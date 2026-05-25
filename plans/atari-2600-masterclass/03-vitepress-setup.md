# VitePress Setup: Atari 2600 Masterclass

> **Document**: 03-vitepress-setup.md
> **Parent**: [Index](00-index.md)

## Overview

The masterclass is delivered as a VitePress static documentation site. The site lives in the `docs/` directory of the same repository as the lesson source code, and includes custom Vue components for interactive reference tools.

> **Decision per AR-14:** Local development only — no deployment pipeline.
> **Decision per AR-5:** Lesson code is included via `<<<` file imports from `.asm` source files.

## Architecture

### Directory Structure

```
docs/
├── .vitepress/
│   ├── config.ts               # VitePress configuration
│   ├── theme/
│   │   ├── index.ts            # Theme setup (extends default)
│   │   ├── custom.css          # Atari-inspired accent colors
│   │   └── components/
│   │       ├── ColorPicker.vue     # NTSC 128-color interactive grid
│   │       ├── InstructionRef.vue  # 6502 instruction searchable table
│   │       └── TIARegRef.vue       # TIA register reference with bit diagrams
│   └── cache/                  # (gitignored)
├── index.md                    # Course home page
├── getting-started.md          # Setup instructions (ACME, Stella, project)
├── part0-foundations/
│   ├── index.md                # Part 0 overview
│   ├── 01-number-systems.md
│   ├── 02-stella-debugger.md
│   └── 03-anatomy-of-2600.md
├── part1-6502-cpu/
│   ├── index.md
│   ├── 01-registers-and-memory.md
│   ├── ... (8 lessons)
│   └── 08-lookup-tables.md
├── ... (parts 2-9)
├── part10-capstones/
│   ├── index.md
│   ├── 01-pong.md
│   ├── 02-breakout.md
│   ├── 03-maze-game.md
│   └── 04-your-game.md
└── reference/
    ├── color-chart.md          # Uses <ColorPicker /> component
    ├── 6502-instructions.md    # Uses <InstructionRef /> component
    ├── tia-registers.md        # Uses <TIARegRef /> component
    ├── cheat-sheet.md          # Quick reference card
    └── glossary.md             # Terms and definitions
```

### VitePress Configuration

```typescript
// docs/.vitepress/config.ts
import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Atari 2600 Masterclass',
  description: 'From zero to homebrew mastery',
  base: '/',
  
  themeConfig: {
    // Sidebar auto-generated from directory structure
    sidebar: [/* ... generated from parts ... */],
    
    // Top navigation
    nav: [
      { text: 'Lessons', link: '/part0-foundations/' },
      { text: 'Reference', link: '/reference/color-chart' },
    ],
    
    // Search
    search: { provider: 'local' },
    
    // Social links
    socialLinks: [
      { icon: 'github', link: 'https://github.com/...' }
    ],
  },
  
  // Markdown configuration
  markdown: {
    lineNumbers: true,  // Show line numbers in code blocks
  },
})
```

### Theme Customization

> **Decision per Q18:** Default VitePress theme with Atari-inspired accent colors.

```css
/* docs/.vitepress/theme/custom.css */
:root {
  /* Atari-inspired orange/red accent */
  --vp-c-brand-1: #e85d04;   /* Atari orange */
  --vp-c-brand-2: #dc2f02;   /* Atari red */
  --vp-c-brand-3: #f48c06;   /* Atari gold */
  
  /* Dark mode default (retro feel) */
  --vp-c-bg: #1a1a2e;
}
```

## Interactive Components

### Component 1: ColorPicker.vue

> **Decision per AR-11:** Interactive grid with click-to-copy hex values.

**Purpose:** Display all 128 NTSC colors in a grid. Clicking a color copies its hex value.

**Features:**
- 16×8 grid (16 hues × 8 luminances)
- Hover shows: hex value, hue name, luminance level
- Click copies `$XX` format to clipboard
- Visual feedback on copy
- Labels for hue rows and luminance columns

**Data source:** Static array of 128 color entries with hex value, RGB equivalent, and hue/lum names.

### Component 2: InstructionRef.vue

> **Decision per AR-12:** Searchable/filterable table.

**Purpose:** Complete 6502 instruction set reference.

**Features:**
- Search box: filter by mnemonic, description, or category
- Category filter: Load/Store, Arithmetic, Logic, Branch, Jump, Stack, Status, NOP
- Columns: Mnemonic, Name, Operation, Flags Affected, Addressing Modes, Cycles
- Expandable rows showing all addressing modes with opcodes and byte counts
- Sort by mnemonic or cycles

**Data source:** Static JSON with all 56 official 6502 instructions + commonly used illegal opcodes.

### Component 3: TIARegRef.vue

> **Decision per AR-13:** Searchable with bit-field diagrams.

**Purpose:** TIA and RIOT register reference with visual bit-field diagrams.

**Features:**
- Search by register name or address
- Filter: TIA Write / TIA Read / RIOT
- Each register shows:
  - Name, address, read/write
  - 8-bit diagram showing bit assignments
  - Description of each bit/field
  - Usage example
- Linked cross-references (e.g., COLUBK links to color picker)

**Data source:** Static JSON derived from `include/vcs.asm`.

## Code Snippet Integration

> **Decision per AR-5:** Import `.asm` files directly using VitePress code snippets.

Lesson markdown files reference source code like this:

```markdown
## The Complete Code

Here's the full lesson source:

<<< @/lessons/part0-foundations/01-number-systems/01-number-systems.asm{asm}

### Key Section: The Loop

Just the loop portion:

<<< @/lessons/part0-foundations/01-number-systems/01-number-systems.asm#loop{asm}
```

The `.asm` files use region markers for partial includes:

```asm
; #region loop
.my_loop:
    DEX
    BNE .my_loop
; #endregion loop
```

## Build Integration

### package.json scripts

```json
{
  "scripts": {
    "docs:dev": "vitepress dev docs",
    "docs:build": "vitepress build docs",
    "docs:preview": "vitepress preview docs"
  }
}
```

### Makefile integration

```makefile
# VitePress commands
docs:
	npm run docs:dev

docs-build:
	npm run docs:build
```

## Error Handling

| Error Case | Handling Strategy |
|------------|-------------------|
| Missing `.asm` file referenced in markdown | VitePress build fails with clear error pointing to the missing file |
| Syntax highlighting not available for `asm` | Falls back to plain text; can register custom Shiki grammar |
| Vue component data file missing | Component shows error state with message |
| Node.js not installed | README documents prerequisite; `make docs` checks for `npm` |

## Testing Requirements

- VitePress builds without errors: `npm run docs:build`
- All `<<<` file imports resolve correctly
- All three Vue components render without console errors
- Local dev server starts and all pages are navigable
- Search indexes all lesson content
