# RD-11: Part 11 — Legendary Techniques (lessons 73–79)

> **Document**: RD-11-part11-legendary.md
> **Status**: Complete 2026-11-09
> **Created**: 2026-10-10
> **Project**: Racing the Beam
> **Depends On**: RD-10 (Part 10 — Capstone Projects)
> **CodeOps Artifact Schema**: 1

---

## Feature Overview

Part 11 teaches the showcase techniques of the platform: the Cosmic Ark starfield, skipdraw
kernels, pseudo-3D roads, LFSR procedural worlds, interlaced flicker, a room-and-object
engine, and the publisher mark — a static 48-pixel brand in the bottom band. Each lesson starts
from source-cited mechanism research (AR #8), recorded as a dependency of the lesson tasks.

## Lesson List

| # | Lesson |
|---|--------|
| 73 | Cosmic Ark Starfield |
| 74 | Skipdraw Sprite Kernel |
| 75 | Pseudo-3D Road |
| 76 | Procedural Worlds (LFSR) |
| 77 | Interlaced Flicker |
| 78 | Room & Object Engine |
| 79 | The Publisher Mark — An Activision-Style In-Game Logo |

Lesson 79 is the 2026-11-08 user-authorized addition; Lessons 73–78 keep their numbers.

## Learning Outcomes

- The reader can reproduce the Cosmic Ark starfield effect.
- The reader can implement a skipdraw sprite kernel.
- The reader can render a pseudo-3D road.
- The reader can generate procedural worlds with an LFSR.
- The reader can use interlaced flicker and build a room-and-object engine.
- The reader can draw a static 48-pixel publisher mark in the bottom band from a ROM table.

## Acceptance Criteria

1. [x] For each of lessons 73–79: the full artifact set exists per `vcs-lesson-production` —
   assembly source (`exercise-NN-solution.asm` when the lesson has exercises; `demo-NN.asm` for
   theory lessons), a lesson document following the lesson template, Stella screenshots captured
   from the real ROM under `docs/public/images/lessonNN/`, and each buildable lesson's `.bin`
   committed under `docs/public/roms/<part-folder>/NN-slug/` with a `<RomPlayer>` embed under the
   screenshot; the VitePress sidebar, part index, and prev/next links are updated; `README.md` is
   synced when the listing changes.
2. [x] `bash scripts/verify.sh` passes (ROM drift check + docs build) with all listed lessons included.
3. [x] Technical claims follow the `atari-2600-expert` claim discipline; `atari2600-reviewer` and
   `curriculum-auditor` report no critical/major findings before a lesson is considered done.
4. [x] No further lesson or part is added, removed, renamed, or reordered — the amended
   79-lesson structure stays frozen (AR #1).

## Dependencies

- **Requires:** RD-10 — Part 10; plus source-cited mechanism research for each legendary technique before authoring (AR #8). Lesson 79 is authorized by the user on 2026-11-08; its mechanism is the documented 48-pixel trick from Lessons 39, 50, and 55.
- **Depended on by:** — (final RD).

## Scope Decisions

| Decision | Options Considered | Chosen | Rationale | AR Ref |
|----------|-------------------|--------|-----------|--------|
| Part scope | One RD per part / one mega-RD / one RD per lesson | Part 11, lessons 73–79 only | Per-part planning and progress granularity | AR #3 |
| Lesson 79 addition | Do not add / add at the start / add at the end | Add at the end of Part 11 | User-authorized 2026-11-08; preserves the 73–78 numbers; closes the in-game publisher-mark gap | AR #1 |
| Research first | Source-cited research before authoring / author from memory | Research first | Legendary techniques need verifiable mechanisms | AR #8 |
| Definition of done | Five hard rules + `verify.sh` + reviews / lighter checks | Full gate per lesson | User's quality mandate | AR #5 |
| Claim standard | Claim discipline / free-form prose | Observed/documented/derived claims; `include/vcs.asm` ground truth | Reviewable, verified claims | AR #6 |

## Security Considerations

N/A — static content and local ROMs only; no user input, authentication, secrets, or server-side
processing. The bundled Javatari player stays unmodified (AR #9).
