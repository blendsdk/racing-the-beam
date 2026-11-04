; =============================================================================
; LESSON 25: Player Sprite Basics — GRP0, Your First Character — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Draws the first player sprite: a red 8x8 invader on a dark background.
;   The shape is eight bytes in ROM; the kernel writes one byte to GRP0 on
;   each of the sprite's eight scanlines.  The sprite is 8 pixels wide, and
;   bit 7 of each byte is the leftmost pixel.
;
; The two dimensions of a sprite:
;   - HORIZONTAL position is where the player's position counter sits.  This
;     lesson places it with a fixed coarse delay (see below); Lesson 26
;     replaces that with the proper divide-by-15 routine.
;   - VERTICAL position is WHEN you write GRP0.  A write on scanline N makes
;     the sprite appear on scanline N (at its horizontal position).  Eight
;     writes, one per line, make an eight-line-tall shape.
;
; Why the shape is a table:
;   A player is only 8 bits wide, so a character is a list of bytes, one per
;   scanline.  The kernel walks the list with X and stores each byte to GRP0.
;   The table is the picture; the loop is the pen.
;
; The frame is the course standard (262 lines):
;   VSYNC 3, VBLANK 37 on TIM64T = 44, visible 192, overscan 30 on TIM64T = 36.
;   The sprite sits at visible line 80 (scanline 117), so the top loop parks
;   80 lines, the body draws 8, the clear line parks 1, and the bottom loop
;   parks the remaining 103.
;
; This lesson's placement (a placeholder):
;   After a WSYNC, a short DEX/BNE pad delays the RESP0 strobe.  RESP0 sets
;   the player's position to wherever the beam is, plus the player's fixed
;   output delay.  The pad is tuned to land near X=81; Lesson 26 derives the
;   exact divide-by-15 routine.  The measured landing is recorded in the doc.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VisibleStart (37), BodyStart (117,
;   the first sprite line), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson25.bin \
;        lessons/part4-sprites/25-player-basics/25-player-basics.asm
; Run:   stella build/lesson25.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (Lesson 15)
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (Lesson 15)
VISIBLE_LINES  = 192
SPRITE_TOP     = 80     ; blank visible lines above the sprite
SPRITE_HEIGHT  = 8      ; the invader is eight scanlines tall

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the placeholder placement: a fixed delay, then strobe RESP0 ---
    STA WSYNC               ; start the delay on a fresh line
    LDX #9                  ; LDX 2 + nine DEX/BNE (44) + STA (3) = 49 cycles
PlaceDelay:
    DEX
    BNE PlaceDelay
Resp0Write:                 ; checkpoint: the RESP0 store starts at cycle 46
    STA RESP0               ; write effect at cycle 49 -> clock 147; +5 -> X=84
    LDA #$42
    STA COLUP0              ; red
    LDA #$02
    STA COLUBK              ; dark neutral
    LDX #$00
    STX NUSIZ0              ; one copy, normal width (explicit, though cleared)
    STX REFP0               ; not mirrored

    +wait_timer             ; wait out line 36, then park it

; -----------------------------------------------------------------------------
; VISIBLE — top blank lines, 8 sprite lines, bottom blank lines
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
    LDX #SPRITE_TOP
VisibleStart:               ; debugger checkpoint: the picture's first line (37)
TopLoop:
    STA WSYNC               ; park one line
    DEX
    BNE TopLoop

    LDX #0
BodyStart:                  ; debugger checkpoint: the first sprite line (117)
BodyLoop:
    LDA SpriteShape,X       ; this line's 8 pixels
SpriteWrite:                ; checkpoint: A = the row byte, 8 hits per frame
    STA GRP0                ; draw them
    STA WSYNC               ; park the rest of the line
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

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines; blank-on lands in line 229's HBLANK
; -----------------------------------------------------------------------------
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SPRITE SHAPE — eight rows, bit 7 is the leftmost pixel
; =============================================================================
SpriteShape:
    !byte %00011000         ; $18
    !byte %00111100         ; $3C
    !byte %01111110         ; $7E
    !byte %11011011         ; $DB
    !byte %11111111         ; $FF
    !byte %00100100         ; $24
    !byte %01011010         ; $5A
    !byte %10100101         ; $A5

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
