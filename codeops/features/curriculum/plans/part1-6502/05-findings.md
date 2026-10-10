# Findings Ledger: Part 1 — The 6502 CPU (Lessons 07–11)

> **Parent**: [Index](00-index.md)
> **CodeOps Artifact Schema**: 1

One row per review batch. Identifiers and area tokens only.

| Finding | Phase | Severity | Area | Ruling |
| --- | --- | --- | --- | --- |
| SR-001 | 1 | MINOR | lessons/part1-6502-cpu/07-branches-and-loops (band colour write lands ~1 clock into the visible line for the cursor band) | accepted — cosmetic, 1 px × 1 line, imperceptible; band geometry exact |
| SR-002 | 1 | MINOR | docs/part1-6502-cpu/07-branches-and-loops.md (V-flag claim "only touched by ADC/SBC") | fixed |
| SR-003 | 1 | MINOR | docs/part1-6502-cpu/07-branches-and-loops.md (false Lesson 06 cross-reference) | fixed |
| SR-004 | 1 | MINOR | docs/part1-6502-cpu/07-branches-and-loops.md (Exercise 3 premise vs branch reach) | fixed |
| SR-005 | 1 | MINOR | docs/part1-6502-cpu/07-branches-and-loops.md (wrap wording implied the cursor leaves the ladder) | fixed |
| SR-006 | 1 | MINOR | docs/part1-6502-cpu/06-flags-and-comparisons.md (same V-flag claim, pre-existing) | fixed |
| SR-007 | 1 | MINOR | package.json (description still said 72 lessons, pre-existing) | fixed |
| SR-008 | 2 | MINOR | lessons/part1-6502-cpu/08-stack-and-subroutines (last band line clipped: subroutine unwind put the overscan blank-on ~12 cycles into the visible line) | fixed — `STA WSYNC` before the blank-on in all four sources; frame stays 262 lines; bottom edge verified clean |
| SR-009 | 2 | MINOR | asm comments + docs/part1-6502-cpu/08-stack-and-subroutines.md ("four equal bands, 48 each / 192 visible lines" vs actual 49/48/48/48 and 193 non-blanked) | fixed — reworded accurately everywhere |
| SR-010 | 2 | MINOR | docs/part1-6502-cpu/08-stack-and-subroutines.md (disassembly example quoted stale addresses) | fixed — updated to the shipped layout (`$F056` JSR, `$F058` pushed, `$F059` resume, `$F061` PaintBand) |
| SR-011 | 2 | MINOR | docs/part1-6502-cpu/08-stack-and-subroutines.md (Step 4 counterfactual claimed a mid-line color change) | fixed — first visible line would hold the previous bottom color; the change arrives at the next line |
| SR-012 | 2 | MINOR | asm headers + doc (register contract claimed Y is clobbered; Y is untouched and Exercise 3 relies on it) | fixed — contracts corrected; listing kept byte-identical |
| SR-013 | 2 | MINOR | docs/part1-6502-cpu/08-stack-and-subroutines.md (unbalanced-stack failure mode misstated for the up-counting loop) | fixed — true failure described; one-band demo attributed to Exercise 2's design |
| SR-014 | 2 | MINOR | docs/part1-6502-cpu/08-stack-and-subroutines.md (collision-range numbers mixed `$FA`/`$F9` conventions) | fixed — single rule: SP `$F9`, pushes down to `$FA`, keep variables below `$F9` |
| SR-015 | 2 | MINOR | docs/public/images/lesson08/subroutine-bands.png (bottom-edge artifact) | fixed — same root cause as SR-008; recaptured with the pointer parked; edge verified clean |
| SR-016 | 3 | MAJOR | lessons/part1-6502-cpu/09-bitwise-operations/exercise-03-solution.asm + docs/part1-6502-cpu/09-bitwise-operations.md Exercise 3 Hint 3 (mirrored `ROR` recipe omitted that `LSR` shifts the byte; followed literally it shifts twice and can store `$00`) | fixed — recipe corrected to `LDA / LSR / LDA / ROR / STA` with the reload rationale in both places; re-walked for all eight single-bit patterns; no other copy remains |
| SR-017 | 3 | MINOR | exercise-03 solution + doc §5 (redundant `LDA Pattern` after `CMP`; comment claimed `CMP` modified A, contradicting Lesson 06) | fixed — instruction deleted; prose states `CMP` sets C and leaves the byte alone (why the ring needs no reload) |
| SR-018 | 3 | MINOR | exercise-02 solution comment (`($8, green)` — hue `$8` is not green) | fixed — `($8, dark violet-blue)` |
| SR-019 | 3 | MINOR | exercise-02 solution comment (`$C4` called "green-blue") | fixed — "a dimmer green, same hue as the ladder's bright green, lower luminance" |
| SR-020 | 3 | MINOR | doc ("dividing by 16 four times" reads as four divisions by 16) | fixed — "four one-bit shifts divide it by 16 again" |
| SR-021 | 3 | MINOR | doc (`LSR` cycle note "two for the load, three for the shift-with-store") | fixed — described as a read-modify-write |
| SR-022 | 3 | MINOR | doc (indexed-address mention in the operand-forms sentence — Lesson 10 forward reference) | fixed — removed |
| SR-023 | 3 | MINOR | doc Key Takeaways had 8 bullets (template allows 5–7) | fixed — merged the Z/N bullet into the shift/carry bullet → 7 |
| SR-024 | 3 | MINOR | solutions (six unreferenced checkpoint labels, no comments) | fixed — each labelled a debugger checkpoint with its expected value |
| SR-025 | 3 | MINOR | doc (`StepShift`/`ReloadStore` mentions implied labels ship in the ROM) | fixed — `acme -l` symbol-list pointer added; second mention says "the `StepShift` symbol" |
| SR-026 | 4 | MINOR | docs/part1-6502-cpu/10-addressing-modes.md (ramp wording "a little brighter"/"smooth" — false for the `+$0A` walk) | fixed — accurate hue/brightness description at all four spots |
| SR-027 | 4 | MINOR | docs/part1-6502-cpu/10-addressing-modes.md (fetch count "first five routes … sixth is not a route") | fixed — five memory fetches named; immediate called out as not a route |
| SR-028 | 4 | MINOR | docs/part1-6502-cpu/10-addressing-modes.md (exercise-3 recipe with the main-ROM band lands on `$02`/CXP0FB, not `$00`) | fixed — recipe re-anchored to the demo's band 4 (`$80 + $80`) |
| SR-029 | 4 | MINOR | exercise-03-solution.asm (table `$1A…$88` vs "pictures are identical" claim) | fixed — table aligned to exercise 1's `$42…$B0`; ROM rebuilt; evidence re-run |
| SR-030 | 4 | MINOR | docs/part1-6502-cpu/10-addressing-modes.md (cycles "same costs" false for stores/RMW) | fixed — LDA qualifier; stores/RMW noted |
| SR-031 | 4 | MINOR | docs/part1-6502-cpu/10-addressing-modes.md ("`(zp),Y` only way to compute a 16-bit address") | fixed — "only way" dropped |
| SR-032 | 4 | MINOR | docs/part1-6502-cpu/10-addressing-modes.md + demo-10.asm ("band k = mode k" across the relative gap) | fixed — "k-th data mode (relative excepted)" + catalog numbers in the table |
| SR-033 | 4 | MINOR | docs/part1-6502-cpu/10-addressing-modes.md (prerequisites credit lesson 09 with indexed reads; they come from lesson 08) | fixed |
| SR-034 | 4 | MINOR | demo-10.asm (comment calls `CPY` a branch) | fixed — compare named as such |
| SR-035 | 4 | MINOR | docs/part1-6502-cpu/10-addressing-modes.md ("Band 10 stores two pointers" — stores happen in Reset) | fixed |
| SR-036 | 4 | MINOR | 10-addressing-modes.asm + docs/part1-6502-cpu/10-addressing-modes.md (`BandPtr` "three bytes away" false) | fixed — true relationship stated |
| SR-037 | 4 | MINOR | docs/part1-6502-cpu/10-addressing-modes.md ("both tables are page-aligned" — only TableUp is) | fixed — "sit together inside one page" |
| SR-038 | 5 | MINOR | 11-lookup-tables.asm + docs/part1-6502-cpu/11-lookup-tables.md:452/:465 + exercise-02-solution.asm (the COLUBK-ordering rule contradicted the code: real constraint is before the release line's *visible pixels*) | fixed — wording corrected in all three asm files + all doc spots |
| SR-039 | 5 | MINOR | docs/part1-6502-cpu/11-lookup-tables.md:496 ("Four instructions per band and a call"; the body is six instructions + `JSR`) | fixed — names the actual seven-step body |
| SR-040 | 5 | MINOR | docs/part1-6502-cpu/11-lookup-tables.md:15 (prerequisites attributed `!byte` tables to Lesson 04; they debut in Lesson 08) | fixed — parenthetical now "RAM variables and the frame skeleton"; `!byte` credited to Lesson 08 |
| SR-041 | 5 | MINOR | exercise-01/-03 solutions (`!align 15, 0` used ACME's `$EA` default fill; Lesson 10's documented convention is the explicit zero fill) | fixed — `!align 15, 0, 0`; pad bytes now `$00`; ROMs rebuilt; addresses/behaviour unchanged |
| SR-042 | 5 | MINOR | docs/part1-6502-cpu/11-lookup-tables.md:555 ("a few seconds later" wall-clock claim vs the sampled captures; pattern displacement is 4 steps ≈ 1 s) | fixed — "later in the same session" |

## Batch notes

- **Phase 1 batch (lesson 07):** reviewers `atari2600-reviewer` (SR-001, SR-002) and
  `curriculum-auditor` (SR-003–SR-007), dispatched in parallel on the lesson-07 change set;
  findings renumbered sequentially across both reviewers.
- No CRITICAL or MAJOR findings; no re-review required (fixes applied were MINOR content
  corrections only).
- Advisory (no finding raised): screenshot-pair timing wording was cross-checked against the
  author's capture evidence and left as-is.
- **Phase 2 batch (lesson 08):** reviewers `atari2600-reviewer` and `curriculum-auditor`,
  dispatched in parallel on the lesson-08 change set; findings merged and renumbered sequentially
  across both reviewers.
- No CRITICAL or MAJOR findings; no re-review required. The code fix (SR-008) was re-verified by
  the orchestrator after the fix pass: `verify.sh` green, frame steady at scanline 258
  (262-line frame), correct post-fix symbol addresses, screenshot bottom edge clean.
- **ST-08.3/ST-08.4 task-note evidence (AR-11 amendment — debugger state log):** `stella -break
  <addr>` with the debugger's `logBreaks` setting produced `BP: … | <flags> <A> <X> <Y> <SP> |`
  lines. Steady-state observations: frame top `$FF`; `DrawScreen` entry `$FD`; after `PHA` `$FC`
  (A = X = band index); `PaintBand` `$FA` on all 42,624 sampled hits; after `PLA` A = restored
  index at `$FD`; exercise-03 ladder `$FF→$FD→$FB→$F9` on all 42,432 deepest hits. Matches the
  author's witness and the static ledger.
- Task-note fix (not a review finding): the `atari-2600-expert` reference documented accumulator
  mode as `ASL A`, which ACME 0.97 rejects; corrected to bare `ASL` in a separate skills commit.
- Deferred (out of lesson scope): earlier lessons phrase the release-line geometry as
  "192 visible lines"; lesson 08 now states its geometry exactly (49/48/48/48, 193 non-blanked
  scanlines). A cross-lesson wording sweep is not part of this plan.
- **Phase 3 batch (lesson 09):** reviewers `atari2600-reviewer` (SR-016–SR-018, SR-020–SR-021,
  open questions) and `curriculum-auditor` (SR-017, SR-019, SR-021–SR-025), dispatched in
  parallel on the lesson-09 change set; findings merged and renumbered sequentially across both
  reviewers.
- One MAJOR (SR-016) and no CRITICAL findings. After the fix pass, the raising reviewer
  re-reviewed the fix diff once: **no residual findings** — the corrected mirrored recipe walks
  correctly for all eight single-bit patterns, the deleted instruction was a true no-op, and
  every reworded claim checks out.
- Fix-pass re-verification: `verify.sh` green; only `exercise-03-solution.bin` changed bytes
  (behavior identical — `RingStep` debugger log A = 01, 02, 04, 08, 10, 20, 40, 80 with C set
  at `$80`, then 01; frame timing unchanged).
- **ST-09 task-note evidence:** ST-09.4 debugger state log (method refined: `stella
  -dbg.logbreaks 1 -logtoconsole 1 -break '$addr' <rom>` — run-independent, no reliance on saved
  Stella settings): mask per band `$80…$01` at 24-scanline spacing (TopBandTest `$F031`,
  BandTest `$F055`); pattern stepping `$01→$80` at one step per 30 frames (StepShift `$F087`);
  reload `A = $01` with C = 1 (ReloadStore `$F091`). ST-09.3 full-cycle observation from a
  56-frame burst of the committed ROM: the bright band visited every band position, advanced
  bottom→top, and wrapped.
- Screenshot provenance: the author's two captures were pixel-identical below the title bar to
  the committed ROM's output but showed a scratch build name in the title bar; the orchestrator
  recaptured both from `docs/public/roms/part1-6502-cpu/09-bitwise-operations/09-bitwise-operations.bin`
  (titles now `09-bitwise-operations`; below-title diff AE 0).
- Accepted notes (no action): the ROM runs some game logic before `+vsync`, so the VSYNC leading
  edge varies slightly (pulse ≈2.6–2.9 lines); the frame remains exactly 262 lines and emulated
  output is stable. The `.vitepress/dist` image copies were briefly stale right after the
  recapture; the next `verify.sh` docs build refreshed them (`dist` is gitignored).
- **Phase 4 batch (lesson 10):** reviewers `atari2600-reviewer` (SR-101–SR-107 + 2 open questions)
  and `curriculum-auditor` (SR-001–SR-006 + 4 open questions), dispatched in parallel on the
  lesson-10 change set; findings merged and renumbered SR-026–SR-037. **No CRITICAL or MAJOR
  findings; no re-review required** (minor content corrections only — the exercise-03 table
  alignment was the reviewers' own sanctioned remedy).
- **ST-10 task-note evidence:** debugger log — six fetch sites A=`$42` with checkpoints 16
  scanlines apart; pointer stores A=`$82`/`$00` (→ `$0082`); the `JMP (ptr)` trampoline reaches
  `PaintBand` in the same frame/scanline; ramp fetch A=`42,4C,56,60,6A,74` (Y=0…5); demo bands
  A=`1A…88` as tabled. The `$82` differential used a labeled scratch witness (`$42`→`$77`: five
  memory bands changed, the immediate and ramp[0] bands stayed) — live debugger `poke` keystrokes
  do not land on this Wayland setup. Solutions on record: ex-1 A=`$42` then loop `4C…B0`; ex-2
  flips at frames 121/241; ex-3 rebuilt A=`$42`, loop `4C…B0`.
- **Session C edge checks (lesson 10):** zero-page wrap witnessed with a scratch witness —
  `LDA $80,X` with X=0 reads A=`$42` (RAM `$80`); with X=`$80` reads A=`$02` (TIA `$00` read
  register, not `$42`). Frame integrity — `StartFrame $F022` is reached at a steady scanline 257
  every frame (stable 262-line frame).
- **Deferred (out of plan scope):** Lesson 01 names `$1A` "Orange"/yellow-orange family while its
  own screenshot renders a yellow-green (lesson 10's "yellow-green" matches the rendering) —
  candidate `fix(lesson01)` follow-up, not actioned in this plan.
- Accepted notes (no action): lesson 11's stub has no back-link — repo-wide stub convention, not
  this diff; the auditor's inability to re-run `verify.sh` (no shell) was covered by the parent's
  green runs.
- **Phase 5 batch (lesson 11):** reviewers `atari2600-reviewer` (2 minors + 2 open questions) and
  `curriculum-auditor` (2 minors + 3 open questions), dispatched in parallel on the lesson-11
  change set; findings merged and renumbered SR-038–SR-042. **No CRITICAL or MAJOR findings; no
  re-review required** (minor content corrections only).
- **ST-11 task-note evidence:** debugger log — offset `$80` cycles `00…0f` held exactly 16 frames
  per value (`OffsetLoaded $F030`; author log shows the wrap `15@241 → 0@257`); fetch probe at
  `WaveFetch $F056` yields exactly 16 unique (X, A) pairs `00→1a … 0f→ec` — the index never
  leaves 0…15; frame steady at scanline 257 (`StartFrame $F016`). Solutions: ex-1 16 equal
  constant-brightness bands; ex-2 durations `08,0C,…,44` (8…68 frames) with the cycle restarting
  at frame 609; ex-3 valid rotations of WaveA / reversed WaveB with a palette flip ~every 2 s.
- Screenshot provenance: `lookup-wave.png` = table order (offset 0); `lookup-wave-shifted.png` =
  the same colors rotated by exactly 4 entries; both titles show `11-lookup-tables`; parent
  verified visually (no blank/duplicate step at the seam).
- Accepted notes (no action): Lesson 12's stub has no prev-link until Part 2 is authored (the
  forward link follows the Lesson 06 pattern, per the frozen spec); README unchanged (no
  curriculum-listing change).
- **Part 1 complete (5/5 tasks).** RD-01 set to Done on the feature and portfolio roadmaps with
  this batch.
