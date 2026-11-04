# Preflight Report: Part 5 — Sound (Lessons 35–37)

> **Status**: ✅ PREFLIGHT PASSED WITH NOTES — 1 critical + 9 major resolved, 9 minor resolved,
> 4 observations accepted
> **Iteration**: 1 (first scan; fixes applied under the user's execution authorization for RD-05)
> **Artifact**: implementation plan at `codeops/features/curriculum/plans/part5-sound/`,
> committed at `b8c11b2`; post-fix working-tree hash
> a7ef2f417e864a5ad713ebe97ab9237290d5da5c (all plan documents except this report)
> **Codebase Grounded**: 34 source/reference files examined, 46 references verified, two scratch
> prototypes assembled and run in Stella 7.0
> **Last Updated**: 2026-11-04
>
> ⚠️ **SAME-SESSION REVIEW** — the plan was created in this session. Mitigations: every finding was
> checked against the real repository and, for the audio design, against two independent
> subagent reviews; the critical bass field error was caught by both independent reviewers and
> fixed before this report; the three scratch prototypes exercised the frame, positioning, VU, and
> note-ladder designs in Stella. The per-lesson reviews remain the independent execution gate.

## Audit Scope Contract

| Term | Content |
| --- | --- |
| **Audit target** | `codeops/features/curriculum/plans/part5-sound/` (all seven plan documents plus the findings ledger) |
| **Context documents** | `RD-05-part5-sound.md`, `README.md`, `docs/.vitepress/config.ts`, `docs/part5-sound/*` stubs, `docs/part6-game-dev/38-collision-detection.md`, `include/vcs.asm`, `include/macro.asm`, `scripts/verify.sh`, `scripts/build-roms.sh`, `scripts/capture-screenshot.sh`, the Part 4 plan, `atari-2600-expert/references/{sound,tia-hardware}.md`, `vcs-lesson-production/{SKILL.md,references/lesson-template.md}` |
| **Modification set** | The audit target only; the fixes below change plan documents and add this report. No lesson source, ROM, or site file is changed by the preflight. |

## Codebase Context Summary

**Tech stack:** 6502 assembly (ACME 0.97), VitePress 1.6.4, Node 20+, Bash tooling; static lesson
content and committed 4,096-byte ROMs.

**Architecture:** per-lesson `.asm` sources plus three exercise solutions; lesson documents under
`docs/partN-topic/`; committed ROMs under `docs/public/roms/`; screenshots under
`docs/public/images/lessonNN/`; the Part 5 sidebar entries already exist (`config.ts:100–102`); the
Part 5 index is a 5-line stub; Lesson 34 already links forward to Lesson 35.

**Ground truth examined:** `include/vcs.asm` audio registers (`AUDC0/1 $15/$16`, `AUDF0/1 $17/$18`,
`AUDV0/1 $19/$1A`, `AUDF` 5-bit 0–31); `include/macro.asm` (`+clean_start`, `+vsync`,
`+set_timer`, `+wait_timer`); the Part 4 lesson sources for the frame/positioning patterns; the
`atari-2600-expert` sound reference (divider chain, `AUDC` table, `AUDF+1` divisor, `AUDV=0` mute)
and the 2k6specs audio section (NTSC audio clock 31,399.5 Hz = 3.579545 MHz / 114).

**Prototype evidence (scratch, not committed):**

| Prototype | What it proved | Key measurement |
| --- | --- | --- |
| `build/l35-proto.asm` | Lesson 35 monitor and effect state machine | 262 lines; VU bar 15 cells at x=169–216, y≈195–478; pitch marker at the expected X; `CtlWrite` A=`$0C`, `FreqWrite` A=`$13`, `VolWrite` A=`$0F` |
| `build/l36-proto.asm` | Lesson 36 ladder and two-voice timing | Markers at x=313/697; rungs at the expected rows; `LeadFreq` at frames 0/12/24/36; `HarmonyFreq` at 0/48/96/144 |
| `build/l36-proto.asm` (timing) | Work-first vs WSYNC-first | WSYNC-first: `OverscanStart` 230 (263-line frame); work-first: 229 (262); `HmoveDone` line 3 cycle 3 |

## Summary by Dimension

| # | Dimension | Findings | Highest Severity |
|---|-----------|----------|-----------------|
| 1 | Ambiguities | 2 | 🟡 MINOR |
| 2 | Implicit Assumptions | 2 | 🟠 MAJOR |
| 3 | Logical Contradictions | 3 | 🔴 CRITICAL |
| 4 | Completeness Gaps | 4 | 🟠 MAJOR |
| 5 | Dependency Issues | 1 | 🟡 MINOR |
| 6 | Feasibility Concerns | 2 | 🟠 MAJOR |
| 7 | Testability | 3 | 🟡 MINOR |
| 8 | Security Blind Spots | 0 | — (N/A) |
| 9 | Edge Cases | 2 | 🟡 MINOR |
| 10 | Scope Creep Indicators | 0 | — |
| 11 | Ordering & Sequencing | 1 | 🟡 MINOR |
| 12 | Consistency | 4 | 🟠 MAJOR |
| 13 | Codebase Alignment | 3 | 🟠 MAJOR |

## Summary by Severity

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | 1 | resolved |
| MAJOR | 9 | resolved |
| MINOR | 9 | resolved |
| OBSERVATION | 4 | accepted |

## Findings

### PF-001 — 🔴 CRITICAL — Lesson 36 wrote bass `AUDF` values outside the 5-bit field

**Location:** `03-lesson-specs.md` §Lesson 36 (pre-fix bass table `39,35,31,29,26,23,20,19`);
`07-testing-strategy.md` ST-36.3/ST-36.5; `00-ambiguity-register.md` AR-16/AR-17.
**Problem:** `AUDF` is a 5-bit field (0–31, `include/vcs.asm:84`). Writing 39/35 truncates to 7/3,
so the chip plays 654/1,308 Hz, not the published 130.8/145.4 Hz. The cents table, the ST oracle,
and exercise 2 were all invalid.
**Options:** (a) keep the low bass on div 31 and publish the −56/+58-cent errors; (b) move the
lower voice up to a div-6 harmony (C4/G4) and publish the trade-off; (c) transpose the whole tune.
**Decision:** (b) — both voices use the one measured div-6 table; the lower voice is a **harmony**,
not a bass. The doc states that a C3 bass would need `AUDF` 39 (out of range) or div 31 at
`AUDF` 7 (126.61 Hz, −56.5 ¢), and explains why the lesson chooses the in-range harmony.
**Resolution:** 03 §Lesson 36, AR-16/17, ST-36.3/36.5, and exercise 2 rewritten; `HarmonyFreqWrite`
A=19,12,19,12; no value exceeds 31. **Resolved.**

### PF-002 — 🟠 MAJOR — A non-looping sound could leave a drone

**Location:** `03-lesson-specs.md` §Lesson 37 engine; `00-ambiguity-register.md` AR-18.
**Problem:** The engine description said "advance the steps" but did not require `AUDV=0` and
clearing the active flag when a non-looping sound exhausts its steps. A literal implementation
leaves the last volume on the channel and a stuck bar.
**Options:** (a) require `SoundUpdate` to write `AUDV=0` and clear active; (b) require every
non-looping volume table to end in 0; (c) both.
**Decision:** (a) with (b) as a second guard: the engine mutes and frees the channel at
exhaustion; the lesson's tables also end in 0. **Resolution:** AR-18 and 03 §Lesson 37 now state
the behavior; ST-37.3 checks `VolWrite`/the bar. **Resolved.**

### PF-003 — 🟠 MAJOR — The LASER bar height was not in its volume table

**Location:** `03-lesson-specs.md` §Lesson 37 (LASER table, expected screen); ST-37.2.
**Problem:** The expected LASER bar was 12 cells, but the table was `15,13,11,9,7,5`; no step
writes 12. The VU bar is volume × 6 lines, so 12 cells is unobservable.
**Options:** (a) change the table to include 11/12; (b) change the expected to 13; (c) hold the
first volume for two steps.
**Decision:** (a)+(c): LASER `11,11,9,7,5,0`; the first two steps show 11 cells. **Resolution:**
03 §Lesson 37 and ST-37.2 now expect 11 cells. **Resolved.**

### PF-004 — 🟠 MAJOR — "9 chunks wide" was ambiguous under the mirrored playfield

**Location:** `03-lesson-specs.md` §Lesson 37 priority bar; ST-37.2.
**Problem:** `CTRLPF=$01` mirrors the playfield, so a 20-bit pattern with N lit chunks shows N
chunks in each half (2N visible). "9 chunks wide" could mean 9 total or 9 per half.
**Options:** (a) draw the bar with a player/ball; (b) specify N chunks per half; (c) use repeat
mode.
**Decision:** (b) — the bar lights N chunks in the left half and mirrors them; the ST says
"9 chunks per half" (18 visible). **Resolution:** 03 §Lesson 37, AR-19, ST-37.2. **Resolved.**

### PF-005 — 🟠 MAJOR — The mix exceeded the plan's own volume ceiling

**Location:** `03-lesson-specs.md` §Shared Conventions and §Lesson 37; ST-37.2/37.5.
**Problem:** The plan promised "no more than two channels at 8 or one at 15", but Lesson 37 had
EXPLOSION 15 + MUSIC 6 = 21. The TIA channels sum and can clip.
**Options:** (a) lower the music/SFX volumes; (b) document the clipping as intentional; (c) duck
the music whenever an effect plays.
**Decision:** (a) with (c) as an exercise: MUSIC 4, loudest SFX 11, combined ≤ 15; the stretch
exercise ducks the music to 2 during the explosion. **Resolution:** the sound table, expected
screens, AR-22, and ST-37.2/37.5 use the new levels. **Resolved.**

### PF-006 — 🟠 MAJOR — The priority schedule did not guarantee the documented rejection

**Location:** `03-lesson-specs.md` §Lesson 37; `00-ambiguity-register.md` AR-20; ST-37.3.
**Problem:** BLIP every 24 and LASER every 120 coincide; no BLIP falls strictly inside a LASER
window. The first-trigger phase was unstated: firing EXPLOSION/POWERUP at frame 0 would contradict
"frame 24 BLIP accepted".
**Options:** (a) offset the BLIP; (b) pin the within-frame order and the first-trigger phase;
(c) change the schedule.
**Decision:** (b)+(a): the counters start at their periods (first requests 24/120/240/360); the
VBLANK order is LASER → EXPLOSION → POWERUP → BLIP, so the BLIP at 120/240 is rejected; the
guaranteed standalone rejection is the BLIP at 264 inside the explosion's 240–275 window. The
music restarts at 384.
**Resolution:** 03 §Lesson 37, AR-20, ST-37.3. **Resolved.**

### PF-007 — 🟠 MAJOR — The kernel order was not pinned; a WSYNC-first loop made a 263-line frame

**Location:** `03-lesson-specs.md` §Shared Conventions; all three lesson kernels.
**Problem:** The plan said "192-line body" but did not say whether the line's work precedes or
follows `STA WSYNC`. The scratch Lesson 36 prototype with WSYNC-first measured `OverscanStart` at
230 (a 263-line frame); reordering to work-first measured 229 (262).
**Options:** (a) work-first; (b) WSYNC-first and a 191-line loop; (c) leave it to the implementer.
**Decision:** (a) — every full-screen kernel writes the line's registers, then `STA WSYNC`; the
first work line is 37 and the last is 228. **Resolution:** 03 §Shared Conventions; ST-35.4/36.4/
37.4 require `OverscanStart` 229. **Resolved.**

### PF-008 — 🟠 MAJOR — The two-object HMOVE placement was not pinned; the store could land late

**Location:** `03-lesson-specs.md` §Shared Conventions; Lesson 35–37 positioning.
**Problem:** The plan said "one HMOVE" but not where the final `STA WSYNC` sits. The scratch
prototype with a caller-level WSYNC reported `HmoveApply` at line 3 cycle 61; moving the WSYNC
inside the positioning routine put `HmoveDone` at line 3 cycle 3, with the markers at the expected
X. A late HMOVE risks the comb/extra-offset behavior.
**Options:** (a) put the final WSYNC/HMOVE inside the positioning routine; (b) use one routine per
object with its own HMOVE; (c) rely on the caller.
**Decision:** (a) — the final `STA WSYNC` sits immediately after the last `STA RESPx`, with
`STA HMOVE` next; the doc reports `HmoveApply` (stall) and `HmoveDone` (store). The measured X is
authoritative. **Resolution:** 03 §Shared Conventions; ST rows. **Resolved.**

### PF-009 — 🟠 MAJOR — `BodyStart` 117 was copied from the sprite lessons

**Location:** `03-lesson-specs.md` evidence pins; ST-35.4/36.4/37.4.
**Problem:** Lessons 35–37 are full-screen kernels; their first visible line is 37, not 117. A
test pinned to 117 would fail a correct implementation.
**Options:** (a) use 37 for all three; (b) add a per-lesson marker checkpoint and keep 117.
**Decision:** (a) — `BodyStart` 37; the marker/VU-specific rows are checked separately.
**Resolution:** 03/07 updated. **Resolved.**

### PF-010 — 🟠 MAJOR — Lesson 35's pitch/bottom line budget was inconsistent

**Location:** `03-lesson-specs.md` §Lesson 35; ST-35.2.
**Problem:** The layout said the pitch band was 122–137 and the bottom 54 lines, but the preceding
24+4+90 lines end at 117. The correct pitch band is 118–133, marker 122–129, bottom 134–191
(58 lines).
**Options:** (a) correct the line numbers; (b) change the VU height; (c) leave it to the
implementer.
**Decision:** (a). **Resolution:** 03/07 use 118–133 and y≈491–517. **Resolved.**

### PF-011 — 🟡 MINOR — The Lesson 36 rest behavior was not pinned in the ST

**Location:** `03-lesson-specs.md` §Lesson 36; ST-36.3.
**Problem:** The lead sequence ends with `$FF`; the ST expected the last `LeadFreqWrite` to be 19
without saying how the rest handles the frequency.
**Options:** (a) the rest writes C4's `AUDF` 19 with volume 0; (b) the rest writes no frequency;
(c) change the sequence.
**Decision:** (a) — the log still ends on 19 and the marker hides. **Resolution:** 03/07 state
the behavior. **Resolved.**

### PF-012 — 🟡 MINOR — The evidence checkpoints did not identify the channel

**Location:** `03-lesson-specs.md` §Lesson 37; ST-37.3/37.4.
**Problem:** `SoundUpdate` writes both channels; a `VolWrite` breakpoint fires twice per frame with
different values and no channel label.
**Options:** (a) per-channel labels; (b) the X column is the channel; (c) log only channel 0.
**Decision:** (b) — the log's X column identifies the channel; the ST says so.
**Resolution:** 03/07. **Resolved.**

### PF-013 — 🟡 MINOR — The engine state fits 16 bytes only if table pointers are re-read

**Location:** `03-lesson-specs.md` §Shared RAM Map; AR-18/AR-25.
**Problem:** Caching the definition pointer plus the two per-step table pointers would need 20
bytes; the state block is 16.
**Options:** (a) re-read the table pointers into scratch each step; (b) enlarge the block;
(c) store only the table pointers and recompute the definition.
**Decision:** (a). **Resolution:** 03/AR-18/AR-25 state the 8-byte-per-channel layout.
**Resolved.**

### PF-014 — 🟡 MINOR — The divisor grouping and the "one table" wording were wrong

**Location:** `02-current-state.md`; `03-lesson-specs.md` §Lesson 36.
**Problem:** `D=2,6,31,93` was grouped as "4/5, 6/A/C/D, E" — but 6/A are div 31 and C/D are div 6.
The phrase "same divisor means one tuning table per octave" was false for the old bass table.
**Options:** (a) correct the mapping and the wording; (b) drop the detail.
**Decision:** (a). **Resolution:** 02 lists 4/5→2, 6/A→31, C/D→6, E→93; 03 says the two voices
share one table by design. **Resolved.**

### PF-015 — 🟡 MINOR — Two exercise details were underspecified

**Location:** `03-lesson-specs.md` exercises 35.3 and 36.1.
**Problem:** Lesson 35 ex 3 said "`SWCHA` bits 4–7 (left/right)"; the P0 left/right bits are 6/7.
Lesson 36 ex 1 changed `NOTE_FRAMES` but not the harmony duration, so the voices could
desynchronize.
**Options:** (a) fix the bits and make `HARMONY_FRAMES = 4 × NOTE_FRAMES`; (b) leave the
desynchronization as a feature.
**Decision:** (a). **Resolution:** 03/07. **Resolved.**

### PF-016 — 🟡 MINOR — The Part 5 index row states and the Lesson 38 boundary were unstated

**Location:** `03-lesson-specs.md` cross-lesson consistency; `99-execution-plan.md`; ST-37.6.
**Problem:** The plan said the index is rebuilt in Phase 1 but not that rows 36–37 start
`🔒 Coming Soon`. The Lesson 38 stub has no frontmatter, so Lesson 37's next link has no back
link.
**Options:** (a) state the row statuses and the Part 6 boundary exception; (b) add frontmatter to
the 38 stub (out of scope).
**Decision:** (a) — the index rows flip per phase; the 38 stub's frontmatter is Part 6's
responsibility. **Resolution:** 03/07/99. **Resolved.**

### PF-017 — 🟡 MINOR — The BOOM capture had no concrete expectation

**Location:** `07-testing-strategy.md` ST-35.2/35.6.
**Problem:** ST-35.2 checked only `beep.png`; `boom.png` had a qualitative "shorter" description.
**Options:** (a) add a concrete first-step expectation (band 2 red, 15 red cells, marker x=457);
(b) drop the second image.
**Decision:** (a) — the doc records the exact captured step and height. **Resolution:** 07.
**Resolved.**

### PF-018 — 🟡 MINOR — Two Lesson 37 ST rows were imprecise

**Location:** `07-testing-strategy.md` ST-37.1/37.5.
**Problem:** ST-37.1 said "assemble include/sound.asm" although `verify.sh` assembles only
`lessons/**/*.asm`; ST-37.5 said "5 steps" for a volume bar.
**Options:** (a) say "the main source that includes the library" and separate the step count from
the bar height; (b) change the script.
**Decision:** (a). **Resolution:** 07. **Resolved.**

### PF-019 — 🟡 MINOR — Housekeeping in the current-state and execution docs

**Location:** `02-current-state.md` ("Parts 1–4", "Plan Created/Preflighted now");
`99-execution-plan.md` (stale timestamp, `head -3` document check, missing completion checks).
**Problem:** Part 0 was omitted; the roadmap was still Plan Created; the timestamp was pre-fix;
`head -3` cannot distinguish a lesson from a stub; the completion criteria omitted dead code,
security N/A, and the post-completion re-analysis.
**Options:** (a) correct the docs; (b) leave them to execution.
**Decision:** (a). **Resolution:** 02/99 updated. **Resolved.**

### PF-020 — 🟡 MINOR — The findings ledger and the push authority were missing

**Location:** plan folder; `00-ambiguity-register.md` AR-12; `99-execution-plan.md`.
**Problem:** The plan referenced a findings ledger but did not create it; push mode was not tied to
an explicit authority.
**Options:** (a) create `05-findings.md` with a zero-findings header and record the push authority
in AR-12; (b) drop the ledger.
**Decision:** (a) — the user's directive to execute RD-05 plus the Part 1–4 push practice is the
continuing authority. **Resolution:** `05-findings.md` created; AR-12/99 updated. **Resolved.**

### PF-021 — 🟡 MINOR — The lesson-template checklist and TypeScript equivalents were implicit

**Location:** `03-lesson-specs.md` Shared Conventions.
**Problem:** The plan referenced "the fixed lesson template" but did not list its sections or the
TypeScript equivalent for each lesson. A lesson author could omit a section.
**Options:** (a) add the checklist and a one-line TypeScript concept per lesson; (b) rely on the
skill.
**Decision:** (a). **Resolution:** 03 §Lesson Document Template. **Resolved.**

### PF-022 — 🟡 MINOR — Some evidence pins were not mirrored in the ST rows

**Location:** `03-lesson-specs.md` vs `07-testing-strategy.md`.
**Problem:** `CtlWrite`, `MusicStart`, and `HmoveDone` were listed as evidence but not checked in
the corresponding ST rows.
**Options:** (a) add them to the ST rows; (b) remove them from the evidence list.
**Decision:** (a). **Resolution:** 07 ST-35.3/35.4, ST-37.3/37.4. **Resolved.**

### PF-023 — 🔵 OBSERVATION — The static ledger is arithmetic, not a numeric table

**Location:** `03-lesson-specs.md` Shared Conventions.
**Problem:** "Static cycle ledgers" are promised, but the docs do not enumerate the VBLANK cycles.
**Decision:** accepted — 03 now budgets 2,812 cycles (37 lines) and notes the 2,753-tick timer
plus the final WSYNC; Session C records the measured `HmoveDone` and frame lines.

### PF-024 — 🔵 OBSERVATION — The priority-bar table's 20-bit pattern

**Location:** `03-lesson-specs.md` §Lesson 37.
**Problem:** "Three bytes per entry" needed a gloss: PF0/PF1/PF2 = one 20-bit row, mirrored.
**Decision:** accepted — 03 now states the left half lights N chunks and `CTRLPF` mirrors it.

### PF-025 — 🔵 OBSERVATION — `lesson-author` is routed but not used as a separate executor

**Location:** `00-index.md` Specialist Agents.
**Problem:** The role exists in `codeops/codeops.json`, but this run executes directly with the
lesson-production skill.
**Decision:** accepted — the index states the choice; the two reviewers remain the gate.

### PF-026 — 🔵 OBSERVATION — Screenshot timing is wall-clock

**Location:** `03-lesson-specs.md`/`07-testing-strategy.md`.
**Problem:** The audio envelope phase at capture time is not frame-locked.
**Decision:** accepted — captures use a burst and select the documented state; the doc records the
measured step/height rather than claiming a specific frame.

## Verification

| Check | Result |
| --- | --- |
| All plan links resolve (except this report before creation) | pass after this file is added |
| AR rows 1–26, no open item | pass |
| ST cases: 6 per lesson, 18 total | pass |
| Specification-first ordering (Session A freeze → B implement → C verify) | pass |
| `AUDF` values all 0–31 in 03/07 | pass after PF-001 |
| Combined volume ≤ 15 in Lesson 37 | pass after PF-005 |
| Frame budget: 3 + 37 + 192 + 30 = 262; timer 44 + final WSYNC | pass |
| Scratch prototypes assembled to 4,096 bytes and ran in Stella | pass |

## Pass Verdict

**✅ PREFLIGHT PASSED WITH NOTES.** All critical and major findings are resolved; all minor
findings are resolved; the four observations are accepted with their rationale. The plan is ready
for execution after this report and the fixes are committed and the roadmap row is advanced to
`Plan Preflighted`.

## Residual Risks

1. **Audio is temporal.** The state logs prove the register values and frame timing, not the
   listener's perception; the committed ROM and `<RomPlayer>` are the audible artifact. The lesson
   docs disclose this.
2. **The harmony is not a deep bass.** A true C3 bass is outside the div-6 `AUDF` range; the
   lesson chooses an in-tune harmony and publishes the trade-off rather than hiding it.
3. **The capture phase is wall-clock.** The screenshots are selected from bursts and checked
   against the measured state; the doc records the measured step/height.
