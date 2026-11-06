# Requirements: Part 7 — Kernel Mastery (Lessons 48–55)

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)
> **Source**: [curriculum/RD-07](../../requirements/RD-07-part7-kernel-mastery.md) — the OWNING requirements doc

## Scope of this plan (delta view)

### In this plan

- **RD-07 AC 1** — for each of lessons 48–55: an annotated main source, three
  `exercise-NN-solution.asm` files, a lesson document from the fixed template, two Stella
  screenshots, a committed 4,096-byte ROM with `<RomPlayer>`, and the VitePress/part-index/prev-next
  updates. Lesson 48 also ships `demo-48.asm`; Lesson 53 also ships
  `include/kernel_patterns.asm` (AR-3, AR-7).
- **RD-07 AC 2** — `bash scripts/verify.sh` passes with all eight lessons included.
- **RD-07 AC 3** — technical claims follow the `atari-2600-expert` discipline; both specialists
  report no critical/major findings before a lesson is done.
- **RD-07 AC 4** — no lesson or part is added, removed, renamed, or reordered; Parts 0–6 stay as
  shipped.

### Deferred / out of this plan

- Lessons 56–78 — owned by RD-08 … RD-11; this plan ends at Part 7's last lesson.
- PAL timing and PAL layouts — noted as an aside only, never exercised (AR-11).
- A sprite-scaling engine, a general text renderer beyond the 48-pixel window, a scrolling-world
  editor, sampled audio, and any emulator modification — named as later refinements only (AR-7).
- Additional capture or test tooling — excluded by AR-6 and AR-7.

## Plan-local decisions

| Decision | Chosen | AR Ref |
| --- | --- | --- |
| Plan scope | RD-07 only; lessons 48–55 strictly sequential | AR-1, AR-42 |
| Phase/session model | 8 phases, one per lesson; Sessions A/B/C | AR-2 |
| Demo ROMs | Lesson 48 only; 49–55 are kernel labs | AR-3 |
| Verify command | `bash scripts/verify.sh` (detected from `AGENTS.md`; course policy) | AR-4 |
| Specialist assignment | Both reviewers gate each lesson; `lesson-author` implements | AR-5 |
| Evidence | State-log checkpoints + static ledgers + pixel checks; the ROM is runnable | AR-6 |
| New machinery | `include/kernel_patterns.asm`, `demo-48.asm` | AR-7 |
| Identifiers | Existing slugs and endpoints verbatim | AR-8 |
| Forward mentions | Name-only context notes; never used in code | AR-9 |
| Part index | Rebuilt in the Lesson 48 phase; rows flip per lesson | AR-10 |
| Video standard | NTSC only | AR-11 |
| Commits and records | One atomic commit per lesson (`git-commit` push mode); ledger, progress header, roadmap per lesson | AR-12 |
| Lesson 48 monitor | Split 1-line/2-line kernel zoo + full modes | AR-13, AR-32 |
| Lesson 49 monitor | 2-line mountain pass | AR-14, AR-33 |
| Lesson 50 monitor | Score + status + play + ground dashboard | AR-15, AR-27, AR-34 |
| Lesson 51 monitor | Four-object flicker gallery; per-row skipdraw, no strips | AR-16, AR-29, AR-35 |
| Lesson 52 monitor | Three-plane vertical tunnel + 1-px HMOVE ship | AR-17, AR-30, AR-36 |
| Lesson 53 monitor + library | Four-band pattern sampler + `include/kernel_patterns.asm` | AR-18, AR-28, AR-37 |
| Lesson 54 monitor | Starfield, rainbow, centred pseudo-3D road reel | AR-19, AR-38 |
| Lesson 55 monitor | 48-pixel scrolling text marquee via `include/score.asm` | AR-20, AR-31, AR-39 |
| Audio | Tiny direct beep in the state-changing lessons | AR-21 |
| RAM map | `$80–$9F` lesson, `$A0` scratch in 51, `$A0–$D7` score in 50/55, `$80–$83` library + `$84–$9F` counters + `$A0–$D0` strip in 53, `$D8–$F7` free, `$F8–$FF` stack | AR-22 |
| Screenshots | Two per lesson, committed-ROM provenance, burst selection | AR-23 |
| Exercises | Three per lesson, all assembling and verified | AR-24 |
| Frame | 262 lines; work-first except documented cycle-timed kernels; `LDY #0; INY; CPY #N; BNE` top-down row loops; one HMOVE per repositioning event | AR-25 |
| Completion | 32 sources, 32 ROMs, 8 docs, 16 screenshots; RD-07 Done; 7/11 RDs | AR-26 |
| Score reuse | `include/score.asm` in 50 and 55; two HMOVEs in 50 | AR-27 |
| Library API | Four routines over a zero-page pointer; `$80–$83` | AR-28 |
| Flicker evidence | Two 30 Hz halves, not a merged image | AR-29 |
| Scroll evidence | 1-line/1-px measured steps | AR-30 |
| Text evidence | Buffer checkpoints + letters + scroll offset | AR-31 |
| Document template | Fixed six-section template + TypeScript equivalent | AR-6, AR-24 |

## Acceptance Criteria

Plan-local criteria only (RD-07 owns the lesson acceptance criteria):

1. Each lesson's ST cases are frozen in its Session A record before implementation starts, with a
   recorded red baseline (AR-2, AR-4).
2. Frozen ST expectations are never edited to match an implementation; a mismatch is fixed in the
   implementation or escalated (the immutable-oracle rule in [07-testing-strategy.md](07-testing-strategy.md)).
3. Every kernel, scroll, flicker, text, and zone claim names the observed register/RAM value at a
   labelled checkpoint (AR-6, AR-29–AR-31).
4. Every screenshot is captured from the committed ROM path and pixel-checked against the layout
   and state log (AR-23).
5. Every exercise solution assembles to 4,096 bytes, runs in Stella, and produces the documented
   result (AR-24).
6. `bash scripts/verify.sh` is green at every lesson commit and at Part 7 completion (AR-4).
7. Both specialists report no critical/major findings before a lesson is marked done (AR-5).
8. The Part 7 index, prev/next links, sidebar, and README are coherent after the last lesson
   (AR-10, AR-26).
