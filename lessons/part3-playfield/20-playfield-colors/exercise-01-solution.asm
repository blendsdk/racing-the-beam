; =============================================================================
; LESSON 20 — EXERCISE 1 SOLUTION: Swap the Score Colors
; =============================================================================
; Part 3: Playfield
;
; Exercise: swap the colors score mode paints on the two halves.
;
; The technique: score mode reads COLUP0 for the left half and COLUP1 for
; the right.  The normal state still uses COLUPF green.  Swapping the two
; constants is enough:
;
;   COLUP0 = $84 (blue)  -> the left half
;   COLUP1 = $42 (red)   -> the right half
;
; Expected: normal state green with the central gap; score state blue on
; the left, red on the right, still with the dark gap at x = 457-552 (96 px).
;
; Debugger checkpoints: CtrlWrite (A = $01 / $03, first change frame 120),
; VisibleStart (37).
;
; Build: acme -f plain -o build/lesson20-ex1.bin \
;        lessons/part3-playfield/20-playfield-colors/exercise-01-solution.asm
; Run:   stella build/lesson20-ex1.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
ANIM_FRAMES    = 120

FrameCounter   = $80
AnimState      = $81

    * = $F000

Reset:
    +clean_start

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    INC FrameCounter
    LDA FrameCounter
    CMP #ANIM_FRAMES
    BNE VblankTickDone
    LDA #$00
    STA FrameCounter
    LDA AnimState
    EOR #$01
    STA AnimState
VblankTickDone:
    LDA AnimState
    BEQ VblankNormal
    LDA #$03
    BNE VblankStoreCtrl
VblankNormal:
    LDA #$01
VblankStoreCtrl:
    STA CTRLPF
CtrlWrite:                  ; checkpoint: A = $01 / $03

    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    LDA #$3F
    STA PF2
    LDA #$C8
    STA COLUPF
    LDA #$84
    STA COLUP0              ; SWAPPED: blue on the left
    LDA #$42
    STA COLUP1              ; SWAPPED: red on the right
    LDA #$02
    STA COLUBK

    +wait_timer

    LDA #$00
    STA VBLANK
    LDX #VISIBLE_LINES
VisibleStart:
    STA WSYNC
    DEX
    BNE VisibleStart

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
