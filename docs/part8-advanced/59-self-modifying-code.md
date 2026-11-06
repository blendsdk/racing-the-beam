---
title: "Lesson 59: Self-Modifying Code — The Ultimate 6502 Trick"
description: "Copy a seven-byte routine into RIOT RAM, patch its immediate operand on every scanline, and call it to paint 'the code painter' — a 184-line color gradient — while learning why cartridge ROM cannot be written, how the 128-byte RAM and the stack share the same page, what the copy/patch/call pattern costs, and the safety rules that keep self-modifying code readable."
prev:
  text: "Lesson 58: Illegal Opcodes — Undocumented Power"
  link: "/part8-advanced/58-illegal-opcodes"
next:
  text: "Lesson 60: DPC and DPC+ — Enhanced Audio and Graphics"
  link: "/part8-advanced/60-dpc-plus"
---

# Lesson 59: Self-Modifying Code — The Ultimate 6502 Trick

> **Part 8: Advanced Topics** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 03 (the memory map), Lesson 04 (registers and memory), Lesson 08 (the stack and subroutines), Lesson 10 (addressing modes), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 18 (mid-scanline changes), Lesson 25 (players), Lesson 26 (positioning), Lesson 48 (the kernel taxonomy)
> **You will learn:** why a cartridge's ROM cannot be modified and why the routine must be copied to RIOT RAM; how the 128-byte RAM, the zero page, and the stack share the same bytes; the copy/patch/call pattern that turns a seven-byte routine into 184 colour writes drawn from a 184-entry table (28 distinct colours); the exact cycle cost of a `JSR`/`RTS` call plus an operand patch; the difference between self-modifying code and a data-driven table; and the safety rules — fixed length, known entry, no stack use — that keep it debuggable
> **You will build:** "the code painter" — a 4,096-byte ROM that copies `LDA #color / STA COLUBK / STA WSYNC / RTS` to `$80`, patches the immediate operand from a 184-entry color table, calls the routine once per visible line, and paints a 184-line gradient with an 8-line binary status band; plus three 4,096-byte exercise solutions that patch a delay, patch a table address, and run a second RAM routine

## Introduction

Lesson 58 changed what a single instruction does: an undocumented opcode such as `LAX` combines two documented operations in one byte. This lesson changes the **program itself**. A 6502 instruction is just bytes in memory. If the CPU can fetch those bytes from writable memory, the program can rewrite them while it runs. That is self-modifying code: the instruction stream is also data.

On the Atari 2600 there is a hard constraint. The cartridge is ROM. The 6507 can read it, but a write to a ROM address does nothing — there is no RAM at that address and no write path into the cartridge. The only writable memory in the console is the RIOT's 128 bytes at `$80-$FF`, and the 6507 can execute code from there. So a self-modifying routine must first be **copied** from a ROM template into RIOT RAM, then **patched**, then **called**. This lesson builds that pattern in its smallest useful form: a seven-byte routine that writes one color to `COLUBK` and waits for the next scanline. The main loop patches the routine's immediate operand 184 times per frame and calls it once per visible line. The result is "the code painter": a rainbow gradient painted by code that rewrites itself on every line.

The companion program `59-self-modifying-code.asm` is that ROM. It also shows the cost. The copy/patch/call pattern spends 32 cycles before the routine's `STA COLUBK`, so the write lands on cycle 34 of a 76-cycle line. The write applies three color clocks later, so the steady previous-color strip is 37 pixels (measured at `x = 247`, TIA X 37). The first and last lines are longer: 46 and 64 pixels. The first pixels of each gradient line keep the previous line's color, and the left edge of the gradient becomes a stair-step. That is not a bug to hide; it is the measured price of changing an instruction instead of reading a table, and it is the best way to see why self-modifying code is a tool, not a default.

::: details TypeScript Equivalent

In TypeScript, a function's code and its data live in different worlds. You can patch a variable that the function reads, but you cannot patch the function's compiled instructions:

```typescript
// The data-driven version: the routine reads a mutable color.
let color = 0x02;
function paint(): void {
  writeRegister("COLUBK", color); // the instruction stream never changes
  waitForNextLine();
}

// The self-modifying version, as an instruction array the interpreter runs.
type Instruction =
  | { op: "LDA_IMM"; value: number }
  | { op: "STA"; address: number }
  | { op: "WSYNC" }
  | { op: "RTS" };

const routine: Instruction[] = [
  { op: "LDA_IMM", value: 0x02 }, // the operand is instruction[0].value
  { op: "STA", address: 0x09 },   // COLUBK
  { op: "WSYNC" },
  { op: "RTS" },
];

function patchImmediate(value: number): void {
  routine[0].value = value;       // change the instruction, not a variable
}
```

The analogy breaks in the places that make the 2600 interesting. In TypeScript the array is an interpreter's data; the real 6507 fetches the bytes of the routine directly and executes them. `routine[0].value` is a property of an object; `$81` is the second byte of an `LDA #` instruction at `$80`. The TypeScript engine is free to inline, cache, or recompile `paint`; the 6507 has no instruction cache and no memory protection, so a write to `$81` changes the very next fetch. And the array lives in a heap that can grow; the 2600 has 128 bytes of RAM total, shared with the stack. The analogy teaches the idea — code as data — but the constraint that makes it hard is the tiny, shared, writable memory.

:::

## Theory

### Section 1: Why the Routine Must Run from RIOT RAM

The 6507 has 13 address lines. The cartridge occupies `$F000-$FFFF` (4 KB), the TIA registers live at `$00-$3F`, and the RIOT provides 128 bytes of RAM at `$80-$FF` plus its I/O and timer registers at `$0280-$0297`. The cartridge is a ROM: a read returns a byte, a write is ignored. There is no flash, no EEPROM, and no write line to the cartridge in a plain 4K board.

That leaves exactly one place where executable code can change: the RIOT RAM. The 6507's instruction fetch is an ordinary memory read, so it can fetch from `$80-$FF` just as well as from `$F000`. The RAM is small and it is also the stack page — the stack pointer is an 8-bit index into page 1, which the 6507 mirrors onto `$0100-$01FF`, and the RIOT's address decoding maps that to the same 128 bytes as `$80-$FF`. A `JSR` pushes two bytes; a deep call chain eats the same bytes that hold your variables.

This is why the lesson's routine is only seven bytes and lives at `$80-$86`:

| Address | Byte | Instruction | Role |
|---|---|---|---|
| `$80` | `A9` | `LDA #imm` | loads the color; the operand is at `$81` |
| `$82` | `85 09` | `STA COLUBK` | writes the background color |
| `$84` | `85 02` | `STA WSYNC` | waits for the next scanline |
| `$86` | `60` | `RTS` | returns to the main loop |

The routine's variables start at `$87` (`PatchVal`), `$88` (`Calls`), `$89` (`FrameNum`), `$8A` (`Phase`), `$8B` (`HoldFrames`), and `$8C` (`PhaseTimer`). The stack lives at `$F8-$FF`, far above them. The single `JSR $80` in the main loop pushes the return address at `$FF/$FE` (SP goes from `$FF` to `$FD`), and the routine's `RTS` pops it back to `$FF`. The routine itself uses no stack: no `PHA`, no `PLA`, no nested `JSR`. If it did, the stack would grow toward `$F8` and could overwrite the variables — the classic self-modifying-code crash.

::: warning The 128-byte limit is the real design constraint
A routine that runs from RIOT RAM must fit in the same 128 bytes as its variables and the stack. The main demo's routine is 7 bytes; exercise 1 grows it to 12 bytes; exercise 3 adds a second 5-byte routine at `$90`. There is room for these, but not for a general-purpose subroutine library. On a 2600, self-modifying code is a scalpel: a short, fixed routine that does one thing, not a second operating system.
:::

### Section 2: The Copy — ROM Template to `$80`

The cartridge holds the routine as a template, not as the running code. The template is seven bytes in ROM:

```asm
RoutineTemplate:
    !byte $A9, $00          ; LDA #$00
    !byte $85, COLUBK       ; STA COLUBK ($09)
    !byte $85, WSYNC        ; STA WSYNC  ($02)
    !byte $60               ; RTS
```

After `+clean_start` — which zeroes all of RAM, including `$80-$FF` — the reset code copies the template to `$80`:

```asm
    LDX #6
CopyRoutine:
    LDA RoutineTemplate,X   ; the ROM byte
    STA $80,X               ; the RAM copy: $80-$86
    DEX
    BPL CopyRoutine
```

`DEX` sets N when X wraps from `$00` to `$FF`, so `BPL` exits after the index-0 byte is copied. The copy is not a per-frame cost; it happens once, before the first frame. The template never changes. The RAM copy does.

The seven bytes are deliberately written with `!byte` instead of mnemonics. The assembler's listing then shows the exact bytes that are copied, and the operand at `$81` is visible as the byte the main loop patches. A disassembler reading `$80` sees:

```text
$0080  A9 xx   LDA #$xx
$0082  85 09   STA $09     ; COLUBK
$0084  85 02   STA $02     ; WSYNC
$0086  60      RTS
```

The `xx` is the part that changes. The instructions around it do not.

### Section 3: The Patch — an Instruction Operand Is Also Data

The main loop walks a 184-entry color table, one entry per gradient line. For each line it stores the entry into `$81` and calls the routine:

```asm
    LDY Phase
    LDX #GRADIENT_LINES
FirstWindow:
    LDA ColorTable,Y
PatchByte:
    STA $81                 ; patch the LDA #'s immediate operand
    INY
    DEX
    BEQ LastLine
    JSR RamRoutine          ; LDA #color; STA COLUBK; STA WSYNC; RTS
    CPY #0                  ; did the table index wrap past 255?
    BNE FirstWindow
SecondWindow:
    LDY #0
SecondWindowLoop:
    LDA ColorTable+256,Y    ; second copy, offset 72: table[72..]
PatchByteTail:
    STA $81
    INY
    DEX
    BEQ LastLine
    JSR RamRoutine
    CPY #0
    BNE SecondWindowLoop
```

`STA $81` is the whole trick. It writes a data byte into the second byte of an instruction. The next `JSR $80` fetches `A9 <value>` and loads the new color. The instruction stream is data; the data is the instruction stream.

The table is 184 entries, one per visible gradient line. Its colors are built from two formulas:

- **Hue:** `hue = (line * 16) / 184`, so the 184 lines walk all sixteen TIA hues in bands of about 11.5 lines.
- **Luminance:** `lum = 1 + round(6 * |sin(pi * line / 183)|)`, so the gradient is dark at the top and bottom and bright in the middle.

A TIA color byte is `CCCCLLL0`: the high nibble is the hue (0-15), bits 3-1 are the luminance (0-7), and bit 0 is unused. Every table entry is even, as a color byte must be.

The table is **page-aligned and stored twice**. Y is only eight bits, so the window cannot be a single 184-entry run from any phase:

- The **first window** starts at Y = Phase and reads `ColorTable,Y`. For a phase above 72 it reaches Y = 255 and covers `table[Phase..183]` plus the second copy's `table[0..71]`; for a lower phase the 184 entries end inside the first copy.
- If Y wraps, the **second window** starts at Y = 0 and reads `ColorTable+256,Y`, which is the second copy's `table[72..]`. It finishes the remaining `table[72..Phase-1]` entries. The page alignment means neither window's `LDA abs,Y` crosses a page, so the color write keeps one cycle count.

X is the line counter, independent of Y, so the phase never changes the 184-line total. A one-shot 60-frame hold keeps phase 0 for the first capture; after it expires the phase advances one entry every four frames. The hold is a separate byte and does not repeat when `FrameNum` wraps. Two captures of the same committed ROM therefore show different phases.

### Section 4: The Call and the Stack

`JSR $80` is a six-cycle instruction. It pushes the address of the next main-loop instruction (high byte first) at `$FF` and `$FE`, decrements the stack pointer twice, and jumps to `$80`. The routine's `RTS` pulls the two bytes back and increments SP twice. At the top level of the main loop, SP starts at `$FF`; inside the routine it is `$FD`; after the `RTS` it is `$FF` again. The routine uses no stack of its own, so the call depth never grows.

The routine is:

```asm
$80: LDA #color     ; 2 cycles
$82: STA COLUBK     ; 3 cycles
$84: STA WSYNC      ; 3 cycles, then the CPU waits for the next line
$86: RTS            ; 6 cycles
```

`STA WSYNC` is the line pacing. The write halts the CPU until the next scanline begins; the `RTS` then runs at the start of that line. The routine's color write happens before the `WSYNC`, so it applies to the line that is currently being drawn — which is why its timing matters (Section 5).

::: tip Why the routine cannot call another subroutine
A nested `JSR` would push two more bytes, and the routine would need a matching `RTS`. That is not forbidden by the CPU, but it breaks the lesson's safety rule: the routine must have a fixed, known stack depth. A self-modifying routine that calls other code is much harder to reason about, and on 128 bytes it is easy to run out of stack. Keep the RAM routine a leaf.
:::

### Section 5: The Cycle Cost — Why the Left Edge Is Smeared

The visible part of a scanline is 160 color clocks, and one CPU cycle is three color clocks. HBLANK is 68 color clocks, about 22.7 CPU cycles. If a color register is written during HBLANK, the whole visible line uses the new color. If it is written later, the left part of the line keeps the old color and the rest uses the new one.

The patched routine's color write is not the first thing that happens after the previous line's `WSYNC`. Both windows use the same patch/call body and the same padded tail:

| Step | Cycles | Running total |
|---|---|---|
| `RTS` from the previous call | 6 | 6 |
| `CPY #0` | 2 | 8 |
| `BNE` (taken) | 3 | 11 |
| `LDA ColorTable,Y` | 4 | 15 |
| `STA $81` (the patch) | 3 | 18 |
| `INY` | 2 | 20 |
| `DEX` | 2 | 22 |
| `BEQ` (not taken) | 2 | 24 |
| `JSR $80` | 6 | 30 |
| `LDA #color` | 2 | 32 |
| `STA COLUBK` (write on the third cycle) | 3 | 34 |

The state log puts the `STA COLUBK` instruction at scanline/cycle 46/32, so the write lands on cycle 34: 102 color clocks, 34 after the visible field starts at color clock 68. The write applies about three color clocks later, so the measured previous-color strip is 37 pixels (`x = 247`, TIA X 37). The table is page-aligned, so neither window's `LDA abs,Y` crosses a page; the **steady** color write is cycle 34 in both windows, and the gradient has no page-cross seam.

The first tail line after the wrap is the one exact exception. The hand-off takes `CPY #0` (2) + `BNE` not taken (2) = 4 cycles instead of the steady `CPY` (2) + `BNE` taken (3) = 5, and Y is already 0, so the redundant `LDY #0` is gone. That line's `STA COLUBK` is at 227/31, its write cycle is 33, and its strip is 34 pixels (`x = 229`). It is invisible because `table[71]` and `table[72]` are both `$6E` at the first wrap. Every other tail line is the steady 34/37.

One CPU cycle is three color clocks, so one extra cycle is three pixels. That rule explains the two exceptions the state log shows:

| Line | `STA COLUBK` | Write cycle | Extra cycles | Measured strip |
|---|---|---|---|---|
| steady first/second window | 46/32 | 34 | 0 | 37 px (`x = 247`) |
| first gradient line | 45/35 | 37 | +3 | 46 px (`x = 301`) |
| last gradient line | 228/41 | 43 | +9 | 64 px (not visible at phase 0: the last two colors are the same) |

The first line's longer setup adds three cycles (+9 pixels); the last line's bookkeeping adds nine cycles (+27 pixels). The 37 → 46 → 64 progression is the 3-pixels-per-cycle rule applied to +0, +3, and +9 cycles.

That stair-step is the lesson. It is the measured cost of the `JSR`/`RTS` pair, the patch, and the loop tail. A data-driven kernel can write `COLUBK` in HBLANK and get a clean edge, but it does not change its instruction stream. Self-modifying code buys flexibility with cycles; this is the bill.

::: tip The same cost applies to every patch
Exercise 1 adds a delay before the color write and patches the delay; the seam sweeps right by five cycles per delay count. Exercise 3 adds a second `JSR` and a second patch; the color write moves further right and the smear widens. The cycle ledger is not an abstract table: every added instruction in the post-`WSYNC` path moves the color boundary.
:::

### Section 6: Self-Modifying Code vs. a Data-Driven Table

A data-driven kernel stores the colors in a table and writes the table entry to `COLUBK` directly:

```asm
    LDA ColorTable,Y
    STA COLUBK
    STA WSYNC
```

That is about ten cycles, and the color write can be in HBLANK. It is faster, smaller, and easier to debug. So why ever self-modify?

Because some programs need to change an **instruction**, not just a value:

- **An address operand.** Exercise 2 changes `LDA TableA,X` into `LDA TableB,X` by patching the two address bytes. A data-driven version would need a pointer in zero page and an indirect load; the patched instruction keeps the absolute,X addressing mode and its exact cycle count.
- **An opcode or a whole routine.** A program can generate a short routine at run time, or select between variants by copying one template or another into RAM.
- **A routine whose behavior is its bytes.** Copying a routine to RAM is also how a program can run code that did not exist in the cartridge image — a tiny interpreter, a patch loader, or a code generator.

For the gradient itself, the data-driven version wins. The lesson's demo is deliberately the small, visible case: one operand, one routine, 184 calls. It teaches the mechanism and its cost without pretending it is the fastest way to paint a screen. The honest rule is: **use a table unless the instruction itself is what must change.**

### Section 7: The Safety Rules

Self-modifying code is powerful because the CPU does not distinguish code from data. That is also why it is dangerous. The lesson follows six rules:

1. **Fixed length.** The routine is exactly seven bytes, copied from a seven-byte template. Nothing jumps into the middle of it, and nothing writes past `$86`.
2. **Known entry.** The only entry is `$80`, the first byte of the copy. There is no fall-through from data and no computed jump into the routine's middle.
3. **No stack use inside.** The routine only loads, stores, and returns. The `JSR`/`RTS` pair is the only stack traffic, so SP returns to its entry value and the stack cannot creep into the variables.
4. **No overlap with the stack.** The routine and variables live at `$80-$8C`; the stack is at `$F8-$FF`. A 128-byte machine leaves no room for guessing.
5. **Copy after `+clean_start`.** The startup macro zeroes all of RAM, including `$80-$FF`. Copying before it would be erased.
6. **Patch only the operand.** The main loop writes `$81`, the immediate byte of `LDA #`. It never writes the opcode at `$80`, the `STA` instructions, or the `RTS`. The disassembly stays valid: `A9 xx 85 09 85 02 60`.

Two more rules are good practice even though the demo does not need them: verify the copied bytes in the debugger before trusting the routine, and keep the routine's page fixed. The 6507 has no instruction cache, so a write to `$81` is visible to the very next fetch; on a modern CPU the same trick needs cache maintenance and is usually forbidden by the operating system.

### Section 8: The Picture — Status Band, Gradient, and Phase

The visible picture is 192 lines:

| Visible lines | What is drawn |
|---|---|
| 0-3 | the status band's top field: `PatchVal`, the last color patched into `$81`, as eight `PF1` bits (bit 7 first) |
| 4-7 | the status band's bottom field: `Calls`, the frame's call count (184 = `$B8`), as eight `PF1` bits |
| 8-191 | 184 gradient lines, one `ColorTable` entry per line |

`PF1` bit 7 is playfield chunk 4, so the eight-bit field sits at chunks 4-11 (TIA X 16-47). `CTRLPF=$01` reflects the playfield, so the field appears again on the right. The top field is white; the bottom field is gold; `COLUBK` is forced to black behind the status so the bits are readable.

The status is drawn before the gradient, so it shows the values from the **previous** frame. In a steady phase, `PatchVal` is the last color of the previous frame's gradient; `Calls` is 184. The status is a diagnostic, not a game display: it proves that the patched value and the call count are real variables, not constants in the source.

The gradient's phase advances one entry every four frames after a **one-shot** 60-frame hold. The hold is a separate byte, `HoldFrames`, not `FrameNum`, so it does not repeat when the 8-bit frame counter wraps. The first phase step lands on frame 64; the hold is never restarted. Two captures of the committed ROM at different phases show the same code with a different table window:

- At phase 0, the first gradient line is `$02` and the status field reads `$F2`. All 184 lines come from the first window.
- At phase 96, the first gradient line is `$8E` and the status field reads `$8E`. The first window covers visible lines 8-167, and the second window covers 168-191.

The phase animation is the only moving part in the demo. The routine, the patch address, and the frame are constant.

## The Code

### Building This Lesson

```bash
# every lesson ROM, including this one:
npm run roms

# or just this one:
acme -f plain -o build/lesson59.bin lessons/part8-advanced/59-self-modifying-code/59-self-modifying-code.asm
stella build/lesson59.bin
```

The ROM is 4,096 bytes. It uses a plain 4K cartridge, so every 2600 emulator and every 4K board can run it.

### Full Source

The complete annotated source:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 59: Self-Modifying Code — The Ultimate 6502 Trick — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the code painter": a 4,096-byte cartridge that copies a seven-byte
;   routine into RIOT RAM at $80, patches the routine's immediate operand on
;   every visible line, and calls the patched routine with JSR $80.  The
;   routine writes the patched color to COLUBK and then waits for the next
;   line with STA WSYNC.  The result is a 184-line vertical color gradient:
;   sixteen hue bands with a luminance arc, painted by code that rewrites
;   itself 184 times per frame.
;
; The routine (seven bytes, copied from ROM to $80 before it runs):
;   $80  A9 xx   LDA #color     ; the operand at $81 is patched each line
;   $82  85 09   STA COLUBK     ; $09 is the background-color register
;   $84  85 02   STA WSYNC      ; $02 is the wait-for-next-line strobe
;   $86  60      RTS            ; return to the main loop
;
; Why the routine must live in RAM:
;   A cartridge is ROM.  The 6507 can read it, but a write to a ROM address
;   does nothing: there is no RAM there and no write path.  RIOT RAM at
;   $80-$FF is the only writable memory in the machine, and the 6507 can
;   execute code from it.  So the routine is copied from the ROM template
;   (RoutineTemplate) to $80, and the main loop patches the copy.  The ROM
;   template never changes.
;
; The stack:
;   RIOT RAM is also the stack page.  +clean_start sets SP = $FF; the single
;   JSR $80 pushes the return address at $FF/$FE (SP becomes $FD), and the
;   RTS inside the routine pops it (SP returns to $FF).  The routine itself
;   uses no stack: it only loads, stores, and returns.  The routine and the
;   variables at $87-$8C are far below the stack at $F8-$FF, so the two
;   cannot collide.
;
; The picture (192 visible lines):
;   visible   0-7    the status band, eight lines:
;                      lines 0-3  PatchVal as eight PF1 chunks (bit 7 first)
;                      lines 4-7  Calls as eight PF1 chunks (bit 7 first)
;                    PF1's bit 7 is playfield chunk 4, so the field sits at
;                    chunks 4-11 (TIA X 16-47); CTRLPF=$01 mirrors it on the
;                    right.  The top field is white; the bottom field is gold.
;   visible   8-191  the gradient: 184 lines, one color per line from the
;                    184-entry ColorTable.  The table walks 16 hue bands with
;                    a luminance arc that is dark at both ends and bright in
;                    the middle.  The table is page-aligned and stored twice.
;                    The first window starts at Y = Phase and reads
;                    ColorTable,Y; for a phase above 72 it reaches Y = 255
;                    and covers table[Phase..183] plus the second copy's
;                    table[0..71]; for a lower phase the 184 entries end
;                    inside the first copy.  If Y wraps, the second
;                    window starts at Y = 0 and reads ColorTable+256,Y, which
;                    is the second copy's table[72..]; it finishes the
;                    remaining table[72..Phase-1] entries.  A one-shot
;                    60-frame hold keeps phase 0 for the first capture; after
;                    it expires the phase advances one entry every four
;                    frames.  The hold does not repeat when FrameNum wraps.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229/6.
;   No player or missile is used, so there is no HMOVE in the main demo.
;
; Cycle ledger (one scanline = 76 CPU cycles; measured in Stella):
;   The patched routine is called once per gradient line.  Both windows use
;   the same patch/call body and the same padded tail:
;     RTS 6 + CPY 2 + BNE 3 + LDA ColorTable,Y 4 + STA $81 3 + INY 2 +
;     DEX 2 + BEQ 2 (not taken) + JSR 6 + LDA # 2 = 32 cycles to the STA
;   COLUBK instruction; its write is the third cycle, 34.  The state log
;   confirms 46/32 for the instruction and a write on cycle 34.
;   The table is page-aligned, so neither window's LDA abs,Y crosses a page;
;   the color write is 34 in both windows.
;   The write is 34 CPU cycles = 102 color clocks; the visible field starts
;   at clock 68, and the write applies about three clocks later, so the
;   measured steady strip is 37 pixels (x = 247).
;   One extra CPU cycle is 3 pixels: the first line's longer setup puts its
;   STA COLUBK at 45/35 (write 37) and its strip at 46 pixels (x = 301); the
;   last line's bookkeeping puts it at 228/41 (write 43) and its strip at 64
;   pixels.  The 37 -> 46 -> 64 progression is 0 -> +3 -> +9 cycles, i.e.
;   0 -> +9 -> +27 pixels, exactly the 3-pixel rule.
;   That stair-step left edge is the measured cost of the copy/patch/call
;   pattern, not a bug.  A data-driven kernel that writes COLUBK directly
;   after WSYNC can put the write inside HBLANK, but it does not change its
;   instruction stream.
;   The routine's STA WSYNC is at 46/35; the CPU then waits out the remaining
;   cycles of the 76-cycle line.
;
; Checkpoints (the state log's scanline/cycle, A/X/Y/SP, and P fields):
;   StartFrame   $F033  259/3, the first VSYNC instruction
;   VblankStart  $F041  0/5, the first VBLANK instruction
;   BodyStart    $F08B  37/5, the first visible-line instruction
;   OverscanStart $F0D1 229/6, the first overscan instruction
;   Frame        $F04E  A = 1, 2, 3, ... (the new frame count)
;   PatchByte    $F0AB  A = the new color in the first window
;   PatchByteTail $F0BB A = the new color in the second window
;   CallCount    $F0CC  A = 184 (the number of JSR $80 calls this frame)
;   RamRoutine   $0080  the copied routine; the debugger disassembly is
;                       A9 xx 85 09 85 02 60
;
; RAM map (RIOT, $80-$FF; +clean_start zeroes every byte):
;   $80-$86  the copied routine (LDA #, STA COLUBK, STA WSYNC, RTS)
;   $87      PatchVal  the last color patched into $81
;   $88      Calls     the number of gradient lines drawn this frame (184)
;   $89      FrameNum  frames since reset, wraps at 256
;   $8A      Phase     the table phase, 0-183; +1 every four frames
;   $8B      HoldFrames one-shot 60-frame phase hold
;   $8C      PhaseTimer divides the post-hold frames by four
;   $8D-$9F  free
;   $A0-$D7  free
;   $D8-$F7  free
;   $F8-$FF  stack (the single JSR uses $FF/$FE; SP returns to $FF)
;
; Build: acme -f plain -o build/lesson59.bin \
;        lessons/part8-advanced/59-self-modifying-code/59-self-modifying-code.asm
; Run:   stella build/lesson59.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44          ; 37-line VBLANK (44 ticks)
OVERSCAN_TIMER = 36          ; 30-line overscan (36 ticks)

GRADIENT_LINES = 184         ; visible lines 8-191
STATUS_LINES   = 8           ; visible lines 0-7
SCREEN_LINES   = 192         ; 8 status + 184 gradient

C_BG           = $00         ; black behind the status band
C_STATUS_A     = $0E         ; white: the PatchVal field
C_STATUS_B     = $1A         ; gold: the CallCount field

; =============================================================================
; RAM ALLOCATION ($80-$FF; +clean_start zeroes every byte)
; =============================================================================
; The routine occupies $80-$86.  The equates below are the variables; the
; routine is addressed with the RamRoutine equate so a breakpoint at $0080
; names the copied code, not a ROM label.
RamRoutine   = $80           ; A9 xx 85 09 85 02 60 (seven bytes)
PatchVal     = $87           ; the last color patched into $81
Calls        = $88           ; the number of calls this frame (184)
FrameNum     = $89           ; frames since reset (wraps at 256)
Phase        = $8A           ; the table phase, 0-183
HoldFrames   = $8B           ; one-shot 60-frame hold before the phase moves
PhaseTimer   = $8C           ; divides the post-hold frames by four

; $8D-$9F, $A0-$D7, and $D8-$F7 are free.  The stack lives at $F8-$FF; the
; call depth is one (the main loop's JSR $80), so the stack uses $FF/$FE only.

; A build-time guard: the status and gradient must fill the 192-line picture.
    !if STATUS_LINES + GRADIENT_LINES != SCREEN_LINES {
        !error "the status and the gradient must total 192 visible lines"
    }

; =============================================================================
; RESET — copy the routine, set the TIA, and start the frame loop
; =============================================================================
    * = $F000

Reset:
    +clean_start            ; zero TIA + RAM, set SP = $FF

; The phase hold is one-shot: it must not repeat when FrameNum wraps.
    LDA #60
    STA HoldFrames

; -----------------------------------------------------------------------------
; 1. COPY THE SEVEN-BYTE ROUTINE FROM ROM TO $80
; -----------------------------------------------------------------------------
; This must happen after +clean_start: the macro zeroes all of RAM, including
; $80-$86.  The template is in ROM (RoutineTemplate, below); the loop copies
; indices 6 down to 0.  DEX sets N when X wraps from $00 to $FF, so BPL exits
; after the index-0 byte is copied.
    LDX #6
CopyRoutine:
    LDA RoutineTemplate,X   ; the ROM byte
    STA $80,X               ; the RAM copy: $80-$86
    DEX
    BPL CopyRoutine

; -----------------------------------------------------------------------------
; 2. THE TIA'S FIXED STATE
; -----------------------------------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; a black page until the first gradient line
    LDA #C_STATUS_A
    STA COLUPF              ; the status field is white
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the fields mirror

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
; The counter is the only per-frame work in VBLANK: the demo has no input and
; no game logic.  Frame: is placed on the NOP so the breakpoint fires once per
; frame (the +wait_timer loop polls INTIM many times, so a label inside it
; would report the timer value, not the frame count).
    INC FrameNum
    LDA FrameNum
Frame:                      ; checkpoint: A = the new frame count
    NOP

; Advance the table phase one entry every four frames, after a one-shot
; 60-frame hold at phase 0.  HoldFrames is a separate byte, not FrameNum:
; FrameNum wraps at 256, and a compare against it would freeze the phase again
; every 256 frames.  The one-shot hold makes the first capture deterministic;
; the first phase step lands four frames after the hold expires.
    LDA HoldFrames
    BEQ PhaseTick
    DEC HoldFrames
    JMP NoPhase
PhaseTick:
    INC PhaseTimer
    LDA PhaseTimer
    AND #$03
    BNE NoPhase
    INC Phase
    LDA Phase
    CMP #GRADIENT_LINES
    BCC NoPhase
    LDA #$00
    STA Phase
NoPhase:

; Load the first status field while the picture is still blanked.  The PF1
; store must not race playfield chunk 4 on visible line 0; doing it here, in
; VBLANK, means the first line starts with its field already set.  The
; +wait_timer macro clobbers A but preserves Y.
    LDA #C_BG
    STA COLUBK
    LDA #C_STATUS_A
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF2
    LDA PatchVal
    STA PF1
    LDY #4

    +wait_timer             ; wait out the 37-line VBLANK
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; THE VISIBLE KERNEL — 192 lines
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    NOP                     ; one-time hit; StatusPatch is the loop target

; -----------------------------------------------------------------------------
; ZONE 1: EIGHT STATUS LINES — the patch byte and the call count
; -----------------------------------------------------------------------------
; Both fields are eight PF1 bits at playfield chunks 4-11.  PF1 bit 7 is the
; leftmost chunk of the field, so the byte reads bit 7 first.  The top four
; lines are white and show PatchVal; the next four are gold and show Calls.
; COLUBK is black behind the status.
StatusPatch:
    STA WSYNC               ; one status line per pass
    DEY
    BNE StatusPatch

    LDA #C_STATUS_B
    STA COLUPF
    LDA Calls
    STA PF1
    LDY #4
StatusCalls:
    STA WSYNC
    DEY
    BNE StatusCalls

; Clear the playfield before the gradient: PF1 still holds the call-count
; field, and an uncleared PF1 would paint eight vertical bars down the whole
; gradient.
    LDA #$00
    STA PF1

; -----------------------------------------------------------------------------
; ZONE 2: 184 GRADIENT LINES — patch the routine, call it, repeat
; -----------------------------------------------------------------------------
; The phase window is split in two because Y is only eight bits.  The first
; window starts at Y = Phase and reads ColorTable,Y; it can reach Y = 255,
; which covers table[Phase..183] and the second copy's table[0..71].  If Y
; wraps, the second window starts at Y = 0 and reads ColorTable+256,Y, which
; is the second copy's table[72..]; it finishes the remaining table[72..Phase-1]
; entries.  X is the line counter, so every frame draws exactly 184 lines.
; The last line skips the normal tail and returns from JSR directly into the
; overscan: that is what puts OverscanStart at 229/6.
    LDY Phase
    LDX #GRADIENT_LINES
FirstWindow:
    LDA ColorTable,Y        ; page-aligned: always a 4-cycle abs,Y load
PatchByte:                  ; checkpoint: A = the new color
    STA $81                 ; patch the LDA #'s immediate operand
    INY
    DEX
    BEQ LastLine
    JSR RamRoutine          ; LDA #color; STA COLUBK; STA WSYNC; RTS
    CPY #0                  ; did the table index wrap past 255?
    BNE FirstWindow
SecondWindow:
    ; Y is already 0 here: the first window's INY wrapped it.  Do not reload
    ; it; the hand-off is then one cycle shorter than a steady tail line.
SecondWindowLoop:
    LDA ColorTable+256,Y    ; second copy, offset 72: table[72..]
PatchByteTail:              ; checkpoint: A = the new color in the tail
    STA $81
    INY
    DEX
    BEQ LastLine
    JSR RamRoutine
    CPY #0                  ; harmless pad: matches the first window's tail
    BNE SecondWindowLoop
LastLine:
    STA PatchVal            ; A = the last color
    LDA #GRADIENT_LINES
CallCount:                  ; checkpoint: A = 184
    STA Calls               ; the frame's call count
    JSR RamRoutine          ; the 184th visible line
; The last routine's STA WSYNC ends visible line 191; its RTS returns here at
; scanline 229, cycle 6.

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229, cycle 6
    LDA #$02
    STA VBLANK              ; blank during overscan
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; THE ROM TEMPLATE — the seven bytes that are copied to $80
; =============================================================================
; The bytes are written with !byte rather than mnemonics so the copy is
; explicit: the operand at $81 is the byte the main loop patches.  The
; assembled bytes are A9 00 85 09 85 02 60.
RoutineTemplate:
    !byte $A9, $00          ; $80  A9 00  LDA #$00 (operand at $81)
    !byte $85, COLUBK       ; $82  85 09  STA COLUBK
    !byte $85, WSYNC        ; $84  85 02  STA WSYNC
    !byte $60               ; $86  60     RTS

; =============================================================================
; THE COLOR TABLE — 184 entries, one per gradient line
; =============================================================================
; hue = (line * 16) / 184: sixteen bands, about 11.5 lines each.
; luminance = 1 + round(6 * |sin(pi * line / 183)|): dark at both ends,
; bright in the middle.  A TIA color byte is CCCCLLL0: the high nibble is the
; hue (0-15), bits 3-1 are the luminance (0-7), and bit 0 is unused.  Every
; entry below is even, as a color byte must be.  The table is page-aligned so
; neither window's LDA abs,Y crosses a page: the first window reads
; $F100-$F1FF, the second reads $F200-$F26E.
    !align 255, 0
ColorTable:
    !byte $02, $02, $02, $02, $02, $04, $04, $04   ; lines   0-  7, hue 0
    !byte $04, $04, $04, $04, $14, $14, $14, $16   ; lines   8- 15, hue 0-1
    !byte $16, $16, $16, $16, $16, $16, $16, $26   ; lines  16- 23, hue 1-2
    !byte $26, $26, $28, $28, $28, $28, $28, $28   ; lines  24- 31, hue 2
    !byte $28, $28, $28, $38, $38, $3A, $3A, $3A   ; lines  32- 39, hue 2-3
    !byte $3A, $3A, $3A, $3A, $3A, $3A, $4A, $4A   ; lines  40- 47, hue 3-4
    !byte $4A, $4A, $4C, $4C, $4C, $4C, $4C, $4C   ; lines  48- 55, hue 4
    !byte $4C, $4C, $5C, $5C, $5C, $5C, $5C, $5C   ; lines  56- 63, hue 4-5
    !byte $5C, $5C, $5C, $5C, $5E, $6E, $6E, $6E   ; lines  64- 71, hue 5-6
    !byte $6E, $6E, $6E, $6E, $6E, $6E, $6E, $6E   ; lines  72- 79, hue 6
    !byte $6E, $7E, $7E, $7E, $7E, $7E, $7E, $7E   ; lines  80- 87, hue 6-7
    !byte $7E, $7E, $7E, $7E, $8E, $8E, $8E, $8E   ; lines  88- 95, hue 7-8
    !byte $8E, $8E, $8E, $8E, $8E, $8E, $8E, $8E   ; lines  96-103, hue 8
    !byte $9E, $9E, $9E, $9E, $9E, $9E, $9E, $9E   ; lines 104-111, hue 9
    !byte $9E, $9E, $9E, $AE, $AC, $AC, $AC, $AC   ; lines 112-119, hue 9-10
    !byte $AC, $AC, $AC, $AC, $AC, $AC, $AC, $BC   ; lines 120-127, hue 10-11
    !byte $BC, $BC, $BC, $BC, $BC, $BC, $BA, $BA   ; lines 128-135, hue 11
    !byte $BA, $BA, $CA, $CA, $CA, $CA, $CA, $CA   ; lines 136-143, hue 11-12
    !byte $CA, $CA, $CA, $C8, $C8, $C8, $D8, $D8   ; lines 144-151, hue 12-13
    !byte $D8, $D8, $D8, $D8, $D8, $D8, $D6, $D6   ; lines 152-159, hue 13
    !byte $D6, $E6, $E6, $E6, $E6, $E6, $E6, $E6   ; lines 160-167, hue 13-14
    !byte $E6, $E4, $E4, $E4, $E4, $F4, $F4, $F4   ; lines 168-175, hue 14-15
    !byte $F4, $F4, $F4, $F2, $F2, $F2, $F2, $F2   ; lines 176-183, hue 15

; --- the second copy: 184 more entries; offset 72 is ColorTable+256 ----------
; The first window uses the first 256 bytes; its wrapped tail uses the second
; copy's first 72 entries.  The second window starts at ColorTable+256, which
; is this copy's table[72], and finishes the window.
ColorTableWrap:
    !byte $02, $02, $02, $02, $02, $04, $04, $04
    !byte $04, $04, $04, $04, $14, $14, $14, $16
    !byte $16, $16, $16, $16, $16, $16, $16, $26
    !byte $26, $26, $28, $28, $28, $28, $28, $28
    !byte $28, $28, $28, $38, $38, $3A, $3A, $3A
    !byte $3A, $3A, $3A, $3A, $3A, $3A, $4A, $4A
    !byte $4A, $4A, $4C, $4C, $4C, $4C, $4C, $4C
    !byte $4C, $4C, $5C, $5C, $5C, $5C, $5C, $5C
    !byte $5C, $5C, $5C, $5C, $5E, $6E, $6E, $6E
    !byte $6E, $6E, $6E, $6E, $6E, $6E, $6E, $6E
    !byte $6E, $7E, $7E, $7E, $7E, $7E, $7E, $7E
    !byte $7E, $7E, $7E, $7E, $8E, $8E, $8E, $8E
    !byte $8E, $8E, $8E, $8E, $8E, $8E, $8E, $8E
    !byte $9E, $9E, $9E, $9E, $9E, $9E, $9E, $9E
    !byte $9E, $9E, $9E, $AE, $AC, $AC, $AC, $AC
    !byte $AC, $AC, $AC, $AC, $AC, $AC, $AC, $BC
    !byte $BC, $BC, $BC, $BC, $BC, $BC, $BA, $BA
    !byte $BA, $BA, $CA, $CA, $CA, $CA, $CA, $CA
    !byte $CA, $CA, $CA, $C8, $C8, $C8, $D8, $D8
    !byte $D8, $D8, $D8, $D8, $D8, $D8, $D6, $D6
    !byte $D6, $E6, $E6, $E6, $E6, $E6, $E6, $E6
    !byte $E6, $E4, $E4, $E4, $E4, $F4, $F4, $F4
    !byte $F4, $F4, $F4, $F2, $F2, $F2, $F2, $F2

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
> `lessons/part8-advanced/59-self-modifying-code/59-self-modifying-code.asm`.

### Code Walkthrough

#### Step 1 — Reset: copy the routine, then set the TIA

`+clean_start` zeroes the TIA, zeroes all 128 bytes of RAM, and sets SP to `$FF`. The first job after it is the copy:

```asm
    LDX #6
CopyRoutine:
    LDA RoutineTemplate,X
    STA $80,X
    DEX
    BPL CopyRoutine
```

The loop copies indices 6 down to 0, which is `$86` down to `$80`. `DEX` sets N when X wraps to `$FF`, so `BPL` falls through after the last byte. The template is in ROM at `RoutineTemplate`; the running copy is in RAM at `$80`.

The TIA setup is deliberately minimal: black background, white playfield color, `PF0`/`PF1`/`PF2` clear, and `CTRLPF=$01` to reflect the playfield. No players, missiles, or ball are used in the main demo, so there is no `RESP`/`HMOVE` in the frame.

#### Step 2 — The frame skeleton

The frame is the course's NTSC skeleton:

```asm
StartFrame:
    +vsync                  ; 3 lines
VblankStart:
    LDA #$02
    STA VBLANK              ; blank
    +set_timer 44           ; 37-line VBLANK
    INC FrameNum
    LDA FrameNum
Frame:                      ; checkpoint: A = the new frame count
    NOP
    ; ... phase update ...
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:
    ; ... 192 visible lines ...
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer 36           ; 30-line overscan
    +wait_timer
    JMP StartFrame
```

`StartFrame` is at scanline 259/3, `VblankStart` at 0/5, `BodyStart` at 37/5, and `OverscanStart` at 229/6. The `Frame` label sits on a `NOP` after `LDA FrameNum`, so the breakpoint fires once per frame; a label inside `+wait_timer` would fire on every timer poll instead.

The phase update runs in VBLANK, where there is time to spare:

```asm
    LDA HoldFrames
    BEQ PhaseTick
    DEC HoldFrames
    JMP NoPhase
PhaseTick:
    INC PhaseTimer
    LDA PhaseTimer
    AND #$03
    BNE NoPhase
    INC Phase
    LDA Phase
    CMP #GRADIENT_LINES
    BCC NoPhase
    LDA #$00
    STA Phase
NoPhase:
```

`HoldFrames` is a one-shot counter, not a compare against `FrameNum`. If the code compared `FrameNum` with 60, the hold would restart during frames 256-315 because the 8-bit counter wraps — the phase would freeze for about a second every 4.3 seconds. The one-shot byte avoids that. The first 60 frames hold phase 0; the first phase step lands on frame 64 (the fourth `PhaseTimer` tick after the hold expires). The `CMP #GRADIENT_LINES` / `BCC` pair wraps 184 back to 0. The phase does not change the frame's line count.

#### Step 3 — The status band

The status band is eight lines, four per field. `PF1` carries the eight bits; `PF0` and `PF2` are cleared so no other playfield chunks are lit. The first field is loaded **in VBLANK**, while the picture is still blanked, so the `PF1` store cannot race playfield chunk 4 on visible line 0:

```asm
    LDA #C_BG
    STA COLUBK              ; black behind the status
    LDA #C_STATUS_A
    STA COLUPF              ; white
    LDA #$00
    STA PF0
    STA PF2
    LDA PatchVal
    STA PF1
    LDY #4
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:
    NOP                     ; one-time hit; StatusPatch is the loop target
StatusPatch:
    STA WSYNC
    DEY
    BNE StatusPatch
```

`+wait_timer` clobbers A but preserves Y, so the four-line count survives the wait. The second field repeats the pattern with `C_STATUS_B` (gold) and `Calls`. After the eighth line, `PF1` is cleared before the gradient; otherwise the status bits would paint eight vertical bars down the whole screen. That clear is a one-line fix that is easy to forget: the playfield registers persist until they are written again.

#### Step 4 — The gradient loop and the last-line special case

The gradient loop is the heart of the lesson, and it is split in two because Y is only eight bits:

```asm
    LDY Phase
    LDX #GRADIENT_LINES
FirstWindow:
    LDA ColorTable,Y
PatchByte:                  ; checkpoint: A = the new color
    STA $81                 ; patch the LDA #'s immediate operand
    INY
    DEX
    BEQ LastLine
    JSR RamRoutine
    CPY #0                  ; did the table index wrap past 255?
    BNE FirstWindow
SecondWindow:
    LDY #0
SecondWindowLoop:
    LDA ColorTable+256,Y    ; second copy, offset 72: table[72..]
PatchByteTail:              ; checkpoint: A = the new color in the tail
    STA $81
    INY
    DEX
    BEQ LastLine
    JSR RamRoutine
    CPY #0
    BNE SecondWindowLoop
LastLine:
    STA PatchVal            ; A = the last color
    LDA #GRADIENT_LINES
CallCount:                  ; checkpoint: A = 184
    STA Calls
    JSR RamRoutine          ; the 184th visible line
```

Four details keep the frame at 192 lines and the phase correct:

- **X is the line counter, Y is the table index.** If the loop used `CPY #184` with Y starting at `Phase`, a phase above 0 would draw fewer than 184 lines. X counts 184 lines independently of the phase.
- **The first window cannot cover the whole phase.** Y runs from Phase to 255, so the first window covers `table[Phase..183]` plus the second copy's `table[0..71]`. If it exits by wrapping, the second window starts at `ColorTable+256,Y`, the second copy's `table[72..]`, and finishes the remaining entries. Without the split, phases above 72 read `table[0]` where `table[72]` belongs.
- **The table is page-aligned.** `ColorTable` is at `$F100`, so the first window reads `$F100-$F1FF` and the second reads `$F200-$F26E`; neither `LDA abs,Y` crosses a page. The color write keeps one cycle count.
- **The last line skips the normal tail.** On the last iteration `DEX` makes X zero and `BEQ LastLine` jumps over the normal `JSR`/tail. The last line still calls the routine once. Its `RTS` returns directly to `OverscanStart`, which is why `OverscanStart` lands at 229/6 instead of 229/13.

The last line stores `PatchVal` and `Calls` **before** its `JSR`. The values are already known (A holds the last color, and 184 is the line count), and doing the stores after the `WSYNC` would push the overscan start later. This is the same kind of budget arithmetic as the color write: every instruction after the `WSYNC` is on the visible frame's clock.

#### Step 5 — The routine and the table

The template and the table are data at the end of the source:

```asm
RoutineTemplate:
    !byte $A9, $00          ; LDA #$00
    !byte $85, COLUBK       ; STA COLUBK
    !byte $85, WSYNC        ; STA WSYNC
    !byte $60               ; RTS

ColorTable:
    !byte $02, $02, ...     ; 184 entries, hue and luminance
ColorTableWrap:
    !byte $02, $02, ...     ; the same 184 entries again
```

The template is copied to `$80`; the table is read, never copied. The table is page-aligned at `$F100` and stored twice. The first copy is `table[0..183]`; the second copy begins at `$F1B8`, so `ColorTable+256` is `$F200`, the second copy's `table[72]`. The first window reads the first 256 bytes; the second reads `ColorTable+256` onward. The whole block is 368 bytes.

The `!byte $85, COLUBK` form is intentional. `COLUBK` is `$09`, so the bytes are `85 09`; `WSYNC` is `$02`, so they are `85 02`. The source shows the exact template that the debugger will find at `$80`.

## What You Should See

At power-on the picture is a 192-line test card. The top eight lines are the status band: four white lines show `PatchVal` as eight playfield chunks, then four gold lines show `Calls`. The fields sit at chunks 4-11 and are mirrored on the right. Below them, 184 lines of gradient run from a dark olive through orange, red, magenta, purple, blue, cyan, green, and back to olive. Each line is one color from the table. The steady color write is on cycle 34; the write applies three clocks later, so the left edge of each line keeps the previous color for 37 pixels (`x = 247`). The first line's longer setup makes its strip 46 pixels (`x = 301`); the last line's bookkeeping makes its strip 64 pixels (not visible at phase 0 because the last two colors match). The table is page-aligned, so there is no page-cross step between the two windows. The phase holds at 0 for a one-shot 60 frames, then scrolls one entry every four frames; the first step lands on frame 64.

![Stella running the Lesson 59 ROM at table phase 0: an eight-line status band with two white/gold binary fields, then a 184-line color gradient from olive through orange, red, magenta, purple, blue, cyan and green; the left edge shows the one-line color stair-step; the title bar reads Stella 7.0: "59-self-modifying-code"](/images/lesson59/painter-a.png)

*`painter-a`: table phase 0. The status's top field reads `$F2` (chunks 4-7 and 10 lit); the bottom field reads `$B8` (184, chunks 4, 6, 7, and 8). The first gradient line is `$02`. The steady left-edge transition is at `x = 247`, TIA X 37; the first line's is at `x = 301`, TIA X 46.*

![Stella running the Lesson 59 ROM at table phase 96: the same status band but with the top field reading $8E, and a gradient whose hue bands have shifted; the left edge still shows the one-line color stair-step; the title bar reads Stella 7.0: "59-self-modifying-code"](/images/lesson59/painter-b.png)

*`painter-b`: table phase 96, captured from the same committed ROM a few seconds later. The top field reads `$8E` (chunks 4, 8, 9, and 10); the first gradient line is `$8E`. The first window covers visible lines 8-167 and the second window 168-191; both have the same 37-pixel steady strip. The hue bands have moved; the code, the routine, and the frame have not changed.*

<RomPlayer rom="/roms/part8-advanced/59-self-modifying-code/59-self-modifying-code.bin" title="Lesson 59 — Self-Modifying Code" />

Javatari starts muted; this ROM is silent, so there is nothing to unmute. The ROM uses a plain 4K cartridge, so every 2600 emulator can run it.

> **Capture method.** The two images are window captures of
> `docs/public/roms/part8-advanced/59-self-modifying-code/59-self-modifying-code.bin`
> in Stella 7.0, launched with a fresh Stella base directory, `-audio.enabled 0`,
> `-uimessages 0` (so the startup OSD is absent), a fixed 3× zoom, and a fixed
> window position. The window is 1010×807 including the title bar. The pointer
> was parked at `(0, 0)` before the captures, so the images contain no cursor.
> A burst of window captures was taken while the ROM ran; the two frames were
> selected by decoding the status's top field and the first gradient line.
> `painter-a` is phase 0 (`PatchVal` `$F2`); `painter-b` is phase 96
> (`PatchVal` `$8E`). The 184-line colour sequence in `painter-b` is consistent
> with `table[96..183] + table[0..95]` (172 of 184 sampled lines match exactly;
> the rest are line-boundary or left-edge samples), which verifies the split
> window. Both are
> captures of the same committed ROM; no modified ROM was used. The title
> bars read `Stella 7.0: "59-self-modifying-code"`.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
ROM=docs/public/roms/part8-advanced/59-self-modifying-code/59-self-modifying-code.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F033' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F041' $ROM   # VblankStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F08B' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0D1' $ROM   # OverscanStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F04E' $ROM   # Frame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0AB' $ROM   # PatchByte
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0BB' $ROM   # PatchByteTail
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0CC' $ROM   # CallCount
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$0080' $ROM   # RamRoutine
```

| Checkpoint | Address | Measured | Meaning |
|---|---|---|---|
| `StartFrame` | `$F033` | 259/3 steady; 34/67 on the power-on frame | the first VSYNC instruction |
| `VblankStart` | `$F041` | 0/5 | the first VBLANK instruction |
| `BodyStart` | `$F08B` | 37/5 | the first visible-line instruction |
| `OverscanStart` | `$F0D1` | 229/6 | the first overscan instruction |
| `Frame` | `$F04E` | A = 1, 2, 3, … | the new frame count |
| `PatchByte` | `$F0AB` | A = `$02`, `$04`, `$14`, `$16`, … | the new color in the first window |
| `PatchByteTail` | `$F0BB` | A = `$6E` (first wrap, phase 73) | the new color in the second window |
| `CallCount` | `$F0CC` | A = `$B8` (184) | the frame's call count |
| `RamRoutine` | `$0080` | PC = `$0080`, A = the color, SP = `$FD` | the routine executing from RAM |

The state log's frame, scanline, and cycle fields are the evidence:

```text
BP:           1 259 03 -59 | nv-BdIZC 00 00 b8 ff |   # StartFrame
BP:           2 259 03 -59 | nv-BdIZC 00 00 b8 ff |
BP:           3 259 03 -59 | nv-BdIZC 00 00 b8 ff |
BP:           1   0 05 -53 | nv-BdIZC 00 ff 00 ff |   # VblankStart
BP:           2   0 05 -53 | nv-BdIZC 00 00 b8 ff |
BP:           3   0 05 -53 | nv-BdIZC 00 00 b8 ff |
BP:           1  37 05 -53 | nv-BdIZC 00 ff 00 ff |   # BodyStart
BP:           2  37 05 -53 | nv-BdIZC 00 00 b8 ff |
BP:           3  37 05 -53 | nv-BdIZC 00 00 b8 ff |
BP:           1 229 06 -50 | Nv-BdIzC f2 00 b8 ff |   # OverscanStart
BP:           2 229 06 -50 | Nv-BdIzC f2 00 b8 ff |
BP:           3 229 06 -50 | Nv-BdIzC f2 00 b8 ff |
BP:           1   0 24   4 | nv-BdIzC 01 ff 00 ff |   # Frame, A=1
BP:           2   0 24   4 | nv-BdIzC 02 00 b8 ff |   # Frame, A=2
BP:           3   0 24   4 | nv-BdIzC 03 00 b8 ff |   # Frame, A=3
```

`PatchByte` fires once per line in the first window; at phase 0 that is all 184 gradient lines. (`PatchByteTail` takes over the remaining lines when the phase is above 72.) Its first hits are the first table entries (`$02`); later hits show the hue sweep:

```text
BP:           1  45 18 -14 | nV-BdIzc 02 b8 00 ff |   # PatchByte, first line, A=$02
BP:           1  46 15 -23 | nV-BdIzC 02 b7 01 ff |   # A=$02
BP:           1  47 15 -23 | nV-BdIzC 02 b6 02 ff |   # A=$02
BP:           1  57 15 -23 | nV-BdIzC 14 ac 0c ff |   # A=$14
BP:           1  60 15 -23 | nV-BdIzC 16 a9 0f ff |   # A=$16
BP:           1  71 15 -23 | nV-BdIzC 28 9e 1a ff |   # A=$28
```

The `PatchByteTail` breakpoint first fires when the phase reaches 73 (frame 352). The first window has read `table[73..183] + table[0..71]`; the second window now reads `table[72]`, whose value is `$6E` — not the `table[0] = $02` that the old single-window loop would have read:

```text
BP:         352 228 14 -26 | nV-BdIzC 6e 01 00 ff |   # frame 352, phase 73, A=table[72]=$6E
BP:         353 228 14 -26 | nV-BdIzC 6e 01 00 ff |
BP:         356 227 14 -26 | nV-BdIzC 6e 02 00 ff |
BP:         356 228 15 -23 | nV-BdIzC 6e 01 01 ff |   # second tail line: X=1, Y=1
```

The `CallCount` breakpoint reports `A = $B8` on the last line of every frame:

```text
BP:           1 228 30  22 | NV-BdIzC b8 00 b8 ff |   # CallCount, A=184
BP:           2 228 30  22 | NV-BdIzC b8 00 b8 ff |
BP:           3 228 30  22 | NV-BdIzC b8 00 b8 ff |
```

The `RamRoutine` breakpoint shows the routine running from `$0080`, with SP at `$FD` because the `JSR` has pushed its return address:

```text
BP:           1  45 33  31 | NV-BdIzc 02 b7 01 fd |   # RamRoutine, PC=$0080, A=$02
BP:           2  46 30  22 | NV-BdIzC 02 b6 02 fd |
BP:           3  47 30  22 | NV-BdIzC 02 b5 03 fd |
```

`$0080` is RAM, not ROM. The copied bytes are the seven-byte template:

| Address | Bytes | Disassembly | Meaning |
|---|---|---|---|
| `$0080` | `A9 xx` | `LDA #$xx` | the operand at `$0081` is patched |
| `$0082` | `85 09` | `STA $09` | `COLUBK` |
| `$0084` | `85 02` | `STA $02` | `WSYNC` |
| `$0086` | `60` | `RTS` | return to the main loop |

The `STA COLUBK` instruction is at `$0082`; its write happens on the third cycle. The `RamRoutine` breakpoint at `$0080` reports cycle 30 on a steady line, and the `$0082` breakpoint reports cycle 32; the write lands on cycle 34. The write applies about three clocks later, so the steady strip is 37 pixels. The first line's `$0082` is at 45/35 (write 37, 46 pixels); the last line's is at 228/41 (write 43, 64 pixels). That is the measurement behind the 3-pixels-per-cycle rule in the Theory section.

The pixel checks decode the two captures with `x = 25 + 6 × TIA pixel` and `y = 106 + 3.15625 × visible line`:

| Check | `painter-a.png` | `painter-b.png` | Expected |
|---|---|---|---|
| full image | 1010×807 | 1010×807 | window plus title bar |
| title bar | `Stella 7.0: "59-self-modifying-code"` | the same | the committed ROM |
| active top | `y = 106` | `y = 106` | visible line 0 |
| status top field | `PatchVal = $F2`, white, chunks 4-7 and 10 (x = 121-216, 265-288; mirrors 721-744, 793-888) | `PatchVal = $8E`, chunks 4, 8, 9, 10 (x = 121-144, 217-288; mirrors 721-792, 865-888) | the phase |
| status bottom field | `Calls = $B8`, gold, chunks 4, 6, 7, 8 (x = 121-144, 169-240; mirrors 769-840, 865-888) | the same | 184 calls |
| first gradient line | `$02` (63, 63, 62) at visible 8 | `$8E` (121, 134, 251) at visible 8 | the table phase |
| gradient | 184 lines, olive → orange → red → magenta → purple → blue → cyan → green | `table[96..183] + table[0..95]` | 184 lines |
| steady left-edge strip | `x = 247` (TIA X 37) | `x = 247` (TIA X 37) | cycle 34 + 3-clock application delay |
| first line strip | `x = 301` (TIA X 46) | `x = 301` (TIA X 46) | write 37: +3 cycles, +9 pixels |
| first tail line after wrap | — (phase 0 has no tail) | 34 px (`x = 229`); hidden, `table[71]=table[72]=$6E` | hand-off: write 33 (-1 cycle, -3 pixels) |
| last line strip | 64 px (not visible in this capture) | 64 px (not visible in this capture) | write 43: +9 cycles, +27 pixels |
| cursor | none | none | pointer parked at (0,0) |
| startup OSD | none | none | the captures are after the OSD fades |

The two captures differ exactly where the lesson says they should: the status's top field and the whole gradient phase. The bottom field (`Calls = 184`) is identical, because the number of lines and calls never changes.

## Exercises

### Exercise 1: Patch a Delay Count

**Challenge:** add a small delay loop before the routine's color write, patch the `LDX` operand from a 184-entry delay table, and watch the gradient's left-edge seam sweep across the screen. The screen should keep the 8 status lines and the 184 gradient lines, and the frame must stay at 262 lines.

**Hints:**
1. Copy a 12-byte routine: `LDX #n` / `DEX` / `BNE` / `LDA #color` / `STA COLUBK` / `STA WSYNC` / `RTS`. The delay operand is at `$81`; the color operand moves to `$86`.
2. Patch `$81` from a delay table and `$86` from the color table. A delay of 0 does **not** work with `LDX`/`DEX`/`BNE` — `DEX` wraps 0 to `$FF` and the loop runs 255 times. Use 1..4.
3. Keep the delay small enough that the `STA WSYNC` still lands inside the 76-cycle line. The budget reaches the `WSYNC` write at cycle 70 for delay 5 and 75 for delay 6; delay 7 overflows the 76-cycle line. Both tables are page-aligned, so the two loads are always four cycles; delay 6 fits with one cycle to spare. The solution's table stops at 4 to leave margin.
4. Display the last delay in the status's top field and the call count in the bottom field.

**Expected Result:** the ROM assembles to 4,096 bytes. The left-edge seam moves right as the delay grows from 1 to 4, then resets, producing a repeating diagonal band over the gradient. `DelayPatch` reports A = 1, 2, 3, 4 on successive lines; `PatchByte` reports the color; `CallCount` reports `$B8`; the frame stays at `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6. The top status field reads 4; the bottom reads 184.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Patch a Table Address

**Challenge:** replace the immediate load with `LDA TableA,X`, patch the instruction's two address bytes to select `TableA` or `TableB`, and switch tables every 60 frames. The two tables must be page-aligned so the absolute,X load never crosses a page and the color write keeps a fixed cycle.

**Hints:**
1. The routine is eight bytes: `BD lo hi` (`LDA TableA,X`), `85 09` (`STA COLUBK`), `85 02` (`STA WSYNC`), `60` (`RTS`).
2. Patch `$81` (low byte) and `$82` (high byte). At reset the template points at `TableA`; when the switch fires, write the new low/high bytes.
3. Page-align both tables (`!align 255, 0`) and make each exactly 184 bytes. Then X = 0..183 stays inside one page.
4. Use X as the table index and a separate line counter (or a compare against 183) so the last line uses X = 183, not 184.

**Expected Result:** the ROM assembles to 4,096 bytes. The gradient changes phase every 60 frames. `PtrLowB`/`PtrHighB` report A = `$00`/`$F2` (the address of `TableB`), and `PtrLowA`/`PtrHighA` report A = `$00`/`$F1` (the address of `TableA`); the `TableRead` breakpoint at `$0083` reports the color read from the selected table. The status's top field shows `TableID` 0 or 1; the bottom shows 184. The frame stays at 259/3, 0/5, 37/5, 229/6.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: A Second RAM Routine Draws an Object *(Stretch Goal)*

**Challenge:** copy a second routine to `$90`, patch its shape operand, and draw a P0 object over the gradient. The second routine is `LDA #shape` / `STA GRP0` / `RTS`; the shape table is 184 bytes, one byte per line. Position P0 once per frame with one `HMOVE`.

**Hints:**
1. Copy the gradient routine (7 bytes) to `$80` and the shape routine (5 bytes) to `$90`. The shape operand is at `$91`; the gradient operand is at `$81`.
2. Call the shape routine **before** the gradient routine. The shape write must happen before the beam reaches P0's X; the color write can be later.
3. Position P0 in VBLANK with the divide-by-15 dance and one `HMOVE`. The solution uses `P0_X = 80` and `POS_BIAS = 3`.
4. Clear `GRP0` before the status band; otherwise the last shape byte from the previous frame sits over the status field.
5. Expect a wider left-edge smear: the second `JSR` and patch spend more of the 76-cycle line.

**Expected Result:** the ROM assembles to 4,096 bytes. A gold chain of 23 diamonds runs down the screen at TIA X 80 over the gradient. `ShapePatch` reports A = `$18`, `$3C`, `$7E`, `$FF` on four successive lines; `ShapeRoutine` executes from `$0090`; the frame stays at `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, and `OverscanStart` 229/6. The status's top field shows the first shape byte (`$18`); the bottom shows 184. The gradient's left-edge transition is wider than the main lesson's — the price of the second routine.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **ROM is read-only; RIOT RAM is executable.** A self-modifying routine must be copied from the cartridge to `$80-$FF` before the CPU can run or patch it.
- ✅ **The 128 bytes are also the stack.** `+clean_start` sets SP to `$FF`; a `JSR` uses `$FF/$FE`; keep the routine and variables below `$F8`, and keep the RAM routine a leaf.
- ✅ **The pattern is copy, patch, call.** A seven-byte template at `$80`, a one-byte patch at `$81`, and `JSR $80` once per line. The disassembly stays `A9 xx 85 09 85 02 60`.
- ✅ **The cost is measurable.** The patch and the call put `STA COLUBK` at 46/32, so its write lands on cycle 34 and the steady previous-color strip is 37 pixels. The first line is 46 pixels (write 37) and the last is 64 pixels (write 43); one CPU cycle is three pixels. A data-driven table is faster and cleaner — self-modifying code is for when the instruction itself must change.
- ✅ **X counts lines, Y indexes the table.** Separating the counter from the phase offset is what lets the gradient start anywhere without changing the 184-line picture.
- ✅ **The phase is the only moving part.** The status band shows the last patched color and the call count; the gradient scrolls one table entry every four frames.
- ✅ **Follow the safety rules.** Fixed length, known entry, no stack use inside, no overlap with the stack, copy after `+clean_start`, patch only the operand, and verify the disassembly in Stella.

## What's Next

Self-modifying code changes the program with the CPU's own instruction stream. [Lesson 60: DPC and DPC+ — Enhanced Audio and Graphics](/part8-advanced/60-dpc-plus) changes the *cartridge*: a display processor fetches playfield bytes from a 2 KB image, and the lesson explains what the Harmony/Melody DPC+ coprocessor adds. The 4K world is about to get a co-processor.
