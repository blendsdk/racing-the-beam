; =============================================================================
; LESSON 26 — EXERCISE 2 SOLUTION: The Far Right
; =============================================================================
; Part 4: Sprites
;
; Exercise: put the sprite at X=152 and explain the quotient.
;
; The technique: the program passes 155 (152 + the 3-pixel bias).  155 = 10 x
; 15 + 5, so the loop subtracts 11 times and exits with A = 5 - 15 = $F6.
; EOR #7 and four ASLs produce HMP0 = $10 (+1 clock, left); the coarse
; position is 153 and the fine motion moves it to 152.  The sprite's left
; edge lands at TIA X=152 (capture x=937), and the 8-pixel sprite spans to
; x=984 — the right edge of the picture.
;
; Build: acme -f plain -o build/lesson26-ex2.bin \
;        lessons/part4-sprites/26-horizontal-positioning/exercise-02-solution.asm
; Run:   stella build/lesson26-ex2.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
SPRITE_TOP     = 80
SPRITE_HEIGHT  = 8

    * = $F000

Reset:
    +clean_start

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    LDA #155                ; target 152 + 3 output-delay bias
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
