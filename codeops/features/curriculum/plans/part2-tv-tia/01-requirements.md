# Requirements: Part 2 — TV & TIA (Lessons 12–18)

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)
> **Source**: [curriculum/RD-02](../../requirements/RD-02-part2-tv-tia.md) — the OWNING requirements doc

## Scope of this plan (delta view)

### In this plan

- **RD-02 AC 1** — for each of lessons 12–18: assembly source (exercise solutions; `demo-NN.asm`
  only where required per AR-3, with the reason recorded in the lesson specification), a lesson
  document from the fixed template, Stella screenshots, a committed ROM with `<RomPlayer>`, and
  the VitePress/part-index/prev-next/README updates.
- **RD-02 AC 2** — `bash scripts/verify.sh` passes with all seven lessons included.
- **RD-02 AC 3** — claims follow the `atari-2600-expert` discipline; both specialists report no
  critical/major findings before a lesson is done.
- **RD-02 AC 4** — no lesson or part is added, removed, renamed, or reordered; Part 1 (lessons
  04–11) stays as shipped.

### Deferred / out of this plan

- Lessons 19–78 — owned by RD-03 … RD-11; this plan ends at Part 2's last lesson.
- PAL video support — noted as an aside only, never exercised (AR-11).
- Any new tooling, test framework, or generator — excluded by AR-7; no deferral needed.

## Plan-local decisions

| Decision | Chosen | AR Ref |
| --- | --- | --- |
| Plan scope | RD-02 only; lessons 12–18 strictly sequential | AR-1 |
| Phase/session model | 7 phases, one per lesson; Sessions A/B/C; one task per lesson | AR-2 |
| Demo ROMs | Only where a lesson's concept cannot be visualized by its main ROM; reason per lesson | AR-3 |
| Verify command | `bash scripts/verify.sh` (detected from `AGENTS.md`; user-confirmed) | AR-4 |
| Specialist assignment | `lesson-author` implements; both reviewers gate each lesson | AR-5 |
| Timing-claim evidence | State-log checkpoints + static cycle ledgers; labeled witnesses for what-ifs | AR-6 |
| New machinery | None — reuse the existing pipeline | AR-7 |
| Identifiers | Existing slugs and endpoints verbatim; Part 1 naming conventions | AR-8 |
| Forward mentions | Name-only context notes for later-part mechanisms; never used in code or exercises | AR-9 |
| Part index | Rebuilt to the Part 1 format in the lesson-12 phase; rows flip per lesson | AR-10 |
| Video standard | NTSC only (262 lines; ~60 Hz — ≈59.9 Hz derived in lesson 12) | AR-11 |
| Commits and records | One atomic commit per lesson (`git-commit` push mode); ledger, progress header, roadmap per lesson | AR-12 |

## Acceptance Criteria

Plan-local criteria only (RD-02 owns the lesson acceptance criteria):

1. Each lesson's ST cases are frozen in its Session A record before implementation starts, with a
   recorded red baseline (AR-2, AR-4).
2. Frozen ST expectations are never edited to match an implementation; a mismatch is fixed in the
   lesson artifacts (AR-4).
3. Each lesson phase completes only after both specialist reviews report no critical/major
   findings (AR-5).
4. Every timing, cycle, or frame claim is backed by a recorded state-log observation plus a static
   cycle ledger, and the task record states both (AR-6).
5. Roadmap rows reflect Plan Created on plan creation and Done when all seven lessons ship
   (AR-12).
