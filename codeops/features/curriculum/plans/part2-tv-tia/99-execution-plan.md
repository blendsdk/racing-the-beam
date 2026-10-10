# Execution Plan: Part 2 — TV & TIA (Lessons 12–18)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-10-10 23:03
> **Progress**: 1/7 tasks (14%)
> **CodeOps Artifact Schema**: 1

## Overview

Seven phases, one per lesson, strictly sequential — each lesson is the next one's prerequisite
(AR-1). Every phase is one task run through the mandatory three-session ordering: Session A
freezes that lesson's specification cases, Session B implements the full artifact set, and
Session C verifies against the frozen cases and hardens under independent review (AR-2, AR-5).
`bash scripts/verify.sh` is the gate for every phase (AR-4). Timing, cycle, and frame claims
carry the state-log + ledger evidence of AR-6.

**🚨 Update this document after EACH completed task!**

---

## Implementation Phases

| Phase | Title | Tasks |
| ----- | ----- | ----- |
| 1 | Lesson 12 — The NTSC Frame | 1 |
| 2 | Lesson 13 — Colors | 1 |
| 3 | Lesson 14 — WSYNC and Timing | 1 |
| 4 | Lesson 15 — The Timer | 1 |
| 5 | Lesson 16 — Horizontal Zones | 1 |
| 6 | Lesson 17 — Cycle Counting | 1 |
| 7 | Lesson 18 — Mid-Scanline Changes | 1 |

**Total: 7 tasks across 7 phases.**

> **⚠️ EXECUTION RULE — APPLIES TO EVERY AGENT EXECUTING THIS PLAN:**
>
> The task checkboxes below are the **single source of truth** for progress. Every task line
> appears exactly once in this document. The executing agent MUST:
>
> 1. **On implementation:** mark the task `[~]` with a timestamp —
>    `- [~] 1.1.1 Task description ⏳ (implemented: YYYY-MM-DD HH:MM)`
> 2. **On verify pass:** promote it to `[x]` —
>    `- [x] 1.1.1 Task description ✅ (completed: YYYY-MM-DD HH:MM)`
> 3. **Update the Progress header** and the Last Updated stamp after EVERY task — never batch.
> 4. **Resume** at the first `[~]`, else the first `[ ]`.
> 5. **On blocker:** mark the task `[!]` with a one-line reason.
>
> Timestamps come from `date '+%Y-%m-%d %H:%M'` — never invented.

---

## Phase 1: Lesson 12 — The NTSC Frame

> **Phase baseline tree**: 4d9a7acf3186bed2d4f7f50888db06d83615ff5e (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part2-tv-and-tia/12-the-ntsc-frame/` (4 sources) · `docs/part2-tv-and-tia/12-the-ntsc-frame.md` · `docs/part2-tv-and-tia/index.md` · `docs/public/roms/part2-tv-and-tia/12-the-ntsc-frame/` · `docs/public/images/lesson12/` · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — the course's core frame-structure claims under independent hardware review

### Step 1.1: Lesson 12 — The NTSC Frame

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 12 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 12 · AR-2, AR-4, AR-6
**Objective**: Deliver lesson 12 end to end through the mandatory three sessions.

- [x] 1.1.1 Lesson 12 — The NTSC Frame: Session A freezes ST-12.1–ST-12.6 (red baseline), Session B implements the full artifact set (including the AR-10 index rebuild), Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson12): The NTSC Frame` ✅ (completed: 2026-10-10 23:03)

**Session A record** (freeze + red baseline, 2026-10-10 22:45): ST-12.1–ST-12.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 12 — four equal 48-line bands `$42`/`$84`/`$C8`/`$1A` with the release line counted inside band 0, phases 3/37/192/30 = 262 lines, solutions 48/96/48 and the 16 × 12-line ladder, screenshot `frame-anatomy.png`, site checks per ST-12.6. Red baseline confirmed: no lesson sources, ROMs, or images; the document is still the `🔒 Coming Soon` stub; the part index is still the minimal stub; `verify.sh` green with the lesson absent (expected — nothing references it yet). No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-10-10): `bash scripts/verify.sh` green (ROM drift + docs build); all four sources assemble to 4,096 bytes. State logs (AR-6, `stella -dbg.logbreaks 1 -logtoconsole 1 -break '<addr>'`): `StartFrame` reports scanline 259 every frame (frames 1–8; frame 0 is the power-on transient), `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229 — deltas 3 / 37 / 192 / 30, the frame ledger confirmed line for line. Solutions run and show their stated pictures: ex 1 the four equal bands from RAM; ex 2 the 48/96/48 partition (pixel-measured 1:2:1) with checkpoints at 37 / 84 / 180 / 229; ex 3 sixteen equal 12-line hue bands. Site (ST-12.6): the built page references the committed ROM via `<RomPlayer>` and `frame-anatomy.png`, and index row 12 links the lesson; assets present under `dist/`. Reviews: both specialists dispatched on the phase diff (both sessions reviewed statically — their sessions had no shell/tool access; they verified against the `atari-2600-expert` references and this record's live evidence). Seven findings (1 major, 6 minor: the `zp,X` read-cost claim, debugger-observation wording, scanline-origin consistency across the sources, first-value wording, luminance-field wording, RAM/stack note, and the steady-state `VblankStart` X value) — all fixed; the single bounded re-review confirmed six fixes clean and raised only the steady-state minor, fixed immediately. No critical or major findings remain (AR-5).

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-12.1–ST-12.6, including the four band colors/heights and the 3/37/192/30 phase map ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 12); record the red baseline. No implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part2-tv-and-tia/12-the-ntsc-frame/12-the-ntsc-frame.asm` + its three solutions; write `docs/part2-tv-and-tia/12-the-ntsc-frame.md`; run `npm run roms`; capture `frame-anatomy.png` from the committed ROM path; embed `<RomPlayer>`; **rebuild `docs/part2-tv-and-tia/index.md` to the Part 1 format with `🔒 Coming Soon` rows (AR-10)** and update prev/next (RD-02 AC 1; AR-6, AR-8, AR-10).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-12.* confirmed; frame-integrity edge check (steady scanline; blank-on in HBLANK); both specialist reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson12): The NTSC Frame` (AR-12).

---

## Phase 2: Lesson 13 — Colors

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Reasoning**: high — palette claims and luminance behavior under independent hardware review

### Step 2.1: Lesson 13 — Colors

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 13 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 13 · AR-2, AR-4, AR-6, AR-9
**Objective**: Deliver lesson 13 end to end through the mandatory three sessions.

- [ ] 2.1.1 Lesson 13 — Colors: Session A freezes ST-13.1–ST-13.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson13): Colors`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-13.1–ST-13.6, including the 16 hue bands, the descending luminance sequence (7→0, wrap), and the 128-color cycle ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 13); record the red baseline. No implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part2-tv-and-tia/13-colors/13-colors.asm` + its three solutions; write `docs/part2-tv-and-tia/13-colors.md`; run `npm run roms`; capture `palette-hues.png` and `palette-dim.png` from the committed ROM path; embed `<RomPlayer>`; update part index row 13 and prev/next (RD-02 AC 1; AR-6, AR-8, AR-9, AR-10).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-13.* confirmed; full-cycle luminance observation; both specialist reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson13): Colors` (AR-12).

---

## Phase 3: Lesson 14 — WSYNC and Timing

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Reasoning**: high — beam-alignment claims are correctness-sensitive under independent hardware review

### Step 3.1: Lesson 14 — WSYNC and Timing

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 14 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 14 · AR-2, AR-4, AR-6
**Objective**: Deliver lesson 14 end to end through the mandatory three sessions.

- [ ] 3.1.1 Lesson 14 — WSYNC and Timing: Session A freezes ST-14.1–ST-14.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson14): WSYNC and Timing`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-14.1–ST-14.6, including the 96/96 split and the late-mode static tear (≈25 cycles into the visible portion) ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 14); record the red baseline. No implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part2-tv-and-tia/14-wsync-and-timing/14-wsync-and-timing.asm` + its three solutions; write `docs/part2-tv-and-tia/14-wsync-and-timing.md`; run `npm run roms`; capture `wsync-aligned.png` and `wsync-torn.png` from the committed ROM path; embed `<RomPlayer>`; update part index row 14 and prev/next (RD-02 AC 1; AR-6, AR-8, AR-10).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-14.* confirmed; aligned-stability check (same boundary line across sampled frames); both specialist reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson14): WSYNC and Timing` (AR-12).

---

## Phase 4: Lesson 15 — The Timer

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Reasoning**: high — RIOT-timer budget claims under independent hardware review

### Step 4.1: Lesson 15 — The Timer

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 15 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 15 · AR-2, AR-4, AR-6
**Objective**: Deliver lesson 15 end to end through the mandatory three sessions.

- [ ] 4.1.1 Lesson 15 — The Timer: Session A freezes ST-15.1–ST-15.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson15): The Timer`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-15.1–ST-15.6, including the timer budgets (37-line VBLANK = `TIM64T` 43, 30-line overscan = 35) and the hue cadence ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 15); record the red baseline. No implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part2-tv-and-tia/15-the-timer/15-the-timer.asm` + its three solutions; write `docs/part2-tv-and-tia/15-the-timer.md`; run `npm run roms`; capture `timer-frame.png` from the committed ROM path; embed `<RomPlayer>`; update part index row 15 and prev/next (RD-02 AC 1; AR-6, AR-8, AR-10).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-15.* confirmed; `INTIM`/overrun check; both specialist reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson15): The Timer` (AR-12).

---

## Phase 5: Lesson 16 — Horizontal Zones

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Reasoning**: high — zone-boundary geometry under independent hardware review

### Step 5.1: Lesson 16 — Horizontal Zones

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 16 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 16 · AR-2, AR-4, AR-6, AR-9
**Objective**: Deliver lesson 16 end to end through the mandatory three sessions.

- [ ] 5.1.1 Lesson 16 — Horizontal Zones: Session A freezes ST-16.1–ST-16.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson16): Horizontal Zones`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-16.1–ST-16.6, including the 24/72/48/48 zone table and its cumulative boundary lines ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 16); record the red baseline. No implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part2-tv-and-tia/16-horizontal-zones/16-horizontal-zones.asm` + its three solutions; write `docs/part2-tv-and-tia/16-horizontal-zones.md`; run `npm run roms`; capture `zones.png` from the committed ROM path; embed `<RomPlayer>`; update part index row 16 and prev/next (RD-02 AC 1; AR-6, AR-8, AR-9, AR-10).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-16.* confirmed; zone-boundary scanline check; both specialist reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson16): Horizontal Zones` (AR-12).

---

## Phase 6: Lesson 17 — Cycle Counting

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Reasoning**: high — hand-counted cycle budgets are the highest-verification-risk content in Part 2

### Step 6.1: Lesson 17 — Cycle Counting

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 17 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 17 · AR-2, AR-4, AR-6
**Objective**: Deliver lesson 17 end to end through the mandatory three sessions.

- [ ] 6.1.1 Lesson 17 — Cycle Counting: Session A freezes ST-17.1–ST-17.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson17): Cycle Counting`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-17.1–ST-17.6, including the 76-cycle ledger and the +6-cycle over-budget figures (≈8-line stretch, ≈270-line frame) ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 17); record the red baseline. No implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part2-tv-and-tia/17-cycle-counting/17-cycle-counting.asm` + its three solutions; write `docs/part2-tv-and-tia/17-cycle-counting.md`; run `npm run roms`; capture `cycle-ruler.png` from the committed ROM path; embed `<RomPlayer>`; update part index row 17 and prev/next (RD-02 AC 1; AR-6, AR-8, AR-10).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-17.* confirmed; per-iteration cycle check (two state-log hits, same scanline); both specialist reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson17): Cycle Counting` (AR-12).

---

## Phase 7: Lesson 18 — Mid-Scanline Changes

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Reasoning**: high — sub-line timing positions close Part 2's timing chain under independent hardware review

### Step 7.1: Lesson 18 — Mid-Scanline Changes

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 18 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 18 · AR-2, AR-4, AR-6
**Objective**: Deliver lesson 18 end to end through the mandatory three sessions and close Part 2.

- [ ] 7.1.1 Lesson 18 — Mid-Scanline Changes: Session A freezes ST-18.1–ST-18.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson18): Mid-Scanline Changes`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-18.1–ST-18.6, including the pinned write cycles (≈14 / 36 / 49 / 63, +4-cycle shift) and the two animation states ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 18); record the red baseline. No implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part2-tv-and-tia/18-mid-scanline-changes/18-mid-scanline-changes.asm` + its three solutions; write `docs/part2-tv-and-tia/18-mid-scanline-changes.md`; run `npm run roms`; capture `columns.png` and `columns-shifted.png` from the committed ROM path; embed `<RomPlayer>`; update part index row 18 and prev/next (**next links forward to `/part3-playfield/19-playfield-basics`** — the lesson-11 pattern) (RD-02 AC 1; AR-6, AR-8, AR-10).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-18.* confirmed; per-line write-cycle check; both specialist reviews report no critical/major findings; Part 2 is complete (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson18): Mid-Scanline Changes` (AR-12).

---

## Dependencies

```
Phase 1 (Lesson 12) → Phase 2 (Lesson 13) → Phase 3 (Lesson 14) → Phase 4 (Lesson 15)
    → Phase 5 (Lesson 16) → Phase 6 (Lesson 17) → Phase 7 (Lesson 18)
```

---

## Success Criteria

**Feature is complete when:**

1. ✅ All phases completed (7/7 tasks `[x]`)
2. ✅ `bash scripts/verify.sh` passing with all seven lessons included
3. ✅ No warnings/errors (clean ACME assembly, clean docs build)
4. ✅ No dead code — every solution file is referenced by its lesson; no stray artifacts
5. ✅ Security — N/A: static lesson content and local ROMs only; no user input, secrets, or server-side processing
6. ✅ Documentation updated — lesson documents, rebuilt part index, and the README sync verified
7. ✅ Code reviewed — `atari2600-reviewer` and `curriculum-auditor`, no critical/major findings per lesson
8. ✅ Post-completion project re-analysis (handled by the exec-plan skill)
