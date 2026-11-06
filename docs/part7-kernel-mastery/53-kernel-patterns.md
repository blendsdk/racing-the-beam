---
title: "Lesson 53: Kernel Design Patterns — Building Your Toolkit"
description: "Package the four kernel shapes of Part 7 as a reusable library — solid fill, two-line playfield rows, one-line sprite strips, and per-line colour ramps — then build a four-band sampler whose bands can be resized and reordered without rewriting a kernel."
prev:
  text: "Lesson 52: Fine Scrolling — Smooth Movement"
  link: "/part7-kernel-mastery/52-fine-scrolling"
next:
  text: "Lesson 54: Visual Effects Cookbook — Starfields, Rainbows, Pseudo-3D"
  link: "/part7-kernel-mastery/54-visual-effects-cookbook"
---

# Lesson 53: Kernel Design Patterns — Building Your Toolkit

> **Part 7: Kernel Mastery** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 11 (lookup tables), Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 15 (the RIOT timer), Lesson 17 (cycle counting), Lesson 18 (mid-scanline changes), Lesson 19 (the playfield), Lesson 25 (players), Lesson 26 (positioning), Lesson 28 (one `HMOVE`), Lesson 48 (the kernel taxonomy), Lesson 49 (the 2-line kernel)
> **You will learn:** how to package the recurring kernel shapes as reusable routines; how a zero-page pointer plus a row count replace per-band code; the four patterns — solid fill, two-line playfield rows, one-line sprite strips, per-line colour ramps — and their cycle ledgers; the band-boundary contract that keeps one band from inheriting another's objects; and how to combine patterns without hidden state
> **You will build:** "the pattern sampler" — a 4,096-byte ROM that sources `include/kernel_patterns.asm` and draws four 48-line bands: a solid teal-green fill, a 24-row playfield checkerboard, a dark band with an 8-line diamond sprite, and a 48-line red-to-blue gradient; fire cycles a three-entry palette, SELECT resets it, an auto-demo advances it every 240 frames, and one `HMOVE` positions the diamond; plus three exercise solutions: a five-band split (38+38+38+38+40), a SELECT-controlled 24-line ramp offset, and a table-ordered build

## Introduction

Lesson 52 ended with one kernel drawing one picture. The tunnel was a single 192-line loop, and every line did the same work. Most 2600 pictures are not like that. A game screen is usually several horizontal bands stacked together — a score, a status bar, a playfield, a strip of sprites — and each band has its own data shape and its own cycle budget. Writing a new loop for every band is how a 4K ROM runs out of space and a programmer runs out of patience.

This lesson turns the last five lessons into a toolkit. The shapes are always the same four: a solid colour, a playfield row, a sprite strip, and a colour ramp. What changes between uses is the data and the number of lines. So the four loops move into a shared library, `include/kernel_patterns.asm`, behind a small API: set a pointer and a row count, call the routine, and the band draws itself. The sampler that uses the library has no kernel loops of its own; it has a band boundary and four calls.

The boundary is where the lesson's real subject lives. A library routine writes only its own object, so the caller must clear the others and set the next band's colours. That cleanup runs on the first line of the new band, in the few cycles between the previous routine's return and the new routine's first `WSYNC`. Get the order wrong and the first line shows the previous band's playfield or a stripe of the wrong colour. The sampler's boundaries are written so the store that affects pixel 0 always lands before cycle 22.7, and the state log proves the bands still total exactly 192 lines.

The companion program `53-kernel-patterns.asm` is **the pattern sampler**. Its four bands are 48 lines each: a solid teal-green fill, a 24-row playfield checkerboard, a dark band with a moving eight-line diamond, and a red-to-blue gradient. Fire cycles a three-entry palette; SELECT resets it; an auto-demo advances it every 240 frames so every palette is reachable without a key press. The diamond sweeps down and up one strip row per frame, and one `HMOVE` in VBLANK places it horizontally.

::: details TypeScript Equivalent

A kernel library is a set of functions that write one line each, plus a builder that stacks them. In TypeScript the same idea is a pattern function and a band list:

```typescript
type LineWriter = (line: number) => void;

function fill(color: number): LineWriter {
  return () => writeRegister("COLUBK", color);
}

function pfRows(rows: Uint8Array, rowCount: number): LineWriter {
  return (line) => {
    const row = Math.min(line >> 1, rowCount - 1);   // two lines per row
    writeRegister("PF0", rows[row * 3 + 0]);
    writeRegister("PF1", rows[row * 3 + 1]);
    writeRegister("PF2", rows[row * 3 + 2]);
  };
}

function spriteStrip(strip: Uint8Array): LineWriter {
  return (line) => writeRegister("GRP0", strip[line]);
}

function colorRamp(ramp: Uint8Array): LineWriter {
  return (line) => writeRegister("COLUBK", ramp[line]);
}

function buildFrame(bands: Array<{ draw: LineWriter; lines: number }>): void {
  let line = 0;
  for (const band of bands) {
    for (let i = 0; i < band.lines; i++) band.draw(line++);
  }
}
```

The analogy breaks in the places that make the 2600 hard. There is no framebuffer and no `line` parameter: the kernel is called once per frame and must count the scanlines itself with `WSYNC`. `writeRegister` is not a store into an array; it is a store into a TIA latch that the beam reads as it passes, and a store that lands after the beam has passed the relevant pixels has no effect on this frame. The library's `KernelPtr` is a real 16-bit pointer in zero page, not a JavaScript array reference, and `(KernelPtr),Y` costs five cycles instead of one. The band list is not a data structure the program can reorder at run time: the four band calls are inline code, and a runtime dispatch loop would add about twenty-five cycles before every boundary — enough to push a band's first `WSYNC` past its scanline. Finally, the boundary is not free: the caller must clear the objects the next routine does not write, and that cleanup competes with the first line's pixel deadlines.

:::

## Theory

### Section 1: Why Package Kernels at All

Every kernel in Part 7 has been a variation on four data shapes:

| Shape | What changes per line | What the routine writes | Where the course built it |
|---|---|---|---|
| **Solid fill** | nothing | `COLUBK` | Lesson 12's background |
| **Playfield rows** | one 3-byte row per two lines | `PF0`, `PF1`, `PF2` | Lessons 19, 23, 49 |
| **Sprite strip** | one byte per line | `GRP0` (or `GRP1`) | Lessons 25, 30, 52 |
| **Colour ramp** | one colour per line | `COLUBK` (or `COLUPF`) | Lessons 20, 49 |

A game mixes them. The score zone is a special sprite kernel; the status bar is a playfield fill; the play area is a 2-line playfield plus sprite strips; a sky or a sunset is a colour ramp. The loops differ in their data and their object, but the *control flow* is the same: read a pointer, write a register, wait one line, advance.

The library turns that control flow into four callable routines. The lesson's job is then reduced to three decisions: which routine draws this band, how many lines it gets, and what the boundary must clear before it starts. Those three decisions are exactly the kind of thing a designer wants to change late in a project — and the library makes them cheap.

There is a cost, and the lesson is honest about it. A subroutine call is six cycles plus the return, and the routines cannot know what the previous band left in the TIA. The caller pays for both. That is why the sampler's boundaries are written by hand, in a fixed order, rather than generated by a generic dispatcher.

::: tip A library is not a framework
The library owns three bytes of zero page and four routines. It does not own the frame, the palette, the sprites, or the boundary. That is deliberate: a 2600 library that tries to own the frame becomes a game engine, and a game engine in 4K is a different lesson. These routines are tools, not a policy.
:::

### Section 2: The Zero-Page Pointer API

The library's entire interface is three bytes:

| Byte | Name | Meaning |
|---|---|---|
| `$80–$81` | `KernelPtr` | a 16-bit pointer to the band's table |
| `$82` | `KernelRows` | the band's row or line count (>= 1) |
| `$83` | — | left free for the lesson |

`KernelPtr` has to be in zero page because the 6502's indirect indexed addressing mode, `LDA (KernelPtr),Y`, only accepts a zero-page pointer. The mode reads the two bytes at `KernelPtr` and `KernelPtr+1`, adds `Y`, and loads from the resulting address. That is one instruction and five cycles:

```asm
    LDY #0
    LDA (KernelPtr),Y
```

The absolute indexed form, `LDA Table,Y`, is four cycles, but it hard-codes the table's address in the instruction. The pointer form pays one extra cycle to make the table a run-time choice. The library needs that: the same `KernelSpriteStrip` draws the 48-byte RAM strip in this lesson and could draw a ROM strip in another.

The five-cycle figure has one exception. If the base pointer plus `Y` crosses a page boundary, the load takes six cycles. The library's header records that; the lesson's tables are page-aligned or short enough that it never happens. `KernelPFRows` advances its pointer by three bytes per row, and the playfield table starts on a page boundary, so the pointer's low byte runs 0, 3, 6, …, 69 and never carries past `$FF`.

`KernelRows` is a plain zero-page byte. The library never assumes a value for it: the caller sets it before every call. That is the whole state. There are no hidden counters, no flags, and no "current band" variable inside the library. The only persistent state is the pointer and the count, and the caller owns both.

::: warning Set the pointer for every call
`KernelPFRows` advances `KernelPtr` as it draws, so the pointer is *not* the same after the call as it was before. The next band must set it again. This is not a bug; it is what lets the routine walk a table without a second index. The lesson's boundary code always reloads both pointer bytes.
:::

### Section 3: The Four Patterns and Their Ledgers

Each routine has one job and one ledger. The ledgers are static sums of the instructions in the loop body; the state log measures the line spacing and the store cycles, and the two agree.

**`KernelFill` — A = colour, X = lines**

```asm
KernelFill:
KernelFillLine:
    STA COLUBK
    STA WSYNC
    DEX
    BNE KernelFillLine
    RTS
```

| Work | Cycles |
|---|---|
| `STA COLUBK` | 3 |
| `STA WSYNC` | 3 |
| `DEX` | 2 |
| `BNE` (taken) | 3 |
| **per line** | **11** |

The last line's `BNE` is not taken, so it costs 2 and the routine's total is `11 * lines - 1`. The store is the first instruction of the loop body, so it finishes early in the line: the state log reports it at cycle 5 of every line after the first, and it completes at cycle 7, long before pixel 0 at cycle 22.7. The `WSYNC` halts the CPU at the end of the line, the loop tail runs at the start of the next (DEX 2, BNE 3), and the store follows.

**`KernelPFRows` — 3 bytes per row, two lines per row**

```asm
KernelPFRows:
KernelPFRow:
    LDY #0
    LDA (KernelPtr),Y
    STA PF0
    INY
    LDA (KernelPtr),Y
    STA PF1
    INY
    LDA (KernelPtr),Y
    STA PF2
    CLC
    LDA KernelPtr
    ADC #3
    STA KernelPtr
    BCC KernelPFNoCarry
    INC KernelPtr+1
KernelPFNoCarry:
    STA WSYNC
    STA WSYNC
    DEC KernelRows
    BNE KernelPFRow
    RTS
```

| Work | Cycles |
|---|---|
| `LDY #0` | 2 |
| three `LDA (Ptr),Y` + `STA PFn` pairs | 3 × 8 = 24 |
| two `INY` | 4 |
| `CLC` + `LDA` + `ADC` + `STA` | 10 |
| `BCC` (no carry) | 3 |
| two `STA WSYNC` | 6 |
| `DEC KernelRows` | 5 |
| `BNE` (taken) | 3 |
| **per row (two lines)** | **57 = 28.5 per line** |

The two-line budget is 152 cycles, so a row leaves 95 cycles (47.5 per line). The stores are in pixel-deadline order: `PF0`'s field starts at pixel 0, `PF1`'s at pixel 16 (chunk 4), and `PF2`'s at pixel 48 (chunk 12). The measured row starts at cycle 8, so the three stores complete at cycles 17, 27 and 37. `PF0` is safely before pixel 0; `PF1` completes one cycle before chunk 4's field begins at cycle 28; `PF2` completes at cycle 37, five pixels before chunk 12 begins at pixel 48. The row body uses 57 of the 152 cycles, so the remaining 95 are the margin a caller can spend on a colour or sprite write in the same pair (Lesson 49 does exactly that).

The pointer advance is the only place a row can cost more. If the low byte carries, the `BCC` is not taken and `INC KernelPtr+1` adds four cycles (61 per row, 30.5 per line). The lesson's page-aligned table never carries.

**`KernelSpriteStrip` and `KernelColorRamp` — one byte per line**

```asm
KernelSpriteStrip:
    LDY #0
KernelSpriteLine:
    LDA (KernelPtr),Y
    STA GRP0
    STA WSYNC
    INY
    CPY KernelRows
    BNE KernelSpriteLine
    RTS
```

| Work | Cycles |
|---|---|
| `LDA (KernelPtr),Y` | 5 |
| `STA GRP0` | 3 |
| `STA WSYNC` | 3 |
| `INY` | 2 |
| `CPY KernelRows` (zero page) | 3 |
| `BNE` (taken) | 3 |
| **per line** | **19** |

`KernelColorRamp` is byte-for-byte the same shape with `STA COLUBK` in place of `STA GRP0`. That is the point of the pattern: the loop is the kernel, and the object is a parameter. The last line costs 18 because its `BNE` is not taken. The 76-cycle line leaves 57 cycles.

`CPY KernelRows` is three cycles because `KernelRows` is a zero-page address. A `CPY #constant` would be two, but then the routine could not resize its band. One cycle buys the whole API.

::: tip Why two lines per playfield row?
The playfield's three registers are rewritten once per row, and a row is displayed on two scanlines because the TIA latches the registers until the next write. The 2-line budget is 152 cycles; the row body uses 57, so there is room for a colour write and a sprite write in the same pair. That is why the 2-line playfield is the default full-screen shape (Lesson 49).
:::

### Section 4: The Band-Boundary Contract

The routines write only their own object:

| Routine | Writes | Leaves dirty |
|---|---|---|
| `KernelFill` | `COLUBK` | nothing |
| `KernelPFRows` | `PF0`, `PF1`, `PF2` | the playfield |
| `KernelSpriteStrip` | `GRP0` | player 0 |
| `KernelColorRamp` | `COLUBK` | nothing |

A band boundary is the code between the previous routine's return and the next routine's first `WSYNC`. It runs on the first line of the new band, and it has a hard deadline: a store that affects the leftmost pixel must complete before the TIA draws pixel 0 at cycle 22.7. That is about twenty-two cycles from the start of the line, minus the ten the fill spends returning (a four-cycle tail, `DEX` 2 + not-taken `BNE` 2, plus the six-cycle `RTS`) or the thirteen the other three spend (a seven-cycle tail plus the `RTS`), leaving roughly ten cycles for the first store — twelve after the fill.

The sampler's boundaries follow three rules:

1. **Store the first thing the line shows at pixel 0.** For the playfield band that is `COLUBK` (the row is blank, so the background must change from the fill's teal before pixel 0); for the sprite band it is the `PF0`–`PF2` clear (the previous band's playfield would otherwise show through); for the ramp it is `COLUBK` with the ramp's first colour. Each store that changes a pixel-0 value (`PF0`, `COLUBK`) completes before cycle 22.7. `COLUPF` is written before the blank first playfield row, and `COLUP0` before the blank first strip row, so both have the row's slack. In the sprite boundary the `PF2` clear lands at ~24, after pixel 0, but `PF2`'s field starts at 38.7, so it cannot show.
2. **Clear the objects the next routine does not write, but only the dirty ones.** Clearing a register that is already zero costs three cycles and can push the first `WSYNC` past the line. The playfield band is followed by the sprite band, so its boundary clears `PF0`–`PF2`; the sprite band is followed by the ramp, so its boundary clears `GRP0` (and `GRP1` defensively — nothing writes it, but the pair costs only six cycles and keeps the boundary symmetric). Redundant clears are skipped and the comment says why.
3. **Give the first row a blank line when the boundary is slow.** The playfield table's row 0 is `$00,$00,$00`; the sprite strip's row 0 is `$00`. If the boundary's stores land a few cycles late, they land on a blank line, not on visible data.

The line arithmetic is checked by the state log, not by the comments. `BodyStart` is scanline 37, `OverscanStart` is 229, and 229 − 37 = 192. Each band's first routine line is at a measured scanline: the playfield band's rows at 85, 87, 89, …; the sprite strip at 133; the ramp at 181. If a boundary's first `WSYNC` spilled into the next line, the next band's start would move by one and `OverscanStart` would read 230.

::: warning The boundary is not part of the library
This is the lesson's most important design decision. The library routines know nothing about each other, so the *caller* owns the band boundary. A generic "draw these four bands" function would need to know each routine's object, its first-line timing, and the next band's colours — in other words, it would need the whole screen's policy. The sampler keeps that policy in four small, explicit blocks.
:::

### Section 5: Building the Sampler

The sampler's four bands are 48 lines each. The data is small: a 72-byte playfield table, a 48-byte RAM strip, and two 96-byte ramp tables.

**Band 1 — the fill.** `KernelFill` is called with `A` = the palette's fill colour and `X` = 48. The colour was preloaded in VBLANK, so the first visible line is already correct; the routine re-stores the same colour on every line. The boundary is just the load and the call.

**Band 2 — the playfield.** The table is 24 rows × 3 bytes. Row 0 is blank; rows 1–23 alternate two four-pixel checkerboard phases:

| Row parity | `PF0` | `PF1` | `PF2` |
|---|---|---|---|
| A (odd rows) | `$50` | `$2A` | `$55` |
| B (even rows) | `$A0` | `$55` | `$AA` |

Chunk 4 (pixel 16) is dark in **both** phases. That is not a stylistic choice: `PF1`'s store completes at cycle 27, one cycle before chunk 4's field begins at cycle 28, so a bit that changed there would be a one-cycle race. Holding it constant makes the late store invisible. The result is a checkerboard divided by a four-pixel dark column near each side; the reflection mirrors it, so the screen has three panels.

The pointer and the row count are loaded in VBLANK, before band 1 starts. `KernelFill` never touches them, so they survive until band 2's call. Loading them at the band-2 boundary would add fifteen cycles and push the first `WSYNC` past the line.

**Band 3 — the sprite strip.** The strip is 48 bytes of RAM at `$A0–$CF`. Every frame the VBLANK code clears it and stamps the eight-byte diamond at `SpriteRow`, clamped to 1–40 so the shape's last byte is at index 47 at most. Row 0 stays blank. The strip is then drawn by `KernelSpriteStrip` with `KernelRows = 48`. The diamond is eight lines tall and eight pixels wide at its middle:

```asm
SpriteShape:
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
```

The sprite's horizontal position is a player position, not a playfield bit. The lesson sets it once per frame with the Lesson 26 divide-by-15 dance and one `HMOVE`; the diamond is at `SPRITE_X = 76`, the centre of the 160-pixel field.

**Band 4 — the colour ramp.** The ramp is 48 entries in six eight-line steps:

| Lines | Byte | Name |
|---|---|---|
| 0–7 | `$46` | red |
| 8–15 | `$56` | pink |
| 16–23 | `$66` | light violet |
| 24–31 | `$76` | violet |
| 32–39 | `$86` | blue |
| 40–47 | `$84` | deeper blue |

The table is stored **twice** (96 bytes per direction). That is what makes the exercise's 24-line phase work: a 48-line window that starts at offset 24 is still contiguous. The palette selects a forward or a reversed table, so palette 1's gradient runs blue at the top to red at the bottom.

**The palette.** A palette is five bytes: fill colour, playfield colour, sprite colour, and the ramp pointer's low and high bytes. The VBLANK code computes `5 * Palette` with two `ASL`s and an `ADC`, indexes the table, and stores the five results in the lesson's variables. The ramp's first colour is read from the pointer and cached as `RampFirst`, so the band-4 boundary has a one-byte store instead of an indirect load.

| Palette | Fill | Playfield | Sprite | Ramp |
|---|---|---|---|---|
| 0 | `$B8` teal-green | `$1A` gold | `$0E` white | forward, red→blue |
| 1 | `$84` blue | `$C8` green | `$1A` gold | reversed, blue→red |
| 2 | `$42` red | `$0E` white | `$C8` green | forward, red→blue |

Fire advances the palette, SELECT resets it to 0, and the auto-demo advances it every 240 frames. The fire edge uses the Lesson 46 detector with the eight-frame startup guard from Lesson 48, so a held fire button does not advance the palette. SELECT needs no guard: a held SELECT at power-on only resets to palette 0, which is already the power-on state.

### Section 6: Reading It in Stella

The sampler is a state machine, and the debugger shows its three layers at once:

- **The frame:** `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `OverscanStart` 229. The last two are the proof that the body is 192 lines.
- **The bands:** `PatternStart` reports the frame's band plan in VBLANK (A = 0, 1, 2, 3), `PatternCount` reports the count (4), and `Band2Setup`, `Band3Setup`, `Band4Setup` report each library call's `KernelRows` in A and `KernelPtr` in X/Y. `PatternWrite` reports the first band's fill colour.
- **The inputs:** `PaletteRead` reports the current palette each frame, `PaletteStep` reports a change (the auto-demo at frames 240, 480, 720; fire at whichever frame the press lands), `SelectReset` reports the SELECT reset, and `SpriteRowWrite` reports the diamond's top strip row, which advances by one per frame.

A screenshot proves the picture; the state log proves the values, the lines and the cycles. The lesson uses both, and neither is asked to prove the other's claim.

## The Code

### Building This Lesson

```bash
# every lesson ROM, including this one:
npm run roms

# or just this one:
acme -f plain -o build/lesson53.bin \
  lessons/part7-kernel-mastery/53-kernel-patterns/53-kernel-patterns.asm

stella build/lesson53.bin
```

The lesson sources the library after `* = $F000` (and after `include/vcs.asm`), because the library emits code and uses the TIA register names. Sourcing it before the program counter is defined is the usual ACME error:

```asm
    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

    * = $F000
    !source "include/kernel_patterns.asm"
```

The three exercise solutions sit beside the lesson source. Each is a complete 4,096-byte ROM:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part7-kernel-mastery/53-kernel-patterns/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part7-kernel-mastery/53-kernel-patterns/exercise-02-solution.asm
acme -f plain -o build/exercise-03.bin \
  lessons/part7-kernel-mastery/53-kernel-patterns/exercise-03-solution.asm
```

### Full Source

The complete annotated source is reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 53: Kernel Design Patterns — The Pattern Sampler — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; What this program does:
;   "the pattern sampler": four 48-line bands, each drawn by one routine from
;   include/kernel_patterns.asm.  The library packages the four kernel shapes
;   the course has built:
;
;     KernelFill         a solid background band        A = colour, X = lines
;     KernelPFRows       a 2-line playfield band        KernelPtr = 3 bytes/row
;     KernelSpriteStrip  a 1-line sprite band           KernelPtr = 1 byte/line
;     KernelColorRamp    a per-line background ramp     KernelPtr = 1 colour/line
;
;   The four bands are 48 lines each = 192:
;     visible 0-47     KernelFill:        solid teal-green ($B8)
;     visible 48-95    KernelPFRows:      24 rows x 2 lines of a checkerboard
;     visible 96-143   KernelSpriteStrip: a dark band with an 8-line diamond
;     visible 144-191  KernelColorRamp:   a red-to-blue gradient
;
;   The band boundary is the lesson's contract.  Each routine writes only its
;   own object, so the boundary clears the objects the next routine does not
;   write and sets the next band's colours.  The order inside a boundary is
;   chosen so the store that affects the first line's left edge completes
;   before the TIA draws pixel 0 (cycle 22.7).
;
;   The library owns $80-$82: KernelPtr ($80/$81) and KernelRows ($82).  The
;   lesson uses $83-$93 for its counters and $A0-$CF for the 48-byte sprite
;   strip.  $94-$9F and $D0-$F7 are free; the stack is $F8-$FF.
;
; Controls:
;   Fire cycles the palette 0 -> 1 -> 2 -> 0 and beeps.  A palette is five
;   bytes: the fill colour, the PF colour, the sprite colour, and the ramp
;   pointer.  SELECT resets to palette 0 and beeps.  The auto-demo advances
;   the palette every 240 frames, so every palette is reachable without a key
;   press.  Palette 1 also reverses the ramp: its gradient runs blue at the
;   top to red at the bottom.
;
;   The sprite band's diamond sweeps 1 -> 40 -> 1, one strip row per frame.
;   The clamp keeps the 8-byte shape inside the 48-byte strip; row 0 is always
;   blank, which is the band's top margin.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;
; The library's cycle ledgers (steady state):
;   KernelFill         11 cycles/line
;   KernelPFRows       57 cycles per row = 28.5/line (95 cycles of margin)
;   KernelSpriteStrip  19 cycles/line
;   KernelColorRamp    19 cycles/line
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), OverscanStart (229);
;   PatternStart (A = each band index in the frame's plan: 0, 1, 2, 3);
;   PatternCount (A = 4); PatternWrite (A = the first band's fill colour);
;   Band2Setup (A = KernelRows, X/Y = the PF pointer), Band3Setup and
;   Band4Setup (the same three values for their bands); PaletteRead (A = the
;   palette index); PaletteStep (A = the new palette); SelectReset (A = 0);
;   SpriteRowWrite (A = the diamond's top strip row); HmoveApply (the WSYNC
;   stall), HmoveDone (the store has executed).
;
; Build: acme -f plain -o build/lesson53.bin \
;        lessons/part7-kernel-mastery/53-kernel-patterns/53-kernel-patterns.asm
; Run:   stella build/lesson53.bin     (click the screen to unmute the beep)
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

BAND_LINES     = 48      ; each of the four bands
BAND_COUNT     = 4       ; the band-count checkpoint
PF_ROWS        = 24      ; KernelPFRows draws two lines per row
SPRITE_LINES   = 48      ; the strip is one byte per line
SPRITE_SHAPE   = 8       ; the diamond is eight bytes tall
SPRITE_MIN     = 1       ; the top strip row (row 0 stays blank)
SPRITE_MAX     = 40      ; row + 8 <= 48, so the shape never leaves the strip
SPRITE_X       = 76      ; the diamond's left edge: centred on the 160-px field

DEMO_PERIOD    = 240     ; frames per palette in the auto-demo
PALETTE_COUNT  = 3       ; palettes 0, 1, 2
BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright beep

C_BG           = $02     ; the dark background behind the sprite band

; The band arithmetic is a build-time assertion, not a comment: four 48-line
; bands must fill the 192-line picture exactly.
!if BAND_LINES * BAND_COUNT != 192 {
    !error "the four bands must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($83-$93; +clean_start zeroes every byte)
; =============================================================================
; The library owns $80-$82 (KernelPtr and KernelRows); this lesson starts at
; $83.  The sprite strip is the 48-byte RAM block at $A0-$CF.
Palette      = $83   ; the current palette, 0..2
PaletteTimer = $84   ; frames left before the auto-demo advances the palette
PrevFire     = $85   ; fire state last frame (1 = pressed)
PrevSelect   = $86   ; SELECT state last frame (1 = pressed)
BeepTimer    = $87   ; frames of beep remaining
BeepPitch    = $88   ; AUDF for the beep
SpriteRow    = $89   ; the diamond's top strip row, 1..40
SpriteDir    = $8A   ; the auto-demo's sweep direction: 0 = up, 1 = down
Startup      = $8B   ; frames left before the fire edge is trusted
FillColor    = $8C   ; the palette's fill colour
PFColor      = $8D   ; the palette's playfield colour
SpriteColor  = $8E   ; the palette's sprite colour
RampLo       = $8F   ; the ramp pointer's low byte
RampHi       = $90   ; the ramp pointer's high byte
RampFirst    = $91   ; the ramp's first colour (the band-4 boundary store)
NewFire      = $92   ; this frame's fire 0 -> 1 edge
Scratch      = $93   ; SELECT's pressed state
;
; $94-$9F are free (12 bytes).  The sprite strip occupies $A0-$CF; $D0-$F7
; are free (40 bytes).  The stack lives at $F8-$FF; the call depth stays at
; one level (SetCoarseP0, AdvancePalette, BeepStart).
SpriteStrip  = $A0   ; 48 bytes: one GRP0 byte per line of the sprite band

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; THE PATTERN LIBRARY
; =============================================================================
; kernel_patterns.asm emits code, so it is sourced after * = $F000 (and after
; include/vcs.asm, whose register names it uses).  It defines the four
; routines and the zero-page control bytes before the lesson's own code, so
; every KernelPtr/KernelRows reference is a zero-page access: an absolute
; access would be one byte and one cycle too long, and the band budgets would
; be wrong.
    !source "include/kernel_patterns.asm"

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

    LDA #$00
    STA Palette             ; power on with palette 0
    LDA #DEMO_PERIOD
    STA PaletteTimer
    LDA #$01
    STA SpriteDir           ; the diamond sweeps down first
    LDA #SPRITE_MIN
    STA SpriteRow
    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #$08
    STA Startup             ; ignore the fire line while the console settles

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; the sprite band's dark background
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the right half mirrors
    LDA #$00
    STA NUSIZ0              ; one 8-pixel copy of P0
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
; 2. FIRE — advance the palette on the 0 -> 1 edge
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
    JSR AdvancePalette
    LDA #DEMO_PERIOD        ; a manual change restarts the auto-demo window
    STA PaletteTimer
    JSR BeepStart
NoFireEdge:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; -----------------------------------------------------------------------------
; 3. SELECT — reset to palette 0
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  The edge, not the level, resets the
; palette.  SELECT is also the capture helper: a capture can start from
; palette 0 without waiting for the auto-demo.
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelectEdge
    LDA #$00
SelectReset:                ; checkpoint: A = 0, the new palette
    STA Palette
    LDA #DEMO_PERIOD
    STA PaletteTimer
    JSR BeepStart
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 4. THE AUTO-DEMO'S PALETTE CLOCK — one palette every 240 frames
; -----------------------------------------------------------------------------
    DEC PaletteTimer
    BNE NoAutoPalette
    JSR AdvancePalette
    LDA #DEMO_PERIOD
    STA PaletteTimer
NoAutoPalette:

; -----------------------------------------------------------------------------
; 5. THE PALETTE TABLE AND THE FRAME'S BAND PLAN
; -----------------------------------------------------------------------------
; The palette table is five bytes per entry: fill, PF, sprite, ramp low, ramp
; high.  The index math is 5 * Palette = 4 * Palette + Palette.
    LDA #BAND_COUNT
PatternCount:               ; checkpoint: A = 4
    NOP
    LDA Palette
PaletteRead:                ; checkpoint: A = the palette index (0..2)
    ASL
    ASL
    CLC
    ADC Palette             ; A = 5 * Palette
    TAX
    LDA PaletteTable+0,X
    STA FillColor
    LDA PaletteTable+1,X
    STA PFColor
    LDA PaletteTable+2,X
    STA SpriteColor
    LDA PaletteTable+3,X
    STA RampLo
    LDA PaletteTable+4,X
    STA RampHi

; The band-4 boundary needs the ramp's first colour before the TIA draws the
; band's first pixel.  Compute it here, where there is time, and store it.
    LDY #0
    LDA (RampLo),Y
    STA RampFirst

; The frame's band plan.  The visible kernel's boundaries cannot spare the
; seventeen cycles of a debug call (that is why the four band bodies are
; inlined), so PatternStart is reported here: four hits, A = 0, 1, 2, 3.
    LDX #0
PlanBands:
    TXA
PatternStart:               ; checkpoint: A = each band index in the plan
    NOP
    INX
    CPX #BAND_COUNT
    BNE PlanBands

; -----------------------------------------------------------------------------
; 6. THE SPRITE'S ROW — 1..40, bouncing one strip row per frame
; -----------------------------------------------------------------------------
    LDA SpriteDir
    BNE SpriteDown
    LDA SpriteRow
    CMP #SPRITE_MIN
    BEQ SpriteFlipDown
    DEC SpriteRow
    JMP SpriteRowDone
SpriteDown:
    LDA SpriteRow
    CMP #SPRITE_MAX
    BEQ SpriteFlipUp
    INC SpriteRow
    JMP SpriteRowDone
SpriteFlipDown:
    LDA #$01
    STA SpriteDir
    INC SpriteRow
    JMP SpriteRowDone
SpriteFlipUp:
    LDA #$00
    STA SpriteDir
    DEC SpriteRow
SpriteRowDone:

; -----------------------------------------------------------------------------
; 7. REBUILD THE SPRITE STRIP — clear 48 bytes, then stamp the 8-byte shape
; -----------------------------------------------------------------------------
; The strip lives in RAM and is rebuilt every frame: clearing it makes the
; diamond's old row disappear, so the picture can move without erasing a
; previous position.  The stamp starts at SpriteRow (1..40), so the shape's
; last byte is at index 47 at most.  X is the strip index; Y walks the shape.
    LDA #$00
    LDX #SPRITE_LINES
ClearStrip:
    DEX
    STA SpriteStrip,X
    BNE ClearStrip

    LDA SpriteRow
SpriteRowWrite:             ; checkpoint: A = the diamond's top strip row
    TAX
    LDY #0
StampShape:
    LDA SpriteShape,Y
    STA SpriteStrip,X       ; zero-page,X: $A0-$CF
    INX
    INY
    CPY #SPRITE_SHAPE
    BNE StampShape

; -----------------------------------------------------------------------------
; 8. PRELOAD BAND 2'S LIBRARY STATE
; -----------------------------------------------------------------------------
; KernelFill (band 1) never touches KernelPtr or KernelRows, so the values for
; band 2 can be loaded here, where there is plenty of time.  Loading them at
; the band-2 boundary would push the first WSYNC past the line and make the band a line too long.
    LDA #PF_ROWS
    LDX #<PFTable
    LDY #>PFTable
Band2Setup:                 ; checkpoint: A = KernelRows, X/Y = the PF pointer
    STA KernelRows
    STX KernelPtr
    STY KernelPtr+1

; -----------------------------------------------------------------------------
; 9. POSITION P0 FOR THE SPRITE BAND, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; The diamond is the only player object in the frame.  SetCoarseP0 has set
; HMP0 and strobed RESP0; one WSYNC starts a fresh line and one HMOVE applies
; the fine offset in its HBLANK.  The HMOVE is inside VBLANK, so its left-edge
; blanking is invisible.
    LDA #(SPRITE_X + POS_BIAS)
    JSR SetCoarseP0
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed
    NOP                     ; keep HmoveDone distinct from the timer poll

; -----------------------------------------------------------------------------
; 10. PRELOAD BAND 1 — its colour is latched before the picture turns on
; -----------------------------------------------------------------------------
    LDA FillColor
    STA COLUBK              ; band 1's solid colour from visible line 0
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines in four 48-line bands, work-first
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; =============================================================================
; BAND 1 — KernelFill: 48 solid lines (visible 0-47)
; =============================================================================
; The colour was preloaded in VBLANK, so the boundary's only job is to pass
; the colour and the line count.  PatternWrite reports the fill colour.
    LDA FillColor
PatternWrite:               ; checkpoint: A = the first band's fill colour
    LDX #BAND_LINES
    JSR KernelFill

; =============================================================================
; BAND 2 — KernelPFRows: 24 rows x 2 lines (visible 48-95)
; =============================================================================
; KernelFill's last WSYNC releases the CPU at scanline 85 (visible line 48).
; The background store (COLUBK) must beat pixel 0, and the playfield colour
; should be ready before the first pattern row; both are stored here, and both
; complete before cycle 22.7.  PF0-PF2 and GRP0/GRP1 are already zero (band 1
; wrote only COLUBK), so a redundant clear is skipped: it would push the
; routine's first WSYNC past the end of the line and lengthen the band by one
; scanline.  Row 0 of the table is blank, so the boundary's own late first-row
; stores land on a blank line.
    LDA PFColor
    STA COLUPF              ; the checkerboard's colour
    LDA #C_BG
    STA COLUBK              ; the gaps show the background
    JSR KernelPFRows

; =============================================================================
; BAND 3 — KernelSpriteStrip: 48 lines (visible 96-143)
; =============================================================================
; KernelPFRows' last WSYNC releases the CPU at scanline 133 (visible line 96).
; Band 2 leaves the playfield dirty, so the PF clear comes first: PF0's field
; starts at pixel 0, PF1's at pixel 16, PF2's at pixel 48.  GRP0/GRP1 are
; still zero because band 2 never wrote them.  The strip's row 0 is zero, so
; the band's first line is blank by construction.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA SpriteColor
    STA COLUP0              ; the diamond's colour
    LDA #C_BG
    STA COLUBK              ; the band stays dark around the diamond
    LDA #SPRITE_LINES
    LDX #<SpriteStrip
    LDY #>SpriteStrip
Band3Setup:                 ; checkpoint: A = KernelRows, X/Y = the strip pointer
    STA KernelRows
    STX KernelPtr
    STY KernelPtr+1
    JSR KernelSpriteStrip

; =============================================================================
; BAND 4 — KernelColorRamp: 48 lines (visible 144-191)
; =============================================================================
; KernelSpriteStrip's last WSYNC releases the CPU at scanline 181 (visible
; line 144).  The ramp's first colour is the store that must beat pixel 0, so
; it goes first.  Band 3 leaves GRP0 dirty (its last strip row may hold shape
; bytes); clear it, but leave PF0-PF2 alone: band 3's boundary already
; cleared them and its routine writes only GRP0.  GRP1 is cleared too:
; nothing ever writes it, but the pair costs only six cycles and keeps the
; boundary symmetric.
    LDA RampFirst
    STA COLUBK              ; the ramp's top colour, before pixel 0
    LDA #$00
    STA GRP0                ; the diamond must not leak into the ramp
    STA GRP1
    LDA #BAND_LINES
    LDX RampLo
    LDY RampHi
Band4Setup:                 ; checkpoint: A = KernelRows, X/Y = the ramp pointer
    STA KernelRows
    STX KernelPtr
    STY KernelPtr+1
    JSR KernelColorRamp
; 48 lines x 1 colour = visible 144-191.  The last WSYNC releases the CPU at
; scanline 229, the first overscan line.

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
; AdvancePalette — the next palette, wrapping 2 -> 0
; =============================================================================
; A is the new palette when the routine returns.  PaletteStep is after the
; store, so a breakpoint there reports the value the rest of the frame uses.
AdvancePalette:
    LDA Palette
    CLC
    ADC #$01
    CMP #PALETTE_COUNT
    BCC AdvanceStore
    LDA #$00
AdvanceStore:
    STA Palette
PaletteStep:                ; checkpoint: A = the new palette
    RTS

; =============================================================================
; SetCoarseP0 — the Lesson 26 divide-by-15 positioning dance
; =============================================================================
; A = the desired left edge + POS_BIAS.  The first WSYNC starts a fresh line;
; each iteration of the loop is 5 cycles = 15 colour clocks, which is why
; dividing by 15 works.  The remainder becomes HMP0's fine value and RESP0
; strobes the coarse position.  The caller's HMOVE applies the fine offset.
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
; THE PALETTE TABLE — five bytes per palette
; =============================================================================
;   0 fill colour
;   1 playfield colour
;   2 sprite colour
;   3 ramp pointer low
;   4 ramp pointer high
;
; Palette 0 is the sampler's default: teal-green, gold, white, red-to-blue.
; Palette 1 changes every colour and reverses the ramp.  Palette 2 returns the
; ramp to red-to-blue and changes the colours again.
PaletteTable:
    !byte $B8, $1A, $0E, <RampFwd, >RampFwd
    !byte $84, $C8, $1A, <RampRev, >RampRev
    !byte $42, $0E, $C8, <RampFwd, >RampFwd

; =============================================================================
; THE PLAYFIELD TABLE — 24 rows x 3 bytes (PF0, PF1, PF2)
; =============================================================================
; Row 0 is blank: it is the band's top margin, and it lets the boundary's late
; first-row stores land without a visible tear.  Rows 1-23 alternate two
; four-pixel checkerboard phases:
;
;   A: chunks 0,2 / 6,8,10 / 12,14,16,18
;   B: chunks 1,3 / 5,7,9,11 / 13,15,17,19
;
; Chunk 4 is dark in both phases on purpose.  Its field starts at pixel 16
; (cycle 28), one cycle after PF1's store completes at cycle 27, so a bit that
; changed there would be a one-cycle race; keeping it constant makes the late
; store safe.  CTRLPF=$01 reflects the left half, so the right half mirrors
; this pattern.
;
; The table is page-aligned: KernelPtr advances 0,3,6,...,69, so the low byte
; never carries and (KernelPtr),Y never crosses a page.
    !align 255, 0
PFTable:
    !byte $00,$00,$00       ; row 0: the boundary line stays blank
    !byte $50,$2A,$55       ; row  1: chunks 0,2 / 6,8,10 / 12,14,16,18
    !byte $A0,$55,$AA       ; row  2: chunks 1,3 / 5,7,9,11 / 13,15,17,19
    !byte $50,$2A,$55       ; row  3
    !byte $A0,$55,$AA       ; row  4
    !byte $50,$2A,$55       ; row  5
    !byte $A0,$55,$AA       ; row  6
    !byte $50,$2A,$55       ; row  7
    !byte $A0,$55,$AA       ; row  8
    !byte $50,$2A,$55       ; row  9
    !byte $A0,$55,$AA       ; row 10
    !byte $50,$2A,$55       ; row 11
    !byte $A0,$55,$AA       ; row 12
    !byte $50,$2A,$55       ; row 13
    !byte $A0,$55,$AA       ; row 14
    !byte $50,$2A,$55       ; row 15
    !byte $A0,$55,$AA       ; row 16
    !byte $50,$2A,$55       ; row 17
    !byte $A0,$55,$AA       ; row 18
    !byte $50,$2A,$55       ; row 19
    !byte $A0,$55,$AA       ; row 20
    !byte $50,$2A,$55       ; row 21
    !byte $A0,$55,$AA       ; row 22
    !byte $50,$2A,$55       ; row 23

; =============================================================================
; THE SPRITE SHAPE — eight bytes, one per scanline
; =============================================================================
; A diamond two, four, six and eight pixels wide, then narrowing again.  The
; stamp copies these bytes into the 48-byte strip in VBLANK.
SpriteShape:
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18

; =============================================================================
; THE COLOUR RAMPS — 48 entries, stored twice
; =============================================================================
; Six 8-line steps: red $46, pink $56, light violet $66, violet $76, blue $86,
; deeper blue $84.  The second copy is not decoration: a 48-line window that
; starts at offset 24 (the phase exercise) must stay contiguous, so the ramp
; is stored twice and `RampFwd`/`RampRev` + 24 is still a valid 48-byte window.
RampFwd:
    !fill 8, $46            ; visible 0-7 of the ramp: red
    !fill 8, $56            ; pink
    !fill 8, $66            ; light violet
    !fill 8, $76            ; violet
    !fill 8, $86            ; blue
    !fill 8, $84            ; deeper blue
    !fill 8, $46            ; the second copy starts here
    !fill 8, $56
    !fill 8, $66
    !fill 8, $76
    !fill 8, $86
    !fill 8, $84

RampRev:
    !fill 8, $84            ; blue at the top
    !fill 8, $86
    !fill 8, $76
    !fill 8, $66
    !fill 8, $56
    !fill 8, $46            ; red at the bottom
    !fill 8, $84            ; the second copy
    !fill 8, $86
    !fill 8, $76
    !fill 8, $66
    !fill 8, $56
    !fill 8, $46

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
> `lessons/part7-kernel-mastery/53-kernel-patterns/53-kernel-patterns.asm`.
> The library it sources lives in `include/kernel_patterns.asm`.

### Code Walkthrough

#### Step 1 — The frame skeleton

```asm
StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    ; ... the palette, the strip, the HMOVE ...
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

BodyStart:
    ; ... the four bands ...
```

The frame is the Part 2–7 skeleton: 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines. `StartFrame` is scanline 259, `VblankStart` 0, `BodyStart` 37 and `OverscanStart` 229. The state log confirms all four.

#### Step 2 — The palette

```asm
    LDA Palette
PaletteRead:
    ASL
    ASL
    CLC
    ADC Palette             ; A = 5 * Palette
    TAX
    LDA PaletteTable+0,X
    STA FillColor
    ...
```

The table lookup is Lesson 11's indexed read with a small piece of arithmetic: `4 * Palette + Palette = 5 * Palette`. The five bytes are copied into fixed zero-page variables so the band boundaries can load a colour with a three-cycle absolute load, not an indexed one. The palette is read once per frame, even when it has not changed.

#### Step 3 — The sprite strip

```asm
    LDA #$00
    LDX #SPRITE_LINES
ClearStrip:
    DEX
    STA SpriteStrip,X
    BNE ClearStrip

    LDA SpriteRow
SpriteRowWrite:
    TAX
    LDY #0
StampShape:
    LDA SpriteShape,Y
    STA SpriteStrip,X
    INX
    INY
    CPY #SPRITE_SHAPE
    BNE StampShape
```

The strip is rebuilt every frame: clearing it removes the diamond's old position, and stamping it writes the new one. `X` is the strip index (0–47) and `Y` walks the eight shape bytes. The zero-page indexed store `STA SpriteStrip,X` is four cycles, and the clamp guarantees that `SpriteRow + 7 <= 47`.

#### Step 4 — One HMOVE

```asm
    LDA #(SPRITE_X + POS_BIAS)
    JSR SetCoarseP0
HmoveApply:
    STA WSYNC
    STA HMOVE
HmoveDone:
    NOP
```

`SetCoarseP0` sets `HMP0` and strobes `RESP0`; the `WSYNC` starts a fresh line and the `HMOVE` applies the fine offset in its horizontal blank. The HMOVE falls on scanline 13, inside VBLANK, so its left-edge blanking is invisible. There is no second HMOVE in the frame.

#### Step 5 — Band 1: the fill

```asm
    LDA FillColor
PatternWrite:
    LDX #BAND_LINES
    JSR KernelFill
```

The fill colour was preloaded in VBLANK. The boundary is two loads and a call; the routine's first store completes at cycle 18, before pixel 0, and every line after that is identical.

#### Step 6 — Band 2: the playfield

```asm
    LDA PFColor
    STA COLUPF
    LDA #C_BG
    STA COLUBK
    JSR KernelPFRows
```

The two colour stores complete before cycle 22.7. The pointer and the row count were set in VBLANK; the routine's first `WSYNC` lands inside the boundary line, so the band is exactly 48 lines. Row 0 of the table is blank, so the boundary's late first-row stores have a safe line.

#### Step 7 — Band 3: the sprite band

```asm
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA SpriteColor
    STA COLUP0
    LDA #C_BG
    STA COLUBK
    ...
    LDA #SPRITE_LINES
    LDX #<SpriteStrip
    LDY #>SpriteStrip
Band3Setup:
    STA KernelRows
    STX KernelPtr
    STY KernelPtr+1
    JSR KernelSpriteStrip
```

The playfield is dirty from band 2, so its clear comes first. The strip's row 0 is zero, so the band's first visible line is blank even if the boundary's stores are a few cycles late. `Band3Setup` reports `A = 48`, `X = $A0`, `Y = $00`.

#### Step 8 — Band 4: the ramp

```asm
    LDA RampFirst
    STA COLUBK
    LDA #$00
    STA GRP0
    STA GRP1
    ...
    LDA #BAND_LINES
    LDX RampLo
    LDY RampHi
Band4Setup:
    STA KernelRows
    STX KernelPtr
    STY KernelPtr+1
    JSR KernelColorRamp
```

The ramp's first colour is the one store that must beat pixel 0, so it goes first. `GRP0` is cleared because the sprite band's last strip row may still hold a shape byte; `PF0`–`PF2` are already zero. `Band4Setup` reports `A = 48` and the ramp pointer.

#### Step 9 — Reading it back in Stella

Assemble with a symbol file and ask Stella for the checkpoints:

```bash
acme -f plain -l build/lesson53.sym -o build/lesson53.bin \
  lessons/part7-kernel-mastery/53-kernel-patterns/53-kernel-patterns.asm

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F1AF' build/lesson53.bin
```

Run each checkpoint separately for a readable log. The addresses below are the ones this source produced. A breakpoint on a label reports the first cycle of the instruction that follows it.

### Checkpoints

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F08F` | 259/3 | the first VSYNC line |
| `VblankStart` | `$F09D` | 0/5 | the first VBLANK line |
| `BodyStart` | `$F1AF` | 37/5 | visible line 0 |
| `OverscanStart` | `$F1F9` | 229/13 | the first blank line after the picture |
| `PatternStart` | `$F136` | A=0, 1, 2, 3 | the frame's band plan, reported in VBLANK |
| `PatternCount` | `$F10B` | A=4 | the number of bands |
| `PatternWrite` | `$F1B1` | A=`$B8` | the first band's fill colour |
| `Band2Setup` | `$F184` | A=`$18`, X=`$00`, Y=`$F3` | `KernelRows`=24, `KernelPtr`=`$F300` (the PF table) |
| `Band3Setup` | `$F1D7` | A=`$30`, X=`$A0`, Y=`$00` | `KernelRows`=48, `KernelPtr`=`$00A0` (the strip) |
| `Band4Setup` | `$F1F0` | A=`$30`, X=`$50`, Y=`$F3` | `KernelRows`=48, `KernelPtr`=`$F350` (the forward ramp) |
| `HmoveApply` | `$F18F` | 12/53 | the `WSYNC` before the `HMOVE` |
| `HmoveDone` | `$F193` | 13/3 | the `NOP` after the `HMOVE` store; the store completes at 13/2 |
| `PaletteRead` | `$F10E` | A=0 | the palette index, once per frame |
| `PaletteStep` | `$F219` | A=1 at frame 240, A=2 at 480, A=0 at 720 | a palette change |
| `SelectReset` | `$F0F1` | A=0 at frame 1 | SELECT's reset, under `-holdselect` |
| `SpriteRowWrite` | `$F170` | A=2, 3, 4, … | the diamond's top strip row, one per frame |

## What You Should See

The picture is four horizontal bands, each exactly 48 visible lines tall:

- **Visible 0–47 — the fill.** One solid colour: teal-green `$B8` in the default palette.
- **Visible 48–95 — the checkerboard.** A gold `$1A` four-pixel checkerboard, two lines per row. Row 0 is blank, so the first two lines are the dark background; the pattern then alternates for 23 rows. A constant dark column at chunk 4 (and its mirror) divides the band into three panels.
- **Visible 96–143 — the diamond.** A dark `$02` band with an eight-line white `$0E` diamond at TIA X=76. The diamond's row advances by one per frame, so a still capture shows it at one row; the state log's `SpriteRowWrite` shows the sweep.
- **Visible 144–191 — the gradient.** Six eight-line steps from red `$46` at the top to deeper blue `$84` at the bottom.

![Stella running the Lesson 53 ROM with palette 0: a teal-green fill band, a gold checkerboard band, a dark band with a white eight-line diamond, and a red-to-blue gradient, in four equal 48-line bands; the title bar reads Stella 7.0: "53-kernel-patterns"](/images/lesson53/sampler.png)

*`sampler`: palette 0. The fill is `$B8` (capture RGB 73,177,142), the checkerboard is `$1A` (205,205,52), the diamond is `$0E` (234,234,233) at visible lines 124–131, and the ramp runs `$46`→`$84`. The four bands measure 0–47, 48–95, 96–143 and 144–191.*

<RomPlayer rom="/roms/part7-kernel-mastery/53-kernel-patterns/53-kernel-patterns.bin" title="Lesson 53 — Kernel Design Patterns" />

![Stella running the Lesson 53 ROM with palette 1: a blue fill band, a green checkerboard band, a dark band with a gold eight-line diamond, and a blue-to-red gradient; the title bar reads Stella 7.0: "53-kernel-patterns"](/images/lesson53/palette.png)

*`palette`: palette 1, the state fire selects (the auto-demo also reaches it after 240 frames). The fill is `$84` (36,40,176), the checkerboard is `$C8` (81,179,80), the diamond is `$1A` (205,205,52) at visible lines 110–117, and the ramp is reversed: `$84` at the top, `$46` at the bottom. Every band's colour changed; the geometry did not.*

> **Capture method.** Both images are window captures of
> `docs/public/roms/part7-kernel-mastery/53-kernel-patterns/53-kernel-patterns.bin`
> in Stella 7.0. The pointer was parked at `(0, 0)` before the burst; the title bars read
> `Stella 7.0: "53-kernel-patterns"`. The diamond moves one strip row per frame, so a single
> timed capture cannot be aimed at a chosen row. Stella was launched on the committed ROM,
> a burst of window captures was taken with the same `xwininfo` lookup the screenshot script
> uses, and each capture was classified by measuring the fill band's colour and the diamond's
> visible row. The two images are from those bursts, unchanged apart from the window frame.
> Palette 1 was reached by the auto-demo's 240-frame clock. The fire edge is proven separately
> by the state log: a fire press at frame ~70 produced `PaletteStep` A=`$01` at frame 73, while
> the auto-demo's first step is frame 240.

The ROM needs no input: the diamond sweeps 1→40→1 and the palette advances every 240 frames, so both captures are reachable without a key press. The joystick is not read in this lesson; fire and SELECT are the only controls.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
ROM=docs/public/roms/part7-kernel-mastery/53-kernel-patterns/53-kernel-patterns.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1AF' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1F9' $ROM   # OverscanStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F136' $ROM   # PatternStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F184' $ROM   # Band2Setup
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1D7' $ROM   # Band3Setup
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1F0' $ROM   # Band4Setup
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F219' $ROM   # PaletteStep
```

- **`$F1AF` (`BodyStart`)** is **37/5**, **`$F1F9` (`OverscanStart`)** **229/13**: 3 + 37 + 192 + 30 = 262 lines, and 229 − 37 = 192 visible lines.
- **`$F136` (`PatternStart`)** reports A=0, 1, 2, 3 on four hits in the same frame (scanline 2), and **`$F10B` (`PatternCount`)** reports A=4. **`$F1B1` (`PatternWrite`)** reports A=`$B8`.
- **`$F184` (`Band2Setup`)** reports A=`$18` (24 rows), X=`$00`, Y=`$F3`: `KernelRows`=$18 and `KernelPtr`=$F300. **`$F1D7` (`Band3Setup`)** reports A=`$30` (48 lines), X=`$A0`, Y=`$00`: the strip at $00A0. **`$F1F0` (`Band4Setup`)** reports A=`$30`, X=`$50`, Y=`$F3`: the forward ramp at $F350.
- **`$F219` (`PaletteStep`)** reports A=`$01` at frame 240, A=`$02` at frame 480 and A=`$00` at frame 720: one palette every 240 frames (four seconds), then back to the start. Under `-holdselect`, **`$F0F1` (`SelectReset`)** reports A=`$00` at frame 1. A fire press at frame ~70 produced A=`$01` at frame 73.
- **`$F170` (`SpriteRowWrite`)** reports A=2, 3, 4, … on consecutive frames: the diamond's top strip row, one per frame.
- **`$F18F` (`HmoveApply`)** is the `WSYNC` at 12/53 and **`$F193` (`HmoveDone`)** the `NOP` at 13/3: one `HMOVE`, in VBLANK.

The pixel checks decode the captures with `capture x = 25 + 6 × TIA X` and `capture y = 107 + 3.15 × visible line`:

| Check | `sampler.png` | `palette.png` | Expected |
|---|---|---|---|
| band boundaries | 0–47, 48–95, 96–143, 144–191 | the same | four 48-line bands |
| fill colour | `$B8` (73,177,142) | `$84` (36,40,176) | the palette's fill |
| playfield colour | `$1A` (205,205,52) | `$C8` (81,179,80) | the palette's PF colour |
| checkerboard rows | 24 rows of two lines; row 0 blank, then A/B alternating | the same | 24 rows × 2 lines |
| chunk-4 column | dark in both phases | dark in both phases | the timing-safe column |
| diamond rows | visible 124–131 | visible 110–117 | eight lines, one strip row apart |
| diamond widths | 2, 4, 6, 8, 8, 6, 4, 2 TIA px | the same | the eight-byte shape |
| diamond X | 76–83 | 76–83 | `SPRITE_X` = 76 |
| ramp steps | `$46,$56,$66,$76,$86,$84` | `$84,$86,$76,$66,$56,$46` | forward / reversed |
| ramp step size | 8 visible lines each | 8 visible lines each | 48 entries / 6 steps |

The screenshots prove the visual state; the state log proves the values, the lines and the cycle. The thing a still cannot prove is the diamond's motion: the two captures show it at two different rows, and `SpriteRowWrite` proves the one-row-per-frame sweep.

## Exercises

### Exercise 1: A Fifth Pattern

**Challenge:** split the sampler into five bands instead of four and add a second `KernelFill` band. The line budget is 38 + 38 + 38 + 38 + 40 = 192, and `PatternCount` must report 5.

**Hints:**
1. The playfield band is 38 lines, so `PF_ROWS` becomes 19 (19 rows × 2 lines). The sprite strip becomes 38 bytes, so its row clamp becomes 1–30.
2. The second fill band comes after the sprite strip. Its boundary must store the new `COLUBK` before pixel 0 and clear `GRP0` (the strip's last row may hold a shape byte).
3. `KernelFill` takes its colour in `A`, so reload `A` with the fill colour after the clears and before the `JSR`.
4. The band plan loop in VBLANK compares against `BAND_COUNT`; raise it to 5.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `PatternCount` reports A=5 and `PatternStart` reports A=0…4; the bands start at visible 0, 38, 76, 114 and 152; the second fill is the palette's playfield colour (gold in palette 0); `OverscanStart` is still 229, so the five bands total 192 lines.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Ramp Offset

**Challenge:** make SELECT shift the colour-ramp table by 24 lines. The new variable `RampPhase` must alternate 0 and 24, and the gradient must rotate: at phase 24 the top of the ramp is the violet row (`$76`) and the bottom is the light-violet row (`$66`).

**Hints:**
1. The ramp table is already stored twice (96 bytes), so a 48-byte window from offset 24 is contiguous: `RampFwd`/`RampRev` + 24 is a valid 48-entry ramp.
2. Add the phase to the ramp pointer in VBLANK, after the palette table has supplied the base pointer. Propagate the carry into the pointer's high byte with `ADC #$00`.
3. Recompute `RampFirst` from the phased pointer (`LDY #0; LDA (RampLo),Y; STA RampFirst`). The band-4 boundary uses that byte, so the first line stays clean for both phases.
4. SELECT becomes `LDA RampPhase; EOR #$18; STA RampPhase` (0 xor 24 = 24, 24 xor 24 = 0), then beep.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; under `-holdselect`, `RampPhaseWrite` reports A=`$18` (24) on frame 1; the ramp's top colour becomes `$76` and its bottom `$66`; with no SELECT press the ramp is phase 0 and unchanged from the base lesson. The band boundaries and `OverscanStart` 229 do not move.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Reorder the Bands *(Stretch Goal)*

**Challenge:** drive the band order from a `PatternOrder` table. The solution's order is 1, 3, 0, 2 — playfield, ramp, fill, sprite — so the picture is the same four patterns stacked in a different order. The same four library routines must run, and the build must pass.

**Hints:**
1. The four band bodies are macros (`BandFill`, `BandPF`, `BandSprite`, `BandRamp`); a four-way selector macro turns an order value into one of them. An ACME `!for` loop walks the four slots.
2. The order is applied at **assembly** time. A runtime dispatch loop would add about 25 cycles before every boundary, push each band's first `WSYNC` past its line, and force the line counts to change. The table is also emitted as data so the VBLANK plan loop can report the order.
3. The playfield band is now first, so its `KernelPtr`/`KernelRows` are loaded in VBLANK (`Band1Setup`), exactly as the base lesson preloads band 2.
4. The ramp follows the playfield. Its first store is `COLUBK`, which beats pixel 0; the PF clear afterwards can be one pixel late, so make the playfield table's last row blank to keep that pixel invisible.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `PatternStart` reports A=1, 3, 0, 2; the visible order is playfield (0–47), ramp (48–95), fill (96–143), sprite (144–191); `OverscanStart` is still 229. The build passes and the four routines are the same ones the base lesson calls.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **The four kernel shapes are a library.** A solid fill, a two-line playfield, a one-line sprite strip and a colour ramp cover most 2600 bands; each is a short loop behind a pointer-plus-count API.
- ✅ **The pointer must be in zero page.** `LDA (KernelPtr),Y` is the only indirect indexed mode, and it costs five cycles (six on a page cross). A page-aligned table keeps the index inside one page.
- ✅ **The ledgers are the contract.** Fill 11/line, playfield rows 57 per row (28.5/line), sprite strip and colour ramp 19/line. The 76-cycle line and the 152-cycle pair leave 57 and 95 cycles of margin.
- ✅ **The caller owns the boundary.** The routines write only their own object; the caller clears the dirty registers and sets the next band's colours, with the pixel-0 store first and redundant clears skipped.
- ✅ **The first `WSYNC` must stay inside the boundary line.** If it slips, the band grows by one scanline and the 192-line total fails; `BodyStart` 37 and `OverscanStart` 229 are the proof that it did not slip.
- ✅ **The playfield's late `PF1` store is visible in the data design.** Chunk 4 is held constant in both checkerboard phases because `PF1` completes at cycle 27, one cycle before the chunk's left edge at cycle 28.
- ✅ **A table can order the bands, but the order is a build-time decision.** A runtime dispatcher costs about 25 cycles per boundary; the static order keeps the sampler's 192-line body exact.

## What's Next

The sampler proves that the patterns can be packaged and combined, but it uses each one once. [Lesson 54: Visual Effects Cookbook — Starfields, Rainbows, Pseudo-3D](/part7-kernel-mastery/54-visual-effects-cookbook) turns the patterns into three full-screen effects — a scrolling starfield, a rainbow, and a pseudo-3D road — and measures what each effect costs per line.
