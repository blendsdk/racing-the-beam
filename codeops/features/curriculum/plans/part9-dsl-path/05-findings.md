# Findings Ledger: Part 9 — The DSL Path (Lessons 66–68)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Lesson 66 complete after round 3 — 0 critical, 0 major open. Lessons 67–68 pending.
> **Rule**: every reviewer finding is recorded with its severity, the lesson, the evidence, and
> the resolution. A lesson is not done while a critical/major is open. The plan-level preflight
> findings live in [00-preflight-report.md](00-preflight-report.md); this ledger is for the
> per-phase reviews.

## Summary

| Lesson | Critical | Major | Minor | Open critical/major |
| --- | --- | --- | --- | --- |
| 66 | 0 | 4 | 27 | 0 |
| 67 | 0 | 0 | 0 | 0 |
| 68 | 0 | 0 | 0 | 0 |

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

_No phase findings yet._

## Lesson 68 — Kernel Architecture

_No phase findings yet._
