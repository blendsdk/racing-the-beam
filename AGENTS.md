# Racing the Beam — Agent Guide

Racing the Beam is a 79-lesson Atari 2600 assembly masterclass: buildable ACME lessons that run
in Stella, published as a VitePress site with per-lesson screenshots, downloadable ROMs, and an
in-browser Javatari player. This file is the entry point for every agent working in this repo.

## Load these skills first

| Task | Skill |
| --- | --- |
| Any Atari 2600 / 6502 writing, reviewing, or teaching | `atari-2600-expert` |
| Authoring or updating a lesson | `vcs-lesson-production` (plus `atari-2600-expert`) |

## The five lesson rules (hard stops — user policy)

1. **VitePress rework** after every lesson (sidebar, cross-refs, `npm run docs:build`, assets,
   prev/next, part index).
2. **Stella screenshots** for every lesson with visual output; theory lessons ship a standalone
   `demo-NN.asm` that visualizes the concept.
3. **Preflight before every lesson** — prerequisites, technical accuracy, screenshot plan. Any
   gap is a hard stop: raise it before writing content.
4. **README curriculum sync** whenever the curriculum listing changes — same atomic commit.
5. **Committed ROM + embedded player** for every buildable lesson (`npm run roms`, `<RomPlayer>`).

The detailed procedure and checklists live in the `vcs-lesson-production` skill.

## Curriculum is frozen

The 79-lesson structure (Parts 0–11) is fixed. Lesson 79 (Part 11) was added by the
user's decision on 2026-11-08; the structure is frozen again at 79. Do not add, remove,
rename, or reorder lessons or parts. Fixing text that disagrees with the curriculum
(counts, stale tool names) is expected; changing the structure is not.

## Commit & branch conventions

- One lesson = one atomic commit: `feat(lessonNN): <Lesson title>`.
- Fixes: `fix(lessonNN): …` · site/tooling: `chore(vitepress): …`, `chore(ci): …`, `chore(skills): …`.
- Integration branch: `master`. Lesson work commits directly; no long-lived feature branches
  unless a plan explicitly calls for one.
- Every change to sources, ROMs, or docs must pass `bash scripts/verify.sh` before commit.

<!-- CODEOPS-PROJECT:START -->

## Project facts (managed)

- **Type:** educational content repository — 79 Atari 2600 assembly lessons + a VitePress static site.
- **Languages:** 6502 assembly (ACME 0.97), TypeScript/Markdown (VitePress 1.6.4), Bash scripts.
- **Node:** 20+ (CI uses 20; local 24 works). Install with `npm ci`.

### Commands (use these; verified 2026-11-09 unless marked)

| Purpose | Command | Status |
| --- | --- | --- |
| Full verify (starter ROM + ROM drift + docs build) | `bash scripts/verify.sh` | ✅ verified (287 sources, docs build) |
| Assemble all lesson ROMs into `docs/public/roms/` | `npm run roms` | ✅ verified (287 ROMs, no drift) |
| Starter ROM | `acme -f plain -o build/game.bin src/main.asm` (or `make`) | ✅ verified |
| Docs build | `npm run docs:build` | ✅ verified |
| Docs dev / preview | `npm run docs:dev` · `npm run docs:preview` | not exercised this run |
| Stella screenshot | `bash scripts/capture-screenshot.sh <rom.bin> <out.png>` | ✅ verified (1010x807 capture) |
| Run in Stella | `stella <rom.bin>` | ✅ installed (Stella 7.0) |

### Structure

- `lessons/partN-topic/NN-slug/` — lesson assembly (+ `exercise-NN-solution.asm`, `demo-NN.asm`);
  287 ACME sources across Parts 0–11.
- `docs/partN-topic/NN-slug.md` — 79 lesson documents; `docs/reference/` — instruction,
  TIA-register, colour and glossary pages.
- `include/vcs.asm` — TIA/RIOT register definitions (**ground truth for addresses**);
  `include/macro.asm` — `+clean_start`, `+vsync`, `+set_timer`, `+wait_timer`.
- `src/main.asm` — starter ROM. `scripts/` — ROM build, verify, screenshot tooling.
- `docs/public/roms/` — committed `.bin` outputs (287 lesson ROMs + the Part 9 batari Basic
  reference = 288 total); `docs/public/images/` — committed screenshots;
  `docs/public/javatari/` — third-party Javatari emulator (AGPL-3.0; do not modify, keep
  `license.txt`); see `THIRD-PARTY-NOTICES.md`.

### Generated / committed-file warnings

- `docs/public/roms/**/*.bin` are **generated build outputs that are committed**. Never edit
  them by hand; regenerate with `npm run roms` when lesson sources change, and let
  `scripts/verify.sh` catch drift.
- `docs/.vitepress/dist` and `cache` are generated; `build/` is scratch (gitignored).

### CI

- `.github/workflows/verify.yml` — installs acme, runs `scripts/verify.sh` (ROM drift + docs).
- `.github/workflows/deploy.yml` — builds and deploys the site to GitHub Pages on `master`.

### CodeOps artifacts

- Nested layout: `codeops/` — `00-roadmap.md` (portfolio), `features/curriculum/`
  (requirements and 12 plan folders), `specialists/` (briefs), `codeops.json` (routing).
  Layout marker: `codeops/.codeops.yml` (`integrationBranch: master`); the curriculum
  roadmap is complete at 11/11 RDs.
- Project agents live in `.opencode/agents/`; project skills in `.opencode/skills/`.

### Specialist coverage

`up to date (2026-11-09)` — `lesson-author`, `atari2600-reviewer`, `curriculum-auditor`
(`codeops/specialist-check.json`)

<!-- CODEOPS-PROJECT:END -->

<!-- CODEOPS-SPECIALISTS:START -->
Specialist agents (routing: `codeops/codeops.json`; briefs: `codeops/specialists/`):
- `atari2600-reviewer` — "Independently verifies the hardware and CPU correctness of Atari 2600 lesson code and content — TIA/RIOT semantics, timing and cycle claims, ACME syntax, and the classic failure modes."
- `curriculum-auditor` — "Independently audits lesson completeness against the course's five hard rules — screenshots, ROM/player artifacts, VitePress and README integration — and the didactic chain (prerequisites, exercises, "
- `lesson-author` — "Implements Racing the Beam lessons end-to-end — assembly, lesson document, exercise solutions, screenshots, committed ROMs, VitePress and README integration — under the course's five hard rules."
<!-- CODEOPS-SPECIALISTS:END -->
