# Execution Plan: Part 6 — Game Development (Lessons 38–47)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-05 14:46
> **Progress**: 4/10 tasks (40%)
> **CodeOps Artifact Schema**: 1

## Overview

Ten phases, one per lesson, strictly sequential — 39's score library is used by 40, 38's collision
read is used by 39/41/44/46, 41's state machine is used by 42/44, and 45's map is used by 46;
43 is the standalone randomness lesson (AR-1, AR-38). Every phase is one task run through the mandatory three-session ordering: Session A
freezes that lesson's specification cases, Session B implements the full artifact set, and Session
C verifies against the frozen cases and hardens under independent review (AR-2, AR-5).
`bash scripts/verify.sh` is the gate for every phase (AR-4). Logic claims carry the state-log +
static-ledger evidence of AR-6 and AR-28; every screenshot is pixel-checked against the monitor
geometry (AR-26).

**🚨 Update this document after EACH completed task!**

**Session record slots:** each task gets a `**Session A record**` paragraph after its task line
(freeze + red baseline + design pins) and a `**Session C record**` paragraph after the Session
sub-steps. The per-lesson findings are appended to [05-findings.md](05-findings.md); the plan-level
preflight findings live in [00-preflight-report.md](00-preflight-report.md). The plan is not
executable until the preflight report exists and the roadmap row reads `Plan Preflighted`. The
push mode is authorized by the user's directive to execute RD-06 and the Part 1–5 practice (AR-12).

---

## Implementation Phases

| Phase | Title | Tasks |
| ----- | ----- | ----- |
| 1 | Lesson 38 — Collision Detection | 1 |
| 2 | Lesson 39 — The Scoreboard | 1 |
| 3 | Lesson 40 — BCD Arithmetic | 1 |
| 4 | Lesson 41 — Game States | 1 |
| 5 | Lesson 42 — Difficulty and Progression | 1 |
| 6 | Lesson 43 — Random Numbers | 1 |
| 7 | Lesson 44 — AI & Enemy Behavior | 1 |
| 8 | Lesson 45 — Memory Management | 1 |
| 9 | Lesson 46 — Debugging | 1 |
| 10 | Lesson 47 — Development Tools & Workflow | 1 |

**Total: 10 tasks across 10 phases.**

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

## Phase 1: Lesson 38 — Collision Detection

> **Phase baseline tree**: c4263ab (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part6-game-dev/38-collision-detection/` (4 sources) ·
> `docs/part6-game-dev/38-collision-detection.md` · `docs/part6-game-dev/index.md` (rebuild + row
> 38) · `docs/public/roms/part6-game-dev/38-collision-detection/` · `docs/public/images/lesson38/`
> (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + `05-findings.md` + roadmaps
> **Reasoning**: high — the first game lesson reads the TIA collision latches; the read/clear order
> and the one-frame latency are under independent hardware review

### Step 1.1: Lesson 38 — Collision Detection

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 38 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 38 · AR-2, AR-3, AR-4, AR-6, AR-10,
AR-13, AR-26, AR-27, AR-28, AR-32
**Objective**: Deliver Lesson 38 end to end through the mandatory three sessions.

- [x] 1.1.1 Lesson 38 — Collision Detection: Session A freezes ST-38.1–ST-38.6 (red baseline),
  Session B implements the full artifact set (including the AR-10 index rebuild), Session C
  verifies to green and hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson38): Collision Detection` ✅ (completed: 2026-11-05 11:40)

**Session A record** (freeze + red baseline, 2026-11-05 09:55): ST-38.1–ST-38.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 38. Design pins: the standard 262-line frame; four 6-line bands (P0–P1, P0–ball, P0–playfield, M0–P1); a 15-chunk hit bar per half; P0 moves in both axes (clamp 8–144, 40–156), P1 sweeps 40–136 at Y=40, the ball is fixed at X=80/Y=100, M0 fires from P0; read the latches in VBLANK, build `LatchMask`, edge-detect into `NewBits`, increment `Hits`, then `CXCLR`; the auto-demo moves P0 and fires M0 every 90 frames; work-first kernel; one HMOVE. Evidence pins (AR-6): frame checkpoints; `ReadCX` A = `CXP0FB`; `CollMask` A = the full mask; `CollStep` A = the 0→1 edge; `CXClear`; `Hits`; `BodyStart` 37; `HmoveApply`/`HmoveDone`; the capture bands and bar. Red baseline confirmed: no `lessons/part6-game-dev/38-collision-detection`, no `docs/public/images/lesson38`, no Part 6 ROMs, the document is the `🔒 Coming Soon` stub, the Part 6 index is the minimal stub, sidebar entry exists (`config.ts:109`), `verify.sh` green at `c4263ab`. No implementation logic read (AR-2).


**Session C record** (verify + evidence, 2026-11-05 11:40): Preflight per `vcs-lesson-production` — the collision bit table, the one-frame latch latency, the edge detector, the 15-chunk bar, the PF2 bit order, and the one-HMOVE rule checked against `include/vcs.asm` and the TIA reference; ACME forms; no demo (AR-3: the collision lab is the visible picture). `bash scripts/verify.sh` green (implementation, review fixes, and re-captures); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F035` = (259, 3), `VblankStart` `$F043` = (0, 5), `BodyStart` `$F267` = (37, 5), `HmoveApply` `$F238` line 8 c56 (the WSYNC stall), `HmoveDone` `$F23A` line 9 c3 (the store executes at line 9 c0 in HBLANK), `OverscanStart` `$F394` = (229, 4). Logic: `ReadCX` `$F05A` A=$02 then $82; `CollMask` `$F07B` A=$20 (wall) and $10 (M0–P1 at frame 2936); `CollStep` `$F081` A=$00 held, $20 first wall, $10 M0–P1 at 2936; `CXClear` `$F0B4` line 1 c68; `Hits` `$F0A0` 1/2/3/4 at frames 2/343/439/713 and 12 at 2936. Captures from the committed ROM: `wall.png` band 2 green (x 25–984), 1 chunk per half (25–48/961–984), P0 X=8/Y≈126, P1 X=69/Y=40, ball X=80/Y=100, 16-px walls; `p1.png` band 0 red, 2 chunks per half (25–72/937–984), P0 X=80/Y=40, P1 X=81 (one visible pixel at X=88 under P0), ball X=80/Y=100; no cursor. The P0-at-156 check shows red only through visible 171 (no smear into the bar/bands); the Hits=15 check shows 15 contiguous chunks per half. Solutions: ex 1 — `CXP0FB` bit 6, the bar advances two chunks per ball contact; ex 2 — M1/`CXM1P` bit 7, M1–P0 at frame 588; ex 3 — no `CXCLR` at all, the mask only gains bits. Site (ST-38.6): the Part 6 index was rebuilt to the Part 1 format (row 38 ✅, rows 39–47 `🔒 Coming Soon`); the page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 37, next → 39; sidebar `config.ts:109`; README unchanged. Reviews (AR-5): the atari2600-reviewer round 1 — **1 critical, 2 major, 4 minor** (the P0 smear; PF2 reversed; ex2 `ENAM1`; M0 offset; right wall; doc wording; `CollStep`); round 2 — **0 critical, 0 major**, all confirmed, one documented minor (the missile enable's one-line offset). The curriculum-auditor round 1 — **1 major, 2 major, 4 minor** (the P0 smear; ex2 M1; the Lesson 29 ball calibration; `CollStep`; prerequisites; ex1 double chunks; ex3 fourth pair); round 2 — **0 critical, 0 major**, all confirmed with 3 text residuals fixed. Final state: **0 critical, 0 major open**. Lesson 38 is complete.


**Session sub-steps:**

1. **Session A — freeze the specification (red phase):** re-affirm ST-38.1–ST-38.6, the four
   bands, the hit bar, the read/clear order, and the auto-demo; record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author the main source and
   three solutions; rebuild the Part 6 index; write the document; assemble, run in Stella, and
   capture the two screenshots from the committed ROM; run `npm run roms`; run `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row with recorded evidence; run the two
   specialists on the phase diff; fix findings; re-run `verify.sh`; record the Session C evidence
   and the findings ledger rows.
4. **Commit:** `git-commit` skill in push mode with the `Ref:`/`Task:` trailers; update the
   roadmap row to Done only at Part 6 completion (AR-12).

---

## Phase 2: Lesson 39 — The Scoreboard

> **Phase baseline tree**: 96faf13 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part6-game-dev/39-scoreboard/` (4 sources) ·
> `include/score.asm` (new library) · `docs/part6-game-dev/39-scoreboard.md` ·
> `docs/part6-game-dev/index.md` (row 39) · `docs/public/roms/part6-game-dev/39-scoreboard/` ·
> `docs/public/images/lesson39/` (2 captures) · `README.md` (verify only) ·
> `99-execution-plan.md` + `05-findings.md` + roadmaps
> **Reasoning**: high — the 48-pixel Staugas kernel is cycle-tight; the score zone's line count
> and the digit carries are the phase's highest-risk code

### Step 2.1: Lesson 39 — The Scoreboard

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 39 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 39 · AR-2, AR-3, AR-4, AR-6, AR-7,
AR-10, AR-14, AR-15, AR-26, AR-27, AR-28, AR-31
**Objective**: Deliver Lesson 39 end to end, including `include/score.asm`.

- [x] 2.1.1 Lesson 39 — The Scoreboard: Session A freezes ST-39.1–ST-39.6 (red baseline), Session
  B implements the full artifact set including `include/score.asm`, Session C verifies to green
  and hardens; commit via the `git-commit` skill in push mode — `feat(lesson39): The Scoreboard` ✅ (completed: 2026-11-05 12:44)

**Session A record** (freeze + red baseline, 2026-11-05 11:50): ST-39.1–ST-39.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 39. Design pins: the 48-pixel Staugas kernel (P0/P1 three-copy close, P1 8 px right, VDEL cross-latch, 8 rows, bottom-up font); the 9-line score zone (line 0 setup/blank, rows 1–8, cleanup shares row 8) and the 183-line game zone (192 total); P0 X=56/P1 X=64; the score digits 000000 and `ScoreAddOne`; the target at visible 150–157, X=64–95; the 1-px ball at Y=150, X=24–136; `CXBLPF` bit 7 → `ScoreAddOne`, beep, respawn; the auto-sweep; `include/score.asm` with `ScoreDigits` $A0–$A5, scratch $A6–$A7, `ScoreBuf` $A8–$D7. Evidence pins (AR-6): frame checkpoints; `ScoreDigitWrite` (A=position, X=digit); `ScoreAdd` (A=the low digit); `BallHit` A=`CXBLPF`; `BodyStart` 37; `ScoreDraw`/`ScoreDrawRow`; `HmoveDone`; the capture score/target/ball. Red baseline confirmed: no `lessons/part6-game-dev/39-scoreboard`, no `include/score.asm`, no `docs/public/images/lesson39`, no Part 6 39 ROMs, the document is the `🔒 Coming Soon` stub, index row 39 is Coming Soon, sidebar entry exists (`config.ts:110`), `verify.sh` green at `96faf13`. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-11-05 12:44): Preflight per `vcs-lesson-production` — the Staugas kernel's cross-latch timing, the 8-byte columns, the decimal carry, the target/ball collision, and the 9+183 zone split checked against the prototype, `include/vcs.asm`, and the hardware reference; ACME forms; the library is the promised artifact. `bash scripts/verify.sh` green (implementation, review fixes, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F025` = (259, 3), `VblankStart` `$F033` = (0, 5), `BodyStart` `$F0EE` = (37, 5), `ScoreDraw` `$F20A` = (37, 11), `ScoreDrawRow` `$F215` = (37, 26) (the WSYNC stall; the store executes at 38/0), `HmoveApply` `$F1BE` line 4 c45, `HmoveDone` `$F1C0` line 5 c3, `OverscanStart` `$F11E` = (229, 4). Logic: `ScoreInit` `$F154` once; `ScoreDigitWrite` `$F1C1` A=00/01/02/05…; `ScoreAdd` `$F1F3` A=01/02/03/04 at frames 22/42/62/82 and A=00 then A=01 at frame 202 (000009→000010); `BallHit` `$F04E` A=$80 at 22/42/62/82. Captures from the committed ROM: `score-a.png` reads **000001** at x=367–642, y=110–130; `score-b.png` reads **000002**; the target is gold at x=409–600 (TIA 64–95), y=580–604; the ball is 1 px wide, 8 rows, at TIA 44/36, y=580–604; no cursor. Solutions: ex1 012345→012346; ex2 000000→000002; ex3 `    42`→`    43`. Site (ST-39.6): index row 39 ✅ (rows 38 ✅, 40–47 Coming Soon); the page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 38, next → 40; sidebar `config.ts:110`; README unchanged; `include/score.asm` sourced by all four. Reviews (AR-5): the atari2600-reviewer round 1 — **1 major, 3 minor** (the VDEL model; color clocks/spacing; duplicate headers; ex2 wording); round 2 — **0 major**, all confirmed, one comment-only residual fixed. The curriculum-auditor round 1 — **1 major, 7 minor** (the VDEL model; spacing; line mapping; unrecorded burst; ex1 calls; debugger state; plan wording/bookkeeping); round 2 — **0 major**, one library-comment residual and one §2-opening regression fixed. Final state: **0 critical, 0 major open**. Lesson 39 is complete.


**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-39.1–ST-39.6, the Staugas kernel, the
   score zone, the digit carry, and the target/ball layout; record the red baseline.
2. **Session B — implement:** preflight; author the library, the main source, and three
   solutions; write the document; assemble, run, and capture; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 3: Lesson 40 — BCD Arithmetic

> **Phase baseline tree**: 87d7350 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part6-game-dev/40-bcd-arithmetic/` (4 sources) ·
> `docs/part6-game-dev/40-bcd-arithmetic.md` · `docs/part6-game-dev/index.md` (row 40) ·
> `docs/public/roms/part6-game-dev/40-bcd-arithmetic/` · `docs/public/images/lesson40/` ·
> `README.md` (verify only) · `99-execution-plan.md` + `05-findings.md` + roadmaps
> **Reasoning**: high — decimal mode state leakage and multi-byte carry are classic 6502 bugs;
> every path must restore `CLD`

### Step 3.1: Lesson 40 — BCD Arithmetic

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 40 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 40 · AR-2, AR-3, AR-4, AR-6, AR-10,
AR-16, AR-26, AR-27, AR-28, AR-33
**Objective**: Deliver Lesson 40 end to end on the Lesson 39 score library.

- [x] 3.1.1 Lesson 40 — BCD Arithmetic: Session A freezes ST-40.1–ST-40.6 (red baseline), Session
  B implements the full artifact set, Session C verifies to green and hardens; commit via the
  `git-commit` skill in push mode — `feat(lesson40): BCD Arithmetic` ✅ (completed: 2026-11-05 13:38)

**Session A record** (freeze + red baseline, 2026-11-05 13:00): ST-40.1–ST-40.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 40. Design pins: the 3-byte BCD score (low/mid/high; low=digits 5/4); `BCDAdd` A=command selector 1/100 in the main (A=1 low+1, A=100 mid+1 carry high), ADD 10/SUB 1 as exercises; `SED`/`CLD` isolation; top-byte overflow wraps to 000000, borrow to 999999; the six-digit rebuild via `ScoreSetDigit`/`ScoreDraw`; the operation bar visible 9–16, carry 17–24, strip 25–32; the auto-demo ADD 1 → ADD 100; captures 000001/000101. Evidence pins (AR-6): frame checkpoints; `BCDAdd` A=selector; `BCDCarryMid`/`BCDCarry`; `BCDScoreLow/Mid/High`; `ScoreDigitWrite`; `Overflow`; `BodyStart` 37; `HmoveDone`. Red baseline confirmed: no `lessons/part6-game-dev/40-bcd-arithmetic`, no `docs/public/images/lesson40`, no Part 6 40 ROMs, the document is the `🔒 Coming Soon` stub, index row 40 is Coming Soon, sidebar entry exists (`config.ts:111`), `verify.sh` green at `87d7350`. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-11-05 13:38): Preflight per `vcs-lesson-production` — the decimal-mode paths, the 3-byte carry/borrow, the command selector, the BCD-to-six-digits rebuild, the operation bar/carry/strip, and the 262-line frame checked against `include/vcs.asm`, the 6502 decimal rules, and the Lesson 39 score library; ACME forms. `bash scripts/verify.sh` green (implementation, review fixes, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `HmoveApply` 4/45 (the WSYNC stall; the `STA HMOVE` executes at 5/0), `HmoveDone` 5/3, `OverscanStart` 229/4. Logic: `BCDAdd` A=$01/$64 (selector 100)/$01; `BCDCarryMid` A=0 (A=1 on a preset 000099), `BCDCarry` A=0 (ex 3 A=1); `BCDScoreLow` 0→1→2, mid 0/1/1, high 0; `ScoreDigitWrite` six calls per operation; the overflow probe (000000−1=999999, then ADD 1) wraps to 000000; ex 1 000010, ex 2 999999 with the borrow, ex 3 009900+100=010000 with the middle carry. Captures from the committed ROM: `add1.png` reads 000001 at x=367–642, y=110–130, bar slot 0, strip bit 0, carry dark; `add100.png` reads 000101, bar slot 2, strip bit 0; no cursor. Site (ST-40.6): index row 40 ✅ (rows 38–39 ✅, 41–47 Coming Soon); the page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 39, next → 41; sidebar `config.ts:111`; README unchanged; `include/score.asm` sourced by all four. Reviews (AR-5): the atari2600-reviewer round 1 — **0 critical, 0 major**, 5 minor (timing; SED comment; ex2 SUB1 comment; Borrow flag; BCDCarryMid wording); the curriculum-auditor round 1 — **0 critical, 0 major**, 5 minor (the excerpt; the strip claim; the SED comment; y extent; HMOVE table). All fixed; final state **0 critical, 0 major open**. Lesson 40 is complete.


**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-40.1–ST-40.6, the 3-byte BCD layout,
   the add/subtract paths, the carry/borrow cells, and `CLD` restoration; record the red baseline.
2. **Session B — implement:** preflight; author the main source and three solutions; write the
   document; assemble, run, and capture; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 4: Lesson 41 — Game States

> **Phase baseline tree**: ae879a8 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part6-game-dev/41-game-states/` (4 sources) ·
> `docs/part6-game-dev/41-game-states.md` · `docs/part6-game-dev/index.md` (row 41) ·
> `docs/public/roms/part6-game-dev/41-game-states/` · `docs/public/images/lesson41/` ·
> `README.md` (verify only) · `99-execution-plan.md` + `05-findings.md` + roadmaps
> **Reasoning**: high — a state machine's reset-on-entry and per-state input are where game bugs
> start; the title/over layouts must be pixel-checked

### Step 4.1: Lesson 41 — Game States

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 41 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 41 · AR-2, AR-3, AR-4, AR-6, AR-10,
AR-17, AR-26, AR-27, AR-28
**Objective**: Deliver Lesson 41 end to end.

- [x] 4.1.1 Lesson 41 — Game States: Session A freezes ST-41.1–ST-41.6 (red baseline), Session B
  implements the full artifact set, Session C verifies to green and hardens; commit via the
  `git-commit` skill in push mode — `feat(lesson41): Game States` ✅ (completed: 2026-11-05 14:46)

**Session A record** (freeze + red baseline, 2026-11-05 14:00): ST-41.1–ST-41.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 41. Design pins: states 0 title, 1 play, 2 over; `SetState` owns the entry work; title gold emblem + blinking 15-chunk bar; play 16-line status bar, P0 at Y=140, ball from Y=24; `CXP0FB` bit 6 edge → Hits++/beep/respawn; ball Y>180 → over; over red field + final bar + blinking fire bar; fire 0↔1/2↔0; the auto-demo 180 frames title / first hit arms 30 / P0 slides away / over at 446; the pause/attract/high-score exercises. Evidence pins (AR-6): frame checkpoints; `StateChange` A=new state; `TimerRead` (A=`StateTimer`); `FireRead` A=`INPT4`; `HitStep` A=hits; `BallStep` A=`BallY`; `BodyStart`; `HmoveApply`/`HmoveDone`. Red baseline confirmed: no `lessons/part6-game-dev/41-game-states`, no `docs/public/images/lesson41`, no Part 6 41 ROMs, the document is the `🔒 Coming Soon` stub, index row 41 is Coming Soon, sidebar entry exists (`config.ts:112`), `verify.sh` green at `ae879a8`. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-11-05 14:46): Preflight per `vcs-lesson-production` — the state machine, the per-state entry work, the fire/SELECT edges, the joystick level, the P0–ball collision, the three layouts, and the 262-line frame checked against `include/vcs.asm` and the state-machine/input references; ACME forms. `bash scripts/verify.sh` green (implementation, review fixes, and re-captures); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` `$F12A` = 37/5, `HmoveApply` 11/56, `HmoveDone` 12/3, `OverscanStart` `$F289` = 229/7. Logic: `StateChange` `$F358` A=0 reset → A=1 at frame 180 (auto-demo) → A=2 at 446; a forced-fire probe 0@460 → 1@640; `TimerRead` `$F2AB` A=$B4→$01; `HitStep` `$F307` A=1 at 290; `BallStep` `$F320` 25/133/25/181; `FireRead` A=$8C; `ReadCX` $02/$42. Captures: `title.png` gold emblem + blinking bar (15 chunks per half, two segments); `over.png` red field + solid 16-line final hit bar + fire bar, 120 TIA px (720 capture px); the doc discloses that the images are Stella `saveSnap` frames at 40/500 in real window chrome. Solutions: ex1 pause 3@220/1@250 with the contact preserved (HitStep 1@293); ex2 attract 1@300 and hit 410/over 566; ex3 HighScore 1@446. Site (ST-41.6): index row 41 ✅ (rows 38–40 ✅, 42–47 Coming Soon); the page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 40, next → 42; sidebar `config.ts:112`; README unchanged. Reviews (AR-5): the atari2600-reviewer — **2 major, 4 minor** (the saveSnap provenance; the over first line; the play-kernel timing; the 720-pixel wording; the edge claim; the snippet labels); the curriculum-auditor — **2 major, 5 minor** (the provenance; the edge claim; the snippet labels; the Lesson 40 promise; the stale `Lives`; the pause hit loss; the alt text). The provenance is accepted with an explicit method note; all other findings fixed. Final state: **0 critical, 0 major open** (one disclosed capture-method deviation). Lesson 41 is complete.


**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-41.1–ST-41.6, the three states, the
   transition conditions, the reset-on-entry rules, and the two layouts; record the red baseline.
2. **Session B — implement:** preflight; author the main source and three solutions; write the
   document; assemble, run, and capture; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 5: Lesson 42 — Difficulty and Progression

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part6-game-dev/42-difficulty/` (4 sources) ·
> `docs/part6-game-dev/42-difficulty.md` · `docs/part6-game-dev/index.md` (row 42) ·
> `docs/public/roms/part6-game-dev/42-difficulty/` · `docs/public/images/lesson42/` ·
> `README.md` (verify only) · `99-execution-plan.md` + `05-findings.md` + roadmaps
> **Reasoning**: high — the switch bits, the speed table, and the level cap are the part's most
> error-prone progression arithmetic

### Step 5.1: Lesson 42 — Difficulty and Progression

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 42 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 42 · AR-2, AR-3, AR-4, AR-6, AR-10,
AR-18, AR-26, AR-27, AR-28
**Objective**: Deliver Lesson 42 end to end.

- [ ] 5.1.1 Lesson 42 — Difficulty and Progression: Session A freezes ST-42.1–ST-42.6 (red
  baseline), Session B implements the full artifact set, Session C verifies to green and hardens;
  commit via the `git-commit` skill in push mode — `feat(lesson42): Difficulty and Progression`

**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-42.1–ST-42.6, the `SWCHB` bits, the
   start-level choices, the speed table, and the cap; record the red baseline.
2. **Session B — implement:** preflight; author the main source and three solutions; write the
   document; assemble, run, and capture; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 6: Lesson 43 — Random Numbers

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part6-game-dev/43-random-numbers/` (4 sources) ·
> `include/random.asm` (new library) · `docs/part6-game-dev/43-random-numbers.md` ·
> `docs/part6-game-dev/index.md` (row 43) · `docs/public/roms/part6-game-dev/43-random-numbers/` ·
> `docs/public/images/lesson43/` · `README.md` (verify only) ·
> `99-execution-plan.md` + `05-findings.md` + roadmaps
> **Reasoning**: high — the LFSR polynomial, the zero lock, and the period claim are math claims
> that must be cross-checked, not assumed

### Step 6.1: Lesson 43 — Random Numbers

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 43 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 43 · AR-2, AR-3, AR-4, AR-6, AR-7,
AR-10, AR-19, AR-26, AR-27, AR-28
**Objective**: Deliver Lesson 43 end to end, including `include/random.asm`.

- [ ] 6.1.1 Lesson 43 — Random Numbers: Session A freezes ST-43.1–ST-43.6 (red baseline), Session
  B implements the full artifact set including `include/random.asm`, Session C verifies to green
  and hardens; commit via the `git-commit` skill in push mode — `feat(lesson43): Random Numbers`

**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-43.1–ST-43.6, the polynomial, the
   period, the zero lock, the mask, and the history layout; record the red baseline.
2. **Session B — implement:** preflight; author the library, the main source, and three
   solutions; write the document; assemble, run, and capture; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 7: Lesson 44 — AI & Enemy Behavior

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part6-game-dev/44-ai-enemy-behavior/` (4 sources) ·
> `docs/part6-game-dev/44-ai-enemy-behavior.md` · `docs/part6-game-dev/index.md` (row 44) ·
> `docs/public/roms/part6-game-dev/44-ai-enemy-behavior/` · `docs/public/images/lesson44/` ·
> `README.md` (verify only) · `99-execution-plan.md` + `05-findings.md` + roadmaps
> **Reasoning**: high — the state transitions, the distance thresholds, and the flee timer must
> match the log exactly; the color/state row is the visual witness

### Step 7.1: Lesson 44 — AI & Enemy Behavior

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 44 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 44 · AR-2, AR-3, AR-4, AR-6, AR-10,
AR-20, AR-26, AR-27, AR-28
**Objective**: Deliver Lesson 44 end to end.

- [ ] 7.1.1 Lesson 44 — AI & Enemy Behavior: Session A freezes ST-44.1–ST-44.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson44): AI & Enemy Behavior`

**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-44.1–ST-44.6, the three states, the
   distance thresholds, the flee timer, and the colors; record the red baseline.
2. **Session B — implement:** preflight; author the main source and three solutions; write the
   document; assemble, run, and capture; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 8: Lesson 45 — Memory Management

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part6-game-dev/45-memory-management/` (4 sources) ·
> `docs/part6-game-dev/45-memory-management.md` · `docs/part6-game-dev/index.md` (row 45) ·
> `docs/public/roms/part6-game-dev/45-memory-management/` · `docs/public/images/lesson45/` ·
> `README.md` (verify only) · `99-execution-plan.md` + `05-findings.md` + roadmaps
> **Reasoning**: high — the RAM map, the bit packing, and the ACME budget assert are compile-time
> and runtime claims; the map table must match the source's actual addresses

### Step 8.1: Lesson 45 — Memory Management

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 45 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 45 · AR-2, AR-3, AR-4, AR-6, AR-10,
AR-21, AR-26, AR-27, AR-28, AR-34
**Objective**: Deliver Lesson 45 end to end.

- [ ] 8.1.1 Lesson 45 — Memory Management: Session A freezes ST-45.1–ST-45.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson45): Memory Management`

**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-45.1–ST-45.6, the map table, the packed
   flags/timer, the overlay, and the `$F7` budget; record the red baseline.
2. **Session B — implement:** preflight; author the main source and three solutions; write the
   document; assemble, run, and capture; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 9: Lesson 46 — Debugging

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part6-game-dev/46-debugging/` (4 sources) ·
> `docs/part6-game-dev/46-debugging.md` · `docs/part6-game-dev/index.md` (row 46) ·
> `docs/public/roms/part6-game-dev/46-debugging/` · `docs/public/images/lesson46/` ·
> `README.md` (verify only) · `99-execution-plan.md` + `05-findings.md` + roadmaps
> **Reasoning**: high — the bug paths are intentional defects; the lesson must prove they fail
> and that the fixed paths pass, without leaving a bug in the committed main ROM's default mode

### Step 9.1: Lesson 46 — Debugging

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 46 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 46 · AR-2, AR-3, AR-4, AR-6, AR-10,
AR-22, AR-26, AR-27, AR-28, AR-35
**Objective**: Deliver Lesson 46 end to end.

- [ ] 9.1.1 Lesson 46 — Debugging: Session A freezes ST-46.1–ST-46.6 (red baseline), Session B
  implements the full artifact set, Session C verifies to green and hardens; commit via the
  `git-commit` skill in push mode — `feat(lesson46): Debugging`

**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-46.1–ST-46.6, the three bug/fix paths,
   the debugger commands, and the screenshots; record the red baseline.
2. **Session B — implement:** preflight; author the main source and three solutions; write the
   document; assemble, run, and capture; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 10: Lesson 47 — Development Tools & Workflow

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part6-game-dev/47-dev-tools-workflow/` (4 sources, including
> `demo-47.asm`) · `docs/part6-game-dev/47-dev-tools-workflow.md` ·
> `docs/part6-game-dev/index.md` (row 47) · `docs/public/roms/part6-game-dev/47-dev-tools-workflow/`
> · `docs/public/images/lesson47/` · `README.md` (verify only) ·
> `99-execution-plan.md` + `05-findings.md` + roadmaps (progress/finish)
> **Reasoning**: high — the `!if DEBUG` build pair and the checksum are tooling claims; the demo
> must be reproducible from the documented commands

### Step 10.1: Lesson 47 — Development Tools & Workflow

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 47 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 47 · AR-2, AR-3, AR-4, AR-5, AR-6,
AR-7, AR-10, AR-23, AR-26, AR-27, AR-28, AR-30, AR-36
**Objective**: Deliver Lesson 47 end to end, close Part 6, and update the roadmaps.

- [ ] 10.1.1 Lesson 47 — Development Tools & Workflow: Session A freezes ST-47.1–ST-47.6 (red
  baseline), Session B implements the full artifact set including `demo-47.asm`, Session C
  verifies to green and hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson47): Development Tools & Workflow`

**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-47.1–ST-47.6, the five stages, the
   `DEBUG` build pair, the checksum, and the tooling commands; record the red baseline.
2. **Session B — implement:** preflight; author the demo and three solutions; write the document;
   assemble both builds, run, and capture; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Part 6 completion gate (required before 10.1.1 is `[x]`):** flip index row 47, confirm all
   rows 38–47 ✅, update the feature roadmap (RD-06 Done, 6/11 RDs), the portfolio (6 plans done),
   and the plan completion note; final `verify.sh`; commit and push (AR-30).

- [ ] 10.1.1a Part 6 completion gate: index rows 38–47 ✅, RD-06 Done, feature roadmap 6/11,
  portfolio 6 plans, all completion criteria ticked, final `verify.sh` green

---

## Plan-Level Verification

| Check | Command | Pass condition |
| --- | --- | --- |
| ROM drift + docs | `bash scripts/verify.sh` | `=== VERIFY PASSED ===` |
| Part 6 artifacts | `find docs/public/roms/part6-game-dev -name '*.bin' \| wc -l` | 40 |
| Screenshots | `find docs/public/images/lesson{38..47} -name '*.png' \| wc -l` | 20 |
| Documents | `grep -l '## Key Takeaways' docs/part6-game-dev/3*.md docs/part6-game-dev/4*.md \| wc -l` | 10 |
| Roadmap | `grep 'RD-06' codeops/features/curriculum/00-roadmap.md` | `Done` / `✅` |
| Reviews | [05-findings.md](05-findings.md) | 0 critical, 0 major open |
| Frame | state logs | every lesson's fixed/default path `BodyStart` 37 and `OverscanStart` 229 (262 lines); Lesson 46's intentional bug path is 230 |
| HMOVE | state logs | each lesson that positions sprites (38–42, 44, 46) reports its measured `HmoveDone` in HBLANK; 43/45/47 are playfield-only |

## Completion Criteria

- [ ] All ten phases marked `[x]` with Session A/C records.
- [ ] 40 committed 4,096-byte ROMs, 10 documents, 20 screenshots.
- [ ] `include/score.asm`, `include/random.asm`, and `demo-47.asm` shipped.
- [ ] Part 6 index rows 38–47 all ✅ Complete.
- [ ] `bash scripts/verify.sh` green at the final commit.
- [ ] Both specialists report no critical/major open for every lesson.
- [ ] No dead code, no unused symbols/tables; security is N/A (static content, no input).
- [ ] The post-completion re-analysis (plan/skill protocol) is recorded.
- [ ] RD-06 Done; feature roadmap 6/11 RDs; portfolio 6 plans done.
