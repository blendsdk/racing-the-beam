# Lesson 79 — Lesson Specification

> **Title**: The Publisher Mark — An Activision-Style In-Game Logo
> **Slug**: `79-publisher-mark`
> **Part**: Part 11 — Legendary Techniques
> **Artifact**: “the calling card”, 4,096 bytes
> **Status**: Draft specification; implementation starts at Session A.

## 1. Artifact

A 4,096-byte Atari 2600 ROM with five visible bands:

- a six-digit score at the top, drawn by the Lesson 39 48-pixel kernel;
- a small play field with a P0 player and a falling ball;
- a 48-pixel publisher mark in the bottom-left, drawn by a `MarkDraw` clone of the
  same kernel from a 48-byte ROM table.

The player catches the falling star; each catch adds one to the score. SELECT hides
or shows the mark, proving the mark is an independent screen element and not part of
the play field. The auto-demo produces both captures without input.

## 2. Frame layout

NTSC: 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262 lines.

| Visible lines | Lines | Zone | Content |
|---|---:|---|---|
| 0–8 | 9 | Score | `ScoreDraw`: line 0 setup, lines 1–8 glyphs; P0=56, P1=64; white; `NUSIZ=3`; VDEL on |
| 9–13 | 5 | Top positioner | P0 to the game X; ball to its X; `NUSIZ=1`; VDEL off; `ENABL=1`; HMOVE |
| 14–177 | 164 | Play | 82 rows × 2 lines; playfield bands; P0 player rows 72–79; ball rows 8–70 |
| 178–182 | 5 | Handover | P0=16, P1=24; `NUSIZ=3`; VDEL on; gold; `ENABL=0`; HMOVE |
| 183–191 | 9 | Mark | `MarkDraw`: line 0 setup, lines 1–8 glyphs; P0=16, P1=24; gold |
| — | **192** | | |

Absolute scanlines:

| Zone | Scanlines |
|---|---|
| Score | 37–45 |
| Top positioner | 46–50 |
| Play | 51–214 |
| Handover | 215–219 |
| Mark | 220–228 |
| Overscan | 229–258 |
| Next VSYNC | 259 |

The exact cycle at `ScoreDone`, `PlayStart`, `HandoverStart`, and `MarkStart` is
measured in Session B. The frame gate is `StartFrame` 259/3, `VblankStart` 0/5,
`BodyStart` 37/5, `OverscanStart` 229/6, and 262 lines.

## 3. RAM map

`+clean_start` zeroes `$80–$FF`. The score library owns `$A0–$D7`.

| Address | Name | Purpose |
|---|---|---|
| `$80` | `Frame` | frame counter (wraps) |
| `$81` | `PlayerX` | P0 TIA X, 8–144 |
| `$82` | `BallX` | ball TIA X |
| `$83` | `BallY` | play-zone row, 8–70 |
| `$84` | `PrevFire` | fire edge latch |
| `$85` | `PrevSelect` | SELECT edge latch |
| `$86` | `AutoTimer` | idle counter |
| `$87` | `AutoPlay` | 1 after 120 idle frames |
| `$88` | `MarkVisible` | 0 = hidden, 1 = visible; reset sets 1 |
| `$89` | `Hit` | one-frame collision flag |
| `$8A` | `MarkRow` | mark kernel row counter |
| `$8B` | `MarkTmp` | mark kernel column-3 scratch |
| `$8C–$8F` | — | free |
| `$A0–$A5` | `ScoreDigits` | score library |
| `$A6` | `ScoreRow` | score library |
| `$A7` | `ScoreTmp` | score library |
| `$A8–$D7` | `ScoreBuf` | 48-byte score buffer |
| `$D8–$F7` | — | free / future |
| `$F8–$FF` | stack | |

The mark table is **not** in RAM. It is a 48-byte ROM table.

## 4. ROM map

| Region | Contents |
|---|---|
| Code | `Reset`, `StartFrame`, `Vblank`, `PositionGame`, `PlayKernel`, `Handover`, `MarkSetup`, `MarkDraw`, `ReadInput`, `AutoDemo`, `ToggleMark` |
| Library | `include/score.asm` (`ScoreInit`, `ScoreClear`, `ScoreSetup`, `ScoreDraw`, `ScoreAddOne`, `ScoreFont`) |
| Tables | `MarkBuf` (48 bytes, page-aligned), playfield band constants, vectors |
| Total | 4,096 bytes |

## 5. The score band

- VBLANK sets `ENABL=0` so the ball is off during the score and mark bands.
- `ScoreSetup` runs in VBLANK: `NUSIZ0=NUSIZ1=3`, VDEL on, P0=56, P1=64, one HMOVE.
- `COLUP0`/`COLUP1` = white (`$0E`).
- `ScoreDraw` consumes nine visible lines: line 0 is the setup/blank line, lines 1–8
  are the glyph rows. The score buffer is column-major, bottom-up, 48 bytes.
- `ScoreAddOne` updates the buffer on a hit.

## 6. The top positioner

- P0 moves from X=56 to `PlayerX`; the ball moves to `BallX`.
- `NUSIZ0=1`, `NUSIZ1=1`; `VDELP0/VDELP1=0`; `ENABL=1`.
- `COLUP0` = red; `COLUPF` = the play-field/ball colour.
- `SetGameP0` and `SetGameBall` are the Lesson 39 divide-by-15 routines with the
  Lesson 26 bias (`+3`). Each takes two lines; the fifth line carries the HMOVE.
- The HMOVE applies P0 and the ball; P1 is blank and its stale motion is harmless.
- After the HMOVE, do not write a motion register for 24 machine cycles. The WSYNCs
  between the routines satisfy the rule.

## 7. The play kernel

- 82 rows × 2 lines. Each row writes the playfield bytes at band boundaries and
  selects the band colour; the player and ball graphics are written per row.
- P0 player: 8 pixels wide, 16 lines tall (8 kernel rows), fixed at rows 72–79.
  `PlayerX` is the TIA X; the player is repositioned once per frame.
- Ball: 1 pixel wide, 8 lines tall (4 kernel rows), X=`BallX`, Y=`BallY` (8–70).
  The ball shares `COLUPF`. The sky is mostly PF-off, so the gold ball reads against
  `COLUBK`; the few static star bits are sparse. The ground band's PF is on, so the
  ball blends near the catch. That is acceptable for the demo and is called out in
  the lesson.
- Playfield: a dark sky, a horizon, and a ground band. The horizon and ground are
  written once per band; the sky has a few PF star bits.
- `CXP0FB` is read in the next VBLANK; a hit adds one to the score, resets the ball to
  row 8, and chooses a new X. The one-frame hit delay is the Lesson 38/50 behaviour.
- The play area never uses P1; P1 is reserved for the score and the mark.

## 8. The handover

- The handover is five lines, visible 178–182.
- `SetMarkP0` (two lines) positions P0 at X=16; `SetMarkP1` (two lines) positions P1
  at X=24; the fifth line carries the HMOVE.
- `NUSIZ0=NUSIZ1=3`; `VDELP0=VDELP1=1`; `COLUP0`/`COLUP1` = gold (`$1A`);
  `ENABL=0` (the ball leaves the screen).
- The HMOVE blanking falls in the blank handover line, not on the mark.
- After the HMOVE, the mark draw writes no motion registers; the next frame’s score
  setup is far away in VBLANK.

## 9. The mark band and table

- `MarkSetup` is the mark-position copy of `ScoreSetup`:
  - `NUSIZ0=NUSIZ1=3`, VDEL on, P0=16, P1=24, one HMOVE.
  - It does **not** call the shared `ScoreSetup`, because that routine hard-codes
    56/64. Refactoring the shared library would affect Lessons 39, 40, 50, 55, 61,
    63, and the capstones; the lesson copies the setup instead and explains why.
- `MarkBuf` is 48 bytes, column-major, bottom-up:
  - column `c`, row `r` at `MarkBuf + c*8 + r`;
  - six cells: R, A, C, I, N, G;
  - each glyph is 5×7 in an 8×8 cell; byte 0 is `$00`, so the lit block is seven rows
    (visible 184–190).
- The table is preceded by `!align 255,0`. The 48 bytes stay inside one page, so every
  `LDA MarkBuf+n,Y` is four cycles; a page cross would add one and shift the column.
- `MarkDraw` is a clone of `ScoreDraw` with `MarkBuf`, `MarkRow`, and `MarkTmp`:
  - the six stores and the seventh flush are unchanged;
  - the `NOP` and `CPX MarkRow` are timing only; keep them;
  - the cleanup blanks `GRP0`/`GRP1` and clears VDEL.
- If `MarkVisible=0`, the band still consumes nine lines: skip `MarkDraw`, keep the
  players blank, and clear VDEL. The frame does not change.

## 10. Input and auto-demo

- Reset initializes `MarkVisible=1`, `AutoTimer=0`, and `AutoPlay=0`.
- `SWCHA` P0 left/right moves `PlayerX` (follow the exact bits used by Lesson 27/42).
- `INPT4` fire resets the score to 000000 with `ScoreClear`.
- `SWCHB` bit 1 SELECT: an edge toggles `MarkVisible` through `ToggleMark`.
- The auto-demo starts after 120 idle frames. The player tracks `BallX`; the ball falls;
  the hit increments the score. After the demo starts, `ToggleMark` is called at a
  scripted frame so `game.png` shows the mark and `no-mark.png` shows the blank band.
  Session B tunes the exact frames and records them in the capture notes.

## 11. Checkpoints and state evidence

| Checkpoint | Evidence |
|---|---|
| `StartFrame` | 259/3 |
| `VblankStart` | 0/5 |
| `BodyStart` | 37/5 |
| `ScoreDone` | visible line 9 / scanline 46 |
| `PlayStart` | visible line 14 / scanline 51 |
| `HandoverStart` | visible line 178 / scanline 215 |
| `MarkStart` | visible line 183 / scanline 220 |
| `MarkDone` | visible line 192 / scanline 229 |
| `OverscanStart` | 229/6 |

State log: `ScoreWrite` (A=the new score), `MarkVisible` (A=0/1), `PlayerXRead`,
`BallYRead`, `Hit` (A=the score), `SelectEdge` (A=1 on a toggle).

## 12. Exercises

| # | Exercise | Expected result |
|---|---|---|
| 1 | A ten-letter mark with a 4×7 font packed two letters per 8-pixel cell | The new wordmark fits in 40–48 px; the table stays 48 bytes; frame 262 |
| 2 | Move the mark to the bottom-right (P0=96, P1=104) or centre (P0=56, P1=64) | The mark moves; only the mark position constants change; frame 262 |
| 3 | *Stretch:* draw the mark with PF0/PF1/PF2 in the bottom eight lines | A blockier 4-px mark; the players are free; the PF table is 24 bytes; frame 262 |

Every solution is a complete 4,096-byte ROM and is committed.

## 13. Captures

| File | Content |
|---|---|
| `docs/public/images/lesson79/game.png` | ~2 s: white score, red player, gold ball, gold `RACING` mark bottom-left |
| `docs/public/images/lesson79/no-mark.png` | ~6 s: SELECT toggled; the mark band is blank; the rest unchanged |

Both are 1010×807, title bar `Stella 7.0: "79-publisher-mark"`, no cursor, captured
from the committed ROM. The mark block is TIA X=16–63, visible 184–190; the score
block is TIA X=56–103, visible 1–7. Pixel-check both against the rendered tables.

## 14. Document outline

1. Frontmatter: title, description, `prev` to `/part11-legendary/`, no `next`.
2. Meta block: Part 11, estimated 150 minutes, prerequisites, you will learn, you will build.
3. Introduction: from Lessons 39/50/55 to the in-game mark; the Activision practice.
4. TypeScript equivalent: zones, `drawScore`/`drawMark`, the table; where the analogy breaks.
5. Theory: the bottom band and the 192-line budget; the second 48-pixel window;
   the handover and the three HMOVEs; the ROM table and page alignment; title-screen
   logo vs in-game mark; Activision history and the trademark rule.
6. The Code: building, full source, walkthrough.
7. What You Should See: captures, RomPlayer, debugger checks.
8. Exercises 1–3 with hints, expected results, and solution file names.
9. Key Takeaways: 5–7.
10. What’s Next: the Part 11 index and the remaining 73–78 lessons.

## 15. Site integration

- Sidebar: add `79 — The Publisher Mark` under Part 11, linked to the doc.
- Part 11 index: rebuild to the standard lesson table; 79 ✅, 73–78 🔮; “seven
  lessons / 79 total”; the page no longer says the whole part is coming soon.
- `prev` → `/part11-legendary/`; no `next`; “What’s Next” → the Part 11 index.
- RomPlayer under the screenshot.
- README: line 3 `78` → `79`; line 26 `73–78` → `73–79`.
- `docs/index.md`: tagline 78 → 79; row 11 73–78 → 73–79 and add the publisher mark.
- `package.json` description and `config.ts` description/OG: 78 → 79.

## 16. Budgets and risks

| Budget | Plan |
|---|---|
| Visible lines | 9 + 5 + 164 + 5 + 9 = 192 |
| ROM | 4,096 main; 48-byte mark table; 80-byte score font; code and vectors |
| RAM | `$80–$8F` game, `$90–$9F` free, `$A0–$D7` score library, `$D8–$F7` free, stack `$F8–$FF` |
| Cycles | Score/mark 9-line kernels per Lesson 39; play 2-line; positioner 2 lines per object; handover 2 lines per player |

| Risk | Mitigation |
|---|---|
| The 5-line positioner/handover is tight | Reuse the Lesson 50 two-line routines; measure at Session B; adjust the play zone if needed |
| Three HMOVEs per frame | Each in a blank HBLANK; 24-cycle rule; no motion writes during the play or mark draw |
| `MarkBuf` page cross | `!align 255,0`; static check of the table’s last access |
| 4K ROM budget | Mark table in ROM; no sound; simple play field |
| Mark visibility | Gold on a dark field; the score is white; the player red |
| Trademark | Original `RACING`; history as context only |
