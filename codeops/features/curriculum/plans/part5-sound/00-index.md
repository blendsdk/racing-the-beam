# Part 5 — Sound (Lessons 35–37) Implementation Plan

> **Feature**: Curriculum — complete Part 5 by shipping lessons 35–37 as a reviewed lesson set
> **Status**: Preflight Complete
> **Created**: 2026-11-04
> **Implements**: curriculum/RD-05
> **Source**: ../../requirements/RD-05-part5-sound.md
> **CodeOps Artifact Schema**: 1

## Overview

Part 5 adds the TIA's two audio channels: the first purely temporal output in the course. The
three lessons move from a single sound effect (35), through a two-channel melody with a tuned note
table (36), to a small data-driven sound engine with priority (37). Audio is invisible, so every
lesson also carries a **visual monitor** built from the objects and playfield the reader already
knows: a sound lab with a volume meter and a pitch marker, a two-column note ladder, and a
two-channel mixer with a priority bar. The picture shows the audio state; the state log proves the
register writes; the committed ROM is where the reader hears the result.

Each lesson ships the course's full artifact set: annotated assembly, three exercise solutions, a
document built from the fixed lesson template, two real Stella screenshots, a committed
4,096-byte ROM with a `<RomPlayer>` embed, and the part-index and prev/next updates. Per AR-3, no
standalone `demo-NN.asm` ships in this part — each main ROM is the concept made visible. Lesson 37
also ships the small `include/sound.asm` library promised by its curriculum stub (AR-7, AR-18).

The work runs as three phases — one per lesson, strictly sequential because Lesson 36 reuses
Lesson 35's audio registers and Lesson 37 generalizes Lesson 36's timing. Every phase follows the
mandatory three-session ordering: Session A freezes that lesson's specification cases, Session B
implements, Session C verifies against the frozen cases and hardens under independent review. The
gate for every phase is `bash scripts/verify.sh`; both specialist reviewers must report no
critical/major findings before a lesson counts as done. The highest-risk claims are the tone
frequency arithmetic, the exact register values per frame, and the priority semantics — each is
pinned by a state log and a static ledger.

## Minimum-Sufficient Baseline

**Original goal:** plan, preflight, and execute RD-05 (Part 5 — Sound, lessons 35–37) at the same
quality bar as Parts 1–4.
**Smallest viable design:** reuse the existing lesson pipeline and frame skeleton; add three
visual monitors and one small sound library; no new tooling, framework, or infrastructure.
**Excluded machinery:** an audio-capture pipeline, a waveform analyzer, a full music tracker, and
preemption-with-resume in the engine (AR-6, AR-18).
**Approved complexity:** `include/sound.asm` only (AR-7, AR-18); everything else reuses existing
patterns.

## Document Index

| #   | Document                                       | Description                                 |
| --- | ---------------------------------------------- | ------------------------------------------- |
| AR  | [Ambiguity Register](00-ambiguity-register.md) | Zero-Ambiguity Gate decisions (audit trail) |
| 00  | [Index](00-index.md)                           | This document — overview and navigation     |
| 01  | [Requirements](01-requirements.md)             | Delta view of RD-05 and plan-local criteria |
| 02  | [Current State](02-current-state.md)           | Analysis of the existing course state       |
| 03  | [Lesson Specifications](03-lesson-specs.md)    | Per-lesson ROM, visual, audio, and exercise design |
| 07  | [Testing Strategy](07-testing-strategy.md)     | Specification test cases and verification   |
| 05  | [Findings Ledger](05-findings.md)              | Per-phase review findings (appended during execution) |
| 99  | [Execution Plan](99-execution-plan.md)         | Phases, sessions, and task checklist        |

## Quick Reference

### Usage Examples

```bash
# Build and run Lesson 35
acme -f plain -o build/lesson35.bin \
  lessons/part5-sound/35-sound-effects/35-sound-effects.asm
stella build/lesson35.bin          # click the screen, then listen

# Rebuild every committed ROM and run the gate
npm run roms
bash scripts/verify.sh
```

### Key Decisions

| Decision | Outcome |
| --- | --- |
| Scope | RD-05 only; lessons 35–37 strictly sequential (AR-1) |
| Phasing | Three phases, one per lesson; Sessions A/B/C (AR-2) |
| Demo ROMs | None; each main ROM carries a visual monitor (AR-3) |
| Verify | `bash scripts/verify.sh` (AR-4) |
| Reviews | `atari2600-reviewer` + `curriculum-auditor`; no critical/major (AR-5) |
| Audio evidence | State logs + static ledgers + pixel checks; the ROM is the audible artifact (AR-6, AR-22) |
| New machinery | `include/sound.asm` only, promised by the Lesson 37 stub (AR-7) |
| Tuning | div 6; one published `AUDF` table and cents errors; harmony rather than an out-of-range bass (AR-16) |
| Engine | 8-byte data-driven definitions, two channels, priority (AR-18) |
| Part index | Rebuilt to the Part 1 format in the Lesson 35 phase (AR-10) |

## Specialist Agents

| Role | Kind | Use | AR Ref |
| --- | --- | --- | --- |
| `lesson-author` | executor | Not used as a separate executor in this run; the plan is executed directly with the lesson-production skill | — |
| `atari2600-reviewer` | reviewer | Hardware/CPU review of every lesson phase | AR-5 |
| `curriculum-auditor` | reviewer | Five-rule and didactic-chain audit of every lesson phase | AR-5 |

_Detection evidence: `codeops/codeops.json` already routes `lesson-author`, `atari2600-reviewer`,
and `curriculum-auditor`; `.opencode/agents/` contains the project agents; the Part 1–4 plans used
the two reviewers per lesson. No new specialist gap was found: audio is covered by the existing
`atari-2600-expert` reference and the Atari reviewer, and the site/curriculum checks are already
owned by the auditor._

## Related Files

| Path | Purpose |
| --- | --- |
| `lessons/part5-sound/35-sound-effects/` … `37-advanced-audio/` | Lesson sources and exercise solutions |
| `docs/part5-sound/35-sound-effects.md` … `37-advanced-audio.md` | Lesson documents (stubs today) |
| `docs/public/roms/part5-sound/35…37/` | Committed ROMs |
| `docs/public/images/lesson35/` … `lesson37/` | Screenshots |
| `docs/part5-sound/index.md` | Part index (stub; rebuilt in Phase 1) |
| `include/sound.asm` | Lesson 37's sound library |
| `docs/.vitepress/config.ts` | Sidebar (entries already exist; verify only) |
| `README.md` | Curriculum listing (row 5 already correct; verify only) |
