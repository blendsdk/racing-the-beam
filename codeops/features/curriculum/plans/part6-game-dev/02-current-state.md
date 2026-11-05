# Current State: Part 6 — Game Development (Lessons 38–47)

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

### What Exists

- **Parts 1–5 are complete (lessons 01–37).** Every lesson has an annotated `.asm` source,
  `exercise-NN-solution.asm` files, a document from the fixed template, real Stella screenshots,
  a committed 4,096-byte ROM, and a `<RomPlayer>` embed with working prev/next frontmatter.
  - Sources: `lessons/part1-6502-cpu/` (04–11), `part2-tv-and-tia/` (12–18),
    `part3-playfield/` (19–24), `part4-sprites/` (25–34), `part5-sound/` (35–37).
  - Documents: `docs/part1-6502-cpu/*.md` … `docs/part5-sound/*.md`; the Part 5 index is in the
    Part 1 format and fully ✅.
  - Artifacts: 140 committed ROMs (all exactly 4,096 bytes) under `docs/public/roms/`; screenshots
    under `docs/public/images/lesson01/` … `lesson37/`.
- **Working rails.** `scripts/verify.sh` assembles every `lessons/**/*.asm`, compares each result
  with the committed ROM, and builds the docs; `scripts/build-roms.sh` (`npm run roms`) globs the
  same tree, so new lessons need no script change; `scripts/capture-screenshot.sh` captures real
  Stella frames.
- **Proven evidence method.** Lessons 12–37 used
  `stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'` state logs with static
  cycle ledgers; Part 5 measured the frame, the effect/step timing, the HMOVE line, and the
  monitor pixels. The same method works for game logic: a checkpoint after a collision read,
  a score store, a state store, or an LFSR step reports the value in A.
- **Collision registers are already defined.** `include/vcs.asm` has `CXM0P=$00` … `CXPPMM=$07`
  and `CXCLR=$2C` (lines 121, 132–139), plus `VDELP0=$25`, `VDELP1=$26`, `SWCHB=$0282`,
  `SWCHA=$0280`, `INPT4=$0C`, `INPT5=$0D`.
- **The 48-pixel technique is proven in a scratch prototype.** The Staugas kernel (P0/P1 three
  copies close, P1 8 px right, VDEL on, 8 rows, bottom-up font) assembled to 4,096 bytes and
  rendered "123456" at capture x=367–642, y=109–131 in Stella 7.0. The plan's scoreboard spec uses
  that measured block (AR-31).
- **Pre-wired navigation.** Sidebar entries for 38–47 already exist (`docs/.vitepress/config.ts`,
  Part 6 block, lines 109–118). Lesson 37's frontmatter already links forward to Lesson 38. The
  Part 6 index is a minimal stub (`docs/part6-game-dev/index.md`) that AR-10 rebuilds to the Part 1
  format. `README.md` row 6 already says `Game Development | 38–47`.
- **Part 6 stubs.** `docs/part6-game-dev/38-collision-detection.md` … `47-dev-tools-workflow.md`
  are 19-line "Coming Soon" pages with a concept bullet list. Lesson 39's stub names
  "Building the include/score.asm library"; Lesson 43's stub names "The include/random.asm
  library" (the origins of AR-7).

### Relevant Files

| File / directory | Purpose | Changes needed |
| --- | --- | --- |
| `lessons/part6-game-dev/38…47/` | Lesson sources and exercise solutions | Create |
| `docs/part6-game-dev/38…47.md` | Lesson documents (stubs today) | Replace stubs |
| `docs/public/roms/part6-game-dev/38…47/`, `docs/public/images/lesson38/` … `lesson47/` | Committed ROMs and screenshots | Create (`npm run roms`, `capture-screenshot.sh`) |
| `docs/part6-game-dev/index.md` | Part index (minimal stub) | Rebuild to the Part 1 format; rows flip per lesson (AR-10) |
| `include/score.asm`, `include/random.asm` | Lesson 39/43 libraries | Create (AR-7, AR-15, AR-19) |
| `docs/.vitepress/config.ts` (Part 6 block) · `README.md` | Sidebar · curriculum listing | Verify only — entries already covered |
| `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md` | Tracking | Plan Preflighted; Done at completion (AR-12) |

### Code Analysis

Part 6 lessons reuse the Part 3/4/5 program shape: `!cpu 6502` with `include/vcs.asm` and
`include/macro.asm`, origin `* = $F000`, `Reset` calling `+clean_start`, the frame skeleton
(`+vsync`, `+set_timer`/`+wait_timer` with 44/36), a visible kernel, and the vectors at `$FFFA`.
Collision registers are read-only latches that stay set until `CXCLR`; reading them in VBLANK
observes the previous visible frame. `VDELP0/VDELP1` delay a graphic by one line, which is the
basis of the six-digit score trick. `SWCHB` bits 6/7 are the two difficulty switches (0 = expert,
1 = novice). `INPT4` bit 7 is active-low fire. The 8-bit Galois LFSR with taps `$1D` has a period
of 255 and locks at zero.

The visual monitors use only mechanisms already taught: playfield bands (19–24), player sprites
and `GRP0/GRP1` (25–31), the divide-by-15 positioning routine and one `HMOVE` (26–28), frame
counters (34), and the audio registers (35–37). The two-object positioning sets every coarse/fine
value first, then strobes one `HMOVE` (the Part 4 rule).

## Gaps Identified

### Gap 1: Lessons 38–47 have no sources, documents, or artifacts

**Current Behavior:** `lessons/part6-game-dev/` does not exist; the ten documents are 19-line
"Coming Soon" stubs.
**Required Behavior:** Each lesson ships its full artifact set per RD-06 AC 1 and the per-lesson
specifications ([03-lesson-specs.md](03-lesson-specs.md)).
**Fix Required:** Author sources, thirty exercise solutions, one demo, documents, screenshots, and
committed ROMs per the specifications.

### Gap 2: The Part 6 index is a minimal stub

**Current Behavior:** `docs/part6-game-dev/index.md` has no lesson table and no learning summary;
all ten sidebar links exist but the index does not list status.
**Required Behavior:** The Part 1 index format with rows 38–47; each row flips to ✅ Complete as
its lesson ships (AR-10).
**Fix Required:** Rebuild in the Lesson 38 phase; update rows per lesson commit.

### Gap 3: No score or random library and no game-logic evidence pattern

**Current Behavior:** `include/` has `macro.asm`, `sound.asm`, and `vcs.asm`; no lesson has logged
a collision, score, state, LFSR, AI, or memory-map value.
**Required Behavior:** Lesson 39 ships `include/score.asm`; Lesson 43 ships `include/random.asm`;
every lesson's Session C records the labelled checkpoint values that prove its claims.
**Fix Required:** Author the libraries (AR-15, AR-19) and add the checkpoints to each source
(AR-6, AR-28).

### Gap 4: No screenshots or committed ROMs exist for 38–47

**Current Behavior:** `docs/public/images/` ends at `lesson37`; the ROM tree ends at
`part5-sound/37-advanced-audio/`.
**Required Behavior:** Twenty screenshots (two per lesson) and forty 4,096-byte ROMs (four per
lesson; Lesson 47's main is `demo-47.asm`) committed under the Part 6 tree.
**Fix Required:** Run `npm run roms` and `capture-screenshot.sh` from the committed ROM paths.
