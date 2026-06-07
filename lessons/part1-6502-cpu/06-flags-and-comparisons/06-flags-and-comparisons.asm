; =============================================================================
; LESSON 06: Flags and Comparisons — How the CPU Decides
; =============================================================================
;
; This program demonstrates the CMP instruction and the three status flags it
; sets:  Z (zero / equal), C (carry / unsigned >=), and N (negative / bit 7).
;
; It compares three pairs of values.  For the FIRST pair it captures each of
; the three flags into RAM so you can read them in the Stella debugger.  For
; ALL three pairs it picks a color — GREEN when A >= B (carry set) or RED when
; A < B (carry clear) — and paints one screen zone per comparison.
;
; The screen therefore becomes a visual truth-table:
;   Zone 1: $40 vs $40  (equal)   -> A >= B -> GREEN
;   Zone 2: $20 vs $60  (less)    -> A <  B -> RED
;   Zone 3: $90 vs $30  (greater) -> A >= B -> GREEN
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- Color constants (NTSC) ---
GREEN       = $C8       ; "A >= B" — comparison passed
RED         = $44       ; "A <  B" — comparison failed

; --- RAM VARIABLES (RIOT RAM, $80-$FF) ---
FlagZ       = $80       ; 1 if the first compare was EQUAL      (Z flag)
FlagC       = $81       ; 1 if the first compare had A >= B     (C flag)
FlagN       = $82       ; 1 if (A - B) had bit 7 set            (N flag)
Color1      = $83       ; result color for pair 1 (equal)
Color2      = $84       ; result color for pair 2 (less)
Color3      = $85       ; result color for pair 3 (greater)

    * = $F000

Reset:
    +clean_start            ; zero RAM/TIA, set stack, CLD (binary math)

    ; -------------------------------------------------------------------------
    ; PAIR 1: $40 vs $40 (EQUAL) — capture all three flags into RAM
    ; -------------------------------------------------------------------------
    LDA #$40            ; A = $40
    CMP #$40            ; compare A with $40  (internally: A - $40, flags only)

    ; Capture Z (the equal flag).  CMP sets Z=1 when A == operand.
    LDX #$00
    BNE +              ; not equal? leave 0
    LDX #$01           ; equal -> 1
+   STX FlagZ          ; FlagZ = 1   (the values matched)

    ; Capture C (the unsigned ">=" flag).  CMP sets C=1 when A >= operand.
    LDX #$00
    BCC +              ; carry clear (A < operand)? leave 0
    LDX #$01           ; carry set (A >= operand) -> 1
+   STX FlagC          ; FlagC = 1   ($40 >= $40)

    ; Capture N (bit 7 of the subtraction result A - operand).
    LDX #$00
    BPL +              ; result positive (bit 7 = 0)? leave 0
    LDX #$01           ; result negative (bit 7 = 1) -> 1
+   STX FlagN          ; FlagN = 0   ($40 - $40 = 0, bit 7 clear)

    ; Pick pair 1's color from the carry: GREEN if A >= B, else RED.
    LDA #$40
    CMP #$40
    LDX #RED
    BCC +              ; A < B -> keep RED
    LDX #GREEN         ; A >= B -> GREEN
+   STX Color1         ; equal counts as ">=" -> GREEN

    ; -------------------------------------------------------------------------
    ; PAIR 2: $20 vs $60 (A < B) -> RED
    ; -------------------------------------------------------------------------
    LDA #$20
    CMP #$60           ; $20 - $60 borrows -> carry CLEAR
    LDX #RED
    BCC +              ; carry clear -> A < B -> RED
    LDX #GREEN
+   STX Color2

    ; -------------------------------------------------------------------------
    ; PAIR 3: $90 vs $30 (A > B) -> GREEN
    ; -------------------------------------------------------------------------
    LDA #$90
    CMP #$30           ; $90 - $30 = $60, no borrow -> carry SET
    LDX #RED
    BCC +              ; carry set -> not taken -> A >= B -> GREEN
    LDX #GREEN
+   STX Color3

; -----------------------------------------------------------------------------
; MAIN DISPLAY LOOP
; -----------------------------------------------------------------------------
StartFrame:
    +vsync                  ; 3-line VSYNC — new frame

    LDA #$02
    STA VBLANK
    +set_timer 43           ; ~37 lines of VBLANK
    +wait_timer
    LDA #$00
    STA VBLANK

    ; --- KERNEL: three 64-line zones, one per comparison result ---
    LDA Color1          ; Zone 1: pair 1 (equal)   -> GREEN
    STA COLUBK
    LDX #64
-   STA WSYNC
    DEX
    BNE -

    LDA Color2          ; Zone 2: pair 2 (less)    -> RED
    STA COLUBK
    LDX #64
-   STA WSYNC
    DEX
    BNE -

    LDA Color3          ; Zone 3: pair 3 (greater) -> GREEN
    STA COLUBK
    LDX #64
-   STA WSYNC
    DEX
    BNE -

    LDA #$02
    STA VBLANK
    +set_timer 35           ; ~30 lines of overscan
    +wait_timer

    JMP StartFrame

; --- VECTORS ---
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
