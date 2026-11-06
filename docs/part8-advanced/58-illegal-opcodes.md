---
title: "Lesson 58: Illegal Opcodes — Undocumented Power"
description: "Run the four stable undocumented NMOS 6502 instructions — LAX, SAX, DCP and ISB — in 'the opcode laboratory', compare their cycle counts with the documented equivalents, and learn why ACME's !cpu 6502 mode needs !byte macros (its 6510 mode accepts the mnemonics) and why the 65C02 is different."
prev:
  text: "Lesson 57: Superchip — Extra RAM"
  link: "/part8-advanced/57-superchip"
next:
  text: "Lesson 59: Self-Modifying Code — The Ultimate 6502 Trick"
  link: "/part8-advanced/59-self-modifying-code"
---

# Lesson 58: Illegal Opcodes — Undocumented Power

> **Part 8: Advanced Topics** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 04 (registers and memory), Lesson 06 (flags and comparisons), Lesson 07 (branches and loops), Lesson 09 (bitwise operations), Lesson 10 (addressing modes), Lesson 17 (cycle counting), Lesson 25 (player basics)
> **You will learn:** what an "illegal" opcode really is on the NMOS 6502; which undocumented instructions are stable and which are not; the exact operation, flags, byte, and cycle count of LAX, SAX, DCP, and ISB; how much they save over the documented sequences; why ACME 0.97's !cpu 6502 mode rejects the mnemonics while its 6510 mode accepts them (LAX, SAX, DCP, and ISC for ISB); why the 65C02 is not a drop-in target; and the safety rules that keep undocumented code readable
> **You will build:** "the opcode laboratory" — a 4,096-byte ROM that runs the four stable operations once per frame on known inputs, stores the results, the processor flags, and a checksum in RAM, and draws a 192-line instrument panel; SELECT switches to a second screen with the documented-versus-illegal cycle table for eight stable opcodes; plus three 4,096-byte exercise solutions

## Introduction

Lesson 57 put 128 bytes of RAM inside the cartridge. This lesson goes inside the **processor**. The 6507 in the Atari 2600 is an NMOS 6502 die in a smaller package, and the 6502's opcode matrix has 256 entries. The official instruction set fills about 151 of them. The rest are not empty: the silicon decodes them, executes them, and sets flags. The community calls them **undocumented** or **illegal** opcodes. They are not illegal in the sense of a trap or an exception — a real NMOS 6502 simply runs them.

The undocumented group is not uniform. A small set — LAX, SAX, DCP, ISB, SLO, RLA, SRE, RRA — behaves the same on every NMOS 6502 and 6507 die. Those are the **stable** opcodes, and they are useful: LAX loads A and X from one memory byte, SAX stores A AND X, DCP decrements and compares, ISB increments and subtracts. Each one replaces a two- or three-instruction sequence and saves cycles. A second group — ANE, LXA, SHA, SHX, SHY, TAS, LAS, and the KIL/JAM group — can depend on the data bus, the high byte of the address, the temperature, or the individual chip. Those are **unstable**, and this lesson does not use them.

The companion program `58-illegal-opcodes.asm` is **the opcode laboratory**. It runs the four stable operations once per frame on fixed inputs, stores the result bytes, the live P register, and an XOR checksum in RAM, and draws the results as playfield bars. SELECT switches to a second screen that draws the cycle table: the documented sequence versus the illegal instruction for eight stable opcodes. The source cannot write `LAX $90` under `!cpu 6502` — ACME 0.97 rejects the mnemonic there, although its `!cpu 6510` mode accepts it — so four named macros emit the opcode bytes and the operand. That is not a hidden workaround; it is the honest toolchain answer, and it keeps the bytes visible for the lesson.

::: details TypeScript Equivalent

An undocumented opcode is a combined operation with a fixed cycle cost. In TypeScript the shape is a small CPU object:

```typescript
type Flags = { n: boolean; v: boolean; z: boolean; c: boolean };

class Cpu6502 {
  a = 0;
  x = 0;
  readonly mem = new Uint8Array(0x10000);
  readonly flags: Flags = { n: false, v: false, z: false, c: false };

  /** LAX zp ($A7): A = M, X = M; N and Z from M; 3 cycles. */
  lax(addr: number): void {
    this.a = this.x = this.mem[addr];
    this.flags.n = (this.a & 0x80) !== 0;
    this.flags.z = this.a === 0;
  }

  /** SAX zp ($87): M = A AND X; no flags; 3 cycles. */
  sax(addr: number): void {
    this.mem[addr] = this.a & this.x;
  }

  /** DCP zp ($C7): M = M - 1; then CMP A,M; 5 cycles. */
  dcp(addr: number): void {
    this.mem[addr] = (this.mem[addr] - 1) & 0xff;
    const diff = (this.a - this.mem[addr]) & 0x1ff;
    this.flags.c = this.a >= this.mem[addr];
    this.flags.z = this.a === this.mem[addr];
    this.flags.n = (diff & 0x80) !== 0;
  }

  /** ISB zp ($E7): M = M + 1; then SBC A,M; 5 cycles. */
  isb(addr: number): void {
    this.mem[addr] = (this.mem[addr] + 1) & 0xff;
    const borrow = this.flags.c ? 0 : 1;
    const result = (this.a - this.mem[addr] - borrow) & 0xff;
    this.flags.c = this.a >= this.mem[addr] + borrow;
    this.flags.z = result === 0;
    this.flags.n = (result & 0x80) !== 0;
    this.flags.v = ((this.a ^ this.mem[addr]) & (this.a ^ result) & 0x80) !== 0;
    this.a = result;
  }
}
```

The analogy breaks in the places that make the hardware interesting. The class documents every method and has no undefined states; the real opcodes are undocumented precisely because MOS never promised what they do. The `Flags` type is clean; the 6502's P register has a bit 5 that reads as 1 and a B bit that only exists in a pushed copy. The `mem` array is a flat 64K space; the 6507 exposes 13 address lines and mirrors the cartridge every 8K, and RIOT/TIA registers have read and write meanings at the same address. The `cycles` are not a cost model — they are the number of CPU clocks the die takes, which is what a scanline budget actually spends. And the 65C02 would need a different class: it does not implement these NMOS opcodes the same way.

:::

## Theory

### Section 1: What "Illegal" Really Means

The 6502 decodes an instruction in two steps: it fetches a byte, then uses that byte as an index into a 256-entry instruction decode table (a PLA and a decode ROM, not a microcoded engine). The official table covers the documented instructions. The remaining entries are not empty silicon — they decode to combinations of two documented operations. That is why the undocumented instructions are predictable on the NMOS die: they are not random behaviour, they are the chip's own building blocks wired together.

Two words matter:

| Word | What it means here |
|---|---|
| **undocumented** | MOS never published the opcode in the official data sheet. The instruction still exists on the die. |
| **illegal** | The community's nickname for the same group. It does **not** mean the CPU traps, faults, or refuses to run the byte. |

The 6507 is a 6502 with 13 address lines instead of 16 and no interrupt pins; it keeps the 8 data pins. The instruction set and timing are identical; the `atari-2600-expert` reference (`references/6502-cpu.md`) states plainly that the 6507 is a standard NMOS 6502 die and that undocumented opcodes work, and the Stella logs in this lesson are the observed evidence. That is the claim discipline for this lesson: **documented** for the die's identity, **observed** for the four operations' results in Stella, and **derived** for every cycle count (the documented instruction costs add up).

::: warning The 65C02 is not the same CPU
The 65C02 — the CMOS successor used in later machines and in the 65C816 — does not implement the NMOS undocumented opcodes the same way. Many of them became one-, two-, or three-byte NOPs; some opcode slots were reused for new instructions such as `BRA`, `PHX`, `PLX`, `STP`, and `WAI`. A ROM that relies on LAX or DCP is a ROM for the **NMOS 6502/6507**, not for a 65C02. Do not carry these instructions into portable code, and say so in the source comment when you use one.
:::

The stable group is small:

| Stable | Bytes (zp) | What it does |
|---|---|---|
| LAX | `$A7` | A = M, X = M |
| SAX | `$87` | M = A AND X |
| DCP | `$C7` | M = M − 1, then CMP A,M |
| ISB (ISC) | `$E7` | M = M + 1, then SBC A,M |
| SLO | `$07` | ASL M, then ORA M |
| RLA | `$27` | ROL M, then AND M |
| SRE | `$47` | LSR M, then EOR M |
| RRA | `$67` | ROR M, then ADC M |

The **unstable** group is the one to avoid: ANE (`$8B`), LXA (`$AB`), SHA (`$9F`/`$93`), SHX (`$9E`), SHY (`$9C`), TAS (`$9B`), LAS (`$BB`), and the KIL/JAM opcodes (`$02`, `$12`, `$22`, and relatives). Their results can depend on the value on the data bus during an unused cycle, the high byte of the address, the temperature, or the individual die. A lesson ROM must not use them, and neither should a game that has to run on a stranger's console.

### Section 2: The Four Operations

This is the table the lesson is built around. Every number is either documented (the official instruction costs) or derived (the sum of those costs); the lab measures the results in Stella.

| Mnemonic | Byte | Operation | Flags | Illegal cycles | Documented equivalent | Documented cycles |
|---|---|---|---|---|---|---|
| `LAX zp` | `$A7` | A = M; X = M | N, Z from M | 3 | `LDA zp` (3) + `TAX` (2) | 5 |
| `SAX zp` | `$87` | M = A AND X | none | 3 | `STX zp` (3) + `AND zp` (3) + `STA zp` (3) | 9 |
| `DCP zp` | `$C7` | M = M − 1; then CMP A,M (A − M) | N, Z, C | 5 | `DEC zp` (5) + `CMP zp` (3) | 8 |
| `ISB zp` | `$E7` | M = M + 1; then SBC A,M | N, V, Z, C | 5 | `INC zp` (5) + `SBC zp` (3) | 8 |

The four are easiest to remember as pairs:

- **LAX is a load pair.** The memory byte goes into both A and X. The flags are the ordinary load flags: N from bit 7, Z when the byte is zero.
- **SAX is a store of a mask.** It stores A AND X and changes no flags. If you have a mask in A and a value in X, SAX writes the masked value in one instruction.
- **DCP is a decrement-and-compare.** It is the countdown instruction: decrement the memory byte, then compare A with the new value. The flags are the CMP flags — C set when A ≥ M, Z set when A = M.
- **ISB is an increment-and-subtract.** It increments the memory byte, then performs SBC with the current carry. Set the carry first (`SEC` for a plain subtraction) and the flags are the ordinary SBC flags.

::: tip The SAX cycle count: 9, not 7
A common first sketch quotes 7 cycles for a mask sequence. That is the **immediate-mask** case: `TXA` (2) + `AND #mask` (2) + `STA zp` (3) = 7, which computes X AND a constant, not A AND X. When both registers are live, the exact documented equivalent of SAX is `STX zp` (3) + `AND zp` (3) + `STA zp` (3) = 9. If A must also be preserved, add `PHA`/`PLA` (3 + 4), so the documented sequence costs 16 cycles — a 13-cycle saving for SAX. The 7-cycle immediate form needs the mask as an immediate; it cannot take a second register. The lab uses 9 in its table because the lab's SAX has A = `$12` and X = `$34`; the lesson states the 7-cycle special case rather than hiding it.
:::

The four documented-example opcodes follow the same pattern, and the second screen draws their bars too:

| Mnemonic | Byte | Operation | Illegal cycles | Documented equivalent | Documented cycles |
|---|---|---|---|---|---|
| `SLO zp` | `$07` | ASL M; then ORA M | 5 | `ASL zp` (5) + `ORA zp` (3) | 8 |
| `RLA zp` | `$27` | ROL M; then AND M | 5 | `ROL zp` (5) + `AND zp` (3) | 8 |
| `SRE zp` | `$47` | LSR M; then EOR M | 5 | `LSR zp` (5) + `EOR zp` (3) | 8 |
| `RRA zp` | `$67` | ROR M; then ADC M | 5 | `ROR zp` (5) + `ADC zp` (3) | 8 |

### Section 3: The Cycle Saving in Context

A scanline is 76 CPU cycles. A kernel that draws one line per iteration has a fixed budget, and the difference between 8 and 5 cycles is the difference between fitting a second object and dropping it. The saving is real, but it is not free:

| Operation | Documented sequence | Cycles | Bytes | Illegal | Cycles | Bytes | Saved |
|---|---|---|---|---|---|---|---|
| LAX | `LDA zp` + `TAX` | 5 | 3 | `LAX zp` | 3 | 2 | 2 cycles, 1 byte |
| SAX | `STX zp` + `AND zp` + `STA zp` | 9 | 6 | `SAX zp` | 3 | 2 | 6 cycles, 4 bytes |
| DCP | `DEC zp` + `CMP zp` | 8 | 4 | `DCP zp` | 5 | 2 | 3 cycles, 2 bytes |
| ISB | `INC zp` + `SBC zp` | 8 | 4 | `ISB zp` | 5 | 2 | 3 cycles, 2 bytes |

The byte counts use the zero-page forms: `LDA zp` is 2 bytes, `TAX` is 1, `LAX zp` is 2; `DEC zp` is 2, `CMP zp` is 2, `DCP zp` is 2; `STX zp` is 2, `AND zp` is 2, `STA zp` is 2.

Where the saving matters:

- **Inside a per-line kernel.** If the loop is already within a few cycles of 76, replacing a DEC/CMP pair with DCP can move the loop from "one cycle too many" to "fits".
- **Inside a tight sprite or sound update.** SAX turning a 9-cycle mask into a 3-cycle store is the largest win of the four.
- **Inside a countdown.** DCP's flags make "decrement and test for zero" one instruction.

Where it does not:

- **VBLANK with thousands of spare cycles.** The lab's four operations run in VBLANK; the saving is irrelevant there. That is deliberate: the lab is measuring the operations, not optimising the frame.
- **Code that must be read by a beginner.** An undocumented opcode is a surprise. If the cycle saving is not measured, the documented sequence is the better choice.
- **Code that must run on a 65C02.** The instruction may not exist.

::: warning The rule for this course
Use a stable undocumented opcode only when (1) the target is the NMOS 6502/6507, (2) the cycle or byte saving is measured and justified, and (3) the source has a comment naming the opcode, its byte, and its documented equivalent. If any of the three is missing, write the documented sequence.
:::

### Section 4: ACME's 6502 Mode Has No Mnemonics

ACME 0.97 has no `6502i` type. Under `!cpu 6502` it rejects `LAX`, `SAX`, `DCP`, and `ISB` as unknown mnemonics; under `!cpu 6510` it accepts `LAX`, `SAX`, `DCP`, and `ISC` (the 6510 spelling of ISB). This course keeps `!cpu 6502` and uses a named macro that emits the bytes, so every opcode byte stays visible in the listing. The emitted bytes are identical:

```asm
!macro LAX_ZP .addr {
    !byte $A7, .addr        ; LAX zp: A = M, X = M
}
!macro SAX_ZP .addr {
    !byte $87, .addr        ; SAX zp: M = A AND X
}
!macro DCP_ZP .addr {
    !byte $C7, .addr        ; DCP zp: M = M-1, then CMP A,M
}
!macro ISB_ZP .addr {
    !byte $E7, .addr        ; ISB zp: M = M+1, then SBC A,M
}
```

Then the call site reads like an instruction with a visibly different spelling:

```asm
    +LAX_ZP LaxMem           ; ACME emits $A7 $90
```

The macro name is documentation and the `!byte` line is the truth. When the lesson says "LAX zp is `$A7`", the source contains `$A7`. When a reader disassembles the ROM, the byte matches the table. That is better than a mnemonic that hides which CPU mode the assembler chose. The `6510` alternative is honest about the toolchain but would make this lesson's CPU target different from every other lesson; the macro keeps the course's `!cpu 6502` line intact.

::: tip Why not switch assemblers?
You could switch to `!cpu 6510` in ACME, or use DASM or ca65 with an illegal-opcode mode, and many 2600 projects do. This course standardised on ACME and on `!cpu 6502` in Lesson 01; changing the CPU target to make four instructions look nicer would make this lesson different from every other lesson and hide the byte-level fact the lesson is teaching. The macro is the smaller, more honest change.
:::

### Section 5: The 65C02 and the Unstable Group

The 65C02 is a CMOS redesign, not a faster NMOS 6502. Its opcode matrix was cleaned up: the undocumented slots became defined instructions or NOPs of fixed lengths. A few examples:

| NMOS byte | NMOS behaviour | 65C02 behaviour |
|---|---|---|
| `$A7` | LAX zp | not the same instruction; a NOP or a different operation |
| `$87` | SAX zp | not the same instruction |
| `$C7` | DCP zp | not the same instruction |
| `$E7` | ISB zp | not the same instruction |
| `$80` | NOP (undocumented) | `BRA` (branch always) |
| `$DA` | NOP (undocumented) | `PHX` |
| `$FA` | NOP (undocumented) | `PLX` |
| `$DB` | NOP (undocumented) | `STP` |
| `$CB` | NOP (undocumented) | `WAI` |

The point is not the exact 65C02 map — it is that the byte `$A7` is not a portable contract. The 2600's 6507 is NMOS, so the stable group works there; a ROM written for a 65C02 target must use the documented instructions.

The unstable group is a different risk. These opcodes can produce different results on two consoles with the same ROM:

| Opcode | Byte | Why it is unstable |
|---|---|---|
| ANE | `$8B` | The result depends on the value on the data bus during an unused cycle. |
| LXA | `$AB` | Same class: an immediate value combined with a bus-dependent value. |
| SHA | `$9F`/`$93` | Stores A AND X AND (high byte + 1); the high byte depends on the address. |
| SHX | `$9E` | Stores X AND (high byte + 1). |
| SHY | `$9C` | Stores Y AND (high byte + 1). |
| TAS | `$9B` | Combines S, A, X, and the high byte of the address. |
| LAS | `$BB` | Loads A, X, and S from a bus-dependent value. |
| KIL/JAM | `$02`, `$12`, `$22`, … | Locks the CPU until reset. |

The lab does not use any of these. The Stella logs in this lesson are evidence for the **stable four** only, on the emulator's NMOS core; they are not a promise about an unstable opcode or a different chip.

### Section 6: The Opcode Laboratory

The screen is 192 visible lines in both modes:

| Visible lines | What it shows |
|---|---|
| 0–15 | The title block: a gold frame and "LAB" in 4-chunk glyphs |
| 16–47 | Four 8-line labels: the opcode byte as eight chunks (bit 7 first), the illegal cycle bar (PF2), the documented cycle bar (white) |
| 48 | A one-line setup gap (blank) |
| 49–176 | Screen 0: four 32-line result rows. Screen 1: eight 16-line cycle bands |
| 177–191 | The footer: a white rule, the XOR checksum as eight chunks, and the screen indicator |

**Screen 0 — the four result rows.** Each row is 32 lines tall and uses the same layout:

- **PF0 and PF1** draw eight flag columns, one chunk per bit of the live P byte, running the full height of the row. The columns are `N V 1 B D I Z C` from left to right. PF0 carries the high nibble (reversed, because PF0's bit 4 is the leftmost chunk); PF1 carries the low nibble.
- **PF2** draws the result bar at chunks 12–13. The bar is on for the last *result* lines of the row: `BarStart = 32 − result`, so the bar's height is the result byte. LAX `$12` is 18 lines, SAX `$10` is 16, DCP `$1F` is 31, ISB `$11` is 17.
- **P0** is the gold diamond marker at TIA X = 32, on lines 20–27 of the selected row. It steps down one row every 60 frames.

The four inputs and results are fixed, so the picture is stable:

| Row | Operation | Input | Result | Flags after the operation |
|---|---|---|---|---|
| 1 | LAX `$90` | `$90` = `$12` | A = X = `$12` | N=0, Z=0, C=0 |
| 2 | SAX `$91` | A = `$12`, X = `$34` | `$91` = `$10` | unchanged (N=0, Z=0, C=0) |
| 3 | DCP `$92` | `$92` = `$20`, A = `$1F` | `$92` = `$1F` | N=0, Z=1, C=1 |
| 4 | ISB `$93` | `$93` = `$10`, A = `$20`, SEC | `$93` = `$11`, A = `$0F` | N=0, V=0, Z=0, C=1 |

The XOR checksum of the four result bytes is `$12 ^ $10 ^ $1F ^ $11 = $0C`. The footer draws it at chunks 6–13, bit 7 first, so `$0C` lights chunks 10 and 11.

The whole panel is reflected: `CTRLPF=$01` mirrors every playfield pattern, so each title chunk, label bar, flag column, and result bar appears a second time on the right half. The pixel checks list both the left pattern and its mirror; the right half is the intended symmetric panel, not a rendering defect.

**Screen 1 — the cycle table.** Eight 16-line bands, one per stable opcode: LAX, SAX, DCP, ISB, SLO, RLA, SRE, RRA. Each band has a separator line, a two-line **documented** bar in white, and a two-line **illegal** bar in the opcode's colour. The bars start at chunk 2; the length is the cycle count. The first four bands are the lab's four operations; the last four are the documented examples.

**The frame.** 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines. `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6. One HMOVE per frame positions the P0 marker. The auto-demo toggles the screen every 240 frames and the marker every 60; SELECT toggles the screen immediately and restarts the 240-frame clock.

## The Code

### Building This Lesson

```bash
# every lesson ROM, including this one:
npm run roms

# or just this one:
acme -f plain -o build/lesson58.bin \
  lessons/part8-advanced/58-illegal-opcodes/58-illegal-opcodes.asm
stella build/lesson58.bin
```

The source assembles to exactly **4,096 bytes**. The four named macros emit the undocumented opcodes under `!cpu 6502`; `!cpu 6510` would accept the mnemonics (`ISC` for ISB), but the macros keep every byte visible in the listing. The emitted bytes are identical. The exercise solutions sit beside the lesson source:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part8-advanced/58-illegal-opcodes/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part8-advanced/58-illegal-opcodes/exercise-02-solution.asm
acme -f plain -o build/exercise-03.bin \
  lessons/part8-advanced/58-illegal-opcodes/exercise-03-solution.asm
```

Each solution also assembles to 4,096 bytes.

### Full Source

The complete annotated source is reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 58: Illegal Opcodes — Undocumented Power — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the opcode laboratory": a 4,096-byte cartridge that runs the four stable
;   undocumented NMOS 6502 instructions — LAX, SAX, DCP and ISB — once per
;   frame in VBLANK on known inputs, stores the result bytes, the processor
;   flags and an XOR checksum in RAM, and draws a 192-line instrument panel
;   that shows the results as playfield bars.  SELECT switches to a second
;   screen: the documented-versus-illegal cycle table for eight stable
;   opcodes, drawn as bars.  An auto-demo toggles the screen every 240 frames
;   and walks the P0 marker down the four result rows every 60 frames.
;
; The four operations (zero-page forms):
;   LAX zp  $A7  A = M and X = M; N and Z from M.        illegal 3 cycles
;                documented: LDA zp (3) + TAX (2) = 5
;   SAX zp  $87  M = A AND X; no flags change.           illegal 3 cycles
;                documented: STX zp (3) + AND zp (3) + STA zp (3) = 9
;                (7 if the mask is an immediate: TXA + AND #mask + STA zp)
;   DCP zp  $C7  M = M - 1; then CMP A,M (A - M).        illegal 5 cycles
;                documented: DEC zp (5) + CMP zp (3) = 8
;   ISB zp  $E7  M = M + 1; then SBC A,M.                illegal 5 cycles
;                documented: INC zp (5) + SBC zp (3) = 8
;   (ISB is also written ISC in some references.  The byte is the same.)
;
; The inputs and the results:
;   LAX  $90 = $12                  -> A = X = $12
;   SAX  A = $12, X = $34, $91      -> $91 = $12 & $34 = $10
;   DCP  $92 = $20, A = $1F         -> $92 = $1F; A - M = 0: Z=1, C=1
;   ISB  $93 = $10, A = $20, SEC    -> $93 = $11; A = $20-$11 = $0F, C=1
;   The four result bytes are $12, $10, $1F, $11.  Their XOR is $0C.
;
; ACME 0.97 and the illegal mnemonics:
;   ACME has no 6502i type.  Under !cpu 6502 the undocumented mnemonics are
;   rejected; under !cpu 6510 the assembler accepts them (LAX, SAX, DCP and
;   ISC, the 6510 spelling of ISB).  This course keeps !cpu 6502 and
;   emits the bytes with the four named macros below, so every opcode byte
;   stays visible in the listing.  The emitted bytes are identical:
;       !macro LAX_ZP .addr { !byte $A7, .addr }
;   Every use is a +LAX_ZP / +SAX_ZP / +DCP_ZP / +ISB_ZP line.  This is not
;   a workaround hidden from the reader: it is the honest toolchain answer,
;   and it makes the opcode table in the lesson document exact.
;
; Why these four and not the unstable ones:
;   LAX, SAX, DCP, ISB, SLO, RLA, SRE and RRA are the stable undocumented
;   instructions: their behaviour is the same on every NMOS 6502/6507 die.
;   The unstable group (ANE, LXA, SHA, SHX, SHY, TAS, LAS, the KIL/JAM
;   opcodes) can depend on the data bus, the temperature, or the individual
;   chip.  This lesson does not use them.  The 65C02 does not implement the
;   NMOS undocumented opcodes the same way (many became NOPs or new
;   instructions), so portable code must not depend on them.
;
; The screen (192 visible lines in both modes):
;   visible   0-15   the title block: a gold frame and "LAB" in 4-chunk glyphs
;   visible  16-47   four 8-line byte/cycle labels, one per operation
;                      line 0: the opcode byte as eight PF chunks (bit 7 first)
;                      line 1: the illegal cycle count as a PF2 bar
;                      line 2: the documented count as a white bar
;                      lines 3-7: blank
;   visible     48   a one-line setup gap (blank)
;   visible  49-176  the middle: four 32-line result rows (screen 0) or
;                    eight 16-line cycle bands (screen 1)
;   visible    177   the white footer rule
;   visible 178-183  six blank lines
;   visible 184-191  the XOR checksum as eight chunks and the screen indicator
;                    (left of centre = screen 0, right of centre = screen 1)
;
; The result row (32 lines):
;   PF0/PF1  eight flag columns (N V 1 B D I Z C), one chunk each, full height
;            PF0 = Rev4[flags >> 4] << 4; PF1 = (flags & $0F) << 4
;   PF2      the result bar: chunks 12-13, present only on the last `result`
;            lines of the row, so the bar's height is the result byte.
;            BarStart = 32 - result; the bar is drawn when Y >= BarStart.
;   P0       an 8x8 gold diamond at TIA X = 32, on the selected row's lines
;            20-27.  The marker strip is 33 bytes of ROM: 20 zeros, the
;            diamond, 5 zeros; MarkerStrip+1,Y is the value for line Y+1.
;   The row colours: LAX green, SAX blue, DCP orange, ISB purple.
;
;   Every line writes PF0/PF1 first, the PF2 bar next, and preloads the NEXT
;   line's GRP0.  The WSYNC/loop tail (INY/CPY/BNE) runs at the top of the
;   next line, so the cycle numbers below are measured from ResultLine:
;   PF0 by 7, PF1 by 14, PF2 by 24-26, the marker's LDA at ~40 and its
;   STA GRP0 at ~43.  Absolute scanline cycles are PF0/PF1 14/21 on a normal
;   line and 18/25 on the first line of rows 2-4 (the row-end LDY #0/JMP adds
;   5).  The next row's colour/PF2/BarCur are preloaded on the current row's
;   last line after the playfield is drawn; the last row ends with STA WSYNC
;   and jumps to the footer.  This keeps the first line of every row complete:
;   the old row setup wrote PF0 at 24-31 and PF1 at 31-38, after the beam.
;
; The cycle-table screen (screen 1):
;   eight 16-line bands, one per opcode: LAX, SAX, DCP, ISB, SLO, RLA, SRE,
;   RRA.  Each band has a separator line, a two-line documented bar (white)
;   at chunks 2..2+cycles-1, and a two-line illegal bar (the op's colour).
;   The documented counts are 5, 9, 8, 8, 8, 8, 8, 8; the illegal counts are
;   3, 3, 5, 5, 5, 5, 5, 5.  The first four bands are the lab's four ops;
;   the last four are documented examples of the same pattern.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;   One HMOVE per frame for the P0 marker.
;
; Cycle ledger (a line is 76 CPU cycles; the loops are page-local):
;   title row:      LDA/STA x3 (21) + WSYNC 3 + INY 2 + CPY 2 + BNE 3 = 31.
;                   PF0 is stored by cycle 14 on every row.
;   label row 0:    colour/PF0/PF1 by 27 on the first strip (after the
;                   title's 6-cycle tail), by 25 on the other three (after
;                   the blank loop's 4-cycle tail); PF2 by 32.  The old
;                   loop's INX/CPX/BNE tail put PF1 at 28-31; unrolling the
;                   four strips removes it.
;   label row 1:    PF2 first (7), then PF0/PF1 (12) = 19; PF0 by 12.
;   label row 2:    colour (5) + PF1 (7) + PF2 (7) + PF0 (5) = 24.
;   result row:     measured from ResultLine: PF0 7, PF1 14, PF2 24-26,
;                   marker LDA ~40, STA GRP0 ~43; a normal line ends at
;                   ~46-50 (about 26-30 unused).  The RowEnd line adds the
;                   next-row preload (after the playfield, cycle 42) and ends
;                   at ~66 (about 10 unused).  Absolute scanline PF0/PF1 are
;                   14/21 normal and 18/25 on the first line of rows 2-4.
;   table band:     the separator's tail is 9 cycles (the index update now
;                   runs before the nine blanks), so its colour, PF0, PF1 and
;                   PF2 are written by 16/21/26/29; the chunk-4 boundary is 28.
;                   The bar lines write within 25 cycles and repeat the value.
;   footer:         colour by 8, PF0 by 13, PF1 by 18, PF2 by 21 on screen 0;
;                   the screen-1 band loop reaches the footer ~7 cycles later,
;                   still before PF0's chunk 0.  The rule starts at chunk 0.
;   The RowEnd line is ~66 cycles (about 10 unused); a normal line leaves ~26-30.
;
; Checkpoints (the state log's A/X/Y/SP and P fields):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   OverscanStart (229/6);
;   Frame (A = the new frame count, 1, 2, 3, ...);
;   LaxRead (A = $12, X = $12), SaxRead (A = $12),
;   DcpRead (A = $1F), IsbRead (A = $0F), FlagsRead (P after ISB);
;   SaxM (A = $10), DcpM (A = $1F, C = 1), IsbM (A = $11);
;   Checksum (A = $0C), Screen (A = 0/1).
;
; RAM map (RIOT, $80-$FF; +clean_start zeroes every byte):
;   $80 ResultA      LAX's A, $12
;   $81 ResultX      LAX's X, $12
;   $82 ResultM      the last M result, ISB's $11
;   $83 Flags        the live P after ISB, $25
;   $84 Checksum     XOR of the four result bytes, $0C
;   $85 Screen       0 = the lab, 1 = the cycle table
;   $86 Result0..3   the four displayed result bytes ($12,$10,$1F,$11)
;   $8A Flag0..3     the four live P bytes ($24,$24,$27,$25)
;   $8E MarkerRow    the selected row, 0..3
;   $8F FrameCount   frames since reset, wraps at 256
;   $90 LaxMem       LAX's input, $12 (read-only)
;   $91 SaxMem       SAX's destination, written $10 every frame
;   $92 DcpMem       DCP's input, reset to $20, becomes $1F
;   $93 IsbMem       ISB's input, reset to $10, becomes $11
;   $94 PrevSelect   SELECT state last frame (1 = pressed)
;   $95 SelectNow    this frame's SELECT level
;   $96 MarkerTimer  the 60-frame marker divider
;   $97 ScreenTimer  the 240-frame screen divider
;   $98 Startup      frames left before SELECT is trusted
;   $99 BarCur       the current row's BarStart
;   $9A Tmp          scratch
;   $9B-$9C          free (2 bytes)
;   $9D ChecksumPF1  the footer's checksum bits 7-2, precomputed
;   $9E ChecksumPF2  the footer's checksum bits 1-0, precomputed
;   $9F              free (1 byte)
;   $A0 RowF0        four flag-field PF0 bytes, one per row
;   $A4 RowF1        four flag-field PF1 bytes, one per row
;   $A8 BarStart     four bar thresholds, one per row
;   $AC-$D7 free
;   $D8-$F7 free
;   $F8-$FF stack
;
; Build: acme -f plain -o build/lesson58.bin \
;        lessons/part8-advanced/58-illegal-opcodes/58-illegal-opcodes.asm
; Run:   stella build/lesson58.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; THE UNDOCUMENTED OPCODES AS NAMED MACROS
; =============================================================================
; ACME 0.97 has no 6502i type.  Under !cpu 6502 the undocumented mnemonics are
; rejected; under !cpu 6510 they assemble (LAX, SAX, DCP and ISC for ISB).
; This course keeps !cpu 6502, and each macro emits the opcode byte followed by
; the zero-page operand.  The names keep the source readable; the bytes keep
; the lesson honest.  A macro invocation is written +LAX_ZP LaxMem and so on.
!macro LAX_ZP .addr {
    !byte $A7, .addr        ; LAX zp: A = M, X = M
}
!macro SAX_ZP .addr {
    !byte $87, .addr        ; SAX zp: M = A AND X
}
!macro DCP_ZP .addr {
    !byte $C7, .addr        ; DCP zp: M = M-1, then CMP A,M
}
!macro ISB_ZP .addr {
    !byte $E7, .addr        ; ISB zp: M = M+1, then SBC A,M (6510: ISC)
}

; +SAVE_P stores the live processor flags in .dest without destroying A.
; PHP pushes a copy with the B marker set; PLA reads it back, AND #$EF clears
; the marker, and the saved A is restored from Tmp.  The stack is used for one
; byte at a time, so the call depth does not grow.
!macro SAVE_P .dest {
    STA Tmp                 ; preserve the result byte
    PHP
    PLA
    AND #$EF                ; clear the PHP B marker
    STA .dest
    LDA Tmp                 ; restore the result byte
}

; -----------------------------------------------------------------------------
; LABEL_STRIP — one 8-line byte/cycle label strip, unrolled four times
; -----------------------------------------------------------------------------
; The four strips used to be a loop with an INX/CPX/BNE tail.  That tail put
; the byte line's PF1 write at cycle 28-31, after chunks 4-6, so the ISB byte
; lost bit 5 (chunk 4) and the LAX bit 5 was short.  Unrolling removes the
; tail: the byte line's colour/PF0/PF1 writes complete at cycle 27, before
; chunk 4 at cycle 28.  The illegal and documented bars are right-aligned at
; chunk 19, so their lengths compare from the same edge.
!macro LABEL_STRIP .idx {
; --- line 0: the opcode byte, bit 7 first ------------------------------------
    LDA OpColor + .idx
    STA COLUPF
    LDA OpBytePF0 + .idx
    STA PF0
    LDA OpBytePF1 + .idx
    STA PF1
    LDA #$00
    STA PF2
    STA WSYNC
; --- line 1: the illegal cycle bar, right-aligned at chunk 19 ---------------
    LDA OpIllegalPF2 + .idx
    STA PF2
    LDA #$00
    STA PF0
    STA PF1
    STA WSYNC
; --- line 2: the documented cycle bar, white, right-aligned at chunk 19 ------
    LDA #C_WHITE
    STA COLUPF
    LDA OpDocPF1 + .idx
    STA PF1
    LDA OpDocPF2 + .idx
    STA PF2
    LDA #$00
    STA PF0
    STA WSYNC
; --- lines 3-7: blank --------------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #5
-
    STA WSYNC
    DEY
    BNE -
}

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

SCREEN_LINES   = 192     ; every frame draws 192 visible lines
TITLE_LINES    = 16      ; the gold LAB block
LABEL_LINES    = 32      ; four 8-line byte/cycle labels
MIDDLE_LINES   = 128     ; four 32-line result rows, or eight 16-line bands
GAP_LINES      = 1       ; one setup line before the middle content
FOOTER_LINES   = 15      ; the rule, the checksum and the screen indicator

ROW_COUNT      = 4       ; LAX, SAX, DCP, ISB
ROW_LINES      = 32      ; one row per operation
BAND_COUNT     = 8       ; the four lab ops plus SLO/RLA/SRE/RRA
BAND_LINES     = 16      ; one cycle-table band

MARKER_X       = 32      ; the P0 marker's TIA X (the gap between the fields)
MARKER_TOP     = 20      ; the marker's first line inside a row

MARKER_FRAMES  = 60      ; the marker steps down every 60 frames
SCREEN_FRAMES  = 240     ; the screen toggles every 240 frames
STARTUP_FRAMES = 8       ; SELECT is ignored while the console settles

C_BG           = $00     ; black page
C_TITLE        = $1A     ; gold title frame
C_WHITE        = $0E     ; white documented-cycle bars and footer
C_MARK         = $1A     ; gold marker (the same gold as the title)
C_LAX          = $C8     ; green
C_SAX          = $84     ; blue
C_DCP          = $38     ; orange
C_ISB          = $66     ; purple
C_GRAY         = $0A     ; the four documented-example bands

FLAG_BAND_TOP  = 4       ; the flag columns run the full row; kept for clarity

; The frame arithmetic is a build-time assertion, not a comment.
!if TITLE_LINES + LABEL_LINES + GAP_LINES + MIDDLE_LINES + FOOTER_LINES != SCREEN_LINES {
    !error "the five screen zones must total 192 lines"
}
!if ROW_COUNT * ROW_LINES != MIDDLE_LINES {
    !error "four 32-line rows must fill the middle 128 lines"
}
!if BAND_COUNT * BAND_LINES != MIDDLE_LINES {
    !error "eight 16-line bands must fill the middle 128 lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$AB; +clean_start zeroes every byte)
; =============================================================================
ResultA      = $80    ; LAX's A, $12
ResultX      = $81    ; LAX's X, $12
ResultM      = $82    ; the last M result, ISB's $11
Flags        = $83    ; the live P after ISB, $25
ChecksumVal  = $84    ; XOR of the four result bytes, $0C
ScreenNum    = $85    ; 0 = lab, 1 = cycle table

ResultBytes  = $86    ; four bytes: LAX, SAX, DCP, ISB
FlagBytes    = $8A    ; four live P bytes, one per operation

MarkerRow    = $8E    ; 0..3
FrameCount   = $8F    ; frames since reset
LaxMem       = $90    ; LAX's input, $12
SaxMem       = $91    ; SAX's destination, $10
DcpMem       = $92    ; DCP's input, $20 -> $1F
IsbMem       = $93    ; ISB's input, $10 -> $11
PrevSelect   = $94
SelectNow    = $95
MarkerTimer  = $96
ScreenTimer  = $97
Startup      = $98
BarCur       = $99
Tmp          = $9A

ChecksumPF1  = $9D    ; the footer's checksum bits 7-2
ChecksumPF2  = $9E    ; the footer's checksum bits 1-0

RowF0        = $A0    ; four flag-field PF0 bytes
RowF1        = $A4    ; four flag-field PF1 bytes
BarStart     = $A8    ; four bar thresholds, 32 - result

; $AC-$D7 and $D8-$F7 are free.  The stack lives at $F8-$FF; the call depth is
; one level (RunLab, BuildDisplay, SetCoarseP0).

; =============================================================================
; RESET — the program's entry point
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port

; --- make the flag state deterministic ---------------------------------------
; +clean_start does SEI and CLD but does not clear V or C.  The lab's P bytes
; are part of the display, so set them here.  I = 1 from SEI, D = 0 from CLD,
; V = 0 from CLV, C = 0 from CLC: the base P is $24.
    SEI
    CLD
    CLV
    CLC

; --- the lab's known inputs ---------------------------------------------------
; LAX and SAX are read-only on their operand for LAX and write-only for SAX;
; DCP and ISB modify their operand, so RunLab resets those two every frame.
    LDA #$12
    STA LaxMem
    LDA #$00
    STA SaxMem
    LDA #$20
    STA DcpMem
    LDA #$10
    STA IsbMem

; --- the demo state -----------------------------------------------------------
; Screen, MarkerRow, the two timers and PrevSelect are already zero.
    LDA #STARTUP_FRAMES
    STA Startup

; --- the TIA's fixed state ----------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; black page
    LDA #C_TITLE
    STA COLUPF              ; gold until the first zone sets its own colour
    LDA #C_MARK
    STA COLUP0              ; the marker
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the panel is symmetric
    LDA #$00
    STA NUSIZ0              ; one copy of P0
    STA GRP0
    STA PF0
    STA PF1
    STA PF2

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK              ; blank the picture
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; 1. THE FRAME COUNTER
; -----------------------------------------------------------------------------
    INC FrameCount
    LDA FrameCount
Frame:                      ; checkpoint: A = the new frame count

; -----------------------------------------------------------------------------
; 2. SELECT — toggle the screen on the 0 -> 1 edge
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  EOR turns that into a 1; the
; EOR/AND pair keeps only a new press, so holding the switch toggles once.
; The first eight frames are not trusted: the console's switches can read low
; while it settles, so Startup forces the edge clear until it reaches zero.
    LDA Startup
    BEQ SelectReady
    DEC Startup
    LDA #$00
    STA SelectNow
    JMP SelectEdgeDone
SelectReady:
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA SelectNow
    EOR PrevSelect
    AND SelectNow
    BEQ SelectEdgeDone
    LDA ScreenNum
    EOR #$01                ; 0 -> 1 = the cycle table, 1 -> 0 = the lab
    STA ScreenNum
    LDA #$00
    STA ScreenTimer         ; restart the 240-frame clock
SelectEdgeDone:
    LDA SelectNow
    STA PrevSelect

; -----------------------------------------------------------------------------
; 3. THE AUTO-DEMO CLOCKS
; -----------------------------------------------------------------------------
; The marker walks the four rows every 60 frames; the screen toggles every
; 240 frames.  Both counters run in VBLANK, so a long frame cannot drift them.
    INC MarkerTimer
    LDA MarkerTimer
    CMP #MARKER_FRAMES
    BCC NoMarkerStep
    LDA #$00
    STA MarkerTimer
    INC MarkerRow
    LDA MarkerRow
    AND #$03
    STA MarkerRow
NoMarkerStep:
    INC ScreenTimer
    LDA ScreenTimer
    CMP #SCREEN_FRAMES
    BCC NoScreenStep
    LDA #$00
    STA ScreenTimer
    LDA ScreenNum
    EOR #$01
    STA ScreenNum
NoScreenStep:
    LDA ScreenNum
Screen:                     ; checkpoint: A = 0 (lab) or 1 (cycle table)

; -----------------------------------------------------------------------------
; 4. THE FOUR OPERATIONS — once per frame on the known inputs
; -----------------------------------------------------------------------------
    JSR RunLab

; -----------------------------------------------------------------------------
; 5. THE DISPLAY BYTES — flags to PF fields, results to bar thresholds
; -----------------------------------------------------------------------------
    JSR BuildDisplay

; -----------------------------------------------------------------------------
; 6. THE MARKER'S POSITION — one divide-by-15 dance and one HMOVE
; -----------------------------------------------------------------------------
    LDA #(MARKER_X + POS_BIAS)
    JSR SetCoarseP0         ; sets HMP0 and strobes RESP0
    STA WSYNC
    STA HMOVE               ; the frame's only HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; THE VISIBLE KERNEL — 192 lines
; =============================================================================

; -----------------------------------------------------------------------------
; Zone 1: 16 title lines — the gold frame and the 4-chunk "LAB"
; -----------------------------------------------------------------------------
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDA #C_TITLE
    STA COLUPF
    LDY #0
TitleRow:
    LDA TitlePF0,Y
    STA PF0
    LDA TitlePF1,Y
    STA PF1
    LDA TitlePF2,Y
    STA PF2
    STA WSYNC
    INY
    CPY #TITLE_LINES
    BNE TitleRow

; -----------------------------------------------------------------------------
; Zone 2: 32 byte/cycle label lines — four 8-line strips, unrolled
; -----------------------------------------------------------------------------
; Line 0 of a strip is the opcode byte as eight chunks, bit 7 first, at
; chunks 2-9.  Line 1 is the illegal cycle count as a PF2 bar; line 2 is the
; documented count as a white bar.  Both bars are right-aligned at chunk 19,
; so a longer bar starts further left and the lengths compare.
    +LABEL_STRIP 0
    +LABEL_STRIP 1
    +LABEL_STRIP 2
    +LABEL_STRIP 3

; -----------------------------------------------------------------------------
; Zone 3: 128 middle lines — branch on the screen
; -----------------------------------------------------------------------------
    LDA ScreenNum
    BNE CycleTable
; --- the one-line setup gap: blank the current line and seed row 0 -----------
; This line absorbs the screen branch.  It also loads row 0's colour, bar
; threshold and PF2, so the first row's first line starts with its PF0/PF1
; writes (cycle 7/14) instead of a 13-cycle row-setup tail.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDX #0
    LDA OpColor,X
    STA COLUPF
    LDA BarStart,X
    STA BarCur
    STA WSYNC
    LDY #0

; --- Screen 0: four 32-line result rows --------------------------------------
; Every line writes PF0/PF1 first (cycle 7/14), then the PF2 bar (cycle 26),
; then preloads the NEXT line's marker into GRP0 (cycle 40).  The marker is
; latched at the player's pixels, not at the start of the line, so the preload
; keeps the diamond intact.  The next row's colour/PF2/BarCur are preloaded on
; the current row's last line after the playfield is drawn; the last row
; preloads the footer's white colour.  This is the fix for the old row setup,
; which wrote PF0 at cycle 24-31 and PF1 at 31-38 and left the first line of
; rows 2-4 showing the previous row's P bytes.
ResultLine:
    LDA RowF0,X             ; PF0 by cycle 7
    STA PF0
    LDA RowF1,X             ; PF1 by cycle 14
    STA PF1
    LDA #$00
    CPY BarCur
    BCC NoBar
    LDA #$03                ; PF2 bits 0-1 = chunks 12-13
NoBar:
    STA PF2                 ; PF2 by cycle 24-26
    CPY #(ROW_LINES - 1)
    BEQ RowEnd
; --- the P0 marker: preload the NEXT line's diamond --------------------------
    LDA #$00
    CPX MarkerRow
    BNE NoMarkerPre
    LDA MarkerStrip+1,Y     ; MarkerStrip+1,Y is line Y+1
NoMarkerPre:
    STA GRP0
    JMP LineDone
RowEnd:
; --- preload the next row's setup, or the footer's colour --------------------
; These writes happen after the current line's playfield is drawn (cycle 42),
; so they affect only the next line.
    CPX #(ROW_COUNT - 1)
    BEQ RowFooter
    LDA NextRowTab,X
    TAX
    LDA OpColor,X
    STA COLUPF
    LDA #$00
    STA PF2
    LDA BarStart,X
    STA BarCur
    JMP LineDone
RowFooter:
    STA WSYNC
    JMP Footer
LineDone:
    STA WSYNC
    INY
    CPY #ROW_LINES
    BNE ResultLine
    LDY #0
    JMP ResultLine           ; X is already the next row

; --- Screen 1: eight 16-line cycle-table bands --------------------------------
; A band: a separator line, a blank line, a two-line white documented bar, a
; blank line, a two-line illegal bar, and nine blank lines.  The bars start at
; chunk 2; PF0 = $C0 covers chunks 2-3, PF1 carries the rest.
CycleTable:
; --- the same one-line setup gap for the cycle table ------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    LDX #0
BandLoop:
; --- separator line -----------------------------------------------------------
    LDA BandColor,X
    STA COLUPF
    LDA #$C0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    STA WSYNC
; --- blank line ---------------------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
; --- documented bar, two lines, white ----------------------------------------
    LDA #C_WHITE
    STA COLUPF
    LDA #$C0
    STA PF0
    LDA BandDocPF1,X
    STA PF1
    LDA #$00
    STA PF2
    STA WSYNC
    STA WSYNC
; --- blank line ---------------------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
; --- illegal bar, two lines, the band's colour -------------------------------
    LDA BandColor,X
    STA COLUPF
    LDA #$C0
    STA PF0
    LDA BandIllPF1,X
    STA PF1
    LDA #$00
    STA PF2
    STA WSYNC
    STA WSYNC
; --- advance to the next band before the blank lines -------------------------
; The index update used to sit after the nine blank lines; its INX/CPX/BNE
; tail pushed the next separator's PF1 write to cycle 28, the chunk-4
; boundary.  Updating X before the blanks leaves only the blank loop's last
; DEY/BNE plus the loop test (9 cycles), so the separator's PF1 is written at
; cycle 26.  The blank lines are unaffected: their PF bytes are 0.
    INX
; --- nine blank lines ---------------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #9
BandBlank:
    STA WSYNC
    DEY
    BNE BandBlank
    CPX #BAND_COUNT
    BNE BandLoop
    JMP Footer

; -----------------------------------------------------------------------------
; Zone 4: 15 footer lines — the rule, the checksum and the screen indicator
; -----------------------------------------------------------------------------
; The last result row reaches this label with its own STA WSYNC, so the rule
; line starts at cycle 3; the screen-1 band loop reaches it at cycle 10.  Both
; are early enough for the rule's colour/PF0/PF1/PF2 writes (cycles 13-28) to
; beat the left half, so the rule needs no setup gap and starts at chunk 0.
Footer:
    LDA #C_WHITE
    STA COLUPF
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    LDA #$00
    STA GRP0
    STA WSYNC
; --- six blank lines --------------------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #6
FooterBlank:
    STA WSYNC
    DEY
    BNE FooterBlank
; --- eight lines: the checksum bits and the screen indicator ------------------
; The checksum is shown at chunks 6-13, bit 7 first.  Screen 0 puts a two-chunk
; indicator at chunks 1-2 (PF0); screen 1 puts it at chunks 17-18 (PF2).
    LDX ScreenNum
    LDA ScreenPF0Tab,X
    STA PF0
    LDA ChecksumPF1
    STA PF1
    LDA ChecksumPF2
    ORA ScreenPF2Tab,X
    STA PF2
    LDY #8
FooterBits:
    STA WSYNC
    DEY
    BNE FooterBits
    NOP                     ; the frame checkpoint reports 229/6, not 229/4

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; RunLab — the four undocumented operations on known inputs
; =============================================================================
; The operations run once per frame.  DCP and ISB modify their operands, so
; both are reset before every run; SAX overwrites its destination every time.
; The flags are saved as the live P: PHP pushes a copy with B set, and the
; AND #$EF clears that marker so the stored byte is the register's value.
RunLab:
; --- reset the operands that the operations change ---------------------------
    LDA #$20
    STA DcpMem
    LDA #$10
    STA IsbMem

; --- LAX: A = X = M ----------------------------------------------------------
; LAX defines N and Z only.  CLC makes the carry deterministic, so the C
; column in the LAX row cannot inherit a carry from the previous frame's ISB
; (or from the screen timer's arithmetic).
    CLC
    +LAX_ZP LaxMem           ; ACME emits $A7 $90
LaxRead:                     ; checkpoint: A = $12, X = $12
    STA ResultBytes+0        ; the LAX result
    STA ResultA
    STX ResultX
    +SAVE_P FlagBytes+0      ; A stays $12 for the SAX
; --- SAX: M = A AND X --------------------------------------------------------
; A is still $12 from LAX; set X to $34.  SAX changes no flags; CLC keeps the
; captured C at 0, the same value the LAX row shows.
    CLC
    LDX #$34
    +SAX_ZP SaxMem           ; ACME emits $87 $91
SaxRead:                     ; checkpoint: A = $12 (unchanged)
    LDA SaxMem
    STA ResultBytes+1
    +SAVE_P FlagBytes+1      ; A stays $10
SaxM:                        ; checkpoint: A = $10

; --- DCP: M = M-1, then CMP A,M ---------------------------------------------
; Set A to the value the decremented memory will hold, so the compare reports
; equality: M = $20-1 = $1F, A = $1F, Z = 1 and C = 1.
    LDA #$1F
    +DCP_ZP DcpMem           ; ACME emits $C7 $92
DcpRead:                     ; checkpoint: A = $1F, P has Z=1 and C=1
    +SAVE_P FlagBytes+2
    LDA DcpMem
    STA ResultBytes+2
DcpM:                        ; checkpoint: A = $1F, C = 1

; --- ISB: M = M+1, then SBC A,M ---------------------------------------------
; Secure the carry first: the SBC then computes A - M - 0.  With A = $20 and
; M = $11 the result is $0F and the carry stays set (no borrow).
    LDA #$20
    SEC
    +ISB_ZP IsbMem           ; ACME emits $E7 $93
IsbRead:                     ; checkpoint: A = $0F
FlagsRead:                   ; checkpoint: P after ISB (C=1, Z=0)
    +SAVE_P FlagBytes+3
    LDA FlagBytes+3
    STA Flags                ; $83 = the live P after ISB
    LDA IsbMem
    STA ResultBytes+3
    STA ResultM
IsbM:                        ; checkpoint: A = $11

; --- the XOR checksum of the four result bytes ------------------------------
    LDA ResultBytes+0
    EOR ResultBytes+1
    EOR ResultBytes+2
    EOR ResultBytes+3
Checksum:                    ; checkpoint: A = $0C
    STA ChecksumVal
    RTS

; =============================================================================
; BuildDisplay — turn the runtime bytes into playfield bytes
; =============================================================================
; The flag columns are PF0 chunks 0-3 (N V 1 B) and PF1 chunks 4-7 (D I Z C).
; The high nibble is reversed because PF0's bit 4 is the leftmost chunk; the
; low nibble shifts straight up because PF1's bit 7 is chunk 4.
BuildDisplay:
    LDX #0
FlagToPF:
    LDA FlagBytes,X
    STA Tmp
    LSR
    LSR
    LSR
    LSR                     ; the high nibble (N V 1 B)
    TAY
    LDA Rev4,Y
    ASL
    ASL
    ASL
    ASL                     ; move it to PF0's high four bits
    STA RowF0,X
    LDA Tmp
    AND #$0F
    ASL
    ASL
    ASL
    ASL                     ; the low nibble (D I Z C) to PF1's high bits
    STA RowF1,X
    INX
    CPX #ROW_COUNT
    BNE FlagToPF

; --- BarStart = 32 - result ---------------------------------------------------
    LDX #0
BarStarts:
    LDA #32
    SEC
    SBC ResultBytes,X
    STA BarStart,X
    INX
    CPX #ROW_COUNT
    BNE BarStarts

; --- the footer's checksum bytes ---------------------------------------------
; The checksum's bit 7 goes to chunk 6 and bit 0 to chunk 13.  PF1 carries
; bits 7-2 (chunks 6-11); PF2 carries bits 1-0, but PF2 bit 0 is chunk 12 and
; bit 1 is chunk 13, so the two bits are reversed with the Rev2 table.
    LDA ChecksumVal
    STA Tmp
    LSR
    LSR
    AND #$3F
    STA ChecksumPF1
    LDA Tmp
    AND #$03
    TAY
    LDA Rev2,Y
    STA ChecksumPF2
    RTS

; =============================================================================
; SetCoarseP0 — the Lesson 26 divide-by-15 positioning dance
; =============================================================================
; A = the desired left edge + POS_BIAS.  Each loop pass is 5 cycles = 15
; colour clocks, which is why dividing by 15 works.  The remainder becomes
; HMP0's fine value and RESP0 strobes the coarse position.
SetCoarseP0:
    STA WSYNC
    SEC
DivP0:
    SBC #15
    BCS DivP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS

; =============================================================================
; THE DATA
; =============================================================================
    !if * > $F800 {
        !error "the code must end before $F800"
    }
    !fill $F800 - *, $EA

; --- the 16-line title block: a gold frame and "LAB" --------------------------
; 20 chunks per line, reflected by CTRLPF.  The three 4-chunk glyphs sit at
; chunks 2-5, 7-10 and 12-15; the frame is chunk 0, chunk 19, and rows 0/15.
TitlePF0:
    !byte $F0, $10, $50, $50, $50, $50, $50, $50
    !byte $D0, $10, $10, $10, $10, $10, $10, $F0
TitlePF1:
    !byte $FF, $00, $0C, $12, $12, $1E, $12, $12
    !byte $D2, $00, $00, $00, $00, $00, $00, $FF
TitlePF2:
    !byte $FF, $80, $87, $89, $89, $87, $89, $89
    !byte $87, $80, $80, $80, $80, $80, $80, $FF

; --- the four opcode bytes as eight chunks, bit 7 first ----------------------
; LAX $A7 = 1010 0111, SAX $87 = 1000 0111, DCP $C7 = 1100 0111,
; ISB $E7 = 1110 0111.  The byte sits at chunks 2-9: PF0 bits 6-7 are bits
; 7-6, and PF1 bits 7-2 are bits 5-0.
OpBytePF0:
    !byte $40, $40, $C0, $C0
OpBytePF1:
    !byte $9C, $1C, $1C, $9C

; --- the illegal cycle bar, right-aligned at chunk 19 ------------------------
; 3 chunks = 17-19 (PF2 $E0); 5 chunks = 15-19 (PF2 $F8).
OpIllegalPF2:
    !byte $E0, $E0, $F8, $F8

; --- the documented cycle bar, right-aligned at chunk 19 ---------------------
; LAX 5 = 15-19 (PF2 $F8).  SAX 9 = 11-19 (PF1 bit 0 + PF2 $FF).
; DCP/ISB 8 = 12-19 (PF2 $FF).
OpDocPF1:
    !byte $00, $01, $00, $00
OpDocPF2:
    !byte $F8, $FF, $FF, $FF

; --- the row colours ----------------------------------------------------------
OpColor:
    !byte C_LAX, C_SAX, C_DCP, C_ISB

; --- the 33-byte marker strip ------------------------------------------------
; One GRP0 byte per line inside a row: 20 zeros, the 8x8 diamond, 5 zeros.
; The extra zero at index 32 makes MarkerStrip+1,Y read a clean zero when
; Y = 31 (the preload for the next line).
MarkerStrip:
    !fill MARKER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill ROW_LINES - MARKER_TOP - 8 + 1, $00

; --- the row after X, wrapping 3 -> 0 ----------------------------------------
NextRowTab:
    !byte 1, 2, 3, 0

; --- the cycle-table bands ----------------------------------------------------
; The first four are the lab's four operations; the last four are documented
; examples of the same combined-operation pattern.
BandColor:
    !byte C_LAX, C_SAX, C_DCP, C_ISB, C_GRAY, C_GRAY, C_GRAY, C_GRAY
; Documented bars, two lines each at chunks 2..2+cycles-1 (PF0=$C0, PF1 below):
; 5 -> $E0, 9 -> $FE, 8 -> $FC.
BandDocPF1:
    !byte $E0, $FE, $FC, $FC, $FC, $FC, $FC, $FC
; Illegal bars: 3 -> $80, 5 -> $E0.
BandIllPF1:
    !byte $80, $80, $E0, $E0, $E0, $E0, $E0, $E0

; --- the footer's screen indicator -------------------------------------------
; Screen 0: chunks 1-2 in PF0 ($60).  Screen 1: chunks 17-18 in PF2 ($60).
ScreenPF0Tab:
    !byte $60, $00
ScreenPF2Tab:
    !byte $00, $60

; --- the 4-bit reversal used by PF0's high nibble -----------------------------
; Rev4[n] reverses n's four bits: bit 3 becomes bit 0.  BuildDisplay uses it
; to place the flag nibble's leftmost bit in PF0's leftmost chunk.
Rev4:
    !byte $0, $8, $4, $C, $2, $A, $6, $E, $1, $9, $5, $D, $3, $B, $7, $F

; --- the 2-bit reversal used by the footer's checksum ------------------------
; Rev2[n] swaps n's two bits: bit 0 -> PF2 bit 1 (chunk 13) and bit 1 ->
; PF2 bit 0 (chunk 12), so the footer still reads bit 7 first.
Rev2:
    !byte $00, $02, $01, $03

; -----------------------------------------------------------------------------
; The vectors
; -----------------------------------------------------------------------------
    !if * > $FFFA {
        !error "the data must end before $FFFA"
    }
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
```

<!-- END-FULL-SOURCE -->

> The complete, fully-commented source lives in
> `lessons/part8-advanced/58-illegal-opcodes/58-illegal-opcodes.asm`.

### Code Walkthrough

#### Step 1 — The macros and the ROM layout

The four macros are the whole "instruction set extension" of this lesson:

```asm
!macro LAX_ZP .addr { !byte $A7, .addr }
!macro SAX_ZP .addr { !byte $87, .addr }
!macro DCP_ZP .addr { !byte $C7, .addr }
!macro ISB_ZP .addr { !byte $E7, .addr }
```

The rest of the ROM is a normal 4K cartridge: `* = $F000`, the reset entry, the frame skeleton, the visible kernel, the data tables, and the vectors at `$FFFA`. The build-time assertions guard the screen arithmetic: the five zones must total 192 lines, four 32-line rows must fill 128, and eight 16-line bands must fill the same 128.

#### Step 2 — RunLab: the four operations

`RunLab` runs once per frame in VBLANK. DCP and ISB modify their operands, so both are reset before every run; LAX only reads, and SAX overwrites its destination every time. The excerpt below is abridged: it shows the reset, the two `CLC`s, the four operations, and the checkpoints `LaxRead`, `SaxRead`, `SaxM`, `DcpRead`, `DcpM`, `IsbRead`, `FlagsRead`, and `IsbM`.

```asm
RunLab:
    LDA #$20
    STA DcpMem
    LDA #$10
    STA IsbMem

; --- LAX ---
    CLC
    +LAX_ZP LaxMem           ; ACME emits $A7 $90
LaxRead:                     ; A = $12, X = $12
    STA ResultBytes+0
    STA ResultA
    STX ResultX
    +SAVE_P FlagBytes+0      ; A stays $12 for the SAX

; --- SAX ---
    CLC
    LDX #$34
    +SAX_ZP SaxMem           ; ACME emits $87 $91
SaxRead:                     ; A = $12 (unchanged)
    LDA SaxMem
    STA ResultBytes+1
    +SAVE_P FlagBytes+1      ; A stays $10
SaxM:                        ; A = $10

; --- DCP ---
    LDA #$1F
    +DCP_ZP DcpMem           ; ACME emits $C7 $92
DcpRead:                     ; A = $1F, Z = 1, C = 1
    +SAVE_P FlagBytes+2
    LDA DcpMem
    STA ResultBytes+2
DcpM:                        ; A = $1F

; --- ISB ---
    LDA #$20
    SEC
    +ISB_ZP IsbMem           ; ACME emits $E7 $93
IsbRead:                     ; A = $0F
FlagsRead:                   ; P after ISB: C = 1, Z = 0
    +SAVE_P FlagBytes+3
    LDA FlagBytes+3
    STA Flags
    LDA IsbMem
    STA ResultBytes+3
    STA ResultM
IsbM:                        ; A = $11
```

The `+SAVE_P` macro is the subtle part. `PHP` pushes a copy of P with the B marker set; `PLA` would load that byte into A and destroy the operation's result. The macro saves A in `Tmp`, captures the flags, clears the B marker with `AND #$EF`, stores the live P, and restores A:

```asm
!macro SAVE_P .dest {
    STA Tmp
    PHP
    PLA
    AND #$EF
    STA .dest
    LDA Tmp
}
```

The two `CLC`s make the LAX/SAX carry deterministic, so the C column cannot inherit the previous frame's ISB carry. The result is a set of four live P bytes (`$24`, `$24`, `$27`, `$25`) and four result bytes (`$12`, `$10`, `$1F`, `$11`). The DCP pair proves the compare: A = `$1F` and the decremented memory = `$1F` leave Z = 1 and C = 1. The ISB pair proves the carry: `SEC` first, A = `$20` minus `$11` = `$0F`, C stays set.

#### Step 3 — The checksum

The checksum is one XOR chain over the four result bytes:

```asm
    LDA ResultBytes+0
    EOR ResultBytes+1
    EOR ResultBytes+2
    EOR ResultBytes+3
Checksum:
    STA ChecksumVal
```

`$12 ^ $10 = $02`, `$02 ^ $1F = $1D`, `$1D ^ $11 = $0C`. A stable `$0C` at the `Checksum` checkpoint is the compact proof that all four operations returned the documented bytes and that the display's input did not change.

#### Step 4 — BuildDisplay: from bytes to playfield

The 6502's flag columns need two different bit orders:

- **PF0** chunks 0–3 are the high nibble `N V 1 B`; PF0's bit 4 is the leftmost chunk, so the nibble is reversed with the 16-byte `Rev4` table before it is shifted into the high four bits.
- **PF1** chunks 4–7 are the low nibble `D I Z C`; PF1's bit 7 is chunk 4, so the nibble shifts straight up.

```asm
    LDA FlagBytes,X
    STA Tmp
    LSR
    LSR
    LSR
    LSR
    TAY
    LDA Rev4,Y
    ASL
    ASL
    ASL
    ASL
    STA RowF0,X
    LDA Tmp
    AND #$0F
    ASL
    ASL
    ASL
    ASL
    STA RowF1,X
```

`BarStart = 32 − result` turns each result byte into a threshold; the row kernel draws the PF2 bar when `Y >= BarStart`. The footer's checksum bytes are precomputed here too: `ChecksumPF1 = (checksum >> 2) & $3F` carries bits 7–2 to chunks 6–11, and `ChecksumPF2 = Rev2[checksum & $03]` carries bits 1–0 to chunks 12–13 with bit 1 at chunk 12 and bit 0 at chunk 13.

#### Step 5 — The frame and the marker

The frame is the Part 7/8 skeleton:

```asm
StartFrame:
    +vsync
VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    ; SELECT, the auto-demo clocks, RunLab, BuildDisplay
    LDA #(MARKER_X + POS_BIAS)
    JSR SetCoarseP0
    STA WSYNC
    STA HMOVE
    +wait_timer
    LDA #$00
    STA VBLANK
BodyStart:
```

`SetCoarseP0` is the Lesson 26 divide-by-15 dance. The marker's X is fixed at 32, so the same value is loaded every frame; the divide still runs, and one `STA HMOVE` applies the fine offset. There is no second HMOVE, and no motion register is rewritten within 24 cycles of the strobe.

#### Step 6 — The kernel zones

The kernel is a set of zone loops, each with its own playfield writes:

- **Title (16 lines).** A three-table read, `TitlePF0/1/2`, 31 cycles per line. The title spells "LAB" in 4-chunk glyphs inside a gold frame.
- **Labels (32 lines).** Four 8-line strips, unrolled so the byte line's PF1 write completes at cycle 27, before chunk 4. Line 0 is the opcode byte as eight chunks (PF0 bits 6–7 plus PF1 bits 7–2); line 1 is the illegal-cycle bar in PF2; line 2 is the documented bar (PF1 bit 0 plus PF2); lines 3–7 are blank. Both bars are right-aligned at chunk 19: LAX's 5 chunks are 15–19, SAX's 9 are 11–19, and DCP/ISB's 8 are 12–19. The documented bar is white, the byte and the illegal bar use the op's colour.
- **Setup gap (1 line).** A blank line absorbs the screen branch and the first zone's setup, so the first result row or cycle band starts with a full line of its own.
- **Result rows (screen 0, 128 lines).** Every line writes PF0/PF1 first, then the PF2 bar, then preloads the next line's marker into GRP0. The numbers are measured from `ResultLine`, not from the start of the scanline: PF0 by 7, PF1 by 14, PF2 by 24–26, the marker's `LDA` at ~40 and its `STA GRP0` at ~43. The WSYNC/loop tail runs at the top of the next line, so the absolute scanline PF0/PF1 are 14/21 on a normal line and 18/25 on the first line of rows 2–4 (the row-end `LDY #0`/`JMP` adds 5). A normal line ends at ~46–50 cycles; the `RowEnd` line ends at ~66, leaving about 10 of the 76 cycles unused. The next row's colour/PF2/BarCur are preloaded on the current row's last line after the playfield is drawn; the last row ends with `STA WSYNC` and jumps to the footer. This keeps the first line of every row complete — the old row setup wrote PF0 at 24–31 and PF1 at 31–38, so rows 2–4 began with the previous row's P bytes.
- **Cycle bands (screen 1, 128 lines).** Each 16-line band: separator, blank, two-line documented bar, blank, two-line illegal bar, nine blanks. The bars start at chunk 2 and use PF0 `$C0` plus a PF1 length table. The band index is advanced *before* the nine blank lines, so the next separator's tail is only the blank loop's last `DEY`/`BNE` and the loop test: its colour/PF0/PF1/PF2 are written by cycles 16/21/26/29, and the chunk-4 boundary is 28. (The old order left the tail at 11 cycles and put PF1 at 28, on the boundary.)
- **Footer (15 lines).** A white rule, six blank lines, and eight lines of checksum bits plus the screen indicator. The rule starts at chunk 0 on both screens; the last result row reaches the footer with its own `STA WSYNC`, so the rule's first write is at cycle 13.

#### Step 7 — The tables

The data tables are the lesson's static reference:

- `TitlePF0/1/2` — 16 rows of the "LAB" title.
- `OpBytePF0/1` — the four opcode bytes (`$A7`, `$87`, `$C7`, `$E7`) as eight chunks each.
- `OpIllegalPF2` — the 3- and 5-chunk illegal bars.
- `OpDocPF1/2` — the 5-, 9-, and 8-chunk documented bars.
- `OpColor` — green, blue, orange, purple.
- `MarkerStrip` — 33 bytes: 20 zeros, the 8×8 diamond, 5 zeros; `MarkerStrip+1,Y` is the next line's marker.
- `NextRowTab` — the row after X, wrapping 3 → 0.
- `Rev2` — the 2-bit reversal for the footer's checksum.
- `BandColor`, `BandDocPF1`, `BandIllPF1` — the eight cycle-table bands.
- `ScreenPF0Tab`, `ScreenPF2Tab` — the left/right screen indicator.
- `Rev4` — the 4-bit reversal for PF0's high nibble.

## What You Should See

At power-on the screen is the laboratory. The top is a gold "LAB" block, then four short label strips: each strip shows the opcode byte as a row of chunks, a short coloured illegal-cycle bar, and a longer white documented-cycle bar. Below a one-line gap are four 32-line rows — green LAX, blue SAX, orange DCP, purple ISB. Each row has eight flag columns at the left and a solid result bar at chunks 12–13; the bar heights are 18, 16, 31, and 17 lines. A gold diamond sits in the gap between the fields and steps down one row every 60 frames. The footer shows the checksum `$0C` as two chunks and a screen indicator at the left edge. The whole panel is reflected by `CTRLPF=$01`, so the right half repeats the left half.

After 240 frames (or a SELECT press) the second screen appears: eight 16-line bands, each with a coloured separator, a white documented bar, and a shorter coloured illegal bar. The first four bands match the four rows; the last four are SLO, RLA, SRE, and RRA in grey. The footer's indicator moves right of centre (chunks 17–18).

![Stella running the Lesson 58 ROM, screen 0: the gold LAB title, four byte/cycle label strips, four result rows (green LAX, blue SAX, orange DCP, purple ISB) with eight flag columns and result bars of 18, 16, 31 and 17 lines, a gold diamond marker on the LAX row, and a checksum footer; the title bar reads Stella 7.0: "58-illegal-opcodes"](/images/lesson58/lab-a.png)

*`lab-a`: the four result rows. The LAX bar is 18 lines, SAX 16, DCP 31, ISB 17. The marker (gold `$1A`) sits on the LAX row at chunks 8–9, lines 20–27. The footer's left indicator marks screen 0, and the checksum `$0C` lights chunks 10–11.*

![Stella running the Lesson 58 ROM, screen 1: the cycle table with eight 16-line bands for LAX, SAX, DCP, ISB, SLO, RLA, SRE and RRA; each band has a white documented bar and a shorter coloured illegal bar; the footer indicator is right of centre at chunks 17–18; the title bar reads Stella 7.0: "58-illegal-opcodes"](/images/lesson58/lab-b.png)

*`lab-b`: the cycle table. The documented bars are 5, 9, 8, 8, 8, 8, 8, 8 chunks; the illegal bars are 3, 3, 5, 5, 5, 5, 5, 5. The footer's right-of-centre indicator marks screen 1.*

<RomPlayer rom="/roms/part8-advanced/58-illegal-opcodes/58-illegal-opcodes.bin" title="Lesson 58 — Illegal Opcodes" />

Javatari starts muted; this ROM is silent, so there is nothing to unmute. The ROM uses no mapper beyond a plain 4K cartridge, so every 2600 emulator can run it.

> **Capture method.** Both images are window captures of
> `docs/public/roms/part8-advanced/58-illegal-opcodes/58-illegal-opcodes.bin`
> in Stella 7.0, launched with a fresh Stella base directory, `-audio.enabled 0`,
> a fixed 3× zoom, and a fixed window position. The window is 1010×807
> including the title bar. The pointer was parked at `(0, 0)` before each
> capture, so the images contain no cursor. A burst of window captures was taken
> while the auto-demo ran; the screen-0 and screen-1 frames were selected by the
> footer indicator (left = screen 0, right = screen 1). The title bars read
> `Stella 7.0: "58-illegal-opcodes"`. No modified ROM was used.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
ROM=docs/public/roms/part8-advanced/58-illegal-opcodes/58-illegal-opcodes.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F04A' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F058' $ROM   # VblankStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0D1' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F319' $ROM   # OverscanStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F065' $ROM   # Frame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F337' $ROM   # LaxRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F34C' $ROM   # SaxRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F35A' $ROM   # SaxM
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F35E' $ROM   # DcpRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F36C' $ROM   # DcpM
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F371' $ROM   # IsbRead / FlagsRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F385' $ROM   # IsbM
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F38D' $ROM   # Checksum
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0B7' $ROM   # Screen
```

| Checkpoint | Address | Measured | Meaning |
|---|---|---|---|
| `StartFrame` | `$F04A` | 259/3 steady; 34/20 on the power-on frame | the first VSYNC instruction |
| `VblankStart` | `$F058` | 0/5 | the first VBLANK instruction |
| `BodyStart` | `$F0D1` | 37/5 | the first visible-line instruction |
| `OverscanStart` | `$F319` | 229/6 | the first overscan instruction |
| `Frame` | `$F065` | A = 1, 2, 3, 4, … | the new frame count |
| `LaxRead` | `$F337` | A = `$12`, X = `$12` | LAX left A = X = M |
| `SaxRead` | `$F34C` | A = `$12`, X = `$34` | SAX did not change A |
| `SaxM` | `$F35A` | A = `$10` | the SAX memory result |
| `DcpRead` | `$F35E` | A = `$1F`; P = Z1 C1 | DCP decremented and compared |
| `DcpM` | `$F36C` | A = `$1F`, C = 1 | the DCP memory result |
| `IsbRead` | `$F371` | A = `$0F` | ISB incremented and subtracted |
| `FlagsRead` | `$F371` | P = C1, Z0 | the ISB flags |
| `IsbM` | `$F385` | A = `$11` | the ISB memory result |
| `Checksum` | `$F38D` | A = `$0C` | the XOR of the four results |
| `Screen` | `$F0B7` | A = 0 or 1 | the selected screen |

The state log's frame, scanline, and cycle fields are the evidence:

```text
BP:           0  34 20  -8 | nv-BdIZc 00 ff 00 ff |   # StartFrame, power-on frame
BP:           1 259 03 -59 | nv-BdIZC 00 00 00 ff |   # StartFrame, steady state
BP:           2 259 03 -59 | nv-BdIZC 00 00 00 ff |
BP:           3 259 03 -59 | nv-BdIZC 00 00 00 ff |
BP:           1   0 05 -53 | nv-BdIZc 00 ff 00 ff |   # VblankStart
BP:           2   0 05 -53 | nv-BdIZC 00 00 00 ff |
BP:           3   0 05 -53 | nv-BdIZC 00 00 00 ff |
BP:           1  37 05 -53 | nv-BdIZC 00 04 00 ff |   # BodyStart
BP:           2  37 05 -53 | nv-BdIZC 00 04 00 ff |
BP:           3  37 05 -53 | nv-BdIZC 00 04 00 ff |
BP:           1 229 06 -50 | nv-BdIZC 00 00 00 ff |   # OverscanStart
BP:           2 229 06 -50 | nv-BdIZC 00 00 00 ff |
BP:           3 229 06 -50 | nv-BdIZC 00 00 00 ff |
BP:           1   0 24   4 | nv-BdIzc 01 ff 00 ff |   # Frame, A=1
BP:           2   0 24   4 | nv-BdIzC 02 00 00 ff |   # Frame, A=2
BP:           3   0 24   4 | nv-BdIZC 03 00 00 ff |   # Frame, A=3
BP:           1   1 22  -2 | nv-BdIzc 12 12 00 fd |   # LaxRead, A=X=$12
BP:           2   1 22  -2 | nv-BdIzc 12 12 00 fd |
BP:           1   1 56 100 | nv-BdIzc 12 34 00 fd |   # SaxRead, A=$12, X=$34
BP:           2   1 56 100 | nv-BdIzc 12 34 00 fd |
BP:           1   2 04 -56 | nv-BdIzc 10 34 00 fd |   # SaxM, A=$10
BP:           2   2 04 -56 | nv-BdIzc 10 34 00 fd |
BP:           1   2 11 -35 | nv-BdIZC 1f 34 00 fd |   # DcpRead, A=$1F, Z=1, C=1
BP:           2   2 11 -35 | nv-BdIZC 1f 34 00 fd |
BP:           1   2 35  37 | nv-BdIzC 1f 34 00 fd |   # DcpM, A=$1F, C=1
BP:           2   2 35  37 | nv-BdIzC 1f 34 00 fd |
BP:           1   2 44  64 | nv-BdIzC 0f 34 00 fd |   # IsbRead / FlagsRead, A=$0F, C=1, Z=0
BP:           2   2 44  64 | nv-BdIzC 0f 34 00 fd |
BP:           1   3 01 -65 | nv-BdIzC 11 34 00 fd |   # IsbM, A=$11
BP:           2   3 01 -65 | nv-BdIzC 11 34 00 fd |
BP:           1   3 13 -29 | nv-BdIzC 0c 34 00 fd |   # Checksum, A=$0C
BP:           2   3 13 -29 | nv-BdIzC 0c 34 00 fd |
BP:           1   1 01 -65 | nv-BdIZc 00 ff 00 ff |   # Screen, A=0
BP:           2   1 01 -65 | nv-BdIZc 00 00 00 ff |
```

The flag string is `N V - B D I Z C`; uppercase means set. The debugger shows the 6502's B bit as set in the displayed string (`B`), because that is how the P register presents bit 4; the stored `FlagBytes` clear bit 4 with `AND #$EF`. So `nv-BdIZC` at `DcpRead` is N=0, V=0, B=1 (display only), D=0, I=1, Z=1, C=1. `nv-BdIzC` at `FlagsRead` is the same with Z=0: the ISB subtraction produced `$0F`, so Z is clear and the carry is set.

The pixel checks decode the captures with `x = 25 + 6 × TIA X` for the visible picture and `y = 107 + 3.156 × visible line`:

| Check | `lab-a.png` | `lab-b.png` | Expected |
|---|---|---|---|
| full image | 1010×807 | 1010×807 | window plus title bar |
| title bar | `Stella 7.0: "58-illegal-opcodes"` | the same | the committed ROM |
| background | `$00` (0,0,0) | the same | black page |
| reflection | `CTRLPF=$01`: left chunk n is mirrored at chunk 39−n | the same | the intended symmetric panel |
| title block | gold `$1A` (205,205,52), visible 0–15, mirrored on the right | the same | frame and "LAB" |
| label strips | four 8-line strips, visible 16–47, mirrored on the right | the same | byte and cycle bars |
| setup gap | one blank line, visible 48 | the same | the branch/setup line |
| middle | four rows, visible 49–176 | eight bands, visible 49–176 | 128 lines |
| band separators | all eight at x=73–505 and 505–985, chunk 4 lit | all eight | no chunk-4 notch |
| row colours | green `$C8`, blue `$84`, orange `$38`, purple `$66`, mirrored on the right | the four band colours | the opcode colours |
| LAX bar | x=313–360 and mirror x=649–697, y=306–361 (18 lines) | band 0 documented 5 chunks, illegal 3 | `$12` |
| SAX bar | x=313–360 and mirror x=649–697, y=413–463 (16 lines) | band 1 documented 9, illegal 3 | `$10` |
| DCP bar | x=313–360 and mirror x=649–697, y=467–564 (31 lines) | band 2 documented 8, illegal 5 | `$1F` |
| ISB bar | x=313–360 and mirror x=649–697, y=612–665 (17 lines) | band 3 documented 8, illegal 5 | `$11` |
| flag columns | LAX/SAX chunks 2,5; DCP 2,5,6,7; ISB 2,5,7 (each with its mirror) | — | the four P bytes |
| marker | gold (205,205,52), x=217–264, y=325–348 | — | chunks 8–9, row 0 lines 20–27 |
| label byte rows | `$A7`/`$87`/`$C7`/`$E7` at chunks 2–9 (mirror 30–37) | — | the four opcode bytes |
| label bars | right-aligned at chunk 19: LAX 5 at 15–19, SAX 9 at 11–19, DCP/ISB 8 at 12–19; illegal 3/5 at 17–19/15–19; mirrored on the right | — | shared right edge |
| row first lines | DCP chunks 2,5,6,7 at visible 113; ISB 2,5,7 at visible 145 (each with its mirror) | — | each row's own P on line 0 |
| footer rule | y=666–667, x=25–985 | y=666–667, x=25–985 | the white rule |
| checksum | chunks 10–11 (x=265–313) and 28–29 (x=697–745), y=687–712 | the same | `$0C` |
| screen indicator | screen 0: chunks 1–2 (x=49–97) and 37–38 (x=913–961) | screen 1: chunks 17–18 (x=433–481) and 21–22 (x=529–577) | screen 0 / screen 1 |
| cursor | none | none | pointer parked at (0,0) |

The static opcode table and the macros match the bytes in the committed ROM:

| Macro call | Emitted bytes | In the ROM at |
|---|---|---|
| `+LAX_ZP LaxMem` | `A7 90` | `$F335` |
| `+SAX_ZP SaxMem` | `87 91` | `$F34A` |
| `+DCP_ZP DcpMem` | `C7 92` | `$F35C` |
| `+ISB_ZP IsbMem` | `E7 93` | `$F36F` |

## Exercises

### Exercise 1: LAX Replaces a LDA/TAX Pair

**Challenge:** replace a documented `LDA $80` / `TAX` pair with `LAX $80` and show that A and X are identical, while the cycle count drops from 5 to 3. The screen must make the saving visible as well as the values.

**Hints:**
1. `LDA $80` costs 3 cycles and `TAX` costs 2; `LAX $80` costs 3 and loads both registers from the same byte.
2. Run both sequences once at startup, store A and X from each, and display the four bytes as two identical A/X field pairs.
3. Draw the documented row with a 5-line cycle bar and the LAX row with a 3-line bar; the 2-cycle difference is the saved bar in the title band.
4. The state log's `LaxRead` must show A = X = `$42`; the `Saved` checkpoint must show A = 2.

**Expected Result:** the ROM assembles to 4,096 bytes. Both rows show the same A field (PF1 = `$42`) and X field (PF2 = `$42`); the documented row's bar is five lines tall, the LAX row's is three, and the title band carries a two-chunk gold "saved" bar. `PairA` reports A = `$42`, `PairX` reports X = `$42`, `LaxRead` reports A = `$42` and X = `$42`, and `Saved` reports A = 2. The frame stays at `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: A DCP Countdown

**Challenge:** use DCP for a countdown and branch on its flags. The counter starts at 32, steps down once every 15 frames, and when it reaches zero the screen flashes and the counter reloads.

**Hints:**
1. Set A = 0 and use `DCP Counter`. The instruction decrements the memory byte and compares 0 with the new value, so Z is set exactly when the counter reaches 0.
2. `BEQ ReachedZero` is the branch. On the zero path, set a pause counter and change `COLUBK`; while the pause is active, skip the DCP so the flags stay stable.
3. Draw the counter as a bar whose height is `Counter × 2`. `BarStart = 64 − (Counter × 2)`; the bar is on when the line counter is at or past `BarStart`.
4. Show the live P byte as eight chunks in the status band (`PF1 = P`) and a two-chunk zero indicator at `PF0`.

**Expected Result:** the ROM assembles to 4,096 bytes. The green bar shrinks from 64 lines to nothing over 32 counts (about eight seconds at 15 frames per count), the background flashes red at zero, and the bar refills. `DcpCount` reports A = `$1F`, `$1E`, `$1D`, … on successive steps; `ReachedZero` reports A = 0 with Z = 1 and C = 1; `DcpFlags` reports the same Z/C pair at the `PHP`, and `CountFlags` is the capture path. The frame stays at 259/3, 0/5, 37/5, 229/6.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The SAX/LAX Mask

**Challenge:** use `SAX $81` to store A AND X, then `LAX $81` to load the same byte back into both registers, and display the result. Use A = `$F0` and X = `$3C`, so the mask is `$30`.

**Hints:**
1. `SAX $81` stores `A & X` = `$F0 & $3C` = `$30`; it changes no flags.
2. `LAX $81` loads A = X = `$30`; the two registers now hold the masked value.
3. Draw the result as a 48-line bar at chunks 2–3 in a 64-line zone (`BarStart = 64 − 48 = 16`).
4. Show the inputs in the status band: `PF1 = $F0` (A) and `PF2 = $3C` (X), each as an eight-chunk field.

**Expected Result:** the ROM assembles to 4,096 bytes. The status band shows the two input fields; the result bar is 48 lines tall at the left. `SaxStore` reports A = `$F0` and X = `$3C`; `SaxMem` reports A = `$30`; `LaxLoad` reports A = `$30` and X = `$30`. The frame stays at 259/3, 0/5, 37/5, 229/6.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **Undocumented is not imaginary.** The NMOS 6502/6507 decodes and runs the stable undocumented opcodes; the 6507 is a standard 6502 die with fewer pins.
- ✅ **Use the stable set only.** LAX, SAX, DCP, ISB, SLO, RLA, SRE, and RRA behave the same on every NMOS die; the unstable group (ANE, LXA, SHA, SHX, SHY, TAS, LAS, KIL/JAM) can depend on the bus, the address, the temperature, or the chip.
- ✅ **The four lab operations are exact.** LAX leaves A = X = M; SAX stores A AND X; DCP decrements and compares; ISB increments and subtracts. The measured results are `$12`, `$10`, `$1F`, `$11`, and the checksum is `$0C`.
- ✅ **The saving is real but bounded.** LAX saves 2 cycles, SAX 6, DCP 3, ISB 3 over the documented sequences; the byte saving is 1, 4, 2, and 2. Use it where the budget is tight, not by default.
- ✅ **ACME 0.97's 6502 mode needs `!byte` macros.** There is no `6502i` type; `!cpu 6502` rejects the mnemonics and `!cpu 6510` accepts them (`ISC` for ISB), so the named macros emit `$A7`, `$87`, `$C7`, and `$E7` and keep the opcode table honest.
- ✅ **The 65C02 is a different CPU.** Many undocumented slots became NOPs or new instructions; a ROM that uses them is an NMOS 6502/6507 ROM.
- ✅ **Comment every use.** Name the opcode, its byte, the documented equivalent, and why the saving is justified. If you cannot write that sentence, use the documented sequence.

## What's Next

The undocumented opcodes change what a single instruction can do. [Lesson 59: Self-Modifying Code — The Ultimate 6502 Trick](/part8-advanced/59-self-modifying-code) changes the *program*: it copies a routine into the 128 bytes of RIOT RAM, patches its operand every scanline, and executes it. That is the other way to get more out of a cartridge that cannot be written.
