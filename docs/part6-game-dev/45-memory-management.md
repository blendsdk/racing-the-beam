---
title: "Lesson 45: Memory Management — 128 Bytes of Creativity"
description: "A 16×8 grid drawn by the playfield turns the 2600's 128 bytes of RAM into a visible budget: a static map table, four flag cells, a nibble-packed timer, a fifteen-byte display buffer, and an ACME !if assert that stops the build before a variable can touch the stack."
prev:
  text: "Lesson 44: AI & Enemy Behavior — Chase, Patrol, Flee"
  link: "/part6-game-dev/44-ai-enemy-behavior"
next:
  text: "Lesson 46: Debugging — Finding and Fixing Bugs"
  link: "/part6-game-dev/46-debugging"
---

# Lesson 45: Memory Management — 128 Bytes of Creativity

> **Part 6: Game Development** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 09 (bitwise operations), Lesson 11 (lookup tables), Lesson 19 (the playfield), Lesson 27 (joystick input), Lesson 34 (frame counters), Lesson 41 (state layouts)
> **You will learn:** how the 128 bytes at `$80–$FF` become a plan; how the playfield draws a 16×8 bitmap of that plan in chunks 2–17; how a static 8×3 table encodes one bit per RAM byte; how four flag bytes pack into one `Flags` byte; how one timer byte holds a 16-frame tick counter and a frame counter in its two nibbles; how a fifteen-byte display buffer buys kernel cycles; how an ACME `!if` turns the RAM budget into a build-time check; why the stack owns `$F8–$FF`
> **You will build:** "the memory map" — a 16×8 grid of the 128 RAM bytes (lit = used), a four-cell flags row, a fifteen-cell timer bar, a two-byte beep, and an auto-demo that needs no controller; plus three exercises: packed flags, a title/play state overlay, and a `RamEnd` budget assert

## Introduction

Lesson 44 gave the enemy a brain: a state byte, a position, a patrol direction, a flee timer, a
distance, three lives, an invulnerability count, and a collision latch. Every one of those
features asked for RAM, and the list was already longer than the bytes the early lessons used.
The Atari 2600 has **128 bytes** of writable memory, at `$80–$FF`, and no operating system to
ask for more. A game that spends them one variable at a time eventually finds the stack sitting
on top of a timer.

This lesson makes the budget visible. The companion program `45-memory-management.asm` draws
the whole RAM map as a **16×8 grid** using the playfield: each of the 128 cells is one byte, a
lit cell is a byte the plan has spent, and a dark cell is free. Above the grid, four cells show
the fire, left, right, and overflow flags. Below it, a fifteen-cell bar shows a timer that is
packed into a single byte: the high nibble counts 16-frame ticks, the low nibble counts frames.
The playfield is mirrored, so the same map appears twice; the left half is the reference and the
right half is its mirror image. A static 24-byte table in ROM, `RamMap`, holds the picture, and
a reset-time routine counts the free cells so the program knows its own budget.

The last piece is the one that saves the project: a `RamEnd` label at the highest used address
and an ACME `!if` that stops the build when the plan reaches into the stack. The exercises put
the ideas to work: pack the four flag bytes into one, overlay the title and play states, and add
the budget assert that fails the build — not the game — when a variable moves to `$F8`.

::: details TypeScript Equivalent
A memory map in TypeScript is an array of flags, and a packed byte is a small integer. The
shapes transfer; the sizes do not:

```typescript
class RamMap {
  // 128 entries, one per byte at $80-$FF. In JavaScript each entry is a
  // value, not a bit: this array is far larger than 128 bytes.
  private readonly used = new Array<boolean>(128).fill(false);

  mark(address: number): void {
    this.used[address - 0x80] = true;
  }

  free(): number {
    return this.used.filter((u) => !u).length;
  }
}

type Flags = { fire: boolean; left: boolean; right: boolean; over: boolean };

function packFlags(f: Flags): number {
  return (f.fire ? 1 : 0) | (f.left ? 2 : 0) | (f.right ? 4 : 0) | (f.over ? 8 : 0);
}

function unpackFire(packed: number): boolean {
  return (packed & 1) !== 0;          // every reader pays a mask
}
```

The analogy breaks in four places. A JavaScript boolean is not a bit: the 128-entry array costs
hundreds of bytes, while the 2600 map costs 24 bytes in ROM and none in RAM. There is no
allocator on the 2600 and no pointer arithmetic worth the cycles: addresses are labels fixed at
assembly time. The mirror is not a second array — it is the TIA reflecting the same twenty
playfield bits, for free. And the budget check is not a runtime `if`: `!if` runs while ACME
assembles, when you can still move the variable, not on the console after the stack has already
been overwritten.
:::

## Theory

### Section 1: One Hundred and Twenty-Eight Bytes

The RIOT (6532) gives the console 128 bytes of RAM at `$80–$FF`. That is the whole writable
memory: no heap, no allocator, no file system, no BIOS. The 6502's stack pointer starts wherever
the program puts it, and the stack lives in page `$01`, which **mirrors the same physical RAM**.
A push at `$01FF` writes the byte at `$FF`; a deep call chain is therefore a memory-corruption
bug waiting to happen. `+clean_start` sets `SP=$FF`, so the stack grows down from the top of the
same 128 bytes the game uses for variables.

This is why a memory map is not bookkeeping. Every variable, buffer, and saved byte has to be
chosen before the code is written, and the choice has to leave room for the stack. The map in
this lesson is a **plan**: a lit cell means the plan has spent that byte, not that this frame
wrote it. The distinction matters for the scoreboard reservation in Section 4 — the space is
spoken for even though this lab never fills it.

There is a second reason to draw the map. A list of addresses in a comment is easy to write and
easy to let drift. A picture that the ROM itself draws from a static table is checked every time
you run it: if the table and the labels disagree, the screen shows the disagreement. The map
does not enforce the plan, but it makes a wrong plan visible.

::: tip The stack is not a separate memory
`$0100–$01FF` and `$80–$FF` are the same 128 bytes seen through two addresses. A `JSR` pushes
two bytes; an interrupt pushes three. The stack reserve in this lesson is `$F8–$FF`, eight bytes,
because the deepest call path is `Reset → CountFree → CountBits`, two return addresses (four
bytes), and the VBLANK path is one `JSR BeepStart`. Eight bytes leave room for a debugger and for
the next feature. If you add a third nested call, check the reserve before you add a variable.
:::

### Section 2: The Playfield as a Bitmap

The TIA's playfield is **twenty bits per half**, and each bit is four color clocks wide. On the
visible 160-pixel line, the left half of the playfield covers X=0–79 and the right half covers
X=80–159. The bits are not in address order, which is the classic playfield trap:

| Register | Bits used | Screen order |
|---|---|---|
| `PF0` | 4–7 | bit 4 is the leftmost pixel |
| `PF1` | 7–0 | bit 7 is the leftmost pixel |
| `PF2` | 0–7 | bit 0 is the leftmost pixel |

The grid needs **sixteen columns per half**, not twenty. It uses chunks 2–17, which leaves an
eight-pixel margin at each edge and a sixteen-pixel gap in the middle. The mapping from a cell
number to a playfield bit is:

| Cell | Register bit | Chunk | TIA X |
|---|---|---|---|
| 0 | `PF0` bit 6 | 2 | 8–11 |
| 1 | `PF0` bit 7 | 3 | 12–15 |
| 2–9 | `PF1` bits 7–0 | 4–11 | 16–47 |
| 10–15 | `PF2` bits 0–5 | 12–17 | 48–71 |

`CTRLPF=$01` sets the reflect bit, so the right half is the **mirror image** of the left: cell 0
appears at X=148–151, cell 15 at X=88–91. The right half is not a second copy of the map; it is
the same twenty bits reflected by the TIA. To read the right half, start at the centre and walk
outward — the cell order is reversed.

Eight rows of four scanlines each make the grid 32 lines tall, visible 8–39. Each cell is a
4×4-pixel block (24×12.6 capture pixels). Adjacent used cells merge into bars, because playfield
pixels have no gaps; the grid is a bitmap, not a table with borders. Read a row by its **length
and offset**, not by looking for cell edges: row 1 of this map is a two-cell bar at the left,
row 5 is an eight-cell bar at the left, and row 6 is an eight-cell bar that starts at cell 8.

### Section 3: The Static Map Table

`RamMap` is 24 bytes in ROM: eight rows, three playfield bytes per row. Each bit is one RAM
byte. The kernel reads the three bytes of a row and stores them; the TIA does the rest.

| Row | Addresses | `PF0` | `PF1` | `PF2` | Cells used |
|---|---|---|---|---|---|
| 0 | `$80–$8F` | `$C0` | `$FF` | `$3F` | 16 |
| 1 | `$90–$9F` | `$C0` | `$00` | `$00` | 2 |
| 2 | `$A0–$AF` | `$C0` | `$FF` | `$3F` | 16 |
| 3 | `$B0–$BF` | `$C0` | `$FF` | `$3F` | 16 |
| 4 | `$C0–$CF` | `$C0` | `$FF` | `$3F` | 16 |
| 5 | `$D0–$DF` | `$C0` | `$FC` | `$00` | 8 |
| 6 | `$E0–$EF` | `$00` | `$03` | `$3F` | 8 |
| 7 | `$F0–$FF` | `$C0` | `$FF` | `$3F` | 16 |

Why a static table and not a runtime builder? Because the map is constant, and the 2600 has no
spare RAM to build it in. A builder would need a 24-byte buffer to produce 24 bytes that already
exist in ROM; it would cost more than it saves. The table is hand-written from the allocation in
the next section, and the labels in the source are the code's view of the same plan. When the
allocation changes, the table changes with it — that is the maintenance cost, and the picture is
the reminder.

```asm
MapRow:
    LDA RamMap+0,X
MapDraw:                    ; checkpoint: A = the row's PF0 byte
    STA PF0
    LDA RamMap+1,X
    STA PF1
    LDA RamMap+2,X
    STA PF2
    TXA
    CLC
    ADC #$03
    TAX                     ; X = the next row's table index (or 24)
    LDY #4
MapLine:
    STA WSYNC
    DEY
    BNE MapLine
    CPX #24
    BNE MapRow
```

The `X` arithmetic runs **before** the four `WSYNC`s. That is deliberate: it keeps the row
transition to the `DEY`/`BNE` loop exit plus `CPX`/`BNE`, so rows 1–7 complete `PF0` at cycle 15,
`PF1` at 22, and `PF2` at 29. Row 0 is two cycles later (17/24/31) because the flags-row exit and
the colour setup come before it. The playfield slots close at about 22.7, 28, and 38.7, so PF0
keeps about eight cycles of margin. Moving the arithmetic after the `WSYNC`s adds its eight
cycles and lands PF0 at the slot boundary; only moving the entire control block past the slot
would shift a row by one cell.

### Section 4: The Plan the Map Draws

The map lights 98 bytes and leaves 30 free. The exact plan is the source's allocation block:

| Range | Bytes | Owner |
|---|---|---|
| `$80–$91` | 18 | 16 lesson variables (frame counter, flags, packed timer, beep, auto-demo, flags-row bytes, free count) + 2 reserved scratch bytes at `$8D–$8E` |
| `$92–$9F` | 14 | free |
| `$A0–$D7` | 56 | the game plan's scoreboard reservation (Lesson 39 layout) |
| `$D8–$E7` | 16 | free |
| `$E8–$F6` | 15 | `BarBuf`: one display byte per timer cell |
| `$F7` | 1 | `BarLevel`: the bar height, the highest used address |
| `$F8–$FF` | 8 | the stack reserve |

The 18-byte block is sixteen cells in row 0 and two in row 1. Row 0 holds fourteen variables plus
the reserved `Scratch0`/`Scratch1` pair at `$8D–$8E`; row 1 holds `FlagPF1` and `FreeCount`. The
scratch pair has no writer in this lab, but it has an owner and a name, so no cell is anonymous;
a future two-byte value can take the space without changing the map.

The scoreboard block is the most interesting line. Lesson 39 built a six-digit score in 48
pixels with six digit bytes, two scratch bytes, and a 48-byte glyph buffer at `$A8–$D7`. This
lab does not include `include/score.asm` and never draws a score, but the finished game's plan
spends those 56 bytes, so the map marks them used. That is what a memory map is for: deciding
today where tomorrow's buffer lives. A reservation you never fill is still a budget line.

The stack is the other reserved block. The lesson uses only two nested calls, but the reserve is
eight bytes because the stack grows down into the same RAM and a future change should not silently
eat the top of the map. The `RamEnd` label and the exercise-3 assert turn that intention into a
build-time check.

### Section 5: Four Flags, One Byte

The flags row has four cells: fire, left, right, and overflow. The main ROM keeps four separate
bytes, one per cell, and the flags row reads them directly:

- `FlagFire` → `PF0` bit 6 (chunk 2, X=8–11)
- `FlagLeft` → `PF0` bit 7 (chunk 3, X=12–15)
- `FlagRight` → `PF1` bit 7 (chunk 4, X=16–19)
- `FlagOver` → `PF1` bit 6 (chunk 5, X=20–23)

Exercise 1 replaces the four bytes with one `Flags` byte:

```
bit 0 = fire    bit 1 = left    bit 2 = right    bit 3 = over
```

The saving is three bytes — three dark cells in the map's top row. The cost is that every reader
now pays a mask or a shift. The flags row turns the byte into two playfield bytes with two
four-entry tables:

```asm
    LDA Flags
FlagsWrite:                 ; checkpoint: A = the packed flags byte
    AND #$03
    TAX
    LDA FlagPF0Table,X      ; fire | left  -> PF0
    STA FlagPF0
    LDA Flags
    LSR
    LSR
    AND #$03
    TAX
    LDA FlagPF1Table,X      ; right | over -> PF1
    STA FlagPF1
```

Packing is a budget decision, not a default. Three bytes matter when the map is full; when they
do not, four named bytes are easier to read. The exercise makes the trade explicit: the map loses
three cells, and the flags row gains two tables.

### Section 6: The Timer in One Byte

`PackedTimer` is one byte with two counters: the high nibble counts **16-frame ticks**, the low
nibble counts **frames since the last tick**. `INC` does the carry for free:

| Value | Meaning |
|---|---|
| `$00` | tick 0, frame 0 |
| `$01` | tick 0, frame 1 |
| `$0F` | tick 0, frame 15 |
| `$10` | tick 1, frame 0 — the low nibble wrapped and incremented the high nibble |
| `$F0` | tick 15, frame 0 — 240 frames, the round is full |

The bar's height is `PackedTimer >> 4`, four `LSR`s in VBLANK. Fifteen cells of six lines make
ninety lines, visible 40–129; cell 0 is the bottom and a cell is lit when its index is below the
height. The timer runs at 60 frames per second, so 240 frames is about four seconds. The high
nibble is **not** seconds: it is a count of sixteen-frame ticks. The bar's top cell is height 15;
values `$F0–$FF` would all show it, but this timer stops at `$F0` and never runs into `$F1–$FF`.

The kernel reads the fifteen cell bytes from `BarBuf` at `$E8–$F6`. That is a real display
buffer: fifteen bytes bought to replace the per-cell compare/branch/select (about twelve or
thirteen cycles) with a four-cycle `LDA BarBuf,X` and a three-cycle `STA` — seven cycles of
per-cell work instead of the Lesson 43 shape. The alternative is to compare each cell's index
with `BarLevel` inside the kernel, as Lesson 43 does for its meter. Both are correct; the buffer
is the trade this lesson's map is wide enough to afford, and it is also the reason `$F7` is the
last used byte. A display buffer is a budget line like any other.

At `$F0` the round is full: `FlagOver` latches, the beep sounds, and the timer stops. Fire
restarts the round on the 0→1 edge, clearing `FlagOver` and resetting `PackedTimer` to zero.

### Section 7: The Stack Reserve and the Budget Assert

The source labels the highest used address:

```asm
BarLevel     = $F7   ; the bar height, PackedTimer >> 4 (0-15)
RamEnd       = BarLevel   ; the highest used address ($F7)
```

Exercise 3 adds the check:

```asm
!if RamEnd > $F7 {
    !error "RAM budget exceeded"
}
```

`!if` is an **assembly-time** directive. It runs inside ACME while the source is being
translated, before a single ROM byte is written. If `RamEnd` is `$F8` or higher, the assembler
prints the error and exits with a failure; no ROM is produced. That is the right time to catch
the mistake: the plan is static, and the build is where you can still move a variable.

The check is only as strong as the label it reads. `RamEnd` must name the **highest used byte**.
If you add a variable above it, extend `RamEnd` to the new variable; the assert will then tell
you whether the plan still fits. Exercise 2 uses the same tool for a different promise: its
`!if` checks that the title and play aliases really land on the same addresses, so an overlay
cannot drift into two copies.

### Section 8: The Layout, the Frame, and the Auto-Demo

The visible picture is four zones that total 192 lines:

| Lines | Lines tall | Content |
|---|---|---|
| 0–7 | 8 | flags row |
| 8–39 | 32 | 16×8 memory grid |
| 40–129 | 90 | fifteen timer cells of six lines |
| 130–191 | 62 | background |

The frame is the standard 262 lines: 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan.
`StartFrame` is scanline 259, `VblankStart` 0, `BodyStart` 37, `OverscanStart` 229. The kernel
is **work-first**: write the line's registers, then `STA WSYNC`. There are no sprites and no
`HMOVE`; the playfield and the background are the whole picture.

The tightest timing is the first line of each zone. The flags row's `BodyStart` is at cycle 5,
so its `PF0` store completes at cycle 15, `PF1` at 21, and `PF2` at 26 — before PF0's slot at
about 22.7. The map's first row completes `PF0` at cycle 17, `PF1` at 24, and `PF2` at 31; rows
1–7 are two cycles earlier (15/22/29) because the flags-row exit and the colour setup are out of
the way. The meter's first line preloads the top cell's `PF1` byte at cycle 14, before the loop
repeats the same byte; the repeat cannot change the picture because it is the same value.

The auto-demo makes the screen move without a controller. `DemoStep` cycles 0–3 every 64 frames;
the left flag is set in phases 0 and 2, the right flag in phases 1 and 2. Fire is left to the
player: the demo never restarts the timer, so the round fills, raises `FlagOver`, and waits for a
fire press. The real input is ORed with the demo, so pressing a direction adds its cell instead
of fighting the demo.

| Input | Effect |
|---|---|
| Fire (held) | `FlagFire` = 1; on the 0→1 edge, reset `PackedTimer` and clear `FlagOver` |
| Joystick left | `FlagLeft` = 1 (ORed with the demo) |
| Joystick right | `FlagRight` = 1 (ORed with the demo) |
| No input | the demo alternates the left and right cells every 64 frames |
| Timer reaches `$F0` | `FlagOver` = 1, the beep sounds, the timer stops |

The beep is the same two-byte pattern as Lessons 38–44: `BeepTimer` and `BeepPitch`. On the
overflow frame, `BeepStart` writes `AUDC0=$0C`, `AUDF0=$0C`, `AUDV0=$0A`, and reloads the timer
with 2; the VBLANK clock silences channel 0 two frames later.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson45.bin \
  lessons/part6-game-dev/45-memory-management/45-memory-management.asm
stella build/lesson45.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.
The shared includes are `include/vcs.asm` (register addresses) and `include/macro.asm`
(`+clean_start`, `+vsync`, `+set_timer`, `+wait_timer`). There is no lesson library to source:
the map table, the timer, and the beep are all in the lesson file.

### Full Source

The complete annotated source:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 45: Memory Management — 128 Bytes of Creativity — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; What this program does:
;   "the memory map": the 128 bytes of RAM at $80-$FF drawn as a 16x8 grid.
;   A lit cell is a byte the game's plan has spent; a dark cell is free.  The
;   playfield is mirrored, so the left half is the reference map and the right
;   half is the same 128 bytes mirrored.  A four-cell flags row sits above the
;   grid and a fifteen-cell timer bar below it.
;
; The screen (192 visible lines, CTRLPF=$01 mirrors the playfield):
;   visible 0-7     flags row: four cells at chunks 2-5 (X=8-23), one per
;                   byte FlagFire, FlagLeft, FlagRight, FlagOver.  A set byte
;                   lights its cell; the mirror copy is at X=136-151.
;   visible 8-39    memory grid: eight rows of four lines.  Row 0 is the top
;                   and holds $80-$8F; row 7 is the bottom and holds $F0-$FF.
;                   Within a row, cell 0 (leftmost) is the lowest address.
;                   The 16 cells come from PF0 bits 6-7, PF1 bits 7-0 and
;                   PF2 bits 0-5 (chunks 2-17, X=8-71); CTRLPF mirrors them at
;                   X=88-151.  Green $C8 = used, background $02 = free.
;   visible 40-129  timer bar: fifteen cells of six lines at chunk 6 (X=24-27,
;                   PF1=$20).  The height is PackedTimer >> 4: the high nibble
;                   counts 16-frame ticks and the low nibble frames.  The bar
;                   is full after 240 frames (PackedTimer = $F0); the mirror
;                   copy is at X=132-135.
;   visible 130-191 background.
;   The zones total 8 + 32 + 90 + 62 = 192 lines; OverscanStart is scanline 229.
;
; The map table:
;   RamMap is a static table of eight rows x three playfield bytes (24 bytes),
;   one bit per byte in $80-$FF.  It is written by hand from the allocation
;   below; the kernel reads the three bytes of a row and stores them.  At
;   reset, CountFree walks the table once and computes the free-byte count.
;
; RAM allocation (the plan the map draws):
;   $80-$91  lesson variables (frame counter, flags, timer, beep, the
;            auto-demo, the flags row's precomputed bytes, the free count)
;            plus two reserved scratch bytes at $8D-$8E; the sixteen variables
;            and two reserved bytes make the eighteen lit bytes of $80-$91
;            (sixteen in row 0, two in row 1)
;   $92-$9F  free (14 bytes)
;   $A0-$D7  the game plan's scoreboard reservation (56 bytes: six digits,
;            two scratch bytes, and a 48-byte glyph buffer -- the Lesson 39
;            layout).  This lab does not call include/score.asm; the map
;            marks the reservation because the plan has spent the space.
;   $D8-$E7  free (16 bytes)
;   $E8-$F6  BarBuf: the fifteen timer-bar cell bytes, one per cell
;   $F7      BarLevel: PackedTimer >> 4, the bar height (0-15)
;   $F8-$FF  stack (+clean_start sets SP=$FF; keep the call depth shallow)
;
;   RamEnd is BarLevel at $F7, the highest used address.  Exercise 3 adds the
;   assembly-time check that fails if the label moves past $F7.
;
; The controls:
;   Fire restarts the timer (on the 0 -> 1 edge); joystick left/right set
;   their flags.  With no input the auto-demo advances DemoStep every 64
;   frames and alternates the left and right flags, so the screen changes by
;   itself.  The timer stops at $F0 and raises FlagOver; fire starts a new
;   round.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), FireRead (A = INPT4), FreeBytes (A =
;   the computed free-byte count), PackTimer (A = the packed timer byte),
;   MapDraw (A = row 0's PF0 byte, $C0), BodyStart (37), OverscanStart (229).
;   This is a playfield-only lesson: there are no sprites, so there is no
;   HMOVE in this ROM.
;
; Build: acme -f plain -o build/lesson45.bin \
;        lessons/part6-game-dev/45-memory-management/45-memory-management.asm
; Run:   stella build/lesson45.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

TIMER_FULL     = $F0     ; 240 frames: 15 ticks of 16 frames
BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $0C     ; AUDF 12 on AUDC $0C: a low, short beep

DEMO_FRAMES    = 64      ; the auto-demo changes phase every 64 frames

BAR_CELLS      = 15      ; the timer shows a nibble: 0-15 lit cells
BAR_LINES      = 6       ; six visible lines per cell
BAR_CHUNK      = $20     ; PF1 bit 5 = chunk 6 = X=24-27

FLAG_FIRE_PF0  = $40     ; PF0 bit 6 = chunk 2 = X=8-11
FLAG_LEFT_PF0  = $80     ; PF0 bit 7 = chunk 3 = X=12-15
FLAG_RIGHT_PF1 = $80     ; PF1 bit 7 = chunk 4 = X=16-19
FLAG_OVER_PF1  = $40     ; PF1 bit 6 = chunk 5 = X=20-23

C_GOLD         = $1A
C_GREEN        = $C8
C_BG           = $02

; =============================================================================
; RAM ALLOCATION — the plan the RamMap table draws
; =============================================================================
; Every address is explicit: the map table below is the reference, and these
; labels are the code's view of the same plan.  Add a variable only by taking
; a byte from a free row and lighting its cell in RamMap.

; --- $80-$91: lesson variables ---------------------------------------------
FrameLo      = $80   ; 16-bit frame counter, low byte
FrameHi      = $81   ; frame counter, high byte
PrevFire     = $82   ; fire state last frame (1 = pressed)
NewFire      = $83   ; this frame's fire 0 -> 1 edge
FlagFire     = $84   ; flags row cell 0: fire is held
FlagLeft     = $85   ; flags row cell 1: joystick left is held
FlagRight    = $86   ; flags row cell 2: joystick right is held
FlagOver     = $87   ; flags row cell 3: the 240-frame timer finished
PackedTimer  = $88   ; high nibble = 16-frame ticks, low nibble = frames
BeepTimer    = $89   ; frames of beep remaining
BeepPitch    = $8A   ; AUDF for the beep
DemoHold     = $8B   ; frames until the next auto-demo phase
DemoStep     = $8C   ; auto-demo phase, 0-3
Scratch0     = $8D   ; reserved scratch, $8D-$8E (not written by this ROM)
Scratch1     = $8E
FlagPF0      = $8F   ; the flags row's PF0 byte, precomputed in VBLANK
FlagPF1      = $90   ; the flags row's PF1 byte, precomputed in VBLANK
FreeCount    = $91   ; the computed free-byte count (128 - used)

; $92-$9F are free (14 bytes).  The auto-demo tables are in ROM.

; --- $A0-$D7: the scoreboard reservation ------------------------------------
; The finished game's plan spends these 56 bytes on the Lesson 39 scoreboard:
; six digit bytes, two scratch bytes, and a 48-byte glyph buffer.  This lab
; does not source include/score.asm, so nothing here is read or written; the
; reservation is a budget line, and the map marks a budget line as used.

; --- $D8-$E7: free (16 bytes) ----------------------------------------------

; --- $E8-$F7: the timer bar's block ----------------------------------------
BarBuf       = $E8   ; fifteen cell bytes: $20 = lit, $00 = dark ($E8-$F6)
BarLevel     = $F7   ; the bar height, PackedTimer >> 4 (0-15)
RamEnd       = BarLevel   ; the highest used address ($F7)

; --- $F8-$FF: the stack ----------------------------------------------------
; +clean_start sets SP=$FF; every JSR and interrupt push grows down from $FF.
; The lesson keeps its call depth to two levels, so eight bytes are enough.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #C_BG
    STA COLUBK              ; the free cells and the background are $02
    LDA #$01
    STA CTRLPF              ; mirror the playfield; ball one pixel wide

; --- the map is static, but the free-byte count is computed once -----------
; CountFree walks the 24-byte table, counts the used bits (PF0 bits 6-7,
; PF1 bits 0-7, PF2 bits 0-5), and returns 128 - used.  It runs before the
; first frame, where no timing budget applies.
    JSR CountFree
FreeBytes:                  ; checkpoint: A = the computed free-byte count
    STA FreeCount

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; 1. THE FRAME COUNTER
; -----------------------------------------------------------------------------
    INC FrameLo
    BNE FrameCounted
    INC FrameHi
FrameCounted:

; -----------------------------------------------------------------------------
; 2. THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0               ; silence at the end of the tick
BeepClockDone:

; -----------------------------------------------------------------------------
; 3. INPUT — three level flags, active low
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  SWCHA bit 6 is P0 left and bit 7 is
; P0 right, also active low.  Each flag byte is 0 or 1: the flags row turns
; the byte into a playfield cell, and the exercises pack the bytes.
    LDA #$00
    STA FlagFire
    LDA INPT4
FireRead:                   ; checkpoint: A = INPT4 (bit 7 = 0 while pressed)
    AND #$80
    BNE FireReadDone
    LDA #$01
    STA FlagFire
FireReadDone:

    LDA #$00
    STA FlagLeft
    LDA SWCHA
    AND #$40                ; P0 left
    BNE LeftReadDone
    LDA #$01
    STA FlagLeft
LeftReadDone:

    LDA #$00
    STA FlagRight
    LDA SWCHA
    AND #$80                ; P0 right
    BNE RightReadDone
    LDA #$01
    STA FlagRight
RightReadDone:

; -----------------------------------------------------------------------------
; 4. THE AUTO-DEMO — a changing screen without a controller
; -----------------------------------------------------------------------------
; DemoStep cycles 0,1,2,3 every 64 frames.  The left flag is set in phases 0
; and 2, the right flag in phases 1 and 2.  The demo's flags are ORed with
; the real input, so pressing a direction adds its cell instead of fighting
; the demo.  Fire is left to the player: the demo never restarts the timer.
    INC DemoHold
    LDA DemoHold
    CMP #DEMO_FRAMES
    BCC DemoStepDone
    LDA #$00
    STA DemoHold
    LDA DemoStep
    CLC
    ADC #$01
    AND #$03
    STA DemoStep
DemoStepDone:
    LDX DemoStep
    LDA DemoLeftTable,X
    ORA FlagLeft
    STA FlagLeft
    LDA DemoRightTable,X
    ORA FlagRight
    STA FlagRight

; -----------------------------------------------------------------------------
; 5. THE FIRE EDGE AND THE ROUND RESTART
; -----------------------------------------------------------------------------
; A held fire keeps FlagFire lit, but the restart happens only on the 0 -> 1
; edge: EOR with last frame's value keeps the bits that changed, and AND with
; this frame's value keeps the ones that changed to 1.
    LDA FlagFire
    EOR PrevFire
    AND FlagFire
    STA NewFire
    LDA FlagFire
    STA PrevFire

    LDA NewFire
    BEQ NoRestart
    LDA #$00
    STA PackedTimer
    STA FlagOver
NoRestart:

; -----------------------------------------------------------------------------
; 6. THE PACKED TIMER — one byte, two counters
; -----------------------------------------------------------------------------
; INC adds one to the low nibble, and binary carry does the rest: $0F + 1 =
; $10 (one 16-frame tick, zero frames), $1F + 1 = $20, and so on.  The high
; nibble is the bar's height.  At $F0 (240 frames) the round is full: FlagOver
; latches and the beep sounds.  Fire clears both and starts again.
    LDA FlagOver
    BNE TimerDone
    INC PackedTimer
    LDA PackedTimer
PackTimer:                  ; checkpoint: A = the packed byte, before the test
    CMP #TIMER_FULL
    BNE TimerDone
    LDA #$01
    STA FlagOver
    JSR BeepStart
TimerDone:

; -----------------------------------------------------------------------------
; 7. THE BAR'S HEIGHT AND ITS FIFTEEN DISPLAY BYTES
; -----------------------------------------------------------------------------
; Four LSRs divide by 16.  Cell 0 is the bottom cell; a cell is lit when its
; index is below the height, so the bar grows from the bottom.  Precomputing
; the fifteen bytes in VBLANK replaces the per-cell compare/branch/select
; (about twelve or thirteen cycles) with a four-cycle load and a store:
; seven cycles of per-cell work instead of the Lesson 43 shape.
    LDA PackedTimer
    LSR
    LSR
    LSR
    LSR
    STA BarLevel
    LDX #$00
FillBar:
    CPX BarLevel
    LDA #$00
    BCS FillBarDark         ; X >= height: this cell is dark
    LDA #BAR_CHUNK          ; chunk 6: X=24-27
FillBarDark:
    STA BarBuf,X
    INX
    CPX #BAR_CELLS
    BNE FillBar

; -----------------------------------------------------------------------------
; 8. THE FLAGS ROW'S TWO PLAYFIELD BYTES
; -----------------------------------------------------------------------------
; The four separate flag bytes are read directly: fire and left share PF0
; (bits 6 and 7), right and over share PF1 (bits 7 and 6).  Exercise 1
; replaces this block with two lookups into a packed Flags byte.
    LDA #$00
    STA FlagPF0
    STA FlagPF1
    LDA FlagFire
    BEQ FireCellDone
    LDA #FLAG_FIRE_PF0
    STA FlagPF0
FireCellDone:
    LDA FlagLeft
    BEQ LeftCellDone
    LDA FlagPF0
    ORA #FLAG_LEFT_PF0
    STA FlagPF0
LeftCellDone:
    LDA FlagRight
    BEQ RightCellDone
    LDA #FLAG_RIGHT_PF1
    STA FlagPF1
RightCellDone:
    LDA FlagOver
    BEQ OverCellDone
    LDA FlagPF1
    ORA #FLAG_OVER_PF1
    STA FlagPF1
OverCellDone:

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- visible 0-7: the flags row --------------------------------------------
; BodyStart is scanline 37, cycle 5, so the first line's PF0 store completes
; at cycle 15, PF1 at 21 and PF2 at 26 -- before the playfield's first slots
; (~22.7 for PF0).  The eight lines then hold the same bytes.
    LDA #C_GOLD
    STA COLUPF
    LDA FlagPF0
    STA PF0
    LDA FlagPF1
    STA PF1
    LDA #$00
    STA PF2
    LDY #8
FlagsRow:
    STA WSYNC
    DEY
    BNE FlagsRow

; --- visible 8-39: the 16x8 memory grid, eight rows of four lines ----------
; Each row reads three bytes from RamMap and writes PF0/PF1/PF2.  The X
; arithmetic advances to the next row *before* the four WSYNCs, so the row
; transition is the DEY/BNE loop exit plus CPX/BNE.  Rows 1-7 complete PF0 at
; cycle 15, PF1 at 22 and PF2 at 29; row 0 is two cycles later (17/24/31)
; because the flags-row exit and the colour setup precede it.  The slots close
; at about 22.7, 28 and 38.7, so PF0 keeps about eight cycles of margin.
    LDA #C_GREEN
    STA COLUPF
    LDX #$00
MapRow:
    LDA RamMap+0,X
MapDraw:                    ; checkpoint: A = the row's PF0 byte
    STA PF0
    LDA RamMap+1,X
    STA PF1
    LDA RamMap+2,X
    STA PF2
    TXA
    CLC
    ADC #$03
    TAX                     ; X = the next row's table index (or 24)
    LDY #4
MapLine:
    STA WSYNC
    DEY
    BNE MapLine
    CPX #24
    BNE MapRow

; --- visible 40-129: the timer bar, fifteen cells of six lines -------------
; The last map row ends at line 39; the preload below writes the top cell's
; byte into PF1 at cycle 14, before PF1's first slot (~28).  The loop's first
; store repeats the same byte, so a late repeat cannot change the picture.
    LDA BarBuf+14
    STA PF1                 ; cell 14 (the top cell) for line 40
    LDA #$00
    STA PF0
    STA PF2
    LDA #C_GOLD
    STA COLUPF
    LDX #14
MeterCell:
    LDA BarBuf,X
    STA PF1
    LDY #BAR_LINES
MeterLine:
    STA WSYNC
    DEY
    BNE MeterLine
    DEX
    BPL MeterCell

; --- visible 130-191: background -------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #62
RestZone:
    STA WSYNC
    DEY
    BNE RestZone
    JMP FrameEnd

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
FrameEnd:
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; CountFree — walk RamMap and return 128 - used in A
; =============================================================================
; The table uses 16 bits per row: PF0 bits 6-7 (two cells), PF1 bits 0-7
; (eight cells), and PF2 bits 0-5 (six cells).  The unused bits are zero, so
; each byte is masked before its bits are counted; counting the used bits and
; subtracting from 128 avoids having to invert the masks.
CountFree:
    LDA #$00
    STA FreeCount           ; the used-byte tally
    LDX #$00
CountRow:
    LDA RamMap+0,X
    AND #$C0                ; PF0 cells 0-1
    JSR CountBits
    LDA RamMap+1,X
    JSR CountBits           ; PF1 cells 2-9
    LDA RamMap+2,X
    AND #$3F                ; PF2 cells 10-15
    JSR CountBits
    TXA
    CLC
    ADC #$03
    TAX
    CPX #24
    BNE CountRow
    LDA #128
    SEC
    SBC FreeCount
    RTS

; --- add the eight bits of A to FreeCount ----------------------------------
CountBits:
    LDY #8
CountBit:
    ASL                     ; the old bit 7 moves into the carry
    BCC CountBitNext
    INC FreeCount
CountBitNext:
    DEY
    BNE CountBit
    RTS

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
; The timer's overflow calls this once.  AUDC 0C is the div-6 tone from
; Lesson 35; AUDV 0A is audible but not loud.  The VBLANK clock silences the
; channel two frames later.
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; TABLES
; =============================================================================

; --- the auto-demo's two direction flags, indexed by DemoStep ---------------
DemoLeftTable:
    !byte 1, 0, 1, 0        ; phase 0 and phase 2
DemoRightTable:
    !byte 0, 1, 1, 0        ; phase 1 and phase 2

; --- the memory map: eight rows x three playfield bytes --------------------
; One bit per byte in $80-$FF.  Row 0 is the top row ($80-$8F); within a row,
; cell 0 is the lowest address and lives in PF0 bit 6.  The table is the
; reference: when the allocation changes, change this table and the picture
; follows.
RamMap:
    !byte $C0, $FF, $3F     ; row 0: $80-$8F  all 16 used
    !byte $C0, $00, $00     ; row 1: $90-$9F  cells 0-1 used ($90,$91)
    !byte $C0, $FF, $3F     ; row 2: $A0-$AF  all 16 used (score plan)
    !byte $C0, $FF, $3F     ; row 3: $B0-$BF  all 16 used (score plan)
    !byte $C0, $FF, $3F     ; row 4: $C0-$CF  all 16 used (score plan)
    !byte $C0, $FC, $00     ; row 5: $D0-$DF  cells 0-7 used ($D0-$D7)
    !byte $00, $03, $3F     ; row 6: $E0-$EF  cells 8-15 used ($E8-$EF)
    !byte $C0, $FF, $3F     ; row 7: $F0-$FF  all 16 used (bar + stack)

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

<!-- END-FULL-SOURCE -->

> The complete, fully-commented source lives in
> `lessons/part6-game-dev/45-memory-management/45-memory-management.asm`.

### Code Walkthrough

#### Step 1 — The allocation and the map table

The file starts with the constants and then the RAM allocation, address by address. The
allocation is the contract; the table in ROM is its picture:

```asm
FrameLo      = $80   ; 16-bit frame counter, low byte
...
FreeCount    = $91   ; the computed free-byte count (128 - used)

; $92-$9F are free (14 bytes).  The auto-demo tables are in ROM.

; --- $A0-$D7: the scoreboard reservation ------------------------------------
...
; --- $E8-$F7: the timer bar's block ----------------------------------------
BarBuf       = $E8   ; fifteen cell bytes: $20 = lit, $00 = dark ($E8-$F6)
BarLevel     = $F7   ; the bar height, PackedTimer >> 4 (0-15)
RamEnd       = BarLevel   ; the highest used address ($F7)
```

`RamEnd` is not used by the main ROM; it exists so the exercise-3 assert has a stable label to
read. The main's job is to make the label true: every variable must sit at or below it. The map
table's eight rows then encode those addresses as bits, and the kernel never has to compute an
address — it reads three bytes per row.

#### Step 2 — Reset and the free-byte count

After `+clean_start`, the program sets the port directions, the background color, and the
playfield control, then counts the free bytes:

```asm
    JSR CountFree
FreeBytes:                  ; checkpoint: A = the computed free-byte count
    STA FreeCount
```

`CountFree` walks the 24-byte table once. Each row contributes two `PF0` bits, eight `PF1` bits,
and six `PF2` bits — sixteen cells. The routine masks the unused bits, counts the set bits with
`ASL`/`BCC`/`INC FreeCount`, adds nothing for the padding bits, and returns `128 - used`. On
this map it returns `$1E`, 30 free bytes. The count runs before the first frame, where the timing
budget does not apply.

#### Step 3 — VBLANK: input, auto-demo, and the fire edge

The VBLANK work reads the three active-low inputs into three level flags. `INPT4` bit 7 is 0
while fire is held; `SWCHA` bit 6 is left and bit 7 is right. Each flag is a 0/1 byte, so the
flags row can turn it into a cell with a branch.

The auto-demo advances every 64 frames:

```asm
    INC DemoHold
    LDA DemoHold
    CMP #DEMO_FRAMES
    BCC DemoStepDone
    LDA #$00
    STA DemoHold
    LDA DemoStep
    CLC
    ADC #$01
    AND #$03
    STA DemoStep
DemoStepDone:
    LDX DemoStep
    LDA DemoLeftTable,X
    ORA FlagLeft
    STA FlagLeft
    LDA DemoRightTable,X
    ORA FlagRight
    STA FlagRight
```

The fire edge is the standard three-instruction idiom: `EOR` with last frame's value keeps the
bits that changed, and `AND` with this frame's value keeps the ones that changed to 1. The
restart runs on that edge only, so holding fire does not reset the timer every frame.

#### Step 4 — The packed timer and the bar buffer

The timer is one `INC` and a compare:

```asm
    LDA FlagOver
    BNE TimerDone
    INC PackedTimer
    LDA PackedTimer
PackTimer:                  ; checkpoint: A = the packed byte, before the test
    CMP #TIMER_FULL
    BNE TimerDone
    LDA #$01
    STA FlagOver
    JSR BeepStart
TimerDone:
```

`INC` carries out of the low nibble into the high nibble by ordinary binary addition: `$0F + 1`
is `$10`, `$1F + 1` is `$20`, and `$EF + 1` is `$F0`. The compare stops at `$F0`, which is
240 frames and a full bar. `PackTimer` reports the byte before the test, so the state log shows
`$01`, `$02`, … `$F0`, one value per frame.

The bar buffer is filled from the high nibble:

```asm
    LDA PackedTimer
    LSR
    LSR
    LSR
    LSR
    STA BarLevel
    LDX #$00
FillBar:
    CPX BarLevel
    LDA #$00
    BCS FillBarDark         ; X >= height: this cell is dark
    LDA #BAR_CHUNK          ; chunk 6: X=24-27
FillBarDark:
    STA BarBuf,X
    INX
    CPX #BAR_CELLS
    BNE FillBar
```

`CPX BarLevel` sets the carry when X is greater than or equal to the height; `BCS` sends that
cell to the dark path. A cell below the height is lit. The bar grows from the bottom, and the
kernel draws it top-down — cell 14 first, cell 0 last.

#### Step 5 — The flags row's two bytes

The flags row is one byte per playfield register. Fire and left share `PF0`, right and overflow
share `PF1`:

```asm
    LDA #$00
    STA FlagPF0
    STA FlagPF1
    LDA FlagFire
    BEQ FireCellDone
    LDA #FLAG_FIRE_PF0
    STA FlagPF0
FireCellDone:
    LDA FlagLeft
    BEQ LeftCellDone
    LDA FlagPF0
    ORA #FLAG_LEFT_PF0
    STA FlagPF0
LeftCellDone:
    ...
```

The four branch tests are the direct version. Exercise 1 replaces them with two table lookups
into the packed `Flags` byte; both produce the same two bytes.

#### Step 6 — The kernel: four zones

The flags row holds its two bytes for eight lines. The map loop draws eight rows of four lines,
reading `RamMap` and advancing X before the `WSYNC`s. The meter preloads the top cell and then
walks X from 14 down to 0, six lines per cell:

```asm
    LDA BarBuf+14
    STA PF1                 ; cell 14 (the top cell) for line 40
    LDA #$00
    STA PF0
    STA PF2
    LDA #C_GOLD
    STA COLUPF
    LDX #14
MeterCell:
    LDA BarBuf,X
    STA PF1
    LDY #BAR_LINES
MeterLine:
    STA WSYNC
    DEY
    BNE MeterLine
    DEX
    BPL MeterCell
```

The background zone clears the three playfield registers and holds them for 62 lines. The zone
counts are 8 + 32 + 90 + 62 = 192; `OverscanStart` is the next line, scanline 229.

#### Step 7 — Reading it back

```bash
acme -f plain -l build/lesson45.sym -o build/lesson45.bin \
  lessons/part6-game-dev/45-memory-management/45-memory-management.asm
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -logtoconsole 1 \
  -break '$F135' docs/public/roms/part6-game-dev/45-memory-management/45-memory-management.bin
```

Stella keeps one `-break` per run, so run one checkpoint at a time. `-dbg.logtrace 0` keeps the
instruction trace out of the output; `-dbg.logbreaks` continues after each break, which is what
makes the `PackTimer` sequence readable.

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F024` | **259, cycle 3** | the first VSYNC line |
| `VblankStart` | `$F032` | 0, cycle 5 | the first VBLANK line |
| `FireRead` | `$F053` | A=`$8C` released; A=`$0C` pressed | `INPT4`; bit 7 is the button |
| `FreeBytes` | `$F022` | A=`$1E` (30), once at reset | the computed free-byte count |
| `PackTimer` | `$F0BC` | A=`$01` … `$F0`, one per frame | the packed timer byte |
| `MapDraw` | `$F135` | **45, cycle 15**, A=`$C0`; then 49, 53, … | row 0's PF0 byte; visible line 8 is scanline 45 |
| `BodyStart` | `$F115` | **37, cycle 5** | visible line 0 |
| `OverscanStart` | `$F181` | **229, cycle 7** | overscan's first line |

The exercise solutions add code, so their scanline reports are the same but their addresses
move. Re-assemble with `-l` and read the symbol file after any edit. In
`exercise-01-solution.asm`: `PackTimer` `$F0C5`, `BodyStart` `$F10C`, `MapDraw` `$F12C`,
`OverscanStart` `$F178`. In `exercise-02-solution.asm`: `PackTimer` `$F0C8`, `BodyStart`
`$F14C`, `MapDraw` `$F16C`, `OverscanStart` `$F1B8`.

The RAM bytes to watch are `PackedTimer` at `$88`, `BarLevel` at `$F7`, `Flags`/the four flag
bytes at `$84–$87`, and `FreeCount` at `$91`. The map table is in ROM at `RamMap`; the debugger's
memory view can show it but the screen is the easier read: the lit cells are the table's bits.

## What You Should See

The screen is a dark `$02` field with three gold-and-green displays. The **flags row** is visible
lines 0–7: four gold cells at TIA X=8–23, one per flag, and their mirror at X=136–151. The
**map** is visible lines 8–39: eight rows of four lines, sixteen cells per half at X=8–71, with
the mirror at X=88–151. Green `$C8` is used, dark `$02` is free. The rows from top to bottom are
16, 2, 16, 16, 16, 8, 8, and 16 used cells: row 5 is an eight-cell bar at the left edge, and
row 6 is an eight-cell bar at the right edge (cells 8–15). The **timer bar** is visible lines
40–129: fifteen cells of six
lines at X=24–27, mirrored at X=132–135; its height is `PackedTimer >> 4`.

**The main map.** This capture shows a partially filled timer: nine of the fifteen cells lit,
from the bottom to visible line 76 (nine cells × six lines = 54 lines, 76–129). The flags row
shows the left and right cells, one 64-frame demo phase with both directions on. The map's top row is full, the second row is the two-cell stub (`$90,$91`), the
middle three rows are the scoreboard reservation, row 5 is half full (`$D0–$D7`), row 6 is the
right half (`$E8–$EF`), and the bottom row is full (`$F0–$FF`: the bar buffer, `BarLevel`, and
the stack).

![Stella running the Lesson 45 ROM: a gold left-and-right flags row at the top, a green 16×8 map with full, partial, and offset rows, and a nine-cell gold timer bar mirrored on both sides](/images/lesson45/map.png)

*The main map at timer value `$9x`: nine bar cells, the left and right flags, and the 16×8 grid.
Row 0 is all sixteen used bytes, row 1 is the two-byte stub, rows 2–4 are the score reservation,
row 5 is the eight-byte half, row 6 is the right-hand eight, and row 7 is the bar block plus the
stack.*

<RomPlayer rom="/roms/part6-game-dev/45-memory-management/45-memory-management.bin" title="Lesson 45 — Memory Management" />

Click the player screen once: Javatari starts muted until a user gesture. The ROM runs its
auto-demo without input, so the flags row alternates and the bar rises. Press fire to restart the
timer after it fills; push the joystick left or right to add a cell to the demo's pattern. The
timer fills in 240 frames (about four seconds) and raises the overflow cell; the beep marks the
moment.

**The packed map.** Exercise 1 packs the four flags into one `Flags` byte at `$84`, so `$85–$87`
become free. The top row now has a three-cell notch at cells 5–7 (TIA X=28–39); every other row
is unchanged, and the rest of the screen is the same program. The free-byte count rises from 30
to 33.

![Stella running the Lesson 45 exercise-1 ROM: the same flags row and timer, but the map's top row has a three-cell notch where the three packed-away flag bytes used to be](/images/lesson45/map-packed.png)

*Exercise 1: three fewer used cells in the top row. The notch is at cells 5–7, `$85–$87`; the
flags row still works from the single `Flags` byte, and `FreeBytes` reports 33.*

> **Capture method.** Both images are window captures of the committed ROMs in Stella 7.0, from
> `docs/public/roms/part6-game-dev/45-memory-management/45-memory-management.bin` and
> `.../exercise-01-solution.bin`, with the pointer parked at (0,0) and no game pixel altered.
> The title bars read `Stella 7.0: "45-memory-management"` and
> `Stella 7.0: "exercise-01-solution"`. Each image is the second frame of a burst started 2.0 s
> after launch, with 0.4 s between captures; the second frame was selected because both ROMs
> showed the same state there (nine lit timer cells, left and right flags), so the only
> difference in the game picture is the packed map (the title bar names the ROM). The row
> lengths, the notch, and the bar
> height are decoded from the captured pixels, not copied from a log: capture x = 25 + 6 × TIA X
> and capture y = 107 + 3.15 × visible line.

The debugger tells the same story as numbers:

- **`$F053` (`FireRead`)**: A=`$8C` while fire is released and A=`$0C` while it is held; bit 7
  is 0 when pressed. The edge, not the level, restarts the round.
- **`$F022` (`FreeBytes`)**: A=`$1E` (30) once at reset. The main map has 98 used bytes: 16
  lesson variables plus 2 reserved scratch bytes, 56 reserved for the scoreboard, 16 in the bar
  block, and 8 in the stack reserve. Exercise 1 reports A=`$21` (33), and exercise 2 reports
  A=`$1D` (29).
- **`$F0BC` (`PackTimer`)**: A=`$01` at the first frame, then `$02`, `$03`, … `$F0` on frame
  240. The sequence stops there because `FlagOver` latches and the timer stops; fire resets it
  to `$01`.
- **`$F135` (`MapDraw`)**: A=`$C0` on the first hit at scanline 45, cycle 15 — visible line 8,
  row 0's `PF0` byte. The next hits are at 49, 53, … as the row index advances by three.
- **`$F115` (`BodyStart`)** 37/5 and **`$F181` (`OverscanStart`)** 229/7 — the 262-line frame.
- There is no `HMOVE` checkpoint: the display is playfield-only.

With the debugger open on a visible frame, `PackedTimer` is `$88`, `BarLevel` is `$F7`,
`FreeCount` is `$91`, `FlagFire`/`FlagLeft`/`FlagRight`/`FlagOver` are `$84–$87`, and the map
table is `RamMap` in ROM. The grid is drawn from the table every frame; there is no display
buffer between the table and the TIA except the bar's fifteen bytes.

## Exercises

### Exercise 1: Pack the Flags

**Challenge:** replace the four flag bytes (`FlagFire`, `FlagLeft`, `FlagRight`, `FlagOver`)
with one `Flags` byte at `$84`: bit 0 = fire, bit 1 = left, bit 2 = right, bit 3 = over. The
flags row must still light one cell per flag; the map must lose the three freed cells in its top
row; `FlagsWrite` must report the packed byte.

**Hints:**
1. The joystick bits arrive as `SWCHA` bits 7 (right) and 6 (left), both active low. Mask first
   with `AND #$C0` — without it, P0 down (bit 5) would be shifted into the fire bit — then
   invert the pair with `EOR #$C0`; five `LSR`s move right to bit 2 and left to bit 1.
2. Fire is `INPT4` bit 7, active low. OR it in as bit 0 after the joystick bits.
3. The timer's overflow bit must survive the input rebuild. Park it in `NewFire` before the
   rebuild (`LDA Flags; AND #$08; STA NewFire`), OR it back after the demo bits, then let the
   fire-edge block overwrite `NewFire`. Without this, the input rebuild clears bit 3 every frame,
   the timer runs on from `$F0`, and it wraps to `$00`.
4. The flags row needs two four-entry tables: index `Flags & 3` (fire | left) for `PF0`, and
   index `(Flags >> 2) & 3` (right | over) for `PF1`.
5. The map's row 0 becomes `$C0,$E3,$3F`; cells 5, 6, and 7 (`$85–$87`) are dark.

**Expected Result:** `FlagsWrite` (`$F0ED`) reports A=`$02` with the demo's left phase and no
input, and A=`$03` with fire held in that phase. The top row of the map has a three-cell notch at
cells 5–7, all other rows are unchanged, and `FreeBytes` (`$F022`) reports A=`$21` (33) at reset.
The flags row still lights the left and right cells from the one packed byte.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Overlay by State

**Challenge:** add a title state whose variables reuse the play state's bytes. Introduce
`GameState` (`$92`), start in the title (0), and let fire start play (1). The title and play
states must share the `$8B/$8C` pair: `TitleHold`/`TitleStep` in the title,
`PlayHold`/`PlayStep` in play. Add `!if` asserts that the two names really are the same
addresses. In the title, blink all four flags and fix the bar at seven cells; in play, run the
main ROM's behaviour, but gate the timer block on `GameState=1` so the title is silent. Update
the map's row 1 and document `StateOverlay`.

**Hints:**
1. `TitleHold = $8B`, `TitleStep = $8C`, `PlayHold = $8B`, `PlayStep = $8C`. Two `!if` blocks
   compare the pairs and `!error` when they differ.
2. The shared bytes are already lit in row 0; the only new cell is `GameState` at `$92`, so row
   1 becomes `$C0,$80,$00` and the free count drops to 29.
3. `StateWrite` is the checkpoint after `STA GameState`, but it shares its address with
   `AlreadyPlaying`: in the title it follows the store, in play it is the branch target. It
   fires on every fire edge with A=1, so it is not a one-shot; the title/play display proves the
   transition.
4. Gate the timer block with `LDA GameState; BEQ TimerDone` before the `FlagOver` test. A title
   left on screen for 240 frames would otherwise raise `FlagOver` and sound the overflow beep.
5. The title's blink can read `TitleStep & 1`; the play path keeps using `PlayStep`. They are
   the same byte, which is the point of the overlay.
6. Do not add a second pair of bytes: the exercise is about proving the overlap, not about
   making the title pretty.

**Expected Result:** The ROM starts in the title, where all four flag cells blink together (lit
in the even phases) and the bar is fixed at seven cells; the title is silent because the timer
block is gated. Pressing fire reports A=`1` at `StateWrite` (`$F0B6`) and switches to the play
display and the main ROM's timer. `StateWrite` fires on every fire edge (it shares its address
with `AlreadyPlaying`), so the state change is proven by the display, not by the checkpoint
alone. `FreeBytes` (`$F022`) reports A=`$1D` (29), and the map's row 1 has three lit cells. The
two `!if` asserts pass; changing `TitleStep` to `$8D` fails the build with
`state overlay mismatch: TitleStep and PlayStep`.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The RAM Budget Assert *(Stretch Goal)*

**Challenge:** add the assembly-time budget check. `RamEnd` is the highest used address
(`BarLevel` at `$F7`); the stack owns `$F8–$FF`. Add an ACME `!if` that fails the build with
`RAM budget exceeded` when `RamEnd > $F7`. Prove it by moving `BarLevel` to `$F8`.

**Hints:**
1. The check goes after the allocation, where `RamEnd` is defined:
   `!if RamEnd > $F7 { !error "RAM budget exceeded" }`.
2. `!if` is assembly-time; `!error` stops ACME and no ROM is written. The check costs no ROM
   bytes and no cycles.
3. To prove it, change `BarLevel = $F7` to `BarLevel = $F8`. `RamEnd` follows the label, so the
   condition is true. Change it back and the build returns to 4,096 bytes.
4. The map table is hand-maintained; a real move would also update row 7. The assert catches the
   plan error before the picture can lie.
5. Keep the label honest: `RamEnd` must name the highest used byte. If you add a variable above
   it, move `RamEnd` to the new variable and let the assert re-check the budget.

**Expected Result:** The solution assembles to exactly 4,096 bytes and its ROM is byte-identical
to the main ROM (the assert emits nothing). With `BarLevel = $F8`, ACME prints
`Error - File ..., line ... (Zone <untitled>): !error: RAM budget exceeded` and exits with
status 1; no `.bin` is produced. With the label back at `$F7`, `bash scripts/verify.sh` passes.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **128 bytes is the whole budget**: RAM is `$80–$FF`, the stack mirrors the same bytes from
  page `$01`, and `+clean_start` sets `SP=$FF`. A map is a plan, and the plan must leave room
  for the stack.
- ✅ **The playfield is a bitmap**: sixteen cells per half come from `PF0` bits 6–7, `PF1` bits
  7–0, and `PF2` bits 0–5 (chunks 2–17). `CTRLPF=$01` reflects the right half, so one 128-cell
  map appears twice; the left half is the reference.
- ✅ **The map table is 24 bytes of ROM**: eight rows × three playfield bytes, one bit per RAM
  byte. It is static because the map is constant and a runtime builder would cost more than it
  saves; the picture makes a drifted table visible.
- ✅ **Used means spent in the plan**: this lab writes 16 lesson bytes, reserves 2 more as
  `Scratch0`/`Scratch1`, writes the 16-byte bar block, and reserves 56 for the scoreboard and 8
  for the stack; 98 used, 30 free. A reservation is a budget line even when the lab never fills
  it.
- ✅ **Packing trades bytes for instructions**: four flags become one `Flags` byte (three bytes
  saved, two lookup tables added); one timer byte holds a 16-frame tick count and a frame count,
  and `INC` carries between the nibbles for free.
- ✅ **The budget check belongs at assembly time**: `RamEnd` at `$F7` plus
  `!if RamEnd > $F7` stops the build before the stack can be overwritten. Exercise 2 uses the
  same `!if` to prove a state overlay's aliases.
- ✅ **The kernel is four work-first zones**: flags 8 + map 32 + bar 90 + background 62 = 192
  lines; 3 + 37 + 192 + 30 = 262. The map's PF0 store completes by cycle 17 (row 0) or 15
  (rows 1–7), before the first slot at about 22.7, and the ROM needs no `HMOVE`.

## What's Next

The map now shows the budget, the timer is packed, and the build refuses to let a variable touch
the stack. The next lesson uses the same debugger that produced this lesson's state log to break
a ROM on purpose. [Lesson 46: Debugging — Finding and Fixing Bugs](/part6-game-dev/46-debugging)
builds a debug lab with three classic failures — a sticky collision latch, a 263-line frame, and
an off-by-one sprite row — and walks the Stella workflow that finds each one.
