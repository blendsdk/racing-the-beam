# Current State: Part 2 — TV & TIA (Lessons 12–18)

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

### What Exists

- **Part 1 is complete (lessons 04–11).** Every Part 1 lesson has an annotated `.asm` source,
  `exercise-NN-solution.asm` files, a document from the fixed template, real Stella screenshots,
  a committed 4,096-byte ROM, and a `<RomPlayer>` embed with working prev/next frontmatter.
  - Sources: `lessons/part1-6502-cpu/04-registers-and-memory/` … `11-lookup-tables/`
    (`demo-10.asm` on lesson 10).
  - Documents: `docs/part1-6502-cpu/04-registers-and-memory.md` … `11-lookup-tables.md`.
  - Artifacts: `docs/public/roms/part1-6502-cpu/**/*.bin` (all exactly 4,096 bytes);
    `docs/public/images/lesson04/` … `lesson11/`.
- **Working rails.** `scripts/verify.sh` assembles every `lessons/**/*.asm`, compares each result
  with the committed ROM, and builds the docs; `scripts/build-roms.sh` (`npm run roms`) globs the
  same tree, so new lessons need no script change; `scripts/capture-screenshot.sh` captures real
  Stella frames (its pitfalls — committed-ROM provenance, pointer parking, moving-state bursts —
  are codified in the `vcs-lesson-production` checklist).
- **Proven timing-claim method.** Lessons 08–11 used `stella -dbg.logbreaks 1 -logtoconsole 1
  -break '$addr'` state logs with static cycle ledgers for runtime evidence; the method is
  recorded in the Part 1 register (AR-11 amendment) and becomes this plan's evidence standard
  (AR-6).
- **Pre-wired navigation.** Sidebar entries for 12–18 already exist (`docs/.vitepress/config.ts`,
  Part 2 block); lesson 11 links forward to lesson 12 in its frontmatter and its closing prose
  (`11-lookup-tables.md:624`). The Part 2 index page is a minimal stub
  (`docs/part2-tv-and-tia/index.md`) that AR-10 rebuilds to the Part 1 format.
- **Skills and specialists.** `vcs-lesson-production` defines the per-lesson cycle and
  checklists; `atari-2600-expert` defines claim discipline with `timing.md` and `tia-hardware.md`
  as the Part 2 references; `lesson-author`, `atari2600-reviewer`, and `curriculum-auditor` exist
  with routing in `codeops/codeops.json`.

### Relevant Files

| File / directory | Purpose | Changes needed |
| --- | --- | --- |
| `lessons/part2-tv-and-tia/12-the-ntsc-frame/` … `18-mid-scanline-changes/` | Lesson sources and exercise solutions | Create |
| `docs/part2-tv-and-tia/12-the-ntsc-frame.md` … `18-mid-scanline-changes.md` | Lesson documents (stubs today) | Replace stubs |
| `docs/public/images/lesson12/` … `lesson18/`, `docs/public/roms/part2-tv-and-tia/12…18/` | Screenshots and committed ROMs | Create (`capture-screenshot.sh`, `npm run roms`) |
| `docs/part2-tv-and-tia/index.md` | Part index (minimal stub) | Rebuild to the Part 1 format; rows flip per lesson (AR-10) |
| `docs/.vitepress/config.ts` (Part 2 block) · `README.md` | Sidebar · curriculum listing | Verify only — entries already covered |
| `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md` | Tracking | Plan Created now; Done at completion (AR-12) |

### Code Analysis

Part 2 lessons reuse the lesson 04–11 program shape: `!cpu 6502` with `include/vcs.asm` and
`include/macro.asm`, origin `* = $F000`, `Reset` calling `+clean_start`, the frame skeleton
(`+vsync`, `+set_timer`, `+wait_timer`), a kernel painting the visible area through `COLUBK` with
`STA WSYNC`, and the vectors at `$FFFA`. Part 2's lessons dissect exactly that skeleton: lesson
12 writes the frame out explicitly so every phase is visible in source; lessons 13–18 refine the
display and timing techniques inside it. Both build scripts glob the lessons tree, so no tooling
change is needed; the only automated per-lesson gate is the byte-identical ROM drift check in
`scripts/verify.sh`.

## Gaps Identified

### Gap 1: Lessons 12–18 have no sources or documents

**Current Behavior:** `lessons/part2-tv-and-tia/` does not exist; the seven documents are
19-line "Coming Soon" stubs.
**Required Behavior:** Each lesson ships its full artifact set per RD-02 AC 1 and the per-lesson
specifications ([03-lesson-specs.md](03-lesson-specs.md)).
**Fix Required:** Author sources, solutions, and documents per the specifications.

### Gap 2: The Part 2 index is a minimal stub

**Current Behavior:** `docs/part2-tv-and-tia/index.md` has no lesson table and no learning
summary; all seven sidebar links exist but the index does not list status.
**Required Behavior:** The Part 1 index format with rows 12–18; each row flips to ✅ Complete as
its lesson ships (AR-10).
**Fix Required:** Rebuild in the lesson-12 phase; update rows per lesson commit.

### Gap 3: No screenshots or committed ROMs exist for 12–18

**Current Behavior:** `docs/public/images/` ends at `lesson11`; the ROM tree has no Part 2
directories.
**Required Behavior:** Per-lesson screenshot sets and committed ROMs per the specifications.
**Fix Required:** Capture with `scripts/capture-screenshot.sh`; build with `npm run roms`.

### Gap 4: No Part 2 timing claims are recorded yet

**Current Behavior:** Part 2 is the course's timing core (frame structure, 76-cycle lines, timer
budgets, mid-scanline positioning), and none of its claims exist.
**Required Behavior:** Every timing/cycle/frame claim carries a state-log observation or a static
cycle ledger (AR-6, plan criteria 4).
**Fix Required:** Collect evidence per lesson during Session C; record it in the task notes and
findings ledger.

## Dependencies

### Internal Dependencies

- Part 1 lessons 04–11 (prerequisites and pattern); `include/vcs.asm`, `include/macro.asm`;
  both skills; the three specialists; `scripts/build-roms.sh`, `scripts/capture-screenshot.sh`,
  `scripts/verify.sh`.

### External Dependencies

- ACME 0.97, Stella 7.0 + ImageMagick, Node 20+ with VitePress 1.6.4.

## Risks and Concerns

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Incorrect timing/cycle claim in prose or code | Med | High | AR-6 evidence standard (state logs + cycle ledgers); `atari2600-reviewer` gate (AR-5) |
| Screenshot capture environment fails or captures the wrong state | Low | Med | Codified capture pitfalls in the `vcs-lesson-production` checklist; burst sampling for moving states |
| ROM drift (committed `.bin` not regenerated) | Low | Med | `npm run roms` per lesson; `verify.sh` drift check (AR-4) |
| Scope creep into later parts (sprites/playfield) | Low | Med | AR-9 forward-mention boundary; `curriculum-auditor` verifies per lesson |
| Frame/timing demos prove subtly unverifiable claims | Low | Med | Session A freezes ST expectations from the specifications (AR-2); immutable-oracle rule (plan criteria 2) |
