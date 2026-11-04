# Lesson Specifications: Part 4 — Sprites (Lessons 25–34)

> **Document**: 03-lesson-specs.md
> **Parent**: [Index](00-index.md)

This is the design authority for the ten Part 4 lessons. Each section fixes the lesson's
structure (sprite, rows, colors, positions, cadence, write cycles) so Session A can freeze
concrete ST expectations ([07-testing-strategy.md](07-testing-strategy.md)); the author derives
every claim and cycle ledger from these designs, and any deviation is a specification change, not
a freedom of implementation.

## Shared design rules (apply to every lesson)

- **Frame skeleton continuity:** `!cpu 6502` + `include/vcs.asm` + `include/macro.asm`, origin
  `* = $F000`, `Reset` calling `+clean_start`, `+vsync` (3 lines), VBLANK on with `+set_timer 44`
  (37 lines), `+wait_timer`, release, visible kernel, `STA WSYNC` before the overscan blank-on,
  `+set_timer 36` (30 lines), `+wait_timer`, `JMP` to the frame top, vectors at `$FFFA`.
- **The frame is 262 lines** (3 + 37 + 192 + 30). The release's first visible line is Stella
  scanline 37; the overscan blank-on lands in line 229's HBLANK.
- **Sprite geometry:** a player is 8 pixels wide; `GRP0`/`GRP1` bit 7 is the leftmost pixel. In
  the captures one TIA color clock is 6 pixels, so a player spans 48 capture pixels, and a
  sprite at TIA X appears at capture **x = 25 + 6·X**. The picture spans capture x = 25–984 and
  rows 107–711 (192 lines); scanline *s* maps to capture y ≈ 107 + 3.151·(*s* − 37). These
  mappings are stated once here and cited by every lesson.
- **Vertical rendering:** counted top/body/bottom loops (AR-14). The top loop parks `TOP` lines
  starting with line 37; the body's first write happens on scanline **37 + TOP**. The body writes
  the graphic then `WSYNC`; the write's effect begins at the next instruction's cycle (Lesson 18's
  rule). Sprites are placed at X ≥ 24 so the body's writes always precede their pixels.
- **Horizontal positioning:** the classic divide-by-15 `SetHorizPos` routine (AR-13) is used from
  Lesson 26 on. The requested X is pinned here; the **measured** X is recorded in Session C and
  must be within ±3 pixels of the request. Lesson 25 uses a fixed coarse delay instead (the
  routine is Lesson 26's subject) and pins its measured X with a ±4 tolerance.
- **Multiple objects (AR-21):** in Lessons 28, 29, and 33 every object's coarse `RESxx` and every
  `HMxx` value are set first, then **one** `HMOVE` applies them; the HM registers are rewritten
  every frame, so no stale fine motion is re-applied. Single-object lessons (26, 27) use the
  classic routine with its own `HMOVE`.
- **Colors follow Lesson 13's palette byte** (`%HHHHLLL0`, hue × 16 + level × 2) and the course's
  named-color table. Established names: `$02` dark neutral, `$1A` gold, `$42` red, `$84` blue,
  `$C8` green, `$0E` light gray.
- **Forward mentions are name-only** (later techniques: flicker multiplexing, the 48-pixel trick,
  full games); lesson code, exercises, and solutions use only mechanisms taught by that lesson or
  earlier (AR-9).
- **No standalone demo ROMs** (AR-3): each main ROM is the concept made visible; the reason is
  stated per lesson.
- The document's embedded listing is byte-identical to the `.asm` file; Key Takeaways ≤ 7 bullets;
  the document uses the fixed lesson template (frontmatter, meta block, TypeScript equivalent,
  theory, code walkthrough, screenshots + `RomPlayer`, exercises, takeaways, what's next).
- **Every exercise solution assembles and runs**; each has three solutions, the third marked
  *(Stretch Goal)* where it is materially harder.

---

## Lesson 25: Player Sprite Basics — GRP0, Your First Character

- **Goal:** draw the first player sprite and understand that a sprite is 8 bits wide and one
  scanline tall per write.
- **Concepts:** `GRP0` bit 7 leftmost; a sprite's height is the number of lines you write it; its
  vertical position is *when* you write it; `COLUP0` colors player 0; the rest of the screen is
  `COLUBK` while the playfield registers are zero; a shape is a byte table.
- **ROM:** `25-player-basics.asm` — "first contact": one player 0, 8 rows tall, the classic
  invader shape `$18,$3C,$7E,$DB,$FF,$24,$5A,$A5`; `COLUP0=$42` (red), `COLUBK=$02`; `NUSIZ0=0`,
  `REFP0=0`. The sprite is placed by a **fixed coarse delay** (after `STA WSYNC`, a `LDX #9` /
  `DEX` / `BNE` pad, then `STA RESP0`; `HMP0=0`), explicitly marked as a placeholder for Lesson 26.
  `SPRITE_TOP=80` → the first body line is scanline 117.
- **Expected screen:** a red 8×8 invader, 48 capture pixels wide and about 25 capture pixels
  tall, at capture x ≈ 511 and rows ≈ 359–384 (the measured X and Y are recorded in Session C;
  target X ≈ 81, tolerance ±4). Constant for the whole frame. Background dark.
- **Demo ROM:** none — the first sprite is the visible picture (AR-3).
- **Exercises:** 1. move the sprite down (`SPRITE_TOP=120` → first line ≈ 485 capture y);
  2. mirror it (`REFP0=$08`) — the shape flips, same span; 3. *(Stretch)* two creatures: after the
  first 8-row body, 32 blank lines, then a second copy of the body loop (same player, reused
  vertically) — the second creature is 40 scanlines below the first.
- **Screenshots:** `docs/public/images/lesson25/first-sprite.png`.
- **Evidence pins (AR-6):** frame checkpoints (`StartFrame` 259, `VblankStart` 0,
  `VisibleStart` 37, `OverscanStart` 229); `BodyStart` — the first body line, 117, cycle 6,
  8 hits per frame; `SpriteWrite` — one hit per body line with A = the shape byte; the measured
  sprite X from the capture. The fixed-delay `RESP0` store's cycle is recorded.
- **Integration:** prev → Lesson 24; next → Lesson 26; part-index row 25 → ✅ Complete linking
  `./25-player-basics`; sidebar entry exists (`config.ts:84`). Estimated time: 60 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 25): ST-25.1 assembly &
  drift · ST-25.2 frame and sprite geometry · ST-25.3 shape/color · ST-25.4 debugger state ·
  ST-25.5 solutions and screenshot · ST-25.6 site integration.

## Lesson 26: Horizontal Positioning — The Divide-by-15 Trick

- **Goal:** place a player at an exact horizontal position with `RESP0` plus `HMP0`/`HMOVE`, and
  understand the divide-by-15 routine.
- **Concepts:** `RESP0` strobes the player's position counter to the current beam position;
  `HMP0`'s high nibble is signed fine motion (−8…+7), applied by `HMOVE` in HBLANK; each `SBC #15`
  iteration costs 5 cycles = 15 color clocks; `EOR #7` turns the undershoot into the fine value;
  negative moves right; `HMOVE` in HBLANK blanks the leftmost 8 pixels of that line.
- **ROM:** `26-horizontal-positioning.asm` — "the tour": the Lesson 25 invader, top 80, moving
  through five X targets — **16, 48, 80, 112, 144** — one per 60 frames, wrapping. `SetHorizPos`
  is called in VBLANK each frame; `COLUP0=$42`, `COLUBK=$02`. The target table is five bytes.
- **Expected screen:** the red invader at the requested X ±3, i.e. capture x ≈ 121 / 313 / 505 /
  697 / 889; the sprite stays at rows ≈ 359–384. Two captures at different times show two
  different positions (the measured positions are labelled in the captions).
- **Demo ROM:** none — the moving sprite among five positions is the visible picture (AR-3).
- **Exercises:** 1. a single target X=120 (remove the table); 2. X=152 (the far right) and explain
  the quotient 10 in the routine; 3. *(Stretch)* ping-pong between X=32 and X=128 every 60 frames.
- **Screenshots:** `docs/public/images/lesson26/position-a.png`, `…/position-b.png`.
- **Evidence pins:** frame checkpoints; `PosStep` — A = the new index, one hit per 60 frames;
  `PosApply` — A = the table value (the target + 3 after the measured output-delay calibration), one hit per frame; `Resp0Write` — one hit per frame; the cycle advances with the table entry
  (24/34/44/54/64); `HmoveApply` on the next VBLANK line at cycle 0 (effect 3); the measured X
  from each capture. The routine's static ledger is in the doc.
- **Integration:** prev → Lesson 25; next → Lesson 27; part-index row 26 → ✅ Complete linking
  `./26-horizontal-positioning`; sidebar entry exists (`config.ts:85`). Estimated time: 75 minutes.
- **ST cases:** ST-26.1 assembly & drift · ST-26.2 first position · ST-26.3 second position and
  tour cadence · ST-26.4 debugger state and routine ledger · ST-26.5 solutions and screenshots ·
  ST-26.6 site integration.

## Lesson 27: Sprite Movement — Reading the Joystick

- **Goal:** move the sprite every frame and steer it with the joystick.
- **Concepts:** `SWCHA` at `$0280`, active-low (0 = pressed); player 0 uses bits 4 (up), 5 (down),
  6 (left), 7 (right); `SWACNT` left at `$00` (all input); a velocity/direction byte; bounds and
  bounce; a moving sprite re-strobes every frame with `SetHorizPos` (a static sprite can be
  positioned once).
- **ROM:** `27-sprite-movement.asm` — "the patrol": the Lesson 25 invader, top 80, starts at X=80
  with direction +1. Each frame: if exactly one of left/right is pressed, set the direction; if
  both are released, keep the current direction (including 0 after a stop); if both are pressed,
  stop. Move
  X by the direction, bounce at **16 and 144**, then call `SetHorizPos`. `COLUP0=$42`,
  `COLUBK=$02`. `SWACNT` is written `$00` in `Reset`.
- **Expected screen:** the red invader patrolling horizontally at rows ≈ 359–383; with no
  joystick input it moves right, bounces at X=144, and returns; the committed captures are chosen
  for a large separation (measured X=26 and X=142 in the shipped ROM; the exact frame depends on
  the capture's startup).
- **Demo ROM:** none — the patrol is the visible picture (AR-3); the joystick path is exercised
  manually in Stella.
- **Exercises:** 1. speed 2 (X ±2 per frame); 2. bounds 8 and 152; 3. *(Stretch)* vertical
  movement: `SWCHA` bits 4/5 (up/down) move the sprite's `TOP` by ±4 lines, with the top loop
  count in a variable and the bottom count computed as `192 − TOP − 8 − 1`.
- **Screenshots:** `docs/public/images/lesson27/patrol-a.png`, `…/patrol-b.png`.
- **Evidence pins:** frame checkpoints; `MoveTick` — A = the new X, one hit per frame;
  `DirWrite` — A = `$01`/`$FF`/`$00` while a horizontal direction is held (0 hits in the
  no-input patrol); `PosApply`; the measured X in
  each capture. The doc's static ledger covers the VBLANK update.
- **Integration:** prev → Lesson 26; next → Lesson 28; part-index row 27 → ✅ Complete linking
  `./27-sprite-movement`; sidebar entry exists (`config.ts:86`). Estimated time: 60 minutes.
- **ST cases:** ST-27.1 assembly & drift · ST-27.2 patrol positions · ST-27.3 direction and bounce
  · ST-27.4 debugger state · ST-27.5 solutions and screenshots · ST-27.6 site integration.

## Lesson 28: Two Players — GRP0 and GRP1

- **Goal:** draw and position both players independently, with their own shapes and colors.
- **Concepts:** `GRP1` mirrors `GRP0`'s rules (bit 7 leftmost, one line per write); `COLUP1`
  colors player 1; `RESP1`/`HMP1` position it; two positioning routines or one parameterized by
  the object; the two players share the line budget but not their graphics.
- **ROM:** `28-two-players.asm` — "the meeting": P0 (the Lesson 25 invader, `$42` red) at X=48 and
  P1 (a second 8-row creature `$3C,$7E,$FF,$DB,$FF,$66,$3C,$18`, `$84` blue) at X=104, both with
  top 88. Two coarse routines (`SetCoarse0`/`SetCoarse1`) set `HMP0/HMP1` and strobe
  `RESP0/RESP1`, then a single `HMOVE` applies both (AR-21). `NUSIZ0=NUSIZ1=0`, `COLUBK=$02`.
- **Expected screen:** two 8×8 sprites on the same eight scanlines (125–132), red at capture
  x ≈ 313 and blue at ≈ 649, rows ≈ 384–409.
- **Demo ROM:** none — the two players are the visible picture (AR-3).
- **Exercises:** 1. swap the colors; 2. move P0 to X=16 and P1 to X=140; 3. *(Stretch)* move both
  to X=80 and explain the overlap: player 0 has priority over player 1, so the red shape covers
  the blue one where they collide (the priority table from Lesson 20).
- **Screenshots:** `docs/public/images/lesson28/two-players.png`.
- **Evidence pins:** frame checkpoints; `PosApply0`/`PosApply1`; `Resp0Write`/`Resp1Write` — one
  hit per frame each; `BodyStart` at line 125; the measured X/colors in the capture.
- **Integration:** prev → Lesson 27; next → Lesson 29; part-index row 28 → ✅ Complete linking
  `./28-two-players`; sidebar entry exists (`config.ts:87`). Estimated time: 60 minutes.
- **ST cases:** ST-28.1 assembly & drift · ST-28.2 two-player frame · ST-28.3 colors and overlap ·
  ST-28.4 debugger state · ST-28.5 solutions and screenshot · ST-28.6 site integration.

## Lesson 29: Missiles and Ball — Simple Projectiles

- **Goal:** enable and position the two missiles and the ball, and control their widths.
- **Concepts:** `ENAM0`/`ENAM1`/`ENABL` bit 1 enables the object for the current line; missiles
  share `COLUP0`/`COLUP1`, the ball shares `COLUPF`; missile width is `NUSIZ` bits 4–5
  (1/2/4/8 px); ball width is `CTRLPF` bits 4–5; `RESM0`/`RESM1`/`RESBL` position them, with a
  one-clock-shorter output delay than the players.
- **ROM:** `29-missiles-and-ball.asm` — "the lineup": P0 (the invader, `$42` red) at X=24, rows
  96–103; M0 (1 px wide, 4 rows, rows 98–101) at X=64; M1 (4 px wide, 4 rows, rows 98–101) at
  X=96, `$84` blue; the ball (8 px wide, 4 rows, rows 98–101) at target 108, `$C8` green.
  `NUSIZ0=$00` (player normal, M0 1 px), `NUSIZ1=$20` (M1 4 px), `CTRLPF=$30` (ball 8 px, REF=0),
  `COLUBK=$02`. Four coarse routines set all four `HMxx` values, then a single `HMOVE` applies
  them (AR-21). The missiles' output delay is one clock shorter than the players', so they measure
  63 and 95 for targets 64 and 96. The ball's target-to-X mapping is its own: 68 → 79 and
  108 → 128; the measured table is the rule (the measured X is authoritative).
- **Expected screen:** a horizontal lineup at the same band: an 8-px red player at capture
  x = 169–216 (X=24), a 1-px red missile at 403–408 (X=63), a 4-px blue missile at 595–618
  (X=95), and an 8-px green ball at 793–840 (X=128), all at rows 410–433 (P0) and 416–427 (the
  small objects).
- **Demo ROM:** none — the four objects are the visible picture (AR-3).
- **Exercises:** 1. widen M0 to 8 px (`NUSIZ0=$30`); 2. shrink the ball to 1 px
  (`CTRLPF=$00`) and move it to target 68 (measured X=79); 3. *(Stretch)* a moving bullet: M0 travels from X=16 to
  X=150 (the wrap test stops at 152) at 2 px per frame and wraps, re-positioned every frame.
- **Screenshots:** `docs/public/images/lesson29/lineup.png`.
- **Evidence pins:** frame checkpoints; `PosApplyP0`/`PosApplyM0`/`PosApplyM1`/`PosApplyBL`;
  `EnableWrite` — A = `$02`, four hits on rows 2–5; the measured widths in the capture
  (1/4/8 px → 6/24/48 capture px); the `RESxx` store cycles. The doc's ledger records the
  missile/ball output-delay difference.
- **Integration:** prev → Lesson 28; next → Lesson 30; part-index row 29 → ✅ Complete linking
  `./29-missiles-and-ball`; sidebar entry exists (`config.ts:88`). Estimated time: 60 minutes.
- **ST cases:** ST-29.1 assembly & drift · ST-29.2 object lineup and widths · ST-29.3 colors and
  enables · ST-29.4 debugger state · ST-29.5 solutions and screenshot · ST-29.6 site integration.

## Lesson 30: Multi-Color Sprites — Changing Colors Per Line

- **Goal:** give one sprite several colors by writing `COLUP0` on every scanline.
- **Concepts:** `COLUP0` is a per-scanline register; a color table indexed by the sprite row; the
  shape and the color are independent tables; a 16-row sprite with three bands (hat/body/legs);
  the per-line write is in HBLANK before the sprite's pixels.
- **ROM:** `30-multicolor-sprites.asm` — "the avatar": P0 is a 16-row humanoid at top 80, X=72;
  the shape table is 16 bytes (rows 0–3 form the hat silhouette, 4–11 the body, 12–15 the legs);
  the color table is 4 × `$1A` (gold hat), 8 × `$84` (blue body), 4 × `$42` (red legs). Each body
  line writes `COLUP0` then `GRP0` then `WSYNC`. `COLUBK=$02`. The exact shape bytes are fixed in
  Session B and embedded verbatim in the doc; the captures verify the bands, not a specific face.
- **Expected screen:** one 8×16 sprite at capture x ≈ 457, rows ≈ 359–409, with a gold top band,
  a blue middle band, and a red lower band; the bands are 4/8/4 scanlines.
- **Demo ROM:** none — the color bands are the visible picture (AR-3).
- **Exercises:** 1. add white shoes (`$0E`, 2 rows) and split the rows 4/7/3/2; 2. slide the
  color bands by rotating the 16-byte color table one byte every 30 frames (the shape stays);
  3. *(Stretch)* a 16-px-wide two-color character: P0 and P1 side by side (P1 at X+8), each with
  its own 16-row half-shape and color.
- **Screenshots:** `docs/public/images/lesson30/multicolor.png`.
- **Evidence pins:** frame checkpoints; `ColorWrite` — A = the color, 16 hits per frame, with the
  4/8/4 runs; `BodyStart` at line 117; the capture's three color bands. The ledger covers the
  24-cycle body.
- **Integration:** prev → Lesson 29; next → Lesson 31; part-index row 30 → ✅ Complete linking
  `./30-multicolor-sprites`; sidebar entry exists (`config.ts:89`). Estimated time: 60 minutes.
- **ST cases:** ST-30.1 assembly & drift · ST-30.2 three color bands · ST-30.3 shape and row
  extent · ST-30.4 debugger state and ledger · ST-30.5 solutions and screenshot · ST-30.6 site
  integration.

## Lesson 31: Copies and Sizes — NUSIZ Register

- **Goal:** show every player copy/size mode by writing `NUSIZ0` per band.
- **Concepts:** `NUSIZ` bits 0–2: one copy (0), two close/medium/wide (1, 2, 4), three
  close/medium (3, 6), double width (5), quad width (7); copies are spaced 16/32/64 color clocks;
  `NUSIZ` also sets the missile width (bits 4–5), which is irrelevant while the missile is off.
- **ROM:** `31-copies-and-sizes.asm` — "the eight faces": eight 24-line bands covering the 192
  visible lines; band *k* sets `NUSIZ0=k` and draws `GRP0=$18` (two adjacent pixels) at X=40.
  Each line writes `NUSIZ0` from a 192-byte table (24 copies of each value) and `GRP0`; the
  player's vertical extent is the full screen, so the bands are the copy/size showcase.
  `COLUP0=$42`, `COLUBK=$02`.
- **Expected screen:** eight horizontal bands, each 24 scanlines (≈76 capture px), showing the
  pattern with a different mode: one 2-px bar; two bars at 16/32/64 clocks; three bars; double
  width (4 px); quad width (8 px). The first bar starts at capture x = 283 (the pattern's on-pixels are three pixels in).
- **Demo ROM:** none — the eight bands are the visible picture (AR-3).
- **Exercises:** 1. use `$FF` as the pattern and describe the copy gaps; 2. split the screen:
  top half P0 with `NUSIZ0=3`, bottom half P1 with `NUSIZ1=6` (two players at different X);
  3. *(Stretch)* animate one full-height sprite through all eight modes, one per 60 frames.
- **Screenshots:** `docs/public/images/lesson31/nusiz-bands.png`.
- **Evidence pins:** frame checkpoints; `BandWrite` — A = the band value, 192 hits per frame; the A runs change at lines 37, 61, 85, 109,
  133, 157, 181, 205; `PatternWrite` — 192 hits per frame; the measured
  bar widths in the capture (12/24/48 px; one TIA pixel = 6 capture px).
- **Integration:** prev → Lesson 30; next → Lesson 32; part-index row 31 → ✅ Complete linking
  `./31-copies-and-sizes`; sidebar entry exists (`config.ts:90`). Estimated time: 60 minutes.
- **ST cases:** ST-31.1 assembly & drift · ST-31.2 eight bands · ST-31.3 copy/size geometry ·
  ST-31.4 debugger state · ST-31.5 solutions and screenshot · ST-31.6 site integration.

## Lesson 32: Vertical Delay — VDELP0, VDELP1

- **Goal:** use `VDELP1` to delay a player's graphic by one scanline and understand when that is
  useful.
- **Concepts:** `VDELP0`/`VDELP1` bit 0; the graphic register is double-buffered, so the value
  written on line *N* is displayed on line *N*+1; the one-line shift is uniform; a clear write is
  delayed too; the latch lets a kernel stage the next line's shape while the current one is
  displayed; the 48-pixel trick is named as a later technique, not implemented.
- **ROM:** `32-vertical-delay.asm` — "the shadow": P0 and P1 both use the same 16-row striped
  shape (`$FF,$81,$81,$81,$FF,…`), top 88, P0 at X=48 (`$42` red), P1 at X=104 (`$84` blue);
  `VDELP1=$01`. The body writes both players every line and a final clear line writes 0 to both;
  P1 therefore appears one scanline lower (and its last row clears one line later).
  `COLUBK=$02`.
- **Expected screen:** two striped 8×16 blocks at rows ≈ 384–433, P0 red at capture x ≈ 313, P1
  blue at ≈ 649, with P1's top row one scanline (≈3 capture px) below P0's. The measured top-row
  difference is the evidence.
- **Demo ROM:** none — the one-line offset is the visible picture (AR-3).
- **Exercises:** 1. clear `VDELP1` — the two players align; 2. set `VDELP0` instead — P0 drops
  one line; 3. *(Stretch)* a moving sprite with VDEL on: the sprite descends 4 lines every 30
  frames; the one-line offset stays constant, proving VDEL does not accumulate.
- **Screenshots:** `docs/public/images/lesson32/vdel.png`.
- **Evidence pins:** frame checkpoints; `BodyStart` at line 125; `G0Write`/`G1Write` cycles;
  `VdelWrite` — A = `$01`; the measured top rows of both players in the capture. VDEL's output
  delay is not directly visible in a register log, so the capture is the primary evidence (stated
  in the doc).
- **Integration:** prev → Lesson 31; next → Lesson 33; part-index row 32 → ✅ Complete linking
  `./32-vertical-delay`; sidebar entry exists (`config.ts:91`). Estimated time: 60 minutes.
- **ST cases:** ST-32.1 assembly & drift · ST-32.2 one-line offset · ST-32.3 body and clear ·
  ST-32.4 debugger state · ST-32.5 solutions and screenshot · ST-32.6 site integration.

## Lesson 33: Paddle & Keyboard Controllers

- **Goal:** read the paddle potentiometers, the keyboard matrix, and the fire buttons, and show the
  readings on screen. The driving controller is a name-only aside: its quadrature pair arrives on
  the same `SWCHA` bits as the joystick, but the lesson does not decode it in code.
- **Concepts:** `INPT0–INPT3` are RC-timing inputs; `VBLANK` bit 7 discharges, bit 6 starts the
  charge; a bounded counting loop turns the charge time into a byte; `SWCHA` is an 8-bit
  active-low matrix (player 0 bits 4–7, player 1 bits 0–3); `INPT4`/`INPT5` bit 7 is 0 when the
  fire button is pressed; a keyboard controller pulls one or more matrix bits low, so the monitor's
  eight columns are the raw scan; the driving controller is a quadrature device on two of those
  bits (name-only; a short theory note explains the Gray-code idea).
- **ROM:** `33-paddle-keyboard-controllers.asm` — "the controller monitor": in VBLANK, discharge
  the paddles (`VBLANK=$82`, a `LDX #50` pad), start the charge (`VBLANK=$42`), then count `INPT0`
  until bit 7 rises or `CPY #128` bounds the loop; a timeout stores **0**, which the monitor
  documents as "no paddle or minimum"; a connected paddle's count 0–128 maps to needle
  X = `PaddleValue + 24` (24–152). Set `PF1` to the inverted `SWCHA` byte (eight vertical columns
  in chunks 4–11, capture x = 121–313 with `CTRLPF=$01` reflecting them), `PF0=PF2=0`,
  `COLUPF=$C8`. P0 is a 32-row bar (the needle) at top 80, `$42` red. P1 is an 8-row block at
  X=140, `$C8` green normally and `$42` red while `INPT4` bit 7 is 0. Both players are positioned
  every frame by two coarse routines, then one `HMOVE` (AR-21). `COLUBK=$02`.
- **Expected screen:** a green 8-column matrix strip (dark at rest), a red 32-line needle near
  capture x ≈ 169 at rest, and a green 8×8 fire block at capture x ≈ 865; the needle moves with
  paddle 0, the columns light when matrix bits are pulled low, and the block turns red when fire
  is pressed. The at-rest capture is the committed screenshot; the doc explains what each change
  looks like.
- **Demo ROM:** none — the monitor is the visible picture (AR-3).
- **Exercises:** 1. read paddle 1 (`INPT1`) instead and move the needle with it; 2. make the fire
  block double width (`NUSIZ1=$05`) and gold (`$1A`) when pressed; 3. *(Stretch)* two needles:
  paddle 0 positions P0 and paddle 1 positions P1 (two independent coarse routines and one
  `HMOVE`).
- **Screenshots:** `docs/public/images/lesson33/monitor.png`.
- **Evidence pins:** frame checkpoints; `PaddleRead` — A = the final count (0–128, 0 on timeout),
  one hit per frame; `PaddleX` — A = the needle X (24–152); `KeyWrite` — A = the inverted `SWCHA`
  byte; `FireWrite` — A = the `COLUP1` value; `MoveApply` — one `HMOVE` hit per frame; the capture
  positions/colors. The doc's ledger covers the discharge/charge loop (~22 lines worst case) plus
  the two positions (~3 lines), inside the 37-line VBLANK.
- **Integration:** prev → Lesson 32; next → Lesson 34; part-index row 33 → ✅ Complete linking
  `./33-paddle-keyboard-controllers`; sidebar entry exists (`config.ts:92`). Estimated time:
  75 minutes.
- **ST cases:** ST-33.1 assembly & drift · ST-33.2 monitor layout · ST-33.3 input reads and
  timeout · ST-33.4 debugger state and ledger · ST-33.5 solutions and screenshot · ST-33.6 site
  integration.

## Lesson 34: Sprite Animation — Walking Cycles & Character States

- **Goal:** animate a sprite from a frame table and time the frames.
- **Concepts:** a frame is a 16-byte shape; a frame table is 4 × 16 bytes; the frame base pointer
  is computed in VBLANK (`frame × 16 + base`); the body reads `(FramePtr),Y`; the frame advances
  every 8 frames (7.5 Hz); `REFP0` mirrors the walk direction; animation timing is a frame
  counter, not a timer.
- **ROM:** `34-sprite-animation.asm` — "the walk": P0, 16 rows, top 80, X=72, `COLUP0=$42`,
  `COLUBK=$02`; four walk frames in a 64-byte table (the frames differ only in the leg rows 12–15;
  the exact bytes are fixed in Session B and embedded in the doc); `FrameStep` every 8 frames;
  `REFP0` toggles every 120 frames to face the other way; the body reads the current frame through
  `FramePtr`.
- **Expected screen:** a red 16-row figure at capture x ≈ 457, rows ≈ 359–409; the legs change
  between captures at ~0.5 s and ~1.0 s (frame indices differ); the figure faces left or right
  depending on the direction phase.
- **Demo ROM:** none — the walk cycle is the visible picture (AR-3).
- **Exercises:** 1. cadence 16 (half speed) or 4 (double speed); 2. an idle frame: every 120
  frames, hold a neutral pose for 60 frames (a two-state machine); 3. *(Stretch)* walk and move:
  combine the animation with `SetHorizPos` so the figure crosses the screen at 1 px per frame.
- **Screenshots:** `docs/public/images/lesson34/walk-a.png`, `…/walk-b.png`.
- **Evidence pins:** frame checkpoints; `AnimStep` — A = the new frame index, one hit every 8
  frames; `FramePtrWrite` — A = the low byte of the frame base; `BodyStart` at line 117; the
  capture difference in the leg rows. The ledger covers the 18–19-cycle body (page-crossing
  `(zp),Y` read).
- **Integration:** prev → Lesson 33; next → `/part5-sound/35-sound-effects` (the real Part 5 stub,
  titled "Sound Effects"); part-index row 34 → ✅ Complete linking `./34-sprite-animation`;
  sidebar entry exists (`config.ts:93`). Estimated time: 75 minutes.
- **ST cases:** ST-34.1 assembly & drift · ST-34.2 walk frames · ST-34.3 cadence and direction ·
  ST-34.4 debugger state and ledger · ST-34.5 solutions and screenshots · ST-34.6 site
  integration.
