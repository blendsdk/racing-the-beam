---
title: "Lesson 56: Bankswitching — Beyond 4KB"
description: "Open the 6507's 4K cartridge window: build an 8,192-byte F8 ROM with two banks, byte-identical switch-and-jump trampolines at $F060/$F070, a start bank of 1, two data-driven scenes, and a two-cell bank indicator; then extend the idea to a 16K F6 image and a dedicated data bank."
prev:
  text: "Lesson 55: Scrolling Text Marquee — The Activision Logo Effect"
  link: "/part7-kernel-mastery/55-scrolling-text-marquee"
next:
  text: "Lesson 57: Superchip — Extra RAM"
  link: "/part8-advanced/57-superchip"
---

# Lesson 56: Bankswitching — Beyond 4KB

> **Part 8: Advanced Topics** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and memory), Lesson 12 (the frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players), Lesson 26 (positioning), Lesson 33 (`INPT4` and the fire button), Lesson 48 (the kernel taxonomy)
> **You will learn:** why the 6507 sees only 4K of cartridge at a time; how the F8 mapper hides two 4K banks behind `$F000–$FFFF`; the `$1FF8`/`$1FF9` hotspots and the F8 start bank; why the switch-and-jump stub is duplicated at a fixed address in every bank; the cost of a switch (a read, then a fetch from the new bank); code banks versus data banks; and how to keep a 262-line frame while the code changes underneath it
> **You will build:** "the two worlds" — an 8,192-byte F8 ROM whose bank 1 draws a green/blue forest and whose bank 0 draws a red/orange cave, switched by an auto-demo every 120 frames or by fire, with a two-cell indicator that shows the active bank; plus three exercise solutions: a scene swap, a 16,384-byte four-bank F6 cartridge, and a data bank that keeps the 192-byte playfield table in bank 0

## Introduction

Every lesson so far has lived inside one 4K cartridge. The 6507 has thirteen address lines, so the cartridge window is `$F000–$FFFF`: 4,096 bytes that hold the reset vector, the code, the tables, the graphics, and the vectors. When a game outgrows that window, the extra content does not disappear. It hides in a second 4K bank behind the *same* window, and a small piece of hardware — the mapper — chooses which bank the CPU sees at any moment.

This lesson builds the classic first mapper, **F8**: 8,192 bytes, two 4K banks, selected by a read from `$1FF8` (bank 0) or `$1FF9` (bank 1). The trick is not the read itself. It is what happens on the next cycle: the CPU fetches the instruction after the read from the *new* bank. If the bytes at that address differ between the two banks, the CPU executes garbage. The course's answer is the **duplicate switch-and-jump stub**: the same two instructions at the same fixed address in every bank, so the fetch after the select is identical no matter which bank is active.

The companion program `56-bankswitching.asm` is **the two worlds**. Bank 1, the start bank, draws a green forest on a blue sky. Bank 0 draws a red cave on an orange background. An auto-demo switches every 120 frames; fire switches immediately. A two-cell indicator in the first eight lines shows which bank is selected. The two banks carry the *same code* at the same virtual addresses; only the data block at `$F200–$F2C3` differs (the 192-byte player strip at `$F300` is the same), so a switch changes the world without changing the program. The three exercise solutions then move the idea in three directions: swap the scenes, build a 16K F6 cartridge with four banks, and give the playfield table its own data bank.

::: details TypeScript Equivalent

A bank-switched cartridge is a window onto a larger array, plus a latch that chooses the slice. In TypeScript the shape is a small class:

```typescript
class F8Cartridge {
  private readonly banks: Uint8Array[];
  private selected = 1;                  // F8 starts in bank 1

  constructor(image: Uint8Array) {
    this.banks = [image.subarray(0, 4096), image.subarray(4096, 8192)];
  }

  read(address: number): number {
    if (address === 0x1ff8) this.selected = 0;   // the hotspot read
    if (address === 0x1ff9) this.selected = 1;
    return this.banks[this.selected][address & 0x0fff];
  }
}
```

The analogy breaks in the places that make banking hard. `read` is not a function call: it is a bus cycle that happens while the CPU is fetching an instruction. There is no stack frame, no return address, and no chance to undo the switch if the next byte is wrong. The `selected` latch lives in the cartridge, not in a variable the CPU can inspect; `LDA $1FF9` does not return the bank number, it performs the select and loads whatever byte the ROM drives. The start bank is a property of the mapper's power-on state, not a constructor default you can choose: F8 starts in bank 1 and F6 starts in bank 0. And the 4K window is not a pointer into a larger address space — the program counter, the stack, and every absolute address are still 16-bit values in the same `$F000–$FFFF` range, so the same address means a different byte in each bank.

:::

## Theory

### Section 1: The 4K Window

The 6507 is a 6502 with fewer pins. It exposes thirteen address lines (`A0–A12`), so it can address 8,192 bytes: the 128 bytes of RIOT RAM at `$80–$FF`, the TIA and RIOT registers at `$00–$7F` and `$0280–$0297`, and the cartridge at `$F000–$FFFF`. The cartridge's address decode uses `A12`: when `A12` is high and the other lines select the upper region, the ROM is enabled. The 4,096 bytes at `$F000–$FFFF` are the **window**.

Inside the window, `$FFFA–$FFFF` holds the three vectors: NMI at `$FFFA`, RESET at `$FFFC`, IRQ at `$FFFE`. The 2600 has no interrupts, so only RESET matters in practice, but every bank still needs valid vector bytes because the CPU reads `$FFFC` from whichever bank is selected when the console is powered on or reset.

| Mapper | ROM size | Banks | Hotspot reads | Start bank |
|---|---|---|---|---|
| none | 2K or 4K | 1 | — | — |
| **F8** | **8K** | **2** | **`$1FF8` = 0, `$1FF9` = 1** | **1** |
| **F6** | **16K** | **4** | **`$1FF6–$1FF9` = 0–3** | **0** |
| F4 | 32K | 8 | `$1FF4–$1FFB` = 0–7 | 0 |
| F8SC | 8K + 128 B RAM | 2 | `$1FF8`/`$1FF9`, plus the RAM window | 1 |

The start-bank column is the one that bites. In Stella 7, an F8 ROM's first reset vector is read from bank 1 and an F6 ROM's from bank 0. A program that puts its entry point in bank 0 of an F8 image produces a black screen: the CPU reads bank 1's `$FFFC`, not bank 0's, so it jumps to whatever bank 1's slot holds (often `$FF` fill) and the code that was meant to run never does.

::: warning The reset vector is per bank
The CPU does not know which bank is selected. It reads `$FFFC` from the current bank and jumps to that address. If the selected bank's `$FFFC` is unprogrammed (usually `$FF`), the CPU jumps to `$FFFF`, executes an undocumented opcode, and the console appears dead. Put a valid vector in *every* bank, not only the start bank.
:::

### Section 2: F8, the Hotspots, and the Start Bank

F8 splits the 8K image into two 4K banks. The mapper watches the cartridge's address lines for a read whose low 13 bits match `$1FF8` or `$1FF9`. In the 6507's 13-bit world, `$1FF8` and `$FFF8` are the same external address: both have `A12 = 1` and `A0–A11 = $FF8`. That is why a `LDA $1FF8` written in the `$F000` window reaches the mapper even though `$1FF8` is not inside the window.

| Read from | Selected bank | File offset | Real address of the bank |
|---|---|---|---|
| `$1FF8` | bank 0 | `$0000–$0FFF` | `$E000–$EFFF` in the flat image |
| `$1FF9` | bank 1 | `$1000–$1FFF` | `$F000–$FFFF` in the flat image |

The flat file is bank 0 first, then bank 1. The source writes bank 0 at real `$E000` with `!pseudopc $F000`, so its labels and absolute addresses are the same as bank 1's; the assembler writes the bytes to `$E000` while pretending the code lives at `$F000`. Bank 1 is written at real `$F000` with a second `!pseudopc $F000`. The two 4K halves are therefore two views of the same virtual address space, and a label defined in bank 1 can describe the same address in bank 0.

F8 starts in **bank 1**. At power-on the CPU reads bank 1's `$FFFC`, so bank 1's reset is the first instruction that runs. Bank 0's code never runs at power-on: it executes only after a read selects bank 0. That is the design of this lesson: bank 1 is the forest, bank 0 is the cave, and the cave does not exist until the switch.

::: tip Why the start bank is not a free choice
The mapper's power-on state is wired into the cartridge hardware. You cannot change it from software before the first instruction, because the first instruction comes from the start bank's reset vector. If you want a particular bank to run first, put the entry point there — or put a switch in the start bank's reset that immediately selects the bank you want. The second option costs a few cycles and is what a game does when its "main" bank is not the mapper's start bank.
:::

### Section 3: The Duplicate Switch-and-Jump Stub

The switch is a read followed by a fetch. The 6502's `LDA $1FF9` is four cycles: the address is placed on the bus, the mapper sees the read, and the bank latch changes. The **next** instruction fetch — the opcode after the `LDA` — now comes from the new bank. If the instruction after the `LDA` is a `JMP`, its three opcode bytes must be at the same address in both banks, and its target must be valid in both banks.

The course's pattern puts the stub at fixed addresses:

```asm
; the same six bytes in every bank
    * = $F060
Switch1:
    LDA $1FF9       ; select bank 1
    JMP $F080       ; continue at $F080 in bank 1
    * = $F070
Switch0:
    LDA $1FF8       ; select bank 0
    JMP $F080       ; continue at $F080 in bank 0
```

The `JMP`'s opcode is at `$F063` (or `$F073`). Both banks have a `JMP $F080` there, so the fetch is safe whichever bank the read selected. The target `$F080` is the bank's main; both banks have one. If the two stubs differed by even one byte, the CPU would decode the new bank's byte as a different instruction and the program would crash.

This is why the lesson's source pads the reset to `$F060`, the stub to `$F070`, and the second stub to `$F080` with `!fill … , $EA`. The fixed addresses are not decoration: they are the contract that makes the cross-bank jump safe.

::: warning Never jump across a bank boundary directly
`LDA $1FF8` followed by `JMP CaveOnlyRoutine` is safe only if the `JMP` bytes at the address after the `LDA` are identical in both banks *and* `CaveOnlyRoutine` exists in the new bank. A direct jump to a routine that lives in only one bank is the classic banking crash. Route every switch through the duplicated stub.
:::

### Section 4: What a Switch Costs

A bank switch is not a context switch. There is no register save, no stack, no interrupt, and no return path. The mapper operation itself is the read plus the fetch:

| Work | Cycles |
|---|---|
| `LDA $1FF9` (the hotspot read) | 4 |
| `JMP $F080` (fetched from the new bank) | 3 |
| the target's `LDA SceneInit` (absolute) | 4 |
| the `NOP` that separates `BankEntry` from `StartFrame` | 2 |
| **the mapper chain** | **13** |

The demo wraps that chain in the frame's bookkeeping: it clears `SwitchFlag`, flips `Bank`, reloads `BankTimer`, tests the new bank, and dispatches through the trampoline. That bookkeeping adds 23 cycles on the switch to bank 0 and 24 on the return (the taken branch is one cycle longer), and the dispatch `JMP` adds 3. The switch path is therefore 39 cycles outbound or 40 on the return, against the ordinary path's 3-cycle `JMP StartFrame`: a measured offset of **36 or 37 cycles**.

On the switch frame the state log reports `StartFrame` at **259/39** on the way to bank 0 and **259/40** on the way back to bank 1, instead of the steady **259/3**; the `+vsync` macro's three `WSYNC`s absorb the offset, so `VblankStart` is still **0/5** and `BodyStart` is still **37/5**. The frame stays 262 lines. The next frame is back at 259/3.

The switch is deliberately *not* in the middle of the visible kernel. A switch during the picture would change the code under the beam: the instruction fetch after the read would come from the new bank, and the old bank's loop would disappear mid-frame. The blanked overscan is the safe place; the visible picture is already finished.

### Section 5: The Two Worlds

Both banks carry the same frame skeleton: 3 VSYNC lines, 37 VBLANK lines, 192 picture lines, and 30 overscan lines. The only difference is the data block:

| Virtual address | Bytes | Bank 0 (cave) | Bank 1 (forest) |
|---|---|---|---|
| `$F200–$F2BF` | 192 | a symmetric red cave (ceiling, narrowing centre block, two outward-stepping walls, floor) | a green canopy and three trunks |
| `$F2C0–$F2C2` | 3 | `$28,$44,$1A` (orange, red, gold) | `$84,$C8,$0E` (blue, green, white) |
| `$F2C3` | 1 | `$00` (the bank number) | `$01` (the bank number) |
| `$F300–$F3BF` | 192 | the 8-line diamond at rows 96–103 | the same diamond |

The kernel is a single 1-line loop. It reads one `PF2` byte per visible line, writes it, reads one `GRP0` byte per line, writes it, and waits for the next line:

```asm
    LDY #0
KernelRow:
    LDA ScenePF2,Y
    CPY #INDICATOR_ROWS
    BCS NoIndicator
    LDA Bank
    BEQ Cell0
    LDA #INDICATOR_1
    BNE CellDone
Cell0:
    LDA #INDICATOR_0
CellDone:
NoIndicator:
    STA PF2
    LDA ScenePlayer,Y
    STA GRP0
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE KernelRow
```

The first eight rows are the **two-cell bank indicator**. The table's first eight bytes are zero; the kernel replaces them with a pattern chosen by the `Bank` variable: `$03` (PF2 bits 0–1, pixels 48–55) in bank 1 and `$30` (PF2 bits 4–5, pixels 64–71) in bank 0. The playfield is reflected (`CTRLPF = $01`), so each cell and its mirror both appear. The rest of the table is the scene. The indicator is tied to the bank number, not to the scene data, which is why exercise 1's scene swap leaves it pointing at the correct bank.

PF0 and PF1 stay zero; PF2 covers the middle eight chunks (pixels 48–79), and the reflected playfield mirrors them across the centre, so the visible field spans pixels 48–111. The 1-line kernel is 31 cycles on a scene row, 40 on a bank-1 indicator row, and 37 on a bank-0 indicator row; the worst is 40, so the 76-cycle line leaves at least 36 cycles. On a scene row the `STA PF2` lands at cycle 18 and the `STA GRP0` at cycle 25: `WSYNC` releases the line, the 7-cycle loop tail runs at the top, then the load/compare/store chain. The PF2 field starts at pixel 48 (about cycle 38.7) and the player is at TIA X 72 (about cycle 46.7), so both stores are early.

The player is a fixed 8-line diamond at TIA X 72. It is positioned once per frame with the Lesson 26 divide-by-15 dance and one `HMOVE` in VBLANK. The player strip is 192 bytes: 96 zeros, eight shape bytes, 88 zeros. The colour comes from `COLUP0`, which the VBLANK code reloads from the bank's `SceneColors` every frame; that is how a bank switch changes the palette in one frame.

### Section 6: The Switch Logic

The frame's VBLANK block does four jobs: it reloads the bank's palette, it increments the frame counter, it checks the fire edge and the 120-frame auto-demo, and it positions P0. A switch is requested by setting `SwitchFlag`. The flag is *not* acted on immediately: the visible kernel still has to run, because the switch belongs in the blanked overscan.

```asm
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    LDA SwitchFlag
    BNE SwitchOverscan
    +wait_timer
    JMP StartFrame
SwitchOverscan:
    +wait_timer
    LDA #$00
    STA SwitchFlag
    LDA Bank
    EOR #$01
BankWrite:
    STA Bank
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA Bank
    BNE SwitchOne
    JMP $F070               ; select bank 0
SwitchOne:
    JMP $F060               ; select bank 1
```

The branch before the timer wait keeps the normal path's `JMP StartFrame` at scanline 259/0, so `StartFrame` is 259/3 on ordinary frames. The switch path spends the extra cycles on scanline 259; the target's `+vsync` turns the frame around and the three `WSYNC`s align `VblankStart` to 0/5. The result is one frame of 262 lines either way.

The fire edge uses the standard `INPT4` detector: bit 7 is 0 while the button is held, `EOR #$80` turns that into 1, and the `EOR`/`AND` pair keeps only a new press. The first eight frames are ignored because `INPT4` can read low while the console settles. The auto-demo decrements `BankTimer` every frame and requests a switch when it reaches zero; a switch reloads it with 120, so the rhythm is one switch every 120 frames (about two seconds).

## The Code

### Building This Lesson

```bash
# every lesson ROM, including this one:
npm run roms

# or just this one:
acme -f plain -o build/lesson56.bin \
  lessons/part8-advanced/56-bankswitching/56-bankswitching.asm

stella build/lesson56.bin
```

The source assembles to exactly 8,192 bytes. The flat image is bank 0 (real `$E000–$EFFF`) followed by bank 1 (real `$F000–$FFFF`). Stella's log reports the mapper it selected for the image:

```text
Bankswitch Type: F8* (8K)
```

The `.bin` has no mapper header, so the emulator's log is the evidence for the scheme; the source does not carry a mapper declaration of its own.

The exercise solutions sit beside the lesson source:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part8-advanced/56-bankswitching/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part8-advanced/56-bankswitching/exercise-02-solution.asm
acme -f plain -o build/exercise-03.bin \
  lessons/part8-advanced/56-bankswitching/exercise-03-solution.asm
```

### Full Source

The complete annotated source is reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 56: Bankswitching — Beyond 4KB — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the two worlds": an 8,192-byte F8 cartridge.  The 6507 sees one 4K
;   window at $F000-$FFFF; the F8 mapper hides two 4K banks behind it.  Bank 1
;   draws a green forest on a blue sky; bank 0 draws a red cave on an orange
;   background.  An auto-demo switches every 120 frames and fire switches
;   immediately.  A two-cell indicator in the first eight lines shows which
;   bank is selected.
;
; The F8 layout (the flat file is bank 0 then bank 1):
;   file offset $0000-$0FFF   bank 0, real $E000, assembled with !pseudopc $F000
;   file offset $1000-$1FFF   bank 1, real $F000
;
; F8 starts in BANK 1.  At power-on the CPU reads the reset vector from bank
; 1's $FFFC, so bank 1's ForestReset is the first instruction that runs.
; Bank 0's code never runs at power-on; it is reached by the switch.
;
; The switch-and-jump trampolines, byte-identical in both banks:
;   $F060  Switch1  LDA $1FF9   select bank 1   JMP $F080
;   $F070  Switch0  LDA $1FF8   select bank 0   JMP $F080
; The hotspot read changes the bank; the JMP that follows is fetched from the
; new bank.  Its bytes and its target therefore have to be valid in both banks,
; which is why the two stubs sit at the same fixed addresses in both banks.
;
; Each bank's virtual layout ($F000-$FFFF):
;   $F000   the bank's reset (this source ends it before $F060)
;   $F060   Switch1
;   $F070   Switch0
;   $F080   the bank's main: LDA SceneInit / BankEntry / NOP / StartFrame
;   $F200   ScenePF2    192 bytes: one PF2 byte per visible line
;   $F2C0   SceneColors  3 bytes: COLUBK, COLUPF, COLUP0
;   $F2C3   SceneInit    1 byte: the bank number (1 in bank 1, 0 in bank 0)
;   $F300   ScenePlayer 192 bytes: an 8-line diamond at visible rows 96-103
;   $FFFA   the vectors: Reset, Reset, Reset
;
; The two banks carry the same code at the same virtual addresses.  The only
; difference is the data block at $F200-$F2C3 (the player strip at $F300 is the
; same in both banks), so the switch changes the world without changing the
; program.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;
; The 1-line kernel: 31 cycles on a scene row (LDA 4 + CPY 2 + BCS 4 + STA 3 +
; LDA 4 + STA 3 + WSYNC 3 + INY 2 + CPY 2 + BNE 4; the taken branches cross
; pages); a bank-1 indicator row is 40 and a bank-0 row is 37.  The 76-cycle
; line leaves at least 36 cycles.
;
; Checkpoints (Stella scanline numbers in parentheses; the bank 0 copies sit at
; the same virtual addresses):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   OverscanStart (229/6); Frame (A = the new frame count);
;   BankEntry (A = 1 at power-on, A = 0 after the switch to bank 0);
;   BankWrite (A = the new bank: 0 or 1); SwitchRead1/SwitchRead0 (the
;   hotspot reads at $F060/$F070; the log's bank field is the old bank).
;
; RAM map (+clean_start zeroes every byte):
;   $80   Bank        the selected bank: 1 at power-on, 0 after the switch
;   $81   BankTimer   frames left before the auto-demo switches (120)
;   $82   FrameCount  frames since reset, wraps at 256
;   $83   SwitchFlag  1 = switch at the end of this frame, 0 = stay
;   $84   PrevFire    fire state last frame (1 = pressed)
;   $85   NewFire     this frame's fire 0 -> 1 edge
;   $86   Startup     frames left before the fire line is trusted
;   $87-$9F free (25 bytes)
;   $F8-$FF stack
;
; Build: acme -f plain -o build/lesson56.bin \
;        lessons/part8-advanced/56-bankswitching/56-bankswitching.asm
; Run:   stella build/lesson56.bin
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

SCREEN_LINES   = 192     ; the 1-line kernel draws every visible line
INDICATOR_ROWS = 8       ; the two-cell indicator occupies the first 8 lines
DEMO_PERIOD    = 120     ; frames between auto-demo switches (about 2 seconds)
PLAYER_X       = 72      ; the diamond's left edge, TIA X 72..79
PLAYER_TOP     = 96      ; the diamond's first visible row

INDICATOR_1    = $03     ; bank 1: PF2 bits 0-1, pixels 48-55 (the left cell)
INDICATOR_0    = $30     ; bank 0: PF2 bits 4-5, pixels 64-71 (the right cell)

C_FOREST_BG    = $84     ; bank 1 background: blue
C_FOREST_PF    = $C8     ; bank 1 playfield: green
C_FOREST_P0    = $0E     ; bank 1 marker: white
C_CAVE_BG      = $28     ; bank 0 background: orange
C_CAVE_PF      = $44     ; bank 0 playfield: red
C_CAVE_P0      = $1A     ; bank 0 marker: gold

; =============================================================================
; THE FIXED DATA ADDRESSES — the same in both banks
; =============================================================================
; The code uses these absolute addresses, not per-bank labels, so both banks
; assemble the same instructions.  The bytes behind them differ per bank.
ScenePF2    = $F200      ; 192 bytes, one PF2 byte per visible line
SceneColors = $F2C0      ; 3 bytes: COLUBK, COLUPF, COLUP0
SceneInit   = $F2C3      ; 1 byte: the bank number
ScenePlayer = $F300      ; 192 bytes, one GRP0 byte per visible line

; =============================================================================
; RAM ALLOCATION ($80-$86; +clean_start zeroes every byte)
; =============================================================================
Bank        = $80    ; the selected bank: 1 at power-on, 0 after the switch
BankTimer   = $81    ; frames left before the auto-demo switches
FrameCount  = $82    ; frames since reset, wraps at 256 (the Frame checkpoint)
SwitchFlag  = $83    ; 1 = switch at the end of this frame
PrevFire    = $84    ; fire state last frame (1 = pressed)
NewFire     = $85    ; this frame's fire 0 -> 1 edge
Startup     = $86    ; frames left before the fire line is trusted
;
; $87-$9F are free (25 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (SetCoarseP0).

; =============================================================================
; BANK 0 — real $E000, virtual $F000.  THE CAVE.
; =============================================================================
; The flat ROM starts here.  !pseudopc assembles the code as if it sat at
; $F000, while the bytes go to the real $E000-$EFFF.  A label defined here
; has the same address as its twin in bank 1, which is exactly what the
; trampolines need.
    * = $E000
    !pseudopc $F000 {

; -----------------------------------------------------------------------------
; CaveReset — bank 0's entry (not used at power-on; the F8 mapper starts in
; bank 1, and this vector only runs if the console is reset while bank 0 is
; selected)
; -----------------------------------------------------------------------------
CaveReset:
    +clean_start            ; zero TIA and RAM, set the stack to $FF
    LDA #$00
    STA SWACNT              ; port A is an input port (the joystick)

    LDA SceneInit           ; bank 0's own data: $00
    STA Bank
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA #$00
    STA FrameCount
    LDA #$08
    STA Startup             ; ignore fire while the console settles

; --- the cave's palette ------------------------------------------------------
    LDA SceneColors+0
    STA COLUBK              ; orange background
    LDA SceneColors+1
    STA COLUPF              ; red rock
    LDA SceneColors+2
    STA COLUP0              ; gold marker
    LDA #$01
    STA CTRLPF              ; reflect the playfield: the right half mirrors

    JMP CaveMain            ; $F080 is the same address in both banks

; The reset must end before the fixed trampoline at $F060.  The !if turns
; that rule into a build failure instead of a silent overlap.
    !if * > $F060 {
        !error "bank 0's reset must fit before $F060"
    }
    !fill $F060 - *, $EA

; -----------------------------------------------------------------------------
; The fixed trampolines — THE SAME SIX BYTES AS BANK 1
; -----------------------------------------------------------------------------
; A read from $1FF9 selects bank 1.  The JMP that follows is fetched from the
; new bank at $F063, so the bytes at $F060-$F065 must be identical in both
; banks; they are.  The target $F080 is also the same in both banks.
CaveSwitch1:
    LDA $1FF9               ; select bank 1 (the hotspot read)
    JMP $F080               ; continue in bank 1's main
    !fill $F070 - *, $EA

CaveSwitch0:
    LDA $1FF8               ; select bank 0 (the hotspot read)
    JMP $F080               ; continue in bank 0's main
    !fill $F080 - *, $EA

; -----------------------------------------------------------------------------
; CaveMain — the bank's main ($F080)
; -----------------------------------------------------------------------------
; The reset and the trampoline both land here.  The LDA is three cycles and
; sets A to the bank number, so BankEntry reports A=0 in this bank.  The NOP
; keeps BankEntry and StartFrame as separate breakpoints; the frame loop
; jumps straight to StartFrame, so only a real bank entry runs the LDA/NOP.
CaveMain:
    LDA SceneInit           ; A = 0 (bank 0)
CaveBankEntry:
    NOP
CaveStartFrame:
    +vsync                  ; 3 VSYNC lines: 259, 260, 261

CaveVblankStart:
    LDA #$02
    STA VBLANK              ; blank the picture
    +set_timer VBLANK_TIMER

; --- the palette is read every frame, so a switch changes the world ----------
    LDA SceneColors+0
    STA COLUBK
    LDA SceneColors+1
    STA COLUPF
    LDA SceneColors+2
    STA COLUP0

; --- the frame counter -------------------------------------------------------
    INC FrameCount
    LDA FrameCount
CaveFrame:                  ; checkpoint: A = the new frame count

; --- fire: a new press asks for a switch at the end of this frame ------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1, and the
; EOR/AND pair keeps only the 0 -> 1 edge, so holding the button switches
; once.  The first eight frames are ignored: INPT4 can read low while the
; console settles.
    LDA INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire             ; NewFire = pressed & ~wasPressed
    LDA Startup
    BEQ CaveFireReady
    DEC Startup
    LDA #$00
    STA NewFire
CaveFireReady:
    LDA NewFire
    BEQ CaveNoFire
    LDA #$01
    STA SwitchFlag
CaveNoFire:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; --- the auto-demo: one switch every 120 frames ------------------------------
    DEC BankTimer
    BNE CaveTimerDone
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA #$01
    STA SwitchFlag
CaveTimerDone:

; --- position P0: one divide-by-15 dance and one HMOVE -----------------------
; SetCoarseP0 sets HMP0 and strobes RESP0.  The WSYNC starts a fresh line and
; the HMOVE applies the fine offset in its HBLANK.  This is the frame's only
; HMOVE, and it falls inside VBLANK, so its left-edge blanking is unseen.
    LDA #(PLAYER_X + POS_BIAS)
    JSR CaveSetCoarseP0
    STA WSYNC
    STA HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; -----------------------------------------------------------------------------
; The visible kernel — 192 lines, one PF2 byte and one GRP0 byte per line
; -----------------------------------------------------------------------------
; The first eight rows show the two-cell bank indicator instead of the scene.
; Bank 0 lights the right cell ($30); the playfield is reflected, so the cell
; and its mirror both appear.  The table's own first eight bytes are blank.
CaveBodyStart:              ; checkpoint: scanline 37, visible line 0
    LDY #0
CaveKernelRow:
    LDA ScenePF2,Y
    CPY #INDICATOR_ROWS
    BCS CaveNoIndicator
    LDA Bank
    BEQ CaveCell0
    LDA #INDICATOR_1
    BNE CaveCellDone
CaveCell0:
    LDA #INDICATOR_0
CaveCellDone:
CaveNoIndicator:
    STA PF2
    LDA ScenePlayer,Y
    STA GRP0
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE CaveKernelRow

; -----------------------------------------------------------------------------
; Overscan — 30 lines, then either the next frame or the switch
; -----------------------------------------------------------------------------
; The switch decision was made in VBLANK.  The branch happens before the final
; timer wait, so the normal path still reaches StartFrame at 259/3; the switch
; path spends the trampoline's cycles on scanline 259 and the +vsync macro's
; three WSYNCs absorb them before VblankStart.
CaveOverscanStart:          ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    LDA SwitchFlag
    BNE CaveSwitchOverscan
    +wait_timer
    JMP CaveStartFrame
CaveSwitchOverscan:
    +wait_timer
    LDA #$00
    STA SwitchFlag
    LDA Bank
    EOR #$01                ; 0 -> 1, 1 -> 0
CaveBankWrite:              ; checkpoint: A = the new bank
    STA Bank
    LDA #DEMO_PERIOD        ; the new bank gets a full demo window
    STA BankTimer
    LDA Bank
    BNE CaveSwitchOne
    JMP $F070               ; select bank 0 and continue at $F080
CaveSwitchOne:
    JMP $F060               ; select bank 1 and continue at $F080

; -----------------------------------------------------------------------------
; CaveSetCoarseP0 — the Lesson 26 divide-by-15 positioning dance
; -----------------------------------------------------------------------------
; A = the desired left edge + POS_BIAS.  Each loop pass is 5 cycles = 15
; colour clocks, which is why dividing by 15 works.  The remainder becomes
; HMP0's fine value and RESP0 strobes the coarse position.
CaveSetCoarseP0:
    STA WSYNC
    SEC
CaveDivP0:
    SBC #15
    BCS CaveDivP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS

; -----------------------------------------------------------------------------
; Bank 0's data — the cave
; -----------------------------------------------------------------------------
    !if * > ScenePF2 {
        !error "bank 0's code must end before $F200"
    }
    !fill ScenePF2 - *, $EA

; The first eight bytes are blank: the kernel replaces them with the indicator.
; The table begins at ScenePF2 ($F200); the constant is the address, so the
; data needs no label of its own.
    !fill INDICATOR_ROWS, $00
    !fill 8,  $FF           ; visible 8-15:  a solid ceiling
    !fill 16, $F0           ; visible 16-31: the ceiling's right half
    !fill 32, $E0
    !fill 32, $70
    !fill 32, $38
    !fill 32, $1C
    !fill 24, $0E
    !fill 8,  $FF           ; visible 184-191: the floor

    !fill SceneColors - *, $EA
    !byte C_CAVE_BG, C_CAVE_PF, C_CAVE_P0
    !byte $00               ; SceneInit: bank 0

    !fill ScenePlayer - *, $EA
    !fill PLAYER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill SCREEN_LINES - PLAYER_TOP - 8, $00

    !fill $FFFA - *, $EA
    * = $FFFA
    !word CaveReset, CaveReset, CaveReset
}

; =============================================================================
; BANK 1 — real $F000, virtual $F000.  THE FOREST.
; =============================================================================
; This is the start bank: the F8 mapper selects it at power-on, so its reset
; vector at $FFFC is the one the CPU uses.  The code below is the same program
; as bank 0; only the data at $F200-$F2C3 differs (the player strip at $F300
; is the same).
    * = $F000
    !pseudopc $F000 {

; -----------------------------------------------------------------------------
; ForestReset — bank 1's entry (the power-on entry)
; -----------------------------------------------------------------------------
ForestReset:
    +clean_start
    LDA #$00
    STA SWACNT

    LDA SceneInit           ; bank 1's own data: $01
    STA Bank
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA #$00
    STA FrameCount
    LDA #$08
    STA Startup

; --- the forest's palette ----------------------------------------------------
    LDA SceneColors+0
    STA COLUBK              ; blue background
    LDA SceneColors+1
    STA COLUPF              ; green trees
    LDA SceneColors+2
    STA COLUP0              ; white marker
    LDA #$01
    STA CTRLPF              ; reflect the playfield

    JMP ForestMain

    !if * > $F060 {
        !error "bank 1's reset must fit before $F060"
    }
    !fill $F060 - *, $EA

; -----------------------------------------------------------------------------
; The fixed trampolines — THE SAME SIX BYTES AS BANK 0
; -----------------------------------------------------------------------------
Switch1:
SwitchRead1:                ; checkpoint: the bank-1 hotspot read ($F060)
    LDA $1FF9               ; select bank 1
    JMP $F080
    !fill $F070 - *, $EA

Switch0:
SwitchRead0:                ; checkpoint: the bank-0 hotspot read ($F070)
    LDA $1FF8               ; select bank 0
    JMP $F080
    !fill $F080 - *, $EA

; -----------------------------------------------------------------------------
; ForestMain — the bank's main ($F080)
; -----------------------------------------------------------------------------
ForestMain:
    LDA SceneInit           ; A = 1 (bank 1)
BankEntry:                  ; checkpoint: A = 1 at power-on, 0 after a switch
    NOP
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the palette is read every frame, so a switch changes the world ----------
    LDA SceneColors+0
    STA COLUBK
    LDA SceneColors+1
    STA COLUPF
    LDA SceneColors+2
    STA COLUP0

; --- the frame counter -------------------------------------------------------
    INC FrameCount
    LDA FrameCount
Frame:                      ; checkpoint: A = the new frame count

; --- fire --------------------------------------------------------------------
    LDA INPT4
    AND #$80
    EOR #$80
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire
    LDA Startup
    BEQ FireReady
    DEC Startup
    LDA #$00
    STA NewFire
FireReady:
    LDA NewFire
    BEQ NoFire
    LDA #$01
    STA SwitchFlag
NoFire:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; --- the auto-demo -----------------------------------------------------------
    DEC BankTimer
    BNE TimerDone
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA #$01
    STA SwitchFlag
TimerDone:

; --- position P0: one divide-by-15 dance and one HMOVE -----------------------
    LDA #(PLAYER_X + POS_BIAS)
    JSR SetCoarseP0
    STA WSYNC
    STA HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK

; -----------------------------------------------------------------------------
; The visible kernel
; -----------------------------------------------------------------------------
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDY #0
KernelRow:
    LDA ScenePF2,Y
    CPY #INDICATOR_ROWS
    BCS NoIndicator
    LDA Bank
    BEQ Cell0
    LDA #INDICATOR_1
    BNE CellDone
Cell0:
    LDA #INDICATOR_0
CellDone:
NoIndicator:
    STA PF2
    LDA ScenePlayer,Y
    STA GRP0
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE KernelRow

; -----------------------------------------------------------------------------
; Overscan
; -----------------------------------------------------------------------------
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    LDA SwitchFlag
    BNE SwitchOverscan
    +wait_timer
    JMP StartFrame
SwitchOverscan:
    +wait_timer
    LDA #$00
    STA SwitchFlag
    LDA Bank
    EOR #$01
BankWrite:                  ; checkpoint: A = the new bank (0 or 1)
    STA Bank
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA Bank
    BNE SwitchOne
    JMP $F070
SwitchOne:
    JMP $F060

; -----------------------------------------------------------------------------
; SetCoarseP0
; -----------------------------------------------------------------------------
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

; -----------------------------------------------------------------------------
; Bank 1's data — the forest
; -----------------------------------------------------------------------------
    !if * > ScenePF2 {
        !error "bank 1's code must end before $F200"
    }
    !fill ScenePF2 - *, $EA

; The first eight bytes are blank: the kernel replaces them with the indicator.
    !fill INDICATOR_ROWS, $00
    !fill 24, $FF           ; visible 8-31:  the canopy
    !fill 32, $C3           ; visible 32-63: wide trunks
    !fill 32, $81           ; visible 64-95: thin trunks
    !fill 32, $C3
    !fill 32, $81
    !fill 32, $C3

    !fill SceneColors - *, $EA
    !byte C_FOREST_BG, C_FOREST_PF, C_FOREST_P0
    !byte $01               ; SceneInit: bank 1

    !fill ScenePlayer - *, $EA
    !fill PLAYER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill SCREEN_LINES - PLAYER_TOP - 8, $00

    !fill $FFFA - *, $EA
    * = $FFFA
    !word ForestReset, ForestReset, ForestReset
}
```

<!-- END-FULL-SOURCE -->

> The complete, fully-commented source lives in
> `lessons/part8-advanced/56-bankswitching/56-bankswitching.asm`.

### Code Walkthrough

#### Step 1 — Two banks in one flat file

The first instruction sets the real output address and the virtual program counter:

```asm
    * = $E000
    !pseudopc $F000 {
        ; bank 0: labels are $F000-based, output is $E000-based
    }

    * = $F000
    !pseudopc $F000 {
        ; bank 1: labels and output are both $F000-based
    }
```

`!pseudopc` is the whole trick. Labels inside the block get the virtual address (`$F000`, `$F080`, `$F200`), while the bytes go to the real address (`$E000`, `$E080`, `$E200`). The two blocks therefore define two programs with the same virtual addresses, which is exactly what the mapper presents to the CPU.

#### Step 2 — The reset and the fixed stubs

Each bank's reset starts at `$F000`, runs `+clean_start`, initialises the RAM variables from the bank's own `SceneInit`, loads the palette, sets `CTRLPF` and `SWACNT`, and jumps to `$F080`. The reset must end before `$F060`; the `!if * > $F060` check turns an overflow into a build error, and `!fill $F060 - *, $EA` pads the gap.

The two stubs are the contract:

```asm
Switch1:
    LDA $1FF9
    JMP $F080
    !fill $F070 - *, $EA
Switch0:
    LDA $1FF8
    JMP $F080
    !fill $F080 - *, $EA
```

The same six bytes at `$F060` and `$F070` in both banks. The evidence check compares the two 4K halves at those offsets and finds them identical.

#### Step 3 — The entry and the frame skeleton

`$F080` is the bank's main. The `LDA SceneInit` is three cycles and sets A to the bank number; the `NOP` gives `BankEntry` its own breakpoint address; `StartFrame` is the first instruction of `+vsync`. The frame loop jumps straight to `StartFrame`, so the entry code runs only at power-on and after a switch.

```asm
ForestMain:
    LDA SceneInit           ; A = 1 (bank 1)
BankEntry:
    NOP
StartFrame:
    +vsync
VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
```

The frame is the Part 7 skeleton: three VSYNC lines, 37 VBLANK lines, 192 picture lines, 30 overscan lines. The state log measures `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6.

#### Step 4 — The kernel and the indicator

The kernel is the 1-line loop above. The first eight rows take the indicator branch; the rest are the scene. The branch is deliberately inside the loop rather than a separate eight-line prelude: the 1-line kernel's worst row is a bank-1 indicator row at 40 cycles, leaving 36 (bank 0's indicator row is 37 cycles and a scene row is 31), and the branch keeps the indicator's data out of the scene table (so the exercise's scene swap cannot move the indicator).

The `ScenePlayer` strip is 192 bytes, one `GRP0` byte per line. The shape sits at rows 96–103:

```asm
    !fill PLAYER_TOP, $00
    !byte $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    !fill SCREEN_LINES - PLAYER_TOP - 8, $00
```

The player is positioned once per frame, before the picture:

```asm
    LDA #(PLAYER_X + POS_BIAS)
    JSR SetCoarseP0
    STA WSYNC
    STA HMOVE
```

`SetCoarseP0` is the Lesson 26 routine: a `WSYNC`, a divide-by-15 loop, `HMP0`, and `RESP0`. The `STA HMOVE` is the frame's only HMOVE and it falls inside VBLANK.

#### Step 5 — The switch

The VBLANK block sets `SwitchFlag` on a fire edge or when `BankTimer` reaches zero. The overscan branch chooses the path. The switch path computes the new bank, writes `Bank`, reloads the timer, and jumps to the fixed stub for that bank:

```asm
    LDA Bank
    EOR #$01
BankWrite:
    STA Bank
    LDA #DEMO_PERIOD
    STA BankTimer
    LDA Bank
    BNE SwitchOne
    JMP $F070               ; select bank 0
SwitchOne:
    JMP $F060               ; select bank 1
```

The `JMP $F070`/`JMP $F060` targets are in the *current* bank; the stub's `LDA` selects the other bank, and the stub's `JMP $F080` is fetched from the new bank. The target bank's `$F080` runs `LDA SceneInit`, `BankEntry`, `StartFrame`, and the new frame begins.

#### Step 6 — The data blocks

Everything after `$F1FF` is data. Bank 0's table is the cave: a solid ceiling at visible 8–15, a centre block of `$F0`/`$E0` that splits into the two mirrored walls of `$70`/`$38`/`$1C`/`$0E`, and a solid floor at 184–191. Bank 1's table is the forest: a solid canopy at 8–31 and five 32-line bands of `$C3` (wide trunks) and `$81` (thin trunks). The first eight bytes of both tables are zero; the kernel supplies the indicator.

The two banks' colours and `SceneInit` bytes are the only other differences:

```asm
; bank 0 (cave)
    !byte C_CAVE_BG, C_CAVE_PF, C_CAVE_P0
    !byte $00
; bank 1 (forest)
    !byte C_FOREST_BG, C_FOREST_PF, C_FOREST_P0
    !byte $01
```

Because the VBLANK code reloads `COLUBK`, `COLUPF`, and `COLUP0` every frame from `SceneColors`, the switch's palette change is visible on the first frame in the new bank. The reset loads the same values once, so the first frame after power-on is already in the correct palette.

#### Step 7 — The vectors

Both banks end with the same three words:

```asm
    * = $FFFA
    !word CaveReset, CaveReset, CaveReset   ; bank 0; bank 1 uses ForestReset
```

The addresses are `$F000` in both banks. The NMI and IRQ entries point at the reset as a safe default; the 2600 has no interrupts, so only `$FFFC` is read. The vector must exist in every bank even if the bank is not the start bank, because the console's RESET switch can be pressed while any bank is selected.

## What You Should See

At power-on the screen is the **forest** (bank 1):

- The background is blue `$84`; the playfield is green `$C8`.
- Visible lines 8–31 are a solid green canopy across the playfield's 16-chunk field (pixels 48–111: eight PF2 chunks and their mirror). Lines 32–191 are three green trunks: a left outer trunk, a central trunk, and a right outer trunk. The `$C3` rows are wide (8, 16, and 8 TIA pixels); the `$81` rows narrow to 4, 8, and 4 TIA pixels.
- A white `$0E` 8-line diamond sits at visible 96–103, TIA X 72–79.
- The first eight lines hold the two-cell indicator: bank 1 lights the **left** cell (PF2 `$03`, pixels 48–55 and its mirror 104–111).

After 120 frames (about two seconds), or immediately on fire, the screen switches to the **cave** (bank 0):

- The background is orange `$28`; the playfield is red `$44`.
- Visible lines 8–15 are a solid ceiling. Lines 16–63 are a solid centre block that narrows from 192 to 144 capture pixels (32 to 24 TIA pixels); at 64–183 it splits into two walls that step outward toward the edges; lines 184–191 are a solid floor.
- A gold `$1A` diamond sits at visible 96–103, TIA X 72–79.
- The indicator now lights the **right** cell (PF2 `$30`, pixels 64–71 and its mirror 88–95).

![Stella running the Lesson 56 ROM in bank 1: a blue background, a green canopy and three green trunks, a white eight-line diamond at the centre, and the left bank indicator cell lit at the top; the title bar reads Stella 7.0: "56-bankswitching"](/images/lesson56/bank-1.png)

*`bank-1`: the forest, the F8 start bank. The background is `$84` (capture RGB 36,40,176), the playfield `$C8` (81,179,80), the marker `$0E` (234,234,233). The indicator cells measure x=313–360 and 649–696 in the capture, which are PF2 bits 0–1 and their mirror (TIA pixels 48–55 and 104–111).*

![Stella running the Lesson 56 ROM in bank 0: an orange background, a red cave ceiling and symmetric arch, a gold eight-line diamond at the centre, and the right bank indicator cell lit at the top; the title bar reads Stella 7.0: "56-bankswitching"](/images/lesson56/bank-0.png)

*`bank-0`: the cave, reached by the switch. The background is `$28` (189,134,50), the playfield `$44` (177,40,39), the marker `$1A` (205,205,52). The indicator cells measure x=409–456 and 553–600, which are PF2 bits 4–5 and their mirror (TIA pixels 64–71 and 88–95). Every dominant colour, the indicator position, and the scene geometry changed; only the marker geometry (TIA X 72–79, visible 96–103) is the same.*

<RomPlayer rom="/roms/part8-advanced/56-bankswitching/56-bankswitching.bin" title="Lesson 56 — Bankswitching" />

Javatari starts muted; this ROM is silent, so there is nothing to unmute.

> **Evidence note.** The fire edge is code-reviewed, not logged in this capture run: a fire
> button held from power-on is ignored by the eight-frame startup guard, and the synthetic input
> did not reach Stella in this environment. The auto-demo exercises the same `SwitchFlag` →
> `BankWrite` → trampoline path that fire uses.

> **Capture method.** Both images are window captures of
> `docs/public/roms/part8-advanced/56-bankswitching/56-bankswitching.bin` in Stella 7.0.
> The emulator was launched with a fresh Stella base directory so a local debugger
> configuration could not affect the window; the window is the standard 1010×807 frame,
> title bar included. The pointer was parked at `(0, 0)` before each capture and the
> window captures contain no cursor. The two title bars read
> `Stella 7.0: "56-bankswitching"`.
>
> The auto-demo is 120 frames (about two seconds), so a single 4-second capture can only
> land on one bank and may land on the switch. Stella was launched on the committed ROM and
> a burst of 14 window captures was taken at about 0.45-second intervals, using the same
> `xwininfo` window lookup the screenshot script uses. Each capture was classified by the
> background colour at (60, 300): blue (36,40,176) is bank 1, orange (189,134,50) is bank 0.
> The two images are selected from that burst; the committed ROM still runs the 120-frame
> demo, and no modified ROM was used.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
ROM=docs/public/roms/part8-advanced/56-bankswitching/56-bankswitching.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F084' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F092' $ROM   # VblankStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0F6' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F117' $ROM   # OverscanStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0AE' $ROM   # Frame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F083' $ROM   # BankEntry
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F13D' $ROM   # BankWrite
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F060' $ROM   # SwitchRead1
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F070' $ROM   # SwitchRead0
```

| Checkpoint | Address (bank 1) | Bank 0 twin | Measured | Meaning |
|---|---|---|---|---|
| `StartFrame` | `$F084` | `$F084` | 259/3 steady; 259/39 to bank 0, 259/40 back to bank 1 | the first VSYNC instruction |
| `VblankStart` | `$F092` | `$F092` | 0/5 | the first VBLANK instruction |
| `BodyStart` | `$F0F6` | `$F0F6` | 37/5 | the first visible-line instruction |
| `OverscanStart` | `$F117` | `$F117` | 229/6 | the first overscan instruction |
| `Frame` | `$F0AE` | `$F0AE` | A = 1, 2, 3, … | the new frame count |
| `BankEntry` | `$F083` | `$F083` | A=1 at power-on; A=0 at frame 120 | the bank number at entry |
| `BankWrite` | `$F13D` | `$F13D` | A=0 at frame 120; A=1 at frame 240 | the value written to `Bank` |
| `SwitchRead1` | `$F060` | `$F060` | hit at frame 240, old bank 0 | the `LDA $1FF9` read |
| `SwitchRead0` | `$F070` | `$F070` | hit at frame 120, old bank 1 | the `LDA $1FF8` read |

The state log's frame, scanline, and cycle fields are the evidence:

```text
BP:           0  34 04 -56 | nv-BdIzC 01 ff 00 ff | 1/   # StartFrame, power-on frame
BP:           1 259 03 -59 | nv-BdIZC 00 ff c0 ff | 1/   # StartFrame, steady state
BP:           2 259 03 -59 | nv-BdIZC 00 ff c0 ff | 1/
BP:           1   0 05 -53 | nv-BdIZC 00 ff c0 ff | 1/   # VblankStart
BP:           1  37 05 -53 | nv-BdIZC 00 ff c0 ff | 1/   # BodyStart
BP:           1 229 06 -50 | nv-BdIZC 00 ff c0 ff | 1/   # OverscanStart
BP:           1   0 45  67 | nV-BdIzC 01 ff 00 ff | 1/   # Frame, A=1
BP:           2   0 45  67 | nv-BdIZC 02 ff c0 ff | 1/   # Frame, A=2
BP:           0  34 02 -62 | nv-BdIzC 01 ff 00 ff | 1/   # BankEntry, power-on, A=1
BP:         120 259 37  43 | nv-BdIZC 00 ff c0 ff | 0/   # BankEntry, bank 0, A=0
BP:         240 259 38  46 | nv-BdIZC 01 ff c0 ff | 1/   # BankEntry, bank 1, A=1
BP:         120 259 10 -38 | nv-BdIZC 00 ff c0 ff | 1/   # BankWrite, new bank 0
BP:         240 259 10 -38 | nv-BdIZC 01 ff c0 ff | 0/   # BankWrite, new bank 1
BP:         120 259 26  10 | nv-BdIZC 00 ff c0 ff | 1/   # SwitchRead0, old bank 1
BP:         240 259 27  13 | nv-BdIzC 01 ff c0 ff | 0/   # SwitchRead1, old bank 0
```

The bank field at the end of each line is the selected bank *before* the instruction executes: the `SwitchRead0` line at frame 120 reports bank 1, then the read selects bank 0, and the next `BankEntry` reports bank 0. The pattern is the switch: `BankEntry` A=1 at power-on, A=0 after the first switch, A=1 after the second, and `BankWrite` A=0 then 1.

The two trampolines are byte-for-byte identical in the two 4K halves. The check compares file offsets `$0060–$0065` and `$1060–$1065`, and likewise at `$0070–$0075`/`$1070–$1075`:

```text
$F060 bank 0: AD F9 1F 4C 80 F0
$F060 bank 1: AD F9 1F 4C 80 F0
$F070 bank 0: AD F8 1F 4C 80 F0
$F070 bank 1: AD F8 1F 4C 80 F0
```

The pixel checks decode the captures with `x = 25 + 6 × TIA X` and `y = 107 + 3.229 × visible line`:

| Check | `bank-1.png` | `bank-0.png` | Expected |
|---|---|---|---|
| full image | 1010×807 | 1010×807 | window plus title bar |
| title bar | `Stella 7.0: "56-bankswitching"` | the same | committed ROM |
| background | `$84` (36,40,176) | `$28` (189,134,50) | blue / orange |
| playfield | `$C8` (81,179,80) | `$44` (177,40,39) | green / red |
| marker | `$0E` (234,234,233) | `$1A` (205,205,52) | white / gold |
| indicator cells, visible 0–7 | x=313–360, 649–696 | x=409–456, 553–600 | left cell / right cell |
| scene geometry, visible 8+ | solid 313–696 at row 8; three trunks at 313–360, 457–552, 649–696 at row 32 | solid 313–696 at row 8; centre block 433–576 at row 32; two walls 385–456/553–624 at row 96 | forest / cave |
| marker geometry | x=457–505, rows 96–103 | the same | `PLAYER_X` 72–79 |

The screenshots prove the visual state; the state log proves the values, the lines, and the switch. The two images differ in every dominant colour and in the indicator position; the `BankEntry`/`BankWrite` lines prove the bank really changed.

## Exercises

### Exercise 1: Swap the Scenes

**Challenge:** swap the two worlds. Bank 1 (the start bank) must draw the cave; bank 0 must draw the forest. The start bank stays 1, the code stays the same, and the two-cell indicator must still light the left cell for bank 1 and the right cell for bank 0.

**Hints:**
1. The scenes are data: the 192-byte `ScenePF2` table, the three `SceneColors` bytes, and the `SceneInit` byte. Swap the table and the colours between the two banks; keep `SceneInit` at `$01` in bank 1 and `$00` in bank 0.
2. The player strip is the same in both banks; only `COLUP0` (in `SceneColors`) changes the diamond's colour.
3. Do not swap the indicator patterns: the kernel chooses `$03`/`$30` from `Bank`, so bank 1 keeps the left cell and bank 0 keeps the right cell even after the scenes move.

**Expected Result:** the ROM assembles to 8,192 bytes. At power-on the screen is the cave (orange, red, gold) with the left indicator cell lit; after the switch it is the forest (blue, green, white) with the right cell lit. The frame checkpoints are unchanged. The state log still shows `BankEntry` A=1 at power-on and A=0 after the switch.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: 16K F6, Four Banks

**Challenge:** build a 16,384-byte F6 cartridge with four 4K banks and four scenes. F6 starts in **bank 0**, not bank 1. The hotspots are `$1FF6–$1FF9`; select them with an indexed read, `LDA $1FF6,X`, and keep one trampoline at `$F060`:

```asm
    LDX NextBank
    LDA $1FF6,X
    JMP $F080
```

The four banks must sit at real `$C000`, `$D000`, `$E000`, and `$F000`, each with its own vectors. The scenes are forest (bank 0), cave (bank 1), desert (bank 2), and sea (bank 3); the auto-demo cycles them every 120 frames.

**Hints:**
1. The flat file is bank 0, 1, 2, 3. Use `!pseudopc $F000` inside each block, with `* = $C000`, `$D000`, `$E000`, `$F000` as the real addresses.
2. The trampoline is eight bytes: `LDX NextBank` (two), `LDA $1FF6,X` (three), `JMP $F080` (three). It must be at `$F060` in all four banks and byte-identical; the indexed read at `$F062` is the `SwitchRead` checkpoint.
3. The switch code computes `NextBank = (Bank + 1) AND 3`, writes `Bank`, and jumps to `$F060`. The target's `LDA SceneInit` reloads A with the bank number.
4. The indicator has four cells: PF2 `$03`, `$0C`, `$30`, `$C0` for banks 0–3. The same four bytes sit at `$F1E8` in every bank; the kernel indexes them with `LDX Bank`.
5. The frame skeleton is the lesson's; the four banks can share it through a macro. The `BankEntry`/`StartFrame` addresses stay at `$F083`/`$F084` in every bank.

**Expected Result:** the ROM assembles to exactly 16,384 bytes; Stella reports `F6* (16K)`. At power-on the screen is the forest and `BankEntry` reports A=0; after 120 frames it is the cave (A=1), then the desert (A=2), then the sea (A=3), then the forest again. The four-cell indicator moves one cell per switch. `StartFrame` is 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The Data Bank *(Stretch Goal)*

**Challenge:** split the program so that bank 0 holds the 192-byte `PF2` table and the 1-line kernel that draws it, while bank 1 holds the frame skeleton. Bank 1 must switch to bank 0 for the visible picture, then bank 0 switches back to bank 1 for the overscan. The table is read **directly in bank 0**: there is no 192-byte copy in RIOT RAM.

**Hints:**
1. Bank 1's `$F080` is a dispatcher: `LDA Phase; BNE OverscanMain`. Phase 0 starts the frame (`+vsync`, VBLANK, set the 37-line timer, set Phase=1, `JMP $F070`). Phase 1 runs the overscan after the data bank returns.
2. Bank 0's `$F080` is `DataMain`: load the data colours, `+wait_timer` (bank 1 set the timer), turn the picture on, run the 192-line `LDA DataPF2,Y / STA PF2 / STA WSYNC` loop, then switch back.
3. The switch back must go through the duplicated trampoline at `$F060`. A direct `LDA $1FF9 / JMP $F080` would fetch the `JMP` from bank 1 at an address where bank 1 has different bytes; the trampoline's bytes are identical in both banks, so it is safe.
4. The switch back costs 15 cycles, so bank 1's overscan begins at 229/21 instead of 229/6. Use a 35-tick overscan timer, not 36: the 36-tick timer would expire at 259/0 and the final `WSYNC` would make the frame 263 lines.

**Expected Result:** the ROM assembles to 8,192 bytes. Stella reports `F8* (8K)`. At power-on bank 1 runs the frame skeleton; the visible picture is the red cave on orange, drawn from the table in bank 0. A breakpoint at bank 0's `DataMain` hits at scanline 0 (during VBLANK) and `DataRow` hits in bank 0 at 37/07, 38/07, …; `StartFrame` is 259/3 and `VblankStart` 0/5. The table is read in place; there is no RAM copy.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **The 4K window is a hardware decode, not a software convention.** The 6507 has thirteen address lines; the cartridge sees `$F000–$FFFF` and nothing else. Banking hides more ROM behind the same window.
- ✅ **F8 starts in bank 1 and F6 starts in bank 0.** The reset vector in the start bank is the one the CPU reads at power-on. A bank that is not the start bank still needs a valid vector for a reset while it is selected.
- ✅ **A switch is a read, then a fetch from the new bank.** `LDA $1FF9` selects bank 1; the next instruction fetch comes from bank 1. The duplicated stub at `$F060`/`$F070` makes those bytes identical in every bank, and `$F080` is the same target in every bank.
- ✅ **The mapper chain is thirteen cycles; the full switch path is 39/40 cycles, not a context switch.** There is no interrupt, no register save, and no return path. The path is 36/37 cycles longer than the ordinary frame loop, and the lesson spends it in the blanked overscan; the `+vsync` `WSYNC`s absorb it before `VblankStart`.
- ✅ **Code and data banks are a placement decision.** Keep the reader and the table on the same side, or switch to the data bank, draw, and switch back. The table never has to move to RAM.
- ✅ **The frame does not change when the bank does.** Both banks run the same 3 + 37 + 192 + 30 skeleton, and the state log stays at `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6 on ordinary frames.
- ✅ **The indicator follows the bank number, not the scene.** The kernel chooses the cell from `Bank`, so a scene swap (exercise 1) cannot make the indicator lie.

## What's Next

The F8 mapper adds ROM but not RAM. [Lesson 57: Superchip — Extra RAM](/part8-advanced/57-superchip) keeps the same two-bank F8 structure and adds 128 bytes of cartridge RAM: a write window at `$1000–$107F`, a read window at `$1080–$10FF`, the duplicated signature that lets Stella detect the mapper, and code that starts at `$F100` because the first 256 bytes of each bank hold the signature; the RAM window is `$1000–$107F` write / `$1080–$10FF` read.
