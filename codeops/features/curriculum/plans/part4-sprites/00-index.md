# Part 4 — Sprites (Lessons 25–34) Implementation Plan

> **Feature**: Curriculum — complete Part 4 by shipping lessons 25–34 as a reviewed lesson set
> **Status**: Planning Complete
> **Created**: 2026-11-04
> **Implements**: curriculum/RD-04
> **Source**: ../../requirements/RD-04-part4-sprites.md
> **CodeOps Artifact Schema**: 1

## Overview

Part 4 adds the TIA's movable objects: the two player sprites, the two missiles, and the ball.
The ten lessons move from the first 8-pixel sprite (25), through horizontal positioning with the
classic divide-by-15 routine (26), joystick movement (27), two independent players (28), missiles
and the ball (29), per-line sprite color (30), `NUSIZ` copies and sizes (31), vertical delay (32),
paddle and keyboard controllers (33), to a four-frame walk cycle (34). Part 3 is complete; each
Part 4 lesson builds on the playfield, the counted frame, and the write-position discipline.

Each lesson ships the course's full artifact set: annotated assembly, three exercise solutions, a
document built from the fixed lesson template, real Stella screenshots, a committed 4,096-byte ROM
with a `<RomPlayer>` embed, and the part-index and prev/next updates. Per AR-3, no standalone
`demo-NN.asm` ships in this part — each main ROM is the concept made visible, and the reason is
recorded per lesson in the specification.

The work runs as ten phases — one per lesson, strictly sequential because each lesson's concepts
are the next one's prerequisites. Every phase follows the mandatory three-session ordering:
Session A freezes that lesson's specification cases, Session B implements, Session C verifies
against the frozen cases and hardens under independent review. The gate for every phase is
`bash scripts/verify.sh`; both specialist reviewers must report no critical/major findings before
a lesson counts as done. Horizontal positioning is the part's highest-risk claim: every lesson that
positions an object pins its measured X from a Stella state log and a pixel check.

## Planning Scope Contract

| Boundary | Content |
| --- | --- |
| **Planning target** | RD-04 — Part 4, lessons 25–34 |
| **Context artifacts** | RD-03 and the completed Part 3 plan; Parts 1–2 lesson documents; `include/vcs.asm`; `include/macro.asm`; the `vcs-lesson-production` and `atari-2600-expert` skills; the three specialists; the build/capture/verify scripts |
| **Modification set** | `codeops/features/curriculum/plans/part4-sprites/`, the Part 4 lesson sources/documents/artifacts, the Part 4 index, and the roadmap rows |

## Minimum-Sufficient Baseline

**Original goal:** Ship Part 4 (lessons 25–34) at the Part 1–3 quality bar, reusing the proven
pipeline.
**Smallest viable design:** Reuse the existing pipeline end to end — the `vcs-lesson-production`
cycle, `atari-2600-expert` claim discipline, `npm run roms`, `scripts/capture-screenshot.sh`, the
lesson template, and `bash scripts/verify.sh` — with the existing specialists and the Part 2/3
evidence method (AR-6).
**Excluded machinery:** No test framework, no new build/screenshot/site machinery, no new scripts,
no flicker multiplexer, no 48-pixel-trick implementation (AR-7, AR-18).
**Approved complexity:** None — every decision reuses the existing toolchain.

## Document Index

| # | Document | Description |
| --- | --- | --- |
| AR | [Ambiguity Register](00-ambiguity-register.md) | Zero-Ambiguity Gate decisions (audit trail) |
| 00 | [Index](00-index.md) | This document — overview and navigation |
| 01 | [Requirements](01-requirements.md) | RD-04 delta: scope, plan-local decisions and criteria |
| 02 | [Current State](02-current-state.md) | Shipped Parts 1–3, working rails, and the gaps |
| 03 | [Lesson Specifications](03-lesson-specs.md) | Per-lesson technical specs for 25–34 |
| 07 | [Testing Strategy](07-testing-strategy.md) | Frozen observational ST cases and verification |
| 99 | [Execution Plan](99-execution-plan.md) | 10 phases, three sessions each, task checklists |

## Quick Reference

### Usage Examples

```bash
bash scripts/verify.sh                # project gate: ROM drift check + docs build
npm run roms                          # assemble every lesson ROM into docs/public/roms/
acme -f plain -o build/lesson25.bin \
  lessons/part4-sprites/25-player-basics/25-player-basics.asm
stella build/lesson25.bin
bash scripts/capture-screenshot.sh \
  docs/public/roms/part4-sprites/25-player-basics/25-player-basics.bin \
  docs/public/images/lesson25/first-sprite.png
# runtime evidence for positioning/timing claims (AR-6): breakpoint state logs
stella -dbg.logbreaks 1 -logtoconsole 1 -break '<addr>' <rom>
```

### Key Decisions

| Decision | Outcome | AR |
| --- | --- | --- |
| Scope | RD-04 only: lessons 25–34, strictly sequential | AR-1 |
| Phases | One phase per lesson; Sessions A (freeze ST), B (implement), C (verify & harden) | AR-2 |
| Demo ROMs | None — every main ROM is directly visual; reason per lesson | AR-3 |
| Verify / commits | `bash scripts/verify.sh`; one atomic commit per lesson via the `git-commit` skill in push mode | AR-4, AR-12 |
| Reviews | Both specialists gate every lesson; no critical/major | AR-5 |
| Evidence | State-log checkpoints + static cycle ledgers; pixel-checked captures | AR-6 |
| Machinery | None new — existing pipeline only | AR-7 |
| Forward mentions | Name-only context notes; never used in code | AR-9 |
| Part index | Rebuilt to the Part 1 format in the Lesson 25 phase; rows flip per lesson | AR-10 |
| Video standard | NTSC only | AR-11 |
| Positioning | Classic divide-by-15 `SetHorizPos`; measured X is authoritative | AR-13 |
| Vertical rendering | Counted top/body/bottom loops; graphic write then `WSYNC` | AR-14 |
| Movement demo | Auto-bounce patrol, joystick override | AR-15 |
| Multi-color | Per-line `COLUP0` table over a 16-row shape | AR-16 |
| Copies/sizes | Eight static `NUSIZ` bands, one per value | AR-17 |
| Vertical delay | Two players, P1 one line lower via `VDELP1` | AR-18 |
| Multiple objects | One `HMOVE` per frame after all HM registers are set | AR-21 |
| Controllers | Monitor with real reads and a paddle timeout | AR-19 |
| Animation | Four 16-row frames, stepped every 8 frames | AR-20 |

## Specialist Agents

| Role | Kind | Use | AR Ref |
| --- | --- | --- | --- |
| lesson-author | executor | Session B implementation of every lesson phase (25–34) | AR-2 |
| atari2600-reviewer | reviewer | Independent hardware/timing correctness review after every lesson | AR-5 |
| curriculum-auditor | reviewer | Independent five-rules completeness and didactic audit after every lesson | AR-5 |

_Detection evidence: `codeops/specialists/{lesson-author,atari2600-reviewer,curriculum-auditor}.md`
define the three roles; `codeops/codeops.json` routes both reviewers read-only with independent
review enabled and stop-on-major. RD-04 AC 3 requires both reviewers. The specialist check found no
new gap: Part 4 is static lesson content plus ROMs, fully covered by the existing three roles; no
additional specialist candidate is justified._

## Related Files

- `lessons/part4-sprites/25-player-basics/` … `34-sprite-animation/` — lesson sources and exercise solutions.
- `docs/part4-sprites/25-player-basics.md` … `34-sprite-animation.md` — lesson documents (stubs today).
- `docs/part4-sprites/index.md` — rebuilt to the Part 1 format (AR-10).
- `docs/public/roms/part4-sprites/25-player-basics/` … `34-sprite-animation/` — committed ROMs.
- `docs/public/images/lesson25/` … `lesson34/` — screenshots.
- `docs/.vitepress/config.ts` (Part 4 sidebar block) and `README.md` — verify only.
- `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md` — tracking updates (AR-12).
