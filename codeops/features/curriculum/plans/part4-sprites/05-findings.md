# Findings Ledger: Part 4 — Sprites (Lessons 25–34)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Phase 1 complete — 0 critical, 0 major open

One row per finding. Severity follows the quality profile: 🔴 CRITICAL / 🟠 MAJOR / 🟡 MINOR /
ℹ️ INFO. Duplicate observations raised by both specialists share one row (both IDs noted).

| ID | Phase | Severity | Finding | Resolution |
|----|-------|----------|---------|------------|
| SR-161 | 1 | 🔴 CRITICAL | Reviewer: Exercise 2's `REFP0` mirror was a no-op — every row of the lesson invader is a bit-reversal palindrome, so the mirrored frame was pixel-identical, and the doc claimed `$DB`/`$24`/`$5A`/`$A5` were asymmetric | fixed — the exercise ships an asymmetric tail (`$0F`, `$F0`), the doc explains the shape's symmetry, and the measured tail is `11110000`/`00001111` |
| SR-162 | 1 | 🟠 MAJOR | Both: Exercise 3's vertical budget was 191 lines (`BOTTOM=86`), so the frame was 261 lines and `OverscanStart` fired at 228 | fixed — `BOTTOM=87`; re-measured `OverscanStart` 229 and `StartFrame` 259 (262 lines) |
| SR-163 | 1 | 🟠 MAJOR | Curriculum auditor: the required `SpriteWrite` and `Resp0Write` evidence pins were missing from the sources and the doc | fixed — labels added at `$F053` and `$F02C`; `SpriteWrite` 8 hits/frame (A = row byte), `Resp0Write` line 1 cycle 46 (write 49); doc updated |
| SR-164 | 1 | 🟡 MINOR | Both: "clock 504" was a unit error (504 is the capture-pixel offset, not a color clock; the line is 228 clocks) | fixed — the body write is at clock 39 and the sprite edge at clock 152 (X = 84) |
| SR-165 | 1 | 🟡 MINOR | Both: the placement arithmetic said "45 cycles (nine iterations × 5, minus the last branch)" but the exact sum is 2 + 44 + 3 = 49 cycles to the write effect | fixed — the doc and source state 49 cycles → clock 147 → +5 → clock 152 → X 84 |
| SR-166 | 1 | 🟡 MINOR | Both: "about a sixth of the way down" contradicted the capture (the sprite top is visible line 80 of 192, ~42%) | fixed — "about two-fifths of the way down (visible line 80 of 192)" |
| SR-167 | 1 | 🟡 MINOR | Both: the source header said the bottom loop parks "the remaining 104" lines; it parks 103 (the clear line is the 104th) | fixed — header says the clear line parks 1 and the bottom loop 103; doc re-injected verbatim |
| SR-168 | 1 | 🟡 MINOR | Reviewer: "the player is always eight pixels wide / there is no width register" is false (`NUSIZ` 5/7 draw double/quad width) | fixed — "8 bits per line; with NUSIZ = 0 it draws as eight pixels; NUSIZ can widen or copy it (Lesson 31)" |
| SR-169 | 1 | 🟡 MINOR | Auditor: "a sprite's height is the number of lines on which you write a non-zero byte" contradicted the register-persistence explanation | fixed — "the number of scanlines on which GRP0 holds a non-zero byte; identical consecutive rows need one write" |
| SR-170 | 1 | 🟡 MINOR | Auditor: the main ROM writes `REFP0` but the lesson never explains it before Exercise 2 uses it | fixed — a name-only `REFP0` note in Section 1 |
| SR-171 | 1 | 🟡 MINOR | Re-review: the delay paragraph was left as a dangling "After a WSYNC, a nine-iteration" fragment | fixed — one sentence with the 49-cycle sum |
| SR-172 | 1 | 🟡 MINOR | Re-review: Exercise 2's header still said "the shape table is unchanged" while the solution changes the tail | fixed — "the mirror itself needs no table change; only the tail is made asymmetric" |
| SR-173 | 1 | 🟡 MINOR | Re-review: the tail comment labelled `$0F` "left-heavy" and `$F0` "right-heavy", which is the mirrored display, not the raw byte | fixed — "raw: right-heavy; mirrors to left-heavy" / "raw: left-heavy; mirrors to right-heavy" |
| SR-174 | 1 | ℹ️ INFO | Session B caught the missing clear line before the first review (the last `GRP0` byte smeared down the screen) | fixed — a clear line added to all four sources; capture re-taken; the doc's Section 4 teaches the bug |
