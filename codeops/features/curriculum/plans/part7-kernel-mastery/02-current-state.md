# Current State: Part 7 — Kernel Mastery (Lessons 48–55)

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

### What Exists

- **Parts 0–6 are complete (lessons 01–47).** Every lesson has an annotated `.asm` source,
  `exercise-NN-solution.asm` files, a document from the fixed template, real Stella screenshots,
  a committed 4,096-byte ROM, and a `<RomPlayer>` embed with working prev/next frontmatter.
  - Sources: `lessons/part1-6502-cpu/` (04–11), `part2-tv-and-tia/` (12–18),
    `part3-playfield/` (19–24), `part4-sprites/` (25–34), `part5-sound/` (35–37),
    `part6-game-dev/` (38–47).
  - Documents: `docs/part1-6502-cpu/*.md` … `docs/part6-game-dev/*.md`; the Part 6 index is in the
    Part 1 format and fully ✅.
  - Artifacts: **180 committed ROMs** (all exactly 4,096 bytes) under `docs/public/roms/`;
    screenshots under `docs/public/images/lesson01/` … `lesson47/`.
- **Working rails.** `scripts/verify.sh` assembles every `lessons/**/*.asm`, compares each result
  with the committed ROM, and builds the docs; `scripts/build-roms.sh` (`npm run roms`) globs the
  same tree, so new lessons need no script change; `scripts/capture-screenshot.sh` captures real
  Stella frames.
- **Proven evidence method.** Lessons 12–47 used
  `stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'` state logs with static
  cycle ledgers; Part 6 measured the frame, the kernel stores, the HMOVE line, and the monitor
  pixels. The same method works for kernels: a breakpoint at the first row, the scroll store, the
  flicker parity, or the text fill reports the value in A and the scanline.
- **The 48-pixel kernel is already shipped.** `include/score.asm` (Lesson 39) has a proven
  Staugas kernel: `ScoreSetup` (P0/P1 three-copy close, VDEL, one HMOVE), `ScoreDraw` (8 rows,
  9 visible lines), `ScoreBuf` (48 bytes, column-major, bottom-up), and `ScoreSetDigit` /
  `ScoreAddOne`. Lessons 50 and 55 can reuse it without changing it.
- **The collision, sound, and game-state machinery is already shipped.** `include/vcs.asm` has
  the TIA/RIOT registers (including `VDELP0/1`, `SWCHB`, `INPT4`, `CXCLR`), and the Part 6
  lessons supply the 2-line, 1-line, and state patterns that Part 7 builds on.
- **Pre-wired navigation.** Sidebar entries for 48–55 already exist (`docs/.vitepress/config.ts`,
  Part 7 block, lines 125–132). Lesson 47's frontmatter already links forward to Lesson 48;
  Lesson 55's next will link to `/part8-advanced/56-bankswitching`, whose stub exists. The Part 7
  index is a minimal stub (`docs/part7-kernel-mastery/index.md`) that AR-10 rebuilds to the Part 1
  format. `README.md` row 7 already says `Kernel Mastery | 48–55`.
- **Part 7 stubs.** `docs/part7-kernel-mastery/48-introduction-to-kernels.md` …
  `55-scrolling-text-marquee.md` are 19-line "Coming Soon" pages with a concept bullet list.
  Lesson 53's stub names "The include/kernel_patterns.asm library" (the origin of AR-7).

### Relevant Files

| File / directory | Purpose | Changes needed |
| --- | --- | --- |
| `lessons/part7-kernel-mastery/48…55/` | Lesson sources and exercise solutions | Create |
| `docs/part7-kernel-mastery/48…55.md` | Lesson documents (stubs today) | Replace stubs |
| `docs/public/roms/part7-kernel-mastery/48…55/`, `docs/public/images/lesson48/` … `lesson55/` | Committed ROMs and screenshots | Create (`npm run roms`, `capture-screenshot.sh`) |
| `docs/part7-kernel-mastery/index.md` | Part index (minimal stub) | Rebuild to the Part 1 format; rows flip per lesson (AR-10) |
| `include/kernel_patterns.asm` | Lesson 53 library | Create (AR-7, AR-28) |
| `docs/.vitepress/config.ts` (Part 7 block) · `README.md` | Sidebar · curriculum listing | Verify only — entries already covered |
| `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md` | Tracking | Complete; RD-07 Done (AR-12) |

### Code Analysis

Part 7 lessons reuse the Part 1–6 program shape: `!cpu 6502` with `include/vcs.asm` and
`include/macro.asm`, origin `* = $F000`, `Reset` calling `+clean_start`, the frame skeleton
(`+vsync`, `+set_timer`/`+wait_timer` with 44/36), a visible kernel, and the vectors at `$FFFA`.
The 1-line kernel writes one byte per scanline; the 2-line kernel writes one byte per two
scanlines (96 rows for 192 lines); the multi-zone kernel divides the picture into fixed bands with
their own loops. `WSYNC` anchors each line; a 1-line kernel has ~76 cycles, a 2-line kernel ~152.
`HMOVE` applies all five motion registers in HBLANK; an HMOVE in HBLANK blanks the leftmost 8
pixels of the following line, which matters at a zone boundary. `VDELP0/1` stages a graphic and
commits it on the other player's write (the 48-pixel kernel's cross-latch). The playfield is 4-px
per bit; players/missiles/ball are 1-px objects; that split is the core of Lesson 52.

The visual monitors use only mechanisms already taught: playfield bands (19–24), player sprites
and `GRP0/GRP1` (25–31), the divide-by-15 positioning routine and one `HMOVE` (26–28), frame
counters (34), and the score library (39). The new Part 7 machinery is the kernel-pattern library
(53) and the scroll/flicker/text data structures.

## Gaps Identified

### Gap 1: Lessons 48–55 have no sources, documents, or artifacts

**Current Behavior:** `lessons/part7-kernel-mastery/` does not exist; the eight documents are
19-line "Coming Soon" stubs.
**Required Behavior:** Each lesson ships its full artifact set per RD-07 AC 1 and the per-lesson
specifications ([03-lesson-specs.md](03-lesson-specs.md)).
**Fix Required:** Author sources, twenty-four exercise solutions, one demo, documents, screenshots,
and committed ROMs per the specifications.

### Gap 2: The Part 7 index is a minimal stub

**Current Behavior:** `docs/part7-kernel-mastery/index.md` has no lesson table and no learning
summary; all eight sidebar links exist but the index does not list status.
**Required Behavior:** The Part 1 index format with rows 48–55; each row flips to ✅ Complete as
its lesson ships (AR-10).
**Fix Required:** Rebuild in the Lesson 48 phase; update rows per lesson commit.

### Gap 3: No kernel-pattern library and no kernel-level evidence pattern

**Current Behavior:** `include/` has `macro.asm`, `score.asm`, `random.asm`, `sound.asm`, and
`vcs.asm`; no lesson has logged a kernel row store, a flicker parity, a scroll step, or a text
fill as its primary evidence.
**Required Behavior:** Lesson 53 ships `include/kernel_patterns.asm`; every lesson's Session C
records the labelled checkpoint values that prove its kernel and line claims.
**Fix Required:** Author the library (AR-28) and add the checkpoints to each source (AR-6).

### Gap 4: No screenshots or committed ROMs exist for 48–55

**Current Behavior:** `docs/public/images/` ends at `lesson47`; the ROM tree ends at
`part6-game-dev/47-dev-tools-workflow/`.
**Required Behavior:** Sixteen screenshots (two per lesson) and thirty-two 4,096-byte ROMs (four
per lesson; Lesson 48's main is `demo-48.asm`) committed under the Part 7 tree.
**Fix Required:** Run `npm run roms` and `capture-screenshot.sh` from the committed ROM paths.
