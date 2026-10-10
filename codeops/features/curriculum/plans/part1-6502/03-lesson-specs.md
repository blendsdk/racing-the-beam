# Lesson Specifications: Part 1 — The 6502 CPU (Lessons 07–11)

> **Document**: 03-lesson-specs.md
> **Parent**: [Index](00-index.md)

## Overview

One section per lesson; each is the authoritative spec for that lesson's artifacts. Concepts come only from the lesson's stub title/topic in the Part 1 index (`docs/part1-6502-cpu/index.md:12–16`) and the 6502 reference (`.opencode/skills/atari-2600-expert/references/6502-cpu.md`); register and bit ground truth is `include/vcs.asm` (AR-9). Every lesson ROM assembles to exactly 4,096 bytes and follows the lesson 04 program shape, frame skeleton, and band-painting kernel ([02-current-state.md](02-current-state.md) §Code Analysis).

## Lesson 07: Branches and Loops — Conditional Execution

- **Goal:** write conditional branches and loops that terminate correctly for every relevant flag state.
- **Concepts:** the branch family (`BEQ`/`BNE` → Z, `BCS`/`BCC` → C, `BMI`/`BPL` → N, `BVS`/`BVC` → V); CMP-then-branch (`CPX $nn`) and branching on a previous flag result; count-down (`DEX`/`BNE`) and count-up loops; nested delay loops; `JMP` vs. branch; branch reach (±127 bytes) and anonymous `-`/`+` labels.
- **ROM:** `07-branches-and-loops.asm` — the "cursor ladder": 8 equal bands (24 scanlines). Seven bands are dark gray (`$02`); one band, selected by the cursor byte in RAM `$80`, is bright red (`$42`). The band loop counts with X and compares `CPX $80`; the cursor advances one band per animation step and wraps 7 → 0 with a compare-and-reset branch. A nested countdown loop times the stepping.
- **Expected screen:** eight equal bands with one bright band; the bright band walks downward one band about every half second and wraps from the bottom to the top, repeating.
- **Exercises:** 1. paint 12 bands instead of 8 with a chosen countdown loop — `exercise-01-solution.asm`; 2. a bouncing cursor: a direction byte reverses the bright band at the top and bottom — `exercise-02-solution.asm`; 3. *(Stretch)* branch reach: after the assembler rejects an over-range `BNE`, restructure with `JMP`/flag test — `exercise-03-solution.asm` (the fixed, assembling version).
- **Screenshots:** `docs/public/images/lesson07/loop-cursor-top.png` and `…/loop-cursor-bottom.png` — two captures a few seconds apart showing the bright band at different positions.
- **Demo ROM:** none required — the lesson ROM has direct visual output.
- **Integration:** prev → Lesson 06 (already links forward, `06-flags-and-comparisons.md:7–9`); next → Lesson 08; part-index row 07 → ✅ Complete linking `./07-branches-and-loops`; sidebar entry exists (`config.ts:48`) — verify only. Estimated time: 45 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 07): ST-07.1 assembly & drift · ST-07.2 static frame · ST-07.3 motion and wrap · ST-07.4 debugger state · ST-07.5 solutions and screenshots.

## Lesson 08: The Stack and Subroutines — Functions in Assembly

- **Goal:** use the stack correctly (pushes/pulls, nested `JSR`/`RTS`) and know the page-`$01` collision hazard.
- **Concepts:** the SP register and stack page `$01` mirroring RAM `$80–$FF`; `PHA`/`PLA` and `PHP`/`PLP`; saving registers across calls; `JSR` pushes return address − 1 and `RTS` adds 1; nested chains (`Frame → DrawScreen → PaintBand`); when a subroutine earns its keep.
- **ROM:** `08-stack-and-subroutines.asm` — "subroutine bands": 4 equal bands (48 scanlines) painted by one shared `PaintBand` subroutine (color in A, line count in X). `DrawScreen` calls it four times and preserves its own counter across the calls with an explicit push/pull round trip, so the debugger shows the stack working.
- **Expected screen:** four equal bands, top to bottom `$42`, `$C8`, `$96`, `$1A` — a steady picture produced by four calls to the same subroutine.
- **Exercises:** 1. extend `PaintBand` to 8 calls with shorter bands — `exercise-01-solution.asm`; 2. a subroutine that clobbers X but preserves the caller's X via `TXA`/`PHA`…`PLA`/`TAX` — `exercise-02-solution.asm`; 3. *(Stretch)* a 3-level nested chain; the debugger shows SP descending 2 bytes per level and returning to `$FF` — `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson08/subroutine-bands.png` — the four-band picture.
- **Demo ROM:** none required — the lesson ROM has direct visual output.
- **Integration:** prev → Lesson 07; next → Lesson 09; part-index row 08 → ✅ Complete linking `./08-stack-and-subroutines`; sidebar entry exists (`config.ts:49`). Estimated time: 45 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 08): ST-08.1 assembly & drift · ST-08.2 static frame · ST-08.3 stack behavior in the debugger · ST-08.4 nested-chain depth · ST-08.5 solutions and screenshot.

## Lesson 09: Bitwise Operations — The Power of Bits

- **Goal:** set, clear, and test bit flags with `AND`, `ORA`, `EOR`, and shifts.
- **Concepts:** `AND` masks/clears, `ORA` sets, `EOR` toggles; testing a bit with `AND` + branch; `ASL`/`LSR` (×2, ÷2, carry out); `ROL`/`ROR` through carry; Z/N flags from results; building a byte from nibbles.
- **ROM:** `09-bitwise-operations.asm` — the "bit ladder": 8 bands (24 scanlines), top = bit 7 … bottom = bit 0 of the pattern byte in RAM `$80` (starts `%00000001`). A mask register shifts (`LSR`) once per band; a band is bright green (`$C8`) when `AND #mask` is nonzero, else dark gray (`$02`). Each step `ASL`s the pattern; when the shifted-out bit arrives in the carry (`BCS`), the pattern reloads `%00000001`, so the bright band walks bottom → top and repeats.
- **Expected screen:** eight bands with exactly one bright band; the bright band climbs from the bottom to the top over a few seconds, then restarts at the bottom.
- **Exercises:** 1. from `%10100000`, set bit 2 (`ORA`), clear bit 5 (`AND`), toggle bit 7 (`EOR`); each pattern is displayed and readable in RAM — `exercise-01-solution.asm`; 2. pack two nibbles held in `$80`/`$81` into one color byte with `AND`/`LSR`/`ORA` and use it as the band color — `exercise-02-solution.asm`; 3. *(Stretch)* a ring counter with `ROL`/`ROR` so the traveling bit re-enters instead of reloading — `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson09/bit-ladder-bottom.png` (bit 0 set) and `…/bit-ladder-top.png` (bit 7 set).
- **Demo ROM:** none required — the lesson ROM has direct visual output.
- **Integration:** prev → Lesson 08; next → Lesson 10; part-index row 09 → ✅ Complete linking `./09-bitwise-operations`; sidebar entry exists (`config.ts:50`). Estimated time: 45 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 09): ST-09.1 assembly & drift · ST-09.2 static frame · ST-09.3 walk and reload · ST-09.4 debugger state · ST-09.5 solutions and screenshots.

## Lesson 10: Addressing Modes — How the CPU Finds Data

- **Goal:** choose addressing modes deliberately and explain why each is required or useful.
- **Concepts:** the full catalog — implied, accumulator, immediate, zero-page, zero-page,X/,Y, absolute, absolute,X/,Y, relative, indirect (`JMP (addr)`, NMOS page-boundary bug noted), `(zp,X)`, and `(zp),Y`; length/cycle differences; the zero-page wrap hazard; branch reach; index registers selecting table entries.
- **ROM:** `10-addressing-modes.asm` — "same byte, several ways": top half = 6 identical `$42` bands (16 scanlines) loading the shared byte at RAM `$82` (pointer at `$80/$81` → `$0082`) via immediate, zero-page, absolute, zero-page,X (X=0), absolute,X (X=0), and `(zp),Y` (Y=0); bottom half = 6 bands forming the ramp `$42`, `$4C`, `$56`, `$60`, `$6A`, `$74` fetched from a 6-byte ROM table with `LDA data,Y` (Y = 0…5).
- **Demo ROM:** `demo-10.asm` (theory lesson) — the "mode ladder": 12 equal bands forming the fixed ramp `$1A + $0A·k` (k = 0…11); band k is produced by code that exercises mode k in catalog order, and the lesson document maps band → mode → instruction → debugger value.
- **Expected screen:** main ROM = 6 identical bands above 6 distinct ramp bands; demo ROM = 12 equal bands forming a smooth fixed ramp top to bottom.
- **Exercises:** 1. extend the indexed ramp to 12 bands with `LDA data,Y` — `exercise-01-solution.asm`; 2. walk a zero-page pointer with `(zp),Y` and switch between two tables so the screen alternates — `exercise-02-solution.asm`; 3. *(Stretch)* provoke and observe the zero-page wrap (`LDA $80,X` with X = `$80` reads TIA `$00`, not RAM), then rebuild safely with `(zp),Y` — `exercise-03-solution.asm` (safe version; the fault is documented in the lesson text).
- **Screenshots:** `docs/public/images/lesson10/addressing-modes.png` (main ROM) and `…/addressing-mode-ladder.png` (demo ROM).
- **Integration:** prev → Lesson 09; next → Lesson 11; part-index row 10 → ✅ Complete linking `./10-addressing-modes`; sidebar entry exists (`config.ts:51`). Estimated time: 60 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 10): ST-10.1 assembly & drift (both ROMs) · ST-10.2 main-ROM frame · ST-10.3 demo mode ladder · ST-10.4 debugger state · ST-10.5 solutions and screenshots.

## Lesson 11: Lookup Tables — Data-Driven Programming

- **Goal:** build lookup tables and index them from 6502 code.
- **Concepts:** `!byte` tables in ROM; `LDA table,X`/`,Y` indexing; base + index addressing; table bounds discipline (mask or compare the index); tables over time (colors and durations); tables instead of branch trees and runtime math.
- **ROM:** `11-lookup-tables.asm` — the "color wave": a 16-byte ROM table holding the fixed ramp `$1A + $0E·k` (k = 0…15). The screen shows 16 equal bands (12 scanlines); band k paints `table[(offset + k) AND $0F]`, with the offset byte in RAM `$80` advancing each step, so the wave scrolls upward and wraps seamlessly.
- **Expected screen:** 16 equal bands in the table's color order; the pattern shifts by one table entry about every quarter second and wraps from bottom to top without a jump or blank.
- **Exercises:** 1. author a second 16-byte color table and display it with `LDA table,X` — `exercise-01-solution.asm`; 2. a two-table movie: a colors table plus a durations table drive a full-screen sequence where each color is held for its own time — `exercise-02-solution.asm`; 3. *(Stretch)* a pointer table (`!word` entries) selects between two waves so the palette switches every few seconds — `exercise-03-solution.asm`.
- **Screenshots:** `docs/public/images/lesson11/lookup-wave.png` and `…/lookup-wave-shifted.png` — two captures a few seconds apart showing the wave shifted by one or more table steps.
- **Demo ROM:** none required — the lesson ROM has direct visual output.
- **Integration:** prev → Lesson 10; next → Lesson 12 (forward link to `/part2-tv-and-tia/12-the-ntsc-frame`, matching lesson 06's forward-link pattern); part-index row 11 → ✅ Complete linking `./11-lookup-tables`; sidebar entry exists (`config.ts:52`). Estimated time: 45 minutes.
- **ST cases** ([07-testing-strategy.md](07-testing-strategy.md) §Lesson 11): ST-11.1 assembly & drift · ST-11.2 static frame · ST-11.3 scroll and wraparound · ST-11.4 debugger state · ST-11.5 solutions and screenshots.
