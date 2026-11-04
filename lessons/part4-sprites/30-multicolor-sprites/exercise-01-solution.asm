; =============================================================================
; LESSON 30 — EXERCISE 1 SOLUTION: White Shoes
; =============================================================================
; Part 4: Sprites
;
; Exercise: add a fourth color band for shoes.
;
; The technique: the color table is data.  Split the 16 rows into 4 hat,
; 7 body, 3 legs, and 2 shoes: 4 x $1A, 7 x $84, 3 x $42, 2 x $0E.  The
; shape table is unchanged; only the colors move.
;
; Build: acme -f plain -o build/lesson30-ex1.bin \
;        lessons/part4-sprites/30-multicolor-sprites/exercise-01-solution.asm
; Run:   stella build/lesson30-ex1.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
SPRITE_TOP     = 80
SPRITE_HEIGHT  = 16
SPRITE_X       = 72
POS_BIAS       = 3

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
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
    LDA #$02
    STA COLUBK
    LDA #$00
    STA NUSIZ0
    STA REFP0

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — 16 rows, a color write and a graphic write per row
; -----------------------------------------------------------------------------
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
    LDA ColorBands,X
ColorWrite:                 ; checkpoint: A = this row's color
    STA COLUP0
    LDA Shape,X
SpriteWrite:                ; checkpoint: A = this row's shape
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

; =============================================================================
; SET HORIZONTAL POSITION — the Lesson 26 routine, with the +3 bias
; =============================================================================
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

; =============================================================================
; TABLES — 16 shape bytes and 16 color bytes
; =============================================================================
Shape:
    !byte %00011000         ; row 0  (hat)
    !byte %00111100         ; 1
    !byte %01111110         ; 2
    !byte %01111110         ; 3
    !byte %00111100         ; 4  (body)
    !byte %01111110         ; 5
    !byte %11111111         ; 6
    !byte %11111111         ; 7
    !byte %11111111         ; 8
    !byte %01111110         ; 9
    !byte %01111110         ; 10
    !byte %00111100         ; 11
    !byte %00100100         ; 12 (legs)
    !byte %00100100         ; 13
    !byte %01100110         ; 14
    !byte %11000011         ; 15

ColorBands:
    !byte $1A, $1A, $1A, $1A              ; gold hat (4 rows)
    !byte $84, $84, $84, $84, $84, $84, $84   ; blue body (7 rows)
    !byte $42, $42, $42                   ; red legs (3 rows)
    !byte $0E, $0E                        ; light-gray shoes (2 rows)

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
