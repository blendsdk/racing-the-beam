; =============================================================================
; LESSON 51: Flicker Sprites — The Flicker Gallery — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; What this program does:
;   "the flicker gallery": four 8-line objects share the TIA's two players by
;   alternating two 30 Hz frames.  Each frame draws ONE pair: parity 0 draws
;   objects 0 and 1, parity 1 draws objects 2 and 3.  The eye integrates the
;   alternation into four objects; a still screenshot shows only one half.
;
;   Visible lines (the picture starts at scanline 37, so visible line 0 is
;   scanline 37):
;
;     visible   0-  7   the status zone   8 lines   parity + object cells
;     visible   8-191   the play zone   184 lines   92 rows x 2 (2-line kernel)
;                       ----------------
;                       8 + 184 = 192 visible lines
;
;   THE STATUS ZONE (8 lines).  A strip of playfield cells, repeated in both
;   halves of the screen (CTRLPF bit 0 = 0, repeat):
;
;     chunks 0-1   the parity cell: chunk 0 lit for parity 0,
;                                    chunk 1 lit for parity 1
;     chunks 3-4   object 0's cell      chunks 9-10   object 2's cell
;     chunks 6-7   object 1's cell      chunks 12-13  object 3's cell
;
;   Each cell is two playfield chunks (8 pixels) wide and all eight status
;   lines tall; one dark chunk separates neighbouring cells so two lit cells
;   never merge into a single bar.  The selected pair's cells are lit; the
;   other two are dark.  The cells are white ($0E) and the background $02.
;
;   THE PLAY ZONE (184 lines = 92 rows x 2).  Four objects, each with X, Y,
;   DirX, DirY, Color and Shape.  Every frame every object moves one pixel on
;   each axis and bounces at X 8..144 and Y 0..87.  Y is TOP-DOWN: row 0 is the
;   top of the play zone, row 91 the bottom, and an object's four shape bytes
;   cover rows Y..Y+3 (four 2-line rows = 8 scanlines).
;
;   THE SORT.  Within the selected pair the object with the LARGER Y is nearer
;   the bottom, so it is drawn on P0; its partner goes on P1.  The scheduler
;   copies the two objects' row and shape into the slots (ObjRow0/ObjShape0
;   and ObjRow1/ObjShape1) and their colours straight into COLUP0/COLUP1.
;
;   THE KERNEL.  A 2-line loop.  The first line draws the P0 object, the
;   second line draws the P1 object, each by the same per-row skipdraw test:
;
;     TYA              2   A = the kernel row
;     SEC              2
;     SBC ObjRow0      3   A = row - ObjRow0
;     CMP #4           2   in the four shape rows?
;     BCS NoSlot0      2/3  no: write 0 (blank the player)
;     STA Tmp          3   yes: A = 0..3, the byte inside the shape
;     LDA ObjShape0    3
;     ASL              2   shape x 4 ...
;     ASL              2
;     CLC              2
;     ADC Tmp          3   ... + the row offset = 0..15
;     TAX              2
;     LDA ShapeTable,X 4   the byte from the 4 x 4 shape table
;     JMP Store0       3
;   NoSlot0:
;     LDA #0           2
;   Store0:
;     STA GRP0         3
;     STA WSYNC        3
;
;   That is 35 cycles from TYA to the first cycle of STA GRP0 on the long
;   path; the store completes 3 cycles later.  Line 1's STA begins at cycle
;   42 (7 tail + 35) and completes at 44; line 2's begins at 35 and completes
;   at 37.  The STA WSYNC writes three cycles after the store (47 on line 1,
;   40 on line 2) and then waits out the rest of the line.  The short path is
;   14 cycles to the STA's first cycle and 3 to the write.  The loop tail
;   INY/CPY #92/BNE runs after line 2's WSYNC, at the top of the next pair:
;   7 cycles.  So line 1 costs 7 + 35 + 3 + 3 = 48 cycles of the 76-cycle
;   line and line 2 costs 35 + 3 + 3 = 41; a pair is 89 of the 152-cycle
;   pair.  Both lines are inside the budget; that is the reason the two
;   branchy skipdraws are split one per line instead of stacked on one.
;
;   WHERE THE BYTES LATCH.  The store completes on its last cycle: cycle 44 on
;   line 1 and cycle 37 on line 2.  The visible area starts at cycle 22.7, so
;   the P0 byte applies from TIA pixel 64 and the P1 byte from pixel 43.  An
;   object's 8 pixels start at its X.  A P0 object at X <= 56 is therefore
;   entirely left of the latch: its first line still displays the previous
;   pair row's byte, which is the same shape one row up - a one-scanline
;   downward shift, not a truncated shape (the top line is blank).  From X >= 64 the byte is current and the
;   skew disappears; X 57-63 splits the 8-pixel sprite for one scanline.
;   P1's earlier latch puts its thresholds at X <= 35 / X >= 43.  Both are
;   consequences of the split skipdraw and are documented, not hidden.
;
;   WHY FOUR BYTES ARE EIGHT LINES.  Each line writes only its own player, so
;   the byte written for row Y is not disturbed on the other line: the P0 byte
;   written on line 1 still displays on line 2, and the P1 byte written on
;   line 2 still displays on the next pair's line 1.  That latch persistence
;   is what turns four shape bytes into an 8-line object.
;
;   ONE HMOVE, IN VBLANK.  SlotP0 and SlotP1 each end by coarse-positioning
;   their player (the Lesson 26 divide-by-15 routine); the caller then does
;   one STA WSYNC and one STA HMOVE.  Set every RESxx and HMxx value first,
;   then strobe once.
;
;   THE AUTO-DEMO.  No input is needed: the four objects move and bounce by
;   themselves, so both parities appear within two frames and both capture
;   states are reachable.  A short beep (channel 0) sounds when an object
;   bounces.  There is no fire or SELECT action: this is a kernel lab.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, PlayStart 45, OverscanStart
;   229.  The picture is 8 status lines + 184 play lines = 192.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), PlayStart (45),
;   OverscanStart (229); Parity (A = the new parity, 0/1); DrawSlot0 /
;   DrawSlot1 (A = the object index drawn on P0 / P1); HmoveApply (the WSYNC
;   stall), HmoveDone (the store has executed); SkipWrite (A = the P0 shape
;   byte or 0), SkipWrite1 (A = the P1 shape byte or 0); KernelRow (Y = the
;   play row, 0..91).
;
; RAM map (+clean_start zeroes every byte):
;   $80-$83   ObjX      the four objects' left edges, 8..144
;   $84-$87   ObjY      the four objects' top rows, 0..87
;   $88-$8B   ObjDirX   0 = moving left, 1 = moving right
;   $8C-$8F   ObjDirY   0 = moving up, 1 = moving down
;   $90-$93   ObjColor  the four object colours
;   $94-$97   ObjShape  the four shape indices (0..3)
;   $98       ObjRow0   the P0 object's first kernel row
;   $99       ObjShape0 the P0 object's shape index
;   $9A       ObjRow1   the P1 object's first kernel row
;   $9B       ObjShape1 the P1 object's shape index
;   $9C       Flicker   the parity: 0 draws objects 0/1, 1 draws 2/3
;   $9D       BeepTimer frames of beep left
;   $9E       BeepPitch AUDF0 for the beep
;   $9F       free
;   $A0       Tmp       the kernel's one-byte row-offset scratch
;   $A1-$D7   free
;   $D8-$F7   free (the six-object exercise uses this range)
;   $F8-$FF   stack
;
; Build: acme -f plain -o build/lesson51.bin \
;        lessons/part7-kernel-mastery/51-flicker-sprites/51-flicker-sprites.asm
; Run:   stella build/lesson51.bin     (click the screen to hear the beep)
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

OBJECT_COUNT   = 4       ; four objects: two per parity
SHAPE_BYTES    = 4       ; four shape bytes = four 2-line rows = 8 scanlines
OBJ_MIN_X      = 8       ; the left limit (TIA X)
OBJ_MAX_X      = 144     ; the right limit (8 pixels wide)
OBJ_MIN_Y      = 0       ; the top play-zone row
OBJ_MAX_Y      = 87      ; the last first row: rows 87..90 end by play line 182; Y=88 clips P1

; --- the objects' power-on state --------------------------------------------
; Each pair is spread across the field so both flicker halves are clearly
; visible, and the two members of a pair differ in Y so the sort has work.
OBJ0_X         = 32
OBJ0_Y         = 16
OBJ1_X         = 120
OBJ1_Y         = 64
OBJ2_X         = 64
OBJ2_Y         = 40
OBJ3_X         = 112
OBJ3_Y         = 84

; --- the beep -----------------------------------------------------------------
BEEP_FRAMES    = 6
BEEP_PITCH     = $08

; --- colours ------------------------------------------------------------------
C_RED          = $42     ; object 0
C_GREEN        = $C8     ; object 1
C_BLUE         = $84     ; object 2
C_GOLD         = $1A     ; object 3
C_STATUS       = $0E     ; the status cells: white
C_BG           = $02     ; the background

; =============================================================================
; RAM ALLOCATION ($80-$A0; +clean_start zeroes every byte)
; =============================================================================
ObjX         = $80   ; 4 bytes: the objects' left edges, 8..144
ObjY         = $84   ; 4 bytes: the objects' top rows, 0..87
ObjDirX      = $88   ; 4 bytes: 0 = left, 1 = right
ObjDirY      = $8C   ; 4 bytes: 0 = up, 1 = down
ObjColor     = $90   ; 4 bytes: each object's colour
ObjShape     = $94   ; 4 bytes: each object's shape index, 0..3
ObjRow0      = $98   ; the P0 object's first kernel row
ObjShape0    = $99   ; the P0 object's shape index
ObjRow1      = $9A   ; the P1 object's first kernel row
ObjShape1    = $9B   ; the P1 object's shape index
Flicker      = $9C   ; the parity: 0 = objects 0/1, 1 = objects 2/3
BeepTimer    = $9D   ; frames of beep remaining
BeepPitch    = $9E   ; AUDF0 for the beep
Tmp          = $A0   ; the kernel's row-offset scratch (not persistent state)
;
; $A1-$D7 are free; $D8-$F7 are free (the six-object exercise uses them);
; $F8-$FF is the stack.  The call depth is one level (SlotP0/SlotP1).

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

; --- the four objects --------------------------------------------------------
; Y is top-down and the larger Y is nearer the bottom.  Objects 0 and 1 are
; the parity-0 pair; objects 2 and 3 are the parity-1 pair.
    LDA #OBJ0_X
    STA ObjX
    LDA #OBJ0_Y
    STA ObjY
    LDA #$01
    STA ObjDirX             ; object 0 moves right first
    STA ObjDirY             ; object 0 moves down first
    LDA #C_RED
    STA ObjColor
    LDA #$00
    STA ObjShape            ; shape 0: the arrowhead

    LDA #OBJ1_X
    STA ObjX+1
    LDA #OBJ1_Y
    STA ObjY+1
    LDA #$00
    STA ObjDirX+1           ; object 1 moves left first
    STA ObjDirY+1           ; object 1 moves up first
    LDA #C_GREEN
    STA ObjColor+1
    LDA #$01
    STA ObjShape+1          ; shape 1: the diamond

    LDA #OBJ2_X
    STA ObjX+2
    LDA #OBJ2_Y
    STA ObjY+2
    LDA #$01
    STA ObjDirX+2           ; object 2 moves right first
    LDA #$00
    STA ObjDirY+2           ; object 2 moves up first
    LDA #C_BLUE
    STA ObjColor+2
    LDA #$02
    STA ObjShape+2          ; shape 2: the cross

    LDA #OBJ3_X
    STA ObjX+3
    LDA #OBJ3_Y
    STA ObjY+3
    LDA #$00
    STA ObjDirX+3           ; object 3 moves left first
    LDA #$01
    STA ObjDirY+3           ; object 3 moves down first
    LDA #C_GOLD
    STA ObjColor+3
    LDA #$03
    STA ObjShape+3          ; shape 3: the bug

; --- the flicker scheduler's state ------------------------------------------
; Flicker starts at 1 so the first displayed frame is parity 0 (the EOR at the
; top of VBLANK turns 1 into 0).
    LDA #$01
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
    STA NUSIZ0              ; one 8-pixel copy of each player
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
; 1. THE BEEP'S CLOCK — the last beep frame writes silence
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0
BeepDone:

; -----------------------------------------------------------------------------
; 2. THE FOUR OBJECTS — one pixel per frame on each axis, bouncing at the edges
; -----------------------------------------------------------------------------
; X is the object index 0..3 and every field is a four-byte array, so the same
; code moves all four objects.  At a limit the direction flips and the object
; steps away on the same frame, and the bounce starts the beep.  X runs
; 8..144: 8 is the leftmost safe left edge and 144 keeps the 8-pixel player
; inside the 160-pixel field.  Y runs 0..87 so the four shape rows always fit
; inside the 92 play rows (87 + 3 = 90, rows 0..91).
    LDX #0
MoveLoop:
; --- the X axis --------------------------------------------------------------
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
    INC ObjX,X              ; flip and step away in the same frame
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
; --- the Y axis --------------------------------------------------------------
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
; 3. THE FLICKER SCHEDULER — toggle the parity, select the pair, sort by Y
; -----------------------------------------------------------------------------
; The parity alternates every frame, so each object is drawn 30 times a second
; while the screen refreshes at 60.  The pair base is parity * 2: parity 0
; selects objects 0 and 1, parity 1 selects objects 2 and 3.
;
; Within the pair, Y is top-down, so the object with the LARGER Y is nearer the
; bottom.  That object goes on P0 (the first line of each kernel pair) and its
; partner on P1 (the second line).  The pair is two objects, so the "sort" is
; one compare; a game with more objects would sort the whole draw list by Y the
; same way.
    LDA Flicker
    EOR #$01                ; 0 <-> 1
Parity:                     ; checkpoint: A = the new parity (0/1)
    STA Flicker
    ASL                     ; parity * 2: the pair's first object index
    TAX
    LDA ObjY,X
    CMP ObjY+1,X            ; the pair's second object
    BCC SecondNearer        ; first Y < second Y: the second is nearer
    TXA                     ; the first object is the nearer
    JMP SlotSelect
SecondNearer:
    TXA
    CLC
    ADC #$01                ; the second object is the nearer
SlotSelect:
DrawSlot0:                  ; checkpoint: A = the object index drawn on P0
    PHA                     ; keep the P0 index across the slot copy
    JSR SlotP0              ; row/shape/colour + the coarse X for P0
    PLA
    EOR #$01                ; the partner in the pair (0<->1, 2<->3)
DrawSlot1:                  ; checkpoint: A = the object index drawn on P1
    JSR SlotP1              ; row/shape/colour + the coarse X for P1

; -----------------------------------------------------------------------------
; 4. ONE HMOVE — both coarse resets are set, then one strobe
; -----------------------------------------------------------------------------
; SlotP0 and SlotP1 each end inside the Lesson 26 divide-by-15 routine, so by
; now both RESP0/RESP1 and HMP0/HMP1 hold this frame's positions.  The WSYNC
; starts a fresh line and HMOVE applies both fine offsets in its HBLANK.  This
; is the only HMOVE in the frame.
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed

; -----------------------------------------------------------------------------
; 5. THE STATUS ZONE'S CELLS — a parity cell and four object cells
; -----------------------------------------------------------------------------
; The same 14-chunk strip appears in both halves (CTRLPF bit 0 = 0, repeat):
;
;   PF0 chunks 0-3:   parity cell (chunk 0 or 1) | gap | object 0 (chunks 3-4)
;   PF1 chunks 4-11:  object 0's second chunk | gap | object 1 (6-7) |
;                     gap | object 2 (9-10) | gap
;   PF2 chunks 12-19: object 3 (chunks 12-13)
;
; PF0's bits run backwards against the chunks: bit 4 is chunk 0 and bit 7 is
; chunk 3 (Lesson 19).  The two table entries are the two parities: the
; selected pair's cells are lit and the parity cell shows which half is on
; screen.  The cells are eight lines tall because the status zone is eight
; lines tall.
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
    STA GRP0                ; the players are blank in the status zone
    STA GRP1
    LDA #C_BG
    STA COLUBK

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE LINE 0-7: THE STATUS ZONE (8 lines)
; =============================================================================
; The masks were written in VBLANK, so the first status line is already
; correct.  Eight WSYNCs end lines 37..44 and release the CPU on PlayStart.
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDX #STATUS_LINES
StatusWait:
    STA WSYNC
    DEX
    BNE StatusWait

; =============================================================================
; VISIBLE LINE 8-191: THE PLAY ZONE (184 lines = 92 rows x 2)
; =============================================================================
; The status masks must not leak into the play area: clear the playfield before
; the beam reaches chunk 0 of the first play line.  Then the 2-line loop.
PlayStart:                  ; checkpoint: scanline 45, visible line 8
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #0

; The row loop is the course's top-down form: LDY #0, draw row Y, then
; INY / CPY #92 / BNE.  Y is both the row counter and the row being tested, so
; row 0 is the top of the play zone and row 91 is the bottom.
KernelRow:                  ; checkpoint: Y = 0..91, the play row
; --- line 1: the P0 object (the nearer one) ---------------------------------
    TYA
    SEC
    SBC ObjRow0
    CMP #SHAPE_BYTES
    BCS NoSlot0             ; above or below the shape: blank P0
    STA Tmp                 ; A = 0..3, the byte inside the shape
    LDA ObjShape0
    ASL                     ; shape x 4 ...
    ASL
    CLC
    ADC Tmp                 ; ... + the row offset = 0..15
    TAX
    LDA ShapeTable,X        ; the 4 x 4 shape table
    JMP Store0
NoSlot0:
    LDA #$00
Store0:
SkipWrite:                  ; checkpoint: A = the P0 shape byte or 0
    STA GRP0
    STA WSYNC               ; line 1 of the pair ends here
; --- line 2: the P1 object (the farther one) --------------------------------
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
    STA WSYNC               ; line 2 of the pair ends here
    INY                     ; the loop tail runs at the top of the next pair
    CPY #PLAY_ROWS
    BNE KernelRow
; 92 rows x 2 lines = visible 8-191.  The last WSYNC releases the CPU on
; scanline 229, the first overscan line.

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
; A = the object index (0..3).  The row and shape go to the slot the kernel
; reads; the colour goes straight to the player's colour register; the X goes
; through the Lesson 26 divide-by-15 dance and ends with a RESP strobe.  The
; caller's HMOVE applies the fine offset.  The tail JMP is deliberate: the
; SetCoarse routine's RTS returns to the caller of SlotP0/SlotP1.
SlotP0:
    TAX
    LDA ObjY,X
ObjRow0Read:                ; checkpoint: A = the value written to ObjRow0
    STA ObjRow0
    LDA ObjShape,X
ObjShape0Read:              ; checkpoint: A = the value written to ObjShape0
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
ObjRow1Read:                ; checkpoint: A = the value written to ObjRow1
    STA ObjRow1
    LDA ObjShape,X
ObjShape1Read:              ; checkpoint: A = the value written to ObjShape1
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
; A = the desired left edge + POS_BIAS.  The first WSYNC starts a fresh line;
; the divide loop and the stores run on that line.  Each iteration of the loop
; is 5 cycles = 15 colour clocks, which is why dividing by 15 works.  The
; caller strobes HMOVE afterwards.
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
    LDA #$0C                ; AUDC 0C: the div-6 tone from Lesson 35
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; THE STATUS ZONE'S MASKS — one entry per parity
; =============================================================================
; PF0 bit 4 = chunk 0 ... bit 7 = chunk 3; PF1 bit 7 = chunk 4 ... bit 0 =
; chunk 11; PF2 bit 0 = chunk 12 ... bit 7 = chunk 19.  Each object cell is
; two chunks, with one dark chunk between cells.
;
;   parity 0:  chunk 0 (parity) | object 0 (chunks 3-4) | object 1 (6-7)
;   parity 1:  chunk 1 (parity) | object 2 (chunks 9-10) | object 3 (12-13)
StatusPF0:
    !byte $90               ; parity 0: chunk 0 ($10) + object 0's chunk 3 ($80)
    !byte $20               ; parity 1: chunk 1
StatusPF1:
    !byte $B0               ; parity 0: object 0's chunk 4 ($80) + object 1 ($30)
    !byte $06               ; parity 1: object 2 at chunks 9-10
StatusPF2:
    !byte $00
    !byte $03               ; parity 1: object 3 at chunks 12-13

; =============================================================================
; THE SHAPE TABLE — four shapes x four bytes (16 bytes)
; =============================================================================
; Each byte is one 2-line kernel row, so a shape is four rows = 8 scanlines.
; The index is shape * 4 + (row - ObjRow), 0..15.  The table is page-aligned
; so the indexed load never crosses a page and the kernel ledger needs no
; page-cross allowance.
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
