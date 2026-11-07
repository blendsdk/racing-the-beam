---
title: "Lesson 68: Designing Your Kernel Architecture — A Zone Framework"
description: "Design a reusable Atari 2600 kernel architecture: compose a 192-line frame from configurable display zones, enforce the line budget at assembly time with an ACME !error, select among three layouts at run time with a branch dispatcher, and understand the boundary line, the band-boundary contract, and the 13-cycle overscan tax."
prev:
  text: "Lesson 67: Identifying Automatable Patterns — A Wave Compiler"
  link: "/part9-dsl-path/67-automatable-patterns"
next:
  text: "Lesson 69: Capstone 1 — Pong"
  link: "/part10-capstones/69-pong"
---

# Lesson 68: Designing Your Kernel Architecture — A Zone Framework

> **Part 9: The DSL Path** · Estimated time: 110 minutes
> **Prerequisites:** Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and memory), Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players), Lesson 26 (positioning), Lesson 48 (the kernel taxonomy), Lesson 49 (the two-line kernel), Lesson 50 (the multi-zone kernel), Lesson 53 (kernel patterns), Lesson 55 (text), Lesson 67 (generated data)
> **You will learn:** how to read a kernel as a schedule of bands; how a zone macro differs from a runtime descriptor; why every zone owns a boundary line; how a 192-line budget becomes an assembly-time assertion; which objects the next band expects (the band-boundary contract); how a one-byte selector dispatches to three layouts without a ROM jump vector; why the dispatch/return chain reaches the overscan at 229/19; and where a generator would emit zone calls — the bridge from a hand-written kernel to a layout DSL.
> **You will build:** **the zone gallery**, a 4,096-byte ROM whose 192-line picture is assembled from the same four band macros in three different orders. STATUS draws a solid band, a playfield, a sprite strip and a moving colour ramp; STARFIELD draws a ramp, a star strip, a star playfield and a black fill; SPLIT draws two playfields with a strip between them. SELECT and a 240-frame auto-demo cycle the layouts. The framework lives in `include/kernel_framework.asm`; the exercise solutions add a ball band, a fourth layout, and a scrolling star strip.

## Introduction

The course built the machine, the CPU and the TIA lesson by lesson. Part 7 packaged the recurring shapes: Lesson 49 the two-line kernel, Lesson 50 the multi-zone kernel, Lesson 53 the four band patterns — a solid fill, a two-line playfield, a one-line sprite strip, and a per-line colour ramp. By Lesson 67 you had a generator that lowers a level description into data tables for a hand-written engine. The data became flexible; the kernel stayed fixed.

This lesson makes the kernel flexible. A real game screen is not one shape. It has a status band, a play area, a score band, sometimes a horizon. Each shape has its own loop and its own cycle budget, and each boundary between shapes is a place where the TIA must already hold the next shape's colour, objects and table pointer. Hand-counting the lines and hand-writing every boundary is how a picture rolls: one missing `WSYNC`, one extra data line, and the frame is 261 or 263 lines instead of 262.

The companion program, `68-kernel-architecture.asm`, is **the zone gallery**: three 192-line layouts composed from the same four band macros. Each macro is one zone — a boundary line plus a call to one of the Lesson 53 routines. The framework in `include/kernel_framework.asm` counts the zones at assembly time and refuses to build a layout that is not exactly 192 lines. One byte, `Layout`, selects a layout at run time with a branch dispatcher. The three layouts are deliberately different: a status-like gallery with a moving colour ramp, a starfield with a sparse star strip and a mirrored playfield, and a split screen with two playfields and a strip between them.

The interesting parts are the ones that do not show up in a screenshot: the boundary line, the 13-cycle dispatch tax at the overscan, the `$80–$82` RAM collision that a preflight scratch build hit, and the fact that a jump vector written into ROM cannot select anything. The lesson is about making those constraints part of the architecture instead of surprises.

::: details TypeScript Equivalent

A zone framework looks natural in TypeScript: a layout is an array of zone objects, a budget function sums the zone costs, an assertion checks 192, and a dispatch function picks a layout.

```typescript
type Zone =
  | { kind: 'fill';   color: number; dataLines: number }
  | { kind: 'pf';     color: number; rows: number; table: number[] }
  | { kind: 'strip';  color: number; dataLines: number; table: number[] }
  | { kind: 'ramp';   dataLines: number; table: number[] }
  | { kind: 'custom'; dataLines: number; draw: (line: number, frame: number) => number };

interface Layout { name: string; zones: Zone[]; }

const STATUS: Layout = {
  name: 'STATUS',
  zones: [
    { kind: 'fill',  color: 0x02, dataLines: 15 },
    { kind: 'pf',    color: 0x1A, rows: 24, table: PFDataA },
    { kind: 'strip', color: 0xC8, dataLines: 48, table: StripDataA },
    { kind: 'ramp',  dataLines: 77, table: RampDataA },
  ],
};

// Every zone owns its data lines plus one boundary line.
function zoneLines(zone: Zone): number {
  const data = zone.kind === 'pf' ? zone.rows * 2 : zone.dataLines;
  return data + 1;
}

function budget(layout: Layout): number {
  return layout.zones.reduce((total, zone) => total + zoneLines(zone), 0);
}

function assert192(layout: Layout): void {
  const lines = budget(layout);
  if (lines !== 192) throw new Error(`${layout.name}: ${lines} lines, expected 192`);
}

// The selector is a single byte in the ROM, not an object reference.
function dispatch(layout: number): Layout {
  return [STATUS, STARFIELD, SPLIT][layout] ?? STATUS;
}
```

The model captures the shape — a typed tree, a budget check, a dispatch — and it breaks exactly where the 2600 differs:

- **There is no zone array in the ROM.** The macros expand into straight-line code. The "array" exists in the source; the CPU executes a fixed sequence of stores and `JSR`s. A layout is code, not data.
- **`assert192` is an assembler directive.** In the ROM the check is `+kf_end`'s `!error`, evaluated while ACME assembles. There is no runtime exception and no `Layout` object; `Layout` is one byte at `$83`.
- **`draw` is a `JSR`, and the zone costs real cycles and a boundary line.** The TypeScript call is free; the real handler returns at cycle 10 or 13, its caller needs the rest of that line to set up the next zone, and the next zone's boundary line is part of the 192.
- **The tables are pointers and one length byte.** `KernelPtr`/`KernelRows` replace an array object; there is no length field, no bounds check and no allocation. A table may live in ROM or in RAM.
- **The colour is a TIA byte written to a register.** `0x1A` is not an RGB value; it is the hardware's gold. The palette is the console's.
- **The boundary line has no TypeScript analogue.** Calling a function does not consume a scanline; `+kf_strip` does.

:::

## Theory

### Section 1: The Kernel as a Schedule of Bands

The 2600 has no frame buffer. The kernel is the code that visits all 192 visible scanlines every frame, and the only state it carries between lines is the TIA's registers and the CPU's registers. A fixed kernel repeats one shape 192 times or 96 times; a multi-zone kernel breaks the picture into bands and gives each band its own loop. Lesson 50 built a three-zone picture by hand. This lesson turns that hand-built structure into a reusable schedule.

A **zone** is one band plus the routine that draws it. A **layout** is an ordered list of zones. The kernel is the layout, executed once per frame. The schedule has a hard budget: the visible area is 192 scanlines on NTSC, and every zone consumes its data lines plus one **boundary line** — the line on which the next zone is set up. That line is visible and is part of the picture:

```text
zone cost = data lines + 1 boundary line
```

The gallery's three layouts are four zones each, with 188 data lines and four boundary lines:

| Layout | Zone 1 | Zone 2 | Zone 3 | Zone 4 | Data | Boundaries | Total |
|---|---|---|---:|---:|---:|---:|---:|
| STATUS | fill 15 | PF 24 rows (48) | strip 48 | ramp 77 | 188 | 4 | 192 |
| STARFIELD | ramp 31 | strip 95 | PF 16 rows (32) | fill 30 | 188 | 4 | 192 |
| SPLIT | PF 24 rows (48) | strip 31 | PF 24 rows (48) | ramp 61 | 188 | 4 | 192 |

The frame around the schedule is the Lesson 12 skeleton: 3 VSYNC lines, 37 VBLANK lines, 192 picture lines and 30 overscan lines, 262 in all. The first boundary line is `BodyStart` at scanline 37. The last data line is picture line 191 at scanline 228. The dispatch and return chain reaches the overscan at scanline 229.

The difference from a fixed kernel is not the drawing code. `KernelFill`, `KernelPFRows`, `KernelSpriteStrip` and `KernelColorRamp` are exactly the Lesson 53 routines. The difference is the layer above them: the framework owns the setup, the cleared objects, the boundary line, the return path and the line budget. A lesson writes a list of bands and the framework makes the list a cycle-exact frame.

::: tip The boundary line is not overhead
It is tempting to count only the data lines and treat the boundary as waste. The boundary is where the TIA is prepared for the next band: the colour, the table pointer, the row count, the objects that must be cleared. The store that changes the leftmost pixel must complete before pixel 0 of the next line; the setup therefore cannot be moved into the data line without moving the change into the visible area. The boundary line is the cheapest place to do the work, and it is part of the 192.
:::

### Section 2: The Zone Macro vs the Runtime Descriptor

There are two ways to make a kernel configurable. The first is a **runtime descriptor table**: each zone is a record — kind, colour, table pointer, row count — and an interpreter reads the records and calls the matching routine. The record format costs ROM or RAM, the interpreter costs a dispatch per zone, and the table must be validated at run time. The second is a **compile-time macro call**: each zone is a macro invocation that expands into the setup, a `STA WSYNC` and a `JSR` to the routine. The layout is straight-line code, the budget is an assembly-time symbol, and there is no per-zone interpreter.

The framework uses the second design. At 4,096 bytes and 76 cycles per line, the 2600 rewards code that is counted at build time over code that is interpreted at run time. A layout that is known before the ROM is built does not need a runtime record; it needs a checked expansion.

The API is eight macros:

| Macro | Parameters | Data lines | Handler | Boundary + data |
|---|---|---:|---|---:|
| `+kf_begin` | — | — | resets the budget | — |
| `+kf_fill` | `.color`, `.dataLines` | `.dataLines` | `KernelFill` | `.dataLines + 1` |
| `+kf_pf` | `.color`, `.rows`, `.table` | `.rows * 2` | `KernelPFRows` | `.rows * 2 + 1` |
| `+kf_strip` | `.color`, `.dataLines`, `.table` | `.dataLines` | `KernelSpriteStrip` | `.dataLines + 1` |
| `+kf_ramp` | `.dataLines`, `.table` | `.dataLines` | `KernelColorRamp` | `.dataLines + 1` |
| `+kf_custom` | `.dataLines`, `.routine` | `.dataLines` | lesson routine | `.dataLines + 1` |
| `+kf_end` | — | — | `!error` unless 192 | — |
| `+kf_dispatch` | `.l0`, `.l1`, `.l2` | — | branch on `Layout` | — |

A `+kf_strip` call expands to the following code. The macro is inlined, so the same shape appears once per strip zone:

```asm
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    LDA #.color
    STA COLUP0
    LDA #<.table
    STA KernelPtr
    LDA #>.table
    STA KernelPtr+1
    LDA #.dataLines
    STA KernelRows
    STA WSYNC
    JSR KernelSpriteStrip
```

The setup is deliberately ordered: the clears come first (the first `PF0` store completes before pixel 0), then the colour, the pointer, the row count, `WSYNC` and the handler. The same ordering appears in every zone macro. The handler reads only `KernelPtr` and `KernelRows`; it has no hidden state.

The `.table` argument is an address expression, not a data structure. A table may be in ROM (`PFDataA`, `StripDataB`, `RampDataC`) or in RAM (`RampDataA` in this lesson). The framework sets the pointer; the handler reads `(KernelPtr),Y`. There is no length field: `KernelRows` is the only count, and the macro supplies it.

`+kf_custom` is the escape hatch. It sets `KernelRows = .dataLines`, ends the boundary line with `WSYNC` and calls the lesson's routine. The routine must draw exactly `.dataLines` lines and return; it owns its colours and objects, and it must leave the TIA ready for the next zone. Exercise 1 uses `+kf_custom` to add a ball band without changing the shared framework; exercise 3 replaces a strip's table with a RAM buffer.

::: tip A macro is a contract, not a function
The macro does not "call a zone object"; it emits the zone's setup and the handler call at the point of invocation. The `JSR`/`RTS` pair is real: it uses the stack, it costs 12 cycles in total, and the handler's return lands at cycle 10 or 13 of the following line. That return point is why every zone needs a boundary line, and it is the first thing a generator must know when it emits zone calls.
:::

### Section 3: The Boundary Line and the Band-Boundary Contract

Trace one boundary. `KernelSpriteStrip` draws its last data line, executes `STA WSYNC`, then `INY` (2), `CPY KernelRows` (3), the not-taken `BNE` (2) and `RTS` (6). It returns 13 cycles into the line after the last data line. `KernelFill` returns at cycle 10 (its last line has no `INY`/`CPY`/`BNE`). The caller — the next zone's macro — resumes at that point and runs its setup on the same line.

The framework header states the contract directly:

```text
A handler returns at cycle 10 (KernelFill) or 13 (the other three) of the
line after its last data line.  The next zone's macro runs its setup during
the rest of that line.
```

The setup clears `PF0`–`PF2`, `GRP0`, `GRP1` and `ENABL` **first**, then sets the zone's colour, table pointer and row count. The first `STA PF0` begins at cycle 13 and completes by cycle 18, before pixel 0 (cycle 22.7), so the previous band's playfield bytes and first player copy cannot leak onto the boundary line. The colour store may land after pixel 0; that is the boundary line's one-line gutter, and the first data line is fully the new band. The setup is 30–45 cycles depending on the zone, so the `STA WSYNC` still ends the boundary line. The `JSR` to the next handler takes 6 cycles, so the handler's first instruction starts 6 cycles into the next line; its first data store completes by about cycle 16, before pixel 0 (cycle 22.7).

The TIA state at a boundary is the **band-boundary contract** from Lesson 53, made explicit:

| Zone | Writes | Clears first on its boundary line |
|---|---|---|
| `+kf_fill` | `COLUBK` | `PF0`–`PF2`, `GRP0`, `GRP1`, `ENABL` |
| `+kf_pf` | `PF0`–`PF2` | `PF0`–`PF2`, `GRP0`, `GRP1`, `ENABL` |
| `+kf_strip` | `GRP0` | `PF0`–`PF2`, `GRP0`, `GRP1`, `ENABL` |
| `+kf_ramp` | `COLUBK` | `PF0`–`PF2`, `GRP0`, `GRP1`, `ENABL` |
| `+kf_custom` | lesson's choice | lesson's responsibility |

The framework writes `GRP1 = 0` on every boundary line; it never writes `ENAM0` or `ENAM1`. A custom routine that uses the missiles must clear them before it returns; the built-in zones do not know about them. `+kf_ramp` is the one built-in zone whose boundary line keeps the previous background: its first data line writes the ramp's first colour. That is the one-line gutter the layout's line count already pays for.

Two boundary cases need special care. The **first** zone's boundary line is `BodyStart`, and the dispatcher plus the setup run after pixel 0. The colour of the first line must therefore already be in the TIA when VBLANK releases the picture. The lesson's **first-line prelude** handles this: VBLANK leaves the first zone's background in `COLUBK` —

- STATUS: the fill's background (`C_BG`),
- STARFIELD: the first byte of the ROM ramp (`RampDataB`),
- SPLIT: the dark background behind the upper playfield (`C_BG2`).

The macro re-stores the colour on the boundary line, so a late store cannot affect the data lines. The three captures confirm the prelude: the first picture line is a single colour across its full width in all three layouts.

The **last** zone must end black. The dispatch/return chain reaches the overscan at scanline 229 cycle 19 instead of the usual cycle 6, and the `STA VBLANK` that blanks the overscan completes at about cycle 24. The visible area of line 229 starts at cycle 22.7, so the first few colour clocks of the overscan line can show the last kernel colour. Every layout therefore ends in black: the STATUS and SPLIT ramps have `$00` as their last byte, and STARFIELD ends in `+kf_fill 0, 30`. The 13-cycle tax is invisible because the last colour is black.

Where do the 13 cycles come from? The last handler returns at cycle 13 of line 229 (13 − 6 = 7 more than a kernel that reaches the overscan directly), and the layout's `RTS` back to `KernelEnd` takes 6 cycles (19). The `LDA #$02` begins at 19; the store completes at 24. The scanline is still 229, and the frame is still 262.

### Section 4: The Build-Time Assertion

The framework header states the rule directly:

```text
Every zone owns one boundary line plus its data lines:

  zone cost = .dataLines + 1

A layout's costs must sum to 192.
```

The budget is an assembly-time symbol, not a comment:

```asm
!macro kf_begin {
    !set KF_TOTAL = 0
}

!macro kf_end {
    !if KF_TOTAL != 192 {
        !error "kf_end: zone budget is ", KF_TOTAL, ", expected 192 (data lines + one boundary line per zone)"
    }
}
```

`!set` is ACME's reassignable assignment. A plain `=` would make the second `+kf_begin` a duplicate-symbol error; `!set` is defined to update the value. Each zone macro adds its cost:

```asm
!set KF_TOTAL = KF_TOTAL + .dataLines + 1
```

A 191-line layout stops the build with the number in the message. The negative test in this lesson's evidence is a scratch copy with `+kf_fill C_BG, 15` changed to `14`:

```text
Error - File include/kernel_framework.asm, line 335 (Macro kf_end):
!error: kf_end: zone budget is 191 (0xbf), expected 192 (data lines + one boundary line per zone)
Info - File .../68-kernel-architecture-191.asm, line 345: ...called from here.
```

Changing it to `16` produces `193 (0xc1)`. The check is not a warning; `acme` exits nonzero and no ROM is written.

What the assertion does not catch:

- A handler that draws the wrong number of lines (the budget counts the macro's declared data lines, not the loop's iterations).
- A custom routine that returns early or late.
- The dispatch/return tax (a runtime cost, measured at 229/19).
- The first-line colour (a VBLANK responsibility, measured by the first-line pixel check).

Those four are covered by the boundary contract and the Stella state log. The assembly check and the state log are two independent gates: one proves the arithmetic, the other proves the clock.

The three ledgers, repeated from the source header:

```text
STATUS:    fill 15 + PF 24 rows + strip 48 + ramp 77
           16 + 49 + 49 + 78 = 192
STARFIELD: ramp 31 + strip 95 + PF 16 rows + fill 30
           32 + 96 + 33 + 31 = 192
SPLIT:     PF 24 rows + strip 31 + PF 24 rows + ramp 61
           49 + 32 + 49 + 62 = 192
```

The `+kf_end` check runs three times, once per layout. A layout cannot reach the ROM with a missing or extra line; the only way to build the gallery is to make all three sums exactly 192.

### Section 5: The Runtime Selector and the Dispatch Tax

`Layout` is one byte at `$83`. It is not at `$80`: that byte is `KernelPtr` in `kernel_patterns.asm`, and `$81`/`$82` are the pointer's high byte and `KernelRows`. A preflight scratch build made exactly that mistake — `Layout` and `Frame` at `$80/$81` — and the layout smashing the kernel pointer collapsed that build's frame to 71 lines. The framework owns `$80–$82`; Lesson 68's variables start at `$83`.

The selector is a branch dispatcher:

```asm
LDA Layout
BNE .not0               ; 2 cycles when Layout is 0
JMP .l0
.not0:
CMP #1
BEQ .do1
CMP #2
BEQ .do2
JMP .l0                 ; defensive: an unknown value runs layout 0
.do1:
JMP .l1
.do2:
JMP .l2
```

It is not a self-modified jump vector. A preflight scratch build first wrote the target address into `KernelJmp+1/+2` and executed `JMP (KernelJmp)`. The writes went to **ROM**, were ignored, and the indirect jump read `$FFFF`; that build's frame collapsed. A branch dispatcher has no writable state: the target is encoded in the instruction stream, and the only state is the `Layout` byte.

The macro branches to local `JMP` trampolines because the dispatch point is more than 127 bytes from `Layout1` and `Layout2`; a `BEQ` cannot reach. The layouts' distance from each other is not the reason. The trampolines are three bytes each and stay inside the branch range. Layout 0 is 8 cycles; layout 1 is 14; layout 2 is 18 (two compares and a taken branch).

The dispatch cost is paid on the first visible line, not in VBLANK: `BodyStart` calls `DrawKernel` and the branch runs there. The first-line prelude is what keeps that line clean — the background is already in `COLUBK` before the branch, so the 8–18 cycles of the dispatcher do not produce a left-edge sliver. The 13-cycle tax that the state log measures at 229/19 comes from the **return** chain, not the dispatch: the last handler's `RTS` (6 cycles into line 229) plus the layout routine's `RTS` (6) puts `KernelEnd`/`OverscanStart` at cycle 19.

`StoreLayout` is the one place that writes `Layout`. Both the SELECT edge and the auto-demo call it; the `LayoutWrite` checkpoint sits after the store, so a debugger sees the new layout on either path. It also resets `Frame` and `SpriteY`, so a layout always opens on its own frame 0.

SELECT uses the same fresh-press edge as Lesson 67: `SWCHB` bit 1 inverted, stored in `NewSelect`, then `new & ~previous`. The auto-demo advances every 240 frames — about four seconds at 60 Hz — so the three captures are deterministic without keyboard focus and without synthetic key events. Layout 0 occupies frames 0–239, layout 1 240–479, and layout 2 480–719. The state log shows `LayoutWrite` A=1 at frame 240, A=2 at 480 and A=0 at 720, and `LayoutRead` follows with A=0/1/2.

### Section 6: The Three Layouts in Detail

The three layouts exercise the same macros in different orders. Each layout's geometry is the ledger made visible.

**STATUS** — four zones, 192 lines:

| Zone | Lines (picture) | What it draws |
|---|---:|---|
| fill 15 + boundary | 0–15 | a solid dark-grey band (`$02`) |
| PF 24 rows + boundary | 16–64 | mirrored gold (`$1A`) console bars: four repetitions of a solid bar, side rails, a centre block and a gap |
| strip 48 + boundary | 65–113 | six green (`$C8`) diamonds in three close copies of player 0 |
| ramp 77 + boundary | 114–191 | a 16-colour cycle that climbs one line every other frame, ending in black |

The ramp is the lesson's motion. `RampDataA` is a 77-byte **RAM** working copy, seeded once from `RampSeedA` in the first VBLANK. Every other frame `RotateRamp` moves bytes 1–75 into 0–74, puts the saved byte 0 at 75, and forces byte 76 to `$00`. The colour bands climb the screen; the last line stays black. The seed is a 16-colour cycle repeated four times, then 12 colours and the black last line.

**STARFIELD** — four zones, 192 lines:

| Zone | Lines (picture) | What it draws |
|---|---:|---|
| ramp 31 + boundary | 0–31 | a blue-to-black fade (`RampDataB`) |
| strip 95 + boundary | 32–127 | 95 sparse bytes in three close copies — the star strip |
| PF 16 rows + boundary | 128–160 | a light-blue (`$9A`) star pattern, mirrored by the playfield's reflect mode |
| fill 30 + boundary | 161–191 | black |

The star strip is a one-byte-per-line player 0 band. Each byte is eight pixels; the three close copies repeat the slice at x, x+16 and x+32, so the strip is a sparse star field in the left-middle of the screen. The playfield below is the full-width star pattern; reflect mode mirrors the 20 chunks, so the two halves agree. The black fill at the bottom is the last zone and makes the overscan tax invisible.

**SPLIT** — four zones, 192 lines:

| Zone | Lines (picture) | What it draws |
|---|---:|---|
| PF 24 rows + boundary | 0–48 | a mirrored blue (`$84`) grid: four repetitions of a solid bar, side rails and a gap |
| strip 31 + boundary | 49–80 | three red (`$46`) diamonds |
| PF 24 rows + boundary | 81–129 | a green (`$C8`) staircase; reflect mode turns it into a V |
| ramp 61 + boundary | 130–191 | a sunset from gold to violet, ending in black |

The two playfields differ: the upper is a horizontal grid, the lower a descending staircase. The strip between them is 31 lines of the diamond pattern. The ramp's last byte is `$00`, so the layout ends black.

The horizontal position of player 0 is the lesson's, not the framework's. VBLANK writes `RESP0` after a seven-iteration delay, which puts the three close copies at about TIA x=60, 76 and 92. The same delay places the exercise's ball; the ball's output delay is one clock less, so its left edge is at about TIA x=59. The framework draws the strip; the lesson decides where it stands.

### Section 7: A Framework vs a Fixed Kernel

A fixed kernel is one loop with one shape. It is easy to count and cheap in ROM, but every new screen shape means editing the loop, recounting the lines and rewriting the boundary setup. A framework is a layer above the loop: the zone macros own the setup, the cleared objects, the boundary line and the return path; the layout owns the order and the line counts; the lesson owns the data, the colours and the horizontal positions.

The trade is explicit:

| | Fixed kernel | Zone framework |
|---|---|---|
| A new layout | edit the loop and recount | add a `+kf_*` list |
| Line budget | a hand count | `+kf_end` at assembly time |
| Runtime selection | a branch per screen | one byte + a branch dispatcher |
| Cost per zone | none | one boundary line |
| Dispatch tax | none | 13 cycles at the overscan (hidden by black) |
| Code size | one loop | one expanded sequence per zone |
| Data-driven layout | no | no — a layout is code |

The last row is the bridge to a generator. The framework's layouts are code, so a **layout DSL** would have to emit zone calls, not a descriptor table. A generator would read a layout description — zone kinds, colours, table data, order — and lower it to `+kf_fill`, `+kf_pf`, `+kf_strip`, `+kf_ramp` calls and their tables. That is the same relationship Lesson 67's wave generator has with its engine: the generator owns the description and the lowering, the hand-written target owns the cycle-exact execution. The zone framework is the lowering target for a layout language; the `+kf_end` assertion is the target's type checker.

The framework stops where the lesson's judgment is needed: it does not position objects horizontally, it does not decide the first line's colour, it does not update a RAM table (the custom zone does), and it does not handle audio. Those remain lesson code. The framework's job is the schedule and the budget.

## The Code

### Building This Lesson

```bash
# assemble every lesson ROM into docs/public/roms/
npm run roms

# or just this one, from the repository root
acme -f plain -o build/lesson68.bin \
  lessons/part9-dsl-path/68-kernel-architecture/68-kernel-architecture.asm
stella build/lesson68.bin
```

The committed ROM is `docs/public/roms/part9-dsl-path/68-kernel-architecture/68-kernel-architecture.bin`, 4,096 bytes. The three exercise ROMs are beside it: `exercise-01-solution.bin`, `exercise-02-solution.bin`, `exercise-03-solution.bin`, each 4,096 bytes.

The framework is a shared include, `include/kernel_framework.asm`. It is sourced **after** `include/vcs.asm`, `include/macro.asm`, `* = $F000` and `include/kernel_patterns.asm`:

```asm
    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

    * = $F000

    !source "include/kernel_patterns.asm"
    !source "include/kernel_framework.asm"
```

The framework file contains macros only: no program counter, no code, no vector. It calls the four pattern routines, so the pattern library must be sourced first; the framework owns no RAM of its own and uses the library's `$80–$82`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 68: The Zone Gallery — a kernel architecture from four band macros
; =============================================================================
; Part 9: The DSL Path
;
; What this program does:
;   Three 192-line layouts are built from the same four zone macros in
;   include/kernel_framework.asm.  Each macro expands into a boundary line
;   (colour, table pointer, cleared objects, STA WSYNC) plus a call to one of
;   the four routines in include/kernel_patterns.asm.  The framework checks
;   the line budget at assembly time: every zone costs .dataLines + 1, and
;   +kf_end fails unless the sum is 192.  A one-byte Layout selects the
;   layout at run time with a branch dispatcher (never a ROM jump vector).
;
;   Layout 0 — STATUS:    fill 15 + PF 24 rows + strip 48 + ramp 77
;                         16 + 49 + 49 + 78 = 192
;   Layout 1 — STARFIELD: ramp 31 + strip 95 + PF 16 rows + fill 30
;                         32 + 96 + 33 + 31 = 192
;   Layout 2 — SPLIT:     PF 24 rows + strip 31 + PF 24 rows + ramp 61
;                         49 + 32 + 49 + 62 = 192
;
;   Every layout's last zone is black: the STATUS and SPLIT ramps end in $00,
;   and STARFIELD ends in +kf_fill 0, 30.  The dispatch/return chain reaches
;   the overscan at 229/19 instead of the usual 229/6, and the VBLANK store
;   completes at about cycle 24; black makes the first visible clocks of the
;   overscan line invisible.
;
; Motion:
;   The STATUS ramp is a 77-byte RAM working copy (RampDataA at $89-$D5),
;   seeded once from the ROM table RampSeedA.  Every other frame the VBLANK
;   code rotates the first 76 bytes by one line and forces the last byte to
;   $00, so the colour bands climb the screen.  Frame drives the auto-demo;
;   SpriteY divides the rotation clock.
;
; Auto-demo and SELECT:
;   The ROM advances Layout 0 -> 1 -> 2 -> 0 every 240 frames (about four
;   seconds), so the three screenshots are deterministic without keyboard
;   focus and without a synthetic key event.  SELECT also advances the layout
;   on a fresh press and resets Frame to 0, so a layout always opens on its
;   own frame 0.
;
; The zone framework (include/kernel_framework.asm):
;   +kf_begin                     reset the assembly-time budget
;   +kf_fill  .color, .dataLines  solid COLUBK band
;   +kf_pf    .color, .rows, .t   PF0/PF1/PF2 band, two lines per row
;   +kf_strip .color, .lines, .t  one GRP0 byte per line
;   +kf_ramp  .lines, .t          one COLUBK byte per line
;   +kf_custom .lines, .routine   a lesson-supplied band
;   +kf_end                       !error unless the budget is 192
;   +kf_dispatch .l0, .l1, .l2    branch on Layout = 0/1/2
;
; Frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines.
;   StartFrame    259/3   the first VSYNC instruction
;   VblankStart     0/5   the first VBLANK instruction
;   BodyStart      37/5   the first picture line (the first boundary line)
;   KernelEnd     229/19  the last zone's handler has returned
;   OverscanStart 229/19  the first overscan instruction (the 13-cycle tax)
;   LayoutRead    A = 0/1/2, the active layout
;   LayoutWrite   A = the new layout after a SELECT edge or the auto-demo
;   FrameRead     A = the frame counter after the increment
;
; RAM map (+clean_start zeroes every byte):
;   $80-$81 KernelPtr   the framework's table pointer (kernel_patterns.asm)
;   $82     KernelRows  the framework's row/line count
;   $83     Layout      0 = STATUS, 1 = STARFIELD, 2 = SPLIT
;   $84     Frame       the frame counter, 0..239 between auto-advances
;   $85     PrevSelect  SELECT state last frame
;   $86     NewSelect   SELECT state this frame
;   $87     Startup     1 until the first VBLANK's one-time ramp seed
;   $88     SpriteY     the ramp rotation phase (incremented every frame)
;   $89-$D5 RampDataA   the 77-byte RAM ramp (the STATUS motion)
;   $D6     Tmp         the rotation's saved first byte
;   $D7-$F7 free
;   $F8-$FF stack
;   The score library is not used; its usual $A0-$D7 window is part of the
;   ramp buffer and the free space above it.
;
; Build: acme -f plain -o build/lesson68.bin \
;        lessons/part9-dsl-path/68-kernel-architecture/68-kernel-architecture.asm
; Run:   stella build/lesson68.bin
; The ROM is exactly 4,096 bytes; no mapper, no bankswitching.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; CONSTANTS
; =============================================================================
VBLANK_TIMER    = 44            ; the 37-line VBLANK (44 ticks)
OVERSCAN_TIMER  = 36            ; the 30-line overscan (36 ticks)
LAYOUT_COUNT    = 3             ; STATUS, STARFIELD, SPLIT
AUTO_FRAMES     = 240           ; about four seconds at 60 Hz
RAMP_LINES      = 77            ; the STATUS ramp's length
RAMP_ROTATE     = 75            ; the first 76 bytes rotate; byte 76 stays 0

C_BG            = $02           ; STATUS fill: dark grey
C_PF            = $1A           ; STATUS playfield: gold
C_FG            = $C8           ; STATUS strip: green
C_STAR          = $0E           ; STARFIELD strip: white
C_PF2           = $9A           ; STARFIELD playfield: light blue
C_BG2           = $02           ; SPLIT first-line background: dark grey
C_PF3           = $84           ; SPLIT upper playfield: blue
C_FG2           = $46           ; SPLIT strip: red
C_PF4           = $C8           ; SPLIT lower playfield: green

; =============================================================================
; RAM
; =============================================================================
; The framework owns $80-$82 through include/kernel_patterns.asm.  Every
; lesson variable starts at $83, the first byte the pattern library leaves
; free.
Layout      = $83
Frame       = $84
PrevSelect  = $85
NewSelect   = $86
Startup     = $87
SpriteY     = $88
RampDataA   = $89               ; 77 bytes: $89-$D5
Tmp         = $D6               ; the rotation's saved first byte
; $D7-$F7 free; $F8-$FF is the stack.

; =============================================================================
; THE PATTERN LIBRARY AND THE ZONE FRAMEWORK
; =============================================================================
; kernel_patterns.asm contains the four band routines and defines KernelPtr
; and KernelRows at $80-$82.  kernel_framework.asm contains macros only: it
; emits no code, sets no program counter and declares no vector.  Both are
; sourced after * = $F000 because the pattern library contains code.
    * = $F000

    !source "include/kernel_patterns.asm"
    !source "include/kernel_framework.asm"

; =============================================================================
; RESET
; =============================================================================
Reset:
    +clean_start

    LDA #0
    STA SWACNT              ; port A is an input port
    STA SWBCNT              ; port B is an input port
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA VDELP0
    STA VDELP1
    STA COLUBK
    STA COLUPF
    STA COLUP0
    STA COLUP1

    LDA #$21                ; reflect the playfield (bit 0); 4-pixel ball
    STA CTRLPF
    LDA #$03                ; three close copies of player 0
    STA NUSIZ0
    LDA #0
    STA NUSIZ1

    ; --- the initial gallery state ---------------------------------------
    LDA #0
    STA Layout
    STA Frame
    STA PrevSelect
    STA NewSelect
    STA SpriteY
    LDA #1
    STA Startup             ; the first VBLANK seeds the ramp

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262
; =============================================================================
StartFrame:                  ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                 ; checkpoint: scanline 0, cycle 5
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; SELECT — one layout advance per fresh press
; -----------------------------------------------------------------------------
    LDA SWCHB
    AND #$02
    EOR #$02                 ; 1 = SELECT pressed
    STA NewSelect
    AND PrevSelect
    EOR NewSelect            ; new & ~previous: a fresh press
    BEQ NoLayoutSwitch

    INC Layout
    LDA Layout
    CMP #LAYOUT_COUNT
    BCC SelectStore
    LDA #0
SelectStore:
    JSR StoreLayout

NoLayoutSwitch:
    LDA NewSelect
    STA PrevSelect

; -----------------------------------------------------------------------------
; ONE-TIME RAMP SEED — the first VBLANK copies the ROM ramp into RAM
; -----------------------------------------------------------------------------
    LDA Startup
    BEQ RampSeeded
    LDA #0
    STA Startup
    JSR SeedRamp
RampSeeded:

; -----------------------------------------------------------------------------
; FRAME COUNTER AND AUTO-DEMO — 240 frames per layout
; -----------------------------------------------------------------------------
    INC Frame
    LDA Frame
FrameRead:                   ; checkpoint: A = the frame counter
    NOP
    CMP #AUTO_FRAMES
    BNE NoAutoAdvance
    INC Layout
    LDA Layout
    CMP #LAYOUT_COUNT
    BCC AutoStore
    LDA #0
AutoStore:
    JSR StoreLayout
NoAutoAdvance:

    LDA Layout
LayoutRead:                  ; checkpoint: A = the active layout
    NOP

; -----------------------------------------------------------------------------
; MOTION — rotate the STATUS ramp every other frame
; -----------------------------------------------------------------------------
    INC SpriteY
    LDA SpriteY
    AND #$01
    BNE NoRampRotate
    JSR RotateRamp
NoRampRotate:

; -----------------------------------------------------------------------------
; POSITION PLAYER 0 FOR THE STRIP
; -----------------------------------------------------------------------------
; The strip is GRP0.  Three close copies at TIA x ~ 60 put the band in the
; middle-left of the screen.  The delay loop writes RESP0 at about cycle 39,
; 49 colour clocks into the visible area; the player's output delay and the
; TIA's three-clock position quantization put the displayed left edge at
; x ~ 60.  The position latches for every following line, so one strobe per
; frame is enough.
    STA WSYNC
    LDX #7
PositionDelay:
    DEX
    BNE PositionDelay
    LDA #0
    STA RESP0

; -----------------------------------------------------------------------------
; FIRST-LINE PRELUDE — the colour BodyStart must already show
; -----------------------------------------------------------------------------
; The dispatcher and the first zone's setup run after pixel 0.  VBLANK
; therefore leaves the first zone's background in COLUBK, so the first
; picture line has no left-edge sliver:
;   STATUS    the fill's background
;   STARFIELD the first byte of the ROM ramp
;   SPLIT     the dark background behind the upper playfield
    LDA Layout
    CMP #1
    BEQ PreludeStar
    CMP #2
    BEQ PreludeSplit
    LDA #C_BG
    JMP PreludeStore
PreludeStar:
    LDA RampDataB
    JMP PreludeStore
PreludeSplit:
    LDA #C_BG2
PreludeStore:
    STA COLUBK

    ; Clear the objects and the playfield for the first boundary line.
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL

VblankWait:
    +wait_timer
    LDA #0
    STA VBLANK               ; picture on

; =============================================================================
; THE VISIBLE PICTURE — one dispatch, then the selected layout's zones
; =============================================================================
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    JSR DrawKernel

; The last zone's handler returns here through the layout's RTS.  The label
; is the common point after the last zone of whichever layout ran.
KernelEnd:                   ; checkpoint: scanline 229, cycle 19
OverscanStart:               ; checkpoint: scanline 229, cycle 19
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; THE DISPATCHER — a branch on Layout, never a ROM jump vector
; =============================================================================
DrawKernel:
    +kf_dispatch Layout0, Layout1, Layout2

; =============================================================================
; LAYOUT 0 — STATUS: a solid band, a playfield, a sprite strip, a moving ramp
; =============================================================================
; Ledger: 15+1 = 16, 24x2+1 = 49, 48+1 = 49, 77+1 = 78; total 192.
Layout0:
    +kf_begin
    +kf_fill C_BG, 15
    +kf_pf C_PF, 24, PFDataA
    +kf_strip C_FG, 48, StripDataA
    +kf_ramp RAMP_LINES, RampDataA
    +kf_end
    RTS

; =============================================================================
; LAYOUT 1 — STARFIELD: a ramp, a star strip, a star playfield, black
; =============================================================================
; Ledger: 31+1 = 32, 95+1 = 96, 16x2+1 = 33, 30+1 = 31; total 192.
Layout1:
    +kf_begin
    +kf_ramp 31, RampDataB
    +kf_strip C_STAR, 95, StripDataB
    +kf_pf C_PF2, 16, PFDataB
    +kf_fill 0, 30
    +kf_end
    RTS

; =============================================================================
; LAYOUT 2 — SPLIT: two playfield bands with a sprite strip between them
; =============================================================================
; Ledger: 24x2+1 = 49, 31+1 = 32, 24x2+1 = 49, 61+1 = 62; total 192.
Layout2:
    +kf_begin
    +kf_pf C_PF3, 24, PFDataC
    +kf_strip C_FG2, 31, StripDataC
    +kf_pf C_PF4, 24, PFDataD
    +kf_ramp 61, RampDataC
    +kf_end
    RTS

; =============================================================================
; StoreLayout — the one place that writes Layout
; =============================================================================
; The SELECT edge and the auto-demo both compute the next value in A and call
; this routine.  A = 0..LAYOUT_COUNT-1.  The checkpoint sits after the store,
; so a debugger sees the new layout on either path.  A layout change resets
; the frame and the motion phase, so a layout always opens on its first frame.
StoreLayout:
    STA Layout
LayoutWrite:                 ; checkpoint: A = the new layout
    NOP
    LDA #0
    STA Frame
    STA SpriteY
    RTS

; =============================================================================
; THE RAMP'S RAM WORKING COPY
; =============================================================================
; SeedRamp copies the 77-byte ROM seed into the RAM buffer.  It runs once, in
; the first VBLANK, after +clean_start has cleared the RAM.
SeedRamp:
    LDX #0
SeedRampLoop:
    LDA RampSeedA,X
    STA RampDataA,X
    INX
    CPX #RAMP_LINES
    BNE SeedRampLoop
    RTS

; RotateRamp moves the first 76 colours up one line: byte 1 becomes byte 0,
; ..., byte 75 becomes byte 74, and the saved old byte 0 becomes byte 75.
; Byte 76 is forced to black on every frame, so the last zone always ends
; black and the overscan's 13-cycle tax stays invisible.
RotateRamp:
    LDA RampDataA
    STA Tmp
    LDX #0
RotateRampLoop:
    LDA RampDataA+1,X
    STA RampDataA,X
    INX
    CPX #RAMP_ROTATE
    BNE RotateRampLoop
    LDA Tmp
    STA RampDataA+(RAMP_LINES-2)
    LDA #0
    STA RampDataA+(RAMP_LINES-1)
    RTS

; =============================================================================
; DATA — the playfield rows (3 bytes per row, two scanlines per row)
; =============================================================================
; Each table is page-aligned so a row's three reads never cross a page: the
; KernelPFRows ledger is 57 cycles per row, and a page cross would add one.
; The bytes are in pixel-deadline order: PF0, then PF1, then PF2.

; STATUS: four repetitions of a six-row console motif (solid bar, side rails,
; a centre block, a gap).
    !align 255, 0, $EA
PFDataA:
    !byte $F0, $FF, $FF     ; row 0:  solid bar
    !byte $F0, $FF, $FF     ; row 1
    !byte $10, $00, $01     ; row 2:  side rails
    !byte $10, $00, $01     ; row 3
    !byte $10, $18, $01     ; row 4:  centre block
    !byte $00, $00, $00     ; row 5:  gap
    !byte $F0, $FF, $FF     ; row 6
    !byte $F0, $FF, $FF     ; row 7
    !byte $10, $00, $01     ; row 8
    !byte $10, $00, $01     ; row 9
    !byte $10, $18, $01     ; row 10
    !byte $00, $00, $00     ; row 11
    !byte $F0, $FF, $FF     ; row 12
    !byte $F0, $FF, $FF     ; row 13
    !byte $10, $00, $01     ; row 14
    !byte $10, $00, $01     ; row 15
    !byte $10, $18, $01     ; row 16
    !byte $00, $00, $00     ; row 17
    !byte $F0, $FF, $FF     ; row 18
    !byte $F0, $FF, $FF     ; row 19
    !byte $10, $00, $01     ; row 20
    !byte $10, $00, $01     ; row 21
    !byte $10, $18, $01     ; row 22
    !byte $00, $00, $00     ; row 23

; STARFIELD: 16 sparse rows; the same star pattern in both halves because
; CTRLPF bit 0 = 1 mirrors the left half.
    !align 255, 0, $EA
PFDataB:
    !byte $12, $48, $21     ; row 0
    !byte $84, $21, $04     ; row 1
    !byte $21, $04, $92     ; row 2
    !byte $48, $92, $48     ; row 3
    !byte $92, $04, $21     ; row 4
    !byte $04, $21, $84     ; row 5
    !byte $21, $48, $12     ; row 6
    !byte $84, $92, $48     ; row 7
    !byte $12, $04, $21     ; row 8
    !byte $48, $21, $84     ; row 9
    !byte $21, $92, $04     ; row 10
    !byte $92, $48, $12     ; row 11
    !byte $04, $21, $48     ; row 12
    !byte $21, $84, $92     ; row 13
    !byte $48, $12, $04     ; row 14
    !byte $92, $21, $48     ; row 15

; SPLIT upper: four repetitions of a three-row solid bar, two side-rail rows
; and a gap.
    !align 255, 0, $EA
PFDataC:
    !byte $F0, $FF, $FF     ; row 0
    !byte $F0, $FF, $FF     ; row 1
    !byte $F0, $FF, $FF     ; row 2
    !byte $10, $00, $01     ; row 3
    !byte $10, $00, $01     ; row 4
    !byte $00, $00, $00     ; row 5
    !byte $F0, $FF, $FF     ; row 6
    !byte $F0, $FF, $FF     ; row 7
    !byte $F0, $FF, $FF     ; row 8
    !byte $10, $00, $01     ; row 9
    !byte $10, $00, $01     ; row 10
    !byte $00, $00, $00     ; row 11
    !byte $F0, $FF, $FF     ; row 12
    !byte $F0, $FF, $FF     ; row 13
    !byte $F0, $FF, $FF     ; row 14
    !byte $10, $00, $01     ; row 15
    !byte $10, $00, $01     ; row 16
    !byte $00, $00, $00     ; row 17
    !byte $F0, $FF, $FF     ; row 18
    !byte $F0, $FF, $FF     ; row 19
    !byte $F0, $FF, $FF     ; row 20
    !byte $10, $00, $01     ; row 21
    !byte $10, $00, $01     ; row 22
    !byte $00, $00, $00     ; row 23

; SPLIT lower: a staircase that walks from the top-left pair of chunks to the
; middle of the field.  With reflect mode it becomes a V.
    !align 255, 0, $EA
PFDataD:
    !byte $F0, $00, $00     ; row 0
    !byte $F0, $00, $00     ; row 1
    !byte $70, $00, $00     ; row 2
    !byte $70, $00, $00     ; row 3
    !byte $30, $00, $00     ; row 4
    !byte $30, $00, $00     ; row 5
    !byte $10, $00, $00     ; row 6
    !byte $10, $00, $00     ; row 7
    !byte $10, $80, $00     ; row 8
    !byte $10, $80, $00     ; row 9
    !byte $10, $40, $00     ; row 10
    !byte $10, $40, $00     ; row 11
    !byte $10, $20, $00     ; row 12
    !byte $10, $20, $00     ; row 13
    !byte $10, $10, $00     ; row 14
    !byte $10, $10, $00     ; row 15
    !byte $10, $08, $00     ; row 16
    !byte $10, $08, $00     ; row 17
    !byte $10, $04, $00     ; row 18
    !byte $10, $04, $00     ; row 19
    !byte $10, $02, $00     ; row 20
    !byte $10, $02, $00     ; row 21
    !byte $10, $01, $00     ; row 22
    !byte $10, $01, $00     ; row 23

; =============================================================================
; DATA — the player-0 strips (one GRP0 byte per line)
; =============================================================================
; Each strip is page-aligned and shorter than 256 bytes, so the
; KernelSpriteStrip read never crosses a page (19 cycles per line, 18 on the
; last line).

; STATUS: six eight-line diamonds.
    !align 255, 0, $EA
StripDataA:
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18

; STARFIELD: 95 sparse bytes.  Every byte is one line of an eight-pixel-wide
; slice; the three close copies repeat the slice at x, x+16 and x+32.
    !align 255, 0, $EA
StripDataB:
    !byte $00, $08, $00, $22, $00, $41, $00, $14
    !byte $00, $82, $00, $28, $00, $44, $00, $91
    !byte $00, $20, $00, $0A, $00, $50, $00, $84
    !byte $00, $12, $00, $40, $00, $21, $00, $08
    !byte $00, $44, $00, $82, $00, $11, $00, $24
    !byte $00, $48, $00, $90, $00, $05, $00, $22
    !byte $00, $80, $00, $14, $00, $41, $00, $08
    !byte $00, $22, $00, $84, $00, $10, $00, $42
    !byte $00, $08, $00, $21, $00, $84, $00, $12
    !byte $00, $40, $00, $08, $00, $22, $00, $44
    !byte $00, $81, $00, $10, $00, $42, $00, $24
    !byte $00, $08, $00, $41, $00, $82, $00

; SPLIT: three diamonds and seven extra rows.
    !align 255, 0, $EA
StripDataC:
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C

; =============================================================================
; DATA — the ramps (one COLUBK byte per line)
; =============================================================================

; The STATUS seed: a 16-colour cycle repeated four times, then 12 colours and
; the black last line.  77 bytes.  SeedRamp copies it into RampDataA.
    !align 255, 0, $EA
RampSeedA:
    !byte $02, $04, $06, $08, $0A, $0C, $0E, $1A
    !byte $2A, $3A, $4A, $5A, $6A, $7A, $8A, $9A
    !byte $02, $04, $06, $08, $0A, $0C, $0E, $1A
    !byte $2A, $3A, $4A, $5A, $6A, $7A, $8A, $9A
    !byte $02, $04, $06, $08, $0A, $0C, $0E, $1A
    !byte $2A, $3A, $4A, $5A, $6A, $7A, $8A, $9A
    !byte $02, $04, $06, $08, $0A, $0C, $0E, $1A
    !byte $2A, $3A, $4A, $5A, $6A, $7A, $8A, $9A
    !byte $02, $04, $06, $08, $0A, $0C, $0E, $1A
    !byte $2A, $3A, $4A, $5A, $00

; STARFIELD: a blue-to-black fade.  It is not the last zone (the black fill
; is), so its last byte need not be black.
    !align 255, 0, $EA
RampDataB:
    !byte $9A, $98, $96, $94, $92, $90, $8E, $8C
    !byte $8A, $88, $86, $84, $82, $80, $7A, $78
    !byte $76, $74, $72, $70, $6E, $6C, $6A, $68
    !byte $66, $64, $62, $60, $5A, $58, $00

; SPLIT: a sunset from gold to violet, then black.  61 bytes; the last byte
; is $00 because this is the layout's last zone.
    !align 255, 0, $EA
RampDataC:
    !byte $1A, $1A, $2A, $2A, $3A, $3A, $4A, $4A
    !byte $5A, $5A, $6A, $6A, $7A, $7A, $8A, $8A
    !byte $9A, $9A, $AA, $AA, $1A, $1A, $2A, $2A
    !byte $3A, $3A, $4A, $4A, $5A, $5A, $6A, $6A
    !byte $7A, $7A, $8A, $8A, $9A, $9A, $AA, $AA
    !byte $1A, $1A, $2A, $2A, $3A, $3A, $4A, $4A
    !byte $5A, $5A, $6A, $6A, $7A, $7A, $8A, $8A
    !byte $9A, $9A, $AA, $AA, $00

; =============================================================================
; VECTORS — the 6507 reads RESET at $FFFC and jumps to Reset
; =============================================================================
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

<!-- END-FULL-SOURCE -->

> The complete, fully-commented source lives in
> `lessons/part9-dsl-path/68-kernel-architecture/68-kernel-architecture.asm`.

### Code Walkthrough

#### Step 1 — Reset and the RAM map

`Reset` runs `+clean_start`, sets `SWACNT`/`SWBCNT` to input, blanks the objects and the playfield, sets `CTRLPF = $21` (reflect mode, 4-pixel ball) and `NUSIZ0 = $03` (three close copies of player 0), and clears the colours. It then sets `Layout = 0`, `Frame = 0`, `PrevSelect = 0`, `NewSelect = 0`, `SpriteY = 0` and `Startup = 1`, and jumps to `StartFrame`.

The RAM map is the lesson's first correctness boundary. The pattern library owns `$80–$81` (`KernelPtr`) and `$82` (`KernelRows`); the framework adds nothing. `Layout` starts at `$83`, `Frame` at `$84`, `PrevSelect`/`NewSelect` at `$85`/`$86`, `Startup` at `$87`, `SpriteY` at `$88`, and the 77-byte ramp working copy at `$89–$D5`. `Tmp` at `$D6` is the rotation's saved byte; `$D7–$F7` are free; `$F8–$FF` is the stack. The score library is not used, so its usual `$A0–$D7` window is part of the ramp buffer and the free space above it.

The source header records the map; the state log's first evidence is that a break at `LayoutRead` reports A=0 rather than a corrupted pointer. A lesson variable at `$80–$82` would smash `KernelPtr` or `KernelRows` and the frame would collapse — a preflight scratch build (not this ROM) measured 71 lines when `Layout`/`Frame` sat at `$80/$81`.

#### Step 2 — The frame skeleton and the VBLANK prelude

`StartFrame` is the three-line VSYNC. `VblankStart` sets `VBLANK` and arms the 44-tick timer (the 37-line VBLANK). The VBLANK then does the frame's bookkeeping: the SELECT edge, the one-time ramp seed, the frame counter and auto-demo, `LayoutRead`, the ramp rotation, player 0's horizontal position, and the first-line prelude.

The prelude is the answer to a subtle problem. `BodyStart` is the first picture line, but the dispatcher and the first zone's setup run after pixel 0. The line's background must already be correct when VBLANK releases the picture, so the prelude writes `COLUBK`:

```asm
    LDA Layout
    CMP #1
    BEQ PreludeStar
    CMP #2
    BEQ PreludeSplit
    LDA #C_BG
    JMP PreludeStore
PreludeStar:
    LDA RampDataB
    JMP PreludeStore
PreludeSplit:
    LDA #C_BG2
PreludeStore:
    STA COLUBK
```

STATUS uses the fill's background, STARFIELD the first byte of the ROM ramp, and SPLIT the dark background behind the upper playfield. The pixel check confirms it: the first picture line is one colour across its full width in all three captures.

The prelude is followed by a blanket clear of `PF0–PF2`, `GRP0`, `GRP1`, `ENAM0`, `ENAM1` and `ENABL`, so the first boundary line starts from a known TIA state even before the first zone's setup. `+wait_timer` waits out the 37 lines; `LDA #$00; STA VBLANK` releases the picture at line 37 cycle 5.

#### Step 3 — SELECT, the auto-demo and StoreLayout

SELECT is a fresh-press edge, not a level: `SWCHB` bit 1 is inverted into `NewSelect`; `AND PrevSelect; EOR NewSelect` is true only on a new press. The edge computes the next layout and calls `StoreLayout`:

```asm
    INC Layout
    LDA Layout
    CMP #LAYOUT_COUNT
    BCC SelectStore
    LDA #0
SelectStore:
    JSR StoreLayout
```

The auto-demo does the same after 240 frames:

```asm
    INC Frame
    LDA Frame
FrameRead:
    NOP
    CMP #AUTO_FRAMES
    BNE NoAutoAdvance
    INC Layout
    LDA Layout
    CMP #LAYOUT_COUNT
    BCC AutoStore
    LDA #0
AutoStore:
    JSR StoreLayout
NoAutoAdvance:
```

`StoreLayout` is the one place that writes `Layout`:

```asm
StoreLayout:
    STA Layout
LayoutWrite:                 ; checkpoint: A = the new layout
    NOP
    LDA #0
    STA Frame
    STA SpriteY
    RTS
```

The shared store gives the `LayoutWrite` checkpoint both paths. It also resets `Frame` and `SpriteY`, so a layout always opens on its own frame 0. The auto-demo makes the three captures deterministic without keyboard focus: layout 0 occupies frames 0–239, layout 1 240–479, layout 2 480–719. At 60 Hz that is 0–4 s, 4–8 s and 8–12 s, so the 2 s, 6 s and 10 s captures see STATUS, STARFIELD and SPLIT respectively.

#### Step 4 — BodyStart, the dispatcher and the three layouts

`BodyStart` calls `DrawKernel`, which expands the framework's branch dispatcher:

```asm
DrawKernel:
    LDA Layout
    BNE .not0
    JMP Layout0
.not0:
    CMP #1
    BEQ .do1
    CMP #2
    BEQ .do2
    JMP Layout0                 ; defensive: an unknown value runs layout 0
.do1:
    JMP Layout1
.do2:
    JMP Layout2
```

Layout 0 is 8 cycles; layout 1 is 14; layout 2 is 18. The local trampolines exist because the dispatch point is more than 127 bytes from `Layout1`/`Layout2`; `BEQ Layout1` cannot reach. No target is written to ROM, and no `JMP (vector)` is used.

The three layouts are the ledgers made code:

```asm
Layout0:
    +kf_begin
    +kf_fill C_BG, 15
    +kf_pf C_PF, 24, PFDataA
    +kf_strip C_FG, 48, StripDataA
    +kf_ramp RAMP_LINES, RampDataA
    +kf_end
    RTS

Layout1:
    +kf_begin
    +kf_ramp 31, RampDataB
    +kf_strip C_STAR, 95, StripDataB
    +kf_pf C_PF2, 16, PFDataB
    +kf_fill 0, 30
    +kf_end
    RTS

Layout2:
    +kf_begin
    +kf_pf C_PF3, 24, PFDataC
    +kf_strip C_FG2, 31, StripDataC
    +kf_pf C_PF4, 24, PFDataD
    +kf_ramp 61, RampDataC
    +kf_end
    RTS
```

Each layout ends with `RTS`. The `JSR DrawKernel` return address is still on the stack, so the last handler's `RTS` returns to the layout, and the layout's `RTS` returns to `KernelEnd`. That two-level return is what puts `KernelEnd`/`OverscanStart` at 229/19: the last handler returns at cycle 13, and the layout's `RTS` takes 6 more.

#### Step 5 — The ramp's RAM working copy

The STATUS ramp is the lesson's motion. `RampDataA` is a 77-byte RAM buffer at `$89–$D5`, seeded from the ROM table `RampSeedA` in the first VBLANK:

```asm
SeedRamp:
    LDX #0
SeedRampLoop:
    LDA RampSeedA,X
    STA RampDataA,X
    INX
    CPX #RAMP_LINES
    BNE SeedRampLoop
    RTS
```

Every other frame `RotateRamp` rotates the first 76 bytes one line upward:

```asm
RotateRamp:
    LDA RampDataA
    STA Tmp
    LDX #0
RotateRampLoop:
    LDA RampDataA+1,X
    STA RampDataA,X
    INX
    CPX #RAMP_ROTATE
    BNE RotateRampLoop
    LDA Tmp
    STA RampDataA+(RAMP_LINES-2)
    LDA #0
    STA RampDataA+(RAMP_LINES-1)
    RTS
```

Bytes 1–75 move into 0–74, the saved byte 0 moves into 75, and byte 76 is forced to `$00`. The colour bands climb the screen, and the last line stays black. The rotation is gated by `SpriteY & 1`, so the motion is one line every two frames: 76 rotations in about 2.5 seconds. The `LDA RampDataA+1,X` is zero-page indexed (the base and X stay inside page zero), so it is a 4-cycle load; the whole rotation is about 1,200 cycles, comfortably inside the 2,753-cycle VBLANK.

#### Step 6 — The data tables

The tables are the layouts' content. The playfield tables hold three bytes per row in pixel-deadline order — PF0 first (its field starts at pixel 0), then PF1 (chunk 4), then PF2 (chunk 12). Each table is page-aligned so a row's three reads never cross a page and the `KernelPFRows` ledger stays at 57 cycles per row. The strip and ramp tables are page-aligned and shorter than 256 bytes, so their `(KernelPtr),Y` reads never cross either.

`PFDataA` is four repetitions of a six-row console motif: a solid bar, two side-rail rows, a centre block and a gap. `PFDataB` is 16 sparse star rows. `PFDataC` is four repetitions of a three-row bar, two side rails and a gap. `PFDataD` is a descending staircase. `StripDataA` is six eight-line diamonds; `StripDataB` is 95 sparse bytes; `StripDataC` is three diamonds and seven extra rows. `RampSeedA` is the 77-byte colour cycle; `RampDataB` is a 31-byte blue-to-black fade; `RampDataC` is a 61-byte sunset ending in `$00`.

The playfield is in reflect mode (`CTRLPF` bit 0 = 1), so the right half mirrors the left. That is why the SPLIT staircase becomes a V and the STARFIELD star pattern is symmetric. The strip is player 0 in three close copies; the copies are 16 pixels apart, so the strip reads as three columns.

#### Step 7 — The framework macros and the boundary contract

The framework is `include/kernel_framework.asm`. It contains no code at all: eight macros, a budget symbol and the documentation. A zone macro expands into the sequence from Section 2 and ends with `STA WSYNC; JSR <handler>`. The handler returns at cycle 10 (`KernelFill`) or 13 (the others) of the line after its last data line; the next macro's setup runs on that line; its `WSYNC` makes it the boundary line; the next handler starts 6 cycles into the next line. That is the whole boundary contract.

The budget is `KF_TOTAL`. `+kf_begin` `!set`s it to 0; each zone adds `.dataLines + 1`; `+kf_end` emits `!error` unless the sum is 192. The check runs at assembly time, once per layout. The 191/193 negative test is in the evidence below.

The dispatcher is a branch, not a vector. A preflight scratch build's two mistakes are the lesson's warnings: a jump target written into ROM is ignored, and a lesson variable at `$80–$82` clobbers the pattern library. Both collapse the frame; both are avoided by the framework's design.

## What You Should See

The gallery opens on **STATUS**. The top 16 visible lines are a solid dark-grey band. Below it, 48 lines of mirrored gold console bars plus the one-line gutter (49 in the ledger) fill the width: four repetitions of a solid bar, a pair of side rails, a centre block and a gap. Then 48 lines of the green strip plus its one-line gutter (49): three close copies of a six-diamond column at about TIA x=60, 76 and 92. The bottom 78 lines are 77 ramp lines plus the one-line gutter: a 16-colour cycle that climbs one line every other frame, so the bands visibly move upward, and the last line is black.

![Stella running the STATUS layout of the Lesson 68 zone gallery: a dark-grey band at the top, gold console bars, three green diamond columns, and a rainbow ramp climbing to black; the title bar reads Stella 7.0: "68-kernel-architecture"](/images/lesson68/layout-status.png)

*`layout-status.png`: STATUS after two seconds. The fill is 16 lines (15 data + the boundary), the playfield 49 (24 rows × 2 + the boundary), the strip 49 (48 + the boundary), and the ramp 78 (77 + the boundary). The three green columns are the three close copies of player 0. The ramp's colours have already rotated about 60 times.*

<RomPlayer rom="/roms/part9-dsl-path/68-kernel-architecture/68-kernel-architecture.bin" title="Lesson 68 — Designing Your Kernel Architecture (the zone gallery)" />

Javatari starts muted; this ROM is silent, so there is nothing to unmute.

At about four seconds the auto-demo advances to **STARFIELD**. 31 ramp lines plus the boundary (32) sit at the top; 95 star lines plus the boundary (96) fill the left-middle in three columns; 32 playfield lines plus the boundary (33) span the width; the last 30 black fill lines plus the boundary (31) close the picture. The playfield's reflect mode makes the two halves agree. The star strip is the ROM table `StripDataB`, so this layout is static; the motion in the gallery is the STATUS ramp.

![Stella running the STARFIELD layout of the Lesson 68 zone gallery: a blue/purple ramp at the top, three columns of white stars, a light-blue star playfield across the width, and a black bottom; the title bar reads Stella 7.0: "68-kernel-architecture"](/images/lesson68/layout-starfield.png)

*`layout-starfield.png`: STARFIELD after six seconds (two seconds into the second layout). The ramp is 32 lines (31 + boundary), the strip 96 (95 + boundary), the playfield 33 (16 rows × 2 + boundary), and the black fill 31 (30 + boundary). The star strip's three copies are at the same x positions as the STATUS diamonds.*

At about eight seconds the auto-demo advances to **SPLIT**. 48 grid lines plus the boundary (49) top the picture; 31 red strip lines plus the boundary (32) follow; 48 green staircase lines plus the boundary (49) fill the lower half, mirrored into a V; 61 sunset lines plus the boundary (62) run to black. The two playfields are different tables, so the upper grid and the lower staircase are visibly distinct.

![Stella running the SPLIT layout of the Lesson 68 zone gallery: a blue playfield grid at the top, three red diamond columns, a green mirrored staircase, and a sunset ramp below; the title bar reads Stella 7.0: "68-kernel-architecture"](/images/lesson68/layout-split.png)

*`layout-split.png`: SPLIT after ten seconds. The upper playfield is 49 lines, the strip 32, the lower playfield 49, and the sunset ramp 62. The green staircase is the reflected `PFDataD` table; the red diamonds are `StripDataC`.*

The debugger tells the same story as numbers. The gallery's checkpoints:

| Checkpoint | Address (committed ROM) | Measured | Meaning |
|---|---|---|---|
| `StartFrame` | `$F099` | 259/3 (the first hit is the power-on partial frame at 34/33) | the first VSYNC instruction |
| `VblankStart` | `$F0A7` | 0/5 | the first VBLANK instruction |
| `BodyStart` | `$F140` | 37/5 | the first picture line (the first boundary line) |
| `KernelEnd` | `$F143` | 229/19 | the last zone's handler has returned |
| `OverscanStart` | `$F143` | 229/19 | the first overscan instruction (the 13-cycle tax) |
| `LayoutRead` | `$F0F3` | A = 0/1/2 | the active layout |
| `LayoutWrite` | `$F2FB` | A = 1, 2, 0 on the auto-demo; A = 1 with `-holdselect` | the new layout |
| `FrameRead` | `$F0DF` | A = 2, 3, 4, … | the frame counter after the increment |

The frame checkpoints, first hits:

```text
# StartFrame
BP:           0  34 33  31 | nV-BdIzC 01 ff 00 ff |    (power-on)
BP:           1 259 03 -59 | nv-BdIZC 00 00 4d ff |
BP:           2 259 03 -59 | nv-BdIZC 00 00 4d ff |

# VblankStart
BP:           1   0 05 -53 | nV-BdIZC 00 ff 00 ff |
BP:           2   0 05 -53 | nv-BdIZC 00 00 4d ff |

# BodyStart
BP:           1  37 05 -53 | nV-BdIZc 00 00 00 ff |
BP:           2  37 05 -53 | nv-BdIZc 00 00 4d ff |
BP:           3  37 05 -53 | nv-BdIZc 00 00 4d ff |

# KernelEnd and OverscanStart (the same address)
BP:           1 229 19 -11 | nv-BdIZC 00 00 4d ff |
BP:           2 229 19 -11 | nv-BdIZC 00 00 4d ff |
BP:           3 229 19 -11 | nv-BdIZC 00 00 4d ff |

# FrameRead
BP:           1  16 12 -32 | nv-BdIzC 01 4d 00 ff |    (power-on)
BP:           2   0 56 100 | nv-BdIzC 02 00 4d ff |
BP:           3   0 56 100 | nv-BdIzC 03 00 4d ff |
BP:           4   0 56 100 | nv-BdIzC 04 00 4d ff |
```

The layout checkpoints, with the auto-demo's transitions:

```text
# LayoutRead (normal run)
BP:           1  16 22  -2 | nV-BdIZc 00 4d 00 ff |    (power-on)
BP:           2   0 66 130 | nv-BdIZc 00 00 4d ff |
BP:           3   0 66 130 | nv-BdIZc 00 00 4d ff |

# LayoutRead transitions (13-second run)
BP:         240   1 27  13 | nv-BdIzc 01 00 4d ff |    A=1, frame 240
BP:         480   1 27  13 | nv-BdIzc 02 00 02 ff |    A=2, frame 480
BP:         720   1 28  16 | nv-BdIZC 00 00 3d ff |    A=0, frame 720

# LayoutWrite (same run)
BP:         240   1 08 -44 | Nv-BdIzc 01 00 4d fd |
BP:         480   1 08 -44 | Nv-BdIzc 02 00 02 fd |
BP:         720   1 09 -41 | nv-BdIZC 00 00 3d fd |

# LayoutWrite with -holdselect at power-on
BP:           1   0 57 103 | NV-BdIzc 01 ff 00 fd |    A=1
```

The frame checkpoints measure 259/3, 0/5, 37/5 and 229/19 on every frame after the power-on partial. The `BodyStart`→`OverscanStart` span is 229 − 37 = 192 scanlines, the exact budget. `KernelEnd` and `OverscanStart` share an address: the `JSR DrawKernel` returns to the instruction at that address, which is the first overscan instruction (`LDA #$02`). The `LayoutWrite` log shows the auto-demo's writes 1, 2, 0; the `-holdselect` run shows the SELECT edge's write 1.

The pixel check of the committed images:

| Image | Size | Title bar | What the pixels show |
|---|---|---|---|
| `layout-status.png` | 1010×807 | `Stella 7.0: "68-kernel-architecture"` | TIA area 960×606 at (25,106); first picture line one colour `(63,63,62)` across; fill 16 lines; mirrored gold `(205,205,52)` console bars; green `(81,179,80)` diamond columns; a rainbow ramp with `(90,100,224)`, `(90,176,212)`, `(205,205,52)`, `(226,100,99)` bands; the last picture rows are black |
| `layout-starfield.png` | 1010×807 | `Stella 7.0: "68-kernel-architecture"` | first picture line one colour `(90,151,221)` across (the first ramp byte `$9A`); the blue/purple ramp; white `(234,234,233)` star columns; the mirrored light-blue star playfield; the last rows black |
| `layout-split.png` | 1010×807 | `Stella 7.0: "68-kernel-architecture"` | first picture line one colour `(63,63,62)` across; the mirrored blue `(36,40,176)` grid; red `(194,61,60)` diamonds; the mirrored green `(81,179,80)` staircase (a V); the sunset ramp; the last rows black |

The three TIA-area pixel hashes differ (`0b44cd26…`, `ebbc1442…`, `6a20ab0e…`), so the layouts are genuinely different pictures, not three captures of one frame. All three images are 1010×807, carry the window frame and title bar, and show no cursor; the pointer was parked at (0,0) before each capture. The first picture line is a single colour across its full width in all three layouts: the VBLANK prelude's left-edge proof.

The **reflect proof** is a pixel-symmetry check. In each playfield band, the left half of the 960-pixel TIA area matches the mirrored right half for 99.0% of the STATUS bars, 97.8% of the STARFIELD star playfield, and 99.7% of the SPLIT lower staircase; the small remainder is the emulator's scaling and the strip's non-mirrored player copies. The SPLIT lower playfield is a V, and the STARFIELD halves agree, exactly as `CTRLPF` bit 0 = 1 requires.

The **boundary-line proof** is a pixel check of the clear order. Each zone macro clears `PF0`–`PF2`, `GRP0`, `GRP1` and `ENABL` before the colour/pointer setup; on a mid-layout boundary the first `PF0` store completes by cycle 18, before pixel 0, and the first zone's objects are already zero from the VBLANK blanket clear. In the committed captures, STARFIELD's black fill boundary line (picture line 161) is black across the width even though the last playfield row above it has star bits; SPLIT's ramp boundary line (picture line 130) is dark grey even though the lower playfield's last row has green bits; and SPLIT's lower-playfield boundary line (picture line 81) has no red pixels in the first player copy even though the strip's last line is a diamond row. `+kf_ramp` is the deliberate exception: its boundary line keeps the previous background, and its first data line writes the ramp's first colour.

> **Capture method.** `layout-status.png` is `scripts/capture-screenshot.sh` on the committed
> `docs/public/roms/part9-dsl-path/68-kernel-architecture/68-kernel-architecture.bin`
> after two seconds; `layout-starfield.png` after six seconds; `layout-split.png` after ten
> seconds. The ROM starts its auto-demo at power-on and advances every 240 frames
> (about four seconds), so the captures see STATUS, STARFIELD and SPLIT without a key event.
> SELECT also advances the layout on a fresh press; the state log above is the proof of the
> auto-demo's `LayoutWrite` sequence. The pointer was parked at (0,0) before every capture.
> All three images are 1010×807 and carry the title bar `Stella 7.0: "68-kernel-architecture"`;
> no cursor appears. The TIA area is 960×606 at (25,106) in all three.

## Exercises

Each exercise ships a 4,096-byte `exercise-NN-solution.asm`. The solutions assemble through `npm run roms`, run in Stella, and actually solve the exercise as written.

### Exercise 1: Add a ball zone

**Challenge:** Use the framework's `+kf_custom` escape hatch to add a ball band. Define a lesson-local `BallBand` routine that reads `KernelPtr`/`KernelRows` and writes `ENABL` per line; in the STATUS layout, clear the objects, set `COLUPF` and the table pointer, and call `+kf_custom 12, BallBand`.

**Hints:**
1. The ball shares `COLUPF` with the playfield; `ENABL` is enabled by a byte with bit 1 set (`$02`) and disabled by `$00`.
2. `+kf_custom` sets `KernelRows = .dataLines`, ends the boundary line with `WSYNC` and calls the routine. It does not set the colour or the object clears; the lesson does those before the macro.
3. Clear first, then set `COLUPF` and `KernelPtr`, then `+kf_custom 12, BallBand`. The clears complete before pixel 0, so the boundary line's left edge is clean.
4. Give the ball 12 data lines and take them from the fill (15 → 12) and the strip (48 → 38); the ledger becomes 13 + 49 + 39 + 13 + 78 = 192.
5. Position the ball in VBLANK with the same seven-iteration delay that places player 0; the ball's output delay is one clock less, so its left edge is at TIA x ≈ 59. `CTRLPF = $21` makes it four pixels wide.

**Expected Result:** `exercise-01-solution.asm` is 4,096 bytes; the STATUS layout shows a red (`$46`) dashed 4-pixel column below the strip's four full diamonds and the first six rows of the fifth; a Stella break at `BallWrite` reports A=`$02` on the enabled rows and A=`$00` on the gaps; `OverscanStart` is still 229/19.

**Solution:** See `exercise-01-solution.asm`.

The layout's ball zone is the `+kf_custom` escape hatch; the lesson owns the colour, pointer and clears:

```asm
    +kf_strip C_FG, 38, StripDataA

    ; The ball zone: clears first, then colour and pointer, then the
    ; framework's +kf_custom (KernelRows = 12, WSYNC, JSR BallBand).
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    LDA #C_BALL
    STA COLUPF
    LDA #<BallData
    STA KernelPtr
    LDA #>BallData
    STA KernelPtr+1
    +kf_custom 12, BallBand
```

The routine is the sprite strip's loop with `ENABL` as the destination:

```asm
BallBand:
    LDY #0
BallBandLine:
    LDA (KernelPtr),Y
    STA ENABL               ; $02 = ball on, $00 = ball off
BallWrite:                  ; checkpoint: A = the ball enable byte
    STA WSYNC
    INY
    CPY KernelRows
    BNE BallBandLine
    RTS
```

The STATUS ledger is now 13 + 49 + 39 + 13 + 78 = 192. The ball's 12 bytes are three enabled lines, two disabled, three enabled, two disabled and two enabled, so the band is a dashed column. The VBLANK adds a second `STA WSYNC`/delay/`RESBL` block; it costs about 115 cycles and the 37-line VBLANK has room. The state log reports `BallWrite` A=`$02` at scanlines 139–141 and A=`$00` at 142–143; the strip's 38 data lines end after four full diamonds and six rows of the fifth, so the ball band starts below that.

### Exercise 2: Add a fourth layout and a selector

**Challenge:** Add a fourth layout (GALLERY) with its own tables and a selector that cycles 0→1→2→3→0. The shared `+kf_dispatch` is a three-way macro; add a lesson-local four-way variant.

**Hints:**
1. `LAYOUT_COUNT` becomes 4; both SELECT and the auto-demo use it.
2. The four-way dispatcher has the same branch shape plus one compare and one local trampoline.
3. Layout 3's ledger: fill 23 + PF 16 rows (32) + strip 71 + ramp 62 = 24 + 33 + 72 + 63 = 192.
4. The GALLERY tables: a 16-row white frame (`PFDataE`), a 71-byte gold diamond strip (`StripDataD`), and a 62-byte blue-to-black ramp (`RampDataD`) ending in `$00`.
5. Add the first-line prelude case for layout 3 (`C_BG3`).

**Expected Result:** `exercise-02-solution.asm` is 4,096 bytes; SELECT and the auto-demo cycle four layouts; `LayoutRead` reaches A=3 at frame 720 (12 seconds); the GALLERY layout shows a blue band, a white frame around the playfield, gold diamonds and a blue-to-black ramp.

**Solution:** See `exercise-02-solution.asm`.

The four-way dispatcher keeps the shared macro's shape:

```asm
!macro kf_dispatch4 .l0, .l1, .l2, .l3 {
    LDA Layout
    BNE .not0
    JMP .l0
.not0:
    CMP #1
    BEQ .do1
    CMP #2
    BEQ .do2
    CMP #3
    BEQ .do3
    JMP .l0                 ; defensive: an unknown value runs layout 0
.do1:
    JMP .l1
.do2:
    JMP .l2
.do3:
    JMP .l3
}
```

The new layout and its ledger:

```asm
Layout3:
    +kf_begin
    +kf_fill C_BG3, 23
    +kf_pf C_PF5, 16, PFDataE
    +kf_strip C_FG3, 71, StripDataD
    +kf_ramp 62, RampDataD
    +kf_end
    RTS
```

The state log shows `LayoutRead` A=1 at 240, A=2 at 480 and A=3 at 720; the GALLERY source uses the blue `$84` fill, the white `$0E` frame, the gold `$1A` strip and `RampDataD`'s blue-to-black ramp. The three new tables are packed after the existing ones without page alignment; their addresses keep every row and every read inside a page, so the PF row's 57-cycle ledger and the strip's 19-cycle ledger are unchanged.

### Exercise 3: Make a zone configurable at runtime

**Challenge:** Make a zone's table a runtime structure. Replace the STARFIELD strip's ROM table with a 95-byte RAM working copy, seed it from `StripDataB`, and scroll it one pixel to the left every other frame, injecting one new star bit from an LFSR.

**Hints:**
1. The RAM budget allows one 95-byte buffer: `$89–$E7`. Put the LFSR at `$E8` and the new star's row at `$E9`.
2. `ASL StarRam,X` shifts every byte left; bit 7 falls out and bit 0 becomes 0. The new star enters at bit 0 of one row.
3. Use an 8-bit LFSR with the maximal tap mask `$1D`; its period is 255, so the row choice does not repeat for 255 frames.
4. The main lesson's STATUS ramp animation uses the same `$89–$D5` region, so the solution trades it for the star animation: the STATUS ramp returns to its ROM table `RampSeedA`.
5. Gate the scroll on `SpriteY & 1`, so it runs every other frame; the star row is `Lfsr & $7F` folded into 0–94 (`CMP #95 / BCC` else `SBC #95`).
6. Add a `StarShift` checkpoint after `STA Lfsr`; A is the LFSR value.

**Expected Result:** `exercise-03-solution.asm` is 4,096 bytes; the STARFIELD strip scrolls left and new stars appear; a Stella break at `StarShift` reports a changing LFSR (for example `$57`, `$AE`, `$41`, `$82`, `$19`, `$32`); `LayoutRead` reaches A=1 at frame 240; `OverscanStart` is 229/19 after the power-on partial frame.

**Solution:** See `exercise-03-solution.asm`.

The scroll is a one-byte-per-line loop plus the LFSR:

```asm
ScrollStars:
    LDX #0
StarShiftLoop:
    ASL StarRam,X
    INX
    CPX #95
    BNE StarShiftLoop
    LDA Lfsr
    ASL
    BCC StarNoTap
    EOR #$1D
StarNoTap:
    STA Lfsr
StarShift:                  ; checkpoint: A = the LFSR after the tap
    AND #$7F                ; 0..127; fold 95..127 back into 0..32
    CMP #95
    BCC StarRow
    SBC #95
StarRow:
    STA Tmp
    LDX Tmp
    LDA #1
    STA StarRam,X
    RTS
```

The STARFIELD layout's strip call is the only line that changes:

```asm
    +kf_strip C_STAR, 95, StarRam
```

The RAM map is now `$89–$E7` `StarRam`, `$E8` `Lfsr`, `$E9` `Tmp`, `$EA–$F7` free, `$F8–$FF` stack. On scroll frames the 95 `ASL`s and the LFSR cost about 1,255 cycles; the VBLANK has 2,753. The state log shows the LFSR changing every other frame and `LayoutRead` A=1 at frame 240. The star row covers all 95 lines (the fold maps 95–127 to 0–32), so the bottom of the strip is not starved. The STATUS ramp is static in this solution because the 77-byte ramp buffer and the 95-byte star buffer cannot both fit in the 128-byte RAM; the exercise is the trade, not a free addition.

## Key Takeaways

- ✅ **A kernel is a schedule of bands.** Each zone costs its data lines plus one boundary line; four zones with 188 data lines plus four boundaries make exactly 192. The boundary line is where the next zone is prepared, not wasted space.
- ✅ **The budget is checked at assembly time.** `+kf_begin`/`+kf_end` use an ACME `!set` counter and an `!error`; a 191-line or 193-line layout stops the build with the number in the message.
- ✅ **The boundary line is a contract.** A handler returns at cycle 10 or 13; the next macro clears `PF0`–`PF2`, `GRP0`, `GRP1` and `ENABL` first, then sets the colour and pointer; `STA WSYNC` ends the line. The first `PF0` clear completes before pixel 0, and the next handler's first data store does too; the colour store may land after pixel 0, which is the boundary's one-line gutter.
- ✅ **The first and last lines are special.** VBLANK leaves the first zone's background in `COLUBK` (the prelude), and every layout ends in black so the 13-cycle dispatch tax at 229/19 is invisible.
- ✅ **The selector is a branch, not a ROM vector.** `Layout` lives at `$83` because `$80–$82` are the pattern library's pointer and row count; a write to a ROM jump vector is ignored and a `JMP (vector)` collapses the frame.
- ✅ **The dispatch tax is measured, not guessed.** The last handler returns at cycle 13 of line 229; the layout's `RTS` takes 6 more, so `OverscanStart` is 229/19 and the `STA VBLANK` completes at about 24. The scanline is still 229 and the frame is 262.
- ✅ **A framework buys composition; a generator would target it.** One macro set, a checked budget and a runtime selector cost one line per zone and a dispatch tax. The next step is a layout DSL that emits zone calls, the same relationship Lesson 67's generator has with its engine.

## What's Next

The gallery is the last lesson in Part 9. [Lesson 69: Capstone 1 — Pong](/part10-capstones/69-pong) puts the zone framework to work in a two-player game: a playfield, two paddles, a ball, a score band and a fixed frame budget. The schedule you built here is the tool; the capstone is the test.
