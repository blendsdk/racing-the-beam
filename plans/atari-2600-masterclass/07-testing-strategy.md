# Testing Strategy: Atari 2600 Masterclass

> **Document**: 07-testing-strategy.md
> **Parent**: [Index](00-index.md)

## Testing Overview

This is an educational project, not a software product. "Testing" means verifying that all lesson materials are correct, buildable, and functional.

> **Decision per AR-20:** Compilation + ROM size check.

### Verification Goals

- All `.asm` lesson files compile without warnings
- All ROMs are correct size (4096 bytes for standard 4KB, documented exceptions for bankswitching)
- VitePress builds without errors
- All `<<<` file imports resolve
- All Vue components render without console errors

## Verification Methods

### 1. Assembly Build Verification

Each lesson `.asm` file must compile with ACME assembler without warnings or errors.

**Automated check (Makefile target):**
```makefile
verify-lessons:
	@echo "=== Verifying all lessons ==="
	@PASS=0; FAIL=0; \
	for asm in lessons/*/*/*.asm; do \
		if acme -f plain -o /tmp/test.bin "$$asm" 2>/dev/null; then \
			SIZE=$$(wc -c < /tmp/test.bin); \
			if [ "$$SIZE" -eq 4096 ]; then \
				PASS=$$((PASS+1)); \
			else \
				echo "WARN: $$asm — $$SIZE bytes (expected 4096)"; \
				PASS=$$((PASS+1)); \
			fi; \
		else \
			echo "FAIL: $$asm"; \
			FAIL=$$((FAIL+1)); \
		fi; \
	done; \
	echo "=== $$PASS passed, $$FAIL failed ==="
```

### 2. VitePress Build Verification

```bash
npm run docs:build
```

Must exit with code 0 and no errors.

### 3. Vue Component Verification

Manual check: open VitePress dev server, navigate to each reference page, verify:
- ColorPicker renders 128 colors in a grid
- InstructionRef shows searchable instruction table
- TIARegRef shows register details with bit diagrams

## Specification Test Cases

> These verify the core educational requirements are met.

| # | Test | Expected Result | Source |
|---|------|----------------|--------|
| ST-1 | Compile lesson 01 | 0 warnings, 4096 bytes | 01-requirements.md: "All .asm files must compile" |
| ST-2 | Compile all 61 lessons | 0 warnings each, correct sizes | 01-requirements.md: "All 61+ lesson .asm files compile" |
| ST-3 | Build VitePress site | Exit code 0, no errors | 03-vitepress-setup.md: "VitePress builds without errors" |
| ST-4 | All `<<<` imports resolve | No missing file errors during build | AR-5: "Import from actual .asm files" |
| ST-5 | Lesson 58 (Pong) is playable | ROM loads in Stella, paddles move, ball bounces | AR-16: "Full — 2 paddles, score, sound" |
| ST-6 | Lesson 59 (Breakout) is playable | ROM loads, bricks break, score works | AR-17: "Breakout" |
| ST-7 | Lesson 60 (Maze) is playable | ROM loads, rooms transition, items collectable | AR-18: "Maze game" |
| ST-8 | ColorPicker shows 128 colors | Grid renders, click copies hex value | AR-11: "Interactive grid with click-to-copy" |
| ST-9 | InstructionRef is searchable | Filter by mnemonic/category works | AR-12: "Searchable/filterable table" |
| ST-10 | TIARegRef shows bit diagrams | Register details with 8-bit diagrams visible | AR-13: "Searchable with bit-field diagrams" |
| ST-11 | Exercises have solutions | Each lesson dir contains exercise-*-solution.asm | AR-3/AR-8 |
| ST-12 | Solution files compile | All solution .asm files compile without warnings | 01-requirements.md |

## Verification Checklist (per lesson)

When creating each lesson, verify:

- [ ] `.asm` file compiles with `acme -f plain` — 0 warnings
- [ ] ROM is 4096 bytes (or documented exception)
- [ ] ROM runs in Stella without crash
- [ ] `.md` file has all template sections (intro, theory, code, exercises, takeaways)
- [ ] TypeScript analogy present (collapsible section)
- [ ] At least 2 exercises with hints and expected results
- [ ] Solution `.asm` files present and compile
- [ ] PAL notes included where timing differs
- [ ] Code regions (`#region`/`#endregion`) match `<<<` imports in markdown
- [ ] Previous/next navigation links correct

## Verification Checklist (final)

- [ ] All 61 lesson .asm files compile without warnings
- [ ] All solution .asm files compile without warnings
- [ ] All ROMs correct size
- [ ] VitePress builds without errors (`npm run docs:build`)
- [ ] All Vue components render
- [ ] All 4 capstone ROMs are playable in Stella
- [ ] Strictly linear — no forward references to untaught concepts
- [ ] `make verify-lessons` passes all checks
