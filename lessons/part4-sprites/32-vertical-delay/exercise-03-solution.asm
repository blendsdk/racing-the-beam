; =============================================================================
; LESSON 32 — EXERCISE 3 SOLUTION: Moving with VDEL (Stretch Goal)
; =============================================================================
; Part 4: Sprites
;
; Exercise: move the delayed sprite down 4 lines every 30 frames and show
; that the one-line offset does not accumulate.
;
; The technique: make the top count a variable (SpriteTop, 40-120) and
; compute the bottom count as 192 - SpriteTop - 16 - 1.  VDELP1 stays on;
; P0 and P1 move together, P1 always one line lower.  The offset is a latch,
; not a velocity.
;
; Build: acme -f plain -o build/lesson32-ex3.bin \
;        lessons/part4-sprites/32-vertical-delay/exercise-03-solution.asm
; Run:   stella build/lesson32-ex3.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
SPRITE_HEIGHT  = 16
P0_X           = 48
P1_X           = 104
POS_BIAS       = 3
TOP_MIN        = 40
TOP_MAX        = 120
STEP_FRAMES    = 30

SpriteTop      = $80
BottomCount    = $81
FrameCounter   = $82

    * = $F000

Reset:
    +clean_start
    LDA #80
    STA SpriteTop

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
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1
    LDA #$01
    STA VDELP1

    INC FrameCounter
    LDA FrameCounter
    CMP #STEP_FRAMES
    BNE VDone
    LDA #$00
    STA FrameCounter
    LDA SpriteTop
    CLC
    ADC #4
    CMP #(TOP_MAX + 1)
    BCC StoreTop
    LDA #TOP_MIN
StoreTop:
    STA SpriteTop
VDone:
    LDA #(VISIBLE_LINES - SPRITE_HEIGHT - 1)
    SEC
    SBC SpriteTop
    STA BottomCount

    +wait_timer

    LDA #$00
    STA VBLANK
    LDX SpriteTop
VisibleStart:
TopLoop:
    STA WSYNC
    DEX
    BNE TopLoop

    LDX #0
BodyStart:
BodyLoop:
    LDA Shape,X
    STA GRP0
    LDA Shape,X
    STA GRP1
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0                ; trigger the delayed copy of the last row
    STA GRP1                ; then clear the primary
    STA WSYNC

    LDX BottomCount
BottomLoop:
    STA GRP0                ; keep triggering the delayed copy with 0
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

Shape:
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
