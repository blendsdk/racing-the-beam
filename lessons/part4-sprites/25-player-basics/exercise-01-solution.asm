; =============================================================================
; LESSON 25 — EXERCISE 1 SOLUTION: Move the Sprite Down
; =============================================================================
; Part 4: Sprites
;
; Exercise: move the sprite down the screen without changing its shape.
;
; The technique: vertical position is WHEN the kernel writes GRP0.  Raising
; SPRITE_TOP from 80 to 120 makes the top loop park 40 more lines, so the
; first sprite line moves from scanline 117 to 157.  The bottom loop's count
; shrinks by 40 because it is computed from the same constants.  The picture
; is the same invader, 40 scanlines lower.
;
; Debugger checkpoints: VisibleStart (37), BodyStart (157), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson25-ex1.bin \
;        lessons/part4-sprites/25-player-basics/exercise-01-solution.asm
; Run:   stella build/lesson25-ex1.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
SPRITE_TOP     = 120    ; CHANGED: 40 lines lower than the lesson ROM
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
    STX REFP0

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
    !byte %01011010
    !byte %10100101

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
