# Testing Strategy: Part 10 — Capstone Projects (Lessons 69–72)

> **Document**: 07-testing-strategy.md
> **Parent**: [Index](00-index.md)
> **Rule:** the ST cases are the immutable oracle. Session A freezes them; an implementation
> mismatch is fixed in the implementation, never by editing the expectation. Every case names the
> evidence: `verify.sh`, a Stella state log, a static ledger, a host-side check, or a PIL pixel
> check.

## Shared Verification

Every lesson runs these gates before its commit:

1. `acme -f plain` (or `npm run roms`) produces the declared 4,096 bytes; the committed `.bin` is
   byte-identical.
2. `bash scripts/verify.sh` passes (all ACME sources, no drift, docs build).
3. The document's Full Source is verbatim against the main source.
4. The Part 10 index row is ✅; prev/next links resolve; the sidebar entry exists; README row 10
   is unchanged.
5. The captures exist, come from the committed lesson ROM, show the title bar, and have no cursor;
   the doc's pixel table matches the measurements.
6. Both specialists report no critical/major open.

The state-log command shape is:

```bash
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$ADDR' \
  docs/public/roms/part10-capstones/NN-slug/NN-slug.bin
```

`BP: <hit> <scanline> <cycle> <pixels> | <flags> <A> <X> <Y> <SP>` is the log format. A label
reports the first cycle of the instruction that follows it.

---

## Lesson 69 — Pong

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-69.1 | Assemble the four sources | Main + three solutions 4,096 each; Full Source verbatim | `acme`, byte compare |
| ST-69.2 | Inspect the frame | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `ScoreDone` 46, `OverscanStart` 229 | State log |
| ST-69.3 | Inspect the score | P0's left digit and P1's right digit at X=64/88; `ScoreLeft`/`ScoreRight` A=the new digit; the score changes on a point | State log + pixels |
| ST-69.4 | Inspect the row table | 89 bytes; P0/P1/ball bits; `RowTableWrite` matches the Y ranges; P0 and P1 paddles visible; the ball visible | State log + pixels |
| ST-69.5 | Play/collide | A paddle hit reverses VX (`PaddleHit` A=0/1); a wall bounce reverses VY; the serve parks the ball for 60 frames; the first to 9 sets the over state | State log |
| ST-69.6 | Run the auto-demo | The 2 s/6 s/12 s captures differ (serve/rally/game over); titles; no cursor | Screenshots + pixels |
| ST-69.7 | Assemble/run the exercises | ex1 CPU opponent, ex2 spin/speed, ex3 best-of-three; each 4,096 and runs | `acme`, Stella |
| ST-69.8 | Site integration | Index row 69 ✅; prev 68/next 70; sidebar `config.ts:164`; `<RomPlayer>`; README unchanged | Page check |

## Lesson 70 — Breakout

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-70.1 | Assemble the four sources | 4,096 each; Full Source verbatim | `acme`, byte compare |
| ST-70.2 | Inspect the frame | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `ScoreDone` 46, `BrickStart` 51, `PlayStart` 99, `OverscanStart` 229 | State log |
| ST-70.3 | Inspect the brick field | 6 rows × 6 unique bricks mirrored to 12; the PF bytes match `BrickPF[6-bit mask]`; the first brick is at X=8; the field is 48 lines | Pixels + static check |
| ST-70.4 | Clear a brick | `BrickHit` A=the row; `BrickClear` A=the new mask; the score increments; the brick disappears | State log + pixels |
| ST-70.5 | Lives/levels | A miss decrements `Lives`; 0 -> game over; clearing all 36 unique bricks advances `Level`; the pattern changes | State log |
| ST-70.6 | Run the auto-demo | The 2 s/6 s/10 s captures show the start, a broken field, and level 2; titles; no cursor | Screenshots + pixels |
| ST-70.7 | Assemble/run the exercises | ex1 multi-hit, ex2 levels, ex3 angle/power-up; each 4,096 and runs | `acme`, Stella |
| ST-70.8 | Site integration | Index row 70 ✅; prev 69/next 71; sidebar `config.ts:165`; README unchanged | Page check |

## Lesson 71 — Maze Explorer

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-71.1 | Validate the generator | `--check` exits 0; a tampered include exits 1; a bad spec exits 1 with `spec:line`; the committed `maze-data.inc` matches | Generator run |
| ST-71.2 | Assemble the four sources | 4,096 each; Full Source verbatim | `acme`, byte compare |
| ST-71.3 | Verify the maze data | The PF rows match the wall map; 10 unique columns × 11 rows; the seam is open; 3 keys and 2 enemies on open cells | Host-side check |
| ST-71.4 | Inspect the frame | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `MazeRowStart` 53, `OverscanStart` 229 | State log |
| ST-71.5 | Move and collide | A direction moves the player to an open cell; a wall blocks; the mirror transform works (`col 15` -> unique 4); `WallRead` A=the wall byte | State log |
| ST-71.6 | Keys/enemies/win | A key increments `KeyGet`; the icon fills; an enemy catch sets the lose state; 3 keys set the win state | State log + pixels |
| ST-71.7 | Run the auto-demo | The 2 s/6 s/10 s captures show the start, a key, and the win; titles; no cursor | Screenshots + pixels |
| ST-71.8 | Assemble/run the exercises | ex1 fog, ex2 smarter enemies, ex3 treasure/timer; each 4,096 and runs | `acme`, Stella |
| ST-71.9 | Site integration | Index row 71 ✅; prev 70/next 72; sidebar `config.ts:166`; README unchanged | Page check |

## Lesson 72 — Your Own Game

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-72.1 | Assemble the demo | 4,096; Full Source verbatim | `acme`, byte compare |
| ST-72.2 | Inspect the frame/state | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229; `StateChange` 0->1->2; `ScoreWrite` advances; `Catch`/`Miss` | State log |
| ST-72.3 | Run the auto-demo | The 2 s/6 s captures show the title and the play state; titles; no cursor | Screenshots + pixels |
| ST-72.4 | Verify the doc | The GDD/RAM/screen/4K/milestone templates are complete; the three exercises are answered; the skeleton sections are marked; the production checklist is present | Page check |
| ST-72.5 | Site integration | Index row 72 ✅; prev 71/next Part 11; sidebar `config.ts:167`; README unchanged | Page check |

## Test Categories

### Specification Tests (from the ST cases)

There is no separate unit-test harness: the course's executable tests are ACME assembly, the
committed-ROM drift check, Stella state logs, static ledgers, host-side generator checks, and PIL
pixel checks. The ST cases are enacted by the Session C evidence scripts; the expectations above
are the immutable oracle.

### Implementation Tests

| Test | Description | Priority |
| --- | --- | --- |
| Row-table bounds | The Pong table is 89 bytes; no read past `$D8`; the bits match the object ranges | High |
| Brick PF table | For each 6-bit mask, the 3 PF bytes match the expected chunk pattern | High |
| Brick collision | A ball at a known X/Y maps to the expected row/unique column | High |
| Mirror maze | `col` 0..19 maps to unique 0..9 and back; a wall at unique 4 blocks visible cols 4 and 15 | High |
| Generator negative test | A bad spec (width 0, key on a wall) exits 1 with a location | High |
| Score reposition | `ScoreSetup` + `ScoreDraw` + reposition keeps the score at 56/64 and the paddle at `PaddleX` | High |

### Integration / End-to-End

| Scenario | Steps | Expected Result |
| --- | --- | --- |
| Pong page | Build, capture 3 states, open the page | 3 images, 1 player, the row-table theory; no console error |
| Breakout page | Build, capture 3 states, open the page | 3 images, 1 player, the brick math; no console error |
| Maze page | Regenerate the include, build, capture 3 states, open the page | 3 images, 1 player, the generator commands; no console error |
| Lesson 72 page | Build, capture 2 states, open the page | 2 images, 1 player, the templates; no console error |
| Part 10 site | Build the docs | Sidebar 69–72, index rows, prev/next, README row 10 correct |

## Test Data

### Fixtures
- The Pong row table (89 bytes) and the score font.
- The Breakout brick masks and the 64×3 PF table.
- `maze-spec.txt` and `maze-data.inc` (the committed generator output).
- The committed PNGs under `docs/public/images/lesson69..72/`.

### Mock Requirements
None. The tests use the real ACME, Stella, Python 3, and PIL.

## Verification Checklist
- [ ] All ST cases are defined with concrete expectations and sources.
- [ ] Session A freezes the ST cases and records the red baseline.
- [ ] The implementation matches the ST cases; the expectations are never edited to fit.
- [ ] `bash scripts/verify.sh` passes before every lesson commit.
- [ ] The two specialists report no critical/major open.
- [ ] The Part 10 completion gate re-checks all counts and the site.
