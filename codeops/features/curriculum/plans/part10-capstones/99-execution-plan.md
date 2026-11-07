# Execution Plan: Part 10 — Capstone Projects (Lessons 69–72)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-07 19:20
> **Progress**: 0/5 tasks (0%)
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

- [ ] 1.1.1 Lesson 69 — Capstone 1: Pong: Session A freezes ST-69.1–ST-69.8 (red baseline),
  Session B implements the game, the custom score, the row table, the three solutions, and the
  document, Session C verifies to green and hardens; commit via the `git-commit` skill in push
  mode — `feat(lesson69): Capstone 1 — Pong`

**Session A record**:

**Session B record**:

**Session C record**:

**Deliverables**:
- [ ] `69-pong.asm` (4,096) + `exercise-01/02/03-solution.asm` (4,096 each).
- [ ] The 89-byte row table, the custom one-digit score, the two-player input, the auto-demo.
- [ ] `docs/part10-capstones/69-pong.md` (six-section template, Full Source verbatim, 3 images,
  1 player, three exercises with solutions).
- [ ] Part 10 index rebuilt to the Part 7/8/9 format; row 69 ✅; prev 68 / next 70; sidebar; README
  unchanged.
- [ ] `verify.sh` green; both reviews 0 critical/major.

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

- [ ] 2.1.1 Lesson 70 — Capstone 2: Breakout: Session A freezes ST-70.1–ST-70.8 (red baseline),
  Session B implements the brick field, the collision math, the levels, the three solutions, and
  the document, Session C verifies to green and hardens; commit via the `git-commit` skill in push
  mode — `feat(lesson70): Capstone 2 — Breakout`

**Session A record**:

**Session B record**:

**Session C record**:

**Deliverables**:
- [ ] `70-breakout.asm` (4,096) + `exercise-01/02/03-solution.asm` (4,096 each).
- [ ] The brick map (6 bytes), the 64×3 PF table, the dual-zone ball, the score library, three
  levels, three lives, the auto-demo.
- [ ] `docs/part10-capstones/70-breakout.md` (six-section template, Full Source verbatim, 3 images,
  1 player, three exercises with solutions).
- [ ] Index row 70 ✅; prev 69 / next 71; sidebar; README unchanged.
- [ ] `verify.sh` green; both reviews 0 critical/major.

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

- [ ] 3.1.1 Lesson 71 — Capstone 3: Maze Explorer: Session A freezes ST-71.1–ST-71.9 (red
  baseline), Session B implements the generator, the mirror maze, the AI, the keys/win/lose, the
  three solutions, and the document, Session C verifies to green and hardens; commit via the
  `git-commit` skill in push mode — `feat(lesson71): Capstone 3 — Maze Explorer`

**Session A record**:

**Session B record**:

**Session C record**:

**Deliverables**:
- [ ] `71-maze-explorer.asm` (4,096) + `exercise-01/02/03-solution.asm` (4,096 each).
- [ ] `lesson71-generate.py` with `--check`; `maze-spec.txt`; `maze-data.inc`.
- [ ] `docs/part10-capstones/71-maze-explorer.md` (six-section template, Full Source verbatim,
  3 images, 1 player, three exercises with solutions).
- [ ] Index row 71 ✅; prev 70 / next 72; sidebar; README unchanged.
- [ ] `verify.sh` green; both reviews 0 critical/major.

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
