# Findings Ledger: Part 4 — Sprites (Lessons 25–34)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Phase 3 complete — 0 critical, 0 major open

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
| SR-175 | 2 | 🟠 MAJOR | Both: the divide-by-15 explanation said A exits with an undershoot of 0–14; the loop runs one extra subtraction to detect the underflow, so A is a negative byte ($F1–$FF) and the fine value is `u − 9` (u = the overshoot) | fixed — the doc/source explain the extra subtraction, the negative exit, and the `6 − remainder` fine value; the TypeScript block matches |
| SR-176 | 2 | 🟠 MAJOR | Both: the checkpoint ledger said `HmoveApply` was on VBLANK line 1 cycle 30 and `Resp0Write` always at cycle 24; HMOVE executes on line 2 cycle 0 (effect 3), and RESP0's cycle advances with the table (24/34/44/54/64) | fixed — the doc, spec, and ST now list the five RESP0 cycles and the line-2 HMOVE; the `RTS` breakpoint confirms line 2 cycle 3 |
| SR-177 | 2 | 🟠 MAJOR | Reviewer: Exercise 2 said "152 = 10×15 + 2, ten subtractions"; the program passes 155, so the loop subtracts 11 times and A = $F6, HMP0 = $10 (+1 left), coarse 153 → 152 | fixed — the hint and the solution header show the 155/11/$F6/153 arithmetic |
| SR-178 | 2 | 🟠 MAJOR | Reviewer: the position-B caption called 96 TIA pixels "three coarse steps" (96 TIA = 576 capture px = three tour steps; the coarse change is six 15-clock steps plus the six-clock fine change) | fixed — the caption states 96 TIA px / 576 capture px / three tour steps / 90 coarse + 6 fine clocks |
| SR-179 | 2 | 🟡 MINOR | Both: a `RESP0` at clock 68 puts the sprite at X≈5, not the left edge; the left edge needs clock 63 | fixed — the doc says clock 63 for the left edge and clock 68 for X≈5 |
| SR-180 | 2 | 🟡 MINOR | Auditor: the TypeScript `fine = (target ^ 7) - 7` returned values the hardware never produces | fixed — the TS block mirrors the asm (`while a >= 0`, `remainder = a + 15`, `fine = 6 - remainder`) |
| SR-181 | 2 | 🟡 MINOR | Both: the source comments said `PosApply` A = the target X and the routine input was the target; the caller passes the biased value | fixed — the comments say "biased table value (target + 3)" and the routine input is 0–162 |
| SR-182 | 2 | 🟡 MINOR | Auditor: exercise 1's header said "Load #120" while the code loads #123 | fixed — "#123 (120 + the 3-pixel bias)" |
| SR-183 | 2 | 🟡 MINOR | Both: the spec lists the HMOVE/HBLANK left-edge mask but the doc never explained it | fixed — a theory tip: HMOVE in HBLANK blanks the leftmost 8 pixels; the VBLANK line makes it invisible |
| SR-184 | 2 | 🟡 MINOR | Reviewer: exercise 3's `PosStep` label shared the `ApplyPos` address and fired every frame | fixed — the label is on the tick's `STA PosIndex` |
| SR-185 | 2 | 🟡 MINOR | Auditor: the five-position table said "measured" but only two positions had committed captures | fixed — the table notes all five were measured in scratch captures; the two committed captures are X=16 and X=112 |
| SR-186 | 2 | 🟡 MINOR | Re-review: the `PosApply` comment in the source still said "target X" | fixed — "biased table value (target + 3)" |
| SR-187 | 2 | 🟡 MINOR | Re-review: "(`remainder − 9`)" was ambiguous because the remainder was defined as the negative byte | fixed — "`u − 9`, where `u = −A` is the overshoot" |
| SR-188 | 2 | 🟡 MINOR | Re-review: "the coarse strobe sits at 15 × (quotient + 1) − 12" described the coarse position, not the strobe cycle | fixed — "the coarse position is …"; the strobe cycle is 5 × (SBC count) + 14 |
| SR-189 | 2 | 🟡 MINOR | Re-review: the TypeScript comment `// steps = coarse` was wrong (steps = quotient + 1) | fixed — `// steps = quotient + 1` |
| SR-190 | 2 | 🟡 MINOR | Re-review: the 96-pixel caption did not explain the six-clock fine change | fixed — "90 clocks coarse + 6 clocks fine" |
| SR-191 | 2 | 🟡 MINOR | Re-review: "a strobe just before clock 68" was ~4–5 px off; the left edge is clock 63 | fixed — "clock 63 … clock 68 lands near X=5" |
| SR-192 | 2 | 🟡 MINOR | Re-review: "output delay" / "three clocks coarse" misnamed the constant −3 | fixed — "encoding offset" / "three clocks left of exact placement" |
| SR-193 | 2 | 🟡 MINOR | Re-review: the `Resp0Write` comment "cycle 5k+14" left k undefined | fixed — "cycle 5 × SBC count + 14" |
| SR-194 | 3 | 🔴 CRITICAL | Both: the SWCHA direction mapping was reversed — the lesson used P0 bit 4 right / 5 left / 6 down / 7 up; the hardware is bit 4 up / 5 down / 6 left / 7 right (0 = pressed) | fixed — `include/vcs.asm`, the expert reference, all four sources, the doc, the spec, and the plan record now use the correct bit order |
| SR-195 | 3 | 🟠 MAJOR | Both: the doc claimed a sprite "does not remember" X and must be strobed every frame; `RESP0` latches the position and a static sprite can be positioned once | fixed — the doc says the TIA keeps the latch; a moving sprite re-strobes because `SpriteX` changes and `HMOVE` re-applies the fine offset |
| SR-196 | 3 | 🔴 CRITICAL | Round 2: after the bit-order fix, the active-low masked values were still inverted (left = `$80`, right = `$40`); the code steered left as right | fixed — `$80`→`DirLeft` (`$FF`), `$40`→`DirRight` (`$01`); the doc tables, Step 1/2, and the plan record match; the witnesses left `$80`→`$FF`, right `$40`→`$01` |
| SR-197 | 3 | 🟠 MAJOR | Round 2: exercise 3's vertical decode was inverted (up = `$20`, down = `$10`) | fixed — `$20`→up (−4), `$10`→down (+4); the header and hint match |
| SR-198 | 3 | 🟡 MINOR | Both: `DirWrite` was documented as firing only on changes; it fires every frame a horizontal input is held | fixed — the source header, doc, spec, and ST-27.4 say every frame while held (0 hits in the no-input patrol) |
| SR-199 | 3 | 🟡 MINOR | Both: `TopTick` was documented as firing only on a vertical change; it fires every frame exactly one of up/down is held, including at the clamp | fixed — the source header and the doc hint say "exactly one of up/down", A = the new or clamped top |
| SR-200 | 3 | 🟡 MINOR | Both: "keeps moving" after a both-pressed stop was false — the `$C0` path keeps the stored 0 | fixed — the doc says the sprite stays still until a single direction is pressed |
| SR-201 | 3 | 🟡 MINOR | Reviewer/auditor: the spec's exercise-3 bottom count was `192 − TOP − 8`, dropping the clear line | fixed — `192 − TOP − 8 − 1` (183 − TOP) in the spec, matching the source |
| SR-202 | 3 | 🟡 MINOR | Auditor: the Lesson 27 `SetHorizPos` copy lacked the Lesson 26 comments | fixed — the routine carries the input comment and the cycle notes in the main and exercise 3 |
| SR-203 | 3 | 🟡 MINOR | Auditor: exercise 1's `Direction` comment said +1/−1 while the exercise uses +2/−2 | fixed — "+2, -2 ($FE), or 0" |
| SR-204 | 3 | ℹ️ INFO | `patrol-b.png` shows Stella's transient launch badge in the lower black border, outside the picture | accepted — the auditor confirmed it does not cover the picture and matches Lesson 25's artifact |
| SR-205 | 3 | ℹ️ INFO | Synthetic key injection did not reach Stella; the input path was verified with scratch builds that force the input byte | accepted — AR-6 allows scratch witnesses for what-if states; the shipped ROM uses the real `SWCHA` read |
