# Ambiguity Register: Part 8 — Advanced Topics (Lessons 56–65)

> **Status**: ✅ GATE PASSED — all plan-local items resolved
> **Created**: 2026-11-06
> **Authority**: user directive to plan, preflight, and execute RD-08; the global curriculum
> register (`../../requirements/00-ambiguity-register.md`) delegates implementation mechanisms
> inside the frozen curriculum (AR #2–#9 there).
> **Scope**: RD-08 only; lessons 56–65.

| # | Category | Ambiguity / Gap | Options Presented | Decision | Status |
|---|----------|-----------------|-------------------|----------|--------|
| 1 | Scope | Which lessons belong to this plan? | All 78 / Part 8 only / one lesson | **Part 8 only, lessons 56–65, strictly in curriculum order.** The 10-lesson part is larger than Part 7's 8. | ✅ Resolved |
| 2 | Process | How is the work phased? | One phase per lesson + gate / batched phases | **10 phases, one per lesson, plus a completion gate.** Each phase uses Sessions A/B/C and one atomic commit. | ✅ Resolved |
| 3 | Artifacts | Do theory lessons need exercise solutions? | Three solutions everywhere / demo only for theory | **Buildable lessons 56–61 and 65: main source + three `exercise-NN-solution.asm`. Theory lessons 62–64: one `demo-NN.asm`, two screenshots, conceptual exercises answered in the doc.** RD-08 AC 1 allows `demo-NN.asm` for theory lessons. | ✅ Resolved |
| 4 | Verify | What is the gate? | `verify.sh` / lighter check | **`bash scripts/verify.sh` before every commit and at Part 8 completion.** | ✅ Resolved |
| 5 | Reviews | Who gates a lesson? | One reviewer / both specialists | **Both `atari2600-reviewer` and `curriculum-auditor` must report no critical/major open.** | ✅ Resolved |
| 6 | Claims | What accuracy standard applies? | Observed/documented/derived / free prose | **Observed/documented/derived; `include/vcs.asm` is ground truth; hardware claims cite Stella, the Atari manuals, or the expert references.** | ✅ Resolved |
| 7 | Screenshots | How are captures produced? | Existing script / browser capture | **`scripts/capture-screenshot.sh` from the committed ROM, pointer parked, no cursor, title bar visible.** Two per lesson. | ✅ Resolved |
| 8 | ROM sizes | Do all lessons stay at 4,096 bytes? | 4K only / mapper-correct sizes | **Mapper-correct sizes: 4K, 8K, 10K, 16K.** `npm run roms` and `verify.sh` already handle any size; docs and commits state the actual size. | ✅ Resolved |
| 9 | Mappers | Which mapper does each lesson use? | One scheme / lesson-specific | **56 = F8 (8K); 57 = F8SC (8K + 128B RAM); 60 = DPC (10K); all others = 4K; 56 exercise 2 = F6 (16K).** | ✅ Resolved |
| 10 | Start bank | Which bank is selected at power-on? | Bank 0 everywhere / mapper truth | **F8 and F8SC start in bank 1; DPC starts in bank 1; F6 starts in bank 0.** Verified in Stella 7: F8 `F8*`, F8SC `F8SC*`, DPC `DPC*`, F6 starts in bank 0. The reset vector in the start bank is the one used. | ✅ Resolved |
| 11 | F8SC layout | How is Superchip RAM addressed and detected? | 4KSC / F8SC / E7 | **F8SC: write `$1000–$107F`, read `$1080–$10FF`; the first 256 bytes of each 4K bank are the RAM window, so code starts at `$F100`; each bank's first 128 bytes are duplicated at +128 (the Stella auto-detect signature).** Verified: `F8SC* (8K)`. | ✅ Resolved |
| 12 | DPC layout | How is a DPC image laid out? | DPC+ / real DPC / theory only | **Real DPC, 10,240 bytes = 8K program (two 4K banks) + 2K display image at file offset 8K. Start bank 1; code entry `$F080` because `$F000–$F07F` is the DPC register window.** Verified: `DPC* (10K)`. | ✅ Resolved |
| 13 | DPC+ | Is DPC+ built? | Build it / document it | **Documented, not built.** DPC+ needs the Harmony/Melody ARM coprocessor and a 29K/32K image; a plain cartridge cannot run it. Lesson 60 builds a real DPC demo and explains DPC+ with sources. | ✅ Resolved |
| 14 | Illegal opcodes | How are they assembled? | ACME mnemonics / `!byte` macros | **ACME 0.97 has no `6502i`; `!cpu 6502` rejects the undocumented mnemonics while `!cpu 6510` accepts them (LAX/SAX/DCP/ISC). The lesson keeps `!cpu 6502` and uses named `!byte` macros so every byte stays visible; document the bytes, flags, and cycles.** The stable NMOS set is safe on the 6507; the doc warns about the 65C02 and unstable opcodes. | ✅ Resolved |
| 15 | Self-modifying | Where does patched code run? | ROM / RIOT RAM | **RIOT RAM `$80–$88` for the routine, `$89–$9F` for variables, stack `$F8–$FF`.** ROM is read-only; a self-modifying routine must be copied to RAM. Verified with a gradient running from `$80`. | ✅ Resolved |
| 16 | Compression | Which scheme? | RLE / LZ / dictionary | **A documented RLE token stream decoded row-by-row into a 3-byte zero-page buffer.** No general-purpose library. A checksum proves the decode. | ✅ Resolved |
| 17 | Reverse engineering | Which ROM is reverse-engineered? | A copyrighted classic / a course-written classic-style ROM | **A course-written 4K "classic-style" game (`demo-62.asm`), so the lesson can annotate every byte without copyright risk.** The method transfers to any ROM. | ✅ Resolved |
| 18 | Homebrew | What is the artifact? | Prose only / an attract-mode demo | **`demo-63.asm`: a polished attract mode (logo, starfield, scrolling message, tune, credits).** The prose covers Harmony/UnoCart, AtariAge, contests, and publishing. | ✅ Resolved |
| 19 | Cartridge | What is the artifact? | PCB files / a burn-in test ROM | **`demo-64.asm`: a cartridge burn-in test (color bars, ROM checksum, RAM test, controller test, frame counter).** The prose covers PCB, SST39SF010A, TL866II Plus, soldering, shell, and labels. | ✅ Resolved |
| 20 | PAL/NTSC | Is runtime auto-detection possible? | Auto-detect / selector / build variants | **Software-only auto-detection is impossible on a stock 2600: the RIOT and TIA count the same clock, and the ~1% crystal difference cannot be measured without an independent timebase.** Lesson 65 teaches a title-screen selector + adaptive 262/312-line timing, and documents the Harmony/Melody ARM exception and the Color/BW-switch practice. | ✅ Resolved |
| 21 | Frame | What frame does each lesson use? | 262 only / adaptive | **NTSC 262 lines (3 VSYNC + 37 VBLANK + 192 picture + 30 overscan); PAL 312 lines in Lesson 65 (3 + 45 + 192 + 72).** Top-down forward row loops; one HMOVE per repositioning event. | ✅ Resolved |
| 22 | RAM map | Which bytes are safe? | Shared map / per lesson | **RIOT RAM `$80–$9F` variables; `$A0–$D7` free; `$D8–$F7` free; `$F8–$FF` stack.** Self-modifying lesson uses `$80–$88` routine. Superchip RAM is separate at `$1000–$10FF`; DPC registers/display are separate. | ✅ Resolved |
| 23 | Evidence | What proves a claim? | Screenshot / state log + ledger | **State-log checkpoints + static cycle/line ledgers + pixel checks.** A screenshot proves only the visual state. | ✅ Resolved |
| 24 | Exercises | How many? | Three everywhere / lesson-specific | **Three per buildable lesson; theory lessons have three analysis/production exercises answered in the doc.** Every shipped solution assembles and runs. | ✅ Resolved |
| 25 | Index/README | How is the site updated? | Rebuild per part / per lesson | **Part index rows 56–65 flip per lesson; sidebar entries already exist; prev/next frontmatter; README row 8 stays `Advanced Topics | 56–65`.** | ✅ Resolved |
| 26 | Commits | How is work committed? | One per part / one per lesson | **One atomic `feat(lessonNN): <title>` commit per lesson, pushed to `master`; the plan+preflight is its own commit.** | ✅ Resolved |
| 27 | Completion | What is the Part 8 target? | Per lesson / part count | **31 sources/ROMs, 10 documents, 20 screenshots; RD-08 Done; feature roadmap 8/11 RDs; portfolio 8 plans done.** | ✅ Resolved |
| 28 | Machinery | Is a new shared library needed? | Bank library / self-contained | **No new shared library or tooling.** Each lesson is self-contained; reuse `include/vcs.asm`, `include/macro.asm`, and `include/score.asm` where already shipped. | ✅ Resolved |
| 29 | Javatari | Does the in-browser player support the mappers? | Assume / verify | **Javatari's mapper table includes F8/F6/F4 with +RAM and DPC.** F8SC uses the F8(+RAM) path; DPC uses the DPC path. The bundle stays unmodified (AGPL-3.0). | ✅ Resolved |
| 30 | DPC registers | Which register addresses are correct? | Guess / measure | **Measured table: DF0 top `$1040`, bottom `$1048`, counter low `$1050`, high `$1058`; DF1 top `$1041`, bottom `$1049`, counter low `$1051`, high `$1059`; DF2 top `$1042`, bottom `$104A`, counter low `$1052`, high `$105A`; music DF5 top `$1045`, bottom `$104D`, counter low `$1055`, high `$105D`; read `$1008/$1009/$100A`; RNG read `$1000`, reset `$1070`.** The prototype caught both the bottom and counter-high offsets. | ✅ Resolved |
| 31 | Bank stubs | How is a cross-bank jump safe? | Jump directly / duplicate stubs | **Duplicate the switch-and-jump stub at the same fixed address in every bank; never execute across a boundary without the target bank selected.** | ✅ Resolved |
| 32 | Colors | Are PAL colors the same? | Assume / document | **NTSC has 128 colors, PAL 104; cross-region hues differ. Lesson 65 shows a color-bar test and states the mapping is approximate.** | ✅ Resolved |
| 33 | F6 exercise | Which F6 start bank? | Bank 0 / bank 3 | **F6 starts in bank 0 (Stella 7 measured).** The 16K exercise places its entry in bank 0 and its data in banks 1–3. | ✅ Resolved |
| 34 | DPC display | How are three planes stored? | Interleaved / three offsets | **Three 192-byte planes at display offsets 0, 683, and 1366; counters start at 2047, 1364, and 681.** Verified by the 10K prototype. | ✅ Resolved |

## Resolution Notes

**AR-1 / AR-2.** RD-08 names lessons 56–65. The plan keeps the frozen curriculum and runs 10
phases plus a gate. The Part 7 process is reused unchanged: Session A freezes the lesson's ST
cases and records a red baseline; Session B implements; Session C verifies and hardens.

**AR-3.** RD-08 AC 1 explicitly allows `demo-NN.asm` for theory lessons. Lessons 62–64 are
method/production lessons whose artifact is a demo that visualizes the concept; their exercises
are analysis or production tasks answered in the document, so no `exercise-NN-solution.asm` is
shipped. The other seven lessons ship three solutions each.

**AR-8 / AR-9 / AR-10 / AR-11 / AR-12.** The prototypes were run before the plan was frozen:
an 8K F8 ROM assembles to 8,192 bytes and Stella reports `F8*`; an 8K F8SC ROM with the
duplicated signature reports `F8SC*` and the RAM write/read returns the written value; a 10K DPC
ROM reports `DPC*` and its three display fetchers draw a playfield; F8 starts in bank 1, F6 starts
in bank 0; a 16K F6 ROM assembles and reports `F6*`; LAX/SAX/DCP/ISB execute; a routine copied to
`$80` executes and its immediate operand can be patched. These are the plan's hardware proofs.

**AR-13.** DPC+ is a Harmony/Melody feature. The lesson documents the ARM coprocessor, the
29K/32K image, the extra RAM, and the DPC+ register model, and states plainly that a plain
cartridge cannot run it. Building a DPC+ image would require an ARM toolchain and a flash cart,
which is out of scope and not verifiable in the repository's artifact set.

**AR-14.** ACME 0.97 has no `6502i` target; under `!cpu 6502` the undocumented mnemonics fail,
but ACME's `!cpu 6510` type accepts them (`LAX`/`SAX`/`DCP`/`ISC`, verified: `A7 80 87 80 C7 80
E7 80`). The lesson keeps the course-wide `!cpu 6502` shape and uses `!byte $A7, $80` with a
named macro and a comment, so every opcode byte stays visible and teachable; the emitted bytes are
identical to the `6510` form. This is a deliberate visibility choice, not a claim that ACME cannot
assemble the instructions.

**AR-18 / AR-19.** The reverse-engineering and cartridge lessons need a ROM that can be shipped
and annotated. Using a copyrighted classic would be a licensing and verification problem; a
course-written classic-style game and a burn-in test are both original and useful. The methods
carry over to real ROMs.

**AR-20.** The web research and the expert references agree: the 2600 has no independent
timebase. The RIOT timer and the TIA both count the CPU clock; the NTSC/PAL crystal difference
is about 1%, below what the 8-bit timer can resolve across a frame without an external clock.
Harmony/Melody ARM carts can measure it; a stock cart cannot. The lesson never claims otherwise.

**AR-29.** Javatari's F8 entry is `8K Atari (+RAM)` and its `CartridgeBankedByMaskedRange`
implementation enables a 128-byte RAM after the first write to the low 128 bytes, then reads it
at `+128`. That is exactly the Superchip window. The DPC format is in Javatari's format list.
The player stays unmodified.

**AR-30.** The DPC write-function decode is `(address >> 3) & 7`, so the counter-high writes for
DF1 and DF2 are `$1059` and `$105A`, not `$104B`/`$1053`. The prototype initially missed this and
the picture lost two planes; the corrected table is recorded here and in the lesson spec.
