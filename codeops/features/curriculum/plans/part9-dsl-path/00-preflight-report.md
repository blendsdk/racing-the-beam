# Preflight Report: Part 9 — The DSL Path (Lessons 66–68)

> **Document**: 00-preflight-report.md
> **Parent**: [Index](00-index.md)
> **Run**: 2026-11-07, before the first lesson phase
> **Method**: plan audit against RD-09, the shipped course, the expert references, Stella 7.0,
> ACME 0.97, Python 3, bB 1.9 (wasm) + wasmtime 50.0.1, and four executable prototypes (the bB
> compilation, the kernel-framework zone budget, the framework dispatch, and the generator
> include shape).
> **Verdict**: ✅ **GATE PASSED** — 2 critical and 5 major findings resolved; 6 minor findings
> folded into the lesson specs; 3 observations recorded. No unresolved blocker remains.

## Findings

### Critical

| ID | Finding | Risk | Resolution |
| --- | --- | --- | --- |
| PF-01 | The Lesson 68 stub promises `include/kernel_framework.asm`, which does not exist. The course has only `include/kernel_patterns.asm` (four band routines) and no zone table, dispatcher, or line-budget check. | A lesson that promises a framework without one would either ship no artifact or invent an unverified library. | **Resolved:** create `include/kernel_framework.asm` as a macro-composed zone framework over `kernel_patterns.asm`. The prototype assembled a 4,096-byte three-layout ROM, the build-time budget check caught a 191-line layout, and the final layouts produce a 262-line frame (`BodyStart` 37/5, `OverscanStart` 229/19). AR-16–AR-19; spec §Lesson 68. |
| PF-02 | The Lesson 66 stub requires analyzing batari BASIC output, but bB is not installed and the repository has no bB build path. A theory lesson without real compiler output would be prose about an unverified tool. | The lesson's central claims (`if` lowering, score BCD, kernel shape) would be unverifiable. | **Resolved:** bB 1.9 (wasm) + wasmtime 50.0.1 compile a course-authored `.bas` on Linux to a 4,096-byte ROM and a generated listing (the preflight sample: 41,044 bytes). The listing is CC0; the bB README exempts games created with bB from the GPL. The `.bas`, the listing, and the reference ROM are committed; the compiler is not vendored. AR-9–AR-12; spec §Lesson 66. |

### Major

| ID | Finding | Risk | Resolution |
| --- | --- | --- | --- |
| PF-03 | Every zone handler is called with `JSR` and returns with `RTS` at about cycle 10 of its last line. The next zone's setup therefore runs on the following line, which is an extra visible line. Seven zones with 192 data lines measured 199 visible lines (Body 37 → Overscan 236). | A framework that ignores the boundary line overruns the 192-line picture and rolls the frame. | **Resolved:** the budget is **data lines + one boundary line per zone = 192**. `+kf_end` emits an `!error` unless the sum is exactly 192. The preflight prototype first assembled a 191-line layout and the check rejected it; the corrected layout measured Body 37 → Overscan 229. AR-17; spec §Lesson 68. |
| PF-04 | The first framework dispatch wrote the jump target into `KernelJmp+1/+2` in **ROM**; the writes were ignored and `JMP (KernelJmp)` read `$FFFF`, so the frame collapsed to 71 lines. | A runtime layout selector that writes ROM never selects the layout; the demo would crash or roll. | **Resolved:** the lesson uses a branch dispatcher (`CMP #1 / BEQ` … `JMP Layout0`) instead of a self-modified vector. The prototype's three layouts then measured a stable 262-line frame. AR-18; spec §Lesson 68. |
| PF-05 | The framework prototype placed `Layout`/`Frame` at `$80/$81`, which are `KernelPtr`/`KernelPtr+1` in `kernel_patterns.asm`; the layout smashed the kernel pointer and the frame measured 71 lines. | A lesson RAM map that overlaps the library silently corrupts every kernel table read. | **Resolved:** the framework owns `$80–$82`; Lesson 68's variables start at `$83` (`Layout`), `$84` (`Frame`). The spec states the ownership and the prototype re-measured a stable frame. AR-20; spec §Lesson 68. |
| PF-06 | The framework's dispatch/return chain reaches the overscan at 229/**19**, not the course's usual 229/6. The VBLANK store completes at about cycle 24, after the first visible clocks of the overscan line. | A visible sliver of the last kernel colour at the top of the overscan. | **Resolved:** the last zone in every layout is black, so the sliver is black; the doc states the measured 229/19 and the 13-cycle dispatch tax. The scanline is still 229 and the frame is 262. AR-18/AR-21; spec §Lesson 68. |
| PF-07 | The bB `if` lowering is not a direct compare: `if player0y > 120 then player0y = 60` compiles to `LDA #120 / CMP player0y / BCS skip / LDA #60 / STA player0y`. The branch is taken when the source condition is **false**. `score = score + 1` compiles to `SED / CLC / ADC` chains on `score+2`, `score+1`, `score`, then `CLD`. | The lesson would teach the comparison or the score as a naive direct translation; both are wrong. | **Resolved:** the spec pins the real generated excerpt and the doc explains the reversed branch and the BCD score. The committed listing is the evidence. AR-6/AR-9; spec §Lesson 66. |

### Minor

| ID | Finding | Resolution |
| --- | --- | --- |
| PF-08 | The bB reference ROM is not rebuilt by `npm run roms`; it would sit in the ROM tree without an ACME source. | The doc labels it a reference build, gives the bB 1.9 command, and states it is not drift-checked. The completion count separates 9 ACME ROMs from the 1 reference. AR-27. |
| PF-09 | The bB generated listing uses DASM syntax and cannot be assembled by ACME; committing it as `.asm` would break `verify.sh`. | Commit it as `lesson66.generated.txt`; the doc quotes it; the build path stays ACME. AR-9. |
| PF-10 | The Lesson 67 generator is Python; CI has no Python step and the course's verify gate is ACME + VitePress. | Commit the generated include; provide `--check` for the author; state that CI does not run Python. AR-13. |
| PF-11 | The Lesson 67 spec language needs a bounded grammar, not free prose, or the generator cannot validate it. | The spec pins the line-oriented fields and ranges; the generator exits nonzero on a bad spec. AR-14. |
| PF-12 | Lesson 66's three lenses and Lesson 68's three layouts are moving states; a fixed sleep may capture the wrong lens/layout. | Capture from the committed ROM after a SELECT or a measured frame; the state log records `Lens`/`Layout`; the doc discloses the method. AR-7/AR-22. |
| PF-13 | The bB variable map is version-specific; a future bB could move it. | Pin bB 1.9; the doc quotes the committed `2600basic_variable_redefs.h`/symbol file, not a generic claim. AR-9. |
| PF-14 | The Part 9 index is intro-only (no lesson table), unlike the Part 7/8 indexes. | Lesson 66 rebuilds the Part 9 index to the Part 7/8 format (big-idea intro + lesson table + What You'll Learn) and flips row 66. |

### Observations

| ID | Observation | Handling |
| --- | --- | --- |
| OB-1 | The Part 9 index and sidebar are already present; no navigation rewrite is expected. | Verify only; flip the three lesson rows. |
| OB-2 | `include/score.asm` provides the six-column text window used by Lessons 63/64/65. | Lesson 66/67/68 may reuse it for labels; the spec records the choice. |
| OB-3 | Javatari runs plain 4K; the bB reference ROM is also 4K. | No player change; the bundle stays unmodified. |

## Prototype Evidence

| Prototype | Command / artifact | Result |
| --- | --- | --- |
| bB compile | `bB/2600basic.sh lesson66.bas` with bB 1.9 and wasmtime 50.0.1 | `basic version: batari Basic v1.9 (c)2025`; `4,096` bytes; `lesson66.bas.asm` 41,044 bytes; `2,697 bytes of ROM space left` |
| bB lowering | `lesson66.bas.asm` around `;;line 42–45` | `player0y = player0y + 1` → `INC player0y`; the `if` → `LDA #120 / CMP player0y / BCS skip / LDA #60 / STA player0y`; `score = score + 1` → `SED / CLC / LDA score+2 / ADC #$01 / … / CLD`; `drawscreen` → `JSR`; `goto` → `JMP` |
| bB reference screen | Stella capture of `lesson66.bas.bin` | 1,010×807 window; the bB-compiled picture runs; the player and score are visible |
| Framework budget | `acme test2.asm` | first run: `!error: zone line budget is 191 (0xbf), expected 192`; after the fix: `size=4096` |
| Framework frame | Stella breakpoints `StartFrame` `$F068`, `Body` `$F08A`, `Overscan` `$F08D` | `StartFrame` 259/18; `Body` 37/5; `Overscan` 229/19; the frame is 262 |
| Framework layouts | three layouts selected on a 64-frame timer | all three assemble from the same macros; the budget check passes for each; the picture is stable |
| Generator shape | a Python table emitter + ACME `!source` include | the include is a normal ACME file; the ROM assembles; the generator's `--check` compares the regenerated bytes |

## Gate Conditions Carried into Execution

1. Lesson 66's demo and the bB reference are separate artifacts; the doc never calls the demo
   generated code.
2. The bB claims quote the committed bB 1.9 listing, not a generic description.
3. Lesson 67's generated include is committed; the generator's `--check` must pass before the
   lesson commit.
4. Lesson 68's every layout passes the `+kf_end` 192-line check before capture.
5. The framework owns `$80–$82`; lesson variables start at `$83`.
6. The last zone in every Lesson 68 layout is black; the doc states the 229/19 overscan entry.
7. Every screenshot comes from the committed lesson ROM and is pixel-checked.
8. `bash scripts/verify.sh` is green before every lesson commit.
