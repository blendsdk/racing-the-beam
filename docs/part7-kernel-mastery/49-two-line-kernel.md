---
title: "Lesson 49: The 2-Line Kernel — Standard Game Pattern"
description: "Build the 2-line kernel that most 2600 games are built on: 96 rows for 192 scanlines, a 62-cycle nominal row body (63 effective) inside the 152-cycle pair, per-row mountain and sky colour ramps, a 16-line figure on P0, a 16-line bird on P1, one HMOVE, and a joystick-driven figure with a 272-frame auto-demo."
prev:
  text: "Lesson 48: Introduction to Kernels — The Heart of Every 2600 Game"
  link: "/part7-kernel-mastery/48-introduction-to-kernels"
next:
  text: "Lesson 50: Multi-Zone Kernel — Scoreboard + Playfield + Sprites"
  link: "/part7-kernel-mastery/50-multi-zone-kernel"
---

# Lesson 49: The 2-Line Kernel — Standard Game Pattern

> **Part 7: Kernel Mastery** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC` and timing), Lesson 17 (cycle counting), Lesson 18 (mid-scanline changes), Lesson 19 (the playfield), Lesson 20 (playfield colours), Lesson 25 (players), Lesson 26 (positioning), Lesson 28 (the one-`HMOVE` rule), Lesson 31 (`NUSIZ`), Lesson 48 (the kernel taxonomy)
> **You will learn:** why one data byte per two scanlines is the platform's default; how 96 rows fill the 192-line visible area; how to count a seven-store row body against the 152-cycle pair; why the store order is a beam-race decision, not a matter of taste; how per-row colour ramps and a reflected playfield build a mountain pass; and how to move a 16-line figure with one `HMOVE` and a 272-frame auto-demo
> **You will build:** "the mountain pass" — a 4,096-byte ROM with a 96-row reflected mountain, a blue-to-gold sky ramp, a grey-to-green mountain ramp, a red 16-line figure on P0, a white 16-line bird on P1, a joystick-driven figure clamped to TIA X 8–144, and a 272-frame auto-demo; plus three exercise solutions: an unrolled two-row loop, a two-pixel-per-frame figure, and three copies of the figure

## Introduction

Lesson 48 named the kernel shapes and showed the one-line and two-line kernels side by side. The 2-line kernel won that comparison for the same reason it won on real cartridges: one data byte covers two scanlines, so 96 bytes fill the screen and the row body has **152 cycles** to spend instead of 76. Almost every full-screen game from *Combat* onward starts from this shape. This lesson builds the standard version and then makes it carry a complete picture.

The companion program `49-two-line-kernel.asm` is **the mountain pass**. It draws 96 rows, each two scanlines tall. Every row writes seven values: three playfield bytes (`PF0`, `PF1`, `PF2`) for the mountain silhouette, two colour bytes (`COLUPF`, `COLUBK`) for the mountain and sky ramps, and two player graphics bytes (`GRP0`, `GRP1`) for a red figure and a white bird. The playfield is reflected, so one row draws two mountain walls with a sky pass between them. The pass is wide at the top, where the sky runs from dark blue to gold, and closes at row 84, where the mountain fills the screen. The red figure stands at visible lines 150–165; the white bird sits in a 16-line slot at 60–75. The joystick moves the figure one pixel per frame; with no input, an auto-demo sweeps it from X=8 to X=144 and back every 272 frames (after a shorter first cycle), so both screenshots are reachable without touching a control.

The lesson's real subject is the **row body**. Seven load/store pairs and two `WSYNC`s cost 62 cycles nominal (63 effective, because the loop's `BNE` crosses a page), well inside the 152-cycle pair. That sounds like an easy budget, and it is — until you notice that only the first ~23 cycles of the first scanline are horizontal blanking. The stores spill into the visible area, and their order decides which pixels on the first scanline see the previous row's value. By the end of the lesson you can count the row, order its stores by pixel deadline, and explain exactly what the second scanline buys you.

::: details TypeScript Equivalent

The 2-line kernel is a table of rows and a loop that displays each row twice. In TypeScript the same idea is a row renderer:

```typescript
interface Row {
  pf0: number;       // the three playfield bytes
  pf1: number;
  pf2: number;
  mountain: number;  // COLUPF
  sky: number;       // COLUBK
  p0: number;        // GRP0
  p1: number;        // GRP1
}

function drawRow(row: Row): void {
  // The order is the lesson's beam-race order: the sprite whose left
  // edge can be at X=8 goes first, the playfield bytes next, the colour
  // ramps after them, and the fixed bird last.
  writeRegister("GRP0", row.p0);
  writeRegister("PF0", row.pf0);
  writeRegister("PF1", row.pf1);
  writeRegister("COLUPF", row.mountain);
  writeRegister("PF2", row.pf2);
  writeRegister("COLUBK", row.sky);
  writeRegister("GRP1", row.p1);
}

function drawFrame(rows: Row[]): void {
  for (const row of rows) {
    drawRow(row);
    waitScanline();   // line 1 of the pair
    waitScanline();   // line 2 shows the same bytes
  }
}
```

The analogy breaks in the places that matter. There is no framebuffer and no `Row` array in RAM: the 96 rows are 672 bytes of ROM, and `drawRow` writes TIA latches that the beam reads *as it passes*. A write that lands after the beam has drawn the relevant pixels changes nothing on this line; it waits for the next line. `waitScanline()` is `STA WSYNC`: it stops the CPU until the end of the current line, and the CPU resumes at the start of the next one. The loop is not free: seven load/store pairs plus two `WSYNC`s plus the loop tail must fit the 152-cycle pair, and the store order has to follow the pixel deadlines. In TypeScript you can reorder statements freely; on the 2600 the order is part of the picture.

:::

## Theory

### Section 1: One Byte, Two Scanlines

The visible area is 192 scanlines. A 1-line kernel writes one byte per scanline, so it needs 192 bytes per object plane and a 76-cycle row body. A 2-line kernel writes one byte per **two** scanlines, so it needs 96 bytes per plane and has **152 cycles** for the pair. The trade-off is vertical detail: a shape's edge can move only every two lines. That is why 2-line graphics look chunky, and why the shape is the platform's default — 96 rows leave room for the game.

The frame is the Lesson 12 skeleton:

```
3 lines    VSYNC
37 lines   VBLANK   (logic, positioning, the first-row preload)
192 lines  picture  (96 rows x 2 scanlines)
30 lines   overscan
---------
262 lines  NTSC
```

`StartFrame` is scanline 259, `VblankStart` is 0, `BodyStart` is 37 (visible line 0), and `OverscanStart` is 229. The kernel runs once per frame at about 60 Hz. It never waits for the game logic: the logic must already have written the values the kernel will copy to the TIA.

The mountain pass stores seven 96-byte planes:

| Plane | Register | What it draws |
|---|---|---|
| `MtnPF0` | `PF0` | playfield chunks 0–3 |
| `MtnPF1` | `PF1` | playfield chunks 4–11 |
| `MtnPF2` | `PF2` | playfield chunks 12–19 |
| `MtnColor` | `COLUPF` | the mountain colour for the row |
| `SkyColor` | `COLUBK` | the sky colour for the row |
| `P0Strip` | `GRP0` | the figure: eight shape bytes at rows 75–82 |
| `P1Strip` | `GRP1` | the bird: eight shape bytes at rows 30–37 |

Seven planes × 96 bytes = 672 bytes of picture data. The row loop reads one byte from each plane per iteration; the index `Y` is both the row counter and the table index, so row 0 is the top of the screen and row 95 is the bottom.

::: tip Why the index is the row
The course's row loops are top-down: `LDY #0`, draw row 0, then `INY; CPY #96; BNE`. Y runs 0..95, exactly 96 iterations, and the table index equals the visible row. A `DEY; BNE` down-counter would draw the table backwards. There is no sentinel; the tables are exactly 96 bytes. Lesson 48's `LineRow` used the same form.
:::

### Section 2: The 62-Cycle Row Body (63 Effective)

A row body is seven load/store pairs, two `WSYNC`s, and the loop tail. Count the cycles:

| Work | Cycles | Running total |
|---|---|---|
| 3 PF pairs (`LDA table,Y` 4 + `STA PFx` 3) | 21 | 21 |
| `COLUPF` pair | 7 | 28 |
| `COLUBK` pair | 7 | 35 |
| `GRP0` pair | 7 | 42 |
| `GRP1` pair | 7 | 49 |
| `STA WSYNC` × 2 | 6 | 55 |
| `INY` 2 + `CPY #96` 2 + `BNE` 3 (taken) | 7 | **62** nominal |
| taken-branch page cross (`BNE KernelRow`, $F1 -> $F0) | 1 | **63** effective |

The two-line budget is 152 cycles, so the pair leaves **89 cycles of margin** — 44.5 per scanline. The second line is idle: the first `WSYNC` ends line 1, and the second `WSYNC` waits out the whole of line 2. The CPU has nothing to do on that line unless the programmer gives it work.

Two costs are not in the nominal 62 (the taken-branch page cross makes the effective body 63):

- **A page-crossing indexed load adds 1 cycle.** `LDA table,Y` is 4 cycles when the access stays inside the table's page and 5 when it crosses. Every 96-byte table in this lesson is page-aligned with `!align 255,0`, so `Y=0..95` never crosses, and the ledger needs no allowance.
- **The taken branch adds 1 cycle.** The `BNE` is 3 cycles when taken and 2 when not; the ledger uses the taken value for every row except the last, where the branch falls through and the frame ends 1 cycle early. The difference is invisible.

The 90-cycle margin is the point of the 2-line kernel. A 1-line kernel's row body has 76 cycles, and a full-screen game quickly spends them. The 2-line pair gives the same picture twice as long, which is why it is the standard.

### Section 3: The Store Order and the Beam

The row body's seven stores do not all fit in horizontal blanking. The visible area starts **68 colour clocks** into the scanline, which is **22.67 CPU cycles**. In steady state the loop tail of the previous pair has already spent 8 cycles (the taken `BNE` crosses a page), the `LDA` takes 4, and the `STA` writes on its third cycle, so the first store of a row lands at about **cycle 15**; the first row, with no tail, is 14. Only the first two stores fit before cycle 22.7; the other five land in the visible area.

That is not fatal, because the TIA draws each object at a known pixel position. A store that lands before the object's pixels changes the whole object; a store that lands inside the pixels changes the rest of it; a store after the pixels leaves the previous value on this line and the new value on the next. The store order follows the **pixel deadlines**:

| Register | First pixel | Deadline (cycle) | Why |
|---|---|---|---|
| `GRP0` | the figure at X=8 | 25.3 | the figure can move to the left edge |
| `PF0` | chunk 0, X=0 | 22.7 | the mountain starts at the left edge |
| `PF1` | chunk 4, X=16 | 28.0 | the next six chunks of mountain |
| `COLUPF` | the mountain at X=0 | 22.7 | the mountain's first colour |
| `PF2` | chunk 12, X=48 | 38.7 | the inner edge of the pass |
| `COLUBK` | the sky at the pass edge | 26.7–48.0 | depends on how wide the pass is |
| `GRP1` | the bird at X=104 | 57.3 | the bird is fixed at X=104 |

The lesson's order is:

```
GRP0 -> PF0 -> PF1 -> COLUPF -> PF2 -> COLUBK -> GRP1
```

`GRP0` goes first because a late `GRP0` (at about cycle 50, as it would be in a playfield-first order) would show the previous row's figure byte on the first scanline for any figure left of about X=82 (the store applies from pixel 82); writing `GRP0` first removes that failure entirely. `PF0` and `PF1` follow because their chunks are the outer mountain wall. The steady-state stores are `PF0` at 22 (pixel −2, 2 pixels of margin), `PF1` at 29 (pixel 19, 3 pixels into its chunk-4 field), `COLUPF` at 36 (pixel 40), `PF2` at 43 (pixel 61), `COLUBK` at 50 (pixel 82) and `GRP1` at 57 (pixel 103). Only the first `PF1` step (row 8) shows a 3-pixel sky notch; the later `PF1` steps change a chunk at X≥20, after the store. `COLUPF` is about 13 cycles late, so the first ~40 pixels (ten chunks) of the mountain keep the previous row's colour on the first scanline of a ramp step. `PF2`'s chunk 12 starts at X=48 (cycle 38.7); the store at 43 applies from pixel 61, so the first ~13 pixels (about three chunks) of the `PF2` field keep the previous row's byte on the rows whose new chunk falls before pixel 61 (42/48/54; row 60's chunk 15 loses pixel 60). `COLUBK` is written at cycle 50, so the left part of the sky — up to ~70 pixels at the top rows — keeps the old colour on the first scanline of a sky step. `GRP1` is safe last because the bird's fixed X=104 puts its first pixel at cycle 57.3, one pixel of margin. The first row is one cycle earlier throughout (14/21/28/35/42/49/56); the steady-state values above are the operative ones.

The **second scanline of every pair is always correct**: all seven latches hold until the next row's stores. The first scanline is where the store-order budget shows. The lesson measures it honestly rather than hiding it: on the first scanline of a row where a ramp steps, the left edge of the mountain or the sky still shows the previous colour; on row 8 the first three pixels of the `PF1` field keep the old byte; on the rows where the inner `PF2` edge moves, the first ~13 pixels can lag. The measured mountain edge matches the edge table exactly on 74 of 84 rows and is within one chunk on the other 10; the timing model's visible windows are row 8 and the `PF2` rows 42/48/54, so the extra measured rows sit at the capture's one-chunk threshold rather than a second lag mechanism. A production kernel spends the second line's idle cycles pre-loading the next row (the idea the pattern library in Lesson 53 packages). The simple 62-cycle nominal body (63 effective) is the starting point, and knowing its store-order budget is the lesson.

::: tip The second line is not wasted
`STA WSYNC` on the first line ends line 1; the second `STA WSYNC` waits out line 2. The CPU is stalled for ~70 cycles of line 2. Those cycles are the 89-cycle margin. A game can use them for the next row's arithmetic, a scroll update, or a sprite-positioning dance; the simple lesson leaves them empty so the 62/63 ledger is the only thing the reader has to count.
:::

### Section 4: The Mountain Pass Data

The playfield is drawn with `CTRLPF=$01` (reflect): the left half is the 20-bit playfield, and the right half mirrors it. One row's three bytes therefore draw **two** mountain walls with a sky pass between them.

The bit order is the classic confusion:

- `PF0` uses bits 4–7; bit 4 is the leftmost chunk (chunks 0–3).
- `PF1` uses bits 7–0; bit 7 is the leftmost chunk (chunks 4–11).
- `PF2` uses bits 0–7; bit 0 is the leftmost chunk (chunks 12–19).

The lesson stores a **body edge** `e` per row: the mountain fills chunks 0..e−1 of the left half. At `e=3` the mountain is a 12-pixel cap at each edge and the pass is 34 chunks wide; at `e=20` the pass is closed and the row is mountain from edge to edge. The edge runs:

```
rows  0- 3  e=3     rows  4- 7  e=4     rows  8-11  e=5
rows 12-15  e=6     rows 16-19  e=7     rows 20-23  e=9   (a cliff)
rows 24-29  e=10    rows 30-35  e=11    rows 36-41  e=12
rows 42-47  e=13    rows 48-53  e=14    rows 54-59  e=15
rows 60-65  e=16    rows 66-71  e=17    rows 72-77  e=18
rows 78-83  e=19    rows 84-95  e=20    (the pass closes)
```

The three PF planes are the edge expanded into masks. For `e=3`, `PF0=$70` lights chunks 0–2 and `PF1`/`PF2` are zero. For `e=9`, `PF0=$F0` and `PF1=$F8` light chunks 0–8. For `e=20`, all three are full.

The colours are per row too:

- **Mountain**: six 16-row bands, grey `$0A` at the top, lighter grey `$0C`, then dark green `$C0`, `$C2`, `$C4`, and `$C6` at the floor.
- **Sky**: ten 8-row bands plus a 16-row floor, dark blue `$84` at the top, through `$86`, `$88`, `$78`, `$6E`, `$5E`, `$4E`, `$3E`, `$2E`, `$26`, to gold `$1A` at the pass floor.

The figure and the bird are eight shape bytes each, displayed for two scanlines per byte:

```asm
P0Strip:                    ; rows 75-82, visible 150-165
    !fill 75, $00
    !byte $18, $3C, $7E, $5A, $18, $3C, $66, $C3
    !fill 13, $00

P1Strip:                    ; rows 30-37, visible 60-75
    !fill 30, $00
    !byte $00, $44, $6C, $7E, $3C, $18, $00, $00
    !fill 58, $00
```

The figure is a small person: head, shoulders, arms, body, and two legs. The bird is a spread-winged shape. The strips are 96 bytes each, mostly `$00`; the `!fill` directives build the gaps.

::: tip Why the strips are page-aligned
Each strip is 96 bytes. If a strip starts mid-page, a row near the bottom (`Y≥64` in a table that starts at page+192, or `Y≥95` at page+161) can cross into the next page and make `LDA table,Y` 5 cycles instead of 4. `!align 255,0` before each table removes the uncertainty. The lesson's ledger assumes no page cross; the alignment is what makes the assumption true.
:::

### Section 5: The Frame, the Players, and the Auto-Demo

The frame is the one from Lesson 12. VBLANK sets `VBLANK=$02`, starts the 44-tick timer (37 lines), does the movement and positioning, preloads the first row, and waits for the timer. The picture turns on at `BodyStart` (scanline 37). The kernel runs 96 rows × 2 `WSYNC`s and lands on `OverscanStart` (scanline 229). Overscan sets `VBLANK=$02`, starts the 36-tick timer (30 lines), waits, and jumps back to `StartFrame`.

The two players are positioned with the Lesson 26 divide-by-15 dance and **one** `HMOVE`:

```asm
    LDA P0X
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA P1X
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
HmoveApply:
    STA WSYNC
    STA HMOVE
HmoveDone:
```

Every coarse `RESxx` and every `HMxx` is set first, then one `WSYNC` and one `HMOVE` apply both fine offsets in the same HBLANK. The one-`HMOVE` rule from Lesson 28 is not an optimisation here; it is the only way to keep both players' positions from being re-applied twice. The `HMOVE` blanks the left 8 pixels of the following line, which is still inside VBLANK, so the visible picture is unaffected.

The joystick read is the same one Lesson 48 used. `SWCHA`'s player-0 direction bits are active low. The raw masks are `$40` (left) and `$80` (right); after `AND #$C0`, a left press reads `$80` and a right press reads `$40` — the other bit stays high. `$C0` is neither and `$00` is both. The code maps `$80` to the left branch (`DEC P0X`) and `$40` to the right branch (`INC P0X`), clamped to `P0X=8..144`. Do not reverse the two: a reversed map makes the joystick feel inverted on the first test.

With no input, the auto-demo moves one pixel per frame between the limits. At a limit it flips the direction and steps back on the same frame, so a full `8 -> 144 -> 8` cycle is `136 + 136 = 272` frames. The figure powers on at `P0_START=72`, so the first cycle is shorter (`72 -> 144 -> 8`); from then on the period is exactly 272. The state log confirms it: `P0XRead` reports 144 at frames 72 and 344 (272 apart) and 8 at frames 208 and 480 (272 apart).

## The Code

### Building This Lesson

```bash
# every lesson ROM, including this one:
npm run roms

# or just this one:
acme -f plain -o build/lesson49.bin \
  lessons/part7-kernel-mastery/49-two-line-kernel/49-two-line-kernel.asm

stella build/lesson49.bin
```

The three exercise solutions sit beside the lesson source. Each is a complete 4,096-byte ROM:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part7-kernel-mastery/49-two-line-kernel/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part7-kernel-mastery/49-two-line-kernel/exercise-02-solution.asm
acme -f plain -o build/exercise-03.bin \
  lessons/part7-kernel-mastery/49-two-line-kernel/exercise-03-solution.asm
```

### Full Source

The complete annotated source is the lesson's reference copy. It is reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 49: The 2-Line Kernel — The Mountain Pass — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; What this program does:
;   "the mountain pass": a full-screen 2-line kernel.  Every byte of picture
;   data covers two scanlines, so 96 rows fill the 192-line visible area.
;   Each row writes seven values:
;
;     PF0/PF1/PF2   the mountain silhouette (three 96-byte planes)
;     COLUPF        the mountain colour ramp (96 bytes)
;     COLUBK        the sky colour ramp (96 bytes)
;     GRP0          the figure strip (96 bytes, 8 shape bytes at rows 75-82)
;     GRP1          the bird strip   (96 bytes, 8 shape bytes at rows 30-37)
;
;   The mountain body fills playfield chunks 0..e-1 of the left half, where
;   e grows from 3 chunks at the top row to 20 at row 84.  CTRLPF=$01 reflects
;   the left half, so the same row draws two mountain walls with a sky pass
;   between them.  The pass narrows from 34 chunks at the top to 0 at row 84:
;   the top is a wide sunset sky, the bottom is the mountain floor.
;
;   P0 is a 16-line figure (8 bytes x 2) at strip rows 75-82, visible lines
;   150-165.  P1 is a 16-line bird at strip rows 30-37, visible lines 60-75.
;   The figure moves one pixel per frame with the joystick (left/right),
;   clamped to TIA X 8..144.  With no input a 272-frame auto-demo sweeps it
;   8 -> 144 -> 8 at one pixel per frame, so both extremes are reachable
;   without a key press.  The bird is fixed at X=104.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame is scanline 259, VblankStart 0, BodyStart 37, OverscanStart
;   229.  The kernel is work-first: write the row's registers, then wait.
;
; The kernel ledger (cycles; no page cross, the tables are page-aligned):
;   3 PF pairs        3 x 7 = 21
;   COLUPF                   7
;   COLUBK                   7
;   GRP0                     7
;   GRP1                     7
;   two STA WSYNC            6
;   INY + CPY #96 + BNE      7   (nominal; BNE 3)
;   taken-branch page cross +1  (BNE KernelRow crosses $F1 -> $F0)
;   ---------------------------------
;   total per two lines     62 nominal / 63 effective (31.5/line)
;   The two-line budget is 152 cycles, so the pair leaves 89 cycles of
;   margin (44.5 per line).  The second line is idle: its WSYNC waits it out.
;   Every 96-byte table below is page-aligned, so the indexed loads do not
;   add a page cross; the branch's page cross is counted above.
;
; Why the stores are in this order (it is not the order of the register
; list above):
;   The first line of a pair starts at cycle 0, but the loop tail of the
;   previous pair has already spent 8 cycles in steady state, so the first
;   store lands at cycle 15 (cycle 14 on the first row).  The TIA draws the
;   visible area from cycle 22.67.  GRP0 goes first because the figure's
;   left edge can be at X=8 (cycle 25.3): a late GRP0 (at about cycle 50 in
;   a playfield-first order) would put the previous row's byte on the first
;   line for any figure left of X=82.  PF0 and PF1 follow because chunks
;   0-11 start at cycles 22.7-28.  In steady state PF0 lands at 22 (pixel
;   -2, 2 px of margin); PF1 lands at 29 (pixel 19, 3 px into its chunk-4
;   field), and only the first PF1 step (row 8) shows a 3-px sky notch
;   because the later steps change a chunk at X>=20, after the store.
;   COLUPF is written at 36, so the first ~40 pixels of the mountain keep
;   the previous row's colour on the first scanline of a ramp step; PF2 is
;   next: chunk 12 starts at X=48 (cycle 38.7), and the store at 43 applies
;   from pixel 61, so the first ~13 px of the PF2 field keep the old byte
;   on the rows where the edge crosses chunks 12-19; COLUBK is written at
;   50, so the left part of the sky (up to ~70 pixels at the top rows)
;   keeps the old colour at a sky step; GRP1 is safe last because the
;   bird's fixed X=104 starts at cycle 57.3, one pixel of margin.  The
;   first row is one cycle earlier throughout (14/21/28/35/42/49/56); the
;   steady-state values above are the operative ones.  The second scanline
;   of every pair is always current: all seven latches hold until the next
;   row's stores.  The measured mountain edge matches the edge table exactly
;   on 74 of 84 rows and is within one chunk on the other 10; the model's
;   visible windows are row 8 and the PF2 rows 42/48/54, so the extra
;   measured rows sit at the capture's one-chunk threshold.
;   This is the beam-race trade-off the lesson measures; the 62/63 ledger
;   is unchanged by the order.
;
; Controls:
;   Joystick left/right moves the figure one pixel per frame, clamped to
;   X=8..144.  With no input the auto-demo sweeps the figure.  There is no
;   fire or SELECT action: this is a pure kernel lab.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), OverscanStart (229),
;   P0XRead / P1XRead (A = the players' left edges), JoyLeft / JoyRight
;   (A = P0X on the joystick branch), HmoveApply (the WSYNC stall),
;   HmoveDone (the store has executed), KernelRow (Y = 0..95),
;   RowWrite (A = the first row's P0 strip byte), BirdWrite (A = the first
;   row's P1 strip byte).  The RAM map is below.
;
; Build: acme -f plain -o build/lesson49.bin \
;        lessons/part7-kernel-mastery/49-two-line-kernel/49-two-line-kernel.asm
; Run:   stella build/lesson49.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

ROW_COUNT      = 96      ; 96 rows x 2 scanlines = 192 visible lines

P0_MIN         = 8       ; the figure's left limit (TIA X)
P0_MAX         = 144     ; the figure's right limit (8 pixels wide)
P0_START       = 72      ; power-on position; the auto-demo takes it from here
P1_X           = 104     ; the bird's fixed left edge

C_FIGURE       = $42     ; P0: red
C_BIRD         = $0E     ; P1: white
C_BG           = $02     ; the borders before the first row is preloaded

; =============================================================================
; RAM ALLOCATION ($80-$82; +clean_start zeroes every byte)
; =============================================================================
P0X          = $80   ; the figure's left edge, 8..144
P1X          = $81   ; the bird's left edge (fixed at P1_X)
DemoDir      = $82   ; the auto-demo's direction: 0 = left, 1 = right
;
; $83-$F7 are free (117 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (SetCoarseP0 / SetCoarseP1).

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
    STA SWACNT              ; port A is an input port (the joysticks)

    LDA #P0_START
    STA P0X                 ; the figure starts in the middle
    LDA #P1_X
    STA P1X
    LDA #$01
    STA DemoDir             ; the auto-demo sweeps right first

    LDA #C_BG
    STA COLUBK
    LDA #C_FIGURE
    STA COLUP0
    LDA #C_BIRD
    STA COLUP1
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the right half mirrors
    LDA #$00                ; the left half
    STA NUSIZ0              ; one 8-pixel copy of each player
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    STA ENAM0
    STA ENAM1
    STA ENABL

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
; 1. THE FIGURE — joystick left/right, or the auto-demo's sweep
; -----------------------------------------------------------------------------
; SWCHA's P0 direction bits are active low.  The raw masks are $40 (left)
; and $80 (right); after AND #$C0, a left press reads $80 and a right press
; reads $40 (the other bit stays high).  $C0 is neither; $00 (both) is
; ignored.  The clamp keeps the 8-pixel figure inside TIA X 8..144.
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ AutoMove
    CMP #$80
    BEQ MoveLeft
    CMP #$40
    BEQ MoveRight
    JMP AutoMove            ; both directions held: treat as no input
MoveLeft:
    LDA P0X
JoyLeft:                    ; checkpoint: A = P0X on the left branch
    CMP #P0_MIN
    BEQ MoveDone
    DEC P0X
    JMP MoveDone
MoveRight:
    LDA P0X
JoyRight:                   ; checkpoint: A = P0X on the right branch
    CMP #P0_MAX
    BEQ MoveDone
    INC P0X
    JMP MoveDone

; The auto-demo: one pixel per frame between the limits.  At a limit the
; direction flips and the same frame steps back, so a full 8 -> 144 -> 8
; cycle is 136 + 136 = 272 frames.  (The first cycle is shorter because the
; figure powers on at P0_START; from then on the cycle is exactly 272.)
AutoMove:
    LDA DemoDir
    BNE AutoRight
    LDA P0X
    CMP #P0_MIN
    BEQ AutoFlipRight
    DEC P0X
    JMP MoveDone
AutoRight:
    LDA P0X
    CMP #P0_MAX
    BEQ AutoFlipLeft
    INC P0X
    JMP MoveDone
AutoFlipLeft:
    LDA #$00
    STA DemoDir
    DEC P0X
    JMP MoveDone
AutoFlipRight:
    LDA #$01
    STA DemoDir
    INC P0X
MoveDone:

; -----------------------------------------------------------------------------
; 2. POSITION BOTH PLAYERS, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; Every coarse RESxx and every HMxx is set first; one WSYNC and one HMOVE
; apply both fine offsets in the same HBLANK (the one-HMOVE rule from
; Lesson 28).  The HMOVE blanks the left 8 pixels of the next line, which is
; still inside VBLANK, so the visible picture is unaffected.
    LDA P0X
P0XRead:                    ; checkpoint: A = P0X
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA P1X
P1XRead:                    ; checkpoint: A = P1X (104)
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the HMOVE store has executed

; -----------------------------------------------------------------------------
; 3. PRELOAD THE FIRST ROW
; -----------------------------------------------------------------------------
; The previous frame left the TIA holding the last row's values.  The first
; row's colours and playfield are written here, before the picture turns on,
; so the first visible line is correct even though the kernel's later stores
; land a few cycles into it.  The kernel's own first-row stores repeat the
; same bytes.
    LDA P0Strip
    STA GRP0
    LDA P1Strip
    STA GRP1
    LDA MtnPF0
    STA PF0
    LDA MtnPF1
    STA PF1
    LDA MtnPF2
    STA PF2
    LDA MtnColor
    STA COLUPF
    LDA SkyColor
    STA COLUBK

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines, 96 rows x 2 scanlines, work-first
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; The row loop is the course's top-down form: LDY #0, draw row Y, then
; INY / CPY #96 / BNE.  Y is both the row counter and the table index, so
; row 0 is the top of the screen and row 95 is the bottom.  There is no
; sentinel: the tables are exactly 96 bytes.
    LDY #0
KernelRow:                  ; checkpoint: Y = 0..95, the visible row
    LDA P0Strip,Y
RowWrite:                   ; checkpoint: A = this row's figure byte
    STA GRP0                ; the figure: write before its X=8 deadline
    LDA MtnPF0,Y
    STA PF0                 ; chunks 0-3
    LDA MtnPF1,Y
    STA PF1                 ; chunks 4-11
    LDA MtnColor,Y
    STA COLUPF              ; the mountain colour for this row
    LDA MtnPF2,Y
    STA PF2                 ; chunks 12-19 (the inner edge)
    LDA SkyColor,Y
    STA COLUBK              ; the sky colour for this row
    LDA P1Strip,Y
BirdWrite:                  ; checkpoint: A = this row's bird byte
    STA GRP1                ; the bird at its fixed X
    STA WSYNC               ; line 1 of the pair ends here
    STA WSYNC               ; line 2 displays the same bytes
    INY
    CPY #ROW_COUNT
    BNE KernelRow
; 96 rows x 2 lines = visible 0-191.  The last WSYNC releases the CPU at
; the start of scanline 229, which is the first overscan line.

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SetCoarseP0 / SetCoarseP1 — the Lesson 26 divide-by-15 positioning dance
; =============================================================================
; A = the desired left edge + POS_BIAS.  Each routine starts on a fresh line,
; divides by 15 with repeated SBC, turns the remainder into the HMxx fine
; value, and strobes the matching RESxx.  The caller applies both with one
; HMOVE.
SetCoarseP0:
    STA WSYNC
    SEC
DivP0:
    SBC #15
    BCS DivP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS

SetCoarseP1:
    STA WSYNC
    SEC
DivP1:
    SBC #15
    BCS DivP1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
    RTS

; =============================================================================
; THE TABLES — seven 96-byte planes, one byte per two scanlines
; =============================================================================
; Every table is page-aligned so a 96-row index (Y=0..95) never crosses a
; page: the kernel ledger needs no page-cross allowance.
;
; The mountain shape.  The body fills playfield chunks 0..e-1 of the left
; half; the reflection draws the mirror on the right.  e by row:
;
;   rows  0- 3  e=3    rows  4- 7  e=4    rows  8-11  e=5
;   rows 12-15  e=6    rows 16-19  e=7    rows 20-23  e=9  (a cliff)
;   rows 24-29  e=10   rows 30-35  e=11   rows 36-41  e=12
;   rows 42-47  e=13   rows 48-53  e=14   rows 54-59  e=15
;   rows 60-65  e=16   rows 66-71  e=17   rows 72-77  e=18
;   rows 78-83  e=19   rows 84-95  e=20 (the pass is closed)
;
; The sky pass is chunks e..(39-e): 34 chunks at the top, 2 at row 83, none
; from row 84.  The mountain colour is grey at the peaks and green at the
; floor; the sky is blue at the top and gold at the pass floor.
    !align 255, 0
MtnPF0:
    !byte $70, $70, $70, $70, $F0, $F0, $F0, $F0      ; rows  0- 7
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows  8-15
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 16-23
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 24-31
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 32-39
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 40-47
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 48-55
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 56-63
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 64-71
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 72-79
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 80-87
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 88-95

    !align 255, 0
MtnPF1:
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows  0- 7
    !byte $80, $80, $80, $80, $C0, $C0, $C0, $C0      ; rows  8-15
    !byte $E0, $E0, $E0, $E0, $F8, $F8, $F8, $F8      ; rows 16-23
    !byte $FC, $FC, $FC, $FC, $FC, $FC, $FE, $FE      ; rows 24-31
    !byte $FE, $FE, $FE, $FE, $FF, $FF, $FF, $FF      ; rows 32-39
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 40-47
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 48-55
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 56-63
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 64-71
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 72-79
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 80-87
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 88-95

    !align 255, 0
MtnPF2:
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows  0- 7
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows  8-15
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows 16-23
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows 24-31
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows 32-39
    !byte $00, $00, $01, $01, $01, $01, $01, $01      ; rows 40-47
    !byte $03, $03, $03, $03, $03, $03, $07, $07      ; rows 48-55
    !byte $07, $07, $07, $07, $0F, $0F, $0F, $0F      ; rows 56-63
    !byte $0F, $0F, $1F, $1F, $1F, $1F, $1F, $1F      ; rows 64-71
    !byte $3F, $3F, $3F, $3F, $3F, $3F, $7F, $7F      ; rows 72-79
    !byte $7F, $7F, $7F, $7F, $FF, $FF, $FF, $FF      ; rows 80-87
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 88-95

; The mountain colour: grey $0A at the top, dark green $C6 at the floor.
; Six 16-row bands: $0A, $0C, $C0, $C2, $C4, $C6.  Each row's COLUPF is a
; 96-byte table entry, written once per two scanlines.
    !align 255, 0
MtnColor:
    !byte $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A      ; rows  0- 7
    !byte $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A      ; rows  8-15
    !byte $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C      ; rows 16-23
    !byte $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C      ; rows 24-31
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0      ; rows 32-39
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0      ; rows 40-47
    !byte $C2, $C2, $C2, $C2, $C2, $C2, $C2, $C2      ; rows 48-55
    !byte $C2, $C2, $C2, $C2, $C2, $C2, $C2, $C2      ; rows 56-63
    !byte $C4, $C4, $C4, $C4, $C4, $C4, $C4, $C4      ; rows 64-71
    !byte $C4, $C4, $C4, $C4, $C4, $C4, $C4, $C4      ; rows 72-79
    !byte $C6, $C6, $C6, $C6, $C6, $C6, $C6, $C6      ; rows 80-87
    !byte $C6, $C6, $C6, $C6, $C6, $C6, $C6, $C6      ; rows 88-95

; The sky: dark blue $84 at the top, stepping through violet and red to
; gold $1A at the pass floor.  Ten 8-row bands plus a 16-row gold floor:
; $84, $86, $88, $78, $6E, $5E, $4E, $3E, $2E, $26, then $1A.
    !align 255, 0
SkyColor:
    !byte $84, $84, $84, $84, $84, $84, $84, $84      ; rows  0- 7
    !byte $86, $86, $86, $86, $86, $86, $86, $86      ; rows  8-15
    !byte $88, $88, $88, $88, $88, $88, $88, $88      ; rows 16-23
    !byte $78, $78, $78, $78, $78, $78, $78, $78      ; rows 24-31
    !byte $6E, $6E, $6E, $6E, $6E, $6E, $6E, $6E      ; rows 32-39
    !byte $5E, $5E, $5E, $5E, $5E, $5E, $5E, $5E      ; rows 40-47
    !byte $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E      ; rows 48-55
    !byte $3E, $3E, $3E, $3E, $3E, $3E, $3E, $3E      ; rows 56-63
    !byte $2E, $2E, $2E, $2E, $2E, $2E, $2E, $2E      ; rows 64-71
    !byte $26, $26, $26, $26, $26, $26, $26, $26      ; rows 72-79
    !byte $1A, $1A, $1A, $1A, $1A, $1A, $1A, $1A      ; rows 80-87
    !byte $1A, $1A, $1A, $1A, $1A, $1A, $1A, $1A      ; rows 88-95

; The figure strip: eight shape bytes at rows 75-82, so visible lines
; 150-165.  Each byte covers two scanlines.  The shape is a small person:
; head, shoulders, arms, body, and two legs.
    !align 255, 0
P0Strip:
    !fill 75, $00
    !byte $18, $3C, $7E, $5A, $18, $3C, $66, $C3
    !fill 13, $00

; The bird strip: eight shape bytes at rows 30-37, so visible lines 60-75.
; The wings are spread; the body is centred.
    !align 255, 0
P1Strip:
    !fill 30, $00
    !byte $00, $44, $6C, $7E, $3C, $18, $00, $00
    !fill 58, $00

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
> `lessons/part7-kernel-mastery/49-two-line-kernel/49-two-line-kernel.asm`.

### Code Walkthrough

#### Step 1 — The frame skeleton and the row loop

The frame is the Part 2–6 skeleton with the 2-line kernel in the middle:

```asm
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    ; ... movement, positioning, preload ...
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDY #0
KernelRow:                  ; checkpoint: Y = 0..95, the visible row
    ; ... seven stores, two WSYNCs ...
    INY
    CPY #ROW_COUNT
    BNE KernelRow
```

`ROW_COUNT` is 96. The loop draws row 0 on scanlines 37–38, row 1 on 39–40, and row 95 on 227–228. The last `WSYNC` releases the CPU at the start of scanline 229, which is `OverscanStart`. The frame is `3 + 37 + 192 + 30 = 262` lines, the same total as every other lesson in the course.

#### Step 2 — The 62-cycle nominal row body (63 effective)

The body is the lesson's subject. It writes seven values and then waits out the pair:

```asm
    LDA P0Strip,Y
RowWrite:                   ; checkpoint: A = this row's figure byte
    STA GRP0                ; the figure: write before its X=8 deadline
    LDA MtnPF0,Y
    STA PF0                 ; chunks 0-3
    LDA MtnPF1,Y
    STA PF1                 ; chunks 4-11
    LDA MtnColor,Y
    STA COLUPF              ; the mountain colour for this row
    LDA MtnPF2,Y
    STA PF2                 ; chunks 12-19 (the inner edge)
    LDA SkyColor,Y
    STA COLUBK              ; the sky colour for this row
    LDA P1Strip,Y
BirdWrite:                  ; checkpoint: A = this row's bird byte
    STA GRP1                ; the bird at its fixed X
    STA WSYNC               ; line 1 of the pair ends here
    STA WSYNC               ; line 2 displays the same bytes
```

The order is the beam-race order from Section 3, not the register list's order. The first `STA` writes at about cycle 14; `GRP0`'s player can be at X=8, whose first pixel arrives at cycle 25.3, so the figure goes first. `PF0` and `PF1` cover the outer mountain wall and are next. Five later stores (PF1, COLUPF, PF2, COLUBK, GRP1) land in the visible area; the three colour/inner-PF2 stores can lag, and GRP1 is safe before the bird. The second scanline is always correct because the latches hold.

#### Step 3 — The tables

The seven tables are data, not code. The mountain edge is a hand-designed silhouette; the three PF planes are the edge expanded to masks. Here are the first and last rows of each:

```asm
MtnPF0:                     ; chunks 0-3, bit 4 = chunk 0
    !byte $70, $70, $70, $70, $F0, $F0, $F0, $F0      ; rows  0- 7
    ...
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0      ; rows 88-95

MtnPF1:                     ; chunks 4-11, bit 7 = chunk 4
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows  0- 7
    ...
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 88-95

MtnPF2:                     ; chunks 12-19, bit 0 = chunk 12
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; rows  0- 7
    ...
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF      ; rows 88-95
```

The mountain colour has six 16-row bands; the sky has ten 8-row bands plus a 16-row gold floor. The figure and bird strips are mostly `$00`; the shape bytes sit at the rows the picture needs.

#### Step 4 — Positioning both players with one HMOVE

`SetCoarseP0` and `SetCoarseP1` are the Lesson 26 routines. Each starts with a `WSYNC`, subtracts 15 until the remainder is negative, turns the remainder into the `HMPx` high nibble, and strobes the matching `RESxx`. The caller sets both, then applies both with one `HMOVE`:

```asm
    LDA P0X
P0XRead:                    ; checkpoint: A = P0X
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA P1X
P1XRead:                    ; checkpoint: A = P1X (104)
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the HMOVE store has executed
```

`P0XRead` reports the value before the bias, so the state log is the game's coordinate, not the dance's intermediate number. `P1XRead` reports 104 ($68). `HmoveApply` is the `WSYNC` write (line 2 cycle 63 in the state log); the CPU waits to the end of line 2, and `HmoveDone` fires at line 3 cycle 3, after the one `HMOVE` store. One `HMOVE` per frame. The held-joystick logs prove the left/right branch and the `DEC`/`INC`; the clamps themselves are demonstrated by the auto-demo (8 and 144) and code-verified for the joystick.

#### Step 5 — The joystick and the auto-demo

The joystick maps `$80` to left and `$40` to right, exactly as Lesson 48's dash code did:

```asm
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ AutoMove
    CMP #$80
    BEQ MoveLeft
    CMP #$40
    BEQ MoveRight
    JMP AutoMove            ; both directions held: treat as no input
MoveLeft:
    LDA P0X
JoyLeft:                    ; checkpoint: A = P0X on the left branch
    CMP #P0_MIN
    BEQ MoveDone
    DEC P0X
    JMP MoveDone
MoveRight:
    LDA P0X
JoyRight:                   ; checkpoint: A = P0X on the right branch
    CMP #P0_MAX
    BEQ MoveDone
    INC P0X
    JMP MoveDone
```

The auto-demo is the same shape without the input test. At a limit it flips `DemoDir` and steps back on the same frame, so a full 8→144→8 cycle is 272 frames. The first cycle is shorter because the figure powers on at 72; the steady-state period is exactly 272.

#### Step 6 — The first-row preload

The previous frame leaves the TIA holding the last row's values. Before the picture turns on, VBLANK writes the first row's seven values:

```asm
    LDA P0Strip
    STA GRP0
    LDA P1Strip
    STA GRP1
    LDA MtnPF0
    STA PF0
    LDA MtnPF1
    STA PF1
    LDA MtnPF2
    STA PF2
    LDA MtnColor
    STA COLUPF
    LDA SkyColor
    STA COLUBK
```

The kernel's own first-row stores repeat the same bytes. The preload guarantees that the first visible line is correct even though the kernel's later stores land a few cycles into it. It costs 49 cycles in VBLANK (seven `LDA`/`STA` pairs, about 54 with the `VBLANK` and `LDA #$00` setup), which the 37-line timer easily absorbs.

#### Step 7 — Reading it back in Stella

Assemble with a symbol file and ask Stella for the checkpoints:

```bash
acme -f plain -l build/lesson49.sym -o build/lesson49.bin \
  lessons/part7-kernel-mastery/49-two-line-kernel/49-two-line-kernel.asm

stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -logtoconsole 1 \
  -break '$F045' \
  docs/public/roms/part7-kernel-mastery/49-two-line-kernel/49-two-line-kernel.bin
```

Stella keeps one `-break` per run, so run each checkpoint separately. The symbol file resolves the labels; the addresses below are the ones this source produced. `KernelRow` fires at scanline 37 with Y=0, 39 with Y=1, 41 with Y=2, and ends at 227 with Y=95. `RowWrite` fires at scanline 37 cycle 11 with A=0 (the first strip byte), then at 39 cycle 12 with A=0, and so on. `BirdWrite` fires at scanline 37 cycle 53 with A=0, and at scanline 99 cycle 54 with A=$44 (the bird's first lit byte).

### Checkpoints

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F045` | 259/3 | the first VSYNC line |
| `VblankStart` | `$F053` | 0/5 | the first VBLANK line |
| `BodyStart` | `$F0F1` | 37/5 | visible line 0 |
| `OverscanStart` | `$F11F` | 229/6 | the first blank line after the picture |
| `P0XRead` | `$F0B1` | A = `P0X` (73 at frame 1) | the figure's left edge |
| `P1XRead` | `$F0B9` | A = `$68` (104) | the bird's left edge |
| `HmoveApply` | `$F0BF` | 2/63 | the `WSYNC` stall; the CPU waits to the end of line 2 |
| `HmoveDone` | `$F0C3` | 3/3 | the `HMOVE` store, once per frame |
| `KernelRow` | `$F0F3` | Y = 0..95 | the row counter; one hit every two scanlines |
| `RowWrite` | `$F0F6` | A = the row's P0 byte | the first store of the row body |
| `BirdWrite` | `$F114` | A = the row's P1 byte | the last store before the `WSYNC` |
| `JoyLeft` | `$F072` | A = `P0X` | the left branch, under `-holdjoy0 L` |
| `JoyRight` | `$F07D` | A = `P0X` | the right branch, under `-holdjoy0 R` |

`OverscanStart` is scanline 229, and the cycle at the label (6) is the loop tail (INY + CPY + the not-taken BNE); the scanline is the frame fact. The same pattern appears in every lesson: the scanline is exact, the cycle depends on the tail.

## What You Should See

The picture is a mountain pass at sunset. The sky fills the centre: dark blue at the top, then lighter blue, violet, pink, peach, orange, and gold at the pass floor. The mountain walls are grey at the peaks, then lighter grey, then dark green toward the floor. The pass starts 34 chunks wide and narrows as the rows go down; at row 83 it is a two-chunk slit, and from row 84 the mountain fills the screen. A red 16-line figure stands at visible lines 150–165, in the lower fifth of the screen when it is at X=8. A white bird in a 16-line slot flies at visible lines 60–75, in the violet band.

![Stella running the Lesson 49 ROM with the figure at the left: a blue-to-gold sunset sky in a V-shaped mountain pass, grey-to-green mountain walls, a white bird, and a red figure at the lower left](/images/lesson49/landscape.png)

*The figure near the left of its travel (capture X≈13, visible lines 150–165). The image is a window capture of the committed ROM; the title bar reads `Stella 7.0: "49-two-line-kernel"`.*

<RomPlayer rom="/roms/part7-kernel-mastery/49-two-line-kernel/49-two-line-kernel.bin" title="Lesson 49 — The 2-Line Kernel" />

Click the player screen once: Javatari starts muted until a user gesture. The ROM needs no input to show both states: the auto-demo sweeps the figure one pixel per frame, 8→144→8 every 272 frames. Hold the joystick left or right to take over; releasing it hands control back to the auto-demo.

The second capture shows the same picture with the figure near the right of its travel. The mountain, sky, and bird are unchanged; only the figure has moved.

![Stella running the Lesson 49 ROM with the figure near the right: the same mountain pass and bird, with the red figure near the right edge](/images/lesson49/figure-right.png)

*The figure near the right (capture X≈142, visible lines 150–165). The image is a window capture of the committed ROM; the title bar reads `Stella 7.0: "49-two-line-kernel"`.*

> **Capture method.** Both images are window captures of
> `docs/public/roms/part7-kernel-mastery/49-two-line-kernel/49-two-line-kernel.bin` in Stella 7.0.
> The pointer was parked outside the window before each capture; the title bars read
> `Stella 7.0: "49-two-line-kernel"`. Because the figure moves one pixel per frame, a single
> fixed-wait capture cannot be aimed at the left or right extreme. Stella was launched on the
> committed ROM, a burst of window captures was taken with the same `xwininfo` lookup the
> screenshot script uses, and the frames were selected by pixel analysis: the leftmost and
> rightmost red figure bounding boxes. The colours and positions are decoded from the captured
> pixels with `capture x = 25 + 6 × TIA X` and `capture y = 107 + 3.15 × visible line`, not
> copied from a log.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
# the frame boundaries
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F045' \
  docs/public/roms/part7-kernel-mastery/49-two-line-kernel/49-two-line-kernel.bin
# the row counter
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0F3' \
  docs/public/roms/part7-kernel-mastery/49-two-line-kernel/49-two-line-kernel.bin
# the left joystick branch
stella -audio.enabled 0 -holdjoy0 L -dbg.logbreaks 1 -logtoconsole 1 -break '$F072' \
  docs/public/roms/part7-kernel-mastery/49-two-line-kernel/49-two-line-kernel.bin
```

- **`$F045` (`StartFrame`)** is **259/3** and **`$F053` (`VblankStart`)** is **0/5**: the VSYNC and VBLANK boundaries of the 262-line frame.
- **`$F0F1` (`BodyStart`)** is **37/5**: visible line 0. **`$F11F` (`OverscanStart`)** is **229/6**: the first blank line after the picture; the cycle is the loop tail, the scanline is the frame fact.
- **`$F0F3` (`KernelRow`)** fires at line 37 with Y=`$00`, line 39 with Y=`$01`, line 41 with Y=`$02`, and ends at line 227 with Y=`$5F` (95). That is 96 rows over 192 scanlines.
- **`$F0F6` (`RowWrite`)** fires at line 37 cycle 11 with A=`$00`, line 39 cycle 12 with A=`$00`, line 41 cycle 12 with A=`$00`. The A column is the row's `P0Strip` byte; the figure's first lit byte is at row 75.
- **`$F0BF` (`HmoveApply`)** is line 2 cycle 63 (the `WSYNC` write; the CPU waits to the end of line 2), and **`$F0C3` (`HmoveDone`)** is line 3 cycle 3: one `HMOVE` per frame, applied in HBLANK.
- **`$F0B1` (`P0XRead`)** reports A=`$49` (73) at frame 1, then 74, 75, … as the auto-demo moves right; **`$F0B9` (`P1XRead`)** reports `$68` (104) every frame.
- **`$F072` (`JoyLeft`)** under `-holdjoy0 L` reports A=`$48` (72), then `$47`, `$46`, … — the left branch and the `DEC`. **`$F07D` (`JoyRight`)** under `-holdjoy0 R` reports `$48`, then `$49`, `$4A`, … — the right branch and the `INC`.
- The auto-demo's 272-frame period is measurable from the `P0XRead` log: A=144 at frames 72 and 344, A=8 at frames 208 and 480.

The pixel checks decode the captures with the same mapping:

| Check | Capture | Measured | Expected |
|---|---|---|---|
| the figure's vertical box | `landscape.png` | y=580–629 (visible 150.2–165.7) | rows 150–165 |
| the figure's left box | `landscape.png` | x=103–150 (TIA X 13.0–20.8) | X=13, 8 pixels wide |
| the figure's right box | `figure-right.png` | x=877–924 (TIA X 142.0–149.8) | X=142, 8 pixels wide |
| the bird's lit box | both | x=655–690 (TIA X 105–110.8), y=302–332 (visible 61.9–71.4) | P1 at X=104; the 16-line slot is 60–75, the lit bytes are 62–71 |
| the left wall's inner (pass) edge at X=4e | `landscape.png` | 74 of 84 rows match the edge table exactly; the other 10 are within one chunk (the timing model's windows are row 8 and the `PF2` rows 42/48/54; the rest are at the one-chunk threshold) | the `e` table |
| the mountain colour at X=2 | `landscape.png` | `$0A`→RGB(186,186,185), `$0C`→(210,210,209), `$C0`→(0,57,0), `$C2`→(19,91,18), `$C4`→(40,121,39), `$C6`→(61,151,60) | the six 16-row bands |
| the sky at X=79 | `landscape.png` | `$84`→(36,40,176), `$86`→(55,61,193), `$88`→(73,81,209), `$78`→(116,81,208), `$6E`→(208,130,251), `$5E`→(234,130,220), `$4E`→(253,134,133), `$3E`→(253,181,104), `$2E`→(234,194,84), `$26`→(173,111,38), `$1A`→(205,205,52) | the eleven sky bands |

The screenshot proves the visual state; the state log proves the values and the lines. Neither one alone is the whole claim. The one thing the screenshots cannot prove is the 62/63 ledger; that is a static count, and the row counter's two-scanline spacing is the timing evidence.

## Exercises

### Exercise 1: Unroll Two Rows

**Challenge:** duplicate the row body inside the loop and iterate two rows per pass. The picture must be visually identical, the loop must use four `WSYNC`s per iteration, and `KernelRow` must advance by two.

**Hints:**
1. The second body reads the same tables with a `+1` offset: `LDA P0Strip+1,Y`, `LDA MtnPF0+1,Y`, and so on. The tables are 96 bytes, so `Y+1` stays inside the page for `Y=0..94` and the loads cost the same 4 cycles.
2. The shared tail is `INY` (2) + `INY` (2) + `CPY #96` (2) + `BNE` (3) = 9 cycles. Two increments are needed because the row counter advances by two.
3. The second body's labels are `RowWrite2` and `BirdWrite2`; the first body keeps `RowWrite` and `BirdWrite`.
4. The loop runs 48 times (Y=0,2,…,94) and draws 48 × 4 = 192 scanlines.

**Expected Result:** visually identical to the base mountain pass — the same colours, figure, and bird; the unrolled body shifts the store phase, so the first-scanline lag pattern differs (odd rows are cleaner at the `PF1`/`PF2` edges and have a shorter sky lag; even rows can show the bird's left 5 pixels one line late). `KernelRow` reports Y=0,2,4,…94; `RowWrite` and `RowWrite2` report the two bodies' bytes; `OverscanStart` is still 229. The ledger is **120 cycles per four scanlines**: two 55-cycle row bodies plus the 10-cycle shared tail (two `INY`s, `CPY #96`, the taken `BNE` and its page cross). The 2-line budget for four lines is 304, so 120 leaves 184 cycles of margin — 46 per line; the unroll saves 6 cycles over two separate 63-cycle pairs. The solution assembles to exactly 4,096 bytes.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Two Pixels per Frame

**Challenge:** move the figure two pixels per frame instead of one, with the same clamp (TIA X 8–144). The picture must stay stable and the frame must still use one `HMOVE`.

**Hints:**
1. Add `P0_STEP = 2` and replace the `DEC P0X` / `INC P0X` with `SEC/SBC #P0_STEP` and `CLC/ADC #P0_STEP`.
2. Clamp after the arithmetic: if the subtraction borrows below `P0_MIN`, store `P0_MIN`; if the addition reaches `P0_MAX+1`, store `P0_MAX`. Starting at 72 and stepping by 2 keeps every position even, so the limits are hit exactly.
3. The auto-demo uses the same step. At a limit it flips the direction and parks at `P0_MAX-2` or `P0_MIN+2` on the turn frame.
4. `P0XRead` is the checkpoint: the log starts at 74 and steps 76, 78, … under the right joystick (the power-on value is 72).

**Expected Result:** the figure moves two pixels per frame, the joystick clamp is still 8–144, and `HmoveDone` fires once per frame. `P0XRead` reports a step of 2. The solution assembles to exactly 4,096 bytes.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Three Copies *(Stretch Goal)*

**Challenge:** set `NUSIZ0=3` so the figure appears three times at X, X+16, and X+32. Clamp X to 8–120 so all three copies stay on screen, and keep the bird on P1.

**Hints:**
1. `NUSIZ0=3` is three close copies: X, X+16, X+32. The TIA repeats the same `GRP0` byte; the kernel does not change.
2. The right clamp is 120 because the third copy's last pixel is at `X+32+7 = X+39`; `X=120` puts it at 159, the last visible pixel. `X=121` would put it at 160, off screen.
3. Leave `P1X=104` and `NUSIZ1=0`; the bird is still one 8-pixel copy.
4. The state log reports `P0X` clamped to 8–120; the capture should show three red figures 16 pixels apart.

**Expected Result:** three 16-line red figures at X, X+16, and X+32, clamped to X=8–120; the bird still on P1; the same 96-row, 63-effective kernel; `OverscanStart` 229. The solution assembles to exactly 4,096 bytes.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A 2-line kernel writes one byte per two scanlines.** 96 bytes cover the 192-line screen, and the pair has 152 cycles instead of the 1-line kernel's 76.
- ✅ **The row body is 62 cycles nominal, 63 effective.** Seven 7-cycle load/store pairs (49), two `WSYNC`s (6), a 7-cycle nominal tail, and the taken-branch page cross (+1); the pair leaves 89 cycles of margin, 44.5 per scanline.
- ✅ **The second scanline is a free work window.** The first `WSYNC` ends line 1; the second waits out line 2. The simple kernel leaves the 89 cycles empty; a game can use them.
- ✅ **The store order is a beam race.** The visible area starts at cycle 22.67; the first store lands at about cycle 14. `GRP0` goes first because the figure can be at X=8; `PF0`/`PF1` follow; the colour and inner-PF2 stores land in the visible area, and the second scanline is always correct.
- ✅ **One HMOVE positions both players.** Set both `RESxx` and both `HMxx`, one `WSYNC`, one `HMOVE`; the fine values apply together in HBLANK.
- ✅ **The joystick mapping is fixed by the hardware.** Active-low `SWCHA` bits: after `AND #$C0`, left reads `$80` and right reads `$40`; map `$80` to `DEC` and `$40` to `INC`.
- ✅ **The data is the picture.** Three PF planes, two colour ramps, and two sprite strips; 672 bytes of ROM produce a 192-line scene, and the page-aligned tables keep every `LDA table,Y` at 4 cycles.

## What's Next

The mountain pass is one full-screen kernel. Real games divide the screen into zones and reuse the players: a score at the top, a status bar, a play area, and a ground line. [Lesson 50: Multi-Zone Kernel — Scoreboard + Playfield + Sprites](/part7-kernel-mastery/50-multi-zone-kernel) splits the 192 lines into `9 + 8 + 174 + 1`, reuses the 48-pixel score library, and adds a second `HMOVE` in the status HBLANK.
