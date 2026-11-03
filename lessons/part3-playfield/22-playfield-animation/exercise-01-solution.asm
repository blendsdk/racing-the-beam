; =============================================================================
; LESSON 22 — EXERCISE 1 SOLUTION: Faster Gate
; =============================================================================
; Part 3: Playfield
;
; Exercise: make the gate animation twice as fast.
;
; The technique: the cadence is one constant, STEP_FRAMES.  The lesson ROM
; uses 30 frames (~0.5 s per step); this solution uses 15 (~0.25 s).  The
; nine states, the direction reversal, and the picture are unchanged.
;
; At ~60 Hz a full open-close cycle drops from ~8 seconds to ~4 seconds.
;
; Debugger checkpoint: GateStep fires every 15 frames instead of 30, with
; the same 0..8..0 sequence.
;
; Build: acme -f plain -o build/lesson22-ex1.bin \
;        lessons/part3-playfield/22-playfield-animation/exercise-01-solution.asm
; Run:   stella build/lesson22-ex1.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
STEP_FRAMES    = 15     ; twice as fast as the lesson ROM

GateState      = $80
GateDir        = $81
FrameCounter   = $82

    * = $F000

Reset:
    +clean_start
    LDA #$01
    STA GateDir

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    INC FrameCounter
    LDA FrameCounter
    CMP #STEP_FRAMES
    BNE VblankSetGate
    LDA #$00
    STA FrameCounter
    LDA GateState
    CLC
    ADC GateDir
    STA GateState
GateStep:                   ; checkpoint: A = the new state, every 15 frames
    CMP #8
    BNE VblankCheckBottom
    LDA #$FF
    STA GateDir
    JMP VblankSetGate
VblankCheckBottom:
    CMP #0
    BNE VblankSetGate
    LDA #$01
    STA GateDir

VblankSetGate:
    LDX GateState
    LDA GateTable,X
    STA PF2
PF2Write:                   ; checkpoint: A = GateTable[state]
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    LDA #$C8
    STA COLUPF
    LDA #$02
    STA COLUBK
    LDA #$01
    STA CTRLPF

    LDX #VISIBLE_LINES
    +wait_timer

    LDA #$00
    STA VBLANK
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

GateTable:
    !byte $FF, $7F, $3F, $1F, $0F, $07, $03, $01, $00

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
