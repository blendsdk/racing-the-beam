# Ambiguity Register: Atari 2600 Masterclass

> **Status**: ✅ GATE PASSED — all 20 items resolved
> **Last Updated**: 2026-05-26

| # | Category | Ambiguity / Gap | Options Presented | User Decision | Status |
|---|----------|----------------|-------------------|---------------|--------|
| AR-1 | Technical | VitePress version | Latest 1.x stable vs older | 1.x stable — well-documented, Shiki built-in | ✅ Resolved |
| AR-2 | Structure | Lesson directory layout | A) `lessons/01-name/` B) `lessons/part0/01-name/` | B) Group by part — `lessons/part0-foundations/01-number-systems/` | ✅ Resolved |
| AR-3 | Structure | Solution files location | A) Same dir as lesson B) `solutions/` subdir | A) Same directory: `lesson.asm` + `exercise-solution.asm` | ✅ Resolved |
| AR-4 | Naming | Lesson file naming | A) `main.asm` B) Descriptive name | B) Descriptive: `01-number-systems.asm` | ✅ Resolved |
| AR-5 | Technical | VitePress code inclusion | A) Copy-paste B) `<<< @/path` import | B) Import from actual `.asm` files — single source of truth | ✅ Resolved |
| AR-6 | Format | PAL notes format | A) Inline callouts B) End-of-lesson C) Appendix | A) Inline `:::tip PAL Note` callouts where timing differs | ✅ Resolved |
| AR-7 | Format | TypeScript analogy format | A) Inline text B) Side-by-side C) Collapsible | C) Collapsible `:::details TypeScript Equivalent` sections | ✅ Resolved |
| AR-8 | Format | Exercise format | A) Challenges B) +hints C) +hints+expected | C) Structured: challenge → hints → expected result | ✅ Resolved |
| AR-9 | Format | Cheat sheet format | A) VitePress page only B) Also printable PDF | A) VitePress page — searchability over printing | ✅ Resolved |
| AR-10 | Format | Lesson dependencies | A) Strictly linear B) Some out of order | A) Strictly linear — structured course | ✅ Resolved |
| AR-11 | Technical | Color picker component | A) Simple table B) Interactive grid C) Grid+search+filter | B) Interactive grid with click-to-copy hex | ✅ Resolved |
| AR-12 | Technical | 6502 instruction reference | A) Static B) Searchable C) Full interactive | B) Searchable/filterable table | ✅ Resolved |
| AR-13 | Technical | TIA register reference | A) Static B) Searchable+bit diagrams | B) Searchable with bit-field diagrams | ✅ Resolved |
| AR-14 | Technical | VitePress deployment | A) Local dev only B) GitHub Pages | A) Local only — deployment can be added later | ✅ Resolved |
| AR-15 | Technical | Makefile lesson target format | Various formats | `make lesson L=part0/01` — part + lesson number | ✅ Resolved |
| AR-16 | Scope | Capstone 1: Pong scope | A) Minimal B) Full | B) Full — 2 paddles, score, sound | ✅ Resolved |
| AR-17 | Scope | Capstone 2 game choice | A) Breakout B) Maze C) Shooting gallery | A) Breakout — builds on Pong concepts | ✅ Resolved |
| AR-18 | Scope | Capstone 3 game choice | A) Maze B) Vertical scrolling C) Platformer | A) Maze game — room management, playfield design | ✅ Resolved |
| AR-19 | Scope | Capstone 4 game choice | A) Scrolling shooter B) Guided C) Student's choice | C) Student's choice — open-ended with guidance | ✅ Resolved |
| AR-20 | Scope | Lesson verification method | A) Compilation only B) +ROM size C) +Stella screenshot | B) Compilation + ROM size check | ✅ Resolved |

## Pre-Gate Decisions (from Phase 1.1 Q&A)

| Q | Decision | User Confirmation |
|---|----------|-------------------|
| Q1 | NTSC primary, PAL notes where timing differs | Confirmed |
| Q2 | Each lesson: `.asm` file + `.md` theory + exercises + solutions | Confirmed |
| Q3 | All the way to modern homebrew mastery (ARM-assisted, DPC+, etc.) | Confirmed |
| Q4 | Analyze batari BASIC kernel + design our own kernel architecture | Confirmed |
| Q5 | Build toward DSL throughout — later lessons identify automatable patterns | Confirmed |
| Q6 | Ultra-thorough 6502 teaching: reference doc + lessons + cheat sheet | Confirmed |
| Q7 | Medium TypeScript analogies — every concept gets a TS equivalent | Confirmed |
| Q8 | Growing reusable library — each lesson adds, becomes DSL foundation | Confirmed |
| Q9 | `make lesson L=part0/01` build target per lesson | Confirmed |
| Q10 | All compile + exercises + at least one capstone game completed | Confirmed |
| Q11 | Multiple capstones of increasing difficulty | Confirmed |
| Q12 | Binary/hex/number systems lesson included | Confirmed |
| Q13 | Dedicated Stella debugger lesson included | Confirmed |
| Q14 | 60+ lesson full masterclass | Confirmed |
| Q15 | Same repo — `docs/` alongside source | Confirmed |
| Q16 | Both: inline code in lessons + standalone buildable `.asm` files | Confirmed |
| Q17 | Interactive components: color picker, 6502 reference, TIA reference | Confirmed |
| Q18 | Default VitePress theme with Atari-inspired accent colors | Confirmed |
