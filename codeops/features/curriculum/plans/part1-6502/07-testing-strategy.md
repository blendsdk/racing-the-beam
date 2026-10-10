# Testing Strategy: Part 1 — The 6502 CPU (Lessons 07–11)

> **Document**: 07-testing-strategy.md
> **Parent**: [Index](00-index.md)

## Testing Overview

This is a content repository: deliverables are lesson sources, documents, screenshots, and ROMs, not testable code modules. There is no unit-test framework and none is added (AR-3, AR-7). The specification tests are **observational acceptance cases** with concrete expected outcomes; each case names its evidence method, and the immutable-oracle rule applies to frozen expectations exactly as it would to spec-test files.

### Coverage Goals

| Artifact type | Target |
| --- | --- |
| Lesson sources (07–11) assembling to drift-free committed ROMs | 100% (every source, via `verify.sh`) |
| Exercise solutions assembled and behaving | 100% (every solution in its Session C) |
| Screenshot sets per the lesson specs | 100% (every listed screenshot) |
| Lesson documents + index/prev-next integration | 100% (every lesson) |

E2E testing uses the existing site build; no new harness is created (AR-3).

## 🚨 Specification Test Cases (MANDATORY — NON-NEGOTIABLE)

> These cases derive EXCLUSIVELY from RD-01's acceptance criteria, the lesson specifications ([03-lesson-specs.md](03-lesson-specs.md)), and the Ambiguity Register (AR-3). They define expected behavior BEFORE any implementation and are frozen in each lesson's Session A (AR-2). **IMMUTABLE ORACLE RULE:** do NOT modify these expectations to match the implementation. If a lesson does not match a case, the lesson is wrong — not the case.

### Lesson 07

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-07.1 | Assemble `07-branches-and-loops.asm`; commit the ROM; run `bash scripts/verify.sh` | No assembly errors; exactly 4,096 bytes; committed `…/07-branches-and-loops/07-branches-and-loops.bin` byte-identical to a fresh assemble; docs build passes | `verify.sh` output + file size | RD-01 AC 1–2 / AR-3 |
| ST-07.2 | Run the ROM in Stella; inspect one frame | Exactly 8 equal bands; seven dark gray (`$02`), exactly one bright red (`$42`) | Screenshot `loop-cursor-top.png` matches | 03 §Lesson 07 / RD-01 AC 1 |
| ST-07.3 | Keep running; capture a later frame | The bright band is at a different position; over one cycle it advances downward through all 8 positions and wraps to the top | Screenshot `loop-cursor-bottom.png` + full-cycle observation | 03 §Lesson 07 / RD-01 AC 1 |
| ST-07.4 | Debugger: watch RAM `$80`, loop counters, SP | `$80` cycles 0…7 in step with the visible band and resets only via the compare branch; the band counter reaches 0; SP stays `$FF` | Debugger observation in the task notes | RD-01 AC 3 / 03 §Lesson 07 |
| ST-07.5 | Assemble and run each solution; check the screenshots | Each assembles to exactly 4,096 bytes and produces its stated result (12-band ladder; bouncing cursor; restructured out-of-range loop); both screenshots exist and match | `verify.sh` + manual runs + file check | RD-01 AC 1–2 / AR-3 |

### Lesson 08

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-08.1 | Assemble the lesson source and solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output | RD-01 AC 1–2 / AR-3 |
| ST-08.2 | Run the ROM in Stella | Four equal bands, top to bottom `$42`, `$C8`, `$96`, `$1A`; steady picture | Screenshot `subroutine-bands.png` matches | 03 §Lesson 08 / RD-01 AC 1 |
| ST-08.3 | Step into the calls; watch SP and the stack | At the frame top SP = `$FF`; each `JSR` lowers SP by 2; every `RTS` restores it; each `PHA` matches a `PLA` with the same value | Debugger state log (`-break` + logBreaks) + static SP ledger, in the task notes (AR-11) | RD-01 AC 3 / 03 §Lesson 08 |
| ST-08.4 | Exercise the 3-level nested chain; record the deepest SP | SP reaches exactly `$F9` and returns to `$FF` each frame; no lesson variable lives at `$F9–$FF` | Debugger state log (`-break` + logBreaks) + static SP ledger, in the task notes (AR-11) | 03 §Lesson 08 / RD-01 AC 3 |
| ST-08.5 | Assemble and run each solution | Each assembles to exactly 4,096 bytes and produces its stated result (8 bands; caller's X preserved across a clobbering call; nested chain returns to `$FF`); the screenshot exists | `verify.sh` + manual runs | RD-01 AC 1–2 / AR-3 |

### Lesson 09

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-09.1 | Assemble the lesson source and solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output | RD-01 AC 1–2 / AR-3 |
| ST-09.2 | Run the ROM; inspect a frame with bit 0 set | Exactly 8 equal bands; exactly one bright green (`$C8`) band at the bottom; the rest dark gray (`$02`) | Screenshot `bit-ladder-bottom.png` matches | 03 §Lesson 09 / RD-01 AC 1 |
| ST-09.3 | Continue running; capture a later frame | The bright band moves one band per step from the bottom toward the top; after bit 7 leaves via the carry it restarts at the bottom | Screenshot `bit-ladder-top.png` + full-cycle observation | 03 §Lesson 09 / RD-01 AC 1 |
| ST-09.4 | Debugger: watch RAM `$80`, the mask shift, P | `$80` holds `%00000001` … `%10000000` in single-bit steps, then reloads `%00000001`; carry is set at reload; the mask shifts once per band | Debugger observation in the task notes | RD-01 AC 3 / 03 §Lesson 09 |
| ST-09.5 | Assemble and run each solution | Each assembles to exactly 4,096 bytes and produces its stated result (set/clear/toggle pattern; packed color equals the two nibbles; ring walk wraps without reload); both screenshots exist | `verify.sh` + manual runs | RD-01 AC 1–2 / AR-3 |

### Lesson 10

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-10.1 | Assemble the main ROM, `demo-10.asm`, and solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output | RD-01 AC 1–2 / AR-3 |
| ST-10.2 | Run the main ROM in Stella | Six identical `$42` bands above six ramp bands `$42`, `$4C`, `$56`, `$60`, `$6A`, `$74`; all 12 bands equal height | Screenshot `addressing-modes.png` matches | 03 §Lesson 10 / RD-01 AC 1 |
| ST-10.3 | Run the demo ROM in Stella | 12 equal bands forming the fixed ramp `$1A + $0A·k` (k = 0…11) top to bottom; each band matches the document's mode table | Screenshot `addressing-mode-ladder.png` + document comparison | 03 §Lesson 10 / RD-01 AC 1 |
| ST-10.4 | Debugger: change RAM `$82`; watch the next frame; inspect pointer and X/Y | The five memory-fetch bands change color while the immediate band stays `$42` (literal vs. memory); pointer `$80/$81` reads `$0082`; `JMP (ptr)` lands on the band painter | Debugger observation in the task notes | RD-01 AC 3 / 03 §Lesson 10 |
| ST-10.5 | Assemble and run each solution | Each assembles to exactly 4,096 bytes and produces its stated result (12-band ramp; pointer-switched alternating tables; wrap fault observed, safe rebuild runs); both screenshots exist | `verify.sh` + manual runs | RD-01 AC 1–2 / AR-3 |

### Lesson 11

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-11.1 | Assemble the lesson source and solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output | RD-01 AC 1–2 / AR-3 |
| ST-11.2 | Run the ROM; inspect the initial frame | 16 equal bands whose colors reproduce the documented 16-byte table in order (offset 0 first) | Screenshot `lookup-wave.png` matches | 03 §Lesson 11 / RD-01 AC 1 |
| ST-11.3 | Continue running; capture a later frame | The pattern has shifted by one or more table entries; the wraparound shows no blank or duplicated step | Screenshot `lookup-wave-shifted.png` + full-cycle observation | 03 §Lesson 11 / RD-01 AC 1 |
| ST-11.4 | Debugger: watch RAM `$80`, the ROM table, indexed fetches | `$80` cycles 0…15; the table reads `$1A`, `$28`, …, `$EC` in order; the index mask keeps every fetch inside the table | Debugger observation in the task notes | RD-01 AC 3 / 03 §Lesson 11 |
| ST-11.5 | Assemble and run each solution | Each assembles to exactly 4,096 bytes and produces its stated result (custom table; two-table timing movie; pointer-table palette switch); both screenshots exist | `verify.sh` + manual runs | RD-01 AC 1–2 / AR-3 |

## Test Categories

### Specification Tests (from the ST cases above)

No spec-test files exist or are added (AR-3); each case runs on the real artifacts via the vehicles below.

| Execution vehicle | ST cases covered | Per lesson |
| --- | --- | --- |
| `bash scripts/verify.sh` (assemble + ROM drift + docs build) | `ST-NN.1` | 07–11 |
| `scripts/capture-screenshot.sh` + visual comparison | `ST-NN.2`, `ST-NN.3` | 07–11 |
| Stella debugger observation (recorded in the task notes) | `ST-NN.4` | 07–11 |
| ACME assemble + manual run of each solution | `ST-NN.5` | 07–11 |

### Implementation Tests (edge cases, internals)

No `*.impl.test.*` files exist or are added (AR-3); Session C runs these edge checks and records the results.

| Edge check | Expected | Per lesson |
| --- | --- | --- |
| Branch reach | Loop bodies stay within ±127 bytes; over-range cases restructured | 07 |
| Stack balance | SP returns to `$FF`; deepest SP never touches lesson variables; pushes/pulls balance | 08 |
| Zero-page wrap | Indexed zero-page fetches reviewed for wrap; safe form used, or the hazard is the lesson's topic | 09, 10 |
| Table bounds | Index masking/comparison keeps every fetch inside its table | 09, 11 |
| Frame integrity | Kernel stays at 192 visible lines; no rolling or torn picture in Stella | 07–11 |

### Integration Tests

| Test | Components | Description |
| --- | --- | --- |
| `bash scripts/verify.sh` | all lesson ROMs + docs | Assembles every `lessons/**/*.asm`, checks committed ROMs, builds the site |
| Navigation chain | docs | Lesson 06 → 07 → … → 12 links resolve both ways; part-index rows updated |

### End-to-End Tests

| Scenario | Steps | Expected Result |
| --- | --- | --- |
| Open each finished lesson page | `npm run docs:build`, preview, open lesson 07–11 pages | Screenshot renders, `<RomPlayer>` loads the committed ROM, prev/next links work, no broken part-index links |

## Test Data

### Fixtures Needed

The frozen ST expectations (this document) and the lesson specs (03) are the oracle; the real lesson ROMs are the test subjects. No mocks — all evidence comes from the real ROMs in Stella.

### Mock Requirements

None.

## Verification Checklist

- [ ] All ST cases frozen in every lesson's Session A record before implementation (AR-2)
- [ ] Every ST case traces to an RD-01 acceptance criterion, a 03 §Lesson section, or AR-3
- [ ] Red phase recorded: each lesson's cases fail before Session B (artifacts do not exist)
- [ ] Green phase recorded: all cases pass after Session B and its fixes (expectations unedited)
- [ ] Implementation edge checks executed and recorded in Session C
- [ ] `bash scripts/verify.sh` passes with all lessons included
- [ ] No regressions: lessons 01–06 ROMs stay drift-free and the docs build stays green
- [ ] Every listed screenshot matches its lesson's stated screen; every solution assembles
