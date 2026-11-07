# Requirements: Part 8 — Advanced Topics (Lessons 56–65)

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)
> **Source**: [curriculum/RD-08](../../requirements/RD-08-part8-advanced.md) — the OWNING requirements doc

## Scope of this plan (delta view)

### In this plan

- **RD-08 AC 1** — for each of lessons 56–65: the lesson artifact set. Buildable lessons
  56–61 and 65 ship an annotated main source, three `exercise-NN-solution.asm` files, a lesson
  document from the fixed template, two Stella screenshots, a committed mapper-correct ROM with
  `<RomPlayer>`, and the VitePress/part-index/prev-next updates. Theory lessons 62–64 ship a
  standalone `demo-NN.asm`, two screenshots, a document, a committed ROM, and the same site
  integration; their exercises are analysis/production tasks answered in the document.
- **RD-08 AC 2** — `bash scripts/verify.sh` passes with all ten lessons included.
- **RD-08 AC 3** — technical claims follow the `atari-2600-expert` discipline; both specialists
  report no critical/major findings before a lesson is done.
- **RD-08 AC 4** — no lesson or part is added, removed, renamed, or reordered; Parts 0–7 stay as
  shipped.

### Deferred / out of this plan

- Lessons 66–78 — owned by RD-09 … RD-11.
- A DPC+ build (needs an ARM toolchain and Harmony/Melody hardware) — documented only (AR-13).
- PCB Gerbers, a bill of materials order, and a physical build — the lesson ships a burn-in ROM
  and prose, not manufacturing files (AR-19).
- A general bankswitching/compression library, an LZ compressor, a new emulator, or emulator
  modifications — excluded by AR-28 and AR-29.

## Plan-local decisions

| Decision | Chosen | AR Ref |
| --- | --- | --- |
| Plan scope | RD-08 only; lessons 56–65 strictly sequential | AR-1 |
| Phase/session model | 10 phases, one per lesson; Sessions A/B/C; completion gate | AR-2 |
| Lesson artifacts | 7 buildable labs (4 sources each); 3 theory demos (1 source) | AR-3 |
| Verify command | `bash scripts/verify.sh` | AR-4 |
| Specialist assignment | Both reviewers gate each lesson; `lesson-author` implements | AR-5 |
| Evidence | State-log checkpoints + static ledgers + pixel checks | AR-23 |
| New machinery | None; lesson-local layouts only | AR-28 |
| ROM sizes | 4K, 8K, 10K, 16K | AR-8 |
| Mapper choices | 56 F8; 57 F8SC; 60 DPC; 56-ex2 F6; rest 4K | AR-9 |
| Start bank | F8/F8SC/DPC bank 1; F6 bank 0 | AR-10 |
| Superchip | F8SC, `$1000–$107F`/`$1080–$10FF`, code `$F100` | AR-11 |
| DPC | 10K, bank 1, entry `$F080`, display at offset 8K | AR-12 |
| DPC+ | Documented only | AR-13 |
| Illegal opcodes | Stable NMOS set, `!byte` macros | AR-14 |
| Self-modifying | Routine `$80–$88`, variables `$89–$9F`, stack `$F8–$FF` | AR-15 |
| Compression | RLE with a 3-byte row buffer | AR-16 |
| Reverse engineering | Course-written classic-style ROM | AR-17 |
| Homebrew | Attract-mode demo | AR-18 |
| Cartridge | Burn-in test ROM | AR-19 |
| PAL/NTSC | Selector + adaptive 262/312 lines; no auto-detect claim | AR-20 |
| Frame | 262 NTSC; 312 PAL in Lesson 65; top-down loops; one HMOVE per event | AR-21 |
| RAM map | `$80–$9F` variables; `$A0–$D7` free; `$D8–$F7` free; `$F8–$FF` stack | AR-22 |
| Screenshots | Two per lesson, committed-ROM provenance, pixel checks | AR-7, AR-23 |
| Exercises | Three per buildable lesson; analysis tasks for theory | AR-24 |
| Index/README | Part 8 index rebuilt; rows flip per lesson; README unchanged | AR-25 |
| Commits | One atomic `feat(lessonNN)` per lesson; plan+preflight first; push mode | AR-26 |
| Completion | 31 sources/ROMs, 10 docs, 21 screenshots; RD-08 Done; 8/11 RDs | AR-27 |
| Javatari | F8(+RAM)/DPC supported; bundle unmodified | AR-29 |

## Acceptance Criteria

Plan-local criteria only (RD-08 owns the lesson acceptance criteria):

1. Each lesson's ST cases are frozen in its Session A record before implementation starts, with a
   recorded red baseline (AR-2, AR-4).
2. Frozen ST expectations are never edited to match an implementation; a mismatch is fixed in the
   implementation or escalated (the immutable-oracle rule in [07-testing-strategy.md](07-testing-strategy.md)).
3. Every mapper, RAM-window, opcode, RAM-routine, DPC-fetcher, decompressor, and frame claim names
   the observed register/RAM value at a labelled checkpoint (AR-6, AR-23).
4. Every screenshot is captured from the committed ROM path and pixel-checked against the layout
   and state log (AR-7, AR-23).
5. Every shipped exercise solution assembles to the declared size, runs in Stella, and produces
   the documented result (AR-24).
6. Theory lessons (62–64) ship a runnable `demo-NN.asm`, two real captures, and a document whose
   analysis exercises are answered by the annotated listing (AR-3, AR-17–AR-19).
7. The Part 8 index is ✅ for every shipped lesson and never says "Coming Soon" for a shipped
   row; the sidebar and prev/next links resolve; README row 8 is unchanged (AR-25).
8. The final gate runs `bash scripts/verify.sh`, counts the artifacts, confirms both reviewers
   have no critical/major open, and marks RD-08 Done (AR-27).
