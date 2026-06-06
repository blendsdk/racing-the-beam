; =============================================================================
; LESSON 05: Arithmetic — Adding and Subtracting
; =============================================================================
; Part 1: The 6502 CPU
;
; What this program does:
;   A tiny "calculator" ROM. It takes two numbers in RAM and computes both
;   their SUM (ADC) and their DIFFERENCE (SBC), stores every result back to
;   RAM, then paints FOUR colored zones so you can SEE each value:
;
;     Zone 1 (top)    : NumA   ($30)
;     Zone 2          : NumB   ($12)
;     Zone 3          : Sum    = NumA + NumB = $42   (CLC then ADC)
;     Zone 4 (bottom) : Diff   = NumA - NumB = $1E   (SEC then SBC)
;
;   It also demonstrates a 16-bit ADD (two-byte addition with carry) and
;   stores the 16-bit result at SumHi/SumLo — open the debugger to inspect it.
;
; What you'll learn:
;   - CLC + ADC (add with carry) and SEC + SBC (subtract with borrow)
;   - Why you ALWAYS clear carry before an add and set carry before a subtract
;   - How the carry flag chains single-byte math into 16-bit (multi-byte) math
;   - 8-bit wraparound: results are always taken mod 256
;
; Build: acme -f plain -o build/lesson05.bin \
;        lessons/part1-6502-cpu/05-arithmetic/05-arithmetic.asm
; Run:   stella build/lesson05.bin
;
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
NumA        = $80    ; first operand
NumB        = $81    ; second operand
Sum         = $82    ; NumA + NumB  (8-bit, wraps mod 256)
Diff        = $83    ; NumA - NumB  (8-bit, borrows mod 256)

; 16-bit addition result (two bytes, low + high)
SumLo       = $84    ; low  byte of the 16-bit sum
SumHi       = $85    ; high byte of the 16-bit sum

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================

    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero all TIA registers and RAM, set the stack
                            ; (clean_start also does CLD — decimal mode OFF, so
                            ;  all of our math below is plain binary)

; =============================================================================
; THE CALCULATOR  —  runs ONCE at startup
; =============================================================================

    ; --- Set up the two operands ---
    LDA #$30            ; A = $30 (48 decimal)
    STA NumA            ; NumA = $30
    LDA #$12            ; A = $12 (18 decimal)
    STA NumB            ; NumB = $12

    ; --- ADD: Sum = NumA + NumB ---------------------------------------------
    ; RULE: clear the carry BEFORE the first/only ADC, or a stray carry from
    ;       an earlier operation would add an extra 1.
    LDA NumA            ; A = $30
    CLC                 ; carry = 0  (essential before ADC!)
    ADC NumB            ; A = A + NumB + carry = $30 + $12 + 0 = $42
    STA Sum             ; Sum = $42  (66 decimal)

    ; --- SUBTRACT: Diff = NumA - NumB ---------------------------------------
    ; RULE: SET the carry BEFORE the first/only SBC. On the 6502, carry SET
    ;       means "no borrow." Forgetting SEC subtracts an extra 1.
    LDA NumA            ; A = $30
    SEC                 ; carry = 1  (= "no borrow"; essential before SBC!)
    SBC NumB            ; A = A - NumB - (1-carry) = $30 - $12 - 0 = $1E
    STA Diff            ; Diff = $1E  (30 decimal)

    ; --- 16-BIT ADD: SumHi:SumLo = $00F0 + $0025 = $0115 --------------------
    ; The carry flag is how you chain bytes. Add the low bytes first; if they
    ; overflow past $FF the carry is set, and the high-byte ADC folds it in.
    LDA #$F0            ; low byte of first number  ($00F0)
    CLC                 ; clear carry before the low-byte add
    ADC #$25            ; $F0 + $25 = $115 -> A = $15, carry = 1 (overflowed!)
    STA SumLo           ; SumLo = $15
    LDA #$00            ; high byte of first number ($00F0 -> $00)
    ADC #$00            ; $00 + $00 + carry(1) = $01   (DO NOT clear carry here)
    STA SumHi           ; SumHi = $01  ->  full result $0115 (277 decimal)

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame
; =============================================================================
StartFrame:

; --- VSYNC (3 scanlines) ---
    +vsync

; --- VBLANK (37 scanlines) ---
    LDA #$02
    STA VBLANK
    +set_timer 43

    ; === GAME LOGIC ===
    ; Nothing changes frame-to-frame — the results are computed once at boot.
    ; === END GAME LOGIC ===

    +wait_timer
    LDA #$00
    STA VBLANK

; --- KERNEL (192 visible scanlines = 4 zones x 48 lines) ---
; Each zone reads one computed value back from RAM and shows it as a color.
; #region kernel

    ; --- Zone 1: NumA ($30) ---
    LDA NumA
    STA COLUBK
    LDX #48
-   STA WSYNC
    DEX
    BNE -

    ; --- Zone 2: NumB ($12) ---
    LDA NumB
    STA COLUBK
    LDX #48
-   STA WSYNC
    DEX
    BNE -

    ; --- Zone 3: Sum ($42) ---
    LDA Sum
    STA COLUBK
    LDX #48
-   STA WSYNC
    DEX
    BNE -

    ; --- Zone 4: Diff ($1E) ---
    LDA Diff
    STA COLUBK
    LDX #48
-   STA WSYNC
    DEX
    BNE -

; #endregion kernel

; --- OVERSCAN (30 scanlines) ---
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
