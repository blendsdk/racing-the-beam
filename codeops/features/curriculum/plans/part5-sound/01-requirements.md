# Requirements: Part 5 — Sound (Lessons 35–37)

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)
> **Source**: [curriculum/RD-05](../../requirements/RD-05-part5-sound.md) — the OWNING requirements doc

## Scope of this plan (delta view)

### In this plan

- **RD-05 AC 1** — for each of lessons 35–37: an annotated main source, three
  `exercise-NN-solution.asm` files (the lessons have exercises), a lesson document from the fixed
  template, two Stella screenshots, a committed 4,096-byte ROM with `<RomPlayer>`, and the
  VitePress/part-index/prev-next updates. Lesson 37 also ships `include/sound.asm` (AR-7, AR-18).
- **RD-05 AC 2** — `bash scripts/verify.sh` passes with all three lessons included.
- **RD-05 AC 3** — audio claims follow the `atari-2600-expert` discipline; both specialists report
  no critical/major findings before a lesson is done.
- **RD-05 AC 4** — no lesson or part is added, removed, renamed, or reordered; Parts 0–4 stay as
  shipped.

### Deferred / out of this plan

- Lessons 38–78 — owned by RD-06 … RD-11; this plan ends at Part 5's last lesson.
- PAL audio timing and PAL note tables — noted as an aside only, never exercised (AR-11).
- A full music tracker, sampled audio, and preemption-with-resume in the sound engine — named as
  later refinements only (AR-18).
- An audio-capture or waveform-analysis tool — excluded by AR-6 and AR-7.

## Plan-local decisions

| Decision | Chosen | AR Ref |
| --- | --- | --- |
| Plan scope | RD-05 only; lessons 35–37 strictly sequential | AR-1 |
| Phase/session model | 3 phases, one per lesson; Sessions A/B/C; one task per lesson | AR-2 |
| Demo ROMs | None; each main ROM is a visual monitor | AR-3 |
| Verify command | `bash scripts/verify.sh` (detected from `AGENTS.md`; course policy) | AR-4 |
| Specialist assignment | Both reviewers gate each lesson | AR-5 |
| Audio evidence | State-log checkpoints + static ledgers + pixel checks; the ROM is the audible artifact | AR-6, AR-22 |
| New machinery | `include/sound.asm` only (Lesson 37) | AR-7 |
| Identifiers | Existing slugs and endpoints verbatim | AR-8 |
| Forward mentions | Name-only context notes; never used in code | AR-9 |
| Part index | Rebuilt to the Part 1 format in the Lesson 35 phase; rows flip per lesson | AR-10 |
| Video standard | NTSC only | AR-11 |
| Commits and records | One atomic commit per lesson (`git-commit` push mode); ledger, progress header, roadmap per lesson | AR-12 |
| Lesson 35 monitor | Three effect bands, a 15-cell VU meter, a pitch marker; auto-cycle | AR-13, AR-14 |
| Lesson 36 monitor | Eight-rung note ladder, lead/harmony markers; one div-6 note table | AR-15, AR-16, AR-17 |
| Lesson 37 monitor + engine | Two-channel mixer, priority bar; 8-byte definitions, two channels, priority, non-looping end mute | AR-18, AR-19, AR-20 |
| Exercises | Three per lesson, all assembling and verified | AR-21 |
| Screenshots | Two per lesson, committed-ROM provenance, burst selection | AR-23 |
| Completion | 12 ROMs, 3 docs, 6 screenshots; RD-05 Done; 5/11 RDs | AR-24 |
| RAM map | `$80–$87` lesson, `$88–$8F` engine scratch, `$90–$9F` engine state | AR-25 |
| Audio update | VBLANK; registers hold; `AUDV=0` mutes, `AUDC=0` disables | AR-26 |

## Acceptance Criteria

Plan-local criteria only (RD-05 owns the lesson acceptance criteria):

1. Each lesson's ST cases are frozen in its Session A record before implementation starts, with a
   recorded red baseline (AR-2, AR-4).
2. Frozen ST expectations are never edited to match an implementation; a mismatch is fixed in the
   implementation or escalated (the immutable-oracle rule in [07-testing-strategy.md](07-testing-strategy.md)).
3. Every audio claim names the observed register write and the formula or generator behind it
   (AR-6, AR-22).
4. Every screenshot is captured from the committed ROM path and pixel-checked against the layout
   and state log (AR-23).
5. Every exercise solution assembles to 4,096 bytes, runs in Stella, and produces the documented
   result (AR-21).
6. `bash scripts/verify.sh` is green at every lesson commit and at Part 5 completion (AR-4).
7. Both specialists report no critical/major findings before a lesson is marked done (AR-5).
8. The Part 5 index, prev/next links, sidebar, and README are coherent after the last lesson
   (AR-10, AR-24).
