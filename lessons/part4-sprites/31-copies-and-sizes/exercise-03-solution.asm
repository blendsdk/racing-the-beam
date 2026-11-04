; =============================================================================
; LESSON 31 — EXERCISE 3 SOLUTION: Animated Modes (Stretch Goal)
; =============================================================================
; Part 4: Sprites
;
; Exercise: animate one full-height player through all eight modes.
;
; The technique: keep a 0-7 index and advance it every 60 frames; the
; visible kernel writes that index to NUSIZ0 on every line.  The pattern
; stays $18.  Each second the sprite changes from one copy to two, three,
; double width, and quad width.
;
; Build: acme -f plain -o build/lesson31-ex3.bin \
;        lessons/part4-sprites/31-copies-and-sizes/exercise-03-solution.asm
; Run:   stella build/lesson31-ex3.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
SPRITE_X       = 40
PATTERN        = $18
POS_BIAS       = 3
BandIndex      = $80
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

    LDA #(SPRITE_X + POS_BIAS)
    JSR SetHorizPos
    LDA #$42
    STA COLUP0
    LDA #$02
    STA COLUBK
    LDA #$00
    STA REFP0

    INC FrameCounter
    LDA FrameCounter
    CMP #60
    BNE NoTick
    LDA #$00
    STA FrameCounter
    INC BandIndex
    LDA BandIndex
    AND #$07
    STA BandIndex
NoTick:

    +wait_timer

    LDA #$00
    STA VBLANK
    LDX #0
VisibleStart:
LineLoop:
    LDA BandIndex
    STA NUSIZ0
    LDA #PATTERN
    STA GRP0
    STA WSYNC
    INX
    CPX #VISIBLE_LINES
    BNE LineLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

SetHorizPos:
    STA WSYNC
    SEC
Div15:
    SBC #15
    BCS Div15
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    STA WSYNC
    STA HMOVE
    RTS

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
