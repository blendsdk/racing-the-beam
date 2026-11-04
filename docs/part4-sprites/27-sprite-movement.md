---
title: "Lesson 27: Sprite Movement — Reading the Joystick"
description: "SWCHA is an active-low input byte. Lesson 27 reads player 0's left/right bits, keeps a signed direction, bounces at the edges, and repositions the sprite every frame with the Lesson 26 routine."
prev:
  text: "Lesson 26: Horizontal Positioning"
  link: "/part4-sprites/26-horizontal-positioning"
next:
  text: "Lesson 28: Two Players"
  link: "/part4-sprites/28-two-players"
---

# Lesson 27: Sprite Movement — Reading the Joystick

> **Part 4: Sprites** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 18 (write positions), Lesson 25 (the sprite and its vertical schedule), Lesson 26 (`SetHorizPos` and the +3 bias)
> **You will learn:** how `SWCHA` reports the joystick (active-low bits); how a signed direction byte moves a sprite; how to bounce at the bounds; why a moving sprite re-strobes every frame; how to keep a ROM self-demonstrating when no controller is connected
> **You will build:** "the patrol" — the invader moving left and right, bouncing at X=16 and X=144, steered by the joystick when one is present; plus three exercises: double speed, edge-to-edge bounds, and vertical movement

## Introduction

Lesson 26 placed the sprite at a new position once per second. This lesson moves it **every
frame**, and hands the direction to the player. The new ingredient is input: the RIOT's `SWCHA`
register at `$0280`.

`SWCHA` is **active-low**: a bit reads 0 when the corresponding switch is pressed, 1 when it is
released. Player 0's joystick uses bits 4 (up), 5 (down), 6 (left), and 7 (right). Reading the
byte and masking the two horizontal bits (6 and 7) gives four cases: right, left, both, neither.

The movement model is small: a `SpriteX` byte, a `Direction` byte (+1, −1, or 0), an add, and a
clamp. When the clamp is hit, the direction flips. `SetHorizPos` then puts the sprite at the new
X. The vertical schedule never changes, so the invader slides along its eight scanlines.

One design choice makes the lesson easy to capture: when neither left nor right is pressed, the
sprite keeps its current direction and patrols on its own. Press the joystick and the same code
follows it; hold both directions and it stops.

::: details TypeScript Equivalent
A position and a velocity, updated once per frame:

```typescript
let x = 80;
let dir = 1;                       // +1 right, -1 left, 0 stop
function step(input: { left: boolean; right: boolean }) {
  if (input.left && !input.right) dir = -1;
  else if (input.right && !input.left) dir = 1;
  else if (input.left && input.right) dir = 0;
  x += dir;
  if (x > 144) { x = 144; dir = -1; }
  if (x < 16)  { x = 16;  dir = 1; }
  return x;
}
```

The 2600 version does the same arithmetic with a byte; the difference is that the result must be
turned into a `RESP0` strobe and a fine-motion value every frame.
:::

## Theory

### Section 1: SWCHA Is Active-Low

`SWCHA` at `$0280` reports both joysticks in one byte:

| Bits | Player | Direction |
|---|---|---|
| 4 | 0 | up |
| 5 | 0 | down |
| 6 | 0 | left |
| 7 | 0 | right |

Reading 0 means **pressed**. Masking with `#$C0` keeps the two horizontal bits:

| `SWCHA & $C0` | Meaning |
|---|---|
| `$C0` | neither left nor right |
| `$80` | left pressed |
| `$40` | right pressed |
| `$00` | both pressed |

`SWACNT` (`$0281`) is the port A direction register. It is written `$00` in `Reset`, which makes
all eight pins inputs. Leave it alone unless you deliberately drive a pin.

### Section 2: A Signed Direction

`Direction` holds `$01` for right, `$FF` for left (two's complement −1), or `$00` for stop. Adding
it to `SpriteX` is the whole movement:

```asm
    LDA SpriteX
    CLC
    ADC Direction
```

The clamp checks both ends. If the sum exceeds 144, the sprite is put back at 144 and the
direction becomes `$FF`; if it is below 16, it is put at 16 and the direction becomes `$01`. The
edge position is therefore held for one extra frame while the direction flips — a small pause that
makes the bounce read clearly.

The `DirWrite` checkpoint sits on the input path's store, so it fires every frame a horizontal
direction is held (never during the no-input patrol). The bounce stores are separate; the
`MoveTick` checkpoint's X sequence is the evidence that they happen.

### Section 3: Position Every Frame

The TIA has no writable X register. `RESP0` latches the beam position and the object keeps that
position until the next strobe — a static sprite can be positioned once. This program re-strobes
**every frame** because `SpriteX` changes every frame, and each new strobe needs its fine offset
re-applied by `HMOVE`; that is exactly what `SetHorizPos` does. The routine costs about two lines;
VBLANK has 37.

Because the call is in VBLANK, the position is stable before line 37. There is no mid-frame jump
and no tearing.

### Section 4: The Auto-Patrol

When `SWCHA & $C0` is `$C0`, the program keeps the current `Direction`. That is why the ROM is
self-demonstrating: with no controller, the invader patrols and bounces forever. With a
controller, the input branches override the direction; when both horizontal switches are held,
`Direction` becomes 0 and the sprite stops. After that stop, the `$C0` path keeps 0, so the sprite
stays still until a single direction is pressed.

The vertical schedule is the Lesson 25 kernel: 80 top lines, 8 body rows, a clear line, 103 bottom
lines. The frame is 262 lines.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson27.bin \
  lessons/part4-sprites/27-sprite-movement/27-sprite-movement.asm
stella build/lesson27.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 27: Sprite Movement — Reading the Joystick — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   The Lesson 25 invader patrols horizontally.  With no joystick input it
;   moves one pixel per frame, bounces at X=16 and X=144, and keeps going.
;   Holding left or right takes over the direction; holding both stops it.
;
; Reading the joystick:
;   SWCHA is at $0280 and is active-low: 0 = pressed.  Player 0 uses bits
;   4 (up), 5 (down), 6 (left), and 7 (right).  This lesson reads bits 6-7:
;
;     SWCHA & $C0   meaning
;     $C0           neither left nor right: keep the current direction
;     $80           left pressed:  direction = -1 ($FF)
;     $40           right pressed: direction = +1
;     $00           both pressed:  direction = 0 (stop)
;
;   SWACNT is set to $00 in Reset so all port A pins are inputs.
;
; Movement:
;   SpriteX is a 0-159 value.  Direction is +1 or -1 (two's complement $FF).
;   Each frame: X += Direction, clamp to 16..144, flip the direction if the
;   clamp was hit, then call SetHorizPos with X + 3 (the routine's output
;   delay bias from Lesson 26).  The sprite stays at the Lesson 25 vertical
;   schedule (visible line 80, eight rows).
;
;   The auto-patrol is deliberate: with no controller the ROM still shows
;   the movement, which makes the captured states unambiguous.  Press the
;   joystick in Stella and the same code follows it.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), MoveTick (A = the new X, every frame),
;   PosApply (A = X + 3), DirWrite (A = the input direction, every frame held),
;   VisibleStart (37), BodyStart (117), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson27.bin \
;        lessons/part4-sprites/27-sprite-movement/27-sprite-movement.asm
; Run:   stella build/lesson27.bin
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
MIN_X          = 16
MAX_X          = 144
START_X        = 80
POS_BIAS       = 3      ; Lesson 26's measured output-delay calibration

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
SpriteX        = $80    ; 0-159, the desired TIA X
Direction      = $81    ; +1, -1 ($FF), or 0

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start
    LDA #START_X
    STA SpriteX
    LDA #$01
    STA Direction           ; start moving right
    LDA #$00
    STA SWACNT              ; all port A pins are inputs

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- read the joystick and choose a direction ---
    LDA SWCHA
    AND #$C0                ; bits 7 (right) and 6 (left)
    CMP #$80
    BEQ DirLeft
    CMP #$40
    BEQ DirRight
    CMP #$00
    BEQ DirStop
    JMP DirDone             ; $C0: neither pressed, keep patrolling
DirRight:
    LDA #$01
    JMP DirStore
DirLeft:
    LDA #$FF
    JMP DirStore
DirStop:
    LDA #$00
DirStore:
DirWrite:                   ; checkpoint: A = the direction, every frame a horizontal input is held
    STA Direction
DirDone:

; --- move, bounce at the bounds ---
    LDA SpriteX
    CLC
    ADC Direction
    CMP #(MAX_X + 1)
    BCC CheckLow
    LDA #MAX_X
    STA SpriteX
    LDA #$FF
    STA Direction           ; bounce left
    JMP MoveDone
CheckLow:
    CMP #MIN_X
    BCS StoreX
    LDA #MIN_X
    STA SpriteX
    LDA #$01
    STA Direction           ; bounce right
    JMP MoveDone
StoreX:
    STA SpriteX
MoveDone:
    LDA SpriteX
MoveTick:                   ; checkpoint: A = the new X, every frame
    CLC
    ADC #POS_BIAS
PosApply:                   ; checkpoint: A = the biased target
    JSR SetHorizPos

    LDA #$42
    STA COLUP0
    LDA #$02
    STA COLUBK
    LDA #$00
    STA NUSIZ0
    STA REFP0

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — the Lesson 25 kernel
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

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SET HORIZONTAL POSITION — the Lesson 26 divide-by-15 routine
; =============================================================================
; Input: A = the biased target (target + 3), 0-162.
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
Resp0Write:
    STA RESP0               ; set the position counter to the beam's clock
    STA WSYNC               ; move to the next line's HBLANK
HmoveApply:
    STA HMOVE               ; apply HMP0 (and the other HM registers)
    RTS

SpriteShape:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %11011011
    !byte %11111111
    !byte %00100100
    !byte %01011010
    !byte %10100101

    * = $FFFA
    !word Reset
    !word Reset
    !word Reset
```

<!-- END-FULL-SOURCE -->

> The complete, fully-commented source lives in
> `lessons/part4-sprites/27-sprite-movement/27-sprite-movement.asm`.

### Code Walkthrough

#### Step 1 — Read the joystick

`LDA SWCHA` / `AND #$C0` isolates the two horizontal bits. The `CMP` chain sends `$80` to
`DirLeft`, `$40` to `DirRight`, `$00` to `DirStop`, and `$C0` straight to `DirDone` (keep the
current direction).

#### Step 2 — Store the direction

`DirRight` loads 1, `DirLeft` loads `$FF`, `DirStop` loads 0, and all three meet at `DirWrite` /
`STA Direction`. The label is the input path's evidence pin: it fires every frame a horizontal
input is held, never during the no-input patrol.

#### Step 3 — Move and clamp

`SpriteX + Direction` is the candidate. `CMP #145` catches the right overshoot, `CMP #16` the
left. The clamp stores the edge value and flips the direction; the normal path stores the sum.

#### Step 4 — Position and draw

`LDA SpriteX` / `CLC` / `ADC #3` / `JSR SetHorizPos` applies the Lesson 26 routine. Then the
colors are set and the Lesson 25 kernel draws the eight rows at visible line 80, the same every
frame.

#### Step 5 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F01B` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F029` | 0, cycle 5 | VBLANK's first line |
| `MoveTick` | `$F07B` | A = the new X, every frame | the movement result |
| `PosApply` | `$F07E` | A = X + 3, every frame | the routine's input |
| `DirWrite` | `$F052` | A = the direction, while a horizontal input is held; **0 hits** with no joystick | the input path |
| `VisibleStart` | `$F09C` | 37, cycle 7 (first hit) | the top loop's first line |
| `BodyStart` | `$F0A3` | **117, cycle 6**; 8 hits per frame | the first sprite line |
| `OverscanStart` | `$F0BC` | 229, cycle 4 | overscan's first line |

## What You Should See

The red invader sliding left and right along the same eight scanlines. With no controller it
patrols on its own: right until X=144, a one-frame pause, then left until X=16, and back. The two
committed captures show it near the two ends: X=26 and X=142 (capture x = 181–228 and 877–924).
The sprite's vertical position never changes.

![Stella running the Lesson 27 ROM with the invader near the left bound](/images/lesson27/patrol-a.png)

*Patrol A, captured from the committed ROM: TIA X = 26 (capture x = 181–228), near the left
bound.*

![Stella running the Lesson 27 ROM with the invader near the right bound](/images/lesson27/patrol-b.png)

*Patrol B: TIA X = 142 (capture x = 877–924), near the right bound. The two captures are 116 TIA
pixels apart, which is 696 capture pixels.*

<RomPlayer rom="/roms/part4-sprites/27-sprite-movement/27-sprite-movement.bin" title="Lesson 27 — Sprite Movement" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson27.sym -o build/lesson27.bin \
  lessons/part4-sprites/27-sprite-movement/27-sprite-movement.asm
grep -E "MoveTick|PosApply|DirWrite" build/lesson27.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F07B' \
  docs/public/roms/part4-sprites/27-sprite-movement/27-sprite-movement.bin
```

- **`$F07B` (`MoveTick`)**: one hit per frame; A steps 81, 82, 83, … while the sprite moves
  right, then decreases after the bounce.
- **`$F07E` (`PosApply`)**: the same value + 3, the argument to `SetHorizPos`.
- **`$F052` (`DirWrite`)**: no hits in the no-input capture; holding a direction fires it every
  frame with A = 1 or `$FF`, and both fires it with A = 0. Scratch witnesses that force the input
  byte to `#$80`/`#$40`/`#$00` confirm left A = `$FF`, right A = `$01`, both A = 0.

## Exercises

### Exercise 1: Double Speed

**Challenge:** move two pixels per frame.

**Hints:**
1. The direction byte is a signed step. Use 2 for right and `$FE` (−2) for left.
2. The bounds and the bounce logic do not change.
3. The sprite crosses the patrol in half the time.

**Expected Result:** the same patrol, with `MoveTick` stepping by 2 and the same X=16/144 bounds.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Edge to Edge

**Challenge:** let the sprite reach X=8 and X=152.

**Hints:**
1. Change `MIN_X` to 8 and `MAX_X` to 152.
2. At X=8 the sprite spans 8–15; at X=152 it spans 152–159.
3. The joystick and the kernel do not change.

**Expected Result:** the patrol covers the full width; the sprite's left edge reaches capture
x=73 and its right edge reaches x=984.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Vertical Movement *(Stretch Goal)*

**Challenge:** use the joystick's up/down bits to move the sprite vertically while it patrols.

**Hints:**
1. Make the top count a variable (`SpriteTop`); the top loop loads it.
2. Compute the bottom count as `192 − SpriteTop − 8 − 1` every frame.
3. `SWCHA & $30`: `$20` is up (decrease `SpriteTop` by 4), `$10` is down (increase by 4); clamp
   40–140.

**Expected Result:** up/down moves the sprite 4 scanlines per frame, and `BodyStart` moves with
it; the horizontal patrol continues. `TopTick` fires while exactly one of up/down is held, with
A = the new or clamped `SpriteTop`.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **`SWCHA` is active-low**: 0 means pressed; player 0's horizontal bits are 6 (left) and 7 (right), with 4 up and 5 down
- ✅ **`SWACNT` = `$00` makes the pins inputs**; write it once in `Reset`
- ✅ **A direction byte is the whole movement**: +1, −1, or 0; add it, clamp, flip at the edges
- ✅ **A moving sprite re-strobes every frame**: `RESP0` latches the beam position, so a new X needs a new strobe in VBLANK with the Lesson 26 bias
- ✅ **The auto-patrol keeps the ROM self-demonstrating**: no input keeps the current direction, so the captures show motion; after a both-pressed stop it stays still
- ✅ **Vertical position is a line count**: the stretch exercise makes the top count a variable and computes the bottom count from it
- ✅ **Input belongs in VBLANK**: the whole update fits in the 37-line blank, never in the visible kernel

## What's Next

One sprite is moving. [Lesson 28: Two Players](/part4-sprites/28-two-players) draws both players on
the same lines, each with its own shape, color, and position — and shows what happens when they
overlap: player 0 has priority over player 1.
