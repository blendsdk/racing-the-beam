# Current State: Part 8 — Advanced Topics (Lessons 56–65)

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

### What Exists

- **Parts 0–7 are complete (lessons 01–55).** Every lesson has an annotated `.asm` source,
  `exercise-NN-solution.asm` files (or the promised demo), a document from the fixed template,
  real Stella screenshots, a committed ROM, and a `<RomPlayer>` embed with working prev/next
  frontmatter.
  - Sources: `lessons/part1-6502-cpu/` … `part7-kernel-mastery/`; 32 Part 7 sources.
  - Documents: `docs/part1-6502-cpu/*.md` … `docs/part7-kernel-mastery/*.md`.
  - Artifacts: **212 committed ROMs** under `docs/public/roms/`; Part 7's 32 are 4,096 bytes.
- **Working rails.** `scripts/verify.sh` assembles every `lessons/**/*.asm`, compares each result
  with the committed ROM, and builds the docs; `scripts/build-roms.sh` (`npm run roms`) globs the
  same tree, so new lessons and new ROM sizes need no script change;
  `scripts/capture-screenshot.sh` captures real Stella frames from any committed ROM.
- **Proven evidence method.** Lessons 12–55 used
  `stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'` state logs with static
  cycle ledgers; Part 7 measured the frame, kernel stores, HMOVE lines, scroll steps, flicker
  parity, and text fills. The same method works for bank entries, RAM windows, patched operands,
  and DPC fetches.
- **Shipped libraries.** `include/vcs.asm` is the register ground truth; `include/macro.asm`
  supplies `+clean_start`, `+vsync`, `+set_timer`, `+wait_timer`; `include/score.asm` supplies the
  48-pixel score kernel; `include/kernel_patterns.asm` supplies the four Part 7 patterns. Part 8
  reuses them where appropriate and adds no new shared library (AR-28).
- **Pre-wired navigation.** Sidebar entries for 56–65 already exist
  (`docs/.vitepress/config.ts`, lines 139–148). Lesson 55's frontmatter links to
  `/part8-advanced/56-bankswitching`. The Part 8 index is a minimal stub
  (`docs/part8-advanced/index.md`) that the Lesson 56 phase rebuilds to the Part 1 format.
  `README.md` row 8 already says `Advanced Topics | 56–65`.
- **Part 8 stubs.** `docs/part8-advanced/56-bankswitching.md` … `65-pal-ntsc-universal.md` are
  19-line "Coming Soon" pages with a concept bullet list. Several stubs contain claims that the
  preflight corrects: Lesson 65's "runtime TV system detection" is impossible on stock hardware
  (PF-09); Lesson 60's DPC+ is not buildable on a plain cart (PF-08); the stubs assume 4K ROMs.

### Relevant Files

| File / directory | Purpose | Changes needed |
| --- | --- | --- |
| `lessons/part8-advanced/56…65/` | Lesson sources, exercise solutions, demos | Create |
| `docs/part8-advanced/56…65.md` | Lesson documents (stubs today) | Replace stubs |
| `docs/public/roms/part8-advanced/56…65/`, `docs/public/images/lesson56/` … `lesson65/` | Committed ROMs and screenshots | Create (`npm run roms`, `capture-screenshot.sh`) |
| `docs/part8-advanced/index.md` | Part index (minimal stub) | Rebuild to the Part 1 format; rows flip per lesson (AR-25) |
| `docs/.vitepress/config.ts` (Part 8 block) · `README.md` | Sidebar · curriculum listing | Verify only — entries already covered |
| `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md` | Tracking | RD-08 Done at completion (AR-27) |

### Code Analysis

Part 8 lessons reuse the Part 1–7 program shape: `!cpu 6502` with `include/vcs.asm` and
`include/macro.asm`, a reset entry that calls `+clean_start` or does the equivalent init, the
262-line frame skeleton, `+set_timer`/`+wait_timer` in VBLANK, a visible kernel with `WSYNC`,
and the 30-line overscan. The differences are the mapper and the subject:

- **F8/F8SC:** the source is assembled as two 4K windows. Bank 0 occupies real `$E000` with
  `!pseudopc $F000`; bank 1 occupies real `$F000`. The flat output is bank 0 then bank 1, so the
  8K file matches the F8 image. The start bank is 1; bank 1's reset vector is used. F8SC adds the
  duplicated 128-byte signature at the start of each bank and moves code to `$F100`.
- **F6:** four 4K windows at `$C000`, `$D000`, `$E000`, `$F000`; the start bank is 0; the flat
  output is 16K. The exercises use this for four scenes.
- **DPC:** two 4K program windows plus a 2K display segment at real `$E000`; the flat output is
  10,240 bytes. The start bank is 1; code starts at `$F080` because `$F000–$F07F` is the DPC
  register window; the display data is at file offset 8K.
- **4K lessons:** the familiar `* = $F000` layout.

ACME's plain output writes segments in address order, so the source layouts above produce the
correct flat image without a post-build step. This was verified with the preflight prototypes
(PF-03, PF-05, PF-07).

### Testing Gaps and Risks

- `verify.sh` does not know a ROM's mapper; it compares bytes. The mapper correctness is proved
  by Stella's detection log (`F8*`, `F8SC*`, `F6*`, `DPC*`) and by the visual/state evidence.
- The in-browser player (Javatari) supports F8/F6/F4 with +RAM and DPC; the lesson documents must
  not claim support for a mapper outside that set. Part 8 stays inside it (AR-29).
- The Part 8 stubs' "Coming Soon" marker must flip exactly once per lesson; the index is the
  reader-facing progress surface.

## Final State (2026-11-07)

Part 8 is complete. The ten lessons ship **31 sources/ROMs** (F8 8K, F8SC 8K, F6 16K, DPC 10K,
and 4K), **10 documents**, and **21 Stella screenshots** (Lesson 62 ships three). `npm run roms`
builds **243** ROMs, and `bash scripts/verify.sh` passes with no drift and a successful VitePress
build. The Part 8 index rows 56–65 are all ✅; the sidebar, prev/next links, and README row 8 are
unchanged. RD-08 is Done, the feature roadmap is 8/11, and the portfolio records 8 plans done.

The preflight's mapper and platform facts held: F8/F8SC/DPC start in bank 1 and F6 in bank 0; the
F8SC signature and `$F100` code start are required; DPC is 10,240 bytes with entry `$F080`; a stock
2600 cannot auto-detect PAL/NTSC. The per-lesson review gate caught the remaining implementation
and documentation defects before each commit; the fixes are recorded in `05-findings.md`.
