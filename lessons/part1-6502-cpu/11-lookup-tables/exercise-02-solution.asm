; =============================================================================
; LESSON 11 — EXERCISE 2 SOLUTION: A Two-Table Movie
; =============================================================================
;
; Challenge: let ONE color fill the whole screen, but hold each color for its
; own time.  Two tables drive the picture: Colors[k] says what to show, and
; Durations[k] says how many frames to hold it.  The screen becomes a movie
; whose timing is data, not code.
;
; Why this works:
;   - A table is not only data to draw: Colors[k] holds COLORS, and
;     Durations[k] holds TIME.  The same LDA table,X read serves both — the
;     reader decides what the byte means.
;   - The step index lives in RAM because it has to survive from frame to
;     frame; X is loaded from it whenever a table read happens, so color k and
;     duration k are always read with the SAME index.  That is what keeps the
;     two tables in lock-step.
;   - The countdown is Lesson 09's animation clock, except that its reload
;     value now comes from a table instead of a constant: short holds for some
;     colors, long holds for others, and the program does not know which.
;   - The whole visible field is ONE COLUBK write.  The write lands in HBLANK
;     right after VBLANK is cleared — before the release line's visible
;     portion starts — and nothing touches the register again, so it paints
;     every one of the 192 visible lines.  The "picture" is free and all the
;     work is in the timing.
;
; Why the countdown sits where it does: the hold is tested during VBLANK and
; decremented after the visible field, so a color is on screen for exactly
; Durations[k] frames — the test runs on the first frame of a step, the
; decrement on the last.
;
; Frame geometry: 192 non-blanked scanlines — the beam-release line plus 191
; more from the wait loop.  The blank-on after the last visible line waits for
; HBLANK first (STA WSYNC), so the last line is painted whole.
;
; Expected screen: the full screen changes color at the frame boundary.  The
; sixteen colours step up the holds in the Durations table (8 frames up to 68),
; so each change comes noticeably later than the one before, and after the
; sixteenth step the movie starts over.  Nothing moves inside a frame — the
; animation IS the list of durations.
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
Step        = $80       ; which color/duration pair is on screen: 0...15
Hold        = $81       ; frames the current color still has to run

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
STEPS       = 16        ; steps in the movie — one per table entry
VISIBLE     = 192       ; non-blanked scanlines: the release line + 191 more
INDEX_MASK  = STEPS-1   ; 16 entries -> the mask is the last valid index

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    ; --- The movie starts at step 0: Colors[0], held for Durations[0] ---
    LDA #$00
    STA Step                ; step 0 is the first color in the table
    LDX #$00
    LDA Durations,X         ; the first step's hold, from the second table
    STA Hold                ; the countdown the frame loop will run down

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame = one step of the countdown
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK

; -----------------------------------------------------------------------------
; THE STEP: has the current hold run out?
; -----------------------------------------------------------------------------
; A color's time is up when its countdown reaches 0 — which can only happen
; after the frame that decremented it, so the color is never cut short in the
; middle of a frame.  Only then are the tables consulted for a NEW pair.
    LDA Hold                ; frames still owed to the color on screen
    BNE HoldThisStep        ; not 0 -> keep the same color this frame
    INC Step                ; the hold is over: advance to the next step
    LDA Step
    AND #INDEX_MASK         ; wrap 16 back to 0 — the step index stays in range
    STA Step
    LDX Step                ; X = the new step, for BOTH tables
    LDA Durations,X         ; how long this color gets, out of the time table
DurationFetch:              ; debugger checkpoint: break here, A = Durations[Step]
    STA Hold                ; the new countdown
HoldThisStep:
    LDX Step                ; X = the step again: the countdown above may
    LDA Colors,X            ;   have used X, and color k pairs with duration k
ColorFetch:                 ; debugger checkpoint: break here, A = Colors[Step], X = Step
    TAY                     ; park the color: +wait_timer clobbers A

    +wait_timer             ; finish the ~37 scanlines of VBLANK

    LDA #$00
    STA VBLANK              ; release the beam: the visible field starts here
    TYA                     ; A = this step's color
    STA COLUBK              ; ONE write paints all 192 visible lines

    LDX #VISIBLE-1          ; X = 191: release line + 191 = 192 visible lines
-   STA WSYNC               ; wait for the next scanline to start
    DEX                     ; one fewer line to go
    BNE -                   ; loop until the line counter reaches 0

; -----------------------------------------------------------------------------
; OVERSCAN — and the countdown
; -----------------------------------------------------------------------------
    STA WSYNC               ; wait for HBLANK before blanking: the last visible
                            ; line is being drawn right now, so writing VBLANK
                            ; here would clip it partway across
    LDA #$02
    STA VBLANK
    +set_timer 35           ; ~30 scanlines of overscan
    +wait_timer

    DEC Hold                ; this frame is done: one frame less to hold
    JMP StartFrame          ; next frame — same color, or the next step

; =============================================================================
; DATA — two tables, one index: Colors[Step] is what to show,
;        Durations[Step] is how many frames to hold it
; =============================================================================
Colors:
    !byte $1A, $28, $36, $44    ; the lesson's wave colors, one at a time
    !byte $52, $60, $6E, $7C
    !byte $8A, $98, $A6, $B4
    !byte $C2, $D0, $DE, $EC
Durations:
    !byte 8, 12, 16, 20         ; frames: about 1/8 second for the first ...
    !byte 24, 28, 32, 36
    !byte 40, 44, 48, 52
    !byte 56, 60, 64, 68        ; ... and about one second for the last

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
