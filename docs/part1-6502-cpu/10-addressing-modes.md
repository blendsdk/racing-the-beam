---
title: "Lesson 10: Addressing Modes — How the CPU Finds Data"
description: "The full 6502 addressing-mode catalog: immediate, zero page and its indexed and indirect forms, absolute and indexed, relative branches, and the one indirect jump — with byte lengths, cycle costs, the zero-page wrap hazard, and an experiment where six bands paint one byte six different ways."
prev:
  text: "Lesson 09: Bitwise Operations"
  link: "/part1-6502-cpu/09-bitwise-operations"
next:
  text: "Lesson 11: Lookup Tables"
  link: "/part1-6502-cpu/11-lookup-tables"
---

# Lesson 10: Addressing Modes — How the CPU Finds Data

> **Part 1: The 6502 CPU** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 04 (registers, load/store, immediate/zero-page/absolute addressing), Lesson 07 (branches and loops), Lesson 08 (subroutines, register contracts, and indexed table reads), Lesson 09 (`EOR` and the bit operations)
> **You will learn:** the complete addressing-mode catalog — implied, accumulator, immediate, zero page, zero page,X/,Y, absolute, absolute,X/,Y, relative, indirect, `(zp,X)`, and `(zp),Y`; what each mode costs in bytes and cycles and why; the zero-page wrap hazard that silently reads the TIA; how far a branch can reach; and how the index registers turn one load instruction into a table reader
> **You will build:** a "same byte, several ways" ROM — the byte `$42` lives at RAM `$82` and six identical top bands each fetch it by a different route; six more bands turn `LDA Ramp,Y` into a table-driven ramp. The theory demo `demo-10.asm` ladders all twelve data modes, one band per mode.

## Introduction

Lesson 04 introduced three ways to name data — immediate (`LDA #$42`), zero page (`LDA $82`), and absolute (`LDA $0082`) — and every lesson since has quietly used more of them. Lesson 08 read `LDA BandColors,X` to pick a band color; Lesson 09 shifted `LSR Mask` once per band. Those spellings were *given* to you. This lesson names the system behind them: the **addressing modes**, the rules the CPU uses to turn an instruction's operand bytes into an address.

An addressing mode is not a property of your program; it is part of the *opcode*. `LDA #$42` and `LDA $42` share a mnemonic but are different instructions, with different opcodes, different lengths, and different cycle counts. Learning the catalog is learning what the operand field can mean: a literal, a zero-page address, a 16-bit address, an address plus an index, a *pointer* to an address, or (for branches) a signed distance from the next instruction. Most of the 2600's reputation for tight, clever code comes from choosing among these deliberately — the same data, found by a cheaper or dearer route.

The companion program `10-addressing-modes.asm` makes that concrete: it stores `$42` **once**, at RAM `$82`, and then paints the top half of the screen as six identical bands, each fetched by a different mode. All six are `$42` on screen, because all six arrive in the accumulator with the same value — but the routes differ, and the debugger checkpoints prove it band by band. The bottom half adds the mode that makes tables possible: `LDA Ramp,Y`, one instruction reading six different values. The theory demo `demo-10.asm` goes further and builds a twelve-band "mode ladder" where band *k* exercises the *k*-th **data** mode in catalog order (relative excepted — it has no band).

::: details TypeScript Equivalent
A modern language gives you a handful of operand forms, and the compiler picks the machine instruction. The 6502 asks *you* to pick:

```typescript
const literal   = 0x42;                 // LDA #$42     — immediate
const variable  = ram[0x82];            // LDA $82      — zero page
const sameAgain = ram[0x0082];          // LDA $0082    — absolute
const indexed   = ram[0x80 + x];        // LDA $80,X    — zero page,X
const table     = rom[0xF100 + y];      // LDA Ramp,Y   — absolute,Y
const through   = ram[ram[0x80] + y];   // LDA ($80),Y  — (zp),Y
```

The analogy breaks in three places, and each break is the lesson:

- **There is no one `[]` operator.** Each of those lines is a *different instruction* on the 6502 — a different opcode, a fixed length (2 or 3 bytes), and a fixed base cycle count. Choosing a mode is choosing the instruction, so the mode list is finite: thirteen of them for the whole CPU.
- **Address arithmetic has a fixed width per mode.** `ram[0x80 + x]` in TypeScript is 32-bit (or whatever your `number` is) and never wraps by accident; `LDA $80,X` adds in **eight bits** and wraps inside page `$00`. `LDA $0080,X` adds in sixteen. The mode decides.
- **No expressions.** You cannot write `LDA Table + Y*2`. The operand is assembled once; if the address needs arithmetic at run time, you do it in registers or put the pointer in zero page and use `(zp),Y`.
:::

## Theory

### Section 1: The Catalog — Thirteen Modes in One Table

Every operand a 6502 instruction can take belongs to exactly one of these modes. The table gives the syntax this course uses, an example, the instruction's size, and the cycles it takes. The sizes and the listed cycles are for `LDA`; the rest of the *read* family (`ADC`, `SBC`, `AND`, `ORA`, `EOR`, `CMP`, `BIT`) shares them, but each instruction has its own costs. Stores pay the index cycle unconditionally (`STA abs,X` and `STA abs,Y` are always 5, not 4+1), and read-modify-write instructions cost more (`INC`/`DEC`/`ASL`/`LSR`/`ROL`/`ROR` on a zero-page byte is 5, not 3). Check the instruction's own entry before counting cycles.

| # | Mode | Syntax | Example | Bytes | Cycles |
|:--:|------|--------|---------|:-----:|:------:|
| 1 | Implied | *(no operand)* | `TAX`, `INX`, `CLC` | 1 | 2 |
| 2 | Accumulator | *(no operand)* | `ASL`, `LSR`, `ROL`, `ROR` | 1 | 2 |
| 3 | Immediate | `#value` | `LDA #$42` | 2 | 2 |
| 4 | Zero page | `$nn` | `LDA $82` | 2 | 3 |
| 5 | Zero page,X | `$nn,X` | `LDA $82,X` | 2 | 4 |
| 6 | Zero page,Y | `$nn,Y` | `LDX $82,Y` | 2 | 4 |
| 7 | Absolute | `$nnnn` | `LDA $0082` | 3 | 4 |
| 8 | Absolute,X | `$nnnn,X` | `LDA $F100,X` | 3 | 4 (+1) |
| 9 | Absolute,Y | `$nnnn,Y` | `LDA Ramp,Y` | 3 | 4 (+1) |
| 10 | Relative | branch target | `BNE RampLoop` | 2 | 2 (+1 taken, +1 more on a page cross) |
| 11 | Indirect | `(address)` | `JMP (BandPtr)` | 3 | 5 |
| 12 | Indexed indirect | `(zp,X)` | `LDA (PtrTab,X)` | 2 | 6 |
| 13 | Indirect indexed | `(zp),Y` | `LDA (PtrTab),Y` | 2 | 5 (+1) |

Four columns of fine print:

- **"Bytes" is the whole instruction**: opcode plus operands. `LDA #$42` is two bytes (`A9 42`); `LDA $0082` is three (`AD 82 00`). Longer modes cost ROM *and* fetch cycles — the extra operand byte has to be read.
- **"(+1)" means "plus one cycle if the index addition crosses a page boundary."** `LDA $F0F8,X` with X = 10 crosses from page `$F0` into `$F1` and costs 5. It is the same instruction and the same value either way; only the timing changes — and in a kernel, timing is the picture.
- **The two shift rows are one-byte instructions**: implied and accumulator modes have no operand field at all. The instruction *is* the whole opcode. In ACME, the accumulator form of a shift is written bare — `ASL`, `LSR`, `ROL`, `ROR` — with no operand.
- **The modes are per instruction, not universal.** `LDA` has eight of them (there is no `LDA` zero page,Y, and no indirect `LDA`); `STA` has no immediate (you can store a register, not a number); `JMP` has exactly two (absolute and indirect); `LDX` and `STX` are the zero page,Y users; `LDY` and `STY` are the zero page,X users. When an instruction refuses a mode, the assembler tells you — but it is worth knowing which pairs exist before you plan around one.

::: tip Why there is more than one "indexed" family
The five indexed modes differ in *what gets indexed*:

- `$nn,X` / `$nnnn,X` — the **address** is indexed: use them to read `table[x]`.
- `(zp,X)` — the **pointer's location** is indexed: X picks a two-byte pointer out of a table of pointers, then the CPU reads through it.
- `(zp),Y` — a **fixed pointer** is read, and Y is added to the address it contains: one pointer, many bytes.

That is the whole family tree; the lesson's ROM and demo use one of each.
:::

### Section 2: Same Byte, Several Ways

The lesson ROM performs a controlled experiment. At startup it writes `$42` to RAM `$82` **once** and never writes it again, and it stores the 16-bit address `$0082` into the zero-page pair `$80/$81`. Then, every frame, six bands show that same `$42` — five fetch it from `$82`, and the sixth carries it as a literal:

| Band (from the top) | Mode | The fetch | A at the checkpoint |
|:---:|---|-----------------------|:---:|
| 0 | Immediate | `LDA #$42` | `$42` |
| 1 | Zero page | `LDA $82` | `$42` |
| 2 | Absolute | `LDA $0082` | `$42` |
| 3 | Zero page,X | `LDX #$00` / `LDA $82,X` | `$42` |
| 4 | Absolute,X | `LDX #$00` / `LDA $0082,X` | `$42` |
| 5 | Indirect indexed | `LDY #$00` / `LDA ($80),Y` | `$42` |

All six bands are the same color on screen, and that is the point: five different *routes* to one byte, plus one instruction that never touches memory at all. The last column names the value each fetch leaves in A at its debugger checkpoint — one label per fetch, all six reachable in a running frame.

The ROM's own bytes show the difference directly — this is the top half of the kernel as assembled (opcode bytes on the left, the fetch they perform and the effective address on the right):

```text
    A9 42           LDA #$42        ; 2 bytes — the value is the operand
    A5 82           LDA $82         ; 2 bytes — one-byte address
    AD 82 00        LDA $0082       ; 3 bytes — two-byte address
    B5 82           LDA $82,X       ; 2 bytes — address + X, still page 0
    BD 82 00        LDA $0082,X     ; 3 bytes — 16-bit address + X
    B1 80           LDA ($80),Y     ; 2 bytes — pointer + Y
```

Five of the six fetches — zero-page, absolute, zero-page,X, absolute,X, and `(zp),Y` — end at the same RAM cell; the immediate fetch is not a route at all, it is the destination written out in full. The distinction is testable: set RAM `$82` to another value in the debugger and the five memory bands change color on the next frame while the immediate band stays `$42`. The literal is in the instruction stream; nothing in RAM can change it.

### Section 3: Zero Page — Fast, and Two Kinds of Trap

Zero page is the 2600's natural home: RAM is exactly `$80–$FF`, so *every* variable you declare is a zero-page address, and every access is the cheap two-byte, three-cycle form. Two consequences deserve care.

**The pointer modes live here too.** `LDA ($80),Y` does not name an address — it names **two bytes that hold an address**. The CPU reads `$80` and `$81`, forms the 16-bit address `$0082`, adds Y to it, and reads *that*. This is how a program walks a buffer whose base is decided at run time. Because all of a 2600's variables already live in zero page, the pointer costs nothing extra to place.

The two indirect forms index different things, and the demo ROM shows both side by side:

| Mode | What X or Y does | In `demo-10.asm` |
|------|------------------|------------------|
| `(zp,X)` | X is added to the **pointer slot number**: X = 2 selects the pointer two bytes along. | The demo sets two pointers at `$8C`/`$8E` during `Reset`; band 10's X = 2 selects the second, which points at `Ramp+10` (`!byte` value `$7E`). |
| `(zp),Y` | The pointer slot is fixed; Y is added to the **address** it contains. | Band 11 reads the pointer at `$8C` (`$0080`) and adds Y = 11 to walk to the twelfth byte of the RAM copy. |

**Trap one: the wrap.** Zero page indexed modes add the index in **eight bits and throw the carry away**. `LDA $80,X` with X = `$80` computes `$80 + $80 = $100`, drops the carry, and reads `$00` — which on the 2600 is not memory at all but an address in TIA space: `$00` *reads* as `CXM0P`, the missile 0 / player collision register. (The intended address is not a variable either: the 2600's RAM ends at `$FF`, so there is no RAM cell "128 past `$80`" to find.) The load does not fault; it silently returns hardware state. Two guards: keep the base and index so their sum stays inside `$00–$FF`, or use a mode whose arithmetic is sixteen bits wide — `$0080,X`, `$0080,Y`, or a `(zp),Y` pointer. Exercise 3 is built on this trap.

**Trap two: the pointer's own address.** The operand of an indirect mode names the *location of the pointer*, not the target. `LDA ($80),Y` reads a pointer at `$80/$81`; if you meant "read the byte at `$80`", you wanted plain `LDA $80`. It is the same "`#` means literal" confusion as Lesson 04, one level up: the operand can be a value, an address, or the address *of* an address.

::: details TypeScript Equivalent
A pointer in TypeScript is a reference you rarely think about; on the 6502 it is two bytes in zero page, and the offsets are mode-specific:

```typescript
// TypeScript: one array, one index — width is an implementation detail.
const buffer = rom.slice(0xF100, 0xF10C);
const byte = buffer[y];            // y is at least a 32-bit value

// 6502: the width is chosen by the mode you write.
//   LDA $80,X     -> ($80 + X) & $FF     — eight bits, wraps in page 0
//   LDA $0080,X   -> $0080 + X           — sixteen bits, +1 cycle on page cross
//   LDA ($80),Y   -> ram[$80..$81] + Y   — sixteen bits, carry propagates
```

The wrap is the analogy's sharpest break: `buffer[y]` in a modern language always reads the array it names, but `LDA $80,X` with X = `$80` silently reads TIA address `$00` instead of the `$100` you asked for.
:::

### Section 4: Index Registers Select Table Entries

The bottom half of the lesson ROM is the pattern that turns one instruction into a table reader:

```asm
    LDY #$00                ; Y = the table index: entry 0 is the first band
RampLoop:
    LDA Ramp,Y              ; ABSOLUTE,Y: one instruction reads six colors
RampFetch:                  ; debugger checkpoint: break here, A = Ramp[Y]
    LDX #LINES
    JSR PaintBand           ; PaintBand preserves Y: it can index the table
    INY                     ; next table entry
    CPY #RAMP_BANDS         ; 0 ... 5 — the loop stops at the table's edge
    BNE RampLoop
```

`Ramp` is a six-byte table of colors in ROM; Y selects the entry, `PaintBand` paints the band with it, and the loop advances Y. Two details make this pattern safe and cheap:

- **The table is page-aligned, and the index is bounded.** The ROM places `Ramp` at the start of a page (the `!align 255, 0, 0` before it), so Y = 0…5 cannot push the address past `$F1FF` — the load costs exactly 4 cycles every time. The loop's `CPY #RAMP_BANDS` stops Y at the table's edge, which is the discipline that prevents "one entry too many": an index that walks off the end reads whatever the assembler put next.
- **`PaintBand` preserves Y.** Lesson 08's register contract was built for exactly this: the painter uses X as its line counter and never touches Y, so the table loop can keep its index in Y across the call without saving it. (A subroutine that clobbered Y would force a `TYA`/`PHA`/`PLA`/`TAY` round trip around every band.)

The index registers deserve one more warning: the instruction sets are *not* symmetric. `LDA $nn,Y` does not exist — zero page,Y is an `LDX`/`STX` mode. If you want a byte from a table in RAM and you are loading into A, you write `LDA $nn,X`, or you accept the three-byte `LDA $nnnn,Y` with the table at a 16-bit address. That asymmetry is why the demo's band 5 uses `LDX RampCopy,Y` and then `TXA` to get the byte into A.

### Section 5: Branches Are Relative; `JMP (indirect)` Is the Only Indirect Jump

**Relative mode is for control flow only.** Every conditional branch (`BEQ`, `BNE`, `BCC`, `BCS`, …) takes a two-byte instruction whose operand is a **signed offset from the address of the next instruction**, not an address. The offset is assembled from a label, so you write `BNE RampLoop` and the assembler does the subtraction — but the reach is limited to **−128 … +127 bytes**. A label farther away is a hard assembler error ("branch out of range"), and the fix is to invert the condition and `JMP`, or insert a nearby trampoline. Two timing notes: a taken branch costs one extra cycle, and a taken branch that crosses a page boundary costs one more. Not-taken branches are always 2 cycles — which is why kernels count their branches.

Unconditional `JMP` is different: it takes an absolute address (3 bytes, 3 cycles) — or, in the one indirect mode in the whole instruction set, `JMP (address)` (3 bytes, 5 cycles):

```asm
    JMP (BandPtr)           ; INDIRECT: read the target address from $83/$84
```

`JMP (BandPtr)` reads a 16-bit address out of the two bytes at `$83/$84` and jumps there. This makes **the destination itself data**: change those two bytes and the same program continues somewhere else. The lesson ROM uses it to reach its painter, and the demo uses it for band 9's loader.

Two practicalities:

- **The NMOS `JMP ($xxFF)` bug.** If the pointer's *low byte* is `$FF`, the NMOS 6502 fetches the target's high byte from `$xx00` — the same page — instead of `$(xx+1)00`. `JMP ($F0FF)` therefore jumps to an address built from `$F0FF` (low byte) and `$F000` (high byte). The fix is placement, not code: keep the pointer away from a page boundary. In this ROM the pointer is at `$83/$84`, so the bug cannot apply. It is documented here because it is *the* classic indirect-jump story — and because emulators reproduce it faithfully, so a program that "works" in one placement and breaks in another is telling you exactly this.
- **Calling through a pointer.** There is no `JSR (indirect)`. The idiom is a two-byte trampoline: `JSR` to a `JMP (pointer)`, and let the *callee's* `RTS` use the return address the `JSR` already pushed.

```asm
PaintBandViaPtr:
    JMP (BandPtr)           ; INDIRECT: read the target address from $83/$84
```

Band 0 calls the painter with `JSR PaintBandViaPtr`: the `JSR` pushes the return address, the indirect `JMP` reads `BandPtr` and lands on `PaintBand`, and `PaintBand`'s `RTS` pops the pushed address and comes back to the instruction after the `JSR`. Change `$83/$84` to another routine's address and every frame calls *that* routine instead — no kernel change required.

### Section 6: Choosing a Mode

A short decision list, in the order the choices usually come up:

1. **A constant?** Immediate. Nothing is faster than data already in the instruction stream.
2. **A variable?** Zero page — on the 2600 that is not an optimization, it is just where RAM is.
3. **One of many values in a table?** Absolute,X / absolute,Y (`LDA Ramp,Y`), after bounding the index.
4. **A table whose base is decided at run time?** `(zp),Y` — one pointer, any base.
5. **One of several pointers?** `(zp,X)` — X selects the pointer slot.
6. **Something at `$100` or beyond, computed?** Never zero page indexed without checking the wrap; use `$0080,X` or a pointer.
7. **A decision?** A relative branch, within ±127 bytes; an unconditional jump needs absolute (`JMP label`) or indirect (`JMP (ptr)`).

The cycle column is not decoration: in a kernel every cycle of every line is accounted for, and the difference between a 3-cycle and a 5-cycle fetch is 2/76ths of a scanline, every line, forever. Choosing the cheap mode is how kernels stay in their budget.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's two ROMs directly with ACME:

```bash
acme -f plain -o build/lesson10.bin \
  lessons/part1-6502-cpu/10-addressing-modes/10-addressing-modes.asm
acme -f plain -o build/demo10.bin \
  lessons/part1-6502-cpu/10-addressing-modes/demo-10.asm
```

Then run either one in Stella:

```bash
stella build/lesson10.bin
stella build/demo10.bin
```

### Full Source

The program lives in one frame loop: initialize the shared byte and the two pointers, then paint twelve 16-line bands — the six mode fetches, then the six-entry table ramp. The picture is 192 non-blanked scanlines: band 0's color is pre-loaded while the beam is blanked, so the beam-release line is band 0's *first* line and `PaintBand` paints the other 15; every other band is one `PaintBand` call of 16 lines. The blank-on after the last band waits for HBLANK first (`STA WSYNC`), so the last band line is painted whole.

```asm
; =============================================================================
; LESSON 10: Addressing Modes — How the CPU Finds Data
; =============================================================================
; Part 1: The 6502 CPU
;
; What this program does:
;   "Same byte, several ways": TWELVE bands of 16 scanlines each.  The TOP
;   six bands all show the SAME value — the byte at RAM $82, which holds $42
;   — but each band FETCHES it with a different addressing mode:
;
;     band 0   LDA #$42       immediate      the value is in the instruction
;     band 1   LDA $82        zero page      1-byte address; 2 bytes, 3 cycles
;     band 2   LDA $0082      absolute       16-bit address; 3 bytes, 4 cycles
;     band 3   LDA $82,X      zero page,X    X = 0; base wraps in page $00
;     band 4   LDA $0082,X    absolute,X     X = 0; a true 16-bit address
;     band 5   LDA ($80),Y    (zp),Y         Y = 0; pointer $80/$81 = $0082
;
;   All six bands look identical on screen, because all six arrive with $42
;   in the accumulator.  That is the point: addressing modes are different
;   ROUTES to the same data.  The bottom six bands are different: they show
;   the ramp $42, $4C, $56, $60, $6A, $74, fetched from the 6-byte ROM table
;   at Ramp with LDA Ramp,Y — the mode that lets ONE instruction read MANY
;   values, with Y choosing which.
;
;   The program also uses the only indirect instruction on the 6502: band 0's
;   paint call goes through JMP (BandPtr), a pointer at $83/$84 that holds
;   PaintBand's address.  Change those two bytes and the same program jumps
;   somewhere else — the jump's destination is data.
;
; What you'll learn:
;   - The full mode catalog: implied, accumulator, immediate, zero page,
;     zero page,X/,Y, absolute, absolute,X/,Y, relative, indirect,
;     (zp,X), and (zp),Y
;   - Length and cycle differences: the same byte, cheaper or dearer
;   - The zero-page wrap hazard: LDA $80,X with X = $80 reads TIA $00
;   - Branches are relative: +/-127 bytes from the next instruction
;   - JMP ($xxFF): the NMOS page-boundary bug (explained, not used)
;   - Index registers select table entries: LDA Ramp,Y
;
; Frame geometry: 192 non-blanked scanlines — 12 EQUAL bands of 16 lines.
;   Band 0's color is pre-loaded while the beam is blanked, so the
;   beam-release line is band 0's FIRST line and PaintBand paints the other
;   15; every other band is one PaintBand call of 16 lines.  The blank-on
;   after the last band waits for HBLANK first (STA WSYNC), so the last band
;   line is painted whole.  Same skeleton as Lesson 09.
;
; Build: acme -f plain -o build/lesson10.bin \
;        lessons/part1-6502-cpu/10-addressing-modes/10-addressing-modes.asm
; Run:   stella build/lesson10.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
Ptr         = $80       ; $80/$81: the (zp),Y pointer.  Its two bytes are
                        ;   $82 and $00, so it points at RAM address $0082.
Shared      = $82       ; the byte every MEMORY-mode band reads: $42.
                        ;   Written once at startup and never again.
BandPtr     = $83       ; $83/$84: the indirect-jump pointer.  Holds the
                        ;   address of PaintBand — the subroutine that sits
                        ;   immediately before the trampoline that reads it.

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
BANDS       = 12        ; bands on the screen
LINES       = 16        ; scanlines per band (12 x 16 = 192 visible lines)
RAMP_BANDS  = 6         ; the bottom half: one entry per ramp band

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    ; --- The shared byte: stored ONCE, read six different ways per frame ---
    LDA #$42                ; the byte every memory-mode band will fetch
    STA Shared              ; $82 = $42 — no instruction below writes it again

    ; --- The (zp),Y pointer: $80/$81 = $0082 ---
    LDA #<Shared            ; A = $82 — the LOW byte of the target address
PtrLow:                     ; debugger checkpoint: break here, A = $82
    STA Ptr                 ; $80 = $82: writing the pointer's low first
    LDA #>Shared            ; A = $00 — the HIGH byte: RAM $82 sits in page 0
PtrHigh:                    ; debugger checkpoint: break here, A = $00
    STA Ptr+1               ; $81 = $00: together, $80/$81 read as $0082

    ; --- The indirect-jump pointer: $83/$84 = PaintBand ---
    LDA #<PaintBand         ; the painter's address, low byte ...
    STA BandPtr
    LDA #>PaintBand         ; ... and high byte.  Low byte $83 is nowhere
    STA BandPtr+1           ; near $FF, so the JMP ($xxFF) bug cannot bite.

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK

; -----------------------------------------------------------------------------
; BAND 0 — IMMEDIATE  (LDA #$42)
; -----------------------------------------------------------------------------
; Band 0 is the TOP band, and its color must be in COLUBK BEFORE the beam is
; released — the release line is band 0's first line.  So this fetch happens
; during VBLANK, and the color is parked in Y across the timer wait (the
; +wait_timer macro leaves its own value in A).
;
; Immediate mode: the operand lives inside the instruction.  There is no
; memory read at all — the CPU already has $42 before the instruction ends.
    LDA #$42                ; IMMEDIATE: 2 bytes, 2 cycles, no memory access
FetchImmediate:             ; debugger checkpoint: break here, A = $42
    TAY                     ; park the color: +wait_timer clobbers A

    +wait_timer             ; finish the ~37 scanlines of VBLANK

    LDA #$00
    STA VBLANK              ; un-blank: this line is band 0's FIRST line
    TYA                     ; A = band 0's color again
    STA COLUBK              ; written in HBLANK, so the release line shows it

    LDX #LINES-1            ; X = 15: release line + 15 painted = band 0
    JSR PaintBandViaPtr     ; paint it — reached through the $83/$84 pointer

; -----------------------------------------------------------------------------
; BAND 1 — ZERO PAGE  (LDA $82)
; -----------------------------------------------------------------------------
; The address of the data fits in ONE byte, so the instruction is 2 bytes
; long and the access takes 3 cycles.  All 2600 RAM is zero page, so every
; variable access is a zero-page access.
    LDA Shared              ; ZERO PAGE: the $82 in the operand is the address
FetchZeroPage:              ; debugger checkpoint: break here, A = $42
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 2 — ABSOLUTE  (LDA $0082)
; -----------------------------------------------------------------------------
; The SAME address, spelled with sixteen bits.  ACME chooses the length from
; the way the address is written: leading zeros mean "use absolute".  Three
; bytes long, 4 cycles — one byte and one cycle more for the same value.
    LDA $0082               ; ABSOLUTE: 3 bytes, 4 cycles
FetchAbsolute:              ; debugger checkpoint: break here, A = $42
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 3 — ZERO PAGE,X  (LDA $82,X)
; -----------------------------------------------------------------------------
; The index is added to the base BEFORE the access.  X = 0 here, so this
; band reads $82 — but the important property is the WRAP: the sum stays
; inside page $00.  With X = $80 the address would be $02, not $102.  The
; lesson's stretch exercise shows how that silently lands on the TIA.
    LDX #$00                ; X = 0: the base index; $82 + 0 = $82
    LDA Shared,X            ; ZERO PAGE,X: 2 bytes, 4 cycles
FetchZeroPageX:             ; debugger checkpoint: break here, A = $42, X = $00
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 4 — ABSOLUTE,X  (LDA $0082,X)
; -----------------------------------------------------------------------------
; The same indexed read with a sixteen-bit base.  Now the sum is a real
; 16-bit add: base + X can leave the page, and if it does, the access takes
; one extra cycle (4+1).  With X = 0 it does not, so this band costs 4.
    LDX #$00                ; X = 0 again
    LDA $0082,X             ; ABSOLUTE,X: 3 bytes, 4 cycles (+1 on page cross)
FetchAbsoluteX:             ; debugger checkpoint: break here, A = $42, X = $00
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BAND 5 — (zp),Y  —  INDIRECT INDEXED  (LDA ($80),Y)
; -----------------------------------------------------------------------------
; The operand names a ZERO-PAGE PAIR ($80/$81), not an address.  The CPU
; reads a 16-bit address out of those two bytes — here $0082 — and then adds
; Y to it.  This is the mode for walking a buffer at a run-time-chosen base.
    LDY #$00                ; Y = 0: the offset added to the pointer's target
    LDA (Ptr),Y             ; INDIRECT INDEXED: 2 bytes, 5 cycles (+1 on page
                            ;   cross); pointer $80/$81 = $0082, so it reads $82
FetchIndirectY:             ; debugger checkpoint: break here, A = $42, Y = $00
    LDX #LINES
    JSR PaintBand

; -----------------------------------------------------------------------------
; BANDS 6-11 — THE RAMP  (LDA Ramp,Y)
; -----------------------------------------------------------------------------
; One instruction, six values: Y is added to the table's 16-bit address and
; the load returns that entry.  The table is page-aligned (see !align below),
; so Y = 0...5 never crosses a page and the load is always exactly 4 cycles.
    LDY #$00                ; Y = the table index: entry 0 is the first band
RampLoop:
    LDA Ramp,Y              ; ABSOLUTE,Y: one instruction reads six colors
RampFetch:                  ; debugger checkpoint: break here, A = Ramp[Y]
    LDX #LINES
    JSR PaintBand           ; PaintBand preserves Y: it can index the table
    INY                     ; next table entry
    CPY #RAMP_BANDS         ; 0 ... 5 — the loop stops at the table's edge
    BNE RampLoop

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
    STA WSYNC               ; wait for HBLANK before blanking: the last band
                            ; line is being drawn right now, so writing VBLANK
                            ; here would clip it partway across.  WSYNC lets the
                            ; line finish; the blank-on starts on the next line
    LDA #$02
    STA VBLANK
    +set_timer 35           ; ~30 scanlines of overscan
    +wait_timer

    JMP StartFrame          ; next frame — the picture is static

; =============================================================================
; SUBROUTINE: PaintBand  —  paint X scanlines of the color in A
; =============================================================================
; How to call:   A = color byte, X = scanline count, then JSR PaintBand
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for X lines.  Writing the color
;                right after the WSYNC — instead of once before the loop —
;                puts the change in the first few cycles of the line, before
;                the TIA starts drawing on it, so band boundaries fall
;                exactly on a scanline instead of showing a notch where the
;                new color arrives mid-line.
; Registers:     A survives (still the color) and Y is never touched — the
;                ramp loop relies on that; X is used up: the line counter
;                counts it down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.  Nothing
;                else is pushed inside, so callers can use the stack freely.
; =============================================================================
PaintBand:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEX                     ; one line fewer to go: 16, 15, ... 1
    BNE -                   ; loop until the line counter reaches 0
    RTS                     ; return; the return address comes off the stack

; =============================================================================
; CALLING A SUBROUTINE THROUGH A POINTER  —  JMP (indirect)
; =============================================================================
; The 6502 has no "JSR (indirect)".  To call through a pointer you JSR to a
; two-byte trampoline that does the indirect JMP: the JSR has already pushed
; the return address, so when PaintBand finishes, its RTS pops that address
; and control comes back to the instruction after the JSR.
;
; Band 0's call uses this path every frame, with the target address read from
; the pointer at $83/$84.  The pointer's low byte is $83 — not $FF — so the
; NMOS JMP ($xxFF) bug (documented in the lesson text) cannot apply.
PaintBandViaPtr:
    JMP (BandPtr)           ; INDIRECT: read the target address from $83/$84

; =============================================================================
; DATA — the six ramp colors, read as Ramp,Y
; =============================================================================
; Page-aligned so that Y = 0...5 cannot cross a page: LDA abs,Y costs exactly
; 4 cycles here instead of 4+1.  (!align pads to the next page with zeros.)
    !align 255, 0, 0
Ramp:
    !byte $42, $4C, $56     ; bands 6-8
    !byte $60, $6A, $74     ; bands 9-11

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

> The complete, fully-commented source lives in
> `lessons/part1-6502-cpu/10-addressing-modes/10-addressing-modes.asm`.

### Code Walkthrough

#### Step 1 — One byte, two pointers, set up once

```asm
    LDA #$42                ; the byte every memory-mode band will fetch
    STA Shared              ; $82 = $42 — no instruction below writes it again
```

`Shared` is `$82`; this is the only write to it, which is what makes the experiment honest. Then the two pointers are stored, low byte first:

```asm
    LDA #<Shared            ; A = $82 — the LOW byte of the target address
PtrLow:                     ; debugger checkpoint: break here, A = $82
    STA Ptr                 ; $80 = $82: writing the pointer's low first
    LDA #>Shared            ; A = $00 — the HIGH byte: RAM $82 sits in page 0
PtrHigh:                    ; debugger checkpoint: break here, A = $00
    STA Ptr+1               ; $81 = $00: together, $80/$81 read as $0082
```

`<` and `>` are ACME's low-byte and high-byte operators, and a 16-bit zero-page pointer is just two stores. The two labels sitting on the stores are debugger checkpoints: break there and A holds `$82`, then `$00` — the pointer being built byte by byte. The second pointer is the indirect-jump target:

```asm
    LDA #<PaintBand         ; the painter's address, low byte ...
    STA BandPtr
    LDA #>PaintBand         ; ... and high byte.  Low byte $83 is nowhere
    STA BandPtr+1           ; near $FF, so the JMP ($xxFF) bug cannot bite.
```

#### Step 2 — Band 0: immediate, the release line, and the indirect call

Band 0's color has to be in `COLUBK` *before the beam is released*, because the release line is the band's first line and nothing else gets a chance to write the register in time. So the immediate fetch happens during VBLANK, and the color waits in Y while the timer runs:

```asm
    LDA #$42                ; IMMEDIATE: 2 bytes, 2 cycles, no memory access
FetchImmediate:             ; debugger checkpoint: break here, A = $42
    TAY                     ; park the color: +wait_timer clobbers A

    +wait_timer             ; finish the ~37 scanlines of VBLANK

    LDA #$00
    STA VBLANK              ; un-blank: this line is band 0's FIRST line
    TYA                     ; A = band 0's color again
    STA COLUBK              ; written in HBLANK, so the release line shows it

    LDX #LINES-1            ; X = 15: release line + 15 painted = band 0
    JSR PaintBandViaPtr     ; paint it — reached through the $83/$84 pointer
```

The `JSR` goes to the trampoline, not the painter: the trampoline's `JMP (BandPtr)` supplies the target from RAM, and `PaintBand`'s `RTS` returns here. That is Section 5's indirect call in its real home — and it is real, not decorative: **every frame** reaches the painter through the pointer.

#### Step 3 — Bands 1 through 5: five memory routes to `$82`

Each of the next five bands is a fetch plus the same two-line paint call. Read them as a set; the differences are the lesson.

Band 1, zero page — the address is one byte:

```asm
    LDA Shared              ; ZERO PAGE: the $82 in the operand is the address
FetchZeroPage:              ; debugger checkpoint: break here, A = $42
    LDX #LINES
    JSR PaintBand
```

Band 2, absolute — the same address spelled with sixteen bits (write the leading zeros and ACME emits the absolute form):

```asm
    LDA $0082               ; ABSOLUTE: 3 bytes, 4 cycles
FetchAbsolute:              ; debugger checkpoint: break here, A = $42
    LDX #LINES
    JSR PaintBand
```

Band 3, zero page,X — the index is added in eight bits, inside page zero:

```asm
    LDX #$00                ; X = 0: the base index; $82 + 0 = $82
    LDA Shared,X            ; ZERO PAGE,X: 2 bytes, 4 cycles
FetchZeroPageX:             ; debugger checkpoint: break here, A = $42, X = $00
    LDX #LINES
    JSR PaintBand
```

Band 4, absolute,X — the same index on a 16-bit base, so the sum may leave the page (and cost one extra cycle when it does):

```asm
    LDX #$00                ; X = 0 again
    LDA $0082,X             ; ABSOLUTE,X: 3 bytes, 4 cycles (+1 on page cross)
FetchAbsoluteX:             ; debugger checkpoint: break here, A = $42, X = $00
    LDX #LINES
    JSR PaintBand
```

Band 5, `(zp),Y` — the only route of the five that reads a *pointer*: `$80/$81` hold `$0082`, the CPU adds Y = 0, and the byte arrives:

```asm
    LDY #$00                ; Y = 0: the offset added to the pointer's target
    LDA (Ptr),Y             ; INDIRECT INDEXED: 2 bytes, 5 cycles (+1 on page
                            ;   cross); pointer $80/$81 = $0082, so it reads $82
FetchIndirectY:             ; debugger checkpoint: break here, A = $42, Y = $00
    LDX #LINES
    JSR PaintBand
```

The indexed forms both use a zero index (X = 0, Y = 0) — deliberately neutral, so the experiment isolates the *mode*, not the index. Break at any of the five fetch checkpoints in a running frame and A is `$42`.

#### Step 4 — Bands 6 through 11: the table does the work

```asm
    LDY #$00                ; Y = the table index: entry 0 is the first band
RampLoop:
    LDA Ramp,Y              ; ABSOLUTE,Y: one instruction reads six colors
RampFetch:                  ; debugger checkpoint: break here, A = Ramp[Y]
    LDX #LINES
    JSR PaintBand           ; PaintBand preserves Y: it can index the table
    INY                     ; next table entry
    CPY #RAMP_BANDS         ; 0 ... 5 — the loop stops at the table's edge
    BNE RampLoop
```

Section 4's pattern: Y selects the entry, the painter's contract keeps Y alive, and the bounds check stops at six. The table itself is page-aligned so no index can cross a page:

```asm
    !align 255, 0, 0
Ramp:
    !byte $42, $4C, $56     ; bands 6-8
    !byte $60, $6A, $74     ; bands 9-11
```

#### Step 5 — Blanking the beam in HBLANK

```asm
    STA WSYNC               ; wait for HBLANK before blanking: the last band
                            ; line is being drawn right now, so writing VBLANK
                            ; here would clip it partway across.  WSYNC lets the
                            ; line finish; the blank-on starts on the next line
    LDA #$02
    STA VBLANK
```

Unwinding the ramp loop takes enough cycles to push a naive blank-on write into the visible part of the last band line, where it clips the line partway across. `STA WSYNC` first makes the CPU wait for the next horizontal blank, so the blank-on lands there instead and the last band line is painted in full — the same habit Lesson 09 describes.

#### Step 6 — The demo: one band per mode

`demo-10.asm` is the theory visual: twelve equal bands forming the fixed ramp `$1A + $0A·k` (`$1A`, `$24`, `$2E`, … `$88`), where band *k* is produced by code that exercises the *k*-th **data** mode in catalog order (relative excepted — it has no band, so the table skips from #9 to #11). Because the modes fetch from different places, the demo puts the ramp in **two** places: a RAM copy at `$80–$8B` (for the zero-page modes) and the ROM table at `Ramp` (for the absolute modes), plus a two-entry pointer table for the indirect modes. Open the debugger and step band by band:

| # | Band | Color | Mode | The instruction(s) | Debugger value at the checkpoint |
|:--:|:---:|:---:|---|---|---|
| 1 | 0 | `$1A` | Implied | `LDX #$1A` / `TXA` | A = `$1A` (X was the seed) |
| 2 | 1 | `$24` | Accumulator | `LDA #$12` / `ASL` | A = `$24`, C = 0 |
| 3 | 2 | `$2E` | Immediate | `LDA #$2E` | A = `$2E` |
| 4 | 3 | `$38` | Zero page | `LDA RampCopy+3` (`$83`) | A = `$38` |
| 5 | 4 | `$42` | Zero page,X | `LDX #$04` / `LDA RampCopy,X` | A = `$42`, X = `$04` |
| 6 | 5 | `$4C` | Zero page,Y | `LDY #$05` / `LDX RampCopy,Y` / `TXA` | A = `$4C`, Y = `$05` |
| 7 | 6 | `$56` | Absolute | `LDA Ramp+6` | A = `$56` |
| 8 | 7 | `$60` | Absolute,X | `LDX #$07` / `LDA Ramp,X` | A = `$60`, X = `$07` |
| 9 | 8 | `$6A` | Absolute,Y | `LDY #$08` / `LDA Ramp,Y` | A = `$6A`, Y = `$08` |
| 11 | 9 | `$74` | Indirect | `JMP (IndPtr)` → `LDA Ramp+9` | A = `$74` after landing at `DemoBand9Load` |
| 12 | 10 | `$7E` | `(zp,X)` | `LDX #$02` / `LDA (PtrTable,X)` | A = `$7E`, X = `$02` |
| 13 | 11 | `$88` | `(zp),Y` | `LDY #$0B` / `LDA (PtrTable),Y` | A = `$88`, Y = `$0B` |

The numbers in the first column are the catalog numbers from Section 1 — and the gap tells the story: catalog entry **#10, relative mode, has no band** (the table skips from #9 to #11). Branches change *where the code runs*, not what a load reads, so a branch cannot paint a band — you can see relative mode at work in the `BNE` that closes every loop in the ladder instead. And band 5's `TXA` is there for the reason Section 4 gave: zero page,Y exists for `LDX`/`STX`, not for `LDA`, so the byte arrives through X. The checkpoint labels (`DemoBand0` … `DemoBand11`, plus `DemoBand9Load`) come from the `acme -l` symbol list; the shipped `.bin` carries no names.

## What You Should See

The main ROM is a steady picture of **twelve equal horizontal bands of 16 scanlines** — 192 non-blanked scanlines in all. The top **seven** bands are the same **dark red**: the six mode fetches plus the ramp's first entry, which happens to be the same `$42` (the ramp `$42, $4C, …` starts where the shared byte's value lives). Below them the ramp continues, and each step adds `$0A` to the byte — which is not a brightness ladder: the hue field advances by one (or stays put) while the luminance field jumps around, so the bands alternate lighter and darker. `$4C` is a brighter red than `$42`, `$56` shifts the hue toward magenta, `$60` (luminance 0) is the **darkest**, then `$6A` is a light purple and `$74` a blue-violet:

![Stella running the Lesson 10 addressing-modes ROM: seven dark red bands at the top, then five ramp bands running from a brighter red through magenta, a dark purple, a light purple, and a blue-violet](/images/lesson10/addressing-modes.png)

<RomPlayer rom="/roms/part1-6502-cpu/10-addressing-modes/10-addressing-modes.bin" title="Lesson 10 — Addressing Modes" />

The demo ROM is the same geometry, but every band differs — the same `$0A`-per-step walk from `$1A` (a yellow-green) at the top to `$88` (a blue) at the bottom, with the same alternation of lighter and darker bands:

![Stella running the Lesson 10 demo: twelve equal bands following the $0A-per-step ramp — the hue creeps upward while the brightness alternates lighter and darker — from a yellow-green at the top to a blue at the bottom](/images/lesson10/addressing-mode-ladder.png)

<RomPlayer rom="/roms/part1-6502-cpu/10-addressing-modes/demo-10.bin" title="Lesson 10 — The Mode Ladder (demo)" />

Both pictures are static — nothing animates — because every mode reads fixed data. What changes from band to band is only the route, and that is what the debugger shows. (The checkpoint label names below live in an `acme -l` symbol list; the shipped `.bin` has no names in it.)

- **`$82`** — the shared byte: `$42`, written once at startup. Edit it in the debugger and watch the next frame: the **five memory-mode bands** repaint in the new color while the **immediate band stays `$42`**. That is literal-versus-memory mode in one experiment — and it is the fastest way to convince yourself that `LDA #$42` reads nothing.
- **The six fetch checkpoints**: break at `FetchImmediate`, `FetchZeroPage`, `FetchAbsolute`, `FetchZeroPageX`, `FetchAbsoluteX`, or `FetchIndirectY` in a running frame and A holds `$42` at all six. Each breakpoint pauses *before* its instruction, which is why the checkpoints sit one instruction *after* each load.
- **`$80/$81`** — the `(zp),Y` pointer. Break at `PtrLow` as the ROM starts and A = `$82`; at `PtrHigh` and A = `$00`. The pair reads back as `$0082`.
- **`$83/$84`** — the painter's address, read by the indirect jump. Break at `PaintBandViaPtr` (the `JMP (BandPtr)`) and then at `PaintBand`: the jump lands on the painter every frame, with A = `$42` and X = `$0F` (band 0's fifteen remaining lines) on the way in.
- **`RampFetch`** — inside the ramp loop. A walks the table's six values, `$42`, `$4C`, `$56`, `$60`, `$6A`, `$74`, with Y as the index; that is absolute,Y selecting one of six bytes with one instruction.
- **The demo's checkpoints** (`DemoBand0` … `DemoBand11`) — one per band, matching the table in Step 6. Break at `DemoBand9Load` and again at `DemoBand9` inside the same scanline: the first hit is the indirect jump's landing, the second is the byte it delivered.

::: warning The `$80,X` trap — read this before Exercise 3
`LDA $80,X` with X = `$80` computes `$100`; the carry is discarded and A ends up holding the TIA's collision register at `$00` instead of a color. Nothing crashes; the screen simply lies. Use `LDA $0080,X` or a `(zp),Y` pointer when the address can leave page zero.
:::

## Exercises

### Exercise 1: The Ramp, All the Way Down

**Challenge:** the lesson ROM's indexed ramp is only the bottom half — six bands read from a six-byte table with `LDA Ramp,Y`. Extend it: make the **whole picture** a twelve-band ramp, fetched by one `LDA Ramp,Y` loop and a twelve-byte table that continues the step (`$42`, `$4C`, `$56`, … `$B0`).

**Hints:**
1. Y is the table index, and `PaintBand` preserves Y — so the band loop needs no save and restore (Lesson 08's contract, used for real).
2. The table needs twelve `!byte`s. Put `!align 255, 0, 0` before it so Y = 0…11 cannot cross a page and every load costs exactly 4 cycles.
3. Band 0's color must be in `COLUBK` before the beam is released: fetch it right after `+wait_timer` and store it before the band's `JSR PaintBand`.

**Expected Result:** twelve equal bands following the `+$0A` walk from `$42` at the top to `$B0` at the bottom — hue stepping while brightness alternates (the same ramp the lesson ROM's bottom half shows, continued up the screen). Band 0's checkpoint (`Band0Fetch`) shows A = `$42`, Y = `$00`; the loop's (`BandFetch`) walks A through `$4C` … `$B0` with Y = 1 … 11.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Point the Table Around

**Challenge:** use a single zero-page pointer, walk it with `(zp),Y`, and repoint it between two twelve-byte tables every couple of seconds so the screen alternates: the ascending ramp for a while, then the same ramp read backwards.

**Hints:**
1. `LDA (Ptr),Y` with the pointer at `$80/$81`: store the table's address there, low byte first.
2. Y is the index and `PaintBand` preserves it, so one loop walks the whole table; bounds-check Y with `CPY #BANDS`.
3. To switch, store the other table's address into `$80/$81`. A frame countdown plus `EOR #$01` on a flag byte flips between them — `EOR` from Lesson 09 is exactly the flip instruction.

**Expected Result:** the ascending ramp holds for two seconds, then the picture flips to the descending ramp, forever. In the debugger, `$80/$81` hold the current table's address and change at the flip; the two tables sit together inside one page, so no `(zp),Y` load crosses a page boundary and each costs exactly 5 cycles.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The Wrap Trap, Rebuilt Safely *(Stretch Goal)*

**Challenge:** provoke the zero-page wrap, understand it, then rebuild the lookup safely. `LDA $80,X` with X = `$80` computes `$100` — the carry is discarded and the CPU reads `$00`, a TIA address, not RAM. Watch it happen — the demo's zero-page,X band is the clean place to try it: give its `LDA RampCopy,X` an X of `$80` (the same `$80 + $80 = $100` wrap) and single-step it; A stops holding `$42`. Then rewrite the table walk with a `(zp),Y` pointer.

**Hints:**
1. The wrap is arithmetic: zero-page indexed modes add in eight bits. `$80 + $80 = $100` truncates to `$00`; the same happens at any base + index past `$FF`.
2. `$00` is not "empty memory" — reading it returns the `CXM0P` collision register. Nothing crashes, which is what makes the bug dangerous: the band painted with that value shows *some* color, just not a table entry.
3. The safe rebuild is a pointer: store the table's 16-bit address at `$80/$81` and index with `LDA (Ptr),Y`. The addition is sixteen bits wide — the carry propagates into the high byte — and the loop's `CPY #BANDS` keeps the index inside the table.

**Expected Result:** the debugger shows `$80/$81` holding the table's address and every band's A coming from it; the screen shows the twelve-band ramp — the same `$42`…`$B0` picture Exercise 1 paints — and never reads anything from TIA space. Compare against Exercise 1: the pictures are identical; the addressing is not — and only this one stays correct if the table moves or the index grows.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **An addressing mode is part of the opcode, not the expression** — `LDA #$42` and `LDA $42` are different instructions with different lengths and cycles; there are thirteen modes in the whole catalog
- ✅ **Immediate data is in the instruction; memory modes read memory** — `LDA #$42` cannot be changed by writing RAM, and writing `$82` in the debugger proves it band by band
- ✅ **All 2600 RAM is zero page, so zero-page addressing is free speed** — 2 bytes and 3 cycles against absolute's 3 bytes and 4, on every variable access in every program you write
- ✅ **Zero page indexed modes wrap in eight bits** — `$80 + $80` reads `$00`, which is a TIA register, not RAM; guard the sum or use a 16-bit mode (`$0080,X`, `(zp),Y`)
- ✅ **A pointer is two bytes that hold an address** — `LDA ($80),Y` adds Y to the stored address (16 bits, +1 cycle on a page cross); `(zp,X)` instead indexes the *pointer slot* itself
- ✅ **The index registers turn one load into a table reader** — `LDA Ramp,Y` with a bounded Y and a page-aligned table is the course's core data idiom (and `LDA` has no zero page,Y: the instruction sets differ)
- ✅ **Branches are relative (±127 from the next instruction); `JMP` is absolute or indirect** — the only indirect instruction, with the NMOS `$xxFF` bug avoided by pointer placement, and the `JSR`-plus-`JMP (ptr)` trampoline when you need to *call* through a pointer

## What's Next

You can now name every route the CPU takes to its data — and the most useful of those routes, the indexed table read, has only been used for a six-byte color ramp so far. [Lesson 11: Lookup Tables](/part1-6502-cpu/11-lookup-tables) makes tables the main event: sixteen-band color waves, tables that hold durations as well as colors, and the discipline of keeping an index inside its table.
