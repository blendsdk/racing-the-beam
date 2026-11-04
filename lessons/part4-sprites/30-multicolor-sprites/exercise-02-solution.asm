; =============================================================================
; LESSON 30 — EXERCISE 2 SOLUTION: Sliding Bands
; =============================================================================
; Part 4: Sprites
;
; Exercise: slide the color bands while the shape stays still.
;
; The technique: keep a 0-15 ColorOffset and read ColorBands[(offset + row)
; & 15].  A 30-frame tick increments the offset.  The shape table never
; changes, which is the point: color and shape are independent.
;
; Build: acme -f plain -o build/lesson30-ex2.bin \
;        lessons/part4-sprites/30-multicolor-sprites/exercise-02-solution.asm
; Run:   stella build/lesson30-ex2.bin
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

ColorOffset    = $80    ; 0-15, the band rotation
FrameCounter   = $81

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

    INC FrameCounter
    LDA FrameCounter
    CMP #30
    BNE NoBandTick
    LDA #$00
    STA FrameCounter
    INC ColorOffset
    LDA ColorOffset
    AND #$0F
    STA ColorOffset
NoBandTick:

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
    TXA
    CLC
    ADC ColorOffset
    AND #$0F
    TAY
    LDA ColorBands,Y
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
