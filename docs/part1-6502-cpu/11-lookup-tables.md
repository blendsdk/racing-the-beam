---
title: "Lesson 11: Lookup Tables — Data-Driven Programming"
description: "Build tables in ROM and index them from 6502 code: LDA table,X, the (offset + k) AND $0F scroll math, the bounds discipline that keeps an index inside its table, and tables over time — a sixteen-band color wave that scrolls upward and wraps seamlessly, plus colors-plus-durations and pointer-table programs."
prev:
  text: "Lesson 10: Addressing Modes"
  link: "/part1-6502-cpu/10-addressing-modes"
next:
  text: "Lesson 12: The NTSC Frame"
  link: "/part2-tv-and-tia/12-the-ntsc-frame"
---

# Lesson 11: Lookup Tables — Data-Driven Programming

> **Part 1: The 6502 CPU** · Estimated time: 45 minutes
> **Prerequisites:** Lesson 04 (RAM variables and the frame skeleton), Lesson 07 (countdown loops), Lesson 08 (subroutines, register contracts, and the `!byte` band palette), Lesson 09 (`AND` masks and the animation clock), Lesson 10 (indexed reads, every addressing mode, and pointers)
> **You will learn:** what a lookup table is and why it beats a branch tree or runtime arithmetic; `!byte` tables in ROM read with `LDA table,X`; the base-plus-index fetch and what it costs; the bounds discipline — mask or compare — that keeps an index inside its table; `(offset + k) AND $0F`, the scroll math that turns a fixed table into an animation; and the idea of a table as a script, with colors, durations, and pointers as entries
> **You will build:** the "color wave" ROM — one 16-byte table of colors and one offset byte in RAM, driving sixteen equal bands that scroll upward and wrap seamlessly — plus three exercises that turn it into a static palette, a two-table movie in which every color is held for its own time, and a pointer table that swaps palettes every couple of seconds

## Introduction

Lesson 08 handed you a four-byte palette read as `LDA BandColors,X`, and Lesson 10 put a six-byte ramp in ROM and read it with `LDA Ramp,Y`. Both times the table was a small convenience — a nicer way to write `LDA #$42` three times. This lesson makes the table the *program*, and that is a real change of style: instead of computing a value with arithmetic, or choosing between values with a tree of `CMP`/`BEQ` branches, you put the answers in a table ahead of time and let one indexed load fetch the one you want. Programmers call the result **data-driven** code, and on a machine with 4 kilobytes of cartridge space and a hard cycle budget on every scanline, it is how the 2600 gets made.

The companion program `11-lookup-tables.asm` is called the **color wave**. It paints sixteen equal bands of twelve scanlines each — 192 non-blanked lines — and every band's color comes out of a single 16-byte table in ROM: `$1A`, `$28`, `$36`, … `$EC`, a slow rainbow sweep with a light-to-dark ramp inside it. Band *k* shows `Wave[(offset + k) AND $0F]`, where `offset` is one byte in RAM. Every sixteen frames — about a quarter second — that offset advances by one, so the whole picture walks one band *up* the screen and the color that leaves the top reappears at the bottom. When the offset passes 15, the `AND $0F` wraps it back to 0 and the wave starts again, and at no point is there a blank band, a repeated band, or a color the table does not contain.

Nothing in the kernel computes a color. Change the sixteen bytes of the table and the picture is a different picture; change the *offset* and it is the same picture at a different stage. That separation — data in ROM, index in RAM, one instruction joining them — is the whole lesson, and the three exercises take it apart: your own table, two tables holding colors *and* time, and a table of pointers that swaps the palette underneath a running wave.

::: details TypeScript Equivalent
In a modern language you reach for an array and never think about it:

```typescript
const wave = [0x1A, 0x28, 0x36, 0x44, 0x52, 0x60, 0x6E, 0x7C,
              0x8A, 0x98, 0xA6, 0xB4, 0xC2, 0xD0, 0xDE, 0xEC];

const color = wave[(offset + k) % wave.length];   // the whole lesson, one line
```

The 6502 spends a different currency to get there: the wave computes the index in a register (a running `TXA`/`AND` — the index register *is* the sum, so no `ADC` is needed) and then loads through it, and the mask is what does the `% wave.length` work. The analogy breaks in three places, each of them the reason this lesson exists:

- **There is no bounds checking.** `wave[i]` in TypeScript reads `undefined` past the end (or throws); `LDA Wave,X` with X = 16 reads the *next byte in ROM* and hands it back as a perfectly good color. The mask in this lesson (`AND #$0F`) is the programmer's substitute for the runtime check the CPU does not do.
- **The index is one byte.** There is no 32-bit indexing and no `wave.length`: the table's size is something *you* keep track of, in the mask's constant or in a compare. Every table in the course comes with a stated size for exactly that reason.
- **The lookup costs what it costs.** `LDA Wave,X` is 3 bytes and 4 cycles, every time; there is no optimizer to hoist it out of a loop, and inside a scanline those 4 cycles are 4 of the ~76 you get. A table trades ROM (cheap, 4K of it) for the cycles of computing or branching (expensive, 76 per line).
:::

## Theory

### Section 1: A Table Is Just Bytes — and an Index

A **lookup table** is a run of bytes at a known address, read one at a time by an index. In ACME the bytes are written with `!byte`:

```asm
Wave:
    !byte $1A, $28, $36, $44    ; k = 0...3
    !byte $52, $60, $6E, $7C    ; k = 4...7
    !byte $8A, $98, $A6, $B4    ; k = 8...11
    !byte $C2, $D0, $DE, $EC    ; k = 12...15
```

The label `Wave` is the address of the first byte; entry *k* sits at `Wave + k`. Reading it is one instruction, and Lesson 10's mode catalog tells you which one: `LDA Wave,X` (absolute,X — 3 bytes, 4 cycles) or `LDA Wave,Y` (absolute,Y, the same cost). X or Y is the index; the instruction adds it to the table's 16-bit base and reads the byte. There is no arithmetic to write and no branch to take: **the entry you want is chosen by the value in an index register.**

Why not compute the value instead? Because on this machine every option costs something different, and the table is usually the cheapest:

| Way to produce 16 different colors | ROM | Per color | Fragility |
|---|---|---|---|
| Branch tree (`CMP`/`BEQ` per entry) | ~64 bytes (the tree alone) | 1 compare + 1 branch *per test* (up to 16 of them) | Every new entry adds two instructions |
| Arithmetic (`ADC #$0E` per step) | a few bytes | `CLC`, `ADC`, and a store | Needs a formula; not every sequence has one |
| **Lookup table** | **16 bytes** | **`LDA Wave,X` — 4 cycles** | **None: the data *is* the answer** |

The trade is deliberate: cartridge ROM is the cheap resource (4K in this course's cartridges), and CPU cycles are the expensive one — a kernel has about 76 of them per scanline and no way to buy more. A table spends the cheap resource to save the expensive one. It also changes the *shape* of the code: adding a seventeenth color means adding one byte and bumping the size, not adding two instructions and re-counting cycles.

The same trick scales to every kind of data the course will need later: a table of sprite graphic bytes, a table of sine values for smooth motion, a table of level layouts. The instruction never changes — it is always `LDA something,X`.

::: tip Two index registers, two instruction sets
`LDA Wave,X` and `LDA Wave,Y` both exist for a table at a 16-bit address, so either index register can do the job. What does *not* exist is a zero-page,Y load into A: if a table lives in RAM, `LDA` reads it with X, or you move the byte through `LDX`/`TXA`. Lesson 10 listed the asymmetries; the practical rule here is to pick the index register the rest of your loop does **not** need, which is exactly what the wave kernel does below.
:::

### Section 2: The Table as the Picture — `(offset + k) AND $0F`

The wave ROM's table holds the ramp `$1A + $0E x k`. Read it in order and both halves of the color byte move at once:

| k | Byte | Hue | Luminance | On screen |
|:--:|:----:|:---:|:---------:|-----------|
| 0 | `$1A` | 1 | 5 | gold |
| 1 | `$28` | 2 | 4 | orange-brown |
| 2 | `$36` | 3 | 3 | orange-red |
| 3 | `$44` | 4 | 2 | red |
| 4 | `$52` | 5 | 1 | magenta |
| 5 | `$60` | 6 | 0 | very dark purple |
| 6 | `$6E` | 6 | 7 | light violet |
| 7 | `$7C` | 7 | 6 | violet |
| 8 | `$8A` | 8 | 5 | blue-violet |
| 9 | `$98` | 9 | 4 | blue |
| 10 | `$A6` | A | 3 | steel blue |
| 11 | `$B4` | B | 2 | teal-green |
| 12 | `$C2` | C | 1 | green |
| 13 | `$D0` | D | 0 | very dark green |
| 14 | `$DE` | D | 7 | bright yellow-green |
| 15 | `$EC` | E | 6 | yellow-green |

Adding `$0E` to a byte advances its low nibble by 14, which walks the luminance field downward — 5, 4, 3, 2, 1, 0, then wrapping from 0 to 7, twice over the table — and carries into the hue nibble on every step except the two where the luminance wraps. So the wave is a color-wheel sweep with a light-to-dark ramp folded into it. The two entries with luminance 0 (`$60` and `$D0`) are the darkest step the palette has: in Stella's default NTSC palette they render as a very dark purple and a very dark green rather than pure black, which is what makes them readable as *bands* rather than holes.

The kernel paints band *k* (k = 0 at the top) with

```text
band k  ->  Wave[(offset + k) AND $0F]
```

and the offset advances once every 16 frames. Walk one step and you can see why the picture scrolls the way it does. With `offset = 0` the bands read `$1A $28 $36 … $EC` from top to bottom. With `offset = 1` they read `$28 $36 $44 … $EC $1A`: every color has moved **one band up** the screen, and the color that was in the top band has reappeared in the bottom one. Nothing was created and nothing was lost — the screen is always a **cyclic rotation** of the table, all sixteen entries exactly once, with the sequence running continuously off the bottom and back in at the top (after `$EC` comes `$1A` again). That is what "seamless" means here: at every step of the cycle there are sixteen bands, sixteen distinct table entries, no blank and no repeat.

Two details make the arithmetic work:

- **The wrap is the mask.** `offset + k` can be as large as `15 + 15 = 30`, and the table only goes up to entry 15. `AND $0F` maps 16…30 back to 0…14, which is exactly arithmetic modulo 16 — the table's size. The mask is not a safety net bolted onto a working kernel; it *is* the scroll's wrap-around, and the same mask appears twice: once on the band index, once on the offset itself when the animation clock advances it.
- **The table fits in one page.** In the assembled ROM the 16 bytes after the `Wave` label start at `$F08C`, so `$F08C + 15 = $F09B` stays inside page `$F0`: no indexed read here can cross a page boundary, and every fetch costs exactly the base 4 cycles. (A page cross would add one cycle — harmless in this kernel, but it is the kind of detail that decides whether a tight scanline loop fits.)

::: tip Reading the scroll direction from the formula
`band k = Wave[offset + k]` means the *band number* of a fixed entry is `entry - offset` (mod 16) — so as `offset` grows, each entry's band number falls, and a falling band number is *up* the screen. The wave scrolls upward: entries leave through the top band and re-enter at the bottom. If you want the opposite direction, subtract the offset instead of adding it; the mask does not care.
:::

### Section 3: Bounds Discipline — Mask or Compare

Every table has a size, and the 6502 will not remind you of it. `LDA Wave,X` with X = 16 does not fault, does not return "nothing", and does not stop — it reads whatever byte happens to sit after the table (in this ROM, one of the filler bytes that pad the cartridge out to the vector addresses) and paints a band with it. Silent wrong answers are the worst kind, so every indexed read in the course is *deliberately* bounded, using one of two tools:

- **A mask**, when the table's size is a power of two: `AND #$0F` keeps an index in 0…15 and *wraps* it. The wave uses this because it wants wrapping. (Masking works for 2, 4, 8, 16, 32, … entries; 16 is the size here, so the mask is `$0F`.)
- **A compare**, when it is not: a twelve-entry table checks the index before the read (`CPX #12` / `BCC`, Lesson 06) and *stops* at the edge instead of wrapping. Exercise 1 below uses the same idea in its simplest form — an index that only ever counts up needs nothing more than a `CPX #BANDS` / `BNE` at the end of the loop.

The difference is a design decision, not a style preference. A wave wants the index to come back around; a ramp that fills a screen wants to stop at the last entry. What is never acceptable is an index that *can* leave the table: with a mask, the code is correct for every possible byte in the index register, and the proof fits in the constant.

::: warning `AND $0F` is arithmetic, not a clamp
`16 AND $0F = 0`, `17 AND $0F = 1`: the mask wraps, it does not saturate. That is what makes the wave seamless, and it is also why the mask must match the table size exactly — `AND $0F` on a 12-entry table would happily produce index 13 and hand you the wrong byte (or one past the end).
:::

### Section 4: Tables Over Time — Colors, Durations, Pointers

The wave's offset is what turns a table into an *animation*: the table is the picture, and the offset is the clock. Two consequences are worth holding on to, because the exercises build on them.

**A table holds bytes; their meaning is the reader's choice.** `LDA Colors,X` and `LDA Durations,X` use the same instruction on the same kind of data, but one byte is a color to paint and the other is a number of frames to wait. A program can keep two tables in lock-step by reading both with the same index — color *k* paired with duration *k* — and the animation becomes a script: a list of what to show and for how long. Change the durations and the *timing* changes with no code change at all. This is how sprite animations and level scripts are built.

**A table can hold addresses too.** An `!word` directive stores sixteen bits — a full 6502 address — so a table of `!word` entries is a table of *pointers*, and an index into it selects not a value but a whole table. One more level of indirection, and swapping one entry swaps the entire palette of a running program. The catch is a Lesson 10 detail: `(zp,X)` reads its pointers out of **zero page**, so a pointer table in cartridge ROM cannot be used with that mode. The idiom instead is two loads — `LDA WavePtrs,X` for the low byte, `LDA WavePtrs+1,X` for the high byte — into a zero-page pair, and then `(zp),Y` walks whichever table they point at. Exercise 3 is exactly that program.

::: details TypeScript Equivalent
Tables over time are still arrays in TypeScript — the difference is that on the 6502 the *clock* is a byte you own:

```typescript
// TypeScript: the timing lives in the control flow, and the data structure
// is chosen for convenience (objects, pairs, whatever reads well).
const script = [
  { color: 0x1A, frames:  8 },
  { color: 0x28, frames: 12 },
  // ...
];
for (const step of script) await hold(step.color, step.frames);

// 6502: the pairs live in two parallel arrays and the clock is a countdown.
//   DEC Hold            -> one frame of the hold is spent
//   BNE same_step       -> not zero: keep the same color
//   INC Step / AND #$0F -> advance, wrapping like the wave does
//   LDX Step            -> ONE index reads BOTH tables: Colors[X], Durations[X]
```

Where the analogy breaks: in TypeScript "the same index reads both arrays" is automatic; on the 6502 you *write it twice* — once per read — and if the two reads use different values of X, the script silently desynchronizes and color 3 gets the time meant for color 5. Keeping a shared index in step is a programmer's job here.
:::

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson11.bin \
  lessons/part1-6502-cpu/11-lookup-tables/11-lookup-tables.asm
stella build/lesson11.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`, all in the same directory.

### Full Source

The program is one frame loop: fetch band 0's color during VBLANK, release the beam onto it, then paint the fifteen remaining bands — each one a masked index and a table read — and finally let the animation clock advance the offset once every sixteen frames. The picture is 192 non-blanked scanlines: band 0's color is pre-loaded, so the beam-release line is band 0's *first* line and `PaintLines` paints the other eleven; every other band is one `PaintLines` call of twelve lines. The blank-on after the last band waits for HBLANK first (`STA WSYNC`), so the last band line is painted whole.

```asm
; =============================================================================
; LESSON 11: Lookup Tables — Data-Driven Programming
; =============================================================================
; Part 1: The 6502 CPU
;
; What this program does:
;   The "color wave": SIXTEEN equal bands of 12 scanlines each — 192
;   non-blanked lines.  Every band's color is read out of ONE 16-byte table
;   in ROM, as a cyclic rotation of that table:
;
;     band k  ->  Wave[(offset + k) AND $0F]      k = 0 (top) ... 15 (bottom)
;
;   `offset` is a single byte in RAM ($80).  Every 16 frames — about a
;   quarter second at 60 Hz — it advances by one, and every color in the
;   picture moves one band UP the screen: the entry that leaves the top band
;   reappears at the bottom.  When the offset passes 15, the AND $0F wraps it
;   back to 0, so the picture never blanks, never repeats a band, and can
;   never show anything the table does not contain.
;
;   The table is the ramp $1A + $0E x k, k = 0...15:
;
;     $1A $28 $36 $44 $52 $60 $6E $7C $8A $98 $A6 $B4 $C2 $D0 $DE $EC
;
;   Hue and luminance both step as you read down it, so the wave is a slow
;   rainbow sweep — with two dark notches: the entries $60 and $D0 land on
;   luminance 0, the palette's darkest step, and read as very dark purple and
;   very dark green.  Those two bands make the scroll easy to follow.
;
;   Nothing here computes a color and nothing branches on one: the picture is
;   ONE instruction — LDA Wave,X — applied to a moving index, and the index
;   mask (AND $0F) is what keeps that index inside the table's 16 bytes.
;
; What you'll learn:
;   - Storing data in ROM with !byte, and reading it back with LDA table,X
;   - Base + index: one instruction, any entry — no branch tree, no math
;   - Bounds discipline: AND #$0F keeps the index in 0...15 (Lesson 09's mask)
;   - Tables over time: the offset in RAM turns a fixed table into an animation
;   - The scroll math (offset + k) AND $0F and the seamless wrap it gives
;   - What a table buys: 16 bytes of ROM against color arithmetic or a
;     branch tree — and 4 cycles for the read
;
; Frame geometry: 192 non-blanked scanlines — 16 EQUAL bands of 12 lines.
;   Band 0's color is fetched during VBLANK, so the beam-release line is band
;   0's FIRST line and PaintLines paints the other 11; every other band is one
;   PaintLines call of 12 lines.  The blank-on after the last band waits for
;   HBLANK first (STA WSYNC), so the last band line is painted whole.
;   Same skeleton as Lesson 09.
;
; Build: acme -f plain -o build/lesson11.bin \
;        lessons/part1-6502-cpu/11-lookup-tables/11-lookup-tables.asm
; Run:   stella build/lesson11.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
Offset      = $80       ; the wave position: 0...15.  It is the table index
                        ;   of the TOP band; every band below it is the next
                        ;   table entry, so band k = Wave[(offset + k) AND $0F]
WaveTimer   = $81       ; frames left before the wave takes its next step
BandsLeft   = $82       ; bands still to paint this frame: 15 after band 0

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
BANDS       = 16        ; bands on the screen — one per table entry
LINES       = 12        ; scanlines per band (16 x 12 = 192 non-blanked lines)
STEP_FRAMES = 16        ; frames between wave steps (~1/4 second at 60 Hz)
INDEX_MASK  = $0F       ; keeps (offset + k) inside the 16-byte table: the
                        ;   table has 16 entries, numbered 0...15, and any
                        ;   index AND $0F lands on one of them

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    ; --- The wave starts at offset 0: the table in the order it is written ---
    LDA #$00
    STA Offset              ; TOP band = Wave[0] = $1A, next band = Wave[1] ...
    LDA #STEP_FRAMES
    STA WaveTimer           ; the first step comes after one full cadence

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK

; -----------------------------------------------------------------------------
; BAND 0 — fetched while the beam is still blanked
; -----------------------------------------------------------------------------
; Band 0 is the TOP band, and its color has to be in COLUBK before the release
; line's visible portion starts — the release line is band 0's first line, so
; the store lands in HBLANK right after VBLANK is cleared.
;
; Band 0's index is (offset + 0) AND $0F.  Offset is already kept in 0...15 by
; the code that writes it, so the mask here is a no-op — it is written anyway
; because every index in this program goes through the same mask, and one
; extra instruction during VBLANK is cheaper than one index that escapes.
    LDX Offset              ; X = the wave position, 0...15
    TXA                     ; A = the offset, so the mask below can act on it
OffsetLoaded:               ; debugger checkpoint: break here, A = X = offset
    AND #INDEX_MASK         ; (offset + 0) AND $0F — an index the table has
    TAX
    LDA Wave,X              ; band 0's color: the table does the looking up
WaveFetch0:                 ; debugger checkpoint: break here, A = color, X = index
    TAY                     ; park the color: +wait_timer clobbers A

    +wait_timer             ; finish the ~37 scanlines of VBLANK

    LDA #$00
    STA VBLANK              ; release the beam: this line is band 0's FIRST line
    TYA                     ; A = band 0's color again
    STA COLUBK              ; written in HBLANK, so the release line shows it
    LDY #LINES-1            ; Y = 11: release line + 11 painted = band 0's 12
    JSR PaintLines          ; paint them — A survives, X is never touched

; -----------------------------------------------------------------------------
; BANDS 1-15 — one table read per band, with a moving index
; -----------------------------------------------------------------------------
; Each band is two ideas: step the index once and fold it back into the table
; with the mask, then let the table supply the color.  There is no color
; arithmetic and no branch tree anywhere in this kernel — the table IS the
; picture, and the offset decides where in it the screen starts.
    LDA #BANDS-1            ; 15 bands left after band 0
    STA BandsLeft
BandLoop:
    INX                     ; X = offset + k for the band about to be painted
    TXA                     ; A = offset + k, which can be 16...30
    AND #INDEX_MASK         ; 16...30 comes back as 0...14 — that is the wrap ...
    TAX                     ;   ... and X is never allowed past 15
    LDA Wave,X              ; band k's color, straight out of the table
WaveFetch:                  ; debugger checkpoint: break here, A = color, X = index
    LDY #LINES              ; Y = 12: a full band
    JSR PaintLines          ; paint it — A and X survive, Y is used up
    DEC BandsLeft           ; one band fewer to go
    BNE BandLoop

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

; -----------------------------------------------------------------------------
; THE ANIMATION CLOCK — the wave steps once every STEP_FRAMES frames
; -----------------------------------------------------------------------------
; This countdown is what turns a fixed table into a moving picture.  It runs
; once per frame because the frame loop runs once per frame: 16 frames is
; about a quarter second, so the whole picture walks up one band per step and
; the table's 16 entries take a little over four seconds to come full circle.
    DEC WaveTimer           ; one frame closer to the next step
    BNE NoStep              ; not 0 yet -> the offset stays put
    LDA #STEP_FRAMES        ; countdown reached 0 -> reload it ...
    STA WaveTimer
    INC Offset              ; ... and move the wave one entry up the screen
    LDA Offset              ; A = offset + 1
    AND #INDEX_MASK         ; wrap 16 back to 0 — the same mask as the kernel
    STA Offset              ; Offset is 0...15 again
NoStep:
    JMP StartFrame          ; next frame

; =============================================================================
; SUBROUTINE: PaintLines — paint Y scanlines of the color in A
; =============================================================================
; How to call:   A = color byte, Y = scanline count, then JSR PaintLines
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for Y lines.  Writing the color
;                right after the WSYNC — instead of once before the loop —
;                puts the change in the first few cycles of the line, before
;                the TIA starts drawing on it, so band boundaries fall
;                exactly on a scanline instead of showing a notch where the
;                new color arrives mid-line.
; Registers:     A survives (still the color) and X is never touched — the
;                wave index lives in X, so the kernel depends on that — and
;                Y is used up: the line counter counts it down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.  Nothing
;                else is pushed inside, so callers can use the stack freely.
; =============================================================================
PaintLines:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEY                     ; one line fewer to go: 12, 11, ... 1
    BNE -                   ; loop until the line counter reaches 0
    RTS                     ; return; the return address comes off the stack

; =============================================================================
; DATA — the 16 wave colors, read as Wave,X
; =============================================================================
; Entry k is $1A + $0E x k: the hue nibble climbs while the luminance nibble
; steps down, so reading the table in order sweeps the color wheel with a
; light-to-dark ramp inside it.  Two entries — $60 and $D0 — land on
; luminance 0, the darkest step the palette has: they read as very dark purple
; and very dark green, and they mark the scroll clearly.
Wave:
    !byte $1A, $28, $36, $44    ; k = 0...3
    !byte $52, $60, $6E, $7C    ; k = 4...7
    !byte $8A, $98, $A6, $B4    ; k = 8...11
    !byte $C2, $D0, $DE, $EC    ; k = 12...15

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

> The complete, fully-commented source lives in
> `lessons/part1-6502-cpu/11-lookup-tables/11-lookup-tables.asm`.

### Code Walkthrough

#### Step 1 — Setup: three RAM bytes, four constants

```asm
Offset      = $80       ; the wave position: 0...15.  It is the table index
                        ;   of the TOP band; every band below it is the next
                        ;   table entry, so band k = Wave[(offset + k) AND $0F]
WaveTimer   = $81       ; frames left before the wave takes its next step
BandsLeft   = $82       ; bands still to paint this frame: 15 after band 0
```

Three bytes is the whole state of the animation. `Offset` is the table index of the top band; `WaveTimer` is the animation clock's countdown; `BandsLeft` is the kernel's own loop counter. The constants name the things that would otherwise be magic numbers:

```asm
BANDS       = 16        ; bands on the screen — one per table entry
LINES       = 12        ; scanlines per band (16 x 12 = 192 non-blanked lines)
STEP_FRAMES = 16        ; frames between wave steps (~1/4 second at 60 Hz)
INDEX_MASK  = $0F       ; keeps (offset + k) inside the 16-byte table
```

`Reset` then sets the starting state explicitly — offset 0, a full cadence on the clock — rather than trusting RAM to be zero:

```asm
    LDA #$00
    STA Offset              ; TOP band = Wave[0] = $1A, next band = Wave[1] ...
    LDA #STEP_FRAMES
    STA WaveTimer           ; the first step comes after one full cadence
```

#### Step 2 — Band 0: a table read during VBLANK

Band 0 is the top band, and the picture starts the instant the beam is released — so its color has to be in `COLUBK` before the release line's visible portion starts. The fetch happens while the beam is still blanked, and the store lands in HBLANK immediately after `VBLANK` is cleared:

```asm
    LDX Offset              ; X = the wave position, 0...15
    TXA                     ; A = the offset, so the mask below can act on it
OffsetLoaded:               ; debugger checkpoint: break here, A = X = offset
    AND #INDEX_MASK         ; (offset + 0) AND $0F — an index the table has
    TAX
    LDA Wave,X              ; band 0's color: the table does the looking up
WaveFetch0:                 ; debugger checkpoint: break here, A = color, X = index
    TAY                     ; park the color: +wait_timer clobbers A
```

Band 0's index is `(offset + 0) AND $0F` — the offset itself. The offset is already kept in 0…15 by the code that writes it, so the mask is a no-op here; it is written anyway because every index in this program goes through the same mask, and one instruction during VBLANK is cheaper than one index that escapes. The color then waits in Y across `+wait_timer` and lands in `COLUBK` in HBLANK, right after `VBLANK` is cleared — before the release line's visible pixels:

```asm
    LDA #$00
    STA VBLANK              ; release the beam: this line is band 0's FIRST line
    TYA                     ; A = band 0's color again
    STA COLUBK              ; written in HBLANK, so the release line shows it
    LDY #LINES-1            ; Y = 11: release line + 11 painted = band 0's 12
    JSR PaintLines          ; paint them — A survives, X is never touched
```

The eleven is the whole reason the geometry adds up: band 0 counts the release line inside its twelve, and `PaintLines` (Y = the line count, twelve writes of `COLUBK`, one per `WSYNC`) paints the rest. `PaintLines` promises A and X, and uses up Y — which is precisely what the next step needs.

#### Step 3 — Bands 1–15: step, mask, fetch, paint

```asm
    LDA #BANDS-1            ; 15 bands left after band 0
    STA BandsLeft
BandLoop:
    INX                     ; X = offset + k for the band about to be painted
    TXA                     ; A = offset + k, which can be 16...30
    AND #INDEX_MASK         ; 16...30 comes back as 0...14 — that is the wrap ...
    TAX                     ;   ... and X is never allowed past 15
    LDA Wave,X              ; band k's color, straight out of the table
WaveFetch:                  ; debugger checkpoint: break here, A = color, X = index
    LDY #LINES              ; Y = 12: a full band
    JSR PaintLines          ; paint it — A and X survive, Y is used up
    DEC BandsLeft           ; one band fewer to go
    BNE BandLoop
```

Six instructions per band and a call — `INX`, `TXA`, `AND`, `TAX`, `LDA Wave,X`, `LDY #LINES`, then `JSR PaintLines` (with the loop's `DEC`/`BNE` after it): the index steps, the mask folds it back into the table, the load fetches the color, the painter paints it. Two design choices are worth naming:

- **The index lives in X, so the line counter lives in Y.** `PaintLines` counts lines in Y and never touches X; that is why the wave index survives the call and why the painter's register contract is part of the kernel's design rather than a comment on the side.
- **No branch tree.** There is no `CMP`-and-`BEQ` ladder deciding which color a band gets, and no arithmetic building the color byte: the *only* thing that varies from band to band is an index, and the table turns it into a color.

#### Step 4 — Overscan and the animation clock

The kernel ends in HBLANK, not mid-line:

```asm
    STA WSYNC               ; wait for HBLANK before blanking: the last band
                            ; line is being drawn right now, so writing VBLANK
                            ; here would clip it partway across.  WSYNC lets the
                            ; line finish; the blank-on starts on the next line
    LDA #$02
    STA VBLANK
```

Then the countdown that moves the wave runs once per frame, because the frame loop runs once per frame:

```asm
    DEC WaveTimer           ; one frame closer to the next step
    BNE NoStep              ; not 0 yet -> the offset stays put
    LDA #STEP_FRAMES        ; countdown reached 0 -> reload it ...
    STA WaveTimer
    INC Offset              ; ... and move the wave one entry up the screen
    LDA Offset              ; A = offset + 1
    AND #INDEX_MASK         ; wrap 16 back to 0 — the same mask as the kernel
    STA Offset              ; Offset is 0...15 again
NoStep:
    JMP StartFrame          ; next frame
```

This is Lesson 09's animation clock with two changes: what it moves is a *byte in RAM* instead of a pattern, and the wrap uses a mask instead of a compare. Sixteen frames per step is about a quarter second at the TV's ~60 frames per second, so a full turn of the table takes a little over four seconds (16 steps x 16 frames = 256 frames). And because the offset is masked on the way *in*, the kernel's own mask can never see anything but 0…15 — the two masks are the same discipline applied twice.

#### Step 5 — The data, and what bounds it

```asm
Wave:
    !byte $1A, $28, $36, $44    ; k = 0...3
    !byte $52, $60, $6E, $7C    ; k = 4...7
    !byte $8A, $98, $A6, $B4    ; k = 8...11
    !byte $C2, $D0, $DE, $EC    ; k = 12...15
```

The table is the picture. Its sixteen bytes are the entire visual content of this ROM: change one and the corresponding band changes its color in every frame of the animation, in every position it ever visits. Nothing else in the program describes what the wave looks like.

There is no alignment directive here, and this table does not need one: it assembles at `$F08C`, so the highest address any index can reach is `$F09B` — still inside page `$F0`, which is why every fetch costs exactly the base 4 cycles. (`!align 15, 0, 0` before a table — the habit the first and third exercises follow — makes that guarantee explicit instead of accidental, since nothing else pins a table to a 16-byte boundary; the third field is the pad byte, and `0` is what fills the gap with zeros.) The mask, on the other hand, is load-bearing: it is the only thing standing between a 16-entry table and an index that can reach 30.

## What You Should See

Sixteen horizontal bands of exactly the same height — twelve scanlines each, 192 non-blanked lines in total — forming a smooth rainbow sweep with two dark notches in it. The wave is moving: every quarter second or so the whole pattern shifts one band **upward**, each color sliding from one band to the one above it, with the color that leaves the top band reappearing at the bottom. There is never a black gap, never a duplicated band: at every instant the screen is the table's sixteen entries, in order, rotated to wherever the offset has walked them.

Here is the wave at **offset 0** — the table in the order it is written, read from the top down: gold, orange-brown, orange-red, red, magenta, a very dark purple, light violet, violet, blue-violet, blue, steel blue, teal-green, green, a very dark green, bright yellow-green, and a yellow-green at the bottom:

![Stella running the Lesson 11 ROM: sixteen equal bands of the color wave at offset 0 — gold at the top through reds, magenta, a very dark purple, violets, blues, greens and a very dark green to a yellow-green at the bottom](/images/lesson11/lookup-wave.png)

<RomPlayer rom="/roms/part1-6502-cpu/11-lookup-tables/11-lookup-tables.bin" title="Lesson 11 — Lookup Tables" />

And here it is later in the same session, at **offset 4**: the same sixteen colors in the same cyclic order, but each one has moved four bands up the screen — the magenta band that was fifth from the top is now the top band, and the red band that was fourth is now the bottom one:

![Stella running the Lesson 11 ROM four table steps later: the identical sixteen bands, shifted four entries — magenta at the top and red at the bottom](/images/lesson11/lookup-wave-shifted.png)

The second capture is four steps of the table ahead of the first — at sixteen frames per step, about one second of play at 60 Hz. Sixteen steps bring the picture exactly back to the start, because sixteen steps of a sixteen-entry table is one full turn.

Open the debugger (`stella -debug`, then `Tab` or the *Debugger* menu) and check the machinery:

- **`Offset` at RAM `$80`** — break at `OffsetLoaded` and A (and X) hold the wave position. Watch it for a while: it stays on each value for exactly 16 frames, then steps 0, 1, 2, … 15, and after 15 comes 0 again. That single byte is the animation.
- **`WaveTimer` at `$81` and `BandsLeft` at `$82`** — the two countdowns. `WaveTimer` runs 16 down to 0 once per 16 frames; `BandsLeft` runs 15 down to 1 once per *frame*, one decrement per band.
- **`WaveFetch0`** — once per frame, band 0's read: break there and A is the top band's color while X is the offset. Step the breakpoint through a full cycle and A walks the whole table: `$1A`, `$28`, `$36`, … `$EC`.
- **`WaveFetch`** — fifteen hits per frame, one per painted band. At every one of them A is the fetched color and X is the masked index, and X *never* leaves 0…15: that is the mask doing its job. A always equals `Wave[X]`.
- **The table itself** — the sixteen bytes after the `Wave` label (`$F08C` in the ROM built here; the label address comes from ACME's symbol list — the shipped `.bin` carries no names). Edit one byte in the debugger's memory view and the corresponding color changes in every band that passes through it.

Each breakpoint pauses *before* the instruction it marks, which is why the fetch checkpoints sit immediately after their `LDA`.

## Exercises

### Exercise 1: A Table of Your Own

**Challenge:** the lesson ROM hands you both the table and the moving offset. Write your *own* 16-byte color table and display it with `LDA Palette,X` — sixteen equal bands, one per entry, top to bottom, with no offset and no scroll: the table is the picture, standing still.

**Hints:**
1. `!byte` with sixteen values is the table; `LDA Palette,X` is the reader. Let X be both the band number and the table index and the display loop becomes a single loop.
2. With an index that only counts up, the bound is a compare, not a mask: `INX` / `CPX #BANDS` / `BNE BandLoop` stops at the table's edge (Lesson 06's count-up loop).
3. Band 0's color has to be in `COLUBK` before the release line's visible portion starts — fetch it during VBLANK, park it in Y while `+wait_timer` runs, and store it in HBLANK right after clearing VBLANK. Then paint the rest with a line-counting subroutine that leaves X alone.

**Expected Result:** sixteen equal bands (192 non-blanked lines) of constant brightness: light gray at the top, then the color wheel in order — yellow, orange, peach, pink, violet, blue-violet, blue, light blue, aqua, green, the yellow-greens — finishing in a yellow-orange at the bottom. Nothing moves, and every band is exactly one table entry.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: A Two-Table Movie

**Challenge:** let one color fill the whole screen and hold each color for its own time. Two tables drive the picture — `Colors[k]` says what to show and `Durations[k]` says how many frames to hold it — so the screen becomes a movie whose timing is data.

**Hints:**
1. The step index has to survive from frame to frame, so it lives in RAM. Load X from it whenever a table is read, and read *both* tables with the same X — that is what pairs color *k* with duration *k*.
2. Lesson 09's animation clock returns, but its reload value now comes from a table: `DEC Hold` / `BNE` / on zero, advance the step and load `Durations[X]` into the hold.
3. The whole visible field is one `COLUBK` write — write the color after releasing the beam and nothing else changes it for the rest of the frame. Then count out 192 lines with a `WSYNC` loop (release line + 191), and remember the `STA WSYNC` before blanking the beam again.

**Expected Result:** the full screen changes color at the frame boundary, and each color stays for its own duration: the first color holds for 8 frames, the next for 12, then 16, 20, … up to 68 frames for the last one — visibly longer holds as the movie runs, then the cycle starts over. The debugger shows the step index and the countdown, and a breakpoint on the color fetch reports the same frame number sequence the `Durations` table predicts.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: A Pointer Table Picks the Wave *(Stretch Goal)*

**Challenge:** keep the wave scrolling, but let a **pointer table** choose which of two palettes it reads. `WavePtrs` holds two `!word` entries — the 16-bit addresses of `WaveA` and `WaveB` — and every two seconds the selector flips, so the picture changes palette while it keeps moving.

**Hints:**
1. `!word WaveA` stores the *address* of the table, low byte first. That is the new idea: a table whose entries are tables.
2. `(zp,X)` reads pointers out of **zero page**, so a ROM pointer table cannot use it. Load the chosen entry's two bytes separately into a zero-page pair — `LDA WavePtrs,X` then `LDA WavePtrs+1,X` — and read *through* the pair with `(zp),Y` (Lesson 10's pointer mode).
3. Each entry is two bytes wide, so the selector has to be doubled: `TXA` / `ASL` / `TAX` turns 0 and 1 into offsets 0 and 2. Flip the selector with `EOR #$01` and a frame countdown (Lesson 09's flip).

**Expected Result:** the lesson's scrolling wave for about two seconds — one table read through the pointer — then the same colors read backwards for about two seconds, then back again, forever. The wave keeps stepping one band per step in both palettes; only the table the pointer aims at changes. In the debugger, `$80/$81` hold the current wave's address and change at the switch.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A lookup table turns an indexed load into a program structure** — `!byte` data at a label, `LDA table,X` to read entry X: 16 bytes of ROM and a 4-cycle fetch instead of sixty-odd bytes of compares and branches
- ✅ **One instruction reads any entry** — base plus index, chosen by an index register; that is why Lesson 10's `LDA table,X` mattered, and it is the idiom the whole course keeps using
- ✅ **The 6502 does not check your bounds — you do** — `AND #$0F` wraps an index for a 16-entry table, `CPX #BANDS` / `BNE` stops a count-up loop at the edge; an index that escapes reads whatever bytes follow the table and paints a wrong color with no error
- ✅ **The mask *is* the wrap** — `(offset + k) AND $0F` keeps the sum 0…30 inside a 16-entry table and makes the wave seamless: every frame shows all sixteen entries exactly once, with no blank band and no repeat
- ✅ **A fixed table plus a moving offset is an animation** — the offset byte in RAM is the clock's memory; 16 frames per step walks the picture one band up the screen, and a full turn is 16 steps
- ✅ **Tables hold whatever you decide they hold** — colors, durations, and addresses: two tables read with one index become a script with per-step timing, and an `!word` pointer table selects a whole table with one index
- ✅ **Every index needs a matched bound and every table needs a stated size** — the mask constant, the compare constant, or the pointer table's two entries; write the size down next to the data, because the CPU will not

## What's Next

That is Part 1 complete: you know the 6507's registers, flags, branches, subroutines, bit operations, every addressing mode, and now how to drive a program from data in ROM. [Lesson 12: The NTSC Frame](/part2-tv-and-tia/12-the-ntsc-frame) leaves the CPU and meets the television — where the picture actually comes from, what VSYNC/VBLANK/overscan really mean to the beam, and how the 262-scanline frame this course has been painting all along is built line by line.
