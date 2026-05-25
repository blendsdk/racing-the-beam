# Atari 2600 Masterclass — Implementation Plan

> **Feature**: Complete 61+ lesson Atari 2600 programming masterclass with VitePress documentation site
> **Status**: Planning Complete
> **Created**: 2026-05-26
> **CodeOps Version**: N/A (educational project)

## Overview

A comprehensive, zero-to-mastery Atari 2600 programming course built as a VitePress documentation site. The student is a TypeScript developer who programmed C64 30+ years ago but has forgotten 6502 assembly. The course covers everything from binary/hex number systems through advanced homebrew techniques (DPC+, bankswitching, illegal opcodes), culminating in multiple capstone game projects and groundwork for a future DSL/code generator.

Each lesson consists of a theory document (VitePress markdown with TypeScript analogies), a standalone buildable `.asm` source file, exercises with hints, and solution files. Interactive Vue components provide reference tools (color picker, 6502 instruction table, TIA register browser).

The course is strictly linear — each lesson builds on the previous — and uses NTSC as the primary standard with PAL notes where timing differs.

## Document Index

| # | Document | Description |
|---|----------|-------------|
| AR | [Ambiguity Register](00-ambiguity-register.md) | Zero-Ambiguity Gate decisions (audit trail) |
| 00 | [Index](00-index.md) | This document — overview and navigation |
| 01 | [Requirements](01-requirements.md) | Feature requirements and scope |
| 02 | [Current State](02-current-state.md) | Analysis of current project |
| 03 | [VitePress Setup](03-vitepress-setup.md) | VitePress project configuration and interactive components |
| 04 | [Lesson Curriculum](04-lesson-curriculum.md) | Complete 61+ lesson list across 10 parts |
| 05 | [Lesson Format](05-lesson-format.md) | Template and format spec for each lesson |
| 06 | [Reference Materials](06-reference-materials.md) | Cheat sheets, color chart, register references |
| 07 | [Testing Strategy](07-testing-strategy.md) | Build verification for all lessons |
| 99 | [Execution Plan](99-execution-plan.md) | Phased execution with task checklist |

## Quick Reference

### Usage

```bash
# Build and serve documentation
npm run docs:dev

# Build a specific lesson
make lesson L=part0/01

# Run a lesson in Stella
make run-lesson L=part0/01

# Build all lessons
make all-lessons
```

### Key Decisions

| Decision | Outcome | AR Ref |
|----------|---------|--------|
| TV Standard | NTSC primary, PAL inline notes | Q1 |
| Lesson format | .asm + .md + exercises + solutions | Q2 |
| Depth | All the way to modern homebrew mastery | Q3 |
| DSL path | Build toward DSL throughout curriculum | Q5 |
| 6502 teaching | Ultra-thorough with reference doc + cheat sheet | Q6 |
| TS analogies | Collapsible sections, medium density | AR-7 |
| VitePress | Same repo, local dev, Atari-themed | Q15, AR-14 |
| Interactive components | Color picker, 6502 ref, TIA ref | Q17 |
| Lesson structure | Strictly linear | AR-10 |
| Code inclusion | `<<<` imports from actual .asm files | AR-5 |

## Related Files

### Existing (from starter project)
- `include/vcs.asm` — Hardware register definitions
- `include/macro.asm` — Common macros
- `src/main.asm` — Starter rainbow ROM
- `Makefile` — Build system

### To Be Created
- `docs/` — VitePress site (config, theme, lessons, components)
- `lessons/` — All lesson `.asm` source files organized by part
- `docs/.vitepress/` — VitePress configuration and Vue components
- `docs/reference/` — Cheat sheets and reference pages
