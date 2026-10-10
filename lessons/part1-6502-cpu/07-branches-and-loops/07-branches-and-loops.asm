; =============================================================================
; LESSON 07: Branches and Loops — Conditional Execution
; =============================================================================
; Part 1: The 6502 CPU
;
; What this program does:
;   The "cursor ladder": EIGHT equal bands of 24 scanlines fill the screen,
;   and exactly one of them — chosen by the cursor byte at RAM $80 — is bright
;   red ($42).  Every other band is dark gray ($02).  The cursor walks DOWN
;   one band about every half second and wraps from the bottom back to the top.
;
;   Almost every interesting instruction below is a control-flow instruction:
;   a compare, a branch, or a loop.  That is the whole lesson.
;
; What you'll learn:
;   - The branch family, and the flag each branch reads:
;       BEQ/BNE -> Z     BCS/BCC -> C     BMI/BPL -> N     BVS/BVC -> V
;   - CMP / CPX / CPY set the flags; the branch right after them reads them
;   - A count-up loop  (INX ... CPX #8 ... BNE)  walks the 8 bands
;   - A count-down loop (LDY #24 ... DEY ... BNE) fills one band, 24 lines
;   - A countdown loop nested inside the frame loop times the animation
;   - A compare-and-reset branch wraps 7 -> 0
;   - JMP is the unconditional jump; branches are for decisions
;   - A branch can only reach about ±127 bytes away (see Exercise 3)
;
; Build: acme -f plain -o build/lesson07.bin \
;        lessons/part1-6502-cpu/07-branches-and-loops/07-branches-and-loops.asm
; Run:   stella build/lesson07.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; COLOR CONSTANTS  (NTSC)
; =============================================================================
DARK        = $02       ; every band that is NOT the cursor band
BRIGHT      = $42       ; the cursor band — bright red

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
Cursor      = $80       ; 0..7: which band is bright (0 = top band, 7 = bottom)
StepTimer   = $81       ; frames left before the cursor moves again

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
BANDS       = 8         ; bands on the ladder (8 x 24 = 192 visible lines)
LINES       = 24        ; scanlines per band
STEP_FRAMES = 30        ; frames between cursor steps (~1/2 second at 60 Hz)

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, set the stack, CLD (Lesson 04)

    ; --- Starting state: the cursor sits on the TOP band ---
    LDA #0                  ; A = 0
    STA Cursor              ; Cursor = 0  (band 0, the top band, is bright)
    LDA #STEP_FRAMES        ; A = 30
    STA StepTimer           ; 30 frames until the first step

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK
    +wait_timer
    LDA #$00
    STA VBLANK              ; un-blank — the visible picture starts now

; -----------------------------------------------------------------------------
; KERNEL — eight 24-line bands; the cursor band is the bright one
; -----------------------------------------------------------------------------
    LDX #0                  ; X = band index.  0 = top band, 7 = bottom band.
PaintBand:
    LDA #DARK               ; assume a dark band...
    CPX Cursor              ; ...until X equals the cursor?  (CPX: X - Cursor)
    BNE +                   ; not equal (Z = 0) -> keep DARK
    LDA #BRIGHT             ; equal (Z = 1) -> this band is the cursor band
+   STA COLUBK              ; paint this band with the chosen color

    LDY #LINES              ; Y counts down the 24 scanlines of this band
-   STA WSYNC               ; wait for the end of the current scanline
    DEY                     ; one line fewer to go: 24, 23, ... 0
    BNE -                   ; loop until the line counter reaches 0

    INX                     ; count up: next band
    CPX #BANDS              ; have we painted all 8 bands?
    BNE PaintBand           ; no (Z = 0) -> loop back for the next band

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
    LDA #$02
    STA VBLANK
    +set_timer 35           ; ~30 scanlines of overscan
    +wait_timer

; -----------------------------------------------------------------------------
; GAME LOGIC — a countdown loop nested inside the frame loop
; -----------------------------------------------------------------------------
; This countdown is the animation clock.  One pass of the frame loop takes
; exactly one frame, and we drop the counter by one on every pass.  Only when
; it reaches 0 does the cursor move — so the bright band steps every 30
; frames, about half a second at the TV's ~60 frames per second.
    DEC StepTimer           ; one frame closer to the next step
    BNE NoStep              ; not 0 yet (Z = 0) -> the cursor stays put
    LDA #STEP_FRAMES        ; countdown reached 0 -> reload it...
    STA StepTimer
    INC Cursor              ; ...and walk the cursor down one band
    LDA Cursor
    CMP #BANDS              ; did it walk past the bottom band (7)?
    BNE NoStep              ; no (Z = 0) -> nothing more to do
    LDA #0                  ; yes -> wrap back to the top band.
    STA Cursor              ; (a compare-and-reset branch, not a wraparound)
NoStep:
    JMP StartFrame          ; next frame.  This jump is unconditional — the
                            ; frame loop simply repeats, so there is no flag to
                            ; test and JMP (not a branch) is the right tool.
                            ; Exercise 3 shows what happens when a loop body
                            ; grows past a branch's ~±127-byte reach.

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
