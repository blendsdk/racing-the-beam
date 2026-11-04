; =============================================================================
; LESSON 30: Multi-Color Sprites — Changing Colors Per Line — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Draws one 8x16 character with three color bands: a gold hat (rows 0-3),
;   a blue body (rows 4-11), and red legs (rows 12-15).  COLUP0 is written
;   every scanline from a 16-byte table, so a single player shows three
;   colors without a second object.
;
; The idea:
;   COLUP0 is a normal TIA color register.  The beam reads it when it draws
;   the player, so a write in HBLANK sets the color of that whole line.  A
;   table with one byte per line gives the sprite as many colors as it has
;   rows; the shape and the colors are independent tables.
;
;   This is the same per-line color technique Lesson 24 used for the
;   playfield, now applied to a player instead of COLUPF.
;
; The two tables:
;   Shape     16 bytes, one per row; bit 7 is the leftmost pixel.
;   ColorBands 16 bytes: 4 x $1A (gold), 8 x $84 (blue), 4 x $42 (red).
;
; The per-line body:
;   LDA ColorBands,X   4   (this row's color)
;   STA COLUP0         3
;   LDA Shape,X        4
;   STA GRP0           3
;   STA WSYNC          3
;   INX / CPX / BNE    7
;   ---------------------------------
;   total             24 of 76 cycles
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; The sprite starts at visible line 80 (scanline 117): 80 top + 16 body +
; 1 clear + 95 bottom = 192.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VisibleStart (37), BodyStart (117,
;   16 hits), ColorWrite (A = the color byte, 16 hits), SpriteWrite (A = the
;   shape byte, 16 hits), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson30.bin \
;        lessons/part4-sprites/30-multicolor-sprites/30-multicolor-sprites.asm
; Run:   stella build/lesson30.bin
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
    !byte $1A, $1A, $1A, $1A              ; gold hat
    !byte $84, $84, $84, $84, $84, $84, $84, $84   ; blue body
    !byte $42, $42, $42, $42              ; red legs

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
