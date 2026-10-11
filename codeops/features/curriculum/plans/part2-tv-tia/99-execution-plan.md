# Execution Plan: Part 2 — TV & TIA (Lessons 12–18)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-10-11 15:08
> **Progress**: 6/7 tasks (86%)
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

> **Phase baseline tree**: 7f8340d9ac6b82626350e12bfe296b44d2bfd851 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part2-tv-and-tia/16-horizontal-zones/` (4 sources) · `docs/part2-tv-and-tia/16-horizontal-zones.md` · `docs/part2-tv-and-tia/index.md` (row 16) · `docs/public/roms/part2-tv-and-tia/16-horizontal-zones/` · `docs/public/images/lesson16/` · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — zone-boundary geometry under independent hardware review

### Step 5.1: Lesson 16 — Horizontal Zones

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 16 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 16 · AR-2, AR-4, AR-6, AR-9
**Objective**: Deliver lesson 16 end to end through the mandatory three sessions.

- [x] 5.1.1 Lesson 16 — Horizontal Zones: Session A freezes ST-16.1–ST-16.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson16): Horizontal Zones` ✅ (completed: 2026-10-11 09:44)

**Session C record** (verify + evidence, 2026-10-11 09:44): Preflight per `vcs-lesson-production` — zone/timing claims checked against the `atari-2600-expert` references (68-clock HBLANK ≈ 22.7 cycles; entry stores inside HBLANK; per-line repaint at line-cycle 2) and Lessons 12–15's records; registers against `include/vcs.asm`; ACME forms; screenshots planned; no demo (AR-3: the zone structure is the visible picture); style follows Lessons 12–15. Session B self-caught a real defect by pixel verification — the first build's per-line repaint re-stored A after the entry had loaded the height into it, so zone bodies were painted with their height bytes as colors (measured olive/salmon/dark-red bodies with only the entry lines correct); the fix loads the height into Y (`LDY`), keeping the color in A — taught as Theory 4. `bash scripts/verify.sh` green (ROM drift + docs build); all four sources 4,096 bytes. Frame checkpoints (main ROM): `StartFrame` `$F00E` (259, cycle 3), `VblankStart` `$F01C` (0, cycle 5), `VisibleStart` `$F030` (37, cycle 5), `OverscanStart` `$F04A` (229, cycle 8) — Lesson 12's frame, 262 lines. Zone evidence: `ZoneColor` `$F035` fires 4×/frame at (37,11)/(61,13)/(133,13)/(181,13) with A = `$02`/`$84`/`$46`/`$C4` and X = 0/2/4/6; `ZoneHeight` `$F03A` same lines with A = color, X = cursor, Y = `$18`/`$48`/`$30`/`$30` (24/72/48/48 — each entry used exactly once per frame); `ZoneWrite` `$F03D` one hit per line — 188 hits/frame (= 23+71+47+47 = Σ(H−1)), steady (cycle 11, pixel −35), A holding the zone's color on sampled lines 100/150/200 (`$84`/`$46`/`$C4`); polls: first reads 43/35, zeros at (36,35) and (258,59). Screenshot: `zones.png` — runs 74/226/150/151 px ↔ 24/72/48/48 lines; $02→(63,63,62) neutral level 1, $84→(36,40,176) byte-identical to Lesson 12's published blue, $46→(194,61,60) (red level 3, brighter than `$42`), $C4→(40,121,39) (green two levels below `$C8`); 0 of 580,195 picture pixels differ between captures ~6 s apart (stable). Solutions pixel- and log-checked: ex 1 — five zones, sky split 48+24 at `$86` (entries 37/61/109/133/181, Y = `$18`/`$30`/`$18`/`$30`/`$30`, runs 74/150/75/150/151 incl. the new (55,61,193) band); ex 2 — rebalanced 48/96/24/24 (entries 37/85/181/205, Y = `$30`/`$60`/`$18`/`$18`, runs 150/302/75/75); ex 3 — RAM table at `$80–$87` (copy loop: 8 boot-frame-only hits at `CopyTable` `$F010`, X = 0..7; runtime entries identical, read from RAM), plus a labeled, deleted scratch witness (AR-6) proving the live-edit path on the corrected total-preserving recipe (`$82=$30`, `$84=$60`, `$86=$18` at frame 60): frame 59 pre-flip 37/61/133/181 (Y `$18`/`$48`/`$30`/`$30`), frame 60 post-flip 37/61/109/205 (Y `$18`/`$30`/`$60`/`$18`), capture 74/150/302/75 px — the horizon takes 24 lines from each neighbour, the frame stays 262. Site (ST-16.6): built page renders with `<RomPlayer>` on the committed ROM, `zones.png` present, prev/next resolve to 15/17, index row 16 ✅ Complete. Reviews (AR-5): both specialists dispatched on the phase diff (both static; the parent ran all gates/logs/pixel checks; the atari reviewer re-derived the committed ROM bytes independently) — round 1: 2 majors (intro premise vs Lessons 12/13/15, both reviewers; ex-3's live-edit recipe breaking the 192 total) + 6 minors (overscan addresses `$F04B`/`$F057` → `$F04A`/`$F056`; 69→68 color clocks; ex-2 hint arithmetic; height ≥ 2 contract; inline span; Theory 4 color names), 2 info accepted (AR-9 vocabulary; prev/next one-way until L17) + the ex-1 header quote nit — all fixed; the bounded fix-scoped re-review (both) confirmed every fix with no regressions; the auditor's out-of-scope follow-up (Lesson 15's "What's Next") is fixed in a follow-up `fix(lesson15)` commit. No critical/major findings remain (AR-5).

**Session A record** (freeze + red baseline, 2026-10-11 09:10): ST-16.1–ST-16.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 16. Design pins: the frame is the course standard — VSYNC 3 (WSYNC-counted), VBLANK 37 (`TIM64T` = 44), visible 192, overscan 30 (36), 262 lines, the timer windows kept explicit as in Lesson 15; the visible 192 is painted as four zones of 24/72/48/48 lines with colors `$02` (dark, the scoreboard area), `$84` (blue sky), `$46` (dark red horizon), `$C4` (dim green ground) top to bottom, driven by an interleaved 4-entry ROM table (height/color pairs, walked as byte offsets 0/2/4/6); the release line is inside zone 0, so the cumulative painted boundaries are 24/96/144/192 (zone starts predicted at Stella lines 37/61/133/181 — Session C measures); a per-zone anchor `WSYNC` parks each zone's last line (Lessons 14–15's discipline); each table entry is used exactly once per frame (ST-16.4). Exercise pins: exercise 1 splits the **sky** into two bands — 24/48/24/48/48 (`$84` then `$86`), total 192, the paint loop untouched but for the table (the spec's parenthetical example describes a ground split; the prose action is taken as the requirement — AR-13 (runtime)); exercise 2 rebalances to 48/96/24/24 (same four colors, total 192); exercise 3 moves the table into RAM at `$80–$87` (ROM copy at boot) so boundaries can be edited live in the debugger. Evidence pins (AR-6): frame checkpoints (259/0/37/229); `ZoneHeight`/`ZoneColor` breakpoints (A = 24/72/48/48 and `$02`/`$84`/`$46`/`$C4`, once per zone); `ZoneWrite` (one hit per line at the steady HBLANK position); a static cycle ledger for the zone-entry stores and the paint loop; screenshot `zones.png` with measured pixel runs (predicted ≈ 76/226/151/151 px for 24/72/48/48). Red baseline confirmed: no lesson sources, ROMs, or images; the document is still the `🔒 Coming Soon` stub; index row 16 still `🔒 Coming Soon`; sidebar entry exists (`config.ts:63`); `verify.sh` green with the lesson absent (expected — nothing references it yet). No implementation logic read (AR-2).

**Session sub-steps (the task's checklist):**

1. **Session A — freeze the specification (red phase):** re-affirm ST-16.1–ST-16.6, including the 24/72/48/48 zone table and its cumulative boundary lines ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 16); record the red baseline. No implementation logic read (AR-2).
2. **Session B — implement:** preflight per `vcs-lesson-production`; author `lessons/part2-tv-and-tia/16-horizontal-zones/16-horizontal-zones.asm` + its three solutions; write `docs/part2-tv-and-tia/16-horizontal-zones.md`; run `npm run roms`; capture `zones.png` from the committed ROM path; embed `<RomPlayer>`; update part index row 16 and prev/next (RD-02 AC 1; AR-6, AR-8, AR-9, AR-10).
3. **Session C — green phase, implementation checks & hardening:** `bash scripts/verify.sh` green; all ST-16.* confirmed; zone-boundary scanline check; both specialist reviews report no critical/major findings (AR-4, AR-5, AR-6).

**Verify**: `bash scripts/verify.sh`

**Commit**: `git-commit` skill in push mode — `feat(lesson16): Horizontal Zones` (AR-12).

---

## Phase 6: Lesson 17 — Cycle Counting

> **Phase baseline tree**: 723d13db0429b972018bdda1cdae5c68c70fbb90 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part2-tv-and-tia/17-cycle-counting/` (4 sources) · `docs/part2-tv-and-tia/17-cycle-counting.md` · `docs/part2-tv-and-tia/index.md` (row 17) · `docs/public/roms/part2-tv-and-tia/17-cycle-counting/` · `docs/public/images/lesson17/` · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — hand-counted cycle budgets are the highest-verification-risk content in Part 2

### Step 6.1: Lesson 17 — Cycle Counting

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 17 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 17 · AR-2, AR-4, AR-6
**Objective**: Deliver lesson 17 end to end through the mandatory three sessions.

- [x] 6.1.1 Lesson 17 — Cycle Counting: Session A freezes ST-17.1–ST-17.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson17): Cycle Counting` ✅ (completed: 2026-10-11 15:08)

**Session C record** (verify + evidence, 2026-10-11 15:08): Preflight per `vcs-lesson-production` — the lesson's claims (76-cycle instruction costs, the HBLANK budget, the page-crossing +1, branch parity) checked against the `atari-2600-expert` references and Lessons 12–16's records; registers against `include/vcs.asm`; ACME forms; no demo (AR-3: the ruler visualizes directly); style follows Lessons 12–16. `bash scripts/verify.sh` green (ROM drift + docs build); all four sources 4,096 bytes; the ramp page-aligned (`ColorRamp = $F100`, max read `$F15F` — the constant-cycle S1Tick positively proves no `abs,X` +1 fired). Frame: **270 lines** (`StartFrame` `$F00E` = (267, 3) every frame); `VblankStart` (0,5), `VisibleStart` (37,5), `OverscanStart` `$F089` (236,51). Section 1: `S1Tick` `$F037` — 96 hits/frame at lines 37..132, **every hit at cycle 14** (constant → aligned), X = 0..95, A = the hue just written; consecutive hits 76 cycles apart. Junction: `Section2Start` `$F05B` = (133, 6), A = `$FE`; section 2's first write in HBLANK (line 133 shows no sliver). Section 2: `S2Tick` `$F062` — 96 hits, first (133, 15), in-line cycle +6 per hit, the line advancing 1 (or 2 at a skip, seven times), last (235, 53); 96 hits over 103 lines; consecutive hits **82 cycles apart**. Polls: first reads 43/35 (`$2B`/`$23`), zeros at (36,35) and (266,26). Screenshot `cycle-ruler.png`: section 1 = rows 107–408 (302 px = exactly 96 lines) as 16 bands ≈19 px (the 16 luminance-7 hues, `$0E`..`$FE`, in wheel order); section 2 = rows 410–736 (326 px ≈ 103.6 lines); the twelve visible hue-transition notches measured at x = 535/463/391/319/967/247/895/175/823/103/751/31 — each predicted by x = 25 + (3·hit − 68)·6 from hit cycles 51/47/43/39/75/35/71/31/67/27/63/23 (three further hue changes land in HBLANK, clean); 0 of 604,170 pixels differ across captures ~6 s apart. Solutions: ex 1 — drill = **54 cycles/pass**, breakpoint gap pattern five-cycles ×9 then nine (measured at `$F010`); ex 2 — trimmed: `StartFrame` (259,3) → frame back to exactly **262**, `S2Tick` 96 hits all at cycle 15, last (228,15); ex 3 — full ledger, `Section1End` = `Section2Start` = `$F05B` (documented), recipes literal-address. Site (ST-17.6): built page renders with `<RomPlayer>` on the committed ROM, `cycle-ruler.png` present, prev/next resolve (16↔18), index row 17 ✅ Complete, README unchanged ("TV & TIA | 12–18"). Reviews (AR-5): both specialists on the phase diff (static; parent ran all gates/logs/pixels) — round 1: **1 major** (\"one color clock\" — one CPU cycle is three color clocks) + 6 minors (S2Tick hit semantics; wrap count; the +36-cycle/≈72-px slip; stale predicted figures ~269/~266/7,872/7,873/577; placeholder breakpoint addresses; wording: notch basis = hit cycles, \"little delay loop\", captured-image pixels, ≈19 px) + 1 info (the `!align 255, 0` query — verified page-safe) — all fixed; the bounded re-review (both, fix-scoped) confirmed every fix but raised **one new major** — the fix pass had inverted the padding fact (\"could be padded away with one more instruction\" is false: no 1-cycle instruction exists; padding steps by two) — restated as the parity framing (\"padding cannot close it\"), plus residue (ex-3 inline tick wording, the 7,295-vs-7,297 phrasing, the takeaway's \"write cycles\") — corrected in a final pass; per the bounded policy no third round was run; **AR-14 amended** (the \"unreachable\" phrasing scoped: straight padding cannot land on 7,296 — a reshaped loop could; the ROM keeps the simple shape and leaves the cycle to HBLANK). No critical findings remain; round 2 reported no rule or hardware regressions.

**Session A record** (freeze + red baseline, 2026-10-11 14:50): ST-17.1–ST-17.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 17. Design pins: the frame keeps the course skeleton (VSYNC 3 WSYNC-counted; VBLANK 37 on `TIM64T` = 44; overscan 30 on 36); the visible is a two-section "cycle ruler": **section 1** — `LDA ColorRamp,X` (4) + `STA COLUBK` (3) + 31 × `NOP` (62) + `INX` (2) + `CPX #96` (2) + `BNE` (3) = **76 cycles** per iteration, X = 0..95 over a 96-byte ramp table (16 hues at luminance 7 — `$0E`…`$FE`, each hue six times; the table page-aligned so the `abs,X` read never crosses a page — no +1 penalty); no `WSYNC` inside the loops — the release anchor plus the fixed prologue align section 1 at its start. **Section 2** — the same loop with +3 `NOP`s (68-cycle pad) = **82 cycles** per iteration; 96 iterations = 95×82 + 81 = **7,871 cycles ≈ 103.6 lines** (stretch ≈ 7.6 ≈ 8 lines; frame predicted ≈ 269 — measured in Session C). **Junction pin (AR-14):** section 1's loop = 95×76 + 75 = 7,295 cycles; the exit's spare cycle (BNE not-taken parity — prologue + loop is odd, no instruction mix lands exactly on 7,296) chains directly into section 2's prologue (no WSYNC), so section 2's first write lands in the next line's HBLANK: the 16 × 6-line cadence and the section boundary stay exact, and the staircase develops from the +6 drift. Evidence pins (AR-6): frame checkpoints (`StartFrame` ≈ line 266 — the grown frame; `VblankStart`; `VblankPoll`; `VisibleStart`; `OverscanStart`; `OverscanPoll`); `S1Tick`/`S2Tick` (post-`STA COLUBK`): S1Tick one hit per line at a constant in-line cycle for all 96 lines; S2Tick's consecutive hits 82 cycles apart with the in-line position +6 per line; capture `cycle-ruler.png` — the 16 bands (≈19 px each), the exact junction, and the section-2 sliver staircase. Exercises: ex 1 — the drill snippet (`LDY #$0A` / `DEY` / `BNE` / `JMP` back: 54 cycles per pass = 2 + 9×5 + 4 + 3; breakpoint gap pattern: nine short gaps + one long) hand-counted in the document then verified with breakpoints; ex 2 — section 2 trimmed to 76 (pad back to 62): both sections stable, drift gone, frame back to the textbook 262; ex 3 — full ledger header plus junction checkpoints (`Section1End`/`Section2Start`) proving the spare cycle and the carried phase. Red baseline confirmed: no lesson sources, ROMs, or images; the document is still the `🔒 Coming Soon` stub; index row 17 still `🔒 Coming Soon`; sidebar entry exists (`config.ts:64`); `verify.sh` green with the lesson absent. No implementation logic read (AR-2).

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
