---
title: "Lesson 24: The Multicolor Playfield"
description: "COLUPF is a per-scanline register. Lesson 24 writes it from a 192-byte table every line, turning one playfield shape into a 16-band rainbow and a cool/warm region scheme — the shape and the color as independent layers."
prev:
  text: "Lesson 23: Data-Driven Playfield"
  link: "/part3-playfield/23-data-driven-playfield"
next:
  text: "Lesson 25: Player Sprite Basics"
  link: "/part4-sprites/25-player-basics"
---

# Lesson 24: The Multicolor Playfield

> **Part 3: Playfield** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 13 (the color byte), Lesson 19 (the playfield registers), Lesson 20 (`COLUPF` and score mode), Lesson 23 (per-row tables and the one-line kernel)
> **You will learn:** how to change `COLUPF` on every scanline; how a 192-byte table gives every line its own color; how to swap color schemes in VBLANK; how the playfield's shape and its color stay independent; the page-cross timing in a per-line table read
> **You will build:** "the rainbow keep" — the Lesson 19 castle colored by 16 hue bands, then by a cool/warm region scheme, switching every two seconds; plus three exercises: a moving rainbow, a sky/ground split, and a data-colored maze

## Introduction

Part 3 has treated the playfield as a shape: bits on or off, mirrored or repeated, animated or loaded from tables. Color has been a single byte per frame — `COLUPF` set once in VBLANK and left alone for 192 lines. This lesson makes color a **per-scanline** value.

The mechanism is the same one `COLUBK` used in Part 2: a TIA color register is read when the beam draws, so a write in HBLANK changes the color of that line. Write `COLUPF` from a table once per line, and the playfield's shape stays fixed while its color becomes a second, independent layer. Sixteen hue bands, a cool/warm split, a moving rainbow — all of them are the same 20 bits with a different 192-byte table.

This is the last piece of Part 3's canvas. A playfield can carry a maze; a color table can carry its palette; together they are most of what a 2600 background needs before sprites arrive.

::: details TypeScript Equivalent
A shape function and a color function are separate; the line loop combines them:

```typescript
const castle = [0xf0, 0xcc, 0xf0];           // one 20-bit shape
const rainbow = Array.from({ length: 192 }, (_, line) =>
  0x0e + (Math.floor(line / 12) << 4)          // 16 hue bands
);
function drawLine(line: number) {
  const pf2 = castle[2];                       // the shape
  const color = rainbow[line];                 // the color
  return { pf2, color };
}
```

The 2600 version reads `rainbow[line]` from ROM with `(ColorPtr),Y`; the shape registers are written once per frame and never change.
:::

## Theory

### Section 1: Color Is a Per-Line Register

`COLUPF` is read by the TIA when it draws the playfield. A write during HBLANK sets the color for the whole line; a write during the visible area changes it mid-line (the Lesson 18 rule, now applied to color). This lesson keeps every write in HBLANK, so each line has one clean color.

A 192-byte table is exactly the number of visible lines. The table's byte *k* is the color of visible line *k*; the beam reads it in order, one line at a time. The playfield's shape registers (`PF0/PF1/PF2`) are set once in VBLANK and never touched in the kernel — the color table is the only per-line state.

### Section 2: The Per-Line Kernel

The kernel is a counted read/write loop:

| Cycles | Instruction | Note |
|---|---|---|
| 5–9 | `LDA (ColorPtr),Y` | 6–10 when the table read crosses a page |
| 10–12 | `STA COLUPF` | 11–13 on a page-crossing line; still in HBLANK |
| 13–14 | `INY` | 14–15 on a page-crossing line |
| 15–17 | `STA WSYNC` | 16–18 on a page-crossing line; parks the rest |
| next 0–1 | `CPY #192` | |
| next 2–4 | `BNE` taken | the next line's read starts at 5 |

The release (`LDA #$00` + `STA VBLANK`) is 5 cycles, the same as the steady-state `CPY`+`BNE` wake, so line 37 and line 228 share the phase. All writes land before the visible part of their line; the color for line *k* is in place before the beam reaches the playfield.

The rainbow table starts at `$F08D`; `LDA (ColorPtr),Y` crosses a page when `$8D + Y > $FF`, i.e. from **table entry 115** — Stella scanline **152**. The regions table starts at `$F14D`, so its crossing begins at entry 179 — scanline **216**. The page-crossing lines take one extra cycle, which `WSYNC` absorbs; the checkpoint reports cycle 13 or 14 depending on the line and the table.

### Section 3: Two Tables, Two Seconds

The lesson has two 192-byte tables:

- **Rainbow** — 16 hue bands of 12 lines: hue 0 at luminance 7 (`$0E`), hue 1 (`$1E`), …, hue 15 (`$FE`). The top of the picture is light gray, the bottom is yellow; the bands walk the wheel.
- **Regions** — six cool bands of 16 lines (`$6E` light violet, `$7E` violet, `$8E` blue, `$9E` light blue, `$AE` aqua, `$BE` teal-green), then six warm bands (`$2E` orange, `$3E` peach, `$4E` light salmon-pink, `$5E` pink, `$1E` gold, `$0E` light gray).

`ColorState` flips every 120 frames (~2 s), and VBLANK points `ColorPtr` at the other table. The shape never changes; the picture changes palette.

### Section 4: The Shape and the Color

The castle pattern is the Lesson 19 pattern: `PF0=$F0`, `PF1=$CC`, `PF2=$F0` in reflect mode. Its chunks are the same in both states; only the color of the on-chunks changes. The rainbow state shows the shape in 16 horizontal color bands; the regions state splits it into a cool top and a warm bottom.

Because the color is per line, a band boundary can fall on any line — the table, not the pattern, decides. That independence is the lesson's real payload: shapes and palettes are separate data.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson24.bin \
  lessons/part3-playfield/24-multicolor-playfield/24-multicolor-playfield.asm
stella build/lesson24.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 24: The Multicolor Playfield — Racing the Beam
; =============================================================================
; Part 3: Playfield
;
; What this program does:
;   Colors the playfield every scanline.  The shape is the Lesson 19 castle
;   (PF0=$F0, PF1=$CC, PF2=$F0), but COLUPF is written from a 192-byte table,
;   so every line can have its own color.  Two tables alternate every two
;   seconds:
;
;     Rainbow: 16 hue bands of 12 lines, hues 0-15 at luminance 7;
;     Regions: six cool bands of 16 lines, then six warm bands of 16 lines.
;
; Why per-line color is cheap:
;   COLUPF is a normal TIA register; the beam reads it when it draws the
;   playfield.  A write in HBLANK changes the color of the whole line, and a
;   table lookup per line gives every line a different value.  The shape and
;   the color are independent layers: the same 20 bits, a different palette.
;
; The per-line kernel:
;   LDA (ColorPtr),Y   5-9
;   STA COLUPF        10-12   (the color for this line, in HBLANK)
;   INY               13-14
;   STA WSYNC         15-17
;   CPY #192           next line 0-1
;   BNE VisibleStart   next line 2-4
;
;   The release (LDA #$00 + STA VBLANK) is 5 cycles, the same as the
;   steady-state wake (CPY + BNE), so line 37 and line 228 share the phase.
;   Y runs 0..191; the table pointer is swapped in VBLANK, never mid-frame.
;
; The tables:
;   Rainbow (192 bytes): 16 x 12 lines, hue k at luminance 7 ($0E, $1E, ...,
;   $FE).  State A.
;   Regions (192 bytes): 6 x 16 cool ($6E,$7E,$8E,$9E,$AE,$BE), then
;   6 x 16 warm ($2E,$3E,$4E,$5E,$1E,$0E).  State B.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), StateFlip (A = the new state, at
;   frames 120, 240, ...), VisibleStart (37), ColorWrite (one hit per line,
;   A = the table byte), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson24.bin \
;        lessons/part3-playfield/24-multicolor-playfield/24-multicolor-playfield.asm
; Run:   stella build/lesson24.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines
VISIBLE_LINES  = 192
STATE_FRAMES   = 120    ; ~2 seconds per color table

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameCounter   = $80
ColorState     = $81    ; 0 = Rainbow, 1 = Regions
ColorPtr       = $82    ; 2 bytes: the current 192-byte table

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM; ColorState = 0

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the color tick: swap tables every STATE_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #STATE_FRAMES
    BNE VblankSetColors
    LDA #$00
    STA FrameCounter
    LDA ColorState
    EOR #$01
StateFlip:                  ; debugger checkpoint: A = the new state (flip only)
    STA ColorState

; --- point ColorPtr at the current 192-byte table ---
VblankSetColors:
    LDA ColorState
    BEQ VblankUseRainbow
    LDA #<Regions
    STA ColorPtr
    LDA #>Regions
    STA ColorPtr+1
    JMP VblankSetup
VblankUseRainbow:
    LDA #<Rainbow
    STA ColorPtr
    LDA #>Rainbow
    STA ColorPtr+1

; --- the shape never changes; only the color does ---
VblankSetup:
    LDA #$F0
    STA PF0                 ; chunks 0-3 on
    LDA #$CC
    STA PF1                 ; chunks 4-11: 11001100
    LDA #$F0
    STA PF2                 ; chunks 12-19: 00001111 (bit 0 first)
    LDA #$02
    STA COLUBK              ; dark background
    LDA #$01
    STA CTRLPF              ; reflect: the castle is symmetric

    LDY #0
    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — one COLUPF byte per line
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
VisibleStart:               ; debugger checkpoint: the picture's first line (37)
    LDA (ColorPtr),Y        ; 5-9    this line's color
    STA COLUPF              ; 10-12  in HBLANK
ColorWrite:                 ; debugger checkpoint: A = the color, hit 13
    INY                     ; 13-14
    STA WSYNC               ; 15-17  park the rest of the line
    CPY #VISIBLE_LINES      ; next line 0-1
    BNE VisibleStart        ; next line 2-4

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
; RAINBOW — 16 hue bands of 12 lines (192 bytes)
; =============================================================================
Rainbow:
    !fill 12, $0E           ; hue 0
    !fill 12, $1E           ; hue 1
    !fill 12, $2E           ; hue 2
    !fill 12, $3E           ; hue 3
    !fill 12, $4E           ; hue 4
    !fill 12, $5E           ; hue 5
    !fill 12, $6E           ; hue 6
    !fill 12, $7E           ; hue 7
    !fill 12, $8E           ; hue 8
    !fill 12, $9E           ; hue 9
    !fill 12, $AE           ; hue 10
    !fill 12, $BE           ; hue 11
    !fill 12, $CE           ; hue 12
    !fill 12, $DE           ; hue 13
    !fill 12, $EE           ; hue 14
    !fill 12, $FE           ; hue 15

; =============================================================================
; REGIONS — six cool bands then six warm bands (16 lines each)
; =============================================================================
Regions:
    !fill 16, $6E           ; cool: light violet
    !fill 16, $7E           ; violet
    !fill 16, $8E           ; blue
    !fill 16, $9E           ; light blue
    !fill 16, $AE           ; aqua
    !fill 16, $BE           ; teal-green
    !fill 16, $2E           ; warm: orange
    !fill 16, $3E           ; peach
    !fill 16, $4E           ; light salmon-pink
    !fill 16, $5E           ; pink
    !fill 16, $1E           ; gold
    !fill 16, $0E           ; light gray

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
> `lessons/part3-playfield/24-multicolor-playfield/24-multicolor-playfield.asm`.

### Code Walkthrough

#### Step 1 — The color tick

`FrameCounter` counts to 120; `ColorState` flips and the VBLANK code selects the table. The `StateFlip` checkpoint sits on the `STA ColorState` that only executes on a flip, so the debugger reports one hit every 120 frames.

#### Step 2 — The pointer

`ColorPtr` is a two-byte zero-page pointer to the start of the selected table. The kernel reads `(ColorPtr),Y` with `Y` running 0–191. Changing the pointer in VBLANK is the whole state switch.

#### Step 3 — The line

`LDA (ColorPtr),Y` fetches the line color; `STA COLUPF` writes it; `INY` advances; `WSYNC` parks. The `ColorWrite` checkpoint sits on the `INY`, so the debugger reports the color byte once per line.

#### Step 4 — The tables

`Rainbow` is 16 `!fill 12` lines, one per hue. `Regions` is 12 `!fill 16` lines, cool then warm. Both are exactly 192 bytes, so `Y` never runs past the selected table.

#### Step 5 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `StateFlip` | `$F035` | A = the new state; hits at frames **120** (A=1), **240** (A=0), 360, 480 | the table switch |
| `VisibleStart` | `$F06F` | 37, cycle 5 | the picture's first line |
| `ColorWrite` | `$F073` | 192 hits/frame; cycle **13** (14 on a page-crossing line), A = the color | one color per line |
| `OverscanStart` | `$F07A` | 229, cycle 4 | overscan's first line |

The first 12 `ColorWrite` hits of the rainbow state all report A = `$0E`; the next 12 report `$1E`; the log is the band table read back line by line.

## What You Should See

The castle wall, but colored in horizontal bands. First the rainbow: light gray at the top, then gold, orange, red, pink, violet, blue, cyan, greens, and yellow-greens down the picture — 16 bands of 12 lines each. Two seconds later the palette changes: the top half is cool (violets through teal-greens), the bottom half warm (oranges through light gray), split at the middle of the picture. The castle's shape is identical in both states; only its colors move.

![Stella running the Lesson 24 ROM in the rainbow state: the castle pattern in 16 horizontal hue bands](/images/lesson24/rainbow.png)

*Rainbow state, captured from the committed ROM: 16 hue bands of 12 lines, hue 0 (`$0E`, rgb(234,234,233)) at the top; the castle's on-chunks carry the bands.*

![Stella running the Lesson 24 ROM in the region state: cool hues above, warm hues below](/images/lesson24/regions.png)

*Region state, same ROM ~2 seconds later: six cool bands (16 lines each) above, six warm bands below; the top reads light violet rgb(208,130,251), the middle teal-green rgb(121,253,207). The two states differ in 348,480 picture pixels; repeat captures of either state differ in zero.*

<RomPlayer rom="/roms/part3-playfield/24-multicolor-playfield/24-multicolor-playfield.bin" title="Lesson 24 — The Multicolor Playfield" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson24.sym -o build/lesson24.bin \
  lessons/part3-playfield/24-multicolor-playfield/24-multicolor-playfield.asm
grep -E "StateFlip|ColorWrite|VisibleStart" build/lesson24.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F073' \
  docs/public/roms/part3-playfield/24-multicolor-playfield/24-multicolor-playfield.bin
```

- **`$F073` (`ColorWrite`)**: 192 hits per frame, A = the table byte; 12 consecutive lines share a hue in the rainbow state. The cycle column reads 13, or 14 when the table read crosses a page.
- **`$F035` (`StateFlip`)**: hits at frames 120, 240, 360, 480, with A = 1, 0, 1, 0. The palette changes exactly every two seconds.
- **`$F06F` (`VisibleStart`)**: line 37 every frame; the first color is in place before the picture starts.

## Exercises

### Exercise 1: A Moving Rainbow

**Challenge:** slide the rainbow bands upward, one band per second.

**Hints:**
1. Store the 192-byte rainbow twice (384 bytes) and advance the table pointer by 12 bytes every 60 frames.
2. The offset cycles 0, 12, 24, …, 180, then wraps to 0; the doubled table makes the wrap seamless.
3. The pointer update is a 16-bit add: low = base low + offset, high = base high + carry.

**Expected Result:** the bands move up one band (12 lines) per second and wrap after 16 seconds. Measured: `OffsetStep` fires at frames 60/120/180/240/300 with A = `$0C`/`$18`/`$24`/`$30`/`$3C`; a capture at offset 12 (about 1.5 s of emulation) shows the top band at `$1E` (gold) instead of `$0E`.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Sky and Ground

**Challenge:** replace the rainbow with a two-region table — blue sky, dark red ground.

**Hints:**
1. The table is data: 96 lines of `$84` (blue), then 96 of `$46` (dark red).
2. The kernel and the castle shape do not change.
3. The horizon lands on visible line 133 (capture y ≈ 409).

**Expected Result:** the top half blue rgb(36,40,176), the bottom half dark red rgb(194,61,60). Measured: `ColorWrite` reads A = `$84` on line 37 through 132 and A = `$46` on 133 through 228.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: A Data-Colored Maze *(Stretch Goal)*

**Challenge:** combine Lesson 23's row tables with Lesson 24's per-line color: walls green, open rows dark.

**Hints:**
1. Add a fourth parallel table per level — a 192-byte color table — and a fourth pointer.
2. The color is `$C8` for a wall row (`PF1` or `PF2` nonzero) and `$02` for an open row (both zero); the table is generated once, from the row data.
3. The kernel stores `COLUPF` at the top of the line and prefetches the next row's color with the other three bytes.

**Expected Result:** the maze's walls green, the corridors disappearing into the dark background. Measured: `ColorStore` reports 152 lines at `$C8` and 40 at `$02` in frame 1; `LevelSwitch` still flips at frames 240/480.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **`COLUPF` is per-scanline**: a write in HBLANK sets the whole line's color; a 192-byte table gives 192 independent line colors
- ✅ **Shape and color are separate layers**: the same 20 bits produce a rainbow or a region scheme from a different table
- ✅ **The pointer is the palette**: swapping `ColorPtr` in VBLANK changes the whole picture; the kernel never changes
- ✅ **The phase holds**: the release's 5 cycles equal the `CPY`+`BNE` wake, so line 37 and line 228 share the cycle grid
- ✅ **Page crossings cost one cycle**: the rainbow's table read adds a cycle from scanline 152 (entry 115); the regions table from scanline 216; `WSYNC` absorbs it, and the checkpoint shows cycle 13 or 14
- ✅ **Twelve lines per band, sixteen bands**: the rainbow table is exactly 192 bytes — one byte per visible line
- ✅ **Part 3 is complete**: the playfield can carry a shape, a level, an animation, and a palette, all from tables and a counted kernel

## What's Next

Part 3 is complete: the TIA's background layer is a full canvas. Part 4 adds the objects that move on it. [Lesson 25: Player Sprite Basics](/part4-sprites/25-player-basics) introduces the player sprite — eight bits wide, one scanline tall per write, positioned by a strobe — and the playfield becomes the scene the sprites act in.
