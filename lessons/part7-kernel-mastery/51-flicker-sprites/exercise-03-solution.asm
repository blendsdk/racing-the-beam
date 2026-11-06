; =============================================================================
; LESSON 51, EXERCISE 3: Always-On Player — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; The exercise makes P0 permanent.  The player's ship is object 0 and it is
; copied into the P0 slot on every frame; the three enemies (objects 1, 2 and
; 3) rotate through the P1 slot on a three-frame cycle:
;
;   parity 0: ship on P0, enemy 1 on P1
;   parity 1: ship on P0, enemy 2 on P1
;   parity 2: ship on P0, enemy 3 on P1
;
; This is the "draw the player first" variant: the object the player steers
; never flickers, and only the enemies pay the 20 Hz price.  P0 is drawn on
; the first line of every kernel pair and P1 on the second, so the ship is on
; screen for both scanlines of every row.  Each enemy is written on the second
; line of every row, and its byte latches through the next row's first line,
; so it is also an 8-line object, one line lower.
;
; There is no sort in this variant: the ship's slot is fixed, and the enemy
; has only one candidate per frame, so the scheduler is one increment, one
; table index and two slot copies.  AlwaysSlot reports A = 0 (the ship's
; object index) every frame.
;
; What this program does:
;   "the flicker gallery" with a fixed player.  Visible 0-7 is the status
;   zone: the parity cell, a ship cell that is always lit, and one enemy cell
;   per frame.  Visible 8-191 is the play zone (184 lines = 92 rows x 2) drawn
;   by the same 2-line skipdraw kernel.  Every object moves one pixel per
;   frame on each axis and bounces at X 8..144 and Y 0..87.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, PlayStart 45, OverscanStart
;   229.  8 status lines + 184 play lines = 192.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), PlayStart (45),
;   OverscanStart (229); Parity (A = the new parity, 0/1/2); AlwaysSlot (A =
;   0, the ship's index); DrawSlot1 (A = the enemy's index, 1..3); HmoveApply,
;   HmoveDone; SkipWrite / SkipWrite1 (A = the shape byte or 0); KernelRow
;   (Y = the play row).
;
; RAM map (+clean_start zeroes every byte):
;   $80-$83   ObjX      the four objects' left edges, 8..144
;   $84-$87   ObjY      the four objects' top rows, 0..87
;   $88-$8B   ObjDirX   0 = left, 1 = right
;   $8C-$8F   ObjDirY   0 = up, 1 = down
;   $90-$93   ObjColor  the four object colours
;   $94-$97   ObjShape  the four shape indices
;   $98-$9B   ObjRow0/ObjShape0/ObjRow1/ObjShape1
;   $9C       Flicker   the parity, 0..2
;   $9D       BeepTimer
;   $9E       BeepPitch
;   $9F       free
;   $A0       Tmp       the kernel's row-offset scratch
;   $A1-$F7   free
;   $F8-$FF   stack
;
; Build: acme -f plain -o build/exercise-03.bin \
;        lessons/part7-kernel-mastery/51-flicker-sprites/exercise-03-solution.asm
; Run:   stella build/exercise-03.bin     (click the screen to hear the beep)
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

STATUS_LINES   = 8       ; visible 0-7: the status zone
PLAY_ROWS      = 92      ; visible 8-191: 92 rows x 2 = 184 lines

OBJECT_COUNT   = 4       ; the ship plus three enemies
SHAPE_BYTES    = 4       ; four shape bytes = four 2-line rows
OBJ_MIN_X      = 8
OBJ_MAX_X      = 144
OBJ_MIN_Y      = 0
OBJ_MAX_Y      = 87      ; the last first row: rows 87..90 end by play line 182; Y=88 clips P1

; --- the ship and the enemies' power-on state -------------------------------
SHIP_X         = 76      ; the player's ship starts in the middle
SHIP_Y         = 60
ENEMY1_X       = 32
ENEMY1_Y       = 20
ENEMY2_X       = 120
ENEMY2_Y       = 44
ENEMY3_X       = 64
ENEMY3_Y       = 80

; --- the beep -----------------------------------------------------------------
BEEP_FRAMES    = 6
BEEP_PITCH     = $08

; --- colours ------------------------------------------------------------------
C_SHIP         = $C8     ; object 0: green
C_RED          = $42     ; enemy 1
C_BLUE         = $84     ; enemy 2
C_GOLD         = $1A     ; enemy 3
C_STATUS       = $0E     ; the status cells: white
C_BG           = $02     ; the background

; =============================================================================
; RAM ALLOCATION ($80-$A0; +clean_start zeroes every byte)
; =============================================================================
ObjX         = $80   ; 4 bytes: the objects' left edges
ObjY         = $84   ; 4 bytes: the objects' top rows
ObjDirX      = $88   ; 4 bytes: 0 = left, 1 = right
ObjDirY      = $8C   ; 4 bytes: 0 = up, 1 = down
ObjColor     = $90   ; 4 bytes: the object colours
ObjShape     = $94   ; 4 bytes: the shape indices
ObjRow0      = $98   ; the P0 object's first kernel row (always the ship)
ObjShape0    = $99   ; the P0 object's shape index
ObjRow1      = $9A   ; the P1 object's first kernel row (the enemy)
ObjShape1    = $9B   ; the P1 object's shape index
Flicker      = $9C   ; the parity, 0..2
BeepTimer    = $9D   ; frames of beep remaining
BeepPitch    = $9E   ; AUDF0 for the beep
Tmp          = $A0   ; the kernel's row-offset scratch
;
; $A1-$F7 are free; $F8-$FF is the stack.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the ship (object 0) -----------------------------------------------------
    LDA #SHIP_X
    STA ObjX
    LDA #SHIP_Y
    STA ObjY
    LDA #$01
    STA ObjDirX             ; drifts right first
    LDA #$00
    STA ObjDirY             ; drifts up first
    LDA #C_SHIP
    STA ObjColor
    LDA #$00
    STA ObjShape            ; shape 0: the arrowhead

; --- the three enemies -------------------------------------------------------
    LDA #ENEMY1_X
    STA ObjX+1
    LDA #ENEMY1_Y
    STA ObjY+1
    LDA #$01
    STA ObjDirX+1
    STA ObjDirY+1
    LDA #C_RED
    STA ObjColor+1
    LDA #$01
    STA ObjShape+1

    LDA #ENEMY2_X
    STA ObjX+2
    LDA #ENEMY2_Y
    STA ObjY+2
    LDA #$00
    STA ObjDirX+2
    STA ObjDirY+2
    LDA #C_BLUE
    STA ObjColor+2
    LDA #$02
    STA ObjShape+2

    LDA #ENEMY3_X
    STA ObjX+3
    LDA #ENEMY3_Y
    STA ObjY+3
    LDA #$01
    STA ObjDirX+3
    LDA #$00
    STA ObjDirY+3
    LDA #C_GOLD
    STA ObjColor+3
    LDA #$03
    STA ObjShape+3

; --- the flicker scheduler's state ------------------------------------------
; Flicker starts at 2 so the first displayed frame is parity 0 (enemy 1).
    LDA #$02
    STA Flicker
    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #$00

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_BG
    STA COLUBK
    LDA #C_STATUS
    STA COLUPF
    LDA #$00
    STA CTRLPF              ; bit 0 = 0: the right half repeats the left
    STA NUSIZ0
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    STA ENAM0
    STA ENAM1
    STA ENABL

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; 1. THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0
BeepDone:

; -----------------------------------------------------------------------------
; 2. THE FOUR OBJECTS — one pixel per frame, bouncing
; -----------------------------------------------------------------------------
    LDX #0
MoveLoop:
    LDA ObjDirX,X
    BNE MoveRight
    LDA ObjX,X
    CMP #OBJ_MIN_X
    BEQ BounceRight
    DEC ObjX,X
    JMP XDone
BounceRight:
    LDA #$01
    STA ObjDirX,X
    INC ObjX,X
    JSR BeepStart
    JMP XDone
MoveRight:
    LDA ObjX,X
    CMP #OBJ_MAX_X
    BEQ BounceLeft
    INC ObjX,X
    JMP XDone
BounceLeft:
    LDA #$00
    STA ObjDirX,X
    DEC ObjX,X
    JSR BeepStart
XDone:
    LDA ObjDirY,X
    BNE MoveDown
    LDA ObjY,X
    CMP #OBJ_MIN_Y
    BEQ BounceDown
    DEC ObjY,X
    JMP YDone
BounceDown:
    LDA #$01
    STA ObjDirY,X
    INC ObjY,X
    JSR BeepStart
    JMP YDone
MoveDown:
    LDA ObjY,X
    CMP #OBJ_MAX_Y
    BEQ BounceUp
    INC ObjY,X
    JMP YDone
BounceUp:
    LDA #$00
    STA ObjDirY,X
    DEC ObjY,X
    JSR BeepStart
YDone:
    INX
    CPX #OBJECT_COUNT
    BNE MoveLoop


; -----------------------------------------------------------------------------
; 3. THE SCHEDULER — the ship every frame, one enemy per frame
; -----------------------------------------------------------------------------
; The parity cycles 0, 1, 2 and the enemy is object parity + 1.  The ship's
; slot is object 0 on every frame: the player never flickers.
    INC Flicker
    LDA Flicker
    CMP #$03
    BCC ParityOk
    LDA #$00
    STA Flicker
ParityOk:
Parity:                     ; checkpoint: A = the new parity (0/1/2)

    LDA #$00                ; the ship is object 0
AlwaysSlot:                 ; checkpoint: A = 0, the P0 slot's object
    JSR SlotP0

    LDA Flicker
    CLC
    ADC #$01                ; the enemy is object parity + 1 (1..3)
DrawSlot1:                  ; checkpoint: A = the enemy's object index (1..3)
    JSR SlotP1

; -----------------------------------------------------------------------------
; 4. ONE HMOVE
; -----------------------------------------------------------------------------
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed

; -----------------------------------------------------------------------------
; 5. THE STATUS ZONE'S CELLS
; -----------------------------------------------------------------------------
; The parity cell is chunks 0-1, the ship cell is always chunks 3-4, and the
; three enemy cells are chunks 6-7, 9-10 and 12-13.  One enemy cell is lit per
; frame; the ship cell never goes dark.
    LDX Flicker
    LDA StatusPF0,X
    STA PF0
    LDA StatusPF1,X
    STA PF1
    LDA StatusPF2,X
    STA PF2
    LDA #C_STATUS
    STA COLUPF
    LDA #$00
    STA GRP0
    STA GRP1
    LDA #C_BG
    STA COLUBK

    +wait_timer
    LDA #$00
    STA VBLANK

; =============================================================================
; VISIBLE LINE 0-7: THE STATUS ZONE (8 lines)
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDX #STATUS_LINES
StatusWait:
    STA WSYNC
    DEX
    BNE StatusWait

; =============================================================================
; VISIBLE LINE 8-191: THE PLAY ZONE (184 lines = 92 rows x 2)
; =============================================================================
PlayStart:                  ; checkpoint: scanline 45, visible line 8
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #0

KernelRow:                  ; checkpoint: Y = 0..91, the play row
    TYA
    SEC
    SBC ObjRow0
    CMP #SHAPE_BYTES
    BCS NoSlot0
    STA Tmp
    LDA ObjShape0
    ASL
    ASL
    CLC
    ADC Tmp
    TAX
    LDA ShapeTable,X
    JMP Store0
NoSlot0:
    LDA #$00
Store0:
SkipWrite:                  ; checkpoint: A = the P0 shape byte or 0
    STA GRP0
    STA WSYNC
    TYA
    SEC
    SBC ObjRow1
    CMP #SHAPE_BYTES
    BCS NoSlot1
    STA Tmp
    LDA ObjShape1
    ASL
    ASL
    CLC
    ADC Tmp
    TAX
    LDA ShapeTable,X
    JMP Store1
NoSlot1:
    LDA #$00
Store1:
SkipWrite1:                 ; checkpoint: A = the P1 shape byte or 0
    STA GRP1
    STA WSYNC
    INY
    CPY #PLAY_ROWS
    BNE KernelRow

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SlotP0 / SlotP1 — copy one object's draw state into a slot, then position it
; =============================================================================
SlotP0:
    TAX
    LDA ObjY,X
    STA ObjRow0
    LDA ObjShape,X
    STA ObjShape0
    LDA ObjColor,X
    STA COLUP0
    LDA ObjX,X
    CLC
    ADC #POS_BIAS
    JMP SetCoarseP0

SlotP1:
    TAX
    LDA ObjY,X
    STA ObjRow1
    LDA ObjShape,X
    STA ObjShape1
    LDA ObjColor,X
    STA COLUP1
    LDA ObjX,X
    CLC
    ADC #POS_BIAS
    JMP SetCoarseP1

; =============================================================================
; SetCoarseP0 / SetCoarseP1 — the Lesson 26 divide-by-15 positioning dance
; =============================================================================
SetCoarseP0:
    STA WSYNC
    SEC
DivP0:
    SBC #15
    BCS DivP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS

SetCoarseP1:
    STA WSYNC
    SEC
DivP1:
    SBC #15
    BCS DivP1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
    RTS

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; THE STATUS ZONE'S MASKS — one entry per parity
; =============================================================================
; The ship cell (chunks 3-4) is lit in every entry; the parity cell shows the
; phase and the matching enemy cell is lit.
StatusPF0:
    !byte $90               ; parity 0: chunk 0 + ship chunk 3
    !byte $A0               ; parity 1: chunk 1 + ship chunk 3
    !byte $B0               ; parity 2: both parity chunks + ship chunk 3
StatusPF1:
    !byte $B0               ; parity 0: ship chunk 4 + enemy 1 (6-7)
    !byte $86               ; parity 1: ship chunk 4 + enemy 2 (9-10)
    !byte $80               ; parity 2: ship chunk 4 only
StatusPF2:
    !byte $00
    !byte $00
    !byte $03               ; parity 2: enemy 3 at chunks 12-13

; =============================================================================
; THE SHAPE TABLE — four shapes x four bytes (16 bytes)
; =============================================================================
    !align 255, 0
ShapeTable:
    ; shape 0: an arrowhead
    !byte $18, $3C, $7E, $FF
    ; shape 1: a diamond
    !byte $18, $3C, $3C, $18
    ; shape 2: a cross
    !byte $5A, $FF, $FF, $5A
    ; shape 3: a bug
    !byte $5A, $FF, $A5, $5A

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
