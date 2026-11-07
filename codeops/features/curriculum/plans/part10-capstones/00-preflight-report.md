# Preflight Report: Part 10 — Capstone Projects (Lessons 69–72)

> **Document**: 00-preflight-report.md
> **Parent**: [Index](00-index.md)
> **Run**: 2026-11-07, before the first lesson phase
> **Method**: plan audit against RD-10, the shipped course, the expert references, Stella 7.0,
> ACME 0.97, Python 3, and five executable prototypes (the Pong frame/score, the one-line
> multi-object failure, the row-table two-line kernel, the forced-object rendering, and the
> split-versus-mirror maze decision).
> **Verdict**: ✅ **GATE PASSED** — 1 critical and 4 major findings resolved; 5 minor findings
> folded into the lesson specs; 2 observations recorded. No unresolved blocker remains.

## Findings

### Critical

| ID | Finding | Risk | Resolution |
| --- | --- | --- | --- |
| PF-01 | A one-line multi-object kernel cannot write GRP0 before P0's pixel time when three range tests precede the store. The preflight's P0 branch wrote GRP0 at cycle ~49; P0 at X=16 (pixel 48) displayed the old byte every line, so the left paddle was invisible while P1 at X=136 rendered. | A Pong/Breakout/Maze kernel that loses its leftmost object is not shippable. | **Resolved:** the games use a **precomputed row table + a two-line kernel**. The table stores one byte per row with the object bits; the kernel reads the byte and stores P0/P1/ball at the start of the row's first line. The prototype measured `StartFrame` 259, `BodyStart` 37, `OverscanStart` 229 with P0, P1, and the ball visible. AR-11; spec §Lesson 69. |

### Major

| ID | Finding | Risk | Resolution |
| --- | --- | --- | --- |
| PF-02 | The score library positions P0/P1 at 56/64 and uses three copies; Pong needs P0/P1 at 16/136 for the paddles. Calling `ScoreSetup` once at reset leaves the score drawn at the paddle positions after the first reposition. | The score band would garble or the paddles would draw at the score's X. | **Resolved:** call `ScoreSetup` every frame in VBLANK (it re-positions P0/P1 at 56/64), draw `ScoreDraw`, then reposition P0/P1 for the game. The preflight measured `ScoreDone` at line 46 and the frame at 229. Pong instead uses a custom one-digit-per-player score to free the RAM. AR-10; spec §Lesson 69, §Lesson 70. |
| PF-03 | The Pong row table is 89 bytes. With the score library's `$A0-$D7` reserved, only 64 free bytes remain; the table plus game variables does not fit. | A RAM map that overlaps the score or the stack silently corrupts the game. | **Resolved:** Pong uses a **custom score** (P0 = left digit, P1 = right digit) instead of the score library. The map is row table `$80-$D8`, variables `$D9-$F0`, stack `$F1-$FF`. Breakout/Maze keep the score library and size their row tables to the free 64 bytes. AR-24; spec §Lesson 69. |
| PF-04 | The two-line row kernel's body must fit one scanline (76 cycles). The naive three-range-test compute was ~99 cycles including `JSR/RTS`; the frame drifted to 198 lines for 89 rows. | A row kernel that overruns adds scanlines and rolls the picture. | **Resolved:** the row table replaces the per-line range tests. The kernel body is ~45 cycles: read the table byte, decode three bits, store, two `WSYNC`s. The prototype's 96-row play area measured exactly 192 visible lines and a 262-line frame. AR-11; spec §Lesson 69. |
| PF-05 | A 20-column full-width maze at 8 px per cell needs 40 playfield chunks; the TIA gives 20 per half. A split-playfield kernel was considered but has no course precedent and a tight mid-line deadline. | A maze that repeats or mirrors unintentionally. | **Resolved:** Lesson 71 uses a **mirror maze**: 10 unique columns × 11 rows, each cell 8×16 px, drawn in reflect mode so the screen shows 20×11 cells. The column transform is `col < 10 ? col : 19 - col`. The generator emits the 11×3 PF rows and the wall map. AR-17; spec §Lesson 71. |

### Minor

| ID | Finding | Resolution |
| --- | --- | --- |
| PF-06 | The games are moving states; a fixed wait can capture the wrong state. | Every game has a deterministic auto-demo (Pong paddle tracking, Breakout paddle tracking, Maze scripted path, Lesson 72 state timer); the doc discloses the waits and the SELECT path. AR-7. |
| PF-07 | Breakout's 64-entry × 3-byte brick PF table is 192 ROM bytes. | The table is lesson-scoped and page-aligned; the 4K budget still leaves room for the game. The lesson quotes the table size. AR-15. |
| PF-08 | The Lesson 71 generator is Python and CI has no Python step. | Commit `maze-data.inc`; the generator has a read-only `--check`; CI never runs Python. AR-18, AR-29. |
| PF-09 | The Part 10 index is intro-only (no lesson table), unlike Parts 7–9. | Lesson 69 rebuilds it to the Part 7/8/9 format and flips row 69. AR-9. |
| PF-10 | Lesson 72's `next` has no Part 11 lesson page yet. | Point `next` at the Part 11 index (`/part11-legendary/`), which exists. AR-30. |

### Observations

| ID | Observation | Handling |
| --- | --- | --- |
| OB-1 | The sidebar entries for 69–72 already exist at `config.ts:164–167`; no navigation rewrite is expected. | Verify only; flip the four lesson rows. |
| OB-2 | `include/score.asm` owns `$A0-$D7` and draws nine visible lines; `include/sound.asm` expects a `SoundTable` of 8-byte records. | Breakout/Maze reuse the score library with the repositioning sequence; Lesson 72 demonstrates the sound table. |

## Prototype Evidence

| Prototype | Command / artifact | Result |
| --- | --- | --- |
| Pong frame + score | `pong.bin`, breakpoints `StartFrame`/`VblankStart`/`BodyStart`/`ScoreDone`/`OverscanStart` | 259/3, 0/5, 37/5, 46, 229/12; the score draws in the top 9 lines; the frame is 262. |
| One-line multi-object failure | `pong.bin` with the inline range tests; `P0Hit` breakpoint | `P0Hit` at cycle 49; P0 at X=16 invisible; P1 at X=136 visible. The root cause is the store-after-pixel-time. |
| Forced-object render | `pong-test.bin` with GRP0/GRP1/ENABL forced on | Left bar at TIA X≈17, right bar at X≈136, ball at X≈85; the positioners and colors are correct. |
| Row-table two-line kernel | `rowtable.bin`, 96 rows × 2 lines, P0/P1/ball bits | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/17; P0 and P1 8×24 px, the ball 4 lines; frame 262. |
| 4-line alternative | `pong-4line.bin` | Renders the paddles but the frame drifts (overscan 255/256); rejected because the 4-line row's compute still spills. |
| Maze decision | Plan-level arithmetic: 20 cells × 2 chunks = 40 chunks > 20 per half; reflect gives 10 unique cells | The mirror maze is the only full-width design without a split-playfield kernel. |

## Gate Conditions Carried into Execution

1. Pong uses the 89-byte row table and the custom one-digit score; the source header is the exact
   RAM map.
2. Breakout uses the 9-line score + 48-line brick + 128-line play partition; the ball is drawn in
   both zones.
3. Maze uses the mirror transform and the committed generator include; the generator `--check`
   passes before the lesson commit.
4. Every game has a deterministic auto-demo; every capture comes from the committed ROM and is
   pixel-checked.
5. Lesson 72's demo is a complete mini-game with the three `YOUR GAME` sections; the exercises
   are design tasks answered in the doc.
6. `bash scripts/verify.sh` is green before every lesson commit.
7. The Part 10 index is rebuilt in Lesson 69; README row 10 stays unchanged.
