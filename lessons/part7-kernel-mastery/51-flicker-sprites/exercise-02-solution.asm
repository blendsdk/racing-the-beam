; =============================================================================
; LESSON 51, EXERCISE 2: Three-Frame Flicker — Six Objects — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; The exercise adds two objects and a third parity.  Six objects, three
; frames, two objects per frame: each object is now drawn 20 times a second
; (60 / 3), and the eye still merges the three halves into six objects.
;
;   parity 0 draws objects 0 and 1
;   parity 1 draws objects 2 and 3
;   parity 2 draws objects 4 and 5
;
; The first four objects live in the same $80-$9E arrays as the base lesson.
; The two extra objects live in the free page at $D8-$E3 as six 2-byte arrays:
;
;   $D8 Obj4X    $DA Obj4Y    $DC Obj4DirX
;   $DE Obj4DirY $E0 Obj4Color $E2 Obj4Shape
;
; Object 4 is index 0 in those arrays and object 5 is index 1, so the extra
; motion loop is the base loop with X as a 0..1 index (the 6502 has no
; zero-page,Y addressing for LDA/STA/INC/DEC, so the extra arrays use X).  The scheduler reads the
; extra pair directly when the parity is 2; the partner rule is still
; "index EOR 1" (4 <-> 5), and SlotP0/SlotP1 branch to the $D8 arrays for an
; index of 4 or 5.
;
; What this program does:
;   "the flicker gallery" with six objects.  Visible 0-7 is the status zone:
;   a parity cell (chunk 0 = parity 0, chunk 1 = parity 1, both = parity 2)
;   plus six two-chunk object cells, each separated by one dark chunk.  Visible 8-191 is the play zone, 184
;   lines = 92 rows x 2, drawn by the same 2-line skipdraw kernel.  Every
;   object moves one pixel per frame on each axis and bounces at X 8..144 and
;   Y 0..87; the nearer object of the selected pair (the larger Y) goes on P0.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, PlayStart 45, OverscanStart
;   229.  8 status lines + 184 play lines = 192.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), PlayStart (45),
;   OverscanStart (229); Parity (A = the new parity, 0/1/2); DrawSlot0 /
;   DrawSlot1 (A = the object index drawn on P0 / P1, 0..5); HmoveApply,
;   HmoveDone; SkipWrite / SkipWrite1 (A = the shape byte or 0); KernelRow
;   (Y = the play row).
;
; RAM map (+clean_start zeroes every byte):
;   $80-$83   ObjX      objects 0-3: left edges, 8..144
;   $84-$87   ObjY      objects 0-3: top rows, 0..87
;   $88-$8B   ObjDirX   0 = left, 1 = right
;   $8C-$8F   ObjDirY   0 = up, 1 = down
;   $90-$93   ObjColor  the four base colours
;   $94-$97   ObjShape  the four base shape indices
;   $98-$9B   ObjRow0/ObjShape0/ObjRow1/ObjShape1
;   $9C       Flicker   the parity, 0..2
;   $9D       BeepTimer
;   $9E       BeepPitch
;   $9F       free
;   $A0       Tmp       the kernel's row-offset scratch
;   $A1-$D7   free
;   $D8-$E3   the two extra objects (six 2-byte arrays, see above)
;   $E4-$F7   free
;   $F8-$FF   stack
;
; Build: acme -f plain -o build/exercise-02.bin \
;        lessons/part7-kernel-mastery/51-flicker-sprites/exercise-02-solution.asm
; Run:   stella build/exercise-02.bin     (click the screen to hear the beep)
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

BASE_OBJECTS   = 4       ; objects 0-3 in the $80-$9E arrays
EXTRA_OBJECTS  = 2       ; objects 4-5 in the $D8-$E3 arrays
SHAPE_BYTES    = 4       ; four shape bytes = four 2-line rows
OBJ_MIN_X      = 8
OBJ_MAX_X      = 144
OBJ_MIN_Y      = 0
OBJ_MAX_Y      = 87      ; the last first row: rows 87..90 end by play line 182; Y=88 clips P1

; --- the six objects' power-on state ----------------------------------------
OBJ0_X         = 24
OBJ0_Y         = 12
OBJ1_X         = 120
OBJ1_Y         = 52
OBJ2_X         = 48
OBJ2_Y         = 72
OBJ3_X         = 112
OBJ3_Y         = 28
OBJ4_X         = 72
OBJ4_Y         = 84
OBJ5_X         = 96
OBJ5_Y         = 60

; --- the beep -----------------------------------------------------------------
BEEP_FRAMES    = 6
BEEP_PITCH     = $08

; --- colours ------------------------------------------------------------------
C_RED          = $42     ; object 0
C_GREEN        = $C8     ; object 1
C_BLUE         = $84     ; object 2
C_GOLD         = $1A     ; object 3
C_ORANGE       = $36     ; object 4
C_PURPLE       = $A8     ; object 5
C_STATUS       = $0E     ; the status cells: white
C_BG           = $02     ; the background

; =============================================================================
; RAM ALLOCATION ($80-$A0 and $D8-$E3)
; =============================================================================
ObjX         = $80   ; 4 bytes: the base objects' left edges
ObjY         = $84   ; 4 bytes: the base objects' top rows
ObjDirX      = $88   ; 4 bytes: 0 = left, 1 = right
ObjDirY      = $8C   ; 4 bytes: 0 = up, 1 = down
ObjColor     = $90   ; 4 bytes: the base object colours
ObjShape     = $94   ; 4 bytes: the base shape indices, 0..3
ObjRow0      = $98   ; the P0 object's first kernel row
ObjShape0    = $99   ; the P0 object's shape index
ObjRow1      = $9A   ; the P1 object's first kernel row
ObjShape1    = $9B   ; the P1 object's shape index
Flicker      = $9C   ; the parity, 0..2
BeepTimer    = $9D   ; frames of beep remaining
BeepPitch    = $9E   ; AUDF0 for the beep
Tmp          = $A0   ; the kernel's row-offset scratch

; --- the two extra objects: six 2-byte arrays (index 0 = object 4) ----------
Obj4X        = $D8
Obj4Y        = $DA
Obj4DirX     = $DC
Obj4DirY     = $DE
Obj4Color    = $E0
Obj4Shape    = $E2
;
; $A1-$D7 and $E4-$F7 are free; $F8-$FF is the stack.

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

; --- objects 0-3: the base arrays -------------------------------------------
    LDA #OBJ0_X
    STA ObjX
    LDA #OBJ0_Y
    STA ObjY
    LDA #$01
    STA ObjDirX
    STA ObjDirY
    LDA #C_RED
    STA ObjColor
    LDA #$00
    STA ObjShape

    LDA #OBJ1_X
    STA ObjX+1
    LDA #OBJ1_Y
    STA ObjY+1
    LDA #$00
    STA ObjDirX+1
    STA ObjDirY+1
    LDA #C_GREEN
    STA ObjColor+1
    LDA #$01
    STA ObjShape+1

    LDA #OBJ2_X
    STA ObjX+2
    LDA #OBJ2_Y
    STA ObjY+2
    LDA #$01
    STA ObjDirX+2
    LDA #$00
    STA ObjDirY+2
    LDA #C_BLUE
    STA ObjColor+2
    LDA #$02
    STA ObjShape+2

    LDA #OBJ3_X
    STA ObjX+3
    LDA #OBJ3_Y
    STA ObjY+3
    LDA #$00
    STA ObjDirX+3
    LDA #$01
    STA ObjDirY+3
    LDA #C_GOLD
    STA ObjColor+3
    LDA #$03
    STA ObjShape+3

; --- objects 4-5: the extra arrays in $D8-$E3 -------------------------------
    LDA #OBJ4_X
    STA Obj4X
    LDA #OBJ4_Y
    STA Obj4Y
    LDA #$01
    STA Obj4DirX
    STA Obj4DirY
    LDA #C_ORANGE
    STA Obj4Color
    LDA #$00
    STA Obj4Shape

    LDA #OBJ5_X
    STA Obj4X+1
    LDA #OBJ5_Y
    STA Obj4Y+1
    LDA #$00
    STA Obj4DirX+1
    STA Obj4DirY+1
    LDA #C_PURPLE
    STA Obj4Color+1
    LDA #$01
    STA Obj4Shape+1

; --- the flicker scheduler's state ------------------------------------------
; Flicker starts at 2 so the first displayed frame is parity 0.
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
; 2. THE FOUR BASE OBJECTS — one pixel per frame, bouncing
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
    CPX #BASE_OBJECTS
    BNE MoveLoop

; -----------------------------------------------------------------------------
; 3. THE TWO EXTRA OBJECTS — the same motion over the $D8-$E3 arrays
; -----------------------------------------------------------------------------
    LDX #0
MoveExtra:
    LDA Obj4DirX,X
    BNE MoveRightE
    LDA Obj4X,X
    CMP #OBJ_MIN_X
    BEQ BounceRightE
    DEC Obj4X,X
    JMP XDoneE
BounceRightE:
    LDA #$01
    STA Obj4DirX,X
    INC Obj4X,X
    JSR BeepStart
    JMP XDoneE
MoveRightE:
    LDA Obj4X,X
    CMP #OBJ_MAX_X
    BEQ BounceLeftE
    INC Obj4X,X
    JMP XDoneE
BounceLeftE:
    LDA #$00
    STA Obj4DirX,X
    DEC Obj4X,X
    JSR BeepStart
XDoneE:
    LDA Obj4DirY,X
    BNE MoveDownE
    LDA Obj4Y,X
    CMP #OBJ_MIN_Y
    BEQ BounceDownE
    DEC Obj4Y,X
    JMP YDoneE
BounceDownE:
    LDA #$01
    STA Obj4DirY,X
    INC Obj4Y,X
    JSR BeepStart
    JMP YDoneE
MoveDownE:
    LDA Obj4Y,X
    CMP #OBJ_MAX_Y
    BEQ BounceUpE
    INC Obj4Y,X
    JMP YDoneE
BounceUpE:
    LDA #$00
    STA Obj4DirY,X
    DEC Obj4Y,X
    JSR BeepStart
YDoneE:
    INX
    CPX #EXTRA_OBJECTS
    BNE MoveExtra


; -----------------------------------------------------------------------------
; 4. THE THREE-FRAME SCHEDULER — parity 0/1/2, two objects per frame
; -----------------------------------------------------------------------------
; Flicker counts 0, 1, 2 and wraps.  Parity 0 and 1 use the base arrays and
; the parity*2 pair base; parity 2 reads the extra pair directly.  Within a
; pair the larger Y (the nearer object) goes on P0.
    INC Flicker
    LDA Flicker
    CMP #$03
    BCC ParityOk
    LDA #$00
    STA Flicker
ParityOk:
Parity:                     ; checkpoint: A = the new parity (0/1/2)
    CMP #$02
    BEQ ExtraPair
    ASL                     ; 0 -> 0, 1 -> 2
    TAX
    LDA ObjY,X
    CMP ObjY+1,X
    BCC SecondNearer
    TXA
    JMP SlotSelect
SecondNearer:
    TXA
    CLC
    ADC #$01
    JMP SlotSelect
ExtraPair:
    LDA Obj4Y
    CMP Obj4Y+1
    BCC ExtraSecond
    LDA #$04
    JMP SlotSelect
ExtraSecond:
    LDA #$05
SlotSelect:
DrawSlot0:                  ; checkpoint: A = the object index drawn on P0
    PHA
    JSR SlotP0
    PLA
    EOR #$01                ; the partner (0<->1, 2<->3, 4<->5)
DrawSlot1:                  ; checkpoint: A = the object index drawn on P1
    JSR SlotP1

; -----------------------------------------------------------------------------
; 5. ONE HMOVE
; -----------------------------------------------------------------------------
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed

; -----------------------------------------------------------------------------
; 6. THE STATUS ZONE'S CELLS — one parity entry per three-frame phase
; -----------------------------------------------------------------------------
; Six object cells plus the parity cell fill 14 of the 20 playfield chunks:
;
;   chunks 0-1 parity | 2-3 object 0 | 5-6 object 1 | 8-9 object 2
;   chunks 11-12 object 3 | 14-15 object 4 | 17-18 object 5
;
; Chunk 19 is left dark so the repeated strip (chunk 20 is the second copy's
; parity cell) never merges with object 5's cell.  PF0 bit 4 = chunk 0,
; PF1 bit 7 = chunk 4, PF2 bit 0 = chunk 12.
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
; SlotP0 / SlotP1 — objects 0-3 from the base arrays, 4-5 from $D8-$E3
; =============================================================================
; A = the object index (0..5).  The row and shape go to the slot the kernel
; reads; the colour goes to the player's colour register; the X goes through
; the divide-by-15 dance and ends with a RESP strobe.
SlotP0:
    CMP #$04
    BCS SlotP0Extra
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
SlotP0Extra:
    SEC
    SBC #$04                ; the extra index: 0 = object 4, 1 = object 5
    TAX
    LDA Obj4Y,X
    STA ObjRow0
    LDA Obj4Shape,X
    STA ObjShape0
    LDA Obj4Color,X
    STA COLUP0
    LDA Obj4X,X
    CLC
    ADC #POS_BIAS
    JMP SetCoarseP0

SlotP1:
    CMP #$04
    BCS SlotP1Extra
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
SlotP1Extra:
    SEC
    SBC #$04
    TAX
    LDA Obj4Y,X
    STA ObjRow1
    LDA Obj4Shape,X
    STA ObjShape1
    LDA Obj4Color,X
    STA COLUP1
    LDA Obj4X,X
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
; THE STATUS ZONE'S MASKS — one entry per parity (three entries)
; =============================================================================
; parity 0:  chunk 0 (parity) | object 0 (2-3) | object 1 (5-6)
; parity 1:  chunk 1 (parity) | object 2 (8-9) | object 3 (11-12)
; parity 2:  chunks 0-1 (parity) | object 4 (14-15) | object 5 (17-18)
StatusPF0:
    !byte $D0               ; parity 0: chunk 0 ($10) + object 0 ($C0)
    !byte $20               ; parity 1: chunk 1
    !byte $30               ; parity 2: both parity chunks
StatusPF1:
    !byte $60               ; parity 0: object 1 at chunks 5-6
    !byte $0D               ; parity 1: object 2 ($0C) + object 3's chunk 11 ($01)
    !byte $00               ; parity 2: no cells in PF1
StatusPF2:
    !byte $00               ; parity 0
    !byte $01               ; parity 1: object 3's chunk 12
    !byte $6C               ; parity 2: object 4 ($0C) + object 5 ($60)

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
