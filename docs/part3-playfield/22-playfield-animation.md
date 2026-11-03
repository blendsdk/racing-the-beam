---
title: "Lesson 22: Playfield Animation — Moving Walls"
description: "The playfield registers persist across scanlines, so a change made in VBLANK appears on the whole next frame with no per-line writes. Lesson 22 animates a portcullis through nine gate states with a 30-frame state machine."
prev:
  text: "Lesson 21: Asymmetric Playfield"
  link: "/part3-playfield/21-asymmetric-playfield"
next:
  text: "Lesson 23: Data-Driven Playfield"
  link: "/part3-playfield/23-data-driven-playfield"
---

# Lesson 22: Playfield Animation — Moving Walls

> **Part 3: Playfield** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 16 (horizontal zones), Lesson 19 (the playfield registers and bit order), Lesson 21 (mid-line rewrites for a one-sided variant), Lesson 20 (`CTRLPF`)
> **You will learn:** why a playfield animation can live entirely in VBLANK; how a state byte, a direction byte, and a frame counter make a ping-pong; how a nine-entry gate table maps state to `PF2`; and how to measure an animation with gap widths
> **You will build:** "the portcullis" — a symmetric castle wall whose central gate opens and closes through nine states, one step every half second; plus three exercises: a faster gate, a one-sided gate, and a scrolling wall

## Introduction

Lessons 19–21 set the playfield up once per frame (Lesson 21 rewrote the registers within every line, but repeated the same two patterns frame after frame). This lesson makes the change **continuous** — a gate that opens and closes, forever — and shows why that costs almost nothing.

The key fact is the one Lesson 19 established: the TIA re-reads `PF0`, `PF1`, and `PF2` on every scanline. The registers are not a frame buffer; they are the current picture. If you change `PF2` once in VBLANK, the change applies to **all 192 lines of the next frame**. There is no per-line write, no per-line timing, and no drift. The visible kernel remains the same 192-line hold used in Lessons 19–20. The animation lives in the blanking time, where the frame has thousands of free cycles.

That makes this the simplest animation model in the course so far: a state byte, a direction byte, a frame counter, and a table. The only new discipline is deciding *when* the state changes — and keeping that decision in VBLANK, never mid-picture.

::: details TypeScript Equivalent
A frame-level animation is a reducer plus a lookup table:

```typescript
type GateState = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8;
const GATE = [0xff, 0x7f, 0x3f, 0x1f, 0x0f, 0x07, 0x03, 0x01, 0x00];

let state: GateState = 0;
let dir = 1;
function tick(frame: number) {
  if (frame === 0 || frame % 30 !== 0) return;
  state = (state + dir) as GateState;
  if (state === 8 || state === 0) dir = -dir;
}
const pf2 = GATE[state];    // one write per frame
```

The 2600 version is the same reducer in VBLANK. The display does not interpolate and does not need to: each state is a complete picture, held for thirty frames.
:::

## Theory

### Section 1: One Write, 192 Lines

The playfield registers are read by the TIA for every line. A write in VBLANK changes the value the TIA will read when the visible area begins; every line of that frame sees the new value. This is why the hold kernel works:

```asm
    LDA #$00
    STA VBLANK          ; release the beam
    LDX #192
VisibleStart:
    STA WSYNC
    DEX
    BNE VisibleStart
```

No playfield stores occur in the loop. The picture is the register state, and the loop only keeps the CPU from running ahead of the beam. The same property makes the animation cheap: move the state change into VBLANK, and the whole picture updates at once.

### Section 2: The Portcullis

The wall is `PF0 = $F0` (chunks 0–3) and `PF1 = $FF` (chunks 4–11). The gate is `PF2`, reflected about the center:

| State | `PF2` | Open chunks each side | Gap width | Gap x |
|---|---|---|---|---|
| 0 | `$FF` | 0 | 0 | — |
| 1 | `$7F` | 1 | 2 chunks | 481–528 (48 px) |
| 2 | `$3F` | 2 | 4 chunks | 457–552 (96 px) |
| 3 | `$1F` | 3 | 6 chunks | 433–576 (144 px) |
| 4 | `$0F` | 4 | 8 chunks | 409–600 (192 px) |
| 5 | `$07` | 5 | 10 chunks | 385–624 (240 px) |
| 6 | `$03` | 6 | 12 chunks | 361–648 (288 px) |
| 7 | `$01` | 7 | 14 chunks | 337–672 (336 px) |
| 8 | `$00` | 8 | 16 chunks | 313–696 (384 px) |

`PF2` bit 0 is leftmost, so clearing bits from bit 7 downward opens the gate from the center outward. State *k* opens 2*k* chunks; the gap spans **x = 505 − 24k … 505 + 24k − 1** (inclusive; 48k pixels wide), with transitions at 505 − 24k and 505 + 24k. The fully open state is a 384-pixel gap — nearly half the picture — with the wall's outer 12 chunks still solid on each side.

### Section 3: The State Machine

Three bytes run the animation:

- `GateState` 0–8 — the current gate width;
- `GateDir` `$01` or `$FF` — opening or closing;
- `FrameCounter` 1–30 — the cadence (0 only at the instant of the reset).

Every frame `FrameCounter` increments (stored as 1–30, then reset to 0). On the 30th frame it wraps, the state adds the direction, and the direction reverses at 0 and 8. At ~60 Hz one step is half a second; the sixteen-step open-close cycle is **eight seconds** (four seconds each way). The state changes only in VBLANK; the visible kernel never sees a mid-frame edit.

The state machine is deliberately tiny: `INC`/`CMP`/`BNE` for the timer, `LDA`/`CLC`/`ADC`/`STA` for the state, two `CMP`/`BNE` pairs for the ends, and an indexed table load for `PF2`. It fits in the 37-line VBLANK with room to spare.

### Section 4: The Frame

The frame is the course standard: 3 VSYNC lines, 37 VBLANK lines (`TIM64T` = 44), 192 visible lines, 30 overscan lines (`TIM64T` = 36) = 262 lines. The gate write happens before `+wait_timer`, so it is in place before the release; the hold kernel covers all 192 lines.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson22.bin \
  lessons/part3-playfield/22-playfield-animation/22-playfield-animation.asm
stella build/lesson22.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 22: Playfield Animation — Moving Walls — Racing the Beam
; =============================================================================
; Part 3: Playfield
;
; What this program does:
;   Animates a symmetric portcullis.  The castle wall is solid except for a
;   central gate; every half second the gate opens one step, then closes
;   again.  Nine states take the gate from fully closed to fully open and
;   back.  The wall's shape is constant down the screen; only PF2 changes,
;   and it changes once per frame in VBLANK.
;
; Why the animation is cheap:
;   The playfield registers persist across scanlines — the TIA re-reads them
;   every line.  A change made in VBLANK therefore appears on the whole next
;   frame, with no per-line writes.  The visible kernel just holds 192 lines;
;   the state machine lives in the blanking time, where there are thousands
;   of free cycles.
;
; The gate:
;   PF0 = $F0, PF1 = $FF  -> the wall, solid from chunk 0 to chunk 11.
;   PF2 = GateTable[state] -> the gate, in chunks 12-19 and their mirror.
;
;   PF2 bit 0 is leftmost, so clearing bits from bit 7 downward opens the
;   gate from the center outward.  A cleared bit is a zero, which shows
;   COLUBK (the dark background).
;
;     state  PF2    open chunks (each side mirrors)
;     0      $FF    0        closed
;     1      $7F    1        a 2-chunk gap
;     2      $3F    2        a 4-chunk gap
;     ...
;     8      $00    8        a 16-chunk gap (x = 313-696, 384 px)
;
;   State k opens 2k chunks; the gap spans x = 505 - 24k .. 505 + 24k - 1.
;
; The animation:
;   GateState 0..8, GateDir $01 (up) or $FF (down).  FrameCounter counts to
;   30 (~0.5 s), then the state steps and the direction reverses at 0 and 8.
;   At ~60 Hz the full open-close cycle is 8 seconds (16 steps).
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), GateStep (A = the new state, once per
;   30 frames), PF2Write (A = the table byte), VisibleStart (37),
;   OverscanStart (229).
;
; Build: acme -f plain -o build/lesson22.bin \
;        lessons/part3-playfield/22-playfield-animation/22-playfield-animation.asm
; Run:   stella build/lesson22.bin
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
STEP_FRAMES    = 30     ; ~0.5 s per gate step

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
GateState      = $80    ; 0 (closed) .. 8 (open)
GateDir        = $81    ; $01 = opening, $FF = closing
FrameCounter   = $82    ; counts up to STEP_FRAMES

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM; GateState = 0
    LDA #$01
    STA GateDir             ; start opening

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the gate tick: step the state every STEP_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #STEP_FRAMES
    BNE VblankSetGate
    LDA #$00
    STA FrameCounter
    LDA GateState
    CLC
    ADC GateDir
    STA GateState
GateStep:                   ; debugger checkpoint: A = the new state
    CMP #8
    BNE VblankCheckBottom
    LDA #$FF                ; at the top: start closing
    STA GateDir
    JMP VblankSetGate
VblankCheckBottom:
    CMP #0
    BNE VblankSetGate
    LDA #$01                ; at the bottom: start opening
    STA GateDir

; --- write the frame's wall and gate ---
VblankSetGate:
    LDX GateState
    LDA GateTable,X
    STA PF2
PF2Write:                   ; debugger checkpoint: A = GateTable[state]
    LDA #$F0
    STA PF0                 ; chunks 0-3 on
    LDA #$FF
    STA PF1                 ; chunks 4-11 on
    LDA #$C8
    STA COLUPF              ; green
    LDA #$02
    STA COLUBK              ; dark
    LDA #$01
    STA CTRLPF              ; reflect: the gate mirrors about the center

    LDX #VISIBLE_LINES
    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — the registers are the picture; hold 192 lines
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
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
; GATE TABLE — nine states, closed to fully open
; =============================================================================
GateTable:
    !byte $FF, $7F, $3F, $1F, $0F, $07, $03, $01, $00

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
> `lessons/part3-playfield/22-playfield-animation/22-playfield-animation.asm`.

### Code Walkthrough

#### Step 1 — The gate tick

```asm
    INC FrameCounter
    LDA FrameCounter
    CMP #STEP_FRAMES
    BNE VblankSetGate
    LDA #$00
    STA FrameCounter
    LDA GateState
    CLC
    ADC GateDir
    STA GateState
```

`GateDir` is `$01` or `$FF`; adding it is the whole step. The `CMP #STEP_FRAMES` is the only timing decision in the animation.

#### Step 2 — The end stops

At state 8 the direction flips to `$FF`; at state 0 it flips back to `$01`. The state itself is written before the comparison, so the gate holds the end state for its full 30 frames — the pause at the ends is what makes the motion read as a door rather than a flicker.

#### Step 3 — The table load

```asm
    LDX GateState
    LDA GateTable,X
    STA PF2
```

Nine bytes cover the whole animation. The table is the state machine's output; `PF2` is the only register that changes.

#### Step 4 — The hold

The wall and gate are in place before `+wait_timer`; the release follows, and the 192-line hold paints the frame. The gate does not move inside a frame.

#### Step 5 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F012` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F020` | 0, cycle 5 | VBLANK's first line |
| `GateStep` | `$F03C` | A = the new state; one hit every **30 frames** (state 1 at frame 30, …, 8 at 240, then 7, 6, …) | the state step |
| `PF2Write` | `$F056` | A = `GateTable[state]`; one hit per frame | the gate write |
| `VisibleStart` | `$F077` | 37, cycle 5 | the picture's first line |
| `OverscanStart` | `$F07C` | 229, cycle 4 | overscan's first line |

## What You Should See

A green portcullis on a dark field. The outer wall is solid; the center is closed at first. Every half second the gate opens one step — two chunks, 48 pixels — then holds, then opens again, until the gap is 384 pixels wide. Then it closes in the same steps. The wall's outer edges never move.

![Stella running the Lesson 22 ROM with the gate partly open: a green portcullis with a 48-pixel central gap](/images/lesson22/gate-opening.png)

*Opening state, captured from the committed ROM: a 48-pixel gap (state 1, `PF2=$7F`, x = 481–528). The wall's outer chunks are solid.*

![Stella running the Lesson 22 ROM with the gate fully open: a 384-pixel central gap](/images/lesson22/gate-open.png)

*Fully open state: state 8 (`PF2=$00`), a 384-pixel gap (x = 313–696; transitions at 313 and 697). The gate holds this state for 30 frames before closing.*

<RomPlayer rom="/roms/part3-playfield/22-playfield-animation/22-playfield-animation.bin" title="Lesson 22 — Playfield Animation" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson22.sym -o build/lesson22.bin \
  lessons/part3-playfield/22-playfield-animation/22-playfield-animation.asm
grep -E "GateStep|PF2Write|VisibleStart" build/lesson22.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F03C' \
  docs/public/roms/part3-playfield/22-playfield-animation/22-playfield-animation.bin
```

- **`$F03C` (`GateStep`)**: hits at frames 30, 60, 90, …, A = 1, 2, 3, …, 8, then 7, 6, … — one step per 30 frames, reversing at the ends.
- **`$F056` (`PF2Write`)**: one hit per frame, A = `$FF` while closed, `$7F` at state 1, …, `$00` at state 8. The log's A column is the gate table readout.
- **`$F077` (`VisibleStart`)**: line 37 every frame; the gate state is in place before the picture starts.

## Exercises

### Exercise 1: Faster Gate

**Challenge:** make the gate animation twice as fast.

**Hints:**
1. The cadence is one constant, `STEP_FRAMES`. Change 30 to 15.
2. The nine states, the direction reversal, and the picture stay the same.
3. The full open-close cycle drops from ~8 seconds to ~4 seconds.

**Expected Result:** the same gate sequence, one step every 15 frames. Measured: `GateStep` fires at frames 15, 30, 45, … with the same 1..8..0 sequence; captures show different gate widths at the same clock times as the lesson ROM.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: A One-Sided Gate

**Challenge:** open the gate on the right half only, leaving the left wall closed.

**Hints:**
1. Use repeat mode (`CTRLPF=$00`) and the Lesson 21 mid-line kernel: the left half writes `$F0/$FF/$FF` (closed), the right half writes `GatePF0/$FF/$FF`.
2. The right half's center-adjacent chunks are 20–23, in `PF0`; animate `PF0`, not `PF2`, with a five-entry table `$F0, $E0, $C0, $80, $00`.
3. The `LDA GatePF0` is a zero-page read (3 cycles), so the right-half writes land at hit 36/47/58 instead of 35/46/57 — still inside the windows.

**Expected Result:** the left half solid to the center; the right half solid except for a doorway that opens 0–4 chunks at x = 505–600 (96 px; transitions at 505 and 601). Measured: a capture at a partly open state shows the gap only on the right side of the center (505–576 at state 3), with the left wall unchanged.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: A Scrolling Wall *(Stretch Goal)*

**Challenge:** scroll the wall pattern horizontally, one chunk per step.

**Hints:**
1. Precompute all twenty rotations of a 20-bit crenellated pattern (`PF0=$F0`, `PF1=$CC`, `PF2=$3F` = `11111100110011111100` in on-screen chunk order: `PF0` bit 4 first, `PF1` bit 7 first, `PF2` bit 0 first) and store them as `(PF0, PF1, PF2)` triples. A solid wall would look static when shifted; the notches are what the eye follows.
2. Advance the index every 10 frames (~1/6 s); the offset is `index × 3`; wrap at 20 so the sequence is seamless.
3. The visible kernel is the hold; the table lookup happens in VBLANK. Repeat mode (`CTRLPF=$00`) duplicates the shifted left half, so both halves slide together.

**Expected Result:** the wall appears to slide one chunk (24 pixels) every 10 frames and wraps after twenty steps (~3.3 s) with no jump. Measured: captures ~0.2 s apart show every transition shifted by one chunk (24 pixels).

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **Registers are the picture**: the TIA re-reads `PF0/PF1/PF2` every line, so one VBLANK write updates all 192 lines — no per-line stores, no drift
- ✅ **Animation is a state machine**: a state byte, a direction byte, and a frame counter are enough for a ping-pong; the table maps state to `PF2`
- ✅ **End states need a hold**: reversing at 0 and 8 keeps each end state for its full 30 frames, which reads as a door rather than a flicker
- ✅ **The gate opens from the center**: `PF2` bit 0 is leftmost, so clearing from bit 7 downward opens outward; state *k* gives a 2*k*-chunk gap
- ✅ **One write per frame is enough**: the animation's cost is a handful of VBLANK cycles, not a per-line budget
- ✅ **Measure the state by its gap**: 48 pixels per step (24 per chunk; state 1 = 48, state 8 = 384) makes a capture self-identifying

## What's Next

The gate states are a hand-written table. [Lesson 23: Data-Driven Playfield](/part3-playfield/23-data-driven-playfield) replaces the table with a full level: 192 rows of playfield data, one row per scanline, two levels switched by changing three pointers. The hold kernel gives way to a one-line data kernel — the shape of every maze, text screen, and title card that follows.
