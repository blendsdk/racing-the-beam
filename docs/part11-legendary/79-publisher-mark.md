---
title: "Lesson 79: The Publisher Mark — An Activision-Style In-Game Logo"
description: "Build the calling card: a 4,096-byte game with a six-digit score, a falling star, and a 48-pixel RACING publisher mark in the bottom band, drawn by a page-aligned ROM table and an unrolled 48-pixel kernel."
prev:
  text: "Lesson 78: Room & Object Engine — The Adventure Architecture"
  link: "/part11-legendary/78-room-object-engine"
---

# Lesson 79: The Publisher Mark — An Activision-Style In-Game Logo

> **Part 11: Legendary Techniques** · Estimated time: 150 minutes
> **Prerequisites:** Lesson 17 (cycle counting and page-cross costs), Lesson 19 (playfield basics), Lesson 21 (asymmetric playfield), Lesson 23 (data-driven playfield), Lesson 26 (horizontal positioning), Lesson 31 (copies and sizes), Lesson 32 (vertical delay), Lesson 38 (collision detection), Lesson 39 (the scoreboard and the 48-pixel kernel), Lesson 42/47/63 (joystick, SELECT, and the auto-demo pattern), Lesson 50 (the multi-zone kernel and the handover), Lesson 55 (the 48-pixel text window)
> **You will learn:** how a five-zone frame fits exactly 192 visible lines; how the Lesson 39 48-pixel kernel becomes a second, independent screen element; why the score kernel is position-sensitive, and how to unroll the eight rows and place the commits for a block 40 pixels to the left; how a 48-byte ROM table replaces the score's RAM buffer; how the handover positions the players between zones; how the three HMOVEs share a frame; and how SELECT hides the mark without changing the frame.
> **You will build:** "the calling card" — a 4,096-byte ROM with a white `000000` score, a red player, a falling gold star, and a gold `RACING` mark in the bottom-left corner. The player catches the star; each catch adds one. SELECT hides or shows the mark; an auto-demo scripts the toggle for the two captures. Plus three complete exercise solutions: a ten-letter 4×7 wordmark, the mark moved to the bottom-centre, and a stretch solution that draws the mark with the playfield.

## Introduction

Lesson 39 built the 48-pixel score: two players in three-copy close mode, six 8-pixel cells across TIA X=56–103, and a 48-byte buffer in RAM. Lesson 50 put four kernels in one frame and gave each zone a fixed line budget. Lesson 55 replaced the digits with a text window and scrolled it through the same six cells. Each lesson used the 48-pixel window at the top of the screen, and each treated the window as a single element.

This lesson turns the window into a second, independent screen element: a publisher mark in the bottom band. The score still reads a RAM buffer at X=56/64; the mark reads a 48-byte ROM table at X=16/24. The two windows share the frame with a small game — a red player, a falling gold star, a six-digit score — and a fixed handover that moves the players from the score to the mark. SELECT hides or shows the mark. The mark is not part of the playfield and not a title screen: it is redrawn every frame, nine lines tall, while the game runs above it.

The composition has a trap. The Lesson 39 kernel's store order is timed for copies at X=56/64. Move the block 40 pixels left and the copies arrive 13.3 cycles earlier; the later stores land after the copies and every cell shows its first column. A literal clone draws `RARARA`, not `RACING`. The lesson's central work is unrolling the eight rows and placing the six commits for the mark's earlier windows while keeping the frame at 262 lines. The companion program `79-publisher-mark.asm` makes the whole picture visible: a white `000001`, a red player, a gold star, a dark-green ground, and the gold `RACING` mark at the bottom-left.

::: details TypeScript Equivalent

The frame is a list of zones with fixed line counts. A `drawScore` function reads a six-column buffer; a `drawMark` function reads a six-column ROM table. The shape of the data is the same:

```typescript
interface Zone {
  name: string;
  lines: number;
  draw: () => void;
}

const FRAME: Zone[] = [
  { name: "score", lines: 9, draw: drawScore },
  { name: "positioner", lines: 5, draw: positionGame },
  { name: "play", lines: 164, draw: drawPlay },
  { name: "handover", lines: 5, draw: positionMark },
  { name: "mark", lines: 9, draw: drawMark },
];

// 9 + 5 + 164 + 5 + 9 = 192 visible lines
const VISIBLE_LINES = FRAME.reduce((n, z) => n + z.lines, 0);

const MARK: number[][] = [
  [0x00, 0x88, 0x90, 0xa0, 0xf0, 0x88, 0x88, 0xf0], // R
  [0x00, 0x88, 0x88, 0x88, 0xf8, 0x88, 0x88, 0x70], // A
  [0x00, 0x70, 0x88, 0x80, 0x80, 0x80, 0x88, 0x70], // C
  [0x00, 0xf8, 0x20, 0x20, 0x20, 0x20, 0x20, 0xf8], // I
  [0x00, 0x88, 0x88, 0x88, 0x98, 0xa8, 0xc8, 0x88], // N
  [0x00, 0x70, 0x88, 0x88, 0xb8, 0x80, 0x88, 0x70], // G
];

function drawMark(table: number[][]): void {
  for (let row = 7; row >= 0; row--) {
    for (let col = 0; col < 6; col++) {
      emitCell(col, table[col][row]);
    }
    waitScanline();
  }
}
```

The analogy breaks in three places. There is no framebuffer: `emitCell` is not a pixel write but a store to `GRP0`/`GRP1` that must happen before that cell's copy reaches the beam. The TIA has two one-byte latches, `GRP0` and `GRP1`, and VDEL makes a write stage a byte that the *other* player's write commits; the order and the cycle of each store decide which cell shows which byte. And the frame is fixed: the five zones must total 192 visible lines, and every kernel must finish inside its lines or the picture rolls. A TypeScript loop can take as long as it likes; a 2600 kernel cannot.

:::

## Theory

### The bottom band and the 192-line budget

NTSC is 262 lines: 3 VSYNC lines, 37 VBLANK lines, 192 visible lines, and 30 overscan lines. The visible area is the only part the player sees, and it is a fixed budget. This lesson spends it in five bands:

| Visible lines | Lines | Band | What draws it |
|---|---:|---|---|
| 0–8 | 9 | Score | `ScoreDraw`, the Lesson 39 48-pixel kernel |
| 9–13 | 5 | Top positioner | P0 to `PlayerX`, the ball to `BallX`, one HMOVE |
| 14–177 | 164 | Play | 82 rows × 2 lines, playfield bands, P0 and the ball |
| 178–182 | 5 | Handover | P0 to 16, P1 to 24, one HMOVE |
| 183–191 | 9 | Mark | `MarkDraw`, the unrolled 48-pixel kernel |
| **192** | | | |

In absolute scanlines (visible line 0 is scanline 37):

| Band | Scanlines |
|---|---|
| Score | 37–45 |
| Top positioner | 46–50 |
| Play | 51–214 |
| Handover | 215–219 |
| Mark | 220–228 |
| Overscan | 229–258 |
| Next VSYNC | 259 |

The frame gate is `StartFrame` at 259/3, `VblankStart` at 0/5, `BodyStart` at 37/5, and `OverscanStart` at 229/6. The exact cycles are not decoration: `BodyStart` is the first visible line, and every band boundary is a fixed line. The kernel is a schedule, not a drawing library.

The VBLANK timer is 44 ticks (`1 + 43 × 64 = 2,753` cycles, 36.2 lines), which lands the `+wait_timer` return at line 37 cycle 0; `LDA #$00 / STA VBLANK` then puts `BodyStart` at 37/5. The overscan timer is 36 ticks (`1 + 35 × 64 = 2,241` cycles, 29.5 lines), which should put the next `StartFrame` at 259/3.

On this build the overscan timer is a single 36-tick write; `StartFrame` measures 259/3 and `MarkDone` 229/6, so the frame is 262. An earlier build measured 257/3 because the old mark cleanup returned before scanline 229; the unrolled kernel's cleanup delay fixes the overscan entry. If a frame comes up short, log `StartFrame` before changing any kernel.

### The second 48-pixel window

A player is 8 pixels wide. `NUSIZ=3` gives three close copies at X, X+16, and X+32. Put P0 at TIA X=56 and P1 at X=64 and the copies interleave:

```
P0 copy 0  X=56    P1 copy 0  X=64
P0 copy 1  X=72    P1 copy 1  X=80
P0 copy 2  X=88    P1 copy 2  X=96
```

That is six 8-pixel cells across 48 pixels, X=56–103. The score uses this block at the top. The mark uses the same geometry 40 pixels to the left: P0 at X=16 (copies 16, 32, 48), P1 at X=24 (copies 24, 40, 56), block X=16–63.

`VDELP0`/`VDELP1` make the kernel possible. A write to `GRP0` does not change the output immediately; it *stages* a byte. The next write to `GRP1` commits the staged `GRP0` byte to P0 and stages the `GRP1` byte. The next write to `GRP0` commits the staged `GRP1` byte to P1, and so on. Each cell can therefore be placed just before its copy reaches the beam. Without VDEL, a store that lands inside an 8-pixel copy window would change the byte halfway through the cell and tear it.

The six stores and the seventh flush are the Lesson 39 sequence:

| Store | Register | Column | What it does |
|---|---|---|---|
| 1 | `GRP0` | 0 | stages column 0 |
| 2 | `GRP1` | 1 | commits column 0 to P0, stages column 1 |
| 3 | `GRP0` | 2 | commits column 1 to P1, stages column 2 |
| 4 | `GRP1` | 3 | commits column 2 to P0, stages column 3 |
| 5 | `GRP0` | 4 | commits column 3 to P1, stages column 4 |
| 6 | `GRP1` | 5 | commits column 4 to P0, stages column 5 |
| 7 | `GRP0` | 5 | commits column 5 to P1 (the cross-latch flush) |

`MarkDraw` keeps this order. The trap is *when* the stores happen.

#### The score kernel is position-sensitive

The score's copies at X=56/64 have first pixels at

```
(56 + 68) / 3 = 41.3 cycles    (P0 copy 0)
(64 + 68) / 3 = 44.0 cycles    (P1 copy 0)
(72 + 68) / 3 = 46.7 cycles    (P0 copy 1)
(80 + 68) / 3 = 49.3 cycles    (P1 copy 1)
(88 + 68) / 3 = 52.0 cycles    (P0 copy 2)
(96 + 68) / 3 = 54.7 cycles    (P1 copy 2)
```

`ScoreDraw`'s commits land at cycles 9, 16, 44, 47, 50 and 53. The first two have huge margins; the later four are timed to fall just before their copy windows. That is why the NOP and `CPX ScoreRow` are in the library: they are the delay between the early columns and the late ones.

Move the block to X=16/24 and every copy arrives 40 pixels earlier:

```
(16 + 68) / 3 = 28.0    (24 + 68) / 3 = 30.7
(32 + 68) / 3 = 33.3    (40 + 68) / 3 = 36.0
(48 + 68) / 3 = 38.7    (56 + 68) / 3 = 41.3
```

The score's later commits at 44–53 are now *after* the mark's copies. A literal clone displays the first column in every cell: `RARARA`. This is not a table bug and not a page-cross bug; it is the store schedule measuring the wrong windows.

#### Unrolling the mark kernel

`MarkDraw` keeps the six stores and the seventh flush, but it cannot keep the score's load schedule. The score's stores are timed for copies at X=56/64; the mark's copies arrive 40 pixels (13.3 cycles) earlier. A literal clone commits its later columns after the mark's copies and draws `RARARA`, not `RACING`.

The fix is to unroll the eight rows. `MarkPreload` and `MarkStores` are expanded for `.r = 7` down to 0, with fixed table addresses:

- `MarkPreload` loads column 2 into `MarkTmp`, column 0 into A and column 1 into X (15 cycles).
- `STA WSYNC` ends the setup line.
- `MarkStores` writes columns 0, 1, 2, 3, 4 and 5 and the seventh flush, using fixed-address loads for columns 3, 4 and 5 (41 cycles).

A row is 15 + 3 + 41 = 59 cycles, inside the 76-cycle line; there is no loop counter or branch. The GRP1/GRP0 writes that commit the six columns start at cycles 3, 9, 29, 32, 35 and 38 (write cycles 5, 11, 31, 34, 37 and 40). The C commit at write 31 (CLK 93) sits in the gap between P0 copy 0 (CLK 84–91) and P0 copy 1 (CLK 100–107). The later commits at CLK 102, 111 and 120 keep 6/5/4 CLK of margin before the P1 copy 1, P0 copy 2 and P1 copy 2 windows. The host-rendered table and the capture match exactly (0/384); the C-to-R bleed is gone, and the captured mark reads `RACING`.

The table is page-aligned, so every fixed-address load is four cycles. A page cross would add one cycle and shift that column.

::: tip Why the eight NOPs are still there

A `STA WSYNC` parks the CPU until the HCount wrap whatever cycle it is written on (Lessons 12 and 14). The eight NOPs after the HMOVE are not needed to make the WSYNC work; they put the store at 50/25 (and 219/25), so the HMOVE has settled and the next line starts where the kernel expects. The positioner's first WSYNCs measure 48/19–21 and the handover's 217/14–16; those store positions are the evidence, not a HBLANK rule. Removing the NOPs would move the store earlier in the line but the band lines would not change.

:::

### The handover and the three HMOVEs

The players are shared by the score and the mark. The handover is the five lines that move them from the score's positions to the mark's:

- `SetMarkP0` is the Lesson 26 divide-by-15 routine with P0's target `16 + 3`; it starts on a fresh line and ends with a WSYNC, so it costs exactly two lines for every X.
- `SetMarkP1` is the same routine for P1's target `24 + 3`; it costs the next two lines.
- The fifth line carries one `STA HMOVE`, which applies `HMP0` and `HMP1` in that line's HBLANK. The HMOVE's left-edge blanking falls on the blank handover line, not on the mark.
- `NUSIZ0=NUSIZ1=3`, `VDELP0=VDELP1=1`, `COLUP0=COLUP1=$1A` (gold), and `ENABL=0`.

The frame has three HMOVEs:

1. **Score HMOVE** in VBLANK, inside `ScoreSetup`, applying HMP0/HMP1 at 56/64.
2. **Game HMOVE** on line 50, applying HMP0 and HMBL for the play band. The ball's reset is one colour clock shorter than a player's, so its target carries one extra pixel (`POS_BIAS + 1`).
3. **Mark HMOVE** on line 219, applying HMP0/HMP1 at 16/24.

The 24-cycle rule says do not write a motion register for 24 cycles after an HMOVE. All three HMOVEs are followed by either a WSYNC plus several lines of work (the score), the play kernel (the game), or the next frame's VBLANK (the mark). No motion register is written in the play or the mark band.

::: tip Why MarkSetup is a copy, not a call

`ScoreSetup` in `include/score.asm` hard-codes `SCORE_P0_X=56` and `SCORE_P1_X=64`. The mark needs 16/24. Refactoring the library to take parameters would change Lessons 39, 40, 50, 55, 61, 63, and the capstones. The lesson copies the setup (`MarkSetup`) and explains the duplication. A shared library is a contract; when one caller needs a different position, copy the routine rather than change the contract for everyone.

:::

### The ROM table and page alignment

The score changes every catch, so its six columns live in RAM (`ScoreBuf`, 48 bytes, column-major, bottom-up). The mark never changes, so its six columns live in ROM (`MarkBuf`, 48 bytes, same layout). That saves 48 RAM bytes and makes the mark table part of the cartridge image.

The layout is column-major and bottom-up: column `c`, row `r` is `MarkBuf + c*8 + r`. The six columns are the glyphs R, A, C, I, N, G in 8×8 cells. Each glyph is 5×7, bit 7 is the leftmost pixel, and byte 0 is `$00`, so the lit block is seven rows (visible 184–190). The table is preceded by `!align 255,0`: all 48 bytes stay inside one page, so every `LDA MarkBuf+n,Y` is four cycles. A page cross adds one cycle and shifts that column in the kernel. The alignment is part of the timing, not a style choice.

The playfield's PF planes and the player's strip are page-aligned for the same reason. The mark kernel reads columns at `MarkBuf+0`, `+8`, `+16`, `+24`, `+32`, and `+40`; with `Y` in 0–7 and the table at a page boundary, none of those loads crosses a page.

### Title-screen logo vs the in-game mark

Lessons 61 and 63 build title screens: a logo or a menu that occupies the whole visible area, then yields to the game. A title screen is a state; it can use every line for the logo and every cycle for the display.

The in-game mark is a different object. It shares the frame with the game, the score, and the handover. It is nine lines tall, it is redrawn every frame, and it must not disturb the play band. The mark is not a bitmap loaded into a framebuffer — the 2600 has no framebuffer — it is a 48-byte table read by a kernel that runs in the bottom band. The band is a promise: whatever the game does above, the mark is there for nine lines, and SELECT can hide it without changing the frame.

### A historical note: the Activision wordmark

Activision was founded in 1979 by former Atari employees. Its early Atari 2600 releases used the publisher's name as a screen element: a logo screen, and later a wordmark in a band of the game screen. The 48-pixel two-player trick was one of the techniques that made a wide, detailed strip affordable in a 4K cartridge. The history is context for this lesson; it is not a template.

The mark in this lesson is **RACING**, an original course wordmark. Do not reproduce the Activision wordmark, logo, or any copyrighted screen. A release uses its own name and artwork; another company's trademark is not the homebrew author's to use. Lesson 63 states the rule; this lesson follows it.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson79.bin \
  lessons/part11-legendary/79-publisher-mark/79-publisher-mark.asm

stella build/lesson79.bin
```

The three exercise solutions sit beside the lesson source. Each is a complete 4,096-byte ROM:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part11-legendary/79-publisher-mark/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part11-legendary/79-publisher-mark/exercise-02-solution.asm
acme -f plain -o build/exercise-03.bin \
  lessons/part11-legendary/79-publisher-mark/exercise-03-solution.asm
```

### Full Source

The complete annotated source is reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 79: The Publisher Mark — An Activision-Style In-Game Logo
; =============================================================================
; Part 11: Legendary Techniques
;
; What this program does:
;   "the calling card": a small game with a six-digit score at the top, a
;   play field with a red player and a falling gold star, and a 48-pixel
;   publisher mark — the original word RACING — in the bottom-left corner.
;   The player catches the star; every catch adds one to the score.  SELECT
;   hides or shows the mark, proving that the mark is an independent screen
;   element and not part of the play field.  An auto-demo plays the game and
;   scripts the toggle, so both captures are reproducible without input.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   The 192 visible lines are five bands:
;
;     visible   0-  8   the score       9 lines   ScoreDraw (Lesson 39)
;     visible   9- 13   the positioner  5 lines   P0 to PlayerX, ball to BallX
;     visible  14-177   the play      164 lines   82 rows x 2 lines
;     visible 178-182   the handover    5 lines   P0=16, P1=24 for the mark
;     visible 183-191   the mark        9 lines   MarkDraw (unrolled at X=16)
;                       ----------------
;                       9 + 5 + 164 + 5 + 9 = 192
;
;   Absolute scanlines: ScoreDone 46, PlayStart 51, HandoverStart 215,
;   MarkStart 220, MarkDone 229, OverscanStart 229.  The frame gate is
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5.
;
; The score band (visible 0-8):
;   include/score.asm draws six white digits with P0/P1 in three-copy close
;   mode.  P0 sits at TIA X=56 (copies at 56, 72, 88) and P1 at X=64 (copies
;   at 64, 80, 96), so the six columns interleave across X=56-103: a
;   48-pixel block.  ScoreSetup runs in VBLANK, sets NUSIZ=3 and VDEL on,
;   positions the players, and strobes ONE HMOVE.  ScoreDraw consumes nine
;   lines: line 0 is the setup/blank line and lines 1-8 are the eight rows.
;   Every glyph's byte 0 is $00, so the lit digits are visible 1-7.
;
;   The play field's P1 is blank: P1 is reserved for the score and the mark.
;
; The top positioner (visible 9-13):
;   P0 moves from the score's X=56 to PlayerX; the ball moves to BallX.
;   SetGameP0 and SetGameBall are the Lesson 26 divide-by-15 routines.  Each
;   starts with a WSYNC and ends with a WSYNC, so each costs exactly two
;   lines for every X; the fifth line carries the HMOVE.  The ball's target
;   adds one extra pixel because a ball's reset is one colour clock shorter
;   than a player's (Lesson 29/39).  NUSIZ0=NUSIZ1=0 (one 8-pixel copy
;   each), VDEL off, COLUP0 red, COLUPF gold.  The ball is left disabled here;
;   the play kernel enables it only on its four rows, so no stray pixel
;   appears on the positioner line.
;
;   The HMOVE applies HMP0 and the ball's HMBL in the HBLANK of line 50.
;   Its left-edge blanking is on that positioner line, not on the play.
;
; The play band (visible 14-177, 164 lines = 82 rows x 2):
;   A two-line kernel.  Each row writes GRP0, the ball's ENABL, and PF0/PF1/
;   PF2.  The playfield is reflected (CTRLPF=$01); the sky is mostly dark,
;   with four two-row star bands and a full-width gold horizon; the ground
;   is a solid dark-green band.  The player is an 8-pixel-wide, 16-line-tall
;   figure fixed at kernel rows 72-79.  The ball is one pixel wide and four
;   kernel rows tall (eight scanlines); BallY runs 8-70 and is its top row.
;
;   The ball is eight scanlines tall and shares COLUPF with the playfield.
;   In the sky it is gold against the dark background; on the green ground
;   (rows 69-81) it takes the ground colour and blends near the catch.  That
;   is the trade-off of a one-colour playfield/ball register, and it is
;   called out in the lesson.
;
;   CXP0FB bit 6 (P0-ball) is read in the next VBLANK: the latch describes
;   the visible frame that just ended, so a catch is one frame late by
;   construction (Lessons 38/50).  A hit adds one with ScoreAddOne, resets
;   the ball to row 8, and chooses a new X.  The new X alternates between 56
;   and 104.  Once the demo is running (AutoPlay=1 after 120 frames), the
;   one-pixel-per-frame player can reach either X before the star lands.
;   The first respawn at X=56 (frame 63) is missed because the demo has not
;   started; the second catch is frame 188, and the 62-frame cadence starts
;   there.
;
; The handover (visible 178-182):
;   SetMarkP0 positions P0 at TIA X=16 (two lines), SetMarkP1 positions P1 at
;   X=24 (two lines), and the fifth line carries ONE HMOVE.  NUSIZ=3 for
;   both, VDEL on, COLUP0/COLUP1 gold ($1A), ENABL off.  The HMOVE's
;   left-edge blanking falls on the blank handover line, not on the mark.
;   No motion register is written again until the next frame's VBLANK, far
;   beyond the 24-cycle rule.
;
; The mark band (visible 183-191):
;   MarkSetup is the mark-position copy of ScoreSetup.  It cannot call the
;   shared ScoreSetup because that routine hard-codes 56/64, and changing
;   the library would affect Lessons 39, 40, 50, 55, 61, 63 and the
;   capstones.  The lesson copies the setup and explains why.
;
;   MarkBuf is a 48-byte ROM table, column-major and bottom-up: column c,
;   row r lives at MarkBuf + c*8 + r.  The six 8-pixel cells are the glyphs
;   R, A, C, I, N, G in 8x8 cells; each glyph is 5x7, bit 7 is the leftmost
;   pixel, and byte 0 is $00, so the lit block is seven rows (visible
;   184-190).  The table is preceded by !align 255,0: all 48 bytes stay in
;   one page, so every LDA MarkBuf+n,Y is four cycles.  A page cross would
;   add one cycle and shift that column in the kernel.
;
;   MarkDraw is unrolled: the eight rows are eight expansions of
;   MarkPreload/MarkStores with fixed table addresses.  There is no loop
;   counter, which gives the row the cycles to place the C commit in the
;   gap between P0 copy 0 (CLK 84-91) and P0 copy 1 (CLK 100-107).  The
;   commits are at write cycles 5, 11, 31, 34, 37 and 40; the C commit at
;   31/CLK 93 is the one that used to bleed the C glyph into the R cell.
;   The row is 59 cycles, comfortably inside 76; the cleanup blanks
;   GRP0/GRP1, clears VDEL, and a nine-NOP/BIT delay puts MarkDone at
;   229/6.  The band still consumes nine lines.
;
;   If MarkVisible=0 the band still consumes nine lines: the program skips
;   MarkDraw, keeps the players blank, clears VDEL, and waits nine WSYNCs.
;   The frame stays 262 in both states.
;
; Input and the auto-demo:
;   SWCHA P0 left/right (bits 6/7, active low) moves PlayerX one pixel per
;   frame, clamped to 8-144.  INPT4 fire (bit 7, active low) resets the
;   score to 000000 with ScoreClear on a new press.  SWCHB bit 1 SELECT
;   (active low) toggles MarkVisible on a new press.  After 120 idle frames
;   the auto-demo starts: the player tracks BallX-3, so the star lands on
;   the player's left-centre.  At frame 240 the demo calls the same
;   ToggleMark path as SELECT, hiding the mark for the second capture.  The
;   demo's state byte is AutoPlay: 0 = idle, 1 = tracking, 2 = the mark has
;   been hidden (so the scripted toggle happens once).
;
; Checkpoints (the A/X/Y values are the state at the label):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   ScoreDone (46), PlayStart (51), HandoverStart (215),
;   MarkStart (220), MarkDone (229), OverscanStart (229/6);
;   ScoreWrite (A = the new score's rightmost digit), MarkVisibleWrite
;   (A = the new MarkVisible, 0/1), PlayerXRead (A = PlayerX on the manual
;   left branch), BallYRead (A = BallY before the fall), Hit (A = the new
;   score's rightmost digit), SelectEdge (A = 1 on a toggle).
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80 Frame          frame counter, 8 bits
;   $81 PlayerX        the player's TIA X, 8-144
;   $82 BallX          the ball's TIA X, 24-136
;   $83 BallY          the ball's top kernel row, 8-70
;   $84 PrevFire       fire edge latch (0 = released, 1 = pressed)
;   $85 PrevSelect     SELECT edge latch (0 = released, 1 = pressed)
;   $86 AutoTimer      idle frames, 0-120
;   $87 AutoPlay       0 = idle, 1 = tracking, 2 = the scripted toggle ran
;   $88 MarkVisible    0 = hidden, 1 = visible; reset sets 1
;   $89-$8A            free (2 bytes)
;   $8B MarkTmp        MarkDraw's column-2 scratch
;   $8C BallNext       the ball-enable lookahead for the next play row
;   $8D-$8F            free (3 bytes)
;   $A0-$A5 ScoreDigits
;   $A6 ScoreRow
;   $A7 ScoreTmp
;   $A8-$D7 ScoreBuf    48 bytes, column-major, bottom-up
;   $D8-$F7            free (32 bytes)
;   $F8-$FF            stack
;
;   The mark table is in ROM, not RAM: the score changes every catch, the
;   mark never changes, so moving it to ROM saves 48 RAM bytes.
;
; Build: acme -f plain -o build/lesson79.bin \
;        lessons/part11-legendary/79-publisher-mark/79-publisher-mark.asm
; Run:   stella build/lesson79.bin
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

; --- the visible-line budget --------------------------------------------------
PLAY_ROWS      = 82      ; visible 14-177: 82 rows x 2 scanlines = 164 lines
SKY_ROWS       = 69      ; play rows 0-68: the sky and the horizon row
PLAYER_TOP     = 72      ; the player's first kernel row (visible 158)
PLAYER_ROWS    = 8       ; the player is 8 kernel rows = 16 scanlines
BALL_START_Y   = 8       ; the star's top row at respawn
BALL_END_Y     = 70      ; the last top row before a miss

P0_MIN         = 8       ; the player's left clamp (TIA X)
P0_MAX         = 144     ; the player's right clamp (8 pixels wide)
P0_START       = 76      ; power-on: the ball at 80 is inside the player
PLAYER_CENTRE  = 3       ; the auto-demo aims three pixels left of BallX

; --- the auto-demo ------------------------------------------------------------
AUTO_FRAMES    = 120     ; idle frames before the demo starts
AUTO_TOGGLE    = 240     ; the demo hides the mark at this frame

; --- the mark positions -------------------------------------------------------
MARK_P0_X      = 16      ; P0's TIA X; copies at 16, 32, 48
MARK_P1_X      = 24      ; P1's TIA X; copies at 24, 40, 56
; The six interleaved cells span TIA X=16-63.

; --- colours ------------------------------------------------------------------
C_WHITE        = $0E     ; the score
C_PLAYER       = $42     ; the player: red
C_GOLD         = $1A     ; the star, the stars, the mark
C_GROUND       = $C4     ; the ground: dark green
C_BG           = $02     ; the sky: near-black

; --- the score library's fixed positions (include/score.asm) ------------------
; The score uses SCORE_P0_X=56 and SCORE_P1_X=64; the mark uses 16 and 24.
; The mark's setup is copied below because the library hard-codes the score.

; =============================================================================
; RAM ALLOCATION ($80-$8C; +clean_start zeroes every byte)
; =============================================================================
Frame        = $80   ; the frame counter, 8 bits
PlayerX      = $81   ; the player's left edge, 8-144
BallX        = $82   ; the ball's left edge, 24-136
BallY        = $83   ; the ball's top kernel row, 8-70
PrevFire     = $84   ; 0 = fire released, 1 = held
PrevSelect   = $85   ; 0 = SELECT released, 1 = held
AutoTimer    = $86   ; idle frames, 0-120
AutoPlay     = $87   ; 0 = idle, 1 = tracking, 2 = the scripted toggle ran
MarkVisible  = $88   ; 0 = hidden, 1 = visible
MarkTmp      = $8B   ; MarkDraw's column-2 scratch
BallNext     = $8C   ; the ball-enable lookahead for the next play row
ScoreOnes    = $A5   ; ScoreDigits+5: the visible score's rightmost digit
;
; $8D-$8F are free (3 bytes).  The score library owns $A0-$D7; $D8-$F7 is
; free.  The stack lives at $F8-$FF.

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

; --- the score starts at 000000 ----------------------------------------------
    JSR ScoreInit           ; zero the digits and the 48-byte buffer
    JSR ScoreClear          ; build the six zero glyphs: 000000

; --- the game's initial state ------------------------------------------------
    LDA #P0_START
    STA PlayerX
    LDA #$50                ; 80: the star starts above the player
    STA BallX
    LDA #BALL_START_Y
    STA BallY
    LDA #$01
    STA MarkVisible         ; the mark is visible at power-on

; --- the static colours and controls -----------------------------------------
    LDA #C_BG
    STA COLUBK
    LDA #C_GOLD
    STA COLUPF
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    LDA #$01
    STA CTRLPF              ; reflect the playfield; the ball is one pixel
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    STA NUSIZ0
    STA NUSIZ1

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    INC Frame

; -----------------------------------------------------------------------------
; 1. THE COLLISION — CXP0FB bit 6 (P0-ball), read one frame late
; -----------------------------------------------------------------------------
; The latch describes the visible frame that just ended, so the hit is always
; one frame late by construction.  CXCLR clears every latch after the read.
    LDA CXP0FB
    AND #$40                ; bit 6: player 0 met the ball
    BEQ NoHit
    JSR ScoreAddOne         ; add one, with a decimal carry
    LDA ScoreOnes           ; ScoreDigits+5: the rightmost digit
ScoreWrite:                 ; checkpoint: A = the new rightmost digit
Hit:                        ; checkpoint: A = the new rightmost digit
    LDA #BALL_START_Y
    STA BallY               ; respawn at the top of the field
    LDA BallX
    CMP #$50                ; 80: alternate the respawn left and right
    BCS HitLeft
    LDA #$68                ; 104
    JMP HitStoreX
HitLeft:
    LDA #$38                ; 56
HitStoreX:
    STA BallX               ; the player can reach either X before the fall
    JMP HitDone
NoHit:
    LDA BallY
BallYRead:                  ; checkpoint: A = BallY before the step
    CMP #BALL_END_Y
    BCS BallReset
    INC BallY
    JMP HitDone
BallReset:
    LDA #BALL_START_Y
    STA BallY               ; the star reached the ground: start again
HitDone:
    LDA #$00
    STA CXCLR               ; the latches have done their job for this frame

; -----------------------------------------------------------------------------
; 2. P0 — the joystick, or the auto-demo seeking the star
; -----------------------------------------------------------------------------
; SWCHA's P0 direction bits are active low: left reads $80 after AND #$C0,
; right reads $40, and neither reads $C0.  TIA X is clamped to 8..144.
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ AutoDemo            ; neither pressed: run the demo
    LDA SWCHA
    AND #$40                ; left
    BNE MoveRight
    LDA PlayerX
PlayerXRead:                ; checkpoint: A = PlayerX on the left branch
    CMP #P0_MIN
    BEQ MoveDone
    DEC PlayerX
    JMP MoveDone
MoveRight:
    LDA SWCHA
    AND #$80                ; right
    BNE AutoDemo            ; both directions: treat as no input
    LDA PlayerX
    CMP #P0_MAX
    BEQ MoveDone
    INC PlayerX
    JMP MoveDone

; The auto-demo: after AUTO_FRAMES idle frames, track BallX-3.  The seek
; target is clamped to the player's travel, and the player moves one pixel
; per frame, so it is under the star before the star reaches row 70.
AutoDemo:
    LDA AutoPlay
    BNE AutoTrack
    INC AutoTimer
    LDA AutoTimer
    CMP #AUTO_FRAMES
    BCC MoveDone
    LDA #$01
    STA AutoPlay            ; the demo starts
AutoTrack:
    LDA BallX
    SEC
    SBC #PLAYER_CENTRE
    CMP #P0_MIN
    BCS AutoHigh
    LDA #P0_MIN
AutoHigh:
    CMP #(P0_MAX + 1)
    BCC AutoCompare
    LDA #P0_MAX
AutoCompare:
    CMP PlayerX
    BEQ MoveDone
    BCC AutoLeft
    INC PlayerX
    JMP MoveDone
AutoLeft:
    DEC PlayerX
MoveDone:

; -----------------------------------------------------------------------------
; 3. FIRE — a new press resets the score to 000000
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while the button is pressed.  PrevFire is the edge latch,
; so a held button resets once, not once per frame.
    LDA INPT4
    BMI FireReleased
    LDA PrevFire
    BNE FireDone
    LDA #$01
    STA PrevFire
    JSR ScoreClear
    JMP FireDone
FireReleased:
    LDA #$00
    STA PrevFire
FireDone:

; -----------------------------------------------------------------------------
; 4. SELECT — a new press toggles the mark
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is pressed.  The scripted demo toggle jumps
; to SelectEdge, the same path as the switch, so both use ToggleMark.
    LDA SWCHB
    AND #$02
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$01
SelectEdge:                 ; checkpoint: A = 1 on a toggle
    JSR ToggleMark
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; -----------------------------------------------------------------------------
; 5. THE SCRIPTED TOGGLE — hide the mark once, at frame 240
; -----------------------------------------------------------------------------
; The demo is in stage 1 after frame 120.  At frame 240 it calls the SELECT
; path and advances to stage 2, so the toggle cannot repeat.
    LDA AutoPlay
    CMP #$01
    BNE AutoToggleDone
    LDA Frame
    CMP #AUTO_TOGGLE
    BNE AutoToggleDone
    LDA #$02
    STA AutoPlay
    LDA #$01
    JMP SelectEdge
AutoToggleDone:

; -----------------------------------------------------------------------------
; 6. POSITION THE SCORE — one HMOVE in VBLANK
; -----------------------------------------------------------------------------
; ScoreSetup sets NUSIZ=3 and VDEL on, positions P0/P1 at 56/64, and strobes
; the one HMOVE that applies HMP0/HMP1.  The ball's stale HMBL is applied
; too, but the ball is disabled until the play kernel and is repositioned by
; the top positioner, so nothing visible moves.
    JSR ScoreSetup

; -----------------------------------------------------------------------------
; 7. THE SCORE BAND'S COLOURS AND CONTROLS
; -----------------------------------------------------------------------------
; The score digits are white; the playfield is blank during the score band.
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    LDA #C_GOLD
    STA COLUPF
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    STA GRP0
    STA GRP1
    LDA #$01
    STA CTRLPF              ; reflect the playfield; the ball is one pixel

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE LINE 0-8: THE SCORE BAND (9 lines)
; =============================================================================
; ScoreDraw consumes nine visible lines: line 0 is the setup/blank line, the
; rows are displayed on lines 1-8, and the cleanup shares line 8.  The
; library entry is the ScoreDraw checkpoint; the caller resumes on line 9.
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    JSR ScoreDraw

; =============================================================================
; VISIBLE LINE 9-13: THE TOP POSITIONER (5 lines)
; =============================================================================
; ScoreDone is visible line 9 / scanline 46.  The score's P0/P1 are at
; 56/64; the play needs P0 at PlayerX and the ball at BallX.  NUSIZ and
; VDEL are reset for one 8-pixel player; COLUP0 is red; the ball is off
; during the positioner so no stray pixel appears on line 50.
ScoreDone:                  ; checkpoint: scanline 46, visible line 9
    LDA #$00                ; NUSIZ 0 = one 8-pixel copy each
    STA NUSIZ0
    STA NUSIZ1
    LDA #$00
    STA VDELP0
    STA VDELP1
    LDA #C_PLAYER
    STA COLUP0
    LDA #C_GOLD
    STA COLUPF
    LDA #$00
    STA ENABL
    STA BallNext            ; row 0 is above the ball (BallY >= 8)

    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetGameP0           ; line 46 stall, line 47 division, ends on 48
    LDA BallX
    CLC
    ADC #(POS_BIAS + 1)     ; the ball's reset is one colour clock shorter
    JSR SetGameBall         ; line 48 stall, line 49 division, ends on 50
    STA HMOVE               ; line 50's HBLANK: apply HMP0 and HMBL
    ; The HMOVE is early in HBLANK.  Eight NOPs put the following WSYNC
    ; store at 50/25; a WSYNC parks the CPU until the HCount wrap whatever
    ; cycle it is written on, so the play band starts on line 51.
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    STA WSYNC               ; release on line 51, the first play line

; =============================================================================
; VISIBLE LINE 14-177: THE PLAY BAND (164 lines = 82 rows x 2)
; =============================================================================
; PlayStart is visible line 14 / scanline 51.  The row body stores in this
; order, which meets every pixel deadline on the steady row:
;
;   PF0       completes ~9     PF0 chunk 0: cycle 22.7
;   GRP0      completes ~16    P0's first pixel: (8+68)/3 = 25.3 (X=8)
;   PF1       completes ~23    PF1 chunk 4: cycle 28.0
;   ENABL     completes ~29    the ball's first pixel: (24+68)/3 = 30.7
;   PF2       completes ~36    PF2 chunk 12: cycle 38.7
;
; The ball's enable is a six-cycle lookahead pair (LDA BallNext + STA
; ENABL); the test for the next row runs after the PF stores, with the rest
; of the 152-cycle pair to spare.  The first WSYNC ends the work line; the
; loop tail and the second WSYNC run on the second line, and the JMP lands
; at the start of the next row's work line, so each row is exactly two
; scanlines.
; =============================================================================
; PLAYROW — one two-line row of the play band
; =============================================================================
; Y is the kernel row (0-81); it indexes P0Strip and the three PF planes.
; BallNext is the enable computed for this row by the previous row.  The
; lookahead test at the end computes the enable for row Y+1:
;
;   TYA + 1 - BallY, then CMP #4
;   carry set   -> the next row is outside the ball's four rows
;   carry clear -> the next row is inside; BallNext = 2
!macro PlayRow {
    LDA PlayPF0,Y
    STA PF0
    LDA P0Strip,Y
    STA GRP0
    LDA PlayPF1,Y
    STA PF1
    LDA BallNext
    STA ENABL
    LDA PlayPF2,Y
    STA PF2
    TYA
    CLC
    ADC #$01
    SEC
    SBC BallY
    CMP #$04
    LDA #$00
    BCS +
    LDA #$02
+
    STA BallNext
}

PlayStart:                  ; checkpoint: scanline 51, visible line 14
    LDY #$00

SkyLoop:
    +PlayRow
    STA WSYNC
    INY
    CPY #SKY_ROWS
    BEQ SkyDone
    STA WSYNC
    JMP SkyLoop
SkyDone:
    STA WSYNC
; Row 68 is the horizon: its PF bytes are $F0/$FF/$FF, the full width.
; It is part of the sky loop, so COLUPF stays gold for the horizon line.

    LDA #C_GROUND
    STA COLUPF
GroundLoop:
    +PlayRow
    STA WSYNC
    INY
    CPY #PLAY_ROWS
    BEQ GroundDone
    STA WSYNC
    JMP GroundLoop
GroundDone:
    STA WSYNC
; 82 rows x 2 lines = visible 14-177.  The last WSYNC releases the CPU on
; scanline 215, the first handover line.

; =============================================================================
; VISIBLE LINE 178-182: THE HANDOVER (5 lines)
; =============================================================================
; The handover is MarkSetup: three-copy close mode, VDEL on, gold, ball off,
; and the two players positioned at 16/24.  Each set routine is two lines;
; the fifth line carries the HMOVE.  No motion write follows it until the
; next frame's VBLANK.
HandoverStart:              ; checkpoint: scanline 215, visible line 178
MarkSetup:
    LDA #$03
    STA NUSIZ0
    STA NUSIZ1
    LDA #$01
    STA VDELP0
    STA VDELP1
    LDA #C_GOLD
    STA COLUP0
    STA COLUP1
    LDA #$00
    STA ENABL               ; the ball leaves the screen
    STA PF0                 ; the ground's full-width playfield ends here
    STA PF1
    STA PF2
    LDA #(MARK_P0_X + POS_BIAS)
    JSR SetMarkP0           ; line 215 stall, line 216 division, ends on 217
    LDA #(MARK_P1_X + POS_BIAS)
    JSR SetMarkP1           ; line 217 stall, line 218 division, ends on 219
    STA HMOVE               ; line 219's HBLANK: apply HMP0/HMP1
    ; The same store-position delay as the top positioner: the WSYNC
    ; store is at 219/25 and the mark band starts on line 220.
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    STA WSYNC               ; release on line 220, the first mark line

; =============================================================================
; VISIBLE LINE 183-191: THE MARK BAND (9 lines)
; =============================================================================
; MarkStart is visible line 183 / scanline 220.  MarkDraw consumes nine
; lines exactly like ScoreDraw: line 0 is the setup/blank line, rows 1-8 are
; the glyph rows, and the cleanup shares line 8.  When the mark is hidden,
; the same nine lines are consumed by nine WSYNCs, so the frame does not
; change.
MarkStart:                  ; checkpoint: scanline 220, visible line 183
    LDA MarkVisible
    BEQ MarkHidden
    JSR MarkDraw            ; nine lines: 220 setup, 221-228 rows
MarkDone:                   ; checkpoint: scanline 229, visible line 192
OverscanStart:              ; checkpoint: scanline 229, the first blank line
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; The hidden mark path lives after the overscan so the visible path can fall
; straight through MarkDone into OverscanStart.  It still runs during the
; mark band: MarkStart branches here, the nine WSYNCs cover 220-228, and the
; JMP returns to MarkDone at the start of line 229.
MarkHidden:
    LDA #$00
    STA GRP0                ; keep both players blank
    STA GRP1
    STA VDELP0              ; VDEL is a drawing tool, not a state
    STA VDELP1
    LDX #$09
MarkBlankLoop:
    STA WSYNC
    DEX
    BNE MarkBlankLoop
    JMP MarkDone

; =============================================================================
; SETGAMEP0 / SETGAMEBALL — two-line divide-by-15 positioning
; =============================================================================
; A = the desired left edge + POS_BIAS.  The first WSYNC starts a fresh line;
; the divide loop and the stores run on that line; the final WSYNC ends it.
; The worst case (A=147) is under 70 cycles, inside the 76-cycle line, so
; each call costs exactly two scanlines for every X.  That is what keeps
; PlayStart fixed.
SetGameP0:
    STA WSYNC
    SEC
DivGameP0:
    SBC #15
    BCS DivGameP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    STA WSYNC
    RTS

SetGameBall:
    STA WSYNC
    SEC
DivGameBall:
    SBC #15
    BCS DivGameBall
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMBL
    STA RESBL
    STA WSYNC
    RTS

; =============================================================================
; SETMARKP0 / SETMARKP1 — the mark's two-line positioning
; =============================================================================
; This is the same divide-by-15 routine as SetGameP0/SetGameBall, with the
; mark's targets.  It is a copy, not a call to the score library: ScoreSetup
; hard-codes 56/64 and the library is shared by seven earlier lessons.
SetMarkP0:
    STA WSYNC
    SEC
DivMarkP0:
    SBC #15
    BCS DivMarkP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    STA WSYNC
    RTS

SetMarkP1:
    STA WSYNC
    SEC
DivMarkP1:
    SBC #15
    BCS DivMarkP1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
    STA WSYNC
    RTS

; =============================================================================
; TOGGLEMARK — flip MarkVisible; SELECT and the demo share it
; =============================================================================
ToggleMark:
    LDA MarkVisible
    EOR #$01
    STA MarkVisible
MarkVisibleWrite:           ; checkpoint: A = the new MarkVisible (0/1)
    RTS

; =============================================================================
; MARKDRAW — the unrolled 48-pixel mark kernel
; =============================================================================
; Preconditions: MarkSetup ran (NUSIZ=3, VDEL on, P0=16, P1=24) and MarkBuf
; is page-aligned.  MarkDraw consumes NINE visible lines: line 0 is the
; setup/blank line, the eight rows are displayed on lines 1-8, and the
; cleanup shares line 8.
;
; The six stores and the seventh flush are the Lesson 39 VDEL sequence:
;
;   STA GRP0  col 0 (R)   stages R
;   STA GRP1  col 1 (A)   commits R to P0, stages A
;   STA GRP0  col 2 (C)   commits A to P1, stages C
;   STA GRP1  col 3 (I)   commits C to P0, stages I
;   STA GRP0  col 4 (N)   commits I to P1, stages N
;   STA GRP1  col 5 (G)   commits N to P0, stages G
;   STA GRP0  col 5 (G)   commits G to P1 (the seventh flush)
;
; A literal ScoreDraw clone does not work at X=16/24.  ScoreDraw's stores
; are timed for the score's copies at X=56/64, whose first pixels arrive at
; cycle (56+68)/3 = 41.3 and (64+68)/3 = 44.0.  Moving the block 40 pixels
; left moves every copy 13.3 cycles earlier: the mark's P0 copies arrive at
; cycles (16+68)/3 = 28.0, (32+68)/3 = 33.3 and (48+68)/3 = 38.7, and its
; P1 copies at 30.7, 36.0 and 41.3.  ScoreDraw's later commits land at
; cycles 44-53, after the mark's copies, so every copy would show the first
; column: the screen reads "RARARA", not "RACING".
;
; The kernel is unrolled: MarkPreload and MarkStores are expanded for the
; eight rows with fixed table addresses, so there is no loop counter or
; branch.  Each row is 15 cycles of preload, 3 for the WSYNC, and 41 of
; stores and loads = 59 cycles, well inside the 76-cycle line.  The
; GRP1/GRP0 writes that commit the six columns start at cycles 3, 9, 29,
; 32, 35 and 38 (write cycles 5, 11, 31, 34, 37 and 40).  The C commit at
; write 31 (CLK 93) sits in the gap between P0 copy 0 (CLK 84-91) and P0
; copy 1 (CLK 100-107); the later commits at CLK 102, 111 and 120 keep
; 6/5/4 CLK of margin before the P1 copy 1, P0 copy 2 and P1 copy 2
; windows.  That removes the C-to-R bleed and keeps every column on its
; own copy.
;
; The delay before the cleanup is the line-count adjustment: nine NOPs
; and a three-cycle BIT Frame.  Without it the unrolled kernel returns on
; line 229 too early; with it the cleanup's RTS spills onto scanline 229 at
; cycle 6, so the mark band still covers nine lines and the frame stays 262.

!macro MarkPreload .r {
    LDA MarkBuf+16+.r
    STA MarkTmp
    LDA MarkBuf+0+.r
    LDX MarkBuf+8+.r
}
!macro MarkStores .r {
    STA GRP0
    STX GRP1
    LDA MarkTmp
    STA GRP0
    LDY MarkBuf+32+.r
    LDA MarkBuf+24+.r
    LDX MarkBuf+40+.r
    BIT Frame
    NOP
    STA GRP1
    STY GRP0
    STX GRP1
    STX GRP0
}

MarkDraw:
    +MarkPreload 7
    STA WSYNC
MarkDrawRow:
    +MarkStores 7
    +MarkPreload 6
    STA WSYNC
    +MarkStores 6
    +MarkPreload 5
    STA WSYNC
    +MarkStores 5
    +MarkPreload 4
    STA WSYNC
    +MarkStores 4
    +MarkPreload 3
    STA WSYNC
    +MarkStores 3
    +MarkPreload 2
    STA WSYNC
    +MarkStores 2
    +MarkPreload 1
    STA WSYNC
    +MarkStores 1
    +MarkPreload 0
    STA WSYNC
    +MarkStores 0

    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    BIT Frame
    LDA #$00
    STA GRP0
    STA GRP1
    STA VDELP0
    STA VDELP1
    RTS


; =============================================================================
; THE MARK TABLE — six 5x7 glyphs in 8x8 cells, column-major, bottom-up
; =============================================================================
; Column c, row r is MarkBuf + c*8 + r.  Byte 0 of every glyph is $00, so
; the lit block is seven rows (visible 184-190).  Bit 7 is the leftmost
; pixel.  The table is page-aligned: LDA MarkBuf+n,Y never crosses a page,
; so every load is four cycles; the mark kernel's store schedule assumes it.
; The glyphs are the original course word RACING, not any publisher's mark.
    !align 255, 0
MarkBuf:
    ; column 0: R
    !byte $00, $88, $90, $A0, $F0, $88, $88, $F0
    ; column 1: A
    !byte $00, $88, $88, $88, $F8, $88, $88, $70
    ; column 2: C
    !byte $00, $70, $88, $80, $80, $80, $88, $70
    ; column 3: I
    !byte $00, $F8, $20, $20, $20, $20, $20, $F8
    ; column 4: N
    !byte $00, $88, $88, $88, $98, $A8, $C8, $88
    ; column 5: G
    !byte $00, $70, $88, $88, $B8, $80, $88, $70

; =============================================================================
; THE PLAY BAND'S PLAYFIELD PLANES — one byte per two-line row
; =============================================================================
; The three planes are page-aligned, so LDA PlayPFx,Y never crosses a page.
; The bytes change only at band boundaries:
;
;   rows  0- 1  star band A   PF1=$20 (chunk 6)
;   rows  2-15  dark sky
;   rows 16-17  star band B   PF1=$04 (chunk 9)
;   rows 18-31  dark sky
;   rows 32-33  star band C   PF2=$08 (chunk 15)
;   rows 34-47  dark sky
;   rows 48-49  star band D   PF1=$40 (chunk 5), PF2=$02 (chunk 13)
;   rows 50-67  dark sky
;   row  68     the horizon  PF0=$F0, PF1=PF2=$FF (full width)
;   rows 69-81  the ground   the same full-width bytes
;
; CTRLPF=$01 reflects the playfield, so every star and the horizon appear in
; both halves.  COLUPF is gold in the sky and on the horizon; the ground is
; dark green.  The one-pixel ball shares COLUPF, so it is gold in the sky
; and green on the ground — the blend near the catch is deliberate.
    !align 255, 0
PlayPF0:
    !fill 68, $00           ; rows 0-67: the sky has no PF0 star bits
    !fill 14, $F0           ; rows 68-81: the horizon and the ground

    !align 255, 0
PlayPF1:
    !byte $20, $20          ; rows 0-1: star band A
    !fill 14, $00           ; rows 2-15: dark sky
    !byte $04, $04          ; rows 16-17: star band B
    !fill 14, $00           ; rows 18-31: dark sky
    !fill 2, $00            ; rows 32-33: star band C uses PF2
    !fill 14, $00           ; rows 34-47: dark sky
    !byte $40, $40          ; rows 48-49: star band D
    !fill 18, $00           ; rows 50-67: dark sky
    !fill 14, $FF           ; rows 68-81: the horizon and the ground

    !align 255, 0
PlayPF2:
    !fill 2, $00            ; rows 0-1: star band A uses PF1
    !fill 14, $00           ; rows 2-15: dark sky
    !fill 2, $00            ; rows 16-17: star band B uses PF1
    !fill 14, $00           ; rows 18-31: dark sky
    !byte $08, $08          ; rows 32-33: star band C
    !fill 14, $00           ; rows 34-47: dark sky
    !byte $02, $02          ; rows 48-49: star band D
    !fill 18, $00           ; rows 50-67: dark sky
    !fill 14, $FF           ; rows 68-81: the horizon and the ground

; =============================================================================
; THE PLAYER'S STRIP — one byte per two-line row
; =============================================================================
; The player is eight kernel rows (16 scanlines) tall at rows 72-79, so the
; feet sit two rows above the bottom of the field.  The top row is solid:
; the falling ball meets the player's head anywhere across the 8-pixel body,
; which is what makes the auto-demo's catch repeatable.  Every other row is
; blank.  The strip is page-aligned for a four-cycle LDA.
    !align 255, 0
P0Strip:
    !fill PLAYER_TOP, $00
    !byte $FF, $3C, $3C, $18, $7E, $5A, $5A, $18
    !fill (PLAY_ROWS - PLAYER_TOP - PLAYER_ROWS), $00

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreInit, ScoreClear, ScoreSetup, ScoreSetDigit, ScoreAddOne, ScoreDraw,
; and ScoreFont live here.  The library must be sourced inside the ROM area
; (after * = $F000) and after include/vcs.asm.  Its ScoreSetup is the
; 56/64 routine; the mark has its own MarkSetup above.
    !source "include/score.asm"

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
> `lessons/part11-legendary/79-publisher-mark/79-publisher-mark.asm`.

### Code Walkthrough

#### Step 1 — The frame skeleton

The frame is the same 3 + 37 + 192 + 30 skeleton as Lessons 39 and 50:

```asm
StartFrame:
    +vsync
VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    INC Frame
    ; ... game logic ...
    +wait_timer
    LDA #$00
    STA VBLANK
BodyStart:
    JSR ScoreDraw
```

`+vsync` takes the three VSYNC lines and leaves `VblankStart` at 0/5. `+set_timer 44` covers the 37 VBLANK lines. The game logic (collision, ball, player, fire, SELECT, the auto-demo toggle) runs in VBLANK, then `ScoreSetup` positions the score. `+wait_timer` returns at 37/0, `STA VBLANK` turns the picture on, and `BodyStart` is at 37/5.

The overscan timer is written once:

```asm
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame
```

`+wait_timer` returns at the end of the 30-line overscan, `StartFrame` measures 259/3, and the frame is 262. An earlier build measured 257/3 because the old mark cleanup returned before scanline 229; the unrolled kernel's cleanup delay fixes the overscan entry.

#### Step 2 — The collision, the ball, and the player

`CXP0FB` bit 6 is the P0–ball latch. It is read in the next VBLANK, so a catch is one frame late by construction:

```asm
    LDA CXP0FB
    AND #$40
    BEQ NoHit
    JSR ScoreAddOne
    LDA ScoreOnes
ScoreWrite:
Hit:
    LDA #BALL_START_Y
    STA BallY
    LDA BallX
    CMP #$50
    BCS HitLeft
    LDA #$68
    JMP HitStoreX
HitLeft:
    LDA #$38
HitStoreX:
    STA BallX
    JMP HitDone
```

`ScoreAddOne` adds one with a decimal carry. `ScoreOnes` is `ScoreDigits+5`, the visible score's rightmost digit; the `ScoreWrite`/`Hit` checkpoint reports it. The new X alternates between 56 and 104. Once the demo is running (`AutoPlay=1` after 120 frames), the one-pixel-per-frame player can reach either X before the star lands; the first respawn at X=56 (frame 63) is missed because the demo has not started. The second catch is frame 188, and the 62-frame cadence starts there. `CXCLR` clears the latch after the read.

The player moves from `SWCHA` bits 6/7 (active low: left reads `$80` after `AND #$C0`, right reads `$40`) or from the auto-demo. After 120 idle frames `AutoPlay=1`; the player seeks `BallX-3`, which puts the star over the player's left-centre. The player's top strip row is solid `$FF`, so the catch is repeatable even if the player is one pixel off the aim.

#### Step 3 — The top positioner and the play band

`ScoreDone` is line 46. The top positioner resets `NUSIZ` to 0 (one 8-pixel copy each; `NUSIZ=1` would draw two), clears VDEL, sets `COLUP0` red, and leaves the ball disabled:

```asm
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetGameP0
    LDA BallX
    CLC
    ADC #(POS_BIAS + 1)
    JSR SetGameBall
    STA HMOVE
    NOP
    ; ... eight NOPs ...
    STA WSYNC
```

`SetGameP0` and `SetGameBall` each start with a WSYNC and end with a WSYNC, so each costs exactly two lines. The HMOVE is on line 50. The eight NOPs put the following WSYNC store at 50/25; a WSYNC parks the CPU until the HCount wrap, so `PlayStart` is on line 51.

The play band is 82 rows × 2 lines. The `PlayRow` macro writes the player, the ball enable, and the three PF planes:

```asm
!macro PlayRow {
    LDA PlayPF0,Y
    STA PF0
    LDA P0Strip,Y
    STA GRP0
    LDA PlayPF1,Y
    STA PF1
    LDA BallNext
    STA ENABL
    LDA PlayPF2,Y
    STA PF2
    TYA
    CLC
    ADC #$01
    SEC
    SBC BallY
    CMP #$04
    LDA #$00
    BCS +
    LDA #$02
+
    STA BallNext
}
```

The band loop puts the loop tail on the second line:

```asm
SkyLoop:
    +PlayRow
    STA WSYNC
    INY
    CPY #SKY_ROWS
    BEQ SkyDone
    STA WSYNC
    JMP SkyLoop
SkyDone:
    STA WSYNC
```

The steady row's stores complete at about 9 (PF0), 16 (GRP0), 23 (PF1), 29 (ENABL) and 36 (PF2). The deadlines are PF0 chunk 0 at 22.7, the player at 25.3 (X=8), PF1 chunk 4 at 28.0, the ball at 30.7 (X=24), and PF2 chunk 12 at 38.7. The ball enable is a six-cycle lookahead pair (`LDA BallNext` + `STA ENABL`); the test for the next row runs after the PF stores. The first WSYNC ends the work line; the `INY`/`CPY`/`BEQ` loop tail and the second WSYNC run on the second line, and the `JMP` lands at the start of the next row's work line. The first play row starts two cycles after `PlayStart` because `BallNext` and the sky `COLUPF` are set after the positioner; the first ground row has a five-cycle `COLUPF` setup, but its PF1/PF2 values are the horizon's, so the lag is invisible. The horizon and the ground are full-width in the capture.

The playfield planes are page-aligned and sparse: four two-row star bands, a dark sky, a full-width gold horizon on row 68, and a dark-green ground on rows 69–81. `CTRLPF=$01` reflects the playfield, so every star and the horizon appear in both halves. The ball shares `COLUPF`: it is gold in the sky and green on the ground, so it blends near the catch. That is the one-colour playfield/ball trade-off, and it is deliberate.

#### Step 4 — The handover

`HandoverStart` is line 215. `MarkSetup` sets three-copy close mode, VDEL on, gold, and the ball off, then calls the two two-line positioners:

```asm
    LDA #$03
    STA NUSIZ0
    STA NUSIZ1
    LDA #$01
    STA VDELP0
    STA VDELP1
    LDA #C_GOLD
    STA COLUP0
    STA COLUP1
    LDA #$00
    STA ENABL
    LDA #(MARK_P0_X + POS_BIAS)
    JSR SetMarkP0
    LDA #(MARK_P1_X + POS_BIAS)
    JSR SetMarkP1
    STA HMOVE
    NOP
    ; ... eight NOPs ...
    STA WSYNC
```

The handover is five lines: 215 (P0's WSYNC), 216 (P0's divide), 217 (P1's WSYNC), 218 (P1's divide), 219 (HMOVE and the wait). The HMOVE's blanking is on 219, not on the mark. `MarkStart` is 220.

#### Step 5 — The mark kernel

`MarkDraw` is the heart of the lesson. It unrolls the eight rows and keeps the Lesson 39 store order:

```asm
!macro MarkPreload .r {
    LDA MarkBuf+16+.r
    STA MarkTmp
    LDA MarkBuf+0+.r
    LDX MarkBuf+8+.r
}
!macro MarkStores .r {
    STA GRP0
    STX GRP1
    LDA MarkTmp
    STA GRP0
    LDY MarkBuf+32+.r
    LDA MarkBuf+24+.r
    LDX MarkBuf+40+.r
    BIT Frame
    NOP
    STA GRP1
    STY GRP0
    STX GRP1
    STX GRP0
}

MarkDraw:
    +MarkPreload 7
    STA WSYNC
MarkDrawRow:
    +MarkStores 7
    +MarkPreload 6
    STA WSYNC
    +MarkStores 6
    ; ... rows 5 down to 0 ...
```

Each row is 15 cycles of preload, 3 for the WSYNC, and 41 of stores and loads = 59 cycles. The `BIT Frame`/`NOP` pair is the five-cycle delay before the C commit; it puts the C commit at write cycle 31 (CLK 93), in the gap between P0 copy 0 and P0 copy 1. The later commits are at CLK 102, 111 and 120, with 6/5/4 CLK of margin before the copy-1 and copy-2 windows. The `MarkDrawRow` checkpoint is at 221/0 on the first row (the logger reports the first store one line early because it immediately follows a WSYNC; the later rows report the true line). The eight rows are 221–228. The cleanup blanks GRP0/GRP1, clears VDEL, and the delay before it (nine NOPs and `BIT Frame`) puts `MarkDone`/`OverscanStart` at 229/6.

If `MarkVisible=0`, the band still consumes nine lines: the hidden path clears PF/GRP0/GRP1/VDEL and waits nine WSYNCs, then jumps to `MarkDone`. The frame stays 262.

#### Step 6 — Input, SELECT, and the scripted toggle

`SWCHA` bits 6/7 move the player; `INPT4` bit 7 resets the score with `ScoreClear` on a new press; `SWCHB` bit 1 toggles `MarkVisible` on a new press. The auto-demo uses the same toggle path:

```asm
    LDA AutoPlay
    CMP #$01
    BNE AutoToggleDone
    LDA Frame
    CMP #AUTO_TOGGLE
    BNE AutoToggleDone
    LDA #$02
    STA AutoPlay
    LDA #$01
    JMP SelectEdge
AutoToggleDone:
```

At the VBLANK whose `Frame` value is 240 (the 241st frame; Stella's breakpoint hit counter reads 241) the demo sets `AutoPlay=2` and jumps to `SelectEdge`; `ToggleMark` flips `MarkVisible` from 1 to 0 and the next frame takes the hidden path. The stage byte makes the toggle happen once. The first capture at about 3 seconds is before the toggle; the second at about 6 seconds is after it.

#### Step 7 — Reading it back in Stella

Assemble with a symbol file and ask Stella for the checkpoints:

```bash
acme -f plain -l build/lesson79.sym -o build/lesson79.bin \
  lessons/part11-legendary/79-publisher-mark/79-publisher-mark.asm
grep -E "StartFrame|VblankStart|BodyStart|ScoreDone|PlayStart|HandoverStart|MarkStart|MarkDone|OverscanStart|ScoreWrite|SelectEdge|MarkVisibleWrite|BallYRead|PlayerXRead" build/lesson79.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F04D' docs/public/roms/part11-legendary/79-publisher-mark/79-publisher-mark.bin
```

Run each checkpoint separately for a readable log. The addresses below are the ones this source produced. A breakpoint on a label reports the cycle at the instruction; a label immediately after a WSYNC reports the WSYNC's line (one line early), which is why `PlayStart` and `MarkStart` show 50/28 and 219/28 in the log but their real lines are 51 and 220 (confirmed by `SkyLoop` at 51/12 and `MarkDraw` at 220/11).

### Checkpoints

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F04D` | 259/3 | the first VSYNC line |
| `VblankStart` | `$F05B` | 0/5 | the first VBLANK line |
| `BodyStart` | `$F169` | 37/5 | visible line 0 |
| `ScoreDone` | `$F16C` | 46/5 | visible line 9, the first positioner line |
| `PlayStart` | `$F1A2` | 51 (log 50/28) | visible line 14, the first play line |
| `HandoverStart` | `$F216` | 215 (log 214/10) | visible line 178, the first handover line |
| `MarkStart` | `$F248` | 220 (log 219/28) | visible line 183, the first mark line |
| `MarkDone` | `$F24F` | 229/6 | visible line 192, the first overscan line |
| `OverscanStart` | `$F24F` | 229/6 | the same line, the overscan entry |
| `ScoreDraw` | `$FA08` | 37/11 | the score kernel's entry |
| `MarkDraw` | `$F2CD` | 220/11 | the mark kernel's entry |
| `MarkDrawRow` | `$F2DA` | 221/0 (first store logged 220/29) | the first row's stores |
| `ScoreWrite` / `Hit` | `$F071` | A=1 at frame 63, A=2 at 188, A=3 at 250, … | the new rightmost score digit |
| `SelectEdge` | `$F11C` | A=1 at frame 241 | the scripted (and SELECT) toggle |
| `MarkVisibleWrite` | `$F2CC` | A=0 at frame 241 | the new `MarkVisible` |
| `PlayerXRead` | `$F0AC` | A=76, 75, 74, … under `-holdjoy0 L` | the player's X on the manual left branch |
| `BallYRead` | `$F089` | A=8, 9, 10, … | the ball's top row before the fall |

The frame log: `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `ScoreDone` 46/5, `PlayStart` 51, `HandoverStart` 215, `MarkStart` 220, `MarkDone` 229/6, `OverscanStart` 229/6. The play and handover labels follow a WSYNC, so the logger reports their stores one line early: `SkyLoop` hits 51/2, `HandoverStart` reports 214/10 with the next instruction at 215/2, and `MarkDraw` hits 220/11. The visible ledger is 9 + 5 + 164 + 5 + 9 = 192; 229 − 37 = 192; 3 + 37 + 192 + 30 = 262.

The state log: `ScoreWrite`/`Hit` reports A=1 at hit 63, A=2 at 188, A=3 at 250, A=4 at 312, A=5 at 374, A=6 at 436, A=7 at 498, A=8 at 560. The first catch is 63 (the player starts under the star); the first respawn at X=56 is missed because `AutoPlay` does not turn on until frame 120; the second catch is 188, and the 62-frame cadence starts there (188, 250, 312, …). The star falls from row 8 to row 70 in 62 frames.

`SelectEdge` reports A=1 at hit 241; `MarkVisibleWrite` reports A=0 at the same hit. The source compares `Frame` to `AUTO_TOGGLE=240` in VBLANK, so the toggle is the 240-value frame; Stella's hit counter is one-based and reads 241. The next frame takes the hidden path; in the hidden state `StartFrame` still reads 259/3 (the 9-WSYNC hidden band keeps the frame at 262). `PlayerXRead` reports A=76, 75, 74, … with `-holdjoy0 L`; `BallYRead` reports 8, 9, 10, …

## What You Should See

At power-on the screen is dark. The score band at the top reads `000000` in white (then `000001` after the first catch). Below it, the play band has a dark sky with four sparse gold star bands, a full-width gold horizon line, and a full-width dark-green ground. A red 8×16 player stands at TIA X=76, and a one-pixel gold star falls from row 8. The star is eight scanlines tall, so it looks like a short vertical dash. The bottom band is the gold `RACING` mark at TIA X=16–63, seven lit rows tall.

The 8-pixel black notch at the left edge of visible lines 13 and 182 (scanlines 50 and 219) is the HMOVE blanking. It falls on the blank positioner and handover lines, not on the play band or the mark.

![Stella running Lesson 79: the white 000001 score, the gold star bands, the red player on the green ground, the falling gold star, and the gold RACING mark at the bottom-left; the title bar reads Stella 7.0: "79-publisher-mark"](/images/lesson79/game.png)

*`game.png`: about 3 seconds after power-on. The score is `000001` (the first catch at frame 63). The white score block is TIA X=56–103, visible 1–7. The red player is a single 8-pixel copy at TIA X≈61 (the auto-demo has started tracking), visible 158–173. The gold ball is at TIA X≈60, visible 99–106. The gold `RACING` mark is TIA X=16–63, visible 184–190. The four star bands and the full-width gold horizon are the playfield; the ground is the dark-green band below the horizon.*

<RomPlayer rom="/roms/part11-legendary/79-publisher-mark/79-publisher-mark.bin" title="Lesson 79 — The Publisher Mark" />

*Javatari starts muted; this ROM is silent.*

At the frame-240 script the auto-demo toggles the mark. SELECT does the same thing. The second capture is after the toggle: the score has climbed to `000003` (the fourth catch is at frame 312, after this capture), the player and star have moved, and the mark band is blank. The rest of the screen is unchanged.

![Stella running Lesson 79 with the mark hidden: the score 000003, the star bands, the ground, and the red player; the bottom band is blank; the title bar reads Stella 7.0: "79-publisher-mark"](/images/lesson79/no-mark.png)

*`no-mark.png`: about 6 seconds after power-on, after the frame-240 toggle. The score is `000003`; the mark band is empty. The white score block is still TIA X=56–103, visible 1–7. The player has moved to TIA X≈78 as the auto-demo tracks the next star. The frame is still 262 lines; `MarkVisible=0` only skips the mark draw and blanks the band.*

The two TIA-area images are different states, not two copies of one frame: the score digit, the player's X, and the ball's row all change.

> **Capture method.** Both images are `scripts/capture-screenshot.sh` captures of the committed
> `docs/public/roms/part11-legendary/79-publisher-mark/79-publisher-mark.bin` on display `:0`
> (the mutter window manager supplies the title bar) at three and six wall-clock seconds, with
> `xdotool mousemove 0 0` before each. The auto-demo timer starts at power-on and the demo takes over at frame 120, so the frame
> sequence is deterministic: the first catch is frame 63, the toggle is the `Frame=240` VBLANK.
> The emulator's start-up takes a fraction of a second, so the 3-second image is about frame
> 120–170 (visible mark, score 1) and the 6-second image is about frame 280–320 (hidden mark,
> score 3). All images are 1010×807, carry the window frame and the
> `Stella 7.0: "79-publisher-mark"` title bar, and show no cursor.

The **pixel check** of the two images:

| Image | Size | Title bar | What the pixels show |
|---|---|---|---|
| `game.png` | 1010×807 | `Stella 7.0: "79-publisher-mark"` | TIA area 960×606 at (25,106); the white score at x=367–642, y=110–130 (`000001`); the gold mark at x=121–390, y=687–708 (the block is x=121–409, TIA 16–63, visible 184–191); the red player at x=391–438, y=605–654 (TIA X≈61); the full-width gold horizon at y=580–584, x=25–984; the star bands at four heights; no cursor |
| `no-mark.png` | 1010×807 | `Stella 7.0: "79-publisher-mark"` | the white score at x=367–642, y=110–130 (`000003`); **no gold pixels** in the mark band y=680–715; the red player at x=493–540, y=605–654 (TIA X≈78); the full-width horizon and ground unchanged; no cursor |

The **mark table check** compares the 48-byte `MarkBuf` to the captured mark. The six 8×8 cells decode to the glyphs R, A, C, I, N, G; the host-rendered 48×8 bitmap and the capture match at all 384 pixels (**0 mismatches**). The C commit at write 31 (CLK 93) is in the gap between P0 copy 0 and P0 copy 1; it no longer bleeds the C glyph into the R cell. The R's fifth pixel is at table rows 1, 5 and 6, and the capture matches it. The score block is a separate check: its white pixels span x=367–642, y=110–130, which is TIA X=56–103, visible 1–7.

The **play band check** confirms the reordered stores: the gold horizon at y=580–584 spans x=25–984 (960 capture pixels, the full 160-TIA-pixel width), and the first star band's left run is x=169–192 (TIA X=24–27), with its reflection at x=817–840. The PF0/PF1/PF2 stores are early enough for the chunk deadlines; the horizon/ground no longer lose their left half.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
ROM=docs/public/roms/part11-legendary/79-publisher-mark/79-publisher-mark.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F04D' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F169' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1A2' $ROM   # PlayStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F216' $ROM   # HandoverStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F248' $ROM   # MarkStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F24F' $ROM   # MarkDone/Overscan
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F071' $ROM   # ScoreWrite/Hit
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F11C' $ROM   # SelectEdge
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F2CC' $ROM   # MarkVisibleWrite
```

- **`$F04D` (`StartFrame`)** is **259/3**, **`$F05B` (`VblankStart`)** **0/5**, **`$F169` (`BodyStart`)** **37/5**, **`$F16C` (`ScoreDone`)** **46/5**, **`$F216` (`HandoverStart`)** **215** (log 214/10; the next instruction is 215/2), and **`$F24F` (`MarkDone`/`OverscanStart`)** **229/6**. The play line is **51** (`SkyLoop` 51/2) and the mark line is **220** (`MarkDraw` 220/11).
- **`$F071` (`ScoreWrite`/`Hit`)** reports A=1 at hit 63, A=2 at 188, A=3 at 250, A=4 at 312, A=5 at 374, A=6 at 436, A=7 at 498, A=8 at 560. The first respawn is missed because the demo starts at 120; the second catch is 188, and the 62-frame cadence starts there.
- **`$F11C` (`SelectEdge`)** reports A=1 at hit 241; **`$F2CC` (`MarkVisibleWrite`)** reports A=0 at the same hit. The source's `Frame=240` VBLANK is the 241st frame in Stella's one-based hit counter.
- **`$F0AC` (`PlayerXRead`)** reports 76, 75, 74, … under `-holdjoy0 L`; **`$F089` (`BallYRead`)** reports 8, 9, 10, … one row per frame. In the hidden state `StartFrame` stays 259/3.

The screenshots prove the visual state; the state log proves the values and the clock. The thing a still cannot prove is the mark toggle: `SelectEdge` and `MarkVisibleWrite` prove the 1→0 transition at hit 241, and the two captures prove the two states. The 62-frame catch cadence is the `ScoreWrite` sequence after the second catch.

## Exercises

Each exercise ships a complete 4,096-byte `exercise-NN-solution.asm`. The solutions assemble through `npm run roms`, run in Stella, and actually solve the exercise as written.

### Exercise 1: A Ten-Letter 4×7 Mark

**Challenge:** Replace the six 5×7 glyphs with a ten-letter wordmark in a 4×7 font, packed two letters per 8-pixel cell. The wordmark must fit in 40–48 pixels, the table must stay 48 bytes, and the frame must stay 262 lines.

**Hints:**
1. A cell is 8 pixels wide. Use bits 7–4 for the left letter and bits 3–0 for the right letter. Each 4-pixel glyph row is a nibble.
2. Ten letters need five cells (RA, CI, NG, BE, AM) = 40 pixels. The sixth cell is blank.
3. Byte 0 of every cell stays `$00`, so the lit block is still seven rows. Keep the table page-aligned; the unrolled `MarkDraw` reads the same 48 bytes.
4. The word RACINGBEAM uses R, A, C, I, N, G, B, E, A, M; all are in the 4×7 font in the solution.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; the mark reads `RACINGBEAM` across 40 pixels (five cells); the table is 48 bytes; `StartFrame` is 259/3 and `MarkDone`/`OverscanStart` is 229/6; the frame is 262.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Move the Mark

**Challenge:** Move the mark from the bottom-left to the bottom-right (P0=96, P1=104) or the bottom-centre (P0=56, P1=64). The mark must render correctly, and the frame must stay 262 lines.

**Hints:**
1. The mark kernel is position-sensitive. The bottom-left kernel's store schedule is tuned for the copies at X=16/24; the score's literal `ScoreDraw` schedule is tuned for X=56/64. Moving the mark to the centre lets the literal clone work; moving it to the right needs a different kernel.
2. The centre position spans TIA X=56–103, the score's own block. Change `MARK_P0_X` to 56 and `MARK_P1_X` to 64, and use the literal six-store clone with the NOP and `CPX MarkRow`.
3. The handover's divide-by-15 routines take the same two lines for 56/64 as for 16/24, so the frame and the band boundaries do not change.
4. The bottom-right option (96/104) would need the commit cycles moved later by 26.7 cycles; the row's 76 cycles do not leave room for the same six-store schedule without a different kernel.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; the mark appears at the bottom-centre, TIA X=56–103, visible 184–190; `StartFrame` is 259/3; `MarkDone`/`OverscanStart` is 229/5 (the literal clone's cleanup returns one cycle earlier than the lesson's unrolled kernel); the frame is 262. The solution takes the centre option and documents why the bottom-right option needs a different kernel.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The Playfield Mark *(Stretch Goal)*

**Challenge:** Draw the mark with PF0/PF1/PF2 in the bottom eight lines instead of the players. Use a blockier 4-pixel mark, keep the players free, use a 24-byte PF table, and keep the frame at 262 lines.

**Hints:**
1. The playfield is 20 chunks per half, 4 pixels per chunk. A 12-chunk pattern is 48 pixels wide. Use PF0 for chunks 0–3 — **bit 4 is chunk 0, not bit 7** — and PF1 for chunks 4–11; PF2 stays 0.
2. `CTRLPF=$02` is SCORE mode: the left half uses `COLUP0` and the right half `COLUP1`. Set `COLUP0=$1A` (gold) and `COLUP1=$02` (background), so only the left-half mark is visible.
3. The table is 8 rows × 3 bytes: `MarkPF0`, `MarkPF1`, `MarkPF2`. Row 0 is blank, rows 1–7 are the letters. Write each row's PF bytes before the playfield's first chunk (cycle 22.7).
4. The PF stores end early in the line. Three NOPs put the row's WSYNC at a known store position; a WSYINC parks the CPU until the HCount wrap whatever cycle it is written on, so each row still takes one scanline.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; the bottom eight lines show a blocky four-letter `RACE` mark at TIA X=0–47, 48 pixels wide; the players are blank and free; the PF table is 24 bytes; `StartFrame` is 259/3, `MarkDone`/`OverscanStart` is 229/7, and the frame is 262. The mark is hidden by the same SELECT/auto-demo path; the hidden band is blank.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **The frame is a budget.** 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262; the visible area is 9 score + 5 positioner + 164 play + 5 handover + 9 mark. Every band boundary is a scanline, not a suggestion.
- ✅ **The 48-pixel window is six player copies.** P0 at X and P1 at X+8, both in three-copy close mode, interleave into six 8-pixel cells across 48 pixels. The score uses 56/64; the mark uses 16/24.
- ✅ **The kernel's store schedule is position-sensitive.** A literal `ScoreDraw` clone at X=16/24 commits its later columns after the mark's copies and draws `RARARA`. Moving the block 40 pixels left moves every copy 13.3 cycles earlier; the mark kernel unrolls the eight rows and keeps the six stores and the VDEL order; the commits are at write cycles 5, 11, 31, 34, 37 and 40, with the C commit at 31 (CLK 93) in the P0 copy-0/copy-1 gap.
- ✅ **A static mark belongs in ROM.** The score changes, so its 48 columns live in RAM; the mark never changes, so its 48 bytes live in ROM. The table is page-aligned: `LDA abs,Y` costs one more cycle on a page cross, and one cycle shifts a column.
- ✅ **Three HMOVEs share one frame.** The score's HMOVE is in VBLANK, the game's is on line 50, and the mark's is on line 219. Each is in a blank HBLANK, each is followed by more than 24 cycles before the next motion write, and no motion register is touched in the play or the mark band.
- ✅ **The handover is the second positioner.** The players are shared, so the five-line handover moves them from 56/64 to 16/24 and turns the ball off. A WSYNC parks the CPU until the HCount wrap whatever cycle it is written on; the eight NOPs are a store-position device (50/25 and 219/25).
- ✅ **The mark is an independent screen element.** SELECT toggles `MarkVisible`; the hidden path still consumes the nine lines, so the frame stays 262 and the score and play are untouched. The mark is original `RACING`; the Activision history is context, not a template.

## What's Next

This is one of the first published lessons of Part 11: Lesson 73 (the HMOVE comb and the Cosmic Ark starfield) and this Lesson 79 are live; Lessons 74–78 — skipdraw, the pseudo-3D road, procedural worlds, interlaced flicker, and the Adventure room engine — remain coming soon. [The Part 11 index](/part11-legendary/) lists the anthology.
