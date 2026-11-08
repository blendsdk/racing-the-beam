# Lessons 73–78 — The Rest of Part 11

> **Status**: Adopted 2026-11-08. Lessons 73–78 are the remaining six lessons of RD-11.
> **Base commit**: `496a346` (Lesson 79 complete; Part 11 at 1/7 lessons).
> **Repository**: `/home/gevik/workdir/2600/racing-the-beam`

## Scope

Six lessons, in curriculum order:

| # | Slug | Title |
|---|---|---|
| 73 | `73-cosmic-ark-starfield` | The HMOVE Comb & the Cosmic Ark Starfield |
| 74 | `74-skipdraw-kernel` | Skipdraw — The Classic Sprite Kernel Idiom |
| 75 | `75-pseudo-3d-road` | Pseudo-3D Road — The Enduro / Pole Position Effect |
| 76 | `76-procedural-worlds` | Procedural Worlds from a Seed — Pitfall! & River Raid |
| 77 | `77-interlaced-flicker` | Interlaced Flicker — Faking More Colours & Resolution |
| 78 | `78-room-object-engine` | Room & Object Engine — The Adventure Architecture |

Each lesson ships the full artifact set: the main source, two exercise solutions, the lesson
document, two real Stella captures, and the committed ROMs. The site integration flips the
lesson's Part 11 row and sidebar entry; the final integration commit wires the prev/next chain.

## Why one combined plan

The six lessons share one production loop, one testing strategy, and one integration
checklist. Their designs differ; the specs are in `01-lesson-specs.md`, one section per
lesson. Lesson-specific findings are recorded in `04-findings.md`.

## Constraints

- 4,096-byte ROMs, ACME 0.97, `include/vcs.asm` as register ground truth.
- NTSC 262 lines: 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan.
- The curriculum is frozen at 79; no lesson is renumbered, renamed, or reordered.
- Historical claims are separated from what this ROM implements; the lessons reproduce a
  convincing effect and say so. No bit-exactness claim without a source and a Stella check.
- The original course marks are used (`RACING`), never a trademarked company wordmark.
