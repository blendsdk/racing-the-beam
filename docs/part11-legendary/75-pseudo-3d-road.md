---
title: "Lesson 75: Pseudo-3D Road — The Enduro / Pole Position Effect"
description: "Draw a road that widens to a horizon by writing the playfield twice per scanline: two 20-entry mask tables give the left and right edges, a 32-entry curve table shifts the centre, a clamp keeps the road across the screen's midpoint, and 22 rows of five scanlines rebuild the edge tables in the vertical blank."
prev:
  text: "Part 11: Legendary Techniques"
  link: "/part11-legendary/"
next:
  text: "Part 11: Legendary Techniques"
  link: "/part11-legendary/"
---

# Lesson 75: Pseudo-3D Road — The Enduro / Pole Position Effect

> **Part 11: Legendary Techniques** · Estimated time: 120 minutes
> **Prerequisites:** Lesson 12 (the NTSC frame), Lesson 14 (WSYNC and scanline timing), Lesson 15 (the RIOT timer), Lesson 17 (cycle counting), Lesson 19 (playfield basics), Lesson 20 (playfield colours), Lesson 21 (the asymmetric playfield), Lesson 23 (data-driven playfield), Lesson 26 (positioning objects, RESP and HMOVE), Lesson 49 (the 2-line kernel), Lesson 52 (fine scrolling)
> **You will learn:** how a road that appears to run to a horizon is built from per-scanline tables rather than geometry; how two 20-entry mask tables turn a left edge and a right edge into the six playfield bytes a line needs; why the playfield must be written twice on **every** scanline and where the two write windows sit; how a clamp turns a constant-amplitude curve into a perspective curve for free; and how the per-row arithmetic moves into the vertical blank so the kernel is nothing but table lookups.
> **You will build:** "the road" — a 4,096-byte ROM with a 40-row sky, a gold sun, a horizon band and a 22-row road that widens from 3 playfield chunks to 21, with a dashed centre line and a curve that switches on and off every three seconds. Plus two complete exercise solutions: a night palette with a wider road, and a three-phase demo that curves right and then left.

## Introduction

Lessons 19 to 24 built the playfield one idea at a time: twenty chunks of four pixels, three registers, and — in Lesson 21 — the trick of rewriting those registers **during** the line so the left half and the right half show different patterns. Lesson 49 showed the comfortable kernel arithmetic: one byte of picture data per two scanlines, 96 rows, plenty of cycles to spare.

A **pseudo-3D road** is what happens when you take the asymmetric playfield seriously and let every scanline be different. There is no geometry anywhere in this program. There is no road, no perspective, no vanishing point. There is a table of half-widths, a table of curve offsets, and a routine that turns each row into six playfield bytes. The picture is 110 hand-tuned bands of grass and grey; the eye supplies the road.

That is exactly how *Enduro* and *Pole Position* did it on the same hardware: per-scanline control of a pattern that the player reads as a road. This lesson rebuilds the effect from the two pieces the course has already given you — the mask tables and the mid-line rewrite — and then spends most of its effort on the part that actually bites: **the budget**. A line is 76 cycles, the playfield needs six of those writes, and the TIA re-reads the registers on every scanline, so the left/right pair has to be re-established on all 192 visible lines, every frame.

The companion program `75-pseudo-3d-road.asm` makes the mechanism visible: the road's left edge steps outward one playfield chunk at a time as you move down the screen, the right edge steps the other way, a green four-pixel gap dashes down the middle, and every three seconds the whole road leans into a curve before snapping straight again.

::: details TypeScript Equivalent

The natural model is a per-row width and centre, exactly the values the tables hold:

```typescript
/** One road row: half-width in 4-pixel chunks, and a signed centre offset. */
function edge(row: number, scroll: number, curved: boolean): [number, number] {
  const half = HALF[row];                       // 2..10 chunks each side here
  const raw = curved ? CURVE[(row - scroll) & 31] : 0;
  const maxOff = half - 1;                      // the clamp
  const c = Math.max(-maxOff, Math.min(maxOff, raw));
  const leftChunk = 20 - half + c;              // 1..19
  const rightChunk = 20 + half + c;             // 21..39
  const centre = 20 + c;                        // where the dash gap goes
  return [leftChunk, rightChunk];
}

/** The three playfield bytes a row needs, with the centre gap applied. */
function masks(row: number, dash: number): [number, number, number] {
  const [l, r] = edge(row, scroll, curved);
  const g = (l + r) / 2;                        // == 20 + c
  const gapOn = HALF[row] >= 4 && ((row - dash) & 3) < 2;
  const clear = (base: number, bit: number) => (gapOn ? base & ~(1 << bit) : base);
  return [
    clear(LEFT_PF2[l], g - 12),                 // left half,  chunk 12..19
    clear(RIGHT_PF0[r - 20], g - 16),           // right half, chunk 20..23
    RIGHT_PF1[r - 20],                          // never takes the gap
  ];
}

/** One scanline: the six register writes. */
function drawLine(row: number): void {
  const [l2, r0, r1] = masks(row, dash);
  write(PF0, LEFT_PF0[L[row]]);  write(PF1, LEFT_PF1[L[row]]);  write(PF2, l2);
  write(PF0, r0);                write(PF1, r1);                write(PF2, RIGHT_PF2[R[row]]);
}
```

The analogy breaks in four places. There is no `out[]` array: the playfield is three 8-bit registers, and "chunk 23" only exists while the beam is passing it. The loop over 40 chunks is free in TypeScript; the real one is six stores with deadlines measured in color clocks, and two of them must land *after* the TIA has finished with the left half. The clamp is an ordinary `Math.min`; on the 6502 it is a two's-complement dance with a branch on each side, which is why this lesson measures it and then moves it out of the kernel entirely. And the 262 lines are not a nested loop you can reorder — they are a deadline per scanline, every frame.

:::

## Theory

### The illusion: 110 bands, not geometry

A road receding to a horizon looks like perspective. On the 2600 it is a **staircase**. The playfield is 40 chunks of 4 pixels across the visible line; the road is a contiguous run of those chunks, and the run gets longer as you move down the screen. This ROM uses 22 road rows of five scanlines each:

| Row | Half-width | Left chunk | Right chunk | Width |
|---:|---:|---:|---:|---:|
| 0 | 1 | 19 | 21 | 3 chunks (12 px) |
| 5 | 2 | 18 | 22 | 5 chunks (20 px) |
| 10 | 5 | 15 | 25 | 11 chunks (44 px) |
| 15 | 7 | 13 | 27 | 15 chunks (60 px) |
| 21 | 10 | 10 | 30 | 21 chunks (84 px) |

The half-width comes from a 22-byte table, `HalfTable`. It grows slowly near the horizon and faster near the viewer, which is the shape a flat road projects onto a screen: the screen distance between two points on the road is proportional to one over their distance from the camera, so equal steps away from you compress toward the horizon and the width grows to match.

The word "pseudo" in the lesson title is honest. Nothing in the ROM knows what a road is. Change `HalfTable` and you get a different road; the rest of the program does not care.

::: tip Why the road is 3 chunks wide at the horizon, not 2

The road spans chunks `L..R` **inclusive**, so a half-width of `H` produces `2H + 1` chunks. `HalfTable[0]` is 1, which gives chunks 19, 20 and 21 — twelve pixels. The narrowest possible road that still crosses the screen's centre is three chunks, because `L` must be 19 or less and `R` must be 21 or more. That one-chunk floor is what the clamp exists to protect.

:::

### Two tables and a clamp

Each row needs two numbers: where the road starts and where it ends. The ROM stores them as one half-width plus one signed offset:

```
Half[r]   the road's half-width in chunks            (1..10)
Curve     the signed offset from a 32-entry table    (-6..+6)
c         Curve, clamped to -(Half-1) .. +(Half-1)
L         the left edge chunk  = 20 - Half + c
Ridx      the right edge index =      Half + c      (the right chunk is Ridx + 20)
```

`Curve` is read from a 32-entry table indexed by `(row − Scroll) & 31`. `Scroll` advances once every eight frames, so the curve pattern **crawls down the road** toward the viewer — the same trick Lesson 52 used to scroll a background, applied to a shape instead of a picture. The subtraction is what sets the direction: `row − Scroll` puts a bend at row `index + Scroll` and moves it down the screen as `Scroll` rises, while `row + Scroll` would move it toward the horizon. In the straight demo phase a mask byte zeroes the curve, so the same code path draws both states.

The clamp is the interesting part. The road is drawn as "left half: chunks `L`..19" and "right half: chunks 20..`R`", which only works if the road actually crosses the boundary at chunk 19/20. If the curve pushed the centre far enough, a narrow road could end up entirely inside one half and the two mask tables would draw nonsense. Clamping `c` to `±(Half - 1)` keeps `L ≤ 19` and `R ≥ 21` with one symmetric bound — and it does something better than that:

> **The clamp is the perspective.** At row 0 the half-width is 1, so the clamp is zero and the narrow road cannot move at all: it stays dead centre. At row 21 the half-width is 10, so the clamp is ±9 and the full ±6 curve passes. Between them the road's centre is allowed to move in proportion to how wide the road is — which is exactly how a real curve looks, tight at the horizon and wide near you. The perspective falloff of the curve is not drawn; it falls out of the width clamp.

:::

### The asymmetric playfield, and why it does not survive the line

Lesson 21 established the mechanism: the TIA reads the playfield registers once for the left half and again for the right half, so if you rewrite them in between, the two halves differ. What Lesson 21 did not have to face is that **the registers are re-read on every scanline**. The value you write at cycle 10 is not "the value for this row": it is the value the TIA uses until it reads the register again, which it does 76 cycles later.

The TIA does not latch the whole playfield at one instant either. Each register is read as the beam arrives at its chunks, so a write only affects the chunks the beam has not reached yet. The visible area starts 68 color clocks — **22.67 CPU cycles** — after the `WSYNC` release, so pixel x is drawn at cycle `22.67 + x/3`:

| Register | Pixels | Cycles |
|---|---|---:|
| left `PF0` | 0–15 | 22.67 – 27.67 |
| left `PF1` | 16–47 | 28.00 – 38.33 |
| left `PF2` | 48–79 | 38.67 – 49.00 |
| right `PF0` | 80–95 | 49.33 – 54.33 |
| right `PF1` | 96–127 | 54.67 – 65.00 |
| right `PF2` | 128–159 | 65.33 – 75.67 |

Two constraints follow, one per half. The **left** byte must be in the register before the visible area starts drawing that register's chunks; the **right** byte must be written after the left chunks for that register have gone by and before the right chunks arrive:

| Byte | Written at | Must be after | Must be before |
|---|---:|---:|---:|
| `PF0` left | 11 | — | 22.67 |
| `PF1` left | 18 | — | 28.00 |
| `PF2` left | 25 | — | 38.67 |
| `PF0` right | 36 | 27.67 | 49.33 |
| `PF1` right | 43 | 38.33 | 54.67 |
| `PF2` right | 54 | 49.00 | 65.33 |

The tightest write in that table is right `PF1` at 43, with 4.7 cycles (14 color
clocks) of margin; the rest are looser — right `PF2` has 11.3, left `PF0` 11.7, left `PF2` 13.7 and right `PF0` 13.3. **The tightest is right `PF1` at 4.7.**

::: warning The 22.67-cycle offset is easy to lose

Dividing a pixel number by three gives the cycle measured from the start of the **visible** area, not from the `WSYNC` release. A schedule built on those numbers writes everything 22.67 cycles — one horizontal blank — too early, and the halves come out swapped. That failure was measured on this ROM, not guessed: with the "right" group written at cycles 10/19/30 and the "left" group at 40/47/60, the capture showed the right-hand mask on the left half and the left-hand mask on the right.

A probe ROM settles it. It writes `PF1` = `$FF` at cycle 5 and `PF1` = `$00` at cycle 32, and the left half comes out white only from x 16 to x 31: the changeover is inside the left `PF1` field and near its end, which only happens if the left `PF1` window is still open at cycle 32 — that is, if it starts around cycle 28, 22.67 cycles after the `WSYNC` release. A second build writes the `$00` at cycle 11 and produces no white at all, because that write lands before the window opens. Under a schedule measured from the start of the visible area the first probe would split near x 96 and the second near x 33; neither is what the captures show. The formula is good to a cycle or two only because the write lands in the middle of a four-pixel chunk, so the ROM is checked against the captures rather than against the arithmetic.

:::

::: tip Why one line of every row used to be wrong

An earlier version of this kernel computed the dash mask on line 1 of each row and drew on all five. Line 1 was 18 cycles longer than the others, so on line 1 alone the right-half stores landed past their windows — and every road row showed a one-scanline seam. The fix is in the ROM you are reading: the dash mask moved into the vertical blank, and every drawing line is now the same 54 cycles. Timing bugs in a kernel rarely look like timing bugs; they look like one bad scanline in a repeating pattern.

:::

### The budget: why a road row is five scanlines

Add the drawing line up: 54 cycles for the six stores, out of 76. That leaves 22 cycles per line for everything else — and the per-row road arithmetic (width, curve, clamp, two edge lookups) measures 81 to 85. Two lines would not hold it, and neither would three.

So the arithmetic leaves the kernel. The **vertical blank** rebuilds two 22-byte tables, `LTable` and `RidxTable`, whenever the scroll or the curve changes:

| Work | Cycles per row | Rows | Total |
|---|---:|---:|---:|
| pass A: width, curve, clamp, two edge lookups | 81–85 | 22 | ~1870 |
| pass B: centre chunk, two masked bytes | 113 | 22 | 2486 |
| demo timers, colours, SELECT | | | ~180 |

Pass A is 23 of the 37 blank lines and the measured finish is scanline 23 to 26.
Pass B is bigger, and the two together would not fit, so the ROM **defers pass B
by one frame whenever pass A runs**: a frame carries at most 2486 + 180 cycles,
well inside the 2812-cycle blank, and the dashes — which step every two
frames — are one frame late once every eight, which at 30 Hz is invisible.
Measured: `BodyStart` is 37 on 457 consecutive frames.

With the arithmetic gone the kernel is pure lookups: 54 cycles of stores, 22 cycles spare. Why then does a row need **five** lines? Not because the hardware demands it — the kernel would work on a two-line row — but because 22 rows × 5 lines = 110 lines is what makes the band split land on 192 under an 80-line sky and two horizon lines, and because five lines per width step keeps the road's edge from stepping too fast. The five-line row is a deliberate choice about vertical resolution, and it is the one accepted deviation from a two-line row.

| Band | Rows | Lines | What draws it |
|---|---:|---:|---|
| Sky | 40 | 80 | one `ENABL` value per row: the sun |
| Horizon line | — | 1 | `COLUBK` gold, full width, playfield clear |
| Verge | — | 1 | `COLUBK` green, full width |
| Road | 22 | 110 | the six playfield stores, five times per row |
| **Total** | | **192** | |

### The demo: straight, curved, and the dash that rushes

`PhaseTimer` counts frames and flips `CurveMask` between `$00` and `$FF` every 180 frames. The cycle is 360 frames — six seconds — with three seconds straight and three seconds curved. `Scroll` advances once every eight frames and `Dash` once every two, and both count **down** against the row index (`row − phase`), so as they rise the feature they index moves toward the viewer: a bend or a dash enters at row 0 and slides down the screen. `SELECT` toggles the phase and restarts its timer.

The dashed centre line is a **gap in the playfield**: on a dash row one chunk of the road is cleared and the green background shows through. No extra objects, no missile, no ball — the road simply has a hole in it.

The gap follows the road, not the screen. The road's centre chunk is `g = 20 + c`, which is chunk 14 at one end of the curve and chunk 26 at the other. `g` is 14-19 inside the left half (so the byte to mask is `PF2`, bit `g−12`) and 20-23 in right `PF0` (bit `g−16`); the vertical blank builds one masked byte per register per row, with the dash state ORed in, so the kernel does no masking at all. Two limits are worth stating. Right `PF1` (chunks 24-31) is written in the same group as `PF0` and there is no room for a third masked byte there, so `g` saturates at 23 — on the strongest right-hand curves the line stops three chunks short of the centre, and everywhere else it is exact. And the dash is **suppressed on the narrow rows** (`HalfTable` below 4, rows 0-7): a four-pixel gap is a third of the twelve-pixel road at row 0, which reads as a pothole, while from row 8 the road is at least 36 pixels wide and the same gap reads as a centre mark.

The pattern is **two rows on, two rows off** — ten scanlines of dash, ten of gap. With 22 rows and a four-row period, and the first eight rows (0-7) suppressed, a single frame shows three or four dashes; the straight capture shows three and the curved one two, because the dash phase differs between them.

::: tip Where the effect comes from

The pseudo-3D road is documented as a per-scanline technique in the same community material that documents skipdraw and the HMOVE walk — 8bitworkshop's VCS section and the AtariAge kernel threads — and *Racing the Beam* describes the same "the picture is a schedule, not a scene" idea for the console as a whole. This lesson reconstructs the mechanism from those descriptions and verifies it in Stella: the road edges, the curve shift and the write cycles in this document are all measured from this ROM, not quoted. The road, the palette and the sun are original art; no claim is made that any particular cartridge used this exact code.

:::

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson75.bin \
  lessons/part11-legendary/75-pseudo-3d-road/75-pseudo-3d-road.asm
stella build/lesson75.bin
```

The two exercise solutions sit beside the lesson source and are complete 4,096-byte ROMs:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part11-legendary/75-pseudo-3d-road/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part11-legendary/75-pseudo-3d-road/exercise-02-solution.asm
```

### Full Source

The complete annotated source, reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 75: Pseudo-3D Road — The Enduro / Pole Position Effect
; =============================================================================
; Part 11: Legendary Techniques
;
; What this program does:
;   "the road": a road widening to a horizon.  The picture is 192 scanlines
;   in three bands:
;
;     visible   0-79    the sky        40 rows x 2 lines   blue + a gold sun
;     visible  80       the horizon    one gold line, full width
;     visible  81       the verge      one green line below it
;     visible  82-191   the road       22 rows x 5 lines   grey road, green grass
;                       -------------------
;                       80 + 1 + 1 + 110 = 192
;
;   The road is the PLAYFIELD.  Its left edge and its right edge are looked
;   up in two 20-entry mask tables, one for the left half of the screen and
;   one for the right half.  The playfield registers are written TWICE on
;   every road scanline: first with THIS line's left-half bytes, while the
;   beam is still in horizontal blank, then with THIS line's right-half
;   bytes, after the left half has been drawn and before the beam reaches
;   the right half.  That is the Lesson 21 asymmetric-playfield technique,
;   and it is what lets the road sit off-centre when it curves.
;
;   The write does NOT survive to the next scanline.  The TIA reads the
;   playfield registers again on every line, so the left and right pair has
;   to be re-established 76 cycles at a time.  That single fact sets the
;   budget and the instruction order.
;
;   Per road row:
;     Half[r]   the road's half-width in playfield chunks (1..10)
;     Curve     a signed per-row offset from a 32-entry table (-6..+6),
;               masked to 0 in the straight demo phase
;     c         Curve clamped to +/- (Half - 1) so the road always crosses
;               the chunk 19/20 boundary (the two mask tables need it)
;     L         the left edge chunk  = 20 - Half + c     (1..19)
;     Ridx      the right edge index =      Half + c     (1..19)
;               the right edge chunk is Ridx + 20        (21..39)
;     g         the road's centre chunk = (L + Ridx + 20) / 2 = 20 + c
;
;   The road therefore spans chunks L..(Ridx+20), which is 4L..4(Ridx+20)+3
;   in pixels.  The chunk at g is blanked on the "dash" rows to make the
;   dashed centre line; the green background shows through.  Because g
;   follows c, the line follows the road: 20 + c is chunk 14 at one end of
;   the curve and chunk 26 at the other.
;
;   Each playfield chunk is 4 pixels.  The road is 3 chunks wide at the
;   horizon and 21 at the bottom of the screen.
;
; WHERE THE PLAYFIELD IS LATCHED, AND WHY THAT SETS THE INSTRUCTION ORDER
;   The TIA does not latch the whole playfield at one instant.  Each
;   register is read as the beam arrives at its chunks, so a write only
;   affects the chunks the beam has not reached yet.  The visible area
;   starts 68 color clocks -- 22.67 CPU cycles -- after the WSYNC release,
;   so pixel x is drawn at cycle 22.67 + x/3:
;
;     left  PF0  pixels   0- 15   cycles 22.67 - 27.67
;     left  PF1  pixels  16- 47   cycles 28.00 - 38.33
;     left  PF2  pixels  48- 79   cycles 38.67 - 49.00
;     right PF0  pixels  80- 95   cycles 49.33 - 54.33
;     right PF1  pixels  96-127   cycles 54.67 - 65.00
;     right PF2  pixels 128-159   cycles 65.33 - 75.67
;
;   To change the RIGHT half of a line, a register must be rewritten after
;   its LEFT chunks have been drawn and before its RIGHT chunks arrive:
;
;     right PF0   after 27.67 and before 49.33   -> write at 36
;     right PF1   after 38.33 and before 54.67   -> write at 43
;     right PF2   after 49.00 and before 65.33   -> write at 54
;
;   and the LEFT half of the same line must be in the registers before the
;   visible area starts drawing it:
;
;     left PF0    before 22.67                   -> write at 11
;     left PF1    before 28.00                   -> write at 18
;     left PF2    before 38.67                   -> write at 25
;
;   Both groups therefore live on the same scanline, left group first:
;
;     0  LDY LTable,X      4      25  LDY RidxTable,X   4
;     4  LDA LeftPF0,Y     4      29  LDA SzR0,X        4
;     8  STA PF0           3  11  33  STA PF0           3  36
;    11  LDA LeftPF1,Y     4      36  LDA RightPF1,Y     4
;    15  STA PF1           3  18  40  STA PF1           3  43
;    18  LDA SzL2,X        4      43  LDA RightPF2,Y     4
;    22  STA PF2           3  25  47  NOP               2
;                                49  NOP               2
;                                51  STA PF2           3  54
;                                 54 cycles
;
;   SzL2 and SzR0 are the two playfield bytes the centre-line gap can fall
;   in, already masked, built in the vertical blank.  The left PF0 and PF1
;   bytes and the right PF1 and PF2 bytes never take the gap, so they are
;   plain table lookups.
;
;   THE 22.67-CYCLE OFFSET IS EASY TO LOSE.  Dividing a pixel number by
;   three gives the cycle measured from the start of the VISIBLE area, not
;   from the WSYNC release; a schedule built on those numbers writes
;   everything one horizontal blank too early and the halves come out
;   swapped.  The offset was measured, not assumed.  A probe ROM writes
;   PF1 = $FF at cycle 5 and PF1 = $00 at cycle 32 and shows white on the
;   left half only from x 16 to x 31.  The changeover is between the last
;   chunk drawn before the write and the first chunk drawn after it, which
;   is the statement the schedule needs; the arithmetic that predicts it
;   is only good to a cycle or two because the write lands in the middle of
;   a four-pixel chunk.
;
; THE KERNEL BUDGET
;   A drawing line is 54 cycles plus the WSYNC, so 19 cycles are spare.
;   Everything else per row is precomputed: the vertical blank rebuilds
;   LTable and RidxTable (about 81-85 cycles a row, 1870 for 22 rows) when
;   the scroll or the curve changes, and SzL2/SzR0 (113 cycles a row, 2486
;   for 22 rows) when the curve changes or the dash steps.  The two passes
;   never run on the same frame: the mask pass waits for a frame where the
;   edges were not rebuilt, so it can lag by up to two frames, and a frame
;   carries at most 2486 cycles of work plus the demo's ~180, well inside the
;   2812-cycle blank.
;
;   Why a road row is five scanlines: it is a deliberate choice, not a
;   hardware limit.  A row could be two lines (the kernel is 54 of 76
;   cycles on every line), but 22 rows x 5 = 110 lines is what makes the
;   band split land on exactly 192 with an 80-line sky, and five lines per
;   width step keeps the road's edge from stepping too fast.  That is the
;   one accepted deviation from a two-line row, and the price is paid in
;   vertical resolution, not in the kernel.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262.
;   Measured schedule (Stella breakpoints): the sky bodies run on absolute
;   lines 37-116, the horizon line on 117, the verge on 118, the road rows
;   on 119-228 (22 rows x 5), the overscan on 229-258 and the VSYNC on
;   259-261.
;
;   Measurement convention: a checkpoint's line/cycle is the instruction's
;   start line and start cycle, with the line's cycle 0 being the first
;   instruction after the WSYNC release.  A breakpoint on the first
;   instruction after a STA WSYNC fires during the stall and reports the
;   WSYNC's own line/cycle; the instruction itself starts on the next line
;   at cycle 0.
;
; The demo (no controller needed):
;   PhaseTimer counts frames and toggles the curve between straight
;   (CurveMask = $00) and curved (CurveMask = $FF) every 180 frames, so the
;   cycle is 360 frames (6 s).  Scroll advances once every 8 frames and Dash
;   once every 2.  Both count DOWN against the row index, so as they rise
;   the pattern they index moves toward the viewer: a dash or a bend
;   appears at row (index + phase) and slides down the screen.
;
;   The dashed line is suppressed on the narrow rows (Half < 4, rows 0-7).
;   A four-pixel gap is a third of the twelve-pixel road at row 0, which
;   reads as a pothole; from row 8 down the road is at least 36 pixels wide
;   and the same gap reads as a centre mark.  With a four-row dash period
;   and only 22 rows, a single frame shows three or four dashes (three in
;   the captured images).
;
; Checkpoints (the values are the state at the label; addresses are in the
; symbol file, which is the authority):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   SkyEnd (116/9, the WSYNC that ends the sky), RoadBody (119, the first
;   road row's first line), OverscanStart (228/64; the first blanked line
;   is 229), EdgeDone (the edge rebuild's last instruction), MaskDone (the
;   mask rebuild's last instruction), BuildOne (A = a row's clamped curve).
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80 PhaseTimer   frames elapsed in the current demo phase
;   $81 CurveMask    $00 straight, $FF curved
;   $82 Scroll       the curve table's phase (0..31)
;   $83 ScrollTimer  frames to the next Scroll step
;   $84 Dash         the centre-line phase (0..7)
;   $85 DashTimer    frames to the next Dash step
;   $86 PrevSelect   the SELECT edge latch
;   $87 MaxOff       the curve clamp, and the rebuild's scratch byte
;   $88 GapIx        the mask rebuild's table index for the current row
;   $89 MaskDirty    1 = rebuild SzL2/SzR0 in this vertical blank
;   $8A CurveDirty   1 = rebuild LTable and RidxTable in this vertical blank
;   $8B-$A0 LTable   the road's left edge chunk for each row (22 bytes)
;   $A1-$B6 RidxTable the road's right edge index for each row (22 bytes)
;   $B7-$CC SzL2     the left PF2 byte per row, centre gap applied (22)
;   $CD-$E2 SzR0     the right PF0 byte per row, centre gap applied (22)
;   $E3-$F7          free (21 bytes)
;   $F8-$FF          the stack
;
; Build: acme -f plain -o build/lesson75.bin \
;        lessons/part11-legendary/75-pseudo-3d-road/75-pseudo-3d-road.asm
; Run:   stella build/lesson75.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK (Lesson 15)
OVERSCAN_TIMER = 36      ; 30-line overscan (Lesson 15)

VISIBLE_LINES  = 192

SKY_ROWS       = 40      ; visible rows 0-39, two scanlines each
HORIZON_LINES  = 2       ; one gold horizon line and one green verge line
ROAD_ROWS      = 22      ; the road's rows, five scanlines each
ROAD_LINES     = 110     ; 22 x 5

BALL_X         = 116     ; the sun's left edge (TIA x)
POS_BIAS       = 3       ; the Lesson 26 output-delay bias

PHASE_LEN      = 180     ; frames per demo phase (3 s at 60 Hz)
SCROLL_STEP    = 8       ; frames per curve-table step
DASH_STEP      = 2       ; frames per dash-row step
DASH_MIN_HALF  = 4       ; no centre line until the road is 9 chunks wide

; --- colours -----------------------------------------------------------------
C_SKY          = $9A     ; daylight blue
C_GOLD         = $1A     ; the sun and the horizon band
C_GRASS        = $C6     ; the grass verges
C_ROAD         = $0A     ; the road surface: grey

; The band arithmetic is a build-time assertion, not a comment.
!if SKY_ROWS * 2 + HORIZON_LINES + ROAD_ROWS * 5 != VISIBLE_LINES {
    !error "the sky, horizon and road bands must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$F7; +clean_start zeroes every byte)
; =============================================================================
PhaseTimer   = $80   ; frames elapsed in the current demo phase
CurveMask    = $81   ; $00 = straight, $FF = curved
Scroll       = $82   ; the curve table's phase, 0..31
ScrollTimer  = $83   ; frames to the next Scroll step
Dash         = $84   ; the centre-line phase, 0..7
DashTimer    = $85   ; frames to the next Dash step
PrevSelect   = $86   ; the SELECT edge latch
MaxOff       = $87   ; the curve clamp, and the rebuild's scratch byte
GapIx        = $88   ; the mask rebuild's table index for the current row
MaskDirty    = $89   ; 1 = rebuild SzL2 and SzR0
CurveDirty   = $8A   ; 1 = rebuild LTable and RidxTable
LTable       = $8B   ; 22 bytes: $8B-$A0, the left edge chunk per row
RidxTable    = $A1   ; 22 bytes: $A1-$B6, the right edge index per row
SzL2         = $B7   ; 22 bytes: $B7-$CC, left PF2, gap applied
SzR0         = $CD   ; 22 bytes: $CD-$E2, right PF0, gap applied
;
; The stack lives at $F8-$FF; the call depth stays at one level (the ball
; positioner at reset only).  Used: 99 bytes of variables and tables
; ($80-$E2); 21 bytes ($E3-$F7) are free.

; =============================================================================
; DRAWROADROW — one road scanline, 54 cycles
; =============================================================================
; The left group is in the registers before the visible area starts; the
; right group lands after the left half's chunks for each register have
; gone by and before the right half's arrive.  SzL2 and SzR0 already have
; the centre-line gap applied; the two registers that never carry the gap
; (left PF0/PF1's first chunks, and all of right PF1/PF2) are plain table
; lookups.  54 cycles.
!macro DrawRoadRow {
    LDY LTable,X            ; 4   0- 4  the left edge chunk for this row
    LDA LeftPF0,Y           ; 4   4- 8  chunks L..3   (never takes the gap)
    STA PF0                 ; 3   8-11  write 11  (before 22.67)
    LDA LeftPF1,Y           ; 4  11-15  chunks 4..11  (never takes the gap)
    STA PF1                 ; 3  15-18  write 18  (before 28.00)
    LDA SzL2,X              ; 4  18-22  chunks 12..19, gap applied
    STA PF2                 ; 3  22-25  write 25  (before 38.67)
    LDY RidxTable,X         ; 4  25-29  the right edge index for this row
    LDA SzR0,X              ; 4  29-33  chunks 20..23, gap applied
    STA PF0                 ; 3  33-36  write 36  (after 27.67, before 49.33)
    LDA RightPF1,Y          ; 4  36-40  chunks 24..31 (gap saturates in PF0)
    STA PF1                 ; 3  40-43  write 43  (after 38.33, before 54.67)
    LDA RightPF2,Y          ; 4  43-47  chunks 32..39 (never takes the gap)
    NOP                     ; 2  47-49
    NOP                     ; 2  49-51
    STA PF2                 ; 3  51-54  write 54  (after 49.00, before 65.33)
}

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
    STA ENABL
    STA PF0
    STA PF1
    STA PF2

    LDA #$30
    STA CTRLPF              ; an 8-pixel ball; REPEAT playfield; no priority
                            ; bit 0 = 0 is essential: repeat mode puts the
                            ; right half in the same PF0/PF1/PF2 order as the
                            ; left half, which is what the mask tables assume

; --- the sun: the ball, positioned once ---------------------------------------
    LDA #(BALL_X + POS_BIAS)
    JSR SetHorizPosBL
    STA HMOVE               ; apply HMBL inside HBLANK

; --- the first frame's state -------------------------------------------------
    LDA #$00
    STA PhaseTimer
    STA Scroll
    STA ScrollTimer
    STA Dash
    STA DashTimer
    STA PrevSelect
    STA CurveMask           ; start in the straight phase
    LDA #$01
    STA CurveDirty          ; build the edge tables on frame 0
    STA MaskDirty           ; and the masked bytes on frame 1

; --- seed the four tables for the first frame --------------------------------
; The first visible frame is drawn before either rebuild has run, so the
; tables are seeded from HalfTable with c = 0 — the straight phase's row
; shape.  Both edges and both masked bytes are seeded, so the first frame is
; consistent; seeding only the edges would leave the row-0 masks on a
; widening road and punch holes in its left half.  The seed also works for a
; different HalfTable, which is why exercise 1 needs no change here.
    LDX #$00
SeedRow:
    LDA BaseLTable,X        ; L = 20 - Half
    STA LTable,X
    TAY
    LDA LeftPF2,Y           ; the left PF2 byte for that edge, no gap yet
    STA SzL2,X
    LDA HalfTable,X         ; Ridx = Half
    STA RidxTable,X
    TAY
    LDA RightPF0,Y          ; the right PF0 byte for that edge
    STA SzR0,X
    INX
    CPX #ROAD_ROWS
    BNE SeedRow

    LDA #C_SKY
    STA COLUBK
    LDA #C_GOLD
    STA COLUPF

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; 1. SELECT — advance to the next phase and rebuild everything
; -----------------------------------------------------------------------------
    LDA SWCHB
    AND #$02
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$00
    STA PhaseTimer
    LDA CurveMask
    EOR #$FF
    STA CurveMask
    LDA #$01
    STA CurveDirty          ; a phase change always rebuilds, both ways
    STA MaskDirty
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; -----------------------------------------------------------------------------
; 2. THE PHASE TIMER — straight for 180 frames, curved for 180 frames
; -----------------------------------------------------------------------------
    INC PhaseTimer
    LDA PhaseTimer
    CMP #PHASE_LEN
    BCC PhaseDone
    LDA #$00
    STA PhaseTimer
    LDA CurveMask
    EOR #$FF
    STA CurveMask
    LDA #$01
    STA CurveDirty          ; $01, not the mask: straight is a real rebuild
    STA MaskDirty
PhaseDone:

; -----------------------------------------------------------------------------
; 3. THE SCROLL — one curve-table step every 8 frames, toward the viewer
; -----------------------------------------------------------------------------
    INC ScrollTimer
    LDA ScrollTimer
    CMP #SCROLL_STEP
    BCC ScrollDone
    LDA #$00
    STA ScrollTimer
    INC Scroll
    LDA Scroll
    AND #31
    STA Scroll
    LDA #$01
    STA CurveDirty
ScrollDone:

; -----------------------------------------------------------------------------
; 4. THE DASH — one row of centre-line dashes every 2 frames, toward the viewer
; -----------------------------------------------------------------------------
    INC DashTimer
    LDA DashTimer
    CMP #DASH_STEP
    BCC DashDone
    LDA #$00
    STA DashTimer
    INC Dash
    LDA Dash
    AND #7
    STA Dash
    LDA #$01
    STA MaskDirty
DashDone:

; -----------------------------------------------------------------------------
; 5. THE SKY COLOURS AND A CLEAN PLAYFIELD
; -----------------------------------------------------------------------------
; The previous frame ended with road bytes in the registers.  Clearing them
; here keeps the sky free of road fragments, and re-setting the two colours
; undoes the road's colour change.
    LDA #C_SKY
    STA COLUBK
    LDA #C_GOLD
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF1
    STA PF2

; -----------------------------------------------------------------------------
; 6. REBUILD THE EDGE TABLES, IF THE CURVE CHANGED
; -----------------------------------------------------------------------------
; 22 rows of width, curve, clamp and two edge lookups: 81-85 cycles each,
; about 1870 cycles for the whole table.  Both tables are rebuilt inside one
; vertical blank, so the picture never shows a row from one curve next to a
; row from another.  The index is (row - Scroll), so a bend enters at row 0
; and moves DOWN the screen as Scroll rises.
    LDA CurveDirty
    BEQ EdgesBuilt
    LDA #$00
    STA CurveDirty
    STA MaskDirty           ; defer the mask pass by one frame: the two
                            ; passes together would not fit the blank
    LDX #$00
BuildRow:
    LDA HalfTable,X         ; 4  the road's half-width for this row
    STA MaxOff              ; 3
    SEC                     ; 2
    SBC #1                  ; 2  MaxOff = Half - 1
    STA MaxOff              ; 3
    TXA                     ; 2
    SEC                     ; 2
    SBC Scroll              ; 3  row - Scroll: features move down
    AND #31                 ; 2  wrap the 32-entry table
    TAY                     ; 2
    LDA CurveTable,Y        ; 4  the signed curve byte, -6..+6
    AND CurveMask           ; 3  $00 masks it to zero in the straight phase
    CMP #$80                ; 2  carry set when the byte is negative
    BCS .neg                ; 3 taken when negative
    CMP MaxOff              ; 3
    BCC .done               ; 3 taken when 0 <= c <= MaxOff
    LDA MaxOff              ; 3  clamp a large positive curve
    JMP .done               ; 3
.neg:
    EOR #$FF                ; 2  two's complement: A = -c
    CLC                     ; 2
    ADC #1                  ; 2
    CMP MaxOff              ; 3
    BCC .negok              ; 3 taken when |c| <= MaxOff
    LDA MaxOff              ; 3  clamp a large negative curve
.negok:
    EOR #$FF                ; 2  two's complement back to a negative value
    CLC                     ; 2
    ADC #1                  ; 2
.done:
BuildOne:                   ; checkpoint: A = this row's clamped curve
    STA MaxOff              ; 3  c, kept for the second lookup
    CLC                     ; 2
    ADC HalfTable,X         ; 4  Ridx = c + Half
    STA RidxTable,X         ; 4
    LDA BaseLTable,X        ; 4  20 - Half
    CLC                     ; 2
    ADC MaxOff              ; 3  L = 20 - Half + c
    STA LTable,X            ; 4
    INX                     ; 2
    CPX #ROAD_ROWS          ; 2
    BNE BuildRow            ; 3 taken
EdgesBuilt:
EdgeDone:                   ; checkpoint: the edge rebuild has finished

; -----------------------------------------------------------------------------
; 7. REBUILD THE THREE MASKED BYTES, IF THE CURVE OR THE DASH MOVED
; -----------------------------------------------------------------------------
; 22 rows of: the road centre g = (L + Ridx + 20)/2, one 13-entry lookup per
; register, and the dash bit folded into the table index.  113 cycles a row,
; 2486 for the whole table.
; The gap follows the road: g is chunk 14 at one end of the curve and chunk
; 26 at the other, so the line stays on the road's centre instead of on the
; screen's.
    LDA MaskDirty
    BEQ MasksBuilt
    LDA #$00
    STA MaskDirty
    LDX #$00
MaskRow:
    TXA                     ; 2
    SEC                     ; 2
    SBC Dash                ; 3  row - Dash: dashes move down
    AND #3                  ; 2  the four-row dash period
    LSR                     ; 2  0 on a dash row, 1 on a plain row
    STA MaxOff              ; 3  the dash bit
    LDA HalfTable,X         ; 4  a four-pixel gap is a third of the road at
    CMP #DASH_MIN_HALF      ; 2  the horizon, so the narrow rows get none
    BCS .wide               ; 3
    LDA #$01                ; 2
    STA MaxOff              ; 3  force the plain entry
.wide:
    LDA LTable,X            ; 4
    CLC                     ; 2
    ADC RidxTable,X         ; 4
    CLC                     ; 2
    ADC #20                 ; 2  L + Ridx + 20 = 40 + 2c
    LSR                     ; 2  /2 = 20 + c, the road's centre chunk
    SEC                     ; 2
    SBC #14                 ; 2  the gap table starts at chunk 14
    ASL                     ; 2  two entries per chunk: gap on, gap off
    ORA MaxOff              ; 3
    STA GapIx               ; 3
    LDY LTable,X            ; 4  Y = L
    LDA LeftPF2,Y           ; 4  chunks 12..19
    STA MaxOff              ; 3
    LDY GapIx               ; 3
    LDA GapL2Tab,Y          ; 4
    AND MaxOff              ; 3
    STA SzL2,X              ; 4
    LDY RidxTable,X         ; 4  Y = Ridx
    LDA RightPF0,Y          ; 4  chunks 20..23
    STA MaxOff              ; 3
    LDY GapIx               ; 3
    LDA GapR0Tab,Y          ; 4
    AND MaxOff              ; 3
    STA SzR0,X              ; 4
    INX                     ; 2
    CPX #ROAD_ROWS          ; 2
    BNE MaskRow             ; 3 taken
MasksBuilt:
MaskDone:                   ; checkpoint: the mask rebuild has finished

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:                  ; checkpoint: scanline 37/5, visible line 0

; =============================================================================
; VISIBLE LINES 0-79: THE SKY (40 rows x 2 lines)
; =============================================================================
; One job per row: enable or disable the sun.  The loop is rotated so its
; first body runs on visible line 0 instead of eating a WSYNC line.
    LDX #$00
    JMP SkyBody
SkyLoop:
    STA WSYNC               ; line 2X
SkyBody:
    LDA SunTable,X          ; 4  $02 on the sun's eight rows, $00 elsewhere
    STA ENABL               ; 3  the ball is the sun
    STA WSYNC               ; line 2X+1
    INX                     ; 2
    CPX #SKY_ROWS           ; 2
    BNE SkyLoop             ; 3 taken

; =============================================================================
; VISIBLE LINES 80-81: THE HORIZON LINE AND THE VERGE
; =============================================================================
; Both are the BACKGROUND, not the playfield: COLUBK is gold for one line and
; green for the next, and the playfield stays clear, so neither line needs a
; mask.  Doing it this way also lets COLUPF change to the road's grey here,
; hidden behind the band.
    STA WSYNC               ; end the sky's last line (visible 79)
SkyEnd:                     ; checkpoint: the WSYNC that ends the sky
    LDA #C_GOLD
    STA COLUBK              ; visible line 80: the gold horizon line
    LDA #C_ROAD
    STA COLUPF              ; the road's colour, hidden behind it
    STA WSYNC               ; end visible 80
    LDA #C_GRASS
    STA COLUBK              ; visible line 81: the verge
    LDX #$00                ; row 0; the road loop draws line 82
    STA WSYNC               ; end visible 81

; =============================================================================
; VISIBLE LINES 82-191: THE ROAD (22 rows x 5 lines)
; =============================================================================
; Each road row is five identical lines: 54 cycles of stores plus WSYNC.
; The row's edges are constant across its five lines, so the first line of a
; row draws exactly what the fifth does.
;
; The very first road line is entered with a JMP and so starts three cycles
; late, which moves its stores to 14/21/28/39/46/57.  Every one of those is
; still inside its window, and row 0's right half is a single PF0 chunk, so
; even a late PF1 write there would cost nothing.
    JMP RoadBody            ; X is already 0
RoadLoop:
    STA WSYNC               ; line 1 of row X
RoadBody:
    +DrawRoadRow            ; 54
    STA WSYNC               ; line 2 of row X
    +DrawRoadRow
    STA WSYNC               ; line 3 of row X
    +DrawRoadRow
    STA WSYNC               ; line 4 of row X
    +DrawRoadRow
    STA WSYNC               ; line 5 of row X
    +DrawRoadRow
    INX                     ; 2
    CPX #ROAD_ROWS          ; 2
    BEQ RoadDone            ; 2/3
    JMP RoadLoop            ; 3  (the loop body is longer than a branch can reach)
RoadDone:
    STA WSYNC               ; finish visible line 191

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229, the first blanked line
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SETHORIZPOSBL — the Lesson 26 divide-by-15 dance, for the ball
; =============================================================================
; A = the desired left edge + the output-delay bias.  Subtracting 15 costs
; 5 cycles = 15 color clocks per iteration; the remainder becomes the signed
; fine motion in HMBL and the coarse store lands on the beam.
    !align 31, 0
SetHorizPosBL:
    STA WSYNC
    SEC
DivBL:
    SBC #15
    BCS DivBL
    EOR #7                  ; the negative remainder -> the signed fine value
    ASL                     ; bits 0-3 -> HMBL's high nibble
    ASL
    ASL
    ASL
    STA HMBL
    STA RESBL               ; the coarse strobe
    STA WSYNC
    RTS

; =============================================================================
; THE ROAD'S HALF-WIDTH — one byte per road row, in playfield chunks
; =============================================================================
; Row 0 is the horizon row: a 3-chunk road (12 pixels).  The half-width grows
; to 10 chunks at row 21, so the road is 21 chunks (84 pixels) at the bottom.
; The growth follows a mild perspective curve: slow near the horizon, faster
; near the viewer.
    !align 255, 0
HalfTable:
    !byte  1,  1,  1,  2,  2,  2,  3,  3,  4,  4   ; rows  0- 9
    !byte  5,  5,  5,  6,  6,  7,  7,  8,  8,  9   ; rows 10-19
    !byte  9, 10                                   ; rows 20-21

; The left edge with no curve: 20 - Half.
    !align 255, 0
BaseLTable:
    !byte 19, 19, 19, 18, 18, 18, 17, 17, 16, 16   ; rows  0- 9
    !byte 15, 15, 15, 14, 14, 13, 13, 12, 12, 11   ; rows 10-19
    !byte 11, 10                                   ; rows 20-21

; =============================================================================
; THE CURVE — 32 signed bytes, one full wave, -6..+6
; =============================================================================
; Row r reads entry (r - Scroll) & 31, so the pattern crawls DOWN the road as
; Scroll advances — toward the viewer, not away.  The clamp is what turns
; this constant amplitude into a perspective curve: the narrow rows near the
; horizon cannot take the full +/-6, so they flatten out by themselves.
    !align 255, 0
CurveTable:
    !byte   0,   1,   2,   3,   4,   5,   6,   6   ; entries  0- 7
    !byte   6,   6,   6,   5,   4,   3,   2,   1   ; entries  8-15
    !byte   0,  -1,  -2,  -3,  -4,  -5,  -6,  -6   ; entries 16-23
    !byte  -6,  -6,  -6,  -5,  -4,  -3,  -2,  -1   ; entries 24-31

; =============================================================================
; THE CENTRE-LINE GAP — 13 chunks x 2 dash states, one table per register
; =============================================================================
; Indexed by ((g - 14) * 2 + dashBit), where g is the road's centre chunk and
; dashBit is 0 on a dash row and 1 on a plain one.  Each entry ANDs with the
; register: everything on except the one bit for chunk g.  g is 14-19 in the
; left half (PF2, bit g-12) and 20-23 in right PF0 (bit g-16).  The register
; that does not hold g keeps $FF, and so does every plain row.
;
; The road's centre can reach chunk 26 on the strongest right-hand curves, and
; right PF1 (chunks 24-31) is written in the same group as PF0, where there is
; no room for a third masked byte.  The table therefore saturates: g = 24, 25
; and 26 all clear chunk 23, so on the extreme right the line stops three
; chunks short of the centre.  Everywhere else it is the true centre.
    !align 255, 0
GapL2Tab:
    !byte $FB, $FF                                  ; g = 14  (dash on, off)
    !byte $F7, $FF                                  ; g = 15
    !byte $EF, $FF                                  ; g = 16
    !byte $DF, $FF                                  ; g = 17
    !byte $BF, $FF                                  ; g = 18
    !byte $7F, $FF                                  ; g = 19
    !byte $FF, $FF, $FF, $FF, $FF, $FF              ; g = 20-22: gap is in PF0
    !byte $FF, $FF, $FF, $FF, $FF, $FF              ; g = 23-25
    !byte $FF, $FF                                  ; g = 26
    !align 255, 0
GapR0Tab:
    !byte $FF, $FF, $FF, $FF, $FF, $FF              ; g = 14-16
    !byte $FF, $FF, $FF, $FF, $FF, $FF              ; g = 17-19: gap is in PF2
    !byte $EF, $FF                                  ; g = 20
    !byte $DF, $FF                                  ; g = 21
    !byte $BF, $FF                                  ; g = 22
    !byte $7F, $FF                                  ; g = 23
    !byte $7F, $FF                                  ; g = 24: saturates at 23
    !byte $7F, $FF                                  ; g = 25: saturates at 23
    !byte $7F, $FF                                  ; g = 26: saturates at 23

; =============================================================================
; THE SUN — one ENABL value per sky row
; =============================================================================
SunTable:
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows  0- 7
    !byte $00, $00, $00, $00, $02, $02, $02, $02   ; rows  8-15
    !byte $02, $02, $02, $02, $00, $00, $00, $00   ; rows 16-23 (12-19 sun)
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 24-31
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 32-39

; =============================================================================
; THE LEFT-HALF MASK TABLES — 20 entries each, indexed by the left edge L
; =============================================================================
; LeftPF0[L] = chunks L..3 on  (PF0 bits 4-7; bit 4 is chunk 0)
; LeftPF1[L] = chunks L..3 and 4..11 on (see the table)
; LeftPF2[L] = chunks L..19 on (PF2 bits 0-7; bit 0 is chunk 12)
; The road always starts at chunk L and runs to the centre of the screen.
    !align 255, 0
LeftPF0:
    !byte $F0, $E0, $C0, $80, $00, $00, $00, $00   ; L =  0- 7
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; L =  8-15
    !byte $00, $00, $00, $00                       ; L = 16-19

    !align 255, 0
LeftPF1:
    !byte $FF, $FF, $FF, $FF, $FF, $7F, $3F, $1F   ; L =  0- 7
    !byte $0F, $07, $03, $01, $00, $00, $00, $00   ; L =  8-15
    !byte $00, $00, $00, $00                       ; L = 16-19

    !align 255, 0
LeftPF2:
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF   ; L =  0- 7
    !byte $FF, $FF, $FF, $FF, $FF, $FE, $FC, $F8   ; L =  8-15
    !byte $F0, $E0, $C0, $80                       ; L = 16-19

; =============================================================================
; THE RIGHT-HALF MASK TABLES — 20 entries each, indexed by Ridx = R - 20
; =============================================================================
; RightPF0[R] = chunks 20..20+R on (bit 4 is chunk 20)
; RightPF1[R] = chunks 24..20+R on
; RightPF2[R] = chunks 32..20+R on
; The right half runs from the centre of the screen to the road's right edge.
    !align 255, 0
RightPF0:
    !byte $10, $30, $70, $F0, $F0, $F0, $F0, $F0   ; R =  0- 7
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0   ; R =  8-15
    !byte $F0, $F0, $F0, $F0                       ; R = 16-19

    !align 255, 0
RightPF1:
    !byte $00, $00, $00, $00, $80, $C0, $E0, $F0   ; R =  0- 7
    !byte $F8, $FC, $FE, $FF, $FF, $FF, $FF, $FF   ; R =  8-15
    !byte $FF, $FF, $FF, $FF                       ; R = 16-19

    !align 255, 0
RightPF2:
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; R =  0- 7
    !byte $00, $00, $00, $00, $01, $03, $07, $0F   ; R =  8-15
    !byte $1F, $3F, $7F, $FF                       ; R = 16-19

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
> `lessons/part11-legendary/75-pseudo-3d-road/75-pseudo-3d-road.asm`.

### Code Walkthrough

#### Step 1 — The frame and the three bands

The frame is the course's NTSC skeleton. What is new is the band split:

```asm
StartFrame:
    +vsync
VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    ; ... SELECT, the phase timer, the scroll, the dash, the colour reset ...
    ; ... rebuild the edge tables if the curve changed ...
    +wait_timer
    LDA #$00
    STA VBLANK
BodyStart:
    LDX #$00
    JMP SkyBody
```

80 sky lines, 2 horizon lines, 110 road lines: 192 visible, and 3 + 37 + 192 + 30 = 262 for the frame. The sky loop is rotated — its first body runs on visible line 0 rather than eating a `WSYNC` line — and the road loop is rotated the same way, which matters more here: line 82 is the road's first line and it must start drawing at cycle 3, not cycle 13, or its right-half stores miss their windows. That bug is in the ROM's history and in the comment at the `JMP`.

#### Step 2 — The vertical blank rebuilds the edge tables

This is where the road is "computed". Once per change of the curve, 22 times:

```asm
    LDA HalfTable,X         ; the half-width for this row
    STA MaxOff
    SEC
    SBC #1                  ; MaxOff = Half - 1
    STA MaxOff
    TXA
    SEC
    SBC Scroll              ; row - Scroll: a bend moves DOWN the screen
    AND #31                 ; wrap the 32-entry table
    TAY
    LDA CurveTable,Y        ; the signed curve byte
    AND CurveMask           ; $00 in the straight phase
    CMP #$80                ; carry set when the byte is negative
    BCS .neg
    CMP MaxOff
    BCC .done
    LDA MaxOff              ; clamp a large positive curve
    JMP .done
.neg:
    EOR #$FF                ; two's complement: A = -c
    CLC
    ADC #1
    CMP MaxOff
    BCC .negok
    LDA MaxOff              ; clamp a large negative curve
.negok:
    EOR #$FF
    CLC
    ADC #1
.done:
    STA MaxOff              ; c, kept for the second lookup
    CLC
    ADC HalfTable,X         ; Ridx = c + Half
    STA RidxTable,X
    LDA BaseLTable,X        ; 20 - Half
    CLC
    ADC MaxOff              ; L = 20 - Half + c
    STA LTable,X
    INX
    CPX #ROAD_ROWS
    BNE BuildRow
```

The clamp is the only branchy part, and it is the only place in the program where
the curve's sign matters. `MaxOff` is the clamp bound at the start of the row
and the scratch copy of `c` at the end; there is no separate `cSave` — RAM is
used to the last byte. Everything downstream — the kernel and the mask pass —
treats `L` and `Ridx` as plain small numbers.

The pass costs 81 to 85 cycles a row, about 1870 for the table, and finishes on
scanline 23 to 26 of the 37-line blank.

#### Step 3 — One drawing line, six stores, two halves

```asm
!macro DrawRoadRow {
    LDY LTable,X            ; the left edge chunk for this row
    LDA LeftPF0,Y           ; chunks L..3
    STA PF0                 ; write 11  (before 22.67)
    LDA LeftPF1,Y           ; chunks 4..11
    STA PF1                 ; write 18  (before 28.00)
    LDA SzL2,X              ; chunks 12..19, centre gap already applied
    STA PF2                 ; write 25  (before 38.67)
    LDY RidxTable,X         ; the right edge index for this row
    LDA SzR0,X              ; chunks 20..23, centre gap already applied
    STA PF0                 ; write 36  (after 27.67, before 49.33)
    LDA RightPF1,Y          ; chunks 24..31
    STA PF1                 ; write 43  (after 38.33, before 54.67)
    LDA RightPF2,Y          ; chunks 32..39
    NOP
    NOP
    STA PF2                 ; write 54  (after 49.00, before 65.33)
}
```

Fifty-four cycles: six loads, six stores, two `LDY zp,X` (four cycles each, not
three) and two `NOP`s. The left group must be in the registers before the
visible area reaches the left chunks (22.67, 28.00, 38.67) and the right group
must land after the left chunks have gone by and before the right chunks arrive
(27.67 → 49.33, 38.33 → 54.67, 49.00 → 65.33). The tightest margin is right
`PF1`, 4.7 cycles.

Three of the six bytes are pre-masked in the vertical blank — `SzL2`, `SzR0` and
the two that never take the gap (`LeftPF0`, `LeftPF1`, `RightPF1`, `RightPF2`)
are plain table lookups. Note the last one: right `PF1` is *not* masked, which
is why the centre line saturates at chunk 23.

#### Step 4 — The mask tables

Six 20-entry tables, page-aligned so the indexed loads never cross a page and always cost 4 cycles:

```asm
LeftPF0:                        ; chunks L..3 on, PF0 bits 4-7
    !byte $F0, $E0, $C0, $80, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00
LeftPF1:                        ; chunks L..11 on, PF1 bits 7-0
    !byte $FF, $FF, $FF, $FF, $FF, $7F, $3F, $1F
    !byte $0F, $07, $03, $01, $00, $00, $00, $00
    !byte $00, $00, $00, $00
LeftPF2:                        ; chunks L..19 on, PF2 bits 0-7
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    !byte $FF, $FF, $FF, $FF, $FF, $FE, $FC, $F8
    !byte $F0, $E0, $C0, $80
```

The right-half tables use the same bit order because `CTRLPF`'s `REF` bit is clear: in repeat mode the TIA re-reads `PF0`, `PF1`, `PF2` in that order for the right half, so chunk 20 is `PF0` bit 4 and chunk 32 is `PF2` bit 0 — exactly the left half's mapping, shifted twenty chunks. That is the single reason this effect is practical: one set of bit layouts, two sets of edge values.

#### Step 5 — The centre gap and the demo

There is no dash table. The gap is folded into the two masked bytes, and the
dash state is folded into the table index:

```asm
MaskRow:
    TXA
    SEC
    SBC Dash                ; row - Dash: dashes move DOWN the screen
    AND #3                  ; the four-row dash period
    LSR                     ; 0 on a dash row, 1 on a plain row
    STA MaxOff              ; the dash bit
    LDA HalfTable,X         ; a four-pixel gap is a third of the road at
    CMP #DASH_MIN_HALF      ; the horizon, so the narrow rows get none
    BCS .wide
    LDA #$01                ; force the plain entry
    STA MaxOff
.wide:
    LDA LTable,X            ; L + Ridx + 20 = 40 + 2c
    CLC
    ADC RidxTable,X
    CLC
    ADC #20
    LSR                     ; /2 = 20 + c, the road's centre chunk
    SEC
    SBC #14                 ; the gap table starts at chunk 14
    ASL                     ; two entries per chunk: gap on, gap off
    ORA MaxOff
    STA GapIx
    LDY LTable,X            ; SzL2 = LeftPF2[L] AND GapL2Tab[GapIx]
    LDA LeftPF2,Y
    STA MaxOff
    LDY GapIx
    LDA GapL2Tab,Y
    AND MaxOff
    STA SzL2,X
    LDY RidxTable,X         ; SzR0 = RightPF0[Ridx] AND GapR0Tab[GapIx]
    LDA RightPF0,Y
    STA MaxOff
    LDY GapIx
    LDA GapR0Tab,Y
    AND MaxOff
    STA SzR0,X
    INX
    CPX #ROAD_ROWS
    BNE MaskRow
```

`GapL2Tab` and `GapR0Tab` are 26 entries each — 13 chunks (14 to 26) times two
dash states — and each entry is `$FF` with one bit cleared. `GapL2Tab` clears a
`PF2` bit for chunks 14-19, `GapR0Tab` a `PF0` bit for chunks 20-23, and the
entries for chunks 24-26 repeat the chunk-23 mask, because right `PF1` is
written in the same group as `PF0` and has no room for a third masked byte.
That saturation is the one place the line is not the true centre.

The pass costs 113 cycles a row, 2486 for the table, and it runs on a frame
where the edge pass did not — the two together would not fit the blank.

`Dash` advances every two frames, so a dash moves down the road at one row per
two frames: fast enough to read as motion, slow enough not to flicker at 30 Hz.
`PhaseTimer` counts 150 frames straight and 120 in each curve phase; `SELECT`
calls the same advance routine as the timer.

#### Step 6 — Reading it back in Stella

Assemble with a symbol file and ask Stella for the checkpoints:

```bash
acme -f plain -l build/lesson75.sym -o build/lesson75.bin \
  lessons/part11-legendary/75-pseudo-3d-road/75-pseudo-3d-road.asm
grep -E "StartFrame|VblankStart|BodyStart|SkyEnd|RoadBody|OverscanStart" build/lesson75.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 \
  -break '$F063' docs/public/roms/part11-legendary/75-pseudo-3d-road/75-pseudo-3d-road.bin
```

One checkpoint per run keeps the log readable. The addresses below are the ones this source produced.

#### Step 7 — What the trace shows

The cycle convention, once: **the ledger counts from cycle 0, the first instruction after the `WSYNC` release; a store's write lands three cycles after it starts.** Stella's breakpoint log reports the instruction's *start* line and cycle, and a breakpoint on the first instruction after a `STA WSYNC` fires during the stall and reports the `WSYNC`'s own line and cycle.

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F063` | 259/3 | the first VSYNC line |
| `VblankStart` | `$F071` | 0/5 | the first VBLANK line |
| `BodyStart` | `$F1AB` | 37/5 | visible line 0 |
| `SkyEnd` | `$F1C0` | 116/9 (the `WSYNC` stall) | the horizon line begins on 117 |
| `RoadBody` | `$F1D7` | 119/3 | the first road row's first line |
| `OverscanStart` | `$F293` | 228/64 (the `WSYNC` stall) | the first blanked line is 229 |

The frame log: `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, the sky ends on 116, the road runs 119-228, the overscan 229-258, the VSYNC 259-261. 229 − 37 = 192 visible lines, and 3 + 37 + 192 + 30 = 262. Measured over 393 consecutive frames the `StartFrame` breakpoint reported 259 every time: the VBLANK rebuild fits inside the blank.

### Checkpoints

Every address below was regenerated from the symbol file (`acme -l`); that file
is the authority, and the `-break` commands in the next section use the same
six.

The six addresses are in the [Checkpoints](#checkpoints) table below.

The state that is worth watching in RAM:

| Address | Holds | What to expect |
|---|---|---|
| `$8B`-`$A0` | `LTable` | row 0 is 19; row 21 is 10; the values step down by one |
| `$A1`-`$B6` | `RidxTable` | row 0 is 1; row 21 is 10; the values step up by one |
| `$B7`-`$CC` | `SzL2` | left `PF2`, centre gap applied |
| `$CD`-`$E2` | `SzR0` | right `PF0`, centre gap applied |
| `$82` | `Scroll` | advances once every eight frames, 0..31 |
| `$84` | `Dash` | advances once every two frames, 0..7 |
| `$81` | `CurveMask` | `$00` for three seconds, `$FF` for three seconds |

In the Stella debugger, break at `RoadBody` (`$F1D7`) and watch `LTable,X` and
`RidxTable,X` as X climbs: the two values move apart by one every few rows, and
that is the whole road.

## What You Should See

At power-on the screen is a daylight sky: blue above, one gold horizon line below it, and a gold eight-pixel sun in the upper right. Under the horizon a grey road starts as a twelve-pixel strip and widens to eighty-four pixels at the bottom of the screen, flanked by green verges. Three or four short green dashes mark the road's centre, starting a third of the way down where the road is wide enough to carry them, and they drift down the road toward the viewer. Every three seconds the road leans into a curve and then snaps straight again.

![Stella running Lesson 75 at two seconds: the straight road, a grey wedge from a narrow horizon to the full width of the screen, green verges, a gold sun and horizon band, and a green dashed line down the centre](/images/lesson75/straight.png)

*`straight.png`: about 2 seconds after power-on, in the straight phase. The road's edges step outward one playfield chunk at a time, and every scanline of a row carries the same edge; the green dashes in the centre are a hole in the playfield rather than an object.*

<RomPlayer rom="/roms/part11-legendary/75-pseudo-3d-road/75-pseudo-3d-road.bin" title="Lesson 75 — Pseudo-3D Road — The Enduro / Pole Position Effect" />

*Javatari starts muted; this ROM is silent.*

After three seconds the curve switches on and the road leans. The curve is the same four-pixel chunk grid, so it reads as a staircase rather than a smooth arc:

![Stella running Lesson 75 at five seconds: the same road leaning into a curve, its bottom edge shifted five chunks to the left of the straight state, with the sun and horizon unchanged](/images/lesson75/curve.png)

*`curve.png`: about 5 seconds after power-on, in the curved phase. The bottom of the road has moved five chunks (20 pixels) to the left; the horizon end has not moved at all, because the clamp at the narrow rows is zero.*

The two images are different states, not two copies of one frame. The **pixel check** of the two committed captures:

| Image | Size | Title bar | The road's edges, measured |
|---|---|---|---|
| `straight.png` | 1010×807 | `Stella 7.0: "75-pseudo-3d-road"` | TIA viewport 960×605 at (25,107). Row 0 (visible line 82): x 76-87, chunks 19-21. Row 21 (visible line 191): x 40-123, chunks 10-30, centre chunk 20.4. Three dashes — rows 10-11, 14-15 and 18-19 — each a gap at chunk 20 (x 80-83). |
| `curve.png` | 1010×807 | `Stella 7.0: "75-pseudo-3d-road"` | the same viewport; row 0 unchanged at x 76-87; row 21 at x 20-103, chunks 5-25, centre chunk 15.4. Two dashes at this phase — rows 14-15 with the gap at chunks 22 and 21, and rows 18-19 at chunks 18 and 17 — each row's own centre chunk, within half a chunk. |

The **curve check**: the bottom row's centre moves from chunk 20.4 to chunk 15.4, a shift of **five chunks — 20 pixels**. The size of the shift depends on where in the 32-entry curve table the capture lands, so it varies between roughly four and six chunks from run to run; the documented pair is five. The horizon end does not move at all, which is the clamp doing its job: `HalfTable[0]` is 1, so `MaxOff` is 0 and the narrow end of the road is pinned to the centre in both phases.

The **road check**: the width grows monotonically from 3 chunks to 21, and every one of the five scanlines in a row carries the same edges. That was checked line by line on both captures: each image contains only a handful of distinct edge pairs (10 in the straight one, 17 in the curved one), and every pair covers 5, 10 or 15 consecutive lines — one, two or three whole rows, never a partial one. Every step between rows is one or two chunks (±4 or ±8 pixels) with no isolated spike. If the left/right write order or its timing were wrong, one of those five lines would show the other half's mask and the right edge would be discontinuous.

The **centre-line check**: in the straight capture every dash sits at chunk 20, which is `20 + c` with `c = 0`. In the curved capture the gaps sit at chunks 22, 21, 18 and 17 while those rows' roads are centred on 22.4, 21.4, 18.4 and 17.4 — the gap tracks the centre row by row, never more than half a chunk away. That is the difference between a centre line and a line drawn on the screen's centre.

The **bottom check**: the last road row is visible lines 187-191, and the road is still there on line 191 — the last line of the picture. In both captures the road's pixels run to image row 711, which is the last row of the TIA viewport (rows 107-711, 192 lines at 3.15 pixels per line). The black band below row 711 is the window margin outside the emulated screen, not a missing part of the picture.

> **Capture method.** Both images are `scripts/capture-screenshot.sh` captures of the committed
> `docs/public/roms/part11-legendary/75-pseudo-3d-road/75-pseudo-3d-road.bin` on display `:0`
> at two and five wall-clock seconds, with `xdotool mousemove 0 0` before each. The auto-demo
> timer starts at power-on: the 2-second image samples the straight phase (frames 0-179) and the
> 5-second image the curved phase (frames 180-359). All images are 1010×807, carry the window
> frame and the `Stella 7.0: "75-pseudo-3d-road"` title bar, and show no cursor.

The debugger tells the same story as numbers:

```bash
ROM=docs/public/roms/part11-legendary/75-pseudo-3d-road/75-pseudo-3d-road.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -break '$F063' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -break '$F071' $ROM   # VblankStart
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -break '$F1AB' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -break '$F1C0' $ROM   # SkyEnd
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -break '$F1D7' $ROM   # RoadBody
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -break '$F293' $ROM   # OverscanStart
```

- **`$F063` (`StartFrame`)** is **259/3** on every frame — across 393 consecutive frames it never moved. **`$F071`** is **0/5**, **`$F1AB`** is **37/5** and **`$F293`** is **228/64**: the frame does not grow in either demo state.
- **`$F1C0` (`SkyEnd`)** logs **116/9** during the `WSYNC` stall, so the gold horizon line is 117 and the verge is 118; **`$F1D7` (`RoadBody`)** logs **119/3**, the first road line, and the same breakpoint fires at 123, 128, 133 and so on to 223 — 22 rows, five lines each.
- The rebuild finish labels log scanlines 23-26 (`EdgeDone`) and 2-36 (`MaskDone`); the two passes never run on the same frame, so the blank always closes with `BodyStart` on 37.

The screenshots prove the shape and the curve; the state log proves the clock. What the stills cannot show is the dash motion — that needs the ROM running, and the player above is the same binary.

## Exercises

Each exercise ships a complete 4,096-byte `exercise-NN-solution.asm`. The solutions assemble through `npm run roms`, run in Stella, and solve the exercise as written. Both keep the three bands, the mask tables, the clamp and the dashed centre line.

### Exercise 1: A Night Road, Twice as Wide at the Horizon

**Challenge:** recolour the road and its verges, and change the width table so the road is **five chunks wide at the horizon** instead of three, keeping the 21-chunk bottom. Keep the frame at 262 lines and the ROM at exactly 4,096 bytes.

**Hints:**

1. The palette is four constants: `C_SKY`, `C_GOLD` (the sun **and** the horizon band share `COLUPF`), `C_GRASS` and `C_ROAD`. A night palette with a bright road reads best: `$84` sky, `$0E` moon and horizon, `$D2` verges, `$1C` road.
2. The width table is `HalfTable`, one byte per row, `2..10` in this solution. Widening the horizon means starting at 2 (which draws `2×2+1 = 5` chunks, the road spans `L..R` inclusive) and reaching 10 in 22 rows. `BaseLTable` is always `20 - HalfTable`, so both tables change together.
3. Keep the `!if` band assertion at the top of the file: it is what stops a width-table edit from silently changing the line count.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; the horizon road measures five chunks (x 72-91, chunks 18-22) instead of the lesson's three (x 76-87); the bottom still measures 21 chunks (x 40-123); the sky band is dark blue with a white moon; `StartFrame` is 259 on 430 consecutive frames and the frame is 262.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Three Phases — Straight, Right, Left

**Challenge:** add a second curve phase so the demo runs **straight, curve right, curve left** and repeats. Phase 0 must be long enough that the 2-second capture is comfortably inside it — 150 frames (2.5 s) does that — and the two curve phases can be 120 frames each. Keep the ROM at 4,096 bytes and the frame at 262.

**Hints:**

1. The cheapest way to mirror the curve is **not** to negate it at run time: the vertical-blank rebuild is 22 rows of arithmetic with only a few lines of margin. Lengthening the table instead costs nothing per frame.
2. Instead, make the curve table **twice as long**: entries 0-31 are the right-hand wave, entries 32-63 the same values negated. Wrap the wave first and add the base afterwards: `SBC Scroll` / `AND #31` / `CLC` / `ADC CurveBase` / `TAY`. Adding the base before the wrap would make the base itself wrap, which is not the same index.
3. Replace the two-phase toggle with a three-phase counter (`Phase` 0/1/2) and set `CurveMask` = 0 for phase 0, `$FF` for phases 1 and 2, with `CurveBase` = 0 or 32. `SELECT` calls the same advance routine.
4. Set `CurveDirty` to `$01` (not to the mask) **inside** the "the timer expired" branch, and set `MaskDirty` with it. The first version of this solution put the flag at the fall-through label, so the tables were rebuilt on every frame, the mask pass was skipped every frame and the centre line vanished; and storing `CurveMask` into the flag wrote `$00` when going back to straight, so that direction never rebuilt at all.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; at 2 s the bottom of the road is at x 40-123 (chunks 10-30, straight), because phase 0 lasts 150 frames; at 5 s the capture lands in **phase 2** — frame 300 of the 390-frame cycle, which runs 270-389 — the left-hand curve, measured at x 20-103; phase 1 (frames 150-269) is the mirror of it. `StartFrame` is 259 on 452 consecutive frames and the frame is 262.

**Solution:** See `exercise-02-solution.asm`

## Key Takeaways

- ✅ **A pseudo-3D road is a staircase, not geometry.** 22 rows of five scanlines, each row a contiguous run of four-pixel playfield chunks whose length grows as you move down the screen. Nothing in the ROM knows what a road is; change `HalfTable` and the road changes.
- ✅ **The playfield is re-read on every line, as the beam arrives.** Six writes per scanline, and the halves have specific windows: pixel x is drawn at cycle `22.67 + x/3`, so the left byte must be in before 22.67/28.00/38.67 and the right byte between 27.67 and 49.33, 38.33 and 54.67, 49.00 and 65.33. Forget the 22.67 offset and every write is one horizontal blank too early, which swaps the halves — measured, not assumed.
- ✅ **The clamp is the perspective.** Clamping the curve to `±(Half - 1)` keeps the road across chunk 19/20, and because `Half` grows toward the bottom of the screen, the narrow rows flatten by themselves. The curve's falloff toward the horizon is free.
- ✅ **Move the arithmetic where it fits — in two passes.** 81-85 cycles of width, curve, clamp and edge lookup will not live in a 22-cycle kernel slot; 22 rows of it fit in the vertical blank (about 1870 cycles). The masked bytes are a second pass of 2486 cycles, and running both on one frame would not fit, so the second is deferred by a frame — which keeps `BodyStart` on 37 for every frame measured.
- ✅ **Count down, not up.** `row − Scroll` and `row − Dash` make a feature appear at row 0 and move toward the viewer. `row + Scroll` moves it the other way, toward the horizon, which is the wrong direction for a road you are driving down.
- ✅ **The capture is the proof of the curve.** The bottom of the road moves five chunks — 20 pixels — between the two stills, and the horizon end does not move at all: the clamp, visible as a measurement. Every one of the 110 road lines carries one of only 10 (straight) or 17 (curve) edge pairs, each covering a whole number of rows — which is what "the five lines of a row are identical" looks like as a number.
- ✅ **A centre line has to follow the road.** The gap chunk is `20 + c`, not a fixed 19 or 20; the dashes sit at chunk 20 straight ahead and at 22, 21, 18 and 17 as the road bends (centres 22.4, 21.4, 18.4 and 17.4). A line pinned to the screen's centre looks correct straight ahead and wrong the moment the road bends.

## What's Next

The road ends with the two captures and the dashed line; [the Part 11 index](/part11-legendary/) lists the rest of the anthology. The next legendary technique, **Procedural Worlds from a Seed**, takes the same "the picture is a table" idea in a different direction: a linear-feedback shift register that generates a scrolling world from a single byte, the way *Pitfall!* and *River Raid* did — same hardware, no stored map. Return to the index for the part's overview and the next lesson.
