# RD-06: Part 6 — Game Development (lessons 38–47)

> **Document**: RD-06-part6-game-dev.md
> **Status**: Draft
> **Created**: 2026-10-10
> **Project**: Racing the Beam
> **Depends On**: RD-05 (Part 5 — Sound)
> **CodeOps Artifact Schema**: 1

---

## Feature Overview

Part 6 turns rendering skill into complete games: collisions, scoreboards, decimal math, game
states, difficulty, randomness, enemy behavior, memory management, debugging, and workflow.

## Lesson List

| # | Lesson |
|---|--------|
| 38 | Collision Detection |
| 39 | The Scoreboard |
| 40 | BCD Arithmetic |
| 41 | Game States |
| 42 | Difficulty and Progression |
| 43 | Random Numbers |
| 44 | AI & Enemy Behavior |
| 45 | Memory Management |
| 46 | Debugging |
| 47 | Development Tools & Workflow |

## Learning Outcomes

- The reader can detect collisions with the `CXM` registers and react to them.
- The reader can display a score and perform BCD arithmetic.
- The reader can structure a game with states and difficulty progression.
- The reader can generate pseudo-random numbers and implement enemy behavior.
- The reader can manage the 128-byte RAM budget, debug with Stella, and follow the course workflow.

## Acceptance Criteria

1. [ ] For each of lessons 38–47: the full artifact set exists per `vcs-lesson-production` —
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

- **Requires:** RD-05 — Part 5. Preflight must confirm its lessons are complete (no forward references).
- **Depended on by:** RD-07, and later parts through the chain.

## Scope Decisions

| Decision | Options Considered | Chosen | Rationale | AR Ref |
|----------|-------------------|--------|-----------|--------|
| Part scope | One RD per part / one mega-RD / one RD per lesson | Part 6, lessons 38–47 only | Per-part planning and progress granularity | AR #3 |
| Definition of done | Five hard rules + `verify.sh` + reviews / lighter checks | Full gate per lesson | User's quality mandate | AR #5 |
| Claim standard | Claim discipline / free-form prose | Observed/documented/derived claims; `include/vcs.asm` ground truth | Reviewable, verified claims | AR #6 |

## Security Considerations

N/A — static content and local ROMs only; no user input, authentication, secrets, or server-side
processing. The bundled Javatari player stays unmodified (AR #9).
