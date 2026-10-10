# RD-04: Part 4 — Sprites (lessons 25–34)

> **Document**: RD-04-part4-sprites.md
> **Status**: Draft
> **Created**: 2026-10-10
> **Project**: Racing the Beam
> **Depends On**: RD-03 (Part 3 — Playfield)
> **CodeOps Artifact Schema**: 1

---

## Feature Overview

Part 4 covers the movable objects — both player sprites, the missiles and ball — plus positioning,
motion, animation, and controller inputs; sprites are the visual core of every later game.

## Lesson List

| # | Lesson |
|---|--------|
| 25 | Player Sprite Basics |
| 26 | Horizontal Positioning |
| 27 | Sprite Movement |
| 28 | Two Players |
| 29 | Missiles and Ball |
| 30 | Multi-Color Sprites |
| 31 | Copies and Sizes |
| 32 | Vertical Delay |
| 33 | Paddle & Keyboard Controllers |
| 34 | Sprite Animation |

## Learning Outcomes

- The reader can draw both players and position them with `RESP`/`HMOVE`.
- The reader can move sprites smoothly and animate them from frame tables.
- The reader can use missiles and the ball, and set copies and sizes with `NUSIZ`.
- The reader can apply multi-color sprite and `VDEL` vertical-delay techniques.
- The reader can read the paddle and keyboard controllers.

## Acceptance Criteria

1. [ ] For each of lessons 25–34: the full artifact set exists per `vcs-lesson-production` —
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

- **Requires:** RD-03 — Part 3. Preflight must confirm its lessons are complete (no forward references).
- **Depended on by:** RD-05, and later parts through the chain.

## Scope Decisions

| Decision | Options Considered | Chosen | Rationale | AR Ref |
|----------|-------------------|--------|-----------|--------|
| Part scope | One RD per part / one mega-RD / one RD per lesson | Part 4, lessons 25–34 only | Per-part planning and progress granularity | AR #3 |
| Definition of done | Five hard rules + `verify.sh` + reviews / lighter checks | Full gate per lesson | User's quality mandate | AR #5 |
| Claim standard | Claim discipline / free-form prose | Observed/documented/derived claims; `include/vcs.asm` ground truth | Reviewable, verified claims | AR #6 |

## Security Considerations

N/A — static content and local ROMs only; no user input, authentication, secrets, or server-side
processing. The bundled Javatari player stays unmodified (AR #9).
