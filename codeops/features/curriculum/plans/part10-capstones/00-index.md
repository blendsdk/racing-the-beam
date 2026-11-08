# Part 10 — Capstone Projects (Lessons 69–72) Implementation Plan

> **Feature**: Curriculum — complete Part 10 by shipping four capstone lessons
> **Status**: Complete (4/4 lessons; RD-10 Done)
> **Created**: 2026-11-07
> **Implements**: curriculum/RD-10
> **Source**: ../../requirements/RD-10-part10-capstones.md
> **CodeOps Artifact Schema**: 1

## Overview

Part 10 is the graduation sequence. The course has built the machine, the CPU, the TIA, the
sprites, the game-development techniques, the kernels, the bankswitching, and the code-generation
path. Part 10 asks the reader to build complete games with that whole toolbox: a two-player Pong,
a Breakout, a generated mirror-maze adventure, and finally an original game.

The through-line is **the game as a complete system**: a state machine, a kernel budget, an input
map, a collision policy, a score, a sound, a win/lose condition, an auto-demo for deterministic
evidence, and a production pipeline that ends in a committed ROM with screenshots and a lesson.

Lesson 69 builds **Pong** — two paddles, a ball, wall and paddle collisions, a serve, a
one-digit-per-player score, and a custom 89-byte row table driving a two-line kernel. The lesson
teaches the row table because a one-line multi-object kernel cannot write GRP0 before P0's pixel
time at X=16; the preflight measured the failure and the fix.

Lesson 70 builds **Breakout** — a 48-line brick field, a 128-line play area, a paddle, a ball, a
brick map with per-brick removal, three levels, three lives, and the score library. The kernel
splits into a brick zone (playfield rows + a ball row compare) and a play zone (a 32-byte row
table). The ball is visible in both zones.

Lesson 71 builds **Maze Explorer** — a generated mirror maze (10 unique columns, 20 visible with
reflect mode), cell-by-cell movement, two enemies with a chase AI, three keys, a win and a lose
state, and a first-party Python generator with a committed include and a `--check` gate.

Lesson 72 is **Your Own Game** — the production lesson. Its `demo-72.asm` is a complete skeleton
mini-game: title/play/over states, a catch loop, the score library, the sound library, restart,
and three clearly marked `YOUR GAME` sections. The doc supplies the GDD template, the RAM/screen
map worksheets, the 4K budget, the milestone plan, and three design exercises.

Every lesson follows the mandatory three-session ordering: Session A freezes the specification
cases and records a red baseline; Session B implements; Session C verifies against the frozen
cases and hardens under independent review. `bash scripts/verify.sh` is the gate for every phase;
both specialist reviewers must report no critical/major findings before a lesson counts as done.

## Minimum-Sufficient Baseline

**Original goal:** plan, preflight, and execute RD-10 (Part 10 — Capstone Projects, lessons
69–72) at the same quality bar as Parts 1–9.
**Smallest viable design:** reuse the existing lesson pipeline, the 262-line frame skeleton,
`include/vcs.asm`, `include/macro.asm`, `include/score.asm`, `include/sound.asm`, and the proven
positioning/collision idioms. The new work is four complete games, one lesson-scoped Python maze
generator, and the design/production templates.
**Excluded machinery:** a new shared game engine, a mapper, a new emulator, a build-time Python
dependency in CI, a general-purpose compiler, and any change to earlier lessons.
**Approved complexity:** the Pong 89-byte row table, the Breakout 64×3 brick PF table, and the
Lesson 71 generator/include. Each is lesson-scoped, documented, and backed by a `--check` or a
static ledger.

## Document Index

| #   | Document                                       | Description                                 |
| --- | ---------------------------------------------- | ------------------------------------------- |
| AR  | [Ambiguity Register](00-ambiguity-register.md) | Zero-Ambiguity Gate decisions (audit trail) |
| PF  | [Preflight Report](00-preflight-report.md)      | Plan-level audit findings and prototypes    |
| 00  | [Index](00-index.md)                           | This document — overview and navigation     |
| 01  | [Requirements](01-requirements.md)             | Delta view of RD-10 and plan-local criteria |
| 02  | [Current State](02-current-state.md)           | Analysis of the existing course state       |
| 03  | [Lesson Specifications](03-lesson-specs.md)    | Per-lesson ROM, visual, logic, and exercise design |
| 07  | [Testing Strategy](07-testing-strategy.md)     | Specification test cases and verification   |
| 05  | [Findings Ledger](05-findings.md)              | Per-phase review findings (appended during execution) |
| 99  | [Execution Plan](99-execution-plan.md)         | Phases, sessions, and task checklist        |

## Quick Reference

### Usage Examples

```bash
# Build and run Pong
acme -f plain -o build/lesson69.bin \
  lessons/part10-capstones/69-pong/69-pong.asm
stella build/lesson69.bin            # two joysticks; auto-demo after 2 s

# Build and run Breakout
acme -f plain -o build/lesson70.bin \
  lessons/part10-capstones/70-breakout/70-breakout.asm
stella build/lesson70.bin            # joystick; auto-demo paddle

# Rebuild the Lesson 71 maze include, then the ROM
python3 lessons/part10-capstones/71-maze-explorer/lesson71-generate.py \
  --spec lessons/part10-capstones/71-maze-explorer/maze-spec.txt \
  --out lessons/part10-capstones/71-maze-explorer/maze-data.inc
acme -f plain -o build/lesson71.bin \
  lessons/part10-capstones/71-maze-explorer/71-maze-explorer.asm

# Build and run the Lesson 72 skeleton
acme -f plain -o build/demo-72.bin \
  lessons/part10-capstones/72-your-game/demo-72.asm

# Rebuild every committed ACME ROM and run the gate
npm run roms
bash scripts/verify.sh
```

### Key Decisions

| Decision | Outcome |
| --- | --- |
| Part scope | Lessons 69–72 only; curriculum frozen (AR-1) |
| Phases | 4 lesson phases + completion gate (AR-2) |
| Artifacts | 3 buildable games × 4 sources + 1 theory demo (AR-3) |
| ROM sizes | 4,096 for every lesson; no mapper (AR-8) |
| Pong score | One digit per player, custom; frees $A0-$D7 (AR-10) |
| Pong kernel | 89-byte row table + two-line kernel (AR-11) |
| Breakout | 9-line score + 48-line brick + 128-line play (AR-14) |
| Brick map | 6 rows × 6 unique (12 visible); 64×3 PF table (AR-15) |
| Maze | Mirror maze 10×11 unique / 20×11 visible (AR-17) |
| Maze generator | Python, `--check`, committed `maze-data.inc` (AR-18) |
| Lesson 72 | Skeleton mini-game + GDD/RAM/screen templates (AR-22) |
| Frame | NTSC 262; StartFrame 259, Body 37, Overscan 229 (AR-25) |
| Evidence | State logs + ledgers + PIL checks + generator checks (AR-26) |
| Completion | 13 ACME sources, 4 docs, 11 screenshots, 265/266 ROMs (AR-28) — achieved |

## Specialist Agents

| Role | Kind | Use | AR Ref |
| ---- | ---- | --- | ------ |
| `lesson-author` | executor | Session B implementation of each lesson | AR-2 |
| `atari2600-reviewer` | reviewer | Hardware/CPU/kernel correctness review of every phase | AR-5 |
| `curriculum-auditor` | reviewer | Five hard rules, didactic chain, site integration | AR-5 |

_Detection evidence: the three roles already exist under `.opencode/agents/` and were used for
Parts 7–9; Part 10 adds full games and one generator, both covered by the existing reviewer's
hardware/CPU scope and the auditor's lesson-completeness scope. No new specialist is needed._

## Risks and Mitigations

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Kernel budget | A one-line multi-object kernel writes GRP0 after P0's pixel time; the paddle disappears | The preflight measured the failure; Pong uses the two-line row table; every kernel ledger is recorded |
| Score/player conflict | The score library owns P0/P1 and $A0-$D7; the games reuse P0/P1 for paddles/player | Pong uses a custom score; Breakout/Maze call `ScoreSetup` every frame and reposition after `ScoreDraw`; the preflight proved the sequence |
| RAM collision | Row tables plus game vars plus the score library can exceed 128 bytes | The per-lesson maps are fixed; the row tables are sized to the free blocks; the source header is the exact map |
| Brick collision math | A wrong column/row maps a hit to the wrong brick | The brick map and column formula are pinned; the capture/log shows a brick cleared |
| Maze generator drift | The committed include could stop matching the spec | `lesson71-generate.py --check` compares; CI does not run Python; the include is committed |
| Moving-state captures | A fixed wait may capture the wrong state | Every game has an auto-demo; the doc discloses the waits and the SELECT path |
| 4K overflow | Four games plus tables could exceed 4,096 | The specs pin the data sizes; every source is assembled before capture |
| Lesson 72 scope creep | A full game would be a fifth capstone, not a production lesson | The demo is a small, complete mini-game; the exercises are design tasks, not code |

## Integration

- The sidebar entries for 69–72 already exist in `docs/.vitepress/config.ts` (lines 164–167); no
  navigation change is expected, only verification.
- The Part 10 index (`docs/part10-capstones/index.md`) is intro-only; Lesson 69 rebuilds it to
  the Part 7/8/9 format. The four lesson rows flip per lesson.
- Lesson 68's `next` already points to `/part10-capstones/69-pong`; Lesson 69's `prev` points
  back to 68; each lesson's `next` points to the next stub; Lesson 72's `next` points to the
  Part 11 index (`/part11-legendary/`).
- README row 10 already says `Capstone Projects | 69–72`; it must not change.
- The completion gate updates `codeops/features/curriculum/00-roadmap.md` (RD-10 Done, 10/11) and
  `codeops/00-roadmap.md` (10 plans done).

## Related Files

- `lessons/part10-capstones/69-pong/` — main + three solutions.
- `lessons/part10-capstones/70-breakout/` — main + three solutions.
- `lessons/part10-capstones/71-maze-explorer/` — main + three solutions, generator, spec, include.
- `lessons/part10-capstones/72-your-game/` — `demo-72.asm`.
- `docs/part10-capstones/69-pong.md`, `70-breakout.md`, `71-maze-explorer.md`, `72-your-game.md`.
- `docs/public/roms/part10-capstones/` — the committed ROMs.
- `docs/public/images/lesson69/`, `lesson70/`, `lesson71/`, `lesson72/` — the captures.
