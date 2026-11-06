# Lesson Specifications: Part 7 — Kernel Mastery (Lessons 48–55)

> **Document**: 03-lesson-specs.md
> **Parent**: [Index](00-index.md)
> **Authority**: this document owns the per-lesson design; [07-testing-strategy.md](07-testing-strategy.md)
> owns the ST cases, and [00-ambiguity-register.md](00-ambiguity-register.md) owns the decisions.

## Shared Conventions

### Frame and Video

- NTSC only: `VSYNC` 3 + `VBLANK` 37 + picture 192 + overscan 30 = **262 lines**. The last
  visible line is 228 and `OverscanStart` is scanline 229; the cycle at that label depends on
  the kernel's tail, so the scanline is the oracle, not the cycle.
- `+set_timer 44` and `+wait_timer` cover VBLANK; `+set_timer 36` and `+wait_timer` cover overscan.
- The picture begins at scanline 37 (visible line 0 = capture y 107) and ends at scanline 228.
- Capture mapping used by every pixel check: `capture x = 25 + 6 × TIA_X`, `capture y = 107 +
  3.15 × visible_line`. A sprite's first visible row is the scanline where its `GRP` write is
  latched.
- **Kernel order:** every kernel is **work-first** — write the line's registers, then `STA WSYNC`
  — except the documented cycle-timed exceptions: the 48-pixel score kernel (WSYNC-first, Lesson
  39/55), a 1-line kernel whose first store is timed, and any unrolled row whose stores are
  deliberately placed in HBLANK. Each exception names its measured store line/cycle in the lesson.
- **One HMOVE per repositioning event:** set every coarse `RESxx` and every `HMxx` value first,
  then strobe one `HMOVE`; the final `STA WSYNC` sits immediately after the last `STA RESxx`, with
  `STA HMOVE` next. A multi-zone kernel may use one HMOVE per zone that repositions players
  (Lesson 50's score and game zones); both are labelled and measured. An HMOVE re-applies every
  motion register, so a register already applied by an earlier HMOVE is cleared before the next
  one (Lesson 50 clears `HMBL`). Report `HmoveApply` (the WSYNC stall) and `HmoveDone` (the store,
  which executes at the next line's cycle 3).
- A multi-zone frame keeps the 192-line total: each zone states its line count and the total is
  checked in Session C.
- **1-line vs 2-line:** a 1-line kernel writes one byte per scanline (192 bytes/rows); a 2-line
  kernel writes one byte per two scanlines (96 rows). The 1-line budget is 76 cycles; the 2-line
  budget is 152 cycles across two lines. A 2-line kernel is the default for a full-screen game
  because 96 rows are cheap; a 1-line kernel buys vertical detail at twice the data and cycle
  cost.
- **Row-loop idiom (top-down):** a loop that draws N rows uses `LDY #0` and `INY; CPY #N; BNE`
  (Y=0..N−1, exactly N iterations). The table index equals the visible row: row 0 is the top of
  the screen, row N−1 the bottom. The tables are exactly N bytes/rows; there is no sentinel. A
  `DEY; BNE` down-counter would reverse the table and is not used. Every ledger below uses the
  forward form (INY 2 + CPY 2 + BNE 3 = 7 cycles per row, 4 on the last row).

### Logic and Timing Evidence

- Kernel claims: a breakpoint at the first row store reports the line/cycle and A; a breakpoint at
  the row counter reports the row. The static ledger sums the stores, the WSYNCs, the loop
  overhead, the taken branches, and the page crosses.
- Scroll claims: a breakpoint after `INC ScrollY` / `STA ScrollY` reports A; the world table's
  first byte is reported at `WorldRead`; two captures one frame apart measure the one-line step.
- Flicker claims: `Parity` A=0/1; `DrawSlot0`/`DrawSlot1` A = the object indices; the two captures
  are the two 30 Hz halves. A still image cannot prove the merged perception.
- Text claims: `TextFill` writes 48 bytes to `ScoreBuf`; `TextRow`/`TextCol` and `ScrollOffset`
  are logged; the captures show the letters and the shift.
- Zone claims: `ScoreDraw`, `StatusStart`, `PlayStart`, `GroundStart`, `OverscanStart` are
  labelled; the line arithmetic is checked in the state log.
- A screenshot never proves the logic or the timing; the committed ROM and the `<RomPlayer>` are
  the runnable artifact. The lesson documents say this, and tell the reader to click the player
  screen once: Javatari starts muted until a user gesture.

### Audio Beep

The state-changing lessons (48, 51, 53, 54, 55) carry a two-byte beep: `BeepTimer` and
`BeepPitch`. `BeepStart` writes `AUDC0=$0C`, `AUDF0=pitch`, `AUDV0=$0A`; every VBLANK decrements
`BeepTimer` and writes `AUDV0=0` at zero. The beep uses channel 0 only; no lesson uses
`include/sound.asm` (AR-21).

### RAM Map

| Range | Owner | Contents |
| --- | --- | --- |
| `$80–$83` | `include/kernel_patterns.asm` (Lesson 53 only) | `KernelPtr` (2), `KernelRows`, `KernelTmp` |
| `$84–$9F` | Lesson 53 lesson | counters (pattern, ramp direction, etc.) |
| `$A0–$CF` | Lesson 53 lesson | the 48-byte sprite strip |
| `$80–$9F` | lesson (except 53) | counters, positions, state, scroll, parity, beep |
| `$A0–$D7` | score library (Lessons 50 and 55 only) | `ScoreDigits` 6 + scratch 2 + `ScoreBuf` 48 |
| `$D8–$F7` | free | lesson overflow / future use |
| `$F8–$FF` | stack | `+clean_start` sets SP=$FF; keep call depth shallow |

A lesson never uses both the score library and the kernel-pattern library in the same source
unless it documents the split (Lesson 53 is the only library user; 50/55 use the score library).
Each lesson's source header repeats its exact map; `+clean_start` zeroes all of it.

### Lesson Document Template

Every lesson document follows the fixed six-section template (the Part 1–6 pattern):
frontmatter (`title`, `description`, `prev`, `next`), the meta block (Part, estimated time,
prerequisites, "You will learn", "You will build"), Introduction with a `::: details TypeScript
Equivalent` block, Theory, The Code (Building, Full Source **verbatim** from the `.asm`, Code
Walkthrough, checkpoint table), What You Should See (two images + `<RomPlayer>` + debugger
commands), Exercises (three, each with Challenge/Hints/Expected Result/Solution), Key Takeaways
(≤ 7), and What's Next. The TypeScript blocks mirror the lesson's mechanism:
- 48: a kernel-taxonomy selector and a row renderer.
- 49: a two-scanline loop and a row table.
- 50: a zone table with per-zone renderers.
- 51: a flicker scheduler and a draw-list sort.
- 52: a scroll offset and a world-table lookup.
- 53: a pattern library and a band builder.
- 54: an effects registry and a per-effect renderer.
- 55: a glyph atlas and a bitstream window.

### Shared Score Library (reused in Lessons 50 and 55)

- `ScoreDigits` = `$A0–$A5`; `ScoreRow`/`ScoreTmp` = `$A6–$A7`; `ScoreBuf` = `$A8–$D7`.
- `ScoreInit`, `ScoreSetup` (three-copy close, VDEL, P0=56/P1=64, one HMOVE), `ScoreSetDigit`,
  `ScoreAddOne`, `ScoreClear`, `ScoreDraw` (8 rows, 9 visible lines, WSYNC-first).
- `ScoreDraw` consumes 9 visible lines: line 0 is the setup/blank line, rows 1–8 draw, and the
  cleanup shares line 8. The caller's next code starts on visible line 9.
- The score's HMOVE also applies any ball/missile fine offsets set before `ScoreSetup`; Lesson 50
  uses that for the play ball.

### Shared Kernel-Pattern Library (`include/kernel_patterns.asm`, Lesson 53)

- Owns `$80/$81` = `KernelPtr`, `$82` = `KernelRows`, `$83` = `KernelTmp`.
- `KernelFill` — A = color, X = lines; fills the screen with `STA COLUBK` and one `WSYNC` per line.
- `KernelPFRows` — `KernelPtr` points at a table of 3 bytes per row; `KernelRows` = rows; draws
  two lines per row (a 2-line playfield block). The outer loop uses `KernelRows` and `DEC`/`BNE`;
  the Y register is only 2..0 for the three PF bytes, and the pointer advances by 3 per row.
- `KernelSpriteStrip` — `KernelPtr` points at a 1-byte-per-line strip; `KernelRows` = lines; draws
  it to `GRP0` with one `WSYNC` per line. The loop is `LDY #0; INY; CPY KernelRows; BNE`.
- `KernelColorRamp` — `KernelPtr` points at one color per line; `KernelRows` = lines; writes
  `COLUBK` and one `WSYNC` per line. The loop is the same forward form.
- The routines preserve X and Y unless their header says otherwise; the caller sets `KernelPtr`
  and `KernelRows` before each call.

## Lesson 48: Introduction to Kernels — The Heart of Every 2600 Game

- **Goal:** understand what a kernel is, the kernel taxonomy, and the 1-line/2-line trade-off.
- **Prerequisites:** Lesson 12 (the frame), Lesson 14 (`WSYNC` and timing), Lesson 17 (cycle
  counting), Lesson 18 (mid-scanline changes), Lesson 19 (the playfield), Lesson 25 (player
  graphics), Lesson 26 (positioning), Lesson 28 (the one-HMOVE rule), Lesson 29 (the ball),
  Lesson 31 (`NUSIZ`).
- **Concepts:** the kernel as the scanline-by-scanline picture; 1-line, 2-line, multi-zone,
  repositioning, and flicker archetypes; vertical position from *when* you write; the 76-cycle
  line; the 152-cycle two-line pair; the data-size/vertical-detail trade-off; five iconic kernels
  (Combat, Adventure, Pitfall!, River Raid, Cosmic Ark) and the design trade-off each shows.
- **ROM:** `demo-48.asm` — "the kernel zoo".
  - `Mode` 0 = split: visible 0–95 is a 1-line zone (96 rows), visible 96–191 is a 2-line zone
    (48 rows). The same diamond is drawn in both zones, 96 lines tall; the top is smooth, the
    bottom is chunky. A 1-line dash on P0 in the top zone and a 2-line dash on P1 in the bottom
    zone show the same 8-px sprite at both resolutions.
  - `Mode` 1 = full 1-line: 192 rows, the 96-row diamond table repeated twice; the 96-byte P0/P1
    strips are repeated twice.
  - `Mode` 2 = full 2-line: 96 rows, the 48-row diamond table repeated twice; the 48-byte strips
    are repeated twice.
  - Fire cycles the modes; the auto-demo cycles every 240 frames. SELECT resets to mode 0.
  - The diamond tables: three 96-byte planes (1-line, 288 bytes) and three 48-byte planes
    (2-line, 144 bytes), indexed by the top-down row counter; the full modes repeat the same
    planes twice (the full 1-line mode displays 192 rows, the full 2-line mode displays 96 rows).
    The planes are generated as data; the shape is a diamond with a 96-line height and a 96-px
    maximum width, centred. The split uses the full 96-row 1-line planes for the top and the full
    48-row 2-line planes for the bottom.
  - The 1-line dash is one byte tall (1 line); the 2-line dash is one byte per two lines (2
    lines). The dashes move horizontally with the joystick (clamp 8–144); with no input the
    auto-demo sweeps them so both captures are reachable without a key press.
  - The lesson's Theory section adds a short historical analysis of five iconic kernels — Combat
    (2-line), Adventure (data-driven rooms), Pitfall! (playfield/animation), River Raid
    (scrolling river), and Cosmic Ark (starfield) — with the design trade-off each one shows.
    The history is clearly marked as context; the demo does not reproduce the games.
  - Colors: top zone green `$C8`, bottom zone gold `$1A`, dashes white `$0E`, background `$02`.
- **Expected screen:** mode 0 shows a smooth green diamond in the top half and a chunky gold
  diamond in the bottom half, with a one-line white dash in the top and a two-line white dash in
  the bottom; mode 2 shows the whole screen in chunky gold.
- **Exercises:**
  1. **Three zones.** Split the screen into 64-line 1-line, 64-line 2-line, and 64-line 1-line
     zones; expected: 64+64+64 = 192, `ZoneCount` = 3, the middle zone chunky.
  2. **Rectangle, not diamond.** Replace the diamond table with a solid rectangle; expected:
     the 1-line zone shows crisp edges, the 2-line zone still steps in two-line blocks.
  3. *(Stretch)* **Mode 3: a multi-zone layout.** Add an 8-line header, a 176-line 2-line play
     area, and an 8-line footer; expected: 8+176+8 = 192, `Mode` = 3, `HeaderEnd` = 8.
- **Evidence pins:** `Mode` (A=0/1/2), `ZoneCount`, `LineCount` (96/192), `PairCount` (48/96),
  `LineRow`/`PairRow` (the row counters, 0→N−1), `BodyStart` 37, `OverscanStart` 229, `StartFrame`
  259.
- **Screenshots:** `docs/public/images/lesson48/split.png` (mode 0), `…/full-two-line.png`
  (mode 2).
- **Integration:** prev → Lesson 47; next → Lesson 49; part-index row 48 → ✅ Complete; the Part 7
  index rebuilt to the Part 1 format; sidebar entry exists (`config.ts:125`). Estimated time: 75
  minutes.

## Lesson 49: The 2-Line Kernel — Standard Game Pattern

- **Goal:** build a reusable 2-line kernel and understand why it is the standard game pattern.
- **Prerequisites:** Lesson 12 (the frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting),
  Lesson 18 (mid-scanline changes), Lesson 19 (the playfield), Lesson 20 (playfield colors),
  Lesson 25 (players), Lesson 26 (positioning), Lesson 28 (one HMOVE), Lesson 31 (`NUSIZ`),
  Lesson 48 (the taxonomy).
- **Concepts:** one data byte per two scanlines; 96 rows for 192 lines; the 152-cycle two-line
  budget; interleaving the next row's loads with the current row's stores; the page-cross and
  taken-branch costs; color ramps per row.
- **ROM:** `49-two-line-kernel.asm` — "the mountain pass".
  - 96 rows × 2 lines = 192. For each row `Y` the store order follows the pixel deadlines:
    `GRP0` (the figure), `PF0`, `PF1`, `COLUPF`, `PF2`, `COLUBK`, `GRP1` (the fixed bird at X=104),
    then two `WSYNC`s. The sprite goes first because a late `GRP0` would show the previous row's
    figure byte on the first scanline for any figure left of X≈82 (the store applies from pixel
    82). The steady-state stores are `PF0` 22 (2 px margin), `PF1` 29 (3 px; only the first `PF1`
    step, row 8, shows a notch), `COLUPF` 36 (~40 px), `PF2` 43 (~13 px), `COLUBK` 50 (~70 px at
    the top) and `GRP1` 57 (1 px). The late `PF1`/`PF2`/`COLUBK` stores can leave the previous
    value on the first scanline's left edge, which the doc measures (74/84 rows exact, 10 within
    one chunk) and discloses; the model's visible windows are row 8 and the `PF2` rows 42/48/54.
    The second scanline is always correct.
  - P0 is a 16-line figure (8 bytes × 2) at strip row 75 (visible 150–165); P1 is a 16-line bird
    at strip row 30 (visible 60–75) with a fixed left edge at X=104. The strip is indexed by the
    top-down row counter (`Y`), so `P0Strip+75` is the figure's first byte and `P0Strip+30` the
    bird's. The figure moves
    left/right with the joystick (clamp 8–144); with no input a 272-frame auto-demo sweeps it
    8→144→8 at one pixel per frame, so both captures are reachable without a key press. The bird
    is fixed.
  - The mountain is a silhouette: the PF bits are set for the mountain body; the sky is the
    background. The mountain color ramps from dark green `$C6` at the bottom to gray `$0A` at the
    top; the sky ramps from dark blue `$84` at the top to orange `$1A` at the horizon.
  - The cycle ledger: 3 PF loads/stores (7 each = 21), `COLUPF` 7, `COLUBK` 7, `GRP0` 7, `GRP1`
    7, two `WSYNC`s 6, `INY`/`CPY`/`BNE` 7 = **62 cycles nominal**; the loop's taken `BNE` crosses
    a page, so the **effective body is 63** (31.5/line). The two-line budget is 152, so the margin
    is 89 cycles per pair (44.5/line). The tables are page-aligned, so the indexed loads do not
    add a page cross.
- **Expected screen:** a chunky mountain range with a smooth sky gradient, a 16-line figure at the
  bottom, and a 16-line bird in the sky; the figure moves with the joystick.
- **Exercises:**
  1. **Unroll two rows.** Duplicate the row body inside the loop and use a 2-row iteration;
     expected: the same picture, four `WSYNC`s per iteration, `KernelRow` advances by 2, the
     ledger is **119 cycles per four lines** (two row bodies at 55 each plus the shared 9-cycle
     tail: two `INY`s, `CPY #96`, `BNE`).
  2. **Two-pixel figure.** Move the figure two pixels per frame instead of one, with the same
     clamp; expected: `P0X` changes by 2, the picture is stable, `HmoveDone` once per frame.
  3. *(Stretch)* **Three copies.** Set `NUSIZ0=3` so the figure appears three times at X, X+16,
     X+32, and clamp X to 8–120 so all three copies stay on screen; expected: three 16-line
     figures, the bird still on P1, the same 96-row kernel.
- **Evidence pins:** `KernelRow` (Y=0→95 with `LDY #0; INY; CPY #96; BNE`), `RowWrite` (the first row), `P0X`,
  `P1X`, `HmoveApply`/`HmoveDone`, `BodyStart` 37, `OverscanStart` 229, `StartFrame` 259.
- **Screenshots:** `docs/public/images/lesson49/landscape.png` (figure left),
  `…/figure-right.png` (figure right).
- **Integration:** prev → Lesson 48; next → Lesson 50; index row 49 → ✅ Complete; sidebar
  `config.ts:126`. Estimated time: 75 minutes.

## Lesson 50: Multi-Zone Kernel — Scoreboard + Playfield + Sprites

- **Goal:** divide the screen into fixed zones, each with its own kernel, and keep the line and
  cycle budgets exact.
- **Prerequisites:** Lesson 12 (the frame), Lesson 14 (`WSYNC`), Lesson 15 (the timer), Lesson 17
  (cycle counting), Lesson 18 (mid-scanline changes), Lesson 19 (the playfield), Lesson 26
  (positioning), Lesson 28 (one HMOVE), Lesson 29 (the ball), Lesson 31 (`NUSIZ`), Lesson 38
  (collision latches), Lesson 39 (`include/score.asm`), Lesson 41 (game states), Lesson 49 (the
  2-line kernel).
- **Concepts:** zone boundaries and line budgets; different kernels per zone; the score library's
  9-line zone; reusing P0/P1 in the score then the game; a second HMOVE in the status HBLANK; the
  ball's fine offset applied by the score's HMOVE; the one-frame collision latency.
- **ROM:** `50-multi-zone-kernel.asm` — "the dashboard".
  - Visible 0–8: the score zone (9 lines) via `ScoreSetup`/`ScoreDraw`; the score starts 000000.
  - Visible 9–16: the status zone (8 lines): a mirrored pair of 15-chunk gold level bars (one per
    half); `Level` 0–15; every 120 frames `Level++` (cap 15); the bar fills.
  - Visible 17–190: the play zone (174 lines = 87 rows × 2). A 2-line kernel writes the floor and
    ceiling playfield, P0 (16 kernel rows = 32 scanlines) at the bottom, P1 (16 kernel rows) at
    the top, and the ball (8 lines, four 2-line rows).
    P0 moves left/right with the joystick; P1 sweeps; the ball falls from Y=24 to Y=158 (its top
    visible row; the 8-line ball is four 2-line rows and ends at 165, inside the 174-line zone).
    `CXP0FB` bit 6 (P0–ball) adds
    one via `ScoreAddOne`, beeps, and respawns the ball; read in VBLANK, then `CXCLR`.
  - Visible 191: the ground line (1 line), a solid dark green.
  - The zone arithmetic: 9 + 8 + 174 + 1 = 192.
  - The HMOVEs: the score's `ScoreSetup` HMOVE (`ScoreHmove`) in VBLANK applies P0/P1 at 56/64 and
    the ball's fine offset (`RESBL`/`HMBL`, set before `ScoreSetup`); after `ScoreDraw`, the status zone repositions
    P0/P1 for the game (`NUSIZ0=NUSIZ1=0`, one copy) and applies a second HMOVE (`GameHmove`) in
    the status HBLANK. An HMOVE re-applies every motion register, so `HMBL` is cleared after
    `ScoreHmove` and before `GameHmove`; the ball keeps the position `ScoreHmove` gave it and is
    not shifted twice. The status bar starts at chunk 2, so the HMOVE's left-edge blanking is an
    eight-pixel black notch at chunks 0–1; no bar chunk is lost.
  - The auto-demo moves P0 under the ball when there is no input, so the score climbs.
- **Expected screen:** a six-digit score at the top, a gold level bar, a play area with a red
  player at the bottom, a green enemy at the top, and a gold ball; the score and the bar advance.
- **Exercises:**
  1. **Resize the status zone.** Make the status 12 lines and the play 170 lines (85 rows × 2);
     expected: 9+12+170+1 = 192, `StatusStart` 46, `PlayStart` 58, `GroundStart` 228.
  2. **Add a second status row.** Add an 8-line timer bar; status 16, play 166 (83 rows × 2);
     expected: 9+16+166+1 = 192, `StatusStart` 46, `PlayStart` 62, `GroundStart` 228.
  3. *(Stretch)* **Zone budget audit.** Add a `ZoneTable` and ACME `!if`/`!error` asserts that the
     zone lines total 192; expected: the build passes, a wrong total fails with a clear error.
- **Evidence pins:** `ScoreDraw`, `StatusStart`, `PlayStart`, `GroundStart`, `ScoreHmove`,
  `GameHmove`, `ScoreAdd` (A = the low digit), `LevelWrite`, `BallY`, `BodyStart` 37,
  `OverscanStart` 229, `StartFrame` 259; the play loop uses `LDY #0; INY; CPY #87; BNE` for 87 rows.
- **Screenshots:** `docs/public/images/lesson50/dashboard.png` (score 000001, level 1),
  `…/level4.png` (score 000004, level 4).
- **Integration:** prev → Lesson 49; next → Lesson 51; index row 50 → ✅ Complete; sidebar
  `config.ts:127`. Estimated time: 90 minutes.

## Lesson 51: Flicker Sprites — More Than 2 Objects

- **Goal:** draw more objects than the TIA provides by alternating two 30 Hz frames, with the
  selected objects drawn by a per-row skipdraw test (no RAM strips).
- **Prerequisites:** Lesson 12 (the frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting),
  Lesson 18 (mid-scanline changes), Lesson 25 (players), Lesson 26 (positioning), Lesson 27
  (sprite movement), Lesson 28 (one HMOVE), Lesson 29 (the ball), Lesson 31 (`NUSIZ`), Lesson 34
  (frame counters), Lesson 49 (the 2-line kernel).
- **Concepts:** 30 Hz flicker; two players × two frames = four objects; parity; the draw-list
  sort; the skipdraw test (`row - ObjRow`, compare, mask) inside a 2-line kernel; the eye's
  persistence; why a still image shows only one half. The lesson uses the 2-line budget (152
  cycles per pair) because two branchy skipdraw tests do not fit a 76-cycle line.
- **ROM:** `51-flicker-sprites.asm` — "the flicker gallery".
  - Visible 0–7: the status zone (8 lines): a parity cell and four object cells (2 chunks each,
    per half); the cells show which objects are drawn this frame.
  - Visible 8–191: the play zone (184 lines = 92 rows × 2) drawn by a 2-line kernel. Four objects
    (X, Y, DirX, DirY, Color, Shape) move ±1 per frame and bounce at X 8–144, Y 0–88 (relative
    to the play zone). Each object is 8 lines tall (4 bytes, two lines per byte). Parity 0 draws
    objects 0/1; parity 1 draws 2/3. Y is top-down, so the **larger** Y is nearer the bottom; the
    nearer object of a parity pair is drawn on P0, the other on P1.
  - The kernel loop is `LDY #0`; the first line draws object 0 (`TYA; SEC; SBC ObjRow0; CMP #4;
    BCS No0; ... LDA ShapeTable,X; STA GRP0; STA WSYNC`); the second line draws object 1 the same
    way (`STA GRP1; STA WSYNC`); then `INY; CPY #92; BNE`. The two lines each carry one skipdraw
    (about 43 cycles including the WSYNC), well inside 76; the pair is about 93, inside 152. The
    shape table is 4 shapes × 4 bytes = 16 bytes. The object's row is 0–88 (top-down); the
    4-byte shape covers rows Y..Y+3 (8 lines).
  - The cycle ledger: each line carries one in-sprite skipdraw (~40) plus its `WSYNC` (3), so
the first and second lines are ~43 each; the pair is ~86 plus the 7-cycle loop tail = **~93
cycles per two lines** (46.5/line), 59 cycles of margin per pair. The branchy skipdraw is the
lesson's subject; splitting it across the two lines keeps each line inside 76.
  - No 184-byte strips and no 368-byte RAM: the only state is the four objects' X/Y/dir/color/
    shape bytes and the two selected slot bytes, all inside `$80–$9F`.
  - The VBLANK: select the parity pair; copy the two objects' row/shape/colour into the slot
    bytes; set P0/P1 X with two coarse resets and one HMOVE.
  - Colors: red `$42`, green `$C8`, blue `$84`, gold `$1A`; background `$02`.
- **Expected screen:** two of the four colorful ships are visible in each frame; the status cells
  show the parity and the two drawn objects. The two captures are the two halves.
- **Exercises:**
  1. **Reverse priority.** Draw the farther (smaller Y) object of each parity pair on P0 instead
     of the nearer one; expected: `SortFirst` A = the farther object, the draw list order, the
     captures.
  2. **Three-frame flicker.** Add two more objects (six total) and cycle parity 0/1/2; expected:
     `Parity` 0/1/2, two objects per frame, six status cells, the eye sees six at 20 Hz.
  3. *(Stretch)* **Always-on player.** Draw the player's ship on P0 every frame and flicker three
     enemies on P1; expected: P0 always visible, `AlwaysSlot` = 0, the three enemies alternate.
- **Evidence pins:** `Parity` (A=0/1), `DrawSlot0`/`DrawSlot1` (A=object index), `ObjRow0`/
  `ObjRow1`, `ObjShape0`/`ObjShape1`, `SkipWrite` (A = the shape byte or 0), `HmoveApply`/
  `HmoveDone`, `BodyStart` 37, `OverscanStart` 229, `StartFrame` 259; the play loop uses
  `LDY #0; INY; CPY #92; BNE` for 92 rows. The base uses `$80–$9F`: four objects × 6 bytes, two
  slots × 2 bytes (row/shape; the colours go straight to `COLUP0/1`), parity, beep, frame = 32
  bytes; exercise 2 puts the two extra objects in `$D8–$F7`.
- **Screenshots:** `docs/public/images/lesson51/frame-a.png` (parity 0, objects 0/1),
  `…/frame-b.png` (parity 1, objects 2/3).
- **Integration:** prev → Lesson 50; next → Lesson 52; index row 51 → ✅ Complete; sidebar
  `config.ts:128`. Estimated time: 90 minutes.

## Lesson 52: Fine Scrolling — Smooth Movement

- **Goal:** scroll a world smoothly and move a sprite one pixel at a time, and explain the
  hardware's playfield/sprite resolution split.
- **Prerequisites:** Lesson 12 (the frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting),
  Lesson 18 (mid-scanline changes), Lesson 19 (the playfield), Lesson 26 (positioning), Lesson 27
  (sprite movement), Lesson 28 (one HMOVE), Lesson 29 (the ball), Lesson 31 (`NUSIZ`), Lesson 34
  (frame counters), Lesson 48 (the 1-line kernel).
- **Concepts:** vertical scrolling one line at a time; three 256-byte playfield planes indexed by
  `ScrollY`; the 1-line kernel's 40-cycle loop; the 4-px playfield vs the 1-px HMOVE sprite; the
  tunnel's width breathing (the gap narrows and widens over the scroll); the 256-row loop.
- **ROM:** `52-fine-scrolling.asm` — "the tunnel".
  - 192 lines, 1-line kernel. Three 256-byte planes (`WorldPF0`, `WorldPF1`, `WorldPF2`) draw a
    symmetric, reflected tunnel: the gap is centred and its width follows a 32-row sine
    (6..10 chunks of 20). `ScrollY` increments one per frame (0–255); the world loops every 256
    lines, and the 32-row period divides 256, so row 255 and row 0 join cleanly.
  - The kernel: `LDX ScrollY; LDY #0; loop: LDA WorldPF0,X; STA PF0; LDA WorldPF1,X; STA PF1;
    LDA WorldPF2,X; STA PF2; LDA ShipStrip,Y; STA GRP0; STA WSYNC; INX; INY; CPY #192; BNE` =
    **40 cycles/line** (3 PF load/store pairs 21, GRP0 7, WSYNC 3, INX 2, INY 2, CPY 2, BNE 3).
    Each 256-byte plane is page-aligned (`!align 255,0`), so the `X` wrap 255→0 stays inside the
    plane and there is no page cross. The three planes are indexed by the same X, so each row is
    three independent bytes, not a row-major triple.
  - The ship: a **16-byte** strip (16 lines, one byte per line) in a 192-byte strip at rows
    150–165; `ShipX` moves one pixel per frame with the divide-by-15 + HMOVE dance; clamp 24–136.
    The joystick left/right overrides the auto-demo; with no input the ship sweeps 24→136→24.
  - The playfield is 4-px per bit (`CTRLPF=$01` reflects the 20-bit half); the ship is a 1-px
    object moved by HMOVE. The lesson's "fine" motion is the ship; the world scrolls one line at
    a time. The tunnel's width breathing is the horizontal variation; the doc states plainly that
    a 3-byte playfield row is symmetric under reflect and cannot snake sideways.
- **Expected screen:** a green tunnel of walls with a dark central gap that narrows and widens as
  it scrolls upward one line per frame; a white 16-line ship slides one pixel per frame along the
  bottom.
- **Exercises:**
  1. **Reverse the scroll.** Decrement `ScrollY`; expected: the tunnel scrolls down, `ScrollY`
     counts down, the kernel unchanged.
  2. **Faster scroll.** Add two to `ScrollY` per frame; expected: `ScrollStep` A=2, the tunnel
     moves two lines per frame.
  3. *(Stretch)* **Half-speed ship.** Move the ship one pixel every two frames; expected:
     `ShipStep` alternates 0/1, the ship moves smoothly slower.
- **Evidence pins:** `ScrollY` (A), `ScrollStep`, `WorldRead` (A = the first `WorldPF0` byte),
  `ShipX`, `HmoveApply`/`HmoveDone`, `BodyStart` 37, `OverscanStart` 229, `StartFrame` 259; the
  kernel loop uses `LDY #0; INY; CPY #192; BNE` for 192 top-down rows (0..191), and a ScrollY
  255→0 wrap keeps the planes aligned.
- **Screenshots:** `docs/public/images/lesson52/tunnel-a.png` (ScrollY 0),
  `…/tunnel-b.png` (ScrollY 40; the ship at a different X).
- **Integration:** prev → Lesson 51; next → Lesson 53; index row 52 → ✅ Complete; sidebar
  `config.ts:129`. Estimated time: 90 minutes.

## Lesson 53: Kernel Design Patterns — Building Your Toolkit

- **Goal:** package the common kernel shapes as reusable routines and combine them into a
  four-band sampler.
- **Prerequisites:** Lesson 11 (lookup tables), Lesson 12 (the frame), Lesson 14 (`WSYNC`),
  Lesson 17 (cycle counting), Lesson 18 (mid-scanline changes), Lesson 19 (the playfield),
  Lesson 25 (players), Lesson 26 (positioning), Lesson 28 (one HMOVE), Lesson 29 (the ball),
  Lesson 48 (the taxonomy), Lesson 49 (the 2-line kernel).
- **Concepts:** reusable kernel building blocks; a zero-page pointer API; the fill, PF-row,
  sprite-strip, and color-ramp patterns; a band table; the register contract (each band boundary
  clears PF0–PF2 and GRP0/GRP1); the cycle ledger per routine; combining patterns without hidden
  state.
- **ROM:** `53-kernel-patterns.asm` — "the pattern sampler".
  - Four 48-line bands = 192:
    1. `KernelFill`: a solid teal band (48 lines).
    2. `KernelPFRows`: a 24-row stripe/checkerboard (2 lines per row = 48 lines).
    3. `KernelSpriteStrip`: a 48-line dark band with a moving 8-line sprite on P0.
    4. `KernelColorRamp`: a 48-line red-to-blue gradient.
  - The library `include/kernel_patterns.asm` provides the four routines and owns `$80–$83`; the
    lesson uses `$84–$9F` for counters and `$A0–$CF` for the 48-byte sprite strip, leaving
    `$D0–$F7` free.
  - The band boundary clears `PF0/PF1/PF2`, `GRP0`, and `GRP1`; the routines write only their own
    object and do not clear another band's state.
  - Fire cycles the palette (fill color, PF color, sprite color, ramp direction); SELECT resets;
    the auto-demo cycles every 240 frames.
  - The sprite band's strip is 48 bytes; the sprite's 8 bytes are stamped at a moving row
    **clamped 1–40** so the 8-byte shape never writes past the 48-byte strip (row 0 is left
    blank); the strip is rebuilt each frame; P0's X is set in VBLANK with one HMOVE.
  - The cycle ledgers: `KernelFill` 11/line (`DEX` 2 + `BNE` 3 + `STA COLUBK` 3 + `STA WSYNC` 3,
    with X=N..1); `KernelPFRows` ~28/line (Y=2..0 loads three `(Ptr),Y` bytes at 5 + 3 each =
    24, `LDY #2`/two `DEY`s 6, the 16-bit pointer advance ~13, two `WSYNC`s 6, `DEC KernelRows`
    5, `BNE` 3 per row ≈ 57/2 lines); `KernelSpriteStrip` 19/line (`LDA (Ptr),Y` 5 + `STA GRP0`
    3 + `WSYNC` 3 + `INY` 2 + `CPY KernelRows` 3 + `BNE` 3); `KernelColorRamp` 19/line (the
    same with `STA COLUBK`). The `KernelPFRows` outer loop decrements `KernelRows`; the Y
    register only selects the three PF bytes.
- **Expected screen:** four distinct horizontal bands: a solid color, a striped playfield, a
  moving sprite on a dark band, and a smooth gradient; the palette changes with fire.
- **Exercises:**
  1. **Add a fifth pattern.** Split the sampler into 38+38+38+38+40 lines and add a `KernelFill`
     band; expected: five bands, total 192, `PatternCount` = 5.
  2. **Ramp offset.** Shift the color-ramp table by 24 lines with SELECT; expected: `RampPhase`
     0/24, the gradient rotates.
  3. *(Stretch)* **Reorder the bands.** Add a `PatternOrder` table and a loop; expected: the same
     routines in a different order, `PatternOrder` documented, the build passes.
- **Evidence pins:** `PatternStart` (A=band index), `PatternCount`, `KernelRows`, `KernelPtr`,
  `PatternWrite` (the first band), `BodyStart` 37, `OverscanStart` 229, `StartFrame` 259.
- **Screenshots:** `docs/public/images/lesson53/sampler.png` (default palette),
  `…/palette.png` (fire changed the palette).
- **Integration:** prev → Lesson 52; next → Lesson 54; index row 53 → ✅ Complete; sidebar
  `config.ts:130`; `include/kernel_patterns.asm` created. Estimated time: 90 minutes.

## Lesson 54: Visual Effects Cookbook — Starfields, Rainbows, Pseudo-3D

- **Goal:** build three reusable visual effects and understand the kernel cost of each.
- **Prerequisites:** Lesson 12 (the frame), Lesson 13 (colors), Lesson 14 (`WSYNC`), Lesson 17
  (cycle counting), Lesson 18 (mid-scanline changes), Lesson 19 (the playfield), Lesson 20
  (playfield colors), Lesson 24 (multicolor playfield), Lesson 25 (players), Lesson 26
  (positioning), Lesson 28 (one HMOVE), Lesson 29 (the ball), Lesson 31 (`NUSIZ`), Lesson 48 (the
  taxonomy), Lesson 52 (the scroll).
- **Concepts:** a starfield from a sparse playfield table; a full-screen color ramp; a per-line
  pseudo-3D road (a centred road whose width grows toward the bottom); an effects registry; the
  per-effect cycle budget; the difference between a static table effect and a moving one. The
  road is symmetric under reflect, so the road's *width* changes, not its centre; the doc says so.
- **ROM:** `54-visual-effects-cookbook.asm` — "the effects reel".
  - `Effect` 0 = starfield: three 256-byte star planes (768 bytes) scrolled one line every two
    frames (`StarScroll`); a 16-byte ship strip on P0 at the bottom; the ball and the two missiles
    add three bright stars at fixed positions; the whole starfield's colour alternates between
    white `$0E` and gold `$1A` every 32 frames (`Twinkle`). The stub's "starfield with missiles"
    is satisfied by the two missile stars and the ball star.
  - `Effect` 1 = rainbow: a 192-byte color ramp (`Rainbow`) written to `COLUBK` one line per
    line; a playfield sun block (a centred 32-px block at rows 40–88) and a black horizon at the
    bottom; `RainbowShift` every 4 frames.
  - `Effect` 2 = pseudo-3D road: 192 rows of per-line `PF0/PF1/PF2` (576 bytes); the road is
    centred and its width grows from 4 chunks at the horizon to 16 chunks at the bottom; the
    width also breathes with a slow 64-row table (`WidthIndex`). A 16-byte car strip on P0 at the
    bottom. The doc states that the 3-byte reflected playfield cannot move the road centre; the
    "3D" is the width/depth table.
  - `EffectTimer` 240 frames; at zero `Effect++` (0→1→2→0) and the timer reloads; fire advances;
    SELECT resets to effect 0.
  - The cycle ledgers: starfield 40/line (3 PF pairs 21 + P0 7 + WSYNC 3 + INX 2 + INY 2 + CPY 2
    + BNE 3); rainbow 18/line (LDA 5 + STA COLUBK 3 + WSYNC 3 + INY 2 + CPY 2 + BNE 3); road
    40/line (the starfield shape). The starfield planes are page-aligned for the X wrap.
- **Expected screen:** a scrolling starfield with a ship; a full-screen rainbow with a sun; a
  road rushing toward the horizon with a car. The captures show the starfield and the road; the
  doc describes the rainbow.
- **Exercises:**
  1. **Per-star twinkle.** Add a twinkle mask to the star planes so some stars disappear every
     16 frames; expected: `TwinkleMask` toggles, some stars go dark, the rest stay.
  2. **Rainbow speed.** Shift the rainbow table index every 2 frames (the base is 4); expected:
     `RainbowShift` advances twice as fast, the colors move faster.
  3. *(Stretch)* **Centre line.** Add a 1-px ball centre line that scrolls with the road;
     expected: `CenterLine` moves, the road stays centred and the line follows the width.
- **Evidence pins:** `Effect` (A=0/1/2), `EffectTimer`, `StarScroll`, `RainbowShift`, `RoadScroll`,
  `WidthIndex`, `Twinkle`, `BodyStart` 37, `OverscanStart` 229, `StartFrame` 259.
- **Screenshots:** `docs/public/images/lesson54/starfield.png`,
  `…/road.png`.
- **Integration:** prev → Lesson 53; next → Lesson 55; index row 54 → ✅ Complete; sidebar
  `config.ts:131`. Estimated time: 120 minutes.

## Lesson 55: Scrolling Text Marquee — The Activision Logo Effect

- **Goal:** turn the 48-pixel score kernel into a reusable text display and scroll a message one
  pixel at a time.
- **Prerequisites:** Lesson 11 (lookup tables), Lesson 12 (the frame), Lesson 14 (`WSYNC`),
  Lesson 17 (cycle counting), Lesson 18 (mid-scanline changes), Lesson 25 (players), Lesson 26
  (positioning), Lesson 28 (one HMOVE), Lesson 31 (`NUSIZ`), Lesson 32 (VDEL), Lesson 39 (the
  48-pixel kernel and `include/score.asm`), Lesson 48 (the taxonomy).
- **Concepts:** an 8×8 glyph atlas; a bitstream window; pre-shifted phases for 1-px scrolling;
  the 48-pixel kernel's column-major `ScoreBuf`; the 6-character window; the message loop; the
  starfield background; the history of the Activision logo (a short, clearly historical note).
- **ROM:** `55-scrolling-text-marquee.asm` — "the marquee".
  - Visible 0–8: the text zone (9 lines) via `ScoreSetup`/`ScoreDraw`; six 8-px columns at TIA
    X=56–103. `ScoreBuf` is filled from a pre-shifted table: 8 phases × 8 rows × 18 bytes; the
    message "RACING THE BEAM  " (17 chars); `ScrollOffset` 0–88, one pixel every two frames.
  - Visible 9–191: a 183-line starfield (three 183-byte planes) drawn by a 1-line kernel; a 1-px
    ball shooting star moves down one line per frame; the stars are white `$0E`/gold `$1A`.
  - The text fill: `Phase = ScrollOffset & 7`, `ByteIndex = ScrollOffset >> 3`; a phase pointer
    table selects one of the eight 144-byte blocks; for each row r and column c, the byte is
    `Shifted[phase][r][byteIndex+c]`, stored at **`ScoreBuf + c*8 + r`** (column-major, not a
    contiguous 48-byte copy). That is 8 rows × 6 columns = 48 stores.
  - The font: 39 glyphs (A–Z, 0–9, space, dash, period), 8 bytes each, bottom-up; the glyph is
    5×7 in an 8×8 cell, bit 7 = the leftmost pixel. The bottom row is blank, so the lit block is
    seven rows (y≈110–130).
  - The text starts at "RACING" (offset 0); at offset 40 the window is "G THE ".
  - The auto-demo scrolls; SELECT resets to offset 0; fire pauses/resumes.
  - The Activision note is a short historical sidebar (the logo was a scrolling graphic, not a
    full-screen text engine); it is marked as historical context, not a bit-exact reproduction.
- **Expected screen:** a white six-character text banner at the top, scrolling smoothly left; a
  starfield below with a shooting star. The two captures show the banner at two offsets. The
  48-px cell block is capture x=361–643; the lit glyph pixels measure x≈367–642, y≈110–130.
- **Exercises:**
  1. **Change the message.** Replace it with "KERNEL MASTERY" (14 chars); expected: the banner
     scrolls the new message, `MessageLen` = 14, and the wrap is `MessageLen*8 - 48` = 64 (not 88).
  2. **Double-speed scroll.** Increment the offset every frame; expected: `ScrollOffset` advances
     one per frame, the loop time halves.
  3. *(Stretch)* **Second line.** Add a second 9-line text band at visible 96–104 with a different
     message; expected: two bands, each 9 lines, `TextRow2`, and the starfield shrinks to 174
     lines (9 + 87 + 9 + 87 = 192). The second message is filled into `ScoreBuf` during the 87-line
     gap between the bands, so no second 48-byte buffer is needed. The second `ScoreSetup` runs at
     visible 93–95 (three `WSYNC` lines) and `ScoreDraw` starts at visible 96, because the first
     `ScoreDraw`'s cleanup clears VDEL; the second HMOVE is measured. The second band's 9 lines
     are 96–104, and the lower starfield is 105–191.
- **Evidence pins:** `ScrollOffset` (A), `TextRow` (0–7), `TextCol` (0–5), `TextFill` (the first
  byte), `ScoreDraw`, `HmoveApply`/`HmoveDone`, `BodyStart` 37, `OverscanStart` 229, `StartFrame`
  259; `ScoreBuf` stores follow the `c*8+r` stride.
- **Screenshots:** `docs/public/images/lesson55/marquee-a.png` (offset 0, "RACING"),
  `…/marquee-b.png` (offset 40, "G THE ").
- **Integration:** prev → Lesson 54; next → `/part8-advanced/56-bankswitching`; index row 55 →
  ✅ Complete; sidebar `config.ts:132`. Estimated time: 120 minutes.

## Cross-Lesson Consistency

- **Progression:** 48 introduces the taxonomy and the 1-line/2-line shapes; 49 builds the 2-line
  kernel; 50 adds multi-zone and reuses the score; 51 adds flicker; 52 adds scrolling; 53 packages
  the patterns; 54 applies them to effects; 55 reuses the 48-pixel kernel for text. No lesson uses
  a later lesson's mechanism in code.
- **Naming:** main sources are `NN-slug.asm`; solutions are `exercise-01-solution.asm` …
  `exercise-03-solution.asm`; Lesson 48's main is `demo-48.asm`.
- **Visual language:** the same 8-line status row, 15-cell bar, one-HMOVE positioning, and `$02`
  background recur where they fit.
- **Logic honesty:** every kernel/scroll/flicker/text/zone claim cites the checkpoint and the
  measured value; screenshots are never described as proof of timing.
- **Part 7 index:** rows 48–55 with What You'll Learn summaries; row 48 flips in Phase 1 and rows
  49–55 start `🔒 Coming Soon` and flip in their own lesson commits (AR-10).
