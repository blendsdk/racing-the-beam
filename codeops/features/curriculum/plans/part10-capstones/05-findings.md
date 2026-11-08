# Findings Ledger: Part 10 — Capstone Projects (Lessons 69–72)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Lesson 70 complete after round 2 — 0 critical, 0 major open. Lessons 71–72 pending.
> **Rule**: every reviewer finding is recorded with its severity, the lesson, the evidence, and
> the resolution. A lesson is not done while a critical/major is open. The plan-level preflight
> findings live in [00-preflight-report.md](00-preflight-report.md); this ledger is for the
> per-phase reviews.

## Summary

| Lesson | Critical | Major | Minor | Open critical/major |
| --- | --- | --- | --- | --- |
| 69 | 1 | 4 | 12 | 0 |
| 70 | 1 | 2 | 20 | 0 |
| 71 | 0 | 0 | 0 | 0 |
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

_No phase findings yet._

## Lesson 72 — Your Own Game

_No phase findings yet._
