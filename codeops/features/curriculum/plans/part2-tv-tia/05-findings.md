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
