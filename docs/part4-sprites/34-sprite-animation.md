---
title: "Lesson 34: Sprite Animation — Walking Cycles & Character States"
description: "A walk cycle is four 16-row frames, a frame pointer computed in VBLANK, and two counters: one steps the frame every 8 frames, the other flips REFP0 every 120. Lesson 34 animates a red walker from a 64-byte table and shows the leg phases and the mirrored direction."
prev:
  text: "Lesson 33: Paddle & Keyboard Controllers"
  link: "/part4-sprites/33-paddle-keyboard-controllers"
next:
  text: "Lesson 35: Sound Effects"
  link: "/part5-sound/35-sound-effects"
---

# Lesson 34: Sprite Animation — Walking Cycles & Character States

> **Part 4: Sprites** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 17 (cycle counting), Lesson 23 (zero-page pointers and `(zp),Y`), Lesson 26 (`SetHorizPos`), Lesson 30 (per-line sprite writes)
> **You will learn:** how a frame is a 16-byte table; how a frame pointer is computed in VBLANK and read with `(zp),Y`; how a frame counter sets the animation cadence; how `REFP0` mirrors the walk; why the direction flip needs an asymmetric detail to be visible
> **You will build:** "the walk" — a red 16-row walker animated from four frames, stepping every 8 frames and flipping direction every 120 frames; plus three exercises: a half-speed cadence, an idle state, and a walk that moves across the screen

## Introduction

A sprite animation is a table and a pointer. Each **frame** is a complete 16-byte shape. The frame
table holds four of them; the body reads the current frame through a zero-page pointer, one row per
scanline. The pointer changes in VBLANK, so the visible kernel never branches on the frame number.

Two counters drive the animation. One counts to 8 and advances the frame — 7.5 steps per second, a
walking cadence. The other counts to 120 and flips `REFP0`, so the walker faces the other way every
two seconds. The counters are independent: the legs keep walking while the direction changes.

There is one visual trap. The walker's body and legs are left-right symmetric, so a mirror of the
shape would be invisible — the same trap as Lesson 25's mirror exercise. The walker therefore has a
one-pixel **nose** on the head. The nose is the proof that `REFP0` did something.

::: details TypeScript Equivalent
A frame table, an index, and a pointer:

```typescript
const frames = [frame0, frame1, frame2, frame3];   // each 16 rows
let index = 0;
let animCounter = 0;
let flipCounter = 0;
let flipState = 0;

function vblank() {
  if (++animCounter === 8) { animCounter = 0; index = (index + 1) % 4; }
  if (++flipCounter === 120) { flipCounter = 0; flipState ^= 8; }
  return { ptr: frames[index], reflect: flipState !== 0 };
}

function drawLine(row: number) {
  return { grp0: frameRow(row), refp0: flipState };  // the pointer picks the row
}
```

The 2600 version computes the pointer as `base + index * 16` with four `ASL`s, then reads
`(FramePtr),Y`. The analogy hides the cycle cost: the indirect read is 5 cycles, or 6 when it
crosses a page.
:::

## Theory

### Section 1: A Frame Is 16 Rows

The walker is 8 pixels wide and 16 scanlines tall. A frame is 16 bytes; the four frames are 64
bytes. Rows 0–11 are the same upper body in every frame; rows 12–15 are the legs, and they are the
only bytes that differ. That is the whole animation: four leg patterns under one body.

| Frame | Legs (rows 12–15) | Pose |
|---|---|---|
| 0 | `$66 $66 $66 $C3` | legs apart |
| 1 | `$24 $24 $24 $42` | passing, feet close |
| 2 | `$66 $66 $24 $42` | legs closing |
| 3 | `$24 $24 $66 $C3` | passing, feet apart |

The pose names are mnemonic; the bytes are the authority. Every leg byte is a bit-reversal
palindrome, so a left/right stance cannot be read from the shape.

Every frame also has the nose: row 2 is `$3E` (`00111110`), one pixel to the right of the head.
Reversed, it is `$7C` (`01111100`), one pixel to the left. The nose is what makes the direction
flip visible.

### Section 2: The Frame Pointer

`FramePtr = FrameTable + FrameIndex × 16`. The index is 0–3, so multiplying by 16 is four `ASL`s.
The low byte and the high byte are computed separately:

```asm
    LDA FrameIndex
    ASL
    ASL
    ASL
    ASL
    CLC
    ADC #<FrameTable
    STA FramePtr
    LDA #>FrameTable
    ADC #$00
    STA FramePtr+1
```

The `ADC #$00` carries the overflow from the low byte; frame 3's base is `$F100`, so its high byte
is `$F1`. The body then reads `(FramePtr),Y` with `Y = 0..15`. The indirect read is 5 cycles, or 6
when the 16-byte frame crosses a page. All four frames are 16-byte aligned here, so the body is
**18 cycles** (19 only on a page-crossing read, which this layout avoids).

### Section 3: The Cadence

`AnimCounter` counts 0–7 and wraps when the increment reaches 8; `FrameIndex` then advances,
wrapping at 4. At 60 frames per
second, 8 frames per step is 7.5 steps per second — a brisk walk. The cadence is a **frame counter**,
not a RIOT timer: it advances with the picture, so the animation stays in step even if the program
does more or less work in VBLANK.

The animation is independent of the sprite's position. A moving walker keeps the same cadence; the
stretch exercise combines the two.

### Section 4: The Direction Flip

`FlipCounter` counts 0–119 and wraps at 120; `FlipState` then toggles between 0 and 8. `FlipState` is
written to `REFP0`, so the player is mirrored for the next two seconds. The flip is a **latch**, not
a second animation: the legs keep their cadence, and the whole shape — body, legs, nose — mirrors.

The nose is essential. Every other byte of the walker is a bit-reversal palindrome (`$18`, `$3C`,
`$7E`, `$FF`, `$66`, `$24`, `$42`, `$C3`), so without the nose the mirror would be pixel-identical
and the direction flip would look like a bug. This is the same lesson as Lesson 25's mirror exercise,
applied to animation.

### Section 5: The Frame

The frame is 3 + 37 + 192 + 30 = 262. The walker starts at visible line 80 (scanline 117): 80 top
lines, 16 body rows, one clear line, and 95 bottom lines = 192. The sprite is at X=72, so its pixels
begin at color clock 140 (capture x = 457).

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson34.bin \
  lessons/part4-sprites/34-sprite-animation/34-sprite-animation.asm
stella build/lesson34.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 34: Sprite Animation — Walking Cycles & Character States — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Animates a 16-row walker from a four-frame table.  The body reads the
;   current frame through a zero-page pointer; the frame advances every 8
;   frames (7.5 Hz), and REFP0 flips every 120 frames so the walker faces
;   the other way.
;
; The frame table:
;   Four frames, 16 bytes each, 64 bytes total.  Rows 0-11 are the same
;   upper body in every frame; rows 12-15 are the legs, and they are the
;   only bytes that differ.  The table is the animation; the body is the
;   player.
;
; The frame pointer:
;   FramePtr = FrameTable + FrameIndex * 16.  The index is 0-3, so four
;   ASLs multiply it by 16; the low byte and the high byte are computed in
;   VBLANK.  The body reads (FramePtr),Y with Y = 0..15.  The (zp),Y read
;   is 5 cycles, or 6 when it crosses a page; all four frames are 16-byte
;   aligned here, so the body is 18 cycles (19 only if a frame crosses a page).
;
; Timing:
;   AnimCounter counts 0-7 and advances the frame index when the increment
;   reaches 8; the index wraps at 4.  FlipCounter counts to 120 and toggles FlipState between 0 and 8,
;   which is written to REFP0.  The animation and the direction are two
;   independent counters; neither uses the RIOT timer.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; The walker starts at visible line 80 (scanline 117): 80 top + 16 body +
; 1 clear + 95 bottom = 192.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), AnimStep (A = the new 0-3 index, one
;   hit every 8 frames), FramePtrWrite (A = the frame base low byte),
;   FlipWrite (A = 0/8, one hit every 120 frames), VisibleStart (37),
;   BodyStart (117, 16 hits), SpriteWrite (A = the row byte), OverscanStart
;   (229).
;
; Build: acme -f plain -o build/lesson34.bin \
;        lessons/part4-sprites/34-sprite-animation/34-sprite-animation.asm
; Run:   stella build/lesson34.bin
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
SPRITE_HEIGHT  = 16
SPRITE_X       = 72
POS_BIAS       = 3
ANIM_RATE      = 8      ; frames per walk step (7.5 Hz)
FLIP_RATE      = 120    ; frames per direction flip (2 s)

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameIndex     = $80    ; 0-3, the current walk frame
AnimCounter    = $81    ; 0-7, the frame cadence
FlipCounter    = $82    ; 0-119, the direction cadence
FlipState      = $83    ; 0 or 8, written to REFP0
FramePtr       = $84    ; two-byte pointer to the current 16-row frame

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA FrameIndex
    STA AnimCounter
    STA FlipCounter
    STA FlipState

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- advance the walk frame every 8 frames ---
    INC AnimCounter
    LDA AnimCounter
    CMP #ANIM_RATE
    BNE NoAnimStep
    LDA #$00
    STA AnimCounter
    INC FrameIndex
    LDA FrameIndex
    AND #$03
AnimStep:                   ; checkpoint: A = the new 0-3 index
    STA FrameIndex
NoAnimStep:

; --- flip the direction every 120 frames ---
    INC FlipCounter
    LDA FlipCounter
    CMP #FLIP_RATE
    BNE NoFlip
    LDA #$00
    STA FlipCounter
    LDA FlipState
    EOR #$08
    STA FlipState
FlipWrite:                  ; checkpoint: A = 0/8, every 120 frames
    STA REFP0
NoFlip:

; --- FramePtr = FrameTable + FrameIndex * 16 ---
    LDA FrameIndex
    ASL
    ASL
    ASL
    ASL
    CLC
    ADC #<FrameTable
FramePtrWrite:              ; checkpoint: A = the frame base low byte
    STA FramePtr
    LDA #>FrameTable
    ADC #$00
    STA FramePtr+1

; --- position, colors ---
    LDA #(SPRITE_X + POS_BIAS)
    JSR SetHorizPos
    LDA #$42
    STA COLUP0              ; red
    LDA #$02
    STA COLUBK              ; dark neutral
    LDA #$00
    STA NUSIZ0
    STA REFP1

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — the pointer walks the 16-row frame
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK
    LDX #SPRITE_TOP
VisibleStart:
TopLoop:
    STA WSYNC
    DEX
    BNE TopLoop

    LDY #0
BodyStart:
BodyLoop:
    LDA (FramePtr),Y
SpriteWrite:                ; checkpoint: A = this row's shape
    STA GRP0
    STA WSYNC
    INY
    CPY #SPRITE_HEIGHT
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
; SET HORIZONTAL POSITION — the Lesson 26 routine, with the +3 bias
; =============================================================================
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

; =============================================================================
; WALK FRAMES — 4 x 16 rows; rows 0-11 are shared, rows 12-15 are the legs
; =============================================================================
FrameTable:
; --- frame 0: legs apart ---
    !byte %00011000         ; row 0  (head)
    !byte %00111100         ; 1
    !byte %00111110         ; 2  (right-facing nose)
    !byte %00011000         ; 3
    !byte %01111110         ; 4  (arms)
    !byte %11111111         ; 5
    !byte %11111111         ; 6
    !byte %01111110         ; 7
    !byte %00111100         ; 8  (body)
    !byte %00111100         ; 9
    !byte %00111100         ; 10
    !byte %00111100         ; 11
    !byte %01100110         ; 12 (legs)
    !byte %01100110         ; 13
    !byte %01100110         ; 14
    !byte %11000011         ; 15
; --- frame 1: passing pose ---
    !byte %00011000
    !byte %00111100
    !byte %00111110         ; right-facing nose
    !byte %00011000
    !byte %01111110
    !byte %11111111
    !byte %11111111
    !byte %01111110
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00100100
    !byte %00100100
    !byte %00100100
    !byte %01000010
; --- frame 2: legs closing ---
    !byte %00011000
    !byte %00111100
    !byte %00111110         ; right-facing nose
    !byte %00011000
    !byte %01111110
    !byte %11111111
    !byte %11111111
    !byte %01111110
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %01100110
    !byte %01100110
    !byte %00100100
    !byte %01000010
; --- frame 3: passing pose, feet apart ---
    !byte %00011000
    !byte %00111100
    !byte %00111110         ; right-facing nose
    !byte %00011000
    !byte %01111110
    !byte %11111111
    !byte %11111111
    !byte %01111110
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00100100
    !byte %00100100
    !byte %01100110
    !byte %11000011

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
> `lessons/part4-sprites/34-sprite-animation/34-sprite-animation.asm`.

### Code Walkthrough

#### Step 1 — The cadence

`INC AnimCounter` / `CMP #8` / `BNE NoAnimStep`; on the eighth frame the counter resets, `FrameIndex`
increments, and `AND #$03` wraps it. `AnimStep` sits on the store, so the log shows one hit every
8 frames with A = the new index.

#### Step 2 — The direction

`FlipCounter` counts to 120; on the wrap, `FlipState` is XORed with 8 and written to `REFP0`.
`FlipWrite` marks the store, so the log shows A = 8 at frame 120, 0 at 240, and so on.

#### Step 3 — The pointer

Four `ASL`s multiply the index by 16; `ADC #<FrameTable` gives the low byte, and `LDA #>FrameTable`
/ `ADC #$00` gives the high byte. `FramePtrWrite` marks the low-byte store: A runs `$D0`, `$E0`,
`$F0`, `$00` for frames 0–3.

#### Step 4 — The body

`LDY #0` and `LDA (FramePtr),Y` read one row; `STA GRP0` draws it; `STA WSYNC` parks; `INY` / `CPY
#16` repeat. The body does not know which frame it is drawing — the pointer already chose it.

#### Step 5 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F018` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F026` | 0, cycle 5 | VBLANK's first line |
| `AnimStep` | `$F041` | A = 1/2/3/0 at frames **8/16/24/32** | the frame advance |
| `FlipWrite` | `$F055` | A = `$08` at frame 120, `$00` at 240, `$08` at 360 | the direction latch |
| `FramePtrWrite` | `$F060` | A = `$D0/$E0/$F0/$00` for frames 0–3 | the frame base low byte |
| `VisibleStart` | `$F088` | 37, cycle 7 (first hit) | the top loop's first line |
| `BodyStart` | `$F08F` | **117, cycle 6**; 16 hits per frame | the first body row |
| `SpriteWrite` | `$F091` | 16 hits; A = the row byte | the `GRP0` store |
| `OverscanStart` | `$F0A7` | 229, cycle 4 | overscan's first line |
| `Resp0Write` | `$F0C9` | VBLANK line 2, cycle 44 | the coarse strobe |
| `HmoveApply` | `$F0CD` | VBLANK line 2, cycle 50 (the `WSYNC` stall); `STA HMOVE` executes on line 3 cycle 0 | the fine strobe |

## What You Should See

One red 16-row walker at capture x = 457–504 and y = 359–408. The first committed capture shows
frame 0: the legs are `$66 $66 $66 $C3`, the nose on the **right** of the head. The second shows
frame 3 after the first direction flip: the legs are `$24 $24 $66 $C3`, and the nose is on the
**left** — `REFP0` mirrored the whole shape.

![Stella running the Lesson 34 ROM: the walker in frame 0, facing right](/images/lesson34/walk-a.png)

*Walk A, captured from the committed ROM at about 0.6 s: frame 0, wide stance, nose right.*

![Stella running the Lesson 34 ROM: the same walker after the direction flip](/images/lesson34/walk-b.png)

*Walk B, captured at about 3.0 s: frame 3, the legs have changed, and `REFP0` has mirrored the
walker — the nose is on the left. The two captures are the same X and Y; only the frame and the
direction differ.*

<RomPlayer rom="/roms/part4-sprites/34-sprite-animation/34-sprite-animation.bin" title="Lesson 34 — Sprite Animation" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson34.sym -o build/lesson34.bin \
  lessons/part4-sprites/34-sprite-animation/34-sprite-animation.asm
grep -E "AnimStep|FramePtrWrite|FlipWrite|BodyStart" build/lesson34.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F041' \
  docs/public/roms/part4-sprites/34-sprite-animation/34-sprite-animation.bin
```

- **`$F041` (`AnimStep`)**: frames 8, 16, 24, 32 with A = 1, 2, 3, 0. One hit every 8 frames.
- **`$F060` (`FramePtrWrite`)**: A = `$D0`, `$E0`, `$F0`, `$00` — the four frame bases at `$F0D0`,
  `$F0E0`, `$F0F0`, and `$F100`.
- **`$F055` (`FlipWrite`)**: frames 120, 240, 360 with A = 8, 0, 8.
- **`$F08F` (`BodyStart`)**: line 117, 16 hits.

## Exercises

### Exercise 1: Half-Speed Walk

**Challenge:** make the walk step every 16 frames instead of 8.

**Hints:**
1. `ANIM_RATE` is the only constant: change 8 to 16.
2. The frame table, the pointer, and the direction flip do not change.
3. The cadence becomes 3.75 steps per second.

**Expected Result:** the same four frames at half speed. Measured captures show frame 0 (legs
`$66…`) and frame 1 (legs `$24…`), where the main ROM's two captures show frames 0 and 3. The
capture times are wall-clock and include the emulator's startup; the measured frame is the
authority.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: The Idle State

**Challenge:** every 120 walk frames, hold a neutral pose for 60 frames.

**Hints:**
1. Add a fifth frame, `FrameIdle`, with the legs together (`$3C $3C $3C $3C`).
2. `WalkTimer` counts walking frames; at 120, load `IdleTimer` with 60 and point `FramePtr` at
   `FrameIdle`.
3. While `IdleTimer` is nonzero, decrement it and keep the idle pointer; when it reaches 0, resume
   the walk. This is a two-state machine: walk and idle.

**Expected Result:** the walker walks for two seconds, stands still for one second, and resumes.
Measured at ~1.5 s: a walk frame; at ~2.5 s: the idle pose with the legs together (`$3C` rows) and
the nose left after the flip.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Walk and Move *(Stretch Goal)*

**Challenge:** combine the walk cycle with horizontal movement at 1 pixel per frame.

**Hints:**
1. Add `SpriteX` (start 16) and `Direction` (+1); move, then bounce at 16/144.
2. Use `SpriteX + 3` in `SetHorizPos`, exactly as Lesson 27 did.
3. Set `REFP0` from the direction: 0 when moving right, 8 when moving left. Delete the 120-frame
   `FlipCounter`/`FlipState` flip — `Direction` is now the only writer of `REFP0`.

**Expected Result:** the figure crosses the screen at 1 px per frame and bounces at the edges; the
nose faces the direction of travel. Measured captures show X=52 (nose right, moving right) and
X=116 (after the bounce, nose left, moving left); `FaceWrite` logs A=0 while moving right and A=8
while moving left. As elsewhere, the capture times are wall-clock; the measured frame and X are
the authority.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A frame is a table**: 16 bytes for a 16-row sprite; four frames are 64 bytes, and only the leg rows differ
- ✅ **The pointer is the animation state**: `base + index × 16`, computed in VBLANK; the body reads `(FramePtr),Y`
- ✅ **The body is 18 cycles here**: the indirect read is 5 cycles; a page-crossing frame would add one
- ✅ **Cadence is a frame counter**: 8 frames per step is 7.5 Hz; no RIOT timer is involved
- ✅ **The direction is a second counter**: 120 frames per flip, written to `REFP0`
- ✅ **Mirroring needs an asymmetric detail**: without the nose, the entire walker is a palindrome and the flip is invisible
- ✅ **Animation and movement are independent**: the stretch exercise moves the same walker without touching the frame table
- ✅ **The frame is unchanged**: 80 top + 16 body + 1 clear + 95 bottom = 192

## What's Next

Part 4 ends here: the TIA's objects, their positioning, their colors, their copies and sizes, their
input devices, and now their animation. [Lesson 35: Sound Effects](/part5-sound/35-sound-effects)
opens Part 5 with the other half of the TIA — the two audio channels: tone, noise, volume, and the
first beeps of a game.
