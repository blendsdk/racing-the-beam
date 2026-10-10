; =============================================================================
; LESSON 07 — EXERCISE 2 SOLUTION: The Bouncing Cursor
; =============================================================================
;
; Challenge: the lesson ROM wraps the bright band from the bottom band back to
; the top.  Make it BOUNCE instead: walk down, reverse at the bottom, walk up,
; reverse at the top, forever.  A direction byte in RAM decides which way the
; cursor moves on each step.
;
; Direction = 0 -> the cursor walks DOWN the ladder (Cursor + 1)
; Direction = 1 -> the cursor walks UP the ladder   (Cursor - 1)
;
; The step code tests Direction with BNE (the Z flag) to pick a path, then
; watches for the two ends of the ladder:
;
;   * walking down, CMP #7 catches the bottom band and flips Direction to 1;
;   * walking up, DEC sets N when Cursor goes from 0 to $FF, and BPL falls
;     through exactly then, so the top-band bounce flips Direction back to 0
;     and puts the cursor on band 1 for the next step.
;
; The band painter is the lesson's: eight 24-line bands, the cursor band red.
;
; Expected screen: the bright band slides down all eight positions, bounces
; off the bottom, slides back up, bounces off the top — repeating.
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- Colors ---
DARK        = $02       ; every band that is NOT the cursor band
BRIGHT      = $42       ; the cursor band

; --- Geometry ---
BANDS       = 8         ; 8 bands x 24 lines = 192 visible scanlines
LINES       = 24
BOTTOM_BAND = BANDS - 1 ; band index of the bottom band (7)
STEP_FRAMES = 30        ; frames between cursor steps (~1/2 second)

; --- RAM variables ---
Cursor      = $80       ; 0..7: which band is bright (0 = top, 7 = bottom)
StepTimer   = $81       ; frames left before the cursor moves again
Direction   = $82       ; 0 = walking down, 1 = walking up

    * = $F000

Reset:
    +clean_start

    LDA #0
    STA Cursor              ; start on the top band
    STA Direction           ; and walk downward first
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
    +wait_timer
    LDA #$00
    STA VBLANK

; --- KERNEL: eight 24-line bands (the lesson's painter) ---
    LDX #0                  ; X = band index; 0 = top band
PaintBand:
    LDA #DARK
    CPX Cursor
    BNE +
    LDA #BRIGHT
+   STA COLUBK
    LDY #LINES
-   STA WSYNC
    DEY
    BNE -

    INX
    CPX #BANDS
    BNE PaintBand

; --- OVERSCAN ---
    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer

; --- GAME LOGIC: countdown, then move the cursor one band ---
    DEC StepTimer
    BNE NoStep              ; not time to move yet
    LDA #STEP_FRAMES
    STA StepTimer

    LDA Direction           ; which way are we walking?
    BNE StepUp              ; Direction = 1 -> walking up

    ; --- walking DOWN: Cursor = Cursor + 1 ---
    INC Cursor
    LDA Cursor
    CMP #BOTTOM_BAND        ; reached the bottom band?
    BNE NoStep              ; no -> done
    LDA #1                  ; yes -> reverse at the bottom
    STA Direction
    JMP NoStep              ; done — do not fall through into the walk-up code

StepUp:
    ; --- walking UP: Cursor = Cursor - 1 ---
    DEC Cursor
    BPL NoStep              ; still on the ladder (0..7)?  N clear -> done
    LDA #1                  ; fell off the top: put the cursor on band 1...
    STA Cursor
    LDA #0                  ; ...and reverse at the top
    STA Direction
NoStep:
    JMP StartFrame

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
