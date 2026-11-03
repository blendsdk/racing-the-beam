; =============================================================================
; LESSON 22 — EXERCISE 3 SOLUTION: A Scrolling Wall (Stretch Goal)
; =============================================================================
; Part 3: Playfield
;
; Exercise: scroll the wall pattern horizontally, one chunk per step.
;
; The technique: precompute all twenty rotations of a 20-bit crenellated
; pattern and store them as (PF0, PF1, PF2) triples.  A frame counter
; advances the index every 10 frames (~1/6 s); the visible kernel is the
; hold used throughout Part 3.  Repeat mode (CTRLPF = $00) makes the right
; half repeat the left, so the whole wall slides as one piece.
;
; The base pattern is a crenellated wall:
;   PF0 = $F0, PF1 = $CC, PF2 = $3F  ->  chunks 11111100110011111100
; (A solid wall would look static when shifted; the notches are what the
; eye follows.)  The twenty entries cover every rotation exactly, so the
; sequence wraps without a jump: 20 steps x 10 frames = 200 frames
; (~3.3 s) per revolution.
;
; Debugger checkpoints: ScrollStep (A = the new 0..19 index, every 10
; frames), PatternWrite (A = the PF2 byte), VisibleStart (37).
;
; Build: acme -f plain -o build/lesson22-ex3.bin \
;        lessons/part3-playfield/22-playfield-animation/exercise-03-solution.asm
; Run:   stella build/lesson22-ex3.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
STEP_FRAMES    = 10     ; one chunk per ~1/6 s

ScrollIndex    = $80    ; 0..19
FrameCounter   = $81

    * = $F000

Reset:
    +clean_start

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- advance the scroll one chunk every STEP_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #STEP_FRAMES
    BNE VblankSetPattern
    LDA #$00
    STA FrameCounter
    INC ScrollIndex
    LDA ScrollIndex
    CMP #20
    BNE ScrollStep
    LDA #$00
    STA ScrollIndex
ScrollStep:                 ; checkpoint: A = the new 0..19 index

; --- fetch the triple (offset = index x 3) ---
VblankSetPattern:
    LDA ScrollIndex
    ASL
    CLC
    ADC ScrollIndex
    TAY
    LDA PatternTable,Y
    STA PF0
    LDA PatternTable+1,Y
    STA PF1
    LDA PatternTable+2,Y
    STA PF2
PatternWrite:               ; checkpoint: A = the PF2 byte
    LDA #$C8
    STA COLUPF
    LDA #$02
    STA COLUBK
    LDA #$00
    STA CTRLPF              ; repeat: both halves slide together

    LDX #VISIBLE_LINES
    +wait_timer

    LDA #$00
    STA VBLANK
VisibleStart:               ; checkpoint: the picture's first line (37)
    STA WSYNC
    DEX
    BNE VisibleStart

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SCROLL TABLE — all twenty rotations of the crenellated pattern
; =============================================================================
PatternTable:
    !byte $F0, $CC, $3F     ; shift 0
    !byte $E0, $E6, $7E     ; shift 1
    !byte $C0, $F3, $FC     ; shift 2
    !byte $90, $F9, $F9     ; shift 3
    !byte $30, $FC, $F3     ; shift 4
    !byte $70, $7E, $E6     ; shift 5
    !byte $F0, $3F, $CC     ; shift 6
    !byte $F0, $9F, $99     ; shift 7
    !byte $F0, $CF, $33     ; shift 8
    !byte $E0, $E7, $67     ; shift 9
    !byte $C0, $F3, $CF     ; shift 10
    !byte $90, $F9, $9F     ; shift 11
    !byte $30, $FC, $3F     ; shift 12
    !byte $60, $7E, $7E     ; shift 13
    !byte $C0, $3F, $FC     ; shift 14
    !byte $90, $9F, $F9     ; shift 15
    !byte $30, $CF, $F3     ; shift 16
    !byte $70, $67, $E7     ; shift 17
    !byte $F0, $33, $CF     ; shift 18
    !byte $F0, $99, $9F     ; shift 19

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
