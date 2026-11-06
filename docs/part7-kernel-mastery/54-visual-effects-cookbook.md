---
title: "Lesson 54: Visual Effects Cookbook — Starfields, Rainbows, Pseudo-3D"
description: "Build three full-screen Atari 2600 effects on one 4K cartridge — a scrolling starfield with three one-pixel stars, a full-height rainbow with a playfield sun, and a centred pseudo-3D road with a width pulse — and measure what each effect costs per scanline."
prev:
  text: "Lesson 53: Kernel Design Patterns — Building Your Toolkit"
  link: "/part7-kernel-mastery/53-kernel-patterns"
next:
  text: "Lesson 55: Scrolling Text Marquee — The Activision Logo Effect"
  link: "/part7-kernel-mastery/55-scrolling-text-marquee"
---

# Lesson 54: Visual Effects Cookbook — Starfields, Rainbows, Pseudo-3D

> **Part 7: Kernel Mastery** · Estimated time: 120 minutes
> **Prerequisites:** Lesson 12 (the NTSC frame), Lesson 13 (colors), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 18 (mid-scanline changes), Lesson 19 (the playfield), Lesson 20 (playfield colors and priority), Lesson 24 (the multicolor playfield), Lesson 25 (players), Lesson 26 (positioning), Lesson 28 (two players and one `HMOVE`), Lesson 29 (the ball and missiles), Lesson 31 (`NUSIZ`), Lesson 48 (the kernel taxonomy), Lesson 52 (fine scrolling)
> **You will learn:** how a sparse playfield plane becomes a starfield; how a colour ramp becomes a rainbow; how a reflected playfield becomes a centred pseudo-3D road whose width is the only free axis; how an effects registry and a 240-frame clock tie three kernels together; and the measured per-line cost of each effect
> **You will build:** "the effects reel" — a 4,096-byte ROM with three full-screen effects: a starfield of three page-aligned 256-byte planes scrolled one line every two frames, a 16-line ship, and three one-pixel stars on the ball and missiles; a rainbow written from a 192-entry `COLUBK` window with a centred playfield sun and a black horizon; and a pseudo-3D road whose base width grows from 4 to 12 chunks and whose 64-entry pulse takes it to 16 at the bottom, with a 16-line car. Fire advances the effect, SELECT returns to the starfield, and an auto-demo cycles every 240 frames; plus three exercise solutions: a per-star twinkle mask, a rainbow twice as fast, and a one-pixel ball centre line

## Introduction

Lesson 52 ended with one kernel drawing one scrolling world. Lesson 53 packaged the recurring kernel shapes into a library and stacked four bands. Both lessons drew a single picture. A real 2600 cartridge usually needs several *complete* pictures — a title screen, a game screen, a demo — and each one has to fill all 192 visible lines with its own data and its own cycle budget. This lesson builds three such pictures and puts them on a reel.

The three effects are chosen because they are the three ways a 2600 screen can be built from the hardware's limited registers. The **starfield** is a playfield: three page-aligned planes hold a sparse pattern, one byte per world row, and scrolling is one index. The **rainbow** is a colour: one `COLUBK` write per line, with the playfield used as a sun block. The **road** is a width: the reflected playfield is symmetric about the screen centre, so a centred road cannot move sideways, but its *width* can grow toward the bottom and breathe with a pulse. Each effect is a full 192-line frame, and each has a different cost per line.

The companion program `54-visual-effects-cookbook.asm` is **the effects reel**. Its `Effect` byte selects the kernel: 0 is the starfield, 1 is the rainbow, 2 is the road. An `EffectTimer` advances the effect every 240 frames, fire advances it immediately, and SELECT returns to the starfield. All three animation clocks run every frame, so an effect is never frozen while it is off screen. Three exercise solutions extend the reel: a per-star twinkle mask, a rainbow that shifts every two frames, and a one-pixel ball centre line that follows the road's width pulse.

::: details TypeScript Equivalent

An effects reel is a registry of renderers and a clock. In TypeScript the shape is a small interface and an array:

```typescript
interface Effect {
  readonly name: string;
  /** Advance this effect's own state by one frame. */
  update(): void;
  /** Draw one frame. On the 2600 this writes TIA registers, line by line. */
  draw(): void;
}

const starfield: Effect = {
  name: "starfield",
  update() { if (++starTimer % 2 === 0) starScroll++; },
  draw() { /* one WSYNC per visible line, three PF writes per line */ },
};

const rainbow: Effect = {
  name: "rainbow",
  update() { if (--rainbowTimer === 0) { rainbowShift = (rainbowShift + 1) & 63; rainbowTimer = 4; } },
  draw() { /* one COLUBK write per line */ },
};

const road: Effect = {
  name: "road",
  update() { widthIndex = (++roadScroll >> 1) & 63; },
  draw() { /* one PF write per line, with the width pulse */ },
};

const effects: Effect[] = [starfield, rainbow, road];
let current = 0;
let timer = 240;

function frame(): void {
  for (const effect of effects) effect.update(); // every clock runs every frame
  effects[current].draw();
  if (--timer === 0) {
    current = (current + 1) % effects.length;
    timer = 240;
  }
}
```

The analogy breaks in four places, and each one is a 2600 constraint rather than a coding preference. There is no framebuffer: `draw()` is not a function that fills an array and returns, it is code that runs *while the television beam moves down the screen*, and a write that lands after the beam has passed its pixels has no effect on this frame. The tables are ROM bytes read by indexed loads, not JavaScript arrays; the star world is 768 bytes and the road's PF2 plane is another 192, all page-aligned so an index never crosses a page. The registry is a compare chain in `VBLANK`, not a data structure: `LDA Effect / CMP #1 / BEQ …` costs six cycles, while a runtime dispatch table would cost more and still have to jump into a kernel written for a fixed address. And the frame clock is exact: 192 visible lines, 76 CPU cycles each, and the auto-demo's 240 frames are 240 real vertical blanks.

:::

## Theory

### Section 1: Three Effects, One Frame

Every effect in this lesson is a **192-line kernel** and shares the same frame:

| Zone | Lines | What runs there |
|---|---|---|
| `VSYNC` | 3 | `+vsync` |
| `VBLANK` | 37 | beep clock, fire/SELECT, effect clock, animation clocks, effect setup, one `HMOVE` |
| picture | 192 | the selected effect's kernel, one `WSYNC` per line |
| overscan | 30 | `+set_timer 36` and the next frame |
| **total** | **262** | NTSC |

The three effects differ in what they write per line:

| Effect | Per-line data | Objects | Kernel shape |
|---|---|---|---|
| **0 — starfield** | one byte from each of three 256-byte planes | P0 ship (16 rows), ball + 2 missiles as 1-px stars | 3 PF pairs + 3 enable pairs + P0 (16 rows) |
| **1 — rainbow** | one byte from a 192-entry `COLUBK` window | none (the sun and horizon are playfield) | one `LDA`/`STA COLUBK` pair |
| **2 — road** | one byte from a 192-byte `PF2` plane | P0 car (16 rows) | PF2 + width pulse + P0 (16 rows) |

The reel is a **state machine**: `Effect` is the selected renderer, `EffectTimer` is the clock, and the three animation counters keep running whichever renderer is selected. That last decision is deliberate. If an effect's clock stopped while it was off screen, a return to it would show a frozen picture; running all three clocks costs about sixty cycles per frame in `VBLANK` and makes every effect continuous.

The frame's checkpoints are the same as every Part 7 lesson: `StartFrame` at scanline 259, `VblankStart` at 0, `BodyStart` at 37 and `OverscanStart` at 229. The state log in "What You Should See" measures all four and the 192-line total.

::: tip One `HMOVE` per effect frame
The starfield positions P0, the ball and the two missiles; the road positions P0. Each of those effects sets every coarse `RESxx` and every `HMxx` value first, then strobes **one** `HMOVE` in `VBLANK`. The rainbow positions no player object, so it has no `HMOVE` at all. The state log shows that pattern: one hit per frame during effects 0 and 2, none during effect 1.
:::

### Section 2: The Starfield — Three Planes and One Index

A starfield is a sparse pattern of dots on a dark background. On the 2600 the natural place to put it is the playfield: 20 chunks per half, each chunk four pixels wide, mirrored by `CTRLPF=$01`. The playfield has no vertical resolution of its own — it shows whatever the three registers hold until you write them again — so a starfield needs one byte per plane per scanline.

The lesson stores the star world in **three page-aligned 256-byte planes**: `StarPF0`, `StarPF1` and `StarPF2`. Row *r* of the world is the byte at `StarPF0+r`, `StarPF1+r` and `StarPF2+r`. The screen shows 192 of the 256 rows at a time, starting at `StarScroll`:

```asm
    LDX StarScroll
    LDY #0
StarRow:
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    LDA StarBall,Y
    STA ENABL
    LDA StarM0,Y
    STA ENAM0
    LDA StarM1,Y
    STA ENAM1
    ...
    STA WSYNC
    INX                 ; 255 -> 0 inside the page
    INY
    CPY #SHIP_TOP
    BNE StarRow
```

`X` is the world row and `Y` is the visible row. Both advance together, so the same world row feeds all three planes. The planes are page-aligned, which is what makes the `INX` wrap free: when `X` passes 255 it becomes 0 and the next line reads the top of the same page, so the world is a seamless loop. The first loop stops at `Y=176`; a second copy of the same shape draws rows 176–191 and adds the ship. The star field scrolls one row every two frames: `StarScroll` increments on every second frame, and the whole picture moves up one scanline.

The star pattern is sparse by construction. Each plane byte is a set of chunk bits; a bit is a four-pixel star. The three planes cover different chunks: `PF0` bits 4–7 are chunks 0–3, `PF1` bits 7–0 are chunks 4–11, and `PF2` bits 0–7 are chunks 12–19. A star at chunk 19 sits next to the reflection axis and appears twice as an eight-pixel pair (chunk 19 and its mirror 20); that is the widest a "star" can look. The three planes hold about sixty stars in the default pattern, which the reflection doubles.

**The three one-pixel stars.** The playfield's minimum star is four pixels wide. For a true one-pixel star the lesson uses the three objects that can be one pixel wide: the ball and the two missiles. Each is positioned once per frame with the divide-by-15 dance and one `HMOVE`, then enabled on exactly one line:

```asm
    LDA StarBall,Y
    STA ENABL               ; the ball's star, row 32
    LDA StarM0,Y
    STA ENAM0               ; missile 0's star, row 96
    LDA StarM1,Y
    STA ENAM1               ; missile 1's star, row 160
```

Instead of a clear-and-compare chain, the lesson keeps one 192-byte enable table per star: `StarBall`, `StarM0` and `StarM1` hold `$02` on the star's row and `$00` everywhere else. Every row writes all three latches, so a zero clears the previous line's star and a `$02` sets this line's. The three stores complete at cycles 37, 44 and 51 (`StarBallWrite`, `StarM0Write`, `StarM1Write`), long before the stars' pixels at `X=112`, `128` and `144` (cycles 60, 65 and 71). The measured positions are 111, 127 and 143; the one-pixel difference is the ball and missile output delay, one colour clock shorter than the player's.

The three star rows are fixed at 32, 96 and 160. The tables hold 576 bytes of data, each on its own page; the page-alignment padding brings the ROM cost to 704 bytes, and they use no RAM. Every row pays 21 cycles for the three table pairs, so the starfield's measured ledger is 54 cycles on a plain or star row and 62 on a ship row; the old clear, the three compares and the single set cost 26 cycles on every row and 31 on a star row.

**The ship.** P0 draws a 16-byte ship at rows 176–191. The load address is `ShipShape - SHIP_TOP + Y`, so `Y` in 176..191 reads `ShipShape` 0..15 without a second index:

```asm
StarShipRow:
    LDA StarPF0,X
    STA PF0
    ...
    LDA ShipShape - SHIP_TOP,Y
    STA GRP0
    ...
    CPY #SCREEN_LINES
    BNE StarShipRow
```

The first loop stops at row 176, so the second loop needs no ship gate: it writes `GRP0` unconditionally for its 16 rows. The store is latched by cycle 39 (`ShipWrite`; the first ship row at 37), before the ship's left edge at `X=76` (cycle 48), so all 16 lines are visible. `GRP0` is cleared in `VBLANK` every frame, so the ship does not leak into the top of the next frame. A capture of the fixed ROM measures the ship at visible rows 176–191.

::: warning The enable store is a deadline, not a formality
A one-pixel star is visible only if its enable is latched before the beam reaches its X. The lesson's first draft used a clear-and-compare chain; its compare stores landed around visible pixels 94–118, so a star at X=96 was missed. The enable tables write all three latches at cycles 37/44/51 (visible pixels 43/64/85), so the stars at X=112/128/144 have margin. When you add a star of your own, either keep it to the **right** of the enable store or move the store earlier in the line.
:::

### Section 3: The Rainbow — A Window on a Colour Ramp

The rainbow is the simplest of the three effects and the one that shows the 2600's colour hardware most directly. It is one `COLUBK` write per line:

```asm
RainbowRowA:
    LDA (RampLo),Y
    STA COLUBK
    STA WSYNC
    INY
    CPY #SUN_TOP
    BNE RainbowRowA
```

That is 18 cycles per line: the indirect load (5), the store (3), `WSYNC` (3) and the loop tail (2 + 2 + 3). The 76-cycle line leaves 58 cycles of margin, which is why the rainbow can afford four separate loops and a boundary store on the sun and horizon lines.

**The ramp.** `Rainbow` is 16 hues × 12 lines at luminance 7: `$0E` (white), `$1E` (gold), `$2E`, `$3E`, and so on to `$FE`. Twelve lines per hue gives a 192-entry ramp, exactly one screen. The table is stored as **192 entries plus the first 64 repeated**, so a 192-entry window that starts at any offset 0..63 stays contiguous:

```asm
Rainbow:
    !fill 12, $0E
    !fill 12, $1E
    ...
    !fill 12, $FE
    ; the first 64 entries again:
    !fill 12, $0E
    !fill 12, $1E
    !fill 12, $2E
    !fill 12, $3E
    !fill 12, $4E
    !fill 4,  $5E
```

The pointer is computed in `VBLANK`: `RampLo/RampHi = Rainbow + RainbowShift`. `RainbowShift` runs 0..63 and advances every four frames, so the whole colour wheel drifts up the screen one entry every four frames. The table is page-aligned, and the window's longest read is 63 + 191 = 254, so the indirect load never crosses a page.

**The sun.** The sun is a playfield block, not a ball. A centred 32-pixel block is four chunks per half: chunks 16–19, which is `PF2 = $F0` (`$F0` = bits 4–7 = chunks 16, 17, 18, 19; the reflection draws chunks 20–23 as the mirror). It covers visible rows 40–88 and is coloured by `COLUPF = $1A` (gold). The choice of playfield is forced by two facts, not by colour: the ball is at most eight pixels wide, six chunks short of the 32-pixel sun (two chunks short of its 16-pixel half), and the starfield needs the ball for one of its three one-pixel stars. Colour is not the obstacle — the ball shares `COLUPF`, which is the sun's gold here — but width and object count are.

**The horizon.** The bottom 32 rows are a full-width black band. A full-width band needs all three playfield bytes: `PF0=$FF`, `PF1=$FF`, `PF2=$FF`, with `COLUPF=$00`. The three stores are ordered `COLUPF` first (it must beat pixel 0), then `PF0`, `PF1`, `PF2`. `PF0`'s field starts at pixel 0 and its store completes after the deadline, so the very first horizon line shows about seven pixels of row 159's colour at the far left; from the next line the band is solid. The lesson shows the sliver rather than hiding it, because it is the same pixel-deadline arithmetic every boundary in the course uses.

**The four loops.** Rows 0–39 are plain, row 40 starts the sun, rows 41–88 are the sun, row 89 ends it, rows 90–159 are plain, row 160 starts the horizon, and rows 161–191 are black. The boundaries are rows where the loop draws its first row and then stores the new `PF2`/`COLUPF` before `WSYNC`. The measured cost of those boundary lines is 27, 22 and 33 cycles — all far inside 76.

### Section 4: The Pseudo-3D Road — Width Is the Only Axis

The road is the lesson's most interesting constraint. The playfield is 20 chunks per half and `CTRLPF=$01` mirrors the right half. A row of three playfield bytes is therefore always **symmetric about the screen centre**: the mirror is the hardware's, not the data's. You cannot move the road's centre sideways with a 3-byte reflected row, and no amount of table data changes that. What you *can* change is the width.

The road's data is one page-aligned 192-byte plane, `RoadPF2`. The road lives entirely in `PF2` at these widths: its lit range is chunks `(20-h)`..19, where `h` is the half-width in chunks, and `PF2` covers chunks 12–19. The base half-width is

```
h(row) = 2 + round(4 * row / 191)
```

so the base road is 4 chunks wide at the horizon and 12 at the bottom (`h = 2..6`). `PF0` and `PF1` are zero on every row, so the setup clears them once and the kernel never stores them. The 192-byte plane is page-aligned, so `Y` never crosses a page, and the 16-chunk maximum is exactly `PF2`'s eight chunks per half.

**The width pulse.** On top of the base, a 64-entry table adds 0, 1 or 2 chunks per half:

```
PulseTable:  0 x 8, 1 x 16, 2 x 16, 1 x 16, 0 x 8
```

`RoadScroll` increments every frame, and every second frame `WidthIndex = (RoadScroll >> 1) & 63` steps through the table. The kernel applies the pulse to the `PF2` byte by shifting it and OR-ing the result with the unshifted byte:

```asm
    LDA RoadPF2,Y
    STA PFTemp
    LDX PulseAmt
    BEQ RoadPulseDone
    LSR
    ORA PFTemp
    DEX
    BEQ RoadPulseDone
    LSR
    ORA PFTemp
RoadPulseDone:
    STA PF2
```

A right shift of the mask moves its top bit down one chunk; OR-ing the original restores the top bit and adds the new lower chunk at the road's **outer** edge. One shift widens the road by one chunk per half; two shifts by two. At the bottom of the screen the base `$FC` (6 half-chunks) becomes `$FF` (8) — the full 16 chunks. At the horizon the base `$C0` (2) becomes `$F0` (4), so the top of the road breathes between 4 and 8 chunks. The measured ledgers are 26/35/39 cycles on a plain line and 34/43/47 on a car line for pulse 0/1/2; the 76-cycle line leaves 29 cycles of margin on the worst line.

**The car.** P0 draws a 16-byte car at rows 176–191, at X=76. The kernel stores `PF2` first: its field starts at pixel 48, and the pulse's longest path is latched by cycle 36 (38 in exercise 3 with the centre-gap mask), before the beam reaches chunk 12. The car follows in a second bottom loop, so its `GRP0` store completes at cycle 43 (45 in exercise 3), before its left edge at X=76 (cycle 48). Splitting the loop removes the `CPY #CAR_TOP` gate from the 176 road rows, and the setup preloads the first row's `PF2` so the very first line is unambiguous.

**Why not a curve?** A road that turns would need asymmetric playfield rows. The 2600 supports that with `CTRLPF=$00` (repeat instead of reflect) and a 20-bit half, but then the *whole* screen is asymmetric and the road cannot be centred by construction. The lesson's road is centred and straight; its "3D" is the width profile, and its motion is the pulse. Exercise 3 adds a one-pixel centre line in the road's centre gap and makes it follow the pulse.

::: tip The reflection axis is the road's centre
Chunk 19 is the last chunk of the left half and chunk 20 is its mirror. The screen centre is the boundary between them, at TIA X=80. A centred road is symmetric about that line, and its centre pixel is at X=79/80. The car's left edge is at X=76, so the eight-pixel car straddles the centre.
:::

### Section 5: The Effects Registry and the 240-Frame Clock

The reel's state machine is three bytes and a compare chain. `Effect` (0, 1 or 2) is the selected renderer, `EffectTimer` counts down from 240, and `Effect` advances when it reaches zero:

```asm
    DEC EffectTimer
    BNE NoAutoEffect
    JSR AdvanceEffect
    LDA #EFFECT_PERIOD
    STA EffectTimer
NoAutoEffect:
```

`AdvanceEffect` adds one, compares against 3 and wraps to 0. Fire advances the effect on the 0→1 edge and reloads the timer, so a manual change gets a fresh 240-frame window. SELECT returns to effect 0 and also reloads. The fire detector is the Lesson 48 idiom: `INPT4` bit 7 is 0 while the button is held, `EOR #$80` turns that into a 1, and `EOR PrevFire / AND NewFire` keeps only a new press. The first eight frames are ignored because `INPT4` can read low while the console settles; `Startup` forces the edge clear until it reaches zero.

The auto-demo's 240-frame clock starts at power-on and advances at frames 240, 480 and 720. Each effect therefore owns four seconds, and the three effects cycle in twelve. The state log shows `EffectStep` with A=1 at frame 240, A=2 at 480 and A=0 at 720.

**All clocks run every frame.** The three animation counters are updated before the dispatch:

| Counter | Rate | Range | What it drives |
|---|---|---|---|
| `StarScroll` | every 2 frames | 0–255 | the star world's top row |
| `Twinkle` | every 32 frames | 0/1 | white or gold stars |
| `RainbowShift` | every 4 frames | 0–63 | the colour window's first entry |
| `RoadScroll` | every frame | 0–255 | the road's animation clock |
| `WidthIndex` | every 2 frames | 0–63 | the pulse table's index |

`Twinkle` is a separate 32-frame clock: it toggles `StarColor` between `$0E` (white) and `$1A` (gold). `COLUPF` drives the playfield and the ball, and `COLUP1` drives missile 1, so those three change together. Missile 0 is wired to `COLUP0`, which stays white, so the row-96 star is the one that does not twinkle. The base lesson has no per-star mask; exercise 1 adds one.

**The beep.** Both manual changes call `BeepStart`: `AUDC0=$0C`, `AUDF0=BeepPitch` ($08), `AUDV0=$0A`, and `BeepTimer=2`. The `VBLANK` clock decrements `BeepTimer` every frame and writes `AUDV0=0` at zero, so the beep lasts two frames. The auto-demo is silent; only a fire or SELECT press beeps.

### Section 6: The Cycle Ledgers

The 76-cycle line is the budget, and the lesson's three effects spend it very differently. The figures below are measured with the state log, not estimated: the kernel's row label reports the cycle at the start of the line, the `…Wait` label reports the cycle where the `WSYNC` store begins, and the work is `(wait − row start) + 3 + tail`.

**Starfield** — `StarRow` starts at cycle 9, the ship loop's `StarShipRow` at 10; tail 9 (INX, INY, CPY, BNE):

| Line | `…Wait` starts | Work |
|---|---|---|
| plain or star row | 51 | 54 |
| ship row (176–191) | 60 | 62 |

The three playfield pairs are 21 cycles; the three enable-table pairs are another 21; the ship pair adds 7. The ship loop's row label starts one cycle later than the top loop's (10 vs 9), so its measured work is 62. The worst line leaves 14 cycles of margin.

**Rainbow** — row start cycle 7, tail 7:

| Line | `…Wait` starts | Work |
|---|---|---|
| plain row | 15 | 18 |
| sun boundary (row 40) | 24 | 27 |
| sun-end boundary (row 89) | 19 | 22 |
| horizon boundary (row 160) | 30 | 33 |

The rainbow has the most margin of the three — 58 cycles on a plain line (76 − 18).

**Road** — row start cycle 7, tail 7:

| Line | pulse 0 | pulse 1 | pulse 2 |
|---|---|---|---|
| plain row | 26 | 35 | 39 |
| car row | 34 | 43 | 47 |

The pulse's two shifts cost 9 and 4 cycles over the unshifted path; the car's `LDA`/`STA` pair adds 8. The worst line is 47, leaving 29 cycles. Exercise 3's centre-gap mask adds two cycles, so its worst line is 49.

The three ledgers explain the effect design. The starfield spends its budget on *objects* (three one-pixel stars and a ship), the road spends it on *data* (the pulse), and the rainbow spends almost nothing because a colour write is one store. A full-screen effect is not automatically expensive; the cost is in what changes per line.

### Section 7: Reading It in Stella

The reel is a state machine with three layers, and the debugger shows all three:

- **The frame:** `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/11 (starfield), 229/6 (rainbow), 229/9 (road). The scanlines prove the 262-line frame and the 192-line picture; the cycles differ per kernel and are recorded, not required.
- **The effect clock:** `EffectRead` reports A=0, 1 or 2 every frame; `EffectTimerRead` reports 239, 238, …; `EffectStep` reports the new effect at frames 240, 480 and 720. Under `-holdselect`, `SelectReset` reports A=0 at frame 1.
- **The animation:** `StarScrollRead` 0, 1, 1, 2, 2, …; `RainbowShiftRead` 0, 0, 0, 1, 1, …; `RoadScrollRead` 1, 2, 3, …; `WidthIndexRead` 0, 1, 1, 2, 2, …; `TwinkleStep` 1 at 32, 0 at 64, 1 at 96.
- **The objects:** `HmoveApply` 9/3 and `HmoveDone` 10/3 in the starfield; 4/59 and 5/3 in the road; no hits in the rainbow. `StarWait`, `StarShipWait`, `RoadWait`, `RoadCarWait` and the four rainbow waits are the cycle ledgers above.

A screenshot proves the picture; the state log proves the values, the lines and the cycles. The lesson uses both, and neither is asked to prove the other's claim.

## The Code

### Building This Lesson

```bash
# every lesson ROM, including this one:
npm run roms

# or just this one:
acme -f plain -o build/lesson54.bin \
  lessons/part7-kernel-mastery/54-visual-effects-cookbook/54-visual-effects-cookbook.asm

stella build/lesson54.bin
```

The three exercise solutions sit beside the lesson source. Each is a complete 4,096-byte ROM:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part7-kernel-mastery/54-visual-effects-cookbook/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part7-kernel-mastery/54-visual-effects-cookbook/exercise-02-solution.asm
acme -f plain -o build/exercise-03.bin \
  lessons/part7-kernel-mastery/54-visual-effects-cookbook/exercise-03-solution.asm
```

### Full Source

The complete annotated source is reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 54: Visual Effects Cookbook — Starfields, Rainbows, Pseudo-3D
; =============================================================================
; Part 7: Kernel Mastery
;
; What this program does:
;   "the effects reel": three full-screen effects, one per 192-line frame.
;
;     Effect 0 — the starfield.  Three page-aligned 256-byte star planes
;       (StarPF0/1/2).  Every visible line reads one byte from each plane at
;       the same world row (StarScroll + the visible row), so scrolling is
;       just incrementing StarScroll every two frames.  P0 draws a 16-line
;       ship at the bottom, and the ball and the two missiles add three
;       one-pixel stars at fixed rows.  The star colour alternates white $0E
;       and gold $1A every 32 frames (Twinkle).
;
;     Effect 1 — the rainbow.  A 192-entry COLUBK ramp (16 hues x 12 lines,
;       stored with a 64-byte repeat so a shifted 192-line window is always
;       contiguous) is written one line per line.  A centred playfield sun
;       block covers visible rows 40-88 (PF2=$F0 -> 32 pixels after the
;       reflection), and a black horizon covers rows 160-191 (all three PF
;       bytes $FF, so the band is full width).
;       RainbowShift advances the window one entry every four frames.
;
;     Effect 2 — the pseudo-3D road.  One page-aligned 192-byte playfield
;       plane (RoadPF2) holds a centred road whose base half-width grows
;       from 2 to 6 chunks (4 to 12 chunks wide) from the horizon to the
;       bottom.  A 64-entry width pulse (WidthIndex) adds up to two chunks
;       per half, so the widest bottom rows are the full 16 chunks wide.  P0
;       draws a 16-line car at the bottom.  The playfield is reflected
;       (CTRLPF=$01), so the road is symmetric about the screen centre and
;       cannot move sideways; the "3D" is the width profile.
;
;   EffectTimer 240: at zero the effect advances 0 -> 1 -> 2 -> 0 and the
;   timer reloads.  Fire advances immediately; SELECT returns to effect 0.
;   The auto-demo cycles every 240 frames, so every effect is reachable
;   without a key press.  A two-byte beep (BeepTimer/BeepPitch) sounds on
;   both manual changes.
;
;   All three animation clocks run every frame, whichever effect is on
;   screen, so a return to an effect finds it where it would have been.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;
; The kernels (work-first, one line per row, forward top-down):
;
;   Starfield   writes PF0/PF1/PF2 from the three planes at the same X,
;               then one 192-byte enable table per one-pixel star.  The
;               ship's GRP0 is written only in the bottom 16-row loop.  The
;               measured ledger is 54 cycles on a plain or star row and 62
;               on a ship row.  The enable stores complete at cycles
;               37/44/51 (before X=112/128/144 at 60/65/71), and the ship
;               store completes at cycle 39 (before X=76 at 48).
;
;   Rainbow     LDA (RampLo),Y / STA COLUBK / WSYNC / INY / CPY / BNE =
;               18 cycles per line.  The sun-start, sun-end and horizon
;               boundary lines cost 27, 22 and 33 cycles; all are inside 76.
;
;   Road        PF2 with up to two widening shifts of the 64-entry pulse,
;               then the car in a 16-row bottom loop, WSYNC and the tail.
;               The measured ledger is 26/35/39 cycles (pulse 0/1/2) on a
;               plain line and 34/43/47 on a car line.
;
;   Every plane is page-aligned: the star X wraps 255 -> 0 inside its page;
;   the road/rainbow indices stay inside a page because their windows are
;   at most 192 + 63 = 255 entries long, and the enable tables are
;   192 bytes each on their own page.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), OverscanStart (229);
;   EffectRead (A = 0/1/2); EffectTimerRead (A = 240 down to 0);
;   StarScrollRead, RoadScrollRead, WidthIndexRead, RainbowShiftRead (A =
;   the counter); TwinkleStep (A = the new 0/1 flag); StarRow (Y =
;   0..175); StarShipRow (Y = 176..191); RoadRow (Y = 0..175);
;   RoadCarRow (Y = 176..191); RainbowRowA (Y = the row); StarBallWrite/
;   StarM0Write/StarM1Write and ShipWrite (the object writes are latched);
;   HmoveApply (the WSYNC stall), HmoveDone (the store has executed).
;
; RAM map (+clean_start zeroes every byte):
;   $80 Effect        the current effect, 0..2
;   $81 EffectTimer   frames left before the auto-demo advances
;   $82 PrevFire      fire state last frame (1 = pressed)
;   $83 PrevSelect    SELECT state last frame (1 = pressed)
;   $84 BeepTimer     frames of beep remaining
;   $85 BeepPitch     AUDF for the beep
;   $86 Startup       frames left before the fire edge is trusted
;   $87 NewFire       this frame's fire 0 -> 1 edge
;   $88 Scratch       SELECT's pressed state
;   $89 StarScroll    the star world row at the top, 0..255
;   $8A StarTimer     the two-frame star scroll divider
;   $8B Twinkle       0 = white stars, 1 = gold stars
;   $8C TwinkleTimer  frames left before the star colour flips
;   $8D RainbowShift  the ramp window's first entry, 0..63
;   $8E RainbowTimer  frames left before the ramp shifts
;   $8F RoadScroll    the road's animation clock, 0..255
;   $90 WidthIndex    the pulse-table index, 0..63
;   $91 PulseAmt      the pulse shift count, 0..2
;   $92 RampLo        the rainbow window's low byte
;   $93 RampHi        the rainbow window's high byte
;   $94 StarColor     COLUPF for the stars: $0E or $1A
;   $95 PFTemp        the road's unshifted PF2 byte
;   $96-$F7 free (98 bytes)
;   $F8-$FF stack
;
; Build: acme -f plain -o build/lesson54.bin \
;        lessons/part7-kernel-mastery/54-visual-effects-cookbook/54-visual-effects-cookbook.asm
; Run:   stella build/lesson54.bin     (click the screen to unmute the beep)
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

SCREEN_LINES   = 192     ; every kernel draws 192 lines
EFFECT_STAR    = 0
EFFECT_RAINBOW = 1
EFFECT_ROAD    = 2
EFFECT_COUNT   = 3
EFFECT_PERIOD  = 240     ; frames per effect in the auto-demo

SHIP_TOP       = 176     ; the ship's first visible row
SHIP_LINES     = 16      ; 16 bytes, one line per byte
SHIP_X         = 76      ; the ship's left edge: the centre of the field

STAR0_ROW      = 32      ; the ball's one-pixel star
STAR1_ROW      = 96      ; missile 0's star
STAR2_ROW      = 160     ; missile 1's star
STAR0_X        = 112     ; all three sit right of the late enable store
STAR1_X        = 128
STAR2_X        = 144

SUN_TOP        = 40      ; the sun block's first row
SUN_BOTTOM     = 89      ; exclusive: rows 40..88
HORIZON_TOP    = 160     ; the black horizon's first row
SUN_PF         = $F0     ; PF2 chunks 16-19: 32 pixels after reflection
HORIZON_PF     = $FF     ; all three PF bytes: the full screen width

CAR_TOP        = 176     ; the car's first visible row
CAR_LINES      = 16
CAR_X          = 76
WIDTH_STEPS    = 64      ; the width-pulse table's length

TWINKLE_PERIOD = 32      ; frames per star colour
RAINBOW_PERIOD = 4       ; frames per rainbow step

C_BG           = $02     ; the space/field background
C_STAR_WHITE   = $0E
C_STAR_GOLD    = $1A
C_SHIP         = $0E     ; the ship and the car are white
C_ROAD         = $0C     ; the road surface: light grey
C_SUN          = $1A     ; the sun block: gold
C_BLACK        = $00     ; the horizon

BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright beep

; The region arithmetic is a build-time assertion, not a comment.
!if SUN_TOP >= SUN_BOTTOM {
    !error "the sun block must have at least one row"
}
!if SUN_BOTTOM >= HORIZON_TOP {
    !error "the sun must end before the horizon starts"
}
!if HORIZON_TOP >= SCREEN_LINES {
    !error "the horizon must start inside the picture"
}
!if SHIP_TOP + SHIP_LINES > SCREEN_LINES {
    !error "the ship must fit inside the picture"
}
!if CAR_TOP + CAR_LINES > SCREEN_LINES {
    !error "the car must fit inside the picture"
}

; =============================================================================
; RAM ALLOCATION ($80-$95; +clean_start zeroes every byte)
; =============================================================================
Effect        = $80   ; the current effect, 0..2
EffectTimer   = $81   ; frames left before the auto-demo advances
PrevFire      = $82   ; fire state last frame (1 = pressed)
PrevSelect    = $83   ; SELECT state last frame (1 = pressed)
BeepTimer     = $84   ; frames of beep remaining
BeepPitch     = $85   ; AUDF for the beep
Startup       = $86   ; frames left before the fire edge is trusted
NewFire       = $87   ; this frame's fire 0 -> 1 edge
Scratch       = $88   ; SELECT's pressed state
StarScroll    = $89   ; the star world row at the top, 0..255
StarTimer     = $8A   ; the two-frame star scroll divider
Twinkle       = $8B   ; 0 = white stars, 1 = gold stars
TwinkleTimer  = $8C   ; frames left before the star colour flips
RainbowShift  = $8D   ; the ramp window's first entry, 0..63
RainbowTimer  = $8E   ; frames left before the ramp shifts
RoadScroll    = $8F   ; the road's animation clock, 0..255
WidthIndex    = $90   ; the pulse-table index, 0..63
PulseAmt      = $91   ; the pulse shift count, 0..2
RampLo        = $92   ; the rainbow window's low byte
RampHi        = $93   ; the rainbow window's high byte
StarColor     = $94   ; COLUPF for the stars: $0E or $1A
PFTemp        = $95   ; the road's unshifted PF2 byte
;
; $96-$F7 are free (98 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (SetCoarseP0/BL/M0/M1, AdvanceEffect, BeepStart).

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
    STA SWACNT              ; port A is an input port (the joystick/fire)

    LDA #EFFECT_STAR
    STA Effect              ; power on with the starfield
    LDA #EFFECT_PERIOD
    STA EffectTimer
    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #$08
    STA Startup             ; ignore the fire line while the console settles
    LDA #TWINKLE_PERIOD
    STA TwinkleTimer
    LDA #RAINBOW_PERIOD
    STA RainbowTimer

    LDA #$00
    STA StarScroll
    STA StarTimer
    STA Twinkle
    STA RainbowShift
    STA RoadScroll
    STA WidthIndex
    STA PulseAmt
    LDA #C_STAR_WHITE
    STA StarColor           ; the first 32 frames are white

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; space is dark
    LDA #$01
    STA CTRLPF              ; reflect: the right half mirrors the left
    LDA #C_SHIP
    STA COLUP0              ; the ship and the car are white
    LDA #$00
    STA NUSIZ0              ; one 8-pixel P0; the missiles are 1 pixel
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
; 1. THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
; The same two-byte beep the rest of Part 6 and Part 7 uses: BeepTimer counts
; down every frame and channel 0 goes silent at zero.
    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — advance the effect on the 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1, and the
; EOR/AND pair keeps only a new press, so holding the button advances once.
; The first eight frames are not trusted: INPT4 can read low while the console
; settles, so Startup forces the edge clear until it reaches zero.
    LDA INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire             ; NewFire = pressed & ~wasPressed
    LDA Startup
    BEQ FireEdgeReady
    DEC Startup
    LDA #$00
    STA NewFire
FireEdgeReady:
    LDA NewFire
    BEQ NoFireEdge
    JSR AdvanceEffect
    LDA #EFFECT_PERIOD      ; a manual change restarts the auto-demo window
    STA EffectTimer
    JSR BeepStart
NoFireEdge:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; -----------------------------------------------------------------------------
; 3. SELECT — return to the starfield
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  The edge, not the level, resets the
; effect.  SELECT is also the capture helper: a capture can start from effect
; 0 without waiting for the auto-demo.
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelectEdge
    LDA #EFFECT_STAR
SelectReset:                ; checkpoint: A = 0, the new effect
    STA Effect
    LDA #EFFECT_PERIOD
    STA EffectTimer
    JSR BeepStart
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 4. THE AUTO-DEMO'S EFFECT CLOCK — one effect every 240 frames
; -----------------------------------------------------------------------------
    DEC EffectTimer
    BNE NoAutoEffect
    JSR AdvanceEffect
    LDA #EFFECT_PERIOD
    STA EffectTimer
NoAutoEffect:
    LDA EffectTimer
EffectTimerRead:            ; checkpoint: A = 240 down to 0
    NOP

; -----------------------------------------------------------------------------
; 5. THE ANIMATION CLOCKS — all three run every frame
; -----------------------------------------------------------------------------
; Each effect keeps its own state, so switching away and back does not reset
; the motion.  The clocks are cheap and the VBLANK has room for all of them.
    INC StarTimer
    LDA StarTimer
    AND #$01
    BNE NoStarStep
    INC StarScroll
NoStarStep:
    LDA StarScroll
StarScrollRead:             ; checkpoint: A = the star world row
    NOP

    DEC TwinkleTimer
    BNE NoTwinkle
    LDA #TWINKLE_PERIOD
    STA TwinkleTimer
    LDA Twinkle
    EOR #$01
    STA Twinkle
    TAX
    LDA TwinkleColors,X
    STA StarColor
    TXA
TwinkleStep:                ; checkpoint: A = the new 0/1 flag
    NOP
NoTwinkle:

    DEC RainbowTimer
    BNE NoRainbowStep
    LDA #RAINBOW_PERIOD
    STA RainbowTimer
    INC RainbowShift
    LDA RainbowShift
    AND #$3F
    STA RainbowShift
NoRainbowStep:
    LDA RainbowShift
RainbowShiftRead:           ; checkpoint: A = the ramp window's first entry
    NOP

    INC RoadScroll
    LDA RoadScroll
    LSR                     ; one pulse step every two frames
    AND #WIDTH_STEPS - 1
    STA WidthIndex
    TAX
    LDA PulseTable,X
    STA PulseAmt
    LDA WidthIndex
WidthIndexRead:             ; checkpoint: A = the pulse-table index, 0..63
    NOP
    LDA RoadScroll
RoadScrollRead:             ; checkpoint: A = the road's animation clock
    NOP

; -----------------------------------------------------------------------------
; 6. DISPATCH — one setup path per effect
; -----------------------------------------------------------------------------
; Every path ends with its own +wait_timer / VBLANK-off / kernel entry, so
; the VBLANK-off store completes at cycle 5 of scanline 37; the first data stores follow at cycle 9 (star) or 7 (road).  GRP0
; is cleared here every frame: the ship and the car write only the bottom 16
; rows, so without this clear the last byte would show at the top of the
; next frame as a thin vertical line.
    LDA #$00
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    LDA Effect
EffectRead:                 ; checkpoint: A = the current effect, 0/1/2
    CMP #EFFECT_RAINBOW
    BEQ SetupRainbow
    CMP #EFFECT_ROAD
    BEQ SetupRoad

; --- effect 0: the starfield -------------------------------------------------
SetupStar:
    LDA #C_BG
    STA COLUBK
    LDA StarColor
    STA COLUPF              ; the playfield stars and the ball
    STA COLUP1              ; missile 1's one-pixel star
    LDA #C_SHIP
    STA COLUP0              ; the ship and missile 0's star are white
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    ; One HMOVE applies every object's fine offset.  The four coarse resets
    ; come first; the ship and the three one-pixel stars are positioned here.
    LDA #(SHIP_X + POS_BIAS)
    JSR SetCoarseP0
    LDA #(STAR0_X + POS_BIAS)
    JSR SetCoarseBL
    LDA #(STAR1_X + POS_BIAS)
    JSR SetCoarseM0
    LDA #(STAR2_X + POS_BIAS)
    JSR SetCoarseM1
    JMP DoHmove

; --- effect 2: the road ------------------------------------------------------
SetupRoad:
    LDA #C_BG
    STA COLUBK
    LDA #C_ROAD
    STA COLUPF              ; the road surface is light grey
    LDA #C_SHIP
    STA COLUP0
    LDA #$00
    STA PF0                 ; the road never lights PF0
    STA PF1                 ; or PF1: both planes are zero on every row
    STA PF2
    ; Preload the first row's PF2.  The kernel stores PF2 first, so its
    ; first store also beats chunk 12; the preload keeps the very first
    ; line unambiguous and gives the setup a single path for the pulse.
    LDA RoadPF2
    STA PFTemp
    LDX PulseAmt
    BEQ RoadPreloadDone
    LSR
    ORA PFTemp
    DEX
    BEQ RoadPreloadDone
    LSR
    ORA PFTemp
RoadPreloadDone:
    STA PF2
    LDA #(CAR_X + POS_BIAS)
    JSR SetCoarseP0
    JMP DoHmove

; --- effect 1: the rainbow ---------------------------------------------------
; No player objects are used, so there is no HMOVE in this effect.  The sun
; and the horizon are playfield blocks, which is why they cost no sprite.
SetupRainbow:
    LDA #C_BG
    STA COLUBK
    LDA #C_SUN
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    ; The ramp window: a 192-entry read starting at Rainbow + RainbowShift.
    ; The table is page-aligned and 192 + 63 = 255 entries long, so the
    ; indirect load never crosses a page.
    LDA #<Rainbow
    CLC
    ADC RainbowShift
    STA RampLo
    LDA #>Rainbow
    ADC #$00
    STA RampHi
    JMP PictureRainbow

; --- the one HMOVE for the effects that position P0 --------------------------
DoHmove:
    STA WSYNC               ; a fresh line for the HMOVE's HBLANK
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed
    NOP
    LDA Effect
    CMP #EFFECT_ROAD
    BEQ PictureRoad
    ; fall through to the starfield
PictureStar:
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; EFFECT 0 — THE STARFIELD (visible lines 0-191)
; =============================================================================
; Two top-down loops share one X index: LDY #0 draws rows 0-175, then
; the same loop shape draws rows 176-191 and adds the ship.  X is the world
; row: it starts at StarScroll and wraps 255 -> 0 inside the page-aligned
; planes.  Y is the visible row and also the index into the enable tables.
BodyStart:                  ; checkpoint: scanline 37, visible line 0
StarField:
    LDX StarScroll
    LDY #0
StarRow:                    ; checkpoint: Y = 0..175
    ; Three playfield load/store pairs: 21 cycles.
    LDA StarPF0,X
    STA PF0                 ; chunks 0-3
    LDA StarPF1,X
    STA PF1                 ; chunks 4-11
    LDA StarPF2,X
    STA PF2                 ; chunks 12-19
    ; One 192-byte enable table per one-pixel star.  Every row writes all
    ; three enables: $02 on the star's own row, $00 everywhere else.  The
    ; three stores complete at cycles 37, 44 and 51, before the stars'
    ; pixels at X=112, 128 and 144 (cycles 60, 65 and 71).
    LDA StarBall,Y
    STA ENABL
StarBallWrite:              ; checkpoint: the ball enable is latched
    LDA StarM0,Y
    STA ENAM0
StarM0Write:                ; checkpoint: missile 0's enable is latched
    LDA StarM1,Y
    STA ENAM1
StarM1Write:                ; checkpoint: missile 1's enable is latched
StarWait:                   ; checkpoint: the WSYNC's first cycle
    STA WSYNC               ; the line is complete; wait for the next
    INX                     ; next world row (255 -> 0 inside the page)
    INY                     ; next visible row
    CPY #SHIP_TOP
    BNE StarRow

; --- rows 176-191: the ship ------------------------------------------------
; The split drops the ship gate from the 176 plain rows and lets this loop
; write GRP0 unconditionally.  The store completes by cycle 39 (the first
; ship row at 37), before the ship's left edge at X=76 (cycle 48).
StarShipRow:                ; checkpoint: Y = 176..191
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    LDA ShipShape - SHIP_TOP,Y
    STA GRP0
ShipWrite:                  ; checkpoint: the ship byte is latched
    LDA StarBall,Y
    STA ENABL
    LDA StarM0,Y
    STA ENAM0
    LDA StarM1,Y
    STA ENAM1
StarShipWait:               ; checkpoint: the ship loop's WSYNC
    STA WSYNC
    INX
    INY
    CPY #SCREEN_LINES
    BNE StarShipRow
    JMP OverscanStart       ; 176 + 16 = 192 lines: visible 0-191

; =============================================================================
; EFFECT 2 — THE PSEUDO-3D ROAD (visible lines 0-191)
; =============================================================================
; PF2 carries the whole road and is stored first: its field starts at
; pixel 48, and the pulse's longest path completes at cycle 36 (38 in
; exercise 3 with the centre-gap mask).  The car is written only in the
; bottom 16-row loop, after PF2; its GRP0 store completes at cycle 43 (45
; in exercise 3), before its left edge at X=76 (cycle 48).
PictureRoad:
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
RoadStart:                  ; checkpoint: scanline 37, visible line 0
RoadField:
    LDY #0
RoadRow:                    ; checkpoint: Y = 0..175
    ; PF2 is the whole road.  Compute and store it first: the store is
    ; latched by cycle 23/32/36 (pulse 0/1/2), before chunk 12's pixel.
    LDA RoadPF2,Y
    STA PFTemp
    LDX PulseAmt
    BEQ RoadPulseDone
    LSR
    ORA PFTemp
    DEX
    BEQ RoadPulseDone
    LSR
    ORA PFTemp
RoadPulseDone:
    STA PF2
RoadWait:                   ; checkpoint: the WSYNC's first cycle
    STA WSYNC
    INY
    CPY #CAR_TOP
    BNE RoadRow

; --- rows 176-191: the car ------------------------------------------------
; The split drops the car gate from the 176 road rows and lets this loop
; write GRP0 unconditionally.  The car's store completes at cycle 43, before
; its left edge at X=76 (cycle 48).
RoadCarRow:                 ; checkpoint: Y = 176..191
    LDA RoadPF2,Y
    STA PFTemp
    LDX PulseAmt
    BEQ RoadCarPulseDone
    LSR
    ORA PFTemp
    DEX
    BEQ RoadCarPulseDone
    LSR
    ORA PFTemp
RoadCarPulseDone:
    STA PF2
    LDA CarShape - CAR_TOP,Y
    STA GRP0
RoadCarWait:                ; checkpoint: the car loop's WSYNC
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE RoadCarRow
    JMP OverscanStart       ; 176 + 16 = 192 lines: visible 0-191

; =============================================================================
; EFFECT 1 — THE RAINBOW (visible lines 0-191)
; =============================================================================
; Four forward loops: plain 0-39, sun 40-88, plain 89-159, horizon 160-191.
; Each boundary draws its first row with the boundary stores, then the loop
; continues.  The COLUBK store always comes first: it is the store that must
; beat pixel 0.  PF2's field does not start until pixel 48, so the sun and
; horizon PF stores have the rest of HBLANK.
PictureRainbow:
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
RainbowStart:               ; checkpoint: scanline 37, visible line 0
    LDY #0
RainbowRowA:                ; checkpoint: Y = 0..39
    LDA (RampLo),Y
    STA COLUBK
RainbowWaitA:               ; checkpoint: the WSYNC's first cycle
    STA WSYNC
    INY
    CPY #SUN_TOP
    BNE RainbowRowA
; --- row 40: the sun block starts (PF2 chunks 16-19 -> 32 pixels) ------------
    LDA (RampLo),Y
    STA COLUBK
    LDA #SUN_PF
    STA PF2
    LDA #C_SUN
    STA COLUPF
RainbowSunWait:             ; checkpoint: the sun boundary line's WSYNC
    STA WSYNC
    INY
RainbowRowB:                ; checkpoint: Y = 41..88
    LDA (RampLo),Y
    STA COLUBK
    STA WSYNC
    INY
    CPY #SUN_BOTTOM
    BNE RainbowRowB
; --- row 89: the sun ends ----------------------------------------------------
    LDA (RampLo),Y
    STA COLUBK
    LDA #$00
    STA PF2
RainbowEndWait:             ; checkpoint: the sun-end line's WSYNC
    STA WSYNC
    INY
RainbowRowC:                ; checkpoint: Y = 90..159
    LDA (RampLo),Y
    STA COLUBK
    STA WSYNC
    INY
    CPY #HORIZON_TOP
    BNE RainbowRowC
; --- row 160: the black horizon starts (the full half-width) -----------------
; The horizon is a full-width black band, so all three playfield bytes are
; $FF.  COLUPF goes first: it must beat pixel 0.  PF0's store lands after
; pixel 0, so the very first horizon line shows about seven pixels of the
; previous line's colour at the far left; from the next line the band is solid.
    LDA (RampLo),Y
    STA COLUBK
    LDA #C_BLACK
    STA COLUPF
    LDA #HORIZON_PF
    STA PF0
    STA PF1
    STA PF2
RainbowHorizonWait:         ; checkpoint: the horizon boundary line's WSYNC
    STA WSYNC
    INY
RainbowRowD:                ; checkpoint: Y = 161..191
    LDA (RampLo),Y
    STA COLUBK
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE RainbowRowD
; 40 + 1 + 48 + 1 + 70 + 1 + 31 = 192 lines.  The last WSYNC releases the CPU
; at scanline 229, the first overscan line.

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
; AdvanceEffect — the next effect, wrapping 2 -> 0
; =============================================================================
; A is the new effect when the routine returns.  EffectStep is after the
; store, so a breakpoint there reports the value the rest of the frame uses.
AdvanceEffect:
    LDA Effect
    CLC
    ADC #$01
    CMP #EFFECT_COUNT
    BCC AdvanceStore
    LDA #$00
AdvanceStore:
    STA Effect
EffectStep:                 ; checkpoint: A = the new effect
    RTS

; =============================================================================
; SetCoarseP0 — the Lesson 26 divide-by-15 positioning dance
; =============================================================================
; A = the desired left edge + POS_BIAS.  The first WSYNC starts a fresh line;
; each iteration of the loop is 5 cycles = 15 colour clocks, which is why
; dividing by 15 works.  The remainder becomes the fine value and RESxx
; strobes the coarse position.  The caller's HMOVE applies the fine offset.
; Align the routine so the divide loop's taken BCS stays inside one page:
; a page-crossing branch costs one extra cycle per iteration, and 6 cycles
; would shift the object 15 colour clocks (one wrong coarse step).
    !align 31, 0
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

; =============================================================================
; SetCoarseBL — the same dance for the ball (HMBL / RESBL)
; =============================================================================
; Align the routine so the divide loop's taken BCS stays inside one page:
; a page-crossing branch costs one extra cycle per iteration, and 6 cycles
; would shift the object 15 colour clocks (one wrong coarse step).
    !align 31, 0
SetCoarseBL:
    STA WSYNC
    SEC
DivBL:
    SBC #15
    BCS DivBL
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMBL
    STA RESBL
    RTS

; =============================================================================
; SetCoarseM0 — the same dance for missile 0 (HMM0 / RESM0)
; =============================================================================
; Align the routine so the divide loop's taken BCS stays inside one page:
; a page-crossing branch costs one extra cycle per iteration, and 6 cycles
; would shift the object 15 colour clocks (one wrong coarse step).
    !align 31, 0
SetCoarseM0:
    STA WSYNC
    SEC
DivM0:
    SBC #15
    BCS DivM0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM0
    STA RESM0
    RTS

; =============================================================================
; SetCoarseM1 — the same dance for missile 1 (HMM1 / RESM1)
; =============================================================================
; Align the routine so the divide loop's taken BCS stays inside one page:
; a page-crossing branch costs one extra cycle per iteration, and 6 cycles
; would shift the object 15 colour clocks (one wrong coarse step).
    !align 31, 0
SetCoarseM1:
    STA WSYNC
    SEC
DivM1:
    SBC #15
    BCS DivM1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM1
    STA RESM1
    RTS

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
; AUDC 0C is the div-6 tone from Lesson 35; AUDV 0A is audible but not loud.
; The VBLANK clock silences the channel two frames later.
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; THE TABLES
; =============================================================================
; The star, road and rainbow tables are the lesson's data.  Every plane is
; page-aligned so the indexed loads never cross a page:
;
;   StarPF0/1/2   256 bytes each; X wraps 255 -> 0 inside the page.
;   StarBall/M0/M1 192 bytes each; Y is 0..191, so a table never crosses
;                 the page when it starts on one.
;   RoadPF2       192 bytes; Y is 0..191, so the plane never crosses a page.
;   Rainbow       192 ramp entries plus the first 64 repeated, so a 192-entry
;                 window starting at 0..63 is contiguous.
;
; The road's width arithmetic:
;   base half-width h(row) = 2 + round(4*row/191)    (2 -> 6)
;   The base road is therefore 4 chunks wide at the horizon and 12 at the
;   bottom.  The kernel then applies the 64-entry pulse: it shifts the PF2
;   mask 0, 1 or 2 times and ORs the shifted value with the unshifted one.
;   Each shift adds one chunk at the outer edge, so the widest bottom rows
;   reach the full 16 chunks.  Chunk 19 is the screen centre (the reflection
;   axis); chunk 12 is the leftmost PF2 chunk.  PF2 bit 7 is chunk 19 and
;   bit 0 is chunk 12, so a half-width h sets bits (8-h)..7.
;
;   At these widths the road lives entirely in PF2: PF0 and PF1 are $00 on
;   every row, so the setup clears them once and the kernel never stores
;   them.  The 16-chunk maximum is exactly PF2's eight chunks per half.

    !align 255, 0
StarPF0:
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 0-15
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$00   ; rows 16-31
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 32-47
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 48-63
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$00,$00,$00   ; rows 64-79
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$00,$00,$00,$00   ; rows 80-95
    !byte $00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 96-111
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 112-127
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 128-143
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$00,$20,$00,$00,$00   ; rows 144-159
    !byte $80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 160-175
    !byte $00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 176-191
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 192-207
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00   ; rows 208-223
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 224-239
    !byte $00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$80,$00,$00   ; rows 240-255

    !align 255, 0
StarPF1:
    !byte $40,$00,$00,$00,$08,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00   ; rows 0-15
    !byte $00,$40,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 16-31
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$A0,$00,$00,$00   ; rows 32-47
    !byte $00,$00,$00,$00,$04,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00   ; rows 48-63
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 64-79
    !byte $00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 80-95
    !byte $00,$00,$00,$00,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 96-111
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 112-127
    !byte $00,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$08,$00,$00,$00,$00   ; rows 128-143
    !byte $00,$02,$00,$00,$00,$00,$00,$00,$00,$09,$00,$00,$00,$00,$20,$00   ; rows 144-159
    !byte $00,$00,$02,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00   ; rows 160-175
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$00   ; rows 176-191
    !byte $00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 192-207
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$08,$00,$80,$00,$00,$00,$00,$00   ; rows 208-223
    !byte $00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 224-239
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$00,$00   ; rows 240-255

    !align 255, 0
StarPF2:
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$08,$00,$80,$80   ; rows 0-15
    !byte $00,$00,$00,$00,$00,$00,$04,$00,$00,$00,$10,$04,$00,$00,$00,$00   ; rows 16-31
    !byte $00,$00,$00,$00,$00,$00,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 32-47
    !byte $00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$00,$02,$00,$00,$00,$00   ; rows 48-63
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$00,$00,$00,$00,$00,$00   ; rows 64-79
    !byte $00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 80-95
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 96-111
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 112-127
    !byte $40,$00,$08,$01,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 128-143
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 144-159
    !byte $40,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 160-175
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 176-191
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00   ; rows 192-207
    !byte $00,$00,$08,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00   ; rows 208-223
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 224-239
    !byte $00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$80   ; rows 240-255

    !align 255, 0
RoadPF2:
    !byte $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0   ; rows 0-23
    !byte $E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0   ; rows 24-47
    !byte $E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0   ; rows 48-71
    !byte $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0   ; rows 72-95
    !byte $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0   ; rows 96-119
    !byte $F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8   ; rows 120-143
    !byte $F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8   ; rows 144-167
    !byte $FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC   ; rows 168-191

; =============================================================================
; THE RAINBOW — 16 hues x 12 lines at luminance 7, plus a 64-byte repeat
; =============================================================================
; Hue 0 is $0E (white), hue 1 $1E (gold), and so on to hue 15 $FE.  The
; 64 bytes after the ramp repeat the ramp's first 64 entries, so a window
; that starts at RainbowShift (0..63) and runs 192 rows stays contiguous.
    !align 255, 0
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
    ; the repeat: the first 64 entries (5 bands of 12 plus 4 of the sixth)
    !fill 12, $0E
    !fill 12, $1E
    !fill 12, $2E
    !fill 12, $3E
    !fill 12, $4E
    !fill 4, $5E

; =============================================================================
; THE WIDTH PULSE — 64 entries of 0, 1 or 2 widening steps
; =============================================================================
; WidthIndex walks this table once every 128 frames (one step per two
; frames).  Each step widens the road by one chunk per half; the peak adds
; two chunks per half, so the widest bottom row is the full 16 chunks wide.
PulseTable:
    !fill 8, 0
    !fill 16, 1
    !fill 16, 2
    !fill 16, 1
    !fill 8, 0

; =============================================================================
; THE SHIP — sixteen bytes, one per scanline
; =============================================================================
; The same 16-line ship Lesson 52 uses: a pointed nose, a widening body,
; engine gaps and two tail fins.  Drawn on P0 at SHIP_X=76.
    !align 15, 0
ShipShape:
    !byte $18, $18, $3C, $3C, $7E, $7E, $FF, $FF
    !byte $E7, $E7, $C3, $C3, $81, $81, $18, $18

; =============================================================================
; THE CAR — sixteen bytes, one per scanline
; =============================================================================
; A rounded rear view: a narrow roof, a wide body, and a dark window band.
; Drawn on P0 at CAR_X=76, at the bottom of the road.
    !align 15, 0
CarShape:
    !byte $18, $3C, $7E, $FF, $FF, $E7, $C3, $C3
    !byte $C3, $C3, $E7, $FF, $FF, $7E, $3C, $18

; =============================================================================
; THE STAR COLOURS — indexed by Twinkle (0 = white, 1 = gold)
; =============================================================================
TwinkleColors:
    !byte C_STAR_WHITE, C_STAR_GOLD

; =============================================================================
; THE STAR ENABLE TABLES — one 192-byte table per one-pixel star
; =============================================================================
; Row r is $02 on the star's row and $00 everywhere else.  The kernel writes
; all three enables every line, so a table replaces both the clear and the
; compare chain.  Each table is page-aligned: Y is 0..191, so a 192-byte
; table never crosses a page.
    !align 255, 0
StarBall:
    !fill STAR0_ROW, $00
    !byte $02
    !fill SCREEN_LINES - STAR0_ROW - 1, $00

    !align 255, 0
StarM0:
    !fill STAR1_ROW, $00
    !byte $02
    !fill SCREEN_LINES - STAR1_ROW - 1, $00

    !align 255, 0
StarM1:
    !fill STAR2_ROW, $00
    !byte $02
    !fill SCREEN_LINES - STAR2_ROW - 1, $00

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
> `lessons/part7-kernel-mastery/54-visual-effects-cookbook/54-visual-effects-cookbook.asm`.

### Code Walkthrough

#### Step 1 — The frame skeleton

```asm
StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    ; ... beep, inputs, effect clock, animation clocks, effect setup ...
PictureStar:
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

BodyStart:
StarField:
    ; ... 192 lines ...
```

The frame is the Part 2–7 skeleton: 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines. `StartFrame` is scanline 259, `VblankStart` 0, `BodyStart` 37 and `OverscanStart` 229. The three effects each have their own `+wait_timer` / `VBLANK`-off / kernel entry, so the dispatch costs nothing after the picture turns on: the VBLANK-off store completes at cycle 5 of scanline 37, and the first data stores follow at cycle 9 (starfield) or 7 (road).

#### Step 2 — The effect clock and the inputs

```asm
    LDA NewFire
    BEQ NoFireEdge
    JSR AdvanceEffect
    LDA #EFFECT_PERIOD
    STA EffectTimer
    JSR BeepStart
NoFireEdge:
```

Fire advances the effect on a new press and restarts the 240-frame window. SELECT is the same edge idiom and resets to effect 0. The auto-demo decrements `EffectTimer` every frame; at zero it calls the same `AdvanceEffect` and reloads. All three paths converge on one routine, so the effect can never be advanced by two frames at once.

#### Step 3 — The animation clocks

```asm
    INC StarTimer
    LDA StarTimer
    AND #$01
    BNE NoStarStep
    INC StarScroll
NoStarStep:
```

Every clock is a small zero-page counter. `StarTimer`'s low bit makes the star scroll every second frame; `TwinkleTimer` counts 32 frames and flips `Twinkle`; `RainbowTimer` counts 4 frames and increments `RainbowShift`; `RoadScroll` increments every frame and every second frame its high bits become `WidthIndex`, which indexes `PulseTable` into `PulseAmt`. The clocks are updated before the effect dispatch, so the selected kernel always sees this frame's values.

#### Step 4 — The effect dispatch

```asm
    LDA #$00
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    LDA Effect
EffectRead:
    CMP #EFFECT_RAINBOW
    BEQ SetupRainbow
    CMP #EFFECT_ROAD
    BEQ SetupRoad
    ; fall through to SetupStar
```

The dispatch clears the object registers first. `GRP0` is the important one: the ship and the car write only the bottom 16 rows, so without the clear the last byte would show at the top of the next frame as a thin vertical line. The three enable registers are cleared so an object enabled on the last line of one effect cannot survive into the next.

#### Step 5 — Positioning and the one `HMOVE`

```asm
    LDA #(SHIP_X + POS_BIAS)
    JSR SetCoarseP0
    LDA #(STAR0_X + POS_BIAS)
    JSR SetCoarseBL
    LDA #(STAR1_X + POS_BIAS)
    JSR SetCoarseM0
    LDA #(STAR2_X + POS_BIAS)
    JSR SetCoarseM1
    JMP DoHmove
...
DoHmove:
    STA WSYNC
HmoveApply:
    STA HMOVE
HmoveDone:
    NOP
```

Each `SetCoarse` routine is the Lesson 26 divide-by-15 dance: `STA WSYNC`, then subtract 15 until borrow, then the remainder becomes the fine value and `RESxx` strobes the coarse position. The four objects are positioned in sequence, then one `WSYNC` starts a fresh line and one `HMOVE` applies every fine offset. The four routines are 32-byte aligned so the divide loop's taken `BCS` never crosses a page; a page-crossing branch costs an extra cycle per iteration and would shift an object 15 colour clocks. That bug is easy to miss because it only appears when the code moves.

#### Step 6 — The starfield kernel

```asm
StarRow:
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    LDA StarBall,Y
    STA ENABL
    LDA StarM0,Y
    STA ENAM0
    LDA StarM1,Y
    STA ENAM1
StarWait:
    STA WSYNC
    INX
    INY
    CPY #SHIP_TOP
    BNE StarRow
```

The order is the pixel-deadline order. The three playfield pairs come first; the three enable-table pairs follow and complete at cycles 37/44/51, before the stars at X=112/128/144. The first loop stops at row 176. A second loop, `StarShipRow`, repeats the playfield pairs, writes `GRP0` unconditionally and then writes the three enables (all zero down there). The `X` index is the world row and wraps 255→0 inside the page-aligned planes; `Y` is both the visible row and the enable-table index. The body costs 54 cycles on a plain or star row and 62 on a ship row.

#### Step 7 — The rainbow kernel

```asm
RainbowRowA:
    LDA (RampLo),Y
    STA COLUBK
RainbowWaitA:
    STA WSYNC
    INY
    CPY #SUN_TOP
    BNE RainbowRowA
; --- row 40: the sun starts ---
    LDA (RampLo),Y
    STA COLUBK
    LDA #SUN_PF
    STA PF2
    LDA #C_SUN
    STA COLUPF
RainbowSunWait:
    STA WSYNC
```

`RampLo/RampHi` point into `Rainbow + RainbowShift`, so `Y` walks the colour window directly. The plain loop is 18 cycles; the boundary rows add the `PF2` and `COLUPF` stores before their `WSYNC`. `COLUBK` is always the first store on a row because it is the one that must beat pixel 0; `PF2`'s field does not start until pixel 48. The four loops are 40 + 1 + 48 + 1 + 70 + 1 + 31 = 192 lines.

#### Step 8 — The road kernel

```asm
RoadRow:
    LDA RoadPF2,Y
    STA PFTemp
    LDX PulseAmt
    BEQ RoadPulseDone
    LSR
    ORA PFTemp
    DEX
    BEQ RoadPulseDone
    LSR
    ORA PFTemp
RoadPulseDone:
    STA PF2
RoadWait:
    STA WSYNC
    INY
    CPY #CAR_TOP
    BNE RoadRow
```

`PF2` is the whole road, so it goes first: the pulse's longest path completes at cycle 36, before chunk 12's pixel at cycle 39. `PF0` and `PF1` are zero on every row, so the setup clears them once and the kernel never touches them. The car is written only in the second bottom loop, `RoadCarRow`, after `PF2`; its `GRP0` store completes at cycle 43, before X=76 (cycle 48). The pulse is the only arithmetic in the kernel: each shift of the `PF2` mask plus an OR adds one chunk at the road's **outer** edge.

#### Step 9 — Reading it back in Stella

Assemble with a symbol file and ask Stella for the checkpoints:

```bash
acme -f plain -l build/lesson54.sym -o build/lesson54.bin \
  lessons/part7-kernel-mastery/54-visual-effects-cookbook/54-visual-effects-cookbook.asm

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F1D2' build/lesson54.bin
```

Run each checkpoint separately for a readable log. The addresses below are the ones this source produced. A breakpoint on a label reports the first cycle of the instruction that follows it.

### Checkpoints

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F061` | 259/3 | the first VSYNC line |
| `VblankStart` | `$F06F` | 0/5 | the first VBLANK line |
| `BodyStart` | `$F1D2` | 37/5 | visible line 0 (effect 0) |
| `OverscanStart` | `$F2DB` | 229/11 (star), 229/6 (rainbow), 229/9 (road) | the first blank line after the picture |
| `EffectRead` | `$F137` | A=0, 1, 2 | the selected effect |
| `EffectTimerRead` | `$F0DD` | A=239, 238, … | the effect clock |
| `EffectStep` | `$F2FB` | A=1 at 240, A=2 at 480, A=0 at 720 | an automatic effect change |
| `SelectReset` | `$F0C3` | A=0 at frame 1 under `-holdselect` | SELECT's reset |
| `StarScrollRead` | `$F0EA` | 0, 1, 1, 2, 2, … | the star world's top row |
| `RainbowShiftRead` | `$F113` | 0, 0, 0, 1, 1, … | the ramp window's first entry |
| `RoadScrollRead` | `$F128` | 1, 2, 3, 4, … | the road's animation clock |
| `WidthIndexRead` | `$F125` | 0, 1, 1, 2, 2, … | the pulse-table index |
| `TwinkleStep` | `$F100` | 1 at 32, 0 at 64, 1 at 96 | the star colour flip |
| `HmoveApply` | `$F1BE` | 9/3 (star), 4/59 (road); none in the rainbow | the `HMOVE` store |
| `HmoveDone` | `$F1C0` | 10/3 (star), 5/3 (road) | the store has executed |
| `StarRow` | `$F1D6` | Y=0..175 | the starfield row |
| `StarShipRow` | `$F1FC` | Y=176..191 | the ship row |
| `ShipWrite` | `$F210` | 39 steady (37 on the first ship row) | the ship byte is latched |
| `StarBallWrite` | `$F1EA` | 37 | the ball enable is latched |
| `StarM0Write` | `$F1EF` | 44 | missile 0's enable is latched |
| `StarM1Write` | `$F1F4` | 51 | missile 1's enable is latched |
| `StarWait` | `$F1F4` | 51 | the star loop's `WSYNC` |
| `StarShipWait` | `$F21F` | 60 | the ship loop's `WSYNC` |
| `RoadRow` | `$F237` | Y=0..175 | the road row |
| `RoadCarRow` | `$F252` | Y=176..191 | the car row |
| `RoadWait` | `$F24B` | 23/32/36 (pulse 0/1/2) | the road loop's `WSYNC` |
| `RoadCarWait` | `$F26B` | 31/40/44 (pulse 0/1/2) | the car loop's `WSYNC` |
| `RainbowRowA` | `$F282` | Y=0..39 | the first rainbow loop |
| `RainbowWaitA` | `$F286` | 15 | the plain rainbow `WSYNC` |
| `RainbowSunWait` | `$F299` | 24 | the sun boundary's `WSYNC` |
| `RainbowEndWait` | `$F2AF` | 19 | the sun-end boundary's `WSYNC` |
| `RainbowHorizonWait` | `$F2CD` | 30 | the horizon boundary's `WSYNC` |

## What You Should See

The reel has three pictures, one at a time.

**Effect 0 — the starfield.** A dark `$02` field with about sixty four-pixel stars and three one-pixel stars: a gold one at row 32 (the ball), a white one at row 96 (missile 0) and a gold one at row 160 (missile 1). The whole field scrolls up one scanline every two frames; the three one-pixel stars stay at their fixed rows. Every 32 frames the playfield, the ball and missile 1 change colour together between white `$0E` and gold `$1A`; missile 0 stays white because it is driven by `COLUP0`, not `COLUPF`. The white 16-line ship sits at the bottom centre, its left edge at TIA X=76, visible rows 176–191.

![Stella running the Lesson 54 ROM on effect 0: a dark grey starfield of short gold dashes, three one-pixel stars at rows 32, 96 and 160, and a white 16-line ship at the bottom centre; the title bar reads Stella 7.0: "54-visual-effects-cookbook"](/images/lesson54/starfield.png)

*`starfield`: effect 0, gold phase (`Twinkle`=1). The background is `$02` (63,63,62); the playfield stars are `$1A` (205,205,52); the ship is `$0E` (234,234,233) at TIA X=76–83, visible 176–191 (16 lines). The three one-pixel stars measure X=111 (ball, gold), X=127 (missile 0, white) and X=143 (missile 1, gold); their nominal constants are 112/128/144 and the one-pixel difference is the ball/missile output delay. Missile 0 is the white one because it is wired to `COLUP0`; the other two follow `COLUPF`/`COLUP1` and turn gold with the field.*

<RomPlayer rom="/roms/part7-kernel-mastery/54-visual-effects-cookbook/54-visual-effects-cookbook.bin" title="Lesson 54 — Visual Effects Cookbook" />

Javatari starts muted: click the player once to unmute the two-frame fire/SELECT beep.

**Effect 1 — the rainbow.** A full-height background of sixteen colour bands, twelve lines each, drifting upward one ramp entry every four frames. The bands are the sixteen hues at luminance 7: `$0E` (white), `$1E` (gold), `$2E`, `$3E`, and so on to `$FE`. A centred gold block covers visible rows 40–88 (the sun), and a black band covers rows 160–191 (the horizon). This effect is verified from the ramp table and the `RainbowShiftRead`/`COLUBK` state log, not from a committed screenshot; the two captures are effects 0 and 2.

**Effect 2 — the pseudo-3D road.** A dark field with a centred light-grey road. The road's base is 4 chunks wide at the horizon and 12 at the bottom; the 64-entry pulse widens it by up to two chunks per half, so at the pulse's peak the road is 8 chunks at the top and the full 16 chunks at the bottom. The white 16-line car sits at the bottom centre, its left edge at X=76. The pulse makes the road's edges breathe in and out over 128 frames, which is the effect's motion.

![Stella running the Lesson 54 ROM on effect 2: a centred light-grey road widening from 8 chunks at the top to 16 chunks at the bottom, with a white 16-line car at the bottom centre and the title bar reading Stella 7.0: "54-visual-effects-cookbook"](/images/lesson54/road.png)

*`road`: effect 2 at the pulse's peak (`PulseAmt`=2). The background is `$02`; the road is `$0C` (210,210,209); the car is `$0E`. The measured widths are 8, 10, 12, 14 and 16 chunks at visible rows 0, 32, 96, 160 and 190; at the pulse's low phase the same rows are 4, 6, 8, 10 and 12. The car measures X=76–83, visible 176–191.*

> **Capture method.** Both images are window captures of
> `docs/public/roms/part7-kernel-mastery/54-visual-effects-cookbook/54-visual-effects-cookbook.bin`
> in Stella 7.0, taken with `scripts/capture-screenshot.sh` after a timed wait. The starfield
> image is from the first 240-frame window, in its gold phase; the road image is from the
> 480–719-frame window at the pulse's peak. The starfield scrolls one line every two frames and
> the road's pulse moves every two frames, so the wait selects the phase; each image was checked
> by measuring the background, field colours and road widths above.

The ROM needs no input: the auto-demo advances the effect every 240 frames, so all three effects are reachable without a key press. The joystick is not read in this lesson; fire and SELECT are the only controls.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
ROM=docs/public/roms/part7-kernel-mastery/54-visual-effects-cookbook/54-visual-effects-cookbook.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1D2' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F2DB' $ROM   # OverscanStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F137' $ROM   # EffectRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F2FB' $ROM   # EffectStep
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0EA' $ROM   # StarScrollRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F113' $ROM   # RainbowShiftRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F125' $ROM   # WidthIndexRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F100' $ROM   # TwinkleStep
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1BE' $ROM   # HmoveApply
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F24B' $ROM   # RoadWait
```

- **`$F061` (`StartFrame`)** is **259/3**, **`$F06F` (`VblankStart`)** **0/5**, **`$F1D2` (`BodyStart`)** **37/5** and **`$F2DB` (`OverscanStart`)** **229/11** on the starfield, **229/6** on the rainbow and **229/9** on the road: 3 + 37 + 192 + 30 = 262 lines, and 229 − 37 = 192 visible lines.
- **`$F137` (`EffectRead`)** reports A=0 for the first 240 frames, A=1 for frames 240–479, A=2 for 480–719 and A=0 again at 720. **`$F0DD` (`EffectTimerRead`)** reports 239, 238, 237, … on consecutive frames and reloads to 240 after each change.
- **`$F2FB` (`EffectStep`)** reports A=`$01` at frame 240, A=`$02` at frame 480 and A=`$00` at frame 720: one effect every 240 frames, then back to the start. Under `-holdselect`, **`$F0C3` (`SelectReset`)** reports A=`$00` at frame 1. A held fire button does not advance the reel repeatedly: with `-holdfire`, `EffectStep` still fires only at 240/480/720, because the edge detector sees no new press after the startup guard.
- **`$F0EA` (`StarScrollRead`)** reports 0, 1, 1, 2, 2, 3, 3, …: one world row every two frames. **`$F113` (`RainbowShiftRead`)** reports 0, 0, 0, 1, 1, 1, 1, 2, …: one ramp entry every four frames. **`$F128` (`RoadScrollRead`)** reports 1, 2, 3, 4, …: one frame per step. **`$F125` (`WidthIndexRead`)** reports 0, 1, 1, 2, 2, 3, …: one pulse entry every two frames, 0–63.
- **`$F100` (`TwinkleStep`)** reports A=`$01` at frame 32, A=`$00` at frame 64, A=`$01` at frame 96 and so on: the star colour flips every 32 frames.
- **`$F1BE` (`HmoveApply`)** is 9/3 and **`$F1C0` (`HmoveDone`)** 10/3 in the starfield; in the road they are 4/59 and 5/3 (the first road frame's `HmoveApply` is 5/59 because the first frame's setup is one line longer). There are **no** `HmoveApply` hits during the rainbow: effect 1 positions no player object.
- **`$F24B` (`RoadWait`)** reports 23/32/36 on plain rows and **`$F26B` (`RoadCarWait`)** 31/40/44 on car rows for pulse 0/1/2; the row starts at cycle 7. **`$F1F4` (`StarWait`)** reports 51 on every top-loop row and **`$F21F` (`StarShipWait`)** 60 on a ship row; the top loop starts at cycle 9 and the ship loop at 10. The enable writes report 37/44/51 (`StarBallWrite`/`StarM0Write`/`StarM1Write`) and the ship write 39 (`ShipWrite`). **`$F286` (`RainbowWaitA`)** reports 15 every plain row; the sun, sun-end and horizon boundaries report 24, 19 and 30.

The pixel checks decode the captures with `capture x = 25 + 6 × TIA X` and `capture y = 107 + 3.15 × visible line`:

| Check | `starfield.png` | `road.png` | Expected |
|---|---|---|---|
| background | `$02` (63,63,62) | `$02` (63,63,62) | the dark field |
| field colour | `$1A` (205,205,52) | `$0C` (210,210,209) | gold stars / light-grey road |
| white object | `$0E` (234,234,233) | `$0E` (234,234,233) | ship / car / missile-0 star |
| ship or car | X=76.0–83.8, visible 176.5–191.7 | X=76.0–83.8, visible 176.5–191.7 | 8 px wide, 16 lines |
| one-pixel stars | X=111, 127, 143 at rows 32, 96, 160 | — | nominal 112/128/144, one clock left |
| road width at row 0 | — | 8 chunks (32 px) | 4 base + 2 pulse per half |
| road width at row 32 | — | 10 chunks (40 px) | the widening profile |
| road width at row 96 | — | 12 chunks (48 px) | the widening profile |
| road width at row 160 | — | 14 chunks (56 px) | the widening profile |
| road width at row 190 | — | 16 chunks (64 px) | the full PF2 half-width |

The screenshots prove the visual state; the state log proves the values, the lines and the cycles. The thing a still cannot prove is the motion: `StarScrollRead` proves the one-row-per-two-frames scroll, `RainbowShiftRead` proves the four-frame colour drift, and `WidthIndexRead` proves the road's two-frame pulse. The two captures are from two different effects, so they also prove that the dispatch reaches both kernels.

## Exercises

### Exercise 1: Per-Star Twinkle

**Challenge:** make some stars disappear every 16 frames while the rest stay. Add a `TwinkleMask` byte that flips between `$FF` (every star) and `$55` (every other `PF2` chunk), and apply it to the star planes.

**Hints:**
1. `TwinkleMask` is a zero-page byte; start it at `$FF` and flip it with `EOR #$AA`, which turns `$FF` into `$55` and `$55` back into `$FF`. A `MaskTimer` reloads to 16 on each flip.
2. Mask `PF2` only: `LDA StarPF2,X / AND TwinkleMask / STA PF2`. Masking all three planes adds six cycles and would still fit (the ship row would measure 71), but `$55` is a `PF2` chunk pattern; applying it to `PF0`/`PF1` would hide a different set of chunks and lose the exercise's "every other `PF2` chunk" rule.
3. `PF2` covers chunks 12–19, so the mask hides every other star inside the field; the `PF0`/`PF1` stars and the three one-pixel stars stay lit.
4. The base kernel already splits at row 176. The mask's three cycles land on both loops, so the ship row measures 65 cycles — still inside the 76-cycle budget without another split.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `TwinkleMaskRead` reports A=`$FF` at frame 1 and A=`$55` at frame 16, then `$FF` again at 32; the starfield alternates between the full field and a field with every other `PF2` chunk dark. The ship, the three one-pixel stars and the other two effects are unchanged, and `OverscanStart` is still 229.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: A Faster Rainbow

**Challenge:** make the rainbow's colour window advance every two frames instead of every four. `RainbowShift` must walk 0, 1, 1, 2, 2, …

**Hints:**
1. The period is one constant: change `RAINBOW_PERIOD` from 4 to 2. `RainbowTimer` reloads from that constant, so the shift doubles its rate without touching the kernel.
2. A full 64-step cycle then takes 128 frames instead of 256; the window still stays inside the page-aligned 256-byte table.
3. The sun, the horizon and the other two effects do not change.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `RainbowShiftRead` reports 0, 1, 1, 2, 2, 3, 3, … (one step every two frames) instead of the base's 0, 0, 0, 1, 1, …; the colours move twice as fast, and `OverscanStart` is still 229.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The Ball Centre Line *(Stretch Goal)*

**Challenge:** add a one-pixel centre line to the road, drawn with the ball at `CenterLine`, and make the line move with the road.

**Hints:**
1. The ball and the playfield share `COLUPF`, so a ball pixel over a lit playfield chunk is the same colour as the chunk. Clear `PF2` bit 7 (`AND #$7F`) so the road has an eight-pixel centre gap, and draw the one-pixel line in that gap.
2. `CenterLine = 80 + PulseAmt`: the line follows the road's width pulse, drifting 0–2 pixels while the road itself stays centred. The reflected playfield cannot move its centre, so this is the only lateral motion the hardware allows.
3. Position the ball with the `SetCoarseBL` dance in the road setup (the same single `HMOVE` applies it) and set `ENABL=$02` for the whole effect. P0 has priority over the ball, so the car covers the line at the bottom.
4. The only kernel change is the `AND #$7F` before the `PF2` store (two cycles); the road's worst line measures 49 cycles (car row, pulse 2), still inside 76.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `CenterLineRead` reports 80, 81 and 82 over the pulse cycle; the road keeps its centre gap and the car, and the one-pixel line is measurable at TIA X=79–79.8 (nominal 80) inside the 76.0–83.8 gap. `OverscanStart` is still 229.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A full-screen effect is a kernel plus its data shape.** The starfield is three planes and an index; the rainbow is a colour window; the road is a width profile. The registers are always the same three, but the data and the deadlines differ.
- ✅ **Page-align the planes.** The star world wraps 255→0 inside its 256-byte page, the road's 192-byte `PF2` plane and the three 192-byte enable tables never cross a page at `Y` 0–191, and the rainbow window is 192 + 63 entries so its indirect load never crosses either.
- ✅ **A one-pixel star has a horizontal deadline.** The ball and missile enables must be latched before the beam reaches the star's X; the enable tables complete at cycles 37/44/51 (visible pixels 43/64/85), which is why the three stars at X=112/128/144 (measured 111/127/143) all have margin.
- ✅ **The reflected playfield has a fixed centre.** A 3-byte reflected row is symmetric about TIA X=80, so a centred road can only change its *width*. The "3D" is the width profile, and the width pulse is the motion.
- ✅ **The width pulse is a shift and an OR.** `(mask >> 1) | mask` adds one chunk at the outer edge; two shifts add two. The base road is 4→12 chunks, and the pulse takes the bottom to the full 16.
- ✅ **The ledgers are the contract.** Starfield 54/62 cycles (plain-or-star/ship), rainbow 18 plus 27/22/33 on the boundary lines, road 26/35/39 plain and 34/43/47 car. Every one is inside 76, and the worst (the starfield's ship row) leaves 14 cycles.
- ✅ **A full-screen effect can be cheap.** The rainbow costs 18 cycles per line because a colour write is one store; the starfield costs 54 because three planes, three enables and (on 16 rows) a ship share the line. Choose the effect's data shape before writing the kernel.

## What's Next

The reel proves that three effects can share one frame skeleton and one clock, but each effect is still a fixed picture. [Lesson 55: Scrolling Text Marquee — The Activision Logo Effect](/part7-kernel-mastery/55-scrolling-text-marquee) reuses the Lesson 39 score kernel to scroll a six-character text window across a starfield, and shows how a pre-shifted glyph table turns a 48-pixel window into a moving message.
