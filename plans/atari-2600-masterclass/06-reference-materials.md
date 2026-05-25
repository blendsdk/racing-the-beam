# Reference Materials: Atari 2600 Masterclass

> **Document**: 06-reference-materials.md
> **Parent**: [Index](00-index.md)

## Overview

Reference materials are VitePress pages in `docs/reference/` that serve as ongoing lookup tools throughout the course. They include static pages and interactive Vue components.

## Reference Pages

### 1. Color Chart (`docs/reference/color-chart.md`)

> **Decision per AR-11:** Interactive grid with click-to-copy.

**Content:**
- Brief explanation of NTSC color encoding (CCCCLLL0)
- `<ColorPicker />` Vue component (128-color grid)
- Color groupings with hue names:
  - $0x: Gray/White
  - $1x: Gold/Yellow
  - $2x: Orange
  - $3x: Red-Orange
  - $4x: Pink/Red
  - $5x: Purple
  - $6x: Blue-Purple
  - $7x: Blue
  - $8x: Light Blue
  - $9x: Turquoise
  - $Ax: Green-Blue
  - $Bx: Green
  - $Cx: Yellow-Green
  - $Dx: Orange-Green
  - $Ex: Light Orange
  - $Fx: Light Yellow
- PAL color differences noted
- Common color combinations for games (sky + ground, sprite colors that stand out)

### 2. 6502 Instruction Reference (`docs/reference/6502-instructions.md`)

> **Decision per AR-12:** Searchable/filterable table.

**Content:**
- Brief intro to 6502 instruction format
- `<InstructionRef />` Vue component
- Instruction categories:
  - **Load/Store:** LDA, LDX, LDY, STA, STX, STY
  - **Arithmetic:** ADC, SBC, INC, DEC, INX, INY, DEX, DEY
  - **Logic:** AND, ORA, EOR, BIT
  - **Shift/Rotate:** ASL, LSR, ROL, ROR
  - **Branch:** BEQ, BNE, BCS, BCC, BMI, BPL, BVS, BVC
  - **Jump:** JMP, JSR, RTS, RTI, BRK
  - **Stack:** PHA, PLA, PHP, PLP, TXS, TSX
  - **Status:** CLC, SEC, CLD, SED, CLI, SEI, CLV
  - **Transfer:** TAX, TAY, TXA, TYA
  - **Other:** NOP
  - **Illegal (commonly used):** LAX, SAX, DCP, ISC, SLO, RLA, SRE, RRA
- Per instruction: mnemonic, full name, operation description, flags affected, all addressing modes with opcode/bytes/cycles
- Page-crossing penalty notes

### 3. TIA Register Reference (`docs/reference/tia-registers.md`)

> **Decision per AR-13:** Searchable with bit-field diagrams.

**Content:**
- Brief intro to TIA architecture
- `<TIARegRef />` Vue component
- Register groups:
  - **Sync/Blank:** VSYNC, VBLANK, WSYNC, RSYNC
  - **Color:** COLUP0, COLUP1, COLUPF, COLUBK
  - **Playfield:** PF0, PF1, PF2, CTRLPF
  - **Player:** GRP0, GRP1, REFP0, REFP1, NUSIZ0, NUSIZ1
  - **Position:** RESP0, RESP1, RESM0, RESM1, RESBL
  - **Motion:** HMP0, HMP1, HMM0, HMM1, HMBL, HMOVE, HMCLR
  - **Missile/Ball:** ENAM0, ENAM1, ENABL, RESMP0, RESMP1
  - **Delay:** VDELP0, VDELP1, VDELBL
  - **Audio:** AUDC0, AUDC1, AUDF0, AUDF1, AUDV0, AUDV1
  - **Collision (read):** CXM0P, CXM1P, CXP0FB, CXP1FB, CXM0FB, CXM1FB, CXBLPF, CXPPMM, CXCLR
  - **Input (read):** INPT0-INPT5
  - **RIOT:** SWCHA, SWACNT, SWCHB, SWBCNT, INTIM, INSTAT, TIM1T, TIM8T, TIM64T, T1024T
- Per register: name, address, R/W, 8-bit diagram, bit descriptions, usage example, cross-references

### 4. Cheat Sheet (`docs/reference/cheat-sheet.md`)

> **Decision per AR-9:** VitePress page (searchable).

**Content:**
- **Memory Map** — compact table: $00-$3F TIA, $80-$FF RAM, $0280-$0297 RIOT, $F000-$FFFF ROM
- **Frame Structure** — 3+37+192+30 = 262 scanlines, timing values
- **Common Timer Values** — VBLANK=43, overscan=35 (TIM64T)
- **Cycle Counts** — most-used instructions with cycle counts
- **Color Encoding** — CCCCLLL0 format
- **Joystick Bits** — SWCHA bit mapping for P0/P1
- **Console Switches** — SWCHB bit mapping
- **NUSIZ Values** — table of all 8 player copy/size modes
- **Horizontal Positioning** — divide-by-15 formula, fine position values
- **HMOVE Values** — signed 4-bit motion values ($00-$70, $80-$F0)
- **ACME Quick Reference** — common directives (!byte, !word, !source, !macro, !to, *, !cpu)
- **Stella Debugger** — key shortcuts

### 5. Glossary (`docs/reference/glossary.md`)

**Content:** Alphabetical definitions of all 2600-specific terms:
- Accumulator, Address Bus, Asymmetric Playfield, Ball, Bankswitching, BCD, Beam Racing, CDFJ, Clean Start, Collision, Color Clock, CRT, DPC, DPC+, EEPROM, Fine Positioning, Flicker, Frame, GRP, Harmony, HBLANK, HMOVE, Horizontal Motion, Illegal Opcode, Interlace, IRQ, Kernel, LFSR, Luminance, Missile, NMI, NUSIZ, NTSC, Overscan, PAL, Page Crossing, Playfield, Player, PlusCart, RIOT, ROM, Scanline, Score Mode, Sprite, Stack, Superchip, TIA, Timer, Two-Line Kernel, VBLANK, VDEL, Vertical Delay, VSYNC, WSYNC, Zero Page

## Vue Component Data Files

All component data is stored as static TypeScript files:

```
docs/.vitepress/theme/
├── data/
│   ├── ntsc-colors.ts      # 128 NTSC colors: hex, RGB, hue name, lum level
│   ├── pal-colors.ts       # 104 PAL colors: same structure
│   ├── instructions.ts     # 56 official + illegal 6502 instructions
│   └── tia-registers.ts    # All TIA + RIOT registers with bit fields
```

### Data Format Examples

```typescript
// ntsc-colors.ts
export interface NTSCColor {
  hex: string;        // "$1A"
  value: number;      // 0x1A
  rgb: string;        // "#D4A017"
  hue: string;        // "Gold"
  hueIndex: number;   // 1
  luminance: number;  // 5
}

// instructions.ts
export interface Instruction {
  mnemonic: string;       // "LDA"
  name: string;           // "Load Accumulator"
  category: string;       // "Load/Store"
  operation: string;      // "A ← M"
  flags: string;          // "N Z"
  illegal: boolean;       // false
  modes: AddressingMode[];
}

// tia-registers.ts
export interface TIARegister {
  name: string;           // "COLUBK"
  address: number;        // 0x09
  type: 'write' | 'read';
  chip: 'TIA' | 'RIOT';
  bits: BitField[];
  description: string;
  example: string;
  related: string[];      // ["COLUP0", "COLUPF"]
}
```
