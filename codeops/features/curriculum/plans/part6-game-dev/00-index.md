# Part 6 — Game Development (Lessons 38–47) Implementation Plan

> **Feature**: Curriculum — complete Part 6 by shipping lessons 38–47 as a reviewed lesson set
> **Status**: Preflight Complete
> **Created**: 2026-11-05
> **Implements**: curriculum/RD-06
> **Source**: ../../requirements/RD-06-part6-game-dev.md
> **CodeOps Artifact Schema**: 1

## Overview

Part 6 turns the rendering and audio skills of Parts 1–5 into complete games. The ten lessons
move from the TIA's collision latches (38), through a 48-pixel scoreboard and BCD scoring
(39–40), the title/play/game-over state machine (41), difficulty and progression (42), an LFSR
(43), enemy AI (44), the 128-byte memory budget (45), systematic debugging (46), to the build and
verification workflow (47).

Each lesson is a playable or observable lab whose picture **is** the evidence: four collision
bands and a hit bar, a six-digit score, a BCD register strip, a state-colored screen, a difficulty
ladder, a random history grid, an enemy state display, a 128-byte RAM map, a bug/fix debug lab,
and a build-pipeline dashboard. The state log proves the logic; the screenshot proves the monitor;
the committed ROM is what the reader runs.

Every lesson ships the course's full artifact set: annotated assembly, three exercise solutions, a
document built from the fixed lesson template, two real Stella screenshots, a committed
4,096-byte ROM with a `<RomPlayer>` embed, and the part-index and prev/next updates. Lesson 39
ships `include/score.asm`; Lesson 43 ships `include/random.asm`; Lesson 47 ships the theory demo
`demo-47.asm`. Per AR-3 there is no other standalone demo.

The work runs as ten phases, one per lesson, strictly sequential because the score library (39) is
used by 40, the collision read (38) is used by 39/41/44/46, the state machine (41) is used by
42/44, and the memory map (45) is used by 46; 43 is the standalone randomness lesson. Every phase
follows the mandatory three-session ordering:
Session A freezes that lesson's specification cases, Session B implements, Session C verifies
against the frozen cases and hardens under independent review. The gate for every phase is
`bash scripts/verify.sh`; both specialist reviewers must report no critical/major findings before
a lesson counts as done.

## Minimum-Sufficient Baseline

**Original goal:** plan, preflight, and execute RD-06 (Part 6 — Game Development, lessons 38–47)
at the same quality bar as Parts 1–5.
**Smallest viable design:** reuse the existing lesson pipeline, frame skeleton, collision/TIA
registers, and screenshot tooling; add two small promised libraries and one theory demo; no new
tooling, framework, or infrastructure.
**Excluded machinery:** a test framework, an audio-capture pipeline, a full game engine, a
scrolling/text renderer beyond the 48-pixel score, and persistent save data (the 2600 has no
battery-backed RAM in this course).
**Approved complexity:** `include/score.asm`, `include/random.asm`, and `demo-47.asm` only (AR-7,
AR-15, AR-19, AR-22).

## Document Index

| #   | Document                                       | Description                                 | 
| --- | ---------------------------------------------- | ------------------------------------------- |
| AR  | [Ambiguity Register](00-ambiguity-register.md) | Zero-Ambiguity Gate decisions (audit trail) |
| PF  | [Preflight Report](00-preflight-report.md) | Plan-level audit findings and resolutions |
| 00  | [Index](00-index.md)                           | This document — overview and navigation     |
| 01  | [Requirements](01-requirements.md)             | Delta view of RD-06 and plan-local criteria |
| 02  | [Current State](02-current-state.md)           | Analysis of the existing course state       |
| 03  | [Lesson Specifications](03-lesson-specs.md)    | Per-lesson ROM, visual, logic, and exercise design |
| 07  | [Testing Strategy](07-testing-strategy.md)     | Specification test cases and verification   |
| 05  | [Findings Ledger](05-findings.md)              | Per-phase review findings (appended during execution) |
| 99  | [Execution Plan](99-execution-plan.md)         | Phases, sessions, and task checklist        |

## Quick Reference

### Usage Examples

```bash
# Build and run Lesson 38
acme -f plain -o build/lesson38.bin \
  lessons/part6-game-dev/38-collision-detection/38-collision-detection.asm
stella build/lesson38.bin          # move with the joystick; collide with the objects

# Rebuild every committed ROM and run the gate
npm run roms
bash scripts/verify.sh
```

### Key Decisions

| Decision | Outcome |
| --- | --- |
| Scope | RD-06 only; lessons 38–47 strictly sequential (AR-1, AR-38) |
| Phasing | Ten phases, one per lesson; Sessions A/B/C (AR-2) |
| Demo ROMs | `demo-47.asm` only; lessons 38–46 are playable labs (AR-3) |
| Verify | `bash scripts/verify.sh` (AR-4) |
| Reviews | `atari2600-reviewer` + `curriculum-auditor`; no critical/major (AR-5) |
| Evidence | State logs + static ledgers + pixel checks; the ROM is the runnable artifact (AR-6, AR-28) |
| New machinery | `include/score.asm` (39), `include/random.asm` (43) (AR-7) |
| Scoreboard | Staugas 48-pixel kernel; 8 rows; bottom-up font; 9-line zone (AR-15, AR-31) |
| Collisions | Read in VBLANK, then `CXCLR`; one-frame latency documented (AR-32) |
| Prerequisites | Each lesson document names the earlier lessons it builds on (AR-37) |
| BCD | 3 BCD bytes → 6 digits via `ScoreSetDigit`; `CLD` restored (AR-33) |
| RAM | `$80–$9F` lesson, `$A0–$D7` score or `$A0–$A8` random, `$A9–$D7` free in 43, `$D8–$F7` free, `$F8–$FF` stack (AR-25) |
| Frame | 262 lines, work-first (score kernel WSYNC-first), one `HMOVE` where sprites are placed (AR-29) |
| Part index | Rebuilt to the Part 1 format in the Lesson 38 phase (AR-10) |

## Specialist Agents

| Role | Kind | Use | AR Ref |
| --- | --- | --- | --- |
| `lesson-author` | executor | Implements lessons 38–47 end-to-end from the per-lesson specifications; the parent verifies each artifact and runs the gates | — |
| `atari2600-reviewer` | reviewer | Hardware/CPU review of every lesson phase | AR-5 |
| `curriculum-auditor` | reviewer | Five-rule and didactic-chain audit of every lesson phase | AR-5 |

_Detection evidence: `codeops/codeops.json` already routes `lesson-author`, `atari2600-reviewer`,
and `curriculum-auditor`; `.opencode/agents/` contains the project agents; the Part 1–5 plans used
the two reviewers per lesson. Lesson 38–47 are substantially larger than the Part 5 lessons, so
the `lesson-author` role is used as the implementation executor and the parent keeps the
verification, review dispatch, and commit authority. No new specialist gap was found: the game
logic, collision latches, scoreboard, BCD, LFSR, AI, memory, debugging, and tooling are covered by
the existing `atari-2600-expert` references and the two reviewers._

## Related Files

| Path | Purpose |
| --- | --- |
| `lessons/part6-game-dev/38-collision-detection/` … `47-dev-tools-workflow/` | Lesson sources and exercise solutions |
| `docs/part6-game-dev/38-collision-detection.md` … `47-dev-tools-workflow.md` | Lesson documents (stubs today) |
| `docs/public/roms/part6-game-dev/38…47/` | Committed ROMs |
| `docs/public/images/lesson38/` … `lesson47/` | Screenshots |
| `docs/part6-game-dev/index.md` | Part index (stub; rebuilt in Phase 1) |
| `include/score.asm`, `include/random.asm` | Lesson 39 and 43 libraries |
| `docs/.vitepress/config.ts` | Sidebar (entries already exist; verify only) |
| `README.md` | Curriculum listing (row 6 already correct; verify only) |
