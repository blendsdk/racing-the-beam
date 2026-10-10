# Execution Plan: Part 1 — The 6502 CPU (Lessons 07–11)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-10-10 19:28
> **Progress**: 5/5 tasks (100%)
> **CodeOps Artifact Schema**: 1

## Overview

Five phases, one per lesson, strictly sequential — each lesson is the next one's prerequisite (AR-1). Every phase is one task run through the mandatory three-session ordering: Session A freezes that lesson's specification cases, Session B implements the full artifact set, and Session C verifies against the frozen cases and hardens under independent review (AR-2, AR-3, AR-5). `bash scripts/verify.sh` is the gate for every phase (AR-4).

**🚨 Update this document after EACH completed task!**

---

## Implementation Phases

| Phase | Title | Tasks |
| ----- | ----- | ----- |
| 1 | Lesson 07 — Branches and Loops | 1 |
| 2 | Lesson 08 — The Stack and Subroutines | 1 |
| 3 | Lesson 09 — Bitwise Operations | 1 |
| 4 | Lesson 10 — Addressing Modes | 1 |
| 5 | Lesson 11 — Lookup Tables | 1 |

**Total: 5 tasks across 5 phases** (no fabricated hour estimates — scope is bounded by the task-size criteria of the make-plan quality checklist)

> **⚠️ EXECUTION RULE — APPLIES TO EVERY AGENT EXECUTING THIS PLAN:**
>
> The task checkboxes in the phase sections below are the **single source of truth** for progress. Every task line appears exactly once in this document. The executing agent MUST:
>
> 1. **On implementation:** mark the task `[~]` with a timestamp — `- [~] 1.1.1 Task description ⏳ (implemented: YYYY-MM-DD HH:MM)`
> 2. **On verify pass:** promote it to `[x]` — `- [x] 1.1.1 Task description ✅ (completed: YYYY-MM-DD HH:MM)`
> 3. **Update the Progress header** (`> **Progress**: X/Y tasks (Z%)`) and the Last Updated stamp after EVERY task — never batch updates. Only `[x]` counts as complete.
> 4. **Resume** by scanning the phase sections top-to-bottom: the first `[~]` task is resumed first, else the first `[ ]` task.
> 5. **On blocker:** mark the task `[!]` and append `Blocked: <short reason>` on the same line. The plan lifecycle is `Ready`, `Executing`, `Done`, or `Blocked`, derived from these markers.
>
> Timestamps come from `date '+%Y-%m-%d %H:%M'` — never invented. Failure to keep the marks current means progress is invisible after crashes, context resets, or session handoffs.


## Phase 1: Lesson 07 — Branches and Loops

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Reasoning**: high — correctness-sensitive 6502 teaching content under independent hardware review

### Step 1.1: Lesson 07 — Branches and Loops

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 07 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 07 · AR-2, AR-3, AR-5, AR-6, AR-8
**Objective**: Deliver lesson 07 end to end through the mandatory three sessions.

- [x] 1.1.1 Lesson 07 — Branches and Loops: Session A freezes ST-07.1–ST-07.5 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson07): Branches and Loops` ✅ (completed: 2026-10-10 15:14)

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-07.1–ST-07.5 with their expected outcomes and evidence methods ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 07); record the red baseline (ROM, document, images, index update absent). No implementation logic read (AR-3).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part1-6502-cpu/07-branches-and-loops/07-branches-and-loops.asm` + its three solutions; write `docs/part1-6502-cpu/07-branches-and-loops.md`; capture both screenshots; run `npm run roms`; update part index row 07 and prev/next; confirm `README.md` needs no change (AR-5, AR-6, AR-7).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-07.* confirmed with recorded evidence; edge checks ([07-testing-strategy.md](07-testing-strategy.md) §Implementation Tests) run; both specialist reviews report no critical/major findings (AR-5).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson07): Branches and Loops` (AR-8; under exec-plan's auto-commit mode).


## Phase 2: Lesson 08 — The Stack and Subroutines

> **Phase baseline tree**: clean tree at `0f34e23` (recorded 2026-10-10 15:35)
> **Reasoning**: high — correctness-sensitive 6502 teaching content under independent hardware review

### Step 2.1: Lesson 08 — The Stack and Subroutines

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 08 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 08 · AR-2, AR-3, AR-5, AR-6, AR-8
**Objective**: Deliver lesson 08 end to end through the mandatory three sessions.

- [x] 2.1.1 Lesson 08 — The Stack and Subroutines: Session A freezes ST-08.1–ST-08.5 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson08): The Stack and Subroutines` ✅ (completed: 2026-10-10 16:21)

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-08.1–ST-08.5, including the exact SP values to observe ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 08); record the red baseline. No implementation logic read (AR-3).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part1-6502-cpu/08-stack-and-subroutines/08-stack-and-subroutines.asm` + its three solutions; write `docs/part1-6502-cpu/08-stack-and-subroutines.md`; capture `subroutine-bands.png`; run `npm run roms`; update part index row 08 and prev/next (AR-5, AR-6, AR-7).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-08.* confirmed; stack-balance edge checks run; both specialist reviews report no critical/major findings (AR-5).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson08): The Stack and Subroutines` (AR-8).


## Phase 3: Lesson 09 — Bitwise Operations

> **Phase baseline tree**: clean tree at `3047fb1` (recorded 2026-10-10 17:23)
> **Reasoning**: high — correctness-sensitive 6502 teaching content under independent hardware review

### Step 3.1: Lesson 09 — Bitwise Operations

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 09 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 09 · AR-2, AR-3, AR-5, AR-6, AR-8
**Objective**: Deliver lesson 09 end to end through the mandatory three sessions.

- [x] 3.1.1 Lesson 09 — Bitwise Operations: Session A freezes ST-09.1–ST-09.5 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson09): Bitwise Operations` ✅ (completed: 2026-10-10 18:00)

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-09.1–ST-09.5, including the single-bit patterns and carry behavior to observe ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 09); record the red baseline. No implementation logic read (AR-3).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part1-6502-cpu/09-bitwise-operations/09-bitwise-operations.asm` + its three solutions; write `docs/part1-6502-cpu/09-bitwise-operations.md`; capture `bit-ladder-bottom.png` and `bit-ladder-top.png`; run `npm run roms`; update part index row 09 and prev/next (AR-5, AR-6, AR-7).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-09.* confirmed; mask/shift and zero-page-wrap edge checks run; both specialist reviews report no critical/major findings (AR-5).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson09): Bitwise Operations` (AR-8).


## Phase 4: Lesson 10 — Addressing Modes

> **Phase baseline tree**: clean tree at `5a1fd16` (recorded 2026-10-10 18:18)
> **Reasoning**: high — correctness-sensitive 6502 teaching content under independent hardware review

### Step 4.1: Lesson 10 — Addressing Modes

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 10 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 10 · AR-2, AR-3, AR-5, AR-6, AR-8
**Objective**: Deliver lesson 10 (theory lesson) end to end through the mandatory three sessions.

- [x] 4.1.1 Lesson 10 — Addressing Modes: Session A freezes ST-10.1–ST-10.5 (red baseline), Session B implements the lesson ROM, `demo-10.asm`, and the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson10): Addressing Modes` ✅ (completed: 2026-10-10 18:53)

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-10.1–ST-10.5, including the demo's band → mode mapping and the `$82` debugger experiment ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 10); record the red baseline. No implementation logic read (AR-3).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part1-6502-cpu/10-addressing-modes/10-addressing-modes.asm`, the standalone `demo-10.asm`, and three solutions; write `docs/part1-6502-cpu/10-addressing-modes.md` with the mode table; capture `addressing-modes.png` and `addressing-mode-ladder.png`; run `npm run roms`; update part index row 10 and prev/next (AR-5, AR-6, AR-7).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-10.* confirmed; zero-page-wrap and frame-integrity edge checks run; both specialist reviews report no critical/major findings (AR-5).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson10): Addressing Modes` (AR-8).


## Phase 5: Lesson 11 — Lookup Tables

> **Phase baseline tree**: clean tree at `cc60ceb` (recorded 2026-10-10 18:56)
> **Reasoning**: high — correctness-sensitive 6502 teaching content under independent hardware review

### Step 5.1: Lesson 11 — Lookup Tables

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 11 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 11 · AR-2, AR-3, AR-5, AR-6, AR-8
**Objective**: Deliver lesson 11 end to end through the mandatory three sessions and close Part 1.

- [x] 5.1.1 Lesson 11 — Lookup Tables: Session A freezes ST-11.1–ST-11.5 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson11): Lookup Tables` ✅ (completed: 2026-10-10 19:28)

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-11.1–ST-11.5, including the table bytes and wrap behavior to observe ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 11); record the red baseline. No implementation logic read (AR-3).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part1-6502-cpu/11-lookup-tables/11-lookup-tables.asm` + its three solutions; write `docs/part1-6502-cpu/11-lookup-tables.md`; capture `lookup-wave.png` and `lookup-wave-shifted.png`; run `npm run roms`; update part index row 11 and prev/next (next links forward to Lesson 12); confirm all five index rows ✅ and `README.md` still needs no change (AR-5, AR-6, AR-7).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-11.* confirmed; table-bounds and frame-integrity edge checks run; both specialist reviews report no critical/major findings; Part 1 is complete (AR-5).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson11): Lookup Tables` (AR-8).

---

## Dependencies

```
Phase 1 (Lesson 07) → Phase 2 (Lesson 08) → Phase 3 (Lesson 09) → Phase 4 (Lesson 10) → Phase 5 (Lesson 11)
```

---

## Success Criteria

**Feature is complete when:**

1. ✅ All phases completed (5/5 tasks `[x]`)
2. ✅ `bash scripts/verify.sh` passing with all five lessons included
3. ✅ No warnings/errors (clean ACME assembly, clean docs build)
4. ✅ No dead code — every solution and demo file is referenced by its lesson; no stray artifacts
5. ✅ Security — N/A: static lesson content and local ROMs only; no user input, secrets, or server-side processing
6. ✅ Documentation updated — lesson documents, part index, and the Part 1 README sync verified
7. ✅ Code reviewed — `atari2600-reviewer` and `curriculum-auditor`, no critical/major findings per lesson
8. ✅ Post-completion project re-analysis (handled by the exec-plan skill)
