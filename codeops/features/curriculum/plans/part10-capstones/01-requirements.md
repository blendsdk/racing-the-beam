# Requirements: Part 10 — Capstone Projects (Lessons 69–72)

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)
> **Source**: [RD-10](../../requirements/RD-10-part10-capstones.md) — the OWNING requirements doc

## Scope of this plan (delta view)

### In this plan
- RD-10 AC 1 for lessons 69–72: the full artifact set — source, document, screenshots, committed
  ROMs, `<RomPlayer>`, VitePress index/sidebar/prev-next, README check.
- RD-10 AC 2: `bash scripts/verify.sh` passes with all four lessons included.
- RD-10 AC 3: both specialists report no critical/major before a lesson is done.
- RD-10 AC 4: the 78-lesson curriculum stays frozen (no add/remove/rename/reorder).

### Deferred / out of this plan
- RD-11 (Part 11 — Legendary Techniques).
- Any new mapper, bankswitching, or hardware support; all Part 10 ROMs are 4,096 bytes.
- A reusable game engine or a shared game library; each game is lesson-scoped.
- A Python step in CI; the Lesson 71 generator is an author tool.

## Plan-local decisions

| Decision | Chosen | AR Ref |
| -------- | ------ | ------ |
| Lesson 69 artifact | Pong + three solutions; custom score; 89-byte row table | AR-10, AR-11, AR-12, AR-13 |
| Lesson 70 artifact | Breakout + three solutions; brick map + PF table; three levels | AR-14, AR-15, AR-16 |
| Lesson 71 artifact | Mirror maze + three solutions; Python generator + include | AR-17–AR-21 |
| Lesson 72 artifact | Skeleton mini-game + design exercises (no solutions) | AR-22, AR-23 |
| Zone tables | Pong 89 bytes; Breakout 32-byte play table + 12-byte brick table; Maze 44-byte table | AR-24 |
| Screenshots | 3 + 3 + 3 + 2 = 11 | AR-7 |
| Completion | 13 ACME ROMs, 4 docs, 11 screenshots, 265/266 ROMs | AR-28 |

## Acceptance Criteria

1. [x] Lessons 69–72 each have the artifact set named in RD-10 AC 1.
2. [x] `bash scripts/verify.sh` passes with 265 ACME sources; the committed ROMs are byte-identical.
3. [x] Every game's auto-demo produces deterministic captures; the three/four states per lesson differ.
4. [x] The Lesson 71 generator's `--check` mode reports no drift; the maze spec validates.
5. [x] Every kernel ledger matches the measured Stella scanlines (259/37/229; 262 lines).
6. [x] Both specialists report no critical/major open for each lesson.
7. [x] The Part 10 index rows 69–72 are ✅; sidebar, prev/next, `<RomPlayer>`, README row 10 checked.
8. [x] RD-10 is Done; feature roadmap 10/11; portfolio 10 plans done.
