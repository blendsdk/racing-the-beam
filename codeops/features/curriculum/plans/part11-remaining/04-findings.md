# Lessons 73–78 — Findings

> **Status**: Lesson 73 reviewed and fixed; 74–78 pending.
> **Rule**: every finding gets a stable ID, a severity, a status, and file:line evidence.

## Summary

| Severity | Raised | Open | Accepted | Fixed |
|---|---:|---:|---:|---:|
| Critical | 4 | 0 | 0 | 4 |
| Major | 13 | 0 | 0 | 13 |
| Minor | 33 | 0 | 0 | 33 |

## Lesson 73

### Critical

| ID | Source | Finding | Evidence | Resolution | Status |
|---|---|---|---|---|---|
| L73-C1 | atari2600-reviewer, curriculum-auditor | Planet rows 12–14 set PF1 `$1F/$3F/$7F` and PF0 `$80/$C0/$E0`, leaving chunks 4–6 empty; the limb had detached 4-px blocks at both bottom corners | source PF tables; captures | Rows 12–15 now `PF1=$FF` + PF0 `$80/$C0/$E0/$F0` (half-widths 68/72/76/80); 0 sky gaps; captures re-taken | Fixed |
| L73-C2 | atari2600-reviewer | The doc modeled the visible-line HMOVE as "re-applies 4 px of left motion" with a `−640 ≡ 0` argument; the real effect is plugging/stall (not-yet-drawn pixels delayed rightward), so the +12 px measurement contradicted the model | doc theory; state test | Theory rewritten: HBLANK HMOVE = walk + bar; visible-line HMOVE = bounded stall; `−640` deleted; per-line trace added (36–133 px mod 160) | Fixed |
| L73-C3 | atari2600-reviewer, curriculum-auditor | Exercise 1 computed the band index with `TAX`, overwriting the walk's line cursor X; the exercise's 160-line walk was broken | ex1 `GroupFirstBody`; Stella frame-end X | `TAY` + `LDA StarBandColours,Y`; X preserved; frame-end X=$A0 (160), field span 8–151; doc hint changed to TAY | Fixed |

### Major

| ID | Source | Finding | Evidence | Resolution | Status |
|---|---|---|---|---|---|
| L73-M1 | atari2600-reviewer | The first-line HMOVE completed at ~cycle 19, so the line-0 bar was a coin flip on real TIA | source `BodyStart`; 37/11 label | First-line HMM0/HMBL preloaded in VBLANK; `BodyStart` is `STA HMOVE`; Body 37/5, bar 160/160 including line 0 | Fixed |
| L73-M2 | atari2600-reviewer, curriculum-auditor | The "colour wash" was attributed to HMOVE; the kernel writes colours in VBLANK and a band-local grey is not a documented HMOVE effect; the "colour-locked frames" claim was inconsistent with the capture method | doc tip/capture note | Hardware attribution and colour-locked claim deleted; captures plain 2 s/5 s; sky values changed to four blues (`$82/$84/$86/$88`) | Fixed |
| L73-M3 | atari2600-reviewer | "Even with HMP0=0 the strobe can move P0" is false; P0 drifted because the per-line HMOVE re-applies a nonzero HMP0 | source comments; doc | Reworded: HMP0 must be 0 because the per-line HMOVE re-applies it; HMP0 cleared before HMOVE | Fixed |
| L73-M4 | curriculum-auditor | The plan's ST-73.4 expected the bar only in comb.png; the delivered walk has it in both states; the spec still described per-line RESM0/RESBL | plan 01/02/03; doc | Plan amended to the HMOVE walk, the bar in both states, the 240 toggle, and the 229/3 label | Fixed |
| L73-M5 | curriculum-auditor | The doc asserted a visible 8-px bar but the "0 object pixels in x=0–7" check cannot prove it; the bar is border-black and visible, but the check was vacuous | doc pixel table; captures | Doc now says the bar is the border-colour notch and the object-pixel check is a separate limit; the bar is measured as the left 8-px border strip | Fixed |
| L73-M6 | curriculum-auditor | The doc used "cycle ~9" for the strobe but its own GroupTop checkpoint was 37/11; two cycle conventions were mixed | doc; source | Strobe cycles re-derived for the new kernel; Body 37/5, GroupTop 45/5; the doc states the convention once | Fixed |
| L73-M7 | curriculum-auditor | The eighth-line tail wrote the next group's HMM0/HMBL ~11–14 cycles after the comb HMOVE, inside the 24-cycle window | source tail; GroupTop | The tail only loads A/Y; the next `GroupTop` writes HMM0/HMBL then strobes; measured gap ~40 cycles | Fixed |
| L73-M8 | curriculum-auditor | The group-first comb strobe was ~57; the next body line's `STA HMM0` was ~23 cycles later, inside the 24-cycle window | source; cycle trace | 2-cycle `NOP` at the top of `WalkBody`; group-first gap 25, eighth-line gap 39; bar 160/160; frame 262 | Fixed |
| L73-M9 | atari2600-reviewer | Walkthrough Step 3 still taught the pre-fix design (eighth line writes HMM0/HMBL straight into the registers) | doc Step 3; source | Step 3 rewritten: eighth line loads A/Y; next GroupTop writes the registers and strobes | Fixed |
| L73-M10 | atari2600-reviewer, curriculum-auditor | The doc said the overscan timer was 35 and 36 gave 263 lines; the source uses 36 and gates 259/3 | doc; source | Doc says 36; the 35 build is labelled an earlier build; gate 259/3, frame 262 | Fixed |

### Minor

| ID | Finding | Resolution | Status |
|---|---|---|---|
| L73-m1 | Mask "bit 0 of every byte is zero" held only for the ROM table; the ROL moves bit 7 into bit 0 and the group-first line discards it, so a seam star blinks for one phase | Doc states the write-time invariant and the blink; source comment corrected | Fixed |
| L73-m2 | Copies at X+16/X+32 can wrap past 159; "the group's first line is always blank" is not guaranteed | Doc says "mod 160" and adds the wrapped-copy caveat | Fixed |
| L73-m3 | Stale numbers: 51 star lines/204 px vs 34/136; STAR_START 91/BALL_START 152 vs 73/83; `.done` label; 34-bit mask; probe table; 229/3 vs 228/3; ex2 "every 8 frames" | All replaced with the measured values | Fixed |
| L73-m4 | `SHIP_X` dead constant; header said X=76 while the capture measured 78–86 | Deleted; header/doc use the measured 78–86 | Fixed |
| L73-m5 | The doc said the positioner lands M0 at 103 with a "+30 output delay" story; Lesson 26's calibration says it lands at the value passed | Re-measured: zero-motion M0 78 / ball 83; the +5 is a measured calibration, no output-delay claim | Fixed |
| L73-m6 | Ship positioner arithmetic: 18 NOPs = 36 cycles, not 44 | 22 NOPs = 44 cycles, RESP0 ~46; measured X 78–86 | Fixed |
| L73-m7 | Colour names: `$02` is dark grey, `$8E` bright blue; "four dark blues" was three blues and a grey | Sky is four blues (`$82/$84/$86/$88`); names match the bytes | Fixed |
| L73-m8 | "The comb artifact widens" and "teeth" were unmeasured; the second state shows a shift, not a wider bar | "Widens"/teeth deleted; the second state is the visible-line stall | Fixed |
| L73-m9 | The "1 of 32 at cycle 18" bar probe claim was inconsistent with the documented latch window | 32/1 numbers dropped; only "early enough" and the measured 160/160 remain | Fixed |
| L73-m10 | Exercise 1 hint said the group-first line has the most cycles after the reload moved to the eighth line | Hint reworded; ex1/ex2 planet and comments fixed | Fixed |
| L73-m11 | The auto-demo fired `Frame==240` every 256 frames and could override a SELECT-off | One-shot `AutoFired` latch; SELECT remains independent | Fixed |
| L73-m12 | The prerequisite line omitted Lesson 18 (mid-scanline changes) and the SELECT lessons | Added Lesson 18 and 42/47 | Fixed |
| L73-m13 | The RAM map said `$9E-$F7 free` while `AutoFired=$9E` | `$80-$9E`, `$9F-$F7 free`; Full Source resynced | Fixed |
| L73-m14 | The auto-demo comment said "once every 256 frames" after the one-shot latch | "fires once; `AutoFired` latches it off" | Fixed |
| L73-m15 | The "frame-phase sensitive" claim contradicted the deterministic closed walk | Removed; the visible set changes with the mask scroll, not the HMOVE phase | Fixed |
| L73-m16 | The seam blink was called one frame; the scroll is every 8 frames | One scroll phase (8 frames) | Fixed |
| L73-m17 | The ball's leftmost was stated X=18/28.7; the table gives X=9 (cycle 25.7), the capture X=8 | Doc/source state the measured value and the margin; the enable is in time | Fixed |
| L73-m18 | PF store cycles mixed relative and absolute numbering | "14/21/28 after the label (19/26/33 absolute)" | Fixed |
| L73-m19 | ex1's mask comment said 34/136 over a 73-star mask; ex1/ex2 kept comb clauses and dead `AUTO_COMB` | 73/292; clauses and constants removed | Fixed |
| L73-m20 | The `PlanetRow` label said 200/3; the measured first row is 199/3; the Lesson 79 What's Next still said 73–78 coming; the doc prose said rows 12–14; the second strobe was called ~30 cycles | 199/3; Lesson 79 points at Lesson 73; rows 12–15; second strobe ~44 cycles | Fixed |
| L73-m21 | The doc's absolute landing was reported as 16/21 in the current build while the walk check and ledger used 78/83 | The main ROM's measured start is 78/83 (the 16/21 probe was a different build); doc/source/TS now use 78; the relative walk is the claim | Fixed |
| L73-m22 | The ship X was reported as 78–86 in the ledger and 97–105 in the exercises, while a fresh capture of the committed 22-NOP ROM measures 57–65; the star minimum/ball citations/Step 6 snippet had residuals | Fresh 2 s/5 s captures from the committed ROM both measure the ship at TIA 57–65; the doc/source use 57–65; ledger m4/m6 updated; star min 24; Step 6 verbatim; ex2 2 frames | Fixed |

## Lesson 74

### Critical / major

| ID | Source | Severity | Finding | Resolution | Status |
|---|---|---|---|---|---|
| L74-C1 | atari2600-reviewer, curriculum-auditor | 🔴 Critical | The flight-band `BCC .draw` and `BNE FlightLoop` crossed a page, so the draw path was 26 and the line 51–52, not 25/25 and 50/53 | Page-aligned `FlightLoop` (`$F100`); scan shows both branches same-page; ledger 25/25, line 50/53 | Fixed |
| L74-M1 | atari2600-reviewer, curriculum-auditor | 🟠 Major | The Step 8 trace mixed start and completion cycles; store/ENAM0/WSYNC values disagreed across the doc | Re-traced with `-dbg.logtrace`; one convention stated; STY 22→25, ENAM0 40→43, WSYNC 50→53, margins 23/6/23 | Fixed |
| L74-M2 | curriculum-auditor, atari2600-reviewer | 🟠 Major | Exercise 1's flight `BNE` crossed; the 73+3=76 worst case was unproven and the overlap windows were not measured | Moon uses the branchless 256-byte table; loop page-aligned; worst case 65/68; captures at 2 s/5 s; ex1 gate at 1.3 s/2.6 s | Fixed |
| L74-M3 | atari2600-reviewer, curriculum-auditor | 🟠 Major | The PF write deadlines were wrong (22.7/38.7/70.7); the correct first-chunk times are 22.67/28.0/38.67 | Doc/source corrected; first star line 17/24/31, steady 7/14/21, ground 15/18/21 | Fixed |

### Minor

| ID | Finding | Resolution | Status |
|---|---|---|---|
| L74-m1 | Capture method not disclosed | 73-style note added (committed ROM, script, 2 s/5 s, pointer, 1010x807) | Fixed |
| L74-m2 | The auto-demo timeline said four seconds low; the table is high at 4 s | ROM-time holds stated (low 0.93–2.25 s, high 2.80–4.25 s); captures at 1.3 s/2.6 s | Fixed |
| L74-m3 | Checkpoint cycles disagreed across source/doc/plan | One measured convention (61/2, 205/2, 229/2; GroundStart 204/49) | Fixed |
| L74-m4 | Wrap range said 128..255; the true floor is 112 | 112..255 in source/doc/ex2 | Fixed |
| L74-m5 | The Part 11 index called skipdraw "branchless"/"every commercial game" | Parent edited the index to "one-branch ... unconditional store"; no universal claim | Fixed |
| L74-m6 | Ground PF stores said 10/13/16 | 15/18/21 | Fixed |
| L74-m7 | The two ENAM0 clears were not taught | Step 4 snippet + VBLANK/GroundLine sentence | Fixed |
| L74-m8 | "Nine instructions" for eight | Eight | Fixed |
| L74-m9 | Pixel boxes were short of the 8-px/24-row extents | Inclusive x 76–83 (half-open 84), rows 144–167; sampling artifacts labelled | Fixed |
| L74-m10 | GRP0 ground invariant not stated | Last flight line is always a skip for RocketY≤144; widening the table needs a clear | Fixed |
| L74-m11 | History sourcing was unnamed | 8bitworkshop VCS material + AtariAge community descriptions; no universal claim | Fixed |

### Accepted limitations

| ID | Limitation | Why accepted | Ruling |
|---|---|---|---|
| L73-L1 | The second state reproduces the visible-line HMOVE stall/shift, not a bit-exact Cosmic Ark comb pattern. | The historical register sequence is not documented in a form the course can cite; the lesson proves the mechanism it uses. | Accepted by the review |
| L73-L2 | The per-line star map is frame-phase sensitive: the walk is deterministic, but the mask scroll changes which lines are stars, so two captures do not share per-line values. | The scroll is the lesson's animation; the doc claims a bounded table-driven walk, not a frame-stable map. | Accepted |
| L73-L3 | The bar check is against the 960x606 window capture, not a native TIA framebuffer. | The course's standard evidence; the left 8-px border strip is visible and measured. | Accepted |
| L73-L4 | Planet row 14 reads 72 px in the capture vs the design 76 (4-px latch/sampling). | The limb is continuous with 0 sky gaps; the difference is one PF chunk at the edge. | Accepted |
| L73-L5 | M0 lands at X=78 with `STAR_START=73` (+5 measured calibration); the ball lands at 83. | The walk's relative steps are the table; the absolute offset is calibrated and disclosed. | Accepted |
| L73-L6 | The overscan timer is 35, not 36; the frame is 262. | With 36 this build measured 263 lines; 35 + the WSYNC anchor gives the correct frame. | Accepted |
