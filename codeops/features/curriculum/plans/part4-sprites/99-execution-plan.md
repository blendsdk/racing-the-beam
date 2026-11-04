# Execution Plan: Part 4 — Sprites (Lessons 25–34)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-04 15:40
> **Progress**: 5/10 tasks (50%)
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

> **Phase baseline tree**: 2e63a29ba850bcf145f1b458b5c35fa131f0f09b (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part4-sprites/25-player-basics/` (4 sources) · `docs/part4-sprites/25-player-basics.md` · `docs/part4-sprites/index.md` (rebuild + row 25) · `docs/public/roms/part4-sprites/25-player-basics/` · `docs/public/images/lesson25/` (1 capture) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — the first sprite is the part's foundation; the vertical-write model and the fixed coarse placement are under independent hardware review

### Step 1.1: Lesson 25 — Player Sprite Basics

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 25 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 25 · AR-2, AR-3, AR-4, AR-6, AR-10, AR-13, AR-14
**Objective**: Deliver lesson 25 end to end through the mandatory three sessions.

- [x] 1.1.1 Lesson 25 — Player Sprite Basics: Session A freezes ST-25.1–ST-25.6 (red baseline), Session B implements the full artifact set (including the AR-10 index rebuild), Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson25): Player Sprite Basics` ✅ (completed: 2026-11-04 13:40)

**Session A record** (freeze + red baseline, 2026-11-04 13:10): ST-25.1–ST-25.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 25. Design pins: the standard 262-line frame. One player 0, 8 rows, shape `$18,$3C,$7E,$DB,$FF,$24,$5A,$A5`, `COLUP0=$42` red, `COLUBK=$02`, `NUSIZ0=0`, `REFP0=0`. `SPRITE_TOP=80` → first body line scanline 117; body 8 lines; **one clear line** (`LDA #$00` / `STA GRP0` / `STA WSYNC`); bottom 103 lines; top+body+clear+bottom = 192. Placement is the Lesson 25 placeholder: after `STA WSYNC`, `LDX #9` and a `DEX`/`BNE` pad, then `STA RESP0`; target TIA X ≈ 81, tolerance ±4, measured X authoritative. Expected capture: 48 px wide (8 × 6) at capture x = 25 + 6·X, 8 scanlines tall, dark background. Evidence pins (AR-6): frame checkpoints (`StartFrame` 259, `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229); `BodyStart` at scanline 117, cycle 6, 8 hits per frame; the measured sprite X. Solutions: ex 1 `SPRITE_TOP=120` (first line 157); ex 2 `REFP0=$08` (mirror, same span); ex 3 two bodies with a clear line each, top 56, gap 31, second body at line 133. Red baseline confirmed: no `lessons/part4-sprites` tree, no `docs/public/images/lesson25`, no `docs/public/roms/part4-sprites`, the document is the `🔒 Coming Soon` stub, the Part 4 index is the minimal stub, sidebar entry exists (`config.ts:84`); `verify.sh` green at `2e63a29`. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-11-04 13:40): Preflight per `vcs-lesson-production` — the sprite geometry checked against `tia-hardware.md` (GRP0 bit 7 leftmost, one line per write, the register holds), the frame against Lessons 12–24, the placement arithmetic against Lesson 18's hit-cycle rule, ACME forms; no demo (AR-3: the first sprite is the visible picture). `bash scripts/verify.sh` green (implementation, fixes, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F00E` = (259, 3), `VblankStart` `$F01C` = (0, 5), `VisibleStart` `$F049` = (37, 7), `BodyStart` `$F050` = (117, 6) with 8 hits per frame, `OverscanStart` `$F069` = (229, 4). The placement: `Resp0Write` `$F02C` on VBLANK line 1, instruction start cycle 46, write effect cycle 49 → clock 147; the player's 5-clock output delay puts the left edge at clock 152, TIA X = **84**. The body: `SpriteWrite` `$F053` at line 117 cycle 10 (A = `$18`) and line 118 cycle 11 (A = `$3C`), 8 hits per frame; the store's effect at cycle 13 = clock 39, far before the sprite's left edge. Capture from the committed ROM (`first-sprite.png`): red `$42` bbox capture x = **529–576** (48 px = 8 pixels × 6) and y = **359–383** (25 px = 8 scanlines); nothing below the sprite (the clear line works). Solutions: ex 1 — bbox y = 486–509 (first body line 157), same x; ex 2 — same span, tail rows `11110000` / `00001111` (the mirror of the `$0F`/`$F0` asymmetric tail); ex 3 — bodies at scanlines 93 and 133, bands y = 284–307 and 410–433, `OverscanStart` 229 and `StartFrame` 259 (262 lines). Site (ST-25.6): the Part 4 index was rebuilt to the Part 1 format with rows 25–34 (row 25 ✅ Complete); the built page renders with `<RomPlayer>` on the committed ROM, the capture, prev → 24, next → 26; README unchanged ("4 | Sprites | 25–34"). Reviews (AR-5): both specialists on the phase diff (static; the parent ran all builds/logs/captures) — round 1: **1 critical, 2 major, 7 minor**. The critical: Exercise 2's mirror was a no-op because every row of the lesson shape is a bit-reversal palindrome, and the doc claimed otherwise; fixed by giving the exercise an asymmetric tail (`$0F`/`$F0`) and correcting the theory. The majors: Exercise 3's frame was 261 lines (`BOTTOM=86` instead of 87); and the `SpriteWrite`/`Resp0Write` evidence pins were missing from the sources. The minors: the "clock 504" unit error, the 45-vs-49-cycle delay arithmetic, "one-sixth" vs "two-fifths", the "remaining 104" header, the "always eight pixels wide" claim, the height wording, the untaught `REFP0` note. Session B also caught the missing clear line before review (the last GRP0 byte smeared); fixed in all four sources and the capture re-taken. Bounded re-review (round 2): **0 critical, 0 major**, 3 prose minors (a garbled delay sentence, the exercise-2 header still saying "table unchanged", and inverted raw-byte tail labels); all fixed and verify stayed green. No third review under the quality policy. Lesson 25 is complete.

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

> **Phase baseline tree**: eff8bfa (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part4-sprites/26-horizontal-positioning/` (4 sources) · `docs/part4-sprites/26-horizontal-positioning.md` · `docs/part4-sprites/index.md` (row 26) · `docs/public/roms/part4-sprites/26-horizontal-positioning/` · `docs/public/images/lesson26/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — the part's highest-risk claim: the divide-by-15 routine's landing under independent hardware review

### Step 2.1: Lesson 26 — Horizontal Positioning

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 26 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 26 · AR-2, AR-3, AR-4, AR-6, AR-13
**Objective**: Deliver lesson 26 end to end through the mandatory three sessions, with the
divide-by-15 routine's measured landing recorded.

- [x] 2.1.1 Lesson 26 — Horizontal Positioning: Session A freezes ST-26.1–ST-26.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson26): Horizontal Positioning` ✅ (completed: 2026-11-04 14:12)

**Session A record** (freeze + red baseline, 2026-11-04 13:41): ST-26.1–ST-26.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 26. Design pins: the standard 262-line frame; the Lesson 25 invader at top 80, body 8, clear 1, bottom 103; five targets **16, 48, 80, 112, 144** (capture x = 121, 313, 505, 697, 889), one per **60 frames**, wrapping; `SetHorizPos` (classic divide-by-15: `STA WSYNC`, `SEC`, `SBC #15`/`BCS`, `EOR #7`, `ASL`×4, `STA HMP0`, `STA RESP0`, `STA WSYNC`, `STA HMOVE`) called in VBLANK; `COLUP0=$42`, `COLUBK=$02`. The measured landing is authoritative: each target is accepted within ±3, and the routine's output-delay calibration is recorded in Session C. Evidence pins (AR-6): frame checkpoints; `PosStep` (A = the new index, once per 60 frames); `PosApply` (A = the table value, every frame); `Resp0Write` and `HmoveApply` (the two strobes); the measured X from each capture. Solutions: ex 1 single target 120; ex 2 target 152 (the quotient 10); ex 3 ping-pong 32/128 every 60 frames. Red baseline confirmed: no `lessons/part4-sprites/26-horizontal-positioning`, no `docs/public/images/lesson26`, no committed ROMs, the document is the `🔒 Coming Soon` stub, index row 26 is Coming Soon, sidebar entry exists (`config.ts:85`), `verify.sh` green at `eff8bfa`. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-11-04 14:12): Preflight per `vcs-lesson-production` — the divide-by-15 arithmetic and the output-delay calibration checked against Lesson 18's hit-cycle rule and `sprite-tricks.md`; the frame against Lessons 12–25; ACME forms; no demo (AR-3: the five positions are the visible picture). `bash scripts/verify.sh` green (implementation, fixes, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F00E` = (259, 3), `VblankStart` `$F01C` = (0, 5), `VisibleStart` `$F060` first hit (37, 7), `BodyStart` `$F067` first hit (117, 6) with 8 hits per frame, `OverscanStart` `$F080` = (229, 4). Tour: `PosStep` `$F03B` at frames **60/120/180/240/300** with A = 1/2/3/4/0; `PosApply` `$F042` every frame with A = `$13/$33/$53/$73/$93` (19/51/83/115/147). The routine: `Resp0Write` `$F0A2` on VBLANK line 1 at cycles **24/34/44/54/64** (the cycle advances with the table); `HmoveApply` `$F0A6` on VBLANK line 2 cycle 0 (effect 3, in HBLANK — confirmed by the `RTS` at line 2 cycle 3). The measured landing is `target − 3` for every input, so the table stores target + 3 and the five positions are exact: capture x = **121–168 (X=16), 313–360 (48), 505–552 (80), 697–744 (112), 889–936 (144)**, all at y = 359–383. Committed captures are `position-a.png` (X=16) and `position-b.png` (X=112); scratch captures at the other three tour steps measured 48/80/144. Solutions: ex 1 — X=120 (capture 745–792); ex 2 — X=152 (937–984, the right edge); ex 3 — X=32 (217–264) and X=128 (793–840). Site (ST-26.6): index row 26 ✅ Complete; the built page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 25, next → 27; README unchanged. Reviews (AR-5): both specialists on the phase diff (static; the parent ran all builds/logs/captures) — round 1: **0 critical, 4 major**, 8 minor. The majors: the remainder model was wrong (A exits as a negative byte, not 0–14); the checkpoint ledger said HMOVE was on line 1 cycle 30 and RESP0 always at 24 (it is line 2 cycle 0 / 24-34-44-54-64); Exercise 2's quotient explanation used 152 instead of the passed 155; and the capture-gap caption called 96 TIA pixels "three coarse steps" (it is 576 capture pixels / three tour steps / 90 coarse + 6 fine clocks). The minors: the TypeScript fine formula, the clock-68/X=5 example, the −3 causal account, the source comments saying "target X" instead of the biased value, exercise 1's `#123`, the HMOVE/HBLANK mask note, exercise 3's `PosStep` label, and the "measured" note for the five positions. Bounded re-review (round 2): **0 critical, 0 major**, 8 prose minors (the `PosApply` comment, the `u − 9` wording, "coarse strobe" vs "coarse position", the TS `steps` comment, the 90+6 caption arithmetic, the clock-63 example, the "output delay" vocabulary, and the undefined `5k+14`); all fixed and verify stayed green. No third review under the quality policy. Lesson 26 is complete.

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

> **Phase baseline tree**: 86f1fa5 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part4-sprites/27-sprite-movement/` (4 sources) · `docs/part4-sprites/27-sprite-movement.md` · `docs/part4-sprites/index.md` (row 27) · `docs/public/roms/part4-sprites/27-sprite-movement/` · `docs/public/images/lesson27/` (2 captures) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: medium — a bounded input + movement loop reusing the positioning routine; the capture timing is the main risk

### Step 3.1: Lesson 27 — Sprite Movement

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 27 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 27 · AR-2, AR-3, AR-4, AR-6, AR-15
**Objective**: Deliver lesson 27 end to end through the mandatory three sessions.

- [x] 3.1.1 Lesson 27 — Sprite Movement: Session A freezes ST-27.1–ST-27.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson27): Sprite Movement` ✅ (completed: 2026-11-04 14:45)

**Session A record** (freeze + red baseline, 2026-11-04 14:15): ST-27.1–ST-27.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 27. Design pins: the standard 262-line frame; the Lesson 25 kernel (top 80, body 8, clear 1, bottom 103); `SpriteX` starts at 80, `Direction` at +1, bounds **16/144**; `SWCHA` bits 6 (left) and 7 (right) active-low (`$C0` keep, `$80` left, `$40` right, `$00` stop); `SWACNT=$00` in Reset; `SetHorizPos` every frame with `SpriteX + 3` (Lesson 26's measured bias); `COLUP0=$42`, `COLUBK=$02`. The auto-patrol is deliberate so the ROM moves with no controller. Evidence pins (AR-6): frame checkpoints; `MoveTick` (A = the new X, every frame); `PosApply` (A = X + 3); `DirWrite` (A = the input direction while a horizontal input is held; 0 hits in the no-input patrol); the two committed captures near the bounds; the manual joystick check (left/right/both). Solutions: ex 1 speed 2; ex 2 bounds 8/152; ex 3 vertical movement with `SpriteTop`/`BottomCount`, ±4 lines, clamp 40/140, bottom count 192 − TOP − 8 − 1. Red baseline confirmed: no `lessons/part4-sprites/27-sprite-movement`, no `docs/public/images/lesson27`, no committed ROMs, the document is the `🔒 Coming Soon` stub, index row 27 is Coming Soon, sidebar entry exists (`config.ts:86`), `verify.sh` green at `86f1fa5`. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-11-04 14:45): Preflight per `vcs-lesson-production` — the input mapping checked against the corrected `include/vcs.asm` and `tia-hardware.md` (P0 bit 4 up, 5 down, 6 left, 7 right; 0 = pressed), the movement/clamp arithmetic, the Lesson 26 routine, the frame against Lessons 12–26, ACME forms; no demo (AR-3: the patrol is the visible picture). `bash scripts/verify.sh` green (implementation, fixes, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F01B` = (259, 3), `VblankStart` `$F029` = (0, 5), `VisibleStart` `$F09C` first hit (37, 7), `BodyStart` `$F0A3` first hit (117, 6) with 8 hits, `OverscanStart` `$F0BC` = (229, 4). Movement: `MoveTick` `$F07B` one hit per frame, A = 81, 82, 83, …; `PosApply` `$F07E` A = X + 3; `DirWrite` `$F052` has **0 hits** with no controller (the auto-patrol skips it). Input witnesses (scratch builds that force the input byte; AR-6): left `#$80` → A = `$FF`; right `#$40` → A = `$01`; both `#$00` → A = 0; none `#$C0` → 0 hits. Captures from the committed ROM: `patrol-a.png` X = **26** (capture x = 181–228), `patrol-b.png` X = **142** (877–924), both y = 359–383. Solutions: ex 1 speed 2 (`$02`/`$FE`); ex 2 bounds 8/152; ex 3 vertical (`SWCHA & $30`: `$20` up, `$10` down; top ±4, clamp 40/140; bottom = 192 − top − 8 − 1). Site (ST-27.6): index row 27 ✅ Complete; the built page renders with `<RomPlayer>` on the committed ROM, both captures, prev → 26, next → 28; README unchanged. Reviews (AR-5): both specialists on the phase diff (static; the parent ran all builds/logs/captures) — round 1: **1 critical, 1 major**, 4 minor. The critical: the SWCHA direction bits were reversed (the lesson used P0 bit 4 right/5 left/6 down/7 up; the hardware is bit 4 up/5 down/6 left/7 right). The major: the doc claimed a sprite "does not remember" X and must be strobed every frame; `RESP0` latches the position and a static sprite can be positioned once — a moving sprite re-strobes because `SpriteX` changes and the fine offset must be re-applied by `HMOVE`. Round 1's fix corrected the bit order but not the active-low masked values (left is `$80`, right `$40`), so round 2 found the decode still inverted (**1 critical, 2 major**). The corrected code swaps `$80`→`DirLeft` and `$40`→`DirRight`, and the exercise-3 vertical decode is `$20`→up, `$10`→down. The scratch witnesses now confirm left→`$FF`, right→`$01`, both→0. Round 3 (scoped, allowed because round 2 left a critical): **0 critical, 0 major**, 2 prose minors (`DirWrite`/`TopTick` wording), fixed. The ground-truth fix also corrected `include/vcs.asm` and the `atari-2600-expert` reference. The transient Stella launch badge in `patrol-b.png` is outside the picture and is accepted (same artifact as Lesson 25). Lesson 27 is complete.

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

> **Phase baseline tree**: c86ffc7 (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part4-sprites/28-two-players/` (4 sources) · `docs/part4-sprites/28-two-players.md` · `docs/part4-sprites/index.md` (row 28) · `docs/public/roms/part4-sprites/28-two-players/` · `docs/public/images/lesson28/` (1 capture) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: medium — two independent players sharing a line budget; positioning correctness under review

### Step 4.1: Lesson 28 — Two Players

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 28 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 28 · AR-2, AR-3, AR-4, AR-6, AR-13
**Objective**: Deliver lesson 28 end to end through the mandatory three sessions.

- [x] 4.1.1 Lesson 28 — Two Players: Session A freezes ST-28.1–ST-28.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson28): Two Players` ✅ (completed: 2026-11-04 15:05)

**Session A record** (freeze + red baseline, 2026-11-04 14:50): ST-28.1–ST-28.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 28. Design pins: the standard 262-line frame; P0 shape `$18,$3C,$7E,$DB,$FF,$24,$5A,$A5` red `$42` at X=48, P1 shape `$3C,$7E,$FF,$DB,$FF,$66,$3C,$18` blue `$84` at X=104; both top 88 (first body line 125), 8 rows, one clear line, bottom 95 = 192; `COLUBK=$02`, `NUSIZ0=NUSIZ1=0`, `REFP0=REFP1=0`; two coarse routines (`SetCoarse0`/`SetCoarse1`) set `HMP0/HMP1` and strobe `RESP0/RESP1`, then **one** `HMOVE` applies both (AR-21); the targets carry the Lesson 26 +3 bias (51/107). Evidence pins (AR-6): frame checkpoints; `PosApply0/1` (A = the biased targets); `Resp0Write`/`Resp1Write` (the coarse strobes); `HmoveApply` (the single fine strobe); `BodyStart` at 125 with 8 hits; the measured X/colors in the capture. Solutions: ex 1 swap the colors; ex 2 X=16/140; ex 3 both at X=80 to show P0's priority over P1. Red baseline confirmed: no `lessons/part4-sprites/28-two-players`, no `docs/public/images/lesson28`, no committed ROMs, the document is the `🔒 Coming Soon` stub, index row 28 is Coming Soon, sidebar entry exists (`config.ts:87`), `verify.sh` green at `c86ffc7`. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-11-04 15:05): Preflight per `vcs-lesson-production` — the two player registers and the one-HMOVE rule checked against `include/vcs.asm` / AR-21, the frame against Lessons 12–27, ACME forms; no demo (AR-3: the two players are the visible picture). `bash scripts/verify.sh` green (implementation, fixes, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F00E` = (259, 3), `VblankStart` `$F01C` = (0, 5), `VisibleStart` `$F056` first hit (37, 7), `BodyStart` `$F05D` first hit (125, 6) with 8 hits, `OverscanStart` `$F07D` = (229, 4). Positions: `PosApply0` `$F027` A = `$33` (51 = 48 + 3), line 0 cycle 18; `PosApply1` `$F02C` A = `$6B` (107 = 104 + 3), line 1 cycle 45; `Resp0Write` `$F09F` line 1 cycle 34; `Resp1Write` `$F0B1` line 2 cycle 54; `HmoveApply` `$F031` line 3 cycle 0, with `AfterHmove` at line 3 cycle 3 (the single HMOVE applies both fine offsets). Capture from the committed ROM: red P0 at capture x = **313–360** (TIA X=48), blue P1 at **649–696** (X=104), both y = **385–408** (scanlines 125–132). Solutions: ex 1 — blue 313–360, red 649–696; ex 2 — red 121–168 (X=16), blue 865–912 (X=140); ex 3 — both at 505–552 (X=80), P0 red wins the overlap and blue shows only where P1 is on and P0 off. Site (ST-28.6): index row 28 ✅ Complete; the built page renders with `<RomPlayer>` on the committed ROM, the capture, prev → 27, next → 29; README unchanged. Reviews (AR-5): both specialists on the phase diff (static; the parent ran all builds/logs/captures) — round 1: **0 critical, 1 major**, 4 minor. The major: the HMOVE checkpoint was labelled VBLANK line 2 cycle 66, which is the `STA WSYNC` stall point; the actual `STA HMOVE` executes on line 3 cycle 0 (the strobe completes by cycle 3, in HBLANK), confirmed by a new `AfterHmove` breakpoint at line 3 cycle 3. The minors: the two `STA` stores are 6 cycles, not 12; the repeated HMOVE gives a fixed extra offset, not "drift"; the plan ID AR-21 leaked into the lesson source/doc; and the What's Next teaser claimed per-object colors the missiles/ball do not have. Round 2: **0 critical, 0 major**, 3 prose minors (the "effect at the next line" wording, 14/76 is under a fifth not a quarter, and the Part 4 index's Lesson 29 color wording); all fixed and verify stayed green. The Stella launch toast in `two-players.png` is outside the picture and is accepted. Lesson 28 is complete.

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

> **Phase baseline tree**: 459474f (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part4-sprites/29-missiles-and-ball/` (4 sources) · `docs/part4-sprites/29-missiles-and-ball.md` · `docs/part4-sprites/index.md` (row 29) · `docs/public/roms/part4-sprites/29-missiles-and-ball/` · `docs/public/images/lesson29/` (1 capture) · `README.md` (verify only) · `99-execution-plan.md` + roadmaps (progress)
> **Reasoning**: high — four independently positioned objects with different output delays under independent hardware review

### Step 5.1: Lesson 29 — Missiles and Ball

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 29 · [07-testing-strategy.md](07-testing-strategy.md) §Lesson 29 · AR-2, AR-3, AR-4, AR-6, AR-13
**Objective**: Deliver lesson 29 end to end through the mandatory three sessions, with each
object's measured X and width recorded.

- [x] 5.1.1 Lesson 29 — Missiles and Ball: Session A freezes ST-29.1–ST-29.6 (red baseline), Session B implements the full artifact set, Session C verifies to green and hardens; commit via the `git-commit` skill in push mode — `feat(lesson29): Missiles and Ball` ✅ (completed: 2026-11-04 15:40)

**Session A record** (freeze + red baseline, 2026-11-04 15:12): ST-29.1–ST-29.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 29. Design pins: the standard 262-line frame; P0 8-row invader at X=24, top 96 (first body line 133); M0 1 px at X=64, M1 4 px (`NUSIZ1=$20`) at X=96, ball 8 px (`CTRLPF=$30`) at target **108**; the small objects enabled on body rows 2–5 via `ENAM0`/`ENAM1`/`ENABL` bit 1; `COLUP0=$42` (P0+M0), `COLUP1=$84` (M1), `COLUPF=$C8` (ball), `COLUBK=$02`; four coarse routines set `HMP0/HMM0/HMM1/HMBL` and strobe `RESP0/RESM0/RESM1/RESBL`, then **one** `HMOVE` (AR-21). The missiles/ball output delay is one clock shorter than the players'; the measured X is authoritative: the missiles land 63/95 for 64/96, and the ball's target-to-X mapping is measured (68 → 79, 108 → 128). Evidence pins (AR-6): frame checkpoints; the four `PosApply*` values; the four `Resp*` strobes; `HmoveApply`; `EnableWrite` (A=$02, four hits on rows 2–5); the measured X/widths/colors in the capture. Solutions: ex 1 widen M0 to 8 px; ex 2 ball 1 px at target 68 (measured 79); ex 3 a moving M0 at 2 px/frame, wrapping. Red baseline confirmed: no `lessons/part4-sprites/29-missiles-and-ball`, no `docs/public/images/lesson29`, no committed ROMs, the document is the `🔒 Coming Soon` stub, index row 29 is Coming Soon, sidebar entry exists (`config.ts:88`), `verify.sh` green at `459474f`. No implementation logic read (AR-2).

**Session C record** (verify + evidence, 2026-11-04 15:40): Preflight per `vcs-lesson-production` — the enables, widths, colors, and four-object positioning checked against `include/vcs.asm` and the one-HMOVE rule (AR-21); the frame against Lessons 12–28; ACME forms; no demo (AR-3: the lineup is the visible picture). `bash scripts/verify.sh` green (implementation, fixes, and final runs); all four sources 4,096 bytes. Frame: **262 lines** — `StartFrame` `$F00E` = (259, 3), `VblankStart` `$F01C` = (0, 5), `VisibleStart` `$F072` first hit (37, 7), `BodyStart` `$F079` first hit (133, 6) with 8 hits, `OverscanStart` `$F0B3` = (229, 4). Enable: `EnableWrite` `$F088` four hits on scanlines 135–138, A = `$02`. Positions: `PosApplyP0/M0/M1/BL` A = 27/67/99/111 at line 0 c18 / line 1 c35 / line 2 c50 / line 3 c60; `RespP0` line 1 c24, `RespM0` line 2 c39, `RespM1` line 3 c49, `RespBL` line 4 c61 (the logged value; the simple 14+5n estimate is 54, so the ball path carries a 7-cycle offset); `HmoveApply` `$F03B` is the WSYNC stall at line 4 c73, and `STA HMOVE` executes at VBLANK line 5 c0. Capture from the committed ROM (sha1 `f16342c4212bcdff6449123dc693f66d9d7cd221`, re-captured for this record): P0 at capture x = 169–216 (TIA 24), M0 at 403–408 (63, 1 px), M1 at 595–618 (95, 4 px), ball at 793–840 (128, 8 px); P0 y = 410–433, small objects y = 416–427. Solutions: ex 1 — M0 8 px at 403–450; ex 2 — ball 1 px at 499–504 (X=79); ex 3 — moving M0, 2 px/frame, 16–150 with the wrap test at 152. Site (ST-29.6): index row 29 ✅ Complete; the built page renders with `<RomPlayer>` on the committed ROM, the capture, prev → 28, next → 30; README unchanged. Reviews (AR-5): both specialists on the phase diff (static; the parent ran all builds/logs/captures) — round 1: **0 critical, 1 major**, 5 minor. The major: the ball's target→X narrative used a false "coarse slot" cause; fixed by removing the cause and publishing the measured mapping (missiles 64→63, 96→95; ball 68→79, 108→128). The minors: the `HmoveApply` row reported the WSYNC stall as the strobe (now line 5 c0), the spec's exercise-3 range (16–150), the source's `Resp*` names, the think-aloud aside, and the NUSIZ copies hint. Round 2: the auditor re-raised the ball table and the HmoveApply row; the row is fixed, and the ball mapping was re-verified on the committed ROM (fresh capture and log, sha1 above) — the lesson states it as an observation and does not claim a hardware formula. The reviewers' remaining disagreement (their 14+5n model predicts 107, the ROM measures 128) is recorded as an accepted observation; the unexplained 7-cycle ball-path offset is documented in the checkpoint table rather than hidden. The TS block's ball target was aligned to 108. No third review under the quality policy. Lesson 29 is complete.

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
