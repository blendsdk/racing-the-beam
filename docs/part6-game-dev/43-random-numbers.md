---
title: "Lesson 43: Random Numbers — Unpredictable Fun"
description: "One shift, one branch, one XOR: Lesson 43 builds an 8-bit Galois LFSR that walks all 255 nonzero bytes, a seed row and 8×8 history grid drawn by the playfield, a 15-cell meter of the high nibble, and a two-byte beep on bit 0 — plus three exercises: a 16-bit LFSR, a ball placed by a mask, and a SELECT reseed."
prev:
  text: "Lesson 42: Difficulty and Progression — The Difficulty Ladder"
  link: "/part6-game-dev/42-difficulty"
next:
  text: "Lesson 44: AI & Enemy Behavior — Chase, Patrol, Flee"
  link: "/part6-game-dev/44-ai-enemy-behavior"
---

# Lesson 43: Random Numbers — Unpredictable Fun

> **Part 6: Game Development** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 09 (bitwise operations), Lesson 11 (lookup tables), Lesson 27 (joystick input), Lesson 34 (frame counters)
> **You will learn:** how a linear feedback shift register (LFSR) turns a shift and a conditional XOR into a 255-state sequence; why a zero seed freezes it; how the Galois `$1D` step works in five instructions; how `RandomMask` selects a range with one `AND`; how an 8-byte history and a playfield grid make the sequence visible; how a 15-cell meter shows the high nibble; how fire and the joystick seed the generator
> **You will build:** "the random lab" — an 8-cell seed row, an 8×8 history grid, a 15-cell `seed >> 4` meter, a two-byte beep on bit 0, fire and joystick reseeding, and an auto-demo that needs no controller; plus three exercises: a 16-bit LFSR, a ball placed by `seed & 7`, and a SELECT reseed

## Introduction

Lesson 42 gave the game a ladder: a starting level, a speed table, and three lives. Every run
of the same level was still identical, though. The enemy bounced on the same line, the ball
fell on the same column, and a player who had learned the first ten seconds had learned the
whole game. The missing ingredient is **surprise**.

The Atari 2600 has no random-number register. The TIA draws and the RIOT counts, but neither
produces a random byte. A game that wants variety must build its own generator from the
instructions it already has. The classic tool is a **linear feedback shift register** (LFSR):
a byte that shifts left every step, with one XOR fed back from the bit that falls off the end.
With the right polynomial the byte visits every nonzero value before it repeats — 255 states
from eight bits, using one `ASL`, one branch, and one `EOR`.

This lesson builds **the random lab**. The current seed is a row of eight 4-pixel cells at the
top of the screen. Below it, an 8×8 grid shows the last eight seeds, one row per seed and four
scanlines per row. On the left, a 15-cell meter shows the seed's high nibble; the playfield is
mirrored, so the same three displays appear again on the right. Every four frames the LFSR
takes one step, the history shifts, and the speaker ticks when the new bit 0 is set. Fire
reseeds from the frame counters; the joystick nudges the seed by one each frame it is held. The companion program
`43-random-numbers.asm` is the complete ROM; the exercises extend it to 16 bits, use a mask to
place a ball, and add a second reseed source on SELECT.

::: details TypeScript Equivalent
The generator is a class with one private byte and two methods. The shape transfers; the
constraints do not:

```typescript
class Lfsr8 {
  private state: number;

  constructor(seed: number) {
    // Zero is the fixed point: 0 << 1 is 0 and the XOR never runs.
    this.state = seed === 0 ? 0x5a : seed & 0xff;
  }

  step(): number {
    const feedback = (this.state & 0x80) !== 0; // the old bit 7
    this.state = (this.state << 1) & 0xff;      // the 8-bit register
    if (feedback) this.state ^= 0x1d;           // taps 0, 2, 3, 4
    return this.state;
  }

  mask(m: number): number {
    return this.state & m;                       // a power-of-two range without a modulo
  }

  history: number[] = [];
  push(): void {
    this.history.unshift(this.state);            // newest at index 0
    if (this.history.length > 8) this.history.pop();
  }
}
```

The analogy breaks in four places. JavaScript numbers are 64-bit floats, so the `& 0xff` is
the only thing making the register eight bits wide. The `if` is a 6502 carry branch, not a
boolean: the `ASL` puts the old bit 7 in the carry and the `BCC` reads it on the next
instruction. There is no modulo operator in the 6502 instruction set; `mask` is the whole range
story. And there is no `render`: the seed row, the grid, and the meter are a scanline plan,
rebuilt every frame from the same bytes.
:::

## Theory

### Section 1: A Sequence You Can Repeat

A **pseudo-random number generator** (PRNG) is a deterministic machine with a random-looking
output. It starts from a **seed** and produces a fixed sequence; the same seed always produces
the same sequence. That sounds like the opposite of randomness, and in a cryptographic sense
it is. For a game it is exactly what you want: the sequence is long enough that the player
cannot predict the next value, and it is reproducible, so a bug reported at "the third enemy"
can be replayed from the same seed.

The 2600 has no source of entropy. Its clocks are deterministic: the RIOT timer counts CPU
cycles from a known start, and `+clean_start` zeroes the RAM, so there is no uninitialised byte
to harvest. Even the frame counters are predictable: a player who presses fire at the same
frame gets the same seed. The LFSR does not create
entropy; it **stretches** the small amount of variety that input and timing provide into a
long sequence. That is the honest description, and it is enough for a game.

The sequence is a **cycle**, not an infinite stream. An 8-bit LFSR has at most 256 states; the
right polynomial gives 255 of them before the start value returns. A game that runs for hours
will eventually repeat. At one step every four frames, 255 steps take 1,020 frames — about 17
seconds at 60 Hz. That is why real games mix the seed with input: a new fire press or a new
joystick nudge moves the cycle to a different starting point.

### Section 2: The Galois LFSR

A shift register holds bits and moves them one place per step. An LFSR adds **feedback**: the
bit that falls off one end is combined with other bits and fed back into the other end. In the
**Galois** form the feedback is applied as a conditional XOR after the shift:

```asm
    LDA RandomSeed
    ASL                 ; shift left; the old bit 7 lands in the carry
    BCC RandomNoEor     ; a zero fell off the end: no feedback
    EOR #$1D            ; a one fell off: apply the polynomial
RandomNoEor:
    STA RandomSeed
```

`ASL` shifts the accumulator left, moves bit 7 into the carry, and puts a zero in bit 0. If the
carry is clear, the shift alone is the step. If the carry is set, the `EOR #$1D` flips bits 0,
2, 3, and 4 of the shifted byte. Those four bits are the **taps**; the constant `$1D` is
`0001 1101` in binary. The result is a new byte in the same eight bits, and the cycle repeats.

The polynomial `$1D` is **maximal-length**: starting from any nonzero seed, the register visits
all 255 nonzero bytes and then returns to the start. That is a mathematical property of the
polynomial, not a tuning choice. The 16-bit exercise uses `$2D` for the same reason; its cycle
is 65,535.

From the lesson's reset seed `$5A`, the first sixteen steps are:

| Step | Seed | Frame (one step every four frames) |
|---|---|---|
| 0 | `$5A` | 0 |
| 1 | `$B4` | 4 |
| 2 | `$75` | 8 |
| 3 | `$EA` | 12 |
| 4 | `$C9` | 16 |
| 5 | `$8F` | 20 |
| 6 | `$03` | 24 |
| 7 | `$06` | 28 |
| 8 | `$0C` | 32 |
| 9 | `$18` | 36 |
| 10 | `$30` | 40 |
| 11 | `$60` | 44 |
| 12 | `$C0` | 48 |
| 13 | `$9D` | 52 |
| 14 | `$27` | 56 |
| 15 | `$4E` | 60 |

Stella's `RandomStep` checkpoint reports exactly this sequence in the companion ROM: `$B4` at
frame 4, `$75` at 8, `$EA` at 12, and so on. The table is the ledger; the state log is the
observation.

The step core costs 11 cycles when the branch is taken (`LDA` 3 + `ASL` 2 + `BCC` 3 + `STA` 3)
and 12 when the `EOR` also runs (`BCC` 2 + `EOR` 2). The `JSR` and `RTS` add 12. That is cheap
enough to run in VBLANK once every four frames without touching the visible kernel's budget.

::: warning The zero lock
Zero is the one fixed point. `0 << 1` is 0, the carry is clear, the `EOR` never runs, and the
next state is 0 again. A seed of zero therefore produces an infinite row of zeros, not a
sequence. Only the seed-accepting entry points guard it: `RandomInit` replaces a zero seed with
`$5A`, and the lesson's fire and joystick paths never store zero. `Random`, `RandomMask`, and
`RandomPush` do not test the seed; they trust the caller.
:::

### Section 3: Seeding from Input and Time

The seed is the only state the generator has. Three code paths write it:

- **Reset.** `RandomInit` stores `$5A`. The value is arbitrary but nonzero; a fixed reset seed
  makes the default run deterministic, which is what the captures need.
- **Fire.** On the 0→1 edge of `INPT4` bit 7, the ROM computes `FrameLo EOR FrameHi` and passes
  it to `RandomInit`.
- **Joystick up/down.** `SWCHA` bits 4 and 5 are active low. Up increments the seed every frame
  it is held and down decrements it every frame; a result of zero becomes `$FF`.

The fire mix uses XOR rather than addition because the two frame bytes are very different
clocks: `FrameLo` changes every frame, `FrameHi` every 256 frames. XOR folds both into one byte
without a carry, so a press 256 frames later still gets a different value. The measured log
shows the arithmetic: a press at frame 181 stores `$B5` (`$B5 EOR $00`), and a press at frame
409 stores `$98`: `FrameLo` is 409 − 256 = 153 = `$99`, `FrameHi` is 1, and `$99 EOR $01` is
`$98`.

The joystick control has a second job: it lets the player **steer** the sequence. It is a
**level**, not an edge: the VBLANK code runs `INC RandomSeed` or `DEC RandomSeed` every frame
while the direction is held, so a quick tap moves a little and a held stick sweeps the seed at
60 steps per second. Because the cycle visits every nonzero byte, a nudge is a jump to a
different point in the same cycle, not a new cycle. The `0 → $FF` wrap keeps the seed nonzero:
without it, decrementing `$01` would land on the fixed point and freeze the display.

Exercise 3 adds a fourth path: SELECT adds the two frame counters and the carry from the first
`ADC` to the **current** seed (`seed + FrameLo + FrameHi + carry`). The addition folds the
current sequence position into the seed, while fire's XOR starts from the frame counters alone.
Two SELECT presses at different frames therefore produce different `SelectSeedWrite` bytes; two
measured runs, with the press seen in ROM frames 174 and 302, record `$8D` and `$A0`. The run
at 174 has `FrameHi=0` and a carry; the run at 302 has `FrameHi=1`.

### Section 4: Masks, Not Modulo

The 6502 has no divide instruction. A general "seed modulo N" is a loop of subtracts: compare,
subtract, count, repeat. For a range that is a power of two there is a much cheaper answer:
**mask the low bits**.

`RandomMask` takes the mask in A and returns `RandomSeed AND mask`:

```asm
RandomMask:
    AND RandomSeed
RandomMaskDone:             ; checkpoint: A = RandomSeed AND the mask
    RTS
```

`$01` selects one bit, `$03` selects 0–3, `$07` selects 0–7, and `$0F` selects 0–15. The lesson
uses `$01` for the beep (play a tick when the new seed's low bit is set) and exercise 2 uses
`$07` to choose one of eight columns. The mask is exact: no division, no loop, two bytes.

A mask is not a uniform distribution in the mathematical sense. Over one full 255-state cycle,
the mask `$07` sees values 1–7 thirty-two times each and value 0 thirty-one times, because
zero is the one state the cycle omits. For a game that is invisible; for a simulation that
needs exact probabilities it is a fact to know. The lesson states it rather than hiding it.

### Section 5: A History You Can Watch

A single byte that changes every four frames is hard to read on a screen. The lesson keeps the
last eight seeds in `RandomHistory` and draws them as an 8×8 grid, so the sequence becomes a
picture: each row is one byte, each lit cell is a 1 bit, and the grid scrolls downward as new
seeds arrive.

`RandomPush` shifts the eight bytes one place and stores the new seed at the front:

```asm
RandomPush:
    LDX #7
RandomPushLoop:
    LDA RandomHistory-1,X   ; X=7: entry 6; ...; X=1: entry 0
    STA RandomHistory,X     ; X=7: entry 7; ...; X=1: entry 1
    DEX
    BNE RandomPushLoop
    LDA RandomSeed
    STA RandomHistory       ; entry 0 = the newest seed
RandomPushDone:             ; checkpoint: A = the seed stored at +0
    RTS
```

Entry 6 moves to 7, 5 to 6, and so on; the oldest byte (entry 7) is discarded. The new seed
becomes entry 0. The grid draws row 0 at the top, so the newest byte is always the top row and
the display scrolls downward. The zero-page,X base `RandomHistory-1` lets one index read the
byte one below the destination, so the copy never overwrites a byte it has not read yet.

::: tip Why row 0 is newest
The grid is a **time axis**: the top row is now, the bottom row is seven steps ago. If the
newest byte were at the bottom, the picture would scroll upward and the eye would have to
chase it. Keeping the newest row fixed at the top makes the motion read as "the new byte
enters at the top and the old ones fall away," the same direction as a text log.
:::

### Section 6: The Layout and the 262-Line Frame

The frame is the same 262 lines as every lesson in this part: 3 VSYNC + 37 VBLANK + 192
visible + 30 overscan. The 192 visible lines are four zones:

| Visible lines | Count | What |
|---|---|---|
| 0–7 | 8 | the seed row: `PF1 = RandomSeed`, eight 4-pixel cells |
| 8–39 | 32 | the history grid: eight rows of four lines, `PF1 = RandomHistory[row]` |
| 40–129 | 90 | the meter: fifteen cells of six lines, `PF1=$20` for a lit cell |
| 130–191 | 62 | background |

The total is 8 + 32 + 90 + 62 = 192. `BodyStart` is scanline 37; `OverscanStart` is 229.

The playfield is mirrored (`CTRLPF=$01`). `PF1` alone is used, and `PF0`/`PF2` stay zero, so
only chunks 4–11 are lit. Each chunk is four color clocks wide, so the eight bits of `PF1`
make a 32-pixel block. The left copy is at TIA X=16–47; the mirror copy is at X=112–143. The
middle of the screen (X=48–111) stays dark. That is the shape of a `PF1`-only display: the
pattern sits left of center and repeats as a mirror image on the right, not as a centered
32-pixel block.

The meter uses **one chunk**: `PF1=$20` lights bit 5, which is chunk 6, X=24–27. The mirror
copy is X=132–135. Each cell is six lines tall, so a full meter is 15 × 6 = 90 lines. The lit
cells grow from the bottom: cell 14 is the top cell (visible 40–45) and cell 0 is the bottom
(124–129). The value shown is `RandomSeed >> 4`, the high nibble, so the meter is a 0–15
gauge — the same range as a BCD digit, and a useful size for a game's "randomness" display.

The kernel is **work-first**: it writes the line's `PF1`, then `STA WSYNC`. The write lands in
HBLANK, before the playfield's first visible slot, so each line shows the byte written at its
start. The VBLANK block also preloads the seed into `PF1`; that is belt-and-braces, because the
`BodyStart` write already lands in HBLANK, and it matches the level-bar pattern from Lesson 42.

Colors are a design choice, not a hardware fact: the seed row and grid are gold (`$1A`), the
meter is green (`$C8`), and the background is `$02`. The playfield color register is shared by
the seed and grid zones, so the kernel changes `COLUPF` once, at the start of the meter zone.
The background zone writes `PF1=0` and leaves `COLUPF` alone; what the viewer sees there is
`COLUBK=$02`.

### Section 7: The Auto-Demo and the Controls

A lesson ROM has to demonstrate itself. This one does not need a controller: with no input, the
frame counter reaches a multiple of four every four frames, the LFSR steps, the history
shifts, and the meter moves. The two captures are simply two moments in that run.

The full input map is small:

| Input | Effect |
|---|---|
| Fire (0→1 edge) | reseed from `FrameLo EOR FrameHi`; zero becomes `$5A` |
| Joystick up (held) | `RandomSeed + 1` every frame; a result of zero becomes `$FF` |
| Joystick down (held) | `RandomSeed − 1` every frame; a result of zero becomes `$FF` |
| SELECT (exercise 3) | `RandomSeed + FrameLo + FrameHi + carry`; zero becomes `$5A` |

The beep is the same two-byte pattern as Lessons 38–42: `BeepTimer` and `BeepPitch`. On a step
whose low bit is 1, `BeepStart` writes `AUDC0=$0C`, `AUDF0=$04`, `AUDV0=$0A`, and reloads the
timer with 2. The VBLANK clock decrements the timer every frame and writes `AUDV0=0` at zero.
The tick is shorter than the four-frame step, so consecutive steps sound like separate clicks,
not a continuous tone.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson43.bin \
  lessons/part6-game-dev/43-random-numbers/43-random-numbers.asm
stella build/lesson43.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

The shared random library lives in `include/random.asm`; the lesson source sources it after
`include/vcs.asm` and `include/macro.asm`, inside the ROM area. The library is assembled first,
so its RAM symbols (`RandomSeed` at `$A0` and `RandomHistory` at `$A1–$A8`) are known to the
lesson source before its first use. `Reset` follows the library; the RESET vector points at it,
so the entry point does not have to be the first byte of the cartridge.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 43: Random Numbers — Unpredictable Fun — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; What this program does:
;   "the random lab": an 8-bit Galois LFSR runs in the background.  Every four
;   frames it takes one step, pushes the new byte into an eight-byte history,
;   and beeps when the new bit 0 is set.  The screen shows the current seed,
;   the last eight seeds, and a meter of seed >> 4.
;
; The screen (192 visible lines, CTRLPF=$01 so the playfield is mirrored):
;   visible 0-7     the seed row: PF1 = RandomSeed.  Eight 4-pixel cells
;                   (chunks 4-11, X=16-47); the mirror copy is at X=112-143.
;                   PF1 bit 7 is the leftmost cell, so the byte reads left to
;                   right as bit 7 ... bit 0.
;   visible 8-39    the history grid: eight rows of four lines.  Row 0 is
;                   RandomHistory+0 (the newest seed) and row 7 is +7 (the
;                   oldest).  PF1 = RandomHistory[row]; the same 4-pixel
;                   cells, so the grid is 32 pixels wide per half.
;   visible 40-129  the meter: fifteen 6-line cells.  Cell 14 is the top cell
;                   and cell 0 the bottom; the number of lit cells is
;                   RandomSeed >> 4 (0-15).  A lit cell writes PF1=$20, which
;                   is chunk 6 (X=24-27); the mirror copy is at X=132-135.
;   visible 130-191 background.
;   The zones total 8+32+90+62 = 192 lines; OverscanStart is scanline 229.
;
; The LFSR (include/random.asm):
;   RandomSeed = $A0, RandomHistory = $A1-$A8.
;   Random      LDA seed / ASL / BCC / EOR #$1D / STA seed.  One step visits
;               all 255 nonzero bytes before returning to the start; zero is
;               the fixed point, which is why RandomInit and the joystick
;               control both keep the seed nonzero.
;   RandomPush  shift the eight history bytes down and store the seed at +0.
;   RandomMask  A = mask, returns seed AND mask (the beep uses mask $01).
;   RandomInit  A = seed; zero becomes $5A.
;
; The controls:
;   Fire reseeds the generator from FrameLo EOR FrameHi.
;   Joystick up/down changes the seed by +1/-1 every frame while held; a
;   change that would produce zero stores $FF instead, because zero would
;   freeze the LFSR.
;   With no input the LFSR keeps stepping every four frames, so the captures
;   need no controller.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), FireRead (A = INPT4),
;   SeedWrite (A = the seed after a fire reseed),
;   RandomStep (A = the new seed), RandomPush (A = the seed pushed),
;   RandomMaskDone (A = seed AND $01), BodyStart (37),
;   OverscanStart (229).
;   This is a playfield-only lesson: there are no sprites, so there is no
;   HMOVE in this ROM.  The exercise-2 solution adds a ball and therefore
;   adds HmoveApply/HmoveDone.
;
; Build: acme -f plain -o build/lesson43.bin \
;        lessons/part6-game-dev/43-random-numbers/43-random-numbers.asm
; Run:   stella build/lesson43.bin     (click the screen to hear the beep)
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

SEED_DEFAULT   = $5A     ; the nonzero seed used at reset and for a zero reseed
RANDOM_FRAMES  = 4       ; one LFSR step every fourth frame (FrameLo & 3 == 0)

BEEP_FRAMES    = 2       ; a two-frame tick, shorter than the four-frame step
BEEP_PITCH     = $04     ; AUDF 4 on AUDC $0C: a short, bright tick

METER_CELLS    = 15      ; the meter shows a nibble: 0-15 lit cells
METER_LINES    = 6       ; six visible lines per cell
METER_CHUNK    = $20     ; PF1 bit 5 = chunk 6 = X=24-27

C_GOLD         = $1A
C_GREEN        = $C8
C_BG           = $02

; --- Lesson variables (RAM $80-$87; +clean_start zeroes them) --------------
FrameLo      = $80   ; 16-bit frame counter, low byte (also the step clock)
FrameHi      = $81   ; frame counter, high byte (fire reseeds with both)
PrevFire     = $82   ; fire state last frame (1 = pressed)
NewFire      = $83   ; this frame's fire 0 -> 1 edge
BeepTimer    = $84   ; frames of beep remaining
BeepPitch    = $85   ; AUDF for the beep
MeterCount   = $86   ; RandomSeed >> 4, computed in VBLANK
MeterFirst   = $87   ; the first meter cell's PF1 byte ($20 or $00)
;
; $88-$9F are free for exercises.
; include/random.asm owns $A0-$A8 (RandomSeed + RandomHistory).
; $A9-$D7 are free; the stack lives at $F8-$FF.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; --- the shared random library ---------------------------------------------
; The library is assembled first, so its RAM symbols (RandomSeed at $A0 and
; RandomHistory at $A1-$A8) are known to this source before the first use.
; The RESET vector at $FFFC points at Reset, which follows the library.
    !source "include/random.asm"

; =============================================================================
; RESET — the program's entry point (it need not be the first ROM byte)
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the LFSR starts from a nonzero seed -----------------------------------
; clean_start has already zeroed $A0, so RandomInit's zero guard matters if
; an exercise or a warm reset ever leaves it zero.  The lesson uses $5A.
    LDA #SEED_DEFAULT
    JSR RandomInit
    LDA #BEEP_PITCH
    STA BeepPitch

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; 1. THE 16-BIT FRAME COUNTER AND THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
; FrameLo is the fast byte; every 256 frames it wraps and FrameHi advances.
; The low byte also gates the LFSR step (its low two bits), so the step lands
; on frames 4, 8, 12, ...  Fire uses both bytes to make a fresh seed.
    INC FrameLo
    BNE FrameCounted
    INC FrameHi
FrameCounted:

    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0               ; silence at the end of the tick
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — one reseed per 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while the fire button is pressed.  The EOR turns that into
; a 1, and the EOR/AND pair keeps only the new press, so holding the button
; does not reseed on every frame.
    LDA INPT4
FireRead:                   ; checkpoint: A = INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire             ; NewFire = pressed & ~wasPressed
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

    LDA NewFire
    BEQ NoFireReseed
    JSR FireReseed
NoFireReseed:

; -----------------------------------------------------------------------------
; 3. JOYSTICK UP/DOWN — nudge the seed by one, but never to zero
; -----------------------------------------------------------------------------
; SWCHA is active low: 0 means the direction is pressed.  Bit 4 is P0 up and
; bit 5 is P0 down.  The code runs every VBLANK, so a held direction moves the
; seed once per frame (60 times a second), not once per press.  A result of
; zero is replaced by $FF; that keeps the LFSR out of its fixed point and
; makes the wrap visible as a full meter.
    LDA SWCHA
    AND #$10                ; P0 up
    BNE JoyUpDone
    INC RandomSeed
    BNE JoyUpDone           ; $FF + 1 = $00: use $FF instead
    LDA #$FF
    STA RandomSeed
JoyUpDone:

    LDA SWCHA
    AND #$20                ; P0 down
    BNE JoyDownDone
    DEC RandomSeed
    BNE JoyDownDone         ; $01 - 1 = $00: use $FF instead
    LDA #$FF
    STA RandomSeed
JoyDownDone:

; -----------------------------------------------------------------------------
; 4. THE LFSR STEP — every fourth frame
; -----------------------------------------------------------------------------
; The low two bits of FrameLo count 0..3; the branch skips the step while they
; are nonzero.  FrameLo is incremented at the top of VBLANK, so the first step
; is on frame 4.  RandomPush moves the new seed into the history grid, and
; RandomMask selects bit 0 for the beep.
    LDA FrameLo
    AND #(RANDOM_FRAMES - 1)
    BNE NoRandomStep
    JSR Random
RandomStep:                 ; checkpoint: A = the new seed
    JSR RandomPush
    LDA #$01
    JSR RandomMask
    BEQ NoRandomBeep
    LDA #BEEP_PITCH
    STA BeepPitch
    JSR BeepStart
NoRandomBeep:
NoRandomStep:

; -----------------------------------------------------------------------------
; 5. THE METER'S COUNT, COMPUTED ONCE PER FRAME
; -----------------------------------------------------------------------------
; The high nibble is the meter's value.  Computing it here, in VBLANK, keeps
; the kernel's first meter line short: MeterFirst's PF1 store lands at cycles
; 14-16 of visible line 40, before PF1's first slot.  With the four LSRs and
; the setup inside the kernel, that first store would land at cycle ~30,
; after the slot, and line 40 would still show the last grid row.
    LDA RandomSeed
    LSR
    LSR
    LSR
    LSR                     ; A = RandomSeed >> 4 (0-15)
    STA MeterCount
; Cell 14 is the first meter cell (the top one).  It is lit only when the
; count is 15; precomputing its PF1 byte lets the kernel write it before the
; first meter line's playfield slot.
    LDA #$00
    STA MeterFirst
    LDA MeterCount
    CMP #15
    BNE MeterFirstDone
    LDA #METER_CHUNK
    STA MeterFirst
MeterFirstDone:

; -----------------------------------------------------------------------------
; 6. COLORS, CONTROL, AND THE FIRST LINE'S PRELOAD
; -----------------------------------------------------------------------------
; The seed row and the history grid are gold; the meter is green.  PF0 and
; PF2 stay zero, so only PF1's chunks 4-11 (and their mirror copies) are lit.
; The seed is stored in PF1 here as well as at BodyStart.  The kernel's first
; write lands at cycles 8-11 of visible line 0, well before PF1's first slot,
; so the preload is belt-and-braces rather than a necessity.
    LDA #C_GOLD
    STA COLUPF
    LDA #C_BG
    STA COLUBK
    LDA #$01
    STA CTRLPF              ; mirror the playfield; ball one pixel wide
    LDA #$00
    STA PF0
    STA PF2
    LDA RandomSeed
    STA PF1

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- visible 0-7: the seed row ---------------------------------------------
; PF1 = RandomSeed for eight lines.  The preload above already put the byte
; in PF1; the reload here makes the loop's A explicit.
    LDA RandomSeed
    STA PF1
    LDY #8
SeedRow:
    STA WSYNC
    DEY
    BNE SeedRow

; --- visible 8-39: the history grid, 8 rows x 4 lines ----------------------
; Row 0 is the newest seed.  Each row is one PF1 byte held for four lines,
; so a lit cell is a 4-pixel-wide, 4-line-tall block.
    LDX #0
GridRow:
    LDA RandomHistory,X
    STA PF1
    LDY #4
GridLine:
    STA WSYNC
    DEY
    BNE GridLine
    INX
    CPX #8
    BNE GridRow

; --- visible 40-129: the meter, 15 cells x 6 lines -------------------------
; MeterCount and MeterFirst were computed in VBLANK.  The first store below
; puts cell 14's byte in PF1 at cycles 14-16 of visible line 40, before the
; playfield's first PF1 slot; the loop's first iteration rewrites the same
; byte.  The loop then walks cell 14 down to cell 0; a cell is lit when its
; index is below the count, so the bar grows from the bottom.  A lit cell
; writes PF1=$20 (chunk 6, X=24).
    LDA MeterFirst
    STA PF1
    LDA #C_GREEN
    STA COLUPF
    LDX #METER_CELLS        ; X = 15; the first DEX makes it cell 14
MeterCell:
    DEX
    CPX MeterCount
    LDA #$00
    BCS MeterDark           ; X >= count: this cell is dark
    LDA #METER_CHUNK        ; chunk 6: X=24-27
MeterDark:
    STA PF1
    LDY #METER_LINES
MeterLine:
    STA WSYNC
    DEY
    BNE MeterLine
    TXA
    BNE MeterCell
    ; the last cell (X=0) ends here; its six lines are lines 124-129

; --- visible 130-191: background ------------------------------------------
    LDA #$00
    STA PF1
    LDY #62
RestZone:
    STA WSYNC
    DEY
    BNE RestZone
    JMP FrameEnd

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
FrameEnd:
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; FireReseed — one fresh seed from the two frame-counter bytes
; =============================================================================
; The EOR mixes the fast and slow bytes: FrameHi changes only every 256
; frames, so the XOR still gives a different byte for presses 256 frames
; apart.  RandomInit replaces a zero result with $5A, because a zero seed
; would freeze the LFSR.
FireReseed:
    LDA FrameLo
    EOR FrameHi             ; two frame bytes -> one fresh seed byte
    JSR RandomInit
SeedWrite:                  ; checkpoint: A = the seed actually stored
    RTS

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
; Called when the new seed's bit 0 is one.  AUDC 0C is the div-6 tone from
; Lesson 35; AUDV 0A is audible but not loud.  The timer silences the channel
; two frames later, so consecutive steps produce a short tick.
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
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

> The complete, fully-commented lesson source lives in
> `lessons/part6-game-dev/43-random-numbers/43-random-numbers.asm`. The shared library lives in
> `include/random.asm`.

### Code Walkthrough

#### Step 1 — The library's map and API

`include/random.asm` owns `$A0–$A8`. `RandomSeed` is the single state byte; `RandomHistory`
is the eight-byte history, newest at `+0`. The public routines are `RandomInit`, `Random`,
`RandomMask`, and `RandomPush`. The library has no hidden persistent state beyond those nine
bytes, and `+clean_start` zeroes all of them.

Only the seed-accepting paths guard zero. `RandomInit` substitutes `$5A`; the lesson's joystick
path substitutes `$FF`; the 16-bit exercise substitutes `$5A` when both bytes are zero.
`Random`, `RandomMask`, and `RandomPush` do not test the seed — they trust the caller. That is
the usual split for a small library: the cheap inner loop stays cheap, and the entry points
that accept outside values do the guard.

#### Step 2 — Reset: a nonzero seed and a beep pitch

`+clean_start` zeroes TIA and RAM and sets the stack. `SWACNT=0` makes port A an input port
for the joysticks. `RandomInit` stores `$5A` in `RandomSeed`; `BeepPitch` starts at `$04`.

`Reset` is not the first byte of the cartridge: the library is assembled first at `$F000` and
`Reset` follows it. The RESET vector at `$FFFC` points at `Reset`, so the CPU starts in the
right place. Putting the library first is what lets the lesson's kernel use `RandomSeed` and
`RandomHistory` without forward-declaring them; ACME needs a zero-page symbol to be defined
before its first use to choose the two-byte addressing mode.

#### Step 3 — VBLANK: five decisions before the picture

The VBLANK block runs in a fixed order:

1. **Frame counters.** `INC FrameLo`; when it wraps, `INC FrameHi`. The low byte also gates the
   LFSR step (its low two bits), so the step lands on frames 4, 8, 12, …
2. **Beep clock.** `BeepTimer` counts down; at zero, `AUDV0=0`.
3. **Fire.** `INPT4` bit 7 is 0 while pressed; the EOR turns that into 1, and the EOR/AND pair
   keeps only the 0→1 edge. On the edge, `FireReseed` computes `FrameLo EOR FrameHi` and calls
   `RandomInit`. `SeedWrite` marks the store inside that routine, so the breakpoint fires only
   on a press, not on every frame.
4. **Joystick.** `SWCHA` bits 4 (up) and 5 (down) are active low. Up increments the seed, down
   decrements it; a result of zero becomes `$FF`.
5. **The step.** On a frame whose `FrameLo & 3` is zero, `Random` takes one Galois step,
   `RandomPush` moves the new seed into the history, and `RandomMask` with `$01` decides the
   beep. `RandomStep`, `RandomPush`, and `RandomMaskDone` are the three checkpoints.

The VBLANK work is short. The RIOT timer still has time left when the block ends, so
`+wait_timer` waits out the rest of the 37 lines and anchors the visible section at scanline 37.

#### Step 4 — The step, the push, and the beep

The step is five instructions:

```asm
    LDA RandomSeed
    ASL
    BCC RandomNoEor
    EOR #$1D
RandomNoEor:
    STA RandomSeed
```

The `ASL` is the shift and the carry test in one instruction. The `EOR` runs only when a one
falls off the top. `Random` returns with A = the new seed, so the caller can test it without
reloading:

```asm
    JSR Random
RandomStep:                 ; checkpoint: A = the new seed
    JSR RandomPush
    LDA #$01
    JSR RandomMask
    BEQ NoRandomBeep
```

`RandomPush` shifts the history and stores the new seed at `+0`; its entry is the
`RandomPush` checkpoint (A = the new seed). `RandomMask` with `$01` returns `seed AND 1`; the
`BEQ` skips the beep when bit 0 is clear. `RandomMaskDone` is the checkpoint after the `AND`.

The beep itself is the two-byte pattern from the earlier lessons: `BeepTimer=2`, `AUDC0=$0C`,
`AUDF0=$04`, `AUDV0=$0A`. Two frames later the VBLANK clock silences the channel. Because the
step is every four frames, a set bit 0 produces a short tick, not a tone.

#### Step 5 — The four visible zones

`BodyStart` is at scanline 37, visible line 0. The kernel is work-first: write `PF1`, then
`STA WSYNC`. The seed row holds `PF1 = RandomSeed` for eight lines. The grid then runs eight
rows of four lines each; each row loads `RandomHistory,X`, stores it in `PF1`, and waits four
lines. Row 0 is the newest seed. The meter runs fifteen cells of six lines; VBLANK has already
computed `MeterCount = RandomSeed >> 4` and the first cell's `MeterFirst`, and each cell
compares its index with the count and writes either `$00` (dark) or `$20` (chunk 6, X=24).
The background writes `PF1=0` for 62 lines.

The line counts are 8 + 32 + 90 + 62 = 192. The first line of each zone is the critical one:
the zone's `PF1` write happens at cycles 0–11 of that line, inside HBLANK, so the whole line
shows the new byte. The VBLANK block preloads the seed into `PF1` as well; the `BodyStart`
write would already be in time, so the preload is belt-and-braces rather than a necessity.

There is no sprite and no `HMOVE` in this ROM. The playfield's mirror is `CTRLPF` bit 0, not a
horizontal-motion register. That is why this lesson has no `HmoveApply`/`HmoveDone`
checkpoints; the exercise-2 solution adds a ball and therefore adds the one `HMOVE` that the
ball needs.

#### Step 6 — The meter's arithmetic

The meter is the one part of the display that computes instead of copying a byte. The
computation happens in VBLANK, and the reason is a one-line timing trap:

```asm
; VBLANK: the high nibble and the first cell's byte
    LDA RandomSeed
    LSR
    LSR
    LSR
    LSR                     ; A = RandomSeed >> 4 (0-15)
    STA MeterCount
    LDA #$00
    STA MeterFirst
    LDA MeterCount
    CMP #15
    BNE MeterFirstDone
    LDA #METER_CHUNK        ; cell 14 is lit only when the count is 15
    STA MeterFirst
MeterFirstDone:

; visible line 40: the first meter cell's byte, before the playfield slot
    LDA MeterFirst
    STA PF1
    LDA #C_GREEN
    STA COLUPF
    LDX #METER_CELLS        ; X = 15; the first DEX makes it cell 14
MeterCell:
    DEX
    CPX MeterCount
    LDA #$00
    BCS MeterDark           ; X >= count: this cell is dark
    LDA #METER_CHUNK        ; chunk 6: X=24-27
MeterDark:
    STA PF1
    LDY #METER_LINES
MeterLine:
    STA WSYNC
    DEY
    BNE MeterLine
    TXA
    BNE MeterCell
```

Four `LSR`s divide by 16. The loop walks cell 14 down to cell 0; `CPX MeterCount` sets the
carry when X is greater than or equal to the count, and `BCS` sends that cell to the dark path.
A cell with an index below the count is lit, so the bar grows from the bottom. `MeterCount` is
lesson RAM at `$86`; `MeterFirst` is `$87`.

Why is the nibble computed in VBLANK instead of at the top of the meter zone? Because the
kernel's first `STA PF1` must land before PF1's first slot on visible line 40, around CPU cycle
28. If the four `LSR`s and the `STA MeterCount` sat in the kernel, the grid-loop exit, the color
change, and the setup would add about 30 cycles before that first store — after the slot. Line
40 would keep the last grid row's `PF1`, and the top of the meter would show a one-line gold
ghost. Precomputing `MeterFirst` in VBLANK lets the kernel write it at
cycles 14–16, and the loop's first iteration rewrites the same byte. This is the kind of bug a
pixel check catches and a casual read does not; the fix is one byte of RAM.

The last cell is X=0: after its six `STA WSYNC`s the `TXA` is zero, `BNE` falls through, and
the background zone starts at visible line 130. The 90 meter lines are exactly 15 × 6.

#### Step 7 — Reading it back

```bash
acme -f plain -l build/lesson43.sym -o build/lesson43.bin \
  lessons/part6-game-dev/43-random-numbers/43-random-numbers.asm
grep -E "StartFrame|VblankStart|FireRead|SeedWrite|RandomStep|RandomPush|RandomMask|BodyStart|OverscanStart" build/lesson43.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -logtoconsole 1 \
  -break '$F0AD' docs/public/roms/part6-game-dev/43-random-numbers/43-random-numbers.bin
```

Stella keeps one `-break` per run (the last one on the command line), so run one checkpoint at a
time. `-dbg.logtrace 0` is worth keeping: without it, `-dbg.logbreaks` also logs every executed
instruction, and the breakpoint lines drown in a hundred thousand trace lines. `-dbg.logbreaks`
continues after a break, which is what makes a sequence of 60 `RandomStep` hits readable.

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F040` | **259, cycle 3** | the first VSYNC line |
| `VblankStart` | `$F04E` | 0, cycle 5 | the first VBLANK line |
| `FireRead` | `$F06B` | A=`$8C` released; A=`$0C` pressed | `INPT4`; bit 7 is the button |
| `SeedWrite` | `$F159` | A=`$B5` at frame 181; `$FE` at 254; `$98` at 409; `$CB` at 458 | the fire reseed, `FrameLo EOR FrameHi` |
| `RandomStep` | `$F0AD` | A=`$B4` at 4; `$75` at 8; `$EA` at 12; `$C9` at 16 | the new seed |
| `RandomPush` | `$F016` | A = the new seed | the byte pushed into history |
| `RandomMask` | `$F013` | A=`$01` | the mask passed to the routine |
| `RandomMaskDone` | `$F015` | A = seed AND `$01` | the beep bit |
| `BodyStart` | `$F0F5` | **37, cycle 5** | visible line 0 |
| `OverscanStart` | `$F13F` | **229, cycle 7** | overscan's first line |

The two RAM bytes to watch are `RandomSeed` at `$A0` and `RandomHistory` at `$A1–$A8`. The
seed is the byte the display calls "now"; the history is the eight bytes the grid draws.
`FrameLo` is `$80` and `FrameHi` is `$81`; the 16-bit frame counter is what a fire press folds
into a seed.

## What You Should See

The screen is a dark `$02` field with three gold/green displays. The **seed row** is visible
lines 0–7: eight 4-pixel cells at TIA X=16–47, and the mirror copy at X=112–143. `PF1` bit 7 is
the leftmost cell, so the row reads left to right as bit 7 … bit 0. The **history grid** is
visible lines 8–39: eight rows of four lines, each row one `RandomHistory` byte, row 0 the
newest seed at the top. The **meter** is visible lines 40–129: fifteen cells of six lines at
TIA X=24–27, mirrored at X=132–135, lit from the bottom; the number of lit cells is
`RandomSeed >> 4` (0–15). The middle of the screen stays background because only `PF1`'s
chunks 4–11 are lit.

**Capture A.** The seed row reads `$6D`, so the meter has six lit cells (`$6D >> 4 = 6`). The
grid rows, top to bottom, are `6D B8 5C 2E 17 85 CC 66`: each row is one LFSR step ahead of
the row below, which is exactly what eight consecutive LFSR steps look like.

![Stella running the Lesson 43 ROM at seed 6D: an eight-cell gold seed row, an eight-row gold history grid, and a six-cell green meter at the left, mirrored on the right](/images/lesson43/random-a.png)

*Seed `$6D`: six meter cells, and a history grid whose bottom row `$66` steps up through
`$CC`, `$85`, `$17`, `$2E`, `$5C`, `$B8` to the newest `$6D`.*

**Capture B.** A later moment shows seed `$32`: the meter has three lit cells, and the grid is
`32 19 82 41 AE 57 A5 DC`. The two pictures differ in every display — the seed row, all eight
grid rows, and the meter height — because the two captures are four seconds apart and the LFSR
has stepped many times in between.

![Stella running the Lesson 43 ROM at seed 32: a different gold seed row and history grid, and a three-cell green meter at the left, mirrored on the right](/images/lesson43/random-b.png)

*Seed `$32`: three meter cells, and a different eight-row history: `DC` is the oldest, `32`
the newest.*

> **Capture method.** Both images are window captures of the committed ROM in Stella 7.0, from
> `docs/public/roms/part6-game-dev/43-random-numbers/43-random-numbers.bin`, with the pointer
> parked at (0,0) and no game pixel altered. The title bar reads
> `Stella 7.0: "43-random-numbers"`. The ROM was allowed to run for 8 s and 12 s before the two captures, so
> the history grid is full and the two seeds differ. The seeds and grids in the captions are
> decoded from the captured pixels, not copied from a log.

<RomPlayer rom="/roms/part6-game-dev/43-random-numbers/43-random-numbers.bin" title="Lesson 43 — Random Numbers" />

Click the player screen once: Javatari starts muted until a user gesture. The ROM runs its
auto-demo without input, so the seed row, grid, and meter move on their own. Press fire to
reseed from the frame counters; push the joystick up or down to nudge the seed by one. The
exercise solutions are separate ROMs: the first changes the generator to 16 bits, the second
adds a gold ball, and the third adds SELECT.

The debugger tells the same story as numbers:

- **`$F06B` (`FireRead`)**: A=`$8C` while fire is released; A=`$0C` while it is held (bit 7 =
  0). The reseed uses the 0→1 edge, so holding the button does not reseed every frame.
- **`$F159` (`SeedWrite`)**: A=`$B5` at frame 181 and `$FE` at 254, where `FrameHi` is still 0,
  so the byte is `FrameLo`; A=`$98` at frame 409 (`FrameLo` = 153 = `$99`, `FrameHi` = 1, and
  `$99 EOR $01` = `$98`) and `$CB` at 458 (`FrameLo` = 202 = `$CA`, `FrameHi` = 1, and
  `$CA EOR $01` = `$CB`). This is the whole fire-seed formula, observed.
- **`$F0AD` (`RandomStep`)**: A=`$B4` at frame 4, `$75` at 8, `$EA` at 12, `$C9` at 16, `$8F`
  at 20, `$03` at 24. The sequence matches the table in Section 2.
- **`$F016` (`RandomPush`)**: A = the same new seed, because the push happens immediately after
  the step. **`$F013` (`RandomMask`)** reports A=`$01` (the mask); **`$F015`
  (`RandomMaskDone`)** reports A=`seed AND $01`, the beep condition.
- **`$F0F5` (`BodyStart`)** 37/5 and **`$F13F` (`OverscanStart`)** 229/7 — the 262-line frame.
- There is no `HMOVE` checkpoint in this ROM: the display is playfield-only. The exercise-2
  solution adds a ball and therefore has `HmoveApply`/`HmoveDone` around its single `HMOVE`.

With the debugger open on a visible frame, `RandomSeed` is `$A0`, `RandomHistory` is `$A1–$A8`,
`FrameLo` is `$80`, `FrameHi` is `$81`, `BeepTimer` is `$84`, `BeepPitch` is `$85`, `MeterCount` is `$86`, and
`MeterFirst` is `$87`. The seed row and grid are drawn from `RandomSeed` and `RandomHistory`
directly; there is no display buffer to inspect because the kernel reads the bytes every frame.

## Exercises

### Exercise 1: A 16-Bit LFSR

**Challenge:** extend the generator's state to two bytes. Shift the low byte left, rotate the
high byte through the carry, and when the high byte's old bit 7 falls off, XOR `$2D` into the
low byte. The seed row and the history grid still use the **low** byte; the meter still shows
the low byte's high nibble. The period must grow from 255 to 65,535.

**Hints:**
1. Put the high byte at `$A9`, the first free byte after the library's `RandomHistory`. The
   library's `RandomSeed` at `$A0` stays the low byte, so `RandomPush` and `RandomMask` work
   unchanged.
2. The carry chain is the whole trick: `ASL` on the low byte sets the carry, `STA` does not
   disturb it, and `ROL` on the high byte shifts that carry in and puts the high byte's old
   bit 7 in the carry. The `BCC` then decides whether `EOR #$2D` runs on the low byte.
3. Reload the low byte before `RTS` so `RandomStep` reports it. If you branch straight to the
   return when there is no feedback, A still holds the shifted **high** byte.
4. The low byte can read `$00` while the 16-bit state is nonzero. That is not the zero lock:
   the high byte keeps the register alive. The first run shows `B4 68 D0 A0 40 80 00 00 00 2D
   5A 99 …` — three zero low bytes in a row before the next feedback step.
5. The all-zero 16-bit state is still the fixed point. The fire reseed replaces a zero pair
   with `$5A/$00`.

**Expected Result:** `RandomStep` reports the low bytes `B4`, `68`, `D0`, `A0`, `40`, `80`,
`00`, `00`, `00`, `2D`, `5A`, `99`, … A host-side model of the same `ASL`/`ROL`/`BCC`/`EOR
$2D` transitions has period 65,535: it visits every nonzero 16-bit value exactly once. The grid
still shows the low byte, so a row of `00` cells is a valid state, not a dead generator.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: The Random Ball

**Challenge:** use `RandomMask` with the mask `$07` to place an 8-pixel ball at one of eight
columns: TIA X = 24 + 16 × (seed AND 7). The ball is eight lines tall on visible lines 150–157;
the seed row, history grid, and meter stay as they are.

**Hints:**
1. `RandomMask` returns `seed AND 7`. The checkpoint after the call (`BallMask`) reports 0–7.
2. Four `ASL`s multiply the column by 16; `ADC #24` adds the left margin. The eight columns are
   24, 40, 56, 72, 88, 104, 120, and 136; an 8-pixel ball at 136 spans 136–143, inside the
   160-pixel screen.
3. `CTRLPF` bits 4–5 select the ball width: `%11` is 8 pixels, so `CTRLPF=$31` keeps the
   mirror bit (bit 0) and sets the width.
4. Position the ball with `RESBL`/`HMBL` and one `HMOVE`. The ball's output delay is one clock
   shorter than a player's, so the target gets `POS_BIAS + 1` (4); the measured left edge then
   lands on the requested X. `SetCoarseBL` is the divide-by-15 routine from Lesson 26/39.
5. `ENABL=2` on visible line 150 turns the ball on; clearing it at line 158 ends the eight rows.

**Expected Result:** `RandomMask` enters with A=`$07` and `BallMask` reports A = `seed AND 7`.
With seed `$B6`, `$B6 AND 7 = 6`, so the ball's left edge is 24 + 96 = 120; the captured ball
is exactly eight pixels wide, from X=120 to 127, on visible lines 150–157. The seed byte is
the column selector, not the X: with seed `$88` the low three bits are 0, so the left edge is
24, never 88. A different seed moves the ball to a different column on the next frame.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Seed from SELECT *(Stretch Goal)*

**Challenge:** add a second reseed source. Pressing SELECT adds the two frame-counter bytes to
the current seed (`RandomSeed + FrameLo + FrameHi + carry`); fire keeps the main ROM's reseed
(`FrameLo EOR FrameHi`). Two SELECT presses at different frames must produce different
`SelectSeedWrite` values.

**Hints:**
1. `SWCHB` bit 1 is 0 while SELECT is pressed. It is the same active-low convention as
   `INPT4` bit 7 and `SWCHA`.
2. SELECT is a level, not an event. Convert the bit to 1 = pressed, then keep only the 0→1
   edge with the same EOR/AND pair the fire path uses.
3. The addition is `LDA RandomSeed; CLC; ADC FrameLo; ADC FrameHi`. The second `ADC` adds
   `FrameHi` **plus the carry from the first**, so the stored byte is
   `(seed + FrameLo + FrameHi + carry) AND $FF`. The carry is part of the formula, not noise.
4. Pass the result to `RandomInit` so a zero sum becomes `$5A`. Use a separate checkpoint
   (`SelectSeedWrite`) inside the SELECT path; a label at the merge point would fire every
   frame and prove nothing.
5. Do not change the fire path. The exercise is about adding a source, not replacing one.

**Expected Result:** Two presses at different frames give different `SelectSeedWrite` values.
In the first measured run the press is seen in ROM frame 174 and reports `$8D`: the seed before
the add is `$DE` (43 LFSR steps), `$DE + $AE = $18C`, the low byte is `$8C`, and the carry from
the first `ADC` is added by the second, so the stored byte is `$8D`. In a second run the press
is seen in ROM frame 302 and reports `$A0`: the seed is `$71` (75 steps), `FrameLo = $2E`,
`FrameHi = $01`, so `$71 + $2E + $01 = $A0`. Fire still reports `$B5` at frame 181 and `$FE` at
254, because its `FrameLo EOR FrameHi` path is untouched. The values are read at the
`SelectSeedWrite` checkpoint; SELECT was pressed through Stella's Command Menu → Select (the
console-switch button), not with a keyboard key.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **An LFSR is a shift plus conditional feedback**: `ASL` moves bit 7 into the carry; a set
  carry runs `EOR #$1D`; the byte stays eight bits wide. The `$1D` polynomial visits all 255
  nonzero bytes before repeating.
- ✅ **Zero is the fixed point**: `0 → 0` forever. `RandomInit` stores `$5A` for a zero seed and
  the joystick stores `$FF` for a zero result; the inner `Random` loop trusts its caller.
- ✅ **The Galois step is cheap**: 11 cycles when the branch is taken, 12 when the `EOR` runs,
  plus the 12-cycle call overhead. That fits in VBLANK even at one step every four frames.
- ✅ **Mask, don't divide**: the 6502 has no modulo instruction; `RandomMask` is one `AND`.
  `$01` is the beep bit, `$07` is the eight ball columns, and a mask is as even as the 255-state
  cycle allows.
- ✅ **A history makes the sequence visible**: `RandomPush` shifts the eight-byte history and
  stores the new seed at `+0`; the grid draws row 0 as the newest seed and four lines per row.
- ✅ **The layout is 8 + 32 + 90 + 62 = 192 lines**: a `PF1` seed row, an 8×8 grid, a 15-cell
  meter, and background, all mirrored by `CTRLPF=$01`. This ROM is playfield-only, so it needs
  no `HMOVE`.
- ✅ **Seed from input and time**: fire mixes `FrameLo EOR FrameHi`, the joystick nudges ±1
  every frame while held with a zero guard, and SELECT (exercise 3) adds the frame counters
  (plus the first `ADC`'s carry) to the current state.

## What's Next

The generator now gives the game a source of surprise: a byte that changes on its own, a
visible history, and a meter of its high nibble. The next lesson turns that byte into an
opponent. [Lesson 44: AI & Enemy Behavior — Chase, Patrol, Flee](/part6-game-dev/44-ai-enemy-behavior)
gives the enemy a patrol path, a chase trigger based on horizontal distance, a flee state with
hysteresis, and a state color the player can read at a glance.
