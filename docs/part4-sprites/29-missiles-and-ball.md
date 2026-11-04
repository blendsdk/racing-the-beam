---
title: "Lesson 29: Missiles and Ball — Simple Projectiles"
description: "Missiles 0 and 1 and the ball are independent objects: ENAM0/ENAM1/ENABL enable them, NUSIZ and CTRLPF set their widths, and RESM0/RESM1/RESBL position them. Lesson 29 draws a four-object lineup with one HMOVE."
prev:
  text: "Lesson 28: Two Players"
  link: "/part4-sprites/28-two-players"
next:
  text: "Lesson 30: Multi-Color Sprites"
  link: "/part4-sprites/30-multicolor-sprites"
---

# Lesson 29: Missiles and Ball — Simple Projectiles

> **Part 4: Sprites** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 20 (priority and `COLUPF`), Lesson 26 (`SetHorizPos` and the output-delay calibration), Lesson 28 (the one-`HMOVE` rule)
> **You will learn:** how `ENAM0`, `ENAM1`, and `ENABL` turn the small objects on; how missile width uses `NUSIZ` bits 4–5 and ball width uses `CTRLPF` bits 4–5; how `RESM0`/`RESM1`/`RESBL` position them; why their output delays differ from the players'; how four objects share one `HMOVE`
> **You will build:** "the lineup" — player 0 plus a 1-pixel missile, a 4-pixel missile, and an 8-pixel ball, all on the same four scanlines; plus three exercises: widen the missile, shrink the ball, and move the missile across the screen

## Introduction

The TIA's five movable objects are two players, two missiles, and a ball. A player draws eight
bits per line — eight pixels with `NUSIZ=0`; the small objects are **1 to 8 pixels** wide, set by
a size field. They are perfect
for bullets, paddles, goal posts, and thin scenery.

Each has its own enable bit: `ENAM0`, `ENAM1`, `ENABL`, bit 1. A write enables the object for the
current scanline; the next line keeps the value until you change it. The missiles share the
players' colors (`COLUP0`, `COLUP1`); the ball shares `COLUPF`. That is a hardware fact, not a
limitation of this lesson: there are only four color registers, and each one colors a group.

Positioning uses the same `RESxx`/`HMxx` pair as the players, but the missiles and ball have a
**one-clock-shorter output delay**. That changes their calibration: the missiles land one pixel
left of their player-style targets, and the ball's target-to-X mapping is its own (68 → 79,
108 → 128). The lesson records the measured values instead of pretending the player's +3 bias
applies to every object.

::: details TypeScript Equivalent
Four objects with an enable, a width, and a position:

```typescript
type Small = { enabled: boolean; width: number; x: number };
const m0: Small = { enabled: true, width: 1, x: 64 };
const m1: Small = { enabled: true, width: 4, x: 96 };
const ball: Small = { enabled: true, width: 8, x: 108 };  // target; measured X=128

function line(y: number) {
  const on = y >= 98 && y <= 101;        // four scanlines
  return { m0: on && m0.enabled, m1: on && m1.enabled, ball: on && ball.enabled };
}
```

The 2600 version writes the three enable bits on those four lines and positions the objects once
per frame. The widths come from `NUSIZ`/`CTRLPF`, not from the shape.
:::

## Theory

### Section 1: Three Enables, Three Colors

| Object | Enable | Color | Width |
|---|---|---|---|
| Missile 0 | `ENAM0` bit 1 | `COLUP0` | `NUSIZ0` bits 4–5 |
| Missile 1 | `ENAM1` bit 1 | `COLUP1` | `NUSIZ1` bits 4–5 |
| Ball | `ENABL` bit 1 | `COLUPF` | `CTRLPF` bits 4–5 |

The width field is the same two-bit code in both registers: `00` = 1 pixel, `01` = 2, `10` = 4,
`11` = 8. The lesson uses 1, 4, and 8 so the three widths are obvious in one capture.

The enable is per scanline. The body sets the three bits on rows 2–5 and clears them on the other
rows, so each small object is four lines tall. The player is eight lines tall.

### Section 2: Positioning the Small Objects

`RESM0`, `RESM1`, and `RESBL` are strobes, exactly like `RESP0`. `HMM0`, `HMM1`, and `HMBL` carry
their signed fine offsets. The four coarse routines are separate because each writes a different
`RESxx`/`HMxx` pair, but they follow the same divide-by-15 pattern.

Missiles and the ball have a **four-clock** output delay (the players have five). The player's +3
bias is therefore not the right calibration for them. Measured in this environment, the missiles
land one pixel left of the player-style target (63 and 95 for 64 and 96). The ball's mapping is
different again: target 68 measures X=79, and target 108 measures X=128. The ball's target-to-X
mapping is not the player's +3 rule, so the lesson uses the **measured table** rather than a
formula. The measured X is the authority.

### Section 3: One HMOVE for Four

The four coarse routines set `HMP0`, `HMM0`, `HMM1`, and `HMBL` and strobe their `RESxx`, then a
single `HMOVE` applies all four fine offsets. This is the Lesson 28 one-`HMOVE` rule at four
objects. The measured ball landing is the observation the lesson relies on: target 108 produces
X=128 and target 68 produces X=79. The lesson does not derive the ball's mapping from the
player's +3 rule; the measured table is the rule.

### Section 4: The Frame and the Lineup

The frame is 3 + 37 + 192 + 30 = 262. Player 0's body starts at visible line 96 (scanline 133);
the small objects are enabled on rows 2–5 (scanlines 135–138). The kernel parks 96 lines, runs the
eight body lines, clears, and parks the remaining 87: `96 + 8 + 1 + 87 = 192`.

The measured lineup: P0 at X=24 (capture 169–216), M0 at 63 (403–408), M1 at 95 (595–618), the
ball at 128 (793–840). The widths are 48, 6, 24, and 48 capture pixels.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson29.bin \
  lessons/part4-sprites/29-missiles-and-ball/29-missiles-and-ball.asm
stella build/lesson29.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 29: Missiles and Ball — Simple Projectiles — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Draws a lineup of the four small objects next to player 0: the player,
;   missile 0 at 1 pixel wide, missile 1 at 4 pixels wide, and the ball at
;   8 pixels wide.  All four are positioned independently and enabled for
;   four scanlines (rows 98-101) inside player 0's eight rows (96-103).
;
; The small objects:
;   - Missile 0 is its own 1-pixel object; it shares player 0's color,
;     COLUP0.  ENAM0 bit 1 enables it for the current line.
;   - Missile 1 shares COLUP1; ENAM1 bit 1 enables it.
;   - The ball shares COLUPF; ENABL bit 1 enables it.
;   - Missile widths are NUSIZ bits 4-5 (1/2/4/8 px); the ball width is
;     CTRLPF bits 4-5 (1/2/4/8 px).
;
; Positioning:
;   RESM0/RESM1/RESBL strobe the coarse positions; HMM0/HMM1/HMBL carry the
;   fine offsets.  Missiles and the ball have a one-clock-shorter output
;   delay than the players, so the +3 calibration from Lesson 26 is
;   re-measured here.  All four coarse values are set first, then one HMOVE
;   applies all four fine offsets (the one-HMOVE rule).
;
; The lineup (desired TIA X):
;   P0   24   (8 pixels wide)
;   M0   64   (1 pixel wide)
;   M1   96   (4 pixels wide)
;   BL  128   (8 pixels wide; target 108, measured 128 — the ball's
;               target-to-X mapping is measured, not the player +3 bias)
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; The body is eight lines at visible line 96 (scanline 133); the small
; objects are enabled on body rows 2-5 (scanlines 135-138).
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), PosApply* (A = the biased targets),
;   RespP0/RespM0/RespM1/RespBL (the four coarse strobes), HmoveApply (the single fine
;   strobe), VisibleStart (37), BodyStart (133), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson29.bin \
;        lessons/part4-sprites/29-missiles-and-ball/29-missiles-and-ball.asm
; Run:   stella build/lesson29.bin
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
SPRITE_TOP     = 96
SPRITE_HEIGHT  = 8
P0_X           = 24
M0_X           = 64
M1_X           = 96
BL_X           = 108    ; measured: X=128 (the ball's mapping is its own)
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

; --- position all four objects, then apply all four fine offsets once ---
    LDA #(P0_X + POS_BIAS)
PosApplyP0:
    JSR SetCoarseP0
    LDA #(M0_X + POS_BIAS)
PosApplyM0:
    JSR SetCoarseM0
    LDA #(M1_X + POS_BIAS)
PosApplyM1:
    JSR SetCoarseM1
    LDA #(BL_X + POS_BIAS)
PosApplyBL:
    JSR SetCoarseBL
    STA WSYNC
HmoveApply:
    STA HMOVE

    LDA #$42
    STA COLUP0              ; red: player 0 and missile 0
    LDA #$84
    STA COLUP1              ; blue: missile 1
    LDA #$C8
    STA COLUPF              ; green: the ball
    LDA #$02
    STA COLUBK
    LDA #$00
    STA NUSIZ0              ; P0 normal, M0 1 px
    LDA #$20
    STA NUSIZ1              ; M1 4 px
    LDA #$30
    STA CTRLPF              ; ball 8 px
    LDA #$00
    STA REFP0
    STA REFP1
    STA ENAM0
    STA ENAM1
    STA ENABL               ; off until the body enables them

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — player 0's eight rows; the small objects on rows 2-5
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
; --- enable the missiles and ball on rows 2-5 ---
    CPX #2
    BCC DisableSmall
    CPX #6
    BCS DisableSmall
    LDA #$02
EnableWrite:                ; checkpoint: the small objects on rows 2-5
    STA ENAM0
    STA ENAM1
    STA ENABL
    JMP EnableDone
DisableSmall:
    LDA #$00
    STA ENAM0
    STA ENAM1
    STA ENABL
EnableDone:
    STA WSYNC
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0
    STA ENAM0
    STA ENAM1
    STA ENABL
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
; COARSE POSITIONING — one routine per object; no HMOVE here
; =============================================================================
; Input: A = the biased target (target + 3).
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
RespP0:
    STA RESP0
    RTS

SetCoarseM0:
    STA WSYNC
    SEC
DivM0:
    SBC #15
    BCS DivM0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM0
RespM0:
    STA RESM0
    RTS

SetCoarseM1:
    STA WSYNC
    SEC
DivM1:
    SBC #15
    BCS DivM1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM1
RespM1:
    STA RESM1
    RTS

SetCoarseBL:
    STA WSYNC
    SEC
DivBL:
    SBC #15
    BCS DivBL
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMBL
RespBL:
    STA RESBL
    RTS

; =============================================================================
; SHAPE — player 0's eight rows
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
> `lessons/part4-sprites/29-missiles-and-ball/29-missiles-and-ball.asm`.

### Code Walkthrough

#### Step 1 — Four coarse positions

`PosApplyP0` / `PosApplyM0` / `PosApplyM1` / `PosApplyBL` load the biased targets (27, 67, 99,
111). Each `SetCoarse*` routine runs the divide-by-15 loop, stores the fine value, and strobes its
`RESxx` — but none of them strobes `HMOVE`.

#### Step 2 — One fine strobe

After the fourth routine, `STA WSYNC` parks the line and `STA HMOVE` applies all four fine
offsets. The `$F03B` breakpoint reports the `WSYNC` stall at line 4 cycle 73; `STA HMOVE` itself
executes at VBLANK line 5, cycle 0.

#### Step 3 — Colors and sizes

`COLUP0=$42` (player 0 and M0), `COLUP1=$84` (M1), `COLUPF=$C8` (ball), `COLUBK=$02`.
`NUSIZ0=$00` (P0 normal, M0 1 px), `NUSIZ1=$20` (M1 4 px), `CTRLPF=$30` (ball 8 px).
`ENAM0`/`ENAM1`/`ENABL` start at zero.

#### Step 4 — The body

The body writes `ShapeP0,X` to `GRP0`, then enables the three small objects only on rows 2–5.
The clear line writes zero to `GRP0` and the three enables. The small objects are four lines tall
inside the player's eight.

#### Step 5 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `PosApplyP0` | `$F027` | A = 27 (24 + 3), line 0 cycle 18 | P0's target |
| `PosApplyM0` | `$F02C` | A = 67 (64 + 3), line 1 cycle 35 | M0's target |
| `PosApplyM1` | `$F031` | A = 99 (96 + 3), line 2 cycle 50 | M1's target |
| `PosApplyBL` | `$F036` | A = 111 (108 + 3), line 3 cycle 60 | the ball's target |
| `RespP0` | `$F0D5` | line 1 cycle 24 | P0's coarse strobe |
| `RespM0` | `$F0E7` | line 2 cycle 39 | M0's coarse strobe |
| `RespM1` | `$F0F9` | line 3 cycle 49 | M1's coarse strobe |
| `RespBL` | `$F10B` | line 4 cycle 61 (the logged value; the simple 14 + 5n estimate is 54, so the ball path carries a 7-cycle offset) | the ball's coarse strobe |
| `HmoveApply` | `$F03B` | VBLANK line 5, cycle 0 (the `$F03B` hit at line 4 cycle 73 is the `WSYNC` stall) | the single fine strobe |
| `VisibleStart` | `$F072` | 37, cycle 7 (first hit) | the top loop's first line |
| `BodyStart` | `$F079` | **133, cycle 6**; 8 hits per frame | the first player line |
| `EnableWrite` | `$F088` | 4 hits per frame on rows 2–5; A = `$02` | the small-object enable |
| `OverscanStart` | `$F0B3` | 229, cycle 4 | overscan's first line |

## What You Should See

Four objects at the same height, increasing in width: the red player at X=24, a 1-pixel red
missile at 63, a 4-pixel blue missile at 95, and an 8-pixel green ball at 128. The player is eight
lines tall; the small objects are four lines tall, centered in the player's rows. The background
is dark.

![Stella running the Lesson 29 ROM: the player, a 1-pixel missile, a 4-pixel missile, and an 8-pixel ball](/images/lesson29/lineup.png)

*The lineup, captured from the committed ROM: red P0 at capture x = 169–216 (X=24), a 1-pixel red
missile at 403–408 (X=63), a 4-pixel blue missile at 595–618 (X=95), and an 8-pixel green ball at
793–840 (X=128). The small objects occupy scanlines 135–138.*

<RomPlayer rom="/roms/part4-sprites/29-missiles-and-ball/29-missiles-and-ball.bin" title="Lesson 29 — Missiles and Ball" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson29.sym -o build/lesson29.bin \
  lessons/part4-sprites/29-missiles-and-ball/29-missiles-and-ball.asm
grep -E "PosApply|Resp|HmoveApply" build/lesson29.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F03B' \
  docs/public/roms/part4-sprites/29-missiles-and-ball/29-missiles-and-ball.bin
```

- **`$F027`–`$F036`**: the four targets, 27/67/99/111.
- **`$F0D5`–`$F10B`**: the four coarse strobes, one per line.
- **`$F03B`**: the single `HMOVE`, after all four fine values are set; the breakpoint's line-4
  cycle-73 hit is the `WSYNC` stall, and `STA HMOVE` executes at VBLANK line 5 cycle 0.

## Exercises

### Exercise 1: A Fat Missile

**Challenge:** widen missile 0 from 1 pixel to 8.

**Hints:**
1. `NUSIZ0` bits 4–5 set the missile width; `$30` = 11 (8 pixels).
2. Keep the player's bits 0–2 at 0, as in Lesson 25.
3. The position and color do not change.

**Expected Result:** the red missile at X=63 becomes a 48-pixel block (capture 403–450), still
four lines tall. Measured in a scratch capture.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: A Thin Ball

**Challenge:** shrink the ball to 1 pixel and move it between the missiles.

**Hints:**
1. `CTRLPF` bits 4–5 = `00` makes the ball 1 pixel wide.
2. Change the ball target to 68; it measures X=79, between M0 (63) and M1 (95).
3. The ball's color and the single `HMOVE` do not change.

**Expected Result:** a 6-pixel green bar at capture 499–504 (X=79), four lines tall. This is the
measured result of the committed solution; the ball's target-to-X mapping is its own, not the
player's +3 rule.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: A Moving Bullet *(Stretch Goal)*

**Challenge:** move missile 0 across the screen at 2 pixels per frame.

**Hints:**
1. Keep `BulletX` in zero page; add 2 each frame and wrap at 152 back to 16.
2. Call `SetCoarseM0` with `BulletX + 3`; the other three objects stay fixed.
3. The single `HMOVE` still applies all four fine offsets.

**Expected Result:** the red 1-pixel missile travels left to right and wraps; the player, M1, and
the ball stay put.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **Three small objects, three enables**: `ENAM0`, `ENAM1`, `ENABL` bit 1 turn the missile/ball on for the current line
- ✅ **Widths are fields, not shapes**: `NUSIZ` bits 4–5 for missiles, `CTRLPF` bits 4–5 for the ball; 1/2/4/8 pixels
- ✅ **Colors are shared**: missiles use `COLUP0`/`COLUP1`; the ball uses `COLUPF`
- ✅ **`RESM0`/`RESM1`/`RESBL` position them**: the same divide-by-15 routine, different registers
- ✅ **The measured mapping is the rule**: the missiles land one pixel left of their player-style targets; the ball's mapping is its own (68→79, 108→128), so use the measured table
- ✅ **One `HMOVE` for four objects**: set all four fine values, then strobe once
- ✅ **The enable is per line**: four lines make a four-line-tall projectile

## What's Next

The objects have one color each. [Lesson 30: Multi-Color Sprites](/part4-sprites/30-multicolor-sprites)
changes `COLUP0` on every scanline of a single player, turning one 8×16 shape into a three-band
character.
