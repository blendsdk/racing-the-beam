; =============================================================================
; LESSON 07 — EXERCISE 1 SOLUTION: Twelve Bands, Counted Down
; =============================================================================
;
; Challenge: turn the lesson's 8-band ladder into a TWELVE-band ladder, so
; every band is 16 scanlines tall (12 x 16 = 192 visible lines at 60 Hz), and
; paint it with a count-down loop instead of the lesson's count-up loop.
;
; The count-down band loop:
;
;       LDX #11                 ; the top band's index
;   Loop:
;       ... paint band index X ...
;       DEX                     ; count down: 11, 10, ... 1, 0
;       BPL Loop                ; branch while N is clear -> all 12 bands
;
; DEX updates N and Z from the result, so BPL ("branch on N clear") keeps
; looping while X is still 0..127.  The band painted FIRST appears at the TOP
; of the screen, so here band 11 is the top and band 0 is the bottom.
;
; That flips the cursor's direction: it counts DOWN from 11 to 0 and wraps
; back to 11.  Its wrap test watches the N flag: when DEC takes the cursor
; from 0 to $FF, bit 7 turns on and the following BPL falls through, so we
; reset the cursor to 11.
;
; Expected screen: twelve equal bands, one bright red, walking DOWN the screen
; and looping from the bottom back to the top — the same idea as the lesson
; ROM, built from a count-down loop and an N-flag branch.
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- Colors ---
DARK        = $02       ; every band that is NOT the cursor band
BRIGHT      = $42       ; the cursor band

; --- Geometry ---
BANDS       = 12        ; 12 bands x 16 lines = 192 visible scanlines
LINES       = 16
TOP_BAND    = BANDS - 1 ; band index of the top band (11)
STEP_FRAMES = 30        ; frames between cursor steps (~1/2 second)

; --- RAM variables ---
Cursor      = $80       ; 11..0: which band is bright (11 = top, 0 = bottom)
StepTimer   = $81       ; frames left before the cursor moves again

    * = $F000

Reset:
    +clean_start

    LDA #TOP_BAND
    STA Cursor              ; start with the bright band at the top
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

; --- KERNEL: twelve 16-line bands, counted DOWN ---
    LDX #TOP_BAND           ; X = 11: the top band is painted first
PaintBand:
    LDA #DARK               ; assume a dark band...
    CPX Cursor              ; ...unless X is the cursor band
    BNE +
    LDA #BRIGHT
+   STA COLUBK

    LDY #LINES              ; 16 scanlines in this band
-   STA WSYNC
    DEY
    BNE -

    DEX                     ; count down: 11, 10, ... 1, 0
    BPL PaintBand           ; N clear -> still on the ladder, so loop

; --- OVERSCAN ---
    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer

; --- GAME LOGIC: the cursor counts down too ---
    DEC StepTimer
    BNE NoStep
    LDA #STEP_FRAMES
    STA StepTimer
    DEC Cursor              ; move the bright band one band DOWN the screen
    BPL NoStep              ; still 0..11?  N clear -> nothing to fix
    LDA #TOP_BAND           ; DEC went 0 -> $FF: wrap back to the top band
    STA Cursor
NoStep:
    JMP StartFrame

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
