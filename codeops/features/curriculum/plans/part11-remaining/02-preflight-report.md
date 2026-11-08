# Lessons 73–78 — Preflight Report

> **Status**: Passed 2026-11-08. No prerequisite gap; no screenshot gap. Each lesson's new
> mechanism is the lesson's subject; every supporting mechanism was taught earlier.

## Prerequisites (all earlier lessons)

| Lesson | Supporting lessons | Why they are enough |
|---|---|---|
| 73 | 12 NTSC frame, 14 WSYNC/timing, 17 cycle counting, 18 mid-scanline, 26 positioning, 29 missiles/ball, 31 copies/sizes, 54 visual effects | The frame, the 76-cycle line, `RESM0`/`RESBL`, `NUSIZ` three-copy mode, and the HMOVE rule are all taught before the starfield. |
| 74 | 14, 17, 25 player sprites, 26 positioning, 29 missiles/ball, 48 kernels, 49 2-line kernel, 53 kernel patterns | The reader has written a kernel, positioned a player, and counted cycles; skipdraw adds the carry trick to known parts. |
| 75 | 12, 14, 17, 19–24 playfield, 21 asymmetric playfield, 49 2-line kernel, 52 fine scrolling, 54 effects | The playfield writes, the asymmetric mid-line rewrite, and the 2-line budget are all earlier material. |
| 76 | 9 bitwise, 11 lookup tables, 23 data-driven playfield, 43 random numbers, 49, 52, 61 compression | Shifts, tables, random generation, and scrolling are known; the LFSR is the new subject. |
| 77 | 12, 13 colours, 14, 17, 51 flicker sprites, 54 effects | Flicker is taught as an object technique; this lesson extends it to whole-frame colour mixing. |
| 78 | 10 addressing, 11 tables, 19–24 playfield, 25–32 sprites, 38 collision, 41 game states, 45 memory, 53 patterns, 71 Maze Explorer | Tables, sprites, collision, states, and a room-based game are all earlier; the engine architecture is the new subject. |

No forward reference: each document names only earlier lessons, except its What's Next link.

## Technical accuracy checks

| Lesson | Check | Source / method |
|---|---|---|
| 73 | Repeated `HMOVE` re-applies the motion registers; HMOVE in the visible line blanks the leftmost 8 pixels | `references/legendary.md`, problemkaputt.de TIA notes; verify in Stella |
| 73 | `RESM0`/`RESBL` position at the beam with a fixed output delay; `NUSIZ=3` is three close copies | `references/tia-hardware.md`, Lessons 26/31 |
| 74 | `SBC`/`CMP` carry is the unsigned "below" test; the skip branch is the only branch; both paths must be cycle-padded | `references/6502-cpu.md`; count both paths in Stella |
| 74 | The missile form `ROL; ROL; EOR #2` turns carry into `ENAM0`'s bit 1 without a branch | Derived from the carry/rotate semantics; verify in Stella |
| 75 | A 2-line kernel gives 76 cycles per row; the left playfield half is latched before the right-half rewrite | `references/timing.md`, Lesson 21; measure the store cycles |
| 76 | A Galois LFSR with taps `$B8` has a maximal period of 255 states; the same seed repeats the sequence | `references/6502-cpu.md`, standard LFSR arithmetic; verify with a host model and Stella |
| 77 | Two 30 Hz frames alternate; the eye blends them; a single capture shows one phase | `references/kernels.md` flicker section; disclose the static-capture limit |
| 78 | A room table plus an object table interpreted by one engine is data-driven, not per-room code | `references/legendary.md`; compare ROM size with a per-room version |

## Screenshot plan

Two captures per lesson, from the committed main ROM, 1010x807, title bar
`Stella 7.0: "<slug>"`, pointer parked, no cursor, auto-demo state.

| Lesson | Capture A | Capture B |
|---|---|---|
| 73 | `starfield.png` — clean field, stars + planet + ship | `comb.png` — comb mode, 8-pixel bars at the left |
| 74 | `rocket-low.png` — rocket low, exhaust clipped at the ground | `rocket-high.png` — rocket high, exhaust follows |
| 75 | `straight.png` — road at phase 0 | `curve.png` — road curved, centre line visible |
| 76 | `world-seed-a.png` — seed A world | `world-seed-b.png` — seed B, visibly different |
| 77 | `phase-a.png` — colour phase A | `phase-b.png` — colour phase B |
| 78 | `room-1.png` — start room with the key | `room-2.png` — second room, key carried |

Each document shows both captures and one `<RomPlayer>` for the main ROM.

## Risks carried into implementation

- Lesson 73: the comb must be visible without corrupting the whole picture; the auto-demo
  toggle must be scripted, not input-dependent.
- Lesson 74: a 1-line kernel has 76 cycles; the P0 and M0 paths must fit with the playfield
  and the loop.
- Lesson 75: asymmetric playfield timing is the hardest part; fall back to a symmetric road
  with a colour-shift curve only if the timing cannot be made stable, and record it.
- Lesson 76: the LFSR must be maximal-length and the ring must fit in RAM (16 rows x 20 bits
  = 40 bytes, fine).
- Lesson 77: a static screenshot cannot show the blend; the document must say so explicitly.
- Lesson 78: the engine must stay under 4K with four rooms and two objects; the tables must be
  data, not code.
