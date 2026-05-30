; =============================================================================
; LESSON 04 - EXERCISE 3 SOLUTION (STRETCH): The Register Relay
; =============================================================================
; Challenge: Move a single value through ALL THREE registers using the
;            transfer instructions (no extra LDA/LDX/LDY from memory), then
;            store the result. Bonus: read it back using ABSOLUTE addressing
;            instead of zero-page to see the third addressing mode in action.
; Solution:  Load the value into A once, then relay it A -> X -> (back to A)
;            -> Y using TAX, TXA, TAY. Store Y to RAM. In the kernel we read
;            the byte back with an ABSOLUTE address ($0080 instead of $80) to
;            prove both addressing modes reach the same RIOT RAM byte.
;
; Transfer instructions used:
;   TAX = Transfer A to X     TXA = Transfer X to A
;   TAY = Transfer A to Y     TYA = Transfer Y to A
;
; Build: acme -f plain -o build/lesson04-ex3.bin \
;        lessons/part1-6502-cpu/04-registers-and-memory/exercise-03-solution.asm
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES
; =============================================================================
RelayColor  = $80    ; the value after it has toured all three registers

; =============================================================================
; ROM START
; =============================================================================
    * = $F000

Reset:
    +clean_start

    ; --- The relay: one value visits A, then X, then Y ---
    LDA #$3C            ; A = $3C (a warm yellow). Loaded ONCE from immediate.
    TAX                 ; X = A   (now both A and X hold $3C)
    INX                 ; X = $3D — tweak it so we can prove X really carried
    TXA                 ; A = X   ($3D) — relay back into the accumulator
    TAY                 ; Y = A   ($3D)
    STY RelayColor      ; RAM $80 = Y = $3D                       [zero-page]

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

; --- KERNEL: whole screen shows the relayed value, read via ABSOLUTE mode ---
; #region kernel
    ; $0080 is the SAME byte as zero-page $80 — but written as a full 16-bit
    ; address it assembles to an ABSOLUTE-mode instruction (3 bytes, 4 cycles)
    ; instead of zero-page (2 bytes, 3 cycles). Same data, slower encoding.
    LDA $0080           ; read RelayColor using ABSOLUTE addressing
    STA COLUBK
    LDX #192            ; one solid color zone for the whole visible screen
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
