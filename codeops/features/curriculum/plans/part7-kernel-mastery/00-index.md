# Part 7 — Kernel Mastery (Lessons 48–55) Implementation Plan

> **Feature**: Curriculum — complete Part 7 by shipping lessons 48–55 as a reviewed lesson set
> **Status**: Executing (2/8 lessons complete)
> **Created**: 2026-11-05
> **Implements**: curriculum/RD-07
> **Source**: ../../requirements/RD-07-part7-kernel-mastery.md
> **CodeOps Artifact Schema**: 1

## Overview

Part 7 turns the rendering and game skills of Parts 1–6 into kernel architecture. The eight
lessons move from the kernel taxonomy and the 1-line/2-line trade-off (48–49), through a
multi-zone dashboard (50), flicker (51), fine scrolling (52), a reusable kernel-pattern library
(53), a visual-effects cookbook (54), to a 48-pixel scrolling text marquee (55).

Each lesson is a kernel lab whose picture **is** the evidence: a split 1-line/2-line diamond, a
chunky mountain landscape, a score/status/play dashboard, two flicker halves, a scrolling tunnel,
a four-band pattern sampler, a starfield/rainbow/road reel, and a scrolling text banner. The state
log proves the scanline stores and the frame count; the static ledger proves the cycle and line
arithmetic; the committed ROM is what the reader runs.

Every lesson ships the course's full artifact set: annotated assembly, three exercise solutions, a
document built from the fixed lesson template, two real Stella screenshots, a committed
4,096-byte ROM with a `<RomPlayer>` embed, and the part-index and prev/next updates. Lesson 48
ships the theory demo `demo-48.asm`; Lesson 53 ships `include/kernel_patterns.asm`; Lessons 50 and
55 reuse `include/score.asm` from Lesson 39. Per AR-3 there is no other standalone demo.

The work runs as eight phases, one per lesson, strictly sequential because 48 introduces the
taxonomy and the 1-line/2-line shapes, 49 builds the 2-line kernel, 50 reuses it plus the score
library, 54 uses 52's scroll with its own effect tables, and 55 reuses 39's 48-pixel kernel (not
the pattern library). Every phase follows the mandatory three-session ordering: Session A freezes that lesson's
specification cases, Session B implements, Session C verifies against the frozen cases and hardens
under independent review. The gate for every phase is `bash scripts/verify.sh`; both specialist
reviewers must report no critical/major findings before a lesson counts as done.

## Minimum-Sufficient Baseline

**Original goal:** plan, preflight, and execute RD-07 (Part 7 — Kernel Mastery, lessons 48–55) at
the same quality bar as Parts 1–6.
**Smallest viable design:** reuse the existing lesson pipeline, frame skeleton, one-HMOVE
positioning, and screenshot tooling; add one small promised library (`include/kernel_patterns.asm`)
and one theory demo; no new tooling, framework, or infrastructure.
**Excluded machinery:** a test framework, a sprite-scaling engine, a general text renderer beyond
the 48-pixel window, a scrolling-world editor, sampled audio, and any emulator modification.
**Approved complexity:** `include/kernel_patterns.asm` (Lesson 53) and `demo-48.asm` only (AR-3,
AR-7, AR-18). `include/score.asm` is already shipped and is reused, not extended.

## Document Index

| #   | Document                                       | Description                                 |
| --- | ---------------------------------------------- | ------------------------------------------- |
| AR  | [Ambiguity Register](00-ambiguity-register.md) | Zero-Ambiguity Gate decisions (audit trail) |
| PF  | [Preflight Report](00-preflight-report.md)      | Plan-level audit findings and resolutions   |
| 00  | [Index](00-index.md)                           | This document — overview and navigation     |
| 01  | [Requirements](01-requirements.md)             | Delta view of RD-07 and plan-local criteria |
| 02  | [Current State](02-current-state.md)           | Analysis of the existing course state       |
| 03  | [Lesson Specifications](03-lesson-specs.md)    | Per-lesson ROM, visual, logic, and exercise design |
| 07  | [Testing Strategy](07-testing-strategy.md)     | Specification test cases and verification   |
| 05  | [Findings Ledger](05-findings.md)              | Per-phase review findings (appended during execution) |
| 99  | [Execution Plan](99-execution-plan.md)         | Phases, sessions, and task checklist        |

## Quick Reference

### Usage Examples

```bash
# Build and run Lesson 52
acme -f plain -o build/lesson52.bin \
  lessons/part7-kernel-mastery/52-fine-scrolling/52-fine-scrolling.asm
stella build/lesson52.bin          # the tunnel scrolls; move the ship with the joystick

# Rebuild every committed ROM and run the gate
npm run roms
bash scripts/verify.sh
```

### Key Decisions

| Decision | Outcome |
| --- | --- |
| Scope | RD-07 only; lessons 48–55 strictly sequential (AR-1, AR-42) |
| Phasing | Eight phases, one per lesson; Sessions A/B/C (AR-2) |
| Demo ROMs | `demo-48.asm` only; lessons 49–55 are kernel labs (AR-3) |
| Verify | `bash scripts/verify.sh` (AR-4) |
| Reviews | `atari2600-reviewer` + `curriculum-auditor`; no critical/major (AR-5) |
| Evidence | State logs + static ledgers + pixel checks; the ROM is runnable (AR-6) |
| New machinery | `include/kernel_patterns.asm` (53); `demo-48.asm` (AR-7) |
| Lesson 48 | Split 1-line/2-line kernel zoo + full modes (AR-13, AR-32) |
| Lesson 49 | 2-line mountain pass, 63 effective cycles/2 lines (62 nominal) (AR-14, AR-33) |
| Lesson 50 | Score + status + play + ground; score library reused; two HMOVEs (AR-15, AR-27, AR-34) |
| Lesson 51 | Four-object flicker gallery; two 30 Hz halves; per-row skipdraw, no strips (AR-16, AR-29, AR-35) |
| Lesson 52 | Three-plane vertical tunnel + 1-px HMOVE ship (AR-17, AR-30, AR-36) |
| Lesson 53 | Four-band pattern sampler + `include/kernel_patterns.asm` (AR-18, AR-28, AR-37) |
| Lesson 54 | Starfield, rainbow, centred pseudo-3D road reel (AR-19, AR-38) |
| Lesson 55 | 48-pixel scrolling text marquee via `include/score.asm` (not the pattern library) (AR-20, AR-31, AR-39) |
| Audio | Tiny direct beep in the state-changing lessons (AR-21) |
| RAM | `$80–$9F` lesson; `$A0–$D7` score in 50/55; `$80–$83` library + `$84–$9F` counters + `$A0–$CF` strip in 53; `$D8–$F7` free; `$F8–$FF` stack (AR-22) |
| Screenshots | Two per lesson, committed-ROM provenance, burst selection (AR-23) |
| Frame | 262 lines; work-first except documented cycle-timed kernels; `LDY #0; INY; CPY #N; BNE` top-down row loops; one HMOVE per repositioning event (AR-25) |
| Part index | Rebuilt in the Lesson 48 phase; rows flip per lesson (AR-10) |

## Specialist Agents

| Role | Kind | Use | AR Ref |
| --- | --- | --- | --- |
| `lesson-author` | executor | Implements lessons 48–55 end-to-end from the per-lesson specifications; the parent verifies each artifact and runs the gates | — |
| `atari2600-reviewer` | reviewer | Hardware/CPU review of every lesson phase | AR-5 |
| `curriculum-auditor` | reviewer | Five-rule and didactic-chain audit of every lesson phase | AR-5 |

_Detection evidence: `codeops/codeops.json` already routes `lesson-author`, `atari2600-reviewer`,
and `curriculum-auditor`; `.opencode/agents/` contains the project agents; the Part 1–6 plans used
the two reviewers per lesson. Lessons 48–55 are kernel-heavy, so the `lesson-author` role is the
implementation executor and the parent keeps the verification, review dispatch, and commit
authority. No new specialist gap was found: the kernel timing, scroll, flicker, text, and effects
are covered by the existing `atari-2600-expert` references (kernels, timing, sprite tricks,
legendary techniques) and the two reviewers._

## Related Files

| Path | Purpose |
| --- | --- |
| `lessons/part7-kernel-mastery/48-introduction-to-kernels/` … `55-scrolling-text-marquee/` | Lesson sources and exercise solutions |
| `docs/part7-kernel-mastery/48-introduction-to-kernels.md` … `55-scrolling-text-marquee.md` | Lesson documents (stubs today) |
| `docs/public/roms/part7-kernel-mastery/48…55/` | Committed ROMs |
| `docs/public/images/lesson48/` … `lesson55/` | Screenshots |
| `docs/part7-kernel-mastery/index.md` | Part index (stub; rebuilt in Phase 1) |
| `include/kernel_patterns.asm` | Lesson 53 library |
| `include/score.asm` | Reused by Lessons 50 and 55 |
| `docs/.vitepress/config.ts` | Sidebar (entries already exist; verify only) |
| `README.md` | Curriculum listing (row 7 already correct; verify only) |
