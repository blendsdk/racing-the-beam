---
title: "Lesson 69: Capstone 1 — Pong"
description: "Build a complete two-player Pong: a precomputed 89-byte row table drives a two-line kernel, a custom one-digit-per-player score keeps P0/P1 at X=64/88 before the paddles move to X=16/136, and CXP0FB/CXP1FB turn the TIA collision latches into a five-zone bounce. The lesson explains the preflight's cycle-49 GRP0 failure and proves the frame with Stella state logs."
prev:
  text: "Lesson 68: Designing Your Kernel Architecture — A Zone Framework"
  link: "/part9-dsl-path/68-kernel-architecture"
next:
  text: "Lesson 70: Capstone 2 — Breakout"
  link: "/part10-capstones/70-breakout"
---

# Lesson 69: Capstone 1 — Pong

> **Part 10: Capstone Projects** · Estimated time: 180 minutes
> **Prerequisites:** Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and memory), Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 25 (players), Lesson 26 (horizontal positioning), Lesson 28 (two players), Lesson 29 (the ball), Lesson 33 (controllers), Lesson 38 (collision detection), Lesson 39 (the scoreboard and the score library), Lesson 41 (game states), Lesson 49 (the two-line kernel), Lesson 52 (fine scrolling), Lesson 68 (the kernel framework)
> **You will learn:** how a precomputed row table turns three per-line object range tests into three table loads; why a one-line multi-object kernel writes `GRP0` too late for P0 at X=16 (the preflight's cycle-49 failure); how a two-line kernel uses a one-row lookahead so the stores land at cycles 12/18/24; how a custom one-digit-per-player score frees `$A0-$D8` for the 89-byte row table; how `CXP0FB`/`CXP1FB` bit 6, read in VBLANK and cleared with `CXCLR`, drive the paddle bounce and the five-zone angle table; how the serve parks the ball for 60 frames, fixes the first serve left, and serves toward the player who lost after a point; how the first-to-9 game-over state flashes the winning digit; and how a deterministic auto-demo produces the serve, rally, and game-over captures.
> **You will build:** **Pong**, a complete two-player, 4,096-byte ROM: two 8×24 paddles at X=16 and X=136, a 4×8 ball, an 89-row play field, a green left digit at X=64 and a blue right digit at X=88, a five-zone bounce, wall collisions at Y=8 and Y=164, a 60-frame serve, a first-to-9 match, and a flashing winner. The three exercise solutions add a CPU opponent, a four-hit speed-up, and a best-of-three match.

## Introduction

The course has spent sixty-eight lessons building the pieces. You can draw a player (Lesson 25), position it to the pixel (Lesson 26), put two players on the same lines (Lesson 28), add a ball (Lesson 29), read the joysticks (Lesson 33), detect collisions (Lesson 38), run a state machine (Lesson 41), write a two-line kernel (Lesson 49), and compose a kernel from zones (Lesson 68). The capstones are where those pieces stop being exercises and become a game.

Pong is the right first capstone because it is small enough to understand completely and demanding enough to expose the one problem every multi-object kernel meets: **the beam does not wait for your object tests.** A Pong screen has three independently moving things — two paddles and a ball — and they can be anywhere vertically. The obvious kernel tests each object's Y range on every line and stores the graphics when the line is inside the range. That kernel works for the right paddle and fails for the left one. The preflight measured why: with three range tests ahead of the `GRP0` store, the store landed at cycle 49. P0 at X=16 has its leftmost pixel at cycle (16 + 68) / 3 = 28, so the left paddle rendered the previous row's byte and was invisible while P1 at X=136 rendered perfectly.

The fix is the lesson's central idea: **precompute the whole screen's object layout into a row table before the picture starts.** One byte per two-line row, three bits: bit 0 is P0, bit 1 is P1, bit 2 is the ball. The kernel reads one byte, decodes three bits, and stores the three TIA registers at the start of the row's first line. There are no range tests in the kernel, so the stores are early enough for the leftmost object, and the second line is free for the next row's decode.

The companion program, `69-pong.asm`, is a complete two-player Pong in 4,096 bytes. Its screen is 8 score lines + 1 blank line + 5 positioner lines + 178 play lines = 192. Its frame is the course standard: 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines. Its RAM map is exact: the row table owns `$80-$D8`, the game variables `$D9-$F0`, and the stack `$F1-$FF`. The score is custom — P0 draws the left digit at X=64 and P1 the right at X=88 — because the shared score library owns `$A0-$D7` and would leave no room for the 89-byte table. After the score band both players are repositioned to X=16 and X=136, and the ball to `BallX`, with one `HMOVE`.

::: details TypeScript Equivalent

A Pong renderer in TypeScript usually keeps a framebuffer and draws rectangles into it. The 2600 has no framebuffer, so the closest model has two layers: a **row table** that describes which objects are visible on each two-line row, and a **renderer** that visits the rows in order and writes the three object bytes. The physics step is ordinary.

```typescript
// The screen is 89 rows; each row covers two scanlines.
const ROW_COUNT = 89;
const P0_X = 16, P1_X = 136, BALL_TOP = 8, BALL_BOTTOM = 164;

interface World {
  p0y: number;   // 8..148
  p1y: number;   // 8..148
  ballX: number; // 4..152
  ballY: number; // 8..164
  ballVX: number; // -2 or +2
  ballVY: number; // -2..+2
}

// The 89-byte row table: bit 0 = P0, bit 1 = P1, bit 2 = ball.
function buildRowTable(w: World): Uint8Array {
  const table = new Uint8Array(ROW_COUNT);
  const p0Row = w.p0y >> 1;
  const p1Row = w.p1y >> 1;
  const ballRow = w.ballY >> 1;
  for (let r = 0; r < 12; r++) table[p0Row + r] |= 0b001;
  for (let r = 0; r < 12; r++) table[p1Row + r] |= 0b010;
  for (let r = 0; r < 4; r++) table[ballRow + r] |= 0b100;
  return table;
}

// The two-line kernel: one row per two scanlines.
function render(table: Uint8Array): void {
  for (let row = 0; row < ROW_COUNT; row++) {
    const bits = table[row];
    const grp0 = (bits & 0b001) ? 0xff : 0x00; // P0's eight pixels
    const grp1 = (bits & 0b010) ? 0xff : 0x00; // P1's eight pixels
    const enabl = (bits & 0b100) ? 0x02 : 0x00; // the ball
    drawTwoLines(grp0, grp1, enabl);
  }
}

// One physics step.  The real code runs this in VBLANK, once per frame.
function stepBall(w: World, angle: number[]): void {
  w.ballX += w.ballVX;
  w.ballY += w.ballVY;
  if (w.ballY < BALL_TOP) { w.ballY = BALL_TOP; w.ballVY = -w.ballVY; }
  if (w.ballY > BALL_BOTTOM) { w.ballY = BALL_BOTTOM; w.ballVY = -w.ballVY; }
  if (w.ballX < 6) { scoreRight(); resetServe(w, -2); }
  if (w.ballX > 150) { scoreLeft(); resetServe(w, +2); }
}

// The paddle hit: the offset picks one of the five vertical speeds.
function bounce(w: World, paddleY: number, side: 0 | 1): void {
  let offset = Math.max(0, Math.min(20, w.ballY - paddleY));
  offset = Math.floor(offset / 5);          // 0..4
  w.ballVY = angle[offset];                  // -2,-1,0,+1,+2
  w.ballVX = side === 0 ? +2 : -2;
  w.ballX = side === 0 ? P0_X + 8 : P1_X - 4;
}
```

The model captures the shape — a row table, a row loop, a physics step, an angle table — and it breaks exactly where the 2600 differs:

- **There is no framebuffer.** `drawTwoLines` is a metaphor; the real renderer writes `GRP0`, `GRP1` and `ENABL` once per row and the beam draws those latches on two scanlines. The table is not an image; it is a schedule of three TIA writes.
- **The row table lives in RAM and is rebuilt every frame.** The 89 bytes at `$80-$D8` are cleared and re-ORed in VBLANK. A TypeScript `Uint8Array` is allocated once; the 2600 table is the same memory every frame.
- **The collision check is a hardware latch.** `CXP0FB` bit 6 is set when the ball's pixels overlap P0's pixels at any point during the frame; it stays set until `CXCLR`. The TypeScript code calls a function at the moment of the step; the real code reads the previous frame's latch at the start of VBLANK, so the hit is one frame late by construction.
- **The frame is fixed at 262 lines and one row is exactly 152 cycles.** The TypeScript `for` loop has no time budget; the real loop must fit its two lines in 152 cycles and its first-line stores must finish before P0's pixel time.
- **The score is glyphs from a ROM table, not a font engine.** `ScoreFont` holds ten 8×8 glyphs; row 7 is blank. The left digit's address is `ScoreFont + LeftScore * 8 + row`. There is no text layout.
- **The positions are TIA X positions quantized to three color clocks.** A `RESPx` strobe lands on a three-clock boundary; the fine value in `HMPx` adjusts by -8..+7. The TypeScript positions are 1:1 pixels; the 2600 cannot place every object at every X.

:::

## Theory

### Section 1: The Pong Architecture

Pong is a screen of three moving objects and a score band. The 192 visible lines split into four bands:

| Picture lines | Lines | What happens |
|---|---:|---|
| 0-7 | 8 | The score band: P0 draws the left digit at X=64, P1 the right at X=88 |
| 8 | 1 | Blank; the row-0 decode and the first positioner setup live here |
| 9-13 | 5 | The play positioners: P0 to X=16, P1 to X=136, the ball to `BallX`, one `HMOVE` |
| 14-191 | 178 | The play area: 89 rows × 2 lines, driven by the 89-byte row table |

`8 + 1 + 5 + 178 = 192`. The frame around it is the Lesson 12 skeleton: 3 VSYNC lines, 37 VBLANK lines, 192 picture lines, 30 overscan lines, 262 in all. The measured checkpoints are `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `ScoreDone` 46, `PositionDone` 51, and `OverscanStart` 229.

The game logic lives in VBLANK. In one frame it reads the joysticks, moves the paddles, reads the collision latches from the previous frame, moves the ball, checks the walls and the score, and builds the row table. The VBLANK timer is the standard 44 ticks: 2,753 cycles, about 36.2 lines. The timer plus `+wait_timer`'s final `WSYNC` absorb the remainder and make the measured 37-line VBLANK; the work fits with room for the score positioners.

The visible code is four short pieces:

1. **The score band** (8 lines): read the glyph row for each digit and store `GRP0`/`GRP1`. The band is the only place the players are at X=64/88.
2. **The blank line**: decode row 0 into `CurP0`/`CurP1`/`CurBall` and wait.
3. **The play positioners** (5 lines): three divide-by-15 coarse strobes and one `HMOVE`.
4. **The play kernel** (178 lines): 89 iterations, two lines each, one row table byte per iteration.

### Section 2: Why the Row Table — the Cycle-49 Failure

The obvious one-line kernel looks like this:

```asm
; The tempting kernel: test each object's range, then store.
    LDA BallY
    CMP Line
    BCC NoBall
    ; ... the ball's range test
    LDA P0Y
    CMP Line
    BCC NoP0
    LDA #$FF
    STA GRP0
NoP0:
    ; ... P1
    STA WSYNC
```

Every branch and every load costs cycles before the first store. The preflight built exactly this kernel and measured the result: with three range tests ahead of the `GRP0` store, the store landed at **cycle 49**. P0 at X=16 has its leftmost pixel at cycle

```text
(16 + 68) / 3 = 28
```

so the left paddle displayed the previous row's byte — black — on every line. P1 at X=136 has a deadline of (136 + 68) / 3 = 68 cycles, so it rendered. The picture looked like a one-paddle game.

The lesson is not "write the tests faster." Even a perfect set of tests costs a load, a compare and a branch per object, and the first object's store is behind all of them. The lesson is **move the decision out of the kernel**: do the range tests once per frame, in VBLANK, and store the answer in a table. The kernel then reads one byte and writes three registers. The per-row decode costs 27 cycles on the visible second line, and the whole table build costs about 1,500 cycles in VBLANK; the visible first line's stores are only 18 cycles before the WSYNC.

The table is 89 bytes, one per two-line row. Each byte has three bits:

| Bit | Object | Kernel store |
|---|---|---|
| 0 | P0 (the left paddle) | `GRP0` = `$FF` |
| 1 | P1 (the right paddle) | `GRP1` = `$FF` |
| 2 | The ball | `ENABL` = `$02` |

The build is three passes over the same table:

```asm
    ; clear the 89 bytes, then OR each object's range
    LDA P0Y
    LSR                     ; P0Row = P0Y / 2
    STA P0Row
    CLC
    ADC #PADDLE_ROWS        ; 12 rows = 24 pixels
    STA P0RowEnd
    LDX P0Row
RowP0:
    LDA RowTable,X
    ORA #$01
    STA RowTable,X
    INX
    CPX P0RowEnd
    BNE RowP0
```

The paddle is 24 pixels tall, so it covers 12 rows (`P0Y/2` through `P0Y/2 + 11`). The ball is 8 pixels tall, so it covers 4 rows. The clear pass runs once; the P0 pass 12 times, the P1 pass 12 times, the ball pass 4 times. The whole build is about 1,500 cycles — well inside the 2,753-cycle VBLANK.

::: tip The table is the level-of-detail trick
A row table is a small, general idea: precompute anything that depends only on this frame's object positions, in the horizontal blank, and let the visible kernel read the answer. The same shape drives the Lesson 70 brick field and the Lesson 71 maze. The price is RAM — 89 bytes here — and the payoff is a kernel whose per-line work is constant.
:::

### Section 3: The Two-Line Kernel and the Lookahead

The play area is 178 lines, so 89 rows of two lines. A row's objects are the same on both lines: the kernel writes the three TIA registers once, waits one line, then waits a second line. The second line is the decode slot for the *next* row.

The loop is:

```asm
PositionDone:
    LDA CurP0
    STA GRP0                ; P0's byte for this row
    LDA CurBall
    STA ENABL               ; the ball for this row
    LDA CurP1
    STA GRP1                ; P1's byte for this row
    STA WSYNC               ; line 1 of the pair

    CPX #ROW_COUNT
    BEQ KernelLastRow       ; row 88 has no next row
    LDA RowTable,X          ; decode the next row during line 2
    TAY
    LDA DecodeP0,Y
    STA CurP0
    LDA DecodeP1,Y
    STA CurP1
    LDA DecodeBall,Y
    STA CurBall
KernelLastRow:
    STA WSYNC               ; line 2 of the pair
    INX
    CPX #(ROW_COUNT + 1)
    BNE PositionDone
```

`CurP0`, `CurP1` and `CurBall` are the *current* row's TIA bytes. Before the loop, row 0 is decoded into them (on the blank line); each iteration stores them and decodes the next row for the following pair. The three decode tables are 8 bytes each:

```asm
DecodeP0:   !byte $00, $FF, $00, $FF, $00, $FF, $00, $FF
DecodeP1:   !byte $00, $00, $FF, $FF, $00, $00, $FF, $FF
DecodeBall: !byte $00, $00, $00, $00, $02, $02, $02, $02
```

Each table is aligned to an 8-byte boundary so the indexed loads never cross a page.

The cycle ledger for one pair:

| Line | Work | Cycles |
|---|---|---:|
| 1 | The previous pair's tail: `INX` 2, `CPX #90` 2, `BNE` 3 | 7 |
| 1 | `LDA CurP0` 3, `STA GRP0` 3, `LDA CurBall` 3, `STA ENABL` 3, `LDA CurP1` 3, `STA GRP1` 3, `STA WSYNC` 3 | 21 |
| 2 | `CPX #89` 2, `BEQ` 2, the decode 27, `STA WSYNC` 3 | 34 |
| **Total** | | **62 of 152** |

The pair leaves 90 cycles of margin. The stores land at cycles 12, 18 and 24 in steady state (the first row at 8, 14 and 20 because there is no tail before it). The leftmost deadlines are P0 at X=16 → 28 cycles and the ball's leftmost X=4 → 24.0 cycles; both stores are earlier (12 and 24). The preflight's cycle-49 failure is gone.

The last row skips the decode: `CPX #89` / `BEQ KernelLastRow` takes the branch, the second `WSYNC` is the only work, and the loop exits with X=90. The 89th row's two lines end at scanline 228, and the final `WSYNC` releases the CPU at 229 for the overscan.

::: warning The first line's stores are the whole design
It is tempting to move the decode onto the first line and the stores onto the second, or to test ranges directly in the kernel. Both orders push the stores past P0's deadline. The two-line kernel is not a style choice: the first line must begin with the three stores, and the second line must be the only place the next row's decode can run. If a future edit adds a range test or a `JSR` before `STA GRP0`, P0 at X=16 disappears again.
:::

### Section 4: The Input Map

`SWCHA` is the RIOT's port A. Both joysticks share it, and the hardware splits it by player:

| Bits | Player | Bit 4 / 0 | Bit 5 / 1 | Bit 6 / 2 | Bit 7 / 3 |
|---|---|---|---|---|---|
| 7-4 | P0 | up | down | left | right |
| 3-0 | P1 | up | down | left | right |

The bits are **active low**: 0 means pressed. The lesson needs only up and down, so it reads:

```asm
    LDA SWCHA
    AND #$10                ; P0 up
    BNE ...
    LDA SWCHA
    AND #$20                ; P0 down
    BNE ...
    LDA SWCHA
    AND #$01                ; P1 up
    BNE ...
    LDA SWCHA
    AND #$02                ; P1 down
    BNE ...
```

`include/vcs.asm` is the authority for the address and the bit layout. A common mistake is to assume P0 owns the low nibble; the hardware puts P0 in the high nibble and P1 in the low nibble. The lesson's `ReadInput` follows the file, and the debugger's `-holdjoy0`/`-holdjoy1` options are the quickest way to prove it: `-holdjoy0 U` moves the left paddle, `-holdjoy1 U` moves the right one.

A direction moves a paddle **2 pixels per frame**, clamped to `P0Y`/`P1Y` 8..148. The clamp is a **range test**, not an equality test: the auto-demo moves a paddle one pixel at a time, so `P0Y`/`P1Y` can be odd. From 9, an equality test at 8 would miss and the next 2-pixel step would give 7, 5, 3, 1, `$FF`; from 147 the down step would give 149, 151, … and the row-table build would write past `$D8` into the variables and the stack. The lesson's moves subtract/add 2, compare the result against 8 (up) or 149 (down), and store the bound. `BuildRowTable` also clamps both bytes as a safety net before computing the row ranges. Fire (`INPT4` bit 7, also active low) starts a waiting serve early; after game over, fire or SELECT resets the scores and serves.

### Section 5: The Ball, the Angle Table, and the Collision Latches

The ball is a 4×8 object: a 4-pixel-wide ball (CTRLPF bits 4-5 = `10`) and 8 lines tall (4 two-line rows). It has two signed velocities:

- `BallVX` is `$FE` (-2) or `$02` (+2): two pixels per frame horizontally.
- `BallVY` comes from the five-entry `AngleTable`:

```asm
AngleTable:
    !byte $FE, $FF, $00, $01, $02   ; -2, -1, 0, +1, +2
```

The index is the hit offset divided by 5:

```text
offset = BallY - PaddleY          ; 0..20 after the clamp
index  = offset / 5               ; 0..4
BallVY = AngleTable[index]
```

A hit near the top of the paddle sends the ball up (-2), the centre sends it straight (0), and the bottom sends it down (+2). The division is a short repeated-subtraction loop; the offset is clamped to 0..20 first so the index is always 0..4.

The paddle hit itself is not a geometric test in the kernel. The TIA sets **collision latches** when two objects' pixels overlap:

| Register | Bit 6 means | Bit 7 means |
|---|---|---|
| `CXP0FB` ($02) | P0 ↔ ball | P0 ↔ playfield |
| `CXP1FB` ($03) | P1 ↔ ball | P1 ↔ playfield |

The latches are set during the visible frame and stay set until `CXCLR` ($2C) is strobed. The game reads them at the start of VBLANK — the previous frame's collisions — and clears them once:

```asm
    LDA CXP0FB
    AND #$40
    BEQ CheckP1
    LDA BallVX
    BMI HitP0                ; moving left, toward P0
    JMP NoHit
CheckP1:
    LDA CXP1FB
    AND #$40
    BEQ NoHit
    LDA BallVX
    BMI NoHit                ; moving left, away from P1
    LDA #$01
```

The direction check is essential. A latch can be set while the ball is still overlapping a paddle but already moving away; bouncing it again would trap the ball. The code only reverses `BallVX` when the ball is moving toward the paddle, and it moves the ball out of the paddle (`BallX = P0X + 8` or `P1X - 4`) so the next frame's latch is clean.

`P0Y`, `P1Y` and `BallY` are **play-area-relative**: row 0 is picture line 14, so `Y=8` is picture line 22 and `Y=164` is picture line 178. The paddle and ball positions are 8-bit play-area bytes, not absolute scanlines.

The row table is built from `BallY / 2`, so the ball's vertical motion is quantized to the two-line row grid. A `BallVY` of ±1 changes `BallY` every frame but only changes `BallRow` on alternate frames: the displayed ball moves in 2-pixel steps (0, 2, 0, 2, …). A `BallVY` of ±2 moves one row every frame. The angle table is five vertical speeds, but the visible vertical granularity is two lines.

The walls are simple:

```asm
    LDA BallY
    CLC
    ADC BallVY
    STA BallY
    CMP #8
    BCS CheckBottom
    LDA #8
    STA BallY
    ; reverse BallVY
```

`Y=8` and `Y=164` are the top and bottom bounce lines. The horizontal bounds are the score lines: `BallX < 6` scores for the right, `BallX > 150` scores for the left. The score check happens **before** the horizontal move, so the ball can never wrap from 1 to 255 at the left edge and be mistaken for a right-side score.

### Section 6: The Custom Score

The shared score library (`include/score.asm`) draws six digits with P0 and P1 in three-copy mode and owns `$A0-$D7`. Pong needs P0 and P1 for the paddles and the 89-byte row table needs `$80-$D8`. With `$A0-$D7` occupied, the free RAM is 57 bytes (`$80-$9F` plus `$D8-$F0`); after the 24 game variables (`$D9-$F0`) only 33 bytes remain, and the table alone wants 89. Pong therefore uses a **custom one-digit-per-player score**:

- The left digit is P0 at TIA X=64.
- The right digit is P1 at TIA X=88.
- Each digit is an 8×8 glyph from a 10×8 `ScoreFont`; row 7 is blank, so the lit glyph is 7 lines.
- The glyph address for a row is `ScoreFont + Score * 8 + row`.

The score band is the first 8 visible lines. The VBLANK code has already positioned P0 at 64 and P1 at 88 (with the Lesson 26 divide-by-15 routine and one `HMOVE`). The band loop is 8 iterations:

```asm
ScoreLine:
    TXA
    CLC
    ADC CurP0                ; row + LeftScore * 8
    TAY
    LDA ScoreFont,Y
    STA GRP0
    LDA CurBall
    BNE ScoreLeftDone
    LDA #$00
    STA GRP0                 ; the flash-off frame blanks the left digit
ScoreLeftDone:
    ...
    STA WSYNC
    INX
    CPX #8
    BNE ScoreLine
```

`CurP0` and `CurP1` hold the digit bases (`Score * 8`); `CurBall` holds the flash flag (`$FF` = draw both, 0 = blank the left, 1 = blank the right). The row-0 decode on the blank line overwrites all three before the play kernel, so the score band is the only user of those meanings.

At game over the winning digit flashes with `Frame & $10`: on alternate 16-frame phases the winning digit's `GRP` is overwritten with 0. The other digit stays lit. The flash is a one-byte flag and a branch, not a second kernel.

After the band the players are repositioned for the paddles:

```asm
    LDA #(P0_X + PLAY_BIAS)  ; 19 -> X=16
    JSR SetCoarseP0Play
    LDA #(P1_X + PLAY_BIAS)  ; 139 -> X=136
    JSR SetCoarseP1
    LDA BallX
    CLC
    ADC #BALL_BIAS           ; +4: the ball's output delay is one clock shorter
    JSR SetCoarseBL
    STA WSYNC
    STA HMOVE                ; one HMOVE applies all three fine offsets
```

The +3 player bias is Lesson 26's calibration. The ball uses +4 because its reset output delay is four clocks instead of five. The `ScoreDone` checkpoint is on the first play positioner's divide (scanline 46); `PositionDone` is the first kernel line (51).

::: tip Why the score is not a playfield
A playfield digit is possible, but the playfield's 4-pixel chunks make a two-digit score 64 pixels wide and the P0/P1 repositioning would still be needed. The player-based score uses the same two objects as the paddles, needs only the font table, and costs one `HMOVE` after the band. The price is that the score and the paddles cannot be on screen at the same X at the same time — which is why the band comes first and the repositioning comes second.
:::

### Section 7: The Serve, the Game State, and the Auto-Demo

A point ends when the ball leaves the horizontal bounds. The score handler caps the digit at 9, then either starts the next serve or ends the game:

- `ServeTimer = 60`, `BallX = 80`, `BallY = 90`, `BallVY = 0`.
- The **first** serve at power-on is fixed left (`BallVX = $FE`). After a point the serve travels toward the player who **lost** it: if the right scored, `BallVX = $FE`; if the left scored, `BallVX = $02`.
- While `ServeTimer > 0` the ball is parked and the game logic skips the ball step.
- The first score to 9 sets `GameState = 1`; the score band flashes the winner.
- Fire or SELECT resets the scores, the paddles and the serve.

The auto-demo exists so the screenshots are deterministic. After 120 frames with no direction held, both paddles track the ball. The right paddle moves up to **2 pixels per frame** so it can return a ball whose vertical speed is ±2. The left paddle moves **1 pixel per frame** toward a target **40 pixels below** the ball's target — the tracking lag taken to its limit — so its 24-pixel paddle cannot touch the 8-pixel ball after the opening rally. The opening rally is real Pong: the first serve, four paddle hits at frames 89 (P0), 145 (P1), 200 (P0) and 255 (P1), and wall bounces at 130 and 159. After the fourth hit the left drifts away, the right scores steadily, and the first point lands at frame 319.

The auto-demo also starts a waiting serve early after two seconds: it sets `ServeTimer = 1` instead of waiting the full 60 frames. That is the same effect as a fire press. The result is the timeline measured in Stella:

| Event | Frame | Time |
|---|---:|---:|
| The first serve | 60 | 1.0 s |
| The first point (right 1-0) | 319 | 5.3 s |
| The second point (right 2-0) | 358 | 6.0 s |

> The six-second capture is taken just before frame 358, so it shows the 0-1 state; the second point is the next event.
| The ninth point (right 9-0) | 631 | 10.5 s |
| `GameState = 1` (game over) | 632 | 10.5 s |

The 2 s capture is the opening rally at 0-0; the 6 s capture is the 0-1 state just before the second point at frame 358 (about 5.9 s); the 12 s capture is the game-over state at 0-9 with the right digit flashing. Any up/down direction takes over and resets the auto timer (the code checks `SWCHA & $33`; left/right does not reset it).

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson69.bin lessons/part10-capstones/69-pong/69-pong.asm
stella build/lesson69.bin
```

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 69: Capstone 1 — Pong — Racing the Beam
; =============================================================================
; Part 10: Capstone Projects
;
; What this program does:
;   A complete two-player Pong.  Two 8x24 paddles, a 4x8 ball, wall and
;   paddle collisions, a five-zone bounce angle, a 60-frame serve, a
;   one-digit-per-player score, and a first-to-9 game with a flashing
;   winner.  With no joystick input a deterministic auto-demo plays both
;   paddles so the captures show a serve, a rally, and the game-over state.
;
; The screen (192 visible lines):
;   picture lines 0-7     the score band.  P0 draws the left digit at
;                         TIA X=64 and P1 the right digit at X=88.  Each
;                         digit is an 8x7 glyph (font row 7 is blank) from
;                         the 10x8 ScoreFont table.
;   picture line 8        blank.
;   picture lines 9-13    the play positioners: SetCoarseP0 (P0 to 16),
;                         SetCoarseP1 (P1 to 136), SetCoarseBL (the ball to
;                         BallX), then WSYNC + HMOVE.  The three coarse
;                         strobes and one HMOVE take five lines.
;   picture lines 14-191  the play area: 178 lines = 89 rows x 2 lines.
;                         The 89-byte RowTable at $80-$D8 carries one byte
;                         per row (bit 0 = P0, bit 1 = P1, bit 2 = ball).
;                         The first row is decoded before the loop; the
;                         kernel stores the current row at the start of the
;                         row's first line and decodes the next row during
;                         the second line.
;   8 + 1 + 5 + 178 = 192.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame is scanline 259, VblankStart 0, BodyStart 37, ScoreDone 46,
;   PositionDone 51, OverscanStart 229.
;
; Why the row table (the cycle-49 lesson):
;   A one-line kernel that tests three object ranges in turn cannot store
;   GRP0 before P0's pixel time when P0 sits at X=16.  The preflight's
;   direct kernel wrote GRP0 at cycle 49; P0's leftmost pixel is at cycle
;   (16 + 68) / 3 = 28, so the left paddle rendered the previous row's byte
;   and was invisible.  The row table replaces the range tests with three
;   table loads, and the two-line lookahead puts the stores at the start of
;   the row's first line: GRP0 at cycle 12, ENABL at 18, GRP1 at 24.  P0 is
;   fixed at X=16, so its deadline is (16 + 68) / 3 = 28 cycles; the ball
;   can be displayed as far left as X=4 (the score check is BallX < 6), so
;   its deadline is (4 + 68) / 3 = 24.0 cycles.  Both stores are earlier.
;
; The kernel ledger (cycles; one row = two scanlines, 152 cycles):
;   line 1: the previous pair's loop tail INX 2, CPX #90 2, BNE 3 = 7;
;           LDA CurP0 3, STA GRP0 3, LDA CurBall 3, STA ENABL 3,
;           LDA CurP1 3, STA GRP1 3, STA WSYNC 3             = 28
;   line 2: CPX #89 2, BEQ 2; LDA RowTable,X 4, TAY 2,
;           LDA DecodeP0,Y 4, STA CurP0 3, LDA DecodeP1,Y 4,
;           STA CurP1 3, LDA DecodeBall,Y 4, STA CurBall 3,
;           STA WSYNC 3                                     = 34
;   the pair costs 62 cycles of the 152 available, leaving 90 cycles of
;   margin.  The stores land at 12 / 18 / 24 in steady state (8 / 14 / 20
;   on the first row).  P0's deadline at X=16 is cycle 28 and the ball's
;   at X=4 is cycle 24.0; the stores are earlier.
;   The 89th row skips the decode (CPX #89 / BEQ), so its second line
;   costs 8 cycles; the last WSYNC releases the CPU at scanline 229.
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80-$D8  RowTable     89 bytes, one byte per two-line row
;   $D9      LeftScore    0-9
;   $DA      RightScore   0-9
;   $DB      P0Y          P0's top row, 8-148
;   $DC      P1Y          P1's top row, 8-148
;   $DD      BallX        4-152 (the ball's left edge; the score check is <6)
;   $DE      BallY        8-164 (the ball's top row)
;   $DF      BallVX       signed: $FE (-2) or $02 (+2)
;   $E0      BallVY       signed: $FE..$02 (-2..+2)
;   $E1      Frame        the frame counter, 8 bits
;   $E2      ServeTimer   60..1 while the ball is parked, 0 in play
;   $E3      GameState    0 = play, 1 = game over
;   $E4      ScoreFlash   0 = the left digit won, 1 = the right digit won
;   $E5      Temp         scratch
;   $E6      CurP0        the current/next row's GRP0 byte (also the score
;                         font base before the score band)
;   $E7      CurP1        the current/next row's GRP1 byte (also the score
;                         font base before the score band)
;   $E8      CurBall      the current/next row's ENABL byte (also the score
;                         flash flag before the score band)
;   $E9      P0Row        P0Y / 2
;   $EA      P1Row        P1Y / 2
;   $EB      BallRow      BallY / 2
;   $EC      P0RowEnd     P0Row + 12
;   $ED      P1RowEnd     P1Row + 12
;   $EE      BallRowEnd   BallRow + 4
;   $EF      PrevFire     bit 0 = fire (0 = released, 1 = pressed), bit 1 unused
;   $F0      AutoTimer    consecutive frames with no direction held
;   $F1-$FF  stack
;
; The game:
;   SWCHA bits 4/5 are P0 up/down and bits 0/1 are P1 up/down (active
;   low; include/vcs.asm is the authority).  A direction moves a paddle 2
;   px/frame, clamped to 8..148.  Fire (INPT4) starts a serve early.
;   The ball moves 2 px/frame horizontally; its vertical speed comes from
;   AngleTable = (-2,-1,0,+1,+2) indexed by (BallY - PaddleY) / 5, clamped
;   to 0..4.  It bounces at Y=8 and Y=164.  CXP0FB/CXP1FB bit 6 is read in
;   VBLANK (the previous frame's latch) and CXCLR clears it.  A hit
;   reverses BallVX and moves the ball out of the paddle.
;   BallX < 6 scores for the right; BallX > 150 scores for the left; the
;   score caps at 9.  ServeTimer=60, the ball parks at X=80, Y=90.  The
;   first serve is fixed left; after a point it serves toward the player
;   who lost.  The first score to reach 9 sets GameState=1; the winner's
;   digit flashes with Frame & $10.  Fire or SELECT resets the scores and
;   serves.
;
; The auto-demo:
;   After 120 frames with no direction held, both paddles track the ball.
;   The right paddle moves up to 2 px/frame; the left moves 1 px/frame
;   toward a target 40 px below the ball's target (the tracking lag taken
;   to its limit), so its 24-pixel paddle cannot touch the 8-pixel ball
;   after the opening rally.  The opening rally exercises the paddle and
;   wall collisions: P0 hits at frame 89, P1 at 145, P0 at 200, P1 at 255;
;   after the fourth the left drifts away and the first point lands at 319.
;   The rest of the demo scores for the right.  The
;   auto-demo also starts a waiting serve early after two seconds, so the
;   ninth point lands at about frame 631 (10.5 s) and the 12 s capture
;   shows the game-over state.  Any up/down direction takes over and
;   resets AutoTimer to zero.
;
; Controls:
;   Left joystick: up/down moves P0.  Right joystick: up/down moves P1.
;   Fire starts a serve early; fire or SELECT restarts after game over.
;
; Checkpoints (the A/X/Y/SP values are the state at the label):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   ScoreDone (46), PositionDone (51), OverscanStart (229),
;   P0YRead (A=P0Y), P1YRead (A=P1Y), BallXRead (A=BallX),
;   BallYRead (A=BallY), ScoreLeft (A=the new left score),
;   ScoreRight (A=the new right score), PaddleHit (A=0 for P0, 1 for P1),
;   WallBounce (A=the clamped Y, 8 or 164), GameStateRead (A=GameState),
;   RowTableWrite (A=the byte at RowTable+0), ServeStart (A=the serve VX).
;
; Build: acme -f plain -o build/lesson69.bin \
;        lessons/part10-capstones/69-pong/69-pong.asm
; Run:   stella build/lesson69.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44       ; 1 + 43 x 64 = 2753 cycles = 36.2 lines; the
                          ; timer + wait_timer's WSYNC make the measured 37-line VBLANK
OVERSCAN_TIMER = 36       ; 1 + 35 x 64 = 2241 cycles = 29.5 lines; the
                          ; timer + WSYNC make the measured 30-line overscan

ROW_COUNT      = 89       ; 89 rows x 2 lines = 178 play lines
PADDLE_ROWS    = 12       ; 12 rows x 2 lines = 24 pixels of paddle
BALL_ROWS      = 4        ; 4 rows x 2 lines = 8 pixels of ball

P0_X           = 16       ; P0's fixed horizontal position
P1_X           = 136      ; P1's fixed horizontal position
PADDLE_MIN     = 8        ; the paddle's top edge limits
PADDLE_MAX     = 148
BALL_TOP       = 8        ; the ball's vertical bounce limits
BALL_BOTTOM    = 164
BALL_LEFT      = 6        ; BallX < 6: the right player scores
BALL_RIGHT     = 150      ; BallX > 150: the left player scores
SERVE_FRAMES   = 60
WIN_SCORE      = 9

PLAY_BIAS      = 3        ; the Lesson 26 player positioning bias
BALL_BIAS      = 4        ; the ball's output delay is one clock shorter

C_P0           = $C8      ; P0 and the left digit: green
C_P1           = $84      ; P1 and the right digit: blue
C_BALL         = $0E      ; the ball: white
C_BG           = $00      ; black

AUTO_START     = 120      ; frames with no input before the auto-demo

; =============================================================================
; RAM ALLOCATION ($80-$F0; the stack is $F1-$FF)
; =============================================================================
RowTable    = $80         ; 89 bytes ($80-$D8)
LeftScore   = $D9
RightScore  = $DA
P0Y         = $DB
P1Y         = $DC
BallX       = $DD
BallY       = $DE
BallVX      = $DF
BallVY      = $E0
Frame       = $E1
ServeTimer  = $E2
GameState   = $E3
ScoreFlash  = $E4
Temp        = $E5
CurP0       = $E6
CurP1       = $E7
CurBall     = $E8
P0Row       = $E9
P1Row       = $EA
BallRow     = $EB
P0RowEnd    = $EC
P1RowEnd    = $ED
BallRowEnd  = $EE
PrevFire    = $EF
AutoTimer   = $F0

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
    STA SWACNT              ; port A is an input port (both joysticks)

    LDA #C_P0
    STA COLUP0
    LDA #C_P1
    STA COLUP1
    LDA #C_BALL
    STA COLUPF
    LDA #C_BG
    STA COLUBK
    LDA #$20
    STA CTRLPF              ; the ball is 4 pixels wide (bits 4-5 = 10)
    LDA #$00
    STA NUSIZ0              ; one 8-pixel copy of each player
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

    LDA #90
    STA P0Y                 ; both paddles start centred
    LDA #90
    STA P1Y
    LDA #80
    STA BallX               ; the ball starts parked at the centre
    LDA #90
    STA BallY
    LDA #$FE
    STA BallVX              ; the first serve travels toward the left
    LDA #$00
    STA BallVY
    LDA #SERVE_FRAMES
    STA ServeTimer
    LDA #$00
    STA GameState
    STA ScoreFlash
    STA LeftScore
    STA RightScore
    STA Frame
    STA PrevFire
    STA AutoTimer
    STA CXCLR

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

; -----------------------------------------------------------------------------
; 1. READ THE INPUT, THE FIRE EDGE, AND THE AUTO-DEMO
; -----------------------------------------------------------------------------
    JSR ReadInput

; -----------------------------------------------------------------------------
; 2. THE SERVE TIMER (the ball is parked until it reaches zero)
; -----------------------------------------------------------------------------
    JSR ServeStep

; -----------------------------------------------------------------------------
; 3. THE BALL: COLLISION LATCHES, MOTION, WALLS, AND SCORING
; -----------------------------------------------------------------------------
    JSR BallStep

; -----------------------------------------------------------------------------
; 4. BUILD THE 89-BYTE ROW TABLE
; -----------------------------------------------------------------------------
    JSR BuildRowTable

; -----------------------------------------------------------------------------
; 5. THE SCORE BAND'S FONT BASES AND FLASH FLAG
; -----------------------------------------------------------------------------
; The score band uses CurP0/CurP1 as the left/right glyph bases (digit * 8)
; and CurBall as the flash flag: $FF draws both digits, 0 blanks the left,
; 1 blanks the right.  The row-0 decode at ScoreDone overwrites all three
; before the play kernel.
    LDA LeftScore
    ASL
    ASL
    ASL
    STA CurP0
    LDA RightScore
    ASL
    ASL
    ASL
    STA CurP1
    LDA #$FF
    STA CurBall
    LDA GameState
    BEQ ScoreNoFlash
    LDA Frame
    AND #$10
    BEQ ScoreNoFlash
    LDA ScoreFlash
    STA CurBall
ScoreNoFlash:

; -----------------------------------------------------------------------------
; 6. POSITION P0 AT 64 AND P1 AT 88 FOR THE SCORE BAND (one HMOVE)
; -----------------------------------------------------------------------------
    LDA #(64 + PLAY_BIAS)
    JSR SetCoarseP0
    LDA #(88 + PLAY_BIAS)
    JSR SetCoarseP1
    STA WSYNC
    STA HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE 0-7 — THE SCORE BAND (8 lines)
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, picture line 0
    LDX #0
ScoreLine:
    TXA
    CLC
    ADC CurP0               ; row + LeftScore * 8
    TAY
    LDA ScoreFont,Y
    STA GRP0                ; the left digit (green)
    LDA CurBall
    BNE ScoreLeftDone
    LDA #$00
    STA GRP0                ; the flash-off frame blanks the left digit
ScoreLeftDone:
    TXA
    CLC
    ADC CurP1               ; row + RightScore * 8
    TAY
    LDA ScoreFont,Y
    STA GRP1                ; the right digit (blue)
    LDA CurBall
    CMP #$01
    BNE ScoreRightDone
    LDA #$00
    STA GRP1                ; the flash-off frame blanks the right digit
ScoreRightDone:
    STA WSYNC
    INX
    CPX #8
    BNE ScoreLine

; =============================================================================
; VISIBLE 8 — THE BLANK LINE
; =============================================================================
; The row-0 decode belongs here: the score band has finished with CurP0/
; CurP1/CurBall, and the kernel needs row 0's object bytes in them.  The
; decode also pushes the line's WSYNC past the start of the visible area;
; a WSYNC written during the leading HBLANK does not wait for the next line.
    LDX #1                  ; the kernel's next-row index
    LDA RowTable
    TAY
    LDA DecodeP0,Y
    STA CurP0
    LDA DecodeP1,Y
    STA CurP1
    LDA DecodeBall,Y
    STA CurBall
    STA WSYNC

; =============================================================================
; VISIBLE 9-13 — THE PLAY POSITIONERS (five lines)
; =============================================================================
    LDA #(P0_X + PLAY_BIAS)
    JSR SetCoarseP0Play     ; P0's coarse position; ScoreDone is on line 46
    LDA #(P1_X + PLAY_BIAS)
    JSR SetCoarseP1         ; P1's coarse position and HMP1
    LDA BallX
    CLC
    ADC #BALL_BIAS
    JSR SetCoarseBL         ; the ball's coarse position and HMBL
    STA WSYNC
    STA HMOVE               ; one HMOVE applies all three fine offsets

; =============================================================================
; VISIBLE 14-191 — THE PLAY AREA: 89 ROWS x 2 LINES
; =============================================================================
PositionDone:               ; checkpoint: scanline 51, picture line 14
    LDA CurP0
    STA GRP0
    LDA CurBall
    STA ENABL
    LDA CurP1
    STA GRP1
    STA WSYNC               ; line 1 of the pair displays the current row

    CPX #ROW_COUNT
    BEQ KernelLastRow       ; row 88 has no next row to decode
    LDA RowTable,X          ; decode the next row during the second line
    TAY
    LDA DecodeP0,Y
    STA CurP0
    LDA DecodeP1,Y
    STA CurP1
    LDA DecodeBall,Y
    STA CurBall
KernelLastRow:
    STA WSYNC               ; line 2 of the pair displays the same row

    INX
    CPX #(ROW_COUNT + 1)
    BNE PositionDone
    ; 89 rows x 2 lines = 178; the last WSYNC releases at scanline 229.

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
; READ INPUT — the paddles, the fire edge, and the auto-demo
; =============================================================================
; SWCHA is active low.  P0's up/down are bits 4/5 and P1's are bits 0/1
; (include/vcs.asm).  A held direction resets AutoTimer and hands control to
; the joystick.  With no direction the auto-demo takes over at 120 frames.
ReadInput:

; The four observation points below are the values the game logic is about
; to use; they let the debugger report the paddle and ball state once a frame.
    LDA P0Y
P0YRead:                    ; checkpoint: A = P0Y
    LDA P1Y
P1YRead:                    ; checkpoint: A = P1Y
    LDA BallX
BallXRead:                  ; checkpoint: A = BallX
    LDA BallY
BallYRead:                  ; checkpoint: A = BallY

; --- the fire edge (bit 7 of INPT4 is 0 while pressed) ---
    LDA INPT4
    AND #$80
    BEQ FireIsDown
    LDA #$00
    JMP FireState
FireIsDown:
    LDA #$01
FireState:
    STA Temp                ; Temp = 1 while fire is held
    LDX #0
    LDA Temp
    BEQ FireEdgeDone
    LDA PrevFire
    AND #$01
    BNE FireEdgeDone
    LDX #1                  ; a new press
FireEdgeDone:
    LDA PrevFire
    AND #$FE
    ORA Temp
    STA PrevFire            ; remember this frame's fire state

    LDA GameState
GameStateRead:              ; checkpoint: A = GameState
    BNE GameOverInput

; --- play: fire starts a waiting serve early ---
    CPX #1
    BNE AutoCheck
    LDA ServeTimer
    BEQ AutoCheck
    LDA #$01
    STA ServeTimer          ; the next ServeStep decrements to zero

; --- the auto-demo starts a waiting serve early after two seconds ---
AutoCheck:
    LDA AutoTimer
    CMP #AUTO_START
    BCC PlayInput
    LDA ServeTimer
    BEQ PlayInput
    LDA #$01
    STA ServeTimer

; --- the paddles: joystick or auto-demo ---
PlayInput:
    LDA SWCHA
    AND #$33                ; P0 up/down (4/5) and P1 up/down (0/1)
    CMP #$33
    BEQ NoDirection
    LDA #$00
    STA AutoTimer           ; a direction takes over
    JSR ManualMoves
    RTS
NoDirection:
    INC AutoTimer
    BNE AutoCounted
    DEC AutoTimer           ; saturate at 255; the auto-demo stays on
AutoCounted:
    LDA AutoTimer
    CMP #AUTO_START
    BCC InputDone
    JSR AutoMoves
InputDone:
    RTS

; --- game over: fire or SELECT restarts ---
GameOverInput:
    CPX #1
    BEQ RestartGame
    LDA SWCHB
    AND #$02                ; SELECT is active low
    BNE InputDone
RestartGame:
    LDA #$00
    STA GameState
    STA LeftScore
    STA RightScore
    STA ScoreFlash
    STA AutoTimer
    LDA #90
    STA P0Y
    STA P1Y
    LDA #80
    STA BallX
    LDA #90
    STA BallY
    LDA #$00
    STA BallVY
    LDA #$FE
    STA BallVX
    LDA #SERVE_FRAMES
    STA ServeTimer
    LDA #$00
    STA CXCLR
    RTS

; =============================================================================
; MANUAL MOVES — two pixels per frame, range-clamped to 8..148
; =============================================================================
; The clamp is a range test, not an equality test.  The auto-demo moves a
; paddle one pixel per frame, so P0Y/P1Y can be odd: from 9 an equality test
; would subtract to 7, 5, 3, 1, $FF, and the row table would then write past
; $D8.  The range test clamps the result in one step.
ManualMoves:
    LDA SWCHA
    AND #$10                ; P0 up
    BNE ManualP0Down
    LDA P0Y
    SEC
    SBC #2
    CMP #PADDLE_MIN
    BCS ManualP0UpStore
    LDA #PADDLE_MIN
ManualP0UpStore:
    STA P0Y
ManualP0Down:
    LDA SWCHA
    AND #$20                ; P0 down
    BNE ManualP1Up
    LDA P0Y
    CLC
    ADC #2
    CMP #(PADDLE_MAX + 1)
    BCC ManualP0DownStore
    LDA #PADDLE_MAX
ManualP0DownStore:
    STA P0Y
ManualP1Up:
    LDA SWCHA
    AND #$01                ; P1 up
    BNE ManualP1Down
    LDA P1Y
    SEC
    SBC #2
    CMP #PADDLE_MIN
    BCS ManualP1UpStore
    LDA #PADDLE_MIN
ManualP1UpStore:
    STA P1Y
ManualP1Down:
    LDA SWCHA
    AND #$02                ; P1 down
    BNE ManualDone
    LDA P1Y
    CLC
    ADC #2
    CMP #(PADDLE_MAX + 1)
    BCC ManualP1DownStore
    LDA #PADDLE_MAX
ManualP1DownStore:
    STA P1Y
ManualDone:
    RTS

; =============================================================================
; AUTO MOVES — both paddles track the ball; the left lags
; =============================================================================
; The right paddle's target centres its 24-pixel paddle on the 8-pixel ball:
; target = BallY - 8, clamped to 8..148.  The right moves up to two pixels
; per frame.  The left moves one pixel per frame toward a target 40 pixels
; below the ball's target: the tracking lag taken to its limit, so the left
; paddle cannot touch the ball after the opening rally.  The right returns the ball
; and the left misses.
AutoMoves:
    LDA BallY
    SEC
    SBC #8
    BCS AutoRTarget
    LDA #PADDLE_MIN
AutoRTarget:
    CMP #(PADDLE_MAX + 1)
    BCC AutoRTargetOK
    LDA #PADDLE_MAX
AutoRTargetOK:
    STA Temp

    LDA P1Y
    CMP Temp
    BEQ AutoRightDone
    BCC AutoRightDown
    LDA P1Y
    SEC
    SBC #2
    CMP #PADDLE_MIN
    BCS AutoRightStore
    LDA #PADDLE_MIN
    JMP AutoRightStore
AutoRightDown:
    LDA P1Y
    CLC
    ADC #2
    CMP #(PADDLE_MAX + 1)
    BCC AutoRightStore
    LDA #PADDLE_MAX
AutoRightStore:
    STA P1Y
AutoRightDone:

    LDA Temp
    CLC
    ADC #40                 ; the left trails the ball by 40 pixels: far
    BCS AutoLagCap          ; enough that its 24-pixel paddle cannot touch
    CMP #(PADDLE_MAX + 1)   ; the 8-pixel ball
    BCC AutoLagOK
AutoLagCap:
    LDA #PADDLE_MAX
AutoLagOK:
    STA Temp

    LDA P0Y
    CMP Temp
    BEQ AutoLeftDone
    BCC AutoLeftDown
    CMP #PADDLE_MIN
    BEQ AutoLeftDone
    DEC P0Y
    JMP AutoLeftDone
AutoLeftDown:
    CMP #PADDLE_MAX
    BEQ AutoLeftDone
    INC P0Y
AutoLeftDone:
    RTS

; =============================================================================
; SERVE STEP — count the parked frames; at zero the ball starts moving
; =============================================================================
ServeStep:
    LDA GameState
    BNE ServeStepDone
    LDA ServeTimer
    BEQ ServeStepDone
    DEC ServeTimer
    BNE ServeStepDone
    LDA BallVX
ServeStart:                 ; checkpoint: A = the serve direction
    NOP
ServeStepDone:
    RTS

; =============================================================================
; BALL STEP — the collision latches, the motion, the walls, and the score
; =============================================================================
BallStep:
    LDA GameState
    BEQ BallCheckTimer
    JMP BallFrozen
BallCheckTimer:
    LDA ServeTimer
    BEQ BallStepRun
    JMP BallFrozen
BallStepRun:

; --- the paddle collision latches (CXP0FB/CXP1FB bit 6) ---
    LDA CXP0FB
    AND #$40
    BEQ BallCheckP1
    LDA BallVX
    BMI BallHitP0           ; moving left, toward P0
    JMP BallNoHit
BallCheckP1:
    LDA CXP1FB
    AND #$40
    BEQ BallNoHit
    LDA BallVX
    BMI BallNoHit           ; moving left, away from P1
    LDA #$01
    JMP BallHitCommon
BallHitP0:
    LDA #$00
BallHitCommon:
PaddleHit:                  ; checkpoint: A = 0 for P0, 1 for P1
    STA Temp                ; the side
    LDA Temp
    BNE BallGetP1Y
    LDA P0Y
    JMP BallHavePaddleY
BallGetP1Y:
    LDA P1Y
BallHavePaddleY:
    STA CurBall             ; scratch: the paddle's top row
    LDA BallY
    SEC
    SBC CurBall
    BCS BallOffset
    LDA #0
BallOffset:
    CMP #21
    BCC BallOffsetOK
    LDA #20
BallOffsetOK:
    LDX #0
BallDiv5:
    CMP #5
    BCC BallDiv5Done
    SBC #5
    INX
    BNE BallDiv5
BallDiv5Done:
    LDA AngleTable,X
    STA BallVY

    LDA Temp
    BNE BallBounceP1
    LDA #2
    STA BallVX              ; P0 sends the ball right
    LDA #(P0_X + 8)
    STA BallX               ; just right of the paddle
    JMP BallClearMove
BallBounceP1:
    LDA #$FE
    STA BallVX              ; P1 sends the ball left
    LDA #(P1_X - 4)
    STA BallX               ; just left of the paddle
    JMP BallClearMove

; --- no hit: clear the latches and move ---
BallNoHit:
BallClearMove:
    LDA #$00
    STA CXCLR               ; the latches are read; start the next frame clean

; --- score check before the move, so the ball cannot wrap at the edges ---
    LDA BallX
    CMP #BALL_LEFT
    BCC BallRightPoint
    CMP #(BALL_RIGHT + 1)
    BCS BallLeftPoint

; --- horizontal and vertical motion ---
    LDA BallX
    CLC
    ADC BallVX
    STA BallX
    LDA BallY
    CLC
    ADC BallVY
    STA BallY

; --- the walls at Y=8 and Y=164 ---
    CMP #BALL_TOP
    BCS BallCheckBottom
    LDA #BALL_TOP
    STA BallY
    JMP BallWallBounce
BallCheckBottom:
    CMP #(BALL_BOTTOM + 1)
    BCC BallStepDone
    LDA #BALL_BOTTOM
    STA BallY
BallWallBounce:
WallBounce:                 ; checkpoint: A = the clamped Y (8 or 164)
    LDA BallVY
    EOR #$FF
    CLC
    ADC #1
    STA BallVY              ; two's-complement negation
BallStepDone:
    RTS

; The game-over and serve-wait paths freeze the ball; clear the latches and
; leave the score check untouched.
BallFrozen:
    LDA #$00
    STA CXCLR
    RTS

; --- the right player scored: BallX < 6 ---
BallRightPoint:
    INC RightScore
    LDA RightScore
    CMP #10
    BCC BallRightCap
    LDA #9
    STA RightScore
BallRightCap:
ScoreRight:                 ; checkpoint: A = the new right score
    CMP #WIN_SCORE
    BCS BallRightWon
    LDA #$FE
    STA BallVX              ; serve toward the loser (the left)
    JMP BallServeSetup
BallRightWon:
    LDA #$01
    STA GameState
    STA ScoreFlash          ; the right digit won
    LDA #$00
    STA ServeTimer
    RTS

; --- the left player scored: BallX > 150 ---
BallLeftPoint:
    INC LeftScore
    LDA LeftScore
    CMP #10
    BCC BallLeftCap
    LDA #9
    STA LeftScore
BallLeftCap:
ScoreLeft:                  ; checkpoint: A = the new left score
    CMP #WIN_SCORE
    BCS BallLeftWon
    LDA #2
    STA BallVX              ; serve toward the loser (the right)
    JMP BallServeSetup
BallLeftWon:
    LDA #$01
    STA GameState
    LDA #$00
    STA ScoreFlash          ; the left digit won
    LDA #$00
    STA ServeTimer
    RTS

; --- park the ball for the next serve ---
BallServeSetup:
    LDA #SERVE_FRAMES
    STA ServeTimer
    LDA #80
    STA BallX
    LDA #90
    STA BallY
    LDA #$00
    STA BallVY
    STA ScoreFlash
    RTS

; =============================================================================
; BUILD ROW TABLE — clear 89 bytes, then OR the three object ranges
; =============================================================================
BuildRowTable:
    LDA P0Y
    JSR ClampPaddle
    STA P0Y
    LDA P1Y
    JSR ClampPaddle
    STA P1Y
    LDX #0
    LDA #$00
RowClear:
    STA RowTable,X
    INX
    CPX #ROW_COUNT
    BNE RowClear

    LDA P0Y
    LSR                     ; P0Row = P0Y / 2
    STA P0Row
    CLC
    ADC #PADDLE_ROWS
    STA P0RowEnd
    LDX P0Row
RowP0:
    LDA RowTable,X
    ORA #$01
    STA RowTable,X
    INX
    CPX P0RowEnd
    BNE RowP0

    LDA P1Y
    LSR
    STA P1Row
    CLC
    ADC #PADDLE_ROWS
    STA P1RowEnd
    LDX P1Row
RowP1:
    LDA RowTable,X
    ORA #$02
    STA RowTable,X
    INX
    CPX P1RowEnd
    BNE RowP1

    LDA BallY
    LSR
    STA BallRow
    CLC
    ADC #BALL_ROWS
    STA BallRowEnd
    LDX BallRow
RowBall:
    LDA RowTable,X
    ORA #$04
    STA RowTable,X
    INX
    CPX BallRowEnd
    BNE RowBall

    LDA RowTable
RowTableWrite:              ; checkpoint: A = the byte at RowTable+0
    RTS

; =============================================================================
; CLAMP PADDLE — A = 8..148 (the row-table build's safety net)
; =============================================================================
; The moves already clamp, but a corrupted P0Y/P1Y must never index past
; RowTable+$D8.  The build clamps both bytes before it computes the ranges.
ClampPaddle:
    CMP #PADDLE_MIN
    BCS ClampHigh
    LDA #PADDLE_MIN
    RTS
ClampHigh:
    CMP #(PADDLE_MAX + 1)
    BCC ClampDone
    LDA #PADDLE_MAX
ClampDone:
    RTS

; =============================================================================
; COARSE POSITIONING — the Lesson 26 divide-by-15 routines; no HMOVE here
; =============================================================================
; Input: A = the target + the object's bias.  Each routine starts on a fresh
; line, subtracts 15 until the carry clears, turns the negative remainder
; into the signed fine value, stores it in HMxx, and strobes RESxx.  The
; caller applies the three fine offsets with one HMOVE.
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

; The play positioner's first routine is SetCoarseP0 with the ScoreDone
; checkpoint on its first line (scanline 46).  The score-band positioner
; in VBLANK uses SetCoarseP0 above, so the checkpoint has exactly one hit
; per frame.
SetCoarseP0Play:
    STA WSYNC
ScoreDone:                 ; checkpoint: scanline 46, the first play positioner
    SEC
DivP0Play:
    SBC #15
    BCS DivP0Play
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
; THE DECODE TABLES — index a row byte to the three TIA bytes
; =============================================================================
; Index = bit 2 ball, bit 1 P1, bit 0 P0.  Each table is aligned to an
; 8-byte boundary so the kernel's indexed loads never cross a page.
    !align 7, 0
DecodeP0:
    !byte $00, $FF, $00, $FF, $00, $FF, $00, $FF
    !align 7, 0
DecodeP1:
    !byte $00, $00, $FF, $FF, $00, $00, $FF, $FF
    !align 7, 0
DecodeBall:
    !byte $00, $00, $00, $00, $02, $02, $02, $02

; =============================================================================
; THE ANGLE TABLE — the five vertical speeds
; =============================================================================
AngleTable:
    !byte $FE, $FF, $00, $01, $02   ; -2, -1, 0, +1, +2

; =============================================================================
; THE SCORE FONT — ten 8x8 glyphs, top-down; row 7 is blank
; =============================================================================
; The left digit is drawn by P0 at X=64 and the right by P1 at X=88.  Each
; row's byte is ScoreFont + digit * 8 + row; the last row is $00, so the
; lit glyph is seven scanlines tall.
ScoreFont:
    !byte %00111100, %01100110, %01100110, %01100110   ; 0
    !byte %01100110, %01100110, %00111100, %00000000
    !byte %00011000, %00111000, %00011000, %00011000   ; 1
    !byte %00011000, %00011000, %01111110, %00000000
    !byte %00111100, %01100110, %00000110, %00001100   ; 2
    !byte %00110000, %01100000, %01111110, %00000000
    !byte %00111100, %01100110, %00000110, %00011100   ; 3
    !byte %00000110, %01100110, %00111100, %00000000
    !byte %00001100, %00011100, %00111100, %01101100   ; 4
    !byte %01111110, %00001100, %00001100, %00000000
    !byte %01111110, %01100000, %01111100, %00000110   ; 5
    !byte %00000110, %01100110, %00111100, %00000000
    !byte %00011100, %00110000, %01100000, %01111100   ; 6
    !byte %01100110, %01100110, %00111100, %00000000
    !byte %01111110, %00000110, %00001100, %00011000   ; 7
    !byte %00110000, %00110000, %00110000, %00000000
    !byte %00111100, %01100110, %01100110, %00111100   ; 8
    !byte %01100110, %01100110, %00111100, %00000000
    !byte %00111100, %01100110, %01100110, %00111110   ; 9
    !byte %00000110, %00001100, %00111000, %00000000

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
> `lessons/part10-capstones/69-pong/69-pong.asm`.

### Code Walkthrough

#### Step 1 — The frame and the VBLANK budget

`StartFrame` is the first VSYNC line (scanline 259). `+vsync` produces 3 lines; `VblankStart` sets `VBLANK` and starts the 44-tick timer; the visible code begins at `BodyStart` (scanline 37). The VBLANK work is:

1. `ReadInput`: the four observation reads, the SELECT edge (in this lesson only a comment in the main; the exercise uses it), the fire edge, the title/play dispatch, the manual or auto paddle moves.
2. `ServeStep`: decrement `ServeTimer`; at zero, the ball's `BallVX` starts it moving.
3. `BallStep`: the collision latches, the bounce, the motion, the walls, the score.
4. `BuildRowTable`: the 89-byte table.
5. The score bases and the flash flag.
6. The score positioners: P0 to 64, P1 to 88, one `HMOVE`.

The timer is 2,753 cycles, about 36.2 lines. The row-table build is about 1,500; the game logic is a few hundred; the score positioners take three scanlines. `+wait_timer`'s final `WSYNC` absorbs the remainder into the measured 37-line VBLANK, and the work fits before the picture turns on.

#### Step 2 — The input and the auto-demo

`ReadInput` begins with four reads whose only purpose is observation:

```asm
    LDA P0Y
P0YRead:                    ; checkpoint: A = P0Y
    LDA P1Y
P1YRead:                    ; checkpoint: A = P1Y
    LDA BallX
BallXRead:                  ; checkpoint: A = BallX
    LDA BallY
BallYRead:                  ; checkpoint: A = BallY
```

The fire edge is a one-byte state machine. `INPT4` bit 7 is 0 while pressed; `PrevFire` bit 0 remembers the previous frame. A new press is `current & ~previous`. The edge starts a waiting serve early (`ServeTimer = 1`) or restarts after game over.

The paddle path:

```asm
    LDA SWCHA
    AND #$33                ; P0 up/down (4/5) and P1 up/down (0/1)
    CMP #$33
    BEQ NoDirection
    LDA #$00
    STA AutoTimer           ; a direction takes over
    JSR ManualMoves
    RTS
NoDirection:
    INC AutoTimer
    ...
    JSR AutoMoves
```

`ManualMoves` reads the four active-low bits and moves 2 pixels per frame with the 8..148 clamp. `AutoMoves` computes the right paddle's target (`BallY - 8`, the paddle centred on the ball), moves it up to 2 pixels, then computes the left target (`right target + 40`) and moves it 1 pixel. The auto timer gates the auto path: the first 120 frames of no input are manual (no movement); after that the demo takes over.

#### Step 3 — The row table build

`BuildRowTable` clears the 89 bytes, then ORs three ranges. The index arithmetic is the whole trick:

```asm
    LDA P0Y
    LSR                     ; P0Row = P0Y / 2
    STA P0Row
    CLC
    ADC #PADDLE_ROWS        ; +12 rows for 24 pixels
    STA P0RowEnd
    LDX P0Row
RowP0:
    LDA RowTable,X
    ORA #$01
    STA RowTable,X
    INX
    CPX P0RowEnd
    BNE RowP0
```

The same shape runs for P1 (`ORA #$02`, 12 rows) and the ball (`ORA #$04`, 4 rows). The table is at `$80-$D8`; `RowTable,X` never crosses a page because the largest X is 88 and `$80 + 88 = $D8`. The `RowTableWrite` checkpoint reads row 0 (`A = $00` on the opening frames: the paddles start at row 45, so the first row is empty).

#### Step 4 — The score band and the font

The score band is eight iterations of the loop in Section 6. `CurP0` and `CurP1` hold `LeftScore * 8` and `RightScore * 8`; the loop's `TXA`/`ADC`/`TAY` indexes `ScoreFont`. The flash flag in `CurBall` blanks the winner on the 16-frame off phase.

The font is ten glyphs, top-down, each 8 bytes:

```asm
ScoreFont:
    !byte %00111100, %01100110, %01100110, %01100110   ; 0
    !byte %01100110, %01100110, %00111100, %00000000
    ...
    !byte %00111100, %01100110, %01100110, %00111110   ; 9
    !byte %00000110, %00001100, %00111000, %00000000
```

The last byte of every glyph is `$00`, so the digit's lit block is seven scanlines tall. Row 7 is the blank line inside the score band; picture line 8 is the separate blank line before the positioners.

#### Step 5 — The play positioners

`SetCoarseP0Play`, `SetCoarseP1` and `SetCoarseBL` are the Lesson 26 divide-by-15 routines. Each starts on a fresh line, subtracts 15 until the carry clears, turns the negative remainder into the signed fine value, stores it in `HMPx`/`HMBL`, and strobes `RESPx`/`RESBL`. The caller sets all three coarse positions first and then strobes **one** `HMOVE`:

```asm
    LDA #(P0_X + PLAY_BIAS)
    JSR SetCoarseP0Play
    LDA #(P1_X + PLAY_BIAS)
    JSR SetCoarseP1
    LDA BallX
    CLC
    ADC #BALL_BIAS
    JSR SetCoarseBL
    STA WSYNC
    STA HMOVE
```

The `ScoreDone` checkpoint sits inside `SetCoarseP0Play`, after its `WSYNC` and before the divide, so it reports scanline 46 with A = the biased P0 target (`$13` = 19). The three coarse strobes and the `HMOVE` take five lines: 46-50. `PositionDone` is the first kernel line, 51.

#### Step 6 — The two-line kernel and the lookahead

The kernel is Section 3's loop. The row table provides the current row in `CurP0`/`CurP1`/`CurBall`; the second line decodes the next row. The first-line stores are at cycles 8/14/20 on the first row and 12/18/24 in steady state. P0's deadline at X=16 is cycle 28; the ball's leftmost displayed X is 4 (the score check is `<6`), so its deadline is 24.0. The loop costs 62 of the 152 cycles in a pair; the rest is the `WSYNC` idle time. The last row skips the decode and its second `WSYNC` releases the CPU at 229.

#### Step 7 — The collision and the score

`BallStep` reads the latches, checks the direction, computes the hit offset, indexes the angle table, sets `BallVX`, and moves the ball out of the paddle. The move is guarded by the score check before the horizontal step. The wall bounce is the top/bottom clamp and the two's-complement negation:

```asm
    LDA BallVY
    EOR #$FF
    CLC
    ADC #1
    STA BallVY
```

The score handlers cap at 9, set the serve direction, and park the ball. At 9 the game-over branch sets `GameState = 1`, stores the winner in `ScoreFlash`, and clears the serve timer. The score band's flash flag reads `ScoreFlash` on the `Frame & $10` phase.

#### Step 8 — The serve and the game over

The serve is a 60-frame countdown. `ServeStep` decrements; when it reaches zero, `ServeStart` reports A = `BallVX` (`$FE`). The ball is parked at 80/90 during the countdown. A point's handler sets `BallVX` toward the loser and jumps to `BallServeSetup`, which resets the timer and parks the ball. At game over the ball stays where it left the screen; the paddles freeze because `BallStep` and the input path skip the play state.

## What You Should See

The screen is black. The score band at the top has a green digit on the left (P0 at TIA X=64) and a blue digit on the right (P1 at X=88); `00` at the start. Below it, after a blank line and the five positioner lines, the play area has a green 8×24 paddle at X=16, a blue 8×24 paddle at X=136, and a white 4×8 ball. There is no playfield: Pong is the three objects and the score.

The serve starts after one second: the first serve leaves the centre (X=80, Y=90) toward the left; later serves travel toward the player who lost the previous point, travels two pixels per frame, bounces off the top wall at Y=8 or the bottom wall at Y=164, and reverses direction when a paddle's collision latch fires. The angle table sends it up, straight, or down depending on where it met the 24-pixel paddle. A point parks the ball at the centre for one second and serves toward the loser. The first side to 9 wins; its digit flashes, and fire or SELECT starts a new game.

The three captures are from the committed ROM:

![Pong's opening rally: the score 00, the green left paddle at X=16, the blue right paddle at X=136, and the white ball left of centre](/images/lesson69/serve.png)

*The opening rally, 2 s after power-on. The score is 00, the paddles are centred, and the white ball is at TIA X≈38, picture line≈90.*

![Pong's 0-1 rally: the blue right digit shows 1, the paddles are at different heights, and the ball is mid-court](/images/lesson69/rally.png)

*The 0-1 rally, about 6 s after power-on (just before the second point). P0's left digit is 0, P1's right digit is 1, and the ball is at TIA X≈50.*

![Pong's game-over state: the score 0-9, the right digit flashing, the ball at the left edge, and both paddles frozen](/images/lesson69/game-over.png)

*The game-over state, 12 s after power-on. The right digit is 9 (the flash's lit phase), the ball is at the left edge where the last point ended, and the paddles are frozen.*

<RomPlayer rom="/roms/part10-capstones/69-pong/69-pong.bin" title="Lesson 69 — Capstone 1: Pong" />

*Javatari starts muted; this ROM is silent, so there is nothing to unmute.*

The debugger tells the same story. Assemble with a symbol list and break at the labelled checkpoints:

```bash
acme -f plain -l build/69-pong.sym -o build/69-pong.bin \
  lessons/part10-capstones/69-pong/69-pong.asm
grep -E "StartFrame|VblankStart|BodyStart|ScoreDone|PositionDone|OverscanStart" build/69-pong.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F071' docs/public/roms/part10-capstones/69-pong/69-pong.bin
```

The measured checkpoints:

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F071` | 259, cycle 3 | The first VSYNC line |
| `VblankStart` | `$F07F` | 0, cycle 5 | The first VBLANK line |
| `BodyStart` | `$F0CF` | 37, cycle 5 | The first picture line (the score band) |
| `ScoreDone` | `$F454` | 46, cycle 11; A = `$13` | The first play positioner's divide |
| `PositionDone` | `$F12A` | 51, cycle 3 (first hit) | The first kernel line |
| `OverscanStart` | `$F155` | 229, cycle 6 | The first overscan line |
| `P0YRead` / `P1YRead` | `$F16A` / `$F16C` | A = `$5A` / `$5A` | The paddle tops |
| `BallXRead` / `BallYRead` | `$F16E` / `$F170` | A = `$50` / `$5A` | The ball's start |
| `ScoreRight` | `$F384` | A = 1..9 | The right's new score, once per point |
| `ScoreLeft` | `$F3A6` | A = 1 with `-holdjoy1 D` | The left's new score |
| `PaddleHit` | `$F2F2` | A = 0 / 1 | Which paddle the latch matched |
| `WallBounce` | `$F369` | A = 8 | The clamped Y at the top bounce (the Y=164 bottom branch is code-derived; see below) |
| `GameStateRead` | `$F197` | A = 0, then 1 at frame 632 | The play/game-over state |
| `RowTableWrite` | `$F431` | A = `$00` | The byte at `RowTable+0` |
| `ServeStart` | `$F2C4` | A = `$FE` | The serve's horizontal direction |

The state log also shows the auto-demo's timeline. `ScoreRight` hits A=1 at frame 319, A=2 at 358, and A=9 at 631; `GameStateRead` changes from A=0 to A=1 at frame 632. `PaddleHit` reports A=0 at frame 89, A=1 at 145, A=0 at 200 and A=1 at 255 — the fourth hit is where the left starts to drift away; the first point follows at 319. `WallBounce` reports A=8 at 130 and 159: those are the top wall. The Y=164 bottom bounce exists in the code but the auto-demo's high-ball opening rally never reaches it, so its evidence is code-derived, not observed. Those are the opening rally's real events, not a scripted animation.

The **pixel check** of the three images:

| Image | Size | Title bar | What the pixels show |
|---|---|---|---|
| `serve.png` | 1010×807 | `Stella 7.0: "69-pong"` | TIA area 960×606 at (25,106); the score `00` (green bbox 415-450×107-127, blue 559-594×107-127); the green paddle 121-168×435-509, the blue 841-888×435-509; the white ball 253-276×391-414; no cursor |
| `rally.png` | 1010×807 | `Stella 7.0: "69-pong"` | the score `01` (the blue digit's 312 lit pixels); the paddles at 121-168×435-509 and 841-888×359-433; the ball 325-348×435-458 |
| `game-over.png` | 1010×807 | `Stella 7.0: "69-pong"` | the score `09` (the blue `9`'s 372 lit pixels); the paddles 121-168×536-610 and 841-888×410-484; the ball 49-72×435-458 at the left edge; the right digit is the flash's lit phase |

The three TIA-area hashes differ (`291f0fe7e04de607…`, `2ff0eb7d4d4e6726…`, `46f5d5607b125bfd…`), so the captures are genuinely different states, not three copies of one frame. All three are 1010×807, carry the window frame and the `Stella 7.0: "69-pong"` title bar, and show no cursor: the pointer was parked at (0,0) before each capture.

> **Capture method.** `serve.png` is a direct `stella -uimessages 0` window on the committed
> `docs/public/roms/part10-capstones/69-pong/69-pong.bin`, captured two seconds after launch
> (not through `scripts/capture-screenshot.sh`, because the script would catch the emulator's
> start-up status box); `rally.png` and `game-over.png` use `scripts/capture-screenshot.sh` on
> the same committed ROM at six and twelve seconds. The ROM starts its auto-demo at power-on, so the states are
> deterministic: 0-0 at 2 s, 0-1 at about 6 s, 0-9 at 12 s. The `-uimessages 0` flag removes the
> emulator's start-up status box from the serve image; the title bar is the window manager's.
> The pointer was parked at (0,0) before every capture. All three images are 1010×807 and
> carry the title bar; no cursor appears.

## Exercises

Each exercise ships a 4,096-byte `exercise-NN-solution.asm`. The solutions assemble through `npm run roms`, run in Stella, and actually solve the exercise as written.

### Exercise 1: A CPU opponent

**Challenge:** Replace the right paddle's joystick with a computer follower. The CPU tracks the ball's centre with a speed cap; SELECT toggles easy (1 px/frame) and hard (2 px/frame). The left paddle stays human.

**Hints:**
1. The CPU's target is `BallY - 8`: the 24-pixel paddle centred on the 8-pixel ball. Clamp the target to 8..148.
2. The CPU's move is the manual move with a two-step option: easy subtracts/adders 1, hard 2. A `CpuMode` byte selects the cap.
3. SELECT is `SWCHB` bit 1, active low. A new press is an edge: keep the previous SELECT state in bit 1 of `PrevFire` (bit 0 is the fire button) and toggle `CpuMode` only when the current bit is 1 and the previous bit is 0.
4. The left joystick is still `SWCHA` bits 4/5. Remove the P1 joystick reads from `ManualMoves`; the CPU ignores the right joystick.
5. The game, the serve, the custom score and the row-table kernel are unchanged. Fire still starts a serve and restarts after game over.

**Expected Result:** `exercise-01-solution.asm` is 4,096 bytes and the frame is still 259/37/229. With no input the CPU's `CpuStep` log shows `P1Y` walking from 90 toward 82 one pixel per frame (`A=89, 88, 87, …`); with `-holdselect` the same log steps two pixels per frame (`A=88, 86, 84, …`) and `ModeToggle` reports A=1 once. The left paddle moves only with `-holdjoy0`.

**Solution:** See `exercise-01-solution.asm`.

The CPU move is a small extension of the manual move:

```asm
CpuMoves:
    LDA BallY
    SEC
    SBC #8
    BCS CpuTarget
    LDA #PADDLE_MIN
CpuTarget:                  ; checkpoint: A = the CPU's target
    CMP #(PADDLE_MAX + 1)
    BCC CpuTargetOK
    LDA #PADDLE_MAX
CpuTargetOK:
    STA CurP0
    LDA CpuMode
    CLC
    ADC #1
    STA CurP1                ; the speed cap: 1 or 2
    ...
```

The state log on the committed solution:

```text
# CpuStep with no input (easy)
BP:           1   2 69 139 | nv-BdIzC 59 00 00 fb |
BP:           2   2 69 139 | nv-BdIzC 58 00 00 fb |
BP:           3   2 69 139 | nv-BdIzC 57 00 00 fb |

# CpuStep with -holdselect (hard)
BP:           1   3 08 -44 | nv-BdIzC 58 00 00 fb |
BP:           2   2 74 154 | nv-BdIzC 56 00 00 fb |
BP:           3   2 74 154 | nv-BdIzC 54 00 00 fb |

# ModeToggle with -holdselect
BP:           1   1 24   4 | nv-BdIzC 01 01 00 fd |
```

### Exercise 2: Spin and speed

**Challenge:** Keep the five-zone angle table and add a rally hit counter. After four paddle hits the ball's horizontal speed grows from 2 to 3 pixels per frame. Reset the counter at each serve.

**Hints:**
1. The main already has the five-zone table: `AngleTable = (-2,-1,0,+1,+2)` indexed by `(BallY - PaddleY) / 5`. The exercise adds only the speed.
2. Use `ScoreFlash` as the rally hit counter during play: increment it on every paddle hit and cap it at 4. The serve resets it to 0; the game-over handler reuses the byte for the winning side.
3. The bounce speed is `2` while the counter is 0..3 and `3` when it is 4. For P1 negate the magnitude to get `$FD` (-3) or `$FE` (-2).
4. A hit counter above 4 is meaningless; the cap keeps the digit and the speed deterministic.
5. The speed change does not affect the row table, the score or the collision latches; only `BallX`'s step grows.

**Expected Result:** `exercise-02-solution.asm` is 4,096 bytes. `HitStep` reports A=1, 2, 3, 4 on the opening rally's four hits; `SpeedUp` reports A=2, 2, 2, then A=3. The fifth hit starts a new rally at A=1 and the speed returns to 2.

**Solution:** See `exercise-02-solution.asm`.

The speed choice is one compare:

```asm
    LDA ScoreFlash
    CMP #4
    BCC HitSpeedTwo
    LDA #3
    JMP HitSpeedStore
HitSpeedTwo:
    LDA #2
HitSpeedStore:
SpeedUp:                    ; checkpoint: A = the new speed (2 or 3)
    STA CurP1
    LDA Temp
    BNE BallBounceP1
    LDA CurP1
    STA BallVX
    ...
```

The state log on the committed solution:

```text
# HitStep
BP:          89   2 44  64 | Nv-BdIzc 01 00 00 fd |
BP:         145   3 74 154 | Nv-BdIzc 02 00 00 fd |
BP:         200   3 65 127 | Nv-BdIzc 03 00 00 fd |
BP:         255   3 75 157 | Nv-BdIzc 04 00 00 fd |
BP:         328   3 69 139 | Nv-BdIzc 01 00 00 fd |   (the next rally)

# SpeedUp
BP:          89   3 22  -2 | nv-BdIzc 02 00 00 fd |
BP:         145   4 52  88 | nv-BdIzc 02 00 00 fd |
BP:         200   4 43  61 | nv-BdIzc 02 00 00 fd |
BP:         255   4 65 127 | nv-BdIzC 03 01 00 fd |
BP:         328   4 58 106 | nv-BdIzc 02 01 00 fd |   (reset)
```

### Exercise 3: Best of three

**Challenge:** Add a title/attract screen, a best-of-three match (first to two games), a serve countdown, and a match-over screen. SELECT starts.

**Hints:**
1. `GameState` becomes a three-value state: 0 = title, 1 = play, 2 = match over. The title parks the ball and blinks it; the play is the lesson's game; the match-over screen freezes the paddles and hides the ball.
2. Two new bytes hold the match wins: `MatchLeft` at `$F1` and `MatchRight` at `$F2`. Keep SP=`$FF`; the `$F3-$FF` window (13 bytes) is reserved for the stack by never pushing past it. `TXS #$F3` would be wrong: the next pushes land on `$F2/$F1` and destroy the match bytes. The call depth is shallow (two levels), so 13 bytes is enough.
3. A game ends when a score reaches 9. Increment that side's match wins; reset the game scores and serve toward the game's loser. If the winner's match wins reach 2, set `GameState=2`.
4. On the match-over screen, copy the match wins into `LeftScore`/`RightScore` so the same score band shows `20` or `02`; the winner's digit flashes with `Frame & $10`.
5. The serve countdown is the ball blink: in `BuildRowTable`, hide the ball when `Frame & $08` is set and either the game is in its title state or `ServeTimer > 0`. Hide it unconditionally on the match-over screen.
6. SELECT and fire are edges: a new press starts the match at the title and returns to the title at the match over. The title's attract mode can reuse `AutoMoves`; the play keeps the lesson's auto-demo.

**Expected Result:** `exercise-03-solution.asm` is 4,096 bytes. With no input the `GameStateRead` log stays A=0 (the title). With `-holdselect` it reports A=0 at frame 1, A=1 at frame 2, and A=2 at frame 983; `GameWin` reports A=1 at frame 631 and A=2 at frame 982; `MatchOver` reports A=2; `ServeCount` walks 60, 59, 58, … The title screen shows `00` with the blinking ball; the match-over screen shows `02` (the right won both games) with the right digit flashing.

**Solution:** See `exercise-03-solution.asm`.

The match transition is one path for both sides:

```asm
GameWinCheck:
GameWin:                    ; checkpoint: A = the winner's match wins
    CMP #MATCH_WINS
    BCS MatchWon
    ; next game: reset the game scores and serve toward the loser
    LDA #$00
    STA LeftScore
    STA RightScore
    LDA #SERVE_FRAMES
    STA ServeTimer
    ...
    RTS
MatchWon:
    LDA #2
    STA GameState
MatchOver:                  ; checkpoint: A = 2, the match is over
    LDA MatchLeft
    STA LeftScore
    LDA MatchRight
    STA RightScore
    RTS
```

The state log on the committed solution:

```text
# GameStateRead with -holdselect
BP:           1   1 54  94 | nv-BdIZc 00 00 00 fd |   (title, before the SELECT edge)
BP:           2   1 53  91 | nv-BdIZc 01 00 00 fd |   (play)
BP:         983   1 48  76 | nv-BdIzc 02 00 00 fd |   (match over)

# GameWin with -holdselect
BP:         631   4 46  70 | Nv-BdIzC 01 00 00 fd |
BP:         982   4 46  70 | Nv-BdIzC 02 00 00 fd |

# MatchOver with -holdselect
BP:         982   4 56 100 | Nv-BdIzC 02 00 00 fd |

# ServeCount with -holdselect
BP:           1   3 11 -35 | nV-BdIzC 3c 00 00 fd |
BP:           2   2 43  61 | nv-BdIzC 3b 00 00 fd |
BP:           3   2 43  61 | nv-BdIzC 3a 00 00 fd |
```

## Key Takeaways

- ✅ **Move the decision out of the kernel.** The preflight's direct range-test kernel wrote `GRP0` at cycle 49; P0 at X=16 has a deadline of cycle 28, so the left paddle was invisible. The 89-byte row table does the range tests once per frame in VBLANK and leaves the kernel with three table loads.
- ✅ **The two-line lookahead is the timing contract.** The first line begins with the three stores (cycles 12/18/24 in steady state); the second line decodes the next row. The pair costs 62 of 152 cycles. The first row's stores are at 8/14/20; P0's deadline at X=16 is 28 and the ball's at X=4 is 24.0.
- ✅ **A custom score buys the RAM.** The shared score library owns `$A0-$D7`; Pong's row table needs `$80-$D8`. One digit per player — P0 at X=64, P1 at X=88 — uses the same two players as the paddles, a 10×8 font, and one `HMOVE` after the band to reposition to 16/136 plus the ball.
- ✅ **The collision latches are one frame old by design.** `CXP0FB`/`CXP1FB` bit 6 is read in VBLANK, the direction is checked so a stale overlap cannot trap the ball, `CXCLR` clears the latch, and the angle table maps the hit offset to one of five vertical speeds.
- ✅ **The input map follows `include/vcs.asm`.** P0's up/down are `SWCHA` bits 4/5 and P1's are bits 0/1, active low. The paddles move 2 px/frame and clamp to 8..148.
- ✅ **The game is a state machine with a 60-frame serve.** The ball parks at 80/90, the first serve is fixed left, later serves travel toward the loser, and the first score to 9 flashes the winning digit. Fire or SELECT restarts.
- ✅ **A deterministic demo is part of the lesson.** The right paddle's 2 px/frame cap returns the opening rally; the left's 40-pixel tracking lag makes it miss afterward. The measured timeline (first point at frame 319, ninth at 631, game over at 632) is what makes the 2 s/6 s/12 s captures predictable.

## What's Next

Pong proves the row-table kernel with three objects and two score lines. [Lesson 70: Capstone 2 — Breakout](/part10-capstones/70-breakout) adds a brick field: a playfield zone above a play area, a 64-entry × 3-byte brick table, per-brick collision math, three lives and three levels, and the shared score library with the repositioning sequence you just built. The row table you wrote here is the second half of Breakout's kernel.
