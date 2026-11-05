---
title: "Lesson 38: Collision Detection — When Things Touch"
description: "The TIA's collision registers are eight read-only bytes with two meaningful bits each. Lesson 38 builds the collision lab: four bands reporting four object pairs, a player that moves in both axes, a sweeping enemy, a ball, a missile, and a 15-chunk hit bar — plus the edge detection and CXCLR discipline that turn a latch into a game event."
prev:
  text: "Lesson 37: Advanced Audio"
  link: "/part5-sound/37-advanced-audio"
next:
  text: "Lesson 39: The Scoreboard"
  link: "/part6-game-dev/39-scoreboard"
---

# Lesson 38: Collision Detection — When Things Touch

> **Part 6: Game Development** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 12 (the NTSC frame), Lesson 17 (cycle counting), Lesson 18 (mid-line TIA writes), Lesson 26 (`SetHorizPos` and one `HMOVE`), Lesson 27 (joystick movement), Lesson 28 (the one-`HMOVE` rule), Lessons 29 and 31 (missiles, the ball, and `NUSIZ`), Lesson 33 (`INPT4` and the fire button), Lesson 35 (the audio registers)
> **You will learn:** how the eight collision registers pair the TIA's objects; why a latch stays set until `CXCLR`; why a read in VBLANK describes the previous visible frame; how to turn a latch into a one-shot event with a 0→1 edge; how to draw a 15-chunk hit bar from a clamped count
> **You will build:** "the collision lab" — four 6-line bands for P0–P1, P0–ball, P0–playfield, and M0–P1; a joystick/auto-demo player, a sweeping enemy, a fixed ball, a missile, and a 15-chunk hit bar; plus three exercises: read the ball bit, add an enemy missile, and remove the clear to see sticky latches

## Introduction

Every game needs to know when two things touch. A modern engine gives you a physics engine, a
broad phase, bounding boxes, and callbacks. The Atari 2600 gives you eight bytes. Each byte holds
two bits, each bit names a pair of objects, and the bit sets when those two objects' **drawn
pixels** land on the same color clock. That is the whole system.

The eight registers are read-only, and they are **sticky**: once a bit sets, it stays set until
you write to `CXCLR` and clear every latch at once. There is no "collision ended" bit, no event
queue, and no object identifier — just eight latches that remember what happened since the last
clear. A game has to turn that memory into an event: read it, notice what is new, react once, and
clear it.

This lesson builds **the collision lab**. Four bands at the top of the screen report four pairs.
The play area holds player 0, player 1, the ball, missile 0, and a sixteen-pixel playfield wall
at each edge. A fifteen-chunk hit bar at the bottom counts new contacts. The screen is the
monitor for the registers, and the debugger checkpoints are the receipt.

::: details TypeScript Equivalent
A collision read is a poll of eight hardware latches, followed by an edge test. The TypeScript
version keeps the same shape: build a mask, compare it with the previous mask, count the bits
that changed from 0 to 1.

```typescript
type Registers = {
  CXM0P: number;   // bit 7 = M0-P1, bit 6 = M0-P0
  CXP0FB: number;  // bit 7 = P0-playfield, bit 6 = P0-ball
  CXPPMM: number;  // bit 7 = P0-P1, bit 6 = M0-M1
  CXCLR: number;   // write any value: clear every latch
};

const PAIRS = [
  { name: "P0-P1",        mask: 0x80, read: (r: Registers) => r.CXPPMM & 0x80 },
  { name: "P0-ball",      mask: 0x40, read: (r: Registers) => r.CXP0FB & 0x40 },
  { name: "P0-playfield", mask: 0x20, read: (r: Registers) => r.CXP0FB & 0x80 },
  { name: "M0-P1",        mask: 0x10, read: (r: Registers) => r.CXM0P & 0x80 },
];

const popcount = (n: number): number => {
  let count = 0;
  for (; n; n &= n - 1) count += 1;   // clear the lowest set bit each pass
  return count;
};

let previous = 0;
let hits = 0;

function vblank(registers: Registers): void {
  let mask = 0;
  for (const pair of PAIRS) {
    if (pair.read(registers)) mask |= pair.mask;
  }

  const newBits = mask & ~previous;             // 0 -> 1 edges only
  hits = Math.min(15, hits + popcount(newBits)); // the bar has 15 chunks
  if (newBits) beep();

  previous = mask;
  registers.CXCLR = 0;                          // clear AFTER reading
}
```

The analogy breaks in three places. There is no event callback: the program polls once per
frame, so a contact shorter than a frame is still visible only because the hardware latches it.
The latch is sticky: `mask` is the OR of every contact since the last `CXCLR`, not the contacts
of one instant. And the read happens in VBLANK, after the visible frame that produced it, so the
whole mask is one frame old.
:::

## Theory

### Section 1: Eight Bytes, Two Bits Each

The TIA exposes eight collision registers in the read half of `$00–$07`. Only bits 7 and 6 are
connected; the other six bits are not defined (Stella returns various values, so the lesson masks
them). The register name is the pair it reports:

| Register | Address | Bit 7 | Bit 6 |
|---|---|---|---|
| `CXM0P` | `$00` | M0–P1 | M0–P0 |
| `CXM1P` | `$01` | M1–P0 | M1–P1 |
| `CXP0FB` | `$02` | P0–playfield | P0–ball |
| `CXP1FB` | `$03` | P1–playfield | P1–ball |
| `CXM0FB` | `$04` | M0–playfield | M0–ball |
| `CXM1FB` | `$05` | M1–playfield | M1–ball |
| `CXBLPF` | `$06` | ball–playfield | — |
| `CXPPMM` | `$07` | P0–P1 | M0–M1 |

The bit sets when the two objects are **drawn on the same scanline and color clock**. The comparison is not
between `PlayerX` and `EnemyX`; it is between the pixels the TIA actually outputs. Two objects
whose position variables overlap but whose graphics bits are zero do not collide. This is the
first fact a game programmer has to internalize: the collision hardware is downstream of the
picture, not of the game logic.

::: tip Only bits 7 and 6
Read a collision register with `AND #$C0` before you test it. The other bits have no meaning.
In Stella this lesson's `CXP0FB` read returns `$02` with no contact and `$82` with a P0–playfield
contact; the `$02` is noise from the undefined bits, and the `$80` is the fact.
:::

### Section 2: Latches Stay Set Until `CXCLR`

A collision register is not a snapshot of the current frame. It is a latch with a set-only
input: while the objects are drawn on top of each other, the bit sets; when they separate, the
bit **stays** set. The only way to clear it is to write any value to `CXCLR` ($2C), which clears
all eight registers at once.

That design is deliberate. The program cannot watch every color clock, but the hardware can. The
latch remembers a contact that happened between two reads. The price is that the program must
clear the latches at a known point, or every collision the game has ever seen stays true forever.

```text
frame N visible area          VBLANK of frame N+1
objects touch  ─────────────► latch set ──► read ──► build mask ──► CXCLR
                                                            │
                                                            └──► the band on frame N+1
```

The read happens in VBLANK, after the visible area that produced it. The mask built from that
read is used to draw the **next** visible frame. So the bands are one frame behind the drawn
contact: the collision happened on frame N, the band shows it on frame N+1. This is not a bug in
the program; it is the shape of the hardware handshake.

### Section 3: The Four Pairs in This Lab

The lab watches four pairs. Each one gets a 6-line band at the top of the screen, and each band
uses its own color while the pair's mask bit is set:

| Band | Visible lines | Pair | Register | Bit | Color |
|---|---|---|---|---|---|
| 0 | 0–5 | P0–P1 | `CXPPMM` | 7 | red `$42` |
| 1 | 6–11 | P0–ball | `CXP0FB` | 6 | gold `$1A` |
| 2 | 12–17 | P0–playfield | `CXP0FB` | 7 | green `$C8` |
| 3 | 18–23 | M0–P1 | `CXM0P` | 7 | blue `$84` |

The bands are drawn with `COLUBK`, not the playfield. That matters: if the monitor were drawn
with the playfield, the bands themselves could create P0–playfield collisions and the
instrument would change the measurement.

The play area is where the objects live:

| Object | Rows | X | Y | Color | Notes |
|---|---|---|---|---|---|
| P0 | 16 | 8–144 | 40–156 | red `$42` | joystick, or the auto-demo |
| P1 | 16 | 40–136 | 40 | blue `$84` | sweeps one pixel per frame |
| ball | 8 | 80 | 100 | gold `$1A` | fixed; one pixel wide |
| M0 | 4 | P0's X at fire | climbs | red `$42` | shares `COLUP0` |
| wall | 148 | 0–15 and 144–159 | — | gold `$1A` | `PF0=$F0`, reflected |

P0 has to move in **both** axes because the latches only set on shared scanlines. P1 sits at
Y=40 and the ball at Y=100; a P0 that only moved left and right could never meet either. The
auto-demo therefore walks a rectangle — up the left wall, right along the top, down the right
edge, left along the bottom — one pixel every two frames. With no joystick input it also fires
M0 every 90 frames, so the M0–P1 band demonstrates itself; the joystick overrides P0's movement,
and fire launches the missile manually.

The wall and the ball share `COLUPF`; they are told apart by position and size. The wall is
sixteen pixels wide and 148 lines tall. The ball is one pixel wide and eight lines tall. The
playfield control is `$01`: bit 0 reflects the right half, so writing `PF0=$F0` puts a wall at
both edges.

### Section 4: From a Latch to a One-Shot Event

The mask is a byte with four interesting bits:

```text
bit 7  P0-P1
bit 6  P0-ball
bit 5  P0-playfield
bit 4  M0-P1
```

The mask lives in `LatchMask`; `PrevMask` holds last frame's copy. A contact is **new** when its
mask bit is 1 now and was 0 last frame:

```asm
    EOR PrevMask      ; bits that changed
    AND LatchMask     ; keep only the 0 -> 1 changes
    STA NewBits
```

The `CollMask` checkpoint marks the full-mask store (A = the whole mask); `CollStep` marks the
edge store (A = only the 0→1 bits). The log needs both: the full mask shows which pairs are in
contact, and the edge shows which one is new this frame.

Holding the fire button, or leaning on a wall for two hundred frames, produces one event, not
two hundred. The four mask bits sit in bits 7–4, so four `ASL`s shift each one into the carry in
turn; `INX` counts the carry sets. The count (0–4) is added to `HitCount`, clamped at 15 — the
bar has only fifteen chunks. A nonzero count also starts the beep: `AUDC0=$0C`, `AUDF0=$08`,
`AUDV0=$0A`, and a timer that writes `AUDV0=0` after eight frames.

Then `STA CXCLR`. Clearing after the read is the contract: the latches have done their job for
this frame, and the next visible frame starts from zero. Exercise 3 removes that store and
shows what happens when the contract is broken.

### Section 5: The Frame and the Kernel

The frame is the course standard: 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = **262
lines**. The picture is work-first: each line's registers are written, then `STA WSYNC` moves to
the next line. The first work line is scanline 37, the last is 228, and overscan starts at 229.

The 192 picture lines are budgeted exactly:

```text
 24  four collision bands (4 × 6)
148  play area
  6  hit bar
 14  bottom background
---
192
```

The play area is split into five zones. Each zone handles only the objects that can be present
there, which keeps every line inside 76 cycles and keeps P0's graphics write in HBLANK:

| Zone | Visible lines | Fixed object | Optional objects |
|---|---|---|---|
| A | 24–39 | — | M0 |
| B | 40–55 | P1 | P0, M0 |
| C | 56–99 | — | P0, M0 |
| D | 100–107 | ball | P0, M0 |
| E | 108–171 | — | P0, M0 |

The four movable objects are positioned once per frame. Each coarse routine strobes its `RESxx`
and leaves a fine value in its `HMPx`; a single `HMOVE` applies all four fine offsets in one
HBLANK. This is the one-`HMOVE` rule from Lessons 28 and 29 at four objects.

The hit bar is six lines at visible 172–177. Fifteen chunks per half, four pixels per chunk, is
fifteen playfield bits: `PF0` bits 4–7, `PF1` bits 7–0, and `PF2` bits 0–2 (bit 0 is leftmost,
because PF2's bit order is reversed). The table has sixteen
entries of three bytes. The VBLANK code indexes it once and stores `HitPF0/1/2`; the kernel writes
those three bytes in HBLANK, so the first bar line starts with the right chunks.

::: tip Why the ball needs one extra pixel
The players' `RESP` output delay is five color clocks; the missiles and the ball are one clock
shorter (Lesson 29). The `+3` bias that places a player also places the ball one pixel to the
left, so the ball's target is `BALL_X + 3 + 1`. The measured result is the authority: in the
committed ROM the ball's left pixel is at TIA X=80.

Lesson 38 re-measured the one-pixel ball: its committed capture is the authority for this ROM.
The two measured rows disagree (Lesson 29's ball row is the outlier), so Lesson 29 needs a
re-measure in its own commit; until then, trust this ROM's committed capture for this mapping.
The missiles use the same one-pixel correction, so M0 and M1 land on the player-style target
instead of one pixel left of it.
:::

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson38.bin \
  lessons/part6-game-dev/38-collision-detection/38-collision-detection.asm
stella build/lesson38.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 38: Collision Detection — When Things Touch — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; What this program does:
;   "The collision lab": four 6-line bands at the top of the screen report the
;   four collision pairs this lesson reads.  The play area holds player 0,
;   player 1, the ball, missile 0, and a 16-pixel wall at each edge.  A
;   15-chunk hit bar at the bottom counts new contacts.
;
; The collision registers (read-only; only bits 7 and 6 are defined):
;   CXM0P  ($00)  bit 7 = M0-P1,        bit 6 = M0-P0
;   CXM1P  ($01)  bit 7 = M1-P0,        bit 6 = M1-P1
;   CXP0FB ($02)  bit 7 = P0-playfield, bit 6 = P0-ball
;   CXP1FB ($03)  bit 7 = P1-playfield, bit 6 = P1-ball
;   CXM0FB ($04)  bit 7 = M0-playfield, bit 6 = M0-ball
;   CXM1FB ($05)  bit 7 = M1-playfield, bit 6 = M1-ball
;   CXBLPF ($06)  bit 7 = ball-playfield
;   CXPPMM ($07)  bit 7 = P0-P1,        bit 6 = M0-M1
;
;   A latch sets when the two objects' drawn pixels share both a scanline and
;   a color clock.  It stays set until CXCLR is strobed.  Collisions are
;   between drawn pixels, not between the position variables.
;
; The four bands (visible 0-23, six lines each):
;   band 0  P0-P1         CXPPMM bit 7   red   $42
;   band 1  P0-ball       CXP0FB bit 6   gold  $1A
;   band 2  P0-playfield  CXP0FB bit 7   green $C8
;   band 3  M0-P1         CXM0P  bit 7   blue  $84
;   The band shows its color while the mask bit is set; the other bands stay
;   at the $02 background.  The bands are drawn with COLUBK, so the monitor
;   itself never adds playfield pixels that could create a collision.
;
; The play area (visible 24-171, 148 lines):
;   P0     16 rows, red $42,  X 8-144, Y 40-156, joystick or auto-demo
;   P1     16 rows, blue $84, X 40-136, Y 40, auto-sweep
;   ball    8 rows, gold $1A, X 80, Y 100
;   M0      4 rows, red $42,  fires upward from P0's X (missile +1 bias)
;   wall    playfield PF0=$F0 (reflected), gold $1A, 16 px at each edge
;
; The hit bar (visible 172-177):
;   N chunks per half, N = HitCount (0-15), drawn by PF0/PF1/PF2, mirrored.
;
; Collision handling (every VBLANK):
;   read CXP0FB, CXPPMM, CXM0P -> build LatchMask
;   edge-detect against PrevMask; each new bit increments HitCount (clamp 15)
;   and starts the beep; then STA CXCLR.
;   The latches read in VBLANK describe the PREVIOUS visible frame: the mask
;   and the bands are one frame behind the drawn contact.
;
; Auto-demo:
;   With no joystick input P0 walks a rectangle (X 8..80, Y 40..156) one
;   pixel every two frames.  P1 sweeps X 40..136 one pixel per frame.  The
;   auto-demo also fires M0 every 90 frames, so the M0-P1 band demonstrates
;   itself; the joystick overrides P0's movement and fire launches M0
;   manually.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), ReadCX (A = CXP0FB),
;   CollMask (A = the full mask), CollStep (A = the 0->1 edge bits),
;   CXClear (the strobe), Hits (A = HitCount),
;   BodyStart (37), HmoveApply/HmoveDone (one per frame), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson38.bin \
;        lessons/part6-game-dev/38-collision-detection/38-collision-detection.asm
; Run:   stella build/lesson38.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

PLAY_TOP       = 24      ; first play-area line
PLAY_BOTTOM    = 172     ; first hit-bar line
P0_MIN_X       = 8
P0_MAX_X       = 144
P0_MIN_Y       = 40
P0_MAX_Y       = 156
P0_HEIGHT      = 16
AUTO_MAX_X     = 80      ; the auto-demo rectangle's right edge
ENEMY_Y        = 40      ; P1's fixed top row
ENEMY_MIN_X    = 40
ENEMY_MAX_X    = 136
BALL_X         = 80
BALL_Y         = 100
BALL_HEIGHT    = 8
M0_HEIGHT      = 4
MISSILE_OFF    = 220     ; a Y outside the play area: the missile is hidden
BEEP_FRAMES    = 8
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright hit

C_RED          = $42
C_GOLD         = $1A
C_GREEN        = $C8
C_BLUE         = $84
C_BG           = $02

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
PlayerX     = $80   ; P0's left edge, 8..144
PlayerY     = $81   ; P0's top row, 40..156
AutoPhase   = $82   ; 0 = up, 1 = right, 2 = down, 3 = left
AutoDiv     = $83   ; the auto-demo moves on every second frame
EnemyX      = $84   ; P1's left edge, 40..136
EnemyDir    = $85   ; 1 = right, 0 = left
MissileY    = $86   ; M0's top row; MISSILE_OFF hides it
MissileX    = $87   ; M0's left edge, set when it is fired
LatchMask    = $88   ; bit7 P0-P1, bit6 P0-ball, bit5 P0-PF, bit4 M0-P1
PrevMask    = $89   ; last frame's mask, for the 0->1 edge
NewBits     = $8A   ; the bits that changed from 0 to 1
HitCount    = $8B   ; new contacts, clamped at 15
BeepTimer   = $8C   ; frames of beep remaining
BeepPitch   = $8D   ; AUDF for the beep
FirePrev    = $8E   ; fire button state last frame
InputBits   = $8F   ; this frame's SWCHA read
BandColors  = $90   ; $90-$93: the four band colors
HitPF0      = $94   ; the hit bar's three playfield bytes
HitPF1      = $95
HitPF2      = $96
AutoFireTimer = $97 ; frames until the auto-demo fires M0 again

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the initial scene ---
    LDA #P0_MIN_X
    STA PlayerX             ; P0 starts inside the left wall
    LDA #140
    STA PlayerY
    LDA #0
    STA AutoPhase           ; climb to Y=40 first
    STA AutoDiv
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir            ; sweep right first
    LDA #MISSILE_OFF
    STA MissileY            ; no missile yet
    LDA #BEEP_PITCH
    STA BeepPitch

; --- the auto-demo's fire clock ---
    LDA #90
    STA AutoFireTimer

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; 1. THE BEEP'S CLOCK — one frame shorter every VBLANK
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0               ; the last frame of the beep: silence
BeepDone:

; -----------------------------------------------------------------------------
; 2. READ THE COLLISION LATCHES — the previous visible frame's contacts
; -----------------------------------------------------------------------------
; The TIA latches a pair while the two objects are drawn on the same color
; clock.  The read happens in the next VBLANK, so it describes frame N while
; the program is building frame N+1: one frame of latency, by construction.
    LDA CXP0FB              ; bit 7 = P0-playfield, bit 6 = P0-ball
ReadCX:                     ; checkpoint: A = CXP0FB
    AND #$40                ; keep the P0-ball bit in bit 6
    STA LatchMask
    LDA CXP0FB
    AND #$80                ; P0-playfield
    LSR
    LSR                     ; bit 7 -> bit 5
    ORA LatchMask
    STA LatchMask
    LDA CXPPMM              ; P0-P1 stays in bit 7
    AND #$80
    ORA LatchMask
    STA LatchMask
    LDA CXM0P               ; M0-P1
    AND #$80
    LSR
    LSR
    LSR                     ; bit 7 -> bit 4
    ORA LatchMask
    STA LatchMask
CollMask:                   ; checkpoint: A = the full mask

; --- 0->1 edges only: a contact that is still held is not a new hit ---
    EOR PrevMask
    AND LatchMask
    STA NewBits
CollStep:                   ; checkpoint: A = the 0->1 edge bits
    LDA LatchMask
    STA PrevMask

; --- count the new bits (0..4) and add them to Hits ---
; The four mask bits live in bits 7-4, so four ASLs shift each one into the
; carry in turn: bit 7 first, then 6, 5, and 4.
    LDA NewBits
    LDX #0
    LDY #4
CountBits:
    ASL
    BCC CountNext
    INX
CountNext:
    DEY
    BNE CountBits
    TXA
    BEQ NoNewHit
    CLC
    ADC HitCount
    CMP #16
    BCC StoreHits
    LDA #15                 ; the bar has only 15 chunks
StoreHits:
    STA HitCount
Hits:                       ; checkpoint: A = Hits after the increment
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C                ; AUDC 0C: the div-6 tone from Lesson 35
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0

; --- clear the latches after reading them: this frame starts from zero ---
NoNewHit:
    LDA #$00
    STA CXCLR
CXClear:                    ; checkpoint: the strobe has executed

; -----------------------------------------------------------------------------
; 3. THE FOUR BAND COLORS — $02 unless the pair's mask bit is set
; -----------------------------------------------------------------------------
    LDA #C_BG
    STA BandColors+0
    STA BandColors+1
    STA BandColors+2
    STA BandColors+3

    LDA LatchMask
    AND #$80                ; P0-P1
    BEQ NoBand0
    LDA #C_RED
    STA BandColors+0
NoBand0:
    LDA LatchMask
    AND #$40                ; P0-ball
    BEQ NoBand1
    LDA #C_GOLD
    STA BandColors+1
NoBand1:
    LDA LatchMask
    AND #$20                ; P0-playfield
    BEQ NoBand2
    LDA #C_GREEN
    STA BandColors+2
NoBand2:
    LDA LatchMask
    AND #$10                ; M0-P1
    BEQ NoBand3
    LDA #C_BLUE
    STA BandColors+3
NoBand3:

; -----------------------------------------------------------------------------
; 4. THE HIT BAR'S BYTES — computed now so the kernel can write them in HBLANK
; -----------------------------------------------------------------------------
    LDA HitCount
    ASL                     ; Hits * 3: three playfield bytes per entry
    CLC
    ADC HitCount
    TAX
    LDA HitBarPF,X
    STA HitPF0
    LDA HitBarPF+1,X
    STA HitPF1
    LDA HitBarPF+2,X
    STA HitPF2

; -----------------------------------------------------------------------------
; 5. P0'S MOTION — the joystick, or the automatic rectangle
; -----------------------------------------------------------------------------
    LDA SWCHA
    STA InputBits
    AND #$F0
    CMP #$F0                ; all four directions released?
    BEQ AutoDemo

; --- manual: one pixel per frame on each pressed axis, clamped ---
    LDA InputBits
    AND #$10                ; up
    BNE NoUp
    DEC PlayerY
    LDA PlayerY
    CMP #P0_MIN_Y
    BCS NoUp
    LDA #P0_MIN_Y
    STA PlayerY
NoUp:
    LDA InputBits
    AND #$20                ; down
    BNE NoDown
    INC PlayerY
    LDA PlayerY
    CMP #(P0_MAX_Y + 1)
    BCC NoDown
    LDA #P0_MAX_Y
    STA PlayerY
NoDown:
    LDA InputBits
    AND #$40                ; left
    BNE NoLeft
    DEC PlayerX
    LDA PlayerX
    CMP #P0_MIN_X
    BCS NoLeft
    LDA #P0_MIN_X
    STA PlayerX
NoLeft:
    LDA InputBits
    AND #$80                ; right
    BNE NoRight
    INC PlayerX
    LDA PlayerX
    CMP #(P0_MAX_X + 1)
    BCC NoRight
    LDA #P0_MAX_X
    STA PlayerX
NoRight:
    JMP MoveDone

; --- auto-demo: one pixel every two frames around the rectangle.
;     With no joystick input it also fires M0 every 90 frames, so the
;     M0-P1 band demonstrates itself. ---
AutoDemo:
    DEC AutoFireTimer
    BNE AutoFireDone
    LDA #90
    STA AutoFireTimer
    LDA PlayerY
    STA MissileY
    LDA PlayerX
    STA MissileX
AutoFireDone:
    INC AutoDiv
    LDA AutoDiv
    AND #$01
    BNE MoveDone
    LDA AutoPhase
    CMP #0
    BEQ AutoUp
    CMP #1
    BEQ AutoRight
    CMP #2
    BEQ AutoDown
    JMP AutoLeft

AutoUp:
    DEC PlayerY
    LDA PlayerY
    CMP #P0_MIN_Y
    BCS MoveDone
    LDA #P0_MIN_Y
    STA PlayerY
    LDA #1
    STA AutoPhase
    JMP MoveDone
AutoRight:
    INC PlayerX
    LDA PlayerX
    CMP #(AUTO_MAX_X + 1)
    BCC MoveDone
    LDA #AUTO_MAX_X
    STA PlayerX
    LDA #2
    STA AutoPhase
    JMP MoveDone
AutoDown:
    INC PlayerY
    LDA PlayerY
    CMP #157
    BCC MoveDone
    LDA #P0_MAX_Y
    STA PlayerY
    LDA #3
    STA AutoPhase
    JMP MoveDone
AutoLeft:
    DEC PlayerX
    LDA PlayerX
    CMP #P0_MIN_X
    BCS MoveDone
    LDA #P0_MIN_X
    STA PlayerX
    LDA #0
    STA AutoPhase
MoveDone:

; -----------------------------------------------------------------------------
; 6. P1'S SWEEP — 40..136, one pixel per frame
; -----------------------------------------------------------------------------
    LDA EnemyDir
    BNE EnemyRight
    DEC EnemyX
    LDA EnemyX
    CMP #ENEMY_MIN_X
    BCS EnemyDone
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir
    JMP EnemyDone
EnemyRight:
    INC EnemyX
    LDA EnemyX
    CMP #(ENEMY_MAX_X + 1)
    BCC EnemyDone
    LDA #ENEMY_MAX_X
    STA EnemyX
    LDA #0
    STA EnemyDir
EnemyDone:

; -----------------------------------------------------------------------------
; 7. FIRE — a new press launches M0 from P0's position
; -----------------------------------------------------------------------------
    LDA INPT4               ; bit 7: 0 = pressed
    AND #$80
    BNE FireReleased
    LDA FirePrev
    BNE FireHeld
    LDA PlayerY
    STA MissileY
    LDA PlayerX
    STA MissileX
FireHeld:
    LDA #1
    STA FirePrev
    JMP FireDone
FireReleased:
    LDA #0
    STA FirePrev
FireDone:

; --- the missile climbs two pixels per frame and resets at the top ---
    LDA MissileY
    CMP #MISSILE_OFF
    BEQ MissileDone
    SEC
    SBC #2
    CMP #PLAY_TOP
    BCS MissileStore
    LDA #MISSILE_OFF
MissileStore:
    STA MissileY
MissileDone:

; -----------------------------------------------------------------------------
; 8. POSITION ALL FOUR MOVABLE OBJECTS, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA EnemyX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
    LDA MissileX
    CLC
    ADC #(POS_BIAS + 1)     ; missiles have a 4-clock reset, one pixel left
    JSR SetCoarseM0
; The ball's output delay is one clock shorter than a player's (Lesson 29),
; so its target needs one extra pixel to land on BALL_X.
    LDA #(BALL_X + POS_BIAS + 1)
    JSR SetCoarseBL
    STA WSYNC
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed (next line, cycle 3)

; -----------------------------------------------------------------------------
; 9. COLORS, SIZES, AND THE WALL — the playfield is off during the bands
; -----------------------------------------------------------------------------
    LDA #C_RED
    STA COLUP0              ; P0 and M0 are both red
    LDA #C_BLUE
    STA COLUP1              ; P1 and M1 are both blue
    LDA #C_GOLD
    STA COLUPF              ; the wall, the ball, and the hit bar
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA NUSIZ0              ; P0 normal; M0 one pixel wide
    STA NUSIZ1              ; P1 normal; M1 one pixel wide
    STA ENAM1               ; M1 is not used in this ROM
    STA PF0                 ; the bands and the bottom are not playfield
    STA PF1
    STA PF2
    LDA #$01
    STA CTRLPF              ; reflect the playfield; ball one pixel wide

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: the first visible line (scanline 37)
; --- visible 0-23: four 6-line collision bands ---
    LDX #0
BandLoop:
    LDA BandColors,X
    STA COLUBK
    LDY #6
BandLines:
    STA WSYNC
    DEY
    BNE BandLines
    INX
    CPX #4
    BNE BandLoop

; --- visible 24: the wall goes on and the play area begins ---
    LDA #C_BG
    STA COLUBK
    LDA #$F0
    STA PF0                 ; PF0 bits 4-7: the 16-px left wall
    LDA #$00
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL

; --- visible 24-39: only M0 can be up here ---
    LDX #PLAY_TOP
ZoneA:
    TXA
    SEC
    SBC MissileY
    CMP #M0_HEIGHT
    LDA #$00
    BCS ZoneAM0Off
    LDA #$02
ZoneAM0Off:
    STA ENAM0
    STA WSYNC
    INX
    CPX #ENEMY_Y
    BNE ZoneA

; --- visible 40-55: P1 is always here; P0 and M0 may be ---
; P0's write comes first so it lands in HBLANK.  The GRP1 write is after it:
; P1 starts at X>=40, so a write at X~1 still reaches P1's pixels in time.
    LDX #ENEMY_Y
ZoneB:
    TXA
    SEC
    SBC PlayerY
    CMP #P0_HEIGHT
    LDA #$00
    BCS ZoneBP0Off
    LDA #$FF
ZoneBP0Off:
    STA GRP0
    LDA #$FF
    STA GRP1
    TXA
    SEC
    SBC MissileY
    CMP #M0_HEIGHT
    LDA #$00
    BCS ZoneBM0Off
    LDA #$02
ZoneBM0Off:
    STA ENAM0
    STA WSYNC
    INX
    CPX #(ENEMY_Y + P0_HEIGHT)
    BNE ZoneB
    LDA #$00
    STA GRP1

; --- visible 56-99: P0 and M0 ---
    LDX #56
ZoneC:
    TXA
    SEC
    SBC PlayerY
    CMP #P0_HEIGHT
    LDA #$00
    BCS ZoneCP0Off
    LDA #$FF
ZoneCP0Off:
    STA GRP0
    TXA
    SEC
    SBC MissileY
    CMP #M0_HEIGHT
    LDA #$00
    BCS ZoneCM0Off
    LDA #$02
ZoneCM0Off:
    STA ENAM0
    STA WSYNC
    INX
    CPX #BALL_Y
    BNE ZoneC

; --- visible 100-107: the ball sits here; P0 and M0 may pass ---
; As in zone B, P0's write goes first; ENABL is written after it, at X~1,
; well before the ball's X=80.
    LDX #BALL_Y
ZoneD:
    TXA
    SEC
    SBC PlayerY
    CMP #P0_HEIGHT
    LDA #$00
    BCS ZoneDP0Off
    LDA #$FF
ZoneDP0Off:
    STA GRP0
    LDA #$02
    STA ENABL
    TXA
    SEC
    SBC MissileY
    CMP #M0_HEIGHT
    LDA #$00
    BCS ZoneDM0Off
    LDA #$02
ZoneDM0Off:
    STA ENAM0
    STA WSYNC
    INX
    CPX #(BALL_Y + BALL_HEIGHT)
    BNE ZoneD
    LDA #$00
    STA ENABL

; --- visible 108-171: P0 and M0 ---
    LDX #108
ZoneE:
    TXA
    SEC
    SBC PlayerY
    CMP #P0_HEIGHT
    LDA #$00
    BCS ZoneEP0Off
    LDA #$FF
ZoneEP0Off:
    STA GRP0
    TXA
    SEC
    SBC MissileY
    CMP #M0_HEIGHT
    LDA #$00
    BCS ZoneEM0Off
    LDA #$02
ZoneEM0Off:
    STA ENAM0
    STA WSYNC
    INX
    CPX #(PLAY_BOTTOM - 1)
    BNE ZoneE

; --- line 171: the last play-area line.  Draw its P0/M0 work, preload the
;     hit-bar bytes in Y/A/X, then store them in line 172's HBLANK together
;     with the clears that stop P0 and the missile at row 171. ---
    TXA
    SEC
    SBC PlayerY
    CMP #P0_HEIGHT
    LDA #$00
    BCS LastP0Off
    LDA #$FF
LastP0Off:
    STA GRP0
    TXA
    SEC
    SBC MissileY
    CMP #M0_HEIGHT
    LDA #$00
    BCS LastM0Off
    LDA #$02
LastM0Off:
    STA ENAM0
    LDY HitPF0
    LDA HitPF1
    LDX HitPF2
    STA WSYNC               ; end line 171
; --- line 172 HBLANK: the bar's three bytes, then blank P0 and the missile ---
    STY PF0
    STA PF1
    STX PF2
    LDA #$00
    STA GRP0
    STA ENAM0
    STA ENAM1

; --- visible 172-177: the 15-chunk hit bar, mirrored by CTRLPF ---
    LDY #6
HitBarLoop:
    STA WSYNC
    DEY
    BNE HitBarLoop

; --- visible 178-191: the bottom background ---
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #14
BottomLoop:
    STA WSYNC
    DEY
    BNE BottomLoop

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines
; -----------------------------------------------------------------------------
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; COARSE POSITIONING — four objects, one HMOVE at the end
; =============================================================================
; A = the target TIA X plus POS_BIAS.  Each routine strobes its RESxx and
; leaves the fine value in its HMPx; the caller's single HMOVE applies all
; four fine offsets in one HBLANK (the one-HMOVE rule from Lesson 28/29).
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
    STA RESP0
    RTS

SetCoarseP1:
    STA WSYNC
    SEC
DivP1:
    SBC #15
    BCS DivP1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
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
    STA RESM0
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
    STA RESBL
    RTS

; =============================================================================
; HIT-BAR TABLE — N chunks from the left, three playfield bytes per entry
; =============================================================================
; PF0 bits 4-7 are the first four chunks (bit 4 leftmost); PF1 bits 7-0 are
; the next eight (bit 7 leftmost); PF2 bits 0-2 are the last three (bit 0 is
; leftmost, because PF2's bit order is reversed).  CTRLPF=$01 mirrors the
; same chunks from the right edge.
HitBarPF:
    !byte $00,$00,$00       ; 0 chunks
    !byte $10,$00,$00       ; 1
    !byte $30,$00,$00       ; 2
    !byte $70,$00,$00       ; 3
    !byte $F0,$00,$00       ; 4
    !byte $F0,$80,$00       ; 5
    !byte $F0,$C0,$00       ; 6
    !byte $F0,$E0,$00       ; 7
    !byte $F0,$F0,$00       ; 8
    !byte $F0,$F8,$00       ; 9
    !byte $F0,$FC,$00       ; 10
    !byte $F0,$FE,$00       ; 11
    !byte $F0,$FF,$00       ; 12
    !byte $F0,$FF,$01       ; 13
    !byte $F0,$FF,$03       ; 14
    !byte $F0,$FF,$07       ; 15

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
> `lessons/part6-game-dev/38-collision-detection/38-collision-detection.asm`.

### Code Walkthrough

#### Step 1 — The beep clock

`BeepTimer` is decremented once per VBLANK. When it reaches zero the code writes `AUDV0=0`; the
generator and the divider stay where they were. A new hit reloads the timer and writes
`AUDC0=$0C`, `AUDF0=$08`, `AUDV0=$0A`, so the beep restarts cleanly on top of a beep that is
still playing.

#### Step 2 — Building the mask

`LDA CXP0FB` is the first read. `ReadCX` marks the load, so the log reports A = `CXP0FB`. The
next instructions move the two bits into the lesson's mask layout:

```asm
    AND #$40            ; P0-ball stays in bit 6
    STA LatchMask
    LDA CXP0FB
    AND #$80            ; P0-playfield
    LSR
    LSR                 ; bit 7 -> bit 5
    ORA LatchMask
    STA LatchMask
```

`CXPPMM` bit 7 is already in the right place (bit 7), and `CXM0P` bit 7 becomes bit 4 after
three `LSR`s. `CollMask` marks the final store, so A is the whole mask.

#### Step 3 — The edge and the count

`EOR PrevMask` plus `AND LatchMask` keeps only 0→1 changes, and `CollStep` marks that store, so
A is only the edge bits. Four `ASL`s examine bits 7, 6, 5, and 4; `INX` counts the carry sets.
The count is added to `HitCount`, and `CMP #16` clamps the result at 15. `Hits` marks the store,
so the log reports the new count. A nonzero count reloads `BeepTimer` and writes the three audio
registers.

#### Step 4 — The band colors

The VBLANK code fills four bytes, `BandColors+0` through `BandColors+3`, with `$02` and then
replaces each one whose mask bit is set. The kernel reads the array with `LDX`/`LDA
BandColors,X` and writes `COLUBK` once per band. The array is in RAM because the kernel is
running too close to the line to test four bits per band.

#### Step 5 — The hit bar's three bytes

`HitCount × 3` indexes the 48-byte `HitBarPF` table. The table is ordered by chunk count, so
entry 0 is three zero bytes and entry 15 is `$F0,$FF,$07` — `PF2`'s bit 0 is the leftmost of its
three chunks, so the last three bits are `$01`, `$03`, `$07`, not the high end of the byte. The
VBLANK code stores the three bytes in `HitPF0/1/2`; the kernel writes them at visible 172 in
HBLANK.

#### Step 6 — P0's motion

The joystick is read from `SWCHA`. `AND #$F0` followed by `CMP #$F0` answers "are all four
directions released?". If not, each pressed direction moves P0 one pixel and clamps it:
X 8–144, Y 40–156. If all four are released, the auto-demo advances `AutoDiv`, moves P0 one
pixel every second frame around the rectangle X 8–80, Y 40–156, and fires M0 every 90 frames.
The 144 clamp puts P0's right edge at 144–151, inside the right wall; the left clamp at 8 puts it
at 8–15, inside the left wall.

#### Step 7 — P1, fire, and the missile

P1 sweeps X 40–136 at one pixel per frame and reverses at each end. The fire button is `INPT4`
bit 7, active low. A new press copies P0's X and Y into `MissileX`/`MissileY`; the missile then
climbs two pixels per frame and hides at Y=220 when it passes the top of the play area. The
missile's target is `MissileX + 3 + 1`: the missile's reset is one clock shorter than a player's,
so the extra pixel lands it on P0's X rather than one pixel left.

#### Step 8 — Position and one HMOVE

`SetCoarseP0`, `SetCoarseP1`, `SetCoarseM0`, and `SetCoarseBL` are four copies of the
divide-by-15 routine from Lesson 26. Each starts on a fresh line with `STA WSYNC`, computes the
coarse step and the fine nibble, and strobes its `RESxx`. After the fourth, `STA WSYNC` /
`STA HMOVE` applies all four fine offsets in one HBLANK. `HmoveApply` marks the WSYNC stall;
`HmoveDone` marks the store, which executes at the next line, cycle 3.

#### Step 9 — The visible kernel

The band loop writes `COLUBK` and holds it for six `WSYNC`s. At visible 24 the playfield turns
on with `PF0=$F0`, and zone A handles the missile. Zone B draws P1 with `GRP1=$FF` every line
and P0 with the compare; P0's write comes first so it lands in HBLANK. Zones C, D, and E repeat
the pattern: compare the line counter against `PlayerY` and `MissileY`, write `GRP0` and
`ENAM0`, and let the fixed object's enable be written after P0's graphics.

The last play-area line, visible 171, is handled separately. It draws its P0/M0 work, preloads
the bar's three playfield bytes into Y, A, and X, and then stores them in line 172's HBLANK
together with `GRP0=0`, `ENAM0=0`, and `ENAM1=0`. That single HBLANK puts the bar bytes on the
first bar line and stops the player and the missile at row 171. The bar holds for six lines,
then the playfield is cleared for the last fourteen.

#### Step 10 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F035` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F043` | 0, cycle 5 | VBLANK's first line |
| `ReadCX` | `$F05A` | A=`$02` with no contact; A=`$82` on the wall | the `CXP0FB` read |
| `CollMask` | `$F07B` | A=`$20` on the wall; A=`$10` on the M0–P1 frame | the full mask |
| `CollStep` | `$F081` | A=`$00` while a contact is held; `$20` on the first wall frame; `$40` ball; `$80` P0–P1; `$10` M0–P1 | the 0→1 edge bits |
| `CXClear` | `$F0B4` | line 1, cycle 68 (first frame) | the `CXCLR` strobe |
| `Hits` | `$F0A0` | A=1 at frame 2; 2 at 343; 3 at 439; 4 at 713; 12 at 2936 (the M0–P1 edge) | `HitCount` after the add |
| `BodyStart` | `$F267` | 37, cycle 5 | the first visible line |
| `HmoveApply` | `$F238` | line 8, cycle 56 | the WSYNC stall |
| `HmoveDone` | `$F23A` | line 9, cycle 3 | the `HMOVE` store |
| `OverscanStart` | `$F394` | 229, cycle 4 | overscan's first line |

::: tip M0's enable can be one line late
`ENAM0` is written after `GRP0` on each play-area line. When M0's X is below about 46, that store
lands after the missile's pixel window, so M0's first drawn row can be one line low; the M0–P1
collision rows follow the drawn missile. The kernel timing is unchanged for this lesson. The
M0–P1 witness at frame 2936 is from the committed ROM.
:::

## What You Should See

The collision lab is a dark field with a gold wall on each side, a red block, a blue block, a
thin gold dash, and four quiet bands at the top. The bands are the only part that changes colour
without the player: they follow the latches one frame behind the objects.

**At a wall contact.** P0 starts at X=8 inside the left wall, so the very first visible frame
sets the P0–playfield latch. Band 2 is green for the whole time P0 stays in the wall. In this
capture P0 has climbed to Y≈126; the red block is drawn over the gold wall. The hit bar shows
**one chunk per half** — the wall contact is one event, not a sequence, because the latch stays
set and the edge detector sees only the first 0→1 change.

![Stella running the Lesson 38 ROM at a wall contact: a green band 2, the red player inside the left gold wall, the blue enemy at the top, the gold ball at the middle, and a one-chunk hit bar at the bottom](/images/lesson38/wall.png)

*The wall contact: band 2 (`P0–playfield`) green, P0 red at X=8 over the left wall, P1 blue at
X=69/Y=40, the ball gold at X=80/Y=100, and one hit chunk per half. Captured from the committed
ROM.*

**At a P0–P1 contact.** P0 reaches Y=40 on the top of its rectangle while P1 is sweeping through
the same columns. Band 0 turns red. In this capture P0 is at X=80 and P1 is at X=81; the two
eight-pixel sprites overlap by seven pixels, and P0 has priority, so only P1's rightmost pixel
shows blue. The hit bar is at **two chunks per half**: the first contact was the wall, the second
is this one.

![Stella running the Lesson 38 ROM at a P0-P1 contact: a red band 0, the red player at the top of the play area with one blue pixel of the enemy showing at its right edge, the gold ball in the middle, and a two-chunk hit bar at the bottom](/images/lesson38/p1.png)

*The P0–P1 contact: band 0 red, P0 red at X=80/Y=40, P1 blue partly hidden under P0 (one visible
pixel at X=88), the ball at X=80/Y=100, and two hit chunks per half. Captured from the committed
ROM.*

The auto-demo also fires M0 every 90 frames. The fourth band (blue, M0–P1) lights when that
missile crosses P1's rows at the same X; the state log shows the edge at frame 2936 (`CollStep`
A=`$10`). Press fire to launch a missile immediately instead of waiting for the auto-fire.

<RomPlayer rom="/roms/part6-game-dev/38-collision-detection/38-collision-detection.bin" title="Lesson 38 — Collision Detection" />

Click the player screen once: Javatari starts muted until a user gesture, and the hit beep
begins when you click. Hold a direction on the joystick to take P0 off the auto-demo; press fire
to launch M0 upward from P0's X. The blue band lights when the missile crosses P1's rows at the
same X.

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson38.sym -o build/lesson38.bin \
  lessons/part6-game-dev/38-collision-detection/38-collision-detection.asm
grep -E "ReadCX|CollMask|CollStep|CXClear|Hits|BodyStart|HmoveDone" build/lesson38.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0A0' \
  docs/public/roms/part6-game-dev/38-collision-detection/38-collision-detection.bin
```

- **`$F05A` (`ReadCX`)**: A=`$02` before the first visible frame, then A=`$82` on the wall.
  Bit 7 is the fact; the `$02` is the undefined low bits.
- **`$F07B` (`CollMask`)**: A=`$20` while the wall latch is set; A=`$10` on the M0–P1 frame.
  This is the whole mask, held or not.
- **`$F081` (`CollStep`)**: A=`$00` after the first frame because the wall contact is held;
  `$20` on the first wall frame, `$40` on a ball edge, `$80` on a P0–P1 edge, and `$10` on an
  M0–P1 edge. This is only the 0→1 bits.
- **`$F0B4` (`CXClear`)**: the strobe executes once per frame, at scanline 1, cycle 68 on the
  first frame.
- **`$F0A0` (`Hits`)**: A=1 at frame 2 (the wall), 2 at frame 343 (P0–P1), 3 at frame 439
  (P0–ball), 4 at frame 713 (the wall again); the M0–P1 edge at frame 2936 raises it to 12.
- **`$F267` (`BodyStart`)**: scanline 37, cycle 5. **`$F394` (`OverscanStart`)**: scanline 229,
  cycle 4 — the 262-line frame.

## Exercises

### Exercise 1: The Ball, Not the Wall

**Challenge:** change the green band's source from `CXP0FB` bit 7 (P0–playfield) to `CXP0FB`
bit 6 (P0–ball), and document the new meaning.

**Hints:**
1. The green band reads `LatchMask` bit 5. The mask build is the only place that decides which
   `CXP0FB` bit feeds bit 5.
2. In the mask build, `AND #$80` followed by two `LSR`s moves the playfield bit into bit 5.
   Replacing that with `AND #$40` and one `LSR` moves the ball bit into the same place.
3. The wall is still drawn and still touched; it simply has no band and no hit count any more.

**Expected Result:** the green band lights when P0 touches the ball, not when it touches the
wall. Band 1 (gold) also lights, because both bands now report the same pair. Each ball contact
sets two mask bits (bit 6 for the gold band and bit 5 for the green band), so the hit bar
advances **two chunks** on a ball contact. `ReadCX` still reports the whole `CXP0FB` byte —
`$82` on the wall, `$42` on the ball — because the exercise changes the mask, not the hardware
read; the green band only follows bit 6. The wall contact lights no band and adds no hit, so the
initial climb produces a dark monitor and an empty bar.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: The Enemy Missile

**Challenge:** give P1 a missile (M1) that fires downward every 90 frames and read `CXM1P` bit 7
(M1–P0). The main ROM only has M0.

**Hints:**
1. Add a countdown byte and a Y byte for M1. Reset the countdown to 90, launch at row 56 (just
   below P1), and add 2 to the Y every frame until it passes the bottom of the play area.
2. The missile's X is P1's X at launch. Position it with `RESM1`/`HMM1` and add its coarse
   routine to the same one-`HMOVE` group as the four existing objects.
3. The blue band is `LatchMask` bit 4. Change the read from `CXM0P` bit 7 to `CXM1P` bit 7 and
   move the `ReadCX` label with it, so the checkpoint reports the new register.

**Expected Result:** the blue band lights when M1 crosses P0's rows at the same X; `ReadCX`
reports A=`CXM1P` with bit 7 set (`$8x`). In the solution's auto-demo run the M1–P0 edge is the
fourth hit, at frame 588 (after the wall, P1, and ball edges), and `Hits` reaches 5 at the next
wall contact (frame 713).

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Sticky Latches *(Stretch Goal)*

**Challenge:** remove the `CXCLR` store entirely and watch the bands stay lit after the objects
separate. Do not merely move the store: a store after the kernel still clears once per frame,
and the bands go dark instead of sticking.

**Hints:**
1. The store is the `STA CXCLR` after `NoNewHit`. Removing the instruction is the whole change.
2. The `CXClear` checkpoint is a label after the store. If the store is gone, the label cannot
   be reached either; the log should show no `CXClear` break of any kind.
3. The edge detector still works, but after each bit has set once there are no more 0→1 edges,
   so `Hits` stops climbing.

**Expected Result:** the first contact with each pair latches its bit forever. Bands light and
never go dark again, even after the objects separate. The auto-demo produces the wall, P0–P1,
and P0–ball pairs in its first cycle; the fourth bit (M0–P1) arrives with the auto-fire's
missile, or immediately when you press fire. The hit bar stops growing once the four pairs have
each been seen; the state log shows `CollMask` values that never lose a bit (the `CollStep`
edges are all zero after the first four).

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **Eight registers, two bits each**: the TIA pairs its five movable objects and the playfield, and each latch reports one pair
- ✅ **A latch is sticky**: it remembers a contact until `CXCLR` clears all eight; clear after reading, once per frame
- ✅ **VBLANK reads the past**: the latches describe the visible frame that just ended, so the monitor is one frame behind
- ✅ **Collisions are drawn pixels**: the hardware compares the picture, not the position variables
- ✅ **An event is a 0→1 edge**: `mask AND NOT previous` turns a sticky latch into one hit, one beep, one bar chunk
- ✅ **One HMOVE for four objects**: every coarse `RESxx` and fine `HMPx` is set first, then one strobe applies them together
- ✅ **The hit bar is a table**: `HitCount × 3` indexes fifteen playfield patterns, and the kernel writes the three bytes in HBLANK

## What's Next

The lab turns contacts into a count, but a game needs a number on the screen. [Lesson 39: The
Scoreboard](/part6-game-dev/39-scoreboard) uses the collision latch to add one to a six-digit
score, and builds the 48-pixel Staugas kernel that draws it with two players in three-copy close
mode.
