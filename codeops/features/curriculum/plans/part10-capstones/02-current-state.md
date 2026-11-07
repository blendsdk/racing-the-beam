# Current State: Part 10 — Capstone Projects (Lessons 69–72)

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

### What Exists

Part 9 is complete at `b98bd62` (`docs(curriculum): complete Part 9 (lessons 66-68)`):
**252** committed ACME ROMs plus the bB reference (253 total `.bin`), 9 Part 9 sources, 3 Part 9
documents, 10 Part 9 screenshots, `verify.sh` green, and RD-09 Done (feature roadmap 9/11,
portfolio 9 plans done). The Part 10 structure exists as four docs stubs and an intro-only part
index; the sidebar has entries for 69–72 at `config.ts:164–167`; README row 10 says
`Capstone Projects | 69–72`.

The course libraries are `include/vcs.asm` (TIA/RIOT ground truth), `include/macro.asm`
(`+clean_start`, `+vsync`, `+set_timer`, `+wait_timer`), `include/score.asm` (the six-digit score,
nine visible lines, `$A0-$D7`), `include/sound.asm` (two channels, `SoundTable`), `include/random.asm`
(the LFSR), and `include/kernel_patterns.asm` / `include/kernel_framework.asm` (the Part 7/9 band
libraries). There is **no** game engine or shared row-table library.

The lesson pipeline is proven: `lessons/<part>/<NN-slug>/<NN-slug>.asm` + solutions or
`demo-NN.asm`, `npm run roms` builds every `.asm` with ACME into
`docs/public/roms/<part>/<NN-slug>/`, `verify.sh` checks drift, `scripts/capture-screenshot.sh`
captures Stella windows, and the Part 7–9 three-session review process shipped 29 lessons with
0 critical/major open.

The preflight prototyped the Part 10 kernels in scratch:
- The 262-line frame with the score library and the repositioning sequence measured 259/37/229.
- The one-line multi-object kernel failed at cycle 49 (P0 invisible); the row-table two-line
  kernel measured 259/37/229 with three objects.
- The forced-object test confirmed the positioners and colors for P0/P1/ball.
- The 4-line alternative was rejected because its compute still spilled.

### Relevant Files

| File | Purpose | Changes Needed |
| ---- | ------- | -------------- |
| `docs/part10-capstones/index.md` | Part 10 index (intro only) | Rebuild to the Part 7/8/9 format in Lesson 69 |
| `docs/part10-capstones/69-pong.md` | Lesson 69 stub | Replace with the full lesson |
| `docs/part10-capstones/70-breakout.md` | Lesson 70 stub | Replace with the full lesson |
| `docs/part10-capstones/71-maze-explorer.md` | Lesson 71 stub | Replace with the full lesson |
| `docs/part10-capstones/72-your-game.md` | Lesson 72 stub | Replace with the full lesson |
| `docs/.vitepress/config.ts` | Sidebar | Verify lines 164–167; no change expected |
| `README.md` | Curriculum listing | Row 10 unchanged |
| `include/score.asm` | Score library | Source of the score; no changes |
| `include/sound.asm` | Sound library | Source of the sound; no changes |
| `lessons/part10-capstones/` | New lesson sources | Create four lessons |
| `docs/public/roms/part10-capstones/` | New committed ROMs | 13 ACME ROMs |
| `docs/public/images/lesson69..72/` | New captures | 11 images |
| `codeops/features/curriculum/00-roadmap.md` | Feature roadmap | RD-10 Executing → Done |
| `codeops/00-roadmap.md` | Portfolio | 10 plans done at the gate |

### Code Analysis

The score library's `ScoreSetup` positions P0 at 56 and P1 at 64 and sets three-copy/VDEL mode;
`ScoreDraw` consumes nine visible lines and leaves VDEL off. A game that reuses P0/P1 must call
`ScoreSetup` every frame before `ScoreDraw` and reposition the players after it. The preflight
measured this sequence: `ScoreDone` at line 46, `OverscanStart` at 229.

The Lesson 49 two-line kernel's body is 62 cycles; the preflight's row-table body is ~45 cycles
(read one byte, decode three bits, store three objects, two `WSYNC`s). The table is built in
VBLANK: clear the rows, then OR the object bit into each row of the object's range. The Pong table
is 89 bytes; the Breakout play table is 32 bytes; the Maze table is 44 bytes.

The positioners are the Lesson 26/28/29 divide-by-15 routines. The one-HMOVE rule applies: set
all `HMPx`/`RESxx` first, then one `HMOVE`. The games re-strobe the coarse positions every frame
because `HMOVE` re-applies the fine offsets.

## Gaps Identified

### Gap 1: No Part 10 lesson sources or documents
**Current Behavior:** The four docs are `🔒 Coming Soon` stubs; there are no `.asm` sources, no
ROMs, and no screenshots.
**Required Behavior:** Four complete lessons with the full artifact set.
**Fix Required:** Implement Lessons 69–72 in four phases.

### Gap 2: No complete game implementations
**Current Behavior:** The course has individual techniques and kernels but no end-to-end game.
**Required Behavior:** Pong, Breakout, Maze Explorer, and the skeleton mini-game.
**Fix Required:** Lessons 69–72.

### Gap 3: No maze generator or include
**Current Behavior:** No maze data, generator, or spec exists.
**Required Behavior:** A Python generator, a spec, a committed `maze-data.inc`, and a playable
mirror maze.
**Fix Required:** Lesson 71.

### Gap 4: No production templates
**Current Behavior:** The course has no GDD, RAM-map, screen-map, or milestone template.
**Required Behavior:** The Lesson 72 templates and the skeleton demo.
**Fix Required:** Lesson 72.

## Dependencies

### Internal Dependencies
- RD-09 complete (lessons 66–68; no forward references).
- `include/vcs.asm`, `include/macro.asm`, `include/score.asm`, `include/sound.asm`,
  `include/random.asm`.
- The Part 4 sprite/positioning vocabulary (Lessons 25–33), the Part 6 game-development
  vocabulary (Lessons 38–47), and the Part 7 kernel vocabulary (Lessons 48–55).

### External Dependencies
- ACME 0.97, Stella 7.0, Python 3, ImageMagick/`import`, `xwininfo`.

## Risks and Concerns

| Risk | Likelihood | Impact | Mitigation |
| ---- | ---------- | ------ | ---------- |
| Kernel budget overrun | Medium | High | Row tables + measured ledgers; every source assembled and run before capture |
| Score/player conflict | Medium | High | ScoreSetup every frame + reposition; Pong uses a custom score |
| RAM collision | Medium | High | Per-lesson maps; the source header is the exact map |
| Brick collision math | Medium | High | Pinned column formula; a capture/log shows a brick cleared |
| Generator drift | Medium | High | `--check` before commit; the include is committed |
| 4K overflow | Medium | Medium | Compact tables; assemble before capture; size pins |
| Moving-state screenshot | Medium | Medium | Deterministic auto-demos; disclosed waits |
