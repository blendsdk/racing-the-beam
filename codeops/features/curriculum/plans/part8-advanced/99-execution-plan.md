# Execution Plan: Part 8 — Advanced Topics (Lessons 56–65)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-06 11:00
> **Progress**: 0/10 tasks (0%)
> **CodeOps Artifact Schema**: 1

## Overview

Ten phases, one per lesson, strictly sequential — 56 introduces banking, 57 adds the Superchip
RAM on the same F8 base, 58/59 are CPU-level labs independent of the mapper, 60 uses the F8-style
layout with the DPC display processor, 61 is a 4K data lesson, 62/63/64 are method/production
lessons whose artifact is a demo, and 65 closes the part with the PAL/NTSC frame selector. Every
phase is one task run through the mandatory three-session ordering: Session A freezes that
lesson's specification cases, Session B implements the full artifact set, and Session C verifies
against the frozen cases and hardens under independent review (AR-2, AR-5).
`bash scripts/verify.sh` is the gate for every phase (AR-4). Mapper, RAM-window, opcode,
RAM-routine, DPC-fetcher, decompressor, and frame claims carry the state-log + static-ledger
evidence of AR-6/AR-23; every screenshot is pixel-checked against the lesson geometry (AR-7,
AR-23).

**🚨 Update this document after EACH completed task!**

**Session record slots:** each task gets a `**Session A record**` paragraph after its task line
(freeze + red baseline + design pins) and a **Session C record** paragraph after the Session
sub-steps. The per-lesson findings are appended to [05-findings.md](05-findings.md); the plan-level
preflight findings live in [00-preflight-report.md](00-preflight-report.md). The plan is not
executable until the preflight report exists and the roadmap row reads `Plan Preflighted`. The
push mode is authorized by the user's directive to execute RD-08 and the Part 1–7 practice (AR-26).

---

## Implementation Phases

| Phase | Title | Tasks |
| ----- | ----- | ----- |
| 1 | Lesson 56 — Bankswitching | 1 |
| 2 | Lesson 57 — Superchip | 1 |
| 3 | Lesson 58 — Illegal Opcodes | 1 |
| 4 | Lesson 59 — Self-Modifying Code | 1 |
| 5 | Lesson 60 — DPC and DPC+ | 1 |
| 6 | Lesson 61 — Compression & Data Encoding | 1 |
| 7 | Lesson 62 — Reverse Engineering a Classic Game | 1 |
| 8 | Lesson 63 — Modern Homebrew | 1 |
| 9 | Lesson 64 — Building Your Own Cartridge | 1 |
| 10 | Lesson 65 — PAL/NTSC Universal ROM | 1 |

**Total: 10 tasks across 10 phases; plus the Part 8 completion gate.**

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

## Phase 1: Lesson 56 — Bankswitching

> **Phase baseline tree**: the plan+preflight commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/56-bankswitching/` (4 sources) ·
> `docs/part8-advanced/56-bankswitching.md` · `docs/part8-advanced/index.md` (rebuild + row 56) ·
> `docs/public/roms/part8-advanced/56-bankswitching/` ·
> `docs/public/images/lesson56/` (2 captures) · `README.md` (verify only) ·
> `99-execution-plan.md` + `05-findings.md` + roadmaps
> **Reasoning**: high — the first Part 8 lesson establishes the bank layout, the start bank, and
> the duplicate trampoline that 57 and 60 reuse

### Step 1.1: Lesson 56 — Bankswitching

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 56 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 56 · AR-1–AR-6, AR-8–AR-10, AR-23,
AR-25, AR-31, AR-33
**Objective**: Deliver Lesson 56 end to end.

- [ ] 1.1.1 Lesson 56 — Bankswitching: Session A freezes ST-56.1–ST-56.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson56): Bankswitching`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 2: Lesson 57 — Superchip

> **Phase baseline tree**: the Lesson 56 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/57-superchip/` (4 sources) ·
> `docs/part8-advanced/57-superchip.md` · index row 57 ·
> `docs/public/roms/part8-advanced/57-superchip/` · `docs/public/images/lesson57/` (2 captures) ·
> `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the F8SC signature, the `$F100` code start, and the RAM windows are easy
> to get subtly wrong

### Step 2.1: Lesson 57 — Superchip

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 57 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 57 · AR-1–AR-6, AR-8–AR-11, AR-23,
AR-25
**Objective**: Deliver Lesson 57 end to end.

- [ ] 2.1.1 Lesson 57 — Superchip: Session A freezes ST-57.1–ST-57.6 (red baseline), Session B
  implements the full artifact set, Session C verifies to green and hardens; commit via the
  `git-commit` skill in push mode — `feat(lesson57): Superchip`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 3: Lesson 58 — Illegal Opcodes

> **Phase baseline tree**: the Lesson 57 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/58-illegal-opcodes/` (4 sources) ·
> `docs/part8-advanced/58-illegal-opcodes.md` · index row 58 ·
> `docs/public/roms/part8-advanced/58-illegal-opcodes/` · `docs/public/images/lesson58/` ·
> `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the undocumented opcode bytes, flags, and the ACME toolchain limitation
> must be exact

### Step 3.1: Lesson 58 — Illegal Opcodes

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 58 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 58 · AR-1–AR-6, AR-8, AR-14, AR-23,
AR-25
**Objective**: Deliver Lesson 58 end to end.

- [ ] 3.1.1 Lesson 58 — Illegal Opcodes: Session A freezes ST-58.1–ST-58.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson58): Illegal Opcodes`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 4: Lesson 59 — Self-Modifying Code

> **Phase baseline tree**: the Lesson 58 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/59-self-modifying-code/` (4 sources) ·
> `docs/part8-advanced/59-self-modifying-code.md` · index row 59 ·
> `docs/public/roms/part8-advanced/59-self-modifying-code/` · `docs/public/images/lesson59/` ·
> `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the RAM routine, the stack overlap, and the patched operand are the
> lesson's correctness core

### Step 4.1: Lesson 59 — Self-Modifying Code

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 59 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 59 · AR-1–AR-6, AR-8, AR-15, AR-22,
AR-23, AR-25
**Objective**: Deliver Lesson 59 end to end.

- [ ] 4.1.1 Lesson 59 — Self-Modifying Code: Session A freezes ST-59.1–ST-59.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson59): Self-Modifying Code`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 5: Lesson 60 — DPC and DPC+

> **Phase baseline tree**: the Lesson 59 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/60-dpc-plus/` (4 sources) ·
> `docs/part8-advanced/60-dpc-plus.md` · index row 60 ·
> `docs/public/roms/part8-advanced/60-dpc-plus/` · `docs/public/images/lesson60/` ·
> `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the 10K layout, the bank-1/`$F080` entry, the measured register table, and
> the 2K display image are the hardest technical claims in Part 8

### Step 5.1: Lesson 60 — DPC and DPC+

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 60 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 60 · AR-1–AR-6, AR-8, AR-12, AR-13,
AR-23, AR-25, AR-29, AR-30
**Objective**: Deliver Lesson 60 end to end.

- [ ] 5.1.1 Lesson 60 — DPC and DPC+: Session A freezes ST-60.1–ST-60.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson60): DPC and DPC+`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 6: Lesson 61 — Compression & Data Encoding

> **Phase baseline tree**: the Lesson 60 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/61-compression/` (4 sources) ·
> `docs/part8-advanced/61-compression.md` · index row 61 ·
> `docs/public/roms/part8-advanced/61-compression/` · `docs/public/images/lesson61/` ·
> `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the RLE decoder must be bounded and the decoded image must checksum-match

### Step 6.1: Lesson 61 — Compression & Data Encoding

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 61 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 61 · AR-1–AR-6, AR-8, AR-16, AR-23,
AR-25
**Objective**: Deliver Lesson 61 end to end.

- [ ] 6.1.1 Lesson 61 — Compression & Data Encoding: Session A freezes ST-61.1–ST-61.6 (red
  baseline), Session B implements the full artifact set, Session C verifies to green and hardens;
  commit via the `git-commit` skill in push mode — `feat(lesson61): Compression`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 7: Lesson 62 — Reverse Engineering a Classic Game

> **Phase baseline tree**: the Lesson 61 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/62-reverse-engineering/demo-62.asm` ·
> `docs/part8-advanced/62-reverse-engineering.md` · index row 62 ·
> `docs/public/roms/part8-advanced/62-reverse-engineering/` ·
> `docs/public/images/lesson62/` · `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the demo must be complete enough to reverse-engineer, and the annotated
> map must match the symbol table

### Step 7.1: Lesson 62 — Reverse Engineering a Classic Game

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 62 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 62 · AR-1–AR-6, AR-8, AR-17, AR-23,
AR-25
**Objective**: Deliver Lesson 62 end to end.

- [ ] 7.1.1 Lesson 62 — Reverse Engineering a Classic Game: Session A freezes ST-62.1–ST-62.6
  (red baseline), Session B implements the demo and the document, Session C verifies to green and
  hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson62): Reverse Engineering a Classic Game`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 8: Lesson 63 — Modern Homebrew

> **Phase baseline tree**: the Lesson 62 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/63-modern-homebrew/demo-63.asm` ·
> `docs/part8-advanced/63-modern-homebrew.md` · index row 63 ·
> `docs/public/roms/part8-advanced/63-modern-homebrew/` ·
> `docs/public/images/lesson63/` · `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: medium — the attract mode is a production-value demo; the prose must avoid
> unsourced community claims

### Step 8.1: Lesson 63 — Modern Homebrew

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 63 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 63 · AR-1–AR-6, AR-8, AR-18, AR-23,
AR-25
**Objective**: Deliver Lesson 63 end to end.

- [ ] 8.1.1 Lesson 63 — Modern Homebrew: Session A freezes ST-63.1–ST-63.6 (red baseline),
  Session B implements the demo and the document, Session C verifies to green and hardens; commit
  via the `git-commit` skill in push mode — `feat(lesson63): Modern Homebrew`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 9: Lesson 64 — Building Your Own Cartridge

> **Phase baseline tree**: the Lesson 63 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/64-building-cartridges/demo-64.asm` ·
> `docs/part8-advanced/64-building-cartridges.md` · index row 64 ·
> `docs/public/roms/part8-advanced/64-building-cartridges/` ·
> `docs/public/images/lesson64/` · `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: medium — the burn-in test must be a real, useful test; the hardware prose must
> be accurate and not claim a physical build

### Step 9.1: Lesson 64 — Building Your Own Cartridge

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 64 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 64 · AR-1–AR-6, AR-8, AR-19, AR-23,
AR-25
**Objective**: Deliver Lesson 64 end to end.

- [ ] 9.1.1 Lesson 64 — Building Your Own Cartridge: Session A freezes ST-64.1–ST-64.6 (red
  baseline), Session B implements the demo and the document, Session C verifies to green and
  hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson64): Building Your Own Cartridge`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 10: Lesson 65 — PAL/NTSC Universal ROM

> **Phase baseline tree**: the Lesson 64 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/65-pal-ntsc-universal/` (4 sources) ·
> `docs/part8-advanced/65-pal-ntsc-universal.md` · index row 65 ·
> `docs/public/roms/part8-advanced/65-pal-ntsc-universal/` ·
> `docs/public/images/lesson65/` · `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the lesson must teach the selector and the impossibility of stock
> auto-detection, and the 262/312 frame arithmetic must match the state log

### Step 10.1: Lesson 65 — PAL/NTSC Universal ROM

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 65 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 65 · AR-1–AR-6, AR-8, AR-20, AR-21,
AR-23, AR-25, AR-32
**Objective**: Deliver Lesson 65 end to end.

- [ ] 10.1.1 Lesson 65 — PAL/NTSC Universal ROM: Session A freezes ST-65.1–ST-65.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson65): PAL/NTSC Universal ROM`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 11: Part 8 Completion Gate

> **Phase baseline tree**: the Lesson 65 commit (clean tree at gate start; scope: strict)
> **Expected modifications**: `docs/part8-advanced/index.md` (final check) · `README.md` (verify
> only) · `codeops/features/curriculum/00-roadmap.md` · `codeops/00-roadmap.md` ·
> `99-execution-plan.md` · `05-findings.md` · `00-index.md` · `02-current-state.md`
> **Reasoning**: high — the gate counts the artifacts, confirms the reviews, and marks RD-08 Done

- [ ] 10.1.1a Part 8 completion gate (a gate, not an eleventh lesson task): index rows 56–65 ✅,
  RD-08 Done, feature roadmap 8/11, portfolio 8 plans, all completion criteria ticked, final
  `verify.sh` green

## Completion Criteria

- [ ] All ten phases marked `[x]` with Session A/C records.
- [ ] 31 committed ROMs (4K/8K/10K/16K), 10 documents, 20 screenshots.
- [ ] Lessons 56–61 and 65 ship three exercise solutions each; 62–64 ship `demo-NN.asm`.
- [ ] Part 8 index rows 56–65 all ✅ Complete.
- [ ] `bash scripts/verify.sh` green at the final commit.
- [ ] Both specialists report no critical/major open for every lesson.
- [ ] No dead code, no unused symbols/tables; security is N/A (static content, no input).
- [ ] The post-completion re-analysis (plan/skill protocol) is recorded.
- [ ] RD-08 Done; feature roadmap 8/11 RDs; portfolio 8 plans done.
