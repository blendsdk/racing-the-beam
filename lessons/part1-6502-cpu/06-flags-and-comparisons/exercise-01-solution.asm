; =============================================================================
; LESSON 06 — EXERCISE 1 SOLUTION: Predict the Flags
; =============================================================================
;
; Challenge: For each of three comparisons, work out on paper what the Z, C,
; and N flags will be — then prove it by capturing them into RAM and reading
; them in the Stella debugger.
;
; We compare A = $50 against three operands and record (Z, C, N) for each:
;
;   CMP #$50  ($50 - $50 = $00)   -> Z=1  C=1  N=0   (equal)
;   CMP #$80  ($50 - $80 borrows) -> Z=0  C=0  N=1   (A < operand, bit7 set)
;   CMP #$10  ($50 - $10 = $40)   -> Z=0  C=1  N=0   (A > operand)
;
; RAM layout (read these in the debugger after reset):
;   $80,$81,$82 = Z,C,N for compare #1
;   $83,$84,$85 = Z,C,N for compare #2
;   $86,$87,$88 = Z,C,N for compare #3
;
; A small local macro keeps the flag-capture boilerplate readable.  It assumes
; a CMP was just executed and writes 0/1 for Z, C, N into three RAM bytes.
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- Local helper: snapshot Z, C, N into .base, .base+1, .base+2 ---
!macro capture_flags .base {
    LDX #$00            ; Z flag -> .base
    BNE +
    LDX #$01
+   STX .base
    LDX #$00            ; C flag -> .base+1
    BCC +
    LDX #$01
+   STX .base+1
    LDX #$00            ; N flag -> .base+2
    BPL +
    LDX #$01
+   STX .base+2
}

    * = $F000

Reset:
    +clean_start

    ; --- Compare #1: $50 vs $50 ---
    LDA #$50
    CMP #$50
    +capture_flags $80     ; expect Z=1 C=1 N=0

    ; --- Compare #2: $50 vs $80 ---
    LDA #$50
    CMP #$80
    +capture_flags $83     ; expect Z=0 C=0 N=1

    ; --- Compare #3: $50 vs $10 ---
    LDA #$50
    CMP #$10
    +capture_flags $86     ; expect Z=0 C=1 N=0

StartFrame:
    +vsync
    LDA #$02
    STA VBLANK
    +set_timer 43
    +wait_timer
    LDA #$00
    STA VBLANK

    ; Paint the screen a calm blue — this exercise is read in the debugger.
    LDA #$84
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
