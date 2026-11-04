---
title: "Lesson 31: Copies and Sizes — NUSIZ Register"
description: "NUSIZ bits 0-2 turn one player into two or three copies, double width, or quad width. Lesson 31 splits the screen into eight 24-line bands, writes NUSIZ0 from a table, and shows every mode in one capture."
prev:
  text: "Lesson 30: Multi-Color Sprites"
  link: "/part4-sprites/30-multicolor-sprites"
next:
  text: "Lesson 32: Vertical Delay"
  link: "/part4-sprites/32-vertical-delay"
---

# Lesson 31: Copies and Sizes — NUSIZ Register

> **Part 4: Sprites** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 25 (the player sprite and `GRP0`), Lesson 26 (`SetHorizPos`), Lesson 29 (`NUSIZ` bits 4–5 for missile width)
> **You will learn:** `NUSIZ` bits 0–2 and all eight player appearance modes; the copy spacings (16/32/64 color clocks); double and quad width; how to write `NUSIZ` per band to show every mode at once; the copy pattern's effect on the picture
> **You will build:** "the eight faces" — eight 24-line bands, each showing one `NUSIZ` mode with the same two-pixel pattern; plus three exercises: a solid pattern, two players with different modes, and an animated mode

## Introduction

`NUSIZ` is the player's "number and size" register. Its low three bits choose one of eight
appearance modes: one copy, two copies at three spacings, three copies at two spacings, double
width, and quad width. The shape table never changes; the TIA repeats or widens it.

The lesson shows all eight modes in one still picture. The 192 visible lines are divided into
eight 24-line bands; band *k* writes `NUSIZ0 = k` and draws the same `$18` pattern. A single
capture then reads as a table: one bar, two bars, two bars further apart, three bars, two bars
far apart, a double-width bar, three bars, a quad-width bar.

Writing `NUSIZ` on every line is the simplest way to keep each band independent. The value is
read when the player is drawn, so a band's first line sets the mode for all 24 lines.

::: details TypeScript Equivalent
A table of eight modes and a band index:

```typescript
const modes = [0, 1, 2, 3, 4, 5, 6, 7];
const pattern = 0x18;
const band = (line: number) => Math.floor(line / 24);

function drawLine(line: number) {
  return { nusiz0: modes[band(line)], grp0: pattern };
}
```

The 2600 version stores the same eight values in a 192-byte table (24 copies of each) and reads
one per line. The TIA does the copying and widening; the CPU only names the mode.
:::

## Theory

### Section 1: The Eight Modes

| `NUSIZ0` bits 0–2 | Copies | Spacing / width |
|---|---|---|
| 0 | one | normal |
| 1 | two | close (16 clocks) |
| 2 | two | medium (32) |
| 3 | three | close |
| 4 | two | wide (64) |
| 5 | one | double width |
| 6 | three | medium |
| 7 | one | quad width |

Bits 4–5 are the missile width (Lesson 29); they stay 0 here. The player's graphic is still eight
bits, bit 7 leftmost; the copies are the same eight pixels repeated, and the width modes stretch
each pixel.

### Section 2: Copies and Spacing

A copy is 16 color clocks after the previous close copy, 32 for medium, 64 for wide. In the
captures, one color clock is six pixels, so the copies are 96, 192, and 384 capture pixels apart
(start to start); the empty gap between the 12-pixel bars is 84, 180, and 372. The lesson's `$18`
pattern has its two on-pixels at bits 3–4, i.e. three pixels in from the player's left edge; the
first bar therefore starts at capture x = 283 (X=40 plus 3 pixels at 6 px each, plus the 25-pixel
picture origin).

### Section 3: Double and Quad Width

Values 5 and 7 do not add copies; they **stretch** each pixel. The two on-pixels become 4 and 8
color clocks wide, so the bar is 24 and 48 capture pixels wide instead of 12. Measured, the
stretched player's output begins one color clock later than the normal-width output (X=41 rather
than 40), and the on-pixels sit three stretched pixels in: `25 + 6·(41 + 3·2) = 307` for double
and `25 + 6·(41 + 3·4) = 343` for quad. That one-clock offset is observed in the committed ROM;
the widths are exact.

### Section 4: The Bands

The NUSIZ table is 192 bytes: 24 zeros, 24 ones, …, 24 sevens. The kernel reads one byte per line
and writes it to `NUSIZ0`, then draws the pattern. The band boundaries are lines 37, 61, 85, 109,
133, 157, 181, and 205 — every 24 lines.

The frame is 3 + 37 + 192 + 30 = 262; the player is at X=40, and the pattern is on every line, so
the eight bands are horizontal slices of one tall striped sprite.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson31.bin \
  lessons/part4-sprites/31-copies-and-sizes/31-copies-and-sizes.asm
stella build/lesson31.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 31: Copies and Sizes — NUSIZ Register — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Shows all eight player copy/size modes with one static picture.  The
;   192 visible lines are split into eight 24-line bands; band k writes
;   NUSIZ0 = k and draws the same two-pixel pattern.  One capture shows
;   one copy, two copies at three spacings, three copies at two spacings,
;   double width, and quad width.
;
; NUSIZ bits 0-2:
;   0  one copy, normal
;   1  two copies, close (16 clocks apart)
;   2  two copies, medium (32)
;   3  three copies, close
;   4  two copies, wide (64)
;   5  one copy, double width
;   6  three copies, medium
;   7  one copy, quad width
;
;   Bits 4-5 set the missile width; the missile is disabled here, so they
;   stay 0.
;
; The per-line kernel:
;   LDA BandNUSIZ,X   4   (the band's mode)
;   STA NUSIZ0        3
;   LDA #PATTERN      2
;   STA GRP0          3
;   STA WSYNC         3
;   INX / CPX / BNE   7
;   ---------------------------------
;   total            22 of 76 cycles (23 from X=132, where the table read
;                    crosses into $F1xx; WSYNC absorbs the extra cycle)
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; The player is at X=40; the pattern is `$18` (two adjacent pixels).
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VisibleStart (37), BandWrite (A = the
;   band value, 192 hits; the A runs change at lines 37/61/85/109/133/157/181/
;   205), PatternWrite (A = $18, 192 hits), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson31.bin \
;        lessons/part4-sprites/31-copies-and-sizes/31-copies-and-sizes.asm
; Run:   stella build/lesson31.bin
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
SPRITE_X       = 40
PATTERN        = $18
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
    LDA #$42
    STA COLUP0              ; red
    LDA #$02
    STA COLUBK              ; dark neutral
    LDA #$00
    STA REFP0

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — 192 lines; NUSIZ0 changes every 24 lines
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK
    LDX #0
VisibleStart:
LineLoop:
    LDA BandNUSIZ,X
BandWrite:                  ; checkpoint: A = the band value
    STA NUSIZ0
    LDA #PATTERN
PatternWrite:               ; checkpoint: A = the pattern
    STA GRP0
    STA WSYNC
    INX
    CPX #VISIBLE_LINES
    BNE LineLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SET HORIZONTAL POSITION — the Lesson 26 routine
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
    STA RESP0
    STA WSYNC
    STA HMOVE
    RTS

; =============================================================================
; NUSIZ TABLE — 24 lines of each mode 0-7
; =============================================================================
BandNUSIZ:
    !fill 24, 0
    !fill 24, 1
    !fill 24, 2
    !fill 24, 3
    !fill 24, 4
    !fill 24, 5
    !fill 24, 6
    !fill 24, 7

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
> `lessons/part4-sprites/31-copies-and-sizes/31-copies-and-sizes.asm`.

### Code Walkthrough

#### Step 1 — Position and colors

`SetHorizPos` puts player 0 at X=40 (target 43 with the bias). `COLUP0=$42` red, `COLUBK=$02`
dark, `REFP0=0`.

#### Step 2 — The per-line kernel

`LDA BandNUSIZ,X` / `STA NUSIZ0` sets the band; `LDA #$18` / `STA GRP0` draws the pattern; `STA
WSYNC` parks. The body is 22 cycles (23 from X=132, where the table read crosses into the next
page; `WSYNC` absorbs the extra cycle), so there is plenty of room.

#### Step 3 — The table

`BandNUSIZ` is eight runs of 24, generated with `!fill 24, k`. `X` is the visible line index
0–191, so `X / 24` is the band.

#### Step 4 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `VisibleStart` | `$F043` | 37, cycle 7 (first hit) | the first visible line |
| `BandWrite` | `$F046` | 192 hits; A = the table value; the A runs change at lines **37/61/85/109/133/157/181/205** | the `NUSIZ0` store |
| `PatternWrite` | `$F04A` | 192 hits; A = `$18` | the `GRP0` store |
| `OverscanStart` | `$F053` | 229, cycle 6 | overscan's first line |

## What You Should See

Eight horizontal bands of 24 lines each. From top to bottom: one bar; two bars close; two bars
medium; three bars close; two bars wide; one double-width bar; three bars medium; one quad-width
bar. All bars are red on the dark field, and all are made from the same two-pixel pattern.

![Stella running the Lesson 31 ROM: eight bands showing every NUSIZ player mode](/images/lesson31/nusiz-bands.png)

*The eight faces, captured from the committed ROM: band 0 one bar at 283–294; band 1 two bars at
283/379; band 2 at 283/475; band 3 at 283/379/475; band 4 at 283/667; band 5 a 24-px bar at
307–330; band 6 three bars at 283/475/667; band 7 a 48-px bar at 343–390.*

<RomPlayer rom="/roms/part4-sprites/31-copies-and-sizes/31-copies-and-sizes.bin" title="Lesson 31 — Copies and Sizes" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson31.sym -o build/lesson31.bin \
  lessons/part4-sprites/31-copies-and-sizes/31-copies-and-sizes.asm
grep -E "BandWrite|PatternWrite|VisibleStart" build/lesson31.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F046' \
  docs/public/roms/part4-sprites/31-copies-and-sizes/31-copies-and-sizes.bin
```

- **`$F046` (`BandWrite`)**: 192 hits; A = 0 for lines 37–60, 1 for 61–84, …, 7 for 205–228.
- **`$F04A` (`PatternWrite`)**: 192 hits, A = `$18`.
- **`$F043` (`VisibleStart`)**: line 37 every frame.

## Exercises

### Exercise 1: A Solid Pattern

**Challenge:** change the pattern from `$18` (two pixels) to `$FF` (all eight).

**Hints:**
1. One constant: `PATTERN = $FF`.
2. The copies become 8-pixel blocks with gaps of 8, 24, and 56 TIA pixels (48/144/336 capture px)
at the three spacings.
3. Double and quad width become 16- and 32-pixel-wide blocks.

**Expected Result:** the same eight bands, with solid blocks instead of two-pixel bars.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Two Players, Two Modes

**Challenge:** top half player 0 with three close copies (`NUSIZ0=3`); bottom half player 1 with
three medium copies (`NUSIZ1=6`).

**Hints:**
1. Place P0 at X=32 and P1 at X=88; two coarse routines and one `HMOVE`.
2. The top 96 lines draw `GRP0` only; the bottom 96 draw `GRP1` only.
3. The pattern is `$18` in both halves.

**Expected Result:** the top half shows three red bars at capture 235/331/427; the bottom half
shows three blue bars at 571/763/955. Measured in a scratch capture.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Animated Modes *(Stretch Goal)*

**Challenge:** animate one full-height player through all eight modes.

**Hints:**
1. Keep a 0–7 index and advance it every 60 frames.
2. Write the index to `NUSIZ0` on every line; the pattern stays `$18`.
3. The picture changes once a second from one copy to two, three, double, and quad.

**Expected Result:** the full-height sprite cycles through the eight modes, one per second. A
capture in the first second shows one bar; a capture a second later shows two close bars (the
index steps at frame 60).

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **`NUSIZ` bits 0–2 are the eight player modes**: one/two/three copies at three spacings, double width, quad width
- ✅ **Copies are 16/32/64 clocks apart**: 96/192/384 capture pixels at six pixels per clock
- ✅ **Width modes stretch pixels**: the two-pixel pattern becomes 24 px double and 48 px quad
- ✅ **The table is per line**: 24 copies of each value make eight independent bands
- ✅ **One write names the mode**: the TIA repeats or widens the same 8-bit shape
- ✅ **The shape never changes**: only `NUSIZ` differs between the bands
- ✅ **The frame is unchanged**: 192 visible lines split into eight 24-line bands

## What's Next

Copies and widths are horizontal tricks. [Lesson 32: Vertical Delay](/part4-sprites/32-vertical-delay)
uses `VDELP1` to delay one player's graphic by a single scanline — a one-line latch with a
surprising number of uses.
