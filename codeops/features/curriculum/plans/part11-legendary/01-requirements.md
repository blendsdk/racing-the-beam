# Lesson 79 — Requirements

> **Status**: Adopted 2026-11-08; preflight to be re-run at Session A.
> **Source**: user decisions of 2026-11-08; course rules in `AGENTS.md`;
> `vcs-lesson-production`; `atari-2600-expert`.

## 1. Goal

Add **Lesson 79: The Publisher Mark — An Activision-Style In-Game Logo** to Part 11
and build it end-to-end, while keeping Lessons 73–78 unchanged and coming soon.

The lesson teaches how to put a static 48-pixel brand mark in the bottom-left corner
of a game screen, the way Activision put its wordmark in the bottom band of its early
2600 games. The artifact is an original course mark (`RACING`), not a reproduction of
the Activision trademark.

## 2. Curriculum requirements

| ID | Requirement |
|---|---|
| CR-1 | The curriculum becomes **79 lessons**. Part 11 becomes **73–79**. |
| CR-2 | Lessons 73–78 keep their numbers and titles; only Lesson 79 is added. |
| CR-3 | The user's 2026-11-08 authorization is recorded in `AGENTS.md`, both lesson-author briefs, the CodeOps ambiguity register (AR-1 amendment), and RD-11. |
| CR-4 | After the amendment, the 79-lesson structure is frozen again: no further add/remove/rename/reorder without a new user decision. |
| CR-5 | `README.md`, `docs/index.md`, `docs/.vitepress/config.ts`, `package.json`, the Part 11 index, and every `78` / `73–78` reference agree on 79 / 73–79. |

## 3. Lesson functional requirements

| ID | Requirement |
|---|---|
| FR-1 | **Artifact**: "the calling card", a 4,096-byte ROM. |
| FR-2 | **Frame**: 9 score + 5 top positioner + 164 play + 5 handover + 9 mark = 192 visible lines; 262 total. |
| FR-3 | **Score**: Lesson 39 `include/score.asm`; six digits at the top; `ScoreBuf` in RAM; P0/P1 at X=56/64. |
| FR-4 | **Mark**: original six-letter `RACING` mark, 48 pixels wide, X=16–63, eight rows; 48-byte table in ROM, column-major, bottom-up, page-aligned. |
| FR-5 | **Kernel**: the mark is drawn by a `MarkDraw` clone of `ScoreDraw`; the store order and the `NOP`/`CPX` timing are preserved. |
| FR-6 | **Handover**: P0/P1 are repositioned between the score and the play, and between the play and the mark; `NUSIZ` 3↔1; VDEL on/off; `HMOVE` in each blank HBLANK; the 24-cycle rule is respected. |
| FR-7 | **Play**: a 2-line kernel with a playfield, a P0 player, and a falling ball; `CXP0FB` adds one to the score; the auto-demo catches the ball. |
| FR-8 | **Toggle**: SELECT hides/shows the mark; the frame stays 262 lines; the score and play are unchanged. |
| FR-9 | **Exercises**: three complete solutions — (1) a ten-letter 4-px mark; (2) the mark moved to the bottom-right or centre; (3) a playfield-drawn mark *(stretch goal)*. |
| FR-10 | **Document**: follows the lesson template: frontmatter, meta block, TypeScript equivalents, theory, full source, walkthrough, captures, RomPlayer, exercises, takeaways, what's next. |
| FR-11 | **Captures**: `game.png` (mark visible) and `no-mark.png` (mark hidden), 1010×807, Stella title bar, no cursor. |
| FR-12 | **ROMs**: the main ROM and three exercise solutions are committed under `docs/public/roms/part11-legendary/79-publisher-mark/`. |
| FR-13 | **Site**: sidebar entry, Part 11 index row 79 ✅, prev/next, RomPlayer, cross-references. |
| FR-14 | **README**: the count and Part 11 range are synced in the curriculum-amendment commit. |

## 4. Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-1 | The five hard rules in `AGENTS.md` all pass. |
| NFR-2 | Technical claims follow the `atari-2600-expert` claim discipline: observed, documented, or derived; no invented cycle counts. |
| NFR-3 | The artifact uses an original mark; no Activision trademark or bit-exact logo. |
| NFR-4 | The main ROM is 4,096 bytes; RAM stays within the 128-byte map; every visible line lands on its boundary. |
| NFR-5 | `bash scripts/verify.sh` passes; `atari2600-reviewer` and `curriculum-auditor` report no critical/major findings. |
| NFR-6 | No repository work while the Maze Explorer session is uncommitted. |

## 5. Acceptance criteria

| ID | Criterion |
|---|---|
| AC-1 | The curriculum says 79 lessons and Part 11 says 73–79 in all listed files. |
| AC-2 | The main ROM and all three exercise solutions assemble to exactly 4,096 bytes. |
| AC-3 | The frame is 262 lines; the score, play, and mark bands land at the measured scanlines. |
| AC-4 | The mark is a 48-pixel block at TIA X=16–63; the pixel check matches the table. |
| AC-5 | The score is a 48-pixel block at TIA X=56–103 and updates on a hit. |
| AC-6 | SELECT toggles the mark; `no-mark.png` shows the blank band; the frame is unchanged. |
| AC-7 | All three exercise solutions run and produce their documented results. |
| AC-8 | The document matches the template and the full source is verbatim. |
| AC-9 | The sidebar, Part 11 index, prev/next, and RomPlayer work; `npm run docs:build` passes. |
| AC-10 | `bash scripts/verify.sh` passes with the four new ROMs committed. |
| AC-11 | Reviews: 0 critical, 0 major open. |
| AC-12 | The curriculum-amendment commit precedes the atomic `feat(lesson79)` commit. |

## 6. Dependencies

| Dependency | Why |
|---|---|
| Part 10 completion (71, 72, gate) | Part 10 is complete at `255b534`; the tree is clean except unrelated `.opencode` edits. |
| Lesson 26 | Positioning with `RESPx`/`HMPx`/`HMOVE` for X=16/24. |
| Lesson 31 | `NUSIZ` copies/sizes for the 48-pixel block and the game. |
| Lesson 32 | VDEL for the 48-pixel kernel; clearing it for the game. |
| Lesson 39 | The 48-pixel trick, score library, 9-line kernel, cycle ledger. |
| Lesson 50 | Zones, line budgets, the second HMOVE, the 24-cycle rule, handover. |
| Lesson 55 | The 48-pixel window as a text display; the Activision history note. |
| Lesson 17 | `LDA abs,Y` page-cross timing; the page-aligned table. |
| Lessons 19, 21, 23 | Playfield and asymmetric/data-driven PF for the game and exercise 3. |
| Lessons 38, 50 | `CXP0FB` collision latch and the one-frame hit delay. |
| Lessons 47, 63 | `SWCHB` SELECT edge handling and the auto-demo pattern. |
| Tools | ACME 0.97, Stella 7.0, ImageMagick, Node 20+, VitePress 1.6.4. |

## 7. Scope decisions

| Decision | Choice | Reason |
|---|---|---|
| Placement | Lesson 79 at the end of Part 11 | No renumbering; the 48-pixel arc becomes 39 → 55 → 79 |
| Build order | After Part 10 | Does not interrupt the in-progress capstones; the user chose this |
| Artifact | Small game + score + mark | Proves the mark coexists with gameplay; two 48-pixel windows |
| Mark | Original `RACING` wordmark | Trademark safety; the history is context only |
| Exercises | 3, the last a stretch goal | Matches the course pattern |
| Captures | 2 full-screen captures | Enough to prove visible/hidden; no extra close-up |
| Sound | None | Keeps the lesson focused; Lesson 50 is the precedent |
| Navigation | `prev` to the Part 11 index; no `next` | Lessons 73–78 have no pages yet |
| Commit split | Amendment/plan commit, then lesson commit | README sync in the listing change; lesson stays atomic |

## 8. Out of scope

- Lessons 73–78 and their research.
- Changes to Lesson 71, Lesson 72, or the Part 10 plan.
- A title-screen logo lesson (already covered by Lessons 61 and 63).
- A bit-exact Activision reproduction.
- Sound, game-over, lives, or scoring beyond the one-hit demo.
