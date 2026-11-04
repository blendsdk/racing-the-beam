---
title: "Lesson 33: Paddle & Keyboard Controllers"
description: "The paddle is an RC timer read through INPT0, the keypad is a driven 4x3 matrix on SWCHA, and the fire button is INPT4's top bit. Lesson 33 builds a controller monitor: a needle positioned by the paddle charge count, eight raw-port columns from the playfield, a fire block that changes color, and the keypad scan explained."
prev:
  text: "Lesson 32: Vertical Delay"
  link: "/part4-sprites/32-vertical-delay"
next:
  text: "Lesson 34: Sprite Animation"
  link: "/part4-sprites/34-sprite-animation"
---

# Lesson 33: Paddle & Keyboard Controllers

> **Part 4: Sprites** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 15 (the RIOT timer), Lesson 19 (`PF1` and `CTRLPF`'s reflect bit), Lesson 20 (playfield priority), Lesson 27 (`SWCHA` and active-low input), Lesson 28 (the one-`HMOVE` rule). `INPT4` is introduced in Section 4 below.
> **You will learn:** how a paddle's RC circuit is read with `VBLANK` and `INPT0`; why the read loop must be bounded; how the keypad's 4×3 matrix is scanned (its rows must be driven); how the raw `SWCHA` port reads switches to ground; how `INPT4` reports the fire button; how to build a monitor that shows the inputs at once
> **You will build:** "the controller monitor" — a paddle-driven needle, eight raw-port columns built from the playfield, and a fire block that turns from green to red; plus three exercises: paddle 1, a wide gold fire block, and two independent needles

## Introduction

The joystick is a set of switches. The paddle is not: it is a **variable resistor** in an RC circuit,
and the TIA measures how long the capacitor takes to charge. The keyboard controller is a 4×3
matrix on the same port, but unlike the joystick its rows must be driven before its columns can be
read. The fire button is one more switch. Three different input devices, three different read
techniques.

This lesson builds a monitor for the paddle, the raw port, and the fire button — and explains the
keypad scan that the port is designed for. Paddle 0's charge time positions a red needle. The eight
`SWCHA` bits light eight green columns made from the playfield. The fire button changes a small
block from green to red.

The monitor is designed to be honest about missing hardware. A real paddle's count varies with the
potentiometer; with no paddle attached, the read **times out** and the needle parks at its minimum.
The ROM never hangs, and the capture of the unplugged state is unambiguous.

::: details TypeScript Equivalent
A paddle read is a timeout-bounded measurement, and the monitor is just arithmetic on the result:

```typescript
function readPaddle(): number {
  discharge();                    // VBLANK bit 7 = 1
  startCharge();                  // clear VBLANK bit 7
  for (let count = 0; count < 128; count++) {
    if (inputBitHigh()) return count;   // 0..127
  }
  return 0;                       // gave up: no paddle or beyond the bound
}

const needleX = Math.min(151, readPaddle() + 24);
const rawPort = ~swcha & 0xff;    // closed switches become 1s
const fire    = (inpt4 & 0x80) === 0;

// A keypad scan drives one row, waits, then reads three columns:
function scanKeypadRow(row: number): number {
  vblank &= ~0xc0;                        // bits 6-7 clear for the scan
  swacnt = 0xff;                          // rows are outputs
  swcha = 0xff & ~(1 << (4 + row));       // pull one row low
  delayMicroseconds(400);
  const keys = ((inpt0 & 0x80) === 0 ? 1 : 0)
             | ((inpt1 & 0x80) === 0 ? 2 : 0)
             | ((inpt4 & 0x80) === 0 ? 4 : 0);
  swacnt = 0x00;                          // restore inputs
  return keys;
}
```

The 2600 version does the same measurement in a counted loop; the difference is that the loop's
iteration count *is* the time, so the CPU cycle budget is part of the design. The keypad scan is a
separate job: it drives the port and reads a different set of inputs.
:::

## Theory

### Section 1: The Paddle Is an RC Timer

`INPT0`–`INPT3` are not ordinary switch bits. Each paddle is a potentiometer connected to a
capacitor, and the TIA charges that capacitor through the potentiometer's resistance. The higher the
resistance, the longer the charge takes.

The read sequence has three steps:

1. **Discharge.** Set `VBLANK` bit 7 (`$80`). The capacitor drains.
2. **Start the charge.** Clear bit 7 to release the ground; the standard recipe also sets bit 6
   (`$40`) to latch the fire buttons. The capacitor starts charging when bit 7 clears.
3. **Count until ready.** Poll `INPT0`; bit 7 goes to 1 when the capacitor crosses the threshold.

The count is the measurement. It is not a calibrated position; it is a time in loop iterations. The
monitor maps it to a needle position with `X = count + 24`, which puts count 0 at X=24 and count 127
at X=151.

A paddle with a large resistance produces a large count; a paddle at minimum produces a small one.
That is why the count must be bounded: a missing or broken paddle can make the input never go high.

The 128-iteration bound is about 1.3 ms of charge time. A real CX30 paddle's travel spans roughly
0–24 ms (0–380 scanlines; the 2k6specs POT timing table gives that range): only the low-resistance
end fits the bound, while mid-travel is around 12 ms. With a real paddle, most of the knob's travel therefore reads 0 (the timeout) and the needle
sits at the left. The monitor is a teaching harness for the read sequence and for the
emulator/no-controller case. A game that needs the full range counts across frames (or continues
the read during overscan) and keeps a 16-bit count; the lesson notes the limit rather than hiding
it.

### Section 2: The Bounded Read

The loop must end even if the input never does. The program counts in Y and stops at `CPY #128`:

```asm
    LDA #$82            ; discharge + blank
    STA VBLANK
    LDX #50
PadDischarge:
    DEX
    BNE PadDischarge
    LDA #$42            ; start the charge + blank
    STA VBLANK
    LDY #0
PadWait:
    LDA INPT0
    BMI PadReady        ; bit 7 = 1: charged
    INY
    CPY #128
    BNE PadWait
    LDY #0              ; timeout: no paddle or resistance beyond the bound
PadReady:
    STY PaddleValue
```

At 12 cycles per iteration (`LDA INPT0` is a zero-page read: 3 + 2 + 2 + 2 + 3), 128 reads cost
about 1,536 cycles, or 20 scanlines. Add the discharge loop (249 cycles, about 3.3 lines) and the
setup, and the worst case is still inside the 37-line VBLANK. A 255-iteration read would not fit. The bound is a frame-budget decision, not an arbitrary
safety limit. The last storable count is 127; 128 is the bound that gives up.

A timeout stores 0. The monitor documents that as "no paddle, or a resistance beyond the
single-frame bound" — the two cases are indistinguishable from the outside, and the lesson says so
rather than pretending otherwise.

### Section 3: The Raw Port and the Keypad Scan

`SWCHA` at `$0280` is an 8-bit port. With `SWACNT=$00` every pin is an input, and each bit is
**active-low**: 0 means the switch is closed to ground. Player 0 uses bits 4–7; player 1 uses bits
0–3. A joystick direction and a driving controller's switch both work this way.

The monitor writes the inverted byte to `PF1`:

```asm
    LDA SWCHA
    EOR #$FF
    STA PF1
```

An unpressed port reads `$FF`, so `PF1` becomes 0 and no columns light. A closed switch becomes a 1
in the playfield and lights a column. `PF1` is the playfield's middle third: with `CTRLPF` bit 0
set, the columns are mirrored on the right half. The eight columns occupy playfield chunks 4–11,
which is capture x = 121–312 on the left, plus the mirror image on the right.

**The keypad is a driven matrix.** A CX50 keyboard controller has 12 keys in 4 rows × 3 columns.
Its rows are not switches to ground: the program must drive them. The scan is:

1. `SWACNT=$FF` — make all port A pins outputs.
2. Write `$FF` to `SWCHA`, then clear one of bits 4–7; that row is selected.
3. Wait about 400 µs for the matrix to settle. Do this with `VBLANK` bits 6–7 clear: bit 7 grounds
   the analog columns (every key would read pressed), and bit 6 latches `INPT4`, the right column.
4. Read the three column inputs: `INPT0` (left), `INPT1` (middle), `INPT4` (right); bit 7 = 0
   means pressed.
5. Repeat for the four rows (select bits 4, 5, 6, 7).
6. Restore `SWACNT=$00` before reading the joystick or the paddles again; otherwise the driven row
   fights any switch to ground.

A full scan costs four 400 µs waits — about 25 scanlines — so it does not fit in the same VBLANK as
the paddle read. A real monitor scans one row per frame, or scans during overscan. This lesson's
monitor does not drive the port: `SWACNT` stays `$00`, so its eight columns show the raw switch
state (a joystick direction, for example). A CX50 key alone does not pull a line low until the
program selects its row. The recipe above is the bridge from this monitor to a keyboard-driven
game.

The driving controller is a different device on the same port: it reports a two-bit Gray code on
two of the joystick-direction bits (`SWCHA` bits 4–5 for player 0). Decoding it means comparing the
pair with the previous pair and counting transitions. This lesson names the technique but does not
implement it.

### Section 4: The Fire Button

`INPT4` is player 0's fire button. Only bit 7 is a switch: it is **active-low**, 0 when pressed.
Test the bit explicitly and never treat "nonzero" as pressed. The monitor reads it and chooses the
fire block's color:

```asm
    LDA INPT4
    AND #$80
    BNE FireOff
    LDA #$42            ; pressed: red
    BNE FireStore
FireOff:
    LDA #$C8            ; released: green
FireStore:
    STA COLUP1
```

`COLUP1` is also player 1's color, so the block is green when released and red when pressed. The
needle uses `COLUP0` red; the raw-port columns use `COLUPF` green. Because the read sets `VBLANK` bit 6, the
fire input is latched: a press between the latch enable and the read is remembered, so the block
shows the frame's fire state even if the button is released before the read.

### Section 5: The Monitor Layout

The monitor has three visual parts:

| Part | Object | Position | Color |
|---|---|---|---|
| Needle | Player 0, 32 rows | X = count + 24 (24–151) | `$42` red |
| Fire block | Player 1, 8 rows | X=140 | `$C8` green / `$42` red |
| Raw-port columns | Playfield `PF1` | chunks 4–11, reflected | `$C8` green |

The needle and the fire block start at visible line 80 (scanline 117). The needle is 32 rows tall;
the fire block is 8 rows tall, drawn only on the first eight body rows. The frame is the course
standard: 3 + 37 + 192 + 30 = 262; the vertical budget is 80 top + 32 body + 1 clear + 79 bottom =
192.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson33.bin \
  lessons/part4-sprites/33-paddle-keyboard-controllers/33-paddle-keyboard-controllers.asm
stella build/lesson33.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 33: Paddle & Keyboard Controllers — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   A controller monitor.  Paddle 0's charge time positions a red needle;
;   the eight SWCHA bits light eight green playfield columns; the fire
;   button turns a green block red.  With no controller, the paddle read
;   times out, the needle sits at X=24, the columns are dark, and the fire
;   block is green.
;
; Reading a paddle (INPT0-INPT3):
;   The paddle is an RC circuit.  VBLANK bit 7 discharges it; clearing bit 7
;   starts the charge, and the input bit goes high when the capacitor crosses
;   the threshold.  (Bit 6 latches the fire buttons.)  The loop counts until
;   that happens.
;
;   The loop is bounded at 128 iterations (CPY #128) so a missing paddle
;   cannot hang the ROM and the read fits the 37-line VBLANK.  A timeout
;   stores 0, meaning no paddle or a resistance beyond the single-frame
;   bound.  The raw count is not calibrated; the monitor maps it to needle
;   X = count + 24 (24-151).
;
; Reading the raw matrix (SWCHA):
;   With SWACNT=$00 the port is all inputs, so a switch to ground (a joystick
;   direction, or a driving controller's switch) reads 0.  PF1 is loaded with
;   the inverted byte, so a closed switch lights one of the eight columns in
;   chunks 4-11 (reflected on the right half).
;
;   A CX50 keyboard controller is a driven 4x3 matrix: the program must set
;   SWACNT=$FF, pull one of the row lines (bits 4-7) low, wait ~400us, and
;   read the three column bits (INPT0/INPT1/INPT4, 0=pressed).  This monitor
;   shows the raw port; the doc explains the keypad scan, which is the next
;   step.  The driving controller is a name-only aside (two Gray-code bits).
;
; Reading fire (INPT4):
;   Bit 7 is 0 when pressed.  The block's COLUP1 is green when released and
;   red when pressed.
;
; The frame is the course standard: 3 + 37 + 192 + 30 = 262 lines.
; The needle and the fire block start at visible line 80 (scanline 117):
; 80 top + 32 body + 1 clear + 79 bottom = 192.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), PaddleRead (A = the count, 0-127),
;   PaddleX (A = the needle X), KeyWrite (A = the inverted SWCHA byte),
;   FireWrite (A = COLUP1), PosApply0/1, HmoveApply, VisibleStart (37),
;   BodyStart (117, 32 hits), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson33.bin \
;        lessons/part4-sprites/33-paddle-keyboard-controllers/33-paddle-keyboard-controllers.asm
; Run:   stella build/lesson33.bin
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
NEEDLE_HEIGHT  = 32
FIRE_HEIGHT    = 8
FIRE_X         = 140
POS_BIAS       = 3
PADDLE_MAX     = 128

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
PaddleValue    = $80    ; 0-127, the raw charge count (0 on timeout)
NeedleX        = $81    ; 24-151, the needle position

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    ; SWACNT resets to $00 (all port A pins inputs); no write is needed.

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- paddle 0: discharge, charge, count until ready or 128 ---
    LDA #$82                ; bit 7 = discharge, bit 1 = blank
    STA VBLANK
    LDX #50
PadDischarge:
    DEX
    BNE PadDischarge
    LDA #$42                ; bit 6 = fire latch, bit 1 = blank; bit 7 cleared = charge
    STA VBLANK
    LDY #0
PadWait:
    LDA INPT0
    BMI PadReady            ; bit 7 = 1: the capacitor is charged
    INY
    CPY #PADDLE_MAX
    BNE PadWait
    LDY #0                  ; timeout: no paddle or resistance beyond the bound
PadReady:
    STY PaddleValue
    LDA PaddleValue
PaddleRead:                 ; checkpoint: A = the count, 0-127
    CLC
    ADC #24
PaddleX:                    ; checkpoint: A = the needle X
    STA NeedleX

; --- the raw-port columns: PF1 = the inverted SWCHA byte ---
    LDA SWCHA
    EOR #$FF
KeyWrite:                   ; checkpoint: A = the inverted SWCHA
    STA PF1

; --- the fire button: INPT4 bit 7 = 0 when pressed ---
    LDA INPT4
    AND #$80
    BNE FireOff
    LDA #$42                ; pressed: red
    BNE FireStore
FireOff:
    LDA #$C8                ; released: green
FireStore:
FireWrite:                  ; checkpoint: A = COLUP1
    STA COLUP1

; --- position the needle (P0) and the fire block (P1) ---
    LDA NeedleX
    CLC
    ADC #POS_BIAS
PosApply0:                  ; checkpoint: P0's biased target
    JSR SetCoarse0
    LDA #(FIRE_X + POS_BIAS)
PosApply1:                  ; checkpoint: P1's biased target
    JSR SetCoarse1
    STA WSYNC
HmoveApply:                 ; checkpoint: the single HMOVE
    STA HMOVE

    LDA #$C8
    STA COLUPF              ; green playfield columns
    LDA #$02
    STA COLUBK              ; dark neutral
    LDA #$42
    STA COLUP0              ; red needle
    LDA #$01
    STA CTRLPF              ; reflect the raw-port columns
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA REFP0
    STA REFP1

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — 32 rows: the needle (P0) and the 8-row fire block (P1)
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
    LDA #$FF
    STA GRP0                ; the needle bar
    CPX #FIRE_HEIGHT
    BCS NoFire
    LDA #$FF
    BNE FireDraw
NoFire:
    LDA #$00
FireDraw:
    STA GRP1                ; the fire block, 8 rows
    STA WSYNC
    INX
    CPX #NEEDLE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0
    STA GRP1
    STA WSYNC

    LDX #(VISIBLE_LINES - SPRITE_TOP - NEEDLE_HEIGHT - 1)
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
; COARSE POSITIONING — two objects, one HMOVE
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
    STA RESP1
    RTS

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
> `lessons/part4-sprites/33-paddle-keyboard-controllers/33-paddle-keyboard-controllers.asm`.

### Code Walkthrough

#### Step 1 — Discharge and charge

`LDA #$82` / `STA VBLANK` grounds the paddle capacitors and keeps the screen blank. The `LDX #50`
pad holds that state for about 3.3 scanlines — long enough for the capacitor to drain. `LDA #$42`
clears the ground and starts the charge.

#### Step 2 — Count the charge

`LDY #0` resets the counter, and the `LDA INPT0` / `BMI` / `INY` / `CPY #128` loop counts until the
input goes high. `PaddleRead` sits on the `LDA PaddleValue` after the loop, so its A value is the
final count, 0–127. On a timeout it is 0.

#### Step 3 — Map to the needle

`CLC` / `ADC #24` turns the count into a TIA X, and `PaddleX` marks the store to `NeedleX`. The
needle's coarse positioning runs in VBLANK with the fire block's: `SetCoarse0` and `SetCoarse1` set
`HMP0`/`HMP1` and strobe `RESP0`/`RESP1`, then one `HMOVE` applies both fine offsets (the Lesson 28
rule). The measured HMOVE is on VBLANK line 27.

#### Step 4 — The matrix and the fire button

`LDA SWCHA` / `EOR #$FF` / `STA PF1` mirrors the raw port's closed switches into the playfield.
`KeyWrite` marks the store, so its A value is the inverted byte (0 with nothing closed). `LDA INPT4`
/ `AND #$80` selects green or red for `COLUP1`; `FireWrite` marks that store.

#### Step 5 — The body

The body writes `$FF` to `GRP0` on all 32 rows (the needle), and writes `$FF` to `GRP1` only on the
first eight rows (the fire block). The clear line zeroes both. The raw-port columns are drawn by the
playfield on every line; because `PF1` is set once per frame in VBLANK, the columns are stable.

#### Step 6 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `PaddleRead` | `$F043` | 0 (timeout) at line 23; A = the final count | the bounded read |
| `PaddleX` | `$F046` | line 24, cycle 2; A = 24 | the needle X |
| `KeyWrite` | `$F04D` | line 24, cycle 11; A = 0 (no keys) | the inverted `SWCHA` |
| `FireWrite` | `$F05B` | line 24, cycle 24; A = `$C8` green | the fire color |
| `PosApply0` | `$F062` | line 24, cycle 34; A = 27 (24 + 3) | the needle's target |
| `PosApply1` | `$F067` | line 25, cycle 35; A = 143 (140 + 3) | the fire block's target |
| `HmoveApply` | `$F06C` | line 27, cycle 0 | the single fine strobe |
| `VisibleStart` | `$F095` | 37, cycle 7 (first hit) | the top loop's first line |
| `BodyStart` | `$F09C` | **117, cycle 6**; 32 hits per frame | the first needle row |
| `OverscanStart` | `$F0C2` | 229, cycle 4 | overscan's first line |

## What You Should See

At rest — no paddle, no keys, no fire — the monitor is three quiet shapes on the dark field:

- the red needle at capture x = 169–216 (TIA X=24), 32 rows tall (capture y = 359–458);
- the green fire block at capture x = 865–912 (TIA X=140), 8 rows tall (y = 359–383);
- no raw-port columns lit: `SWCHA` reads `$FF`, so `PF1` is 0.

![Stella running the Lesson 33 ROM: a red needle on the left, a green fire block on the right, and dark raw-port columns](/images/lesson33/monitor.png)

*The controller monitor, captured from the committed ROM with no controller attached: the paddle
read times out to 0 and the needle sits at X=24; the fire block is green; the raw-port columns are
dark because no switch is closed to ground — a CX50 key alone cannot light them without the driven
scan.*

With a paddle whose resistance is in the low end of the range, the needle moves as you turn it;
most of a real paddle's travel is beyond this monitor's single-frame bound, which is why the
timeout is documented. With a joystick direction (or a driving controller switch), the matching
columns light green. A CX50 key needs the driven scan from Section 3; this
monitor does not run it, so the columns stay dark for a key alone. With the fire button held, the
block turns red. The at-rest capture is the committed screenshot; the input changes are what the
monitor is for.

<RomPlayer rom="/roms/part4-sprites/33-paddle-keyboard-controllers/33-paddle-keyboard-controllers.bin" title="Lesson 33 — Paddle & Keyboard Controllers" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson33.sym -o build/lesson33.bin \
  lessons/part4-sprites/33-paddle-keyboard-controllers/33-paddle-keyboard-controllers.asm
grep -E "PaddleRead|PaddleX|KeyWrite|FireWrite|BodyStart" build/lesson33.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F043' \
  docs/public/roms/part4-sprites/33-paddle-keyboard-controllers/33-paddle-keyboard-controllers.bin
```

- **`$F043` (`PaddleRead`)**: one hit per frame, A = 0 on the timeout path. With a paddle, A is the
  charge count.
- **`$F046` (`PaddleX`)**: A = 24 at rest (count 0 + 24).
- **`$F04D` (`KeyWrite`)**: A = 0 at rest; a closed switch (a joystick direction) appears here as a 1.
- **`$F05B` (`FireWrite`)**: A = `$C8` green at rest, `$42` red while fire is held.
- **`$F09C` (`BodyStart`)**: line 117, 32 hits — the needle is 32 rows tall.

## Exercises

### Exercise 1: Paddle 1

**Challenge:** read paddle 1 (`INPT1`) instead of paddle 0 and move the needle with it.

**Hints:**
1. The discharge/charge/count loop is identical; change the one `LDA INPT0` to `LDA INPT1`.
2. The needle mapping is unchanged: `X = count + 24`.
3. With no paddle on the port, the read may time out (X=24); with a paddle at minimum resistance
   it returns a small count. Either way the needle stays near the left edge.

**Expected Result:** the needle follows paddle 1. In the capture environment the port presented
paddle 1 at minimum resistance, so the read returned count 4 and the needle measures X=28 (capture
193–240); an absent paddle times out to 0, as the main ROM's `INPT0` path does (X=24). The rest of
the monitor is unchanged.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: A Wide Gold Fire Block

**Challenge:** make the fire block double width and gold when pressed.

**Hints:**
1. `NUSIZ1 = $05` doubles player 1's width (16 pixels), so the block spans 96 capture pixels.
2. The pressed color becomes `$1A` gold; the released color stays green.
3. The needle, matrix, and positioning do not change.

**Expected Result:** the block is 96 capture pixels wide at capture x = 871–966, because `NUSIZ1`
doubles it. With no fire it is green; while fire is held the same bar turns gold. Measured in a
scratch capture.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Two Needles *(Stretch Goal)*

**Challenge:** paddle 0 positions player 0 and paddle 1 positions player 1.

**Hints:**
1. A full bounded read costs about 20 scanlines plus the 3.3-line discharge, so two reads do not
   fit in one 37-line VBLANK.
   Read one paddle per frame, alternating with a frame counter, and keep both results in RAM.
2. Both players are 32-row bars; one `HMOVE` applies both fine offsets.
3. With no paddles, both reads time out to 0 and the needles overlap at X=24; player 0's red wins
   the overlap.

**Expected Result:** each needle updates at 30 Hz and follows its own paddle. With no paddles, the
picture shows a single red needle at X=24.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A paddle is a timer, not a switch**: `VBLANK` bit 7 discharges; clearing it starts the charge; `INPT0` goes high when the capacitor crosses the threshold
- ✅ **The count must be bounded**: 128 reads fit the 37-line VBLANK; 255 would not, and the stored count is 0–127
- ✅ **A timeout needs a defined value**: the monitor stores 0 and documents it as "no paddle, or a resistance beyond the single-frame bound"
- ✅ **`SWCHA` is an active-low port**: with `SWACNT=$00`, invert it for `PF1` and each closed switch lights a playfield column
- ✅ **A keypad needs a driven scan**: `SWACNT=$FF`, pull one row low, wait ~400 µs, then read `INPT0`/`INPT1`/`INPT4`
- ✅ **`INPT4` bit 7 is 0 when fire is pressed**: test the bit, not "nonzero"; the fire block's `COLUP1` shows the state
- ✅ **One `HMOVE` for two objects**: set both coarse and fine values, then strobe once
- ✅ **The monitor is also a test harness**: the at-rest capture pins the layout, and each input has a checkpoint in the log

## What's Next

The monitor covers input. [Lesson 34: Sprite Animation](/part4-sprites/34-sprite-animation) returns
to the sprite: four walk frames in a table, a frame pointer computed in VBLANK, a cadence of eight
frames, and a direction flip — the last lesson of Part 4.
