; =============================================================================
; LESSON 09 — EXERCISE 3 SOLUTION: A Ring Counter *(Stretch Goal)*
; =============================================================================
;
; Challenge: make the traveling bit RE-ENTER instead of reloading.  In the
; lesson ROM the bit reaches bit 7, falls out into the carry, and a BCS
; reload tells the pattern to start over at %00000001.  A ring counter has
; no reload: ROL rotates THROUGH the carry, so the bit that leaves bit 7
; comes straight back in at bit 0 and the ladder never stops.
;
; The catch is what ROL expects of the carry.  A true rotate needs C to BE
; the bit that re-enters:
;
;   ROL:   bit 7 -> carry        (the bit that leaves)
;          carry -> bit 0        (the bit that re-enters)
;
; so before each rotation the carry must be set from bit 7 — exactly the bit
; about to leave.  CMP does that in one instruction, and it is also a
; comparison: it sets the flags and leaves A alone, so the byte it just tested
; is still in the accumulator for the rotate — no reload needed here:
;
;   LDA Pattern / CMP #%10000000 / ROL / STA Pattern
;
; Walk it through by hand:
;   %00000001  bit 7 is 0 -> C=0 -> ROL -> %00000010
;   %00000010  bit 7 is 0 -> C=0 -> ROL -> %00000100
;   ...                                       (six steps up the ladder)
;   %10000000  bit 7 is 1 -> C=1 -> ROL -> %00000001   <- re-entered!
;
; Eight rotations bring the bit all the way around: the ring has exactly
; eight positions, one per bit, and never holds zero bits.  The mirrored
; version walks the bit DOWN with ROR — and it DOES need a reload, because
; LSR (how bit 0 gets into the carry) shifts the byte as well:
;
;   LDA Pattern
;   LSR                 ; bit 0 -> carry ... and A is shifted, too
;   LDA Pattern         ; reload the byte (LDA does not touch C)
;   ROR                 ; the bit that left bit 0 re-enters at bit 7
;   STA Pattern
;
; The difference is the setup instruction: CMP is a comparison and leaves its
; operand alone, while LSR consumes the byte it shifts.  (LDA preserves the
; carry, so the bit that just landed in C is still there for the ROR.)
;
; (Why not a bare ROL?  The carry does not survive the ~30 frames between
; steps — the kernel's LSR Mask overwrites C every frame — so a bare ROL
; would feed the mask's leftover bit back in and light a second band.  The
; CMP makes each rotation independent of whatever ran before it.)
;
; The display is the lesson's bit ladder: 8 bands of 24 scanlines, bit 7 at
; the top and bit 0 at the bottom, a set bit bright green ($C8).  192
; non-blanked scanlines: the release line is band 0's first line plus 23
; painted, then 24 for each other band.
;
; Expected screen: the bright band climbs bottom -> top like the lesson ROM,
; then the next step puts it straight back on the bottom band — no reload,
; no gap, forever.  In the debugger, $80 steps %00000001, %00000010, ...
; %10000000, %00000001, ... and never reads %00000000.
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- Colors (NTSC) ---
GRAY        = $02       ; a band whose bit is 0
GREEN       = $C8       ; a band whose bit is 1

; --- RAM variables ---
Pattern     = $80       ; the ring: one bit set, rotating forever
Mask        = $81       ; band-select mask: %10000000 ... %00000001
StepTimer   = $82       ; frames until the ring rotates again

; --- Program constants ---
BANDS       = 8         ; bands on the ladder — one per ring position
LINES       = 24        ; scanlines per band (8 x 24 = 192 visible lines)
STEP_FRAMES = 30        ; frames between rotations (~1/2 second at 60 Hz)

    * = $F000

Reset:
    +clean_start

    LDA #%00000001          ; the ring starts on bit 0 (the bottom band)
    STA Pattern
    LDA #STEP_FRAMES
    STA StepTimer

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

    ; --- one rotation every STEP_FRAMES frames ---
    DEC StepTimer
    BNE NoStep
    LDA #STEP_FRAMES
    STA StepTimer

    ; --- ring the bit around: bit 7 -> carry -> bit 0 ---
    LDA Pattern
    CMP #%10000000          ; C = 1 exactly when bit 7 holds the set bit;
                            ; CMP leaves A alone, so no reload is needed
RingStep:                   ; debugger checkpoint: A = the pattern before the
                            ;   rotate, C = the bit that re-enters at bit 0
    ROL                     ; the bit that left bit 7 re-enters at bit 0
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
