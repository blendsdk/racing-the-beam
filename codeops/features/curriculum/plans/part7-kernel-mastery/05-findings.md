# Findings Ledger: Part 7 — Kernel Mastery (Lessons 48–55)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Phase 1 complete — 0 critical, 0 major open.
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

