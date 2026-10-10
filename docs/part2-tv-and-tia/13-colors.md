---
title: "Lesson 13: Colors — Painting the Screen"
description: "The TIA's color byte, decoded: %HHHHLLL0 — hue and luminance, 16 by 8, 128 colors from one byte. Build a live palette explorer whose sixteen hue bands step down through every luminance level (7 → 0, wrapping), learn the course's named-color table, and try three exercises: swapped axes, the chart-match table, and a one-hue fade."
prev:
  text: "Lesson 12: The NTSC Frame"
  link: "/part2-tv-and-tia/12-the-ntsc-frame"
next:
  text: "Lesson 14: WSYNC and Timing"
  link: "/part2-tv-and-tia/14-wsync-and-timing"
---

# Lesson 13: Colors — Painting the Screen

> **Part 2: TV & TIA** · Estimated time: 45 minutes
> **Prerequisites:** Lesson 12 (the frame this lesson steps inside), Lesson 11 (indexed table reads — the hue table), Lesson 09 (bit masks — the hue wrap in Exercise 1)
> **You will learn:** what the TIA's color byte actually is — `%HHHHLLL0`: a hue (16 values) and a luminance level (8 values); where "red" and "blue" live in that grid; why luminance 0 is the palette's darkest step, not a hole in the screen; how to build color bytes in code and read them back in the debugger; and that the object color registers (`COLUP0`, `COLUP1`, `COLUPF` — named here for reference) use the very same byte
> **You will build:** the "palette explorer" ROM — sixteen equal hue bands that step down through every luminance level, one step every ~2 seconds, wrapping 7 → 0 → 7 so a full ~16-second cycle shows all 128 colors — plus three exercises: the same picture with its axes swapped, a still chart of the course's named colors, and a one-hue fade that breathes through all eight levels

## Introduction

Every color you have written since Lesson 04 has been a hexadecimal number taken on faith. `$42` paints "red" because the course said so; `$C8` paints "green"; the bands line up because the bytes work. But a TIA color byte is not an arbitrary value — it is a little structured thing, and its structure is worth knowing before every later part of the course starts coloring sprites, playfields and scores with it.

The structure is two axes packed into one byte: a **hue** (16 positions around a color wheel) and a **luminance** level (8 brightness steps). Sixteen times eight is 128 — that is the entire color vocabulary of the NTSC machine, and it comes out of a single byte with one spare bit. "Red" is not a value, it is a *place* in that grid: hue 4 at a low luminance. Today's companion program makes the grid visible.

`13-colors.asm` is a **palette explorer**: sixteen equal bands, one per hue, and the whole picture descends through the eight luminance levels — one step every two seconds, then back up to the top. On the screen it is a slow, deliberate dimming; in the debugger it is a set of numbers you can read directly, because every band's byte is *constructed* as you watch: hue from a table, luminance from RAM. By the end you will be able to look at any color byte and decode it — and to build any of the 128 on purpose.

::: details TypeScript Equivalent
A modern color type is a packed structure too — this is the TIA's, in its entirety:

```typescript
// The whole TIA color model fits in one byte: %HHHHLLL0
const color = (hue << 4) | (luminance << 1);   // hue: 0-15, luminance: 0-7

const RED = (4 << 4) | (1 << 1);   // $42 — "red" is a place, not a value
```

Where CSS gives you `hsl(h, s%, l%)` with continuous components, this palette is a *closed grid*: 16 hues by 8 brightnesses, nothing in between. That sounds limiting — but game art is built from those exact steps, and knowing the grid is what lets you pick colors that read well on a television instead of guessing hex codes.
:::

## Theory

### Section 1: The Palette Byte, Decoded

Every color byte has the same shape:

```text
bit:     7  6  5  4  |  3  2  1  |  0
        %H  H  H  H  |  L  L  L  |  0
         └── hue ──┘   └ luminance ┘  unused (always 0)
```

- **Hue** (high nibble, 4 bits): which color, 0–15.
- **Luminance** (bits 3–1, 3 bits): how bright, 0–7. Level 7 is the brightest.
- **Bit 0**: unused. It is always 0, which is why all 128 colors have an even byte value.

The arithmetic is worth memorizing: **byte = hue × 16 + level × 2**. And it works backwards. The four bands from Lesson 12 decode like this:

| Byte | Hue | Level | Reads as |
|---|---|---|---|
| `$42` | 4 | 1 | red — hue 4 at a low level |
| `$84` | 8 | 2 | blue |
| `$C8` | 12 | 4 | green |
| `$1A` | 1 | 5 | gold |

Until recently those were four opaque hex numbers; now they are four coordinates. (Say the hue out loud, then the level: "$42 is hue four, level one." That habit pays off for the rest of the course.)

### Section 2: Sixteen Hues — the Wheel

Hues 1 through 15 walk around a color wheel: gold, orange, peach, red, pink, violets, blue, cyan, greens, yellow-greens — then back to gold. Hue 0 is the odd one out: it is not on the wheel, it is the neutral column — grey, at every level, and pure black at level 0.

Here is the course's **named-color table** — one row per band, one example byte per hue. These are the names the lessons use from here on, and the example column is what Exercise 2 puts on the screen:

| Band | Hue | Name | Example byte | Where it comes from |
|---|---|---|---|---|
| 0 | 0 | light gray | `$0E` | Lesson 11's chart, brightest step |
| 1 | 1 | gold | `$1A` | Lesson 08's bottom band |
| 2 | 2 | orange | `$2E` | this lesson (bright form) |
| 3 | 3 | peach | `$3E` | this lesson (bright form) |
| 4 | 4 | red | `$42` | Lesson 08's top band |
| 5 | 5 | pink | `$5E` | this lesson (bright form) |
| 6 | 6 | light violet | `$6E` | Lesson 11's wave |
| 7 | 7 | violet | `$7E` | this lesson (bright form) |
| 8 | 8 | blue | `$84` | Lesson 12's second band |
| 9 | 9 | light blue | `$9E` | this lesson (bright form) |
| 10 | 10 | aqua | `$AE` | this lesson (bright form) |
| 11 | 11 | teal-green | `$BE` | this lesson (bright form of Lesson 11's `$B4`) |
| 12 | 12 | green | `$C8` | Lesson 12's third band |
| 13 | 13 | bright yellow-green | `$DE` | Lesson 11's wave |
| 14 | 14 | yellow-green | `$EE` | this lesson (bright form) |
| 15 | 15 | yellow | `$FE` | this lesson (bright form) |

*The course's named-color table. Exercise 2 renders the example column as a still chart; the names stay in this table and that exercise's caption — never on your screen, because on-screen text needs the playfield and sprites that arrive in later parts.*

One warning about naming: these names are **course-local**, and a hue can read differently at different levels. Hue 4 at level 1 (`$42`) is plainly red; the same hue at level 7 (`$4E`) is a light salmon-pink. Earlier lessons named a few hues differently because they were looking at other bytes of the same hue — Lesson 11's wave calls bright hue 8 "blue-violet" where this table's `$84` is simply blue. Same hue, different level, different word: this table's example bytes are the course's reference points. When a name and a byte disagree, the byte wins — look at the screen, not the vocabulary.

### Section 3: Eight Luminance Levels — the Brightness Axis

The other axis is simpler: eight steps, and each step up adds 2 to the byte. A hue's *column* is eight colors:

```text
hue 4, level 7 → $4E   brightest: light salmon-pink
hue 4, level 6 → $4C
hue 4, level 5 → $4A
hue 4, level 4 → $48
hue 4, level 3 → $46
hue 4, level 2 → $44
hue 4, level 1 → $42   the course's red
hue 4, level 0 → $40   dark red — not black
```

Three things to notice:

1. **Stepping the luminance changes the mood, not the identity.** A picture dimmed one level at a time stays the same picture; that is why game-state transitions (night falls, a life is lost) can be done with a single byte per object.
2. **Level 0 is the palette's darkest step, not a hole.** For every colored hue it renders as a very dark version of that color — Lesson 11's wave showed `$60` and `$D0` as very dark purple and very dark green. Only the neutral column's `$00` is true black.
3. **The grid is finite and ordered.** There is no color "between" `$4C` and `$4E`; every choice is one of 128. Fast, exact, and identical on every NTSC TIA — no color profiles, no gradients. (PAL consoles use a different, 104-color palette — see Lesson 12's note on NTSC vs PAL.)

> **Looking ahead (name-only):** the object color registers — `COLUP0`, `COLUP1`, and `COLUPF` — take the exact same byte. Parts 3 and 4 will color players, missiles and the playfield with what you learn here; today the whole byte goes to `COLUBK`, the background.

### Section 4: 128 Colors, One Cycle

Sixteen hues by eight levels makes 128 colors, and the companion ROM shows you all of them on one slow schedule:

- **120 frames per step.** The frame loop's counter counts down once per frame; every 120th tick the picture steps one level down. At ~59.9 frames per second that is about two seconds per step.
- **7 → 0 → 7.** The step walks *down* from the brightest level, and when it passes 0 it wraps back to 7. Eight steps make a full cycle: 8 × 120 = 960 frames, about sixteen seconds — and in that time every band has shown every level, so all 128 colors have appeared.
- **Stable while it holds.** Between steps nothing drifts; the same sixteen bands hold for the whole 120 frames. Watching the picture dim is watching the *output*; the debugger section below shows the numbers moving behind it.

::: details TypeScript Equivalent
The clock is not a timer — it is the frame loop itself, rewritten in TypeScript shape:

```typescript
let framesLeft = 120, level = 7;

function frame() {              // once per pass of the loop = once per TV frame
  if (--framesLeft === 0) {
    framesLeft = 120;           // reload: another ~2 seconds
    level = (level + 7) & 7;    // 7 -> 6 -> ... -> 0 -> 7  (level - 1, mod 8)
  }
  paint(level);                 // the loop IS the clock
  requestAnimationFrame(frame);
}
```

On the web you would reach for `setInterval`; on the 2600 there is no timer running the show — the frame loop runs sixty times a second whether you count or not, so the cheapest clock is a byte that goes down by one every pass.
:::

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson13.bin \
  lessons/part2-tv-and-tia/13-colors/13-colors.asm
stella build/lesson13.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`, all in the same directory.

### Full Source

The program keeps Lesson 12's counted frame exactly as it was, and adds two things: a 16-byte table of hue nibbles and a three-byte luminance clock in RAM. Sixteen of the palette's 128 colors are on screen at any instant — one per band.

```asm
; =============================================================================
; LESSON 13: Colors — Painting the Screen
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   The "palette explorer": SIXTEEN equal bands of twelve lines — one band
;   per hue, 0 (light gray) at the top through 15 (yellow) at the bottom.
;   Every band's color byte is built from two parts:
;
;     %HHHHLLL0        HHHH = hue (the band number)
;                      LLL  = luminance (the picture's brightness level)
;                      bit 0 is unused — it is always 0
;
;   and the whole picture descends through the eight luminance levels,
;   7 (brightest) down to 0, one step every 120 frames — about two seconds
;   — then wraps back to 7.  A full cycle is 8 x 120 frames, about
;   sixteen seconds, and shows all 128 colors the TIA has: 16 hues x
;   8 luminance levels.
;
;   The frame is Lesson 12's, unchanged: VSYNC 3, VBLANK 37, visible 192
;   (16 x 12), overscan 30 — 262 counted scanlines per pass of the loop.
;   The luminance clock is a RAM byte decremented once per frame; when it
;   reaches 0 the level steps and the byte reloads with 120.
;
; What you'll learn:
;   - the palette byte: hue in the high nibble, luminance in bits 3-1
;   - 16 hues x 8 luminance levels = 128 colors
;   - luminance 0 is the palette's darkest step, not pure black
;   - building color bytes in code — a hue table ORed with a luminance field
;   - reading the picture back in the debugger: COLUBK shows the byte
;   - COLUP0, COLUP1 and COLUPF use the same byte for objects (later parts)
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VisibleStart (37), Band0Write,
;   BandWrite, LumStep, OverscanStart (229).  See the lesson document
;   for what each one watches.
;
; Build: acme -f plain -o build/lesson13.bin \
;        lessons/part2-tv-and-tia/13-colors/13-colors.asm
; Run:   stella build/lesson13.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame, the palette, and the clock
; =============================================================================
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
BANDS          = 16     ; visible bands — one per hue
LINES          = 12     ; scanlines per band (16 x 12 = 192 visible lines)
OVERSCAN_LINES = 30     ; blanked lines after the picture
STEP_FRAMES    = 120    ; frames per luminance step (~2 seconds at ~60 Hz)

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
FrameCounter = $80      ; frames left in this luminance step: 120 -> 0
Luminance    = $81      ; the current level, 0-7 (7 = brightest)
LumField     = $82      ; the level as the palette byte's field: level x 2

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    ; --- Start bright: level 7, its doubled field, and a full step ---
    LDA #$07
    STA Luminance           ; level 7 = brightest
    ASL                     ; 7 x 2 = $0E — the palette byte's field
    STA LumField
    LDA #STEP_FRAMES
    STA FrameCounter        ; 120 frames until the first step

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; THE LUMINANCE CLOCK — one tick per frame, one step per 120 ticks
; -----------------------------------------------------------------------------
; FrameCounter counts down once per pass of the loop.  At 0 the picture
; steps one luminance level darker: 7, 6, 5, ... 0, and then — because DEC
; past 0 wraps to $FF, whose sign bit is set — the wrap branch puts it back
; at 7.  The field the palette byte needs is level x 2, rebuilt each step.
    DEC FrameCounter
    BNE NoStep              ; still counting: mid-step, nothing changes
    LDA #STEP_FRAMES
    STA FrameCounter        ; reload: another 120 frames to the next step
    DEC Luminance
    BPL LumStep             ; landed on 0-7: use it as-is
    LDA #$07                ; DEC wrapped past 0 to $FF: back to brightest
    STA Luminance
LumStep:                    ; debugger checkpoint: one hit per 120 frames
    LDA Luminance
    ASL                     ; level x 2 = the luminance field
    STA LumField
NoStep:
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines (Lesson 12)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = start VSYNC
    STA VSYNC
    STA WSYNC               ; VSYNC line 1 ends
    STA WSYNC               ; VSYNC line 2 ends
    STA WSYNC               ; VSYNC line 3 ends
    LDA #$00
    STA VSYNC               ; pulse off — exactly 3 lines

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 blanked lines (Lesson 12)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDX #VBLANK_LINES
VblankLines:
    STA WSYNC
    DEX
    BNE VblankLines

VisibleStart:               ; debugger checkpoint: visible's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — 192 lines = sixteen bands of 12, one per hue
; -----------------------------------------------------------------------------
; Band k's color is the palette byte for hue k at the current luminance:
; the hue nibble comes out of the table, the luminance field out of RAM.
    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
    LDX #$00
    LDA HueNibbles,X        ; band 0: the hue nibble, $00
    ORA LumField            ; OR in the luminance field
    STA COLUBK              ; lands in HBLANK: the release line shows it
Band0Write:                 ; debugger checkpoint: A = 0 | field (see the doc)
    LDY #LINES-1            ; Y = 11: release line + 11 painted = band 0's 12
    JSR PaintLines
    LDX #$01                ; bands 1...15 remain
BandLoop:
    LDA HueNibbles,X        ; this band's hue nibble (k << 4)
    ORA LumField            ; OR in the luminance field: k<<4 | level<<1
BandWrite:                  ; debugger checkpoint: A = hue*16 + level*2, X = hue
    LDY #LINES              ; a full band of 12
    JSR PaintLines
    INX                     ; next band
    CPX #BANDS              ; 0...15 — the index IS the hue
    BNE BandLoop

    STA WSYNC               ; let the last band line finish before blanking
    LDA #$02
OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
    STA VBLANK
    LDX #OVERSCAN_LINES
OverscanLines:
    STA WSYNC
    DEX
    BNE OverscanLines
    JMP StartFrame          ; 262 lines done: next frame

; =============================================================================
; SUBROUTINE: PaintLines — paint Y scanlines with the color in A
; =============================================================================
; How to call:   A = color byte, Y = scanline count, then JSR PaintLines
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for Y lines — every write lands in
;                HBLANK, so band boundaries fall exactly on scanlines.
; Registers:     A survives, X is never touched (the hue index lives there),
;                Y is used up counting lines down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.
; =============================================================================
PaintLines:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEY                     ; one line fewer to go
    BNE -
    RTS

; =============================================================================
; DATA — the hue nibbles: entry k is k << 4, k = 0...15
; =============================================================================
; The table holds the palette byte's HIGH nibble and nothing else; the low
; nibble's luminance field is ORed in from RAM at paint time.  Aligned so
; X can never push a read across a page: every fetch costs 4 cycles.
    !align 15, 0, 0
HueNibbles:
    !byte $00, $10, $20, $30    ; hues 0-3  (0 = light gray)
    !byte $40, $50, $60, $70    ; hues 4-7  (4 = red, 7 = violet)
    !byte $80, $90, $A0, $B0    ; hues 8-11 (8 = blue, 11 = teal-green)
    !byte $C0, $D0, $E0, $F0    ; hues 12-15 (12 = green, 15 = yellow)

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

> The complete, fully-commented source lives in
> `lessons/part2-tv-and-tia/13-colors/13-colors.asm`.

### Code Walkthrough

#### Step 1 — The hue nibbles

```asm
    !align 15, 0, 0
HueNibbles:
    !byte $00, $10, $20, $30    ; hues 0-3  (0 = light gray)
    !byte $40, $50, $60, $70    ; hues 4-7  (4 = red, 7 = violet)
    !byte $80, $90, $A0, $B0    ; hues 8-11 (8 = blue, 11 = teal-green)
    !byte $C0, $D0, $E0, $F0    ; hues 12-15 (12 = green, 15 = yellow)
```

The table carries only the **high nibble** — hue × 16, which is hue shifted left four times. The low nibble is deliberately missing: it arrives at paint time from RAM, because it is the part that changes. This is the same split the byte itself has, and splitting it the same way in code is the whole trick. The table sits at a 16-byte boundary so that an indexed read can never cross a page.

#### Step 2 — The luminance clock

```asm
    DEC FrameCounter
    BNE NoStep              ; still counting: mid-step, nothing changes
    LDA #STEP_FRAMES
    STA FrameCounter        ; reload: another 120 frames to the next step
    DEC Luminance
    BPL LumStep             ; landed on 0-7: use it as-is
    LDA #$07                ; DEC wrapped past 0 to $FF: back to brightest
    STA Luminance
LumStep:
    LDA Luminance
    ASL                     ; level x 2 = the luminance field
    STA LumField
```

Three bytes of state do the whole job. `FrameCounter` counts down once per pass of the loop; when it reaches 0 the level drops by one. The wrap is Lesson 07's count-down behaviour put to work: `DEC` past `$00` lands on `$FF`, whose top bit is set — so the branch *falls through* exactly when the level left the 0–7 range, and the reload puts it back at 7. The last two instructions turn the level into the field the palette byte needs: level × 2. Multiply by two is `ASL`, and 7 × 2 = `$0E` — bit 0 of the byte stays 0 forever, which is exactly why the unused bit is unused.

#### Step 3 — The frame is Lesson 12's, unchanged

VSYNC 3 lines, VBLANK 37, visible 192, overscan 30 — the same counted `WSYNC` frame, byte for byte, from the previous lesson. Nothing about the clock changed the frame's shape, and the debugger checkpoints confirm it: `StartFrame` still reports scanline 259, `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229. If that frame section looks like a copy, that is on purpose: a frame you understand is machinery you can reuse. (Lesson 15 will hand the two blanked waits to the RIOT timer and shrink the code; until then, counting lines keeps the ledger exact.)

#### Step 4 — Sixteen bands, sixteen bytes

```asm
    LDX #$00
    LDA HueNibbles,X        ; band 0: the hue nibble, $00
    ORA LumField            ; OR in the luminance field
    STA COLUBK              ; lands in HBLANK: the release line shows it
Band0Write:
    LDY #LINES-1            ; Y = 11: release line + 11 painted = band 0's 12
    JSR PaintLines
    LDX #$01
BandLoop:
    LDA HueNibbles,X        ; this band's hue nibble (k << 4)
    ORA LumField            ; OR in the luminance field: k<<4 | level<<1
BandWrite:
    LDY #LINES
    JSR PaintLines
    INX
    CPX #BANDS
    BNE BandLoop
```

`ORA` completes the byte because the two halves do not overlap: the high nibble is all bits where the field has none, and the field occupies bits 3–1. For hue 4 at level 7 that is `$40 OR $0E` = `$4E` — hue four, level seven, one byte. Band 0 is written before the painter starts (the release line belongs to it, as always), and the loop walks hues 1–15 through the same two instructions. X is the band number *and* the table index *and* half of the color — the single-index trick this kernel keeps coming back to.

Count the release-line sequence exactly: the loop's `DEX`/`BNE` tail (4 cycles), `LDA #$00` (2), `STA VBLANK` (3), `LDX #$00` (2), `LDA HueNibbles,X` (4), `ORA LumField` (3), `STA COLUBK` (3) — **21 cycles**. The store goes out on cycle 20 (color clocks 60–63 of HBLANK's 68), a few clocks before the visible pixels begin, so the first visible line is already band 0's color. Every later write happens right after a `WSYNC`, which puts it in HBLANK by construction.

#### Step 5 — Reading the picture back

There are no computed colors on screen — every band is `hue × 16 + level × 2`, built from two places you can watch. The checkpoint table in "What You Should See" maps the labels to the numbers; in short: `Band0Write` shows the *luminance* half (`$0E` at level 7), and `BandWrite` shows full bytes walking `$1E, $2E, … $FE` with X counting 1 through 15 — hue times sixteen plus the level's two, accumulating in the accumulator.

## What You Should See

Sixteen equal bands fill the picture window — one per hue, top to bottom in wheel order: light gray, then the gold-orange-peach-red pinks, the violets and blues, the greens and yellow-greens, finishing in yellow. Hold on the first frames and everything is at its brightest — luminance 7. Then, about every two seconds, the whole picture dims one step, holds for two seconds, dims again: a deliberate, uniform descent from 7 down through 0 and back up to 7. Nothing flickers, nothing drifts; the only thing changing is one digit of sixteen numbers.

![Stella running the Lesson 13 ROM at luminance 7: sixteen equal bands, light gray at the top through the color wheel, all at full brightness, in Stella's window titled 13-colors](/images/lesson13/palette-hues.png)

*Luminance 7 — the brightest level. Every band is hue k at level 7: the byte `k×16 + $0E`. (Captured at the level's second appearance, about sixteen seconds in; the opening frames are identical.)*

<RomPlayer rom="/roms/part2-tv-and-tia/13-colors/13-colors.bin" title="Lesson 13 — Colors" />

Twelve seconds in — six steps later — the same sixteen hues have descended to luminance 1:

![Stella running the Lesson 13 ROM at luminance 1: the same sixteen hue bands, each drawn at its darkest readable step](/images/lesson13/palette-dim.png)

*Luminance 1 — the same picture at level 1: the byte `k×16 + $02`. Only the brightness axis moved; the hues and the band boundaries are identical.*

Open the debugger (`stella -debug`) and watch the numbers move. Each checkpoint marks one fact:

| Checkpoint | Address in the shipped ROM | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F019` | scanline 259, every frame | the frame top (same as Lesson 12) |
| `VblankStart` | `$F03C` | scanline 0 | VBLANK's first line |
| `VisibleStart` | `$F047` | scanline 37 | the picture's first line |
| `Band0Write` | `$F054` | A = the luminance field | band 0's byte, as stored (`$0E` at level 7) |
| `BandWrite` | `$F060` | A = hue×16 + level×2, X = hue | every band's byte as it is built |
| `LumStep` | `$F029` | one hit per step | the luminance clock ticking |
| `OverscanStart` | `$F06E` | scanline 229 | overscan's first line |

(Stella counts the frame from the VSYNC-off boundary, so the four scanline values read 259/0/37/229 — the same numbers as Lesson 12, which is how you know the frame survived.)

The course's state-log method makes the same facts into text you can diff:

```bash
# assemble with a symbol list to get the checkpoint addresses
acme -f plain -l build/lesson13.sym -o build/lesson13.bin \
  lessons/part2-tv-and-tia/13-colors/13-colors.asm
grep -E "LumStep|Band0Write|BandWrite" build/lesson13.sym

# then log one breakpoint per run
stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F029' \
  docs/public/roms/part2-tv-and-tia/13-colors/13-colors.bin
```

- **`$F029` (`LumStep`)**: the log's frame column advances by exactly 120 — the first hit lands at frame 119, then 239, 359, and so on. That is the "frame counter" from the code, read from the television's side.
- **`$F054` (`Band0Write`)**: A walks `$0E, $0C, $0A, …, $00`, and after `$00` comes `$0E` again — the whole 7 → 0 → 7 descent, one step every 120 frames. Let this one run for twenty seconds and you have watched a complete palette cycle.
- **`$F060` (`BandWrite`)**: inside a single frame the log shows fifteen hits — X = 1…15 and A = `$1E, $2E, $3E, … $FE` at level 7. For any hit, `A = X×16 + level×2`, live, per band.
- **`COLUBK` in the TIA view**: break at `BandWrite` a few times and watch the register agree with the table above; the background register is literally holding the byte you just built.

## Exercises

### Exercise 1: Swap the Axes

**Challenge:** turn the picture inside out. Draw **eight** equal bands of 24 lines — band j at luminance level 7−j, brightest on top — and let the **hue** be the thing that steps over time: one hue every 120 frames, wrapping 15 → 0. The whole screen changes color together instead of dimming together.

**Hints:**
1. The lesson's hue table still supplies the high nibble; now the low nibble varies band by band instead. A small `LevelFields` table holds `$0E, $0C, … $00` for the eight bands.
2. The hue clock is the lesson's frame counter with its roles changed: `HueCounter` ticks once per frame, and every 120th tick the index advances. `INC` then `AND #$0F` wraps 15 → 0 — Lesson 09's mask trick.
3. Band 0 counts the release line inside its 24, exactly like the lesson: write the color in HBLANK, then paint 23 more with `Y = LINES-1`.

**Expected Result:** eight equal 24-line bands, bright at the top fading to almost-black at the bottom, all in one hue — gray at first, then gold, orange, peach, red, pink, light violet, around the wheel every couple of seconds and wrapping back to gray.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: The Chart Match

**Challenge:** render the lesson's named-color table as a **still chart**. Sixteen bands of twelve lines, one named color per band, straight out of a lookup table — no clock, no stepping, no computation. Then match the screen against the table, band for band: that match is the exercise. The names live in the table and this caption, not on your screen.

**Hints:**
1. The chart never changes, so there is no RAM at all: sixteen bytes in ROM are the entire program state.
2. The table entries are *complete* bytes — `$0E`, `$1A`, `$2E`, `$3E`, `$42`, `$5E`, `$6E`, `$7E`, `$84`, `$9E`, `$AE`, `$BE`, `$C8`, `$DE`, `$EE`, `$FE` — so the kernel is the lesson's band loop with the `ORA` removed.
3. Band 0 keeps the release line inside its 12 (`Y = LINES-1`); the loop bound `CPX #16` is the table's size.

**Expected Result:** sixteen equal 12-line bands, top to bottom: **light gray, gold, orange, peach, red, pink, light violet, violet, blue, light blue, aqua, teal-green, green, bright yellow-green, yellow-green, yellow** — the example column of the named-color table, as a still picture, one band per name.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: One Hue Breathing *(Stretch Goal)*

**Challenge:** one hue, no bands: the whole picture is a single field of red (hue 4) that breathes through all eight luminance levels — dark to bright to dark, endlessly.

**Hints:**
1. The breath is a table of luminance fields: `$00, $02, … $0E` rising, then `$0C, $0A, … $02` falling. Wrapping from the last entry back to the first continues the cycle through level 0.
2. Cache the finished byte in RAM once per step (`FadeColor`) — then the visible area needs no computation at all, just a load.
3. One band means one color write: the release line's write in HBLANK carries the whole picture; then wait out all 192 visible lines with a countdown, and blank for overscan as usual.

**Expected Result:** a single solid field of red that brightens from its darkest shade to its brightest and fades back down, roughly every seven seconds. In the debugger, break at `FadeStep` and watch A walk `$40, $42, … $4E`, then back down `$4C, $4A, … $42`.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **The color byte is structured: `%HHHHLLL0`** — hue in the high nibble, luminance in bits 3–1, bit 0 always 0; byte = hue × 16 + level × 2
- ✅ **16 hues × 8 levels = 128 colors** (NTSC), a closed grid: no colors between steps, identical on every NTSC machine
- ✅ **Hues 1–15 form a wheel; hue 0 is the neutral column** — grey at every level, true black at level 0
- ✅ **Luminance is the brightness axis** — a hue's column is eight colors, each step adding 2 to the byte; level 0 is the darkest step, not a hole
- ✅ **Build bytes in code**: hue nibble from a table, luminance field from RAM, `ORA` them together — the split mirrors the byte's own structure
- ✅ **The frame loop is a free clock** — a RAM byte decremented once per pass counts frames; 120 of them ≈ 2 seconds, and 960 ≈ 16 seconds is all 128 colors
- ✅ **The debugger reads the palette back**: `COLUBK` holds the byte you built, and `BandWrite` shows `A = hue×16 + level×2` as it accumulates

## What's Next

You can now name any of the machine's 128 colors and build it on purpose — but every write so far has landed "somewhere in the line" and been safe by construction: right after a `WSYNC`, inside HBLANK. [Lesson 14: WSYNC and Timing](/part2-tv-and-tia/14-wsync-and-timing) puts the beam on the clock: what `WSYNC` really waits for, what your code does in the first 23 cycles of every line, and what a write looks like when it misses its window by a few dozen cycles.
