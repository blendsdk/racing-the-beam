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
| SR-113 | 38 | 🟡 MINOR | The screenshots predated the fixes; the reviewer asked for provenance from the rebuilt ROM. | fixed — both re-captured from the current committed ROM; the doc's P0/P1 measurements were updated to the new frames. |
