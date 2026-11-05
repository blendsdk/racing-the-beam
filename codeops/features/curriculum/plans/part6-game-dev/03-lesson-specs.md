# Lesson Specifications: Part 6 — Game Development (Lessons 38–47)

> **Document**: 03-lesson-specs.md
> **Parent**: [Index](00-index.md)
> **Authority**: this document owns the per-lesson design; [07-testing-strategy.md](07-testing-strategy.md)
> owns the ST cases, and [00-ambiguity-register.md](00-ambiguity-register.md) owns the decisions.

## Shared Conventions

### Frame and Video

- NTSC only: `VSYNC` 3 + `VBLANK` 37 + picture 192 + overscan 30 = **262 lines**.
- `+set_timer 44` and `+wait_timer` cover VBLANK; `+set_timer 36` and `+wait_timer` cover overscan.
- The picture begins at scanline 37 (visible line 0 = capture y 107) and ends at scanline 228.
- Capture mapping used by every pixel check: `capture x = 25 + 6 × TIA_X`, `capture y = 107 +
  3.15 × visible_line`. A sprite's first visible row is the scanline where its `GRP` write is
  latched.
- **Kernel order:** every full-screen kernel is **work-first** — write the line's registers, then
  `STA WSYNC` — except the 48-pixel score kernel below. The first work line is scanline 37, the last is 228, and `OverscanStart` is 229.
  The 48-pixel score kernel is the documented **WSYNC-first exception**: its `STA WSYNC` sits
  after the first load because its six stores are cycle-timed; visible line 0 is its setup/blank
  line.
- Two-object positioning: set every coarse `RESxx` and every `HMxx` value first, then strobe one
  `HMOVE` (the one-HMOVE rule). The final `STA WSYNC` sits immediately after the last `STA RESxx`,
  with `STA HMOVE` next. Report `HmoveApply` (the WSYNC stall) and `HmoveDone` (the store, which
  executes at the next line's cycle 0). The measured X is authoritative; the target includes the
  `+3` bias used by `SetHorizPos`.
- A multi-zone frame keeps the 192-line total: each zone states its line count and the total is
  checked in Session C.

### Logic Evidence

- Collision claims: a breakpoint after the `LDA CXxx` reports A; a breakpoint after `STA CXCLR` (a
  strobe has no A effect) marks the clear. The latches observed in VBLANK are from the previous
  visible frame; the document states this one-frame latency.
- Score claims: breakpoints after `STA ScoreDigits,X`, `STA ScoreBuf,X`, and the BCD `STA` report
  the value; the displayed score is pixel-checked against the font.
- State claims: a breakpoint after `STA GameState` reports A = the new state; the state's layout
  is pixel-checked.
- LFSR claims: a breakpoint after `STA RandomSeed` reports A; the sequence is cross-checked against
  the polynomial's 255-state period.
- AI claims: breakpoints after `STA EnemyState`, `STA EnemyX`, and the distance computation report
  A; the enemy's capture X is pixel-checked.
- Memory claims: the map table is static; the packed bytes are logged after their stores.
- A screenshot never proves the logic; the committed ROM and the `<RomPlayer>` are the runnable
  artifact. The lesson documents say this, and tell the reader to click the player screen once:
  Javatari starts muted until a user gesture.

### Audio Beep

Each lesson carries a two-byte beep: `BeepTimer` and `BeepPitch`. `BeepStart` writes
`AUDC0=$0C`, `AUDF0=pitch`, `AUDV0=$0A`; every VBLANK decrements `BeepTimer` and writes
`AUDV0=0` at zero. The beep uses channel 0 only; no lesson uses `include/sound.asm` (AR-24).

### RAM Map

| Range | Owner | Contents |
| --- | --- | --- |
| `$80–$9F` | lesson | counters, positions, flags, state, beep |
| `$A0–$D7` | score library (39/40 only) | `ScoreDigits` 6 + `ScoreBuf` 48 + pad |
| `$A0–$A8` | random library (43 only) | `RandomSeed` 1 + `RandomHistory` 8 |
| `$D8–$F7` | free | lesson overflow / future use |
| `$A9–$D7` | free in Lesson 43 | not used by the random library |
| `$F8–$FF` | stack | `+clean_start` sets SP=$FF; keep call depth shallow |

A lesson never uses both libraries. Each lesson's source header repeats its exact map;
`+clean_start` zeroes all of it.

### Lesson Document Template

Every lesson document follows the fixed six-section template (the Part 1–5 pattern):
frontmatter (`title`, `description`, `prev`, `next`), the meta block (Part, estimated time,
prerequisites, "You will learn", "You will build"), Introduction with a `::: details TypeScript
Equivalent` block, Theory, The Code (Building, Full Source **verbatim** from the `.asm`, Code
Walkthrough, checkpoint table), What You Should See (two images + `<RomPlayer>` + debugger
commands), Exercises (three, each with Challenge/Hints/Expected Result/Solution), Key Takeaways
(≤ 7), and What's Next. Each TypeScript block mirrors the lesson's mechanism:
- 38: collision-latch polling and classification.
- 39: a 6-digit score buffer and a digit-carry add.
- 40: BCD add/subtract with carry.
- 41: a state machine with per-state update/draw.
- 42: a level/speed table and switch reads.
- 43: an LFSR step and range mask.
- 44: a patrol/chase/flee state machine.
- 45: a RAM map and bit-packed flags.
- 46: a bug/fix toggle and the debugger workflow.
- 47: an assembler/build pipeline model.

### Shared Score Library (`include/score.asm`, Lesson 39)

- `ScoreDigits` = `$A0–$A5` (six binary digits 0–9, left to right).
- `ScoreRow`/`ScoreTmp` = `$A6–$A7` (library scratch; no state between calls).
- `ScoreBuf` = `$A8–$D7` (48 bytes, six columns × eight rows, column-major, bottom-up).
- API:
  - `ScoreInit` — zero `ScoreDigits` and `ScoreBuf`.
  - `ScoreSetup` — `NUSIZ0=NUSIZ1=3`, `VDELP0=VDELP1=1`, position P0 at 56 and P1 at 64
    (the Lesson 26 divide-by-15 positioning with the +3 bias), then one `HMOVE`. Colors are the
    caller's.
  - `ScoreSetDigit` — A = position 0–5 (0 = leftmost), X = digit 0–9; stores the digit in
    `ScoreDigits` and copies all **eight** bytes of that column from `ScoreFont + digit×8`
    (bottom-up glyph).
  - `ScoreAddOne` — increment the six-digit decimal number with carry; returns C=1 on overflow
    from 999999 to 000000.
  - `ScoreClear` — set all six digits to 0 and rebuild the buffer.
  - `ScoreDraw` — the 8-row Staugas kernel; consumes **9 visible lines**: line 0 is the
    setup/blank line (the first `STA WSYNC`), lines 1–8 carry the eight rows, and the cleanup
    (`GRP0/GRP1=0`, `VDELP0/VDELP1=0`) shares line 8. The caller calls it once per frame at the
    top of the visible area, then continues the game zone. The kernel reads `ScoreBuf+0,Y`,
    `+8,Y`, `+16,Y`, `+24,Y`, `+32,Y`, `+40,Y`; the sixth data store is at cycle 51 and the
    seventh `STA GRP0` flush at cycle 54. `ScoreDrawRow` marks each row's staged bytes for the
    debugger; `ScoreDraw` marks the call.
- Font: 10 glyphs × 8 bytes, 8×8, stored **bottom-up** (row 7 first) because the Staugas loop
  counts Y down from 7. The prototype rendered "123456" at x=367–642, y=109–131.
- The score zone is **9 lines** (1 setup/blank + 8 score rows; the cleanup shares the last row's
  line); the game zone is 183 lines (9 + 183 = 192).

### Shared Random Library (`include/random.asm`, Lesson 43)

- `RandomSeed` = `$A0` (1 byte, nonzero), `RandomHistory` = `$A1–$A8` (8 bytes).
- API:
  - `RandomInit` — A = seed; store it; if zero, store `$5A` (the LFSR locks at zero).
  - `Random` — one Galois step: `LDA RandomSeed; ASL; BCC +; EOR #$1D; +: STA RandomSeed; RTS`;
    returns A = the new seed. Period 255 for a nonzero seed.
  - `RandomMask` — A = mask; `AND RandomSeed`; returns A. (A power-of-two range; the lesson
    explains why modulo is expensive on the 6502.)
  - `RandomPush` — shift `RandomHistory` down one byte and store the current seed at
    `RandomHistory+0`; the 8×8 history grid reads these eight bytes.
- The 8-bit polynomial `$1D` (taps 0, 2, 3, 4) is maximal-length; the lesson states the period and
  the zero lock.

## Lesson 38: Collision Detection — When Things Touch

- **Goal:** read the TIA's collision latches, classify them, and react once per contact.
- **Prerequisites:** Lesson 12 (the frame), Lesson 17 (cycle counting), Lesson 18 (mid-line TIA
  writes), Lesson 26 (`SetHorizPos` and one `HMOVE`), Lesson 27 (joystick movement), Lesson 28
  (the one-`HMOVE` rule), Lessons 29 and 31 (missiles, the ball, and `NUSIZ`), Lesson 33
  (`INPT4` fire), Lesson 35 (the audio registers).
- **Concepts:** `CXM0P`…`CXPPMM`; bit 7/6 pair meanings; latches stay set until `CXCLR`; reading in
  VBLANK observes the previous visible frame; a new-contact edge (0→1) triggers a hit; the hit bar.
- **ROM:** `38-collision-detection.asm` — "the collision lab".
  - Top: four 6-line bands (visible 0–23) for P0–P1 (`CXPPMM` bit 7, red `$42`), P0–ball
    (`CXP0FB` bit 6, gold `$1A`), P0–playfield (`CXP0FB` bit 7, green `$C8`), M0–P1 (`CXM0P` bit 7,
    blue `$84`). The active band uses its color; the others `$02`.
  - Play area: visible 24–171. `CTRLPF=$01` (reflect). A 16-px wall at each edge (`PF0=$F0`,
    `PF1=$00`, `PF2=$00`), gold `$1A`; P0 (16 rows, red `$42`) starts at X=8, Y=140 and moves in
    **both** axes with the joystick (clamp X=8…144, Y=40…156; 144 puts P0 8 px inside the right
    wall); P1 (16 rows, blue `$84`) sits at
    X=40…136, Y=40 (auto-sweep; 136 keeps the 8-px sprite clear of the right wall); the ball
    (8 rows, gold `$1A`) is fixed at X=80, Y=100; M0
    (4 rows, red — it shares `COLUP0` with P0) fires upward from P0's X and resets at the top.
    The wall and the ball share `COLUPF`; they are told apart by position and size.
  - Bottom: a 15-chunk hit bar (visible 172–177) drawn by the playfield as N chunks from the left,
    mirrored by `CTRLPF=$01`, gold; the remaining lines are background.
  - Collision read in VBLANK: build `LatchMask` from the four bits, edge-detect against
    `PrevMask`; a new bit increments `Hits` (clamped at 15) and starts the beep. Then `CXCLR`.
  - The ROM auto-demo: P0 moves around a rectangle (X 8…80, Y 40…156) by ±1 every 2 frames and
    P1 sweeps 40…136; the joystick overrides P0. The auto-demo also fires M0 every 90 frames
    when there is no input, so the M0–P1 band demonstrates itself; fire launches M0 manually.
  - Colors: playfield/ball `$1A`, P0/M0 `$42`, P1 `$84`, background `$02`.
- **Expected screen:** at a P0–wall contact, band 2 is green and the hit bar is at least 1 cell;
  at a P0–P1 contact, band 0 is red. The exact captured band/bar is recorded in Session C.
- **Exercises:**
  1. **The ball, not the wall.** Change the green band's source from `CXP0FB` bit 7 to bit 6 and
     document the new meaning. Expected: the band lights only when P0 touches the ball;
     `ReadCX` A has bit 6 set.
  2. **Enemy missile.** Give P1 a missile (M1) that fires downward every 90 frames and read
     `CXM1P` bit 7 (M1–P0); the main ROM only has M0. Expected: the blue band lights when the
     enemy missile hits P0; `ReadCX` A = `CXM1P` with bit 7 set.
  3. *(Stretch)* **Sticky latches.** Remove the `STA CXCLR` store (do not merely move it: a store
     after the kernel still clears once per frame and the bands go dark). Expected: the bands stay
     lit after the objects separate; the log shows no `CXClear` at all, proving why clearing
     matters.
- **Screenshots:** `docs/public/images/lesson38/wall.png`, `…/p1.png`.
- **Evidence pins:** `StartFrame`, `VblankStart`, `ReadCX` (A = `CXP0FB`), `CollMask` (A = the full
  mask), `CollStep` (A = the 0→1 edge bits), `CXClear`, `Hits`, `BodyStart` 37,
  `HmoveApply`/`HmoveDone`, `OverscanStart` 229.
- **Integration:** prev → Lesson 37; next → Lesson 39; part-index row 38 → ✅ Complete linking
  `./38-collision-detection`; sidebar entry exists (`config.ts:109`). Estimated time: 75 minutes.

## Lesson 39: The Scoreboard — 48-Pixel Sprite Trick

- **Goal:** draw six digits in 48 pixels with two players and VDEL, and keep a decimal score.
- **Prerequisites:** Lesson 11 (lookup tables), Lesson 18 (mid-line writes), Lesson 25 (player
  graphics), Lesson 26 (`SetHorizPos` and one `HMOVE`), Lesson 31 (`NUSIZ` copies), Lesson 32
  (vertical delay), Lesson 38 (collision latches).
- **Concepts:** three-copy close mode; P1 8 px right of P0; VDEL shadow registers; the Staugas
  six-store kernel; a column-major score buffer; a decimal digit carry; the score zone.
- **ROM:** `39-scoreboard.asm` — "the scoreboard".
  - Top: the 6-digit score (9 lines) via `include/score.asm`; starts at 000000.
  - Play area: visible 9–191. A playfield target block at visible 150–157 (8 lines), X=64–95
    (32 px), gold `$1A`; a ball (8 rows, gold) at Y=150, X starts at 24 and is moved by the
    joystick (2 px/frame, clamp 24–136). When `CXBLPF` bit 7 sets, `ScoreAddOne`, beep, and
    respawn the ball at X=24. The collision is read in VBLANK, then `CXCLR`.
  - The ROM auto-sweeps the ball 24→136 and back when there is no input, so the score climbs
    during a capture; the joystick overrides.
  - Bottom: the remaining lines are background.
- **Expected screen:** the score is a white 6-digit block at capture x≈367–642, y≈110–130; the
  first capture reads **000001** and the second **000002**; the ball is a gold 1-px-wide, 8-row
  block at capture y≈580–604, and the target is a gold 32-px block at the same rows.
- **Exercises:**
  1. **Set a score.** Call `ScoreSetDigit` six times to show 012345 at reset. Expected: the
     capture shows 012345; `ScoreDigitWrite` logs each position/value.
  2. **Double score.** Call `ScoreAddOne` twice per hit. Expected: the score advances by 2 and
     carries 9→0 correctly; `ScoreAdd` runs twice.
  3. *(Stretch)* **Leading blanks.** Add a `ScoreBlank` call so leading zero columns are dark.
     Expected: 000042 displays as `    42` (four blanks + 42 = six columns); the font's zero glyph
     is replaced by a blank for the leading positions only.
- **Screenshots:** `docs/public/images/lesson39/score-a.png` (first captured score),
  `…/score-b.png` (a later score, one hit higher).
- **Evidence pins:** `ScoreInit`, `ScoreDigitWrite` (A = position, X = digit), `ScoreAdd` (A = the
  low digit after the add), `BallHit`, `BodyStart` 37, `ScoreDraw` (the call) and `ScoreDrawRow`
  (each row's bytes), `HmoveDone`, `OverscanStart` 229.
- **Integration:** prev → Lesson 38; next → Lesson 40; index row 39 → ✅ Complete;
  `include/score.asm` created. Estimated time: 90 minutes.

## Lesson 40: BCD Arithmetic — Scores That Make Sense

- **Goal:** keep a six-digit score in three BCD bytes and add/subtract with decimal mode.
- **Prerequisites:** Lesson 05 (addition and subtraction), Lesson 06 (flags), Lesson 39 (the
  48-pixel score and `ScoreSetDigit`).
- **Concepts:** BCD nibbles; `SED`/`CLD`; `CLC`/`ADC` and `SEC`/`SBC` across three bytes; the
  carry/borrow between bytes; converting BCD to six display digits; restoring binary mode.
- **ROM:** `40-bcd-arithmetic.asm` — "the BCD counter".
  - `BCDScore` = three bytes `$00,$00,$00` (low/mid/high, two digits each).
  - The main ROM implements `BCDAdd` A=1 and A=100 (the **command selector**, not a BCD addend:
    A=1 adds 1 to the **low** byte; A=100 adds 1 to the **middle** byte, carrying into the high
    byte) and isolates `SED`/`CLD`. ADD 10 (low += $10) and SUB 1 are the exercise subjects, so
    the operation bar's ADD 10/SUB 1 positions stay dark in the main ROM. A top-byte carry sets
    `Overflow` (visible 17–24, red) and wraps to 000000; a borrow wraps to 999999. The main's
    auto-demo cannot reach 999999; the overflow witness is exercise 2 (000000 − 1 = 999999, then
    ADD 1) or a scratch probe, and the doc says so.
  - Display: rebuild six digits from the three bytes (low → digits 5/4, mid → 3/2, high → 1/0)
    and call `ScoreSetDigit`, then `ScoreDraw` (9 lines).
  - Operation bar: a single 16-px gold cell at one of four positions (ADD 1, ADD 10, ADD 100,
    SUB 1) on visible 9–16. The main ROM implements ADD 1 and ADD 100; the ADD 10/SUB 1
    positions are dark/hidden until the exercises. Joystick up/down selects; fire executes. The
    auto-demo cycles **ADD 1 → ADD 100** every 60 frames and executes, so the first two captures
    read 000001 and 000101.
  - Carry cell: visible 17–24, red. Bit/value strip: visible 25–32, eight cells showing the low
    BCD nibbles. The rest is background.
- **Expected screen:** the score at x≈367–642, y≈109–131; after one ADD 1 it reads 000001; after
  ADD 100 it reads 000101. The operation bar highlights the active operation; the overflow cell
  is dark except on wrap.
- **Exercises:**
  1. **Add 10.** Implement the ADD10 path (A=10, the command selector; it is not a BCD addend)
     and light the ADD 10 cell. Expected: 000010; `BCDAdd` A=10, `BCDScore` low=$10.
  2. **Subtract 1.** Implement `BCDSub` with `SED; SEC; SBC #1` across the bytes. Expected:
     000000 → 999999 with the borrow; `BCDBorrow` set.
  3. *(Stretch)* **Add 100 with a middle carry.** 009900 + 100 = 010000; the middle byte 99 + 01
     carries out. Expected: `BCDCarry` A=1 on the middle add; the score shows 010000.
- **Screenshots:** `docs/public/images/lesson40/add1.png`, `…/add100.png`.
- **Evidence pins:** `BCDAdd` (A = command selector), `BCDCarryMid` (A = the carry into the middle
  byte; ADD 1/ADD 10), `BCDCarry` (A = the carry into the high byte), `BCDScoreLow/Mid/High`,
  `ScoreDigitWrite`, `Overflow`, `BodyStart`, `HmoveDone`.
- **Integration:** prev → Lesson 39; next → Lesson 41; index row 40 → ✅ Complete. Estimated
  time: 75 minutes.

## Lesson 41: Game States — Title, Play, Game Over

- **Goal:** structure a game as a state machine with per-state update and draw code.
- **Prerequisites:** Lesson 06 (flags and comparisons), Lesson 11 (lookup tables), Lesson 27
  (joystick input), Lesson 29 (the ball), Lesson 34 (frame counters), Lesson 38 (collision
  latches), Lesson 40 (the score display pattern).
- **Concepts:** a state byte; per-state input handling; transitions on fire/hit/miss; a shared
  frame skeleton; resetting per-game variables on entry; a high-score byte (exercise).
- **ROM:** `41-game-states.asm` — "the state machine".
  - `GameState` 0=title, 1=play, 2=over. `StateTimer`, `Hits`, `PlayerX`, `BallY`, `BallX`,
    `BeepTimer` (lives arrive in Lesson 42).
  - Title (visible 0–191): a centered playfield emblem (three stacked blocks) in gold, a blinking
    15-cell bar at the bottom (`Frame & $20`), background `$02`; fire → state 1.
  - Play: a 16-line status bar at the top (visible 0–15) shows the hit bar (N chunks per half);
    P0 (16 rows, red) at Y=140 moves left/right; the ball (8 rows, gold) falls from Y=24 at
    1 px/frame, X aligned with P0 at spawn. `CXP0FB` bit 6 (P0–ball) → `Hits++`, beep, respawn
    the ball; ball Y > 180 → state 2. P0 is positioned in VBLANK.
  - Over: a red background, the final hit bar at the top, a blinking "fire" bar at the bottom;
    fire → state 0.
  - The title and over screens use the playfield only; play uses P0 + ball. No 48-pixel score.
  - Auto-demo: the title's `StateTimer` starts at 180 frames and counts down while no joystick
    direction is held; at zero it enters play. Fire enters play immediately. In play, the first
    hit arms a 30-frame timer; when it expires P0 slides right, away from the ball's spawn, so the
    next ball misses and the over screen appears without input. A manual left/right press takes
    control; fire returns to the title from over.
- **Expected screen:** title shows the gold emblem and a blinking bar (15 chunks per half, two
  segments with a centre gap); over shows a red field, the final hit bar, and the blinking fire
  bar. The two committed captures are the title and over layouts; the play layout is the live
  ROM state.
- **Exercises:**
  1. **Pause.** Add state 3 toggled by SELECT in play; the game freezes and the status bar blinks.
     Expected: `StateChange` A=3, then A=1; the ball's Y is unchanged during the pause.
  2. **Attract mode.** After 300 frames on the title with no fire, enter play automatically.
     Expected: `StateChange` A=1 at frame 300; `StateTimer` counts down.
  3. *(Stretch)* **High score.** Keep the best `Hits` in `HighScore` across games; show it on the
     over screen as a second bar. Expected: `HighScore` retains the max across two games.
- **Screenshots:** `docs/public/images/lesson41/title.png`, `…/over.png`. The images are Stella
  debugger `saveSnap` TIA frames at frames 40 and 500 from the committed ROM, placed in the
  window chrome of a Stella window capture of the same ROM; the doc discloses the method.
- **Evidence pins:** `StateChange` (A = new state), `TimerRead` (A = `StateTimer`'s low byte),
  `FireRead` (A = `INPT4`), `HitStep` (A = hits), `BallStep` (A = the new `BallY`), `BodyStart`,
  `HmoveApply`/`HmoveDone`. `StateTimer` and `BallY` are RAM variables; `TimerRead` and `BallStep`
  are their code checkpoints.
- **Integration:** prev → Lesson 40; next → Lesson 42; index row 41 → ✅ Complete. Estimated
  time: 90 minutes.

## Lesson 42: Difficulty and Progression

- **Goal:** read the console switches and scale the game's speed and enemy over time.
- **Prerequisites:** Lesson 06 (flags), Lesson 11 (lookup tables), Lesson 27 (joystick input),
  Lesson 34 (frame counters), Lesson 38 (collision latches), Lesson 41 (game states and the
  restart flow).
- **Concepts:** `SWCHB` bits 6/7 (difficulty, 0=B/novice, 1=A/expert); a starting level from a switch;
  a speed table indexed by level; a survival timer; a level cap; lives.
- **ROM:** `42-difficulty.asm` — "the difficulty ladder".
  - `Level` 1–15, `LevelTimer` 300, `Lives` 3, `EnemyX`, `EnemyDir`, `PlayerX`, `Switches`.
  - Read `SWCHB` in VBLANK: bit 6 (P0 difficulty) selects the starting level 1 (B/novice, bit=0)
    or 5 (A/expert, bit=1); bit 7 (P1 difficulty) selects `NUSIZ1=0` (B/novice) or `NUSIZ1=5`
    (A/expert, double width). The course's `include/vcs.asm` and hardware reference now state
    this polarity (0=B, 1=A); the earlier comment was inverted. A 2-cell indicator at the top shows the two switch states.
  - Top: visible 0–7 is the level bar (N chunks per half, gold); visible 8–15 is the three red
    life cells per half (each 2 chunks, at X=8/16/24); visible 16–23 is the two-cell switch
    indicator per half (left and right difficulty). Play area: visible 24–191, `CTRLPF=$01`, `PF0=$F0` for the two
    edge walls.
  - P0 (16 rows, red) and P1 (16 rows, green) both at **Y=140** (the same scanlines, so
    `CXPPMM` can set); P1 bounces between X=24 and X=136 at `Speed = SpeedTable[Level]`
    (1…4 px/frame).
  - Every 300 survived frames: `Level++` (cap 15), beep, flash the level bar. A P0–P1 collision
    (`CXPPMM` bit 7): `Lives--`, respawn P1 at the opposite side, 60 frames of invulnerability,
    beep; at 0 lives the field turns red, play freezes, and fire restarts at the switch-selected
    starting level (1 on B, 5 on A).
  - The left difficulty switch is also shown as a 1-cell block; the right as another.
- **Expected screen:** at level 1 the level bar is 1 chunk and the enemy speed is 1; at level 5
  the bar is 5 chunks and the enemy is faster. Expert (switch A, bit 6/7=1) starts at level 5
  with a wider enemy.
- **Exercises:**
  1. **Invert the left switch.** Make expert start at level 1 and novice at 5 (the opposite of
     the main ROM). Expected: `ReadSWCHB` A bit 6, the level bar starts at 1 on expert.
  2. **Three copies.** Make the right switch select `NUSIZ1=3` (three copies) on expert instead
     of double width, and cap P1 at X=24…104 so all three copies stay on screen. Expected:
     `NUSIZWrite` A=3; the play area shows three green enemies.
  3. *(Stretch)* **Expert level cap.** Make the right switch cap the level at 10 on expert and
     15 on novice. Expected: `LevelUp` stops at 10 on expert; `SpeedWrite` stays at the level-10
     entry.
- **Screenshots:** `docs/public/images/lesson42/level1.png`, `…/level5.png`.
- **Evidence pins:** `ReadSWCHB` (A = `SWCHB`), `LevelUp` (A = level), `SpeedWrite` (A = speed),
  `NUSIZWrite` (A = NUSIZ1), `LifeStep` (A = lives), `BodyStart`, `HmoveDone`.
- **Integration:** prev → Lesson 41; next → Lesson 43; index row 42 → ✅ Complete. Estimated
  time: 75 minutes.

## Lesson 43: Random Numbers — Unpredictable Fun

- **Goal:** generate pseudo-random bytes with a Galois LFSR and use them for positions.
- **Prerequisites:** Lesson 09 (bitwise operations), Lesson 11 (lookup tables), Lesson 27
  (joystick input), Lesson 34 (frame counters).
- **Concepts:** the 8-bit LFSR `ASL`/`EOR #$1D`; nonzero seed; period 255; masking for ranges;
  a history grid; seeding from a frame counter/input.
- **ROM:** `43-random-numbers.asm` — "the random lab".
  - `include/random.asm`; `RandomInit` with seed `$5A` at reset.
  - Top: a seed row (8 cells, 8 lines) drawn by `PF1=RandomSeed`; below, an 8×8 history grid
    (8 rows × 4 lines) drawn by `PF1=RandomHistory[row]`; each lit cell is a **4-px** chunk, so
    the grid is 32 px wide.
  - Left: a 15-cell meter (6 lines per cell) at X=24 showing `RandomSeed >> 4`; the bar is
    `PF1=$20` (chunk 6) for lit cells; `CTRLPF=$01` mirrors it on the right.
  - Every 4 frames: `Random`, `RandomPush`, beep on bit 0. Fire reseeds from `FrameLo EOR FrameHi`;
    joystick up/down changes the seed by ±1, wrapping 0 to $FF. The seed row, grid, and meter
    update.
  - The rest of the screen is background.
- **Expected screen:** the seed row shows 8 lit/dark cells; the 8×8 grid shows the last eight
  bytes; the meter height is `seed >> 4`. Two captures show different seeds/patterns.
- **Exercises:**
  1. **16-bit LFSR.** Extend the state to two bytes with `ASL lo; ROL hi; BCC; EOR #$2D` on the
     low byte; expected: the period is 65535 (the log's low bytes repeat only after 65535 steps);
     the grid still uses the low byte.
  2. **Range.** Use `AND #$07` to place a ball at one of eight columns; expected: the ball's X is
     `24 + 16 × (seed & 7)`; `RandomMask` A=7.
  3. *(Stretch)* **Seed from SELECT.** Add a second reseed source: pressing SELECT adds the frame
     counters to the seed. Expected: two SELECT presses at different frames give different
     `SeedWrite` values; fire keeps its original reseed.
- **Screenshots:** `docs/public/images/lesson43/random-a.png`, `…/random-b.png`.
- **Evidence pins:** `RandomStep` (A = new seed), `SeedWrite` (A = seed), `RandomPush`,
  `RandomMask` (A = masked), `BodyStart`, `OverscanStart`.
- **Integration:** prev → Lesson 42; next → Lesson 44; index row 43 → ✅ Complete;
  `include/random.asm` created. Estimated time: 75 minutes.

## Lesson 44: AI & Enemy Behavior — Chase, Patrol, Flee

- **Goal:** build a small enemy brain with patrol, chase, and flee states.
- **Prerequisites:** Lesson 06 (flags and comparisons), Lesson 27 (joystick input), Lesson 34
  (frame counters), Lesson 38 (collision latches), Lesson 41 (the state-machine shape).
- **Concepts:** a state byte; a distance computation; per-state movement; a state timer; a flee
  trigger; color as state feedback; collision/lives.
- **ROM:** `44-ai-enemy-behavior.asm` — "the hunter".
  - `EnemyState` 0=patrol, 1=chase, 2=flee; `EnemyX`, `EnemyDir`, `EnemyTimer`, `PlayerX`,
    `Lives` 3, `Distance`.
  - P0 (16 rows) and P1 (16 rows) both at **Y=100**; both move horizontally; `CTRLPF=$01` draws
    the two edge walls with `PF0=$F0`.
  - Patrol: move ±1 between X=24 and X=136; on a wall, reverse; a patrol is **calm** at close
    range and does not flee. Chase (when `|PlayerX-EnemyX| > 24`): move toward the player at ±2.
    A **chasing** enemy flees (distance ≤ 24 or fire): move away at ±2 for 60 frames; do not
    re-enter patrol while the distance is still ≤ 32 (hysteresis). Fire panics any state. This
    keeps all three states visible: patrol at 18–23 (18–22 target, the rightward phase rests at
    23), chase when the player escapes past 24, flee
    when the chase closes to 24 or the player fires.
  - Layout: the state row is visible 0–7 (three cells per half, one lit cell per state); the
    distance bar is visible 8–15 (N chunks per half = distance/16); the play area is 16–191.
    Colors: patrol green `$C8`, chase gold `$1A`, flee red `$42`.
  - A P0–P1 collision (`CXPPMM` bit 7) costs a life, respawns P1 at the opposite side, and grants
    60 frames of invulnerability; at 0 the field turns red, play freezes, fire restarts.
  - The player moves with the joystick; fire triggers flee.
- **Expected screen:** the enemy is green and sweeps in patrol; when the player escapes past 24
  pixels it turns gold and closes; when the chase closes to 24 pixels (or the player fires) it
  turns red and runs. The state row and the enemy color match.
- **Exercises:**
  1. **Waypoint patrol.** Patrol between X=40 and X=120 with a 30-frame pause at each end.
     Expected: `EnemyTimer` counts down at the ends; `EnemyX` holds.
  2. **Dead zone.** Chase only when the distance > 16, else patrol. Expected: `EnemyMove` A=0 in
     the dead zone; no jitter.
  3. *(Stretch)* **Flee speed.** Scale the flee speed with the right difficulty switch (2 vs 3).
     Expected: `EnemySpeed` A=3 on expert; the enemy escapes faster.
- **Screenshots:** `docs/public/images/lesson44/patrol.png`, `…/chase.png`.
- **Evidence pins:** `EnemyState` (A = state), `EnemyMove` (A = delta), `Distance` (A = distance),
  `EnemyX`, `LifeStep` (A = lives), `BodyStart`, `HmoveDone`.
- **Integration:** prev → Lesson 43; next → Lesson 45; index row 44 → ✅ Complete. Estimated
  time: 90 minutes.

## Lesson 45: Memory Management — 128 Bytes of Creativity

- **Goal:** plan the 128-byte RAM map, pack values into bits, and prove the budget.
- **Prerequisites:** Lesson 09 (bitwise operations), Lesson 11 (lookup tables), Lesson 19 (the
  playfield), Lesson 27 (joystick input), Lesson 34 (frame counters), Lesson 41 (state layouts).
- **Concepts:** the `$80–$FF` map; a 16×8 grid; bit packing; state overlays; an ACME `!if` budget
  assert; the stack reserve.
- **ROM:** `45-memory-management.asm` — "the memory map".
  - `RamMap` = 8 rows × 3 playfield bytes (24 bytes), one bit per byte `$80–$FF`; lit = used.
    The map reflects the lesson's planned allocation (lesson vars, flags, timer, score/display
    buffers).
  - Top: a 4-cell flags row at visible 0–7, chunks 2–5 (X=8–23); each cell is one `Flags` bit.
    The map uses two colors: used green `$C8`, free `$02`; the doc explains the shared/stack
    regions, which the two-color grid cannot show.
  - Grid: 8 rows × 4 lines at visible 8–39, 16 columns per half in chunks 2–17 (`PF0=$C0`,
    `PF1`, `PF2=$3F`), `CTRLPF=$01` mirrors the half; the left copy is the 128-byte map reference.
  - Left: a 15-cell timer bar (6 lines per cell) at X=24, visible 40–129; height =
    `PackedTimer >> 4` (0–15). The timer's low nibble counts frames; the high nibble counts
    16-frame ticks (the bar fills in 240 frames), not seconds.
  - The main ROM keeps four separate flag bytes (`FlagFire`, `FlagLeft`, `FlagRight`, `FlagOver`)
    and the four flags row cells read them directly. The 128-byte map includes those four bytes.
    Exercise 1 packs them into one `Flags` byte; exercise 3 adds the `RamEnd` budget assert.
- **Expected screen:** the 16×8 grid shows the used bytes; the timer bar rises; the flags row
  changes with input. The exercise-1 capture has fewer lit cells (the packed flags).
- **Exercises:**
  1. **Pack the flags.** Replace the four flag bytes with one `Flags` byte. Expected: the map
     loses three used cells; the flags row still works; `FlagsWrite` A = the packed byte.
  2. **Overlay by state.** Reuse the title-screen variables for the play state with an `!if`
     assert. Expected: the map table marks the shared bytes; `StateOverlay` documented; the build
     passes.
  3. *(Stretch)* **Budget assert.** Add an ACME `!if` on a `RamEnd` label that fails if the last
     variable exceeds `$F7`; moving a variable to `$F8` must fail the build with a clear error
     (documented).
- **Screenshots:** `docs/public/images/lesson45/map.png` (main), `…/map-packed.png` (exercise 1).
- **Evidence pins:** `MapDraw` (the first row), `FlagsWrite` (A = `Flags`), `PackTimer` (A = the
  packed byte), `FreeBytes` (the computed count), `BodyStart`, `OverscanStart`.
- **Integration:** prev → Lesson 44; next → Lesson 46; index row 45 → ✅ Complete. Estimated
  time: 75 minutes.

## Lesson 46: Debugging — Finding and Fixing Bugs

- **Goal:** recognize and fix three classic 2600 bugs with the Stella debugger.
- **Prerequisites:** Lesson 17 (cycle counting), Lesson 18 (mid-line writes), Lesson 26
  (divide-by-15 positioning), Lesson 28 (the one-`HMOVE` rule), Lesson 29 (the ball), Lesson 38
  (collision latches), Lesson 41 (state flow), Lesson 45 (the RAM map).
- **Concepts:** sticky collision latches; a 263-line frame from a WSYNC-first kernel; an off-by-one
  sprite Y; breakpoints, watches, the frame/scanline readout, `-dbg.logbreaks`.
- **ROM:** `46-debugging.asm` — "the debug lab".
  - `Mode` 0/1/2 selects the bug; `BugOn` 1 = buggy, 0 = fixed; fire toggles; left/right selects.
  - Status row: visible 0–15; three 8-line cells for the modes (the selected one bright, 2 chunks
    per half) and one 8-line bug/fix cell (red = bug, green = fixed). Play area: 16–191.
  - Scene: P0 (16 rows) moves with the joystick at Y=140; P1 (16 rows) at Y=40; the ball (8 rows)
    at X=80, Y=140 (the same scanlines as P0, so the off-by-one is visible); a playfield wall.
  - Bug 0: the `CXCLR` store is skipped; the collision band stays lit after separation.
  - Bug 1: the kernel is WSYNC-first (`STA WSYNC` then the line's writes) so `OverscanStart` is
    230 and the frame is 263 lines; the fixed path is work-first and 229.
  - Bug 2: the P0 Y compare is one line off, so the drawn sprite row is one line away from the
    game-logic Y used for the P0–ball check; the fixed path makes them agree. (The TIA has no
    collision box: collisions are between drawn pixels, and the wall spans every line.)
  - The doc walks the debugger: `stella -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'`, the
    frame/scanline/cycle columns, the TIA and RAM watches, and the `CXCLR`/frame checkpoints.
- **Expected screen:** in bug 0 the red collision band stays lit after P0 leaves the wall; in the
  fixed version it clears. In bug 1 the frame is 263 lines (`StartFrame` 260, `OverscanStart`
  230), the picture is one line low and the frame rate is ~59.8 Hz; a normal TV may hold sync, and
  whether a given set loses hold was not verified — the debugger's line count is the evidence.
  The fixed version is 262/229. In bug 2 the sprite is one line off; the fixed version aligns.
- **Exercises:**
  1. **Fix the sticky collision.** Add `STA CXCLR` after the read. Expected: the band clears;
     `CXClear` fires every frame.
  2. **Fix the frame.** Reorder the kernel to work-first. Expected: `OverscanStart` 229; 262 lines.
  3. *(Stretch)* **Fix the off-by-one.** Change the sprite's Y compare to match the game-logic Y.
     Expected: `PlayerY` and the drawn row agree; the P0–ball collision occurs on the drawn row.
- **Screenshots:** `docs/public/images/lesson46/bug-sticky.png`, `…/fix-sticky.png`.
- **Evidence pins:** `Mode`, `BugToggle` (A = `BugOn`), `ReadCX`, `CXClear`, `OverscanStart`
  (229 fixed / 230 bug), `PlayerY`, `BodyStart`, `HmoveApply`/`HmoveDone`.
- **Integration:** prev → Lesson 45; next → Lesson 47; index row 46 → ✅ Complete. Estimated
  time: 90 minutes.

## Lesson 47: Development Tools & Workflow

- **Goal:** use ACME, Make, git, and the verification pipeline as a repeatable workflow, and see
  the pipeline on screen.
- **Prerequisites:** every earlier lesson (the course's build/verify/screenshot pipeline and the
  full artifact set).
- **Concepts:** `!macro`, `!if`, `!align`, `!fill`, `!source`, labels/zones; the Makefile; git
  commits; `scripts/verify.sh`; Stella's debugger and symbol files; `npm run roms`.
- **ROM:** `demo-47.asm` — "the build dashboard" (the theory lesson's demo).
  - Five 16-line stages (EDIT, ASSEMBLE, RUN, VERIFY, COMMIT) stacked, visible 0–79; the active
    stage is green, the completed ones dim gold, the future ones `$02`. Gap 80–87.
  - A 15-cell progress bar (6 lines per cell) at visible 88–177 showing the stage count, **15
    chunks per half**; gap 178–183; an 8-cell checksum row at visible 184–191, **8 cells per
    half**, showing the low byte of `CheckSum` (the 8-bit sum of the 256-byte `CheckData` table).
    `CTRLPF=$01`; the left half is the reference. Total: 80+8+90+6+8 = 192.
  - `Stage` increments every 30 frames; at 5 it pauses 60 frames and restarts. Fire advances;
    SELECT resets.
  - Uses a `StageBlock` `!macro` for the five blocks and `!if DEBUG` to add a red border when
    `DEBUG=1`; the release build (`DEBUG=0`) has no border.
  - The doc cross-checks `CheckSum` with a Python sum and an ACME `!warn`/`!error` example.
- **Expected screen:** stage 2 (ASSEMBLE) shows the first two bands green/dim gold and the
  progress bar at 2 cells per half; stage 4 (VERIFY) shows four bands and 4 cells per half. The
  checksum row is a stable 8-cell pattern per half.
- **Exercises:**
  1. **Add a stage.** Add a TEST stage with the `StageBlock` macro; expected: six blocks and a
     six-step progress bar; `StageStep` A reaches 5.
  2. **Conditional build.** Make the border color depend on `DEBUG`: red for the debug build,
     green for the release build, with a `BuildFlag` cell. Expected: `BuildFlag` A=1/0 and the
     two builds' borders differ; both assemble to 4,096 bytes.
  3. *(Stretch)* **Rotated checksum.** Replace the sum with an 8-bit rotate-right-and-add over
     `CheckData`; expected: the new `CheckSum` matches a Python cross-check and the 8-cell row is
     stable but different from the main ROM's.
- **Screenshots:** `docs/public/images/lesson47/stage2.png`, `…/stage4.png`.
- **Evidence pins:** `StageStep` (A = stage), `BuildFlag` (A = `DEBUG`), `CheckSum` (A = the sum),
  `BodyStart`, `OverscanStart`. The demo is the only ROM in this lesson (plus three exercise
  solutions).
- **Integration:** prev → Lesson 46; next → `/part7-kernel-mastery/48-introduction-to-kernels`
  (the real Part 7 stub); index row 47 → ✅ Complete. Estimated time: 90 minutes.

## Cross-Lesson Consistency

- **Progression:** 38 reads collisions; 39 displays a score and 40 does BCD; 41 structures states;
  42 scales difficulty; 43 adds randomness; 44 adds AI; 45 manages RAM; 46 debugs; 47 automates.
  No lesson uses a later lesson's mechanism in code.
- **Naming:** main sources are `NN-slug.asm`; solutions are `exercise-01-solution.asm` …
  `exercise-03-solution.asm`; Lesson 47's main is `demo-47.asm`.
- **Visual language:** the same 15-cell meter, 8-line status row, one-HMOVE positioning (only
  where sprites are placed; 43/45/47 are playfield-only), and `$02` background recur across the
  ten monitors.
- **Logic honesty:** every collision/score/state/LFSR/AI/memory claim cites the checkpoint and the
  measured value; screenshots are never described as proof of logic.
- **Part 6 index:** rows 38–47 with What You'll Learn summaries; row 38 flips in Phase 1 and rows
  39–47 start `🔒 Coming Soon` and flip in their own lesson commits (AR-10).
