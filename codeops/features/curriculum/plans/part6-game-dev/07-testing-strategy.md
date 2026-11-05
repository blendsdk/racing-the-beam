# Testing Strategy: Part 6 — Game Development (Lessons 38–47)

> **Document**: 07-testing-strategy.md
> **Parent**: [Index](00-index.md)

## Testing Overview

This repository ships static lesson content and ROMs; there is no test framework, and none is
added (AR-7). The specification tests are **observational acceptance cases**: every ST row names
a concrete action (assemble, run, inspect, capture, break) and a concrete expected outcome that a
human or recorded command output can confirm. Session A freezes the rows for its lesson before
implementation and records the red baseline; Session C confirms every row and records the evidence
(AR-2, AR-4).

Expected outcomes here derive only from [03-lesson-specs.md](03-lesson-specs.md) and the register
ground truth — never from the implementation (immutable-oracle rule). If an implementation
disagrees with an ST row, the implementation is wrong.

**Evidence methods:** `bash scripts/verify.sh` output (assembly + drift + docs build); screenshots
captured from the committed ROM path and pixel-checked against the monitor geometry
(`x = 25 + 6·X`; `y = 107 + 3.15·visible_line`; picture rows 107–711); timed waits/bursts for
moving or switching states; and Stella state logs
(`stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'`, format
`BP: <frame> <scanline> <cycles> <pixels> | <flags> <A> <X> <Y> <SP> |`) with static cycle ledgers.
Logic rows use a breakpoint after the store/read; the A column is the value.

> A screenshot proves the visual state only. The runnable artifact is the committed ROM and the
> `<RomPlayer>`; the tests below never claim otherwise. The lesson docs tell the reader to click
> the player screen once to unmute Javatari.

## 🚨 Specification Test Cases (frozen per lesson in Session A)

### Lesson 38 — Collision Detection

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-38.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-06 AC 1–2 / AR-4 |
| ST-38.2 | Run the ROM; inspect the collision bands and hit bar | Four 6-line bands at visible 0–23; the active band uses its color (`P0–P1` red `$42`, `P0–ball` gold `$1A`, `P0–playfield` green `$C8`, `M0–P1` blue `$84`); the hit bar is N gold chunks per half at visible 172–177; P0 moves in both axes so it can meet P1 (Y=40), the ball (Y=100), and the wall (X≤15); background `$02` | Screenshots `wall.png`, `p1.png` + pixel check | 03 §Lesson 38 |
| ST-38.3 | Inspect the collision read and edge detection | `ReadCX` A = `CXP0FB`; `CollMask` A = the full mask; `CollStep` A = the 0→1 edge bits only (`CollMask & ~PrevMask`); `Hits` increments once per edge and clamps at 15; `CXClear` fires once per frame after the read; the auto-fire produces an M0–P1 `CollStep` `$10` | State log + static ledger | RD-06 AC 3 / 03 §Lesson 38 |
| ST-38.4 | Debugger: frame and positioning | `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `OverscanStart` 229 (262 lines); `HmoveApply`/`HmoveDone` once per frame; P0 starts at X=8, Y=140 and moves in both axes (clamp 8–144); P1 at X=40–136, Y=40; ball X=80, Y=100 | State log + static ledger (AR-6) | RD-06 AC 3 / 03 §Lesson 38 |
| ST-38.5 | Assemble and run each solution | Ex 1: the green band lights on `CXP0FB` bit 6 (ball); ex 2: the enemy missile M1 lights the blue band on `CXM1P` bit 7; ex 3: **no** `CXClear` at all and the bands stay lit after separation | `verify.sh` + manual runs + captures | RD-06 AC 1 / AR-27 |
| ST-38.6 | Build the site and inspect the page | Part index row 38 ✅ Complete linking `./38-collision-detection`; page prev 37, next 39; both images and `<RomPlayer>` on the committed ROM render; sidebar `config.ts:109`; README unchanged | `npm run docs:build` + page check | RD-06 AC 1 / AR-10 |

### Lesson 39 — The Scoreboard

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-39.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-06 AC 1–2 / AR-4 |
| ST-39.2 | Run the ROM; inspect the score and the target | Six white digits in a 48-pixel block at capture x≈367–642, y≈110–130; the first capture reads **000001** and the second **000002**; the target is a gold 32-px block at y≈580–604 (visible 150–157); the ball is a gold 1-px-wide, 8-row block at the same rows | Screenshots `score-a.png`, `score-b.png` + pixel check | 03 §Lesson 39 |
| ST-39.3 | Inspect the score logic | `ScoreInit` zeros `ScoreDigits`/`ScoreBuf`; `ScoreClear` draws six zero glyphs; `ScoreSetDigit` stores the digit and copies all eight font bytes of the column; `ScoreAddOne` carries 9→0 across the six digits and returns C=1 at 999999→000000; `BallHit` fires on `CXBLPF` bit 7 | State log + static ledger | RD-06 AC 3 / 03 §Lesson 39 |
| ST-39.4 | Debugger: frame and score zone | `StartFrame` 259, `VblankStart` 0, `BodyStart` 37; the score zone is 9 lines (visible 0 is the setup/blank line, rows 1–8 draw), the game zone is 183 lines, and `OverscanStart` 229 (262 lines); `ScoreDraw` marks the call and `ScoreDrawRow` each row; `HmoveDone` once per frame; P0 X=56, P1 X=64 | State log + static ledger (AR-6) | RD-06 AC 3 / 03 §Lesson 39 |
| ST-39.5 | Assemble and run each solution | Ex 1: the capture reads 012345 with `ScoreDigitWrite` at six positions; ex 2: the score advances by 2 per hit and carries; ex 3: leading zero columns are blank and 000042 reads `    42` (four blanks + 42) | `verify.sh` + manual runs + captures | RD-06 AC 1 / AR-27 |
| ST-39.6 | Build the site and inspect the page | Part index row 39 ✅ Complete; page prev 38, next 40; both images and `<RomPlayer>` render; sidebar `config.ts:110`; README unchanged; `include/score.asm` exists and is sourced | `npm run docs:build` + page check | RD-06 AC 1 / AR-10 |

### Lesson 40 — BCD Arithmetic

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-40.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-06 AC 1–2 / AR-4 |
| ST-40.2 | Run the ROM; inspect the score and operations | The first capture reads **000001** after one ADD 1; the second reads **000101** after ADD 100; the operation bar highlights the active operation; the overflow cell is dark except on wrap; background `$02` | Screenshots `add1.png`, `add100.png` + pixel check | 03 §Lesson 40 |
| ST-40.3 | Inspect the BCD arithmetic | `BCDAdd` A = the command selector (1/10/100; A=1 low+1, A=10 low+$10, A=100 mid+1); `BCDCarryMid` A = 1 on a middle-byte carry (ADD 1/ADD 10), `BCDCarry` A = 1 on a high-byte carry (ex 3); `BCDScoreLow/Mid/High` hold the BCD bytes; `CLD` is restored after every path that enters decimal mode; the subtotal is a valid BCD value | State log + static ledger | RD-06 AC 3 / 03 §Lesson 40 |
| ST-40.4 | Debugger: frame and score | `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `OverscanStart` 229 (262 lines); `ScoreDigitWrite` rebuilds the six digits; `HmoveDone` once per frame | State log + static ledger (AR-6) | RD-06 AC 3 / 03 §Lesson 40 |
| ST-40.5 | Assemble and run each solution | Ex 1: 000010 with the ADD 10 cell lit; ex 2: 000000 → 999999 with the borrow; ex 3: 009900 + 100 = 010000 with the middle carry | `verify.sh` + manual runs + captures | RD-06 AC 1 / AR-27 |
| ST-40.6 | Build the site and inspect the page | Part index row 40 ✅ Complete; page prev 39, next 41; both images and `<RomPlayer>` render; sidebar `config.ts:111`; README unchanged | `npm run docs:build` + page check | RD-06 AC 1 / AR-10 |

### Lesson 41 — Game States

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-41.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-06 AC 1–2 / AR-4 |
| ST-41.2 | Run the ROM; inspect the three states | Title: gold emblem + blinking bottom bar (15 chunks per half, two segments); play: 16-line status bar with the hit bar, P0 red at Y=140, ball gold falling; over: red field + solid 16-line final hit bar + blinking fire bar; background `$02`; the doc discloses the saveSnap+chrome capture method | Screenshots `title.png`, `over.png` + pixel check | 03 §Lesson 41 |
| ST-41.3 | Inspect the transitions and per-state logic | `StateChange` A=1 on fire from title; A=2 on ball Y>180; A=0 on fire from over; `Hits` resets on entering play; `BallY` is unchanged while paused (ex 1) | State log + static ledger | RD-06 AC 3 / 03 §Lesson 41 |
| ST-41.4 | Debugger: frame and state timing | `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `OverscanStart` 229 (262 lines); `HmoveApply` 11/56, `HmoveDone` 12/3; `FireRead` A = `INPT4`; `TimerRead` A = `StateTimer`; `BallStep` A = the new `BallY` | State log + static ledger (AR-6) | RD-06 AC 3 / 03 §Lesson 41 |
| ST-41.5 | Assemble and run each solution | Ex 1: `StateChange` A=3 then A=1 on SELECT and the ball freezes; ex 2: `StateChange` A=1 at frame 300 with no fire; ex 3: `HighScore` retains the max across two games | `verify.sh` + manual runs + captures | RD-06 AC 1 / AR-27 |
| ST-41.6 | Build the site and inspect the page | Part index row 41 ✅ Complete; page prev 40, next 42; both images and `<RomPlayer>` render; sidebar `config.ts:112`; README unchanged | `npm run docs:build` + page check | RD-06 AC 1 / AR-10 |

### Lesson 42 — Difficulty and Progression

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-42.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-06 AC 1–2 / AR-4 |
| ST-42.2 | Run the ROM with each switch combination; inspect the ladder | Level bar N chunks per half; three red life cells per half; a 2-cell switch indicator per half; the enemy is green and its width is 8 px (B/novice, bit=0) or 16 px (A/expert, bit=1); the speed rises with the level | Screenshots `level1.png`, `level5.png` + pixel check | 03 §Lesson 42 |
| ST-42.3 | Inspect the switch reads and progression | `ReadSWCHB` A = `SWCHB`; bit 6 selects start level 1 (B/0) or 5 (A/1); bit 7 selects `NUSIZ1` 0 (B/0) or 5 (A/1); `LevelUp` A=level every 300 frames capped at 15; `SpeedWrite` A = `SpeedTable[Level]`; `LifeStep` decrements on `CXPPMM` bit 7 (P0 and P1 share Y=140) | State log + static ledger | RD-06 AC 3 / 03 §Lesson 42 |
| ST-42.4 | Debugger: frame and lives | `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `OverscanStart` 229 (262 lines); `LifeInit` A=3; `LifeStep` A=2→1→0; the red field appears at 0; fire restarts at the switch-selected starting level (1 on B, 5 on A) | State log + static ledger (AR-6) | RD-06 AC 3 / 03 §Lesson 42 |
| ST-42.5 | Assemble and run each solution | Ex 1: expert starts at level 1 (inverted); ex 2: `NUSIZWrite` A=3, P1 capped at X=24–104, three enemies on screen; ex 3: `LevelUp` stops at 10 on expert | `verify.sh` + manual runs + captures | RD-06 AC 1 / AR-27 |
| ST-42.6 | Build the site and inspect the page | Part index row 42 ✅ Complete; page prev 41, next 43; both images and `<RomPlayer>` render; sidebar `config.ts:113`; README unchanged | `npm run docs:build` + page check | RD-06 AC 1 / AR-10 |

### Lesson 43 — Random Numbers

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-43.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-06 AC 1–2 / AR-4 |
| ST-43.2 | Run the ROM; inspect the random visuals | The 8-cell seed row, the 8×8 history grid (4-px cells, 4 lines per row), and the 15-cell `seed>>4` meter (4 px wide, mirrored); two captures show different seeds/patterns; background `$02` | Screenshots `random-a.png`, `random-b.png` + pixel check | 03 §Lesson 43 |
| ST-43.3 | Inspect the LFSR | `RandomStep` A = the new seed; the sequence has period 255 for a nonzero seed and never reaches 0 from a nonzero seed; `RandomMask` A = `seed & mask`; `RandomPush` shifts the history | State log + static ledger | RD-06 AC 3 / 03 §Lesson 43 |
| ST-43.4 | Debugger: frame and update rate | `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `OverscanStart` 229 (262 lines); `RandomStep` fires every 4 frames; `SeedWrite` A = the seed on fire | State log + static ledger (AR-6) | RD-06 AC 3 / 03 §Lesson 43 |
| ST-43.5 | Assemble and run each solution | Ex 1: the 16-bit low bytes repeat only after 65535 steps; ex 2: the ball X is `24 + 16×(seed&7)` and `RandomMask` A=7; ex 3: two SELECT presses at different frames give different seeds while fire keeps its reseed | `verify.sh` + manual runs + captures | RD-06 AC 1 / AR-27 |
| ST-43.6 | Build the site and inspect the page | Part index row 43 ✅ Complete; page prev 42, next 44; both images and `<RomPlayer>` render; sidebar `config.ts:114`; README unchanged; `include/random.asm` exists and is sourced | `npm run docs:build` + page check | RD-06 AC 1 / AR-10 |

### Lesson 44 — AI & Enemy Behavior

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-44.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-06 AC 1–2 / AR-4 |
| ST-44.2 | Run the ROM; inspect the enemy states | Patrol green, chase gold, flee red; the 3-cell state row (per half, visible 0–7) lights one cell; the distance bar (per half, visible 8–15) is N chunks; the enemy and player are 16-row sprites at Y=100; background `$02` | Screenshots `patrol.png`, `chase.png` + pixel check | 03 §Lesson 44 |
| ST-44.3 | Inspect the AI transitions | P0 and P1 share Y=100; `EnemyState` A=0→1 when distance > 24; a **chasing** enemy A=2 when distance ≤ 24 or fire (a patrol is calm at close range); A=0 after 60 flee frames and distance > 32 (hysteresis); `EnemyMove` A=±1 patrol/±2 chase/flee; `Distance` A = `|PlayerX−EnemyX|`; `LifeStep` on `CXPPMM` bit 7, with a safe respawn and 60-frame invulnerability | State log + static ledger | RD-06 AC 3 / 03 §Lesson 44 |
| ST-44.4 | Debugger: frame and state timing | `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `OverscanStart` 229 (262 lines); `EnemyTimer` counts the flee/waypoint pause; `HmoveDone` once per frame | State log + static ledger (AR-6) | RD-06 AC 3 / 03 §Lesson 44 |
| ST-44.5 | Assemble and run each solution | Ex 1: `EnemyX` pauses 30 frames at 40/120; ex 2: `EnemyMove` A=0 in the 16-px dead zone; ex 3: `EnemySpeed` A=3 on expert | `verify.sh` + manual runs + captures | RD-06 AC 1 / AR-27 |
| ST-44.6 | Build the site and inspect the page | Part index row 44 ✅ Complete; page prev 43, next 45; both images and `<RomPlayer>` render; sidebar `config.ts:115`; README unchanged | `npm run docs:build` + page check | RD-06 AC 1 / AR-10 |

### Lesson 45 — Memory Management

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-45.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no RAM overflows; no ROM drift; docs build passes | `verify.sh` + file size | RD-06 AC 1–2 / AR-4 |
| ST-45.2 | Run the ROM; inspect the memory map | A 16×8 grid of 128 cells (16 columns per half, `CTRLPF=$01` mirror) at visible 8–39; lit = used, dark = free; the 4-cell flags row per half at visible 0–7; the 15-cell timer bar at X=24 (visible 40–129); background `$02` | Screenshot `map.png` + pixel check | 03 §Lesson 45 |
| ST-45.3 | Inspect the packed values | The main's four flag bytes (`FlagFire/Left/Right/Over`) are stored; exercise 1's `FlagsWrite` A = the packed byte; `PackTimer` A = the nibble-packed timer (high nibble = 16-frame ticks); `MapDraw` reads the static `RamMap` table; the `!if` budget assert is on the `RamEnd` label at `$F7` | State log + static ledger | RD-06 AC 3 / 03 §Lesson 45 |
| ST-45.4 | Debugger: frame and RAM | `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `OverscanStart` 229 (262 lines); the used addresses are inside `$80–$F7`; the stack is reserved `$F8–$FF` | State log + static ledger (AR-6) | RD-06 AC 3 / 03 §Lesson 45 |
| ST-45.5 | Assemble and run each solution | Ex 1: the packed map loses three cells per reference half; ex 2: the overlay builds and the shared bytes are marked; ex 3: moving a variable to `$F8` fails the ACME build with the budget error | `verify.sh` + manual runs + captures | RD-06 AC 1 / AR-27 |
| ST-45.6 | Build the site and inspect the page | Part index row 45 ✅ Complete; page prev 44, next 46; both images and `<RomPlayer>` render; sidebar `config.ts:116`; README unchanged | `npm run docs:build` + page check | RD-06 AC 1 / AR-10 |

### Lesson 46 — Debugging

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-46.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-06 AC 1–2 / AR-4 |
| ST-46.2 | Run the ROM; toggle the three bugs | The 3-cell mode row per half and the bug/fix cell in the status row (visible 0–15), play area 16–191; bug 0 leaves the collision band lit after separation, fixed 0 clears; bug 1 gives `OverscanStart` 230 (263 lines), fixed 1 gives 229; bug 2 draws P0 one line off | Screenshots `bug-sticky.png`, `fix-sticky.png` + pixel check | 03 §Lesson 46 |
| ST-46.3 | Inspect the debug checkpoints | `Mode` A=0/1/2; `BugToggle` A=`BugOn`; `CXClear` fires only in the fixed 0 path; `OverscanStart` 229/230; `PlayerY` matches the fixed sprite row (the off-by-one is the drawn row vs the game-logic Y, not a TIA collision box) | State log + static ledger | RD-06 AC 3 / 03 §Lesson 46 |
| ST-46.4 | Debugger: the lesson's commands | The doc's `stella -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'` commands report the frame/scanline/cycle columns as described; the frame is 262 lines in the fixed paths; `HmoveDone` once per frame | State log + static ledger (AR-6) | RD-06 AC 3 / 03 §Lesson 46 |
| ST-46.5 | Assemble and run each solution | Ex 1: `CXClear` every frame and the band clears; ex 2: `OverscanStart` 229; ex 3: the drawn row and the game-logic Y agree | `verify.sh` + manual runs + captures | RD-06 AC 1 / AR-27 |
| ST-46.6 | Build the site and inspect the page | Part index row 46 ✅ Complete; page prev 45, next 47; both images and `<RomPlayer>` render; sidebar `config.ts:117`; README unchanged | `npm run docs:build` + page check | RD-06 AC 1 / AR-10 |

### Lesson 47 — Development Tools & Workflow

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-47.1 | Assemble `demo-47.asm` and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes; the `DEBUG=1` and `DEBUG=0` builds differ | `verify.sh` + file size + `cmp` | RD-06 AC 1–2 / AR-4 |
| ST-47.2 | Run the demo; inspect the dashboard | Five 16-line stage blocks (EDIT, ASSEMBLE, RUN, VERIFY, COMMIT); the active stage green, completed dim gold, future `$02`; the 15-cell progress bar per half; the 8-cell checksum row per half; `CTRLPF=$01`; background `$02` | Screenshots `stage2.png`, `stage4.png` + pixel check | 03 §Lesson 47 |
| ST-47.3 | Inspect the stage and checksum logic | `StageStep` A increments every 30 frames 0→4, pauses 60, restarts; `BuildFlag` A = `DEBUG`; `CheckSum` A = the 8-bit sum of the 256-byte `CheckData` table and matches the Python sum | State log + static ledger | RD-06 AC 3 / 03 §Lesson 47 |
| ST-47.4 | Debugger: frame and build symbols | `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `OverscanStart` 229 (262 lines); the symbol file (`-l`) resolves `StageStep`, `BuildFlag`, `CheckSum`; the doc's commands reproduce the log | State log + symbol file | RD-06 AC 3 / 03 §Lesson 47 |
| ST-47.5 | Assemble and run each solution | Ex 1: six stages and `StageStep` A reaches 5; ex 2: the debug build's border is red, the release's green, and `BuildFlag` A=1/0; ex 3: the rotated `CheckSum` matches the Python value, differs from the main, and the row is stable | `verify.sh` + manual runs + captures | RD-06 AC 1 / AR-27 |
| ST-47.6 | Build the site and inspect the page | Part index row 47 ✅ Complete; page prev 46, next `/part7-kernel-mastery/48-introduction-to-kernels`; both images and `<RomPlayer>` render; sidebar `config.ts:118`; README unchanged | `npm run docs:build` + page check | RD-06 AC 1 / AR-10 |

## Verification Commands

| Purpose | Command |
| --- | --- |
| Full gate | `bash scripts/verify.sh` |
| Rebuild committed ROMs | `npm run roms` |
| Capture a screenshot | `bash scripts/capture-screenshot.sh <committed-rom> <out.png> [wait]` |
| State log | `stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$ADDR' <rom>` |
| Docs build | `npm run docs:build` |

## Coverage Notes

- Every RD-06 acceptance criterion maps to at least one ST row: AC 1 → the `.1`/`.5`/`.6` rows;
  AC 2 → the `.1` rows; AC 3 → the `.3`/`.4` rows; AC 4 → the site rows and the frozen curriculum
  check in each Session A record.
- The logic rows test the register/RAM values and frame timing, not the player's perception. The
  lesson documents disclose that boundary.
- No unit-test framework is added; the observation cases are the repository's test form (AR-7).
