---
title: "Lesson 39: The Scoreboard — 48-Pixel Sprite Trick"
description: "Two 8-pixel players become six digits: the Staugas 48-pixel score kernel uses three-copy close mode, a one-pixel offset, and VDEL to draw a six-digit score. Lesson 39 builds the scoreboard — a column-major font buffer, a decimal carry, a gold target, a ball, and the collision latch that adds one."
prev:
  text: "Lesson 38: Collision Detection"
  link: "/part6-game-dev/38-collision-detection"
next:
  text: "Lesson 40: BCD Arithmetic"
  link: "/part6-game-dev/40-bcd-arithmetic"
---

# Lesson 39: The Scoreboard — 48-Pixel Sprite Trick

> **Part 6: Game Development** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 11 (lookup tables), Lesson 18 (mid-line TIA writes), Lesson 25 (player graphics), Lesson 26 (`SetHorizPos` and one `HMOVE`), Lesson 31 (`NUSIZ` copies), Lesson 32 (vertical delay), Lesson 38 (collision latches)
> **You will learn:** how two 8-pixel players become six digits; why `NUSIZ=3` and a one-pixel offset are enough; how `VDEL`'s cross-latch lets six different bytes reach two players on one line; how a column-major, bottom-up font buffer works; how a decimal carry moves through six digits; how a collision latch becomes one point on the scoreboard
> **You will build:** "the scoreboard" — a six-digit score across the top, a gold 32-pixel target, a gold ball that sweeps or follows the joystick, a `CXBLPF` hit that adds one and beeps, and three exercises: set a score, double the score, and hide the leading zeros

## Introduction

The Atari 2600 has no text mode. It has no character generator, no frame buffer, and no
video memory. The picture is produced one scanline at a time by the TIA, and the only
things that can draw a digit are the two 8-pixel players, two missiles, a ball, and the
20-bit playfield. A six-digit score is therefore a puzzle: 6 × 8 = 48 pixels, but the
two players together offer only 16 pixels before `NUSIZ` copies are considered.

The solution is a classic 2600 trick usually credited to John Staugas. Put both players
in **three-copy close mode** (`NUSIZ=3`): each player becomes three 8-pixel copies, 16
pixels apart. Put P0 at X=56 and P1 at X=64 — exactly 8 pixels to the right. The copies
interleave into six 8-pixel columns:

```text
P0 copy 0  X=56     P1 copy 0  X=64
P0 copy 1  X=72     P1 copy 1  X=80
P0 copy 2  X=88     P1 copy 2  X=96
```

Six digits, 48 pixels, two players. The hard part is not the position; it is the
*six bytes per scanline*. The TIA draws the copies one after another across the line,
so the kernel has to rewrite `GRP0` and `GRP1` between the copies. The Staugas kernel
does exactly that, using `VDELP0`/`VDELP1` as a cross-latch: each write stages a pending
byte, and the other player's write commits it to the screen just before the next copy.

This lesson builds **the scoreboard**: the six-digit score across the top, a gold
target in the lower play area, a gold ball that sweeps back and forth (or follows the
joystick), and a `CXBLPF` collision that adds one to the score. The score starts at
000000; the first two auto-demo hits produce 000001 and 000002. The screen is the
monitor; the debugger checkpoints are the receipt.

::: details TypeScript Equivalent
A six-digit score is a small array and a carry loop. The display is a second array
that holds the bytes the TIA will draw, one column per digit:

```typescript
// Ten glyphs, eight rows each.  Row 0 is the bottom row; row 7 is the top.
const FONT: number[][] = [
  [0x00, 0x3c, 0x66, 0x66, 0x76, 0x6e, 0x66, 0x3c], // 0
  [0x00, 0x7e, 0x18, 0x18, 0x18, 0x18, 0x38, 0x18], // 1
  // ... 2 through 9
];

const digits: number[] = [0, 0, 0, 0, 0, 0];          // left to right
const buffer: number[][] = Array.from({ length: 6 }, () => Array(8).fill(0));

function setDigit(position: number, digit: number): void {
  digits[position] = digit;
  for (let row = 0; row < 8; row += 1) {
    buffer[position][row] = FONT[digit][row];
  }
}

function addOne(): boolean {
  let position = 5;                  // the rightmost digit
  while (position >= 0) {
    digits[position] += 1;
    if (digits[position] < 10) {
      setDigit(position, digits[position]);
      return false;                  // no carry out of the top digit
    }
    setDigit(position, 0);           // 9 + 1 = 10: write 0 and carry left
    position -= 1;
  }
  return true;                       // 999999 -> 000000
}
```

The analogy breaks in the part that makes the 2600 interesting. `buffer` is not a
framebuffer: nothing scans it for you. The program has to write each byte to `GRP0` or
`GRP1` at the exact color clock when the corresponding copy is about to be drawn.
`VDEL` turns that impossible schedule into a feasible one: a write stages a pending
byte and the other player's write commits it, which gives the kernel a safe moment for
each column. And the "display" is only 48 pixels wide — there is no room for a seventh
digit without another trick.
:::

## Theory

### Section 1: Six Digits from Two Players

A player is eight pixels wide. `NUSIZ0` and `NUSIZ1` bits 0–2 select how many copies
are drawn and how far apart they are:

| `NUSIZ` bits 0–2 | Copies | Spacing |
|---|---|---|
| 0 | one | — |
| 1 | two | 16 pixels (close) |
| 2 | two | 32 pixels (medium) |
| 3 | **three** | **16 pixels (close)** |
| 4 | two | 64 pixels (wide) |
| 6 | three | 32 pixels (medium) |

`NUSIZ=3` gives three copies at X, X+16, and X+32. Place P0 at X=56 and P1 at X=64 and
the copies interleave perfectly:

| Column | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| Player | P0 copy 0 | P1 copy 0 | P0 copy 1 | P1 copy 1 | P0 copy 2 | P1 copy 2 |
| TIA X | 56 | 64 | 72 | 80 | 88 | 96 |
| Capture X | 361 | 409 | 457 | 505 | 553 | 601 |

The capture X column uses the course mapping `capture x = 25 + 6 × TIA X`. Each cell is
8 TIA pixels wide, so the six cells cover X=56–103 and capture x=361–648. The glyphs
do not touch the edges of their cells, so the *lit* pixels in this lesson's captures
start at x=367 and end at x=642.

The vertical side has the same "no framebuffer" problem. A player shows only the byte
that is in `GRP0` or `GRP1` at the moment its copy is drawn. The six cells are
contiguous, so a write that lands inside a copy's eight-pixel window would tear it;
the kernel uses VDEL's cross-latch to stage each byte and commit it at the right moment.
The next section is the schedule that makes that possible.

### Section 2: VDEL and the Six-Store Kernel

The TIA draws a scanline from left to right. The first P0 copy is at **TIA X=56** and
occupies TIA color clocks 56–63; because the visible area starts at absolute color
clock 68, those are absolute color clocks 124–131. P1's first copy at TIA X=64 occupies
TIA color clocks 64–71; P0's second at 72–79; and so on. The six cells are contiguous:
each of the last four writes lands during a copy of the player it belongs to, and the
cross-latch defers it until the other player's write — that is why VDEL is needed.

The catch is that a write to `GRP0`/`GRP1` during a copy's eight-pixel window would tear
that copy: the first pixels would come from the old byte and the rest from the new one.
`VDELP0` and `VDELP1` solve this with a **cross-latch**. With VDEL on, a write to `GRP0`
does not change P0's output immediately; it stores a **pending** byte. The next write to
`GRP1` copies that pending byte into P0's display register, and a write to `GRP0` copies
`GRP1`'s pending byte into P1's display register. Each player's display is committed by
the other player's write.

The kernel uses the cross-latch as a schedule. The first three stores land in HBLANK
(cycles 3, 10, and 17, 1-based) and stage columns 0, 1, and 2; the first two columns are
committed in HBLANK, before the visible area. The last four stores land just before the
later copy windows (cycles 45, 48, 51, and 54) and commit columns 2, 3, 4, and 5:

| Order | Store | Column | Cycle | What the cross-latch does |
|---|---|---|---|---|
| 1 | `STA GRP0` | 0 | 3 | stages column 0 in P0's pending byte |
| 2 | `STA GRP1` | 1 | 10 | stages column 1; commits column 0 to P0 |
| 3 | `STA GRP0` | 2 | 17 | stages column 2; commits column 1 to P1 |
| 4 | `STY GRP1` | 3 | 45 | stages column 3; commits column 2 to P0 |
| 5 | `STX GRP0` | 4 | 48 | stages column 4; commits column 3 to P1 |
| 6 | `STA GRP1` | 5 | 51 | stages column 5; commits column 4 to P0 |
| 7 | `STA GRP0` | — | 54 | flushes; commits column 5 to P1 |

The three HBLANK stores are seven cycles apart; the last four are a three-cycle run. The
seventh `STA GRP0` is the flush that commits P1's last column, column 5. Two instructions
that look useless are part of the schedule: the `NOP` and the `CPX ScoreRow`. The `CPX`
reads the row counter only to burn three cycles; its flags are discarded. Remove either
one and the columns move.

The stores execute on the **same visible line that displays the row**. On entry the CPU
is at the start of visible line 0; the first iteration loads row 7 and its `STA WSYNC`
ends line 0, so row 7's six stores execute on visible line 1 and are displayed there.
Rows 7 through 0 are displayed on visible lines 1 through 8. The cleanup (`GRP0=0`,
`GRP1=0`, `VDELP0=0`, `VDELP1=0`) runs after line 8's copies have gone by. Line 9 is
blank not because the zeros are delayed, but because VDEL is turned off with
`GRP0`/`GRP1` already zero. The score zone is therefore 9 lines (0 through 8), and the
game zone is 183 lines (9 through 191).

::: tip Do not "clean up" the kernel
The `NOP` and `CPX` are not leftover code. They are cycle padding. The six stores are
timed against the copies' pixel windows; one extra or missing cycle changes which copy
receives which byte. If you edit the kernel, change only the data addresses — never the
instruction order or count.
:::

### Section 3: The Score as Data

The displayed score is built from two arrays:

| Symbol | Address | Size | Meaning |
|---|---|---|---|
| `ScoreDigits` | `$A0–$A5` | 6 bytes | the six digits, 0 = leftmost, 5 = rightmost |
| `ScoreBuf` | `$A8–$D7` | 48 bytes | six columns × eight rows, column-major, bottom-up |
| `ScoreRow` | `$A6` | 1 byte | the kernel's row counter (scratch) |
| `ScoreTmp` | `$A7` | 1 byte | column 3's byte / a saved digit (scratch) |

`ScoreBuf` is **column-major**: column 0's eight rows are `$A8–$AF`, column 1's are
`$B0–$B7`, and so on. It is **bottom-up**: row 0 is the bottom row and row 7 is the top
row. That order matches the kernel, which counts Y down from 7 to 0. A column is copied
straight from the font with no reversal:

```asm
    LDA ScoreFont,X     ; X walks the eight font bytes
    STA ScoreBuf,Y      ; Y walks the eight buffer bytes
```

`ScoreFont` holds ten glyphs, eight bytes each. Every glyph's byte 0 is `$00`, so the
bottom row of the cell is empty and the visible part of a digit is seven scanlines
tall. That is why the lit score block in the captures is seven lines high even though
the kernel draws eight rows.

`ScoreSetDigit` takes A = position (0–5) and X = digit (0–9). It stores the digit in
`ScoreDigits`, computes `digit × 8` for the font offset and `position × 8` for the
buffer offset, and copies eight bytes. `ScoreClear` calls it six times with digit 0 to
draw `000000`. `ScoreInit` zeroes the digits and the buffer; it leaves the screen
blank, so a program that wants six zeros calls `ScoreClear` after it.

### Section 4: The Decimal Carry

The score is six **binary** digits, 0–9, not a packed BCD number yet. Lesson 40 turns
the arithmetic into BCD; this lesson keeps the simplest version: a loop from the
rightmost digit.

```text
add one to digit 5
if it is 10: write 0, add one to digit 4
if that is 10: write 0, add one to digit 3
...
if digit 0 carries: the score was 999999, so it is now 000000
```

`ScoreAddOne` starts at position 5. It increments the digit, compares it with 10, and
either stores the new value (no carry) or stores 0 and moves one position left. Every
digit that changes is redrawn immediately with `ScoreSetDigit`, so `ScoreBuf` is always
the picture of `ScoreDigits`. The routine returns **C=1** when the carry leaves position
0; that is the 999999 → 000000 overflow. The caller can use the carry for a rollover
indicator (Lesson 40 does).

The state log shows the carry at frame 202: `ScoreAdd` reports A=0 for the rightmost
digit (9 → 0), then A=1 for the next digit (0 → 1). The score goes from 000009 to
000010 in one call. Adding one again reports A=1 for the rightmost digit and the score
becomes 000011.

### Section 5: The Frame and the Game Zone

The frame is the course standard: 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan =
**262 lines**. The picture is 192 lines, but it is no longer a single work-first kernel:
the score kernel is the documented **WSYNC-first exception**, and the game zone is
work-first after it.

```text
  9  score zone (visible 0-8)
183  game zone (visible 9-191)
---
192
```

The game zone is budgeted exactly:

```text
141  background (visible 9-149)
  8  target and ball (visible 150-157)
 34  background (visible 158-191)
---
183
```

The target is drawn by the playfield. With `CTRLPF=$01` the right half of the
playfield mirrors the left, and `PF2=$F0` sets bits 4–7 of the playfield's last byte.
`PF2`'s bit 0 is the leftmost of its eight chunks, so bits 4–7 are the center 32
pixels. In this layout that is TIA X=64–95, capture x=409–600. The same eight lines
enable the ball (`ENABL=2`), a one-pixel-wide, eight-row gold mark at `BallX`.

The ball starts at X=24 and moves two pixels per frame. With no joystick input it
sweeps right to X=136 and back; the joystick's left/right directions override the
sweep. The target is at X=64–95, so the first sweep reaches it after 20 frames. The
collision is read in VBLANK:

```asm
    LDA CXBLPF      ; bit 7: ball-playfield
    AND #$80
    BEQ NoBallHit
    JSR ScoreAddOne
    JSR BeepStart
    ; respawn at X=24
NoBallHit:
    STA CXCLR       ; clear after reading
```

The read describes the **previous** visible frame: the ball hit the target on frame N,
the VBLANK of frame N+1 reads the latch, and the new score is displayed on frame N+1.
That one-frame latency is the hardware handshake from Lesson 38, not a bug. After the
read, `CXCLR` clears every latch so the next frame starts from zero.

The ball's horizontal position and the score's two players are positioned in the same
VBLANK. `SetCoarseBL` sets `HMBL`/`RESBL`; `ScoreSetup` sets `HMP0`/`RESP0` and
`HMP1`/`RESP1`; one `HMOVE` applies all three fine offsets in one HBLANK. This is the
one-`HMOVE` rule at three objects. The ball needs one extra pixel in its target because
its reset is one color clock shorter than a player's (`BallX + 3 + 1`).

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson39.bin \
  lessons/part6-game-dev/39-scoreboard/39-scoreboard.asm
stella build/lesson39.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

The shared score library lives in `include/score.asm`; the lesson source sources it
after `include/vcs.asm` and `include/macro.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 39: The Scoreboard — 48-Pixel Sprite Trick — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; What this program does:
;   "The scoreboard": a six-digit score across the top of the screen, drawn
;   with two players in three-copy close mode.  The play area holds a gold
;   playfield target and a gold ball; when the ball touches the target the
;   score goes up by one, the beep sounds, and the ball respawns at the left.
;   With no joystick input the ball sweeps left and right by itself, so the
;   first two hits produce 000001 and 000002 without any help.
;
; The two players make six digits:
;   NUSIZ0 = NUSIZ1 = 3  three copies, close spacing (16 pixels apart)
;   P0 at TIA X=56 -> copies at 56, 72, 88
;   P1 at TIA X=64 -> copies at 64, 80, 96
;   The copies interleave into six 8-pixel columns: 56..103.
;   VDELP0/VDELP1 = 1    a write stages a pending byte; the other player's
;                        write commits it, so each column can be placed just
;                        before its copy is drawn.
;
; The score zone (9 visible lines, visible 0-8):
;   line 0  setup/blank: the first row's bytes are loaded, then WSYNC
;   lines 1-8  the eight glyph rows, top (font byte 7) to bottom (byte 0)
;   the cleanup (GRP0/GRP1=0, VDEL off) shares line 8
;   Every glyph's bottom row is blank, so the lit block is seven lines tall.
;   include/score.asm owns ScoreDigits ($A0-$A5), ScoreBuf ($A8-$D7), and the
;   two scratch bytes $A6-$A7.
;
; The game zone (183 visible lines, visible 9-191):
;   visible 9-149    background (141 lines)
;   visible 150-157  the target (PF2=$F0 with CTRLPF=$01 -> X=64-95) and the
;                    ball (ENABL=2, one pixel wide, gold) on the same rows
;   visible 158-191  background (34 lines)
;   The target and the ball share COLUPF=$1A; the collision still latches
;   because ball and playfield are separate TIA objects.
;
; The score:
;   ScoreInit clears the digits and the buffer; ScoreClear draws 000000.
;   A hit calls ScoreAddOne, which carries 9 -> 0 across the six digits.
;   ScoreSetDigit copies one 8-byte glyph (bottom-up) into its column.
;
; The ball:
;   X starts at 24, moves 2 pixels per frame with the joystick, and clamps to
;   24..136.  With no joystick input it sweeps 24 -> 136 -> 24 by itself.
;   CXBLPF bit 7 (ball-playfield) is read in VBLANK, one frame after the
;   contact; the read is followed by CXCLR.  A hit adds one, beeps, and
;   respawns the ball at X=24.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), ScoreInit (once at reset),
;   ScoreDigitWrite (A = position, X = digit), ScoreAdd (A = the digit after
;   the add), BallHit (A = $80), BodyStart (37), ScoreDraw (the call),
;   ScoreDrawRow (the first drawn row), HmoveApply/HmoveDone (once per frame),
;   OverscanStart (229).
;
; Build: acme -f plain -o build/lesson39.bin \
;        lessons/part6-game-dev/39-scoreboard/39-scoreboard.asm
; Run:   stella build/lesson39.bin     (click the screen to hear the beep)
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

BALL_MIN_X     = 24      ; the ball's left clamp
BALL_MAX_X     = 136     ; the ball's right clamp
BALL_Y         = 150     ; the ball's first visible row (8 rows tall)
TARGET_LINES   = 8       ; the target and the ball share these eight rows
TARGET_PF2     = $F0     ; PF2 bits 4-7: the center 32 pixels when reflected
BALL_ENABLE    = $02     ; ENABL bit 1
BEEP_FRAMES    = 8
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright hit

C_WHITE        = $0E
C_GOLD         = $1A
C_BG           = $02

; --- Lesson variables (RAM $80-$9F; +clean_start zeroes them) ---
BallX       = $80   ; the ball's left edge, 24..136
BallDir     = $81   ; 1 = sweeping right, 0 = sweeping left
InputBits   = $82   ; this frame's SWCHA read
BeepTimer   = $83   ; frames of beep remaining
BeepPitch   = $84   ; AUDF for the beep
;
; The score library owns $A0-$D7:
;   ScoreDigits $A0-$A5, ScoreRow $A6, ScoreTmp $A7, ScoreBuf $A8-$D7.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start

    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the score starts at 000000 ---
    JSR ScoreInit           ; zero the digits and the 48-byte buffer
    JSR ScoreClear          ; build the six zero glyphs

; --- the ball starts at the left, sweeping right ---
    LDA #BALL_MIN_X
    STA BallX
    LDA #1
    STA BallDir
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
; 1. THE BEEP'S CLOCK — the last frame writes silence
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0
BeepDone:

; -----------------------------------------------------------------------------
; 2. READ THE BALL-PLAYFIELD LATCH — the previous visible frame's contact
; -----------------------------------------------------------------------------
; CXBLPF bit 7 sets while the ball's drawn pixel and a playfield pixel share
; a color clock.  The read is in the next VBLANK, so it describes frame N
; while the program builds frame N+1: one frame of latency by construction.
    LDA CXBLPF              ; bit 7 only; the low bits are not defined
    AND #$80
    BEQ NoBallHit
BallHit:                    ; checkpoint: A = $80 when the ball hit the target
    JSR ScoreAddOne         ; add one, with a decimal carry
    JSR BeepStart           ; AUDC/AUDF/AUDV and the timer
    LDA #BALL_MIN_X
    STA BallX               ; respawn at the left edge
    LDA #1
    STA BallDir             ; and sweep right again
NoBallHit:
    LDA #$00
    STA CXCLR               ; the latches have done their job for this frame

; -----------------------------------------------------------------------------
; 3. THE BALL'S MOTION — the joystick, or the automatic sweep
; -----------------------------------------------------------------------------
    LDA SWCHA
    STA InputBits
    AND #$C0                ; P0 left (bit 6) and right (bit 7)
    CMP #$C0
    BEQ AutoSweep           ; neither pressed: run the demo

; --- manual: two pixels per frame, clamped to 24..136 ---
    LDA InputBits
    AND #$40                ; left
    BNE ManualRight
    LDA BallX
    SEC
    SBC #2
    CMP #BALL_MIN_X
    BCS ManualStore
    LDA #BALL_MIN_X
    JMP ManualStore
ManualRight:
    LDA InputBits
    AND #$80                ; right
    BNE ManualDone
    LDA BallX
    CLC
    ADC #2
    CMP #(BALL_MAX_X + 1)
    BCC ManualStore
    LDA #BALL_MAX_X
ManualStore:
    STA BallX
    JMP ManualDone

; --- auto-demo: 24 -> 136 -> 24, two pixels per frame ---
AutoSweep:
    LDA BallDir
    BNE AutoRight
    LDA BallX
    SEC
    SBC #2
    CMP #BALL_MIN_X
    BCS AutoStore
    LDA #BALL_MIN_X
    LDX #1
    STX BallDir             ; bounce off the left clamp
    JMP AutoStore
AutoRight:
    LDA BallX
    CLC
    ADC #2
    CMP #(BALL_MAX_X + 1)
    BCC AutoStore
    LDA #BALL_MAX_X
    LDX #0
    STX BallDir             ; bounce off the right clamp
AutoStore:
    STA BallX
ManualDone:

; -----------------------------------------------------------------------------
; 4. POSITION THE BALL AND THE SCORE, THEN ONE HMOVE
; -----------------------------------------------------------------------------
; The ball's reset is one color clock shorter than a player's, so its target
; needs one extra pixel (Lesson 29/38).  SetCoarseBL leaves HMBL ready;
; ScoreSetup sets HMP0/HMP1 and ends with the single HMOVE that applies all
; three fine offsets in one HBLANK.
    LDA BallX
    CLC
    ADC #(POS_BIAS + 1)
    JSR SetCoarseBL
    JSR ScoreSetup

; -----------------------------------------------------------------------------
; 5. COLORS AND PLAYFIELD CONTROL
; -----------------------------------------------------------------------------
    LDA #C_WHITE
    STA COLUP0              ; the score is white
    STA COLUP1
    LDA #C_GOLD
    STA COLUPF              ; the target and the ball are gold
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL               ; the ball is off outside its eight rows
    LDA #$01
    STA CTRLPF              ; reflect the playfield; ball one pixel wide

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines: the score zone (9) then the game zone (183)
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: scanline 37, visible line 0
    JSR ScoreDraw           ; 9 lines: line 0 setup, lines 1-8 rows

; -----------------------------------------------------------------------------
; THE GAME ZONE — visible 9-191 (183 lines).  ScoreDraw returns on visible 9.
; -----------------------------------------------------------------------------
; The first game-zone line writes the blank playfield.  The same values are
; already in the registers; writing them here is the work-first line.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL

; --- visible 9-149: BALL_Y - 9 = 141 background lines ---
    LDY #(BALL_Y - 9)
TopBackground:
    STA WSYNC
    DEY
    BNE TopBackground

; --- visible 150-157: the target and the ball share these eight lines ---
; PF2=$F0 with CTRLPF bit 0 (reflect) is the center 32 pixels, X=64-95.
; ENABL=2 draws the ball's one-pixel column at BallX.
    LDA #TARGET_PF2
    STA PF2
    LDA #BALL_ENABLE
    STA ENABL
    LDY #TARGET_LINES
TargetLines:
    STA WSYNC
    DEY
    BNE TargetLines

; --- visible 158-191: 192 - BALL_Y - TARGET_LINES = 34 background lines ---
    LDA #$00
    STA PF2
    STA ENABL
    LDY #(192 - BALL_Y - TARGET_LINES)
BottomBackground:
    STA WSYNC
    DEY
    BNE BottomBackground

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines
; -----------------------------------------------------------------------------
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C                ; AUDC 0C: the div-6 tone from Lesson 35
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; BALL COARSE POSITIONING — one RESBL, one HMBL, no HMOVE
; =============================================================================
; A = the target TIA X plus POS_BIAS + 1.  The +1 corrects the ball's
; one-clock-shorter reset.  ScoreSetup's single HMOVE applies HMBL.
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
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreInit, ScoreClear, ScoreSetup, ScoreSetDigit, ScoreAddOne, ScoreDraw,
; and ScoreFont live here.  The library must be sourced inside the ROM area
; (after * = $F000) and after include/vcs.asm.
    !source "include/score.asm"

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
> `lessons/part6-game-dev/39-scoreboard/39-scoreboard.asm`. The shared library lives in
> `include/score.asm`.

### Code Walkthrough

#### Step 1 — The library's map and API

`include/score.asm` owns `$A0–$D7`. `ScoreDigits` holds the six digits; `ScoreBuf`
holds the 48 display bytes; `ScoreRow` and `ScoreTmp` are scratch. The public routines
are `ScoreInit`, `ScoreClear`, `ScoreSetup`, `ScoreSetDigit`, `ScoreAddOne`, and
`ScoreDraw`, plus the `ScoreFont` table. The caller owns the colors: this lesson writes
`COLUP0=COLUP1=$0E` (white).

The library keeps no hidden persistent state. `ScoreRow` and `ScoreTmp` are written and
read inside a single call; the caller's durable state is `ScoreDigits` and `ScoreBuf`.

#### Step 2 — Reset: a blank slate, then six zeros

`ScoreInit` zeroes the six digits and all 48 buffer bytes. That leaves the buffer
blank. `ScoreClear` sets the digits to 0 and calls `ScoreSetDigit` six times, which
copies the zero glyph into each column. The display reads **000000** before the first
frame.

The lesson then sets the ball at X=24, sweeping right, and seeds `BeepPitch` with
`$08`. The auto-demo needs no other state: the ball's direction byte and the X position
are the whole demo.

#### Step 3 — VBLANK: beep, collision, motion, position

The VBLANK section is a fixed sequence:

1. **The beep clock.** `BeepTimer` counts down one per frame; when it reaches zero the
   program writes `AUDV0=0`. `BeepStart` (called on a hit) writes `AUDC0=$0C` (the
   div-6 tone from Lesson 35), `AUDF0=$08`, `AUDV0=$0A`, and reloads the timer.
2. **The collision read.** `CXBLPF` bit 7 is the ball–playfield latch. On a hit the
   code calls `ScoreAddOne`, starts the beep, and respawns the ball at X=24. Then
   `CXCLR` clears the latches. `BallHit` marks the hit path, so the log reports A=`$80`.
3. **The ball's motion.** `SWCHA` bits 6/7 are P0 left/right, active low. If either is
   pressed, the ball moves two pixels in that direction and clamps at 24 or 136. If
   neither is pressed, `BallDir` selects the automatic sweep, which reverses at the
   clamps.
4. **Positioning.** `SetCoarseBL` sets the ball's `HMBL`/`RESBL`; `ScoreSetup` sets the
   score's `NUSIZ`, `VDEL`, `HMP0`/`HMP1`, and `RESP0`/`RESP1`, then strokes one
   `HMOVE`. `HmoveApply` marks the WSYNC stall and `HmoveDone` the store.
5. **Colors and playfield.** `COLUP0`/`COLUP1` are white, `COLUPF` is gold, `COLUBK`
   is `$02`, and `CTRLPF=$01` (reflect). The playfield bytes and `ENABL` are cleared;
   the target and ball are enabled later, inside the game zone.

The RIOT timer covers 37 lines. The VBLANK work is short; the `+wait_timer` WSYNC
anchors the visible section at scanline 37.

#### Step 4 — The score kernel

`BodyStart` is at scanline 37, visible line 0. `JSR ScoreDraw` enters the Staugas
kernel. Each iteration does this:

```asm
    LDY ScoreRow          ; 3 cycles
    LDA ScoreBuf+0,Y      ; 4
    STA WSYNC             ; the setup/blank line, then one row's line
    STA GRP0              ; column 0
    LDA ScoreBuf+8,Y
    STA GRP1              ; column 1
    LDA ScoreBuf+16,Y
    STA GRP0              ; column 2
    LDA ScoreBuf+24,Y
    STA ScoreTmp          ; hold column 3
    LDA ScoreBuf+32,Y
    TAX                   ; hold column 4
    LDA ScoreBuf+40,Y
    LDY ScoreTmp
    NOP
    CPX ScoreRow          ; timing only
    STY GRP1              ; column 3
    STX GRP0              ; column 4
    STA GRP1              ; column 5
    STA GRP0              ; flush
    DEC ScoreRow
    BPL ScoreDrawLine
```

The `STA WSYNC` is the WSYNC-first exception: the first iteration's WSYNC ends visible
line 0, and the stores after it execute on visible line 1 and are displayed there. (The
write cycles in Section 2 are 1-based; Stella's breakpoint column reports the instruction
start, which is why the `ScoreDrawRow` stall at 37/26 becomes a store at 38/0.) The loop
runs eight times (Y=7 down to 0); row 7 is displayed on visible line 1 and row 0 on
visible line 8. The cleanup then writes `GRP0=0`, `GRP1=0`, `VDELP0=0`, and `VDELP1=0`
after line 8's copies have gone by. The RTS is at line 8, cycle 75 — the last cycle of
the score zone.

#### Step 5 — The game zone

The caller resumes on visible line 9. The first game-zone line writes the blank
playfield bytes and `ENABL=0`; the same values are already in the registers, so the
only visible effect is none. The top background loop runs **141** times, ending on
visible line 149. The next line writes `PF2=$F0` and `ENABL=2` in HBLANK, so visible
line 150 is the target's first line. Eight `WSYNC`s hold the target and ball through
visible line 157. The bottom loop turns both off and runs **34** times, ending on
visible line 191. The next instruction is `OverscanStart` at scanline 229.

The target's eight lines and the ball's eight rows are the same lines, which is what
makes the collision possible. The ball is one pixel wide, so its capture run is six
pixels wide (one TIA pixel × the 6-pixel capture scale); the target is 32 TIA pixels
wide, or 192 capture pixels.

#### Step 6 — The auto-demo and the score

The ball starts at X=24. On the first pass it reaches X=64 after 20 frames, which is
the target's left edge. The collision latch sets on that visible frame; the next
VBLANK reads it, adds one, beeps, and respawns the ball at 24. The score is now
**000001**. Twenty frames later the ball reaches the target again and the score becomes
**000002**. The same cycle continues: 000003, 000004, and so on.

The auto-demo is why the captures are reproducible. The joystick still works: holding
left or right moves the ball two pixels per frame and clamps it at the ends. A hit
during manual play behaves exactly like a hit during the demo.

#### Step 7 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F025` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F033` | 0, cycle 5 | VBLANK's first line |
| `ScoreInit` | `$F154` | once at reset (frame 0) | the library's clear |
| `ScoreDigitWrite` | `$F1C1` | reset: A=0…5, X=0; hits: A=5, X=1,2,3… | position and digit |
| `ScoreAdd` | `$F1F3` | A=1 at frame 22; 2 at 42; 3 at 62; 0 then 1 at the 9→10 carry | the digit after the add |
| `BallHit` | `$F04E` | A=`$80` at frames 22, 42, 62, 82 | the `CXBLPF` bit |
| `BodyStart` | `$F0EE` | **37, cycle 5** | visible line 0 |
| `ScoreDraw` | `$F20A` | 37, cycle 11 | the kernel call |
| `ScoreDrawRow` | `$F215` | first break 37/26 = the WSYNC stall; the store executes at 38/0, then 39/0, 40/0, … with A=`$3C,$66,$6E…` | the first row's bytes |
| `HmoveApply` | `$F1BE` | line 4, cycle 45 | the WSYNC stall |
| `HmoveDone` | `$F1C0` | **line 5, cycle 3** | the `HMOVE` store |
| `OverscanStart` | `$F11E` | **229, cycle 4** | overscan's first line |

`ScoreDraw` fires on visible line 0 (the setup line). `ScoreDrawRow`'s first breakpoint
at 37/26 is the WSYNC stall; the store itself executes at 38/0 and draws row 7 on
visible line 1. The next iterations stage at 39/0, 40/0, and so on; each row is
displayed on the same line its stores execute.

## What You Should See

The scoreboard is a dark field with a white six-digit score across the top, a gold
32-pixel target near the bottom, and a thin gold ball on the same rows. The ball sweeps
left and right when the joystick is idle; each pass through the target adds one to the
score and starts a short beep.

**000001.** The score block is a white 6-digit row at capture x=367–642, y=110–130.
The first digit is a 0, the last is a 1. The target is the gold block at capture
x=409–600, y=580–604 (TIA X=64–95, visible lines 150–157). The ball is the thin gold
run at capture x=289–294, y=580–604 — one TIA pixel wide, eight rows tall, at TIA X=44
in this capture.

![Stella running the Lesson 39 ROM after the first hit: a white six-digit score reading 000001, a gold 32-pixel target, and a thin gold ball at the same rows](/images/lesson39/score-a.png)

*The first hit: the score reads 000001, the target spans TIA X=64–95, and the ball is
mid-sweep at TIA X=44. Captured from the committed ROM.*

**000002.** One hit later the same block reads 000002. In this capture the ball is at
TIA X=36 (capture x=241–246), still on the same eight target rows; the score's last
digit has changed from 1 to 2, while the score block and the target are unchanged. The
ball is at a different point in its sweep (TIA X=36 vs TIA X=44).

![Stella running the Lesson 39 ROM after the second hit: the six-digit score reads 000002 with the same gold target and ball](/images/lesson39/score-b.png)

*The second hit: 000002. The ball has respawned at the left and is sweeping right
again; the target and the score block are unchanged. Captured from the committed ROM.*

The auto-demo keeps going. The state log shows the score climbing one per hit:
`ScoreAdd` A=1 at frame 22, 2 at 42, 3 at 62, and so on. The carry is visible at
frame 202: `ScoreAdd` reports A=0 for the rightmost digit (9 → 0), then A=1 for the next
digit (0 → 1), so 000009 becomes 000010; the next hit reports A=1 again and makes
000011. That is the state-log evidence for the carry; the committed captures in this
lesson are the 000001 and 000002 pair above.

<RomPlayer rom="/roms/part6-game-dev/39-scoreboard/39-scoreboard.bin" title="Lesson 39 — The Scoreboard" />

Click the player screen once: Javatari starts muted until a user gesture, and the hit
beep begins when you click. The ball sweeps on its own; hold left or right on the
joystick to take over.

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson39.sym -o build/lesson39.bin \
  lessons/part6-game-dev/39-scoreboard/39-scoreboard.asm
grep -E "StartFrame|ScoreInit|ScoreDigitWrite|ScoreAdd|BallHit|BodyStart|ScoreDraw|HmoveDone|OverscanStart" build/lesson39.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1F3' \
  docs/public/roms/part6-game-dev/39-scoreboard/39-scoreboard.bin
```

With the debugger open on a visible frame, the score's state is in `$A0–$A5` (the six
digits), `$A8–$D7` (the six columns × eight rows), and the TIA's `NUSIZ0`/`NUSIZ1` = 3
with `VDELP0`/`VDELP1` = 1 while the score is drawn.

- **`$F025` (`StartFrame`)**: scanline 259, cycle 3 — the first VSYNC line of a
  262-line frame.
- **`$F033` (`VblankStart`)**: scanline 0, cycle 5 — the first VBLANK line.
- **`$F1C1` (`ScoreDigitWrite`)**: at reset A=0,1,2,3,4,5 with X=0 — the six calls from
  `ScoreClear`. On a hit A=5 and X=1, then 2, 3, … — the rightmost digit's new value.
- **`$F1F3` (`ScoreAdd`)**: A=1 at frame 22, 2 at 42, 3 at 62; the 000009→000010 carry
  reports A=0 then A=1 in the same call.
- **`$F04E` (`BallHit`)**: A=`$80` at frames 22, 42, 62, 82 — `CXBLPF` bit 7.
- **`$F0EE` (`BodyStart`)**: scanline 37, cycle 5. **`$F11E` (`OverscanStart`)**:
  scanline 229, cycle 4 — the 262-line frame and the 9 + 183 picture split.
- **`$F1C0` (`HmoveDone`)**: line 5, cycle 3 — one `HMOVE` per frame for the two
  players and the ball.

## Exercises

### Exercise 1: Set a Score

**Challenge:** call `ScoreSetDigit` six times at reset so the scoreboard reads
**012345** before the first hit.

**Hints:**
1. `ScoreSetDigit` takes A = position (0 = leftmost) and X = digit (0–9).
2. The six calls are (A,X) = (0,0), (1,1), (2,2), (3,3), (4,4), (5,5).
3. Put the calls after `ScoreClear`; the hit path stays unchanged, so the first hit
   makes 012346.

**Expected Result:** the capture reads 012345. `ScoreDigitWrite` logs twelve calls at
reset — six from `ScoreClear` with X=0 (A=0…5), then the exercise's six with X=0…5
(A=0…5) — and A=5, X=6 on the first hit. The rest of the screen is the main ROM's.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Double Score

**Challenge:** call `ScoreAddOne` twice per hit, so every contact adds two points.

**Hints:**
1. The hit path is the `BallHit` block; add a second `JSR ScoreAddOne` after the first.
2. The two calls are independent. The first may carry through several digits; the
   second starts at the rightmost digit again.
3. The once-per-contact guard is the VBLANK read plus `CXCLR`: the latch is read once
   and cleared, so one contact produces one pair of adds.

**Expected Result:** the score starts at 000000; the first hit makes **000002**, the
second **000004**. `ScoreAdd` fires twice per hit. The decimal carry still works: a
digit that reaches 10 wraps to 0 and carries left. At 000098 the first add makes
000099 (units 8 → 9) and the second makes 000100 (units 9 → 0, carry; tens 9 → 0,
carry), so the units digit does carry. The library's carry path is the same one the
main ROM exercises at 000009 → 000010.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Leading Blanks *(Stretch Goal)*

**Challenge:** add a `ScoreBlank` call so leading zero columns are dark. **000042**
should display as `    42` — four blank columns followed by the 4 and the 2.

**Hints:**
1. `ScoreBlank` takes A = position and fills that column with eight zero bytes; it
   does not change `ScoreDigits`.
2. Walk from position 0 while `ScoreDigits` is zero, blanking each column; stop at the
   first nonzero digit.
3. Call the walk after `ScoreClear` and after every `ScoreAddOne`, so a carry that
   turns a leading zero into a one leaves that column drawn (000099 + 1 → `   100`).

**Expected Result:** the reset capture reads `    42` (four blank columns, then 4 and
2); the next hit reads `    43`. `ScoreDigitWrite` still logs the changed column;
`ScoreAdd` reports the carry as usual. The `.bin` still assembles to exactly 4,096
bytes.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **Six digits from two players**: `NUSIZ=3` gives three close copies each; P1 offset by 8 pixels interleaves them into six 8-pixel columns
- ✅ **VDEL is a cross-latch**: a write stages a pending byte and the other player's write commits it, so the kernel can place each column just before its copy is drawn
- ✅ **The kernel is cycle-timed**: the first three stores land in HBLANK seven cycles apart, and the last four are a three-cycle run; the `NOP` and `CPX` are part of the schedule
- ✅ **The buffer is column-major and bottom-up**: `ScoreBuf` stores six columns of eight rows, and every glyph's bottom row is blank
- ✅ **The carry is decimal**: `ScoreAddOne` wraps 9 to 0, carries left, and returns C=1 on 999999 → 000000
- ✅ **Nine score lines + 183 game lines**: the score kernel is the WSYNC-first exception; the game zone is work-first and 183 lines long
- ✅ **A hit is one frame old**: read `CXBLPF` in VBLANK, then `CXCLR`; the score, the beep, and the respawn all happen once per contact

## What's Next

The scoreboard keeps its number as six separate binary digits, and `ScoreAddOne`
handles the carry itself. [Lesson 40: BCD Arithmetic](/part6-game-dev/40-bcd-arithmetic)
replaces that loop with three BCD bytes, `SED`/`CLD`, and `ADC`/`SBC` across the bytes,
then rebuilds the same six columns with `ScoreSetDigit`.
