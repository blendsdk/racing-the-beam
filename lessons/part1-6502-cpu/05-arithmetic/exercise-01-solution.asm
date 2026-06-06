; =============================================================================
; LESSON 05 - EXERCISE 1 SOLUTION: Add Two 16-Bit Numbers
; =============================================================================
; Challenge: A single byte tops out at 255. Add two 16-bit numbers
;            ($01F0 + $0220 = $0410) by adding the low bytes, then the high
;            bytes with the carry chained between them. Prove it worked by
;            showing both result bytes as colored zones.
; Solution:  CLC before the LOW-byte ADC; then add the HIGH bytes WITHOUT
;            clearing carry, so the carry out of the low add folds in.
;
; Build: acme -f plain -o build/lesson05-ex1.bin \
;        lessons/part1-6502-cpu/05-arithmetic/exercise-01-solution.asm
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- RAM ---
NumLo1  = $80   ; low  byte of first  number
NumHi1  = $81   ; high byte of first  number
NumLo2  = $82   ; low  byte of second number
NumHi2  = $83   ; high byte of second number
ResLo   = $84   ; low  byte of the 16-bit result
ResHi   = $85   ; high byte of the 16-bit result

    * = $F000

Reset:
    +clean_start

    ; First number  = $01F0
    LDA #$F0
    STA NumLo1
    LDA #$01
    STA NumHi1

    ; Second number = $0220
    LDA #$20
    STA NumLo2
    LDA #$02
    STA NumHi2

    ; --- 16-bit addition ---
    LDA NumLo1          ; low byte of #1
    CLC                 ; clear carry before the FIRST add
    ADC NumLo2          ; $F0 + $20 = $110 -> A = $10, carry = 1
    STA ResLo           ; ResLo = $10
    LDA NumHi1          ; high byte of #1
    ADC NumHi2          ; $01 + $02 + carry(1) = $04   (no CLC here!)
    STA ResHi           ; ResHi = $04  ->  result = $0410 (1040 decimal)

StartFrame:
    +vsync
    LDA #$02
    STA VBLANK
    +set_timer 43
    +wait_timer
    LDA #$00
    STA VBLANK

; --- KERNEL: two 96-line zones (high byte on top, low byte on bottom) ---
; #region kernel
    LDA ResHi           ; $04
    STA COLUBK
    LDX #96
-   STA WSYNC
    DEX
    BNE -

    LDA ResLo           ; $10
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

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
