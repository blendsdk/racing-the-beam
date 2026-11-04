; =============================================================================
; LESSON 25 — EXERCISE 3 SOLUTION: Two Creatures (Stretch Goal)
; =============================================================================
; Part 4: Sprites
;
; Exercise: draw two creatures with the same player.
;
; The technique: vertical reuse.  One player can appear several times down the
; screen if the kernel writes GRP0 in separate bands.  This program parks 56
; lines, draws the 8-row shape, parks 32 lines, draws the shape again, then
; parks the remaining 87 lines (56 + 8 + 1 + 31 + 8 + 1 + 87 = 192).  The second
; creature starts 40 scanlines below the first (8 rows + 32 blank lines).
;
; This is the same idea as a status-bar kernel: the player's horizontal
; position is fixed, and the vertical position is the write schedule.
;
; Debugger checkpoints: VisibleStart (37), Body1 (93), Body2 (133),
; OverscanStart (229).
;
; Build: acme -f plain -o build/lesson25-ex3.bin \
;        lessons/part4-sprites/25-player-basics/exercise-03-solution.asm
; Run:   stella build/lesson25-ex3.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
TOP_ONE        = 56
SPRITE_HEIGHT  = 8
GAP            = 31            ; one line is the clear after the first body
TOP_TWO        = 56 + 8 + 32      ; 96: the second creature's top blank count
BOTTOM         = VISIBLE_LINES - TOP_TWO - SPRITE_HEIGHT - 1  ; 87

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
    LDX #TOP_ONE
VisibleStart:
TopLoop:
    STA WSYNC
    DEX
    BNE TopLoop

    LDX #0
Body1:
BodyLoop1:
    LDA SpriteShape,X
    STA GRP0
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop1
    LDA #$00
    STA GRP0
    STA WSYNC

    LDX #GAP
GapLoop:
    STA WSYNC
    DEX
    BNE GapLoop

    LDX #0
Body2:
BodyLoop2:
    LDA SpriteShape,X
    STA GRP0
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop2
    LDA #$00
    STA GRP0
    STA WSYNC

    LDX #BOTTOM
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
