# Execution Plan: Part 7 — Kernel Mastery (Lessons 48–55)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-06 09:35
> **Progress**: 7/8 tasks (87.5%)
> **CodeOps Artifact Schema**: 1

## Overview

Eight phases, one per lesson, strictly sequential — 48 introduces the taxonomy and the 1-line/
2-line shapes; 49 builds the 2-line kernel; 50 reuses it and the score library; 51/52 are
independent kernel labs; 53 builds the pattern library; 54 uses 52's scroll with its own effect
tables; 55 reuses 39's 48-pixel kernel (AR-1, AR-42). Every phase is one task run through the mandatory
three-session ordering: Session A freezes that lesson's specification cases, Session B implements
the full artifact set, and Session C verifies against the frozen cases and hardens under
independent review (AR-2, AR-5). `bash scripts/verify.sh` is the gate for every phase (AR-4). Kernel,
scroll, flicker, text, and zone claims carry the state-log + static-ledger evidence of AR-6 and
AR-29–AR-31; every screenshot is pixel-checked against the monitor geometry (AR-23).

**🚨 Update this document after EACH completed task!**

**Session record slots:** each task gets a `**Session A record**` paragraph after its task line
(freeze + red baseline + design pins) and a **Session C record** paragraph after the Session
sub-steps. The per-lesson findings are appended to [05-findings.md](05-findings.md); the plan-level
preflight findings live in [00-preflight-report.md](00-preflight-report.md). The plan is not
executable until the preflight report exists and the roadmap row reads `Plan Preflighted`. The
push mode is authorized by the user's directive to execute RD-07 and the Part 1–6 practice (AR-12).

---

## Implementation Phases

| Phase | Title | Tasks |
| ----- | ----- | ----- |
| 1 | Lesson 48 — Introduction to Kernels | 1 |
| 2 | Lesson 49 — The 2-Line Kernel | 1 |
| 3 | Lesson 50 — Multi-Zone Kernel | 1 |
| 4 | Lesson 51 — Flicker Sprites | 1 |
| 5 | Lesson 52 — Fine Scrolling | 1 |
| 6 | Lesson 53 — Kernel Design Patterns | 1 |
| 7 | Lesson 54 — Visual Effects Cookbook | 1 |
| 8 | Lesson 55 — Scrolling Text Marquee | 1 |

**Total: 8 tasks across 8 phases.**

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

## Phase 1: Lesson 48 — Introduction to Kernels

> **Phase baseline tree**: f097ab4 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part7-kernel-mastery/48-introduction-to-kernels/` (4 sources,
> including `demo-48.asm`) · `docs/part7-kernel-mastery/48-introduction-to-kernels.md` ·
> `docs/part7-kernel-mastery/index.md` (rebuild + row 48) ·
> `docs/public/roms/part7-kernel-mastery/48-introduction-to-kernels/` ·
> `docs/public/images/lesson48/` (2 captures) · `README.md` (verify only) ·
> `99-execution-plan.md` + `05-findings.md` + roadmaps
> **Reasoning**: high — the first Part 7 lesson defines the kernel taxonomy and the split 1-line/
> 2-line demo; the line counts and the two kernels are under independent hardware review

### Step 1.1: Lesson 48 — Introduction to Kernels

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 48 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 48 · AR-1–AR-6, AR-10, AR-13, AR-23,
AR-24, AR-32
**Objective**: Deliver Lesson 48 end to end through the mandatory three sessions.

- [x] 1.1.1 Lesson 48 — Introduction to Kernels: Session A freezes ST-48.1–ST-48.6 (red baseline),
  Session B implements the full artifact set (including the AR-10 index rebuild), Session C
  verifies to green and hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson48): Introduction to Kernels` ✅ (completed: 2026-11-06 00:47)

**Session C record** (verify + evidence, 2026-11-06 00:47): Preflight per `vcs-lesson-production` — the 1-line/2-line kernels, the split/full mode arithmetic, the three-plane diamond data, the top-down row loops, the dashes, the one-HMOVE positioning, the mode/auto-demo/fire/SELECT logic, and the 262-line frame checked against `include/vcs.asm`, the timing reference, and the state logs; ACME forms. `bash scripts/verify.sh` green (implementation and review fixes); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F053` 259/3, `VblankStart` `$F061` 0/5, `BodyStart` `$F16B` 37/5, `OverscanStart` `$F22F` 229/9 (the cycle is the loop tail; the scanline is 229), `HmoveApply` `$F156` 4/53 (the `WSYNC` write; the CPU waits to the end of line 4), `HmoveDone` `$F15A` 5/3 (after the `HMOVE` store at 5/0). Logic: `ModeRead` `$F119` A=0/1/2 at frames 1/240/480; `ModeStep` `$F24F` A=1 at 240 and A=2 at 480; `SelectReset` `$F0B5` A=0 with `-holdselect`; `ZoneCountRead` `$F121` A=2; `LineCountRead` `$F126` A=$60/$C0/$00; `PairCountRead` `$F12B` A=$30/$00/$60; `LineRow` `$F178` Y=0..95; `PairRow` `$F1A7` Y=0..47; `LineRow2`/`PairRow2` fire on both passes. Joystick (the review's raw-bit/masked-value check): `-holdjoy0 L` reaches `DashLeft` with A=$80 (the raw left bit is $40; after `AND #$C0` the other bit is high), `-holdjoy0 R` reaches `DashRight` with A=$40; the code DECs/INCs, so left moves left and right moves right. A manual fire press was not exercised in the log; the auto-demo calls the same `AdvanceMode`, and SELECT is logged. Captures from the current committed ROM (`split.png`, `full-two-line.png`): the split has green top/gold bottom, diamond widths 8/48/96 TIA px at visible 0/24/47/71/95/120/144/168/190, a 1-line top dash and a 2-line bottom dash; the full 2-line view is all gold with four 2-line dashes; no cursor; the title bars read `Stella 7.0: "demo-48"`. The images were re-captured after the joystick/alignment fix by the same burst/pixel-selection method. Solutions: ex1 three zones 64+64+64 (`ZoneCount` 3, `LineRow` 0..63 at 37–100, `PairRow` 0..31 at 101–163, `LineRow3` 0..63 at 165–228), ex2 rectangle 16–79/112–175 (`Shape` 1), ex3 mode 3 8+176+8 (`HeaderEnd` 8, `PlayPair` 0..87 at 45–219; the footer PF0/PF1/PF2 are written before the player clears to remove the 4-px notch). Site (ST-48.6): the Part 7 index was rebuilt to the Part 1 format (row 48 ✅, rows 49–55 `🔒 Coming Soon`); the page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 47, next → 49; sidebar `config.ts:125`; README unchanged. Reviews (AR-5): round 1 — the atari2600-reviewer 7 minor (duplicate label, dispatch 8 vs 12, four-cross page bound, RAM 40 vs 15, ex2 comments, ex1/ex3 comments, LineRow2 wording, ex2 hint) and 3 open questions; the curriculum-auditor 2 major (dispatch 8 vs 12; ex2 hint) and 4 minor (duplicate label, RAM 40, ex1 mode header, `HmoveApply` label). Round 2 — 1 major (the joystick raw-bit/masked-value wording; the functional mapping is correct and the doc now states both) and the page-cross/`HmoveApply` residuals; round 3 — the joystick wording, page-cross prose, ex1/ex2/ex3 comments, and ex3 footer notch were fixed. Final state: **0 critical, 0 major open** (the joystick is functionally correct; the raw/masked wording is documented; the manual fire press is disclosed). Lesson 48 is complete.


**Session A record** (freeze + red baseline, 2026-11-05 23:32): ST-48.1–ST-48.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 48. Design pins: mode 0 split 96+96 (top 1-line, bottom 2-line); mode 1 full 1-line 192 rows; mode 2 full 2-line 96 rows; the three 96-byte and three 48-byte diamond planes repeated in the full modes; a 1-line dash and a 2-line dash; fire cycles the modes, the auto-demo cycles every 240 frames, SELECT resets; the row loops are top-down `LDY #0; INY; CPY #N; BNE`; the 1-line/2-line kernels total 192 lines. Evidence pins (AR-6): `Mode` A=0/1/2; `ZoneCount`; `LineCount` 96/192; `PairCount` 48/96; `LineRow`/`PairRow` 0→N−1; `BodyStart` 37; `OverscanStart` 229; `StartFrame` 259. Red baseline confirmed: no `lessons/part7-kernel-mastery/48-introduction-to-kernels`, no `docs/public/images/lesson48`, no Part 7 ROMs, the document is the `🔒 Coming Soon` stub, the Part 7 index is the minimal stub, sidebar entry exists (`config.ts:125`), `verify.sh` green at `f097ab4`. No implementation logic read (AR-2).


**Session sub-steps:**

1. **Session A — freeze the specification (red phase):** re-affirm ST-48.1–ST-48.6, the split
   line counts (96+96), the full modes (192 rows / 96 rows), the diamond and dash shapes, and the
   mode cycle; record the red baseline. No implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `demo-48.asm` and
   three solutions; rebuild the Part 7 index; write the document; assemble, run in Stella, and
   capture the two screenshots from the committed ROM; run `npm run roms`; run `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row with recorded evidence; run the two
   specialists on the phase diff; fix findings; re-run `verify.sh`; record the Session C evidence
   and the findings ledger rows.
4. **Commit:** `git-commit` skill in push mode with the `Ref:`/`Task:` trailers; update the
   roadmap row to Done only at Part 7 completion (AR-12).

---

## Phase 2: Lesson 49 — The 2-Line Kernel

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part7-kernel-mastery/49-two-line-kernel/` (4 sources) ·
> `docs/part7-kernel-mastery/49-two-line-kernel.md` · `docs/part7-kernel-mastery/index.md`
> (row 49) · `docs/public/roms/part7-kernel-mastery/49-two-line-kernel/` ·
> `docs/public/images/lesson49/` · `README.md` (verify only) · `99-execution-plan.md` +
> `05-findings.md` + roadmaps
> **Reasoning**: high — the 62/63 two-line kernel is the part's core pattern; the row table,
> the color ramps, and the sprite strips must fit the 152-cycle pair

### Step 2.1: Lesson 49 — The 2-Line Kernel

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 49 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 49 · AR-1–AR-6, AR-10, AR-14, AR-23,
AR-24, AR-33
**Objective**: Deliver Lesson 49 end to end.

- [x] 2.1.1 Lesson 49 — The 2-Line Kernel: Session A freezes ST-49.1–ST-49.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson49): The 2-Line Kernel` ✅ (completed: 2026-11-06 02:05)

**Session C record** (verify + evidence, 2026-11-06 02:05): Preflight per `vcs-lesson-production` — the 2-line row body, the steady-state store order and pixel deadlines, the 96-byte mountain/sky/strip tables, the top-down 96-row loop, the 16-line figure/bird, the one-HMOVE positioning, the joystick mapping, and the 262-line frame checked against `include/vcs.asm`, the timing reference, and the state logs; ACME forms. `bash scripts/verify.sh` green (implementation and review fixes); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6, `HmoveApply` 2/63 (the `WSYNC` write; the CPU waits to the end of line 2), `HmoveDone` 3/3 (after the `HMOVE` store at 3/0). Kernel: `KernelRow` Y=0..95 (37/07, 39/08, 41/08, last 227/08/Y=$5F); `RowWrite` 37/11, 39/12; `P0XRead` A=$49 (73), then 74, 75…; `P1XRead` A=$68 (104); `-holdjoy0 L` reaches the left branch and DECs 73→72→71 (the raw left bit is `$40`; after `AND #$C0` the masked value is `$80`); `-holdjoy0 R` reaches the right branch and INCs 73→74→75; the auto-demo holds 144 at frames 72/344 and 8 at 208/480 (272 frames). The 62-cycle nominal row body is **63 effective** because the loop's taken `BNE` crosses a page; the pair margin is 89 (44.5/line); the first row is one cycle earlier (14/21/28/35/42/49/56), the steady state is 15/22/29/36/43/50/57. The first-scanline windows: `PF0` 2 px, `PF1` 3 px (only row 8 visible), `COLUPF` ~40 px, `PF2` ~13 px (rows 42/48/54), `COLUBK` ~70 px at the top, `GRP1` 1 px; the captured mountain edge is 74/84 exact and 10 rows within one chunk (the model's windows plus the one-chunk threshold). Captures from the committed ROM: `landscape.png` figure X≈13, 16 lines; `figure-right.png` X≈142; the bird X=105–110.8; the two images differ only in the figure; no cursor; the title bars read `Stella 7.0: "49-two-line-kernel"`. Solutions: ex1 120 cycles/four lines (two 55 bodies + a 10-cycle tail; 184 margin/46 per line; `KernelRow` 0,2,…94), ex2 two pixels/frame (this layout's `BNE` is page-local, so its body is 62), ex3 NUSIZ0=3 with clamp 8–120 (last pixel 159). Site (ST-49.6): index row 49 ✅ (rows 48 ✅, 50–55 Coming Soon); the page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 48, next → 50; sidebar `config.ts:126`; README unchanged. Reviews (AR-5): the atari2600-reviewer round 1 — **1 major, 6 minor** (the store-order/timing model; X=56; the mountain-edge evidence; the bird box; the captions; the ex1 note) and round 2/3 — the effective 63 ledger, the PF1 row 8, the PF2 43/61, the X=82, the 74/84 measurement, the ex1/Ex3/P0_MAX comments, the prerequisite trim, and the joystick-clamp disclosure; the curriculum-auditor round 1 — **2 major** (the X=56/79 and the ex2 hint) plus 4 minor, round 2 — the 35→49/54, page+96→192, KernelRow Y, the bird box, the edge row, the ex2 hint, and round 3 — the effective 63 ledger and the ex1 wording. The final state is **0 critical, 0 major open** (the 63 effective is the operative ledger; the 10-row measurement is recorded as 74/84 exact with the model's windows; the joystick hold's ~22-frame release is disclosed, the auto-demo verifies the clamps). Lesson 49 is complete.


**Session A record** (freeze + red baseline, 2026-11-06 00:50): ST-49.1–ST-49.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 49. Design pins: 96 rows × 2 lines = 192; three 96-byte mountain planes; 96-byte COLUPF/COLUBK ramps; 96-byte P0/P1 strips; the figure at strip row 75 (visible 150–165), the bird at row 30 (visible 60–75); the figure 1 px/frame, clamp 8–144, a 272-frame auto-demo; 62 nominal / 63 effective cycles per 2 lines (31.5/line, 89 per pair margin); top-down `LDY #0; INY; CPY #96; BNE`; one HMOVE; 262 lines. Evidence pins (AR-6): `StartFrame`, `VblankStart`, `BodyStart` 37, `OverscanStart` 229, `HmoveApply`/`HmoveDone`, `KernelRow` 0..95, `RowWrite`, `P0X`/`P1X`. Red baseline confirmed: no `lessons/part7-kernel-mastery/49-two-line-kernel`, no `docs/public/images/lesson49`, no Part 7 49 ROMs, the document is the `🔒 Coming Soon` stub, index row 49 is Coming Soon, sidebar `config.ts:126`, `verify.sh` green at `76d9846`. No implementation logic read (AR-2).


**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-49.1–ST-49.6, the 96 rows × 2 lines,
   the 62/63 ledger, the mountain/sky tables, the figure/bird strips, and the joystick clamp;
   record the red baseline.
2. **Session B — implement:** preflight; author the main source and three solutions; write the
   document; assemble, run, and capture; flip index row 49; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 3: Lesson 50 — Multi-Zone Kernel

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part7-kernel-mastery/50-multi-zone-kernel/` (4 sources) ·
> `docs/part7-kernel-mastery/50-multi-zone-kernel.md` · `docs/part7-kernel-mastery/index.md`
> (row 50) · `docs/public/roms/part7-kernel-mastery/50-multi-zone-kernel/` ·
> `docs/public/images/lesson50/` · `README.md` (verify only) · `99-execution-plan.md` +
> `05-findings.md` + roadmaps
> **Reasoning**: high — the 9+8+174+1 zone split, the score/library reuse, and the two HMOVEs are
> the part's most error-prone line and timing arithmetic

### Step 3.1: Lesson 50 — Multi-Zone Kernel

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 50 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 50 · AR-1–AR-6, AR-10, AR-15, AR-23,
AR-24, AR-27, AR-34
**Objective**: Deliver Lesson 50 end to end, reusing `include/score.asm`.

- [x] 3.1.1 Lesson 50 — Multi-Zone Kernel: Session A freezes ST-50.1–ST-50.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson50): Multi-Zone Kernel` ✅ (completed: 2026-11-06 03:28)

**Session C record** (verify + evidence, 2026-11-06 03:28): Preflight per `vcs-lesson-production` — the 9+8+174+1 zone budget, the score library's 9-line hand-over, the two HMOVEs and the 24-cycle motion-register rule, the 2-line play kernel, the collision/latch, the level clock, the joystick, and the 262-line frame checked against `include/vcs.asm`, `include/score.asm`, the timing reference, and the state logs; ACME forms. `bash scripts/verify.sh` green (implementation and review fixes); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` `$F159` 37/5, `ScoreDraw` `$F50D` 37/11, `StatusStart` `$F15C` 46/5, `PlayStart` `$F19B` 54/4, `GroundStart` `$F22A` 228/6, `OverscanStart` `$F239` 229/2; `ScoreHmove` 5/45 (the library's `WSYNC` stall), `ScoreHmoveDone` 6/3 (the store), `GameHmove` `$F192` 51/2. The `HMBL` clear was moved from immediately after `ScoreHmove` to status line 50 (after `SetGameP1`), more than 24 cycles after the score `HMOVE`, before `GameHmove`; the ball keeps X=80 and the second HMOVE applies only P0/P1. Logic: `LevelWrite` `$F084` A=1/2/3/4 at frames 121/241/361/481; `ScoreAdd` `$F4F6` A=1..5 at 106/211/316/421/526; `BallYRead` `$F087` A=24, 25, 26…; `JoyLeft` `$F0C8` 73→72→71, `JoyRight` `$F0D3` 73→74→75; the exercise hit periods: ex1 `ScoreAdd` 102/203/304/405/506 (101 frames), ex2 98/195/292/389/486 (97 frames). Captures from the committed ROM: `dashboard.png` score 000001, level 1 (one 24-px chunk per half); `level4.png` score 000004, level 4 (four chunks); P0 red TIA 76–83, P1 green 88–96, ball X=80, the ceiling/field/floor/ground `$0C`/`$1A`/`$C4`; the HMOVE notch is 8 black pixels at chunks 0–1 on status line 51; no cursor; the title bars read `Stella 7.0: "50-multi-zone-kernel"`. Solutions: ex1 9+12+170+1 (`PlayStart` 58), ex2 9+16+166+1 (`PlayStart` 62, the timer bar), ex3 the `ZoneTable` 9/8/174/1 with the 192/228 asserts; all 4,096 bytes. Site (ST-50.6): index row 50 ✅ (rows 48–49 ✅, 51–55 Coming Soon); the page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 49, next → 51; sidebar `config.ts:127`; README unchanged. Reviews (AR-5): the atari2600-reviewer round 1 — **1 major, 5 minor** (the `HMBL` clear only ~10 cycles after `ScoreHmove`; the line-52 comments; the `BallYRead` 25; the P1 strip rows; the ex3 field; the ex1/ex2 ball floor) and round 2 — **1 major** (the checkpoint addresses stale after the HMBL move) plus 3 minor (the Step 3 listing, the ex3 line 52, the band claim); the curriculum-auditor round 1 — 4 minor (the line-52 comments, the ex2 RAM, the ex3 field, the doc level 1) and round 2 — the stale addresses and the ex2 header. The HMBL clear, the `$F159`/`$F15C` addresses (re-logged 37/5/46/5), the Step 3 listing, the comments, the band claim, and the measured exercise periods are fixed. Final state: **0 critical, 0 major open**. Lesson 50 is complete.


**Session A record** (freeze + red baseline, 2026-11-06 02:07): ST-50.1–ST-50.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 50. Design pins: 9 score + 8 status + 174 play (87 rows × 2) + 1 ground = 192; `ScoreDraw` starts at visible 0, `StatusStart` 46 (37+9), `PlayStart` 54 (37+17), `GroundStart` 228 (37+191), `OverscanStart` 229; the score library's P0/P1 at 56/64 and the game's P0/P1 reposition with a second HMOVE in the status HBLANK; `RESBL`/`HMBL` before `ScoreSetup`, `HMBL` cleared after `ScoreHmove`; `CXP0FB` bit 6, read in VBLANK then `CXCLR`; the 120-frame level; the ball top 24–158; the exercises 12/170, 16/166, and the ZoneTable. Evidence pins (AR-6): `ScoreDraw`, `StatusStart`, `PlayStart`, `GroundStart`, `ScoreHmove`, `GameHmove`, `ScoreAdd`, `LevelWrite`, `BallY`, `BodyStart` 37, `OverscanStart` 229. Red baseline confirmed: no `lessons/part7-kernel-mastery/50-multi-zone-kernel`, no `docs/public/images/lesson50`, no Part 7 50 ROMs, the document is the `🔒 Coming Soon` stub, index row 50 is Coming Soon, sidebar `config.ts:127`, `verify.sh` green at `d9933f4`. No implementation logic read (AR-2).


**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-50.1–ST-50.6, the zone arithmetic
   (9+8+174+1), the score's 9 lines, the two HMOVEs, the collision read, and the level bar;
   record the red baseline.
2. **Session B — implement:** preflight; author the main source and three solutions; write the
   document; assemble, run, and capture; flip index row 50; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 4: Lesson 51 — Flicker Sprites

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part7-kernel-mastery/51-flicker-sprites/` (4 sources) ·
> `docs/part7-kernel-mastery/51-flicker-sprites.md` · `docs/part7-kernel-mastery/index.md`
> (row 51) · `docs/public/roms/part7-kernel-mastery/51-flicker-sprites/` ·
> `docs/public/images/lesson51/` · `README.md` (verify only) · `99-execution-plan.md` +
> `05-findings.md` + roadmaps
> **Reasoning**: high — the two-frame flicker, the per-row skipdraw test, and the sort/priority
> rule are the lesson's evidence; the two captures must be the two halves, not a merged image

### Step 4.1: Lesson 51 — Flicker Sprites

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 51 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 51 · AR-1–AR-6, AR-10, AR-16, AR-23,
AR-24, AR-29, AR-35
**Objective**: Deliver Lesson 51 end to end.

- [x] 4.1.1 Lesson 51 — Flicker Sprites: Session A freezes ST-51.1–ST-51.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson51): Flicker Sprites` ✅ (completed: 2026-11-06 04:54)

**Session C record** (verify + evidence, 2026-11-06 04:54): Preflight per `vcs-lesson-production` — the 8+184 zone split, the per-row skipdraw math (`row - ObjRow`, `CMP #4`, `shape*4+offset`), the two-object compare, the 92-row kernel, the latch persistence, the one-HMOVE positioning, the physics/beep, and the 262-line frame checked against `include/vcs.asm`, the timing reference, and the state logs; ACME forms. `bash scripts/verify.sh` green (implementation and review fixes); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F099` 259/3, `VblankStart` `$F0A7` 0/5, `BodyStart` `$F16F` 37/5, `PlayStart` `$F176` 45/4, `OverscanStart` `$F1C1` 229/6; `HmoveApply` `$F141` 7/38 or 7/48 (the `WSYNC` write), `HmoveDone` `$F145` 8/3 (the `HMOVE` store); 3+37+192+30 = 262. Logic: `Parity` `$F125` A=0/1 each frame; `DrawSlot0` `$F137` A=1/3 and `DrawSlot1` `$F13E` A=0/2 (parity 0 → object 1 nearer on P0, object 0 on P1; parity 1 → 3 on P0, 2 on P1); `KernelRow` `$F180` Y=0..91; `SkipWrite` `$F19A` / `SkipWrite1` `$F1B8` report the shape bytes or 0 (steady-state cycles 42/35; the first play line starts at 31 because `PlayStart`'s setup replaces the loop tail); the objects' live rows/shapes are `(63,1)/(17,0)` on frame 1 and `(86,3)/(38,2)` on frame 2. The kernel rows are 48 and 41 cycles, 89 of the 152-cycle pair; the shape table is 4×4 bytes; the persistent state is 31 bytes `$80–$9E` with `$A0` scratch. The latch: P0 shifts one line at X≤56 (seven lit lines inside the window, top blank), P1 is one line lower and shifts again at X≤35; `OBJ_MAX_Y=87` keeps the worst last line at play 182 (Y=88 would put P1's last line on the first overscan line). Captures from the committed ROM: `frame-a.png` parity 0 with red first ink TIA 71 (nearer, P0) and green 83 (farther, P1), status runs 25–48/97–144/169–216/+480; `frame-b.png` parity 1 with blue 92 (P0) and gold 84 (P1), status runs 49–72/241–288/313–360/+480; all four objects 24–25 capture rows; no cursor; title bars read `Stella 7.0: "51-flicker-sprites"`. Solutions: ex1 `SortFirst` A=0/2/0/2; ex2 `Parity` A=0/1/2 and `DrawSlot0` A=1/2/4; ex3 `AlwaysSlot` A=0 every frame and `DrawSlot1` A=1/2/3. Site (ST-51.6): index row 51 ✅ (rows 48–50 ✅, 52–55 Coming Soon); the page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 50, next → 52; sidebar `config.ts:128`; README unchanged. Reviews (AR-5): the atari2600-reviewer round 1 — 7 minor (the cycle parenthetical, the Y=88 bottom clip, the latch-persistence gap, the green X, `SHAPE_MASK`/`Frame`, plan slot wording, `-break`) and 3 open questions; round 2 — **1 major** (the new capture captions/table inverted P0/P1) plus the latch-height wording and a stale 88+3 comment; round 3 — 2 minor prose residuals (the VBLANK blanking wording; the ex3 header). The curriculum-auditor round 1 — 7 minor (the cycle parenthetical, the stale 43/93, the frame-1 Y=64/16, the green X, dead `Frame`/`SHAPE_MASK`, `-break`, the slot wording); round 2 — **1 major** (the same P0/P1 inversion) plus stale `$80–$9F`, the latch wording, and the exercise-2 hint count; round 3 — the 7-scanline wording, the blue 6/12/6, and the hint's 19 chunks. All fixed: the captures re-taken outside the latch windows (all 24–25 rows), the P0/P1 labels corrected, the Y bound 87, the dead symbols removed (31 bytes), the plan/07/99 wording aligned, the addresses re-derived and the logs re-run. The final state is **0 critical, 0 major open**. Lesson 51 is complete.


**Session A record** (freeze + red baseline, 2026-11-06 03:29): ST-51.1–ST-51.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 51. Design pins: 8 status + 184 play (92 rows × 2) = 192; four 8-line objects, parity 0 → objects 0/1 and parity 1 → 2/3; the 2-line kernel draws the P0-slot object on the first line and the P1-slot object on the second by the `row - ObjRow` / `CMP #4` / shape-table skipdraw (no RAM strips); the larger Y (top-down) is nearer and goes on P0; the status cells show the parity and the two drawn objects; the base RAM $80–$9E (four objects × 6, two slots × 2, parity, beep = 31; `$A0` is scratch; exercise 2 uses $D8–$F7 for the extra objects); the exercises reverse priority, six objects/three parities, and the always-on player. Evidence pins (AR-6): `Parity` A=0/1, `DrawSlot0`/`DrawSlot1`, `ObjRow0`/`ObjRow1`, `ObjShape0`/`ObjShape1`, `SkipWrite`, `HmoveApply`/`HmoveDone`, `BodyStart` 37, `OverscanStart` 229. Red baseline confirmed: no `lessons/part7-kernel-mastery/51-flicker-sprites`, no `docs/public/images/lesson51`, no Part 7 51 ROMs, the document is the `🔒 Coming Soon` stub, index row 51 is Coming Soon, sidebar `config.ts:128`, `verify.sh` green at `4928e8a`. No implementation logic read (AR-2).


**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-51.1–ST-51.6, the 8+184 zones, the
   four objects, the parity pairs, the per-row skipdraw, and the sort rule; record the red baseline.
2. **Session B — implement:** preflight; author the main source and three solutions; write the
   document; assemble, run, and capture the two halves; flip index row 51; `npm run roms`;
   `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 5: Lesson 52 — Fine Scrolling

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part7-kernel-mastery/52-fine-scrolling/` (4 sources) ·
> `docs/part7-kernel-mastery/52-fine-scrolling.md` · `docs/part7-kernel-mastery/index.md`
> (row 52) · `docs/public/roms/part7-kernel-mastery/52-fine-scrolling/` ·
> `docs/public/images/lesson52/` · `README.md` (verify only) · `99-execution-plan.md` +
> `05-findings.md` + roadmaps
> **Reasoning**: high — the 1-line kernel's 40-nominal/41-effective loop, the three page-aligned 256-byte
> planes, and the 1-px HMOVE ship are measured claims; the 4-px playfield / 1-px sprite split
> must be honest

### Step 5.1: Lesson 52 — Fine Scrolling

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 52 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 52 · AR-1–AR-6, AR-10, AR-17, AR-23,
AR-24, AR-30, AR-36
**Objective**: Deliver Lesson 52 end to end.

- [x] 5.1.1 Lesson 52 — Fine Scrolling: Session A freezes ST-52.1–ST-52.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson52): Fine Scrolling` ✅ (completed: 2026-11-06 06:10)

**Session C record** (verify + evidence, 2026-11-06 06:10): Preflight per `vcs-lesson-production` — the three page-aligned 256-byte planes, the 32-row sine continuity, the 40-nominal/41-effective 1-line kernel, the 16-byte ship, the latch window, the one HMOVE, the joystick, and the 262-line frame checked against `include/vcs.asm`, the timing reference, and the state logs; ACME forms. `bash scripts/verify.sh` green (implementation and review fixes); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F043` 259/3, `VblankStart` `$F051` 0/5, `BodyStart` `$F0E2` 37/5, `OverscanStart` `$F102` 229/8; `HmoveApply` `$F0D2` 2/53 (the `WSYNC` write), `HmoveDone` `$F0D6` 3/3 (the `NOP` after the `HMOVE` store; the store completes at 3/2). Scroll: `ScrollStep` `$F05C` A=1; `ScrollYWrite` `$F061` A=1,2,3,4… and 255→0→1 at frames 255/256/257; `WorldRead` `$F0E9` A=$F0 at cycle 14; `ShipWrite` `$F0F8` at cycle 35 with the 16 ship bytes at visible 150–165. Kernel: 40 cycles nominal / **41 effective** (the taken `BNE KernelRow` at $F100 targets $F0E6 across a page), 35 cycles of margin; exercise 1's page-local BNE keeps its body at 40; an off-boundary plane would make the worst case 42. Ship: `ShipXRead` `$F0CC` A=81,82,83…; the sweep hits 136 at frame 56 and 24 at frame 168; `-holdjoy0 L` DECs 79→76, `R` INCs 81→84. Latch: the base store at 35/37 applies from pixel ~43–44; X≤36 is wholly old, X=37–43 straddles, X≥44 is current; the bbox turns clean at X=41 because the top/bottom rows' ink sits at columns 3–4; a test capture at X=36 measured 151.4–166.7, and the shipped captures at X=48/88 are clean. Captures from the committed ROM: `tunnel-a.png` phase 0 (gap sequence 8,8,8,10×11,8×5,6×11,8×2), ship first ink TIA 48; `tunnel-b.png` phase 8 = ScrollY 40 mod 32 (10×6,8×5,6×11,8×5,10×5), ship TIA 88; walls `$C8`, gap `$02`, ship `$0E`; no cursor; title bars read `Stella 7.0: "52-fine-scrolling"`. A still measures the 32-row phase, not the exact 0–255 byte; the state log proves the increment and the wrap. Solutions: ex1 `ScrollYWrite` counts down and wraps 0→$FF (page-local 40); ex2 `ScrollStep` A=2 and ScrollYWrite 2,4,6,8 (41); ex3 `ShipStep` 0/1 and ShipXRead 80,81,81,82,82 (41). Site (ST-52.6): index row 52 ✅ (rows 48–51 ✅, 53–55 Coming Soon); the page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 51, next → 53; sidebar `config.ts:129`; README unchanged. Reviews (AR-5): the atari2600-reviewer round 1 — 4 minor (the latch boundary, the exercise headers, the `C_BG` comment, the doc prereq) and 3 open questions; round 2 — **1 major** (the 40-cycle ledger missed the taken BNE's page cross; fixed to 40 nominal/41 effective) plus the latch 8-pixel rule, the HmoveDone wording, and the drift direction; rounds 3/4 — no findings after the fixes. The curriculum-auditor round 1 — **1 major** (the doc prereq still listed the ball and omitted the timer) plus 2 minor (the exercise headers, the `C_BG` comment); round 2 — **1 major** (the latch boundary contradicted the pixel-43 anchor), fixed by the 8-pixel rule and the measured X=34–48 sweep; round 3 — **1 major** (the ex1 header copied the base's 35/37 cycle pair; ex1 is 34/36) plus the HmoveDone prose; round 4 — only the ex1 cycle pair, fixed. Final state: **0 critical, 0 major open**. Lesson 52 is complete.


**Session A record** (freeze + red baseline, 2026-11-06 04:58): ST-52.1–ST-52.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 52. Design pins: 192 lines, 1-line kernel; three page-aligned 256-byte planes (`WorldPF0/1/2`) indexed by the same `ScrollY`; the gap is centred and its width follows a 32-row sine (6..10 chunks), so the 32-row period divides 256 and the wrap joins cleanly; `ScrollY` 0–255, one line per frame; the kernel is `LDX ScrollY; LDY #0; ...; LDA WorldPFx,X; STA PFx; LDA ShipStrip,Y; STA GRP0; STA WSYNC; INX; INY; CPY #192; BNE` = 40 cycles nominal / 41 effective (the taken BNE crosses a page); the ship is a 16-byte (16-line) strip at rows 150–165, `ShipX` 1 px/frame with the divide-by-15 + one HMOVE dance, clamp 24–136; the joystick swaps the auto-demo; the exercises reverse the scroll, double the step, and halve the ship step. Evidence pins (AR-6): `ScrollY`, `ScrollStep`, `WorldRead` (A = the first `WorldPF0` byte), `ShipX`, `HmoveApply`/`HmoveDone`, `BodyStart` 37, `OverscanStart` 229, `StartFrame` 259. Red baseline confirmed: no `lessons/part7-kernel-mastery/52-fine-scrolling`, no `docs/public/images/lesson52`, no Part 7 52 ROMs, the document is the `🔒 Coming Soon` stub, index row 52 is Coming Soon, sidebar `config.ts:129`, `verify.sh` green at `4643caf`. No implementation logic read (AR-2).


**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-52.1–ST-52.6, the 256-row world, the
   1-line 40/41 ledger, the page-aligned planes, the 1-px ship step, and the playfield/sprite
   resolution split; record the red baseline.
2. **Session B — implement:** preflight; author the main source and three solutions; write the
   document; assemble, run, and capture; flip index row 52; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 6: Lesson 53 — Kernel Design Patterns

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part7-kernel-mastery/53-kernel-patterns/` (4 sources) ·
> `include/kernel_patterns.asm` (new library) · `docs/part7-kernel-mastery/53-kernel-patterns.md`
> · `docs/part7-kernel-mastery/index.md` (row 53) ·
> `docs/public/roms/part7-kernel-mastery/53-kernel-patterns/` · `docs/public/images/lesson53/` ·
> `README.md` (verify only) · `99-execution-plan.md` + `05-findings.md` + roadmaps
> **Reasoning**: high — the library is new shared machinery; the four routines' state, the
> zero-page ownership, and the per-band ledgers are under independent review

### Step 6.1: Lesson 53 — Kernel Design Patterns

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 53 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 53 · AR-1–AR-7, AR-10, AR-18, AR-23,
AR-24, AR-28, AR-37
**Objective**: Deliver Lesson 53 end to end, including `include/kernel_patterns.asm`.

- [x] 6.1.1 Lesson 53 — Kernel Design Patterns: Session A freezes ST-53.1–ST-53.6 (red baseline),
  Session B implements the full artifact set including `include/kernel_patterns.asm`, Session C
  verifies to green and hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson53): Kernel Design Patterns` ✅ (completed: 2026-11-06 07:26)

**Session C record** (verify + evidence, 2026-11-06 07:26): Preflight per `vcs-lesson-production` — the library API and zero-page ownership, the four routines' cycle ledgers, the 4×48 = 192 band arithmetic, the boundary deadlines, the sprite strip rebuild, the one HMOVE, the palette/fire/SELECT clock, and the 262-line frame checked against `include/vcs.asm`, the timing reference, and the state logs; ACME forms; the library assembles with `vcs.asm` alone and fails without it. `bash scripts/verify.sh` green (implementation and review fixes); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F08F` 259/3, `VblankStart` `$F09D` 0/5, `BodyStart` `$F1AF` 37/5, `OverscanStart` `$F1F9` 229/13; `HmoveApply` `$F18F` 12/53, `HmoveDone` `$F193` 13/3. Library: `KernelFill` 11/line (10 last); `KernelPFRows` 57/row = 28.5/line (last 56; pointer carry 61); `KernelSpriteStrip` 19/line; `KernelColorRamp` 19/line. Evidence: `PatternStart` `$F136` four hits A=0,1,2,3 (the VBLANK band plan; the band-boundary alternative costs 17 cycles and would lengthen the PF band); `PatternCount` `$F10B` A=4; `PatternWrite` `$F1B1` A=$B8; `Band2Setup` `$F184` A=$18 X=$00 Y=$F3; `Band3Setup` `$F1D7` A=$30 X=$A0 Y=$00; `Band4Setup` `$F1F0` A=$30 X=$50 Y=$F3; `PaletteRead` `$F10E` A=0; `PaletteStep` `$F219` A=1 at 240, 2 at 480, 0 at 720, fire at 73; `SelectReset` `$F0F1` A=0; `SpriteRowWrite` `$F170` A=2..6. Captures from the committed ROM: `sampler.png` palette 0 — bands 0–47 fill `$B8`, 48–95 checker `$1A` (row 0 blank), 96–143 diamond `$0E` at visible 124–131, 144–191 ramp `$46/$56/$66/$76/$86/$84`; `palette.png` palette 1 — fill `$84`, PF `$C8`, diamond `$1A` at 110–117, ramp reversed; both 1010×807, no cursor, titles `Stella 7.0: "53-kernel-patterns"`. The palette capture is the auto-demo's palette 1; the fire edge is logged at frame 73. Solutions: ex1 five bands 38+38+38+38+40, `PatternCount` 5, `PatternStart` 0..4, bands at 0/38/76/114/152; ex2 `RampPhaseWrite` A=$18 (24), ramp top `$76`/bottom `$66`; ex3 `PatternStart` A=1,3,0,2, visible order PF/ramp/fill/sprite, and its fill macro stores COLUBK before the JSR (first fill line `$B8` at the left edge). Site (ST-53.6): index row 53 ✅ (rows 48–52 ✅, 54–55 Coming Soon); the page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 52, next → 54; sidebar `config.ts:130`; README unchanged; `include/kernel_patterns.asm` exists. Reviews (AR-5): the atari2600-reviewer round 1 — **1 major** (ex3's fill band stored COLUBK after the JSR, so its top line kept the ramp's colour) plus 6 minor (KernelFill's clobber, the carry arithmetic, the band-2 preload, the fire/SELECT guard, the ex1 comments, the GRP1 clear); round 2 — the ex3 fix and the minor wording, including the 10/13 return arithmetic; round 3 — no critical/major. The curriculum-auditor round 1 — **1 major** (the band-boundary paragraph said the fill returns in 10 but its parenthetical summed to 13) plus 5 minor (RampTable, the ex1 38-byte comments, the ex3 header, the library API pointer advance, the 03 ledger); round 2 — **1 major** (the same 7+6 parenthetical) plus the 15-cycle preload, the fire/SELECT sentence, the pixel-0 listing, the ex1 leftovers, and the GRP1 clear; round 3 — minor comments only. All fixed: the ex3 fill store, the 10/13 arithmetic, the 15-cycle preload, the 38-byte ex1 comments, the Y=0..2 ledger, the dirty-register contract, the defensive GRP1 wording, and the library pointer/KernelRows/return notes. Final state: **0 critical, 0 major open**. Lesson 53 is complete.


**Session A record** (freeze + red baseline, 2026-11-06 06:15): ST-53.1–ST-53.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 53. Design pins: four 48-line bands = 192; the library `include/kernel_patterns.asm` provides `KernelFill` (A=color, X=lines), `KernelPFRows` (`KernelPtr` → 3 bytes/row, `KernelRows` rows, 2 lines/row, PF0→PF1→PF2 in deadline order), `KernelSpriteStrip` (`KernelPtr` → 1 byte/line to `GRP0`), `KernelColorRamp` (`KernelPtr` → 1 color/line to `COLUBK`); the library owns `$80/$81` (`KernelPtr`) and `$82` (`KernelRows`), with `$83` free; the lesson uses `$84–$9F` counters and `$A0–$CF` for the 48-byte sprite strip; each band boundary clears PF0–PF2 and GRP0/GRP1; the sprite stamp clamps 1–40; fire cycles the palette, SELECT resets, the auto-demo cycles every 240 frames. The measured ledgers will be recorded in Session C (the plan's fill 11/line, PF rows ~28/line, sprite/ramp 19/line are the starting estimates). Exercises: five bands 38+38+38+38+40; ramp offset 0/24; the `PatternOrder` reorder. Evidence pins (AR-6): `PatternStart` A=0..3, `PatternCount`, `KernelRows`, `KernelPtr`, `PatternWrite`, `BodyStart` 37, `OverscanStart` 229, `StartFrame` 259. Red baseline confirmed: no `include/kernel_patterns.asm`, no `lessons/part7-kernel-mastery/53-kernel-patterns`, no `docs/public/images/lesson53`, no Part 7 53 ROMs, the document is the `🔒 Coming Soon` stub, index row 53 is Coming Soon, sidebar `config.ts:130`, `verify.sh` green at `669b424`. No implementation logic read (AR-2).


**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-53.1–ST-53.6, the four 48-line bands,
   the library API and `$80–$83` ownership, and the four cycle ledgers; record the red baseline.
2. **Session B — implement:** preflight; author the library, the main source, and three
   solutions; write the document; assemble, run, and capture; flip index row 53; `npm run roms`;
   `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 7: Lesson 54 — Visual Effects Cookbook

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part7-kernel-mastery/54-visual-effects-cookbook/` (4
> sources) · `docs/part7-kernel-mastery/54-visual-effects-cookbook.md` ·
> `docs/part7-kernel-mastery/index.md` (row 54) ·
> `docs/public/roms/part7-kernel-mastery/54-visual-effects-cookbook/` ·
> `docs/public/images/lesson54/` · `README.md` (verify only) · `99-execution-plan.md` +
> `05-findings.md` + roadmaps
> **Reasoning**: high — three full-screen effects, three tables, and the effect clock are a large
> integration; the starfield/road captures must be selected at the right effect

### Step 7.1: Lesson 54 — Visual Effects Cookbook

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 54 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 54 · AR-1–AR-6, AR-10, AR-19, AR-23,
AR-24, AR-38
**Objective**: Deliver Lesson 54 end to end.

- [x] 7.1.1 Lesson 54 — Visual Effects Cookbook: Session A freezes ST-54.1–ST-54.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson54): Visual Effects Cookbook` ✅ (completed: 2026-11-06 09:35)

**Session C record** (verify + evidence, 2026-11-06 09:35): Preflight per `vcs-lesson-production` — the three full-screen 192-line effects, the starfield's three planes and three 1-px stars, the rainbow's ramp/sun/horizon, the road's PF2 width/pulse, the effect clock, the one HMOVE per star/road frame, and the 262-line frame checked against `include/vcs.asm`, the timing reference, and the state logs; ACME forms. `bash scripts/verify.sh` green (implementation and review fixes); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/11 (star), 229/6 (rainbow), 229/9 (road); `HmoveApply` `$F1BE` 9/3 (star), 4/59 (road); `HmoveDone` `$F1C0` 10/3 (star), 5/3 (road); none in the rainbow. Effects: `EffectRead` A=0 at frame 1, 1 at 300, 2 at 600; `EffectTimer` 239…; `EffectStep` A=1 at 240, 2 at 480, 0 at 720; `SelectReset` A=0; `StarScroll` 1 per 2 frames; `RainbowShift` 1 per 4; `RoadScroll` 1/frame; `WidthIndex` 1 per 2; `TwinkleStep` 32. Measured ledgers: starfield 54 plain/star and 62 ship (the three 192-byte enable tables replace the per-line clears/compares; enables 37/44/51); rainbow 18/line with 27/22/33 boundaries; road 26/35/39 plain and 34/43/47 car (PF2 latch 23/32/36 before chunk 12's 39; car 43 before X=76's 48; one 192-byte PF2 plane; PF0/PF1 zero). The starfield ship is split at row 176 and stores `GRP0` unconditionally: 16 hits Y=176–191, capture top 176.5, store latch 39 before X=76's 48. Captures from the committed ROM: `starfield.png` effect 0 — gold `$1A`/white `$0E` stars, ship TIA 76–83.8 visible 176.5–191.7, three 1-px stars X=111/127/143 rows 32/96/160; `road.png` effect 2 — road `$0C`, car `$0E` TIA 76–83 visible 176.5–191.7, widths 8/10/12/14/16 at rows 0/32/96/160/190; both 1010×807, no cursor, titles `Stella 7.0: "54-visual-effects-cookbook"`. The rainbow is described in the doc and verified from the ramp/state log, not captured. Solutions: ex1 `TwinkleMaskRead` $FF/$55, 57/65 ledger, star pixels 3,336/4,752; ex2 `RainbowShiftRead` 0,1,1,2,2…; ex3 `CenterLineRead` 80/81/82, line TIA 79–79.8 in the 76–83.8 gap, road 28/37/41 and car 36/45/49. Site (ST-54.6): index row 54 ✅ (rows 48–53 ✅, row 55 Coming Soon); the page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 53, next → 55; sidebar `config.ts:131`; README unchanged. Reviews (AR-5): the atari2600-reviewer round 1 — **1 major** (the starfield ship store landed after P0's pixels; the ship rendered one line low) plus 11 minor (the PF slots, the road PF2 order, the inner/outer edge, the PF1 claim, the star X, the exercise ledgers, the ex3 preload, the horizon sliver, the why-not-ball, the doc numbers); round 2 — the major fixed and no critical/major, 4 minor residuals. The curriculum-auditor round 1 — **1 major** (the same ship/store; the 16-line claim was false) plus 7 minor (doc:72 768, the clear/enable numbers, the 43-cycle margin, the PF1 claim, the twinkle register, the effect-1 paragraph, the unmute sentence); round 2 — the major fixed and no critical/major, 7 minor residuals. All fixed: the split starfield with enable tables (ship 176–191), the PF-first order, the road PF2-first/PF0/PF1 removal, the ex3 preload mask, the measured 54/62 and 26–47 ledgers, the doc's 192-byte PF2/7-px horizon/58-cycle margin, the effect-1 disclosure, the unmute sentence, the ex1/ex3 cycle counts, the build headers, the RAM maps, the twinkle 3-cycle note, the base road 38, and the plan's 192-entry/64-entry wording. Final state: **0 critical, 0 major open**. Lesson 54 is complete.


**Session A record** (freeze + red baseline, 2026-11-06 07:30): ST-54.1–ST-54.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 54. Design pins: three effects, full-screen 192 lines each; effect 0 starfield uses three page-aligned 256-byte star planes scrolled one line every two frames (`StarScroll`), a 16-byte ship strip on P0 at the bottom, and three bright stars on the ball/missiles at fixed positions; effect 1 rainbow uses a 192-byte `COLUBK` ramp, a centred playfield sun block at rows 40–88, and a black horizon; effect 2 pseudo-3D road uses one page-aligned 192-byte PF2 plane with the road centred and its base width growing from 4 to 12 chunks plus a 64-entry pulse to 16 (`WidthIndex`), and a 16-byte car on P0; `Effect` 0/1/2, `EffectTimer` 240, fire advances, SELECT resets; the per-effect ledgers will be measured (the plan's starfield 40/line, rainbow 18/line, road 40/line are the starting estimates; the measured values are starfield 54/62, rainbow 18 (27/22/33 at the boundaries), road 26–47). Exercises: per-star twinkle mask, 2-frame rainbow, ball centre line. Evidence pins (AR-6): `Effect` A=0/1/2, `EffectTimer`, `StarScroll`, `RainbowShift`, `RoadScroll`, `WidthIndex`, `Twinkle`, `BodyStart` 37, `OverscanStart` 229, `StartFrame` 259. Red baseline confirmed: no `lessons/part7-kernel-mastery/54-visual-effects-cookbook`, no `docs/public/images/lesson54`, no Part 7 54 ROMs, the document is the `🔒 Coming Soon` stub, index row 54 is Coming Soon, sidebar `config.ts:131`, `verify.sh` green at `d01d2b6`. No implementation logic read (AR-2).


**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-54.1–ST-54.6, the three effects, the
   240-frame clock, the starfield/rainbow/road ledgers, and the capture states; record the red
   baseline.
2. **Session B — implement:** preflight; author the main source and three solutions; write the
   document; assemble, run, and capture; flip index row 54; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 8: Lesson 55 — Scrolling Text Marquee

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part7-kernel-mastery/55-scrolling-text-marquee/` (4
> sources) · `docs/part7-kernel-mastery/55-scrolling-text-marquee.md` ·
> `docs/part7-kernel-mastery/index.md` (row 55) ·
> `docs/public/roms/part7-kernel-mastery/55-scrolling-text-marquee/` ·
> `docs/public/images/lesson55/` · `README.md` (verify only) · `99-execution-plan.md` +
> `05-findings.md` + roadmaps (progress/finish)
> **Reasoning**: high — the 48-pixel kernel is reused for text; the 8-phase pre-shifted table,
> the 48-byte buffer fill, and the 1-px scroll are cycle- and data-sensitive

### Step 8.1: Lesson 55 — Scrolling Text Marquee

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 55 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 55 · AR-1–AR-6, AR-10, AR-20, AR-23,
AR-24, AR-31, AR-39
**Objective**: Deliver Lesson 55 end to end, close Part 7, and update the roadmaps.

- [ ] 8.1.1 Lesson 55 — Scrolling Text Marquee: Session A freezes ST-55.1–ST-55.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson55): Scrolling Text Marquee`

**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-55.1–ST-55.6, the 9-line text zone +
   183-line starfield, the 8-phase pre-shifted table, the 48-byte fill, and the 1-px scroll;
   record the red baseline.
2. **Session B — implement:** preflight; author the main source and three solutions; write the
   document; assemble, run, and capture; flip index row 55; `npm run roms`; `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Part 7 completion gate (required before 8.1.1 is `[x]`):** confirm index row 55 is already
   ✅ in the Lesson 55 commit, confirm all rows 48–55 ✅, update the feature roadmap (RD-07 Done,
   7/11 RDs), the portfolio (7 plans done), and the plan completion note; final `verify.sh`; commit
   and push (AR-26).

- [ ] 8.1.1a Part 7 completion gate (a gate, not a ninth lesson task): index rows 48–55 ✅, RD-07
  Done, feature roadmap 7/11, portfolio 7 plans, all completion criteria ticked, final `verify.sh`
  green

---

## Plan-Level Verification

| Check | Command | Pass condition |
| --- | --- | --- |
| ROM drift + docs | `bash scripts/verify.sh` | `=== VERIFY PASSED ===` |
| Part 7 artifacts | `find docs/public/roms/part7-kernel-mastery -name '*.bin' \| wc -l` | 32 |
| Screenshots | `find docs/public/images/lesson{48..55} -name '*.png' \| wc -l` | 16 |
| Documents | `grep -l '## Key Takeaways' docs/part7-kernel-mastery/4*.md docs/part7-kernel-mastery/5*.md \| wc -l` | 8 |
| Roadmap | `grep 'RD-07' codeops/features/curriculum/00-roadmap.md` | `Done` / `✅` |
| Reviews | [05-findings.md](05-findings.md) | 0 critical, 0 major open |
| Frame | state logs | every lesson's fixed path `BodyStart` 37 and `OverscanStart` 229 (262 lines) |
| HMOVE | state logs | each lesson that positions sprites (48–55) reports its measured `HmoveDone` in HBLANK; 53's sprite band and 54's ship/car are included |
| Lines | state logs | 48's split 96+96 and full modes; 49's 96×2; 50's 9+8+174+1; 51's 8+184; 52's 192; 53's 4×48; 54's three 192-line effects; 55's 9+183 |

## Completion Criteria

- [ ] All eight phases marked `[x]` with Session A/C records.
- [ ] 32 committed 4,096-byte ROMs, 8 documents, 16 screenshots.
- [ ] `include/kernel_patterns.asm` and `demo-48.asm` shipped.
- [ ] Part 7 index rows 48–55 all ✅ Complete.
- [ ] `bash scripts/verify.sh` green at the final commit.
- [ ] Both specialists report no critical/major open for every lesson.
- [ ] No dead code, no unused symbols/tables; security is N/A (static content, no input).
- [ ] The post-completion re-analysis (plan/skill protocol) is recorded.
- [ ] RD-07 Done; feature roadmap 7/11 RDs; portfolio 7 plans done.
