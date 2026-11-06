---
title: "Lesson 48: Introduction to Kernels — The Heart of Every 2600 Game"
description: "What a kernel is, the five kernel archetypes, the one-line versus two-line trade-off, and a kernel-zoo ROM that draws the same diamond at both vertical resolutions — with a historical tour of Combat, Adventure, Pitfall!, River Raid, and Cosmic Ark."
prev:
  text: "Lesson 47: Development Tools & Workflow"
  link: "/part6-game-dev/47-dev-tools-workflow"
next:
  text: "Lesson 49: The 2-Line Kernel"
  link: "/part7-kernel-mastery/49-two-line-kernel"
---

# Lesson 48: Introduction to Kernels — The Heart of Every 2600 Game

> **Part 7: Kernel Mastery** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC` and timing), Lesson 17 (cycle counting), Lesson 18 (mid-scanline changes), Lesson 19 (the playfield), Lesson 25 (player graphics), Lesson 26 (positioning), Lesson 28 (the one-`HMOVE` rule), Lesson 29 (the ball), Lesson 31 (`NUSIZ`)
> **You will learn:** what a kernel is and why the 2600 needs one; the five kernel archetypes (1-line, 2-line, multi-zone, repositioning, flicker); how the 76-cycle scanline and the 152-cycle two-line pair set the budget; how vertical position comes from *when* you write; how the 1-line/2-line choice trades data and cycles for vertical detail; and how five famous kernels each solved a different data/motion problem
> **You will build:** "the kernel zoo" — a 4,096-byte ROM that draws the same 96-line diamond with a 1-line kernel and a 2-line kernel, switches between split, full-1-line, and full-2-line views with fire (or a 240-frame auto-demo), and moves two 8-pixel dashes with the joystick; plus three exercise solutions: three 64-line zones, a rectangle instead of a diamond, and a fourth mode with an 8-line header, a 176-line play area, and an 8-line footer

## Introduction

Lesson 47 ended with a verified build: the source was assembled, the ROM was tested in Stella, and the site and the screenshot were regenerated from the same commit. This lesson begins the part of the course the whole machine has been circling around: the **kernel**.

A kernel is the code that draws the picture. The 2600 has no frame buffer, no video memory, and no sprite engine. The television beam sweeps the screen about sixty times a second, and the CPU has to put the right bytes into the TIA registers at the right moment for every one of the 192 visible scanlines. The kernel is that routine. Everything else — the game logic, the score, the sound — happens in the blanking periods around it.

The companion program `demo-48.asm` is **the kernel zoo**. It draws one picture three ways. The picture is a diamond 96 scanlines tall and at most 96 pixels wide, plus two white 8-pixel dashes, one on each player. In mode 0 the screen is split: the top half uses a 1-line kernel, so the diamond is smooth; the bottom half uses a 2-line kernel, so the same diamond is chunky. In mode 1 the whole screen is drawn 1 line at a time; in mode 2 the whole screen is drawn 2 lines at a time. The same data, the same shape, three different kernels. Fire cycles the modes, SELECT resets to mode 0, and an auto-demo advances the mode every 240 frames so both screenshots are reachable without touching a control.

By the end of the lesson you can read a kernel's data layout, count its cycles against the 76-cycle line and the 152-cycle pair, and choose the kernel that fits the picture you want to draw.

::: details TypeScript Equivalent

A kernel is a row renderer that runs in lockstep with the display. In TypeScript the same idea is a function that writes one row of a framebuffer:

```typescript
type KernelKind = "one-line" | "two-line" | "multi-zone" | "flicker";

interface RowSource {
  playfield: Uint8Array;   // three bytes per row (PF0, PF1, PF2)
  p0: Uint8Array;          // one byte per row or per two rows
  p1: Uint8Array;
}

function renderRow(visibleRow: number, kind: KernelKind, data: RowSource): void {
  const row = kind === "two-line" ? visibleRow >> 1 : visibleRow;
  writeRegister("PF0", data.playfield[row * 3 + 0]);
  writeRegister("PF1", data.playfield[row * 3 + 1]);
  writeRegister("PF2", data.playfield[row * 3 + 2]);
  writeRegister("GRP0", data.p0[row]);
  writeRegister("GRP1", data.p1[row]);
  if (kind === "two-line") {
    waitScanline();        // the same row is displayed for a second line
    waitScanline();
  } else {
    waitScanline();
  }
}

function renderFrame(kind: KernelKind, data: RowSource): void {
  const rows = kind === "two-line" ? 96 : 192;
  for (let row = 0; row < rows; row++) renderRow(row, kind, data);
}
```

The analogy breaks in the places that matter. The framebuffer does not exist; the "registers" are TIA latches that the beam reads as it passes, and a write that lands after the beam has passed the relevant pixels has no effect on this frame. `waitScanline()` is `STA WSYNC`: it stops the CPU until the end of the current line, and the CPU resumes at the start of the next one. A function call, an array bounds check, or a garbage-collector pause would all be fatal. The data is not a `Uint8Array` in RAM: the 96-row diamond is 288 bytes of ROM, the 48-row diamond is 144, and the 128 bytes of RAM are shared with the stack. And the loop is not free — each row body has to fit in 76 CPU cycles, or the frame grows a line and the picture rolls.

:::

## Theory

### Section 1: The Kernel Is the Picture

The TIA has no memory of the picture. It has registers that describe what to draw *right now*: the playfield bytes, the two player graphics, the ball and missiles, and the colours. As the beam moves across a scanline, the TIA turns those registers into pixels. When the beam reaches the right edge, the line ends; the CPU gets a fresh 76 cycles and must set up the next line.

That is why a 2600 program is organised around the frame:

```
3 lines    VSYNC       tell the TV a new frame starts
37 lines   VBLANK      blank the beam; do the game logic
192 lines  picture     the kernel: write the registers for each line
30 lines   overscan    blank again; finish the frame's work
```

The four numbers add up to 262 lines, the NTSC frame. The kernel owns the 192 picture lines. It runs once per frame, at about 60 Hz, and it never stops to wait for the game logic: the logic must already have computed the values the kernel will write.

Two numbers set every kernel budget:

- **One scanline is 76 CPU cycles.** The line is 228 colour clocks, and one CPU cycle is three colour clocks. In the visible part you have about 53 cycles before the beam reaches the right edge; the rest is horizontal blanking.
- **A 1-line kernel writes one data byte per scanline.** A 2-line kernel writes one byte per *two* scanlines, so it has 152 cycles for the pair. That is the whole reason the 2-line kernel is the platform's default: it halves the data and doubles the time.

Vertical position comes from **when** you write. If you write `GRP0` during scanline 100, the player appears on scanline 100. There is no Y coordinate register. Horizontal position comes from **where** you strobe `RESP0`/`RESP1` and from the fine value in `HMP0`/`HMP1`, applied by `HMOVE`. The kernel decides the vertical order; the positioning dance decides the horizontal order.

The kernels in this lesson are **work-first**: each row writes its registers and then executes `STA WSYNC`. The store at the end of the row waits for the beam to finish the line, so the next row's stores begin at the start of the next line. The alternative — `WSYNC` first, then the stores — is used only when the first store must be timed against the beam; this lesson uses work-first everywhere and preloads the first visible row in VBLANK so the mode dispatch cannot clip it.

::: tip The scanline is the unit of trust
Every claim in this lesson is either a line number (verified with a Stella breakpoint), a cycle count (a static sum of the instructions in the row body), or a pixel measurement (from a screenshot of the committed ROM). A screenshot proves the picture; it never proves the timing. The state log proves the value and the line; it never proves that the diamond looks right. The lesson uses all three.
:::

### Section 2: The Kernel Taxonomy

Almost every 2600 kernel is one of five shapes, or a combination of them:

| Archetype | Data per screen | Budget | What it buys | What it costs | In this course |
|---|---|---|---|---|---|
| **1-line** | 192 bytes (one per line) | 76 cycles/line | maximum vertical detail | twice the data and twice the stores of a 2-line kernel | Lessons 48, 52 |
| **2-line** | 96 bytes (one per pair) | 152 cycles/pair | the cheapest full-screen kernel | vertical detail quantised to two lines | Lessons 49, 50 |
| **Multi-zone** | one table per zone | one budget per zone | a score, a status bar, a play area, a ground line | boundary code; objects may need repositioning | Lessons 48 (mode 3), 50 |
| **Repositioning** | reuse one object | about two lines per reset | many objects from two players | the `RESxx` + `HMPx` + `HMOVE` dance | Lessons 50, 53 |
| **Flicker** | two frames | two frame budgets | more objects than the TIA has | 30 Hz flicker; a still image shows one half | Lesson 51 |

The **1-line** kernel is the most detailed: one byte per scanline, so a sprite can change on every line. It is also the most expensive: 192 loads and stores, and the row body plus the loop overhead must fit in 76 cycles. The demo's 1-line row is 45 cycles (Section 3), which leaves 31.

The **2-line** kernel is the workhorse: one byte covers two scanlines, so 96 bytes cover the screen and the row body has 152 cycles to spend. The price is vertical chunkiness: a shape's edge can only move in two-line steps. The demo makes that visible by drawing the same diamond with both kernels in one frame.

A **multi-zone** kernel divides the 192 lines into bands, each with its own loop and its own colours. The bands are usually a score or status bar at the top, a play area in the middle, and a ground line or a second status band at the bottom. The boundary is where the kernel resets the playfield and object registers so the next zone does not inherit the previous zone's picture.

A **repositioning** kernel reuses the same player for several objects at different horizontal positions. The `SetHorizPos` dance costs about two lines per object: one `WSYNC`, a divide-by-15 loop, and a `RESxx` strobe, then one `HMOVE` applies every fine offset. The one-`HMOVE` rule from Lesson 28 matters here: set every coarse reset and every `HMPx` first, then strobe `HMOVE` once.

A **flicker** kernel draws more objects than the TIA has by alternating two 30 Hz frames. The eye merges them into four or six objects, but a photograph of one frame shows only half. Lesson 51 builds the two halves and proves which objects are in each with the state log.

### Section 3: The 1-Line/2-Line Trade-off

The demo's diamond is the trade-off made visible. The same shape is stored twice:

| | 1-line table | 2-line table |
|---|---|---|
| Rows | 96 | 48 |
| Bytes (3 planes) | 288 | 144 |
| Lines drawn | 96 | 96 |
| Row total | 45 cycles | 48 cycles per pair |
| Vertical detail | one scanline | two scanlines |
| Where it appears | mode 0 top; mode 1 | mode 0 bottom; mode 2 |

The 2-line table is not a different shape. It is the 1-line table sampled at rows 0, 2, 4, …, 94. Every second row is discarded, so the picture is the same 96 lines tall but its width can only change every two lines. The data is half as large, and the row body has twice as long to run.

The demo's kernel ledgers make the costs concrete. A row body is a list of load/store pairs plus the loop tail:

| Kernel | Row total | Total per row/pair |
|---|---|---|
| Split top (1-line, P0 + PF1 + PF2 + PF0) | 7 + 7 + 7 + 7 + 3 = 31 | 38 cycles (loop tail 7) |
| Split bottom (2-line, P1 + PF1 + PF2 + PF0) | 7 + 7 + 7 + 7 + 6 = 34 | 41 cycles per pair |
| Full 1-line (P0 + P1 + PF1 + PF2 + PF0) | 7 + 7 + 7 + 7 + 7 + 3 = 38 | 45 cycles |
| Full 2-line (the same body + one `WSYNC`) | 38 + 3 = 41 | 48 cycles per pair |

The 1-line budget is 76 cycles, so the nominal row (45) leaves 31; the page-aligned tables add at most one page cross (46), leaving 30. The 2-line budget is 152 cycles for the pair, so 48 leaves 104. The numbers explain why a full-screen game starts with the 2-line kernel: it is not a compromise forced by weak hardware, it is the shape that leaves room for the game.

::: tip Store order is part of the budget
The row body's stores are not interchangeable. In the full 1-line kernel the row begins at cycle 7 (the loop tail has just run). The P0/P1 stores finish at cycles 14 and 21; `PF1` finishes at 28; `PF2` at 35. The first lit playfield chunk (chunk 8) appears at about cycle 33.4, and the first lit `PF2` chunk (chunk 12) at about 38.7. Writing the sprites first and the playfield second is what makes the row fit the beam. `PF0` is written last because this centred diamond never lights chunks 0–3; a shape that used `PF0` would have to move that store to the front.
:::

### Section 4: The Kernel Zoo on Screen

The demo has three modes. Each one is a complete 192-line kernel; the mode byte selects which one runs in the visible area.

**Mode 0 — the split.** Visible lines 0–95 are a 1-line zone: 96 rows, one `WSYNC` per row. Visible lines 96–191 are a 2-line zone: 48 rows, two `WSYNC`s per row. The top diamond is green `$C8`; the bottom is gold `$1A`. P0 draws a one-line white dash at visible line 24; P1 draws a two-line dash at visible lines 168–169. The two dashes are the same 8-pixel sprite at the two vertical resolutions.

**Mode 1 — full 1-line.** 192 rows. The 96-row diamond table and the 96-byte P0/P1 strips are used twice, once for visible lines 0–95 and once for 96–191. The screen is two smooth green diamonds, each 96 lines tall.

**Mode 2 — full 2-line.** 96 rows. The 48-row diamond table and the 48-byte strips are used twice. The screen is two chunky gold diamonds, each 96 lines tall.

The controls are small on purpose. Fire cycles 0 → 1 → 2 → 0 and beeps. SELECT resets to mode 0 and beeps. The auto-demo advances the mode every 240 frames, so mode 2 is reachable without a key press (it is the 480–719 frame window). Joystick left/right moves both dashes one pixel per frame between TIA X=8 and X=144; with no input, the auto-demo sweeps them between the same limits.

The frame arithmetic is the one from Lesson 12:

```
3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
```

`StartFrame` is scanline 259 (the first VSYNC line), `VblankStart` is 0, `BodyStart` is 37 (visible line 0), and `OverscanStart` is 229 (the first blank line after the picture). The kernel writes the last visible line on scanline 228; the next `WSYNC` lands on 229.

The diamond data is generated, not hand-drawn. Each row is three playfield bytes: `PF0` for chunks 0–3, `PF1` for chunks 4–11, and `PF2` for chunks 12–19. `CTRLPF=$01` reflects the left half, so lighting chunks 8–19 draws a centred shape at most 96 pixels wide. The width follows a simple diamond rule: 2 chunks at the tips, 24 chunks at the middle, in even steps of two chunks. The 2-line table is the same list sampled every second row.

### Section 5: Five Kernels That Defined the Platform

The rest of this section is **historical context**. The demo does not reproduce these games, and none of the numbers below are claims about their exact code. The point is the design trade-off each game made — the same trade-offs this lesson's taxonomy names.

| Game | Year | Kernel idea | The trade-off it shows |
|---|---|---|---|
| **Combat** | 1977 | a 2-line playfield with two players and two missiles | two players and simple shapes, cheap enough for the pack-in |
| **Adventure** | 1979–80 | data-driven rooms and object records | ROM reuse instead of per-room code |
| **Pitfall!** | 1982 | a playfield jungle with a small animated player | a large world from a compact data set |
| **River Raid** | 1982 | a scrolling river drawn with the playfield | continuous motion from a narrow per-line window |
| **Cosmic Ark** | 1982 | a full-screen starfield from sprite positioning | atmosphere from almost no ROM |

**Combat** shipped with the console in 1977. It is the clearest early example of the 2-line playfield pattern: two tanks, two missiles, and a handful of walls, all drawn with one byte per two scanlines. The 2-line budget is what made two players and a playfield practical at 60 Hz.

**Adventure** (Warren Robinett, 1979–80) is the data-driven kernel. A room is not a block of code; it is an entry in a table, pointing at object records (position, graphic, behaviour). The kernel interprets the tables. That is why a 4K cartridge could hold a world of rooms, dragons, keys, and the first video-game easter egg.

**Pitfall!** (David Crane, Activision, 1982) puts the playfield and a small animated player together and generates a large world from a compact data scheme. The lesson's point is not the exact generator: it is that a 2600 game can spend its ROM on a *description* of a world instead of on a picture of every screen.

**River Raid** (Carol Shaw, Activision, 1982) scrolls a river drawn with the playfield. The river's width and the bridges change as the world scrolls; the scroll makes a narrow window feel like a long world. The playfield's 4-pixel chunks are the medium, and the scroll is the motion.

**Cosmic Ark** (Imagic, Rob Fulop, 1982) is the starfield. *Racing the Beam* documents it as an exploitation of a TIA sprite-positioning side effect: the stars are scattered by the positioning hardware rather than stored as a bitmap. The result is a full screen of stars from almost no ROM while the CPU runs the game. Lesson 54 builds a different starfield (three sparse playfield planes and a scroll); it is a convincing effect, not a bit-exact reproduction.

The common thread is that none of these kernels is a general-purpose renderer. Each one is a small, hand-counted routine shaped around one game's data. That is the lesson the rest of Part 7 teaches: choose the kernel for the picture, then count it.

## The Code

### Building This Lesson

```bash
# every lesson ROM, including this one:
npm run roms

# or just this one:
acme -f plain -o build/demo-48.bin \
  lessons/part7-kernel-mastery/48-introduction-to-kernels/demo-48.asm

stella build/demo-48.bin
```

The three exercise solutions sit beside the lesson source. Each is a complete 4,096-byte ROM:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part7-kernel-mastery/48-introduction-to-kernels/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part7-kernel-mastery/48-introduction-to-kernels/exercise-02-solution.asm
acme -f plain -o build/exercise-03.bin \
  lessons/part7-kernel-mastery/48-introduction-to-kernels/exercise-03-solution.asm
```

### Full Source

The complete annotated source is the lesson's reference copy. It is reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 48: Introduction to Kernels — The Kernel Zoo — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; What this program does:
;   "the kernel zoo": one picture drawn three ways, so the 1-line and 2-line
;   kernels can be compared side by side.  The picture is a diamond 96 lines
;   tall and at most 96 pixels wide, plus two 8-pixel dashes, one on each
;   player.  The diamond is data: three 96-byte planes for the 1-line kernel
;   and three 48-byte planes for the 2-line kernel.  The 2-line table is the
;   same shape sampled every second row of the 1-line table.
;
;   Mode 0 (the split):
;     visible 0-95    a 1-line zone: 96 rows, one scanline per row.  The
;                     diamond is smooth and green ($C8).  P0 draws a
;                     one-line white dash at visible line 24.
;     visible 96-191  a 2-line zone: 48 rows, two scanlines per row.  The
;                     same diamond is chunky and gold ($1A).  P1 draws a
;                     two-line white dash at visible lines 168-169.
;   Mode 1 (full 1-line): 192 rows.  The 96-row diamond and the 96-byte
;     P0/P1 strips are used twice, so the screen is two smooth green
;     diamonds, each 96 lines tall.
;   Mode 2 (full 2-line): 96 rows.  The 48-row diamond and the 48-byte
;     P0/P1 strips are used twice, so the screen is two chunky gold
;     diamonds, each 96 lines tall.
;
; Controls:
;   Fire cycles 0 -> 1 -> 2 -> 0 and beeps.  SELECT resets to mode 0 and
;   beeps.  The auto-demo advances the mode every 240 frames, so every mode
;   is reachable without a key press.  Joystick left/right moves both dashes
;   one pixel per frame, clamped to X=8..144; with no input the auto-demo
;   sweeps them between those limits.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame is scanline 259, VblankStart 0, BodyStart 37, OverscanStart
;   229.  The kernels are work-first: write the row's registers, then WSYNC.
;
; The kernel ledgers (cycles; a page-crossing indexed load adds 1):
;   1-line split top:    P0 7 + PF1 7 + PF2 7 + PF0 7 + WSYNC 3 + loop 7 = 38
;   2-line split bottom: P1 7 + PF1 7 + PF2 7 + PF0 7 + 2 WSYNC 6 + loop 7 = 41
;   1-line full:         P0 7 + P1 7 + PF1 7 + PF2 7 + PF0 7 + WSYNC 3 + loop 7 = 45
;   2-line full:         the 1-line full body (45) + one extra WSYNC (3) = 48
;   The 1-line budget is 76; the 2-line budget is 152 for the pair.  Even the
;   aligned tables add at most one page cross (45 + 1 = 46), leaving 30
;   cycles; the 2-line pair (48, page-contained) leaves 104.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), OverscanStart (229),
;   ModeRead (A = Mode, every frame), ModeStep (A = the new mode after fire
;   or the auto-demo), ZoneCountRead (A = ZoneCount), LineCountRead (A =
;   LineCount), PairCountRead (A = PairCount), LineRow / LineRow2 (Y =
;   0..95), PairRow / PairRow2 (Y = 0..47), HmoveApply (the WSYNC stall),
;   HmoveDone (the HMOVE store).  The full RAM map is below.
;
; Build: acme -f plain -o build/demo-48.bin \
;        lessons/part7-kernel-mastery/48-introduction-to-kernels/demo-48.asm
; Run:   stella build/demo-48.bin     (click the screen to unmute the beep)
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

LINE_ROWS      = 96      ; rows in the 1-line diamond
PAIR_ROWS      = 48      ; rows in the 2-line diamond
MODE_COUNT     = 3       ; modes 0, 1, 2
DEMO_PERIOD    = 240     ; frames per mode in the auto-demo
DASH_MIN       = 8       ; the dash's left limit (TIA X)
DASH_MAX       = 144     ; the dash's right limit (TIA X)
DASH_START     = 72      ; the dash's power-on X

BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright beep

C_GREEN        = $C8     ; the 1-line zones
C_GOLD         = $1A     ; the 2-line zones
C_WHITE        = $0E     ; both dashes
C_BG           = $02     ; the background

; =============================================================================
; RAM ALLOCATION ($80-$8E; +clean_start zeroes every byte)
; =============================================================================
Mode         = $80   ; 0 = split, 1 = full 1-line, 2 = full 2-line
DemoTimer    = $81   ; frames left before the auto-demo advances the mode
DashX        = $82   ; both dashes' left edge, 8..144
DashDir      = $83   ; the auto-demo's sweep direction: 0 = left, 1 = right
PrevFire     = $84   ; fire state last frame (1 = pressed)
PrevSelect   = $85   ; SELECT state last frame (1 = pressed)
BeepTimer    = $86   ; frames of beep remaining
BeepPitch    = $87   ; AUDF for the beep
ZoneCount    = $88   ; 2 in the split, 1 in the full modes (the checkpoint)
LineCount    = $89   ; 96 in the split, 192 in the full 1-line mode
PairCount    = $8A   ; 48 in the split, 96 in the full 2-line mode
Pass         = $8B   ; 0/1: which copy of the table the full modes draw
Scratch      = $8C   ; SELECT's pressed state, then general scratch
NewFire      = $8D   ; this frame's fire 0 -> 1 edge
Startup      = $8E   ; frames left before the fire edge is trusted
;
; $8F-$F7 are free (105 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (JSR SetCoarseP0 / SetCoarseP1 / AdvanceMode / BeepStart).

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

    LDA #$00
    STA Mode                ; power on in the split view
    LDA #DEMO_PERIOD
    STA DemoTimer
    LDA #DASH_START
    STA DashX
    LDA #$01
    STA DashDir             ; sweep right first
    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #$08
    STA Startup             ; ignore the fire line while the console settles

    LDA #C_BG
    STA COLUBK              ; the background is $02
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the right half mirrors the left
    LDA #C_WHITE
    STA COLUP0              ; both dashes are white
    STA COLUP1
    LDA #C_GREEN
    STA COLUPF              ; the first frame is mode 0's green top zone
    LDA #$00
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
; 1. THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
; BeepTimer counts down every frame and silences channel 0 at zero.  The
; sound itself is not the lesson's subject; it is the same two-byte beep the
; rest of Part 6 and Part 7 uses.
    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0               ; silence at the end of the tick
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — cycle the mode on the 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1, and the
; EOR/AND pair keeps only a new press, so holding the button advances once.
    LDA INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire             ; NewFire = pressed & ~wasPressed

; The first frames after power-on are not trusted: INPT4 can read low while
; the console settles.  Startup counts eight frames; until it reaches zero
; the edge is forced clear.
    LDA Startup
    BEQ FireEdgeReady
    DEC Startup
    LDA #$00
    STA NewFire
FireEdgeReady:
    LDA NewFire
    BEQ NoFireEdge
    JSR AdvanceMode
    LDA #DEMO_PERIOD        ; a manual change restarts the auto-demo window
    STA DemoTimer
    JSR BeepStart
NoFireEdge:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; -----------------------------------------------------------------------------
; 3. SELECT — reset to mode 0
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  The edge, not the level, resets the
; zoo.  SELECT is also the screenshot helper: a capture can start from mode 0
; without waiting for the auto-demo.
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelectEdge
    LDA #$00
SelectReset:                ; checkpoint: A = 0, the new mode
    STA Mode
    LDA #DEMO_PERIOD
    STA DemoTimer
    JSR BeepStart
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 4. THE AUTO-DEMO'S MODE CLOCK — one mode every 240 frames
; -----------------------------------------------------------------------------
; The auto-demo is what makes both screenshots reachable without a key press:
; mode 0 is the first 240 frames, mode 1 the next 240, mode 2 the next 240.
    DEC DemoTimer
    BNE NoAutoMode
    JSR AdvanceMode
    LDA #DEMO_PERIOD
    STA DemoTimer
NoAutoMode:

; -----------------------------------------------------------------------------
; 5. THE DASHES — joystick left/right, or the auto-demo's sweep
; -----------------------------------------------------------------------------
; SWCHA's P0 direction bits are active low.  The raw masks are $40 (left)
; and $80 (right); after AND #$C0, a left press reads $80 and a right press
; reads $40 (the other bit stays high).  $C0 is neither; $00 (both) is ignored.
; The clamp keeps the 8-pixel dash inside TIA X 8..144.
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ AutoDash
    CMP #$80
    BEQ DashLeft
    CMP #$40
    BEQ DashRight
    JMP AutoDash
DashLeft:
    LDA DashX
    CMP #DASH_MIN
    BEQ DashDone
    DEC DashX
    JMP DashDone
DashRight:
    LDA DashX
    CMP #DASH_MAX
    BEQ DashDone
    INC DashX
    JMP DashDone
AutoDash:
    LDA DashDir
    BNE AutoDashRight
    LDA DashX
    CMP #DASH_MIN
    BEQ AutoDashFlip
    DEC DashX
    JMP DashDone
AutoDashRight:
    LDA DashX
    CMP #DASH_MAX
    BEQ AutoDashFlip
    INC DashX
    JMP DashDone
AutoDashFlip:
    LDA DashDir
    EOR #$01
    STA DashDir
DashDone:

; -----------------------------------------------------------------------------
; 6. THE MODE'S COUNTERS — three bytes from one table
; -----------------------------------------------------------------------------
; ModeStates holds three bytes per mode: ZoneCount, LineCount, PairCount.
; The state log reads the three labels below; each reports A before its
; store, so the value is visible without watching RAM.
    LDA Mode
ModeRead:                   ; checkpoint: A = Mode
    ASL
    CLC
    ADC Mode                ; A = 3 * Mode
    TAX
    LDA ModeStates,X
ZoneCountRead:              ; checkpoint: A = ZoneCount
    STA ZoneCount
    LDA ModeStates+1,X
LineCountRead:              ; checkpoint: A = LineCount
    STA LineCount
    LDA ModeStates+2,X
PairCountRead:              ; checkpoint: A = PairCount
    STA PairCount

; -----------------------------------------------------------------------------
; 7. THE PLAYFIELD COLOUR — green for modes 0/1, gold for mode 2
; -----------------------------------------------------------------------------
; Mode 0 changes to gold again at the zone boundary, inside the kernel.
    LDA Mode
    CMP #$02
    BEQ ModeColorGold
    LDA #C_GREEN
    JMP ModeColorStore
ModeColorGold:
    LDA #C_GOLD
ModeColorStore:
    STA COLUPF

; -----------------------------------------------------------------------------
; 8. THE FIRST VISIBLE ROW'S PLAYFIELD — written before the picture turns on
; -----------------------------------------------------------------------------
; Every mode's first row is the diamond's top tip: PF0=0, PF1=0, PF2=$80
; (chunks 19-20, TIA X=76-83).  Writing it here means the mode dispatch and
; the first row's late stores cannot clip the tip: they write the same byte.
    LDA #$00
    STA PF0
    STA PF1
    LDA #$80
    STA PF2

; -----------------------------------------------------------------------------
; 9. POSITION BOTH PLAYERS, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; Every coarse RESxx and every HMxx is set first; one WSYNC and one HMOVE
; apply both fine offsets in the same HBLANK (the one-HMOVE rule from
; Lesson 28).  The HMOVE blanks the left 8 pixels of the next line, which is
; still inside VBLANK, so the visible picture is unaffected.
    LDA DashX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA DashX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed (next line)

; -----------------------------------------------------------------------------
; 10. A CLEAN FIRST LINE
; -----------------------------------------------------------------------------
; The playfield was preloaded above; clear the two player graphics so the
; first row's dash slots are empty.  The dash rows are 24 and 36, far below
; the first row, so an empty GRP at the top is always correct.
    LDA #$00
    STA GRP0
    STA GRP1

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- the mode dispatch -----------------------------------------------------
; The branch chain costs 6-12 cycles, which is why the first row's playfield
; was preloaded in VBLANK.  Every target is a kernel with its own row loop.
    LDA Mode
    BEQ SplitKernel
    CMP #$01
    BEQ FullOneLineKernel
    JMP FullTwoLineKernel

; -----------------------------------------------------------------------------
; MODE 0 — THE SPLIT: 96 one-line rows, then 48 two-line rows
; -----------------------------------------------------------------------------
SplitKernel:
    LDY #0
SplitTopRow:
LineRow:                    ; checkpoint: Y = 0..95, the visible row
    LDA P0Strip1,Y          ; P0's one-byte-tall dash (row 24)
    STA GRP0
    LDA Diamond1PF1,Y       ; the diamond, one byte per scanline
    STA PF1
    LDA Diamond1PF2,Y
    STA PF2
    LDA Diamond1PF0,Y       ; $00 for this centred shape; written last
    STA PF0
    STA WSYNC               ; work-first: the row is complete, then wait
    INY
    CPY #LINE_ROWS
    BNE SplitTopRow
; 96 rows x 1 line = visible 0-95.  The CPU is now at the start of line 133.

; --- the zone boundary: visible 96 ------------------------------------------
; The colour changes to gold here, at the start of the 2-line zone.  The
; first 2-line row's top tip is preloaded ($00/$00/$80) for the same reason
; the frame's first row was: the zone setup costs a few cycles.
    LDA #$00
    STA GRP0                ; P0 is not used in the bottom zone
    LDA #C_GOLD
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF1
    LDA #$80
    STA PF2

    LDY #0
SplitBottomRow:
PairRow:                    ; checkpoint: Y = 0..47, the 2-line row
    LDA P1Strip2,Y          ; P1's two-line dash (row 36 = visible 168-169)
    STA GRP1
    LDA Diamond2PF1,Y       ; the same diamond, one byte per two scanlines
    STA PF1
    LDA Diamond2PF2,Y
    STA PF2
    LDA Diamond2PF0,Y
    STA PF0
    STA WSYNC               ; line 1 of the pair
    STA WSYNC               ; line 2 of the pair
    INY
    CPY #PAIR_ROWS
    BNE SplitBottomRow
    JMP KernelDone
; 48 rows x 2 lines = visible 96-191.

; -----------------------------------------------------------------------------
; MODE 1 — FULL 1-LINE: the 96-row table twice
; -----------------------------------------------------------------------------
FullOneLineKernel:
    LDA #$00
    STA Pass
    LDY #0
Full1Row:
LineRow2:                   ; checkpoint: Y = 0..95, then 0..95 again
    LDA P0Strip1,Y
    STA GRP0
    LDA P1Strip1,Y          ; P1's one-line dash (row 72)
    STA GRP1
    LDA Diamond1PF1,Y
    STA PF1
    LDA Diamond1PF2,Y
    STA PF2
    LDA Diamond1PF0,Y
    STA PF0
    STA WSYNC
    INY
    CPY #LINE_ROWS
    BNE Full1Row
    INC Pass
    LDA Pass
    CMP #$02
    BEQ KernelDone
    LDY #0
    JMP Full1Row
; 2 passes x 96 rows x 1 line = 192 lines.

; -----------------------------------------------------------------------------
; MODE 2 — FULL 2-LINE: the 48-row table twice
; -----------------------------------------------------------------------------
FullTwoLineKernel:
    LDA #$00
    STA Pass
    LDY #0
Full2Row:
PairRow2:                   ; checkpoint: Y = 0..47, then 0..47 again
    LDA P0Strip2,Y
    STA GRP0
    LDA P1Strip2,Y
    STA GRP1
    LDA Diamond2PF1,Y
    STA PF1
    LDA Diamond2PF2,Y
    STA PF2
    LDA Diamond2PF0,Y
    STA PF0
    STA WSYNC
    STA WSYNC
    INY
    CPY #PAIR_ROWS
    BNE Full2Row
    INC Pass
    LDA Pass
    CMP #$02
    BEQ KernelDone
    LDY #0
    JMP Full2Row
; 2 passes x 48 rows x 2 lines = 192 lines.

KernelDone:

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
; AdvanceMode — the next mode, wrapping 2 -> 0
; =============================================================================
; A is the new mode when the routine returns.  ModeStep is after the store,
; so a breakpoint there reports the value the rest of the frame will use.
; Fire calls this and then BeepStart; the auto-demo calls it silently.
AdvanceMode:
    LDA Mode
    CLC
    ADC #$01
    CMP #MODE_COUNT
    BCC AdvanceStore
    LDA #$00
AdvanceStore:
    STA Mode
ModeStep:                   ; checkpoint: A = the new mode
    RTS

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
; THE MODE TABLE — three bytes per mode
; =============================================================================
; ModeStates[3*Mode + 0] = ZoneCount
; ModeStates[3*Mode + 1] = LineCount
; ModeStates[3*Mode + 2] = PairCount
ModeStates:
    !byte 2, 96, 48         ; mode 0: two zones, 96 one-line rows, 48 pairs
    !byte 1, 192, 0         ; mode 1: one zone, 192 one-line rows, no pairs
    !byte 1, 0, 96          ; mode 2: one zone, no one-line rows, 96 pairs

; =============================================================================
; THE DIAMOND DATA
; =============================================================================
; The shape is generated as data, not by the kernel.  Each row is three
; playfield bytes: PF0 (chunks 0-3), PF1 (chunks 4-11) and PF2 (chunks
; 12-19).  CTRLPF=$01 reflects the left half, so lighting chunks 8-19 draws
; a centred 96-pixel-wide diamond at its widest.  PF0 stays $00 for this
; centred shape (nothing below chunk 8 is lit), but the plane is kept so the
; table really is 96 rows x 3 bytes = 288 bytes.
;
; The 2-line table is the 1-line table sampled at rows 0, 2, 4, ..., 94.
; That is the whole trade-off in one sentence: the same picture, half the
; data and half the vertical detail.
    !align 255, 0
Diamond1PF0:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

Diamond1PF1:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $01, $01, $01, $01, $03, $03, $03, $03, $07, $07, $07, $07, $0F
    !byte $0F, $07, $07, $07, $07, $03, $03, $03, $03, $01, $01, $01, $01, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

Diamond1PF2:
    !byte $80, $80, $80, $80, $80, $C0, $C0, $C0, $C0, $E0, $E0, $E0, $E0, $F0, $F0, $F0
    !byte $F0, $F0, $F8, $F8, $F8, $F8, $FC, $FC, $FC, $FC, $FE, $FE, $FE, $FE, $FF, $FF
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    !byte $FF, $FF, $FE, $FE, $FE, $FE, $FC, $FC, $FC, $FC, $F8, $F8, $F8, $F8, $F0, $F0
    !byte $F0, $F0, $F0, $E0, $E0, $E0, $E0, $C0, $C0, $C0, $C0, $80, $80, $80, $80, $80

; ---------- main demo: 48-row diamond (2-line, sampled every 2 rows) ----------
Diamond2PF0:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

Diamond2PF1:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $01, $01, $03, $03, $07, $07, $0F, $07, $07, $03, $03, $01, $01, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

Diamond2PF2:
    !byte $80, $80, $80, $C0, $C0, $E0, $E0, $F0, $F0, $F8, $F8, $FC, $FC, $FE, $FE, $FF
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    !byte $FF, $FE, $FE, $FC, $FC, $F8, $F8, $F0, $F0, $F0, $E0, $E0, $C0, $C0, $80, $80

; --- the player strips: one byte per line (1-line) or per two lines (2-line)
; The dash is a solid 8-pixel byte ($FF).  P0's one-line dash is at row 24;
; P1's one-line dash is at row 72.  In the 2-line strips P0's dash is at row
; 24 and P1's at row 36.  Each strip is mostly $00; !fill builds the gaps.
; P0Strip1 and P0Strip2 are page-aligned; the 1-line pair and the 2-line pair
; each sit inside one page, so only the Diamond1PF2 plane can cross.
    !align 255, 0
P0Strip1:
    !fill 24, $00
    !byte $FF
    !fill 71, $00
P1Strip1:
    !fill 72, $00
    !byte $FF
    !fill 23, $00
    !align 255, 0
P0Strip2:
    !fill 24, $00
    !byte $FF
    !fill 23, $00
P1Strip2:
    !fill 36, $00
    !byte $FF
    !fill 11, $00

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
> `lessons/part7-kernel-mastery/48-introduction-to-kernels/demo-48.asm`.

### Code Walkthrough

#### Step 1 — The frame skeleton and the mode dispatch

The frame is the Part 2–6 skeleton with one new idea: the visible area is a **dispatch**. `BodyStart` reads `Mode` and jumps to one of three kernels:

```asm
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDA Mode
    BEQ SplitKernel
    CMP #$01
    BEQ FullOneLineKernel
    JMP FullTwoLineKernel
```

The branch chain costs 6 cycles for mode 0, 10 for mode 1, and 12 for mode 2 (the `JMP`). That is why the first row's playfield is preloaded in VBLANK: the dispatch and the first row's stores can land a few cycles into the line, and the preload guarantees the top tip is already correct. The first row's later stores write the same bytes, so a late store cannot change the picture.

Each kernel ends at `KernelDone`, which falls into `OverscanStart`:

```asm
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame
```

The 30-line overscan and the 3-line VSYNC close the 262-line frame.

#### Step 2 — Reset and the RAM map

`Reset` calls `+clean_start`, makes port A an input port, and seeds the state:

```asm
    LDA #$00
    STA Mode                ; power on in the split view
    LDA #DEMO_PERIOD
    STA DemoTimer
    LDA #DASH_START
    STA DashX
    LDA #$01
    STA DashDir             ; sweep right first
```

The RAM map is fifteen bytes, `$80–$8E`; `$8F–$F7` is free. `Mode` is `$80`, `DemoTimer` `$81`, `DashX` `$82`, `DashDir` `$83`, the input edges `$84–$85`, the beep `$86–$87`, the three counters `$88–$8A`, `Pass` `$8B`, scratch `$8C`, the fire edge `$8D`, and `Startup` `$8E`. The stack lives at `$F8–$FF`, so the call depth stays shallow: `SetCoarseP0`, `SetCoarseP1`, `AdvanceMode`, and `BeepStart` are the only subroutines.

The TIA state is set once: `CTRLPF=$01` reflects the playfield, `COLUBK=$02`, `COLUP0/COLUP1=$0E` (white dashes), `NUSIZ0/NUSIZ1=0` (one 8-pixel copy each), and the graphics and playfield registers are cleared. `COLUPF` is set every frame from the mode.

#### Step 3 — VBLANK: the beep, the inputs, and the auto-demo

VBLANK does five jobs in order: the beep clock, fire, SELECT, the auto-demo clock, and the dash sweep.

The beep is the Part 6 two-byte tick:

```asm
    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0
BeepClockDone:
```

Fire and SELECT use the edge detector from Lesson 46: `INPT4` bit 7 is 0 while fire is held, so the first `EOR` turns a press into a 1, and the `EOR`/`AND` pair keeps only the 0→1 transition. `Startup` counts eight frames and forces the edge clear while the console settles, so a held button at power-on does not advance the mode.

Fire calls `AdvanceMode` and then `BeepStart`; SELECT stores 0, reloads the timer, and beeps. The auto-demo calls the same `AdvanceMode` silently:

```asm
    DEC DemoTimer
    BNE NoAutoMode
    JSR AdvanceMode
    LDA #DEMO_PERIOD
    STA DemoTimer
NoAutoMode:
```

`AdvanceMode` is the single place that advances the mode; SELECT resets it directly at
`SelectReset`:

```asm
AdvanceMode:
    LDA Mode
    CLC
    ADC #$01
    CMP #MODE_COUNT
    BCC AdvanceStore
    LDA #$00
AdvanceStore:
    STA Mode
ModeStep:                   ; checkpoint: A = the new mode
    RTS
```

A breakpoint at `ModeStep` reports the new mode. The auto-demo produces `A=$01` at frame 240 and `A=$02` at frame 480. Fire calls the same `AdvanceMode` routine; a manual fire press was not exercised in the state log.

The dash sweep reads `SWCHA` bits 6 and 7 (P0 left and right, active low). The raw masks are `$40` (left) and `$80` (right); after `AND #$C0`, a left press reads `$80` and a right press reads `$40` because the other bit stays high. `$C0` means neither; `$00` (both) is ignored. The code maps `$80` to `DashLeft` (DEC) and `$40` to `DashRight` (INC). The clamp is `DashX` 8..144. With no input, `DashDir` walks the dash between the limits and flips at each end.

#### Step 4 — The counters, the colours, and the first row

The three counters come from one table:

```asm
    LDA Mode
ModeRead:                   ; checkpoint: A = Mode
    ASL
    CLC
    ADC Mode                ; A = 3 * Mode
    TAX
    LDA ModeStates,X
ZoneCountRead:              ; checkpoint: A = ZoneCount
    STA ZoneCount
    LDA ModeStates+1,X
LineCountRead:              ; checkpoint: A = LineCount
    STA LineCount
    LDA ModeStates+2,X
PairCountRead:              ; checkpoint: A = PairCount
    STA PairCount
```

The table has three bytes per mode:

```asm
ModeStates:
    !byte 2, 96, 48         ; mode 0: two zones, 96 one-line rows, 48 pairs
    !byte 1, 192, 0         ; mode 1: one zone, 192 one-line rows, no pairs
    !byte 1, 0, 96          ; mode 2: one zone, no one-line rows, 96 pairs
```

The colours follow the mode: green for modes 0 and 1, gold for mode 2. The first visible row's playfield is written before the picture turns on. Every mode's first row is the diamond's top tip, `PF0=$00`, `PF1=$00`, `PF2=$80` (chunks 19–20, TIA X=76–83). The preload is what lets the mode dispatch run late without clipping the tip.

#### Step 5 — Position both players with one HMOVE

The two dashes share one X. The Lesson 26 dance sets each coarse position and fine value, then one `HMOVE` applies both:

```asm
    LDA DashX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA DashX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed (next line)
```

`SetCoarseP0`/`SetCoarseP1` are the divide-by-15 routines from Lesson 26. Each starts with a `WSYNC`, subtracts 15 until the remainder is negative, turns the remainder into the `HMPx` nibble, and strobes the matching `RESxx`. The final `WSYNC` before `HMOVE` puts the strobe at the start of the next line, inside HBLANK. The HMOVE's left-edge blanking happens during VBLANK, so it is invisible.

#### Step 6 — The split kernel: 96 one-line rows, then 48 two-line rows

The split kernel is the lesson's centrepiece. The top zone is a 1-line loop:

```asm
SplitKernel:
    LDY #0
SplitTopRow:
LineRow:                    ; checkpoint: Y = 0..95, the visible row
    LDA P0Strip1,Y          ; P0's one-byte-tall dash (row 24)
    STA GRP0
    LDA Diamond1PF1,Y       ; the diamond, one byte per scanline
    STA PF1
    LDA Diamond1PF2,Y
    STA PF2
    LDA Diamond1PF0,Y       ; $00 for this centred shape; written last
    STA PF0
    STA WSYNC
    INY
    CPY #LINE_ROWS
    BNE SplitTopRow
```

The loop is the top-down form from the course conventions: `LDY #0`, draw row 0, then `INY`/`CPY #96`/`BNE` until Y reaches 96. Y is both the row counter and the table index, so row 0 is the top of the screen and row 95 is the bottom. The row body is work-first: the stores complete, then `STA WSYNC` waits for the beam to finish the line.

At visible line 96 the zone changes:

```asm
    LDA #$00
    STA GRP0                ; P0 is not used in the bottom zone
    LDA #C_GOLD
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF1
    LDA #$80
    STA PF2
```

The colour change is at the start of line 133 (visible 96), so the last green line is 95 and the first gold line is 96. The bottom zone is a 2-line loop:

```asm
    LDY #0
SplitBottomRow:
PairRow:                    ; checkpoint: Y = 0..47, the 2-line row
    LDA P1Strip2,Y          ; P1's two-line dash (row 36 = visible 168-169)
    STA GRP1
    LDA Diamond2PF1,Y
    STA PF1
    LDA Diamond2PF2,Y
    STA PF2
    LDA Diamond2PF0,Y
    STA PF0
    STA WSYNC               ; line 1 of the pair
    STA WSYNC               ; line 2 of the pair
    INY
    CPY #PAIR_ROWS
    BNE SplitBottomRow
    JMP KernelDone
```

The two `WSYNC`s are the 2-line kernel: the first row's bytes are displayed on two scanlines. The loop draws 48 pairs = 96 lines, so the split is 96 + 96 = 192.

#### Step 7 — The full modes: the same table twice

Mode 1 uses the 96-row table and both 96-byte strips twice:

```asm
FullOneLineKernel:
    LDA #$00
    STA Pass
    LDY #0
Full1Row:
LineRow2:                   ; checkpoint: Y = 0..95, then 0..95 again
    LDA P0Strip1,Y
    STA GRP0
    LDA P1Strip1,Y          ; P1's one-line dash (row 72)
    STA GRP1
    LDA Diamond1PF1,Y
    STA PF1
    LDA Diamond1PF2,Y
    STA PF2
    LDA Diamond1PF0,Y
    STA PF0
    STA WSYNC
    INY
    CPY #LINE_ROWS
    BNE Full1Row
    INC Pass
    LDA Pass
    CMP #$02
    BEQ KernelDone
    LDY #0
    JMP Full1Row
```

The second pass starts at visible line 96. The pass boundary row is a tip (`$00/$00/$80`), the same bytes as the previous pass's last row, so the few extra cycles of the pass reset cannot clip the tip.

Mode 2 is the same structure with the 48-row table and the 48-byte strips:

```asm
FullTwoLineKernel:
    LDA #$00
    STA Pass
    LDY #0
Full2Row:
PairRow2:                   ; checkpoint: Y = 0..47, then 0..47 again
    LDA P0Strip2,Y
    STA GRP0
    LDA P1Strip2,Y
    STA GRP1
    LDA Diamond2PF1,Y
    STA PF1
    LDA Diamond2PF2,Y
    STA PF2
    LDA Diamond2PF0,Y
    STA PF0
    STA WSYNC
    STA WSYNC
    INY
    CPY #PAIR_ROWS
    BNE Full2Row
    INC Pass
    LDA Pass
    CMP #$02
    BEQ KernelDone
    LDY #0
    JMP Full2Row
```

Two passes of 48 rows × 2 lines = 192 lines.

#### Step 8 — The diamond data

The diamond tables are data, not code. Three 96-byte planes hold the 1-line shape; three 48-byte planes hold the sampled 2-line shape. The widths are generated by a simple rule: 2 chunks at the tips, 24 chunks at the middle, in even steps:

```
row  0:  8 px wide   (chunks 19-20)
row 24: 48 px wide   (chunks 14-25)
row 47: 96 px wide   (chunks  8-31)
row 48: 96 px wide
row 95:  8 px wide
```

`PF0` is `$00` on every row because the centred shape never reaches chunks 0–3. The plane is still present, so the table really is 96 rows × 3 bytes = 288 bytes, and a wider or off-centre shape would use it. The 2-line table is the same rows at 0, 2, 4, …, 94, so its 48 rows are 144 bytes. That is the whole 1-line/2-line trade-off in two numbers.

The player strips are one byte per line (or per pair). Most of each strip is `$00`; `!fill` builds the gaps and a single `$FF` places the 8-pixel dash:

```asm
P0Strip1:
    !fill 24, $00
    !byte $FF
    !fill 71, $00
```

#### Step 9 — The cycle ledger

The static ledger sums the loads, stores, `WSYNC`s, and loop tail:

| Path | Loads/stores | `WSYNC` | Loop tail | Total |
|---|---|---|---|---|
| Split top (1-line) | P0 7 + PF1 7 + PF2 7 + PF0 7 = 28 | 3 | 7 | **38** |
| Split bottom (2-line) | P1 7 + PF1 7 + PF2 7 + PF0 7 = 28 | 6 | 7 | **41** per pair |
| Full 1-line | P0 7 + P1 7 + PF1 7 + PF2 7 + PF0 7 = 35 | 3 | 7 | **45** |
| Full 2-line | 35 | 6 | 7 | **48** per pair |

The 1-line budget is 76 cycles per scanline; the 2-line budget is 152 per pair. The worst 1-line row (45 + one page cross = 46) leaves 30 cycles; the 2-line pair (48, page-contained) leaves 104. The margin is what lets the kernel run at all: the `WSYNC` absorbs the rest of the line, and the loop tail is already counted in the total.

#### Step 10 — Reading it back in Stella

Assemble with a symbol file and ask Stella for the checkpoints:

```bash
acme -f plain -l build/demo-48.sym -o build/demo-48.bin \
  lessons/part7-kernel-mastery/48-introduction-to-kernels/demo-48.asm

stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -logtoconsole 1 \
  -break '$F053' -break '$F061' -break '$F16B' -break '$F22F' \
  docs/public/roms/part7-kernel-mastery/48-introduction-to-kernels/demo-48.bin
```

The symbol file resolves the labels; the addresses change when the source changes, so read the current `.sym` file. The state log in the next section quotes the values. A breakpoint at `LineRow` fires once per 1-line row with Y=0..95; a breakpoint at `PairRow` fires once per 2-line row with Y=0..47. `LineRow2` and `PairRow2` are the labels inside the two-pass loops of modes 1 and 2; they fire on both passes.

### Checkpoints

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F053` | frame 1, **259/3** | the first VSYNC line |
| `VblankStart` | `$F061` | **0/5** | the first VBLANK line |
| `BodyStart` | `$F16B` | **37/5** | visible line 0 |
| `OverscanStart` | `$F22F` | **229/9** | the first blank line after the picture |
| `HmoveApply` | `$F156` | line 4, cycle 53 | the `WSYNC` write; the CPU waits to the end of line 4, then `HMOVE` stores at 5/0 |
| `HmoveDone` | `$F15A` | line 5, cycle 3 | the `HMOVE` store, once per frame |
| `ModeRead` | `$F119` | A = `Mode` | the mode in VBLANK |
| `ModeStep` | `$F24F` | A = 1 at frame 240; A = 2 at frame 480 | the new mode after fire or the auto-demo |
| `ZoneCountRead` | `$F121` | A = 2 (mode 0); 1 (modes 1/2) | the zone count |
| `LineCountRead` | `$F126` | A = `$60`/`$C0`/`$00` | 96 / 192 / 0 one-line rows |
| `PairCountRead` | `$F12B` | A = `$30`/`$00`/`$60` | 48 / 0 / 96 two-line rows |
| `LineRow` | `$F178` | Y = 0..95 | the split's 1-line row counter |
| `LineRow2` | `$F1CD` | Y = 0..95, twice | the full 1-line row counter |
| `PairRow` | `$F1A7` | Y = 0..47 | the split's 2-line row counter |
| `PairRow2` | `$F200` | Y = 0..47, twice | the full 2-line row counter |
| `SelectReset` | `$F0B5` | A = 0 | SELECT's new mode |

`OverscanStart` is scanline 229 in every mode. The cycle at the label (9 in the split path) is the loop tail plus the `JMP` to `KernelDone`; the scanline is the frame fact, and it stays 229. The same pattern appears in the full modes with a longer pass-boundary tail.

## What You Should See

The split view is a `$02` field with two diamonds stacked tip to tip. The top diamond is green `$C8`; its edges move in one-line steps and its maximum width is 96 TIA pixels. The bottom diamond is gold `$1A`; it is the same shape sampled every two lines, so its edges move in two-line steps. A white 8-pixel dash sits on the green diamond at visible line 24; a second white dash sits on the gold diamond at visible lines 168–169 and is twice as tall. The zone boundary is exactly at visible line 96.

![Stella running the Lesson 48 ROM in mode 0: a smooth green diamond in the top half, a chunky gold diamond in the bottom half, a one-line white dash at visible line 24, and a two-line white dash at visible lines 168-169](/images/lesson48/split.png)

*Mode 0, the split: the same 96-line diamond drawn by a 1-line kernel on top and a 2-line kernel below. The top dash is one scanline tall; the bottom dash is two. The image is a window capture of the committed ROM; the title bar reads `Stella 7.0: "demo-48"`.*

<RomPlayer rom="/roms/part7-kernel-mastery/48-introduction-to-kernels/demo-48.bin" title="Lesson 48 — Introduction to Kernels" />

Click the player screen once: Javatari starts muted until a user gesture. The ROM runs the 240-frame mode cycle without input, so the picture changes by itself. Press fire to advance one mode; press SELECT to return to mode 0. The joystick moves both dashes (left moves them left, right moves them right); with no input
the auto-demo sweeps them.

The full 2-line view is the whole screen in gold. Both the 96-line diamonds are drawn from the 48-row table, so every edge is a two-line step; the two P0 dashes (visible lines 48–49 and 144–145) and the two P1 dashes (72–73 and 168–169) are all two lines tall. Comparing this image with the split is the lesson in one glance: the same picture, half the data, half the vertical detail.

![Stella running the Lesson 48 ROM in mode 2: the whole screen is the chunky gold diamond drawn two scanlines at a time, with four two-line white dashes](/images/lesson48/full-two-line.png)

*Mode 2, the full 2-line view: two chunky gold diamonds and four two-line dashes. The image is a window capture of the committed ROM; the title bar reads `Stella 7.0: "demo-48"`.*

> **Capture method.** Both images are window captures of
> `docs/public/roms/part7-kernel-mastery/48-introduction-to-kernels/demo-48.bin` in Stella 7.0. The
> pointer was parked outside the window before each capture; the title bars read
> `Stella 7.0: "demo-48"`. Because the mode changes every 240 frames, a single fixed-wait capture
> cannot be aimed at mode 0 or mode 2. Stella was launched on the committed ROM, a burst of window
> captures was taken with the same `xwininfo` lookup the screenshot script uses, and the frames were
> selected by pixel analysis: mode 0 when the top half is green and the bottom half gold, mode 2
> when both halves are gold. The diamond widths, the dash heights, and the colours are decoded from
> the captured pixels with `capture x = 25 + 6 × TIA X` and `capture y = 107 + 3.15 × visible line`,
> not copied from a log.

The debugger tells the same story as numbers:

- **`$F053` (`StartFrame`)** is **259/3** and **`$F061` (`VblankStart`)** is **0/5**: the VSYNC and VBLANK boundaries of the 262-line frame.
- **`$F16B` (`BodyStart`)** is **37/5**: visible line 0. **`$F22F` (`OverscanStart`)** is **229/9**: the first blank line after the picture; the cycle is the loop tail, the scanline is the frame fact.
- **`$F156` (`HmoveApply`)** is line 4 cycle 53 (the `WSYNC` write; the CPU waits to the end of line 4) and **`$F15A` (`HmoveDone`)** is line 5 cycle 3 (after the `HMOVE` store at 5/0): one `HMOVE` per frame, applied in HBLANK.
- **`$F24F` (`ModeStep`)** reports A=`$01` at frame 240 and A=`$02` at frame 480. The same routine is called by fire; the auto-demo is the runnable proof of the mode cycle.
- **`$F121` (`ZoneCountRead`)** reports A=`$02` in mode 0. **`$F126` (`LineCountRead`)** reports `$60` (96), `$C0` (192), `$00` as the mode changes; **`$F12B` (`PairCountRead`)** reports `$30` (48), `$00`, `$60` (96).
- **`$F178` (`LineRow`)** fires at line 37 with Y=`$00`, line 38 with Y=`$01`, and ends at line 132 with Y=`$5F` (95). **`$F1A7` (`PairRow`)** fires at line 133 with Y=`$00`, line 135 with Y=`$01`, and ends at line 227 with Y=`$2F` (47).
- The RAM bytes to watch are `Mode` at `$80`, `DemoTimer` at `$81`, `DashX` at `$82`, the counters at `$88–$8A`, and the mode table at `ModeStates` in ROM.

The screenshot proves the visual state; the state log proves the values and the lines. Neither one alone is the whole claim.

## Exercises

### Exercise 1: Three Zones — 64 + 64 + 64

**Challenge:** change mode 0 from a 96 + 96 split into three 64-line zones: a 1-line zone (64 rows), a 2-line zone (32 rows), and a 1-line zone (64 rows). The zones must total 192 lines, `ZoneCount` must report 3, and the middle zone must be visibly chunky.

**Hints:**
1. A 64-row 1-line table is the same diamond rule with `half = min(row, 63 - row)`: 2 chunks at the tips, 24 chunks at the middle. The 2-line table is rows 0, 2, 4, …, 62 of it.
2. The three loops are 64 × `WSYNC`, 32 × two `WSYNC`s, and 64 × `WSYNC` = 64 + 64 + 64 = 192. The boundaries are at visible 64 and 128, which are scanlines 101 and 165.
3. Use P0 for the two 1-line zones and P1 for the middle 2-line zone. Put the 1-line dash at row 16 of the 64-row strip (visible 16 in the top zone and 144 in the bottom) and the 2-line dash at row 16 of the 32-row strip (visible 96–97).
4. Change the mode-0 `ModeStates` entry to `3, 64, 32`; leave the mode 1/2 entries alone.
5. Reset the playfield registers at each boundary and preload the next zone's top tip, exactly as the lesson's split does at visible 96.

**Expected Result:** mode 0 shows a green 64-line diamond at visible 0–63, a chunky gold 64-line diamond at 64–127, and the green 64-line diamond again at 128–191. `ZoneCountRead` reports A=`$03`; `LineRow` starts at line 37, `PairRow` at 101, `LineRow3` at 165; `OverscanStart` is 229. The solution assembles to exactly 4,096 bytes.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: A Rectangle, Not a Diamond

**Challenge:** replace the diamond data with a solid rectangle. The 1-line zone must show a crisp 64-line rectangle; the 2-line zone must show the same rectangle with two-line-thick top and bottom edges. Add a `Shape` byte that reports 1.

**Hints:**
1. The rectangle is 96 pixels wide and 64 lines tall, centred in each 96-line zone: data rows 16–79 are `$00/$0F/$FF` and every other row is `$00/$00/$00`.
2. The 2-line table is the same sample-at-every-second-row operation. Rows 16, 18, …, 78 are the 32 full rows; in the full 2-line mode's first pass they span visible 16–79, and in mode 0's bottom zone the same rows display at visible 112–175 (64 lines). The first and last rows cover two scanlines each.
3. The left and right edges are vertical and identical in both zones; the vertical edge is the detail the kernel resolution changes.
4. Keep the dashes where they are: P0 row 24 and P1 row 36. Both fall inside the rectangle.
5. Add `SHAPE = 1` and a `Shape` byte; store it at reset and break at `ShapeRead` to report A=1.

**Expected Result:** mode 0's top zone is a green rectangle from visible 16 to 79 with a crisp one-line top edge; the bottom zone is the same rectangle in gold from visible 112 to 175, with two-line-thick edges. `ShapeRead` reports A=`$01`; `OverscanStart` is 229. The solution assembles to exactly 4,096 bytes.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Mode 3 — A Multi-Zone Layout *(Stretch Goal)*

**Challenge:** add a fourth mode with an 8-line header, a 176-line 2-line play area (88 rows × 2), and an 8-line footer. The zones must total 192, `Mode` must reach 3, and `HeaderEnd` must report 8.

**Hints:**
1. The header and footer are full-width playfield bands: `PF0/PF1/PF2 = $FF`, green `$C8`, eight `WSYNC`s each.
2. The play area needs an 88-row 2-line table. Generate it from a 176-line 1-line diamond sampled at rows 0, 2, …, 174. The play area is 88 × 2 = 176 lines.
3. `ModeStates` gets a fourth entry: `3, 0, 88` (header/play/footer = three zones, no one-line rows, 88 pairs).
4. `MODE_COUNT` becomes 4, so fire cycles 0 → 1 → 2 → 3 → 0 and the auto-demo's four-mode cycle is 960 frames.
5. Preload the header's first row as `$FF/$FF/$FF` in VBLANK and reset the playfield at each boundary; `HeaderEnd` is the `LDA #8` at the start of the header loop.

**Expected Result:** mode 3 shows a green 8-line header, a gold 176-line 2-line diamond with two-line dashes, and a green 8-line footer. `HeaderEnd` reports A=`$08` at scanline 37; `ModeStep` reports A=`$03` at frame 720; `OverscanStart` is 229. The solution assembles to exactly 4,096 bytes.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A kernel is the picture, drawn live.** The 2600 has no frame buffer; the CPU writes the TIA registers for each of the 192 visible scanlines, once per frame.
- ✅ **One line is 76 cycles; a 2-line pair is 152.** The row body, the `WSYNC`, the loop tail, and any page-crossing loads all come out of that budget.
- ✅ **1-line buys vertical detail; 2-line buys room.** The demo's diamond is 96 rows and 288 bytes at 1-line, 48 rows and 144 bytes at 2-line; the 2-line kernel is the default for a full-screen game.
- ✅ **Vertical position comes from *when* you write.** There is no Y register; the row you write on is the row that appears. Horizontal position is the `RESxx` + `HMPx` + one-`HMOVE` dance.
- ✅ **Work-first: write the row, then `WSYNC`.** The store order follows the first visible pixel: sprites first, `PF1` and `PF2` next, `PF0` last for a centred shape that never uses it.
- ✅ **The taxonomy is a design vocabulary.** Multi-zone divides the screen, repositioning reuses an object, and flicker alternates two frames; each one spends cycles and data in a different place.
- ✅ **The famous kernels are context, not copy-paste.** Combat, Adventure, Pitfall!, River Raid, and Cosmic Ark each solved a different data/motion problem; the demo reproduces the trade-off, not the games.

## What's Next

The zoo shows the shapes; the next lesson builds the one you will use most. [Lesson 49: The 2-Line Kernel — Standard Game Pattern](/part7-kernel-mastery/49-two-line-kernel) turns the 2-line loop into a full landscape: a 96-row mountain, a per-row colour ramp, a 16-line figure on P0, and a 16-line bird on P1, with a 63-effective (62 nominal) two-line ledger.
