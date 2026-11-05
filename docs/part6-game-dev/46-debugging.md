---
title: "Lesson 46: Debugging — Finding and Fixing Bugs"
description: "A debug lab with three classic 2600 failures — a sticky collision latch, a WSYNC-first frame that grows to 263 lines, and a one-line sprite offset — plus the Stella breakpoints, watches, and state logs that find each one."
prev:
  text: "Lesson 45: Memory Management — 128 Bytes of Creativity"
  link: "/part6-game-dev/45-memory-management"
next:
  text: "Lesson 47: Development Tools & Workflow"
  link: "/part6-game-dev/47-dev-tools-workflow"
---

# Lesson 46: Debugging — Finding and Fixing Bugs

> **Part 6: Game Development** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 02 (the Stella debugger), Lesson 17 (cycle counting), Lesson 18 (mid-line TIA writes), Lesson 26 (divide-by-15 positioning), Lesson 28 (the one-`HMOVE` rule), Lesson 29 (the ball), Lesson 38 (collision latches), Lesson 41 (state flow), Lesson 45 (the RAM map)
> **You will learn:** how to recognise a sticky collision latch and clear it with `CXCLR`; how a WSYNC-first kernel spends one extra scanline and turns a 262-line frame into 263; how a one-line sprite offset hides between the game logic and the drawn row; how to read the Stella breakpoint columns (frame, scanline, cycle, registers); how to turn a ROM into a state log with `-dbg.logbreaks`; how to separate what a screenshot proves from what the log proves
> **You will build:** "the debug lab" — a 4,096-byte ROM with three selectable bugs, a mode/bug status row, a wall, two players, a ball, a collision band, a two-byte beep, and a deterministic auto-demo; plus three exercise solutions that fix each bug

## Introduction

Lesson 45 made the 128-byte budget visible. The map showed which bytes the plan had spent, the
timer packed two counters into one byte, and an ACME `!if` refused to let a variable touch the
stack. The program was correct because the plan was correct — and the picture let you check the
plan every time you ran it.

This lesson is the other half of that discipline. A 2600 game has no operating system, no
`console.log`, and no exception trace. When it goes wrong it keeps drawing frames at sixty per
second, and the only evidence is the picture and the values you can stop the CPU to read. The
companion program `46-debugging.asm` is a **debug lab**: one small scene with three classic
failures hidden behind a mode selector. Press fire to switch between the faulty and fixed paths,
and use the joystick to choose which failure you are looking at.

The three failures are the ones that cost the most time in a real project. **Bug 0** is a
collision latch that is read but never cleared, so the red band stays lit after the player has
walked away. **Bug 1** is a kernel written WSYNC-first: the first `STA WSYNC` throws away a
visible line, the frame grows to 263 lines, and the picture sits one line low. The frame rate
is about 15,734 / 263 ≈ 59.8 Hz, one line outside the 262-line contract.
**Bug 2** is an off-by-one sprite row: the game logic says `PlayerY = 140`, but the drawn sprite
starts at 141, so the row you see and the row the P0-ball check uses disagree. Each bug has a
checkpoint, a symptom, and a one-line fix. The exercises make you apply the fixes.

::: details TypeScript Equivalent

A debug lab is a state machine with a mode selector and a fault flag. The shape transfers; the
debugging does not:

```typescript
type Mode = "sticky" | "frame" | "offByOne";

class DebugLab {
  mode: Mode = "sticky";
  bugOn = true;                 // true = the faulty path

  toggleBug(): void {
    this.bugOn = !this.bugOn;   // the fire button
  }

  select(mode: Mode): void {
    this.mode = mode;
    this.bugOn = true;          // selecting a bug shows that bug
  }

  // The real ROM does not have a "debugger" object. This is the shape of
  // the three checkpoints the lesson stops at:
  step(): void {
    if (this.mode === "sticky" && this.bugOn) {
      // the latch is read but never cleared
    } else {
      clearLatches();           // the fixed path
    }
  }
}

function clearLatches(): void {
  // On the 2600 this is a single strobe: STA CXCLR.
}
```

The analogy breaks in four places. There is no runtime that can pause the program: the debugger
is an emulator feature, and `-break '$F131'` stops the 6507 at an address, not at a source line.
A "frame" is not a tick in a loop; it is exactly 262 scanlines, and one extra `WSYNC` makes it
263. A latch is not a boolean in a variable: `CXP0FB` is a TIA register that stays set until a
write to `CXCLR`, and the read describes the previous visible frame. And the off-by-one bug is
not a wrong comparison in a model — it is a `GRP0` store that happens one scanline later than the
game logic believes.

:::

## Theory

### Section 1: Three Bugs, Three Symptoms

The lab's three modes are not three random mistakes. They are the three failure families that
show up again and again in 2600 code:

| Mode | Failure | What you see | The checkpoint that proves it | The fix |
|---|---|---|---|---|
| 0 | Sticky collision | the red band stays lit after P0 leaves the wall | `ReadCX` (A = `CXP0FB`), `CXClear` | write `CXCLR` after the read |
| 1 | Frame overrun | the picture is one line low; the frame is 263 lines (~59.8 Hz) | `OverscanStart` (230), `StartFrame` (260) | work-first: write the line, then `WSYNC` |
| 2 | Off-by-one row | P0 is drawn one line below `PlayerY` | `PlayerY` (140), `P0RowFixed` (scanline 177) vs `P0RowBug` (178) | draw P0's first row on `PlayerY` |

Each mode has a **fixed path** behind `BugOn = 0`. The fixed paths are the reference
implementations; the buggy paths are intentionally wrong and marked `BUG:` in the source. The
point of the lesson is not that the fixes are hard — they are one line each. The point is the
route from a symptom to the value that causes it.

::: tip A screenshot is not a proof of logic
A screenshot proves the monitor state: the band is red, the cell is green, the sprite is one line
low. It does not prove *why*. The state log proves the value at a labelled checkpoint, and the
static ledger proves the frame arithmetic. This lesson uses all three, and the "What You Should
See" section says which claim belongs to which kind of evidence.
:::

### Section 2: Sticky Collision Latches

The TIA has eight collision registers. The one this lesson uses is `CXP0FB` at `$02`:

| Bit | Pair | What sets it |
|---|---|---|
| 7 | P0 – playfield | any drawn P0 pixel overlaps a playfield pixel |
| 6 | P0 – ball | any drawn P0 pixel overlaps a ball pixel |

The bits are **latches**, not levels. Once a pair touches, the bit stays set until the program
writes to `CXCLR` (`$2C`). That is deliberate: the TIA cannot interrupt the CPU, so it leaves a
sticky note that the program reads once per frame. The catch is that the note is *history*: if
you never clear it, it stays set forever.

The correct shape is a read in VBLANK followed by a clear:

```asm
    LDA CXP0FB
ReadCX:                     ; checkpoint: A = CXP0FB
    AND #$80                ; bit 7 is P0-playfield; bit 6 is P0-ball
    STA CollisionBit
    LDA #$00
    STA CXCLR
CXClear:                    ; checkpoint: the latches are cleared
```

Two details matter. First, the read is in VBLANK, so it describes the **previous visible frame** —
the collision has already happened by the time you see the bit. The display therefore reacts one
frame late, and the lesson states that latency instead of hiding it. Second, `CXCLR` clears all
eight latches at once. There is no per-pair clear, so every collision consumer in the program
shares one strobe.

In mode 0's buggy path the `CXCLR` store is skipped. The latch sets when P0 first touches the
wall, and it never clears. The red band is drawn from `CollisionBit`, so it stays lit even after
P0 has moved back to X=88. The fixed path writes `CXCLR` every frame, so the next frame's read
is the current picture; the band goes dark one frame after separation.

::: tip The ball bit is not the wall bit
`CXP0FB` bit 6 sets when P0 crosses the ball at X=80. The code masks with `#$80`, so the ball
never lights the collision band. During the auto-demo's sweep the raw register shows `$42` (the
ball bit) and then `$C2` (the wall and ball bits); the state log in the next section shows both.
Masks are part of the debugging story: a raw read of `$C2` does not mean the wall is still
touching if you only care about bit 7.
:::

### Section 3: The 263-Line Frame

An NTSC frame in this course is built from four counts:

```
3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262 scanlines
```

`StartFrame` is the first VSYNC line, scanline 259. `VblankStart` is line 0. `BodyStart` is line
37, cycle 5. `OverscanStart` is line 229, cycle 7. Those four numbers are the frame's signature,
and any extra or missing line moves them.

A **work-first** kernel writes the line's registers and then waits for the line to end:

```asm
BodyStart:
    LDA #C_GOLD
    STA COLUPF
    LDA ModePF0
    STA PF0
    ...
    LDY #8
ModeRow:
    STA WSYNC
    DEY
    BNE ModeRow
```

`BodyStart` is already line 37 cycle 5. The stores finish before the visible part of line 37,
so line 37 shows the mode row. The eight `WSYNC`s cover lines 37–44, and the next zone starts on line 45.
Every zone is counted the same way, and the last one returns at line 229.

A **WSYNC-first** kernel starts each line by waiting:

```asm
    STA WSYNC               ; wait for the end of the line we are on
    LDA #C_GOLD             ; now write the *next* line
    STA COLUPF
    ...
```

If you put that first `WSYNC` at `BodyStart`, the CPU waits for the end of line 37 before writing
anything. The mode row's first line is lost; every later zone starts and ends one line late; the
last zone returns at line 230. The frame is now 263 lines: 3 + 37 + 193 + 30, a frame rate of
about 15,734 / 263 ≈ 59.8 Hz. The picture is one line low and the 262-line contract is broken.
Whether a particular television loses vertical hold is a physical-TV behaviour we did not
verify; the debugger's scanline counter is the evidence: `OverscanStart` reports 230 and
`StartFrame` reports 260. (The 262-line NTSC frame is the standard this course targets; the
263-line rate is derived from the standard line rate, not measured on hardware.)

The lesson's bug is the single leading `WSYNC`, because that is the smallest change that produces
the real symptom. A full WSYNC-first rewrite of every zone has the same one-line effect on the
frame and a slightly different effect on the zone contents; the checkpoint that matters is the
same.

::: tip Why the first line is the expensive one
`BodyStart` is not the start of the scanline; it is cycle 5 of line 37, after `+wait_timer`'s
final `WSYNC` and the `STA VBLANK`. The beam is already racing through the blanking interval. A
`WSYNC` there does not "align" the line; it throws the line away and resumes at cycle 0 of line
38. Work-first is the habit that keeps the first line's writes on the first line.
:::

### Section 4: The Off-by-One Sprite Row

The TIA has no collision box. A collision is between **drawn pixels**, and the sprite's vertical
position is whatever scanline its `GRP` register is set on. The game logic, on the other hand,
uses a byte. In this lesson that byte is `PlayerY = 140`.

The P0 zone is sixteen lines. In the fixed path `GRP0` is set at the top of the zone, before the
visible part of line 140, and stays set through line 155. In the buggy path `GRP0` stays zero for
line 140 and is set at cycle 0 of line 141; the sprite is still sixteen rows, 141–155 plus the
extra line 156 that the lower wall gives back. `PlayerY` remains 140. The drawn top row and the
game-logic row differ by one scanline.

Why does that matter if the P0–ball check still returns the same boolean? Because the check is a
**software** box test, not a TIA latch:

```asm
; Y overlap: PlayerY < BallY+8 AND BallY < PlayerY+16
    LDA PlayerY
    CMP #(BALL_Y + 8)
    BCS BallCheckDone
    CLC
    ADC #15
    CMP #BALL_Y
    BCC BallCheckDone
```

The ball is eight rows at Y=140–147. With P0 at 140–155 the boxes overlap for eight rows; with
P0 at 141–156 they still overlap for seven. The boolean does not flip. What flips is the
*correspondence* between the variable and the picture: a reader who trusts `PlayerY` will look at
row 140 and see the ball alone, and a later feature that uses the top row (a head hit, a ladder,
a platform edge) will be wrong by one line. That is exactly the kind of bug a debugger finds and
a screenshot alone does not: the picture looks plausible, and the variable looks plausible, but
they do not agree.

The lab makes the disagreement measurable. `P0RowFixed` is the label on the fixed path's first
`GRP0` store; a breakpoint there reports scanline 177 (visible 140). `P0RowBug` is the label after
the line-141 store; it reports scanline 178 (visible 141). In the buggy path `P0RowFixed` never
fires; in the fixed path it fires every frame. `PlayerYRead` reports A=`$8C` (140) in both. The
state log is the proof; the one-line picture difference is the symptom.

### Section 5: The Lab's Screen

The screen is 192 visible lines. The status row is visible 0–15; the play area is 16–191. The
playfield is reflected (`CTRLPF` bit 0), so every cell and wall appears in both halves.

| Visible | Content | Position / colour |
|---|---|---|
| 0–7 | mode row | three cells, each 2 chunks (8 px) wide: mode 0 at X=8–15 (`PF0=$C0`), mode 1 at X=16–23 (`PF1=$C0`), mode 2 at X=24–31 (`PF1=$30`); the selected cell is gold `$1A`, the others dark; mirror at X=128–151 |
| 8–15 | bug/fix cell | X=8–15 (`PF0=$C0`); red `$42` when `BugOn=1`, green `$C8` when `BugOn=0`; mirror at X=144–151 |
| 16–39 | top of the play area | gold edge wall at X=0–15 and X=144–159 |
| 40–55 | P1 | 16 rows at X=80–87, green `$C8` |
| 56–139 | middle of the play area | gold edge wall |
| 140–155 | P0 | 16 rows at X=PlayerX..PlayerX+7, red `$42` |
| 140–147 | ball | 8 rows at X=80–83, gold (the playfield colour); the ball is four pixels wide |
| 156–175 | lower play area | gold edge wall |
| 176–183 | collision band | full-width playfield bar; red `$42` when `CollisionBit` is set, background `$02` when clear |
| 184–191 | background | `$02` |

The wall is present on every play-area line 16–175; the table lists the object rows separately
because that is where the action is. The wall is 16 pixels wide at each edge, and P0's left limit
is X=8, so P0 can drive deep into the left wall. The ball is four TIA pixels wide (`CTRLPF` bits
4–5 = `10`), which makes it visible at the capture scale; a one-pixel ball would be a thin line.

The zones total 8 + 8 + 24 + 16 + 84 + 16 + 20 + 8 + 8 = 192 lines. `OverscanStart` is 229 in
the fixed paths and 230 in the mode-1 buggy path.

### Section 6: Controls, the Status Row, and the Auto-Demo

`ModeVal` (`$80`) holds 0, 1, or 2. `BugOn` (`$81`) is 1 for the faulty path and 0 for the fixed
path. Fire toggles `BugOn`; joystick left and right select the previous and next mode, wrapping
in both directions. The status row makes the state visible: the selected mode cell is gold, and
the bug/fix cell is red for the buggy path and green for the fixed path.

Two small startup rules keep the lab deterministic:

1. The first eight frames ignore the fire edge while the console settles. A **held direction** is
   treated as a menu selection, not a fire press; a lone held fire becomes one edge when the
   gate opens. Stella parses the hold value letter by letter, so the single letters `R`, `L`,
   and `F` are unambiguous (a longer value such as `LEFT` also contains `F`).
2. Selecting a mode re-arms the bug (`BugOn=1`). The selector is a *bug* selector: when you
   choose mode 1, you want to see mode 1's failure. Fire then flips to the fixed path.

The auto-demo is a 410-frame phase cycle driven by `DemoPhase` and `DemoTimer`: 408
movement/hold frames plus the two boundary frames that detect the end of phases 0 and 2.

| Phase | Frames | PlayerX |
|---|---|---|
| 0 | 80 | walks left from 88 to 8; it passes the ball at 80 and reaches the wall contact around frame 73 (X=15) |
| 1 | 8 | holds X=8 |
| 2 | 80 | walks right from 8 to 88, passing the ball again |
| 3 | 240 | holds X=88, the long settled window used for the screenshots |

At 60 frames per second the cycle is about 6.8 seconds. The 5-second capture used below lands in
phase 3: P0 is at X=88, the wall contact happened about 3.5 seconds earlier, and the sticky latch
(in the buggy path) is still set. The demo never changes `ModeVal` or `BugOn`, so the captures
show the defaults: mode 0 and `BugOn=1`.

### Section 7: The Debugger Workflow

Stella's debugger is the tool from Lesson 02. The command-line form used in this lesson adds a
breakpoint and a log:

```bash
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F131' \
  docs/public/roms/part6-game-dev/46-debugging/46-debugging.bin
```

`-dbg.logbreaks 1` logs each breakpoint and continues instead of opening the debugger.
`-dbg.logtrace 0` (optional) keeps the instruction trace out of the output. `-logtoconsole 1`
prints to the terminal. Stella keeps one `-break` per run, so run one checkpoint at a time.

Each log line has the columns the lesson uses:

```
Trigger:  Frame Scn Cy Pxl | PS       A  X  Y  SP | Addr Code Disasm
BP:           9   0 70 142 | nv-BdIZC 00 00 00 ff |
```

| Column | Meaning |
|---|---|
| `Frame` | the frame counter; the power-on partial frame is 0, and the first complete frame is 1 |
| `Scn` | the scanline within the frame (0–261, or 0–262 in the bug) |
| `Cy` | the CPU cycle within the scanline |
| `Pxl` | the pixel/colour-clock column |
| `PS` | the processor flags (`N V - B D I Z C`) |
| `A X Y SP` | the registers; `A` is the value the checkpoint reports |

To use a label name instead of an address, assemble with a symbol file:

```bash
acme -f plain -l build/lesson46.sym -o build/lesson46.bin \
  lessons/part6-game-dev/46-debugging/46-debugging.asm
```

The `.sym` file is a text table. The examples in the next section use the addresses from that
file. `-holdjoy0 R` selects mode 1, `-holdjoy0 L` selects mode 2 (the mode-0 left edge
wraps), and `-holdjoy0 F` holds fire so the startup gate reports one `BugToggle`.

::: tip The TIA and RAM watches
The breakpoint log gives you the registers. The debugger's TIA panel shows the live `COLUP0`,
`COLUP1`, `COLUPF`, `GRP0`, `GRP1`, `ENABL`, `PF0`–`PF2`, and collision registers; the RAM panel
shows `$80–$FF`. The bytes to watch in this lesson are `ModeVal` `$80`, `BugOn` `$81`, `PlayerX`
`$82`, `PlayerY` `$83`, `CollisionBit` `$84`, `BallHit` `$85`, `DemoPhase` `$8E`, and `P0Delay`
`$96`. `CXP0FB` is a read register at `$02`; it does not appear as a stored value.
:::

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson46.bin lessons/part6-game-dev/46-debugging/46-debugging.asm
stella build/lesson46.bin
```

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 46: Debugging — Finding and Fixing Bugs — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; What this program does:
;   "the debug lab": a small scene with three objects and three selectable
;   bugs.  Mode 0 is a sticky collision latch, mode 1 is a kernel that starts
;   one line late and grows the frame to 263 lines, and mode 2 is an
;   off-by-one sprite row.  BugOn = 1 selects the faulty path; BugOn = 0
;   selects the fixed path.  Fire toggles BugOn; joystick left/right selects
;   the mode.
;
; The screen (192 visible lines, CTRLPF=$21: reflect + a 4-pixel ball):
;   visible 0-7     mode row: three 8-line cells, each two playfield chunks
;                   (8 pixels) wide, one per mode.  The selected mode lights
;                   its cell gold; the other two stay dark.  The cells are
;                   at X=8-15 (mode 0, PF0=$C0), X=16-23 (mode 1, PF1=$C0)
;                   and X=24-31 (mode 2, PF1=$30).  CTRLPF mirrors them at
;                   X=128-151, so each half has the three cells.
;   visible 8-15    bug/fix row: one 8-line cell at X=8-15 (PF0=$C0).  Red
;                   $42 means BugOn=1; green $C8 means BugOn=0.  The mirror
;                   copy is at X=144-151.
;   visible 16-39   top play area: the gold edge wall only.
;   visible 40-55   P1: 16 rows at X=80, green.
;   visible 56-139  middle play area: the gold edge wall only.
;   visible 140-155 P0: 16 rows at PlayerX, red.  In mode 2's buggy path P0
;                   starts on visible 141 instead, one line below PlayerY.
;   visible 140-147 the ball: 8 rows at X=80, gold (COLUPF).  It shares the
;                   top eight rows of P0, so a one-line sprite shift is
;                   visible against the ball's fixed row.
;   visible 156-175 lower play area: the gold edge wall only.
;   visible 176-183 the collision band: eight lines of full-width playfield.
;                   Red $42 when the P0-playfield latch is set; background
;                   $02 when it is clear.
;   visible 184-191 background.
;   The zones total 8+8+24+16+84+16+20+8+8 = 192 lines.  OverscanStart is
;   scanline 229 in the fixed paths and 230 in the mode-1 buggy path.
;
; The wall:
;   PF0=$F0 lights chunks 0-3 (X=0-15) and, with CTRLPF reflect, X=144-159.
;   P0 can reach X=8, so it overlaps the left wall.  CXP0FB bit 7 is the
;   P0-playfield latch; bit 6 is the P0-ball latch and is masked out.
;
; The three bugs:
;   0  STICKY COLLISION (ModeVal=0, BugOn=1)
;      The VBLANK code reads CXP0FB and stores bit 7, but skips the CXCLR
;      strobe.  The TIA's collision latches are sticky: once P0 touches the
;      wall, the latch - and therefore the red band - stays set even after
;      P0 moves away.  The fixed path writes CXCLR after the read, so the
;      next frame reads the current picture.  The read is one frame old by
;      construction (the latches describe the previous visible frame).
;   1  FRAME OVERRUN (ModeVal=1, BugOn=1)
;      BodyStart inserts STA WSYNC before the first line's writes, the
;      classic WSYNC-first habit.  BodyStart is already the start of
;      scanline 37, so that WSYNC throws the line away; every zone then
;      starts and ends one line late.  OverscanStart moves from 229 to 230
;      and the frame grows from 262 to 263 lines.  The fixed path is
;      work-first: write the line, then WSYNC.
;   2  OFF-BY-ONE SPRITE ROW (ModeVal=2, BugOn=1)
;      The P0 zone keeps GRP0 blank for its first line, so the drawn sprite
;      starts at PlayerY+1.  PlayerY itself stays 140 and the P0-ball check
;      keeps using PlayerY, so the game-logic row and the drawn row disagree
;      by one line.  The fixed path draws the first row on PlayerY.  The
;      lower wall loses one line in the bug path, so the frame length does
;      not change.
;
; The controls:
;   Fire toggles BugOn.  Joystick right cycles 0 -> 1 -> 2 -> 0; left
;   cycles the other way (0 -> 2 -> 1 -> 0).  Selecting a mode re-arms
;   BugOn=1 so the chosen bug is visible.  Both actions beep.  The first
;   eight frames ignore the fire line while the console settles; a held
;   direction counts as a menu selection, not a fire press (Stella parses
;   the hold value letter by letter, so a value such as LEFT also contains
;   F).  The joystick also moves P0; holding a direction cancels the
;   auto-demo and holds the current X for DEMO_HOLD frames.
;
; The auto-demo (so bug-sticky/fix-sticky captures are deterministic):
;   With no joystick input, PlayerX follows a 410-frame phase cycle: 408
;   movement/hold frames plus the two boundary frames that detect the end
;   of phases 0 and 2.
;     phase 0  80 frames: move left from X=88 to X=8 (the wall contact is
;              around frame 73, when X reaches 15)
;     phase 1   8 frames: hold X=8
;     phase 2  80 frames: move right from X=8 to X=88 (passing the ball at
;              X=80 on the way)
;     phase 3 240 frames: hold X=88
;   The cycle then restarts at X=88.  At 60 frames per second, phase 3 is the
;   long settled window used for the screenshots: the buggy latch has been
;   set by the contact, P0 is far from the wall, and the fixed path's band is
;   dark.  The demo never changes ModeVal or BugOn, so the captures show the
;   defaults: mode 0 and BugOn=1.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259 fixed / 260 bug), VblankStart (0), FireRead (A = INPT4),
;   LeftRead (A = SWCHA), Mode (A = ModeVal, read every frame), BugToggle
;   (A = the new BugOn), ReadCX (A = CXP0FB), CXClear (the CXCLR strobe;
;   absent in the mode-0 bug), P0BallCheck (A = BallHit), PlayerXRead (A =
;   PlayerX), DemoPhaseRead (A = the demo phase), P0DelayRead (A = P0Delay),
;   PlayerYRead (A = 140), P0RowFixed (the fixed path's first GRP0 store) /
;   P0RowBug (the line-141 store), BodyStart (37), HmoveApply (the WSYNC
;   stall), HmoveDone (the HMOVE store), OverscanStart (229 fixed / 230 bug).
;   ModeVal is $80, BugOn $81, PlayerX $82, PlayerY $83, CollisionBit $84,
;   BallHit $85.  The full RAM map is in the allocation block below.
;
; Build: acme -f plain -o build/lesson46.bin \
;        lessons/part6-game-dev/46-debugging/46-debugging.asm
; Run:   stella build/lesson46.bin     (click the screen to hear the beep)
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

PLAYER_Y       = 140     ; P0's first visible row (game logic)
PLAYER_START_X = 88      ; P0's left edge at power-on and in demo phase 3
PLAYER_HOLD_X  = 88      ; the auto-demo's right-hand resting place
PLAYER_MIN_X   = 8       ; deep enough into the 16-pixel wall to collide
PLAYER_MAX_X   = 136     ; the joystick's right limit
P1_X           = 80      ; P1's left edge (fixed)
BALL_X         = 80      ; the ball's left edge (fixed)
BALL_Y         = 140     ; the ball's first row (fixed)

DEMO_LEFT_HOLD = 8       ; frames parked at the left wall
DEMO_HOLD      = 240     ; frames parked at PLAYER_HOLD_X (the capture window)
BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright beep

MODE0_PF0      = $C0     ; PF0 bits 6-7: chunks 2-3, X=8-15
MODE1_PF1      = $C0     ; PF1 bits 6-7: chunks 4-5, X=16-23
MODE2_PF1      = $30     ; PF1 bits 4-5: chunks 6-7, X=24-31
BUG_PF0        = $C0     ; the bug/fix cell: chunks 2-3, X=8-15

C_RED          = $42
C_GOLD         = $1A
C_GREEN        = $C8
C_BG           = $02

; =============================================================================
; RAM ALLOCATION ($80-$FF; +clean_start zeroes every byte)
; =============================================================================
ModeVal      = $80   ; 0 = sticky collision, 1 = frame overrun, 2 = off-by-one
BugOn        = $81   ; 1 = the faulty path is selected, 0 = the fixed path
PlayerX      = $82   ; P0's left edge, 8..136
PlayerY      = $83   ; P0's game-logic first row (140)
CollisionBit = $84   ; CXP0FB bit 7 as read this frame ($80 or 0)
BallHit      = $85   ; the P0-ball AABB result (1 = the boxes overlap)
PrevFire     = $86   ; fire state last frame (1 = pressed)
NewFire      = $87   ; this frame's fire 0 -> 1 edge
PrevLeft     = $88   ; left state last frame
NewLeft      = $89   ; this frame's left 0 -> 1 edge
PrevRight    = $8A   ; right state last frame
NewRight     = $8B   ; this frame's right 0 -> 1 edge
BeepTimer    = $8C   ; frames of beep remaining
BeepPitch    = $8D   ; AUDF for the beep
DemoPhase    = $8E   ; 0 = left, 1 = hold left, 2 = right, 3 = hold right
DemoTimer    = $8F   ; frames left in phases 1 and 3
ModePF0      = $90   ; the mode row's PF0 byte for this frame
ModePF1      = $91   ; the mode row's PF1 byte for this frame
BugColor     = $92   ; red (BugOn=1) or green (BugOn=0)
BandPF       = $93   ; $FF = the collision band is lit, $00 = dark
BandColor    = $94   ; red when lit, background when dark
ExtraWsync   = $95   ; 1 = mode 1 bug: BodyStart adds the extra WSYNC
P0Delay      = $96   ; 1 = mode 2 bug: P0 starts one line below PlayerY
Startup      = $97   ; frames left before the fire edge is trusted
;
; $98-$F7 are free (96 bytes).  The score and random libraries are not used.
; The stack lives at $F8-$FF; the call depth stays at one level.

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

; --- the lab starts in mode 0 with the buggy path selected ------------------
; That is the state the bug-sticky capture uses: the missing CXCLR is live,
; and the auto-demo drives P0 into the wall and back out.
    LDA #$00
    STA ModeVal
    LDA #$01
    STA BugOn

    LDA #PLAYER_START_X
    STA PlayerX
    LDA #PLAYER_Y
    STA PlayerY
    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #$08
    STA Startup             ; ignore the fire line while it settles

    LDA #C_BG
    STA COLUBK              ; the background and the dark band are $02
    LDA #$21
    STA CTRLPF              ; reflect the playfield; ball is 4 pixels wide

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
; 1. THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
; BeepTimer counts down every frame and silences channel 0 at zero.
    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0               ; silence at the end of the tick
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — toggle BugOn on the 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1, and the
; EOR/AND pair keeps only a new press, so holding the button toggles once.
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

; The first frames after power-on are not trusted: INPT4 can read low
; while the console settles.  Startup counts eight frames.  Until it reaches
; zero the fire edge is forced clear; a held direction arms PrevFire so the
; shared F in a longer hold string cannot toggle the bug by accident.
    LDA Startup
    BEQ FireEdgeReady
    DEC Startup
    LDA #$00
    STA NewFire
; A held direction is a menu selection, not a fire press.  Stella parses the
; hold value letter by letter, so a value such as LEFT also contains F
; (fire); the gate suppresses that fire while a direction is held.  A lone
; held fire becomes exactly one edge after the gate.
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ StartupNoDirection
    LDA #$80
    STA PrevFire
    JMP NoBugToggle
StartupNoDirection:
    LDA #$00
    STA PrevFire
    JMP NoBugToggle
FireEdgeReady:
    LDA NewFire
    BEQ NoBugToggle
    LDA BugOn
    EOR #$01                ; 0 <-> 1
    STA BugOn
BugToggle:                  ; checkpoint: A = the new BugOn
    JSR BeepStart
NoBugToggle:

; -----------------------------------------------------------------------------
; 3. MODE SELECTION — left and right edges, wrapping
; -----------------------------------------------------------------------------
; The SWCHA bits are active low.  The same pair also cancels the auto-demo
; in section 7; here they only change ModeVal on their 0 -> 1 edges.
    LDA SWCHA
LeftRead:                   ; checkpoint: A = SWCHA
    AND #$40                ; P0 left
    EOR #$40                ; 1 = pressed
    STA NewLeft
    EOR PrevLeft
    AND NewLeft
    STA NewLeft
    LDA SWCHA
    AND #$40
    EOR #$40
    STA PrevLeft

    LDA SWCHA
    AND #$80                ; P0 right
    EOR #$80                ; 1 = pressed
    STA NewRight
    EOR PrevRight
    AND NewRight
    STA NewRight
    LDA SWCHA
    AND #$80
    EOR #$80
    STA PrevRight

    LDA ModeVal
Mode:                       ; checkpoint: A = the selected mode
    CMP #$01
    BEQ ModeLeftFrom1
    CMP #$02
    BEQ ModeLeftFrom2
; --- mode 0: left wraps to 2 ----------------------------------------------
    LDA NewLeft
    BEQ CheckModeRight
    LDA #$02
    STA ModeVal
    JSR ArmBug
    JSR BeepStart
    JMP ModeSelectionDone
ModeLeftFrom1:
    LDA NewLeft
    BEQ CheckModeRight
    LDA #$00                ; 1 -> 0
    STA ModeVal
    JSR ArmBug
    JSR BeepStart
    JMP ModeSelectionDone
ModeLeftFrom2:
    LDA NewLeft
    BEQ CheckModeRight
    LDA #$01                ; 2 -> 1
    STA ModeVal
    JSR ArmBug
    JSR BeepStart
    JMP ModeSelectionDone
; --- right wraps 0 -> 1 -> 2 -> 0 -----------------------------------------
CheckModeRight:
    LDA ModeVal
    CMP #$02
    BEQ ModeRightFrom2
    LDA NewRight
    BEQ ModeSelectionDone
    LDA ModeVal
    CLC
    ADC #$01                ; 0 -> 1, 1 -> 2
    STA ModeVal
    JSR ArmBug
    JSR BeepStart
    JMP ModeSelectionDone
ModeRightFrom2:
    LDA NewRight
    BEQ ModeSelectionDone
    LDA #$00                ; 2 -> 0
    STA ModeVal
    JSR ArmBug
    JSR BeepStart
ModeSelectionDone:

; -----------------------------------------------------------------------------
; 4. THE P0-PLAYFIELD COLLISION LATCH
; -----------------------------------------------------------------------------
; CXP0FB bit 7 is P0-playfield; bit 6 is P0-ball and is masked out.  The read
; happens in VBLANK and therefore describes the previous visible frame.
; In modes 1 and 2 and in mode 0's fixed path the latch is cleared after the
; read, so the next frame sees only the current contact.  In mode 0's buggy
; path the CXCLR store is skipped and the latch stays set forever.
    LDA CXP0FB
ReadCX:                     ; checkpoint: A = CXP0FB
    AND #$80
    STA CollisionBit
    LDA ModeVal
    BNE ClearCollision
    LDA BugOn
    BEQ ClearCollision
    JMP CollisionDone       ; BUG 0: the CXCLR store is skipped
ClearCollision:
    LDA #$00
    STA CXCLR
CXClear:                    ; checkpoint: the latches are cleared
    NOP                     ; keeps CollisionDone a distinct breakpoint address
CollisionDone:

; -----------------------------------------------------------------------------
; 5. THE STATUS BYTES — mode cells, bug/fix colour, collision band
; -----------------------------------------------------------------------------
; The three mode cells are precomputed: only the selected cell is lit, so
; the row costs four stores per line instead of a compare per line.
    LDA #$00
    STA ModePF0
    STA ModePF1
    LDA ModeVal
    CMP #$01
    BEQ ModeCell1
    CMP #$02
    BEQ ModeCell2
    LDA #MODE0_PF0
    STA ModePF0
    JMP ModeCellsDone
ModeCell1:
    LDA #MODE1_PF1
    STA ModePF1
    JMP ModeCellsDone
ModeCell2:
    LDA #MODE2_PF1
    STA ModePF1
ModeCellsDone:

; --- the bug/fix cell is red for the buggy path and green for the fix ------
    LDA #C_RED
    LDX BugOn
    BNE BugColorDone
    LDA #C_GREEN
BugColorDone:
    STA BugColor

; --- the collision band is a full-width bar when the latch is set ----------
    LDA CollisionBit
    BEQ BandOff
    LDA #$FF
    STA BandPF
    LDA #C_RED
    STA BandColor
    JMP BandDone
BandOff:
    LDA #$00
    STA BandPF
    LDA #C_BG
    STA BandColor
BandDone:

; -----------------------------------------------------------------------------
; 6. THE P0-BALL CHECK — the game-logic rows, not the drawn rows
; -----------------------------------------------------------------------------
; An axis-aligned overlap of the 8x16 P0 box against the 4x8 ball box.  The
; game logic uses PlayerY, which is the fixed row where P0 is supposed to
; start.  Mode 2's bug draws the sprite one line lower; the check does not
; move, which is exactly the disagreement the debugger exposes.
    LDA #$00
    STA BallHit

; --- Y overlap: PlayerY < BallY+8 AND BallY < PlayerY+16 -------------------
    LDA PlayerY
PlayerYRead:                ; checkpoint: A = PlayerY (140)
    CMP #(BALL_Y + 8)       ; PlayerY > 147?
    BCS BallCheckDone
    CLC
    ADC #15                 ; PlayerY + 15 (the last P0 row)
    CMP #BALL_Y             ; PlayerY+15 < 140?
    BCC BallCheckDone

; --- X overlap: PlayerX < BallX+4 AND BallX < PlayerX+8 --------------------
    LDA PlayerX
PlayerXRead:                ; checkpoint: A = PlayerX
    CMP #(BALL_X + 4)       ; PlayerX > 83?
    BCS BallCheckDone
    CLC
    ADC #7                  ; PlayerX + 7 (the last P0 pixel)
    CMP #BALL_X             ; PlayerX+7 < 80?
    BCC BallCheckDone
    LDA #$01
    STA BallHit
BallCheckDone:
    LDA BallHit
P0BallCheck:                ; checkpoint: A = BallHit (0 or 1)

; -----------------------------------------------------------------------------
; 7. PLAYER MOVEMENT — the joystick, or the deterministic auto-demo
; -----------------------------------------------------------------------------
; A held direction stops the demo and keeps P0 where the player put it for
; DEMO_HOLD frames.  With no direction held, AutoMove runs the 410-frame
; phase cycle described in the header.
    LDA SWCHA
    AND #$C0                ; P0 left (bit 6) and right (bit 7)
    CMP #$C0
    BEQ AutoPlayer
ManualPlayer:
    LDA #$03
    STA DemoPhase           ; park the demo after the manual move
    LDA #DEMO_HOLD
    STA DemoTimer
    LDA SWCHA
    AND #$40                ; left
    BNE ManualNoLeft
    LDA PlayerX
    CMP #PLAYER_MIN_X
    BEQ ManualLeftDone
    DEC PlayerX
ManualLeftDone:
    JMP MovementDone
ManualNoLeft:
    LDA SWCHA
    AND #$80                ; right
    BNE MovementDone
    LDA PlayerX
    CMP #PLAYER_MAX_X
    BEQ MovementDone
    INC PlayerX
    JMP MovementDone
AutoPlayer:
    JSR AutoMove
MovementDone:

; -----------------------------------------------------------------------------
; 8. THE TWO BUG FLAGS THE KERNEL READS
; -----------------------------------------------------------------------------
; ExtraWsync = mode 1 + BugOn: the WSYNC-first line.
; P0Delay    = mode 2 + BugOn: the one-line-late P0 row.
    LDA #$00
    STA ExtraWsync
    STA P0Delay
    LDA ModeVal
    CMP #$01
    BNE CheckP0Delay
    LDA BugOn
    BEQ CheckP0Delay
    LDA #$01
    STA ExtraWsync
CheckP0Delay:
    LDA ModeVal
    CMP #$02
    BNE BugFlagsDone
    LDA BugOn
    BEQ BugFlagsDone
    LDA #$01
    STA P0Delay
BugFlagsDone:

; -----------------------------------------------------------------------------
; 9. POSITION ALL THREE OBJECTS, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; Every coarse RESxx and every HMxx is set first; one WSYNC and one HMOVE
; apply all three fine offsets in the same HBLANK (the one-HMOVE rule from
; Lesson 28).
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA #P1_X
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
    LDA #BALL_X
    CLC
    ADC #(POS_BIAS + 1)     ; the ball's output delay is one clock shorter
    JSR SetCoarseBall
    STA WSYNC
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed (next line)

; -----------------------------------------------------------------------------
; 10. COLOURS, SIZES, AND A CLEAN FIRST LINE
; -----------------------------------------------------------------------------
; The playfield registers are cleared so the mode-1 bug's lost line shows
; background, not a stale row from the previous frame.
    LDA #C_RED
    STA COLUP0              ; P0 is red
    LDA #C_GREEN
    STA COLUP1              ; P1 is green
    LDA #C_BG
    STA COLUBK
    LDA #C_GOLD
    STA COLUPF              ; the wall and the ball are gold
    LDA #$00
    STA NUSIZ0              ; both players are one 8-pixel copy
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    LDA #$21
    STA CTRLPF              ; reflect; the ball is 4 pixels wide

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- BUG 1: the WSYNC-first habit costs the first visible line -------------
; BodyStart is already line 37 cycle 5.  A WSYNC here waits for the end of
; line 37, so the first line's writes and every later zone land one line
; late.  The frame grows to 263 lines and OverscanStart reports 230.
    LDA ExtraWsync
    BEQ BodyNoWsync
    STA WSYNC               ; BUG 1: WSYNC before the line's writes
BodyNoWsync:

; --- visible 0-7: the mode row --------------------------------------------
; The mode row's bytes and colour are precomputed in VBLANK.  In the fixed
; path the stores complete before PF1's first visible slot.
    LDA #C_GOLD
    STA COLUPF
    LDA ModePF0
    STA PF0
    LDA ModePF1
    STA PF1
    LDA #$00
    STA PF2
    LDY #8
ModeRow:
    STA WSYNC
    DEY
    BNE ModeRow

; --- visible 8-15: the bug/fix cell ---------------------------------------
    LDA BugColor
    STA COLUPF
    LDA #BUG_PF0
    STA PF0
    LDA #$00
    STA PF1
    STA PF2
    LDY #8
BugRow:
    STA WSYNC
    DEY
    BNE BugRow

; --- visible 16-39: the top of the play area, wall only -------------------
    LDA #C_GOLD
    STA COLUPF
    LDA #$F0                ; PF0 bits 4-7: a 16-pixel wall at each edge
    STA PF0
    LDA #$00
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    LDY #24
TopWall:
    STA WSYNC
    DEY
    BNE TopWall

; --- visible 40-55: P1, 16 rows -------------------------------------------
; P1 is at X=80.  The GRP1 store completes before P1's first pixel.
    LDA #$FF
    STA GRP1
    LDY #16
P1Rows:
    STA WSYNC
    DEY
    BNE P1Rows

; --- visible 56-139: the middle of the play area, wall only ---------------
    LDA #$00
    STA GRP1
    STA GRP0
    LDY #84
MidWall:
    STA WSYNC
    DEY
    BNE MidWall

; --- visible 140-155: P0 and the ball -------------------------------------
; P0's first row is the one the off-by-one bug moves.  GRP0 is set at the
; top of the zone in the fixed path, before P0's first pixel even at X=8.
; In the bug path GRP0 stays 0 for line 140 and is set at the top of line
; 141, so the drawn sprite starts one line below PlayerY.  The ball is
; enabled for its eight fixed rows in both paths.
    LDA P0Delay
P0DelayRead:                ; checkpoint: A = P0Delay
    BEQ P0DrawNow
    JMP P0Colors            ; BUG 2: line 140 stays blank
P0DrawNow:
    LDA #$FF
P0RowFixed:                 ; checkpoint: fixed path's first GRP0 store
    STA GRP0
P0Colors:
    LDA #C_RED
    STA COLUP0
    LDA #$02
    STA ENABL               ; the ball's first row
    LDA #C_GOLD
    STA COLUPF
    STA WSYNC               ; the end of visible line 140

; Line 141: in the fixed path this is P0's second row; in the bug path it is
; the first.  The store completes before the visible area; the P0RowBug
; checkpoint reports scanline 178, cycle 5.
    LDA #$FF
    STA GRP0
P0RowBug:                   ; checkpoint: the line-141 GRP0 store
    LDY #7
P0BallRows:
    STA WSYNC
    DEY
    BNE P0BallRows

; --- line 148: the ball is over; P0 continues to row 155 ------------------
    LDA #$00
    STA ENABL
    LDY #8
P0Rows:
    STA WSYNC
    DEY
    BNE P0Rows

; --- line 156: the fixed path ends P0 here; the bug path needs one more ---
; In the bug the sprite's 16 rows are 141-156, so line 156 must keep GRP0
; set.  The WSYNC below holds it for that line, and the lower wall loses one
; line to keep the total at 192.
    LDA P0Delay
    BEQ P0ClearNow
    STA WSYNC               ; BUG 2: line 156 is P0's last row
P0ClearNow:
    LDA #$00
    STA GRP0
    LDY #20                 ; 20 lines fixed, 19 in the bug path
    LDX P0Delay
    BEQ BottomCountReady
    LDY #19
BottomCountReady:
    LDA #$F0
    STA PF0
    LDA #$00
    STA PF1
    STA PF2
    LDA #C_GOLD
    STA COLUPF
BottomWall:
    STA WSYNC
    DEY
    BNE BottomWall

; --- visible 176-183: the collision band ----------------------------------
; The band is the visible proof of bug 0.  A full-width playfield bar in red
; means the latch was set; the fixed path turns the playfield off and the
; background shows through.
    LDA BandColor
    STA COLUPF
    LDA BandPF
    STA PF0
    STA PF1
    STA PF2
    LDY #8
BandRow:
    STA WSYNC
    DEY
    BNE BandRow

; --- visible 184-191: background ------------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    LDY #8
RestZone:
    STA WSYNC
    DEY
    BNE RestZone
    JMP FrameEnd

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
FrameEnd:
OverscanStart:              ; checkpoint: scanline 229 fixed / 230 bug
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; ArmBug — selecting a mode shows that mode's bug
; =============================================================================
; The selector is a bug selector: arriving at a mode re-arms BugOn so the
; chosen failure is visible.  Fire then flips to the fixed path.
ArmBug:
    LDA #$01
    STA BugOn
    RTS

; =============================================================================
; AutoMove — the deterministic 410-frame phase cycle
; =============================================================================
; Phase 0 walks left to the wall, phase 1 holds for eight frames, phase 2
; walks right past the ball to X=88, and phase 3 holds for 240 frames.  The
; long hold is the screenshot window.
AutoMove:
    LDA DemoPhase
DemoPhaseRead:              ; checkpoint: A = DemoPhase
    CMP #$01
    BEQ AutoHoldLeft
    CMP #$02
    BEQ AutoRight
    CMP #$03
    BEQ AutoHoldRight

; --- phase 0: left until the wall -----------------------------------------
    LDA PlayerX
    CMP #PLAYER_MIN_X
    BEQ AutoToHoldLeft
    DEC PlayerX
    RTS
AutoToHoldLeft:
    LDA #$01
    STA DemoPhase
    LDA #DEMO_LEFT_HOLD
    STA DemoTimer
    RTS

; --- phase 1: park at the wall --------------------------------------------
AutoHoldLeft:
    DEC DemoTimer
    BNE AutoDone
    LDA #$02
    STA DemoPhase
AutoDone:
    RTS

; --- phase 2: right until the resting place ------------------------------
AutoRight:
    LDA PlayerX
    CMP #PLAYER_HOLD_X
    BEQ AutoToHoldRight
    INC PlayerX
    RTS
AutoToHoldRight:
    LDA #$03
    STA DemoPhase
    LDA #DEMO_HOLD
    STA DemoTimer
    RTS

; --- phase 3: the long hold ----------------------------------------------
AutoHoldRight:
    DEC DemoTimer
    BNE AutoDone
    LDA #$00
    STA DemoPhase
    RTS

; =============================================================================
; SetCoarseP0 / SetCoarseP1 / SetCoarseBall — the Lesson 26 divide-by-15
; =============================================================================
; A = the desired left edge + POS_BIAS.  Each routine starts on a fresh line,
; divides by 15 with repeated SBC, turns the remainder into the HMxx fine
; value, and strobes the matching RESxx.  The caller applies all three with
; one HMOVE.
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

SetCoarseBall:
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
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
; AUDC 0C is the div-6 tone from Lesson 35; AUDV 0A is audible but not loud.
; The VBLANK clock silences the channel two frames later.
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

> The complete, fully-commented source lives in
> `lessons/part6-game-dev/46-debugging/46-debugging.asm`.

### Code Walkthrough

#### Step 1 — The RAM map and the reset state

The lesson uses `$80–$97`; `$98–$F7` are free (96 bytes), and the stack stays at `$F8–$FF`. Every byte is
named in the allocation block, and `+clean_start` zeroes it. Reset sets the state the first
screenshot uses: `ModeVal=0`, `BugOn=1`, `PlayerX=88`, `PlayerY=140`, and a background of `$02`.

```asm
ModeVal      = $80   ; 0 = sticky collision, 1 = frame overrun, 2 = off-by-one
BugOn        = $81   ; 1 = the faulty path is selected, 0 = the fixed path
PlayerX      = $82   ; P0's left edge, 8..136
PlayerY      = $83   ; P0's game-logic first row (140)
CollisionBit = $84   ; CXP0FB bit 7 as read this frame ($80 or 0)
BallHit      = $85   ; the P0-ball AABB result (1 = the boxes overlap)
...
P0Delay      = $96   ; 1 = mode 2 bug: P0 starts one line below PlayerY
Startup      = $97   ; frames left before the fire edge is trusted
```

#### Step 2 — The input edges and the mode selector

The fire and direction edges use the standard `EOR`/`AND` idiom: `EOR` with last frame's value
keeps the bits that changed, and `AND` with this frame's value keeps the ones that changed to 1.
The startup gate is the only unusual part: for eight frames it forces `NewFire` clear and
records a held direction as `PrevFire=$80`, so a command-line hold that contains both a direction
and `F` does not toggle the bug by accident. A lone held fire becomes one edge when the gate
opens.

```asm
    LDA Startup
    BEQ FireEdgeReady
    DEC Startup
    LDA #$00
    STA NewFire
; A held direction is a menu selection, not a fire press...
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ StartupNoDirection
    LDA #$80
    STA PrevFire
    JMP NoBugToggle
StartupNoDirection:
    LDA #$00
    STA PrevFire
    JMP NoBugToggle
FireEdgeReady:
```

The mode selector wraps in both directions. `ArmBug` is the small routine that sets `BugOn=1`
after a mode change, so selecting mode 1 or 2 shows that mode's failure:

```asm
ArmBug:
    LDA #$01
    STA BugOn
    RTS
```

#### Step 3 — The collision read and the missing clear

This is the three-instruction difference between bug 0 and its fix:

```asm
    LDA CXP0FB
ReadCX:                     ; checkpoint: A = CXP0FB
    AND #$80
    STA CollisionBit
    LDA ModeVal
    BNE ClearCollision
    LDA BugOn
    BEQ ClearCollision
    JMP CollisionDone       ; BUG 0: the CXCLR store is skipped
ClearCollision:
    LDA #$00
    STA CXCLR
CXClear:                    ; checkpoint: the latches are cleared
    NOP                     ; keeps CollisionDone a distinct breakpoint address
CollisionDone:
```

The `NOP` is a deliberate debug aid. Without it, `CollisionDone` and `CXClear` would be the same
address, and a breakpoint on `CXClear` would fire in the buggy path even though the `CXCLR` store
never ran. The `NOP` gives the two labels distinct addresses, so the absence of `CXClear` hits is
real evidence, not a symbol-table accident.

#### Step 4 — The status bytes and the band

The display bytes are precomputed in VBLANK. The mode row lights one of three cells; the bug/fix
cell takes its colour from `BugOn`; the band takes its full-width byte and colour from
`CollisionBit`:

```asm
    LDA CollisionBit
    BEQ BandOff
    LDA #$FF
    STA BandPF
    LDA #C_RED
    STA BandColor
    JMP BandDone
BandOff:
    LDA #$00
    STA BandPF
    LDA #C_BG
    STA BandColor
BandDone:
```

`BandPF=$FF` drives all twenty playfield bits, so the band is a full-width bar. When the latch is
clear the playfield is zero and the background shows through; the eight lines are still there,
they are just invisible.

#### Step 5 — The P0-ball check

This is a software box test, not a TIA collision. It uses `PlayerY` — the game-logic row — and
`PlayerX` after the movement:

```asm
    LDA PlayerY
PlayerYRead:                ; checkpoint: A = PlayerY (140)
    CMP #(BALL_Y + 8)       ; PlayerY > 147?
    BCS BallCheckDone
    CLC
    ADC #15                 ; PlayerY + 15 (the last P0 row)
    CMP #BALL_Y             ; PlayerY+15 < 140?
    BCC BallCheckDone
    LDA PlayerX
PlayerXRead:                ; checkpoint: A = PlayerX
    CMP #(BALL_X + 4)       ; PlayerX > 83?
    BCS BallCheckDone
    CLC
    ADC #7                  ; PlayerX + 7 (the last P0 pixel)
    CMP #BALL_X             ; PlayerX+7 < 80?
    BCC BallCheckDone
    LDA #$01
    STA BallHit
BallCheckDone:
    LDA BallHit
P0BallCheck:                ; checkpoint: A = BallHit (0 or 1)
```

The check reports `1` while P0 sweeps through X=73–83, the range where the 8-pixel player box
overlaps the 4-pixel ball at X=80–83. In mode 2 the drawn sprite is one line lower, but the check
still uses `PlayerY=140`; that is the disagreement the lesson exposes.

#### Step 6 — The auto-demo

The demo is a four-phase state machine. Phase 0 walks left to the wall, phase 1 holds for eight
frames, phase 2 walks right past the ball to X=88, and phase 3 holds for 240 frames. The long
hold is what makes the captures deterministic: both ROMs are in phase 3 at the five-second
capture, with P0 far from the wall.

```asm
    LDA DemoPhase
    CMP #$01
    BEQ AutoHoldLeft
    CMP #$02
    BEQ AutoRight
    CMP #$03
    BEQ AutoHoldRight
; --- phase 0: left until the wall ---
    LDA PlayerX
    CMP #PLAYER_MIN_X
    BEQ AutoToHoldLeft
    DEC PlayerX
    RTS
```

A held joystick direction bypasses the demo and sets `DemoPhase=3` with `DemoTimer=240`, so a
manual move parks the demo at the player's X for four seconds rather than fighting the stick.

#### Step 7 — Positioning three objects with one HMOVE

P0, P1, and the ball each use the Lesson 26 divide-by-15 routine. Every `HMPx`/`HMBL` value is
set first, every `RESxx` is strobed, and then one `WSYNC` and one `HMOVE` apply all three fine
offsets in the same horizontal blank:

```asm
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA #P1_X
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
    LDA #BALL_X
    CLC
    ADC #(POS_BIAS + 1)
    JSR SetCoarseBall
    STA WSYNC
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed (next line)
```

The ball's output delay is one clock shorter than a player's (Lesson 29), so its target needs
one extra pixel. The code uses `POS_BIAS + 1` for the ball; the measured left edge is X=80–83,
which matches the `BALL_X = 80` used by the software check.

#### Step 8 — The kernel: nine work-first zones

The visible kernel writes the first line of each zone and then `WSYNC`s through the rest. The
zone counts are 8 + 8 + 24 + 16 + 84 + 16 + 20 + 8 + 8 = 192. The mode-1 bug is the conditional
`WSYNC` at the very top:

```asm
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDA ExtraWsync
    BEQ BodyNoWsync
    STA WSYNC               ; BUG 1: WSYNC before the line's writes
BodyNoWsync:
```

The P0 zone is the only zone whose line count changes between paths. The fixed path draws P0 on
lines 140–155 and gives the lower wall 20 lines. The bug path leaves line 140 blank, draws P0 on
141–156, and gives the lower wall 19 lines; both paths reach the collision band on line 176. The
frame length is unchanged in mode 2, which is why `OverscanStart` stays 229 while the sprite row
moves:

```asm
    LDA P0Delay
P0DelayRead:                ; checkpoint: A = P0Delay
    BEQ P0DrawNow
    JMP P0Colors            ; BUG 2: line 140 stays blank
P0DrawNow:
    LDA #$FF
P0RowFixed:                 ; checkpoint: the fixed path's first GRP0 store
    STA GRP0
...
    LDA P0Delay
    BEQ P0ClearNow
    STA WSYNC               ; BUG 2: line 156 is P0's last row
P0ClearNow:
```

#### Step 9 — Reading it back

```bash
acme -f plain -l build/lesson46.sym -o build/lesson46.bin \
  lessons/part6-game-dev/46-debugging/46-debugging.asm
stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -logtoconsole 1 \
  -break '$F131' docs/public/roms/part6-game-dev/46-debugging/46-debugging.bin
```

Stella keeps one `-break` per run, so run one checkpoint at a time. `-dbg.logtrace 0` keeps the
instruction trace out of the output; `-dbg.logbreaks` continues after each break, which is what
makes a per-frame sequence readable. The measured values are in the table below.

### Checkpoints

The addresses below come from the final symbol file for `46-debugging.asm`. The exercise
solutions add or remove code, so their addresses move; re-assemble with `-l` and read the symbol
file after an edit. The exercise addresses that matter are listed after the table.

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F033` | **259**, cycle 3 fixed; **260** in the mode-1 bug | the first VSYNC line |
| `VblankStart` | `$F041` | 0, cycle 5 | the first VBLANK line |
| `FireRead` | `$F058` | A=`$0C` pressed; A=`$8C` released | `INPT4`; bit 7 is the button |
| `LeftRead` | `$F09D` | A=`$BF` left; A=`$FF` released | `SWCHA`; bit 6 is P0 left |
| `Mode` | `$F0CC` | A=0, 1, or 2 | `ModeVal`, read every frame |
| `BugToggle` | `$F097` | A=0 or 1 | the new `BugOn` after a fire edge |
| `ReadCX` | `$F131` | A=`$02` clear; `$42` ball only; `$C2` wall + ball | `CXP0FB` raw |
| `CXClear` | `$F144` | A=0; **absent in the mode-0 bug** | the `CXCLR` strobe |
| `PlayerYRead` | `$F18E` | A=`$8C` (140) | the game-logic P0 row |
| `PlayerXRead` | `$F19B` | A=88 in the capture window; 8 at the wall | P0's left edge |
| `P0BallCheck` | `$F1AC` | A=0 or 1 | the software P0-ball overlap |
| `P0DelayRead` | `$F2BC` | A=0 fixed; A=1 in the mode-2 bug | the P0 row-delay flag |
| `P0RowFixed` | `$F2C3` | A=`$FF`, **scanline 177** (visible 140); absent in the mode-2 bug | the fixed path's first `GRP0` store |
| `P0RowBug` | `$F2D7` | A=`$FF`, **scanline 178** (visible 141) | the line-141 `GRP0` store |
| `BodyStart` | `$F257` | **37**, cycle 5 | visible line 0 |
| `HmoveApply` | `$F220` | line 7, cycle 56 | the `WSYNC` stall before the one `HMOVE` |
| `HmoveDone` | `$F222` | line 8, cycle 3 | the store has executed |
| `OverscanStart` | `$F339` | **229**, cycle 7 fixed; **230** in the mode-1 bug | overscan's first line |

The measured state log in the next section shows the values behind the table. The important
negative results are as loud as the positive ones:

- `CXClear` has **no hits** in the main ROM's mode 0 and one hit per frame in
  `exercise-01-solution`.
- `P0RowFixed` has **no hits** in the main ROM's mode 2 and one hit per frame at scanline 177 in
  `exercise-03-solution`.
- `OverscanStart` reports 230 in the main ROM's mode 1 and 229 in `exercise-02-solution`.

The exercise solutions' key addresses are:

| Solution | Checkpoint | Address | Measured |
|---|---|---|---|
| `exercise-01-solution` | `ReadCX` | `$F12F` | returns to `$02` after separation |
| `exercise-01-solution` | `CXClear` | `$F137` | A=0 every frame |
| `exercise-01-solution` | `OverscanStart` | `$F32C` | 229 |
| `exercise-02-solution` | `StartFrame` | `$F033` | 259 |
| `exercise-02-solution` | `OverscanStart` | `$F323` | 229 in mode 1 |
| `exercise-03-solution` | `P0RowFixed` | `$F2AC` | scanline 177 |
| `exercise-03-solution` | `P0RowBug` | `$F2C0` | scanline 178 (the second row) |
| `exercise-03-solution` | `OverscanStart` | `$F316` | 229 in mode 2 |

## What You Should See

The screen is a dark `$02` field with a gold status row, a gold-framed play area, and two
sprites. In the main ROM's default state (mode 0, `BugOn=1`):

- **Status row, visible 0–7.** The selected mode 0 cell is a gold 8×8-pixel block at TIA
  X=8–15; the mode 1 and mode 2 cells are dark. The mirror copy is at X=144–151.
- **Status row, visible 8–15.** The bug/fix cell is a red 8×8-pixel block at X=8–15, mirror at
  X=144–151. Red means the buggy path is selected.
- **Play area, visible 16–175.** Gold walls at X=0–15 and X=144–159. P1 is a green 8×16 block at
  X=80–87, visible 40–55. P0 is a red 8×16 block at X=88–95, visible 140–155. The ball is a gold
  4×8 block at X=80–83, visible 140–147, just to the left of P0.
- **Collision band, visible 176–183.** A full-width red bar. P0 is far from the wall at X=88;
  the bar is lit because the mode-0 bug never cleared the latch from the earlier contact.

![Stella running the Lesson 46 ROM: a gold mode cell and red bug cell in the status row, gold side walls, a green enemy above, a red player and a small gold ball below, and a full-width red collision band at the bottom](/images/lesson46/bug-sticky.png)

*The buggy sticky collision. The auto-demo has already driven P0 into the left wall and back to
X=88, but the red band at visible 176–183 is still lit: `CXP0FB` bit 7 was read and never cleared.
The status row says mode 0 (gold cell) and bug (red cell). The ball at X=80 is visible to the left
of P0.*

<RomPlayer rom="/roms/part6-game-dev/46-debugging/46-debugging.bin" title="Lesson 46 — Debugging" />

Click the player screen once: Javatari starts muted until a user gesture. The ROM runs its
auto-demo without input, so P0 walks into the wall, comes back, and parks at X=88. Press fire to
switch to the fixed path and watch the band clear; press left or right to select another mode.
Mode 1 makes the frame 263 lines (the debugger's `OverscanStart` reports 230); mode 2 draws P0
one line below `PlayerY`.

![Stella running the Lesson 46 exercise-01 ROM: the same scene, but the bug/fix cell is green and the collision band is dark](/images/lesson46/fix-sticky.png)

*Exercise 1's fix. The status cell is green (`BugOn=0`), the collision band is the background
`$02`, and the rest of the scene is identical to the buggy capture: the gold mode cell, the gold
walls, green P1, red P0 at X=88, and the gold ball at X=80. This is the pair used to pixel-check
the band and the status row.*

> **Capture method.** Both images are window captures of the committed ROMs in Stella 7.0, from
> `docs/public/roms/part6-game-dev/46-debugging/46-debugging.bin` and
> `.../exercise-01-solution.bin`, with the pointer parked at (0,0) and no game pixel altered.
> The title bars read `Stella 7.0: "46-debugging"` and `Stella 7.0: "exercise-01-solution"`.
> The buggy capture waited 5.0 seconds after launch and the fix waited 6.0 seconds (the longer
> wait let Stella's startup overlay clear). Those waits include Stella's startup, so they are
> wall-clock waits, not emulated frame numbers; the auto-demo's phase 3 is 240 frames long
> (about 4 seconds), so both runs land in the settled window with P0 at X=88. The pixel checks
> decode the captured colours: the mode cell at capture (80,110) is gold in both, the bug/fix
> cell at (80,140) is red in the buggy image and green in the fix, and the band at (300,665) is
> red in the buggy image and background `$02` in the fix. The positions use capture x = 25 + 6 ×
> TIA X and capture y = 107 + 3.15 × visible line: P0's left edge at X=88 is capture x=553, the
> ball at X=80 is x=505, and the band at visible 176 is y=661.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
# the frame is 262 lines in mode 0
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F339' \
  docs/public/roms/part6-game-dev/46-debugging/46-debugging.bin
# the mode-1 bug: select mode 1 with the right direction held from power-on
stella -audio.enabled 0 -holdjoy0 R -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F339' docs/public/roms/part6-game-dev/46-debugging/46-debugging.bin
```

| Run | Checkpoint | Measured | What it proves |
|---|---|---|---|
| main, no input | `StartFrame` | 259, cycle 3 | the fixed 262-line frame |
| main, `-holdjoy0 R` | `StartFrame` | 260, cycle 3 | the mode-1 bug's 263-line frame |
| main, no input | `OverscanStart` | 229, cycle 7 | the fixed frame's last picture line |
| main, `-holdjoy0 R` | `OverscanStart` | 230, cycle 7 | the extra line from the WSYNC-first start |
| main, no input | `BodyStart` | 37, cycle 5 | visible line 0 |
| main, no input | `HmoveApply` / `HmoveDone` | 7/56, 8/3 | the one-`HMOVE` rule |
| main, no input | `ReadCX` | `$02` → `$42` → `$C2` | the ball bit, then the sticky wall bit |
| main, no input | `CXClear` | **no hits** | the missing `CXCLR` in mode 0 |
| main, no input | `PlayerYRead` | `$8C` (140) | the game-logic row |
| main, no input | `PlayerXRead` | 88 in phase 3 | the capture's P0 position |
| main, no input | `P0BallCheck` | 1 on frames 6–16; the return sweep starts the second window at frame 155 | the ball is crossed on both sweeps |
| main, `-holdjoy0 R` | `Mode` | 1 | the mode selector |
| main, `-holdjoy0 L` | `Mode` | 2 | the left wrap |
| main, `-holdjoy0 F` | `BugToggle` | A=0 at frame 9 | the startup gate and the fire edge |
| main, `-holdjoy0 L` | `P0DelayRead` | A=1 | mode 2's row delay |
| main, `-holdjoy0 L` | `P0RowFixed` | **no hits** | the buggy path skips line 140 |
| main, `-holdjoy0 L` | `P0RowBug` | 178, cycle 5 | the first `GRP0` store is on visible 141 |
| `exercise-01-solution` | `CXClear` | A=0 every frame | the fix |
| `exercise-01-solution` | `ReadCX` | returns to `$02` after separation | the fixed latch |
| `exercise-02-solution`, `-holdjoy0 R` | `OverscanStart` | 229 | the frame is back to 262 lines |
| `exercise-03-solution`, `-holdjoy0 L` | `P0RowFixed` | 177 | the drawn row matches `PlayerY` |

With the debugger open on a visible frame, the RAM bytes are `ModeVal` at `$80`, `BugOn` at
`$81`, `PlayerX` at `$82`, `PlayerY` at `$83`, `CollisionBit` at `$84`, and `BallHit` at `$85`.
`CXP0FB` is a read register at `$02`; the debugger's TIA panel shows its live bits. The band is
drawn from `CollisionBit`, so a red band means bit 7 is still set in RAM, not that the TIA is
still seeing a contact.

## Exercises

### Exercise 1: Fix the Sticky Collision

**Challenge:** add `STA CXCLR` after the `CXP0FB` read so the mode-0 path clears the latch every
frame. The band must go dark one frame after P0 leaves the wall, `CXClear` must fire every frame,
and the bug/fix cell should start green so the picture and the status row agree.

**Hints:**
1. The read is in VBLANK and describes the previous visible frame. Clear the latch after the
   read, not before it; clearing first would throw away the contact you have not read yet.
2. `CXCLR` is a strobe; the stored value does not matter. `LDA #$00; STA CXCLR` is the same as
   any other `STA CXCLR`.
3. The mode-0 bug is selected by `ModeVal=0` and `BugOn=1`. If you make the clear unconditional,
   mode 0 is fixed in both `BugOn` states; the status cell still reports `BugOn`, which is why
   the solution starts with `BugOn=0` and a green cell.
4. `ReadCX` after separation should return `$02` (bit 6 from the ball is clear by then; bit 7 is
   clear because the wall latch was cleared). In the bug it stays `$C2`.
5. The one-frame latency is expected. The frame after separation still reads the old contact;
   the frame after that reads clear. `CXClear` fires on both frames.

**Expected Result:** `CXClear` (`$F137` in the solution) reports A=0 on every frame; `ReadCX`
(`$F12F`) returns to `$02` after P0 leaves the wall; the band is background `$02` in the capture;
the bug/fix cell is green. The ROM assembles to exactly 4,096 bytes.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Fix the Frame

**Challenge:** reorder the kernel to work-first in every mode. Remove the conditional `WSYNC` at
`BodyStart`; the first line's writes must belong to line 37. `OverscanStart` must report 229 and
`StartFrame` 259 in mode 1, and the frame must be 262 lines.

**Hints:**
1. `BodyStart` is line 37 cycle 5, not the top of the scanline. The first `STAs` must happen
   before the beam reaches the visible part of line 37; a `WSYNC` there waits for the end of the
   line and loses it.
2. The `LDA ExtraWsync` / `BEQ` / `STA WSYNC` block is the whole bug. Delete it and the kernel
   is work-first; the `ExtraWsync` flag becomes unused and can be removed from the RAM map.
3. The zone counts do not change. The first zone's stores still cover line 37 (8 lines), the
   last zone still returns at 229, and the picture is the same as the fixed mode-0 path.
4. Select mode 1 with `-holdjoy0 R` (one right edge from power-on). Without the fix,
   `OverscanStart` reports 230 and `StartFrame` 260; with it, 229 and 259.
5. The frame is 263 lines at about 59.8 Hz, one line outside the 262-line contract. Whether a
   given television loses hold was not verified; the scanline count is the evidence.

**Expected Result:** `OverscanStart` (`$F323` in the solution) reports 229, cycle 7 in mode 1;
`StartFrame` (`$F033`) reports 259, cycle 3; the frame is 262 lines. The ROM assembles to exactly
4,096 bytes and the mode-1 picture is stable.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Fix the Off-by-One Sprite Row *(Stretch Goal)*

**Challenge:** make the drawn sprite's first row match `PlayerY`. Remove the one-line delay in the
P0 zone, keep the lower wall at twenty lines, and prove that `P0RowFixed` fires at scanline 177
while `PlayerY` reports 140. The frame must stay 262 lines in mode 2.

**Hints:**
1. The bug path jumps over the line-140 `GRP0` store and sets `GRP0` at line 141. The fixed path
   sets it at the top of the zone, before the visible part of line 140, and the store completes
   before P0's first pixel even at X=8.
2. The bug path holds `GRP0` for line 156 and gives the lower wall 19 lines. Removing the delay
   means clearing `GRP0` at line 156 and restoring the wall's 20 lines; the zone totals stay at
   192 and `OverscanStart` stays 229.
3. `PlayerY` stays 140; the fix does not move the game logic, it moves the drawing. That is the
   point: the variable and the picture must agree.
4. Select mode 2 with `-holdjoy0 L` (the mode-0 left edge wraps to 2). In the bug
   `P0RowFixed` has no hits and `P0RowBug` reports 178; in the fix `P0RowFixed` reports 177 and
   `P0RowBug` reports 178 as the second row.
5. The P0-ball check still uses `PlayerY`; with an eight-row ball the overlap boolean does not
   change, but the top row of the sprite now sits on the row the check believes it does.

**Expected Result:** `P0RowFixed` (`$F2AC` in the solution) reports A=`$FF` at scanline 177;
`P0RowBug` (`$F2C0`) reports scanline 178 as the second row; `PlayerYRead` (`$F18E`)
reports 140; `OverscanStart` (`$F316`) reports 229 in mode 2. The ROM assembles to exactly 4,096
bytes.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A latch is not a level.** `CXP0FB` stays set until `CXCLR`; a read without a clear turns
  one contact into a permanent red band. The fix is one strobe, but the diagnosis is the read in
  VBLANK and the negative result at the `CXClear` checkpoint.
- ✅ **Read collisions in VBLANK and disclose the one-frame latency.** The latch describes the
  previous visible frame. The band reacts one frame after the contact, and that is the correct
  behaviour, not a bug.
- ✅ **Work-first keeps the first line.** `BodyStart` is line 37 cycle 5; a leading `WSYNC`
  throws that line away and every zone ends one line late. 262 becomes 263, `OverscanStart` 229
  becomes 230, and `StartFrame` 259 becomes 260.
- ✅ **A frame has a signature.** `StartFrame`, `VblankStart`, `BodyStart`, and `OverscanStart`
  are four numbers that should not move. When one moves, the frame arithmetic tells you which
  count is wrong before you look at the picture.
- ✅ **Correlate the variable with the drawn row.** A one-line sprite offset can leave the
  collision boolean unchanged and still be a real bug. Break on the first `GRP0` store and read
  its scanline; compare that with the game-logic `PlayerY`.
- ✅ **Breakpoints turn a frame into a table.** `-dbg.logbreaks 1 -logtoconsole 1 -break '$ADDR'`
  gives frame, scanline, cycle, flags, and registers, one line per hit. One checkpoint per run is
  enough to prove a value; the negative result (no hits) is evidence too.
- ✅ **A screenshot proves the monitor; the log proves the logic.** The pair above proves the
  band and the status cell. The state log proves the latch, the scanline count, and the drawn
  row. The lesson uses both and says which is which.

## What's Next

The lab has shown you how to find a bug with a breakpoint, a watch, and a frame count. The next
lesson turns the same pipeline outward: ACME macros and `!if`, the Makefile, git, and the
verification script, all shown on screen as a build dashboard. [Lesson 47: Development Tools &
Workflow](/part6-game-dev/47-dev-tools-workflow) closes Part 6 and sets up the kernel work in
Part 7.
