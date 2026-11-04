; =============================================================================
; LESSON 31 — EXERCISE 2 SOLUTION: Two Players, Two Modes
; =============================================================================
; Part 4: Sprites
;
; Exercise: top half P0 with three close copies (NUSIZ0=3), bottom half P1
; with three medium copies (NUSIZ1=6).
;
; The technique: two players at different X, two coarse routines and one
; HMOVE (the Lesson 28 rule).  The top 96 lines draw P0 only; the bottom 96
; draw P1 only.  The pattern is $18 in both halves.
;
; Build: acme -f plain -o build/lesson31-ex2.bin \
;        lessons/part4-sprites/31-copies-and-sizes/exercise-02-solution.asm
; Run:   stella build/lesson31-ex2.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
P0_X           = 32
P1_X           = 88
POS_BIAS       = 3
PATTERN        = $18

    * = $F000

Reset:
    +clean_start

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    LDA #(P0_X + POS_BIAS)
    JSR SetCoarse0
    LDA #(P1_X + POS_BIAS)
    JSR SetCoarse1
    STA WSYNC
    STA HMOVE

    LDA #$42
    STA COLUP0
    LDA #$84
    STA COLUP1
    LDA #$02
    STA COLUBK
    LDA #$00
    STA REFP0
    STA REFP1

    +wait_timer

    LDA #$00
    STA VBLANK
    LDX #96
VisibleStart:
TopLoop:
    LDA #$03
    STA NUSIZ0              ; three close copies
    LDA #PATTERN
    STA GRP0
    LDA #$00
    STA GRP1                ; P1 off in the top half
    STA WSYNC
    DEX
    BNE TopLoop

    LDX #96
BottomLoop:
    LDA #$00
    STA GRP0                ; P0 off in the bottom half
    LDA #$06
    STA NUSIZ1              ; three medium copies
    LDA #PATTERN
    STA GRP1
    STA WSYNC
    DEX
    BNE BottomLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

SetCoarse0:
    STA WSYNC
    SEC
Div0:
    SBC #15
    BCS Div0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS

SetCoarse1:
    STA WSYNC
    SEC
Div1:
    SBC #15
    BCS Div1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
    RTS

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
