; =============================================================================
; LESSON 04 - EXERCISE 1 SOLUTION: Store Your Birth Year in RAM
; =============================================================================
; Challenge: A byte holds 0-255 ($00-$FF), but a year like 1986 is too big
;            for one byte. Store a 4-digit year as TWO bytes (high/low) in
;            RAM, then prove it worked by painting the two bytes as colors.
; Solution:  Split the year into two bytes. $1986 would be $19 (high) and
;            $86 (low). We load each half immediately and store it to RAM,
;            then read both back in the kernel to colour two screen halves.
;
; Build: acme -f plain -o build/lesson04-ex1.bin \
;        lessons/part1-6502-cpu/04-registers-and-memory/exercise-01-solution.asm
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES
; =============================================================================
YearHigh    = $80    ; high byte of the year (e.g. $19 for 1986 -> $1986)
YearLow     = $81    ; low  byte of the year (e.g. $86 for 1986 -> $1986)

; =============================================================================
; ROM START
; =============================================================================
    * = $F000

Reset:
    +clean_start

    ; --- Store a 4-digit year as two bytes ---
    ; Pick your own birth year! Here we use 1986 = $1986 in "BCD-ish" hex.
    ; (We just treat each pair of digits as one hex byte for display.)
    LDA #$19            ; high half "19"
    STA YearHigh        ; RAM $80 = $19
    LDA #$86            ; low half "86"
    STA YearLow         ; RAM $81 = $86

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

; --- KERNEL: two 96-line zones, one per stored byte ---
; #region kernel
    LDA YearHigh        ; read the high byte back from RAM $80
    STA COLUBK
    LDX #96
-   STA WSYNC
    DEX
    BNE -

    LDA YearLow         ; read the low byte back from RAM $81
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
