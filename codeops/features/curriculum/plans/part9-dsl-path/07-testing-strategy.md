# Testing Strategy: Part 9 — The DSL Path (Lessons 66–68)

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
4. The Part 9 index row is ✅; prev/next links resolve; the sidebar entry exists; README row 9 is
   unchanged.
5. The captures exist, come from the committed lesson ROM, show the title bar, and have no cursor;
   the doc's pixel table matches the measurements.
6. Both specialists report no critical/major open.

The state-log command shape is:

```bash
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$ADDR' \
  docs/public/roms/part9-dsl-path/NN-slug/NN-slug.bin
```

`BP: <hit> <scanline> <cycle> <pixels> | <flags> <A> <X> <Y> <SP>` is the log format. A label
reports the first cycle of the instruction that follows it.

---

## Lesson 66 — Analyzing batari BASIC

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-66.1 | Assemble the demo | 4,096 bytes; `acme` clean; Full Source verbatim | `acme`, byte compare |
| ST-66.2 | Assemble the bB reference | `lesson66.bas` compiles with bB 1.9 + wasmtime 50.0.1 to 4,096 bytes; the committed `lesson66-bb.bin` matches | bB command + byte compare |
| ST-66.3 | Run the three lenses | RUN, ZONES, VARS differ; SELECT cycles them; 3 captures; the bB reference player runs its own screen | Screenshots + pixel check |
| ST-66.4 | Inspect the frame and lens state | `StartFrame` 259/3; `VblankStart` 0/5; `BodyStart` 37/5; `OverscanStart` 229/6; `LensWrite` A=0→1→2; `Frame` advances | State log |
| ST-66.5 | Verify the bB claims | The committed listing contains `start`, `.main`, `drawscreen`, `kernel`, `vblank_bB_code`, `overscan`; the `if` lowering is the reversed compare; the score is `SED/CLC/ADC/CLD`; the reference ROM's 4,096 bytes and `start` at `$F000` | Listing + symbol table |
| ST-66.6 | Exercises and site integration | Three analysis answers are complete and consistent with the listing; index row 66 ✅; prev 65/next 67; sidebar `config.ts:153`; README unchanged | Page check |

## Lesson 67 — Automatable Patterns

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-67.1 | Validate the specs | `lesson67-generate.py --check` exits 0 with and without `--out`; a bad spec (frame 300) exits 1 with `spec:line`; a tampered include exits 1 with a drift diff; the two specs produce the committed `generated-levels.inc` | Generator run |
| ST-67.2 | Assemble the main ROM | 4,096 bytes; the generated include is `!source`d; Full Source verbatim | `acme`, byte compare |
| ST-67.3 | Run both levels | Level A and B differ (name, colours, backdrop, waves); SELECT switches; 3 captures (level-a, level-a-hit, level-b); the waves spawn at the generated frames | Screenshots + pixel check |
| ST-67.4 | Inspect the state | `LevelRead` A=0/1; `LevelWrite` A=1 on the SELECT edge; `WaveSpawn` A=the wave index and X=the slot offset; `ScoreWrite` advances; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6 | State log |
| ST-67.5 | Verify the generated tables | The host parser reads the spec and the include; every `WaveFrame/X/Y/Speed/Type` matches; the level descriptor pointers resolve; the backdrop is 8×3 bytes | Host-side check |
| ST-67.6 | Assemble/run the exercises | ex1 4,096 with type 2 (true triangle); ex2 4,096 with three levels (source inspection + start-at-C, disclosed); ex3 4,096 with the colour schedule (hit-between-entries log) | `acme`, Stella logs |
| ST-67.7 | Site integration | Index row 67 ✅; prev 66/next 68; sidebar `config.ts:156`; `<RomPlayer>` path; README unchanged | Page check |

## Lesson 68 — Kernel Architecture

| ID | What | Expected | Evidence |
| --- | --- | --- | --- |
| ST-68.1 | Assemble the main ROM and framework | 4,096 bytes; `+kf_end` passes for all three layouts; changing a zone line by one makes `+kf_end` fail with a 191/193 error | `acme` (positive + negative) |
| ST-68.2 | Run the three layouts | STATUS, STARFIELD, SPLIT differ; SELECT cycles; 3 captures | Screenshots + pixel check |
| ST-68.3 | Inspect the frame and layout state | `StartFrame` 259/3; `VblankStart` 0/5; `BodyStart` 37/5; `OverscanStart` 229/19; `LayoutWrite` A=0→1→2; `Frame` advances; `KernelEnd` at the last zone | State log |
| ST-68.4 | Verify the budget | The source's `KF_LINES` ledger sums 192 for each layout; the measured Body→Overscan span is exactly 192 scanlines (37 → 229) | Static ledger + state log |
| ST-68.5 | Assemble/run the exercises | ex1 4,096 with the ball zone; ex2 4,096 with a fourth layout/selector; ex3 4,096 with a runtime zone | `acme`, Stella logs |
| ST-68.6 | Site integration | Index row 68 ✅; prev 67/next 69; sidebar `config.ts:155`; `<RomPlayer>` path; README unchanged | Page check |

## Test Categories

### Specification Tests (from the ST cases)

There is no separate unit-test harness: the course's executable tests are ACME assembly, the
committed-ROM drift check, Stella state logs, static ledgers, and PIL pixel checks. The ST cases
are enacted by the Session C evidence scripts; the expectations above are the immutable oracle.

### Implementation Tests

| Test | Description | Priority |
| --- | --- | --- |
| Generator negative test | A bad spec (frame 300, x 200, type 9) exits nonzero with a location | High |
| Framework negative test | A 191-line layout fails `+kf_end`; a 193-line layout fails | High |
| Framework RAM test | `Layout`/`Frame` at `$83/$84`; `$80–$82` remain the pattern library's; the frame is 262 | High |
| bB listing test | The committed listing's key labels and the reversed `if` are present; the reference ROM is 4,096 | High |

### Integration / End-to-End

| Scenario | Steps | Expected Result |
| --- | --- | --- |
| Lesson 66 page | Build, capture 3 lenses + bB reference, open the page | 3 demo images, 2 players, the bB listing quotes; no console error |
| Lesson 67 page | Regenerate the include, build, capture A/B, open the page | 2 images, 1 player, the two levels differ; the generator commands are accurate |
| Lesson 68 page | Build, capture 3 layouts, open the page | 3 images, 1 player, the three layouts differ; the framework API is documented |
| Part 9 site | Build the docs | Sidebar 66–68, index rows, prev/next, and README row 9 correct |

## Test Data

### Fixtures
- `lesson66.bas` and `lesson66.generated.txt` (the bB 1.9 reference).
- `waves-a.txt`, `waves-b.txt`, and the committed `generated-levels.inc`.
- The three Lesson 68 layout ledgers in the source header.
- The committed PNGs under `docs/public/images/lesson66..68/`.

### Mock Requirements
None. The tests use the real ACME, Stella, Python 3, the committed bB reference, and PIL.

## Verification Checklist
- [ ] All ST cases are defined with concrete expectations and sources.
- [ ] Session A freezes the ST cases and records the red baseline.
- [ ] The implementation matches the ST cases; the expectations are never edited to fit.
- [ ] `bash scripts/verify.sh` passes before every lesson commit.
- [ ] The two specialists report no critical/major open.
- [ ] The Part 9 completion gate re-checks all counts and the site.
