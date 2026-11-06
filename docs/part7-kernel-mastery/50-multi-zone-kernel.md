---
title: "Lesson 50: Multi-Zone Kernel — Scoreboard + Playfield + Sprites"
description: "Split one 192-line frame into four zones and give each zone its own kernel: a 9-line 48-pixel score, an 8-line gold level bar, a 174-line two-line playfield with a red player, a green enemy and a falling gold ball, and a one-line ground. Two HMOVEs, a reused score library, and an exact 9 + 8 + 174 + 1 line budget."
prev:
  text: "Lesson 49: The 2-Line Kernel — Standard Game Pattern"
  link: "/part7-kernel-mastery/49-two-line-kernel"
next:
  text: "Lesson 51: Flicker Sprites — More Than 2 Objects"
  link: "/part7-kernel-mastery/51-flicker-sprites"
---

# Lesson 50: Multi-Zone Kernel — Scoreboard + Playfield + Sprites

> **Part 7: Kernel Mastery** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 15 (the RIOT timer), Lesson 17 (cycle counting), Lesson 18 (mid-scanline changes), Lesson 19 (the playfield), Lesson 26 (positioning), Lesson 28 (the one-`HMOVE` rule), Lesson 29 (the ball), Lesson 31 (`NUSIZ`), Lesson 38 (collision latches), Lesson 39 (`include/score.asm`), Lesson 41 (game states), Lesson 49 (the 2-line kernel)
> **You will learn:** how to divide the 192-line picture into fixed zones with an exact line budget; how to give each zone its own kernel shape; how the score library's 9-line 48-pixel kernel fits above the game; how to reuse P0 and P1 after the score has finished with them; how a second `HMOVE` in the status HBLANK repositions them without disturbing the ball; and how a collision read one frame late turns a falling ball into a score
> **You will build:** "the dashboard" — a 4,096-byte ROM with a six-digit white score, a mirrored gold level bar that fills every 120 frames, a grey ceiling, a 174-line two-line playfield with a red 32-scanline player (16 kernel rows), a green 32-scanline enemy that sweeps, a gold 8-line ball that falls from top 24 to 158 and respawns on a P0–ball hit, a gold floor, and a one-line dark green ground; plus three exercise solutions: a 12-line status zone, a 16-line status zone with a draining timer bar, and a `ZoneTable` with assembly-time budget asserts

## Introduction

Lesson 49 built one kernel for the whole screen. Real games do not work that way. A game screen is a stack of **zones**: a score at the top, a status bar below it, a play area, and a ground line. Each zone wants a different kernel, and each zone gets a fixed number of scanlines. The skill is the **line budget** — deciding how many of the 192 visible lines each zone owns, and making every kernel land on its boundary on every frame.

The companion program `50-multi-zone-kernel.asm` is **the dashboard**, and it divides the frame exactly:

```
visible   0-  8   score      9 lines   the 48-pixel score kernel
visible   9- 16   status     8 lines   a mirrored pair of gold level bars
visible  17-190   play     174 lines   87 rows x 2, the 2-line kernel
visible 191       ground     1 line    a solid dark green
                  ----------------
                  9 + 8 + 174 + 1 = 192 visible lines
```

The score is drawn by the shared `include/score.asm` library from Lesson 39, so the top of the screen is the same 48-pixel trick you already know: two players in three-copy close mode at TIA X=56/64, six white digits across 48 pixels. The status zone is new: a gold bar in each half of the screen that fills one 4-pixel chunk per level, using the reflected playfield. The play zone is Lesson 49's two-line loop with its own three bands: a grey ceiling, a field, and a gold floor. The player is red, the enemy is green, and the ball is a one-pixel gold column, eight scanlines tall, that falls one visible line per frame — two scanlines every second frame, the vertical resolution of the 2-line kernel.

The lesson's real subject is the **transition between zones**. The score library leaves P0 and P1 parked at 56/64 in three-copy mode. The play zone needs them at the game's positions, in one-copy mode. The status zone is where the hand-over happens: the score's `HMOVE` runs in VBLANK, `ScoreDraw` draws nine lines, and then a second `HMOVE` in the status HBLANK repositions both players for the game. An `HMOVE` re-applies **every** motion register, so the ball's fine offset — applied by the score's `HMOVE` — must be cleared before the second one, or the ball moves twice. By the end of the lesson you can count the zones, position the reused players, and prove the frame is still 262 lines.

::: details TypeScript Equivalent

A multi-zone kernel is a table of zones with a renderer and a line budget. In TypeScript the same idea is a list of zone objects:

```typescript
type ZoneName = "score" | "status" | "play" | "ground";

interface Zone {
  name: ZoneName;
  start: number;    // the first visible line
  lines: number;    // the budget
  draw: () => void; // the zone's own kernel
}

const zones: Zone[] = [
  { name: "score",  start: 0,   lines: 9,   draw: drawScore },
  { name: "status", start: 9,   lines: 8,   draw: drawStatus },
  { name: "play",   start: 17,  lines: 174, draw: drawPlay },
  { name: "ground", start: 191, lines: 1,   draw: drawGround },
];

function drawFrame(): void {
  for (const zone of zones) {
    for (let line = 0; line < zone.lines; line++) {
      zone.draw();          // the zone's kernel writes its registers
      waitScanline();       // STA WSYNC
    }
  }
}
```

The analogy breaks where the hardware starts. There is no framebuffer and no `Zone` array in RAM: the four zones share the same TIA registers, and `draw()` is not a pure function — it writes latches that the beam reads **as it passes**. `waitScanline()` is `STA WSYNC`, which stops the CPU until the end of the current line; the CPU resumes at the start of the next one. A write that lands after the beam has drawn the relevant pixels changes nothing on that line. The line budget must be exact: one extra or missing `WSYNC` moves every later zone by a scanline. And the zones share the two players and the ball, so a boundary is not a new canvas — it is a **repositioning event**, paid for with an `HMOVE`. In TypeScript you can call `drawStatus()` and let it use its own objects; on the 2600 the status zone must move the same P0 and P1 that the score just used.

:::

## Theory

### Section 1: A Zone Is a Line Budget

The NTSC frame is 3 VSYNC lines, 37 VBLANK lines, 192 picture lines, and 30 overscan lines. The picture starts at scanline 37, so **visible line 0 is scanline 37**. Every zone in this lesson is stated in visible lines, and every boundary is also an absolute scanline:

| Zone | Visible lines | Lines | Start scanline | Kernel |
|---|---|---|---|---|
| Score | 0–8 | 9 | 37 (`BodyStart`) | `ScoreDraw`, WSYNC-first |
| Status | 9–16 | 8 | 46 (`StatusStart`) | a playfield bar, one `WSYNC` per line |
| Play | 17–190 | 174 | 54 (`PlayStart`) | a 2-line kernel, 87 rows |
| Ground | 191 | 1 | 228 (`GroundStart`) | one background line |
| — | — | **192** | 229 (`OverscanStart`) | the frame ends |

The arithmetic is the design: `9 + 8 + 174 + 1 = 192`, and `37 + 9 = 46`, `37 + 17 = 54`, `37 + 191 = 228`, `37 + 192 = 229`. The four entry points are labels in the source, and the state log checks them: `StatusStart` 46, `PlayStart` 54, `GroundStart` 228, `OverscanStart` 229.

The score zone's 9 lines are fixed by the library. `ScoreDraw` consumes **nine** visible lines: line 0 is a setup/blank line, the eight glyph rows are displayed on lines 1–8, and the cleanup shares line 8. The caller resumes on visible line 9 — which is why `StatusStart` is scanline 46, not 45.

The play zone is 87 rows × 2 scanlines. The kernel lands on `GroundStart` (scanline 228) after the last row's second `WSYNC` and the loop tail.

::: tip The scanline is the fact; the cycle depends on the tail
A breakpoint at a zone label reports the line exactly, but the cycle at the label depends on the instructions just before it. `GroundStart` is at scanline 228 cycle 6 because the floor loop's `INY`/`CPY`/`BNE` ran at the start of the line. `StatusStart` is at 46 cycle 5 because `ScoreDraw`'s cleanup spilled five cycles into the line. Measure the line; treat the cycle as a description of the code path.
:::

### Section 2: The Score Zone, and the Players It Leaves Behind

The score is the Lesson 39 library, unchanged. `ScoreInit` and `ScoreClear` run once at reset and build the six zero glyphs. Every frame in VBLANK, `ScoreSetup`:

- sets `NUSIZ0 = NUSIZ1 = 3` (three copies, close spacing),
- sets `VDELP0 = VDELP1 = 1` (the cross-latch that lets each column be placed just before its copy),
- positions P0 at TIA X=56 and P1 at X=64,
- and strobes **one** `HMOVE`.

Then `ScoreDraw` draws the eight rows. Its line 0 is the setup/blank line; the stores for row 7 land on visible line 1 with `VDEL` on. The cleanup blanks both players and turns `VDEL` off, so the caller's next code starts on visible line 9 with `GRP0 = GRP1 = 0` and `VDELP0 = VDELP1 = 0`.

That cleanup is the hand-over point. The players are **blank**, but they are still at the score's positions (56/64) and still in three-copy mode. The game needs them at its own positions and in one-copy mode. The status zone does the repositioning.

The score itself is a six-digit decimal number. `ScoreAddOne` adds one with a decimal carry, redrawing every digit that changes. A P0–ball hit calls it. The library's `ScoreAdd` label is the checkpoint: `A` is the digit after the add. The measured first hit is `A = 1` at frame 106, then 2 at frame 211, 3 at 316, and 4 at 421.

### Section 3: Two HMOVEs, One per Repositioning Event

Lesson 28's rule is one `HMOVE` per repositioning event. This lesson has two events, so it has two HMOVEs:

1. **`ScoreHmove`**, the `HMOVE` inside `ScoreSetup`, in VBLANK. It applies P0/P1 at 56/64 for the score **and** the ball's fine offset, because `SetCoarseBL` sets `HMBL` and `RESBL` before `ScoreSetup` is called. That is the Lesson 39 arrangement: one `HMOVE` applies all three objects' fine offsets in one HBLANK.
2. **`GameHmove`**, our own `HMOVE`, in the HBLANK of status scanline 51. It applies P0/P1 at the game positions after `ScoreDraw` has finished with them.

The trap is the ball. An `HMOVE` re-applies **every** motion register, not just the ones you changed. After `ScoreHmove`, `HMBL` still holds the ball's fine offset. If `GameHmove` ran with that value, the ball would be shifted a second time. The fix is one store, placed **more than 24 cycles after `ScoreHmove`** (the TIA forbids a motion-register write for 24 machine cycles after `HMOVE`) and before `GameHmove`: clear `HMBL` after the game players have been repositioned, on status line 50.

```asm
    JSR ScoreSetup          ; ScoreHmove: P0/P1 at 56/64 and the ball's fine offset
    ; ... the score zone, the status bar, SetGameP0 and SetGameP1 ...
    JSR SetGameP1           ; status line 49
    LDA #$00
    STA HMBL                ; >24 cycles after ScoreHmove: GameHmove must not shift it again
    STA WSYNC               ; status line 50 ends here
GameHmove:
    STA HMOVE               ; P0/P1 only; HMBL is zero
```

The ball keeps the position `ScoreHmove` gave it, and `GameHmove` applies only P0/P1.

#### The positioning dance must cost a fixed number of lines

The game's positions come from the Lesson 26 divide-by-15 routine. The routine's loop runs a variable number of times (a player at X=8 subtracts 15 once; a player at X=144 subtracts 15 ten times), so a naive call would push the following code across a scanline boundary for some X and not for others. The zone's line count would move with the joystick. That is not acceptable.

The fix is a `WSYNC` at each end of the routine:

```asm
SetGameP0:
    STA WSYNC       ; start a fresh line
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
    STA WSYNC       ; end this line, whatever the loop length was
    RTS
```

The division and its stores run on one line; the final `WSYNC` ends it. The worst case is A=147: `SEC` 2 + ten loop pairs 49 + `EOR` 2 + four `ASL`s 8 + `STA HMP0` 3 + `STA RESP0` 3 + `STA WSYNC` 3 = **70 cycles**, inside the 76-cycle line. The routine therefore costs exactly **two scanlines** for every X. `SetGameP0` takes lines 46–47, `SetGameP1` lines 48–49, the caller's `WSYNC` ends line 50, and `GameHmove` runs at the start of line 51. The status bar's PF values are latched the whole time and are not disturbed.

`HMOVE` blanks the left eight pixels of its own line. The bar starts at playfield chunk 2 (pixel 8), so the blanking covers only chunks 0–1: no bar chunk is lost, and the blanking shows as an eight-pixel black notch on that one status line. The screenshot shows it; it is the hardware, not a bug.

::: tip Why the score's HMOVE runs in VBLANK and the game's in the status zone
The score's players must be at 56/64 *before* `ScoreDraw` starts, so its `HMOVE` belongs in VBLANK. The game's players must be repositioned *after* `ScoreDraw`, but the play zone starts at visible line 17; the status zone is the only place with eight spare lines. The status HBLANK at line 51 is the last safe strobing point before the play kernel.
:::

### Section 4: The Play Zone — Three Bands and One Row Body

The play zone is 174 lines = 87 rows × 2. It has three sub-bands whose playfield registers are **constant**, so the playfield bytes and `COLUPF` are written once at each band's first line instead of once per row:

| Play rows | Visible lines | `PF0`/`PF1`/`PF2` | `COLUPF` | What it draws |
|---|---|---|---|---|
| 0–3 | 17–24 | `$F0`/`$FF`/`$FF` | `$0C` grey | the ceiling |
| 4–82 | 25–182 | `$00`/`$00`/`$00` | `$1A` gold | the field (the ball) |
| 83–86 | 183–190 | `$F0`/`$FF`/`$FF` | `$1A` gold | the floor |

The band boundary writes land before each register's first chunk: the ceiling's PF0/PF1/PF2 complete at about cycles 15/20/23, the field at 15/18/21, and the floor at 10/15/18. PF2's first chunk is chunk 12 (cycle 38.7), so even the ceiling's cycle-23 PF2 store is in time; no boundary bleeds into the visible area. A per-row playfield write would not be so lucky: its later stores would leave the previous band's chunks on the first scanline of the new band.

The row body is one macro, expanded once per band:

```asm
    LDA P0Strip,Y
    STA GRP0          ; the player
    LDA P1Strip,Y
    STA GRP1          ; the enemy
    LDA #$00
    STA ENABL         ; the ball off by default
    TYA
    SEC
    SBC BallRow
    CMP #$04
    BCS .NoBall       ; Y - BallRow >= 4: not one of the ball's four rows
    LDA #$02
    STA ENABL         ; ENABL bit 1: the ball on
.NoBall:
    STA WSYNC         ; line 1 of the row
    STA WSYNC         ; line 2 of the row
```

The cycle count per pair:

| Work | Cycles |
|---|---|
| `GRP0` pair | 7 |
| `GRP1` pair | 7 |
| `ENABL = 0` | 5 |
| `TYA` + `SEC` + `SBC BallRow` + `CMP #4` | 9 |
| branch + `LDA #2` + `STA ENABL` (ball rows) | 7 |
| two `STA WSYNC` | 6 |
| `INY` + `CPY` + `BNE` (loop tail) | 7 |
| **total** | **44–48 per pair** |

The two-line budget is 152, so the pair leaves more than 100 cycles of margin. The stores are early because the sprites' positions are chosen to make them early: in steady state `GRP0` lands at about cycle 14 (P0's left edge can be TIA X=8, whose first pixel is at cycle 25.3), `GRP1` at about cycle 21 (P1's left limit is X=48, first pixel 38.7), and `ENABL` at about cycle 42 (the ball is fixed at X=80, first pixel 49.3). All three are in time.

The ball's four rows move every frame, so a ROM table cannot hold them; an 87-byte RAM table does not fit beside the 48-byte `ScoreBuf`. The row test is a zero-page `SBC` and a carry compare — five instructions and a branch. `BallY` is in visible play-zone lines (24–158) and `BallRow = BallY >> 1` is the first of the four rows. The kernel draws a 2-line row, so the ball's top moves two scanlines every second frame: that is the vertical resolution of the kernel, not a bug.

The two sprite strips are 87 bytes each, page-aligned:

- **P0** is a 32-scanline player (16 kernel rows): sixteen strip bytes at rows 67–82 (visible 151–182), feet just above the floor at row 83. Its top byte is solid `$FF`, so the falling ball meets the player as soon as it reaches the head.
- **P1** is a 32-scanline enemy at rows 6–21 (visible 29–60), below the ceiling.

The auto-demo positions P0 four pixels left of the ball (`BALL_X - 4 = 76`), so the ball's column at X=80 is inside the top row's eight pixels.

### Section 5: The Level Bar, the Collision, and the Auto-Demo

**The level bar.** The status zone's left half occupies playfield chunks 2–16: 15 chunks × 4 pixels = 60 pixels. `CTRLPF = $01` reflects the playfield, so the right half is the mirror. Level `N` lights chunks `2 .. 1+N` of the left half, and the reflection lights the matching chunks at the right edge. The bar grows from the two **outer** edges toward the centre; level 15 leaves the central six chunks (24 pixels) as background.

Three 16-byte tables hold the masks:

- `LevelPF0` — chunks 0–3 (bit 4 = chunk 0).
- `LevelPF1` — chunks 4–11 (bit 7 = chunk 4).
- `LevelPF2` — chunks 12–19 (bit 0 = chunk 12).

Level 1 lights chunk 2 (`PF0 = $40`); level 4 lights chunks 2–5 (`PF0 = $C0`, `PF1 = $C0`); level 15 lights chunks 2–16 (`$C0`, `$FF`, `$1F`).

The level clock is `LevelTimer`, which counts 0–119 and wraps. On the frame it reaches 120, `Level` increments and `LevelWrite` logs the new value; at level 15 the clock keeps running but the level stays. The measured values: `A = 1` at frame 121, 2 at 241, 3 at 361, 4 at 481. The bar is eight lines tall because the status zone is eight lines; the same three masks are latched through the dance and the wait loop.

**The collision.** `CXP0FB` bit 6 is set while a player-0 pixel and a ball pixel share a colour clock. The read happens in the **next** VBLANK, so it describes the visible frame that just ended: the hit is one frame late by construction. After the read, `CXCLR` clears every latch. A hit calls `ScoreAddOne`, starts the beep, and respawns the ball at `BALL_START_Y = 24`.

**The auto-demo.** With no joystick input, P0 aims at `BALL_X - 4` and steps one pixel per frame toward it. The ball is fixed at X=80, so the player settles at 76 and catches every ball. P1 sweeps 48 → 112 → 48, one pixel per frame. The joystick takes over P0 whenever left or right is held: `SWCHA`'s player-0 bits are active low, and after `AND #$C0` a left press reads `$80` (→ `DEC P0X`) and a right press reads `$40` (→ `INC P0X`), clamped to TIA X 8–144.

The ball falls 24 → 128 before it meets the player's head (play row 67), takes 104 increments, and the collision is read one frame later. A hit therefore happens every **105 frames**, while the level steps every **120**. The score's period is 15 frames shorter, so the two counters drift apart by 15 frames per level; the capture windows still line up: score 000001 during level 1 (frames 121–210) and score 000004 during level 4 (frames 481–525). That is why the two screenshots can show the score and the level with the same digit.

::: tip The one-frame collision latency is the game's clock
The latch describes the frame that just ended, not the frame being built. On the frame you read a hit, the ball has already respawned and the score has already changed; the visible frame shows the new state. Every 2600 game with a collision-driven score has this one-frame offset — it is why a ball can appear to pass through a paddle for one frame.
:::

## The Code

### Building This Lesson

```bash
# every lesson ROM, including this one:
npm run roms

# or just this one:
acme -f plain -o build/lesson50.bin \
  lessons/part7-kernel-mastery/50-multi-zone-kernel/50-multi-zone-kernel.asm

stella build/lesson50.bin
```

The three exercise solutions sit beside the lesson source. Each is a complete 4,096-byte ROM:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part7-kernel-mastery/50-multi-zone-kernel/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part7-kernel-mastery/50-multi-zone-kernel/exercise-02-solution.asm
acme -f plain -o build/exercise-03.bin \
  lessons/part7-kernel-mastery/50-multi-zone-kernel/exercise-03-solution.asm
```

### Full Source

The complete annotated source is the lesson's reference copy. It is reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 50: Multi-Zone Kernel — The Dashboard — Racing the Beam
; =============================================================================
; Part 7: Kernel Mastery
;
; What this program does:
;   "the dashboard": one frame split into four fixed zones, each drawn by a
;   different kernel shape.  The zones are counted in VISIBLE LINES (the
;   picture starts at scanline 37, so visible line 0 is scanline 37):
;
;     visible   0-  8   the score zone    9 lines  ScoreDraw (48-pixel trick)
;     visible   9- 16   the status zone   8 lines  a gold level bar
;     visible  17-190   the play zone   174 lines  87 rows x 2 (2-line kernel)
;     visible 191       the ground line   1 line   a solid dark green
;                       ----------------
;                       9 + 8 + 174 + 1 = 192 visible lines
;
;   The zones are also absolute scanlines: StatusStart 46 (37+9), PlayStart 54
;   (37+17), GroundStart 228 (37+191), and OverscanStart 229.  Every kernel is
;   work-first (write the line's registers, then STA WSYNC) except the score
;   library's 48-pixel kernel, which is WSYNC-first by design (Lesson 39).
;
;   THE SCORE ZONE (9 lines).  include/score.asm draws six white digits with
;   P0/P1 in three-copy close mode: P0 at TIA X=56 and P1 at X=64, so the
;   copies interleave into six 8-pixel columns across 48 pixels (56..103).
;   ScoreDraw's line 0 is a setup/blank line; rows are displayed on lines 1-8
;   and the cleanup shares line 8, so the caller resumes on visible line 9.
;   The score starts at 000000 and ScoreAddOne increments it on a P0-ball hit.
;
;   THE STATUS ZONE (8 lines).  A mirrored pair of 15-chunk gold level bars
;   (one per half).  The bar's left half occupies playfield chunks 2..16;
;   CTRLPF=$01 reflects it, so the right half is the mirror.  Level 0-15 fills
;   the bar one chunk at a time: Level N lights chunks 2..(1+N) of the left
;   half, and the reflection lights the same chunks at the right edge.  The
;   bar therefore grows from the two outer edges toward the centre.  The three
;   PF masks for each level come from LevelPF0/1/2 (16 entries each).
;   The level advances every 120 frames and stops at 15 (LevelWrite).
;
;   THE PLAY ZONE (174 lines = 87 rows x 2).  A 2-line kernel.  The play area
;   has three sub-bands with constant registers, so the playfield bytes are
;   written once per band, not once per row:
;     rows  0- 3   the ceiling      (PF0=$F0, PF1=PF2=$FF, COLUPF=$0C)
;     rows  4-82   the field        (PF0=PF1=PF2=0,   COLUPF=$1A, ball gold)
;     rows 83-86   the floor        (PF0=$F0, PF1=PF2=$FF, COLUPF=$1A)
;   P0 is a red player 16 kernel rows tall (32 scanlines): sixteen strip
;   bytes at rows 67-82 (visible 151-182, feet just above the floor at row
;   83).  P1 is a green enemy of the same height at rows 6-21 (visible
;   29-60).  Both strips are 87 bytes, one byte per 2-line row.
;   The ball is an 8-line gold ball (four 2-line rows) that falls from visible
;   play-zone line 24 to 158, one line per frame; the 2-line kernel quantises
;   its top to the pair row, so it advances two lines every second frame.
;   BallY stores visible lines; BallRow = BallY >> 1 is the first of its four
;   kernel rows.
;
;   THE GROUND LINE (1 line).  PF0/PF1/PF2 are cleared and COLUBK is set to
;   dark green $C4 for visible line 191; the next frame's VBLANK restores $02.
;
;   THE TWO HMOVES (one per repositioning event):
;     1. ScoreHmove is ScoreSetup's HMOVE in VBLANK.  It applies P0/P1 at
;        TIA X=56/64 for the score AND the ball's fine offset, because HMBL
;        and RESBL are set before ScoreSetup.  HMBL is cleared after the game
;        repositioning (status line 50), more than 24 cycles after
;        ScoreHmove, so GameHmove does not shift the ball a second time.
;     2. GameHmove is our own HMOVE in the HBLANK of status scanline 51.  It
;        applies P0/P1 at the game positions after ScoreDraw has finished
;        with them.  The status bar starts at playfield chunk 2, so the
;        HMOVE's 8-pixel left-edge blanking covers only chunks 0-1: no bar
;        chunk is lost, and the blanked pixels show the HMOVE's black edge
;        on that one status line.
;
;   THE COLLISION.  CXP0FB bit 6 (P0-ball) is read in VBLANK, one frame after
;   the overlap; the read is followed by CXCLR.  A hit calls ScoreAddOne,
;   beeps, and respawns the ball at the top.
;
;   THE AUTO-DEMO.  With no joystick input P0 seeks the point 4 pixels left of
;   the ball (the ball at X=80 therefore sits in the middle of P0's 8-pixel
;   top row), so the score climbs.  P1 sweeps 48 -> 112 -> 48.  The joystick
;   takes over P0 whenever left or right is held.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame is scanline 259, VblankStart 0, BodyStart 37, StatusStart 46,
;   PlayStart 54, GroundStart 228, OverscanStart 229.
;
; The play kernel's row body (one byte per two scanlines):
;   GRP0 + GRP1                       14 cycles
;   ENABL 0, then the ball window test
;     TYA + SEC + SBC BallRow + CMP    9
;     branch + LDA #2 + STA ENABL      7 (ball rows) / 2 (other rows)
;   two STA WSYNC                      6
;   INY + CPY #87 + BNE                7
;   ---------------------------------------
;   total                             ~43-48 cycles per pair
;   The two-line budget is 152, so the pair leaves more than 100 cycles of
;   margin.  The stores land early: GRP0 at ~cycle 14 (P0's left edge can be
;   TIA X=8, whose first pixel arrives at cycle 25.3), GRP1 at ~21 (P1's left
;   limit is X=48, first pixel 38.7) and ENABL at ~43 (the ball is fixed at
;   X=80, first pixel 49.3).  The playfield bytes are constant within a band
;   and are written at the band's first line, before each register's first chunk.
;
; Controls:
;   Joystick left/right moves P0 one pixel per frame, clamped to TIA X 8..144.
;   With no input the auto-demo moves P0 under the ball.  The score climbs by
;   one per caught ball; the level bar advances every 120 frames.  There is no
;   fire or SELECT action: this is a kernel lab.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BodyStart (37), StatusStart (46),
;   PlayStart (54), GroundStart (228), OverscanStart (229);
;   ScoreDraw (the library entry, visible line 0), ScoreAdd (the library's
;   A = the digit after the add), ScoreHmove (the library's HmoveApply, the
;   score HMOVE's WSYNC stall), ScoreHmoveDone (the store has executed),
;   GameHmove (the game HMOVE at status line 51), LevelWrite (A = the new
;   level), BallYRead (A = BallY before the step), JoyLeft / JoyRight (A = P0X
;   on the joystick branch).
;
; RAM map (+clean_start zeroes every byte):
;   $80 P0X          the player's left edge, 8..144
;   $81 P1X          the enemy's left edge, 48..112
;   $82 P1Dir        the enemy's sweep direction: 0 = left, 1 = right
;   $83 BallY        the ball's top visible line inside the play zone, 24..158
;   $84 BallRow      BallY >> 1: the first of the ball's four kernel rows
;   $85 Level        the level, 0..15
;   $86 LevelTimer   frames since the last level step, 0..119
;   $87 BeepTimer    frames of beep left
;   $88 BeepPitch    AUDF0 for the beep
;   $89-$9F          free (23 bytes)
;   $A0-$D7          include/score.asm (ScoreDigits, ScoreRow, ScoreTmp, ScoreBuf)
;   $D8-$F7          free (32 bytes)
;   $F8-$FF          stack
;
; Build: acme -f plain -o build/lesson50.bin \
;        lessons/part7-kernel-mastery/50-multi-zone-kernel/50-multi-zone-kernel.asm
; Run:   stella build/lesson50.bin     (click the screen to hear the beep)
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

; --- the zone line counts (they must total 192) ------------------------------
STATUS_LINES   = 8       ; visible 9-16
PLAY_ROWS      = 87      ; visible 17-190: 87 rows x 2 scanlines = 174 lines
CEIL_ROWS      = 4       ; play rows 0-3: the ceiling
FLOOR_ROWS     = 4       ; play rows 83-86: the floor
FIELD_END      = PLAY_ROWS - FLOOR_ROWS   ; first floor row (83)
P0_TOP         = FIELD_END - 16           ; P0's first strip byte (67)
STATUS_WAIT    = STATUS_LINES - 5         ; the WSYNCs after GameHmove

; --- the level clock ---------------------------------------------------------
LEVEL_FRAMES   = 120     ; frames per level step
LEVEL_MAX      = 15      ; the bar is full at level 15

; --- the ball -----------------------------------------------------------------
BALL_START_Y   = 24      ; the ball's top line at respawn
BALL_END_Y     = 158     ; the last top line before a miss
BALL_X         = 80      ; the ball's fixed TIA X

; --- the players --------------------------------------------------------------
P0_MIN         = 8       ; the player's left limit (TIA X)
P0_MAX         = 144     ; the player's right limit (8 pixels wide)
P0_START       = 76      ; power-on: the ball at 80 is centred on the player
PLAYER_CENTRE  = 4       ; the ball's column inside the 8-pixel player
P1_MIN         = 48      ; the enemy's left limit (GRP1 is safe before 38.7)
P1_MAX         = 112     ; the enemy's right limit
P1_START       = 48

; --- the beep -----------------------------------------------------------------
BEEP_FRAMES    = 8
BEEP_PITCH     = $08

; --- colours ------------------------------------------------------------------
C_PLAYER       = $42     ; P0: red
C_ENEMY        = $C8     ; P1: green
C_WHITE        = $0E     ; the score digits
C_GOLD         = $1A     ; the status bar, the ball, the field, the floor
C_CEILING      = $0C     ; the ceiling: light grey
C_GROUND       = $C4     ; the ground line: dark green
C_BG           = $02     ; the background

; =============================================================================
; RAM ALLOCATION ($80-$88; +clean_start zeroes every byte)
; =============================================================================
P0X          = $80   ; the player's left edge, 8..144
P1X          = $81   ; the enemy's left edge, 48..112
P1Dir        = $82   ; 0 = sweeping left, 1 = sweeping right
BallY        = $83   ; the ball's top visible line in the play zone
BallRow      = $84   ; BallY >> 1: the first of the ball's four kernel rows
Level        = $85   ; 0..15
LevelTimer   = $86   ; frames since the last level step
BeepTimer    = $87   ; frames of beep remaining
BeepPitch    = $88   ; AUDF0 for the beep
;
; $89-$9F are free.  The score library owns $A0-$D7; $D8-$F7 is free.

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

    JSR ScoreInit           ; zero the six digits and the 48-byte buffer
    JSR ScoreClear          ; build the six zero glyphs: the score reads 000000

    LDA #P0_START
    STA P0X                 ; the player starts centred under the ball
    LDA #P1_START
    STA P1X
    LDA #$01
    STA P1Dir               ; the enemy sweeps right first
    LDA #BALL_START_Y
    STA BallY
    LDA #BEEP_PITCH
    STA BeepPitch

    LDA #C_BG
    STA COLUBK
    LDA #C_GOLD
    STA COLUPF
    LDA #$01
    STA CTRLPF              ; reflect the playfield; the ball is one pixel
    LDA #$00                ; the left half
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    STA NUSIZ0
    STA NUSIZ1

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
; 2. THE LEVEL CLOCK — every 120 frames Level++ (cap 15)
; -----------------------------------------------------------------------------
; LevelTimer counts 0..119 and wraps.  When the level is already 15 the clock
; keeps running but the level stays there: the bar is full.
    INC LevelTimer
    LDA LevelTimer
    CMP #LEVEL_FRAMES
    BCC LevelDone
    LDA #$00
    STA LevelTimer
    LDA Level
    CMP #LEVEL_MAX
    BEQ LevelDone
    INC Level
    LDA Level
LevelWrite:                 ; checkpoint: A = the new level
    NOP                     ; the label sits on the change path only
LevelDone:

; -----------------------------------------------------------------------------
; 3. THE BALL'S FALL — one visible line per frame, respawn at the bottom
; -----------------------------------------------------------------------------
; BallY is in visible play-zone lines and runs 24..158.  The kernel draws a
; 2-line row, so BallRow = BallY >> 1 quantises the top: the ball steps two
; lines every second frame, which is the vertical resolution of the kernel.
; At 158 the ball has reached its last top line; without a hit it respawns.
    LDA BallY
BallYRead:                  ; checkpoint: A = BallY before the step
    CMP #BALL_END_Y
    BCC BallStep
    LDA #BALL_START_Y
    STA BallY
    JMP BallMoved
BallStep:
    INC BallY
BallMoved:
    LDA BallY
    LSR
    STA BallRow

; -----------------------------------------------------------------------------
; 4. THE COLLISION — CXP0FB bit 6 (P0-ball), read in the next VBLANK
; -----------------------------------------------------------------------------
; The latch describes the visible frame that just ended, so the hit is always
; one frame late by construction.  CXCLR clears every latch after the read.
    LDA CXP0FB
    AND #$40                ; bit 6: player 0 met the ball
    BEQ NoHit
    JSR ScoreAddOne         ; add one, with a decimal carry
    JSR BeepStart           ; AUDC/AUDF/AUDV and the beep timer
    LDA #BALL_START_Y
    STA BallY               ; respawn at the top of the field
    LDA #BALL_START_Y
    LSR
    STA BallRow
NoHit:
    LDA #$00
    STA CXCLR               ; the latches have done their job for this frame

; -----------------------------------------------------------------------------
; 5. P0 — the joystick, or the auto-demo seeking the ball
; -----------------------------------------------------------------------------
; SWCHA's P0 direction bits are active low.  The raw masks are $40 (left) and
; $80 (right); after AND #$C0 a left press reads $80 and a right press reads
; $40.  Map $80 to DEC and $40 to INC; clamp TIA X 8..144.
    LDA SWCHA
    AND #$C0
    CMP #$C0
    BEQ AutoSeek            ; neither pressed: run the demo
    CMP #$80
    BEQ MoveLeft
    CMP #$40
    BEQ MoveRight
    JMP AutoSeek            ; both directions held: treat as no input
MoveLeft:
    LDA P0X
JoyLeft:                    ; checkpoint: A = P0X on the left branch
    CMP #P0_MIN
    BEQ MoveDone
    DEC P0X
    JMP MoveDone
MoveRight:
    LDA P0X
JoyRight:                   ; checkpoint: A = P0X on the right branch
    CMP #P0_MAX
    BEQ MoveDone
    INC P0X
    JMP MoveDone

; The auto-demo: aim four pixels left of the ball, so the ball's column falls
; inside the player's 8-pixel top row, then step one pixel per frame.  The
; seek target is clamped to the player's travel.
AutoSeek:
    LDA #BALL_X
    SEC
    SBC #PLAYER_CENTRE      ; the ball's column inside the player
    CMP #P0_MIN
    BCS AutoSeekHigh
    LDA #P0_MIN
AutoSeekHigh:
    CMP #(P0_MAX + 1)
    BCC AutoSeekCompare
    LDA #P0_MAX
AutoSeekCompare:
    CMP P0X
    BEQ MoveDone
    BCC AutoSeekLeft
    INC P0X
    JMP MoveDone
AutoSeekLeft:
    DEC P0X
MoveDone:

; -----------------------------------------------------------------------------
; 6. P1 — the sweep, 48 -> 112 -> 48, one pixel per frame
; -----------------------------------------------------------------------------
    LDA P1Dir
    BNE P1Right
    LDA P1X
    CMP #P1_MIN
    BEQ P1FlipRight
    DEC P1X
    JMP P1Done
P1Right:
    LDA P1X
    CMP #P1_MAX
    BEQ P1FlipLeft
    INC P1X
    JMP P1Done
P1FlipLeft:
    LDA #$00
    STA P1Dir
    DEC P1X
    JMP P1Done
P1FlipRight:
    LDA #$01
    STA P1Dir
    INC P1X
P1Done:

; -----------------------------------------------------------------------------
; 7. POSITION THE BALL AND THE SCORE — ONE HMOVE IN VBLANK
; -----------------------------------------------------------------------------
; The ball's reset is one colour clock shorter than a player's, so its target
; carries one extra pixel (Lesson 29/39).  SetCoarseBL leaves HMBL and RESBL
; ready; ScoreSetup sets HMP0/HMP1 and ends with ONE HMOVE that applies the
; ball's fine offset and both players' score positions together (ScoreHmove).
    LDA #BALL_X
    CLC
    ADC #(POS_BIAS + 1)
    JSR SetCoarseBL
    JSR ScoreSetup          ; the score's HMOVE = ScoreHmove (the library's HmoveApply)

; -----------------------------------------------------------------------------
; 8. THE SCORE ZONE'S COLOURS AND CONTROLS
; -----------------------------------------------------------------------------
; The score digits are white; the status bar that follows is gold; the
; background is $02.  PF and ENABL are blank: the score kernel draws only the
; players.  NUSIZ/VDEL were set by ScoreSetup for the 48-pixel score.
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    LDA #C_GOLD
    STA COLUPF
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    STA GRP0
    STA GRP1
    LDA #$01
    STA CTRLPF              ; reflect the playfield; the ball is one pixel

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE LINE 0-8: THE SCORE ZONE (9 lines)
; =============================================================================
; ScoreDraw consumes nine visible lines: line 0 is the setup/blank line, the
; rows are displayed on lines 1-8, and the cleanup shares line 8.  The kernel
; is WSYNC-first by design (the Staugas 48-pixel kernel, Lesson 39).  The
; library's entry label is the ScoreDraw checkpoint.
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    JSR ScoreDraw

; =============================================================================
; VISIBLE LINE 9-16: THE STATUS ZONE (8 lines)
; =============================================================================
; ScoreDraw's cleanup spills five cycles into visible line 9, so the status
; writes start at scanline 46 cycle ~5.  Their pixel deadlines are chunk 0 at
; cycle 22.7 (PF0), chunk 4 at 28.0 (PF1) and chunk 12 at 38.7 (PF2); the
; stores land at about 16, 23 and 30, so the first bar line is clean.
StatusStart:                ; checkpoint: scanline 46, visible line 9
    LDX Level
    LDA LevelPF0,X
    STA PF0                 ; chunks 0-3 of the bar
    LDA LevelPF1,X
    STA PF1                 ; chunks 4-11 of the bar
    LDA LevelPF2,X
    STA PF2                 ; chunks 12-19 of the bar

    LDA #C_PLAYER
    STA COLUP0              ; the game's player is red
    LDA #C_ENEMY
    STA COLUP1              ; the enemy is green
    LDA #$00
    STA NUSIZ0              ; one 8-pixel copy each (the score used three)
    STA NUSIZ1

; --- reposition P0 and P1 for the game, one player per line -----------------
; Each routine ends with a WSYNC, so it consumes exactly two scanlines no
; matter how long the divide-by-15 loop runs.  That keeps the status zone's
; line count fixed for every player X.
    LDA P0X
    CLC
    ADC #POS_BIAS
    JSR SetGameP0           ; status line 46: WSYNC, line 47: the P0 division
    LDA P1X
    CLC
    ADC #POS_BIAS
    JSR SetGameP1           ; status line 48: WSYNC, line 49: the P1 division
    LDA #$00
    STA HMBL                ; >24 cycles after ScoreHmove; GameHmove must not shift it


    STA WSYNC               ; status line 50 ends here
    NOP                     ; the WSYNC releases the CPU on status line 51
GameHmove:                  ; checkpoint: status line 51, the game's HMOVE
    STA HMOVE               ; applies HMP0/HMP1; HMBL is zero
; The HMOVE blanks the left 8 pixels of its own status line (51).  The bar
; starts at chunk 2 (pixel 8), so only chunks 0-1 are blanked: the bar itself
; is unaffected.

; The rest of the status zone: the bar's registers are latched and no writes
; change them.  STATUS_WAIT ends the remaining status lines and releases the
; CPU on PlayStart.
    LDX #STATUS_WAIT
StatusWait:
    STA WSYNC
    DEX
    BNE StatusWait

; =============================================================================
; PlayRow — one play row (two scanlines), work-first
; =============================================================================
; The macro is expanded once per sub-band.  Y is both the row counter and the
; table index; the caller owns INY / CPY / BNE.
;
;   GRP0  7   the player: first (P0's left edge can be TIA X=8)
;   GRP1  7   the enemy: P1's left limit is X=48, first pixel 38.7
;   ENABL 5   start with the ball off
;   test  9+2/7  Y - BallRow < 4 turns the ball on for its four rows
;   WSYNC 6   line 1 and line 2 of the row
;
; The ball test is a plain zero-page SBC and a carry test, not a table: the
; ball's four rows move every frame, so a ROM table cannot hold them and an
; 87-byte RAM table does not fit beside the 48-byte score buffer.
!macro PlayRow {
    LDA P0Strip,Y
    STA GRP0
    LDA P1Strip,Y
    STA GRP1
    LDA #$00
    STA ENABL
    TYA
    SEC
    SBC BallRow
    CMP #$04
    BCS .NoBall
    LDA #$02
    STA ENABL
.NoBall:
    STA WSYNC
    STA WSYNC
}

; =============================================================================
; VISIBLE LINE 17-190: THE PLAY ZONE (174 lines = 87 rows x 2)
; =============================================================================
; The play zone has three sub-bands with constant registers.  The playfield
; bytes and COLUPF are written once at each band's first line, before each
; register's first chunk (PF2 starts at chunk 12, cycle 38.7), so no band
; boundary bleeds into the visible area.
PlayStart:                  ; checkpoint: scanline 54, visible line 17
    LDY #0

; --- the ceiling: play rows 0-3 (visible 17-24) ------------------------------
    LDA #C_CEILING
    STA COLUPF              ; the ceiling is grey
    LDA #$F0
    STA PF0                 ; chunks 0-3
    LDA #$FF
    STA PF1                 ; chunks 4-11
    STA PF2                 ; chunks 12-19
CeilingLoop:
    +PlayRow
    INY
    CPY #CEIL_ROWS
    BNE CeilingLoop

; --- the field: play rows 4-82 (visible 25-182) ------------------------------
    LDA #C_GOLD
    STA COLUPF              ; the ball is gold in the field
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
FieldLoop:
    +PlayRow
    INY
    CPY #FIELD_END
    BNE FieldLoop

; --- the floor: play rows 83-86 (visible 183-190) ----------------------------
; COLUPF is already gold, so the ball keeps its colour if it ever reaches the
; floor; only the playfield bytes change.
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
FloorLoop:
    +PlayRow
    INY
    CPY #PLAY_ROWS
    BNE FloorLoop
; 87 rows x 2 lines = visible 17-190.  The last WSYNC releases the CPU at
; scanline 228, the first ground line.

; =============================================================================
; VISIBLE LINE 191: THE GROUND LINE (1 line)
; =============================================================================
; The floor left PF0/PF1/PF2 set; clear them before the ground line's pixels
; (chunk 0 at cycle 22.7) and paint the whole line with the background colour.
GroundStart:                ; checkpoint: scanline 228, visible line 191
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA #C_GROUND
    STA COLUBK              ; a solid dark green line, full width
    STA WSYNC
    NOP                     ; the WSYNC releases the CPU on scanline 229

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
; SETGAMEP0 / SETGAMEP1 — the Lesson 26 divide-by-15 dance, fixed to two lines
; =============================================================================
; A = the desired left edge + POS_BIAS.  The first WSYNC starts a fresh line;
; the divide loop and the stores run on that line; the final WSYNC ends it.
; The worst case (A=147) is 70 cycles, inside the 76-cycle line, so each call
; costs exactly two scanlines for every X.  That is what keeps PlayStart fixed.
SetGameP0:
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
    STA WSYNC
    RTS

SetGameP1:
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
    STA WSYNC
    RTS

; =============================================================================
; BALL COARSE POSITIONING — one RESBL, one HMBL, no HMOVE here
; =============================================================================
; A = the ball's TIA X plus POS_BIAS + 1 (the ball's reset is shorter).
; ScoreSetup's HMOVE applies HMBL in the same HBLANK as the players' fine
; offsets, which is Lesson 39's arrangement.
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
; THE STATUS BAR'S LEVEL MASKS — 16 levels x 3 playfield bytes
; =============================================================================
; The bar's left half covers playfield chunks 2..16 (15 chunks).  Level N
; lights chunks 2..(1+N): the bar grows from the outer edges toward the
; centre, and CTRLPF's reflection draws the right half's mirror.  PF0 carries
; chunks 0-3 (bit 4 = chunk 0), PF1 chunks 4-11 (bit 7 = chunk 4) and PF2
; chunks 12-19 (bit 0 = chunk 12).
LevelPF0:
    !byte $00, $40, $C0, $C0, $C0, $C0, $C0, $C0      ; levels 0-7
    !byte $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0      ; levels 8-15
LevelPF1:
    !byte $00, $00, $00, $80, $C0, $E0, $F0, $F8      ; levels 0-7
    !byte $FC, $FE, $FF, $FF, $FF, $FF, $FF, $FF      ; levels 8-15
LevelPF2:
    !byte $00, $00, $00, $00, $00, $00, $00, $00      ; levels 0-7
    !byte $00, $00, $00, $01, $03, $07, $0F, $1F      ; levels 8-15

; =============================================================================
; THE PLAY ZONE'S SPRITE STRIPS — one byte per 2-line row
; =============================================================================
; Every strip is page-aligned so LDA strip,Y never crosses a page.
;
; P0: a player 16 kernel rows tall (32 scanlines): sixteen strip bytes
; starting at P0_TOP, so the feet sit just above the floor at FIELD_END.
; The top byte is solid $FF, so the falling ball meets the player as soon as
; it reaches the head; the rest is a small person.
    !align 255, 0
P0Strip:
    !fill P0_TOP, $00
    !byte $FF, $18, $18, $3C, $3C, $7E, $7E, $5A
    !byte $5A, $18, $18, $3C, $3C, $66, $66, $C3
    !fill (PLAY_ROWS - P0_TOP - 16), $00

; P1: an enemy of the same height at rows 6-21 (visible 29-60), below the
; ceiling.  Each byte covers two scanlines.
    !align 255, 0
P1Strip:
    !fill 6, $00
    !byte $3C, $3C, $7E, $7E, $DB, $DB, $FF, $FF
    !byte $FF, $FF, $DB, $DB, $66, $66, $3C, $3C
    !fill (PLAY_ROWS - 22), $00

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreInit, ScoreClear, ScoreSetup, ScoreSetDigit, ScoreAddOne, ScoreDraw,
; and ScoreFont live here.  The library must be sourced inside the ROM area
; (after * = $F000) and after include/vcs.asm.
    !source "include/score.asm"

; The lesson's names for the score's HMOVE.  The library's HmoveApply label sits
; on the STA HMOVE inside ScoreSetup; HmoveDone sits after it.  A breakpoint on
; ScoreHmove reports the WSYNC stall one line early (a Stella logging artefact
; for an instruction that immediately follows a WSYNC); ScoreHmoveDone reports
; the state just after the store, which is the HMOVE's real line and cycle.
ScoreHmove     = HmoveApply
ScoreHmoveDone = HmoveDone

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
> `lessons/part7-kernel-mastery/50-multi-zone-kernel/50-multi-zone-kernel.asm`.

### Code Walkthrough

#### Step 1 — The frame skeleton and the four entry points

The frame is the Part 2–6 skeleton with four zone entry points in the middle:

```asm
StartFrame:                 ; scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; scanline 0
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    ; ... the beep, the level clock, the ball, the collision, the players,
    ;     the ball's coarse position, ScoreSetup, the score colours ...
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

BodyStart:                  ; scanline 37, visible line 0
    JSR ScoreDraw           ; 9 lines: visible 0-8

StatusStart:                ; scanline 46, visible line 9
    ; ... the level masks, the game colours, SetGameP0/P1, GameHmove, waits ...

PlayStart:                  ; scanline 54, visible line 17
    ; ... the ceiling, field and floor loops, 87 rows x 2 ...

GroundStart:                ; scanline 228, visible line 191
    ; ... clear PF, COLUBK = dark green, one WSYNC ...

OverscanStart:              ; scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame
```

The zones are labels, and the state log checks them: 37, 46, 54, 228, and 229. The frame remains `3 + 37 + 192 + 30 = 262` lines.

#### Step 2 — The score zone and the hand-over

`ScoreSetup` runs in VBLANK with the ball's coarse position already set. Its `HMOVE` (`ScoreHmove`) applies P0/P1 at 56/64 **and** `HMBL`. The clear waits until the status zone's game repositioning, more than 24 cycles later:

```asm
    JSR ScoreSetup          ; ScoreHmove
    ; ... score/status setup, SetGameP0, SetGameP1 ...
    LDA #$00
    STA HMBL                ; >24 cycles after ScoreHmove; do not apply the ball's offset twice
    STA WSYNC               ; status line 50 ends here
```

`BodyStart` calls `ScoreDraw`. Nine visible lines later the score is on screen, the players are blank, `VDEL` is off, and the status zone starts at scanline 46. The library's labels are the checkpoints: `ScoreDraw` enters at 37/11, and `ScoreAdd` reports the digit after each hit (1, 2, 3, 4 at frames 106/211/316/421).

#### Step 3 — The status zone: the bar and the fixed two-line dance

The first status line writes the level masks and the game's colours, then hands the players over:

```asm
StatusStart:                ; scanline 46, visible line 9
    LDX Level
    LDA LevelPF0,X
    STA PF0
    LDA LevelPF1,X
    STA PF1
    LDA LevelPF2,X
    STA PF2

    LDA #C_PLAYER
    STA COLUP0
    LDA #C_ENEMY
    STA COLUP1
    LDA #$00
    STA NUSIZ0              ; one copy each; the score used three
    STA NUSIZ1

    LDA P0X
    CLC
    ADC #POS_BIAS
    JSR SetGameP0           ; lines 46-47
    LDA P1X
    CLC
    ADC #POS_BIAS
    JSR SetGameP1           ; lines 48-49
    LDA #$00
    STA HMBL                ; >24 cycles after ScoreHmove; GameHmove must not shift it again
    STA WSYNC               ; ends line 50
GameHmove:
    STA HMOVE               ; line 51: P0/P1 at the game positions
    LDX #STATUS_WAIT
StatusWait:
    STA WSYNC
    DEX
    BNE StatusWait
```

`SetGameP0` and `SetGameP1` each end with a `WSYNC`, so the divide-by-15 loop's length cannot move the boundary. `GameHmove` is on status line 51; its eight-pixel blanking covers chunks 0–1, and the bar starts at chunk 2. The wait loop ends the remaining status lines and releases the CPU at `PlayStart`.

#### Step 4 — The play zone: three bands, one row body

The play kernel is three loops around one macro. Each band writes its constant playfield registers at its first line; the macro draws a row and waits twice:

```asm
PlayStart:                  ; scanline 54, visible line 17
    LDY #0
    ; ceiling: COLUPF=$0C, PF0=$F0, PF1=PF2=$FF
CeilingLoop:
    +PlayRow
    INY
    CPY #CEIL_ROWS
    BNE CeilingLoop

    ; field: COLUPF=$1A, PF0=PF1=PF2=0
FieldLoop:
    +PlayRow
    INY
    CPY #FIELD_END
    BNE FieldLoop

    ; floor: PF0=$F0, PF1=PF2=$FF (COLUPF is still gold)
FloorLoop:
    +PlayRow
    INY
    CPY #PLAY_ROWS
    BNE FloorLoop
```

The `PlayRow` macro's ball test is the only per-row decision: `TYA; SEC; SBC BallRow; CMP #4; BCS .NoBall` turns `ENABL` on for exactly the ball's four rows. The measured row body is 44–48 cycles of the 152-cycle pair; the scale of the margin is the point of a 2-line kernel.

#### Step 5 — The ground and the overscan

The floor left the playfield bits set, so the ground line clears them and paints the background:

```asm
GroundStart:                ; scanline 228, visible line 191
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA #C_GROUND
    STA COLUBK              ; a solid dark green line
    STA WSYNC
    NOP                     ; the WSYNC releases the CPU on scanline 229
```

The clears and the colour write all land before each register's first chunk, so the whole line is dark green. The next frame's VBLANK restores `COLUBK = $02`.

#### Step 6 — The level clock, the collision, and the demo

The level clock is a 120-frame counter:

```asm
    INC LevelTimer
    LDA LevelTimer
    CMP #LEVEL_FRAMES
    BCC LevelDone
    LDA #$00
    STA LevelTimer
    LDA Level
    CMP #LEVEL_MAX
    BEQ LevelDone
    INC Level
    LDA Level
LevelWrite:                 ; A = the new level
    NOP
LevelDone:
```

The collision is read one frame late:

```asm
    LDA CXP0FB
    AND #$40                ; bit 6: player 0 met the ball
    BEQ NoHit
    JSR ScoreAddOne
    JSR BeepStart
    LDA #BALL_START_Y
    STA BallY               ; respawn
NoHit:
    LDA #$00
    STA CXCLR
```

The ball's motion and the demo run before the score setup:

```asm
    LDA BallY
BallYRead:                  ; A = BallY before the step
    CMP #BALL_END_Y
    BCC BallStep
    LDA #BALL_START_Y
    STA BallY
    JMP BallMoved
BallStep:
    INC BallY
BallMoved:
    LDA BallY
    LSR
    STA BallRow
```

The auto-demo's seek target is `BALL_X - 4`; the player starts at 76 and stays there while the ball falls. P1 sweeps 48 → 112 → 48 in the same block.

#### Step 7 — Reading it back in Stella

Assemble with a symbol file and ask Stella for the checkpoints:

```bash
acme -f plain -l build/lesson50.sym -o build/lesson50.bin \
  lessons/part7-kernel-mastery/50-multi-zone-kernel/50-multi-zone-kernel.asm

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F15C' \
  docs/public/roms/part7-kernel-mastery/50-multi-zone-kernel/50-multi-zone-kernel.bin
```

Stella keeps one `-break` per run, so run each checkpoint separately. The symbol file resolves the labels; the addresses below are the ones this source produced. The zone boundaries report 46/5, 54/4, 228/6 and 229/2. `GameHmove` reports 51/2 (the store executes two cycles later, still in HBLANK). `ScoreHmove` reports 5/45 (the `WSYNC` stall one line before the store); `ScoreHmoveDone` reports 6/3, after the `HMOVE` has executed. `LevelWrite` reports `A = 1` at frame 121; `ScoreAdd` reports `A = 1` at frame 106.

### Checkpoints

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F04B` | 259/3 | the first VSYNC line |
| `VblankStart` | `$F059` | 0/5 | the first VBLANK line |
| `BodyStart` | `$F159` | 37/5 | visible line 0, the `ScoreDraw` call |
| `ScoreDraw` | `$F50D` | 37/11 | the library entry |
| `StatusStart` | `$F15C` | 46/5 | visible line 9, the level bar |
| `GameHmove` | `$F192` | 51/2 | the game's `HMOVE` in HBLANK |
| `PlayStart` | `$F19B` | 54/4 | visible line 17, the play kernel |
| `GroundStart` | `$F22A` | 228/6 | visible line 191, the ground |
| `OverscanStart` | `$F239` | 229/2 | the first blank line after the picture |
| `ScoreHmove` | `$F4C1` | 5/45 | the score `HMOVE`'s `WSYNC` stall |
| `ScoreHmoveDone` | `$F4C3` | 6/3 | the score `HMOVE` has executed |
| `ScoreAdd` | `$F4F6` | A = 1, 2, 3, 4 | the digit after a hit (frames 106/211/316/421) |
| `LevelWrite` | `$F084` | A = 1, 2, 3, 4 | the new level (frames 121/241/361/481) |
| `BallYRead` | `$F087` | A = 24…158 | the ball's top line before the step |
| `JoyLeft` | `$F0C8` | A = `P0X` | the left branch, under `-holdjoy0 L` |
| `JoyRight` | `$F0D3` | A = `P0X` | the right branch, under `-holdjoy0 R` |

`ScoreHmove` sits on the library's `STA HMOVE`; a breakpoint there reports the preceding `WSYNC`'s line and cycle (a Stella logging artefact for an instruction immediately after a `WSYNC`). `ScoreHmoveDone` is the label after the store and reports the `HMOVE`'s real line and cycle: 6/3, in HBLANK. Both labels are aliases of the library's `HmoveApply`/`HmoveDone`.

## What You Should See

The picture is a dashboard. Six white digits sit at the top, in the 48-pixel cell block from TIA X=56 to 103. Below them is the status zone: a gold bar in the far left and far right of the screen, one 4-pixel chunk per level, growing toward the centre as the level rises. Below that is the play area: a light-grey ceiling band, a dark background field with a red player near the bottom, a green enemy sweeping near the top, and a one-pixel gold ball falling from the top of the field. The field ends in a gold floor band, and the last visible line is a solid dark green ground.

![Stella running the Lesson 50 ROM with score 000001 and level 1: six white digits, a small gold chunk at each end of the status bar, a grey ceiling, a green enemy near the top, a gold ball, a red player at the bottom, a gold floor and a dark green ground line](/images/lesson50/dashboard.png)

*Score 000001, level 1. The status bar is one chunk (24 capture pixels) at each outer edge. The player is at TIA X=76, the ball at X=80. The capture is a window capture of the committed ROM; the title bar reads `Stella 7.0: "50-multi-zone-kernel"`.*

<RomPlayer rom="/roms/part7-kernel-mastery/50-multi-zone-kernel/50-multi-zone-kernel.bin" title="Lesson 50 — Multi-Zone Kernel" />

![Stella running the Lesson 50 ROM with score 000004 and level 4: the same dashboard, with the gold status bar four chunks wide at each end and the last digit of the score a 4](/images/lesson50/level4.png)

*Score 000004, level 4. The status bar is four chunks (96 capture pixels) at each outer edge. The enemy has swept to a new X; the player, the ball, the ceiling, the floor and the ground are unchanged. The capture is a window capture of the committed ROM; the title bar reads `Stella 7.0: "50-multi-zone-kernel"`.*

> **Capture method.** Both images are window captures of
> `docs/public/roms/part7-kernel-mastery/50-multi-zone-kernel/50-multi-zone-kernel.bin`
> in Stella 7.0. The pointer was parked outside the window before each capture; the title
> bars read `Stella 7.0: "50-multi-zone-kernel"`. The score and the level advance with
> time, so a fixed-wait capture cannot be aimed at a chosen pair. Stella was launched on
> the committed ROM, a burst of window captures was taken with the same `xwininfo` lookup
> the screenshot script uses, and the frames were selected by pixel analysis: the six
> digits were decoded against `ScoreFont`, and the status bar's left run was measured in
> 24-pixel chunks. The colours and positions below are decoded from the captured pixels
> with `capture x = 25 + 6 × TIA X` and `capture y = 107 + 3.15 × visible line`, not copied
> from a log.

Click the player screen once: Javatari starts muted until a user gesture. The ROM needs no input to show both states: the ball falls, the auto-demo catches it, and the score and level advance. Hold the joystick left or right to take over P0; releasing it hands control back to the auto-demo.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
# the zone boundaries
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F15C' \
  docs/public/roms/part7-kernel-mastery/50-multi-zone-kernel/50-multi-zone-kernel.bin
# the game HMOVE
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F192' \
  docs/public/roms/part7-kernel-mastery/50-multi-zone-kernel/50-multi-zone-kernel.bin
# the level and the score
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F084' \
  docs/public/roms/part7-kernel-mastery/50-multi-zone-kernel/50-multi-zone-kernel.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F4F6' \
  docs/public/roms/part7-kernel-mastery/50-multi-zone-kernel/50-multi-zone-kernel.bin
```

- **`$F159` (`BodyStart`)** is **37/5**, **`$F15C` (`StatusStart`)** is **46/5**, **`$F19B` (`PlayStart`)** is **54/4**, **`$F22A` (`GroundStart`)** is **228/6**, and **`$F239` (`OverscanStart`)** is **229/2**: the four zones and the 262-line frame.
- **`$F50D` (`ScoreDraw`)** is **37/11**: the library's entry, on visible line 0.
- **`$F192` (`GameHmove`)** is **51/2**: the game's `HMOVE`, before its store, in HBLANK. **`$F4C1` (`ScoreHmove`)** is **5/45** and **`$F4C3` (`ScoreHmoveDone`)** is **6/3**: the score's `HMOVE`, applied in VBLANK.
- **`$F084` (`LevelWrite`)** reports `A=1` at frame 121, `2` at 241, `3` at 361, `4` at 481: the level steps every 120 frames.
- **`$F4F6` (`ScoreAdd`)** reports `A=1` at frame 106, `2` at 211, `3` at 316, `4` at 421: the ball's fall plus the one-frame collision read is 105 frames.
- **`$F087` (`BallYRead`)** reports A=24, 25, 26, … on consecutive frames: the ball's top line advances one visible line per frame (the 2-line kernel draws two lines per step).
- **`$F0C8` (`JoyLeft`)** under `-holdjoy0 L` reports A=`$4B` (75), `$4A`, `$49`, `$48`, … — the left branch and the `DEC`. **`$F0D3` (`JoyRight`)** under `-holdjoy0 R` reports A=`$4D` (77), `$4E`, `$4F`, `$50`, … — the right branch and the `INC`.

The pixel checks decode the captures with the same mapping:

| Check | Capture | Measured | Expected |
|---|---|---|---|
| the score | both | `000001` / `000004`, exact match against `ScoreFont`; x=367–642, y=110–130 | six white digits, 48-pixel block at TIA 56–103, rows 1–7 |
| the status bar | `dashboard.png` | left run 24 px (one 24-px chunk), x=73–96; right run x=913–936 | level 1: chunk 2 (4 px per half) |
| the status bar | `level4.png` | left run 96 px (four chunks), x=73–168; right run x=841–936 | level 4: chunks 2–5 (16 px per half) |
| the status bar's rows | both | y=135–158 (8 visible lines) | visible 9–16 |
| the status bar's colour | both | `$1A` = RGB(205,205,52) | gold |
| the ceiling | both | y=160–184, `$0C` = RGB(210,210,209) | visible 17–24, grey |
| the player | both | x=481–528 (TIA 76–83), y=584–683 (visible 151–182), `$42` = RGB(158,19,18) | P0 at X=76, sixteen strip bytes at rows 67–82 |
| the enemy | `dashboard.png` | x=553–600 (TIA 88–96), y=198–297 (visible 29–60), `$C8` = RGB(81,179,80) | P1 sweeping, 32 scanlines at rows 6–21 |
| the enemy | `level4.png` | x=493–540 (TIA 78–86), same rows | P1 at a different sweep position |
| the ball | both | x=505–510 (TIA 80, one pixel wide), 24 capture rows = 8 visible lines, `$1A` | a 1×8 gold ball at X=80 |
| the floor | both | y≈684–708, `$1A` | visible 183–190, gold |
| the ground | both | y=710–711, `$C4` = RGB(40,121,39), full width | visible 191, dark green |
| the background | both | RGB(63,63,62) | `$02` |
| the HMOVE blanking | both | 48 capture px (8 TIA pixels) of black at x=25–72 on y=151–152 (visible line 14 = scanline 51) | the `HMOVE`'s left-edge blanking on chunks 0–1; no bar chunk lost |

The screenshot proves the visual state; the state log proves the values and the lines. Neither one alone is the whole claim. The one thing the screenshots cannot prove is the line budget; that is the zone labels and the 262-line frame, and the static arithmetic `9 + 8 + 174 + 1 = 192`.

## Exercises

### Exercise 1: Resize the Status Zone

**Challenge:** make the status zone 12 lines and take the four extra lines from the play zone, so the play area becomes 170 lines (85 rows × 2). The score stays 9 lines and the ground stays 1 line. Verify the new boundaries.

**Hints:**
1. `STATUS_LINES` becomes 12 and `PLAY_ROWS` becomes 85. `FIELD_END` and `P0_TOP` are derived, so they follow automatically.
2. `STATUS_WAIT = STATUS_LINES - 5` becomes 7: the four extra status lines are four more `WSYNC`s after `GameHmove`.
3. `PlayStart` moves from 54 to 58 (`37 + 9 + 12`), and `GroundStart` stays 228 (`37 + 191`). The score and the ground are unchanged.
4. The play kernel's three bands are still ceiling 4 + field 77 + floor 4 = 85 rows; `P0_TOP` becomes 65, so the player's 32 scanlines stay just above the floor at row 81.

**Expected Result:** `9 + 12 + 170 + 1 = 192`; the state log reports `StatusStart` 46, `PlayStart` 58, `GroundStart` 228, `OverscanStart` 229; the bar is four lines taller, the play area four lines shorter, and the score/level logic is unchanged; the play zone (and the ball) starts four lines lower while the head stays at visible 151–182, so the hit period shortens to 101 frames (the exercise's `ScoreAdd` is logged at frames 102/203/304/405/506). The ball can overlap the floor if missed; the auto-demo catches it. The solution assembles to exactly 4,096 bytes.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Add a Second Status Row

**Challenge:** add an 8-line timer bar under the level bar, so the status zone is 16 lines and the play zone is 166 lines (83 rows × 2). The timer bar must drain over the same 120-frame clock as the level.

**Hints:**
1. `STATUS_LINES` becomes 16 and `PLAY_ROWS` becomes 83; `PlayStart` becomes 62 (`37 + 25`).
2. Split the status zone into two halves. The positioning dance still ends with `GameHmove` on line 51; `STATUS_WAIT_1 = 3` ends lines 51–53 with the level bar latched. Then write the timer bar's three PF masks and use `STATUS_WAIT_2 = STATUS_LINES - 8 = 8` to end lines 54–61. `PlayStart` is 62.
3. The timer level is `15 - (LevelTimer >> 3)`: the timer bar steps down every eight frames and reloads with the level. Both bars use the same `LevelPF0/1/2` tables, so the timer bar is the level bar's countdown twin.
4. Keep the level bar's masks in X=Level and the timer bar's in X=TimerLevel; the two masks are written at different status lines, so no extra buffer is needed.

**Expected Result:** `9 + 16 + 166 + 1 = 192`; `StatusStart` 46, `PlayStart` 62, `GroundStart` 228, `OverscanStart` 229; two 8-line gold bars — the top one fills with the level, the bottom one drains with the timer. The score/level logic is unchanged; the play zone (and the ball) starts eight lines lower while the head stays at visible 151–182, so the hit period shortens to 97 frames (the exercise's `ScoreAdd` is logged at frames 98/195/292/389/486). The ball can overlap the floor if missed; the auto-demo catches it. The solution assembles to exactly 4,096 bytes.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Zone Budget Audit *(Stretch Goal)*

**Challenge:** add a `ZoneTable` and ACME assembly-time asserts that prove the zones total 192 visible lines and that the ground starts on scanline 228. A wrong total must stop the build with a clear error.

**Hints:**
1. Define `ZONE_SCORE_LINES = 9`, `ZONE_STATUS_LINES = STATUS_LINES`, `ZONE_PLAY_LINES = PLAY_ROWS * 2`, and `ZONE_GROUND_LINES = 1`.
2. Use `!if` with an `!error` body: `!if ZONE_SCORE_LINES + ZONE_STATUS_LINES + ZONE_PLAY_LINES + ZONE_GROUND_LINES != 192 { !error "the zones must total 192 visible lines" }`.
3. Add a second assert for the absolute boundary: `37 + 9 + STATUS_LINES + PLAY_ROWS*2` must be 228, or the ground line has moved.
4. Emit the table as four bytes; the asserts run at assembly time, so the table can never disagree with the constants. Test the failure by changing `STATUS_LINES` to 9 in a scratch copy: the build stops before producing a ROM.

**Expected Result:** the shipped source passes both asserts and still assembles to exactly 4,096 bytes; `ZoneTable` holds `9, 8, 174, 1` and `ZoneCount` is 4. Changing the status zone to 9 lines fails the build with `the zones must total 192 visible lines` (and the boundary assert).

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A zone is a line budget.** The dashboard is `9 + 8 + 174 + 1 = 192` visible lines, with absolute starts 46, 54, 228 and `OverscanStart` 229. A boundary is a scanline; the cycle at its label depends on the code just before it.
- ✅ **Different zones use different kernels.** The score is the WSYNC-first 48-pixel kernel from Lesson 39; the play area is Lesson 49's work-first 2-line kernel; the status and ground are simple latched playfield/background lines.
- ✅ **The score zone hands the players over blank.** `ScoreDraw` ends with `GRP0 = GRP1 = 0`, `VDEL` off, and P0/P1 still at 56/64; the status zone sets one-copy mode and repositions them.
- ✅ **Two HMOVEs, one per repositioning event.** `ScoreHmove` in VBLANK applies the score positions and the ball's fine offset; `GameHmove` in the status HBLANK applies the game positions. `HMBL` is cleared between them, or the ball is shifted twice.
- ✅ **A fixed-cost positioning routine protects the budget.** `SetGameP0` and `SetGameP1` each end with a `WSYNC`, so the variable divide-by-15 loop costs exactly two scanlines for every X and `PlayStart` cannot move with the joystick.
- ✅ **The play zone writes its playfield per band, not per row.** Ceiling, field and floor have constant `PF0/1/2` and `COLUPF`; writing them at the band's first line keeps each store ahead of its register's first chunk (PF2's first is chunk 12 at cycle 38.7). The row body is 44–48 cycles of the 152-cycle pair.
- ✅ **Collisions are one frame late.** `CXP0FB` bit 6 is read in the next VBLANK and cleared with `CXCLR`; the ball falls 24 → 128, the hit lands every 105 frames, and the level steps every 120, so the first four scores and levels still line up.

## What's Next

The dashboard draws two objects per player and one ball. When a game needs more objects than the TIA has players, it has to show them **half the time**: [Lesson 51: Flicker Sprites — More Than 2 Objects](/part7-kernel-mastery/51-flicker-sprites) alternates two 30 Hz frames, draws each selected object with a per-row skipdraw test inside a 2-line kernel, and explains why a still screenshot can show only one half of the picture.
