---
title: "Lesson 30: Multi-Color Sprites — Changing Colors Per Line"
description: "COLUP0 is a per-scanline register. Lesson 30 writes it from a 16-byte table while drawing a 16-row character, producing a gold hat, a blue body, and red legs from one player and one shape table."
prev:
  text: "Lesson 29: Missiles and Ball"
  link: "/part4-sprites/29-missiles-and-ball"
next:
  text: "Lesson 31: Copies and Sizes"
  link: "/part4-sprites/31-copies-and-sizes"
---

# Lesson 30: Multi-Color Sprites — Changing Colors Per Line

> **Part 4: Sprites** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 13 (the color byte), Lesson 24 (per-line `COLUPF`), Lesson 25 (the player shape table), Lesson 26 (`SetHorizPos`)
> **You will learn:** how to change `COLUP0` on every scanline; how a 16-byte color table maps rows to colors; how shape and color stay independent; the cost of the per-line color write; how a single player shows three colors without a second object
> **You will build:** "the avatar" — one 8×16 character with a gold hat, a blue body, and red legs; plus three exercises: white shoes, sliding bands, and a 16-pixel two-player figure

## Introduction

The player's color is one register: `COLUP0`. Set it once and the whole sprite is red. But the TIA
reads `COLUP0` **when it draws each scanline**, so a write in HBLANK changes the color of that
line — exactly the technique Lesson 24 used for the playfield's `COLUPF`.

This lesson draws a 16-row character and writes `COLUP0` on every row from a 16-byte table. The
shape table says which pixels are on; the color table says what color each row is. The two tables
are independent: changing the colors never touches the silhouette, and changing the silhouette
never touches the colors.

That independence is the whole trick behind "multi-color sprites" on the 2600. There is no
multi-color sprite object; there is one color register per player per line, and a kernel that
writes it often enough.

::: details TypeScript Equivalent
Two arrays, one for the shape and one for the colors:

```typescript
const shape = [0x18, 0x3c, 0x7e, 0x7e, 0x3c, 0x7e, 0xff, 0xff,
               0xff, 0x7e, 0x7e, 0x3c, 0x24, 0x24, 0x66, 0xc3];
const color = [
  ...Array(4).fill(0x1a),   // gold hat
  ...Array(8).fill(0x84),   // blue body
  ...Array(4).fill(0x42),   // red legs
];

function drawLine(row: number) {
  return { grp0: shape[row], colup0: color[row] };
}
```

The 2600 version writes both values inside the same 24-cycle loop; the color write lands in
HBLANK, before the sprite's pixels.
:::

## Theory

### Section 1: Color Is a Per-Line Register

`COLUP0` is read by the TIA when it draws player 0. A write during HBLANK sets the color for the
whole line; a write during the visible area changes it mid-line. This lesson keeps every color
write in HBLANK, so each row has one clean color.

A 16-row sprite needs 16 color bytes. The table is the palette; the shape table is the
silhouette. Both are indexed by the same `X` (the row), so the kernel reads one byte from each.

### Section 2: The Per-Line Body

The body writes the color, then the shape, then parks:

```asm
    LDA ColorBands,X
    STA COLUP0
    LDA Shape,X
    STA GRP0
    STA WSYNC
    INX
    CPX #16
    BNE BodyLoop
```

The color store starts at cycle 10 on the first row and its write lands on cycle 12; the graphic
store starts at cycle 17 and its write lands on cycle 19. Later rows are one cycle later (11/13
and 18/20) because the loop tail is seven cycles instead of the first row's six. Both writes are
inside HBLANK (which ends around cycle 22).
The sprite's left edge is at X=72, color clock 140 (capture x = 457), so the writes precede the
pixels by more than 25 cycles. The body costs 24 cycles of the 76-cycle line, so there is room
for more per-line logic.

### Section 3: Shape and Color Are Independent

The shape table has 16 rows: a narrow top, a wider body, and two legs. The color table has three
runs: 4 × `$1A` gold, 8 × `$84` blue, 4 × `$42` red. Changing the color table's run lengths moves
the band boundaries without changing a single shape byte; changing a shape byte changes the
silhouette without touching the colors.

That is why the exercise that slides the bands is only a few lines: rotate the color index, leave
the shape alone.

### Section 4: The Frame

The frame is 3 + 37 + 192 + 30 = 262. The sprite starts at visible line 80 (scanline 117): 80 top
lines, 16 body rows, one clear line, 95 bottom lines = 192.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson30.bin \
  lessons/part4-sprites/30-multicolor-sprites/30-multicolor-sprites.asm
stella build/lesson30.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
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
```

<!-- END-FULL-SOURCE -->

> The complete, fully-commented source lives in
> `lessons/part4-sprites/30-multicolor-sprites/30-multicolor-sprites.asm`.

### Code Walkthrough

#### Step 1 — Position and colors

`SetHorizPos` places player 0 at X=72 (the target is 75 with the +3 bias). `COLUBK=$02` is the
dark field; `NUSIZ0=0` and `REFP0=0` keep the default eight-pixel player.

#### Step 2 — The tables

`Shape` is 16 bytes; `ColorBands` is 16 bytes in three runs. The kernel reads both with the same
`X`.

#### Step 3 — The body

The color write and the graphic write happen on every row. `ColorWrite` and `SpriteWrite` are the
two evidence labels: 16 hits each per frame.

#### Step 4 — The clear line

After row 15, `GRP0` is cleared and one line is parked. Without it, the last row would smear down
the rest of the screen (the Lesson 25 lesson).

#### Step 5 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `VisibleStart` | `$F041` | 37, cycle 7 (first hit) | the top loop's first line |
| `BodyStart` | `$F048` | **117, cycle 6**; 16 hits per frame | the first sprite row |
| `ColorWrite` | `$F04B` | 117, cycle 10 (write lands at 12); 16 hits; A = `$1A` for rows 0–3, `$84` for 4–11, `$42` for 12–15 | the `COLUP0` store |
| `SpriteWrite` | `$F050` | 117, cycle 17 (write lands at 19); 16 hits; A = the shape byte | the `GRP0` store |
| `OverscanStart` | `$F066` | 229, cycle 4 | overscan's first line |

## What You Should See

One 8×16 character at capture x = 457–504. The top four rows are gold (capture y = 359–371, with the
last row's blend), the middle eight rows blue (y = 372–396), and the bottom four red (y = 397–408). The silhouette is a
simple figure: a narrow hat, a wider body, and two legs.

![Stella running the Lesson 30 ROM: a 16-row character with a gold hat, blue body, and red legs](/images/lesson30/multicolor.png)

*The avatar, captured from the committed ROM: gold `$1A` rows 0–3, blue `$84` rows 4–11, red `$42`
rows 12–15; the sprite spans capture x = 457–504 and y = 359–408.*

<RomPlayer rom="/roms/part4-sprites/30-multicolor-sprites/30-multicolor-sprites.bin" title="Lesson 30 — Multi-Color Sprites" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson30.sym -o build/lesson30.bin \
  lessons/part4-sprites/30-multicolor-sprites/30-multicolor-sprites.asm
grep -E "ColorWrite|SpriteWrite|BodyStart" build/lesson30.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F04B' \
  docs/public/roms/part4-sprites/30-multicolor-sprites/30-multicolor-sprites.bin
```

- **`$F04B` (`ColorWrite`)**: 16 hits per frame; A runs `$1A` × 4, `$84` × 8, `$42` × 4.
- **`$F050` (`SpriteWrite`)**: 16 hits, one per row.
- **`$F048` (`BodyStart`)**: the first row, scanline 117, cycle 6.

## Exercises

### Exercise 1: White Shoes

**Challenge:** add a fourth color band for shoes.

**Hints:**
1. Split the 16 rows into 4 hat, 7 body, 3 legs, and 2 shoes.
2. The color table becomes 4 × `$1A`, 7 × `$84`, 3 × `$42`, 2 × `$0E`.
3. The shape table does not change.

**Expected Result:** the hat stays on rows 0–3; the blue band loses its last row (rows 4–10); the
red band moves up one row (rows 11–13); rows 14–15 are light gray. The shape is unchanged.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Sliding Bands

**Challenge:** slide the color bands while the shape stays still.

**Hints:**
1. Keep a 0–15 `ColorOffset` and read `ColorBands[(offset + row) & 15]`.
2. Increment the offset every 30 frames.
3. The shape table never changes.

**Expected Result:** the bands move up one row every half second and wrap; the silhouette is
identical. The extra `TXA`/`CLC`/`ADC`/`AND`/`TAY` pushes the color write to about cycle 23, just past the
HBLANK boundary; the sprite at X=72 still receives the color because its pixels start at color
clock 140.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: A 16-Pixel Character *(Stretch Goal)*

**Challenge:** combine two players into a 16-pixel-wide, two-color character.

**Hints:**
1. Place P0 at X=64 and P1 at X=72 — adjacent 8-pixel halves.
2. Each player has its own 16-row shape table and its own color (`COLUP0`, `COLUP1`).
3. Position both with two coarse routines, then one `HMOVE` (the Lesson 28 rule).

**Expected Result:** red at capture 409–456 (X=64) and blue at 457–504 (X=72), a continuous
16-pixel figure. Measured in a scratch capture.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **`COLUP0` is per-scanline**: a write in HBLANK sets that line's color, so a 16-byte table gives 16 colors
- ✅ **Shape and color are separate tables**: the kernel reads one byte from each, indexed by the row
- ✅ **The body costs 24 cycles**: color, shape, park, and loop fit comfortably in the 76-cycle line
- ✅ **One player can show many colors**: no second object, no flicker, no overlay — just a table
- ✅ **The clear line still matters**: clear `GRP0` after the last row or the final shape smears
- ✅ **The frame is unchanged**: 80 top + 16 body + 1 clear + 95 bottom = 192
- ✅ **The bands are data**: changing a run length moves a boundary without touching the silhouette

## What's Next

One player, many colors. [Lesson 31: Copies and Sizes](/part4-sprites/31-copies-and-sizes) uses
`NUSIZ` to turn one player into two or three copies, double width, or quad width — all from the
same shape table.
