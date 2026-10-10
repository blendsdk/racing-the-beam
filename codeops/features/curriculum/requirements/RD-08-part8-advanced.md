# RD-08: Part 8 — Advanced Topics (lessons 56–65)

> **Document**: RD-08-part8-advanced.md
> **Status**: Draft
> **Created**: 2026-10-10
> **Project**: Racing the Beam
> **Depends On**: RD-07 (Part 7 — Kernel Mastery)
> **CodeOps Artifact Schema**: 1

---

## Feature Overview

Part 8 covers shipping 2600 software for real: bank-switching, extra RAM, illegal opcodes,
self-modifying code, DPC/DPC+, compression, reverse engineering, homebrew, cartridges, PAL/NTSC.

## Lesson List

| # | Lesson |
|---|--------|
| 56 | Bankswitching |
| 57 | Superchip |
| 58 | Illegal Opcodes |
| 59 | Self-Modifying Code |
| 60 | DPC and DPC+ |
| 61 | Compression & Data Encoding |
| 62 | Reverse Engineering a Classic |
| 63 | Modern Homebrew |
| 64 | Building Your Own Cartridge |
| 65 | PAL/NTSC Universal ROM |

## Learning Outcomes

- The reader can bank-switch 8K/16K/32K ROMs and use superchip extra RAM.
- The reader can use illegal opcodes and self-modifying code where they are safe and justified.
- The reader can use DPC/DPC+ and compressed data encoding.
- The reader can reverse-engineer a classic game and describe modern homebrew practice.
- The reader can produce a cartridge image and a PAL/NTSC universal ROM.

## Acceptance Criteria

1. [ ] For each of lessons 56–65: the full artifact set exists per `vcs-lesson-production` —
   assembly source (`exercise-NN-solution.asm` when the lesson has exercises; `demo-NN.asm` for
   theory lessons), a lesson document following the lesson template, Stella screenshots captured
   from the real ROM under `docs/public/images/lessonNN/`, and each buildable lesson's `.bin`
   committed under `docs/public/roms/<part-folder>/NN-slug/` with a `<RomPlayer>` embed under the
   screenshot; the VitePress sidebar, part index, and prev/next links are updated; `README.md` is
   synced when the listing changes.
2. [ ] `bash scripts/verify.sh` passes (ROM drift check + docs build) with all listed lessons included.
3. [ ] Technical claims follow the `atari-2600-expert` claim discipline; `atari2600-reviewer` and
   `curriculum-auditor` report no critical/major findings before a lesson is considered done.
4. [ ] No lesson or part is added, removed, renamed, or reordered — the curriculum stays frozen (AR #1).

## Dependencies

- **Requires:** RD-07 — Part 7. Preflight must confirm its lessons are complete (no forward references).
- **Depended on by:** RD-09, and later parts through the chain.

## Scope Decisions

| Decision | Options Considered | Chosen | Rationale | AR Ref |
|----------|-------------------|--------|-----------|--------|
| Part scope | One RD per part / one mega-RD / one RD per lesson | Part 8, lessons 56–65 only | Per-part planning and progress granularity | AR #3 |
| Definition of done | Five hard rules + `verify.sh` + reviews / lighter checks | Full gate per lesson | User's quality mandate | AR #5 |
| Claim standard | Claim discipline / free-form prose | Observed/documented/derived claims; `include/vcs.asm` ground truth | Reviewable, verified claims | AR #6 |

## Security Considerations

N/A — static content and local ROMs only; no user input, authentication, secrets, or server-side
processing. The bundled Javatari player stays unmodified (AR #9).
