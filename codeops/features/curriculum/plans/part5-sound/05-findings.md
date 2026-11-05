# Findings Ledger: Part 5 — Sound (Lessons 35–37)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Phase 3 complete — 0 critical, 0 major open. Part 5 complete.
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
| SR-001 | 35 | 🟡 MINOR | ST-35.4 predicted `EffectStep` at frames 32/64/112/144; the first play frame is frame 1, so the step occurs on the frame after the 32nd play frame (33/65/113/145). | fixed — ST-35.4 and the lesson document use the measured 33/65/113/145; the arithmetic is stated. |
| SR-002 | 35 | ℹ️ INFO | The BOOM capture caught 14 meter cells, one three-frame step after the first step's 15. | accepted — the document discloses the measured step; the first step is specified as 15. |
| SR-003 | 35 | 🟠 MAJOR | Both reviewers: Exercise 1 was titled "Lower the Beep" but `AUDF $13 → $09` raises the pitch from 261.66 to 523.33 Hz. | fixed — renamed "Raise the Beep" in the document, the solution header, and 03; the measured marker stays x=385. |
| SR-004 | 35 | 🟠 MAJOR | Reviewer: Exercise 2's hint called `AUDF` 6 the "low" pitch and 20 the "high"; 2,242.8 Hz is the higher pitch. | fixed — the hint now says `AUDF` 6 is higher and 20 is lower, with the Hz values. |
| SR-005 | 35 | 🟡 MINOR | Reviewer: the timer is armed ~15 cycles into the line, so it expires at 2,768 and the WSYNC absorbs 44 cycles, not 59. | fixed — document and 03 say 44 cycles (2,812 − 15 − 2,753). |
| SR-006 | 35 | 🟡 MINOR | Reviewer: the `HmoveApply` row reported line 3 c55 as if it were the strobe; the store executes at line 4 c0. | fixed — the table calls line 3 c55 the WSYNC stall and `HmoveDone` line 4 c3 confirms the store at line 4 c0. |
| SR-007 | 35 | 🟡 MINOR | Reviewer: ST-35.2 still demanded the BOOM first step (15 cells, x=457) while the committed capture is 14 cells at x=889. | fixed — ST-35.2 now accepts a self-consistent pair and records the committed 14-cell/x=889 state (frame 5, AUDF 30). |
| SR-008 | 35 | 🟡 MINOR | Reviewer: `VISIBLE_LINES = 192` was unused in all four sources. | fixed — the constant was removed; the 192 budget stays in the header and the document. |
| SR-009 | 35 | 🟡 MINOR | Both reviewers: each exercise carried a duplicate stale main header whose `Build:` line pointed at the lesson ROM. | fixed — each solution now has exactly one exercise header with its own build command. |
| SR-010 | 35 | 🟠 MAJOR | Auditor: the document said "the top band is red" for BOOM; the third band is red. | fixed — "the third band is red; the top two are dark". |
| SR-011 | 35 | 🟡 MINOR | Auditor: the BOOM PNG has a one-line, 24-px left-edge notch at the band transition. | accepted and documented — the band loop's tail lands `STA COLUPF` a couple of cycles after color clock 68, so the first playfield bit keeps the previous color; the image is not a tear (see SR-013 for the corrected explanation). |
| SR-012 | 35 | 🟡 MINOR | Reviewer: after auto-resume, a fire press could restart the last manual selection instead of the sound on screen. | fixed — the auto step stores `EffectID` to `Selected`; fire restarts the current effect. |
| SR-013 | 35 | 🟠 MAJOR | Both reviewers: the first notch explanation claimed the TIA latches `COLUPF` per line; the TIA applies color writes mid-line, and the real cause is the active band's extra `LDA EffectColor` pushing the store to CPU cycle 24, after the first playfield pixel at cycle 22. | fixed — the caption now gives the measured cycle (label at c21, store completes c24) with no latch claim. |
| SR-014 | 35 | 🟡 MINOR | Reviewer: the BOOM alt text still said "a red top band". | fixed — "a red third band". |
| SR-015 | 35 | 🟡 MINOR | Reviewer: the `HmoveApply` cell still paired line 3 c55 with the strobe. | fixed — the cell says line 3 c55 is the stall; the store is line 4 c0 via `HmoveDone`. |
| SR-016 | 36 | 🔴 CRITICAL | Both reviewers: no source wrote `AUDC0`/`AUDC1`; `+clean_start` leaves them 0, which disables the channels, so all four ROMs were silent. | fixed — Reset writes `AUDC0=$0C`/`AUDC1=$0D` with `AUDC0Write`/`AUDC1Write` checkpoints; all four ROMs rebuilt; the doc/ST record the timbre evidence. |
| SR-017 | 36 | 🟠 MAJOR | Both reviewers: ex3 set `HarmonyTop=0` at the pause, which draws the blue marker on visible lines 0–7 instead of hiding it. | fixed — `HarmonyTop=$F0` with a `PauseTopWrite` checkpoint. |
| SR-018 | 36 | 🟠 MAJOR | Both reviewers: the pause was 48 frames (rest frame plus 47), not the specified 60. | fixed — `PauseTimer=60` at the rest; silence 180–239, restart 240, next `LeadStep` 252; the doc/ST say so. |
| SR-019 | 36 | 🟡 MINOR | Reviewer: the marker-top formula said `RungTop[degree] − 4`; the table already includes the −4. | fixed — `RungTop[degree]` (the rung line minus 4). |
| SR-020 | 36 | 🟡 MINOR | Reviewer: the grid path cycle figures were 20/13; the correct counts are higher. | fixed — the tip now states the rung path is 23 cycles and the worst line is ~71 of 76, without the disputed per-path figures. |
| SR-021 | 36 | 🟡 MINOR | Reviewer: `LeadVolWrite` never reports 0 (the rest uses `LeadRestVol`), and ST-36.3 appended a 16th `LeadFreqWrite` value that is `LeadRestFreq`. | fixed — the doc/ST use `LeadRestFreq`/`LeadRestVol` for the rest and 15 `LeadFreqWrite` values. |
| SR-022 | 36 | 🟡 MINOR | Reviewer: the note frequencies were called "measured"; they are calculated from the nominal audio clock. | fixed — "Hz (nominal clock)", "derived", and "computed against equal temperament"; the asm header says derived. |
| SR-023 | 36 | 🟡 MINOR | Reviewer: the Stella run line said "click the screen to hear it"; Stella needs no click (Javatari does). | fixed — the parenthetical is removed; the RomPlayer paragraph keeps the click note. |
| SR-024 | 36 | 🟡 MINOR | Reviewer: the ex3 hint said the markers "reappear on the first rung"; the lead restarts on E (rung 2). | fixed — the harmony returns on rung 0 and the lead on rung 2 (E). |
| SR-034 | 37 | 🟠 MAJOR | Both reviewers: Exercise 2 said the BLIP at frame 264 was "inside the explosion" and that it "loses to a ZAP"; with priority 10 the BLIP wins at 240 and also beats the ZAP (10 > 6). | fixed — the exercise uses 240 as the priority witness, says the 264 accept is a free-channel accept, and says the BLIP beats the ZAP. |
| SR-035 | 37 | 🟡 MINOR | Both reviewers: the first visible line of each band and of the priority bar showed the previous colour (a 1-line stub) because `COLUPF` was written too late. | fixed — the three band colours are precomputed at `$A3–$A5` and the priority colour is preloaded during the gap; both captures re-taken and the band/priority rows are full width. |
| SR-036 | 37 | 🟡 MINOR | Both reviewers: `MusicStart` was listed in the source header and ST-37.3 but no label existed. | fixed — `MusicStart` is on the retrigger path at frame 384 (`$F18D`). |
| SR-037 | 37 | 🟡 MINOR | Reviewer: the priority/band shadows lived in the engine's `$8C/$8D/$9D`. | fixed — the monitor uses `$A0–$A5`, outside the engine's block; the library contract is stated. |
| SR-038 | 37 | 🟡 MINOR | Reviewer: `SoundTrigger`'s API did not say X is preserved; `TriggerSound` depends on it. | fixed — the API and the lesson document say X is preserved. |
| SR-039 | 37 | 🟡 MINOR | Reviewer: BLIP was called a "short high tone"; AUDF 20 is the lowest pitch in the lesson. | fixed — "a short low pulse". |
| SR-040 | 37 | 🟡 MINOR | Reviewer: ex1 said `Accept` reports A=5 "every 60 frames"; the ZAP is rejected at 240/480 inside the explosion. | fixed — accepted while channel 0 is free; rejected at 240/480; the ZAP replaces the LASER at 120/360. |
| SR-041 | 37 | 🟡 MINOR | Reviewer: "the 8-byte records are the only interface" overstated the contract. | fixed — the records are the data; the API and `Snd*` shadows are the rest. |
| SR-042 | 37 | 🟡 MINOR | Reviewer: the library RAM block said "keep out" but then freed `$8E–$8F`; the exact rules were unclear. | fixed — `$8E–$8F` free, `$90–$9F` read-only to the caller, `$A0–$A5` monitor. |
| SR-043 | 37 | ℹ️ INFO | Reviewer: the main's 6th `SfxColorTbl`/`BandMap` entry (ZAP) was unreachable. | fixed — the main has five entries; the ZAP entries are added in exercise 1. |
| SR-044 | 37 | ℹ️ INFO | Reviewer: the music's last step is a rest, so the channel-1 meter drops to 0 for 12 frames each loop. | accepted and documented — it is the Lesson 36 tune's rest. |
| SR-045 | 37 | ℹ️ INFO | Reviewer: Lesson 37 uses `-audio.enabled 0`; Lessons 35/36 use `-sound 0`. | fixed in the Part 5 completion commit — all three documents use `-audio.enabled 0`. |
| SR-046 | 37 | 🟠 MAJOR | Reviewer round 2: the three exercise sources still used the old `$8C/$8D/$9D` monitor block and the inline band-colour select; the main had moved to `$A0–$A5` and the precomputed band colours. | fixed — all three solutions were regenerated from the current main (the ZAP, priority, and duck changes re-applied); ex2/ex3 now carry five `SfxColorTbl`/`BandMap` entries, ex1 six. |
| SR-047 | 37 | 🟡 MINOR | Reviewer round 2: band 0's first visible line still had a 3-chunk stub because the `STA COLUPF` landed after the playfield's first pixel. | fixed — `LDA BandColor0 / STA COLUPF` before `STA VBLANK`; the re-taken captures have a clean first line. |
| SR-048 | 37 | 🟡 MINOR | Reviewer round 2: the explosion capture is 10 cells, not 11; the doc said 11 and "first step". | fixed — the committed captures are LASER 9 cells and EXPLOSION 7 cells; the doc records the captured step and the first-step 11. |
| SR-049 | 37 | 🟡 MINOR | Reviewer round 2: the plan's HMOVE row still said line 3, and the completion checkboxes were unchecked. | fixed — the row names each lesson's measured line (35/4, 36/3, 37/5); the plan and RD-05 AC checkboxes are ticked. |
| SR-050 | 37 | ℹ️ INFO | Reviewer: the ledger jumped from SR-024 to SR-034. | accepted — the auditor's SR-025–SR-033 were merged into the atari reviewer's SR-034–SR-042 rows; no finding was dropped. |
| SR-051 | 37 | ℹ️ INFO | Reviewer: the exercise sources carried the 6th color/band entries even when they did not add ZAP. | fixed by the regeneration — only exercise 1 has the ZAP entries. |
