# Preflight Report: Part 4 — Sprites (Lessons 25–34)

> **Status**: ✅ PREFLIGHT PASSED WITH NOTES — 3 major resolved, 6 minor resolved, 2 observations accepted
> **Iteration**: 1 (first scan; fixes applied under the objective's execution authorization and `--auto-design`)
> **Artifact**: implementation plan at `codeops/features/curriculum/plans/part4-sprites/` (git tree `3ef2b2635fd83023e1127477fa4e29c52780728d`, commit `17abb79`)
> **Codebase Grounded**: 24 source files examined, 31 references verified
> **Last Updated**: 2026-11-04
>
> ⚠️ **SAME-SESSION REVIEW** — this plan was created in the current session. Mitigations: every
> finding was checked against the real repository; the three majors were sent to an independent
> challenger before resolution; every lesson still passes both specialist reviews during execution.

## Audit Scope Contract

| Term | Content |
| --- | --- |
| **Audit target** | `codeops/features/curriculum/plans/part4-sprites/` (all seven documents) |
| **Context documents** | `RD-04-part4-sprites.md`, the completed Part 3 plan, `docs/part4-sprites/*.md` stubs, `docs/part5-sound/35-sound-effects.md`, `docs/.vitepress/config.ts`, `README.md`, `include/vcs.asm`, `include/macro.asm`, the `vcs-lesson-production` and `atari-2600-expert` references |
| **Modification set** | The audit target only; the fixes below change plan documents and nothing else |

## Codebase Context Summary

**Tech Stack:** 6502 assembly (ACME 0.97), VitePress 1.6.4, Node 20+, Bash tooling; static lesson
content and committed 4,096-byte ROMs.
**Architecture:** per-lesson `.asm` sources plus exercise solutions; lesson documents in
`docs/partN-topic/`; committed ROMs in `docs/public/roms/`; screenshots in
`docs/public/images/lessonNN/`; the Part 4 sidebar block already exists (`config.ts:84–93`); the
Part 4 index is a stub; Part 5's first stub is `35-sound-effects.md`.
**Key Files Examined:** `codeops/features/curriculum/plans/part4-sprites/*` (7), RD-04,
`include/vcs.asm` (sprite/RIOT registers), `include/macro.asm` (`+clean_start`, `+vsync`,
`+set_timer`, `+wait_timer`), `docs/part4-sprites/*` (11 stubs),
`docs/part5-sound/35-sound-effects.md`, `docs/.vitepress/config.ts`, `README.md`,
`scripts/verify.sh`, `atari-2600-expert/references/{tia-hardware,sprite-tricks,kernels,pitfalls}.md`,
`vcs-lesson-production/SKILL.md`, the Part 3 plan set.

## Summary by Dimension

| # | Dimension | Findings | Highest Severity |
|---|-----------|----------|-----------------|
| 1 | Ambiguities | 2 | 🟡 MINOR |
| 2 | Implicit Assumptions | 1 | 🟡 MINOR |
| 3 | Logical Contradictions | 0 | — |
| 4 | Completeness Gaps | 1 | 🟠 MAJOR |
| 5 | Dependency Issues | 0 | — |
| 6 | Feasibility Concerns | 1 | 🟠 MAJOR |
| 7 | Testability | 1 | 🟡 MINOR |
| 8 | Security Blind Spots | 0 | — (N/A) |
| 9 | Edge Cases | 0 (folded into PF-001) | — |
| 10 | Scope Creep Indicators | 0 | — |
| 11 | Ordering & Sequencing | 0 | — |
| 12 | Consistency | 2 | 🟡 MINOR |
| 13 | Codebase Alignment | 1 | 🟠 MAJOR |

## Summary by Severity

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | 0 | — |
| MAJOR | 3 | all resolved |
| MINOR | 6 | all resolved |
| OBSERVATION | 2 | accepted |

---

## Findings

### PF-001: Paddle read can exceed the 37-line VBLANK 🟠 MAJOR

**Dimension:** Feasibility / Edge Cases
**Location:** `03-lesson-specs.md` §Lesson 33; `00-ambiguity-register.md` AR-19; `07-testing-strategy.md` ST-33.3
**Codebase Evidence:** `include/macro.asm` `+set_timer 44` (37 lines) and `+wait_timer`; the
proposed loop `LDA INPT0` (3 cycles, zero page) + `BMI` (2) + `INY` (2) + `CPY` (2) + `BNE` (3) = 12 cycles per iteration.
**The Problem:** The spec and AR-19 allowed "255 iterations". 255 × 12 = 3,060 cycles = 40.3
scanlines; with the 3.5-line discharge pad the paddle read alone exceeds the 37-line VBLANK, so the
frame grows and the picture can roll. The timeout value was also undefined ("a defined value"), and
the `INY`/`BNE` loop would wrap at 256 rather than stop at the intended bound.

**Options:**

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A | 128-iteration bounded read (`CPY #128`); timeout stores 0; needle X = count + 24 (24–151; the last storable count is 127); both players' coarse/fine positions set before one `HMOVE` | Fits VBLANK (~26 lines worst case); full needle range; testable timeout; teaches the HMOVE rule | Saturates a real paddle's upper range; the 0 timeout is indistinguishable from a real minimum (documented) |
| B | Keep 255 iterations and extend VBLANK | Full paddle range | Breaks the 262-line frame; every later lesson inherits a non-standard frame |
| C | Read paddles during overscan | Fits VBLANK | Consumes overscan; the release timing and the monitor update change; harder to teach |

**Recommendation:** Option A — the smallest change that preserves the 262-line frame and gives
the monitor a full-range needle.
**Decision:** Resolved — auto-design (execution-authorized fix). The spec, AR-19, and ST-33.3 now
pin the 128-iteration `CPY #128` loop (0 on timeout), X = count + 24, and the one-`HMOVE`
multi-object rule (AR-21).

### PF-002: Lesson 34's forward link targets a non-existent page 🟠 MAJOR

**Dimension:** Codebase Alignment (Phantom Reference)
**Location:** `03-lesson-specs.md` §Lesson 34; `07-testing-strategy.md` ST-34.6; `99-execution-plan.md` Phase 10
**Codebase Evidence:** the actual stub is `docs/part5-sound/35-sound-effects.md`; the sidebar link
is `/part5-sound/35-sound-effects` (`config.ts:100`); there is no `35-sound-basics` file.
**The Problem:** The lesson's next link would 404, breaking ST-34.6 and the course chain.

**Options:**

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A | Point to `/part5-sound/35-sound-effects` with the title "Sound Effects" | Matches the frozen curriculum and the existing stub | None |
| B | Rename the Part 5 stub to `35-sound-basics` | Matches the plan text | Renames a frozen lesson; forbidden by RD-04 AC 4 |

**Recommendation:** Option A — the curriculum is frozen; the plan text is wrong.
**Decision:** Resolved — auto-design (execution-authorized fix). `03`, `07` (ST-34.6), and `99`
now use `/part5-sound/35-sound-effects`; the doc's `next.text` is "Lesson 35: Sound Effects".

### PF-003: Lesson 33's title/promise disagree with RD-04 🟠 MAJOR

**Dimension:** Completeness Gap
**Location:** `03-lesson-specs.md` §Lesson 33
**Codebase Evidence:** RD-04 line 29 and the sidebar (`config.ts:92`) say "Paddle & Keyboard
Controllers"; the pre-existing stub H1 says "Paddle, Keyboard & Driving Controllers" and its
"What you'll learn" promises "Driving controller decoding". The plan had adopted the stub H1 but
had no driving-controller code or exercise.
**The Problem:** The lesson would either break its published promise or drift from the frozen
RD-04 title. The challenger confirmed the title authority is inconsistent and that the planned
decode exercise could not be visually verified without a driving controller.

**Options:**

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A | Use the RD-04/sidebar title "Paddle & Keyboard Controllers"; explain the driving controller as a name-only quadrature aside; keep the paddle/keyboard/fire exercises | Matches the frozen requirement and the sidebar; no unverifiable exercise; smaller | Drops the stub's extra "Driving" heading, which the shipped document replaces |
| B | Keep the long title and add a full quadrature decoder | Covers the stub wording | Adds a code path the capture cannot verify; contradicts RD-04/sidebar |
| C | Leave the promise unmet | No work | Fails the didactic audit |

**Recommendation:** Option A — the lesson number and slug do not change; the canonical title is
RD-04's, and the shipped document replaces the stub. The driving controller's Gray-code idea is
still explained in the theory as a name-only note.
**Decision:** Resolved — auto-design (execution-authorized fix). The spec, the execution plan's
Phase 9 title/task/commit, and the part-index row use "Paddle & Keyboard Controllers"; the theory
keeps a name-only driving-controller paragraph.

### PF-004: Lesson 25's "requested X" is not a request 🟡 MINOR

**Dimension:** Consistency
**Location:** `03-lesson-specs.md` §Lesson 25
**The Problem:** Lesson 25 uses a fixed delay, not `SetHorizPos`; "requested" implied a routine
that does not exist yet.
**Decision:** Resolved — reworded to "target ≈ 81; the measured X is authoritative (±4)".

### PF-005: ST-26.3 accepts two different positions 🟡 MINOR

**Dimension:** Testability
**Location:** `07-testing-strategy.md` ST-26.3
**The Problem:** A two-value acceptance hid a wrong tour index.
**Decision:** Resolved — ST-26.3 now requires the measured X to be within ±3 of **one of the five
targets** and the two captures to differ by at least 24 px.

### PF-006: AR-19's timeout value is undefined 🟡 MINOR

**Dimension:** Ambiguity
**Location:** `00-ambiguity-register.md` AR-19
**The Problem:** "A defined value" is not a value; the ST could not check it.
**Decision:** Resolved — AR-19 states the 128-iteration timeout stores 0, and the needle's range is
24–151.

### PF-007: Lesson 30/34 shapes are not pinned 🟡 MINOR

**Dimension:** Implicit Assumption
**Location:** `03-lesson-specs.md` §Lesson 30, §Lesson 34
**The Problem:** "A 16-row humanoid" and "four walk frames" left the exact silhouettes open.
**Decision:** Resolved — the spec constrains the rows (4/8/4 color bands for 30; four frames
differing only in the leg rows for 34) and requires the exact bytes to be fixed in Session B and
embedded verbatim in the doc. The STs check bands and leg differences, not a specific silhouette.

### PF-008: Phase 9's commit title did not match the lesson title 🟡 MINOR

**Dimension:** Consistency
**Location:** `99-execution-plan.md` Phase 9 task line
**The Problem:** The task line's commit trailer dropped "Driving" (and now conflicts with the
canonical RD-04 title).
**Decision:** Resolved — the phase title, task line, and commit trailer all read
`feat(lesson33): Paddle & Keyboard Controllers`.

### PF-009: The SWCHA column mapping was not stated 🟡 MINOR

**Dimension:** Ambiguity
**Location:** `03-lesson-specs.md` §Lesson 33
**The Problem:** `PF1` maps to chunks 4–11, not 0–11; a reader could expect the columns at the
left edge.
**Decision:** Resolved — the spec states that the eight columns occupy chunks 4–11 (capture
x = 121–313 with reflect mode).

### PF-010: Same-session review bias 🔵 OBSERVATION

**Dimension:** Process
**Decision:** Accepted — the plan was authored and audited in one session. Mitigation: every
finding is codebase-grounded, the majors were challenged independently, and the per-lesson
specialist reviews remain the execution gate.

### PF-011: Capture timing is not frame-exact 🔵 OBSERVATION

**Dimension:** Testability
**Location:** ST-26.2/26.3, ST-27.2, ST-34.2
**The Problem:** `capture-screenshot.sh` waits in wall-clock seconds, so the captured frame may
differ by a few frames from the intended index.
**Decision:** Accepted — the STs assert the measured state (one of the pinned targets) rather than
a frame-exact index; Session C records the measured frame/position from the state log.

---

## Independent Challenger Reconciliation

The three majors were sent to an independent challenger before resolution. It confirmed all three
severities and added four corrections that are now in the plan:

1. The 255-iteration overrun is 40.3 lines, not 51 (arithmetic corrected here).
2. The `INY`/`BNE` loop would wrap at 256; the bound must be `CPY #128`.
3. `STA HMOVE` re-applies every nonzero `HMxx`; calling the classic routine once per object would
   move earlier objects again. The plan now uses **one `HMOVE` per frame after all coarse and fine
   values are set** (AR-21), so no `HMCLR` timing question arises.
4. Lesson 33's title authority is RD-04/sidebar, not the stub H1; the driving-controller promise
   came from the stub and is now a name-only theory note.

The challenger's remaining concerns are recorded as the documented "0 = no paddle or minimum"
rule (AR-19) and the wall-clock capture caveat (PF-011).

## Adversarial Checks

| Check | Result |
| --- | --- |
| Does every lesson have a directly visible main ROM? | Yes — the ten specs each name the visible concept; no demo ROM is needed (AR-3). |
| Does every positioned sprite have a measured-X gate? | Yes — ST-25.2/26.2/26.3/27.2/28.2/29.2/30.2/32.2/33.2/34.2 plus Session C. |
| Does the plan invent a frame length or bypass the Part 3 skeleton? | No — all ten reuse 3/37/192/30 = 262. |
| Does any lesson use a mechanism from a later part? | No — VDEL/48-pixel/flicker are name-only; the driving controller is a name-only aside. |
| Does the plan add machinery? | No — no new scripts, framework, or dependency. |
| Are the specialist roles sufficient? | Yes — the same three roles cover Part 4; no new specialist is justified. |

## Verdict

**✅ PREFLIGHT PASSED WITH NOTES** — all 3 MAJOR and 6 MINOR findings are resolved in the plan
documents; 2 OBSERVATIONS are accepted. The plan is executable under the Part 1–3 pipeline.
