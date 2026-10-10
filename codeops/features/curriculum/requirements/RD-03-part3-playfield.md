# RD-03: Part 3 — Playfield (lessons 19–24)

> **Document**: RD-03-part3-playfield.md
> **Status**: Draft
> **Created**: 2026-10-10
> **Project**: Racing the Beam
> **Depends On**: RD-02 (Part 2 — TV & TIA)
> **CodeOps Artifact Schema**: 1

---

## Feature Overview

Part 3 delivers the playfield: the 20-bit background layer that carries levels, mazes, scores,
and scene furniture. The lessons move from basic setup to asymmetric, animated, data-driven, and
multicolor playfields.

## Lesson List

| # | Lesson |
|---|--------|
| 19 | Playfield Basics |
| 20 | Playfield Colors & Priority |
| 21 | Asymmetric Playfield |
| 22 | Playfield Animation |
| 23 | Data-Driven Playfield |
| 24 | Multicolor Playfield |

## Learning Outcomes

- The reader can draw the playfield with `PF0`–`PF2` and the symmetry controls.
- The reader can apply playfield colors (`COLUPF`) and priority (`CTRLPF`).
- The reader can build asymmetric playfields and animate them frame to frame.
- The reader can drive playfield data from tables and give regions different colors.

## Acceptance Criteria

1. [ ] For each of lessons 19–24: the full artifact set exists per `vcs-lesson-production` —
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

- **Requires:** RD-02 — Part 2. Preflight must confirm its lessons are complete (no forward references).
- **Depended on by:** RD-04, and later parts through the chain.

## Scope Decisions

| Decision | Options Considered | Chosen | Rationale | AR Ref |
|----------|-------------------|--------|-----------|--------|
| Part scope | One RD per part / one mega-RD / one RD per lesson | Part 3, lessons 19–24 only | Per-part planning and progress granularity | AR #3 |
| Definition of done | Five hard rules + `verify.sh` + reviews / lighter checks | Full gate per lesson | User's quality mandate | AR #5 |
| Claim standard | Claim discipline / free-form prose | Observed/documented/derived claims; `include/vcs.asm` ground truth | Reviewable, verified claims | AR #6 |

## Security Considerations

N/A — static content and local ROMs only; no user input, authentication, secrets, or server-side
processing. The bundled Javatari player stays unmodified (AR #9).
