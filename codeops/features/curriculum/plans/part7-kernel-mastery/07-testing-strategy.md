# Testing Strategy: Part 7 — Kernel Mastery (Lessons 48–55)

> **Document**: 07-testing-strategy.md
> **Parent**: [Index](00-index.md)

## Testing Overview

This repository ships static lesson content and ROMs; there is no test framework, and none is
added (AR-7). The specification tests are **observational acceptance cases**: every ST row names
a concrete action (assemble, run, inspect, capture, break) and a concrete expected outcome that a
human or recorded command output can confirm. Session A freezes the rows for its lesson before
implementation and records the red baseline; Session C confirms every row and records the evidence
(AR-2, AR-4).

Expected outcomes here derive only from [03-lesson-specs.md](03-lesson-specs.md) and the register
ground truth — never from the implementation (immutable-oracle rule). If an implementation
disagrees with an ST row, the implementation is wrong.

**Evidence methods:** `bash scripts/verify.sh` output (assembly + drift + docs build); screenshots
captured from the committed ROM path and pixel-checked against the monitor geometry
(`x = 25 + 6·X`; `y = 107 + 3.15·visible_line`; picture rows 107–711); timed waits/bursts for
moving or switching states; and Stella state logs
(`stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'`, format
`BP: <frame> <scanline> <cycles> <pixels> | <flags> <A> <X> <Y> <SP> |`) with static cycle ledgers.
Logic rows use a breakpoint after the store/read; the A column is the value.

> A screenshot proves the visual state only. The runnable artifact is the committed ROM and the
> `<RomPlayer>`; the tests below never claim otherwise. The lesson docs tell the reader to click the
> player screen once to unmute Javatari.

## 🚨 Specification Test Cases (frozen per lesson in Session A)

### Lesson 48 — Introduction to Kernels

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-48.1 | Assemble `demo-48.asm` and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-07 AC 1–2 / AR-4 |
| ST-48.2 | Run the demo in mode 0; inspect the split | Visible 0–95 is a 1-line zone (96 rows) and visible 96–191 is a 2-line zone (48 rows); the same 96-line diamond is smooth on top and chunky below; the top dash is 1 line and the bottom dash 2 lines; mode 2 shows the full 2-line diamond | Screenshots `split.png`, `full-two-line.png` + pixel check | 03 §Lesson 48 |
| ST-48.3 | Inspect the modes and row counters | `Mode` A=0/1/2 on fire; `ZoneCount` 2 (split) / 1 (full); `LineCount` 96 (split 1-line) / 192 (full 1-line); `PairCount` 48 (split 2-line) / 96 (full 2-line); the auto-demo cycles every 240 frames | State log + static ledger | RD-07 AC 3 / 03 §Lesson 48 |
| ST-48.4 | Debugger: frame and kernels | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229 (262 lines; the measured cycle is recorded); `LineRow`/`PairRow` advance once per row (0→N−1); `HmoveDone` once per frame | State log + static ledger (AR-6) | RD-07 AC 3 / 03 §Lesson 48 |
| ST-48.5 | Assemble and run each solution | Ex 1: three zones 64+64+64 = 192, `ZoneCount` 3; ex 2: a rectangle, the 1-line edge crisp and the 2-line edge stepped; ex 3: mode 3 with 8+176+8 = 192 | `verify.sh` + manual runs + captures | RD-07 AC 1 / AR-24 |
| ST-48.6 | Build the site and inspect the page | Part index row 48 ✅ Complete; page prev 47, next 49; both images and `<RomPlayer>` render; sidebar `config.ts:125`; README unchanged | `npm run docs:build` + page check | RD-07 AC 1 / AR-10 |

### Lesson 49 — The 2-Line Kernel

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-49.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-07 AC 1–2 / AR-4 |
| ST-49.2 | Run the ROM; inspect the landscape | A 96-row mountain range (2 lines per row), the sky gradient (not `$02`), a 16-line figure on P0, a 16-line bird on P1; the figure moves with the joystick and the auto-demo sweep | Screenshots `landscape.png`, `figure-right.png` + pixel check | 03 §Lesson 49 |
| ST-49.3 | Inspect the kernel and cycle ledger | `KernelRow` Y=0→95 (96 rows, `LDY #0; INY; CPY #96; BNE`); `RowWrite` fires once per row; the ledger is 62 cycles nominal / 63 effective per 2 lines (31.5/line), 89 cycles of margin per pair (44.5/line); `P0X` clamps 8–144; `P1X` is fixed at 104 | State log + static ledger | RD-07 AC 3 / 03 §Lesson 49 |
| ST-49.4 | Debugger: frame and positioning | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229 (262 lines; the measured cycle is recorded); `HmoveApply`/`HmoveDone` once per frame; P0/P1 X measured | State log + static ledger (AR-6) | RD-07 AC 3 / 03 §Lesson 49 |
| ST-49.5 | Assemble and run each solution | Ex 1: the same picture with a 2-row iteration (four `WSYNC`s, `KernelRow` +2, 119 cycles/4 lines); ex 2: `P0X` moves 2/frame and the picture is stable; ex 3: `NUSIZ0=3`, three 16-line figures, the bird still on P1 | `verify.sh` + manual runs + captures | RD-07 AC 1 / AR-24 |
| ST-49.6 | Build the site and inspect the page | Part index row 49 ✅ Complete; page prev 48, next 50; both images and `<RomPlayer>` render; sidebar `config.ts:126`; README unchanged | `npm run docs:build` + page check | RD-07 AC 1 / AR-10 |

### Lesson 50 — Multi-Zone Kernel

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-50.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-07 AC 1–2 / AR-4 |
| ST-50.2 | Run the ROM; inspect the zones | Score zone visible 0–8 (six white digits), status 9–16 (a mirrored pair of gold level bars), play 17–190 (red P0 32 scanlines, green P1 32 scanlines, gold ball 8 lines, floor/ceiling), ground 191; background `$02`; the HMOVE notch is 8 black pixels at chunks 0–1 on status line 51 | Screenshots `dashboard.png`, `level4.png` + pixel check | 03 §Lesson 50 |
| ST-50.3 | Inspect the zones, score, and HMOVEs | `ScoreDraw` starts at visible 0; `StatusStart` 46 (37+9), `PlayStart` 54 (37+17), `GroundStart` 228 (37+191), `OverscanStart` 229; `ScoreAdd` A = the low digit; `LevelWrite` A = level; `ScoreHmove` and `GameHmove` both in HBLANK; `HMBL` is cleared after `ScoreHmove`, so `GameHmove` does not re-apply the ball offset; the game players use `NUSIZ=0` (one copy) | State log + static ledger | RD-07 AC 3 / 03 §Lesson 50 |
| ST-50.4 | Debugger: frame and collision | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5 (262 lines); `CXP0FB` bit 6 read in VBLANK then `CXCLR`; `BallY` falls and respawns | State log + static ledger (AR-6) | RD-07 AC 3 / 03 §Lesson 50 |
| ST-50.5 | Assemble and run each solution | Ex 1: 9+12+170+1 = 192 (`StatusStart` 46, `PlayStart` 58, `GroundStart` 228); ex 2: 9+16+166+1 = 192 (`PlayStart` 62); ex 3: the `ZoneTable` asserts pass and a wrong total fails | `verify.sh` + manual runs + captures | RD-07 AC 1 / AR-24 |
| ST-50.6 | Build the site and inspect the page | Part index row 50 ✅ Complete; page prev 49, next 51; both images and `<RomPlayer>` render; sidebar `config.ts:127`; README unchanged; `include/score.asm` sourced | `npm run docs:build` + page check | RD-07 AC 1 / AR-10 |

### Lesson 51 — Flicker Sprites

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-51.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-07 AC 1–2 / AR-4 |
| ST-51.2 | Run the ROM; inspect the two flicker halves | Parity 0 shows objects 0/1; parity 1 shows 2/3; the status cells show the parity and the two drawn objects; four colorful 8-line objects; background `$02`; the play zone is 184 lines (92 rows × 2) | Screenshots `frame-a.png`, `frame-b.png` + pixel check | 03 §Lesson 51 |
| ST-51.3 | Inspect the flicker scheduler and skipdraw | `Parity` A=0/1 alternating each frame; `DrawSlot0` A=1/3 and `DrawSlot1` A=0/2; the 2-line kernel draws the P0-slot object on the first line and the P1-slot object on the second by the `row - ObjRow` skipdraw test (no RAM strips); the larger Y (nearer) of a parity pair is on P0; `SkipWrite` A = the shape byte or 0; the measured lines are 48 and 41 cycles (each ≤76) | State log + static ledger | RD-07 AC 3 / 03 §Lesson 51 |
| ST-51.4 | Debugger: frame and positioning | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `PlayStart` 45/4, `OverscanStart` 229/6 (262 lines); `HmoveDone` once per frame; the play zone is 184 lines | State log + static ledger (AR-6) | RD-07 AC 3 / 03 §Lesson 51 |
| ST-51.5 | Assemble and run each solution | Ex 1: `SortFirst` A = the farther object (reverse priority); ex 2: six objects, `Parity` 0/1/2; ex 3: P0 always on, three enemies alternate | `verify.sh` + manual runs + captures | RD-07 AC 1 / AR-24 |
| ST-51.6 | Build the site and inspect the page | Part index row 51 ✅ Complete; page prev 50, next 52; both images and `<RomPlayer>` render; sidebar `config.ts:128`; README unchanged | `npm run docs:build` + page check | RD-07 AC 1 / AR-10 |

### Lesson 52 — Fine Scrolling

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-52.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-07 AC 1–2 / AR-4 |
| ST-52.2 | Run the ROM; inspect the tunnel and ship | A green tunnel with a dark central gap whose width breathes as it scrolls upward one line per frame; a white 16-line ship at the bottom moving one pixel per frame; background `$02`; the captures measure phase 0 and phase 8 (ScrollY 0 and 40 mod 32), and the ship is at X=48 and X=88 | Screenshots `tunnel-a.png`, `tunnel-b.png` + pixel check | 03 §Lesson 52 |
| ST-52.3 | Inspect the scroll and the cycle ledger | `ScrollY` increments 1/frame; `WorldRead` A = the first `WorldPF0` byte; `ShipX` moves 1/frame and clamps 24–136; the 1-line kernel is **40 cycles nominal / 41 effective** (the taken BNE crosses a page; exercise 1's page-local BNE is 40); the three planes are page-aligned and indexed by the same X; a ScrollY 255→0 wrap keeps the picture continuous | State log + static ledger | RD-07 AC 3 / 03 §Lesson 52 |
| ST-52.4 | Debugger: frame and positioning | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229 (262 lines; the measured cycle is recorded); `HmoveApply`/`HmoveDone` once per frame | State log + static ledger (AR-6) | RD-07 AC 3 / 03 §Lesson 52 |
| ST-52.5 | Assemble and run each solution | Ex 1: `ScrollY` counts down and wraps 0→255, its page-local BNE keeps the body at 40; ex 2: `ScrollStep` A=2 and ScrollYWrite 2,4,6,8…; ex 3: `ShipStep` alternates 0/1 with ShipX 80,81,81,82,82… | `verify.sh` + manual runs + captures | RD-07 AC 1 / AR-24 |
| ST-52.6 | Build the site and inspect the page | Part index row 52 ✅ Complete; page prev 51, next 53; both images and `<RomPlayer>` render; sidebar `config.ts:129`; README unchanged | `npm run docs:build` + page check | RD-07 AC 1 / AR-10 |

### Lesson 53 — Kernel Design Patterns

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-53.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes; `include/kernel_patterns.asm` is sourced | `verify.sh` + file size | RD-07 AC 1–2 / AR-4 |
| ST-53.2 | Run the ROM; inspect the four bands | Four 48-line bands: solid fill, striped PF rows, a moving sprite on a dark band, a color ramp; fire changes the palette; background `$02` | Screenshots `sampler.png`, `palette.png` + pixel check | 03 §Lesson 53 |
| ST-53.3 | Inspect the library calls and the ledgers | `PatternStart` A=0/1/2/3; `KernelRows` and `KernelPtr` set per band; the four routines execute; the ledgers are fill 11/line, PF rows 57/row (28.5/line), sprite strip 19/line, color ramp 19/line; `KernelPFRows` uses Y=0..2 (PF0→PF1→PF2) and decrements `KernelRows`; the band boundaries clear the dirty registers (PF0–PF2 before the sprite band, GRP0 and defensively GRP1 before the ramp); the sprite stamp clamps 1–40 | State log + static ledger | RD-07 AC 3 / 03 §Lesson 53 |
| ST-53.4 | Debugger: frame and library state | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229 (262 lines; the measured cycle is recorded); `KernelPtr`/`KernelRows` observed at each band; the library owns `$80–$82` | State log + static ledger (AR-6) | RD-07 AC 3 / 03 §Lesson 53 |
| ST-53.5 | Assemble and run each solution | Ex 1: five bands 38+38+38+38+40 = 192; ex 2: `RampPhase` 0/24 and the gradient rotates; ex 3: the reordered bands use the same routines and the build passes | `verify.sh` + manual runs + captures | RD-07 AC 1 / AR-24 |
| ST-53.6 | Build the site and inspect the page | Part index row 53 ✅ Complete; page prev 52, next 54; both images and `<RomPlayer>` render; sidebar `config.ts:130`; README unchanged; `include/kernel_patterns.asm` exists | `npm run docs:build` + page check | RD-07 AC 1 / AR-10 |

### Lesson 54 — Visual Effects Cookbook

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-54.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` + file size | RD-07 AC 1–2 / AR-4 |
| ST-54.2 | Run the ROM; inspect the effects | Effect 0: a scrolling starfield with a ship and three 1-px ball/missile stars; effect 1: a full-screen rainbow with a playfield sun block and a black horizon; effect 2: a centred road rushing to the horizon with a car, base width 4→12 and pulse to 16; the borders are `$02` | Screenshots `starfield.png`, `road.png` + pixel check | 03 §Lesson 54 |
| ST-54.3 | Inspect the effect clock and the motion | `Effect` A=0/1/2; `EffectTimer` 240; `StarScroll` advances every 2 frames, `RainbowShift` every 4, `RoadScroll` every frame; `WidthIndex` and `Twinkle`; the measured ledgers are starfield 54/62, rainbow 18 (27/22/33 at the boundaries), road 26–47 | State log + static ledger | RD-07 AC 3 / 03 §Lesson 54 |
| ST-54.4 | Debugger: frame and effect switch | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229 (262 lines; the measured cycle is recorded); fire advances and SELECT resets | State log + static ledger (AR-6) | RD-07 AC 3 / 03 §Lesson 54 |
| ST-54.5 | Assemble and run each solution | Ex 1: `TwinkleMask` toggles and some stars go dark; ex 2: `RainbowShift` advances every 2 frames; ex 3: `CenterLine` moves with the road | `verify.sh` + manual runs + captures | RD-07 AC 1 / AR-24 |
| ST-54.6 | Build the site and inspect the page | Part index row 54 ✅ Complete; page prev 53, next 55; both images and `<RomPlayer>` render; sidebar `config.ts:131`; README unchanged | `npm run docs:build` + page check | RD-07 AC 1 / AR-10 |

### Lesson 55 — Scrolling Text Marquee

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-55.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes; `include/score.asm` is sourced | `verify.sh` + file size | RD-07 AC 1–2 / AR-4 |
| ST-55.2 | Run the ROM; inspect the marquee | A white six-character text banner in the 48-px cell block (x=361–648; the lit glyphs measure x=361–630 at offset 0 and x=361–582 at offset 40, y=109–130) reading "RACING" at offset 0 and "G THE " at offset 40; a 183-line starfield with a gold 1-px shooting star; background `$02` | Screenshots `marquee-a.png`, `marquee-b.png` + pixel check | 03 §Lesson 55 |
| ST-55.3 | Inspect the text fill and the scroll | `ScrollOffset` 0–88, one pixel every two frames; `TextRow` 0–7 and `TextCol` 0–5; `TextFill` writes 48 bytes to `ScoreBuf` at `c*8+r`; the pre-shifted table selects the phase | State log + static ledger | RD-07 AC 3 / 03 §Lesson 55 |
| ST-55.4 | Debugger: frame and score zone | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `ScoreDraw` 37/11, `ScoreDrawRow` 37/26, `OverscanStart` 229 (262 lines; the measured cycle is recorded); `HmoveDone` once per frame | State log + static ledger (AR-6) | RD-07 AC 3 / 03 §Lesson 55 |
| ST-55.5 | Assemble and run each solution | Ex 1: the new message scrolls (`MESSAGE_LEN` 14, wrap 64); ex 2: `ScrollOffset` advances 1/frame; ex 3: two 9-line bands plus 171 starfield lines + 3 setup lines = 192, and the second band re-runs `ScoreSetup` before `ScoreDraw` | `verify.sh` + manual runs + captures | RD-07 AC 1 / AR-24 |
| ST-55.6 | Build the site and inspect the page | Part index row 55 ✅ Complete; page prev 54, next `/part8-advanced/56-bankswitching`; both images and `<RomPlayer>` render; sidebar `config.ts:132`; README unchanged | `npm run docs:build` + page check | RD-07 AC 1 / AR-10 |

## Verification Commands

| Purpose | Command |
| --- | --- |
| Full gate | `bash scripts/verify.sh` |
| Rebuild committed ROMs | `npm run roms` |
| Capture a screenshot | `bash scripts/capture-screenshot.sh <committed-rom> <out.png> [wait]` |
| State log | `stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$ADDR' <rom>` |
| Docs build | `npm run docs:build` |

## Coverage Notes

- Every RD-07 acceptance criterion maps to at least one ST row: AC 1 → the `.1`/`.5`/`.6` rows;
  AC 2 → the `.1` rows; AC 3 → the `.3`/`.4` rows; AC 4 → the site rows and the frozen curriculum
  check in each Session A record.
- The logic rows test the register/RAM values and the line/cycle arithmetic, not the player's
  perception. The lesson documents disclose that boundary.
- No unit-test framework is added; the observation cases are the repository's test form (AR-7).
