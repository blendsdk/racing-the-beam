---
title: "Lesson 73: The HMOVE Comb & the Cosmic Ark Starfield"
description: "Walk one missile and the ball across the screen with a per-line HMOVE motion table: the stars are the accumulated motion, the eight-pixel bar is the HMOVE blanking, and a second visible-line strobe stalls the not-yet-drawn pixels rightward."
prev:
  text: "Part 11: Legendary Techniques"
  link: "/part11-legendary/"
next:
  text: "Lesson 74: Skipdraw — The Classic Sprite Kernel Idiom"
  link: "/part11-legendary/74-skipdraw-kernel"
---

# Lesson 73: The HMOVE Comb & the Cosmic Ark Starfield

> **Part 11: Legendary Techniques** · Estimated time: 150 minutes
> **Prerequisites:** Lesson 12 (the NTSC frame), Lesson 14 (WSYNC and scanline timing), Lesson 17 (cycle counting and page-cross costs), Lesson 18 (mid-scanline changes), Lesson 26 (horizontal positioning, RESP and HMOVE), Lesson 29 (missiles and the ball), Lesson 31 (copies and sizes), Lesson 42/47 (SELECT and the auto-demo pattern), Lesson 54 (starfields and the effects reel)
> **You will learn:** how one missile in three-copy close mode and the ball become a whole star field without a per-line reset; how a per-line HMOVE motion table moves the objects and why their X is the accumulated motion; why the eight-pixel bar is present in both captures and why the strobe must be early in HBLANK; what a visible-line HMOVE really does — plugging that stalls the not-yet-drawn pixels rightward, bounded per line — and how far that is from a simple "re-apply the motion"; and how the 192-line budget holds a 160-line one-line star kernel plus a 32-line planet loop.
> **You will build:** "the starfield" — a 4,096-byte ROM with a 160-line field of white and bright-blue single-pixel stars over a green/brown planet limb and a small red ship, a slowly cycling blue sky, and a drifting mask. The stars are one missile and the ball, positioned once and then walked by a pseudo-random HMOVE motion table; the eight-pixel HMOVE bar is on every star line. SELECT toggles a second visible-line HMOVE; an auto-demo turns it on once at frame 240, so the first capture is the single-strobe walk and the second shows the stalled field. Plus two complete exercise solutions: a denser walk field with a per-band star colour, and a faster vertical scroll with a twinkle.

## Introduction

Lesson 54 drew a starfield with the playfield: three page-aligned 256-byte planes, one byte per line, and a scrolling world row. Cosmic Ark, Imagic's 1982 sequel to *Atlantis*, did something stranger and much cheaper. Its starfield comes from a TIA positioning exploit that Rob Fulop found while working on *Demon Attack*: the graphics chip's object-positioning logic can be made to generate extra clocks, and the stars are the result of moving a handful of objects around the screen. *Racing the Beam* tells the story; the effect became a signature, and emulators had to reproduce the bug faithfully.

This lesson rebuilds the look, not the exact cartridge. The stars are missile 0 in three-copy close mode (three one-pixel copies at X, X+16 and X+32, all modulo 160) and the ball (a fourth star). The objects are positioned **once**. On every visible line the kernel writes a motion value to `HMM0` and `HMBL` and strokes `HMOVE`; the TIA re-applies the motion, so each object's X is the accumulated motion of the table. A pseudo-random motion table makes the walk scatter instead of tracing a single diagonal. A 24-byte line mask decides which lines show the objects; adjacent star lines are legal because the objects never need re-positioning. The eight-pixel bar at the left is the HMOVE blanking, and it is present on every star-band line in **both** captures — it is the technique's real signature, not a mode.

The second state is a second `HMOVE` in the visible line with `HMM0` and `HMBL` set to `$40`. That is not a second "four pixels left": in the visible area the extra clocks **plug MOTCK** and delay the pixels that have not yet been drawn, rightward. The stall is bounded by the line and depends on where each star's pixel falls relative to the strobe, so the field's stars jump by large, line-dependent amounts. The companion program `73-cosmic-ark-starfield.asm` makes both states visible: `starfield.png` is the single-strobe walk, and `comb.png` is the same ROM after the frame-240 auto-demo has switched the second strobe on.

::: details TypeScript Equivalent

The natural model is a point with a velocity table and a per-line draw:

```typescript
const MOTION: number[] = [/* 160 per-line displacements, +left / -right */];
const MASK: boolean[] = [/* 160 line bits, 34 true */];

let x = 78;                      // the measured starting X of M0 (the table's design point is 73)
function drawFrame(): void {
  for (let y = 0; y < 160; y++) {
    x = (x - MOTION[y] + 160) % 160;  // positive motion moves left
    if (MASK[y]) {
      drawPixel(x, y, WHITE);          // M0 copy 0
      drawPixel((x + 16) % 160, y, WHITE);
      drawPixel((x + 32) % 160, y, WHITE);
      drawPixel(ballX[y], y, BLUE);    // the ball's own motion table
    }
    waitScanline();
  }
}
```

The analogy breaks in four places. There is no framebuffer: `drawPixel` is not a memory write but a TIA latch, and the pixel appears only if the object's position counter says so. The motion is not a variable the CPU owns: `HMOVE` is a strobe that reads the five motion registers and shifts the objects, and the register value is consumed by the hardware, not stored in a position variable. The TIA has one missile and one ball, not 160 object slots: the three copies come from `NUSIZ0`'s copy mode. And the eight-pixel bar and the visible-line stall are hardware side effects of the strobe, not anything a per-pixel draw can express. A JavaScript loop can take as long as it likes; a 2600 kernel has 76 cycles per line.

:::

## Theory

### The Cosmic Ark story: a bug turned into a signature

Cosmic Ark shipped from Imagic in 1982, designed and programmed by Rob Fulop as a sequel to *Atlantis*. The game alternates meteor defence with shuttle rescue missions, but its most quoted feature is the background: a moving starfield that seems to cost the cartridge almost nothing. Fulop has said the effect came from an unusual behaviour he found in the TIA while working on *Demon Attack*: the object-positioning logic can be made to generate extra clocks, and with the right register writes those clocks scatter a handful of objects into a field of stars. *Racing the Beam* (Bogost and Montfort, MIT Press, 2009) discusses the effect; AtariAge's programming threads and the emulator community's TIA notes document the register behaviour.

What is documented is the *idea*: a TIA positioning exploit that moves objects by re-strobing the motion hardware, not a stored bitmap. What is not documented, at least not in a form this course can cite as a register sequence, is the exact Cosmic Ark program. This lesson therefore makes a narrower claim. It reproduces the *look* — a sparse field of single-pixel stars, four per active line, from one missile and the ball, moved by repeated `HMOVE` strobes, with the eight-pixel bar and a second-strobe stall — and it verifies each mechanism in Stella. It does **not** claim to be bit-exact with the 1982 cartridge, and it does not copy the cartridge's code or art. The ship and the planet are original shapes.

::: tip What "the comb" means here

The name comes from the bars the effect leaves at the left of the screen. In this ROM the HBLANK `HMOVE` on every line blanks the leftmost eight pixels, so the bar is a solid notch on all 160 star-band lines in both states. The second `HMOVE` in the visible line does not widen that bar; it stalls the not-yet-drawn pixels rightward and shifts the field. The bar is the HBLANK signature; the second strobe is the visible-line artifact.

:::

### The HMOVE walk

`HMOVE` is a strobe at `$2A`. It applies five motion registers — `HMP0`, `HMP1`, `HMM0`, `HMM1`, `HMBL` — to the five moving objects. The high nibble of each register is a signed offset: `$00` is no move, `$10`–`$70` move left one to seven pixels, and `$F0`–`$80` move right one to eight. The course's rule from Lesson 26 is simple: **strobe `HMOVE` immediately after `WSYNC`**, so it runs in horizontal blank, and **do not rewrite a motion register for about 24 cycles after the strobe**.

The walk uses the strobe as the motion itself. Position missile 0 and the ball once. Then, on every visible line, write the line's motion value to `HMM0` and `HMBL` and stroke `HMOVE`. The TIA applies the motion to each object's current position; the object keeps the new position until the next strobe. The X of the star on line `L` is therefore the accumulated sum of the table's values:

```
X[L] = X[start] - sum(MOTION[0..L])      (positive motion moves left)
```

The table is 160 bytes, one per visible line, plus a sentinel for the last `+1` load. The star and the ball have their own tables. The star table uses `$00` (no move), `$10`–`$50` (left 1–5) and `$B0`–`$F0` (right 5–1); the ball table uses `$20`–`$60` (left 6–2) and `$A0`–`$E0` (right 6–2). The two tables are page-aligned, so `LDA/LDY abs,X` is four cycles and never crosses a page.

The walk is **closed**. The initial position is the last line's position, so after 160 lines the object is back where it started and the next frame needs no re-positioning. The main ROM's measured start is **M0 X = 78** and **ball X = 83**; the table's design points are `STAR_START = 73` and `BALL_START = 83`. The +5 on M0 is the positioner's calibration. The table's design point and the measured landing do not have to agree for the lesson's claim: the **relative** walk (the table's steps) and the captures are what the lesson teaches, not a frame-stable absolute star map.

A probe makes the walk visible. Use a full mask (every line a star) and a simple table: zero for ten lines, `$10` (+1, left) for ten lines, `$F0` (-1, right) for ten lines, zero after. The measured star X on consecutive lines is:

| Visible lines (sampled) | Table | Measured X |
|---|---|---|
| 1, 2, 4–7, 9 | `$00` | X0, X0, X0, X0, X0, X0, X0 |
| 10, 12–15, 17, 18 | `$10` | X0−1, X0−3, X0−4, X0−5, X0−6, X0−8, X0−9 |
| 20–23, 25, 26, 28, 29 | `$F0` | X0−9, X0−8, X0−7, X0−6, X0−4, X0−3, X0−1, X0 |
| 30–159 | `$00` | X0 |

`X0` is the measured start, M0 X = 78 in this build. The absolute start is a calibration point; the table's steps are the stable part.

The X falls by one per line while the table says `$10` and rises by one while it says `$F0`. That is the whole mechanism: **the star's position is the accumulated HMOVE motion**. A pseudo-random table with values in both directions makes the path scatter; the mask samples the path into a field. The measured star path spans about 96 pixels of relative movement; the three copies add +16 and +32, and the ball's own walk fills the left side.

The first line is pipelined too. The first line's motion bytes are preloaded into `HMM0`/`HMBL` in VBLANK, and the first `STA HMOVE` is the first instruction at `BodyStart` (the label reports 37/5; the strobe completes at about cycle 8). Each later line's motion is loaded into A and Y at the end of the previous line, so the normal `STA HMM0` / `STY HMBL` / `STA HMOVE` sequence also starts at the line top. The group's eighth line loads the **next group's first-line motion** into A/Y; the next `GroupTop` writes `HMM0`/`HMBL` and strobes `HMOVE`, so the group-first line's strobe is early and outside the 24-cycle motion-register window. Every star-band line gets the bar; the measured check is 160 of 160 lines in both captures.

::: tip The absolute X is a calibration point

The main ROM's measured start is M0 X = 78 and ball X = 83; the table's design points are 73/83. The +5 is the positioner's calibration. The lesson's claims are about the **relative** walk (the table's steps) and the measured captures, not about a frame-stable absolute star map.

:::

### The bar and the two states

An `HMOVE` in HBLANK blanks the leftmost eight pixels of that line. The kernel does its motion work at the top of the line, so the strobe lands early enough; the capture measures the bar on 160 of 160 star-band lines in both states. That is the HBLANK signature: a solid eight-pixel border-colour notch.

The second state is a second `HMOVE` about 44 cycles into the visible line, after the mask test and the enables, with `HMM0` and `HMBL` set to `$40`. Its behaviour is not a simple four-pixel left shift. In the visible area the extra clocks **plug MOTCK**: they suppress motion clocks and delay the pixels that have not yet been drawn, rightward. The HBLANK-extension latch is cleared at the HSync wrap, so there is no extension or stuffing; the stall is bounded by the line. The amount of stall depends on where each star's pixel falls relative to the strobe:

- A star whose pixel has already been drawn is not affected on that line.
- A star whose pixel is still to come is delayed rightward; the delay can be large (the measured full-mask probe shows rightward shifts of **36–133 pixels mod 160**), and it wraps at the 160-pixel field edge.
- The object's position for the next line is the stalled position, so the field changes from line to line, not by a constant.

There is no `−640 ≡ 0` arithmetic and no "motion is re-applied" explanation of the shift: the visible-line strobe is a stall, not a second walk step. The measured effect is a **position shift** with a line-dependent, bounded magnitude; the field's picture changes, and the eight-pixel bar is unchanged. The frame length stays 262 in both states.

The per-line X trace (full mask, one ROM single-strobe and one second-strobe, captured at the same wall-clock time) gives the shifts below. The values are `(B − A) mod 160` on the common star lines; they are bounded by the field width and are not a ramp:

| Star lines (sample) | Single X | Second-strobe X | Shift mod 160 |
|---|---:|---:|---:|
| 1 | 45 | 146 | 101 |
| 2 | 44 | 17 | 133 |
| 4 | 42 | 14 | 132 |
| 12 | 33 | 134 | 101 |
| 25 | 36 | 9 | 133 |
| 29 | 51 | 8 | 117 |
| 33 | 63 | 20 | 117 |

The shifts cluster at 36–133 pixels; the smallest and largest are bounded by 160, and there is no monotone growth with the line. The frame length repeats at 259/3 (262 lines). The walk itself is deterministic and closed: the start is fixed and `STA HMOVE` is the first instruction of every body line, so the per-line walk is stable. Two captures can show different star positions because the mask rotates every eight frames and samples a different set of walk points (and the second state stalls the pixels); the star map is a sample of the walk, not a frame-stable bitmap. The relative steps are the stable, table-driven part.

### The 192-line budget and the pipelined line

NTSC gives 262 lines: 3 VSYNC, 37 VBLANK, 192 visible, 30 overscan. The visible area is the whole budget, and this lesson spends it in two bands:

| Visible lines | Lines | Band | What draws it |
|---|---:|---|---|
| 0–159 | 160 | Star field | 20 groups × 8 lines, one HMOVE per line |
| 160–191 | 32 | Planet | 16 rows × 2 lines, playfield arc + P0 ship |
| **192** | | | |

In absolute scanlines (visible line 0 is scanline 37):

| Band | Scanlines |
|---|---|
| Star field | 37–196 |
| Planet | 197–228 |
| Overscan | 229–258 |
| Next VSYNC | 259 |

The frame gate is `StartFrame` at 259/3, `VblankStart` at 0/5, `BodyStart` at 37/5, `PlanetStart` at 197/5, and `OverscanStart` at **228/3** (the label sits on the last planet line; the first blanked line is 229). The visible ledger is 160 + 32 = 192; 3 + 37 + 192 + 30 = 262.

The star band is a **one-line kernel**. A star line costs:

```
star line:  STA HMM0        3
            STY HMBL        3
            STA HMOVE       3   the first strobe (~cycle 11)
            LSR MaskByte    5
            BCS .star       3
            LDA #$02        2
            STA ENAM0       3
            STA ENABL       3
.comb:      LDA CombMode    3   (comb state only)
            BEQ .noComb     2
            LDA #$40        2
            STA HMM0        3
            STA HMBL        3
            STA HMOVE       3   the second strobe (~cycle 44)
.noComb:    LDA HmmStar+1,X 4   pipeline the next line
            LDY HmmBall+1,X 4
            STA WSYNC       3
            INX             2
            -----------------
            ~44 to the second strobe; ~54 full line; ~41 without
```

The second strobe's `STA HMOVE` completes at ~43–44 cycles into the line: 41 cycles after the first `STA HMM0`, plus the 2-cycle `INX` at the line top. The ~54-cycle full line is still inside 76. (The count is nominal; the point is that the second strobe is late in the line, not at the top.)

The non-star line has the same shape with `LDA #$00`; the second-strobe state adds the `LDA CombMode` / `BEQ` / `LDA #$40` / two stores / `STA HMOVE` (16 cycles), still inside 76. The body line gains 2 cycles from the `NOP`: ~43 without the comb, ~56 with it. The group's first line is always blank (mask bit 0 is zero); it reloads the mask byte for the next seven lines, consumes bit 0, disables the objects, and (in comb mode) strokes the second `HMOVE`. Its budget is about 71 cycles with the comb: the two added stores at `GroupTop` add 6 cycles (the line already had one `STA HMOVE`; the three stores cost 9). The group-first line's second strobe completes at ~57; the next body line's `NOP` puts its `STA HMM0` at ~82, a **25-cycle** gap. The group's eighth line carries the group counter (`DEC Groups` / `BNE`) before its `WSYNC` and loads the next group's first-line motion into A/Y; the next `GroupTop`'s `STA HMM0` is at ~83, a **39-cycle** gap after that comb strobe. Both are outside the 24-cycle motion-register window. Every path is inside 76 cycles, so the frame stays 262 in both states.

The motion is pipelined. The first line's motion is preloaded in VBLANK; each line's end loads the **next** line's motion into A and Y; the eighth line loads the next group's first-line motion into A/Y, and the next `GroupTop` writes `HMM0`/`HMBL` and strobes `HMOVE`. That is what lets the `HMOVE` be the first work of every line.

### The mask and the scroll

The line mask is 24 bytes: 160 bits for the star band and four zero bytes for the planet band, so nothing is ever drawn below the horizon. Bit 0 of byte 0 is visible line 0; bit 7 of byte 19 is line 159. Bit 0 of every byte **of the ROM table** is zero: the group's first line is blank and carries the mask-byte reload. The other bits are the sparse field; **adjacent bits are legal** because the objects never need re-positioning. The lesson ROM's mask has **34 star lines** and up to **136 star pixels**; it is a 160-bit mask with 34 set bits, not a "34-bit mask".

The scroll rotates the 20 star bytes left by one bit every eight frames, so the sampled points on the walk drift down one line per eight frames. The rotation moves bit 7 of byte 19 into bit 0 of byte 0; the group-first line consumes that bit unconditionally, so a star that crosses a byte boundary is dropped for one scroll phase (8 frames) and reappears after the next rotation. That is a blink that lasts one scroll phase (8 frames) at the seam, not a mask invariant violation; the ROM table itself has bit 0 = 0 in every byte.

The copies are at X, X+16 and X+32 **mod 160**; the ball is one pixel. The group-first line is blank by mask, but a wrapped M0 copy at X = 8–15 can appear for the few cycles before the group-first line's disable, because the objects are still enabled from the previous line. That is the same star wrapping at the seam; it is not a separate star.

### The planet band and the ship

The planet is a playfield arc in reflect mode (`CTRLPF = $01`). Each row fills PF2 from the centre chunk outward, then PF1, then PF0. Rows 0–7 grow the PF2 cap from 4 to 32 pixels; rows 8–11 add four PF1 chunks (36/40/44/48); rows 12–15 set **PF1 = `$FF`** (the whole PF1 group) and add PF0 chunks 3, 2–3, 1–3, 0–3. The half-widths are:

| Rows | PF2 | PF1 | PF0 | Half-width |
|---:|---|---|---|---:|
| 0–7 | `$80,$C0,$E0,$F0,$F8,$FC,$FE,$FF` | `$00` | `$00` | 4, 8, 12, 16, 20, 24, 28, 32 |
| 8–11 | `$FF` | `$01,$03,$07,$0F` | `$00` | 36, 40, 44, 48 |
| 12–15 | `$FF` | `$FF,$FF,$FF,$FF` | `$80,$C0,$E0,$F0` | 68, 72, 76, 80 |

The important change from the first build is rows 12–15: PF1 is **full** before PF0 adds the outer chunks. The first build set PF1 `$1F/$3F/$7F` and PF0 `$80/$C0/$E0`, which left chunks 4–6 empty and produced detached 4-pixel islands at both bottom corners. With PF1 = `$FF`, the surface is contiguous: the measured capture has **0 sky gaps** inside every row. The table's 68/72/76/80 are the design values; the capture reads 68, 72, 72, 80 in one frame and 68, 72, 76, 80 in another — a one-chunk (4-px) sampling difference at row 14. The limb stays continuous. The arc grows from the 8-pixel cap at row 0 to the full 160-pixel width at row 15.

The first planet row's PF stores are the first work at `PlanetStart`, after `COLUPF` is set: the PF0 store completes 14 cycles after the label (cycle 19 absolute), PF1 at 21 (26 absolute) and PF2 at 28 (33 absolute), inside the chunk deadlines (22.7, 28 and 38.7). The colour and NUSIZ/ship setup follows the PF stores.

The ship is P0, eight pixels wide and eight scanlines tall, drawn as four two-line rows on planet rows 10–13. `NUSIZ0` is zero in the planet band, so the ship is one copy; the missile is disabled. The ship is the one object that is **not** positioned once. The per-line `HMOVE`s apply `HMP0` 160 times a frame; with a nonzero `HMP0`, P0 would drift every frame. `HMP0` is therefore set to 0 **before** every `HMOVE` (the initial reset HMOVE and the per-frame ship reset), and the ship is re-positioned with a coarse-only fixed delay: `STA WSYNC`, 22 `NOP`s, `STA RESP0`. The measured ship spans **X = 57–65 (left edge 57)**. No `HMOVE` is used for the ship, so the stars are not disturbed.

The sky is four blues: `$82` (dark), `$84` (medium), `$86` (bright) and `$88` (light). The ball is `$8E`, a bright blue. There is no grey phase.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson73.bin \
  lessons/part11-legendary/73-cosmic-ark-starfield/73-cosmic-ark-starfield.asm

stella build/lesson73.bin
```

The two exercise solutions sit beside the lesson source. Each is a complete 4,096-byte ROM:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part11-legendary/73-cosmic-ark-starfield/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part11-legendary/73-cosmic-ark-starfield/exercise-02-solution.asm
```

### Full Source

The complete annotated source is reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 73: The HMOVE Comb & the Cosmic Ark Starfield
; =============================================================================
; Part 11: Legendary Techniques
;
; What this program does:
;   "the starfield": a 192-line night sky over a planet limb.  The upper 160
;   lines are a sparse field of one-pixel stars; the bottom 32 lines are a
;   green/brown planet arc with a small red ship.
;
;   The stars are not positioned per line.  Missile 0 and the ball are
;   positioned ONCE, then every visible line writes a motion value to HMM0
;   and HMBL and strokes HMOVE.  The TIA re-applies the motion, so the
;   objects walk across the screen: their X is the accumulated motion.  A
;   pseudo-random motion table makes the walk scatter instead of tracing a
;   single diagonal.  NUSIZ0=3 gives three 1-pixel M0 copies at X, X+16 and
;   X+32; the ball is the fourth star.  A line mask decides which lines
;   show the objects.  Adjacent star lines are allowed: the objects keep
;   their position, so there is no "position-ahead" rule.
;
;   Every star-band line strokes HMOVE in HBLANK, which blanks the leftmost
;   eight pixels.  The eight-pixel bar is therefore present on all 160
;   star-band lines in BOTH captures; it is the real HMOVE signature, not a
;   mode.  The two states are:
;
;     starfield.png  one HMOVE per line: the walk and the bar.
;     comb.png       a second HMOVE about 44 cycles into the visible line with
;                    HMM0=HMBL=$40.  In the visible area the extra clocks
;                    plug MOTCK and delay the not-yet-drawn pixels rightward;
;                    the stall is bounded by the line and depends on where
;                    each star's pixel falls relative to the strobe.
;
;   The auto-demo switches the second strobe on once, at frame 240.
;   SELECT toggles it at any time.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   The 192 visible lines are two bands:
;
;     visible   0-159   the star band    160 lines   20 groups x 8 lines
;     visible 160-191   the planet band   32 lines   16 rows x 2 lines
;                       ----------------
;                       160 + 32 = 192
;
;   Absolute scanlines: BodyStart 37/5, PlanetStart 197/5, OverscanStart
;   228/3 label (the first blanked line is 229).  The frame gate is
;   StartFrame 259/3 and VblankStart 0/5.
;
; The star band (visible 0-159):
;   The motion is pipelined.  The first line's bytes are preloaded into
;   HMM0/HMBL in VBLANK and the first strobe is the first instruction at
;   BodyStart; each later line's motion is loaded into A and Y at the end
;   of the previous line.  The HMOVE lands at about cycle 11 on the body
;   lines and ~13 on the group-first line, early enough in HBLANK for the
;   eight-pixel bar (measured 160/160 star-band lines in both captures).
;   The group's eighth line loads the next group's first-line motion into
;   A/Y; the next GroupTop writes HMM0/HMBL and strokes HMOVE, outside the
;   24-cycle motion-register window after the eighth line's comb strobe.
;   Then the kernel tests the mask bit, sets the enables, and (in comb
;   mode) strokes the second HMOVE.
;
;   The motion table gives the per-line displacement.  A positive value in
;   the high nibble moves left (1-7 pixels), a negative value moves right
;   (1-8 pixels).  The star table uses $00 (no move), $10-$50 (left 1-5)
;   and $B0-$F0 (right 5-1); the ball table uses $20-$60 (left 6-2) and
;   $A0-$E0 (right 6-2).  The table is 160 entries, one per visible line,
;   plus a sentinel for the last +1 load.  The two tables are page-aligned,
;   so LDA/LDY abs,X is four cycles and never crosses a page.  The walks
;   are closed: the initial position is the last line's position, so the
;   object returns to the start at the end of every frame and no per-frame
;   RESxx is needed.  The relative walk spans about 96 pixels; the three
;   copies add +16 and +32, and the ball has its own walk.  The main ROM's
;   measured start is M0 X=78 and ball X=83; the table's design points are
;   STAR_START = 73 and BALL_START = 83.  The +5 on M0 is the positioner's
;   calibration; the relative walk is the table's job.
;
;   The line mask is 24 bytes: bit 0 of byte 0 is visible line 0, bit 7 of
;   byte 19 is line 159.  Bit 0 of every byte is zero: the group's first
;   line is always blank and carries the mask-byte reload.  The other bits
;   are the sparse field; adjacent bits are legal because the objects do not
;   need to be re-positioned.  The last four bytes are zero, so no star is
;   drawn below the horizon.  34 star lines, up to 136 star pixels.
;
; The two states (visible 0-159):
;   Both states stroke HMOVE on every star-band line.  The single-strobe
;   state is the walk: the eight-pixel bar and the accumulated motion.
;   The second-strobe state writes HMM0=HMBL=$40 after the enables and
;   strokes HMOVE again about 44 cycles into the visible line.  In the visible
;   area the extra clocks plug MOTCK: they delay the pixels that have not
;   yet been drawn, rightward.  The stall is bounded by the line and depends
;   on where each star's pixel falls relative to the strobe; a full-mask
;   probe measures rightward shifts of 36-133 pixels (mod 160), not a
;   4-pixel left move and not a uniform median.  The bar is unchanged and
;   the frame length stays 262.
;
; The planet band (visible 160-191):
;   Sixteen rows x two lines.  PF2 is filled first from the centre out,
;   then PF1, then PF0, so the limb grows from an 8-pixel cap to the full
;   160-pixel width.  CTRLPF=$01 reflects the playfield.  COLUPF is green
;   on the first six rows and brown on the rest.  P0 is the ship: eight
;   pixels wide, eight scanlines tall, drawn as four two-line rows at
;   planet rows 10-13; the ship spans X=57-65 (left edge 57; a fixed
;   coarse delay, not an HMOVE).  COLUP0 is red here; missile 0 is
;   disabled, so the change from the star colour is safe.
;
; Input and the auto-demo:
;   SWCHB bit 1 SELECT (active low) toggles CombMode on a new press.
;   The auto-demo sets CombMode=1 in the VBLANK whose Frame value is 240
;   (about four seconds), so a two-second capture is the single-strobe
;   walk and a five-second capture (after the toggle) shows the second
;   strobe.
;
;   The mask scrolls: every eight frames the 20 star bytes are rotated left
;   by one bit, so the sampled points on the walk drift down one line per
;   eight frames.  The last four mask bytes stay zero.  The sky colour
;   cycles through four blues ($82/$84/$86/$88), eight frames each.
;
; Checkpoints (the values are the state at the label):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   PlanetStart (197/5), OverscanStart (228/3 label; line 229);
;   CombWrite (A = the new CombMode, 0/1), SkyRead (A = the sky colour),
;   MaskRotate (A = the new first mask byte), GroupTop (X = the line,
;   A/Y = the next line's motion).
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80 Frame         frame counter, 8 bits
;   $81 CombMode      0 = single strobe, 1 = second strobe
;   $82 PrevSelect    SELECT edge latch (0 = released, 1 = pressed)
;   $83 MaskByte      the current eight-line mask byte
;   $84 MaskIdx       the current group's byte index (0-19)
;   $85 Groups        groups left in this frame (20..1)
;   $86-$9D MaskBuf   24-byte RAM mask (20 star bytes + 4 zero bytes)
;   $9E               AutoFired  0 = the frame-240 auto has not fired
;   $9F-$F7           free (89 bytes)
;   $F8-$FF           stack
;
; Build: acme -f plain -o build/lesson73.bin \
;        lessons/part11-legendary/73-cosmic-ark-starfield/73-cosmic-ark-starfield.asm
; Run:   stella build/lesson73.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos calibration bias from Lesson 26

STAR_GROUPS    = 20      ; 160 visible lines / 8 lines per group
PLANET_ROWS    = 16      ; 16 rows x 2 lines = 32 visible lines
SCROLL_FRAMES  = 8       ; rotate the mask once every 8 frames
AUTO_COMB      = 240     ; the auto-demo turns the second strobe on here

SHIP_ROW       = 10      ; the ship's first planet row (4 rows = 8 lines)
SHIP_ROWS      = 4
PLANET_COLOUR  = 6       ; rows 0-5 green, rows 6-15 brown

STAR_START     = 73      ; the table's design point
BALL_START     = 83      ; the ball's design position before line 0

COMB_MOTION    = $40     ; HMM0/HMBL: +4 pixels left, second strobe

; --- colours -----------------------------------------------------------------
C_SKY0         = $82     ; dark blue
C_SKY1         = $84     ; medium blue
C_SKY2         = $86     ; bright blue
C_SKY3         = $88     ; light blue
C_STAR         = $0E     ; the three missile copies: white
C_STAR_BALL    = $8E     ; the ball: bright blue
C_SHIP         = $42     ; the ship: red
C_PLANET_GREEN = $C6     ; the planet's limb
C_PLANET_BROWN = $26     ; the planet's body

; =============================================================================
; RAM ALLOCATION ($80-$9E; +clean_start zeroes every byte)
; =============================================================================
Frame        = $80   ; frame counter, 8 bits
CombMode     = $81   ; 0 = one HMOVE per line, 1 = second visible HMOVE
PrevSelect   = $82   ; SELECT edge latch (0 = released, 1 = pressed)
MaskByte     = $83   ; the current eight-line mask byte
MaskIdx      = $84   ; the current group's mask byte index, 0-19
Groups       = $85   ; groups left in this frame, 20..1
MaskBuf      = $86   ; 24 bytes: 20 star bytes + 4 zero horizon bytes
AutoFired    = $9E   ; 0 = the frame-240 auto-demo has not fired; 1 = fired
;
; $9F-$F7 are free (89 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (SetCoarseM0, SetCoarseBL and RotateMask).

; =============================================================================
; WALKLINE — one eight-line group's first line, then seven masked lines
; =============================================================================
; The group's first line is always blank (mask bit 0 is zero).  It moves the
; objects with the first HMOVE, reloads the mask byte for the next seven
; lines, consumes bit 0, disables the objects, and (in comb mode) strokes
; the second HMOVE.  The seven bodies test bits 1-7.
;
; The motion is pipelined: A and Y hold this line's HMM0/HMBL bytes, which
; the previous line loaded.  The line starts with a 2-cycle NOP, then the
; stores and STA HMOVE; the HMOVE lands at about cycle 11 and the leftmost
; eight pixels are blanked on every line.  The NOP puts the group-first
; line's comb strobe at least 25 cycles before this line's HMM0 stores.
; At the end of the line the kernel loads the NEXT line's bytes into A
; and Y.
;
; The star line's enable must land before the star's first pixel.  The
; ball is the leftmost object: its table walk from BALL_START=83 reaches
; X=9 on line 19 (X=12 with the positioner's +3 bias), pixel cycle 25.7.
; The capture's visible leftmost is X=9-11 depending on the scroll phase;
; the enable is in time (the capture shows the ball).  The star's own
; table walk never goes left of X=24.
!macro WalkBody {
    NOP                     ; the group-first comb's 24-cycle window
    STA HMM0
    STY HMBL
    STA HMOVE
    LSR MaskByte
    BCS .star
    LDA #$00
    STA ENAM0
    STA ENABL
    JMP .comb
.star:
    LDA #$02
    STA ENAM0
    STA ENABL
.comb:
    LDA CombMode
    BEQ .noComb
    LDA #COMB_MOTION
    STA HMM0
    STA HMBL
    STA HMOVE
.noComb:
    LDA HmmStar+1,X
    LDY HmmBall+1,X
    STA WSYNC
    INX
}

; =============================================================================
; GROUPFIRSTBODY — the eight-line group's blank first line
; =============================================================================
; The caller has already stroked this line's HMOVE: the first group from the
; preloaded registers at BodyStart, the later groups from the pipelined A/Y.
; This body reloads the mask byte, consumes bit 0, disables the objects,
; strokes the second HMOVE in comb mode, loads the next line's motion, and
; ends the line.  The first group's line 0 is the only caller that does not
; do the two motion stores, which is why its HMOVE lands at ~cycle 8.
!macro GroupFirstBody {
    LDY MaskIdx
    LDA MaskBuf,Y
    STA MaskByte
    INC MaskIdx
    LSR MaskByte            ; consume bit 0 (the ROM table's bit 0 is 0)
    LDA #$00
    STA ENAM0
    STA ENABL
    LDA CombMode
    BEQ .noComb
    LDA #COMB_MOTION
    STA HMM0
    STA HMBL
    STA HMOVE               ; the second strobe, visible line
.noComb:
    LDA HmmStar+1,X
    LDY HmmBall+1,X
    STA WSYNC
    INX
}

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_SKY0
    STA COLUBK              ; the first sky colour; VBLANK cycles it
    LDA #C_STAR
    STA COLUP0              ; missile 0 and (later) the ship
    LDA #C_STAR_BALL
    STA COLUPF              ; the ball star and (later) the planet
    LDA #$01
    STA CTRLPF              ; reflect the playfield; 1-pixel ball
    LDA #$03
    STA NUSIZ0              ; missile 0: three close 1-pixel copies
    LDA #$00
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    STA ENAM0
    STA ENABL

; --- copy the mask to RAM ----------------------------------------------------
    LDX #$00
CopyMask:
    LDA MaskRom,X
    STA MaskBuf,X
    INX
    CPX #24
    BNE CopyMask

; --- position M0 and the ball ONCE -------------------------------------------
; The walk moves the stars from here on.  Each routine is the Lesson 26
; divide-by-15 dance; the single HMOVE applies both fine offsets.  The
; star's initial point is STAR_START, the ball's is BALL_START.  P0 (the
; ship) is positioned every frame in VBLANK instead: the walk's HMOVEs
; re-apply HMP0 160 times a frame, so HMP0 must be 0 or P0 drifts; the
; ship's coarse-only positioner avoids a second HMOVE that would shift the
; stars too.
    LDA #(STAR_START + POS_BIAS)
    JSR SetCoarseM0
    LDA #(BALL_START + POS_BIAS + 1)
    JSR SetCoarseBL
    LDA #$00
    STA HMP0
    STA HMOVE

; --- single-strobe mode at power-on -----------------------------------------
    STA CombMode
    STA HMM0
    STA HMBL
    STA Frame
    STA PrevSelect

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    INC Frame

; -----------------------------------------------------------------------------
; 1. SELECT — a new press toggles the second strobe
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is pressed.  PrevSelect makes the toggle
; happen on the falling edge (one toggle per press).  CombWrite is the
; SELECT path's store; the auto-demo has its own direct path so it cannot
; loop back into the frame-240 check.
    LDA SWCHB
    AND #$02
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA CombMode
    EOR #$01
CombWrite:                  ; checkpoint: A = the new CombMode (0/1)
    STA CombMode
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; -----------------------------------------------------------------------------
; 2. THE AUTO-DEMO — the second strobe on at frame 240
; -----------------------------------------------------------------------------
; AutoFired latches the auto-demo off after its one firing at frame 240.
    LDA Frame
    CMP #AUTO_COMB
    BNE AutoDone
    LDA AutoFired
    BNE AutoDone
    LDA #$01
    STA AutoFired
    STA CombMode
AutoDone:

; -----------------------------------------------------------------------------
; 3. THE SKY COLOUR — four blues, eight frames each
; -----------------------------------------------------------------------------
    LDA Frame
    LSR                     ; one phase every 8 frames
    LSR
    LSR
    AND #$03
    TAX
    LDA SkyColours,X
SkyRead:                    ; checkpoint: A = the sky colour
    STA COLUBK

; -----------------------------------------------------------------------------
; 4. THE STAR COLOURS — white missile copies, cyan ball
; -----------------------------------------------------------------------------
    LDA #C_STAR
    STA COLUP0
    LDA #C_STAR_BALL
    STA COLUPF
    LDA #$03
    STA NUSIZ0              ; three close missile copies (and P0 copies)
    LDA #$00
    STA PF0                 ; the planet's full-width PF ends here
    STA PF1
    STA PF2
    STA GRP0                ; the ship's last row ends here
    STA GRP1

; -----------------------------------------------------------------------------
; 5. THE SCROLL — rotate the 20 star mask bytes once every 8 frames
; -----------------------------------------------------------------------------
    LDA Frame
    AND #(SCROLL_FRAMES - 1)
    BNE NoRotate
    JSR RotateMask
NoRotate:

; -----------------------------------------------------------------------------
; 6. THE SHIP — a coarse-only fixed-delay positioner every frame
; -----------------------------------------------------------------------------
; No HMOVE: the walk's HMOVEs must not get an extra fine offset from HMP0.
; 22 NOPs = 44 cycles; RESP0 writes at ~cycle 46; the measured ship spans
; X=57-65 (left edge 57).
    STA WSYNC
    !fill 22, $EA
    STA RESP0
    LDA #$00
    STA HMP0

; -----------------------------------------------------------------------------
; 7. THE WALK'S START — reset the cursor and the group count
; -----------------------------------------------------------------------------
    LDA #$00
    STA MaskIdx
    LDA #STAR_GROUPS
    STA Groups
    LDA #$00
    STA HMP0                ; the walk's HMOVEs must not move P0
    LDA HmmStar
    STA HMM0                ; preload the first line's motion
    LDA HmmBall
    STA HMBL
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:                  ; checkpoint: scanline 37/5, visible line 0
    STA HMOVE               ; the first line's strobe, ~cycle 8

; =============================================================================
; VISIBLE LINES 0-159: THE STAR BAND (20 groups x 8 lines)
; =============================================================================
; BodyStart is visible line 0.  A/Y hold the first line's motion; the loop
; then pipelines each line's motion into the next.  The objects were
; positioned once at reset, so no RESM0/RESBL appears in this band.
    LDX #$00
StarField:
    ; --- group 0's first line: HMOVE first, then the blank-line body ------
    +GroupFirstBody
    +WalkBody
    +WalkBody
    +WalkBody
    +WalkBody
    +WalkBody
    +WalkBody
; --- the eighth line carries the group tail, before its WSYNC -------------
    STA HMM0
    STY HMBL
    STA HMOVE
    LSR MaskByte
    BCS Body7Star
    LDA #$00
    STA ENAM0
    STA ENABL
    JMP Body7Comb
Body7Star:
    LDA #$02
    STA ENAM0
    STA ENABL
Body7Comb:
    LDA CombMode
    BEQ Body7NoComb
    LDA #COMB_MOTION
    STA HMM0
    STA HMBL
    STA HMOVE
Body7NoComb:
    LDA HmmStar+1,X
    LDY HmmBall+1,X
    DEC Groups
    BNE GroupNext
    STA WSYNC               ; the last group's eighth line
    INX
    JMP PlanetStart
GroupNext:
    STA WSYNC               ; the eighth line ends; the next group starts
    INX
    JMP GroupTop

GroupTop:
    ; --- groups 1-19's first line: A/Y hold the next group's motion ------
    STA HMM0
    STY HMBL
    STA HMOVE               ; the write completes at ~cycle 13
    +GroupFirstBody
    +WalkBody
    +WalkBody
    +WalkBody
    +WalkBody
    +WalkBody
    +WalkBody
; --- the eighth line carries the group tail, before its WSYNC -------------
    STA HMM0
    STY HMBL
    STA HMOVE
    LSR MaskByte
    BCS Body7Star2
    LDA #$00
    STA ENAM0
    STA ENABL
    JMP Body7Comb2
Body7Star2:
    LDA #$02
    STA ENAM0
    STA ENABL
Body7Comb2:
    LDA CombMode
    BEQ Body7NoComb2
    LDA #COMB_MOTION
    STA HMM0
    STA HMBL
    STA HMOVE
Body7NoComb2:
    LDA HmmStar+1,X
    LDY HmmBall+1,X
    DEC Groups
    BNE GroupNext2
    STA WSYNC
    INX
    JMP PlanetStart
GroupNext2:
    STA WSYNC
    INX
    JMP GroupTop

; =============================================================================
; VISIBLE LINES 160-191: THE PLANET BAND (16 rows x 2 lines)
; =============================================================================
; PlanetStart is scanline 197.  The star objects are disabled; the
; playfield draws the limb and P0 draws the ship.
PlanetStart:                ; checkpoint: scanline 197, visible line 160
    LDA #C_PLANET_GREEN
    STA COLUPF              ; the PF colour must be set before the first chunk
    LDY #$00
    LDA PlanetPF0,Y         ; the first row's PF goes first: the PF0 chunk 0
    STA PF0                 ; deadline is cycle 22.7
    LDA PlanetPF1,Y
    STA PF1
    LDA PlanetPF2,Y
    STA PF2
    LDA #$00
    STA ENAM0
    STA ENABL
    STA GRP0                ; the ship is blank on row 0
    JMP PlanetAfterPF
PlanetRow:
    LDA PlanetPF0,Y
    STA PF0
    LDA PlanetPF1,Y
    STA PF1
    LDA PlanetPF2,Y
    STA PF2
PlanetAfterPF:
; --- the ship: four rows, eight scanlines -----------------------------------
    CPY #SHIP_ROW
    BCC NoShip
    CPY #(SHIP_ROW + SHIP_ROWS)
    BCS NoShip
    LDA #C_SHIP
    STA COLUP0              ; the ship is red; missile 0 is off
    LDA #$00
    STA NUSIZ0              ; one 8-pixel ship copy on the ship rows
    LDA ShipShape-SHIP_ROW,Y
    STA GRP0
    JMP ShipDone
NoShip:
    LDA #$00
    STA GRP0
ShipDone:
; --- the planet's two colours -----------------------------------------------
    CPY #PLANET_COLOUR
    BNE ColourDone
    LDA #C_PLANET_BROWN
    STA COLUPF
ColourDone:
    INY
    CPY #PLANET_ROWS
    BEQ PlanetLast
    STA WSYNC               ; the row's first line
    STA WSYNC               ; the row's second line
    JMP PlanetRow
PlanetLast:
    STA WSYNC               ; the last row's first line
    STA WSYNC               ; the last row's second line

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: the line the label reports (228/3 after the trim)
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SETCOARSEM0 / SETCOARSEBL — the Lesson 26 dance for the stars
; =============================================================================
; A = the desired left edge + POS_BIAS.  Each routine starts a fresh line,
; divides by 15 (5 cycles per iteration = 15 colour clocks), stores the
; remainder as the fine value, strobes the coarse reset, and ends with a
; WSYNC.  The caller's single HMOVE applies the fine offsets.
    !align 31, 0
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
    STA WSYNC
    RTS

    !align 31, 0
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
    STA WSYNC
    RTS

; =============================================================================
; ROTATEMASK — rotate the 20 star mask bytes left by one bit
; =============================================================================
; The star bits are consumed bit 0 first, so a left rotation moves each
; star down one line.  The carry out of byte 19 wraps into bit 0 of byte 0.
; The four horizon bytes are not rotated: they stay zero.
RotateMask:
    CLC
    LDX #$00
    LDY #20                 ; DEY keeps the carry: CPX would destroy it
RotateLoop:
    LDA MaskBuf,X
    ROL                     ; carry in = the previous byte's bit 7
    STA MaskBuf,X
    INX                     ; INX and DEY do not touch the carry
    DEY
    BNE RotateLoop
    BCC RotateDone
    LDA MaskBuf
    ORA #$01
    STA MaskBuf
RotateDone:
    LDA MaskBuf
MaskRotate:                 ; checkpoint: A = the new first mask byte
    RTS

; =============================================================================
; THE MOTION TABLES — one byte per visible line, plus a sentinel
; =============================================================================
; The byte is the HMM signed offset: $10-$70 move left 1-7 pixels,
; $F0-$80 move right 1-8 pixels, $00 does not move.  This ROM's star table
; uses $00/$10-$50/$B0-$F0; the ball table uses $20-$60/$A0-$E0.  The walks are closed
; (the last line returns to the initial position), and the initial position
; is the last line's point: STAR_START = 73, BALL_START = 83.  Page-aligned, so
; LDA/LDY abs,X is four cycles; the +1 load of the last line reads the
; sentinel, still inside the page.
    !align 255, 0
HmmStar:
    !byte $50, $50, $50, $10, $30, $10, $20, $40, $20, $50, $40, $30, $20, $40, $20, $10
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $F0, $B0, $C0, $B0, $B0, $F0, $C0, $B0
    !byte $F0, $E0, $D0, $B0, $D0, $C0, $C0, $B0, $B0, $B0, $D0, $C0, $B0, $D0, $F0, $F0
    !byte $20, $20, $10, $50, $10, $40, $30, $40, $50, $20, $20, $30, $10, $20, $50, $10
    !byte $40, $40, $20, $20, $20, $50, $30, $50, $E0, $D0, $C0, $D0, $B0, $F0, $C0, $C0
    !byte $F0, $E0, $B0, $D0, $C0, $D0, $B0, $C0, $C0, $C0, $B0, $E0, $B0, $E0, $E0, $C0
    !byte $10, $20, $10, $20, $10, $40, $10, $50, $30, $40, $30, $20, $10, $30, $10, $20
    !byte $40, $20, $20, $30, $30, $30, $20, $10, $B0, $D0, $D0, $C0, $C0, $C0, $E0, $E0
    !byte $C0, $C0, $B0, $B0, $E0, $C0, $F0, $F0, $C0, $00, $00, $00, $00, $00, $00, $00
    !byte $30, $50, $10, $50, $10, $20, $30, $30, $20, $40, $30, $40, $20, $40, $30, $20
    !byte $00

    !align 255, 0
HmmBall:
    !byte $50, $20, $50, $30, $30, $20, $30, $60, $40, $50, $60, $30, $50, $40, $20, $30
    !byte $20, $60, $20, $30, $D0, $A0, $C0, $B0, $A0, $D0, $B0, $B0, $D0, $A0, $B0, $B0
    !byte $B0, $D0, $B0, $B0, $D0, $A0, $D0, $A0, $30, $20, $20, $30, $20, $40, $60, $30
    !byte $20, $30, $50, $30, $20, $60, $60, $50, $30, $60, $20, $30, $B0, $B0, $A0, $A0
    !byte $E0, $C0, $D0, $E0, $B0, $C0, $E0, $A0, $C0, $B0, $D0, $C0, $C0, $A0, $D0, $C0
    !byte $40, $40, $60, $50, $60, $40, $30, $60, $40, $30, $20, $50, $50, $60, $50, $60
    !byte $30, $60, $50, $30, $C0, $B0, $E0, $D0, $E0, $E0, $E0, $E0, $E0, $E0, $B0, $C0
    !byte $B0, $E0, $E0, $D0, $C0, $E0, $E0, $C0, $60, $20, $20, $20, $50, $20, $20, $40
    !byte $30, $40, $40, $60, $30, $60, $20, $40, $50, $20, $30, $50, $B0, $E0, $B0, $A0
    !byte $E0, $B0, $C0, $B0, $E0, $E0, $C0, $D0, $B0, $C0, $B0, $D0, $E0, $E0, $C0, $C0
    !byte $00

; =============================================================================
; THE LINE MASK — 24 bytes, one bit per visible line
; =============================================================================
; Bit 0 of byte 0 is visible line 0, bit 7 of byte 19 is line 159.  Bit 0
; of every byte is zero: the group's first line is blank and carries the
; mask-byte reload.  The other bits are the sparse field; adjacent bits are
; legal because the objects do not need to be re-positioned.  34 star
; lines, up to 136 star pixels.  Bytes 20-23 cover the planet band and
; stay zero: no star below the horizon.  The ROM table's bit 0 is zero in
; every byte, but the ROL can move bit 7 into bit 0; the group-first line
; consumes that bit unconditionally, so a star crossing a byte boundary is
; dropped for one scroll phase (8 frames) (a blink that lasts that phase).
MaskRom:
    !byte $28, $80, $54, $40, $92, $00, $4C, $08, $C0, $C0, $08, $82, $E0, $58, $40, $40
    !byte $48, $20, $40, $40, $00, $00, $00, $00

; =============================================================================
; THE PLANET — 16 rows, one byte per playfield register per row
; =============================================================================
    !align 255, 0
PlanetPF0:
    !fill 12, $00           ; rows 0-11: PF2 and PF1 only
    !byte $80, $C0, $E0, $F0 ; rows 12-15: chunks 3, 2-3, 1-3, 0-3

    !align 255, 0
PlanetPF1:
    !fill 8, $00            ; rows 0-7: PF2 only
    !byte $01, $03, $07, $0F ; rows 8-11: chunks 11, 10-11, 9-11, 8-11
    !byte $FF, $FF, $FF, $FF ; rows 12-15: chunks 4-11 (contiguous with PF0)

    !align 255, 0
PlanetPF2:
    !byte $80, $C0, $E0, $F0 ; rows 0-3
    !byte $F8, $FC, $FE, $FF ; rows 4-7
    !fill 8, $FF            ; rows 8-15

; =============================================================================
; THE SHIP — four two-line rows, eight pixels wide
; =============================================================================
ShipShape:
    !byte $18, $3C, $7E, $DB

; =============================================================================
; THE SKY COLOURS — four blues, indexed by Frame >> 3 & 3
; =============================================================================
SkyColours:
    !byte C_SKY0, C_SKY1, C_SKY2, C_SKY3

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
> `lessons/part11-legendary/73-cosmic-ark-starfield/73-cosmic-ark-starfield.asm`.

### Code Walkthrough

#### Step 1 — The frame skeleton

The frame is the course's standard 3 + 37 + 192 + 30 skeleton:

```asm
StartFrame:
    +vsync
VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    INC Frame
    ; ... input, sky, scroll, ship positioner, first-line preload ...
    +wait_timer
    LDA #$00
    STA VBLANK
BodyStart:
    STA HMOVE               ; the first line's preloaded motion
    LDX #$00
```

`+vsync` takes the three VSYNC lines and leaves `VblankStart` at 0/5. The VBLANK timer is 44 ticks; the work runs while it counts. The overscan timer is **36**, and the frame gate is 259/3 with a 262-line frame. An earlier build (before the first-row trim) used 35 and landed at 258/3; the current build uses 36 and gates at 259/3. The star band's first line starts at 37/5 and the planet band at 197/5.

#### Step 2 — Position once, then walk

Missile 0 and the ball are positioned once at reset by the Lesson 26 divide-by-15 dance, and one `HMOVE` applies their fine offsets:

```asm
    LDA #(STAR_START + POS_BIAS)
    JSR SetCoarseM0
    LDA #(BALL_START + POS_BIAS + 1)
    JSR SetCoarseBL
    LDA #$00
    STA HMP0
    STA HMOVE
```

`HMP0` is cleared **before** the `HMOVE`, not after. The main ROM's measured start is M0 X = 78 and ball X = 83; the table's design points are 73 and 83. The +5 is the positioner's calibration; the relative walk is what the table controls. After this, the star kernel never writes `RESM0` or `RESBL`: the walk is the only positioner.

The ship is re-positioned every frame with the coarse-only delay; the walk's per-line `HMOVE`s would otherwise re-apply a nonzero `HMP0` 160 times a frame and drift P0.

#### Step 3 — The pipelined motion table

The first line's motion is preloaded in VBLANK. Each body line starts with a 2-cycle `NOP`, then the three stores; the `HMOVE` lands at about cycle 11:

```asm
    NOP                     ; the group-first comb's 24-cycle window
    STA HMM0
    STY HMBL
    STA HMOVE
    LSR MaskByte
    BCS .star
    LDA #$00
    STA ENAM0
    STA ENABL
    JMP .comb
.star:
    LDA #$02
    STA ENAM0
    STA ENABL
.comb:
    LDA HmmStar+1,X
    LDY HmmBall+1,X
    STA WSYNC
    INX
```

The `+1` loads prepare the next line. The 2-cycle `NOP` at the top of the body line puts the group-first line's comb strobe at least 25 cycles before the next `STA HMM0`. The group's eighth line loads the next group's first-line bytes into A/Y; the next `GroupTop` writes `STA HMM0` / `STY HMBL` / `STA HMOVE` before the strobe. The tables are page-aligned; the sentinel keeps the last `+1` load inside the page.

#### Step 4 — The mask and the scroll

The group's first line reloads the mask byte and consumes bit 0:

```asm
    LDY MaskIdx
    LDA MaskBuf,Y
    STA MaskByte
    INC MaskIdx
    LSR MaskByte
```

The other seven lines test bits 1–7. The scroll rotates the 20 star bytes left by one bit every eight frames:

```asm
RotateMask:
    CLC
    LDX #$00
    LDY #20                 ; DEY keeps the carry: CPX would destroy it
RotateLoop:
    LDA MaskBuf,X
    ROL
    STA MaskBuf,X
    INX
    DEY
    BNE RotateLoop
    BCC RotateDone
    LDA MaskBuf
    ORA #$01
    STA MaskBuf
RotateDone:
    LDA MaskBuf
    RTS
```

`ROL` pulls the carry in from the previous byte and pushes its bit 7 out; `INX` and `DEY` do not touch the carry, so the chain survives twenty bytes. `CPX` would set the carry as a comparison side effect; a first version written that way turned every byte into a plain `ASL` and the field became a solid bar.

#### Step 5 — The second strobe

In comb mode the line adds a second `HMOVE` after the enables:

```asm
    LDA CombMode
    BEQ .noComb
    LDA #COMB_MOTION
    STA HMM0
    STA HMBL
    STA HMOVE
.noComb:
    LDA HmmStar+1,X
```

`COMB_MOTION` is `$40`. The second strobe completes at about cycle 44 (about 35 cycles after the first at ~9). In the visible area the extra clocks plug MOTCK and delay the not-yet-drawn pixels rightward; the stall is bounded by the line, line-dependent, and can wrap at the 160-pixel edge. The bar from the first strobe is unchanged.

#### Step 6 — The planet band and the ship

`PlanetStart` is scanline 197. The first row's PF stores come first, so the first planet line's chunks are in time:

```asm
PlanetStart:
    LDA #C_PLANET_GREEN
    STA COLUPF
    LDY #$00
    LDA PlanetPF0,Y
    STA PF0
    LDA PlanetPF1,Y
    STA PF1
    LDA PlanetPF2,Y
    STA PF2
    LDA #$00
    STA ENAM0
    STA ENABL
    STA GRP0
    JMP PlanetAfterPF
PlanetRow:
    LDA PlanetPF0,Y
    STA PF0
    LDA PlanetPF1,Y
    STA PF1
    LDA PlanetPF2,Y
    STA PF2
PlanetAfterPF:
    CPY #SHIP_ROW
    BCC NoShip
    CPY #(SHIP_ROW + SHIP_ROWS)
    BCS NoShip
    LDA #C_SHIP
    STA COLUP0
    LDA #$00
    STA NUSIZ0
    LDA ShipShape-SHIP_ROW,Y
    STA GRP0
    JMP ShipDone
NoShip:
    LDA #$00
    STA GRP0
ShipDone:
    ; the colour switch at row 6, WSYNC pair, INY, loop
```

Sixteen rows × two lines = 32 lines; the last `WSYNC` releases on 229. The ship is four two-line rows at planet rows 10–13; `NUSIZ0=0` gives one copy. Rows 12–15 set PF1 = `$FF`, so the PF0 chunks land on a full PF1 body and the limb has no detached corner blocks.

#### Step 7 — Input, SELECT, and the auto-demo

`SWCHB` bit 1 is 0 while SELECT is pressed. The edge latch makes one toggle per press:

```asm
    LDA SWCHB
    AND #$02
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA CombMode
    EOR #$01
CombWrite:
    STA CombMode
    JMP SelectDone
```

The auto-demo fires **once**, at frame 240, and cannot override a later SELECT-off:

```asm
    LDA Frame
    CMP #AUTO_COMB
    BNE AutoDone
    LDA AutoFired
    BNE AutoDone
    LDA #$01
    STA AutoFired
    STA CombMode
AutoDone:
```

`AutoFired` is the one-shot latch. SELECT toggles the second strobe at any time; the auto-demo only adds one on at frame 240. The direct path also avoids the old bug where jumping to `CombWrite` fell back into the auto-demo check and looped in VBLANK forever.

#### Step 8 — Reading it back in Stella

Assemble with a symbol file and ask Stella for the checkpoints:

```bash
acme -f plain -l build/lesson73.sym -o build/lesson73.bin \
  lessons/part11-legendary/73-cosmic-ark-starfield/73-cosmic-ark-starfield.asm
grep -E "StartFrame|VblankStart|BodyStart|GroupTop|PlanetStart|OverscanStart|CombWrite|SkyRead|MaskRotate" build/lesson73.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F05F' docs/public/roms/part11-legendary/73-cosmic-ark-starfield/73-cosmic-ark-starfield.bin
```

One checkpoint per run keeps the log readable. The addresses below are the ones this source produced. A label immediately after a `WSYNC` reports the `WSYNC`'s line.

### Checkpoints

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F05F` | 259/3 | the first VSYNC line |
| `VblankStart` | `$F06D` | 0/5 | the first VBLANK line |
| `BodyStart` | `$F111` | 37/5 | visible line 0 and the first `STA HMOVE` |
| `GroupTop` | `$F290` | 45/5 | the first motion stores of a later group's first line |
| `PlanetStart` | `$F411` | 197/5 | visible line 160 |
| `PlanetRow` | `$F431` | 199/3 | the first loop row's PF stores |
| `OverscanStart` | `$F474` | 228/3 | the label on the last planet line; line 229 is blanked |
| `CombWrite` | `$F08B` | A = the new `CombMode` | the SELECT path |
| `SkyRead` | `$F0AF` | A = the sky colour | the colour cycle |
| `MaskRotate` | `$F4EC` | A = the new first mask byte | the scroll |

The frame log: `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `PlanetStart` 197/5, `PlanetRow` 199/3, `OverscanStart` 228/3. The visible ledger is 160 + 32 = 192; the first blanked line is 229, and 229 − 37 = 192; 3 + 37 + 192 + 30 = 262. The same values hold in the second-strobe state.

## What You Should See

At power-on the star band is a blue field of white and bright-blue single-pixel stars. The stars are the points that the mask samples along the HMOVE walk, so short diagonal runs appear where the motion table repeats a value and the runs turn where the table changes. The three missile copies sit at X, X+16 and X+32 (mod 160); the ball adds a fourth star from its own walk. The eight-pixel HMOVE bar runs down the left edge of all 160 star-band lines. A green/brown planet limb fills the bottom 32 lines with a continuous surface (no detached corner blocks), and a small red ship spans X = 57–65 (left edge 57), just left of centre. The sky cycles through four blues.

![Stella running Lesson 73 in the single-strobe state: a blue field of white and bright-blue one-pixel stars tracing the HMOVE walk, an eight-pixel bar at the left of the star band, a continuous green/brown planet limb and a red ship; the title bar reads Stella 7.0: "73-cosmic-ark-starfield"](/images/lesson73/starfield.png)

*`starfield.png`: about 2 seconds after power-on, before the frame-240 auto-demo. The star band is visible lines 0–159; the planet band is visible lines 160–191. The HMOVE bar is on all 160 star-band lines. The stars sit where the mask samples the walk.*

<RomPlayer rom="/roms/part11-legendary/73-cosmic-ark-starfield/73-cosmic-ark-starfield.bin" title="Lesson 73 — The HMOVE Comb & the Cosmic Ark Starfield" />

*Javatari starts muted; this ROM is silent.*

At frame 240 (about four seconds) the auto-demo sets `CombMode=1`. From the next frame each line's second `HMOVE` stalls the not-yet-drawn pixels rightward; the field shifts by a line-dependent, bounded amount (the measured full-mask trace shows 36–133 pixels mod 160). The eight-pixel bar is unchanged, and the planet and ship are untouched. SELECT does the same thing at any time; the second-strobe capture is taken at about five seconds, after the toggle.

![Stella running Lesson 73 in the second-strobe state: the same star band with the field stalled and shifted, the eight-pixel bar still at the left; the planet and ship are unchanged; the title bar reads Stella 7.0: "73-cosmic-ark-starfield"](/images/lesson73/comb.png)

*`comb.png`: about 5 seconds after power-on, after the frame-240 auto-demo. The bar is still on all 160 star-band lines; the not-yet-drawn pixels have been stalled rightward, so the field is shifted line by line. The field is at a later scroll phase, so the mask samples a different set of walk points.*

The two images are different states, not two copies of one frame: the bar is 160/160 in both, and the star positions are stalled/shifted in the second. The scroll phase and the sky colour also differ.

> **Capture method.** Both images are `scripts/capture-screenshot.sh` captures of the committed
> `docs/public/roms/part11-legendary/73-cosmic-ark-starfield/73-cosmic-ark-starfield.bin` on
> display `:0` (the mutter window manager supplies the title bar) at two and five wall-clock
> seconds, with `xdotool mousemove 0 0` before each. The auto-demo timer starts at power-on and
> switches the second strobe once at frame 240 (about four seconds), so the 2-second image is the
> single-strobe state and the 5-second image is the second-strobe state. All images are 1010×807,
> carry the window frame and the `Stella 7.0: "73-cosmic-ark-starfield"` title bar, and show no
> cursor.

The **pixel check** of the two images:

| Image | Size | Title bar | What the pixels show |
|---|---|---|---|
| `starfield.png` | 1010×807 | `Stella 7.0: "73-cosmic-ark-starfield"` | TIA area 960×606 at (25,107); an eight-pixel HMOVE bar on **160/160** star-band lines; 1,110 white M0 capture pixels and 318 bright-blue ball pixels in the star band; no object pixels in the planet band proper; the ship at capture x=367–415 (TIA X=57–65); no cursor |
| `comb.png` | 1010×807 | `Stella 7.0: "73-cosmic-ark-starfield"` | the same layout with the bar still on **160/160** star-band lines; 972 white M0 pixels and 372 ball pixels; no object pixels in the planet band proper; the ship at capture x=367–415 (TIA X=57–65); no cursor |

The **planet check** samples the second line of each planet row. The design half-widths are 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, then 68, 72, 76, 80; the capture's row 14 reads 72 or 76 depending on the frame (a one-chunk sampling difference). Every row has **0 sky gaps** inside its extent: the limb is continuous, with no detached corner blocks. The first planet row's PF stores complete 14/21/28 cycles after the label (19/26/33 absolute), inside the chunk deadlines.

The **walk check** uses the full-mask, simple-table probe from the theory section: the star X is constant on the `$00` lines, falls one pixel per `$10` line (a measured 78→69) and rises one pixel per `$F0` line. The table is the position, and the absolute start is a calibration point.

The **state check** uses two copies of the ROM with the auto-demo disabled, one single-strobe and one second-strobe, captured at the same wall-clock time. The common star lines shift by 36–133 pixels (mod 160); the shift is bounded and line-dependent, not a uniform four-pixel move. The frame length is 259/3 in both states. The stable claim is the bounded, line-dependent stall and the deterministic table walk, not a frame-stable star map: the mask scroll samples a different set of walk points in each capture.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
ROM=docs/public/roms/part11-legendary/73-cosmic-ark-starfield/73-cosmic-ark-starfield.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F05F' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F06D' $ROM   # VblankStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F111' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F290' $ROM   # GroupTop
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F411' $ROM   # PlanetStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F474' $ROM   # OverscanStart
```

- **`$F05F` (`StartFrame`)** is **259/3**, **`$F06D` (`VblankStart`)** **0/5**, **`$F111` (`BodyStart`)** **37/5**, **`$F411` (`PlanetStart`)** **197/5**, **`$F431` (`PlanetRow`)** **199/3**, and **`$F474` (`OverscanStart`)** **228/3** (the first blanked line is 229).
- **`$F290` (`GroupTop`)** reports 45/5 on the later groups: A/Y hold the next group's motion, and the group-first line starts with `STA HMM0` / `STY HMBL` / `STA HMOVE` (the strobe's write completes at ~cycle 13).
- The **bar** is measured at 160/160 star-band lines in both captures; the first line's strobe is `BodyStart`'s `STA HMOVE` at 37/5.
- The **state test** with the auto-demo disabled gives the bounded 36–133 pixel shifts and the same 259/3 frame gate.

The screenshots prove the visual states; the state log proves the clock and the shift. The thing a still cannot prove is the motion between lines; the full-mask walk probe is the measured proof that the star's X is the accumulated HMOVE motion.

## Exercises

Each exercise ships a complete 4,096-byte `exercise-NN-solution.asm`. The solutions assemble through `npm run roms`, run in Stella, and solve the exercise as written. Both keep the lesson's HMOVE walk and the single strobe; the lesson ROM's second-strobe state is the main lesson's experiment, and the exercise headers say so.

### Exercise 1: A Denser Walk Field and a Per-Band Star Colour

**Challenge:** make the field denser and give the stars a colour that changes by vertical band. The mask should carry about twice as many star lines, and the star band should split into five 32-line bands with a different star colour in each. Keep the frame at 262 lines and the walk intact.

**Hints:**
1. Adjacent star bits are now legal, so a dense mask such as `$7C` (bits 2–6) is fine. Keep bit 0 zero: the group's first line is the blank/reload line.
2. The group-first line has the reload and the colour; put the colour code there. `LDA MaskIdx` / `SEC` / `SBC #1` / two `LSR`s / `TAY` gives the band index `(group - 1) >> 2` (0–4); load `StarBandColours,Y` into `COLUP0` and `COLUPF`. **Do not clobber X**: X is the 0–159 line cursor used by `LDA HmmStar+1,X`; the following `LDY HmmBall+1,X` reloads Y.
3. The group-first line is the tightest line: the two added `GroupTop` stores plus the reload and the colour must fit the 76-cycle budget (the main's group-first line is ~71). The eighth line also carries the group counter.
4. Five bands of 32 lines: the group-first line at X = 0, 32, 64, 96, 128 picks the band 0–4.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; the field has 73 star lines and is visibly denser; the star band shows five colour bands (white, bright blue, yellow, green, orange); `StartFrame` is 259/3, `PlanetStart` 197/5, `PlanetRow` 199/3, `OverscanStart` 228/3, and the frame is 262.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Vertical Scroll and Twinkle

**Challenge:** make the field drift four times faster and add a twinkle. The mask should rotate every two frames instead of every eight, and every 16 frames a set of stars should appear or disappear. Keep the walk and the frame at 262 lines.

**Hints:**
1. The scroll is the mask rotation. Change `AND #(SCROLL_FRAMES - 1)` with `SCROLL_FRAMES = 2`.
2. The twinkle can be a flag that flips every 16 frames (`Frame & $0F == 0`). In the group-first line, XOR mask bit 5 with the flag's value: `LDA Twinkle` / `BEQ .noTwinkle` / `LDA MaskByte` / `EOR #$20` / `STA MaskByte`.
3. The group-first line's reload plus the twinkle XOR fits: the line is about 57 cycles with the twinkle.
4. Adjacent bits are legal, so the twinkle can create or remove line 5 of every group without breaking anything.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; the field drifts down one line every two frames and the star count changes every 16 frames as the twinkle line appears and disappears; `StartFrame` is 259/3, `PlanetStart` 197/5, `PlanetRow` 199/3, `OverscanStart` 228/3, and the frame is 262.

**Solution:** See `exercise-02-solution.asm`

## Key Takeaways

- ✅ **The star's X is the accumulated HMOVE motion.** Position the missile and the ball once, then write a motion value and stroke `HMOVE` on every line. The TIA re-applies the motion; a pseudo-random table turns one object into a scattered field. No per-line `RESM0`/`RESBL` is needed.
- ✅ **The eight-pixel bar is the HMOVE blanking, and it is in both states.** An `HMOVE` in HBLANK blanks the leftmost eight pixels; the kernel does its motion stores first, so the bar is on 160/160 star-band lines in both captures.
- ✅ **A visible-line HMOVE is plugging, not a second walk step.** In the visible area the extra clocks suppress MOTCK and delay the not-yet-drawn pixels rightward. The stall is bounded by the line, line-dependent, and can wrap at the 160-pixel edge; the measured full-mask trace shows 36–133 pixel shifts mod 160, not a uniform four-pixel move.
- ✅ **The table is pipelined into A and Y.** The first line is preloaded in VBLANK; each line loads the next line's motion at its end; the eighth line loads the next group's first line into A/Y, and the next `GroupTop` writes `HMM0`/`HMBL` before its strobe. The two 160-byte tables are page-aligned, with a sentinel.
- ✅ **The mask can be dense and adjacent.** Without position-ahead, adjacent star bits are legal; the only reserved bit is bit 0, the group's blank/reload line. The lesson mask has 34 star lines; the first exercise has 73.
- ✅ **The 192-line budget is a schedule.** 160 star lines (one-line kernel) + 32 planet lines (two-line loop) = 192; 3 + 37 + 192 + 30 = 262. The comb state adds 16 cycles to each star line and still fits.
- ✅ **The planet must be contiguous and the ship must be positioned separately.** Rows 12–15 set PF1 = `$FF` before PF0 adds the outer chunks, so the limb has no detached corner blocks (0 sky gaps). The ship is re-positioned every frame with a coarse-only delay because the per-line HMOVEs re-apply `HMP0` 160 times a frame; `HMP0` is 0 before every strobe.

## What's Next

The starfield ends with the planet limb and the HMOVE bar; [the Part 11 index](/part11-legendary/) lists the rest of the anthology. The next legendary technique, **Skipdraw**, takes the one-line kernel in a different direction: a sprite drawn only on its rows, with a carry test that skips the graphics store on every other line and keeps both paths at a constant cycle count. Return to the index for the part's overview, or continue with Skipdraw when it lands.
