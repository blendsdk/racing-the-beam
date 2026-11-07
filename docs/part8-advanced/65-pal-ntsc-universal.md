---
title: "Lesson 65: PAL/NTSC Universal ROM — One Cart, Every TV"
description: "Build a 4,096-byte ROM that ships one cartridge for NTSC and PAL consoles: a title-screen selector, a 262-line or 312-line frame with the same 192-line picture, a colour-bar test for both palettes, a moving bar, a frame counter, a timing page, and a plain explanation of why a stock 2600 cannot auto-detect the TV system."
prev:
  text: "Lesson 64: Building Your Own Cartridge — From ROM to Physical Cart"
  link: "/part8-advanced/64-building-cartridges"
next:
  text: "Lesson 66: Analyzing batari BASIC — How bB Works"
  link: "/part9-dsl-path/66-analyzing-batari-basic"
---

# Lesson 65: PAL/NTSC Universal ROM — One Cart, Every TV

> **Part 8: Advanced Topics** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and memory), Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 15 (the RIOT timer), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players), Lesson 26 (positioning), Lesson 48 (the kernel taxonomy)
> **You will learn:** the NTSC 262-line and PAL 312-line frames; why the 192-line picture is the same in both; the 128-colour NTSC and 104-colour PAL palettes; why a stock 2600 cannot auto-detect the TV system; the Harmony/Melody ARM exception and the Color/BW-switch practice; a title-screen selector and a frame-boundary mode hand-off; PAL-60; and a colour-bar test that makes the palette difference visible
> **You will build:** "the world traveler" — a 4,096-byte ROM that asks **NTSC or PAL** on a title screen, starts a colour-bar test with a moving bar and a frame counter, and switches to a timing page with `SELECT`; the visible picture is 192 lines in both modes, and the same colour bytes are painted by the console's own palette

## Introduction

Every lesson so far has ended at a `.bin` and a TV. This one asks which TV. An NTSC console draws 262 lines per frame at about 60 Hz; a PAL console draws 312 lines at about 50 Hz. The same ROM cannot simply use one number: a 262-line frame on a PAL set rolls, and a 312-line frame on an NTSC set rolls the other way. The good news is that the **picture** does not have to change. The 2600 draws a 192-line visible kernel in both regions; only the blank lines above and below it differ. One kernel, two timing tables, and a way to choose between them is enough for one cartridge to work on both.

The way to choose is the hard part. A stock 2600 has **no independent timebase**. The RIOT timer and the TIA count the same CPU clock. The NTSC and PAL crystals differ by about one percent, and an 8-bit timer cannot measure that difference against a frame without an external reference. Software-only auto-detection is therefore impossible on a stock console; a cartridge that claims it is either measuring something else or using a flash cart's coprocessor. This lesson states that plainly and does the honest thing instead: a title-screen selector. The default is NTSC; a PAL user selects PAL with the joystick, and the next frame switches to the 312-line timing. A PAL user may see the default 262-line title roll before making the selection. That is the real behaviour of the design, and the document says so.

The artifact is **"the world traveler"**, a 4,096-byte ROM. The title screen offers **NTSC** and **PAL**; up/down moves the underline and fire starts. The picture is a colour-bar test: eight vertical bars, a moving eight-pixel ball, the word **NTSC** or **PAL**, and a frame counter. `SELECT` shows the timing page: the line count (`LN262` or `LN312`), the frame counter, and the colour count (`CL128` or `CL104`). The same colour bytes are used in both modes; the console's palette paints them. The lesson measures the frame with the Stella debugger at every step: `StartFrame` 259/3 or 309/3, `VblankStart` 0/5, `BodyStart` 37/5 or 45/5, `OverscanStart` 229/6 or 301/6.

::: details TypeScript Equivalent

A TypeScript model of the selector and the timing tables is short. The point of the model is the same as the point of the ROM: the mode is a value, the frame is a function of that value, and the console does not tell you which value to use.

```typescript
type TvMode = 'NTSC' | 'PAL';
type Screen = 'title' | 'picture' | 'timing';

interface Console {
  mode: TvMode;
  pending: TvMode;
  screen: Screen;
  frame: number;
  barX: number;
  prevUp: boolean;
  prevDown: boolean;
  prevFire: boolean;
  prevSelect: boolean;
  fromTitle: boolean;   // the timing page remembers where it came from
}

interface Timing {
  frameLines: number;   // 262 or 312
  vblankLines: number;  // 37 or 45
  bodyStart: number;    // 37 or 45
  overscanStart: number;// 229 or 301
  pictureLines: number; // 192 in both
}

function timing(mode: TvMode, pal60 = false): Timing {
  if (mode === 'PAL' && !pal60) {
    return { frameLines: 312, vblankLines: 45, bodyStart: 45,
             overscanStart: 301, pictureLines: 192 };
  }
  return { frameLines: 262, vblankLines: 37, bodyStart: 37,
           overscanStart: 229, pictureLines: 192 };
}

function step(c: Console, input: {
  up: boolean; down: boolean; fire: boolean; select: boolean;
}): void {
  // The edge tests are the 6502's new & ~previous.  Up/down are accepted
  // on every screen; fire only starts the picture from the title.
  if (input.up && !c.prevUp) c.pending = 'NTSC';
  if (input.down && !c.prevDown) c.pending = 'PAL';
  if (input.fire && !c.prevFire && c.screen === 'title') c.screen = 'picture';
  if (input.select && !c.prevSelect) {
    if (c.screen === 'title') {
      c.screen = 'timing';
      c.fromTitle = true;
    } else if (c.screen === 'timing') {
      c.screen = c.fromTitle ? 'title' : 'picture';
      c.fromTitle = false;
    } else {
      c.screen = 'timing';
      c.fromTitle = false;
    }
  }
  c.prevUp = input.up;
  c.prevDown = input.down;
  c.prevFire = input.fire;
  c.prevSelect = input.select;
  c.frame = (c.frame + 1) & 0xff;
  // The real machine applies pending at the frame boundary, not here.
}

function applyPending(c: Console): void {
  c.mode = c.pending;
}
```

The analogy breaks in four places that matter. First, there is no `console.mode` register: `TVMode` is a byte at `$80`, and the timing tables are indexed by it. Second, the TypeScript `Timing` object is free; the 2600 pays for it with two RIOT timer values and a line budget, and the timer's start cycle is part of the arithmetic. Third, the selector is not a menu system: the 2600 has no operating system, no text renderer, and no frame buffer, so the labels are a 4×7 font composed into playfield bytes by hand. Fourth, and most important, `applyPending` is not a formality. On the real machine the new mode is applied **after** the last line of the old frame, so a frame is never half NTSC and half PAL; a mid-frame change would change the number of blank lines under a picture that has already started.

:::

## Theory

### Section 1: The Two Frames — 262 Lines and 312 Lines

A frame is a sequence of scanlines. The TIA does not know how many lines a frame should have; the program decides by waiting for the right number of `WSYNC` boundaries and then pulsing `VSYNC`. The NTSC convention used throughout the course is:

| Phase | NTSC lines | PAL lines |
|---|---:|---:|
| VSYNC | 3 | 3 |
| VBLANK (upper border) | 37 | 45 |
| Visible kernel | 192 | 192 |
| Lower border (VBLANK off) | 0 | 64 |
| Overscan (VBLANK on) | 30 | 8 |
| **Frame total** | **262** | **312** |
| Frame rate | ~60 Hz | ~50 Hz |

The visible kernel is **192 lines in both modes**. The difference is entirely in the blank padding: PAL has eight more VBLANK lines at the top and 42 more lines after the picture (64 lower-border lines plus 8 blanked overscan lines, instead of 30 blanked overscan lines). A real PAL set expects the 312-line total; an NTSC set expects 262. The picture can be identical because the same 192-line kernel sits between the two borders.

The labels the debugger checks are a consequence of this table. The full frame is numbered from the first VBLANK line (`0`) to the last line before the next VSYNC. The VSYNC starts at line **259** on NTSC and **309** on PAL, and its first instruction is the `StartFrame` checkpoint. The first visible line is `BodyStart` at **37** or **45**. The last visible line is 228 or 236; the line after it is `BodyEnd` at **229** or **237**. The first overscan instruction is `OverscanStart` at **229** or **301**. The difference between `BodyStart` and `OverscanStart` is 192 lines on NTSC and 256 on PAL: 192 visible lines plus the 64-line PAL lower border. The state log, not the still image, proves the split.

The 64-line lower border is a deliberate design choice. PAL's nominal 72-line post-picture interval is split into 64 lines with VBLANK **off** and an 8-line blanked tail. The border is painted with `COLUBK = 0`, so it looks exactly like a normal black PAL border, and the last 8 lines are blanked by VBLANK before the VSYNC. The reason for the split is the checkpoint contract: the visible kernel is 192 lines, `BodyStart` is 45, and the `OverscanStart` label is the first instruction of the blanked tail at 301. A single 72-line blanked overscan would put the label at 237, which would make the 192-line visible-kernel claim impossible to state with the same label. The ROM proves the split: `BodyEnd` is at 237/0 and `OverscanStart` at 301/6; the 64 lines between them are the lower border.

::: tip The frame rate is a clock, not a line count
The TV derives its vertical rate from the line count and the horizontal rate, not from an internal 60/50 Hz setting. That is why a fixed 262-line ROM "rolls" on a PAL set: the set is trying to lock to 50 fields per second, and the ROM is sending 60. The 6507 cannot see the set's field rate; it only sees its own clock.
:::

### Section 2: The Visible Kernel — One 192-Line Ledger

The picture is a sequence of **bands**. Each band is a few scanlines tall, and the whole sequence adds up to exactly 192 lines. The per-screen sums are exact. The `+1` is `FinalBars`' black alignment line; the `+5`/`+7` are the transition lines between the bands (five for the six-band title/picture, seven for the eight-band timing):

| Screen | Lines | Sum |
|---|---|---:|
| Title | 8 black + 48 bars + 11 label + 16 bars + 11 label + 92 final + 1 + 5 | 192 |
| Picture | 8 black + 16 bars + 11 label + 126 bars + 11 frame + 14 final + 1 + 5 | 192 |
| Timing | 8 black + 40 bars + 11 line + 24 bars + 11 frame + 24 bars + 11 colour + 55 final + 1 + 7 | 192 |

The text band's 11 lines are **2 setup + 8 glyph + 1 clear**. The setup is 85 cycles, so it overruns the line and needs two setup lines; the final bands are 92, 14 and 55 bars. The authoritative total is the pair `BodyStart`/`OverscanStart`: 37 → 229 and 45 → 301 in the state log.

The band routines are deliberately small. `BlackLines` draws a number of black lines; `BarLines` draws the eight colour bars; `TextBand` draws two setup lines, eight glyph rows and one black clear line; `FinalBars` is the last band and ends at cycle 0 so the overscan label can be hit at cycle 6. `BlackLines` is entered on the `BodyStart` line and has no leading `WSYNC`; its first line is one of the eight black lines. Each later band starts with a `STA WSYNC` that consumes the previous separator, and `FinalBars` ends with a black alignment line (the `+1`). The line count is the number of `WSYNC` boundaries, not a loop counter that can drift.

The **colour bars** use the Lesson 18 mid-line technique. A `STA COLUBK` takes effect from colour clock 3 × the cycle of the next instruction. The body starts at cycle 5, and the eight stores hit cycles 22, 29, 36, 43, 50, 57, 64 and 71. The visible picture starts at clock 68, so the first bar is a little narrower than the rest; the measured widths in the 960-pixel capture are 114, 126 × 6, 90 pixels. The bars are the same eight colour values in both modes; the PAL console maps them through its own palette, which is why the PAL capture looks so different.

The **moving bar** is the ball. `CTRLPF = $30` makes it eight pixels wide, `ENABL = 2` turns it on, and the divide-by-15 routine in `SetBallPos` places it once per frame with one `HMOVE`. `BarX` starts at 16, moves one pixel per frame, and wraps from 151 to 16; the ball is eight pixels wide, so X=151 ends at pixel 159. The ball is disabled on the text rows (`ENABL = 0`), so the label and the frame counter stay readable; it is enabled again on the clear line, so it crosses the bars and the black bands. The PAL border clears `ENABL`; the overscan restores it after `STA VBLANK`, so the next frame's top bands keep the bar.

The **text** is a 4×7 glyph font. The playfield half is 20 chunks wide, each chunk is four colour clocks, and a glyph is four chunks wide, so five characters fit exactly. The five-character strings are `NTSC `, `PAL  `, `LN262`, `LN312`, `CL128`, `CL104` and `FRnnn`. The composer writes a 24-byte buffer: eight PF0 rows, eight PF1 rows, eight PF2 rows. PF0's bit 4 is the leftmost chunk, PF1's bit 7 is the leftmost, and PF2's bit 0 is the leftmost, so the four-bit glyph rows are mapped with a small reverse table and a shift. The title underlines the selected word in row 7 of its buffer. The picture and timing screens use the same band routine; only the buffer changes.

### Section 3: The Palettes — 128 Colours and 104 Colours

A TIA colour byte is `CCCCLLL0`: four hue bits, three luminance bits, and a bit that is not used. The even bytes `$00, $02, ... $FE` are the 128 NTSC values. PAL has 104 defined values; the same byte does not necessarily produce the same hue, and some PAL values repeat. The lesson's eight bar colours are NTSC values chosen for a readable test pattern:

| Bar | Value | NTSC name | What PAL does |
|---|---|---|---|
| 0 | `$0E` | light grey | light grey (similar) |
| 1 | `$1A` | gold | grey-yellow |
| 2 | `$2E` | orange | yellow |
| 3 | `$3E` | peach | green-yellow |
| 4 | `$42` | red | brown |
| 5 | `$5E` | pink | mint |
| 6 | `$84` | blue | magenta |
| 7 | `$C8` | green | purple |

The table is a guide, not a specification: the exact colours depend on the console's palette and the TV's adjustment. The point is that the **same byte** is painted differently. The lesson's colour-bar test makes that visible; the timing page shows `CL128` on NTSC and `CL104` on PAL. Exercise 3 goes further: a 16×8 grid of all 128 values, so the two palettes can be compared side by side on the same TV.

::: tip 104 is not "the first 104 of 128"
The PAL palette is not a prefix of the NTSC palette and it is not a subset of it. The PAL TIA has its own hue assignments, and the values that are not defined are not simply "missing colours". A universal ROM should treat the colour byte as an index into the console's palette, not as an RGB value.
:::

### Section 4: Why a Stock 2600 Cannot Auto-Detect the TV System

This is the section the lesson must get right, because the obvious idea is wrong.

A stock 2600 has **one clock**. The 6507 CPU, the RIOT timer and the TIA all derive from the same crystal. The NTSC crystal is 3.579545 MHz (colour clock) and the PAL crystal is 3.546894 MHz; the CPU clocks are 1.193182 MHz and 1.182298 MHz. The difference is about **0.9 percent**. The RIOT timer can count CPU cycles in 64-cycle ticks (`TIM64T`), and the TIA counts colour clocks. Neither has an independent reference. The frame's line count is the program's own `WSYNC` count, not a counter the TIA exposes. If the program starts a timer and counts how many lines elapse, it is measuring the same clock with the same clock: the ratio is fixed by the code, not by the TV system. The 0.9 percent difference changes the **real-time** length of a frame by about 0.9 percent, but the console has no way to know what a second is. A human with a stopwatch is an external reference; a ROM is not.

The difference in frame structure is equally unhelpful. The ROM decides how many lines to draw. It can draw 262 lines or 312 lines, but it cannot observe the TV's reaction. The only signals the console can read are the controllers, the console switches, and its own timer; none of them carries the TV system. The Color/BW switch is a **manual** switch: bit 3 of `SWCHB` tells the program which position the user chose, not which crystal the console has. Some games use B&W as a "PAL/50 Hz" setting; that is a user decision, not detection.

The honest conclusion is:

- **A stock cartridge cannot auto-detect NTSC vs PAL.** It can only ask the user, or ship as two builds.
- **A custom Harmony/Melody firmware could.** The cart carries an ARM coprocessor with its own clock, so custom firmware can measure the console's frame/line timing and pass a byte to the 6507. The **shipped** Harmony menu is not automatic: it supplies NTSC / PAL50 / PAL60 firmware variants and the user selects one, and DPC+ builds choose the region at compile time. That is a property of the custom firmware, not of a stock cartridge.
- **The Color/BW switch is a manual selector.** It is useful when a game wants a one-switch region control; it is not an automatic test.
- **This lesson uses a title-screen selector.** It is visible, reversible, works with one joystick, and does not pretend to detect anything.

The default is NTSC. A PAL user sees the 262-line title screen roll on a PAL TV until the selection is made. After the selection the 312-line frame is stable. The lesson says this in the introduction, in the theory, and in the capture notes; it never claims a runtime detection the hardware cannot perform.

::: warning The ~1% trap
It is tempting to think that a timer running for a whole frame is long enough to resolve a 1% difference. It is not. A frame is about 20,000 CPU cycles; 1% is about 200 cycles, which is less than three scanlines. The RIOT timer's resolution is 64 cycles and its read is not synchronized to the frame; the frame is the program's `WSYNC` count, not a TIA counter. There is no independent interval to compare against, so the measurement collapses to "the program counted its own clock".
:::

### Section 5: The Harmony/Melody Exception and the Color/BW Practice

A **Harmony** or **Melody** cart is not a plain ROM board. It contains an ARM microcontroller, flash, and RAM; the ARM can run firmware, read the console's buses, and present a ROM image to the 6507. Because the ARM has its own clock, a **custom** firmware can measure the 2600's frame rate or line rate and expose the result to the cartridge program (for example, a configuration byte set by the firmware). The **shipped** Harmony menu is region-specific: it supplies NTSC / PAL50 / PAL60 firmware variants and the user selects one, and DPC+ builds choose the region at compile time. The measurement ability lives in the **cartridge's coprocessor**, not in the console. A stock cartridge has no ARM, no independent clock, and no way to perform the same measurement.

The **Color/BW switch** is the console's bit 3 of `SWCHB`: 1 = COLOR, 0 = B&W. Some games use it as a manual region switch because it is a physical switch the user can set before power-on. The practice is honest as long as the manual label says so; it is not detection. The lesson's title selector is a different manual mechanism: it is on screen, it can be changed without a power cycle, and it teaches the user what is happening.

| Approach | Stock cartridge | Harmony/Melody | What it really is |
|---|---|---|---|
| Timer/line counting | no | custom firmware only | an independent clock; the shipped menu is region-specific |
| Color/BW switch | yes | yes | a manual user choice |
| Title selector | yes | yes | a manual user choice |
| Two separate builds | yes | yes | two ROMs, not one |

### Section 6: The Title Selector and the Frame-Boundary Hand-Off

The selector is a small state machine. `TVMode` at `$80` is 0 for NTSC and 1 for PAL. `PendingMode` at `$8A` is the value the user requested; `ModeDirty` at `$8B` says a change is waiting. Up sets `PendingMode = 0`, down sets `PendingMode = 1`, and either edge sets `ModeDirty = 1`. The title's underline is drawn from `TVMode`, so the selected word is visible. Fire starts the picture; `SELECT` opens the timing page.

The important detail is **when** the pending mode becomes active. The VBLANK timer for the current frame has already started, and the visible kernel has not run yet. If `TVMode` changed in the middle of VBLANK, the frame would use one VBLANK length and another body length, and the total would be neither 262 nor 312. The ROM therefore applies `PendingMode` **after** the last line of the frame, in the overscan, before the next `JMP StartFrame`. The frame that handled the key press is a complete frame in the old mode; the next frame is a complete frame in the new mode. The state log shows the hand-off: `TVMode` is 0 on the frame of the down press and 1 from the next frame (the PAL log below quotes both `TVModeRead` lines), and the frame labels change from 259/37/229 to 309/45/301 together.

`FrameLines` is the 16-bit line count. 262 is `$0106`, 312 is `$0138`; the low byte is at `$81` and the high byte at `$82`. A is an 8-bit register, so the checkpoint `FrameLinesRead` reports the **low** byte (`$06` or `$38`); the high byte is `$01` in both modes. The source documents the byte layout in the header and in the checkpoint table. `TimingMode` at `$AB` is the value the timing tables actually use; in the lesson ROM it follows `TVMode`. The PAL-60 exercise sets `PAL60 = 1`, which forces `TimingMode = 0` while `TVMode` stays 1, so the label and colour count say PAL but the frame is 262 lines.

### Section 7: PAL-60 — A 262-Line Frame on a PAL Console

**PAL-60** is a compatibility mode, not a PAL standard. It sends a 262-line, ~60 Hz frame to a PAL console. The console's crystal and palette are PAL, so the colours are the PAL colours; the frame length is the NTSC length, so the set runs at about 60 Hz. Many PAL TVs accept it, some do not; a game that ships PAL-60 should say so. It is useful for ports whose game logic is tied to 60 Hz, and it is a good exercise because it separates the two ideas that are easy to conflate:

- **TV system / palette**: which console is this? (`TVMode`)
- **Frame timing**: how many lines is the frame? (`TimingMode` / `FrameLines`)

The main lesson keeps them together. Exercise 2 sets `DEFAULT_TV = 1` and `PAL60 = 1`: `TVMode = 1` (the label says PAL, the colour count says 104) but `TimingMode = 0` (262 lines, VBLANK 37, overscan 229, `StartFrame` 259). Run it on a PAL console (`stella -format PAL`): the palette is PAL and the frame is 60 Hz. The exercise's state log shows `TVMode` A=1 and `FrameLines` A=$06/$01; the line count follows the timing, not the label.

### Section 8: The Colour-Bar Test and the Text Bands

The colour-bar test is deliberately simple. Eight vertical bars are painted by changing `COLUBK` at fixed cycles; the ball moves across them; the label says which mode is active; the frame counter advances. The test is not a calibration tool. It shows that the same eight bytes look different on the two consoles, and it gives the reader a stable picture to compare.

The text is a 4×7 font because the playfield is a 20-chunk half and five characters of four chunks each fill it exactly. The font is stored as eight rows per glyph, with bit 3 as the leftmost column. The composer maps five glyphs into the three playfield bytes per row:

```text
PF0 = Rev4[g0] << 4
PF1 = (g1 << 4) | g2
PF2 = Rev4[g3] | (Rev4[g4] << 4)
```

`Rev4` reverses the four bits. The formula looks asymmetric because the TIA's three playfield registers run in different bit orders: PF0's leftmost chunk is bit 4, PF1's is bit 7, and PF2's is bit 0. The buffer is column-major (eight PF0 rows, then eight PF1 rows, then eight PF2 rows), so the band routine can copy one row with three pointer-indexed loads and three stores. The title's underline is row 7 of the selected label's buffer: `$FF, $FF, $0F` for a four-character word, `$FF, $FF, $00` for a three-character word.

The `TextBand` routine draws **two** setup lines, eight glyph rows, and one black clear line: **2 + 8 + 1 = 11**. The setup is 85 cycles, so it overruns the line; the leading `WSYNC` plus the setup's own `WSYNC` are the two setup lines. The setup loads row 0 while `COLUPF` is black, so the playfield data is invisible; the first glyph line turns `COLUPF` white and the row appears. Rows 1–7 load their bytes in HBLANK, before the visible area, and the clear line restores the white ball. Because `CTRLPF` repeats the 20-chunk half, every label appears twice on screen, once in each half.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson65.bin lessons/part8-advanced/65-pal-ntsc-universal/65-pal-ntsc-universal.asm
stella build/lesson65.bin
```

The committed ROM is `docs/public/roms/part8-advanced/65-pal-ntsc-universal/65-pal-ntsc-universal.bin`, 4,096 bytes. The source is `lessons/part8-advanced/65-pal-ntsc-universal/65-pal-ntsc-universal.asm`. The three exercise solutions live beside it as `exercise-01-solution.asm`, `exercise-02-solution.asm` and `exercise-03-solution.asm`; each assembles to 4,096 bytes and is included in `npm run roms`.

To see the PAL path in Stella 7, set the console format explicitly. The old `-pal` option is not the console-format switch in Stella 7; `-format PAL` is. The selector capture uses no input; the PAL capture holds down and fire from power-on, so the first frame starts the picture with the default NTSC timing and the pending mode applies at the frame boundary.

```bash
# title selector, default NTSC
stella docs/public/roms/part8-advanced/65-pal-ntsc-universal/65-pal-ntsc-universal.bin

# PAL test screen: the first frame is the default NTSC picture, then the
# pending mode applies and the picture is PAL from the next frame
stella -format PAL -holdjoy0 'D,F' \
  docs/public/roms/part8-advanced/65-pal-ntsc-universal/65-pal-ntsc-universal.bin
```

### Full Source

The complete annotated source:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 65: PAL/NTSC Universal ROM — One Cart, Every TV
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the world traveler": a 4,096-byte ROM that runs on an NTSC console
;   (262 lines, ~60 Hz) and on a PAL console (312 lines, ~50 Hz).  A stock
;   2600 cannot detect which TV system it is connected to, so the program
;   asks: the title screen offers NTSC and PAL, the joystick's up/down
;   moves the underline, and fire starts the test picture.  TVMode 0 is
;   NTSC and TVMode 1 is PAL.
;
;   The picture is a colour-bar test: eight vertical bars drawn by
;   changing COLUBK at fixed cycles inside each line, a moving eight-pixel
;   ball, the word NTSC or PAL in the playfield, and a frame counter
;   (FR nnn).  SELECT shows the timing page: the line count, the frame
;   count, and the colour count (LN262/FRnnn/CL128, or LN312/FRnnn/CL104).
;
;   The test is deliberately honest about the palette: NTSC has 128 colour
;   values and PAL has 104; the same TIA colour byte can look different on
;   the two consoles.  The colour bars are a test pattern, not a promise
;   that the hues match.
;
; Why the selector, and not auto-detection:
;   A stock 2600 has no independent timebase.  The RIOT timer and the TIA
;   count the same CPU clock; the NTSC/PAL crystal difference is about 1%
;   (NTSC 3.579545 MHz vs PAL 3.546894 MHz colour clock), which an 8-bit
;   timer cannot resolve without an external clock.  Software-only
;   auto-detection is therefore impossible.  A custom Harmony/Melody
;   firmware could measure the console with the ARM's own clock, but the
;   shipped Harmony menu is region-specific and user-selected; DPC+ builds
;   choose the region at compile time.  A stock cartridge cannot measure
;   the console at all.  Some games use the Color/BW switch as a manual
;   region selector; this lesson uses a title-screen selector
;   because it is visible, reversible, and works with one joystick.
;
;   The default mode is NTSC.  A PAL user may see the 262-line title roll
;   on a PAL TV until PAL is selected; after the selection the 312-line
;   frame is stable.  The lesson states this plainly rather than claiming
;   a detection that the hardware cannot perform.
;
; The frame:
;   NTSC: 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262 lines.
;     StartFrame 259/3, VblankStart 0/5, BodyStart 37/5,
;     BodyEnd 229/0, OverscanStart 229/6.
;   PAL: 3 VSYNC + 45 VBLANK + 192 visible + 64 lower border + 8 overscan
;     = 312 lines.  PAL's post-picture interval is 72 lines; this build
;     splits it into 64 lower-border lines with VBLANK off (the background colour
;     is black, so it looks like a normal PAL border) and an 8-line
;     blanked overscan tail.  StartFrame 309/3, VblankStart 0/5,
;     BodyStart 45/5, BodyEnd 237/0, OverscanStart 301/6.
;   The visible kernel is 192 lines in both modes.
;
; The RIOT timer values (the first tick lands one cycle after the write,
; so t ticks cover 1 + (t-1) x 64 cycles; +wait_timer anchors to the next
; scanline):
;   NTSC VBLANK   44 ticks = 2,753 cycles -> line 37.
;   NTSC overscan 36 ticks = 2,241 cycles -> line 259.
;   PAL  VBLANK   53 ticks = 3,329 cycles -> line 45.
;   PAL  border   76 ticks = 4,801 cycles -> line 301.
;   PAL  overscan  9 ticks =   513 cycles -> line 309.
;   The timer starts at the STA TIM64T instruction, not at the first cycle
;   of the VBLANK line: the mode lookup and the STA VBLANK put it at cycle
;   15-20.  The PAL values are one tick below the naive 54/10 because,
;   with that later start, 54/10 would expire after the line boundary the
;   final WSYNC needs; 53/9 keeps the 45/301/309 lines.
;   The state log proves the actual lines (45, 301, 309); the arithmetic is
;   in the values above and in the checkpoint table in the document.
;   No value uses the classic 43/35 one-tick-short pair: the lesson wants
;   the nominal periods.
;
; The colour bars (Lesson 18 mid-line technique):
;   A store paints from colour clock 3 x the cycle of the next instruction.
;   The body starts at cycle 5; the eight stores hit cycles 22, 29, 36,
;   43, 50, 57, 64 and 71, so the visible boundaries are at clocks 66, 87,
;   108, 129, 150, 171, 192 and 213.  The measured widths in the 960-pixel
;   capture are 114, 126 x 6, 90 pixels.  The bars are identical in both
;   modes; only the palette behind the colours changes.
;
; The text:
;   A 20-chunk playfield half holds exactly five four-chunk characters.
;   The glyphs are 4x7 (bit 3 is the leftmost column) and are composed
;   into a 24-byte buffer: eight PF0 rows, eight PF1 rows, eight PF2 rows.
;   The text band draws two setup lines (the leading WSYNC and the
;   85-cycle setup's own WSYNC), eight glyph rows, and one black clear
;   line: 2 + 8 + 1 = 11.  Each band's leading WSYNC consumes the previous
;   separator line.  The title underlines the selected word in row 7 of
;   its buffer.  SELECT switches the main picture to the timing page.
;
; The selector hand-off:
;   Up/down writes PendingMode; the mode is applied at the end of the
;   frame, before the next VSYNC.  The current frame's VBLANK and body
;   timing stay consistent, so a mode switch can never produce a frame
;   that is half NTSC and half PAL.  The state log shows TVMode 0 on the
;   frame of the key press and 1 from the next frame.
;
; Checkpoints (label, Stella scanline/cycle, and the A register):
;   StartFrame    259/3 (NTSC), 309/3 (PAL)  the first VSYNC instruction
;   VblankStart     0/5                      the first VBLANK instruction
;   BodyStart      37/5 (NTSC), 45/5 (PAL)   the first visible line
;   BodyEnd       229/0 (NTSC), 237/0 (PAL)  the line after the kernel
;   OverscanStart 229/6 (NTSC), 301/6 (PAL)  the first overscan instruction
;   TVModeRead    A = 0 (NTSC) or 1 (PAL), the active timing mode
;   FrameLinesRead A = the low byte of the 16-bit line count:
;                 $06 (262 = $0106) or $38 (312 = $0138); the high byte
;                 at FrameLinesHi is $01 in both modes
;   FrameRead     A = the free-running frame counter, 0..255
;   ModeWrite     A = the new pending mode, 0 or 1 (up/down edge)
;   ScreenWrite   A = the new screen, 0 title, 1 picture, 2 timing
;   FrameLinesHiRead A = $01, the high byte of the line count
;
; RAM map (+clean_start zeroes every byte):
;   $80 TVMode        0 = NTSC timing, 1 = PAL timing (the active mode)
;   $81 FrameLinesLo  low byte of the 16-bit line count ($06 or $38)
;   $82 FrameLinesHi  high byte ($01 in both modes)
;   $83 Frame         free-running frame counter, 0..255
;   $84 BarX          the ball's target X, 16..151, one pixel per frame
;   $85 Screen        0 = title, 1 = test picture, 2 = timing page
;   $86 PrevUp        the up level last frame (1 = pressed)
;   $87 PrevDown      the down level last frame
;   $88 PrevFire      the fire level last frame (1 = pressed)
;   $89 PrevSelect    the SELECT level last frame (1 = pressed)
;   $8A PendingMode   the mode requested by up/down, applied at frame end
;   $8B ModeDirty     1 = PendingMode must be copied to TVMode
;   $8C TextDirty     1 = the static text buffers must be rebuilt
;   $8D FromTitle     1 = the timing page was entered from the title
;   $8E FrameHundreds the frame counter's hundreds digit
;   $8F FrameTens     the tens digit
;   $90 FrameOnes     the ones digit
;   $91-$95 TextChars the five glyph codes of the text being composed
;   $96-$97 TextPtr   the source string pointer / the buffer pointer
;   $98-$99 TextDest  the destination buffer pointer
;   $9A-$9B Dest1     TextDest + 8
;   $9C-$9D Dest2     TextDest + 16
;   $9E-$9F GlyphPtr0 the first character's glyph pointer
;   $A0-$A1 GlyphPtr1
;   $A2-$A3 GlyphPtr2
;   $A4-$A5 GlyphPtr3
;   $A6-$A7 GlyphPtr4
;   $A8 free
;   $A9 Scratch       a temporary byte
;   $AA free
;   $AB TimingMode    0 = 262-line timing, 1 = 312-line timing; PAL-60
;                     forces 0 while TVMode stays 1 (the label/colours)
;   $AC-$AF free (4 bytes)
;   $B0-$C7 LabelBuf  the main/title/timing label buffer
;   $C8-$DF FrBuf     the frame-counter buffer
;   $E0-$F7 AltBuf    the second title label / the colour-count buffer
;   $F8-$FF stack
;
; Build: acme -f plain -o build/lesson65.bin \
;        lessons/part8-advanced/65-pal-ntsc-universal/65-pal-ntsc-universal.asm
; Run:   stella build/lesson65.bin
;        stella -format PAL -holdjoy0 'D,F' build/lesson65.bin   (PAL test screen)
; The ROM is 4,096 bytes.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; CONSTANTS
; =============================================================================
; The compile-time hooks the exercises use.  0 in the lesson ROM:
;   DEFAULT_TV = 0 (NTSC) / 1 (PAL) — the mode at power-on.
;   PAL60     = 1 keeps the PAL label/colour count but uses the 262-line
;               timing, i.e. a 60 Hz frame on a PAL console.
DEFAULT_TV = 0
PAL60      = 0

; The RIOT timer values.  See the header for the arithmetic.
NTSC_VBLANK_TIMER   = 44
NTSC_OVERSCAN_TIMER = 36
PAL_VBLANK_TIMER    = 53
PAL_OVERSCAN_TIMER  = 9
PAL_BORDER_TIMER    = 76

; The eight colour-bar values.  They are NTSC values; the PAL console maps
; the same bytes through its own palette, which is why the test is useful.
BAR0 = $0E                  ; light grey
BAR1 = $1A                  ; gold
BAR2 = $2E                  ; orange
BAR3 = $3E                  ; peach
BAR4 = $42                  ; red
BAR5 = $5E                  ; pink
BAR6 = $84                  ; blue
BAR7 = $C8                  ; green

; The playfield text colour (the ball shares COLUPF).
TEXT_COLOR = $0E            ; white

; The screen numbers.
SCREEN_TITLE   = 0
SCREEN_PICTURE = 1
SCREEN_TIMING  = 2

; The glyph codes used by the five-character strings.  0-9 are the digits;
; the letters follow in the order of the font table.
GLYPH_0      = 0
GLYPH_1      = 1
GLYPH_2      = 2
GLYPH_3      = 3
GLYPH_4      = 4
GLYPH_5      = 5
GLYPH_6      = 6
GLYPH_7      = 7
GLYPH_8      = 8
GLYPH_9      = 9
GLYPH_F      = 10
GLYPH_R      = 11
GLYPH_N      = 12
GLYPH_T      = 13
GLYPH_S      = 14
GLYPH_C      = 15
GLYPH_P      = 16
GLYPH_A      = 17
GLYPH_L      = 18
GLYPH_SPACE  = 19

; The bar's travel.  The ball is eight pixels wide, so X=16 is the left
; margin and X=151 ends at pixel 159, the right edge of the visible area.
BAR_MIN = 16
BAR_MAX = 151

; =============================================================================
; RAM
; =============================================================================
TVMode        = $80
FrameLinesLo  = $81
FrameLinesHi  = $82
Frame         = $83
BarX          = $84
Screen        = $85
PrevUp        = $86
PrevDown      = $87
PrevFire      = $88
PrevSelect    = $89
PendingMode   = $8A
ModeDirty     = $8B
TextDirty     = $8C
FromTitle     = $8D
FrameHundreds = $8E
FrameTens     = $8F
FrameOnes     = $90
TextChars     = $91           ; five bytes, $91-$95
TextPtr       = $96           ; two bytes
TextDest      = $98           ; two bytes
Dest1         = $9A           ; two bytes
Dest2         = $9C           ; two bytes
GlyphPtr0     = $9E           ; two bytes
GlyphPtr1     = $A0
GlyphPtr2     = $A2
GlyphPtr3     = $A4
GlyphPtr4     = $A6
Scratch       = $A9
TimingMode    = $AB
; $AC-$AF free
LabelBuf      = $B0           ; 24 bytes: PF0 rows, PF1 rows, PF2 rows
FrBuf         = $C8           ; 24 bytes
AltBuf        = $E0           ; 24 bytes
; $F8-$FF stack

; =============================================================================
; RESET — power-on entry
; =============================================================================
    * = $F000
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (joysticks)
    STA SWBCNT              ; port B is an input port (console switches)

    ; --- the default mode ------------------------------------------------
    ; A PAL user selects PAL on the title screen.  The default is NTSC
    ; because the NTSC frame is the course baseline, and because the
    ; console cannot tell us which one it is.  DEFAULT_TV is the exercise
    ; hook that makes a PAL-default build.
    LDA #DEFAULT_TV
    STA TVMode
    STA PendingMode
    STA ModeDirty
    JSR SetTiming            ; TimingMode and the 16-bit FrameLines
    LDA #$00
    STA Screen
    STA Frame
    STA FromTitle
    STA PrevUp
    STA PrevDown
    STA PrevFire
    STA PrevSelect
    LDA #BAR_MIN
    STA BarX
    LDA #$01
    STA TextDirty            ; the first VBLANK builds the title texts

    ; --- the fixed TIA state ----------------------------------------------
    LDA #TEXT_COLOR
    STA COLUPF               ; the text and the moving ball are white
    STA COLUP0
    STA COLUP1
    LDA #$00
    STA COLUBK
    STA PF0
    STA PF1
    STA PF2
    LDA #$30                 ; ball size 8, repeat playfield, no priority
    STA CTRLPF
    LDA #$02
    STA ENABL                ; the moving ball is on outside the text bands

    ; --- the first frame-counter text -------------------------------------
    JSR BuildFrame           ; "FR000" before the first visible frame

    ; --- place the ball once before the first frame -----------------------
    JSR SetBallPos

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + VBLANK + 192 visible + overscan/border = 262 or 312
; =============================================================================
StartFrame:                 ; checkpoint: 259/3 (NTSC) or 309/3 (PAL)
    +vsync

VblankStart:                ; checkpoint: scanline 0, cycle 5
    LDA #$02
    STA VBLANK
    LDX TimingMode
    LDA VblankTimers,X
    STA TIM64T               ; the VBLANK timer starts at the top of line 0

    ; --- the mode and line-count checkpoints ------------------------------
    LDA TVMode
TVModeRead:                 ; checkpoint: A = 0 (NTSC) or 1 (PAL)
    NOP
    LDA FrameLinesLo
FrameLinesRead:             ; checkpoint: A = $06 (262) or $38 (312)
    NOP
    LDA FrameLinesHi
FrameLinesHiRead:           ; checkpoint: A = $01 (the high byte)
    NOP

; -----------------------------------------------------------------------------
; 1. THE INPUTS AND THE EDGES
; -----------------------------------------------------------------------------
    ; Up: SWCHA bit 4, active low.  NewUp = 1 while pressed.
    LDA SWCHA
    AND #$10
    EOR #$10
    STA Scratch              ; Scratch = NewUp
    AND PrevUp
    EOR Scratch
    BEQ NoUpEdge
    LDA #0
    STA PendingMode          ; up selects NTSC
    LDA #1
    STA ModeDirty
    LDA PendingMode
ModeWrite:                   ; checkpoint: A = the new pending mode (0)
    NOP
NoUpEdge:
    LDA Scratch
    STA PrevUp

    ; Down: SWCHA bit 5, active low.
    LDA SWCHA
    AND #$20
    EOR #$20
    STA Scratch
    AND PrevDown
    EOR Scratch
    BEQ NoDownEdge
    LDA #1
    STA PendingMode          ; down selects PAL
    LDA #1
    STA ModeDirty
    LDA PendingMode
ModeWriteDown:               ; checkpoint: A = 1 on a down edge
    NOP
NoDownEdge:
    LDA Scratch
    STA PrevDown

    ; Fire: INPT4 bit 7, active low.
    LDA INPT4
    AND #$80
    EOR #$80
    STA Scratch
    AND PrevFire
    EOR Scratch
    BEQ NoFireEdge
    LDA Screen
    BNE NoFireEdge           ; fire only starts from the title
    LDA #SCREEN_PICTURE
    STA Screen
    STA FromTitle            ; not used for fire, but keep it clear
    LDA #1
    STA TextDirty
    LDA Screen
ScreenWriteFire:             ; checkpoint: A = the new screen (1)
    NOP
NoFireEdge:
    LDA Scratch
    STA PrevFire

    ; SELECT: SWCHB bit 1, active low.  On the title it opens the timing
    ; page and returns to the title; on the picture it toggles the timing
    ; page; on the timing page it returns to the screen it came from.
    LDA SWCHB
    AND #$02
    EOR #$02
    STA Scratch
    AND PrevSelect
    EOR Scratch
    BEQ NoSelectEdge
    LDA Screen
    CMP #SCREEN_TITLE
    BEQ SelectFromTitle
    CMP #SCREEN_TIMING
    BEQ SelectFromTiming
    ; the picture -> the timing page
    LDA #SCREEN_TIMING
    STA Screen
    LDA #0
    STA FromTitle
    BEQ SelectDone
SelectFromTitle:
    LDA #SCREEN_TIMING
    STA Screen
    LDA #1
    STA FromTitle
    BNE SelectDone
SelectFromTiming:
    LDA FromTitle
    BEQ SelectToPicture
    LDA #SCREEN_TITLE
    STA Screen
    LDA #0
    STA FromTitle
    BEQ SelectDone
SelectToPicture:
    LDA #SCREEN_PICTURE
    STA Screen
SelectDone:
    LDA #1
    STA TextDirty
    LDA Screen
ScreenWrite:                 ; checkpoint: A = the new screen
    NOP
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 2. THE FRAME COUNTER
; -----------------------------------------------------------------------------
    INC Frame
    LDA Frame
FrameRead:                   ; checkpoint: A = the free-running frame, 0..255
    NOP

; -----------------------------------------------------------------------------
; 3. THE STATIC TEXT BUFFERS (only when the screen or the mode changed)
; -----------------------------------------------------------------------------
    LDA TextDirty
    BEQ NoTextBuild
    JSR BuildStaticTexts
    LDA #$00
    STA TextDirty
NoTextBuild:

; -----------------------------------------------------------------------------
; 4. THE MOVING BAR
; -----------------------------------------------------------------------------
    LDA BarX
    CLC
    ADC #1
    CMP #BAR_MAX+1
    BCC StoreBarX
    LDA #BAR_MIN
StoreBarX:
    STA BarX
    JSR SetBallPos           ; one HMOVE, in VBLANK

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; THE VISIBLE PICTURE — 192 lines, 3 screens
; =============================================================================
BodyStart:                  ; checkpoint: 37/5 (NTSC) or 45/5 (PAL)
    LDA #$00
    STA COLUBK              ; the first line is black
    LDA Screen
    BEQ TitleScreen
    CMP #SCREEN_PICTURE
    BEQ PictureScreen
    JMP TimingScreen

; =============================================================================
; THE TITLE SCREEN — 8 + 48 + 11 + 16 + 11 + 92 + 1 + 5 = 192 lines
; =============================================================================
TitleScreen:
    LDY #8
    JSR BlackLines
    LDY #48
    JSR BarLines
    LDA #<LabelBuf
    STA TextPtr
    LDA #>LabelBuf
    STA TextPtr+1
    JSR TextBand
    LDY #16
    JSR BarLines
    LDA #<AltBuf
    STA TextPtr
    LDA #>AltBuf
    STA TextPtr+1
    JSR TextBand
    LDY #92
    JMP FinalBars

; =============================================================================
; THE PICTURE SCREEN — 8 + 16 + 11 + 126 + 11 + 14 + 1 + 5 = 192 lines
; =============================================================================
PictureScreen:
    LDY #8
    JSR BlackLines
    LDY #16
    JSR BarLines
    LDA #<LabelBuf
    STA TextPtr
    LDA #>LabelBuf
    STA TextPtr+1
    JSR TextBand
    LDY #126
    JSR BarLines
    LDA #<FrBuf
    STA TextPtr
    LDA #>FrBuf
    STA TextPtr+1
    JSR TextBand
    LDY #14
    JMP FinalBars

; =============================================================================
; THE TIMING SCREEN — 8 + 40 + 11 + 24 + 11 + 24 + 11 + 55 + 1 + 7 = 192 lines
; =============================================================================
TimingScreen:
    LDY #8
    JSR BlackLines
    LDY #40
    JSR BarLines
    LDA #<LabelBuf
    STA TextPtr
    LDA #>LabelBuf
    STA TextPtr+1
    JSR TextBand
    LDY #24
    JSR BarLines
    LDA #<FrBuf
    STA TextPtr
    LDA #>FrBuf
    STA TextPtr+1
    JSR TextBand
    LDY #24
    JSR BarLines
    LDA #<AltBuf
    STA TextPtr
    LDA #>AltBuf
    STA TextPtr+1
    JSR TextBand
    LDY #55
    JMP FinalBars

; =============================================================================
; BlackLines — Y lines of black, with the ball still visible
; =============================================================================
; Entry: at cycle 5 on the first line (from BodyStart or a band tail).
; Exit: at cycle 5 of the line after the last one (the DEY/BNE tail).
; The ball is not touched: the moving bar crosses the black border too.
BlackLines:
-   LDA #$00
    STA COLUBK
    STA WSYNC
    DEY
    BEQ BlackDone
    JMP -
BlackDone:
    RTS

; =============================================================================
; BarLines — Y lines of eight colour bars; the body starts at cycle 5
; =============================================================================
; The first STA WSYNC discards the caller's partial line, so the routine
; always starts its first body on a fresh scanline at cycle 0.  The
; BIT+NOP pair then puts the body at cycle 5.  The body's stores hit
; cycles 22, 29, 36, 43, 50, 57, 64 and 71, the Lesson 18/64 timing.
BarLines:
    STA WSYNC               ; discard the caller's partial line
    BIT Frame               ; 0-2
    NOP                     ; 3-4
BarLoop:
    LDA #BAR0               ; 5-6
    STA COLUBK              ; 7-9   hit 10 (the base, still in HBLANK)
    NOP                     ; 10-11
    NOP                     ; 12-13
    BIT Frame               ; 14-16 a 3-cycle pad, no side effects
    LDA #BAR0               ; 17-18
    STA COLUBK              ; 19-21 hit 22 (clock 66)
    NOP                     ; 22-23
    LDA #BAR1               ; 24-25
    STA COLUBK              ; 26-28 hit 29
    NOP
    LDA #BAR2               ; 31-32
    STA COLUBK              ; 33-35 hit 36
    NOP
    LDA #BAR3               ; 38-39
    STA COLUBK              ; 40-42 hit 43
    NOP
    LDA #BAR4               ; 45-46
    STA COLUBK              ; 47-49 hit 50
    NOP
    LDA #BAR5               ; 52-53
    STA COLUBK              ; 54-56 hit 57
    NOP
    LDA #BAR6               ; 59-60
    STA COLUBK              ; 61-63 hit 64
    NOP                     ; 64-65
    LDA #BAR7               ; 66-67
    STA COLUBK              ; 68-70 hit 71
    STA WSYNC               ; 71-73
    DEY
    BNE BarLoop
    ; the last line's WSYNC has ended at cycle 0; make the separator
    ; line black before the next band discards it
    LDA #$00
    STA COLUBK
    RTS

; =============================================================================
; FinalBars — the last band: Y bar lines, a black alignment line, then
; BodyEnd at cycle 0
; =============================================================================
; The first STA WSYNC discards the caller's partial line.  BIT+NOP puts
; the first body at cycle 5; the normal DEY/BNE loop keeps every later
; body at cycle 5.  After the last bar line, the routine clears COLUBK
; and spends one black alignment line with STA WSYNC — its last
; instruction — so BodyEnd starts at cycle 0 of the next scanline, the
; exact alignment the overscan label needs.
FinalBars:
    STA WSYNC               ; discard the caller's partial line
    BIT Frame               ; 0-2
    NOP                     ; 3-4
FinalLoop:
    LDA #BAR0               ; 5-6
    STA COLUBK              ; 7-9
    NOP
    NOP
    BIT Frame
    LDA #BAR0
    STA COLUBK              ; hit 22
    NOP
    LDA #BAR1
    STA COLUBK              ; hit 29
    NOP
    LDA #BAR2
    STA COLUBK              ; hit 36
    NOP
    LDA #BAR3
    STA COLUBK              ; hit 43
    NOP
    LDA #BAR4
    STA COLUBK              ; hit 50
    NOP
    LDA #BAR5
    STA COLUBK              ; hit 57
    NOP
    LDA #BAR6
    STA COLUBK              ; hit 64
    NOP
    LDA #BAR7
    STA COLUBK              ; hit 71
    STA WSYNC
    DEY
    BNE FinalLoop
    ; the black alignment line: the last instruction ends at cycle 0
    LDA #$00
    STA COLUBK
    STA WSYNC

; =============================================================================
; BODY END — the first line after the 192-line kernel
; =============================================================================
; NTSC: BodyEnd is 229/0; the LDA/BEQ pair puts OverscanStart at 229/6.
; PAL:  BodyEnd is 237/0; the 64-line lower border runs with VBLANK off,
;       then the last WSYNC and BIT/JMP put OverscanStart at 301/6.
BodyEnd:                    ; checkpoint: 229/0 (NTSC/PAL-60) or 237/0 (PAL)
    LDA TimingMode
    BEQ OverscanStart        ; 262-line timing: 0-2 + taken 3-5 -> cycle 6

    ; PAL: paint the 64-line lower border in black.  VBLANK is still off,
    ; so the TV sees the background colour; black makes it read as a
    ; normal PAL border.  The ball and playfield are cleared for the
    ; border (the last bar band left them on).
    LDA #$00
    STA COLUBK
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    LDA #PAL_BORDER_TIMER
    STA TIM64T

    ; The frame-counter text belongs to the next frame; the 64-line border
    ; leaves plenty of time to compose it here.
    LDA Screen
    BEQ PalNoFrameText
    JSR BuildFrame
PalNoFrameText:
PalBorderWait:
    LDA INTIM
    BNE PalBorderWait
    STA WSYNC                ; line 301, cycle 0
    BIT Frame                ; 0-2
    JMP OverscanStart        ; 3-5 -> the label is at cycle 6

; =============================================================================
; OVERSCAN — 30 lines (NTSC) or 8 lines (PAL), then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: 229/6 (NTSC/PAL-60), 301/6 (PAL)
    LDA #$02
    STA VBLANK
    LDA #$02
    STA ENABL               ; on both modes: restore the ball for the next
                            ; frame's top bands (the PAL border cleared it)
    LDX TimingMode
    LDA OverscanTimers,X
    STA TIM64T

    ; 262-line timing composes the frame-counter text here, in the
    ; 30-line overscan.  312-line PAL already did it in the border.
    LDA TimingMode
    BNE OverscanNoFrame
    LDA Screen
    BEQ OverscanNoFrame
    JSR BuildFrame
OverscanNoFrame:
    ; --- apply a pending mode at the frame boundary ----------------------
    ; The frame that handled the key press used the old timing from its
    ; first VBLANK line to its last border line.  The new mode starts with
    ; the next VSYNC, so no frame is ever half NTSC and half PAL.  The
    ; block runs before the final +wait_timer, so the timer's WSYNC and
    ; the JMP leave StartFrame at cycle 3 of the VSYNC line.
    LDA ModeDirty
    BEQ NoModeApply
    LDA PendingMode
    STA TVMode
    LDA #$00
    STA ModeDirty
    LDA #$01
    STA TextDirty
    JSR SetTiming            ; TimingMode and the 16-bit FrameLines
NoModeApply:
    +wait_timer
    JMP StartFrame

; =============================================================================
; SET BALL POSITION — the classic divide-by-15 routine for the ball
; =============================================================================
; Input: BarX (the left edge of the eight-pixel ball).  The +4 bias is
; the ball's output delay estimate; the HMOVE absorbs the remainder.
SetBallPos:
    LDA BarX
    CLC
    ADC #4
    STA WSYNC
    SEC
-   SBC #15
    BCS -
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMBL
    STA RESBL
    STA WSYNC
    STA HMOVE
    RTS

; =============================================================================
; TEXT BAND — two setup lines, eight glyph lines, one clear line = 11
; =============================================================================
; TextPtr points to a 24-byte buffer: eight PF0 rows, eight PF1 rows,
; eight PF2 rows.  The first STA WSYNC discards the caller's partial
; line.  The setup code is 85 cycles, so it overruns the next line and
; its own WSYNC lands on the line after: the band has TWO setup lines,
; not one.  The setup clears the playfield and loads row 0 while COLUPF
; is black, so both setup lines stay black.  The first glyph line turns
; COLUPF white; eight glyph lines (row 0 plus rows 1-7) follow.  The
; clear line blanks the playfield, restores the white ball, and ends with
; BIT so the next band starts at cycle 3.  Total: 2 + 8 + 1 = 11 lines.
; The first BlackLines line is the BodyStart line; each later band's
; leading WSYNC consumes the previous separator.  FinalBars ends with a
; black alignment line (the +1); the +5/+7 are the transitions between
; the bands (five for the six-band title/picture, seven for the timing).
TextBand:
    STA WSYNC                ; discard the caller's partial line
    LDA #$00
    STA ENABL
    STA COLUBK
    STA COLUPF
    STA PF0
    STA PF1
    STA PF2
    ; Dest1 = TextPtr + 8, Dest2 = TextPtr + 16
    LDA TextPtr
    CLC
    ADC #8
    STA Dest1
    LDA TextPtr+1
    ADC #0
    STA Dest1+1
    LDA TextPtr
    CLC
    ADC #16
    STA Dest2
    LDA TextPtr+1
    ADC #0
    STA Dest2+1
    ; row 0 into the playfield (invisible while COLUPF is black)
    LDY #0
    LDA (TextPtr),Y
    STA PF0
    LDA (Dest1),Y
    STA PF1
    LDA (Dest2),Y
    STA PF2
    STA WSYNC                ; the black setup line

    ; the first text line: the row-0 bytes are already loaded
    LDA #TEXT_COLOR
    STA COLUPF
    STA WSYNC

    ; rows 1-7: load the row at the start of the line, before the beam
    ; reaches the visible area (cycle 22)
    LDY #1
TextRowLoop:
    LDA (TextPtr),Y
    STA PF0
    LDA (Dest1),Y
    STA PF1
    LDA (Dest2),Y
    STA PF2
    STA WSYNC
    INY
    CPY #8
    BNE TextRowLoop

    ; the clear line: blank the playfield, restore the white ball
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA #TEXT_COLOR
    STA COLUPF
    LDA #$02
    STA ENABL
    STA WSYNC
    BIT Frame                ; the next band starts at cycle 3
    RTS

; =============================================================================
; BUILD THE STATIC TEXTS for the current screen and mode
; =============================================================================
BuildStaticTexts:
    LDA Screen
    CMP #SCREEN_PICTURE
    BEQ BuildPictureText
    CMP #SCREEN_TIMING
    BEQ BuildTimingText
    ; the title
BuildTitleText:
    LDA #<TextNtsc
    STA TextPtr
    LDA #>TextNtsc
    STA TextPtr+1
    LDA #<LabelBuf
    STA TextDest
    LDA #>LabelBuf
    STA TextDest+1
    JSR SetText
    LDA TVMode
    BNE NoNtscUnderline
    LDA #$0F                ; NTSC is four characters = 16 chunks
    JSR UnderlineText
NoNtscUnderline:
    LDA #<TextPal
    STA TextPtr
    LDA #>TextPal
    STA TextPtr+1
    LDA #<AltBuf
    STA TextDest
    LDA #>AltBuf
    STA TextDest+1
    JSR SetText
    LDA TVMode
    BEQ NoPalUnderline
    LDA #$00                ; PAL is three characters = 12 chunks
    JSR UnderlineText
NoPalUnderline:
    RTS

BuildPictureText:
    LDA TVMode
    BEQ PictureNtsc
    LDA #<TextPal
    BNE PictureSetText
PictureNtsc:
    LDA #<TextNtsc
PictureSetText:
    STA TextPtr
    LDA TVMode
    BEQ PicturePtrHiNtsc
    LDA #>TextPal
    BNE PicturePtrHi
PicturePtrHiNtsc:
    LDA #>TextNtsc
PicturePtrHi:
    STA TextPtr+1
    LDA #<LabelBuf
    STA TextDest
    LDA #>LabelBuf
    STA TextDest+1
    JSR SetText
    RTS

BuildTimingText:
    ; the line count: LN262 or LN312, from the timing mode (PAL-60 is
    ; 262 lines even though TVMode is PAL)
    LDA TimingMode
    BEQ TimingNtsc
    LDA #<TextLn312
    BNE TimingSetLn
TimingNtsc:
    LDA #<TextLn262
TimingSetLn:
    STA TextPtr
    LDA TimingMode
    BEQ TimingLnHiNtsc
    LDA #>TextLn312
    BNE TimingLnHi
TimingLnHiNtsc:
    LDA #>TextLn262
TimingLnHi:
    STA TextPtr+1
    LDA #<LabelBuf
    STA TextDest
    LDA #>LabelBuf
    STA TextDest+1
    JSR SetText

    ; the colour count: CL128 or CL104
    LDA TVMode
    BEQ TimingClNtsc
    LDA #<TextCl104
    BNE TimingSetCl
TimingClNtsc:
    LDA #<TextCl128
TimingSetCl:
    STA TextPtr
    LDA TVMode
    BEQ TimingClHiNtsc
    LDA #>TextCl104
    BNE TimingClHi
TimingClHiNtsc:
    LDA #>TextCl128
TimingClHi:
    STA TextPtr+1
    LDA #<AltBuf
    STA TextDest
    LDA #>AltBuf
    STA TextDest+1
    JSR SetText
    RTS

; =============================================================================
; BUILD THE FRAME COUNTER — "FRnnn" from Frame
; =============================================================================
BuildFrame:
    LDA Frame
    LDX #0
FrameHundredsLoop:
    CMP #100
    BCC FrameHundredsDone
    SBC #100
    INX
    BCS FrameHundredsLoop
FrameHundredsDone:
    STX FrameHundreds
    LDX #0
FrameTensLoop:
    CMP #10
    BCC FrameTensDone
    SBC #10
    INX
    BCS FrameTensLoop
FrameTensDone:
    STX FrameTens
    STA FrameOnes
    LDA #GLYPH_F
    STA TextChars+0
    LDA #GLYPH_R
    STA TextChars+1
    LDA FrameHundreds
    STA TextChars+2
    LDA FrameTens
    STA TextChars+3
    LDA FrameOnes
    STA TextChars+4
    LDA #<FrBuf
    STA TextDest
    LDA #>FrBuf
    STA TextDest+1
    JSR ComposeText
    RTS

; =============================================================================
; SET TEXT — copy five glyph codes, then compose them
; =============================================================================
SetText:
    LDY #0
-   LDA (TextPtr),Y
    STA TextChars,Y
    INY
    CPY #5
    BNE -
    JSR ComposeText
    RTS

; =============================================================================
; COMPOSE TEXT — five glyph codes -> 24 playfield bytes
; =============================================================================
; The buffer is column-major: eight PF0 rows at +0, eight PF1 rows at +8,
; eight PF2 rows at +16.  Playfield chunks 0-3 come from PF0 (bit 4 is
; the leftmost), 4-11 from PF1 (bit 7 leftmost), 12-19 from PF2 (bit 0
; leftmost).  The glyph rows use bit 3 as the leftmost column, so:
;   PF0 = Rev4[g0] << 4
;   PF1 = (g1 << 4) | g2
;   PF2 = Rev4[g3] | (Rev4[g4] << 4)
ComposeText:
    LDX TextChars+0
    LDA GlyphLo,X
    STA GlyphPtr0
    LDA GlyphHi,X
    STA GlyphPtr0+1
    LDX TextChars+1
    LDA GlyphLo,X
    STA GlyphPtr1
    LDA GlyphHi,X
    STA GlyphPtr1+1
    LDX TextChars+2
    LDA GlyphLo,X
    STA GlyphPtr2
    LDA GlyphHi,X
    STA GlyphPtr2+1
    LDX TextChars+3
    LDA GlyphLo,X
    STA GlyphPtr3
    LDA GlyphHi,X
    STA GlyphPtr3+1
    LDX TextChars+4
    LDA GlyphLo,X
    STA GlyphPtr4
    LDA GlyphHi,X
    STA GlyphPtr4+1
    ; Dest1 = TextDest + 8, Dest2 = TextDest + 16
    LDA TextDest
    CLC
    ADC #8
    STA Dest1
    LDA TextDest+1
    ADC #0
    STA Dest1+1
    LDA TextDest
    CLC
    ADC #16
    STA Dest2
    LDA TextDest+1
    ADC #0
    STA Dest2+1
    LDY #0
ComposeRow:
    LDA (GlyphPtr0),Y
    TAX
    LDA Rev4,X
    ASL
    ASL
    ASL
    ASL
    STA (TextDest),Y
    LDA (GlyphPtr1),Y
    ASL
    ASL
    ASL
    ASL
    STA Scratch
    LDA (GlyphPtr2),Y
    ORA Scratch
    STA (Dest1),Y
    LDA (GlyphPtr3),Y
    TAX
    LDA Rev4,X
    STA Scratch
    LDA (GlyphPtr4),Y
    TAX
    LDA Rev4,X
    ASL
    ASL
    ASL
    ASL
    ORA Scratch
    STA (Dest2),Y
    INY
    CPY #8
    BNE ComposeRow
    RTS

; =============================================================================
; UNDERLINE — set row 7 of the current TextDest buffer
; =============================================================================
; A = $0F for a four-character (16-chunk) word, $00 for three characters.
UnderlineText:
    STA Scratch
    LDY #7
    LDA #$FF
    STA (TextDest),Y
    LDY #15
    STA (TextDest),Y
    LDY #23
    LDA Scratch
    STA (TextDest),Y
    RTS

; =============================================================================
; SET TIMING — TVMode + the PAL60 flag -> TimingMode and FrameLines
; =============================================================================
; PAL60 = 1 keeps the PAL label and colour count (TVMode = 1) but forces
; the 262-line timing, so the frame runs at ~60 Hz on a PAL console.
; PAL60 = 0 (the lesson ROM) makes TimingMode follow TVMode.
SetTiming:
    LDA TVMode
    LDX #PAL60
    BEQ SetTimingStore       ; PAL60 = 0: keep TVMode
    LDA #0                   ; PAL60 = 1: force the 262-line timing
SetTimingStore:
    STA TimingMode
    TAX
    LDA LineLo,X
    STA FrameLinesLo
    LDA LineHi,X
    STA FrameLinesHi
    RTS

; =============================================================================
; THE TIMING TABLES
; =============================================================================
VblankTimers:
    !byte NTSC_VBLANK_TIMER, PAL_VBLANK_TIMER
OverscanTimers:
    !byte NTSC_OVERSCAN_TIMER, PAL_OVERSCAN_TIMER
LineLo:
    !byte <262, <312
LineHi:
    !byte >262, >312

; =============================================================================
; THE TEXT STRINGS — five glyph codes each
; =============================================================================
TextNtsc:
    !byte GLYPH_N, GLYPH_T, GLYPH_S, GLYPH_C, GLYPH_SPACE
TextPal:
    !byte GLYPH_P, GLYPH_A, GLYPH_L, GLYPH_SPACE, GLYPH_SPACE
TextLn262:
    !byte GLYPH_L, GLYPH_N, GLYPH_2, GLYPH_6, GLYPH_2
TextLn312:
    !byte GLYPH_L, GLYPH_N, GLYPH_3, GLYPH_1, GLYPH_2
TextCl128:
    !byte GLYPH_C, GLYPH_L, GLYPH_1, GLYPH_2, GLYPH_8
TextCl104:
    !byte GLYPH_C, GLYPH_L, GLYPH_1, GLYPH_0, GLYPH_4

; =============================================================================
; THE 4x7 GLYPH FONT — bit 3 is the leftmost column
; =============================================================================
; The eleventh entry is a space; the composer indexes GlyphLo/GlyphHi by
; the glyph code, so the table order must match the GLYPH_* constants.
GlyphTable:
Glyph0:
    !byte %0110, %1001, %1001, %1001, %1001, %1001, %0110, %0000
Glyph1:
    !byte %0010, %0110, %0010, %0010, %0010, %0010, %0111, %0000
Glyph2:
    !byte %0110, %1001, %0001, %0010, %0100, %1000, %1111, %0000
Glyph3:
    !byte %1110, %0001, %0001, %0110, %0001, %0001, %1110, %0000
Glyph4:
    !byte %0010, %0110, %1010, %1010, %1111, %0010, %0010, %0000
Glyph5:
    !byte %1111, %1000, %1000, %1110, %0001, %0001, %1110, %0000
Glyph6:
    !byte %0110, %1000, %1000, %1110, %1001, %1001, %0110, %0000
Glyph7:
    !byte %1111, %0001, %0010, %0010, %0100, %0100, %0100, %0000
Glyph8:
    !byte %0110, %1001, %1001, %0110, %1001, %1001, %0110, %0000
Glyph9:
    !byte %0110, %1001, %1001, %0111, %0001, %0001, %0110, %0000
GlyphF:
    !byte %1111, %1000, %1000, %1110, %1000, %1000, %1000, %0000
GlyphR:
    !byte %1110, %1001, %1001, %1110, %1010, %1001, %1001, %0000
GlyphN:
    !byte %1001, %1101, %1101, %1011, %1001, %1001, %1001, %0000
GlyphT:
    !byte %1111, %0010, %0010, %0010, %0010, %0010, %0010, %0000
GlyphS:
    !byte %0111, %1000, %1000, %0110, %0001, %0001, %1110, %0000
GlyphC:
    !byte %0111, %1000, %1000, %1000, %1000, %1000, %0111, %0000
GlyphP:
    !byte %1110, %1001, %1001, %1110, %1000, %1000, %1000, %0000
GlyphA:
    !byte %0110, %1001, %1001, %1111, %1001, %1001, %1001, %0000
GlyphL:
    !byte %1000, %1000, %1000, %1000, %1000, %1000, %1111, %0000
GlyphSpace:
    !byte %0000, %0000, %0000, %0000, %0000, %0000, %0000, %0000

GlyphLo:
    !byte <Glyph0, <Glyph1, <Glyph2, <Glyph3, <Glyph4
    !byte <Glyph5, <Glyph6, <Glyph7, <Glyph8, <Glyph9
    !byte <GlyphF, <GlyphR, <GlyphN, <GlyphT, <GlyphS
    !byte <GlyphC, <GlyphP, <GlyphA, <GlyphL, <GlyphSpace
GlyphHi:
    !byte >Glyph0, >Glyph1, >Glyph2, >Glyph3, >Glyph4
    !byte >Glyph5, >Glyph6, >Glyph7, >Glyph8, >Glyph9
    !byte >GlyphF, >GlyphR, >GlyphN, >GlyphT, >GlyphS
    !byte >GlyphC, >GlyphP, >GlyphA, >GlyphL, >GlyphSpace

; Reverse the four bits of a nibble: bit 3 <-> bit 0, bit 2 <-> bit 1.
Rev4:
    !byte 0, 8, 4, 12, 2, 10, 6, 14
    !byte 1, 9, 5, 13, 3, 11, 7, 15

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
> `lessons/part8-advanced/65-pal-ntsc-universal/65-pal-ntsc-universal.asm`.

### Code Walkthrough

#### Step 1 — Reset and the compile-time hooks

`+clean_start` zeroes the TIA and the 128 bytes of RIOT RAM and sets the stack. The reset code sets the two compile-time hooks the exercises use:

```asm
DEFAULT_TV = 0
PAL60      = 0
```

`DEFAULT_TV` is the mode at power-on; `PAL60` forces the 262-line timing while keeping `TVMode` (and therefore the label and colour count) at PAL. `SetTiming` turns those into `TimingMode` and the 16-bit `FrameLines`:

```asm
SetTiming:
    LDA TVMode
    LDX #PAL60
    BEQ SetTimingStore       ; PAL60 = 0: keep TVMode
    LDA #0                   ; PAL60 = 1: force the 262-line timing
SetTimingStore:
    STA TimingMode
    TAX
    LDA LineLo,X
    STA FrameLinesLo
    LDA LineHi,X
    STA FrameLinesHi
    RTS
```

The reset calls `SetTiming`, so the first VBLANK already has the right timer values and the first `TVModeRead`/`FrameLinesRead` pair is consistent. The TIA state is fixed: `COLUPF` is white (the text and the ball share it), `COLUBK` is black, `CTRLPF = $30` makes the ball eight pixels wide, and `ENABL = 2` turns it on.

#### Step 2 — VBLANK: the inputs, the edges, and the hand-off

VBLANK is where the frame's decisions are made. It starts with the timer for the **current** `TimingMode`, so the frame that handled a key press still has a complete old-mode VBLANK:

```asm
VblankStart:
    LDA #$02
    STA VBLANK
    LDX TimingMode
    LDA VblankTimers,X
    STA TIM64T
```

The input edges use the standard new-and-not-previous test:

```asm
    LDA SWCHA
    AND #$20
    EOR #$20
    STA Scratch              ; 1 while down is pressed
    AND PrevDown
    EOR Scratch
    BEQ NoDownEdge           ; no edge
    LDA #1
    STA PendingMode          ; down selects PAL
    LDA #1
    STA ModeDirty
```

Up selects NTSC, down selects PAL, fire starts the picture from the title, and `SELECT` toggles the timing page. The edges are only acted on once per press; `PrevUp`, `PrevDown`, `PrevFire` and `PrevSelect` store the level for the next frame. The static text buffers are rebuilt only when `TextDirty` is set, so the common frame does not pay for two text compositions. The ball moves one pixel per frame and is repositioned with one `HMOVE`. The VBLANK timer's `+wait_timer` anchors the body to the line boundary.

#### Step 3 — The two sets of timer values

The timer values are not the naive "one tick per line" numbers, because the `STA TIM64T` write happens after the mode lookup, not at the first cycle of the VBLANK line. The lesson uses:

| Period | NTSC | PAL |
|---|---:|---:|
| VBLANK | 44 ticks = 2,753 cycles | 53 ticks = 3,329 cycles |
| Border | — | 76 ticks = 4,801 cycles |
| Overscan | 36 ticks = 2,241 cycles | 9 ticks = 513 cycles |

The first decrement lands one cycle after the write, so `t` ticks cover `1 + (t-1) × 64` cycles. The NTSC 44 ticks expire during line 36 and the final `WSYNC` lands on line 37. The PAL 53 ticks expire during line 44 and the `WSYNC` lands on line 45; 54 ticks would expire too late for the final `WSYNC` to land on line 45, because the timer starts at cycle 15–20. The PAL border 76 ticks expire during line 300 and the `WSYNC` lands on line 301. The PAL overscan 9 ticks expire during line 308 and the `WSYNC` lands on line 309. The exact numbers are in the source header and are confirmed by `BodyStart` 37/5 or 45/5 and `OverscanStart` 229/6 or 301/6.

::: tip The timer values are a measurement, not a formula
The "obvious" PAL values are 54/10 because 45 lines × 76 cycles and 8 lines × 76 cycles look like 54 and 10 ticks. They are one tick too many in this build because the timer starts at cycle 15–20, after the mode lookup. The lesson measured the actual lines and adjusted the values. This is the cycle-counting discipline from Lesson 17 applied to a real frame: count the store cycle, not the macro name.
:::

#### Step 4 — The visible kernel: bands and the 192-line ledger

`BodyStart` is at 37/5 or 45/5. It draws one of three screens:

- **Title**: 8 black + 48 bars + 11 label + 16 bars + 11 label + 92 final + 1 + 5 = 192.
- **Picture**: 8 black + 16 bars + 11 label + 126 bars + 11 frame + 14 final + 1 + 5 = 192.
- **Timing**: 8 black + 40 bars + 11 line + 24 bars + 11 frame + 24 bars + 11 colour + 55 final + 1 + 7 = 192.

`BlackLines` is entered on the `BodyStart` line; each later band starts with a `STA WSYNC` that consumes the previous separator. The final `FinalBars` black alignment line is the `+1`; the `+5`/`+7` are the transitions between the bands (five for the six-band title/picture, seven for the eight-band timing). The bar body starts at cycle 5 and its eight stores hit 22, 29, 36, 43, 50, 57, 64 and 71. `FinalBars` is the last band. It uses the usual `DEY/BNE` loop for its N bar lines and then a black alignment line whose last instruction is `STA WSYNC`; the next instruction is `BodyEnd` at cycle 0. The NTSC `BodyEnd` is 229/0; the `LDA TimingMode` and `BEQ OverscanStart` pair takes six cycles, putting `OverscanStart` at 229/6. The PAL `BodyEnd` is 237/0; the PAL path falls through to the 64-line border, and the final `STA WSYNC` / `BIT` / `JMP` puts `OverscanStart` at 301/6.

The text band is the only non-obvious band. It is 11 lines: **2 setup + 8 glyph + 1 clear**.

1. **Setup lines (2)**: the leading `STA WSYNC` discards the caller's partial line; the 85-cycle setup then overruns the next line, so its own `STA WSYNC` lands on the following line. The setup clears `ENABL`, `COLUBK`, `COLUPF` and the playfield and loads row 0 while `COLUPF` is black, so both setup lines stay black.
2. **Glyph lines (8)**: set `COLUPF` white for row 0, then load rows 1–7 into the three playfield bytes in HBLANK; eight glyph lines in all.
3. **Clear line (1)**: blank the playfield, restore the white ball, `STA WSYNC`, then `BIT Frame` so the next band starts at cycle 3.

The title underlines the selected word in row 7 of its buffer. The picture and timing screens use the same routine; only the buffer and the string differ.

#### Step 5 — The PAL 64-line lower border

The PAL path is a separate branch after the visible kernel:

```asm
BodyEnd:
    LDA TimingMode
    BEQ OverscanStart
    ; PAL: paint the 64-line lower border in black.  VBLANK is still off,
    ; so the TV sees the background colour; black makes it read as a
    ; normal PAL border.  The ball and playfield are cleared for the
    ; border (the last bar band left them on).
    LDA #$00
    STA COLUBK
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    LDA #PAL_BORDER_TIMER
    STA TIM64T

    ; The frame-counter text belongs to the next frame; the 64-line border
    ; leaves plenty of time to compose it here.
    LDA Screen
    BEQ PalNoFrameText
    JSR BuildFrame
PalNoFrameText:
PalBorderWait:
    LDA INTIM
    BNE PalBorderWait
    STA WSYNC
    BIT Frame
    JMP OverscanStart
```

This is the real code: the PAL path falls through from the `BEQ` (the NTSC path branches to `OverscanStart`), and the `BuildFrame` call is part of the border wait. The 64 lines are painted black with VBLANK off; the TV sees the background colour, which is black, so the border looks like a normal PAL border. `BodyEnd` is at 237/0; the `LDA TimingMode`/`BEQ` branch and the five clearing stores complete the `STA TIM64T` at about cycle 27 of line 237. The 76 ticks expire during line 300, the `STA WSYNC` lands on line 301, the `BIT` takes three cycles, and the `JMP` puts `OverscanStart` at 301/6. The 8-line overscan that follows is blanked by VBLANK; the 30-line NTSC overscan does the same with `OverscanTimers[0] = 36`. The frame is 312 lines on PAL and 262 on NTSC. The border clears `ENABL`; the overscan restores it after `STA VBLANK`, so the next frame's top bands keep the moving bar.

#### Step 6 — The text composer

The composer is the largest routine in the lesson, and it is mostly table lookup. The five glyph codes are turned into five pointers with `GlyphLo`/`GlyphHi`; the destination pointer is split into `Dest1 = TextDest + 8` and `Dest2 = TextDest + 16`; then one row loop writes the three playfield bytes:

```asm
    LDA (GlyphPtr0),Y
    TAX
    LDA Rev4,X
    ASL
    ASL
    ASL
    ASL
    STA (TextDest),Y
    LDA (GlyphPtr1),Y
    ASL
    ASL
    ASL
    ASL
    STA Scratch
    LDA (GlyphPtr2),Y
    ORA Scratch
    STA (Dest1),Y
    LDA (GlyphPtr3),Y
    TAX
    LDA Rev4,X
    STA Scratch
    LDA (GlyphPtr4),Y
    TAX
    LDA Rev4,X
    ASL
    ASL
    ASL
    ASL
    ORA Scratch
    STA (Dest2),Y
```

The reverse table is 16 bytes:

```asm
Rev4:
    !byte 0, 8, 4, 12, 2, 10, 6, 14
    !byte 1, 9, 5, 13, 3, 11, 7, 15
```

The four-bit glyph rows use bit 3 as the leftmost column. The `Rev4[g0] << 4` form puts the first character at PF0 bits 4–7; `(g1 << 4) | g2` puts the next two at PF1 bits 7–0; `Rev4[g3] | (Rev4[g4] << 4)` puts the last two at PF2 bits 0–7. The asymmetry is the TIA's, not the composer's.

The frame counter is built in the overscan (NTSC) or the 64-line border (PAL) for the **next** frame. `BuildFrame` turns `Frame` into three decimal digits and composes `FRnnn` into `FrBuf`. The display therefore lags the internal counter by one frame; the counter still advances every frame, and the checkpoint `FrameRead` reports the internal value. The timing page uses the same `FrBuf` plus the static `LN262`/`LN312` and `CL128`/`CL104` buffers.

#### Step 7 — Reading it back: the checkpoints

The source places every checkpoint label immediately before the instruction that follows the labelled event, so the debugger reports the first cycle of that instruction. The frame labels are the contract:

| Checkpoint | Address | NTSC | PAL | Meaning |
|---|---|---|---|---|
| `StartFrame` | `$F05C` | 259/3 | 309/3 | the first VSYNC instruction |
| `VblankStart` | `$F06A` | 0/5 | 0/5 | the first VBLANK instruction |
| `BodyStart` | `$F153` | 37/5 | 45/5 | the first visible line |
| `BodyEnd` | `$F27A` | 229/0 | 237/0 | the line after the 192-line kernel |
| `OverscanStart` | `$F2A2` | 229/6 | 301/6 | the first overscan instruction |
| `TVModeRead` | `$F078` | A=0 | A=1 | the active timing mode |
| `FrameLinesRead` | `$F07B` | A=`$06` | A=`$38` | the low byte of `$0106`/`$0138` |
| `FrameLinesHiRead` | `$F07E` | A=`$01` | A=`$01` | the high byte |
| `FrameRead` | `$F12C` | A=1,2,3… | A=1,2,3… | the free-running counter |
| `ModeWrite` (up) | `$F098` | A=0 | — | the pending mode after an up edge |
| `ModeWriteDown` | `$F0B6` | — | A=1 | the pending mode after a down edge |
| `ScreenWriteFire` | `$F0D9` | A=1 | A=1 | fire starts the picture |
| `ScreenWrite` (SELECT) | `$F123` | A=2 | A=2 | SELECT opens the timing page |

The `BodyEnd` line is reported by the debugger as the preceding `STA WSYNC` at 228/12 or 236/12; the first instruction after the `WSYNC` runs at 229/0 or 237/0, which is the value in the table. The state-log excerpt below shows the raw debugger lines and explains the one-frame difference.

## What You Should See

The **title selector** is a colour-bar field with two black text bands. The first band says **NTSC**, the second says **PAL**; because `CTRLPF` repeats the 20-chunk playfield half, each word appears twice, once in each half. The selected word has a white underline in row 7 of its band; at power-on the underline is under **NTSC**, because the default is NTSC. The moving white ball crosses the bars; it is disabled on the text rows, so the words stay clean. Up/down moves the underline (up = NTSC, down = PAL), and fire starts the picture. On a PAL TV the default 262-line title may roll before the selection; that is the honest default, not a bug. The selector capture below is the power-on state.

![Stella running the Lesson 65 ROM at the title selector: a colour-bar field with the words NTSC and PAL in black bands, each word repeated in the right half, the NTSC word underlined, and the white moving bar crossing the bars; the title bar reads Stella 7.0: "65-pal-ntsc-universal"](/images/lesson65/selector.png)

*`selector.png`: the title selector at power-on, captured from the committed ROM in Stella 7.0 (NTSC format). The default is NTSC; the underline is under **NTSC**. The pointer was parked outside the window and no cursor is visible.*

The **picture screen** is the same colour-bar test with the selected label and a frame counter. On NTSC the eight bars are light grey, gold, orange, peach, red, pink, blue and green; on PAL the same bytes become light grey, grey-yellow, yellow, green-yellow, brown, mint, magenta and purple. The word at the top says **NTSC** or **PAL** (repeated in the right half); the frame counter at the bottom says **FRnnn**. The moving ball crosses the bars and the black bands, but not the text rows; the overscan restores `ENABL` after the PAL border clears it, so the next frame's top bands also show the bar. The PAL capture shows the **64-line black lower border** below the 192-line picture; the 8-line blanked overscan after it is invisible in a still, and the state log proves the 312-line split (`OverscanStart` 301/6). The capture below is the PAL picture after the held down+fire selection.

![Stella running the Lesson 65 ROM in PAL mode: the PAL palette's colour bars, the word PAL at the top (repeated in the right half), the FR frame counter at the bottom, the moving white bar, and the 64-line black PAL lower border; the title bar reads Stella 7.0: "65-pal-ntsc-universal"](/images/lesson65/pal.png)

*`pal.png`: the PAL picture, captured from the committed ROM in Stella 7.0 with `-format PAL` and down+fire held from power-on. The power-on partial frame is the default NTSC timing; the pending mode applies at the frame boundary and the first full frame is PAL. The PAL palette paints the same eight bar bytes differently from the NTSC capture.*

<RomPlayer rom="/roms/part8-advanced/65-pal-ntsc-universal/65-pal-ntsc-universal.bin" title="Lesson 65 — PAL/NTSC Universal ROM" />

The in-page player starts muted; the ROM is silent. The demo is interactive in Stella: up/down selects, fire starts, and `SELECT` opens the timing page. The timing page shows three black bands with `LN262` or `LN312`, `FRnnn`, and `CL128` or `CL104`. The labels are 4×7 playfield glyphs, so they look blocky; that is the native resolution of the playfield text, not a rendering bug.

The debugger writes the same story as numbers. The frame checkpoints, first hits:

```text
# NTSC, no input
StartFrame    259/3
VblankStart     0/5
BodyStart      37/5
OverscanStart 229/6

# PAL, -format PAL -holdjoy0 'D,F'
StartFrame    309/3   (steady; the power-on partial frame is not a full frame)
VblankStart     0/5
BodyStart      37/5   (press frame)
BodyStart      45/5   (from the next frame)
OverscanStart 229/6   (press frame)
OverscanStart 301/6   (from the next frame)
```

The mode and line-count checkpoints:

```text
# NTSC
TVModeRead      A=00
FrameLinesRead  A=06   (262 = $0106)
FrameLinesHiRead A=01
FrameRead       A=01, 02, 03, ...

# PAL, -format PAL -holdjoy0 'D,F'
TVModeRead      A=00   (frame 0: the down+fire frame)
TVModeRead      A=01   (frame 1 onward)
FrameLinesRead  A=38   (312 = $0138)
FrameLinesHiRead A=01
FrameRead       A=01, 02, 03, ...
```

The selector edges:

```text
# -holdjoy0 U (up edge)
ModeWrite       A=00   (up selects NTSC)
# -holdjoy0 D (down edge)
ModeWriteDown   A=01   (down selects PAL)
# -holdjoy0 F (fire edge)
ScreenWriteFire A=01   (fire starts the picture)
# -holdselect (SELECT edge)
ScreenWrite     A=02   (the timing page)
```

The PAL frame is the point of the lesson. The power-on partial frame is the default NTSC timing; the pending mode is applied at its end, and the first full frame is PAL. The mode and the two body/overscan labels move together:

```text
# PAL transition (same -holdjoy0 'D,F' run)
TVModeRead     A=00 -> A=01
BodyStart      37/5 ->  45/5
OverscanStart 229/6 -> 301/6
StartFrame    309/3   (steady PAL)
```

The passive NTSC run gives the 259/3 `StartFrame` and 262-line frame; the PAL steady run gives 309/3 and 312. The power-on partial frame is not a full 262-line frame, so it is not used as a `StartFrame` row in this table.

`TVModeRead` is 0 on the frame of the press and 1 from the next frame. This is the frame-boundary hand-off: the old frame is complete, the new frame is complete, and no frame is half NTSC and half PAL.

The raw debugger lines for the frame labels, first hits:

```text
# NTSC StartFrame
BP:           2 259 03 -59 | nv-BdIZC 00 00 00 ff |
BP:           3 259 03 -59 | ...
# NTSC VblankStart
BP:           2   0 05 -53 | nv-BdIZC 00 00 08 ff |
# NTSC BodyStart
BP:           2  37 05 -53 | nv-BdIZC 00 00 08 ff |
# NTSC OverscanStart
BP:           2 229 06 -50 | nv-BdIZC 00 00 00 ff |

# PAL StartFrame (steady, after the hand-off)
BP:           3 309 03 -59 | nv-BdIZC 00 01 08 ff |
# PAL BodyStart
BP:           2  37 05 -53 | nv-BdIZC 00 00 08 ff |
BP:           3  45 05 -53 | nv-BdIZC 00 00 08 ff |
# PAL OverscanStart
BP:           2 229 06 -50 | nv-BdIZC 00 00 00 ff |
BP:           3 301 06 -50 | nv-BdIZC 00 00 08 ff |
```

The `BodyEnd` label is one instruction after a `STA WSYNC`, so the debugger reports the `WSYNC` at 228/12 (NTSC) or 236/12 (PAL); the next instruction runs at 229/0 or 237/0. The `OverscanStart` labels are the authoritative lines: 229 and 301.

### Capture method

Both images are window captures of the **committed** ROM in Stella 7.0. The selector used the default NTSC format and no input; `pal.png` used `-format PAL -holdjoy0 'D,F'`. Stella 7's console-format switch is `-format PAL`; the older `-pal` option is not the format switch. The pointer was parked outside the window with `xdotool mousemove 0 0` before the capture, and `import -window` captures the window contents, so no cursor or hover artifact is present. The title bar reads `Stella 7.0: "65-pal-ntsc-universal"`; the window title is part of the published image. The first PAL frame is the default NTSC picture because the mode is applied at the frame boundary; the still is the steady PAL picture. No game pixel was altered.

The pixel check: the selector has two black text bands (the words and the underline), the eight bars, and the white ball; `pal.png` has the PAL palette's bars, the `PAL` label, the `FR` counter, the white ball, and the 64-line black lower border. The frame labels and the state logs are the proof of the 262/312 split; the stills prove the visual state.

## Exercises

### Exercise 1: Default PAL with a compile-time flag

**Challenge:** Make the ROM start in PAL instead of NTSC without changing the selector. Set a compile-time flag `DEFAULT_TV = 1`; the title underline must be under PAL at power-on, the first frame must be 312 lines, and up/down must still let a user switch to NTSC. Keep the ROM at 4,096 bytes.

**Hints:**
1. The reset already reads `DEFAULT_TV` into `TVMode` and `PendingMode`; change the constant from 0 to 1. Do not hard-code a separate `STA TVMode` path.
2. `SetTiming` derives `TimingMode` and `FrameLines` from `TVMode`; with `DEFAULT_TV = 1` and `PAL60 = 0` the first frame uses the PAL timer values (53/9) and `FrameLines = $0138`.
3. Run the result with `-format PAL`; the selector underline is under **PAL**, `StartFrame` is 309/3, `BodyStart` is 45/5, and `OverscanStart` is 301/6. The `ModeWrite` up edge still sets `PendingMode = 0`, and the frame switches to 262 on the next frame.

**Expected Result:** The power-on title is 312 lines, the underline is under PAL, and the state log shows `TVMode` A=1 and `FrameLines` A=$38/$01. Pressing up changes the pending mode to 0; the next frame is NTSC (259/37/229) and the underline moves to NTSC. The ROM is 4,096 bytes.

**Solution:** See `exercise-01-solution.asm`.

The program body is unchanged. The file adds an exercise header and sets the compile-time constant `DEFAULT_TV = 1`; the state log for the default build:

```text
TVModeRead      A=01
FrameLinesRead  A=38
FrameLinesHiRead A=01
StartFrame    309/3
VblankStart     0/5
BodyStart      45/5
OverscanStart 301/6
```

### Exercise 2: PAL-60 — 262 lines on a PAL console

**Challenge:** Build a PAL-60 ROM: the label and colour count say PAL, but the frame is 262 lines at about 60 Hz. Set `DEFAULT_TV = 1` and `PAL60 = 1`. The title must use the 262-line timing (not the 312-line PAL timing), the picture must use the PAL palette, and the timing page must show `LN262` and `CL104`. A PAL set that accepts PAL-60 will lock; one that does not will object. Keep the ROM at 4,096 bytes.

**Hints:**
1. `SetTiming` is the switch: with `PAL60 = 1` it forces `TimingMode = 0` while `TVMode` stays 1. The VBLANK/overscan timer tables and the border branch all use `TimingMode`; the label and the colour count use `TVMode`.
2. `FrameLines` follows `TimingMode`, so `FrameLinesRead` is `$06` (262), not `$38`. The `TVMode` checkpoint is still 1.
3. Run it on a PAL console: `stella -format PAL ...`. The palette is PAL, the frame is 262 lines, and `StartFrame` is 259/3. The 262-line frame is not a PAL standard; many PAL TVs accept it, some do not.

**Expected Result:** `TVMode` A=1, `FrameLines` A=$06/$01, `StartFrame` 259/3, `BodyStart` 37/5, `OverscanStart` 229/6. The timing page reads `LN262` and `CL104`; the bars use the PAL palette. A PAL set that accepts PAL-60 sees a stable 60 Hz picture; the ROM does not claim that every PAL set does.

**Solution:** See `exercise-02-solution.asm`.

The solution sets `DEFAULT_TV = 1` and `PAL60 = 1`. The state log:

```text
TVModeRead      A=01   (PAL label and palette)
FrameLinesRead  A=06   (262 = $0106, the PAL-60 timing)
FrameLinesHiRead A=01
StartFrame    259/3
VblankStart     0/5
BodyStart      37/5
OverscanStart 229/6
```

### Exercise 3: A colour-bar test for both palettes

**Challenge:** Replace the picture screen with a palette test: 16 rows of 8 large colour swatches, 12 scanlines per row, showing the 128 TIA colour values `$00, $02, ... $FE`. The title selector still chooses NTSC or PAL, so the same ROM can be run on both console types; the frame timing changes with the mode and the console's own palette paints the grid. Keep the ROM at 4,096 bytes.

**Hints:**
1. The colour table is 128 bytes: 16 rows of 8 even values `$00`–`$FE`. The grid reads `SwatchTable+0..7,X` with X up to 120, so the last read is byte 127; a 64-byte table would read into the timing tables and glyph data. A line body of eight `LDA table+n,X` / `STA COLUBK` pairs is 56 cycles; with the loop overhead it fits in 76 cycles if the first store lands around cycle 15.
2. The table must not cross a page boundary for the `abs,X` loads to stay at four cycles. Page-align it with `!align 255, 0`; otherwise the rows whose `X` crosses the page take five cycles per load and every second line stretches to two scanlines.
3. The screen is one continuous 192-line loop. `LineRow` is a 191-entry table (12 lines per row for rows 0–14, 11 for the last row) plus a black top separator; a one-line-per-row transition would make the frame longer than 262/312. The first iteration gets a `BIT`+`NOP` pad so its body starts at cycle 11 like the loop's later iterations; the eight stores hit 18, 25, 32, 39, 46, 53, 60 and 67. The first store's boundary is in HBLANK; the first visible swatch is 7 clocks wide (68–75), and the rest are 21. The last line ends with a `JMP BodyEnd`; the exercise's NTSC `OverscanStart` is 229/15 rather than the lesson's 229/6 because the `JMP` starts at cycle 6. The exercise therefore uses 35 NTSC overscan ticks instead of 36; the frame is still 262 lines and `StartFrame` is 259/3.

**Expected Result:** The picture is a 16×8 grid of colour swatches from the 128-byte table (16 rows of 8 even values). On NTSC the same grid uses the NTSC palette; on PAL it uses the PAL palette, and some of the 128 values are not distinct. `TVMode` is 0 or 1, `BodyStart` is 37/5 or 45/5, and `OverscanStart` is 229/15 or 301/6; `StartFrame` is 259/3 or 309/3. The ROM is 4,096 bytes.

**Solution:** See `exercise-03-solution.asm`.

The solution keeps the title selector, replaces the picture/timing screens with the palette screen, and adds the 128-byte `SwatchTable` and the 191-byte `LineRow` table. The palette grid's swatches are 7 cycles wide; the black top separator and the final row make the grid 192 lines. The exercise's NTSC overscan cycle differs from the lesson because the continuous loop ends with a `JMP`; the line count and the frame length are unchanged.

## Key Takeaways

- ✅ **NTSC is 262 lines (3 + 37 + 192 + 30); PAL is 312 (3 + 45 + 192 + 64 lower border + 8 overscan).** The visible kernel is 192 lines in both; only the blank padding changes.
- ✅ **A stock 2600 cannot auto-detect the TV system.** The RIOT timer and the TIA share the CPU clock, and the ~0.9% crystal difference has no independent timebase to compare against.
- ✅ **A custom Harmony/Melody firmware could measure the console; the shipped menu is region-specific, and the Color/BW switch is a manual selector.** This lesson uses a title-screen selector and says so.
- ✅ **Apply the pending mode at the frame boundary.** `TVMode` is stable for a whole frame; `TimingMode` and the 16-bit `FrameLines` change together, so no frame is half NTSC and half PAL.
- ✅ **`FrameLines` is 16-bit: `$0106` or `$0138`.** A holds the low byte (`$06` or `$38`); the high byte is `$01` in both modes.
- ✅ **The palettes are 128 and 104 colours.** The same colour byte can look different; the colour-bar test shows the mapping approximately, and PAL-60 uses the PAL palette with a 262-line frame.
- ✅ **The RIOT timer values are measured, not guessed.** The start cycle after the mode lookup matters; 53/9 and 76 produce the exact 45/301/309 lines, while the naive 54/10 would add a line.

## What's Next

The next part leaves the bare-metal 6507 and looks at a higher-level way to write 2600 code: [Lesson 66: Analyzing batari BASIC — How bB Works](/part9-dsl-path/66-analyzing-batari-basic) opens up batari BASIC, the compiler that turns a BASIC-like language into a 2600 kernel and a 4K ROM. The frame and timing vocabulary from this lesson — 262/312, VBLANK, overscan, `WSYNC` — is exactly what the generated kernels are built from.
