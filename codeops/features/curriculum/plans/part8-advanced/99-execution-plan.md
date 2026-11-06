# Execution Plan: Part 8 — Advanced Topics (Lessons 56–65)

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: 2026-11-06 17:56
> **Progress**: 4/10 tasks (40%)
> **CodeOps Artifact Schema**: 1

## Overview

Ten phases, one per lesson, strictly sequential — 56 introduces banking, 57 adds the Superchip
RAM on the same F8 base, 58/59 are CPU-level labs independent of the mapper, 60 uses the F8-style
layout with the DPC display processor, 61 is a 4K data lesson, 62/63/64 are method/production
lessons whose artifact is a demo, and 65 closes the part with the PAL/NTSC frame selector. Every
phase is one task run through the mandatory three-session ordering: Session A freezes that
lesson's specification cases, Session B implements the full artifact set, and Session C verifies
against the frozen cases and hardens under independent review (AR-2, AR-5).
`bash scripts/verify.sh` is the gate for every phase (AR-4). Mapper, RAM-window, opcode,
RAM-routine, DPC-fetcher, decompressor, and frame claims carry the state-log + static-ledger
evidence of AR-6/AR-23; every screenshot is pixel-checked against the lesson geometry (AR-7,
AR-23).

**🚨 Update this document after EACH completed task!**

**Session record slots:** each task gets a `**Session A record**` paragraph after its task line
(freeze + red baseline + design pins) and a **Session C record** paragraph after the Session
sub-steps. The per-lesson findings are appended to [05-findings.md](05-findings.md); the plan-level
preflight findings live in [00-preflight-report.md](00-preflight-report.md). The plan is not
executable until the preflight report exists and the roadmap row reads `Plan Preflighted`. The
push mode is authorized by the user's directive to execute RD-08 and the Part 1–7 practice (AR-26).

---

## Implementation Phases

| Phase | Title | Tasks |
| ----- | ----- | ----- |
| 1 | Lesson 56 — Bankswitching | 1 |
| 2 | Lesson 57 — Superchip | 1 |
| 3 | Lesson 58 — Illegal Opcodes | 1 |
| 4 | Lesson 59 — Self-Modifying Code | 1 |
| 5 | Lesson 60 — DPC and DPC+ | 1 |
| 6 | Lesson 61 — Compression & Data Encoding | 1 |
| 7 | Lesson 62 — Reverse Engineering a Classic Game | 1 |
| 8 | Lesson 63 — Modern Homebrew | 1 |
| 9 | Lesson 64 — Building Your Own Cartridge | 1 |
| 10 | Lesson 65 — PAL/NTSC Universal ROM | 1 |

**Total: 10 tasks across 10 phases; plus the Part 8 completion gate.**

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

## Phase 1: Lesson 56 — Bankswitching

> **Phase baseline tree**: the plan+preflight commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/56-bankswitching/` (4 sources) ·
> `docs/part8-advanced/56-bankswitching.md` · `docs/part8-advanced/index.md` (rebuild + row 56) ·
> `docs/public/roms/part8-advanced/56-bankswitching/` ·
> `docs/public/images/lesson56/` (2 captures) · `README.md` (verify only) ·
> `99-execution-plan.md` + `05-findings.md` + roadmaps
> **Reasoning**: high — the first Part 8 lesson establishes the bank layout, the start bank, and
> the duplicate trampoline that 57 and 60 reuse

### Step 1.1: Lesson 56 — Bankswitching

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 56 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 56 · AR-1–AR-6, AR-8–AR-10, AR-23,
AR-25, AR-31, AR-33
**Objective**: Deliver Lesson 56 end to end.

- [x] 1.1.1 Lesson 56 — Bankswitching: Session A freezes ST-56.1–ST-56.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson56): Bankswitching` ✅ (completed: 2026-11-06 13:02)

**Session A record** (freeze + red baseline, 2026-11-06 11:38): ST-56.1–ST-56.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 56. Design pins: 8,192-byte F8; bank 0 at real `$E000` with `!pseudopc $F000`, bank 1 at real `$F000`; start bank **1** (the reset vector at bank 1's `$FFFC` is used); reset at `$F000` jumps to the bank's main at `$F080`; fixed trampolines `$F060` (`LDA $1FF9; JMP $F080`) and `$F070` (`LDA $1FF8; JMP $F080`) are byte-identical in both banks; each bank draws a 192-line scene from its own 192-byte `PF2` table with a 1-line kernel, a P0 player, and one HMOVE; `Bank` (`$80`), `BankTimer` (`$81`), `FrameCount` (`$82`), `SwitchFlag` (`$83`), `PrevFire` (`$84`), `NewFire` (`$85`), `Startup` (`$86`); the auto-demo switches every 120 frames and fire switches immediately; the two-cell indicator shows the active bank. Exercises: swap the scenes; 16K F6 with four banks and `LDA $1FF6,X`; a data bank whose table/kernel live in bank 0. Evidence pins (AR-6): `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6, `BankEntry` A=1/0, `BankWrite`, `SwitchRead`. Red baseline confirmed: no `lessons/part8-advanced/56-bankswitching`, no `docs/public/images/lesson56`, no Part 8 ROMs, the document is the `🔒 Coming Soon` stub, the Part 8 index is the minimal stub (no rows yet), sidebar `config.ts:139`, `verify.sh --no-docs` green at `18cf887`. No implementation logic read (AR-2).

**Session B record** (implementation, 2026-11-06 12:08): Four sources (main 8,192; ex1 8,192; ex2 16,384 F6; ex3 8,192), the 1,193-line document, two captures, and four committed ROMs. The F8 layout is bank 0 at real `$E000`/pseudopc `$F000` and bank 1 at real `$F000`; bank 1 is the start bank; reset at `$F000` -> main at `$F080`; the `$F060`/`$F070` trampolines are byte-identical and target `$F080`; the vectors are `CaveReset`/`ForestReset`. The forest and cave are 192-line `PF2` scenes with a P0 marker and one HMOVE; the two-cell indicator follows `Bank`. The switch block runs in the blanked overscan; `StartFrame` is 259/39 outbound and 259/40 on the return; the frame stays 262 lines. Exercises: scene swap, 16K F6 four banks with `LDX NextBank; LDA $1FF6,X`, and the data bank drawn in place. Captures were selected from a 14-shot burst by background colour; the fire edge is code-reviewed because a held fire at power-on is ignored by the startup guard.

**Session C record** (verify + evidence, 2026-11-06 13:02): `bash scripts/verify.sh` PASSED (216 ROMs, no drift, docs build); main 8,192, ex1 8,192, ex2 16,384, ex3 8,192; main `F8* (8K)`, ex2 `F6* (16K)`. Frame: `StartFrame` `$F084` 259/3 steady, 259/39 to bank 0, 259/40 back; `VblankStart` `$F092` 0/5; `BodyStart` `$F0F6` 37/5; `OverscanStart` `$F117` 229/6; `BankEntry` `$F083` A=1 at power-on, 0 at frame 120, 1 at 240; `BankWrite` `$F13D` A=0 then 1. The `$F060`/`$F070` trampolines (`AD F9 1F 4C 80 F0` / `AD F8 1F 4C 80 F0`) are byte-identical in the two 4K halves; the vectors are `$F000` in both. Exercise logs: ex1 `BankEntry` A=1 at power-on; ex2 `BankEntry0` A=0 at power-on and A=1/2/3 at 120/240/360, `StartFrame0` 259/3; ex3 `DataMain` 0/39 in bank 0, `DataRow` 37/07, 38/07. Captures: forest bg `$84`, PF `$C8`, marker `$0E`, indicator 313–360/649–696; cave bg `$28`, PF `$44`, marker `$1A`, indicator 409–456/553–600; titles `Stella 7.0: "56-bankswitching"`, no cursor. Site: Part 8 index rebuilt, row 56 ✅, rows 57–65 Coming Soon; prev 55/next 57; sidebar `config.ts:139`; README row 8 unchanged. Reviews (AR-5): atari2600-reviewer — 2 major (the switch-cost ledger said 12 cycles vs the measured 36/37; three capture/prose factual mismatches) and 4 minor (the six-byte stub count, the start-bank mechanism, the 47/38 margin, the duplicate Session B heading); curriculum-auditor — 4 major (the six-byte stub count, the stale 03 pins, the stale ST-56.5, the stale findings/roadmap) and 8 minor (margin, Javatari note, ex1 header, What's Next wording, Step 7 label, prose, duplicate heading, 259/40). All fixed: the full 13 + 23/24 + 3 ledger and 259/39–40, the measured three-trunk/arch captions and pixel table, the six-byte ranges (including the bank-0 header), 03/07/05/99/roadmap sync, the fire disclosure, the Lesson 33 prerequisite, and the exercise logs. A round-2 re-review found seven residuals (the takeaway, the Section 5 table, the bank-0 stub header, the indicator-row counts, the capture-pixel unit, Step 6's staircase, and the ex3 `$F085`); all are fixed. Final state: 0 critical, 0 major open. Lesson 56 is complete.

---

## Phase 2: Lesson 57 — Superchip

> **Phase baseline tree**: the Lesson 56 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/57-superchip/` (4 sources) ·
> `docs/part8-advanced/57-superchip.md` · index row 57 ·
> `docs/public/roms/part8-advanced/57-superchip/` · `docs/public/images/lesson57/` (2 captures) ·
> `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the F8SC signature, the `$F100` code start, and the RAM windows are easy
> to get subtly wrong

### Step 2.1: Lesson 57 — Superchip

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 57 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 57 · AR-1–AR-6, AR-8–AR-11, AR-23,
AR-25
**Objective**: Deliver Lesson 57 end to end.

- [x] 2.1.1 Lesson 57 — Superchip: Session A freezes ST-57.1–ST-57.6 (red baseline), Session B
  implements the full artifact set, Session C verifies to green and hardens; commit via the
  `git-commit` skill in push mode — `feat(lesson57): Superchip` ✅ (completed: 2026-11-06 14:26)

**Session A record** (freeze + red baseline, 2026-11-06 13:03): ST-57.1–ST-57.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 57. Design pins: 8,192-byte F8SC; bank 0 at real `$E000` with `!pseudopc $F000`, bank 1 at real `$F000`; start bank **1**; each bank begins with two 128-byte `$EA` fills (the duplicated Stella/Javatari signature) and code starts at `$F100`; the reset vector at `$FFFC` points to `$F100`; bank 0's `$F100` is a six-byte stub that selects bank 1 and jumps to `$F106` (the first byte after the stub). The Superchip RAM is the 128 bytes at `$1000–$107F` (write) / `$1080–$10FF` (read); it is not zeroed by the console and persists across bank switches. The demo is "the 128-byte notebook": 8 status lines (16-cell gauge + "SC") + 184 play lines (a 6-character message window and a moving marker); a 32-byte message table in ROM is written one byte at a time into the 128-byte RAM at `$1000+RamPtr`, read back through `$1080+RamPtr`, and the gauge lights each 8-byte group that has been written; `Writes`/`Reads` count the operations; one HMOVE. Exercises: fill all 128 bytes (all cells), a 128-byte sprite/playfield strip, and persistence across a bank switch. Evidence pins: `F8SC* (8K)`, the signature compare, `RamWrite` (A = the byte), `RamRead` (A = the same byte), `RamPtr`, `Writes`, `Reads`, `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6. Red baseline confirmed: no `lessons/part8-advanced/57-superchip`, no `docs/public/images/lesson57`, no Part 8 57 ROMs, the document is the `🔒 Coming Soon` stub, index row 57 Coming Soon, sidebar `config.ts:140`, `verify.sh --no-docs` green at `a005bd0`. No implementation logic read (AR-2).

**Session B record** (implementation, 2026-11-06 13:36): Four sources (8,192 each), the 1,367-line document, four committed ROMs, and two captures. The layout is F8SC: bank 0 at real `$E000`/pseudopc `$F000`, bank 1 at real `$F000`; each bank starts with two 128-byte `$EA` fills (the signature); the six-byte `$F100` stub selects bank 1 and jumps to `$F106`; the vectors point to `$F100`. The Superchip RAM is the 128 bytes at `$1000–$107F` write / `$1080–$10FF` read. The demo is the 128-byte notebook: 8 status + 184 play, a 16-cell gauge, a two-line six-character window, a 32-byte message table in ROM written into the 128-byte RAM, and a gold marker; one HMOVE. Exercises: the full 128-byte fill with a permanent failure flag, the 128-byte graphics strip, and the one-way bank-1-to-bank-0 persistence proof. Captures: 4 and 10 gauge cells; the marker at TIA 49–56 / 33–40 after the `POS_BIAS` fix.

**Session C record** (verify + evidence, 2026-11-06 14:26): `bash scripts/verify.sh` PASSED (220 ROMs, no drift, docs build); all four sources 8,192 and byte-identical to the committed ROMs; `F8SC* (8K)`; both 4K banks' first 128 bytes equal the next 128; the entry `AD F9 1F 4C 06 F1` and vectors `$F100` are identical in both banks; the no-signature control reports `F8* (8K)`. Frame: `StartFrame` `$F15F` 259/3 (4/22 on the power-on frame), `VblankStart` `$F16D` 0/5, `BodyStart` `$F1A2` 37/5, `OverscanStart` `$F1F5` 229/6; 262 lines. RAM: `RamWrite` `$F212` A=$20 X=0, A=$20 X=1, A=$53 X=5; `RamRead` `$F215` returns $20/$20/$53; `RamPtr` `$F252`, `MsgPtr` `$F25A`, `Writes` `$F25E`, `Reads` `$F262`. Exercise logs: ex1 `FillDone` A=$FF X=$80 and a forced-mismatch build `FillFailFlag` A=$01 with an empty gauge; ex2 `GaugeAll` `$F128`, `StripRead` $01/$02/$04/$08/$10, `StripDone` Y=$80; ex3 `B1Write` A=$A5, `B0Read` A=$A5, `B0Color` A=$C8, the switch frame `B0StartFrame` 259/15 and steady 259/3, `B0VblankStart` 0/5, `B0BodyStart` 37/5, `B0OverscanStart` 229/6. Captures: notebook-a 4 cells x=121–216, marker x=319–366; notebook-b 10 cells x=121–360, marker x=223–270; titles `Stella 7.0: "57-superchip"`, no cursor. Site: index row 57 ✅, rows 58–65 Coming Soon; prev 56/next 58; sidebar `config.ts:140`; README unchanged. Reviews (AR-5): atari2600-reviewer — 1 major (exercise 3's bank-1 re-entry asserted VSYNC ~51 lines late, a 313-line frame every 128 frames) plus 7 minor (exercise 1's failure gauge self-healed, the page-local cycle ledger, the ex1 RAM map `$80-$A7`, the ex1 `$F200` table address, the ex2 `GaugeAll` label, the notebook-a caption, the reset-vector wording); curriculum-auditor — 1 major (the Session B/C evidence and the SR-57 ledger were not written) plus 7 minor (the missing muted note, the notebook-a caption, the dead `POS_BIAS`, the spec gauge rule, the 99 Session A stub `$F106`, the ex1 RAM map, the Javatari start-bank note). All fixed: exercise 3 is a one-way switch with VSYNC at the bank-0 entry (259/15 switch frame, 259/3 steady, 262 lines); exercise 1 has `FillFailFlag = $AD`; `POS_BIAS` is applied at the call site and the captures are re-taken; the cycle ledger is 29/32/17 with PF0 at 14 and a 44-cycle text margin; the headers/spec/captions/notes are corrected. Final state: 0 critical, 0 major open. Lesson 57 is complete.

---

## Phase 3: Lesson 58 — Illegal Opcodes

> **Phase baseline tree**: the Lesson 57 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/58-illegal-opcodes/` (4 sources) ·
> `docs/part8-advanced/58-illegal-opcodes.md` · index row 58 ·
> `docs/public/roms/part8-advanced/58-illegal-opcodes/` · `docs/public/images/lesson58/` ·
> `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the undocumented opcode bytes, flags, and the ACME toolchain limitation
> must be exact

### Step 3.1: Lesson 58 — Illegal Opcodes

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 58 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 58 · AR-1–AR-6, AR-8, AR-14, AR-23,
AR-25
**Objective**: Deliver Lesson 58 end to end.

- [x] 3.1.1 Lesson 58 — Illegal Opcodes: Session A freezes ST-58.1–ST-58.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson58): Illegal Opcodes` ✅ (completed: 2026-11-06 16:15)

**Session A record** (freeze + red baseline, 2026-11-06 14:28): ST-58.1–ST-58.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 58. Design pins: 4,096-byte "opcode laboratory"; a 192-line static screen with four 32-line rows (the results of LAX/SAX/DCP/ISB) and a title/status band, a P0 marker selects a row, and SELECT toggles a second cycle-table screen; the four operations run once per frame in VBLANK on known inputs; ACME's `!cpu 6502` mode rejects the undocumented mnemonics; `!cpu 6510` accepts them, but the lesson keeps 6502 mode and uses named `!byte` macros so every byte stays visible (`LAX zp $A7`, `SAX zp $87`, `DCP zp $C7`, `ISB zp $E7`); the result bytes, flags, and a XOR checksum are stored in `$80–$85`; one HMOVE. Exercises: (1) replace a `LDA`/`TAX` pair with `LAX`; (2) use `DCP` for a countdown; (3) use `SAX`/`LAX` to store and reload a mask. Evidence pins: `LaxRead`/`SaxRead`/`DcpRead`/`IsbRead` (A = each result), `SaxM`/`DcpM`/`IsbM`, `FlagsRead` (P), `Checksum`, `Screen`, `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6. Red baseline confirmed: no `lessons/part8-advanced/58-illegal-opcodes`, no `docs/public/images/lesson58`, no Part 8 58 ROMs, the document is the `🔒 Coming Soon` stub, index row 58 Coming Soon, sidebar `config.ts:141`, `verify.sh --no-docs` green at `a43bf36`. No implementation logic read (AR-2).

**Session B record** (implementation, 2026-11-06 14:55): Four sources (4,096 each), the 1,680-line document, four committed ROMs, and two captures. The lab runs LAX/SAX/DCP/ISB once per frame on fixed inputs through named `!byte` macros ($A7/$87/$C7/$E7), stores the results, flags, and an XOR checksum, and draws four result rows plus a title/status band; SELECT shows the eight-row cycle table. The row setup was moved into `ResultLine` so PF0/PF1 precede the row's first beam; the four strips were unrolled so the byte line shows $A7/$87/$C7/$E7; the footer rule starts at chunk 0; LAX/SAX clear the carry; the checksum's two PF2 bits are in hardware order; the documented bars are right-aligned. The ACME rationale is corrected: `!cpu 6502` rejects the mnemonics, `!cpu 6510` accepts them (LAX/SAX/DCP/ISC), and the course keeps 6502 mode + macros for byte visibility.

**Session C record** (verify + evidence, 2026-11-06 16:15): `bash scripts/verify.sh` PASSED (224 ROMs, no drift, docs build); all four sources 4,096 and byte-identical; `StartFrame` `$F04A` 259/3, `VblankStart` `$F058` 0/5, `BodyStart` `$F0D1` 37/5, `OverscanStart` `$F319` 229/6; 262 lines. Operations: `LaxRead` `$F337` A=X=$12 (C=0); `SaxRead` `$F34C` A=$12 X=$34 (C=0); `SaxM` `$F35A` A=$10; `DcpRead` `$F35E` A=$1F Z1 C1; `DcpM` `$F36C` A=$1F; `IsbRead`/`FlagsRead` `$F371` A=$0F C1 Z0; `IsbM` `$F385` A=$11; `Checksum` `$F38D` A=$0C; `Screen` `$F0B7` A=0/1. The four strips read $A7/$87/$C7/$E7; the DCP/ISB row first lines show their own flag bits; the footer rule spans x=25–985 on both screens; the documented bars are right-aligned at chunk 19; the eight band separators are continuous (x=73–505 and the mirror); the row ledger is measured from `ResultLine`; the reflected panel is documented; the DcpM log is C=1. Exercises: ex1 PairA/PairX $42, Saved 2; ex2 DcpCount $1F/$1E, DcpFlags/ReachedZero A=0 Z1 C1 at frame 480; ex3 SaxStore A=$F0 X=$3C, SaxMem $30, LaxLoad A=X=$30. Captures: lab-a result bars (18/16/31/17 lines) and lab-b cycle table; titles `Stella 7.0: "58-illegal-opcodes"`, no cursor. Site: index row 58 ✅; prev 57/next 59; sidebar `config.ts:141`; README unchanged. Reviews (AR-5): atari2600-reviewer — 1 major (the ACME claim) + 2 major (the row setup and the strip byte line) + 7 minor; curriculum-auditor — 1 critical (the ACME claim) + 2 major (SHA's `$9E`, the missing phase ledger) + 11 minor. All fixed: the ACME rationale and the 6510 evidence; the row/strip/footer timing and re-captures; the SHA table; the C carry, checksum bit order, exercise checkpoints, bar alignment, TypeScript V, and the prose/plan records. Final state: 0 critical, 0 major open. Lesson 58 is complete.

---

## Phase 4: Lesson 59 — Self-Modifying Code

> **Phase baseline tree**: the Lesson 58 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/59-self-modifying-code/` (4 sources) ·
> `docs/part8-advanced/59-self-modifying-code.md` · index row 59 ·
> `docs/public/roms/part8-advanced/59-self-modifying-code/` · `docs/public/images/lesson59/` ·
> `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the RAM routine, the stack overlap, and the patched operand are the
> lesson's correctness core

### Step 4.1: Lesson 59 — Self-Modifying Code

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 59 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 59 · AR-1–AR-6, AR-8, AR-15, AR-22,
AR-23, AR-25
**Objective**: Deliver Lesson 59 end to end.

- [x] 4.1.1 Lesson 59 — Self-Modifying Code: Session A freezes ST-59.1–ST-59.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson59): Self-Modifying Code` ✅ (completed: 2026-11-06 17:56)

**Session A record** (freeze + red baseline, 2026-11-06 16:17): ST-59.1–ST-59.6 re-affirmed against [03](03-lesson-specs.md) §Lesson 59. Design pins: 4,096-byte "code painter"; a 7-byte routine copied to `$80` (`LDA #$00` at `$80-$81`, `STA COLUBK` at `$82-$83`, `STA WSYNC` at `$84-$85`, `RTS` at `$86`); the main patches the immediate operand at `$81` from a 184-byte color table and calls `JSR $80` once per visible line; the routine uses no stack, so the `JSR`/`RTS` pair uses `$FF/$FE` safely (SP starts at `$FF`); 8 status lines (the patch byte and call count) + 184 gradient lines = 192; one HMOVE if a marker is used. Exercises: (1) patch a delay count (`LDX #n`) in the RAM routine; (2) patch a pointer operand (`LDA table,X` / `LDA (ptr),Y`) to select another table; (3) copy a second routine to `$90`, patch its `STA COLUPF`/`STA GRP0` address, and draw a second object. Evidence pins: `PatchByte` (A = the new color), `CallCount` (A = 184 per frame), `RamRoutine` (`$80`), `Frame`, `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6. Red baseline confirmed: no `lessons/part8-advanced/59-self-modifying-code`, no `docs/public/images/lesson59`, no Part 8 59 ROMs, the document is the `🔒 Coming Soon` stub, index row 59 Coming Soon, sidebar `config.ts:142`, `verify.sh --no-docs` green at `30826e5`. No implementation logic read (AR-2).

**Session B record** (implementation, 2026-11-06 16:55): Four sources (4,096 each), the 1,116-line document, four committed ROMs, and two captures. A 7-byte routine is copied to `$80` (`A9 xx 85 09 85 02 60`); the main patches `$81` from a 184-entry color table and calls `JSR $80` 184 times per frame. The table is stored twice and the phase window is split into two page-aligned halves: the first loop reads `ColorTable,Y` from `Y=Phase`, the second reads `ColorTable+256,Y` after the wrap. `HoldFrames` is a one-shot 60-frame hold; the status setup runs in VBLANK; the left-edge strip is the measured 37 px steady / 46 first / 64 last. Exercises: patched delay, patched pointer, second routine at `$90`. Captures: phase 0 and phase 96.

**Session C record** (verify + evidence, 2026-11-06 17:56): `bash scripts/verify.sh` PASSED (228 ROMs, no drift, docs build); all four sources 4,096 and byte-identical; Full Source verbatim (1,116 doc lines). Frame: `StartFrame` `$F033` 259/3, `VblankStart` `$F041` 0/5, `BodyStart` `$F08B` 37/5, `OverscanStart` `$F0D1` 229/6; 262 lines. The routine bytes at `$80–$86` are `A9 xx 85 09 85 02 60`; `RamRoutine` `$0080` PC, SP=$FD; `PatchByte` `$F0AB` A=$02/$04/$14/$16…; `PatchByteTail` `$F0BB` A=$6E at the first wrap (phase 73); `CallCount` `$F0CC` A=$B8 (184). The color write is cycle 34 steady; the left-edge strip is 37 px; the first line is 46 px and the last 64 px. Exercises: ex1 DelayPatch 1–4 and `STA COLUBK` 45/48/53/58; ex2 PtrLow/High $00/$F1 and $00/$F2, `TableRead` `$0083` $02→$8E; ex3 ShapePatch $18/$3C/$7E, ShapeRoutine `$0090`, P0 at TIA 80. Captures: painter-a phase 0 (`PatchVal=$F2`, first line $02), painter-b phase 96 (`PatchVal=$8E`, first line $8E, the two-window gradient), titles `Stella 7.0: "59-self-modifying-code"`, no cursor. Site: index row 59 ✅; prev 58/next 60; sidebar `config.ts:142`; README unchanged. Reviews (AR-5): atari2600-reviewer — 1 critical (the 8-bit `Y` phase overflow above 72; the painter-b phase claim was false) + 2 major (the 60-frame hold repeated every 256 frames; the left-edge seam had three models) + 8 minor; curriculum-auditor — the same critical + the seam/plan/spec minors. All fixed: the two-window split, the one-shot hold, the single 37/46/64 seam model, the status race, the ex1 delay limit/heading, the ex2 TableRead/184-byte table, the ex3 X/first-byte/cycle numbers, and the 03/07 sync. Final state: 0 critical, 0 major open. Lesson 59 is complete.

---

## Phase 5: Lesson 60 — DPC and DPC+

> **Phase baseline tree**: the Lesson 59 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/60-dpc-plus/` (4 sources) ·
> `docs/part8-advanced/60-dpc-plus.md` · index row 60 ·
> `docs/public/roms/part8-advanced/60-dpc-plus/` · `docs/public/images/lesson60/` ·
> `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the 10K layout, the bank-1/`$F080` entry, the measured register table, and
> the 2K display image are the hardest technical claims in Part 8

### Step 5.1: Lesson 60 — DPC and DPC+

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 60 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 60 · AR-1–AR-6, AR-8, AR-12, AR-13,
AR-23, AR-25, AR-29, AR-30
**Objective**: Deliver Lesson 60 end to end.

- [ ] 5.1.1 Lesson 60 — DPC and DPC+: Session A freezes ST-60.1–ST-60.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson60): DPC and DPC+`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 6: Lesson 61 — Compression & Data Encoding

> **Phase baseline tree**: the Lesson 60 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/61-compression/` (4 sources) ·
> `docs/part8-advanced/61-compression.md` · index row 61 ·
> `docs/public/roms/part8-advanced/61-compression/` · `docs/public/images/lesson61/` ·
> `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the RLE decoder must be bounded and the decoded image must checksum-match

### Step 6.1: Lesson 61 — Compression & Data Encoding

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 61 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 61 · AR-1–AR-6, AR-8, AR-16, AR-23,
AR-25
**Objective**: Deliver Lesson 61 end to end.

- [ ] 6.1.1 Lesson 61 — Compression & Data Encoding: Session A freezes ST-61.1–ST-61.6 (red
  baseline), Session B implements the full artifact set, Session C verifies to green and hardens;
  commit via the `git-commit` skill in push mode — `feat(lesson61): Compression`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 7: Lesson 62 — Reverse Engineering a Classic Game

> **Phase baseline tree**: the Lesson 61 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/62-reverse-engineering/demo-62.asm` ·
> `docs/part8-advanced/62-reverse-engineering.md` · index row 62 ·
> `docs/public/roms/part8-advanced/62-reverse-engineering/` ·
> `docs/public/images/lesson62/` · `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the demo must be complete enough to reverse-engineer, and the annotated
> map must match the symbol table

### Step 7.1: Lesson 62 — Reverse Engineering a Classic Game

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 62 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 62 · AR-1–AR-6, AR-8, AR-17, AR-23,
AR-25
**Objective**: Deliver Lesson 62 end to end.

- [ ] 7.1.1 Lesson 62 — Reverse Engineering a Classic Game: Session A freezes ST-62.1–ST-62.6
  (red baseline), Session B implements the demo and the document, Session C verifies to green and
  hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson62): Reverse Engineering a Classic Game`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 8: Lesson 63 — Modern Homebrew

> **Phase baseline tree**: the Lesson 62 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/63-modern-homebrew/demo-63.asm` ·
> `docs/part8-advanced/63-modern-homebrew.md` · index row 63 ·
> `docs/public/roms/part8-advanced/63-modern-homebrew/` ·
> `docs/public/images/lesson63/` · `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: medium — the attract mode is a production-value demo; the prose must avoid
> unsourced community claims

### Step 8.1: Lesson 63 — Modern Homebrew

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 63 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 63 · AR-1–AR-6, AR-8, AR-18, AR-23,
AR-25
**Objective**: Deliver Lesson 63 end to end.

- [ ] 8.1.1 Lesson 63 — Modern Homebrew: Session A freezes ST-63.1–ST-63.6 (red baseline),
  Session B implements the demo and the document, Session C verifies to green and hardens; commit
  via the `git-commit` skill in push mode — `feat(lesson63): Modern Homebrew`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 9: Lesson 64 — Building Your Own Cartridge

> **Phase baseline tree**: the Lesson 63 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/64-building-cartridges/demo-64.asm` ·
> `docs/part8-advanced/64-building-cartridges.md` · index row 64 ·
> `docs/public/roms/part8-advanced/64-building-cartridges/` ·
> `docs/public/images/lesson64/` · `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: medium — the burn-in test must be a real, useful test; the hardware prose must
> be accurate and not claim a physical build

### Step 9.1: Lesson 64 — Building Your Own Cartridge

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 64 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 64 · AR-1–AR-6, AR-8, AR-19, AR-23,
AR-25
**Objective**: Deliver Lesson 64 end to end.

- [ ] 9.1.1 Lesson 64 — Building Your Own Cartridge: Session A freezes ST-64.1–ST-64.6 (red
  baseline), Session B implements the demo and the document, Session C verifies to green and
  hardens; commit via the `git-commit` skill in push mode —
  `feat(lesson64): Building Your Own Cartridge`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 10: Lesson 65 — PAL/NTSC Universal ROM

> **Phase baseline tree**: the Lesson 64 commit (clean tree at phase start; scope: strict)
> **Expected modifications**: `lessons/part8-advanced/65-pal-ntsc-universal/` (4 sources) ·
> `docs/part8-advanced/65-pal-ntsc-universal.md` · index row 65 ·
> `docs/public/roms/part8-advanced/65-pal-ntsc-universal/` ·
> `docs/public/images/lesson65/` · `99-execution-plan.md` + `05-findings.md`
> **Reasoning**: high — the lesson must teach the selector and the impossibility of stock
> auto-detection, and the 262/312 frame arithmetic must match the state log

### Step 10.1: Lesson 65 — PAL/NTSC Universal ROM

**Reference**: [03-lesson-specs.md](03-lesson-specs.md) §Lesson 65 ·
[07-testing-strategy.md](07-testing-strategy.md) §Lesson 65 · AR-1–AR-6, AR-8, AR-20, AR-21,
AR-23, AR-25, AR-32
**Objective**: Deliver Lesson 65 end to end.

- [ ] 10.1.1 Lesson 65 — PAL/NTSC Universal ROM: Session A freezes ST-65.1–ST-65.6 (red baseline),
  Session B implements the full artifact set, Session C verifies to green and hardens; commit via
  the `git-commit` skill in push mode — `feat(lesson65): PAL/NTSC Universal ROM`

**Session A record**:

**Session B record**:

**Session C record**:

---

## Phase 11: Part 8 Completion Gate

> **Phase baseline tree**: the Lesson 65 commit (clean tree at gate start; scope: strict)
> **Expected modifications**: `docs/part8-advanced/index.md` (final check) · `README.md` (verify
> only) · `codeops/features/curriculum/00-roadmap.md` · `codeops/00-roadmap.md` ·
> `99-execution-plan.md` · `05-findings.md` · `00-index.md` · `02-current-state.md`
> **Reasoning**: high — the gate counts the artifacts, confirms the reviews, and marks RD-08 Done

- [ ] 10.1.1a Part 8 completion gate (a gate, not an eleventh lesson task): index rows 56–65 ✅,
  RD-08 Done, feature roadmap 8/11, portfolio 8 plans, all completion criteria ticked, final
  `verify.sh` green

## Completion Criteria

- [ ] All ten phases marked `[x]` with Session A/C records.
- [ ] 31 committed ROMs (4K/8K/10K/16K), 10 documents, 20 screenshots.
- [ ] Lessons 56–61 and 65 ship three exercise solutions each; 62–64 ship `demo-NN.asm`.
- [ ] Part 8 index rows 56–65 all ✅ Complete.
- [ ] `bash scripts/verify.sh` green at the final commit.
- [ ] Both specialists report no critical/major open for every lesson.
- [ ] No dead code, no unused symbols/tables; security is N/A (static content, no input).
- [ ] The post-completion re-analysis (plan/skill protocol) is recorded.
- [ ] RD-08 Done; feature roadmap 8/11 RDs; portfolio 8 plans done.
