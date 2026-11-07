# Execution Plan: Part 9 — The DSL Path (Lessons 66–68)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-07 11:45
> **Progress**: 0/4 tasks (0%)
> **CodeOps Artifact Schema**: 1

## Overview

Three phases, one per lesson, strictly sequential — 66 establishes the real bB compilation and
the analysis vocabulary; 67 turns a repeated wave pattern into a DSL and a generator; 68 builds
the kernel framework and the three layouts. Every phase is one task run through the mandatory
three-session ordering: Session A freezes that lesson's specification cases and records a red
baseline, Session B implements the full artifact set, and Session C verifies against the frozen
cases and hardens under independent review (AR-2, AR-5). `bash scripts/verify.sh` is the gate for
every phase (AR-4). bB, generator, framework-budget, and frame claims carry the state-log +
static-ledger + pixel evidence of AR-6/AR-22; every screenshot is pixel-checked against the lesson
geometry (AR-7, AR-22).

**🚨 Update this document after EACH completed task!**

**Session record slots:** each task gets a `**Session A record**` paragraph after its task line
(freeze + red baseline + design pins) and a **Session C record** paragraph after the Session
sub-steps. The per-lesson findings are appended to [05-findings.md](05-findings.md); the plan-level
preflight findings live in [00-preflight-report.md](00-preflight-report.md). The plan is not
executable until the preflight report exists and the roadmap row reads `Executing`. The push mode
is authorized by the user's directive to execute RD-09 and the Part 1–8 practice (AR-25).

---

## Implementation Phases

| Phase | Title | Tasks |
| ----- | ----- | ----- |
| 1 | Lesson 66 — Analyzing batari BASIC | 1 |
| 2 | Lesson 67 — Automatable Patterns | 1 |
| 3 | Lesson 68 — Kernel Architecture | 1 |
| 4 | Part 9 completion gate | 1 |

**Total: 3 lesson tasks + 1 completion gate.**

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

## Phase 1: Lesson 66 — Analyzing batari BASIC

> **Phase baseline tree**: the plan+preflight commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part9-dsl-path/66-analyzing-batari-basic/` (demo, `.bas`,
> generated listing) · `docs/part9-dsl-path/66-analyzing-batari-basic.md` ·
> `docs/part9-dsl-path/index.md` (row 66) ·
> `docs/public/roms/part9-dsl-path/66-analyzing-batari-basic/` (demo + bB reference) ·
> `docs/public/images/lesson66/` (3 demo + 1 reference) · `99-execution-plan.md` +
> `05-findings.md` + roadmaps
> **Reasoning**: high — the first Part 9 lesson establishes the real bB evidence, the demo/bB
> separation, and the analysis vocabulary the next two lessons use

### Step 1.1: Lesson 66 — Analyzing batari BASIC

**Reference**: [03 §Lesson 66](03-lesson-specs.md) · AR-3, AR-9–AR-12, AR-23
**Objective**: ship the three-lens demo, the committed bB 1.9 reference, and the document that
maps the generated code to the 6502/TIA concepts.

- [ ] 1.1.1 Lesson 66 — Analyzing batari BASIC: Session A freezes ST-66.1–ST-66.6 (red baseline),
  Session B implements the demo, the bB reference, and the document, Session C verifies to green
  and hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson66): Analyzing batari BASIC`

**Session A record**:

**Session B record**:

**Session C record**:

**Deliverables**:
- [ ] `demo-66.asm` (4,096) with RUN/ZONES/VARS lenses and SELECT.
- [ ] `lesson66.bas`, `lesson66.generated.txt`, `lesson66-bb.bin` (4,096) with bB 1.9 provenance.
- [ ] `docs/part9-dsl-path/66-analyzing-batari-basic.md` (six-section template, Full Source
  verbatim, 3 demo images + bB reference player, three analysis exercises answered).
- [ ] Index row 66 ✅; prev 65 / next 67; sidebar; README unchanged.
- [ ] `verify.sh` green; both reviews 0 critical/major.

**Verify**: `bash scripts/verify.sh`

---

## Phase 2: Lesson 67 — Automatable Patterns

> **Phase baseline tree**: the Lesson 66 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part9-dsl-path/67-automatable-patterns/` (main + 3
> solutions + generator + specs + generated include) · `docs/part9-dsl-path/67-automatable-patterns.md` ·
> `docs/part9-dsl-path/index.md` (row 67) ·
> `docs/public/roms/part9-dsl-path/67-automatable-patterns/` ·
> `docs/public/images/lesson67/` (2 captures) · `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the generator, the DSL, and the playable engine must agree on every field;
> the lesson's claims rest on the committed generated include

### Step 2.1: Lesson 67 — Automatable Patterns

**Reference**: [03 §Lesson 67](03-lesson-specs.md) · AR-13–AR-15, AR-23
**Objective**: ship the wave-spec DSL, the Python generator, the playable wave lab, and the
generated levels.

- [ ] 2.1.1 Lesson 67 — Automatable Patterns: Session A freezes ST-67.1–ST-67.7 (red baseline),
  Session B implements the generator, the spec language, the ROM, the three solutions, and the
  document, Session C verifies to green and hardens; commit via the `git-commit` skill in push
  mode — `feat(lesson67): Automatable Patterns`

**Session A record**:

**Session B record**:

**Session C record**:

**Deliverables**:
- [ ] `67-automatable-patterns.asm` (4,096) + `exercise-01/02/03-solution.asm` (4,096 each).
- [ ] `lesson67-generate.py` with `--check`; `waves-a.txt`, `waves-b.txt`;
  `generated-levels.inc`.
- [ ] `docs/part9-dsl-path/67-automatable-patterns.md` (DSL grammar, generator, engine, two
  levels, 2 images, 1 player, three exercises with solutions).
- [ ] Index row 67 ✅; prev 66 / next 68; sidebar; README unchanged.
- [ ] `verify.sh` green; both reviews 0 critical/major.

**Verify**: `bash scripts/verify.sh`

---

## Phase 3: Lesson 68 — Kernel Architecture

> **Phase baseline tree**: the Lesson 67 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `include/kernel_framework.asm` ·
> `lessons/part9-dsl-path/68-kernel-architecture/` (main + 3 solutions) ·
> `docs/part9-dsl-path/68-kernel-architecture.md` ·
> `docs/part9-dsl-path/index.md` (row 68) ·
> `docs/public/roms/part9-dsl-path/68-kernel-architecture/` ·
> `docs/public/images/lesson68/` (3 captures) · `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the framework's budget, boundary line, dispatch tax, and RAM ownership are
> the lesson's correctness core; a silent 191/193 or a `$80–$82` collision would break the frame

### Step 3.1: Lesson 68 — Kernel Architecture

**Reference**: [03 §Lesson 68](03-lesson-specs.md) · AR-16–AR-21, AR-23
**Objective**: ship the zone framework, the three-layout demo, the three solutions, and the
document that teaches the kernel architecture.

- [ ] 3.1.1 Lesson 68 — Kernel Architecture: Session A freezes ST-68.1–ST-68.6 (red baseline),
  Session B implements the framework, the layouts, the solutions, and the document, Session C
  verifies to green and hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson68): Kernel Architecture`

**Session A record**:

**Session B record**:

**Session C record**:

**Deliverables**:
- [ ] `include/kernel_framework.asm` (API, budget, boundary contract, dispatcher macro).
- [ ] `68-kernel-architecture.asm` (4,096) + `exercise-01/02/03-solution.asm` (4,096 each).
- [ ] `docs/part9-dsl-path/68-kernel-architecture.md` (framework API, three layouts, 3 images, 1
  player, three exercises with solutions).
- [ ] Index row 68 ✅; prev 67 / next 69; sidebar; README unchanged.
- [ ] `verify.sh` green; both reviews 0 critical/major.

**Verify**: `bash scripts/verify.sh`

---

## Phase 4: Part 9 Completion Gate

> **Phase baseline tree**: the Lesson 68 commit (clean tree at gate start)
> **Expected modifications**: `codeops/features/curriculum/plans/part9-dsl-path/00-index.md`,
> `01-requirements.md`, `02-current-state.md`, `05-findings.md`, `99-execution-plan.md`,
> `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md`,
> `codeops/features/curriculum/requirements/RD-09-part9-dsl-path.md`
> **Reasoning**: medium — the gate is bookkeeping and a full re-check; the lesson content is frozen

### Step 4.1: Part 9 completion gate (a gate, not a fourth lesson)

- [ ] 4.1.1 Part 9 completion gate: 9 ACME sources/ROMs + 1 bB reference, 3 docs, 9 screenshots,
  `npm run roms` 252, 253 total `.bin`, index 66–68 ✅, RD-09 Done, feature roadmap 9/11, portfolio
  9 plans, all completion criteria ticked, final `verify.sh` green; commit via the `git-commit`
  skill in push mode — `docs(curriculum): complete Part 9 (lessons 66-68)`

**Completion gate record**:

---

## Dependencies

```
Plan + preflight
      ↓
Lesson 66 (bB evidence)
      ↓
Lesson 67 (generator + DSL)
      ↓
Lesson 68 (framework + layouts)
      ↓
Part 9 completion gate
```

---

## Completion Criteria

- [ ] All three phases marked `[x]` with Session A/C records.
- [ ] 9 ACME sources/ROMs (1 demo + 4 + 4) + 1 bB reference ROM, all 4,096 bytes.
- [ ] 3 documents, 9 screenshots (8 lesson captures + 1 bB reference).
- [ ] Lesson 66: three lenses, bB listing, reference player, three analysis exercises.
- [ ] Lesson 67: generator `--check` clean, two levels, three solutions.
- [ ] Lesson 68: `+kf_end` 192 for every layout, three layouts, three solutions.
- [ ] Part 9 index rows 66–68 all ✅ Complete.
- [ ] `bash scripts/verify.sh` green at the final commit (252 ACME sources).
- [ ] Both specialists report no critical/major open for every lesson.
- [ ] No dead code, no unused symbols/tables; security N/A (static content, no input).
- [ ] The post-completion re-analysis is recorded.
- [ ] RD-09 Done; feature roadmap 9/11 RDs; portfolio 9 plans done.

## Post-Completion Analysis

_To be filled at the gate._
