; =============================================================================
; LESSON 09 — EXERCISE 1 SOLUTION: Set, Clear, and Toggle
; =============================================================================
;
; Challenge: start from the byte %10100000 and change three bits with the
; three logic instructions, showing each result:
;
;   1. SET    bit 2  with ORA   %10100000 -> ORA %00000100 -> %10100100
;   2. CLEAR  bit 5  with AND   %10100100 -> AND %11011111 -> %10000100
;   3. TOGGLE bit 7  with EOR   %10000100 -> EOR %10000000 -> %00000100
;
; The three operations are cumulative: each one starts from the previous
; pattern, which is exactly how flags get cleared and set in real code.
; The pattern then jumps back to %10100000 and the sequence repeats, so each
; of the four display states holds for 30 frames (~1/2 second).
;
; Which instruction does what:
;   ORA sets a bit:   x OR   %00000100 forces bit 2 to 1, leaves the rest
;   AND clears a bit: x AND  %11011111 forces bit 5 to 0, leaves the rest
;   EOR toggles:      x XOR  %10000000 flips bit 7 (1 -> 0 here), leaves
;                     the rest; XORing again would flip it back
; Each one sets Z and N from its result — the flags a later branch can read.
;
; The display is the lesson's bit ladder: 8 bands of 24 scanlines, bit 7 of
; Pattern ($80) on the top band ... bit 0 on the bottom band.  A set bit
; paints its band bright green ($C8), a clear bit dark gray ($02).  The
; picture is 192 non-blanked scanlines: the release line is band 0's first
; line, PaintBand paints 23 more for band 0 and 24 for each other band.
;
; Expected screen: from the top, %10100000 shows bright bands on band 0 and
; band 2 (bits 7 and 5); then %10100100 adds band 5 (bit 2); then %10000100
; drops band 2 (clear bit 5); then %00000100 leaves only band 5.  Read the
; byte itself at RAM $80 — the debugger shows all four patterns in turn.
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- Colors (NTSC) ---
GRAY        = $02       ; a band whose bit is 0
GREEN       = $C8       ; a band whose bit is 1

; --- RAM variables ---
Pattern     = $80       ; the byte being edited: %10100000 at the start
Mask        = $81       ; band-select mask: %10000000 ... %00000001
StepTimer   = $82       ; frames until the next operation
Step        = $83       ; 0 = original, 1 = ORA, 2 = AND, 3 = EOR

; --- Program constants ---
BANDS       = 8         ; bands on the ladder
LINES       = 24        ; scanlines per band (8 x 24 = 192 visible lines)
STEP_FRAMES = 30        ; frames between operations (~1/2 second at 60 Hz)

    * = $F000

Reset:
    +clean_start

    LDA #%10100000          ; the byte the exercise starts from
    STA Pattern
    LDA #STEP_FRAMES
    STA StepTimer           ; the first operation waits one full tick

; =============================================================================
; MAIN LOOP — one pass = one frame
; =============================================================================
StartFrame:
    +vsync

    LDA #$02
    STA VBLANK
    +set_timer 43

    ; --- band 0's color (bit 7), tested while the beam is blanked ---
    LDA #%10000000          ; the mask for band 0 ...
    STA Mask                ; ... and the start of every frame's mask ladder
TopBandTest:                ; debugger checkpoint: break here and A is the mask
    AND Pattern
    BEQ TopBandDark
    LDA #GREEN
    BNE TopBandColor
TopBandDark:
    LDA #GRAY
TopBandColor:
    TAY                     ; park the color: +wait_timer clobbers A

    +wait_timer

    LDA #$00
    STA VBLANK              ; release the beam; the release line is band 0's
    TYA                     ; A = band 0's color
    STA COLUBK              ; written in HBLANK, so the release line shows it

    ; --- band 0: release line + 23 painted lines = 24 ---
    LDX #LINES-1
    JSR PaintBand
    LSR Mask                ; band 1 tests bit 6

    LDY #1
BandLoop:
    LDA Mask
BandTest:                   ; debugger checkpoint: break here and A is the mask
    AND Pattern
    BEQ BandDark
    LDA #GREEN
    BNE BandColor
BandDark:
    LDA #GRAY
BandColor:
    LDX #LINES
    JSR PaintBand
    LSR Mask
    INY
    CPY #BANDS
    BNE BandLoop

    ; --- overscan; WSYNC keeps the blank-on out of the last band line ---
    STA WSYNC
    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer

    ; --- one operation every STEP_FRAMES frames ---
    DEC StepTimer
    BNE NoStep
    LDA #STEP_FRAMES
    STA StepTimer
    INC Step
    LDA Step
    CMP #4                  ; past the last operation?
    BNE DoStep
    LDA #%10100000          ; yes -> back to the original byte ...
RestartDone:                ; debugger checkpoint: A = the pattern about to
    STA Pattern             ;   be stored ($A0 = %10100000)
    LDA #0
    STA Step                ; ... and start the sequence again
    JMP NoStep

DoStep:
    CMP #1
    BEQ SetBit2
    CMP #2
    BEQ ClearBit5
    ; Step = 3: TOGGLE bit 7 with EOR
    LDA Pattern
    EOR #%10000000
ToggleDone:                 ; debugger checkpoint: A = %00000100 (bit 7 off)
    STA Pattern
    JMP NoStep
SetBit2:
    ; Step = 1: SET bit 2 with ORA
    LDA Pattern
    ORA #%00000100
SetDone:                    ; debugger checkpoint: A = %10100100 (bit 2 set)
    STA Pattern
    JMP NoStep
ClearBit5:
    ; Step = 2: CLEAR bit 5 with AND
    LDA Pattern
    AND #%11011111
ClearDone:                  ; debugger checkpoint: A = %10000100 (bit 5 clear)
    STA Pattern
NoStep:
    JMP StartFrame

; =============================================================================
; PaintBand — paint X scanlines of the color in A (from the lesson ROM)
; Registers: A survives, Y is never touched, X is used up as the counter.
; =============================================================================
PaintBand:
-   STA WSYNC
    STA COLUBK
    DEX
    BNE -
    RTS

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
