# Part 8 — Advanced Topics (Lessons 56–65) Implementation Plan

> **Feature**: Curriculum — complete Part 8 by shipping lessons 56–65 as a reviewed lesson set
> **Status**: Executing (5/10 lessons complete)
> **Created**: 2026-11-06
> **Implements**: curriculum/RD-08
> **Source**: ../../requirements/RD-08-part8-advanced.md
> **CodeOps Artifact Schema**: 1

## Overview

Part 8 leaves the 4K world and teaches how real 2600 software is shipped. The ten lessons move
from the cartridge bus outward: bank switching (56), the Superchip's 128-byte RAM (57), the
undocumented opcodes (58), self-modifying code in RIOT RAM (59), the DPC display processor and
DPC+ (60), compression (61), reverse engineering (62), modern homebrew practice (63), physical
cartridges (64), and PAL/NTSC timing (65).

Seven lessons are buildable labs with a main source and three exercise solutions; three are
method/production lessons whose artifact is a standalone `demo-NN.asm` (the reverse-engineering
target, the attract-mode demo, and the cartridge burn-in test). The pictures are the evidence:
two different banks, a scrolling Superchip notebook, an opcode laboratory, a RAM-painted
gradient, a DPC playfield, a decompressed logo, a classic-style game with a debug overlay, an
attract mode, a burn-in test, and a PAL/NTSC selector. The state log proves the mapper, the RAM
window, the patched instruction, the DPC fetchers, and the frame length; the static ledger proves
the cycle and line arithmetic.

The work runs as ten phases, one per lesson, strictly sequential because 57 builds on 56's
banking, 60 uses the F8-style layout with the DPC twist, and 65's frame selector assumes the
Part 2–7 skeleton. Every phase follows the mandatory three-session ordering: Session A freezes
that lesson's specification cases, Session B implements, Session C verifies against the frozen
cases and hardens under independent review. `bash scripts/verify.sh` is the gate for every phase;
both specialist reviewers must report no critical/major findings before a lesson counts as done.

## Minimum-Sufficient Baseline

**Original goal:** plan, preflight, and execute RD-08 (Part 8 — Advanced Topics, lessons 56–65) at
the same quality bar as Parts 1–7.
**Smallest viable design:** reuse the existing lesson pipeline, frame skeleton, HMOVE
positioning, screenshot tooling, and the shipped libraries (`include/vcs.asm`,
`include/macro.asm`, `include/score.asm`). The new work is lesson content and mapper-specific
source layouts, not new tooling.
**Excluded machinery:** a general bankswitching library, an ARM/DPC+ toolchain, an LZ compressor,
a PCB design file set, a new emulator, an emulator modification, and a test framework. DPC+ is
documented, not built (AR-13). The physical-cartridge lesson ships a burn-in ROM, not Gerbers.
**Approved complexity:** lesson-local F8/F8SC/DPC layouts, `!byte` macros for illegal opcodes,
and a copy-to-RAM self-modifying routine (AR-10–AR-16). There is no new shared include in this
plan (AR-28).

## Document Index

| #   | Document                                       | Description                                 |
| --- | ---------------------------------------------- | ------------------------------------------- |
| AR  | [Ambiguity Register](00-ambiguity-register.md) | Zero-Ambiguity Gate decisions (audit trail) |
| PF  | [Preflight Report](00-preflight-report.md)      | Plan-level audit findings and prototypes    |
| 00  | [Index](00-index.md)                           | This document — overview and navigation     |
| 01  | [Requirements](01-requirements.md)             | Delta view of RD-08 and plan-local criteria |
| 02  | [Current State](02-current-state.md)           | Analysis of the existing course state       |
| 03  | [Lesson Specifications](03-lesson-specs.md)    | Per-lesson ROM, visual, logic, and exercise design |
| 07  | [Testing Strategy](07-testing-strategy.md)     | Specification test cases and verification   |
| 05  | [Findings Ledger](05-findings.md)              | Per-phase review findings (appended during execution) |
| 99  | [Execution Plan](99-execution-plan.md)         | Phases, sessions, and task checklist        |

## Quick Reference

### Usage Examples

```bash
# Build and run Lesson 56 (F8, 8K)
acme -f plain -o build/lesson56.bin \
  lessons/part8-advanced/56-bankswitching/56-bankswitching.asm
stella build/lesson56.bin            # the auto-demo switches banks; fire switches too

# Build and run Lesson 60 (DPC, 10K)
acme -f plain -o build/lesson60.bin \
  lessons/part8-advanced/60-dpc-plus/60-dpc-plus.asm
stella build/lesson60.bin            # the DPC display fetchers draw the playfield

# Rebuild every committed ROM and run the gate
npm run roms
bash scripts/verify.sh
```

### Key Decisions

| Decision | Outcome |
| --- | --- |
| Part scope | Lessons 56–65 only; curriculum frozen (AR-1) |
| Phases | 10 lesson phases + completion gate (AR-2) |
| Artifacts | 7 buildable labs × 4 sources; 3 theory lessons × 1 demo (AR-3) |
| ROM sizes | 4K, 8K, 10K, 16K — mapper-correct (AR-8) |
| Start banks | F8/F8SC/DPC bank 1; F6 bank 0 (AR-10) |
| Superchip | F8SC, `$1000–$107F` write / `$1080–$10FF` read, code at `$F100` (AR-11) |
| DPC | 10K, bank 1, entry `$F080`, 2K display at offset 8K (AR-12) |
| DPC+ | Documented only (AR-13) |
| Illegal opcodes | `!byte` macros, stable NMOS set (AR-14) |
| Self-modifying | Routine in `$80–$88`, JSR/RTS (AR-15) |
| Compression | RLE, 3-byte row buffer (AR-16) |
| Reverse engineering | Course-written classic-style ROM (AR-17) |
| Homebrew | Attract-mode demo (AR-18) |
| Cartridge | Burn-in test ROM, prose for hardware (AR-19) |
| PAL/NTSC | Selector + adaptive 262/312 lines; no false auto-detect (AR-20) |
| Evidence | State logs + static ledgers + pixel checks (AR-23) |
| Completion | 31 sources/ROMs, 10 docs, 20 screenshots; RD-08 Done; 8/11 RDs (AR-27) |

## Risks and Mitigations

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| DPC register mistakes | The DPC's function decode is easy to misread; a wrong counter-high address silently loses a plane | The measured register table (AR-30) is in the spec; the prototype's picture is the red test; the lesson author logs the fetched bytes |
| Superchip auto-detection | Without the duplicated 128-byte signature Stella loads F8 and the RAM reads return ROM | The signature and `$F100` code start are mandatory; the preflight verified `F8SC*` |
| F8 start bank | Code in bank 0 never runs at power-on | Every F8/F8SC/DPC layout puts the entry in the start bank (AR-10) |
| Javatari mapper support | The five hard rules require an embedded player | Javatari's F8(+RAM) and DPC formats cover the mappers; the bundle stays unmodified (AR-29) |
| PAL/NTSC false claim | The stub says "runtime detection", which is impossible on stock hardware | The lesson teaches a selector and documents the Harmony exception (AR-20) |
| Ten-lesson scope | More work than Part 7; risk of a rushed lesson | Strict phase order; three lessons are demo-only; the gate is per lesson |
| 4K assumptions | The docs and commits previously said 4,096 bytes | Every lesson's expected size is in the spec; verify.sh compares actual output |

## Integration

- Sidebar entries for 56–65 already exist in `docs/.vitepress/config.ts` (lines 139–148); no
  navigation change is expected, only verification.
- The Part 8 index (`docs/part8-advanced/index.md`) is rebuilt to the Part 1 format in the Lesson
  56 phase; rows 56–65 flip per lesson.
- Lesson 55's `next` already points to `/part8-advanced/56-bankswitching`; Lesson 56's `prev`
  points back to 55; each lesson's `next` points to the next stub.
- README row 8 already says `Advanced Topics | 56–65`; it must not change.
- The completion gate updates `codeops/features/curriculum/00-roadmap.md` (RD-08 Done, 8/11) and
  `codeops/00-roadmap.md` (8 plans done).
