# Testing Strategy: Part 8 — Advanced Topics (Lessons 56–65)

> **Document**: 07-testing-strategy.md
> **Parent**: [Index](00-index.md)
> **Rule:** the ST cases are the immutable oracle. Session A freezes them; an implementation
> mismatch is fixed in the implementation, never by editing the expectation. Every case names the
> evidence: `verify.sh`, a Stella state log, a static ledger, or a PIL pixel check.

## Shared Verification

Every lesson runs these gates before its commit:

1. `acme -f plain` (or `npm run roms`) produces the declared size; the committed `.bin` is
   byte-identical.
2. `bash scripts/verify.sh` passes (all sources, no drift, docs build).
3. The document's Full Source is verbatim against the main source.
4. The Part 8 index row is ✅; prev/next links resolve; the sidebar entry exists; README row 8 is
   unchanged.
5. Two screenshots exist, are captured from the committed ROM, show the title bar, and have no
   cursor; the doc's pixel table matches the measurements.
6. Both specialists report no critical/major open.

The state-log command shape is:

```bash
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$ADDR' \
  docs/public/roms/part8-advanced/NN-slug/NN-slug.bin
```

`BP: <hit> <scanline> <cycle> <pixels> | <flags> <A> <X> <Y> <SP>` is the log format. A label
reports the first cycle of the instruction that follows it.

---

## Lesson 56 — Bankswitching

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-56.1 | Assemble the main ROM | 8,192 bytes; Stella `F8* (8K)`; two 4K banks | `acme`, Stella log |
| ST-56.2 | Run the auto-demo | The forest scene (bank 1) at power-on; the cave scene (bank 0) after the switch; the bank indicator flips; two captures | Screenshots + pixel check |
| ST-56.3 | Inspect the switch | `BankEntry` A=1 at power-on; `BankWrite` A=0 after the switch; `SwitchRead` logs the hotspot; the trampoline bytes at `$F060`/`$F070` are identical in both 4K halves | State log + `cmp` of the halves |
| ST-56.4 | Inspect the frame | 262 lines; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6 | State log |
| ST-56.5 | Assemble/run the exercises | ex1 8,192 (swapped scenes); ex2 16,384 `F6* (16K)` with four scenes and start bank 0; ex3 8,192 (data bank read in place; no RAM copy) | `acme`, Stella logs |
| ST-56.6 | Site integration | Index row 56 ✅; prev 55, next 57; sidebar `config.ts:139`; `<RomPlayer>` path; README unchanged | Build + page check |

## Lesson 57 — Superchip

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-57.1 | Assemble the main ROM | 8,192 bytes; Stella `F8SC* (8K)`; each bank's first 128 bytes duplicated at +128; code at `$F100` | `acme`, Stella log, byte compare |
| ST-57.2 | Run the notebook | The message scrolls; the 16-cell gauge fills; two captures at different scroll positions | Screenshots + pixel check |
| ST-57.3 | Inspect the RAM window | `RamWrite` writes the character to `$1000+RamPtr`; `RamRead` returns the same byte from `$1080+RamPtr`; `Writes`/`Reads` advance | State log |
| ST-57.4 | Inspect the frame | 262 lines; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6 | State log |
| ST-57.5 | Assemble/run the exercises | ex1 8,192 (all cells lit); ex2 8,192 (strip drawn); ex3 8,192 (value persists across a bank switch) | `acme`, Stella logs |
| ST-57.6 | Site integration | Row 57 ✅; prev 56, next 58; sidebar `config.ts:140`; player | Build + page check |

## Lesson 58 — Illegal Opcodes

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-58.1 | Assemble the main ROM | 4,096 bytes; ACME accepts the `!byte` macros | `acme` |
| ST-58.2 | Run the lab | Four result bars with the documented colors; SELECT shows the cycle table; two captures | Screenshots + pixel check |
| ST-58.3 | Inspect the operations | LAX leaves A=X=M; SAX stores A&X; DCP decrements and compares; ISB increments and subtracts; the checksum is stable; no invalid-instruction trap | State log + static table |
| ST-58.4 | Inspect the frame | 262 lines; the four labels | State log |
| ST-58.5 | Assemble/run the exercises | ex1 4,096 (LAX pair); ex2 4,096 (DCP countdown); ex3 4,096 (SAX/LAX mask) | `acme`, Stella logs |
| ST-58.6 | Site integration | Row 58 ✅; prev 57, next 59; sidebar `config.ts:141` | Build + page check |

## Lesson 59 — Self-Modifying Code

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-59.1 | Assemble the main ROM | 4,096 bytes | `acme` |
| ST-59.2 | Run the painter | 8 status lines + 184 gradient lines = 192; two captures at phases 0 and 96; the phase-96 gradient matches `table[96..183] + table[0..95]` | Screenshots + pixel check |
| ST-59.3 | Inspect the RAM routine | The bytes at `$80–$86` match `A9 xx 85 09 85 02 60`; `PatchByte` changes each line; `PatchByteTail` reads `$6E` at the first wrap; `CallCount` = 184; SP returns to its entry value | State log + debugger disassembly |
| ST-59.4 | Inspect the frame | 262 lines; `BodyStart` 37/5, `OverscanStart` 229/6 | State log |
| ST-59.5 | Assemble/run the exercises | ex1 4,096 (patched delay); ex2 4,096 (patched pointer); ex3 4,096 (second routine) | `acme`, Stella logs |
| ST-59.6 | Site integration | Row 59 ✅; prev 58, next 60; sidebar `config.ts:142` | Build + page check |

## Lesson 60 — DPC and DPC+

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-60.1 | Assemble the main ROM | 10,240 bytes; Stella `DPC* (10K)`; program starts at `$F080` in bank 1; display data at offset 8K | `acme`, Stella log |
| ST-60.2 | Run the display | A DPC-generated playfield/starfield; two captures at different twinkle phases | Screenshots + pixel check |
| ST-60.3 | Inspect the fetchers | `Fetch0/1/2` return the three plane bytes; the counters decrement; `RngRead` changes; the register writes use the measured table (bottom `$1048`+index, counter high `$1058`+index) | State log + Stella DPC tab |
| ST-60.4 | Inspect the frame | 262 lines; `BodyStart` 37/5, `OverscanStart` 229/6 | State log |
| ST-60.5 | Assemble/run the exercises | ex1 10,240 (new image); ex2 10,240 (RNG stars); ex3 10,240 (music fetcher or fourth plane) | `acme`, Stella logs |
| ST-60.6 | Site integration | Row 60 ✅; prev 59, next 61; sidebar `config.ts:143`; DPC player | Build + page check |

## Lesson 61 — Compression

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-61.1 | Assemble the main ROM | 4,096 bytes; the packed stream is < 576 bytes | `acme` + table size |
| ST-61.2 | Run the logo | A detailed decompressed logo; SELECT shows the packed/raw counts; two captures | Screenshots + pixel check |
| ST-61.3 | Inspect the decoder | `RowByte0/1/2` match the raw image; `DecodeCount` = 576 (192 rows × 3); `Checksum` matches an independent decode; the `LAX (DecodePtr),Y` prefetch keeps the worst line at 76 cycles; no overrun | State log + host decode |
| ST-61.4 | Inspect the frame | 262 lines; `BodyStart` 37/5, `OverscanStart` 229/6 | State log |
| ST-61.5 | Assemble/run the exercises | ex1 4,096 (sprite RLE); ex2 4,096 (second scheme); ex3 4,096 (2-bit packing) | `acme`, Stella logs |
| ST-61.6 | Site integration | Row 61 ✅; prev 60, next 62; sidebar `config.ts:144` | Build + page check |

## Lesson 62 — Reverse Engineering a Classic Game

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-62.1 | Assemble the demo | 4,096 bytes | `acme` |
| ST-62.2 | Run the game | The paddle, ball, brick wall, score, and game over/restart; SELECT shows the four-band frame map and the diagonal row bar; three captures (game, map, win at score 24) | Screenshots + pixel check |
| ST-62.3 | Inspect the game | `KernelRow` Y=0..190 and `KernelRowLast` Y=191; `BallMove` reports the new `BallX`; `HitBrick` reports a brick; `ScoreWrite` advances to 24 at frame 4004; `OverlayWrite` toggles the map; the wall clamp and the brick-2 gap are correct; the mid-line ball is disclosed | State log |
| ST-62.4 | Inspect the frame | 262 lines; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5; `OverscanStart` 229/6 play, 229/7 over, 229/9 map | State log |
| ST-62.5 | Annotate | The doc quotes the symbol table (vectors, kernel, data, RAM) and a disassembly excerpt that matches the source; the three analysis exercises are answered | Doc + symbol file |
| ST-62.6 | Site integration | Row 62 ✅; prev 61, next 63; sidebar `config.ts:145` | Build + page check |

## Lesson 63 — Modern Homebrew

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-63.1 | Assemble the demo | 4,096 bytes | `acme` |
| ST-63.2 | Run the attract mode | The logo, starfield, color cycle, scrolling message, and tune; fire shows credits; two captures | Screenshots + pixel check |
| ST-63.3 | Inspect the mode | `SceneRead` 0→1 on fire (frame 9) and on the auto-demo (frame 300); `ScrollRead` advances; `TunePtrRead` advances and drives `AUDF0`/`AUDC0=$0C`/`AUDV0`; the frame is stable | State log |
| ST-63.4 | Inspect the frame | 262 lines; `BodyStart` 37/5, `OverscanStart` 229/6, `CreditsOverscan` 229/6 | State log |
| ST-63.5 | Exercises | The doc answers the three production exercises (logo/message, second screen, high-score) with the demo's hooks | Doc |
| ST-63.6 | Site integration | Row 63 ✅; prev 62, next 64; sidebar `config.ts:146` | Build + page check |

## Lesson 64 — Building Your Own Cartridge

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-64.1 | Assemble the demo | 4,096 bytes | `acme` |
| ST-64.2 | Run the burn-in test | The color bars, checksum, RAM pass, controller bits, frame counter; SELECT cycles pages; two captures | Screenshots + pixel check |
| ST-64.3 | Inspect the tests | The checksum equals an independent calculation; `RamResult` = pass; the controller bits change with `-holdjoy0`; `Frame` advances | State log + host checksum |
| ST-64.4 | Inspect the frame | 262 lines; `BodyStart` 37/5, `OverscanStart` 229/8 on both pages | State log |
| ST-64.5 | Exercises | The doc answers the three production exercises (checksum, RAM test, controller) with the demo's code | Doc |
| ST-64.6 | Site integration | Row 64 ✅; prev 63, next 65; sidebar `config.ts:147` | Build + page check |

## Lesson 65 — PAL/NTSC Universal ROM

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-65.1 | Assemble the main ROM | 4,096 bytes | `acme` |
| ST-65.2 | Run the selector | The title asks NTSC/PAL; the chosen mode shows the color bars and the label; two captures | Screenshots + pixel check |
| ST-65.3 | Inspect the timing | `TVMode` A=0/1; `FrameLines` low byte `$06`/`$38` and high byte `$01`; `BodyStart` 37/45; `OverscanStart` 229/301; `StartFrame` 259/309 | State log |
| ST-65.4 | Run both modes | Stella `-format PAL` and the PAL selection produce 312 lines; the NTSC selection produces 262; the doc states stock auto-detect is impossible | State log + doc |
| ST-65.5 | Assemble/run the exercises | ex1 4,096 (PAL default); ex2 4,096 (PAL-60); ex3 4,096 (color bars) | `acme`, Stella logs |
| ST-65.6 | Site integration | Row 65 ✅; prev 64, next Part 9's 66; sidebar `config.ts:148`; README unchanged | Build + page check |

## Review Gate

For each lesson, after the parent's verification:

- `atari2600-reviewer`: hardware/CPU correctness, mapper semantics, cycle/line claims, ACME
  syntax, failure modes. No critical/major open.
- `curriculum-auditor`: five hard rules, template, didactic chain, artifacts, index/README,
  evidence honesty. No critical/major open.
- Findings are appended to [05-findings.md](05-findings.md); fixes are re-verified and re-reviewed
  before the commit.
