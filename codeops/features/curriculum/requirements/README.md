# Curriculum — Requirements Documents

> **Project**: Racing the Beam — 78-lesson Atari 2600 assembly course published as a static site
> **Status**: Draft
> **Created**: 2026-10-10
> **Architecture**: ACME 0.97 assembly lessons + VitePress 1.6.4 site
> **CodeOps Artifact Schema**: 1

---

## Overview

**Feature goal:** deliver the remaining lessons of the frozen 78-lesson curriculum at the quality
bar of the six completed lessons (01–06): real ROMs, Stella screenshots, working navigation.

The curriculum is **frozen** (AR #1): no lesson or part may be added, removed, renamed, or
reordered. These requirements cover the existing Parts 1–11 — lessons 07–78 (72 lessons).

**Domain lenses** (per `.opencode/references/domains/selection.md`): **web-application** — the
published static site (VitePress pages, sidebar, navigation, in-browser Javatari player); and
**compiler-and-language** — 6502/6507 assembly semantics, ACME sources, and ROM build outputs.

## Minimum-Sufficient Baseline

**Original goal:** a complete course site for all 78 frozen lessons. **Smallest viable design:**
the existing per-lesson production pipeline. **Excluded support machinery:** content generators,
new build or test frameworks, hosting changes. **Approved complexity:** None.

## Document Index

| # | Document | Description | Status |
|---|----------|-------------|--------|
| **AR** | [Ambiguity Register](00-ambiguity-register.md) | Zero-Ambiguity Gate decisions (audit trail) | ✅ Passed |
| **RD-01** | [Part 1 — The 6502 CPU](RD-01-part1-6502.md) | Lessons 07–11 (04–06 complete) | Draft |
| **RD-02** | [Part 2 — TV & TIA](RD-02-part2-tv-tia.md) | Lessons 12–18 | Draft |
| **RD-03** | [Part 3 — Playfield](RD-03-part3-playfield.md) | Lessons 19–24 | Draft |
| **RD-04** | [Part 4 — Sprites](RD-04-part4-sprites.md) | Lessons 25–34 | Draft |
| **RD-05** | [Part 5 — Sound](RD-05-part5-sound.md) | Lessons 35–37 | Draft |
| **RD-06** | [Part 6 — Game Development](RD-06-part6-game-dev.md) | Lessons 38–47 | Draft |
| **RD-07** | [Part 7 — Kernel Mastery](RD-07-part7-kernel-mastery.md) | Lessons 48–55 | Draft |
| **RD-08** | [Part 8 — Advanced Topics](RD-08-part8-advanced.md) | Lessons 56–65 | Draft |
| **RD-09** | [Part 9 — The DSL Path](RD-09-part9-dsl-path.md) | Lessons 66–68 | Draft |
| **RD-10** | [Part 10 — Capstone Projects](RD-10-part10-capstones.md) | Lessons 69–72 | Draft |
| **RD-11** | [Part 11 — Legendary Techniques](RD-11-part11-legendary.md) | Lessons 73–78 | Draft |

## Dependency Graph

RD-01 → RD-02 → RD-03 → RD-04 → RD-05 → RD-06 → RD-07 → RD-08 → RD-09 → RD-10 → RD-11

Each part assumes the lessons before it; lessons publish without forward references.

## Key Architecture Decisions

| Decision | Choice | Rationale | AR |
|----------|--------|-----------|----|
| Feature modeling | One feature `curriculum` | One pipeline, one quality gate, one backlog | AR #2 |
| RD granularity | One RD per part (RD-01..RD-11) | Matches the curriculum structure; per-part progress | AR #3 |
| Plan granularity | One plan per RD, one task per lesson | RD-01 plans first | AR #4 |
| Lesson done | Five hard rules + `verify.sh` + independent reviews | User's quality mandate | AR #5 |
| Claim standard | Claim discipline; `include/vcs.asm` ground truth | Reviewable, verified claims | AR #6 |
