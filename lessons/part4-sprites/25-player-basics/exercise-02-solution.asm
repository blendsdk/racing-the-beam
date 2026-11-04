; =============================================================================
; LESSON 25 — EXERCISE 2 SOLUTION: Mirror the Sprite
; =============================================================================
; Part 4: Sprites
;
; Exercise: flip the invader horizontally.
;
; The technique: REFP0 bit 3 mirrors player 0.  The mirror itself needs no table
; change; only the tail is made asymmetric so the flip is visible.  The TIA reads
; each byte from the other end.  The lesson ROM's invader is
; left-right symmetric — every row is a bit-reversal palindrome — so a mirror
; of that shape would be pixel-identical.  This solution therefore gives the
; creature an asymmetric tail: the last two rows are $0F (00001111) and $F0
; (11110000).  With REFP0 set, those rows swap sides, which is the visible
; proof that the mirror happened.  The span stays 48 pixels.
;
; Debugger checkpoints: VisibleStart (37), BodyStart (117), REFP0 = $08.
;
; Build: acme -f plain -o build/lesson25-ex2.bin \
;        lessons/part4-sprites/25-player-basics/exercise-02-solution.asm
; Run:   stella build/lesson25-ex2.bin
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

    STA WSYNC
    LDX #9
PlaceDelay:
    DEX
    BNE PlaceDelay
    STA RESP0
    LDA #$42
    STA COLUP0
    LDA #$02
    STA COLUBK
    LDX #$00
    STX NUSIZ0
    LDA #$08                ; CHANGED: REFP0 bit 3 mirrors player 0
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
    STA GRP0                ; clear the last row; GRP0 holds its value
    STA WSYNC               ; the clear line

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

SpriteShape:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %11011011
    !byte %11111111
    !byte %00100100
    !byte %00001111         ; raw: right-heavy; mirrors to left-heavy
    !byte %11110000         ; raw: left-heavy; mirrors to right-heavy

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
