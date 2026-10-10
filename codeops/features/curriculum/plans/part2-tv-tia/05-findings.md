# Findings Ledger: Part 2 — TV & TIA (Lessons 12–18)

> **Parent**: [Index](00-index.md)
> **CodeOps Artifact Schema**: 1

One row per review batch. Identifiers and area tokens only.

| Finding | Phase | Severity | Area | Ruling |
| --- | --- | --- | --- | --- |
| SR-001 | 1 | MAJOR | docs/part2-tv-and-tia/12-the-ntsc-frame.md + lessons/part2-tv-and-tia/12-the-ntsc-frame/exercise-01-solution.asm (zp,X vs abs,X read-cost claim) | fixed |
| SR-002 | 1 | MINOR | docs/part2-tv-and-tia/12-the-ntsc-frame.md (VisibleStart COLUBK observation; A=$00 attribution) | fixed |
| SR-003 | 1 | MINOR | lessons/part2-tv-and-tia/12-the-ntsc-frame (scanline-origin conflict: exercise-02 header + checkpoint comments in all four sources) | fixed |
| SR-004 | 1 | MINOR | lessons/part2-tv-and-tia/12-the-ntsc-frame/exercise-03-solution.asm + docs/part2-tv-and-tia/12-the-ntsc-frame.md (BandFetch first observed value) | fixed |
| SR-005 | 1 | MINOR | lessons/part2-tv-and-tia/12-the-ntsc-frame/exercise-03-solution.asm (luminance-field wording) | fixed |
| SR-006 | 1 | MINOR | docs/part2-tv-and-tia/12-the-ntsc-frame.md (RAM range vs stack bytes $FE-$FF) | fixed |
| SR-007 | 1 | MINOR | docs/part2-tv-and-tia/12-the-ntsc-frame.md (VblankStart X steady-state value; raised by the re-review) | fixed |
| SR-001 | 2 | MINOR | docs/part2-tv-and-tia/13-colors.md (release-line HBLANK claim; exact 21-cycle ledger now stated) | fixed |
| SR-002 | 2 | MINOR | docs/part2-tv-and-tia/13-colors.md (three palette-scope claims NTSC-qualified) | fixed |
| SR-003 | 2 | MINOR | docs/part2-tv-and-tia/13-colors.md (band 11 provenance cell; `$BE` vs Lesson 11's `$B4`) | fixed |
| SR-004 | 2 | MINOR | docs/part2-tv-and-tia/13-colors.md (`Band0Write` description: fires after the store) | fixed |
| SR-005 | 2 | MINOR | review artifact (phase diff stale vs worktree at review time; diff regenerated) | fixed |
| SR-001 | 3 | MINOR | docs/part2-tv-and-tia/14-wsync-and-timing.md + plan record (mode schedule off-by-one: aligned 1–119, late 120–239; raised by both reviewers) | fixed |
| SR-002 | 3 | MINOR | lesson 14 sources + document (visible-line numbering now 1-based throughout; the boundary is visible line 97) | fixed |
| SR-003 | 3 | MINOR | lesson 14 sources + document (store pixel annotations replaced with convention-free wording; the measured tear pixel 76 kept) | fixed |
| SR-004 | 3 | MINOR | exercise-02-solution.asm + document (ex 2's verification recipe; added the `StoreDone` checkpoint after the store) | fixed |
| SR-005 | 3 | MINOR | docs/part2-tv-and-tia/14-wsync-and-timing.md:57 ("one wrote" typo) | fixed |
| SR-006 | 3 | MINOR | docs/part2-tv-and-tia/14-wsync-and-timing.md (`TopWrite` first hit: the scanline 37 entry at cycle 19) | fixed |
| SR-007 | 3 | MINOR | exercise-03-solution.asm (break recipe now uses the shipped numeric addresses `$F057`/`$F05B`) | fixed |
| SR-008 | 3 | MINOR (info) | spec "≈25 CPU cycles" vs document "~24" for the late write (measured 24.3; keep the measured value) | accepted |
