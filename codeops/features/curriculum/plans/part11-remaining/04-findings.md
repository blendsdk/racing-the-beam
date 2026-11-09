# Lessons 73–78 — Findings

> **Status**: Complete 2026-11-09. All six lessons reviewed and fixed; 4 critical, 33 major, 87 minor; 0 open.
> **Rule**: every finding gets a stable ID, a severity, a status, and file:line evidence.

## Summary

| Severity | Raised | Open | Accepted | Fixed |
|---|---:|---:|---:|---:|
| Critical | 4 | 0 | 0 | 4 |
| Major | 33 | 0 | 0 | 33 |
| Minor | 87 | 0 | 0 | 87 |

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

## Lesson 75

### Critical / major

| ID | Source | Severity | Finding | Resolution | Status |
|---|---|---|---|---|---|
| L75-M1 | atari2600-reviewer, curriculum-auditor | 🟠 Major | The scroll/dash phase moved the road markings toward the horizon (`ADC Scroll`), opposite the stated "rushes toward the viewer" | `SBC Scroll`/`SBC Dash`; captures 0.5 s apart show the dashes moving down | Fixed |
| L75-M2 | atari2600-reviewer | 🟠 Major | The dash was fixed at chunk 19, not the road centre; the curve dashes were off-centre | Gap chunk `20 + c` with `GapL2Tab`/`GapR0Tab`; curve gaps 22/21/18/17 | Fixed |
| L75-M3 | atari2600-reviewer, curriculum-auditor | 🟠 Major | The cycle ledger counted `LDY zp,X` as 3; the macro is 54 and the stores 11/18/25/36/43/54 | Ledger, doc, source and exercise headers corrected | Fixed |
| L75-M4 | curriculum-auditor, atari2600-reviewer | 🟠 Major | The checkpoint table/commands used a stale address set (`$F14F...` vs `$F15D...`) | One `acme -l` set: `$F063/$F071/$F1AB/$F1C0/$F1D7/$F293`; table/commands/prose agree | Fixed |
| L75-M5 | atari2600-reviewer | 🟠 Major | The VBLANK arithmetic used `CMP #$80`=3 and `STA zp,X`=5; the pass counts were wrong | Recounted: `CMP`=2, `STA zp,X`=4; pass A/B counts updated | Fixed |
| L75-M6 | atari2600-reviewer | 🟠 Major | The 22.67-cycle probe formula was internally inconsistent (`16+(32-28)*3=28`, not 31) | Formula removed; the observed split and the mid-chunk caveat stated | Fixed |
| L75-M7 | atari2600-reviewer | 🟠 Major | The capture shows three dashes, not five; rows 0-7 are suppressed | Text corrected (three dashes, rows 0-7) | Fixed |
| L75-M8 | atari2600-reviewer, curriculum-auditor | 🟠 Major | `CurveDirty` stored the new mask, not 1; SELECT-to-straight skipped the rebuild | `LDA #1` on every phase change, main and ex2 | Fixed |
| L75-M9 | atari2600-reviewer, curriculum-auditor | 🟠 Major | Ex2's phase 0 was 120 frames (the 2 s capture on the boundary) and the wave base was added before the 6-bit wrap | Phase 0 = 150; wrap the wave first; 2 s straight, 5 s left curve | Fixed |
| L75-M10 | atari2600-reviewer, curriculum-auditor | 🟠 Major | The walkthrough/TypeScript still taught `row + Scroll`/`ADC`, `cSave`, `DashTable`, `SzR1`, the old `$F04E` checkpoints and the 52-cycle ledger | Theory/TypeScript/Steps 2/5 rewritten from the source; old table removed; exercise headers and build paths fixed | Fixed |
| L75-M11 | atari2600-reviewer, curriculum-auditor | 🟠 Major | Ex2's 5 s state was labelled phase 1/right; with 150+120+120 it is phase 2/left | Doc/ex2 header corrected to phase 2, x20-103 | Fixed |
| L75-M12 | atari2600-reviewer, curriculum-auditor | 🟠 Major | Ex2 SELECT did not advance Phase/CurveBase | SELECT calls the same `NextPhase`/`SetPhase` | Fixed |

### Minor

| ID | Finding | Resolution | Status |
|---|---|---|---|
| L75-m1 | The horizon band was one gold line, not two | Header/table corrected to one gold line + one verge | Fixed |
| L75-m2 | The source header's write order was backwards | "This line's left group, then this line's right group" | Fixed |
| L75-m3 | Lesson 26 missing from the prerequisites | Added; Lesson 15 noted for the timer | Fixed |
| L75-m4 | Ex1 header daylight/moon and build path | Night palette, own build path, 2..10 widths, rows 0-4 | Fixed |
| L75-m5 | Ex2 header 180/360/6 s, 32-entry table, RAM map | 150/120/120, 64-entry, `$E3/$E4` map | Fixed |
| L75-m6 | SunTable "(12-15 sun)" | Rows 12-19 | Fixed |
| L75-m7 | RAM map `$CE-$F7` vs `$D0-$F7` | `$E3-$F7`; 99 used/21 free (main), 101/19 (ex2) | Fixed |
| L75-m8 | The edge rebuild cleared MaskDirty; the dash lag is up to two frames | "Up to two frames"; dash seeded | Fixed |
| L75-m9 | "11 lines of margin"/"5.7-12.7"/"2.6" | 10 lines; 4.7 tightest; 4.7 | Fixed |
| L75-m10 | The 5-line row was described as a hardware necessity | Deliberate band/resolution choice; a 2-line row is mechanically possible | Fixed |
| L75-m11 | The first-frame seed used row-0 masks for all rows | All four tables seeded per row; no first-frame holes | Fixed |
| L75-m12 | Frame-count/stale text residuals (457/398/393; `PhaseTimer`) | One count (393); "frames elapsed" | Fixed |

## Lesson 76

### Critical / major

| ID | Source | Severity | Finding | Resolution | Status |
|---|---|---|---|---|---|
| — | — | — | No critical or major findings. The LFSR math (period 255, zero never visited, exact reverse), the seed tables, the ring replay and the ex2 rewind verified. | — | — |

### Minor

| ID | Finding | Resolution | Status |
|---|---|---|---|
| L76-m1 | "Central water band" is mirrored by REFLECT into two bands | "A water band centred in the 20-chunk field; REFLECT mirrors it" | Fixed |
| L76-m2 | Player-row GRP0 cycles said 4/7; the write lands at 13 (12 last), first line 44 | Corrected in the doc/source/exercises | Fixed |
| L76-m3 | The LFSR tap parenthetical was off by one | "bits 7,5,4,3 of the shifted value; pre-shift 6,5,4 plus the shifted-in bit 7" | Fixed |
| L76-m4 | "Four bars" vs eight; meta "128-byte ring" | Eight bars; 64-byte ring in 128 bytes of RAM | Fixed |
| L76-m5 | "255 rows could not fit 4K" overclaim | 255 rows = 1,020 bytes (a quarter of 4K); the generator is 1 byte + a 96-byte table | Fixed |
| L76-m6 | 229/6 vs 229/4 | 229/4 (`STA VBLANK`); plan ST-76.2 updated | Fixed |
| L76-m7 | "Third change" mislabels the frame-480 A return | "The second change after power-on; frame 480 returns to A" | Fixed |
| L76-m8 | Capture frames 64/256 vs windows 64-71/256-263 | Windows stated; wall-clock approximate | Fixed |
| L76-m9 | Exercise build paths/RAM map/reverse comment | Own source/bin; `$D3-$F7` free; bottom row of the previous window | Fixed |
| L76-m10 | Seed-B "four-row wall block"; player X=40 vs 72 | Three-row wall block; X=40 at power-on, X=72 in the capture | Fixed |
| L76-m11 | ShiftRing "900 cycles"/"a third of VBLANK" | ~600 cycles (~22%) | Fixed |
| L76-m12 | "Three moments"/frame 8-14; prerequisites; What's Next 77; provenance | Four moments; through frame 15; Lesson 26 added; Lesson 77 named; model + Stella trace disclosed | Fixed |

## Lesson 77

### Critical / major

| ID | Source | Severity | Finding | Resolution | Status |
|---|---|---|---|---|---|
| — | — | — | No critical or major code findings. | — | — |
| L77-M1 | atari2600-reviewer | 🟠 Major (wording) | The doc claimed the two frames have "the same brightness"/the stack is "steady"; the TIA luma codes differ and the rendered brightness varies with hue, so the alternation is mildly flickery | "At the same TIA luminance level; the composite luma stays close to constant on real hardware, but the rendered brightness still varies with hue; close to steady" | Fixed |

### Minor

| ID | Finding | Resolution | Status |
|---|---|---|---|
| L77-m1 | Band 5 "pale rose" vs the arithmetic (lavender) | "Pale lavender (periwinkle)"; "white-ish" consistent | Fixed |
| L77-m2 | Ex2 hint 3 said all three writes beat 22.67 | PF0 22.67, PF1 28.0, PF2 38.7; first row 19/26/33, later 14/21/28 | Fixed |
| L77-m3 | Ex2 hint 4 said the pattern is latched for the whole line | The PF registers are live; a later write blanks the rest of the line | Fixed |
| L77-m4 | Frame ledger labelled LDA/STA with the STA start | `STA COLUBK`: LDA 37/7, STA 37/11 -> 37/14; bands 1-7 STA 14 -> 18 | Fixed |
| L77-m5 | "CTRLPF=0 no playfield" | The playfield is blank because PF0/1/2 are zero | Fixed |
| L77-m6 | The reset StagePalette "without it the first frame draws RAM" | Redundant first staging; the first blank stages again | Fixed |
| L77-m7 | Dead `DEMO_SEGMENTS`; `FrameLo` unlisted | Removed; `FrameLo` documented as the frame counter | Fixed |
| L77-m8 | Ex2 607 rows / 3-pixel shift | 606 rows / 3-row vertical shift; the captures are local verification, not committed | Fixed |
| L77-m9 | Muted-player note missing | "Javatari starts muted; this ROM is silent." | Fixed |
| L77-m10 | The build-time assertion was vacuous | `!if BAND_COUNT * BAND_LINES != 192` | Fixed |
| L77-m11 | StagePalette 136 vs ~155; "six instructions" vs nine; ex1 capture times | ~155 (135 loop); eight instructions + WSYNC; 3.5/5.5/7.5 s | Fixed |

## Lesson 78

### Critical / major

| ID | Source | Severity | Finding | Resolution | Status |
|---|---|---|---|---|---|
| L78-M1 | atari2600-reviewer, curriculum-auditor | 🟠 Major | The status gauge's row 0 was not blank: the prelude stored the next row's enable in ENAM0, so the gauge was 5/9/15/17-19 and grew when the key was held | The prelude stores zero to ENAM0/ENAM1; M0 line 0, M1 line 1; the loop enters with TmpM0/TmpM1; captures 8/12 | Fixed |
| L78-M2 | atari2600-reviewer, curriculum-auditor | 🟠 Major | The room kernel never computed row 0 (a player at row 0 lost the top 4 lines) and never cleared GRP0/GRP1/ENABL (a player at row 32 repeated the bottom row through the lower band) | Row 0 computed in VBLANK and loaded in the room band; the lower band clears GRP0/GRP1/ENABL; row 0/32 checks | Fixed |
| L78-M3 | atari2600-reviewer, curriculum-auditor | 🟠 Major | Exercise 1's room-4 gauge was 19 visible lines, not 20, because the disable landed before the last missile pixel | The clear moved to the room setup after the last status line's pixel 0; ex1 gauge 61 px / 20 lines | Fixed |

### Minor

| ID | Finding | Resolution | Status |
|---|---|---|---|
| L78-m1 | ex2 ResetGame did not clear DoorOpen/DoorLocked/CarryGfxOffset | Cleared; CarryColor defaults to C_KEY | Fixed |
| L78-m2 | ex2 gem at x=4 (picked up on entry); no-carry state unreachable | Gem at x=40; the no-carry variant omits both pickups | Fixed |
| L78-m3 | "Full-width edge" was 64 px; later 4 vs 3 lines | PF0/1/2=$FF; three full-width lines stated | Fixed |
| L78-m4 | C_WALL0=$46 called blue-grey | Red (hue 4) in the source/doc | Fixed |
| L78-m5 | Key "four rows below" | Four rows above | Fixed |
| L78-m6 | What's Next did not link Lesson 79 | Lesson 79 linked | Fixed |
| L78-m7 | Frame 248 vs 249 | 249 | Fixed |
| L78-m8 | Stale headers (8 vs 10-byte, five rooms, six vs seven objects, RAM maps) | Corrected in main/ex1/ex2 | Fixed |
| L78-m9 | RowEffects seam claimed "without recolouring a wall" | One-line seam documented; the header split | Fixed |
| L78-m10 | HMM0/HMM1 clears inside the 24-cycle window | Moved to VBLANK; captures gauge x≈21/key x≈41 | Fixed |
| L78-m11 | Room setup top seam; lower-band/LowerStart line numbers; ex2 BEH_LOCKED/P1 comments | Documented/corrected | Fixed |

### Accepted limitations

| ID | Limitation | Why accepted | Ruling |
|---|---|---|---|
| L73-L1 | The second state reproduces the visible-line HMOVE stall/shift, not a bit-exact Cosmic Ark comb pattern. | The historical register sequence is not documented in a form the course can cite; the lesson proves the mechanism it uses. | Accepted by the review |
| L73-L2 | The per-line star map is frame-phase sensitive: the walk is deterministic, but the mask scroll changes which lines are stars, so two captures do not share per-line values. | The scroll is the lesson's animation; the doc claims a bounded table-driven walk, not a frame-stable map. | Accepted |
| L73-L3 | The bar check is against the 960x606 window capture, not a native TIA framebuffer. | The course's standard evidence; the left 8-px border strip is visible and measured. | Accepted |
| L73-L4 | Planet row 14 reads 72 px in the capture vs the design 76 (4-px latch/sampling). | The limb is continuous with 0 sky gaps; the difference is one PF chunk at the edge. | Accepted |
| L73-L5 | M0 lands at X=78 with `STAR_START=73` (+5 measured calibration); the ball lands at 83. | The walk's relative steps are the table; the absolute offset is calibrated and disclosed. | Accepted |
| L73-L6 | The overscan timer is 35, not 36; the frame is 262. | With 36 this build measured 263 lines; 35 + the WSYNC anchor gives the correct frame. | Accepted |
