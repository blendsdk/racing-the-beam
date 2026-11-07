# Current State: Part 9 — The DSL Path (Lessons 66–68)

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

### What Exists

Part 8 is complete at `63ef5f0` (`docs(curriculum): complete Part 8 (lessons 56-65)`):
**243** committed ROMs, 31 Part 8 sources/ROMs, 10 Part 8 documents, 21 Part 8 screenshots,
`verify.sh` green, and RD-08 Done (feature roadmap 8/11). The Part 9 structure exists as three
docs stubs and a part index; the sidebar has entries for 66–68; README row 9 says
`The DSL Path | 66–68`.

The course libraries are `include/vcs.asm` (TIA/RIOT ground truth), `include/macro.asm`
(`+clean_start`, `+vsync`, `+set_timer`, `+wait_timer`), `include/score.asm` (the six-column text
window and score glyphs), `include/sound.asm`, `include/random.asm`, and
`include/kernel_patterns.asm` (the four Part 7 band routines: `KernelFill`, `KernelPFRows`,
`KernelSpriteStrip`, `KernelColorRamp`). There is **no** `include/kernel_framework.asm`.

The lesson pipeline is proven: `lessons/<part>/<NN-slug>/<NN-slug>.asm` + solutions or
`demo-NN.asm`, `npm run roms` builds every `.asm` with ACME into
`docs/public/roms/<part>/<NN-slug>/`, `verify.sh` checks drift, `scripts/capture-screenshot.sh`
captures Stella windows, and the Part 8 three-session review process shipped ten lessons with
0 critical/major open.

bB is **not** installed. The preflight downloaded bB 1.9 (wasm) and wasmtime 50.0.1 into scratch,
compiled a course-authored `.bas` to 4,096 bytes, and captured the reference screen; neither tool
is part of the repository or CI.

### Relevant Files

| File | Purpose | Changes Needed |
| ---- | ------- | -------------- |
| `docs/part9-dsl-path/index.md` | Part 9 intro only (no lesson table) | Rebuild to the Part 7/8 format in Lesson 66; flip rows 66–68 |
| `docs/part9-dsl-path/66-analyzing-batari-basic.md` | Lesson 66 stub | Replace with the full lesson |
| `docs/part9-dsl-path/67-automatable-patterns.md` | Lesson 67 stub | Replace with the full lesson |
| `docs/part9-dsl-path/68-kernel-architecture.md` | Lesson 68 stub | Replace with the full lesson |
| `docs/.vitepress/config.ts` | Sidebar | Verify lines 153–158; no change expected |
| `README.md` | Curriculum listing | Row 9 unchanged |
| `include/kernel_patterns.asm` | Part 7 band library | Source of the framework's zone routines; no changes |
| `include/kernel_framework.asm` | New framework | Create in Lesson 68 |
| `lessons/part9-dsl-path/` | New lesson sources | Create three lessons |
| `docs/public/roms/part9-dsl-path/` | New committed ROMs | 9 ACME + 1 bB reference |
| `docs/public/images/lesson66..68/` | New captures | 9 images |
| `codeops/features/curriculum/00-roadmap.md` | Feature roadmap | RD-09 Executing → Done |
| `codeops/00-roadmap.md` | Portfolio | 9 plans done at the gate |

### Code Analysis

The Part 7 `kernel_patterns.asm` routines are the framework's building blocks. They own
`$80–$82`:
- `KernelPtr` `$80–$81`, `KernelRows` `$82`.
- `KernelFill` A = colour, X = lines; 11 cycles per line.
- `KernelPFRows` `KernelPtr` = 3 bytes/row, `KernelRows` = rows; **2 scanlines per row**.
- `KernelSpriteStrip`/`KernelColorRamp` one byte per line; `KernelRows` = lines.

The preflight prototype wrapped these in zone macros, added the boundary line to the budget, and
measured the frame. The prototype's first dispatch wrote a ROM vector and its first RAM map
collided with `$80–$81`; both were corrected. The lesson spec carries the corrected rules.

## Gaps Identified

### Gap 1: No Part 9 lesson sources or documents
**Current Behavior:** The three docs are `🔒 Coming Soon` stubs; there are no `.asm` sources, no
ROMs, and no screenshots.
**Required Behavior:** Three complete lessons with the full artifact set.
**Fix Required:** Implement Lessons 66–68 in three phases.

### Gap 2: No bB evidence
**Current Behavior:** No `.bas`, generated listing, or bB reference ROM exists.
**Required Behavior:** A course-authored bB program, its generated listing, and its 4,096-byte
reference ROM, committed with the bB 1.9 provenance.
**Fix Required:** Lesson 66.

### Gap 3: No kernel framework
**Current Behavior:** The stub promises `include/kernel_framework.asm`; only
`include/kernel_patterns.asm` exists.
**Required Behavior:** A macro-composed zone framework with a 192-line build-time check and a
runtime layout selector, used by Lesson 68 and its solutions.
**Fix Required:** Lesson 68.

### Gap 4: No generator or DSL
**Current Behavior:** No wave-spec language, generator, or generated include exists.
**Required Behavior:** A Python generator, two valid specs, a committed include, and a playable
ROM that interprets the generated tables.
**Fix Required:** Lesson 67.

## Dependencies

### Internal Dependencies
- RD-08 complete (lessons 56–65; no forward references).
- `include/vcs.asm`, `include/macro.asm`, `include/score.asm`, `include/kernel_patterns.asm`.
- The Part 7/8 frame skeleton and the Part 7 kernel vocabulary (Lessons 48–53).

### External Dependencies
- ACME 0.97, Stella 7.0, Python 3, ImageMagick/`import`, `xwininfo`.
- bB 1.9 + wasmtime 50.0.1 for the Lesson 66 reference only (not a repo/CI dependency).

## Risks and Concerns

| Risk | Likelihood | Impact | Mitigation |
| ---- | ---------- | ------ | ---------- |
| bB version drift | Low | High | Pin bB 1.9; commit the listing and reference ROM |
| Generator include drift | Medium | High | `--check` before commit; commit both specs and include |
| Framework budget error | Medium | High | `+kf_end` build-time `!error`; every layout assembled |
| RAM collision with `$80–$82` | Medium | High | Framework owns `$80–$82`; lesson variables from `$83` |
| 4K overflow | Medium | Medium | Compact tables; assemble before capture; size pin |
| Moving-state screenshot | Medium | Medium | SELECT/frame-based capture; state log proves the state |

## Final State (2026-11-07)

Part 9 is complete. The three lessons ship **9 ACME sources/ROMs** (Lesson 66: `demo-66.asm`;
Lesson 67: the main + three solutions; Lesson 68: the main + three solutions) plus **1 bB reference
ROM**, **3 documents**, and **10 Stella screenshots** (Lesson 66: 4; Lesson 67: 3; Lesson 68: 3).
`npm run roms` builds **252** ACME ROMs; the repository has **253** `.bin` files including the bB
reference. `bash scripts/verify.sh` passes with no drift and a successful VitePress build. The
Part 9 index rows 66–68 are all ✅; the sidebar, prev/next links, and README row 9 are unchanged.

The preflight's facts held: bB 1.9 + wasmtime 50.0.1 compile the course-authored `.bas` to 4,096
bytes and a CC0 listing; the framework's zone budget, build-time `!error`, branch dispatcher, and
`$80-$82` ownership are correct; the 13-cycle dispatch tax lands the overscan at 229/19 on a
262-line frame. The per-lesson review gate caught the remaining defects before each commit (the
Lesson 66 band/starfield/artifact fixes, the Lesson 67 name/stack and generator fixes, the Lesson
68 `CTRLPF`/boundary/`+kf_custom` fixes); the details are in `05-findings.md`. RD-09 is Done, the
feature roadmap is 9/11, and the portfolio records 9 plans done.
