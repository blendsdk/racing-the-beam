; =============================================================================
; LESSON 26 — EXERCISE 3 SOLUTION: Ping-Pong (Stretch Goal)
; =============================================================================
; Part 4: Sprites
;
; Exercise: bounce the sprite between X=32 and X=128 every 60 frames.
;
; The technique: keep a two-entry table and a 0/1 index.  On the tour tick,
; EOR #1 flips the index; the same SetHorizPos routine applies the new target.
; There is no direction byte because two targets are a toggle.
;
; Build: acme -f plain -o build/lesson26-ex3.bin \
;        lessons/part4-sprites/26-horizontal-positioning/exercise-03-solution.asm
; Run:   stella build/lesson26-ex3.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
SPRITE_TOP     = 80
SPRITE_HEIGHT  = 8
POS_FRAMES     = 60

FrameCounter   = $80
PosIndex       = $81

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
    CMP #POS_FRAMES
    BNE ApplyPos
    LDA #$00
    STA FrameCounter
    LDA PosIndex
    EOR #$01
PosStep:
    STA PosIndex
ApplyPos:
    LDX PosIndex
    LDA PosTable,X
PosApply:
    JSR SetHorizPos

    LDA #$42
    STA COLUP0
    LDA #$02
    STA COLUBK
    LDA #$00
    STA NUSIZ0
    STA REFP0

    +wait_timer

    LDA #$00
    STA VBLANK
    LDX #SPRITE_TOP
VisibleStart:
TopLoop:
    STA WSYNC
    DEX
    BNE TopLoop

    LDX #0
BodyStart:
BodyLoop:
    LDA SpriteShape,X
    STA GRP0
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0
    STA WSYNC

    LDX #(VISIBLE_LINES - SPRITE_TOP - SPRITE_HEIGHT - 1)
BottomLoop:
    STA WSYNC
    DEX
    BNE BottomLoop

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
Resp0Write:
    STA RESP0
    STA WSYNC
HmoveApply:
    STA HMOVE
    RTS

PosTable:
    !byte 35, 131           ; targets 32 and 128 + 3 output-delay bias

SpriteShape:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %11011011
    !byte %11111111
    !byte %00100100
    !byte %01011010
    !byte %10100101

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
