# Execution Plan: Part 2 — TV & TIA (Lessons 12–18)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-10-11 01:31
> **Progress**: 4/7 tasks (57%)
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

> **Phase baseline tree**: f38d78ac2127bde9262043c3388d932d019d86e3 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part2-tv-and-tia/13-colors/` (4 sources) · `docs/part2-tv-and-tia/13-colors.md` · `docs/part2-tv-and-tia/index.md` (row 13) · `docs/public/roms/part2-tv-and-tia/13-colors/` · `docs/public/images/lesson13/` · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — palette claims and luminance behavior under independent hardware review

### Step 2.1: Lesson 13 — Colors

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 13 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 13 · AR-2, AR-4, AR-6, AR-9
**Objective**: Deliver lesson 13 end to end through the mandatory three sessions.

- [x] 2.1.1 Lesson 13 — Colors: Session A freezes ST-13.1–ST-13.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson13): Colors` ✅ (completed: 2026-10-10 23:27)

**Session A record** (freeze + red baseline, 2026-10-10 23:12): ST-13.1–ST-13.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 13 — sixteen equal 12-line bands, band k = hue k at the current luminance; the sequence starts at level 7 (brightest), descends one step every 120 frames (~2 s), wraps 7→0→7; the palette byte is `hue × 16 + level × 2` (`%HHHHLLL0`, 16 × 8 = 128 colors); a self-contained course-local named-color table in the lesson doc and the solution (PF-002 Option A), with the names in the table/caption, not on screen (PF-011); screenshots `palette-hues.png` (level 7) and `palette-dim.png` (level 1); solutions: 8 luminance bands of 24 lines cycling hue, the static chart-match table, and a single-band 8-level fade; the explicit counted (WSYNC) frame carried from lesson 12 (PF-007). Red baseline confirmed: no lesson sources, ROMs, or images; the document is still the `🔒 Coming Soon` stub; index row 13 still `🔒 Coming Soon`; `verify.sh` green with the lesson absent (expected — nothing references it yet). No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-10-10): Preflight per `vcs-lesson-production` — palette claims checked against `tia-hardware.md` (`%HHHHLLL0`, luminance 0–7, 128 = 16 × 8), registers against `include/vcs.asm`, ACME forms verified, screenshots planned, no demo (AR-3 reason in [03](03-lesson-specs.md) §Lesson 13), style follows lessons 11–12. `bash scripts/verify.sh` green (ROM drift + docs build); all four sources 4,096 bytes. Frame checkpoints unchanged: `StartFrame` 259 every frame, `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229 (3/37/192/30 over 262 lines). Palette evidence: `LumStep` fires at frames 119, 239, 359 (deltas 120); `Band0Write` walks A = `$0E` → `$0C` → … → `$00` → `$0E` (the full 7→0→7 descent); `BandWrite` shows X = 1…15 with A = `$1E` … `$FE` at level 7 — the byte `hue × 16 + level × 2`, observed live. Screenshots: `palette-hues.png` at level 7 (second appearance, startup badge gone; picture area byte-identical to the first-appearance capture) and `palette-dim.png` at level 1 — cross-proved by band 4 reading `#9E1312`, the exact `$42` rendering from lesson 12's published capture. Solutions pixel-checked: ex 1 eight grey bands 7→0; ex 2 all sixteen named-color bands matching the table byte-for-byte; ex 3 a single red field that brightens between captures. Site (ST-13.6): built page renders with `<RomPlayer>` on the committed ROM, prev/next resolve, index row 13 links the lesson. Reviews: both specialists dispatched on the phase diff (both sessions static — no shell available to them; addresses re-derived by hand and confirmed). Five minor findings (release-line HBLANK ledger wording; three NTSC-unqualified palette claims; band 11's provenance cell; the `Band0Write` wording; the diff/worktree staleness) — all fixed, the diff regenerated, verify green again; no critical or major findings (AR-5).

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-13.1–ST-13.6, including the 16 hue bands, the descending luminance sequence (7→0, wrap), and the 128-color cycle ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 13); record the red baseline. No implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part2-tv-and-tia/13-colors/13-colors.asm` + its three solutions; write `docs/part2-tv-and-tia/13-colors.md`; run `npm run roms`; capture `palette-hues.png` and `palette-dim.png` from the committed ROM path; embed `<RomPlayer>`; update part index row 13 and prev/next (RD-02 AC 1; AR-6, AR-8, AR-9, AR-10).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-13.* confirmed; full-cycle luminance observation; both specialist reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson13): Colors` (AR-12).

---

## Phase 3: Lesson 14 — WSYNC and Timing

> **Phase baseline tree**: 2acef999b77b8ac77d29c2ce6549c2c056179be0 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part2-tv-and-tia/14-wsync-and-timing/` (4 sources) · `docs/part2-tv-and-tia/14-wsync-and-timing.md` · `docs/part2-tv-and-tia/index.md` (row 14) · `docs/public/roms/part2-tv-and-tia/14-wsync-and-timing/` · `docs/public/images/lesson14/` · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — beam-alignment claims are correctness-sensitive under independent hardware review

### Step 3.1: Lesson 14 — WSYNC and Timing

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 14 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 14 · AR-2, AR-4, AR-6
**Objective**: Deliver lesson 14 end to end through the mandatory three sessions.

- [x] 3.1.1 Lesson 14 — WSYNC and Timing: Session A freezes ST-14.1–ST-14.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson14): WSYNC and Timing` ✅ (completed: 2026-10-11 00:15)

**Session A record** (freeze + red baseline, 2026-10-10 23:53): ST-14.1–ST-14.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 14 — the anchored split: 96/96 visible lines, red `$42` above, blue `$84` below, the boundary on visible line 97 (Stella scanline 133); aligned mode writes the boundary color right after the line anchor (static ledger: store at line-cycle 10, HBLANK); late mode deliberately spends 43 cycles between the anchor and the color load (a 38-cycle delay routine around the mode check), landing the store at line-cycle 47 — ≈24.3 CPU cycles into the visible portion (the tear's first blue pixel is 76 — measured), a static tear identical every frame; modes alternate every ~120 frames (aligned: frames 1–119, 240–359, …; late: 120–239, 360–479, …); screenshots `wsync-aligned.png` (clean middle boundary) and `wsync-torn.png` (the tear line), each verified against burst captures; solutions: the split moved by one constant (`TOP_LINES = 64`), the late-mode budget repaired by moving the work before the anchor, and the repaired kernel instrumented with the two-breakpoint ledger check (`BudgetStart`/`BudgetEnd`, 5-cycle critical section). Red baseline confirmed: no lesson sources, ROMs, or images; the document is still the `🔒 Coming Soon` stub; index row 14 still `🔒 Coming Soon`; `verify.sh` green with the lesson absent. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-10-11): Preflight per `vcs-lesson-production` — timing claims checked against `timing.md` (76 cycles per line; HBLANK 68 clocks ≈ 22.7 cycles; visible 160; WSYNC semantics), registers against `include/vcs.asm`, ACME forms, screenshots planned, no demo (AR-3 reason in [03](03-lesson-specs.md) §Lesson 14), style follows lessons 12–13. `bash scripts/verify.sh` green (ROM drift + docs build); all four sources 4,096 bytes. Frame checkpoints unchanged: `StartFrame` 259, `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229 (3/37/192/30, 262 lines). Timing evidence: `TopWrite` logs one hit per line at cycle 11 / pixel −35 — HBLANK, the same position on consecutive lines; the `DEY` right after the store pins the per-line write at cycle 2, well inside HBLANK. `BoundaryWrite` tracks the mode clock: frame 1 cycle 6 / pixel −50 (store cycle 10, HBLANK); frame 120 cycle 43 / pixel +61 (store cycle 47 ≈ 24.3 CPU cycles into the visible portion); frame 240 cycle 6 again. Screenshots: `wsync-aligned.png` — equal 96/96 halves (302 px each), the boundary clean at every sampled column; `wsync-torn.png` — the boundary line's first 76 of 160 pixels red (measured red x 25–480 of the 960 px picture); the store-at-clock-144 arithmetic confirmed in pixels. Bursts: aligned captures 6 s apart pixel-identical; torn captures identical; the modes differ only in the 456×4 tear band (ST-14.2/14.3). Solutions: ex 1 — the split moved to visible line 65 (clean capture; late capture with the 76-pixel tear on visible line 65); ex 2 — clean 96/96 in both sampled windows, pictures identical across them; ex 3 — `BudgetEnd` reads scanline 133, cycle 5 identically in BOTH modes across the flip (frames 118–122): the repair proven live (5 of ~23 HBLANK cycles used). Site (ST-14.6): built page renders with `<RomPlayer>` on the committed ROM, prev/next resolve, index row 14 links the lesson. Reviews: both specialists dispatched on the phase diff (both sessions static — no shell available to them): six minor findings raised and fixed (mode-schedule off-by-one; visible-line numbering; store pixel annotations; ex 2's verification recipe; a typo; the `TopWrite` first-hit entry) plus two recipe notes resolved (ex 3 numeric breakpoint addresses; Stella 7 named as the source of the logged values); no critical or major findings (AR-5).

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-14.1–ST-14.6, including the 96/96 split and the late-mode static tear (≈25 cycles into the visible portion) ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 14); record the red baseline. No implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part2-tv-and-tia/14-wsync-and-timing/14-wsync-and-timing.asm` + its three solutions; write `docs/part2-tv-and-tia/14-wsync-and-timing.md`; run `npm run roms`; capture `wsync-aligned.png` and `wsync-torn.png` from the committed ROM path; embed `<RomPlayer>`; update part index row 14 and prev/next (RD-02 AC 1; AR-6, AR-8, AR-10).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-14.* confirmed; aligned-stability check (same boundary line across sampled frames); both specialist reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson14): WSYNC and Timing` (AR-12).

---

## Phase 4: Lesson 15 — The Timer

> **Phase baseline tree**: 5e7a657907b2cf25d11e1a56ce29aa5e56ac77a0 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part2-tv-and-tia/15-the-timer/` (4 sources) · `docs/part2-tv-and-tia/15-the-timer.md` · `docs/part2-tv-and-tia/index.md` (row 15) · `docs/public/roms/part2-tv-and-tia/15-the-timer/` · `docs/public/images/lesson15/` · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — RIOT-timer budget claims under independent hardware review

### Step 4.1: Lesson 15 — The Timer

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 15 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 15 · AR-2, AR-4, AR-6
**Objective**: Deliver lesson 15 end to end through the mandatory three sessions.

- [x] 4.1.1 Lesson 15 — The Timer: Session A freezes ST-15.1–ST-15.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson15): The Timer` ✅ (completed: 2026-10-11 01:31)

**Session A record** (freeze + red baseline, 2026-10-11 01:11): ST-15.1–ST-15.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 15. Design pins: the frame keeps its shape — VSYNC 3 (WSYNC-counted: the pulse must be exact), VBLANK 37 via `TIM64T` = 44 (the write at line 0 cycle 15 — an absolute 4-cycle `STA`; the timer's first tick lands one cycle after the write — the prescaler restarts full — then every 64; `INTIM` reaches 0 at line 36 cycle 32; the poll and the anchor finish line 36; release at line 37), visible 192 = four equal 48-line bands with per-line anchored writes, overscan 30 via `TIM64T` = 36 (the write at line 229 cycle 16; zero at line 258 cycle 53; VSYNC at line 259) — 262 lines total, the course's standard frame. Correction recorded in Session B (measured in Stella): the spec's original 43/35 — the classic values, whose own note in `include/macro.asm` reads "43 ticks x 64 = 2752 cycles ~ 36 scanlines (use for 37-line VBLANK)" — run one line short (36/29-line blanking, a 260-line frame); 44/36 are the largest values that still expire in lines 36/258; 45/37 overshoot by one line. Hue cadence: n starts at 0 and advances by 1 every 30 frames (steps at frames 30, 60, 90, …; Δ30 ≈ 0.5 s); band hues (n, n+4, n+8, n+12) mod 16 at luminance 7 (`$E`); the per-frame compute (~145 cycles, ~160 on step frames) runs under the timer — the first VBLANK poll must read `INTIM` ≈ 41 (well above 0: the computation fits); the overscan's first poll reads 36. Evidence methods: the poll checkpoint is the `BNE` whose log's A column holds the `INTIM` value just read; the written timer value is read back as the A column of the checkpoint right after `STA TIM64T` (44) and at the overscan wait's first hit (36); the cadence check is `HueStep` firing at Δ30 frames; the screenshot `timer-frame.png` (four equal 48-line bands, stable) plus temporary captures a second apart to show the hues advancing. Red baseline confirmed: no lesson sources, ROMs, or images; the document is still the `🔒 Coming Soon` stub; index row 15 still `🔒 Coming Soon`; `verify.sh` green with the lesson absent. Demo: none — the animation is the timer's visible result (AR-3). No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-10-11 01:22): Preflight per `vcs-lesson-production` — timer claims measured against Stella's 6532 behavior (the prescaler restarts full, so the first decrement lands one cycle after the write; the reviewer corroborated the model against the hardware spec) and checked against `include/macro.asm`'s note (already accurate: 43 ≈ 36 scanlines); the skill references' classic "43/35 for ~37/30" phrasing still describes the nominal arithmetic and is recorded as a follow-up correction (SR-002, phase 4); registers against `include/vcs.asm`; ACME forms; screenshots planned; no demo (AR-3); style follows lessons 12–14. Correction applied in Session B: the spec's original 43/35 give 36/29-line blanking (a 260-line frame — measured); the ROM uses 44/36 for the exact 37/30 lines; the spec, the Session A record, and the findings ledger were amended (SR-001, phase 4). `bash scripts/verify.sh` green (ROM drift + docs build); all four sources 4,096 bytes. Frame checkpoints (main ROM, steady frames): `StartFrame` 259/cycle 3, `VblankStart` 0/cycle 5, `VisibleStart` 37/cycle 5, `OverscanStart` 229/cycle 6 — Lesson 12's frame, 262 lines, undisturbed. Timer evidence: `VblankCompute` logs A = 44 (the value just written to TIM64T) at line 0 cycle 16; `OverscanWait`'s first hit each frame logs A = 36; the VBLANK poll logs the live countdown in A — first read 41 (three ticks spent by the ~150-cycle compute), then 40, 39, …, zero at line 36 cycle 39; the overscan poll likewise — first read 35 (the first tick visible within ~6 cycles of the write), zero at line 258 cycle 57; `BandWrite` logs one hit per line — (37,19) on the release line, then cycle 11 / pixel −35 steady — the same anchor-hold position as Lesson 14. Hue cadence: `HueStep` at frames 30/60/90/120/150 with A = 1/2/3/4/5 (Δ30 ≈ 0.5 s). Screenshots: `timer-frame.png` — four equal 48-line bands (measured runs 150/151/150/151 px), captured at n = 9 (hues 9, 13, 1, 5 = `$9E`/`$DE`/`$1E`/`$5E`); a second (temporary, since deleted) capture ~1 s later shows n = 11 (hues 11, 15, 3, 7) — two steps, exactly on the cadence (ST-15.2). Solutions: ex 1 — `VblankCompute` A = 44, first poll 41, the counted overscan still per-line (`OverscanLines` hits from line 229); ex 2 — `OverscanCompute` A = 36, `HueStep` fires in the overscan (frames 30/60/90/120), first overscan poll 35, VBLANK first poll 41; ex 3 — `VblankCompute` A = 44, `OverscanCompute` A = 36, first polls 42 (VBLANK) and 34 (overscan), overscan zero at line 258 (ST-15.5). Site (ST-15.6): the built page renders with `<RomPlayer>` on the committed ROM, prev/next resolve, index row 15 links the lesson. Reviews: both specialists dispatched on the phase diff (static sessions — no shell available to them); findings applied — SR-001 (43/35→44/36 propagated to the test oracle too), SR-003 (the 4-cycle `STA TIM64T` ledger fix), SR-004…SR-007 (TS comment, macro-note citation, cycle note, diff regenerated); SR-002 (the stale timer notes in the skill references and `include/vcs.asm`) is fixed in a follow-up `chore(skills)` commit in this phase (user-approved at the phase ask).

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-15.1–ST-15.6, including the timer budgets (37-line VBLANK = `TIM64T` 44, 30-line overscan = 36) and the hue cadence ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 15); record the red baseline. No implementation logic read (AR-2).
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
