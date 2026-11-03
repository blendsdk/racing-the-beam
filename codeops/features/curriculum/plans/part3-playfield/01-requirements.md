# Requirements: Part 3 — Playfield (Lessons 19–24)

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)
> **Source**: [curriculum/RD-03](../../requirements/RD-03-part3-playfield.md) — the OWNING requirements doc

## Scope of this plan (delta view)

### In this plan

- **RD-03 AC 1** — for each of lessons 19–24: assembly source, three
  `exercise-NN-solution.asm` files, a lesson document from the fixed template, Stella screenshots,
  a committed 4,096-byte ROM with `<RomPlayer>`, and the VitePress/part-index/prev-next/README
  updates.
- **RD-03 AC 2** — `bash scripts/verify.sh` passes with all six lessons included.
- **RD-03 AC 3** — claims follow the `atari-2600-expert` discipline; both specialists report no
  critical/major findings before a lesson is done.
- **RD-03 AC 4** — no lesson or part is added, removed, renamed, or reordered; Parts 0–2 stay as
  shipped.

### Deferred / out of this plan

- Lessons 25–78 — owned by RD-04 … RD-11; this plan ends at Part 3's last lesson.
- PAL video support — noted as an aside only, never exercised (AR-11).
- An observable `PFP` demonstration — needs a player/ball from Part 4; Lesson 20 teaches the bit
  and defers its visible effect (AR-14).
- Any new tooling, test framework, or generator — excluded by AR-7.

## Plan-local decisions

| Decision | Chosen | AR Ref |
| --- | --- | --- |
| Plan scope | RD-03 only; lessons 19–24 strictly sequential | AR-1 |
| Phase/session model | 6 phases, one per lesson; Sessions A/B/C; one task per lesson | AR-2 |
| Demo ROMs | None; each main ROM is directly visual | AR-3 |
| Verify command | `bash scripts/verify.sh` (detected from `AGENTS.md`; user-confirmed) | AR-4 |
| Specialist assignment | Both reviewers gate each lesson | AR-5 |
| Playfield timing evidence | State-log checkpoints + static cycle ledgers | AR-6 |
| New machinery | None — reuse the existing pipeline | AR-7 |
| Identifiers | Existing slugs and endpoints verbatim | AR-8 |
| Forward mentions | Name-only context notes; never used in code | AR-9 |
| Part index | Rebuilt to the Part 1 format in the Lesson 19 phase; rows flip per lesson | AR-10 |
| Video standard | NTSC only | AR-11 |
| Commits and records | One atomic commit per lesson (`git-commit` push mode); ledger, progress header, roadmap per lesson | AR-12 |
| Playfield write model | Registers re-read per half; writes land on the 4-clock pixel grid; L21 windows measured in Stella | AR-13 |
| Priority scope | `COLUPF` + score mode observable; `PFP` effect named for Part 4 | AR-14 |
| Data-driven kernel | 1-line, 192 rows, three parallel tables per level, three zero-page pointers | AR-15 |
| Multicolor kernel | 192-byte per-line `COLUPF` table through a pointer; two tables | AR-16 |
| Animation model | Frame-level symmetric gate; 9 states; 30-frame cadence | AR-17 |
| First-line phase | 5-cycle release matches the steady-state wake | AR-18 |

## Acceptance Criteria

Plan-local criteria only (RD-03 owns the lesson acceptance criteria):

1. Each lesson's ST cases are frozen in its Session A record before implementation starts, with a
   recorded red baseline (AR-2, AR-4).
2. Frozen ST expectations are never edited to match an implementation; a mismatch is fixed in the
   lesson artifacts (AR-4).
3. Each lesson phase completes only after both specialist reviews report no critical/major
   findings (AR-5).
4. Every playfield timing, geometry, or color claim is backed by a recorded state-log observation
   plus a static cycle ledger, and the task record states both (AR-6, AR-13).
5. Roadmap rows reflect Plan Created on plan creation and Done when all six lessons ship (AR-12).
