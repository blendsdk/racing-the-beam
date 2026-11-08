# Execution Plan: Part 10 — Capstone Projects (Lessons 69–72)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-08 04:37
> **Progress**: 3/5 tasks (60%)
> **CodeOps Artifact Schema**: 1

## Overview

Four lesson phases, one per capstone, strictly sequential — 69 establishes the row-table
two-line kernel and the complete-game pattern; 70 adds the brick field and the zone kernel; 71
adds the generator and the mirror maze; 72 turns the whole course into the reader's own project.
Every phase is one task run through the mandatory three-session ordering: Session A freezes that
lesson's specification cases and records a red baseline, Session B implements the full artifact
set, and Session C verifies against the frozen cases and hardens under independent review (AR-2,
AR-5). `bash scripts/verify.sh` is the gate for every phase (AR-4). Kernel, collision, generator,
and frame claims carry the state-log + static-ledger + pixel evidence of AR-6/AR-26; every
screenshot is pixel-checked against the lesson geometry (AR-7, AR-26).

**🚨 Update this document after EACH completed task!**

**Session record slots:** each task gets a `**Session A record**` paragraph after its task line
(freeze + red baseline + design pins) and a **Session C record** paragraph after the Session
sub-steps. The per-lesson findings are appended to [05-findings.md](05-findings.md); the plan-level
preflight findings live in [00-preflight-report.md](00-preflight-report.md). The plan is not
executable until the preflight report exists and the roadmap row reads `Executing`. The push mode
is authorized by the user's directive to execute RD-10 and the Part 1–9 practice (AR-27).

---

## Implementation Phases

| Phase | Title | Tasks |
| ----- | ----- | ----- |
| 1 | Lesson 69 — Capstone 1: Pong | 1 |
| 2 | Lesson 70 — Capstone 2: Breakout | 1 |
| 3 | Lesson 71 — Capstone 3: Maze Explorer | 1 |
| 4 | Lesson 72 — Capstone 4: Your Own Game | 1 |
| 5 | Part 10 completion gate | 1 |

**Total: 4 lesson tasks + 1 completion gate.**

> **⚠️ EXECUTION RULE — APPLIES TO EVERY AGENT EXECUTING THIS PLAN:**
>
> The task checkboxes below are the **single source of truth** for progress. Every task line
> appears exactly once in this document. The executing agent MUST:
>
> 1. **On implementation:** mark the task `[~]` with a timestamp —
>    `- [~] N.1.1 Task description ⏳ (implemented: YYYY-MM-DD HH:MM)`
> 2. **On verify pass:** promote it to `[x]` —
>    `- [x] N.1.1 Task description ✅ (completed: YYYY-MM-DD HH:MM)`
> 3. **Update the Progress header** and the Last Updated stamp after EVERY task — never batch.
> 4. **Resume** at the first `[~]`, else the first `[ ]`.
> 5. **On blocker:** mark the task `[!]` with a one-line reason.
>
> Timestamps come from `date '+%Y-%m-%d %H:%M'` — never invented.

---

## Phase 1: Lesson 69 — Capstone 1: Pong

> **Phase baseline tree**: the plan+preflight commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part10-capstones/69-pong/` (main + 3 solutions) ·
> `docs/part10-capstones/69-pong.md` · `docs/part10-capstones/index.md` (rebuild + row 69) ·
> `docs/public/roms/part10-capstones/69-pong/` · `docs/public/images/lesson69/` (3 captures) ·
> `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the first capstone establishes the row-table kernel, the complete-game
> pattern, the custom score, and the auto-demo evidence the next three lessons reuse

### Step 1.1: Lesson 69 — Capstone 1: Pong

**Reference**: [03 §Lesson 69](03-lesson-specs.md) · AR-10–AR-13, AR-24
**Objective**: ship the complete two-player Pong, the three solutions, and the document.

- [x] 1.1.1 Lesson 69 — Capstone 1: Pong: Session A freezes ST-69.1–ST-69.8 (red baseline),
  Session B implements the game, the custom score, the row table, the three solutions, and the
  document, Session C verifies to green and hardens; commit via the `git-commit` skill in push
  mode — `feat(lesson69): Capstone 1 — Pong` ✅ (completed: 2026-11-07 22:30)

**Session A record** (freeze + red baseline, 2026-11-07 20:47): ST-69.1–ST-69.8 re-affirmed against [03](03-lesson-specs.md) §Lesson 69. Design pins: the doc title is the curriculum/stub title **"Lesson 69: Capstone 1 — Pong"**; the main ROM is `69-pong.asm` (4,096) with three 4,096-byte solutions. The screen is **8 score + 1 blank + 5 positioner + 178 play = 192**; the play area is 89 rows × 2 lines driven by a **precomputed 89-byte row table** (bit 0 P0, bit 1 P1, bit 2 ball) at `$80-$D8`; the stores are at the start of each row's first line (a lookahead decode of the next row during the second line), because the preflight's one-line range-test kernel wrote GRP0 at cycle 49 and P0 at X=16 was invisible. The **custom one-digit-per-player score** uses P0 at X=64 and P1 at X=88 for the left/right digits (8×7 glyphs; 10×8 font); Pong does not use `include/score.asm`, so `$A0-$D7` is free for the row table. The RAM map is `$80-$D8` row table, `$D9-$F0` variables, `$F1-$FF` stack. The game is two-player (SWCHA bits 0/1 and 4/5), first to 9, 60-frame serve; the auto-demo tracks the ball after 120 idle frames. Captures: `serve.png` (2 s), `rally.png` (6 s), `game-over.png` (12 s), title `Stella 7.0: "69-pong"`, no cursor. The Part 10 index is rebuilt to the Part 7/8/9 format (PF-09). Red baseline confirmed: no `lessons/part10-capstones/69-pong`, no `docs/public/images/lesson69`, no Part 10 69 ROMs, the Part 10 index is intro-only, the document is the `🔒 Coming Soon` stub, sidebar `config.ts:164`, `verify.sh --no-docs` green at `771ab74`. No implementation logic read (AR-2).

**Session B record** (implementation, 2026-11-07 21:48): `69-pong.asm` (4,096) with the 89-byte row table at `$80-$D8`, the custom one-digit-per-player score, the two-player input, the 5-zone angle table, the serve/game-over states, and the auto-demo; three 4,096-byte solutions (CPU opponent, spin/speed, best-of-three); the Part 10 index rebuilt (row 69 ✅); three captures. The critical review fix was the range clamp after the move (all four sources) plus the `ClampPaddle` row-table safety net; the majors were the four-hit rally list, the TypeScript P0_X/P1_X, the ex3 stack hint, and the Lesson 39 prerequisite.

**Session C record** (verify + evidence, 2026-11-07 22:30): `bash scripts/verify.sh` PASSED (256 sources, no drift, docs build); four ROMs 4,096 and byte-identical; Full Source verbatim (1,110 source / 1,958 doc lines); `npm run roms` 256. Frame: `StartFrame` `$F071` 259/3, `VblankStart` `$F07F` 0/5, `BodyStart` `$F0CF` 37/5, `ScoreDone` `$F454` 46/11, `PositionDone` `$F12A` 51/3, `OverscanStart` `$F155` 229/6. State: `P0YRead`/`P1YRead` A=$5A, `BallXRead` A=$50, `BallYRead` A=$5A; `PaddleHit` 89/145/200/255 A=0/1/0/1; `ScoreRight` A=1..9 at 319..631; `GameStateRead` A=0->1 at 632; `ServeStart` A=$FE at 60, 320, 359, 398, 437; `RowTableWrite` A=$00. Captures: serve/rally/game-over 1010×807, titles `Stella 7.0: "69-pong"`, no cursor; scores 00/01/09; paddles at TIA 16/136. Clamp scratch tests: 9->8, 147->148, 200->148; row index max $D5. Site: index row 69 ✅, rows 70-72 Coming Soon; prev 68/next 70; sidebar `config.ts:164`; README row 10 unchanged. Reviews (AR-5): atari2600-reviewer — 1 critical (odd-Y clamp) + 1 major (rally list) + 8 minor, then no critical/major; curriculum-auditor — 3 major (TypeScript, ex3 stack, Lesson 39) + 9 minor, then no critical/major. All fixed; final 0 critical, 0 major open. Lesson 69 is complete.

**Deliverables**:
- [x] `69-pong.asm` (4,096) + `exercise-01/02/03-solution.asm` (4,096 each).
- [x] The 89-byte row table, the custom one-digit score, the two-player input, the auto-demo.
- [x] `docs/part10-capstones/69-pong.md` (six-section template, Full Source verbatim, 3 images,
  1 player, three exercises with solutions).
- [x] Part 10 index rebuilt to the Part 7/8/9 format; row 69 ✅; prev 68 / next 70; sidebar; README
  unchanged.
- [x] `verify.sh` green; both reviews 0 critical/major.

**Verify**: `bash scripts/verify.sh`

---

## Phase 2: Lesson 70 — Capstone 2: Breakout

> **Phase baseline tree**: the Lesson 69 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part10-capstones/70-breakout/` (main + 3 solutions) ·
> `docs/part10-capstones/70-breakout.md` · `docs/part10-capstones/index.md` (row 70) ·
> `docs/public/roms/part10-capstones/70-breakout/` · `docs/public/images/lesson70/` (3 captures) ·
> `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the brick map, the PF table, the collision math, and the dual-zone ball
> are the lesson's correctness core

### Step 2.1: Lesson 70 — Capstone 2: Breakout

**Reference**: [03 §Lesson 70](03-lesson-specs.md) · AR-14–AR-16, AR-24
**Objective**: ship the complete Breakout, the three solutions, and the document.

- [x] 2.1.1 Lesson 70 — Capstone 2: Breakout: Session A freezes ST-70.1–ST-70.8 (red baseline),
  Session B implements the brick field, the collision math, the levels, the three solutions, and
  the document, Session C verifies to green and hardens; commit via the `git-commit` skill in push
  mode — `feat(lesson70): Capstone 2 — Breakout` ✅ (completed: 2026-11-08 01:20)

**Session A record** (freeze + red baseline, 2026-11-07 22:46): ST-70.1–ST-70.8 re-affirmed against [03](03-lesson-specs.md) §Lesson 70. Design pins: the doc title is the curriculum/stub title **"Lesson 70: Capstone 2 — Breakout"**; the main ROM is `70-breakout.asm` (4,096) with three 4,096-byte solutions. The screen is **9 score + 1 blank + 5 positioner + 48 brick + 128 play + 1 blank = 192**; the score library draws the nine score lines, then P0 and the ball are repositioned. The brick field is 6 rows × 8 lines; each row is 6 unique bricks (8 px each, 4-px gap) mirrored to 12 by reflect mode; the PF bytes come from a **64-entry × 3-byte `BrickPF` table** keyed by the 6-bit row mask. The play area is 32 rows × 4 lines driven by a **32-byte `PlayRowTable`** at `$D8-$F7` (bit 0 P0 paddle, bit 1 ball); the brick zone's ball uses a **12-byte `BrickRowTable`** at `$86-$91` (bit 0 ball). RAM: `$80-$85` BrickMap, `$86-$91` BrickRowTable, `$92-$9F` 14 game variables, `$A0-$D7` the score library, `$D8-$F7` PlayRowTable, `$F8-$FF` stack. The brick collision is CXBLPF bit 7: row `(BallY-15)/8`, unique column `(BallX+2-8)/12` on the left and `5-((X-80)/12)` on the right. Lives 3; a miss at BallY>190; levels when all 36 unique bricks clear; three patterns. Captures: `bricks-start.png` (2 s), `bricks-broken.png` (6 s), `level-two.png` (10 s), title `Stella 7.0: "70-breakout"`, no cursor. The Part 10 index row 70 flips in the lesson commit. Red baseline confirmed: no `lessons/part10-capstones/70-breakout`, no `docs/public/images/lesson70`, no Part 10 70 ROMs, index row 70 Coming Soon, sidebar `config.ts:165`, `verify.sh --no-docs` green at `43fb603`. The 03 spec's Lesson 63 references were corrected to Lesson 39 (the scoreboard and score library). No implementation logic read (AR-2).

**Session B record** (implementation, 2026-11-07 23:43): `70-breakout.asm` (4,096) with the 9-line score band, the 48-line brick field (6 rows x 8 lines, 6 unique bricks mirrored to 12), the 64x3 `BrickPF` table, the 32-byte play row table, the 12-byte brick ball table, the score library + reposition, three lives, three patterns, and the auto-demo; three 4,096-byte solutions (multi-hit bricks, level progression, angle/power-up); three captures. The critical review fix was the PF2 bit order; the major was the positioner overrun; the minors were the alignment, timers, comments, and doc precision.

**Session C record** (verify + evidence, 2026-11-08 01:20): `bash scripts/verify.sh` PASSED (260 sources, no drift, docs build); four ROMs 4,096 and byte-identical; Full Source exact (1,434 source / 2,190 doc lines); `npm run roms` 260. Frame: `StartFrame` `$F1B9` 259/3, `VblankStart` `$F1C7` 0/5, `BodyStart` `$F255` 37/5, `ScoreDone` `$F258` 46/5, `BrickStart` `$F298` 51/2, `PlayStart` `$F31A` 99/19, `OverscanStart` `$F388` 229/2; 259/3, 51/2, 99/19, 229/2 at all 12 paddle/ball X extremes. State: `BrickHit` A=5 at 118/236/354; `BrickClear` A=$37/$17/$15; `ScoreAdd` A=1/2/3; `LevelStart` A=1 at 481 (demo) and 1261 (post-restart); `LifeLost` A=2/1/0 at 182/363/660. Captures: bricks-start (000000, 72 bricks), bricks-broken (000002, 2 unique bricks/four visible halves), level-two (000004, the diamond 4/8/12/12/8/4), 1010x807, titles `Stella 7.0: "70-breakout"`, no cursor. Site: index row 70 Done, rows 71-72 Coming Soon; prev 69/next 71; sidebar `config.ts:165`; README row 10 unchanged. Reviews (AR-5): atari2600-reviewer — 1 critical (PF2) + 1 major (positioner) + 11 minor, then no critical/major; curriculum-auditor — 1 major (disclosure) + 13 minor, then no critical/major. All fixed; final 0 critical, 0 major open. Lesson 70 is complete.

**Deliverables**:
- [x] `70-breakout.asm` (4,096) + `exercise-01/02/03-solution.asm` (4,096 each).
- [x] The brick map (6 bytes), the 64×3 PF table, the dual-zone ball, the score library, three
  levels, three lives, the auto-demo.
- [x] `docs/part10-capstones/70-breakout.md` (six-section template, Full Source verbatim, 3 images,
  1 player, three exercises with solutions).
- [x] Index row 70 ✅; prev 69 / next 71; sidebar; README unchanged.
- [x] `verify.sh` green; both reviews 0 critical/major.

**Verify**: `bash scripts/verify.sh`

---

## Phase 3: Lesson 71 — Capstone 3: Maze Explorer

> **Phase baseline tree**: the Lesson 70 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part10-capstones/71-maze-explorer/` (main + 3 solutions +
> generator + spec + include) · `docs/part10-capstones/71-maze-explorer.md` ·
> `docs/part10-capstones/index.md` (row 71) · `docs/public/roms/part10-capstones/71-maze-explorer/` ·
> `docs/public/images/lesson71/` (3 captures) · `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the mirror transform, the generator include, the enemy AI, and the
> row-table kernel must agree on every cell

### Step 3.1: Lesson 71 — Capstone 3: Maze Explorer

**Reference**: [03 §Lesson 71](03-lesson-specs.md) · AR-17–AR-21, AR-24, AR-29
**Objective**: ship the generated mirror maze, the three solutions, and the document.

- [x] 3.1.1 Lesson 71 — Capstone 3: Maze Explorer: Session A freezes ST-71.1–ST-71.9 (red
  baseline), Session B implements the generator, the mirror maze, the AI, the keys/win/lose, the
  three solutions, and the document, Session C verifies to green and hardens; commit via the
  `git-commit` skill in push mode — `feat(lesson71): Capstone 3 — Maze Explorer` ✅ (completed: 2026-11-08 04:37)

**Session A record** (freeze + red baseline, 2026-11-08 01:53; corrected at execution, 2026-11-08 04:30): ST-71.1–ST-71.9 re-affirmed against [03](03-lesson-specs.md) §Lesson 71. Design pins: the doc title is the curriculum/stub title **"Lesson 71: Capstone 3 — Maze Explorer"**; the main ROM is `71-maze-explorer.asm` (4,096) with three 4,096-byte solutions; the **mirror maze** is 10 unique columns × 11 rows (each cell 8×16 px, 2 chunks), drawn in reflect mode so the screen shows 20×11 cells. The screen is **16 status + 176 maze = 192**; the status band's 8 lines show three key slots (unique slots at X=16/40/64; an empty slot is its left 4-px chunk, a collected key adds the right chunk; the reflect mirrors are at 140/116/92 empty and 136/112/88 full) and the other 8 lines carry the setup; the four positioners run in VBLANK, then one HMOVE. The maze PF rows are **11×3 bytes** (20 chunks, reflect); the **44-byte `ObjRowTable`** at `$80-$AB` carries four bits per 4-line row (player, enemy1, enemy2, key); the game variables are `$AC-$C7` (28 bytes); `$C8-$DD` scratch; `$DE-$F7` free; `$F8-$FF` stack. The player is an 8-pixel cell drawn as a 4-pixel gold bar (P0 `$3C`); P1 is red, M0 gold, the ball is the 8×8 key and blinks. The **generator** `lesson71-generate.py` (Python 3, no deps) uses `--spec maze-spec.txt --out maze-data.inc --check`; the spec is `seed 20261010`, `width 10`, `height 11`, `keys 3`, `enemies 2`; it builds a perfect maze, opens the mirror seam at rows 4/6, places 3 keys in dead ends and 2 enemies at `(0,0)`/`(18,10)`, and emits `MazePF` (11×3), `MazeWalls` (11×2), `KeyCells` (3×2), `EnemyCells` (2×2), `DemoPath`/`DemoSteps`, and the constants. The player starts at `(0,10)`; the mirror transform is `col < 10 ? col : 19-col`; the enemies move every 8 frames toward the player (and stay when already on the player's cell); the ball is the current key; 3 keys wins, an enemy in the player's cell loses (also after the player's own move); fire restarts. Captures: `maze-start.png` (2 s), `maze-key.png` (6 s), `maze-win.png` (10 s), title `Stella 7.0: "71-maze-explorer"`, no cursor. Red baseline confirmed: no `lessons/part10-capstones/71-maze-explorer`, no `docs/public/images/lesson71`, no Part 10 71 ROMs, index row 71 Coming Soon, sidebar `config.ts:166`, `verify.sh --no-docs` green at `7039fa2`. No implementation logic read (AR-2).

**Session B record** (implementation, 2026-11-08 02:25): `71-maze-explorer.asm` (4,096) with the generated mirror maze (10 unique columns/20 visible), the 44-byte object row table, the PF rows, the four positioners in VBLANK, the two chase enemies, the three keys, the win/lose, and the scripted demo; three 4,096-byte solutions (fog, smarter enemies, timer/bonus); `lesson71-generate.py`, `maze-spec.txt`, `maze-data.inc`; three captures. The review fixes were the lose rule, the ex3 win-PF timing, the P1 VDELP1 row offset, the cycle ledger, the alignment, the slot mirrors, the move cadence, the generator phase/validation, and the doc precision.

**Session C record** (verify + evidence, 2026-11-08 04:37): `bash scripts/verify.sh` PASSED (264 sources, no drift, docs build); four ROMs 4,096 and byte-identical; Full Source exact (1,401 source / 2,296 doc lines); `npm run roms` 264. Generator: `--check` exit 0; bad width 0 exits 1 (`spec:2`); tampered include exits 1; the host-side maze is 61 open unique cells/60 edges, perfect; seam rows 4/6; keys (4,10)/(19,8)/(11,0); enemies (0,0)/(18,10); PF/wall rows 11/11 agree. Frame: `StartFrame` `$F04E` 259/3, `VblankStart` `$F05C` 0/5, `BodyStart` `$F0D4` 37/5, `MazeRowStart` `$F13A` 53/2, `OverscanStart` `$F22E` 229/7; ex3 play and win both 259/3, 53/2, 229/7. State: `PlayerCell` 2/10 -> 1/10 -> 2/10 -> 2/9; `WallRead` $F7/$00/$10; `KeyGet` A=1/2/3 at 220/365/445; `EnemyStep` A=0/1 every 8 frames; `GameState` 1 from 446; the lose on a scratch data-patched ROM A=2 at frame 9 (enemy on the player's cell) and frame 2 (player walks in). Captures: maze-start/maze-key/maze-win 1010x807, titles `Stella 7.0: "71-maze-explorer"`, no cursor; the key capture shows one slot pair full, the win is green with six full slots. Site: index row 71 Done, row 72 Coming Soon; prev 70/next 72; sidebar `config.ts:166`; README row 10 unchanged. Reviews (AR-5): atari2600-reviewer — 2 major (lose, ex3 timing) + 10 minor, then 1 major (ex3 win frame) + 8 minor, then no critical/major; curriculum-auditor — 12 minor (P1 offset etc.), then no critical/major. All fixed; final 0 critical, 0 major open. Lesson 71 is complete.

**Deliverables**:
- [x] `71-maze-explorer.asm` (4,096) + `exercise-01/02/03-solution.asm` (4,096 each).
- [x] `lesson71-generate.py` with `--check`; `maze-spec.txt`; `maze-data.inc`.
- [x] `docs/part10-capstones/71-maze-explorer.md` (six-section template, Full Source verbatim,
  3 images, 1 player, three exercises with solutions).
- [x] Index row 71 ✅; prev 70 / next 72; sidebar; README unchanged.
- [x] `verify.sh` green; both reviews 0 critical/major.

**Verify**: `bash scripts/verify.sh`

---

## Phase 4: Lesson 72 — Capstone 4: Your Own Game

> **Phase baseline tree**: the Lesson 71 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part10-capstones/72-your-game/demo-72.asm` ·
> `docs/part10-capstones/72-your-game.md` · `docs/part10-capstones/index.md` (row 72) ·
> `docs/public/roms/part10-capstones/72-your-game/` · `docs/public/images/lesson72/` (2 captures) ·
> `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: medium-high — the skeleton must be complete and runnable, the templates must be
> usable, and the doc must not become a fifth game

### Step 4.1: Lesson 72 — Capstone 4: Your Own Game

**Reference**: [03 §Lesson 72](03-lesson-specs.md) · AR-22, AR-23, AR-24
**Objective**: ship the skeleton mini-game, the production templates, the design exercises, and
the document.

- [ ] 4.1.1 Lesson 72 — Capstone 4: Your Own Game: Session A freezes ST-72.1–ST-72.5 (red
  baseline), Session B implements `demo-72.asm`, the GDD/RAM/screen/4K/milestone templates, the
  three design exercises, and the document, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson72): Capstone 4 — Your Own Game`

**Session A record**:

**Session B record**:

**Session C record**:

**Deliverables**:
- [ ] `demo-72.asm` (4,096) — the skeleton mini-game with the three `YOUR GAME` sections.
- [ ] `docs/part10-capstones/72-your-game.md` (six-section template, Full Source verbatim, 2
  images, 1 player, the GDD/RAM/screen/4K/milestone templates, three design exercises answered).
- [ ] Index row 72 ✅; prev 71 / next Part 11; sidebar; README unchanged.
- [ ] `verify.sh` green; both reviews 0 critical/major.

**Verify**: `bash scripts/verify.sh`

---

## Phase 5: Part 10 Completion Gate

> **Phase baseline tree**: the Lesson 72 commit (clean tree at gate start)
> **Expected modifications**: `codeops/features/curriculum/plans/part10-capstones/00-index.md`,
> `01-requirements.md`, `02-current-state.md`, `05-findings.md`, `99-execution-plan.md`,
> `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md`,
> `codeops/features/curriculum/requirements/RD-10-part10-capstones.md`
> **Reasoning**: medium — the gate is bookkeeping and a full re-check; the lesson content is frozen

### Step 5.1: Part 10 completion gate (a gate, not a fifth lesson)

- [ ] 5.1.1 Part 10 completion gate: 13 ACME sources/ROMs, 4 docs, 11 screenshots,
  `npm run roms` 265, 266 total `.bin`, index 69–72 ✅, RD-10 Done, feature roadmap 10/11,
  portfolio 10 plans, all completion criteria ticked, final `verify.sh` green; commit via the
  `git-commit` skill in push mode — `docs(curriculum): complete Part 10 (lessons 69-72)`

**Completion gate record**:

---

## Dependencies

```
Plan + preflight
      ↓
Lesson 69 (Pong / row table)
      ↓
Lesson 70 (Breakout / bricks)
      ↓
Lesson 71 (Maze / generator)
      ↓
Lesson 72 (skeleton / templates)
      ↓
Part 10 completion gate
```

---

## Completion Criteria

- [ ] All four phases marked `[x]` with Session A/C records.
- [ ] 13 ACME sources/ROMs (4 + 4 + 4 + 1), all 4,096 bytes.
- [ ] 4 documents, 11 screenshots (3 + 3 + 3 + 2).
- [ ] Lesson 69: row table, custom score, two-player input, auto-demo, three solutions.
- [ ] Lesson 70: brick map, PF table, dual-zone ball, lives/levels, three solutions.
- [ ] Lesson 71: generator `--check`, mirror maze, AI, keys/win/lose, three solutions.
- [ ] Lesson 72: skeleton mini-game, GDD/RAM/screen/4K/milestone templates, three exercises.
- [ ] Part 10 index rows 69–72 all ✅ Complete.
- [ ] `bash scripts/verify.sh` green at the final commit (265 ACME sources).
- [ ] Both specialists report no critical/major open for every lesson.
- [ ] No dead code, no unused symbols/tables; security N/A (static content, no input).
- [ ] The post-completion re-analysis is recorded.
- [ ] RD-10 Done; feature roadmap 10/11 RDs; portfolio 10 plans done.

## Post-Completion Analysis

_To be filled at the gate._
