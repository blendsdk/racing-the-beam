# Execution Plan: Part 9 — The DSL Path (Lessons 66–68)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-07 18:54
> **Progress**: 3/4 tasks (75%)
> **CodeOps Artifact Schema**: 1

## Overview

Three phases, one per lesson, strictly sequential — 66 establishes the real bB compilation and
the analysis vocabulary; 67 turns a repeated wave pattern into a DSL and a generator; 68 builds
the kernel framework and the three layouts. Every phase is one task run through the mandatory
three-session ordering: Session A freezes that lesson's specification cases and records a red
baseline, Session B implements the full artifact set, and Session C verifies against the frozen
cases and hardens under independent review (AR-2, AR-5). `bash scripts/verify.sh` is the gate for
every phase (AR-4). bB, generator, framework-budget, and frame claims carry the state-log +
static-ledger + pixel evidence of AR-6/AR-22; every screenshot is pixel-checked against the lesson
geometry (AR-7, AR-22).

**🚨 Update this document after EACH completed task!**

**Session record slots:** each task gets a `**Session A record**` paragraph after its task line
(freeze + red baseline + design pins) and a **Session C record** paragraph after the Session
sub-steps. The per-lesson findings are appended to [05-findings.md](05-findings.md); the plan-level
preflight findings live in [00-preflight-report.md](00-preflight-report.md). The plan is not
executable until the preflight report exists and the roadmap row reads `Executing`. The push mode
is authorized by the user's directive to execute RD-09 and the Part 1–8 practice (AR-25).

---

## Implementation Phases

| Phase | Title | Tasks |
| ----- | ----- | ----- |
| 1 | Lesson 66 — Analyzing batari BASIC | 1 |
| 2 | Lesson 67 — Automatable Patterns | 1 |
| 3 | Lesson 68 — Kernel Architecture | 1 |
| 4 | Part 9 completion gate | 1 |

**Total: 3 lesson tasks + 1 completion gate.**

> **⚠️ EXECUTION RULE — APPLIES TO EVERY AGENT EXECUTING THIS PLAN:**
>
> The task checkboxes below are the **single source of truth** for progress. Every task line
> appears exactly once in this document. The executing agent MUST:
>
> 1. **On implementation:** mark the task `[~]` with a timestamp —
>    `- [~] N.1.1 Task description ⏳ (implemented: YYYY-MM-DD HH:MM)`
> 2. **On verify pass:** promote it to `[x]` —
>    `- [x] N.1.1 Task description ✅ (completed: YYYY-MM-DD HH:MM)`
> 3. **Update the Progress header** and the Last Updated stamp after EVERY task — never batch.
> 4. **Resume** at the first `[~]`, else the first `[ ]`.
> 5. **On blocker:** mark the task `[!]` with a one-line reason.
>
> Timestamps come from `date '+%Y-%m-%d %H:%M'` — never invented.

---

## Phase 1: Lesson 66 — Analyzing batari BASIC

> **Phase baseline tree**: the plan+preflight commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part9-dsl-path/66-analyzing-batari-basic/` (demo, `.bas`,
> generated listing) · `docs/part9-dsl-path/66-analyzing-batari-basic.md` ·
> `docs/part9-dsl-path/index.md` (rebuild to the Part 7/8 format + row 66) ·
> `docs/public/roms/part9-dsl-path/66-analyzing-batari-basic/` (demo + bB reference) ·
> `docs/public/images/lesson66/` (3 demo + 1 reference) · `99-execution-plan.md` +
> `05-findings.md` + roadmaps
> **Reasoning**: high — the first Part 9 lesson establishes the real bB evidence, the demo/bB
> separation, and the analysis vocabulary the next two lessons use

### Step 1.1: Lesson 66 — Analyzing batari BASIC

**Reference**: [03 §Lesson 66](03-lesson-specs.md) · AR-3, AR-9–AR-12, AR-23
**Objective**: ship the three-lens demo, the committed bB 1.9 reference, and the document that
maps the generated code to the 6502/TIA concepts.

- [x] 1.1.1 Lesson 66 — Analyzing batari BASIC: Session A freezes ST-66.1–ST-66.6 (red baseline),
  Session B implements the demo, the bB reference, and the document, Session C verifies to green
  and hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson66): Analyzing batari BASIC` ✅ (completed: 2026-11-07 15:19)

**Session A record** (freeze + red baseline, 2026-11-07 11:47): ST-66.1–ST-66.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 66. Design pins: the doc title is the curriculum/stub title **"Lesson 66: Analyzing batari BASIC — How bB Works"**; the demo is a hand-written ACME `demo-66.asm` (4,096) with three SELECT lenses (RUN/ZONES/VARS), and the bB 1.9 reference is a separate artifact set (`lesson66.bas`, `lesson66.generated.txt`, `lesson66-bb.bin` 4,096) never described as the demo. The bB compile uses bB 1.9 (wasm) + wasmtime 50.0.1 at `/tmp/opencode/part9-preflight/bB`; the generated listing is CC0. The doc quotes the committed listing with line numbers and explains the pipeline, `start`, `.main`, `drawscreen`, the 2-line kernel, `vblank_bB_code`, the overscan, the reversed `if`, the BCD score, and the variable map. Captures: 3 from `demo-66.bin` + 1 from `lesson66-bb.bin`, titles `Stella 7.0: "demo-66"` / `"lesson66-bb"`, no cursor. The Part 9 index is rebuilt to the Part 7/8 format in this lesson (PF-14). No exercise solution files. Red baseline confirmed: no `lessons/part9-dsl-path/66-analyzing-batari-basic`, no `docs/public/images/lesson66`, no Part 9 66 ROMs, the document is the `🔒 Coming Soon` stub, sidebar `config.ts:155`, Lesson 65's `next` already points to 66, `verify.sh` green at `81837ba`. No implementation logic read (AR-2).

**Session B record** (implementation, 2026-11-07 14:24): `demo-66.asm` (4,096) with three SELECT/auto-demo lenses (RUN, ZONES, VARS); `lesson66.bas` compiled with bB 1.9 + wasmtime 50.0.1 to a 4,096-byte reference ROM; the CC0 generated listing plus the address listing, symbol table, and variable-redefs header committed. The Part 9 index was rebuilt to the Part 7/8 format (row 66 ✅). Four captures (1010×807, title bars, no cursor). The doc is 1,906 lines with the Full Source verbatim (1,242 lines). Review fixes: the band preload, the starfield/row-191 timing, the VARS `WriteGridLine` split and the tail guard, the dead-state removal, the committed bB evidence files, the symbol/row/timer wording, and the plan corrections.

**Session C record** (verify + evidence, 2026-11-07 15:19): `bash scripts/verify.sh` PASSED (244 sources, no drift, docs build); demo 4,096 (md5 `a5e88b2082d1e8070e0577b7334f2df0`); bB reference 4,096 (md5 `49f1144d8497b1ef7dd484887e5514c5`, matches a fresh bB 1.9 compile); Full Source verbatim (1,242 source / 1,906 doc lines). Frame: `StartFrame` `$F1A9` 259/3; `VblankStart` `$F1B7` 0/5; `BodyStart` `$F2F2` 37/5; `OverscanStart` `$F66B` 229/6 (680/680 hits); `LensWrite` `$F68B` A=1/2/0 at frames 241/481/721; `LensRead` `$F1F3` A=0/1/2; `FrameRead` `$F1F0`; `MapIndexRead` `$F28E` A=00..1E. The bB listing checkpoints: `start` L51/$F000, `.main` L1832/$F4D0, `drawscreen` L1418/$F3BF, `kernel` L114/$F034, `vblk` L1634/$F438, `overscan` L1469/$F3BF; the reversed `if` and BCD score excerpts match. Captures: run/zones/variables/bb-run 1010×807, titles `Stella 7.0: "demo-66"` / `"lesson66-bb"`, no cursor. Site: Part 9 index rebuilt, row 66 ✅; prev 65/next 67; sidebar `config.ts:155`; README row 9 unchanged. Reviews (AR-5): atari2600-reviewer — 2 major (RUN comments, band tear) + 8 minor, then 1 minor (VARS preload) + 2 residual, then 2 minor (tail OOB, ball column); curriculum-auditor — 2 major (missing artifacts, exercise references) + 14 minor, then 4 minor (plan wording/artifacts, 682, StarLast). All fixed; final 0 critical, 0 major open. Lesson 66 is complete.

**Deliverables**:
- [x] `demo-66.asm` (4,096) with RUN/ZONES/VARS lenses and SELECT.
- [x] `lesson66.bas`, `lesson66.generated.txt`, `lesson66-bb.bin` (4,096) with bB 1.9 provenance.
- [x] `docs/part9-dsl-path/66-analyzing-batari-basic.md` (six-section template, Full Source
  verbatim, 3 demo images + bB reference player, three analysis exercises answered).
- [x] Part 9 index rebuilt to the Part 7/8 format; row 66 ✅; prev 65 / next 67; sidebar; README unchanged.
- [x] `verify.sh` green; both reviews 0 critical/major.

**Verify**: `bash scripts/verify.sh`

---

## Phase 2: Lesson 67 — Automatable Patterns

> **Phase baseline tree**: the Lesson 66 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part9-dsl-path/67-automatable-patterns/` (main + 3
> solutions + generator + specs + generated include) · `docs/part9-dsl-path/67-automatable-patterns.md` ·
> `docs/part9-dsl-path/index.md` (row 67) ·
> `docs/public/roms/part9-dsl-path/67-automatable-patterns/` ·
> `docs/public/images/lesson67/` (3 captures) · `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the generator, the DSL, and the playable engine must agree on every field;
> the lesson's claims rest on the committed generated include

### Step 2.1: Lesson 67 — Automatable Patterns

**Reference**: [03 §Lesson 67](03-lesson-specs.md) · AR-13–AR-15, AR-23
**Objective**: ship the wave-spec DSL, the Python generator, the playable wave lab, and the
generated levels.

- [x] 2.1.1 Lesson 67 — Automatable Patterns: Session A freezes ST-67.1–ST-67.7 (red baseline),
  Session B implements the generator, the spec language, the ROM, the three solutions, and the
  document, Session C verifies to green and hardens; commit via the `git-commit` skill in push
  mode — `feat(lesson67): Identifying Automatable Patterns` ✅ (completed: 2026-11-07 17:32)

**Session A record** (freeze + red baseline, 2026-11-07 15:20): ST-67.1–ST-67.7 re-affirmed against [03](03-lesson-specs.md) §Lesson 67. Design pins: the doc title is the curriculum/stub title **"Lesson 67: Identifying Automatable Patterns — A Wave Compiler"**; the main ROM is `67-automatable-patterns.asm` (4,096, "the wave lab"), with `lesson67-generate.py`, the two specs `waves-a.txt`/`waves-b.txt`, the committed generated include `generated-levels.inc`, and three solutions (`exercise-01/02/03-solution.asm`, 4,096 each). The wave spec is line-oriented (`level`, `name`, `bg`, `pf`, `backdrop`, `wave <index> <frame> <x> <y> <speed> <type>`); the generator validates ranges, emits the include, and has `--check`; CI never runs Python. The picture is a 16-line band + 64-line generated backdrop + 112-line play area; the player P0 moves and fires the ball; enemies use P1/M0/M1/ball; the two levels differ in name/colours/backdrop/waves; SELECT switches; the frame is 262 (`StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6). Captures: `level-a.png`/`level-b.png`. Exercises: zigzag type 2; a third level/selector; a generated colour schedule. Red baseline confirmed: no `lessons/part9-dsl-path/67-automatable-patterns`, no `docs/public/images/lesson67`, no Part 9 67 ROMs, the document is the `🔒 Coming Soon` stub, index row 67 Coming Soon, sidebar `config.ts:156`, `verify.sh --no-docs` green at `a550b97`. No implementation logic read (AR-2).

**Session B record** (implementation, 2026-11-07 16:02): `67-automatable-patterns.asm` (4,096) with the 16-line band, the 64-line generated backdrop, and the 111-line play area; `lesson67-generate.py` with the wave DSL, validation, `--check`, and the `--type-max`/`--allow-level`/`--allow-color` dialect flags; `waves-a.txt`/`waves-b.txt` and the committed `generated-levels.inc`; three 4,096-byte solutions with their own generated includes; the doc with 3 captures (level-a, level-a-hit, level-b). The critical name/stack collision was fixed by moving the name to a generated ROM table; the slot rule, the ex3 colour recompute, the play-area partition, and the generator headers were corrected in review.

**Session C record** (verify + evidence, 2026-11-07 17:32): `bash scripts/verify.sh` PASSED (248 sources, no drift, docs build); main + 3 solutions 4,096 and byte-identical; Full Source verbatim (1,263 source / 2,101 doc lines); all four include `--check` forms pass with the stock generator; a tampered copy exits 1; a bad spec (`frame 300`) exits 1 with `spec:line`; the host parser matches every wave/backdrop. Frame: `StartFrame` 259/3 (power-on 29/18), `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6; `LevelRead` A=0/1; `LevelWrite` A=1; `WaveSpawn` A=0..4 with X=0/4/8/12/4; `ScoreWrite` A=1; `FrameRead` A=0,1,2. Captures: level-a (WAVE-A/000000), level-a-hit (WAVE-A/000001, name band intact), level-b (WAVE-B/000000, `-holdselect`), all 1010×807 with title bars, no cursor. Site: index row 67 ✅, row 68 Coming Soon; prev 66/next 68; sidebar `config.ts:156`; README row 9 unchanged. Reviews (AR-5): atari2600-reviewer — 1 critical (name/stack) + 4 major + 8 minor, then 1 major (header) + 4 minor, then no critical/major; curriculum-auditor — 4 major + 7 minor, then 1 major (exercise regeneration) + 4 minor, then no critical/major. All fixed; final 0 critical, 0 major open. Lesson 67 is complete.
**Deliverables**:
- [x] `67-automatable-patterns.asm` (4,096) + `exercise-01/02/03-solution.asm` (4,096 each).
- [x] `lesson67-generate.py` with `--check`; `waves-a.txt`, `waves-b.txt`;
  `generated-levels.inc`.
- [x] `docs/part9-dsl-path/67-automatable-patterns.md` (DSL grammar, generator, engine, two
  levels, 3 images, 1 player, three exercises with solutions).
- [x] Index row 67 ✅; prev 66 / next 68; sidebar; README unchanged.
- [x] `verify.sh` green; both reviews 0 critical/major.

**Verify**: `bash scripts/verify.sh`

---

## Phase 3: Lesson 68 — Kernel Architecture

> **Phase baseline tree**: the Lesson 67 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `include/kernel_framework.asm` ·
> `lessons/part9-dsl-path/68-kernel-architecture/` (main + 3 solutions) ·
> `docs/part9-dsl-path/68-kernel-architecture.md` ·
> `docs/part9-dsl-path/index.md` (row 68) ·
> `docs/public/roms/part9-dsl-path/68-kernel-architecture/` ·
> `docs/public/images/lesson68/` (3 captures) · `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the framework's budget, boundary line, dispatch tax, and RAM ownership are
> the lesson's correctness core; a silent 191/193 or a `$80–$82` collision would break the frame

### Step 3.1: Lesson 68 — Kernel Architecture

**Reference**: [03 §Lesson 68](03-lesson-specs.md) · AR-16–AR-21, AR-23
**Objective**: ship the zone framework, the three-layout demo, the three solutions, and the
document that teaches the kernel architecture.

- [x] 3.1.1 Lesson 68 — Kernel Architecture: Session A freezes ST-68.1–ST-68.6 (red baseline),
  Session B implements the framework, the layouts, the solutions, and the document, Session C
  verifies to green and hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson68): Designing Your Kernel Architecture` ✅ (completed: 2026-11-07 18:54)

**Session A record** (freeze + red baseline, 2026-11-07 17:35): ST-68.1–ST-68.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 68. Design pins: the doc title is the curriculum/stub title **"Lesson 68: Designing Your Kernel Architecture — A Zone Framework"**; the new `include/kernel_framework.asm` exposes `+kf_begin`, `+kf_fill`, `+kf_pf`, `+kf_strip`, `+kf_ramp`, `+kf_custom`, `+kf_end`, and `+kf_dispatch`; each zone costs `.dataLines + 1` boundary lines and `+kf_end` must `!error` unless the sum is 192; the framework composes `include/kernel_patterns.asm` and owns only `$80-$82`. The main `68-kernel-architecture.asm` (4,096) has three layouts: STATUS (fill 15 + PF 24 rows + strip 48 + ramp 77 = 16+49+49+78 = 192), STARFIELD (ramp 31 + strip 95 + PF 16 rows + fill 30 = 32+96+33+31 = 192), and SPLIT (PF 24 + strip 31 + PF 24 + ramp 61 = 49+32+49+62 = 192); the last zone is black. Frame 262: `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/19 (the 13-cycle dispatch tax). RAM: framework `$80-$82`; `$83` `Layout`, `$84` `Frame`, `$85` `PrevSelect`, `$86` `NewSelect`, `$87` `Startup`, `$88` `SpriteY`, `$89-$D5` `RampDataA` (the 77-byte STATUS ramp; the score library is not sourced), `$D6` `Tmp`, `$D7` free; `$D8-$F7` free; `$F8-$FF` stack. Three 4,096-byte solutions: a ball zone, a fourth layout/selector, and a runtime-configurable zone. Captures: `layout-status.png`, `layout-starfield.png`, `layout-split.png`. Red baseline confirmed: no `lessons/part9-dsl-path/68-kernel-architecture`, no `docs/public/images/lesson68`, no Part 9 68 ROMs, no `include/kernel_framework.asm`, the document is the `🔒 Coming Soon` stub, index row 68 Coming Soon, sidebar `config.ts:157`, `verify.sh --no-docs` green at `abafdef`. No implementation logic read (AR-2).

**Session B record** (implementation, 2026-11-07 18:00): `include/kernel_framework.asm` (the zone macros, the 192-line `!error`, the branch dispatcher), `68-kernel-architecture.asm` (4,096) with STATUS/STARFIELD/SPLIT, three 4,096-byte solutions (the `+kf_custom` ball band, the GALLERY fourth layout, the scrolling star strip), the doc (1,519 lines), and three captures. The review fixes: `CTRLPF=$21` reflect and the re-captured V/symmetry, the boundary-line clears first, the `+kf_custom` exercise, the framework contract/cycle/dispatch wording, and the exercise comments.

**Session C record** (verify + evidence, 2026-11-07 18:54): `bash scripts/verify.sh` PASSED (252 sources, no drift, docs build); four ROMs 4,096 and byte-identical to fresh builds; Full Source verbatim (630 source / 1,519 doc lines); `+kf_end` positive and the 191/193 negative; frame `StartFrame` `$F099` 259/3, `VblankStart` `$F0A7` 0/5, `BodyStart` `$F140` 37/5, `KernelEnd`/`OverscanStart` `$F143` 229/19; `LayoutRead` A=0/1/2; `LayoutWrite` A=1/2/0 at 240/480/720; `FrameRead` A=2,3,4; the mirror checks 99.03%/97.77%/99.73%; the captures 1010×807, titles `Stella 7.0: "68-kernel-architecture"`, no cursor. Exercise evidence: ex1 `+kf_custom`/BallBand (4,096, 229/19), ex2 A=3 at 720 (4,096), ex3 StarShift every 2 frames (4,096). Site: index row 68 ✅; prev 67/next 69; sidebar `config.ts:157`; README row 9 unchanged. Reviews (AR-5): atari2600-reviewer — 1 critical (CTRLPF) + 3 major + 15 minor, then no critical/major; curriculum-auditor — 2 major (CTRLPF, `+kf_custom`) + 9 minor, then no critical/major. All fixed; final 0 critical, 0 major open. Lesson 68 is complete.
**Deliverables**:
- [x] `include/kernel_framework.asm` (API, budget, boundary contract, dispatcher macro).
- [x] `68-kernel-architecture.asm` (4,096) + `exercise-01/02/03-solution.asm` (4,096 each).
- [x] `docs/part9-dsl-path/68-kernel-architecture.md` (framework API, three layouts, 3 images, 1
  player, three exercises with solutions).
- [x] Index row 68 ✅; prev 67 / next 69; sidebar; README unchanged.
- [x] `verify.sh` green; both reviews 0 critical/major.

**Verify**: `bash scripts/verify.sh`

---

## Phase 4: Part 9 Completion Gate

> **Phase baseline tree**: the Lesson 68 commit (clean tree at gate start)
> **Expected modifications**: `codeops/features/curriculum/plans/part9-dsl-path/00-index.md`,
> `01-requirements.md`, `02-current-state.md`, `05-findings.md`, `99-execution-plan.md`,
> `codeops/features/curriculum/00-roadmap.md`, `codeops/00-roadmap.md`,
> `codeops/features/curriculum/requirements/RD-09-part9-dsl-path.md`
> **Reasoning**: medium — the gate is bookkeeping and a full re-check; the lesson content is frozen

### Step 4.1: Part 9 completion gate (a gate, not a fourth lesson)

- [ ] 4.1.1 Part 9 completion gate: 9 ACME sources/ROMs + 1 bB reference, 3 docs, 10 screenshots,
  `npm run roms` 252, 253 total `.bin`, index 66–68 ✅, RD-09 Done, feature roadmap 9/11, portfolio
  9 plans, all completion criteria ticked, final `verify.sh` green; commit via the `git-commit`
  skill in push mode — `docs(curriculum): complete Part 9 (lessons 66-68)`

**Completion gate record**:

---

## Dependencies

```
Plan + preflight
      ↓
Lesson 66 (bB evidence)
      ↓
Lesson 67 (generator + DSL)
      ↓
Lesson 68 (framework + layouts)
      ↓
Part 9 completion gate
```

---

## Completion Criteria

- [ ] All three phases marked `[x]` with Session A/C records.
- [ ] 9 ACME sources/ROMs (1 demo + 4 + 4) + 1 bB reference ROM, all 4,096 bytes.
- [ ] 3 documents, 10 screenshots (9 lesson captures + 1 bB reference).
- [ ] Lesson 66: three lenses, bB listing, reference player, three analysis exercises.
- [ ] Lesson 67: generator `--check` clean, two levels, three solutions.
- [ ] Lesson 68: `+kf_end` 192 for every layout, three layouts, three solutions.
- [ ] Part 9 index rows 66–68 all ✅ Complete.
- [ ] `bash scripts/verify.sh` green at the final commit (252 ACME sources).
- [ ] Both specialists report no critical/major open for every lesson.
- [ ] No dead code, no unused symbols/tables; security N/A (static content, no input).
- [ ] The post-completion re-analysis is recorded.
- [ ] RD-09 Done; feature roadmap 9/11 RDs; portfolio 9 plans done.

## Post-Completion Analysis

_To be filled at the gate._
