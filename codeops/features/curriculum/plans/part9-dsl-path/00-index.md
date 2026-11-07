# Part 9 — The DSL Path (Lessons 66–68) Implementation Plan

> **Feature**: Curriculum — complete Part 9 by shipping lessons 66–68 as a reviewed lesson set
> **Status**: Planning Complete (preflighted; ready for execution)
> **Created**: 2026-11-07
> **Implements**: curriculum/RD-09
> **Source**: ../../requirements/RD-09-part9-dsl-path.md
> **CodeOps Artifact Schema**: 1

## Overview

Part 9 is the course's bridge from hand-written kernels to code generation. The three lessons
move from reading a real compiler's output, to automating a repeated game pattern, to designing a
kernel framework that composes a 192-line frame from configurable zones. The through-line is the
**virtual screen**: a description exists at design time, and a compiler or generator lowers it
into the tables and code the 2600 races in real time.

Lesson 66 analyzes a real batari BASIC 1.9 compilation. The reader sees the four-stage bB
pipeline, the generated `start`/`drawscreen`/`kernel` skeleton, the 2-line kernel, the reversed
comparison the compiler emits for `if`, the BCD score, and the fixed zero-page variable map. The
lesson's `demo-66.asm` is a hand-written ACME visualization with three lenses: the bB-style
picture, the four frame phases, and the bB RAM map. The real bB source, generated listing, and
4,096-byte reference ROM are committed as evidence; the demo is never described as generated
code.

Lesson 67 turns a repeated wave pattern into a small description language and a generator. The
spec is line-oriented text (`level`, `name`, `bg`, `pf`, `backdrop`, `wave`); the Python generator
validates it, emits an ACME include, and has a `--check` mode that catches drift. The 4,096-byte
"wave lab" interprets the generated tables: two levels, SELECT to switch, falling waves, a
player, fire, collisions, and a score.

Lesson 68 designs the kernel architecture. `include/kernel_framework.asm` composes the existing
`include/kernel_patterns.asm` routines into configurable display zones. Each zone costs its data
lines plus one boundary line; `+kf_end` refuses to assemble unless the budget is exactly 192. The
demo shows three layouts built from the same macros (STATUS, STARFIELD, SPLIT) and selects them
with SELECT. The build-time check and the measured 262-line frame are the evidence.

Every lesson follows the mandatory three-session ordering: Session A freezes the specification
cases and records a red baseline; Session B implements; Session C verifies against the frozen
cases and hardens under independent review. `bash scripts/verify.sh` is the gate for every phase;
both specialist reviewers must report no critical/major findings before a lesson counts as done.

## Minimum-Sufficient Baseline

**Original goal:** plan, preflight, and execute RD-09 (Part 9 — The DSL Path, lessons 66–68) at
the same quality bar as Parts 1–8.
**Smallest viable design:** reuse the existing lesson pipeline, the 262-line frame skeleton,
`include/vcs.asm`, `include/macro.asm`, `include/score.asm`, and `include/kernel_patterns.asm`.
The new work is lesson content, one bB reference compilation, one small Python data generator, and
one macro-composed kernel framework.
**Excluded machinery:** a bB compiler in the repository, a general-purpose compiler, a full
language implementation, a build-time Python dependency in CI, a new emulator, a mapper, and a
test framework.
**Approved complexity:** `include/kernel_framework.asm` (AR-16) and `lesson67-generate.py`
(AR-13). Both are lesson-scoped and documented; neither changes earlier lessons.

## Document Index

| #   | Document                                       | Description                                 |
| --- | ---------------------------------------------- | ------------------------------------------- |
| AR  | [Ambiguity Register](00-ambiguity-register.md) | Zero-Ambiguity Gate decisions (audit trail) |
| PF  | [Preflight Report](00-preflight-report.md)      | Plan-level audit findings and prototypes    |
| 00  | [Index](00-index.md)                           | This document — overview and navigation     |
| 01  | [Requirements](01-requirements.md)             | Delta view of RD-09 and plan-local criteria |
| 02  | [Current State](02-current-state.md)           | Analysis of the existing course state       |
| 03  | [Lesson Specifications](03-lesson-specs.md)    | Per-lesson ROM, visual, logic, and exercise design |
| 07  | [Testing Strategy](07-testing-strategy.md)     | Specification test cases and verification   |
| 05  | [Findings Ledger](05-findings.md)              | Per-phase review findings (appended during execution) |
| 99  | [Execution Plan](99-execution-plan.md)         | Phases, sessions, and task checklist        |

## Quick Reference

### Usage Examples

```bash
# Build and run Lesson 66 (the bB analysis demo)
acme -f plain -o build/demo-66.bin \
  lessons/part9-dsl-path/66-analyzing-batari-basic/demo-66.asm
stella build/demo-66.bin             # SELECT cycles RUN / ZONES / VARS

# Rebuild the Lesson 67 generated include, then the ROM
python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-a.txt \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-b.txt \
  --out lessons/part9-dsl-path/67-automatable-patterns/generated-levels.inc
acme -f plain -o build/lesson67.bin \
  lessons/part9-dsl-path/67-automatable-patterns/67-automatable-patterns.asm

# Build and run Lesson 68 (the zone framework)
acme -f plain -o build/lesson68.bin \
  lessons/part9-dsl-path/68-kernel-architecture/68-kernel-architecture.asm
stella build/lesson68.bin            # SELECT cycles STATUS / STARFIELD / SPLIT

# Rebuild every committed ACME ROM and run the gate
npm run roms
bash scripts/verify.sh
```

### Key Decisions

| Decision | Outcome |
| --- | --- |
| Part scope | Lessons 66–68 only; curriculum frozen (AR-1) |
| Phases | 3 lesson phases + completion gate (AR-2) |
| Artifacts | 1 theory demo + 2 buildable labs × 4 sources (AR-3) |
| ROM sizes | 4,096 for every lesson; no mapper (AR-8) |
| bB | bB 1.9 + wasmtime in preflight only; `.bas`, listing, reference ROM committed (AR-9) |
| Lesson 66 | Three lenses; hand-written demo, real bB listing as the subject (AR-11, AR-12) |
| Lesson 67 | Python generator + wave-spec DSL; two generated levels; playable lab (AR-13–AR-15) |
| Lesson 68 | `include/kernel_framework.asm`; macro zones; build-time 192-line check (AR-16–AR-19) |
| Zone budget | data lines + 1 boundary line per zone = 192 (AR-17) |
| RAM | framework owns `$80–$82`; lesson variables from `$83` (AR-20) |
| Frame | NTSC 262; `OverscanStart` 229 (cycle varies with the layout) (AR-21) |
| Evidence | State logs + static ledgers + pixel checks + committed bB listing (AR-22) |
| Completion | 9 ACME + 1 bB reference ROM, 3 docs, 10 screenshots, 252/253 ROMs (AR-26) |

## Specialist Agents

| Role | Kind | Use | AR Ref |
| ---- | ---- | --- | ------ |
| `lesson-author` | executor | Session B implementation of each lesson | AR-2 |
| `atari2600-reviewer` | reviewer | Hardware/CPU/bB/framework correctness review of every phase | AR-5 |
| `curriculum-auditor` | reviewer | Five hard rules, didactic chain, site integration | AR-5 |

_Detection evidence: the three roles already exist under `.opencode/agents/` and were used for
Parts 7–8; Part 9 adds a compiler-analysis lesson, a Python generator, and a kernel framework, all
covered by the existing reviewer's hardware/CPU scope and the auditor's lesson-completeness scope.
No new specialist is needed._

## Risks and Mitigations

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| bB output misread | The generated code is the lesson's subject; a wrong claim about `if`, BCD, or the kernel fails the claim discipline | The 4,096-byte reference build is committed; the doc quotes the generated listing with line numbers; the reviewer checks each claim against the listing |
| bB toolchain drift | A future bB version could produce a different listing | The doc pins bB 1.9 and wasmtime 50.0.1; the listing is committed as the artifact of record |
| Generator drift | The committed include could stop matching the specs | `lesson67-generate.py --check` compares the regenerated include; CI does not need Python; the author runs the check before the lesson commit |
| Framework budget error | A zone table that sums to 191 or 193 silently breaks the frame | `+kf_end` is a build-time `!error`; the preflight prototype caught a 191-line layout; every layout is assembled before capture |
| Boundary artifacts | The zone dispatch adds one line per zone and a 13-cycle overscan tax | The boundary line is counted in the budget; the last zone is black; the doc states the measured 229/19 entry and why the sliver is invisible |
| RAM collision | The pattern library owns `$80–$82`; a lesson variable there corrupts the kernel | The lesson map starts at `$83`; the source header and doc state the ownership; the prototype caught the collision |
| 4K budget | The demo, generator tables, framework, and three layouts could exceed 4,096 | The specs pin the data sizes; the author checks the assembled size before capturing; the exercises use compact tables |
| Screenshot provenance | A moving/dynamic state captured by a fixed wait may not match the ROM | Captures come from the committed ROM; the state log proves the selected state; the doc discloses the wait/SELECT method |

## Integration

- The sidebar entries for 66–68 already exist in `docs/.vitepress/config.ts` (lines 153–158); no
  navigation change is expected, only verification.
- The Part 9 index (`docs/part9-dsl-path/index.md`) is already a proper index; the three lesson
  rows flip per lesson. The index's "Browse the lessons" line stays.
- Lesson 65's `next` already points to `/part9-dsl-path/66-analyzing-batari-basic`; Lesson 66's
  `prev` points back to 65; each lesson's `next` points to the next stub; Lesson 68's `next`
  points to Part 10's Lesson 69.
- README row 9 already says `The DSL Path | 66–68`; it must not change.
- The completion gate updates `codeops/features/curriculum/00-roadmap.md` (RD-09 Done, 9/11) and
  `codeops/00-roadmap.md` (9 plans done).

## Related Files

- `lessons/part9-dsl-path/66-analyzing-batari-basic/` — demo, bB source, generated listing.
- `lessons/part9-dsl-path/67-automatable-patterns/` — main source, three solutions, generator,
  specs, generated include.
- `lessons/part9-dsl-path/68-kernel-architecture/` — main source and three solutions.
- `include/kernel_framework.asm` — the new zone framework.
- `docs/part9-dsl-path/66-analyzing-batari-basic.md`, `67-automatable-patterns.md`,
  `68-kernel-architecture.md`.
- `docs/public/roms/part9-dsl-path/` — the committed ROMs.
- `docs/public/images/lesson66/`, `lesson67/`, `lesson68/` — the captures.
