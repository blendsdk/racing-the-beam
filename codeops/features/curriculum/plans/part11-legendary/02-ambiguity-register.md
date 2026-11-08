# Lesson 79 — Ambiguity Register

> **Status**: CLOSED — all material decisions resolved.
> **Rule**: The plan is not executable while any material item is open.
> **Source**: user decisions of 2026-11-08, the course rules, and the existing lesson
> artifacts. No implementation has started.

## 1. Gate status

| Check | Result |
|---|---|
| Material decisions recorded | Yes — D-01 through D-15 |
| Open material items | None |
| Gate | ✅ **PASSED** for planning; re-affirm at Session A |

## 2. Decisions

| ID | Question | Decision | Source / evidence |
|---|---|---|---|
| D-01 | Where does the lesson live? | **Lesson 79 at the end of Part 11** (73–79); Lessons 73–78 keep their numbers | User, 2026-11-08 |
| D-02 | When is it built? | **After Part 10** (Lessons 71–72 and the completion gate) | User, 2026-11-08 |
| D-03 | What is the artifact? | **Small game + score + mark** (“the calling card”) | User, 2026-11-08 |
| D-04 | What mark is used? | **Original `RACING` wordmark**, six 5×7 glyphs in 8×8 cells; no Activision trademark | Lesson 63’s trademark rule; user asked for “like Activision”, not a copy |
| D-05 | What is the frame? | 9 score + 5 top positioner + 164 play + 5 handover + 9 mark = 192 | Derived from Lessons 39/50/69; see `03-lesson-spec.md` |
| D-06 | Where is the mark? | P0 at X=16, P1 at X=24; the 48-pixel block spans X=16–63 | Derived from Lesson 39 geometry |
| D-07 | Where is the score? | P0 at X=56, P1 at X=64; the block spans X=56–103 | Lesson 39 / `include/score.asm` |
| D-08 | RAM or ROM table? | Score in `ScoreBuf` RAM; mark in a 48-byte ROM table | The score changes; the mark is static; saves 48 RAM bytes |
| D-09 | How is the mark drawn? | `MarkDraw`, a clone of `ScoreDraw` with `MarkBuf`; same store order, `NOP`, and `CPX` | The absolute address is part of the timing; a pointer would add cycles |
| D-10 | How is the table protected? | `!align 255,0`; the 48-byte table stays inside one page | Lesson 17: `LDA abs,Y` costs +1 on a page cross |
| D-11 | How does the mark toggle? | SELECT edge toggles `MarkVisible`; the band stays 9 lines and blanks when hidden | Lesson 63 SELECT pattern; frame stays 262 |
| D-12 | Are there captures of the toggle? | Yes: `game.png` (visible) and `no-mark.png` (hidden) | Two full-screen captures; the auto-demo scripts the toggle |
| D-13 | What are the exercises? | (1) ten-letter 4-px mark; (2) move to bottom-right/centre; (3) playfield-drawn mark *(stretch)* | Course pattern: 3 exercises, last may be a stretch goal |
| D-14 | How is navigation handled? | Lesson 79 `prev` points to the Part 11 index; no `next`; “What’s Next” links to the index | Lessons 73–78 have no pages yet |
| D-15 | How are the commits split? | (1) curriculum amendment + plan; (2) atomic `feat(lesson79)` lesson commit | README sync belongs to the listing change; the lesson stays atomic |

## 3. Re-affirmed constraints

| Constraint | Source |
|---|---|
| Five hard rules: VitePress, screenshots, preflight, README, ROM/player | `AGENTS.md`, `vcs-lesson-production` |
| Curriculum frozen at 79 after this authorized amendment | `AGENTS.md`, RD-11, AR-1 amendment |
| No repository work while Lesson 71 is uncommitted | Current shared working tree |
| Original mark; no Activision trademark | Lesson 63 |
| No sound | Lesson 50 precedent; keeps the lesson focused |
| 4,096-byte ROM; 128-byte RAM; 192 visible lines | Course constraint |

## 4. Deferrals

| Item | Why deferred |
|---|---|
| Lessons 73–78 | They remain coming soon; their research and plans are separate. |
| A title-screen logo lesson | Already covered by Lessons 61 and 63. |
| A sound effect on the hit | Out of scope; can be a reader extension. |
| Stub pages for 73–78 | The Part 11 index lists them as coming soon; stubs are not needed for 79. |

## 5. Next action

Adopted into `codeops/features/curriculum/plans/part11-legendary/02-ambiguity-register.md`
on 2026-11-08. Re-run the gate at Session A; if any decision changes, stop and update
this file before implementation.
