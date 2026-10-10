# Requirements: Part 1 — The 6502 CPU (Lessons 07–11)

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)
> **Source**: [curriculum/RD-01](../../requirements/RD-01-part1-6502.md) — the OWNING requirements doc

## Scope of this plan (delta view)

### In this plan

- **RD-01 AC 1** — for each of lessons 07–11: assembly source (exercise solutions; `demo-10.asm` for the theory lesson), a lesson document from the template, Stella screenshots, a committed ROM with `<RomPlayer>`, and the VitePress/part-index/prev-next/README updates.
- **RD-01 AC 2** — `bash scripts/verify.sh` passes with all five lessons included.
- **RD-01 AC 3** — claims follow the `atari-2600-expert` discipline; both specialists report no critical/major findings before a lesson is done.
- **RD-01 AC 4** — no lesson or part is added, removed, renamed, or reordered; lessons 04–06 stay as shipped.

### Deferred / out of this plan

- Lessons 12–78 — owned by RD-02 … RD-11; this plan ends at Part 1's last lesson.
- Any new tooling, test framework, or generator — excluded by AR-7; no deferral needed.

## Plan-local decisions

| Decision | Chosen | AR Ref |
| --- | --- | --- |
| Plan scope | RD-01 only; lessons 07–11 strictly sequential | AR-1 |
| Phase/session model | 5 phases, one per lesson; Sessions A/B/C; one task per lesson | AR-2 |
| Specification-test approach | Observational acceptance cases with frozen expected outcomes | AR-3 |
| Verify command | `bash scripts/verify.sh` (detected from `AGENTS.md`) | AR-4 |
| Specialist assignment | `lesson-author` implements; both reviewers gate each lesson | AR-5 |
| Screenshots and demo ROM | Existing capture script; `demo-10.asm` for lesson 10 | AR-6 |
| New machinery | None — reuse the existing pipeline | AR-7 |
| Commit behavior | One atomic commit per lesson via the `git-commit` skill (push mode) | AR-8 |
| Content sources | RD-01 + `config.ts` titles + `atari-2600-expert` + `include/vcs.asm` | AR-9 |
| Roadmap sync | RD-01 → Plan Created now; Done at completion | AR-10 |

## Acceptance Criteria

Plan-local criteria only (RD-01 owns the lesson acceptance criteria):

1. Each lesson's ST cases are frozen in its Session A record before implementation starts, with a recorded red baseline (AR-2, AR-3).
2. Frozen ST expectations are never edited to match an implementation; a mismatch is fixed in the lesson artifacts (AR-3).
3. Each lesson phase completes only after both specialist reviews report no critical/major findings (AR-5).
4. Roadmap rows reflect Plan Created on plan creation and Done when all five lessons ship (AR-10).
