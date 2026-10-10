---
title: "Lesson 12: The NTSC Frame — 262 Scanlines of Precision"
description: "What a television picture really is: a beam, a color clock, and the 262-line NTSC frame — VSYNC (3 lines), VBLANK (37), the visible 192, and overscan (30) — built by hand with STA WSYNC as the line ruler, four equal 48-line bands as the proof, and the ~59.9 Hz frame rate derived from the numbers."
prev:
  text: "Lesson 11: Lookup Tables"
  link: "/part1-6502-cpu/11-lookup-tables"
next:
  text: "Lesson 13: Colors"
  link: "/part2-tv-and-tia/13-colors"
---

# Lesson 12: The NTSC Frame — 262 Scanlines of Precision

> **Part 2: TV & TIA** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 04 (the frame skeleton and `+clean_start`), Lesson 07 (counted loops), Lesson 08 (subroutines and the `PaintLines` register contract), Lesson 11 (indexed table reads — the exercises use them)
> **You will learn:** what an NTSC television picture actually is — a beam, a color clock, and 262 scanlines of timing; the four phases of the frame (VSYNC, VBLANK, the visible area, overscan) and what each one is for; `STA WSYNC` as the line ruler — one write, one scanline; why a frame is 3 + 37 + 192 + 30 lines at 76 CPU cycles per line; and how to write that frame by hand, with no frame macros doing the work
> **You will build:** the "frame anatomy" ROM — the 262-line frame written out line by line, showing four equal 48-line bands (`$42` red, `$84` blue, `$C8` green, `$1A` gold) — plus three exercises: the same bands colored from RAM, a 48/96/48 repartition, and a sixteen-band proof that the visible budget really is 192 lines

## Introduction

Every program you have written since Lesson 04 has run inside the same frame skeleton. `+vsync`, `+set_timer`, `+wait_timer` — three macros that come back every frame, doing something important that the lessons so far never had to explain. A picture appeared, band after band, and the television tolerated it. This lesson opens that box. What *is* a television picture, and why does displaying one require code that runs on a schedule?

The surprising answer is that the 2600 has no frame buffer and no "display" step at all. A television picture is a single point of light — the electron beam — sweeping across the screen, line by line, about sixty times a second. The TIA generates the video signal as the beam moves; there is nothing anywhere that stores a screen. A "picture" is therefore a piece of *timing*: you must supply the right color at the right moment, again and again, for 262 lines, forever. If your code is late by a few dozen cycles, the beam has moved on and the line shows something else.

The companion program `12-the-ntsc-frame.asm` writes the canonical NTSC frame out by hand — no frame macros — so that every phase of it is visible in the source. It draws four equal bands of 48 lines, red over blue over green over gold, and each color change falls on an exact scanline boundary. On screen the bands look almost too simple; in the debugger they are a ruler, because the four checkpoints in the program report scanlines that advance by exactly 3, 37, 192 and 30 — the frame's four phases, measured by a TV once per frame.

::: details TypeScript Equivalent
If you have drawn to a canvas, the shape of the loop below will look familiar — and every part of its promise is different:

```typescript
while (true) {
  vsync(3);      // tell the TV "a new frame starts now"
  blank(37);     // no picture — in a game, logic runs here
  draw(192);     // the picture: you ARE the renderer, in real time
  blank(30);     // let the TV settle before the next frame
}
```

On the web, `draw(192)` fills a buffer and something else presents it later; if your code takes 20 ms instead of 16, the browser may still show the frame. Here there is no buffer and no later: `draw(192)` must take exactly as long as the TV's beam takes to sweep 192 lines — the duration is not a performance target, it *is* the picture. And "drawing" means setting a color as the beam passes each line, not composing a scene: there is no canvas to inspect afterwards, only the signal you produced while the beam moved.
:::

## Theory

### Section 1: The Picture Is Made While It Is Shown

A CRT television paints its picture with a narrow electron beam that sweeps left to right along one horizontal line, then jumps back and sweeps the next line just below it, then — after the bottom — returns to the top and starts again. The beam's intensity is the brightness you see. Nothing is stored on the screen: the phosphor glows briefly and fades, so the sweep must repeat fast enough that your eye sees a steady picture. ~60 sweeps per second is fast enough.

The TIA does not read out a bitmap; it *is* the signal generator. It keeps the horizontal and vertical sync timing, and it samples a handful of registers — `COLUBK` for the background color, in this lesson — again and again as the beam moves. One picture element is one **color clock**:

| Clock | NTSC rate | What it is |
|---|---|---|
| Color clock | 3.579545 MHz | One pixel of picture |
| CPU "machine clock" | 1.193182 MHz | The 6507's clock — exactly the color clock divided by 3 |

So a scanline is a fixed piece of time with two parts:

| Phase of one scanline | Color clocks | CPU cycles | What happens |
|---|---|---|---|
| Horizontal blank (HBLANK) | 68 | ~22.7 | The beam is off-screen, returning to the left; the TIA's sync pulses |
| Visible picture | 160 | ~53.3 | The beam is moving across the screen — this becomes visible pixels |
| **Total** | **228** | **76** | One scanline |

**One scanline is exactly 76 CPU cycles.** That number is the whole rhythm of 2600 programming: every line, the CPU has 76 cycles' worth of time before the beam has finished that line and moves to the next. Code that takes longer than the line stretches the frame — the picture rolls or tears.

::: tip Why HBLANK matters before you've written a single pixel
The first ~23 CPU cycles of every scanline happen while the beam is *off-screen*. Writes you make there take effect before the visible portion starts — which is how a color change lands exactly on a line boundary instead of halfway across it. The kernel below uses that window deliberately.
:::

### Section 2: The Vertical Frame — Four Phases, 262 Lines

The same structure repeats vertically. A television frame is not just "192 lines of picture"; it is four phases, and the TV needs all of them:

| Phase | NTSC lines | What it is for |
|---|---|---|
| **VSYNC** | 3 | The "new frame starts now" pulse the TV locks onto |
| **VBLANK** | 37 | Blanked lines — the beam is returning to the top; no picture |
| **Visible picture** | 192 | The lines you actually see |
| **Overscan** | 30 | Blanked lines — the beam swings back toward the start |
| **Frame total** | **262** | At ~60 frames per second |

This course's numbers are **NTSC**, the North American standard: 262 lines, ~60 Hz. (PAL televisions run 312 lines at ~50 Hz, which is why a fixed 262-line ROM rolls on PAL hardware — the totals do not match. This course is NTSC throughout.) Of the 262 lines, only 192 can show your colors; the rest exist so the beam can get back to the top of the screen and so the TV can re-synchronize. In a real game, VBLANK and overscan are where the logic runs: read the joystick, move objects, decide what the next frame looks like. They are not wasted time — they are the 2600's "outside the frame" window.

**VSYNC must be exactly 3 lines.** Not 2, not 4: real televisions can lose color lock if the pulse is the wrong length. This is one of the few places where the hardware leaves no room for taste.

### Section 3: `WSYNC` — the Line Ruler

If the frame is a schedule, you need a clock to keep it. The 2600 gives you one instruction for the job:

```asm
STA WSYNC    ; write any value: halt the CPU until the scanline ends
```

Writing to `WSYNC` pauses the CPU until the current scanline reaches its end (HBLANK of the next line, concretely: the CPU resumes at the start of the *next* scanline). The write itself costs 3 cycles; whatever is left of the line is spent waiting. That single behavior gives you two things:

1. **A ruler.** Each `STA WSYNC` consumes exactly one scanline. To wait 37 blanked lines, write it 37 times. To draw 192 lines, write it once per line. Count the writes; you have counted the frame.
2. **A phase boundary.** Code that runs right after a `WSYNC` is running in the new line's HBLANK — the safe window. A color written there applies to the whole line, so changes land on exact scanline boundaries.

This is exactly what the frame macros have been doing since Lesson 04. Here is the mapping:

| Macro you have used | What it actually does | How this lesson writes it |
|---|---|---|
| `+vsync` | VSYNC on, 3 x `STA WSYNC`, VSYNC off | the six-line VSYNC block below |
| `+set_timer 43` / `+wait_timer` | Wait out VBLANK — with the RIOT timer counting cycles | a counted loop of 37 `STA WSYNC`s |
| `+set_timer 35` / `+wait_timer` | Wait out overscan | a counted loop of 30 `STA WSYNC`s |

The macros measure those two blanked periods with the RIOT timer, which frees the CPU to do game logic while it waits. Counting lines with `WSYNC` is the more literal ruler — and it costs nothing but patience. Both produce the same 262-line frame; this lesson's version is the one you can read.

::: details TypeScript Equivalent
Every browser game knows a loop shaped like this — but the mechanism is inverted:

```typescript
// TypeScript: you register a callback and the platform calls you back once per frame.
requestAnimationFrame(function frame(now) {
  update(); draw(); requestAnimationFrame(frame);
});

// 6502: there is no callback and no platform to call you — you ARE the loop.
//   await line() means: block until the beam finishes this line.
//   Using it 262 times defines one frame; using it 191 times inside the
//   picture section defines the picture's height.
```

The analogy breaks where the deadlines live. In TypeScript the frame duration is something that *happens to you*; here the frame duration is something you *write* — a count of waits — and if you write the wrong count, the television will show it instantly.
:::

### Section 4: Where the Numbers Come From

None of the numbers so far are invented; they all follow from the clocks. Three steps, all arithmetic:

1. **One line = 228 color clocks** (the TIA's horizontal design).
2. **One CPU cycle = 3 color clocks**, so one line = **76 CPU cycles** — the per-line budget.
3. **The frame = 3 + 37 + 192 + 30 = 262 lines.**

Multiply it out and the frame rate falls out on its own:

```text
line budget per frame (NTSC)
  VSYNC      3 lines x 228 clocks =   684 color clocks
  VBLANK    37 lines x 228 clocks =  8436 color clocks
  visible  192 lines x 228 clocks = 43776 color clocks
  overscan  30 lines x 228 clocks =  6840 color clocks
  -------------------------------------------------------
  frame    262 lines x 228 clocks = 59736 color clocks

59736 clocks / 3,579,545 Hz = 0.01669 s  ->  ~59.9 frames per second
```

So "60 Hz" is a convenient alias for **~59.9 Hz** on the TIA — the frame rate follows from the numbers the frame is built from: 262 lines x 228 color clocks, divided by the color clock's 3,579,545 Hz. Add an extra line anywhere and the rate sags below 59.9; count 262 correctly and 59.9 is what a television measures.

Nothing in the television is counting these lines with you — it just expects the next VSYNC pulse when the frame is due. That is why a frame is a promise you keep every 262 lines, and why exceeding 76 cycles on any line makes the promise late: the picture rolls, tears, or loses color.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson12.bin \
  lessons/part2-tv-and-tia/12-the-ntsc-frame/12-the-ntsc-frame.asm
stella build/lesson12.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`, all in the same directory.

### Full Source

The program is one frame loop with four counted phases — VSYNC, VBLANK, the visible bands, overscan — and a single subroutine that paints lines. There are no RAM variables at all: the frame is stateless, and the picture is made entirely of waits.

```asm
; =============================================================================
; LESSON 12: The NTSC Frame — 262 Scanlines of Precision
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   Draws the canonical NTSC frame EXPLICITLY, line by line, with no frame
;   macros — so every phase of a television frame is visible in the source:
;
;     VSYNC   3 lines    tell the TV "a new frame starts now"
;     VBLANK  37 lines   blanked — the picture is suppressed
;     visible 192 lines  four equal bands of 48: $42 $84 $C8 $1A
;     overscan 30 lines  blanked again
;     -----------------
;     total   262 lines  one TV frame at ~60 Hz
;
;   There is nothing to "draw" into: the 2600 has no frame buffer.  Every
;   line of the picture is produced by waiting the right amount of time.
;   The ruler is STA WSYNC — it halts the CPU until the current scanline
;   ends — so each write costs exactly one line.  Count them: 3 + 37 + 192
;   + 30 = 262 writes of WSYNC per pass of the frame loop, and the loop
;   runs once per frame.  That is the whole trick, and it is stable.
;
;   The visible area is four bands of 48 lines: red $42, blue $84, green
;   $C8, gold $1A, top to bottom.  Band 0's color is written into COLUBK in
;   HBLANK right after VBLANK is cleared, so the beam-release line is the
;   top band's FIRST line — that is what makes "four equal 48-line bands"
;   literally true.  Every other line is one WSYNC plus one COLUBK write.
;
; What you'll learn:
;   - The vertical structure of an NTSC frame and what each phase is for
;   - Why VSYNC must be exactly 3 lines; what VBLANK and overscan are
;   - STA WSYNC as the line ruler: one write = one scanline of waiting
;   - A frame written out by hand — the same frame +vsync / +set_timer /
;     +wait_timer have been building since Lesson 04, opened up
;   - Where the numbers come from: 228 color clocks = 76 CPU cycles per
;     line; 3 + 37 + 192 + 30 = 262 lines; 262 x 228 clocks gives ~59.9 Hz
;
; Frame geometry: the release line is counted inside band 0's 48 lines, and
;   the frame loop waits out exactly 262 scanlines per pass (3 + 37 + 191
;   + 1 + 30 counted waits: band 0 paints its release line without a wait,
;   the post-visible WSYNC lets the last band line finish).
;
; Build: acme -f plain -o build/lesson12.bin \
;        lessons/part2-tv-and-tia/12-the-ntsc-frame/12-the-ntsc-frame.asm
; Run:   stella build/lesson12.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; only +clean_start is used this time ---
; The frame itself is written out below, so the frame macros have nothing
; left to do here — comparing it against them is half the point (see the
; walkthrough in docs/part2-tv-and-tia/12-the-ntsc-frame.md).
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the phase lengths, summing to 262
; =============================================================================
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
BANDS          = 4      ; visible bands, top to bottom
LINES          = 48     ; scanlines per band (4 x 48 = 192 visible lines)
OVERSCAN_LINES = 30     ; blanked lines after the picture
                        ;   (VSYNC is the three STA WSYNCs below — there is no
                        ;    number to name because the code IS the count)

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
; The frame is four counted waits.  Each phase begins on the FIRST line it
; describes, and the four checkpoints below mark those lines for the
; debugger: break at each label and read the scanline it reports — the
; values advance 3, 37, 192, 30, and then wrap back to the start every
; frame (the loop waits out exactly 262 lines).  Stella numbers the
; frame from the VSYNC-off boundary, so the four values read 259, 0,
; 37 and 229 — the differences are the phase lengths.
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines
; -----------------------------------------------------------------------------
; VSYNC is the "new frame starts here" pulse the TV locks onto.  Three lines
; is not a style choice: two or four can make real televisions lose color.
    LDA #$02                ; bit 1 = start VSYNC
    STA VSYNC               ; pulse on — the 3 VSYNC lines begin here
    STA WSYNC               ; VSYNC line 1 ends
    STA WSYNC               ; VSYNC line 2 ends
    STA WSYNC               ; VSYNC line 3 ends
    LDA #$00
    STA VSYNC               ; pulse off — VSYNC covered exactly 3 lines

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 blanked lines
; -----------------------------------------------------------------------------
; VBLANK suppresses the picture while the TV's beam re-traces to the top of
; the screen.  On a game this is where the logic runs; here it is a counted
; wait, one STA WSYNC per line.  (+set_timer / +wait_timer measure this same
; period with the RIOT timer — the reader has used them since Lesson 04.)
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDX #VBLANK_LINES       ; 37 lines to wait out
VblankLines:
    STA WSYNC               ; wait out one blanked line
    DEX
    BNE VblankLines

VisibleStart:               ; debugger checkpoint: visible's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — 192 lines = four equal bands of 48
; -----------------------------------------------------------------------------
; Releasing VBLANK turns the beam loose.  The release line belongs to band
; 0, so band 0's color goes into COLUBK first — written in HBLANK, before
; the visible portion of the line starts — and the loop settles into one
; color write per line.
    LDA #$00
    STA VBLANK              ; release the beam — this line is visible line 1
    LDA BandColors          ; band 0's color: $42 (red)
    STA COLUBK              ; lands in HBLANK: the release line shows $42
    LDY #LINES-1            ; Y = 47: release line + 47 painted = band 0's 48
    JSR PaintLines          ; paint them — A survives, X is never touched
    LDX #$01                ; bands 1...3 remain
BandLoop:
    LDA BandColors,X        ; this band's color, out of the table
    LDY #LINES              ; a full band of 48
    JSR PaintLines
    INX                     ; next band
    CPX #BANDS              ; 1, 2, 3 — stop after the bottom band
    BNE BandLoop

    STA WSYNC               ; let the last band line finish before blanking:
                            ; the beam is still drawing it, so blanking now
                            ; would clip it partway across
    LDA #$02
OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
    STA VBLANK              ; blank the screen for overscan
    LDX #OVERSCAN_LINES     ; 30 lines to wait out
OverscanLines:
    STA WSYNC               ; wait out one blanked line
    DEX
    BNE OverscanLines

    JMP StartFrame          ; 3 + 37 + 192 + 30 = 262 lines done: next frame

; =============================================================================
; SUBROUTINE: PaintLines — paint Y scanlines with the color in A
; =============================================================================
; How to call:   A = color byte, Y = scanline count, then JSR PaintLines
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for Y lines.  Writing the color
;                right after the WSYNC puts the change in the first few
;                cycles of the line — while the beam is still in HBLANK —
;                so band boundaries fall exactly on a scanline instead of
;                showing a notch where a new color arrives mid-line.
; Registers:     A survives (still the color) and X is never touched — the
;                band index lives in X, so the kernel depends on that — and
;                Y is used up: the line counter counts it down to 0.
; Stack:         JSR pushed the return address; the RTS pops it.  Nothing
;                else is pushed inside, so callers can use the stack freely.
; =============================================================================
PaintLines:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEY                     ; one line fewer to go
    BNE -                   ; loop until the line counter reaches 0
    RTS                     ; return; the return address comes off the stack

; =============================================================================
; DATA — the four band colors, read as BandColors,X
; =============================================================================
; One byte per band, top to bottom.  The bytes ARE the picture: there is no
; computation anywhere in this program that turns one value into another.
BandColors:
    !byte $42               ; band 0 (top)    — red
    !byte $84               ; band 1          — blue
    !byte $C8               ; band 2          — green
    !byte $1A               ; band 3 (bottom) — gold

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

> The complete, fully-commented source lives in
> `lessons/part2-tv-and-tia/12-the-ntsc-frame/12-the-ntsc-frame.asm`.

### Code Walkthrough

#### Step 1 — The phases as constants

```asm
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
BANDS          = 4      ; visible bands, top to bottom
LINES          = 48     ; scanlines per band (4 x 48 = 192 visible lines)
OVERSCAN_LINES = 30     ; blanked lines after the picture
```

The four phase lengths are named constants, and that is the first lesson of the frame: **the frame is a count**, not a picture. VSYNC has no constant because the code below *is* the count — three explicit `STA WSYNC`s, exactly as many as the hardware demands.

#### Step 2 — VSYNC: exactly three lines

```asm
    LDA #$02                ; bit 1 = start VSYNC
    STA VSYNC               ; pulse on — the 3 VSYNC lines begin here
    STA WSYNC               ; VSYNC line 1 ends
    STA WSYNC               ; VSYNC line 2 ends
    STA WSYNC               ; VSYNC line 3 ends
    LDA #$00
    STA VSYNC               ; pulse off — VSYNC covered exactly 3 lines
```

VSYNC is a pulse on the video signal, and the TV uses its leading edge to know a new frame has begun. You turn it on (bit 1 of `VSYNC`), wait out three scanlines, and turn it off. This is `+vsync` with the macro expansion removed — the same three `STA WSYNC`s the macro has been emitting since Lesson 04. Compare this against `include/macro.asm` when you get the chance; it is a good habit, because the macros in this course are all meant to be openable boxes.

#### Step 3 — VBLANK: a counted loop

```asm
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDX #VBLANK_LINES       ; 37 lines to wait out
VblankLines:
    STA WSYNC               ; wait out one blanked line
    DEX
    BNE VblankLines
```

Setting `VBLANK`'s bit 1 suppresses the picture — the beam is off-screen anyway while it returns to the top, and blanking is what guarantees a clean black border. The wait is Lesson 07's count-down loop with `STA WSYNC` as the body: 37 writes, 37 lines, no arithmetic that can drift. (A real game would replace this wait with controller reads and object updates while the timer counts — that swap is Part 2's story, one lesson at a time.)

#### Step 4 — The visible area: release the beam, then four bands of 48

```asm
    LDA #$00
    STA VBLANK              ; release the beam — this line is visible line 1
    LDA BandColors          ; band 0's color: $42 (red)
    STA COLUBK              ; lands in HBLANK: the release line shows $42
    LDY #LINES-1            ; Y = 47: release line + 47 painted = band 0's 48
    JSR PaintLines          ; paint them — A survives, X is never touched
```

Two details make this exact, and both are worth memorizing:

- **The release line counts inside band 0.** Clearing `VBLANK` releases the beam for the line that is *currently* being drawn — so that line is visible, and it belongs to the top band. Band 0's color must already be in `COLUBK` when the release happens, which is why it is stored immediately after clearing, still inside the line's HBLANK: the release line then shows `$42` from its first visible pixel to its last.
- **`LINES-1`, not `LINES`.** Because the release line already consumed one of band 0's 48, the painter only draws 47 more. That off-by-one is the difference between "four equal 48-line bands" being true and being almost true.

The remaining bands are a loop straight out of Lesson 11:

```asm
    LDX #$01                ; bands 1...3 remain
BandLoop:
    LDA BandColors,X        ; this band's color, out of the table
    LDY #LINES              ; a full band of 48
    JSR PaintLines
    INX                     ; next band
    CPX #BANDS              ; 1, 2, 3 — stop after the bottom band
    BNE BandLoop
```

X is the band number *and* the table index — the same single-index trick as the color wave — and `PaintLines` is careful never to touch X, which is what lets the index survive the call.

#### Step 5 — Overscan, the last line, and closing the loop

```asm
    STA WSYNC               ; let the last band line finish before blanking
    LDA #$02
OverscanStart:              ; debugger checkpoint: overscan's first line
    STA VBLANK              ; blank the screen for overscan
    LDX #OVERSCAN_LINES     ; 30 lines to wait out
OverscanLines:
    STA WSYNC
    DEX
    BNE OverscanLines

    JMP StartFrame          ; 3 + 37 + 192 + 30 = 262 lines done: next frame
```

That lone `STA WSYNC` before the blanking is the kind of detail that separates a clean frame from a torn one. When the bottom band's painter returns, the beam is still drawing its last line — the CPU is *somewhere inside* the picture's final scanline (frame scanline 228, visible line 192). Writing `VBLANK` right there would blank part of that line. Waiting for the line to finish first (one more `WSYNC`) moves the blanking to the next line, where it belongs.

Now count the waits in one pass of the loop exactly as the CPU experiences them:

```text
VSYNC .......... 3     (the three STA WSYNCs)
VBLANK ......... 37    (the counted loop)
band 0 ......... 47    (release line painted without a wait)
bands 1-3 ...... 144   (3 x 48)
post-visible ... 1     (let the last line finish)
overscan ....... 30    (the counted loop)
---------------------
total .......... 262 waits = 262 scanlines
```

Three plus thirty-seven plus 191 plus one plus thirty — 262. The loop *is* the frame. That arithmetic is this lesson's cycle ledger: every claim on this page is a row in it.

#### Step 6 — The painter: why the color write goes after the WSYNC

```asm
PaintLines:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEY                     ; one line fewer to go
    BNE -
    RTS
```

The subroutine could have written `COLUBK` once and then counted lines — but it writes the color once *per line*, right after each `WSYNC`, and that is deliberate: each write lands in the new line's HBLANK, before the visible portion starts, so every one of the 48 line boundaries falls exactly where it should. A single write before the loop would work for a solid band; as soon as a band boundary or a mid-picture change is involved, per-line writes are what keep edges crisp. The contract (A survives, X untouched, Y used up) is the same shape as Lesson 08's `PaintBand` — the course keeps its register promises consistent so kernels compose.

## What You Should See

Four bands, all the same height, filling the picture window: red on top, then blue, then green, then gold at the bottom. The borders above and below are black — that is VBLANK and overscan, which Stella renders as blanked black just like a television would. Nothing moves, nothing flickers: the same frame, all 262 lines of it, every sixtieth of a second.

![Stella running the Lesson 12 ROM: four equal horizontal bands — red, blue, green, gold, top to bottom — inside a black frame border, with Stella's window title showing 12-the-ntsc-frame](/images/lesson12/frame-anatomy.png)

<RomPlayer rom="/roms/part2-tv-and-tia/12-the-ntsc-frame/12-the-ntsc-frame.bin" title="Lesson 12 — The NTSC Frame" />

Open the debugger (`stella -debug`, then `Tab` or the *Debugger* menu) and treat the four checkpoints as a ruler. Each label marks the **first line** of one phase, and the scanline each breakpoint reports tells you the frame's shape directly:

| Checkpoint | Address in the shipped ROM | Scanline reported | Phase it opens | Lines in that phase |
|---|---|---|---|---|
| `StartFrame` | `$F00E` | 259 (every frame) | VSYNC | 3 (259, 260, 261) |
| `VblankStart` | `$F01C` | 0 (next frame) | VBLANK | 37 (0–36) |
| `VisibleStart` | `$F027` | 37 | Visible picture | 192 (37–228) |
| `OverscanStart` | `$F048` | 229 | Overscan | 30 (229–258) |

Read down the column: 259 → 0 → 37 → 229 → 259. The distances are 3, 37, 192 and 30 lines — the frame's four phases, measured from the TV itself. (Stella's frame counter happens to start at the VSYNC-off boundary, which is why `VblankStart` reads scanline 0 rather than 262 — the deltas are what matter, and they are exact.)

You can read the same numbers without ever opening a window — this is the course's state-log method, first used in Part 1 for cycle evidence:

```bash
# assemble with a symbol list to get the checkpoint addresses
acme -f plain -l build/lesson12.sym -o build/lesson12.bin \
  lessons/part2-tv-and-tia/12-the-ntsc-frame/12-the-ntsc-frame.asm
grep StartFrame build/lesson12.sym

# then log the breakpoint hits (one address per run)
stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F00E' \
  docs/public/roms/part2-tv-and-tia/12-the-ntsc-frame/12-the-ntsc-frame.bin
```

Each hit prints a line like `BP:  1  259  33 ...` — frame 1, scanline 259 — and a few seconds of run give you dozens of frames proving the loop-top scanline never varies. That constancy *is* a stable picture: the same count, every frame, forever.

A few more things to check while the debugger is open:

- **`COLUBK` in the TIA view** — the `VisibleStart` breakpoint fires *before* the release-line write, so it still holds the previous frame's bottom color (`$1A`; `$00` on the very first frame, before any band has been painted); step past the `STA COLUBK` and it reads `$42`. Break inside the band loop and you see it change four times a frame: `$42`, `$84`, `$C8`, `$1A`.
- **The registers at each checkpoint** — at `VblankStart`, A = `$00` (just loaded to switch VSYNC off) and X = `$00` in steady state (the previous frame's overscan count-down ended there; the very first pass shows X = `$FF`, left over from startup); at `VisibleStart`, A = `$02` and X = `$00` (the VBLANK count-down finished); at `OverscanStart`, X = `$04` (the band loop exited after the fourth band). The register file is part of the frame's state.
- **RAM** — there is none. Edit `$80–$FD` and nothing changes: this frame is stateless. (The top of RAM, `$FE–$FF`, is where the call stack lives — `JSR` pushes there, mirroring page `$01`; leave those bytes alone.) Exercise 1 is about changing that.

## Exercises

### Exercise 1: Four Bands from RAM

**Challenge:** keep the picture and the frame exactly as they are, but move the four band colors into RAM — four bytes written once at startup and read by the kernel every frame.

**Hints:**
1. The colors start life in the cartridge and end up at four consecutive bytes of RIOT RAM (`$80–$83`); a small count-down loop (X = 3, 2, 1, 0) does the copying once, in `Reset`.
2. The kernel's reads change shape with the data's home: `LDA BandColors` (absolute, 4 cycles) becomes a zero-page read (`LDA $80`, 3 cycles) — one cycle saved — while the indexed read becomes `LDA $80,X` and stays at 4 cycles (zero-page indexed reads cost the same as absolute indexed ones). The saving is one cycle per frame, not per band; the point of the move is that the colors are now data the program can edit.
3. Run it, open the debugger's memory view, and edit `$80–$83`: change `$42` to `$E8` and the top band takes on a different color on the next frame. That live edit is the point of the exercise.

**Expected Result:** the lesson's four equal 48-line bands, same colors, same steady frame — now driven entirely by RAM; editing any of the four bytes in the debugger recolors its band on the next frame.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: 48 / 96 / 48

**Challenge:** re-partition the visible area. Keep the frame and the first three colors, but make the bands 48, 96 and 48 lines tall instead of four equal 48s.

**Hints:**
1. The release line still belongs to the top band, so the top band is 48 lines of red with a painter call of 47 (the `LINES-1` shape from the lesson).
2. `PaintLines` does not care how big the band is: a single call with Y = 96 paints a double-height blue band.
3. Verify the totals rather than assuming them: 47 + 96 + 48 painted lines, plus the release line, is 192. The frame around it never changes.

**Expected Result:** three bands — red 48 lines, blue 96 lines, green 48 lines — filling the same 192-line picture window. The band boundaries fall at visible lines 1, 49 and 145 — frame scanlines 37, 85 and 181 (the `MiddleBand` and `BottomBand` checkpoints fire one line earlier, on the last line of the band above).

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The 192-Line Budget, Proved *(Stretch Goal)*

**Challenge:** prove that the visible area is exactly 192 lines by partitioning it entirely differently: sixteen equal 12-line bands, each with a color from a 16-byte table — a completely different picture that must fit the same window.

**Hints:**
1. Band 0 keeps the release line and its 11 painted companions; bands 1–15 are fifteen calls of 12 lines. Count it: 11 + 15 x 12 = 191, plus the release line = 192.
2. The table is read as `Ladder,X` with X = 0…15 — Lesson 11's idiom — and since the index only counts up, the loop's `CPX #16` comparison is the bounds discipline (no mask needed).
3. `!align 15, 0, 0` before the table keeps every fetch inside one page, so each read costs exactly 4 cycles.

**Expected Result:** sixteen equal 12-line bands — the 16 hues at one brightness, gray at the top through the color wheel to the bottom — occupying exactly the same 192-line window as the lesson ROM. In the debugger, break at `BandFetch` and watch A walk `$1C, … $FC` while X counts `1…15` — `$0C`, band 0's entry, is loaded once before the loop.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **The picture is timing, not memory** — the 2600 has no frame buffer; the TIA generates the video signal while the beam moves, and your code must keep the schedule
- ✅ **One scanline is exactly 228 color clocks = 76 CPU cycles** — the CPU's whole time budget for a line; exceed it and the frame stretches, rolls, or tears
- ✅ **The NTSC frame is four phases: 3 + 37 + 192 + 30 = 262 lines** — VSYNC (exactly 3!), VBLANK, the visible picture, and overscan; only the middle 192 can show color
- ✅ **`STA WSYNC` is the line ruler** — one write waits out exactly one scanline, so counting writes counts lines: 262 writes per frame, every frame
- ✅ **Writes right after `WSYNC` land in HBLANK** — before the visible portion starts, which is how color changes fall on exact line boundaries instead of tearing mid-scanline
- ✅ **The release line counts inside the top band** — clear `VBLANK`, store the color immediately (it lands in HBLANK), and the first visible line is already band 0's first line
- ✅ **The frame macros are exactly this code** — `+vsync` is the three-line pulse; `+set_timer`/`+wait_timer` measure the blanking periods with the RIOT timer. You have been writing this frame since Lesson 04; now it is yours

## What's Next

The picture is under control — but the colors so far have been taken on faith: `$42` is "red", `$84` is "blue", and the exercises' tables use them as if that were obvious. [Lesson 13: Colors](/part2-tv-and-tia/13-colors) opens the palette: what those hex bytes actually encode, why 128 colors come from one byte, what luminance does to a hue, and how to build color charts of your own.
