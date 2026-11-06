# Findings Ledger: Part 7 — Kernel Mastery (Lessons 48–55)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Part 7 complete — 0 critical, 0 major open.
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
| SR-48-001 | 48 | 🟡 MINOR | Both reviewers: `Diamond1PF0:` was defined twice on consecutive lines in the demo and exercise 1/3; ACME tolerated it, but it is a latent trap. | fixed — one label in each source; the doc's Full Source re-injected; the ROMs are byte-identical. |
| SR-48-002 | 48 | 🟠 MAJOR | The curriculum auditor: the mode-2 dispatch was documented as 8 cycles; the chain is 12 (`LDA` 3 + `BEQ` 2 + `CMP` 2 + `BEQ` 2 + `JMP` 3). | fixed — the doc says 6/10/12 and the source comment 6-12. |
| SR-48-003 | 48 | 🟡 MINOR | The page-cross prose said four crosses (49/27); the page-aligned tables have at most one (46/30). | fixed — the doc and source say 45+1=46, leaving 30; the Step 9 table is 35/6/7/48. |
| SR-48-004 | 48 | 🟡 MINOR | The RAM walkthrough said "forty bytes, `$80–$8E`"; the map is fifteen bytes. | fixed — fifteen bytes, `$8F–$F7` free. |
| SR-48-005 | 48 | 🟡 MINOR | Exercise 2's `PF2=$00` comment described the diamond tip `$80`; the boundary preload comment said `$00/$00/$80` though the code stores `$00`. | fixed — "no chunks lit; the diamond tip's `$80` would light chunks 19-20"; the boundary is `$00/$00/$00`. |
| SR-48-006 | 48 | 🟡 MINOR | Exercise 1/3 kept the demo's stale `ZoneCount`/`LineCount`/`PairCount` comments (2/96/48) although the exercise uses 3/64/32 and 3/0/88. | fixed — the comments describe the exercise's modes. |
| SR-48-007 | 48 | 🟡 MINOR | The doc called `LineRow2`/`PairRow2` "second-pass copies"; they fire on both passes. | fixed — "the labels inside the two-pass loops; they fire on both passes." |
| SR-48-008 | 48 | 🟠 MAJOR | The curriculum auditor: exercise 2's hint said the 2-line sample spans visible 16–79; mode 0's bottom zone displays it at 112–175. | fixed — the hint gives 16–79 for the full 2-line first pass and 112–175 for mode 0's bottom zone. |
| SR-48-009 | 48 | 🟡 MINOR | The `HmoveApply` label sat on `STA HMOVE` (line 5/0) while the table claimed line 4/56; the exercises had the same placement. | fixed — the label is above `STA WSYNC` in the demo and the three exercises; `HmoveApply` $F156 is 4/53, `HmoveDone` $F15A is 5/3; the doc table/bullet/snippet agree. |
| SR-48-010 | 48 | 🟡 MINOR | The author's pixel record said the split's visible-95 row was 48 TIA px; the source row 95 is `$80` (8 px) and the capture measures 8. | fixed — the evidence records row 71 = 48 px and row 95 = 8 px; the doc's row table was already correct. |
| SR-48-011 | 48 | 🟠 MAJOR | The atari2600-reviewer: the joystick mapping was reversed — `$40` (the masked value for a right press) reached `DashLeft`, so left and right were swapped. | fixed — `$80` reaches `DashLeft` (DEC) and `$40` reaches `DashRight` (INC); `-holdjoy0 L` hits `DashLeft` A=$80, `-holdjoy0 R` hits `DashRight` A=$40; the ROMs were rebuilt. The doc explains the raw masks ($40 left/$80 right) and the masked values ($80 left/$40 right). |
| SR-48-012 | 48 | 🟡 MINOR | Exercise 3's footer PF0 store landed after the left PF0 slot, leaving a 4-px notch on the footer's first line. | fixed — the footer writes PF0/PF1/PF2 first, then COLUPF, then clears the players; the ex3 ROM was rebuilt. |
| SR-48-013 | 48 | 🟡 MINOR | Exercise 1/2's dispatch comments said 6-14 cycles; the chains are 6-13 and 6-12. | fixed. |
| SR-48-014 | 48 | 🟡 MINOR | Exercise 3's first-row comment said every mode preloads the diamond tip; mode 3 preloads the header. | fixed — "except mode 3, whose first row is the header." |
| SR-48-015 | 48 | 🟡 MINOR | The manual fire press was not exercised in the state log; the auto-demo calls the same `AdvanceMode`. | accepted and disclosed — the doc says "a manual fire press was not exercised in the state log"; SELECT is logged with `-holdselect`. |
| SR-48-016 | 48 | 🟡 MINOR | The page-cross comment had "Even the the" and "leaving 30 line"; the 2-line note implied a possible cross although its tables are page-contained. | fixed — "Even the aligned tables add at most one page cross (45 + 1 = 46), leaving 30 cycles; the 2-line pair (48, page-contained) leaves 104." |
| SR-49-001 | 49 | 🟠 MAJOR | The hardware reviewer: the first-scanline timing model mixed the first-row and steady-state stores and attributed the visible lag to `PF2` only; the `PF1` store sits exactly on its chunk-4 deadline (0 px margin) and the taking `BNE` adds a page-cross cycle. | resolved — the doc/source/plan now use the steady-state stores 15/22/29/36/43/50/57, the row-8 `PF1` notch, the `PF2` 43→pixel 61 lag, the `GRP0` X≈82, and the effective **63**-cycle body (62 nominal; 89/44.5 margin). |
| SR-49-002 | 49 | 🟡 MINOR | The late `GRP0` cutoff said X≈56; cycle 49 applies from pixel 79 (steady 50 → 82). | fixed — X≈82. |
| SR-49-003 | 49 | 🟡 MINOR | The mountain-edge pixel check's "Measured" cell repeated the formula; the measurement is 74/84 exact, 10 within one chunk. | fixed — the measured aggregate and the model's windows (row 8, PF2 42/48/54) are stated; the extra rows are at the one-chunk threshold. |
| SR-49-004 | 49 | 🟡 MINOR | The bird's lit box was checked as rows 60–75; the lit bytes are 62–71 (the 16-line slot is 60–75). | fixed. |
| SR-49-005 | 49 | 🟡 MINOR | Ex1's "same picture" overclaimed; the unrolled body shifts the store phase. | fixed — "visually identical"; the odd-row PF1/PF2/sky improvements and the even-row bird lag are disclosed. |
| SR-49-006 | 49 | 🟡 MINOR | The captions said "at the left/right" while the captures are X≈13/142. | fixed — "near the left/right of its travel". |
| SR-49-007 | 49 | 🟡 MINOR | The PF2 lag was attributed to "chunks 12–19"; only rows 42/48/54 have their new chunk before pixel 61 (row 60's chunk 15 loses one pixel). | fixed. |
| SR-49-008 | 49 | 🟡 MINOR | Step 2 said "three later stores"; five stores (PF1, COLUPF, PF2, COLUBK, GRP1) land in the visible area. | fixed. |
| SR-49-009 | 49 | 🟡 MINOR | The `OverscanStart` cycle explanation added a "jump to the frame end"; cycle 6 is the loop tail (INY + CPY + the not-taken BNE). | fixed. |
| SR-49-010 | 49 | 🟡 MINOR | Ex1's expected result omitted the even-row bird lag (GRP1 at ~59 → pixel 109; the bird starts at X=104). | fixed — the even-row bird's left 5 px can lag. |
| SR-49-011 | 49 | 🟡 MINOR | The first-row preload was said to cost 35 cycles; the seven LDA/STA pairs cost 49 (about 54 with setup). | fixed. |
| SR-49-012 | 49 | 🟡 MINOR | The page-cross example used page+96; a 96-byte table at page+96 occupies 96–191 and cannot cross at Y≤95. | fixed — page+192 (or page+161/Y≥95). |
| SR-49-013 | 49 | 🟡 MINOR | ST-49.3 said `KernelRow` A=0→95; the checkpoint reports Y. | fixed — Y=0→95. |
| SR-49-014 | 49 | 🟡 MINOR | The prerequisites listed Lesson 21 (asymmetric playfield), 29 (ball) and 32 (VDEL), none used by this lesson. | fixed — 12/14/17/18/19/20/25/26/28/31/48. |
| SR-49-015 | 49 | 🟡 MINOR | The held-joystick logs release after ~22 frames; the clamp evidence is the auto-demo and the code. | fixed — the doc says the branch/DEC/INC is logged and the auto-demo demonstrates the 8/144 clamps. |
| SR-49-016 | 49 | 🟡 MINOR | Ex3's `P0_MAX` comment said the third copy's last pixel is X+32+8 = 160; 160 is the first off-screen pixel (the visible field is 0–159). | fixed — X+32+7 = 159 (last visible). |
| SR-49-017 | 49 | 🟠 MAJOR | The headline ledger said 62/90/45; the loop's taken `BNE` crosses a page, so the effective body is 63 and the margin is 89 (44.5/line); ex1's 119 becomes 120/184/46, and ex3 is 63. | fixed — the doc/source/plan state 62 nominal / 63 effective; ex1 120/184/46; ex2 62 (its `BNE` is page-local); ex3 63. |
| SR-49-018 | 49 | 🟡 MINOR | The 10 measured edge rows were attributed to "the PF1 step rows and the PF2 inner-edge rows" (15 named); the model's visible windows are row 8 and PF2 42/48/54. | fixed — the extra measured rows are at the capture's one-chunk threshold. |
| SR-49-019 | 49 | 🟡 MINOR | The ex1 challenge/source header said the picture is "identical"; the store phase differs. | fixed — "visually identical" in both. |
| SR-49-020 | 49 | 🟡 MINOR | The `COLUBK` deadline range was 26.7–49.0; the pass closes at e=20 (no sky), so the range is 26.7–48.0. | fixed. |
| SR-50-001 | 50 | 🟠 MAJOR | The `HMBL` clear ran ~10 machine cycles after the score `HMOVE`, violating the TIA's 24-cycle no-motion-write rule; on real hardware the ball's fine move could be applied wrongly (Stella masks it). | fixed — the clear moved to status line 50, after `SetGameP1`, >24 cycles after `ScoreHmove` and before `GameHmove`; all four ROMs regenerated; the doc/source/snippets explain the rule. |
| SR-50-002 | 50 | 🟡 MINOR | The exercise comments said the game HMOVE blanks "line 52"; the strobe is on line 51 and blanks its own line. | fixed — line 51 in ex1/ex2/ex3 and the main. |
| SR-50-003 | 50 | 🟡 MINOR | The doc said the ceiling band's writes land before chunk 0's cycle 22.7; the ceiling's PF2 completes at ~23. | fixed — "before each register's first chunk"; PF2's first chunk is 12 (cycle 38.7); the measured band cycles are stated. |
| SR-50-004 | 50 | 🟡 MINOR | The exercise hit-period explanation said the player's head is higher; on screen the head stays at 151–182; the play zone (and the ball) starts lower. | fixed — "the play zone starts four/eight lines lower while the head stays at 151–182"; the exercise periods are measured (101/97). |
| SR-50-005 | 50 | 🟠 MAJOR | The HMBL move shifted `BodyStart`/`StatusStart` by 4 bytes; the doc's `$F15D`/`$F160` addresses no longer hit the labels. | fixed — the current symbols are `$F159`/`$F15C`; the table, both commands, and the bullet are updated; the re-logged checkpoints are 37/5 and 46/5. |
| SR-50-006 | 50 | 🟡 MINOR | The Step 3 listing omitted the `HMBL` clear, contradicting Step 2/Section 3/the full source. | fixed — the listing shows the clear before the line-50 `WSYNC`. |
| SR-50-007 | 50 | 🟡 MINOR | Exercise 3 still said "line 52". | fixed — line 51. |
| SR-50-008 | 50 | 🟡 MINOR | Exercise 2's RAM allocation header said `($80-$88)` while the file uses `$89`/`$8A`. | fixed — `($80-$8A)`. |
| SR-50-009 | 50 | 🟡 MINOR | Exercise 2's map said `$89-$9F` free while `TimerLevel=$89`/`TimerTmp=$8A`. | fixed — `$8B-$9F` free. |
| SR-50-010 | 50 | 🟡 MINOR | The exercise hit periods 101/97 were derived; the base's 105 was logged. | fixed — the exercise `ScoreAdd` logs: ex1 102/203/304/405/506 (101), ex2 98/195/292/389/486 (97). |
| SR-50-011 | 50 | 🟡 MINOR | Exercise 1/2's P1 strip comments said visible 29–60; the resized play zones put P1 at 33–64 / 37–68. | fixed. |
| SR-50-012 | 50 | 🟡 MINOR | Exercise 3's field comment said visible 25–181; the field ends at 182. | fixed. |
| SR-50-013 | 50 | 🟡 MINOR | The doc's level-1 expectation said "chunks 2"; level 1 lights exactly one chunk (chunk 2). | fixed — "chunk 2". |
| SR-51-001 | 51 | 🟡 MINOR | Both reviewers: the cycle parenthetical said 39 to the write/42 to the WSYNC and 18/21 on the short path; a zero-page `STA GRP0` is 3 cycles. | fixed — the source/doc now say 42→44→47 (line 1), 35→37→40 (line 2), short 14→16→19; the 48/41/89 ledger is unchanged. |
| SR-51-002 | 51 | 🟡 MINOR | The `OBJ_MAX_Y=88` bound let P1's last line land on play 184 (the first overscan line) for some X. | fixed — `OBJ_MAX_Y=87` in all four sources; row 90's last line is play 182; doc/03 state the bound and why 88 clips P1. |
| SR-51-003 | 51 | 🟡 MINOR | The doc never explained the latch persistence that turns four shape bytes into 8 lines; the ex3 hint said each enemy is "one scanline of every row". | fixed — a "why four bytes are eight lines" paragraph in the source and Section 3; ex3 hint 4 and the source header say both are 8-line objects (P1 one line lower). |
| SR-51-004 | 51 | 🟡 MINOR | The green diamond was reported as TIA X=93; the diamond's ink starts two columns into the sprite. | fixed — the captures were re-taken and the doc reports first-ink positions only (red 71, green 83, blue 92, gold 84). |
| SR-51-005 | 51 | 🟡 MINOR | `SHAPE_MASK` was dead in all four sources; `Frame` was zeroed/incremented but never read, and the 32-byte claim counted it. | fixed — both removed; the persistent state is 31 bytes `$80–$9E`, `$9F` free, `$A0` Tmp; doc/03/99 updated. |
| SR-51-006 | 51 | 🟡 MINOR | 03 still said "object 0 on the first line, object 1 on the second" and "about 43/about 93"; ST-51.3 inherited the wording. | fixed — the P0-slot/P1-slot wording; the stale estimate is deleted; ST-51.3 matches the A=1/3 and A=0/2 logs. |
| SR-51-007 | 51 | 🟡 MINOR | "Stella keeps one `-break` per run" is false (Lesson 48 passes four). | fixed — "Run each checkpoint separately for a readable log." |
| SR-51-008 | 51 | 🟠 MAJOR | The re-taken capture captions/table put the lower (nearer) object on P1 and the higher object on P0, inverting the lesson's rule. | fixed — red/blue are P0 (nearer, line 1), green/gold are P1 (farther, line 2, one line lower); the measured rows confirm it. |
| SR-51-009 | 51 | 🟡 MINOR | The latch warning said the object's "lit height is seven scanlines" without explaining P1's one-line offset, and "the skew disappears" described P0 only. | fixed — the warning now states P0 shifts one line (seven lit inside the window), P1 is always one line lower, and at X≤35 shifts again; the shape is shifted, not truncated. |
| SR-51-010 | 51 | 🟡 MINOR | The `OBJ_MAX_Y` fix left "(88 + 3 = 91)" in the main and exercise-1 comments. | fixed — "(87 + 3 = 90, rows 0..91)". |
| SR-51-011 | 51 | 🟡 MINOR | The doc's exercise-2 hint and 03 still said `$80–$9F` for the four-object arrays. | fixed — `$80–$9E`. |
| SR-51-012 | 51 | 🟡 MINOR | `SkipWrite` was described as "cycle 42" for every row; the short path is 21, and the first play line is 31. | fixed — the bullet separates the short/long paths and notes the first-line exception (store completes at 54, still inside 76). |
| SR-51-013 | 51 | 🟡 MINOR | The prerequisites listed the ball (29, unused) and omitted the timer (15) and playfield/`CTRLPF` (19). | fixed — 15 and 19 added, 29 removed, in the doc and 03. |
| SR-51-014 | 51 | 🟡 MINOR | The exercise-2 hint said the status strip "grows to 14 chunks"; the cells span chunks 0–18. | fixed — "19 chunks (14 lit cell chunks across 0–18)". |
| SR-51-015 | 51 | 🟡 MINOR | The capture analysis said the blue cross shows 6/13/6 rows while the table measured 24 rows. | fixed — the measured groups are 6/12/6 (24 rows). |
| SR-51-016 | 51 | 🟡 MINOR | The exercise-3 source header said each enemy is "one scanline of every row". | fixed — both players are 8-line objects; P1 is one line lower. |
| SR-52-001 | 52 | 🟠 MAJOR | The doc prerequisite line still listed Lesson 29 (the ball, unused) and omitted Lesson 15 (the RIOT timer), contradicting the same-diff 03 fix. | fixed — 15 in, 29 out, doc and 03 aligned. |
| SR-52-002 | 52 | 🟠 MAJOR | The latch boundary was stated as X≤39 / 40 / ≥41 from bbox transitions, contradicting the pixel-43 anchor and the 8-pixel rule. | fixed after a measured X=34–48 sweep: the latch is ~43–44; X≤36 wholly old, X=37–43 straddles, X≥44 current. The bbox transitions at 40/41 are explained by the shape's narrow top/bottom rows (ink at columns 3–4); doc, headings, takeaway, and all four source headers updated. |
| SR-52-003 | 52 | 🟡 MINOR | The three exercise headers built/ran `lesson52.bin` from the main source. | fixed — each builds `build/exercise-0N.bin` from its own solution. |
| SR-52-004 | 52 | 🟡 MINOR | `C_BG=$02` was labelled "very dark blue"; `$02` is neutral dark grey. | fixed — "the gap and the borders: the background" in all four sources. |
| SR-52-005 | 52 | 🟠 MAJOR | The 40-cycle ledger missed the taken `BNE`'s page cross: `BNE KernelRow` at $F100 targets $F0E6, so the tail is 10 and the body 41 effective. | fixed — main/ex2/ex3 are 40 nominal / 41 effective, margin 35, last row 39 (2 instead of 4); ex1 is page-local at 40; an off-boundary plane is 42; doc/03/07/99/AR/preflight updated. |
| SR-52-006 | 52 | 🟡 MINOR | `HmoveDone` was described as the HMOVE store; 3/3 is the NOP and the store completes at 3/2. | fixed — the table, Step 4, and the four headers say the NOP; the inline "store has executed" comment remains. |
| SR-52-007 | 52 | 🟡 MINOR | The HMOVE drift sentence said "left"; HMP0 is signed and is −2 at X=80, so it drifts right. | fixed — "the direction follows HMP0's signed value (right at the power-on X=80, where HMP0=$E0, i.e. −2)." |
| SR-52-008 | 52 | 🟡 MINOR | Exercise 1's header copied the base lesson's 35/37 store cycle pair although its page-local BNE makes the store 34/36. | fixed — "the base lesson's measured log puts its store at 35/37; this layout's 9-cycle tail makes it 34/36". |
| SR-52-009 | 52 | 🟡 MINOR | The doc's "fit in 40 of the 76 cycles" was nominal-only. | fixed — "40 nominal / 41 effective". |
| SR-52-010 | 52 | 🟡 MINOR | The checkpoint-cycle convention (a label reports the first cycle of the following instruction) was unstated. | fixed — one sentence added to the debugger section. |
| SR-53-001 | 53 | 🟠 MAJOR | Ex3's fill band (third in the order) stored `COLUBK` only inside `KernelFill`, so its first line's left edge kept the ramp's last colour. | fixed — the `BandFill` macro stores `COLUBK` before the JSR; the first fill line measures `$B8` at the left edge; the band stays 48 lines and `OverscanStart` 229. |
| SR-53-002 | 53 | 🟠 MAJOR | The band-boundary paragraph said the fill returns in 10 cycles but parenthesized "seven tail + six RTS" = 13; the other routines' 7+6 = 13. | fixed — fill = four tail (DEX 2 + not-taken BNE 2) + 6 RTS = 10; others = seven + 6 = 13; the first-store window is ~10 (12 after the fill). |
| SR-53-003 | 53 | 🟡 MINOR | `KernelFill`'s header said it clobbers A and X; `STA` preserves A. | fixed — "Clobbers X; preserves A and Y." |
| SR-53-004 | 53 | 🟡 MINOR | The carry paragraph said `INC` "adds 4" and the safe bound was `$FD`; `INC` is 5 (net +4 with BCC 2) and `$FC`. | fixed. |
| SR-53-005 | 53 | 🟡 MINOR | The band-2 preload note said twelve cycles; the setup is 15. | fixed — "fifteen". |
| SR-53-006 | 53 | 🟡 MINOR | The fire/SELECT guard sentence dangled and implied SELECT had an eight-frame guard. | fixed — only fire has the guard; SELECT needs none (a held SELECT at power-on only resets to palette 0). |
| SR-53-007 | 53 | 🟡 MINOR | The pixel-0 rule listed `COLUPF` both as a pixel-0 store and as having slack, and omitted the PF2 ~24/38.7 exception. | fixed — PF0/COLUBK are the pixel-0 stores; COLUPF/COLUP0 have the blank first row's slack; PF2's field starts at 38.7. |
| SR-53-008 | 53 | 🟡 MINOR | Ex1's comments still said 48 bytes / index 47 / PF pointer 0..69 / band-4; its strip is 38 bytes, last index 37, PF 0..54, band-5. | fixed — 38 bytes used of the 48-byte block, index 37, 0..54, band-5, `$A0-$C5`, defensive GRP clears. |
| SR-53-009 | 53 | 🟡 MINOR | `RampTable` did not exist; the labels are `RampFwd`/`RampRev`. | fixed in the sources and doc. |
| SR-53-010 | 53 | 🟡 MINOR | Ex2's banner still said SELECT resets the palette; it toggles RampPhase 0/24. | fixed — banner, RAM range `$83-$95`. |
| SR-53-011 | 53 | 🟡 MINOR | Ex3's header said PatternStart A=0..3; the order is 1,3,0,2. | fixed — four hits A=1,3,0,2; the Band3/4Setup names report the sprite/ramp slots. |
| SR-53-012 | 53 | 🟡 MINOR | The library API omitted that `KernelPFRows` advances `KernelPtr` by 3 × rows and that `KernelRows` must be >= 1. | fixed — both stated; the return timing (10/13) documented. |
| SR-53-013 | 53 | 🟡 MINOR | The 03 ledger still used Y=2..0/`LDY #2`/two DEYs; the code is Y=0..2/`LDY #0`/two INYs. | fixed — 57/row = 28.5/line, PF0→PF2. |
| SR-53-014 | 53 | 🟡 MINOR | Band 4 cleared GRP1 although nothing writes it, while the doc said redundant clears are skipped. | fixed — documented as a defensive clear (six cycles, boundary stays symmetric); doc rule 2 and ST-53.3 match. |
| SR-53-015 | 53 | 🟡 MINOR | Ex3's PF-table comment said rows 1–23 alternate, but row 23 is blank. | fixed — rows 1–22 alternate; row 23 is blank so the ramp's late PF0 clear cannot show. |
| SR-54-001 | 54 | 🟠 MAJOR | The starfield's ship `GRP0` store landed after P0's pixels (effect ~cycle 51 vs X=76's 48), so the ship rendered one line low: row 176 blank, 15 visible rows, and the "16-line ship" was false. | fixed — the starfield is split at row 176; the bottom loop stores GRP0 unconditionally (store 39), 16 hits Y=176–191, capture top 176.5. |
| SR-54-002 | 54 | 🟡 MINOR | The starfield's PF stores came after the 11-cycle clears, so PF0/PF1/PF2 missed the left-half slots and the mirrored stars sat one line apart. | fixed — PF0/PF1/PF2 are stored first; the starfield ledger is 54 plain/star and 62 ship. |
| SR-54-003 | 54 | 🟡 MINOR | The three ball/missile clears + compares made the rightmost star late; the per-line compare cost was the bulk of the 65/69/71 ledger. | fixed — three page-aligned 192-byte enable tables; enables 37/44/51; the stars remain X=111/127/143 rows 32/96/160. |
| SR-54-004 | 54 | 🟡 MINOR | The road stored PF1/PF0 and the car before PF2, so PF2 missed chunk 12 at pulse 1/2. | fixed — PF2 first (latch 23/32/36 vs 39), car 43 vs 48; the dead PF1/PF0 stores removed; one 192-byte PF2 plane. |
| SR-54-005 | 54 | 🟡 MINOR | The pulse was said to widen the inner edge; a right shift adds the outer chunk. | fixed — "outer edge" in the sources and doc. |
| SR-54-006 | 54 | 🟡 MINOR | "PF1's field starts at pixel 44" and "PF1 chunk 11 on the widest rows" were wrong (PF1 is zero). | fixed — the PF1 claim removed; PF0/PF1 are zero and set once. |
| SR-54-007 | 54 | 🟡 MINOR | The stars were documented as nominal X=112/128/144 but measure 111/127/143 (the reset is one clock shorter). | fixed — the doc records the measured values and the one-clock output delay. |
| SR-54-008 | 54 | 🟡 MINOR | Ex1's "worst line 66" and "two cycles" contradicted the 57/65 ledger and the 3-cycle `AND`. | fixed — three cycles, 24 vs 21, measured 57/65; the store values kept as measured. |
| SR-54-009 | 54 | 🟡 MINOR | Ex3's `AND #$7F` is 2 cycles; the worst line is 49, not 68. | fixed — the measured 36/45/49. |
| SR-54-010 | 54 | 🟡 MINOR | Ex3's PF2 preload omitted the centre-gap mask, so row 0 could lose the gap. | fixed — the `AND #$7F` is applied in the preload and both stores. |
| SR-54-011 | 54 | 🟡 MINOR | The horizon's late PF0 store gives ~7 px, not one. | fixed — "about seven pixels" in the doc/source; the source comment explains. |
| SR-54-012 | 54 | 🟡 MINOR | The "why not the ball" argument said four chunks; 8 px vs 32 px is six chunks. | fixed — six chunks (two short of the 16-px half). |
| SR-54-013 | 54 | 🟡 MINOR | The doc said the road is another 768 bytes and "43 cycles on a plain line"; the real PF2 plane is 192 and the margin is 58. | fixed. |
| SR-54-014 | 54 | 🟡 MINOR | "The whole field twinkles" ignored missile 0's shared `COLUP0` (it stays white). | fixed — the doc states the shared register. |
| SR-54-015 | 54 | 🟡 MINOR | What You Should See omitted effect 1 and did not disclose the rainbow is not captured; the Javatari unmute note was missing. | fixed — an effect-1 paragraph, the not-captured disclosure, and the click-to-unmute sentence. |
| SR-54-016 | 54 | 🟡 MINOR | The exercise build headers pointed at the main source and the ex1/ex3 RAM maps were stale. | fixed — each builds its own `build/exercise-0N.bin`; maps `$98-$F7` / `$97-$F7`. |
| SR-54-017 | 54 | 🟡 MINOR | "Each kernel starts with its first store on cycle 0" contradicted BodyStart 37/5. | fixed — the VBLANK-off store completes at cycle 5; the first data stores are 9/7. |
| SR-54-018 | 54 | 🟡 MINOR | The `HmoveApply` table described the label as "the WSYNC before the HMOVE"; the label is on the HMOVE store. | fixed — "the HMOVE store"; the 9/3 (star) and 4/59 (road) values are the measured store cycles. |
| SR-54-019 | 54 | 🟡 MINOR | The plan called the rainbow ramp 192 bytes and the pulse 64-row; the ramp is 192 entries/256 bytes and the pulse is 64 entries. | fixed in 03/99. |
| SR-55-001 | 55 | 🟠 MAJOR | Exercise 3's `Gap1Fill` used X as the row/copy index without initializing it; it worked only because `ScoreDraw`'s last cleanup left X=0, so a different glyph/order could change the frame length. | fixed — `LDX #0` once before `Gap1Fill:`; re-logged second `ScoreDraw` 133/31, `Star2Start` 142/5, 192 lines. |
| SR-55-002 | 55 | 🟡 MINOR | The cell geometry said "the last cell's left edge is 643"; the six cells start at 361/409/457/505/553/601, the block spans 361–648, and 643–648 is the last pixel column. | fixed in the doc and 03. |
| SR-55-003 | 55 | 🟡 MINOR | The lit glyph y range was 110–130 in the source header and 109–130 in the doc; the measured capture is 109–130. | fixed — 109–130 in all sources/doc. |
| SR-55-004 | 55 | 🟡 MINOR | "The text is nine lines tall" conflated the 9-line zone with the 7 lit glyph rows. | fixed — nine-line zone, seven lit rows. |
| SR-55-005 | 55 | 🟡 MINOR | The pre-shift rationale cited the 76-cycle kernel line, but the fill runs in VBLANK. | fixed — the 37-line VBLANK budget; the fill is ~12 scanlines (880 cycles). |
| SR-55-006 | 55 | 🟡 MINOR | `MessageLen` was used for the constant `MESSAGE_LEN` in the doc/spec/ex1 header. | fixed — `MESSAGE_LEN`. |
| SR-55-007 | 55 | 🟡 MINOR | The three exercise build headers pointed at the main lesson source/ROM. | fixed — each builds its own `build/exercise-0N.bin`. |
| SR-55-008 | 55 | 🟡 MINOR | Ex1's `ScrollOffsetRead`/`ScrollOffset` said 0..88, `ByteIndex` 0..11, and the wrap comment 88→0; the 14-char build is 0..64, 0..8, 64→0. | fixed. |
| SR-55-009 | 55 | 🟡 MINOR | Ex3's `TextCol2`/`TextRow2` were literals presented as copy witnesses; the gap total said 9+87+9+87 and "174 starfield"; the copy cycles said 46+16=62/56+16=72. | fixed — fixed-label wording; 9+84+3+9+87=192 (171 starfield + 3 setup); 45+10=55/52+10=62. |
| SR-55-010 | 55 | 🟡 MINOR | The ball's "visible row 186/38" was presented as measured; it is derived from the y mapping. | fixed — marked derived. |
| SR-55-011 | 55 | 🟡 MINOR | The fire-pause evidence did not name the debug build/guard bypass. | fixed — the doc says the committed ROM ignores a held button during the first eight frames; the pause was measured with the guard bypassed. |
| SR-55-012 | 55 | 🟡 MINOR | The 03 spec still said the cell block's left edges were 361–643 and `MessageLen`. | fixed — the six edges and `MESSAGE_LEN`. |
| SR-55-013 | 55 | 🟡 MINOR | The captures are phase 0 only; the table's other phases were not disclosed. | fixed — the doc says phases 0/1/3/7 were re-derived from the font and the pointer selects the others identically. |
| SR-55-014 | 55 | 🟡 MINOR | The ex3 header still called the 174 lines "starfield" and summarised 9+87+9+87. | fixed — 171 starfield + 3 setup; 9+84+3+9+87. |
