# Execution Plan: Part 3 — Playfield (Lessons 19–24)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-03 22:54
> **Progress**: 1/6 tasks (17%)
> **CodeOps Artifact Schema**: 1

## Overview

Six phases, one per lesson, strictly sequential — each lesson is the next one's prerequisite (AR-1).
Every phase is one task run through the mandatory three-session ordering: Session A freezes that
lesson's specification cases, Session B implements the full artifact set, and Session C verifies
against the frozen cases and hardens under independent review (AR-2, AR-5).
`bash scripts/verify.sh` is the gate for every phase (AR-4). Playfield timing and geometry claims
carry the state-log + ledger evidence of AR-6; Lesson 21's mid-line write windows are measured
before that lesson is done (AR-13).

**🚨 Update this document after EACH completed task!**

---

## Implementation Phases

| Phase | Title | Tasks |
| ----- | ----- | ----- |
| 1 | Lesson 19 — Playfield Basics | 1 |
| 2 | Lesson 20 — Playfield Colors and Priority | 1 |
| 3 | Lesson 21 — Asymmetric Playfield | 1 |
| 4 | Lesson 22 — Playfield Animation | 1 |
| 5 | Lesson 23 — Data-Driven Playfield | 1 |
| 6 | Lesson 24 — The Multicolor Playfield | 1 |

**Total: 6 tasks across 6 phases.**

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

## Phase 1: Lesson 19 — Playfield Basics

> **Phase baseline tree**: d4c9c71c224d583e08fc4b9cbd9822944a82368e (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part3-playfield/19-playfield-basics/` (4 sources) · `docs/part3-playfield/19-playfield-basics.md` · `docs/part3-playfield/index.md` (rebuild + row 19) · `docs/public/roms/part3-playfield/19-playfield-basics/` · `docs/public/images/lesson19/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — the playfield bit order and the reflect/repeat geometry are the part's foundation, under independent hardware review

### Step 1.1: Lesson 19 — Playfield Basics

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 19 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 19 · AR-2, AR-4, AR-6, AR-10
**Objective**: Deliver lesson 19 end to end through the mandatory three sessions.

- [x] 1.1.1 Lesson 19 — Playfield Basics: Session A freezes ST-19.1–ST-19.6 (red baseline), Session B implements the full artifact set (including the AR-10 index rebuild), Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson19): Playfield Basics` ✅ (completed: 2026-11-03 22:54)

**Session A record** (freeze + red baseline, 2026-11-03 22:37): ST-19.1–ST-19.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 19. Design pins: the standard 262-line frame (VSYNC 3; VBLANK 37 on `TIM64T` = 44; visible 192; overscan 30 on 36). `PF0=$F0`, `PF1=$CC`, `PF2=$F0`, `COLUPF=$C8`, `COLUBK=$02`; `CTRLPF` = `$01` (reflect) initially and flips bit 0 every **120 frames** (~2 s) — frames 1–119 reflect, 120–239 repeat. The pattern is constant down the screen, so the PF/CTRLPF/color registers are set in VBLANK and the visible kernel is a 192-iteration `STA WSYNC` hold. Geometry: 20 bits per half, 4 clocks per chunk, capture x = 25 + chunk × 24, picture rows 107–711. Reflect transitions at **169, 217, 265, 409, 601, 745, 793, 841** (an 8-chunk green central block, chunks 16–23, between dark bands); repeat transitions at **169, 217, 265, 409, 649, 697, 745, 889** (the central block widens to chunks 16–25). Captures `reflect.png` (~1 s) and `repeat.png` (~3 s), pixel-classified. Evidence pins (AR-6): frame checkpoints (`StartFrame` 259, `VblankStart`, `VisibleStart` 37, `OverscanStart` 229) and `CtrlWrite` hits once per frame, A = `$01` for frames 1–119 and `$00` for 120–239 (first change at frame 120); the hold kernel's first line is checked for a first-line artifact. Solutions: ex 1 invert (`$00/$33/$0F` — on/off swap: green centre dark, dark bands green); ex 2 one chunk bar (`PF1=$10` — reflect shows chunks 7 and 32, repeat would show 7 and 27); ex 3 an eight-entry pattern table cycling every 60 frames. Red baseline confirmed: no lesson sources, ROMs, or images; the document is still the `🔒 Coming Soon` stub; the Part 3 index is the minimal stub; sidebar entry exists (`config.ts:72`); `verify.sh` green with the lesson absent. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-11-03 22:54): Preflight per `vcs-lesson-production` — the bit-order map checked against `include/vcs.asm` and `tia-hardware.md` (PF0 bits 4–7 with bit 4 leftmost; PF1 bit 7 leftmost; PF2 bit 0 leftmost), the 20-bit/40-chunk geometry against the 160-clock visible line, the hold kernel and frame against Lessons 12–18, ACME forms, no demo (AR-3: the symmetry states are the visible picture), style follows Lessons 12–18. Session B caught a real specification error before review: the initial PF2 note treated `$F0` as `11110000` on screen, but bit 0 is leftmost, so `$F0` displays as `00001111`; the spec, ST rows, Session A record, source comments, and doc were corrected to the measured transitions before the review round. `bash scripts/verify.sh` green (implementation, post-fix, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F012` = (259, 3) every frame; `VblankStart` `$F020` = (0, 5); `VisibleStart` `$F068` = (37, 7); `OverscanStart` `$F06D` = (229, 4). Mode: `CtrlWrite` `$F047` hits once per **frame** — A = `$01` for frames 1–119, `$00` for 120–239, `$01` for 240–359, `$00` for 360–479 (flips at 120/240/360/480/600; 696 frames logged). Captures from the committed ROM: `reflect.png` transitions x = 169/217/265/409/601/745/793/841 (green `$C8` = rgb(81,179,80), dark `$02` = rgb(63,63,62); 8-chunk green centre, chunks 16–23, between dark bands); `repeat.png` transitions 169/217/265/409/649/697/745/889 (centre widens to chunks 16–25; the right-hand dark band moves from 24–29 to 30–35; left half unchanged); picture rows 107–711 = all 192 lines; the two states differ in 116,160 picture pixels. Solutions: ex 1 — the same eight transitions with the colours inverted (green centre dark, dark bands green); ex 2 — bars at x = 193–216 and 793–816 (chunks 7 and 32, 24 px each); ex 3 — the castle at ~1.2 s and a denser table entry at ~2.4 s, transitions 121/145/…/889. Site (ST-19.6): the rebuilt Part 3 index (Part 1 format, row 19 ✅ Complete, rows 20–24 still Coming Soon), the built page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 18, next → 20; README unchanged ("3 | Playfield | 19–24"). Reviews (AR-5): both specialists on the phase diff (static; the parent ran all builds/logs/captures) — round 1: **0 critical, 3 major**, 6 minor + 3 info; the majors were documentation precision (the `CtrlWrite` frequency — one hit per frame, not per flip; the stale source header still describing a "dark gap"; an inverted PF2 comment in exercise 1); all fixed, plus the title/index alignment, the stale exercise-1 spec wording, and the exercise-3 label accuracy. Bounded re-review (round 2) on the fix set: **0 critical, 0 major**; the remaining minors (chunk size 24 px not 6, the repeat band moving only on the right, three exercise-3 labels, the release cycle-4 wording, the plan progress header) were fixed and verify stayed green. No third review required under the quality policy. Lesson 19 is complete.

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-19.1–ST-19.6, including the
   `$F0/$CC/$F0` pattern, the reflect/repeat transitions, and the 120-frame flip
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 19); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part3-playfield/19-playfield-basics/19-playfield-basics.asm` + its three solutions;
   write `docs/part3-playfield/19-playfield-basics.md`; run `npm run roms`; capture `reflect.png`
   and `repeat.png` from the committed ROM path; embed `<RomPlayer>`; **rebuild
   `docs/part3-playfield/index.md` to the Part 1 format with `🔒 Coming Soon` rows** (AR-10) and
   update prev/next (RD-03 AC 1; AR-6, AR-8).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-19.* confirmed; the hold-kernel first-line check; both specialist reviews report no
   critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson19): Playfield Basics` (AR-12).

---

## Phase 2: Lesson 20 — Playfield Colors and Priority

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part3-playfield/20-playfield-colors/` (4 sources) · `docs/part3-playfield/20-playfield-colors.md` · `docs/part3-playfield/index.md` (row 20) · `docs/public/roms/part3-playfield/20-playfield-colors/` · `docs/public/images/lesson20/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — score-mode color routing and the priority boundary under independent hardware review

### Step 2.1: Lesson 20 — Playfield Colors and Priority

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 20 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 20 · AR-2, AR-4, AR-6, AR-14
**Objective**: Deliver lesson 20 end to end through the mandatory three sessions.

- [ ] 2.1.1 Lesson 20 — Playfield Colors and Priority: Session A freezes ST-20.1–ST-20.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson20): Playfield Colors and Priority`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-20.1–ST-20.6, including the
   green/score split and the 4-chunk gap ([07-testing-strategy.md](07-testing-strategy.md)
   §Lesson 20); record the red baseline. No implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part3-playfield/20-playfield-colors/20-playfield-colors.asm` + its three solutions;
   write `docs/part3-playfield/20-playfield-colors.md`; run `npm run roms`; capture
   `single-color.png` and `score-mode.png` from the committed ROM path; embed `<RomPlayer>`;
   update part index row 20 and prev/next (RD-03 AC 1; AR-6, AR-8, AR-14).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-20.* confirmed; the score-mode left/right color check; both specialist reviews report no
   critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson20): Playfield Colors and Priority` (AR-12).

---

## Phase 3: Lesson 21 — Asymmetric Playfield

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part3-playfield/21-asymmetric-playfield/` (4 sources) · `docs/part3-playfield/21-asymmetric-playfield.md` · `docs/part3-playfield/index.md` (row 21) · `docs/public/roms/part3-playfield/21-asymmetric-playfield/` · `docs/public/images/lesson21/` (1 capture) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — the part's highest-risk claim: mid-line PF writes must change only the right half, measured under independent hardware review

### Step 3.1: Lesson 21 — Asymmetric Playfield

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 21 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 21 · AR-2, AR-4, AR-6, AR-13
**Objective**: Deliver lesson 21 end to end through the mandatory three sessions, with the
mid-line write windows measured before the lesson counts as done.

- [ ] 3.1.1 Lesson 21 — Asymmetric Playfield: Session A freezes ST-21.1–ST-21.6 (red baseline) and the six pinned write cycles, Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson21): Asymmetric Playfield`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-21.1–ST-21.6, including the
   six write cycles (hit 10/15/20/35/46/57) and the predicted transitions
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 21); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part3-playfield/21-asymmetric-playfield/21-asymmetric-playfield.asm` + its three
   solutions; write `docs/part3-playfield/21-asymmetric-playfield.md`; run `npm run roms`; capture
   `asymmetric.png` from the committed ROM path; embed `<RomPlayer>`; update part index row 21 and
   prev/next (RD-03 AC 1; AR-6, AR-8, AR-13).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-21.* confirmed; **measure the six write checkpoints and prove the left half is
   unchanged**; both specialist reviews report no critical/major findings (AR-4, AR-5, AR-6,
   AR-13).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson21): Asymmetric Playfield` (AR-12).

---

## Phase 4: Lesson 22 — Playfield Animation

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part3-playfield/22-playfield-animation/` (4 sources) · `docs/part3-playfield/22-playfield-animation.md` · `docs/part3-playfield/index.md` (row 22) · `docs/public/roms/part3-playfield/22-playfield-animation/` · `docs/public/images/lesson22/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: medium — a frame-level state machine reusing the hold kernel; the capture timing is the main risk

### Step 4.1: Lesson 22 — Playfield Animation

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 22 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 22 · AR-2, AR-4, AR-6, AR-17
**Objective**: Deliver lesson 22 end to end through the mandatory three sessions.

- [ ] 4.1.1 Lesson 22 — Playfield Animation: Session A freezes ST-22.1–ST-22.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson22): Playfield Animation`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-22.1–ST-22.6, including the
   nine gate states, the 30-frame cadence, and the gap formula
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 22); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part3-playfield/22-playfield-animation/22-playfield-animation.asm` + its three
   solutions; write `docs/part3-playfield/22-playfield-animation.md`; run `npm run roms`; capture
   `gate-opening.png` and `gate-open.png` from the committed ROM path (timed waits/bursts); embed
   `<RomPlayer>`; update part index row 22 and prev/next (RD-03 AC 1; AR-6, AR-8, AR-17).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-22.* confirmed; the gate-width pixel check and the 30-frame cadence; both specialist
   reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson22): Playfield Animation` (AR-12).

---

## Phase 5: Lesson 23 — Data-Driven Playfield

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part3-playfield/23-data-driven-playfield/` (4 sources) · `docs/part3-playfield/23-data-driven-playfield.md` · `docs/part3-playfield/index.md` (row 23) · `docs/public/roms/part3-playfield/23-data-driven-playfield/` · `docs/public/images/lesson23/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — the one-line table kernel and the 4K data budget are correctness-sensitive under independent review

### Step 5.1: Lesson 23 — Data-Driven Playfield

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 23 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 23 · AR-2, AR-4, AR-6, AR-15
**Objective**: Deliver lesson 23 end to end through the mandatory three sessions.

- [ ] 5.1.1 Lesson 23 — Data-Driven Playfield: Session A freezes ST-23.1–ST-23.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson23): Data-Driven Playfield`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-23.1–ST-23.6, including the
   row layout, the two level descriptions, and the 240-frame switch
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 23); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part3-playfield/23-data-driven-playfield/23-data-driven-playfield.asm` + its three
   solutions; write `docs/part3-playfield/23-data-driven-playfield.md`; run `npm run roms`; capture
   `level1.png` and `level2.png` from the committed ROM path; embed `<RomPlayer>`; update part
   index row 23 and prev/next (RD-03 AC 1; AR-6, AR-8, AR-15).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-23.* confirmed; the per-line ledger and the 4,096-byte size; both specialist reviews
   report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson23): Data-Driven Playfield` (AR-12).

---

## Phase 6: Lesson 24 — The Multicolor Playfield

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part3-playfield/24-multicolor-playfield/` (4 sources) · `docs/part3-playfield/24-multicolor-playfield.md` · `docs/part3-playfield/index.md` (row 24) · `docs/public/roms/part3-playfield/24-multicolor-playfield/` · `docs/public/images/lesson24/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (Part 3 completion → RD-03 row Done)
> **Reasoning**: high — per-line `COLUPF` timing closes Part 3 and must be measured under independent hardware review

### Step 6.1: Lesson 24 — The Multicolor Playfield

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 24 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 24 · AR-2, AR-4, AR-6, AR-16
**Objective**: Deliver lesson 24 end to end through the mandatory three sessions and close Part 3.

- [ ] 6.1.1 Lesson 24 — The Multicolor Playfield: Session A freezes ST-24.1–ST-24.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson24): The Multicolor Playfield`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-24.1–ST-24.6, including the
   two color tables, the 12-line bands, and the 120-frame state flip
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 24); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part3-playfield/24-multicolor-playfield/24-multicolor-playfield.asm` + its three
   solutions; write `docs/part3-playfield/24-multicolor-playfield.md`; run `npm run roms`; capture
   `rainbow.png` and `regions.png` from the committed ROM path; embed `<RomPlayer>`; update part
   index row 24 and prev/next (**next links forward to `/part4-sprites/25-player-basics`** — the
   Lesson 11/18 pattern) (RD-03 AC 1; AR-6, AR-8, AR-16).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-24.* confirmed; the `ColorWrite` per-line cycle and the 12-line hue bands; both
   specialist reviews report no critical/major findings; Part 3 is complete (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson24): The Multicolor Playfield` (AR-12).

---

## Dependencies

```
Phase 1 (Lesson 19) → Phase 2 (Lesson 20) → Phase 3 (Lesson 21)
    → Phase 4 (Lesson 22) → Phase 5 (Lesson 23) → Phase 6 (Lesson 24)
```

---

## Success Criteria

**Feature is complete when:**

1. All phases completed (6/6 tasks `[x]`)
2. `bash scripts/verify.sh` passing with all six lessons included
3. No warnings/errors (clean ACME assembly, clean docs build)
4. No dead code — every solution file is referenced by its lesson; no stray artifacts
5. Security — N/A: static lesson content and local ROMs only; no user input, secrets, or
   server-side processing
6. Documentation updated — lesson documents, rebuilt part index, and the README sync verified
7. Code reviewed — `atari2600-reviewer` and `curriculum-auditor`, no critical/major findings per
   lesson
8. Lesson 21's six mid-line write cycles measured and recorded (AR-13)
9. Post-completion project re-analysis (handled by the exec-plan skill)
