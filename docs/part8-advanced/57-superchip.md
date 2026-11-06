---
title: "Lesson 57: Superchip — Extra RAM"
description: "Add 128 bytes of cartridge RAM to the F8 mapper: build the F8SC write/read windows at $1000–$107F and $1080–$10FF, duplicate the 128-byte signature that lets Stella detect the mapper, start code at $F100, and run 'the 128-byte notebook' — a scrolling message, a 16-cell write gauge, and a moving player marker — then prove the RAM survives a bank switch."
prev:
  text: "Lesson 56: Bankswitching — Beyond 4KB"
  link: "/part8-advanced/56-bankswitching"
next:
  text: "Lesson 58: Illegal Opcodes — Undocumented Power"
  link: "/part8-advanced/58-illegal-opcodes"
---

# Lesson 57: Superchip — Extra RAM

> **Part 8: Advanced Topics** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and memory), Lesson 12 (the frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players), Lesson 26 (positioning), Lesson 48 (the kernel taxonomy), Lesson 56 (banking)
> **You will learn:** what the F8SC mapper adds to F8; why the 6507 sees the RAM at `$1000–$107F` (write) and `$1080–$10FF` (read); why the first 256 bytes of each 4K bank are not code; what the duplicated 128-byte signature is for; why the console does not zero this RAM; and why the RAM survives a bank switch when the ROM does not
> **You will build:** "the 128-byte notebook" — an 8,192-byte F8SC ROM that writes a 32-character message into the Superchip RAM one byte every eight frames, reads each byte back through the read window, shows the newest six characters in a two-line playfield window, fills a 16-cell gauge as the 128 bytes are written, and sweeps a gold player marker across the page; plus three exercise solutions: a full 128-byte fill with all 16 cells lit, a 16-row × 8-byte graphics strip drawn from the RAM, and a value written in bank 1 and read back in bank 0

## Introduction

Lesson 56 gave the cartridge more ROM: the F8 mapper hides two 4K banks behind the 6507's single `$F000–$FFFF` window. More ROM is not always the missing piece. A game also needs scratch space for a level buffer, a scrolling message, a high-score table, or a frame of animation — and the console itself offers only 128 bytes of RIOT RAM, shared with the stack. The Superchip answers that need: the **F8SC** mapper keeps F8's two 4K banks and adds **128 bytes of RAM inside the cartridge**.

The RAM is not mapped beside the ROM. It sits at the *bottom* of the same 4K cartridge window: writes go through `$1000–$107F`, reads come back through `$1080–$10FF`. On the 6507, `$F000` and `$1000` are the same bus access — the CPU has only thirteen address lines — so the first 256 bytes of each 4K bank are the RAM window, not ROM. That is why the code in this lesson starts at `$F100`, and why each bank's first 128 bytes are duplicated at +128: the duplicate is the signature Stella uses to recognize an F8SC image. Javatari's 8K F8 entry is "8K Atari (+RAM)" and enables the same RAM on the first low-128 write, so the player runs the image too; the duplicate is harmless there.

The companion program `57-superchip.asm` is **the 128-byte notebook**. It keeps a 32-character message in the Superchip RAM: every eight frames it writes one ASCII byte through `$1000 + RamPtr`, reads it back through `$1080 + RamPtr`, and shifts the newest six characters into a playfield window. A 16-cell gauge in the status band lights one cell for each group of eight bytes written, and a gold player marker sweeps the page. The three exercise solutions take the idea apart in three directions: fill all 128 bytes and light every cell, draw a 16-row × 8-byte graphics strip from the RAM, and write a value in bank 1, switch to bank 0, and read it back to prove the RAM is cartridge memory rather than bank memory.

::: details TypeScript Equivalent

A Superchip is a 128-byte buffer with two decoded address ranges. In TypeScript the shape is small:

```typescript
class SuperchipRam {
  private readonly bytes = new Uint8Array(128);

  write(address: number, value: number): void {
    if (address >= 0x1000 && address <= 0x107f) {
      this.bytes[address - 0x1000] = value;   // the write window
    }
  }

  read(address: number): number {
    if (address >= 0x1080 && address <= 0x10ff) {
      return this.bytes[address - 0x1080];    // the read window
    }
    throw new Error("not a Superchip read");
  }
}
```

The analogy breaks in the places that make the hardware interesting. `write` and `read` are not function calls: they are bus cycles decoded by the cartridge while the CPU is executing `STA $1000,X` or `LDA $1080,X`. The class uses full 16-bit addresses, but the 6507 only has thirteen address lines; `$F000` and `$1000` are the same external access, which is exactly why the RAM shares the bottom of the ROM window. The `Uint8Array` is zeroed by JavaScript; a real SRAM powers up in an unknown state, so the program must initialize it. The bank latch is separate from this buffer: a bank switch changes which 4K ROM the CPU sees, not which 128 bytes the RAM holds. And the signature is not a runtime read at all — it is a pattern in the *file* that the emulator checks before the first instruction.

:::

## Theory

### Section 1: The 4K Window, Again

The 6507 is a 6502 with fewer pins. It exposes `A0–A12`, so its address space is 8,192 bytes, from `$0000` to `$1FFF`. The console decodes that space into three regions:

| Region | Addresses (CPU) | What lives there |
|---|---|---|
| TIA | `$0000–$003F` (mirrored) | video, sound, input registers |
| RIOT | `$0080–$00FF` RAM, `$0280–$0297` I/O | 128 bytes of RAM, timer, ports |
| Cartridge | `$1000–$1FFF` | the 4K ROM window |

The assembler writes cartridge code at `$F000–$FFFF`, but the CPU never puts those high bits on the bus; it drives the low thirteen, so `$F000` and `$1000` are the same cartridge access. The 4K window is the whole cartridge, and its bytes are addressed by `A0–A11` inside the window.

F8 splits the window into two 4K banks. The mapper watches the low address bits for a read that matches `$1FF8` or `$1FF9`; the read selects bank 0 or bank 1, and the *next* fetch comes from the selected bank. Lesson 56 built that machine in full.

F8SC keeps every part of F8 and adds 128 bytes of RAM. The RAM is decoded at the bottom of the same 4K window:

| Access | Address range | Behaviour |
|---|---|---|
| write | `$1000–$107F` | stores one of 128 bytes |
| read | `$1080–$10FF` | returns one of the same 128 bytes |

The two ranges are 128 bytes apart, not two separate memories. `STA $1000,X` stores byte X; `LDA $1080,X` returns byte X. There is no auto-increment and no address register: X is the index, 0–127.

::: tip Why two windows?
The cartridge has one 128-byte RAM and one 4K address window. It cannot place the RAM at an address the ROM does not already occupy, so it overlays the RAM on the first 256 bytes of the window and decodes writes and reads differently. The write window is where stores land; the read window is where loads read. That is why a program writes to `$1000+X` and reads from `$1080+X`, and why the first 256 bytes of the ROM image can never be normal code.
:::

### Section 2: The First 256 Bytes Are Not Code

The practical consequence is blunt: **code starts at `$F100`.** The bytes at `$F000–$F0FF` are the RAM window when the program runs. If the reset vector pointed at `$F000`, a fetch there would land in the write window, not in ROM or in readable RAM; the first instruction must be at `$F100`. The vectors at `$FFFA–$FFFF` sit at the top of the 4K window, far outside the RAM, so they are safe.

The source lays out each bank like this:

```asm
    * = $F000
    !pseudopc $F000 {
    !fill 128, $EA          ; $F000-$F07F: the write-window half of the signature
    !fill 128, $EA          ; $F080-$F0FF: the read-window half of the signature
    * = $F100               ; the first byte of code
Entry:
    LDA $1FF9               ; select bank 1
    JMP $F106               ; continue at Init, after the six-byte stub
```

The six-byte stub is the same in both banks. At power-on F8SC selects bank 1 (like F8), so bank 1's `$F100` runs first. If the console's RESET switch is pressed while bank 0 is selected, bank 0's `$FFFC` points to its own `$F100`, the `LDA $1FF9` selects bank 1, and the `JMP` at `$F103` is fetched from bank 1. The target is `$F106`, the first byte after the stub; a jump back to `$F100` would re-enter the stub and loop forever.

::: warning A fixed stub cannot live at $F060 any more
Lesson 56 put its switch-and-jump stubs at `$F060` and `$F070` because those addresses were ordinary ROM. In F8SC they are inside the RAM window. The stubs move to `$F100` and above, and the entry stub's target must be the first byte *after* the stub, not the stub's own address.
:::

### Section 3: The Duplicated Signature

An 8,192-byte image with a Superchip is indistinguishable from a plain F8 image by size alone. Stella uses a content heuristic to tell them apart: in a real F8SC image, the first 128 bytes of each 4K bank are duplicated at +128. The file's `$F000–$F07F` equals `$F080–$F0FF`. Stella checks that pattern and selects the F8SC (8K + RAM) mapper; without it, the same image is detected as plain F8, the write window is not emulated as RAM, and the read window returns ROM bytes. (Javatari takes a different route: every 8K image is its "8K Atari (+RAM)" F8 format, and the first low-128 write enables the RAM, so it does not need the signature — but the duplicate does no harm.)

The signature is a *file* convention, not something the running program reads. In this lesson both halves are `$EA` (the NOP opcode), so the duplicate is a visible 256-byte run of `$EA` at the start of each 4K bank. The ROM's actual code is at `$F100` and beyond.

| Check | Bank 0 | Bank 1 |
|---|---|---|
| file bytes `$0000–$007F` vs `$0080–$00FF` | `$EA` ×128 vs `$EA` ×128 | — |
| file bytes `$1000–$107F` vs `$1080–$10FF` | — | `$EA` ×128 vs `$EA` ×128 |
| Stella's mapper report | `F8SC* (8K)` | `F8SC* (8K)` |

A quick experiment makes the point: replace one bank's second 128 bytes with a different value and Stella reports `F8* (8K)` instead of `F8SC* (8K)`. The RAM writes then have no cartridge RAM behind them; the lesson's read-back would return the ROM byte, not the written one. The duplicate is not decoration — it is the mapper's identity card.

### Section 4: The RAM Is Not Zeroed

The 2600 has no BIOS and no startup code. The RIOT's 128 bytes are not initialized by the console either, which is why every lesson starts with `+clean_start`. The Superchip's 128 bytes are the same story: a real SRAM powers up with unknown contents. The program must initialize them explicitly.

This lesson's init loop writes 128 zeros through the write window before the first frame:

```asm
    LDX #0
    LDA #$00
InitRam:
    STA $1000,X             ; write byte X through the write window
    INX
    CPX #128
    BNE InitRam
```

Two consequences follow. First, the gauge starts empty and the notebook starts blank on every reset. Second, the zeros are a *choice*: the program could seed the RAM with a pattern, a level, or a saved high score. The hardware only guarantees that the bytes are there; it does not guarantee what they contain.

::: tip The RAM is not the RIOT RAM
The RIOT's 128 bytes live at `$80–$FF` and share the stack page. The Superchip's 128 bytes live in the cartridge at `$1000–$10FF` and are completely separate. `+clean_start` zeroes `$00–$FF` (TIA and RIOT RAM); it does **not** touch `$1000–$10FF`. The explicit `InitRam` loop is required.
:::

### Section 5: The 128-Byte Notebook

The demo treats the RAM as a notebook with 128 pages. It keeps a 32-character message:

```text
     SUPERCHIP 128 BYTE NOTEBOOK
```

(five leading spaces make the window start blank; the visible text is 27 characters, and the 32-byte table is the ring). A write pointer `WritePtr` walks 0–127; a message pointer `MessagePtr` walks 0–31. Every eight frames the update:

1. reads `Message[MessagePtr]` (an ASCII byte),
2. writes it to `$1000 + WritePtr` (the write window),
3. reads it back from `$1080 + WritePtr` (the read window),
4. converts the ASCII byte to a glyph index (A–Z = 0–25, 0–9 = 26–35, space = 36),
5. shifts the glyph into the six-glyph window,
6. lights the gauge cell `WritePtr >> 3`,
7. advances the pointers (0–127 and 0–31),
8. rebuilds the two-line, fourteen-row playfield bitmap from the window.

The window shows the newest six characters as two lines of three. A new character enters at the lower right and the older characters move left and up. The gauge's 16 cells are the 16 groups of eight bytes: cell 0 = `$1000–$1007`, cell 15 = `$1078–$107F`. A cell is lit when any byte in its group has been written; because the demo writes sequentially, the gauge fills as a growing bar.

| Quantity | Value |
|---|---|
| RAM bytes | 128 |
| message bytes | 32 |
| bytes written per update | 1 |
| update period | 8 frames |
| time to fill all 128 bytes | 128 × 8 = 1,024 frames ≈ 17 s |
| message cycle | 32 writes = 256 frames ≈ 4.3 s |
| gauge cells | 16 (8 bytes each) |
| window | 6 glyphs, two lines of three |

### Section 6: The Frame and the Kernel

The frame is the Part 7 skeleton: 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines. The visible picture splits into 8 status lines and 184 play lines:

- **Status rows 0–6:** `PF0` draws the "SC" label in chunks 0–3; `PF1` draws gauge cells 0–7 in chunks 4–11; `PF2` draws cells 8–15 in chunks 12–19. Row 7 is a solid separator. The playfield is reflected, so the label and gauge appear on both halves.
- **Play rows 0–13:** the six-character window as two lines of three characters. `PF0` carries the first character of each line (chunks 0–3); `PF1` carries the second and third (chunks 4–7 and 8–11).
- **Play rows 14–183:** background, with the 8-line gold marker at play rows 88–95 (visible lines 96–103).

The 1-line kernel's worst row is a text row: `LDA`/`STA` twice (14) + `LDA #0`/`STA PF2` (5) + `STA GRP0` (3) + `WSYNC` (3) + `INY`/`CPY`/`BNE` (7; the loops are page-local, so the taken `BNE` is 3) = 32 cycles, leaving 44 of the 76. The status row is 29 cycles and a play row is 17. PF0 is stored by cycle 14 on every row, before the beam reaches chunk 0 at cycle ~23.

The marker is positioned once per frame with the Lesson 26 divide-by-15 dance and a single `HMOVE` in VBLANK:

```asm
    LDA FrameCount
    AND #$3F
    CLC
    ADC #(MARKER_X_BASE + POS_BIAS)
    JSR SetCoarseP0         ; sets HMP0 and strobes RESP0
    STA WSYNC
    STA HMOVE               ; the frame's only HMOVE
```

`MARKER_X_BASE` is 24 and the call adds `POS_BIAS` (3), so the marker's requested left edge sweeps TIA X 24–87 and wraps every 64 frames. The bias compensates `RESP0`'s three-clock output delay.

## The Code

### Building This Lesson

```bash
# every lesson ROM, including this one:
npm run roms

# or just this one:
acme -f plain -o build/lesson57.bin \
  lessons/part8-advanced/57-superchip/57-superchip.asm
stella build/lesson57.bin
```

The source assembles to exactly **8,192 bytes**. The flat image is bank 0 (real `$E000–$EFFF`) followed by bank 1 (real `$F000–$FFFF`). Stella's log reports the mapper it selected:

```text
Bankswitching type 'F8SC (8K Atari + RAM)' detected
  Bankswitch Type: F8SC* (8K)
```

The `.bin` has no mapper header, so the emulator's log is the evidence for the scheme; the source does not carry a mapper declaration of its own.

The exercise solutions sit beside the lesson source:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part8-advanced/57-superchip/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part8-advanced/57-superchip/exercise-02-solution.asm
acme -f plain -o build/exercise-03.bin \
  lessons/part8-advanced/57-superchip/exercise-03-solution.asm
```

### Full Source

The complete annotated source is reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 57: Superchip — Extra RAM — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the 128-byte notebook": an 8,192-byte F8SC cartridge.  The F8 mapper's
;   two 4K banks are still there, but the cartridge also carries 128 bytes of
;   RAM.  The program keeps a 32-character message in that RAM, writes one
;   character every eight frames through the write window at $1000+RamPtr,
;   reads it back through the read window at $1080+RamPtr, and shows the last
;   six characters in a playfield window.  A 16-cell gauge in the status band
;   fills as the 128 bytes are written, and a gold player marker sweeps the
;   play area.
;
; The F8SC layout (the flat file is bank 0 then bank 1):
;   file offset $0000-$0FFF   bank 0, real $E000, assembled with !pseudopc $F000
;   file offset $1000-$1FFF   bank 1, real $F000
;
; THE FIRST 256 BYTES OF EACH BANK ARE NOT CODE.
;   The Superchip's 128 bytes of RAM appear in the cartridge window at
;   $F000-$F0FF: writes go through $F000-$F07F (the CPU writes $1000-$107F)
;   and reads come back through $F080-$F0FF (the CPU reads $1080-$10FF).  A
;   fetch from $F000-$F0FF would read the RAM window or miss the ROM entirely,
;   so code starts at $F100.
;
;   The first 128 bytes of each bank are also duplicated at +128:
;       $F000-$F07F  ==  $F080-$F0FF
;   Stella uses that duplicate as the F8SC auto-detect signature.  Without it
;   an 8K image with RAM is detected as plain F8, the writes are ignored, and
;   the read-back returns ROM bytes.  Javatari's 8K F8 entry is "8K Atari
;   (+RAM)" and enables the RAM on the first low-128 write, so it runs the
;   image too; the duplicate is harmless there.
;
; Starting bank:
;   F8SC extends F8, and F8 starts in BANK 1.  At power-on the CPU reads the
;   reset vector from bank 1's $FFFC, so bank 1's $F100 is the first
;   instruction.  Both banks' vectors at $FFFA-$FFFF point to $F100.
;
; The entry stubs (six bytes, identical in both banks):
;   $F100  LDA $1FF9   select bank 1 (the hotspot read)
;   $F103  JMP $F106   continue at the init, immediately after the stub
; The JMP is fetched after the select, so its bytes must be the same in both
; banks.  A jump back to $F100 would re-enter the stub and loop; $F106 is the
; first byte after the six-byte stub.  The console's RESET while bank 0 is
; selected reaches bank 1 through exactly this stub.
;
; The virtual layout of bank 1 ($F000-$FFFF):
;   $F000-$F0FF   the RAM window and the duplicated signature (not code)
;   $F100         the six-byte entry stub
;   $F106         Init: +clean_start, zero the Superchip RAM, the frame loop
;   $F400         ScRow        7 bytes: the "SC" label rows
;   $F407         CellBitHi    8 bytes: gauge cell 0-7 masks
;   $F40F         CellBitLo    8 bytes: gauge cell 8-15 masks
;   $F417         Rev4         16 bytes: the PF0 nibble bit-reversal table
;   $F427         MarkerStrip  184 bytes: one GRP0 byte per play line
;   $F4DF         FontRow0-6   259 bytes: 37 glyphs, 4 chunks x 7 rows
;   $F5E2         Message      32 bytes: the ASCII message
;   $FFFA         the vectors: Reset, Reset, Reset
;
; The Superchip RAM ($1000-$107F write, $1080-$10FF read):
;   The 6507's 13-bit bus already makes $F000 and $1000 the same cartridge
;   access (A12 high, A0-A11 = $000); the mapper watches the low 12 bits.
;   A write to $1000+X stores byte X; a read from $1080+X returns byte X.  The
;   two windows are why the RAM costs no code space in the middle of the
;   program: it lives at the bottom of the same 4K window that holds the ROM.
;
;   The console does not initialize this RAM.  The init loop writes 128 zeros
;   before the first frame, so the gauge starts empty and the notebook starts
;   blank.  The RAM is separate from the RIOT's 128 bytes at $80-$FF and it
;   survives a bank switch, because it is in the cartridge, not in a bank.
;
; The message and the display:
;   Message is 32 ASCII bytes: five leading spaces and "SUPERCHIP 128 BYTE
;   NOTEBOOK".  Every eight frames the update:
;     1. reads Message[MsgPtr] (ASCII),
;     2. writes it to $1000+RamPtr (the write window),
;     3. reads it back from $1080+RamPtr (the read window),
;     4. converts the byte to a glyph and shifts it into the 6-glyph window,
;     5. lights the gauge cell RamPtr >> 3,
;     6. advances RamPtr 0..127 and MsgPtr 0..31,
;     7. rebuilds the two-line, fourteen-row playfield bitmap from the window.
;   The window shows the newest six characters: three on the upper line and
;   three on the lower line.  Each new glyph enters at the lower right and the
;   old ones move left and up.  The gauge's 16 cells are the 16 groups of
;   eight bytes: cell 0 = $1000-$1007, cell 15 = $1078-$107F.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;
; The picture: 8 status lines + 184 play lines = 192.
;   Status rows 0-6 draw the SC label in PF0 (chunks 0-3) and the gauge in
;   PF1/PF2 (chunks 4-19); row 7 is a solid separator.  The play rows 0-13
;   show the 6-character window as two lines of three characters (line A in
;   PF0/PF1 chunks 0-11, line B directly below); rows 14-183 are background
;   with the 8-line marker strip at rows 88-95 (visible lines 96-103).
;
; Cycle ledger (a line is 76 CPU cycles; the loops are page-local, so the
; taken BNEs are 3 cycles):
;   status row:  LDA 4 + STA 3 + LDA 3 + STA 3 + LDA 3 + STA 3 + WSYNC 3
;               + INY 2 + CPY 2 + BNE 3 = 29 cycles; PF0 is stored by cycle
;               14 on every row, before the beam reaches chunk 0 at ~cycle 23.
;   text row:    the two PF loads/stores (14) + LDA #0/STA PF2 (5)
;               + STA GRP0 (3) + WSYNC 3 + INY 2 + CPY 2 + BNE 3 = 32 cycles;
;               PF0 by cycle 14 on every row.
;   play row:    LDA 4 + STA 3 + WSYNC 3 + INY 2 + CPY 2 + BNE 3 = 17 cycles.
;   The worst row is the text row at 32; the 76-cycle line leaves 44 cycles.
;
; The single HMOVE:
;   The marker's requested X is 24 + (FrameCount & 63), plus the 3-clock
;   output-delay bias (POS_BIAS).  SetCoarseP0 runs the Lesson 26
;   divide-by-15 dance (RESP0 + HMP0) in VBLANK; one STA HMOVE applies the
;   fine offset.  There is no second HMOVE, and no motion register is rewritten
;   within 24 cycles of the strobe.
;
; Checkpoints (the state log's A/X/Y/SP fields and the bank field):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   OverscanStart (229/6);
;   Frame (A = the new frame count, 1, 2, 3, ...);
;   RamWrite (A = the byte written, X = RamPtr; address = $1000 + X);
;   RamRead (A = the byte read back from $1080 + X);
;   RamPtr (A = the new write pointer, 0..127);
;   MsgPtr (A = the new message pointer, 0..31);
;   Writes (A = the write count), Reads (A = the read count).
;
; RAM map (RIOT, $80-$FF; +clean_start zeroes every byte):
;   $80   WritePtr    the Superchip write pointer 0..127 (checkpoint RamPtr)
;   $81   MessagePtr  the message index 0..31 (checkpoint MsgPtr)
;   $82   FrameCount  frames since reset, wraps at 256 (checkpoint Frame)
;   $83   WriteCount  Superchip writes (checkpoint Writes)
;   $84   ReadCount   Superchip reads (checkpoint Reads)
;   $85   GaugeLo     gauge cells 8-15, cell 8 in bit 0
;   $86   GaugeHi     gauge cells 0-7, cell 0 in bit 7
;   $87-$8C  Window    six glyph indices, oldest first
;   $8D-$9A  MsgPF0    fourteen PF0 bytes: line A rows 0-6, line B rows 0-6
;   $9B-$A8  MsgPF1    fourteen PF1 bytes: line A rows 0-6, line B rows 0-6
;   $A9   Tmp0       bitmap packing scratch
;   $AA   Scratch    a glyph row byte / the new glyph
;   $AB/$AC FontPtr  the current font row's base (zero page for (ptr),Y)
;   $AD-$D7 free
;   $F8-$FF stack
;
; Build: acme -f plain -o build/lesson57.bin \
;        lessons/part8-advanced/57-superchip/57-superchip.asm
; Run:   stella build/lesson57.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

SCREEN_LINES   = 192     ; every frame draws 192 visible lines
STATUS_LINES   = 8       ; the SC label and gauge band
TEXT_ROWS      = 7       ; seven rows per three-character line
TEXT_LINES     = 14      ; two lines of three characters
PLAY_LINES     = 184     ; 192 - 8 status lines
MARKER_TOP     = 88      ; the marker's first play row (visible line 96)
MARKER_X_BASE  = 24      ; the sweep's base X; the call adds POS_BIAS

C_BG           = $00     ; black notebook page
C_STATUS       = $C8     ; green SC label and gauge
C_TEXT         = $0E     ; white message
C_MARK         = $1A     ; gold marker

GAUGE_CELLS    = 16      ; 16 groups of eight bytes = 128
RAM_BYTES      = 128     ; the Superchip's full RAM

; The frame arithmetic is a build-time assertion, not a comment.
!if STATUS_LINES + PLAY_LINES != SCREEN_LINES {
    !error "the status band plus the play area must total 192 lines"
}
!if MARKER_TOP + 8 > PLAY_LINES {
    !error "the marker strip must fit inside the play area"
}
!if GAUGE_CELLS * 8 != RAM_BYTES {
    !error "the 16 gauge cells must cover the 128 RAM bytes"
}

; =============================================================================
; RAM ALLOCATION ($80-$AC; +clean_start zeroes every byte)
; =============================================================================
; The checkpoint labels RamPtr, Writes and Reads cannot share a name with a
; variable, so the variables carry role names and the checkpoints keep the
; names the lesson documents.
WritePtr    = $80    ; the Superchip write pointer, 0..127
MessagePtr  = $81    ; the message index, 0..31
FrameCount  = $82    ; frames since reset, wraps at 256
WriteCount  = $83    ; the number of Superchip writes
ReadCount   = $84    ; the number of Superchip reads
GaugeLo     = $85    ; gauge cells 8-15, cell 8 in bit 0
GaugeHi     = $86    ; gauge cells 0-7, cell 0 in bit 7
Window      = $87    ; six glyph indices, oldest at Window+0

; The display bitmap: two lines of three characters.  A line uses PF0 for its
; first character (chunks 0-3) and PF1 for its second and third (chunks 4-7
; and 8-11).  Rows 0-6 are line A (the older three characters); rows 7-13 are
; line B (the newer three).
MsgPF0      = $8D    ; fourteen PF0 bytes: line A rows 0-6, line B rows 0-6
MsgPF1      = $9B    ; fourteen PF1 bytes: line A rows 0-6, line B rows 0-6

Tmp0        = $A9    ; bitmap packing scratch
Scratch     = $AA    ; a glyph row byte, then the new glyph
FontPtr     = $AB    ; the current font row's base (zero page, two bytes)

; $AD-$D7 are free.  The stack lives at $F8-$FF; the call depth is one level
; (SetCoarseP0, Update, BuildBitmap, AsciiToGlyph).

; =============================================================================
; BANK 0 — real $E000, virtual $F000.  THE RESET-ONLY BANK.
; =============================================================================
; The flat ROM starts here.  Bank 0 is not used by the demo; it exists so that
; a console reset while bank 0 is selected still finds a valid vector and a
; stub that selects bank 1.  Its first 256 bytes are the F8SC signature.
    * = $E000
    !pseudopc $F000 {

; -----------------------------------------------------------------------------
; The signature — 128 bytes duplicated at +128
; -----------------------------------------------------------------------------
; $F000-$F07F is the write window and $F080-$F0FF is the read window when the
; CPU runs; the file bytes here are what the emulator's auto-detect reads.
; The two halves must be identical, or Stella selects plain F8.
    !fill 128, $EA
    !fill 128, $EA

; -----------------------------------------------------------------------------
; Bank 0's entry — the same six bytes as bank 1's entry
; -----------------------------------------------------------------------------
    * = $F100
Bank0Entry:
    LDA $1FF9               ; select bank 1 (the hotspot read)
    JMP $F106               ; the JMP is fetched from bank 1 at $F103
                            ; $F106 is bank 1's init, right after the stub

; Bank 0 has no code after the stub.  The fill is $EA (NOP) so an accidental
; fetch is harmless; the vectors below are the only bytes that matter.
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Bank0Entry, Bank0Entry, Bank0Entry
}

; =============================================================================
; BANK 1 — real $F000, virtual $F000.  THE NOTEBOOK.
; =============================================================================
; This is the start bank: F8SC extends F8, and F8 selects bank 1 at power-on.
; Its reset vector at $FFFC is the one the CPU uses, so bank 1's entry at
; $F100 is the first instruction that runs.
    * = $F000
    !pseudopc $F000 {

; -----------------------------------------------------------------------------
; The signature — the same duplicated 128 bytes as bank 0
; -----------------------------------------------------------------------------
    !fill 128, $EA
    !fill 128, $EA

; -----------------------------------------------------------------------------
; Entry — the six-byte stub at $F100
; -----------------------------------------------------------------------------
; The bank-0 reset and the bank-1 reset both arrive here.  LDA $1FF9 selects
; bank 1; the JMP opcode at $F103 is then fetched from bank 1.  The target
; $F106 is the first byte after the six-byte stub: a JMP to $F100 would
; re-enter the stub and loop forever.
    * = $F100
Entry:
    LDA $1FF9               ; select bank 1
    JMP $F106               ; continue at Init, after the six-byte stub

; -----------------------------------------------------------------------------
; Init — the power-on setup ($F106)
; -----------------------------------------------------------------------------
Init:
    +clean_start            ; zero TIA and RIOT RAM, set the stack to $FF
    LDA #$00
    STA SWACNT              ; port A is an input port (the joystick)

; --- the Superchip RAM is NOT zeroed by the console --------------------------
; A real 128-byte SRAM powers up in an unknown state.  Write all 128 bytes
; explicitly, through the write window.  This is also the first proof that the
; window is live: the read window below would return the written zeros.
    LDX #0
    LDA #$00
InitRam:
    STA $1000,X             ; write byte X through the write window
    INX
    CPX #RAM_BYTES
    BNE InitRam

; --- the named variables (clean_start already zeroed them) -------------------
    LDA #$00
    STA WritePtr
    STA MessagePtr
    STA FrameCount
    STA WriteCount
    STA ReadCount
    STA GaugeLo
    STA GaugeHi

; --- the window starts with six spaces, not six glyph 0s --------------------
; The bitmap is blank until the first update, but the window bytes must also
; be spaces: a zero byte is glyph 0 ('A'), and the first shift would otherwise
; drag five 'A's into the picture.
    LDX #0
    LDA #36                 ; glyph 36 is the space
InitWindow:
    STA Window,X
    INX
    CPX #6
    BNE InitWindow

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; black page
    LDA #C_STATUS
    STA COLUPF              ; green until the message band
    LDA #C_MARK
    STA COLUP0              ; the marker
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the pattern doubles
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

; --- the status band's colours ----------------------------------------------
; The status band is green; the message band switches to white below.
    LDA #C_STATUS
    STA COLUPF
    LDA #C_MARK
    STA COLUP0

; --- the frame counter and the eight-frame update clock ----------------------
    INC FrameCount
    LDA FrameCount
Frame:                      ; checkpoint: A = the new frame count
    AND #$07
    BNE NoUpdate
    JSR Update
NoUpdate:

; --- the marker's X: 24 + (FrameCount & 63), one divide-by-15 dance ----------
    LDA FrameCount
    AND #$3F
    CLC
    ADC #(MARKER_X_BASE + POS_BIAS)
    JSR SetCoarseP0         ; sets HMP0 and strobes RESP0
    STA WSYNC
    STA HMOVE               ; the frame's only HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; THE VISIBLE KERNEL — 192 lines
; =============================================================================

; --- 8 status lines: the SC label and the 16-cell gauge ----------------------
; PF0 draws "SC" in chunks 0-3 (two 2-chunk letters).  PF1 draws gauge cells
; 0-7 and PF2 draws cells 8-15.  Reflection mirrors the whole status band, so
; the reader sees the label at both edges and the gauge on both sides.
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDY #0
StatusRow:
    LDA ScRow,Y
    STA PF0                 ; the SC label
    LDA GaugeHi
    STA PF1                 ; cells 0-7
    LDA GaugeLo
    STA PF2                 ; cells 8-15
    STA WSYNC
    INY
    CPY #7
    BNE StatusRow

; Row 7 is a solid separator in all 20 chunks.
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    STA WSYNC

; --- 14 play lines: two lines of three characters ----------------------------
; The bitmap is rebuilt every eight frames, so these fourteen lines are a
; simple table read.  Line A is the older three characters (top), line B the
; newer three (bottom).  COLUPF changes to white after the separator's line
; has been drawn; the first text row's PF0 store follows at cycle 14.
    LDA #C_TEXT
    STA COLUPF
    LDY #0
TextRow:
    LDA MsgPF0,Y
    STA PF0
    LDA MsgPF1,Y
    STA PF1
    LDA #$00
    STA PF2
    STA GRP0
    STA WSYNC
    INY
    CPY #TEXT_LINES
    BNE TextRow

; --- the rest of the play area: background and the marker --------------------
; The playfield is already zero; the TIA holds it for the remaining 170
; lines.  GRP0 comes from the 184-byte strip, one byte per line.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
PlayRow:
    LDA MarkerStrip,Y
    STA GRP0
    STA WSYNC
    INY
    CPY #PLAY_LINES
    BNE PlayRow

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
; Update — one Superchip write and read, every eight frames
; =============================================================================
; The message index selects an ASCII byte; the write pointer selects one of
; the 128 RAM bytes.  The write goes through $1000+X, the read comes back
; through $1080+X.  The same read byte then drives the display: the new glyph
; shifts into the six-character window and the gauge lights the byte's group.
Update:
; --- the message byte and the write ------------------------------------------
    LDX MessagePtr
    LDA Message,X           ; the next ASCII character
    LDX WritePtr            ; X = 0..127
    STA $1000,X             ; the write window
RamWrite:                   ; checkpoint: A = the byte written, X = RamPtr
; --- the read-back ------------------------------------------------------------
    LDA $1080,X             ; the read window
RamRead:                    ; checkpoint: A = the byte read back

; --- the byte becomes a glyph -------------------------------------------------
    JSR AsciiToGlyph
    STA Scratch             ; the new glyph index (0..36)

; --- shift the six-glyph window left and append the new glyph ----------------
    LDX #0
ShiftWindow:
    LDA Window+1,X
    STA Window,X
    INX
    CPX #5
    BNE ShiftWindow
    LDA Scratch
    STA Window+5

; --- light the gauge cell of the byte just written ---------------------------
; Cell c is bytes 8c..8c+7.  Cells 0-7 live in GaugeHi (cell 0 in bit 7),
; cells 8-15 in GaugeLo (cell 8 in bit 0).  A cell stays lit once any of its
; eight bytes has been written, so the mask is ORed, never cleared.
    LDA WritePtr
    LSR
    LSR
    LSR                     ; cell = WritePtr >> 3, 0..15
    TAX
    CPX #8
    BCS HighCell
    LDA CellBitHi,X          ; $80 >> cell
    ORA GaugeHi
    STA GaugeHi
    JMP GaugeDone
HighCell:
    LDA CellBitLo-8,X        ; x = 8..15, table index 0..7
    ORA GaugeLo
    STA GaugeLo
GaugeDone:

; --- advance the write pointer, 0..127 ---------------------------------------
    INC WritePtr
    LDA WritePtr
    CMP #RAM_BYTES
    BCC WritePtrDone
    LDA #$00
    STA WritePtr
WritePtrDone:
    LDA WritePtr
RamPtr:                     ; checkpoint: A = the new write pointer

; --- advance the message pointer, 0..31 --------------------------------------
    INC MessagePtr
    LDA MessagePtr
    AND #$1F
    STA MessagePtr
MsgPtr:                     ; checkpoint: A = the new message pointer

; --- count the operations -----------------------------------------------------
    INC WriteCount
    LDA WriteCount
Writes:                     ; checkpoint: A = the write count
    INC ReadCount
    LDA ReadCount
Reads:                      ; checkpoint: A = the read count

; --- rebuild the two-line, fourteen-row PF0/PF1 bitmap ------------------------
    JMP BuildBitmap         ; tail call: BuildBitmap returns to the caller

; =============================================================================
; AsciiToGlyph — map ' ', '0'-'9', and 'A'-'Z' to the font's 37 glyphs
; =============================================================================
; The font order is A-Z (0-25), 0-9 (26-35), space (36).  The message only
; contains those characters, so no other case is needed.
AsciiToGlyph:
    CMP #$20                ; space
    BEQ GlyphSpace
    CMP #$30                ; below '0' is not used
    BCC GlyphLetter
    CMP #$3A                ; above '9' falls through to the letter path
    BCS GlyphLetter
    SEC
    SBC #$16                ; '0' ($30) - 26 = $16: A = digit + 26
    RTS
GlyphLetter:
    SEC
    SBC #$41                ; 'A' ($41): A = 0..25
    RTS
GlyphSpace:
    LDA #36
    RTS

; =============================================================================
; BuildBitmap — turn six glyphs into two lines of PF0/PF1 pairs
; =============================================================================
; Each glyph is four chunks wide.  Line A (the older three characters) is
; written to bitmap rows 0-6; line B (the newer three) to rows 7-13.  In a
; row, character 0 is PF0 bits 7-4 (chunks 0-3), character 1 is PF1 bits 7-4
; (chunks 4-7), and character 2 is PF1 bits 3-0 (chunks 8-11).  PF2 stays
; zero.  The reflection draws the mirrored copy on the right half.
;
; The six glyphs are read from FontRow0..FontRow6 through FontPtr; each row
; is 37 bytes, one per glyph, so the pointer advances by 37 after each row.
BuildBitmap:
    LDA #<FontRow0
    STA FontPtr
    LDA #>FontRow0
    STA FontPtr+1
    LDX #0                  ; X = the glyph row, 0..6
BuildRow:
; --- line A: characters 0, 1, 2 ----------------------------------------------
; The font nibble has bit 3 = the leftmost chunk.  PF0's high nibble runs
; bit 4 (left) to bit 7 (right), so character 0's nibble is reversed before
; it moves up; PF1's high nibble runs bit 7 (left) to bit 4 (right) and its
; low nibble runs bit 3 (left) to bit 0 (right), so characters 1 and 2 need
; no reversal.
    LDY Window+0
    LDA (FontPtr),Y
    AND #$0F
    TAY
    LDA Rev4,Y              ; reverse the four chunk bits
    ASL
    ASL
    ASL
    ASL                     ; the nibble moves to PF0's high four bits
    STA MsgPF0,X

    LDY Window+1
    LDA (FontPtr),Y
    AND #$0F
    ASL
    ASL
    ASL
    ASL
    STA Tmp0
    LDY Window+2
    LDA (FontPtr),Y
    AND #$0F
    ORA Tmp0
    STA MsgPF1,X

; --- line B: characters 3, 4, 5 ----------------------------------------------
    LDY Window+3
    LDA (FontPtr),Y
    AND #$0F
    TAY
    LDA Rev4,Y
    ASL
    ASL
    ASL
    ASL
    STA MsgPF0+7,X

    LDY Window+4
    LDA (FontPtr),Y
    AND #$0F
    ASL
    ASL
    ASL
    ASL
    STA Tmp0
    LDY Window+5
    LDA (FontPtr),Y
    AND #$0F
    ORA Tmp0
    STA MsgPF1+7,X

; --- next font row ------------------------------------------------------------
    LDA FontPtr
    CLC
    ADC #37                 ; one 37-byte font row
    STA FontPtr
    LDA FontPtr+1
    ADC #$00
    STA FontPtr+1
    INX
    CPX #TEXT_ROWS
    BNE BuildRow
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
; THE DATA — bank 1 starts its tables at $F400
; =============================================================================
    !if * > $F400 {
        !error "bank 1's code must end before $F400"
    }
    !fill $F400 - *, $EA

; --- the "SC" label, one PF0 byte per status row -----------------------------
; Chunks 0-1 are the S, chunks 2-3 the C: bits 4-5 and 6-7 of PF0.
ScRow:
    !byte $F0, $50, $50, $70, $60, $60, $F0

; --- the gauge masks ----------------------------------------------------------
; CellBitHi[c] = $80 >> c for cells 0-7; CellBitLo[c] = $01 << c for 8-15.
CellBitHi:
    !byte $80, $40, $20, $10, $08, $04, $02, $01
CellBitLo:
    !byte $01, $02, $04, $08, $10, $20, $40, $80

; --- the 4-bit reversal used by PF0's high nibble ----------------------------
; A glyph nibble has bit 3 = the left chunk; PF0's high nibble has bit 4 =
; the left chunk.  Reversing maps bit 3 to bit 0, which the shift moves to
; bit 4.  The table is 16 bytes: Rev4[n] is n's four bits reversed.
Rev4:
    !byte $0, $8, $4, $C, $2, $A, $6, $E, $1, $9, $5, $D, $3, $B, $7, $F

; --- the marker strip, one GRP0 byte per play line ---------------------------
MarkerStrip:
    !fill MARKER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill PLAY_LINES - MARKER_TOP - 8, $00

; --- the 4-chunk x 7-row font, row-major -------------------------------------
; 37 glyphs: A-Z, 0-9, space.  Each row byte is a nibble: bit 3 is the left
; chunk, bit 0 the right chunk.  The rows are contiguous 37-byte blocks
; because BuildBitmap advances by 37.
FontRow0:
    !byte $6,$E,$7,$E,$F,$F,$7,$9,$F,$3,$9,$8,$9,$9,$6,$E,$6,$E,$7,$F,$9,$9,$9,$9,$9,$F,$6,$2,$6,$E,$2,$F,$6,$F,$6,$6,$0
FontRow1:
    !byte $9,$9,$8,$9,$8,$8,$8,$9,$6,$1,$A,$8,$F,$D,$9,$9,$9,$9,$8,$6,$9,$9,$9,$9,$9,$1,$9,$6,$9,$1,$6,$8,$8,$1,$9,$9,$0
FontRow2:
    !byte $9,$9,$8,$9,$8,$8,$8,$9,$6,$1,$C,$8,$F,$F,$9,$9,$9,$9,$8,$6,$9,$9,$9,$6,$6,$2,$B,$2,$1,$1,$A,$8,$8,$2,$9,$9,$0
FontRow3:
    !byte $F,$E,$8,$9,$E,$E,$B,$F,$6,$1,$8,$8,$9,$B,$9,$E,$9,$E,$6,$6,$9,$9,$9,$6,$6,$6,$D,$2,$2,$6,$A,$E,$E,$2,$6,$7,$0
FontRow4:
    !byte $9,$9,$8,$9,$8,$8,$9,$9,$6,$1,$C,$8,$9,$9,$9,$8,$B,$C,$1,$6,$9,$9,$F,$6,$6,$8,$9,$2,$4,$1,$F,$1,$9,$4,$9,$1,$0
FontRow5:
    !byte $9,$9,$8,$9,$8,$8,$9,$9,$6,$9,$A,$8,$9,$9,$9,$8,$6,$A,$1,$6,$9,$6,$F,$9,$6,$8,$9,$2,$8,$1,$2,$1,$9,$4,$9,$1,$0
FontRow6:
    !byte $9,$E,$7,$E,$F,$8,$7,$9,$F,$6,$9,$F,$9,$9,$6,$8,$1,$9,$E,$6,$6,$6,$9,$9,$6,$F,$6,$7,$F,$E,$2,$E,$6,$4,$6,$6,$0

; --- the 32-byte message -----------------------------------------------------
; Five leading spaces then "SUPERCHIP 128 BYTE NOTEBOOK" so the six-character
; window starts blank and fills from the right.
Message:
    !byte $20,$20,$20,$20,$20,$53,$55,$50,$45,$52,$43,$48,$49,$50,$20,$31
    !byte $32,$38,$20,$42,$59,$54,$45,$20,$4E,$4F,$54,$45,$42,$4F,$4F,$4B

; -----------------------------------------------------------------------------
; The vectors
; -----------------------------------------------------------------------------
; All three point at the entry stub at $F100.  The 2600 has no interrupts, but
; every bank carries valid vectors because a reset can happen in any bank.
    !if * > $FFFA {
        !error "bank 1's data must end before $FFFA"
    }
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Entry, Entry, Entry
}
```

<!-- END-FULL-SOURCE -->

> The complete, fully-commented source lives in
> `lessons/part8-advanced/57-superchip/57-superchip.asm`.

### Code Walkthrough

#### Step 1 — Two banks, two signatures

The flat file begins with bank 0 at real `$E000`:

```asm
    * = $E000
    !pseudopc $F000 {
    !fill 128, $EA
    !fill 128, $EA
```

`!pseudopc` assembles the bank as if it sat at `$F000`, while the bytes go to `$E000`. The two `!fill` lines are the signature: 128 bytes at `$F000–$F07F` and the same 128 at `$F080–$F0FF`. Bank 1 repeats the pattern at real `$F000`:

```asm
    * = $F000
    !pseudopc $F000 {
    !fill 128, $EA
    !fill 128, $EA
```

The first 256 bytes of each bank are not code. They are the RAM window (when the program runs) and the auto-detect signature (when the emulator loads the file).

#### Step 2 — The six-byte entry stub

Both banks have the same six bytes at `$F100`:

```asm
    * = $F100
Entry:
    LDA $1FF9               ; select bank 1
    JMP $F106               ; continue at Init, after the six-byte stub
```

The `LDA $1FF9` is a hotspot read: it selects bank 1. The `JMP` that follows is fetched from bank 1, so its three bytes must be the same in both banks — they are. The target is `$F106`, the first byte after the stub. A `JMP $F100` would jump back to the stub and loop. The init label is exactly one stub length away.

Bank 0's copy at `$F100` is identical. If the console's RESET is pressed while bank 0 is selected, bank 0's `$FFFC` sends the CPU to `$F100`, the `LDA $1FF9` selects bank 1, and the `JMP` takes the CPU to bank 1's `$F106`. Both banks' vectors point to `$F100`.

#### Step 3 — Init: clean start, then the RAM

`Init` runs `+clean_start` (zero TIA and RIOT RAM, set the stack), makes port A an input, and then handles the RAM the console does not touch:

```asm
Init:
    +clean_start
    LDA #$00
    STA SWACNT

    LDX #0
    LDA #$00
InitRam:
    STA $1000,X             ; the write window
    INX
    CPX #RAM_BYTES
    BNE InitRam
```

The 128 stores are the first proof that the window is live: the read side at `$1080+X` mirrors these zeros. The init then zeroes the named variables (the macro already did) and fills the six window glyphs with spaces. A zero byte in the window would be glyph 0 (`A`), so the window starts at 36 (`space`) rather than 0.

The TIA setup is small: black background, green status band, gold marker, reflected playfield, one player copy, and the PF/GRP registers clear.

#### Step 4 — The frame skeleton

The frame is the Part 7 skeleton, measured in Stella at `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, and `OverscanStart` 229/6:

```asm
StartFrame:
    +vsync
VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
```

VBLANK does the per-frame work: it restores the status colours, increments `FrameCount`, calls `Update` when `FrameCount & 7` is zero, positions the marker, waits for the 37-line timer, and turns the picture on. The overscan blanks the picture, waits 30 lines, and jumps back to `StartFrame`. The frame is 262 lines in steady state.

#### Step 5 — The update: one write, one read

Every eighth frame `Update` moves one byte through the RAM:

```asm
Update:
    LDX MessagePtr
    LDA Message,X           ; the next ASCII character
    LDX WritePtr            ; X = 0..127
    STA $1000,X             ; the write window
RamWrite:                   ; checkpoint: A = the byte written, X = RamPtr
    LDA $1080,X             ; the read window
RamRead:                    ; checkpoint: A = the byte read back
```

The two checkpoints sit immediately after the two events. A Stella breakpoint at `RamWrite` shows the written byte in A and the index in X; the address is `$1000 + X`. The next breakpoint, `RamRead`, shows the same byte in A from `$1080 + X`. For example, at the sixth update X is 5, the byte is `$53` (`S`), and both checkpoints report `A=$53, X=$05`.

After the read, `AsciiToGlyph` maps the byte to a glyph (A–Z = 0–25, 0–9 = 26–35, space = 36), the six-glyph window shifts left and appends the new glyph, and the gauge lights cell `WritePtr >> 3`. `WritePtr` advances 0–127 and wraps; `MessagePtr` advances 0–31 and wraps. `WriteCount` and `ReadCount` increment once each.

#### Step 6 — The gauge masks

Cells 0–7 live in `GaugeHi`, cell 0 in bit 7; cells 8–15 live in `GaugeLo`, cell 8 in bit 0. The update computes the cell from `WritePtr >> 3` and ORs the matching mask:

```asm
    LDA WritePtr
    LSR
    LSR
    LSR                     ; cell = WritePtr >> 3, 0..15
    TAX
    CPX #8
    BCS HighCell
    LDA CellBitHi,X          ; $80 >> cell
    ORA GaugeHi
    STA GaugeHi
    JMP GaugeDone
HighCell:
    LDA CellBitLo-8,X
    ORA GaugeLo
    STA GaugeLo
GaugeDone:
```

The masks are ORed, never cleared: a cell stays lit after its first byte. Because the write pointer walks 0–127 in order, the gauge fills from left to right as a bar.

#### Step 7 — The playfield bitmap

The display is rebuilt only on update frames, not every frame. The font is 37 glyphs (A–Z, 0–9, space), each **four chunks wide and seven rows tall**. A row byte is a nibble: bit 3 is the left chunk, bit 0 the right chunk. `FontRow0` through `FontRow6` are contiguous 37-byte tables, so `BuildBitmap` advances a pointer by 37 after each row.

Each display line is three glyphs:

```asm
    LDY Window+0
    LDA (FontPtr),Y
    AND #$0F
    TAY
    LDA Rev4,Y              ; PF0's high nibble is reversed
    ASL
    ASL
    ASL
    ASL
    STA MsgPF0,X

    LDY Window+1
    LDA (FontPtr),Y
    AND #$0F
    ASL
    ASL
    ASL
    ASL
    STA Tmp0
    LDY Window+2
    LDA (FontPtr),Y
    AND #$0F
    ORA Tmp0
    STA MsgPF1,X
```

The `Rev4` table is necessary because of the playfield's bit order. A glyph nibble has bit 3 as its left chunk; `PF0`'s high nibble has bit 4 as the left chunk. Reversing the four bits maps bit 3 to bit 0, and the four shifts move it to bit 4. `PF1`'s high nibble has bit 7 as the left chunk and its low nibble has bit 3, so characters 1 and 2 need no reversal.

`BuildBitmap` writes fourteen rows: rows 0–6 are line A (the older three characters), rows 7–13 are line B (the newer three). The kernel reads one `PF0` and one `PF1` byte per line.

#### Step 8 — The visible kernel

The kernel is three loops:

```asm
BodyStart:
    LDY #0
StatusRow:
    LDA ScRow,Y
    STA PF0
    LDA GaugeHi
    STA PF1
    LDA GaugeLo
    STA PF2
    STA WSYNC
    INY
    CPY #7
    BNE StatusRow
```

The status loop draws seven rows of `SC` plus the gauge. Row 7 is a solid separator (`PF0=$F0`, `PF1=PF2=$FF`). The text loop then draws fourteen rows from `MsgPF0`/`MsgPF1`, with `PF2` cleared and `GRP0` off. `COLUPF` switches from green to white after the separator's line, so the message is white while the status stays green.

The play loop starts at `Y=14`, reads `MarkerStrip,Y`, writes `GRP0`, and waits for the next line:

```asm
PlayRow:
    LDA MarkerStrip,Y
    STA GRP0
    STA WSYNC
    INY
    CPY #PLAY_LINES
    BNE PlayRow
```

The marker strip is 184 bytes: zeros until play row 88, the eight diamond bytes `$18,$3C,$7E,$FF,$FF,$7E,$3C,$18`, then zeros. `COLUP0` is gold, so the diamond is gold.

#### Step 9 — The vectors

Both banks end with the same three words:

```asm
    * = $FFFA
    !word Entry, Entry, Entry
```

All three vectors point at `$F100`. The 2600 has no interrupts, so only `$FFFC` (RESET) is read, but a valid vector in every bank keeps a reset-from-bank-0 safe: it enters the same six-byte stub, which selects bank 1 and runs the init.

## What You Should See

At power-on the screen is a black page. The top band is the **status**: a green "SC" label at the left edge, a 16-cell green gauge beside it, a green separator line under both, and the same pattern mirrored on the right half. Below the separator are two lines of white text — the six-character message window — at the left edge and its mirror at the right. A gold diamond sits in the middle of the page and sweeps sideways; every eight frames one more byte is written, the message scrolls one character, and the gauge grows by one cell every 64 frames (eight writes).

The two captures below are the same ROM at different times. In the first, four gauge cells are lit and the window shows the newest six characters at the tail of the first message pass; in the second, ten cells are lit and the window shows the early part of the second pass.

![Stella running the Lesson 57 ROM: a black page, a green SC label and a four-cell gauge in the status band, a white two-line message window at the left and its mirror at the right, and a gold diamond marker in the middle; the title bar reads Stella 7.0: "57-superchip"](/images/lesson57/notebook-a.png)

*`notebook-a`: four gauge cells (cells 0–3) and the window state after about 30 writes — the tail of the first message pass (the newest six characters at that moment). The status is green `$C8` (81,179,80), the message white `$0E` (234,234,233), the marker gold `$1A` (205,205,52), the page black `$00` (0,0,0). The gauge measures x=121–216 (four 24-pixel cells) and its mirror x=793–888; the marker measures x=319–366, y=410–433.*

![Stella running the Lesson 57 ROM later in the demo: the gauge has grown to ten cells, the message window shows the early part of the second pass of the message, and the marker has moved left; the title bar reads Stella 7.0: "57-superchip"](/images/lesson57/notebook-b.png)

*`notebook-b`: ten gauge cells (cells 0–9) after about 75 writes, with the window at the early part of the second message pass. The gauge measures x=121–360 and its mirror x=649–888; the marker has moved to x=223–270. Every colour is the same as `notebook-a`; the difference is the write pointer and the message window.*

<RomPlayer rom="/roms/part8-advanced/57-superchip/57-superchip.bin" title="Lesson 57 — Superchip" />

Javatari starts muted; this ROM is silent, so there is nothing to unmute.

Javatari's in-browser mapper table lists F8 as "8K Atari (+RAM)" and implements the same 128-byte window: the first write to the low 128 bytes enables the RAM and the read at +128 returns it. The player therefore runs this 8K image through its F8 (+RAM) path; no separate F8SC entry is needed, and the signature is a Stella detection aid rather than a Javatari requirement. The lesson does not use a mapper outside the F8/F8SC family.

> **Capture method.** Both images are window captures of
> `docs/public/roms/part8-advanced/57-superchip/57-superchip.bin` in Stella 7.0,
> launched with a fresh Stella base directory and a fixed 3× zoom. The window is
> 1010×807 including the title bar. The pointer was parked at `(0, 0)` before
> each capture, so the images contain no cursor. The title bars read
> `Stella 7.0: "57-superchip"`. The first capture was taken about four seconds
> after launch and the second about ten seconds after launch, from the same
> running process; the committed ROM keeps its 8-frame update cadence. No
> modified ROM was used.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
ROM=docs/public/roms/part8-advanced/57-superchip/57-superchip.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F15F' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F16D' $ROM   # VblankStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1A2' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1F5' $ROM   # OverscanStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F182' $ROM   # Frame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F212' $ROM   # RamWrite
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F215' $ROM   # RamRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F252' $ROM   # RamPtr
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F25A' $ROM   # MsgPtr
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F25E' $ROM   # Writes
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F262' $ROM   # Reads
```

| Checkpoint | Address | Measured | Meaning |
|---|---|---|---|
| `StartFrame` | `$F15F` | 259/3 steady; 4/22 on the power-on frame | the first VSYNC instruction |
| `VblankStart` | `$F16D` | 0/5 | the first VBLANK instruction |
| `BodyStart` | `$F1A2` | 37/5 | the first visible-line instruction |
| `OverscanStart` | `$F1F5` | 229/6 | the first overscan instruction |
| `Frame` | `$F182` | A = 1, 2, 3, … | the new frame count |
| `RamWrite` | `$F212` | A = the byte, X = RamPtr; address `$1000+X` | the write window store |
| `RamRead` | `$F215` | A = the same byte from `$1080+X` | the read window load |
| `RamPtr` | `$F252` | A = 1, 2, 3, … | the new write pointer |
| `MsgPtr` | `$F25A` | A = 1, 2, 3, … | the new message pointer |
| `Writes` | `$F25E` | A = 1, 2, 3, … | the write count |
| `Reads` | `$F262` | A = 1, 2, 3, … | the read count |

The state log's frame, scanline, and cycle fields are the evidence:

```text
BP:           1   4 22  -2 | nv-BdIZC 00 06 00 ff | 1/   # StartFrame, power-on frame
BP:           2 259 03 -59 | nv-BdIZC 00 06 b8 ff | 1/   # StartFrame, steady state
BP:           3 259 03 -59 | nv-BdIZC 00 06 b8 ff | 1/
BP:           2   0 05 -53 | nv-BdIZC 00 06 00 ff | 1/   # VblankStart
BP:           3   0 05 -53 | nv-BdIZC 00 06 b8 ff | 1/
BP:           2  37 05 -53 | nv-BdIZC 00 06 00 ff | 1/   # BodyStart
BP:           3  37 05 -53 | nv-BdIZC 00 06 b8 ff | 1/
BP:           2 229 06 -50 | nv-BdIZC 00 06 b8 ff | 1/   # OverscanStart
BP:           3 229 06 -50 | nv-BdIZC 00 06 b8 ff | 1/
BP:           2   0 34  34 | nV-BdIzC 01 06 00 ff | 1/   # Frame, A=1
BP:           3   0 34  34 | nv-BdIzC 02 06 b8 ff | 1/   # Frame, A=2
BP:           9   0 59 109 | nv-BdIZC 20 00 b8 fd | 1/   # RamWrite, A=$20 (space), X=0
BP:          17   0 59 109 | nv-BdIzC 20 01 b8 fd | 1/   # RamWrite, A=$20, X=1
BP:          49   0 59 109 | nv-BdIzC 53 05 b8 fd | 1/   # RamWrite, A=$53 ('S'), X=5
BP:           9   0 63 121 | nv-BdIzC 20 00 b8 fd | 1/   # RamRead, A=$20, X=0
BP:          17   0 63 121 | nv-BdIzC 20 01 b8 fd | 1/   # RamRead, A=$20, X=1
BP:          49   0 63 121 | nv-BdIzC 53 05 b8 fd | 1/   # RamRead, A=$53, X=5
BP:           9   2 59 109 | nv-BdIzc 01 00 b8 fd | 1/   # RamPtr, A=1
BP:          17   2 59 109 | nv-BdIzc 02 00 b8 fd | 1/   # RamPtr, A=2
BP:           9   2 72 148 | nv-BdIzc 01 00 b8 fd | 1/   # MsgPtr, A=1
BP:          17   2 72 148 | nv-BdIzc 02 00 b8 fd | 1/   # MsgPtr, A=2
BP:           9   3 04 -56 | nv-BdIzc 01 00 b8 fd | 1/   # Writes, A=1
BP:          17   3 04 -56 | nv-BdIzc 02 00 b8 fd | 1/   # Writes, A=2
BP:           9   3 12 -32 | nv-BdIzc 01 00 b8 fd | 1/   # Reads, A=1
BP:          17   3 12 -32 | nv-BdIzc 02 00 b8 fd | 1/   # Reads, A=2
```

The first update runs at program frame 8, which the emulator reports as frame 9 (the log's frame counter starts one frame before the first visible frame). At X=5 the written byte is `$53`, the ASCII `S`, and `RamRead` returns `$53` from `$1080+5`: the write and the read agree. The bank field at the end of every line is `1/`; the demo never selects bank 0.

The two 4K banks carry the signature exactly. The check compares each bank's first 128 bytes with its next 128:

```text
bank 0: $F000-$F07F = EA x128; $F080-$F0FF = EA x128; equal
bank 1: $F000-$F07F = EA x128; $F080-$F0FF = EA x128; equal
entry at $F100 in both banks: AD F9 1F 4C 06 F1
vectors at $FFFA/FFFC/FFFE in both banks: 00 F1 (=$F100)
```

A variant with the duplicate removed from one bank assembles to the same 8,192 bytes but Stella reports `F8* (8K)` instead of `F8SC* (8K)`. That is the signature doing its job.

The pixel checks decode the captures with `x = 25 + 6 × TIA X` and `y = 107 + 3.156 × visible line`:

| Check | `notebook-a.png` | `notebook-b.png` | Expected |
|---|---|---|---|
| full image | 1010×807 | 1010×807 | window plus title bar |
| title bar | `Stella 7.0: "57-superchip"` | the same | the committed ROM |
| background | `$00` (0,0,0) | the same | black page |
| status and gauge | `$C8` (81,179,80) | the same | green |
| gauge, visible 0–6 | x=121–216: 4 cells | x=121–360: 10 cells | 16 cells of 24 px |
| gauge mirror | x=793–888: 4 cells | x=649–888: 10 cells | reflected |
| separator, visible 7 | y=129–130, x=25–984 | the same | row 7 solid |
| message | `$0E` (234,234,233), x=25–313 and 697–984, y=132–174 | the same | two lines of three characters |
| marker | `$1A` (205,205,52), x=319–366, y=410–433 | x=223–270 | 8×8 diamond at TIA X 49–56 / 33–40 |
| cursor | none | none | pointer parked at (0,0) |

The screenshots prove the visual state; the state log proves the frame, the write, the read, and the counters.

## Exercises

### Exercise 1: Fill All 128 Bytes

**Challenge:** fill all 128 Superchip bytes with a pattern during the init, read every byte back, and light all 16 gauge cells when every byte matches. A mismatch must leave the gauge empty **permanently** — the periodic update must not refill it — so the display is the test result.

**Hints:**
1. Write `X EOR $A5` to `$1000+X` for X = 0–127. The pattern changes with the address, so a read-back that is stuck at one value cannot pass.
2. Keep the expected byte in a scratch byte across the read; `CMP` compares A with memory, not with X.
3. When the loop passes, write `$FF` to `GaugeLo` and `GaugeHi`; the status kernel draws the full bar. On a failure, write `$00` to both.
4. Set a failure flag in the failure path (for example `FillFailFlag` at `$AD`) and have the periodic gauge update skip its OR when the flag is set. The periodic update can keep running after a success; its ORed masks will not clear the full gauge.

**Expected Result:** the ROM assembles to 8,192 bytes and Stella reports `F8SC* (8K)`. At power-on all 16 gauge cells are lit (the green bar spans both gauge halves), the "SC" label and the message window are visible, and the marker still sweeps. `FillRead` reports the changing pattern (`A=$A5, $A4, $A7, …`) and `FillDone` reports `A=$FF`. On a forced mismatch, `FillFailFlag` is `$01` and the gauge stays empty even after many update frames (the failure path is code-reviewed).

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: The 16-Row × 8-Byte Strip

**Challenge:** store a 16-row × 8-byte graphics strip (128 bytes) in the Superchip RAM and draw it. Each row of the table is eight bytes; each byte is one scanline's `PF2` pattern. The 16 rows become 16 bands of eight scanlines, and the eight bytes in a band step one chunk to the right.

**Hints:**
1. Copy the 128-byte ROM table to `$1000+X` with a loop; this is a write-window exercise, so every byte must go through the window.
2. Draw the strip by reading it back through `$1080+Y`: `LDA $1080,Y / STA PF2 / STA WSYNC` for Y = 0–127. There is no RAM copy of the table in the kernel: the read window is the table.
3. Set `GaugeLo` and `GaugeHi` to `$FF` after the copy; all 128 bytes were written, so all 16 cells are lit.
4. Keep the status band and the marker; the strip replaces the message in the play area.

**Expected Result:** the ROM assembles to 8,192 bytes and Stella reports `F8SC* (8K)`. The status shows the full gauge; the play area shows a 128-line diagonal weave (8 chunks wide, reflected to 64 pixels) with the gold diamond below it. `StripRead` reports the first bytes `$01, $02, $04, $08, …` and `StripDone` reaches Y=128 with A=$00 (the loop's `LDA #$00`/`STA PF` clear). The frame stays at `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Persistence Across a Bank Switch

**Challenge:** write a value in bank 1, switch to bank 0, read the value back, and show that the Superchip RAM persists. Bank 0 must not write the value it checks.

**Hints:**
1. The RAM is in the cartridge, not in a bank. A bank switch changes which 4K ROM is visible; it does not touch `$1000–$10FF`. Bank 0's `LDA $1080` therefore sees the byte bank 1 wrote.
2. The switch stubs must be duplicated at the same address in both banks. Use `$F100` for the bank-1 stub and `$F200` for the bank-0 stub; `$F060/$F070` are inside the RAM window and cannot hold code.
3. Bank 1's init does `+clean_start`, zeroes the RAM, writes `$A5` to `$1000`, and runs a 64-frame loop. Then it jumps to `$F200`.
4. Bank 0's main entry must assert `+vsync` **immediately**, before the read and the colour setup, so the switch frame is not late. Then it reads `$1080`, compares with `$A5`, and sets the background green on a match (red on a mismatch). Bank 0 stays in bank 0; there is no switch back and no bank-1 re-entry.
5. Put a breakpoint at the read in each bank and at the write in bank 1. The log's bank field distinguishes the two.

**Expected Result:** the ROM assembles to 8,192 bytes and Stella reports `F8SC* (8K)`. The screen is blue while bank 1 runs, then green after the one-way switch, and it stays green. `B1Write` reports `A=$A5` in bank 1; `B0Read` reports `A=$A5` in bank 0; `B0Color` reports `A=$C8` (green). Bank 0's steady frames are `B0StartFrame` 259/3, `B0VblankStart` 0/5, `B0BodyStart` 37/5, `B0OverscanStart` 229/6. The switch frame's first `B0StartFrame` is 259/15, and its `B0VblankStart` is 0/5, so the frame stays 262 lines.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **F8SC is F8 plus 128 bytes of RAM.** The two F8 banks are unchanged; the new memory is a 128-byte cartridge RAM with a write window at `$1000–$107F` and a read window at `$1080–$10FF`.
- ✅ **The first 256 bytes of each bank are the RAM window.** Code starts at `$F100`; the vectors at `$FFFA–$FFFF` are safe because they sit outside the window.
- ✅ **The duplicated 128-byte signature is how the mapper is detected.** Each bank's first 128 bytes are repeated at +128; without the duplicate Stella reports plain F8, and the RAM writes have nothing to land in.
- ✅ **The console does not zero this RAM.** A real SRAM powers up unknown; the program writes 128 zeros (or any seed) explicitly. `+clean_start` does not touch it.
- ✅ **The RAM is cartridge memory, not bank memory.** A bank switch changes the visible ROM; the 128 bytes survive, which is what exercise 3 proves.
- ✅ **One byte every eight frames is enough to make the memory visible.** The write pointer walks 0–127, the gauge lights one cell per eight bytes, and the six-glyph window scrolls through the message.
- ✅ **The frame does not change.** The 3 + 37 + 192 + 30 skeleton stays at `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6, with one `HMOVE` in VBLANK.

## What's Next

The Superchip adds RAM but keeps the instruction set ordinary. [Lesson 58: Illegal Opcodes — Undocumented Power](/part8-advanced/58-illegal-opcodes) opens the stable undocumented NMOS 6502 instructions — LAX, SAX, DCP, ISB, and their relatives — and shows how to use them safely (and how to write them in ACME, which has no mnemonics for them).
