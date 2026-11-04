# Execution Plan: Part 5 — Sound (Lessons 35–37)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-04 22:55
> **Progress**: 0/3 tasks (0%)
> **CodeOps Artifact Schema**: 1

## Overview

Three phases, one per lesson, strictly sequential — Lesson 36 reuses Lesson 35's audio registers,
and Lesson 37 generalizes Lesson 36's timing (AR-1). Every phase is one task run through the
mandatory three-session ordering: Session A freezes that lesson's specification cases, Session B
implements the full artifact set, and Session C verifies against the frozen cases and hardens under
independent review (AR-2, AR-5). `bash scripts/verify.sh` is the gate for every phase (AR-4). Audio
claims carry the state-log + static-ledger evidence of AR-6 and AR-22; every screenshot is
pixel-checked against the monitor geometry (AR-23).

**🚨 Update this document after EACH completed task!**

**Session record slots:** each task gets a `**Session A record**` paragraph after its task line
(freeze + red baseline + design pins) and a `**Session C record**` paragraph after the Session
sub-steps (evidence + review rounds + final state), following the Part 4 plan. The per-lesson
findings are appended to [05-findings.md](05-findings.md); the plan-level preflight findings live in
[00-preflight-report.md](00-preflight-report.md). The plan is not executable until the preflight
report exists and the roadmap row reads `Plan Preflighted`. The push mode is authorized by the
user's directive to execute RD-05 and the Part 1–4 practice (AR-12).

---

## Implementation Phases

| Phase | Title | Tasks |
| ----- | ----- | ----- |
| 1 | Lesson 35 — Sound Effects | 1 |
| 2 | Lesson 36 — Music | 1 |
| 3 | Lesson 37 — Advanced Audio | 1 |

**Total: 3 tasks across 3 phases.**

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

## Phase 1: Lesson 35 — Sound Effects

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part5-sound/35-sound-effects/` (4 sources) ·
> `docs/part5-sound/35-sound-effects.md` · `docs/part5-sound/index.md` (rebuild + row 35) ·
> `docs/public/roms/part5-sound/35-sound-effects/` · `docs/public/images/lesson35/` (2 captures) ·
> `README.md` (verify only) · `99-execution-plan.md` + `05-findings.md` + roadmaps (progress)
> The Part 5 index starts with all three rows `🔒 Coming Soon`; row 35 flips in this phase.
> **Reasoning**: high — the first audio lesson writes the registers directly; the envelope
> arithmetic and the VBLANK budget are under independent hardware review

### Step 1.1: Lesson 35 — Sound Effects

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 35 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 35 · AR-2, AR-3, AR-4, AR-6, AR-10,
AR-13, AR-14, AR-22, AR-23
**Objective**: Deliver Lesson 35 end to end through the mandatory three sessions.

- [ ] 1.1.1 Lesson 35 — Sound Effects: Session A freezes ST-35.1–ST-35.6 (red baseline), Session B
  implements the full artifact set (including the AR-10 index rebuild), Session C verifies to green
  and hardens; commit via the `git-commit` skill in push mode — `feat(lesson35): Sound Effects`

**Session sub-steps:**

1. **Session A — freeze the specification (red phase):** re-affirm ST-35.1–ST-35.6, including the
   three effect recipes, the monitor layout, and the auto-cycle
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 35); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author the main source and
   three solutions; rebuild the Part 5 index; write the document; assemble, run in Stella, and
   capture the two screenshots from the committed ROM; run `npm run roms`; run `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row with recorded evidence; run the two
   specialists on the phase diff; fix findings; re-run `verify.sh`; record the Session C evidence
   and the findings ledger rows.
4. **Commit:** `git-commit` skill in push mode with the `Ref:`/`Task:` trailers; update the
   roadmap row to Done only at Part 5 completion (AR-12).

---

## Phase 2: Lesson 36 — Music

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part5-sound/36-music/` (4 sources) ·
> `docs/part5-sound/36-music.md` · `docs/part5-sound/index.md` (row 36) ·
> `docs/public/roms/part5-sound/36-music/` · `docs/public/images/lesson36/` (2 captures) ·
> `README.md` (verify only) · `99-execution-plan.md` + `05-findings.md` + roadmaps (progress)
> Row 36 flips from `🔒 Coming Soon` to ✅ Complete in this phase.
> **Reasoning**: high — the tuning table and the two-channel timing are the part's most
> error-prone arithmetic, the 5-bit `AUDF` field is a hard limit, and the note ladder must match the log exactly

### Step 2.1: Lesson 36 — Music

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 36 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 36 · AR-2, AR-3, AR-4, AR-6, AR-10,
AR-15, AR-16, AR-17, AR-22, AR-23
**Objective**: Deliver Lesson 36 end to end through the mandatory three sessions.

- [ ] 2.1.1 Lesson 36 — Music: Session A freezes ST-36.1–ST-36.6 (red baseline), Session B
  implements the full artifact set, Session C verifies to green and hardens; commit via the
  `git-commit` skill in push mode — `feat(lesson36): Music`

**Session sub-steps:**

1. **Session A — freeze the specification (red phase):** re-affirm ST-36.1–ST-36.6, including the
   shared div-6 note table, the cents errors, the 12/48-frame timing, and the lead/harmony marker columns
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 36); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight; author the main source and three solutions; write the
   document with the tuning table; assemble, run, and capture the two screenshots; `npm run roms`;
   `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Commit:** `git-commit` in push mode; progress header and roadmap updates (AR-12).

---

## Phase 3: Lesson 37 — Advanced Audio

> **Phase baseline tree**: _(recorded at phase start)_
> **Expected modifications**: `lessons/part5-sound/37-advanced-audio/` (4 sources) ·
> `include/sound.asm` (new library) · `docs/part5-sound/37-advanced-audio.md` ·
> `docs/part5-sound/index.md` (row 37) · `docs/public/roms/part5-sound/37-advanced-audio/` ·
> `docs/public/images/lesson37/` (2 captures) · `README.md` (verify only) ·
> `99-execution-plan.md` + `05-findings.md` + roadmaps (progress/finish)
> Row 37 flips from `🔒 Coming Soon` to ✅ Complete in this phase, and the part completion note is
> written.
> **Reasoning**: high — the engine's pointer arithmetic, priority semantics, and RAM map are the
> part's highest-risk code, and the whole part's completion record depends on this phase

### Step 3.1: Lesson 37 — Advanced Audio

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 37 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 37 · AR-2, AR-3, AR-4, AR-5, AR-6,
AR-7, AR-10, AR-18, AR-19, AR-20, AR-22, AR-23, AR-24, AR-25, AR-26
**Objective**: Deliver Lesson 37 end to end, close Part 5, and update the roadmaps.

- [ ] 3.1.1 Lesson 37 — Advanced Audio: Session A freezes ST-37.1–ST-37.6 (red baseline), Session B
  implements the full artifact set including `include/sound.asm`, Session C verifies to green and
  hardens; commit via the `git-commit` skill in push mode — `feat(lesson37): Advanced Audio`

**Session sub-steps:**

1. **Session A — freeze the specification (red phase):** re-affirm ST-37.1–ST-37.6, including the
   engine API, the 8-byte definitions, the priority log, and the mixer layout
   ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 37); record the red baseline. No
   implementation logic read (AR-2).
2. **Session B — implement:** preflight; author `include/sound.asm`, the main source, and three
   solutions; write the document; assemble, run, and capture the two screenshots; `npm run roms`;
   `verify.sh`.
3. **Session C — verify and harden:** confirm every ST row; run both specialists; fix findings;
   re-run `verify.sh`; record Session C and the findings ledger.
4. **Part 5 completion:** flip index row 37, confirm all rows 35–37 ✅, update the feature roadmap
   (RD-05 Done, 5/11 RDs), the portfolio (5 plans done), and the plan completion note; final
   `verify.sh`; commit and push (AR-24).

---

## Plan-Level Verification

| Check | Command | Pass condition |
| --- | --- | --- |
| ROM drift + docs | `bash scripts/verify.sh` | `=== VERIFY PASSED ===` |
| Part 5 artifacts | `find docs/public/roms/part5-sound -name '*.bin' \| wc -l` | 12 |
| Screenshots | `find docs/public/images/lesson3[5-7] -name '*.png' \| wc -l` | 6 |
| Documents | `grep -l '## Key Takeaways' docs/part5-sound/3*.md \| wc -l` | 3 |
| Roadmap | `grep 'RD-05' codeops/features/curriculum/00-roadmap.md` | `Done` / `✅` |
| Reviews | [05-findings.md](05-findings.md) | 0 critical, 0 major open |
| Frame | state logs | every lesson `BodyStart` 37 and `OverscanStart` 229 (262 lines) |
| HMOVE | state logs | `HmoveDone` on line 3 (the store executes in HBLANK) |

## Completion Criteria

- [ ] All three phases marked `[x]` with Session A/C records.
- [ ] 12 committed 4,096-byte ROMs, 3 documents, 6 screenshots.
- [ ] Part 5 index rows 35–37 all ✅ Complete.
- [ ] `bash scripts/verify.sh` green at the final commit.
- [ ] Both specialists report no critical/major open for every lesson.
- [ ] No dead code, no unused symbols/tables; security is N/A (static content, no input).
- [ ] The post-completion re-analysis (plan/skill protocol) is recorded.
- [ ] RD-05 Done; feature roadmap 5/11 RDs; portfolio 5 plans done.
