# Current State: Part 1 — The 6502 CPU (Lessons 07–11)

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

### What Exists

- **A proven Part 1 lesson pattern (lessons 04–06).** Each shipped lesson has an annotated `.asm` source, `exercise-NN-solution.asm` files, a document from the fixed template, real Stella screenshots, a committed 4,096-byte ROM, and a `<RomPlayer>` embed with prev/next frontmatter.
  - Sources: `lessons/part1-6502-cpu/04-registers-and-memory/` (3 solutions), `…/05-arithmetic/` (3), `…/06-flags-and-comparisons/` (2).
  - Documents: `docs/part1-6502-cpu/04-registers-and-memory.md` … `06-flags-and-comparisons.md`.
  - Artifacts: `docs/public/roms/part1-6502-cpu/**/*.bin` (all exactly 4,096 bytes); `docs/public/images/lesson04/` … `lesson06/`.
- **Working rails.** `scripts/verify.sh` assembles every `lessons/**/*.asm`, compares each result with the committed ROM, and builds the docs (`scripts/verify.sh:66`); `scripts/build-roms.sh` (`npm run roms`) globs the same tree, so new lessons need no script change (`scripts/build-roms.sh:12`); `scripts/capture-screenshot.sh` captures real Stella frames with an xvfb fallback.
- **Pre-wired navigation.** Sidebar entries for 07–11 already exist (`docs/.vitepress/config.ts:48–52`); lesson 06 links forward to 07 in its frontmatter and its "What's Next" prose (`06-flags-and-comparisons.md:7–9`, `:380`).
- **Skills and specialists.** `vcs-lesson-production` defines the per-lesson cycle and checklists; `atari-2600-expert` defines claim discipline; `lesson-author`, `atari2600-reviewer`, and `curriculum-auditor` exist with routing in `codeops/codeops.json`.

### Relevant Files

| File / directory | Purpose | Changes needed |
| --- | --- | --- |
| `lessons/part1-6502-cpu/07-branches-and-loops/` … `11-lookup-tables/` | Lesson sources, solutions, `demo-10.asm` | Create |
| `docs/part1-6502-cpu/07-branches-and-loops.md` … `11-lookup-tables.md` | Lesson documents | Create |
| `docs/public/images/lesson07/` … `lesson11/`, `docs/public/roms/part1-6502-cpu/07…11/` | Screenshots and committed ROMs | Create (`capture-screenshot.sh`, `npm run roms`) |
| `docs/part1-6502-cpu/index.md` | Part index | Rows 07–11: 🔒 Coming Soon → ✅ Complete with links |
| `docs/.vitepress/config.ts` (lines 48–52) · `README.md` | Sidebar · curriculum listing | Verify only — entries already covered |
| `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md` | Tracking | Plan Created now; Done at completion (AR-10) |

### Code Analysis

New lessons follow the lesson 04 program shape: `!cpu 6502` with `include/vcs.asm` and `include/macro.asm`, origin `* = $F000`, `Reset` calling `+clean_start`, the frame skeleton (`+vsync`, `+set_timer`, `+wait_timer`), a kernel painting horizontal bands via `COLUBK` and `STA WSYNC`, and the vectors at `$FFFA`. Both build scripts glob the lessons tree, so no tooling change is needed; the only automated per-lesson gate is the byte-identical ROM drift check in `scripts/verify.sh`.

## Gaps Identified

### Gap 1: Lessons 07–11 have no sources or documents

**Current Behavior:** `lessons/part1-6502-cpu/` contains only 04–06; the 07–11 documents do not exist.
**Required Behavior:** Each lesson ships its full artifact set per RD-01 AC 1.
**Fix Required:** Author sources, solutions, `demo-10.asm`, and documents per [03-lesson-specs.md](03-lesson-specs.md).

### Gap 2: The part index still lists 07–11 as "Coming Soon"

**Current Behavior:** All five rows show 🔒 Coming Soon with no links (`docs/part1-6502-cpu/index.md:12–16`).
**Required Behavior:** Each row links its finished lesson and shows ✅ Complete.
**Fix Required:** Update the part index in each lesson's commit.

### Gap 3: No screenshots or committed ROMs exist for 07–11

**Current Behavior:** `docs/public/images/` ends at `lesson06`; the ROM tree has no 07–11 directories.
**Required Behavior:** Per-lesson screenshot sets and committed ROMs per the specs.
**Fix Required:** Capture with `scripts/capture-screenshot.sh`; build with `npm run roms`.

## Dependencies

### Internal Dependencies

- Lessons 01–06 (prerequisites and pattern); `include/vcs.asm`, `include/macro.asm`; both skills; the three specialists; `scripts/build-roms.sh`, `scripts/capture-screenshot.sh`, `scripts/verify.sh`.

### External Dependencies

- ACME 0.97, Stella 7.0 + ImageMagick, Node 20+ with VitePress 1.6.4.

## Risks and Concerns

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Incorrect technical claim in prose or code | Med | High | Claim discipline and `include/vcs.asm` ground truth (AR-9); Stella observation; `atari2600-reviewer` gate (AR-5) |
| Screenshot capture environment fails | Low | Med | Script verified end-to-end with xvfb fallback (AR-6) |
| ROM drift (committed `.bin` not regenerated) | Low | Med | `npm run roms` per lesson; `verify.sh` drift check (AR-4) |
| Scope creep into later parts | Low | Med | RD-01 scope and AR-1; frozen curriculum |
