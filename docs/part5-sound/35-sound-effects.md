---
title: "Lesson 35: Sound Effects — Beeps, Boops, and Explosions"
description: "The TIA's audio registers are three bytes per channel. Lesson 35 builds the sound lab: a beep, a boop, and a noise explosion, with a volume meter and a pitch marker that show the otherwise invisible audio state."
prev:
  text: "Lesson 34: Sprite Animation"
  link: "/part4-sprites/34-sprite-animation"
next:
  text: "Lesson 36: Music"
  link: "/part5-sound/36-music"
---

# Lesson 35: Sound Effects — Beeps, Boops, and Explosions

> **Part 5: Sound** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 12 (the NTSC frame), Lesson 15 (the RIOT timer), Lesson 17 (cycle counting), Lesson 26 (`SetHorizPos` and fine positioning), Lesson 30 (per-line register writes). The audio registers are introduced here.
> **You will learn:** what `AUDC`, `AUDF`, and `AUDV` do; how the TIA's divider chain turns a 31,399.5 Hz clock into a tone; why the same three bytes can be a beep, a downward boop, or white-noise explosion; how to shape a sound with a per-frame volume envelope; how to make the audio state visible on screen
> **You will build:** "the sound lab" — a self-cycling BEEP/BOOP/BOOM player with a three-band effect indicator, a 15-cell volume meter, and a pitch marker; plus three exercises: raise the beep, turn the boop into a siren, and build a joystick-driven sound board

## Introduction

Every lesson so far has produced something you can see. Sound is different: the TIA's audio output
is a continuous voltage, and the program's only control is a handful of write-only registers. There
is no buffer, no sample, and no "play" command. A sound effect is a **schedule of register writes**
spread across frames.

The TIA has two identical audio channels. Each one has three bytes:

| Register | What it controls |
|---|---|
| `AUDC0` / `AUDC1` | the generator: a pure-tone divisor or a noise type |
| `AUDF0` / `AUDF1` | the frequency divider, 0–31 (higher = lower pitch) |
| `AUDV0` / `AUDV1` | the volume, 0–15 (0 = silent) |

This lesson builds **the sound lab**: a ROM that plays three classic effects in a loop and draws
their state on screen. A full-width band at the top shows which effect is active; a 15-cell meter
on the left is the current volume; an 8-row marker on a pitch ruler shows the current `AUDF`. The
picture is not decoration — it is the evidence that the registers are doing what the code says.

::: details TypeScript Equivalent
A sound effect is a tiny state machine. Each frame the machine advances, and the current frame
selects the pitch and volume:

```typescript
interface Effect {
  ctl: number;                         // AUDC
  length: number;                      // frames
  pitch: (frame: number) => number;    // AUDF
  volume: (frame: number) => number;   // AUDV
}

const effects: Effect[] = [beep, boop, boom];
let id = 0;
let frame = 0;

function vblank() {
  frame++;
  if (frame === effects[id].length) {
    frame = 0;
    id = (id + 1) % effects.length;
  }
  const effect = effects[id];
  write(AUDC0, effect.ctl);
  write(AUDF0, effect.pitch(frame));
  write(AUDV0, effect.volume(frame));
}
```

The analogy breaks in one important place: a modern audio API hands a buffer to a mixer and the
operating system keeps playing it. The 2600 has no mixer and no buffer. If the program stops
writing, the last register value keeps sounding — including a volume above zero, which is why
every effect ends by writing `AUDV=0`.
:::

## Theory

### Section 1: The Divider Chain

The audio clock is not the CPU clock. On NTSC it is **31,399.5 Hz** — the 3.579545 MHz color clock
divided by 114. A pure tone passes through two dividers:

```text
31,399.5 Hz  →  divide by (AUDF + 1)  →  divide by D  →  the tone
```

`AUDF` is a 5-bit field: 0–31. `AUDC` selects the generator and, for a pure tone, the second
divisor `D`:

| `AUDC` | Generator | `D` | Character |
|---|---|---|---|
| `$04` / `$05` | pure tone | 2 | bright, highest range |
| `$06` / `$0A` | pure tone | 31 | mid, soft |
| `$0C` / `$0D` | pure tone | 6 | the workhorse middle tone |
| `$0E` | pure tone | 93 | low, buzzy |
| `$08` | 9-bit poly | — | white noise (the explosion) |

So the frequency is:

```text
f = 31399.5 / ((AUDF + 1) × D)
```

Two consequences matter immediately. **Higher `AUDF` means lower pitch** — it is a divider, not a
note number. And an `AUDF` outside 0–31 is not "a very low note"; the register simply ignores the
upper bits, so `AUDF=39` is `AUDF=7`. Lesson 36 turns this arithmetic into a note table; here the
lesson uses it directly.

`AUDV` is the volume, 0–15. Zero is silence. That is the standard way to end an effect: leave
`AUDC` and `AUDF` alone, write `AUDV=0`, and the channel goes quiet. `AUDC=0` also disables the
channel, but it is a different tool — it changes the generator, not the volume.

### Section 2: Three Effects, Three Shapes

The sound lab uses one channel and three effects. Each is a table of per-frame values, not a
single "play" call.

| Effect | `AUDC` | `AUDF` | Volume | Length |
|---|---|---|---|---|
| BEEP | `$0C` (div 6) | `$13` = 19 → 261.66 Hz | 15 for 10 frames, 12 for 5, 8 for 5, 0 for 12 | 32 |
| BOOP | `$04` (div 2) | `6 + frame/2`, clamped at 20 → 2,242.8 → 747.6 Hz | 12 for 24 frames, 8 for 4, 0 for 4 | 32 |
| BOOM | `$08` (9-bit poly) | `12,19,7,25,3,30,14,9,22,5,28,16,1,24,11,19` (indexed by `frame & 15`) | `15 − frame/3` → 15 down to 0, three frames per level | 48 |

The **BEEP** is a steady pitch with a stepped fade: a clean, short tone. The **BOOP** moves its
divider one step every two frames, so the pitch falls from a bright 2.2 kHz to a soft 748 Hz; the
volume fades after the sweep. The **BOOM** is not a tone at all: `AUDC=$08` selects the 9-bit
polynomial noise generator, and `AUDF` changes the rate at which the noise shifts. The result is a
rushing, gritty decay. Changing `AUDF` here changes the *texture* of the noise, not a musical
pitch; the lesson says so rather than pretending the table is a scale.

The three lengths (32, 32, 48) are the effect clock. A frame counter runs from 0 to the current
length; when it reaches the length, it resets and the next effect begins. The counter is a **frame
counter**, not a RIOT timer: it advances with the picture, so the sound and the screen stay in
step.

### Section 3: The Monitor

The sound lab makes the audio state visible with three shapes:

| Part | Object | Position | What it shows |
|---|---|---|---|
| Effect bands | Playfield, 3 × 8 lines | visible lines 0–23 | the active effect's color; the others `$02` |
| Volume meter | Player 0, 15 cells × 6 lines | X=24, visible lines 28–117 | one lit cell per `AUDV` unit; cell 0 is the bottom |
| Pitch marker | Player 1, 8 rows | X = 24 + `AUDF`×4, visible lines 122–129 | the current `AUDF` on a 32-step ruler |

The meter's mapping is the important part. Cell 14 is the top and cell 0 the bottom. A cell is lit
when its index is **below** the volume: volume 15 lights every cell, volume 8 lights cells 0–7, and
volume 0 lights none. The bar therefore grows upward from the bottom, exactly like a VU meter.

The pitch marker's X is a linear map of the 5-bit divider: `AUDF` 0 is X=24 and `AUDF` 31 is
X=148. In the capture, `capture x = 25 + 6×X`, so `AUDF` 19 lands at 625 and `AUDF` 9 at 385.
The marker does not show a musical note; it shows the divider value, which is what the register
actually holds.

### Section 4: The Frame

The frame is the course standard: 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = **262 lines**.
The picture is work-first: each line's registers are written, then `STA WSYNC` moves to the next
line. The first work line is scanline 37, the last is 228, and overscan starts at 229.

The 192 picture lines are budgeted exactly:

```text
24  top effect bands (3 × 8)
 4  gap
90  volume meter (15 cells × 6)
16  pitch band (4 blank + 8 marker + 4 blank)
58  bottom background
---
192
```

The audio writes happen in VBLANK, before the visible kernel. They do not need to be synchronized
to the beam: `AUDC`, `AUDF`, and `AUDV` hold their values until the program changes them. The
VBLANK work is small — the effect step, three register writes, two object positions, and one
`HMOVE` — and fits comfortably inside the 37 lines. The timer is armed about 15 cycles into the line and covers 2,753 cycles, so it expires at 2,768; the
final `+wait_timer` WSYNC absorbs the remaining 44 cycles to the 2,812-cycle boundary.

::: tip Why one HMOVE?
The meter (player 0) and the pitch marker (player 1) are positioned every frame. Both coarse
`RESPx` strobes and both `HMPx` values are set first, then a single `HMOVE` applies both fine
offsets in one HBLANK. This is the one-`HMOVE` rule from Part 4: a second `HMOVE` would re-apply
the first player's offset and could move it twice.
:::

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson35.bin \
  lessons/part5-sound/35-sound-effects/35-sound-effects.asm
stella build/lesson35.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 35: Sound Effects — Beeps, Boops, and Explosions — Racing the Beam
; =============================================================================
; Part 5: Sound
;
; What this program does:
;   "The sound lab": three effects — BEEP, BOOP, BOOM — play one after another.
;   One of the three full-width bands at the top shows which effect is active; a 15-cell
;   volume meter on the left shows AUDV; an 8-row marker shows AUDF on a pitch
;   ruler at the bottom.  The picture makes the otherwise invisible audio
;   state visible while the ROM plays.
;
; The TIA audio registers:
;   AUDC0 ($15)  generator / tone divisor (0-15)
;   AUDF0 ($17)  frequency divider (0-31; higher = lower pitch)
;   AUDV0 ($19)  volume (0-15; 0 = silent)
;   Channel 1 uses $16/$18/$1A; this lesson uses channel 0 only.
;
; The tone formula (NTSC):
;   f = 31399.5 / ((AUDF + 1) * D)
;   D = 2 for AUDC 4/5, 6 for C/D, 31 for 6/A, 93 for E.
;   AUDC=$08 is the 9-bit poly noise generator (white noise), not a tone.
;
; The effects (all values per frame):
;   BEEP  AUDC=$0C (div 6),  AUDF=$13 (261.66 Hz), volume 15 -> 12 -> 8 -> 0.
;   BOOP  AUDC=$04 (div 2),  AUDF sweeps 6 -> 20 (2242.8 -> 747.6 Hz),
;         volume 12 -> 8 -> 0.
;   BOOM  AUDC=$08 (9-bit poly), AUDF follows a 16-byte table, volume 15 -> 0.
;   The effect lengths are 32, 32, and 48 frames; the ROM loops forever.
;
; The picture:
;   Visible line 0 = scanline 37.  The top 24 lines are three 8-line bands.
;   The next 90 lines are the 15-cell meter (6 lines per cell); cell 0 is at
;   the bottom and lights when its index is below the volume.  The next 16
;   lines hold the pitch marker (4 blank + 8 marker + 4 blank).  The last 58
;   lines are the background.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), EffectStep (A = the new effect ID),
;   CtlWrite (A = AUDC), FreqWrite (A = AUDF), VolWrite (A = AUDV),
;   BodyStart (37), MeterStart (65), HmoveApply/HmoveDone (one per frame),
;   OverscanStart (229).
;
; Build: acme -f plain -o build/lesson35.bin \
;        lessons/part5-sound/35-sound-effects/35-sound-effects.asm
; Run:   stella build/lesson35.bin     (click the screen to hear it)
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
METER_X        = 24
POS_BIAS       = 3

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
EffectID    = $80   ; 0 = BEEP, 1 = BOOP, 2 = BOOM
EffectFrame = $81   ; 0 .. EffectLen-1; starts at $FF so the first INC is 0
Volume      = $82   ; the current AUDV value, for the meter
Pitch       = $83   ; the current AUDF value, for the marker
EffectColor = $84   ; the active effect's color, for the band/meter/marker

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$FF
    STA EffectFrame         ; the first VBLANK increment makes this 0
    LDA #$00
    STA EffectID

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- advance to the next effect when the current one ends ---
    INC EffectFrame
    LDX EffectID
    LDA EffectLen,X
    CMP EffectFrame
    BNE NoEffectStep
    LDA #$00
    STA EffectFrame
    INC EffectID
    LDA EffectID
    CMP #3
    BCC StoreEffect
    LDA #$00
StoreEffect:
EffectStep:                 ; checkpoint: A = the new effect ID
    STA EffectID
NoEffectStep:

; --- the generator is shared; the effect routines pick pitch and volume ---
    LDX EffectID
    LDA EffectCtl,X
    STA AUDC0
CtlWrite:                   ; checkpoint: A = AUDC

    LDA EffectID
    CMP #0
    BEQ Beep
    CMP #1
    BEQ Boop
    JMP Boom

Beep:
    LDA #$13                ; AUDF 19 = 261.66 Hz on div 6
    STA Pitch
    LDX EffectFrame
    LDA BeepVol,X
    STA Volume
    JMP SoundDone

Boop:
    LDA EffectFrame
    LSR                     ; one AUDF step every 2 frames
    CLC
    ADC #6
    CMP #21
    BCC BoopStore
    LDA #20
BoopStore:
    STA Pitch
    LDX EffectFrame
    LDA BoopVol,X
    STA Volume
    JMP SoundDone

Boom:
    LDA EffectFrame
    AND #$0F
    TAX
    LDA BoomFreq,X          ; the noise generator's divider
    STA Pitch
    LDX EffectFrame
    LDA BoomVol,X
    STA Volume

SoundDone:
    LDA Pitch
    STA AUDF0
FreqWrite:                  ; checkpoint: A = AUDF
    LDA Volume
    STA AUDV0
VolWrite:                   ; checkpoint: A = AUDV

    LDX EffectID
    LDA EffectColorTbl,X
    STA EffectColor

; --- position player 0 (meter) and player 1 (pitch marker) ---
    LDA #(METER_X + POS_BIAS)
    JSR SetPos0
    LDA Pitch
    ASL
    ASL                     ; Pitch * 4
    CLC
    ADC #(METER_X + POS_BIAS)
    JSR SetPos1

; --- colors and playfield setup ---
    LDA EffectColor
    STA COLUP0
    STA COLUP1
    LDA #$02
    STA COLUBK
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    LDA #$01
    STA CTRLPF

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK
    LDX #0
VisibleStart:
BodyStart:                  ; checkpoint: the first visible line (scanline 37)
BandLoop:
    LDA #$02
    CPX EffectID
    BNE BandColor
    LDA EffectColor
BandColor:
    STA COLUPF
    LDY #8
BandLines:
    STA WSYNC
    DEY
    BNE BandLines
    INX
    CPX #3
    BNE BandLoop

; --- the 4-line gap; the playfield bars are off below the top bands ---
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #4
GapLoop:
    STA WSYNC
    DEY
    BNE GapLoop

; --- the 15-cell meter, top cell (14) down to bottom cell (0) ---
MeterStart:                 ; checkpoint: the first meter line (scanline 65)
    LDX #15
MeterLoop:
    DEX
    CPX Volume
    LDA #$00
    BCS MeterDark           ; cell index >= volume: dark
    LDA #$FF                ; cell index < volume: lit
MeterDark:
    STA GRP0
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    CPX #0
    BNE MeterLoop

; --- the pitch band: 4 blank, 8 marker, 4 blank ---
    LDA #$00
    STA GRP0
    STA GRP1
    LDY #4
PitchTop:
    STA WSYNC
    DEY
    BNE PitchTop
    LDA #$FF
    LDY #8
PitchMarker:
    STA GRP1
    STA WSYNC
    DEY
    BNE PitchMarker
    LDA #$00
    STA GRP1
    LDY #4
PitchBottom:
    STA WSYNC
    DEY
    BNE PitchBottom

; --- the bottom background: 58 lines ---
    LDY #58
BottomLoop:
    STA WSYNC
    DEY
    BNE BottomLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; TWO-OBJECT POSITIONING — the class routine, one HMOVE at the end
; =============================================================================
; A = the target TIA X plus POS_BIAS.  Each routine sets its coarse RESxx and
; its HMPx value; SetPos1 ends with WSYNC/HMOVE, so the fine offsets for both
; players are applied in one HBLANK.
SetPos0:
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
SetPos1:
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
    STA WSYNC
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed
    RTS

; =============================================================================
; EFFECT TABLES
; =============================================================================
EffectLen:
    !byte 32, 32, 48
EffectCtl:
    !byte $0C, $04, $08
EffectColorTbl:
    !byte $C8, $84, $42

BeepVol:
    !fill 10, 15
    !fill 5, 12
    !fill 5, 8
    !fill 12, 0

BoopVol:
    !fill 24, 12
    !fill 4, 8
    !fill 4, 0

BoomFreq:
    !byte 12,19,7,25,3,30,14,9,22,5,28,16,1,24,11,19

BoomVol:
    !fill 3, 15
    !fill 3, 14
    !fill 3, 13
    !fill 3, 12
    !fill 3, 11
    !fill 3, 10
    !fill 3, 9
    !fill 3, 8
    !fill 3, 7
    !fill 3, 6
    !fill 3, 5
    !fill 3, 4
    !fill 3, 3
    !fill 3, 2
    !fill 3, 1
    !fill 3, 0

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
> `lessons/part5-sound/35-sound-effects/35-sound-effects.asm`.

### Code Walkthrough

#### Step 1 — The effect clock

`INC EffectFrame` advances the effect once per frame. `EffectFrame` starts at `$FF`, so the first
increment makes it 0. `LDX EffectID` / `LDA EffectLen,X` / `CMP EffectFrame` checks the current
effect's length; on the frame that reaches it, the counter resets to 0 and `EffectID` advances,
wrapping at 3. `EffectStep` marks the store, so the log reports A = the new effect ID only on the
frames where the effect changes.

#### Step 2 — The generator

`LDX EffectID` / `LDA EffectCtl,X` / `STA AUDC0` selects the generator from the three-entry
`EffectCtl` table. `CtlWrite` marks the store. The generator is written every frame even when it
does not change; that is harmless and keeps the three effects on one code path.

#### Step 3 — The three shapes

`Beep` writes `Pitch=$13` and looks up `BeepVol[EffectFrame]`. `Boop` computes
`6 + EffectFrame/2`, clamps it at 20, and looks up `BoopVol`. `Boom` indexes `BoomFreq` with
`EffectFrame & 15` and `BoomVol` with the full frame. All three converge on `SoundDone`, which
writes `AUDF0` (`FreqWrite`) and `AUDV0` (`VolWrite`). The common tail is what makes the state log
readable: one frequency write and one volume write per frame, regardless of the effect.

#### Step 4 — Position and color

The meter is player 0 at X=24; the pitch marker is player 1 at `24 + Pitch×4`. `SetPos0` and
`SetPos1` are identical divide-by-15 routines with the same cycle count; the second ends with
`STA WSYNC` / `STA HMOVE`, so both fine offsets are applied in one HBLANK. The effect color is
looked up from `EffectColorTbl` and written to `COLUP0` and `COLUP1`, and the playfield bands use
the same color for the active band.

#### Step 5 — The visible kernel

The kernel is work-first. The three top bands write `COLUPF` and hold it for 8 lines each. The
gap turns the playfield off. The meter loop counts X from 15 down to 1, compares the cell index
with `Volume`, writes `$FF` or `$00` to `GRP0`, and holds the cell for six lines. The pitch band
writes four blank lines, eight `GRP1=$FF` marker lines, and four blanks. The bottom 58 lines are
background. The last line is 228; `OverscanStart` is 229.

#### Step 6 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F016` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F024` | 0, cycle 5 | VBLANK's first line |
| `EffectStep` | `$F046` | A=1 at frame 33, A=2 at 65, A=0 at 113, A=1 at 145 | the effect change |
| `CtlWrite` | `$F04F` | A=`$0C` at frame 1, `$04` at 33, `$08` at 65, `$0C` at 113 | `AUDC` |
| `FreqWrite` | `$F097` | A=`$13` during BEEP; A=6,7,…,20 during BOOP; the noise table during BOOM | `AUDF` |
| `VolWrite` | `$F09B` | A=15 (frames 1–10), 12 (11–15), 8 (16–20), 0 (21–32) for the BEEP | `AUDV` |
| `BodyStart` | `$F0DC` | 37, cycle 7 | the first visible line |
| `MeterStart` | `$F101` | 65, cycle 4 | the first meter line (visible 28) |
| `HmoveApply` | `$F180` | line 3, cycle 55 | the WSYNC stall; the `STA HMOVE` executes at line 4, cycle 0 (see `HmoveDone`) |
| `HmoveDone` | `$F182` | line 4, cycle 3 | the store has executed at line 4, cycle 0, inside HBLANK |
| `OverscanStart` | `$F148` | 229, cycle 4 | overscan's first line |

## What You Should See

The sound lab is three quiet shapes on the dark field, with one effect moving at a time.

**BEEP.** The top band is green; the two lower bands are dark. The volume meter is a solid green
bar of **15 cells** at capture x = 169–216, y ≈ 195–477. The pitch marker is a green 8-row block at
capture x = 625–672 (AUDF 19, X=100), y ≈ 492–515.

![Stella running the Lesson 35 ROM during the beep: a green top band, a full green volume meter, and a green pitch marker](/images/lesson35/beep.png)

*The BEEP at full volume, captured from the committed ROM: band 0 green, the meter at 15/15, and
the pitch marker at AUDF 19 (261.66 Hz).*

**BOOM.** The third band is red; the top two are dark. The meter is a red bar that has begun to fall. This capture caught
**14 cells** (y ≈ 214–477), one three-frame step after the peak of 15; the pitch marker is red at
capture x = 889–936 (AUDF 30), y ≈ 492–515. The marker jumps around the ruler as the noise table
advances.

![Stella running the Lesson 35 ROM during the explosion: a red third band, a falling red volume meter, and a red pitch marker near the right edge](/images/lesson35/boom.png)

*The BOOM one step into its decay: band 2 (the third slot) red, the meter at 14/15, and the noise
divider at AUDF 30. The first step is 15; this capture is three frames later. The first playfield
bit of the band's first scanline (4 color clocks, 24 capture px) still shows the previous color:
the active band's extra `LDA EffectColor` pushes the `STA COLUPF` to CPU cycle 24, just after the
playfield's first pixel at cycle 22. A TIA store takes effect where it lands — there is no per-line
latch — which is the same mid-line rule Lesson 18 teaches.*

<RomPlayer rom="/roms/part5-sound/35-sound-effects/35-sound-effects.bin" title="Lesson 35 — Sound Effects" />

Click the player screen once: Javatari starts muted until a user gesture, and the sound begins
when you click. The picture and the sound are generated by the same three register writes.

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson35.sym -o build/lesson35.bin \
  lessons/part5-sound/35-sound-effects/35-sound-effects.asm
grep -E "EffectStep|CtlWrite|FreqWrite|VolWrite|MeterStart" build/lesson35.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F09B' \
  docs/public/roms/part5-sound/35-sound-effects/35-sound-effects.bin
```

- **`$F046` (`EffectStep`)**: frames 33, 65, 113, 145 with A = 1, 2, 0, 1 — the 32/32/48-frame
  cycle.
- **`$F04F` (`CtlWrite`)**: A = `$0C` for BEEP, `$04` for BOOP, `$08` for BOOM.
- **`$F097` (`FreqWrite`)**: A = `$13` during BEEP; 6, 7, …, 20 during BOOP; the 16-entry noise
  table during BOOM.
- **`$F09B` (`VolWrite`)**: the BEEP envelope 15 → 12 → 8 → 0; the BOOP 12 → 8 → 0; the BOOM
  15 → 0.
- **`$F101` (`MeterStart`)**: line 65, the first meter cell; the bar's height is the volume.

## Exercises

### Exercise 1: Raise the Beep

**Challenge:** raise the BEEP from `AUDF=$13` (261.66 Hz) to `AUDF=$09` (523.33 Hz).

**Hints:**
1. The BEEP is one `LDA #$13` in the `Beep` routine; change the operand.
2. The volume table, the other effects, and the monitor do not change.
3. The pitch marker's capture x is `169 + 24×AUDF`.

**Expected Result:** the BEEP is one octave higher, and its marker sits at capture x = 385–432
(AUDF 9, X=60). The debugger's `FreqWrite` reports A=`$09` during BEEP; the other effects are
unchanged.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Siren Boop

**Challenge:** replace the BOOP's one-way sweep with a two-pitch siren: `AUDF` 6 for four frames,
20 for four frames, repeating; keep the volume envelope.

**Hints:**
1. Test bit 2 of `EffectFrame`: four frames at the higher pitch, four at the lower.
2. `AUDF` 6 is the **higher** pitch (2,242.8 Hz); `AUDF` 20 is the **lower** pitch (747.6 Hz).
3. The volume table stays 12 for 24 frames, 8 for 4, 0 for 4.

**Expected Result:** the pitch marker jumps between capture x = 313–360 (AUDF 6, X=48) and
649–696 (AUDF 20, X=104) every four frames. `FreqWrite` alternates A=`$06`/`$14`; the blue band
and the 12-cell meter are unchanged.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The Sound Board *(Stretch Goal)*

**Challenge:** read the joystick: left/right selects BEEP, BOOP, or BOOM; fire restarts the
selected effect; after 120 frames with no input, the automatic cycle resumes.

**Hints:**
1. `SWCHA` bits 6 (left) and 7 (right) are active-low; `INPT4` bit 7 is active-low fire.
2. Add an `AutoMode` flag: 1 while the ROM is cycling, 0 while the player is choosing. On input,
   clear it and reset the idle timer.
3. In manual mode, let the effect frame loop the selected effect instead of advancing the effect
   ID; after 120 idle frames, set `AutoMode=1` and let the normal cycle resume.

**Expected Result:** tapping left/right moves the bright band through the three effects; fire
restarts the selected one; after two seconds with no input the ROM returns to its automatic
32/32/48 cycle. In the debugger, `SelectStore` reports A=2,1,0,… as the forced-left witness cycles,
and the no-input ROM's `EffectStep` fires at frames 33, 65, 113, and 145.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **Three bytes per channel**: `AUDC` picks the generator, `AUDF` divides the clock, `AUDV` sets the volume
- ✅ **The tone formula is exact**: `f = 31399.5 / ((AUDF+1) × D)`, with `AUDF` limited to 0–31 and `D` selected by `AUDC`
- ✅ **Higher `AUDF` is lower pitch**: it is a divider, not a note number; an out-of-range value silently loses its upper bits
- ✅ **`AUDV=0` is the mute**: leave the generator and divider alone and write zero to end an effect
- ✅ **A sound effect is a frame schedule**: a counter selects the pitch and volume for each frame; there is no buffer
- ✅ **The monitor is the evidence**: the bands, the 15-cell meter, and the pitch marker are driven by the same values written to the audio registers
- ✅ **One `HMOVE` for two objects**: set both coarse and fine values, then strobe once

## What's Next

The sound lab plays one channel and one effect at a time. [Lesson 36: Music](/part5-sound/36-music)
turns the divider arithmetic into a measured note table, plays a melody and a harmony on the two
channels, and draws the current scale degrees on an eight-rung ladder.
