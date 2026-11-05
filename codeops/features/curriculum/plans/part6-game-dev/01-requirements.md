# Requirements: Part 6 — Game Development (Lessons 38–47)

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)
> **Source**: [curriculum/RD-06](../../requirements/RD-06-part6-game-dev.md) — the OWNING requirements doc

## Scope of this plan (delta view)

### In this plan

- **RD-06 AC 1** — for each of lessons 38–47: an annotated main source, three
  `exercise-NN-solution.asm` files, a lesson document from the fixed template, two Stella
  screenshots, a committed 4,096-byte ROM with `<RomPlayer>`, and the VitePress/part-index/prev-next
  updates. Lesson 39 also ships `include/score.asm`; Lesson 43 ships `include/random.asm`; Lesson 47
  ships `demo-47.asm` (AR-3, AR-7).
- **RD-06 AC 2** — `bash scripts/verify.sh` passes with all ten lessons included.
- **RD-06 AC 3** — technical claims follow the `atari-2600-expert` discipline; both specialists
  report no critical/major findings before a lesson is done.
- **RD-06 AC 4** — no lesson or part is added, removed, renamed, or reordered; Parts 0–5 stay as
  shipped.

### Deferred / out of this plan

- Lessons 48–78 — owned by RD-07 … RD-11; this plan ends at Part 6's last lesson.
- PAL timing and PAL layouts — noted as an aside only, never exercised (AR-11).
- A full game engine, a scrolling-text renderer, sampled audio, and battery-backed save data —
  named as later refinements only (AR-7, AR-22).
- Additional capture or test tooling — excluded by AR-6 and AR-7.

## Plan-local decisions

| Decision | Chosen | AR Ref |
| --- | --- | --- |
| Plan scope | RD-06 only; lessons 38–47 strictly sequential | AR-1, AR-38 |
| Phase/session model | 10 phases, one per lesson; Sessions A/B/C | AR-2 |
| Demo ROMs | Lesson 47 only; 38–46 are playable labs | AR-3 |
| Verify command | `bash scripts/verify.sh` (detected from `AGENTS.md`; course policy) | AR-4 |
| Specialist assignment | Both reviewers gate each lesson; `lesson-author` implements | AR-5 |
| Evidence | State-log checkpoints + static ledgers + pixel checks; the ROM is runnable | AR-6, AR-28 |
| New machinery | `include/score.asm`, `include/random.asm`, `demo-47.asm` | AR-7 |
| Identifiers | Existing slugs and endpoints verbatim | AR-8 |
| Forward mentions | Name-only context notes; never used in code | AR-9 |
| Part index | Rebuilt in the Lesson 38 phase; rows flip per lesson | AR-10 |
| Video standard | NTSC only | AR-11 |
| Commits and records | One atomic commit per lesson (`git-commit` push mode); ledger, progress header, roadmap per lesson | AR-12 |
| Lesson 38 monitor | Four collision bands + 15-cell hit bar | AR-13 |
| Lesson 39 monitor + library | 48-pixel six-digit score + `include/score.asm` | AR-14, AR-15, AR-31 |
| Lesson 40 monitor | BCD score, operation bar, carry cell | AR-16, AR-33 |
| Lesson 41 monitor | Title/play/over state layouts + hit bar | AR-17 |
| Lesson 42 monitor | Difficulty ladder, level bar, life cells | AR-18 |
| Lesson 43 monitor + library | 8×8 LFSR history + seed meter + `include/random.asm` | AR-19 |
| Lesson 44 monitor | Patrol/chase/flee enemy + state row | AR-20 |
| Lesson 45 monitor | 16×8 RAM map + four flag bytes (packed in ex 1) + packed timer | AR-21, AR-34 |
| Lesson 46 monitor | Bug/fix debug lab | AR-22, AR-35 |
| Lesson 47 demo | Build-pipeline dashboard + ACME macro/`!if` | AR-23, AR-36 |
| Audio | Tiny direct beep per lesson; no sound engine | AR-24 |
| RAM map | `$80–$9F` lesson, `$A0–$D7` score or `$A0–$A8` random, `$A9–$D7` free in 43, `$D8–$F7` free, `$F8–$FF` stack | AR-25 |
| Screenshots | Two per lesson, committed-ROM provenance, burst selection | AR-26 |
| Exercises | Three per lesson, all assembling and verified | AR-27 |
| Frame | 262 lines, work-first (score kernel WSYNC-first), one `HMOVE` where sprites are placed | AR-29 |
| Completion | 40 sources, 40 ROMs, 10 docs, 20 screenshots; RD-06 Done; 6/11 RDs | AR-30 |
| Scoreboard timing | Staugas kernel, 8 rows, bottom-up font | AR-31 |
| Collision order | Read then `CXCLR`; one-frame latency documented | AR-32 |
| BCD conversion | 3 bytes → 6 digits via `ScoreSetDigit`; `CLD` restored | AR-33 |
| Lesson 45 bits | Static 8×3 map table | AR-34 |
| Lesson 46 paths | Three bug/fix code paths | AR-35 |
| Lesson 47 checksum | Runtime sum of a 256-byte table | AR-36 |
| Document template | Fixed six-section template + TypeScript equivalent | AR-37 |

## Acceptance Criteria

Plan-local criteria only (RD-06 owns the lesson acceptance criteria):

1. Each lesson's ST cases are frozen in its Session A record before implementation starts, with a
   recorded red baseline (AR-2, AR-4).
2. Frozen ST expectations are never edited to match an implementation; a mismatch is fixed in the
   implementation or escalated (the immutable-oracle rule in [07-testing-strategy.md](07-testing-strategy.md)).
3. Every collision, score, state, LFSR, AI, and memory claim names the observed register/RAM value
   at a labelled checkpoint (AR-6, AR-28).
4. Every screenshot is captured from the committed ROM path and pixel-checked against the layout
   and state log (AR-26).
5. Every exercise solution assembles to 4,096 bytes, runs in Stella, and produces the documented
   result (AR-27).
6. `bash scripts/verify.sh` is green at every lesson commit and at Part 6 completion (AR-4).
7. Both specialists report no critical/major findings before a lesson is marked done (AR-5).
8. The Part 6 index, prev/next links, sidebar, and README are coherent after the last lesson
   (AR-10, AR-30).
