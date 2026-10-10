; =============================================================================
; LESSON 07 — EXERCISE 3 SOLUTION: Out of Reach (Stretch Goal)
; =============================================================================
;
; Challenge: make the cursor CRAWL — one band every ~2 seconds — by timing
; the steps with ONE countdown loop that wraps the whole frame, then close
; that loop with a branch back to the top.
;
; The natural way to write the countdown is:
;
;       DEC StepTimer
;       BNE StartFrame          ; <-- ACME: "Target out of range (-206; ...)"
;
; The frame body here is more than 200 bytes long (this version paints the
; eight bands INLINE — one +paint_band expansion per band — the way a
; cycle-exact kernel unrolls a loop), and a branch can only reach about
; ±127 bytes.  A plain BNE simply cannot jump back to StartFrame.
;
; The fix is the branch-else-jump idiom: invert the branch so the target is a
; SHORT forward hop, and use JMP for the long way back:
;
;       DEC StepTimer
;       BEQ StepCursor          ; short hop forward: countdown finished
;       JMP StartFrame          ; long jump back: paint another frame
;
; Note the direction of the thinking: we ask the opposite question ("is the
; countdown finished?") so the conditional jump is short and the unconditional
; jump is long.  JMP has no range limit at all.
;
; Expected screen: exactly the lesson's eight-band ladder, but the bright band
; now steps once every 120 frames — about two seconds — instead of every half
; second.
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
STEP_FRAMES = 120       ; frames between cursor steps (~2 seconds at 60 Hz)

; --- RAM variables ---
Cursor      = $80       ; 0..7: which band is bright (0 = top band)
StepTimer   = $81       ; frames left before the cursor moves again

; =============================================================================
; MACRO: paint one band, inline
; =============================================================================
; Each +paint_band invocation pastes this block once, with .band standing in
; for the band's index — that is how a loop gets "unrolled" into straight-line
; code.  It is exactly the painter the lesson ROM runs inside its band loop,
; with the loop's counter replaced by a constant.
; =============================================================================
!macro paint_band .band {
    LDX #.band              ; X = this band's index
    LDA #DARK               ; assume a dark band...
    CPX Cursor              ; ...unless this is the cursor band
    BNE +
    LDA #BRIGHT
+   STA COLUBK
    LDY #LINES              ; 24 scanlines in this band
-   STA WSYNC
    DEY
    BNE -
}

    * = $F000

Reset:
    +clean_start

    LDA #0
    STA Cursor              ; start with the bright band at the top
    LDA #STEP_FRAMES
    STA StepTimer

; =============================================================================
; MAIN LOOP — one pass = one frame; the countdown wraps the whole frame
; =============================================================================
StartFrame:
    +vsync

    LDA #$02
    STA VBLANK
    +set_timer 43
    +wait_timer
    LDA #$00
    STA VBLANK

; --- KERNEL: eight bands, painted INLINE (no band loop) ---
    +paint_band 0           ; the top band
    +paint_band 1
    +paint_band 2
    +paint_band 3
    +paint_band 4
    +paint_band 5
    +paint_band 6
    +paint_band 7           ; the bottom band

; --- OVERSCAN ---
    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer

; --- COUNTDOWN: the loop body above is far too long for a branch back ---
    DEC StepTimer           ; one frame less to wait
    BEQ StepCursor          ; countdown finished -> go move the cursor
    JMP StartFrame          ; not yet -> another frame (BNE cannot reach)

StepCursor:
    INC Cursor              ; walk the bright band down one band
    LDA Cursor
    CMP #BANDS              ; walked past the bottom band (7)?
    BNE +
    LDA #0                  ; yes -> wrap back to the top band
    STA Cursor
+   LDA #STEP_FRAMES        ; reload the countdown
    STA StepTimer
    JMP StartFrame          ; and keep crawling

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
