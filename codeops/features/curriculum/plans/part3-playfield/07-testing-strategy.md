# Testing Strategy: Part 3 — Playfield (Lessons 19–24)

> **Document**: 07-testing-strategy.md
> **Parent**: [Index](00-index.md)

## Testing Overview

This repository ships static lesson content and ROMs; there is no test framework, and none is
added (AR-7). The specification tests are **observational acceptance cases**: every ST row names a
concrete action (assemble, run, inspect, capture, break) and a concrete expected outcome that can
be confirmed by a human or by recorded command output. Session A freezes the rows for its lesson
before implementation and records the red baseline; Session C confirms every row and records the
evidence (AR-2, AR-4).

Expected outcomes here derive only from [03-lesson-specs.md](03-lesson-specs.md) and the register —
never from the implementation (immutable-oracle rule). If an implementation disagrees with an ST
row, the implementation is wrong.

**Evidence methods:** `bash scripts/verify.sh` output (assembly + drift + docs build); screenshots
captured from the committed ROM path and pixel-checked against the chunk geometry
(`x = 25 + chunk × 24`, picture rows 107–711); timed waits/bursts for animated or switching states;
and Stella state logs (`stella -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'`, format
`BP: <frame> <scanline> <cycles> <pixels> | <flags> <A> <X> <Y> <SP> |`) with the static cycle
ledgers — the timing standard of AR-6 (including the `hit cycle` = the cycle of the instruction
after a store, learned in Lesson 18).

> Rows quote behavioral expectations in self-contained language so they can be handed to a
> reviewer without further interpretation.

## 🚨 Specification Test Cases (frozen per lesson in Session A)

### Lesson 19

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-19.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output + file size | RD-03 AC 1–2 / AR-4 |
| ST-19.2 | Run the ROM; inspect the reflect state | Green `$C8` block pattern on dark `$02`, constant down all 192 lines; transitions at x = 169, 217, 265, 409, 601, 745, 793, 841; an 8-chunk green central block (16–23) between two dark bands | Screenshot `reflect.png` + pixel check | 03 §Lesson 19 |
| ST-19.3 | Wait ~2 s for the state flip | `CTRLPF` bit 0 clears; the right half repeats the left; transitions at 169, 217, 265, 409, 649, 697, 745, 889; the central green block widens to chunks 16–25 | Screenshot `repeat.png` + pixel difference | 03 §Lesson 19 |
| ST-19.4 | Debugger: frame checkpoints and `CtrlWrite` | `StartFrame` 259, `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229 (262 lines); `CtrlWrite` hits once per frame — A = `$01` on frames 1–119 and `$00` on 120–239, first change at frame 120; the hold line is constant | State log + static ledger (AR-6) | RD-03 AC 3 / 03 §Lesson 19 |
| ST-19.5 | Assemble and run each solution | Ex 1 swaps on/off regions; ex 2 draws one chunk bar (two bars visible); ex 3 cycles eight patterns every 60 frames | `verify.sh` + manual runs + captures | RD-03 AC 1 / AR-8 |
| ST-19.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the committed ROM; both captures resolve; prev (18) and next (20) links resolve; part-index row 19 links the lesson | Build output + page check | RD-03 AC 1 / AR-10 |

### Lesson 20

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-20.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output + file size | RD-03 AC 1–2 / AR-4 |
| ST-20.2 | Run the ROM; inspect the normal state | A green `$C8` wall with a 4-chunk dark gap (x = 457–553), constant down the screen; transitions at 25/457/553 | Screenshot `single-color.png` + pixel check | 03 §Lesson 20 |
| ST-20.3 | Wait ~2 s for score mode | The left half turns `COLUP0` red `$42`, the right half `COLUP1` blue `$84`; the gap stays dark; transitions at 25 (red), 457 (dark), 553 (blue) | Screenshot `score-mode.png` + pixel check | 03 §Lesson 20 |
| ST-20.4 | Debugger: `CtrlWrite` and the color registers | `CtrlWrite` fires at frames 120/240 with A = `$03`/`$01`; `COLUP0`/`COLUP1` hold `$42`/`$84`; the frame is 262 lines | State log + static ledger (AR-6) | RD-03 AC 3 / 03 §Lesson 20 |
| ST-20.5 | Assemble and run each solution | Ex 1 swaps score colors; ex 2 shows red/blue blocks separated by gold; ex 3 shows the top score/red-blue half and the bottom green half | `verify.sh` + manual runs + captures | RD-03 AC 1 / AR-8 |
| ST-20.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the committed ROM; both captures resolve; prev (19) and next (21) links resolve; part-index row 20 links the lesson | Build output + page check | RD-03 AC 1 / AR-10 |

### Lesson 21

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-21.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output + file size | RD-03 AC 1–2 / AR-4 |
| ST-21.2 | Run the ROM; inspect the frame | Left 18 chunks solid green; a 6-chunk central gap (x = 457–600, 144 px; transitions at 457 and 601); alternating 1-chunk stripes across the right half; on from x = 25, transitions at 457, 601, 625, 649, 673, 697, 721, 745, 769, 793, 817, 841, 865, 889, 913, 937, 961 | Screenshot `asymmetric.png` + pixel check | 03 §Lesson 21 |
| ST-21.3 | Verify the mid-line write windows | Six write checkpoints fire 192 times per frame at hit cycles **10, 15, 20, 35, 46, 57**; the right-half values are written after the left slots and before the right slots; the left half is unchanged across the line | State log + static cycle ledger (AR-6, AR-13) | RD-03 AC 3 / 03 §Lesson 21 |
| ST-21.4 | Debugger: frame checkpoints | `StartFrame` 259, `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229; the per-line ledger totals 76 cycles | State log + static ledger (AR-6) | RD-03 AC 3 / 03 §Lesson 21 |
| ST-21.5 | Assemble and run each solution | Ex 1 narrows the gap and starts the right half solid; ex 2 mirrors the left and removes the mid-line rewrite; ex 3 shows two different asymmetric bands | `verify.sh` + manual runs + captures | RD-03 AC 1 / AR-8 |
| ST-21.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the committed ROM; the capture resolves; prev (20) and next (22) links resolve; part-index row 21 links the lesson | Build output + page check | RD-03 AC 1 / AR-10 |

### Lesson 22

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-22.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output + file size | RD-03 AC 1–2 / AR-4 |
| ST-22.2 | Run the ROM; capture a partially open gate | The gate width matches a table state k: gap = 48k px centred on x = 505; the wall is green `$C8` on dark `$02` | Screenshot `gate-opening.png` + gap measurement | 03 §Lesson 22 |
| ST-22.3 | Wait for the fully open state | State 8 opens 16 chunks (384 px, x = 313–696; transitions at 313 and 697); `GateStep` fires once per 30 frames and reverses at states 0 and 8 | Screenshot `gate-open.png` + state log | 03 §Lesson 22 |
| ST-22.4 | Debugger: `GateStep` and `PF2` | Each step writes `PF2 = GateTable[state]`; the state sequence ascends 0→8 then descends; the frame is 262 lines | State log + static ledger (AR-6) | RD-03 AC 3 / 03 §Lesson 22 |
| ST-22.5 | Assemble and run each solution | Ex 1 changes the cadence; ex 2 opens only the right half; ex 3 steps a 20-entry rotation table every 10 frames in repeat mode | `verify.sh` + manual runs + captures | RD-03 AC 1 / AR-8 |
| ST-22.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the committed ROM; both captures resolve; prev (21) and next (23) links resolve; part-index row 22 links the lesson | Build output + page check | RD-03 AC 1 / AR-10 |

### Lesson 23

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-23.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output + file size | RD-03 AC 1–2 / AR-4 |
| ST-23.2 | Run the ROM; inspect level 1 | A full border, two internal vertical walls, and a horizontal divider at rows 93–95 with a central doorway; the maze is green `$C8` on dark `$02`; the pattern varies down the screen | Screenshot `level1.png` + pixel check | 03 §Lesson 23 |
| ST-23.3 | Wait ~4 s for the level switch | The level switches at frame 240; level 2 shows the divider at rows 61–63, inner pillar rows, and a side chamber; the two captures differ over the pinned region | Screenshot `level2.png` + pixel difference | 03 §Lesson 23 |
| ST-23.4 | Debugger: `LevelSwitch` and `RowStore` | `LevelSwitch` fires every 240 frames; `RowStore` fires once per line at a constant cycle; the per-line ledger totals 52-55 of 76 cycles (page crossings absorbed by WSYNC); the ROM is 4,096 bytes | State log + static ledger (AR-6) | RD-03 AC 3 / 03 §Lesson 23 |
| ST-23.5 | Assemble and run each solution | Ex 1 adds a third level; ex 2 moves the divider/doorway; ex 3 uses a 2-line kernel (96 rows, each shown twice) and draws the top half of the level | `verify.sh` + manual runs + captures | RD-03 AC 1 / AR-8 |
| ST-23.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the committed ROM; both captures resolve; prev (22) and next (24) links resolve; part-index row 23 links the lesson | Build output + page check | RD-03 AC 1 / AR-10 |

### Lesson 24

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-24.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output + file size | RD-03 AC 1–2 / AR-4 |
| ST-24.2 | Run the ROM; inspect the rainbow state | The castle pattern in 16 hue bands of 12 lines each, hues 0–15 top to bottom; the color changes every 12 lines; the pattern shape is unchanged | Screenshot `rainbow.png` + pixel check | 03 §Lesson 24 |
| ST-24.3 | Wait ~2 s for the region state | The top 96 lines show cool hues, the bottom 96 warm hues; the state flips at frame 120 | Screenshot `regions.png` + pixel check | 03 §Lesson 24 |
| ST-24.4 | Debugger: `ColorWrite` and `StateFlip` | the color write lands at cycles 10–12 (the `ColorWrite` checkpoint on the following `INY` reports 13, or 14 on a page-crossing line) with A = the table byte; 12 consecutive lines share a hue; `StateFlip` fires every 120 frames; the frame is 262 lines | State log + static ledger (AR-6) | RD-03 AC 3 / 03 §Lesson 24 |
| ST-24.5 | Assemble and run each solution | Ex 1 slides the bands; ex 2 shows a sky/ground split; ex 3 colors a data-driven maze by row type | `verify.sh` + manual runs + captures | RD-03 AC 1 / AR-8 |
| ST-24.6 | Build the docs; open the lesson page | The page renders; `<RomPlayer>` loads the committed ROM; both captures resolve; prev (23) and next (Lesson 25) links resolve; part-index row 24 links the lesson | Build output + page check | RD-03 AC 1 / AR-10 |

## Red phase (Session A, every lesson)

1. Re-affirm the lesson's ST rows against [03-lesson-specs.md](03-lesson-specs.md).
2. Record the red baseline: no lesson sources, no images, no committed ROMs, stub document; the
   part-index row is "Coming Soon" (Lesson 19's phase also rebuilds the index); the phase baseline
   captures the tree state.
3. For Lesson 21, additionally re-affirm the six pinned write cycles against AR-13 and state the
   measurement plan before implementation.

## Green phase (Session C, every lesson)

1. `bash scripts/verify.sh` green (assembly, drift, docs build).
2. Every ST row confirmed with recorded evidence; timing rows carry the state log + ledger.
3. Edge checks: frame integrity (steady scanline at the frame top; blank-on in HBLANK) plus the
   lesson's specific checks — ST-19.2/19.3, ST-20.2/20.3, ST-21.2/21.3, ST-22.2/22.3,
   ST-23.2/23.3, ST-24.2/24.3.
4. For Lesson 21, the measured right-half write cycles match the pinned 35/46/57 and the left
   half is unchanged (AR-13). A mismatch is a specification/design failure, not a wording tweak.
5. Both specialist reviews recorded; no critical/major findings may remain open (AR-5).

## Verification Checklist (plan level)

- [ ] All specification test cases defined with concrete input/output pairs, traced to specs/ARs
- [ ] Session A freezes each lesson's ST set with a red baseline before implementation
- [ ] Specification expectations are never edited to match an implementation
- [ ] `bash scripts/verify.sh` passes for every lesson commit (AR-4)
- [ ] Every playfield timing/geometry claim carries a state-log observation plus a static cycle
      ledger (AR-6, AR-13)
- [ ] Screenshots captured from committed ROM paths; titles verified; states pixel-checked
- [ ] Committed ROMs regenerate byte-identically (`npm run roms`; drift check clean)
- [ ] Both reviewers report no critical/major findings per lesson (AR-5)
- [ ] Part index rows flip per lesson; README verified unchanged (AR-10)
- [ ] Each lesson's page renders with a working `<RomPlayer>` and prev/next links (ST-NN.6)
