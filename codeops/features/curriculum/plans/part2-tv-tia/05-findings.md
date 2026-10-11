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
| SR-001 | 4 | MINOR (correction) | spec 03 §Lesson 15 pinned `TIM64T` 43/35 for the blanking; measured in Stella (M6532 preloads the prescaler at divider−1: the first tick lands one cycle after the write), 43/35 give 36/29-line blanking (a 260-line frame); corrected to 44/36 (exact 37/30 lines, 262-line frame) across the four sources, the spec, the Session A record, and the test oracle (07 ST-15.3) — authorization recorded here; both specialists verified the model, the hardware spec corroborates the first-tick behavior | fixed |
| SR-002 | 4 | MAJOR (auditor) | the course's timer notes contradicted the corrected lesson: `tia-hardware.md` 139-140, `timing.md` 45/57-58, `kernels.md` 37 and `include/vcs.asm` 185 still presented 43/35 as the nominal 37/30 values (macro.asm's note was already accurate) | fixed — follow-up `chore(skills)` commit in this phase (user-approved at the phase ask) |
| SR-003 | 4 | MAJOR (atari) | the two ledger tables costed `STA TIM64T` as a 3-cycle zero-page write; it is a 4-cycle absolute write (store at cycles 15/16; last ticks 2,768/2,257; line cycles 32/53) — corrected in the sources, the document, and the phase records | fixed |
| SR-004 | 4 | MINOR | document line 37's TS comment: 44 ticks × 64 = 2,816 (2,753 covered after the write) | fixed |
| SR-005 | 4 | MINOR | the macro-note citation: "use for 37-line VBLANK" clarified as the classic convention the measurement refines | fixed |
| SR-006 | 4 | MINOR | exercise-03's `ComputeBand` cycle note: the +6 is the JSR, not the RTS | fixed |
| SR-007 | 4 | MINOR | the phase diff was stale vs the worktree at review time (regenerated after the fixes) | fixed |
| SR-008 | 4 | MINOR (info) | the part 1 lessons' document annotations still label the classic `+set_timer 43`/`35` snippets as "~37"/"~30 scanlines" (approximate historical labels; the macro's note and Lesson 15 now carry the measured values) — a future `fix(docs)` sweep could align them | recorded — future sweep |
| SR-001 | 5 | MAJOR | docs/part2-tv-and-tia/16-horizontal-zones.md (the intro's "one picture per frame" premise contradicted Lessons 12/13/15's multi-band frames; raised by both reviewers) | fixed — intro rewritten around the data-driven layout; description reworded |
| SR-002 | 5 | MAJOR | docs/part2-tv-and-tia/16-horizontal-zones.md + exercise-03-solution.asm (the live-edit recipe broke the 192-line total while claiming the frame stayed 262; corrected to a total-preserving recipe — witness re-run 24/48/96/24 at 262 lines) | fixed |
| SR-003 | 5 | MINOR | docs/part2-tv-and-tia/16-horizontal-zones.md (overscan checkpoint addresses `$F04B`/`$F057` are mid-instruction; actual `$F04A`/`$F056` — re-run on the committed ROM) | fixed |
| SR-004 | 5 | MINOR | source header + document (HBLANK stated as "69 color clocks = 23 cycles"; the course figure is 68 ≈ 22.7, Lessons 12/14) | fixed |
| SR-005 | 5 | MINOR | document ex-2 hint ("24 + 48 = 72 painted lines" → 48) | fixed |
| SR-006 | 5 | MINOR | document ex-3 hint + source comments (heights must be ≥ 2 — height 0/1 wraps the countdown) | fixed |
| SR-007 | 5 | MINOR | document ex-3 hint (malformed inline span `LDA $80+`,X) | fixed |
| SR-008 | 5 | MINOR | document Theory 4 ("olive"/"salmon" vs Lesson 13's hue names — now "muted gold"/"pale red") | fixed |
| SR-009 | 5 | MINOR (info) | exercise-01-solution.asm header misquoted the spec's example numbers (AR-13 resolution wording) | fixed |
| SR-010 | 5 | MINOR (info) | document's forward-looking zone vocabulary (playfield/sprites/scoreboard) — spec'd as later-part context per AR-9 | accepted |
| SR-011 | 5 | MINOR (info) | prev/next one-way until Lesson 17 ships — the established pattern | accepted |
| SR-012 | 5 | MINOR (out-of-scope follow-up) | docs/part2-tv-and-tia/15-the-timer.md "What's Next" still described the visible 192 as "one uniform picture" (found by the phase-5 re-review) | fixed — follow-up `fix(lesson15)` commit |
