# Ambiguity Register: Part 9 — The DSL Path (Lessons 66–68)

> **Status**: ✅ GATE PASSED — all plan-local items resolved
> **Created**: 2026-11-07
> **Authority**: the user directive to plan, preflight, and execute RD-09; RD-09's acceptance
> criteria; and the Part 1–8 process precedent. The global curriculum register
> (`../../requirements/00-ambiguity-register.md`) delegates implementation mechanisms inside the
> frozen curriculum.
> **Scope**: RD-09 only; lessons 66–68.

| # | Category | Ambiguity / Gap | Options Presented | Decision | Status |
|---|----------|-----------------|-------------------|----------|--------|
| 1 | Scope | Which lessons belong to this plan? | All remaining lessons / Part 9 only / one lesson | **Part 9 only: lessons 66–68, strictly in curriculum order.** The 78-lesson structure and the three lesson titles are frozen. | ✅ Resolved |
| 2 | Process | How is the work phased? | One phase per lesson + gate / batched phases | **3 phases, one per lesson, plus a Part 9 completion gate.** Each phase uses Sessions A/B/C and one atomic commit. | ✅ Resolved |
| 3 | Artifacts | Which lessons are buildable? | Everything buildable / theory for 66, labs for 67–68 | **Lesson 66 is the analysis/theory lesson: `demo-66.asm`, three analysis exercises answered in the doc, no solution files. Lessons 67 and 68 are buildable labs: a main source + three `exercise-NN-solution.asm` each.** RD-09 AC 1 allows `demo-NN.asm` for theory lessons. | ✅ Resolved |
| 4 | Verify | What is the gate? | `verify.sh` / lighter check | **`bash scripts/verify.sh` before every lesson commit and at Part 9 completion.** | ✅ Resolved |
| 5 | Reviews | Who gates a lesson? | One reviewer / both specialists | **Both `atari2600-reviewer` and `curriculum-auditor` must report no critical/major open.** | ✅ Resolved |
| 6 | Claims | What accuracy standard applies? | Observed/documented/derived / free prose | **Observed/documented/derived; `include/vcs.asm` is ground truth; bB claims cite the bB 1.9 compiler output committed in the lesson; hardware claims cite Stella or the expert references.** | ✅ Resolved |
| 7 | Screenshots | How are captures produced? | Existing script / browser capture | **`scripts/capture-screenshot.sh` from the committed lesson ROM, pointer parked, no cursor, title bar visible. Lesson 66: 3 demo captures + 1 bB-reference capture; Lesson 67: 3 (two levels + a post-hit band); Lesson 68: 3.** | ✅ Resolved |
| 8 | ROM sizes | Do all lessons stay at 4,096 bytes? | 4K only / mapper-correct | **All Part 9 ROMs are 4,096 bytes. No mapper, no bankswitching.** The bB reference ROM is also 4,096. | ✅ Resolved |
| 9 | bB toolchain | How is batari BASIC obtained and used? | Vendor the compiler / document it / skip it | **bB 1.9 (wasm) + wasmtime 50.0.1, used in preflight only.** The repository does not vendor the GPL compiler. The course-authored `.bas`, the generated listing, and the reference ROM are committed; the build path remains ACME. | ✅ Resolved |
| 10 | bB license | Can bB output be committed under this MIT course? | Assume / verify | **Verified: the bB README says the GPL does not apply to games created with bB; the generated assembly is CC0.** The `.bas` is course-authored, so the reference ROM and listing are first-party content. | ✅ Resolved |
| 11 | Lesson 66 artifact | Is the demo the bB output or a hand-written visualization? | Ship only bB output / hand-write a demo / both | **Both, clearly separated:** the real bB 1.9 output is the analysis subject (`.bas`, generated listing, reference ROM); `demo-66.asm` is a hand-written ACME ROM that reproduces the bB architecture and adds three teaching lenses. The doc never calls the demo generated code. | ✅ Resolved |
| 12 | Lesson 66 lenses | What does the demo show? | One scene / two scenes / three lenses | **Three SELECT lenses: RUN (the bB-style scene), ZONES (the 3/37/192/30 pipeline tinted), VARS (the bB RAM map as a 16×8 grid).** The state log proves the lens switch. | ✅ Resolved |
| 13 | Lesson 67 generator | What kind of code generator? | Data tables / a full compiler / no generator | **A first-party Python 3 generator (`lesson67-generate.py`) that validates a small wave-spec language and emits an ACME include.** The engine in the ROM interprets the generated tables; the generator has a `--check` mode that detects drift. CI does not run Python. | ✅ Resolved |
| 14 | Lesson 67 DSL | What is the wave-spec grammar? | Free prose / fixed fields | **Line-oriented text: `level`, `name`, `bg`, `pf`, `backdrop`, and `wave <index> <frame> <x> <y> <speed> <type>`.** Type 0 = straight, type 1 = drift; exercise 1 adds type 2 = zigzag. The generator validates ranges and emits a report. | ✅ Resolved |
| 15 | Lesson 67 game | What does the ROM do? | Static gallery / playable shooter | **A playable "wave lab": the player moves left/right, fires, and the generated waves spawn; a hit scores. Two generated levels (A/B) selected with SELECT; the level loops.** | ✅ Resolved |
| 16 | Lesson 68 framework | The stub promises `include/kernel_framework.asm`, which does not exist. Build it? | Change the stub / build a lesson-local library / build the shared include | **Build `include/kernel_framework.asm` as a macro-composed zone framework that composes the existing `include/kernel_patterns.asm`.** It is used only by Lesson 68 and its solutions; no earlier lesson changes. | ✅ Resolved |
| 17 | Zone budget | How is the 192-line kernel guaranteed? | Runtime check / build-time check / hand count | **Build-time:** each zone costs its data lines + one boundary line; `+kf_end` emits an `!error` unless the sum is exactly 192. The preflight prototype caught a 191-line layout. | ✅ Resolved |
| 18 | Zone boundary | What happens at a zone boundary? | Ignore / one boundary line / a runtime seam | **One boundary line per zone is part of the budget.** The macro sets up during the previous handler's return line and starts the handler after `WSYNC`. The measured dispatch tax is 13 cycles at the overscan entry (229/19); the last zone is black so the sliver is invisible. | ✅ Resolved |
| 19 | Lesson 68 layouts | How many layouts? | One / two / three | **Three layouts selected with SELECT: STATUS (text + playfield + sprites + ramp), STARFIELD (ramp + strip + playfield + fill), SPLIT (PF + strip + PF + ramp).** Each composes the same macros and passes the 192-line check. | ✅ Resolved |
| 20 | RAM map | Which bytes are safe? | Shared map / per lesson | **Lesson 66/67: `$80–$9F` variables, `$A0–$D7` the score library, `$D8–$F7` free, `$F8–$FF` stack. Lesson 68: the framework owns `$80–$82` (`KernelPtr`/`KernelRows` from `kernel_patterns.asm`); the lesson's `Layout`/`Frame` start at `$83`.** | ✅ Resolved |
| 21 | Frame | What frame do the lessons use? | 262 only / adaptive | **NTSC 262 = 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229.** Lesson 68's dispatch tax moves the overscan entry cycle but not the scanline. | ✅ Resolved |
| 22 | Evidence | What proves a claim? | Screenshot / state log + ledger | **State-log checkpoints + static ledgers + PIL pixel checks; the screenshot proves only the visual state.** Lesson 66 adds the committed bB listing as the codegen evidence. | ✅ Resolved |
| 23 | Exercises | How many, and what ships? | Three everywhere / lesson-specific | **Lesson 66: three analysis exercises answered in the doc. Lessons 67–68: three exercises, each with a `exercise-NN-solution.asm` that assembles to 4,096 and runs.** | ✅ Resolved |
| 24 | Index/README | How is the site updated? | Rebuild per part / per lesson | **Part 9 index rows 66–68 flip per lesson; the sidebar entries already exist; prev/next frontmatter; README row 9 stays `The DSL Path | 66–68`.** | ✅ Resolved |
| 25 | Commits | How is work committed? | One per part / one per lesson | **The plan + preflight is its own commit; each lesson is one atomic `feat(lessonNN): <title>` commit pushed to `master`; the completion gate is a separate docs commit.** | ✅ Resolved |
| 26 | Completion | What is the Part 9 target? | Per lesson / part count | **9 ACME sources/ROMs (1 demo + 4 + 4) + 1 bB reference ROM; 3 documents; 10 screenshots (9 lesson captures + 1 bB reference); 252 `npm run roms` ROMs; 253 total `.bin` files; RD-09 Done; feature roadmap 9/11 RDs; portfolio 9 plans done.** | ✅ Resolved |
| 27 | bB reference ROM | Is it rebuilt by `npm run roms`? | Add a bB build step / commit only | **Commit only.** bB is not a repository dependency; `npm run roms` builds the 9 ACME sources. The doc gives the bB 1.9 command and states the reference ROM is not drift-checked. | ✅ Resolved |
| 28 | Javatari | Does the player support the ROMs? | Assume / verify | **All Part 9 ROMs are plain 4K; Javatari's 4K path runs them. The bundle stays unmodified.** | ✅ Resolved |

## Resolution Notes

**AR-1 / AR-2.** RD-09 names lessons 66–68. The plan keeps the frozen curriculum and runs three
phases plus a gate. The Part 8 process is reused unchanged: Session A freezes the lesson's ST
cases and records a red baseline; Session B implements; Session C verifies and hardens.

**AR-3.** RD-09 AC 1 explicitly allows `demo-NN.asm` for theory lessons. Lesson 66 is an analysis
lesson whose artifact is a demo that visualizes the bB architecture plus the real bB compilation
evidence; its exercises are analysis tasks answered in the document, so no
`exercise-NN-solution.asm` is shipped. Lessons 67–68 ship three solutions each.

**AR-9 / AR-10.** The preflight compiled a course-authored bB program with bB 1.9 (wasm) and
wasmtime 50.0.1. The generated listing is CC0; the bB README exempts games created with bB from
the GPL. The repository commits the `.bas`, the generated listing, and the 4,096-byte reference
ROM, but not the compiler. `npm run roms` never invokes bB.

**AR-16 / AR-17 / AR-18.** The preflight prototyped the framework: the macros assemble, the
build-time budget check caught a 191-line layout, the final layouts produce a 262-line frame
(`BodyStart` 37/5, `OverscanStart` 229/19), and the dispatch/return tax is 13 cycles at the
overscan entry. The prototype also caught a RAM collision (`Layout`/`Frame` at `$80/$81` clobbered
`KernelPtr`/`KernelRows`); the lesson map starts the lesson variables at `$83`.

**AR-26.** The completion count is derived from the Part 8 count (243 ROMs) plus the 9 ACME
sources/ROMs (`252`), plus the bB reference (`253` total `.bin`). The screenshot count is 3 + 2 +
3 lesson captures plus the bB reference.

**AR-27.** The bB reference ROM is committed under
`docs/public/roms/part9-dsl-path/66-analyzing-batari-basic/lesson66-bb.bin` and embedded with a
second `<RomPlayer>`. The doc labels it as a reference build and gives the exact bB command. It is
not part of `verify.sh`'s ACME drift check.
