# RD-05: Part 5 — Sound (lessons 35–37)

> **Document**: RD-05-part5-sound.md
> **Status**: Draft
> **Created**: 2026-10-10
> **Project**: Racing the Beam
> **Depends On**: RD-04 (Part 4 — Sprites)
> **CodeOps Artifact Schema**: 1

---

## Feature Overview

Part 5 covers the TIA audio registers: sound effects, music playback, and the advanced audio
techniques the platform allows. Audio is the first purely temporal output in the course, so these
lessons build directly on the frame timing from Part 2.

## Lesson List

| # | Lesson |
|---|--------|
| 35 | Sound Effects |
| 36 | Music |
| 37 | Advanced Audio |

## Learning Outcomes

- The reader can build sound effects by programming `AUDC`, `AUDF`, and `AUDV`.
- The reader can play a tune from a note table with frame-based timing on both audio channels.
- The reader can extend the core techniques to richer audio and explain the platform's limits.

## Acceptance Criteria

1. [ ] For each of lessons 35–37: the full artifact set exists per `vcs-lesson-production` —
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

- **Requires:** RD-04 — Part 4. Preflight must confirm its lessons are complete (no forward references).
- **Depended on by:** RD-06, and later parts through the chain.

## Scope Decisions

| Decision | Options Considered | Chosen | Rationale | AR Ref |
|----------|-------------------|--------|-----------|--------|
| Part scope | One RD per part / one mega-RD / one RD per lesson | Part 5, lessons 35–37 only | Per-part planning and progress granularity | AR #3 |
| Definition of done | Five hard rules + `verify.sh` + reviews / lighter checks | Full gate per lesson | User's quality mandate | AR #5 |
| Claim standard | Claim discipline / free-form prose | Observed/documented/derived claims; `include/vcs.asm` ground truth | Reviewable, verified claims | AR #6 |

## Security Considerations

N/A — static content and local ROMs only; no user input, authentication, secrets, or server-side
processing. The bundled Javatari player stays unmodified (AR #9).
