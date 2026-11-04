# Testing Strategy: Part 4 — Sprites (Lessons 25–34)

> **Document**: 07-testing-strategy.md
> **Parent**: [Index](00-index.md)

## Testing Overview

This repository ships static lesson content and ROMs; there is no test framework, and none is
added (AR-7). The specification tests are **observational acceptance cases**: every ST row names
a concrete action (assemble, run, inspect, capture, break) and a concrete expected outcome that
can be confirmed by a human or by recorded command output. Session A freezes the rows for its
lesson before implementation and records the red baseline; Session C confirms every row and
records the evidence (AR-2, AR-4).

Expected outcomes here derive only from [03-lesson-specs.md](03-lesson-specs.md) and the
register — never from the implementation (immutable-oracle rule). If an implementation disagrees
with an ST row, the implementation is wrong.

**Evidence methods:** `bash scripts/verify.sh` output (assembly + drift + docs build); screenshots
captured from the committed ROM path and pixel-checked against the sprite geometry
(`x = 25 + 6·X`; picture rows 107–711); timed waits/bursts for moving or switching states; and
Stella state logs (`stella -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'`, format
`BP: <frame> <scanline> <cycles> <pixels> | <flags> <A> <X> <Y> <SP> |`) with the static cycle
ledgers — the timing standard of AR-6 (including the `hit cycle` = the cycle of the instruction
after a store, learned in Lesson 18).

> Rows quote behavioral expectations in self-contained language so they can be handed to a
> reviewer without further interpretation.

## 🚨 Specification Test Cases (frozen per lesson in Session A)

### Lesson 25

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-25.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output + file size | RD-04 AC 1–2 / AR-4 |
| ST-25.2 | Run the ROM; inspect the frame | One red 8×8 invader on dark; measured X within ±4 of 81 (capture x ≈ 511); first body line scanline 117 (capture y ≈ 359); 8 scanlines tall; 48 capture px wide | Screenshot `first-sprite.png` + pixel check | 03 §Lesson 25 |
| ST-25.3 | Inspect the shape and colors | Shape bytes `$18,$3C,$7E,$DB,$FF,$24,$5A,$A5` top-to-bottom, `COLUP0=$42` red, `COLUBK=$02`; the playfield is off | Capture pixel check + state log | 03 §Lesson 25 |
| ST-25.4 | Debugger: frame checkpoints and `BodyStart` | `StartFrame` 259, `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229 (262 lines); `BodyStart` at scanline 117, cycle 6, 8 hits per frame; `SpriteWrite` A = the row byte | State log + static ledger (AR-6) | RD-04 AC 3 / 03 §Lesson 25 |
| ST-25.5 | Assemble and run each solution | Ex 1 moves the sprite to ≈ capture y 485; ex 2 mirrors it at the same span; ex 3 draws two creatures 40 scanlines apart | `verify.sh` + manual runs + captures | RD-04 AC 1 / AR-8 |
| ST-25.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the committed ROM; the capture resolves; prev (24) and next (26) links resolve; part-index row 25 links the lesson | Build output + page check | RD-04 AC 1 / AR-10 |

### Lesson 26

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-26.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output + file size | RD-04 AC 1–2 / AR-4 |
| ST-26.2 | Run the ROM; capture position A | The invader's measured X is within ±3 of 16 (capture x ≈ 121), at scanlines 117–124 | Screenshot `position-a.png` + pixel check | 03 §Lesson 26 |
| ST-26.3 | Capture position B later in the tour | The measured X is within ±3 of one of the five targets (16/48/80/112/144; capture x ≈ 121/313/505/697/889), and the two captures differ by at least 24 px; `PosStep` advances every 60 frames through the table | Screenshot `position-b.png` + state log | 03 §Lesson 26 |
| ST-26.4 | Debugger: `SetHorizPos` ledger | `PosStep` A = index every 60 frames; `PosApply` A = the table value (target + the 3-pixel output-delay bias) every frame; `Resp0Write` one hit per frame, its cycle advancing with the table (24/34/44/54/64); `HmoveApply` on the next VBLANK line at cycle 0 (effect 3); the divide-by-15 ledger is in the doc | State log + static ledger (AR-6, AR-13) | RD-04 AC 3 / 03 §Lesson 26 |
| ST-26.5 | Assemble and run each solution | Ex 1 parks at X≈120; ex 2 at X≈152; ex 3 ping-pongs 32↔128 every 60 frames | `verify.sh` + manual runs + captures | RD-04 AC 1 / AR-8 |
| ST-26.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the ROM; both captures resolve; prev 25, next 27; index row 26 links | Build output + page check | RD-04 AC 1 / AR-10 |

### Lesson 27

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-27.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output + file size | RD-04 AC 1–2 / AR-4 |
| ST-27.2 | Run the ROM with no joystick input; capture two times | The invader patrols horizontally; the two captures' measured X values match the logged `MoveTick` positions and differ by at least 24 px; the sprite stays at the same scanlines | Screenshots `patrol-a/b.png` + state log | 03 §Lesson 27 |
| ST-27.3 | Hold left or right in Stella (or force the input byte with a scratch witness) | Left (bit 6) → direction `$FF`; right (bit 7) → `$01`; at X=144/16 it bounces; both pressed → direction 0 (no movement); the no-input patrol keeps the last direction | Scratch witness + `DirWrite` log | 03 §Lesson 27 |
| ST-27.4 | Debugger: movement checkpoints | `MoveTick` one hit per frame, A = the new X; `DirWrite` while a horizontal input is held (0 hits in the no-input patrol); `PosApply` A = X + 3; frame 259/0/37/229 | State log + static ledger (AR-6) | RD-04 AC 3 / 03 §Lesson 27 |
| ST-27.5 | Assemble and run each solution | Ex 1 moves 2 px/frame; ex 2 bounds 8/152; ex 3 moves vertically with up/down and keeps the horizontal patrol | `verify.sh` + manual runs + captures | RD-04 AC 1 / AR-8 |
| ST-27.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the ROM; both captures resolve; prev 26, next 28; index row 27 links | Build output + page check | RD-04 AC 1 / AR-10 |

### Lesson 28

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-28.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output + file size | RD-04 AC 1–2 / AR-4 |
| ST-28.2 | Run the ROM; inspect the frame | Two 8×8 sprites on scanlines 125–132; P0 red within ±3 of X=48 (capture x ≈ 313), P1 blue within ±3 of X=104 (≈649); dark background | Screenshot `two-players.png` + pixel check | 03 §Lesson 28 |
| ST-28.3 | Inspect shapes and priority | P0 shape `$18,$3C,$7E,$DB,$FF,$24,$5A,$A5`; P1 shape `$3C,$7E,$FF,$DB,$FF,$66,$3C,$18`; overlapping players show P0's color on top | Capture + state log | 03 §Lesson 28 |
| ST-28.4 | Debugger: both positions | `PosApply0`/`PosApply1` one hit per frame each; `Resp0Write`/`Resp1Write` constant cycles; `BodyStart` line 125; frame 262 lines | State log + static ledger (AR-6, AR-13) | RD-04 AC 3 / 03 §Lesson 28 |
| ST-28.5 | Assemble and run each solution | Ex 1 swaps colors; ex 2 moves to X=16/140; ex 3 overlaps at X=80 with P0 on top | `verify.sh` + manual runs + captures | RD-04 AC 1 / AR-8 |
| ST-28.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the ROM; the capture resolves; prev 27, next 29; index row 28 links | Build output + page check | RD-04 AC 1 / AR-10 |

### Lesson 29

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-29.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output + file size | RD-04 AC 1–2 / AR-4 |
| ST-29.2 | Run the ROM; inspect the lineup | P0 8×8 red at X≈24 (capture ≈169), M0 1 px red at X≈64 (≈409), M1 4 px blue at X≈96 (≈601), ball 8 px green at X≈128 (≈793); measured widths 6/24/48 capture px for 1/4/8 px; all within ±3 | Screenshot `lineup.png` + pixel check | 03 §Lesson 29 |
| ST-29.3 | Inspect enable/size state | `ENAM0`/`ENAM1`/`ENABL` set only on the body lines; `NUSIZ0=$00`, `NUSIZ1=$20`, `CTRLPF=$30`; M0 red, M1 blue, ball green | Capture + state log | 03 §Lesson 29 |
| ST-29.4 | Debugger: four positions and enables | `PosApply*` one hit per frame each; `EnableWrite` on the body lines; the missile/ball `RESxx` cycles are constant and the doc records the output-delay difference; frame 262 lines | State log + static ledger (AR-6, AR-13) | RD-04 AC 3 / 03 §Lesson 29 |
| ST-29.5 | Assemble and run each solution | Ex 1 widens M0 to 8 px; ex 2 shrinks/moves the ball (measured X=79); ex 3 moves M0 from 16 to 150 and wraps at 152 | `verify.sh` + manual runs + captures | RD-04 AC 1 / AR-8 |
| ST-29.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the ROM; the capture resolves; prev 28, next 30; index row 29 links | Build output + page check | RD-04 AC 1 / AR-10 |

### Lesson 30

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-30.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build pass | `verify.sh` output + file size | RD-04 AC 1–2 / AR-4 |
| ST-30.2 | Run the ROM; inspect the sprite | One 8×16 sprite at X≈72 (capture ≈457), scanlines 117–132 (capture y ≈359–409); gold `$1A` rows 0–3, blue `$84` rows 4–11, red `$42` rows 12–15 | Screenshot `multicolor.png` + pixel check | 03 §Lesson 30 |
| ST-30.3 | Inspect shape and row extent | The shape table has 16 rows, one per sprite line (some bytes repeat); the sprite spans exactly 16 scanlines with no first-line artifact | Capture + `SpriteWrite` log | 03 §Lesson 30 |
| ST-30.4 | Debugger: per-line color | `ColorWrite` 16 hits per frame with A = the table byte and 4/8/4 runs; `BodyStart` line 117; body ledger totals 24 cycles | State log + static ledger (AR-6) | RD-04 AC 3 / 03 §Lesson 30 |
| ST-30.5 | Assemble and run each solution | Ex 1 adds white shoes; ex 2 slides the color bands with the shape fixed; ex 3 draws the 16-px two-color figure | `verify.sh` + manual runs + captures | RD-04 AC 1 / AR-8 |
| ST-30.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the ROM; the capture resolves; prev 29, next 31; index row 30 links | Build output + page check | RD-04 AC 1 / AR-10 |

### Lesson 31

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-31.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build pass | `verify.sh` output + file size | RD-04 AC 1–2 / AR-4 |
| ST-31.2 | Run the ROM; inspect the eight bands | Eight 24-line bands (≈76 capture px each) from scanline 37; each band shows the correct mode: one bar, two at 16/32/64 clocks, three, double width, quad width; first bar at capture x = 283 | Screenshot `nusiz-bands.png` + pixel check | 03 §Lesson 31 |
| ST-31.3 | Measure copy spacing and widths | Copy spacings are 16/32/64 color clocks (96/192/384 capture px start to start; the empty gaps are 84/180/372); the pattern's two pixels are 12 px wide normally, 24 px double, 48 px quad; no missile appears | Capture pixel check | 03 §Lesson 31 |
| ST-31.4 | Debugger: band writes | `BandWrite` 192 hits per frame (A = the table value); the A runs change at scanlines 37, 61, 85, 109, 133, 157, 181, 205; `PatternWrite` 192 hits per frame; frame 262 lines | State log + static ledger (AR-6) | RD-04 AC 3 / 03 §Lesson 31 |
| ST-31.5 | Assemble and run each solution | Ex 1 uses `$FF` and shows contiguous copies with gaps; ex 2 splits P0/P1 modes; ex 3 animates the modes | `verify.sh` + manual runs + captures | RD-04 AC 1 / AR-8 |
| ST-31.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the ROM; the capture resolves; prev 30, next 32; index row 31 links | Build output + page check | RD-04 AC 1 / AR-10 |

### Lesson 32

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-32.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build pass | `verify.sh` output + file size | RD-04 AC 1–2 / AR-4 |
| ST-32.2 | Run the ROM; measure the two sprites | P0 red at X≈48, P1 blue at X≈104; P0's 16 rows start at scanline 125, P1's at 126; P1's top row is exactly one scanline below P0's (≈3 capture px); P1's clear is one line later | Screenshot `vdel.png` + pixel check | 03 §Lesson 32 |
| ST-32.3 | Inspect VDEL state | `VDELP1=$01`; the body writes both graphics every line; a clear line writes 0 to both; the shape is the 16-row stripe | State log + capture | 03 §Lesson 32 |
| ST-32.4 | Debugger: body and writes | `BodyStart` line 125; the body's GRP0/GRP1 stores at constant cycles; `VdelWrite` A = `$01`; frame 262 lines | State log + static ledger (AR-6) | RD-04 AC 3 / 03 §Lesson 32 |
| ST-32.5 | Assemble and run each solution | Ex 1 aligns the players (VDEL off); ex 2 drops P0; ex 3 descends 4 lines per 30 frames with a constant one-line offset | `verify.sh` + manual runs + captures | RD-04 AC 1 / AR-8 |
| ST-32.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the ROM; the capture resolves; prev 31, next 33; index row 32 links | Build output + page check | RD-04 AC 1 / AR-10 |

### Lesson 33

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-33.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build pass | `verify.sh` output + file size | RD-04 AC 1–2 / AR-4 |
| ST-33.2 | Run the ROM; inspect the monitor at rest | Green 8-column matrix strip in chunks 4–11 (reflected; dark with no keys); red 32-line needle at X≈24 (capture ≈169; the read times out to 0 at rest); green 8×8 fire block at X≈140 (≈865); dark background | Screenshot `monitor.png` + pixel check | 03 §Lesson 33 |
| ST-33.3 | Paddle read without a controller | The read terminates at `CPY #128` and stores 0 on timeout (documented as "no paddle or minimum"); the needle X is `PaddleValue + 24` (24–152); the ROM never hangs; the fire block stays green with no fire press; a scratch witness forcing INPT0 low exercises the timeout branch | `PaddleRead`/`PaddleX` log + scratch witness | 03 §Lesson 33 |
| ST-33.4 | Debugger: input state and one HMOVE | `PaddleRead` one hit per frame, A = the final count (0–128); `PaddleX` A = the needle X; `KeyWrite` A = the inverted `SWCHA`; `FireWrite` A = `$C8`/`$42`; `MoveApply` one `HMOVE` per frame after both positions (AR-21); frame 262 lines; the VBLANK ledger records the worst-case read plus positions | State log + static ledger (AR-6, AR-19, AR-21) | RD-04 AC 3 / 03 §Lesson 33 |
| ST-33.5 | Assemble and run each solution | Ex 1 uses `INPT1`; ex 2 widens/golds the fire block; ex 3 has two independent needles with one `HMOVE` | `verify.sh` + manual runs + captures | RD-04 AC 1 / AR-8 |
| ST-33.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the ROM; the capture resolves; prev 32, next 34; index row 33 links | Build output + page check | RD-04 AC 1 / AR-10 |

### Lesson 34

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-34.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build pass | `verify.sh` output + file size | RD-04 AC 1–2 / AR-4 |
| ST-34.2 | Run the ROM; capture two walk phases | One 8×16 red figure at X≈72 (capture ≈457), scanlines 117–132; the two captures differ in the leg rows (frame indices differ, leg pixels differ) | Screenshots `walk-a/b.png` + pixel diff | 03 §Lesson 34 |
| ST-34.3 | Inspect cadence and direction | `AnimStep` one hit every 8 frames through 0..3; `REFP0` toggles every 120 frames; the frame base pointer is computed in VBLANK | State log + capture | 03 §Lesson 34 |
| ST-34.4 | Debugger: frame pointer and body | `AnimStep` A = frame index; `FramePtrWrite` A = the frame base low byte; `BodyStart` line 117; the body ledger is 18–19 cycles (page-crossing `(zp),Y`); frame 262 lines | State log + static ledger (AR-6) | RD-04 AC 3 / 03 §Lesson 34 |
| ST-34.5 | Assemble and run each solution | Ex 1 changes cadence; ex 2 holds an idle pose for 60 frames; ex 3 walks across the screen | `verify.sh` + manual runs + captures | RD-04 AC 1 / AR-8 |
| ST-34.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the ROM; both captures resolve; prev 33, next `/part5-sound/35-sound-effects`; index row 34 links | Build output + page check | RD-04 AC 1 / AR-10 |

## Red phase (Session A, every lesson)

1. Re-affirm the lesson's ST rows against [03-lesson-specs.md](03-lesson-specs.md).
2. Record the red baseline: no lesson sources, no images, no committed ROMs, stub document; the
   part-index row is "Coming Soon" (Lesson 25's phase also rebuilds the index); capture the tree
   state.
3. For every lesson that positions a sprite, restate the requested X and the ±3/±4 tolerance
   before implementation; the measured value is Session C's evidence.

## Green phase (Session C, every lesson)

1. `bash scripts/verify.sh` green (assembly, drift, docs build).
2. Every ST row confirmed with recorded evidence; positioning and timing rows carry the state log
   + ledger.
3. Edge checks: frame integrity (steady scanline at the frame top; blank-on in HBLANK) plus the
   lesson's specific pixel checks.
4. Both specialist reviews recorded; no critical/major findings may remain open (AR-5).

## Verification Checklist (plan level)

- [ ] All specification test cases defined with concrete input/output pairs, traced to specs/ARs
- [ ] Session A freezes each lesson's ST set with a red baseline before implementation
- [ ] Specification expectations are never edited to match an implementation
- [ ] `bash scripts/verify.sh` passes for every lesson commit (AR-4)
- [ ] Every sprite positioning/timing claim carries a state-log observation plus a static cycle
      ledger (AR-6, AR-13)
- [ ] Screenshots captured from committed ROM paths; titles verified; states pixel-checked
- [ ] Committed ROMs regenerate byte-identically (`npm run roms`; drift check clean)
- [ ] Both reviewers report no critical/major findings per lesson (AR-5)
- [ ] Part index rows flip per lesson; README verified unchanged (AR-10)
- [ ] Each lesson's page renders with a working `<RomPlayer>` and prev/next links (ST-NN.6)
