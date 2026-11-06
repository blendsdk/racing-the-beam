---
title: "Lesson 52: Fine Scrolling — Smooth Movement"
description: "Scroll a three-plane 256-row world one scanline per frame with a 40-nominal/41-effective 1-line kernel, move a 16-line ship one pixel at a time with the divide-by-15 and HMOVE dance, and explain the 4-pixel playfield against the 1-pixel sprite."
prev:
  text: "Lesson 51: Flicker Sprites — More Than 2 Objects"
  link: "/part7-kernel-mastery/51-flicker-sprites"
next:
  text: "Lesson 53: Kernel Design Patterns — Building Your Toolkit"
  link: "/part7-kernel-mastery/53-kernel-patterns"
---

# Lesson 52: Fine Scrolling — Smooth Movement

> **Part 7: Kernel Mastery** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 15 (the RIOT timer), Lesson 17 (cycle counting), Lesson 18 (mid-scanline changes), Lesson 19 (the playfield), Lesson 26 (positioning), Lesson 27 (sprite movement), Lesson 28 (one `HMOVE`), Lesson 31 (`NUSIZ`), Lesson 34 (frame counters), Lesson 48 (the 1-line kernel)
> **You will learn:** how to scroll a 256-row world one scanline at a time by indexing three page-aligned playfield planes with `ScrollY`; how the reflected playfield makes a centred tunnel whose gap breathes with a 32-row sine; why the 1-line kernel's stores and loop tail fit in 40 nominal / 41 effective of the 76 cycles; why `X` 255→0 stays inside a page-aligned 256-byte plane; how the divide-by-15 and `HMOVE` dance moves the ship one pixel at a time while the playfield moves in 4-pixel chunks; and why the late `GRP0` store shifts the ship one line down at the far left
> **You will build:** "the tunnel" — a 4,096-byte ROM with three 256-byte playfield planes, a 192-line 1-line kernel at 40 cycles nominal (41 effective, because the loop's taken `BNE` crosses a page), a 32-row sine that breathes the central gap between 6 and 10 chunks, a 16-line white ship that sweeps one pixel per frame and follows the joystick, and one `HMOVE` per frame; plus three exercise solutions: a reversed scroll, a two-row-per-frame scroll, and a half-speed ship

## Introduction

Lesson 49 built the standard two-line kernel and Lesson 51 made four objects share two players. Both pictures were static: the world did not move. This lesson turns the kernel around. The world is a table of rows, the scroll is an index, and moving the picture is as cheap as adding one to a byte.

The companion program `52-fine-scrolling.asm` is **the tunnel**. Three page-aligned 256-byte playfield planes hold a complete world: green walls, a dark central gap, and a gap width that breathes with a 32-row sine. Every visible line reads one byte from each plane at the same world row, so incrementing `ScrollY` moves every wall feature up one scanline. The picture is one 1-line kernel for all 192 visible lines; there is no second zone and no second `HMOVE`.

The ship is the lesson's second kind of motion. The playfield moves in 4-pixel chunks because each playfield bit is four colour clocks wide; the ship moves in single pixels because it is a player positioned by `RESP0` and `HMOVE`. The two motions sit on the same screen and make the hardware's horizontal resolution split visible: a 4-pixel world scrolling one line at a time, and a 1-pixel sprite sliding over it.

The 32-row period is the honesty device. It divides 256, so the world joins cleanly at row 255→0; it also means a still capture can measure the world's phase but not the exact 0–255 scroll byte. The state log fills that gap: `ScrollYWrite` reports the byte increasing by one every frame and wrapping 255→0 on frame 256.

::: details TypeScript Equivalent

A scroll offset and a world-table lookup are the whole idea. In TypeScript the renderer is a function of the scroll byte and the visible line:

```typescript
const WORLD_ROWS = 256;
const SCREEN_LINES = 192;

function halfWidth(worldRow: number): number {
  return 4 + Math.round(Math.sin((2 * Math.PI * (worldRow % 32)) / 32));
}

function renderLine(scrollY: number, line: number): Line {
  const worldRow = (scrollY + line) & 0xff;
  return {
    pf0: worldPF0[worldRow],
    pf1: worldPF1[worldRow],
    pf2: worldPF2[worldRow],
    ship: shipStrip[line],
  };
}
```

The `& 0xff` is the 6502's byte wrap, and the `% 32` is why the tunnel breathes. The analogy breaks where the hardware starts. There is no framebuffer and no `renderLine` function that can run whenever it likes: the kernel runs while the beam moves, and each line's four stores must land before the beam reaches the pixels they affect. The 4-pixel playfield is a hardware quantization, not a renderer's choice, and the reflected 20-bit half cannot move its centre. Finally, `renderLine(scrollY, line)` and `renderLine(scrollY + 32, line)` return exactly the same row: a still image cannot tell the two scroll bytes apart.

:::

## Theory

### Section 1: The World Is a Table, the Scroll Is an Index

The tunnel is 256 rows tall. Each row is three playfield bytes, but they are stored as three separate **planes** rather than one row-major table:

| Plane | Playfield chunks | Size |
|---|---|---|
| `WorldPF0` | 0–3 | 256 bytes |
| `WorldPF1` | 4–11 | 256 bytes |
| `WorldPF2` | 12–19 | 256 bytes |

This is the first design decision, and it comes from the kernel. The kernel reads one byte from each plane at the **same** world row and stores them to `PF0`, `PF1` and `PF2` on the same scanline. A row-major table (`row*3 + plane`) would need a multiply or a pointer advance per line; three parallel planes make the row index the same `X` for all three loads.

The visible row `y` reads world row `(ScrollY + y) & 255`. `ScrollY` is a single byte in RAM, so adding one moves the whole world one scanline. The 6502's byte arithmetic gives the 255→0 wrap for free: `LDA ScrollY; CLC; ADC #1; STA ScrollY` stores `$00` after `$FF`, and the next line reads world row 0. Because the planes are exactly 256 bytes, the same `X` that wrapped from 255 to 0 stays inside the plane.

Each plane is page-aligned:

```asm
    !align 255, 0
WorldPF0:
    !fill WORLD_ROWS, $F0
```

`!align 255, 0` pads until the program counter is on a page boundary. The plane then occupies one whole page, `$xx00–$xxFF`. `LDA WorldPF0,X` with `X` 0–255 can never cross into the next page, so the indexed load is four cycles, not five. The same rule applies to the ship strip: its 192 bytes start at a page boundary, so `LDA ShipStrip,Y` with `Y` 0–191 also stays inside one page.

::: tip The 255→0 wrap is invisible here
The gap's half-width is 4 + round(sin(2π·row/32)). Row 255 has phase 31; row 0 has phase 0. Both are half-width 4, so the seam between the last row of the world and the first row is the same width. That is the "32 divides 256" fact doing real work: a 32-row period fits exactly eight times into the 256-row world.
:::

The world costs 768 bytes and the ship strip 192 bytes, so the data is 960 of the 4,096 bytes. The rest is code, alignment padding and vectors. That is a typical 2600 trade: a full-screen scrolling world is data, and the kernel is small.

### Section 2: The Tunnel's Breathing Gap

A playfield row is 20 chunks per half. Each chunk is 4 colour clocks wide, so one half is 80 pixels and the reflected screen is 160 pixels. `CTRLPF` bit 0 is 1, so the right half mirrors the left; the gap therefore straddles the centre and is always symmetric.

The left wall fills chunks `0..e-1`, and the reflection fills the mirror on the right. The gap is chunks `e..(39-e)`, so its width is `2 × (20 - e)` chunks. The lesson defines the gap's **half-width** directly:

```
half = 4 + round(sin(2π × (row mod 32) / 32))
```

The half-width is 3, 4 or 5 chunks, so the gap is 6, 8 or 10 chunks wide — 24, 32 or 40 TIA pixels, or 144, 192 or 240 capture pixels at the course's 6× capture scale. The wall always covers chunks 0–14, so `PF0` is `$F0` and `PF1` is `$FF` on every row; only `PF2`'s low bits move:

| Rows (phase) | Half-width | Gap width | Left wall | `PF2` | Gap chunks |
|---|---|---|---|---|---|
| 0–2, 14–18, 30–31 | 4 | 8 chunks | chunks 0–15 | `$0F` | 16–23 |
| 3–13 | 5 | 10 chunks | chunks 0–14 | `$07` | 15–24 |
| 19–29 | 3 | 6 chunks | chunks 0–16 | `$1F` | 17–22 |

The sequence is 3 rows of 8, 11 rows of 10, 5 rows of 8, 11 rows of 6, 2 rows of 8 — and then it repeats. The sine is sampled at 32 rows but quantized to three integer widths, so the "breathing" is a staircase rather than a smooth curve. That is the playfield's horizontal resolution: one chunk is four pixels, and the gap can only change by a whole chunk.

`PF2`'s bits run in chunk order: bit 0 is chunk 12, bit 1 is chunk 13, and so on. A half-width of 5 lights chunks 12–14 (`$07`), 4 lights 12–15 (`$0F`), and 3 lights 12–16 (`$1F`). The doc's pixel checks measure exactly these widths at the capture scale.

The gap's centre is fixed at TIA X=80 (capture x=504.5 at the course's capture scale) because the reflected halves are symmetric. A 3-byte reflected playfield cannot snake sideways; only its width can change. This is the hardware fact the lesson states plainly: the tunnel breathes, but it does not bend. The 1-pixel ship is the object that can move sideways.

::: warning The gap is background, not a colour
The gap is not a fourth playfield colour or a black ball. It is the background showing through unlit playfield chunks, so `COLUBK=$02` fills it. The walls are `COLUPF=$C8`. If you change `COLUBK`, the tunnel's centre changes with it; the wall colour and the gap colour are independent registers.
:::

### Section 3: The 1-Line Kernel — 40 Cycles Nominal, 41 Effective

The picture is one 1-line kernel. Each iteration draws one scanline, so 192 iterations fill the 192-line visible area:

```asm
    LDX ScrollY
    LDY #0
KernelRow:
    LDA WorldPF0,X
    STA PF0
    LDA WorldPF1,X
    STA PF1
    LDA WorldPF2,X
    STA PF2
    LDA ShipStrip,Y
    STA GRP0
    STA WSYNC
    INX
    INY
    CPY #SCREEN_LINES
    BNE KernelRow
```

The cycle ledger is the lesson's arithmetic:

| Work | Cycles |
|---|---|
| `LDA WorldPF0,X` + `STA PF0` | 7 |
| `LDA WorldPF1,X` + `STA PF1` | 7 |
| `LDA WorldPF2,X` + `STA PF2` | 7 |
| `LDA ShipStrip,Y` + `STA GRP0` | 7 |
| `STA WSYNC` | 3 |
| `INX` | 2 |
| `INY` | 2 |
| `CPY #192` | 2 |
| `BNE` (taken) | 3 |
| taken-branch page cross (`BNE KernelRow`, $F1 → $F0) | 1 |
| **total** | **40 nominal / 41 effective** |

The 1-line budget is 76 cycles, so the kernel leaves 35 cycles of margin. `STA WSYNC` writes on its third cycle and then stalls the CPU until the next horizontal blank; the 35 unused cycles are simply waited out. The last row's `BNE` is not taken (2 cycles instead of 4), so the last line is 39 cycles and the loop falls through to `OverscanStart`.

The stores are **work-first**: the line's registers are written, then `WSYNC`. The order inside the body follows the beam. `PF0`'s field starts at pixel 0, `PF1`'s at pixel 16 (chunk 4), `PF2`'s at pixel 48 (chunk 12), and the ship can start as early as pixel 24. In steady state the `WorldRead` checkpoint is at cycle 14; the three playfield stores then complete around cycles 16, 23 and 30, and `GRP0` around cycle 37. These follow from the logged cycle and the 3-cycle stores. The first three are safely before their fields; the `GRP0` store is the one that races the ship's left edge, which Section 5 measures.

The loop tail runs **after** `WSYNC`, at the top of the next line: `INX` (2), `INY` (2), `CPY` (2), `BNE` (4, because the taken branch crosses from $F1 to $F0). That is why the next line's first load begins at cycle 10 and the first store completes at 16, not at 0. The 40-cycle nominal / 41-cycle effective figure is the active work; the line itself is always 76 cycles because `WSYNC` owns the rest.

::: tip Why the tables are page-aligned
An indexed absolute load (`LDA WorldPF0,X`) is four cycles when the index stays inside the base page, and five when it crosses a page boundary. A 256-byte plane at a page boundary never crosses for `X` 0–255, so the indexed loads need no page-cross allowance. The ship strip is 192 bytes at a page boundary, so `Y` 0–191 is also page-contained. The loop's `BNE` is a separate page cross: the branch sits at $F100 and its target at $F0E6, so the taken branch costs 4, not 3. That is the 41 effective cycles; moving a plane off the boundary would make the worst case 42.
:::

### Section 4: The Ship: One Pixel at a Time

The ship is a 16-byte strip, one byte per line, placed at rows 150–165:

```asm
ShipStrip:
    !fill SHIP_TOP, $00
    !byte $18, $18, $3C, $3C, $7E, $7E, $FF, $FF
    !byte $E7, $E7, $C3, $C3, $81, $81, $18, $18
    !fill 26, $00
```

Because this is a 1-line kernel, each byte is one scanline, so the ship is 16 lines tall. The shape is a pointed nose, a widening body, engine gaps and two tail fins. The strip is page-aligned; `Y` 0–191 never crosses a page.

The ship's horizontal position is a player position, not a playfield bit. `ShipX` is clamped to 24–136. An 8-pixel player at X=24 ends at 31; at X=136 it ends at 143, inside the 160-pixel field. The clamp leaves a 24-pixel margin on the left and a 16-pixel margin on the right.

Positioning is the Lesson 26 divide-by-15 dance plus one `HMOVE`:

```asm
    LDA ShipX
ShipXRead:
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
HmoveApply:
    STA WSYNC
    STA HMOVE
HmoveDone:
    NOP
```

`SetCoarseP0` starts with `STA WSYNC`, then subtracts 15 repeatedly. Each iteration is 5 cycles = 15 colour clocks, so the quotient is the coarse 15-pixel step and the remainder becomes the fine value in `HMP0`. `RESP0` strobes the coarse position; the caller's `STA WSYNC` starts a fresh line and `STA HMOVE` applies the fine offset in the next line's horizontal blank. The `NOP` at `HmoveDone` keeps the checkpoint separate from the `LDA INTIM` poll inside `+wait_timer`, so a breakpoint at the label hits once per frame.

The joystick is read in VBLANK:

```asm
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ AutoShip
    CMP #$80
    BEQ MoveLeft
    CMP #$40
    BEQ MoveRight
    JMP AutoShip
```

`SWCHA`'s P0 direction bits are active low. The raw masks are `$40` (left) and `$80` (right); after `AND #$C0`, a left press reads `$80` and a right press reads `$40`. Left subtracts the step (a `DEC` when `ShipHalf` is 1); right adds it (an `INC` when the step is 1). With no input the auto-demo takes over: `ShipDir` flips at a limit and the same frame steps back, so a full 24→136→24 sweep is 112 + 112 = 224 frames. The ship powers on at 80, so the first cycle is shorter.

The `HMOVE` is the only one in the frame. It runs on scanline 3, inside VBLANK, so its eight-pixel left-edge blanking is invisible. `HMOVE` re-applies `HMP0` every frame; that is why the code always re-strobes `RESP0` even when `ShipHalf` is 0. Skipping the coarse reset would let `HMOVE` shift the ship again every frame; the direction follows `HMP0`'s signed value (right at the power-on X=80, where `HMP0=$E0`, i.e. −2).

::: tip The two resolutions
The playfield moves in 4-pixel chunks because one playfield bit is four colour clocks. The ship moves in one-pixel steps because a player's position is set by `RESP0` plus the `HMP0` fine offset. The 1-line kernel draws both, but their horizontal granularity is different: the tunnel's wall can only step by 4 pixels, while the ship can land on any pixel. That is the hardware split the lesson's title names.
:::

### Section 5: The Latch Window and the 32-Row Phase

`GRP0` is the last register store before `WSYNC`. In steady state the state log puts `ShipWrite` at cycle 35, with the TIA pixel column at 37. `STA GRP0` writes on its third cycle, so the new byte applies a few pixels later — the write lands around pixel 43 and the TIA latches it around pixel 44, derived from the logged pixel column and the three-pixels-per-cycle beam. A ship at X≤36 is entirely left of that point (X+7≤43), so on that scanline P0 still displays the previous row's byte. The ship is shifted down by one line; the shape is not truncated, because the previous byte is the row above. X=37–43 straddles the latch: the left columns are one line behind and the right columns are current. From X≥44 the whole byte is current. The bbox measurements follow the shape: the top and bottom rows' ink sits at columns 3–4, so the top row turns current at X=40 and the bottom's left ink at X=40 still lags; the bbox looks clean from X=41, but the leftmost columns do not clear until X=44.

The lesson's captures stay on the clean side. The `tunnel-a` image has the ship at X=48 and the `tunnel-b` image at X=88; both measure visible lines 150.2–165.7, the nominal 16-line window. A test capture with the ship at X=36 measured visible lines 151.4–166.7: the whole 8-pixel sprite is left of the latch, so the top line is blank and the bottom row appears one line lower. The two shipped captures at X=48 and X=88 are fully on the clean side.

This is the same beam-race trade-off Lesson 49 measured for its late stores. The kernel's order is fixed by the 40/41 ledger: moving `GRP0` earlier would mean moving another store later, and the playfield's own deadlines are tighter at the left edge. The lesson documents the window instead of hiding it.

The 32-row period has a second consequence. Because the world is exactly 32-row periodic and only 192 rows are visible, `ScrollY` and `ScrollY + 32` produce identical pictures. A still capture can therefore measure the **phase** — `ScrollY mod 32` — but not the exact 0–255 byte. The two screenshots measure phase 0 and phase 8, which are the intended 0 and 40 modulo 32. The state log proves the byte's behaviour: it increments by one every frame and wraps 255→0 on frame 256.

## The Code

### Building This Lesson

```bash
# every lesson ROM, including this one:
npm run roms

# or just this one:
acme -f plain -o build/lesson52.bin \
  lessons/part7-kernel-mastery/52-fine-scrolling/52-fine-scrolling.asm

stella build/lesson52.bin
```

The three exercise solutions sit beside the lesson source. Each is a complete 4,096-byte ROM:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part7-kernel-mastery/52-fine-scrolling/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part7-kernel-mastery/52-fine-scrolling/exercise-02-solution.asm
acme -f plain -o build/exercise-03.bin \
  lessons/part7-kernel-mastery/52-fine-scrolling/exercise-03-solution.asm
```

### Full Source

The complete annotated source is reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 52: Fine Scrolling — The Tunnel — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; What this program does:
;   "the tunnel": a full-screen vertical scroller.  The world is three
;   page-aligned 256-byte playfield planes (WorldPF0, WorldPF1, WorldPF2).
;   Every visible line reads one byte from each plane at the same world row
;   (ScrollY + the visible row), so scrolling the world one line is just
;   incrementing ScrollY.  The playfield is reflected (CTRLPF=$01); the lit
;   chunks are the green walls and the unlit centre is the background gap.
;   The gap's half-width follows a 32-row sine: 4 + round(sin(2*pi*row/32)),
;   so the gap is 6, 8 or 10 chunks wide.  The 32-row period divides 256, so
;   world row 255 joins world row 0 cleanly.
;
;   The picture is one 1-line kernel for all 192 visible lines:
;
;     LDX ScrollY
;     LDY #0
;   Loop:
;     LDA WorldPF0,X / STA PF0
;     LDA WorldPF1,X / STA PF1
;     LDA WorldPF2,X / STA PF2
;     LDA ShipStrip,Y / STA GRP0
;     STA WSYNC
;     INX / INY / CPY #192 / BNE Loop
;
;   That is 40 cycles nominal / 41 effective per line: three playfield
;   load/store pairs (3 x 7 = 21), the ship load/store (7), WSYNC (3) and the
;   loop tail (INX 2 + INY 2 + CPY 2 + BNE 4 = 10; the taken BNE crosses from
;   $F1 to $F0).  The 76-cycle line leaves 35 cycles of margin.  Every plane
;   is page-aligned and the ship strip is page-aligned, so X 255 -> 0 stays
;   inside its plane and Y 0..191 stays inside the strip: no indexed load
;   pays a page cross.  (Exercise 1's layout is three bytes shorter, so its
;   BNE is page-local and its body is 40.)
;
;   The ship is a 16-byte (16-line) strip at rows 150-165, drawn on P0.  ShipX
;   moves one pixel per frame with the divide-by-15 + HMOVE positioning dance
;   and is clamped to 24..136.  The joystick's left/right overrides the
;   auto-demo; with no input the ship sweeps 24 -> 136 -> 24 at one pixel per
;   frame.
;
;   THE LATCH WINDOW.  The GRP0 store is the last register store before
;   WSYNC; in steady state the state log puts the store's first cycle at 35,
;   so it completes on cycle 37.  The TIA shows the line from cycle 22.7, so
;   the new byte applies from TIA pixel ~43-44.  A ship at X<=36 is entirely
;   left of that point: on that line P0 displays the previous row's byte, so
;   the ship appears one scanline lower.  X=37..43 straddles (left columns
;   old, right columns current); from X>=44 it is current.  The bbox turns
;   clean at X=41 because the top/bottom rows' ink sits at columns 3-4.
;   This is the same beam-race
;   trade-off Lesson 49 measures for its late stores; the lesson document
;   records the measured window.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), OverscanStart (229);
;   ScrollStep (A = the step, 1 in this source); ScrollYWrite (A = the new
;   ScrollY); WorldRead (A = a WorldPF0 byte, $F0); ShipXRead (A = the
;   ship's left edge); ShipWrite (A = the ship byte at the GRP0 store);
;   HmoveApply (the WSYNC stall), HmoveDone (the NOP after the HMOVE store;
;   the store completes at 3/2).
;
; RAM map (+clean_start zeroes every byte):
;   $80   ScrollY    the world row at the top of the screen, 0..255
;   $81   ShipX      the ship's left edge, TIA X 24..136
;   $82   ShipDir    the auto-demo's direction: 0 = left, 1 = right
;   $83   ShipHalf   the ship's step this frame: 1 here, 0/1 half speed
;   $84-$F7 free
;   $F8-$FF stack
;
; Build: acme -f plain -o build/lesson52.bin \
;        lessons/part7-kernel-mastery/52-fine-scrolling/52-fine-scrolling.asm
; Run:   stella build/lesson52.bin
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

SCREEN_LINES   = 192     ; the 1-line kernel draws every visible line
WORLD_ROWS     = 256     ; each plane has one byte per world row
WORLD_PERIOD   = 32      ; the gap's sine repeats every 32 rows
SHIP_TOP       = 150     ; the ship's first visible row
SHIP_LINES     = 16      ; 16 bytes, one line per byte
SHIP_MIN       = 24      ; the ship's left limit (TIA X)
SHIP_MAX       = 136     ; the ship's right limit (8 pixels wide)
SHIP_START     = 80      ; power-on position; the auto-demo takes it from here
SCROLL_SPEED   = 1       ; world rows per frame (the exercise can raise it)

C_WALL         = $C8     ; the playfield walls: green
C_BG           = $02     ; the gap and the borders: the background
C_SHIP         = $0E     ; the ship: white

; The 32-row sine must divide the 256-row world exactly.  The !if turns
; that arithmetic into a build-time check rather than a comment.
!if WORLD_PERIOD * 8 != WORLD_ROWS {
    !error "the 32-row sine must fit eight times into the 256-row world"
}

; =============================================================================
; RAM ALLOCATION ($80-$83; +clean_start zeroes every byte)
; =============================================================================
ScrollY      = $80   ; the world row drawn at visible line 0, 0..255
ShipX        = $81   ; the ship's left edge, 24..136
ShipDir      = $82   ; the auto-demo's direction: 0 = left, 1 = right
ShipHalf     = $83   ; the per-frame step: 1 (0 or 1 in the half-speed lab)
;
; $84-$F7 are free (116 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (SetCoarseP0).

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
    STA SWACNT              ; port A is an input port (the joystick)

    LDA #$00
    STA ScrollY             ; the first VBLANK step makes it 1
    LDA #SHIP_START
    STA ShipX               ; the ship starts in the middle
    LDA #$01
    STA ShipDir             ; the auto-demo sweeps right first
    STA ShipHalf            ; one pixel per frame

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; the gap shows the background
    LDA #C_WALL
    STA COLUPF              ; the walls are green
    LDA #C_SHIP
    STA COLUP0              ; the ship is white
    LDA #$01
    STA CTRLPF              ; reflect: the right half mirrors the left
    LDA #$00
    STA NUSIZ0              ; one 8-pixel copy of P0
    STA GRP0
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
; 1. THE SCROLL — one world row per frame, wrapping 255 -> 0
; -----------------------------------------------------------------------------
; ScrollY is the world row drawn at visible line 0.  Adding one moves every
; wall feature up one scanline.  The world is 256 rows long and the index is a
; byte, so 255 + 1 wraps to 0 for free; the 32-row sine makes that seam
; invisible (row 255 and row 0 have the same half-width).
    LDA #SCROLL_SPEED
ScrollStep:                 ; checkpoint: A = the step (1)
    CLC
    ADC ScrollY
    STA ScrollY
ScrollYWrite:               ; checkpoint: A = the new ScrollY

; -----------------------------------------------------------------------------
; 2. THE SHIP — joystick left/right, or the auto-demo's sweep
; -----------------------------------------------------------------------------
; SWCHA's P0 direction bits are active low.  The raw masks are $40 (left)
; and $80 (right); after AND #$C0, a left press reads $80 and a right press
; reads $40 (the other bit stays high).  $C0 is neither; $00 (both) is
; ignored.  The clamp keeps the 8-pixel ship inside TIA X 24..136.
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ AutoShip
    CMP #$80
    BEQ MoveLeft
    CMP #$40
    BEQ MoveRight
    JMP AutoShip            ; both directions held: treat as no input

MoveLeft:
    LDA ShipX
    CMP #SHIP_MIN
    BEQ MoveDone
    SEC
    SBC ShipHalf
    STA ShipX
    JMP MoveDone

MoveRight:
    LDA ShipX
    CMP #SHIP_MAX
    BEQ MoveDone
    CLC
    ADC ShipHalf
    STA ShipX
    JMP MoveDone

; The auto-demo: one pixel per frame between the limits.  At a limit the
; direction flips and the same frame steps back, so a full 24 -> 136 -> 24
; cycle is 112 + 112 = 224 frames.  (The first cycle is shorter because the
; ship powers on at SHIP_START.)
AutoShip:
    LDA ShipDir
    BNE AutoRight
    LDA ShipX
    CMP #SHIP_MIN
    BEQ AutoFlipRight
    SEC
    SBC ShipHalf
    STA ShipX
    JMP MoveDone
AutoRight:
    LDA ShipX
    CMP #SHIP_MAX
    BEQ AutoFlipLeft
    CLC
    ADC ShipHalf
    STA ShipX
    JMP MoveDone
AutoFlipLeft:
    LDA #$00
    STA ShipDir
    LDA ShipX
    SEC
    SBC ShipHalf
    STA ShipX
    JMP MoveDone
AutoFlipRight:
    LDA #$01
    STA ShipDir
    LDA ShipX
    CLC
    ADC ShipHalf
    STA ShipX
MoveDone:
    LDA ShipX
ShipXRead:                  ; checkpoint: A = the ship's left edge
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0

; -----------------------------------------------------------------------------
; 3. ONE HMOVE — the coarse reset is set, then one strobe
; -----------------------------------------------------------------------------
; SetCoarseP0 has set HMP0 and strobed RESP0.  The WSYNC starts a fresh line
; and HMOVE applies the fine offset in its HBLANK.  This is the only HMOVE in
; the frame, and it falls inside VBLANK, so its left-edge blanking is unseen.
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed
    NOP                     ; keep HmoveDone distinct from the timer poll

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines, one line per row, work-first
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; The row loop is the course's top-down form: LDY #0, draw row Y, then
; INY / CPY #192 / BNE.  Y is both the row counter and the ship-strip index,
; so row 0 is the top of the screen and row 191 is the bottom.  X is the
; world row: it starts at ScrollY and wraps 255 -> 0 inside the page-aligned
; planes.  There is no sentinel; the ship strip is exactly 192 bytes.
    LDX ScrollY
    LDY #0
KernelRow:                  ; checkpoint: Y = 0..191, the visible row
    LDA WorldPF0,X
WorldRead:                  ; checkpoint: A = the WorldPF0 byte ($F0)
    STA PF0                 ; chunks 0-3
    LDA WorldPF1,X
    STA PF1                 ; chunks 4-11
    LDA WorldPF2,X
    STA PF2                 ; chunks 12-19: the breathing inner edge
    LDA ShipStrip,Y
ShipWrite:                  ; checkpoint: A = the ship byte, at the GRP0 store
    STA GRP0                ; the ship's line for this row
    STA WSYNC               ; the line is complete; wait for the next
    INX                     ; next world row
    INY                     ; next visible row
    CPY #SCREEN_LINES
    BNE KernelRow
; 192 rows x 1 line = visible 0-191.  The last WSYNC releases the CPU on
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
; THE WORLD — three page-aligned 256-byte planes
; =============================================================================
; A playfield row is chunks 0-3 (PF0), 4-11 (PF1) and 12-19 (PF2); the
; reflection draws the mirror on the right.  The wall always covers chunks
; 0..14, so PF0 is $F0 and PF1 is $FF on every row; only PF2's inner edge
; moves.  The gap's half-width is 4 + round(sin(2*pi*row/32)):
;
;   half  gap   left wall  PF2     gap chunks
;   3     6     0..16      $1F     17..22
;   4     8     0..15      $0F     16..23
;   5     10    0..14      $07     15..24
;
; The 32-row period divides 256, so the table below is the same 32-byte
; period eight times.  Every plane is page-aligned: X 255 -> 0 wraps inside
; the plane, so no indexed load crosses a page.
    !align 255, 0
WorldPF0:
    !fill WORLD_ROWS, $F0

    !align 255, 0
WorldPF1:
    !fill WORLD_ROWS, $FF

    !align 255, 0
WorldPF2:
    ; world rows 0-15: half 4, 4, 4, then 5 from row 3
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    ; world rows 16-31: half 4, 4, 4, then 3 from row 19
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 32-63: the same period again
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 64-95
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 96-127
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 128-159
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 160-191
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 192-223
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; rows 224-255
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F

; =============================================================================
; THE SHIP STRIP — 192 bytes, one per visible line
; =============================================================================
; The 16 shape bytes sit at rows 150-165.  Each byte is one scanline (this is
; a 1-line kernel), so the ship is 16 lines tall: a pointed nose, a widening
; body, engine gaps and two tail fins.  The strip is page-aligned so Y 0..191
; never crosses a page.
    !align 255, 0
ShipStrip:
    !fill SHIP_TOP, $00
    !byte $18, $18, $3C, $3C, $7E, $7E, $FF, $FF
    !byte $E7, $E7, $C3, $C3, $81, $81, $18, $18
    !fill SCREEN_LINES - SHIP_TOP - SHIP_LINES, $00

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
> `lessons/part7-kernel-mastery/52-fine-scrolling/52-fine-scrolling.asm`.

### Code Walkthrough

#### Step 1 — The frame skeleton

```asm
StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    ; ... the scroll, the ship, the HMOVE ...
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

BodyStart:
    LDX ScrollY
    LDY #0
    ; ... the 192-line kernel ...
```

The frame is the Part 2–6 skeleton: 3 VSYNC lines, 37 VBLANK lines, 192 picture lines and 30 overscan lines, 262 in total. `StartFrame` is scanline 259, `VblankStart` 0, `BodyStart` 37 and `OverscanStart` 229. The state log confirms all four.

#### Step 2 — The scroll update

```asm
    LDA #SCROLL_SPEED
ScrollStep:
    CLC
    ADC ScrollY
    STA ScrollY
ScrollYWrite:
```

`ScrollY` is the world row drawn at visible line 0. Adding one moves every wall feature up one scanline; adding two moves it two. The byte wraps 255→0 without a branch, and the page-aligned planes make the wrap safe. `ScrollStep` reports the step in A and `ScrollYWrite` reports the new byte, which is how the state log proves the one-per-frame increment.

#### Step 3 — The ship and the joystick

```asm
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ AutoShip
    CMP #$80
    BEQ MoveLeft
    CMP #$40
    BEQ MoveRight
    JMP AutoShip
```

The four branches read the active-low joystick. Left (`$80`) subtracts the step (a `DEC` when `ShipHalf` is 1); right (`$40`) adds it (an `INC` when the step is 1); neither (`$C0`) or both (`$00`) falls into the auto-demo. The clamp checks `SHIP_MIN` and `SHIP_MAX` before the step, and the auto-demo flips `ShipDir` at a limit. `ShipXRead` reports the resulting X in A.

#### Step 4 — One HMOVE

```asm
HmoveApply:
    STA WSYNC
    STA HMOVE
HmoveDone:
    NOP
```

`SetCoarseP0` has already set `HMP0` and strobed `RESP0`. The `WSYNC` starts a fresh line; `HMOVE` applies the fine offset in its horizontal blank; `HmoveDone` reports the `NOP` after the store at scanline 3 cycle 3; the `HMOVE` store completes at 3/2. The `NOP` separates the checkpoint from the timer poll. There is no second `HMOVE` in the frame.

#### Step 5 — The 192-line kernel

```asm
KernelRow:
    LDA WorldPF0,X
WorldRead:
    STA PF0
    LDA WorldPF1,X
    STA PF1
    LDA WorldPF2,X
    STA PF2
    LDA ShipStrip,Y
ShipWrite:
    STA GRP0
    STA WSYNC
    INX
    INY
    CPY #SCREEN_LINES
    BNE KernelRow
```

`X` is the world row and `Y` is the visible row. `X` starts at `ScrollY` and wraps 255→0; `Y` starts at 0 and ends at 191. The four picture stores are work-first; `WSYNC` owns the rest of the 76-cycle line. `WorldRead` reports the `PF0` byte ($F0) and `ShipWrite` reports the ship byte at the `GRP0` store.

#### Step 6 — The world data

The three planes are page-aligned and exactly 256 bytes. `WorldPF0` and `WorldPF1` are constant because the wall always covers chunks 0–14; `WorldPF2` holds the 32-row sine, repeated eight times:

```asm
    !align 255, 0
WorldPF2:
    !byte $0F,$0F,$0F,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$0F,$0F
    !byte $0F,$0F,$0F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$0F,$0F
    ; ... the same 32 bytes, eight periods ...
```

The `$0F` rows are 8-chunk gaps, `$07` is 10 chunks and `$1F` is 6 chunks. The 32-row period divides 256, so the last period ends exactly at world row 255 and the first row of the next frame joins it.

#### Step 7 — Reading it back in Stella

Assemble with a symbol file and ask Stella for the checkpoints:

```bash
acme -f plain -l build/lesson52.sym -o build/lesson52.bin \
  lessons/part7-kernel-mastery/52-fine-scrolling/52-fine-scrolling.asm

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F061' build/lesson52.bin
```

Run each checkpoint separately for a readable log. The addresses below are the ones this source produced. A breakpoint on a label reports the first cycle of the instruction that follows it; the store it labels completes on that instruction's last cycle.

### Checkpoints

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F043` | 259/3 | the first VSYNC line |
| `VblankStart` | `$F051` | 0/5 | the first VBLANK line |
| `ScrollStep` | `$F05C` | A=1 every frame | the world step |
| `ScrollYWrite` | `$F061` | A=1, 2, 3 …; 255→0 on frame 256 | the new `ScrollY` |
| `ShipXRead` | `$F0CC` | A=81, 82 …; 24..136 | the ship's left edge |
| `HmoveApply` | `$F0D2` | 2/53 | the `WSYNC` before the `HMOVE` |
| `HmoveDone` | `$F0D6` | 3/3 | the `NOP` after the `HMOVE` store; the store completes at 3/2 |
| `BodyStart` | `$F0E2` | 37/5 | visible line 0 |
| `KernelRow` | `$F0E6` | Y=0..191 | the visible row |
| `WorldRead` | `$F0E9` | A=$F0, cycle 14 | the `WorldPF0` byte |
| `ShipWrite` | `$F0F8` | A=the ship byte, cycle 35 | the `GRP0` store |
| `OverscanStart` | `$F102` | 229/8 | the first blank line after the picture |

## What You Should See

The picture is a full-screen green tunnel with a dark central gap. The gap is 8 chunks wide at the top of `tunnel-a`, breathes to 10 chunks, narrows to 6 chunks, and returns to 8; the same sequence repeats every 32 visible lines because the world is 32-row periodic. A white 16-line ship sits at the bottom of the wall and moves one pixel per frame; with no input it sweeps 24→136→24.

![Stella running the Lesson 52 ROM at world phase 0: a green reflected playfield with a dark central gap 8 chunks wide at the top, a white 16-line ship at TIA X=48, and the title bar reading Stella 7.0: "52-fine-scrolling"](/images/lesson52/tunnel-a.png)

*`tunnel-a`: the world phase is 0 (mod 32); the gap sequence starts 8, 8, 8, 10, … and the ship is at TIA X=48, visible lines 150.2–165.7. The gap's centre is capture x=504.5 (TIA X=80), the reflected screen's centre.*

<RomPlayer rom="/roms/part7-kernel-mastery/52-fine-scrolling/52-fine-scrolling.bin" title="Lesson 52 — Fine Scrolling" />

![Stella running the Lesson 52 ROM at world phase 8: the same green tunnel with the gap sequence shifted, a white 16-line ship at TIA X=88, and the title bar reading Stella 7.0: "52-fine-scrolling"](/images/lesson52/tunnel-b.png)

*`tunnel-b`: the world phase is 8 (mod 32), which is the intended ScrollY 40 modulo 32. The gap starts 10, 10, 10, 10, 10, 10, 8, … and the ship is at TIA X=88. The two captures show the scroll in two different phases and the ship in two different positions. Click the player screen once to start it: Javatari is muted until a user gesture.*

> **Capture method.** Both images are window captures of
> `docs/public/roms/part7-kernel-mastery/52-fine-scrolling/52-fine-scrolling.bin`
> in Stella 7.0. The pointer was parked at `(0, 0)` before the burst; the title bars read
> `Stella 7.0: "52-fine-scrolling"`. The scroll moves one line per frame, so a single
> timed capture cannot be aimed at a chosen phase. Stella was launched on the committed
> ROM, a burst of 80 window captures was taken with the same `xwininfo` lookup the
> screenshot script uses, and each capture was classified by measuring the gap width on
> the first 32 visible lines. The two images are from that burst, unchanged apart from the
> window frame. The gap widths and the ship positions below are decoded from the captured
> pixels with `capture x = 25 + 6 × TIA X` and `capture y = 107 + 3.15 × visible line`.

The ROM needs no input: the ship's auto-demo sweeps 24→136→24, so both captures are reachable without a key press. The joystick's left/right overrides the auto-demo while held; the state log below shows the two directions.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
ROM=docs/public/roms/part7-kernel-mastery/52-fine-scrolling/52-fine-scrolling.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F061' $ROM   # ScrollYWrite
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0CC' $ROM   # ShipXRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0E9' $ROM   # WorldRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0F8' $ROM   # ShipWrite
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0D6' $ROM   # HmoveDone
```

- **`$F043` (`StartFrame`)** is **259/3**, **`$F051` (`VblankStart`)** **0/5**, **`$F0E2` (`BodyStart`)** **37/5**, and **`$F102` (`OverscanStart`)** **229/8**: 3 + 37 + 192 + 30 = 262 lines.
- **`$F05C` (`ScrollStep`)** reports A=1 every frame, and **`$F061` (`ScrollYWrite`)** reports A=1, 2, 3, … on consecutive frames. Around the wrap the log reads 253, 254, 255, 256→A=$00, 257→A=$01: the byte increments one per frame and wraps 255→0 on frame 256.
- **`$F0CC` (`ShipXRead`)** reports A=81, 82, 83, … after power-on. The sweep reaches **136 on frame 56**, **24 on frame 168**, and **136 again on frame 280**: 112 frames each way, 224 frames per full cycle.
- **Joystick:** with `-holdjoy0 L` the `ShipXRead` log reads A=$4F, $4E, $4D … (79, 78, 77 …), and with `-holdjoy0 R` it reads A=$51, $52, $53 … (81, 82, 83 …): the left branch subtracts and the right branch adds one pixel per frame.
- **`$F0E9` (`WorldRead`)** reports A=$F0 on every line, with X=1, 2, 3, … (the world row) and Y=0, 1, 2, … (the visible row) on the first frame. That is the same `X` feeding all three planes.
- **`$F0F8` (`ShipWrite`)** reports the ship strip's bytes. On scanlines 187–202 (visible lines 150–165) the A column is `$18, $18, $3C, $3C, $7E, $7E, $FF, $FF, $E7, $E7, $C3, $C3, $81, $81, $18, $18`; every other line reports 0 at cycle 35. The store's cycle is the same on every line; the pixel column is 37, and the write completes about six pixels later, around pixel 43.
- **`$F0D2` (`HmoveApply`)** is the `WSYNC` at 2/53 and **`$F0D6` (`HmoveDone`)** is **3/3** every frame: one `HMOVE`, in VBLANK.

The pixel checks decode the captures with the same mapping:

| Check | `tunnel-a.png` | `tunnel-b.png` | Expected |
|---|---|---|---|
| the gap width at rows 0–31 | 8, 8, 8, then 10 × 11, then 8 × 5, then 6 × 11, then 8 × 2 | 10 × 6, then 8 × 5, then 6 × 11, then 8 × 5, then 10 × 5 | the 32-row sine at phase 0 and phase 8 |
| the gap centre | capture x=504.5 | capture x=504.5 | TIA X=80, the reflected screen's centre |
| the wall colour | `(81,179,80)` = `$C8` | `(81,179,80)` = `$C8` | green |
| the gap colour | `(63,63,62)` = `$02` | `(63,63,62)` = `$02` | the background |
| the ship colour | `(234,234,233)` = `$0E` | `(234,234,233)` = `$0E` | white |
| the ship's first ink | capture x=313, TIA X=48.0 | capture x=553, TIA X=88.0 | two different X positions |
| the ship's rows | capture y=580–629, visible 150.2–165.7 | capture y=580–629, visible 150.2–165.7 | the nominal 16-line window |
| the ship's shape | 12, 24, 36, 48, 36, 24, 12, 12 capture pixels of ink per band | the same shape at X=88 | the 16-byte strip's 2/4/6/8/6/4/2/2 pixel pattern |

The screenshots prove the visual state; the state log proves the values, the lines and the cycle. Neither one alone is the whole claim. The thing the still cannot prove is the exact 0–255 scroll byte: the world is 32-row periodic, so `ScrollY` and `ScrollY + 32` look identical. The measured phases are 0 and 8, which are the intended 0 and 40 modulo 32; the state log proves the frame-by-frame byte and the wrap.

## Exercises

### Exercise 1: Reverse the Scroll

**Challenge:** make the tunnel scroll the other way. Decrement `ScrollY` once per frame instead of incrementing it. The kernel, the ship and the frame stay the same.

**Hints:**
1. Replace the `LDA #SCROLL_SPEED / CLC / ADC ScrollY` block with `DEC ScrollY`.
2. `DEC` wraps `$00` to `$FF`, so you do not need a branch for the 0→255 edge.
3. Put `LDA ScrollY` after the `DEC` and label it `ScrollYWrite` so the state log reports the new value in A.
4. The 32-row sine makes the 255→0 seam invisible: row 255 and row 0 both have half-width 4.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `ScrollYWrite` reports A=255, 254, 253, … on consecutive frames, and the tunnel scrolls downward. The state log shows the byte wrapping 0→255 on the next frame; the picture remains continuous.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Faster Scroll

**Challenge:** scroll the world two rows per frame. The `ScrollStep` checkpoint must report A=2.

**Hints:**
1. The lesson already reads its step from `SCROLL_SPEED`; change the constant from 1 to 2.
2. The same `ADC` handles the larger step; the wrap is still byte arithmetic. The byte sequence is even, so the seam is 254→0; it is still inside the 32-row period.
3. `ScrollYWrite` should report 2, 4, 6, … on consecutive frames.
4. The kernel and the ship do not change; the tunnel simply moves twice as fast.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `ScrollStep` reports A=2 and `ScrollYWrite` reports A=2, 4, 6, 8, …; the two captures one frame apart would show a two-line shift. The picture remains stable and the ship still moves one pixel per frame.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Half-Speed Ship *(Stretch Goal)*

**Challenge:** move the ship one pixel every two frames while the tunnel keeps scrolling one line per frame. `ShipStep` must alternate 0 and 1.

**Hints:**
1. `ShipHalf` is already the step used by every movement path. Toggle it before the joystick read: `LDA ShipHalf; EOR #$01; STA ShipHalf`.
2. Put a `ShipStep` label between the `EOR` and the `STA` so a breakpoint reports the new step in A.
3. Every path already adds or subtracts `ShipHalf`; a step of 0 is a no-op, so the movement code does not need a branch.
4. Keep the clamp and the auto-demo; at a limit the direction flips, and the next frame with step 1 moves away.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `ShipStep` reports A=0, 1, 0, 1, … and `ShipXRead` reports 80, 81, 81, 82, 82, … (one pixel every two frames). The tunnel still scrolls one line per frame. The ship is still positioned every frame with the same `HMOVE`; only its step is halved.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **Scroll by indexing a world table.** Three 256-byte planes are read at the same `X`; incrementing `ScrollY` moves the picture one scanline, and the byte wrap 255→0 is free.
- ✅ **Page-align the planes.** A 256-byte plane at a page boundary keeps `X` 255→0 inside the page, so `LDA plane,X` is four cycles and the indexed loads need no page-cross allowance. The loop's `BNE` still crosses a page, so the effective body is 41.
- ✅ **The 1-line kernel is 40 cycles nominal, 41 effective.** Three PF pairs (21), the ship pair (7), `WSYNC` (3), the loop tail (9) and the taken-branch page cross (1); the 76-cycle line leaves 35 cycles of margin.
- ✅ **The reflected playfield makes a centred tunnel.** The 20-bit half is 80 pixels; reflection doubles it to 160, and the gap's width is the only thing that can change. The gap is the background showing through.
- ✅ **The 1-pixel ship is the fine motion.** The divide-by-15 dance sets the coarse position, one `HMOVE` applies the fine offset, and the clamp 24–136 keeps the 8-pixel player on screen. The playfield moves in 4-pixel chunks; the ship moves in single pixels.
- ✅ **The late `GRP0` store has a window.** The store completes on cycle 37, around pixel 43–44, so a ship at X≤36 shows the previous row's byte across the whole sprite; X=37–43 is split, and from X≥44 the window is exact. The two captures (X=48 and X=88) are on the clean side.
- ✅ **A still measures the phase, not the byte.** The world is 32-row periodic, so `ScrollY` and `ScrollY + 32` look identical; the gap width measures `ScrollY mod 32`, and the state log proves the one-per-frame increment and the 255→0 wrap.

## What's Next

The tunnel shows the two axes of motion, but its kernel is still a single shape. [Lesson 53: Kernel Design Patterns — Building Your Toolkit](/part7-kernel-mastery/53-kernel-patterns) packages the fill, playfield-row, sprite-strip and colour-ramp kernels as reusable routines, and combines them into a four-band sampler whose bands can be rearranged without rewriting the screen.
