# Current State: Part 5 — Sound (Lessons 35–37)

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

### What Exists

- **Parts 0–4 are complete (lessons 01–34).** Every lesson has an annotated `.asm` source,
  `exercise-NN-solution.asm` files, a document from the fixed template, real Stella screenshots,
  a committed 4,096-byte ROM, and a `<RomPlayer>` embed with working prev/next frontmatter.
  - Sources: `lessons/part1-6502-cpu/` (04–11), `part2-tv-and-tia/` (12–18),
    `part3-playfield/` (19–24), `part4-sprites/` (25–34).
  - Documents: `docs/part1-6502-cpu/*.md` … `docs/part4-sprites/*.md`; the Part 4 index is in the
    Part 1 format and fully ✅.
  - Artifacts: 128 committed ROMs (all exactly 4,096 bytes) under `docs/public/roms/`; screenshots
    under `docs/public/images/lesson04/` … `lesson34/`.
- **Working rails.** `scripts/verify.sh` assembles every `lessons/**/*.asm`, compares each result
  with the committed ROM, and builds the docs; `scripts/build-roms.sh` (`npm run roms`) globs the
  same tree, so new lessons need no script change; `scripts/capture-screenshot.sh` captures real
  Stella frames.
- **Proven evidence method.** Lessons 12–34 used
  `stella -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'` state logs with static cycle ledgers;
  Part 4 measured body starts, sprite positions, and one-`HMOVE` solutions. The same method works
  for audio: a checkpoint placed after `STA AUDC0`/`AUDF0`/`AUDV0` reports the written value in A.
- **Audio registers are already defined.** `include/vcs.asm` has `AUDC0=$15`, `AUDC1=$16`,
  `AUDF0=$17`, `AUDF1=$18`, `AUDV0=$19`, `AUDV1=$1A` (lines 82–87).
- **Pre-wired navigation.** Sidebar entries for 35–37 already exist (`docs/.vitepress/config.ts`,
  Part 5 block, lines 100–102). Lesson 34's frontmatter already links forward to Lesson 35. The
  Part 5 index is a minimal stub (`docs/part5-sound/index.md`) that AR-10 rebuilds to the Part 1
  format. `README.md` row 5 already says `Sound | 35–37`.
- **Part 5 stubs.** `docs/part5-sound/35-sound-effects.md`, `36-music.md`, and
  `37-advanced-audio.md` are 19-line "Coming Soon" pages with a concept bullet list; Lesson 37's
  stub names "The include/sound.asm library" (the origin of AR-7).

### Relevant Files

| File / directory | Purpose | Changes needed |
| --- | --- | --- |
| `lessons/part5-sound/35-sound-effects/` … `37-advanced-audio/` | Lesson sources and exercise solutions | Create |
| `docs/part5-sound/35-sound-effects.md` … `37-advanced-audio.md` | Lesson documents (stubs today) | Replace stubs |
| `docs/public/roms/part5-sound/35…37/`, `docs/public/images/lesson35/` … `lesson37/` | Committed ROMs and screenshots | Create (`npm run roms`, `capture-screenshot.sh`) |
| `docs/part5-sound/index.md` | Part index (minimal stub) | Rebuild to the Part 1 format; rows flip per lesson (AR-10) |
| `include/sound.asm` | Lesson 37's sound library | Create (AR-7, AR-18) |
| `docs/.vitepress/config.ts` (Part 5 block) · `README.md` | Sidebar · curriculum listing | Verify only — entries already covered |
| `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md` | Tracking | Plan Created now; Plan Preflighted after the preflight; Done at completion (AR-12) |

### Code Analysis

Part 5 lessons reuse the Part 3/4 program shape: `!cpu 6502` with `include/vcs.asm` and
`include/macro.asm`, origin `* = $F000`, `Reset` calling `+clean_start`, the frame skeleton
(`+vsync`, `+set_timer`/`+wait_timer` with 44/36), a visible kernel, and the vectors at `$FFFA`.
The audio registers are write-only; writing them in VBLANK is safe and does not affect the beam.
The exact NTSC audio clock is **31,399.5 Hz** (3.579545 MHz / 114), so a pure tone is
`f = 31399.5 / ((AUDF + 1) × D)` with `D=2` for `AUDC` 4/5, `D=31` for 6/A, `D=6` for C/D, and
`D=93` for E. `AUDF` is 5 bits (0–31). `AUDV=0` mutes; `AUDC=0` disables the channel.

The visual monitors use only mechanisms already taught: playfield bands (19–24), player sprites
and `GRP0/GRP1` (25–31), the divide-by-15 `SetHorizPos` routine and one `HMOVE` (26–28), and
frame counters (34). The two-object positioning in Lessons 35–37 sets every coarse/fine value
first, then strobes one `HMOVE` (AR-21 of Part 4, carried here).

## Gaps Identified

### Gap 1: Lessons 35–37 have no sources, documents, or artifacts

**Current Behavior:** `lessons/part5-sound/` does not exist; the three documents are 19-line
"Coming Soon" stubs.
**Required Behavior:** Each lesson ships its full artifact set per RD-05 AC 1 and the per-lesson
specifications ([03-lesson-specs.md](03-lesson-specs.md)).
**Fix Required:** Author sources, nine exercise solutions, documents, screenshots, and committed
ROMs per the specifications.

### Gap 2: The Part 5 index is a minimal stub

**Current Behavior:** `docs/part5-sound/index.md` has no lesson table and no learning summary;
all three sidebar links exist but the index does not list status.
**Required Behavior:** The Part 1 index format with rows 35–37; each row flips to ✅ Complete as
its lesson ships (AR-10).
**Fix Required:** Rebuild in the Lesson 35 phase; update rows per lesson commit.

### Gap 3: No sound library and no audio evidence pattern

**Current Behavior:** `include/` has no sound module, and no lesson has logged an audio write.
**Required Behavior:** Lesson 37 ships `include/sound.asm` with a documented API; every lesson's
Session C records the `AUDC`/`AUDF`/`AUDV` checkpoint values that prove its claims.
**Fix Required:** Author the library (AR-18) and add the audio checkpoints to each source
(AR-6, AR-22).

### Gap 4: No screenshots or committed ROMs exist for 35–37

**Current Behavior:** `docs/public/images/` ends at `lesson34`; the ROM tree ends at
`part4-sprites/34-sprite-animation/`.
**Required Behavior:** Six screenshots (two per lesson) and twelve 4,096-byte ROMs (three main +
nine solutions) committed under the Part 5 tree.
**Fix Required:** Run `npm run roms` and `capture-screenshot.sh` from the committed ROM paths.
