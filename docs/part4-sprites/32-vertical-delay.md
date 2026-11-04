---
title: "Lesson 32: Vertical Delay — VDELP0, VDELP1"
description: "VDELP1 delays player 1's graphic by one scanline. Lesson 32 draws two identical 16-row blocks and measures the one-line offset, then shows the trigger rule that clears the delayed register and the moving-sprite case where the offset stays constant."
prev:
  text: "Lesson 31: Copies and Sizes"
  link: "/part4-sprites/31-copies-and-sizes"
next:
  text: "Lesson 33: Paddle & Keyboard Controllers"
  link: "/part4-sprites/33-paddle-keyboard-controllers"
---

# Lesson 32: Vertical Delay — VDELP0, VDELP1

> **Part 4: Sprites** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 25 (the sprite shape and `GRP0`), Lesson 26 (the divide-by-15 positioning routine), Lesson 28 (`GRP1` and the one-`HMOVE` rule), Lesson 30 (per-line kernels)
> **You will learn:** what `VDELP1` does; how the graphic register is double-buffered; the one-scanline offset and why it does not accumulate; the trigger rule (a `GRP0` write latches player 1's pending graphic, a `GRP1` write latches player 0's); how to clear a delayed player cleanly; when the delay is useful
> **You will build:** "the shadow" — two identical 16-row striped blocks, one red and one blue, with player 1 exactly one scanline lower; plus three exercises: no delay, the delay on player 0, and a moving delayed sprite

## Introduction

`VDELP1` is a one-bit register with a subtle effect: it delays player 1's graphic output by one
scanline. The graphic register becomes double-buffered. You write a row; the TIA displays it one
line later. The delay is uniform and constant — it is a latch, not a speed.

The lesson draws two identical striped blocks at the same vertical position. Player 0 is normal;
player 1 has `VDELP1` set. The blue block appears exactly one scanline below the red one. In the
capture that is a three-pixel offset at the top edge, and it is the visible proof of the latch.

There is a second hardware detail that costs a kernel an afternoon if you miss it: the copy is
**cross-coupled**. A write to `GRP0` latches player 1's pending graphic; a write to `GRP1` latches
player 0's. A `GRP1`-only clear therefore never latches player 1's zero, and the delayed value can
stay stuck on screen. The lesson's clear writes `GRP0 = 0` first (latching player 1's last row for
the clear line), then `GRP1 = 0`; the bottom loop keeps writing `GRP0 = 0` to latch the zero.

::: details TypeScript Equivalent
A one-line delay is a variable that lags one line:

```typescript
let grp1 = 0;
let delayed = 0;
function line(next: number) {
  delayed = grp1;   // last line's write becomes this line's output
  grp1 = next;      // stage this line's value
  return delayed;
}
```

The 2600 version is the same two-slot latch in hardware. The trigger rule is the part the analogy
hides: a `GRP0` write latches player 1's pending graphic into its delayed slot, and a `GRP1`
write latches player 0's.
:::

## Theory

### Section 1: The Delay Bit

`VDELP0`/`VDELP1` bit 0 delays that player's graphic by one scanline. The write goes to the
primary graphic register; the displayed value comes from the delayed register, which is one line
behind. The delay applies to every row, including the clear, so the whole sprite shifts down one
line; nothing accumulates.

The delay is useful when a kernel needs to stage the next line's shape while the current one is
still displayed. Flicker-free animation and the 48-pixel trick are the classic uses; this lesson
names them but keeps the demo to the one-line offset.

### Section 2: The Cross-Coupled Trigger

The copy is **cross-coupled**: writing `GRP0` latches player 1's pending graphic, and writing
`GRP1` latches player 0's. That is the detail that makes a naive clear fail:

```asm
    LDA #$00
    STA GRP0        ; latch P1's last row for the clear line
    STA GRP1        ; primary = 0
    STA WSYNC
```

If you write only `GRP1 = 0`, player 1's delayed slot never receives the zero: it keeps the last
row a `GRP0` write latched (row 14, so row 15 never appears), and it stays on screen if no further
`GRP0` write latches the zero. Writing `GRP0 = 0` first latches the pending last row (so the clear line
still shows it), then `GRP1 = 0` loads the zero; the bottom loop writes `GRP0 = 0` every line to
latch the zero. The order matters: `GRP1 = 0` before `GRP0` would latch the zero over the last row
and cut it off.

### Section 3: The One-Line Offset

Both players use the same 16-row shape at visible line 88 (scanline 125). Player 0's first row is
on line 125; player 1's delayed first row is on line 126. The measured capture: red top at y=385,
blue top at y=388 — one scanline at the capture's ~3.1 px per line. The bottoms differ by the same
line; the striped pattern makes the offset easy to see.

### Section 4: The Frame

The frame is 3 + 37 + 192 + 30 = 262. The body is 16 rows at scanline 125; 88 top + 16 body +
1 clear + 87 bottom = 192 visible lines.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson32.bin \
  lessons/part4-sprites/32-vertical-delay/32-vertical-delay.asm
stella build/lesson32.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 32: Vertical Delay — VDELP0, VDELP1 — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Draws two identical 16-row striped blocks, one red (P0) and one blue
;   (P1).  P1 has VDELP1 set, so its graphic is delayed by one scanline:
;   P1 appears exactly one line lower than P0.  The one-line offset is the
;   visible proof of the vertical-delay latch.
;
; What VDEL does:
;   VDELP0/VDELP1 bit 0 delays that player's graphic output by one scanline.
;   The graphic register is double-buffered: the value written on line N is
;   displayed on line N+1.  The copy is cross-coupled: a GRP0 write latches
;   player 1's pending graphic, and a GRP1 write latches player 0's.  The
;   delay is uniform, so the whole sprite shifts down one line; nothing
;   accumulates.
;
;   The latch is useful when a kernel needs to stage the next line's shape
;   while the current line is still displayed.  The 48-pixel trick and
;   flicker-free animation are the classic uses; they are named here, not
;   implemented.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; Both sprites start at visible line 88 (scanline 125): 88 top + 16 body +
; 1 clear + 87 bottom = 192.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), PosApply0/PosApply1, Resp0Write/
;   Resp1Write, HmoveApply, VisibleStart (37), BodyStart (125, 16 hits),
;   VdelWrite (A = $01), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson32.bin \
;        lessons/part4-sprites/32-vertical-delay/32-vertical-delay.asm
; Run:   stella build/lesson32.bin
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
SPRITE_TOP     = 88
SPRITE_HEIGHT  = 16
P0_X           = 48
P1_X           = 104
POS_BIAS       = 3

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    LDA #(P0_X + POS_BIAS)
PosApply0:                  ; checkpoint: P0's biased target
    JSR SetCoarse0
    LDA #(P1_X + POS_BIAS)
PosApply1:                  ; checkpoint: P1's biased target
    JSR SetCoarse1
    STA WSYNC
HmoveApply:                 ; checkpoint: the single HMOVE
    STA HMOVE

    LDA #$42
    STA COLUP0
    LDA #$84
    STA COLUP1
    LDA #$02
    STA COLUBK
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1
    LDA #$01
VdelWrite:                  ; checkpoint: A = $01
    STA VDELP1              ; delay player 1 by one scanline

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — identical shapes; P1 is one line lower
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
    LDA Shape,X
    STA GRP0
    LDA Shape,X
    STA GRP1
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0                ; trigger the delayed copy of the last row
    STA GRP1                ; then clear the primary
    STA WSYNC

    LDX #(VISIBLE_LINES - SPRITE_TOP - SPRITE_HEIGHT - 1)
BottomLoop:
    STA GRP0                ; keep triggering the delayed copy with 0
    STA WSYNC
    DEX
    BNE BottomLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; COARSE POSITIONING — two players, one HMOVE
; =============================================================================
SetCoarse0:
    STA WSYNC
    SEC
Div0:
    SBC #15
    BCS Div0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
Resp0Write:                 ; checkpoint: P0's coarse strobe
    STA RESP0
    RTS

SetCoarse1:
    STA WSYNC
    SEC
Div1:
    SBC #15
    BCS Div1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
Resp1Write:                 ; checkpoint: P1's coarse strobe
    STA RESP1
    RTS

; =============================================================================
; SHAPE — a 16-row striped block
; =============================================================================
Shape:
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001
    !byte %11111111
    !byte %10000001
    !byte %10000001
    !byte %10000001

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
> `lessons/part4-sprites/32-vertical-delay/32-vertical-delay.asm`.

### Code Walkthrough

#### Step 1 — Position both players

`SetCoarse0`/`SetCoarse1` set `HMP0`/`HMP1` and strobe `RESP0`/`RESP1`; one `HMOVE` applies both
fine offsets (the Lesson 28 rule). P0 is at X=48, P1 at X=104.

#### Step 2 — Set the delay

`LDA #$01` / `VdelWrite` / `STA VDELP1` turns on player 1's delay. The label is the evidence pin:
the log reports A=`$01` on line 3.

#### Step 3 — Draw both players

The body writes `GRP0`, then `GRP1`, then parks. The `GRP0` write latches player 1's previous row
into the delayed output; the `GRP1` write updates player 1's primary and latches player 0's
previous row. The delayed player 1 output is therefore one row behind.

#### Step 4 — Clear with a trigger

After row 15, the kernel writes `GRP0 = 0` (latching player 1's last row for the clear line), then
`GRP1 = 0`, then parks. The bottom loop writes `GRP0 = 0` every line, latching the zero into
player 1's delayed output.

#### Step 5 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `PosApply0` | `$F027` | A = `$33` (51), line 0 cycle 18 | P0's target |
| `PosApply1` | `$F02C` | A = `$6B` (107), line 1 cycle 45 | P1's target |
| `Resp0Write` | `$F0A5` | line 1 cycle 34 | P0's coarse strobe |
| `Resp1Write` | `$F0B7` | line 2 cycle 54 | P1's coarse strobe |
| `HmoveApply` | `$F031` | line 2 cycle 66 (the `WSYNC` stall); `STA HMOVE` executes on line 3 cycle 0 | the single fine strobe |
| `VdelWrite` | `$F04B` | line 3 cycle 34; A = `$01` | the delay bit |
| `VisibleStart` | `$F05A` | 37, cycle 7 (first hit) | the top loop's first line |
| `BodyStart` | `$F061` | **125, cycle 6**; 16 hits per frame | the first sprite line |
| `OverscanStart` | `$F083` | 229, cycle 4 | overscan's first line |

## What You Should See

Two striped blocks of the same shape: red at capture x = 313–360 and blue at 649–696. The red top
is at y = 385; the blue top is at y = 388 — exactly one scanline lower. The blocks are 16 rows
tall; the blue block's delayed rows follow the red block one line behind throughout.

![Stella running the Lesson 32 ROM: a red block and, one scanline lower, an identical blue block](/images/lesson32/vdel.png)

*The shadow, captured from the committed ROM: red top y = 385, blue top y = 388; both 16-row
striped blocks, one scanline apart. The offset is the VDELP1 latch, and it does not grow.*

<RomPlayer rom="/roms/part4-sprites/32-vertical-delay/32-vertical-delay.bin" title="Lesson 32 — Vertical Delay" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson32.sym -o build/lesson32.bin \
  lessons/part4-sprites/32-vertical-delay/32-vertical-delay.asm
grep -E "VdelWrite|BodyStart|PosApply" build/lesson32.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F04B' \
  docs/public/roms/part4-sprites/32-vertical-delay/32-vertical-delay.bin
```

- **`$F04B` (`VdelWrite`)**: A = `$01` on line 3, once per frame.
- **`$F061` (`BodyStart`)**: line 125, 16 hits.
- **`$F027` / `$F02C`**: the two targets, 51 and 107.

## Exercises

### Exercise 1: No Delay

**Challenge:** turn `VDELP1` off and align the two players.

**Hints:**
1. Store 0 to `VDELP1` instead of 1.
2. Both graphics registers now reach the screen on the line they are written.
3. Nothing else changes.

**Expected Result:** both striped blocks share the same top row (the red and blue tops align).

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Delay Player 0

**Challenge:** delay player 0 instead of player 1.

**Hints:**
1. Store 1 to `VDELP0` (and 0 to `VDELP1`).
2. The red block now sits one line below the blue one.
3. The clear still needs the trigger write.

**Expected Result:** the blue top leads, the red top follows one scanline lower.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Moving with VDEL *(Stretch Goal)*

**Challenge:** move the delayed sprite down 4 lines every 30 frames; show the offset stays one line.

**Hints:**
1. Make the top count a variable (`SpriteTop`, 40–120); compute the bottom count from it.
2. Keep `VDELP1` set and move both players together.
3. The offset is a latch, not a velocity: it does not grow.

**Expected Result:** red and blue tops move down together, always one scanline apart. The two
committed captures measure 372/375 and 397/400; the 3-pixel offset stays constant.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **`VDELP1` delays one player by one scanline**: the graphic register is double-buffered
- ✅ **The offset is constant**: a moving delayed sprite stays exactly one line behind, never two or three
- ✅ **The trigger is cross-coupled**: a `GRP0` write latches player 1; a `GRP1` write latches player 0; a `GRP1`-only clear can leave player 1 stuck
- ✅ **Clear with a trigger**: write `GRP0 = 0` (latch the last row), then `GRP1 = 0`; keep writing `GRP0 = 0` in the bottom loop
- ✅ **The delay is symmetric**: `VDELP0` does the same for player 0
- ✅ **The frame is unchanged**: 88 top + 16 body + 1 clear + 87 bottom = 192
- ✅ **The 48-pixel trick and flicker-free animation** are the advanced uses; this lesson only measures the latch

## What's Next

The players, missiles, and ball are all covered. [Lesson 33: Paddle & Keyboard Controllers](/part4-sprites/33-paddle-keyboard-controllers)
turns to input: the paddle's RC timing, the keyboard matrix, and the fire buttons, shown on a
controller monitor.
