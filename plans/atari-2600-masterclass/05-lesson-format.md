# Lesson Format: Atari 2600 Masterclass

> **Document**: 05-lesson-format.md
> **Parent**: [Index](00-index.md)

## Overview

Every lesson follows a consistent format to ensure predictable structure and maximum learning value. This document defines the templates for both the VitePress markdown theory document and the assembly source file.

## Directory Structure Per Lesson

> **Decision per AR-2:** Grouped by part.
> **Decision per AR-3:** Solutions in same directory.
> **Decision per AR-4:** Descriptive file names.

```
lessons/partN-name/NN-lesson-name/
├── NN-lesson-name.asm              # Main lesson source (buildable ROM)
├── exercise-01-solution.asm        # Solution for exercise 1
├── exercise-02-solution.asm        # Solution for exercise 2
└── exercise-03-solution.asm        # Solution for exercise 3
```

Example:
```
lessons/part1-6502-cpu/04-registers-and-memory/
├── 04-registers-and-memory.asm
├── exercise-01-solution.asm
├── exercise-02-solution.asm
└── exercise-03-solution.asm
```

## VitePress Markdown Template

> **Decision per AR-6:** PAL notes as inline `:::tip` callouts.
> **Decision per AR-7:** TypeScript analogies as collapsible `:::details` sections.
> **Decision per AR-8:** Exercises with challenge → hints → expected result.

```markdown
---
title: "Lesson NN: Title"
description: "One-line description"
prev:
  text: "Lesson NN-1: Previous Title"
  link: "/partN-name/NN-1-previous"
next:
  text: "Lesson NN+1: Next Title"
  link: "/partN-name/NN+1-next"
---

# Lesson NN: Title

> **Part N** · Estimated time: XX minutes
> **Prerequisites:** Lesson NN-1
> **You will learn:** Concept 1, Concept 2, Concept 3
> **You will build:** Description of the ROM you'll create

## Introduction

[2-3 paragraphs explaining WHAT this lesson covers and WHY it matters.
Connect to the bigger picture — how does this help you build games?]

:::details TypeScript Equivalent
[Show the TypeScript way of doing what this lesson teaches.
This helps bridge existing knowledge to assembly concepts.]
```typescript
// TypeScript equivalent of the assembly concept
const value: number = 0xFF;
const masked = value & 0x0F; // Lower nibble
```
:::

## Theory

### Section 1: [Concept Name]

[Explanation with diagrams, tables, examples.]

:::tip PAL Note
[When timing or values differ for PAL, note it here.]
For PAL: use XX scanlines instead of YY. Timer value: ZZ instead of WW.
:::

### Section 2: [Concept Name]

[More explanation.]

:::details TypeScript Equivalent
[TS comparison for this specific concept.]
:::

### Section 3: [Concept Name]

[Continue as needed.]

## The Code

### Building This Lesson

```bash
make lesson L=partN/NN
make run-lesson L=partN/NN
```

### Full Source

<<< @/lessons/partN-name/NN-lesson-name/NN-lesson-name.asm{asm}

### Code Walkthrough

[Step through the important sections of the code, explaining
each part. Reference specific line numbers or regions.]

#### Section: [Name]

<<< @/lessons/partN-name/NN-lesson-name/NN-lesson-name.asm#section-name{asm}

[Explain what this section does and why.]

## What You Should See

[Describe what the student should see in Stella when they run the ROM.
Be specific: "You should see a blue background with a white
horizontal stripe across the middle of the screen."]

## Exercises

### Exercise 1: [Title]

**Challenge:** [Clear description of what to do]

**Hints:**
1. [First hint — gentle nudge in the right direction]
2. [Second hint — more specific guidance]
3. [Third hint — almost the answer]

**Expected Result:** [What the student should see/verify when done correctly]

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: [Title]

**Challenge:** [...]

**Hints:**
1. [...]
2. [...]

**Expected Result:** [...]

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: [Title] *(Stretch Goal)*

**Challenge:** [A harder exercise that goes slightly beyond the lesson]

**Hints:**
1. [...]

**Expected Result:** [...]

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ [Key point 1 — what to remember]
- ✅ [Key point 2]
- ✅ [Key point 3]

## What's Next

[1-2 sentences previewing the next lesson and how it builds on this one.]
```

## Assembly Source Template

```asm
; =============================================================================
; LESSON NN: Title
; =============================================================================
; Part N: Part Name
;
; What this program does:
;   [Description of the ROM behavior]
;
; What you'll learn:
;   - Concept 1
;   - Concept 2
;   - Concept 3
;
; Build: make lesson L=partN/NN
; Run:   make run-lesson L=partN/NN
;
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES
; =============================================================================

Variable1   = $80       ; Description of variable
Variable2   = $81       ; Description of variable

; =============================================================================
; ROM START
; =============================================================================

    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start

; =============================================================================
; MAIN LOOP
; =============================================================================

StartFrame:

; --- VSYNC (3 scanlines) ---
    +vsync

; --- VBLANK (37 scanlines) ---
    LDA #$02
    STA VBLANK
    +set_timer 43

    ; === GAME LOGIC ===
    ; [Lesson-specific logic here, heavily commented]
    ; === END GAME LOGIC ===

    +wait_timer
    LDA #$00
    STA VBLANK

; --- KERNEL (192 visible scanlines) ---
; #region kernel
    ; [Lesson-specific kernel here, heavily commented]
    ; Every instruction explained:
    ;   LDA #$1A    ; Load color $1A (orange, luminance 5)    [2 cycles]
    ;   STA COLUBK  ; Set background color                    [3 cycles]
    ;   STA WSYNC   ; Wait for end of scanline                [3+ cycles]
; #endregion kernel

; --- OVERSCAN (30 scanlines) ---
    LDA #$02
    STA VBLANK
    +set_timer 35

    ; === ADDITIONAL LOGIC ===
    ; === END ADDITIONAL LOGIC ===

    +wait_timer

    JMP StartFrame

; =============================================================================
; DATA TABLES
; =============================================================================
; [Lesson-specific data, if any]

; =============================================================================
; VECTORS
; =============================================================================

    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

## Exercise Solution Template

```asm
; =============================================================================
; LESSON NN - EXERCISE X SOLUTION: Title
; =============================================================================
; Challenge: [Repeat the challenge description]
; Solution:  [Brief description of the approach]
;
; Build: make lesson L=partN/NN-exX
;        (or copy this file to NN-lesson-name.asm and rebuild)
; =============================================================================

    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; [Complete solution code]
```

## Makefile Conventions

> **Decision per AR-15:** `make lesson L=part0/01` format.

```makefile
# Build a specific lesson
# Usage: make lesson L=part0/01
lesson:
	@mkdir -p build
	acme -f plain -o build/lesson.bin \
		lessons/$(L)-*/$(shell echo $(L) | grep -oP '\d+$$')-*.asm
	@echo "Built build/lesson.bin"

# Run a specific lesson
run-lesson: lesson
	stella build/lesson.bin &
```

## Naming Conventions

| Item | Convention | Example |
|------|-----------|---------|
| Part directory | `partN-kebab-name` | `part1-6502-cpu` |
| Lesson directory | `NN-kebab-name` | `04-registers-and-memory` |
| Main ASM file | `NN-kebab-name.asm` | `04-registers-and-memory.asm` |
| Solution files | `exercise-NN-solution.asm` | `exercise-01-solution.asm` |
| VitePress markdown | `NN-kebab-name.md` | `04-registers-and-memory.md` |
| Part index | `index.md` | `index.md` |
| Code regions | `; #region name` / `; #endregion name` | `; #region kernel` |
