; =============================================================================
; LESSON 30 — EXERCISE 3 SOLUTION: A 16-Pixel Character (Stretch Goal)
; =============================================================================
; Part 4: Sprites
;
; Exercise: combine two players into a 16-pixel-wide, two-color character.
;
; The technique: place P0 at X=64 and P1 at X=72 — adjacent 8-pixel halves
; of one 16-pixel figure.  Each has its own 16-row shape table and its own
; color (COLUP0 red, COLUP1 blue).  Two coarse routines set HMP0/HMP1 and
; strobe RESP0/RESP1, then one HMOVE applies both fine offsets (the
; one-HMOVE rule from Lesson 28).
;
; Build: acme -f plain -o build/lesson30-ex3.bin \
;        lessons/part4-sprites/30-multicolor-sprites/exercise-03-solution.asm
; Run:   stella build/lesson30-ex3.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
SPRITE_TOP     = 80
SPRITE_HEIGHT  = 16
P0_X           = 64
P1_X           = 72
POS_BIAS       = 3

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
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1

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
    LDA ShapeP0,X
    STA GRP0
    LDA ShapeP1,X
    STA GRP1
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0
    STA GRP1
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

; =============================================================================
; COARSE POSITIONING — two players, one HMOVE
; =============================================================================
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

; =============================================================================
; SHAPES — two 16-row halves of a 16-pixel figure
; =============================================================================
ShapeP0:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %01111110
    !byte %00111100
    !byte %01111110
    !byte %11111111
    !byte %11111111
    !byte %11111111
    !byte %01111110
    !byte %01111110
    !byte %00111100
    !byte %00100100
    !byte %00100100
    !byte %01100110
    !byte %11000011

ShapeP1:
    !byte %00000000
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %01111110
    !byte %11111111
    !byte %11111111
    !byte %11111111
    !byte %11111111
    !byte %01111110
    !byte %00111100
    !byte %00011000
    !byte %00100100
    !byte %00100100
    !byte %01100110
    !byte %11000011

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
