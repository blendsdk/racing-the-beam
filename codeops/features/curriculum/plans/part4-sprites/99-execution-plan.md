# Execution Plan: Part 4 — Sprites (Lessons 25–34)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-04 13:00
> **Progress**: 0/10 tasks (0%)
> **CodeOps Artifact Schema**: 1

## Overview

Ten phases, one per lesson, strictly sequential — each lesson is the next one's prerequisite
(AR-1). Every phase is one task run through the mandatory three-session ordering: Session A
freezes that lesson's specification cases, Session B implements the full artifact set, and
Session C verifies against the frozen cases and hardens under independent review (AR-2, AR-5).
`bash scripts/verify.sh` is the gate for every phase (AR-4). Sprite positioning and timing claims
carry the state-log + ledger evidence of AR-6; every positioned sprite's measured X is recorded
before that lesson is done (AR-13).

**🚨 Update this document after EACH completed task!**

---

## Implementation Phases

| Phase | Title | Tasks |
| ----- | ----- | ----- |
| 1 | Lesson 25 — Player Sprite Basics | 1 |
| 2 | Lesson 26 — Horizontal Positioning | 1 |
| 3 | Lesson 27 — Sprite Movement | 1 |
| 4 | Lesson 28 — Two Players | 1 |
| 5 | Lesson 29 — Missiles and Ball | 1 |
| 6 | Lesson 30 — Multi-Color Sprites | 1 |
| 7 | Lesson 31 — Copies and Sizes | 1 |
| 8 | Lesson 32 — Vertical Delay | 1 |
| 9 | Lesson 33 — Paddle & Keyboard Controllers | 1 |
| 10 | Lesson 34 — Sprite Animation | 1 |

**Total: 10 tasks across 10 phases.**

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

## Phase 1: Lesson 25 — Player Sprite Basics

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part4-sprites/25-player-basics/` (4 sources) · `docs/part4-sprites/25-player-basics.md` · `docs/part4-sprites/index.md` (rebuild + row 25) · `docs/public/roms/part4-sprites/25-player-basics/` · `docs/public/images/lesson25/` (1 capture) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — the first sprite is the part's foundation; the vertical-write model and the fixed coarse placement are under independent hardware review

### Step 1.1: Lesson 25 — Player Sprite Basics

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 25 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 25 · AR-2, AR-3, AR-4, AR-6, AR-10, AR-13, AR-14
**Objective**: Deliver lesson 25 end to end through the mandatory three sessions.

- [ ] 1.1.1 Lesson 25 — Player Sprite Basics: Session A freezes ST-25.1–ST-25.6 (red baseline), Session B implements the full artifact set (including the AR-10 index rebuild), Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson25): Player Sprite Basics`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-25.1–ST-25.6, including the
   invader shape, the 8-row body, `SPRITE_TOP=80`, and the fixed coarse placement
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 25); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part4-sprites/25-player-basics/25-player-basics.asm` + its three solutions; write
   `docs/part4-sprites/25-player-basics.md`; run `npm run roms`; capture `first-sprite.png` from
   the committed ROM path; embed `<RomPlayer>`; **rebuild `docs/part4-sprites/index.md` to the
   Part 1 format with `🔒 Coming Soon` rows** (AR-10) and update prev/next (RD-04 AC 1; AR-6,
   AR-8).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-25.* confirmed; the body-line and sprite-X measurements; both specialist reviews report
   no critical/major findings (AR-4, AR-5, AR-6, AR-13).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson25): Player Sprite Basics` (AR-12).

---

## Phase 2: Lesson 26 — Horizontal Positioning

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part4-sprites/26-horizontal-positioning/` (4 sources) · `docs/part4-sprites/26-horizontal-positioning.md` · `docs/part4-sprites/index.md` (row 26) · `docs/public/roms/part4-sprites/26-horizontal-positioning/` · `docs/public/images/lesson26/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — the part's highest-risk claim: the divide-by-15 routine's landing under independent hardware review

### Step 2.1: Lesson 26 — Horizontal Positioning

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 26 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 26 · AR-2, AR-3, AR-4, AR-6, AR-13
**Objective**: Deliver lesson 26 end to end through the mandatory three sessions, with the
divide-by-15 routine's measured landing recorded.

- [ ] 2.1.1 Lesson 26 — Horizontal Positioning: Session A freezes ST-26.1–ST-26.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson26): Horizontal Positioning`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-26.1–ST-26.6, including the
   five targets 16/48/80/112/144, the ±3 tolerance, and the routine ledger
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 26); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part4-sprites/26-horizontal-positioning/26-horizontal-positioning.asm` + its three
   solutions; write `docs/part4-sprites/26-horizontal-positioning.md`; run `npm run roms`;
   capture `position-a.png` and `position-b.png`; embed `<RomPlayer>`; update part index row 26
   and prev/next (RD-04 AC 1; AR-6, AR-8, AR-13).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-26.* confirmed; **measure the routine's landing at each target and record the offset**;
   both specialist reviews report no critical/major findings (AR-4, AR-5, AR-6, AR-13).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson26): Horizontal Positioning` (AR-12).

---

## Phase 3: Lesson 27 — Sprite Movement

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part4-sprites/27-sprite-movement/` (4 sources) · `docs/part4-sprites/27-sprite-movement.md` · `docs/part4-sprites/index.md` (row 27) · `docs/public/roms/part4-sprites/27-sprite-movement/` · `docs/public/images/lesson27/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: medium — a bounded input + movement loop reusing the positioning routine; the capture timing is the main risk

### Step 3.1: Lesson 27 — Sprite Movement

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 27 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 27 · AR-2, AR-3, AR-4, AR-6, AR-15
**Objective**: Deliver lesson 27 end to end through the mandatory three sessions.

- [ ] 3.1.1 Lesson 27 — Sprite Movement: Session A freezes ST-27.1–ST-27.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson27): Sprite Movement`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-27.1–ST-27.6, including the
   auto-patrol, the 16/144 bounds, and the SWCHA bit mapping
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 27); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part4-sprites/27-sprite-movement/27-sprite-movement.asm` + its three solutions; write
   `docs/part4-sprites/27-sprite-movement.md`; run `npm run roms`; capture `patrol-a.png` and
   `patrol-b.png`; embed `<RomPlayer>`; update part index row 27 and prev/next (RD-04 AC 1;
   AR-6, AR-8, AR-15).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-27.* confirmed; the `MoveTick` positions match the captures and the manual joystick
   check; both specialist reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson27): Sprite Movement` (AR-12).

---

## Phase 4: Lesson 28 — Two Players

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part4-sprites/28-two-players/` (4 sources) · `docs/part4-sprites/28-two-players.md` · `docs/part4-sprites/index.md` (row 28) · `docs/public/roms/part4-sprites/28-two-players/` · `docs/public/images/lesson28/` (1 capture) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: medium — two independent players sharing a line budget; positioning correctness under review

### Step 4.1: Lesson 28 — Two Players

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 28 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 28 · AR-2, AR-3, AR-4, AR-6, AR-13
**Objective**: Deliver lesson 28 end to end through the mandatory three sessions.

- [ ] 4.1.1 Lesson 28 — Two Players: Session A freezes ST-28.1–ST-28.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson28): Two Players`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-28.1–ST-28.6, including both
   shapes, the X targets 48/104, and the overlap priority
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 28); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part4-sprites/28-two-players/28-two-players.asm` + its three solutions; write
   `docs/part4-sprites/28-two-players.md`; run `npm run roms`; capture `two-players.png`; embed
   `<RomPlayer>`; update part index row 28 and prev/next (RD-04 AC 1; AR-6, AR-8, AR-13).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-28.* confirmed; both positions measured; both specialist reviews report no
   critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson28): Two Players` (AR-12).

---

## Phase 5: Lesson 29 — Missiles and Ball

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part4-sprites/29-missiles-and-ball/` (4 sources) · `docs/part4-sprites/29-missiles-and-ball.md` · `docs/part4-sprites/index.md` (row 29) · `docs/public/roms/part4-sprites/29-missiles-and-ball/` · `docs/public/images/lesson29/` (1 capture) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — four independently positioned objects with different output delays under independent hardware review

### Step 5.1: Lesson 29 — Missiles and Ball

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 29 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 29 · AR-2, AR-3, AR-4, AR-6, AR-13
**Objective**: Deliver lesson 29 end to end through the mandatory three sessions, with each
object's measured X and width recorded.

- [ ] 5.1.1 Lesson 29 — Missiles and Ball: Session A freezes ST-29.1–ST-29.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson29): Missiles and Ball`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-29.1–ST-29.6, including the
   lineup X values 24/64/96/128 and the widths 1/4/8
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 29); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part4-sprites/29-missiles-and-ball/29-missiles-and-ball.asm` + its three solutions;
   write `docs/part4-sprites/29-missiles-and-ball.md`; run `npm run roms`; capture `lineup.png`;
   embed `<RomPlayer>`; update part index row 29 and prev/next (RD-04 AC 1; AR-6, AR-8, AR-13).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-29.* confirmed; **measure the four positions and the three widths**; both specialist
   reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson29): Missiles and Ball` (AR-12).

---

## Phase 6: Lesson 30 — Multi-Color Sprites

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part4-sprites/30-multicolor-sprites/` (4 sources) · `docs/part4-sprites/30-multicolor-sprites.md` · `docs/part4-sprites/index.md` (row 30) · `docs/public/roms/part4-sprites/30-multicolor-sprites/` · `docs/public/images/lesson30/` (1 capture) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: medium — a per-line color write over a fixed shape; the HBLANK budget is the risk

### Step 6.1: Lesson 30 — Multi-Color Sprites

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 30 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 30 · AR-2, AR-3, AR-4, AR-6, AR-16
**Objective**: Deliver lesson 30 end to end through the mandatory three sessions.

- [ ] 6.1.1 Lesson 30 — Multi-Color Sprites: Session A freezes ST-30.1–ST-30.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson30): Multi-Color Sprites`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-30.1–ST-30.6, including the
   16-row shape and the 4/8/4 color bands
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 30); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part4-sprites/30-multicolor-sprites/30-multicolor-sprites.asm` + its three solutions;
   write `docs/part4-sprites/30-multicolor-sprites.md`; run `npm run roms`; capture
   `multicolor.png`; embed `<RomPlayer>`; update part index row 30 and prev/next (RD-04 AC 1;
   AR-6, AR-8, AR-16).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-30.* confirmed; the per-line color runs and the 24-cycle body; both specialist reviews
   report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson30): Multi-Color Sprites` (AR-12).

---

## Phase 7: Lesson 31 — Copies and Sizes

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part4-sprites/31-copies-and-sizes/` (4 sources) · `docs/part4-sprites/31-copies-and-sizes.md` · `docs/part4-sprites/index.md` (row 31) · `docs/public/roms/part4-sprites/31-copies-and-sizes/` · `docs/public/images/lesson31/` (1 capture) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: medium — a static eight-band NUSIZ showcase; the copy geometry is measured against the capture

### Step 7.1: Lesson 31 — Copies and Sizes

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 31 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 31 · AR-2, AR-3, AR-4, AR-6, AR-17
**Objective**: Deliver lesson 31 end to end through the mandatory three sessions.

- [ ] 7.1.1 Lesson 31 — Copies and Sizes: Session A freezes ST-31.1–ST-31.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson31): Copies and Sizes`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-31.1–ST-31.6, including the
   eight 24-line bands, the mode order 0–7, and the copy spacings
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 31); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part4-sprites/31-copies-and-sizes/31-copies-and-sizes.asm` + its three solutions;
   write `docs/part4-sprites/31-copies-and-sizes.md`; run `npm run roms`; capture
   `nusiz-bands.png`; embed `<RomPlayer>`; update part index row 31 and prev/next (RD-04 AC 1;
   AR-6, AR-8, AR-17).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-31.* confirmed; the eight band boundaries and the copy spacings pixel-checked; both
   specialist reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson31): Copies and Sizes` (AR-12).

---

## Phase 8: Lesson 32 — Vertical Delay

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part4-sprites/32-vertical-delay/` (4 sources) · `docs/part4-sprites/32-vertical-delay.md` · `docs/part4-sprites/index.md` (row 32) · `docs/public/roms/part4-sprites/32-vertical-delay/` · `docs/public/images/lesson32/` (1 capture) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — the one-line VDEL offset is subtle and must be measured, under independent hardware review

### Step 8.1: Lesson 32 — Vertical Delay

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 32 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 32 · AR-2, AR-3, AR-4, AR-6, AR-18
**Objective**: Deliver lesson 32 end to end through the mandatory three sessions, with the
one-line offset measured.

- [ ] 8.1.1 Lesson 32 — Vertical Delay: Session A freezes ST-32.1–ST-32.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson32): Vertical Delay`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-32.1–ST-32.6, including the
   16-row striped shape, `VDELP1=$01`, and the one-line offset
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 32); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part4-sprites/32-vertical-delay/32-vertical-delay.asm` + its three solutions; write
   `docs/part4-sprites/32-vertical-delay.md`; run `npm run roms`; capture `vdel.png`; embed
   `<RomPlayer>`; update part index row 32 and prev/next (RD-04 AC 1; AR-6, AR-8, AR-18).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-32.* confirmed; **measure both top rows and record the one-line difference**; both
   specialist reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson32): Vertical Delay` (AR-12).

---

## Phase 9: Lesson 33 — Paddle & Keyboard Controllers

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part4-sprites/33-paddle-keyboard-controllers/` (4 sources) · `docs/part4-sprites/33-paddle-keyboard-controllers.md` · `docs/part4-sprites/index.md` (row 33) · `docs/public/roms/part4-sprites/33-paddle-keyboard-controllers/` · `docs/public/images/lesson33/` (1 capture) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — the RC-timing read and the bounded timeout are the part's highest-risk input code

### Step 9.1: Lesson 33 — Paddle & Keyboard Controllers

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 33 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 33 · AR-2, AR-3, AR-4, AR-6, AR-19
**Objective**: Deliver lesson 33 end to end through the mandatory three sessions.

- [ ] 9.1.1 Lesson 33 — Paddle & Keyboard Controllers: Session A freezes ST-33.1–ST-33.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson33): Paddle & Keyboard Controllers`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red baseline):** re-affirm ST-33.1–ST-33.6, including
   the monitor layout, the paddle timeout, and the SWCHA mapping
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 33); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part4-sprites/33-paddle-keyboard-controllers/33-paddle-keyboard-controllers.asm` +
   its three solutions; write `docs/part4-sprites/33-paddle-keyboard-controllers.md`; run
   `npm run roms`; capture `monitor.png`; embed `<RomPlayer>`; update part index row 33 and
   prev/next (RD-04 AC 1; AR-6, AR-8, AR-19).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-33.* confirmed; **the timeout path is exercised (no hang) and the VBLANK worst case is
   recorded**; both specialist reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson33): Paddle & Keyboard Controllers` (AR-12).

---

## Phase 10: Lesson 34 — Sprite Animation

> **Phase baseline tree**: _(recorded by the exec-plan skill from a temporary-index snapshot of committed, staged, unstaged, and untracked phase-start state)_
> **Expected modifications**: `lessons/part4-sprites/34-sprite-animation/` (4 sources) · `docs/part4-sprites/34-sprite-animation.md` · `docs/part4-sprites/index.md` (row 34) · `docs/public/roms/part4-sprites/34-sprite-animation/` · `docs/public/images/lesson34/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (Part 4 completion → RD-04 row Done)
> **Reasoning**: high — the frame-pointer setup and the 18–19-cycle body close Part 4 and must be measured under independent hardware review

### Step 10.1: Lesson 34 — Sprite Animation

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 34 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 34 · AR-2, AR-3, AR-4, AR-6, AR-20
**Objective**: Deliver lesson 34 end to end through the mandatory three sessions and close Part 4.

- [ ] 10.1.1 Lesson 34 — Sprite Animation: Session A freezes ST-34.1–ST-34.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson34): Sprite Animation`

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-34.1–ST-34.6, including the
   four 16-row frames, the 8-frame cadence, and the direction flip
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 34); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author
   `lessons/part4-sprites/34-sprite-animation/34-sprite-animation.asm` + its three solutions;
   write `docs/part4-sprites/34-sprite-animation.md`; run `npm run roms`; capture `walk-a.png`
   and `walk-b.png`; embed `<RomPlayer>`; update part index row 34 and prev/next (**next links
   forward to `/part5-sound/35-sound-effects`** — the Lesson 24 pattern) (RD-04 AC 1; AR-6, AR-8,
   AR-20).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green;
   all ST-34.* confirmed; the frame cadence and the body ledger; both specialist reviews report
   no critical/major findings; Part 4 is complete (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson34): Sprite Animation` (AR-12).

---

## Dependencies

```
Phase 1 (25) → Phase 2 (26) → Phase 3 (27) → Phase 4 (28) → Phase 5 (29)
    → Phase 6 (30) → Phase 7 (31) → Phase 8 (32) → Phase 9 (33) → Phase 10 (34)
```

---

## Success Criteria

**Feature is complete when:**

1. All phases completed (10/10 tasks `[x]`)
2. `bash scripts/verify.sh` passing with all ten lessons included
3. No warnings/errors (clean ACME assembly, clean docs build)
4. No dead code — every solution file is referenced by its lesson; no stray artifacts
5. Security — N/A: static lesson content and local ROMs only; no user input, secrets, or
   server-side processing
6. Documentation updated — lesson documents, rebuilt part index, and the README sync verified
7. Code reviewed — `atari2600-reviewer` and `curriculum-auditor`, no critical/major findings per
   lesson
8. Every positioned sprite's measured X recorded; the VDEL one-line offset measured; the paddle
   timeout exercised (AR-6, AR-13, AR-18, AR-19)
9. Post-completion project re-analysis (handled by the exec-plan skill)
