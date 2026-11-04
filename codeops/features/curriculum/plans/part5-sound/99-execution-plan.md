# Execution Plan: Part 5 — Sound (Lessons 35–37)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-04 23:17
> **Progress**: 1/3 tasks (33%)
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

> **Phase baseline tree**: 838ac3b (clean tree at phase start; scope: strict)
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

- [x] 1.1.1 Lesson 35 — Sound Effects: Session A freezes ST-35.1–ST-35.6 (red baseline), Session B
  implements the full artifact set (including the AR-10 index rebuild), Session C verifies to green
  and hardens; commit via the `git-commit` skill in push mode — `feat(lesson35): Sound Effects` ✅ (completed: 2026-11-04 23:17)

**Session A record** (freeze + red baseline, 2026-11-04 23:00): ST-35.1–ST-35.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 35. Design pins: the standard 262-line frame; the monitor — three 8-line playfield bands (BEEP/BOOP/BOOM), a 15-cell VU meter (6 lines per cell) on player 0 at X=24, and an 8-row pitch marker on player 1 at X=24+AUDF×4; the effect colors `$C8`/`$84`/`$42`; the exact recipes BEEP `$0C/$13` volume 15→12→8→0, BOOP `$04` AUDF 6→20 volume 12→8→0, BOOM `$08` with the 16-byte noise table and volume 15→0; the 32/32/48-frame auto-cycle; work-first kernel; one HMOVE after both positions. Evidence pins (AR-6): frame checkpoints; `EffectStep` A = the new ID; `CtlWrite`/`FreqWrite`/`VolWrite` A = the written value; `BodyStart` 37; `MeterStart` 65; `HmoveApply`/`HmoveDone`; the capture bars and marker. Red baseline confirmed: no `lessons/part5-sound` tree, no `docs/public/images/lesson35`, no committed Part 5 ROMs, the document is the `🔒 Coming Soon` stub, the Part 5 index is the minimal stub, sidebar entry exists (`config.ts:100`), `verify.sh` green at `838ac3b`. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-11-04 23:17): Preflight per `vcs-lesson-production` — the audio divider chain, the three recipes, the 15-cell meter, the pitch mapping, the work-first kernel, and the one-HMOVE rule checked against `include/vcs.asm`, the sound reference, and the TIA references; ACME forms; no demo (AR-3: the sound lab is the visible picture). `bash scripts/verify.sh` green (implementation, fixes, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F016` = (259, 3), `VblankStart` `$F024` = (0, 5), `BodyStart` `$F0DC` = (37, 7), `MeterStart` `$F101` = (65, 4), `OverscanStart` `$F148` = (229, 4). Effects: `EffectStep` `$F046` at frames **33/65/113/145** with A = 1/2/0/1 (the first play frame is frame 1, so the step is one frame after the 32nd play frame); `CtlWrite` `$F04F` A = `$0C`/`$04`/`$08`; `FreqWrite` `$F097` A = `$13` during BEEP, 6,6,7,7,…20 during BOOP, and the 16-entry noise table during BOOM; `VolWrite` `$F09B` A = 15 (frames 1–10), 12 (11–15), 8 (16–20), 0 (21–32) for the BEEP, and the matching BOOP/BOOM envelopes. Positioning: `HmoveApply` `$F180` line 3 c55 (the WSYNC stall); `HmoveDone` `$F182` line 4 c3, so the store executes at line 4 c0 in HBLANK; P0 X=24 and P1 X=24+AUDF×4. Captures from the committed ROM: `beep.png` band 0 green, VU 15 green cells x=169–216 y=195–477, marker green x=625–672 (AUDF 19) y=492–515; `boom.png` band 2 red, VU 14 red cells x=169–216 y=214–477, marker red x=889–936 (AUDF 30, frame 5) y=492–515; no cursor. The active band's color write lands at line 53 c21 (store completes c24), just after the playfield's first pixel at c22; the one-line, 24-px left-edge notch is documented as that timing effect, not a tear. Solutions: ex 1 — `AUDF=$09`, marker x=385–432; ex 2 — siren 6/20, marker x=313–360/649–696; ex 3 — forced-left `SelectStore` A=2/1/0, fire witness band 0 green 15 cells, no-input `EffectStep` 33/65/113/145. Site (ST-35.6): the Part 5 index was rebuilt to the Part 1 format (row 35 ✅ Complete; rows 36–37 `🔒 Coming Soon`); the built page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 34, next → 36; sidebar `config.ts:100`; README unchanged. Reviews (AR-5): the atari2600-reviewer round 1 — **2 major, 5 minor** (Lower/Raise; pitch labels; timer 44; HmoveApply wording; ST-35.2; dead constant; duplicate headers); round 2 — **1 major, 2 minor** (the first notch explanation claimed a per-line `COLUPF` latch; alt text; HmoveApply residual); round 3 — **0 major**, all confirmed, with the exact active-band store cycle measured (c24). The curriculum-auditor round 1 — **2 major, 2 minor** ("top band" wording; Lower/Raise; the notch; duplicate headers); round 2 — **1 major, 1 minor** (the latch claim; alt text); round 3 — **0 major**. Final state: **0 critical, 0 major open**. Lesson 35 is complete.

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
