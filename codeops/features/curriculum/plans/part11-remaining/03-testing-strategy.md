# Lessons 73–78 — Testing Strategy

> **Evidence rule**: every frame, pixel, and cycle claim has a state log, a static ledger, or
> a pixel check. Screenshots alone are not evidence.

## Specification test cases

| ID | Case | Method | Expected |
|---|---|---|---|
| ST-73.1 | Assemble the artifact set | `acme` for 3 sources (main + 2 solutions) | 3 x 4,096 bytes; byte-identical to the committed ROMs |
| ST-73.2 | Frame | Stella state log | 262 lines; `StartFrame` 259/3, `Vblank` 0/5, `Body` 37/5, `Planet` 197/5, `Overscan` 229/3 (line 229) |
| ST-73.3 | Stars | Pixel check + state log | At least 40 star pixels; 3 M0 copies (mod 160); no stars below the horizon; 160/160 bar in both states |
| ST-73.4 | Second strobe | Pixel check + state log | The bar is on 160/160 star lines in both states; the visible-line strobe shifts the field right (bounded, line-dependent); the frame stays 262 |
| ST-73.5 | Exercises | Assemble + run | ex1 73-star, five-band field; ex2 2-frame scroll + 16-frame twinkle; both 4,096 and 262 lines |
| ST-74.1 | Assemble | `acme` | 3 x 4,096 |
| ST-74.2 | Frame | State log | 262; Body 37/5; first blanked line 229 (label 228/12) |
| ST-74.3 | Skipdraw | State log + pixel check | Rocket rows only at RocketY..RocketY+15; GRP0=0 above/below; the two captures show two heights |
| ST-74.4 | Cycles | Static ledger + Stella | P0 path and skip path both 76 cycles or less; no frame growth |
| ST-74.5 | Exercises | Assemble + run | ex1 second sprite; ex2 branchless form; 4,096 and 262 |
| ST-75.1 | Assemble | `acme` | 3 x 4,096 |
| ST-75.2 | Frame | State log | 262; Body 37/5; Overscan 229/6 |
| ST-75.3 | Road | Pixel check | Road edges widen monotonically to the bottom; centre line visible; sky above the horizon |
| ST-75.4 | Curve | Pixel check + state log | `curve.png` centre differs from `straight.png` by at least 4 px at the bottom |
| ST-75.5 | Exercises | Assemble + run | ex1 recolour; ex2 second curve phase; 4,096 and 262 |
| ST-76.1 | Assemble | `acme` | 3 x 4,096 |
| ST-76.2 | Frame | State log | 262; Body 37/5; Overscan 229/6 |
| ST-76.3 | Determinism | Host model + state log | Seed A repeats the same 16 rows; seed B differs in at least 4 rows |
| ST-76.4 | World | Pixel check | Four tile types visible; the player sprite sits in the world band |
| ST-76.5 | Exercises | Assemble + run | ex1 palette/density; ex2 reverse step; 4,096 and 262 |
| ST-77.1 | Assemble | `acme` | 3 x 4,096 |
| ST-77.2 | Frame | State log | 262; Body 37/5; Overscan 229/6 |
| ST-77.3 | Phase | State log + pixel check | Phase toggles every frame; the 8 bands' colours differ between the captures |
| ST-77.4 | Freeze | State log | SELECT/freeze holds one phase; the frame stays 262 |
| ST-77.5 | Exercises | Assemble + run | ex1 third pair; ex2 interlace fields; 4,096 and 262 |
| ST-78.1 | Assemble | `acme` | 3 x 4,096 |
| ST-78.2 | Frame | State log | 262; Body 37/5; Overscan 229/6 |
| ST-78.3 | Rooms | State log + pixel check | Room index changes; the room walls differ between captures |
| ST-78.4 | Objects | State log | The key object is visible in room 1; after pickup it follows the player (or is gone) |
| ST-78.5 | Exercises | Assemble + run | ex1 fifth room; ex2 second behaviour; 4,096 and 262 |

## Cross-lesson cases

| ID | Case | Method | Expected |
|---|---|---|---|
| ST-P11.1 | ROM drift | `npm run roms` + `verify.sh` | The count `verify.sh` reports (275 after Lesson 74; 287 after Lesson 78), no drift |
| ST-P11.2 | Full source | Source vs document block | Exact match for all six |
| ST-P11.3 | Site | `npm run docs:build` | No dead links; all six sidebar entries and part-index rows live |
| ST-P11.4 | README | Read the curriculum table | 79 lessons; Part 11 = 73–79 (unchanged from the amendment) |

## Review gates

Both specialist reviews run per lesson. A lesson is done only with 0 critical and 0 major open.
Accepted limitations are recorded with the reason and the evidence basis.
