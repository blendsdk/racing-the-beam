# Lesson Specifications: Part 10 — Capstone Projects (Lessons 69–72)

> **Document**: 03-lesson-specs.md
> **Parent**: [Index](00-index.md)
> **Status**: Frozen for execution
> **Source of truth**: this file + [07-testing-strategy.md](07-testing-strategy.md) + the shipped
> `include/vcs.asm`, `include/macro.asm`, `include/score.asm`, and `include/sound.asm`. A claim
> that disagrees with `include/vcs.asm` is wrong.

## Shared Conventions

- **Source shape:** `!cpu 6502`; `!source "include/vcs.asm"`; `!source "include/macro.asm"`;
  the reset entry; `+clean_start`; the 262-line frame skeleton; the visible kernel; the overscan.
  The main source's header comment carries the RAM map, the build command, the run command, the
  checkpoints, and the measured cycle/line ledgers.
- **ROM names and paths:** `lessons/part10-capstones/NN-slug/NN-slug.asm`,
  `exercise-NN-solution.asm` (buildable) or `demo-NN.asm` (theory); committed under
  `docs/public/roms/part10-capstones/NN-slug/`.
- **ROM size:** **4,096 bytes for every Part 10 source.** No mapper, no bankswitching.
- **Frame:** NTSC 262 = 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan. `StartFrame` 259/3,
  `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229 (the cycle is kernel-dependent). The
  visible kernel is 192 lines.
- **Row loops:** top-down `LDX #0; ...; INX; CPX #N; BNE`.
- **Positioning:** the Lesson 26 divide-by-15 routine; the one-HMOVE rule (set every `HMPx`/`RESxx`
  first, then one `HMOVE`); re-strobe the coarse positions every frame because `HMOVE` re-applies
  the fine offsets.
- **Score library re-use (Lessons 70–72):** call `ScoreSetup` every frame in VBLANK before
  `ScoreDraw`; draw the nine score lines at the top; then reposition P0/P1 for the game. The
  preflight measured `ScoreDone` at line 46 and the frame at 229.
- **RAM maps:** every lesson's source header is the exact map; no data under the stack
  (`$F8-$FF` unless the map says otherwise). The maps are pinned below.
- **Checkpoints:** `Label:` immediately before the instruction that follows the labelled event;
  a breakpoint reports the first cycle of that instruction. The source header lists every
  checkpoint and its expected value; the doc quotes the address from the symbol file.
- **Screenshots:** from the committed lesson ROM via `scripts/capture-screenshot.sh`, pointer
  parked, no cursor, title bar visible. Lesson 69: 3; Lesson 70: 3; Lesson 71: 3; Lesson 72: 2.
  Every game has a deterministic auto-demo; the doc discloses the wait/SELECT path.
- **Exercises:** Lessons 69–71 ship three `exercise-NN-solution.asm`, each assembling to 4,096
  and running. Lesson 72 has three design exercises answered in the doc; no solution files.
- **Docs:** the fixed six-section template with frontmatter, meta block, TypeScript equivalent,
  theory, Full Source verbatim between the markers, Code Walkthrough, What You Should See with
  the images and `<RomPlayer>`, Exercises, Key Takeaways (≤7), What's Next. The capture method and
  any deviation are disclosed.
- **Integration:** the Part 10 index row flips to ✅ in the lesson commit; sidebar entry verified;
  prev/next frontmatter; README row 10 unchanged.

---

## Lesson 69: Capstone 1 — Pong

- **Goal:** build a complete two-player Pong — two paddles, a ball, wall and paddle collisions,
  a serve, a one-digit-per-player score, and a win at 9 — and learn why a multi-object kernel
  needs a precomputed row table.
- **Prerequisites:** Lesson 03 (the anatomy), Lesson 04 (registers), Lesson 12 (the frame),
  Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 25 (players), Lesson 26 (positioning),
  Lesson 28 (two players), Lesson 29 (the ball), Lesson 33 (controllers), Lesson 38 (collision),
  Lesson 41 (game states), Lesson 49 (the two-line kernel), Lesson 52 (fine scrolling), Lesson 39
  (the scoreboard and score library), Lesson 68 (the kernel framework).
- **Concepts:** the two-player input map (SWCHA bits 4/5 = P0 up/down, bits 0/1 = P1 up/down); the paddle as a vertical
  8×24 strip; the ball as a 4×8 object with a signed velocity; wall and paddle collision; the
  collision latches read in VBLANK and cleared with `CXCLR`; the angle from the paddle hit
  offset; the serve state; the one-digit-per-player score (P0 left, P1 right); the row-table
  kernel; the auto-demo; why a one-line kernel writes GRP0 too late (the preflight's cycle-49
  failure).
- **Screen (192 visible lines):**
  - Score band, visible 0-7: P0 draws the left digit, P1 the right digit, at TIA X=64 and X=88;
    each digit is an 8×7 glyph (row 7 blank) from a 10×8 font.
  - Blank line 8.
  - Positioner lines 9-13: `SetCoarse0` (P0 to 16), `SetCoarse1` (P1 to 136), `SetCoarseBL`
    (ball to BallX), `WSYNC` + `HMOVE`; the exact count is measured and tuned to 5 lines.
  - Play area 14-191: 178 lines = 89 rows × 2 lines. The row table (bit 0 = P0, bit 1 = P1,
    bit 2 = ball) drives the kernel; the first row's values are decoded before the loop, the
    stores happen at the start of the row's first line, and the next row is decoded during the
    second line.
  - Total: 8 + 1 + 5 + 178 = 192.
- **Frame:** `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229
  (measured; the exact cycle is recorded).
- **RAM map:**
  - `$80-$D8` `RowTable` (89 bytes, one byte per row; bit 0 P0, bit 1 P1, bit 2 ball).
  - `$D9` `LeftScore` 0-9; `$DA` `RightScore` 0-9.
  - `$DB` `P0Y` (8-148), `$DC` `P1Y` (8-148).
  - `$DD` `BallX` (4-152), `$DE` `BallY` (8-164), `$DF` `BallVX` (signed), `$E0` `BallVY` (signed).
  - `$E1` `Frame`, `$E2` `ServeTimer`, `$E3` `GameState` (0=play, 1=over), `$E4` `ScoreFlash`.
  - `$E5` `Temp`, `$E6` `CurP0`, `$E7` `CurP1`, `$E8` `CurBall`.
  - `$E9` `P0Row`, `$EA` `P1Row`, `$EB` `BallRow`, `$EC` `P0RowEnd`, `$ED` `P1RowEnd`,
    `$EE` `BallRowEnd`, `$EF` `PrevFire`, `$F0` `AutoTimer`.
  - `$F1-$FF` stack.
- **Game logic:**
  - Read SWCHA: P0 up bit 4, down bit 5; P1 up bit 0, down bit 1 (active low). Move 2 px/frame;
    clamp 8..148. Fire (INPT4) starts a serve or restarts after game over.
  - Ball: VX = ±2; VY from the 5-entry angle table `(-2,-1,0,1,2)` indexed by the hit offset
    `(BallY - PaddleY) / 5` (0..4). Move; bounce at Y=8 and Y=164; a paddle hit via CXP0FB/CXP1FB
    bit 6 reverses VX and sets VY; the paddle moves the ball out of the paddle.
  - Score: BallX < 6 -> right scores; BallX > 150 -> left scores. Cap at 9. ServeTimer=60;
    the ball parks at X=80, Y=90; the first serve is fixed left, later serves go toward the
    player who lost.
  - Game over: the first to 9 sets GameState=1; the winning digit flashes (`Frame & $10`);
    fire/SELECT resets the scores and serves.
  - Auto-demo: after 120 frames with no direction held, the right paddle tracks at 2 px/frame and
    the left at 1 px/frame toward a target 40 px below the ball, so the right side can score; the
    demo shortens the first serve after 2 s. A manual up/down takes over. The auto-demo is
    deterministic enough for the 2 s/about-6 s/12 s captures.
- **Row table:** clear 89 bytes; for P0 rows `P0Row..P0Row+11` OR bit 0; P1 rows `P1Row..+11` OR
  bit 1; ball rows `BallRow..+3` OR bit 2. `P0Row = P0Y/2`, `P1Row = P1Y/2`, `BallRow = BallY/2`.
  The table is built in VBLANK after the game logic.
- **Checkpoints:** `StartFrame`, `VblankStart`, `BodyStart`, `ScoreDone`, `PositionDone`,
  `OverscanStart`, `P0YRead`, `P1YRead`, `BallXRead`, `BallYRead`, `ScoreLeft` (A=the new score),
  `ScoreRight` (A=the new score), `PaddleHit` (A=0/1), `WallBounce`, `GameStateRead`,
  `RowTableWrite` (A=the code at row 0), `ServeStart`.
- **Screenshots:** `serve.png` (2 s, the serve/rally), `rally.png` (6 s, a rally), `game-over.png`
  (12 s, the winning digit flashing). All 1010×807, title bar `Stella 7.0: "69-pong"`, no cursor.
- **Exercises (4,096 each):**
  1. **CPU opponent.** Replace the right paddle's joystick with a follower that tracks the ball
     with a speed cap; SELECT toggles easy/hard; the left stays human. `exercise-01-solution.asm`.
  2. **Spin and speed.** The main already has the 5-zone angle table; extend it with a speed-up
     after four paddle hits, so the ball's VX grows to ±3 and the ex2 demo reaches 3-153.
     `exercise-02-solution.asm`.
  3. **Best-of-three.** Add a title/attract screen, a best-of-three match (first to 2 wins), a
     serve countdown, and a game-over screen; SELECT starts. `exercise-03-solution.asm`.
- **The doc:** the Pong architecture, the row table, the two-line kernel and the cycle-49 failure,
  the input map, the ball physics and angle table, the collision latches, the custom score, the
  serve/game-over states, the auto-demo. TypeScript equivalent: a row-table renderer + a simple
  physics step; say where the analogy breaks (no framebuffer, the TIA latches, the fixed frame).
- **Integration:** prev 68; next 70; the Part 10 index rebuilt (big-idea intro + 4-row lesson
  table + What You'll Learn), row 69 ✅; sidebar `config.ts:164`; README row 10 unchanged.
- **Risks:** the row-table RAM (89 bytes); the score/P0 conflict (custom score); the positioner
  count; the auto-demo determinism.

---

## Lesson 70: Capstone 2 — Breakout

- **Goal:** build a complete Breakout — a brick field, a paddle, a ball, per-brick collision and
  removal, the score library, three lives, three levels — and learn the zone kernel that combines
  a playfield field with a row-table play area.
- **Prerequisites:** Lesson 03, 04, 12, 14, 17, 19 (the playfield), 25, 26, 29 (the ball), 31
  (`NUSIZ`), 33 (controllers), 38 (collision), 41 (game states), 49 (the two-line kernel), 50
  (multi-zone), 63 (the score library), 69 (the row table).
- **Concepts:** the brick map (6 bits per row, mirrored); the 64×3 brick PF table; the brick
  collision math (row from Y, unique column from X); clearing a brick and rebuilding the PF row;
  the zone partition (score 9, gap 1, positioner 5, bricks 48, play 128, blank 1); the ball in
  both zones; the paddle's divide-by-15/HMOVE; lives and levels; the score library + reposition.
- **Screen (192 visible lines):**
  - Score band 0-8: `ScoreDraw` (nine lines, `000000`).
  - Blank line 9.
  - Positioner lines 10-14: P0 to `PaddleX`, the ball to `BallX`, one `HMOVE`.
  - Brick field 15-62: 6 brick rows × 8 lines; each row's PF0/PF1/PF2 from the brick mask; the
    ball's ENABL is set per line when the line is within `BallY..BallY+3`.
  - Play area 63-190: 32 rows × 4 lines; the row table (bit 0 = P0 paddle, bit 1 = ball) drives
    P0 and the ball; the paddle is 8×8 (2 rows), the ball 4×4 (1 row).
  - Blank line 191.
  - Total: 9 + 1 + 5 + 48 + 128 + 1 = 192.
- **Frame:** 259/3, 0/5, 37/5, 229 (measured).
- **RAM map:**
  - `$80-$85` `BrickMap` (6 bytes; 6 bits per row; bit 5 = leftmost unique brick).
  - `$86-$91` `BrickRowTable` (12 bytes; the brick zone's ball rows, one bit per 4-line row).
  - `$92-$9F` game variables: `BallX`, `BallY`, `BallVX`, `BallVY`, `PaddleX`, `Lives`, `Level`,
    `BricksLeft`, `Frame`, `ServeTimer`, `GameState`, `Temp`, `CurP0`, `CurBall`.
  - `$A0-$D7` the score library.
  - `$D8-$F7` `PlayRowTable` (32 bytes; bit 0 = P0 paddle, bit 1 = ball).
  - `$F8-$FF` stack.
- **Brick field:** 6 rows × 6 unique bricks; each brick is 8 px (2 chunks) with a 4-px gap;
  the 64-entry × 3-byte `BrickPF` table maps a 6-bit row mask to PF0/PF1/PF2; reflect mode
  mirrors the 6 bricks to 12 visible per row. The first brick is at chunk 0 (PF0 bit 4).
- **Brick collision:** read CXBLPF bit 7 in VBLANK. On a hit: `row = (BallY - 15) / 8` (0..5);
  the ball's centre X = BallX + 2; if X < 80, `col = (X - 8) / 12` (0..5); else the visible
  column is mirrored: `col = 5 - ((X - 80) / 12)`. If the brick bit is set, clear it, decrement
  `BricksLeft`, `ScoreAddOne`, reload the row's PF bytes, and bounce (reverse VY when the ball
  came from above/below; otherwise reverse VX). The capstone uses the simpler vertical bounce
  with a horizontal reversal when the ball's centre is within 2 px of the brick's edge.
- **Paddle:** P0, 8×8, X 8..152, 4 px/frame with the joystick; the ball collides via CXP0FB bit 6;
  the paddle's angle zones set the ball's VX (`-2,-1,0,1,2`) and keep VY negative.
- **Lives/levels:** 3 lives; a miss (BallY > 190) decrements; 0 -> game over (fire restarts).
  Clearing all 36 unique bricks advances the level; three patterns (`Level0/1/2` masks) and a
  speed-up; after level 3 the patterns repeat faster.
- **Score library:** `ScoreSetup` every frame in VBLANK, `ScoreDraw` in the body, then reposition
  P0 and the ball. Score 1 per brick; the six-digit display works.
- **Auto-demo:** the paddle tracks the ball with a 4-px/frame cap; the ball breaks bricks; a miss
  respawns; the captures at 2 s/6 s/10 s show the start, a broken field, and level 2.
- **Checkpoints:** `StartFrame`, `VblankStart`, `BodyStart`, `ScoreDone`, `BrickStart`,
  `PlayStart`, `OverscanStart`, `BrickHit` (A=the row), `BrickClear` (A=the new mask),
  `ScoreAdd` (the score library's checkpoint), `LifeLost`, `LevelStart`, `PaddleXRead`,
  `BallXRead`, `BallYRead`.
- **Screenshots:** `bricks-start.png`, `bricks-broken.png`, `level-two.png`. 1010×807, title bar
  `Stella 7.0: "70-breakout"`, no cursor.
- **Exercises (4,096 each):**
  1. **Multi-hit bricks.** A 6-byte HP map (2 bits per brick) so a brick takes two hits; the
     colour changes after the first hit; the score is 1 per hit and 2 for the final.
     `exercise-01-solution.asm`.
  2. **Level progression.** Three brick patterns, a level-clear banner (a playfield bar), a
     speed-up, and a level counter in the score's high digits. `exercise-02-solution.asm`.
  3. **Paddle angle and power-up.** A 5-zone angle table, a wide paddle power-up (NUSIZ), and a
     2× score multiplier for 300 frames. `exercise-03-solution.asm`.
- **The doc:** the Breakout architecture, the brick map and PF table, the collision math, the
  zones and the ball in both, the score/player conflict, lives/levels, the auto-demo. TypeScript
  equivalent: a brick grid + a collision function + a row-table renderer; say where it breaks.
- **Integration:** prev 69; next 71; index row 70 ✅; sidebar `config.ts:165`; README unchanged.
- **Risks:** the brick collision math; the PF table; the ball's dual-zone visibility; the RAM map
  (exact); the score reposition.

---

## Lesson 71: Capstone 3 — Maze Explorer

- **Goal:** build a complete maze adventure — a generated mirror maze, cell-by-cell movement, two
  enemies with a chase AI, three keys, a win and a lose state — and learn how a generator and a
  table-driven kernel produce a playable world.
- **Prerequisites:** Lesson 03, 04, 12, 14, 17, 19 (the playfield), 25, 26, 31, 33, 38, 41, 43
  (random), 44 (AI), 49, 50, 53, 63 (the score library), 67 (the generator), 69 (the row table),
  70 (the zones).
- **Concepts:** the mirror maze (10 unique columns, 20 visible via reflect); the cell/pixel
  transform; the wall map and movement check; the mirror column transform; the four-line object
  row table inside 16-line maze rows; the key icons as playfield blocks; the enemy chase; the
  win/lose states; the generator, spec, include, and `--check`.
- **Screen (192 visible lines):**
  - Status band 0-15: 8 lines of key icons (three 8×8 PF blocks at X=64, 80, 96; filled when
    collected) + 8 lines for the positioners/blank.
  - Maze 16-191: 11 maze rows × 16 lines = 176. Each maze row is 10 unique cells × 2 chunks =
    20 chunks, reflect mode -> 20 cells. The PF bytes load once per maze row (3 bytes); the
    object row table is decoded every 4 lines (4 object rows per maze row).
  - Total: 16 + 176 = 192.
- **Frame:** 259/3, 0/5, 37/5, 229 (measured).
- **RAM map:**
  - `$80-$AB` `ObjRowTable` (44 bytes; 4 bits per 4-line row: bit 0 player, bit 1 enemy1,
    bit 2 enemy2, bit 3 key).
  - `$AC-$D7` game variables: `PlayerCol`, `PlayerRow`, `PrevJoy`, `MoveTimer`, `Enemy1Col`,
    `Enemy1Row`, `Enemy2Col`, `Enemy2Row`, `EnemyTimer`, `KeyCol`, `KeyRow`, `KeysLeft`,
    `KeyIndex`, `Frame`, `GameState`, `Temp`, `CurP0`, `CurP1`, `CurM0`, `CurBall`, `P0Row`,
    `P1Row`, `M0Row`, `BallRow`, `P0RowEnd`, `P1RowEnd`, `M0RowEnd`, `BallRowEnd` (28 bytes).
  - `$D8-$F7` scratch/free; `$F8-$FF` stack.
  - The maze PF bytes and wall map are in ROM (`maze-data.inc`).
- **Maze generation:** `lesson71-generate.py` (Python 3, no third-party deps) with
  `--spec maze-spec.txt --out maze-data.inc --check`; the spec: `seed 20261010`, `width 10`,
  `height 11`, `keys 3`, `enemies 2`. The generator:
  - builds a perfect maze on the 10×11 grid with a recursive backtracker;
  - opens a seam between columns 9 and 10 (the mirror seam) at one or two rows;
  - places 3 keys in dead ends (one per region), 2 enemy starts away from the player;
  - emits the header (canonical command), `MazePF` (11×3 bytes), `MazeWalls` (11×2 bytes, 10 bits
    per row), `KeyCells` (3×2), `EnemyCells` (2×2), and the `MazeRows`/`MazeCols` constants;
  - `--check` regenerates in memory and compares; a bad spec exits 1 with `spec:line`.
- **Movement:** the player starts at `(0,10)`; a joystick direction tries the next cell:
  `col < 10 ? col : 19-col` maps to the unique wall map; open -> move, update X/Y; the move timer
  repeats every 8 frames if held. The player sprite is 8×16; X = col*8, Y = 16 + row*16.
- **Enemies:** two; move every 8 frames; choose the axis with the larger distance to the player;
  if blocked, try the other; if blocked, stay; the mirror transform for the wall check. The
  enemy sprites are 8×16. A collision with the player's cell -> the lose state.
- **Keys:** the ball is the current key; entering its cell increments `KeysLeft`, moves the ball
  to the next key, and fills the next status icon; after 3, the win state (the maze flashes green).
- **Win/lose:** win -> `GameState=1` (green flash, the icons all filled); lose -> `GameState=2`
  (red flash); fire restarts (reset the player/enemies/keys).
- **Auto-demo:** a scripted path visits the first key, passes an enemy, and reaches the win; the
  captures at 2 s/6 s/10 s show the start, a key collected, and the win.
- **Checkpoints:** `StartFrame`, `VblankStart`, `BodyStart`, `MazeRowStart`, `OverscanStart`,
  `PlayerCell` (A=col, X=row), `MoveTry` (A=the direction), `WallRead` (A=the wall byte),
  `KeyGet` (A=the new keys-left), `EnemyStep` (A=enemy 0/1), `GameStateRead`, `ObjRowWrite`.
- **Screenshots:** `maze-start.png`, `maze-key.png`, `maze-win.png`. 1010×807, title bar
  `Stella 7.0: "71-maze-explorer"`, no cursor.
- **Exercises (4,096 each):**
  1. **Fog of war.** Only cells within two of the player are drawn; the rest are black; rebuild
     the PF rows per frame from the distance. `exercise-01-solution.asm`.
  2. **Smarter enemies.** A BFS/pathfinding enemy (or a patrol+chase mix) that takes the shortest
     corridor path; `exercise-02-solution.asm`.
  3. **Treasure and timer.** A 60-second timer, a bonus key worth 2, and a win screen;
     `exercise-03-solution.asm`.
- **The doc:** the mirror maze, the generator and spec, the storage, the cell/pixel transform, the
  wall check, the row-table kernel, the enemy AI, the keys and win/lose, the auto-demo. TypeScript
  equivalent: a grid + a wall lookup + a BFS/AI step; say where it breaks (no runtime parser, the
  fixed tables, the reflect display).
- **Integration:** prev 70; next 72; index row 71 ✅; sidebar `config.ts:166`; README unchanged.
- **Risks:** the generator include drift; the mirror transform; the row-table RAM; the 4K budget
  (the maze PF/wall/key tables + the kernel + the generator include); the auto-demo path.

---

## Lesson 72: Capstone 4 — Your Own Game

- **Goal:** turn the reader into a game designer and producer: scope a 4K game, write the design
  document, plan the RAM/screen maps and milestones, and start from a complete skeleton.
- **Prerequisites:** all of Parts 1–10; especially Lesson 41 (states), Lesson 45 (memory), Lesson
  46 (debugging), Lesson 47 (dev tools), Lesson 39 (the scoreboard and score library), Lesson 69 (Pong), Lesson 70
  (Breakout), Lesson 71 (Maze).
- **Concepts:** the game design document (concept, core loop, controls, screen, objects, states,
  win/lose, audio, milestones); the 4K budget worksheet; the RAM/screen maps; the risk list; the
  prototype-first method; the production pipeline (the five hard rules); the difference between a
  demo and a shippable lesson.
- **ROM:** `demo-72.asm` — **"star catcher"**, 4,096 bytes:
  - State 0 TITLE: a gold emblem, `PRESS FIRE`, a blinking prompt.
  - State 1 PLAY: P0 moves left/right (joystick), a ball falls from the top at a random X, a
    catch scores 1 and respawns, a miss costs a life; 3 lives; a 30-second timer shown as a bar.
  - State 2 OVER: the final score, a red field, `FIRE` restarts.
  - The score library shows the score; the sound library plays a catch blip and a miss buzz; the
    fire edge starts/restarts; an auto-demo catches/misses for deterministic captures.
  - Three clearly marked sections: `YOUR GAME — INPUT`, `YOUR GAME — UPDATE`,
    `YOUR GAME — DRAW`; the reader replaces them.
- **Frame:** 259/3, 0/5, 37/5, 229 (measured).
- **RAM:** `$80-$9F` the game variables (`GameState`, `PlayerX`, `ItemX`, `ItemY`, `Score`,
  `Lives`, `Timer`, `Frame`, `PrevFire`, `CurItem`, etc.); `$A0-$D7` the score library;
  `$D8-$F7` free; `$F8-$FF` stack.
- **Checkpoints:** `StartFrame`, `VblankStart`, `BodyStart`, `StateChange` (A=the new state),
  `ScoreWrite` (A=the new score), `ItemSpawn` (A=the item's X), `Catch` (A=the score),
  `Miss` (A=the lives), `OverscanStart`.
- **Screenshots:** `title.png` (2 s), `play.png` (6 s); 1010×807, title bar
  `Stella 7.0: "demo-72"`, no cursor.
- **Doc templates (answered in the doc):**
  - **GDD template:** one page — title, concept, core loop, controls, screen map, object list,
    states, win/lose, score, audio, milestones, risks.
  - **RAM map worksheet:** a 128-byte grid; the score library `$A0-$D7`, the stack `$F8-$FF`, the
    variables, the tables; the rule "no data under the stack".
  - **Screen map worksheet:** a 192-line grid; the zones; the kernel choice; the cycle budget.
  - **4K budget worksheet:** ROM bytes for the kernel, the tables, the font, the sound, the
    strings; the 4,096 limit; the headroom.
  - **Milestone plan:** M1 the frame + input, M2 the core loop + score, M3 the audio + states,
    M4 the polish + captures; each with a test.
  - **Production checklist:** the five hard rules.
- **Exercises (design tasks, answered in the doc; no solution files):**
  1. Write a one-page GDD for your game using the template; identify the core loop and the
     win/lose state.
  2. Draw the RAM and screen maps; name every variable and every zone; check the 4K budget.
  3. Write the milestone plan; name the riskiest mechanic and the smallest prototype that proves
     it first.
- **Integration:** prev 71; next the Part 11 index (`/part11-legendary/`); index row 72 ✅;
  sidebar `config.ts:167`; README row 10 unchanged.
- **Risks:** the skeleton must be complete enough to run but small enough to read; the three
  `YOUR GAME` sections must be clearly marked; the doc must not become a fifth game.

---

## Cross-Lesson Evidence Summary

| Lesson | ROM(s) | Primary evidence | Captures |
| --- | --- | --- | --- |
| 69 | main + 3 solutions (4,096 each) | Row table 89 bytes; frame 259/37/229; score left/right; paddle hits; serve; game over | 3 |
| 70 | main + 3 solutions (4,096 each) | Brick map 6 bytes; PF table 64×3; frame 259/37/229; brick cleared; life lost; level 2 | 3 |
| 71 | main + 3 solutions (4,096 each) | Mirror maze 10×11; generator `--check`; frame 259/37/229; key collected; win/lose | 3 |
| 72 | demo-72 (4,096) | Skeleton states; score/sound/restart; frame 259/37/229 | 2 |
