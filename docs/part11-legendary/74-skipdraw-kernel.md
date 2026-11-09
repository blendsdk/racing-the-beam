---
title: "Lesson 74: Skipdraw — The Classic Sprite Kernel Idiom"
description: "Draw a 16-row sprite in a one-line kernel with one branch and one unconditional store: the unsigned carry test skips the graphic load above and below the sprite, the missile gets a branchless carry form, and the 192-line schedule fits 24 star lines, 144 flight lines and 24 ground lines into 262."
prev:
  text: "Lesson 73: The HMOVE Comb & the Cosmic Ark Starfield"
  link: "/part11-legendary/73-cosmic-ark-starfield"
next:
  text: "Lesson 75: Pseudo-3D Road — The Enduro / Pole Position Effect"
  link: "/part11-legendary/75-pseudo-3d-road"
---

# Lesson 74: Skipdraw — The Classic Sprite Kernel Idiom

> **Part 11: Legendary Techniques** · Estimated time: 120 minutes
> **Prerequisites:** Lesson 12 (the NTSC frame), Lesson 14 (WSYNC and scanline timing), Lesson 17 (cycle counting and page-cross costs), Lesson 25 (player sprites), Lesson 26 (horizontal positioning, RESP and HMOVE), Lesson 29 (missiles and the ball), Lesson 48 (introduction to kernels), Lesson 49 (the 2-line kernel), Lesson 53 (kernel design patterns)
> **You will learn:** how the carry from an unsigned subtraction becomes a "line is outside the sprite" test; why the store to `GRP0` stays unconditional and how one branch covers both edges of a sprite; how to make both paths of the branch cost exactly 25 cycles and why the graphic table must be page-aligned; how the missile's enable is computed without any branch at all; how a one-line kernel is scheduled as three bands inside 192 lines and 76 cycles per line; and where the idiom comes from.
> **You will build:** "the elevator" — a 4,096-byte ROM with a gold 8×16 rocket, a 2×8 exhaust, a 24-line star band, a 144-line flight region, and a 24-line ground band. The rocket rises and falls on a 64-entry auto-demo table; SELECT restarts it. Plus two complete exercise solutions: a second skipdraw sprite with its own Y, and the fully branchless player built from a 256-byte row table.

## Introduction

Lessons 48 to 53 built kernels one band at a time, and Lesson 49's two-line kernel showed the comfortable default: one graphic byte per two scanlines, plenty of cycles left for the playfield and the game logic. A **one-line kernel** is the other end of the scale. Every scanline reads its own byte, so an 8×16 sprite needs sixteen writes to `GRP0`, one per line — and on the other 176 lines of the screen the kernel must make the sprite disappear.

The obvious way is a compare and a branch: if the line is inside the sprite, load the row and store it; otherwise store zero. That works, but it costs a branch on every line and the two paths take different times. **Skipdraw** is the classic answer: subtract the sprite's Y from the line counter, let the carry tell you whether the line is outside the sprite's window, and keep the store **unconditional**. On a skipped line the store writes a zero that is already sitting in Y; on a drawn line it writes the row. One branch, one store, and — with a little padding — the same number of cycles on both paths.

This lesson builds the idiom into a small vertical scene. Player 0 is an 8×16 rocket at `RocketY`; missile 0 is its 2×8 exhaust at `RocketY + 16`, drawn with the branchless carry form. The playfield provides three bands: a 24-line star band, a 144-line flight region, and a 24-line ground band. A 64-entry demo table raises and lowers the rocket, so the screen is alive without a controller. The companion program `74-skipdraw-kernel.asm` makes the mechanism visible: the rocket appears only on its sixteen rows, the exhaust only on its eight, and everything above and below is the blank the unconditional store writes.

::: details TypeScript Equivalent

The natural model is a per-line window and a row lookup:

```typescript
const ROCKET: number[] = [/* 16 bytes, one per row */];
const ROCKET_Y = 64;

/** One scanline: fill the playfield row and the two object latches. */
function drawLine(line: number, out: number[]): void {
  const row = line - ROCKET_Y;
  // The skipdraw, written the way a TypeScript programmer would:
  out[line]        = row >= 0 && row < ROCKET.length ? ROCKET[row] : 0;
  // The missile: the same window, eight rows tall.
  const jet = line - (ROCKET_Y + 16);
  out[line + 192]  = jet >= 0 && jet < 8 ? 2 : 0;
}
```

The analogy breaks in four places. There is no framebuffer: `out[line]` is not memory the TV reads later; it is a TIA latch the CPU writes *during* the line, and the sprite's eight pixels appear only if the object's position counter says so. The comparison is signed in TypeScript; the 6502's subtraction is modulo 256 and its carry is an **unsigned** "no borrow" flag — the wrapped negative value is what makes one compare cover both edges. The `if` costs nothing in TypeScript; on the 2600 a branch is two cycles, three when taken, and the store has a deadline measured in color clocks. And `drawLine` can take as long as it likes; the real kernel has 76 CPU cycles per line, and the sprite's store must land before the beam reaches its X position.

:::

## Theory

### The problem: a sprite that appears only on its rows

The TIA has no vertical position register for the players. A player's vertical position is simply **when** you write `GRP0`: the register holds the eight pixels that the beam will draw when it reaches the player's horizontal position. Write the same byte on every line and you get a vertical bar. Write a different byte per line and you get a picture. Write zero on every line outside the picture and you get a sprite.

So a one-line sprite kernel looks like this:

```
for each visible line X:
    if X is inside the sprite's rows:
        Y = X - SpriteY
        GRP0 = Graphic[Y]
    else:
        GRP0 = 0
    wait for the next line
```

The first version anyone writes is a compare and a branch:

```asm
    TXA                     ; A = the line
    CMP RocketY
    BCC .blank              ; above the sprite
    SBC #ROCKET_HEIGHT       ; hmm: this subtracts the height, not the Y
```

That second line is already wrong, and the reason is worth understanding. After `CMP RocketY`, the carry tells you whether the line is at or below `RocketY`, but the accumulator no longer holds the difference — `CMP` throws the result away. You need the difference for the row index, so you need a real subtraction, and a real subtraction needs a known carry:

```asm
    TXA
    SEC
    SBC RocketY             ; A = X - RocketY
    CMP #ROCKET_HEIGHT      ; A < 16 ?
    BCS .blank
```

Now there are two branches to think about (one for "above", one for "below"), and the row index only exists on the drawn path. Skipdraw folds both edges into one unsigned compare and keeps a single store.

### The carry is the unsigned "before the sprite" test

Here is the whole rocket block:

```asm
    LDY #0
    TXA
    SEC
    SBC RocketY
    CMP #ROCKET_HEIGHT
    BCC .draw
    <padding>
    JMP .store
.draw:
    TAY
    LDA RocketGfx,Y
    TAY
.store:
    STY GRP0
```

`SBC` is a subtraction with borrow: it computes `A - M - (1 - C)`. With `SEC` first, the borrow is zero, so `A = X - RocketY` modulo 256. The subtraction is **unsigned**: the 6502 has no idea that `X < RocketY` should be negative, so the result wraps to a large value. Then `CMP #16` subtracts 16 and sets the carry when `A >= 16`. The three cases are:

| Line | `X - RocketY` (8-bit) | `CMP #16` carry | Branch | `GRP0` |
|---|---|---|---|---|
| above the sprite | `X < RocketY`, so the result wraps to 112..255 | 1 (set) | not taken | 0 |
| inside the sprite | 0..15 | 0 (clear) | taken | `RocketGfx[row]` |
| below the sprite | 16..159 | 1 (set) | not taken | 0 |

The **carry is the unsigned "outside the sprite" test**, and the wrap is what makes it cover the "above" edge as well as the "below" edge. This is the sense in which the carry is a "before the sprite" test: a line before the sprite produces a negative difference, the negative difference becomes a large unsigned one, and the same `CMP` that rejects the lines below the sprite rejects the lines above it too.

The wrap cannot fake a row. `RocketY` never exceeds 144 in this ROM, so a wrapped difference is at least `256 - 144 = 112`, and a difference below the sprite is at least 16. Only the sixteen values 0..15 can reach the draw path. If `RocketY` could be larger than 240 the argument would need rechecking; the course's sprites live in 0..191, so it is safe.

::: tip Why the store stays unconditional

The skip path still executes `STY GRP0`. That looks wasteful — it stores a value that is already zero — but it is the idiom's core. `Y` was set to 0 at the top of the block and the skip path never changes it, so `STY GRP0` writes a blank line. On the draw path `Y` is the row and the same instruction writes the picture. **One branch, one store, one instruction responsible for the sprite's whole vertical shape.** The moment you make the store conditional you pay a second branch on every line, and the skipdraw's budget advantage disappears.

:::

### Making both paths cost 25 cycles

The skip path is naturally shorter than the draw path: it does not execute `TAY`, `LDA RocketGfx,Y` and `TAY` (8 cycles), and its branch is not taken (one cycle less). The difference is 9 cycles. If a second object shares the line, that jitter changes when the next store happens, and a tight line can grow or clip. The lesson pins both paths to the same count with padding on the skip path:

| | Draw path | Skip path |
|---|---|---|
| `LDY #0` | 2 | 2 |
| `TXA` | 2 | 2 |
| `SEC` | 2 | 2 |
| `SBC RocketY` (zero page) | 3 | 3 |
| `CMP #16` | 2 | 2 |
| `BCC .draw` | 3 (taken) | 2 (not taken) |
| `TAY` | 2 | — |
| `LDA RocketGfx,Y` (page-aligned) | 4 | — |
| `TAY` | 2 | — |
| padding | — | 3 × `NOP` = 6 |
| `JMP .store` | — | 3 |
| `STY GRP0` | 3 | 3 |
| **total** | **25** | **25** |

The draw path's extra is the taken-branch penalty (1) plus `TAY`/`LDA`/`TAY` (8), i.e. 9 cycles. The skip path's extra is the three `NOP`s (6) plus the `JMP` (3), also 9. Both paths are 25 cycles, and the store completes by cycle 25.

Two details make the ledger true on hardware:

- **`LDA RocketGfx,Y` must not cross a page.** An absolute-indexed load costs 4 cycles when the index stays inside the table's page and 5 when it crosses. `RocketGfx` is therefore page-aligned with `!align 255, 0`, and `Y` runs 0..15, so the load is always 4. Without the alignment the draw path would sometimes be 26 and the equality would be a lie.
- **The branch must not cross a page.** A taken branch that crosses a page boundary costs one extra cycle. `BCC .draw` jumps six bytes forward and both instructions sit in the same page, so the taken cost is exactly 3.

The block's 25 cycles include the store. The ledger counts from cycle 0, the first instruction after the `WSYNC` release: `STY GRP0` starts at cycle 22 and completes at 25 (the breakpoint at the store fires at 61/22 on the first flight line, a skip line; the first drawn row fires at 69/22). The rocket's left edge is X=76, and pixel X is drawn at CPU cycle `22.67 + X/3` (the visible area starts at cycle 22.67). X=76 is drawn at cycle 48.0, so the store has 23 cycles of margin. That margin is why the store can be the last instruction of the block and still be early.

::: tip What happens without the padding

The canonical, unpadded skipdraw is also correct: the draw path is 24 cycles and the skip path is 17. The store still happens on every line and the sprite still appears only on its rows. The padding matters only when the *line time* is part of the budget — a second object whose store has a deadline, or a sound routine that must run at a fixed point. Exercise 1 removes the padding to make room for a second sprite and shows the trade.

:::

### The exhaust: the carry into `ENAM0` without a branch

The exhaust is missile 0, a 2×8 object. Its state is one bit: enable (bit 1 of `ENAM0`) or not. That is exactly the shape of the skipdraw test, so it can be computed with no branch at all:

```asm
    TXA
    SEC
    SBC ExhaustY
    CMP #EXHAUST_HEIGHT
    ROL
    ROL
    EOR #2
    STA ENAM0
```

Walk the flags through. After `CMP #8`, carry is **clear** when the difference is 0..7 (inside the eight exhaust rows) and **set** otherwise. The first `ROL` shifts the carry into bit 0, so bit 0 is 1 when the line is *outside*. The second `ROL` shifts bit 0 into bit 1, so bit 1 is still 1 when outside. `EOR #2` inverts bit 1, and bit 1 is the enable: **1 inside the eight rows, 0 outside**. The other bits of A are leftovers from the rotation; the TIA ignores everything except bit 1 in `ENAM0`.

The block is eight instructions and 18 cycles, constant, with no branch. Compare it with the branchy alternative — `BCC` over an `LDA #2`/`LDA #0` pair — which would cost a branch and two different paths. The branchless form is the right tool for a one-bit object.

The block is 18 cycles from its own start. In this ROM it runs after the 25-cycle rocket block, so `STA ENAM0` starts at cycle 40 and completes at 43 (the breakpoint fires at 61/40); the exhaust's left edge is X=79, drawn at cycle 49.0, so the enable has 6 cycles of margin. Run first, the same block would complete at cycle 18 and have 31 cycles of margin — which is why the order of the objects in a tight line matters.

### The 192-line schedule and the 76-cycle budget

The frame is the course's NTSC skeleton: 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262 lines. The visible area is three bands:

| Visible lines | Lines | Band | What draws it |
|---|---:|---|---|
| 0–23 | 24 | Star band | one playfield row per line, plus the skipdraw |
| 24–167 | 144 | Flight region | the rocket, the exhaust and nothing else |
| 168–191 | 24 | Ground band | a solid playfield band |
| **192** | | | |

In absolute scanlines (visible line 0 is scanline 37):

| Band | Scanlines |
|---|---|
| Star band | 37–60 |
| Flight region | 61–204 |
| Ground band | 205–228 |
| Overscan | 229–258 |
| Next VSYNC | 259–261 |

The band boundaries are where the playfield changes. The star band writes a 24-entry playfield column (three bytes per line) on every line, so its stars are single scanlines (each star is one 4-pixel playfield chunk). The flight region and the ground band write the playfield once, at their boundary, and leave it static. The ground band's first line (205) writes its PF early (15/18/21). The flight boundary clears the PF at the end of the star band's last line (60), hidden by the empty row 23.

The per-line ledgers:

| Band line | Work | WSYNC | Total | Margin |
|---|---:|---:|---:|---:|
| Star line | 21 (PF0/PF1/PF2) + 25 (P0) + 7 (loop) = 53 | 3 | 56 | 20 |
| Flight line | 25 (P0) + 18 (M0) + 7 (loop) = 50 | 3 | 53 | 23 |
| Ground loop line | 5 (colour) + 2 (`DEY`) + 3 (`BNE`) = 10 | 3 | 13 | 63 |

The first star line is five cycles longer because the loop is rotated: `LDX #0` and `JMP StarBody` run before the first body so that the first visible line is really line 0, not a wasted `WSYNC` line. Its playfield stores complete at 17, 24 and 31 (the steady-state lines complete at 7, 14 and 21). The first ground line carries the boundary work — the horizon colour, the `ENAM0` clear and the three `$FF` playfield writes — and its stores complete at cycles 5, 15, 18 and 21, all inside the chunk deadlines (PF0 22.67, PF1 28.0, PF2 38.67).

The loop is `INX` / `CPX #168` / `BNE`, 7 cycles when taken. X is the visible-line counter and also the index into the star tables; after the star loop it continues into the flight loop at 24, so the sprite math always sees the true screen line.

### The auto-demo and the two states

`Frame` counts every frame. The table index is `(Frame >> 2) & 63`, so the rocket steps once every four frames and the table repeats every 256 frames (4.27 seconds at 60 Hz). In ROM time the low hold (indices 14–33, frames 56–135) is **0.93–2.25 s** and the high hold (indices 0–5 and 42–63, frames 0–23 and 168–255) is **0–0.38 s and 2.80–4.25 s**. A capture's exact frame depends on how long Stella takes to open its window, so the two-second capture lands in the low hold and the five-second capture in the next period's high hold (the first 0.38 s after the 4.27-second wrap).

SELECT (bit 1 of `SWCHB`, active low) restarts the table by zeroing `Frame`; a one-byte edge latch makes it happen once per press. The demo needs no controller.

::: tip Where the idiom comes from

**8bitworkshop's VCS material** and AtariAge's kernel-programming threads document skipdraw as a way to draw a sprite in a one-line kernel with one branch per line plus an unconditional store, and with a padded path when two objects share the line. This lesson reconstructs the mechanism from those community descriptions and verifies it in Stella. It does not name or reproduce any particular cartridge's code, and the rocket, exhaust, stars and ground are original art. No claim is made that every commercial game used this exact shape.

:::

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson74.bin \
  lessons/part11-legendary/74-skipdraw-kernel/74-skipdraw-kernel.asm
stella build/lesson74.bin
```

The two exercise solutions sit beside the lesson source and are complete 4,096-byte ROMs:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part11-legendary/74-skipdraw-kernel/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part11-legendary/74-skipdraw-kernel/exercise-02-solution.asm
```

### Full Source

The complete annotated source, reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 74: Skipdraw — The Classic Sprite Kernel Idiom
; =============================================================================
; Part 11: Legendary Techniques
;
; What this program does:
;   "the elevator": a vertical rocket scene.  Player 0 is an 8x16 rocket;
;   missile 0 is its 2x8 exhaust, drawn directly under the rocket.  The
;   playfield gives the scene three bands: a 24-line star band at the top,
;   a 144-line flight region, and a 24-line ground band at the bottom.  A
;   64-entry auto-demo table raises and lowers the rocket so the screen is
;   alive without a controller; SELECT restarts the table.
;
;   The rocket is drawn by SKIPDRAW, the classic one-line sprite idiom:
;
;       LDY #0
;       TXA
;       SEC
;       SBC RocketY
;       CMP #ROCKET_HEIGHT
;       BCC .draw
;       <padding>
;       JMP .store
;   .draw:
;       TAY
;       LDA RocketGfx,Y
;       TAY
;   .store:
;       STY GRP0
;
;   X is the visible-line counter (0..191).  The subtraction is unsigned:
;   on the lines before the sprite it wraps to a value of 112 or more, and
;   on the lines after it the plain difference is 16 or more.  Only the 16
;   rows inside the sprite give a difference of 0..15, so only those rows
;   load a graphic byte.  The carry from CMP is the unsigned "before the
;   sprite" test.  The store is UNCONDITIONAL: on a skipped line Y is still
;   zero, so STY GRP0 writes 0 and the sprite disappears.  That is what
;   lets the idiom use one branch and one store.
;
;   The two paths are cycle-equal.  The draw path pays the taken branch
;   (+1) and the 8-cycle TAY/LDA/TAY; the skip path pays 6 cycles of NOP
;   padding and a 3-cycle JMP.  9 = 9, so both paths are 25 cycles.  The
;   ledger is in the comments at the macro.
;
;   The exhaust uses the BRANCHLESS carry form:
;
;       TXA
;       SEC
;       SBC ExhaustY
;       CMP #EXHAUST_HEIGHT
;       ROL
;       ROL
;       EOR #2
;       STA ENAM0
;
;   CMP leaves carry clear when the line is inside the 8 exhaust rows.
;   The first ROL moves that bit into bit 0, the second into bit 1, and
;   EOR #2 inverts it: bit 1 of A is now 1 exactly on the exhaust rows.
;   ENAM0's enable is bit 1, so the store both enables and disables the
;   missile with no branch at all.  18 cycles, always.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 content + 30 overscan = 262.
;   The 192 content lines are three bands:
;
;     visible   0-23    the star band      24 lines   PF stars, one row/line
;     visible  24-167   the flight region 144 lines   the rocket + exhaust
;     visible 168-191   the ground band    24 lines   a solid PF band
;                       ----------------
;                       24 + 144 + 24 = 192
;
;   Measured schedule (Stella breakpoints): the star bodies run on
;   absolute lines 37-60, the flight bodies on 61-204, the ground band on
;   205-228, the overscan on 229-258 and the VSYNC on 259-261.  The
;   picture is 37-228 (192 lines) and the frame gate is StartFrame 259/3,
;   VblankStart 0/5: 3 + 37 + 192 + 30 = 262.
;
;   Measurement convention: a checkpoint's line/cycle is the instruction's
;   start line and start cycle, with the line's cycle 0 being the first
;   instruction after the WSYNC release.  A breakpoint on the first
;   instruction after a STA WSYNC fires during the stall and reports the
;   WSYNC's own line/cycle; the instruction itself starts on the next line
;   at cycle 0.  The store cycles are start cycles: STY GRP0 starts at 22
;   (completes 25), STA ENAM0 at 40 (completes 43) and STA WSYNC at 50
;   (completes 53).
;
;   The star band writes a 24-entry playfield column (three bytes per line)
;   on every line, so the
;   stars are single scanlines (4 pixels wide; the playfield's chunk is 4
;   pixels).  The flight region and the ground band write the playfield
;   once at their band boundary and leave it static.  The flight line's
;   work is 25 + 18 + 7 = 50 cycles (the WSYNC write completes at 53);
;   the star line's is 21 + 25 + 7 = 53 (56 with the WSYNC), and the very
;   first star line adds the LDX/JMP prologue.  All are inside 76.
;
;   The rocket's vertical position is the table's value plus FLIGHT_START
;   (24), so RocketY is a screen line in 32..144 and the exhaust is
;   ExhaustY = RocketY + 16 in 48..160.  The rocket can never reach the
;   star band or the ground band: the table's range is 8..120, so the
;   sprite's rows are 32..159 and the exhaust's rows are 48..167.  The
;   exhaust's last row (167) meets the ground band's first row (168).
;
;   The screen X positions are set ONCE at reset: P0's left edge at
;   ROCKET_X = 76, and M0 at EXHAUST_X = 79 (the missile is 2 pixels wide
;   and sits under the rocket's centre).  Nothing in the kernel writes
;   RESP0 or RESM0, so the horizontal position cannot drift.
;
;   The missile enable is cleared twice on purpose.  The flight loop
;   recomputes ENAM0 on every line, but the star band and the ground band
;   do not run the missile code: they would inherit the last flight line's
;   value.  At the low hold the last flight line is X=167 and
;   ExhaustY=160, so the difference is 7 and the missile is ENABLED; left
;   alone it would streak through the ground band and the next frame's
;   star band.  ENAM0 is therefore cleared in VBLANK (before the star
;   band) and again at GroundLine (before the ground band).
;
;   GRP0 needs no such clear in the ground band.  The last flight line is
;   X=167 and RocketY never exceeds 144, so 167 - RocketY is at least 23:
;   the skipdraw always takes the skip path on the last flight line and
;   stores 0.  GRP0 is therefore already blank when the ground band
;   starts.  This invariant is tied to the table's 8..120 range; widening
;   the table so the rocket can reach line 152 or lower would put a real
;   row on the last flight line and require an explicit GRP0 clear at the
;   ground boundary.
;
; The auto-demo:
;   Frame counts every frame.  The table index is (Frame >> 2) & 63, so
;   the rocket steps once every 4 frames and the table repeats every 256
;   frames (about 4.3 seconds).  The table holds the rocket high on screen
;   (table 8, screen 32) for indices 0-5 and 42-63, and low (table 120,
;   screen 144) for indices 14-33.  The holds are wide: a 2-second capture
;   lands in the low hold and a 5-second capture in the high hold even
;   when Stella's window takes a second to open.
;
;   SELECT (SWCHB bit 1, active low) restarts the table by zeroing Frame.
;   PrevSelect makes the reset happen once per press.
;
; Checkpoints (the values are the state at the label):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5); the first
;   flight body is on line 61 (its first STY GRP0 fires at 61/22), the
;   first ground line is 205 and the first blanked line is 229;
;   DemoRead (A = the table value + 24, i.e. the new RocketY),
;   SelectReset (A = 0, the new Frame).  See the measurement-convention
;   note above for the WSYNC breakpoint artifact.
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80 Frame         frame counter for the auto-demo
;   $81 PrevSelect    SELECT edge latch (0 = released, 1 = pressed)
;   $82 RocketY       the rocket's top screen line (32..144)
;   $83 ExhaustY      the exhaust's top screen line (RocketY + 16)
;   $84-$F7           free (116 bytes)
;   $F8-$FF           stack
;
; Build: acme -f plain -o build/lesson74.bin \
;        lessons/part11-legendary/74-skipdraw-kernel/74-skipdraw-kernel.asm
; Run:   stella build/lesson74.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan

VISIBLE_LINES  = 192     ; the picture
STAR_LINES     = 24      ; visible 0-23
FLIGHT_LINES   = 144     ; visible 24-167
GROUND_LINES   = 24      ; visible 168-191
FLIGHT_START   = STAR_LINES                  ; 24: the flight region's first line
FLIGHT_END     = STAR_LINES + FLIGHT_LINES   ; 168: the ground band's first line

ROCKET_HEIGHT  = 16      ; the player sprite is 8 x 16
EXHAUST_HEIGHT = 8       ; the missile is 2 x 8
ROCKET_X       = 76      ; the rocket's left edge (fixed)
EXHAUST_X      = 79      ; the exhaust's left edge (the rocket's centre)

POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

DEMO_LEN       = 64      ; 64 entries = a 256-frame loop

; --- colours -----------------------------------------------------------------
C_SKY          = $82     ; the night sky: dark blue
C_STAR         = $0E     ; the playfield stars: white
C_ROCKET       = $1A     ; the rocket and its exhaust: gold
C_GROUND       = $26     ; the ground: brown
C_HORIZON      = $2A     ; the ground's top line: a lighter brown

; The band arithmetic is a build-time assertion, not a comment: the three
; bands must fill the 192-line picture exactly.
!if STAR_LINES + FLIGHT_LINES + GROUND_LINES != VISIBLE_LINES {
    !error "the three bands must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$83; +clean_start zeroes every byte)
; =============================================================================
Frame        = $80   ; the auto-demo's frame counter
PrevSelect   = $81   ; SELECT edge latch: 0 = released, 1 = pressed
RocketY      = $82   ; the rocket's top screen line, 0..191
ExhaustY     = $83   ; the exhaust's top screen line, RocketY + 16
;
; $84-$F7 are free (116 bytes).  The stack lives at $F8-$FF; the call depth
; stays at one level (the two positioners at reset only).

; =============================================================================
; ROCKETSKIPDRAW — one line of the rocket, 25 cycles on both paths
; =============================================================================
; X is the visible line (0..191).  The subtraction X - RocketY is unsigned:
;
;   X <  RocketY        wraps to 112..255   -> CMP #16 sets carry -> skip
;   RocketY <= X < +16  gives   0..15       -> carry clear         -> draw
;   X >= RocketY + 16   gives  16..159      -> carry set           -> skip
;
; The wrap is the "before the sprite" test: a negative difference becomes a
; large unsigned one, so one CMP covers both edges of the sprite.  The two
; bounds cannot alias an in-range row because RocketY never exceeds 144
; and 256 - 144 = 112 is far above 15.
;
; The store is unconditional.  On a skipped line Y is still 0 (set at the
; top), so STY GRP0 writes a blank line.  On a drawn line Y is the row.
;
; Cycle ledger (both paths total 25):
;   shared:    LDY #0      2
;              TXA         2
;              SEC         2
;              SBC RocketY 3   (zero page)
;              CMP #16     2
;   draw:      BCC .draw   3   (taken)      skip: BCC .draw   2  (not taken)
;              TAY         2                    NOP            2
;              LDA Gfx,Y   4   (page-aligned)  NOP            2
;              TAY         2                    NOP            2
;              -                             JMP .store      3
;              -                                (9 cycles)      (9 cycles)
;   both:      STY GRP0     3
;              ------------------------------
;              11 (through CMP) + 2 (branch base) + 9 (extra) + 3 = 25
;
; The ledger counts from cycle 0, the first instruction after the WSYNC
; release.  STY GRP0 starts at cycle 22 and completes at 25 (measured with
; a Stella breakpoint at the store: 61/22 on the first flight line (a skip
; line; the first drawn row fires at 69/22).  The
; rocket's left edge is X=76, drawn at cycle 22.67 + 76/3 = 48.0, so the
; store has 23 cycles of margin.
!macro RocketSkipdraw {
    LDY #$00                ; 2  Y = 0 is the "not on this line" value
    TXA                     ; 2  A = the visible line
    SEC                     ; 2
    SBC RocketY             ; 3  A = line - RocketY (unsigned)
    CMP #ROCKET_HEIGHT      ; 2  carry set when the row is outside 0..15
    BCC .draw               ; 3 taken inside the sprite, 2 outside
    NOP                     ; 2  \
    NOP                     ; 2   | 6 cycles of padding plus the JMP:
    NOP                     ; 2   | 9 cycles, equal to the draw path's
    JMP .store              ; 3  /  taken branch (+1) plus TAY/LDA/TAY (8)
.draw:
    TAY                     ; 2  Y = the sprite row 0..15
    LDA RocketGfx,Y         ; 4  the row's 8 pixels (RocketGfx is aligned)
    TAY                     ; 2  move the shape into Y for the store
.store:
    STY GRP0                ; 3  unconditional: 0 above and below, the row inside
}

; =============================================================================
; EXHAUSTBRANCHLESS — one line of the missile, 18 cycles, no branch
; =============================================================================
; CMP #8 leaves carry clear when the unsigned difference is 0..7, i.e. on
; the exhaust's eight rows.  Two ROLs move that carry into bit 1; EOR #2
; inverts it, so bit 1 is 1 exactly on the exhaust rows.  ENAM0's enable
; is bit 1, so one store sets the whole missile state for the line.  The
; other bits of A are rotated leftovers; the TIA ignores everything but
; bit 1 in ENAM0.
;
;   TXA 2 + SEC 2 + SBC 3 + CMP 2 + ROL 2 + ROL 2 + EOR 2 + STA 3 = 18
;
; The block is 18 cycles from its own start.  In the flight line it runs
; after the 25-cycle rocket block, so STA ENAM0 starts at cycle 40 and
; completes at 43 (measured at 61/40); the exhaust at X=79 is drawn at
; cycle 22.67 + 79/3 = 49.0, leaving 6 cycles of margin.  Run first, the
; same block would complete at cycle 18 and have 31 cycles of margin.
!macro ExhaustBranchless {
    TXA                     ; 2  A = the visible line
    SEC                     ; 2
    SBC ExhaustY            ; 3  A = line - ExhaustY (unsigned)
    CMP #EXHAUST_HEIGHT     ; 2  carry clear on the eight exhaust rows
    ROL                     ; 2  carry -> bit 0
    ROL                     ; 2  bit 0 -> bit 1 (1 = outside)
    EOR #$02                ; 2  invert bit 1 (1 = inside)
    STA ENAM0               ; 3  bit 1 enables missile 0
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
    LDA #C_SKY
    STA COLUBK              ; dark blue sky for every band
    LDA #C_STAR
    STA COLUPF              ; the star band's playfield colour
    LDA #C_ROCKET
    STA COLUP0              ; the rocket and (later) the exhaust
    LDA #$01
    STA CTRLPF              ; reflect the playfield; 1-pixel ball
    LDA #$10
    STA NUSIZ0              ; missile 0 is 2 pixels wide; P0 one normal copy
    LDA #$00
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    STA ENAM0
    STA ENAM1
    STA ENABL

; --- position P0 and M0 ONCE ------------------------------------------------
; Each routine is the Lesson 26 divide-by-15 dance: 5 cycles per iteration
; = 15 color clocks, the remainder becomes the fine motion, and the coarse
; stroke lands on the beam.  Both routines end with a WSYNC, then the single
; HMOVE applies both fine values.  Nothing after this touches RESP0, RESM0
; or the motion registers, so the X positions stay put for every frame.
    LDA #(ROCKET_X + POS_BIAS)
    JSR SetHorizPosP0
    LDA #(EXHAUST_X + POS_BIAS + 1)
    JSR SetHorizPosM0
    STA HMOVE               ; apply HMP0 and HMM0 together (A is ignored)

; --- the first frame's state -------------------------------------------------
    LDA #$00
    STA Frame
    STA PrevSelect
    LDA #(8 + FLIGHT_START) ; the table's first value: high on screen
    STA RocketY
    CLC
    ADC #ROCKET_HEIGHT
    STA ExhaustY

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
; 1. SELECT — a new press restarts the auto-demo table
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is pressed.  PrevSelect makes the reset
; happen on the falling edge, once per press.
    LDA SWCHB
    AND #$02
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$00
SelectReset:                ; checkpoint: A = 0, the new Frame
    STA Frame
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; -----------------------------------------------------------------------------
; 2. THE AUTO-DEMO — one 64-entry table step every 4 frames
; -----------------------------------------------------------------------------
; The index is (Frame >> 2) & 63.  The table's value is relative to the
; flight region, so FLIGHT_START (24) turns it into a screen line.
    LDA Frame
    LSR                     ; Frame >> 1
    LSR                     ; Frame >> 2: one step every 4 frames
    AND #(DEMO_LEN - 1)     ; wrap the 64-entry table
    TAY
    LDA RocketTable,Y
    CLC
    ADC #FLIGHT_START
DemoRead:                   ; checkpoint: A = the table value + 24 = RocketY
    STA RocketY
    CLC
    ADC #ROCKET_HEIGHT
    STA ExhaustY

; -----------------------------------------------------------------------------
; 3. THE BAND COLOURS — the star band is white on the dark sky
; -----------------------------------------------------------------------------
    LDA #C_STAR
    STA COLUPF
    LDA #C_ROCKET
    STA COLUP0
    LDA #$00
    STA ENAM0               ; the star band does not run the missile code

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:                  ; checkpoint: scanline 37/5, visible line 0

; =============================================================================
; VISIBLE LINES 0-23: THE STAR BAND (one playfield row per line)
; =============================================================================
; X is both the line counter and the star table index: the band is exactly
; 24 lines, so StarPFx,X reads row X.  The rocket cannot reach this band
; (its first row is 32), but the skipdraw still runs here and stores 0 on
; every line: GRP0 stays blank because X - RocketY wraps to a large value.
;
; The loop is rotated so its first body runs on the first visible line.
; Line 37 is drawn immediately after VBLANK (the label is at 37/5 and the
; body starts at cycle 10); every later line starts at a WSYNC.
; Store completions: on the first line PF0/PF1/PF2 complete at 17/24/31
; (the body starts at cycle 10); on every later line they complete at
; 7/14/21 (the body starts at cycle 0).  All are inside the chunk
; deadlines 22.67/28.0/38.67.
    LDX #$00
    JMP StarBody
StarLoop:
    STA WSYNC               ; line X, X = 1..23
StarBody:
    LDA StarPF0,X           ; 4  chunks 0-3  (page-aligned: no page cross)
    STA PF0                 ; 3  PF0 deadline: cycle 22.67 (pixel 0)
    LDA StarPF1,X           ; 4  chunks 4-11
    STA PF1                 ; 3  PF1 deadline: cycle 28.0 (pixel 16)
    LDA StarPF2,X           ; 4  chunks 12-19
    STA PF2                 ; 3  PF2 deadline: cycle 38.67 (pixel 48)
    +RocketSkipdraw         ; 25 GRP0 = 0 on every star line
    INX                     ; 2
    CPX #STAR_LINES         ; 2
    BNE StarLoop            ; 3 taken

; -----------------------------------------------------------------------------
; The flight boundary runs at the end of line 23.  Star row 23 is empty on
; purpose: the PF clear lands after the line's visible part, where an empty
; row hides it.  COLUPF becomes black (the flight region has no playfield).
; -----------------------------------------------------------------------------
    LDA #$00
    STA COLUPF
    STA PF0
    STA PF1
    STA PF2
    JMP FlightLoop          ; skip the page-alignment fill (never execute it)

; =============================================================================
; VISIBLE LINES 24-167: THE FLIGHT REGION (the rocket and the exhaust)
; =============================================================================
; The loop is page-aligned so the ledgers below are true on hardware.  A
; taken branch that crosses a page boundary costs one extra cycle: if the
; rocket block's BCC or the loop's BNE straddled $F0xx -> $F1xx, the draw
; path would be 26 and the loop 8, and the 25/25 equality would be false.
; With FlightLoop on a page boundary, the BCC at +10, its .draw target at
; +18 and the BNE target at +0 are all in the same page.
;
; A flight line is 25 (rocket) + 18 (exhaust) + 7 (loop) = 50 cycles; the
; WSYNC write completes at 53, inside the 76-cycle line.  Nothing is
; written to the playfield here, so the band stays a clean sky.
    !align 255, 0
FlightLoop:
    STA WSYNC               ; line X
FlightStart:                ; checkpoint: the first flight body is on line 61
    +RocketSkipdraw         ; 25 cycles: GRP0 = the row or 0
    +ExhaustBranchless      ; 18 cycles: ENAM0 = 2 on the 8 exhaust rows
    INX                     ; 2
    CPX #FLIGHT_END         ; 2
    BNE FlightLoop          ; 3 taken (same page: no branch page cross)

; =============================================================================
; VISIBLE LINES 168-191: THE GROUND BAND (a static playfield band)
; =============================================================================
; GroundStart is the band's first line.  The PF stores complete at cycles
; 15/18/21 (PF0/PF1/PF2), all inside the chunk deadlines 22.67/28.0/38.67,
; so the band is full width from its first pixel.  The first line uses the
; lighter horizon colour; the loop rewrites COLUPF with the ground colour
; on the following lines.  The ENAM0 clear is here and in VBLANK: the last
; flight line can end with the exhaust enabled, and the ground and star
; bands do not run the missile code.
GroundStart:                ; checkpoint: the first ground line is 205
    STA WSYNC               ; line 205
GroundLine:                 ; checkpoint: the ground setup line (205)
    LDA #C_HORIZON
    STA COLUPF              ; the horizon line's colour (completes at cycle 5)
    LDA #$00
    STA ENAM0               ; the last flight line can end with the exhaust on
    LDA #$FF
    STA PF0                 ; chunks 0-3   (completes at cycle 15)
    STA PF1                 ; chunks 4-11  (completes at cycle 18)
    STA PF2                 ; chunks 12-19 (completes at cycle 21)
    LDY #(GROUND_LINES - 1) ; 23 more ground lines: 169-191
GroundLoop:
    STA WSYNC               ; line 169 ... 191
    LDA #C_GROUND
    STA COLUPF              ; the ground colour from the second line down
    DEY                     ; 2
    BNE GroundLoop          ; 3 taken
    STA WSYNC               ; finish line 191

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: the first blanked line is 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SETHORIZPOSP0 / SETHORIZPOSM0 — the Lesson 26 dance, one object each
; =============================================================================
; A = the desired left edge + the output-delay bias.  Each routine starts a
; fresh line, divides by 15 (5 cycles = 15 color clocks per iteration), stores
; the remainder as the signed fine value, and strokes the coarse reset.  The
; caller's single HMOVE applies both fine values.
    !align 31, 0
SetHorizPosP0:
    STA WSYNC
    SEC
DivP0:
    SBC #15
    BCS DivP0
    EOR #7                  ; the negative remainder -> the signed fine value
    ASL                     ; bits 0-3 -> HMP0's high nibble
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0               ; the coarse strobe
    STA WSYNC
    RTS

    !align 31, 0
SetHorizPosM0:
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

; =============================================================================
; THE ROCKET — 16 rows, eight pixels wide, page-aligned
; =============================================================================
; The skipdraw loads a row with LDA RocketGfx,Y.  The table is page-aligned
; so the load is always 4 cycles and never pays the page-cross penalty: the
; cycle ledger depends on it.
    !align 255, 0
RocketGfx:
    !byte %00011000         ; 0   ..##....
    !byte %00111100         ; 1   .####...
    !byte %01111110         ; 2   .######.
    !byte %01111110         ; 3   .######.
    !byte %11111111         ; 4   ########
    !byte %11111111         ; 5   ########
    !byte %11100111         ; 6   ###..###  the porthole
    !byte %11111111         ; 7   ########
    !byte %11111111         ; 8   ########
    !byte %11111111         ; 9   ########
    !byte %11111111         ; 10  ########
    !byte %11111111         ; 11  ########
    !byte %11111111         ; 12  ########
    !byte %11100111         ; 13  ###..###  the fins
    !byte %11100111         ; 14  ###..###
    !byte %11000011         ; 15  ##....##

; =============================================================================
; THE AUTO-DEMO TABLE — 64 entries, relative to the flight region
; =============================================================================
; Screen line = value + 24.  The rocket is high on screen (8 -> 32) for
; indices 0-5 and 42-63, and low (120 -> 144) for 14-33.  The holds are
; wide on purpose: a capture's frame number depends on how long Stella
; takes to open its window, so the 2-second capture lands somewhere in
; 16-23 (the low hold) and the 5-second capture in 60-63 or 0-3 (the high
; hold).  Indices 6-13 descend and 34-41 rise: about 14 pixels every 4
; frames.
RocketTable:
    !byte  8,  8,  8,  8,  8,  8                   ;  0-5   high hold
    !byte 16, 30, 44, 58, 72, 86,100,114           ;  6-13  descend
    !fill 20, 120                                  ; 14-33  low hold
    !byte 114,100, 86, 72, 58, 44, 30, 16          ; 34-41  rise
    !fill 22,  8                                   ; 42-63  high hold

; =============================================================================
; THE STAR BAND — one playfield row per visible line
; =============================================================================
; Chunk-to-register: chunks 0-3 are PF0 bits 4-7, chunks 4-11 are PF1
; bits 7-0, chunks 12-19 are PF2 bits 0-7.  CTRLPF reflects the playfield,
; so each 4-pixel chunk appears twice, mirrored about the centre.  Row 23
; is empty: it hides the flight-boundary PF clear (see the kernel).
    !align 255, 0
StarPF0:
    !byte $80, $00, $20, $00, $00, $00, $40, $00, $10, $00, $00, $80
    !byte $00, $20, $00, $00, $00, $40, $00, $10, $00, $00, $80, $00

    !align 255, 0
StarPF1:
    !byte $04, $20, $00, $09, $80, $00, $10, $00, $02, $40, $00, $04
    !byte $20, $00, $08, $81, $00, $10, $00, $42, $00, $20, $04, $00

    !align 255, 0
StarPF2:
    !byte $00, $00, $04, $00, $00, $20, $00, $01, $08, $00, $02, $00
    !byte $10, $00, $04, $00, $20, $00, $09, $00, $40, $02, $00, $00

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
> `lessons/part11-legendary/74-skipdraw-kernel/74-skipdraw-kernel.asm`.

### Code Walkthrough

#### Step 1 — The frame and the three bands

The frame is the standard skeleton. The only unusual part is the rotated star loop:

```asm
StartFrame:
    +vsync
VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    INC Frame
    ; ... SELECT, the demo table, the colours ...
    +wait_timer
    LDA #$00
    STA VBLANK
BodyStart:
    LDX #$00
    JMP StarBody
StarLoop:
    STA WSYNC
StarBody:
    ; ... the star row and the skipdraw ...
    INX
    CPX #STAR_LINES
    BNE StarLoop
```

If the loop started with `STA WSYNC`, the first visible line would be consumed by the wait and the whole picture would shift one line down, growing the frame to 263. Jumping into the body for X=0 draws line 37 immediately; every later line starts at a `WSYNC`. The same pattern, with a `WSYNC` at the top, is safe for the flight and ground loops because their first lines are boundary lines that no sprite uses.

#### Step 2 — The star band

The star band is 24 playfield rows, one per line:

```asm
    LDA StarPF0,X           ; chunks 0-3
    STA PF0
    LDA StarPF1,X           ; chunks 4-11
    STA PF1
    LDA StarPF2,X           ; chunks 12-19
    STA PF2
    +RocketSkipdraw
```

The three tables are page-aligned, so each load is 4 cycles and never crosses a page. On every line after the first, the stores complete at cycles 7, 14 and 21; on the first line they complete at 17, 24 and 31 because the body starts at cycle 10 (after `LDX`/`JMP`). The playfield chunk deadlines are **22.67** for PF0 (pixel 0), **28.0** for PF1 (pixel 16) and **38.67** for PF2 (pixel 48); 70.7 is the deadline of the mirrored PF0 at pixel 144, not PF2. All the star stores are inside the first three. Row 23 of the tables is empty on purpose: the flight boundary's playfield clear runs at the end of line 60, after most of that line has been drawn, and an empty row hides the change. The band's star pixels are therefore 4×1 chunks; `CTRLPF = $01` reflects the playfield, so each star appears twice, mirrored about the centre.

#### Step 3 — The flight boundary and the flight loop

After the star loop, the transition clears the playfield and the playfield colour, jumps over the page-alignment fill, and starts the flight loop:

```asm
    LDA #$00
    STA COLUPF
    STA PF0
    STA PF1
    STA PF2
    JMP FlightLoop          ; skip the alignment fill; never execute it
    !align 255, 0
FlightLoop:
    STA WSYNC
FlightStart:
    +RocketSkipdraw         ; 25 cycles
    +ExhaustBranchless      ; 18 cycles
    INX
    CPX #FLIGHT_END
    BNE FlightLoop
```

The alignment is part of the ledger, not decoration. A taken branch that crosses a page boundary costs one extra cycle: without the alignment the rocket block's `BCC` would be 4 cycles and the draw path 26, and the loop's `BNE` would make the loop 8. With `FlightLoop` on a page boundary, the `BCC` at +10, its `.draw` target at +18 and the `BNE` target at +0 are all in the same page, so the 25/25 and 7-cycle ledgers are true. The `JMP` keeps the CPU out of the fill bytes (`!align` pads with `$00`, which would execute as `BRK`).

The flight loop is 144 lines, X=24..167. The rocket's screen rows are 32..159 (the table's 8..120 plus the 24-line offset) and the exhaust's are 48..167, so the sprites never touch the star or ground bands; the exhaust's last row meets the ground band's first row. On the lines above and below the rocket the skipdraw's wrapped difference sends it down the skip path and `GRP0` gets zero; on the sixteen rocket rows the draw path loads `RocketGfx[row]`.

#### Step 4 — The ground band

`GroundStart` is line 168. Its first line sets the horizon colour and the full-width playfield:

```asm
GroundStart:
    STA WSYNC
GroundLine:
    LDA #C_HORIZON
    STA COLUPF
    LDA #$00
    STA ENAM0               ; the last flight line can end with the exhaust on
    LDA #$FF
    STA PF0
    STA PF1
    STA PF2
    LDY #(GROUND_LINES - 1)
GroundLoop:
    STA WSYNC
    LDA #C_GROUND
    STA COLUPF
    DEY
    BNE GroundLoop
    STA WSYNC
```

The stores complete at cycles 5, 15, 18 and 21, so the ground is full width from its first pixel. The first line keeps the lighter `C_HORIZON`; every later line rewrites `COLUPF` with `C_GROUND` at cycle 5, in time for its first chunk. The `ENAM0` clear is one of the two that keep the missile off outside the flight region: the other is in VBLANK, before the star band. Without them the low hold's last flight line (X=167, ExhaustY=160, difference 7) leaves the missile enabled, and the exhaust streaks through the ground band and the next frame's star band. `GRP0` needs no such clear: the last flight line is always a skip because 167 − RocketY is at least 23 for RocketY ≤ 144, so `GRP0` is already 0 when the ground starts. Widening the table so the rocket could reach line 152 would break that and require an explicit `GRP0` clear. The final `STA WSYNC` finishes visible line 191 (absolute 228) and releases on absolute line 229, where the overscan starts. `LDY #23` plus 23 `DEY`/`BNE` iterations covers lines 169–191.

#### Step 5 — Position once, never again

The horizontal positions are set at reset by the Lesson 26 divide-by-15 dance, one routine per object:

```asm
    LDA #(ROCKET_X + POS_BIAS)
    JSR SetHorizPosP0
    LDA #(EXHAUST_X + POS_BIAS + 1)
    JSR SetHorizPosM0
    STA HMOVE               ; apply HMP0 and HMM0 together
```

Each routine starts a fresh line, subtracts 15 until it borrows (5 cycles per iteration = 15 color clocks), turns the negative remainder into the signed fine value, and strobes the coarse reset. Both routines end with a `WSYNC`; a single `HMOVE` then applies both fine values. Nothing in the kernel writes `RESP0`, `RESM0` or the motion registers, so the X positions cannot drift — the rocket's left edge stays at 76 and the exhaust at 79.

#### Step 6 — The demo table and SELECT

The table read is four instructions:

```asm
    LDA Frame
    LSR
    LSR                     ; Frame >> 2: one step every 4 frames
    AND #(DEMO_LEN - 1)     ; wrap the 64-entry table
    TAY
    LDA RocketTable,Y
    CLC
    ADC #FLIGHT_START       ; the table is relative to the flight region
    STA RocketY
    CLC
    ADC #ROCKET_HEIGHT
    STA ExhaustY
```

`ExhaustY` is `RocketY + 16`, so the exhaust tracks the rocket's base without a second table. SELECT is an edge-triggered reset:

```asm
    LDA SWCHB
    AND #$02
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$00
    STA Frame
```

`PrevSelect` is 1 while the button is held, so the `Frame` reset happens once per press, not once per frame.

#### Step 7 — Reading it back in Stella

Assemble with a symbol file and ask Stella for the checkpoints:

```bash
acme -f plain -l build/lesson74.sym -o build/lesson74.bin \
  lessons/part11-legendary/74-skipdraw-kernel/74-skipdraw-kernel.asm
grep -E "StartFrame|VblankStart|BodyStart|FlightStart|GroundStart|OverscanStart|DemoRead" build/lesson74.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 \
  -break '$F056' docs/public/roms/part11-legendary/74-skipdraw-kernel/74-skipdraw-kernel.bin
```

One checkpoint per run keeps the log readable. The addresses below are the ones this source produced.

#### Step 8 — What the trace shows

The cycle convention, once: **the ledger counts from cycle 0, the first instruction after the `WSYNC` release; a store completes three cycles after it starts.** Stella's breakpoint log reports the instruction's *start* line and cycle. A breakpoint on the first instruction after a `STA WSYNC` fires during the stall and reports the `WSYNC`'s own line/cycle, so only the labels that sit immediately after a `WSYNC` need that correction.

A flight line with the rocket on its first row (the breakpoint at `STY GRP0` fires at 61/22) is:

| Starts | Instruction | Cycles | Completes |
|---:|---|---:|---:|
| 0 | `LDY #0` | 2 | 2 |
| 2 | `TXA` | 2 | 4 |
| 4 | `SEC` | 2 | 6 |
| 6 | `SBC RocketY` | 3 | 9 |
| 9 | `CMP #16` | 2 | 11 |
| 11 | `BCC .draw` | 3 (taken) | 14 |
| 14 | `TAY` | 2 | 16 |
| 16 | `LDA RocketGfx,Y` | 4 | 20 |
| 20 | `TAY` | 2 | 22 |
| 22 | `STY GRP0` | 3 | **25** |
| 25 | `TXA` (M0) | 2 | 27 |
| 27 | `SEC` | 2 | 29 |
| 29 | `SBC ExhaustY` | 3 | 32 |
| 32 | `CMP #8` | 2 | 34 |
| 34 | `ROL` | 2 | 36 |
| 36 | `ROL` | 2 | 38 |
| 38 | `EOR #2` | 2 | 40 |
| 40 | `STA ENAM0` | 3 | **43** |
| 43 | `INX` | 2 | 45 |
| 45 | `CPX #168` | 2 | 47 |
| 47 | `BNE` | 3 (taken) | 50 |
| 50 | `STA WSYNC` | 3 | **53** |

The measured breakpoints agree: `STY GRP0` at 61/22 (completes 25), `STA ENAM0` at 61/40 (completes 43), `STA WSYNC` at 61/50 (completes 53). The rocket's pixel is drawn at cycle 22.67 + 76/3 = 48.0 and the exhaust's at 22.67 + 79/3 = 49.0, so the stores have 23 and 6 cycles of margin. The line uses 53 of 76 cycles; 23 are unused.

On a skipped rocket line the same ledger holds: `BCC` is not taken at 11 (2 cycles, ends 13), three `NOP`s run 13-19, `JMP .store` runs 19-22, and `STY GRP0` starts at 22 — the same cycle as the draw path. That is what "constant cycles" means, and it is why the two paths can share a line with another object whose store has a deadline.

### Checkpoints

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F056` | 259/3 | the first VSYNC line |
| `VblankStart` | `$F064` | 0/5 | the first VBLANK line |
| `BodyStart` | `$F0B4` | 37/5 | visible line 0 |
| `FlightStart` | `$F102` | the first flight body is line 61; the label logs 60/72 during the `WSYNC` stall, the body's `LDY` starts at 61/0 and `$F104` (`TXA`) at 61/2 | visible line 24 |
| `GroundStart` | `$F12A` | the `WSYNC` logs 204/49; the first ground line is 205 (`$F12E` runs at 205/2) | visible line 168 |
| `OverscanStart` | `$F149` | the label logs 228/12; the first blanked line is 229 (`$F14B` runs at 229/2) | the start of overscan |
| `DemoRead` | `$F096` | A = the new `RocketY` (first frame: `$20` = 32) | the table read |
| `SelectReset` | `$F080` | A = 0 | the SELECT reset |

The frame log: `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, the first flight body 61 (its first `STY GRP0` fires at 61/22), the first ground line 205, the first blanked line 229. The visible ledger is 24 + 144 + 24 = 192; 229 − 37 = 192; 3 + 37 + 192 + 30 = 262. The band labels log 60/72, 204/49 (and `GroundLine` 204/52) and 228/12 because of the `WSYNC` breakpoint artifact; the instructions after them run on 61, 205 and 229.

## What You Should See

At power-on the screen is a dark blue night sky. The top 24 lines carry 39 white 4-pixel stars per half, mirrored about the centre by `CTRLPF`'s reflect mode. Below them is the flight region: a gold rocket, 8 pixels wide and 16 rows tall, with a two-pixel gold exhaust under its centre. The bottom 24 lines are a brown ground band with a lighter one-line horizon. The rocket rises and falls every 4.3 seconds; the exhaust follows its base exactly.

![Stella running Lesson 74 at two seconds: the gold rocket low over the brown ground band, its two-pixel exhaust at its base, white star dashes in the top band, and the title bar reading Stella 7.0: "74-skipdraw-kernel"](/images/lesson74/rocket-low.png)

*`rocket-low.png`: about 2 seconds after power-on. The rocket's top row is screen line 144, so the sprite fills rows 144–159 and the exhaust rows 160–167, ending where the ground band begins. The star band is visible lines 0–23 and the ground band 168–191.*

<RomPlayer rom="/roms/part11-legendary/74-skipdraw-kernel/74-skipdraw-kernel.bin" title="Lesson 74 — Skipdraw: The Classic Sprite Kernel Idiom" />

*Javatari starts muted; this ROM is silent.*

The low hold runs from 0.93 to 2.25 s of ROM time; the high hold runs from 2.80 to 4.25 s and again at the start of the next 4.27-second period. The five-second capture lands in that next high hold: the rocket's top row is then screen line 32, the exhaust is at 48–55, and the gap between the rocket and the star band is eight lines. The exhaust and the ground prove the clipping: the gold pixels exist only on the sixteen rocket rows and the eight exhaust rows, and nowhere else.

![Stella running Lesson 74 at five seconds: the same scene with the rocket high, just below the star band, its exhaust at its base, and the ground band at the bottom; the title bar reads Stella 7.0: "74-skipdraw-kernel"](/images/lesson74/rocket-high.png)

*`rocket-high.png`: about 5 seconds after power-on. The rocket's top row is screen line 32; the exhaust is at rows 48–55. The star band, the ground and the colours are unchanged.*

The two images are different states, not two copies of one frame: the rocket is 112 screen lines higher in the second, and the exhaust moved with it. The **pixel check** of the two committed captures:

| Image | Size | Title bar | What the pixels show |
|---|---|---|---|
| `rocket-low.png` | 1010×807 | `Stella 7.0: "74-skipdraw-kernel"` | TIA viewport 960×605 at (25,107); gold span x 76–83 inclusive (8 px; the 6-px sampling reads 76.00–83.83), rows 144–167 inclusive (the ~3.15-px sampling reads 144.08–167.56); rocket rows 144–159, exhaust rows 160–167 at x 79–80; no gold anywhere else; no cursor |
| `rocket-high.png` | 1010×807 | `Stella 7.0: "74-skipdraw-kernel"` | the same viewport; gold span x 76–83 inclusive (sampling 76.00–83.83), rows 32–55 inclusive (sampling 32.05–55.54); rocket rows 32–47, exhaust rows 48–55 at x 79–80; no gold anywhere else; no cursor |

The two states differ by 112 lines: 144 − 32 = 112. The gold bounding box is exactly the sprite and its jet in both images, which is the visual form of "GRP0 = 0 above and below": if the skipdraw failed to clear `GRP0`, there would be a gold column above or below the rocket, or the rocket would smear into a vertical bar.

The **exhaust check** reads the exhaust's two-pixel column at x 79–80: it starts at `RocketY + 16` and is eight rows tall in both captures. The **star check** counts the white star chunks: 39 per half, mirrored, on rows 0–22, with row 23 empty (the boundary line).

> **Capture method.** Both images are `scripts/capture-screenshot.sh` captures of the committed
> `docs/public/roms/part11-legendary/74-skipdraw-kernel/74-skipdraw-kernel.bin` on display `:0`
> (the mutter window manager supplies the title bar) at two and five wall-clock seconds, with
> `xdotool mousemove 0 0` before each. The auto-demo timer starts at power-on: the 2-second image
> samples the low hold (ROM time 0.93–2.25 s) and the 5-second image samples the next period's
> high hold (the first 0.38 s after the 4.27-second wrap). All images are 1010×807, carry the
> window frame and the `Stella 7.0: "74-skipdraw-kernel"` title bar, and show no cursor.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
ROM=docs/public/roms/part11-legendary/74-skipdraw-kernel/74-skipdraw-kernel.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -break '$F056' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -break '$F064' $ROM   # VblankStart
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -break '$F0B4' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -break '$F117' $ROM   # the rocket's STY GRP0
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -break '$F123' $ROM   # the exhaust's STA ENAM0
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -break '$F12E' $ROM   # the first ground line
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -break '$F14B' $ROM   # the first blanked line
```

- **`$F056` (`StartFrame`)** is **259/3** on every frame, and **`$F064` (`VblankStart`)** is **0/5**: the frame does not grow in either demo state.
- **`$F0B4` (`BodyStart`)** is **37/5**; **`$F117`** (`STY GRP0`) first fires at **61/22** on the first flight line (a skip line; the first drawn row is 69/22) (completes 25); **`$F123`** (`STA ENAM0`) at **61/40** (completes 43); **`$F12E`** is the first ground line at **205/2**; **`$F14B`** is the first blanked line at **229/2**. The frame is 262 lines.
- **`$F096` (`DemoRead`)** has A = `$20` (32) on the first frames: the table's first value 8 plus the 24-line flight offset.

The screenshots prove the shapes and the two heights; the state log proves the clock. The thing a still cannot prove is the cycle-level behaviour *within* a line; the traced line in Step 8 is that measurement.

## Exercises

Each exercise ships a complete 4,096-byte `exercise-NN-solution.asm`. The solutions assemble through `npm run roms`, run in Stella, and solve the exercise as written. Both keep the lesson's three bands, the star table, the ground and the auto-demo.

### Exercise 1: A Second Skipdraw Sprite

**Challenge:** add P1 as a second skipdraw sprite with its own Y. Draw a moon: an 8×8 shape at a fixed screen line of your choice (this solution uses Y = 56) and a fixed X (144). Keep the rocket, the exhaust, the frame at 262 lines, and the ROM at exactly 4,096 bytes.

**Hints:**

1. The moon needs its own Y variable and its own graphic table. The unsigned difference `X - MoonY` is the row index, exactly as for the rocket.
2. The order matters: the rocket's store must land before its pixel (X=76 at cycle 48), the exhaust's before X=79 at cycle 49, and the moon's before X=144 at cycle 70.67. The solution uses rocket → exhaust → moon; the stores complete at 24, 42 and 58.
3. Three objects with the branch form cannot be given real margin. The padded rocket (25) plus the exhaust (18) plus a 24-cycle branch moon plus the 7-cycle loop is 74 cycles of work, and 74 + 3 is past the 76-cycle line. Even the unpadded branch forms are 24 + 18 + 24 + 7 = 73, exactly 76 with zero margin. Use the branchless 256-byte table for the moon — the form Exercise 2 develops for P0: its block is 16 cycles, and the worst-case flight line becomes 24 + 18 + 16 + 7 = **65** cycles of work (the `WSYNC` write completes at 68), leaving eight cycles of margin.
4. Page-align the flight loop (`!align 255, 0` plus a `JMP` over the fill) so the `BCS`/`BNE` never cross a page; add a third positioner for P1 (`HMP1`/`RESP1`) and keep the single `HMOVE`.
5. The overlap windows are reachable: at about 0.5 s the table is at index 7 (RocketY 54), so the rocket's rows 54–69 pass through the moon's rows 56–63 and a line can carry both sprites; at about 2.6 s the low hold puts the rocket at rows 144–159. Check the frame gate with breakpoints across both, not only at the 2-second capture: the measured gate is 259/3 on every frame from 1 to 393.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; the moon is visible at TIA x 144–151, rows 56–63; the rocket and exhaust are unchanged; `StartFrame` is 259/3 and the frame is 262; the worst-case flight line is 65 cycles of work (the `WSYNC` completes at 68).

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: The Fully Branchless Player

**Challenge:** replace P0's skip branch with a fully branchless carry form — a full 8-bit mask/index for the player. Keep the exhaust, the bands and the frame.

**Hints:**

1. The difference `X - RocketY` is already an 8-bit value. Use it *directly* as the index into a 256-byte table: `TXA` / `SEC` / `SBC RocketY` / `TAY` / `LDA RocketRows,Y` / `STA GRP0`.
2. The table's first 16 entries are the rocket's rows; the remaining 240 are zero. The lines above the sprite wrap to 112–255 and the lines below it give 16–159; both ranges land in the zero part.
3. Page-align the table with `!align 255, 0` so the indexed load is always 4 cycles and never crosses a page.
4. The block is 16 cycles with no branch and no padding. The printed ledger is `TXA 2 + SEC 2 + SBC 3 + TAY 2 + LDA 4 + STA 3 = 16`; the flight line becomes 16 + 18 + 7 = 41 cycles.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; the rocket still appears only on rows `RocketY..RocketY+15` (measured at 2 s: TIA x 76–83, y 144–167 including the exhaust); the frame gate is 259/3 and the frame is 262. The trade is 240 extra ROM bytes for 9 cycles per line.

**Solution:** See `exercise-02-solution.asm`

## Key Takeaways

- ✅ **The carry is the unsigned window test.** `SEC` / `SBC SpriteY` / `CMP #HEIGHT` leaves carry clear only for the difference 0..HEIGHT−1. A line *before* the sprite wraps to a large unsigned value, so the same compare covers both edges of the sprite; one branch is enough.
- ✅ **The store stays unconditional.** `Y` is zero on the skip path, so `STY GRP0` writes a blank line without a second branch. One branch, one store, one instruction responsible for the sprite's whole vertical shape.
- ✅ **Constant cycles are made, not found.** The draw path's 9-cycle lead (the taken branch plus `TAY`/`LDA`/`TAY`) is matched by 6 cycles of `NOP` padding and a 3-cycle `JMP` on the skip path: 25 = 25. Page-align the graphic table and keep the branch inside a page, or the ledger is wrong.
- ✅ **The missile needs no branch at all.** `CMP` leaves the in-window flag in the carry; two `ROL`s move it to bit 1 and `EOR #2` inverts it, so `STA ENAM0` both enables and disables the missile. 18 cycles, constant.
- ✅ **A one-line kernel is a schedule.** 24 star lines + 144 flight lines + 24 ground lines = 192; 3 + 37 + 192 + 30 = 262. Each band's first line carries its boundary work, and the first star line starts immediately after VBLANK so the picture is not shifted down a line.
- ✅ **The idiom is a budget decision.** Padding costs 8 cycles on a skipped line and 1 on a drawn one, and buys a constant 25-cycle line time; the 256-byte table costs 240 ROM bytes and saves 9 cycles. Exercise 1 drops the padding and gives the moon the 16-cycle table so a third object fits; Exercise 2 spends the ROM to delete P0's branch.
- ✅ **The capture is the proof of the clipping.** The gold pixels exist only on the sprite's rows and the exhaust's rows in both captures; the two states differ by 112 screen lines and the frame gate stays 259/3.

## What's Next

The rocket ends with the two captures and the ground band; [the Part 11 index](/part11-legendary/) lists the rest of the anthology. The next legendary technique, **Pseudo-3D Road**, takes per-scanline control in a different direction: a road that widens as it approaches the bottom of the screen, with a curve table and a dashed centre line — the *Enduro* / *Pole Position* effect. Return to the index for the part's overview and the next lesson.
