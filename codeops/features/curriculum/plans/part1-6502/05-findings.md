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

## Batch notes

- **Phase 1 batch (lesson 07):** reviewers `atari2600-reviewer` (SR-001, SR-002) and
  `curriculum-auditor` (SR-003–SR-007), dispatched in parallel on the lesson-07 change set;
  findings renumbered sequentially across both reviewers.
- No CRITICAL or MAJOR findings; no re-review required (fixes applied were MINOR content
  corrections only).
- Advisory (no finding raised): screenshot-pair timing wording was cross-checked against the
  author's capture evidence and left as-is.
