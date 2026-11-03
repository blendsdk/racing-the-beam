; =============================================================================
; LESSON 22 — EXERCISE 2 SOLUTION: A One-Sided Gate
; =============================================================================
; Part 3: Playfield
;
; Exercise: open the gate on the right half only, leaving the left wall
; closed.
;
; The technique: combine Lesson 22's state machine with Lesson 21's
; mid-line kernel.  Repeat mode gives the right half its own register pass;
; the left half writes a closed wall ($F0/$FF/$FF), and the right half
; writes GatePF0/$FF/$FF.  GatePF0 is the animated byte: it starts at $F0
; (chunks 20-23 on) and steps through $E0, $C0, $80, $00, opening one chunk
; per step from the center outward.
;
; The per-line ledger is the Lesson 21 shape, one cycle longer because
; LDA GatePF0 is a zero-page read (3 cycles):
;   left  writes hit 10/15/20
;   right PF0 hit 36, PF1 hit 47, PF2 hit 58; WSYNC 58-60
; All effects remain inside their windows (clock 108/141/174 vs 148/164/196).
;
; Expected: the left half solid green to the center; the right half solid
; except for a doorway of 0..4 chunks at chunks 20-23 (x = 505-600, 96 px;
; fully open state).
;
; Debugger checkpoints: GateStep (A = 0..4), Left2 (hit 20, A = $FF),
; Right0 (hit 36, A = GatePF0), VisibleStart (37).
;
; Build: acme -f plain -o build/lesson22-ex2.bin \
;        lessons/part3-playfield/22-playfield-animation/exercise-02-solution.asm
; Run:   stella build/lesson22-ex2.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
STEP_FRAMES    = 30
GATE_MAX       = 4      ; 0..4 open chunks on the right

GateState      = $80
GateDir        = $81
FrameCounter   = $82
GatePF0        = $83

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

; --- the gate tick: 0..4 and back, one step every 30 frames ---
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
GateStep:                   ; checkpoint: A = the new state
    CMP #GATE_MAX
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
    LDA GatePF0Table,X
    STA GatePF0             ; the right half's animated PF0
    LDA #$C8
    STA COLUPF
    LDA #$02
    STA COLUBK
    LDA #$00
    STA CTRLPF              ; repeat: the halves are independent

    LDX #VISIBLE_LINES
    +wait_timer

; --- visible: the Lesson 21 mid-line kernel, one-sided gate ---
    LDA #$00
    STA VBLANK
VisibleStart:               ; checkpoint: the picture's first line (37)
    LDA #$F0                ; 5-6    left PF0
    STA PF0                 ; 7-9
Left0:
    LDA #$FF                ; 10-11  left PF1
    STA PF1                 ; 12-14
Left1:
    LDA #$FF                ; 15-16  left PF2: the left wall stays closed
    STA PF2                 ; 17-19
Left2:                      ; checkpoint: hit 20, A = $FF
    NOP
    NOP
    NOP
    NOP
    NOP                     ; 20-29
    LDA GatePF0             ; 30-32  right PF0: the animated doorway
    STA PF0                 ; 33-35
Right0:                     ; checkpoint: hit 36, A = GatePF0
    NOP
    NOP
    NOP                     ; 36-41
    LDA #$FF                ; 42-43  right PF1
    STA PF1                 ; 44-46
Right1:                     ; checkpoint: hit 47
    NOP
    NOP
    NOP                     ; 47-52
    LDA #$FF                ; 53-54  right PF2
    STA PF2                 ; 55-57
Right2:                     ; checkpoint: hit 58
    STA WSYNC               ; 58-60  write 60, park 61-75
    DEX
    BNE VisibleStart

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

GatePF0Table:
    !byte $F0, $E0, $C0, $80, $00

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
