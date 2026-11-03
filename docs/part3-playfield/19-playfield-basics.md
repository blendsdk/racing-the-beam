---
title: "Lesson 19: Playfield Basics — PF0, PF1, PF2"
description: "The TIA's playfield is 20 bits per half at four color clocks per bit. Lesson 19 writes the three registers in the right bit order, draws the first castle wall, and flips CTRLPF's REF bit to show reflection versus repetition."
prev:
  text: "Lesson 18: Mid-Scanline Changes"
  link: "/part2-tv-and-tia/18-mid-scanline-changes"
next:
  text: "Lesson 20: Playfield Colors and Priority"
  link: "/part3-playfield/20-playfield-colors"
---

# Lesson 19: Playfield Basics — PF0, PF1, PF2

> **Part 3: Playfield** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 12 (the counted 262-line frame), Lesson 13 (the color byte), Lesson 14 (`WSYNC` and the 76-cycle line), Lesson 15 (the 44/36 timer windows), Lesson 16 (horizontal zones), Lesson 17 (cycle counting), Lesson 18 (mid-scanline writes and the write-position rule)
> **You will learn:** the three playfield registers and their three different bit orders; the 20-bit half as 20 chunks of four color clocks; `CTRLPF`'s reflect and repeat modes; `COLUPF`; and the hold kernel that redraws a constant pattern on all 192 lines
> **You will build:** "the castle wall" — a green playfield pattern that flips between mirror symmetry and repetition every two seconds; plus three exercises: invert the pattern, isolate one chunk, and cycle eight patterns from a table

## Introduction

Part 2 painted the screen with a single color at a time. `COLUBK` filled the line; the interesting work was deciding *when* to change it. Part 3 adds a shape layer: the **playfield**, the TIA's background pattern that carries walls, mazes, platforms, and scoreboards in almost every 2600 game.

The playfield is beautifully small. There are three write registers — `PF0`, `PF1`, `PF2` — holding **20 bits** between them. Those 20 bits cover the left half of the screen; each bit is a **chunk** four color clocks wide. Twenty chunks × four clocks = 80 clocks, exactly half of the 160-clock visible line. The right half is either the same 20 bits **repeated** or the same bits **mirrored** — one bit in `CTRLPF` chooses which.

There is no frame buffer and no "draw a rectangle" command. You write 20 bits, and the TIA re-reads them on every scanline. A pattern written once is a wall that runs the full height of the screen. That is the first playfield: three stores, one color, and a counted hold.

This lesson also teaches the bit order that trips up every beginner. The three registers do not agree on which bit is leftmost, and `PF2` is the one that surprises people. The good news: once the map is in your head, the playfield is the easiest graphics layer on the machine.

::: details TypeScript Equivalent
A 20-bit half is a boolean array, and the right half is built by `map` or `reverse`:

```typescript
const left = [
  true, true, true, true,                 // PF0 bits 4-7
  true, true, false, false, true, true, false, false,  // PF1 bits 7-0
  false, false, false, false, true, true, true, true,  // PF2 bits 0-7
];                                        // 20 chunks, each 4 clocks

const reflect = [...left, ...left.slice().reverse()];  // mirror
const repeat  = [...left, ...left];                    // duplicate
console.assert(reflect.length === 40 && repeat.length === 40);
```

The 2600 version has no array walk: the TIA re-reads the same three bytes every line, so the "render" is just a counter that parks the CPU until the beam reaches the next line.
:::

## Theory

### Section 1: Twenty Bits, Forty Chunks

The numbers Part 2 established, now read as a drawing grid:

- One visible line = **160 color clocks**; with HBLANK, the full line is 228 clocks (76 CPU cycles).
- One playfield bit = **4 color clocks** = one chunk.
- One half = **20 bits × 4 clocks = 80 clocks**; two halves = 160 clocks.
- In the course captures, one color clock is 6 screen pixels, so one chunk is **24 pixels**. The picture spans x = 25–984, and chunk *k* starts at **x = 25 + 24k**.

The playfield is not centered inside the visible area with a margin: chunk 0 begins at the visible left edge, and chunk 39 ends at the visible right edge. When you see a playfield "border", it is simply the first and last chunks turned on.

### Section 2: The Bit Order Map

The 20 bits are split across the registers unevenly, and each register orders its bits differently. This table is the ground truth (also in `include/vcs.asm`):

| Register | Bits used | Chunks on screen (left → right) | Leftmost bit |
|---|---|---|---|
| `PF0` | 4–7 | 0–3 | bit **4** |
| `PF1` | 7–0 | 4–11 | bit **7** |
| `PF2` | 0–7 | 12–19 | bit **0** |

Two consequences follow immediately:

1. **`PF0`'s low nibble is unused.** Bits 0–3 do nothing. `PF0 = $F0` turns on chunks 0–3; `PF0 = $0F` turns on nothing.
2. **`PF2` runs the opposite way to `PF1`.** `PF1 = $CC` is `11001100` on screen; `PF2 = $CC` is `00110011` on screen. The castle pattern uses `PF2 = $F0`, which displays as **`00001111`**: four dark chunks (12–15), then four green ones (16–19).

That second point is the one to rehearse. A useful habit: write the byte as bits 7→0, then read `PF2` from the **right** end. The lesson ROM's center is green because `PF2`'s low nibble is zero and its high nibble is one.

### Section 3: Reflect and Repeat

`CTRLPF` bit 0 is `REF`:

| `REF` | Mode | Right half |
|---|---|---|
| 1 | **Reflect** | chunks 0–19 reversed — the left half mirrored |
| 0 | **Repeat** | chunks 0–19 again — the left half duplicated |

The lesson ROM's 20-bit half is:

```
PF0 = $F0   1111
PF1 = $CC   11001100
PF2 = $F0   00001111        (display order, bit 0 first)
------------------------------------------------
left half   1111 11001100 00001111
```

With `REF = 1`, the full 40 chunks become:

```
111111 00 11 000000 11111111 000000 11 00 111111
```

Read that as six on, two off, two on, six off, **eight on in the center**, six off, two on, two off, six on. The picture is a green center block with a dark band on each side, then a thin green stripe, a thin dark stripe, and a green outer border. The measured transitions are at x = **169, 217, 265, 409, 601, 745, 793, 841**.

With `REF = 0`, the right half repeats the left:

```
111111 00 11 000000 1111111111 00 11 000000 1111
```

The center block now runs from chunk 16 to chunk 25 (ten chunks); beyond it, the right-hand dark band moves outward from chunks 24–29 to 30–35, while the left half is unchanged. The measured transitions are at x = **169, 217, 265, 409, 649, 697, 745, 889**. The two states differ most in the right middle of the screen — visible at a glance when the ROM flips.

### Section 4: The Hold Kernel

The pattern is the same on every line, so the program does not write the playfield registers in the kernel at all. It writes them once per frame, during VBLANK, and then parks the CPU for 192 lines:

```asm
    LDA #$00
    STA VBLANK          ; release the beam
    LDX #192
VisibleStart:
    STA WSYNC           ; park this line; the TIA redraws the registers
    DEX
    BNE VisibleStart
```

The TIA re-reads `PF0`, `PF1`, and `PF2` for every line; the registers are the picture. The kernel's job is only to keep the CPU from running ahead of the beam. Each `STA WSYNC` holds until the end of the current line, so the loop visits exactly 192 lines.

Because the registers are written in VBLANK, the change on an animation frame appears on the **next** visible frame, cleanly, never mid-picture. That is the same discipline as Lesson 16's zone colors, applied to the whole screen.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson19.bin \
  lessons/part3-playfield/19-playfield-basics/19-playfield-basics.asm
stella build/lesson19.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 19: Playfield Basics — PF0, PF1, PF2 — Racing the Beam
; =============================================================================
; Part 3: Playfield
;
; What this program does:
;   Draws the TIA's playfield: a green "castle wall" on a dark field, made
;   from the three playfield registers PF0, PF1, PF2.  The picture is the
;   same on every one of the 192 visible lines — the TIA re-reads the three
;   registers for every line, so a pattern written once is a vertical wall.
;
;   Every ~2 seconds the wall changes symmetry:
;     - reflect mode (CTRLPF bit 0 = 1): the right half mirrors the left,
;       so the wall is symmetric: an eight-chunk green center between two
;       dark bands;
;     - repeat mode  (CTRLPF bit 0 = 0): the right half repeats the left,
;       so the green center widens to ten chunks; beyond it the right half
;       shows a new rhythm while the left half is unchanged.
;
; The playfield in one paragraph:
;   20 bits cover the LEFT half of the screen.  Each bit is one "chunk" of
;   four color clocks (24 screen pixels — six per color clock — in the
;   course captures).  Twenty
;   chunks of four clocks = 80 clocks; the full visible line is 160 clocks,
;   so the right half is the same 20 bits mirrored or repeated.
;
;   PF0 uses only bits 4-7, and bit 4 is the LEFTMOST chunk.
;   PF1 uses all eight bits, and bit 7 is the leftmost chunk.
;   PF2 uses all eight bits, and bit 0 is the leftmost chunk; bit 7 is the
;   chunk nearest the center of the screen.  Those three different bit
;   orders are the classic playfield confusion — the table below is the map.
;
;     register  bits   chunks (left to right)
;     PF0       4-7    0-3
;     PF1       7-0    4-11
;     PF2       0-7    12-19
;
; The castle pattern (one 20-bit half):
;   PF0 = $F0  -> chunks 0-3   on   (1111)
;   PF1 = $CC  -> chunks 4-11   11001100
;   PF2 = $F0  -> chunks 12-19  00001111   (bit 0 is leftmost!)
;
;   Reflect (this ROM's starting state): the right half is chunks 0-19 reversed, so the
;   center is a green eight-chunk block (chunks 16-23) with a dark band on
;   each side.  Repeat: the right half is the same 20 bits again, so the
;   green center widens to chunks 16-25 and the dark bands move outward.
;
; The frame is the course standard (262 lines):
;   VSYNC 3 lines, VBLANK 37 lines on TIM64T = 44, visible 192 lines,
;   overscan 30 lines on TIM64T = 36.  The PF/CTRLPF/color writes happen in
;   VBLANK, before the beam is released; the visible kernel is a counted
;   WSYNC hold — the TIA redraws the wall from the registers every line.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259 — a standard 262-line frame), VblankStart (0),
;   CtrlWrite (A = the mode: $01 reflect, $00 repeat; first flip at frame
;   120), VisibleStart (37), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson19.bin \
;        lessons/part3-playfield/19-playfield-basics/19-playfield-basics.asm
; Run:   stella build/lesson19.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (Lesson 15)
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (Lesson 15)
VISIBLE_LINES  = 192    ; the standard NTSC picture height
ANIM_FRAMES    = 120    ; ~2 seconds per symmetry state at ~60 Hz

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameCounter   = $80    ; counts up to ANIM_FRAMES, then resets
AnimState      = $81    ; 1 = reflect, 0 = repeat (starts reflect)

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)
    LDA #$01
    STA AnimState           ; frame 1 starts in reflect mode

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines (Lesson 12)
; -----------------------------------------------------------------------------
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 lines, counted by the RIOT timer (TIM64T = 44)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    +set_timer VBLANK_TIMER ; start the countdown: 44 ticks for 37 lines

; --- the symmetry tick: flip CTRLPF's REF bit every ANIM_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #ANIM_FRAMES
    BNE VblankTickDone
    LDA #$00
    STA FrameCounter        ; wrap the counter
    LDA AnimState
    EOR #$01
    STA AnimState           ; reflect <-> repeat
VblankTickDone:

; --- write the frame's playfield state (the pattern never changes) ---
    LDA AnimState
    BEQ VblankRepeat
    LDA #$01                ; bit 0 = REF: mirror the right half
    BNE VblankStoreCtrl     ; (always taken: A = 1)
VblankRepeat:
    LDA #$00                ; REF = 0: repeat the left half
VblankStoreCtrl:
    STA CTRLPF
CtrlWrite:                  ; debugger checkpoint: A = $01 / $00

    LDA #$F0
    STA PF0                 ; chunks 0-3 on
    LDA #$CC
    STA PF1                 ; chunks 4-11: 11001100
    LDA #$F0
    STA PF2                 ; chunks 12-19: 00001111 (bit 0 first)
    LDA #$C8
    STA COLUPF              ; green
    LDA #$02
    STA COLUBK              ; dark neutral

    +wait_timer             ; wait out line 36, then park it

; -----------------------------------------------------------------------------
; VISIBLE — 192 lines; the pattern is redrawn from the registers every line
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
    LDX #VISIBLE_LINES      ; 192 lines to hold
VisibleStart:               ; debugger checkpoint: the picture's first line (37)
    STA WSYNC               ; park the rest of this line
    DEX
    BNE VisibleStart

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines (TIM64T = 36); blank-on lands in line 229's HBLANK
; -----------------------------------------------------------------------------
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

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
> `lessons/part3-playfield/19-playfield-basics/19-playfield-basics.asm`.

### Code Walkthrough

#### Step 1 — The frame

The program keeps the Part 2 skeleton: `+vsync` for three lines, `+set_timer 44` and `+wait_timer` for the 37-line VBLANK, the visible hold, then `+set_timer 36` and `+wait_timer` for the 30-line overscan. Measured, `StartFrame` fires at scanline **259** every frame — a standard 262-line picture.

#### Step 2 — The two-second tick

`FrameCounter` increments once per frame in VBLANK. At 120 it wraps and flips `AnimState` with `EOR #$01`. The first flip lands at frame **120** (≈2.0 s); the next at 240; and so on. Both states are stable for their full 120 frames, which is why the two screenshots are easy to capture.

#### Step 3 — Choosing `CTRLPF`

`AnimState` selects the byte written to `CTRLPF`: `$01` for reflect, `$00` for repeat. The store is labelled `CtrlWrite`; it executes **every frame**, and the accumulator is the mode readout — `$01` while reflect is showing, `$00` while repeat is showing. The first change is at frame 120.

#### Step 4 — The three pattern stores

`$F0`, `$CC`, `$F0` go to `PF0`, `PF1`, `PF2`; `$C8` to `COLUPF`; `$02` to `COLUBK`. The pattern never changes in this ROM — the animation changes only the symmetry bit. That makes the lesson's first picture easy to reason about: one wall, two ways to finish it.

#### Step 5 — The hold and the release

`+wait_timer` parks the rest of line 36. The release pair starts at line 37 cycle 0; its `STA VBLANK` write lands at **cycle 4** (color clock 12, still inside HBLANK), so line 37 is fully visible. `LDX` takes cycles 5–6 and the first `STA WSYNC` parks line 37's remainder at cycle 7. Lines 37–228 are visible — 192 of them. The overscan blank-on follows at line 229, inside HBLANK.

#### Step 6 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F012` | **259, cycle 3** — the frame is 262 lines | VSYNC's first line |
| `VblankStart` | `$F020` | 0, cycle 5 | VBLANK's first line |
| `CtrlWrite` | `$F047` | one hit per frame; A = `$01` (reflect) / `$00` (repeat); first change at frame **120** | the symmetry store |
| `VisibleStart` | `$F068` | 37, cycle 7 | the picture's first line |
| `OverscanStart` | `$F06D` | 229, cycle 4 | overscan's first line |

The captures are the second half of the evidence. At rows 110, 400, and 708 the reflect capture has the same eight transitions — the pattern is truly constant down the screen, with no first-line seam.

## What You Should See

A green castle wall on a dark field, filling all 192 visible lines. In the reflect state the wall is symmetric: a wide green center block, a dark band on each side, a thin green stripe, a thin dark stripe, and a green border at the screen edges. Then, every two seconds, the right half stops mirroring and starts repeating: the center block widens, the dark bands shift outward, and the right side of the wall changes rhythm.

![Stella running the Lesson 19 ROM in reflect mode: a symmetric green castle wall on a dark field](/images/lesson19/reflect.png)

*Reflect state, captured from the committed ROM: transitions at x = 169 / 217 / 265 / 409 / 601 / 745 / 793 / 841. The center is the eight-chunk green block (chunks 16–23); the dark bands are chunks 10–15 and 24–29.*

![Stella running the Lesson 19 ROM in repeat mode: the right half repeats the left](/images/lesson19/repeat.png)

*Repeat state, same ROM ~2 seconds later: transitions at 169 / 217 / 265 / 409 / 649 / 697 / 745 / 889. The center block now spans chunks 16–25; the two captures differ in 116,160 picture pixels.*

<RomPlayer rom="/roms/part3-playfield/19-playfield-basics/19-playfield-basics.bin" title="Lesson 19 — Playfield Basics" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson19.sym -o build/lesson19.bin \
  lessons/part3-playfield/19-playfield-basics/19-playfield-basics.asm
grep -E "CtrlWrite|VisibleStart|OverscanStart" build/lesson19.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F047' \
  docs/public/roms/part3-playfield/19-playfield-basics/19-playfield-basics.bin
```

- **`$F047` (`CtrlWrite`)**: one hit **per frame** (~60 per second). A = `$01` for frames 1–119, 240–359, … and `$00` for frames 120–239, 360–479, …. The log's frame column is the animation clock.
- **`$F068` (`VisibleStart`)**: line 37 on every frame. The first line's store is at cycle 7 rather than the steady-state cycle 5, but the hold kernel writes no playfield data — the registers were set in VBLANK — so line 37 carries the full pattern.
- **`$F06D` (`OverscanStart`)**: line 229 — the visible area is exactly 192 lines, and the blank-on lands before any visible pixel.

## Exercises

### Exercise 1: Invert the Pattern

**Challenge:** invert every playfield bit so the wall's on and off regions swap.

**Hints:**
1. Invert each of the three pattern bytes — but remember `PF0`'s low nibble is unused. The inverse of `$F0` is `$00`, not `$0F`.
2. `PF2`'s bit order is reversed on screen: the inverse of `$F0` is `$0F`, and it displays as `11110000` (bit 0 first). Check the result by chunk, not by the byte's binary digits.
3. Keep the frame, the hold kernel, and reflect mode unchanged; only the three pattern constants move.

**Expected Result:** the photographic negative of the lesson ROM's reflect state: the green center block becomes dark, the dark bands become green, and the outer green border becomes dark. Measured transitions stay at 169 / 217 / 265 / 409 / 601 / 745 / 793 / 841, with the colors swapped.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: One Chunk Bar

**Challenge:** turn on exactly one playfield chunk and explain where the bar appears.

**Hints:**
1. `PF1`'s bit 7 is chunk 4, so bit 4 is chunk **7**. `PF1 = $10` sets that one bit.
2. In reflect mode the right half mirrors chunk *k* to chunk *39 − k*, so the bar appears at chunks 7 and 32.
3. In repeat mode the right half repeats the left's chunk numbering, so the same bit appears at chunks 7 and **27** — not at 32. The bar positions are the cleanest way to see which mode is active.

**Expected Result:** two green 24-pixel bars, one at x = 193–216 (chunk 7) and one at x = 793–816 (chunk 32). In repeat mode the second bar would sit at x = 673–696 (chunk 27).

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Eight Patterns *(Stretch Goal)*

**Challenge:** cycle eight playfield patterns from a ROM table, one per second.

**Hints:**
1. A pattern is three bytes. Store the eight triples consecutively and keep a 0–7 index in RAM.
2. The entry's offset is `index × 3`. `ASL` makes `2 × index`; add the index once more with `CLC` / `ADC`.
3. Advance the index every 60 frames (~1 s), wrap with `AND #$07`, and write the three fetched bytes in VBLANK. The frame and the hold kernel do not change.

**Expected Result:** the wall changes shape once a second through eight patterns — the lesson ROM's castle, a fine comb, an offset comb, two wide slots, and four variants. The frame stays 262 lines and the picture stays stable within each second.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **Twenty bits make forty chunks**: each half is 20 bits × 4 color clocks = 80 clocks; the right half mirrors or repeats it. The whole visible line is 160 clocks, and one chunk is 24 pixels in the captures
- ✅ **Three registers, three bit orders**: `PF0` bits 4–7 (bit 4 leftmost), `PF1` bits 7–0 (bit 7 leftmost), `PF2` bits 0–7 (bit 0 leftmost). `PF0`'s low nibble is unused, and `PF2` is the reversal that catches everyone
- ✅ **`CTRLPF` bit 0 is the symmetry switch**: set it and the right half mirrors the left; clear it and the right half repeats the left. Same 20 bits, two different pictures
- ✅ **The registers are the picture**: the TIA re-reads `PF0`/`PF1`/`PF2` on every line, so a pattern written in VBLANK becomes a wall down all 192 lines. The kernel only has to hold the beam
- ✅ **Write state in VBLANK**: a frame-level change lands on the next visible frame, never as a mid-picture seam
- ✅ **The frame is untouched**: 3 + 37 + 192 + 30 = 262 lines; the playfield lives inside the same frame Part 2 built

## What's Next

The wall is one color. [Lesson 20: Playfield Colors and Priority](/part3-playfield/20-playfield-colors) gives it two: `COLUPF` colors the whole playfield, and `CTRLPF`'s score bit splits the halves between `COLUP0` and `COLUP1` — the mechanism behind every 2600 scoreboard. The same 20 bits, now with a palette.
