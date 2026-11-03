; =============================================================================
; LESSON 24 — EXERCISE 2 SOLUTION: Sky and Ground
; =============================================================================
; Part 3: Playfield
;
; Exercise: replace the rainbow with a two-region table — blue sky above,
; dark red ground below.
;
; The technique: the color table is just data.  Ninety-six lines of $84
; (blue) followed by ninety-six lines of $46 (dark red) give a horizon at
; visible line 133 (capture y = 409).  The kernel, the castle shape, and the
; frame are unchanged.
;
; Debugger checkpoints: ColorWrite (one hit per line, A = $84 for lines
; 37-132 and $46 for 133-228).
;
; Build: acme -f plain -o build/lesson24-ex2.bin \
;        lessons/part3-playfield/24-multicolor-playfield/exercise-02-solution.asm
; Run:   stella build/lesson24-ex2.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192

ColorPtr       = $80    ; 2 bytes: the SkyGround table

    * = $F000

Reset:
    +clean_start

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the shape and the dark background ---
    LDA #$F0
    STA PF0
    LDA #$CC
    STA PF1
    LDA #$F0
    STA PF2
    LDA #$02
    STA COLUBK
    LDA #$01
    STA CTRLPF

    LDA #<SkyGround
    STA ColorPtr
    LDA #>SkyGround
    STA ColorPtr+1

    LDY #0
    +wait_timer

    LDA #$00
    STA VBLANK
VisibleStart:
    LDA (ColorPtr),Y
    STA COLUPF
ColorWrite:                 ; checkpoint: A = the color
    INY
    STA WSYNC
    CPY #VISIBLE_LINES
    BNE VisibleStart

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SKY AND GROUND — 96 lines blue, 96 lines dark red
; =============================================================================
SkyGround:
    !fill 96, $84           ; blue sky
    !fill 96, $46           ; dark red ground

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
