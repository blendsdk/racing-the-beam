# Current State: Part 3 — Playfield (Lessons 19–24)

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

### What Exists

- **Parts 1–2 are complete (lessons 04–18).** Every lesson has an annotated `.asm` source,
  `exercise-NN-solution.asm` files, a document from the fixed template, real Stella screenshots,
  a committed 4,096-byte ROM, and a `<RomPlayer>` embed with working prev/next frontmatter.
  - Sources: `lessons/part1-6502-cpu/04-registers-and-memory/` … `11-lookup-tables/`,
    `lessons/part2-tv-and-tia/12-the-ntsc-frame/` … `18-mid-scanline-changes/`.
  - Documents: `docs/part1-6502-cpu/*.md` (12 files) and `docs/part2-tv-and-tia/*.md` (8 files).
  - Artifacts: `docs/public/roms/part1-6502-cpu/**/*.bin` and `part2-tv-and-tia/**/*.bin`
    (all exactly 4,096 bytes); `docs/public/images/lesson04/` … `lesson18/`.
- **Working rails.** `scripts/verify.sh` assembles every `lessons/**/*.asm`, compares each result
  with the committed ROM, and builds the docs; `scripts/build-roms.sh` (`npm run roms`) globs the
  same tree, so new lessons need no script change; `scripts/capture-screenshot.sh` captures real
  Stella frames. The Part 2 capture/evidence pitfalls (committed-ROM provenance, pixel
  classification, state-log straddles) are codified in the `vcs-lesson-production` checklist.
- **Proven timing-claim method.** Lessons 12–18 used
  `stella -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'` state logs with static cycle ledgers for
  runtime evidence (AR-6). Lesson 18's hit-cycle rule (a store takes effect at clock 3 × the next
  instruction's cycle) is the direct prerequisite for the playfield write windows.
- **Pre-wired navigation.** Sidebar entries for 19–24 already exist (`docs/.vitepress/config.ts`,
  Part 3 block); Lesson 18's frontmatter and closing prose already link forward to Lesson 19. The
  Part 3 index is a minimal stub (`docs/part3-playfield/index.md`) that AR-10 rebuilds to the Part 1
  format.
- **Skills and specialists.** `vcs-lesson-production` defines the per-lesson cycle and checklists;
  `atari-2600-expert` defines claim discipline with `tia-hardware.md` (playfield bit order, priority
  table) and `kernels.md` (2-line and asymmetric-playfield patterns) as the Part 3 references;
  `lesson-author`, `atari2600-reviewer`, and `curriculum-auditor` exist with routing in
  `codeops/codeops.json`.

### Relevant Files

| File / directory | Purpose | Changes needed |
| --- | --- | --- |
| `lessons/part3-playfield/19-playfield-basics/` … `24-multicolor-playfield/` | Lesson sources and exercise solutions | Create |
| `docs/part3-playfield/19-playfield-basics.md` … `24-multicolor-playfield.md` | Lesson documents (stubs today) | Replace stubs |
| `docs/public/roms/part3-playfield/19…24/`, `docs/public/images/lesson19/` … `lesson24/` | Committed ROMs and screenshots | Create (`npm run roms`, `capture-screenshot.sh`) |
| `docs/part3-playfield/index.md` | Part index (minimal stub) | Rebuild to the Part 1 format; rows flip per lesson (AR-10) |
| `docs/.vitepress/config.ts` (Part 3 block) · `README.md` | Sidebar · curriculum listing | Verify only — entries already covered |
| `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md` | Tracking | Plan Created now; Done at completion (AR-12) |

### Code Analysis

Part 3 lessons build on the Part 2 program shape: `!cpu 6502` with `include/vcs.asm` and
`include/macro.asm`, origin `* = $F000`, `Reset` calling `+clean_start`, the frame skeleton
(`+vsync`, `+set_timer` / `+wait_timer` with 44/36), a visible kernel, and the vectors at `$FFFA`.
Playfield registers are defined in `include/vcs.asm` (`PF0` `$0D`, `PF1` `$0E`, `PF2` `$0F`,
`CTRLPF` `$0A`, `COLUPF` `$08`); the bit order is the course ground truth (`PF0` bits 4–7 with bit
4 leftmost; `PF1` bit 7 leftmost; `PF2` bit 0 leftmost). Both build scripts glob the lessons tree,
so no tooling change is needed; the only automated per-lesson gate is the byte-identical ROM drift
check in `scripts/verify.sh`.

## Gaps Identified

### Gap 1: Lessons 19–24 have no sources or documents

**Current Behavior:** `lessons/part3-playfield/` does not exist; the six documents are 19-line
"Coming Soon" stubs.
**Required Behavior:** Each lesson ships its full artifact set per RD-03 AC 1 and the per-lesson
specifications ([03-lesson-specs.md](03-lesson-specs.md)).
**Fix Required:** Author sources, solutions, and documents per the specifications.

### Gap 2: The Part 3 index is a minimal stub

**Current Behavior:** `docs/part3-playfield/index.md` has no lesson table and no learning summary;
all six sidebar links exist but the index does not list status.
**Required Behavior:** The Part 1 index format with rows 19–24; each row flips to ✅ Complete as
its lesson ships (AR-10).
**Fix Required:** Rebuild in the Lesson 19 phase; update rows per lesson commit.

### Gap 3: No screenshots or committed ROMs exist for 19–24

**Current Behavior:** `docs/public/images/` ends at `lesson18`; the ROM tree ends at
`part2-tv-and-tia/18-mid-scanline-changes/`.
**Required Behavior:** Per-lesson screenshot sets and committed ROMs per the specifications.
**Fix Required:** Capture with `scripts/capture-screenshot.sh`; build with `npm run roms`.

### Gap 4: No playfield timing or geometry claims are recorded yet

**Current Behavior:** Part 3's core claim — that mid-line `PF` writes can give the right half
different data — has not been exercised in this course; only the general write-position rule from
Lesson 18 exists.
**Required Behavior:** Every playfield write window carries a state-log observation plus a static
cycle ledger (AR-6, AR-13); Lesson 21's windows are measured before that lesson is done.
**Fix Required:** Collect evidence per lesson during Session C; record it in the task notes and
findings ledger.

## Dependencies

### Internal Dependencies

- Part 2 lessons 12–18 (frame, timing, cycle counting, write-position rule);
  `include/vcs.asm`, `include/macro.asm`; both skills; the three specialists;
  `scripts/build-roms.sh`, `scripts/capture-screenshot.sh`, `scripts/verify.sh`.

### External Dependencies

- ACME 0.97, Stella 7.0 + ImageMagick, Node 20+ with VitePress 1.6.4.

## Risks and Concerns

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Incorrect playfield bit order or write-window claim | Med | High | AR-6/AR-13 evidence standard; `atari2600-reviewer` gate; L21 measured before done |
| Asymmetric kernel overruns HBLANK and tears the left half | Med | High | Pinned cycle ledger with margins; state-log checkpoints per write; pixel check |
| Screenshot captures the wrong animation/level state | Med | Med | Committed-ROM provenance; pixel classification; timed waits/bursts for moving states |
| ROM drift | Low | Med | `npm run roms` per lesson; `verify.sh` drift check |
| Scope creep into sprites (Part 4) | Low | Med | AR-9/AR-14 boundaries; auditor verifies per lesson |
| Data tables too large or misaligned | Low | Med | 2-line kernel (AR-15); table sizes checked in Session B; ROM size asserted |
