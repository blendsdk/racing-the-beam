# Preflight Report: Part 8 — Advanced Topics (Lessons 56–65)

> **Document**: 00-preflight-report.md
> **Parent**: [Index](00-index.md)
> **Run**: 2026-11-06, before the first lesson phase
> **Method**: plan audit against RD-08, the shipped course, the expert references, Stella 7.0,
> ACME 0.97, and nine executable prototypes (F8, F8 switch, F8SC, F6, DPC, illegal opcodes,
> self-modifying RAM, Javatari mapper inspection, PAL/NTSC research).
> **Verdict**: ✅ **GATE PASSED** — 2 critical and 10 major findings resolved; 12 minor findings
> folded into the lesson specs; 4 observations recorded. No unresolved blocker remains.

## Findings

### Critical

| ID | Finding | Risk | Resolution |
| --- | --- | --- | --- |
| PF-01 | The Lesson 65 stub promises **runtime TV-system detection**. On a stock 2600 this is impossible: the RIOT timer and the TIA both count the CPU clock, and the NTSC/PAL crystal difference (~1%) cannot be measured without an independent timebase. The known exception is the Harmony/Melody ARM timer. | The lesson would teach a false, unverifiable mechanism and fail on real hardware. | **Resolved:** Lesson 65 teaches a title-screen selector plus adaptive 262/312-line timing, explains why software auto-detection is impossible, and documents the Harmony/Melody ARM exception and the Color/BW-switch practice. AR-20; spec §Lesson 65. |
| PF-02 | The Lesson 60 stub implies DPC+ is buildable like DPC. DPC+ requires the Harmony/Melody ARM coprocessor, a 29K/32K image, and an ARM toolchain; a plain cartridge cannot run it. | A lesson that promises a DPC+ ROM would ship a non-working or unverifiable artifact. | **Resolved:** Lesson 60 builds a **real DPC** 10K ROM (verified `DPC* (10K)`), and documents DPC+ with its ARM model, extra RAM, and register differences. AR-13; spec §Lesson 60. |

### Major

| ID | Finding | Risk | Resolution |
| --- | --- | --- | --- |
| PF-03 | F8 and F8SC start in **bank 1**, not bank 0. F6 starts in **bank 0**. A source that puts the entry in bank 0 for an F8 ROM never runs at power-on. | A silent black screen; the first banking lesson would be wrong. | **Resolved:** Every F8/F8SC/DPC layout puts the entry in the start bank; F6 exercise 2 puts its entry in bank 0. Verified in Stella: F8 `F8*`, F8SC `F8SC*`, DPC `DPC*`, F6 start color = bank 0's `$84`. AR-10, AR-33; spec §Lesson 56. |
| PF-04 | A plain 8K Superchip ROM is auto-detected as **F8**, not F8SC, unless the first 128 bytes of each 4K bank are duplicated at +128. The first 256 bytes of each bank are the RAM window, so code must start at `$F100`. | The RAM reads would return ROM bytes and the demo would fail. | **Resolved:** The F8SC source emits `!fill 128` twice at the start of each bank, starts code at `$F100`, and uses `$1000–$107F`/`$1080–$10FF`. Verified: `F8SC* (8K)`. AR-11; spec §Lesson 57. |
| PF-05 | A DPC image is **10,240 bytes**: 8K program (two 4K banks) + 2K display data at file offset 8K. The DPC starts in bank 1; `$F000–$F07F` is the DPC register window, so code must start at `$F080`. | A 4K/8K image would be misdetected or crash; an entry at `$F000` executes DPC register data. | **Resolved:** The DPC layout uses real `$C000`/`$D000` program windows and `$E000` display data; start bank 1; entry `$F080`; verified `DPC* (10K)` and a drawn playfield. AR-12; spec §Lesson 60. |
| PF-06 | ACME 0.97 has **no illegal-opcode mnemonics**: `LAX`, `SAX`, `DCP`, `ISB` fail under `!cpu 6502`, and `!cpu 6502i` is an unknown processor. | The illegal-opcode lesson would not assemble. | **Resolved:** The lesson uses named `!byte` macros (`$A7` LAX zp, `$87` SAX zp, `$C7` DCP zp, `$E7` ISB zp) with the bytes and flags documented. Verified in Stella: the four operations run and the screen shows the result. AR-14; spec §Lesson 58. |
| PF-07 | Self-modifying code cannot patch cartridge ROM. The routine must be copied to RIOT RAM and executed there; the 128-byte RAM is also the stack page, so the routine and variables must not collide. | A demo that writes to `$F000` would do nothing; a routine at `$F0` could corrupt the stack. | **Resolved:** The lesson copies a 9-byte routine to `$80–$88`, uses `$89–$9F` for variables, keeps the stack at `$F8–$FF`, and calls the routine with `JSR`/`RTS`. Verified with a RAM-executed gradient. AR-15; spec §Lesson 59. |
| PF-08 | The Part 8 stubs and prior commit messages assume a 4,096-byte ROM. Part 8 ships 4K, 8K, 10K, and 16K images. | Wrong expected sizes in docs/commits; misleading audits. | **Resolved:** Every lesson spec states its size; `npm run roms` and `verify.sh` already handle any size; the docs and commits state the actual size. AR-8; spec headers. |
| PF-09 | The in-browser player must run every buildable lesson. Javatari's mapper table includes `F8` ("8K Atari (+RAM)"), `F6` ("16K Atari (+RAM)"), `F4`, and `DPC`; it has no separate `F8SC` entry. Its F8 implementation enables the 128-byte RAM after the first write to the low 128 bytes and reads it at +128, which is the Superchip window. | A Superchip/DPC lesson could embed a player that cannot run it. | **Resolved:** F8SC uses Javatari's F8(+RAM) path; DPC uses its DPC path. The bundle stays unmodified. AR-29; spec §Lesson 57/60. |
| PF-10 | The DPC write-function decode is `(address >> 3) & 7`. The bottom registers are `$1048`+index, not `$1041`+index; the counter-high registers are `$1058`+index. Writing `$1041`, `$104A`, `$104B`, or `$1053` sets other fetchers and silently loses planes. | A wrong register table produces a black or partial picture. | **Resolved:** The measured table is in AR-30 and spec §Lesson 60; the prototype's first picture lost two planes, the corrected table drew them. |
| PF-11 | The reverse-engineering lesson cannot ship a copyrighted classic ROM; the cartridge lesson cannot ship a physical cart. RD-08 still requires a buildable artifact. | A lesson with no runnable artifact would fail the five hard rules. | **Resolved:** Lesson 62 ships a course-written classic-style game (`demo-62.asm`) that is fully annotatable; Lesson 64 ships a cartridge burn-in test ROM (`demo-64.asm`); both are original and runnable. AR-17, AR-19. |
| PF-12 | A two-bank or DPC demo shows only one state in a still. The reader cannot see the switch/phase from one capture. | The screenshots would not prove the lesson's mechanism. | **Resolved:** Two captures per lesson, chosen from different states; the state log proves the transition. AR-7, AR-23; spec §Screenshots. |

### Minor

| ID | Finding | Resolution |
| --- | --- | --- |
| PF-13 | The 4K stubs use "Coming Soon" and a 4K-only mental model. | Rewritten per lesson; the index flips per lesson. |
| PF-14 | Lesson 56's cross-bank jump must fetch the JMP from the target bank. | The switch-and-jump stub is duplicated at the same fixed address in both banks (AR-31). |
| PF-15 | Lesson 56 exercise 2 uses F6; F6 starts in bank 0, unlike F8. | The exercise places its entry in bank 0 and uses `$1FF6–$1FF9` (AR-33). |
| PF-16 | The DPC music fetchers are more complex than the graphics fetchers. | The main demo uses the three graphics fetchers and the RNG; the music fetcher is an optional exercise with the measured register table. |
| PF-17 | PAL has 104 colors, NTSC 128; a color value can look different across regions. | Lesson 65 shows a color-bar test and states the mapping is approximate (AR-32). |
| PF-18 | The PAL frame is 312 lines; the course's picture is 192 lines. | The PAL frame is 3 + 45 + 192 + 72 = 312; the doc explains the padding. |
| PF-19 | The cartridge lesson's checksum must cover the actual ROM, including the vectors. | The demo computes the checksum over the 4K image and displays it. |
| PF-20 | The reverse-engineering demo needs symbols to annotate. | The build uses `acme -l` and the doc quotes the symbol table; the source is fully commented. |
| PF-21 | The attract-mode demo needs a compact font/table to fit 4K. | It uses a 5×7 font and a short pre-shifted message; the doc states the size. |
| PF-22 | The index and README must not claim a lesson is complete before its commit. | The index row flips in the lesson commit; the completion gate re-checks all 10. |
| PF-23 | The DPC 2K display image must be exactly 2,048 bytes. | The spec gives the three plane offsets (0, 683, 1366) and the pad arithmetic; the prototype's first attempt was 683 bytes long and was fixed. |
| PF-24 | The F8SC signature occupies the first 256 bytes of each bank; a vector or code there is invisible. | Code starts at `$F100`; the vectors are at `$FFFA–$FFFF`, outside the window. |

### Observations

| ID | Observation | Handling |
| --- | --- | --- |
| OB-1 | The Part 8 index is a minimal stub; Part 7's index format is the model. | Rebuild it in the Lesson 56 phase. |
| OB-2 | The sidebar already has 56–65; no `config.ts` change is expected. | Verify only; update if a title/link differs. |
| OB-3 | The `include/score.asm` kernel is available for Lessons 63/65 if a text band is useful. | Optional; the lesson specs choose simpler kernels where the focus is elsewhere. |
| OB-4 | The Javatari player may not support a mapper outside F8/F6/F4(+RAM)/DPC. | Part 8 uses only supported mappers. |

## Prototype Evidence

| Prototype | Command / artifact | Result |
| --- | --- | --- |
| F8 8K | two 4K windows, `!pseudopc` bank 0, vector in each bank | `size=8192`; Stella `Bankswitch Type: F8* (8K)` |
| F8 switch | duplicated `$F060`/`$F070` trampolines | bank 1 runs at power-on; the hotspot read switches to bank 0; the trampoline bytes are identical in both banks |
| F8SC 8K | 128-byte signature duplicated at +128 in each bank; code `$F100`; `STA $1000`/`LDA $1080` | `size=8192`; Stella `F8SC* (8K)`; the RAM read returns the written value |
| F6 16K | four 4K windows; four colors; vector per bank | `size=16384`; Stella `F6* (16K)`; the start color is bank 0's `$84` |
| DPC 10K | 8K program + 2K display; start bank 1; entry `$F080`; DF0/1/2 planes | `size=10240`; Stella `DPC* (10K)`; the three fetchers draw the playfield; the counter-high fix restored the missing planes |
| Illegal opcodes | `!byte $A7/$87/$C7/$E7` | `size=4096`; the screen shows the result color; no invalid-instruction trap |
| Self-modifying | routine copied to `$80`, operand patched, `JSR $80` | `size=4096`; the capture shows a per-line color gradient |
| Javatari | mapper table in `docs/public/javatari/javatari.js` | `F8` = "8K Atari (+RAM)"; `F6`/`F4` = (+RAM); `DPC` present; no separate F8SC entry |
| PAL/NTSC | web research + expert references | no software-only detection on stock hardware; Harmony/Melody ARM is the exception |

## Gate Conditions Carried into Execution

1. Every F8/F8SC/DPC layout puts the reset entry in the start bank (1); F6 uses bank 0.
2. Every F8SC bank starts with the duplicated 128-byte signature and code at `$F100`.
3. The DPC image is exactly 10,240 bytes; entry `$F080`; display data at offset 8K.
4. Every illegal opcode is a documented `!byte` with its byte, flags, and cycle cost.
5. Every self-modifying routine is copied to `$80–$88` before it runs; the stack stays at `$F8`.
6. Every PAL/NTSC claim is framed as a selector, not auto-detection.
7. Every screenshot comes from the committed ROM and is pixel-checked.
8. `bash scripts/verify.sh` is green before every lesson commit.
