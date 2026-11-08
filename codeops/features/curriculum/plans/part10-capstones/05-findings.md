# Findings Ledger: Part 10 — Capstone Projects (Lessons 69–72)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Lesson 71 complete after three rounds — 0 critical, 0 major open. Lesson 72 pending.
> **Rule**: every reviewer finding is recorded with its severity, the lesson, the evidence, and
> the resolution. A lesson is not done while a critical/major is open. The plan-level preflight
> findings live in [00-preflight-report.md](00-preflight-report.md); this ledger is for the
> per-phase reviews.

## Summary

| Lesson | Critical | Major | Minor | Open critical/major |
| --- | --- | --- | --- | --- |
| 69 | 1 | 4 | 12 | 0 |
| 70 | 1 | 2 | 20 | 0 |
| 71 | 0 | 3 | 20 | 0 |
| 72 | 0 | 0 | 0 | 0 |

## Lesson 69 — Pong

**Round 1** (atari2600-reviewer: 1 critical + 1 major + 8 minor; curriculum-auditor: 3 major + 9 minor):
- **SR-001 (critical, reviewer):** the manual clamp used equality only (`CMP #8; BEQ` / `CMP #148; BEQ`). The auto-demo makes P0Y odd; from 9 an up step runs 7, 5, 3, 1, `$FF`, and the row-table build then writes past `$D8` into the variables and the stack return address. Fixed with a range clamp after the move in all four sources plus a `ClampPaddle` safety net before the row-table build; scratch tests confirm 9->8, 147->148, and 200->148, with the P0 row index never past `$D5`.
- **SR-002 (major, reviewer):** the doc's "opening rally" listed two hits (89, 145); the real rally has four (89, 145, 200, 255). Fixed everywhere; the left misses after 255 and the first point is 319.
- **SR-006 / auditor SR-01 (major):** the TypeScript block used `P1_TOP = 16` and `BallX = P1_TOP - 4 = 12`; the right paddle is at X=136. Fixed with `P0_X=16`, `P1_X=136`, `BALL_TOP/BOTTOM`.
- **Auditor SR-02 (major):** the ex3 stack hint said "move the stack to `$F3-$FF`"; `TXS #$F3` would put pushes on `$F2/$F1` (the match bytes). Reworded to keep SP=`$FF` and reserve `$F3-$FF`; the source map is `$F1/$F2` match bytes, `$F3-$FF` stack.
- **Auditor SR-03 (major):** the score library is Lesson 39, not Lesson 63. Fixed in the doc and the 03 spec.
- Minors fixed: the muted-player note, the per-solution build/run lines, the first-row store cycles (8/14/20), the last-row cycles (8), `ServeCount` pre-decrement, the ex3 `PrevFire` bits, the deadline arithmetic (P0 X=16 -> 28; ball X=4 -> 24.0), the "27 cycles" wording (the VBLANK build is ~1,500), the free-RAM count (57/33), "any up/down", the first serve fixed left, the 6 s caption (~5.9 s), the Y=164 bottom bounce disclosed as code-derived, the play-area-relative Y convention, the 2-line vertical quantization, the timer line counts, the capture-method disclosure, and the plan spec's INPT4/auto-demo/angle-table drift.

**Round 2** (no critical/major): the doc's checkpoint table had stale addresses (`ScoreDone $F430` etc.); re-derived from the current symbol file (`$F454`, `$F384`, `$F3A6`, `$F2F2`, `$F369`, `$F431`, `$F2C4`). The `P0 at X=8` sentence and the `ballX 8..152` comment were fixed; the "can never touch" claim is now "cannot touch after the opening rally"; the ex3 stack banner says `$F3-$FF`; the 6 s captions say "about 6 s (just before the second point)". Final 0 critical, 0 major open.

## Lesson 70 — Breakout

**Round 1** (atari2600-reviewer: 1 critical + 1 major + 11 minor; curriculum-auditor: 1 major + 13 minor):
- **SR-001 (critical, reviewer):** the `BrickPF2` column was bit-reversed (PF2 bit 0 = chunk 12, not bit 7). The last three unique bricks and their mirrors rendered at the wrong X, and the collision geometry disagreed with the picture. Fixed with the TIA order (`$04` -> PF1 `$01` + PF2 `$01`; `$02` -> PF2 `$0C`; `$01` -> PF2 `$60`; full row `$3F` -> `$C0/$6D/$6D`) in all four sources and the doc; the three main captures were re-taken.
- **SR-002 (major, reviewer):** the visible positioners overran the line for `PaddleX >= 102` / `BallX >= 146`; the frame grew to 263/264 and the zones shifted. Fixed by positioning the ball in VBLANK before `ScoreSetup` (the score's HMOVE applies it) and giving the P0 positioner a fixed-length 42-cycle fill; the frame is 259/3, 51/2, 99/19, 229/2 at all 12 paddle/ball extremes.
- **Auditor SR-01 (major):** the game-over restart and natural level clear were claimed as observed; the restart is now observed (main `LevelStart` 1261; ex2 1021) and the natural `BricksLeft=0` clear is disclosed as code-verified.
- Minors fixed: the `!align` 64-byte columns, the ex3 power timer, `NUSIZ0=5`, the ex2/ex3 game-over/aim counters, the play area 32x4 (row 0 four lines), the technical prose (VX ±4, mirror arithmetic, ENABL line 5, speeds, 42-cycle burn), the ex2 banner preload, the ex1 6-byte table and bit-7 flag, the doc's level-display/patterns/.bin/TS/32-byte table wording, the planning references removed, the caption/alt text, the scratch-capture wording, and the disclosure.

**Round 2** (no critical/major): the PF2 table, the VBLANK ball positioner, the `!align`, and the timer splits are confirmed. The residual minor items (the mirror arithmetic, the WSYNC wording, the ball-in-VBLANK prose, the ex3 header demo references, the ex2/main comments, the RAM map `$94`, the TS clamp, the alt text, the `.asm` 4,096 claims, the ex2/ex3 effect clears, and plan 03:146) were fixed in the final polish. Final 0 critical, 0 major open.

## Lesson 71 — Maze Explorer

**Round 1** (atari2600-reviewer: 2 major + 10 minor; curriculum-auditor: 12 minor, including a possible P1 vertical offset):
- **SR-001 (major, reviewer/auditor):** the lose rule was not enforced on the player's own move. `EnemyOne` stepped off the player's cell when DeltaX=DeltaY=0, so a player walking into an enemy survived. Fixed by returning immediately for a zero delta, calling `CheckCollision` after a player move, and aligning the generator's `_simulate`. Scratch tests: enemy on the player's cell -> A=2 at frame 9; player walks into the enemy -> A=2 at frame 2.
- **SR-002 (major, reviewer):** exercise 3's per-line `GameState` test pushed the PF/ENAM0 stores past their deadlines (6-px blue tabs/stubs). Fixed by moving the win PF decision off the scanline; the 2 s bar is clean and the 7.5 s screen is solid green.
- **SR-003 (major, rendering):** the red P1 enemy was one object row (4 lines) low. Root cause: `VDELP1` lost the second setup graphics store; fixed by clearing VDELP1, writing P1 immediately on the object row's first line, and unrolling the four object rows. The 2 s image now has the red box at picture lines 16-31 (row 0) and the player at 176-191 (row 10).
- Minors fixed: the cycle ledger (zero-page 3-cycle stores; PF0 8, P1 14, ENAM0 20, PF1 27, PF2 34), `!align 255`, the empty-slot mirrors 140/116/92 vs full 136/112/88, the 8-frame move cadence, the generator's demo/enemy phase and `--report` 220/365/445, the generator validation (duplicate key/enemy, key at start), the `COLUP0` gold comments, the dead `Temp`/`MAZE_ROW_LINES`/`OBJ_ROW_LINES`, the exercise maps, the ENAM0 deadline 22.7, the 4-px player-bar wording, the prerequisite order, the TS BFS relabel, the lose provenance, and the exercise state-log wording.

**Round 2** (no critical; 1 new major): exercise 3's win override on setup line 9 overran the line, growing the frame to 263. Fixed by moving the `$FF` override to the idle line 10; the play and win states both measure 259/3, 53/2, 229/7. The remaining minors (the blue off-phase, the host-side PF/wall check, the dead line-15 `LDX`, the exercise allocation headings, the TS `enemyStep` signs, the capture captions, the "one line shorter" wording, and the 8-takeaway cap) were fixed.

**Round 3** (no critical/major): the win frame, the PF/wall report, and the doc claims are confirmed. Final 0 critical, 0 major open.

## Lesson 72 — Your Own Game

_No phase findings yet._
