# Ambiguity Register: Part 10 — Capstone Projects (Lessons 69–72)

> **Status**: ✅ GATE PASSED — all plan-local items resolved
> **Created**: 2026-11-07
> **Authority**: the user directive to plan, preflight, and execute RD-10; RD-10's acceptance
> criteria; and the Part 1–9 process precedent. The global curriculum register
> (`../../requirements/00-ambiguity-register.md`) delegates implementation mechanisms inside the
> frozen curriculum.
> **Scope**: RD-10 only; lessons 69–72.

| # | Category | Ambiguity / Gap | Options Presented | Decision | Status |
|---|----------|-----------------|-------------------|----------|--------|
| 1 | Scope | Which lessons belong to this plan? | All remaining lessons / Part 10 only / one lesson | **Part 10 only: lessons 69–72, strictly in curriculum order.** The 78-lesson structure and the four lesson titles are frozen. | ✅ Resolved |
| 2 | Process | How is the work phased? | One phase per lesson + gate / batched phases | **4 lesson phases, one per lesson, plus a Part 10 completion gate.** Each phase uses Sessions A/B/C and one atomic commit. | ✅ Resolved |
| 3 | Artifacts | Which lessons are buildable? | Everything buildable / labs for 69–71, theory for 72 | **Lessons 69–71 are buildable capstones: a main source + three `exercise-NN-solution.asm` each. Lesson 72 is the design/production lesson: `demo-72.asm` (the skeleton game) plus three design exercises answered in the doc, no solution files.** RD-10 AC 1 allows `demo-NN.asm` for theory lessons. | ✅ Resolved |
| 4 | Verify | What is the gate? | `verify.sh` / lighter check | **`bash scripts/verify.sh` before every lesson commit and at Part 10 completion.** | ✅ Resolved |
| 5 | Reviews | Who gates a lesson? | One reviewer / both specialists | **Both `atari2600-reviewer` and `curriculum-auditor` must report no critical/major open.** | ✅ Resolved |
| 6 | Claims | What accuracy standard applies? | Observed/documented/derived / free prose | **Observed/documented/derived; `include/vcs.asm` is ground truth; every kernel ledger and state log is measured in Stella; the maze generator's output is committed and `--check`-verified.** | ✅ Resolved |
| 7 | Screenshots | How are captures produced? | Existing script / browser capture | **`scripts/capture-screenshot.sh` from the committed lesson ROM, pointer parked, no cursor, title bar visible. Lesson 69: 3; Lesson 70: 3; Lesson 71: 3; Lesson 72: 2. Total 11.** | ✅ Resolved |
| 8 | ROM sizes | Do all lessons stay at 4,096 bytes? | 4K only / mapper-correct | **All Part 10 ROMs are 4,096 bytes. No mapper, no bankswitching.** | ✅ Resolved |
| 9 | Part index | The Part 10 index is intro-only. | Leave it / rebuild | **Lesson 69 rebuilds the Part 10 index to the Part 7/8/9 format (big-idea intro, a 4-row lesson table, What You'll Learn) and flips row 69.** | ✅ Resolved |
| 10 | Pong score | The score library uses P0/P1 and $A0-$D7; Pong needs P0/P1 for the paddles and the RAM for a row table. | Score library / custom score / playfield score | **A custom one-digit-per-player score: P0 draws the left digit and P1 the right digit in an 8-line band at the top, then both are repositioned to the paddles.** The score is 0–9 per side; first to 9 wins. This frees $A0-$D7 for the row table. | ✅ Resolved |
| 11 | Pong kernel | A one-line kernel with three object range tests writes GRP0 at cycle ~49, after P0's pixel time at X=16; the left paddle is invisible. | One-line / two-line / four-line | **A precomputed 89-byte row table (bit 0 = P0, bit 1 = P1, bit 2 = ball) + a two-line kernel.** The table is built in VBLANK; the kernel reads one byte per row and stores the three objects at the start of the row's first line. The preflight measured 259/37/229 with three objects. | ✅ Resolved |
| 12 | Pong input | Two-player or CPU? | Two-player only / CPU only / both | **Two-player out of the box: SWCHA bits 0/1 move P0 up/down, bits 4/5 move P1. An auto-demo tracks the ball for both paddles when no direction is held, so the captures are deterministic.** Exercise 1 adds the CPU opponent. | ✅ Resolved |
| 13 | Pong game over | What ends a game? | First to 9 / timed / lives | **First to 9. The winning digit flashes; fire or SELECT starts a new game; the serve waits 60 frames.** | ✅ Resolved |
| 14 | Breakout kernel | The brick field is playfield; the paddle/ball are sprites; the ball must be visible in both zones. | One zone / score+brick+play zones | **Three zones: a 9-line score band, a 48-line brick field (6 rows × 8 lines), and a 128-line play area (32 rows × 4 lines) + 1 blank line.** The ball is drawn in the brick zone with a per-line row compare and in the play zone from the 32-byte row table; the score library uses P0/P1 at the top and P0 is repositioned to the paddle after the score. | ✅ Resolved |
| 15 | Breakout bricks | How many bricks and how stored? | 6×6 unique / 8×6 / 12×6 | **6 rows × 6 unique bricks per half, mirrored to 12 visible per row by reflect mode.** The brick map is 6 bytes (6 bits per row); a 64-entry × 3-byte PF table (192 bytes ROM) turns a row mask into PF0/PF1/PF2. Each brick is 8 px (2 chunks) with a 4-px gap. | ✅ Resolved |
| 16 | Breakout progression | Levels and lives? | One level / three levels | **Three brick patterns, three lives, speed-up per level. Clear all 36 unique bricks (72 visible) to advance; after level 3 the game loops faster.** | ✅ Resolved |
| 17 | Maze representation | A 20×12 full-width maze needs a split playfield or a mirror. | Split playfield / repeat / mirror | **A mirror maze: 10 unique columns × 11 rows, each cell 8×16 px, drawn with reflect mode so the screen shows 20×11 cells.** The player and enemies use a mirrored column transform (`col < 10 ? col : 19 - col`). This teaches the reflect playfield and avoids a split-playfield kernel. | ✅ Resolved |
| 18 | Maze generator | Hand-authored maze or generated? | Hand draw / Python generator | **A first-party Python 3 generator (`lesson71-generate.py`) with a fixed seed, a recursive-backtracker maze on the 10×11 grid, validation, a `--check` drift gate, and a committed `maze-data.inc` (PF rows, wall map, key/enemy positions).** CI does not run Python. | ✅ Resolved |
| 19 | Maze objects | Which objects and display? | Players only / players+missiles+ball | **P0 = player, P1 and M0 = two enemies, the ball = the current key. The score band shows the three key icons as playfield blocks (no score library), leaving the RAM for the 44-byte object row table.** | ✅ Resolved |
| 20 | Maze kernel | How are the 16-line maze rows and the moving objects combined? | One-line / four-line | **A four-line object row table (44 rows × 4 lines = 176) inside 11 maze rows of 16 lines.** The maze PF bytes load once per 16-line row; the object row table is decoded every 4 lines. | ✅ Resolved |
| 21 | Maze win/lose | What are the goals? | Timed / keys / enemies | **Collect 3 keys (the ball respawns at the next key); an enemy in the player's cell loses; fire restarts. The key icons fill as keys are collected.** | ✅ Resolved |
| 22 | Lesson 72 | Theory lesson with a skeleton? | No ROM / a skeleton demo | **`demo-72.asm`: a 4,096-byte skeleton game with title/play/over states, P0 left/right, a falling item, the score library, the sound library, fire/restart, and clearly marked `YOUR GAME` sections.** Three design exercises are answered in the doc. | ✅ Resolved |
| 23 | Lesson 72 demo game | What does the skeleton do? | A blank template / a complete mini-game | **A complete mini-game ("star catcher"): a title screen, a 30-second play state where P0 catches falling items for points, a game-over state, sound, and restart.** The reader replaces the marked sections. | ✅ Resolved |
| 24 | RAM maps | Which bytes are safe? | Shared map / per lesson | **Per-lesson maps in the source header and the doc; no overlap with `$A0-$D7` where the score library is used, no data under the stack.** Lesson 69: row table $80-$D8, vars $D9-$F0, stack $F1-$FF. Lesson 70: brick map $80-$85, vars $86-$9F, score $A0-$D7, play table $D8-$F7, stack $F8-$FF. Lesson 71: row table $80-$AB, vars $AC-$D7, scratch $D8-$F7, stack $F8-$FF. Lesson 72: the score library $A0-$D7, vars $80-$9F, stack $F8-$FF. | ✅ Resolved |
| 25 | Frame | What frame do the lessons use? | 262 only / adaptive | **NTSC 262 = 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229 (the cycle varies with the kernel).** | ✅ Resolved |
| 26 | Evidence | What proves a claim? | Screenshot / state log + ledger | **State-log checkpoints + static ledgers + PIL pixel checks + the generator `--check`; the screenshot proves only the visual state.** | ✅ Resolved |
| 27 | Commits | How is work committed? | One per part / one per lesson | **The plan + preflight is its own commit; each lesson is one atomic `feat(lessonNN): <title>` commit pushed to `master`; the completion gate is a separate docs commit.** | ✅ Resolved |
| 28 | Completion | What is the Part 10 target? | Per lesson / part count | **13 ACME sources/ROMs (4+4+4+1), 4 documents, 11 screenshots, 265 `npm run roms` ROMs, 266 total `.bin` files (the existing bB reference included); RD-10 Done; feature roadmap 10/11; portfolio 10 plans.** | ✅ Resolved |
| 29 | Generator | Is the maze include rebuilt by CI? | Add Python to CI / commit only | **Commit only.** The generator has `--check`; CI never runs Python; the committed include is the build input. | ✅ Resolved |
| 30 | README | Does the curriculum listing change? | Update / unchanged | **README row 10 is already `Capstone Projects | 69–72`; it must not change. The sidebar entries already exist at `config.ts:164–167`.** | ✅ Resolved |
| 31 | Javatari | Does the player support the ROMs? | Assume / verify | **All Part 10 ROMs are plain 4K; Javatari's 4K path runs them. The bundle stays unmodified.** | ✅ Resolved |

## Resolution Notes

**AR-1 / AR-2.** RD-10 names lessons 69–72. The plan keeps the frozen curriculum and runs four
lesson phases plus a gate. The Part 9 process is reused: Session A freezes the lesson's ST cases
and records a red baseline; Session B implements; Session C verifies and hardens.

**AR-3.** RD-10 AC 1 explicitly allows `demo-NN.asm` for theory lessons. Lesson 72 is the
production/design lesson; its artifact is the skeleton demo and its exercises are design tasks
answered in the document. Lessons 69–71 are complete games with three solution files each.

**AR-10 / AR-11.** The preflight measured the one-line multi-object failure: with three range
tests, the GRP0 store lands at cycle ~49 and P0 at X=16 is invisible. The row-table two-line
kernel (89 bytes, one byte per row, three bits) measured `StartFrame` 259, `BodyStart` 37,
`OverscanStart` 229 with P0, P1, and the ball visible. That is the Pong kernel. The P0/P1 score
conflict was proven by the score library's fixed 56/64 positions: the score must be drawn first,
then the players repositioned. Pong's custom score avoids the conflict and frees the RAM.

**AR-14 / AR-15.** Breakout's ball must be visible in the brick field and the play area. The
brick zone draws PF rows from the brick map and checks the ball's 4-line row per line; the play
zone uses the 32-byte row table. The brick map is 6 bytes; the 64×3 PF table is 192 ROM bytes.

**AR-17 / AR-18 / AR-19 / AR-20.** The maze is a mirror maze (10 unique columns, 20 visible via
reflect). The generator emits the PF rows and the wall map; the four-line object row table fits
the 176-line maze. The key icons are playfield blocks, so the score library is not used.

**AR-22 / AR-23.** Lesson 72's skeleton is a complete mini-game, not a blank template: the
reader sees the full state machine, score, sound, input, and restart working, then replaces the
three marked sections. The doc's GDD/RAM/screen templates and the three design exercises turn the
skeleton into the reader's own project.

**AR-28.** The completion count is derived from the Part 9 count (252 ACME ROMs, 253 total `.bin`)
plus 13 ACME sources (`265`) and the existing bB reference (`266` total). The screenshots are
3+3+3+2 = 11.
