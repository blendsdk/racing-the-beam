# Requirements: Atari 2600 Masterclass

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)

## Feature Overview

A complete, 60+ lesson programming masterclass that takes a TypeScript developer with forgotten C64/6502 experience from zero to Atari 2600 mastery. Delivered as a VitePress documentation site with interactive reference tools, buildable source code per lesson, exercises with solutions, and multiple capstone game projects. The curriculum is designed to build toward a future DSL/code generator for Atari 2600 game development.

## Functional Requirements

### Must Have

- [ ] **61+ progressive lessons** covering all aspects of Atari 2600 development
- [ ] **10 curriculum parts** from foundations through capstone projects
- [ ] **VitePress documentation site** with sidebar navigation, search, syntax highlighting
- [ ] **Standalone `.asm` file per lesson** that compiles with ACME and runs in Stella
- [ ] **Heavy inline comments** in all assembly code explaining every instruction
- [ ] **TypeScript analogies** for every new concept (collapsible sections) — per AR-7
- [ ] **Exercises with solutions** for every lesson (structured: challenge → hints → expected result) — per AR-8
- [ ] **PAL timing notes** as inline callouts where NTSC/PAL differ — per AR-6
- [ ] **6502 instruction cheat sheet** as a VitePress page — per AR-9
- [ ] **NTSC color chart** with all 128 colors — interactive Vue component — per AR-11
- [ ] **6502 instruction reference** — searchable/filterable table — per AR-12
- [ ] **TIA register reference** — searchable with bit-field diagrams — per AR-13
- [ ] **Stella debugger tutorial** — dedicated lesson with hands-on walkthrough — per Q13
- [ ] **Binary/hex number systems lesson** — per Q12
- [ ] **Growing reusable library** — new include files introduced as complexity grows — per Q8/AR-5
- [ ] **batari BASIC kernel analysis** — understand how bB works — per Q4
- [ ] **Own kernel architecture design** — foundation for future DSL — per Q4
- [ ] **4 capstone projects** of increasing difficulty — per Q11
- [ ] **Makefile with per-lesson build targets** — `make lesson L=part0/01` — per AR-15
- [ ] **Strictly linear progression** — each lesson builds on previous — per AR-10

### Should Have

- [ ] **DSL pattern identification** in later lessons — noting what's automatable — per Q5
- [ ] **Multiple kernel pattern coverage** (1-line, 2-line, multi-zone)
- [ ] **Memory management strategies** for 128 bytes of RAM
- [ ] **Common debugging patterns** — how to diagnose rolling screens, wrong colors, etc.
- [ ] **Cycle-exact counting exercises** — core beam-racing skill
- [ ] **Optimization techniques** — cycle shaving, unrolled loops, self-modifying code

### Won't Have (Out of Scope)

- Actually building the DSL/compiler (future project)
- Writing complete games for the student (capstones are guided, not pre-built)
- Supporting assemblers other than ACME (mention DASM/ca65 briefly)
- Hardware manufacturing / PCB design / cartridge production
- Atari 7800 / 5200 / other Atari platforms
- GitHub Pages deployment (local dev server only) — per AR-14
- Printable PDF cheat sheets — per AR-9

## Technical Requirements

### Build System

- ACME assembler v0.97+ (installed: `/usr/bin/acme`)
- Stella emulator (installed)
- Node.js + npm for VitePress
- GNU Make for lesson builds

### Compatibility

- All `.asm` files must compile with ACME assembler without warnings
- All ROMs must be exactly 4096 bytes (standard 4KB) unless bankswitching lesson
- All ROMs must run correctly in Stella emulator
- VitePress site must build without errors

### Performance

- VitePress dev server starts in < 5 seconds
- Each lesson `.asm` compiles in < 1 second

## Scope Decisions

| Decision | Options Considered | Chosen | Rationale | AR Ref |
|----------|-------------------|--------|-----------|--------|
| TV Standard | NTSC only / PAL only / Both / NTSC+PAL notes | NTSC primary + PAL notes | Student is in EU but NTSC is standard for tutorials | Q1 |
| Lesson depth | Basic / Intermediate / Advanced / Full mastery | Full mastery | Student explicitly requested "ALL, no shortcuts" | Q3 |
| Lesson format | Code only / +markdown / +exercises / +solutions | Full: code + md + exercises + solutions | Maximum learning value | Q2 |
| Code in docs | Copy-paste / File import / Both | File import via `<<<` | Single source of truth | AR-5 |
| Directory layout | Flat / Grouped by part | Grouped by part | Better organization for 60+ lessons | AR-2 |
| Lesson naming | Generic / Descriptive | Descriptive names | Easier identification | AR-4 |

## Acceptance Criteria

1. [ ] All 61+ lesson `.asm` files compile without warnings
2. [ ] All lesson ROMs are correct size (4096 bytes standard, or documented exception)
3. [ ] All lesson ROMs run in Stella without crashes
4. [ ] VitePress site builds without errors
5. [ ] Every lesson has a theory `.md` document
6. [ ] Every lesson has exercises with solutions
7. [ ] All 3 interactive Vue components work (color picker, 6502 ref, TIA ref)
8. [ ] All 4 capstone projects compile and are playable
9. [ ] Strictly linear progression — no lesson references concepts not yet taught
10. [ ] TypeScript analogies present for all major concepts
