# Findings Ledger: Part 5 — Sound (Lessons 35–37)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Phase 1 complete — 0 critical, 0 major open
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
