---
title: "Lesson 77: Interlaced Flicker — Faking More Colours & Resolution"
description: "Draw the same eight bands twice, once in palette A and once in palette B, and let the eye add the two 30 Hz frames into eight colours the TIA cannot show at once: a frame-parity phase byte, a Phase*8 + Band table staged into RAM in the vertical blank, a 192-line band kernel with one COLUBK write per band, an auto-demo that holds each phase for a still capture, and the same trick stacked vertically as a field-interlaced 96-line bitmap."
prev:
  text: "Part 11: Legendary Techniques"
  link: "/part11-legendary/"
next:
  text: "Part 11: Legendary Techniques"
  link: "/part11-legendary/"
---

# Lesson 77: Interlaced Flicker — Faking More Colours & Resolution

> **Part 11: Legendary Techniques** · Estimated time: 110 minutes
> **Prerequisites:** Lesson 12 (the NTSC frame), Lesson 13 (colours — hue and luminance bytes), Lesson 14 (WSYNC and scanline timing), Lesson 15 (the RIOT timer), Lesson 17 (cycle counting), Lesson 41 (game states, SELECT edges and the auto-demo), Lesson 51 (flicker sprites), Lesson 54 (visual effects)
> **You will learn:** how to show more colours than the TIA can hold at once by alternating two whole pictures at 30 Hz; why the two frames must be geometrically identical and why the phase must change in the vertical blank; how a `Phase*8 + Band` table staged into RAM meets the cycle-22.67 deadline at every band boundary; how equal-luminance pairs keep the alternation from reading as a flash; how an auto-demo freezes each phase long enough for a still capture; and how the same idea stacked vertically fakes a 192-line bitmap from two 96-line fields.
> **You will build:** "the colour mosaic" — a 4,096-byte ROM of eight flat 24-line bands, each drawn from one `COLUBK` write, alternating between a palette A and a palette B so the eye sees eight blended colours from eight pairs. SELECT holds whichever phase is showing; an auto-demo holds palette A for two seconds and palette B for the next two, so the two captures show the same ROM in its two phases. Plus two complete exercise solutions: a three-palette ROM that steps the phase in reverse order, and a field-interlaced 96-row bitmap that doubles the addressed line count.

## Introduction

Every lesson in this part has used the same clock: sixty frames a second, 262 lines each, drawn by code that races the beam. The TIA can only put *one* colour into the background register at a time, and NTSC gives it 128 colours to choose from. So a band of the screen is one colour per frame, full stop.

This lesson bends "per frame". If a band is red on one frame and green on the next, and then red again, the band is red for half the time and green for the other half. Each colour is on screen 30 times a second. The eye does not resolve the switch at that rate — it integrates it — so the band reads as a third colour, roughly what you would get by adding red and green light: yellow. Eight bands, eight pairs, eight colours the TIA never has to hold at the same moment.

The technique is old and it has a name: **interlaced flicker**, or whole-frame colour mixing. It is usually described as displaying two different 30 Hz frames whose differences the eye merges, and the line that matters is this: interlacing alternates *whole pictures*, while Lesson 51's flicker alternated *objects* inside one picture. Same clock, different trade.

The companion program `77-interlaced-flicker.asm` makes the trade visible. The screen is eight horizontal bands of 24 scanlines. Palette A fills them with red, blue, green, orange, violet, aqua, peach and light blue. Palette B fills the same eight bands with green, red, blue, blue, yellow-green, pink, teal and violet. Each pair is chosen at the same TIA luminance level, so the composite luma stays close to constant on real hardware; the rendered brightness still varies with hue, so the alternation is mildly flickery rather than perfectly steady. A quarter of a second in, the eye is looking at yellow, magenta, cyan, white-ish, pale grey, rose, warm grey and pale blue-violet. One photograph of the screen shows neither of those sets: it shows palette A or palette B, because a photograph is one frame.

That last sentence is the lesson's honesty clause, and the auto-demo exists to serve it. For the first two seconds the ROM alternates every frame, as it should. Then it holds palette A for two seconds, then palette B for two seconds, then starts again. The hold is what lets a still camera — Stella's screenshot key — catch each phase on purpose, and it is also how a reader can put the two palettes side by side on a real television: press SELECT to freeze either one.

::: details TypeScript Equivalent

The whole program is a palette lookup and a parity bit:

```typescript
/** The two palettes: eight TIA colour bytes, one per band. */
const PALETTE_A = [0x4a, 0x8a, 0xca, 0x2a, 0x7a, 0xaa, 0x3a, 0x9a];
const PALETTE_B = [0xca, 0x4a, 0x8a, 0x8a, 0xea, 0x5a, 0xba, 0x7a];

let phase = 0;          // 0 = palette A, 1 = palette B
let frozen = false;     // SELECT sets this to hold one phase

/** One frame: eight bands, each 24 scanlines of one background colour. */
function drawFrame(): void {
  const palette = phase === 0 ? PALETTE_A : PALETTE_B;
  for (let band = 0; band < 8; band++) {
    setBackground(palette[band]);   // the assembler's STA COLUBK
    waitScanlines(24);              // the band's 24 WSYNCs
  }
}

/** One pass of the main loop: step the phase, then draw. */
function nextFrame(): void {
  if (!frozen) phase ^= 1;          // one step per frame, in the blank
  drawFrame();
}
```

Two places where the analogy breaks, and both are the point of the lesson.

**The blend has no pixel.** In TypeScript you would mix the two colours directly — `mix(PALETTE_A[0], PALETTE_B[0], 0.5)` — and store the answer. The 2600 has no frame buffer to store it in and no arithmetic on colours; it has a register and a beam. The blended colour exists only in the eye, across two frames, and `drawFrame()` never produces it. A screenshot, like `canvas.toDataURL()`, catches one frame: palette A or palette B, never the sum.

**The picture is not "kept" between calls.** A canvas keeps its pixels until you draw over them; the TIA keeps nothing. Every line of every frame is drawn again from scratch, which is why the phase change has to happen in the vertical blank: there is no other moment at which "the whole picture" exists as a thing you can swap.

:::

## Theory

### Section 1: Time is the third axis

A TIA colour byte is `%HHHHLLL0`: the high nibble is the hue (0-15), bits 3-1 are the luminance (0-7), and bit 0 is unused. Sixteen hues times eight luminance levels is 128 colours on NTSC. That is the whole palette, and a single scanline can only show as many of them as you can write in 76 cycles.

Interlacing adds a dimension the palette does not have: **duty cycle**. If a band is colour X on frame *n* and colour Y on frame *n+1*, and the two frames are otherwise identical, then over any half-second the band is X half the time and Y half the time. The eye's persistence of vision — the same integration that makes a film look continuous — turns that ratio into a colour that is not in the palette at all. Change the ratio — X on two frames, Y on one — and you get a third blend. The classic use is a 50/50 split, which is what this lesson draws.

Two constraints come with the trick, and both are visible in the code:

- **The pictures must be geometrically identical.** If the bands moved between frames, the eye would see motion at 30 Hz — the picture would appear to vibrate or double. Here nothing moves: the same eight bands, the same 24-line boundaries, the same 192 lines. Only eight colour bytes differ.
- **The phase must change at the frame boundary.** If the phase changed halfway down the screen, one frame would contain half of palette A above and half of palette B below: a tear, not a blend. On the 2600 the frame boundary is the vertical blank, so that is where the phase is decided.

::: tip Why 30 Hz and not 60
Each palette is *repeated* 30 times a second even though the screen refreshes 60 times a second: frame 1 is A, frame 2 is B, frame 3 is A, and so on. The alternation frequency — how often the picture changes — is 30 Hz. That is the number the eye has to integrate.
:::

### Section 2: Choosing the pairs

Not every pair blends well. The eye sums the two lights, so the useful pairs are the ones whose sum is a colour you want:

| Sum | Pairs that produce it |
|---|---|
| yellow | red + green |
| magenta | blue + red |
| cyan | green + blue |
| white-ish | orange + blue, or any pair of near-complementary hues |
| grey | two complementary hues of equal luminance |

Two design rules make the blends read as colour instead of as flicker:

1. **Equal luminance.** Keep both bytes of a pair at the same level. If one is bright and the other dark, the band flashes at 30 Hz, and a brightness flash is much easier to see than a hue shift. Every byte in this lesson is level 5.
2. **Large hue separation.** A pair one hue step apart sums to something close to both; a pair on opposite sides of the wheel sums to a colour neither of them is.

The mosaic's eight pairs, with the TIA bytes and the colour each is meant to read as:

| Band | Palette A | Palette B | Intended blend |
|---|---|---|---|
| 0 | red `$4A` (hue 4) | green `$CA` (hue 12) | yellow |
| 1 | blue `$8A` (hue 8) | red `$4A` (hue 4) | magenta |
| 2 | green `$CA` (hue 12) | blue `$8A` (hue 8) | cyan |
| 3 | orange `$2A` (hue 2) | blue `$8A` (hue 8) | white-ish |
| 4 | violet `$7A` (hue 7) | yellow-green `$EA` (hue 14) | pale grey |
| 5 | aqua `$AA` (hue 10) | pink `$5A` (hue 5) | pale lavender (periwinkle) |
| 6 | peach `$3A` (hue 3) | teal-green `$BA` (hue 11) | warm grey |
| 7 | light blue `$9A` (hue 9) | violet `$7A` (hue 7) | pale blue-violet |

The blend column is the *intended* result, from the arithmetic of adding two lights. What you actually see is your eye's integration of two phosphor colours on your display, and it will be close to that table but not identical to it. The two committed captures do not show the blends at all — they show the two palettes, one frame each — so the blend column is a guide, not a measurement.

### Section 3: Exact frame sync — and how it differs from object flicker

Lesson 51 drew four objects with two players by alternating two 30 Hz frames: parity 0 drew objects 0 and 1, parity 1 drew objects 2 and 3. That is **object flicker**, and it works because the eye merges two positions into two objects. It has a visible cost: at 30 Hz each object's motion is half as smooth, and two objects at nearly the same place can ghost.

This lesson is **whole-frame interlacing**. The picture is the same on every frame; only colours change. There is no motion to strobe and no object to ghost, so the only thing the eye can do with the difference is average it. That is why the technique can produce a *colour* that neither frame contains, while object flicker can only produce two objects at their real colours.

The frame sync is what keeps it clean:

```asm
VblankStart:
    LDA #$02
    STA VBLANK
    ...
    LDA Freeze              ; decide the phase ...
    BNE PhaseFixed
    LDA Phase
    EOR #$01
    STA Phase
PhaseFixed:
    JSR StagePalette        ; ... stage its eight bytes ...
    +wait_timer
    LDA #$00
    STA VBLANK              ; ... and only then show the picture
```

By the time `VBLANK` bit 1 is cleared, `Phase` has been stepped and the eight colour bytes have been copied into `ActiveBand`. The kernel then draws a complete frame from one palette. There is no frame in which the top half is A and the bottom half is B, and no frame in which the phase is one thing and the staged bytes are another.

::: tip The two failure modes look different
Object flicker fails as *ghosting*: the eye sees both positions and the sprite looks doubled or shaky. Whole-frame flicker fails as *flashing*: if the two frames differ in shape or brightness, the whole picture pulses at 30 Hz. Equal-luminance pairs and identical geometry are what keep this lesson on the "steady blend" side of the line.
:::

### Section 4: One register, eight writes

The picture is eight flat bands, so the kernel has almost nothing to do:

```asm
    LDX #$00
BandLoop:
    LDA ActiveBand,X        ; the colour this phase puts in this band
    STA COLUBK
    LDY #BAND_LINES         ; 24
BandLines:
    STA WSYNC
    DEY
    BNE BandLines
    INX
    CPX #BAND_COUNT
    BNE BandLoop
```

Colour writes to `COLUBK` take effect where the beam is, so each band's write must complete before the beam reaches pixel 0 of that band's first line. HBLANK is 68 colour clocks, three clocks to a CPU cycle, so pixel 0 arrives at cycle 68/3 = **22.67** of the line. Counting from the WSYNC release at the band boundary:

```text
DEY              2     0- 1   the previous band's last line: Y reaches 0
BNE BandLines    2     2- 3   not taken at the end of the band
INX              2     4- 5
CPX #BAND_COUNT  2     6- 7
BNE BandLoop     3     8-10   taken for bands 0-6
LDA ActiveBand,X 4    11-14
STA COLUBK       3    15-17   the store completes at cycle 18
```

Cycle 18 against a deadline of 22.67 leaves 4.67 cycles — fourteen colour clocks — of margin. That margin is why the eight colours are staged in RAM. Indexing the ROM table directly would mean computing `Phase*8 + Band` inside the loop: `TXA/CLC/ADC/TAY/LDA abs,Y/STA`, sixteen cycles after the eleven that reach the load, completing at cycle 27. The beam would already have drawn thirteen colour clocks of the line in the *previous* band's colour, and every band boundary would carry a thin seam. Eight bytes of RAM and one copy loop in the blank buy the difference.

The copy loop is where `Phase*8 + Band` actually happens:

```asm
StagePalette:
    LDA Phase
    ASL                     ; Phase * 2
    ASL                     ; Phase * 4
    ASL                     ; Phase * 8
    TAY                     ; Y = the palette's first table index
    LDX #$00
.copy:
    LDA BandTable,Y
    STA ActiveBand,X
    INY
    INX
    CPX #BAND_COUNT
    BNE .copy
    RTS
```

`BandTable` is sixteen bytes: palette A at offsets 0-7, palette B at 8-15. Phase 0 selects offset 0, phase 1 selects offset 8, and the eight stores walk to the end of the selected palette. The kernel never sees the phase; it sees eight ready colours.

The first band of the frame is even earlier: `BodyStart` runs at 37/5, immediately after the VBLANK store, so its `LDA` starts at cycle 7 and its `STA COLUBK` completes at cycle 14.

### Section 5: The demo, the freeze, and the one-phase screenshot

A still camera catches one frame. That is not a defect of the camera; it is what "still" means. The blended colour is not in any frame buffer, so no screenshot can show it. What a screenshot *can* do is show each phase on purpose, and that is what the auto-demo provides. Counting the frames after power-on from 1:

| Frames | What happens | Palette on screen |
|---|---|---|
| 1-119 | the phase steps every frame | A, B, A, B, ... |
| 120-239 | `Freeze = 1`, `Phase = 0` | palette A |
| 240-359 | `Phase = 1` | palette B |
| 360 onwards | `Freeze = 0`; the six-second cycle restarts | A, B, A, B, ... |

The demo's timer counts 120 frames — two seconds — per segment, so the three boundaries land at 2 s, 4 s and 6 s. SELECT does the same job by hand: a new press toggles `Freeze` and sets `AutoDemo` to 0, so the player owns the phase from then on. Press it once while the mosaic is running and it holds whichever phase is on screen; press it again and the alternation resumes.

::: tip Seeing the blend
The committed captures use Stella's default display settings — no TV filters, no phosphor blending, one frame per screenshot — so the blend is not in any of them. To see it, run the ROM at full speed (`stella build/lesson77.bin`) or use the player below and watch the mosaic, not a still. The two captures exist for the opposite job: they prove that the two palettes are what the ROM says and that they differ in every band.
:::

### Section 6: The same trick, stacked vertically

Colour is not the only thing that can be interleaved. The same 30 Hz bargain buys vertical resolution, and it is the lesson's stretch exercise.

A 2600 frame has 192 visible scanlines and no way to offset the raster by half a line, so real 2:1 interlace is not available. What is available is the colour trick applied to lines: keep two 96-row bitmaps and show one per frame, on alternate scanlines.

```text
frame with Phase 0   field A on visible lines 0, 2, 4, ..., 190
                     the odd lines are blank
frame with Phase 1   field B on visible lines 1, 3, 5, ..., 191
                     the even lines are blank
```

Each field row is two scanlines tall: one line carries the row's playfield bytes, the next clears them. Over two frames the eye integrates the two fields and sees a 192-line picture, with every line refreshed at 30 Hz. The price is brightness — each line is lit on only half the frames — and the price is also honesty: a one-scanline feature cannot be shown by either field alone. It can only exist in the union, which exists only in the eye.

Exercise 2 builds exactly this: a 192-line image whose bar width is `1 + (y & 15)` chunks, split into even lines (field A) and odd lines (field B). In one field the bar's edge steps one chunk every two scanlines; interlaced it steps one chunk every scanline. That halving of the step height is the doubled resolution.

### Section 7: The frame ledger

The frame is the course's NTSC skeleton: 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262 lines. The visible 192 are eight bands of 24. The model's schedule, with the convention that a checkpoint's line/cycle is the instruction's start line and start cycle and cycle 0 is the first instruction after a `WSYNC` release:

| Checkpoint | Line/cycle | What it is |
|---|---|---|
| `StartFrame` | 259/3 | the first VSYNC line |
| `VblankStart` | 0/5 | the first VBLANK line |
| `BodyStart` | 37/5 | visible line 0 |
| `BandLoop` (first band) | 37/7 | the first band's colour load |
| `STA COLUBK`, band 0 | LDA 37/7; STA 37/11 → completes 37/14 | visible line 0's colour |
| `STA COLUBK`, bands 1-7 | STA 14 → completes 18 | the other seven boundaries |
| `OverscanStart` | 229/10 | the first blanked line; its `STA VBLANK` completes at 229/15 |

The eight `COLUBK` writes fall on visible lines 0, 24, 48, 72, 96, 120, 144 and 168 (absolute lines 37, 61, 85, 109, 133, 157, 181 and 205), which is exactly the band grid. The visible body is 229 - 37 = 192 lines, and 3 + 37 + 192 + 30 = 262. The model reports every frame at 19,912 cycles, the same 262 lines, across 420 consecutive frames including the phase changes and the demo's segment boundaries.

The state log for the same run is the phase story in one column: frames 1-119 step `Phase` 0, 1, 0, 1, ... (one step per frame); frame 120 sets `Freeze = 1` and `Phase = 0`; frames 120-239 hold phase 0; frame 240 sets phase 1; frames 240-359 hold phase 1; frame 360 clears `Freeze` and restarts. The staged bytes track the phase exactly: `4A 8A CA 2A 7A AA 3A 9A` while phase 0, `CA 4A 8A 8A EA 5A BA 7A` while phase 1.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson77.bin \
  lessons/part11-legendary/77-interlaced-flicker/77-interlaced-flicker.asm
stella build/lesson77.bin
```

The two exercise solutions sit beside the lesson source and are complete 4,096-byte ROMs:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part11-legendary/77-interlaced-flicker/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part11-legendary/77-interlaced-flicker/exercise-02-solution.asm
```

### Full Source

The complete annotated source, reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 77: Interlaced Flicker — Faking More Colours & Resolution
; =============================================================================
; Part 11: Legendary Techniques
;
; What this program does:
;   "the colour mosaic": eight horizontal bands, 24 scanlines each
;   (8 x 24 = 192 visible lines).  Each band is ONE flat colour written to
;   COLUBK at the band's first line.  The whole frame is a single TIA colour
;   register, rewritten eight times.
;
;   THE PICTURE IS DRAWN TWICE.  Palette A and palette B hold eight
;   DIFFERENT colours at the same eight positions, one pair per band.  On one
;   frame the mosaic is palette A; on the next frame it is palette B; then A
;   again.  Each palette is on screen 30 times a second, and the eye
;   integrates the alternation into a third colour per band:
;
;     band 0   red        $4A  +  green        $CA   -> yellow
;     band 1   blue       $8A  +  red          $4A   -> magenta
;     band 2   green      $CA  +  blue         $8A   -> cyan
;     band 3   orange     $2A  +  blue         $8A   -> white-ish
;     band 4   violet     $7A  +  yellow-green $EA   -> pale grey
;     band 5   aqua       $AA  +  pink         $5A   -> pale lavender
;     band 6   peach      $3A  +  teal-green   $BA   -> warm grey
;     band 7   light blue $9A  +  violet       $7A   -> pale blue-violet
;
;   Every byte above sits at luminance level 5 ($xA: hue in the high nibble,
;   level in bits 3-1).  Equal luminance is the design rule: the two frames
;   are at the same TIA luminance level; the composite luma stays close to constant
;   on real hardware, but the rendered brightness still varies with hue, so the
;   alternation is mildly flickery, not perfectly steady
;   of light.  A pair with different levels would flicker in brightness at
;   30 Hz and be much easier to see as flicker.
;
;   THE MECHANISM IS ONE BYTE.  Phase is 0 or 1.  Phase 0 draws palette A,
;   Phase 1 draws palette B.  Phase is advanced once per frame in the
;   vertical blank, before the picture starts, so a frame is never half one
;   palette and half the other: the band boundaries are at exactly the same
;   scanlines in both phases and only the colour bytes differ.  That exact
;   frame sync is what makes the blend clean; a phase change in the middle
;   of the picture would tear the mosaic.
;
;   THE BAND TABLE IS INDEXED Phase*8 + Band.  BandTable is sixteen bytes:
;   palette A then palette B.  The eight bytes the phase selects are copied
;   into the RAM array ActiveBand during VBLANK, and the kernel reads the
;   RAM copy.  Staging is not decoration: the beam reaches pixel 0 at cycle
;   22.67 of a scanline, and the staged read/write pair completes its store
;   at cycle 18.  Indexing the ROM table directly inside the band loop would
;   need Phase*8 + Band recomputed per band and would complete the store at
;   cycle 27 — after the beam has drawn the line's first 13 colour clocks,
;   a seam of the previous band's colour at every boundary.
;
;   THE KERNEL IS ONE LOOP, EIGHT TIMES.  Write COLUBK, hold it for 24
;   scanlines with WSYNC, advance to the next band.  The band is a flat
;   colour, so the TIA needs no more than the one write; the 24 WSYNCs are
;   the whole "graphics" of the row.
;
;   THE AUTO-DEMO exists so that two STILL screenshots can show both
;   phases (a still can only ever show one).  Counting the frames after
;   power-on from 1:
;
;     frames   1-119   the phase alternates every frame  (2 s of flicker)
;     frame  120       Freeze = 1, Phase = 0            (palette A held)
;     frame  240       Phase = 1                        (palette B held)
;     frame  360       Freeze = 0, the cycle restarts
;
;   The demo's own timer counts 120 frames per segment, so the three
;   boundaries are exactly 2 s, 4 s and 6 s after power-on: the phase-A
;   window is frames 120-239 and the phase-B window is frames 240-359.
;
;   SELECT toggles Freeze by hand and switches the auto-demo off: press it
;   once to hold whichever phase is showing, again to resume the flicker.
;   That is how a reader can put palette A and palette B side by side on
;   the same television, one after the other.
;
;   A STILL SHOWS ONE PHASE.  Stella's screenshot key, and any camera,
;   catches a single frame: all eight bands in palette A, or all eight in
;   palette B.  The blended third colour is never in the frame buffer; it
;   happens in the eye, over two frames.  The two committed captures are
;   the same ROM held on each phase, and they differ in every band.
;
;   THE FRAME (NTSC): 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262.
;   Measured schedule (the cycle-accurate model in the lesson text; the
;   convention is the instruction's start line and start cycle, cycle 0
;   being the first instruction after a WSYNC release):
;
;     StartFrame      259/3    the first VSYNC line
;     VblankStart       0/5    the first VBLANK line
;     BodyStart        37/5    visible line 0
;     BandLoop         37/7    the first band's colour load
;     OverscanStart   229/10   the first blanked line; the VBLANK store
;                              completes at 229/15, before pixel 0 at 22.67
;
;   The model reports every frame at exactly 19,912 cycles = 262 lines.
;
;   RAM map (the exact map; +clean_start zeroes every byte):
;     $80 Phase       0 = palette A, 1 = palette B
;     $81 Freeze      1 = hold the current phase (SELECT or the auto-demo)
;     $82 AutoDemo    1 until SELECT is pressed; then 0
;     $83 FrameLo     frame counter low byte, one increment per frame
;     $84 DemoTimer   frames inside the current 2-second demo segment (0..119)
;     $85 PrevSelect  SELECT edge latch: 0 = released, 1 = pressed
;     $86 DemoStep    the segment: 0 alternate, 1 hold A, 2 hold B
;     $87 ActiveBand  8 bytes: the colour of each band, staged this frame
;     $8F-$F7         free (105 bytes)
;     $F8-$FF         the stack (the deepest call is one level: 2 bytes)
;
; Build: acme -f plain -o build/lesson77.bin \
;        lessons/part11-legendary/77-interlaced-flicker/77-interlaced-flicker.asm
; Run:   stella build/lesson77.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK (Lesson 15)
OVERSCAN_TIMER = 36      ; 30-line overscan (Lesson 15)

BAND_COUNT     = 8       ; eight horizontal bands
BAND_LINES     = 24      ; 24 scanlines each
VISIBLE_LINES  = BAND_COUNT * BAND_LINES   ; 192

; The auto-demo's segment length and count (60 frames = 1 s):
DEMO_SEGMENT   = 120     ; 2 s per segment: alternate, hold A, hold B

; --- the palette bytes -------------------------------------------------------
; The TIA colour byte is %HHHHLLL0: hue in bits 7-4, luminance in bits 3-1.
; Every byte below is level 5 ($xA) so a pair is equal in brightness; only the
; hue changes between the two phases.  The hue names are the course's
; named-colour table from Lesson 13; the RGB triples in the lesson text are
; what Stella actually draws for these bytes.
C_RED          = $4A     ; hue 4,  level 5   (226,100, 99)
C_PEACH        = $3A     ; hue 3,  level 5
C_ORANGE       = $2A     ; hue 2,  level 5   (205,155, 62)
C_PINK         = $5A     ; hue 5,  level 5
C_VIOLET       = $7A     ; hue 7,  level 5   (139,100,223)
C_BLUE         = $8A     ; hue 8,  level 5   ( 90,100,224)
C_LIGHT_BLUE   = $9A     ; hue 9,  level 5
C_AQUA         = $AA     ; hue 10, level 5   ( 90,176,212)
C_TEAL         = $BA     ; hue 11, level 5
C_GREEN        = $CA     ; hue 12, level 5   (100,205, 99)
C_YELLOW_GREEN = $EA     ; hue 14, level 5

; The band arithmetic is a build-time assertion, not a comment.
!if BAND_COUNT * BAND_LINES != 192 {
    !error "the eight bands must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$8E; +clean_start zeroes every byte)
; =============================================================================
Phase        = $80   ; 0 = palette A, 1 = palette B
Freeze       = $81   ; 1 = hold the current phase
AutoDemo     = $82   ; 1 until SELECT is pressed
FrameLo      = $83   ; frame counter, one increment per frame
DemoTimer    = $84   ; frames inside the current demo segment (0..119)
PrevSelect   = $85   ; SELECT edge latch
DemoStep     = $86   ; the auto-demo segment: 0 alternate, 1 hold A, 2 hold B
ActiveBand   = $87   ; 8 bytes: $87-$8E, the colour of each band this frame
;
; $8F-$F7 are free (105 bytes).  The stack lives at $F8-$FF; the deepest call
; is StagePalette, one level, two bytes.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port
    STA NUSIZ0
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA CTRLPF              ; no playfield, no priority, a 1-pixel ball
    STA COLUPF
    STA COLUP0
    STA COLUP1
    STA COLUBK              ; a black screen until the first band write

; --- the first phase and the first staged palette ----------------------------
; Phase starts at 1, but the first frame's vertical blank steps it to 0, so
; the first picture drawn is palette A.  StagePalette copies the eight bytes
; of the selected palette out of the ROM table and into ActiveBand, so the
; first frame already has a full mosaic to draw.
    LDA #$01
    STA Phase
    LDA #$00
    STA Freeze              ; 0: the phase alternates from the first frame
    STA FrameLo
    STA DemoTimer
    STA PrevSelect
    STA DemoStep
    LDA #$01
    STA AutoDemo            ; 1: the frame-120/240/360 clock owns the phase
    JSR StagePalette

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    INC FrameLo

; -----------------------------------------------------------------------------
; 1. SELECT — freeze the phase by hand, and switch the auto-demo off
; -----------------------------------------------------------------------------
; SELECT is SWCHB bit 1, active low.  A NEW press toggles Freeze: from a
; running alternation it holds whichever phase is on screen; from a hold it
; starts the alternation again.  The edge latch (PrevSelect) is what makes it
; one toggle per press instead of one per frame.
    LDA SWCHB
    AND #$02                ; SELECT is active low
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$00
    STA AutoDemo            ; the reader owns the phase from now on
    LDA Freeze
    EOR #$01                ; toggle the hold
    STA Freeze
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; -----------------------------------------------------------------------------
; 2. THE AUTO-DEMO — alternate for 2 s, hold A for 2 s, hold B for 2 s, restart
; -----------------------------------------------------------------------------
; DemoTimer counts frames inside one two-second segment (0..119), and
; DemoStep counts which segment is running: 0 = alternate, 1 = hold palette A,
; 2 = hold palette B.  When the timer reaches 120 the segment is over: it
; resets and the next segment's action is applied.  The segment boundaries
; are therefore game frames 120, 240 and 360 — the same numbers a reader can
; watch in Stella as the three labels below.
    LDA AutoDemo
    BEQ DemoDone
    INC DemoTimer
    LDA DemoTimer
    CMP #DEMO_SEGMENT
    BCC DemoDone            ; still inside this segment
    LDA #$00
    STA DemoTimer           ; the next segment starts now
    INC DemoStep
    LDA DemoStep
    CMP #$01
    BNE DemoStep2
    LDA #$01
    STA Freeze              ; segment 1: pin the phase ...
    LDA #$00
    STA Phase               ; ... to palette A
    JMP DemoDone
DemoStep2:
    CMP #$02
    BNE DemoStep3
    LDA #$01
    STA Phase               ; segment 2: palette B (Freeze is already 1)
    JMP DemoDone
DemoStep3:
    LDA #$00
    STA Freeze              ; segment 3: release the hold ...
    STA DemoStep            ; ... and start the cycle again at segment 0
DemoDone:

; -----------------------------------------------------------------------------
; 3. ADVANCE THE PHASE — one step per frame, and only when it is not held
; -----------------------------------------------------------------------------
; This is the whole interlace: Phase 0 -> 1 -> 0 -> 1 ..., one step per
; frame, decided in VBLANK and staged below before the picture starts.  With
; Freeze set the step is skipped and the same palette is drawn again.
    LDA Freeze
    BNE PhaseFixed
    LDA Phase
    EOR #$01
    STA Phase
PhaseFixed:
    JSR StagePalette

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:                  ; checkpoint: scanline 37/5, visible line 0
    LDX #$00                ; start at band 0

; =============================================================================
; VISIBLE LINES 0-191: EIGHT BANDS OF 24 LINES, ONE COLUBK WRITE EACH
; =============================================================================
; The band loop is eight instructions of bookkeeping, one WSYNC per band line
; per band.
; Cycle ledger for the eight instructions that open a band, counted from the
; WSYNC release of the previous band's last line:
;
;   DEY              2     0- 1   the band's last line: Y reaches 0
;   BNE BandLines    2     2- 3   not taken at the end of the band
;   INX              2     4- 5
;   CPX #BAND_COUNT  2     6- 7
;   BNE BandLoop     3     8-10   taken for bands 0-6
;   LDA ActiveBand,X 4    11-14
;   STA COLUBK       3    15-17   completes at cycle 18
;
; The beam reaches pixel 0 at cycle 22.67, so the colour is in place with
; 4.67 cycles (14 colour clocks) to spare.  The first band of the frame is
; even earlier: BodyStart runs at 37/5 directly after the VBLANK store, so
; its LDA starts at cycle 7 and its store completes at cycle 14.
BandLoop:
    LDA ActiveBand,X        ; the colour this phase puts in this band
    STA COLUBK              ; the frame's only graphics register
    LDY #BAND_LINES
BandLines:
    STA WSYNC               ; hold the band for one scanline
    DEY
    BNE BandLines
    INX
    CPX #BAND_COUNT
    BNE BandLoop

; --- the last band has been drawn (visible line 191); the blank starts -------
OverscanStart:              ; checkpoint: scanline 229, the first blanked line
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; STAGEPALETTE — copy the selected palette out of the ROM table into RAM
; =============================================================================
; The table index is Phase*8 + Band: Phase*8 is the palette's first byte
; (0 for A, 8 for B), and the eight stores walk from there to the end of the
; palette.  Y counts the source index, X the destination band.
;
; Why stage at all?  The kernel could index BandTable directly if it
; recomputed Phase*8 + Band per band, but TXA/CLC/ADC/TAY/LDA abs,Y/STA costs
; 16 cycles after the eleven that reach the band's colour load, so the store
; would complete at cycle 27 — 4.33 cycles after the beam has started drawing
; pixel 0 at 22.67, leaving a seam of the previous band's colour at each
; boundary.  Eight bytes of RAM buy the difference.
StagePalette:
    LDA Phase
    ASL                     ; Phase * 2
    ASL                     ; Phase * 4
    ASL                     ; Phase * 8
    TAY                     ; Y = the palette's first table index
    LDX #$00
.copy:
    LDA BandTable,Y
    STA ActiveBand,X
    INY
    INX
    CPX #BAND_COUNT
    BNE .copy
    RTS

; =============================================================================
; THE BAND TABLE — palette A, then palette B (index = Phase*8 + Band)
; =============================================================================
; Each row of the comment above is one BandTable offset in both palettes.
; The two bytes of a pair are equal in luminance and far apart in hue; the eye
; adds them over two frames.  Read the pairs down the columns:
;
;   band  offset  palette A                palette B
;     0     0     red        $4A (hue  4)  green        $CA (hue 12)
;     1     1     blue       $8A (hue  8)  red          $4A (hue  4)
;     2     2     green      $CA (hue 12)  blue         $8A (hue  8)
;     3     3     orange     $2A (hue  2)  blue         $8A (hue  8)
;     4     4     violet     $7A (hue  7)  yellow-green $EA (hue 14)
;     5     5     aqua       $AA (hue 10)  pink         $5A (hue  5)
;     6     6     peach      $3A (hue  3)  teal-green   $BA (hue 11)
;     7     7     light blue $9A (hue  9)  violet       $7A (hue  7)
BandTable:
    ; --- palette A: the even frames ------------------------------------------
    !byte C_RED, C_BLUE, C_GREEN, C_ORANGE
    !byte C_VIOLET, C_AQUA, C_PEACH, C_LIGHT_BLUE
    ; --- palette B: the odd frames -------------------------------------------
    !byte C_GREEN, C_RED, C_BLUE, C_BLUE
    !byte C_YELLOW_GREEN, C_PINK, C_TEAL, C_VIOLET

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
> `lessons/part11-legendary/77-interlaced-flicker/77-interlaced-flicker.asm`.

### Code Walkthrough

#### Step 1 — Reset, the first phase, and the first staged palette

`Reset` is the course's `+clean_start` plus the fixed TIA state: every graphics register at zero, `CTRLPF` at zero (reflect off, score mode off, no priority; the playfield is blank because PF0/1/2 are zero), and `COLUBK` black until the first band write. Then the variables:

```asm
    LDA #$01
    STA Phase
    LDA #$00
    STA Freeze              ; 0: the phase alternates from the first frame
    STA FrameLo
    STA DemoTimer
    STA PrevSelect
    STA DemoStep
    LDA #$01
    STA AutoDemo
    JSR StagePalette
```

`Phase` starts at 1 only because the first frame's vertical blank steps it to 0 with `EOR #$01`; the first picture drawn is palette A. `StagePalette` is called once here so that the very first frame has a full `ActiveBand` array — it is a redundant first staging: the first blank steps Phase and stages the palette again before VBLANK is cleared.

#### Step 2 — The vertical blank: SELECT, the demo, the phase step

Three things happen in the blank, in this order.

**SELECT** (SWCHB bit 1, active low) is read with an edge latch. A new press sets `PrevSelect`, clears `AutoDemo`, and toggles `Freeze`:

```asm
    LDA SWCHB
    AND #$02                ; SELECT is active low
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$00
    STA AutoDemo            ; the reader owns the phase from now on
    LDA Freeze
    EOR #$01
    STA Freeze
```

**The auto-demo** counts 120 frames per segment. When `DemoTimer` reaches 120 it resets and `DemoStep` advances: 1 pins palette A, 2 writes palette B, and 3 releases the freeze and resets the step. The three segment boundaries are the 120th, 240th and 360th frames after power-on.

**The phase step** is the interlace itself:

```asm
    LDA Freeze
    BNE PhaseFixed
    LDA Phase
    EOR #$01
    STA Phase
PhaseFixed:
    JSR StagePalette
```

One `EOR` per frame while the freeze is clear, none while it is set. The `JSR` immediately after is deliberate: the phase and the bytes the kernel will use are always updated together, in the same blank.

#### Step 3 — Staging: `Phase*8 + Band` into RAM

`StagePalette` shifts `Phase` left three times to make the table offset, then copies eight bytes:

```asm
    LDA Phase
    ASL
    ASL
    ASL
    TAY
    LDX #$00
.copy:
    LDA BandTable,Y
    STA ActiveBand,X
    INY
    INX
    CPX #BAND_COUNT
    BNE .copy
```

`Y` runs from the palette's first table index to its last; `X` runs over the eight bands. The routine touches only `A`, `X` and `Y`, so the kernel's later `LDX #$00` is the only other setup it needs. Its cost is about 155 cycles (135 for the copy loop) — nothing in a 2,753-cycle vertical blank.

#### Step 4 — The band kernel

The kernel is the nine-instruction loop from Section 4. Two details are worth naming:

- **The `STA WSYNC` uses `A`**, which still holds the band's colour, and stores it to `WSYNC`, which ignores the value. That is why the same `A` survives the 24-line hold and does not have to be reloaded.
- **The last line of a band takes the not-taken branch.** `DEY` reaches 0 before the `BNE`, so the branch costs 2 cycles instead of 3 and the band boundary's arithmetic starts four cycles after the `WSYNC` release. That is the arithmetic in the ledger above.

The colour is written during the band's first line's HBLANK, before the beam starts drawing that line's pixels, and the TIA holds it until the next write. The remaining 23 lines of the band are pure `WSYNC` holds.

#### Step 5 — The frame end

After the last band, `OverscanStart` sets `VBLANK` bit 1 and starts the 30-line overscan timer:

```asm
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame
```

The `STA VBLANK` completes at 229/15, well before pixel 0 of line 229 at cycle 22.67, so the first blanked line is a clean one. `+wait_timer` ends with a `WSYNC`, which puts `JMP StartFrame` at 259/0 and `StartFrame` at 259/3 — the same anchor as every other lesson.

#### Step 6 — Reading it back in Stella

Open the debugger and watch four things:

| Address | What it is | What to look for |
|---|---|---|
| `$80` (`Phase`) | 0 = palette A, 1 = palette B | it flips once per frame while `Freeze` is 0 |
| `$81` (`Freeze`) | the hold | it becomes 1 on the 120th frame and 0 on the 360th |
| `$86` (`DemoStep`) | 1 hold A, 2 hold B | it advances only at the segment boundaries |
| `$87-$8E` (`ActiveBand`) | the eight staged colours | all eight change together when `Phase` flips |

The ROM's `BandTable` lives at `$F106`: sixteen bytes, palette A first. Set a breakpoint on `StagePalette` (`$F0F2`) and you will see `A` = `Phase`, then `Y` = 0 or 8, then the eight copies.

## What You Should See

At power-on the screen is a stack of eight flat bands, 24 scanlines each, and it is already alternating between the two palettes. The first frame drawn is palette A from top to bottom: red, blue, green, orange, violet, aqua, peach, light blue. Every band fills the full width; there is no playfield, no sprite and no border. If you sit back, the stack does not look like eight colours — it looks like eight *other* colours, and it is close to steady rather than flashing: yellow, magenta, cyan, a warm white-ish, pale grey, pale lavender (periwinkle), warm grey and pale blue-violet. That steady blended stack is the whole effect, and it is the one thing a photograph cannot show you.

The ROM alternates for two seconds, holds palette A for two seconds, holds palette B for two, then repeats. The two captures below were taken inside the two holds, so each is a genuine single frame of the same committed ROM.

![Stella running Lesson 77 in the phase-A hold: eight flat horizontal bands of red, blue, green, orange, violet, aqua, peach and light blue](/images/lesson77/phase-a.png)

*`phase-a.png`: the phase-A hold, game frames 120-239. Eight bands, 24 scanlines each, in palette A. Every band is one `COLUBK` write.*

<RomPlayer rom="/roms/part11-legendary/77-interlaced-flicker/77-interlaced-flicker.bin" title="Lesson 77 — Interlaced Flicker — Faking More Colours & Resolution" />

*Javatari starts muted; this ROM is silent. Javatari runs at 60 frames a second, so the ROM plays as it should: the first two seconds alternate, then each palette holds for two seconds. The blend happens in your eye.*

![Stella running Lesson 77 in the phase-B hold: the same eight bands in green, red, blue, blue, yellow-green, pink, teal and violet](/images/lesson77/phase-b.png)

*`phase-b.png`: the phase-B hold, game frames 240-359. The same eight bands, the same boundaries, palette B. Nothing moved; eight colour bytes changed.*

The two images are different states, not two copies of one picture. The **pixel check** of the committed captures, one sample at each band's centre:

| Band | Palette A byte | Sampled RGB | Palette B byte | Sampled RGB | Different? |
|---|---|---|---|---|---|
| 0 | `$4A` red | (226, 100, 99) | `$CA` green | (100, 205, 99) | yes |
| 1 | `$8A` blue | (90, 100, 224) | `$4A` red | (226, 100, 99) | yes |
| 2 | `$CA` green | (100, 205, 99) | `$8A` blue | (90, 100, 224) | yes |
| 3 | `$2A` orange | (205, 155, 62) | `$8A` blue | (90, 100, 224) | yes |
| 4 | `$7A` violet | (139, 100, 223) | `$EA` yellow-green | (176, 188, 83) | yes |
| 5 | `$AA` aqua | (90, 176, 212) | `$5A` pink | (208, 97, 188) | yes |
| 6 | `$3A` peach | (224, 141, 77) | `$BA` teal-green | (90, 204, 165) | yes |
| 7 | `$9A` light blue | (90, 151, 221) | `$7A` violet | (139, 100, 223) | yes |

Every sampled colour equals the byte's rendered value in Stella's NTSC palette, and every band differs between the two images: eight of eight. The band boundaries are at picture rows 106, 181, 257, 333, 409, 485, 560, 636 and 712 in both images — the interpolation rows at 181, 257, 333, 409, 485, 560 and 636 are the emulator scaling 192 scanlines to 606 pixels (3.156 pixels per line, so 24 lines is 75.8 pixels). The geometry is identical in the two phases, which is the point: only the eight colour bytes changed.

> **The captures show the phases, not the blend.** A still is one frame. The blended colour exists only in the eye across two frames, so no screenshot — not these, not yours — can contain it. The two images are evidence that the two palettes are what the ROM says, and that they differ in every band.

> **Capture method.** Both images are `scripts/capture-screenshot.sh` captures of the committed
> `docs/public/roms/part11-legendary/77-interlaced-flicker/77-interlaced-flicker.bin`, at
> approximately 3.5 and 5.5 wall-clock seconds after launch, with the pointer parked at (0, 0).
> Stella's window title reads `Stella 7.0: "77-interlaced-flicker"`, both images are 1010x807,
> and neither contains a cursor. The 3.5-second capture lands inside the phase-A hold (game
> frames 120-239) and the 5.5-second one inside the phase-B hold (frames 240-359); the phase of
> each image was confirmed by sampling all eight band centres against the table above.

The **frame log** is the clock behind the pictures:

| Checkpoint | Line/cycle | What it proves |
|---|---|---|
| `StartFrame` | 259/3 | the VSYNC begins at line 259 |
| `VblankStart` | 0/5 | the blank begins at line 0 |
| `BodyStart` | 37/5 | the picture begins at line 37, every frame |
| `LDA ActiveBand,X` | 37/7 for band 0; cycle 11 for bands 1-7 | the band's colour load |
| `STA COLUBK` | completes 37/14 for band 0; cycle 18 for bands 1-7 | before pixel 0 at 22.67 |
| `OverscanStart` | 229/10 | the picture ends at 228; the blank begins at 229 |

The frame is 262 lines; the visible body is 229 - 37 = 192; the band grid is 8 x 24 = 192. The model reports 19,912 cycles — exactly 262 lines — for all 420 frames it runs, including the phase changes.

The **phase log** from the same run, in the frames around each boundary:

```text
frame  Phase Freeze Step   the eight staged bytes
  118      1      0    0   CA 4A 8A 8A EA 5A BA 7A     alternating
  119      0      0    0   4A 8A CA 2A 7A AA 3A 9A     alternating
  120      0      1    1   4A 8A CA 2A 7A AA 3A 9A     frame 120: hold A
  121      0      1    1   4A 8A CA 2A 7A AA 3A 9A
  238      0      1    1   4A 8A CA 2A 7A AA 3A 9A
  239      0      1    1   4A 8A CA 2A 7A AA 3A 9A
  240      1      1    2   CA 4A 8A 8A EA 5A BA 7A     frame 240: hold B
  241      1      1    2   CA 4A 8A 8A EA 5A BA 7A
  359      1      1    2   CA 4A 8A 8A EA 5A BA 7A
  360      0      0    0   4A 8A CA 2A 7A AA 3A 9A     frame 360: release
  361      1      0    0   CA 4A 8A 8A EA 5A BA 7A     alternating again
  362      0      0    0   4A 8A CA 2A 7A AA 3A 9A
```

`Phase` steps on every frame while `Freeze` is 0, and the staged bytes follow it on the same frame. The freezes are the two flat runs: 120 frames of `4A 8A CA 2A 7A AA 3A 9A` followed by 120 frames of `CA 4A 8A 8A EA 5A BA 7A`.

> **How the log was produced.** The checkpoint values and the phase log come from a
> cycle-accurate model of this exact binary: the 6502 instruction subset with real cycle counts
> and branch penalties, the RIOT 64-cycle timer, `WSYNC` stalls to the next 76-cycle line
> boundary, and the frame boundary defined as the release of the third VSYNC `WSYNC`. The
> captures corroborate it: the picture is stable, the eight band boundaries sit exactly 24
> visible lines apart, and the picture area matches the 192-line body. Stella's own instruction
> trace was not captured for this lesson.

## Exercises

Each exercise ships a complete 4,096-byte `exercise-NN-solution.asm`. The solutions assemble through `npm run roms`, run in Stella, and solve the exercise as written.

### Exercise 1: Three Palettes, Reverse Order

**Challenge:** give the mosaic a **third** palette pair and run the phases in **reverse order**. The band table becomes 24 bytes (palettes A, B and C); the phase steps 2 → 1 → 0 → 2 instead of 0 → 1 → 0; and the auto-demo holds the palettes in reverse too — C from the 120th frame, B from the 240th, A from the 360th, with the freeze released at the 480th. Keep the picture eight bands of 24 lines, the frame at 262 lines and the ROM at 4,096 bytes.

**Hints:**

1. `StagePalette` already computes `Phase*8`. Three phases just mean `Phase` can be 0, 1 or 2, and the table grows to 24 bytes. Nothing in the kernel changes.
2. The reverse step is a three-entry table, `NextPhase = {2, 0, 1}`: read as "the phase after this one". `LDX Phase` / `LDA NextPhase,X` / `STA Phase` replaces the `EOR #$01`.
3. The demo needs one more segment. `HoldPhase = {2, 1, 0}` indexed by `DemoStep - 1` gives the reversed hold order, and `DemoStep` reaching 4 instead of 3 releases the freeze.
4. Palette C can be anything that differs from both other palettes in every band. The solution uses peach, aqua, pink, violet, light blue, orange, green and red.

**Expected Result:** the ROM assembles to exactly 4,096 bytes and the frame stays at 262 lines. The phase log shows 2, 1, 0, 2, ... (palette C, then B, then A); the hold windows are C for frames 120-239, B for 240-359 and A for 360-479, and the alternation resumes at the 480th frame. Stella captures at 3.5, 5.5 and 7.5 seconds (after the ~0.5 s startup) show palette C, palette B and palette A. The lesson of the exercise is the cost: three palettes means each colour is on screen one frame in three, a 20 Hz repetition, and the mosaic now visibly flickers where the two-palette version looked close to steady.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Field Interlace — Doubling the Line Count *(Stretch Goal)*

**Challenge:** apply the interlace to lines instead of colours. Store **two** 96-row bitmaps. On phase 0 draw field A on the even visible lines and leave the odd lines blank; on phase 1 draw field B on the odd lines and leave the even lines blank. Each field row is two scanlines tall. The two fields are the even and the odd lines of one 192-line image, so the eye sees 192 addressed lines at 30 Hz. Keep the frame at 262 lines and the ROM at 4,096 bytes.

**Hints:**

1. The image used by the solution is a bar whose width is `n = 1 + (y & 15)` chunks, for image line `y`; `CTRLPF`'s REFLECT bit mirrors the left half, so the bar grows from both edges toward the centre and closes every 16 lines.
2. Field A row `k` is image line `2k` (widths 1, 3, 5, ... 15); field B row `k` is image line `2k+1` (widths 2, 4, 6, ... 16). Store each field as three parallel 96-byte arrays, one per playfield register, so `X` can be the row index for all three loads.
3. Use one kernel per field, selected once per frame from `Phase`, and no per-row branch. Field A's pattern line is the row's first line: PF0 must beat cycle 22.67, PF1 28.0 and PF2 38.7 (the first row lands 19/26/33, later rows 14/21/28). Field B's pattern line is the row's second line, so its writes start from a bare `WSYNC` release.
4. The blank line is the same three playfield registers written with `0`. Do not try to write the pattern and blank on the same line: the PF registers are live, so a later write blanks only the rest of that line; the pattern and the zero must go on different lines.

**Expected Result:** the ROM assembles to exactly 4,096 bytes and the frame stays at 262 lines. Each capture shows 96 lit scanlines of 192, one per field row, with a 2-scanline period; the two fields' lit lines are one scanline apart, so the union covers every line. The solution's pixel check: the field-A and field-B captures (local verification; not committed) agree on 95% of the 606 picture rows at a 3-row vertical shift, and the window scales 192 lines to 606 pixels, so the shift is 0.95 scanlines — the two fields are the same picture offset by one line. A still shows every other line black; on screen the two fields fuse into a 192-line picture at half brightness.

**Solution:** See `exercise-02-solution.asm`

## Key Takeaways

- ✅ **Time is a third axis on top of hue and luminance.** Two whole pictures alternating at 30 Hz give the eye a colour neither frame contains. The TIA has 128 colours; the duty cycle extends the palette without adding a register.
- ✅ **Whole-frame interlacing is not object flicker.** Lesson 51 alternates objects inside one picture and pays in ghosting and strobing motion. Here the geometry never changes, so the only difference the eye can see is colour, and the only thing it can do with it is average.
- ✅ **The phase must change in the vertical blank, and the picture must not.** One `EOR` per frame before `VBLANK` is cleared, staged in the same blank, guarantees that every frame is one complete palette and that the band boundaries sit on the same scanlines in both phases.
- ✅ **Equal luminance is what makes a blend read as colour.** Every byte in the lesson is level 5; a pair with unequal levels would flash at 30 Hz, and a brightness flash is far more visible than a hue shift.
- ✅ **The eight colours are staged because the beam will not wait.** Pixel 0 arrives at cycle 22.67 of each line. The staged `LDA`/`STA` completes at 18; recomputing `Phase*8 + Band` inside the loop completes at 27 and leaves a seam at every band.
- ✅ **A still can only show one phase.** The blend is temporal, so no screenshot contains it. The auto-demo's two-second holds are what make the two phases capturable, and the two committed images differ in all eight bands.
- ✅ **The same trick stacks vertically.** Two 96-row fields, one per frame, on alternate scanlines, fake a 192-line bitmap at 30 Hz — at half brightness, and with one-scanline detail living only in the union.

## What's Next

The mosaic ends with the two phases and the field-interlace stretch; [the Part 11 index](/part11-legendary/) lists the rest of the anthology. The next lesson, **Lesson 78 — Room & Object Engine — The Adventure Architecture**, changes the question from how a frame is coloured to how a whole game fits in 4K: a room table, an object table, and one engine that interprets both. Return to the index for the part's overview.
