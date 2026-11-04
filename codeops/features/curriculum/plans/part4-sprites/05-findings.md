# Findings Ledger: Part 4 — Sprites (Lessons 25–34)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Phase 10 complete — 0 critical, 0 major open. Part 4 complete.

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
| SR-206 | 4 | 🟠 MAJOR | Both: the HMOVE checkpoint was labelled VBLANK line 2 cycle 66; that is the `STA WSYNC` stall point. `STA HMOVE` executes on line 3 cycle 0 and completes by cycle 3, in HBLANK | fixed — the doc and the table say line 3 cycle 0 (completes by 3); a new `AfterHmove` breakpoint measures line 3 cycle 3 |
| SR-207 | 4 | 🟡 MINOR | Both: "the two stores take 12 cycles" — `STA GRP0`/`STA GRP1` are zero-page stores, 3 cycles each, 6 total; both load/store pairs 14 | fixed — 6 cycles for the stores, 14 for both pairs, under a fifth of the 76-cycle line |
| SR-208 | 4 | 🟡 MINOR | Reviewer: a repeated HMOVE gives a fixed extra offset, not frame-to-frame drift | fixed — "the first sprite ends up a fixed extra offset from its target" |
| SR-209 | 4 | 🟡 MINOR | Auditor: the plan ID "AR-21" leaked into the lesson source/doc; no other shipped lesson cites plan IDs | fixed — "the one-HMOVE rule" in the source and doc; the plan keeps the AR reference |
| SR-210 | 4 | 🟡 MINOR | Auditor: the What's Next teaser said the missiles/ball have their own colors; they share `COLUP0`/`COLUP1`/`COLUPF` | fixed — "colored by the player or playfield register it shares" |
| SR-211 | 4 | 🟡 MINOR | Re-review: the Part 4 index's Lesson 29 bullet still said "widths and colors" | fixed — "widths and the player/playfield colors they share" |
| SR-212 | 4 | 🟡 MINOR | Re-review: "effect at the next line's cycle 3" read as line 4; the store is applied in cycle 2 of line 3, the next instruction starts at cycle 3 | fixed — the source says "store applied at cycle 2; next instruction at cycle 3"; the doc says "the strobe completes by cycle 3" |
| SR-213 | 4 | ℹ️ INFO | `two-players.png` shows the transient Stella launch toast in the lower black border, outside the picture | accepted — it does not cover the picture, matching the Lesson 25 artifact |
| SR-220 | 5 | 🟠 MAJOR | Both: the ball's target→X narrative used a false "coarse slot" cause and the table was internally inconsistent | fixed — the cause is removed; the measured mapping is published (missiles 64→63, 96→95; ball 68→79, 108→128) and the lesson states it as an observation |
| SR-221 | 5 | 🟠 MAJOR | Auditor: the `HmoveApply` row reported the WYSYNC stall at line 4 c73 as the strobe | fixed — the row is VBLANK line 5 c0; the `$F03B` line-4/c73 hit is labelled the WYSYNC stall |
| SR-222 | 5 | 🟡 MINOR | Reviewer: `RespBL` c61 is off the simple 14+5n estimate (54) | documented — the table reports the logged 61 and the 7-cycle offset; the measured evidence is from the committed ROM (sha1 recorded) |
| SR-223 | 5 | 🟡 MINOR | Both: exercise-3 range said 16–152; the wrap test stops at 152, so the visible range is 16–150 | fixed — 16–150 in the spec/doc/ST |
| SR-224 | 5 | 🟡 MINOR | Both: the source header named `Resp*Write`, which does not exist | fixed — `RespP0/RespM0/RespM1/RespBL` |
| SR-225 | 5 | 🟡 MINOR | Auditor: a think-aloud aside ("shares player 0's shape? No —") shipped in the source | fixed — "Missile 0 is its own 1-pixel object; it shares COLUP0" |
| SR-226 | 5 | 🟡 MINOR | Auditor: the exercise-1 hint forward-referenced NUSIZ copies (Lesson 31) | fixed — "Keep bits 0–2 at 0, as in Lesson 25" |
| SR-227 | 5 | 🟡 MINOR | Auditor: "the players are eight pixels wide" ignored NUSIZ | fixed — "a player draws eight bits per line; eight pixels with NUSIZ=0" |
| SR-228 | 5 | 🟡 MINOR | Reviewer: the TypeScript ball entry used 128 while the other entries used targets | fixed — `x: 108` with a measured-X comment |
| SR-229 | 5 | 🟡 MINOR | Auditor: the exercise-1/3 sources still said "the ball's slot is later" | fixed — "the ball's mapping is its own" |
| SR-230 | 5 | ℹ️ INFO | The ball's logged cycle (61) and landing (128) are seven cycles from the reviewers' 14+5n model (54/107); the committed ROM (sha1 f16342c4) reproduces 61/128 on a fresh capture | accepted — the measured values are the lesson's evidence; the 7-cycle offset is documented, not explained away |
| SR-231 | 6 | 🟠 MAJOR | Both: the doc said the sprite's left edge was "clock 432" (a line is 228 color clocks; 432 = 72 × 6, the capture scale) | fixed — the left edge is color clock 140 (capture x = 457) |
| SR-232 | 6 | 🟡 MINOR | Both: the store-start cycles were described as the write effects; `STA` writes on its third cycle | fixed — "starts at 10, write 12" / "starts at 17, write 19", with the later-row 11/13 and 18/20 qualification |
| SR-233 | 6 | 🟡 MINOR | Reviewer: exercise 1's expected result said "the rest of the bands shift up"; the 4/7/3/2 table keeps the hat, shortens blue by one, and moves red up one | fixed — the expected rows are hat 0–3, blue 4–10, red 11–13, shoes 14–15 |
| SR-234 | 6 | 🟡 MINOR | Auditor: exercise 3's header had a doubled backslash | fixed — one backslash |
| SR-235 | 6 | 🟡 MINOR | Both: the spec said "shorten the body by 2 rows" while the solution is 4/7/3/2 | fixed — the spec says 4/7/3/2 |
| SR-236 | 6 | 🟡 MINOR | Auditor: ST-30.3 said "16 distinct rows" while some shape bytes repeat | fixed — "16 rows, one per sprite line (some bytes repeat)" |
| SR-237 | 6 | 🟡 MINOR | Re-review: the 10/12 and 17/19 cycles are the first row's; later rows are one cycle later | fixed — the doc qualifies the first row and gives 11/13 / 18/20 for later rows |
| SR-238 | 6 | 🟡 MINOR | Re-review: the ex-2 cost list omitted `CLC` | fixed — `TXA`/`CLC`/`ADC`/`AND`/`TAY` |
| SR-239 | 6 | 🟡 MINOR | Re-review: the band ranges left the two blend rows unclassified | fixed — the ranges tile (gold 359–371, blue 372–396, red 397–408) |
| SR-240 | 6 | ℹ️ INFO | The reviews were static; the parent's `verify.sh` (112 ROMs) and Stella logs are the runtime evidence | accepted — the phase record carries the logs |
| SR-241 | 7 | 🟠 MAJOR | Both: the width-mode derivation produced 301/337 while the committed capture measures 307/343; the stretched player's output starts one clock later (X=41) | fixed — the doc states the measured one-clock offset and derives 307/343 from it |
| SR-242 | 7 | 🟡 MINOR | Both: "gaps" of 96/192/384 were copy spacings, not the visible gaps (84/180/372) | fixed — spacing vs empty gap in the doc and ST-31.3 |
| SR-243 | 7 | 🟡 MINOR | Reviewer: the spec's width list said 6/12/24/48 px; no band has a 6-px bar | fixed — 12/24/48 px (one TIA pixel = 6 capture px) |
| SR-244 | 7 | 🟡 MINOR | Auditor: the Session A record said "the measured bars" before the capture existed | fixed — "expected (to be measured in Session C)" |
| SR-245 | 7 | 🟡 MINOR | Re-review: the table read crosses a page from X=132, so the body is 23 cycles there, not 22 | fixed — the source/doc/plan state 22 (23 from X=132; WSYNC absorbs it) |
| SR-246 | 7 | 🟡 MINOR | Re-review: ex-3 captures at 1 s and 2 s show two bars and two medium bars, not one and two | fixed — "a capture in the first second shows one bar; a second later two close bars" |
| SR-247 | 7 | 🟡 MINOR | Re-review: ex-1's "gaps of 8/24/56 pixels" were TIA pixels while the section uses capture pixels | fixed — tagged "(TIA pixels; 48/144/336 capture px)" |
| SR-248 | 7 | ℹ️ INFO | The stretched-mode one-clock offset is observed in the committed ROM, not derived in the lesson | accepted — stated as observed, with the 307/343 arithmetic |
| SR-249 | 8 | 🟠 MAJOR | Both: the trigger rule said "either GRP0 or GRP1 copies the delayed value"; it is cross-coupled — GRP0 latches P1, GRP1 latches P0 | fixed — the source, doc, and spec state the cross-coupled rule |
| SR-250 | 8 | 🟠 MAJOR | Both: the prose clear order (GRP1=0 then GRP0=0) cut P1's last row; the shipped code is GRP0=0 then GRP1=0 | fixed — the prose, example, and spec match the code; the main capture shows both blocks 16 rows, 3 px apart |
| SR-251 | 8 | 🟠 MAJOR | Both: exercise 2 (VDELP0) aligned instead of delaying P0; the trigger for P0 is the GRP1 write | fixed — the ex2 kernel mirrors the writes (body GRP1→GRP0, clear GRP1=0→GRP0=0, bottom GRP1=0); measured blue 385 / red 388 |
| SR-252 | 8 | 🟠 MAJOR | Both: the frame arithmetic said 95 bottom, which sums to 200, not 192 | fixed — 88 top + 16 body + 1 clear + 87 bottom = 192 everywhere |
| SR-253 | 8 | 🟡 MINOR | Both: the spec/Session A clear order was GRP1=0 then GRP0=0 | fixed — GRP0=0 then GRP1=0 |
| SR-254 | 8 | 🟡 MINOR | Both: the ex1/ex2 banners said "P1 is one line lower" | fixed — ex1 "both players align", ex2 "P0 is one line lower" |
| SR-255 | 8 | 🟡 MINOR | Both: the prerequisite line omitted Lesson 26 | fixed — Lesson 26 added |
| SR-256 | 8 | 🟡 MINOR | Auditor: ST-32.2 said both blocks start at scanline 125 | fixed — P0 at 125, P1 at 126 |
| SR-257 | 8 | 🟡 MINOR | Re-review: the TypeScript block modelled a two-line delay | fixed — `delayed = grp1; grp1 = next; return delayed` |
| SR-258 | 8 | 🟡 MINOR | Re-review: "the last row smears" did not name row 14 or the missing GRP0 trigger | fixed — the qualified wording |
| SR-259 | 8 | 🟡 MINOR | Re-review: Section 4's sum omitted the 88 top lines | fixed — full equation |
| SR-260 | 8 | 🟡 MINOR | Re-review: the spec/ST named `G0Write`/`G1Write`, which do not exist | fixed — "the body's GRP0/GRP1 store cycles" |
| SR-261 | 8 | 🟡 MINOR | Re-review: the spec's expected row range was one block only | fixed — P0 385–433, P1 388–436 |
| SR-262 | 8 | ℹ️ INFO | The phase patch predated the clear-order and VDLP0 edits | accepted — the patch was regenerated from the worktree; the committed ROM/capture are the corrected build |
| SR-263 | 9 | 🟠 MAJOR | Reviewer: ex1's hint said the read "times out exactly like paddle 0" while the expected result reported X=28; the two results need different configurations | fixed — the hint/expected name the capture configuration (paddle 1 at minimum → count 4 → X=28) and the absent-paddle timeout (X=24) |
| SR-264 | 9 | 🟠 MAJOR | Both: the lesson claimed a CX50 key pulls a raw `SWCHA` line low and the monitor's columns show key presses; a keypad needs driven rows | fixed — the monitor is documented as the raw port with `SWACNT=$00`; the keypad's driven 4×3 scan is explained (`SWACNT=$FF`, one row low, ~400 µs, `INPT0`/`INPT1`/`INPT4`, restore) and the ROM is stated not to run it |
| SR-265 | 9 | 🟡 MINOR | Reviewer: the range said 0–128 / X 24–152; the loop stores at most 127 | fixed — 0–127 / 24–151 in all artifacts |
| SR-266 | 9 | 🟡 MINOR | Reviewer: the `PF1` columns end at capture x=312, not 313 | fixed — 121–312 |
| SR-267 | 9 | 🟡 MINOR | Reviewer: the charge was attributed to `VBLANK` bit 6; clearing bit 7 releases the ground and starts the charge | fixed — bit 7 starts the charge; bit 6 latches fire |
| SR-268 | 9 | 🟡 MINOR | Reviewer: ex2 stored A=`$05` to `REFP0`/`REFP1` after `STA NUSIZ1` | fixed — `LDA #$00` before the `REFP` stores |
| SR-269 | 9 | 🟡 MINOR | Reviewer: the fire section called active-low "the opposite convention" | fixed — "only bit 7 is a switch; test the bit, never nonzero" |
| SR-270 | 9 | 🟡 MINOR | Reviewer: ex1's section comment still said "paddle 0" | fixed — "paddle 1" |
| SR-271 | 9 | 🟠 MAJOR | Reviewer: the saturation disclosure said only "maximum resistance" is affected; a real CX30's 0–24 ms travel means most of the knob reads 0 | fixed — the doc states the low-resistance-end limit, ~12 ms mid-travel, the 20-line read, and the cross-frame alternative |
| SR-272 | 9 | 🟡 MINOR | Reviewer: spec/ST named `MoveApply`; the label is `HmoveApply` | fixed |
| SR-273 | 9 | 🟡 MINOR | Reviewer: the keypad scan recipe did not restore `SWACNT=$00` | fixed — step 6 |
| SR-274 | 9 | 🟡 MINOR | Reviewer: the driving controller's pair is on the joystick-direction bits, not the keypad lines | fixed — `SWCHA` bits 4–5 for P0 |
| SR-275 | 9 | 🟠 MAJOR | Auditor: prerequisites sent readers to Lesson 16 for the timer and Lesson 22 for priority; the correct lessons are 15/19/20, and `INPT4` is introduced here | fixed — prerequisites rewritten; the `INPT4` introduction is stated |
| SR-276 | 9 | 🟠 MAJOR | Auditor: the paddle loop ledger used 13 cycles/iteration; `LDA INPT0` is zero page, so the loop is 12 cycles, 1,536 cycles ≈ 20 lines ≈ 1.3 ms | fixed — doc, spec, ex3 hint, AR-19 |
| SR-277 | 9 | 🟡 MINOR | Auditor: the screenshot caption said the columns are dark "because no key is pressed", reinstating the misconception | fixed — "no switch is closed to ground; a CX50 key alone cannot light them without the driven scan" |
| SR-278 | 9 | 🟡 MINOR | Auditor: the ex1 note blamed "floating" inputs; a count of 4 is a connected paddle at minimum, while an absent input times out | fixed — the capture configuration is named |
| SR-279 | 9 | 🟡 MINOR | Auditor: the keypad scan recipe did not state the `VBLANK` state; bit 7 grounds the analog columns and bit 6 latches the right column | fixed — "scan with `VBLANK` bits 6–7 clear" |
| SR-280 | 9 | 🟡 MINOR | Reviewer: the preflight report still had the old cycle arithmetic and 24–152 | fixed — 3+2+2+2+3 and 24–151 |
| SR-281 | 9 | ℹ️ INFO | Reviewer/auditor: "matrix columns" was used for the raw-port columns while the page defines "matrix" as the keypad grid | fixed — "raw-port columns" throughout |
| SR-282 | 9 | ℹ️ INFO | The pressed-fire branch was not in the at-rest logs | accepted — scratch witnesses confirm `FireWrite` A=`$42` (red block) and ex2 A=`$1A` (gold 871–966); the shipped ROM reads the real `INPT4` |
| SR-283 | 10 | 🟠 MAJOR | Reviewer: the second capture was labelled frame 2 but the measured legs `$24 $24 $66 $C3` are frame 3 | fixed — doc/spec/plan relabelled frame 3; the pose labels are mnemonic |
| SR-284 | 10 | 🟠 MAJOR | Reviewer: ex3's `LDX Direction` was followed by `LDA #$00`, clearing N, so `BMI FaceLeft` never ran and REFP0 stayed 0 | fixed — `LDA #$00` before `LDX`; measured X=52 nose right, X=116 nose left |
| SR-285 | 10 | 🟡 MINOR | Reviewer: the body was called 18–19 cycles; all four frames are 16-byte aligned, so it is 18 here | fixed — 18 cycles here (19 only on a page crossing) in doc/source/spec/ST/plan |
| SR-286 | 10 | 🟡 MINOR | Reviewer: the palindrome list omitted `$C3` | fixed — added |
| SR-287 | 10 | 🟡 MINOR | Reviewer: the pose labels claimed a left/right stance the palindromic leg bytes do not encode | fixed — mnemonic labels and a note |
| SR-288 | 10 | 🟡 MINOR | Reviewer: ex1's comments still said 0–7 and every 8 frames | fixed — 0–15 and every 16 |
| SR-289 | 10 | 🟡 MINOR | Reviewer: ex3 kept unused `SPRITE_X`/`FLIP_RATE`/`FlipCounter`/`FlipState` and their stores | fixed — removed |
| SR-290 | 10 | 🟠 MAJOR (false positive) | Reviewer's byte count put `FrameTable` at `$F0CF`; the ACME symbol and the ROM dump put it at `$F0D0` (the count missed the first of four `ASL`s) | accepted as a false positive — no change; `$D0/$E0/$F0/$00` and the byte dump confirm `$F0D0` |
| SR-291 | 10 | 🟠 MAJOR (false positive) | Reviewer's count put `Resp0Write`/`HmoveApply` at `$F0C8`/`$F0CC`; the symbol and ROM dump put them at `$F0C9`/`$F0CD` | accepted as a false positive — no change; the breakpoints fire at `$F0C9`/`$F0CD` |
| SR-292 | 10 | 🟡 MINOR | Reviewer: the exercise sources still had the old left/right pose labels | fixed — the mnemonic labels in all three |
| SR-293 | 10 | 🟡 MINOR | Reviewer: "On 7 it wraps" / "On 119 it wraps" contradicted the post-INC compare | fixed — "wraps when the increment reaches 8" / "wraps at 120" |
| SR-294 | 10 | 🟡 MINOR | Reviewer: ex3's `MoveTick` comment said A = the new X, but the bounce paths leave A = the direction | fixed — the comment distinguishes the normal and bounce frames |
| SR-295 | 10 | 🟡 MINOR | Auditor: the mouse pointer was visible in both captures | fixed — re-captured from one pointer-parked run; 0 white pixels at the old pointer position; walk-a frame 0 nose right, walk-b frame 3 nose left |
| SR-296 | 10 | 🟡 MINOR | Auditor: ex3's hints did not say to remove the 120-frame flip | fixed — hint 3 says delete `FlipCounter`/`FlipState`; `Direction` is the only `REFP0` writer |
| SR-297 | 10 | ℹ️ INFO | Auditor: the exercise capture times are wall-clock and include startup; timing from reset can land on other frames | fixed — the exercise expectations quote the measured frames/X, not seconds |
| SR-298 | 10 | ℹ️ INFO | The first capture round landed on different frames because of wall-clock timing | accepted — a burst was captured and the pair matching frame 0 (nose right) and frame 3 (nose left) was selected; no pointer |
