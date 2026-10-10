# Lesson Specifications: Part 2 — TV & TIA (Lessons 12–18)

> **Document**: 03-lesson-specs.md
> **Parent**: [Index](00-index.md)

This is the design authority for the seven Part 2 lessons. Each section fixes the lesson's
structure (bands, counts, colors, cadence) so Session A can freeze concrete ST expectations
([07-testing-strategy.md](07-testing-strategy.md)); the author derives every claim and cycle
ledger from these designs, and any deviation is a specification change, not a freedom of
implementation.

## Shared design rules (apply to every lesson)

- **Structure is fixed here; exact cycle plumbing is derived in the walkthrough** and recorded in
  a static cycle ledger with state-log evidence (AR-6).
- **Geometry wording is exact** (Part 1 review discipline): the release line is counted inside
  the top band's lines so "N equal bands" is literally true; code, comments, and the document
  must agree.
- **Frame skeleton continuity**: `!cpu 6502` + `include/vcs.asm` + `include/macro.asm`, origin
  `* = $F000`, `Reset` calling `+clean_start`, vectors at `$FFFA`; lessons 13–18 reuse the macro
  frame; lesson 12 writes the frame explicitly and maps it to the macros the reader has used
  since lesson 04.
- **`STA WSYNC` before the overscan blank-on** (blank-on must land in HBLANK) — the Part 1
  review finding.
- **NTSC only** (262 lines, ~60.2 Hz; AR-11). PAL appears as a noted aside at most.
- **Forward mentions are name-only** (`COLUP0`/`COLUP1`/`COLUPF`, the scoreboard/playfield/sprite
  zone taxonomy); code, exercises, and solutions use only mechanisms taught by that lesson (AR-9).
- The document's embedded listings are byte-identical to the `.asm` files; Key Takeaways ≤ 7
  bullets; label references are phrased via the `acme -l` symbol list (Part 1 review discipline).

---

## Lesson 12: The NTSC Frame — Building the Picture Line by Line

- **Goal:** understand how the 2600 paints a television picture and write the canonical 262-line
  frame explicitly, line by line.
- **Concepts:** the NTSC signal and the 262-scanline frame at ~60.2 Hz; VSYNC (3 lines), VBLANK
  (37), visible (192), overscan (30); 76 CPU cycles per scanline (228 color clocks); why the
  frame is drawn every iteration of the main loop; the frame written out — and how it maps to
  `+vsync` / `+set_timer` / `+wait_timer`, which the reader has used all along.
- **ROM:** `12-the-ntsc-frame.asm` — "frame anatomy": explicit VSYNC/VBLANK/visible/overscan
  code (no `+vsync`-family macros inside the frame section; `+clean_start` still runs at reset).
  The visible area shows **four equal bands of 48 lines**: `$42` (red), `$84` (blue), `$C8`
  (green), `$1A` (gold), top to bottom; the release line is counted inside band 0's 48.
- **Expected screen:** four perfectly stable equal bands; identical every frame; no roll.
- **Demo ROM:** none — the main ROM is the frame itself; the screenshot already shows the full
  concept (AR-3).
- **Exercises:** 1. recolor the four bands from RAM (four color bytes written once at startup,
  kernel reads them) — `exercise-01-solution.asm`; 2. re-partition the visible area as 48/96/48
  by changing the structure, keeping the total at 192 — `exercise-02-solution.asm`; 3. *(Stretch)*
  prove the 192-line budget: a 16-color ladder of 12-line bands (one lookup-table row per band)
  that fits exactly — `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson12/frame-anatomy.png` — the four-band frame.
- **Integration:** prev → Lesson 11; next → Lesson 13; part-index row 12 → ✅ Complete linking
  `./12-the-ntsc-frame`; sidebar entry exists (`config.ts:59`). Estimated time: 60 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 12): ST-12.1 assembly &
  drift · ST-12.2 band structure · ST-12.3 stability and frame length · ST-12.4 debugger phase
  map · ST-12.5 solutions and screenshot.

## Lesson 13: Colors — The 128-Color Palette

- **Goal:** choose colors deliberately; understand the palette byte and the luminance axis.
- **Concepts:** the NTSC palette byte `%HHHHLLL0` — hue (16) × luminance (8) = 128 colors; hue
  order and the role of luminance 0 (the palette's darkest step, not pure black); `COLUBK` as
  the picture's background color; the object color registers (`COLUP0`, `COLUP1`, `COLUPF`)
  named as reference — they color objects introduced in later parts (AR-9).
- **ROM:** `13-colors.asm` — "palette explorer": **16 equal bands of 12 lines**, band k = hue k
  (0–15) at the current luminance level; the luminance steps through all 8 levels, one step every
  ~2 seconds (~120 frames), so one full cycle shows all 128 colors; the doc's table maps band →
  hue → an example use.
- **Expected screen:** 16 equal hue bands; the whole picture steps through 8 luminance levels
  (bright to dark and back), each step stable.
- **Demo ROM:** none — the main ROM is a live palette chart (AR-3).
- **Exercises:** 1. swap the axes: 8 luminance bands cycling hue — `exercise-01-solution.asm`;
  2. a "chart match": a lookup table of named colors (from `docs/reference/color-chart.md`)
  shown as labeled bands — `exercise-02-solution.asm`; 3. *(Stretch)* a one-hue fade: a single
  band breathing through all 8 luminance levels — `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson13/palette-hues.png` (a bright step) and
  `…/palette-dim.png` (a dim step) — the two captures prove the luminance cycle.
- **Integration:** prev → Lesson 12; next → Lesson 14; part-index row 13 → ✅ Complete linking
  `./13-colors`; sidebar entry exists (`config.ts:60`). Estimated time: 45 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 13): ST-13.1 assembly &
  drift · ST-13.2 hue frame · ST-13.3 luminance cycle and 128 colors · ST-13.4 debugger state ·
  ST-13.5 solutions and screenshots.

## Lesson 14: WSYNC and Timing — Aligning with the Beam

- **Goal:** control exactly where code lands relative to the electron beam; understand `WSYNC`
  and the 76-cycle scanline budget.
- **Concepts:** the 76-cycle line and HBLANK; what `WSYNC` actually waits for; why untimed writes
  produce moving, torn pictures; the discipline "finish your line's work in the line".
- **ROM:** `14-wsync-and-timing.asm` — "the anchored split": the visible area is **split 96/96**
  — top half `$42` (red), bottom half `$84` (blue) — with the color boundary stable at exactly the
  middle line in the aligned mode. A second, deliberately late mode (same picture, writes landing
  after the line's HBLANK) shows the boundary as a moving, torn edge. The two modes alternate
  every ~2 seconds; the walkthrough carries the cycle ledger for both.
- **Expected screen:** aligned mode — two equal halves, the boundary rock-stable against a
  reference; late mode — the same two colors with a visibly torn, drifting boundary.
- **Demo ROM:** none — the main ROM contrasts both timing regimes directly (AR-3).
- **Exercises:** 1. move the split to another line (one constant) — `exercise-01-solution.asm`;
  2. repair the torn mode: make the late write land in HBLANK (budget fix) —
  `exercise-02-solution.asm`; 3. *(Stretch)* verify your repaired kernel's budget with two
  state-log breakpoints and record the cycle ledger — `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson14/wsync-aligned.png` and
  `…/wsync-torn.png` — the two modes.
- **Integration:** prev → Lesson 13; next → Lesson 15; part-index row 14 → ✅ Complete linking
  `./14-wsync-and-timing`; sidebar entry exists (`config.ts:61`). Estimated time: 60 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 14): ST-14.1 assembly &
  drift · ST-14.2 aligned frame · ST-14.3 late-mode contrast · ST-14.4 debugger timing check ·
  ST-14.5 solutions and screenshots.

## Lesson 15: The Timer — Pacing with the RIOT

- **Goal:** use the RIOT timer for the blanking periods and free CPU time for real work.
- **Concepts:** `TIM64T`, `TIM1T`, `TIM8T`, `TIM1024T` and `INTIM`; timer counts and why the
  VBLANK value is chosen for 37 lines; timer waits vs. `WSYNC` counting; spending the freed
  cycles — computing the next frame while the beam blanks.
- **ROM:** `15-the-timer.asm` — "time to think": the frame's VBLANK is a `TIM64T` wait (explicit
  register writes and `INTIM` polling), and the freed CPU time computes the next frame's picture:
  **four equal 48-line bands** whose hues rotate one step every ~30 frames (~0.5 s), computed
  from a counter in RAM; overscan also paced by the timer.
- **Expected screen:** a stable four-band picture whose hues advance in step every half second —
  the visible proof that the computation fits inside the blanking budget.
- **Demo ROM:** none — the animation is the timer's visible result (AR-3).
- **Exercises:** 1. convert the VBLANK wait from a `WSYNC` loop to `TIM64T` and show the freed
  time — `exercise-01-solution.asm`; 2. compute and use the overscan timer value; move one
  computation there — `exercise-02-solution.asm`; 3. *(Stretch)* split the per-frame work across
  both blanking windows and prove with the ledger that each fits —
  `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson15/timer-frame.png` — the stable frame (one captured
  hue step, described in the caption).
- **Integration:** prev → Lesson 14; next → Lesson 16; part-index row 15 → ✅ Complete linking
  `./15-the-timer`; sidebar entry exists (`config.ts:62`). Estimated time: 60 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 15): ST-15.1 assembly &
  drift · ST-15.2 frame and animation · ST-15.3 timer budgets · ST-15.4 debugger state ·
  ST-15.5 solutions and screenshot.

## Lesson 16: Horizontal Zones — Structuring the Frame

- **Goal:** split the picture into horizontal zones with distinct TIA setups — the multi-zone
  architecture every later part fills in.
- **Concepts:** vertical zones and their boundaries; the standard layout taxonomy — scoreboard,
  playfield, and sprite zones — named as context for later parts (AR-9); changing `COLUBK` at
  zone boundaries; a zone table (`lines`, `color`) driving the paint loop.
- **ROM:** `16-horizontal-zones.asm` — "three-zone sky": **four zones of 24 / 72 / 48 / 48
  lines** (total 192): a dark top zone `$02` (the scoreboard area), a sky zone `$84`, a horizon
  zone `$46` (dark red), and a ground zone `$C4` (dim green); the paint loop reads a 4-entry ROM
  table (lines, color) — a direct lookup-table application (lesson 11).
- **Expected screen:** four zones of exactly the stated heights with distinct colors; stable.
- **Demo ROM:** none — the zone structure is the visible picture (AR-3).
- **Exercises:** 1. add a fifth zone via the table — `exercise-01-solution.asm`; 2. rebalance the
  zones (e.g. 48/96/24/24) keeping the total — `exercise-02-solution.asm`; 3. *(Stretch)* move
  the zone table into RAM so boundaries can be edited live in the debugger —
  `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson16/zones.png` — the four-zone frame.
- **Integration:** prev → Lesson 15; next → Lesson 17; part-index row 16 → ✅ Complete linking
  `./16-horizontal-zones`; sidebar entry exists (`config.ts:63`). Estimated time: 45 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 16): ST-16.1 assembly &
  drift · ST-16.2 zone frame · ST-16.3 table-driven boundaries · ST-16.4 debugger state ·
  ST-16.5 solutions and screenshot.

## Lesson 17: Cycle Counting — The 76-Cycle Budget

- **Goal:** count CPU cycles by hand and budget a kernel's scanlines.
- **Concepts:** 76 cycles per scanline; instruction cycle costs (and their categories); counting
  loops and branches by hand; what happens when a line's work overruns its budget; critical
  scanlines and the ledger discipline.
- **ROM:** `17-cycle-counting.asm` — "the cycle ruler": two 96-line sections. Section 1 is a
  hand-counted **exactly-76-cycle** loop (no `WSYNC` inside; aligned at the section start) that
  steps a color ramp; section 2 is the same loop with a deliberate over-budget addition
  (documented in the ledger), so its color steps land progressively later — the drift renders as
  a visible staircase/tear signature. The exact numbers are frozen in the walkthrough's ledger.
- **Expected screen:** section 1 — perfectly stable stepped bands; section 2 — the same ramp
  with the documented drift pattern; both captured for the ST comparison.
- **Demo ROM:** none — the two-section ruler visualizes the budget directly (AR-3).
- **Exercises:** 1. count a given walkthrough snippet by hand, then verify it with breakpoints —
  `exercise-01-solution.asm`; 2. trim section 2 to exactly 76 cycles and remove the drift —
  `exercise-02-solution.asm`; 3. *(Stretch)* write the full ledger for the kernel and verify two
  consecutive lines' cycle gap with state logs — `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson17/cycle-ruler.png` — the two-section ruler.
- **Integration:** prev → Lesson 16; next → Lesson 18; part-index row 17 → ✅ Complete linking
  `./17-cycle-counting`; sidebar entry exists (`config.ts:64`). Estimated time: 60 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 17): ST-17.1 assembly &
  drift · ST-17.2 ruler structure · ST-17.3 cycle ledger verification · ST-17.4 debugger timing
  check · ST-17.5 solutions and screenshot.

## Lesson 18: Mid-Scanline Changes — Racing the Beam

- **Goal:** change TIA registers mid-scanline on purpose — deterministic timing as a graphics
  tool before sprites exist.
- **Concepts:** the beam crosses the visible line in ~160 color clocks; a `COLUBK` write at cycle
  N paints the boundary at a computable horizontal position; `WSYNC` as the per-line anchor;
  deterministic timing as the basis for later sprite techniques (name-only, AR-9).
- **ROM:** `18-mid-scanline-changes.asm` — "color columns": every visible line paints **four
  vertical columns** — `$42`, `$84`, `$C8`, `$1A` (the lesson-12 palette) — with boundaries at
  roughly the quarter points; the write cycles are hand-timed after each `WSYNC`. Every ~2
  seconds the columns shift by a small cycle offset, so the widths animate; the walkthrough maps
  write cycle → boundary position with the cycle ledger.
- **Expected screen:** four stable vertical columns spanning all 192 lines; two animated states
  (default widths and shifted widths) captured.
- **Demo ROM:** none — the columns are the beam race made visible (AR-3).
- **Exercises:** 1. move one column boundary by NOP-count changes —
  `exercise-01-solution.asm`; 2. add a fifth column — `exercise-02-solution.asm`; 3. *(Stretch)*
  animate the boundaries smoothly, one cycle step per frame — `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson18/columns.png` and `…/columns-shifted.png` — the
  two states.
- **Integration:** prev → Lesson 17; next → Lesson 19 (`/part3-playfield/19-playfield-basics`,
  the forward-link pattern lesson 11 uses); part-index row 18 → ✅ Complete linking
  `./18-mid-scanline-changes`; sidebar entry exists (`config.ts:65`). Estimated time: 60 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 18): ST-18.1 assembly &
  drift · ST-18.2 column frame · ST-18.3 animation states · ST-18.4 debugger timing check ·
  ST-18.5 solutions and screenshots.
