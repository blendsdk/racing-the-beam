; =============================================================================
; LESSON 05 - EXERCISE 3 SOLUTION: Detect Overflow  (Stretch Goal)
; =============================================================================
; Challenge: Add two bytes and detect whether the result OVERFLOWED past
;            $FF (i.e. it didn't fit in 8 bits). Light the screen GREEN when
;            the sum fits, RED when it overflowed — driven purely by the
;            carry flag that ADC leaves behind.
; Solution:  After CLC/ADC, the CARRY flag is the unsigned-overflow signal:
;            carry = 1 means the true sum was > 255. BCC (branch if carry
;            clear) picks the "fits" color; otherwise we fall through to the
;            "overflow" color. Flip TestA/TestB to see both outcomes.
;
; Build: acme -f plain -o build/lesson05-ex3.bin \
;        lessons/part1-6502-cpu/05-arithmetic/exercise-03-solution.asm
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- RAM ---
Sum         = $80   ; the 8-bit (wrapped) sum
Flag        = $81   ; 0 = fit, 1 = overflowed (stored for the debugger)

; --- Operands: $D0 + $50 = $120 -> overflows ($20 with carry set).
;     Try $30 + $50 instead and the screen turns green (no overflow). ---
TEST_A      = $D0
TEST_B      = $50

COLOR_OK    = $C8   ; green  — the sum fit in 8 bits
COLOR_OVER  = $44   ; red    — the sum overflowed

    * = $F000

Reset:
    +clean_start

    ; --- Add, then judge the carry ---
    LDA #TEST_A
    CLC                 ; clear carry before the add
    ADC #TEST_B         ; A = (TEST_A + TEST_B) mod 256; carry = 1 if > 255
    STA Sum             ; store the wrapped sum (debugger: $80)

    LDA #$00            ; assume "fit" (Flag = 0)
    BCC +               ; carry clear? the sum fit — keep Flag = 0
    LDA #$01            ; carry set — it overflowed; Flag = 1
+   STA Flag            ; record the outcome at $81 for inspection

StartFrame:
    +vsync
    LDA #$02
    STA VBLANK
    +set_timer 43

    ; === Choose the screen color from the overflow flag ===
    LDA #COLOR_OK       ; default to green
    LDX Flag            ; X = overflow flag
    BEQ +               ; flag == 0? keep green
    LDA #COLOR_OVER     ; flag == 1? switch to red
+   STA COLUBK          ; latch the chosen color for the whole frame
    ; === END ===

    +wait_timer
    LDA #$00
    STA VBLANK

; --- KERNEL: solid screen in the chosen color ---
; #region kernel
    LDX #192
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
