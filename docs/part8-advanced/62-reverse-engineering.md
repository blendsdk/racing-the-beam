---
title: "Lesson 62: Reverse Engineering a Classic Game — Reading Wall Buster"
description: "Take a 4,096-byte course-written Breakout-style ROM apart with the Stella debugger: read the reset vector, the 262-line frame, the row-loop kernel, the score and brick tables, the RAM map, and the collision and score paths, then use the SELECT frame-map overlay to see the four phases and the row bar."
prev:
  text: "Lesson 61: Compression & Data Encoding — Fitting More in 4KB"
  link: "/part8-advanced/61-compression"
next:
  text: "Lesson 63: Modern Homebrew — Dev Carts and Community"
  link: "/part8-advanced/63-modern-homebrew"
---

# Lesson 62: Reverse Engineering a Classic Game — Reading Wall Buster

> **Part 8: Advanced Topics** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 02 (the Stella debugger), Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and memory), Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players), Lesson 26 (horizontal positioning), Lesson 39 (the score kernel), Lesson 48 (the kernel taxonomy)
> **You will learn:** a repeatable reverse-engineering method — vectors → init → frame → kernel → data → RAM → game logic; how to read a symbol file and a disassembly; how the reset vector, the four frame labels, the row loop, the score table, the brick table, and the collision path fit together; how to use the Stella debugger's breakpoints, state log, RAM/ROM views, and the SELECT frame-map overlay
> **You will build:** "Wall Buster" — a 4,096-byte course-written Breakout-style game: a paddle, a ball, a 6×4 brick wall, a two-digit score, a life counter, and a game-over/restart. It is the artifact you take apart, not a historical classic.

## Introduction

A cartridge is a 4,096-byte image with no labels, no comments, and no source. The console does not care: it reads three vectors at `$FFFA-$FFFF`, jumps to the reset address, and starts executing. Everything else — the frame, the kernel, the tables, the variables — is a pattern you can recover. This lesson teaches that recovery as a repeatable method, then uses a complete game as the specimen.

The specimen is **Wall Buster**, a course-written Breakout-style game. It is deliberately original: every byte is in this repository, so the lesson can annotate every routine and table without copyright risk. It is also deliberately classic-style: a paddle, a ball, a wall of bricks, a score, a life counter, and a game-over screen — the shape of dozens of 4K games. The method transfers to any ROM you are entitled to read; the addresses in this lesson are only Wall Buster's.

The game is complete before you reverse it. The joystick moves the paddle, the ball bounces off the walls, the paddle and the bricks, a brick disappears and the score increments, a ball lost at the bottom costs a life, and the red game-over field waits for fire. SELECT toggles a **frame-map overlay**: four background colours for VSYNC, VBLANK, the kernel, and overscan, plus a white row bar that steps across the screen as the kernel walks its 192 rows. The overlay is the visual evidence of the frame, and the doc explains what it can and cannot show.

::: details TypeScript Equivalent

The game's state and its per-frame step are easy to write in TypeScript. A `Game` object holds the ball, the paddle, the brick bits, and the score; `step()` updates them; `collide()` is a handful of comparisons; `draw(y)` returns the pixels of one line:

```typescript
type Game = {
  paddleX: number;
  ballX: number; ballY: number;
  ballDX: number; ballDY: number;
  score: number; lives: number;
  state: 'play' | 'over';
  bricks: number[];              // four 6-bit rows
};

function step(g: Game, left: boolean, right: boolean): void {
  if (g.state === 'over') return;

  // the paddle: manual or auto-demo
  if (left) g.paddleX = Math.max(0, g.paddleX - 4);
  else if (right) g.paddleX = Math.min(152, g.paddleX + 4);
  else g.paddleX = Math.min(152, Math.max(0, g.ballX - 3));

  // the ball
  g.ballX += g.ballDX;
  g.ballY += g.ballDY;
  if (g.ballX < 1 || g.ballX >= 158) {
    g.ballDX = -g.ballDX;
    g.ballX = Math.min(158, Math.max(0, g.ballX));
  }
  if (g.ballY < 23) { g.ballY = 23; g.ballDY = 2; }
  if (g.ballY >= 188) {
    g.lives--;
    if (g.lives <= 0) g.state = 'over';
    else respawn(g);
  }

  // the paddle's face and the bricks
  if (g.ballDY > 0 && g.ballY + 3 >= 176 && g.ballY + 3 < 184 &&
      g.ballX + 2 >= g.paddleX && g.paddleX + 8 >= g.ballX) {
    g.ballY = 172; g.ballDY = -2;
  }
  const edgeY = g.ballDY > 0 ? g.ballY + 3 : g.ballY;
  const row = Math.floor((edgeY - 32) / 8);
  const col = columnOf(g.ballX + 1);   // mirrors the right half; -1 for a gap
  if (row >= 0 && row < 4 && col >= 0 && (g.bricks[row] & (1 << col))) {
    g.bricks[row] &= ~(1 << col);
    g.score++;
    g.ballDY = -g.ballDY;
  }
}
```

The analogy teaches the shape — a state object, a step, a collision, a draw — and it breaks in the three places that matter on a 2600. First, the TypeScript `step()` runs once per frame and a `draw()` could paint a whole framebuffer; the console has **no framebuffer**, so the draw is the kernel and it runs once per scanline, in real time, inside a 76-cycle deadline. Second, the TypeScript numbers are JavaScript numbers; the real game stores each coordinate in one byte, and the ball's direction in a signed byte (`1`/`$FF` and `2`/`$FE`). Third, the TypeScript `collide()` can scan all 24 bricks; the 2600 version computes one index from the ball's leading edge and tests one bit, because the VBLANK budget is finite. The ROM tables — the score glyphs, the brick-to-playfield translation, the column map — have no TypeScript equivalent at all: they exist to turn arithmetic into a table read the kernel can afford.

:::

## Theory

### Section 1: The Seven-Pass Method

Reverse engineering a 2600 ROM is not a single trick. It is a route through the image, from the things the CPU must read first to the things the player sees last. The route in this lesson has seven passes:

| Pass | What you look at | What it tells you | Wall Buster |
|---|---|---|---|
| 1. Vectors | `$FFFA-$FFFF` | where the CPU starts | `$FFFC` = `$F000` |
| 2. Init | the reset target | how the machine is set up | `Reset` `$F000`, `+clean_start`, `StartGame` `$F3B3` |
| 3. Frame | the `VSYNC`/`VBLANK` writes | the 262-line shape and the timing labels | `StartFrame` `$F019`, `VblankStart` `$F027`, `BodyStart` `$F22F`, `OverscanStart` `$F2D9` |
| 4. Kernel | the `WSYNC` loop | what is drawn on each line and when | `PlayKernel` `$F23D`, `DrawBallLine` `$F2EC` |
| 5. Data | the tables | what the numbers mean | `ScoreGlyphs` `$F58C`, `BrickPF*` `$F484`, `ColTable` `$F434` |
| 6. RAM | `$80-$FF` | the live state | the 32-byte map in Section 6 |
| 7. Logic | the VBLANK code | how the state changes | `GameLogic` `$F06D` |

The order is not arbitrary. The vectors tell you where the program begins; the init tells you the starting state; the frame tells you where the code is in the 262-line budget; the kernel tells you what the frame is made of; the data tells you what the kernel is reading; the RAM tells you what changes; the logic tells you why. A reader who starts at the game logic without the frame and the kernel is reading a novel from the middle.

The tools are the ones the course has used since Lesson 02:

- **`acme -l`** writes a symbol file. The lesson's source is available, but the same file is what a reverse engineer builds by hand: a list of addresses and names. The symbol table is the map.
- **Stella's debugger** shows the TIA frame, the RAM, the ROM, and the disassembly. A breakpoint on an address pauses the CPU; `-dbg.logbreaks 1 -logtoconsole 1` prints the frame, scanline, cycle, and registers on every hit without stopping the run.
- **The state log** is the evidence. A screenshot proves a visual state; a log proves a transition and a clock. The checkpoints in this lesson name the instructions; the log's `Scn` and `Cy` columns are the frame's clock.

::: tip Read the vectors first
The 6507 has no BIOS and no operating system. At power-on it reads the RESET vector at `$FFFC`, loads it into the program counter, and executes. If the vector points at `$F000`, the first instruction is at `$F000`; if it points at `$F080`, the program starts there. A ROM that "does nothing" is usually a ROM whose vector is missing, wrong, or in a bank that is not selected at power-on. Lesson 56 is the mapper version of this rule; this lesson is the 4K version.
:::

### Section 2: The Vectors and the Init

The last six bytes of the 4K window are three vectors:

| Address | Vector | Wall Buster |
|---|---|---|
| `$FFFA-$FFFB` | NMI | `$F000` |
| `$FFFC-$FFFD` | RESET | `$F000` |
| `$FFFE-$FFFF` | IRQ | `$F000` |

The 2600 does not use interrupts: the NMI and IRQ vectors point at the same reset code so a stray interrupt cannot run into the void. The reset vector is the one that matters. In the committed ROM the bytes at `$FFFA` are `00 F0 00 F0 00 F0`, so all three vectors are `$F000` (little-endian: low byte first).

`Reset` at `$F000` does three things. It runs `+clean_start`, which disables interrupts and decimal mode, zeroes TIA registers `$00-$FF` and RAM `$80-$FF`, and sets the stack pointer to `$FF`. It sets `SWACNT` to zero so port A is an input port for the joystick. Then it calls `StartGame` at `$F3B3`, which writes the initial state:

| Byte | Value at power-on | Meaning |
|---|---|---|
| `Score` `$85` | `$00` | 0 points |
| `State` `$87` | `$00` | play |
| `Lives` `$86` | `$03` | three lives |
| `Brick0..3` `$8B-$8E` | `$3F` | all six columns in every row |
| `PaddleX` `$80` | `$4C` (76) | the paddle's left edge |
| `BallX` `$81` | `$4C` (76) | the ball's left edge |
| `BallY` `$82` | `$A8` (168) | the ball's top edge, just above the paddle |
| `BallDX` `$83` | `$01` | one pixel right per frame |
| `BallDY` `$84` | `$FE` | minus two: two pixels up per frame |

`StartGame` is also the restart routine: the game-over screen calls it on a fire edge. The initial values are therefore the same values a restarted game uses, which is exactly the kind of invariant a reverse engineer looks for: one routine, one set of constants, two callers.

### Section 3: The Frame

The NTSC frame is four phases:

| Phase | Lines | What the CPU does | Wall Buster label |
|---|---|---|---|
| VSYNC | 3 | tells the TV a new frame starts | `StartFrame` `$F019` |
| VBLANK | 37 | game logic, tables, positioning | `VblankStart` `$F027` |
| picture | 192 | the kernel draws one line per `WSYNC` | `BodyStart` `$F22F` |
| overscan | 30 | blank the picture, wait for the next frame | `OverscanStart` `$F2D9` |

`3 + 37 + 192 + 30 = 262`. The RIOT timer is set to 44 ticks for the 37-line VBLANK and 36 ticks for the 30-line overscan; the macros in `include/macro.asm` explain the arithmetic. The important consequence for reverse engineering is that the four labels are **timing anchors**: a breakpoint on `BodyStart` reports scanline 37, cycle 5; a breakpoint on `OverscanStart` reports scanline 229, cycle 6. If those numbers move, the frame is wrong even if the picture looks right.

The game's VBLANK is where all the state changes happen. The kernel is deliberately simple: it reads the state the VBLANK prepared and draws it. That split is the lesson's central architectural idea. A beginner writes game logic inside the kernel and runs out of cycles; a classic game does the arithmetic while the beam is blanked and spends the visible 192 lines only on register writes.

The one `HMOVE` of the frame is in VBLANK, after three coarse positioners:

```
SetCoarseP0  -> HMP0 / RESP0    (the paddle)
SetCoarseP1  -> HMP1 / RESP1    (the score column)
SetCoarseBL  -> HMBL / RESBL    (the ball)
STA WSYNC
STA HMOVE                        (one HBLANK applies all three fine offsets)
```

### Section 4: The Kernel and the Row Loop

`BodyStart` is a three-way selector. `Overlay` chooses the frame map (`MapKernel`), `State` chooses the game-over screen (`OverKernel`), and the default is `PlayKernel`. The play kernel is a sequence of zones, and every visible line passes through one subroutine:

```
PlayKernel
  visible 0-15    the score's sixteen rows       LDA (ScorePtr),Y / STA GRP1
  visible 16      a separator
  visible 17-22   the life bar                   two rows per life
  visible 23-31   a blank band
  visible 32-63   four brick rows                seven lines + one gap each
  visible 64-175  the open play area
  visible 176-183 the paddle
  visible 184-191 the bottom margin
```

The row counter is `Y`, and it is absolute: 0 at the first visible line, 191 at the last. `DrawBallLine` owns the checkpoint and the `WSYNC`:

```
DrawBallLine:
KernelRow:          ; Y = 0..190
    TYA
    CLC
    ADC #1
    SEC
    SBC BallY
    CMP #4
    BCS off
    LDA #2
    STA ENABL
    JMP sync
off:
    LDA #0
    STA ENABL
sync:
    STA WSYNC
    INY
    RTS
```

The ball's enable is **pipelined one line ahead in intent**. The call for row Y sets `ENABL` for row Y+1, before the `WSYNC`; the row Y+1 call then draws with the value the previous call prepared. But the store lands about 21 cycles after the call, after the first visible clocks. The ball's pixels to the left of the store keep the previous line's enable; the pixels to its right take the new one. The ball is therefore one scanline higher when it is on the right half than when it is on the left, and the collision test (which uses `BallY`) is one line below the visible ball on the right half. A controlled freeze at `BallX=100`, `BallY=100` draws the ball at row 99; at `BallX=24` it draws at row 100. This is a real 4K timing compromise, and the lesson records it rather than hiding it. The first row's `ENABL` is cleared in VBLANK; the final row's value is set by row 190.

The final row is special. `DrawLastLine` is a bare `STA WSYNC` + `RTS`, so its return address — `OverscanStart` — lands at scanline 229, cycle 6. A normal `DrawBallLine` would do the next-row work and the `INY` first and land at 229/8. The two-cycle difference is the difference between the course's frame skeleton and a frame that is two cycles late.

The kernel's worst line is life-bar row 22 with the ball on: its `STA WSYNC` starts at cycle 69 and the write completes at 72, four cycles before the line ends (seven from the instruction start). Without the ball the row is 67. The ball's top is 23, but the enable for row 23 is written during row 22, so on the right half the ball is also drawn on row 22. A brick line or gap with the ball on is 67. The score rows are 48, the play and paddle rows 40, the first visible line 54, and the first brick line 65. The measured ledger is in the source header, and the measured `BodyStart`/`OverscanStart` pair (37/5 and 229/6) proves the frame is 262 lines on the real ROM.

#### The overlay: what a TV can show

The 2600's VBLANK bit blanks the picture. The 3 VSYNC, 37 VBLANK, and 30 overscan lines are therefore **not visible on a TV**: the TIA may have a background colour in `COLUBK`, but the blanking signal removes it. Stella's window shows the 192 visible lines; it does not show the blanked phases. The overlay therefore cannot be a photograph of the real zones. It is a **frame map**:

| Map rows | Colour | Phase | Real lines |
|---|---|---|---|
| 0-2 | white `$0E` | VSYNC | 3 |
| 3-39 | blue `$84` | VBLANK | 37 |
| 40-161 | green `$C2` | kernel | 192 compressed into 122 |
| 162-191 | red `$42` | overscan | 30 |

The map keeps the three blanked phases' true line counts and compresses the 192-line kernel into the 122 lines that remain. The row bar is a four-pixel white dash at chunk `Y >> 3` (clamped to the right edge); as `Y` runs 0..191, the dash steps right once every eight rows. The two mirrored halves meet at the centre and then stay there through the red band. The diagonal is the row loop made visible: the dash on row Y is the row number, and the four colours are the frame's four phases.

The overlay is a **teaching projection**, not a claim that a TV shows blue VBLANK lines. The lesson is honest about the difference. The playfield and `COLUBK` writes also land partway into a row, so the first pixels of a map row can carry the previous row's value; read the bands and the staircase as the row loop's progression, not a cycle-exact photograph. The state log is the proof of the real frame: `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6 (play) or 229/7 (over) or 229/9 (map).

### Section 5: The Data Tables

The kernel is small because the data is large. Four tables carry most of the game's meaning:

**`ScoreGlyphs`** at `$F58C` is a 25 × 16 table: one 16-row column for each score value 0..24. Rows 0-6 are the tens digit, rows 7-8 are blank, rows 9-15 are the ones digit. The digits are a 5×7 font shifted one bit left inside the 8-pixel player, so the score column is 16 rows tall at X=76. The two 25-byte pointer tables `ScorePtrLo` (`$F71C`) and `ScorePtrHi` (`$F735`) hold each entry's address. VBLANK loads the pointer for the current `Score`; the kernel reads one row per scanline with `LDA (ScorePtr),Y` and writes `GRP1`.

**`BrickPF0Table`/`BrickPF1Table`/`BrickPF2Table`** at `$F484`, `$F4C4`, `$F504` translate a 6-bit brick-row mask into the three playfield bytes. The wall has six unique columns, each two chunks (8 pixels) wide, with one chunk of gap:

| Brick | Chunks | Playfield bits | PF byte |
|---|---|---|---|
| 0 | 1-2 | PF0 bits 5-6 | `$60` |
| 1 | 4-5 | PF1 bits 7-6 | `$C0` |
| 2 | 7-8 | PF1 bits 4-3 | `$18` |
| 3 | 10-11 | PF1 bits 1-0 | `$03` |
| 4 | 13-14 | PF2 bits 2-1 | `$06` |
| 5 | 16-17 | PF2 bits 5-4 | `$30` |

The playfield is reflected, so the right half mirrors the left: six unique bricks appear as twelve columns on screen, and clearing one bit removes both mirror images. That is why the collision table is a six-column wall even though the screen looks like a twelve-column wall. The four masks `Brick0..3` live at `$8B-$8E`; VBLANK's `RebuildBricks` loop at `$F1C0` reads each mask, looks up the three bytes, and stores them in `$8F-$9A`. The kernel's brick zone at `$F27E` loads the bytes for its row and holds them for seven lines.

**`ColTable`** at `$F434` maps the left half's pixel X (0..79) to a brick column 0..5, or `$FF` for a gap or margin. The right half is mirrored onto it by `159 - centre`. The table is the wall's geometry written out in bytes; a reader can reconstruct the brick layout by reading 80 bytes.

**`BitMask`** at `$F42E` is six bytes, `$01, $02, $04, $08, $10, $20`, one bit per brick column. **`BarPF0/1/2`** at `$F544`, `$F55C`, `$F574` are the overlay's 24-entry row bar: entry n lights one chunk at position n.

### Section 6: The RAM Map

The RIOT's 128 bytes of RAM are the game's entire state. The map is 32 bytes: nine state bytes at `$80-$88`, the 2-byte score pointer and the 4 masks and 12 cached PF bytes at `$89-$9A`, five scratch bytes at `$9B-$9F`, and the stack at `$F8-$FF`:

| Address | Name | Role |
|---|---|---|
| `$80` | `PaddleX` | the paddle's left edge, 0..152 |
| `$81` | `BallX` | the ball's left edge, 0..157 |
| `$82` | `BallY` | the ball's top edge, 23..188 |
| `$83` | `BallDX` | `1` right, `$FF` left |
| `$84` | `BallDY` | `2` down, `$FE` up |
| `$85` | `Score` | 0..24 |
| `$86` | `Lives` | 3..0 |
| `$87` | `State` | 0 play, 1 game over |
| `$88` | `Overlay` | 0 game, 1 frame map |
| `$89-$8A` | `ScorePtr` | the selected 16-row glyph column |
| `$8B-$8E` | `Brick0..3` | the four 6-bit brick-row masks |
| `$8F-$92` | `BrickPF0` | the four rows' PF0 bytes |
| `$93-$96` | `BrickPF1` | the four rows' PF1 bytes |
| `$97-$9A` | `BrickPF2` | the four rows' PF2 bytes |
| `$9B` | `LineCount` | the seven-line brick counter / the fire-edge scratch |
| `$9C` | `PrevSelect` | SELECT debounce |
| `$9D` | `PrevFire` | fire-edge debounce |
| `$9E` | `TmpRow` | brick collision scratch |
| `$9F` | `TmpCol` | brick collision scratch |
| `$F8-$FF` | stack | the JSR/RTS return addresses |

The map is small enough to hold in your head, which is the point. A reverse engineer who can name every byte can explain every write. The stack shares the same physical RAM as the variables: `$F8-$FF` in page 1 mirrors `$F8-$FF` in page 0, so a deep stack would collide with the game state. Wall Buster's call depth is one (`JSR DrawBallLine`), so the stack's top two bytes are all it uses.

### Section 7: The Game Logic and the Collisions

The VBLANK order is the game's turn structure:

1. **SELECT** toggles the overlay once per press (`SWCHB` bit 1, debounced by `PrevSelect`).
2. **Fire** restarts the game once per press, and only in `State=1` (`INPT4` bit 7, edge-detected by `PrevFire`).
3. **The paddle** follows the joystick, or the auto-demo: `PaddleX = BallX - 3`, clamped to 0..152. The auto-demo is why the captures show a game in progress without input.
4. **The ball** moves `BallX += BallDX`, `BallY += BallDY`.
5. **The walls and ceiling**: `BallX < 1` or `>= 158` flips `BallDX`; `BallY < 23` clamps to 23 and sets `BallDY = 2`.
6. **The bottom**: `BallY >= 188` costs a life; `Lives` reaches 0 → `State = 1`; otherwise `RespawnBall` serves from the paddle.
7. **The paddle face**: if the ball is moving down and its bottom edge is in rows 176..183 and its x overlaps the paddle, snap `BallY` to 172, set `BallDY = $FE`, and set `BallDX` by which half of the paddle was hit.
8. **The bricks**: the ball's leading edge (bottom when moving down, top when moving up) picks a row; the ball's centre picks a column; the column table rejects the gaps; the bit test clears the brick, increments the score, and flips `BallDY`.
9. **Display setup**: the score pointer, the brick playfield bytes, the colours, the three coarse positioners, one `HMOVE`, and the VBLANK timer wait.

The brick collision is the densest arithmetic in the game, and it is worth reading line by line:

```
row = (leading Y - 32) >> 3          ; 0..3, the four brick rows
centre = BallX + 1                    ; the ball is two pixels wide
if centre >= 80: centre = 159 - centre ; mirror the right half onto the left
col = ColTable[centre]                ; 0..5, or $FF for a gap
index = row * 6 + col                 ; 0..23
if BitMask[col] & Brick0[row]:        ; is the brick still there?
    Brick0[row] ^= BitMask[col]       ; clear it
    Score++                            ; one point
    BallDY ^= $FC                      ; 2 <-> $FE (reverse vertical)
```

The `HitBrick` checkpoint is placed at the top of the hit path; the following `TAY` mirrors the index into Y for the debugger, and the code then loads the column from `TmpCol`. A breakpoint reports `A = index` (0..23). The `ScoreWrite` checkpoint is placed immediately after `LDA Score`, so it reports `A = score` (1..24). Those two labels are the reverse engineer's best handles on the game: they fire exactly when the state changes and they carry the two numbers that matter.

The game-over screen is `State=1`. The play kernel's selector sends the frame to `OverKernel`: the score and the life bar stay at the top, the field turns red, the paddle and ball are hidden, and a white bar at rows 176-183 is the "press fire" invitation. A fire edge calls `StartGame` and returns to play. The wall is rebuilt from the same `$3F` constants, so a restart is indistinguishable from a power-on start except for the frame counter.

### Section 8: Reading It in Stella

The lesson's evidence is a set of breakpoints and a symbol file. Assemble with a symbol list:

```bash
acme -f plain -l build/demo-62.sym -o build/demo-62.bin \
  lessons/part8-advanced/62-reverse-engineering/demo-62.asm
```

The symbol file is a list of names and addresses. The important ones for this lesson:

| Symbol | Address | What it is |
|---|---|---|
| `Reset` | `$F000` | the reset vector's target |
| `StartFrame` | `$F019` | the first VSYNC line |
| `VblankStart` | `$F027` | the first VBLANK line |
| `OverlayWrite` | `$F04C` | the overlay toggle (A = the new `Overlay` byte) |
| `GameLogic` | `$F06D` | the play-state update |
| `BallMove` | `$F0B6` | the ball's new X in A |
| `HitBrick` | `$F186` | the brick index in A |
| `ScoreWrite` | `$F19E` | the new score in A |
| `DisplaySetup` | `$F1B2` | the per-frame tables and colours |
| `BodyStart` | `$F22F` | the first visible line |
| `PlayKernel` | `$F23D` | the 192-line play kernel |
| `BrickSetup` | `$F27E` | the first brick row's PF bytes |
| `BrickLine` | `$F28A` | the seven-line brick loop |
| `BrickGap` | `$F291` | the row gap and the next row's state |
| `BricksDone` | `$F2A8` | the last gap |
| `OverscanStart` | `$F2D9` | the first overscan instruction |
| `KernelRow` | `$F2EC` | Y = the visible row, 0..190 |
| `KernelRowLast` | `$F306` | Y = 191, the final visible row |
| `OverKernel` | `$F309` | the game-over screen |
| `MapKernel` | `$F370` | the overlay frame map |
| `MapRow` | `$F376` | Y = the map row, 0..191 |
| `StartGame` | `$F3B3` | the initial state and the restart |
| `RespawnBall` | `$F3DE` | the serve after a life is lost |
| `BitMask` | `$F42E` | the six brick-column bits |
| `ColTable` | `$F434` | the left half's column map |
| `BrickPF0Table` | `$F484` | the brick mask → PF0 table |
| `BrickPF1Table` | `$F4C4` | the brick mask → PF1 table |
| `BrickPF2Table` | `$F504` | the brick mask → PF2 table |
| `BarPF0/1/2` | `$F544/$F55C/$F574` | the overlay row bar |
| `ScoreGlyphs` | `$F58C` | the 25 × 16 score table |
| `ScorePtrLo` | `$F71C` | the score entry's low bytes |
| `ScorePtrHi` | `$F735` | the score entry's high bytes |

The disassembly matches the source. Here is the reset/frame entry and the ball/collision/score paths:

```text
F000  78        SEI                     ; Reset: +clean_start
F001  D8        CLD
F002  A2 00     LDX  #$00
F004  8A        TXA
F005  A8        TAY
F006  95 00     STA  $00,X              ; zero TIA and RAM
F008  CA        DEX
F009  D0 FB     BNE  $F006
F00B  A2 FF     LDX  #$FF
F00D  9A        TXS
F00E  A9 00     LDA  #$00
F010  8D 81 02  STA  $0281              ; SWACNT: port A is input
F013  20 B3 F3  JSR  $F3B3              ; StartGame
F016  4C 19 F0  JMP  $F019              ; StartFrame

F019  A9 02     LDA  #$02              ; StartFrame: VSYNC on
F01B  85 00     STA  $00
F01D  85 02     STA  $02               ; three WSYNCs
F01F  85 02     STA  $02
F021  85 02     STA  $02
F023  A9 00     LDA  #$00
F025  85 00     STA  $00               ; VSYNC off
F027  A9 02     LDA  #$02              ; VblankStart
F029  85 01     STA  $01               ; blank the picture
F02B  A9 2C     LDA  #$2C
F02D  8D 96 02  STA  $0296              ; TIM64T = 44: the 37-line VBLANK

F0AF  A5 81     LDA  $81               ; BallX
F0B1  18        CLC
F0B2  65 83     ADC  $83               ; BallDX
F0B4  85 81     STA  $81
F0B6  A5 82     LDA  $82               ; BallMove: A = the new BallX
F0B8  18        CLC
F0B9  65 84     ADC  $84               ; BallDY
F0BB  85 82     STA  $82

F186  A8        TAY                     ; HitBrick: A = row*6 + col
F187  A5 9E     LDA  $9E               ; TmpRow
F189  AA        TAX                     ; X = row
F18A  A4 9F     LDY  $9F               ; Y = column
F18C  B9 2E F4  LDA  $F42E,Y            ; BitMask[col]
F18F  35 8B     AND  $8B,X              ; Brick0[row]
F191  F0 1F     BEQ  $F1B2              ; gap or empty: no hit
F193  B9 2E F4  LDA  $F42E,Y
F196  55 8B     EOR  $8B,X              ; clear the bit
F198  95 8B     STA  $8B,X
F19A  E6 85     INC  $85                ; Score++
F19C  A5 85     LDA  $85                ; ScoreWrite is $F19E; A = the score
F19E  A5 84     LDA  $84                ; BallDY
F1A0  49 FC     EOR  #$FC               ; 2 <-> $FE
F1A2  85 84     STA  $84

F2EC  98        TYA                     ; KernelRow: Y = the visible row
F2ED  18        CLC
F2EE  69 01     ADC  #$01
F2F0  38        SEC
F2F1  E5 82     SBC  $82                ; BallY
F2F3  C9 04     CMP  #$04
F2F5  B0 07     BCS  $F2FE              ; outside the four-row window
F2F7  A9 02     LDA  #$02
F2F9  85 1F     STA  $1F                ; ENABL
F2FB  4C 02 F3  JMP  $F302
F2FE  A9 00     LDA  #$00
F300  85 1F     STA  $1F
F302  85 02     STA  $02               ; STA WSYNC
F304  C8        INY
F305  60        RTS
F306  85 02     STA  $02               ; KernelRowLast: STA WSYNC
F308  60        RTS

FFFA  00 F0     !word $F000            ; NMI
FFFC  00 F0     !word $F000            ; RESET
FFFE  00 F0     !word $F000            ; IRQ
```

The bytes at `$FFFA` are data, not instructions; the disassembler shows them as `BRK`/`BEQ` if run as code, which is why the vector table is quoted as `!word` values. The source's `!word Reset, Reset, Reset` at `$FFFA` produces exactly `00 F0 00 F0 00 F0`.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/demo-62.bin lessons/part8-advanced/62-reverse-engineering/demo-62.asm
stella build/demo-62.bin
```

The committed ROM is `docs/public/roms/part8-advanced/62-reverse-engineering/demo-62.bin`, 4,096 bytes. The source is `lessons/part8-advanced/62-reverse-engineering/demo-62.asm`.

### Full Source

The complete annotated source:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 62: Reverse Engineering a Classic Game
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "Wall Buster": a 4,096-byte course-written Breakout-style game, small
;   enough to annotate in full and complete enough to take apart with the
;   Stella debugger.  It is NOT a historical classic: every byte is original,
;   so the lesson can map every routine, table, and RAM byte without copyright
;   risk.  The reverse-engineering method transfers to any 4K ROM.
;
; The game:
;   A paddle (player 0) at the bottom, a two-pixel ball (the ball sprite), a
;   6 x 4 brick wall (the playfield), a two-digit score (player 1), a life
;   counter (the vertical bar under the score), and a game-over/restart state.
;   The joystick moves the paddle; with no joystick input the paddle tracks
;   the ball, so the ROM demonstrates itself.  A brick disappears when the
;   ball's leading edge reaches its two playfield chunks; the score goes up by
;   one; a ball that reaches the bottom costs a life; at zero lives the red
;   game-over field appears and fire starts a new game.
;
; The wall (playfield):
;   20 chunks, 4 pixels each, reflected into the right half.  Six unique brick
;   columns, each two chunks (8 pixels) wide, with one chunk of gap:
;     brick 0  chunks 1-2    PF0 bits 5-6   $60
;     brick 1  chunks 4-5    PF1 bits 7-6   $C0
;     brick 2  chunks 7-8    PF1 bits 4-3   $18
;     brick 3  chunks 10-11  PF1 bits 1-0   $03
;     brick 4  chunks 13-14  PF2 bits 2-1   $06
;     brick 5  chunks 16-17  PF2 bits 5-4   $30
;   Each of the four rows is one 6-bit mask (Brick0..Brick3).  VBLANK rebuilds
;   the four rows' PF bytes from the masks every frame; a hit clears one bit.
;   The reflected playfield draws each brick twice, so the wall shows twelve
;   columns but the collision table is the six-column wall.  Clearing a bit
;   removes both mirror images, which is the classic playfield behaviour.
;
; The score (player 1):
;   ScoreGlyphs is a 25 x 16 table: one 16-row column per score value 0..24.
;   Rows 0-6 are the tens digit, rows 7-8 are blank, rows 9-15 are the ones
;   digit.  ScorePtr points at the selected entry; the kernel reads one row per
;   scanline.  The two digits are stacked vertically at X=76.  Rows 17-22 are
;   the life bar: two rows per remaining life (six rows for three lives).
;
; The overlay (SELECT):
;   A TV can only show the 192 visible lines; the 3 VSYNC, 37 VBLANK, and 30
;   overscan lines are blanked.  The overlay therefore draws a frame map in
;   the visible window: rows 0-2 white (VSYNC), rows 3-39 blue (VBLANK),
;   rows 40-161 green (the kernel, compressed into 122 lines), rows 162-191
;   red (overscan).  On every row the playfield draws a four-pixel dash whose
;   position is the row number divided by eight, so the diagonal is the
;   kernel's row loop: row Y lights chunk Y >> 3 (clamped to the right edge).
;   The four colours and the diagonal are the evidence that the frame has four
;   phases and that the kernel walks Y from 0 to 191.  The map is a visual
;   projection, not a photograph of the blanked regions: their true line
;   counts (3, 37, 30) are kept and the 192-line kernel is compressed into the
;   122 lines that remain.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229/6.
;   One HMOVE per frame, in VBLANK, after three coarse positioners.
;
; Kernel cycle ledger (the line is 76 cycles; the measured frame stays 262):
;   DrawBallLine stores the ball enable 21 cycles after it is entered on the
;     ball-off path (TYA 2, CLC 2, ADC 2, SEC 2, SBC 3, CMP 2, BCS 3,
;     LDA 2, STA 3), or 23 on the ball-on path (BCS 2, LDA 2, STA 3, JMP 3).
;     STA WSYNC adds three more, so the WSYNC write is at 24 or 26.
;   The numbers below are measured with a Stella breakpoint at BallLineSync,
;     not derived; each is the CPU cycle at which the STA WSYNC instruction
;     starts; the write completes three cycles later:
;       first visible line  54      score rows (1-15)      48
;       separator 16        44      life bar 17 (first)   64
;       life bar 18-21      67      life bar 22 (ball)     69
;       blank 23-31         46/40
;       first brick 32      65      brick body             43
;       brick gap 63        65      play 64 (first)        48
;       play 65-175         40      paddle 176 (first)     46
;       paddle 177-183      40      bottom 184 (first)     50
;       bottom 185-190      42
;   The worst line is life-bar row 22 with the ball on: the STA WSYNC starts
;     at 69 and the write completes at 72, four cycles before the line ends
;     (seven from the instruction start).  Without the ball the row is 67.
;     The ball's top is 23, but the enable for row 23 is written during row
;     22, so on the right half the ball is also drawn on row 22.  A brick
;     line or gap with the ball on is 67.  The first visible line's 54
;     includes the one-time zone entry.  Every line fits.
;   The last visible row is DrawLastLine: STA WSYNC + RTS, so the return
;     address (OverscanStart) is at scanline 229 cycle 6 (play), 7 (game
;     over), or 9 (frame map).
;
; Checkpoints (the state log's scanline/cycle and the A or Y register):
;   StartFrame    the first VSYNC instruction
;   VblankStart   the first VBLANK instruction
;   BodyStart     the first visible line
;   OverscanStart the first overscan instruction
;   KernelRow     Y = the visible row, 0..190 (inside DrawBallLine)
;   KernelRowLast Y = 191, the final visible row (DrawLastLine)
;   BallMove      A = the new BallX
;   HitBrick      A = the brick index 0..23
;   ScoreWrite    A = the new score
;   OverlayWrite  A = the new overlay flag (the Overlay byte at $88)
;   MapRow        Y = the overlay map's row, 0..191
;
; RAM map (+clean_start zeroes every byte):
;   $80  PaddleX     the paddle's left edge, 0..152
;   $81  BallX       the ball's left edge, 0..157
;   $82  BallY       the ball's top edge, 23..188
;   $83  BallDX      1 = right, $FF = left
;   $84  BallDY      2 = down, $FE = up
;   $85  Score       0..24
;   $86  Lives       3..0
;   $87  State       0 = play, 1 = game over
;   $88  Overlay     0 = game, 1 = frame map
;   $89-$8A ScorePtr  the selected 16-row glyph column
;   $8B-$8E Brick0..3 the four 6-bit brick-row masks
;   $8F-$92 BrickPF0  the four rows' PF0 bytes
;   $93-$96 BrickPF1  the four rows' PF1 bytes
;   $97-$9A BrickPF2  the four rows' PF2 bytes
;   $9B  LineCount    the seven-line brick counter / the fire-edge scratch
;   $9C  PrevSelect   SELECT debounce
;   $9D  PrevFire     fire-edge debounce
;   $9E  TmpRow       brick collision scratch
;   $9F  TmpCol       brick collision scratch
;   $F8-$FF stack
;
; Build: acme -f plain -o build/lesson62.bin \
;        lessons/part8-advanced/62-reverse-engineering/demo-62.asm
; Run:   stella build/lesson62.bin
; The ROM is 4,096 bytes.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44          ; 37-line VBLANK (44 ticks)
OVERSCAN_TIMER = 36          ; 30-line overscan (1 + 35 x 64 cycles)
POS_BIAS       = 3           ; the Lesson 26 output-delay bias

BALL_H         = 4           ; the ball's visible height in scanlines
BALL_TOP       = 23          ; the first row below the life bar
BALL_BOTTOM    = 188         ; the first row past the paddle
BRICK_TOP      = 32          ; the wall's first visible row
BRICK_ROWS     = 4
BRICK_H        = 8
PADDLE_Y       = 176         ; the paddle's first visible row
PADDLE_MAX     = 152         ; the paddle's rightmost left edge
P1_X           = 76          ; the score column's left edge

C_WHITE        = $0E
C_GOLD         = $1A
C_BRICK        = $1A
C_RED          = $42
C_BLUE         = $84
C_GREEN        = $C2
C_PADDLE       = $C8
C_BG           = $02
C_VSYNC        = $0E
C_VBLANK       = $84
C_KERNEL       = $C2
C_OVERSCAN     = $42

; =============================================================================
; RAM ALLOCATION ($80-$9F; +clean_start zeroes every byte)
; =============================================================================
PaddleX     = $80
BallX       = $81
BallY       = $82
BallDX      = $83
BallDY      = $84
Score       = $85
Lives       = $86
State       = $87
Overlay     = $88
ScorePtr    = $89            ; $89-$8A
Brick0      = $8B            ; $8B-$8E
Brick1      = $8C
Brick2      = $8D
Brick3      = $8E
BrickPF0    = $8F            ; $8F-$92
BrickPF1    = $93            ; $93-$96
BrickPF2    = $97            ; $97-$9A
LineCount   = $9B
PrevSelect  = $9C
PrevFire    = $9D
TmpRow      = $9E
TmpCol      = $9F

; =============================================================================
; RESET — the TIA setup and the first game
; =============================================================================
    * = $F000

Reset:
    +clean_start             ; zero TIA and RAM, set SP = $FF
    LDA #$00
    STA SWACNT               ; port A is an input port (the joystick)
    JSR StartGame            ; score 0, three lives, full wall, ball in play
    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                  ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                 ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK               ; blank the picture
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; SELECT — one toggle per press, not one per frame
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  PrevSelect remembers the previous
; frame so a held switch toggles the overlay once.
    LDA SWCHB
    AND #$02
    BEQ SelectDown
    LDA #$00
    STA PrevSelect
    JMP SelectDone
SelectDown:
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA Overlay
    EOR #$01
    STA Overlay
OverlayWrite:                ; checkpoint: A = the new overlay flag
    NOP
SelectDone:

; -----------------------------------------------------------------------------
; FIRE — one start per press, and only on the game-over screen
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR flips it to 1 = pressed; the
; changed-and-still-pressed test keeps only the 0 -> 1 edge.
    LDA INPT4
    AND #$80
    EOR #$80
    STA LineCount            ; this frame's fire bit (scratch)
    EOR PrevFire
    AND LineCount
    BEQ NoFire
    LDA State
    BEQ NoFire
    JSR StartGame            ; fire restarts the game
NoFire:
    LDA LineCount
    STA PrevFire

; -----------------------------------------------------------------------------
; GAME LOGIC — only while State = 0
; -----------------------------------------------------------------------------
    LDA State
    BEQ GameLogic
    JMP DisplaySetup

GameLogic:
; --- the paddle: the joystick, or the auto-demo ------------------------------
    LDA SWCHA
    AND #$C0                 ; P0 left (bit 6) and right (bit 7)
    CMP #$C0
    BEQ AutoPaddle           ; neither pressed: track the ball
    LDA SWCHA
    AND #$40                 ; left
    BNE PaddleRight
    LDA PaddleX
    SEC
    SBC #4
    BCS PaddleLeftOK
    LDA #0
PaddleLeftOK:
    JMP PaddleStore
PaddleRight:
    LDA SWCHA
    AND #$80                 ; right
    BNE PaddleDone
    LDA PaddleX
    CLC
    ADC #4
    CMP #(PADDLE_MAX + 1)
    BCC PaddleStore
    LDA #PADDLE_MAX
    JMP PaddleStore
AutoPaddle:
    LDA BallX
    SEC
    SBC #3                   ; centre the 8-pixel paddle on the 2-pixel ball
    BCS AutoPaddleOK
    LDA #0
AutoPaddleOK:
    CMP #(PADDLE_MAX + 1)
    BCC PaddleStore
    LDA #PADDLE_MAX
PaddleStore:
    STA PaddleX
PaddleDone:

; --- the ball moves one byte per axis --------------------------------------
    LDA BallX
    CLC
    ADC BallDX
    STA BallX
BallMove:                    ; checkpoint: A = the new BallX
    LDA BallY
    CLC
    ADC BallDY
    STA BallY

; --- side walls and the ceiling --------------------------------------------
    LDA BallX
    CMP #1
    BCC BounceX
    CMP #158                 ; the ball is two pixels wide: 158-159 is the edge
    BCS BounceX
    JMP XDone
BounceX:
; Clamp before the flip: a fast BallDX must not leave BallX at 159, because the
; brick test's centre would be 160 and the mirrored column $FF would read past
; the 80-byte ColTable.  The ball is two pixels wide, so 158 is the last legal
; left edge.
    LDA BallX
    CMP #158
    BCC LeftWallClamp
    LDA #158
    STA BallX
    JMP FlipX
LeftWallClamp:
    LDA #0
    STA BallX
FlipX:
    LDA BallDX
    EOR #$FE                 ; 1 <-> $FF
    STA BallDX
XDone:
    LDA BallY
    CMP #BALL_TOP
    BCS TopDone
    LDA #BALL_TOP
    STA BallY
    LDA #2
    STA BallDY
TopDone:

; --- the bottom: a life, or the game-over state ----------------------------
    LDA BallY
    CMP #BALL_BOTTOM
    BCC BottomDone
    DEC Lives
    BEQ GameOver
    JSR RespawnBall
    JMP BottomDone
GameOver:
    LDA #1
    STA State
BottomDone:

; --- the paddle: a bounce, a snap above the paddle, and an angle -----------
    LDA BallDY
    BMI NoPaddle
    LDA BallY
    CLC
    ADC #3                   ; the ball's bottom edge
    CMP #PADDLE_Y
    BCC NoPaddle
    CMP #(PADDLE_Y + 8)
    BCS NoPaddle
    LDA BallX
    CLC
    ADC #2                   ; the ball's right edge
    CMP PaddleX
    BCC NoPaddle
    LDA PaddleX
    CLC
    ADC #8
    CMP BallX
    BCC NoPaddle
; --- a hit: snap the ball above the paddle and reverse the vertical step ---
    LDA #(PADDLE_Y - BALL_H)
    STA BallY
    LDA #$FE
    STA BallDY
    LDA BallX
    CLC
    ADC #1                   ; the ball's centre
    SEC
    SBC PaddleX
    CMP #4
    BCC PaddleHitLeft
    LDA #1                   ; right half: send it right
    BNE PaddleDXStore
PaddleHitLeft:
    LDA #$FF                 ; left half: send it left
PaddleDXStore:
    STA BallDX
NoPaddle:

; --- the bricks: the leading edge picks one row and the centre one column --
    LDA BallDY
    BMI BrickUp
    LDA BallY
    CLC
    ADC #3                   ; moving down: the bottom edge leads
    JMP BrickEdge
BrickUp:
    LDA BallY                ; moving up: the top edge leads
BrickEdge:
    CMP #BRICK_TOP
    BCC NoBrickHit
    CMP #(BRICK_TOP + 32)
    BCS NoBrickHit
    SEC
    SBC #BRICK_TOP
    LSR
    LSR
    LSR
    STA TmpRow               ; row 0..3
    LDA BallX
    CLC
    ADC #1                   ; the ball's centre
    TAX
    CPX #80
    BCC BrickColLeft
    TXA
    EOR #$FF
    SEC
    SBC #96                  ; 159 - centre: mirror the right half
    TAX
BrickColLeft:
    LDA ColTable,X
    CMP #$FF
    BEQ NoBrickHit
    STA TmpCol               ; column 0..5
    LDA TmpRow
    ASL
    STA LineCount
    ASL
    CLC
    ADC LineCount            ; row * 6
    CLC
    ADC TmpCol
HitBrick:                    ; checkpoint: A = the brick index 0..23
    TAY                      ; mirror the index into Y for the debugger
    LDA TmpRow
    TAX                      ; X = row
    LDY TmpCol
    LDA BitMask,Y
    AND Brick0,X
    BEQ NoBrickHit
; --- clear the bit, score one, and reverse the vertical step ---------------
    LDA BitMask,Y
    EOR Brick0,X
    STA Brick0,X
    INC Score
    LDA Score
ScoreWrite:                  ; checkpoint: A = the new score
    LDA BallDY
    EOR #$FC                 ; 2 <-> $FE
    STA BallDY
    LDA Brick0
    ORA Brick1
    ORA Brick2
    ORA Brick3
    BNE NoBrickHit
    LDA #1                   ; the wall is gone: the game is over (a win)
    STA State
NoBrickHit:

; =============================================================================
; DISPLAY SETUP — tags, tables, colours and the one HMOVE
; =============================================================================
DisplaySetup:
; --- the score pointer: one of the 25 sixteen-row columns -------------------
    LDX Score
    LDA ScorePtrLo,X
    STA ScorePtr
    LDA ScorePtrHi,X
    STA ScorePtr+1

; --- rebuild the four brick rows' playfield bytes from the masks -----------
    LDX #0
RebuildBricks:
    LDY Brick0,X
    LDA BrickPF0Table,Y
    STA BrickPF0,X
    LDA BrickPF1Table,Y
    STA BrickPF1,X
    LDA BrickPF2Table,Y
    STA BrickPF2,X
    INX
    CPX #4
    BNE RebuildBricks

; --- colours, sizes, and the blank TIA state -------------------------------
    LDA #C_WHITE
    STA COLUP1               ; the score and the life bar
    LDA #C_PADDLE
    STA COLUP0               ; the paddle
    LDA #C_BRICK
    STA COLUPF               ; the bricks and the ball
    LDA State
    BEQ NormalBg
    LDA #C_RED
    JMP BgStore
NormalBg:
    LDA #C_BG
BgStore:
    STA COLUBK
    LDA #$11                 ; reflect the playfield; the ball is 2 px
    STA CTRLPF
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1
    STA GRP0
    STA GRP1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA TmpCol               ; the brick-column scratch starts clear

; --- position P0 (paddle), P1 (score), BL (ball), then one HMOVE -----------
; Each coarse routine consumes a line; the three calls and the final WSYNC
; fit inside the 37-line VBLANK, and one HMOVE applies all three fine values.
    LDA PaddleX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA #(P1_X + POS_BIAS)
    JSR SetCoarseP1
    LDA BallX
    CLC
    ADC #(POS_BIAS + 1)      ; the ball's reset is one clock shorter
    JSR SetCoarseBL
    STA WSYNC
    STA HMOVE                ; the one HMOVE of the frame

    +wait_timer
    LDA #$00
    STA VBLANK               ; picture on

; =============================================================================
; THE VISIBLE KERNEL — selector: map, game-over, or play
; =============================================================================
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    LDA Overlay
    BEQ NotMap
    JMP MapKernel
NotMap:
    LDA State
    BEQ PlayKernel
    JMP OverKernel

; -----------------------------------------------------------------------------
; PLAY KERNEL — 192 lines, four zones, one JSR per line
; -----------------------------------------------------------------------------
PlayKernel:
    LDY #0
; --- visible 0-15: the score's sixteen rows --------------------------------
ScoreRows:
    LDA (ScorePtr),Y
    STA GRP1
    JSR DrawBallLine
    CPY #16
    BNE ScoreRows

; --- visible 16: the separator between the score and the life bar ----------
    LDA #$00
    STA GRP1
    JSR DrawBallLine

; --- visible 17-22: the life bar, two rows per life ------------------------
    LDX #6
LivesRows:
    LDA Lives
    ASL
    STA TmpRow
    TYA
    SEC
    SBC #17
    CMP TmpRow
    BCS NoLifeBar
    LDA #$FF
    BNE LifeBarStore
NoLifeBar:
    LDA #$00
LifeBarStore:
    STA GRP1
    JSR DrawBallLine
    DEX
    BNE LivesRows

; --- visible 23-31: the gap between the life bar and the wall --------------
    LDA #$00
    STA GRP1
    LDX #9
BlankRows:
    JSR DrawBallLine
    DEX
    BNE BlankRows

; --- visible 32-63: four brick rows, seven lines plus a one-line gap ------
; X is 0 after the blank loop and becomes the brick-row index.  LineCount is
; the seven-line counter; the gap line prepares the next row's state so the
; first brick line only writes the three PF bytes.
    LDA #7
    STA LineCount
BrickSetup:
    LDA BrickPF0,X
    STA PF0
    LDA BrickPF1,X
    STA PF1
    LDA BrickPF2,X
    STA PF2
BrickLine:
    JSR DrawBallLine
    DEC LineCount
    BNE BrickLine
BrickGap:
    LDA #$00                 ; the row gap: no playfield on this line
    STA PF0
    STA PF1
    STA PF2
    LDA #7                   ; prepare the next row's seven-line counter
    STA LineCount
    INX
    CPX #4
    BEQ BricksDone
    JSR DrawBallLine         ; the gap line for rows 0-2
    JMP BrickSetup
BricksDone:
    JSR DrawBallLine         ; the gap line for row 3

; --- visible 64-175: the open play area ------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDX #112
PlayRows:
    JSR DrawBallLine
    DEX
    BNE PlayRows

; --- visible 176-183: the paddle -------------------------------------------
    LDA #$FF
    STA GRP0
    LDX #8
PaddleRows:
    JSR DrawBallLine
    DEX
    BNE PaddleRows

; --- visible 184-191: the bottom margin ------------------------------------
    LDA #$00
    STA GRP0
    LDX #8
BottomRows:
    DEX
    BEQ BottomLast
    JSR DrawBallLine
    JMP BottomRows
BottomLast:
    JSR DrawLastLine

; =============================================================================
; OVERSCAN — 30 lines, then the next frame
; =============================================================================
; DrawLastLine ends with STA WSYNC + RTS, so its return address is this label
; at scanline 229 cycle 6.
OverscanStart:               ; checkpoint: scanline 229, cycle 6
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; -----------------------------------------------------------------------------
; DrawBallLine — one scanline: the row checkpoint and the next row's ball flag
; -----------------------------------------------------------------------------
; Y is the absolute visible row.  The ball window for the row being drawn was
; prepared by the previous call, so this call sets the window for row Y+1
; before the WSYNC.  The ENABL store lands about 21 cycles after the call,
; after the first visible clocks; the pixels of the ball that lie left of the
; store keep the previous line's enable, while the pixels to its right take
; the new one.  The ball is therefore one scanline higher when it is on the
; right half (X above the store pixel) than when it is on the left.  The
; collision test uses BallY, so it is one line below the visible ball on the
; right half.  That is a real 4K timing compromise; the doc records it.
DrawBallLine:
KernelRow:                   ; checkpoint: Y = the visible row 0..190
    TYA
    CLC
    ADC #1
    SEC
    SBC BallY
    CMP #BALL_H
    BCS BallNextOff
    LDA #$02
    STA ENABL
    JMP BallLineSync
BallNextOff:
    LDA #$00
    STA ENABL
BallLineSync:
    STA WSYNC
    INY
    RTS

; -----------------------------------------------------------------------------
; DrawLastLine — the 192nd row: its ball flag was set by row 190, so this is
; a bare WSYNC and return.  The return lands on OverscanStart at 229/6.
; -----------------------------------------------------------------------------
DrawLastLine:
KernelRowLast:               ; checkpoint: Y = 191, the final visible row
    STA WSYNC
    RTS

; -----------------------------------------------------------------------------
; OVER KERNEL — the red field, the final score, and the restart bar
; -----------------------------------------------------------------------------
OverKernel:
    LDY #0
OverScore:
    LDA (ScorePtr),Y
    STA GRP1
    STA WSYNC
    INY
    CPY #16
    BNE OverScore

    LDA #$00
    STA GRP1
    STA WSYNC
    INY

    LDX #6
OverLives:
    LDA Lives
    ASL
    STA TmpRow
    TYA
    SEC
    SBC #17
    CMP TmpRow
    BCS OverNoLife
    LDA #$FF
    BNE OverLifeStore
OverNoLife:
    LDA #$00
OverLifeStore:
    STA GRP1
    STA WSYNC
    INY
    DEX
    BNE OverLives

; --- visible 23-175: the red field -----------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP1                 ; clear the life bar's last $FF from the red field
    LDX #153
OverField:
    STA WSYNC
    DEX
    BNE OverField

; --- visible 176-183: the white restart bar --------------------------------
    LDA #$FF
    STA PF0
    STA PF1
    STA PF2
    LDA #C_WHITE
    STA COLUPF
    LDX #8
OverBar:
    STA WSYNC
    DEX
    BNE OverBar

; --- visible 184-191: the red bottom margin --------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDX #8
OverBottom:
    STA WSYNC
    DEX
    BNE OverBottom
    JMP OverscanStart

; -----------------------------------------------------------------------------
; MAP KERNEL — the overlay: four phase colours and the row bar
; -----------------------------------------------------------------------------
; Rows 0-2 white (VSYNC), 3-39 blue (VBLANK), 40-161 green (kernel), 162-191
; red (overscan).  The bar on row Y is Y >> 3 chunks long, so the staircase
; records the kernel's row loop.  The true blanked phases keep their line
; counts (3, 37, 30); the 192-line kernel is compressed into 122 rows.
MapKernel:
    LDA #C_WHITE
    STA COLUPF               ; the row bar is white on all four zones
    LDY #0
MapRow:                      ; checkpoint: Y = the map row 0..191
    CPY #3
    BCS MapNotVsync
    LDA #C_VSYNC
    JMP MapBg
MapNotVsync:
    CPY #40
    BCS MapNotVblank
    LDA #C_VBLANK
    JMP MapBg
MapNotVblank:
    CPY #162
    BCS MapOverscan
    LDA #C_KERNEL
    JMP MapBg
MapOverscan:
    LDA #C_OVERSCAN
MapBg:
    STA COLUBK
    TYA
    LSR
    LSR
    LSR
    TAX
    LDA BarPF0,X
    STA PF0
    LDA BarPF1,X
    STA PF1
    LDA BarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #192
    BNE MapRow
    JMP OverscanStart

; =============================================================================
; StartGame — a fresh game: score 0, three lives, a full wall, a served ball
; =============================================================================
StartGame:
    LDA #$00
    STA Score
    STA State
    STA Overlay              ; a restart returns to the game view
    LDA #3
    STA Lives
    LDA #$3F                 ; all six brick columns in every row
    STA Brick0
    STA Brick1
    STA Brick2
    STA Brick3
    LDA #76
    STA PaddleX
    LDA #76
    STA BallX
    LDA #168
    STA BallY
    LDA #1
    STA BallDX
    LDA #$FE                 ; up two pixels per frame
    STA BallDY
    RTS

; =============================================================================
; RespawnBall — serve the ball from the paddle after a life is lost
; =============================================================================
RespawnBall:
    LDA PaddleX
    CLC
    ADC #3
; The clamp is defensive: PaddleX is 0..152 today, so PaddleX+3 <= 155 and the
; CMP never triggers.  It keeps the serve safe if the paddle range ever grows.
    CMP #158
    BCC RespawnBallX
    LDA #157
RespawnBallX:
    STA BallX
    LDA #168
    STA BallY
    LDA #1
    STA BallDX
    LDA #$FE
    STA BallDY
    RTS

; =============================================================================
; THE THREE COARSE POSITIONERS — one line each, one HMOVE for all
; =============================================================================
; Input: A = the target X plus a bias.  The routines leave HMP0/HMP1/HMBL set;
; the caller's single STA HMOVE applies all three fine values in one HBLANK.
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
; THE DATA TABLES
; =============================================================================
; BitMask: the bit for each of the six brick columns, indexed by the column.
BitMask:
    !byte $01, $02, $04, $08, $10, $20

; ColTable: map the left half's pixel X (0..79) to a brick column, or $FF for
; a gap or margin.  A brick is pixels 4+12n .. 11+12n (chunks 1+3n .. 2+3n),
; so the table is the wall's geometry written out; the right half is mirrored
; onto it.
ColTable:
    !byte $FF, $FF, $FF, $FF, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $FF, $FF, $FF, $FF, $01, $01, $01, $01
    !byte $01, $01, $01, $01, $FF, $FF, $FF, $FF, $02, $02
    !byte $02, $02, $02, $02, $02, $02, $FF, $FF, $FF, $FF
    !byte $03, $03, $03, $03, $03, $03, $03, $03, $FF, $FF
    !byte $FF, $FF, $04, $04, $04, $04, $04, $04, $04, $04
    !byte $FF, $FF, $FF, $FF, $05, $05, $05, $05, $05, $05
    !byte $05, $05, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF

; BrickPF0/1/2: the three playfield bytes for every 6-bit brick-row mask.
; The bit-to-chunk mapping is the table in the header; the tables are the
; kernel's translation from "which bricks are left" to "what the TIA draws".
BrickPF0Table:
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
    !byte $00, $60, $00, $60, $00, $60, $00, $60
BrickPF1Table:
    !byte $00, $00, $C0, $C0, $18, $18, $D8, $D8
    !byte $03, $03, $C3, $C3, $1B, $1B, $DB, $DB
    !byte $00, $00, $C0, $C0, $18, $18, $D8, $D8
    !byte $03, $03, $C3, $C3, $1B, $1B, $DB, $DB
    !byte $00, $00, $C0, $C0, $18, $18, $D8, $D8
    !byte $03, $03, $C3, $C3, $1B, $1B, $DB, $DB
    !byte $00, $00, $C0, $C0, $18, $18, $D8, $D8
    !byte $03, $03, $C3, $C3, $1B, $1B, $DB, $DB
BrickPF2Table:
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $06, $06, $06, $06, $06, $06, $06, $06
    !byte $06, $06, $06, $06, $06, $06, $06, $06
    !byte $30, $30, $30, $30, $30, $30, $30, $30
    !byte $30, $30, $30, $30, $30, $30, $30, $30
    !byte $36, $36, $36, $36, $36, $36, $36, $36
    !byte $36, $36, $36, $36, $36, $36, $36, $36

; BarPF0/1/2: the overlay row bar.  Entry n lights one playfield chunk at
; position n (clamped to chunk 19); the kernel indexes it with Y >> 3, so the
; bar on row Y is a four-pixel dash that steps right once every eight rows.
; The diagonal is the row loop; the zone colours stay visible around it.
BarPF0:
    !byte $10, $20, $40, $80, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
BarPF1:
    !byte $00, $00, $00, $00, $80, $40, $20, $10
    !byte $08, $04, $02, $01, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
BarPF2:
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $01, $02, $04, $08
    !byte $10, $20, $40, $80, $80, $80, $80, $80

; =============================================================================
; THE SCORE TABLE — 25 entries of 16 rows, one per score value
; =============================================================================
; Rows 0-6 are the tens glyph, rows 7-8 are blank, rows 9-15 are the ones
; glyph.  Each glyph is a 5x7 font shifted one bit left inside the 8-pixel
; player.  ScorePtr selects an entry; the kernel reads one row per scanline.
ScoreGlyphs:
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $1C, $22, $26, $2A, $32, $22, $1C   ;  0 = 00
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $08, $18, $08, $08, $08, $08, $1C   ;  1 = 01
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $1C, $22, $02, $04, $08, $10, $3E   ;  2 = 02
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $3E, $04, $08, $04, $02, $22, $1C   ;  3 = 03
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $04, $0C, $14, $24, $3E, $04, $04   ;  4 = 04
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $3E, $20, $3C, $02, $02, $22, $1C   ;  5 = 05
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $0C, $10, $20, $3C, $22, $22, $1C   ;  6 = 06
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $3E, $02, $04, $08, $10, $10, $10   ;  7 = 07
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $1C, $22, $22, $1C, $22, $22, $1C   ;  8 = 08
    !byte $1C, $22, $26, $2A, $32, $22, $1C, $00, $00, $1C, $22, $22, $1E, $02, $04, $18   ;  9 = 09
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $1C, $22, $26, $2A, $32, $22, $1C   ; 10 = 10
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $08, $18, $08, $08, $08, $08, $1C   ; 11 = 11
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $1C, $22, $02, $04, $08, $10, $3E   ; 12 = 12
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $3E, $04, $08, $04, $02, $22, $1C   ; 13 = 13
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $04, $0C, $14, $24, $3E, $04, $04   ; 14 = 14
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $3E, $20, $3C, $02, $02, $22, $1C   ; 15 = 15
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $0C, $10, $20, $3C, $22, $22, $1C   ; 16 = 16
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $3E, $02, $04, $08, $10, $10, $10   ; 17 = 17
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $1C, $22, $22, $1C, $22, $22, $1C   ; 18 = 18
    !byte $08, $18, $08, $08, $08, $08, $1C, $00, $00, $1C, $22, $22, $1E, $02, $04, $18   ; 19 = 19
    !byte $1C, $22, $02, $04, $08, $10, $3E, $00, $00, $1C, $22, $26, $2A, $32, $22, $1C   ; 20 = 20
    !byte $1C, $22, $02, $04, $08, $10, $3E, $00, $00, $08, $18, $08, $08, $08, $08, $1C   ; 21 = 21
    !byte $1C, $22, $02, $04, $08, $10, $3E, $00, $00, $1C, $22, $02, $04, $08, $10, $3E   ; 22 = 22
    !byte $1C, $22, $02, $04, $08, $10, $3E, $00, $00, $3E, $04, $08, $04, $02, $22, $1C   ; 23 = 23
    !byte $1C, $22, $02, $04, $08, $10, $3E, $00, $00, $04, $0C, $14, $24, $3E, $04, $04   ; 24 = 24

; ScorePtrLo/Hi: the address of each 16-row entry.  Two 25-byte tables keep
; the 400-byte glyph block free to live anywhere in the cartridge.
ScorePtrLo:
    !byte <(ScoreGlyphs+0), <(ScoreGlyphs+16), <(ScoreGlyphs+32), <(ScoreGlyphs+48), <(ScoreGlyphs+64)
    !byte <(ScoreGlyphs+80), <(ScoreGlyphs+96), <(ScoreGlyphs+112), <(ScoreGlyphs+128), <(ScoreGlyphs+144)
    !byte <(ScoreGlyphs+160), <(ScoreGlyphs+176), <(ScoreGlyphs+192), <(ScoreGlyphs+208), <(ScoreGlyphs+224)
    !byte <(ScoreGlyphs+240), <(ScoreGlyphs+256), <(ScoreGlyphs+272), <(ScoreGlyphs+288), <(ScoreGlyphs+304)
    !byte <(ScoreGlyphs+320), <(ScoreGlyphs+336), <(ScoreGlyphs+352), <(ScoreGlyphs+368), <(ScoreGlyphs+384)
ScorePtrHi:
    !byte >(ScoreGlyphs+0), >(ScoreGlyphs+16), >(ScoreGlyphs+32), >(ScoreGlyphs+48), >(ScoreGlyphs+64)
    !byte >(ScoreGlyphs+80), >(ScoreGlyphs+96), >(ScoreGlyphs+112), >(ScoreGlyphs+128), >(ScoreGlyphs+144)
    !byte >(ScoreGlyphs+160), >(ScoreGlyphs+176), >(ScoreGlyphs+192), >(ScoreGlyphs+208), >(ScoreGlyphs+224)
    !byte >(ScoreGlyphs+240), >(ScoreGlyphs+256), >(ScoreGlyphs+272), >(ScoreGlyphs+288), >(ScoreGlyphs+304)
    !byte >(ScoreGlyphs+320), >(ScoreGlyphs+336), >(ScoreGlyphs+352), >(ScoreGlyphs+368), >(ScoreGlyphs+384)

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
> `lessons/part8-advanced/62-reverse-engineering/demo-62.asm`.

### Code Walkthrough

#### Step 1 — Reset, clean start, and the initial game

`Reset` at `$F000` runs `+clean_start`, sets `SWACNT` to zero, and calls `StartGame`. `StartGame` writes `Score=0`, `State=0`, `Lives=3`, all four brick masks `$3F`, the paddle and ball at X=76, the ball at Y=168, `BallDX=1`, and `BallDY=$FE`. The routine is shared by power-on and the game-over restart, so the two paths cannot drift.

#### Step 2 — VBLANK: SELECT and fire

The VBLANK code reads `SWCHB` bit 1, debounces it with `PrevSelect`, and toggles `Overlay` once per press. `OverlayWrite` is the checkpoint. It then reads `INPT4` bit 7, flips it to 1 = pressed, edge-detects it with `PrevFire`, and calls `StartGame` only when `State=1`. The edge logic is the reason a held fire at power-on does not restart a running game.

#### Step 3 — The paddle and the ball

`GameLogic` starts at `$F06D`. The paddle reads `SWCHA` bits 6-7. With neither pressed it uses the auto-demo: `PaddleX = BallX - 3`, clamped to 0..152. Manual left/right moves four pixels and clamps. The ball adds `BallDX` to `BallX` and `BallDY` to `BallY`; `BallMove` at `$F0B6` reports the new `BallX` in A. The wall and ceiling tests flip or clamp, and the bottom test decrements `Lives` or sets `State=1`.

#### Step 4 — The collision chain

The paddle test runs only while the ball moves down. It checks the ball's bottom edge against rows 176..183, then the ball's x against `PaddleX..PaddleX+7`. On a hit it snaps `BallY` to 172, sets `BallDY=$FE`, and picks `BallDX` by which half of the paddle was hit.

The brick test runs after the paddle test. It chooses the leading edge from `BallDY` (bottom when moving down, top when moving up), rejects rows outside 32..63, computes `row = (Y-32) >> 3`, mirrors the right half's x with `159 - centre`, looks the column up in `ColTable`, rejects `$FF`, and computes `index = row*6 + col`. `HitBrick` reports the index. The bit test clears the brick, increments `Score`, reports `ScoreWrite`, and flips `BallDY` with `EOR #$FC`. When all four masks are zero the wall is gone and `State=1` — a win and a loss share the red game-over screen.

#### Step 5 — DisplaySetup: tables, colours, and one HMOVE

`DisplaySetup` at `$F1B2` loads `ScorePtr` from the two 25-byte pointer tables, rebuilds the twelve `BrickPF` bytes from the four masks, sets the colours (`COLUP1` white, `COLUP0` green, `COLUPF` gold, `COLUBK` dark grey (`$02`) or red in the over state), sets `CTRLPF=$11` (reflect + 2-pixel ball), clears the sprites and playfield, and positions P0, P1, and the ball with three coarse routines. The three calls each take a line; the final `STA WSYNC` and `STA HMOVE` apply all three fine offsets in one HBLANK. `+wait_timer` then releases the picture at scanline 37.

#### Step 6 — The play kernel's zones

`PlayKernel` starts with Y=0. The score rows read `(ScorePtr),Y` and write `GRP1`; the separator clears it; the lives rows light a two-rows-per-life bar; the blank band waits nine lines; the brick zone holds each row's three PF bytes for seven lines and one gap; the play area holds the playfield off for 112 lines; the paddle sets `GRP0=$FF` for eight lines; the bottom clears it for eight. Every line calls `DrawBallLine`, which owns the row checkpoint, the pipelined ball enable, the `WSYNC`, and the `INY`.

#### Step 7 — DrawBallLine and DrawLastLine

`DrawBallLine` computes `Y+1 - BallY`; if the result is 0..3 it sets `ENABL=2`, otherwise 0. The write happens during row Y, for row Y+1. It then does `STA WSYNC`, `INY`, and `RTS`. `KernelRow` reports Y=0..190. The final row uses `DrawLastLine`, a bare `STA WSYNC` + `RTS`; its `ENABL` was set by row 190, and its return address is `OverscanStart`, which is why the overscan starts at 229/6. `KernelRowLast` reports Y=191.

#### Step 8 — The game-over screen

`OverKernel` keeps the score and life bar, clears the playfield, draws the red field, and puts a full-width white bar at rows 176-183. The ball and paddle are hidden because `GRP0` and `ENABL` were cleared in DisplaySetup and the over kernel never sets them. Fire calls `StartGame`.

#### Step 9 — The frame map

`MapKernel` selects one of four background colours by row (0-2 white, 3-39 blue, 40-161 green, 162-191 red) and writes the `BarPF` entry for `Y >> 3`. The bar is a single white chunk; the reflection doubles it. The map is the SELECT overlay; it is a projection of the four phases into the 192 visible lines, because the real blanked phases are not visible on a TV.

#### Step 10 — The tables and the vectors

`ScoreGlyphs` is 400 bytes of 25 sixteen-row columns; `ScorePtrLo/Hi` point at them. `BrickPF0/1/2Table` are 64-entry mask translations; `ColTable` is 80 bytes; `BitMask` is 6 bytes; `BarPF` is 24 entries. The vectors at `$FFFA` are three `!word Reset` values. The `!fill $FFFA - *, $EA` pads the image to exactly 4,096 bytes, which is why the ROM size is a design constant, not an accident.

## What You Should See

The play screen is a dark grey field with a gold brick wall across the upper third, a small gold ball, a green paddle near the bottom, a white two-digit score stacked at the top centre, and a white life bar under it. The wall shows twelve columns because the playfield reflects the six-column table; each brick is eight pixels wide with a four-pixel gap, and the four rows are separated by one blank line. The score reads vertically: the tens digit above the ones digit. The ball is two pixels wide and four lines tall. The paddle is eight pixels wide.

As the game runs, the ball bounces off the walls, the paddle, and the bricks. A hit removes the brick (both mirror images), increments the score, and reverses the ball's vertical direction. A ball that reaches the bottom removes one two-row block from the life bar; after three misses the field turns red, the paddle and ball disappear, and a white bar at the bottom waits for fire. Fire restarts with score 0, three lives, and the full wall. Clearing all 24 bricks is a win and shares the same red screen; the auto-demo reaches it at frame 4004 with score 24, which is the `game-over.png` capture. The over path's `OverscanStart` is 229/7, one cycle later than the play path's 229/6, and the frame stays 262 lines.

![Stella running the Lesson 62 ROM: the Wall Buster play screen with a gold brick wall, a small gold ball, a green paddle, a stacked white score, and a white life bar; the title bar reads Stella 7.0: "demo-62"](/images/lesson62/game.png)

*`game.png`: the play screen after the auto-demo has broken five bricks. The score is 05, the life bar is full, and the ball is in flight at the left.*

![Stella running the Lesson 62 ROM with SELECT held: a white VSYNC band, a blue VBLANK band, a green kernel band, a red overscan band, and the white row bar as a diagonal of dashes that meets at the centre and continues through the red band; the title bar reads Stella 7.0: "demo-62"](/images/lesson62/overlay.png)

*`overlay.png`: the SELECT frame map. The four bands are the four frame phases, with the kernel compressed into the 122 visible lines that remain; the white diagonal is the row bar, one chunk per eight rows.*

![Stella running the Lesson 62 ROM at the win screen: a red field, the final score 24 stacked at the top centre, and a white restart bar at the bottom; the title bar reads Stella 7.0: "demo-62"](/images/lesson62/game-over.png)

*`game-over.png`: the win screen. The auto-demo cleared all 24 bricks at frame 4004; the red field is shared by a win and a loss, the score stays at 24, and the white bar waits for fire. The over path returns at 229/7, so the frame is still 262 lines.*

<RomPlayer rom="/roms/part8-advanced/62-reverse-engineering/demo-62.bin" title="Lesson 62 — Reverse Engineering a Classic Game" />

Press SELECT to toggle the frame map. The game keeps running underneath it: the ball moves, the score changes, and the checkpoints still fire. Javatari's 4K path runs the ROM in the page; the ROM is silent, so there is nothing to unmute.

The debugger tells the same story as numbers. Break at the labels the source defines:

| Checkpoint | Address | Measured | Meaning |
|---|---|---|---|
| `StartFrame` | `$F019` | 259/3 | the first VSYNC line (the first hit at frame 0 is the power-on partial frame) |
| `VblankStart` | `$F027` | 0/5 | the first VBLANK line |
| `BodyStart` | `$F22F` | 37/5 | visible line 0 |
| `OverscanStart` | `$F2D9` | 229/6 play; 229/7 game over; 229/9 frame map | the first overscan instruction |
| `KernelRow` | `$F2EC` | Y = 0..190 | the visible row, one hit per line |
| `KernelRowLast` | `$F306` | Y = 191 | the final visible row |
| `BallMove` | `$F0B6` | A = `$4D`, `$4E`, `$4F`, … | the ball's new `BallX` |
| `HitBrick` | `$F186` | A = `$14`, `$11`, `$17`, … | the brick index 0..23 |
| `ScoreWrite` | `$F19E` | A = 01, 02, …, 24 (the win is frame 4004) | the new score |
| `OverlayWrite` | `$F04C` | A = 01 under `-holdselect` | the new `Overlay` byte |
| `MapRow` | `$F376` | Y = 0..191 under `-holdselect` | the overlay map's row |

The state log commands used for the evidence:

```bash
ROM=docs/public/roms/part8-advanced/62-reverse-engineering/demo-62.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F019' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F027' $ROM   # VblankStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F22F' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F2D9' $ROM   # OverscanStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F2EC' $ROM   # KernelRow
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F306' $ROM   # KernelRowLast
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0B6' $ROM   # BallMove
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F186' $ROM   # HitBrick
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F19E' $ROM   # ScoreWrite
stella -audio.enabled 0 -holdselect -dbg.logbreaks 1 -logtoconsole 1 -break '$F04C' $ROM   # OverlayWrite
stella -audio.enabled 0 -holdselect -dbg.logbreaks 1 -logtoconsole 1 -break '$F376' $ROM   # MapRow
```

The frame checkpoints, first hits:

```text
# StartFrame
BP:           0  34 17 -17 | NV-BdIzC fe ff 00 ff |    (power-on)
BP:           1 259 03 -59 | nv-BdIZC 00 00 bf ff |
BP:           2 259 03 -59 | nv-BdIZC 00 00 bf ff |
BP:           3 259 03 -59 | nv-BdIZC 00 00 bf ff |

# VblankStart
BP:           1   0 05 -53 | nv-BdIZc 00 ff 00 ff |
BP:           2   0 05 -53 | nv-BdIZC 00 00 bf ff |
BP:           3   0 05 -53 | nv-BdIZC 00 00 bf ff |

# BodyStart
BP:           1  37 05 -53 | nv-BdIZC 00 04 3f ff |
BP:           2  37 05 -53 | nv-BdIZC 00 04 3f ff |
BP:           3  37 05 -53 | nv-BdIZC 00 04 3f ff |

# OverscanStart
BP:           1 229 06 -50 | nv-BdIZC 00 00 bf ff |
BP:           2 229 06 -50 | nv-BdIZC 00 00 bf ff |
BP:           3 229 06 -50 | nv-BdIZC 00 00 bf ff |
```

The game checkpoints, first hits:

```text
# KernelRow (Y is the last register column)
BP:           1  37 33  31 | nv-BdIzC 1c 04 00 fd |
BP:           1  38 27  13 | nv-BdIzc 22 04 01 fd |
BP:           1  39 27  13 | nv-BdIzc 26 04 02 fd |
BP:           1  40 27  13 | nv-BdIzc 2a 04 03 fd |

# KernelRowLast
BP:           1 228 22  -2 | nv-BdIZC 00 00 bf fd |

# BallMove (A = the new BallX)
BP:           1   1 27  13 | nv-BdIzc 4d ff 00 ff |
BP:           2   1 27  13 | nv-BdIzc 4e 00 bf ff |
BP:           3   1 27  13 | nv-BdIzc 4f 00 bf ff |

# HitBrick (A = the brick index)
BP:          53   3 07 -47 | nv-BdIzc 14 1d bf ff |
BP:         170   2 74 154 | nv-BdIzc 11 47 bf ff |
BP:         171   3 15 -23 | nv-BdIzc 11 46 bf ff |

# ScoreWrite (A = the new score)
BP:          53   3 47  73 | nv-BdIzc 01 03 02 ff |
BP:         170   3 38  46 | nv-BdIzc 02 02 05 ff |
BP:         172   3 55  97 | nv-BdIzc 03 03 05 ff |

# OverlayWrite (with -holdselect)
BP:           1   0 43  61 | nv-BdIzc 01 ff 00 ff |

# MapRow (with -holdselect)
BP:           1  37 20  -8 | nv-BdIZC 0e 04 00 ff |
BP:           1  38 07 -47 | nv-BdIzc 00 00 01 ff |
BP:           1  39 07 -47 | nv-BdIzc 00 00 02 ff |
```

`KernelRow` covers rows 0..190 and `KernelRowLast` covers row 191. The split is deliberate: the last row does no next-row work, so its `STA WSYNC` + `RTS` lands `OverscanStart` at 229/6. A single `KernelRow` label would have to do the next-row work and would land two cycles late. The two labels together cover Y = 0..191.

> **Capture method.** The three images are window captures of
> `docs/public/roms/part8-advanced/62-reverse-engineering/demo-62.bin` in Stella 7.0.
> `game.png` was captured with `scripts/capture-screenshot.sh` after the auto-demo
> had broken five bricks. `overlay.png` used the same window-capture pipeline with
> `-holdselect`, so SELECT is held at power-on and the frame map is the first screen.
> `game-over.png` waited 120 s for the auto-demo to clear the wall; the win is
> `ScoreWrite` A=`$18` (24) at frame 4004, and the over path was measured at
> `OverscanStart` 229/7. The pointer was parked at `(0, 0)` before each capture (no
> cursor appears in any image), and the title bar reads `Stella 7.0: "demo-62"` in all
> three. The window is
> 1010×807; the TIA area is 960×606 at `(25, 106)`. The pixel check samples the TIA
> area: the game image has the gold wall at logical rows 32-63, the green paddle at
> rows 176-183, the white score and life bar at the top centre, and the gold ball in
> the play area; the overlay image has white/blue/green/red bands at rows 0-2, 3-39,
> 40-161, and 162-191, and the white row bar along the diagonal; the game-over
> image is a red field with the score 24 at the top centre, the white restart bar
> at rows 176-183, and no P1 column.

The pixel check is a host-side sample of the committed images, not a second emulator. The game image's wall and paddle colours are `(205, 205, 52)` and `(81, 179, 80)`; the overlay's four bands are `(234, 234, 233)`, `(36, 40, 176)`, `(19, 91, 18)`, and `(158, 19, 18)`. The sampled band boundaries are within one TIA line of the map's predictions: row 3 at y≈115, row 40 at y≈232, row 162 at y≈617.

## Exercises

The exercises are analysis, not code changes. Each one asks you to find something in the ROM and prove it with the debugger. Answers follow each exercise; there are no `exercise-NN-solution.asm` files because the artifact is the one game and the lesson is the reading of it.

### Exercise 1: Find the reset vector, the frame entry, and the kernel row loop

**Challenge:** Starting from a cold ROM image, find the address the CPU executes first, the label that begins the frame, and the inner loop that draws the 192 visible lines. Prove each with a breakpoint.

**Hints:**
1. The 6507 reads three vectors at `$FFFA-$FFFF`; the middle one is RESET.
2. The frame starts at the first `VSYNC` write and has four named anchors: VSYNC, VBLANK, the first visible line, and the first overscan line.
3. The kernel's row loop is the code that writes `STA WSYNC` once per line and increments the row counter.

**Expected Result:** A breakpoint at `$F000` hits first; `$F019` hits at scanline 259; `$F027` at 0; `$F22F` at 37; `$F2D9` at 229; `$F2EC` reports Y=0..190; `$F306` reports Y=191.

**Answer:** The vectors are at `$FFFA`: NMI `$F000`, RESET `$F000`, IRQ `$F000`. The reset vector's bytes `00 F0` at `$FFFC` send the CPU to `Reset` `$F000`. `Reset` runs `+clean_start`, sets `SWACNT`, calls `StartGame` `$F3B3`, and jumps to `StartFrame` `$F019`. The frame entry is `StartFrame`; its four anchors are `StartFrame` `$F019` (259/3), `VblankStart` `$F027` (0/5), `BodyStart` `$F22F` (37/5), and `OverscanStart` `$F2D9` (229/6). The kernel row loop is `PlayKernel` `$F23D`: each line calls `DrawBallLine` `$F2EC`, whose `KernelRow` label is the row checkpoint; `DrawBallLine` writes `STA WSYNC`, increments Y, and returns. Rows 0..190 come from `KernelRow`; row 191 comes from `DrawLastLine`/`KernelRowLast` `$F306`, the bare `STA WSYNC` + `RTS` that lands the overscan at 229/6. The state log in the previous section is the proof.

### Exercise 2: Locate the ball X/Y variables and the collision test; change the ball speed

**Challenge:** Find the four ball variables and the code that moves and collides the ball. Then change the ball's horizontal and vertical speed in `StartGame`, rebuild, and explain what changes and what does not.

**Hints:**
1. The variables are four consecutive bytes in the `$80-$9F` block: X, Y, DX, DY.
2. `BallMove` is the checkpoint immediately after `STA BallX`; A holds the new X.
3. The speed is two immediate loads in `StartGame`: `LDA #$01 / STA BallDX` and `LDA #$FE / STA BallDY`.

**Expected Result:** The four bytes are `BallX=$81`, `BallY=$82`, `BallDX=$83`, `BallDY=$84`. The move is `$F0AF-$F0BB`; the wall/ceiling tests start at `$F0BD` (the wall clamp is `$F0CA-$F0E0`); the bottom/life test starts at `$F0EF`; the paddle test starts at `$F103`; the brick test starts at `NoPaddle` `$F142` and reaches `NoBrickHit` `$F1B2`. Changing the two `StartGame` loads alone does **not** simply double the speed: `BallDX=2` is flipped to `$FC` (-4) by `EOR #$FE` at the first wall or brick bounce, then back to `$02`; `BallDY=3` is flipped to `$FF` (-1) by `EOR #$FC`, while the ceiling forces `+2`, the paddle forces `-2`, and `RespawnBall` resets to `-2`. The ball therefore alternates 2/4 pixels horizontally and +3/-1 vertically after the first bounce. The frame timing is unchanged: the move is in VBLANK, and the kernel only reads the new state.

**Answer:** `BallX` `$81`, `BallY` `$82`, `BallDX` `$83`, `BallDY` `$84`. `StartGame` sets `BallX=76`, `BallY=168`, `BallDX=1`, `BallDY=$FE` at `$F3C9-$F3DB`; the two speed loads are `LDA #$01` at `$F3D5` and `LDA #$FE` at `$F3D9`. The move is:
```
F0AF  A5 81     LDA $81       ; BallX
F0B1  18        CLC
F0B2  65 83     ADC $83       ; BallDX
F0B4  85 81     STA $81
F0B6  A5 82     LDA $82       ; BallMove: A = the new BallX
F0B8  18        CLC
F0B9  65 84     ADC $84       ; BallDY
F0BB  85 82     STA $82
```
The collision test's brick branch starts at `NoPaddle` `$F142` (the leading-edge choice), computes the row from that edge, mirrors the right half with `159 - centre`, reads `ColTable`, and reaches `HitBrick` `$F186`. The move is only half the story: the speed is hard-coded in five places. The two `StartGame` loads are the serve values; the wall/brick flip `EOR #$FE` produces `1 <-> $FF` for the default `1`, but `2` becomes `$FC` (-4); the ceiling writes `+2`; the paddle writes `-2`; `RespawnBall` writes `+1`/`-2`. If you change only the two serve values, the ball alternates 2/4 horizontally and +3/-1 vertically after the first bounce, so it is not a clean 2x/3x speed. To change the speed consistently, patch all five sites, or replace the horizontal flip with a true negate (`LDA #0 / SEC / SBC BallDX / STA BallDX`) and the vertical flip likewise; the wall and brick bounces then preserve any DX/DY, but the ceiling, paddle, and `RespawnBall` still force ±2, so extend those writes too. The clamp's side test is unsigned: a wrapped negative X at the left wall is treated as the right wall, so a fast DX can teleport once per left approach even though the stock ±1 game never wraps. Fix the side test or use a true negate before shipping a fast ball.

The default game also needs the wall clamp at `$F0CA`: a two-pixel step can leave `BallX=159`, whose collision centre is 160 and whose mirrored column is `$FF`, reading past the 80-byte `ColTable`. The clamp stores 158 (the last legal left edge) before flipping, so the table index stays in 0..79. A faster ball can still cross a one-line brick gap between two checks, and the two-pixel horizontal step makes the paddle's edge easier to slip past. The frame stays 262 lines because the arithmetic is in VBLANK.

### Exercise 3: Annotate the score routine and the brick table

**Challenge:** Produce an annotated map of the score path from the score byte to the two visible digits, and of the brick path from a 6-bit row mask to the three playfield bytes. Quote the addresses.

**Hints:**
1. The score is one byte at `$85`; the score's `INC` and the `ScoreWrite` checkpoint are adjacent.
2. The score table is 25 entries × 16 rows; the pointer tables are two 25-byte arrays.
3. The brick table has four masks, three 64-byte translation tables, and a 12-byte per-frame cache.

**Expected Result:** A table with `Score` `$85`, `INC Score` `$F19A`, `ScoreWrite` `$F19E`, `ScorePtr` `$89-$8A`, `ScorePtrLo` `$F71C`, `ScorePtrHi` `$F735`, `ScoreGlyphs` `$F58C`, the kernel's `LDA (ScorePtr),Y` `$F23F`, and `STA GRP1` `$F241`. The brick side: `Brick0..3` `$8B-$8E`, `BrickPF0/1/2` `$8F-$9A`, `RebuildBricks` `$F1C0` (the 22-byte loop), `BrickPF0/1/2Table` `$F484/$F4C4/$F504`, `BrickSetup` `$F27E`, `BrickLine` `$F28A`, `HitBrick` `$F186`, `BitMask` `$F42E`, `ColTable` `$F434`.

**Answer:** The score path is: a hit does `INC $85` at `$F19A`; `LDA $85` at `$F19C` loads the new score into A, and the `ScoreWrite` label at `$F19E` is the next instruction, so a breakpoint there reports A = score; VBLANK's DisplaySetup reads `Score` into X at `$F1B2`, loads `ScorePtrLo,X` into `$89` and `ScorePtrHi,X` into `$8A`, and the play kernel reads `LDA ($89),Y` at `$F23F`, writes `STA GRP1` at `$F241`, and calls `DrawBallLine`. The table `ScoreGlyphs` at `$F58C` is 25 × 16 bytes: entry n's rows 0-6 are the tens glyph, rows 7-8 are blank, rows 9-15 are the ones glyph. The two pointer tables at `$F71C` and `$F735` hold the 25 entry addresses. The visible score is the vertical stack at X=76: tens above ones.

The brick path is: `Brick0..3` at `$8B-$8E` hold the four 6-bit masks (bit 0 = column 0). VBLANK's `RebuildBricks` loop at `$F1C0` reads each mask with `LDY $8B,X`, looks up `BrickPF0Table,Y` (`$F484`), `BrickPF1Table,Y` (`$F4C4`), `BrickPF2Table,Y` (`$F504`), and stores the three bytes in `BrickPF0,X` (`$8F-$92`), `BrickPF1,X` (`$93-$96`), and `BrickPF2,X` (`$97-$9A`). The kernel's `BrickSetup` at `$F27E` copies the row's three cached bytes to `PF0/PF1/PF2`; `BrickLine` at `$F28A` holds them for seven lines; `BrickGap` at `$F291` clears them for the one-line gap. A hit arrives at `HitBrick` `$F186` with `A = row*6 + col`; `BitMask[col]` at `$F42E` is `$01, $02, $04, $08, $10, $20`; `AND Brick0[row]` tests it; `EOR` clears it; `INC Score` scores it. `ColTable` at `$F434` is the 80-byte left-half column map that turns the ball's centre into a column or `$FF` for a gap.

## Key Takeaways

- ✅ **Read the vectors first.** The 6507 starts at the RESET vector at `$FFFC`; Wall Buster's is `$F000`, and the NMI/IRQ vectors point there too because the console has no interrupts.
- ✅ **The frame anchors are the map.** `StartFrame` 259/3, `VblankStart` 0/5, and `BodyStart` 37/5 are fixed; `OverscanStart` is 229/6 on the play path, 229/7 on the game-over screen, and 229/9 on the frame map. The scanline is the invariant; the cycle depends on the path.
- ✅ **Find the row loop.** The kernel is a `WSYNC` loop with a row counter; `KernelRow` reports Y=0..190 and `KernelRowLast` reports the final row, and the split is what puts the overscan at 229/6.
- ✅ **The VBLANK does the thinking.** The game logic, the score pointer, the brick bytes, the colours, and the one `HMOVE` all run while the picture is blanked; the visible kernel only draws.
- ✅ **Data tables are the game's vocabulary.** `ScoreGlyphs` turns a score byte into sixteen rows; `BrickPF*` turns a six-bit mask into three playfield bytes; `ColTable` turns a pixel X into a brick column. Read the table and the code's purpose follows.
- ✅ **The collision is one index and one bit.** The leading edge picks the row, the centre picks the column, the mirror maps the right half, and `BitMask` tests the brick. `HitBrick` and `ScoreWrite` are the two checkpoints that carry the result.
- ✅ **The overlay is a projection, not a photograph.** A TV cannot show the blanked VBLANK/overscan lines, so the SELECT map keeps their true line counts and compresses the kernel into the visible window; the diagonal is the row loop, and the state log is the proof of the real 262-line frame.

## What's Next

You have read one complete 4K game from its vectors to its score table. [Lesson 63: Modern Homebrew — Dev Carts and Community](/part8-advanced/63-modern-homebrew) moves from reading a ROM to shipping one: the Harmony and UnoCart flash carts, the AtariAge community, contests, publishing, and the modern toolchain, with an attract-mode demo that shows the production values a modern homebrew release expects. The same seven-pass method will read that demo too.
