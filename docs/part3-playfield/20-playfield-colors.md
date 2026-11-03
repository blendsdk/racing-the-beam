---
title: "Lesson 20: Playfield Colors and Priority"
description: "COLUPF colors the whole playfield; CTRLPF's SCORE bit splits it into a left half colored by COLUP0 and a right half colored by COLUP1. Lesson 20 draws one wall, flips between the two color systems, and lays out the TIA's priority stack."
prev:
  text: "Lesson 19: Playfield Basics"
  link: "/part3-playfield/19-playfield-basics"
next:
  text: "Lesson 21: Asymmetric Playfield"
  link: "/part3-playfield/21-asymmetric-playfield"
---

# Lesson 20: Playfield Colors and Priority

> **Part 3: Playfield** · Estimated time: 45 minutes
> **Prerequisites:** Lesson 13 (the color byte and the palette), Lesson 19 (the playfield registers and `CTRLPF`'s reflect bit), Lesson 16 (horizontal zones), Lesson 18 (write positions)
> **You will learn:** `COLUPF` as the playfield's color; `CTRLPF`'s `SCORE` bit and the left/right split between `COLUP0` and `COLUP1`; the TIA's four-level priority stack and the `PFP` bit; why the scoreboard trick needs no extra objects
> **You will build:** "the two-tone wall" — a green wall with a central gap that becomes a red/blue score split every two seconds; plus three exercises: swap the score colors, build a three-color wall, and split the picture into four color quadrants

## Introduction

Lesson 19 gave the playfield a shape. This lesson gives it color — and shows that the TIA has **two** ways to color the same 20 bits.

The first is `COLUPF`: one byte, one color, the whole playfield (and the ball). That is the normal state, and it is the color most 2600 backgrounds use. The second is `CTRLPF` bit 1, `SCORE`. In score mode the playfield is split exactly at the center: the **left half** takes `COLUP0`'s color and the **right half** takes `COLUP1`'s. No extra objects, no extra writes per line — the TIA does the split while it draws. This is the six-digit scoreboard trick in its simplest form: one 20-bit pattern, two colors, and a dozen lines of setup.

The same `CTRLPF` byte also carries the **priority** bit, `PFP`, which decides whether the playfield draws behind or in front of the players. Priority is a stack, not a blend: at every pixel the highest-priority object with a pixel wins outright. The playfield's own place in that stack is easy to see now (it covers the background); its effect on players needs a player, so this lesson teaches the bit and leaves the visible experiment to Part 4.

One warning before the code: the wall's central gap uses `PF2` again, and `PF2` keeps its reversed bit order. The value that clears the two chunks nearest the center is `$3F`, not `$FC`. The gap is the same bit-order lesson from Lesson 19, now used deliberately.

::: details TypeScript Equivalent
A per-pixel color function makes the score-mode decision explicit:

```typescript
type Color = "red" | "blue" | "green" | "dark";
const COLUP0: Color = "red";    // score-mode left half
const COLUP1: Color = "blue";   // score-mode right half
const COLUPF: Color = "green";  // normal playfield

function playfieldColor(chunk: number, score: boolean, on: boolean): Color {
  if (!on) return "dark";                       // COLUBK shows through
  if (on && !score) return COLUPF;              // normal playfield
  return chunk < 20 ? COLUP0 : COLUP1;          // score split at the center
}
```

The hardware has no function call: the TIA evaluates the same decision for every color clock, using the registers as they stand when the beam arrives.
:::

## Theory

### Section 1: One Color, the Whole Field

`COLUPF` is the playfield's color register (and the ball's — the ball shares it, a name-only fact until Part 4). It uses the same palette byte as every other color register: `%HHHHLLL0`, hue × 16 + level × 2. The lesson uses `$C8`: hue 12, level 4 — the course's green.

The wall's **shape** is independent of its color. The pattern is still `PF0=$F0`, `PF1=$FF`, `PF2=$3F`. `$3F` is `00111111` as a byte, but because `PF2` bit 0 is leftmost, its on-screen chunks are `11111100`: chunks 12–17 on, 18–19 off. Reflect mirrors those two dark chunks into chunks 20–21, so the gap is exactly four chunks — **x = 457–552 (96 px)**, between the transitions at 457 and 553 — in the middle of the picture.

### Section 2: Score Mode — Two Colors, One Pattern

`CTRLPF` bit 1 is `SCORE`:

| `SCORE` | Playfield color |
|---|---|
| 0 | `COLUPF` for the whole playfield |
| 1 | left half `COLUP0`, right half `COLUP1` |

The split is at the center of the 40-chunk line, not at the gap. With the wall's gap at chunks 18–21, the two effects line up: the left half is red up to the gap, the right half is blue after it, and the gap itself stays dark because no playfield bit is on there.

This is why score mode is so useful: a scoreboard is a playfield pattern (digits made of chunks) with the left half colored by `COLUP0` and the right half by `COLUP1`. The TIA does the color split for free, so the CPU only has to write the digit bits.

The lesson flips `SCORE` every 120 frames with the same counter Lesson 19 used. Both states are stable for two seconds, so the two screenshots are unambiguous.

### Section 3: The Priority Stack

At every pixel the TIA picks the highest-priority object that wants to draw there:

| Priority | Default (`PFP = 0`) | With `PFP = 1` |
|---|---|---|
| 1 (highest) | Player 0 + Missile 0 (`COLUP0`) | Playfield + Ball (`COLUPF`) |
| 2 | Player 1 + Missile 1 (`COLUP1`) | Player 0 + Missile 0 |
| 3 | Playfield + Ball (`COLUPF`) | Player 1 + Missile 1 |
| 4 (lowest) | Background (`COLUBK`) | Background |

Two consequences you can already see:

- The **background is always lowest**. Every 0 bit in the playfield shows `COLUBK`; that is the dark gap.
- The **playfield is below the players by default**. `PFP` (bit 2) lifts the playfield and ball to the top, so a wall can cover a player — the "playfield in front of sprites" mode used for bridges, gates, and foreground scenery.

The ROM writes only `REF` and `SCORE` (`$01` and `$03`). It does not set `PFP`, because with no player or ball on screen the bit has nothing to change. The priority table is here so the mechanism is in place when Part 4 introduces the objects it orders.

### Section 4: The Frame and the Two-Second Flip

The frame is the course standard: 3 VSYNC lines, 37 VBLANK lines (`TIM64T` = 44), 192 visible lines, 30 overscan lines (`TIM64T` = 36). The pattern and all three colors are written in VBLANK; the visible kernel is the same 192-line `STA WSYNC` hold as Lesson 19.

The flip lives in VBLANK:

```asm
    LDA AnimState
    BEQ VblankNormal
    LDA #$03                ; REF + SCORE
    BNE VblankStoreCtrl
VblankNormal:
    LDA #$01                ; REF only
VblankStoreCtrl:
    STA CTRLPF
```

`AnimState` starts at 0 (normal color), flips at frame 120, and flips back at 240. The store is labelled `CtrlWrite`; it runs every frame, so the debugger reports the current mode as the accumulator value — `$01` or `$03`.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson20.bin \
  lessons/part3-playfield/20-playfield-colors/20-playfield-colors.asm
stella build/lesson20.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 20: Playfield Colors and Priority — Racing the Beam
; =============================================================================
; Part 3: Playfield
;
; What this program does:
;   Draws a solid green wall with a central gap — then, every ~2 seconds,
;   splits the wall into a red left half and a blue right half using
;   CTRLPF's SCORE mode.  The playfield's shape never changes; only its
;   colors do.
;
; Two ways to color a playfield:
;   - COLUPF colors the whole playfield (and the ball).  That is the normal
;     state: a green wall.
;   - CTRLPF bit 1 = SCORE splits the playfield at the center: the left
;     half takes COLUP0's color, the right half COLUP1's.  That is the
;     scoreboard trick: one 20-bit pattern, two colors, no extra objects.
;
; The pattern and the gap:
;   PF0 = $F0  -> chunks 0-3   on
;   PF1 = $FF  -> chunks 4-11  on
;   PF2 = $3F  -> chunks 12-17 on, 18-19 off
;
;   Remember PF2's bit order: bit 0 is leftmost, so $3F (00111111) clears
;   the two chunks nearest the center.  Reflect mode mirrors them, so the
;   gap is four chunks wide: chunks 18-21, capture x = 457-552 (96 px).
;
;   Normal state: green wall, dark gap.  Score state: red left half, blue
;   right half, dark gap.  The screen is 40 chunks wide; the gap is at the
;   center, so the color split and the gap line up.
;
; Priority, in one table (the TIA draws the highest level that has a pixel):
;
;   default (CTRLPF bit 2 PFP = 0)     with PFP = 1
;   1  Player 0 + Missile 0 (COLUP0)    1  Playfield + Ball (COLUPF)
;   2  Player 1 + Missile 1 (COLUP1)    2  Player 0 + Missile 0
;   3  Playfield + Ball (COLUPF)        3  Player 1 + Missile 1
;   4  Background (COLUBK)              4  Background
;
;   The playfield is above the background and below the players by
;   default.  PFP lifts the playfield (and ball) above both players — the
;   "playfield in front of sprites" mode.  Its visible effect needs a
;   player or ball, so this lesson teaches the bit and leaves the
;   demonstration to Part 4 (Lesson 25+); no forward object code runs here.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; The registers are written in VBLANK; the visible kernel is a 192-line
; WSYNC hold.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), CtrlWrite (one hit per frame; A =
;   $01 normal, $03 score; first change at frame 120), VisibleStart (37),
;   OverscanStart (229).
;
; Build: acme -f plain -o build/lesson20.bin \
;        lessons/part3-playfield/20-playfield-colors/20-playfield-colors.asm
; Run:   stella build/lesson20.bin
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
VISIBLE_LINES  = 192
ANIM_FRAMES    = 120    ; ~2 seconds per color state

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameCounter   = $80
AnimState      = $81    ; 0 = normal color, 1 = score mode

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM; AnimState = 0 (normal color)

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the color tick: flip normal <-> score every ANIM_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #ANIM_FRAMES
    BNE VblankTickDone
    LDA #$00
    STA FrameCounter
    LDA AnimState
    EOR #$01
    STA AnimState
VblankTickDone:

; --- choose the CTRLPF bits: REF always, SCORE only in state 1 ---
    LDA AnimState
    BEQ VblankNormal
    LDA #$03                ; bit 0 REF + bit 1 SCORE
    BNE VblankStoreCtrl     ; (always taken: A = 3)
VblankNormal:
    LDA #$01                ; bit 0 REF only
VblankStoreCtrl:
    STA CTRLPF
CtrlWrite:                  ; debugger checkpoint: A = $01 / $03

; --- the wall and its colors; the pattern never changes ---
    LDA #$F0
    STA PF0                 ; chunks 0-3 on
    LDA #$FF
    STA PF1                 ; chunks 4-11 on
    LDA #$3F
    STA PF2                 ; chunks 12-17 on, 18-19 off (bit 0 first)
    LDA #$C8
    STA COLUPF              ; green: the normal-state color
    LDA #$42
    STA COLUP0              ; red: the score mode's left half
    LDA #$84
    STA COLUP1              ; blue: the score mode's right half
    LDA #$02
    STA COLUBK              ; dark background

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — 192 lines; the TIA redraws the wall every line
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
    LDX #VISIBLE_LINES
VisibleStart:               ; debugger checkpoint: the picture's first line (37)
    STA WSYNC
    DEX
    BNE VisibleStart

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines; blank-on lands in line 229's HBLANK
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
> `lessons/part3-playfield/20-playfield-colors/20-playfield-colors.asm`.

### Code Walkthrough

#### Step 1 — The pattern and the gap

`PF0=$F0`, `PF1=$FF`, `PF2=$3F`. The first two fill chunks 0–11. `PF2` runs bit 0 first: `$3F` displays `11111100`, so chunks 12–17 are on and 18–19 are off. Reflect mirrors the two dark chunks into 20–21, and the gap is four chunks wide.

#### Step 2 — The normal color

`COLUPF = $C8` (green) paints the entire wall. The gap has no playfield bit, so `COLUBK = $02` shows through. The measured transitions are at x = **457** (green → dark) and **553** (dark → green); the left edge at x = 25 is already green.

#### Step 3 — The score split

At frame 120 `CTRLPF` becomes `$03` (`REF + SCORE`). The left half now reads `COLUP0 = $42` (red) and the right half `COLUP1 = $84` (blue). The gap stays dark. The measured transitions are at x = **457** (red → dark) and **553** (dark → blue); the left edge at x = 25 is red. The whole wall changed color without changing a single playfield bit.

#### Step 4 — The hold and the release

The release happens at line 37: `LDA #$00` / `STA VBLANK` starts at cycle 0 and the write lands at cycle 4, inside HBLANK, so line 37 is fully drawn. The hold loop then parks 192 lines. The overscan blank-on at line 229 lands in HBLANK.

#### Step 5 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `CtrlWrite` | `$F043` | one hit per frame; A = `$01` (normal) / `$03` (score); first change at frame **120** | the color-mode store |
| `VisibleStart` | `$F06C` | 37, cycle 7 | the picture's first line |
| `OverscanStart` | `$F071` | 229, cycle 4 | overscan's first line |

## What You Should See

A solid wall with a four-chunk gap in the middle, filling all 192 visible lines. For the first two seconds it is green with a dark gap. Then it splits: the left half turns red, the right half blue, and the gap stays dark. Two seconds later it is green again.

![Stella running the Lesson 20 ROM in the normal state: a green playfield wall with a dark central gap](/images/lesson20/single-color.png)

*Normal state, captured from the committed ROM: green `$C8` wall, dark `$02` gap at x = 457–552 (96 px). The wall covers all 192 lines.*

![Stella running the Lesson 20 ROM in score mode: the left half red (COLUP0), the right half blue (COLUP1)](/images/lesson20/score-mode.png)

*Score state, same ROM ~2 seconds later: `SCORE` splits the playfield — left half `COLUP0` red `$42`, right half `COLUP1` blue `$84`; the gap stays dark. The two captures differ in 522,720 picture pixels; repeat captures of either state differ in zero.*

<RomPlayer rom="/roms/part3-playfield/20-playfield-colors/20-playfield-colors.bin" title="Lesson 20 — Playfield Colors and Priority" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson20.sym -o build/lesson20.bin \
  lessons/part3-playfield/20-playfield-colors/20-playfield-colors.asm
grep -E "CtrlWrite|VisibleStart|OverscanStart" build/lesson20.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F043' \
  docs/public/roms/part3-playfield/20-playfield-colors/20-playfield-colors.bin
```

- **`$F043` (`CtrlWrite`)**: one hit per frame. A = `$01` for frames 1–119, `$03` for 120–239, `$01` for 240–359, and so on. The log's frame column is the animation clock.
- **`$F06C` (`VisibleStart`)**: line 37 on every frame; the frame's color state is in place before the first visible line.
- **`$F071` (`OverscanStart`)**: line 229 — 192 visible lines, with the blank-on inside HBLANK.

## Exercises

### Exercise 1: Swap the Score Colors

**Challenge:** keep the same wall and animation, but make the left half blue and the right half red.

**Hints:**
1. Score mode reads `COLUP0` for the left half and `COLUP1` for the right. Only those two constants move.
2. Leave `COLUPF` green: the normal state should not change.
3. The gap and the frame are untouched.

**Expected Result:** the normal state is still green with the gap; the score state is left blue `$84`, right red `$42`, gap dark. Measured: the left edge at x = 25 is blue, the gap is at 457–552 (96 px), and the color changes to red at x = 553.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: A Three-Color Wall

**Challenge:** keep score mode and make the background a third color by opening gaps in the pattern.

**Hints:**
1. A playfield bit that is 0 shows `COLUBK`. `PF1 = $CC` opens chunks 6–7 and 10–11 (and their mirrors).
2. Set `COLUBK = $1A` (gold). The left half is still `COLUP0` red, the right half `COLUP1` blue, and every 0 bit is gold.
3. `PF2` stays `$3F`, so the central gap is gold too.

**Expected Result:** red and blue blocks separated by gold stripes; measured transitions at x = 169 (gold), 217 (red), 265 (gold), 313 (red), 457 (gold), 553 (blue), 697 (gold), 745 (blue), 793 (gold), 841 (blue).

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: A Four-Quadrant Frame *(Stretch Goal)*

**Challenge:** top half in score mode (red|blue), bottom half in normal color (green), split at the middle of the picture.

**Hints:**
1. `CTRLPF` can change at any line. Split the visible kernel into two 96-line loops.
2. After the top loop's last `WSYNC`, the CPU is at line 133. Write `CTRLPF = $01` there; the write lands in HBLANK, so line 133 is the first green line.
3. The color registers are set once in VBLANK; only `CTRLPF` changes between the halves.

**Expected Result:** lines 37–132 red left / blue right with the dark gap; lines 133–228 green with the dark gap. Measured: `TopMode` at (37, cycle 12) with A = `$03`; `BottomMode` at (133, cycle 11) with A = `$01`; a top-row sample is red at x = 25 and blue at x = 553, a bottom-row sample is green at x = 25 and x = 553.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **`COLUPF` colors the whole playfield**: one palette byte for the shape; 0 bits show `COLUBK`
- ✅ **`CTRLPF` bit 1 is `SCORE`**: the left half takes `COLUP0`'s color, the right half `COLUP1`'s — a free two-color split at the center, and the basis of the scoreboard trick
- ✅ **The pattern and the color are independent**: the lesson changes the wall from green to red/blue without touching `PF0`/`PF1`/`PF2`
- ✅ **Priority is a stack, not a blend**: P0/M0 > P1/M1 > PF/BL > BK by default; `PFP` (bit 2) lifts the playfield and ball to the top. The playfield covers the background now; its effect on players waits for Part 4
- ✅ **`PF2` still runs backwards**: `$3F` clears the two chunks nearest the center (`11111100` on screen), so the gap is chunks 18–21, x = 457–552 (96 px)
- ✅ **Mode changes live in VBLANK**: the 120-frame counter flips `SCORE`, and the next visible frame is cleanly one state or the other

## What's Next

The wall is symmetric and one color at a time. [Lesson 21: Asymmetric Playfield](/part3-playfield/21-asymmetric-playfield) breaks the symmetry: the left half and the right half will hold different bits, by rewriting the registers at carefully counted cycles inside the line. That is where the playfield stops being a wallpaper and becomes a maze.
