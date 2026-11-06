---
title: "Lesson 51: Flicker Sprites — More Than 2 Objects"
description: "Draw four objects with two players by alternating two 30 Hz frames: a flicker scheduler that selects a parity pair every frame, a two-object sort that puts the nearer object on P0, a per-row skipdraw test inside a 2-line kernel with no RAM strips, and a status bar whose cells show the parity and the two objects that a still image can only half capture."
prev:
  text: "Lesson 50: Multi-Zone Kernel — Scoreboard + Playfield + Sprites"
  link: "/part7-kernel-mastery/50-multi-zone-kernel"
next:
  text: "Lesson 52: Fine Scrolling — Smooth Movement"
  link: "/part7-kernel-mastery/52-fine-scrolling"
---

# Lesson 51: Flicker Sprites — More Than 2 Objects

> **Part 7: Kernel Mastery** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 15 (the RIOT timer), Lesson 17 (cycle counting), Lesson 18 (mid-scanline changes), Lesson 19 (the playfield and `CTRLPF`), Lesson 25 (players), Lesson 26 (positioning), Lesson 27 (sprite movement), Lesson 28 (one `HMOVE`), Lesson 31 (`NUSIZ`), Lesson 34 (frame counters), Lesson 49 (the 2-line kernel)
> **You will learn:** how to show more objects than the TIA has players by alternating two 30 Hz frames; how a flicker scheduler selects a parity pair; how a two-object sort decides which object gets P0; how a per-row skipdraw test draws an 8-line object from four shape bytes inside a 2-line kernel; why the two branchy tests have to be split one per scanline; and why a still screenshot can show only one half of the picture
> **You will build:** "the flicker gallery" — a 4,096-byte ROM with four moving, bouncing 8-line objects, two drawn per frame, a 92-row two-line kernel with the per-row skipdraw, a status bar that shows the parity and the two drawn objects, and no sprite strips at all: the whole persistent state is 31 bytes in `$80–$9E` plus one kernel scratch byte at `$A0`; plus three exercise solutions: reversed priority, six objects on three parities, and an always-on player with three flickering enemies

## Introduction

The TIA has two players. Lesson 25 drew a player, Lesson 26 placed it, Lesson 27 moved it, and Lesson 49 gave it a full-screen two-line kernel. A game with four ships, four enemies, or four bullets has a problem: there are only two players, and `NUSIZ` copies are identical — three copies of one shape, not three different objects.

The hardware answer is time, not space. Draw two objects on this frame, the other two on the next, and repeat. Each object appears thirty times a second while the screen refreshes sixty; the eye integrates the alternation and sees four objects. This is **flicker**, and it is the standard way every busy 2600 game shows more sprites than the TIA owns.

The companion program `51-flicker-sprites.asm` is **the flicker gallery**. Four objects move and bounce on their own; parity 0 draws objects 0 and 1, parity 1 draws objects 2 and 3. The picture is 8 status lines plus 184 play lines:

```
visible   0-  7   the status zone   8 lines   a parity cell + four object cells
visible   8-191   the play zone   184 lines   92 rows x 2, the 2-line kernel
                  ----------------
                  8 + 184 = 192 visible lines
```

The status bar is the lesson's honesty device. A still screenshot can only show one half of a flicker, so the bar names that half: a 4-pixel parity mark in the first two chunks (chunk 0 for parity 0, chunk 1 for parity 1) and one 8-pixel cell per object, lit only for the two objects drawn this frame. Open the two screenshots and the difference is not a guess — the bar says which half you are looking at.

The interesting engineering is inside the kernel. Each object is four shape bytes drawn over four 2-line rows, and its vertical position changes every frame, so there is no 92-byte strip in RAM — there is not enough RAM for four of them anyway. Instead the kernel tests every row: `row - ObjRow`, compare against 4, and only inside the object's four rows does it look up `shape * 4 + offset` in a 16-byte shape table. That is a **skipdraw** test, and it is branchy: about 35 cycles per line. Two of them do not fit in one 76-cycle line, which is exactly why this kernel is a two-line kernel: one test on each of the pair's scanlines, 48 and 41 cycles, with more than sixty cycles to spare per pair.

::: details TypeScript Equivalent

A flicker scheduler is a frame counter, a pair selector, and a sort. In TypeScript the same idea is a few lines:

```typescript
interface GameObject {
  x: number; y: number;
  dx: number; dy: number;
  color: number; shape: number;
}

const objects: GameObject[] = [ship0, ship1, ship2, ship3];

function renderFrame(frameNumber: number): void {
  const parity = frameNumber % 2;                  // 0 or 1
  const pair = [objects[parity * 2], objects[parity * 2 + 1]];

  // Y is top-down: the larger Y is nearer the bottom.
  const drawList = [...pair].sort((a, b) => b.y - a.y);

  drawPlayer(0, drawList[0]);                      // the nearer object
  drawPlayer(1, drawList[1]);                      // the farther object
}
```

The analogy breaks at the point where the hardware starts. There is no framebuffer and no `objects` array in RAM that a renderer can read at leisure: the kernel runs while the beam moves, and `drawPlayer` is not a function call but a sequence of register writes that must land before the beam reaches the sprite's pixels. The sort cannot run during the picture either — it runs in VBLANK, before the frame starts, and its result is copied into two 2-byte slots. And `renderFrame` is called sixty times a second with a different pair each time: the function that produces the *perceived* picture is the eye's, not the program's. A still capture calls it once and therefore sees half the objects.

:::

## Theory

### Section 1: Two Players, Four Objects — The 30 Hz Bargain

A player is 8 pixels wide and one color per line. The TIA has two of them (`GRP0`/`GRP1`), plus two missiles and a ball. `NUSIZ` can draw two or three copies of a player, but every copy is the same shape and colour. Four *different* objects need four shapes, and that is more than the hardware can draw in one frame.

Flicker trades time for count. The screen refreshes at 60 Hz; if object A is drawn on every even frame and object B on every odd frame, each object is on screen at 30 Hz. The eye's persistence of vision blends the two frames into one picture with both objects. The cost is visible motion: a 30 Hz object has half the temporal resolution, and fast movement strobes.

The gallery's four objects are split into two fixed pairs:

| Parity | Objects drawn | Cell lit in the status bar |
|---|---|---|
| 0 | 0 and 1 | chunk 0 |
| 1 | 2 and 3 | chunk 1 |

The pairing never changes: objects 0/1 always share parity 0 and objects 2/3 always share parity 1. The scheduler is therefore small — increment or toggle a byte, derive a pair base, compare two Y values.

::: tip Why 30 Hz is the usual choice
Three-frame flicker (20 Hz) exists and this lesson's second exercise builds it. At 20 Hz each object is on screen a third of the time, which is dimmer and strobes more, but it draws six objects with two players. Above three frames the flicker becomes obvious and uncomfortable on a real CRT. Two frames is the sweet spot, and many 2600 games used it.
:::

### Section 2: The Flicker Scheduler and the Sort

Everything the scheduler needs runs in VBLANK, before the picture turns on. Five steps:

1. **Toggle the parity.** `Flicker` holds 0 or 1; `EOR #$01` flips it. Because the register starts at 1, the first displayed frame is parity 0.
2. **Select the pair.** `ASL` turns the parity into the pair's base object index: 0 → objects 0/1, 1 → 2/3.
3. **Sort the pair.** Y is top-down, so the object with the **larger** Y is nearer the bottom of the screen. The nearer object is drawn on P0, its partner on P1.
4. **Copy the slots.** The chosen object's row and shape go to `ObjRow0`/`ObjShape0` (or `ObjRow1`/`ObjShape1`), and its colour goes straight to `COLUP0` (or `COLUP1`). The kernel reads only the slots.
5. **Position the players.** Each slot copy ends by running the divide-by-15 positioning routine for that object's X; one `HMOVE` then applies both fine offsets.

The sort is one compare, because a pair is two objects:

```asm
    LDA ObjY,X
    CMP ObjY+1,X        ; the pair's second object
    BCC SecondNearer    ; first Y < second Y: the second is nearer
    TXA                 ; the first object is the nearer
    JMP SlotSelect
SecondNearer:
    TXA
    CLC
    ADC #$01
```

The P1 index is the P0 index with bit 0 flipped (`EOR #$01`): 0 ↔ 1 and 2 ↔ 3. `PHA`/`PLA` carry the P0 index across the first slot copy. A game with more objects per parity would sort the whole list by Y; with two objects the compare *is* the sort. Exercise 1 reverses the rule, and the state log then reports the farther object where this log reports the nearer one.

The scheduler's checkpoints make the invisible visible: `Parity` reports the frame's parity in A, and `DrawSlot0`/`DrawSlot1` report the two object indices the slots received. On frame 1 the log reads `Parity` A=0, `DrawSlot0` A=1, `DrawSlot1` A=0: the VBLANK motion step runs before the scheduler, so the objects are at Y=63 and Y=17; object 1 is nearer, so object 1 takes P0.

::: tip The slot is not the object
P0 and P1 are drawing slots, not identities. In the gallery the object on P0 changes every frame as the Y values cross, and its colour changes with it: `COLUP0` is loaded from the object, not from the slot. If you expect "the red ship is always P0" you will be surprised by the captures — on some frames the red ship is the lower object and on others it is the upper one.
:::

### Section 3: Skipdraw in a Two-Line Kernel

An object is four shape bytes, one per 2-line row, so it is eight scanlines tall. Its vertical position is `ObjRow0` (or `ObjRow1`), a row index 0–87. The kernel walks all 92 rows and must decide, for each row, whether this row is inside the object:

```asm
    TYA
    SEC
    SBC ObjRow0         ; A = row - ObjRow0
    CMP #4              ; inside the four shape rows?
    BCS NoSlot0         ; no: blank the player and skip the lookup
```

Two details make the test correct for every row. `TYA` sets the flags from Y, `SEC` clears the borrow, and `SBC` computes `row - ObjRow0`. When `row < ObjRow0` the subtraction wraps to a large value, and `CMP #4` reports it as "above the shape" — the same branch that handles "below the shape". Only rows `ObjRow0 .. ObjRow0+3` fall through. Because each line writes only one player, the byte is not disturbed on the other line: the P0 byte written on line 1 stays latched through line 2, and the P1 byte written on line 2 stays latched through the next pair's line 1. That persistence is what makes four shape bytes an 8-line object.

Inside the shape, the byte index is `shape * 4 + (row - ObjRow0)`, computed without a RAM table:

```asm
    STA Tmp             ; Tmp = the row offset, 0..3
    LDA ObjShape0
    ASL                 ; shape x 4 ...
    ASL
    CLC
    ADC Tmp             ; ... + the offset = 0..15
    TAX
    LDA ShapeTable,X    ; the byte
    JMP Store0
NoSlot0:
    LDA #$00
Store0:
    STA GRP0
```

`ShapeTable` is 16 bytes: four shapes of four bytes each, page-aligned so the indexed load never pays a page cross. Shape 0 is an arrowhead, shape 1 a diamond, shape 2 a cross and shape 3 a bug.

The test is *branchy*: 35 cycles on the long path, 14 on the short one. The decisive number is the long path, because it has to fit the line together with the `STA WSYNC` and, on the first line of the pair, the loop tail:

| Work | Cycles |
|---|---|
| `INY` + `CPY #92` + `BNE` (line 1 only) | 7 |
| `TYA` + `SEC` + `SBC` + `CMP` + `BCS` (not taken) | 11 |
| `STA Tmp` + `LDA` + two `ASL` + `CLC` + `ADC` + `TAX` + `LDA abs,X` + `JMP` | 24 |
| `STA GRPx` | 3 |
| `STA WSYNC` | 3 |
| **line 1** | **48** |
| **line 2** (same body, no loop tail) | **41** |
| **the pair** | **89 of 152** |

Both lines are comfortably inside 76 cycles; the pair leaves 63 cycles of the 152-cycle budget. That is the whole reason the two skipdraws are **split** across the two lines instead of stacked on one: `TYA ... STA GRP0` must finish before the beam reaches the sprite's pixels, and two of them on one line would take about 70 cycles before the second store even started.

The shape's 2-line structure is visible in the capture: the blue cross (`$5A, $FF, $FF, $5A`) shows 6 capture rows of 24 pixels of ink, then 12 rows of 48 pixels, then 6 rows of 24 — the four shape bytes, each held for two scanlines.

::: warning The price: where the byte latches
The first line's store completes on cycle 44 and the second line's on cycle 37 in steady state. The visible area begins at cycle 22.7, so the P0 byte applies from TIA pixel 64 and the P1 byte from pixel 43. A P0 object at X ≤ 56 sits entirely left of that point: on the first line of each pair the player still holds the *previous* pair row's byte. P0 therefore shifts one line down: its top line is blank, so only seven lines inside its eight-line window are lit — the shape is shifted, not truncated. From X ≥ 64 the byte is current and the skew disappears; X 57–63 splits the 8-pixel sprite for one scanline. P1 is written on the pair's second line, so it is always one line lower than P0; its earlier latch puts the thresholds at X ≤ 35 / X ≥ 43. At X ≥ 43 P1 still has eight lit lines, the last one one line below P0's window; at X ≤ 35 its top line is blank too, so it has seven. The two captures were selected outside both latch windows (all four objects measure 24–25 capture rows tall), but the skew is visible whenever an object moves through it.
:::

### Section 4: The Gallery's Frame and Its Status Cells

The frame is the Part 2–6 skeleton: 3 VSYNC lines, 37 VBLANK lines, 192 picture lines and 30 overscan lines, 262 in total. The picture is split into 8 status lines and 184 play lines:

| Zone | Visible lines | Lines | Start scanline | Kernel |
|---|---|---|---|---|
| Status | 0–7 | 8 | 37 (`BodyStart`) | latched playfield cells, one `WSYNC` per line |
| Play | 8–191 | 184 | 45 (`PlayStart`) | 92 rows × 2, the split skipdraw |
| — | — | **192** | 229 (`OverscanStart`) | the frame ends |

The status zone is a playfield strip repeated in both halves (`CTRLPF` bit 0 = 0, repeat). All the cells are the same height as the zone, eight lines. The layout uses one dark chunk between neighbours so two lit cells never merge into one bar:

| Chunks | Cell | Bits |
|---|---|---|
| 0–1 | the parity cell (chunk 0 = parity 0, chunk 1 = parity 1) | `PF0` bit 4 / bit 5 |
| 3–4 | object 0 | `PF0` bit 7 + `PF1` bit 7 |
| 6–7 | object 1 | `PF1` bits 5–4 |
| 9–10 | object 2 | `PF1` bits 2–1 |
| 12–13 | object 3 | `PF2` bits 1–0 |

`PF0`'s bits run backwards against the playfield chunks — bit 4 is chunk 0 and bit 7 is chunk 3 (Lesson 19). The masks are a two-entry table indexed by the parity:

| Parity | `PF0` | `PF1` | `PF2` | What the bar shows |
|---|---|---|---|---|
| 0 | `$90` | `$B0` | `$00` | chunk 0, object 0 (3–4), object 1 (6–7) |
| 1 | `$20` | `$06` | `$03` | chunk 1, object 2 (9–10), object 3 (12–13) |

The strip repeats from chunk 20, so the same three lit cells appear 480 capture pixels to the right. The cells are white (`$0E`) on the `$02` background. Because the masks are written in VBLANK, the first status line is already correct when the picture turns on; `PlayStart` clears the playfield before the beam reaches chunk 0 of the first play line.

One `HMOVE` per frame repositions both players. `SlotP0` and `SlotP1` each end by running the divide-by-15 routine for their object's X; the caller then does `STA WSYNC` and `STA HMOVE`. The `HMOVE` runs at the start of VBLANK line 8, so its eight-pixel left-edge blanking is invisible. No missile or ball motion value is ever written, so the `HMOVE` has nothing else to move.

### Section 5: What the Eye Sees, What a Still Shows

At 60 Hz the gallery looks like four ships: red, green, blue and gold, each moving one pixel per frame and bouncing at the edges. At 30 Hz each ship is drawn every other frame, so its motion is half as smooth, but the eye blends the two halves into four simultaneous objects.

A still capture cannot do that. Stella renders one frame at a time; `frame-a.png` is a parity-0 frame and `frame-b.png` is a parity-1 frame, and each shows exactly two objects. The status bar is the decoder: the 4-pixel parity mark tells you which half you are looking at, and the two lit 8-pixel cells name the two objects that are drawn.

This is not a flaw in the emulator or the capture — it is the mechanism. Any still of a flickering screen shows one half; only the running ROM shows the merged picture. That is why the lesson ships the committed ROM and the player: the two images are evidence of the two halves, and the player is the only artifact that can show the whole.

## The Code

### Building This Lesson

```bash
# every lesson ROM, including this one:
npm run roms

# or just this one:
acme -f plain -o build/lesson51.bin \
  lessons/part7-kernel-mastery/51-flicker-sprites/51-flicker-sprites.asm

stella build/lesson51.bin
```

The three exercise solutions sit beside the lesson source. Each is a complete 4,096-byte ROM:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part7-kernel-mastery/51-flicker-sprites/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part7-kernel-mastery/51-flicker-sprites/exercise-02-solution.asm
acme -f plain -o build/exercise-03.bin \
  lessons/part7-kernel-mastery/51-flicker-sprites/exercise-03-solution.asm
```

### Full Source

The complete annotated source is reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 51: Flicker Sprites — The Flicker Gallery — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; What this program does:
;   "the flicker gallery": four 8-line objects share the TIA's two players by
;   alternating two 30 Hz frames.  Each frame draws ONE pair: parity 0 draws
;   objects 0 and 1, parity 1 draws objects 2 and 3.  The eye integrates the
;   alternation into four objects; a still screenshot shows only one half.
;
;   Visible lines (the picture starts at scanline 37, so visible line 0 is
;   scanline 37):
;
;     visible   0-  7   the status zone   8 lines   parity + object cells
;     visible   8-191   the play zone   184 lines   92 rows x 2 (2-line kernel)
;                       ----------------
;                       8 + 184 = 192 visible lines
;
;   THE STATUS ZONE (8 lines).  A strip of playfield cells, repeated in both
;   halves of the screen (CTRLPF bit 0 = 0, repeat):
;
;     chunks 0-1   the parity cell: chunk 0 lit for parity 0,
;                                    chunk 1 lit for parity 1
;     chunks 3-4   object 0's cell      chunks 9-10   object 2's cell
;     chunks 6-7   object 1's cell      chunks 12-13  object 3's cell
;
;   Each cell is two playfield chunks (8 pixels) wide and all eight status
;   lines tall; one dark chunk separates neighbouring cells so two lit cells
;   never merge into a single bar.  The selected pair's cells are lit; the
;   other two are dark.  The cells are white ($0E) and the background $02.
;
;   THE PLAY ZONE (184 lines = 92 rows x 2).  Four objects, each with X, Y,
;   DirX, DirY, Color and Shape.  Every frame every object moves one pixel on
;   each axis and bounces at X 8..144 and Y 0..87.  Y is TOP-DOWN: row 0 is the
;   top of the play zone, row 91 the bottom, and an object's four shape bytes
;   cover rows Y..Y+3 (four 2-line rows = 8 scanlines).
;
;   THE SORT.  Within the selected pair the object with the LARGER Y is nearer
;   the bottom, so it is drawn on P0; its partner goes on P1.  The scheduler
;   copies the two objects' row and shape into the slots (ObjRow0/ObjShape0
;   and ObjRow1/ObjShape1) and their colours straight into COLUP0/COLUP1.
;
;   THE KERNEL.  A 2-line loop.  The first line draws the P0 object, the
;   second line draws the P1 object, each by the same per-row skipdraw test:
;
;     TYA              2   A = the kernel row
;     SEC              2
;     SBC ObjRow0      3   A = row - ObjRow0
;     CMP #4           2   in the four shape rows?
;     BCS NoSlot0      2/3  no: write 0 (blank the player)
;     STA Tmp          3   yes: A = 0..3, the byte inside the shape
;     LDA ObjShape0    3
;     ASL              2   shape x 4 ...
;     ASL              2
;     CLC              2
;     ADC Tmp          3   ... + the row offset = 0..15
;     TAX              2
;     LDA ShapeTable,X 4   the byte from the 4 x 4 shape table
;     JMP Store0       3
;   NoSlot0:
;     LDA #0           2
;   Store0:
;     STA GRP0         3
;     STA WSYNC        3
;
;   That is 35 cycles from TYA to the first cycle of STA GRP0 on the long
;   path; the store completes 3 cycles later.  Line 1's STA begins at cycle
;   42 (7 tail + 35) and completes at 44; line 2's begins at 35 and completes
;   at 37.  The STA WSYNC writes three cycles after the store (47 on line 1,
;   40 on line 2) and then waits out the rest of the line.  The short path is
;   14 cycles to the STA's first cycle and 3 to the write.  The loop tail
;   INY/CPY #92/BNE runs after line 2's WSYNC, at the top of the next pair:
;   7 cycles.  So line 1 costs 7 + 35 + 3 + 3 = 48 cycles of the 76-cycle
;   line and line 2 costs 35 + 3 + 3 = 41; a pair is 89 of the 152-cycle
;   pair.  Both lines are inside the budget; that is the reason the two
;   branchy skipdraws are split one per line instead of stacked on one.
;
;   WHERE THE BYTES LATCH.  The store completes on its last cycle: cycle 44 on
;   line 1 and cycle 37 on line 2.  The visible area starts at cycle 22.7, so
;   the P0 byte applies from TIA pixel 64 and the P1 byte from pixel 43.  An
;   object's 8 pixels start at its X.  A P0 object at X <= 56 is therefore
;   entirely left of the latch: its first line still displays the previous
;   pair row's byte, which is the same shape one row up - a one-scanline
;   downward shift, not a truncated shape (the top line is blank).  From X >= 64 the byte is current and the
;   skew disappears; X 57-63 splits the 8-pixel sprite for one scanline.
;   P1's earlier latch puts its thresholds at X <= 35 / X >= 43.  Both are
;   consequences of the split skipdraw and are documented, not hidden.
;
;   WHY FOUR BYTES ARE EIGHT LINES.  Each line writes only its own player, so
;   the byte written for row Y is not disturbed on the other line: the P0 byte
;   written on line 1 still displays on line 2, and the P1 byte written on
;   line 2 still displays on the next pair's line 1.  That latch persistence
;   is what turns four shape bytes into an 8-line object.
;
;   ONE HMOVE, IN VBLANK.  SlotP0 and SlotP1 each end by coarse-positioning
;   their player (the Lesson 26 divide-by-15 routine); the caller then does
;   one STA WSYNC and one STA HMOVE.  Set every RESxx and HMxx value first,
;   then strobe once.
;
;   THE AUTO-DEMO.  No input is needed: the four objects move and bounce by
;   themselves, so both parities appear within two frames and both capture
;   states are reachable.  A short beep (channel 0) sounds when an object
;   bounces.  There is no fire or SELECT action: this is a kernel lab.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, PlayStart 45, OverscanStart
;   229.  The picture is 8 status lines + 184 play lines = 192.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), PlayStart (45),
;   OverscanStart (229); Parity (A = the new parity, 0/1); DrawSlot0 /
;   DrawSlot1 (A = the object index drawn on P0 / P1); HmoveApply (the WSYNC
;   stall), HmoveDone (the store has executed); SkipWrite (A = the P0 shape
;   byte or 0), SkipWrite1 (A = the P1 shape byte or 0); KernelRow (Y = the
;   play row, 0..91).
;
; RAM map (+clean_start zeroes every byte):
;   $80-$83   ObjX      the four objects' left edges, 8..144
;   $84-$87   ObjY      the four objects' top rows, 0..87
;   $88-$8B   ObjDirX   0 = moving left, 1 = moving right
;   $8C-$8F   ObjDirY   0 = moving up, 1 = moving down
;   $90-$93   ObjColor  the four object colours
;   $94-$97   ObjShape  the four shape indices (0..3)
;   $98       ObjRow0   the P0 object's first kernel row
;   $99       ObjShape0 the P0 object's shape index
;   $9A       ObjRow1   the P1 object's first kernel row
;   $9B       ObjShape1 the P1 object's shape index
;   $9C       Flicker   the parity: 0 draws objects 0/1, 1 draws 2/3
;   $9D       BeepTimer frames of beep left
;   $9E       BeepPitch AUDF0 for the beep
;   $9F       free
;   $A0       Tmp       the kernel's one-byte row-offset scratch
;   $A1-$D7   free
;   $D8-$F7   free (the six-object exercise uses this range)
;   $F8-$FF   stack
;
; Build: acme -f plain -o build/lesson51.bin \
;        lessons/part7-kernel-mastery/51-flicker-sprites/51-flicker-sprites.asm
; Run:   stella build/lesson51.bin     (click the screen to hear the beep)
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

STATUS_LINES   = 8       ; visible 0-7: the status zone
PLAY_ROWS      = 92      ; visible 8-191: 92 rows x 2 = 184 lines

OBJECT_COUNT   = 4       ; four objects: two per parity
SHAPE_BYTES    = 4       ; four shape bytes = four 2-line rows = 8 scanlines
OBJ_MIN_X      = 8       ; the left limit (TIA X)
OBJ_MAX_X      = 144     ; the right limit (8 pixels wide)
OBJ_MIN_Y      = 0       ; the top play-zone row
OBJ_MAX_Y      = 87      ; the last first row: rows 87..90 end by play line 182; Y=88 clips P1

; --- the objects' power-on state --------------------------------------------
; Each pair is spread across the field so both flicker halves are clearly
; visible, and the two members of a pair differ in Y so the sort has work.
OBJ0_X         = 32
OBJ0_Y         = 16
OBJ1_X         = 120
OBJ1_Y         = 64
OBJ2_X         = 64
OBJ2_Y         = 40
OBJ3_X         = 112
OBJ3_Y         = 84

; --- the beep -----------------------------------------------------------------
BEEP_FRAMES    = 6
BEEP_PITCH     = $08

; --- colours ------------------------------------------------------------------
C_RED          = $42     ; object 0
C_GREEN        = $C8     ; object 1
C_BLUE         = $84     ; object 2
C_GOLD         = $1A     ; object 3
C_STATUS       = $0E     ; the status cells: white
C_BG           = $02     ; the background

; =============================================================================
; RAM ALLOCATION ($80-$A0; +clean_start zeroes every byte)
; =============================================================================
ObjX         = $80   ; 4 bytes: the objects' left edges, 8..144
ObjY         = $84   ; 4 bytes: the objects' top rows, 0..87
ObjDirX      = $88   ; 4 bytes: 0 = left, 1 = right
ObjDirY      = $8C   ; 4 bytes: 0 = up, 1 = down
ObjColor     = $90   ; 4 bytes: each object's colour
ObjShape     = $94   ; 4 bytes: each object's shape index, 0..3
ObjRow0      = $98   ; the P0 object's first kernel row
ObjShape0    = $99   ; the P0 object's shape index
ObjRow1      = $9A   ; the P1 object's first kernel row
ObjShape1    = $9B   ; the P1 object's shape index
Flicker      = $9C   ; the parity: 0 = objects 0/1, 1 = objects 2/3
BeepTimer    = $9D   ; frames of beep remaining
BeepPitch    = $9E   ; AUDF0 for the beep
Tmp          = $A0   ; the kernel's row-offset scratch (not persistent state)
;
; $A1-$D7 are free; $D8-$F7 are free (the six-object exercise uses them);
; $F8-$FF is the stack.  The call depth is one level (SlotP0/SlotP1).

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
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the four objects --------------------------------------------------------
; Y is top-down and the larger Y is nearer the bottom.  Objects 0 and 1 are
; the parity-0 pair; objects 2 and 3 are the parity-1 pair.
    LDA #OBJ0_X
    STA ObjX
    LDA #OBJ0_Y
    STA ObjY
    LDA #$01
    STA ObjDirX             ; object 0 moves right first
    STA ObjDirY             ; object 0 moves down first
    LDA #C_RED
    STA ObjColor
    LDA #$00
    STA ObjShape            ; shape 0: the arrowhead

    LDA #OBJ1_X
    STA ObjX+1
    LDA #OBJ1_Y
    STA ObjY+1
    LDA #$00
    STA ObjDirX+1           ; object 1 moves left first
    STA ObjDirY+1           ; object 1 moves up first
    LDA #C_GREEN
    STA ObjColor+1
    LDA #$01
    STA ObjShape+1          ; shape 1: the diamond

    LDA #OBJ2_X
    STA ObjX+2
    LDA #OBJ2_Y
    STA ObjY+2
    LDA #$01
    STA ObjDirX+2           ; object 2 moves right first
    LDA #$00
    STA ObjDirY+2           ; object 2 moves up first
    LDA #C_BLUE
    STA ObjColor+2
    LDA #$02
    STA ObjShape+2          ; shape 2: the cross

    LDA #OBJ3_X
    STA ObjX+3
    LDA #OBJ3_Y
    STA ObjY+3
    LDA #$00
    STA ObjDirX+3           ; object 3 moves left first
    LDA #$01
    STA ObjDirY+3           ; object 3 moves down first
    LDA #C_GOLD
    STA ObjColor+3
    LDA #$03
    STA ObjShape+3          ; shape 3: the bug

; --- the flicker scheduler's state ------------------------------------------
; Flicker starts at 1 so the first displayed frame is parity 0 (the EOR at the
; top of VBLANK turns 1 into 0).
    LDA #$01
    STA Flicker
    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #$00

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_BG
    STA COLUBK
    LDA #C_STATUS
    STA COLUPF
    LDA #$00
    STA CTRLPF              ; bit 0 = 0: the right half repeats the left
    STA NUSIZ0              ; one 8-pixel copy of each player
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    STA ENAM0
    STA ENAM1
    STA ENABL

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
; 1. THE BEEP'S CLOCK — the last beep frame writes silence
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0
BeepDone:

; -----------------------------------------------------------------------------
; 2. THE FOUR OBJECTS — one pixel per frame on each axis, bouncing at the edges
; -----------------------------------------------------------------------------
; X is the object index 0..3 and every field is a four-byte array, so the same
; code moves all four objects.  At a limit the direction flips and the object
; steps away on the same frame, and the bounce starts the beep.  X runs
; 8..144: 8 is the leftmost safe left edge and 144 keeps the 8-pixel player
; inside the 160-pixel field.  Y runs 0..87 so the four shape rows always fit
; inside the 92 play rows (87 + 3 = 90, rows 0..91).
    LDX #0
MoveLoop:
; --- the X axis --------------------------------------------------------------
    LDA ObjDirX,X
    BNE MoveRight
    LDA ObjX,X
    CMP #OBJ_MIN_X
    BEQ BounceRight
    DEC ObjX,X
    JMP XDone
BounceRight:
    LDA #$01
    STA ObjDirX,X
    INC ObjX,X              ; flip and step away in the same frame
    JSR BeepStart
    JMP XDone
MoveRight:
    LDA ObjX,X
    CMP #OBJ_MAX_X
    BEQ BounceLeft
    INC ObjX,X
    JMP XDone
BounceLeft:
    LDA #$00
    STA ObjDirX,X
    DEC ObjX,X
    JSR BeepStart
XDone:
; --- the Y axis --------------------------------------------------------------
    LDA ObjDirY,X
    BNE MoveDown
    LDA ObjY,X
    CMP #OBJ_MIN_Y
    BEQ BounceDown
    DEC ObjY,X
    JMP YDone
BounceDown:
    LDA #$01
    STA ObjDirY,X
    INC ObjY,X
    JSR BeepStart
    JMP YDone
MoveDown:
    LDA ObjY,X
    CMP #OBJ_MAX_Y
    BEQ BounceUp
    INC ObjY,X
    JMP YDone
BounceUp:
    LDA #$00
    STA ObjDirY,X
    DEC ObjY,X
    JSR BeepStart
YDone:
    INX
    CPX #OBJECT_COUNT
    BNE MoveLoop


; -----------------------------------------------------------------------------
; 3. THE FLICKER SCHEDULER — toggle the parity, select the pair, sort by Y
; -----------------------------------------------------------------------------
; The parity alternates every frame, so each object is drawn 30 times a second
; while the screen refreshes at 60.  The pair base is parity * 2: parity 0
; selects objects 0 and 1, parity 1 selects objects 2 and 3.
;
; Within the pair, Y is top-down, so the object with the LARGER Y is nearer the
; bottom.  That object goes on P0 (the first line of each kernel pair) and its
; partner on P1 (the second line).  The pair is two objects, so the "sort" is
; one compare; a game with more objects would sort the whole draw list by Y the
; same way.
    LDA Flicker
    EOR #$01                ; 0 <-> 1
Parity:                     ; checkpoint: A = the new parity (0/1)
    STA Flicker
    ASL                     ; parity * 2: the pair's first object index
    TAX
    LDA ObjY,X
    CMP ObjY+1,X            ; the pair's second object
    BCC SecondNearer        ; first Y < second Y: the second is nearer
    TXA                     ; the first object is the nearer
    JMP SlotSelect
SecondNearer:
    TXA
    CLC
    ADC #$01                ; the second object is the nearer
SlotSelect:
DrawSlot0:                  ; checkpoint: A = the object index drawn on P0
    PHA                     ; keep the P0 index across the slot copy
    JSR SlotP0              ; row/shape/colour + the coarse X for P0
    PLA
    EOR #$01                ; the partner in the pair (0<->1, 2<->3)
DrawSlot1:                  ; checkpoint: A = the object index drawn on P1
    JSR SlotP1              ; row/shape/colour + the coarse X for P1

; -----------------------------------------------------------------------------
; 4. ONE HMOVE — both coarse resets are set, then one strobe
; -----------------------------------------------------------------------------
; SlotP0 and SlotP1 each end inside the Lesson 26 divide-by-15 routine, so by
; now both RESP0/RESP1 and HMP0/HMP1 hold this frame's positions.  The WSYNC
; starts a fresh line and HMOVE applies both fine offsets in its HBLANK.  This
; is the only HMOVE in the frame.
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA WSYNC
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed

; -----------------------------------------------------------------------------
; 5. THE STATUS ZONE'S CELLS — a parity cell and four object cells
; -----------------------------------------------------------------------------
; The same 14-chunk strip appears in both halves (CTRLPF bit 0 = 0, repeat):
;
;   PF0 chunks 0-3:   parity cell (chunk 0 or 1) | gap | object 0 (chunks 3-4)
;   PF1 chunks 4-11:  object 0's second chunk | gap | object 1 (6-7) |
;                     gap | object 2 (9-10) | gap
;   PF2 chunks 12-19: object 3 (chunks 12-13)
;
; PF0's bits run backwards against the chunks: bit 4 is chunk 0 and bit 7 is
; chunk 3 (Lesson 19).  The two table entries are the two parities: the
; selected pair's cells are lit and the parity cell shows which half is on
; screen.  The cells are eight lines tall because the status zone is eight
; lines tall.
    LDX Flicker
    LDA StatusPF0,X
    STA PF0
    LDA StatusPF1,X
    STA PF1
    LDA StatusPF2,X
    STA PF2
    LDA #C_STATUS
    STA COLUPF
    LDA #$00
    STA GRP0                ; the players are blank in the status zone
    STA GRP1
    LDA #C_BG
    STA COLUBK

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE LINE 0-7: THE STATUS ZONE (8 lines)
; =============================================================================
; The masks were written in VBLANK, so the first status line is already
; correct.  Eight WSYNCs end lines 37..44 and release the CPU on PlayStart.
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDX #STATUS_LINES
StatusWait:
    STA WSYNC
    DEX
    BNE StatusWait

; =============================================================================
; VISIBLE LINE 8-191: THE PLAY ZONE (184 lines = 92 rows x 2)
; =============================================================================
; The status masks must not leak into the play area: clear the playfield before
; the beam reaches chunk 0 of the first play line.  Then the 2-line loop.
PlayStart:                  ; checkpoint: scanline 45, visible line 8
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #0

; The row loop is the course's top-down form: LDY #0, draw row Y, then
; INY / CPY #92 / BNE.  Y is both the row counter and the row being tested, so
; row 0 is the top of the play zone and row 91 is the bottom.
KernelRow:                  ; checkpoint: Y = 0..91, the play row
; --- line 1: the P0 object (the nearer one) ---------------------------------
    TYA
    SEC
    SBC ObjRow0
    CMP #SHAPE_BYTES
    BCS NoSlot0             ; above or below the shape: blank P0
    STA Tmp                 ; A = 0..3, the byte inside the shape
    LDA ObjShape0
    ASL                     ; shape x 4 ...
    ASL
    CLC
    ADC Tmp                 ; ... + the row offset = 0..15
    TAX
    LDA ShapeTable,X        ; the 4 x 4 shape table
    JMP Store0
NoSlot0:
    LDA #$00
Store0:
SkipWrite:                  ; checkpoint: A = the P0 shape byte or 0
    STA GRP0
    STA WSYNC               ; line 1 of the pair ends here
; --- line 2: the P1 object (the farther one) --------------------------------
    TYA
    SEC
    SBC ObjRow1
    CMP #SHAPE_BYTES
    BCS NoSlot1
    STA Tmp
    LDA ObjShape1
    ASL
    ASL
    CLC
    ADC Tmp
    TAX
    LDA ShapeTable,X
    JMP Store1
NoSlot1:
    LDA #$00
Store1:
SkipWrite1:                 ; checkpoint: A = the P1 shape byte or 0
    STA GRP1
    STA WSYNC               ; line 2 of the pair ends here
    INY                     ; the loop tail runs at the top of the next pair
    CPY #PLAY_ROWS
    BNE KernelRow
; 92 rows x 2 lines = visible 8-191.  The last WSYNC releases the CPU on
; scanline 229, the first overscan line.

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SlotP0 / SlotP1 — copy one object's draw state into a slot, then position it
; =============================================================================
; A = the object index (0..3).  The row and shape go to the slot the kernel
; reads; the colour goes straight to the player's colour register; the X goes
; through the Lesson 26 divide-by-15 dance and ends with a RESP strobe.  The
; caller's HMOVE applies the fine offset.  The tail JMP is deliberate: the
; SetCoarse routine's RTS returns to the caller of SlotP0/SlotP1.
SlotP0:
    TAX
    LDA ObjY,X
ObjRow0Read:                ; checkpoint: A = the value written to ObjRow0
    STA ObjRow0
    LDA ObjShape,X
ObjShape0Read:              ; checkpoint: A = the value written to ObjShape0
    STA ObjShape0
    LDA ObjColor,X
    STA COLUP0
    LDA ObjX,X
    CLC
    ADC #POS_BIAS
    JMP SetCoarseP0

SlotP1:
    TAX
    LDA ObjY,X
ObjRow1Read:                ; checkpoint: A = the value written to ObjRow1
    STA ObjRow1
    LDA ObjShape,X
ObjShape1Read:              ; checkpoint: A = the value written to ObjShape1
    STA ObjShape1
    LDA ObjColor,X
    STA COLUP1
    LDA ObjX,X
    CLC
    ADC #POS_BIAS
    JMP SetCoarseP1

; =============================================================================
; SetCoarseP0 / SetCoarseP1 — the Lesson 26 divide-by-15 positioning dance
; =============================================================================
; A = the desired left edge + POS_BIAS.  The first WSYNC starts a fresh line;
; the divide loop and the stores run on that line.  Each iteration of the loop
; is 5 cycles = 15 colour clocks, which is why dividing by 15 works.  The
; caller strobes HMOVE afterwards.
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
; THE STATUS ZONE'S MASKS — one entry per parity
; =============================================================================
; PF0 bit 4 = chunk 0 ... bit 7 = chunk 3; PF1 bit 7 = chunk 4 ... bit 0 =
; chunk 11; PF2 bit 0 = chunk 12 ... bit 7 = chunk 19.  Each object cell is
; two chunks, with one dark chunk between cells.
;
;   parity 0:  chunk 0 (parity) | object 0 (chunks 3-4) | object 1 (6-7)
;   parity 1:  chunk 1 (parity) | object 2 (chunks 9-10) | object 3 (12-13)
StatusPF0:
    !byte $90               ; parity 0: chunk 0 ($10) + object 0's chunk 3 ($80)
    !byte $20               ; parity 1: chunk 1
StatusPF1:
    !byte $B0               ; parity 0: object 0's chunk 4 ($80) + object 1 ($30)
    !byte $06               ; parity 1: object 2 at chunks 9-10
StatusPF2:
    !byte $00
    !byte $03               ; parity 1: object 3 at chunks 12-13

; =============================================================================
; THE SHAPE TABLE — four shapes x four bytes (16 bytes)
; =============================================================================
; Each byte is one 2-line kernel row, so a shape is four rows = 8 scanlines.
; The index is shape * 4 + (row - ObjRow), 0..15.  The table is page-aligned
; so the indexed load never crosses a page and the kernel ledger needs no
; page-cross allowance.
    !align 255, 0
ShapeTable:
    ; shape 0: an arrowhead
    !byte $18, $3C, $7E, $FF
    ; shape 1: a diamond
    !byte $18, $3C, $3C, $18
    ; shape 2: a cross
    !byte $5A, $FF, $FF, $5A
    ; shape 3: a bug
    !byte $5A, $FF, $A5, $5A

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
> `lessons/part7-kernel-mastery/51-flicker-sprites/51-flicker-sprites.asm`.

### Code Walkthrough

#### Step 1 — The frame skeleton and the two zone labels

```asm
StartFrame:                 ; scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; scanline 0
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    ; ... the beep, the motion, the scheduler, the HMOVE, the status masks ...
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

BodyStart:                  ; scanline 37, visible line 0
    LDX #STATUS_LINES
StatusWait:
    STA WSYNC
    DEX
    BNE StatusWait

PlayStart:                  ; scanline 45, visible line 8
    ; ... the 92-row kernel ...
```

Eight `WSYNC`s end lines 37–44 and release the CPU at scanline 45, so the play zone starts on time every frame. The play kernel's last `WSYNC` releases at scanline 229 (`OverscanStart`), and the 30-line overscan closes the 262-line frame.

#### Step 2 — VBLANK: the beep and the motion

Every object moves one pixel on each axis and bounces at the limits. `X` is the object index and every field is a four-byte array, so one loop moves all four:

```asm
    LDX #0
MoveLoop:
    LDA ObjDirX,X
    BNE MoveRight
    LDA ObjX,X
    CMP #OBJ_MIN_X
    BEQ BounceRight
    DEC ObjX,X
    JMP XDone
BounceRight:
    LDA #$01
    STA ObjDirX,X
    INC ObjX,X              ; flip and step away in the same frame
    JSR BeepStart
    JMP XDone
```

The same block repeats for Y. A bounce starts the beep (`AUDC0 = $0C`, `AUDF0 = BeepPitch`, `AUDV0 = $0A`) and the beep clock in VBLANK writes `AUDV0 = 0` after six frames. The limits are TIA X 8–144 and row Y 0–87: at Y = 87 the four shape rows end at row 90; row 90's last displayed line is play line 182 on P1 (one line lower than P0), one line inside the 184-line play zone. Y=88 would put P1's last line on play line 184, the first overscan line (scanline 229), where VBLANK turns on; that is why the bound is 87.

#### Step 3 — The flicker scheduler

```asm
    LDA Flicker
    EOR #$01                ; 0 <-> 1
Parity:
    STA Flicker
    ASL                     ; parity * 2: the pair's first object index
    TAX
    LDA ObjY,X
    CMP ObjY+1,X
    BCC SecondNearer
    TXA
    JMP SlotSelect
SecondNearer:
    TXA
    CLC
    ADC #$01
SlotSelect:
DrawSlot0:
    PHA
    JSR SlotP0
    PLA
    EOR #$01                ; the partner in the pair
DrawSlot1:
    JSR SlotP1
```

`SlotP0` copies the object's Y and shape into the slot, loads its colour into `COLUP0`, and ends by jumping into `SetCoarseP0` with `ObjX + POS_BIAS`. The tail jump is deliberate: the divide routine's `RTS` returns to the scheduler, not to another level of call. `SlotP1` is the same for the other player.

#### Step 4 — One HMOVE

```asm
HmoveApply:
    STA WSYNC
    STA HMOVE
HmoveDone:
```

Both coarse resets have already strobed `RESP0`/`RESP1` and set `HMP0`/`HMP1`; the `WSYNC` starts a fresh line and the `HMOVE` applies both fine offsets in its HBLANK. The state log puts the store at scanline 8 cycle 3, inside VBLANK. There is no second `HMOVE` in the frame.

#### Step 5 — The status cells

```asm
    LDX Flicker
    LDA StatusPF0,X
    STA PF0
    LDA StatusPF1,X
    STA PF1
    LDA StatusPF2,X
    STA PF2
    LDA #C_STATUS
    STA COLUPF
    LDA #$00
    STA GRP0
    STA GRP1
```

The two table entries are the two parities, and the players are blanked before the picture turns on — otherwise the last play row's `GRP0`/`GRP1` bytes would draw a stray sprite in the status bar. `PlayStart` then clears the playfield so the status cells do not run down the play area.

#### Step 6 — The 92-row skipdraw kernel

```asm
KernelRow:
    TYA
    SEC
    SBC ObjRow0
    CMP #SHAPE_BYTES
    BCS NoSlot0
    STA Tmp
    LDA ObjShape0
    ASL
    ASL
    CLC
    ADC Tmp
    TAX
    LDA ShapeTable,X
    JMP Store0
NoSlot0:
    LDA #$00
Store0:
SkipWrite:
    STA GRP0
    STA WSYNC
    ; ... the same test for ObjRow1 / ObjShape1 on GRP1 ...
    STA GRP1
    STA WSYNC
    INY
    CPY #PLAY_ROWS
    BNE KernelRow
```

The loop tail runs at the top of the next pair, after the second `WSYNC`, which is why line 1 costs 48 cycles and line 2 costs 41. `SkipWrite` and `SkipWrite1` sit on the two stores, so a breakpoint there reports the shape byte or 0 for every row.

#### Step 7 — Reading it back in Stella

Assemble with a symbol file and ask Stella for the checkpoints:

```bash
acme -f plain -l build/lesson51.sym -o build/lesson51.bin \
  lessons/part7-kernel-mastery/51-flicker-sprites/51-flicker-sprites.asm

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F1D7' \
  docs/public/roms/part7-kernel-mastery/51-flicker-sprites/51-flicker-sprites.bin
```

Run each checkpoint separately for a readable log. The addresses below are the ones this source produced.

### Checkpoints

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F099` | 259/3 | the first VSYNC line |
| `VblankStart` | `$F0A7` | 0/5 | the first VBLANK line |
| `Parity` | `$F125` | A = 0, 1, 0, 1 … | the new parity, every frame |
| `DrawSlot0` | `$F137` | A = 1, 3, 1, 3 … | the object index copied into P0 |
| `DrawSlot1` | `$F13E` | A = 0, 2, 0, 2 … | the object index copied into P1 |
| `HmoveApply` | `$F141` | 7/38 or 7/48 | the `WSYNC` before the `HMOVE` |
| `HmoveDone` | `$F145` | 8/3 | the `HMOVE` store in VBLANK |
| `BodyStart` | `$F16F` | 37/5 | visible line 0, the status zone |
| `PlayStart` | `$F176` | 45/4 | visible line 8, the play kernel |
| `KernelRow` | `$F180` | Y = 0..91 | the play row |
| `SkipWrite` | `$F19A` | A = the shape byte or 0 | the P0 store |
| `SkipWrite1` | `$F1B8` | A = the shape byte or 0 | the P1 store |
| `OverscanStart` | `$F1C1` | 229/6 | the first blank line after the picture |
| `ObjRow0Read` | `$F1D7` | A = the P0 row | the value written to `ObjRow0` |
| `ObjShape0Read` | `$F1DB` | A = the P0 shape | the value written to `ObjShape0` |
| `ObjRow1Read` | `$F1EC` | A = the P1 row | the value written to `ObjRow1` |
| `ObjShape1Read` | `$F1F0` | A = the P1 shape | the value written to `ObjShape1` |

`ObjRow0Read` and its three neighbours exist because `-dbg.logbreaks` logs registers, not RAM: each label sits where the value is in A, one instruction before the store. That is how the two slot pairs enter the state log.

## What You Should See

The picture is a dark screen with a white status strip across the top and, below it, **two** small ships — never four. The status strip shows a 4-pixel parity mark near the left edge and two 8-pixel object cells; the same strip repeats in the right half of the screen. The two ships move one pixel per frame and bounce off the edges of the play area.

![Stella running the Lesson 51 ROM in a parity-0 frame: a red arrowhead at TIA X=71 and a green diamond at TIA X=83, with the status bar's leftmost 4-pixel parity cell lit and two 8-pixel object cells lit in each half](/images/lesson51/frame-a.png)

*Parity 0: objects 0 and 1. The red arrowhead (object 0, first ink at TIA X=71) is the lower object, so it is nearer the bottom and takes P0; the green diamond (object 1, first ink at TIA X=83) is the farther object and takes P1. The status bar shows the parity cell at chunk 0 and the object 0 and object 1 cells at chunks 3–4 and 6–7, with the same strip repeated in the right half. The capture is a window capture of the committed ROM; the title bar reads `Stella 7.0: "51-flicker-sprites"`.*

<RomPlayer rom="/roms/part7-kernel-mastery/51-flicker-sprites/51-flicker-sprites.bin" title="Lesson 51 — Flicker Sprites" />

![Stella running the Lesson 51 ROM in a parity-1 frame: a blue cross at TIA X=92 and a gold bug at TIA X=84, with the status bar's second parity cell lit and two different 8-pixel object cells lit](/images/lesson51/frame-b.png)

*Parity 1: objects 2 and 3. The blue cross (object 2, first ink at TIA X=92) is the lower object, so it is nearer the bottom and takes P0; the gold bug (object 3, first ink at TIA X=84) is the farther object and takes P1. The parity cell is now chunk 1 and the lit cells are objects 2 and 3 at chunks 9–10 and 12–13. Click the player screen to start it: Javatari is muted until a user gesture.*

> **Capture method.** Both images are window captures of
> `docs/public/roms/part7-kernel-mastery/51-flicker-sprites/51-flicker-sprites.bin`
> in Stella 7.0. The pointer was parked at `(0, 0)` before the burst; the title bars read
> `Stella 7.0: "51-flicker-sprites"`. A flicker state cannot be aimed at by waiting: the
> parity changes every 1/60 s and a window capture takes much longer. Stella was launched
> on the committed ROM, a burst of 40 window captures was taken with the same `xwininfo`
> lookup the screenshot script uses, and each capture was classified by its object colours
> (red + green is parity 0, blue + gold is parity 1) and by its lit status cells. The two
> images are from that burst, unchanged apart from the window frame. The colours and the
> horizontal positions below are decoded from the captured pixels with
> `capture x = 25 + 6 × TIA X`; the vertical mapping is `capture y = 107 + 3.15 × visible
> line`.

The ROM needs no input: the four objects move and bounce by themselves, so both parities are on screen within two frames. Hold nothing — there is no controller action in this lab. The beep sounds when an object hits a wall, and Javatari starts muted until you click the screen.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
ROM=docs/public/roms/part7-kernel-mastery/51-flicker-sprites/51-flicker-sprites.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F125' $ROM   # Parity
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F137' $ROM   # DrawSlot0
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F13E' $ROM   # DrawSlot1
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1D7' $ROM   # ObjRow0Read
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F19A' $ROM   # SkipWrite
```

- **`$F099` (`StartFrame`)** is **259/3**, **`$F0A7` (`VblankStart`)** **0/5**, **`$F16F` (`BodyStart`)** **37/5**, **`$F176` (`PlayStart`)** **45/4** and **`$F1C1` (`OverscanStart`)** **229/6**: 3 + 37 + 192 + 30 = 262 lines, and the picture is 8 status + 184 play lines.
- **`$F125` (`Parity`)** reports A=0, 1, 0, 1 … on consecutive frames: the parity alternates every frame. A frame with a bounce in its VBLANK shifts the checkpoint later in the line (the beep's `JSR` costs cycles), but the value still alternates.
- **`$F137` (`DrawSlot0`)** reports A=1, 3, 1, 3 … and **`$F13E` (`DrawSlot1`)** A=0, 2, 0, 2 …: on parity 0 the pair is objects 0/1 and object 1 (Y=63 on frame 1) is nearer, so P0 gets 1 and P1 gets 0; on parity 1 the pair is 2/3 and object 3 (Y=86 by frame 2) is nearer, so P0 gets 3 and P1 gets 2.
- **`$F1D7` (`ObjRow0Read`)**, **`$F1DB` (`ObjShape0Read`)**, **`$F1EC` (`ObjRow1Read`)** and **`$F1F0` (`ObjShape1Read`)** report the live slot pairs: frame 1 is `(63, 1)` for P0 and `(17, 0)` for P1; frame 2 is `(86, 3)` and `(38, 2)`. The numbers change every frame because the objects move; the shapes follow the object, not the slot.
- **`$F19A` (`SkipWrite`)** reports A=0 on rows outside the P0 object (short path, cycle 21) and the four shape bytes inside it (long path, cycle 42). These are steady-state cycles: on the first play line, `PlayStart`'s setup replaces the loop tail, so its `SkipWrite` is at cycle 31 and its `GRP0` store completes at 54, still inside 76. On frame 1 the object is shape 1 at row 63, so scanlines 171/173/175/177 report `$18/$3C/$3C/$18` and the rows around them report 0 at cycle 21. **`$F1B8` (`SkipWrite1`)** does the same for P1 at cycle 35: frame 1's rows 17–20 report `$18/$3C/$7E/$FF` at scanlines 80/82/84/86.
- **`$F141` (`HmoveApply`)** is the `WSYNC` at 7/38 or 7/48 (the position changes with the players' X values, which change the divide loop's length), and **`$F145` (`HmoveDone`)** is **8/3** every frame: one `HMOVE`, in VBLANK.

The pixel checks decode the captures with the same mapping:

| Check | `frame-a.png` | `frame-b.png` | Expected |
|---|---|---|---|
| the parity cell | lit x=25–48 (chunk 0) | lit x=49–72 (chunk 1) | chunk 0 for parity 0, chunk 1 for parity 1 |
| the object cells | x=97–144 (chunks 3–4) and x=169–216 (chunks 6–7) | x=241–288 (chunks 9–10) and x=313–360 (chunks 12–13) | only the selected pair's cells are lit |
| the repeat | +480 px: x=505–528, 577–624, 649–696 | +480 px: x=529–552, 721–768, 793–840 | the same strip in both halves |
| the status rows | y=107–130 | y=107–130 | visible lines 0–7 |
| the status colour | `(234,234,233)` = `$0E` | `(234,234,233)` = `$0E` | white cells |
| the first object | red `(158,19,18)` = `$42`, x=451–498 (first ink at TIA X=71), y=479–503 | blue `(36,40,176)` = `$84`, x=577–624 (first ink at TIA X=92), y=549–572 | the P0 object, the nearer one, drawn on line 1 |
| the second object | green `(81,179,80)` = `$C8`, x=523–546 (first ink at TIA X=83), y=293–316 | gold `(205,205,52)` = `$1A`, x=529–576 (first ink at TIA X=84), y=501–525 | the P1 object, the farther one, drawn on line 2 (one line lower) |
| the object height | 25 and 24 capture rows | 24 and 25 capture rows | 8 scanlines (24–25 capture rows); both captures are outside the P0 and P1 latch-skew windows |
| the two-line rows | — | the blue cross shows 6/12/6 capture rows of 24/48/24 ink pixels | each shape byte is held for two scanlines (the latch persistence) |
| the background | `(63,63,62)` = `$02` | `(63,63,62)` = `$02` | the dark field |

The screenshots prove the visual state; the state log proves the values and the lines. Neither one alone is the whole claim. The one thing the screenshots cannot prove is the merged 60 Hz perception — that is the running ROM.

## Exercises

### Exercise 1: Reverse Priority

**Challenge:** draw the farther object of each parity pair (the smaller Y) on P0 instead of the nearer one. Everything else — the scheduler, the skipdraw, the status cells — stays the same.

**Hints:**
1. The compare is a single branch. Swap `BCC SecondNearer` for `BCS SecondFarther` so the first object is chosen when its Y is *smaller* than its partner's.
2. When the branch is not taken, the first object is the farther one, so `TXA` puts its index in A; the partner is still `EOR #$01`.
3. Add a `SortFirst` label where A holds the P0 index so the state log shows the reversed choice. A breakpoint at `SortFirst` reports A=0, 2, 0, 2 … on consecutive frames.
4. The status cells are unchanged: they show *which* objects are drawn, not which slot they went to.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `SortFirst` reports A=0, 2, 0, 2 … (the farther object), `DrawSlot0`/`DrawSlot1` report 0/1, 2/3, and the two captures now put the smaller-Y object on P0. The picture still shows two objects per frame; only the P0/P1 assignment changes, and with it the order in which the two lines draw them.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Three-Frame Flicker — Six Objects

**Challenge:** add two more objects (six total) and cycle the parity 0, 1, 2 instead of 0, 1. Each frame draws two objects, so each object now appears 20 times a second. Put the two extra objects in the free page at `$D8–$F7` and give the status bar six object cells.

**Hints:**
1. The first four objects keep the `$80–$9E` arrays. The extra two get six 2-byte arrays at `$D8–$E3` (`Obj4X`, `Obj4Y`, `Obj4DirX`, `Obj4DirY`, `Obj4Color`, `Obj4Shape`), with object 4 at index 0 and object 5 at index 1.
2. The 6502 has no zero-page,Y addressing for `LDA`/`STA`/`INC`/`DEC`, so index the extra arrays with X, not Y.
3. `Flicker` counts 0, 1, 2 and wraps. Parity 0 and 1 derive the pair base with `ASL`; parity 2 reads `Obj4Y`/`Obj4Y+1` directly. The partner rule is still `EOR #$01` (4 ↔ 5).
4. `SlotP0`/`SlotP1` branch on an index ≥ 4 and copy from the `$D8` arrays for the extra pair.
5. The status strip grows to 19 chunks (14 lit cell chunks across chunks 0–18): the parity cell at 0–1, then object cells at 2–3, 5–6, 8–9, 11–12, 14–15 and 17–18, each separated by one dark chunk. Chunk 19 stays dark so the repeated strip never touches object 5's cell. Object 4's cell is `PF2` bits 2–3 (`$0C`) and object 5's is `PF2` bits 5–6 (`$60`).
6. Parity 2 lights both parity chunks (`PF0 = $30`) so the two-chunk cell encodes three states: left = 0, right = 1, both = 2.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `Parity` reports 0, 1, 2, 0, …; `DrawSlot0` reports 1, 2, 4, … and `DrawSlot1` 0, 3, 5, …; six cells appear in the status strip and exactly two are lit per frame; the eye sees six objects at 20 Hz. The play zone is still 92 rows and the frame is still 262 lines.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Always-On Player *(Stretch Goal)*

**Challenge:** make the player's ship permanent. Object 0 is the player's ship and is drawn on P0 every frame; objects 1, 2 and 3 are three enemies that take turns on P1, one per frame. `AlwaysSlot` must report A=0 on every frame.

**Hints:**
1. The ship is object 0: copy it into the P0 slot with a constant `LDA #$00` before `AlwaysSlot`, with no sort.
2. The enemy is `Flicker + 1`: parity 0 → object 1, parity 1 → object 2, parity 2 → object 3. One `LDA Flicker; CLC; ADC #$01` and `DrawSlot1` has its index.
3. The status strip shows the parity cell at 0–1, a ship cell at 3–4 that is lit in all three entries, and the three enemy cells at 6–7, 9–10 and 12–13.
4. The kernel does not change: P0 is the first line of every pair, P1 the second. Each written byte stays latched on its player through the pair's second line, so the ship and the enemy are both 8-line objects; the enemy changes which object it is on the next frame.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `AlwaysSlot` reports A=0 every frame; `DrawSlot1` reports 1, 2, 3, 1, …; the status bar shows the ship cell lit on every frame and one enemy cell rotating; the ship never flickers. Compare the two halves of the P0 object with the P1 object in the state log: the P0 slot pair is the same object on every frame, the P1 slot pair changes.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **Flicker trades time for objects.** Two players draw four objects by alternating two 30 Hz frames: parity 0 draws objects 0/1, parity 1 draws 2/3, and the eye merges the halves at 60 Hz.
- ✅ **The scheduler is a parity, a pair base and a compare.** `Flicker` toggles, `ASL` gives the pair base, and one `CMP` puts the larger Y (the nearer object) on P0 and its partner (`EOR #$01`) on P1.
- ✅ **Skipdraw needs no strips.** Each row runs `row - ObjRow`, compares against 4, and only inside the shape computes `shape * 4 + offset` into a 16-byte table. The state is 31 bytes, not four 92-byte strips.
- ✅ **Two branchy tests need two lines.** The long path is 35 cycles, so line 1 costs 48 and line 2 costs 41 — 89 of the 152-cycle pair. Stacking both tests on one line would exceed 76 cycles.
- ✅ **The latch has a cost, and it is measurable.** The P0 store completes on cycle 44 (pixel 64) and the P1 store on cycle 37 (pixel 43). An object left of the latch reads the previous pair row on that scanline: P0 shifts one line (seven lit lines inside the window, top blank); P1 is already one line lower, and at X ≤ 35 it shifts one more, so its last line can sit one line below the nominal window. The shape is shifted, not truncated.
- ✅ **The status cells decode the illusion.** A still image shows one half of a flicker; the parity cell and the two lit object cells say which half, and the same strip repeats in both halves of the screen.
- ✅ **One HMOVE, in VBLANK.** Two coarse resets set every `RESxx`/`HMxx` value first; one `WSYNC` and one `HMOVE` apply both fine offsets at scanline 8 cycle 3.

## What's Next

The gallery moves objects one pixel at a time, but its world is fixed: the playfield is empty and nothing scrolls. [Lesson 52: Fine Scrolling — Smooth Movement](/part7-kernel-mastery/52-fine-scrolling) turns the kernel around: a 1-line loop that scrolls three 256-byte playfield planes one line per frame through "the tunnel", and a 16-line ship that moves one pixel at a time with the divide-by-15 dance — the 40-cycle line, the 4-pixel playfield against the 1-pixel sprite, and the reason a 3-byte reflected playfield cannot snake sideways.
