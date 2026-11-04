---
title: "Lesson 28: Two Players — GRP0 and GRP1"
description: "Both players follow the same rules: eight bits per line, one write per scanline, their own color and position. Lesson 28 draws two creatures on the same eight lines and applies both fine offsets with a single HMOVE."
prev:
  text: "Lesson 27: Sprite Movement"
  link: "/part4-sprites/27-sprite-movement"
next:
  text: "Lesson 29: Missiles and Ball"
  link: "/part4-sprites/29-missiles-and-ball"
---

# Lesson 28: Two Players — GRP0 and GRP1

> **Part 4: Sprites** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 25 (the player sprite and `GRP0`), Lesson 26 (`SetHorizPos` and the +3 bias), Lesson 27 (moving a sprite every frame)
> **You will learn:** how `GRP1` mirrors `GRP0`; how `COLUP1` and `RESP1`/`HMP1` give player 1 its own identity; why two positioned objects need **one** `HMOVE` after both fine values are set; what happens when the players overlap
> **You will build:** "the meeting" — a red player 0 at X=48 and a blue player 1 at X=104 on the same eight scanlines; plus three exercises: swap the colors, separate them widely, and overlap them to see the priority stack

## Introduction

One player is half the picture. The TIA gives you **two** players, each with its own graphics,
color, and position. They share the scanline budget and the same rules: `GRP0` and `GRP1` are
eight bits wide, bit 7 leftmost, one write per line. What changes is the register name and the
color/position registers that go with it.

This lesson draws both creatures on the same eight scanlines. Player 0 is red at X=48; player 1
is blue at X=104. The shapes are different, so the two halves of the picture read as two
characters rather than a mirror.

There is one important hardware trap. The fine-motion registers (`HMP0`, `HMP1`) persist, and
every `HMOVE` re-applies **all** of them. If you call the classic positioning routine twice, the
second call's `HMOVE` applies the first player's fine offset again — the first sprite ends up a
fixed extra offset from its target. The
lesson splits the routine into two coarse halves and applies one `HMOVE` after both fine values
are set. That is the pattern every multi-object kernel uses.

::: details TypeScript Equivalent
Two objects, each with its own shape, color, and position:

```typescript
type Player = { shape: number[]; color: string; x: number };
const p0: Player = { shape: [0x18, 0x3c, /* … */], color: "red", x: 48 };
const p1: Player = { shape: [0x3c, 0x7e, /* … */], color: "blue", x: 104 };

function drawLine(row: number) {
  return {
    grp0: p0.shape[row], colup0: p0.color, x0: p0.x,
    grp1: p1.shape[row], colup1: p1.color, x1: p1.x,
  };
}
```

The 2600 version writes both graphics registers on each line and positions both objects once per
frame; the single `HMOVE` is the part the analogy hides.
:::

## Theory

### Section 1: GRP1 Is GRP0's Twin

`GRP1` follows exactly the same rules as `GRP0`: eight bits, bit 7 leftmost, one byte per
scanline, and the register holds its value until the next write. `COLUP1` colors player 1, and
`RESP1`/`HMP1` position it. A second shape table and a second write in the body are all the
kernel needs.

The two players share the line's 76 cycles. The body writes `GRP0`, then `GRP1`, then parks; the
two stores take 6 cycles together (3 each); both load/store pairs cost 14, under a fifth of the
76-cycle line.

### Section 2: One HMOVE for Both

`HMOVE` applies **all five** horizontal-motion registers at once. The classic `SetHorizPos`
routine ends with its own `HMOVE`. If you call it for player 0 and then for player 1, the second
`HMOVE` sees `HMP0` still set and moves player 0 a second time.

The fix is to separate coarse from fine:

1. `SetCoarse0` sets `HMP0`, strobes `RESP0`, and returns — no `HMOVE`.
2. `SetCoarse1` sets `HMP1`, strobes `RESP1`, and returns.
3. One `STA WSYNC` / `STA HMOVE` applies both fine offsets.

Both HM registers are rewritten every frame before the single strobe, so no stale value is ever
re-applied. This is the one-HMOVE rule; the same idea scales to the missiles and the ball.

### Section 3: Overlap and Priority

When both players cover the same pixel, the TIA does not blend. By default player 0 has priority
over player 1, so the red pixel wins and the blue one is hidden. Player 1 shows only where its
shape is on and player 0's is off. Exercise 3 puts both at X=80 to make that visible.

The full priority stack was Lesson 20's subject: P0/M0 > P1/M1 > PF/BL > BK.

### Section 4: The Frame

The frame is the course standard: 3 VSYNC lines, 37 VBLANK lines, 192 visible lines, 30 overscan
lines = 262. Both sprites start at visible line 88 (scanline 125), so the kernel parks 88 lines,
writes both players for 8 lines, clears both for one line, and parks the remaining 95:
`88 + 8 + 1 + 95 = 192`.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson28.bin \
  lessons/part4-sprites/28-two-players/28-two-players.asm
stella build/lesson28.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 28: Two Players — GRP0 and GRP1 — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Draws both players on the same eight scanlines: player 0 in red at X=48,
;   player 1 in blue at X=104.  Each has its own shape table and color.
;   The two players share the line budget but not their graphics.
;
; The two players:
;   GRP0 and GRP1 follow the same rules: 8 bits wide, bit 7 leftmost, one
;   write per scanline.  COLUP0/COLUP1 color them; RESP0/RESP1 position
;   them; HMP0/HMP1 carry their fine offsets.
;
; One HMOVE for both:
;   The classic divide-by-15 routine ends with its own HMOVE.  Calling it
;   twice would apply the first object's HMP0 again while positioning the
;   second object — the HM registers persist.  This lesson splits the
;   routine: SetCoarse0 and SetCoarse1 set their HMPx and strobe their
;   RESPx, then one HMOVE applies both fine offsets.  Both HM registers are
;   rewritten every frame before the single strobe, so nothing accumulates.
;   This is the one-HMOVE rule for multi-object kernels.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; Both sprites start at visible line 88 (scanline 125): 88 top lines, 8 body
; rows writing both players, one clear line, 95 bottom lines.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), PosApply0/PosApply1 (A = the biased
;   X targets), Resp0Write/Resp1Write (the coarse strobes), HmoveApply (the
;   single fine-motion strobe), VisibleStart (37), BodyStart (125),
;   OverscanStart (229).
;
; Build: acme -f plain -o build/lesson28.bin \
;        lessons/part4-sprites/28-two-players/28-two-players.asm
; Run:   stella build/lesson28.bin
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
SPRITE_HEIGHT  = 8
P0_TARGET      = 48
P1_TARGET      = 104
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

; --- position both players, then apply both fine offsets once ---
    LDA #(P0_TARGET + POS_BIAS)
PosApply0:                  ; checkpoint: A = P0's biased target
    JSR SetCoarse0
    LDA #(P1_TARGET + POS_BIAS)
PosApply1:                  ; checkpoint: A = P1's biased target
    JSR SetCoarse1
    STA WSYNC
HmoveApply:                 ; checkpoint: the single HMOVE
    STA HMOVE               ; store applied at cycle 2; next instruction at cycle 3
AfterHmove:                 ; verification label: the instruction after HMOVE

    LDA #$42
    STA COLUP0              ; red
    LDA #$84
    STA COLUP1              ; blue
    LDA #$02
    STA COLUBK              ; dark neutral
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — both players on the same eight lines
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
    LDA ShapeP0,X
    STA GRP0
    LDA ShapeP1,X
    STA GRP1
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0
    STA GRP1
    STA WSYNC

    LDX #(VISIBLE_LINES - SPRITE_TOP - SPRITE_HEIGHT - 1)
BottomLoop:
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
; COARSE POSITIONING — set HMPx and strobe RESPx; no HMOVE here
; =============================================================================
; Input: A = the biased target (target + 3).
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
Resp0Write:
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
Resp1Write:
    STA RESP1
    RTS

; =============================================================================
; SHAPES — two different 8-row creatures
; =============================================================================
ShapeP0:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %11011011
    !byte %11111111
    !byte %00100100
    !byte %01011010
    !byte %10100101

ShapeP1:
    !byte %00111100
    !byte %01111110
    !byte %11111111
    !byte %11011011
    !byte %11111111
    !byte %01100110
    !byte %00111100
    !byte %00011000

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
> `lessons/part4-sprites/28-two-players/28-two-players.asm`.

### Code Walkthrough

#### Step 1 — Position both players

`LDA #(P0_TARGET + 3)` / `JSR SetCoarse0` sets `HMP0` and strobes `RESP0`. Then
`LDA #(P1_TARGET + 3)` / `JSR SetCoarse1` sets `HMP1` and strobes `RESP1`. Neither routine
strobes `HMOVE`.

#### Step 2 — Apply both fine offsets once

After both coarse routines, `STA WSYNC` parks the current line and `STA HMOVE` applies `HMP0` and
`HMP1` together. The `STA WSYNC` before it parks the CPU at the end of line 2, so `STA HMOVE`
executes at the start of VBLANK line 3 and the strobe completes by cycle 3 — inside HBLANK.
The debugger's line-2/cycle-66 reading is the `WSYNC` stall point, not the strobe's write. The
visible area has not started, so the fine motion is ready for line 37.

#### Step 3 — The colors and the kernel

`COLUP0=$42` red, `COLUP1=$84` blue, `COLUBK=$02`. The body writes `ShapeP0,X` to `GRP0` and
`ShapeP1,X` to `GRP1`, then parks. The clear line writes zero to both.

#### Step 4 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `PosApply0` | `$F027` | A = `$33` (51 = 48 + 3), line 0 cycle 18 | P0's biased target |
| `PosApply1` | `$F02C` | A = `$6B` (107 = 104 + 3), line 1 cycle 45 | P1's biased target |
| `Resp0Write` | `$F09F` | VBLANK line 1, cycle 34 | P0's coarse strobe |
| `Resp1Write` | `$F0B1` | VBLANK line 2, cycle 54 | P1's coarse strobe |
| `HmoveApply` | `$F031` | VBLANK line 3, cycle 0 (the strobe completes by cycle 3) | the single fine strobe |
| `VisibleStart` | `$F056` | 37, cycle 7 (first hit) | the top loop's first line |
| `BodyStart` | `$F05D` | **125, cycle 6**; 8 hits per frame | the first sprite line |
| `OverscanStart` | `$F07D` | 229, cycle 4 | overscan's first line |

## What You Should See

Two creatures on the same eight scanlines: a red player 0 at X=48 (capture x = 313–360) and a
blue player 1 at X=104 (capture x = 649–696). Both span capture y = 385–408. The shapes differ,
so the picture reads as two characters facing each other across the dark field.

![Stella running the Lesson 28 ROM: a red player 0 on the left and a blue player 1 on the right](/images/lesson28/two-players.png)

*The meeting, captured from the committed ROM: red at capture x = 313–360 (TIA X=48), blue at
649–696 (X=104), both on scanlines 125–132 (capture y = 385–408).*

<RomPlayer rom="/roms/part4-sprites/28-two-players/28-two-players.bin" title="Lesson 28 — Two Players" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson28.sym -o build/lesson28.bin \
  lessons/part4-sprites/28-two-players/28-two-players.asm
grep -E "PosApply0|PosApply1|Resp0Write|Resp1Write|HmoveApply" build/lesson28.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F031' \
  docs/public/roms/part4-sprites/28-two-players/28-two-players.bin
```

- **`$F027` / `$F02C`**: the two biased targets, 51 and 107.
- **`$F09F` / `$F0B1`**: the two coarse strobes, one line apart.
- **`$F031`**: the single `HMOVE`, after both fine values are set; it executes on VBLANK line 3,
  cycle 0, and the strobe completes by cycle 3 (HBLANK).

## Exercises

### Exercise 1: Swap the Colors

**Challenge:** make player 0 blue and player 1 red.

**Hints:**
1. Only the two color stores change.
2. The shapes, positions, and the single `HMOVE` stay.
3. The priority does not change: player 0 still wins overlaps.

**Expected Result:** blue at capture x = 313–360, red at 649–696; the same scanlines.
Measured in a scratch capture.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Wide Separation

**Challenge:** move player 0 to X=16 and player 1 to X=140.

**Hints:**
1. Change the two target constants; the +3 bias still applies.
2. At X=16 the red sprite spans capture x = 121–168; at X=140 the blue spans 865–912.
3. The single `HMOVE` applies both new fine values.

**Expected Result:** the two players at the far edges, same scanlines. Measured: red
121–168, blue 865–912.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The Overlap *(Stretch Goal)*

**Challenge:** put both players at X=80 and explain the result.

**Hints:**
1. Set both targets to 80 (83 after the bias).
2. The shapes overlap on the same eight lines; the TIA does not blend.
3. Player 0 has priority, so red wins every pixel where both are on; blue shows only where
   player 1 is on and player 0 is off.

**Expected Result:** both sprites occupy capture x = 505–552; the overlap is predominantly red
with blue fringes where the shapes differ. Measured in a scratch capture.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **`GRP1` is `GRP0`'s twin**: eight bits per line, bit 7 leftmost, one write per scanline
- ✅ **Player 1 has its own identity**: `COLUP1` colors it, `RESP1`/`HMP1` position it, and a second shape table draws it
- ✅ **One `HMOVE` for all objects**: the HM registers persist and every `HMOVE` re-applies them; set every value first, then strobe once
- ✅ **Split coarse from fine**: `SetCoarse0`/`SetCoarse1` end with `RTS`, not `HMOVE`; the single strobe comes after both
- ✅ **The kernel budget is shared**: two graphic writes plus the park fit comfortably in 76 cycles
- ✅ **Overlap is priority, not blending**: player 0 covers player 1 where both are on
- ✅ **The vertical schedule is unchanged**: 88 top + 8 body + 1 clear + 95 bottom = 192

## What's Next

Two players are on the field. [Lesson 29: Missiles and Ball](/part4-sprites/29-missiles-and-ball)
adds the small objects: two missiles and the ball, each with its own width and position, colored
by the player or playfield register it shares — and the same one-`HMOVE` rule for four positioned
objects.
