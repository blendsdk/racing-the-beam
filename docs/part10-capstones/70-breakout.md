---
title: "Lesson 70: Capstone 2 — Breakout"
description: "Build a complete Breakout: a 48-line brick field, a 64-entry x 3-byte playfield table, per-brick collision through CXBLPF, a 32-byte play row table driving the 128-line play area, the shared score library with the P0/P1 repositioning sequence, three lives, three patterns, and a zone kernel that keeps the ball visible in both the brick field and the play area. The lesson proves the frame with Stella state logs and the brick math with a static table check."
prev:
  text: "Lesson 69: Capstone 1 — Pong"
  link: "/part10-capstones/69-pong"
next:
  text: "Lesson 71: Capstone 3 — Maze Explorer"
  link: "/part10-capstones/71-maze-explorer"
---

# Lesson 70: Capstone 2 — Breakout

> **Part 10: Capstone Projects** · Estimated time: 180 minutes
> **Prerequisites:** Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and memory), Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players), Lesson 26 (horizontal positioning), Lesson 29 (the ball), Lesson 31 (`NUSIZ`), Lesson 33 (controllers), Lesson 38 (collision detection), Lesson 39 (the scoreboard and the score library), Lesson 41 (game states), Lesson 49 (the two-line kernel), Lesson 50 (the multi-zone kernel), Lesson 69 (the row table)
> **You will learn:** how a 48-line brick field is a playfield pattern generated from a 6-byte brick map and a 64-entry × 3-byte PF table; how the ball's centre and `(BallY - 15) / 8` select one unique brick and clear one mask bit; how reflect mode mirrors six unique bricks to twelve visible ones; how the ball is drawn in both the brick field and the play area; how the shared score library and the paddle share P0 and survive with one repositioning `HMOVE`; how three lives, three patterns, and a speed-up per level fit the same state machine; and how a deterministic auto-demo makes the captures reproducible.
> **You will build:** **Breakout**, a complete 4,096-byte ROM: a 48-line brick field (6 rows of 12 visible bricks), an 8×8 green paddle on the bottom, a 4×4 white ball, per-brick removal, a six-digit score, three lives, three brick patterns, a faster ball each level, and a deterministic auto-demo. The three exercise solutions add multi-hit bricks, a level-clear banner with a level display, and a wide-paddle/2×-score power-up.

## Introduction

Pong taught the capstone's first lesson: a moving object's vertical position is a per-frame decision, so precompute the whole screen's object layout in VBLANK and let the visible kernel read a table. Breakout adds the piece Pong did not need: **a field**. The bricks are not sprites; they are the playfield, the TIA's chunky 20-bit-per-half pattern generator. A field changes the kernel's shape. The brick zone is a playfield kernel — a pattern is loaded once per 8-line brick row, and the ball is a sprite drawn on top of it. The play zone is Pong's row-table kernel again. The two zones meet at picture line 63, and the ball has to cross the border.

The brick field is also where the lesson's central arithmetic lives. Six unique bricks per half, each 8 pixels wide with a 4-pixel gap, mirrored by reflect mode into twelve visible bricks. The brick map is **6 bytes**, one 6-bit mask per row. The PF bytes for any mask come from a **64-entry × 3-byte table** — 192 ROM bytes that turn a mask into `PF0`/`PF1`/`PF2` without a loop in the kernel. When the ball hits a brick, the collision handler has to answer two questions from the ball's position alone: *which row* (`(BallY - 15) / 8`) and *which unique column* (`(centre - 8) / 12` on the left, `5 - ((centre - 80) / 12)` on the right). Clear the mask bit, add one to the score, and the next frame's brick kernel draws one fewer brick.

The companion program, `70-breakout.asm`, is a complete Breakout in 4,096 bytes. Its screen is 9 score lines + 1 blank + 5 positioner + 48 brick + 128 play + 1 blank = 192. Its frame is the course standard 3 + 37 + 192 + 30 = 262, measured as `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `ScoreDone` 46, `BrickStart` 51, `PlayStart` 99, `OverscanStart` 229. Its RAM map is exact: `$80-$85` the brick map, `$86-$91` the ball's brick-row table, `$92-$9F` fourteen game variables, `$A0-$D7` the score library, `$D8-$F7` the 32-byte play row table, `$F8-$FF` the stack.

The score is the shared library this time, not Pong's custom digit pair. That creates a P0/P1 conflict: `ScoreSetup` puts P0 at TIA X=56 and P1 at X=64 in three-copy mode; the paddle needs P0 at `PaddleX`. The sequence is: call `ScoreSetup` every frame in VBLANK, draw `ScoreDraw` first in the body, then reposition P0 with a second `HMOVE` (the ball was positioned in VBLANK and the score's `HMOVE` applied it). The score's white is restored on the blank line at the end of the frame, *not* before the play area, so the paddle stays green.

::: details TypeScript Equivalent

A Breakout model in TypeScript usually keeps a two-dimensional array of bricks and a framebuffer. The 2600 has neither an array of objects nor a framebuffer, so the closest model has three layers: a **brick mask** (one 6-bit number per row), a **function that turns a mask into three playfield bytes**, and a **row table** for the moving objects.

```typescript
// The bricks are six unique columns per half, mirrored by the TIA.
const COLS = 6, ROWS = 6;
const BRICK_START = 8;   // the first brick's left edge, TIA pixels
const BRICK_PITCH = 12;  // 8-pixel brick + 4-pixel gap

type Mask = number; // six bits; bit 5 is the leftmost unique brick

// The ROM's 64 x 3 table: mask -> PF0, PF1, PF2.
function pfBytes(mask: Mask): [number, number, number] {
  let pf0 = 0, pf1 = 0, pf2 = 0;
  // Each unique brick owns two adjacent 4-pixel chunks.
  const chunks = [
    [2, 3], [5, 6], [8, 9], [11, 12], [14, 15], [17, 18],
  ];
  for (let col = 0; col < COLS; col++) {
    if (!(mask & (1 << (5 - col)))) continue;
    for (const chunk of chunks[col]) {
      if (chunk < 4) pf0 |= 1 << (4 + chunk);
      else if (chunk < 12) pf1 |= 1 << (11 - chunk);
      else pf2 |= 1 << (chunk - 12);   // PF2 bit 0 is chunk 12
    }
  }
  return [pf0, pf1, pf2];
}

// The ball's brick: row from Y, unique column from the centre X.
function brickAt(ballY: number, ballX: number): { row: number; col: number } | null {
  if (ballY < 15 || ballY > 62) return null;
  const row = Math.floor((ballY - 15) / 8);       // 0..5
  const centre = ballX + 2;                        // the ball is 4 px wide
  let col: number;
  if (centre < 80) {
    col = Math.max(0, Math.floor((centre - 8) / BRICK_PITCH));
  } else {
    col = 5 - Math.floor((centre - 80) / BRICK_PITCH);
    // The code's 8-bit CMP #6 clamp: the far-right gap becomes col 5.
    if (col < 0 || col > 5) col = 5;
  }
  return { row: Math.min(5, row), col };
}

// The play area: 32 rows of 4 lines, bit 0 = paddle, bit 1 = ball.
function buildPlayTable(paddleX: number, ballY: number): Uint8Array {
  const table = new Uint8Array(32);
  const paddleRow = (179 - 63) >> 2;               // rows 29-30
  table[paddleRow] |= 1;
  table[paddleRow + 1] |= 1;
  if (ballY >= 63 && ballY <= 190) {
    table[(ballY - 63) >> 2] |= 2;
  }
  return table;
}

// One physics step.  The real code runs this in VBLANK, once per frame.
function step(world: World, mask: Mask[]): void {
  world.ballX += world.ballVX;
  world.ballY += world.ballVY;
  if (world.ballX < 4) { world.ballX = 4; world.ballVX = -world.ballVX; }
  if (world.ballX > 152) { world.ballX = 152; world.ballVX = -world.ballVX; }
  if (world.ballY < 15) { world.ballY = 15; world.ballVY = -world.ballVY; }
  if (world.ballY > 190) loseLife(world);
  const hit = brickAt(world.ballY, world.ballX);
  if (hit) {
    const bit = 1 << (5 - hit.col);
    if (mask[hit.row] & bit) {
      mask[hit.row] &= ~bit;
      score += 1;
      world.ballVY = -world.ballVY;
    }
  }
}
```

The model gets the shape right — a mask array, a PF generator, a row table, a collision function — and it breaks at the points where the 2600 is different:

- **The playfield is 4-pixel chunks, not pixels.** `pfBytes` produces three bytes; the TIA repeats the left half into the right half (reflect mode), so a single 6-bit mask draws twelve visible bricks. The TypeScript array of 72 bricks is a lie the hardware does not tell.
- **There is no framebuffer.** The brick kernel writes `PF0`/`PF1`/`PF2` once per 8-line row; the beam holds those latches for eight scanlines. The play kernel writes `GRP0`/`ENABL` once per 4-line row. A `drawRect` call has no counterpart.
- **The collision is a hardware latch.** `CXBLPF` bit 7 is set when the ball's pixels overlap the playfield at any point in the frame. The code reads the *previous* frame's latch in VBLANK and clears it with `CXCLR`. The TypeScript `brickAt` runs at the moment of the step; the real check is one frame late by construction.
- **The frame is fixed at 262 lines and every line is 76 cycles.** The brick kernel's first line has a hard deadline: `PF0` by cycle ~23, `PF1` by ~28, `PF2` by ~39, `ENABL` by ~24. The TypeScript loop has no deadline.
- **The score and the paddle share P0.** The score library draws the six digits with P0 and P1 in three-copy mode at X=56/64; the paddle needs P0 at `PaddleX`. The fix is timing, not data: `ScoreSetup` every frame in VBLANK, the score first, then one `HMOVE` to move P0 (the ball was positioned in VBLANK).
- **The positions are quantized.** The ball's brick-zone row is the playfield's 4-line row; the display snaps to a 4-pixel vertical grid inside the brick field, and the play area's row table snaps to 4-line rows. The TypeScript Y is exact; the 2600's is a schedule.

:::

## Theory

### Section 1: The Breakout Architecture

Breakout is four horizontal bands and one moving object that crosses three of them. The 192 visible lines split like this:

| Picture lines | Lines | What happens |
|---|---:|---|
| 0-8 | 9 | `ScoreDraw`: the six digits, `000000` at power-on |
| 9 | 1 | Blank; `NUSIZ0` returns to one copy and the positioners are prepared |
| 10-14 | 5 | Positioners: the ball is positioned in VBLANK; the visible block moves P0 to `PaddleX` with one `HMOVE`, then brick row 0's setup |
| 15-62 | 48 | The brick field: 6 rows × 8 lines of playfield |
| 63-190 | 128 | The play area: 32 rows × 4 lines driven by `PlayRowTable` |
| 191 | 1 | Blank |

`9 + 1 + 5 + 48 + 128 + 1 = 192`. The frame around it is Lesson 12's skeleton: 3 VSYNC lines, 37 VBLANK lines, 192 picture lines, 30 overscan lines. The measured checkpoints are `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `ScoreDone` 46, `BrickStart` 51, `PlayStart` 99, and `OverscanStart` 229.

The game logic lives in VBLANK: the joystick, the serve timer, the collision latches, the ball's motion, the paddle bounce, the brick arithmetic, the level check, and the two row tables. The VBLANK timer is the course standard 44 ticks (2,753 cycles, about 36.2 lines); the timer plus `+wait_timer`'s final `WSYNC` make the measured 37-line VBLANK. The score positioners also run in VBLANK, so the budget has to cover `ScoreSetup`'s three scanlines plus the game logic.

The visible code is five pieces:

1. **The score band** (9 lines): the library's Staugas kernel.
2. **The blank line** (1): `NUSIZ0=0`, the playfield cleared, and the paddle colour set.
3. **The play positioners** (5): the ball was positioned in VBLANK; P0 moves to `PaddleX` with one `HMOVE`, and the brick row 0 setup runs last.
4. **The brick kernel** (48): 6 rows × 8 lines; PF once per row, the ball's `ENABL` once per 4-line half.
5. **The play kernel** (128): 32 rows × 4 lines; `GRP0` and `ENABL` once per row.

The play kernel is prepared on the last brick-field line (picture 62); the 32 play rows are four lines each (picture 63-190), and the paddle's rows (29-30) land on their specified lines. The frame stays 262 and the measured checkpoints are met.

### Section 2: The Brick Map and the 64 × 3 PF Table

The brick field is six unique bricks per half. A brick is 8 pixels wide — two 4-pixel playfield chunks — with a 4-pixel gap. The first brick starts at X=8 (chunk 2), not X=0, because that makes the field symmetric under reflect mode: the leftmost brick covers X=8-15 and the mirrored rightmost brick covers X=144-151.

The six unique bricks fill 68 of the 80 pixels of a half: `6 × 8 + 5 × 4 = 68`, leaving 8 pixels of margin on the left and 4 on the inner edge. The chunk map is:

| Unique brick (mask bit) | Chunks | PF bits |
|---|---|---|
| col 0 (bit 5, leftmost) | 2-3 | `PF0` bits 6-7 |
| col 1 (bit 4) | 5-6 | `PF1` bits 6-5 |
| col 2 (bit 3) | 8-9 | `PF1` bits 3-2 |
| col 3 (bit 2) | 11-12 | `PF1` bit 0 + `PF2` bit 0 |
| col 4 (bit 1) | 14-15 | `PF2` bits 2-3 |
| col 5 (bit 0, innermost) | 17-18 | `PF2` bits 5-6 |

`PF2` is reversed relative to `PF1`: its bit 0 is the leftmost of its eight chunks (chunk 12), and bit 7 is chunk 19.  `CTRLPF` bit 0 = 1 selects reflect mode, so the TIA draws the left half and then mirrors it. Six unique bricks become twelve visible ones. The field's PF bytes for a row mask are the OR of the six bricks' bit pairs:

| Mask | What it draws | PF0 | PF1 | PF2 |
|---|---|---|---|---|
| `$3F` | all six unique bricks (12 visible) | `$C0` | `$6D` | `$6D` |
| `$20` | col 0 only (2 visible) | `$C0` | `$00` | `$00` |
| `$10` | col 1 only | `$00` | `$60` | `$00` |
| `$08` | col 2 only | `$00` | `$0C` | `$00` |
| `$04` | col 3 only | `$00` | `$01` | `$01` |
| `$02` | col 4 only | `$00` | `$00` | `$0C` |
| `$01` | col 5 only | `$00` | `$00` | `$60` |
| `$00` | empty | `$00` | `$00` | `$00` |

The table has 64 entries because the mask is six bits. Each entry is three bytes, so the whole table is **192 ROM bytes**. The program stores it as three 64-byte columns — `BrickPF0`, `BrickPF1`, `BrickPF2` — so the kernel can index a mask with a single `LDA BrickPF0,X` instead of multiplying by three. The group is page aligned so the 192 bytes never cross a page, and each column is 64-byte aligned so an indexed load always takes the same cycles.

Every 8-line brick row's eighth line is blanked. The brick field still occupies 48 lines (the 6 × 8 grid), but the visible brick is 7 lines tall with a 1-line gap between rows. Without that line the six rows merge into twelve tall vertical bars; with it the reader sees the brick wall the game is named for.

::: tip Why the first brick is at X=8
The playfield's PF0 bit 4 is chunk 0 at X=0. A field starting there would span X=0-67, and reflect mode would mirror it to X=92-159: a 24-pixel central gap (X=68-91) and no left margin. The actual field starts at chunk 2 (X=8), so the left margin is 8 pixels, the left bricks span X=8-75, their mirror spans X=84-151, and the rightmost brick ends at X=151. That is the X=8 edge the collision formula uses: `(centre - 8) / 12`.
:::

### Section 3: The Brick Collision Math

The TIA sets a collision latch when two objects' pixels overlap. `CXBLPF` ($06) bit 7 is the ball ↔ playfield latch. It is set during the visible frame and stays set until `CXCLR` ($2C) is strobed. The game reads it at the start of VBLANK — the previous frame's collision — and clears it once:

```asm
    LDA CXBLPF
    AND #$80
    BEQ NoBrickHit
    LDA BallVY
    BPL NoBrickHit          ; moving down: a stale overlap, not a hit
    JSR BrickCollision
```

The `BallVY` direction check matters. A latch can still be set one frame after a bounce; requiring the ball to be moving up (negative `VY`) rejects that stale overlap.

The handler answers two questions from the ball's position:

1. **Which row?** The brick field starts at visible line 15 and every row is 8 lines: `row = (BallY - 15) / 8`, clamped to 0-5.
2. **Which unique column?** The ball is 4 pixels wide, so its centre is `BallX + 2`. On the left half (`centre < 80`), `col = (centre - 8) / 12`. On the right half, reflect mode has mirrored the unique columns, so `col = 5 - ((centre - 80) / 12)`.

The division is repeated subtraction, not a hardware divide. Six iterations is the worst case; the VBLANK has thousands of cycles to spare.

Some worked examples:

| Ball | Centre | Half | Row | Column | Bit | What it clears |
|---|---|---|---|---|---|---|
| `BallX=62`, `BallY=62` | 64 | left | `(62-15)/8 = 5` | `(64-8)/12 = 4` | `1 << 1 = $02` | row 5, col 4 (the 5th unique brick) |
| `BallX=118`, `BallY=62` | 120 | right | 5 | `5 - ((120-80)/12) = 5-3 = 2` | `1 << 3 = $08` | row 5, col 2 |
| `BallX=8`, `BallY=15` | 10 | left | 0 | `(10-8)/12 = 0` | `$20` | row 0, col 0 |
| `BallX=152`, `BallY=15` | 154 | right | 0 | `5 - ((154-80)/12) = 5-6 = -1 -> clamp 5` | `$01` | row 0, col 5 |

The last example is why the right-side column is clamped: the far-right 4 pixels are the wall margin, and the division can return 6 there. No brick lives in the margin, so the latch should not fire; the clamp is a safety net.

The bounce is vertical: reverse `VY`. The handler also reverses `VX` when the ball's centre is within two pixels of the brick's left or right edge. The brick's left edge is `8 + 12 × col` on the left half and `144 - 12 × col` on the right half; the check is `centre - edge` in 0..2 (near the left edge) or 5..7 (near the right edge). A hit in the middle (3..4) is a pure vertical bounce.

The handler is careful about a hit on an already-empty brick: it tests the mask bit before clearing it. A hit whose bit is clear is ignored — no score, no bounce. The `BrickHit` checkpoint reports A = the row; `BrickClear` reports A = the new mask.

### Section 4: The Ball in Both Zones

The ball is a 4×4 object (`CTRLPF` bits 4-5 = `10`, four lines of `ENABL`). Its `BallY` is the ball's top line in visible coordinates. The ball crosses three regions:

- **The brick field, lines 15-62.** The brick kernel draws the PF rows; the ball needs `ENABL` on the four lines it occupies. The 48 lines are twelve 4-line rows, so a **12-byte `BrickRowTable`** has one bit per 4-line row; the build sets the bit for `(BallY - 15) >> 2`. The brick kernel checks the table once per 4-line half and writes `ENABL` from a 2-entry `EnableByte` table (`$00`/`$02`).
- **The play area, lines 63-190.** The 128 lines are thirty-two 4-line rows. The **32-byte `PlayRowTable`** stores bit 0 = P0 paddle and bit 1 = the ball. The paddle is 8×8 = two rows; the ball is 4×4 = one row.
- **The gap, line 191.** Both tables are empty; the ball is off.

The brick kernel's first line has four stores with hard deadlines. The order is `ENABL`, `PF0`, `PF1`, `PF2`:

| Store | Cycle (first row) | Deadline | Why |
|---|---:|---:|---|
| `ENABL` | 13 | 24.0 | the ball's leftmost X=4, `(4+68)/3` |
| `PF0` | 20 | 22.7 | the playfield's first chunk at X=0 |
| `PF1` | 27 | 28.0 | the playfield's chunk 4 at X=16 |
| `PF2` | 34 | 38.7 | the playfield's chunk 12 at X=48 |

The order is not stylistic: `PF0` must be first among the PF writes, and `ENABL` must be before the ball's pixel time. The first line's `ENABL` for the first 4-line half is precomputed in the `BrickStart` setup on picture line 14; the second half's `ENABL` is written at the start of line 5. The next row's first-half `ENABL` is prepared during line 5 — the 60-plus cycles of a line have room.

The play kernel is Pong's row-table shape with two objects. Each 4-line row starts with:

```asm
    NOP
    NOP
    NOP
    LDA #C_BALL
    STA COLUPF              ; the play area's ball is white
    LDA CurP0
    STA GRP0                ; the paddle row
    LDA Temp
    STA ENABL               ; the ball row
    LDA #$00
    STA PF0                 ; the playfield is empty here
    STA PF1
    STA PF2
    STA WSYNC               ; line 1
```

`GRP0` lands at cycle 17 (the paddle's leftmost X=8 has a deadline of 25.3) and `ENABL` at 23 (the ball's X=4 deadline is 24.0). The PF clears that follow are no-ops: the brick field's gap line already blanked the playfield. The fourth line decodes the next row into `CurP0` and `Temp`; the loop's `INX`/`CPX #32`/`BNE` closes it.

::: warning The ball's two zones are not symmetric
The brick zone quantizes the ball to a 4-line row, and the play zone quantizes it to a different 4-line row grid. The visible ball moves in 4-line steps even though `BallY` moves 2 pixels per frame. The brick collision uses the *logical* `BallY` for the row and the *visible* ball for the latch; the 4-line quantization keeps them consistent. Do not "fix" one grid without the other.
:::

### Section 5: The Paddle, the Angle Table, and the Walls

The paddle is P0, 8×8, at `PaddleY=179` — play rows 29-30, the last two 4-line rows. It moves 4 pixels per frame with the P0 left/right joystick bits: `SWCHA` bits 6 (left) and 7 (right), active low. `include/vcs.asm` is the authority; the P0 nibble is the high nibble, not the low one. The clamp is 8..152.

The paddle hit is `CXP0FB` bit 6 (P0 ↔ ball). Read it in VBLANK, require `BallVY` to be positive (the ball is descending), then:

1. Compute the hit offset `BallX - PaddleX + 3`, a 0..10 index. The boundaries 2, 4, 7, 9 give five zones 2,2,3,2,2 pixels wide.
2. Index the level's angle table:

| Zone | Offset | Slow (level 0) | Fast (levels 1-2) | Turbo (level 3+) |
|---|---|---|---|---|
| 0 | 0-1 | `-2` | `-3` | `-4` |
| 1 | 2-3 | `-1` | `-2` | `-3` |
| 2 | 4-6 | `0` | `0` | `0` |
| 3 | 7-8 | `+1` | `+2` | `+3` |
| 4 | 9-10 | `+2` | `+3` | `+4` |

3. Set `VY` to `-speed` (the ball goes up) and move the ball to `PaddleY - 4` so the next frame's latch is clean.

The vertical speed is `GetSpeed`: 2 at level 0, 3 at levels 1-2, 4 from level 3 on. The wall bounces preserve the speed's magnitude by negating the signed byte.

The walls follow the geometry rather than a naive play-area-top bounce:

- **Left and right:** `BallX` clamps at 4 and 152; reverse `VX`.
- **The top:** the ball must pass the play-area top (line 63) to reach the bricks, so the play-area top is not a wall. The ceiling is the top of the brick field, `Y=15`. A bounce at Y=63 would keep the ball out of the brick field, so the ball rebounds at the brick field's top instead.
- **The bottom:** the paddle is the only bounce. A `BallY` above 190 is a miss: `DEC Lives`, re-serve at the paddle, or game over at zero.

`BallY`, `BallX`, `PaddleX` and the two velocities are visible coordinates, not play-area-relative ones. The brick row formula and the play row formula each subtract their zone's top (15 and 63).

### Section 6: The Score Library and the P0/P1 Conflict

`include/score.asm` draws six digits with P0 and P1 in three-copy close mode. It owns `$A0-$D7` and uses VDEL to keep the column writes from tearing. Its API is small:

- `ScoreInit` / `ScoreClear` at reset: six zero digits.
- `ScoreSetup` every frame in VBLANK: `NUSIZ0=NUSIZ1=3`, `VDELP0=VDELP1=1`, P0 at TIA X=56, P1 at X=64, one `HMOVE`.
- `ScoreDraw` first in the body: nine visible lines.
- `ScoreAddOne` on a brick: add one to the six-digit number, return `C=1` on 999999.

The conflict is P0. The score needs P0 at 56 with three copies; the paddle needs P0 at `PaddleX` with one copy. The sequence is:

1. `JSR ScoreSetup` in VBLANK. It re-positions P0/P1 at 56/64 and strobes one `HMOVE`.
2. `JSR ScoreDraw` at `BodyStart`. The score's nine lines are drawn.
3. On the blank line, `NUSIZ0=0` and `COLUP0=C_PADDLE`.
4. The ball is positioned in VBLANK before `ScoreSetup`: set `HMBL`/`RESBL`, then let the score's single `HMOVE` apply P0/P1/ball. After the score, the visible positioner sets `HMP0`/`RESP0` for the paddle and zeroes `HMP1`/`HMBL`, so its one `HMOVE` moves only the paddle.
5. At the end of the frame (the blank line 191), restore `COLUP0`/`COLUP1` to the score's white and `COLUPF` to the brick colour for the next frame.

Step 5 is the one to get right. Setting the score's white before the play area would clobber the paddle's green; the score's pixels on lines 0-8 are already latched, so the restore belongs after the play area. The paddle is green `$C8`; the ball is white `$0E` in the play area and the brick colour `$28` while it is in the brick zone (the ball and the bricks share `COLUPF`).

`ScoreAddOne` is called from the top-level VBLANK, never from inside `BallStep`. The library's deepest stack use is seven bytes with one `JSR` level, which fits `$F9-$FF`; a second level would reach `$F7` and corrupt `PlayRowTable`.

### Section 7: Lives, Levels, and the Auto-Demo

A miss is `BallY > 190`. The handler decrements `Lives`; at zero it sets `GameState=1`, resets `Frame` so the demo's game-over wait starts, and freezes the ball. Fire restarts: `Lives=3`, `Level=0`, `ScoreClear`, pattern 0, and a fresh serve.

The levels cycle through three patterns:

| Pattern (Level mod 3) | Rows (6 bits each) | Unique bricks |
|---|---|---:|
| `Level0` | `$3F` × 6: the full field | 36 |
| `Level1` | `$0C, $1E, $3F, $3F, $1E, $0C`: a diamond | 24 |
| `Level2` | `$15, $2A` × 3: a checkerboard | 18 |

`PatternCount` holds the counts. Clearing every unique brick of the pattern (`BricksLeft=0`) advances `Level`, loads the next pattern, and re-serves. After level 2 the patterns repeat with the faster `GetSpeed` value.

The serve is a 60-frame countdown. `ServeStep` decrements `ServeTimer`; at zero it launches the ball with `VY = -speed`. The ball is parked at the paddle (`BallX = PaddleX + 2`, `BallY = PaddleY - 4`); the first serve's `VX=+1` drifts it off the paddle's centre so the opening shot reaches the bottom brick row.

The auto-demo exists so the captures are deterministic. `DemoTimer` counts once every two frames; after 60 counts (120 frames = 2 s) with no joystick input the paddle tracks the ball at up to 4 pixels/frame. The target is three pixels to one side of the ball's centre, and the side alternates with `Frame` bit 5 so the bounce angle keeps changing. A miss re-serves. At `DemoTimer=240` (480 frames = 8 s) the demo advances the pattern once, so the ten-second capture shows the second level. The shortcut is disclosed here and in the code: a human player never sees it because any left/right input resets `DemoTimer`.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson70.bin lessons/part10-capstones/70-breakout/70-breakout.asm
stella build/lesson70.bin
```

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 70: Capstone 2 — Breakout — Racing the Beam
; =============================================================================
; Part 10: Capstone Projects
;
; What this program does:
;   A complete Breakout.  A 48-line brick field (6 rows x 8 lines) sits above
;   a 128-line play area; an 8x8 paddle moves along the bottom and a 4x4 ball
;   bounces off the walls, the paddle, and the bricks.  Every brick removed
;   adds one to the six-digit score.  Three lives, three brick patterns, a
;   speed-up per level, and a deterministic auto-demo that plays the game so
;   the captures show the opening field, a broken field, and the second level.
;
; The screen (192 visible lines):
;   picture lines 0-8     the score band.  include/score.asm draws the nine
;                         lines (line 0 is the setup/blank line, lines 1-8 are
;                         the six digits, 000000 at power-on).
;   picture line 9        blank; NUSIZ0 returns to one copy and the play
;                         positioners are prepared.
;   picture lines 10-14   the positioners: the ball is positioned in VBLANK
;                         (the score's HMOVE applies it); the visible block
;                         positions P0 at PaddleX with one HMOVE.  The fifth
;                         line prepares brick row 0.
;   picture lines 15-62   the brick field: 6 brick rows x 8 lines.  Each
;                         row's PF0/PF1/PF2 come from the 64-entry BrickPF
;                         table, keyed by the 6-bit row mask.  Reflect mode
;                         (CTRLPF bit 0) mirrors the 6 unique bricks to 12
;                         visible per row.  The ball is enabled by the
;                         12-byte BrickRowTable, one bit per 4-line row.
;                         The eighth line of every brick row is blanked,
;                         so the six rows read as six rows of 7-line bricks
;                         with a one-line vertical gap.
;   picture lines 63-190  the play area: 32 rows x 4 lines.  The 32-byte
;                         PlayRowTable (bit 0 = P0 paddle, bit 1 = ball)
;                         drives P0 and the ball; the paddle is 8x8 (2 rows)
;                         and the ball is 4x4 (1 row).  The play kernel's
;                         setup line is picture 62; the 32 play rows are
;                         4 lines each (picture 63-190).
;   picture line 191      blank.
;   9 + 1 + 5 + 48 + 128 + 1 = 192.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame is scanline 259, VblankStart 0, BodyStart 37, ScoreDone 46,
;   BrickStart 51, PlayStart 99, OverscanStart 229.
;
; The brick geometry:
;   Each brick is 8 pixels (2 playfield chunks) with a 4-pixel gap; 6 bricks
;   fill 68 of the 80 pixels of a half.  The first brick starts at X=8
;   (chunk 2), so the field is symmetric under reflect mode: the leftmost
;   brick covers X=8-15 and the mirrored rightmost brick covers X=144-151.
;   The six unique bricks map to the six mask bits, bit 5 = leftmost:
;
;     mask bit 5 (col 0): chunks 2-3   -> PF0 bits 6-7
;     mask bit 4 (col 1): chunks 5-6   -> PF1 bits 6-5
;     mask bit 3 (col 2): chunks 8-9   -> PF1 bits 3-2
;     mask bit 2 (col 3): chunks 11-12 -> PF1 bit 0 + PF2 bit 0
;     mask bit 1 (col 4): chunks 14-15 -> PF2 bits 2-3
;     mask bit 0 (col 5): chunks 17-18 -> PF2 bits 5-6
;
;   BrickPF is 64 entries x 3 bytes = 192 ROM bytes, stored as three 64-byte
;   columns (PF0, PF1, PF2) so the kernel indexes a mask without multiplying
;   by three: LDA BrickPF0,X / STA PF0, then PF1 and PF2.  The group is page
;   aligned so the 192 bytes never cross a page, and each column is 64-byte
;   aligned so an indexed load always takes the same cycles.
;
; The brick collision (all of it in VBLANK, on the previous frame's latch):
;   CXBLPF bit 7 = the ball overlapped the playfield.  The row is
;   (BallY - 15) / 8 (0-5).  The ball's centre X is BallX + 2.  On the left
;   half (centre < 80) the unique column is (centre - 8) / 12 (0-5); on the
;   right half it is 5 - ((centre - 80) / 12).  The bit is 1 << (5 - column).
;   A set bit clears the brick, decrements BricksLeft, adds one to the score,
;   and bounces: VY reverses, and VX also reverses when the centre is within
;   two pixels of the brick's left or right edge.  A hit on an already-empty
;   brick is ignored.
;
; The paddle and ball:
;   The paddle is P0, 8x8, at PaddleY=179 (play rows 29-30), X 8..152, and
;   moves 4 pixels/frame with the P0 left/right joystick bits (SWCHA bits
;   6/7, active low; include/vcs.asm is the authority).  P0 is green in the
;   play area (the score's white is restored on the blank line 191, not
;   before the play area).  The ball is 4x4 and white in the play area,
;   the slow angle table's VX is -2..+2, the fast -3..+3, the turbo -4..+4;
;   VY is +-2..+-4.  It bounces off the play-area top?  No: the
;   ball must pass the play-area top (line 63) to reach the bricks, so the
;   top wall is the top of the brick field (Y=15).  It bounces off the left
;   and right walls (X=4 and X=152), and off the paddle through CXP0FB bit 6.
;   The paddle's five angle zones set VX (-2,-1,0,+1,+2 slow; wider at
;   speed 3 and 4) and VY stays negative (the ball goes up).
;
; Lives and levels:
;   Three lives.  A miss (BallY > 190) decrements Lives; at zero GameState=1
;   and fire restarts.  Clearing every unique brick of the pattern advances
;   the level: three patterns (Level0 full 36, Level1 diamond 24, Level2
;   checkerboard 18), then the patterns repeat with a faster ball (speed 2
;   at level 0, 3 at levels 1-2, 4 from level 3 on).  BricksLeft is the
;   pattern's brick count.
;
; The score library:
;   include/score.asm owns $A0-$D7 and draws nine visible lines.  ScoreSetup
;   is called every frame in VBLANK (it re-positions P0/P1 at 56/64 and
;   strobes one HMOVE).  ScoreDraw runs first in the body; then P0 is
;   repositioned to PaddleX with a second HMOVE; the ball was positioned in
;   VBLANK and the score's HMOVE applied it.
;   P1 stays at the score's X with GRP1=0, so it is invisible in the play
;   area.  ScoreAddOne adds one per brick; the six digits handle the carry.
;
; The auto-demo:
;   After 120 frames with no left/right input the paddle tracks the ball at
;   up to 4 pixels/frame, aiming three pixels to one side of the ball and
;   alternating every 32 frames so the bounce angle keeps changing.  A miss
;   re-serves.  At frame 480 (eight seconds) the demo advances the pattern
;   once, so the ten-second capture shows the second level; a human player
;   is never affected because any joystick input resets DemoTimer to zero.  The
;   demo is deterministic; the doc discloses the shortcut.
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80-$85  BrickMap      6 bytes; 6 bits per row; bit 5 = leftmost brick
;   $86-$91  BrickRowTable 12 bytes; one bit per 4-line brick row (bit 0 =
;                          the ball is in this 4-line row)
;   $92      BallX         4..152 (the ball's left edge)
;   $93      BallY         15..190 (the ball's top line, visible coordinates)
;   $94      BallVX        signed: -4..+4 (the turbo table)
;   $95      BallVY        signed: -4..+4
;   $96      PaddleX       8..152 (the paddle's left edge)
;   $97      DemoTimer     the demo's level timer: +1 every two frames; the
;                         skip fires at 240 (480 frames = 8 seconds).  The
;                         paddle's Y is the constant PADDLE_Y = 179; dropping
;                         the PaddleY variable keeps the 14-byte map.
;   $98      Lives         3..0
;   $99      Level         0.. (pattern = Level mod 3; speed from Level)
;   $9A      BricksLeft    the current pattern's remaining bricks
;   $9B      Frame         the free-running frame counter (the demo's
;                         two-frame parity comes from its bit 0)
;   $9C      ServeTimer    60..1 while the ball is parked, 0 in play
;   $9D      GameState     0 = play, 1 = game over
;   $9E      Temp          scratch (also the play kernel's ball byte)
;   $9F      CurP0         scratch (also the play kernel's GRP0 byte)
;   $A0-$D7  the score library (ScoreDigits, ScoreRow, ScoreTmp, ScoreBuf)
;   $D8-$F7  PlayRowTable  32 bytes; bit 0 = P0 paddle, bit 1 = ball
;   $F8-$FF  stack
;
;   The paddle's Y is the constant PADDLE_Y=179, so the byte at $97 is the
;   demo timer.
;
;   The score add is called from the top-level VBLANK, never from inside
;   BallStep: the library's deepest stack use is seven bytes with one JSR
;   level, which fits $F9-$FF.  A second JSR level would reach $F7 and
;   corrupt the PlayRowTable.
;
; Controls:
;   Left joystick left/right moves the paddle (4 pixels/frame).
;   Fire starts a waiting serve early; fire restarts after game over.
;
; Checkpoints (the A/X/Y/SP values are the state at the label):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   ScoreDone (46), BrickStart (51), PlayStart (99), OverscanStart (229),
;   PaddleXRead (A=PaddleX), BallXRead (A=BallX), BallYRead (A=BallY),
;   BrickHit (A=the brick row 0-5), BrickClear (A=the new 6-bit mask),
;   ScoreAdd (the score library: A=the digit after the add),
;   LifeLost (A=the new Lives), LevelStart (A=the new Level).
;
; Build: acme -f plain -o build/lesson70.bin \
;        lessons/part10-capstones/70-breakout/70-breakout.asm
; Run:   stella build/lesson70.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
; The 42-cycle fill keeps each zone-boundary WSYNC store before the end of
; the line; a WSYNC written late still halts to the next line, which is why
; the fill is fixed-length.  It is timing, not decoration.
!macro burn_line {
    !fill 21, $EA          ; 21 NOPs = 42 cycles
}

VBLANK_TIMER   = 44       ; 1 + 43 x 64 = 2753 cycles = 36.2 lines; the
                          ; timer + wait_timer's WSYNC make the measured 37-line VBLANK
OVERSCAN_TIMER = 36       ; 1 + 35 x 64 = 2241 cycles = 29.5 lines; the
                          ; timer + WSYNC make the measured 30-line overscan

PADDLE_MIN     = 8        ; the paddle's left-edge limits
PADDLE_MAX     = 152
PADDLE_Y       = 179      ; play rows 29-30: visible lines 179-186
PADDLE_SPEED   = 4

BALL_LEFT      = 4        ; the ball's wall limits (its left edge)
BALL_RIGHT     = 152
BALL_TOP       = 15       ; the top of the brick field: the ball's ceiling
BALL_BOTTOM    = 190      ; BallY > 190 is a miss
SERVE_FRAMES   = 60

BRICK_TOP      = 15       ; visible line of the first brick row
BRICK_ROWS     = 6
BRICK_ROW_LINES= 8

PLAY_TOP       = 63       ; visible line of the first play row
PLAY_ROWS      = 32

PADDLE_BIAS    = 3        ; the Lesson 26 player positioning bias
BALL_BIAS      = 4        ; the ball's output delay is one clock shorter

C_SCORE        = $0E      ; the score digits: white
C_PADDLE       = $C8      ; P0 in the play area: green
C_BRICK        = $28      ; the bricks and the ball in the brick zone: orange
C_BALL         = $0E      ; the ball in the play area: white
C_BG           = $00      ; black

AUTO_START     = 120      ; frames with no input before the auto-demo
DEMO_LEVEL     = 240      ; DemoTimer count (every two frames) for the skip:
                          ; 240 x 2 = 480 frames = 8 seconds

; =============================================================================
; RAM ALLOCATION ($80-$FF; the score library owns $A0-$D7, the stack $F8-$FF)
; =============================================================================
BrickMap     = $80        ; 6 bytes ($80-$85)
BrickRowTable= $86        ; 12 bytes ($86-$91)
BallX        = $92
BallY        = $93
BallVX       = $94
BallVY       = $95
PaddleX      = $96
DemoTimer    = $97        ; the demo's level timer: +1 every two frames
Lives        = $98
Level        = $99
BricksLeft   = $9A
Frame        = $9B
ServeTimer   = $9C
GameState    = $9D
Temp         = $9E
CurP0        = $9F
PlayRowTable = $D8        ; 32 bytes ($D8-$F7)

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreSetup, ScoreDraw, ScoreInit, ScoreClear, ScoreSetDigit, ScoreAddOne and
; ScoreFont live here.  The library owns $A0-$D7 and is sourced after the ROM
; origin so its code has a program counter.  The reset vector at $FFFC still
; points at this lesson's Reset below.
    !source "include/score.asm"

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joystick)

    LDA #C_SCORE
    STA COLUP0              ; the score's left digits
    STA COLUP1              ; the score's right digits
    LDA #C_BRICK
    STA COLUPF              ; the bricks (and the ball in the brick zone)
    LDA #C_BG
    STA COLUBK
    LDA #$21
    STA CTRLPF              ; reflect the left half + a 4-pixel ball
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1
    STA VDELP0
    STA VDELP1
    STA VDELBL
    STA GRP0
    STA GRP1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2

    LDA #3
    STA Lives
    LDA #0
    STA Level
    STA GameState
    STA Frame
    STA DemoTimer
    STA BallVY
    LDA #60
    STA PaddleX
    LDA #62
    STA BallX               ; the serve's starting X, at the paddle
    LDA #175
    STA BallY               ; just above the paddle
    LDA #1
    STA BallVX              ; the serve drifts right
    LDA #SERVE_FRAMES
    STA ServeTimer
    LDA #0
    STA CXCLR

    JSR ScoreInit
    JSR ScoreClear          ; the display reads 000000
    LDA #0                  ; pattern 0: the full field
    JSR LoadPattern

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK              ; blank the picture while the game thinks
    +set_timer VBLANK_TIMER
    INC Frame

; The previous frame left the playfield and the sprites latched.  Clear them
; before the score band: the score uses only P0/P1/PF=0, and the ball would
; otherwise appear at BallX during the score's nine lines.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    STA GRP0
    STA GRP1

; -----------------------------------------------------------------------------
; 1. THE POSITIONERS — the ball in VBLANK, then the score's one HMOVE
; -----------------------------------------------------------------------------
; The ball is independent of the score, so its coarse position and HMBL are
; set before ScoreSetup.  ScoreSetup ends with one HMOVE, which then applies
; P0, P1 and the ball in the same horizontal blank.  The ball's position is
; fixed for the frame; the score band keeps ENABL=0.
    LDA BallX
    CLC
    ADC #BALL_BIAS
    JSR SetCoarseBL
    JSR ScoreSetup
; The score's HMOVE has applied P0/P1/the ball.  Zero P1's and the ball's
; fine offsets so the play-area HMOVE moves only the paddle.
    LDA #$00
    STA HMP1
    STA HMBL

; -----------------------------------------------------------------------------
; 2. READ THE INPUT, THE FIRE EDGE, AND THE AUTO-DEMO
; -----------------------------------------------------------------------------
    JSR ReadInput

; --- a restart or the demo's level advance runs at the top level -------------
; ReadInput only sets a request in Temp.  The score library is called from here,
; never from inside ReadInput: one JSR level keeps its pushes inside $F8-$FF.
    LDA Temp
    CMP #$FF
    BNE NoRestartRequest
    LDA #0
    STA GameState
    STA Level
    STA Frame
    STA DemoTimer
    STA BallVY
    LDA #3
    STA Lives
    LDA #60
    STA PaddleX
    LDA #62
    STA BallX
    LDA #175
    STA BallY
    LDA #1
    STA BallVX
    LDA #SERVE_FRAMES
    STA ServeTimer
    JSR ScoreClear
    LDA #0
    JSR LoadPattern
NoRestartRequest:
    LDA Temp
    CMP #$FE
    BNE NoLevelRequest
    JSR LevelUp
NoLevelRequest:

; -----------------------------------------------------------------------------
; 3. THE SERVE TIMER (the ball is parked at the paddle until it reaches zero)
; -----------------------------------------------------------------------------
    JSR ServeStep

; -----------------------------------------------------------------------------
; 4. THE BALL: THE LATCHES, THE MOTION, THE WALLS, THE PADDLE, THE BRICKS
; -----------------------------------------------------------------------------
; Temp is the "a brick was cleared this frame" flag.  ScoreAddOne is called
; from this top level (not from BallStep): the score library's deepest stack
; use fits only with one JSR level.
    LDA #0
    STA Temp
    JSR BallStep
    LDA Temp
    BEQ NoBrickScore
    JSR ScoreAddOne         ; the score library's ScoreAdd checkpoint is inside
NoBrickScore:

; -----------------------------------------------------------------------------
; 5. THE LEVEL CHECK AND THE ROW TABLES
; -----------------------------------------------------------------------------
    LDA BricksLeft
    BNE NoLevelUp
    JSR LevelUp
NoLevelUp:
    JSR BuildTables

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE 0-8 — THE SCORE BAND (nine lines from the score library)
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, picture line 0
    JSR ScoreDraw           ; nine lines; returns at scanline 46

; =============================================================================
; VISIBLE 9 — THE BLANK LINE
; =============================================================================
ScoreDone:                  ; checkpoint: scanline 46, picture line 9
    LDA #$00
    STA NUSIZ0              ; one 8-pixel copy for the paddle
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    LDA #C_PADDLE
    STA COLUP0              ; the score's pixels are already latched white
    STA WSYNC               ; consume picture line 9 -> line 10

; =============================================================================
; VISIBLE 10-14 — THE PLAY POSITIONERS (five lines)
; =============================================================================
; Five lines are 10-14 (scanlines 47-51).  Only P0 needs a coarse position
; here: the ball was positioned in VBLANK, and the score's HMOVE applied it.
; P1 and the ball get zero fine offsets before this second HMOVE so it moves
; only the paddle.  The six NOPs before the first WSYNC push its write past
; the start of the visible area (cycle ~23) so it really ends the line; the
; +burn_line waits do the same for the following lines.
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    LDA PaddleX
    CLC
    ADC #PADDLE_BIAS
    JSR SetCoarseP0         ; the P0 divide, starts on line 48
    STA WSYNC               ; line 48 -> the HMOVE line
    STA HMOVE               ; the HMOVE line's HBLANK
; (The score's white is restored on the blank line 191, after the play
;  area; setting it here would clobber the paddle's green for the play area.)
    LDA #C_BRICK
    STA COLUPF
    +burn_line
    STA WSYNC               ; the HMOVE's stall ends on this line
    NOP                     ; the halt has taken effect; BrickStart is line 51

; =============================================================================
; VISIBLE 14 — THE BRICK ROW 0 SETUP (the checkpoint line)
; =============================================================================
; The first brick row's PF bytes and the first 4-line half's ENABL are set
; up here, on the fifth positioner line.  The actual PF stores run at the
; start of line 15 (scanline 52), before the playfield's first pixels.
BrickStart:                 ; checkpoint: scanline 51, picture line 14
    LDX #0
    LDA BrickRowTable,X
    TAY
    LDA EnableByte,Y
    STA CurP0               ; the first half's ENABL byte (0 or 2)
    LDA #0
    STA Temp                ; the brick row counter
    NOP
    NOP
    +burn_line
    STA WSYNC               ; consume picture line 14 -> line 15

; =============================================================================
; VISIBLE 15-62 — THE BRICK FIELD: 6 ROWS x 8 LINES
; =============================================================================
; Each row's first line stores the three PF bytes and the first half's ENABL.
; The order is ENABL, PF0, PF1, PF2: ENABL's store lands at cycle 13 (before
; the ball's leftmost pixel at cycle 24), PF0 at 20 (before its deadline
; 22.7), PF1 at 27 (before 28), PF2 at 34 (before 38.7).  The second half's
; ENABL is written at the start of line 5.  The next row's first-half ENABL
; is prepared during line 5.
BrickRowLoop:               ; eight lines: the row's first line starts here
    LDY Temp
    LDX BrickMap,Y          ; the row's 6-bit mask (X = the PF index)
    LDA CurP0
    STA ENABL               ; the first 4-line half's ball bit
    LDA BrickPF0,X
    STA PF0
    LDA BrickPF1,X
    STA PF1
    LDA BrickPF2,X
    STA PF2

    TYA
    ASL
    TAX                     ; X = 2 * row
    LDA BrickRowTable+1,X   ; the second 4-line half's ball bit
    TAY
    LDA EnableByte,Y
    STA CurP0               ; hold the second half's ENABL until line 5

    STA WSYNC               ; line 1
    STA WSYNC               ; line 2
    STA WSYNC               ; line 3
    STA WSYNC               ; line 4

    LDA CurP0
    STA ENABL               ; line 5: the second half's ball bit
    LDY Temp
    INY                     ; the next brick row
    CPY #BRICK_ROWS
    BEQ BrickNoNextRow
    TYA
    ASL
    TAX
    LDA BrickRowTable,X     ; the next row's first-half ball bit
    TAY
    LDA EnableByte,Y
    STA CurP0
BrickNoNextRow:
    STA WSYNC               ; line 5
    STA WSYNC               ; line 6
    STA WSYNC               ; line 7
    ; line 8 is the one-line vertical gap between brick rows: blank the
    ; playfield before this line's visible area, then wait it out.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA Temp
    CMP #(BRICK_ROWS - 1)
    BEQ BrickLastRow
    STA WSYNC               ; line 8
    INC Temp
    JMP BrickRowLoop
BrickLastRow:
    ; line 8 of the last brick row is picture line 62 (scanline 99); the
    ; play row 0 is prepared here and the WSYNC consumes the line.
    ; (falls through to PlayStart)

; =============================================================================
; VISIBLE 62 — THE PLAY ROW 0 SETUP (the checkpoint line)
; =============================================================================
PlayStart:                  ; checkpoint: scanline 99, picture line 62
    LDX #0
    LDA PlayRowTable,X
    TAY
    LDA DecodeP0,Y
    STA CurP0
    LDA DecodeBall,Y
    STA Temp
    STA WSYNC               ; consume picture line 62 -> line 63

; =============================================================================
; VISIBLE 63-190 — THE PLAY AREA: 32 ROWS x 4 LINES
; =============================================================================
; The first line of every row stores GRP0 and ENABL and clears the playfield
; (the PF is still the last brick row's).  The store order and timing:
; GRP0 at cycle 17 (the paddle's leftmost X=8 has deadline 25.3), ENABL at
; cycle 23 (the ball's leftmost X=4 has deadline 24).  The PF clears that
; follow are no-ops: the brick field's gap line already blanked the PF.
; The fourth line decodes the next row.
PlayRowLoop:
    NOP
    NOP
    NOP                     ; match the first row's phase to the steady state
    LDA #C_BALL
    STA COLUPF              ; the ball in the play area is white
    LDA CurP0
    STA GRP0
    LDA Temp
    STA ENABL
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC               ; line 1

    STA WSYNC               ; line 2
    STA WSYNC               ; line 3

    INX
    CPX #PLAY_ROWS
    BEQ PlayNoNextRow
    LDA PlayRowTable,X
    TAY
    LDA DecodeP0,Y
    STA CurP0
    LDA DecodeBall,Y
    STA Temp
PlayNoNextRow:
    STA WSYNC               ; line 4
    CPX #PLAY_ROWS
    BNE PlayRowLoop

; =============================================================================
; VISIBLE 191 — THE BLANK LINE
; =============================================================================
; The last play row's sprites are still latched.  Clear them immediately:
; the stores land at cycles 5 and 8, before this line's visible area starts.
; The colour restores then push the final WSYNC past the HBLANK (cycle ~23)
; so the blank line is really displayed and the overscan starts on 229.
    LDA #$00
    STA GRP0
    STA ENABL
    LDA #C_SCORE
    STA COLUP0
    STA COLUP1
    LDA #C_BRICK
    STA COLUPF
    +burn_line
    STA WSYNC               ; consume picture line 191 -> overscan
    NOP                     ; the halt has taken effect; overscan is line 229

; =============================================================================
; OVERSCAN — 30 lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; READ INPUT — the paddle, the fire button, and the auto-demo
; =============================================================================
; SWCHA is active low.  P0's left/right are bits 6/7 (include/vcs.asm); a
; held direction resets DemoTimer, the auto-demo timer.  With no
; direction for 120 frames the demo takes over.  Fire (INPT4 bit 7) starts
; a waiting serve early, and restarts after game over.
ReadInput:
    LDA PaddleX
PaddleXRead:                ; checkpoint: A = PaddleX
    LDA BallX
BallXRead:                  ; checkpoint: A = BallX
    LDA BallY
BallYRead:                  ; checkpoint: A = BallY

; --- fire: restart at game over, or shorten a waiting serve ---
    LDA INPT4
    AND #$80
    BNE ReadNoFire
    LDA GameState
    BNE ReadRequestRestart
    LDA ServeTimer
    BEQ ReadNoFire
    LDA #$01
    STA ServeTimer          ; the next ServeStep decrements to zero
ReadNoFire:

; --- game over: wait for fire, or let the demo restart after two seconds ---
    LDA GameState
    BNE ReadGameOver

; --- the joystick or the demo ---
    LDA SWCHA
    AND #$C0                ; P0 left/right (bits 6/7), active low
    CMP #$C0
    BEQ ReadNoDirection
    LDA #$00
    STA DemoTimer           ; a direction takes over; reset the demo timer
    LDA SWCHA
    AND #$40                ; left
    BNE ReadMoveRight
    LDA PaddleX
    SEC
    SBC #PADDLE_SPEED
    CMP #PADDLE_MIN
    BCS ReadStoreLeft
    LDA #PADDLE_MIN
ReadStoreLeft:
    STA PaddleX
    RTS
ReadMoveRight:
    LDA SWCHA
    AND #$80                ; right
    BNE ReadDone
    LDA PaddleX
    CLC
    ADC #PADDLE_SPEED
    CMP #(PADDLE_MAX + 1)
    BCC ReadStoreRight
    LDA #PADDLE_MAX
ReadStoreRight:
    STA PaddleX
    RTS

ReadNoDirection:
    LDA Frame
    AND #$01
    BNE ReadDemoTick
    INC DemoTimer           ; one count every two frames
ReadDemoTick:
    LDA DemoTimer
    CMP #(AUTO_START / 2)   ; 60 counts = 120 frames = 2 seconds
    BCC ReadDone
    JSR AutoPaddle
    LDA DemoTimer
    CMP #DEMO_LEVEL
    BNE ReadDone
    LDA #(AUTO_START / 2)   ; keep the demo active after the skip
    STA DemoTimer
    LDA #$FE                ; ask the top-level VBLANK for the level advance
    STA Temp
ReadDone:
    RTS

; --- game over: fire (or the demo after two seconds) restarts ---
ReadGameOver:
    LDA Frame
    CMP #AUTO_START
    BCC ReadDone
    ; fall into the request
ReadRequestRestart:
    LDA #$FF                ; ask the top-level VBLANK for the restart
    STA Temp
    RTS

; =============================================================================
; AUTO PADDLE — track the ball at up to four pixels per frame
; =============================================================================
; The target is the paddle position that puts the paddle's centre three
; pixels to one side of the ball's centre: BallX - 5, or BallX + 1.  The
; side alternates with Frame bit 5 so the paddle hit keeps changing the
; ball's angle.  The target is clamped to 8..152 and the paddle moves at
; most PADDLE_SPEED pixels toward it.
AutoPaddle:
    LDA Frame
    AND #$20
    BEQ AutoAimLeft
    LDA BallX
    CLC
    ADC #1
    JMP AutoClamp
AutoAimLeft:
    LDA BallX
    SEC
    SBC #5
    BCS AutoClamp
    LDA #0
AutoClamp:
    CMP #PADDLE_MIN
    BCS AutoClampHigh
    LDA #PADDLE_MIN
    JMP AutoTargetReady
AutoClampHigh:
    CMP #(PADDLE_MAX + 1)
    BCC AutoTargetReady
    LDA #PADDLE_MAX
AutoTargetReady:
    STA Temp
    CMP PaddleX
    BEQ AutoDone
    BCC AutoMoveLeft
    LDA PaddleX
    CLC
    ADC #PADDLE_SPEED
    CMP #(PADDLE_MAX + 1)
    BCC AutoStoreRight
    LDA #PADDLE_MAX
AutoStoreRight:
    STA PaddleX
    RTS
AutoMoveLeft:
    LDA PaddleX
    SEC
    SBC #PADDLE_SPEED
    CMP #PADDLE_MIN
    BCS AutoStoreLeft
    LDA #PADDLE_MIN
AutoStoreLeft:
    STA PaddleX
AutoDone:
    RTS

; =============================================================================
; SERVE STEP — count the parked frames; at zero the ball launches upward
; =============================================================================
ServeStep:
    LDA GameState
    BNE ServeStepDone
    LDA ServeTimer
    BEQ ServeStepDone
    DEC ServeTimer
    BNE ServeStepDone
    JSR GetSpeed            ; A = 2, 3 or 4
    EOR #$FF
    CLC
    ADC #1
    STA BallVY              ; the launch: straight up at the level's speed
ServeStepDone:
    RTS

; =============================================================================
; GET SPEED — A = 2 at level 0, 3 at levels 1-2, 4 from level 3 on
; =============================================================================
GetSpeed:
    LDA Level
    BEQ SpeedIsTwo
    CMP #3
    BCS SpeedIsFour
    LDA #3
    RTS
SpeedIsTwo:
    LDA #2
    RTS
SpeedIsFour:
    LDA #4
    RTS

; =============================================================================
; BALL STEP — the latches, the motion, the paddle, the bricks, the miss
; =============================================================================
; Temp is the "brick cleared" flag (set to 1 only on a real brick removal).
; The paddle and brick latches are read first, then CXCLR clears them for the
; next frame.  The ball's motion happens after the paddle test, so a paddle
; hit can move the ball out of the paddle before the next frame's latch.
BallStep:
    LDA GameState
    BNE BallFrozen
    LDA ServeTimer
    BNE BallFrozen

; --- the paddle latch: CXP0FB bit 6, only while the ball is moving down ---
    LDA CXP0FB
    AND #$40
    BEQ BallCheckBrick
    LDA BallVY
    BMI BallCheckBrick      ; moving up: a stale overlap, not a hit
    JSR PaddleBounce
    JMP BallClearLatch

BallCheckBrick:
    LDA CXBLPF
    AND #$80
    BEQ BallClearLatch
    LDA BallVY
    BPL BallClearLatch      ; moving down: a stale overlap, not a hit
    JSR BrickCollision

BallClearLatch:
    LDA #$00
    STA CXCLR               ; the latches are read; start the next frame clean

; --- the horizontal and vertical motion ---
    LDA BallX
    CLC
    ADC BallVX
    STA BallX
    LDA BallY
    CLC
    ADC BallVY
    STA BallY

; --- the left and right walls at X=4 and X=152 ---
    LDA BallX
    CMP #BALL_LEFT
    BCS BallCheckRight
    LDA #BALL_LEFT
    STA BallX
    JSR ReverseVX
BallCheckRight:
    LDA BallX
    CMP #(BALL_RIGHT + 1)
    BCC BallCheckTop
    LDA #BALL_RIGHT
    STA BallX
    JSR ReverseVX

; --- the top wall at Y=15 (the ball passes the play-area top at 63) ---
BallCheckTop:
    LDA BallY
    CMP #BALL_TOP
    BCS BallCheckMiss
    LDA #BALL_TOP
    STA BallY
    JSR ReverseVY

; --- the miss: the ball's top passed the last play line ---
BallCheckMiss:
    LDA BallY
    CMP #(BALL_BOTTOM + 1)
    BCC BallStepDone
    JMP LifeLostHandler
BallStepDone:
    RTS

BallFrozen:
    LDA #$00
    STA CXCLR
    RTS

; =============================================================================
; PADDLE BOUNCE — the five angle zones set VX; VY always goes up
; =============================================================================
; The ball's centre (BallX+2) is compared with the paddle's centre
; (PaddleX+4): the offset plus three is a 0..10 index.  The zone boundaries
; give the five zones 2,2,3,2,2 pixels wide.  VY is set to -speed and the
; ball is moved to PaddleY-4 so the next frame's latch is clean.
PaddleBounce:
    LDA BallX
    SEC
    SBC PaddleX
    CLC
    ADC #3                  ; 0..10 (the ball spans -3..+7 around the paddle)
    CMP #2
    BCC PaddleZone0
    CMP #4
    BCC PaddleZone1
    CMP #7
    BCC PaddleZone2
    CMP #9
    BCC PaddleZone3
    LDX #4
    JMP PaddleZoneReady
PaddleZone0:
    LDX #0
    JMP PaddleZoneReady
PaddleZone1:
    LDX #1
    JMP PaddleZoneReady
PaddleZone2:
    LDX #2
    JMP PaddleZoneReady
PaddleZone3:
    LDX #3
PaddleZoneReady:
    ; choose the slow, fast or turbo angle table from Level
    LDA Level
    BEQ PaddleSlow
    CMP #3
    BCS PaddleTurbo
    LDA PaddleAngleFast,X
    JMP PaddleAngleHave
PaddleSlow:
    LDA PaddleAngleSlow,X
    JMP PaddleAngleHave
PaddleTurbo:
    LDA PaddleAngleTurbo,X
PaddleAngleHave:
    STA BallVX
    JSR GetSpeed
    EOR #$FF
    CLC
    ADC #1
    STA BallVY              ; up at the level's speed
    LDA #(PADDLE_Y - 4)
    STA BallY               ; just above the paddle
    RTS

; =============================================================================
; BRICK COLLISION — the row, the unique column, the mask bit, the bounce
; =============================================================================
; On entry Y is free and Temp is 0 (the top level's "brick cleared" flag).
; The row stays in Y through the whole routine: the column math uses A and X
; only, and the mask lookups use BrickMap,Y.  A hit on an already-empty brick
; returns without touching Temp, so the top level does not score it.
BrickCollision:
    ; row = (BallY - 15) / 8
    LDA BallY
    SEC
    SBC #BRICK_TOP
    BCS BrickRowOK
    LDA #0
BrickRowOK:
    LDY #0
BrickDiv8:
    CMP #8
    BCC BrickRowDone
    SBC #8
    INY
    BNE BrickDiv8
BrickRowDone:
    TYA
BrickHit:                   ; checkpoint: A = the brick row 0-5
    ; the ball's centre X
    LDA BallX
    CLC
    ADC #2
    CMP #80
    BCS BrickRightHalf

    ; left half: col = (centre - 8) / 12
    SEC
    SBC #8
    BCS BrickLeftOK
    LDA #0
BrickLeftOK:
    LDX #0
BrickDiv12:
    CMP #12
    BCC BrickColReady
    SBC #12
    INX
    BNE BrickDiv12
    JMP BrickColReady

    ; right half: col = 5 - ((centre - 80) / 12)
BrickRightHalf:
    SEC
    SBC #80
    BCS BrickRightOK
    LDA #0
BrickRightOK:
    LDX #0
BrickDiv12R:
    CMP #12
    BCC BrickRightDone
    SBC #12
    INX
    BNE BrickDiv12R
BrickRightDone:
    TXA
    EOR #$FF
    CLC
    ADC #6                  ; 5 - X
    CMP #6                  ; the far-right gap can index past col 5
    BCC BrickRightClamp
    LDA #5
BrickRightClamp:
    TAX
BrickColReady:
    ; test the brick's bit: bit 5 = leftmost column
    LDA BrickMap,Y
    AND BitTable,X
    BEQ BrickNoHit
    ; clear the bit (it is set, so EOR clears it)
    LDA BrickMap,Y
    EOR BitTable,X
    STA BrickMap,Y
BrickClear:                 ; checkpoint: A = the new 6-bit mask
    DEC BricksLeft

    ; the brick's left edge, to decide whether the ball also reverses VX
    LDA BallX
    CLC
    ADC #2
    STA CurP0               ; the ball's centre
    CMP #80
    BCS BrickEdgeRight
    LDA BrickLeftEdges,X
    JMP BrickEdgeHave
BrickEdgeRight:
    LDA BrickRightEdges,X
BrickEdgeHave:
    STA Temp                ; the brick's left edge
    LDA CurP0
    SEC
    SBC Temp                ; centre - edge
    CMP #3
    BCC BrickNearEdge       ; 0..2: near the left edge
    CMP #5
    BCC BrickNoXFlip        ; 3..4: the middle of the brick
    CMP #8
    BCS BrickNoXFlip        ; 8+: outside the brick's 8 pixels
BrickNearEdge:              ; 5..7: near the right edge
    LDA BallVX
    EOR #$FF
    CLC
    ADC #1
    STA BallVX
BrickNoXFlip:
    LDA BallVY
    EOR #$FF
    CLC
    ADC #1
    STA BallVY              ; the vertical bounce
    LDA #1
    STA Temp                ; the top level calls ScoreAddOne
    RTS
BrickNoHit:
    RTS

; =============================================================================
; THE LEVEL — load a pattern, count it, and serve
; =============================================================================
LevelUp:
    INC Level
    LDA Level
LevelStart:                 ; checkpoint: A = the new Level
    JSR Mod3
    JMP LoadPattern

; A = Level mod 3
Mod3:
    LDA Level
Mod3Loop:
    CMP #3
    BCC Mod3Done
    SBC #3
    JMP Mod3Loop
Mod3Done:
    RTS

; A = the pattern index (0-2): copy its six masks into BrickMap, set
; BricksLeft from PatternCount, and park the ball at the paddle.
LoadPattern:
    TAX                     ; X = the pattern index
    TXA
    ASL
    TAY
    LDA PatternPtr,Y
    STA Temp
    LDA PatternPtr+1,Y
    STA CurP0
    LDY #5
PatternCopy:
    LDA (Temp),Y
    STA BrickMap,Y
    DEY
    BPL PatternCopy
    LDA PatternCount,X
    STA BricksLeft

    LDA #SERVE_FRAMES
    STA ServeTimer
    LDA PaddleX
    CLC
    ADC #2
    STA BallX
    LDA #(PADDLE_Y - 4)
    STA BallY
    LDA #1
    STA BallVX
    LDA #0
    STA BallVY
    RTS

; =============================================================================
; REVERSE VX / VY — two's-complement negation
; =============================================================================
ReverseVX:
    LDA BallVX
    EOR #$FF
    CLC
    ADC #1
    STA BallVX
    RTS

ReverseVY:
    LDA BallVY
    EOR #$FF
    CLC
    ADC #1
    STA BallVY
    RTS

; =============================================================================
; LIFE LOST — one life down; at zero the game is over, otherwise re-serve
; =============================================================================
LifeLostHandler:
    DEC Lives
    LDA Lives
LifeLost:                   ; checkpoint: A = the new Lives
    BNE LifeRespawn
    LDA #1
    STA GameState           ; game over; fire restarts
    LDA #0
    STA Frame               ; the demo's game-over wait starts now
    STA BallVY
    RTS
LifeRespawn:
    LDA #SERVE_FRAMES
    STA ServeTimer
    LDA PaddleX
    CLC
    ADC #2
    STA BallX
    LDA #(PADDLE_Y - 4)
    STA BallY
    LDA #1
    STA BallVX
    LDA #0
    STA BallVY
    RTS

; =============================================================================
; BUILD TABLES — the 12-byte brick row table and the 32-byte play row table
; =============================================================================
BuildTables:
    LDX #0
    LDA #$00
BuildClearBrick:
    STA BrickRowTable,X
    INX
    CPX #12
    BNE BuildClearBrick

    LDX #0
BuildClearPlay:
    STA PlayRowTable,X
    INX
    CPX #PLAY_ROWS
    BNE BuildClearPlay

    ; the ball's 4-line row in the brick field (visible lines 15-62)
    LDA BallY
    CMP #BRICK_TOP
    BCC BuildNoBrickBall
    CMP #(BRICK_TOP + 48)
    BCS BuildNoBrickBall
    SEC
    SBC #BRICK_TOP
    LSR
    LSR                     ; /4: 0..11
    TAX
    LDA BrickRowTable,X
    ORA #$01
    STA BrickRowTable,X
BuildNoBrickBall:

    ; the paddle's two 4-line rows
    LDA #PADDLE_Y
    SEC
    SBC #PLAY_TOP
    LSR
    LSR
    TAX
    LDA PlayRowTable,X
    ORA #$01
    STA PlayRowTable,X
    INX
    LDA PlayRowTable,X
    ORA #$01
    STA PlayRowTable,X

    ; the ball's 4-line row in the play area (visible lines 63-190)
    LDA BallY
    CMP #PLAY_TOP
    BCC BuildNoPlayBall
    CMP #(PLAY_TOP + 128)
    BCS BuildNoPlayBall
    SEC
    SBC #PLAY_TOP
    LSR
    LSR                     ; /4: 0..31
    TAX
    LDA PlayRowTable,X
    ORA #$02
    STA PlayRowTable,X
BuildNoPlayBall:
    RTS

; =============================================================================
; COARSE POSITIONING — the Lesson 26 divide-by-15 routines; no HMOVE here
; =============================================================================
; Input: A = the target + the object's bias.  Each routine starts on a fresh
; line, subtracts 15 until the carry clears, turns the negative remainder
; into the signed fine value, stores it in HMxx, and strobes RESxx.  The
; caller applies the fine offsets with one HMOVE.
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
; The divide's length grows with PaddleX.  A delay of 5 * (10 - coarse)
; cycles after RESP0 makes the total constant, so the trailing WSYNC and the
; HMOVE land on the same line for every paddle position.  DelayCount is a
; 160-byte table indexed by PaddleX; the 5-cycle DEY/BNE loop counts down.
    LDX PaddleX
    LDY DelayCount,X
    BEQ P0DelayDone
P0DelayLoop:
    DEY
    BNE P0DelayLoop
P0DelayDone:
    RTS

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
; THE DECODE TABLES — index a row byte to the two TIA bytes
; =============================================================================
; Index = bit 1 ball, bit 0 P0.  Each table is aligned so the indexed loads
; never cross a page.
    !align 7, 0
DecodeP0:
    !byte $00, $FF, $00, $FF
    !align 7, 0
DecodeBall:
    !byte $00, $00, $02, $02

; =============================================================================
; ENABLE BYTE — 0 -> ENABL 0, 1 -> ENABL 2 (the ball's enable bit)
; =============================================================================
    !align 2, 0
EnableByte:
    !byte $00, $02

; =============================================================================
; BIT TABLE — 1 << (5 - column), for columns 0..5
; =============================================================================
    !align 3, 0
BitTable:
    !byte $20, $10, $08, $04, $02, $01

; =============================================================================
; BRICK EDGES — the visible left edge of each unique column
; =============================================================================
BrickLeftEdges:
    !byte 8, 20, 32, 44, 56, 68
BrickRightEdges:
    !byte 144, 132, 120, 108, 96, 84

; =============================================================================
; THE PADDLE ANGLE TABLES — five zones, indexed by the hit offset
; =============================================================================
; The slow table is the level-0 table: -2,-1,0,+1,+2.  The fast and turbo
; tables scale the extremes so the ball crosses more of the field per trip.
PaddleAngleSlow:
    !byte $FE, $FF, $00, $01, $02
PaddleAngleFast:
    !byte $FD, $FE, $00, $02, $03
PaddleAngleTurbo:
    !byte $FC, $FD, $00, $03, $04

; =============================================================================
; THE LEVEL PATTERNS — six 6-bit masks each; PatternCount is the brick count
; =============================================================================
; Level0 is the opening full field (36 bricks).  Level1 is a diamond (24);
; Level2 is a checkerboard (18).  After level 2 the patterns repeat faster.
Level0:
    !byte $3F, $3F, $3F, $3F, $3F, $3F
Level1:
    !byte $0C, $1E, $3F, $3F, $1E, $0C
Level2:
    !byte $15, $2A, $15, $2A, $15, $2A
PatternCount:
    !byte 36, 24, 18
PatternPtr:
    !word Level0, Level1, Level2

; =============================================================================
; DELAYCOUNT — the P0 positioner's fixed-length delay, indexed by PaddleX
; =============================================================================
; value = 10 - floor((PaddleX + 3) / 15); the DEY/BNE loop costs 5 cycles per
; unit, exactly the divide loop's 5-cycle SBC/BCS step.  The table is page
; aligned so the indexed load takes the same 4 cycles for every PaddleX.
    !align 255, 0
DelayCount:
    !byte $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $09, $09, $09, $09
    !byte $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $08, $08, $08, $08, $08
    !byte $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $07, $07, $07, $07, $07
    !byte $07, $07, $07, $07, $07, $07, $07, $07, $07, $06, $06, $06, $06, $06, $06, $06
    !byte $06, $06, $06, $06, $06, $06, $06, $06, $05, $05, $05, $05, $05, $05, $05, $05
    !byte $05, $05, $05, $05, $05, $05, $05, $04, $04, $04, $04, $04, $04, $04, $04, $04
    !byte $04, $04, $04, $04, $04, $04, $03, $03, $03, $03, $03, $03, $03, $03, $03, $03
    !byte $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02
    !byte $02, $02, $02, $02, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
    !byte $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

; =============================================================================
; BRICKPF — the 64-entry x 3-byte brick table (192 bytes)
; =============================================================================
; Three 64-byte columns.  Entry m is the PF0/PF1/PF2 triple for the 6-bit row
; mask m; entry 0 is an empty row and entry $3F is the full 12-brick row.
    !align 255, 0
BrickPF0:
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0
    !align 63, 0
BrickPF1:
    !byte $00, $00, $00, $00, $01, $01, $01, $01
    !byte $0C, $0C, $0C, $0C, $0D, $0D, $0D, $0D
    !byte $60, $60, $60, $60, $61, $61, $61, $61
    !byte $6C, $6C, $6C, $6C, $6D, $6D, $6D, $6D
    !byte $00, $00, $00, $00, $01, $01, $01, $01
    !byte $0C, $0C, $0C, $0C, $0D, $0D, $0D, $0D
    !byte $60, $60, $60, $60, $61, $61, $61, $61
    !byte $6C, $6C, $6C, $6C, $6D, $6D, $6D, $6D
    !align 63, 0
BrickPF2:
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D
    !byte $00, $60, $0C, $6C, $01, $61, $0D, $6D

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
> `lessons/part10-capstones/70-breakout/70-breakout.asm`.

### Code Walkthrough

#### Step 1 — The frame and the VBLANK budget

`StartFrame` is the first VSYNC line (scanline 259). `+vsync` produces 3 lines; `VblankStart` sets `VBLANK`, starts the 44-tick timer, clears the latched playfield and sprites, and calls `ScoreSetup`. The visible code begins at `BodyStart` (scanline 37). The VBLANK work is:

1. `ScoreSetup`: three scanlines of positioners and one `HMOVE`.
2. `ReadInput`: the three observation reads, the fire check, the joystick, the auto-demo.
3. `ServeStep`: decrement the serve timer; at zero, launch.
4. `BallStep`: the paddle and brick latches, `CXCLR`, the motion, the walls, the miss.
5. `ScoreAddOne` if a brick was cleared.
6. `LevelUp` if `BricksLeft=0`.
7. `BuildTables`: the 12-byte brick row table and the 32-byte play row table.

The timer is 2,753 cycles. The score positioners take ~228; the game logic and the two table builds fit with room. `+wait_timer`'s final `WSYNC` absorbs the remainder into the measured 37-line VBLANK.

#### Step 2 — The input, the fire edge, and the auto-demo

`ReadInput` starts with the three observation reads:

```asm
    LDA PaddleX
PaddleXRead:                ; checkpoint: A = PaddleX
    LDA BallX
BallXRead:                  ; checkpoint: A = BallX
    LDA BallY
BallYRead:                  ; checkpoint: A = BallY
```

The fire check is level-sensitive: a held fire restarts at game over or shortens a waiting serve. The joystick path reads `SWCHA & $C0`; `$C0` means no direction, anything else resets `DemoTimer` and moves the paddle 4 pixels with the 8..152 clamp. `ReadNoDirection` increments `DemoTimer` once every two frames (`Frame & 1`), starts `AutoPaddle` at 60 counts, and at 240 counts calls `LevelUp` for the disclosed demo skip.

`AutoPaddle` aims at `BallX - 5` or `BallX + 1` (the paddle's centre three pixels to one side of the ball's centre) and moves at most four pixels toward the target. The alternating aim is what keeps the ball from settling into one vertical column.

#### Step 3 — The score band

`ScoreDraw` is called at `BodyStart` before any play-area work. It consumes nine visible lines: the setup/blank line 0, the eight glyph rows on lines 1-8, and a cleanup that spills into line 9. `ScoreDone` is at scanline 46. The library needs `NUSIZ0=NUSIZ1=3`, VDEL on, and P0/P1 at 56/64 — all of which `ScoreSetup` did in VBLANK.

#### Step 4 — The blank line and the five-line positioner

`ScoreDone` runs on the blank line 9. It sets `NUSIZ0=0`, clears the playfield and `ENABL`, and sets `COLUP0=C_PADDLE`. The ball was already positioned in VBLANK, before `ScoreSetup`, so its `HMBL`/`RESBL` were applied by the score's `HMOVE`; the visible block therefore positions only P0:

```asm
    LDA PaddleX
    CLC
    ADC #PADDLE_BIAS
    JSR SetCoarseP0         ; the P0 divide, one line
    STA WSYNC               ; line 48 -> the HMOVE line
    STA HMOVE               ; the HMOVE line's HBLANK
```

`SetCoarseP0` adds a fixed-length delay after `RESP0` (`DelayCount`, indexed by `PaddleX`): the divide grows with the paddle position, and the delay is `5 × (10 - coarse)` cycles, so the trailing `WSYNC` and the `HMOVE` land on the same line for every `PaddleX`. Without it, a paddle at X≥102 or a ball at X≥146 pushed the next `WSYNC` into the following line and the frame grew to 263/264.

The 42-cycle fill keeps the `WSYNC` store before the end of the line; a `WSYNC` written late still halts to the next line, which is why the fill is fixed-length. The `BrickStart` setup runs on the fifth line (picture 14); its `WSYNC` ends that line, and the brick kernel starts on picture 15 (scanline 52).

#### Step 5 — The brick kernel

The brick kernel is six iterations of an 8-line row. The row's first line is the busy one:

```asm
BrickRowLoop:
    LDY Temp
    LDX BrickMap,Y          ; the row's 6-bit mask (X = the PF index)
    LDA CurP0
    STA ENABL               ; the first 4-line half's ball bit
    LDA BrickPF0,X
    STA PF0
    LDA BrickPF1,X
    STA PF1
    LDA BrickPF2,X
    STA PF2
```

`Temp` is the brick row (0-5); `CurP0` is the precomputed `ENABL` byte. The mask indexes the three PF columns directly. After the PF2 store, the code computes the second half's `ENABL` (`BrickRowTable+1`), waits four lines, writes it, prepares the next row's first-half `ENABL` during line 5, waits four more lines, and on line 8 blanks the PF for the vertical gap. The last row branches to `PlayStart` on its line 8.

#### Step 6 — The play kernel and the row table

The play kernel is 32 iterations of a 4-line row. Each row reads `PlayRowTable,X`, decodes bit 0 to `GRP0` and bit 1 to `ENABL`, clears the playfield, and waits four lines. The fourth line decodes the next row. The table is built in VBLANK: the paddle rows are `(179-63)>>2 = 29` and 30; the ball's row is `(BallY-63)>>2` when `BallY` is in 63..190.

The play kernel's setup line is picture 62; the 32 play rows are four lines each (picture 63-190). The paddle at rows 29-30 and the ball land on the specified lines.

#### Step 7 — The brick collision

`BallStep` reads `CXBLPF` bit 7 before it clears the latches. It requires the ball to be moving up, then `BrickCollision` computes the row, the unique column, the mask bit, and the edge check. The first hit on a set bit clears the bit, decrements `BricksLeft`, sets the score flag, and reverses `VY` (and `VX` near an edge). A hit on a clear bit is ignored.

The top-level VBLANK checks the flag and calls `ScoreAddOne` — never inside `BallStep`, so the score library's stack use stays inside the `$F9-$FF` window. If `BricksLeft` reached zero, `LevelUp` runs after the score.

#### Step 8 — The paddle, the miss, and the level

`PaddleBounce` computes the five-zone offset, selects the slow/fast/turbo angle table from `Level`, sets `VX`, sets `VY=-speed`, and moves the ball to `PaddleY-4`. The miss path decrements `Lives`; at zero it sets `GameState=1` and resets the demo timer; otherwise it re-serves. `LevelUp` increments `Level`, computes `Level mod 3`, loads the pattern and its count, and re-serves.

## What You Should See

The screen is black. The score band at the top has six white digits: `000000` at power-on. Below it, after a blank line and the five positioner lines, the brick field is six rows of orange bricks — twelve visible per row, with a one-line gap between rows. The ball is white (orange while it is inside the brick field, where it shares the bricks' colour), the paddle is green, and the score is white.

The first serve starts after one second: the ball leaves the paddle at `PaddleX+2`, drifts right at one pixel per frame, and reaches the bottom brick row at about two seconds. The paddle follows the ball after two seconds of no input. A brick hit scores one, clears the brick, and bounces the ball down; a hit near the brick's edge also flips `VX`. A miss costs a life; at zero the game waits for fire (or the demo restarts after two seconds). Clearing a pattern advances the level: the full field, then the diamond, then the checkerboard, with a faster ball each time. At eight seconds the demo advances the pattern, so the ten-second capture shows the second level.

The three captures are from the committed ROM:

![Breakout's opening field: the score 000000, six rows of twelve orange bricks, the green paddle near the bottom, and the white ball mid-court](/images/lesson70/bricks-start.png)

*The opening field, about 2 s after power-on. The score is 000000, all 72 visible bricks are present, the paddle is at TIA X≈60, and the ball is at TIA X≈89.*

![Breakout's broken field: the score 000002, two unique bricks gone from the bottom row (four visible halves), the paddle at the left, and the ball in the play area](/images/lesson70/bricks-broken.png)

*The broken field, about 6 s after power-on. The score is 000002; the two hits have removed two unique bricks (four visible halves) from the bottom row. The paddle is at TIA X≈12 and the ball at X≈14.*

![Breakout's second pattern: the score 000004 and the diamond brick pattern (rows of 4, 8, 12, 12, 8 and 4 visible bricks)](/images/lesson70/level-two.png)

*The second pattern, about 10 s after power-on. The auto-demo advanced the pattern at 8 s; the diamond (`Level1`) has 24 unique bricks, 48 visible. The score keeps the four points from the first level.*

<RomPlayer rom="/roms/part10-capstones/70-breakout/70-breakout.bin" title="Lesson 70 — Capstone 2: Breakout" />

*Javatari starts muted; this ROM is silent, so there is nothing to unmute.*

The debugger tells the same story. Assemble with a symbol list and break at the labelled checkpoints:

```bash
acme -f plain -l build/70-breakout.sym -o build/70-breakout.bin \
  lessons/part10-capstones/70-breakout/70-breakout.asm
grep -E "StartFrame|VblankStart|BodyStart|ScoreDone|BrickStart|PlayStart|OverscanStart" build/70-breakout.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F1B9' docs/public/roms/part10-capstones/70-breakout/70-breakout.bin
```

The measured checkpoints:

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F1B9` | 259, cycle 3 | The first VSYNC line |
| `VblankStart` | `$F1C7` | 0, cycle 5 | The first VBLANK line |
| `BodyStart` | `$F255` | 37, cycle 5 | The first picture line (the score band) |
| `ScoreDone` | `$F258` | 46, cycle 5 | The blank line after the score |
| `BrickStart` | `$F298` | 51, cycle 2 | The brick row 0 setup line |
| `PlayStart` | `$F31A` | 99, cycle 19 | The play row 0 setup line |
| `OverscanStart` | `$F388` | 229, cycle 2 | The first overscan line |
| `PaddleXRead` / `BallXRead` / `BallYRead` | `$F39D` / `$F39F` / `$F3A1` | A=`$3C` / `$3E` / `$AF` | `PaddleX=60`, `BallX=62`, `BallY=175` at the serve |
| `BrickHit` | `$F563` | A=the row (0-5) | The brick row the ball met |
| `BrickClear` | `$F5B1` | A=the new 6-bit mask | The row's mask after the clear |
| `ScoreAdd` | `$F09F` | A=the digit after the add | The score library's checkpoint |
| `LifeLost` | `$F655` | A=the new `Lives` | A miss |
| `LevelStart` | `$F5F6` | A=the new `Level` | A level advance |

The state log's first two brick hits are the ones the 6 s capture shows. `BrickHit` reports A=5 at frames 118, 236 and 354; `BrickClear` reports A=`$37`, A=`$17` and A=`$15` (the bottom row's mask loses bit 3, then bit 5, then bit 1); `ScoreAdd` reports the digit changes that take the score to 2 at frame 236 and 3 at 354. `LevelStart` reports A=1 at frame 481 — the demo's 8-second pattern advance. `PaddleXRead`, `BallXRead` and `BallYRead` report `$3C/$3E/$AF` at the first frame: the paddle at X=60, the ball parked at X=62/Y=175.

The **pixel check** of the three images:

| Image | Size | Title bar | What the pixels show |
|---|---|---|---|
| `bricks-start.png` | 1010×807 | `Stella 7.0: "70-breakout"` | TIA area 960×606 at (25,106); 6×12 = 72 orange bricks (71,232 orange pixels); the green paddle 385-432×672-695 (TIA X=60, Y=179); the white ball 559-582×482-493 (TIA X≈89); the white score 367-642×110-130 (3,060 white pixels); no cursor |
| `bricks-broken.png` | 1010×807 | `Stella 7.0: "70-breakout"` | the score 000002 (the white score pixels fall from 3,060 to 2,886); 67,296 orange pixels, 3,936 fewer than the start: two unique bricks (four visible halves) are gone from the bottom row; the green paddle 97-144×672-695 (TIA X=12); the white ball 109-132×432-446 (TIA X=14) |
| `level-two.png` | 1010×807 | `Stella 7.0: "70-breakout"` | the score 000004 (2,958 white pixels); the `Level1` diamond: rows of 4, 8, 12, 12, 8 and 4 visible bricks (47,112 orange pixels); the green paddle 913-960×672-695 (TIA X=148); the white ball 907-930×340-342 (TIA X≈147) |

The three TIA-area MD5 hashes differ (`ab3203c3d2547b9a37415aa7cd972213`, `f47c3905f56623cb60c82aa52b096b74`, `bf31023ebd52015421abb7148455326c`), so the captures are genuinely different states, not three copies of one frame. All three are 1010×807, carry the window frame and the `Stella 7.0: "70-breakout"` title bar, and show no cursor: the pointer was parked at (0,0) before each capture.

> **Capture method.** The three images are `scripts/capture-screenshot.sh` captures of the
> committed `docs/public/roms/part10-capstones/70-breakout/70-breakout.bin` on display `:0`
> (the mutter window manager supplies the title bar) at two, six and ten wall-clock seconds,
> with `xdotool mousemove 0 0` before each. The emulator's start-up takes the first fraction
> of a second, so the 2 s image is about ROM frame 85, the 6 s image about frame 330, and the
> 10 s image about frame 580; the images themselves show 000000, 000002 and 000004. The
> auto-demo makes the states deterministic, and the pattern advances at frame 481 (about 8 s).
> Three deliberate choices are disclosed: (1) the ball's ceiling is the top of the brick
> field (Y=15), not the play-area top (Y=63), because the ball must cross Y=63 to reach the
> bricks; (2) the paddle's Y is the constant 179 and the freed byte is `DemoTimer`, because
> the 14-byte map has no room for both; (3) the eighth line of each brick row is blanked to
> give the bricks a one-line vertical gap. The play kernel's setup line is picture 62 and the
> 32 play rows are four lines each.
>
> **Restart and level clear.** The game-over restart is observed: the main's post-restart
> demo skip fires `LevelStart` at frame 1261 after the game over at frame 660, and the
> exercise-2 solution's post-restart skip fires `LevelStart` at frame 1021 after its own
> game over at frame 660. The natural `BricksLeft=0` level clear is code-verified, not
> observed in one run; the other `LevelStart` observation is the demo's 8 s shortcut at
> frame 481.

## Exercises

Each exercise ships a source (`exercise-NN-solution.asm`) that assembles to a 4,096-byte ROM (`exercise-NN-solution.bin`). The solutions build through `npm run roms`, run in Stella, and actually solve the exercise as written. The exercise sources keep the main's frame and checkpoints; the frame logs below are from the committed solutions.

### Exercise 1: Multi-hit bricks

**Challenge:** Give every brick two hit points. A 6-byte HP map (one bit per unique brick) remembers the first hit: the brick stays on screen, its row turns darker, and the hit scores 1. The second hit clears the brick map bit, removes the brick, and scores 2. The 6-byte `BrickRowTable` now carries two bits per brick row (bit 0 = the ball is in the first 4-line half, bit 1 = the second half), and bit 7 is the row's damage flag.

**Hints:**
1. The HP map is 6 bytes, one bit per unique brick, bit 5 = leftmost, the same bit order as `BrickMap`. Put it at `$8C-$91`, immediately after the 6-byte `BrickRowTable` at `$86-$8B`.
2. The brick kernel's `ENABL` needs the ball's half: `LDA BrickRowTable,Y; AND #$02` for the second half, `AND #$01; ASL` for the first. The first half's value is precomputed in `BrickStart`; the second half's is prepared during line 1 and written on line 5.
3. The collision tests `BrickHP,Y` before `BrickMap,Y`. A set HP bit is the first hit: clear it, keep the brick bit, set the score flag to 1. A clear HP bit is the final hit: clear the brick bit, decrement `BricksLeft`, set the flag to 2.
4. The top-level VBLANK turns the flag into 1 or 2 `ScoreAddOne` calls; the library's `ScoreAdd` checkpoint fires once per call.
5. The row colour change uses a damage bit: when a brick takes its first hit, set bit 7 of `BrickRowTable+row`; the gap line chooses `C_BRICK_HIT` for a row with bit 7 set. `LoadPattern` clears the six row-table bytes so a new pattern starts fresh.
6. The bounce code uses `Temp` for the score flag; do not let the edge check overwrite it. Compute `centre - edge` as `~edge + centre + 1` instead of a scratch byte.

**Expected Result:** The source assembles to a 4,096-byte ROM (`exercise-01-solution.bin`), and the frame is still 259/37/46/51/99/229. The first three hits report `HpHit` A=`$37`, `$17` and `$15` at frames 118, 236 and 354 — one point each, and row 5 is the darker `$26` from the first hit. The final hit reports `BrickClear` A=`$37` at frame 471 and scores 2 more. At 10 s the score reads `000005` after three first hits and one final hit.

**Solution:** See `exercise-01-solution.asm`.

The two-hit branch is a short extension of the brick collision:

```asm
    LDA BrickMap,Y
    AND BitTable,X
    BEQ BrickNoHit
    LDA BrickHP,Y
    AND BitTable,X
    BEQ BrickSecondHit
    ; first hit: keep the brick, clear the HP bit, score 1
    LDA BrickHP,Y
    EOR BitTable,X
    STA BrickHP,Y
HpHit:                      ; checkpoint: A = the new HP mask
    LDA BrickRowTable,Y
    ORA #$80                ; the row's damage bit
    STA BrickRowTable,Y
    LDA #1
    STA Temp
    JMP BrickBounce
BrickSecondHit:
    LDA BrickMap,Y
    EOR BitTable,X
    STA BrickMap,Y
BrickClear:                 ; checkpoint: A = the new brick mask
    DEC BricksLeft
    LDA #2
    STA Temp
```

The state log on the committed solution:

```text
# HpHit: the three first hits (row 5, three different bricks)
BP:         118   9 49  79 | nv-BdIzc 37 02 05 fb |
BP:         236   8 54  94 | nv-BdIzc 17 00 05 fb |
BP:         354  10 39  49 | nv-BdIzc 15 04 05 fb |

# BrickClear: the final hit on the brick first hit at frame 118
BP:         471  10 51  85 | nv-BdIzc 37 02 05 fb |

# The frame at the reset defaults
BP:           2 259 03 -59 | nv-BdIZC 00 00 00 ff |
BP:           3  51 02 -62 | nv-BdIZC 28 00 00 ff |
BP:           3  99 19 -11 | nv-BdIZC 05 0a 06 ff |
BP:           3 229 02 -62 | nv-BdIZC 28 00 00 ff |
```

A scratch Stella capture at 3 s shows the bottom row's brick colour is `(173,111,38)` (`$26`), while rows 0-4 are `(189,134,50)` (`$28`) — the once-hit row is visibly darker. A scratch capture at 10 s reads `000005`.

### Exercise 2: Level progression

**Challenge:** Make the level transition visible. The two leftmost score digits show the current level (`01`, `02`, …) and the four rightmost digits show the brick score. Clearing a pattern shows a 60-frame banner — a bright playfield bar across the middle of the play area, with the paddle and ball hidden — then the next pattern starts with its faster ball.

**Hints:**
1. `LoadPattern` already loads the pattern and the count; `LevelUp` already increments `Level`. Add the level display after the load: divide `Level+1` by ten and call `ScoreSetDigit` for positions 0 (tens) and 1 (ones).
2. Use `Frame` as the banner timer: `LevelUp` sets it to 60; the VBLANK decrements it; the play kernel draws the bar while it is non-zero. Frame is the banner countdown (it no longer counts frames): the auto-demo's start, its aim parity and the game-over wait use `DemoTimer`. At game over, `ReadGameOver` increments `DemoTimer` itself, because the play path that normally increments it is skipped; the game-over path also clears `Frame`, so a banner left over from the last life does not persist.
3. The banner is play rows 12-15 (16 lines). Branch on the banner *first*: on rows 12-15 store `PF0`/`PF1`/`PF2 = $FF` before the (hidden) `GRP0`/`ENABL` stores, so the bar's first line meets the PF0/PF1 deadlines; on the other rows store the sprites first and clear the PF. The playfield is blank on the other rows.
4. Hide the paddle and ball while the banner is up: `BuildTables` skips the paddle/ball table writes when `Frame` is non-zero.
5. Keep the auto-demo's level skip as the deterministic way to reach level 2 (the demo cannot clear 36 bricks in ten seconds). `DemoTimer` counts frames: the demo starts at 120 and the skip fires at 240 (four seconds). Its aim parity is `DemoTimer` bit 5, so it keeps alternating; `Frame` belongs to the banner.
6. `ScoreAddOne` adds at digit 5 and only carries into the level digits after 9999 points; a normal game never reaches that.

**Expected Result:** The source assembles to a 4,096-byte ROM (`exercise-02-solution.bin`), and the frame is still 259/37/46/51/99/229. `LevelStart` reports A=1 at frame 241, A=2 at frame 361 and A=3 at frame 481. At about 4.8 s the high score digits read `02`, the banner bar spans the play area (16 solid lines of `$FF` playfield, first line included), and the paddle and ball are absent. At 10 s the high digits read `04` and the brick field is the pattern for that level.

**Solution:** See `exercise-02-solution.asm`.

The level display is a small division and two library calls:

```asm
ShowLevel:
    LDA Level
    CLC
    ADC #1                  ; the display is one-based
    LDX #0
ShowLevelDiv10:
    CMP #10
    BCC ShowLevelDivDone
    SBC #10
    INX
    JMP ShowLevelDiv10
ShowLevelDivDone:
    STA Temp                ; the ones digit
    TXA
    TAX                     ; X = the tens digit
    LDA #0                  ; position 0 = the leftmost digit
    JSR ScoreSetDigit
    LDA Temp
    TAX
    LDA #1                  ; position 1
    JSR ScoreSetDigit
    RTS
```

The banner branch comes before the sprite stores, so the bar's first line is solid:

```asm
    LDA Frame
    BEQ PlaySprites
    CPX #12
    BCC PlaySprites
    CPX #16
    BCS PlaySprites
    LDA #$FF
    STA PF0
    STA PF1
    STA PF2
    LDA #$00
    STA GRP0
    STA ENABL
    JMP PlayRowWait
PlaySprites:
    LDA CurP0
    STA GRP0
    LDA Temp
    STA ENABL
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
PlayRowWait:
```

The state log on the committed solution:

```text
# LevelStart
BP:         241   6 22  -2 | nv-BdIzC 01 20 00 fd |
BP:         361   6 39  49 | nv-BdIzC 02 20 00 fd |
BP:         481   6 23   1 | nv-BdIzC 03 20 00 fd |

# StartFrame / BrickStart / PlayStart / OverscanStart
BP:           2 259 03 -59 | nv-BdIZC 00 00 00 ff |
BP:           3  51 02 -62 | nv-BdIZC 28 00 00 ff |
BP:           3  99 19 -11 | nv-BdIZC 05 0a 06 ff |
BP:           3 229 02 -62 | nv-BdIZC 28 00 00 ff |
```

A scratch Stella capture at about 4.8 s shows the high digits `02` (the scratch capture reads `020002`) and a solid white bar across the play area, first line included, with the paddle and ball absent. At 10 s the high digits read `04`.

### Exercise 3: Paddle angle and power-up

**Challenge:** Keep the five-zone paddle angle and add a power brick. Hitting the bottom row's left-centre brick (row 5, unique column 2) starts a 300-frame power-up: `NUSIZ0` becomes 5 (P0 double width, a continuous 16-pixel paddle), and every brick scores twice.

**Hints:**
1. The main already has the five-zone angle (`PaddleAngleSlow/Fast/Turbo` indexed by the hit offset); the exercise adds only the power-up.
2. Use `PowerTimer` (`$97`) as the power timer: the trigger sets it to 150, and the VBLANK decrements it when the free-running `Frame` bit 0 is clear — 150 × 2 = 300 frames, independent of steering. `Frame` is the free-running frame counter (the auto-demo is not used in this exercise), so the joystick cannot shorten the power-up.
3. In `BrickCollision`, after `STA BrickMap,Y`, compare `Y` with the power row and `X` with the power column; on a match, `LDA #150; STA PowerTimer`. Put the `PowerUp` checkpoint on the `STA PowerTimer` so A=150.
4. The wide paddle is `NUSIZ0=5` while `PowerTimer` is non-zero, set on the blank line (`ScoreDone`). NUSIZ 5 stretches P0 to double width: one continuous 16-pixel block. `CXP0FB` sees the widened player, so no new collision code is needed.
5. The 2× score is a second `ScoreAddOne` in the top-level VBLANK while `PowerTimer` is non-zero.
6. The paddle's X clamp can stay 8..152; at the right edge the double-width player extends past the screen edge, but its visible half still catches the ball. The game-over wait uses the free-running `Frame` (reset at game over), so the auto-restart still runs; the game-over path also clears `PowerTimer`, so a power-up left over from the last life does not persist.

**Expected Result:** The source assembles to a 4,096-byte ROM (`exercise-03-solution.bin`), and the frame is still 259/37/46/51/99/229. `PowerUp` reports A=`$96` (150) at frame 118, when the ball first hits the bottom row's column-2 brick. A scratch 6 s capture shows the continuous 16-pixel paddle and the score `000004` (two bricks × 2). The 2× multiplier lasts 300 frames (five seconds) regardless of steering; after it expires the paddle is one P0 copy again.

**Solution:** See `exercise-03-solution.asm`.

The power trigger and the 2× score:

```asm
BrickClear:                 ; checkpoint: A = the new 6-bit mask
    DEC BricksLeft
    CPY #POWER_BRICK_ROW    ; the bottom row
    BNE NoPowerBrick
    CPX #POWER_BRICK_COL    ; unique column 2
    BNE NoPowerBrick
    LDA #POWER_TICKS        ; 150 two-frame ticks = 300 frames
PowerUp:                    ; checkpoint: A = 150
    STA PowerTimer
NoPowerBrick:
    ; ... the bounce

; in the top-level VBLANK:
    JSR ScoreAddOne
    LDA PowerTimer
    BEQ NoBrickScore
    JSR ScoreAddOne         ; the 2x multiplier
```

The state log on the committed solution:

```text
# PowerUp
BP:         118   9 37  43 | Nv-BdIzC 96 02 05 fb |

# StartFrame / BrickStart / PlayStart / OverscanStart
BP:           2 259 03 -59 | nv-BdIZC 00 00 00 ff |
BP:           3  51 02 -62 | nv-BdIZC 28 00 00 ff |
BP:           3  99 19 -11 | nv-BdIZC 05 0a 06 ff |
BP:           3 229 02 -62 | nv-BdIZC 28 00 00 ff |
```

A scratch Stella capture at 6 s shows one continuous green paddle block 16 TIA pixels wide, and the score reads `000004` after two brick hits under the multiplier.

## Key Takeaways

- ✅ **A field plus moving objects is a zone kernel.** Nine score lines, a 48-line playfield zone, a 128-line row-table play area, and a blank line make 192. Each zone has its own timing contract; the ball crosses two of them.
- ✅ **The brick map is 6 bytes and the PF table is 192.** Six unique bricks per row, mirrored to twelve by reflect mode; the 64-entry × 3-byte table turns a mask into `PF0`/`PF1`/`PF2` with three indexed loads and no multiply.
- ✅ **The collision is one row and one unique column.** `(BallY-15)/8` and `(centre-8)/12` (or `5-((centre-80)/12)`) with the `CXBLPF` latch read one frame late and cleared with `CXCLR`. The bounce reverses `VY` and flips `VX` only near a brick edge.
- ✅ **The ball needs two schedules.** The 12-byte `BrickRowTable` enables the ball in the brick field's 4-line rows; the 32-byte `PlayRowTable` drives the paddle and the ball in the play area. Both are rebuilt in VBLANK.
- ✅ **The score library and the paddle share P0.** `ScoreSetup` every frame, the score first, one `HMOVE` to reposition P0 (the ball is positioned in VBLANK), and the score's white restored on the last blank line — not before the play area.
- ✅ **Three lives and three patterns fit one state machine.** A miss re-serves; clearing a pattern advances the level; `GetSpeed` returns 2, 3 or 4; the angle table scales with the speed.
- ✅ **A deterministic demo is part of the lesson.** The paddle tracks the ball at 4 pixels/frame with an alternating aim; the demo's eight-second pattern advance makes the ten-second capture the second level. The shortcut is disclosed.

## What's Next

Breakout proves that a playfield zone and a row-table play area can share one frame, and that the score library can coexist with a moving P0. [Lesson 71: Capstone 3 — Maze Explorer](/part10-capstones/71-maze-explorer) turns the field into a generated mirror maze: ten unique columns drawn with reflect mode, a Python generator with a committed include and a `--check` gate, two enemies with a chase AI, three keys, and a win/lose state. The brick map you just built is the maze's wall map with a different generator behind it.
