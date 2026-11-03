# Part 3 — Playfield (Lessons 19–24) Implementation Plan

> **Feature**: Curriculum — complete Part 3 by shipping lessons 19–24 as a reviewed lesson set
> **Status**: Planning Complete
> **Created**: 2026-11-03
> **Implements**: curriculum/RD-03
> **Source**: ../../requirements/RD-03-part3-playfield.md
> **CodeOps Artifact Schema**: 1

## Overview

Part 3 introduces the TIA's playfield: 20 bits per half, 4 color clocks per bit, 40 chunks across
the visible line, mirrored (`REF`) or repeated. The six lessons move from the register layout and
the first drawn pattern (19), through color and score mode (20), asymmetric halves (21), frame
animation (22), data-driven level tables (23), to per-scanline color (24). Part 2 is complete;
each Part 3 lesson builds directly on its frame, timing, and cycle-counting vocabulary.

Each lesson ships the course's full artifact set: annotated assembly, three exercise solutions, a
document built from the fixed lesson template, real Stella screenshots, a committed 4,096-byte
ROM with a `<RomPlayer>` embed, and the part-index and prev/next updates. Per AR-3, no standalone
`demo-NN.asm` ships in this part — each main ROM is the concept made visible, and the reason is
recorded per lesson in the specification.

The work runs as six phases — one per lesson, strictly sequential because each lesson's concepts
are the next one's prerequisites. Every phase follows the mandatory three-session ordering:
Session A freezes that lesson's specification cases, Session B implements, Session C verifies
against the frozen cases and hardens under independent review. The gate for every phase is
`bash scripts/verify.sh`; both specialist reviewers must report no critical/major findings before
a lesson counts as done.

## Minimum-Sufficient Baseline

**Original goal:** Ship Part 3 (lessons 19–24) at the Part 1/2 quality bar, reusing the proven
pipeline.
**Smallest viable design:** Reuse the existing pipeline end to end — the `vcs-lesson-production`
cycle, `atari-2600-expert` claim discipline, `npm run roms`, `scripts/capture-screenshot.sh`, the
lesson template, and `bash scripts/verify.sh` — with the existing specialists and the Part 2
evidence method (AR-6).
**Excluded machinery:** No test framework, no new build/screenshot/site machinery, no new scripts
(AR-7).
**Approved complexity:** None — every decision reuses the existing toolchain.

## Document Index

| # | Document | Description |
| --- | --- | --- |
| AR | [Ambiguity Register](00-ambiguity-register.md) | Zero-Ambiguity Gate decisions (audit trail) |
| 00 | [Index](00-index.md) | This document — overview and navigation |
| 01 | [Requirements](01-requirements.md) | RD-03 delta: scope, plan-local decisions and criteria |
| 02 | [Current State](02-current-state.md) | Shipped Parts 1–2, working rails, and the gaps |
| 03 | [Lesson Specifications](03-lesson-specs.md) | Per-lesson technical specs for 19–24 |
| 07 | [Testing Strategy](07-testing-strategy.md) | Frozen observational ST cases and verification |
| 99 | [Execution Plan](99-execution-plan.md) | 6 phases, three sessions each, task checklists |

## Quick Reference

### Usage Examples

```bash
bash scripts/verify.sh                # project gate: ROM drift check + docs build
npm run roms                          # assemble every lesson ROM into docs/public/roms/
acme -f plain -o build/lesson19.bin \
  lessons/part3-playfield/19-playfield-basics/19-playfield-basics.asm
stella build/lesson19.bin
bash scripts/capture-screenshot.sh \
  docs/public/roms/part3-playfield/19-playfield-basics/19-playfield-basics.bin \
  docs/public/images/lesson19/reflect.png
# runtime evidence for timing claims (AR-6): breakpoint state logs
stella -dbg.logbreaks 1 -logtoconsole 1 -break '<addr>' <rom>
```

### Key Decisions

| Decision | Outcome | AR |
| --- | --- | --- |
| Scope | RD-03 only: lessons 19–24, strictly sequential | AR-1 |
| Phases | One phase per lesson; Sessions A (freeze ST), B (implement), C (verify & harden) | AR-2 |
| Demo ROMs | None — every main ROM is directly visual; reason per lesson | AR-3 |
| Verify / commits | `bash scripts/verify.sh`; one atomic commit per lesson via the `git-commit` skill in push mode | AR-4, AR-12 |
| Reviews | Both specialists gate every lesson; no critical/major | AR-5 |
| Evidence | State-log checkpoints + static cycle ledgers; pixel-checked captures | AR-6 |
| Machinery | None new — existing pipeline only | AR-7 |
| Forward mentions | Name-only context notes for later-part mechanisms; never used in code | AR-9 |
| Part index | Rebuilt to the Part 1 format in the Lesson 19 phase; rows flip per lesson | AR-10 |
| Video standard | NTSC only | AR-11 |
| Playfield timing | Registers re-read per half; writes land on the 4-clock pixel grid; L21 windows measured | AR-13 |
| Priority scope | `COLUPF` + score mode observable; `PFP`'s effect deferred to Part 4 in prose only | AR-14 |

## Specialist Agents

| Role | Kind | Use | AR Ref |
| --- | --- | --- | --- |
| lesson-author | executor | Session B implementation of every lesson phase (19–24) | AR-2 |
| atari2600-reviewer | reviewer | Independent hardware/timing correctness review after every lesson | AR-5 |
| curriculum-auditor | reviewer | Independent five-rules completeness and didactic audit after every lesson | AR-5 |

_Detection evidence: `codeops/specialists/{lesson-author,atari2600-reviewer,curriculum-auditor}.md`
define the three roles; `codeops/codeops.json` routes both reviewers read-only with independent
review enabled and stop-on-major. RD-03 AC 3 requires both reviewers. The specialist check found no
new gap: Part 3 is static lesson content plus ROMs, fully covered by the existing three roles; no
additional specialist candidate is justified._

## Related Files

- `lessons/part3-playfield/19-playfield-basics/` … `24-multicolor-playfield/` — lesson sources and exercise solutions.
- `docs/part3-playfield/19-playfield-basics.md` … `24-multicolor-playfield.md` — lesson documents (stubs today).
- `docs/part3-playfield/index.md` — rebuilt to the Part 1 format (AR-10).
- `docs/public/roms/part3-playfield/19-playfield-basics/` … `24-multicolor-playfield/` — committed ROMs.
- `docs/public/images/lesson19/` … `lesson24/` — screenshots.
- `docs/.vitepress/config.ts` (Part 3 sidebar block) and `README.md` — verify only.
- `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md` — tracking updates (AR-12).
