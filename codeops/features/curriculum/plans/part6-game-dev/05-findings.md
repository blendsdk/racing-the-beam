# Findings Ledger: Part 6 — Game Development (Lessons 38–47)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Planning — no lesson reviews have run yet
> **CodeOps Artifact Schema**: 1

## Severity Legend

🔴 CRITICAL — blocks the lesson · 🟠 MAJOR — must be fixed before the lesson is done ·
🟡 MINOR — fix or explicitly accept · ℹ️ INFO — context or a false positive.

The plan-level preflight findings live in [00-preflight-report.md](00-preflight-report.md).
This ledger records the per-lesson review findings; a row is appended when a specialist reports
it and is updated with the fix/acceptance decision. A lesson is done only when its rows show
**0 critical / 0 major open**.

## Rows

| ID | Phase | Severity | Finding | Resolution |
| --- | --- | --- | --- | --- |
| SR-101 | 38 | 🔴 CRITICAL | Both reviewers: `GRP0` was not cleared after the play area; at `PlayerY=156` P0 smeared through the hit bar and the next frame's bands and could latch a false P0–playfield collision from the bar. | fixed — line 171 preloads the bar and line 172's HBLANK clears `GRP0`/`ENAM0`/`ENAM1`; visible-24 clears all five objects. The re-captured P0-at-156 check shows no red below visible 171. |
| SR-102 | 38 | 🟠 MAJOR | Reviewer: the hit-bar table used `PF2=$80/$C0/$E0` for 13/14/15 chunks; PF2 bit 0 is leftmost, so the bar had a 28-px hole and a right-edge stub. | fixed — `$01/$03/$07` in all four sources; a Hits=15 capture shows 15 contiguous chunks per half. |
| SR-103 | 38 | 🟠 MAJOR | Auditor: exercise 2 never disabled `ENAM1` outside zones C/D/E; the missile ghosted through the bands and could set a false `CXM1P` bit 7. | fixed — `ENAM1` is cleared in the visible-24 setup and line 172's HBLANK. |
| SR-104 | 38 | 🟠 MAJOR | Auditor: Lesson 38's 1-px ball calibration contradicts Lesson 29's ball row. | fixed as documentation — the doc states the two rows disagree, this ROM's committed capture is the authority, and Lesson 29 needs a re-measure in its own commit. |
| SR-105 | 38 | 🟡 MINOR | Reviewer: M0 was drawn one pixel left of P0 because the missile reset is one clock shorter than a player's. | fixed — the missile target uses `POS_BIAS + 1` (M0 and ex2's M1). |
| SR-106 | 38 | 🟡 MINOR | Reviewer: P0's right clamp was 136, 8 px short of the right wall at 144. | fixed — `P0_MAX_X = 144`, so P0 spans 144–151 inside the wall. |
| SR-107 | 38 | 🟡 MINOR | Both reviewers: `CollStep` stored the full mask while the doc/ST described the 0→1 edge. | fixed — `CollMask` = full mask, `CollStep` = the edge bits; doc/ST updated. |
| SR-108 | 38 | 🟡 MINOR | Reviewer: "the bands are the only part that moves without the player" was false. | fixed — "changes colour". |
| SR-109 | 38 | 🟡 MINOR | Auditor: the prerequisites named Lesson 30 (unused) and omitted Lesson 28 and 33 (used). | fixed — 28, 29, 31, 33. |
| SR-110 | 38 | 🟡 MINOR | Auditor: exercise 1's expected result omitted that each ball contact sets two mask bits and advances the bar two chunks. | fixed — the doc says so. |
| SR-111 | 38 | 🟡 MINOR | Auditor: exercise 3's expected result assumed the auto-demo produces M0–P1. | fixed — the doc names the three auto pairs and the fourth via auto-fire/fire. |
| SR-112 | 38 | 🟡 MINOR | Reviewer: the missile enable lands after the pixel window when M0 is far left, so M0's first row can be one line low. | accepted and documented — the kernel timing is unchanged; the doc's tip states the one-line offset and that the M0–P1 witness at frame 2936 is from the committed ROM. |
| SR-113 | 38 | 🟡 MINOR | The screenshots predated the fixes; the reviewer asked for provenance from the rebuilt ROM. | fixed — both re-captured from the current committed ROM; the doc's P0/P1 measurements were updated to the new frames. || SR-201 | 39 | 🟠 MAJOR | Both reviewers: the doc taught the wrong VDEL model ("the value written on line N is displayed on N+1; the stores are written on the line before"), which would leave one byte repeated across the three copies. | fixed — the doc, library comment, and lesson headers now teach the cross-latch: a write stages a pending byte and the other player's write commits it; the first three stores are in HBLANK, the last four are the 3-cycle run, and the seventh `STA GRP0` commits P1's col 5. |
| SR-202 | 39 | 🟡 MINOR | Reviewer: the doc mixed TIA X with absolute color clocks and said the six stores are evenly 3 cycles apart. | fixed — the first copy is TIA X=56 = TIA cc 56–63 = absolute cc 124–131; the first three stores are 7 cycles apart (3/10/17), the last four are 3 cycles apart (45/48/51/54). |
| SR-203 | 39 | 🟡 MINOR | Both reviewers: §2, Step 4, and the table disagreed about whether the row stores run on line 0 or line 1. | fixed — the stores execute on the same visible line that displays the row; row 7 is staged on line 1, rows 1–8 display, the `ScoreDrawRow` 37/26 hit is the WSYNC stall, and the store is at 38/0. |
| SR-204 | 39 | 🟡 MINOR | Auditor: the doc claimed a burst capture of 000009/000010/000011 that was not recorded or committed. | fixed — replaced with the frame-202 `ScoreAdd` A=00 X=05 then A=01 X=04 evidence; the committed captures are only 000001/000002. |
| SR-205 | 39 | 🟡 MINOR | Auditor: exercise 1's expected reset log said six calls, but `ScoreClear` already logs six. | fixed — twelve calls: six from `ScoreClear` (X=0) and six exercise calls (X=0..5), then A=5/X=6 on the first hit. |
| SR-206 | 39 | 🟡 MINOR | Auditor: the debugger paragraph never named the RAM/TIA state to inspect. | fixed — `$A0–$A5` digits, `$A8–$D7` buffer, `NUSIZ0/1=3`, `VDELP0/1=1`. |
| SR-207 | 39 | 🟡 MINOR | Auditor: the plan said `ScoreSetup` uses `SetPos` (no such routine), the play area ended at 171, and the target was X=64–96. | fixed — "the Lesson 26 divide-by-15 positioning with the +3 bias", play area 9–191, target X=64–95 (AR-14 too). |
| SR-208 | 39 | 🟡 MINOR | Auditor: the plan task/findings ledger were not updated. | fixed — 2.1.1 `[x]`, progress 2/10, Session A/C records, and these ledger rows. |
| SR-209 | 39 | 🟡 MINOR | Reviewer: the first §2 paragraph still used the "8-pixel gaps / between the copies" framing, which contradicts the cross-latch body. | fixed — "the six cells are contiguous; each of the last four writes lands during a copy of its player, and the cross-latch defers it until the other player's write." |
| SR-210 | 39 | 🟡 MINOR | Both reviewers: `include/score.asm`'s `ScoreDraw` header still said the stores run on lines 0–7 and are displayed on 1–8. | fixed — "line 0 is the setup/blank line; the row stores execute on visible lines 1–8 and are displayed there; the cleanup runs after line 8's copies." |
| SR-211 | 39 | 🟡 MINOR | Reviewer: the three exercise sources repeated the main lesson's Checkpoints/Build block, and the repeated build line pointed at the main source. | fixed — one Checkpoints block and one exercise-specific build line per solution. |
| SR-212 | 39 | 🟡 MINOR | Reviewer: exercise 2 claimed the carry reaches the tens digit and that the respawn prevents a double score. | fixed — 000098+1=000099, +1=000100 (the units carries); the once-per-contact guard is the VBLANK read plus `CXCLR`. |
| SR-213 | 39 | 🟡 MINOR | Reviewer: "nothing else has moved" was false while the ball moved from X=44 to X=36. | fixed — the score block and target are unchanged; the ball is at a different point in its sweep. |
| SR-214 | 39 | 🟡 MINOR | Reviewer: the Section 2 write cycles and the Step 7 instruction-start cycle needed a reconciling note. | fixed — "the write cycles in Section 2 are 1-based; Stella's column is the instruction start, so 37/26 becomes a store at 38/0." || SR-301 | 40 | 🟡 MINOR | Reviewer: the doc said the operation bar's writes happen in the HBLANK of visible line 9; the caller resumes at 9/5 and PF2 lands at clock ~69, just past HBLANK (no visible defect, because the PF2 slot starts at 116). | fixed — the doc and source comments give line 9/c5 and clocks 36/54/69 vs the slots 68/84/116. |
| SR-302 | 40 | 🟡 MINOR | Both reviewers: the SED comment said every path enters decimal mode; A=10/$FF return without touching D. | fixed — "every implemented path that enters decimal mode restores binary mode with CLD; A=10/$FF return without touching D." |
| SR-303 | 40 | 🟡 MINOR | Reviewer: exercise 2's SUB1 comment said the slot is never selected, but the build sets its bit and routes it to BCDSub. | fixed — the slot is routed to `BCDSub` before `OpCommand` is read; the `$FF` entry is unused. |
| SR-304 | 40 | 🟡 MINOR | Reviewer: `Borrow` was set once and never cleared, so `$8F` did not describe the last operation. | fixed — `ExecuteOperation` clears `Borrow` alongside `Overflow`; the ex2 ROM was rebuilt and the flag verifies at 61/121/181. |
| SR-305 | 40 | 🟡 MINOR | Reviewer: `BCDCarryMid` is not executed on the ADD 100 path; the doc said "at each boundary". | fixed — "on the ADD 1/ADD 10 path". |
| SR-306 | 40 | 🟡 MINOR | Auditor: the doc's `BCC BCDBorrow` excerpt skipped the `LDA #1` that makes `BCDBorrow` report A=1. | fixed — the excerpt now shows `BCC BCDBorrowHandler`, `LDA #1`, then the checkpoint. |
| SR-307 | 40 | 🟡 MINOR | Auditor: "Adding 1 flips the strip's bits one at a time" is false ($01→$02 flips two bits, $99→$00 all eight). | fixed — the doc gives the bit-change examples and says a decimal carry changes several cells at once. |
| SR-308 | 40 | 🟡 MINOR | Auditor: the doc gave the score bbox as y=110–131; the lit block is y=110–130. | fixed. |
| SR-309 | 40 | 🟡 MINOR | Auditor: the HMOVE table described the label hits incorrectly (HmoveApply 4/45 is the WSYNC stall; the store is 5/0; HmoveDone 5/3 is after it). | fixed — the table now says exactly that. || SR-401 | 41 | 🟠 MAJOR | Both reviewers: the title/over images are debugger `saveSnap` TIA frames composited into window chrome, not a direct `capture-screenshot.sh` capture. | accepted and disclosed — the game pixels are real TIA output of the committed ROM, the chrome is a real Stella window of the same ROM, and the doc now states the method; the plan/ST record the deviation. |
| SR-402 | 41 | 🟠 MAJOR | Auditor: the theory said every input is an edge; the joystick is level-based (held movement repeats). | fixed — fire and SELECT are edges; the joystick is a level. |
| SR-403 | 41 | 🟡 MINOR | Reviewer: the over screen's first visible line wrote COLUBK/PF0/1/2 after the left-half slots, so the 16-line bar was 15 full lines plus a right-half-only first line. | fixed — the over state preloads COLUBK and the top-bar PF bytes in VBLANK; the over image was re-taken and shows 16 solid lines. |
| SR-404 | 41 | 🟡 MINOR | Auditor: exercise 1's pause could lose a contact made on the pause frame because the latch edge was consumed while paused. | fixed — the resume path clears `PrevColl`; a forced pause-on-contact probe shows `HitStep` A=1 at 293. |
| SR-405 | 41 | 🟡 MINOR | Auditor: the theory snippet branched to `PlayState`/`OverState`; the ROM uses `DoPlayState`/`DoOverState` trampolines. | fixed — the snippet uses the real labels and explains the out-of-range branches. |
| SR-406 | 41 | 🟡 MINOR | Auditor: prerequisite said "Lesson 40 (the per-state display pattern)"; Lesson 40 is a single-screen monitor. | fixed — "Lesson 40 (the score/monitor display pattern)". |
| SR-407 | 41 | 🟡 MINOR | Auditor: the bar alt text said one 15-chunk bar; the image shows two 15-chunk halves with a centre gap. | fixed — "15 chunks per half (two segments with a centre gap)" in the title sentence and both alt strings. |
| SR-408 | 41 | 🟡 MINOR | Reviewer: the doc claimed the play kernel's first store was in HBLANK at cycle ~17; steady state is ~24, just before the X=8 ball pixel at clock 76. "720 white pixels" is the 6x capture width, not TIA. | fixed — the doc states the ~24–25 cycle store and the X=8 margin; "120 TIA pixels (720 in the 6x capture)". |
| SR-409 | 41 | 🟡 MINOR | Auditor: Lesson 40's What's Next promised the BCD score would become Lesson 41's play score; Lesson 41 uses the hit bar. | fixed — Lesson 40's What's Next now says Lesson 41 counts hits with the 15-chunk bar; the score payoff stays later. |
| SR-410 | 41 | 🟡 MINOR | The plan's Lesson 41 RAM list still had `Lives (3)` and the expected screen promised a play capture; neither is in the delivered set. | fixed — `Lives` removed (it arrives in Lesson 42), the expected screen names the two captures, and the screenshot method is recorded. |
