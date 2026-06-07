; =============================================================================
; LESSON 06 — EXERCISE 2 SOLUTION: Max of Two Values
; =============================================================================
;
; Challenge: Given two bytes ValA and ValB, compute the LARGER of the two and
; store it in Max — using CMP plus a single branch.  Then paint the screen with
; Max as the background color so the winner is visible, and stash Max in RAM for
; the debugger.
;
; The idea:  load ValA, CMP ValB.
;   - carry SET  => ValA >= ValB  => ValA is already the max
;   - carry CLEAR => ValA <  ValB  => load ValB instead
;
;   ValA = $30, ValB = $90  -> Max = $90
;
; This is the classic "if (a < b) a = b;" turned into one compare + one BCS.
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

ValA        = $80
ValB        = $81
Max         = $82

    * = $F000

Reset:
    +clean_start

    ; --- Inputs ---
    LDA #$30
    STA ValA
    LDA #$90
    STA ValB

    ; --- Max = max(ValA, ValB) ---
    LDA ValA            ; assume ValA is the winner
    CMP ValB            ; ValA - ValB
    BCS +              ; carry set => ValA >= ValB => keep A = ValA
    LDA ValB            ; else ValB is larger => A = ValB
+   STA Max             ; Max = $90

StartFrame:
    +vsync
    LDA #$02
    STA VBLANK
    +set_timer 43
    +wait_timer
    LDA #$00
    STA VBLANK

    ; Paint the whole screen with the winning value.
    LDA Max
    STA COLUBK
    LDX #192
-   STA WSYNC
    DEX
    BNE -

    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer
    JMP StartFrame

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
