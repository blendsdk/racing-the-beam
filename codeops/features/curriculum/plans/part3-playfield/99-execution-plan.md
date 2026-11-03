# Execution Plan: Part 3 — Playfield (Lessons 19–24)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-04 00:38
> **Progress**: 6/6 tasks (100%)
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

> **Phase baseline tree**: aaf197a39af45f9c204c50a1301fa11b7d6dd050 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part3-playfield/20-playfield-colors/` (4 sources) · `docs/part3-playfield/20-playfield-colors.md` · `docs/part3-playfield/index.md` (row 20) · `docs/public/roms/part3-playfield/20-playfield-colors/` · `docs/public/images/lesson20/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — score-mode color routing and the priority boundary under independent hardware review

### Step 2.1: Lesson 20 — Playfield Colors and Priority

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 20 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 20 · AR-2, AR-4, AR-6, AR-14
**Objective**: Deliver lesson 20 end to end through the mandatory three sessions.

- [x] 2.1.1 Lesson 20 — Playfield Colors and Priority: Session A freezes ST-20.1–ST-20.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson20): Playfield Colors and Priority` ✅ (completed: 2026-11-03 23:08)

**Session A record** (freeze + red baseline, 2026-11-03 22:56): ST-20.1–ST-20.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 20. Design pins: the standard 262-line frame. The wall is `PF0=$F0` (chunks 0-3 on), `PF1=$FF` (4-11 on), `PF2=$3F` (bits 6-7 clear: chunks 18-19 off; reflect mirrors the gap across chunks 20-21), giving a central 4-chunk gap at **x = 457-553**. Colors: `COLUPF=$C8` green, `COLUBK=$02`; `COLUP0=$42` red, `COLUP1=$84` blue. State 0 (frames 1-119): `CTRLPF=$01` (reflect, normal color) — a green wall with a dark gap, transitions at **25 (green), 457 (dark), 553 (green)**. State 1 (frames 120-239): `CTRLPF=$03` (reflect + `SCORE`) — the playfield's left half takes `COLUP0` red and the right half `COLUP1` blue, gap dark, transitions **25 (red), 457 (dark), 553 (blue)**. The flip is the same 120-frame counter as Lesson 19. Captures `single-color.png` (~1 s) and `score-mode.png` (~3 s). Priority is taught as a table (P0/M0 > P1/M1 > PF/BL > BK; `PFP` bit 2 lifts PF/BL) with an explicit name-only note that its visible effect needs a player/ball in Part 4 (AR-14); the ROM writes only `REF`/`SCORE`. Evidence pins (AR-6): frame checkpoints (`StartFrame` 259, `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229) and `CtrlWrite` — one hit per frame, A = `$01`/`$03`, first change at frame 120. Solutions: ex 1 swaps the score colors (`COLUP0=$84`, `COLUP1=$42` — left blue, right red); ex 2 opens PF1 gaps (`PF1=$CC`) with `COLUBK=$1A` gold and score mode always on (red/blue blocks separated by gold); ex 3 splits the frame at line 133 — top 96 lines score mode (red|blue), bottom 96 normal green — by changing `CTRLPF` at the half boundary. Red baseline confirmed: no lesson sources, ROMs, or images; the document is still the `🔒 Coming Soon` stub; index row 20 is Coming Soon; sidebar entry exists (`config.ts:73`); `verify.sh` green with the lesson absent. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-11-03 23:08): Preflight per `vcs-lesson-production` — the palette bytes checked against Lesson 13's table (`$C8` green, `$42` red, `$84` blue, `$1A` gold, `$02` dark), score-mode routing against `include/vcs.asm`/`tia-hardware.md` (left half `COLUP0`, right half `COLUP1`), the priority table against `tia-hardware.md` §Priority, the `PF2=$3F` bit order against the Lesson 19 rule (bit 0 leftmost → chunks 18–19 off, mirrored 20–21), the frame against Lessons 12–19, ACME forms; no demo (AR-3: the color split is the visible picture); style follows Lessons 12–19. `bash scripts/verify.sh` green (implementation, post-fix, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F00E` = (259, 3), `VblankStart` `$F01C` = (0, 5), `VisibleStart` `$F06C` = (37, 7), `OverscanStart` `$F071` = (229, 4). Mode: `CtrlWrite` `$F043` one hit per frame; A = `$01` frames 1–119, `$03` 120–239, `$01` 240–359, `$03` 360–479, `$01` 480–599, `$03` 600– (flips at 120/240/360/480/600). Captures from the committed ROM: `single-color.png` transitions x = 457 (green→dark), 553 (dark→green), left pixel green `$C8`; `score-mode.png` transitions 457 (red→dark), 553 (dark→blue), left pixel red `$42`, right blue `$84`; picture rows 107–711 = all 192 lines; repeats of each state differ in 0 px; the two states differ in 522,720 px. Solutions: ex 1 — blue left `$84`, red right `$42`, gap 457–552; ex 2 — transitions 169/217/265/313/457/553/697/745/793/841 with gold `$1A` in every gap, red left and blue right; ex 3 — `TopMode` (37, 12) A = `$03`, `BottomMode` (133, 11) A = `$01`; top sample red|blue, bottom sample green. Site (ST-20.6): index row 20 ✅ Complete, built page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 19, next → 21; README unchanged ("3 | Playfield | 19–24"). Reviews (AR-5): both specialists on the phase diff (static; the parent ran all builds/logs/captures) — round 1: **0 critical, 0 major**, 5 minor: the phantom `VisibleStart` in exercise 3 (label added), the gap's inclusive-range convention (now 457–552 / 96 px, with transitions at 457 and 553), the TypeScript lead-in overstating priority (now score-mode decision), the spec's exercise-3 "line 96" drift (now scanline 133, two loops), and the plan's stale header timestamp. All fixed; no re-review required (no critical/major). The capture OSD below the picture in `single-color.png` is accepted (it does not cover the picture; the same launch toast appears in Lesson 19's capture). Lesson 20 is complete.

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

> **Phase baseline tree**: f9b2783384145f1d34014be1d57cd38cdf52b4d2 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part3-playfield/21-asymmetric-playfield/` (4 sources) · `docs/part3-playfield/21-asymmetric-playfield.md` · `docs/part3-playfield/index.md` (row 21) · `docs/public/roms/part3-playfield/21-asymmetric-playfield/` · `docs/public/images/lesson21/` (1 capture) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — the part's highest-risk claim: mid-line PF writes must change only the right half, measured under independent hardware review

### Step 3.1: Lesson 21 — Asymmetric Playfield

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 21 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 21 · AR-2, AR-4, AR-6, AR-13
**Objective**: Deliver lesson 21 end to end through the mandatory three sessions, with the
mid-line write windows measured before the lesson counts as done.

- [x] 3.1.1 Lesson 21 — Asymmetric Playfield: Session A freezes ST-21.1–ST-21.6 (red baseline) and the six pinned write cycles, Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson21): Asymmetric Playfield` ✅ (completed: 2026-11-03 23:18)

**Session A record** (freeze + red baseline, 2026-11-03 23:08): ST-21.1–ST-21.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 21. Design pins: the standard 262-line frame. Repeat mode (`CTRLPF=$00`). Left half `LEFT0=$F0` (chunks 0-3 on), `LEFT1=$FF` (4-11 on), `LEFT2=$3F` (bits 6-7 clear → chunks 18-19 off; **not** `$FC`, which would clear chunks 12-13); right half `RIGHT0=$00` (chunks 20-23 off), `RIGHT1=$AA` (24/26/28/30 on, 25/27/29/31 off), `RIGHT2=$55` (32/34/36/38 on, 33/35/37/39 off). `COLUPF=$C8`, `COLUBK=$02`. The per-line body is entered at **cycle 5** (the release's 5 cycles equal the steady-state `DEX`+`BNE`): left writes at hit cycles **10/15/20** (effects at clocks 30/45/60, before the left slots at 68/84/116), then NOP×5; right writes at hit cycles **35/46/57** (effects at clocks 105/138/171, after the left slots and before the right slots at 148/164/196); `STA WSYNC` at 57-59 (write 59, park 60-75). Expected picture: on from x = 25; transitions at **457 (off), 601 (on), 625 (off), 649 (on), 673 (off), 697 (on), 721 (off), 745 (on), 769 (off), 793 (on), 817 (off), 841 (on), 865 (off), 889 (on), 913 (off), 937 (on), 961 (off)**. Captures `asymmetric.png`. Evidence pins (AR-6): frame checkpoints (`StartFrame` 259, `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229) and six write checkpoints `Left0`/`Left1`/`Left2`/`Right0`/`Right1`/`Right2` at hit cycles 10/15/20/35/46/57, 192 hits per frame each; the right-half hits must show the left half unchanged. Exercises: ex 1 `LEFT2=$0F` (chunks 16-19 off) and `RIGHT0=$F0` (right half starts solid) — a 4-chunk doorway on the left of centre; ex 2 mirror the left in reflect mode and skip the mid-line rewrite; ex 3 two 96-line bands with different left/right pairs (no pad; the top band's first line starts at cycle 7, the bottom's at 6, every later line at 5; the margins absorb the shift). Red baseline confirmed: no lesson sources, ROMs, or images; the document is still the `🔒 Coming Soon` stub; index row 21 is Coming Soon; sidebar entry exists (`config.ts:74`); `verify.sh` green with the lesson absent. No implementation logic read (AR-2). The spec's initial `LEFT2=$FC` and the first transition list were corrected to `$3F` and the measured parity before implementation.

**Session C record** (verify + evidence, 2026-11-03 23:18): Preflight per `vcs-lesson-production` — the mid-line re-read model and the slot map checked against `atari-2600-expert/references/kernels.md` §Asymmetric playfield and the measured pixels; the hit-cycle rule against Lesson 18; the six windows against the instruction ledger; the frame against Lessons 12–20; ACME forms; no demo (AR-3: the asymmetric halves are the visible picture); style follows Lessons 12–20. `bash scripts/verify.sh` green (implementation, post-fix, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F00E` = (259, 3), `VblankStart` `$F01C` = (0, 5), `VisibleStart` `$F03E` = (37, 5), `OverscanStart` `$F066` = (229, 4). **The six write ticks** (AR-13, the phase's measurement gate): `Left0` `$F042` (37, **10**) A = `$F0`; `Left1` `$F046` (37, **15**) A = `$FF`; `Left2` `$F04A` (37, **20**) A = `$3F`; `Right0` `$F053` (37, **35**) A = `$00`; `Right1` `$F05A` (37, **46**) A = `$AA`; `Right2` `$F061` (37, **57**) A = `$55` — each 192 hits per frame at one unique cycle. The effects at clocks 30/45/60 and 105/138/171 sit inside the windows; the capture proves the left half is unchanged. Capture from the committed ROM (`asymmetric.png`): on from x = 25, transitions at 457 (dark), 601 (green), 625, 649, 673, 697, 721, 745, 769, 793, 817, 841, 865, 889, 913, 937, 961 (dark); the last chunk is off. Solutions: ex 1 — transitions 409 (dark), 505 (green), 625 (dark), 649, … 961; ex 2 — symmetric gap 457/553; ex 3 — top band matches the main, bottom band transitions 169/217/265/313/457/505/649/697/745/841/937. Site (ST-21.6): index row 21 ✅ Complete, built page renders with `<RomPlayer>` on the committed ROM, the capture, prev → 20, next → 22; README unchanged. Reviews (AR-5): both specialists on the phase diff (static; the parent ran all builds/logs/captures) — round 1: **0 critical, 0 major**, 7 minor: the margin numbers (43/26/25 clocks, not 30–40), the slot table being repeat-mode only (reflect order now noted), the mixed sampling wording, the `$55` bitstring shown in byte order, exercise 1's "stripes start at 601" (625), exercise 3's first-line cycles (top 7 / bottom 6, not both 7), exercise 3's "solid right half" (now its own stripe pair), the prerequisite attribution, the gap range notation (457–600, 144 px), and the plan's non-existent 3-cycle pad. All fixed; no re-review required (no critical/major). Lesson 21 is complete — the part's highest-risk claim is measured and holds.

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

> **Phase baseline tree**: f7c3a702e7eb48d31245da0a5d1781478dcddf7f (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part3-playfield/22-playfield-animation/` (4 sources) · `docs/part3-playfield/22-playfield-animation.md` · `docs/part3-playfield/index.md` (row 22) · `docs/public/roms/part3-playfield/22-playfield-animation/` · `docs/public/images/lesson22/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: medium — a frame-level state machine reusing the hold kernel; the capture timing is the main risk

### Step 4.1: Lesson 22 — Playfield Animation

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 22 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 22 · AR-2, AR-4, AR-6, AR-17
**Objective**: Deliver lesson 22 end to end through the mandatory three sessions.

- [x] 4.1.1 Lesson 22 — Playfield Animation: Session A freezes ST-22.1–ST-22.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson22): Playfield Animation` ✅ (completed: 2026-11-03 23:33)

**Session A record** (freeze + red baseline, 2026-11-03 23:24): ST-22.1–ST-22.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 22. Design pins: the standard 262-line frame. Symmetric portcullis in reflect mode (`CTRLPF=$01`): `PF0=$F0`, `PF1=$FF`, `PF2=GateTable[state]`, `COLUPF=$C8`, `COLUBK=$02`. `GateTable` = `$FF, $7F, $3F, $1F, $0F, $07, $03, $01, $00` — state 0 closed, state 8 fully open (PF2 all zero; reflect mirrors, so the gap is 16 chunks, chunks 12-27, x = 313-696, 384 px; transitions at 313 and 697). State k opens 2k chunks; the gap spans **x = 505 - 24k … 505 + 24k - 1**, so state 1 is 48 px and state 8 is 384 px (x = 313-696; transitions at 313 and 697). The state steps once every **30 frames** (~0.5 s), ascending 0→8 then descending; the direction byte is `$01`/`$FF`, reversing at the ends. All state changes happen in VBLANK; the visible kernel is the 192-line hold. Captures: `gate-opening.png` (~1 s; state 1-2) and `gate-open.png` (~4.3 s; state 8, frames 240-269), classified by the measured gap width. Evidence pins (AR-6): frame checkpoints (`StartFrame` 259, `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229); `GateStep` — one hit per 30 frames, A = the new state (sequence 1..8, 7..0); `PF2Write` — A = `GateTable[state]`. Exercises: ex 1 cadence 15 or 60 frames; ex 2 one-sided gate (repeat mode + the L21 mid-line kernel, right-half PF0 chunks 20-23 animated, left wall closed); ex 3 a scrolling wall from a 20-entry table of shifted patterns, repeat mode, one entry every 10 frames. Red baseline confirmed: no lesson sources, ROMs, or images; the document is still the `🔒 Coming Soon` stub; index row 22 is Coming Soon; sidebar entry exists (`config.ts:75`); `verify.sh` green with the lesson absent. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-11-03 23:33): Preflight per `vcs-lesson-production` — the state machine and gate table checked against the Lesson 19 bit-order rule, the frame against Lessons 12–21, the hold kernel against Lessons 19–20, ACME forms; no demo (AR-3: the gate animation is the visible picture); style follows Lessons 12–21. `bash scripts/verify.sh` green (implementation, post-fix, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F012` = (259, 3), `VblankStart` `$F020` = (0, 5), `VisibleStart` `$F077` = (37, 5), `OverscanStart` `$F07C` = (229, 4). State machine: `GateStep` `$F03C` hits at frames 30/60/90/120/150/180/210/240 with A = 1/2/3/4/5/6/7/8, then 270 A = 7, 300 A = 6 … — one step per 30 frames, reversing at the ends; `PF2Write` `$F056` one hit per frame, A = `$FF` through frame 29, `$7F` at 30–59, `$3F` at 60–89, …, `$00` at 240–269, `$01` at 270. The full open-close cycle is **8 seconds** (16 steps × 0.5 s). Captures from the committed ROM: `gate-opening.png` at ~1 s — a 48-px gap x = 481–528 (state 1); `gate-open.png` at ~4.6 s — a 384-px gap x = 313–696 (state 8, transitions at 313 and 697); colours green `$C8` rgb(81,179,80), dark `$02` rgb(63,63,62). Solutions: ex 1 — the 15-frame cadence (captures at 1.0/1.8 s show different widths); ex 2 — repeat mode + the L21 kernel, the right-side doorway at x = 505–576 at state 3 with the left wall unchanged; ex 3 — repeat mode, the 20-entry rotation table, one step every 10 frames; captures at 1.10/1.28 s shift every transition by exactly 24 px. Site (ST-22.6): index row 22 ✅ Complete, built page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 21, next → 23; README unchanged. Reviews (AR-5): both specialists on the phase diff (static; the parent ran all builds/logs/captures) — round 1: **0 critical, 2 major**, 7 minor. The majors: the open-close cycle was documented as 9 s (it is 8 s; exercise 1 is 4 s), and exercise 3's reflect-mode scroll moved the halves in opposite directions (and its 8-entry table jumped at the wrap). Fixed: the cycle is 8 s everywhere; exercise 3 now uses repeat mode and all 20 rotations, one step every 10 frames, seam-free. The minors fixed: `FrameCounter` 1–30, `BNE` not `BEQ`, the intro no longer contradicts Lesson 21's per-line rewrites, the state-8 range 313–696 with transitions at 313/697, the ex3 spec/ST now describe the table/10-frame design, the base pattern is a crenellated pattern (not the solid lesson wall), the TS reducer's frame-0 phase, and the Session A pins (right-half PF0, state 8 frames 240–269). Bounded re-review (round 2): **0 critical, 0 major**; four residual text drifts fixed (the `FrameCounter` bullet, the spec formula's `− 1`, exercise 2's 505–600 / 96 px, the base pattern's on-screen-order note). No third review required. Lesson 22 is complete.

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

> **Phase baseline tree**: cf2f180 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part3-playfield/23-data-driven-playfield/` (4 sources) · `docs/part3-playfield/23-data-driven-playfield.md` · `docs/part3-playfield/index.md` (row 23) · `docs/public/roms/part3-playfield/23-data-driven-playfield/` · `docs/public/images/lesson23/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — the one-line table kernel and the 4K data budget are correctness-sensitive under independent review

### Step 5.1: Lesson 23 — Data-Driven Playfield

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 23 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 23 · AR-2, AR-4, AR-6, AR-15
**Objective**: Deliver lesson 23 end to end through the mandatory three sessions.

- [x] 5.1.1 Lesson 23 — Data-Driven Playfield: Session A freezes ST-23.1–ST-23.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson23): Data-Driven Playfield` ✅ (completed: 2026-11-04 00:05)

**Session A record** (freeze + red baseline, 2026-11-03 23:45): ST-23.1–ST-23.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 23. Design pins: the standard 262-line frame. A one-line kernel with 192 rows and **three parallel 192-byte tables per level** (`Level1PF0/1/2`, `Level2PF0/1/2`), read through `Ptr0/Ptr1/Ptr2` with `Y = row`; 576 bytes per level, 1,152 bytes of data. The per-line body is entered at cycle 5 (the release's 5 cycles and the steady-state `DEX`+`BNE`); the row is stored from `Tmp0/1/2` (18 cycles, effects at clocks 33/51/69, before the slots at 68/84/116), `INY` + prefetch of the next row (26 cycles), `STA WSYNC` (3), `DEX`/`BNE` (5) = **52-55 of 76 cycles** (a page-crossing `(zp),Y` read adds 1; `WSYNC` absorbs it). Level 1 divider at rows 93-95 (scanlines 130-132, measured), Level 2 divider at rows 61-63 (scanlines 98-100); the level switches every **240 frames** (~4 s) by reloading the three pointers in VBLANK. Captures `level1.png` (~1 s) and `level2.png` (~5 s). Evidence pins (AR-6): frame checkpoints (`StartFrame` 259, `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229); `LevelSwitch` at frames 240/480 with A = 1/0; `RowStore` 192 hits/frame at cycle 23, A = the PF2 byte, with the divider rows at `$3F` (level 1 scanlines 130-132; level 2 scanlines 98-100). Exercises: ex 1 a third level table and a three-way selector; ex 2 move the divider/doorway; ex 3 a 2-line kernel (96 rows, each shown twice) using the top half of the level. Red baseline confirmed: the Lesson 23 sources/data were not present at the phase start; the document is still the `🔒 Coming Soon` stub; index row 23 is Coming Soon; sidebar entry exists (`config.ts:76`); `verify.sh` green at `cf2f180`. No implementation logic read (the design was fixed in the spec; AR-2 is satisfied for the plan's freeze).

**Session C record** (verify + evidence, 2026-11-04 00:05): Preflight per `vcs-lesson-production` — the row tables checked byte-for-byte (six tables of exactly 192 bytes), the pointers and preload, the one-line ledger (stores 5-22; effects at clocks 33/51/69, before the slots at 68/84/116; prefetch 25-48; WSYNC 49-51; DEX/BNE 0-4; **52-55 cycles** with the `(zp),Y` page-cross +1 absorbed by WSYNC), the frame against Lessons 12-22, ACME forms; no demo (AR-3: the two mazes are the visible picture); style follows Lessons 12-22. `bash scripts/verify.sh` green (implementation, post-fix, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F00E` = (259, 3), `VblankStart` `$F01C` = (0, 5), `VisibleStart` `$F095` = (37, 5), `OverscanStart` `$F0B3` = (229, 4). Levels: `LevelSwitch` `$F035` at frames 240 (A=1) and 480 (A=0). Rows: `RowStore` `$F0A1` — 192 hits in frame 1, all at cycle 23; Level 1's divider `PF2=$3F` on scanlines 130-132 (rows 93-95); at frame 300 (Level 2) on scanlines 98-100 (rows 61-63). Captures from the committed ROM: `level1.png` divider at capture y=400 (scanlines 130-132), `level2.png` at y=299 (98-100); repeats of each level differ in 0 px; the two levels differ in 112,464 px; green rgb(81,179,80), dark rgb(63,63,62). Solutions: ex 1 — `LevelSwitch` at frames 240/480/720 with A=1/2/0; a ~9 s capture shows Level 3's divider at y≈200 (rows 30-32, scanlines 67-69); ex 2 — `RowStore` `PF2=$0F` at scanlines 82-84 (divider moved to rows 45-47); Level 2 unchanged; ex 3 — `RowStore` 96 hits/frame at scanlines 37, 39, 41, …, the 2-line kernel. The exercise tables were regenerated to match the lesson ROM exactly for the unchanged levels (ex1 L1/L2, ex2 L2, ex3 L1/L2 byte-identical), and the regenerated ROMs re-measured. Site (ST-23.6): index row 23 ✅ Complete, built page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 22, next → 24; README unchanged. Reviews (AR-5): both specialists on the phase diff (static; the parent ran all builds/logs/captures) — round 1: **0 critical, 2 major**, 6 minor. The majors: the per-line ledger ignored the `(zp),Y` page-cross +1 (the body is 52-55, not 52), and the testing strategy still pinned the old divider rows (96-99/64-67) and a 56-cycle total. Fixed: 52-55 everywhere with the `WSYNC` absorption note; ST-23.2/23.3/23.4 now 93-95/61-63/52-55. The minors fixed: the exercise tables' data drift (regenerated from the lesson's exact tables), AR-15's arithmetic (`18+2+24+3+5=52`), the spec ledger row (`5-22`), the Session A effect clocks (33/51/69), the ex1 `Level` comment, the last-prefetch note, and the "pillar" vocabulary. Bounded re-review (round 2): **0 critical**, but one residual major in the doc intro (still 52/24-to-spare) and four minors (the prefetch/loop-control wording, "never stored", the pillar row, the spec's "color/PF byte" pin); all fixed and verify stayed green. No third review under the quality policy. Lesson 23 is complete.

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

> **Phase baseline tree**: c56d0762c1daf3d5f7643237c02145e85ee18923 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part3-playfield/24-multicolor-playfield/` (4 sources) · `docs/part3-playfield/24-multicolor-playfield.md` · `docs/part3-playfield/index.md` (row 24) · `docs/public/roms/part3-playfield/24-multicolor-playfield/` · `docs/public/images/lesson24/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (Part 3 completion → RD-03 row Done)
> **Reasoning**: high — per-line `COLUPF` timing closes Part 3 and must be measured under independent hardware review

### Step 6.1: Lesson 24 — The Multicolor Playfield

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 24 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 24 · AR-2, AR-4, AR-6, AR-16
**Objective**: Deliver lesson 24 end to end through the mandatory three sessions and close Part 3.

- [x] 6.1.1 Lesson 24 — The Multicolor Playfield: Session A freezes ST-24.1–ST-24.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson24): The Multicolor Playfield` ✅ (completed: 2026-11-04 00:38)

**Session A record** (freeze + red baseline, 2026-11-04 00:18): ST-24.1–ST-24.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 24. Design pins: the standard 262-line frame. The Lesson 19 castle pattern (`PF0=$F0`, `PF1=$CC`, `PF2=$F0`), reflect mode (`CTRLPF=$01`), `COLUBK=$02`. `COLUPF` is written every line from a 192-byte table through `ColorPtr`; the per-line kernel is `LDA (ColorPtr),Y` (cycles 5-9) / `STA COLUPF` (10-12) / `INY` (13-14) / `STA WSYNC` (15-17) / `CPY #192` + `BNE` (next line 0-4) — 5 cycles of wake equal the release, so line 37 and line 228 share the phase. Two tables: `Rainbow` (16 hues × 12 lines, `$0E,$1E,...,$FE` at luminance 7) and `Regions` (6 × 16 cool hues `$6E/$7E/$8E/$9E/$AE/$BE`, then 6 × 16 warm `$2E/$3E/$4E/$5E/$1E/$0E`); the state flips every **120 frames** (~2 s) by swapping the pointer in VBLANK. Captures `rainbow.png` (~1 s) and `regions.png` (~3 s), pixel-classified by the colour at rows 110 and 400. Evidence pins (AR-6): frame checkpoints (`StartFrame` 259, `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229); `ColorWrite` one hit per line at cycle 13, A = the table byte (12 consecutive lines share a hue in the rainbow state); `StateFlip` at frames 120/240 with A = 1/0. Exercises: ex 1 a moving rainbow (a doubled 384-byte table, the pointer advanced 12 bytes per second, wraps); ex 2 a sky/ground table (96 lines `$84`, 96 lines `$46`); ex 3 the Lesson 23 row tables with a per-row colour (wall rows `$C8`, open rows `$02`). Red baseline confirmed: no lesson sources, ROMs, or images; the document is still the `🔒 Coming Soon` stub; index row 24 is Coming Soon; sidebar entry exists (`config.ts:77`); `verify.sh` green at `c56d076`. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-11-04 00:38): Preflight per `vcs-lesson-production` — the per-line color timing checked against the Lesson 18 write-position rule and Lesson 23's page-cross behavior; the two tables are exactly 192 bytes with every byte `%HHHHLLL0`; the shape is the Lesson 19 castle; the frame against Lessons 12–23; ACME forms; no demo (AR-3: the rainbow is the visible picture); style follows Lessons 12–23. `bash scripts/verify.sh` green (implementation, post-fix, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F00E` = (259, 3), `VblankStart` `$F01C` = (0, 5), `VisibleStart` `$F06F` = (37, 5), `OverscanStart` `$F07A` = (229, 4). State: `StateFlip` `$F035` at frames 120/240/360/480 with A = 1/0/1/0. Color: `ColorWrite` `$F073` — 192 hits per frame; frame 1 has 12 lines at A = `$0E` (scanlines 37-48), then 12 at `$1E` (49-60), and so on; the cycles are 13, or 14 on a page-crossing line — the rainbow table (`$F08D`) crosses from entry 115 (scanline 152), the regions table (`$F14D`) from entry 179 (scanline 216); `WSYNC` absorbs the extra cycle. Captures from the committed ROM: `rainbow.png` — top row 110 rgb(234,234,233) = `$0E`, row 400 rgb(181,134,251), row 600 rgb(194,253,120); `regions.png` — row 110 rgb(208,130,251) = `$6E`, row 400 rgb(121,253,207) = `$BE`; repeats of each state differ in 0 px; the states differ in 348,480 px. Solutions: ex 1 — `OffsetStep` at frames 60/120/180/240/300 with A = `$0C`/`$18`/`$24`/`$30`/`$3C`; a capture at offset 12 (about 1.5 s of emulation) shows the top band at `$1E`; ex 2 — `ColorWrite` A = `$84` on lines 37-132 and `$46` on 133-228, using the pointer form so the kernel is unchanged; ex 3 — `LevelSwitch` at 240/480 (A=1/0), `ColorStore` 152 hits A = `$C8` and 40 hits A = `$02` in frame 1. Site (ST-24.6): index row 24 ✅ Complete, built page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 23, next → Lesson 25 (the forward-link pattern); README unchanged. Reviews (AR-5): both specialists on the phase diff (static; the parent ran all builds/logs/captures) — round 1: **0 critical, 0 major**, 7 minor: the page-cross line numbering (entry 115 = scanline 152 in the rainbow state, 216 in regions), the cool-band hue names (aligned to Lesson 13's named-color table), the exercise-1 capture time (offset 12, not 2.5 s), the stale `BNE LineLoop` label, the exercise-2 "kernel unchanged" claim (the solution now uses the pointer form), and the `ColorWrite` checkpoint cycle in ST-24.4/the spec (the write lands at 10-12; the checkpoint on `INY` reads 13/14). All fixed; no re-review required (no critical/major). **Part 3 (lessons 19–24) is complete — the plan's final task.**

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
