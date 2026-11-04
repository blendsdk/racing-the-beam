---
title: "Lesson 25: Player Sprite Basics — GRP0, Your First Character"
description: "A player sprite is eight bits wide and one scanline tall per write. Lesson 25 draws the first invader from an eight-byte shape table, places it with a fixed RESP0 delay, and shows why the graphic register must be cleared after the last row."
prev:
  text: "Lesson 24: The Multicolor Playfield"
  link: "/part3-playfield/24-multicolor-playfield"
next:
  text: "Lesson 26: Horizontal Positioning"
  link: "/part4-sprites/26-horizontal-positioning"
---

# Lesson 25: Player Sprite Basics — GRP0, Your First Character

> **Part 4: Sprites** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 13 (the color byte), Lesson 18 (write positions and hit cycles), Lesson 19 (the playfield registers and bit order), Lesson 21 (per-line register writes)
> **You will learn:** the `GRP0` graphic register and its bit order; why a sprite is eight pixels wide and one scanline tall per write; how a shape table becomes a character; why the graphic register must be cleared after the last row; the counted top/body/bottom kernel
> **You will build:** "first contact" — a red 8×8 invader on a dark field, positioned by a fixed `RESP0` delay; plus three exercises: move it down, mirror it, and draw two creatures with one player

## Introduction

Part 3 drew the background. Part 4 adds the objects that move on it. The first object is the
**player**: a sprite exactly eight pixels wide, with one byte of graphics per scanline. There is
no sprite engine and no frame buffer — you write `GRP0` on the lines where the sprite should
appear, and the TIA paints those pixels at the player's horizontal position.

That gives the two dimensions of sprite programming:

- **Vertical position is a schedule.** A write on scanline 117 draws the sprite on scanline 117.
  Eight writes, one per line, make an eight-line-tall character.
- **Horizontal position is a strobe.** `RESP0` sets the player's position to wherever the beam is
  when you write it. This lesson uses a fixed delay and tunes it by hand; Lesson 26 replaces the
  delay with the proper divide-by-15 routine.

The companion program `25-player-basics.asm` makes the model visible: one red invader, eight
scanlines tall, with a dark field around it. The interesting part is not the shape — it is the
counted loop that decides *when* each row is written.

::: details TypeScript Equivalent
A sprite is an array of row bytes, and the kernel is a loop with a line counter:

```typescript
const shape = [0x18, 0x3c, 0x7e, 0xdb, 0xff, 0x24, 0x5a, 0xa5];
const TOP = 80, HEIGHT = 8;

function grp0ForLine(line: number): number {
  const row = line - TOP;
  return row >= 0 && row < HEIGHT ? shape[row] : 0;
}

// The 2600 kernel is the same table lookup, unrolled over 192 scanlines:
// it writes GRP0 once per line and parks on WSYNC.
```

The analogy breaks at the "line" argument: the 2600 has no line variable to test. The kernel's
position in the code *is* the line number, because every iteration parks on `WSYNC`.
:::

## Theory

### Section 1: Eight Pixels, One Byte

`GRP0` is an 8-bit write register. Each bit is one pixel, and **bit 7 is the leftmost pixel**:

| Byte | Binary | Pixels (left → right) |
|---|---|---|
| `$18` | `00011000` | off off off on on off off off |
| `$3C` | `00111100` | off off on on on on off off |
| `$FF` | `11111111` | eight pixels on |

A player's graphic is 8 bits per line, so with `NUSIZ = 0` it draws as eight pixels. `NUSIZ` can
draw it double or quad width, or add copies (Lesson 31). `REFP0` bit 3 mirrors the player; it
stays clear here, and Exercise 2 uses it. For now: one player, eight pixels, one byte per line.

The sprite's horizontal span in the course captures is therefore 8 × 6 = **48 pixels**. A player
at TIA X appears at capture x = 25 + 6·X; the same mapping the playfield used, because both are
measured in color clocks.

### Section 2: Vertical Position Is a Schedule

The TIA has no vertical position register for sprites. It draws whatever `GRP0` holds on the
current line. The register holds its value until you change it, so:

- writing `$18` on line 117 draws `$18` on line 117;
- leaving `$18` in the register draws it again on line 118;
- writing `$3C` on line 118 changes the next row.

A sprite's height is the number of scanlines on which `GRP0` holds a non-zero byte. Consecutive
identical rows need only one write; the eight-row invader uses eight writes, one per distinct
row. The vertical position is the first line of that run.

This is why the kernel is a counted loop: the top loop parks the lines above the sprite, the body
loop writes the eight rows, and the bottom loop parks the rest. The counts add up to 192:

```
80 top + 8 body + 1 clear + 103 bottom = 192
```

### Section 3: The Shape Table

The eight rows live in ROM as a byte table:

```
$18  $3C  $7E  $DB  $FF  $24  $5A  $A5
```

The kernel reads `SpriteShape,X`, stores it to `GRP0`, and increments X. The table is the
character; the loop is the pen. Changing the table changes the character without touching the
kernel — the same separation Part 3 used for playfield rows and color tables.

The first row `$18` is a narrow top; `$3C` and `$7E` widen it; `$DB` is the middle band; `$FF` is
the solid band; `$24`, `$5A`, and `$A5` are the legs. Every row of this invader is a bit-reversal
palindrome — `$DB` reversed is `$DB`, and so on — so the whole creature is left-right symmetric.
A mirror of it would be pixel-identical, which is why Exercise 2 gives the creature an asymmetric
tail before flipping `REFP0`.

### Section 4: Clear the Register

`GRP0` is a register, not a one-shot. If the body writes `$A5` on the last row and the bottom loop
never writes again, the TIA keeps drawing `$A5` on every line below the sprite — a long smear
instead of a character. The kernel therefore writes **zero** once after the body and parks that
line:

```asm
    LDA #$00
    STA GRP0                ; clear the last row
    STA WSYNC               ; the clear line
```

This is the first sprite lesson's most common bug. The clear line is part of the vertical budget:
`80 + 8 + 1 + 103 = 192`. The bottom loop's count is one smaller than a naive
`192 − top − height`.

### Section 5: The Frame and the Placeholder Placement

The frame is the course standard: 3 VSYNC lines, 37 VBLANK lines (`TIM64T` = 44), 192 visible
lines, 30 overscan lines (`TIM64T` = 36). The sprite's first body line is visible line 80, i.e.
Stella scanline 117.

Horizontal placement is deliberately a placeholder here. After a `WSYNC`, a nine-iteration `DEX`/`BNE` pad and the strobe take 49 cycles from the line
start to the write effect
(2 + 44 + 3), so the write lands at clock 147. `RESP0` sets player 0's position to the beam's
clock, and the player's fixed 5-clock output delay puts the left edge at clock 152 — TIA X = 84
(capture x = 529), close to the intended ≈81. Lesson 26 derives the divide-by-15 routine that
replaces this guess with a repeatable calculation.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson25.bin \
  lessons/part4-sprites/25-player-basics/25-player-basics.asm
stella build/lesson25.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 25: Player Sprite Basics — GRP0, Your First Character — Racing the Beam
; =============================================================================
; Part 4: Sprites
;
; What this program does:
;   Draws the first player sprite: a red 8x8 invader on a dark background.
;   The shape is eight bytes in ROM; the kernel writes one byte to GRP0 on
;   each of the sprite's eight scanlines.  The sprite is 8 pixels wide, and
;   bit 7 of each byte is the leftmost pixel.
;
; The two dimensions of a sprite:
;   - HORIZONTAL position is where the player's position counter sits.  This
;     lesson places it with a fixed coarse delay (see below); Lesson 26
;     replaces that with the proper divide-by-15 routine.
;   - VERTICAL position is WHEN you write GRP0.  A write on scanline N makes
;     the sprite appear on scanline N (at its horizontal position).  Eight
;     writes, one per line, make an eight-line-tall shape.
;
; Why the shape is a table:
;   A player is only 8 bits wide, so a character is a list of bytes, one per
;   scanline.  The kernel walks the list with X and stores each byte to GRP0.
;   The table is the picture; the loop is the pen.
;
; The frame is the course standard (262 lines):
;   VSYNC 3, VBLANK 37 on TIM64T = 44, visible 192, overscan 30 on TIM64T = 36.
;   The sprite sits at visible line 80 (scanline 117), so the top loop parks
;   80 lines, the body draws 8, the clear line parks 1, and the bottom loop
;   parks the remaining 103.
;
; This lesson's placement (a placeholder):
;   After a WSYNC, a short DEX/BNE pad delays the RESP0 strobe.  RESP0 sets
;   the player's position to wherever the beam is, plus the player's fixed
;   output delay.  The pad is tuned to land near X=81; Lesson 26 derives the
;   exact divide-by-15 routine.  The measured landing is recorded in the doc.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VisibleStart (37), BodyStart (117,
;   the first sprite line), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson25.bin \
;        lessons/part4-sprites/25-player-basics/25-player-basics.asm
; Run:   stella build/lesson25.bin
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
SPRITE_TOP     = 80     ; blank visible lines above the sprite
SPRITE_HEIGHT  = 8      ; the invader is eight scanlines tall

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the placeholder placement: a fixed delay, then strobe RESP0 ---
    STA WSYNC               ; start the delay on a fresh line
    LDX #9                  ; LDX 2 + nine DEX/BNE (44) + STA (3) = 49 cycles
PlaceDelay:
    DEX
    BNE PlaceDelay
Resp0Write:                 ; checkpoint: the RESP0 store starts at cycle 46
    STA RESP0               ; write effect at cycle 49 -> clock 147; +5 -> X=84
    LDA #$42
    STA COLUP0              ; red
    LDA #$02
    STA COLUBK              ; dark neutral
    LDX #$00
    STX NUSIZ0              ; one copy, normal width (explicit, though cleared)
    STX REFP0               ; not mirrored

    +wait_timer             ; wait out line 36, then park it

; -----------------------------------------------------------------------------
; VISIBLE — top blank lines, 8 sprite lines, bottom blank lines
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
    LDX #SPRITE_TOP
VisibleStart:               ; debugger checkpoint: the picture's first line (37)
TopLoop:
    STA WSYNC               ; park one line
    DEX
    BNE TopLoop

    LDX #0
BodyStart:                  ; debugger checkpoint: the first sprite line (117)
BodyLoop:
    LDA SpriteShape,X       ; this line's 8 pixels
SpriteWrite:                ; checkpoint: A = the row byte, 8 hits per frame
    STA GRP0                ; draw them
    STA WSYNC               ; park the rest of the line
    INX
    CPX #SPRITE_HEIGHT
    BNE BodyLoop

    LDA #$00
    STA GRP0                ; clear the last row; GRP0 holds its value
    STA WSYNC               ; the clear line

    LDX #(VISIBLE_LINES - SPRITE_TOP - SPRITE_HEIGHT - 1)
BottomLoop:
    STA WSYNC
    DEX
    BNE BottomLoop

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
; SPRITE SHAPE — eight rows, bit 7 is the leftmost pixel
; =============================================================================
SpriteShape:
    !byte %00011000         ; $18
    !byte %00111100         ; $3C
    !byte %01111110         ; $7E
    !byte %11011011         ; $DB
    !byte %11111111         ; $FF
    !byte %00100100         ; $24
    !byte %01011010         ; $5A
    !byte %10100101         ; $A5

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
> `lessons/part4-sprites/25-player-basics/25-player-basics.asm`.

### Code Walkthrough

#### Step 1 — The frame

`+vsync` produces the three-line sync pulse; `+set_timer 44` and `+wait_timer` hold VBLANK for 37
lines; the release is `LDA #$00` / `STA VBLANK` on line 37; `+set_timer 36` and `+wait_timer` hold
the 30-line overscan. The measured frame is 262 lines: `StartFrame` at 259, `OverscanStart` at
229.

#### Step 2 — The placement delay

`STA WSYNC` starts a fresh line. `LDX #9` takes 2 cycles, the nine `DEX`/`BNE` iterations take 44
(eight taken branches at 5 cycles and a final 4), and `STA RESP0` takes 3 — 49 cycles to the write
effect. The write lands at clock 147. `RESP0` sets player 0's position to the beam's clock, and
the player's fixed 5-clock output delay puts the left edge at clock 152: TIA X = 152 − 68 = 84.
The value written does not matter — `RESP0` is a strobe.

#### Step 3 — The top loop

`LDX #SPRITE_TOP` and the `STA WSYNC` / `DEX` / `BNE` loop park exactly 80 visible lines. Each
iteration parks one line, so the first body iteration starts on line 117.

#### Step 4 — The body

`LDA SpriteShape,X` / `STA GRP0` writes one row; `STA WSYNC` parks the line; `INX` / `CPX #8` /
`BNE` repeat eight times. The `SpriteWrite` label fires at cycle 10 on the first row (A = `$18`),
and the store's effect begins at cycle 13 — clock 39. The sprite's left edge is at clock 152
(X = 84), so the data is in place more than a hundred clocks early.

#### Step 5 — The clear and the bottom

After the eighth row, the kernel writes zero to `GRP0` and parks one more line. The bottom loop
parks the remaining 103 lines. The picture is exactly eight rows tall; without the clear line it
would be 111 rows tall, because the last byte would stay in the register.

#### Step 6 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `VisibleStart` | `$F049` | 37, cycle 7 | the picture's first line |
| `BodyStart` | `$F050` | **117, cycle 6**; 8 hits per frame | the first sprite line |
| `SpriteWrite` | `$F053` | 117, cycle 10; 8 hits per frame; A = the row byte | the `GRP0` store |
| `Resp0Write` | `$F02C` | line 1, cycle 46; the write effect at 49 | the placeholder `RESP0` strobe |
| `OverscanStart` | `$F069` | 229, cycle 4 | overscan's first line |

The capture gives the other half: the red pixels occupy capture x = **529–576** (48 px wide) and
y = **359–383** (25 px tall). That is TIA X = (529 − 25) / 6 = **84**, and 8 scanlines at the
capture's ~3.15 px per line.

## What You Should See

A single red invader on a dark field, about two-fifths of the way down the picture (visible line
80 of 192). It is 48 capture pixels wide and 25 tall — eight scanlines — and nothing is drawn
below it. The background is the
dark neutral `$02`; the sprite is `$42` red.

![Stella running the Lesson 25 ROM: a red 8×8 invader on a dark field](/images/lesson25/first-sprite.png)

*First contact, captured from the committed ROM: the red invader at capture x = 529–576 and
y = 359–383. The measured TIA X is 84 (the fixed-delay target was ≈81, within the ±4 tolerance);
the first body line is Stella scanline 117.*

<RomPlayer rom="/roms/part4-sprites/25-player-basics/25-player-basics.bin" title="Lesson 25 — Player Sprite Basics" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson25.sym -o build/lesson25.bin \
  lessons/part4-sprites/25-player-basics/25-player-basics.asm
grep -E "BodyStart|VisibleStart|OverscanStart" build/lesson25.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F050' \
  docs/public/roms/part4-sprites/25-player-basics/25-player-basics.bin
```

- **`$F050` (`BodyStart`)**: the first body line, scanline 117, cycle 6. It fires eight times per
  frame, once per row.
- **`$F053` (`SpriteWrite`)**: the `GRP0` store. Eight hits per frame at cycles 10–11; A = the row
  byte (`$18` on the first row, `$3C` on the second).
- **`$F02C` (`Resp0Write`)**: the placement strobe on VBLANK line 1, instruction start cycle 46;
  the write effect lands at cycle 49.
- **`$F049` (`VisibleStart`)**: line 37 every frame; the top loop starts there.
- **`$F069` (`OverscanStart`)**: line 229 — 192 visible lines, with the blank-on inside HBLANK.

## Exercises

### Exercise 1: Move the Sprite Down

**Challenge:** draw the same invader 40 scanlines lower, without changing the shape.

**Hints:**
1. Vertical position is the top loop's count. Raise `SPRITE_TOP` from 80 to 120.
2. The bottom count is computed from `VISIBLE_LINES - SPRITE_TOP - SPRITE_HEIGHT - 1`; it shrinks
   automatically, so the frame stays 192 lines.
3. The clear line stays one line; only the split between top and bottom changes.

**Expected Result:** the first body line moves from 117 to 157 (capture y ≈ 485); the measured
capture is y = 486–509, same x = 529–576. The frame is unchanged at 262 lines.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Mirror the Sprite

**Challenge:** flip the invader horizontally.

**Hints:**
1. `REFP0` bit 3 mirrors player 0. Write `$08` to `REFP0` in VBLANK.
2. The lesson's invader is left-right symmetric, so flipping it alone changes nothing. Give the
   creature an asymmetric tail first: change the last two shape bytes to `$0F` and `$F0`.
3. With the tail in place, the TIA reads each byte from the other end; the last two rows swap
   sides while the symmetric rows stay put.

**Expected Result:** the same 48-pixel span at x = 529–576 and y = 359–383, with the tail
mirrored. Measured in a scratch capture: the second-to-last row displays `11110000` and the last
row `00001111` — exactly the reverse of the shape table's `$0F`/`$F0` tail.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Two Creatures *(Stretch Goal)*

**Challenge:** draw two creatures with the same player.

**Hints:**
1. Vertical reuse: write `GRP0` in two separate bands. The top loop parks 56 lines; the first
   body draws 8; a clear line; a 31-line gap; the second body; a clear line; the remaining 87
   lines (56 + 8 + 1 + 31 + 8 + 1 + 87 = 192).
2. The second body starts 40 scanlines below the first (8 rows + the clear + the 31-line gap).
3. Keep the clear line after each body, or the first creature's last row will smear into the gap.

**Expected Result:** two red invaders at capture y = 284–307 and y = 410–433, both at
x = 529–576, 40 scanlines apart. The measured bodies are at scanlines 93 and 133, and the frame
stays 262 lines (`OverscanStart` at 229).

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A player is eight pixels wide**: one byte per scanline, `GRP0` bit 7 leftmost; the sprite spans 48 capture pixels
- ✅ **Vertical position is when you write**: one write per line, and the first non-zero write is the sprite's top
- ✅ **The shape is a table**: eight bytes in ROM; changing the table changes the character without touching the kernel
- ✅ **The register holds**: clear `GRP0` after the last row, or the last byte smears down the rest of the screen
- ✅ **The vertical budget is exact**: top + body + clear + bottom = 192 visible lines; the clear line is part of the count
- ✅ **Horizontal position is a separate problem**: `RESP0` sets it, and this lesson's fixed delay is a placeholder for Lesson 26's routine

## What's Next

The invader is stuck near x = 529. [Lesson 26: Horizontal Positioning](/part4-sprites/26-horizontal-positioning)
replaces the hand-tuned delay with the classic divide-by-15 routine: one subtraction loop measures
the distance in 15-clock steps, `HMP0` carries the remainder, and `HMOVE` applies it. The sprite
will visit five exact positions, and every one will be measured.
