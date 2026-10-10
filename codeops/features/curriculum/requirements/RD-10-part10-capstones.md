# RD-10: Part 10 — Capstone Projects (lessons 69–72)

> **Document**: RD-10-part10-capstones.md
> **Status**: Draft
> **Created**: 2026-10-10
> **Project**: Racing the Beam
> **Depends On**: RD-09 (Part 9 — The DSL Path)
> **CodeOps Artifact Schema**: 1

---

## Feature Overview

Part 10 is the capstone sequence: four complete games built end-to-end with the full course
pipeline. Pong, Breakout, and Maze Explorer apply the accumulated technique; the final lesson
scopes and delivers an original game.

## Lesson List

| # | Lesson |
|---|--------|
| 69 | Capstone: Pong |
| 70 | Capstone: Breakout |
| 71 | Capstone: Maze Explorer |
| 72 | Capstone: Your Own Game |

## Learning Outcomes

- The reader can build a complete Pong game with paddles, a ball, collisions, and a score.
- The reader can build a Breakout-style game with a brick field, paddle, and ball.
- The reader can build a maze-exploration game with map rendering and player movement.
- The reader can scope and deliver an original game with the course's production pipeline.

## Acceptance Criteria

1. [ ] For each of lessons 69–72: the full artifact set exists per `vcs-lesson-production` —
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

- **Requires:** RD-09 — Part 9. Preflight must confirm its lessons are complete (no forward references).
- **Depended on by:** RD-11, the final part.

## Scope Decisions

| Decision | Options Considered | Chosen | Rationale | AR Ref |
|----------|-------------------|--------|-----------|--------|
| Part scope | One RD per part / one mega-RD / one RD per lesson | Part 10, lessons 69–72 only | Per-part planning and progress granularity | AR #3 |
| Definition of done | Five hard rules + `verify.sh` + reviews / lighter checks | Full gate per lesson | User's quality mandate | AR #5 |
| Claim standard | Claim discipline / free-form prose | Observed/documented/derived claims; `include/vcs.asm` ground truth | Reviewable, verified claims | AR #6 |

## Security Considerations

N/A — static content and local ROMs only; no user input, authentication, secrets, or server-side
processing. The bundled Javatari player stays unmodified (AR #9).
