# Testing Strategy: Part 2 — TV & TIA (Lessons 12–18)

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

**Evidence methods:** `bash scripts/verify.sh` output (assembly + drift + docs build);
screenshots captured from the committed ROM path and pixel-checked; full-cycle observations from
burst captures for animated states; and Stella state logs
(`stella -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'`, format
`BP: <frame> <scanline> <x> <y> | <flags> <A> <X> <Y> <SP> |`) with the static cycle ledgers —
the timing standard of AR-6.

> Rows quote behavioral expectations in self-contained language so they can be handed to a
> reviewer without further interpretation.

## 🚨 Specification Test Cases (frozen per lesson in Session A)

### Lesson 12

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-12.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output | RD-02 AC 1–2 / AR-4 |
| ST-12.2 | Run the ROM; inspect one frame | Four equal 48-line bands, `$42`, `$84`, `$C8`, `$1A` top to bottom; 192 visible lines total; release line counted inside band 0 | Screenshot `frame-anatomy.png` matches | 03 §Lesson 12 |
| ST-12.3 | Keep running; observe over several seconds | The picture is identical every frame — no roll, no shift; the frame is 262 lines | Full-cycle observation (burst captures); state log at the loop top shows a constant scanline | 03 §Lesson 12 |
| ST-12.4 | Debugger: breakpoints at the four phase boundaries | Phase lengths 3 / 37 / 192 / 30 lines; the scanline deltas in the log match the frame ledger | State-log observation in the task notes (AR-6) | RD-02 AC 3 / 03 §Lesson 12 |
| ST-12.5 | Assemble and run each solution | Each assembles to 4,096 bytes and produces its stated result (RAM-colored bands; 48/96/48 split; 16-band ladder of 12 lines) | `verify.sh` + manual runs | RD-02 AC 1 / AR-3 |

### Lesson 13

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-13.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output | RD-02 AC 1–2 / AR-4 |
| ST-13.2 | Run the ROM; inspect the first frame | 16 equal 12-line bands in hue order 0–15 at the first luminance step | Screenshot `palette-hues.png` matches | 03 §Lesson 13 |
| ST-13.3 | Keep running through one full luminance cycle | The picture steps through all 8 luminance levels in order, each step stable; across one cycle all 128 colors appear | Full-cycle observation; second screenshot `palette-dim.png` | 03 §Lesson 13 |
| ST-13.4 | Debugger: watch the luminance step counter and the `COLUBK` value | The counter advances once per ~120 frames; the written byte equals the hue × 16 plus the step's luminance × 2 | State log + ledger in the task notes (AR-6) | RD-02 AC 3 / 03 §Lesson 13 |
| ST-13.5 | Assemble and run each solution | Each assembles to 4,096 bytes and produces its stated result (swapped axes; chart-match table; one-hue fade); both screenshots exist | `verify.sh` + manual runs + file check | RD-02 AC 1 / AR-3 |

### Lesson 14

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-14.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output | RD-02 AC 1–2 / AR-4 |
| ST-14.2 | Aligned mode: inspect frames over several seconds | Exactly two equal halves (`$42` top, `$84` bottom); the boundary line is identical in every captured frame | Screenshot `wsync-aligned.png` + burst comparison | 03 §Lesson 14 |
| ST-14.3 | Late mode: capture two frames a moment apart | The boundary is visibly torn/moved between the frames (the frames differ at the boundary region) | Screenshot `wsync-torn.png` + observed difference | 03 §Lesson 14 |
| ST-14.4 | Debugger: two consecutive lines' write positions | The aligned write lands in HBLANK every line; the late write lands after HBLANK with the documented cycle offset; both match the ledger | State-log observation in the task notes (AR-6) | RD-02 AC 3 / 03 §Lesson 14 |
| ST-14.5 | Assemble and run each solution | Each assembles to 4,096 bytes and produces its stated result (moved split; repaired budget; ledger check); both screenshots exist | `verify.sh` + manual runs + file check | RD-02 AC 1 / AR-3 |

### Lesson 15

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-15.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output | RD-02 AC 1–2 / AR-4 |
| ST-15.2 | Run the ROM; inspect the frame and observe | Four equal 48-line bands, stable; the hues advance one step about every 30 frames | Screenshot `timer-frame.png` + observation | 03 §Lesson 15 |
| ST-15.3 | Check the timer budgets | VBLANK (37 lines) and overscan (30 lines) are paced as designed; `INTIM` reaches zero within the budgeted window; the per-frame work fits (no overrun) | State log + ledger in the task notes (AR-6) | 03 §Lesson 15 |
| ST-15.4 | Debugger: `TIM64T` value, `INTIM` polling, compute region | Written values and polling behavior match the ledger; the compute code runs while `INTIM` > 0 | State-log observation in the task notes (AR-6) | RD-02 AC 3 / 03 §Lesson 15 |
| ST-15.5 | Assemble and run each solution | Each assembles to 4,096 bytes and produces its stated result (timer VBLANK; overscan value; split work); screenshot exists | `verify.sh` + manual runs + file check | RD-02 AC 1 / AR-3 |

### Lesson 16

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-16.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output | RD-02 AC 1–2 / AR-4 |
| ST-16.2 | Run the ROM; inspect the frame | Four zones of 24 / 72 / 48 / 48 lines with colors `$02`, `$84`, `$46`, `$C4` top to bottom; boundaries exact | Screenshot `zones.png` matches | 03 §Lesson 16 |
| ST-16.3 | Check the table-driven boundaries | The paint loop consumes the 4-entry ROM table; measured boundary scanlines are 24 / 96 / 144 / 192 | State log + pixel check | 03 §Lesson 16 |
| ST-16.4 | Debugger: zone boundary scanlines and the table walk | Boundary scanlines at breakpoints match the table; each entry is used exactly once per frame | State-log observation in the task notes (AR-6) | RD-02 AC 3 / 03 §Lesson 16 |
| ST-16.5 | Assemble and run each solution | Each assembles to 4,096 bytes and produces its stated result (fifth zone; rebalanced zones; RAM table); screenshot exists | `verify.sh` + manual runs + file check | RD-02 AC 1 / AR-3 |

### Lesson 17

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-17.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output | RD-02 AC 1–2 / AR-4 |
| ST-17.2 | Run the ROM; inspect the two-section ruler | Section 1: stable stepped bands; section 2: the documented drift signature; the section boundary is exact | Screenshot `cycle-ruler.png` matches | 03 §Lesson 17 |
| ST-17.3 | Verify the cycle ledger | Section 1's loop counts exactly 76 cycles and stays aligned for its 96 lines; section 2's documented excess produces exactly the stated drift | State log + static ledger (AR-6) | 03 §Lesson 17 |
| ST-17.4 | Debugger: two consecutive iterations of section 1 | Both iterations hit the checkpoint at the same scanline; the per-iteration cycle gap matches the ledger | State-log observation in the task notes (AR-6) | RD-02 AC 3 / 03 §Lesson 17 |
| ST-17.5 | Assemble and run each solution | Each assembles to 4,096 bytes and produces its stated result (hand count verified; trimmed to 76; full ledger); screenshot exists | `verify.sh` + manual runs + file check | RD-02 AC 1 / AR-3 |

### Lesson 18

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-18.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output | RD-02 AC 1–2 / AR-4 |
| ST-18.2 | Run the ROM; inspect the first state | Four vertical columns (`$42`, `$84`, `$C8`, `$1A`) spanning all 192 lines; boundaries at the documented approximate positions | Screenshot `columns.png` matches | 03 §Lesson 18 |
| ST-18.3 | Wait for the shift state | The columns shift by the designed cycle offset; the two screenshots differ as designed | Screenshot `columns-shifted.png` + pixel difference | 03 §Lesson 18 |
| ST-18.4 | Debugger: the per-line `COLUBK` writes | Write cycles match the ledger; the boundary-position math (cycle → color clocks → position) checks out | State-log observation in the task notes (AR-6) | RD-02 AC 3 / 03 §Lesson 18 |
| ST-18.5 | Assemble and run each solution | Each assembles to 4,096 bytes and produces its stated result (moved boundary; fifth column; smooth animation); both screenshots exist | `verify.sh` + manual runs + file check | RD-02 AC 1 / AR-3 |

## Red phase (Session A, every lesson)

1. Re-affirm the lesson's ST rows against [03-lesson-specs.md](03-lesson-specs.md).
2. Record the red baseline: no lesson sources, no images, no committed ROMs, stub document,
   part-index row still "Coming Soon" (the plan's phase baseline captures the tree state).

## Green phase (Session C, every lesson)

1. `bash scripts/verify.sh` green (assembly, drift, docs build).
2. Every ST row confirmed with recorded evidence; timing rows carry the state log + ledger.
3. Edge checks: frame integrity (steady scanline at the frame top; blank-on in HBLANK) plus the
   lesson's specific checks — ST-12.3/12.4, ST-13.3/13.4, ST-14.2/14.4, ST-15.3/15.4,
   ST-16.3/16.4, ST-17.3/17.4, ST-18.3/18.4.
4. Both specialist reviews recorded; no critical/major findings may remain open (AR-5).

## Verification Checklist (plan level)

- [ ] All specification test cases defined with concrete input/output pairs, traced to specs/ARs
- [ ] Session A freezes each lesson's ST set with a red baseline before implementation
- [ ] Specification expectations are never edited to match an implementation
- [ ] `bash scripts/verify.sh` passes for every lesson commit (AR-4)
- [ ] Every timing/cycle/frame claim carries a state-log observation or a static cycle ledger (AR-6)
- [ ] Screenshots captured from committed ROM paths; titles verified; states pixel-checked
- [ ] Committed ROMs regenerate byte-identically (`npm run roms`; drift check clean)
- [ ] Both reviewers report no critical/major findings per lesson (AR-5)
- [ ] Part index rows flip per lesson; README verified unchanged (AR-10)
