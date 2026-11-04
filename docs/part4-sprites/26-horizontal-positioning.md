---
title: "Lesson 26: Horizontal Positioning — The Divide-by-15 Trick"
description: "RESP0 sets a player's coarse position; HMP0 and HMOVE add a signed fine offset. Lesson 26 derives the classic divide-by-15 routine, calibrates its three-pixel encoding offset, and moves the invader through five exact X positions."
prev:
  text: "Lesson 25: Player Sprite Basics"
  link: "/part4-sprites/25-player-basics"
next:
  text: "Lesson 27: Sprite Movement"
  link: "/part4-sprites/27-sprite-movement"
---

# Lesson 26: Horizontal Positioning — The Divide-by-15 Trick

> **Part 4: Sprites** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 14 (`WSYNC` and the 76-cycle line), Lesson 17 (cycle counting), Lesson 18 (write positions and hit cycles), Lesson 25 (the first sprite and its vertical schedule)
> **You will learn:** how `RESP0` turns a strobe into a coarse position; how `HMP0` and `HMOVE` add a signed fine offset; how the divide-by-15 loop measures the distance in 15-clock steps; how to calibrate the routine's constant three-pixel offset; why negative fine motion moves right
> **You will build:** "the tour" — the Lesson 25 invader moving through five exact X positions (16, 48, 80, 112, 144), one per second; plus three exercises: a single target, the far right, and a ping-pong

## Introduction

Lesson 25 placed the invader with a hand-tuned delay: nine `DEX`/`BNE` iterations and a `RESP0`
strobe. It worked, but it was a guess. This lesson replaces the guess with the routine every 2600
programmer eventually writes: **`SetHorizPos`**.

The TIA gives you two tools for horizontal placement. `RESP0` is a strobe that sets the player's
position counter to wherever the beam is when the write lands. `HMP0` holds a signed fine offset
from −8 to +7 color clocks, applied by `HMOVE`. The coarse tool has a resolution of 3 color clocks
(one CPU cycle); the fine tool fills in the remainder. Together they place a sprite at any of the
160 visible clocks.

The divide-by-15 routine is the bridge. Each `SBC #15` iteration costs five CPU cycles, and the
CPU runs three color clocks per cycle — so one iteration is exactly 15 clocks of beam travel.
Subtract 15 until the carry clears; the loop runs one extra subtraction to detect the underflow,
and the negative remainder becomes the fine value. The routine is short, exact, and worth
understanding line by line.

::: details TypeScript Equivalent
A `setX` function separates coarse steps from the remainder:

```typescript
function setX(target: number) {
  let a = target, steps = 0;
  while (a >= 0) { a -= 15; steps += 1; }  // one extra step detects the underflow
  const remainder = a + 15;                // 0..14
  const fine = 6 - remainder;              // positive = left
  return { steps, fine };                  // steps = quotient + 1, fine = HMP0
}
```

The 2600 version runs the same subtraction with one extra step to detect the underflow, then
shifts the encoded remainder into `HMP0`'s high nibble. The analogy breaks at the constant −3
offset: the encoded fine value is three clocks left of exact placement, so the lesson calibrates
with a +3 bias.
:::

## Theory

### Section 1: Coarse and Fine

`RESP0` is a strobe, not a value register. Writing it resets player 0's position counter; the
player's pixels begin about five clocks after the counter's zero. A strobe at clock **63** — five
clocks before the visible area — puts the sprite at the left edge; a strobe whose write lands at
68 puts it near X=5. If you strobe later, it appears further right.
The CPU's cycle granularity is three clocks, so a strobe alone quantizes the position to
3-clock steps.

`HMP0`'s **high nibble** is a signed offset: `$00` is no move, `$10`–`$70` move left 1–7 clocks,
and `$F0`–`$80` move right 1–8 clocks (two's complement). `HMOVE` applies the offset. The sign is
the classic trap: **negative moves right**, positive moves left.

The routine uses both: the loop's subtraction count sets the coarse strobe, and the encoded
remainder sets the fine value.

### Section 2: The Divide-by-15 Loop

Each iteration is `SBC #15` (2 cycles) plus a taken `BCS` (3) = 5 cycles = 15 color clocks. The
loop subtracts until the carry clears, which means the target has underflowed. It runs one extra
subtraction to detect that underflow, so A exits as a negative byte (`$F1`–`$FF`): the target
minus 15 × (quotient + 1).

`EOR #7` maps the negative remainder to the signed fine value (`u − 9`, where `u = −A` is the
overshoot; positive means left), and four `ASL`s move it into the high nibble. Then:

```asm
    STA HMP0
    STA RESP0       ; coarse position at the beam's current clock
    STA WSYNC
    STA HMOVE       ; apply the fine motion
```

The routine spends about two lines. Call it in VBLANK, never inside a tight visible kernel.

::: tip HMOVE and HBLANK
`HMOVE` must be strobed in HBLANK; the `STA WSYNC` before it is what lands it there. An `HMOVE` in
HBLANK blanks the leftmost 8 pixels of that scanline. Here the strobe happens on a VBLANK line, so
the mask falls on a blank line and the visible picture is clean.
:::

### Section 3: The Output Delay and the +3 Bias

The routine's landing has a constant offset. The coarse position is
`15 × (quotient + 1) − 12`, and `EOR #7` encodes the overshoot `u` as `u − 9`, while exact
placement needs `u − 12`. The three-clock difference means the routine lands **three pixels
left** of the value passed to it. This is a property of the routine, not the emulator: passing 19
puts the sprite at X=16, passing 51 puts it at 48, and so on.

The program therefore stores `target + 3` in its position table. This is not a fudge hidden in
the code — it is a calibration, and the doc records it. The measured result is exact:

| Table value | Measured TIA X | Capture x |
|---|---|---|
| 19 | 16 | 121 |
| 51 | 48 | 313 |
| 83 | 80 | 505 |
| 115 | 112 | 697 |
| 147 | 144 | 889 |

All five positions were measured in scratch captures at each tour step; the two committed
captures are X=16 and X=112.

If your own TIA or emulator variant lands a pixel off, re-measure and adjust the bias; the
routine's structure does not change.

### Section 4: The Tour and the Frame

`FrameCounter` counts to 60, then `PosIndex` advances through the five-entry table and wraps.
`SetHorizPos` runs every frame in VBLANK, so the position is stable before the visible area
starts. The sprite's vertical schedule is the Lesson 25 kernel: 80 blank lines, 8 body rows, one
clear line, 103 blank lines, for 192 visible lines.

The frame is the course standard: 3 VSYNC lines, 37 VBLANK lines, 192 visible lines, 30 overscan
lines = 262.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson26.bin \
  lessons/part4-sprites/26-horizontal-positioning/26-horizontal-positioning.asm
stella build/lesson26.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 26: Horizontal Positioning — The Divide-by-15 Trick — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Moves the Lesson 25 invader through five exact horizontal positions —
;   X = 16, 48, 80, 112, 144 — one every 60 frames.  Each frame the VBLANK
;   code calls SetHorizPos with the current target.
;
; The two tools of horizontal positioning:
;   - RESP0 is a strobe: it sets player 0's position counter to wherever the
;     beam is when the write lands.  When you strobe determines the coarse
;     position, in 3-color-clock steps (the CPU runs 3 clocks per cycle).
;   - HMP0 + HMOVE apply a signed fine offset of -8..+7 color clocks.  The
;     high nibble of HMP0 holds the value; negative moves RIGHT, positive
;     moves LEFT.  HMOVE must be strobed in HBLANK.
;
; The divide-by-15 routine:
;   Each SBC #15 / BCS iteration costs 5 CPU cycles = 15 color clocks of
;   beam travel.  The loop subtracts 15 until the carry clears; it runs one
;   extra time to detect the underflow, so A exits as a negative byte
;   ($F1..$FF).  EOR #7 and four ASLs turn that into the signed fine value
;   (positive = left).  The routine then strobes RESP0 and, on the next
;   line's HBLANK, HMOVE.
;
;   The routine's landing has a constant offset: the coarse position is
;   15 x (quotient + 1) - 12, and EOR #7 encodes the overshoot u as u - 9
;   where exact placement needs u - 12.  The three-clock difference means
;   the routine lands three pixels left of the value passed to it, so the
;   table stores target + 3 and the measured X is exact.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; The sprite sits at visible line 80 (scanline 117), exactly as in Lesson 25.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), PosStep (A = the new 0..4 index, every
;   60 frames), PosApply (A = the biased table value, every frame), Resp0Write
;   (the coarse strobe; its cycle advances with the table), HmoveApply (the
;   fine-motion strobe, next line), VisibleStart (37), BodyStart (117),
;   OverscanStart (229).
;
; Build: acme -f plain -o build/lesson26.bin \
;        lessons/part4-sprites/26-horizontal-positioning/26-horizontal-positioning.asm
; Run:   stella build/lesson26.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
VISIBLE_LINES  = 192
SPRITE_TOP     = 80
SPRITE_HEIGHT  = 8
POS_FRAMES     = 60     ; ~1 second per position
POS_COUNT      = 5

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameCounter   = $80
PosIndex       = $81    ; 0..4, the current entry in PosTable

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the tour tick: advance the position every POS_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #POS_FRAMES
    BNE ApplyPos
    LDA #$00
    STA FrameCounter
    INC PosIndex
    LDA PosIndex
    CMP #POS_COUNT
    BNE PosStepStore
    LDA #$00
PosStepStore:
PosStep:                    ; checkpoint: A = the new index (one hit per 60 frames)
    STA PosIndex

; --- position the player for this frame ---
ApplyPos:
    LDX PosIndex
    LDA PosTable,X
PosApply:                   ; checkpoint: A = the biased table value (target + 3)
    JSR SetHorizPos

    LDA #$42
    STA COLUP0              ; red
    LDA #$02
    STA COLUBK              ; dark neutral
    LDA #$00
    STA NUSIZ0
    STA REFP0

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — the Lesson 25 kernel, unchanged except for the moving X
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK
    LDX #SPRITE_TOP
VisibleStart:
TopLoop:
    STA WSYNC
    DEX
    BNE TopLoop

    LDX #0
BodyStart:
BodyLoop:
    LDA SpriteShape,X
SpriteWrite:
    STA GRP0
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0
    STA WSYNC

    LDX #(VISIBLE_LINES - SPRITE_TOP - SPRITE_HEIGHT - 1)
BottomLoop:
    STA WSYNC
    DEX
    BNE BottomLoop

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SET HORIZONTAL POSITION — the classic divide-by-15 routine
; =============================================================================
; Input: A = the biased target (target + 3), 0-162.  Clobbers A only; X and Y survive.
; The routine spends about two lines, so call it in VBLANK.
SetHorizPos:
    STA WSYNC               ; start on a fresh line
    SEC
Div15:
    SBC #15                 ; each iteration = 5 cycles = 15 clocks of beam
    BCS Div15
    EOR #7                  ; the negative remainder becomes the signed fine value
    ASL                     ; move bits 0-3 into HMP0's high nibble
    ASL
    ASL
    ASL
    STA HMP0
Resp0Write:                 ; checkpoint: the coarse strobe (cycle 5 x SBC count + 14)
    STA RESP0               ; set the position counter to the beam's clock
    STA WSYNC               ; move to the next line's HBLANK
HmoveApply:                 ; checkpoint: next line, HBLANK
    STA HMOVE               ; apply HMP0 (and the other HM registers)
    RTS

; =============================================================================
; POSITION TABLE — five targets, left to right
; =============================================================================
PosTable:
    !byte 19, 51, 83, 115, 147   ; target + 3 (the routine's output-delay bias)

; =============================================================================
; SPRITE SHAPE — the Lesson 25 invader
; =============================================================================
SpriteShape:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %11011011
    !byte %11111111
    !byte %00100100
    !byte %01011010
    !byte %10100101

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
> `lessons/part4-sprites/26-horizontal-positioning/26-horizontal-positioning.asm`.

### Code Walkthrough

#### Step 1 — The tour tick

`INC FrameCounter` runs every frame. At 60 it wraps and `PosIndex` advances; after index 4 it
wraps to 0. `PosStep` sits on the tick's `STA PosIndex`, so it fires once per second, not once per
frame.

#### Step 2 — The table and the call

`LDX PosIndex` / `LDA PosTable,X` loads the biased target (19, 51, 83, 115, 147), and `JSR
SetHorizPos` runs the routine. `PosApply` sits on the `JSR`, so its A value is the table value.

#### Step 3 — The divide-by-15 loop

`SEC` clears the borrow, and `SBC #15` / `BCS` repeats while the subtraction does not underflow.
The subtraction count sets the coarse position; A exits negative, and the `EOR #7`/`ASL` encoding
recovers the fine remainder.

#### Step 4 — The fine value

`EOR #7` converts the negative remainder to the signed nibble, four `ASL`s move it into `HMP0`, and
`STA HMP0` / `STA RESP0` / `STA WSYNC` / `STA HMOVE` apply the coarse and fine parts. The `RESP0`
strobe is on VBLANK line 1; `HMOVE` is on line 2's HBLANK. The visible picture is untouched.

#### Step 5 — The kernel

The vertical kernel is unchanged from Lesson 25: 80 top lines, 8 body rows, a clear line, 103
bottom lines. Only the horizontal position changes between frames.

#### Step 6 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `PosStep` | `$F03B` | A = the new index; hits at frames **60, 120, 180, 240, 300** | the tour tick |
| `PosApply` | `$F042` | A = the table value (19/51/83/115/147), every frame | the routine's input |
| `Resp0Write` | `$F0A2` | VBLANK line 1; the cycle advances with the table: **24 / 34 / 44 / 54 / 64** | the coarse strobe |
| `HmoveApply` | `$F0A6` | VBLANK line 2, cycle 0 (the strobe's effect at cycle 3) | the fine-motion strobe |
| `VisibleStart` | `$F060` | 37, cycle 7 (first hit) | the top loop's first line |
| `BodyStart` | `$F067` | **117, cycle 6**; 8 hits per frame | the first sprite line |
| `OverscanStart` | `$F080` | 229, cycle 4 | overscan's first line |

## What You Should See

The red invader at five positions across the picture, one per second: X = 16, 48, 80, 112, 144
(capture x = 121, 313, 505, 697, 889), at the same eight scanlines (capture y = 359–383). The
motion is a jump, not a slide; the sprite is stable for a full second at each position, which is
what makes each capture unambiguous.

![Stella running the Lesson 26 ROM with the invader at X=16](/images/lesson26/position-a.png)

*Position A, captured from the committed ROM: the invader at TIA X = 16 (capture x = 121–168).*

![Stella running the Lesson 26 ROM with the invader at X=112](/images/lesson26/position-b.png)

*Position B, captured later in the tour: TIA X = 112 (capture x = 697–744). The two captures are
96 TIA pixels apart (576 capture pixels) — three one-second tour steps: six 15-clock coarse steps
(90 clocks) plus the six-clock fine change from +2 to −4.*

<RomPlayer rom="/roms/part4-sprites/26-horizontal-positioning/26-horizontal-positioning.bin" title="Lesson 26 — Horizontal Positioning" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson26.sym -o build/lesson26.bin \
  lessons/part4-sprites/26-horizontal-positioning/26-horizontal-positioning.asm
grep -E "PosStep|PosApply|Resp0Write|HmoveApply" build/lesson26.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F03B' \
  docs/public/roms/part4-sprites/26-horizontal-positioning/26-horizontal-positioning.bin
```

- **`$F03B` (`PosStep`)**: frames 60, 120, 180, 240, 300 with A = 1, 2, 3, 4, 0. One hit per
  second.
- **`$F042` (`PosApply`)**: every frame, A = the table value. The five values repeat.
- **`$F0A2` (`Resp0Write`)**: VBLANK line 1; the cycle advances with the table (24 at X=16, 34 at
  X=48, …, 64 at X=144). **`$F0A6` (`HmoveApply`)**: VBLANK line 2, cycle 0 (effect 3, in HBLANK).
  Both are before the visible area, so the position is ready for line 37.

## Exercises

### Exercise 1: A Single Target

**Challenge:** park the sprite at X=120 and remove the tour.

**Hints:**
1. Delete the frame counter and the table; load `#123` (120 + the 3-pixel bias) every frame.
2. Keep the `JSR SetHorizPos` in VBLANK.
3. The vertical kernel does not change.

**Expected Result:** the invader at TIA X = 120 (capture x = 745–792), the same eight scanlines.
Measured in a scratch capture: x = 745–792.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: The Far Right

**Challenge:** put the sprite at X=152 and explain the quotient.

**Hints:**
1. The program passes 155 (152 + the bias). 155 = 10 × 15 + 5, so the loop subtracts 11 times and
   leaves A = `$F6`; `EOR #7` / `ASL` gives `HMP0 = $10` (+1 left).
2. The coarse position is 153; the one-clock fine move lands it at 152.
3. At X=152 the 8-pixel sprite spans to X=159 — the last visible clock.

**Expected Result:** the invader at TIA X = 152; its right edge reaches capture x = 984, the edge
of the picture. Measured: x = 937–984.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Ping-Pong *(Stretch Goal)*

**Challenge:** bounce between X=32 and X=128 every 60 frames.

**Hints:**
1. A two-entry table (35 and 131, after the bias) and a 0/1 index are enough.
2. On the tick, `EOR #1` flips the index.
3. The routine and the kernel stay the same.

**Expected Result:** the invader alternates between TIA X = 32 (capture x = 217–264) and X = 128
(capture x = 793–840). Measured in scratch captures.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **`RESP0` is the coarse tool**: it sets the position counter to the beam's clock; the CPU's 3-clock granularity quantizes it
- ✅ **`HMP0` + `HMOVE` are the fine tool**: a signed high nibble from −8 to +7 color clocks, applied by a strobe in HBLANK (the `STA WSYNC` lands it there); in HBLANK it also blanks the leftmost 8 pixels of that line
- ✅ **One `SBC #15` iteration is 15 clocks**: five CPU cycles × three color clocks; the loop converts the target into coarse steps plus a remainder
- ✅ **The −3 offset is constant**: the encoded fine value is three clocks left of exact placement, so the table stores target + 3 and the measured X is exact
- ✅ **Negative moves right**: the fine value's sign catches everyone; the routine's `EOR #7` handles it
- ✅ **Position in VBLANK**: the strobes run before line 37, so the visible picture never sees a mid-frame change
- ✅ **The vertical schedule is independent**: the same eight scanlines at every X

## What's Next

The invader jumps between five positions. [Lesson 27: Sprite Movement](/part4-sprites/27-sprite-movement)
makes it move every frame and hands the direction to the joystick: `SWCHA`, active-low bits, a
velocity byte, and a bounce at the edges.
