# Part 2 — TV & TIA (Lessons 12–18) Implementation Plan

> **Feature**: Curriculum — complete Part 2 by shipping lessons 12–18 as a reviewed lesson set
> **Status**: Planning Complete
> **Created**: 2026-10-10
> **Implements**: curriculum/RD-02
> **Source**: ../../requirements/RD-02-part2-tv-tia.md
> **CodeOps Artifact Schema**: 1

## Overview

Part 2 explains how the Atari 2600 produces a picture: the 262-line NTSC frame, the 128-color
palette, beam-synchronized code with `WSYNC`, RIOT-timer pacing, horizontal zones, cycle
budgeting, and mid-scanline register changes. Part 1 (lessons 04–11) is complete; Part 2's seven
lessons carry the course's core hardware claims, and every later part builds on them.

Each lesson ships the course's full artifact set: annotated assembly, exercise solutions, a
document built from the fixed lesson template, real Stella screenshots, a committed 4,096-byte
ROM with a `<RomPlayer>` embed, and the part-index and prev/next updates. Per AR-3, a standalone
`demo-NN.asm` ships only where a lesson's concept cannot be visualized by its main ROM; the
current expectation is none for this part, and each lesson's specification states its reason.

The work runs as seven phases — one per lesson, strictly sequential because each lesson's
concepts are the next one's prerequisites. Every phase follows the mandatory three-session
ordering: Session A freezes that lesson's specification cases, Session B implements, Session C
verifies against the frozen cases and hardens under independent review. The gate for every phase
is `bash scripts/verify.sh`; both specialist reviewers must report no critical/major findings
before a lesson counts as done.

## Minimum-Sufficient Baseline

**Original goal:** Ship Part 2 (lessons 12–18) at the Part 1 quality bar, reusing the proven
pipeline.
**Smallest viable design:** Reuse the existing pipeline end to end — the `vcs-lesson-production`
cycle, `atari-2600-expert` claim discipline, `npm run roms`, `scripts/capture-screenshot.sh`, the
lesson template, and `bash scripts/verify.sh` — with the existing specialists and the Part 1
evidence method (AR-6).
**Excluded machinery:** None beyond the existing pipeline: no test framework, no new build,
screenshot, or site machinery (AR-7).
**Approved complexity:** None — every decision reuses the existing toolchain (AR-7).

## Document Index

| # | Document | Description |
| --- | --- | --- |
| AR | [Ambiguity Register](00-ambiguity-register.md) | Zero-Ambiguity Gate decisions (audit trail) |
| 00 | [Index](00-index.md) | This document — overview and navigation |
| 01 | [Requirements](01-requirements.md) | RD-02 delta: scope, plan-local decisions and criteria |
| 02 | [Current State](02-current-state.md) | Shipped Part 1, working rails, and the gaps |
| 03 | [Lesson Specifications](03-lesson-specs.md) | Per-lesson technical specs for 12–18 |
| 07 | [Testing Strategy](07-testing-strategy.md) | Frozen observational ST cases and verification |
| 99 | [Execution Plan](99-execution-plan.md) | 7 phases, three sessions each, task checklists |
| PF | [Preflight Report](00-preflight-report.md) | Pre-execution audit: 21 findings, all resolved |

## Quick Reference

### Usage Examples

```bash
bash scripts/verify.sh                # project gate: ROM drift check + docs build
npm run roms                          # assemble every lesson ROM into docs/public/roms/
acme -f plain -o build/lesson12.bin \
  lessons/part2-tv-and-tia/12-the-ntsc-frame/12-the-ntsc-frame.asm
stella build/lesson12.bin
bash scripts/capture-screenshot.sh \
  docs/public/roms/part2-tv-and-tia/12-the-ntsc-frame/12-the-ntsc-frame.bin \
  docs/public/images/lesson12/frame-anatomy.png
# runtime evidence for timing claims (AR-6): breakpoint state logs
stella -dbg.logbreaks 1 -logtoconsole 1 -break '<addr>' <rom>
```

### Key Decisions

| Decision | Outcome | AR |
| --- | --- | --- |
| Scope | RD-02 only: lessons 12–18, strictly sequential | AR-1 |
| Phases | One phase per lesson; Sessions A (freeze ST), B (implement), C (verify & harden) | AR-2 |
| Demo ROMs | Only where the main ROM cannot visualize the concept; reason per lesson (expect none) | AR-3 |
| Verify / commits | `bash scripts/verify.sh`; one atomic commit per lesson via the `git-commit` skill in push mode | AR-4, AR-12 |
| Reviews | `lesson-author` executes; both specialists gate every lesson | AR-5 |
| Timing evidence | State-log checkpoints + static cycle ledgers; labeled scratch witnesses for what-ifs | AR-6 |
| Machinery | None new — existing pipeline only | AR-7 |
| Forward mentions | Name-only context notes for later-part mechanisms; never used in code or exercises | AR-9 |
| Part index | Rebuilt to the Part 1 format in the lesson-12 phase; rows flip per lesson | AR-10 |
| Video standard | NTSC only (262 lines; ~60 Hz — ≈59.9 Hz derived in lesson 12) | AR-11 |

## Specialist Agents

| Role | Kind | Use | AR Ref |
| --- | --- | --- | --- |
| lesson-author | executor | Session B implementation of every lesson phase (12–18) | AR-5 |
| atari2600-reviewer | reviewer | Independent hardware/timing correctness review after every lesson | AR-5 |
| curriculum-auditor | reviewer | Independent five-rules completeness and didactic audit after every lesson | AR-5 |

_Detection evidence: `codeops/specialists/{lesson-author,atari2600-reviewer,curriculum-auditor}.md`
define the three roles; `codeops/codeops.json` routes both reviewers read-only with independent
review enabled and stop-on-major. The on-demand check (`analyze-agents`) was re-run after this plan was created, recording both plans in
`codeops/specialist-check.json`, and it found no additional gap, and RD-02 AC 3 requires both reviewers._

## Related Files

- `lessons/part2-tv-and-tia/12-the-ntsc-frame/` … `18-mid-scanline-changes/` — lesson sources and exercise solutions.
- `docs/part2-tv-and-tia/12-the-ntsc-frame.md` … `18-mid-scanline-changes.md` — lesson documents.
- `docs/part2-tv-and-tia/index.md` — rebuilt to the Part 1 format (AR-10).
- `docs/public/images/lesson12/` … `lesson18/` — screenshots; `docs/public/roms/part2-tv-and-tia/12…18/` — committed ROMs.
- `docs/.vitepress/config.ts` (Part 2 sidebar block) and `README.md` — verify only.
- `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md` — tracking updates (AR-12).
