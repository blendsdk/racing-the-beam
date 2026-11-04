# Current State: Part 4 — Sprites (Lessons 25–34)

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

### What Exists

- **Parts 1–3 are complete (lessons 04–24).** Every lesson has an annotated `.asm` source,
  `exercise-NN-solution.asm` files, a document from the fixed template, real Stella screenshots,
  a committed 4,096-byte ROM, and a `<RomPlayer>` embed with working prev/next frontmatter.
  - Sources: `lessons/part1-6502-cpu/` (04–11), `lessons/part2-tv-and-tia/` (12–18),
    `lessons/part3-playfield/` (19–24).
  - Documents: `docs/part1-6502-cpu/*.md`, `docs/part2-tv-and-tia/*.md`,
    `docs/part3-playfield/*.md` (Part 3 index rebuilt to the Part 1 format).
  - Artifacts: committed ROMs under `docs/public/roms/part1-6502-cpu/`, `part2-tv-and-tia/`,
    `part3-playfield/` (all exactly 4,096 bytes); screenshots under
    `docs/public/images/lesson04/` … `lesson24/`.
- **Working rails.** `scripts/verify.sh` assembles every `lessons/**/*.asm`, compares each result
  with the committed ROM, and builds the docs; `scripts/build-roms.sh` (`npm run roms`) globs the
  same tree, so new lessons need no script change; `scripts/capture-screenshot.sh` captures real
  Stella frames.
- **Proven evidence method.** Lessons 12–24 used
  `stella -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'` state logs with static cycle ledgers;
  Lesson 21 measured six mid-line write cycles exactly (10/15/20/35/46/57), and Lesson 24 measured
  the per-line color write (cycle 13, or 14 on a page-crossing line).
- **Pre-wired navigation.** Sidebar entries for 25–34 already exist (`docs/.vitepress/config.ts`,
  Part 4 block). Lesson 24's frontmatter already links forward to Lesson 25. The Part 4 index is a
  minimal stub (`docs/part4-sprites/index.md`) that AR-10 rebuilds to the Part 1 format.
- **Skills and specialists.** `vcs-lesson-production` defines the per-lesson cycle and checklists;
  `atari-2600-expert` defines claim discipline with `tia-hardware.md` (sprite registers, NUSIZ,
  VDEL, priority, RIOT inputs) and `sprite-tricks.md` (SetHorizPos, multicolor, VDEL, missiles)
  as the Part 4 references; `lesson-author`, `atari2600-reviewer`, and `curriculum-auditor` exist
  with routing in `codeops/codeops.json`.

### Relevant Files

| File / directory | Purpose | Changes needed |
| --- | --- | --- |
| `lessons/part4-sprites/25-player-basics/` … `34-sprite-animation/` | Lesson sources and exercise solutions | Create |
| `docs/part4-sprites/25-player-basics.md` … `34-sprite-animation.md` | Lesson documents (stubs today) | Replace stubs |
| `docs/public/roms/part4-sprites/25…34/`, `docs/public/images/lesson25/` … `lesson34/` | Committed ROMs and screenshots | Create (`npm run roms`, `capture-screenshot.sh`) |
| `docs/part4-sprites/index.md` | Part index (minimal stub) | Rebuild to the Part 1 format; rows flip per lesson (AR-10) |
| `docs/.vitepress/config.ts` (Part 4 block) · `README.md` | Sidebar · curriculum listing | Verify only — entries already covered |
| `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md` | Tracking | Plan Created now; Done at completion (AR-12) |

### Code Analysis

Part 4 lessons build on the Part 3 program shape: `!cpu 6502` with `include/vcs.asm` and
`include/macro.asm`, origin `* = $F000`, `Reset` calling `+clean_start`, the frame skeleton
(`+vsync`, `+set_timer`/`+wait_timer` with 44/36), a visible kernel, and the vectors at `$FFFA`.
Sprite registers are defined in `include/vcs.asm` (`GRP0` `$1B`, `GRP1` `$1C`, `RESP0` `$10`,
`RESP1` `$11`, `RESM0` `$12`, `RESM1` `$13`, `RESBL` `$14`, `HMP0` `$20`, `NUSIZ0` `$04`,
`VDELP0` `$25`, `HMOVE` `$2A`, `SWCHA` `$0280`, `INPT4` `$0C`). Both build scripts glob the
lessons tree, so no tooling change is needed; the only automated per-lesson gate is the
byte-identical ROM drift check in `scripts/verify.sh`.

## Gaps Identified

### Gap 1: Lessons 25–34 have no sources or documents

**Current Behavior:** `lessons/part4-sprites/` does not exist; the ten documents are 19-line
"Coming Soon" stubs.
**Required Behavior:** Each lesson ships its full artifact set per RD-04 AC 1 and the per-lesson
specifications ([03-lesson-specs.md](03-lesson-specs.md)).
**Fix Required:** Author sources, solutions, and documents per the specifications.

### Gap 2: The Part 4 index is a minimal stub

**Current Behavior:** `docs/part4-sprites/index.md` has no lesson table and no learning summary;
all ten sidebar links exist but the index does not list status.
**Required Behavior:** The Part 1 index format with rows 25–34; each row flips to ✅ Complete as
its lesson ships (AR-10).
**Fix Required:** Rebuild in the Lesson 25 phase; update rows per lesson commit.

### Gap 3: No screenshots or committed ROMs exist for 25–34

**Current Behavior:** `docs/public/images/` ends at `lesson24`; the ROM tree ends at
`part3-playfield/24-multicolor-playfield/`.
**Required Behavior:** Per-lesson screenshot sets and committed ROMs per the specifications.
**Fix Required:** Capture with `scripts/capture-screenshot.sh`; build with `npm run roms`.

### Gap 4: No sprite positioning or input claims are recorded yet

**Current Behavior:** Part 4's core claim — that the divide-by-15 routine lands a player at the
requested X, and that missiles/ball differ by one output clock — has not been exercised in this
course; only playfield geometry (Part 3) and the general write-position rule (Lesson 18) exist.
**Required Behavior:** Every positioning claim carries a state-log observation plus a static cycle
ledger (AR-6, AR-13); the measured X is pinned per lesson before that lesson is done.
**Fix Required:** Collect evidence per lesson during Session C; record it in the task notes and
findings ledger.

## Dependencies

### Internal Dependencies

- Part 3 lessons 19–24 (playfield, per-line writes, table pointers, color writes);
  `include/vcs.asm`, `include/macro.asm`; both skills; the three specialists;
  `scripts/build-roms.sh`, `scripts/capture-screenshot.sh`, `scripts/verify.sh`.

### External Dependencies

- ACME 0.97, Stella 7.0 + ImageMagick, Node 20+ with VitePress 1.6.4.

## Risks and Concerns

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Incorrect sprite positioning or output-delay claim | Med | High | AR-6/AR-13 evidence standard; `atari2600-reviewer` gate; measured X per lesson before done |
| Sprite write lands after the beam has passed its pixels | Med | High | Body writes at cycles 5–12, sprites placed at X ≥ 24; ledger per kernel; pixel check |
| Capture catches the wrong animation/NUSIZ band | Med | Med | Committed-ROM provenance; timed waits; pixel classification; state-log frame pin |
| ROM drift | Low | Med | `npm run roms` per lesson; `verify.sh` drift check |
| Scope creep into later parts (flicker, 48-pixel trick, games) | Low | Med | AR-9/AR-18 boundaries; auditor verifies per lesson |
| Paddle read hangs without a controller | Low | High | Bounded 256-iteration timeout (AR-19); verify on the committed ROM |
| Data tables too large or misaligned | Low | Med | 4K size asserted; tables checked in Session B |
