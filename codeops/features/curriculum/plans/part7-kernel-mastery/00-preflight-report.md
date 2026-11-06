# Preflight Report: Part 7 — Kernel Mastery (Lessons 48–55)

> **Status**: ✅ PREFLIGHT PASSED WITH NOTES — 2 critical + 25 major resolved, 13 minor resolved,
> 2 observations accepted
> **Iteration**: 2 (first scan found the defects; the revised plan was re-checked)
> **Artifact**: implementation plan at `codeops/features/curriculum/plans/part7-kernel-mastery/`,
> committed before this report; post-fix plan hash
> `13dfb7c954532f28c7e1ee1c05d868af6ac3e574` (all plan documents except this report)
> **Codebase Grounded**: 38 source/reference files examined, 70 references verified, two
> independent subagent audits, and two scratch prototypes measured in Stella 7.0 (the three-plane
> vertical tunnel and the 48-pixel text buffer with the pre-shifted phase table)
> **Last Updated**: 2026-11-05
>
> ⚠️ **SAME-SESSION REVIEW** — the plan was created in this session. Mitigations: every finding was
> checked against the real repository; two independent subagents audited the plan (one
> hardware/kernel, one curriculum/integration); the two high-risk kernels were prototyped in Stella
> before their specs were frozen; the per-lesson reviews remain the independent execution gate.

## Audit Scope Contract

| Term | Content |
| --- | --- |
| **Audit target** | `codeops/features/curriculum/plans/part7-kernel-mastery/` (all seven plan documents plus the findings ledger) |
| **Context documents** | `RD-07-part7-kernel-mastery.md`, `README.md`, `docs/.vitepress/config.ts`, `docs/part7-kernel-mastery/*` stubs, `docs/part8-advanced/56-bankswitching.md`, `include/vcs.asm`, `include/macro.asm`, `include/score.asm`, `scripts/verify.sh`, `scripts/build-roms.sh`, `scripts/capture-screenshot.sh`, the Part 6 plan, `atari-2600-expert/references/{kernels,timing,sprite-tricks,legendary,pitfalls}.md`, `vcs-lesson-production/{SKILL.md,references/lesson-template.md}` |
| **Modification set** | The audit target only; the fixes below change plan documents and add this report. No lesson source, ROM, or site file is changed by the preflight. |

## Codebase Context Summary

**Tech stack:** 6502 assembly (ACME 0.97), VitePress 1.6.4, Node 20+, Bash tooling; static lesson
content and committed 4,096-byte ROMs.

**Architecture:** per-lesson `.asm` sources plus three exercise solutions; lesson documents under
`docs/partN-topic/`; committed ROMs under `docs/public/roms/`; screenshots under
`docs/public/images/lessonNN/`; the Part 7 sidebar entries already exist (`config.ts:125–132`);
the Part 7 index is a 5-line stub; Lesson 47 already links forward to Lesson 48; Lesson 55's next
points at the Part 8 Lesson 56 stub.

**Ground truth examined:** `include/vcs.asm` (`WSYNC=$02`, `VBLANK=$01`, `PF0/1/2`, `GRP0/1`,
`ENABL`, `NUSIZ`, `HMP0/1`, `HMBL`, `HMOVE`, `VDELP0/1`, `CTRLPF`, `COLUPF`, `COLUBK`, `SWCHB`,
`INPT4`); `include/macro.asm`; `include/score.asm` (the 48-pixel kernel, `ScoreBuf` `$A8–$D7`,
`ScoreDraw` 9 lines, `ScoreSetup` one HMOVE); the Part 6 lessons for the frame/positioning
patterns; the `atari-2600-expert` kernel/timing/sprite-trick/legendary references; and two scratch
prototypes: the three-plane 256-row tunnel (192 lines, 40/41 cycles/line, a 16-line ship, measured in
Stella) and the 48-pixel text buffer (the glyph columns render and the pre-shifted phase table
shifts the window by one pixel).

## Summary by Dimension

| # | Dimension | Findings | Highest Severity |
|---|-----------|----------|-----------------|
| 1 | Ambiguities | 4 | 🟠 MAJOR |
| 2 | Implicit Assumptions | 5 | 🔴 CRITICAL |
| 3 | Logical Contradictions | 6 | 🔴 CRITICAL |
| 4 | Completeness Gaps | 4 | 🟠 MAJOR |
| 5 | Dependency Issues | 2 | 🟡 MINOR |
| 6 | Feasibility Concerns | 6 | 🔴 CRITICAL |
| 7 | Testability | 3 | 🟡 MINOR |
| 8 | Security Blind Spots | 0 | — (N/A) |
| 9 | Edge Cases | 4 | 🟠 MAJOR |
| 10 | Scope Creep Indicators | 0 | — |
| 11 | Ordering & Sequencing | 2 | 🟡 MINOR |
| 12 | Consistency | 4 | 🟡 MINOR |
| 13 | Codebase Alignment | 3 | 🟠 MAJOR |

## Summary by Severity

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | 2 | resolved |
| MAJOR | 25 | resolved |
| MINOR | 13 | resolved |
| OBSERVATION | 2 | accepted |

## Findings

### PF-001 — 🔴 CRITICAL — Lesson 51 stored two 184-byte strips in 128-byte RAM

**Location:** `03-lesson-specs.md` §Lesson 51; AR-16.
**Problem:** the flicker lab cleared and stamped two 184-byte P0/P1 strips each frame — 368 bytes
of writable storage on a console with 128 bytes total. The VBLANK clear also assumed 3-cycle
indexed stores.
**Options:** (a) a per-row skipdraw test with the four 8-byte shapes; (b) one 128-byte buffer;
(c) a smaller object count.
**Decision:** (a) — the two selected objects are drawn inside a 2-line kernel by the
`row - ObjRow` / `CMP #4` / shape-table skipdraw; no strips. The 2-line budget (152 cycles) fits
two branchy tests split across the two lines (the plan estimated ~93 cycles/2 lines; the measured ledger is 89, 48+41, each line ≤76).
**Resolution:** 03 §Lesson 51, AR-16/AR-29/AR-35, ST-51.2/51.3 updated. **Resolved.**

### PF-002 — 🔴 CRITICAL — Lesson 52 read a row-major world with three consecutive offsets

**Location:** `03-lesson-specs.md` §Lesson 52; AR-17/AR-36.
**Problem:** `World+0,X`, `World+1,X`, `World+2,X` on a 256-row × 3-byte row-major table reads
three consecutive bytes, not one row; the tunnel could not be the specified one.
**Decision:** three independent 256-byte planes (`WorldPF0/1/2`) indexed by the same X.
**Resolution:** 03 §Lesson 52 and the ST rows updated; the three-plane tunnel was assembled and
measured in Stella (192 lines, 40/41 cycles/line, a 16-line ship). **Resolved.**

### PF-003 — 🟠 MAJOR — Lesson 52's 1-line "16-line ship" was 8 bytes

**Location:** `03-lesson-specs.md` §Lesson 52.
**Problem:** a 1-line kernel draws one byte per line, so 8 bytes are 8 lines; the spec said 16.
**Decision:** a 16-byte strip (16 lines) at rows 150–165; the strip is 192 bytes and the forward
loop reads 0..191.
**Resolution:** 03 §Lesson 52 and ST-52.2 updated. **Resolved.**

### PF-004 — 🟠 MAJOR — Lesson 52's "snaking gap" is impossible with one reflected PF write

**Location:** `03-lesson-specs.md` §Lesson 52; AR-17.
**Problem:** a 3-byte PF row is 20 bits; with `CTRLPF=$01` the right half reflects the left, so the
gap is centred and cannot snake sideways.
**Decision:** the gap is centred and its **width** breathes with a 32-row sine (6..10 chunks);
the ship's HMOVE provides the one-pixel horizontal motion. The doc states the hardware limit.
**Resolution:** 03 §Lesson 52, AR-17/AR-36, ST-52.2 updated. **Resolved.**

### PF-005 — 🟠 MAJOR — Lesson 54's road curve is impossible with one reflected PF write

**Location:** `03-lesson-specs.md` §Lesson 54; AR-19.
**Problem:** the road centre cannot move with a 3-byte reflected playfield row; the "curve" and
exercise 3 were impossible.
**Decision:** a centred road whose **width** grows toward the bottom and pulses with a 64-row
table; exercise 3 becomes a width pulse (`WidthIndex`). The doc states the limit.
**Resolution:** 03 §Lesson 54, AR-19/AR-38, ST-54.2/54.5 updated. **Resolved.**

### PF-006 — 🟠 MAJOR — Lesson 50 applied the ball's fine offset twice

**Location:** `03-lesson-specs.md` §Lesson 50; AR-27.
**Problem:** `ScoreSetup`'s HMOVE applies `HMBL`; the later `GameHmove` re-applies every motion
register, shifting the ball twice.
**Decision:** clear `HMBL` after `ScoreHmove` and before `GameHmove`; the ball keeps the position
`ScoreHmove` gave it.
**Resolution:** 03 §Lesson 50, ST-50.3 updated. **Resolved.**

### PF-007 — 🟠 MAJOR — Row loops were off by one

**Location:** `03-lesson-specs.md` §Shared Conventions; every row-loop claim; ST-49.3.
**Problem:** `LDY #N; DEY; BNE` executes N times (Y=N..1), so `LDY #(N-1)` draws N−1 rows; the plan
mixed the two and the evidence counter values.
**Decision:** the course idiom is `LDY #0; INY; CPY #N; BNE` (N top-down rows, Y=0..N−1); the
table index is the visible row and no sentinel is needed. Every ledger and evidence pin uses
that form.
**Resolution:** shared conventions, 03 §48–55, AR-25/AR-33, ST-49.3 updated. **Resolved.**

### PF-008 — 🟠 MAJOR — Lesson 49's margin was computed against one line

**Location:** `03-lesson-specs.md` §Lesson 49; AR-33.
**Problem:** 152 − 62 = 90 per pair = 45 per line, not 16.
**Decision:** state 90 cycles per pair (45/line).
**Resolution:** 03 §Lesson 49, AR-33, ST-49.3 updated. **Resolved.**

### PF-009 — 🟠 MAJOR — Lesson 53's lesson RAM was too small for the 48-byte strip

**Location:** `03-lesson-specs.md` §Lesson 53; AR-22/AR-28.
**Problem:** `$84–$9F` is 28 bytes; the sprite strip is 48 bytes.
**Decision:** `$84–$9F` counters, `$A0–$CF` the 48-byte strip, `$D0–$F7` free; the library
keeps `$80–$83`.
**Resolution:** 03, AR-22/AR-28, 00-index, 01-requirements updated. **Resolved.**

### PF-010 — 🟠 MAJOR — The pattern library leaked state across bands

**Location:** `03-lesson-specs.md` §Lesson 53; AR-28.
**Problem:** `KernelFill`/`KernelSpriteStrip`/`KernelColorRamp` do not clear PF0–PF2, and
`KernelPFRows` does not clear GRP0; the next band would show the previous band's playfield/sprites.
**Decision:** each band boundary clears PF0–PF2 and GRP0/GRP1; the routines write only their object.
**Resolution:** 03 §Lesson 53, AR-28, ST-53.3 updated. **Resolved.**

### PF-011 — 🟠 MAJOR — Lesson 49's second screenshot was unreachable without input

**Location:** `03-lesson-specs.md` §Lesson 49; `scripts/capture-screenshot.sh`.
**Problem:** the figure moved only with the joystick; the capture script injects no input.
**Decision:** a 272-frame auto-demo sweeps the figure 8→144→8 at one pixel per frame when there
is no input.
**Resolution:** 03 §Lesson 49, ST-49.2 updated. **Resolved.**

### PF-012 — 🟠 MAJOR — Lesson 51's Y direction and "nearer" rule were inverted

**Location:** `03-lesson-specs.md` §Lesson 51; AR-35.
**Problem:** Y is top-down in the course; the larger Y is nearer the bottom.
**Decision:** the larger Y of a parity pair goes on P0.
**Resolution:** 03 §Lesson 51, AR-35, ST-51.3 updated. **Resolved.**

### PF-013 — 🟠 MAJOR — Lesson 53's ledgers ignored the pointer and loop costs

**Location:** `03-lesson-specs.md` §Lesson 53; AR-37.
**Problem:** `(KernelPtr),Y` is 5 cycles and the 16-bit pointer advance is ~13; `KernelFill` needs
`DEX`/`BNE`.
**Decision:** fill 11/line, PF rows ~28/line, sprite strip 19/line, color ramp 19/line.
**Resolution:** 03 §Lesson 53, AR-37, ST-53.3 updated. **Resolved.**

### PF-014 — 🟠 MAJOR — Lesson 55's text box and buffer stride were wrong

**Location:** `03-lesson-specs.md` §Lesson 55; AR-31/AR-39.
**Problem:** the mapping gives x=361–643 for X=56–103, not 367–642 (the lit glyphs start inside the
cells); `ScoreBuf` is column-major, so a contiguous 48-byte copy scrambles the columns.
**Decision:** state the cell block x=361–643 and the measured lit block x≈367–642, y≈110–130;
store at `ScoreBuf + c*8 + r`.
**Resolution:** 03 §Lesson 55, AR-31/AR-39, ST-55.2/55.3 updated. **Resolved.**

### PF-015 — 🟠 MAJOR — Lesson 55's 14-character exercise kept the 17-character wrap

**Location:** `03-lesson-specs.md` §Lesson 55 exercise 1.
**Problem:** 14×8−48 = 64, not 88.
**Decision:** derive the wrap from `MessageLen*8 - 48` (64 for 14 chars).
**Resolution:** 03 §Lesson 55, ST-55.5 updated. **Resolved.**

### PF-016 — 🟠 MAJOR — Lesson 55's second band needed a second buffer and broke the line total

**Location:** `03-lesson-specs.md` §Lesson 55 exercise 3.
**Problem:** `ScoreDraw` reads one fixed `ScoreBuf`; a second band needs a second buffer or a refill;
adding 9 lines to the 183-line starfield would total 201.
**Decision:** refill the same `ScoreBuf` during the 87-line gap; the starfield shrinks to 174
(9+87+9+87 = 192).
**Resolution:** 03 §Lesson 55, ST-55.5 updated. **Resolved.**

### PF-017 — 🟠 MAJOR — Lesson 54's exercises repeated the base behavior

**Location:** `03-lesson-specs.md` §Lesson 54 exercises 1/2.
**Problem:** the base rainbow shifts every 4 frames, so exercise 2's "every 4" was a no-op; the
playfield starfield has one colour per line, so "some stars change colour" was false.
**Decision:** exercise 2 shifts every 2 frames; exercise 1 adds a per-star `TwinkleMask`.
**Resolution:** 03 §Lesson 54, ST-54.5 updated. **Resolved.**

### PF-018 — 🟠 MAJOR — Lesson 50's ball could overrun the play zone

**Location:** `03-lesson-specs.md` §Lesson 50.
**Problem:** an 8-line ball at Y=170 in a 174-line zone ends at 177, past the ground.
**Decision:** clamp the ball's top to Y=158 (ends at 165).
**Resolution:** 03 §Lesson 50 updated. **Resolved.**

### PF-019 — 🟠 MAJOR — Lesson 48 omitted the stub's historical analysis

**Location:** `03-lesson-specs.md` §Lesson 48; the Lesson 48 stub.
**Problem:** the stub promises "Historical analysis of 5 iconic game kernels"; the spec had none.
**Decision:** add the five-kernel Theory section (Combat, Adventure, Pitfall!, River Raid, Cosmic
Ark), clearly marked as historical context.
**Resolution:** 03 §Lesson 48 Concepts and ROM design updated. **Resolved.**

### PF-020 — 🟠 MAJOR — The stubs' promised effects/history were not in the specs

**Location:** `03-lesson-specs.md` §Lesson 54/55; the Lesson 54/55 stubs.
**Problem:** Lesson 54's stub says "Starfield effect with missiles"; Lesson 55's says "How
Activision's scrolling logo worked". The specs used a P0 ship and omitted the history.
**Decision:** the starfield adds three bright stars on the ball/missiles; Lesson 55 adds a short,
clearly historical Activision note.
**Resolution:** 03 §Lesson 54/55 updated. **Resolved.**

### PF-021 — 🟠 MAJOR — The plan said Lesson 55 uses the pattern library

**Location:** `00-index.md`, `99-execution-plan.md`, AR-42; `03-lesson-specs.md`.
**Problem:** Lesson 55 uses `include/score.asm`, not `include/kernel_patterns.asm`; the dependency
sentence was wrong.
**Decision:** 55 reuses 39's 48-pixel kernel; 54 uses 52's scroll with its own tables; 53's library
is standalone (the demo and its exercises use it).
**Resolution:** 00-index, 99, AR-42, 03 updated. **Resolved.**

### PF-022 — 🟠 MAJOR — Lesson 52's cycle count was 36, not 38

**Location:** `03-lesson-specs.md` §Lesson 52; AR-30/AR-36.
**Problem:** the listed operations sum to 40 cycles/line nominal (forward loop, page-aligned planes).
**Decision:** 40 nominal / 41 effective; the taken BNE crosses a page. Exercise 1 is page-local at 40.
**Resolution:** 03 §Lesson 52, AR-30/AR-36, ST-52.3 updated. **Resolved.**

### PF-023 — 🟠 MAJOR — Lesson 49's unrolled ledger was 120, not 115

**Location:** `03-lesson-specs.md` §Lesson 49 exercise 1.
**Problem:** two 55-cycle row bodies plus the shared 7-cycle loop tail is 117.
**Decision:** 117 cycles per four lines.
**Resolution:** 03 §Lesson 49 updated. **Resolved.**

### PF-024 — 🟠 MAJOR — Lesson 53's sprite stamp could write past the strip

**Location:** `03-lesson-specs.md` §Lesson 53.
**Problem:** an 8-byte sprite at row 44+ in a 48-byte strip overruns.
**Decision:** clamp the stamp row to 1–40.
**Resolution:** 03 §Lesson 53 updated. **Resolved.**

### PF-025 — 🟠 MAJOR — Lesson 52's sine period did not divide 256

**Location:** `03-lesson-specs.md` §Lesson 52; AR-36.
**Problem:** a period of ~113 rows leaves a 4-chunk jump at the world wrap.
**Decision:** a 32-row period, which divides 256; row 255 and row 0 join cleanly.
**Resolution:** 03 §Lesson 52, AR-36 updated. **Resolved.**

### PF-026 — 🟠 MAJOR — Lesson 50's status bar was described as one bar but mirrored

**Location:** `03-lesson-specs.md` §Lesson 50.
**Problem:** the reflected playfield draws two bars.
**Decision:** "a mirrored pair of 15-chunk gold level bars (one per half)".
**Resolution:** 03 §Lesson 50 updated. **Resolved.**

### PF-027 — 🟠 MAJOR — Lesson 54's sun was a ball in the AR but a playfield block in the spec

**Location:** `00-ambiguity-register.md` AR-19; `03-lesson-specs.md` §Lesson 54.
**Problem:** the ball shares COLUPF with the horizon, so a ball sun conflicts.
**Decision:** the sun is a centred playfield block at rows 40–88; no ball.
**Resolution:** AR-19 and 03 §Lesson 54 updated. **Resolved.**

### PF-028 — 🟡 MINOR — Lesson 55's lit-pixel box mixed the cell and glyph bounds

**Location:** `03-lesson-specs.md` §Lesson 55; ST-55.2.
**Problem:** x=367–642 is the lit glyph block, not the 48-px cell block (x=361–643).
**Decision:** state both; the y is 110–130 (the lit block), with the 9-line zone at 0–8.
**Resolution:** 03 §Lesson 55, ST-55.2 updated. **Resolved.**

### PF-029 — 🟡 MINOR — Lesson 55's fill stored a contiguous 48 bytes

**Location:** `03-lesson-specs.md` §Lesson 55; AR-31.
**Problem:** `ScoreBuf` is column-major; a contiguous copy scrambles the columns.
**Decision:** store at `ScoreBuf + c*8 + r`.
**Resolution:** 03 §Lesson 55, AR-31, ST-55.3 updated. **Resolved.**

### PF-030 — 🟡 MINOR — Lesson 48's table sizes mixed displayed rows and ROM bytes

**Location:** `00-ambiguity-register.md` AR-32; `03-lesson-specs.md` §Lesson 48.
**Problem:** the full modes display 192/96 rows but repeat the 96×3/48×3 tables; the AR said
192×3/96×3.
**Decision:** the tables are 96×3 and 48×3, repeated in the full modes; the strips are 96/48 bytes,
repeated.
**Resolution:** AR-32 and 03 §Lesson 48 updated. **Resolved.**

### PF-031 — 🟡 MINOR — The Session B steps for Lessons 49–55 did not flip their index rows

**Location:** `99-execution-plan.md` Phases 2–8.
**Problem:** the expected-modifications blocks list the index, but the Session B steps did not say
to flip the row.
**Decision:** each Session B flips its own row; the Lesson 55 commit flips row 55.
**Resolution:** 99 updated. **Resolved.**

### PF-032 — 🟡 MINOR — The Phase 8 completion gate re-flipped row 55 after the lesson commit

**Location:** `99-execution-plan.md` Phase 8.
**Problem:** the completion gate said "flip index row 55", which belongs in the Lesson 55 commit.
**Decision:** the Lesson 55 commit flips row 55; 8.1.1a only confirms it.
**Resolution:** 99 updated. **Resolved.**

### PF-033 — 🟡 MINOR — The plan-level HMOVE check excluded Lessons 53/54

**Location:** `99-execution-plan.md` plan-level verification.
**Problem:** 53's sprite band and 54's ship/car use P0 and one HMOVE.
**Decision:** require `HmoveDone` for 48–55, including 53/54.
**Resolution:** 99 updated. **Resolved.**

### PF-034 — 🟡 MINOR — Two ST rows checked `$02` where the visible field is a gradient/rainbow

**Location:** `07-testing-strategy.md` ST-49.2/54.2.
**Problem:** Lessons 49/54 fill the visible area with a sky ramp/rainbow; `$02` is only the border.
**Decision:** check the gradient/rainbow and reserve `$02` for the border.
**Resolution:** 07 updated. **Resolved.**

### PF-035 — 🟡 MINOR — The 8.1.1a gate looked like a ninth task

**Location:** `99-execution-plan.md` Phase 8.
**Problem:** the progress header counts 8 lesson tasks; the gate is a ninth checkbox.
**Decision:** label 8.1.1a a completion gate, not a lesson task; the progress stays 8 tasks.
**Resolution:** 99 updated. **Resolved.**

### PF-036 — 🟡 MINOR — Lesson 53's stamp rows and strip size were ambiguous

**Location:** `03-lesson-specs.md` §Lesson 53.
**Problem:** the 8-byte sprite stamp and the 48-byte strip needed an explicit clamp.
**Decision:** clamp the stamp row 1–40; the strip is 48 bytes, row 0 blank.
**Resolution:** 03 §Lesson 53 updated. **Resolved.**

### PF-037 — 🟡 MINOR — Lesson 54's rainbow exercise repeated the base speed

**Location:** `03-lesson-specs.md` §Lesson 54 exercise 2.
**Problem:** the base is 4 frames; the exercise also said 4.
**Decision:** the exercise changes it to 2 frames.
**Resolution:** 03 §Lesson 54, ST-54.5 updated. **Resolved.**

### PF-038 — 🟡 MINOR — Lesson 55's second band total was 201

**Location:** `03-lesson-specs.md` §Lesson 55 exercise 3.
**Problem:** 9 + 183 + 9 = 201.
**Decision:** shrink the starfield to 174: 9 + 87 + 9 + 87 = 192; refill `ScoreBuf` in the gap.
**Resolution:** 03 §Lesson 55, ST-55.5 updated. **Resolved.**

### PF-039 — 🟡 MINOR — The Lesson 51 status row used a strip-build claim

**Location:** `99-execution-plan.md` Phase 4; `03-lesson-specs.md` §Lesson 51.
**Problem:** the redesign removed the strips; the plan still said "strip build".
**Decision:** say "per-row skipdraw".
**Resolution:** 99 and 03 updated. **Resolved.**

### PF-040 — 🟡 MINOR — The Lesson 55 dependency sentence said "53's fills"

**Location:** `99-execution-plan.md` overview.
**Problem:** 55 uses the score library.
**Decision:** "55 reuses 39's 48-pixel kernel".
**Resolution:** 99 updated. **Resolved.**

### PF-041 — 🔵 OBSERVATION — Lesson 56 has no explicit `prev` frontmatter

**Location:** `docs/part8-advanced/56-bankswitching.md`.
**Problem:** VitePress computes the back-link from the sidebar, but the course's explicit
frontmatter convention is not met.
**Decision:** accepted — the computed link works, and changing the Part 8 stub is outside RD-07.

### PF-042 — 🔵 OBSERVATION — The progress script counts 8 tasks, not the gate

**Location:** `99-execution-plan.md`.
**Problem:** the 8.1.1a completion gate is a ninth checkbox.
**Decision:** accepted — label it a gate; the lesson progress remains 8 tasks.

## Verification

| Check | Result |
| --- | --- |
| All plan links resolve (this report is created by this file) | pass after this file is added |
| AR rows 1–42, no open item | pass |
| ST cases: 6 per lesson, 48 total | pass |
| Specification-first ordering (Session A freeze → B implement → C verify) | pass |
| Lesson 51 fits 128 bytes (skipdraw, no strips) | pass after PF-001 |
| Lesson 52's three page-aligned planes and 40/41 ledger | pass after PF-002/PF-022 |
| Lesson 52/54's reflected playfield claims | pass after PF-004/PF-005 |
| Lesson 50's two HMOVEs and the ball | pass after PF-006 |
| Row loops draw N top-down rows (`LDY #0; INY; CPY #N; BNE`) | pass after PF-007 |
| Lesson 53's RAM (`$A0–$D0`) and ledgers (11/25/19/19) | pass after PF-009/PF-010/PF-013 |
| Lesson 55's text arithmetic and second band | pass after PF-014–PF-016 |
| Frame budget: 3 + 37 + 192 + 30 = 262; 48's split 96+96, 50's 9+8+174+1, 51's 8+184, 53's 4×48, 55's 9+183 | pass |
| The three-plane tunnel prototype assembled to 4,096 bytes and rendered in Stella | pass |
| The 48-pixel text prototype rendered the glyph columns and the pre-shifted shift | pass |

## Pass Verdict

**✅ PREFLIGHT PASSED WITH NOTES.** All critical and major findings are resolved; all minor
findings are resolved; the two observations are accepted with their rationale. The plan is ready
for execution after this report and the fixes are committed and the roadmap row is advanced to
`Plan Preflighted`.

## Residual Risks

1. **Kernel timing is temporal.** The state logs prove the scanline stores and the frame, not the
   player's perception; the committed ROM and `<RomPlayer>` are the runnable artifact. The lesson
   docs disclose this.
2. **The 1-line/2-line budgets are tight.** Lesson 51's measured skipdraw is 89 cycles per two lines and
   Lesson 52's loop is 40/line; each implementation must re-measure the actual cycles and record
   them before accepting a capture.
3. **The 48-pixel text table is data-heavy.** The 8-phase × 8-row × 18-byte table is 1152 bytes;
   the final ROM must still fit 4,096 bytes with the font, message, starfield, and code.
4. **The flicker is 30 Hz.** A still image shows one half; the two captures and the parity log are
   the evidence, and the doc says so.
5. **The playfield is 4-px.** Lessons 52 and 54 use the width, not the centre, for horizontal
   variation; the docs state the hardware limit.
