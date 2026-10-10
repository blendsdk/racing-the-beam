# Part 1 — The 6502 CPU (Lessons 07–11) Implementation Plan

> **Feature**: Curriculum — complete Part 1 by shipping lessons 07–11 as a reviewed lesson set
> **Status**: Planning Complete
> **Created**: 2026-10-10
> **Implements**: curriculum/RD-01
> **Source**: ../../requirements/RD-01-part1-6502.md
> **CodeOps Artifact Schema**: 1

## Overview

Part 1 teaches the 6507 CPU. Lessons 04–06 (registers/memory, arithmetic, flags/comparisons) are shipped; RD-01 defines the remaining five: 07 Branches and Loops, 08 The Stack and Subroutines, 09 Bitwise Operations, 10 Addressing Modes, 11 Lookup Tables. This plan delivers all five so Part 1 is complete and ready for Part 2.

Each lesson ships the course's full artifact set: annotated assembly, exercise solutions, a document built from the fixed lesson template, real Stella screenshots, a committed 4,096-byte ROM with a `<RomPlayer>` embed, and the part-index and prev/next updates. Lesson 10 is a theory lesson and additionally ships a standalone `demo-10.asm` visualizing the addressing-mode catalog.

The work runs as five phases — one per lesson, strictly sequential because each lesson's concepts are the next one's prerequisites. Every phase follows the mandatory three-session ordering: Session A freezes that lesson's specification cases, Session B implements, Session C verifies against the frozen cases and hardens under independent review. The gate for every phase is `bash scripts/verify.sh`; both specialist reviewers must report no critical/major findings before a lesson counts as done.

## Minimum-Sufficient Baseline

**Original goal:** Ship the five remaining Part 1 lessons (07–11) at the established quality bar.
**Smallest viable design:** Reuse the existing pipeline end to end — the `vcs-lesson-production` cycle, `atari-2600-expert` claim discipline, `npm run roms`, `scripts/capture-screenshot.sh`, the lesson template, and `bash scripts/verify.sh` — with the existing specialists.
**Excluded machinery:** None beyond the existing pipeline: no test framework (AR-3, AR-7), no new build, screenshot, or site machinery.
**Approved complexity:** None — every decision reuses the existing toolchain (AR-4, AR-7).

## Document Index

| # | Document | Description |
| --- | --- | --- |
| AR | [Ambiguity Register](00-ambiguity-register.md) | Zero-Ambiguity Gate decisions (audit trail) |
| 00 | [Index](00-index.md) | This document — overview and navigation |
| 01 | [Requirements](01-requirements.md) | RD-01 delta: scope, plan-local decisions and criteria |
| 02 | [Current State](02-current-state.md) | Existing lessons 04–06, rails, and the gaps |
| 03 | [Lesson Specifications](03-lesson-specs.md) | Per-lesson technical specs for 07–11 |
| 07 | [Testing Strategy](07-testing-strategy.md) | Frozen observational ST cases and verification |
| 99 | [Execution Plan](99-execution-plan.md) | 5 phases, three sessions each, task checklists |

## Quick Reference

### Usage Examples

```bash
bash scripts/verify.sh                # project gate: ROM drift check + docs build
npm run roms                          # assemble every lesson ROM into docs/public/roms/
acme -f plain -o build/lesson07.bin \
  lessons/part1-6502-cpu/07-branches-and-loops/07-branches-and-loops.asm
stella build/lesson07.bin
bash scripts/capture-screenshot.sh build/lesson07.bin docs/public/images/lesson07/loop-cursor-top.png
```

### Key Decisions

| Decision | Outcome | AR |
| --- | --- | --- |
| Scope | RD-01 only: lessons 07–11, strictly sequential | AR-1 |
| Phases | One phase per lesson; Sessions A (freeze ST), B (implement), C (verify & harden) | AR-2 |
| Specification tests | Observational acceptance cases with concrete outcomes; no framework added | AR-3 |
| Verify / commits | `bash scripts/verify.sh`; one atomic commit per lesson via the `git-commit` skill in push mode | AR-4, AR-8 |
| Reviews | `lesson-author` executes; both specialists gate every lesson | AR-5 |

## Specialist Agents

| Role | Kind | Use | AR Ref |
| --- | --- | --- | --- |
| lesson-author | executor | Session B implementation of every lesson phase (07–11) | AR-5 |
| atari2600-reviewer | reviewer | Independent hardware/CPU correctness review after every lesson | AR-5 |
| curriculum-auditor | reviewer | Independent five-rules completeness and didactic audit after every lesson | AR-5 |

_Detection evidence: `codeops/specialists/{lesson-author,atari2600-reviewer,curriculum-auditor}.md` define the three roles; `codeops/codeops.json` routes both reviewers read-only with independent review enabled and stop-on-major — matching RD-01 AC 3 and the quality mandate._

## Related Files

- `lessons/part1-6502-cpu/07-branches-and-loops/` … `11-lookup-tables/` — lesson sources, exercise solutions, `demo-10.asm`.
- `docs/part1-6502-cpu/07-branches-and-loops.md` … `11-lookup-tables.md` — lesson documents.
- `docs/public/images/lesson07/` … `lesson11/` — screenshots; `docs/public/roms/part1-6502-cpu/07…11/` — committed ROMs.
- `docs/part1-6502-cpu/index.md` — part-index status rows updated to ✅ Complete.
- `docs/.vitepress/config.ts` (sidebar lines 48–52) and `README.md` — verify only.
- `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md` — tracking updates.
