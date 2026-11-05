# Preflight Report: Part 6 — Game Development (Lessons 38–47)

> **Status**: ✅ PREFLIGHT PASSED WITH NOTES — 2 critical + 14 major resolved, 16 minor resolved,
> 2 observations accepted
> **Iteration**: 1 (first scan; fixes applied under the user's execution authorization for RD-06)
> **Artifact**: implementation plan at `codeops/features/curriculum/plans/part6-game-dev/`,
> committed before this report; post-fix plan hash
> `bd2be6bf8261d668d425cb8595901e136ef709e5` (all plan documents except this report)
> **Codebase Grounded**: 42 source/reference files examined, 61 references verified, two independent
> subagent audits, and the 48-pixel score prototype measured in Stella 7.0
> **Last Updated**: 2026-11-05
>
> ⚠️ **SAME-SESSION REVIEW** — the plan was created in this session. Mitigations: every finding was
> checked against the real repository; two independent subagents audited the plan (one
> hardware/design, one curriculum/integration); the 48-pixel score technique was assembled and
> rendered in Stella before its spec was frozen; the per-lesson reviews remain the independent
> execution gate.

## Audit Scope Contract

| Term | Content |
| --- | --- |
| **Audit target** | `codeops/features/curriculum/plans/part6-game-dev/` (all seven plan documents plus the findings ledger) |
| **Context documents** | `RD-06-part6-game-dev.md`, `README.md`, `docs/.vitepress/config.ts`, `docs/part6-game-dev/*` stubs, `docs/part7-kernel-mastery/48-introduction-to-kernels.md`, `include/vcs.asm`, `include/macro.asm`, `scripts/verify.sh`, `scripts/build-roms.sh`, `scripts/capture-screenshot.sh`, the Part 5 plan, `atari-2600-expert/references/{tia-hardware,sprite-tricks,kernels,pitfalls,timing}.md`, `vcs-lesson-production/{SKILL.md,references/lesson-template.md}` |
| **Modification set** | The audit target only; the fixes below change plan documents and add this report. No lesson source, ROM, or site file is changed by the preflight. |

## Codebase Context Summary

**Tech stack:** 6502 assembly (ACME 0.97), VitePress 1.6.4, Node 20+, Bash tooling; static lesson
content and committed 4,096-byte ROMs.

**Architecture:** per-lesson `.asm` sources plus three exercise solutions; lesson documents under
`docs/partN-topic/`; committed ROMs under `docs/public/roms/`; screenshots under
`docs/public/images/lessonNN/`; the Part 6 sidebar entries already exist (`config.ts:109–118`); the
Part 6 index is a 5-line stub; Lesson 37 already links forward to Lesson 38.

**Ground truth examined:** `include/vcs.asm` (`CXM0P=$00` … `CXPPMM=$07`, `CXCLR=$2C`,
`VDELP0=$25`, `VDELP1=$26`, `SWCHB=$0282`, `SWCHA=$0280`, `INPT4=$0C`); `include/macro.asm`
(`+clean_start`, `+vsync`, `+set_timer`, `+wait_timer`); the Part 5 lesson sources for the
frame/positioning patterns; the `atari-2600-expert` collision/VDEL/kernel/pitfall references; the
Bumbershoot Software 48-pixel Staugas-kernel article; and a scratch prototype that rendered
"123456" at capture x=367–642, y=109–131 in Stella 7.0.

## Summary by Dimension

| # | Dimension | Findings | Highest Severity |
|---|-----------|----------|-----------------|
| 1 | Ambiguities | 3 | 🟠 MAJOR |
| 2 | Implicit Assumptions | 2 | 🔴 CRITICAL |
| 3 | Logical Contradictions | 4 | 🔴 CRITICAL |
| 4 | Completeness Gaps | 4 | 🟠 MAJOR |
| 5 | Dependency Issues | 2 | 🟡 MINOR |
| 6 | Feasibility Concerns | 3 | 🟠 MAJOR |
| 7 | Testability | 3 | 🟡 MINOR |
| 8 | Security Blind Spots | 0 | — (N/A) |
| 9 | Edge Cases | 3 | 🟠 MAJOR |
| 10 | Scope Creep Indicators | 0 | — |
| 11 | Ordering & Sequencing | 1 | 🟡 MINOR |
| 12 | Consistency | 5 | 🟡 MINOR |
| 13 | Codebase Alignment | 4 | 🟠 MAJOR |

## Summary by Severity

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | 2 | resolved |
| MAJOR | 14 | resolved |
| MINOR | 16 | resolved |
| OBSERVATION | 2 | accepted |

## Findings

### PF-001 — 🔴 CRITICAL — Lesson 38's P0, P1, and ball never shared scanlines

**Location:** `03-lesson-specs.md` §Lesson 38 (P0 Y=140, P1 Y=40, ball Y=100); ST-38.2/38.5.
**Problem:** the TIA collision latches only set when the objects are drawn on the same scanline.
With P0 at Y=140, P1 at Y=40, and the ball at Y=100, the P0–P1 and P0–ball bands could never
light; `p1.png` and exercise 1 were impossible.
**Options:** (a) give P0 vertical movement; (b) put P1 and the ball on P0's scanlines; (c) add a
second player.
**Decision:** (a) — P0 moves in both axes (X 8…136, Y 40…156); P1 stays at Y=40 and the ball at
Y=100, so P0 can meet each. The auto-demo moves P0 around a rectangle so every pair meets.
**Resolution:** 03 §Lesson 38 and ST-38.2/38.4 updated. **Resolved.**

### PF-002 — 🔴 CRITICAL — Lessons 42 and 44 put P0 and P1 on different scanlines

**Location:** `03-lesson-specs.md` §Lesson 42 (P0 Y=140, P1 Y=40), §Lesson 44 (P0 Y=140, P1 Y=40);
ST-42.3/42.4/44.3.
**Problem:** both lessons use `CXPPMM` bit 7 for the collision/life path, but the players never
shared a scanline; the life loss, red field, and game-over flow were unreachable.
**Options:** (a) give P0 vertical movement; (b) put the enemy on the player's scanline; (c) use a
distance threshold instead of a hardware collision.
**Decision:** (b) for 42 (both at Y=140) and 44 (both at Y=100); the games are horizontal
dodging/chasing, so the same scanline is the natural design. Add a safe respawn and 60-frame
invulnerability.
**Resolution:** 03 §Lesson 42/44 and ST-42.3/44.3 updated. **Resolved.**

### PF-003 — 🟠 MAJOR — Lesson 38's sticky-latch exercise moved the clear instead of removing it

**Location:** `03-lesson-specs.md` §Lesson 38 exercise 3.
**Problem:** moving `STA CXCLR` after the visible kernel still clears once per frame; the next
VBLANK read sees zero and the bands go dark, not sticky. The exercise's expected result was wrong.
**Options:** (a) remove the store; (b) clear only when no contact; (c) leave it and document dark.
**Decision:** (a) — remove the store; the bands stay lit and the log shows no `CXClear` at all.
**Resolution:** 03 §Lesson 38 and ST-38.5 updated. **Resolved.**

### PF-004 — 🟠 MAJOR — The score zone's 9-line accounting was off by one

**Location:** `03-lesson-specs.md` §Shared Score Library; AR-15/AR-31; ST-39.4.
**Problem:** the plan said "8 rows + 1 cleanup line". The prototype measured a 1-line setup/blank
line, 8 score rows, and the cleanup sharing the last row's line; adding a separate cleanup line
would make a 193-line visible area and a 263-line frame.
**Options:** (a) 1 setup + 8 rows; (b) 8 rows + a separate cleanup and 182 game lines; (c) reduce
the score to 7 rows.
**Decision:** (a) — the score zone is 9 lines (visible 0 setup/blank, rows 1–8), the game zone is
183 lines, total 192.
**Resolution:** 03, AR-15/AR-31, ST-39.4 updated. **Resolved.**

### PF-005 — 🟠 MAJOR — `ScoreSetDigit` copied six bytes, not eight

**Location:** `03-lesson-specs.md` §Shared Score Library.
**Problem:** each column is eight rows; copying six leaves two stale rows. ST-39.3's "eight bits
per column" was also wrong (it is eight bytes/rows).
**Decision:** copy all eight bytes from `ScoreFont + digit×8`.
**Resolution:** 03 and ST-39.3 updated. **Resolved.**

### PF-006 — 🟠 MAJOR — The score target had three different widths and a wrong height

**Location:** `03-lesson-specs.md` §Lesson 39; ST-39.2.
**Problem:** the target was X=64–96 (32 px), "chunks 10–15" (24 px), and "48-px block"; visible
150–165 is 16 lines, but the expected y≈579–600 is 8 lines.
**Decision:** one rectangle: X=64–96 (32 px), visible 150–157 (8 lines), y≈579–602.
**Resolution:** 03, AR-14, ST-39.2 updated. **Resolved.**

### PF-007 — 🟠 MAJOR — BCD ADD 100 used A=100 as a BCD addend

**Location:** `03-lesson-specs.md` §Lesson 40; AR-16.
**Problem:** A=100 is `$64`, which is BCD 64; a single `ADC #$64` adds 64, not 100.
**Decision:** A is a **command selector** 1/10/100: A=1 adds 1 to the low byte, A=10 adds `$10`
to the low byte, and A=100 adds 1 to the middle byte (carrying into the high byte). The main ROM
implements ADD 1 and ADD 100; ADD 10 and SUB 1 are the exercise subjects.
**Resolution:** 03, AR-16, and the exercises updated. **Resolved.**

### PF-008 — 🟠 MAJOR — The BCD middle-carry exercise had no middle carry

**Location:** `03-lesson-specs.md` §Lesson 40 exercise 3.
**Problem:** 000990 + 100 = 001090 has no middle-byte carry (09 + 01 = 10).
**Decision:** use 009900 + 100 = 010000 (99 + 01 carries out).
**Resolution:** 03 and ST-40.5 updated. **Resolved.**

### PF-009 — 🟠 MAJOR — The LFSR meter was drawn at the wrong X

**Location:** `03-lesson-specs.md` §Lesson 43.
**Problem:** `PF0=$10` is chunk 0 (X=0), not X=24; the meter would appear at the left edge.
**Decision:** `PF1=$20` (chunk 6, X=24), mirrored by `CTRLPF=$01`.
**Resolution:** 03 and AR-19 updated. **Resolved.**

### PF-010 — 🟠 MAJOR — The 16×8 memory grid was left-aligned and duplicated

**Location:** `03-lesson-specs.md` §Lesson 45; ST-45.2.
**Problem:** PF0 bits 4–7 + PF1 + PF2 bits 0–3 are chunks 0–15 (the left edge), and the playfield
mirrors/repeats them, so the grid was left-aligned and 32 cells wide, not a centered 16×8 map.
**Decision:** use chunks 2–17 (`PF0=$C0`, `PF1`, `PF2=$3F`), `CTRLPF=$01`, and state that the
left half is the 128-byte map and the right half mirrors it. The flags row moves to chunks 2–5.
**Resolution:** 03, AR-21, ST-45.2 updated. **Resolved.**

### PF-011 — 🟠 MAJOR — The AI could jitter at the 24-px threshold and respawn on top of the player

**Location:** `03-lesson-specs.md` §Lesson 44.
**Problem:** chase >24 / flee ≤24 with ±2 movement can oscillate; the 60-frame timer did not gate
the transition; a respawn at the same X could re-collide every frame.
**Decision:** hysteresis (do not re-enter patrol while the distance is ≤ 32), a safe respawn at the
opposite side, and 60 frames of invulnerability.
**Resolution:** 03, AR-20, ST-44.3 updated. **Resolved.**

### PF-012 — 🟠 MAJOR — Six lessons' exercises restated features the main ROM already had

**Location:** `03-lesson-specs.md` §Lesson 38 ex 2; §40 ex 1–3; §42 ex 1–3; §43 ex 3; §45 ex 1/3;
§47 ex 2–3.
**Problem:** the main ROM already implemented the feature the exercise asked for, so the exercise
was a no-op.
**Decision:** move the feature out of the main ROM or change the exercise to an extension:
- 38 ex 2: add the enemy missile M1 (`CXM1P`), not the existing M0.
- 40: the main implements ADD 1/ADD 100; ex 1 adds ADD 10, ex 2 adds SUB 1, ex 3 is the
  009900+100 carry scenario.
- 42: the main reads both switches; ex 1 inverts the left switch, ex 2 selects three copies, ex 3
  caps the level at 10 on expert.
- 43 ex 3: seed from SELECT, a second source (fire keeps its reseed).
- 45: the main keeps four flag bytes; ex 1 packs them, ex 3 adds the `RamEnd` budget assert.
- 47 ex 2: change the border color by `DEBUG` and add a `BuildFlag` cell; ex 3 uses a rotated
  checksum.
**Resolution:** 03 and the corresponding ST-38.5/40.5/42.5/43.5/45.5/47.5 updated. **Resolved.**

### PF-013 — 🟠 MAJOR — Per-lesson prerequisites were missing

**Location:** `03-lesson-specs.md` §Lesson 38–47.
**Problem:** the lesson template requires a "Prerequisites" line; the plan only had a shared
template note.
**Decision:** add a specific prerequisite line to every lesson (earlier lessons and topics only).
**Resolution:** 03 updated. **Resolved.**

### PF-014 — 🟠 MAJOR — The 40 auto-demo could not produce the documented 000101 capture

**Location:** `03-lesson-specs.md` §Lesson 40; ST-40.2.
**Problem:** the auto-demo order ADD1, ADD10, ADD100, SUB1 from 000000 gives 000001, 000011,
000111, 000110 — 000101 is not in the sequence.
**Decision:** cycle ADD1 → ADD100 (the first two captures read 000001 and 000101); ADD10/SUB1 are
the exercise subjects.
**Resolution:** 03, AR-16, ST-40.2 updated. **Resolved.**

### PF-015 — 🟠 MAJOR — Lesson 42's playfield walls and status colors were underspecified

**Location:** `03-lesson-specs.md` §Lesson 42.
**Problem:** `PF2=$07` is chunks 12–14 (mirrored at 25–27), not a right wall; the level bar (gold)
and life cells (red) shared lines, so one `COLUPF` could not draw both.
**Decision:** `CTRLPF=$01` with `PF0=$F0` for both edge walls; the level bar is visible 0–7, the
life cells 8–15, the switch indicator 16–23, and the play area 24–191.
**Resolution:** 03 and ST-42.2/42.3 updated. **Resolved.**

### PF-016 — 🟠 MAJOR — Lesson 45's flags/legend/timer contradicted the playfield geometry

**Location:** `03-lesson-specs.md` §Lesson 45.
**Problem:** a 4-color legend cannot be drawn on one playfield line; the flags at X=112 are in the
mirrored right half; the high nibble counts 16-frame ticks, not seconds.
**Decision:** drop the 4-color legend (two-color map, the doc explains the regions); the flags row
is chunks 2–5; the timer's high nibble counts 16-frame ticks (the bar fills in 240 frames).
**Resolution:** 03, AR-21, ST-45.2/45.3 updated. **Resolved.**

### PF-017 — 🟡 MINOR — The score kernel is WSYNC-first, not work-first

**Location:** `03-lesson-specs.md` §Shared Conventions.
**Problem:** the blanket work-first rule contradicted the verified Staugas kernel.
**Decision:** document the score kernel as the WSYNC-first exception with its 1-line setup.
**Resolution:** 03 and AR-31 updated. **Resolved.**

### PF-018 — 🟡 MINOR — The score store count was six vs seven

**Location:** `03-lesson-specs.md` §Shared Score Library; AR-31.
**Problem:** the kernel has six data stores plus a seventh `STA GRP0` flush at cycle 54.
**Decision:** state six data stores plus the flush.
**Resolution:** 03 and AR-31 updated. **Resolved.**

### PF-019 — 🟡 MINOR — Lesson 39's leading-blank example had five columns

**Location:** `03-lesson-specs.md` §Lesson 39 ex 3.
**Problem:** `   42` is five columns; a six-digit score needs four blanks + 42.
**Decision:** `    42`.
**Resolution:** 03 updated. **Resolved.**

### PF-020 — 🟡 MINOR — Lesson 40's carry cell and bit strip overlapped

**Location:** `03-lesson-specs.md` §Lesson 40.
**Problem:** the operation bar 9–16, carry 17–24, and strip 24–31 overlap at line 24.
**Decision:** operation bar 9–16, carry 17–24, strip 25–32.
**Resolution:** 03 and AR-16 updated. **Resolved.**

### PF-021 — 🟡 MINOR — The LFSR history grid's cell width was wrong

**Location:** `03-lesson-specs.md` §Lesson 43.
**Problem:** PF1 bits are 4-px chunks, not 8-px; eight bits give a 32-px grid.
**Decision:** 4-px cells; the seed row, grid, and meter use the same width.
**Resolution:** 03 and AR-19 updated. **Resolved.**

### PF-022 — 🟡 MINOR — The LFSR seed ±1 control could reach zero

**Location:** `03-lesson-specs.md` §Lesson 43.
**Problem:** zero locks the LFSR; `RandomInit` only guards the reset seed.
**Decision:** the ±1 control wraps 0 to $FF.
**Resolution:** 03 and AR-19 updated. **Resolved.**

### PF-023 — 🟡 MINOR — The playfield bars are mirrored

**Location:** `03-lesson-specs.md` §Lesson 38/42/44/45/47; ST rows.
**Problem:** "N chunks from the left" appears twice under reflect; the pixel checks would count
30 cells for a 15-cell bar.
**Decision:** specify `CTRLPF=$01` and count "N chunks per half"; the left half is the reference.
**Resolution:** 03 §Lesson 38/42/44/45/47, AR-13/18/20/21/23, and the ST rows updated (including
44's state/distance row and 47's progress/checksum rows). **Resolved.**

### PF-024 — 🟡 MINOR — Lesson 42/44/46's status elements lacked exact X/Y

**Location:** `03-lesson-specs.md` §Lesson 42/44/46.
**Problem:** the level/life/state/distance elements were described qualitatively.
**Decision:** pin the visible ranges and X positions (42: 0–7/8–15/16–23/24–191; 44: 0–7/8–15/16–191;
46: 0–15/16–191).
**Resolution:** 03 §Lesson 42/44/46 updated, with the 44/46 rows repeated in ST-44.2/46.2. **Resolved.**

### PF-025 — 🟡 MINOR — The 41/40 source count was inconsistent

**Location:** `00-ambiguity-register.md` AR-30.
**Problem:** "41 sources" double-counted `demo-47.asm`; the correct total is 9 mains + 30 exercises
+ 1 demo = 40.
**Decision:** 40 sources, 40 ROMs.
**Resolution:** AR-30, 01-requirements updated. **Resolved.**

### PF-026 — 🟡 MINOR — AR provenance was inconsistent

**Location:** `00-ambiguity-register.md` header and provenance note.
**Problem:** AR-12/AR-31 were called user/course-policy in the header but AI-delegated in their
rows; AR-31 appeared in both lists.
**Decision:** AR #1, #4, #5, #30 are user/course-policy; AR #12 and #31 are delegated.
**Resolution:** AR header and provenance note updated. **Resolved.**

### PF-027 — 🟡 MINOR — The plan claimed a 43→44/46 LFSR dependency that did not exist

**Location:** `00-index.md`, AR-38.
**Problem:** 44's AI is deterministic and 46 selects modes by input, not the LFSR.
**Decision:** remove the dependency; 43 is the standalone randomness lesson.
**Resolution:** 00-index, 99, and AR-38 updated. **Resolved.**

### PF-028 — 🟡 MINOR — The frame/HMOVE checks were global

**Location:** `99-execution-plan.md` plan-level verification.
**Problem:** Lesson 46's intentional bug path is 230 lines, and 45/47 have no HMOVE.
**Decision:** check the fixed/default path at 229; check HMOVE only in the lessons that position
sprites (38–44, 46).
**Resolution:** 99 updated. **Resolved.**

### PF-029 — 🟡 MINOR — ST-40.2 allowed "measured equivalents"

**Location:** `07-testing-strategy.md` ST-40.2.
**Problem:** "or the measured equivalents" let the implementation define the oracle, violating the
immutable-oracle rule.
**Decision:** freeze 000001 and 000101.
**Resolution:** ST-40.2 updated. **Resolved.**

### PF-030 — 🟡 MINOR — The 45 budget assert did not name a stable label

**Location:** `03-lesson-specs.md` §Lesson 45; ST-45.3.
**Problem:** "the last variable" may miss a variable moved to `$F8` if it is not last.
**Decision:** assert a `RamEnd` label at the highest used address against `$F7`.
**Resolution:** 03, AR-21, ST-45.3 updated. **Resolved.**

### PF-031 — 🟡 MINOR — Lesson 46's off-by-one described a "collision box"

**Location:** `03-lesson-specs.md` §Lesson 46.
**Problem:** the TIA has no collision box; collisions are between drawn pixels, and the wall spans
every line.
**Decision:** the bug is the drawn row vs the game-logic Y used for the P0–ball check; the ball is
at Y=140 so the difference is visible.
**Resolution:** 03 and ST-46.3 updated. **Resolved.**

### PF-032 — 🟡 MINOR — Lesson 47's stage/bar/checksum layout did not sum cleanly

**Location:** `03-lesson-specs.md` §Lesson 47.
**Problem:** 80 + 90 + 16 + 6 = 192 was stated but the checksum was 8 lines.
**Decision:** 80 stages + 8 gap + 90 bar + 6 gap + 8 checksum = 192.
**Resolution:** 03 and AR-23 updated. **Resolved.**

### PF-033 — 🔵 OBSERVATION — Lesson 38 starts P0 inside the 16-px wall

**Location:** `03-lesson-specs.md` §Lesson 38.
**Problem:** P0 at X=8 is inside the wall, so the P0–playfield band is lit at reset.
**Decision:** accepted — the wall contact is the lesson's first demonstration; the auto-demo and
the player can leave the wall, and the hit count starts at 1. The doc says so.

### PF-034 — 🔵 OBSERVATION — The plan-level completion gate is not a counted task

**Location:** `99-execution-plan.md` Phase 10.
**Problem:** the completion record was a sub-step of 10.1.1; the 10/10 progress could be reached
without it.
**Decision:** accepted with a `10.1.1a` completion-gate checkbox that must be ticked before 10.1.1
is promoted to `[x]`; the progress script keeps 10 lesson tasks.

## Verification

| Check | Result |
| --- | --- |
| All plan links resolve (the preflight report is created by this file) | pass after this file is added |
| AR rows 1–38, no open item | pass |
| ST cases: 6 per lesson, 60 total | pass |
| Specification-first ordering (Session A freeze → B implement → C verify) | pass |
| Lesson 38/42/44 share scanlines for every claimed collision | pass after PF-001/002 |
| The 48-pixel score's 9-line zone + 183-line game zone | pass after PF-004 |
| `AUDF`/score/BCD/LFSR/memory values within their fields | pass after PF-005/007/008/009/010/021 |
| Every lesson has a prerequisite line | pass after PF-013 |
| Every exercise is an extension or a new scenario | pass after PF-012 |
| Frame budget: 3 + 37 + 192 + 30 = 262; score 9 + 183 = 192; 47 80+8+90+6+8 = 192 | pass |
| The 48-pixel prototype assembled to 4,096 bytes and rendered "123456" in Stella | pass |

## Pass Verdict

**✅ PREFLIGHT PASSED WITH NOTES.** All critical and major findings are resolved; all minor
findings are resolved; the two observations are accepted with their rationale. The plan is ready
for execution after this report and the fixes are committed and the roadmap row is advanced to
`Plan Preflighted`.

## Residual Risks

1. **Game logic is temporal.** The state logs prove the register/RAM values and the frame timing,
   not the player's experience; the committed ROM and `<RomPlayer>` are the runnable artifact. The
   lesson docs disclose this.
2. **The 48-pixel kernel is cycle-tight.** The prototype measured 8 rows at x=367–642; each
   implementation must re-measure the score zone before accepting a capture.
3. **The 38/42/44 geometry is deliberate.** P0 and P1 share scanlines in 42/44; in 38 P0 moves in
   both axes. A later layout change must re-freeze the collision ST rows, not edit them to match.
4. **The exercise/main boundary is explicit.** The main ROM leaves ADD 10/SUB 1 (40), the packed
   flags (45), and the debug border color (47) to the exercises; the reviewers must check that the
   main's operation bar/status still reads honestly.
