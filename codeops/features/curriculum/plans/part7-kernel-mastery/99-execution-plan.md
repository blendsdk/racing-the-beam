# Execution Plan: Part 7 — Kernel Mastery (Lessons 48–55)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-05 22:47
> **Progress**: 0/8 tasks (0%)
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

> **Phase baseline tree**: _(recorded at phase start)_
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

- [ ] 1.1.1 Lesson 48 — Introduction to Kernels: Session A freezes ST-48.1–ST-48.6 (red baseline),
  Session B implements the full artifact set (including the AR-10 index rebuild), Session C
  verifies to green and hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson48): Introduction to Kernels`

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
> **Reasoning**: high — the 62-cycle two-line kernel is the part's core pattern; the row table,
> the color ramps, and the sprite strips must fit the 152-cycle pair

### Step 2.1: Lesson 49 — The 2-Line Kernel

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 49 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 49 · AR-1–AR-6, AR-10, AR-14, AR-23,
AR-24, AR-33
**Objective**: Deliver Lesson 49 end to end.

- [ ] 2.1.1 Lesson 49 — The 2-Line Kernel: Session A freezes ST-49.1–ST-49.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson49): The 2-Line Kernel`

**Session sub-steps:**

1. **Session A — freeze the specification:** re-affirm ST-49.1–ST-49.6, the 96 rows × 2 lines,
   the 62-cycle ledger, the mountain/sky tables, the figure/bird strips, and the joystick clamp;
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
