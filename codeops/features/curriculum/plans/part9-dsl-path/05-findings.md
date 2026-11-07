# Findings Ledger: Part 9 — The DSL Path (Lessons 66–68)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Part 9 lessons complete — 0 critical, 0 major open. Lessons 66–68 are committed; the completion gate remains.
> **Rule**: every reviewer finding is recorded with its severity, the lesson, the evidence, and
> the resolution. A lesson is not done while a critical/major is open. The plan-level preflight
> findings live in [00-preflight-report.md](00-preflight-report.md); this ledger is for the
> per-phase reviews.

## Summary

| Lesson | Critical | Major | Minor | Open critical/major |
| --- | --- | --- | --- | --- |
| 66 | 0 | 4 | 27 | 0 |
| 67 | 1 | 4 | 20 | 0 |
| 68 | 1 | 3 | 20 | 0 |

## Lesson 66 — Analyzing batari BASIC

**Round 1** (atari2600-reviewer: 2 major + 8 minor; curriculum-auditor: 2 major + 14 minor):
- **SR-66-001 (major, reviewer):** the RUN lens's comments/claims disagreed on the picture rows (174 vs 176). The measured state log is 229/6 on every RUN frame; the source loops and comments were reconciled to 16 band + 5 setup + 168 star + 2 spacers + 1 last = 192.
- **SR-66-002 (major, reviewer):** the first band row was torn (PF stores after the left-half slots). Fixed by preloading the first band row in VBLANK for RUN/VARS and the first bar row in ZONES; the captures now show full-width row 0.
- **SR-66-003 (major, auditor):** the doc claimed a committed symbol file the repo did not have. Fixed by committing `lesson66.bas.list.txt`, `lesson66.bas.symbol.txt`, and `2600basic_variable_redefs.h`.
- **SR-66-004 (major, auditor):** the exercises referenced those missing files. Fixed by pointing both exercises at the committed artifacts.
- Minors fixed: starfield shear (index before WSYNC, stores after), dead `Startup`/`EnemyY`/`BallY`, VARS solid-block prose, ship height (6 rows), selected symbol table, ZONES repeat (two staircases), row-major grid, `-holdselect`/12 s logs, next-title consistency, `$95` exercise watch, visible-area vs VBLANK timer wording, `lesson66.bas.bin` rename, empty bB playfield caption, muted-player note, "mutter" typo, plan label/RAM drift, plan artifact list.

**Round 2** (no critical/major): the VARS preload used only the left half on the preload line; fixed with the shared `WriteGridLine` macro. Row numbers for the ship/ball and the HMOVE left-edge mask were reconciled/documented; the 682-frame overscan claim replaced the 675 one; `StarLast` row 191 was fixed.

**Round 3** (no critical/major): the tail preload after row 7 read past the grid planes and painted row 106; guarded with `GridRow == 7 -> skip`. The ball column wording was clarified (four white rows 55-58, the 2-px column 55-57 from the wrapper-line enable). The final addresses are `StartFrame $F1A9`, `Vblank $F1B7`, `Body $F2F2`, `Overscan $F66B`, `LensRead $F1F3`, `LensWrite $F68B`, `FrameRead $F1F0`, `MapIndexRead $F28E`.

**Final state:** demo 4,096 (md5 `a5e88b2082d1e8070e0577b7334f2df0`); bB reference 4,096 (md5 `49f1144d8497b1ef7dd484887e5514c5`, matches a fresh bB 1.9 compile); `verify.sh` PASSED (244 sources); Full Source verbatim (1,242 source / 1,906 doc lines); all four captures 1010×807 with title bars, no cursor; 0 critical, 0 major open.

## Lesson 67 — Automatable Patterns

**Round 1** (atari2600-reviewer: 1 critical + 4 major + 8 minor; curriculum-auditor: 4 major + 7 minor):
- **SR-67-001 (critical, reviewer):** `NameBuf` at `$DA-$F7` sat under the stack; the first score hit's 14-byte call chain overwrote the name. Fixed by emitting `LevelNName` in ROM and drawing the name from it; the post-hit capture shows `WAVE-A` + `000001` with 0 differing name-band pixels.
- **SR-67-002 (major, reviewer/auditor):** the play-area partition was off by one (actual 16 band + 1 transition + 64 backdrop + 111 play = 192; HMOVE 122/notch 123). The source/doc now use the measured partition; the plan spec was updated.
- **SR-67-003 (major, reviewer):** a wave reused an active slot without a check. Fixed with a first-inactive-slot scan; a wave with all four slots busy is dropped and its index consumed; the doc states the rule.
- **SR-67-004 (major, reviewer/auditor):** exercise 3's `CurrentColor=$A5` was `ScoreDigits[5]`; a hit overwrote it. Fixed with a per-frame recompute and `$8E`/`$DB`; the hit-between-entries log has no `$01`.
- **SR-67-005 (major/minor, reviewer/auditor):** the generated include headers were hard-coded to the main specs/out. Fixed by threading the actual spec/out through `_regenerate_command`, then adding the `--type-max`, `--allow-level`, and `--allow-color` dialect flags so the stock generator reproduces all four includes.
- **SR-003 (major, auditor):** the doc claimed every solution sources `generated-levels.inc`; each sources its own include. Fixed.
- Minors fixed: the true zigzag triangle, the dead `Startup`/`TYPE_SHIFT`/`BAND_LINES`/`PLAY_LINES`/`SLOT*_TYPE` symbols, the three-field packed byte, six/seven colours, the prepare-cost wording, ex3 offsets 0..14, the bad-spec test, the level-A caption (the 2 s wave is later; the hit capture is the frame-0 proof), the WaveSpawn 0..4/X=slot table, the abridged TypeScript note, the positioner/row/band labels, the duplicated HMOVE sentence, and the stack-map precision (`$DB-$F1` free, `$F2-$FF` effective stack).

**Round 2** (no critical): the generator's `_regenerate_command` still used `DEFAULT_INCLUDE_NAME`; fixed by passing the out basename. The exercise `--check` forms then needed the dialect flags; added in round 3.

**Round 3** (no critical/major): all four `--check` forms pass with the stock generator; the comment/label residuals were fixed. Final 0 critical, 0 major open.

## Lesson 68 — Kernel Architecture

**Round 1** (atari2600-reviewer: 1 critical + 3 major + 15 minor; curriculum-auditor: 2 major + 9 minor):
- **SR-68-001 (critical, reviewer/auditor):** `CTRLPF = $20` is repeat, not reflect; the doc said reflect/mirrored/V in ~12 places. Fixed by the design choice `#$21` (reflect + 4-pixel ball) in all four sources; the captures were re-taken and the doc's reflect claims are now true (SPLIT V, STARFIELD symmetry, STATUS mirror; mirror checks 99.03%/97.77%/99.73%).
- **SR-68-002 (major, reviewer):** the zone macros set up the colour/pointer/rows before the clears, so the previous band's PF0/PF1/player could leak onto the boundary line. Fixed by clearing PF0/PF1/PF2/GRP0/GRP1/ENABL first (PF0 by cycle 18); the boundary lines are clean; the `+kf_ramp` gutter exception is disclosed.
- **SR-68-003 (major, auditor):** the doc claimed the exercise solutions use `+kf_custom`, but no file did. Fixed by converting exercise 1 to `+kf_custom 12, BallBand`; the five-zone ledger is 13+49+39+13+78 = 192.
- Minors fixed: the framework contract (`GRP1=0`, never ENAM0/1), the PF row 57/152, the dispatch 8/14/18 and trampoline reason, ex1 ball x≈59, ex2's page-alignment comments, ex3's star row 0-94 and `SpriteY` gate, ex2's layout 3, the solution build headers, the 48+1/48+1/77+1 prose, the next title "Capstone 1 — Pong", the scratch preflight/capture wording, and the plan's RAM/checkpoint/`KF_TOTAL`/sidebar pins.

**Round 2** (no critical/major): the ex1 ledger/BallData comments, the ex2 layout-3 map line, the ex3 star-seed wording, the 03 exercise-1 description, and the 99 Session A RAM map were corrected. Final 0 critical, 0 major open.
