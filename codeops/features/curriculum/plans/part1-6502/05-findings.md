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
