# Current State: Atari 2600 Masterclass

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

### What Exists

A minimal starter project with a working rainbow ROM and build system:

```
2600/
├── .gitignore
├── .vscode/settings.json
├── Makefile                    # Build system (make / make run / make clean)
├── README.md                   # Quick-start guide
├── build/
│   └── game.bin                # Compiled ROM (4096 bytes)
├── include/
│   ├── macro.asm               # Helper macros (clean_start, vsync, set_timer, wait_timer)
│   └── vcs.asm                 # TIA + RIOT register definitions (heavily commented)
└── src/
    └── main.asm                # Rainbow background demo ROM
```

### Relevant Files

| File | Purpose | Changes Needed |
|------|---------|----------------|
| `include/vcs.asm` | TIA + RIOT register definitions | Keep as-is — becomes the foundation include |
| `include/macro.asm` | Common macros | Will grow with new macros as lessons progress |
| `src/main.asm` | Starter rainbow ROM | Stays as starter; lessons get their own files |
| `Makefile` | Build system | Extend with per-lesson targets and VitePress commands |
| `README.md` | Quick start guide | Update to reference VitePress site |
| `.vscode/settings.json` | Editor config | May need VitePress/Vue file associations |
| `.gitignore` | Git ignores | Add `node_modules/`, `docs/.vitepress/dist/`, `docs/.vitepress/cache/` |

### Code Analysis

**`include/vcs.asm`** — Comprehensive and well-commented. Covers all TIA write registers ($00-$2C), TIA read registers ($00-$0D), and RIOT registers ($0280-$0297). Ready for use as-is.

**`include/macro.asm`** — Contains 4 macros:
- `+clean_start` — Zeros RAM and TIA, sets stack pointer
- `+vsync` — 3-scanline VSYNC signal
- `+set_timer .ticks` — Sets RIOT timer (64-cycle intervals)
- `+wait_timer` — Busy-waits for timer expiry

These form the foundation. New macros will be added in later lessons (e.g., `+position_sprite`, `+draw_score`, `+play_sound`).

**`src/main.asm`** — Complete NTSC frame loop with rainbow gradient. Demonstrates: clean start, VSYNC, VBLANK with timer, 192-line kernel, overscan, proper vectors. Well-commented with explanations of why each step exists.

**`Makefile`** — Simple: `make` builds, `make run` launches Stella, `make clean` removes build artifacts. Needs extension for per-lesson builds.

## Gaps Identified

### Gap 1: No VitePress Site

**Current Behavior:** Documentation is a single README.md
**Required Behavior:** Full VitePress site with lessons, navigation, interactive components
**Fix Required:** Initialize VitePress project in `docs/` directory

### Gap 2: No Lesson Structure

**Current Behavior:** Single starter ROM in `src/main.asm`
**Required Behavior:** 60+ organized lessons in `lessons/` directory, grouped by part
**Fix Required:** Create directory structure per AR-2

### Gap 3: No Interactive Reference Tools

**Current Behavior:** Register definitions only in `.asm` comments
**Required Behavior:** Searchable Vue components for colors, 6502 instructions, TIA registers
**Fix Required:** Create Vue components in `docs/.vitepress/components/`

### Gap 4: Makefile Only Builds One ROM

**Current Behavior:** `make` builds `src/main.asm` only
**Required Behavior:** `make lesson L=part0/01` builds any lesson
**Fix Required:** Extend Makefile with lesson targets per AR-15

### Gap 5: No Exercises

**Current Behavior:** No exercises exist
**Required Behavior:** Each lesson has structured exercises with hints and solutions per AR-8
**Fix Required:** Create exercise sections in lesson `.md` files + solution `.asm` files per AR-3

## Dependencies

### Internal Dependencies

- `include/vcs.asm` — All lessons depend on this
- `include/macro.asm` — Most lessons depend on this (grows over time)
- Lessons are strictly linear — each depends on all previous lessons

### External Dependencies

- ACME assembler v0.97+ ✅ (installed)
- Stella emulator ✅ (installed)
- Node.js + npm (needed for VitePress — **must verify**)
- VitePress 1.x stable (to be installed)

## Risks and Concerns

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| ACME syntax doesn't support a feature needed in advanced lessons | Low | Medium | ACME 0.97 is mature and covers all needed 6502 features |
| VitePress Shiki doesn't have 6502 assembly syntax highlighting | Medium | Low | Can configure custom grammar or use `asm` generic highlighting |
| 60+ lessons exceeds context window for single-session creation | High | Medium | Execute in phases, 3-5 lessons per session |
| Student finds pace too slow in early lessons | Low | Low | Lessons can be skimmed; linear doesn't mean mandatory for experienced topics |
| Node.js not installed | Low | Medium | Student is TypeScript dev — almost certainly has Node.js |
