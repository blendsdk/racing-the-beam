# RD-07: Part 7 — Kernel Mastery (lessons 48–55)

> **Document**: RD-07-part7-kernel-mastery.md
> **Status**: Draft
> **Created**: 2026-10-10
> **Project**: Racing the Beam
> **Depends On**: RD-06 (Part 6 — Game Development)
> **CodeOps Artifact Schema**: 1

---

## Feature Overview

Part 7 moves from drawing a screen to architecting kernels: 1-line and 2-line display kernels,
multi-zone layouts, flicker, scrolling, reusable design patterns, and a visual-effects cookbook.
Kernel skill is what separates custom displays from stock ones in the advanced parts.

## Lesson List

| # | Lesson |
|---|--------|
| 48 | Introduction to Kernels |
| 49 | The 2-Line Kernel |
| 50 | Multi-Zone Kernel |
| 51 | Flicker Sprites |
| 52 | Fine Scrolling |
| 53 | Kernel Design Patterns |
| 54 | Visual Effects Cookbook |
| 55 | Scrolling Text Marquee |

## Learning Outcomes

- The reader can implement 1-line and 2-line kernels inside the 76-cycle scanline budget.
- The reader can build a multi-zone kernel with different rendering per zone.
- The reader can flicker sprites and fine-scroll the screen.
- The reader can apply kernel design patterns and visual-effects recipes.
- The reader can build a scrolling text marquee.

## Acceptance Criteria

1. [ ] For each of lessons 48–55: the full artifact set exists per `vcs-lesson-production` —
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

- **Requires:** RD-06 — Part 6. Preflight must confirm its lessons are complete (no forward references).
- **Depended on by:** RD-08, and later parts through the chain.

## Scope Decisions

| Decision | Options Considered | Chosen | Rationale | AR Ref |
|----------|-------------------|--------|-----------|--------|
| Part scope | One RD per part / one mega-RD / one RD per lesson | Part 7, lessons 48–55 only | Per-part planning and progress granularity | AR #3 |
| Definition of done | Five hard rules + `verify.sh` + reviews / lighter checks | Full gate per lesson | User's quality mandate | AR #5 |
| Claim standard | Claim discipline / free-form prose | Observed/documented/derived claims; `include/vcs.asm` ground truth | Reviewable, verified claims | AR #6 |

## Security Considerations

N/A — static content and local ROMs only; no user input, authentication, secrets, or server-side
processing. The bundled Javatari player stays unmodified (AR #9).
