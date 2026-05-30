; =============================================================================
; LESSON 04 - EXERCISE 2 SOLUTION: Swap Two RAM Values Using A as Temp
; =============================================================================
; Challenge: You have two values in RAM. Swap them so each address ends up
;            holding the other's value — using the accumulator as a temporary
;            holding spot (just like `let t = a; a = b; b = t;` in TS).
; Solution:  The 6502 has no "swap memory" instruction, so we shuttle bytes
;            through registers. The classic three-step swap needs a temp; we
;            use A for one value and X for the other, then write them back
;            crossed over. We PROVE the swap by painting before/after colors:
;            after the swap, the TOP zone shows what used to be in Slot B and
;            the BOTTOM zone shows what used to be in Slot A.
;
; Build: acme -f plain -o build/lesson04-ex2.bin \
;        lessons/part1-6502-cpu/04-registers-and-memory/exercise-02-solution.asm
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES
; =============================================================================
SlotA       = $80    ; starts as $42 (red),   ends as $C8 (green)
SlotB       = $81    ; starts as $C8 (green), ends as $42 (red)

; =============================================================================
; ROM START
; =============================================================================
    * = $F000

Reset:
    +clean_start

    ; --- Set up the two values we want to swap ---
    LDA #$42            ; red
    STA SlotA           ; RAM $80 = $42
    LDA #$C8            ; green
    STA SlotB           ; RAM $81 = $C8

    ; --- The swap ---
    ; We need BOTH old values held somewhere before we overwrite either RAM
    ; byte. Load A from SlotA and X from SlotB first, THEN store them crossed.
    LDA SlotA           ; A = $42 (old SlotA)   <- the "temp" for SlotA
    LDX SlotB           ; X = $C8 (old SlotB)   <- the "temp" for SlotB
    STX SlotA           ; RAM $80 = $C8  (SlotA now holds old SlotB)
    STA SlotB           ; RAM $81 = $42  (SlotB now holds old SlotA)

; =============================================================================
; MAIN LOOP
; =============================================================================
StartFrame:
    +vsync

    LDA #$02
    STA VBLANK
    +set_timer 43
    +wait_timer
    LDA #$00
    STA VBLANK

; --- KERNEL: top half shows SlotA, bottom half shows SlotB (after swap) ---
; #region kernel
    LDA SlotA           ; read SlotA back: now $C8 (green) thanks to the swap
    STA COLUBK
    LDX #96
-   STA WSYNC
    DEX
    BNE -

    LDA SlotB           ; read SlotB back: now $42 (red)
    STA COLUBK
    LDX #96
-   STA WSYNC
    DEX
    BNE -
; #endregion kernel

    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer

    JMP StartFrame

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
