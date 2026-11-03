# Lesson Specifications: Part 3 — Playfield (Lessons 19–24)

> **Document**: 03-lesson-specs.md
> **Parent**: [Index](00-index.md)

This is the design authority for the six Part 3 lessons. Each section fixes the lesson's structure
(pattern, colors, counts, cadence, write cycles) so Session A can freeze concrete ST expectations
([07-testing-strategy.md](07-testing-strategy.md)); the author derives every claim and cycle ledger
from these designs, and any deviation is a specification change, not a freedom of implementation.

## Shared design rules (apply to every lesson)

- **Frame skeleton continuity:** `!cpu 6502` + `include/vcs.asm` + `include/macro.asm`, origin
  `* = $F000`, `Reset` calling `+clean_start`, `+vsync` (3 lines), VBLANK on with `+set_timer 44`
  (exactly 37 lines), `+wait_timer`, release, visible kernel, `STA WSYNC` before the overscan
  blank-on, `+set_timer 36` (30 lines), `+wait_timer`, `JMP` to the frame top, vectors at `$FFFA`.
- **The frame is 262 lines** (3 + 37 + 192 + 30). The release is the first visible line (Stella
  scanline 37); the overscan blank-on lands in line 229's HBLANK.
- **Playfield geometry:** 20 bits per half; each bit is one **chunk** of 4 color clocks; 40 chunks
  across the 160-clock visible line. Capture x = **25 + chunk × 24**; the picture spans x = 25–984
  and rows 107–711 (192 lines). Bit order is `include/vcs.asm`/`tia-hardware.md`: `PF0` bits 4–7
  (bit 4 leftmost), `PF1` bit 7 leftmost, `PF2` bit 0 leftmost (so `PF2` bit 7 is the
  center-adjacent chunk).
- **Hold kernels:** in Lessons 19, 20, and 22 the pattern is constant down the screen. The PF,
  `CTRLPF`, and color registers are written during VBLANK; the visible kernel is a counted
  `STA WSYNC` hold loop. The pattern is redrawn by the TIA every line from the registers.
- **Phase discipline:** the release is `LDA #$00` + `STA VBLANK` (5 cycles). Where the visible
  kernel's steady-state wake is also 5 cycles (`CPY`/`BNE` or `DEX`/`BNE`), the first visible line
  shares the kernel's phase. Where it is not, the spec states the first-line write positions and
  proves they still land before each register's display slot.
- **Colors follow Lesson 13's palette byte** (`%HHHHLLL0`, hue × 16 + level × 2) and the course's
  named-color table. `$02` is the dark neutral (level 1); `$C8` is green; `$42` red; `$84` blue.
- **Forward mentions are name-only** (players, missiles, the ball, `PFP`'s visible effect); lesson
  code, exercises, and solutions use only mechanisms taught by that lesson or earlier (AR-9).
- **Geometry wording is exact** (Part 1/2 review discipline): "N chunks" means N playfield bits,
  each 4 color clocks; pixel captions state the measured capture x.
- The document's embedded listing is byte-identical to the `.asm` file; Key Takeaways ≤ 7 bullets;
  label references are phrased via the `acme -l` symbol list.
- **No standalone demo ROMs** (AR-3): each main ROM is the concept made visible; the reason is
  stated per lesson.

---

## Lesson 19: Playfield Basics — PF0, PF1, PF2

- **Goal:** draw a playfield from the three registers and understand the 20-bit half, the 4-clock
  chunk, and the `CTRLPF` reflect/repeat control.
- **Concepts:** `PF0`/`PF1`/`PF2` and their bit order; 20 bits per half = 20 chunks = 80 color
  clocks; the full line is 40 chunks (160 clocks); `CTRLPF` bit 0 `REF` mirrors the right half,
  clear repeats it; `COLUPF` colors the playfield; the TIA re-reads the registers every line, so a
  constant pattern is a vertical extrusion.
- **ROM:** `19-playfield-basics.asm` — "the castle wall": `PF0 = $F0`, `PF1 = $CC`, `PF2 = $F0`;
  `COLUPF = $C8` (green), `COLUBK = $02` (dark neutral); `CTRLPF` starts at `$01` (reflect) and
  flips bit 0 every **120 frames** (~2 s). The visible kernel is a 192-iteration `STA WSYNC` hold.
  Note the PF2 order: bit 0 is leftmost, so `$F0` displays as **00001111** (chunks 12–15 off,
  16–19 on).
- **Expected screen:** a green block pattern on a dark field, constant down all 192 lines.
  - **Reflect state** (`CTRLPF = $01`): the 40-chunk sequence is
    `111111 00 11 000000 11111111 000000 11 00 111111` — symmetric, with an 8-chunk green
    central block (chunks 16–23) between two dark bands. On/off transitions at capture x =
    **169, 217, 265, 409, 601, 745, 793, 841**.
  - **Repeat state** (`CTRLPF = $00`): the left 20 chunks repeat on the right; the central green
    block widens to chunks 16–25, and the right-hand dark band moves outward from 24–29 to 30–35
    while the left half is unchanged. Transitions at **169, 217, 265, 409, 649, 697, 745, 889**.
    The two states differ most at chunks 24–35 (x = 601–889).
- **Demo ROM:** none — the two symmetry states are the visible picture (AR-3).
- **Exercises:** 1. invert the pattern (`PF0=$00`, `PF1=$33`, `PF2=$0F`) — the on/off regions
  swap: the green centre block becomes dark and the dark bands become green —
  `exercise-01-solution.asm`; 2. draw a single
  chunk bar (`PF1=$10`) and explain why reflect shows two bars and repeat also shows two —
  `exercise-02-solution.asm`; 3. *(Stretch)* cycle eight pattern triples from a table, one every
  60 frames, so the wall changes shape once a second — `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson19/reflect.png` and `…/repeat.png` — the two states.
- **Evidence pins (AR-6):** `StartFrame` (Stella 259), `VblankStart` (0), `VisibleStart` (37),
  `OverscanStart` (229); `CtrlWrite` — one hit **per frame**, A = `$01` while reflect is showing
  and `$00` while repeat is showing; the first change is at frame 120; the hold kernel's first
  line and one steady line; the capture transitions above.
- **Integration:** prev → Lesson 18; next → Lesson 20; part-index row 19 → ✅ Complete linking
  `./19-playfield-basics`; sidebar entry exists (`config.ts:72`). Estimated time: 60 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 19): ST-19.1 assembly &
  drift · ST-19.2 reflect geometry · ST-19.3 repeat geometry · ST-19.4 debugger state · ST-19.5
  solutions and screenshots · ST-19.6 site integration.

## Lesson 20: Playfield Colors and Priority

- **Goal:** color the playfield deliberately, split its halves with score mode, and understand the
  TIA's priority stack.
- **Concepts:** `COLUPF` as the playfield/ball color; `CTRLPF` bit 1 `SCORE` — the left half takes
  `COLUP0`'s color and the right half `COLUP1`'s, the classic scoreboard split; the priority table
  (P0/M0 > P1/M1 > PF/BL > BK by default; `CTRLPF` bit 2 `PFP` lifts PF/BL above the players);
  why `PFP`'s visible effect needs a player/ball and therefore waits for Part 4 (name-only, AR-14).
- **ROM:** `20-playfield-colors.asm` — "the two-tone wall": a solid wall with a central gap
  (`PF0=$F0`, `PF1=$FF`, `PF2=$FC`), `COLUPF=$C8` (green), `COLUBK=$02`, `CTRLPF=$01` (reflect,
  normal color). Every **120 frames** it flips to score mode (`CTRLPF=$03`) with `COLUP0=$42` (red)
  and `COLUP1=$84` (blue). The visible kernel is the 192-line hold loop.
- **Expected screen:** a wall with a 4-chunk central gap (96 px, x = 457–553), constant down the
  screen.
  - **Normal state:** green wall, dark gap — transitions x = **25 (green), 457 (dark), 553
    (green)**.
  - **Score state:** red left half, blue right half, dark gap — transitions x = **25 (red), 457
    (dark), 553 (blue)**. The wall's color split proves `SCORE` reads `COLUP0`/`COLUP1` per half.
- **Demo ROM:** none — the color split is the visible picture (AR-3).
- **Exercises:** 1. swap the score colors (`COLUP0=$84`, `COLUP1=$42`) — left blue, right red —
  `exercise-01-solution.asm`; 2. a three-color wall: keep score mode but clear `PF1` bits to open
  gaps, with `COLUBK=$1A` (gold), so red/blue blocks are separated by gold —
  `exercise-02-solution.asm`; 3. *(Stretch)* a four-quadrant frame: top half in score mode
  (red|blue), bottom half in normal color (green), switched at line 96 by a per-line branch —
  `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson20/single-color.png` and `…/score-mode.png`.
- **Evidence pins:** frame checkpoints; `CtrlWrite` on each flip (A = `$01` / `$03`, first flip
  frame 120); the capture transitions and colors above; a note that `PFP` (bit 2) is taught but not
  exercised because no player exists yet.
- **Integration:** prev → Lesson 19; next → Lesson 21; part-index row 20 → ✅ Complete linking
  `./20-playfield-colors`; sidebar entry exists (`config.ts:73`). Estimated time: 45 minutes.
- **ST cases:** ST-20.1 assembly & drift · ST-20.2 normal color · ST-20.3 score split · ST-20.4
  debugger state · ST-20.5 solutions and screenshots · ST-20.6 site integration.

## Lesson 21: Asymmetric Playfield — Different Left and Right

- **Goal:** give the two halves different data by rewriting `PF0`/`PF1`/`PF2` mid-line, with
  deterministic timing.
- **Concepts:** repeat mode draws the left 20 bits, then the same registers again for the right
  half; the TIA re-reads a register for its second-half slot; a write after a register's left-half
  slot but before its right-half slot changes only the right half; the write windows are set by
  the left-half slot ends (PF0 at clock 84, PF1 at 116, PF2 at 148) and the right-half slot starts
  (PF0 at 148, PF1 at 164, PF2 at 196).
- **ROM:** `21-asymmetric-playfield.asm` — "the split gate": repeat mode (`CTRLPF=$00`), a solid
  left wall with a 2-chunk doorway at the centre (`LEFT0=$F0`, `LEFT1=$FF`, `LEFT2=$FC`) and a
  gapped, striped right half (`RIGHT0=$00`, `RIGHT1=$AA`, `RIGHT2=$55`); `COLUPF=$C8`,
  `COLUBK=$02`. Every line rewrites the three registers for the right half.
- **Pinned per-line ledger** (body entered at cycle 5 on every line — the release's 5 cycles equal
  the steady-state `DEX`+`BNE`):

  | cycles | instruction | effect / note |
  | --- | --- | --- |
  | 5–9 | `LDA #LEFT0` / `STA PF0` | new PF0 from cycle 10 (clock 30) — left slot starts at 68 |
  | 10–14 | `LDA #LEFT1` / `STA PF1` | effect 15 (clock 45) — left slot starts at 84 |
  | 15–19 | `LDA #LEFT2` / `STA PF2` | effect 20 (clock 60) — left slot starts at 116 |
  | 20–29 | `NOP` × 5 | burn 10 cycles; left PF0 slot (68–84) is past |
  | 30–34 | `LDA #RIGHT0` / `STA PF0` | effect 35 (clock 105) — before right PF0 at 148 |
  | 35–40 | `NOP` × 3 | left PF1 slot (84–116) is past |
  | 41–45 | `LDA #RIGHT1` / `STA PF1` | effect 46 (clock 138) — before right PF1 at 164 |
  | 46–51 | `NOP` × 3 | left PF2 slot (116–148) is past |
  | 52–56 | `LDA #RIGHT2` / `STA PF2` | effect 57 (clock 171) — before right PF2 at 196 |
  | 57–59 | `STA WSYNC` | write 59, park 60–75 |
  | next 0–4 | `DEX` / `BNE` taken | wake 5 cycles; body re-entered at 5 |

- **Expected screen:** the left 18 chunks solid green, a 6-chunk central gap (left 2 + right 4,
  144 px, x = 457–601), then alternating 1-chunk stripes across the right half. Transitions at
  x = **25 (on), 457 (off), 601 (on), 625 (off), 649 (on), 673 (off), 697 (on), 721 (off), 745
  (on), 769 (off), 817 (on), 841 (off), 865 (on), 889 (off), 913 (on), 937 (off), 961 (on)**.
- **Demo ROM:** none — the asymmetric halves are the visible picture (AR-3).
- **Exercises:** 1. move the gate: `LEFT2=$F0`, `RIGHT0=$F0` — the gap narrows to 4 chunks and
  the right half starts solid — `exercise-01-solution.asm`; 2. mirror the right half: set
  `RIGHT0/1/2` equal to the left values, enable reflect (`CTRLPF=$01`), and skip the mid-line
  rewrite (the right half becomes the mirror) — `exercise-02-solution.asm`; 3. *(Stretch)* a
  two-band scene: top 96 lines use one left/right pair, bottom 96 another (two copies of the
  per-line body, each with its own immediates) — `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson21/asymmetric.png`.
- **Evidence pins:** frame checkpoints; **six write checkpoints** — `Left0`/`Left1`/`Left2` at hit
  cycles 10/15/20 and `Right0`/`Right1`/`Right2` at 35/46/57, 192 hits per frame each, A = the
  value written. The right-half hits prove the writes land after the left slots and before the
  right slots (the right half's data changes; the left half does not). The capture transitions
  above prove the same in pixels.
- **Integration:** prev → Lesson 20; next → Lesson 22; part-index row 21 → ✅ Complete linking
  `./21-asymmetric-playfield`; sidebar entry exists (`config.ts:74`). Estimated time: 75 minutes.
- **ST cases:** ST-21.1 assembly & drift · ST-21.2 asymmetric frame · ST-21.3 mid-line write
  windows (state log + ledger) · ST-21.4 debugger state · ST-21.5 solutions and screenshot ·
  ST-21.6 site integration.

## Lesson 22: Playfield Animation — Moving Walls

- **Goal:** animate the playfield frame to frame with a small state machine, without per-line data.
- **Concepts:** the registers persist across lines, so a frame-level change updates the whole
  column of the picture; a state byte plus a table is enough for an animation; a direction byte
  makes a ping-pong; a frame counter sets the cadence; VBLANK is where the state changes.
- **ROM:** `22-playfield-animation.asm` — "the portcullis": a symmetric castle wall with a central
  gate (`PF0=$F0`, `PF1=$FF`, `PF2=GateTable[state]`; `CTRLPF=$01`, reflect; `COLUPF=$C8`,
  `COLUBK=$02`). The gate has **9 states** — `$FF`, `$7F`, `$3F`, `$1F`, `$0F`, `$07`, `$03`,
  `$01`, `$00` — stepping once every **30 frames** (~0.5 s), reversing at states 0 and 8. The
  visible kernel is the 192-line hold loop.
- **Expected screen:** a green portcullis whose central gate opens from 0 to 16 chunks (0–384 px)
  and closes again. State k opens 2k chunks; the gap spans x = **505 − 24k … 505 + 24k** (state 0
  has no gap; state 8 spans x = 313–697). Two captures: a partially open state and the fully open
  state.
- **Demo ROM:** none — the gate animation is the visible picture (AR-3).
- **Exercises:** 1. change the cadence to 15 frames (twice as fast) or 60 (half speed) —
  `exercise-01-solution.asm`; 2. a one-sided gate: switch to repeat mode and animate only the
  right half with the L21 mid-line kernel, leaving the left wall closed —
  `exercise-02-solution.asm`; 3. *(Stretch)* scroll the wall: rotate the 20-bit pattern one chunk
  per frame with `ASL`/`ROL` across the three bytes, so the castle slides horizontally —
  `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson22/gate-opening.png` and `…/gate-open.png`, captured
  at waits chosen in Session A so the two states are unambiguous (pixel-classified by gap width).
- **Evidence pins:** frame checkpoints; `GateStep` — one hit per 30 frames, A = the new state and
  `PF2` = `GateTable[state]`; the capture gap widths (state k = 48k px).
- **Integration:** prev → Lesson 21; next → Lesson 23; part-index row 22 → ✅ Complete linking
  `./22-playfield-animation`; sidebar entry exists (`config.ts:75`). Estimated time: 60 minutes.
- **ST cases:** ST-22.1 assembly & drift · ST-22.2 closed/partial gate · ST-22.3 open gate and
  cadence · ST-22.4 debugger state · ST-22.5 solutions and screenshots · ST-22.6 site integration.

## Lesson 23: Data-Driven Playfield — Levels from Tables

- **Goal:** drive the playfield from ROM tables, one row per scanline, and switch levels by
  switching table pointers.
- **Concepts:** a row is three bytes (`PF0`, `PF1`, `PF2`); a 192-row table is 576 bytes; three
  zero-page pointers offset by 0/1/2 read the three bytes of the same row with `LDA (ptr),Y` and
  `Y = row × 3`; a one-line kernel prefetches the next row during the visible line; level switching
  happens in VBLANK by changing the pointer base; compression (the stretch exercise) packs PF0's
  four bits.
- **ROM:** `23-data-driven-playfield.asm` — "the keep": two levels of 192 interleaved rows, each
  `PF0, PF1, PF2`, drawn by a one-line kernel; `CTRLPF=$01` (reflect), `COLUPF=$C8`, `COLUBK=$02`.
  Level 1 is a keep with a full border, two internal vertical walls, and a horizontal divider at
  rows 96–99 with a central doorway. Level 2 is a labyrinth with the divider at rows 64–67, a
  central pillar, and a side chamber. The level switches every **240 frames** (~4 s).
- **Pinned per-line ledger** (body entered at cycle 5 on the first line, cycle 0 on later lines;
  `Y = row × 3`, `X` = rows remaining):

  | cycles | instruction | note |
  | --- | --- | --- |
  | 0/5–19/22 | `LDA Tmp0` / `STA PF0` / `LDA Tmp1` / `STA PF1` / `LDA Tmp2` / `STA PF2` | 18 cycles; all three effects land before their slots (PF2's first chunk is at clock 116) |
  | next 24 | `LDA (Ptr0),Y` / `STA Tmp0` / `LDA (Ptr1),Y` / `STA Tmp1` / `LDA (Ptr2),Y` / `STA Tmp2` | prefetch the next row |
  | next 6 | `INY` × 3 | Y += 3 |
  | next 5 | `DEX` / `BNE` taken | 192 rows |
  | next 3 | `STA WSYNC` | park; total 56 of 76 cycles |

  The first line's stores start at cycle 5 (after the release) and end at 22; each register's
  effect is still before its display slot, so line 37 shows row 0 with no artifact.
- **Expected screen:** a green maze on a dark field, drawn at full 192-line resolution; level 1
  shows a border, two vertical walls, and a doorway in the divider at rows 96–99; level 2 shows a
  different divider height, a central pillar, and a side chamber. The two levels differ over a
  large, pinned region (the ST captures are compared).
- **Demo ROM:** none — the two mazes are the visible picture (AR-3).
- **Exercises:** 1. add a third level table and a three-way selector — `exercise-01-solution.asm`;
  2. change the level geometry (move the divider and doorway) — `exercise-02-solution.asm`;
  3. *(Stretch)* compress the `PF0` bytes two rows per byte (only bits 4–7 are used) and unpack
  them at draw time, halving the PF0 storage — `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson23/level1.png` and `…/level2.png`.
- **Evidence pins:** frame checkpoints; `LevelSwitch` — one hit every 240 frames, A = the level;
  `RowStore` — one hit per line at a constant cycle, A = the color/PF byte; the two captures and
  their pixel difference; the ROM is exactly 4,096 bytes.
- **Integration:** prev → Lesson 22; next → Lesson 24; part-index row 23 → ✅ Complete linking
  `./23-data-driven-playfield`; sidebar entry exists (`config.ts:76`). Estimated time: 75 minutes.
- **ST cases:** ST-23.1 assembly & drift · ST-23.2 level 1 maze · ST-23.3 level switch and level
  2 · ST-23.4 debugger state and ledger · ST-23.5 solutions and screenshots · ST-23.6 site
  integration.

## Lesson 24: The Multicolor Playfield

- **Goal:** change `COLUPF` every scanline to color regions of the playfield independently.
- **Concepts:** `COLUPF` is a per-scanline register like `COLUBK`; a 192-byte color table costs
  little and gives 192 independent line colors; a zero-page pointer lets one kernel switch between
  color schemes; the playfield's shape and its color are independent layers.
- **ROM:** `24-multicolor-playfield.asm` — "the rainbow keep": the Lesson 19 castle pattern
  (`PF0=$F0`, `PF1=$CC`, `PF2=$F0`) with a 192-byte per-line `COLUPF` table; `COLUBK=$02`,
  `CTRLPF=$01`. State A is a 16-band rainbow (hues 0–15, 12 lines each); state B is a region
  scheme (top 96 lines cool blues/cyans/greens, bottom 96 warm reds/oranges/golds). The state
  flips every **120 frames**.
- **Pinned per-line ledger** (release = 5 cycles = steady-state `CPY`+`BNE`; the color write is at
  cycle 10–12 on every line, in HBLANK):

  | cycles | instruction |
  | --- | --- |
  | 0–4 | release (`LDA #$00`, `STA VBLANK`) on line 37; `CPY`/`BNE` (5) on later lines |
  | 5–9 | `LDA (ColorPtr),Y` |
  | 10–12 | `STA COLUPF` |
  | 13–14 | `INY` |
  | 15–17 | `STA WSYNC` |
  | next 0–4 | `CPY #192` / `BNE` taken |

- **Expected screen:** the castle pattern in 16 horizontal color bands, constant across all rows
  of a band; state B shows the cool/warm split at the middle of the picture. Captures:
  `rainbow.png` (state A) and `regions.png` (state B), pixel-classified by the color at rows 110
  and 400.
- **Demo ROM:** none — the rainbow is the visible picture (AR-3).
- **Exercises:** 1. a moving rainbow: add a frame counter to the table index so the bands slide up
  one band per second — `exercise-01-solution.asm`; 2. color by region: replace the table with a
  sky/ground scheme (e.g., 96 lines of `$84`, 96 of `$46`) — `exercise-02-solution.asm`;
  3. *(Stretch)* combine data and color: use the Lesson 23 row table and color each row by a
  property of its data (e.g., wall rows `$C8`, empty rows `$02`), producing a two-color maze —
  `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson24/rainbow.png` and `…/regions.png`.
- **Evidence pins:** frame checkpoints; `ColorWrite` — one hit per line at cycle 10–12, A = the
  table byte (12 consecutive lines share a hue); `StateFlip` every 120 frames; the capture bands.
- **Integration:** prev → Lesson 23; next → Lesson 25 (`/part4-sprites/25-player-basics`, the
  forward-link pattern); part-index row 24 → ✅ Complete linking `./24-multicolor-playfield`;
  sidebar entry exists (`config.ts:77`). Estimated time: 60 minutes.
- **ST cases:** ST-24.1 assembly & drift · ST-24.2 rainbow bands · ST-24.3 region state · ST-24.4
  debugger state and ledger · ST-24.5 solutions and screenshots · ST-24.6 site integration.
