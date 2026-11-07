# Lesson Specifications: Part 9 — The DSL Path (Lessons 66–68)

> **Document**: 03-lesson-specs.md
> **Parent**: [Index](00-index.md)
> **Status**: Frozen for execution
> **Source of truth**: this file + [07-testing-strategy.md](07-testing-strategy.md) + the shipped
> `include/vcs.asm`, `include/macro.asm`, `include/score.asm`, and `include/kernel_patterns.asm`.
> A claim that disagrees with `include/vcs.asm` is wrong.

## Shared Conventions

- **Source shape:** `!cpu 6502`; `!source "include/vcs.asm"`; `!source "include/macro.asm"`;
  the reset entry; `+clean_start`; the 262-line frame skeleton; the visible kernel; the overscan.
  The main source's header comment carries the RAM map, the build command, the run command, the
  checkpoints, and the measured cycle/line ledgers.
- **ROM names and paths:** `lessons/part9-dsl-path/NN-slug/NN-slug.asm`,
  `exercise-NN-solution.asm` (buildable) or `demo-NN.asm` (theory); committed under
  `docs/public/roms/part9-dsl-path/NN-slug/`.
- **ROM size:** **4,096 bytes for every Part 9 source.** No mapper, no bankswitching, no
  Superchip, no DPC. The bB reference ROM is also 4,096.
- **Frame:** NTSC 262 = 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan. `StartFrame` 259/3,
  `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229 (the cycle is layout-dependent; the
  scanline is the invariant). The visible kernel is 192 lines.
- **Row loops:** top-down `LDY #0; ...; INY; CPY #N; BNE`; no sentinels.
- **RAM map:** Lessons 66/67: `$80–$9F` lesson variables, `$A0–$D7` the score library,
  `$D8–$F7` free, `$F8–$FF` stack. Lesson 68: the framework owns `$80–$82` (`KernelPtr`,
  `KernelRows`); the lesson variables start at `$83`. No lesson uses the stack page for data.
- **Checkpoints:** `Label:` immediately before the instruction that follows the labelled event; a
  breakpoint reports the first cycle of that instruction. The source header lists every checkpoint
  and its expected value; the doc's table quotes the address from the symbol file.
- **Screenshots:** from the committed lesson ROM via `scripts/capture-screenshot.sh`, pointer
  parked, no cursor, title bar visible. Lesson 66: 3 demo captures + 1 bB reference; Lesson 67: 2;
  Lesson 68: 3. A still proves the visual state; the state log proves the transition/clock. Pixel
  checks use PIL and record the geometry.
- **Exercises:** Lesson 66 has three analysis exercises answered in the doc (theory lesson, no
  solution files). Lessons 67–68 ship three `exercise-NN-solution.asm`, each assembling to 4,096
  and running in Stella.
- **Docs:** the fixed six-section template with frontmatter, meta block, TypeScript equivalent,
  theory, Full Source verbatim between the markers, Code Walkthrough, What You Should See with the
  images and `<RomPlayer>`, Exercises, Key Takeaways (≤7), What's Next. The capture method and any
  deviation are disclosed.
- **Integration:** the Part 9 index row flips to ✅ in the lesson commit; sidebar entry verified;
  prev/next frontmatter; README row 9 unchanged.

---

## Lesson 66: Analyzing batari BASIC — How bB Works

- **Goal:** read a real batari BASIC 1.9 compilation and map every generated construct back to the
  6502/TIA concepts from Parts 1–8; understand what a high-level 2600 tool must generate and where
  manual control takes over.
- **Prerequisites:** Lesson 03 (the anatomy), Lesson 04 (registers and memory), Lesson 12 (the
  frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25
  (players), Lesson 26 (positioning), Lesson 39 (the score kernel), Lesson 48 (the taxonomy),
  Lesson 55 (text), Lesson 62 (reverse engineering), Lesson 63 (the score library).
- **Concepts:** the bB four-stage pipeline (preprocess → compile → link → assemble); the `.bas` →
  `bB.asm` → linked `.asm` → `.bin` artifacts; the generated `start` (RAM check `$D0/$D1`, clear
  memory, kernel); `drawscreen`; the 2-line kernel; the `vblank_bB_code` hook; the overscan; the
  lowering of assignment, `if`, arithmetic, BCD score, `drawscreen`, and `goto`; the fixed
  zero-page variable map; bB's strengths (fast iteration, readable output) and limits (fixed
  kernel shapes, per-statement cost, the 4K/8K/16K/32K choices); when to drop to assembly.
- **ROM:** `demo-66.asm` — **"the bB anatomy viewer"**, 4,096 bytes. A theory lesson whose demo
  visualizes the bB architecture in three SELECT lenses:
  - **Lens 0 — RUN:** a 16-line score/header band + a 176-line picture. A starfield playfield, a green
    player 0 "ship" that moves left/right (or auto-pans), a gold player 1 "enemy", and a white
    ball. The lens mirrors the bB sample's objects and shows the same kind of picture the bB
    reference ROM draws.
  - **Lens 1 — ZONES:** the frame map. The 192 visible lines are a teaching projection of
    VSYNC (3), VBLANK (37), kernel (192), and overscan (30): four background bands and a row bar
    that steps across them. There are no on-screen labels; the lesson's table names the phases.
    The doc states plainly that the blanked
    phases are invisible on a TV and that the map compresses the true line counts.
  - **Lens 2 — VARS:** a 16×8 grid of 128 cells, one per RIOT RAM byte `$80–$FF`. The grid marks
    the bB system variables, the `dim` aliases, the 3-byte score, the temporary bytes, the stack,
    and the free bytes with distinct patterns; a ball highlights the selected byte; the score
    window shows the address and the owner. The doc maps each group to the generated bB listing.
  - SELECT cycles the lenses; the state log proves `Lens` A=0/1/2. The demo's frame is 262 lines;
    `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6.
- **bB reference artifacts (committed, clearly separated from the demo):**
  - `lesson66.bas` — a course-authored bB 1.9 program: `set romsize 4k`, `set kernel_options
    no_blank_lines`, an 11-row playfield (bB 1.9's default), two 6-row players, a ball, positions, a main loop that
    moves `player0y`, an `if` that wraps it, `score = score + 1`, `drawscreen`, and `goto`.
  - `lesson66.bas.list.txt`, `lesson66.bas.symbol.txt`, and `2600basic_variable_redefs.h` — the
    compiler's CC0 address listing, symbol table, and variable-redefs header, committed so the
    doc's addresses and the exercises are reproducible without installing bB.
  - `lesson66.generated.txt` — the linked bB 1.9 generated assembly (CC0), with a header naming
    the bB/wasmtime versions and the compile command. The doc quotes it with line numbers.
  - `lesson66-bb.bin` — the 4,096-byte bB reference ROM, committed under
    `docs/public/roms/part9-dsl-path/66-analyzing-batari-basic/` for a second `<RomPlayer>`. It is
    not built by `npm run roms`; the doc says so and gives the bB command.
- **RAM (demo):** `$80` `Lens`, `$81` `Frame`, `$82` `ShipX`, `$83` `ShipDir`, `$85` `MapIndex`,
  `$86` `PrevSelect`, `$87` `NewSelect`, `$89` `BallX`, `$8B` `TmpA`, `$8C` `GridRow`, `$8D`
  `ScreenY`, `$8E` `BarIdx`, `$8F` `LineCount`, `$90` `SelectedRow`, `$91` `OwnerGroup`, `$92`
  `MapTick`, `$95` `LensTimer`, `$97` `TmpB`; `$84`, `$88`, `$8A`, `$93-$94`, `$96`, `$98-$9F`
  free; `$A0–$D7` the score library; `$D8–$F7` free; `$F8–$FF` stack. The source header is the
  exact map.
- **Checkpoints:** `StartFrame` (`$F1A9`, 259/3), `VblankStart` (`$F1B7`, 0/5), `BodyStart`
  (`$F2F2`, 37/5), `OverscanStart` (`$F66B`, 229/6), `LensRead` (A=0/1/2), `LensWrite` (`$F68B`, A=the new
  lens), `FrameRead` (A=the frame count), `MapIndexRead` (A=the highlighted RAM byte index). The
  bB listing checkpoints are quoted by label, not by the demo's symbols.
- **Evidence pins:** the demo runs; the three lenses differ; the state log shows `LensWrite`
  changing 0→1→2; the frame is 262; the bB reference ROM is 4,096 and Stella runs it; the bB
  listing shows `start`, `.main`, `drawscreen`, `kernel`, `vblank_bB_code`, `overscan`, the
  reversed `if` lowering, and the `SED/CLC/ADC/CLD` score. The doc never claims the demo is bB
  output.
- **Screenshots:** `run.png`, `zones.png`, `variables.png` from `demo-66.bin`; `bb-run.png` from
  the bB reference ROM. The capture note discloses the lens/SELECT path and the bB reference's
  provenance.
- **Exercises:** analysis, answered in the doc; no solution files.
  1. **Find the `if` lowering.** Locate `if player0y > 120 then player0y = 60` in the listing;
     explain why the branch is taken when the condition is false; prove it with a Stella
     breakpoint; change the threshold and compare.
  2. **Map the variables.** Use `2600basic_variable_redefs.h` and the bB symbol file to find
     `player0y`, `player1y`, `score`, `temp1`, and the stack; prove the addresses with a debugger
     watch; explain why a `dim` alias costs no RAM.
  3. **Trace `drawscreen`.** Find the 2-line kernel, the `vblank_bB_code` hook, and the overscan;
     measure the frame in Stella; explain what the 2-line kernel buys and what it costs; name one
     thing the reader would hand-write instead.
- **Integration:** prev 65; next 67; **rebuild the Part 9 index** to the Part 7/8 format (the big-idea intro, a lesson table with rows 66–68, and a "What You'll Learn" section), row 66 ✅; sidebar `config.ts:155`.
- **Risks:** bB output is version-specific (pin 1.9); the demo is not generated code (say so);
  the ZONES lens is a projection (say so); the bB reference ROM is not drift-checked (say so).

---

## Lesson 67: Automatable Patterns — A Wave Compiler

- **Goal:** recognize a repeated game pattern, define a small description language for it, write a
  generator that lowers the description into assembly tables, and run the generated levels.
- **Prerequisites:** Lesson 03 (the anatomy), Lesson 04 (registers), Lesson 12 (the frame),
  Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players),
  Lesson 26 (positioning), Lesson 33 (`INPT4` and fire), Lesson 39 (the score kernel), Lesson 41
  (game states), Lesson 48 (the taxonomy), Lesson 53 (kernel patterns), Lesson 55 (text), Lesson
  66 (the bB analysis).
- **Concepts:** patterns vs one-off code; the boundary between data and code; a line-oriented DSL;
  validation and range checking; a generator with a deterministic output; a `--check` drift gate;
  generated tables vs generated code; the runtime interpreter; the cost of table indirection; the
  design of a level format that a human can edit and a machine can validate.
- **ROM:** `67-automatable-patterns.asm` — **"the wave lab"**, 4,096 bytes.
  - The picture: a 16-line band, a 1-line transition, a 64-line generated backdrop (8 playfield
    rows), and a 111-line play area (7 setup + 51 rows / 102 game lines + 2 blank) = 192. The player (P0) sits near the bottom and moves left/right with the
    joystick; fire (`INPT4` bit 7) launches the ball upward; enemies are P1, M0, M1, and the ball
    (four slots). Generated waves spawn enemies at the spec's frames and positions; type 0 falls
    straight, type 1 drifts left/right. A shot that hits an enemy deactivates it, increments the
    score, and resets the shot. An enemy that reaches the bottom deactivates (the lab does not
    punish misses). After the last wave plus 120 frames, the level loops.
  - Two generated levels, `A` and `B`, differ in name, background/playfield colours, backdrop,
    wave timing, positions, speeds, and types. SELECT switches levels and resets the frame/wave
    state. The label shows the level name (six characters) and the score; the score is 0–99.
  - Frame: 262 lines; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5,
    `OverscanStart` 229/6.
- **DSL (wave spec)** — line-oriented text, `#` comments, one directive per line:
  - `level <A|B>` — starts a level; required once.
  - `name <six characters>` — the label (space-padded to six).
  - `bg <hex>` / `pf <hex>` — the background and playfield colours.
  - `backdrop <20 chars>` — one of eight rows; `.` = empty, `X` = solid. Exactly eight rows per
    level. The generator expands each row into PF0/PF1/PF2 bytes.
  - `wave <index> <frame> <x> <y> <speed> <type>` — `index` 0..N-1 in order, `frame` 0..255,
    `x` 0..152, `y` 64..160, `speed` 1..3, `type` 0 (straight) or 1 (drift); exercise 1 adds type
    2 (zigzag).
  - The generator validates every field, checks the wave count, and exits nonzero with a
    `spec:line: message` on a bad spec. It prints a one-line report per level (waves, frames).
- **Generator:** `lesson67-generate.py` — Python 3, no third-party dependencies. It reads one or
  more `--spec` files, emits an ACME include with a shared level descriptor table and per-level
  arrays, and supports `--check` (regenerate in memory and compare with the committed include;
  nonzero on drift), `--out <path>`, and `--report`. The committed include is
  `generated-levels.inc`; the main source sources it, and each exercise solution sources its own
  generated include (`generated-zigzag.inc`, `generated-three.inc`, `generated-color.inc`). CI does not run Python;
  the author runs `--check` before each commit.
- **Generated include shape:** `LevelCount`; `LevelName` (6 bytes/level); `LevelBG`, `LevelPF`
  (1 byte/level); `LevelWaveCount` (1 byte/level); a per-level descriptor with pointers to the
  wave arrays and the backdrop; per-level `WaveFrame`, `WaveX`, `WaveY`, `WaveSpeed`, `WaveType`
  arrays; per-level 8×3 backdrop bytes. The exact symbol names are in the generator and the doc.
- **RAM:** `$80` `Level`, `$81` `Frame`, `$82` `WaveIndex`, `$83` `WaveCount`, `$84` `LevelPtrLo`,
  `$85` `LevelPtrHi`, `$86` `PlayerX`, `$87` `ShotX`, `$88` `ShotY`, `$89` `ShotActive`, `$8A`
  `Score`, `$8B` `PrevSelect`, `$8C` `NewSelect`, `$8D` `PrevFire`, `$8E` free (exercise 3 uses it),
  `$8F-$9E` the four enemy slots (active/x/y/type/speed), `$9F` `Tmp`; `$A0-$D7` the score library;
  `$D8-$D9` `ArrayPtr`, `$DA` `SlotOfs`, `$DB-$F7` free; `$F8-$FF` stack. The name is drawn from
  the generated `LevelNName` ROM table, so no name buffer sits under the stack.
- **Checkpoints:** `StartFrame`, `VblankStart`, `BodyStart`, `OverscanStart`, `Level` (A=0/1),
  `LevelWrite` (A=the new level), `WaveSpawn` (A=the wave index), `ScoreWrite` (A=the score),
  `Frame`. The state log proves the SELECT level switch, a generated wave spawn, and a score
  increment.
- **Evidence pins:** all four ROMs 4,096; the generator `--check` passes (with and without `--out`),
  a bad spec exits 1 with `spec:line`, and a tampered include exits 1 with a drift diff; the two
  specs validate; the three captures show the two levels and the post-hit band with `WAVE-A`
  intact; `WaveSpawn` reports the wave index and slot; `ScoreWrite` advances; the frame is 262;
  the generated include's arrays match the spec fields (a host-side parse check).
- **Screenshots:** `level-a.png` (normal run), `level-a-hit.png` (after a score hit, name intact),
  and `level-b.png` (`-holdselect` at power-on) from the committed ROM; the doc discloses the
  paths. The images show the two levels and the post-hit band.
- **Exercises:** each ships a 4,096-byte solution.
  1. **Add a zigzag wave.** Add type 2 to the generator's validation and the engine's update (a
     triangle-wave X offset); add a spec with zigzag waves; ship `exercise-01-solution.asm` with
     the generated table and the engine change. The doc shows the generator diff.
  2. **Add a third level and a selector.** Add level C, a third spec, and a level-select screen
     (or a SELECT cycle A→B→C); ship `exercise-02-solution.asm` with three levels. The doc shows
     the descriptor table.
  3. **Generate a colour schedule.** Extend the generator with `color <frame> <value>` lines and
     the engine with a schedule apply; ship `exercise-03-solution.asm` with a colour-cycling level.
     The doc shows the generated schedule and the ROM.
- **Integration:** prev 66; next 68; index row 67 ✅; sidebar `config.ts:156`.
- **Risks:** generator/include drift (`--check`); a spec range that puts an enemy off-screen
  (validation); the 4K budget with two levels (compact arrays); the score/label window (reuse
  `include/score.asm`).

---

## Lesson 68: Kernel Architecture — A Zone Framework

- **Goal:** design a reusable kernel architecture that composes a 192-line frame from configurable
  display zones, enforce the line budget at assembly time, and select among three layouts at
  runtime.
- **Prerequisites:** Lesson 03 (the anatomy), Lesson 04 (registers), Lesson 12 (the frame),
  Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players),
  Lesson 26 (positioning), Lesson 48 (the taxonomy), Lesson 49 (the two-line kernel), Lesson 50
  (the multi-zone kernel), Lesson 53 (kernel patterns), Lesson 55 (text), Lesson 67 (generated
  data).
- **Concepts:** the kernel as a schedule of bands; the zone descriptor vs the macro call; the
  boundary line; the 192-line budget; the build-time assertion; the band-boundary contract
  (which objects the next zone expects); the runtime layout selector; the cost of a zone
  dispatch (one line + a 13-cycle overscan tax); the difference between a framework and a fixed
  kernel; where a generator would emit zone calls (the bridge to a layout DSL).
- **Library:** `include/kernel_framework.asm` — the new shared include. Source it **after**
  `include/vcs.asm`, `include/macro.asm`, `* = $F000`, and `include/kernel_patterns.asm` (the
  framework calls the four pattern routines). The framework owns no RAM beyond
  `kernel_patterns.asm`'s `$80–$82`. API:
  - `+kf_begin` — reset the line budget.
  - `+kf_fill .color, .dataLines` — a solid background band (uses `KernelFill`).
  - `+kf_pf .color, .rows, .table` — a playfield band, two lines per row (uses `KernelPFRows`).
  - `+kf_strip .color, .dataLines, .table` — a one-byte-per-line GRP0 band (uses
    `KernelSpriteStrip`).
  - `+kf_ramp .dataLines, .table` — a one-byte-per-line COLUBK band (uses `KernelColorRamp`).
  - `+kf_custom .dataLines, .routine` — a lesson-supplied band; the routine reads `KernelPtr`/
    `KernelRows`, draws `.dataLines` lines, and returns.
  - `+kf_end` — `!error` unless the budget is exactly 192.
  - `+kf_dispatch .l0, .l1, .l2` — the runtime branch dispatcher on `Layout` (`$83`).
  - **Budget rule:** each zone costs `.dataLines + 1` (one boundary line). Sum = 192. The
    preflight prototype caught a 191-line layout; the corrected layouts measure Body 37 →
    Overscan 229.
  - **Boundary contract:** the macro sets up during the returning handler's line and starts the
    handler after `WSYNC`; the first store lands before the visible area. The last zone of every
    layout must end black so the 13-cycle overscan tax (229/19) is invisible.
- **ROM:** `68-kernel-architecture.asm` — **"the zone gallery"**, 4,096 bytes. Three layouts from
  the same framework, SELECT cycles:
  - **Layout 0 — STATUS (4 zones, 192):** fill 15 + PF 24 rows + strip 48 + ramp 77.
    16 + 49 + 49 + 78 = 192. A label/status band over a playfield, a player strip, and a colour
    ramp. The ramp's last byte is black.
  - **Layout 1 — STARFIELD (4 zones, 192):** ramp 31 + strip 95 + PF 16 rows + fill 30.
    32 + 96 + 33 + 31 = 192. A star strip over a playfield, ending in a black fill.
  - **Layout 2 — SPLIT (4 zones, 192):** PF 24 rows + strip 31 + PF 24 rows + ramp 61.
    49 + 32 + 49 + 62 = 192. Two playfield bands with a sprite strip between them; the ramp's last
    byte is black.
  - The frame: 262 lines; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5,
    `OverscanStart` 229/19 (the 13-cycle dispatch tax; the scanline is 229).
- **RAM:** the framework owns `$80–$82`; `$83` `Layout`, `$84` `Frame`, `$85` `PrevSelect`,
  `$86` `NewSelect`, `$87` `Startup`, `$88` `SpriteY`, `$89-$D5` `RampDataA` (the 77-byte STATUS
  ramp; the score library is not sourced), `$D6` `Tmp`, `$D7` free; `$D8-$F7` free; `$F8-$FF`
  stack. The source header is the exact map.
- **Checkpoints:** `StartFrame` (`$F099`, 259/3), `VblankStart` (`$F0A7`, 0/5), `BodyStart`
  (`$F140`, 37/5), `KernelEnd`/`OverscanStart` (`$F143`, 229/19), `LayoutRead` (A=0/1/2),
  `LayoutWrite` (A=the new layout), `FrameRead` (A=the frame count). The state log proves the
  layout switch and the 192-line budget.
- **Evidence pins:** every layout passes `+kf_end`; `acme` 4,096; the three captures differ;
  `LayoutWrite` changes 0→1→2; `OverscanStart` 229/19; the frame is 262; the framework header
  documents the API and the boundary contract.
- **Screenshots:** `layout-status.png`, `layout-starfield.png`, `layout-split.png` from the
  committed ROM; the doc discloses the SELECT path.
- **Exercises:** each ships a 4,096-byte solution.
  1. **Add a ball zone.** Define a lesson-local `BallBand` routine (one ENABL byte per line) and
     call it through `+kf_custom 12, BallBand`; ship `exercise-01-solution.asm`. The doc shows the
     routine, the `+kf_custom` call, and the five-zone budget (13+49+39+13+78 = 192).
  2. **Add a fourth layout and a selector.** Add a title/selector screen (or a fourth layout
     D→layout 0) and a `+kf_dispatch` variant; ship `exercise-02-solution.asm`. The doc shows the
     dispatch and the new ledger.
  3. **Make a zone configurable at runtime.** Add a scrolling starfield (a RAM strip updated each
     frame) or a colour-cycling ramp; ship `exercise-03-solution.asm`. The doc shows the update
     and the budget.
- **Integration:** prev 67; next Part 10's 69; index row 68 ✅; sidebar `config.ts:157`.
- **Risks:** the boundary line (budget rule); the dispatch tax (229/19); the RAM collision
  (`$80–$82`); the 4K budget (three layouts + framework); the last-zone colour (black).

---

## Cross-Lesson Evidence Summary

| Lesson | ROM(s) | Primary evidence | Captures |
| --- | --- | --- | --- |
| 66 | `demo-66.bin` (4,096) + `lesson66-bb.bin` (4,096) | Three lenses; bB listing; frame 262; bB `start`/`drawscreen`/`.main` | 3 + 1 reference |
| 67 | main + 3 solutions (4,096 each) | `--check` clean; two levels; wave spawns; frame 262 | 2 |
| 68 | main + 3 solutions (4,096 each) | `+kf_end` 192; three layouts; frame 262; 229/19 | 3 |
