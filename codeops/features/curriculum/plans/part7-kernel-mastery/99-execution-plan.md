# Execution Plan: Part 7 — Kernel Mastery (Lessons 48–55)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-06 02:05
> **Progress**: 2/8 tasks (25%)
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

- [ ] 3.1.1 Lesson 50 — Multi-Zone Kernel: Session A freezes ST-50.1–ST-50.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson50): Multi-Zone Kernel`

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

- [ ] 4.1.1 Lesson 51 — Flicker Sprites: Session A freezes ST-51.1–ST-51.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson51): Flicker Sprites`

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
> **Reasoning**: high — the 1-line kernel's 40-cycle loop, the three page-aligned 256-byte
> planes, and the 1-px HMOVE ship are measured claims; the 4-px playfield / 1-px sprite split
> must be honest

### Step 5.1: Lesson 52 — Fine Scrolling

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 52 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 52 · AR-1–AR-6, AR-10, AR-17, AR-23,
AR-24, AR-30, AR-36
**Objective**: Deliver Lesson 52 end to end.

- [ ] 5.1.1 Lesson 52 — Fine Scrolling: Session A freezes ST-52.1–ST-52.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson52): Fine Scrolling`

**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-52.1–ST-52.6, the 256-row world, the
   1-line 40-cycle ledger, the page-aligned planes, the 1-px ship step, and the playfield/sprite
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

- [ ] 6.1.1 Lesson 53 — Kernel Design Patterns: Session A freezes ST-53.1–ST-53.6 (red baseline),
  Session B implements the full artifact set including `include/kernel_patterns.asm`, Session C
  verifies to green and hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson53): Kernel Design Patterns`

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

- [ ] 7.1.1 Lesson 54 — Visual Effects Cookbook: Session A freezes ST-54.1–ST-54.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson54): Visual Effects Cookbook`

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
