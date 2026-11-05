---
title: "Lesson 41: Game States — Title, Play, Game Over"
description: "One byte selects which program runs this frame: the state machine. Lesson 41 builds the title, play, and game-over states — a gold emblem, a falling ball, the CXP0FB hit latch, a 15-chunk bar, one SetState door for every transition, and an auto-demo that reaches every screen without input."
prev:
  text: "Lesson 40: BCD Arithmetic — Scores That Make Sense"
  link: "/part6-game-dev/40-bcd-arithmetic"
next:
  text: "Lesson 42: Difficulty and Progression"
  link: "/part6-game-dev/42-difficulty"
---

# Lesson 41: Game States — Title, Play, Game Over

> **Part 6: Game Development** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 06 (flags and comparisons), Lesson 11 (lookup tables), Lesson 27 (joystick input), Lesson 29 (the ball), Lesson 34 (frame counters), Lesson 38 (collision latches), Lesson 40 (the score/monitor display pattern)
> **You will learn:** how one state byte selects a whole per-frame program; why every transition should pass through one `SetState` door; how to reset a game on entry; how to read fire and the joystick per state; how the `CXP0FB` latch turns a contact into one hit; how three layouts share a 262-line frame; how an auto-demo makes a title/play/over loop reachable without input
> **You will build:** "the state machine" — a gold title emblem, a 16-line status bar, P0 and a falling ball, a 15-chunk hit bar, a red game-over field with a blinking fire bar, the `SetState` door, and three exercises: pause, attract mode, and a high-score byte

## Introduction

Lesson 40 built a monitor with four zones and rebuilt it every frame. The program still ran
one operation after another: there was no title screen, no game, and no end. A real game is
not one program. It is at least three: a **title** that waits for a player, a **play** screen
that moves and scores, and an **over** screen that reports the result and waits for a restart.
Each one reads different input and draws a different picture.

The usual beginner answer is a pile of flags: `if (started)`, `if (gameOver)`, `if
(paused)`. Every new screen adds another flag and another set of branches, and the combinations
multiply. A **state machine** replaces the pile with one byte. `GameState` holds 0, 1, or 2;
one dispatch in VBLANK runs the title, play, or over update; one dispatch in the visible kernel
chooses the title, play, or over layout. Every transition goes through one routine, `SetState`,
so the state's entry work — reset the score, respawn the ball, start a timer — cannot be
forgotten.

This lesson builds **the state machine**. The title shows a gold playfield emblem and a
blinking bar. Fire starts play: P0 moves, a ball falls, a P0–ball hit adds one to the 15-chunk
bar and beeps, and a missed ball ends the game. The over screen turns the field red and waits
for fire to return to the title. The companion program `41-game-states.asm` is the complete
ROM; the exercises add a pause state, an attract mode, and a high-score byte.

::: details TypeScript Equivalent
A state machine is a `switch` over an enum, with an update and a draw per state. The shape
transfers; the constraints do not:

```typescript
type GameState = 'title' | 'play' | 'over';

class Game {
  private state: GameState = 'title';
  private stateTimer = 180;
  private hits = 0;
  private playerX = 80;
  private ballX = 80;
  private ballY = 24;

  update(input: { fire: boolean; left: boolean; right: boolean }): void {
    switch (this.state) {
      case 'title':
        if (input.fire || --this.stateTimer <= 0) this.enter('play');
        break;
      case 'play':
        if (input.left) this.playerX = Math.max(8, this.playerX - 1);
        if (input.right) this.playerX = Math.min(144, this.playerX + 1);
        if (this.ballHitsPlayer()) {
          this.hits = Math.min(15, this.hits + 1);
          this.ballY = 24;
          this.ballX = this.playerX;
        }
        if (++this.ballY > 180) this.enter('over');
        break;
      case 'over':
        if (input.fire) this.enter('title');
        break;
    }
  }

  private enter(next: GameState): void {
    this.state = next;                    // the state byte first...
    if (next === 'play') {                // ...then the entry work
      this.hits = 0;
      this.playerX = 80;
      this.ballX = 80;
      this.ballY = 24;
      this.stateTimer = 0;
    }
    if (next === 'title') this.stateTimer = 180;
  }

  render(tia: Tia): void {
    if (this.state === 'title') this.drawTitle(tia);
    if (this.state === 'play') this.drawPlay(tia);
    if (this.state === 'over') this.drawOver(tia);
  }
}
```

The analogy breaks in four places. `render` is not a retained scene; it is a scanline-by-scanline
plan, and the state must choose a **kernel**, not a display list. `update` runs in VBLANK while
the beam is blanked; the 192 visible lines are drawn afterwards, one `WSYNC` at a time. The
collision is not an object intersection: the TIA sets a latch when drawn pixels overlap, and
the CPU reads it a frame later. And the whole `Game` object lives in 128 bytes of RAM, so the
state, the timers, and every position are bytes — there is no room for a scene graph or a
garbage collector.
:::

## Theory

### Section 1: Three Programs in One ROM

The state byte is the whole idea:

| `GameState` | State | Input that matters | What the frame does | Leaves when |
|---|---|---|---|---|
| `0` | title | fire, joystick direction | draws the gold emblem and the blinking bar | fire, or 180 quiet frames |
| `1` | play | joystick left/right | moves P0, drops the ball, counts a P0–ball hit | the ball passes Y=180 |
| `2` | over | fire | draws the red field, the final bar, the blinking fire bar | fire |

The byte is read twice per frame. In **VBLANK**, the state selects an update routine:

```asm
    LDA GameState
    CMP #1
    BEQ DoPlayState
    CMP #2
    BEQ DoOverState
    JMP TitleState
DoPlayState:
    JMP PlayState
DoOverState:
    JMP OverState
```

The `DoPlayState`/`DoOverState` trampolines are the real labels from the ROM: the state
routines are more than 127 bytes away, so a long branch needs a `JMP` target.

In the **visible kernel**, the same byte selects a layout. The title is a playfield picture, play
is a status bar plus two sprites, and over is a red field. The player never needs a text mode or
a score display to know which state is running: the picture **is** the state.

A state machine is not just tidier than a pile of flags. It makes the frame's work finite and
regular: one update path, one draw path, one set of variables. When the game grows — a pause
state, a level screen, a boss — you add a number and two branches, not another boolean that
interacts with every existing one.

::: tip Why the state byte is first in RAM
`GameState` lives at `$80`, the first byte of the lesson's RAM block. There is no hardware
reason; it is a reading convenience. In the Stella debugger, `$80` is the first byte on the
zero-page line, so the state is the first number you see. The rest of the block is ordered by
how often it is read in VBLANK: the timers, the hit count, the positions, the display bytes.
:::

### Section 2: One Door into a State

Every transition — title to play, play to over, over to title — executes the same routine:

```asm
SetState:
    STA GameState
StateChange:                ; checkpoint: A = the new state
    CMP #1
    BEQ EnterPlay
    CMP #2
    BEQ EnterOver
    ; state 0: title
    LDA #TITLE_DEMO_FRAMES
    STA StateTimer
    RTS
EnterPlay:
    LDA #$00
    STA Hits
    STA StateTimer
    STA AutoMove
    STA PrevColl
    LDA #BALL_START_X
    STA PlayerX
    STA BallX
    LDA #BALL_START_Y
    STA BallY
    RTS
EnterOver:
    LDA #$00
    STA StateTimer
    RTS
```

The routine stores the new state **first**. `STA GameState` does not change A, so the
`StateChange` checkpoint — the instruction immediately after the store — reports exactly the
value every transition used. That is the evidence the state machine is honest: the debugger
shows `A=1` on the title-to-play transition, `A=2` on the play-to-over transition, and `A=0`
on the over-to-title transition, without reading a flag or reconstructing a branch.

Entering play is more than changing a number. A fresh game needs a zero hit count, a fresh
ball at the top, P0 back at the center, and the auto-demo timers disarmed. Putting that work
behind the door means it cannot be skipped: every path that enters play runs it. The same
discipline applies to the title (restart the 180-frame clock) and over (stop the play timer).

::: tip The order of the reset matters
`EnterPlay` writes `Hits=0` before it writes the ball and P0. If the visible kernel runs
between those writes, it would draw a half-reset frame. It cannot: `SetState` is called in
VBLANK, and the visible kernel starts only after `+wait_timer` and `STA VBLANK`. The whole
entry sequence is over before the beam reaches the first visible line.
:::

### Section 3: Per-State Input

Fire and SELECT are **edges**, not levels. Holding a button should not repeat a transition 60
times per second. The joystick is different: left and right are **levels**, and a held
direction moves P0 every frame.

**Fire** is `INPT4` bit 7, which is 0 while the button is held. `EOR #$80` flips it to 1 =
pressed, and the edge is `pressed & ~previous`:

```asm
    LDA INPT4
FireRead:                   ; checkpoint: A = INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire             ; NewFire = pressed & ~wasPressed
```

The title uses `NewFire` to enter play at once; the over screen uses it to return to the title.
The play screen ignores it. A held button makes one edge, so returning to the title does not
immediately fire again and skip the title.

**The joystick** is `SWCHA` bits 6 and 7 for P0 left and right (0 = pressed). It is a level:
the code reads it every frame, and a held direction moves P0 one pixel per frame, clamped to
8–144. The title screen does not move anything; it uses the four direction bits as a "someone
is here" signal: any direction reloads the 180-frame auto-start clock. That is the difference
between a demo and a game — the demo waits for an empty room, not for a button.

**SELECT** is `SWCHB` bit 1 (0 = pressed). The main ROM does not read it; exercise 1 adds the
pause toggle. The bit table is in `include/vcs.asm`, and the edge code is the same
`pressed & ~previous` pattern. The console switches are not joystick bits, but they are still
one active-low input bit.

### Section 4: The Ball and the Hit

The ball is 8 rows tall, 1 pixel wide, gold (`COLUPF=$1A`), and it falls one pixel per frame
from Y=24. P0 is 16 rows tall, 8 pixels wide, red (`COLUP0=$42`), at Y=140. A hit is not a
position comparison; it is the TIA's **collision latch**:

- `CXP0FB` bit 6 is the P0–ball pair. Bit 7 is P0–playfield; the lesson ignores it.
- A latch sets when the two objects' drawn pixels share a scanline and a color clock. It stays
  set until `CXCLR` is strobed.
- The read happens in VBLANK, so it describes the **previous** visible frame. The program is
  always one frame behind the picture; that latency is normal and documented.
- The lesson edge-detects the latch against `PrevColl`, so a contact that lasts several frames
  is one hit, not one per frame.

At the measured run the ball's last pre-hit row is 133: the ball's rows 133–140 overlap P0's
first row 140, so the latch is set. The next VBLANK reads `CXP0FB=$42` (bit 6 plus low noise),
the mask extracts `$40`, and `HitStep` reports `A=1`. The ball then respawns at Y=24 in P0's
column; in the same play frame it falls to 25. A fresh contact would need another 108 frames of
falling; in the auto-demo the next ball instead misses because P0 has moved.

When the ball passes Y=180, the state changes to over. `BALL_MISS_Y=181`: the ball is drawn at
180 (rows 180–187), then the next increment to 181 ends the game before it is drawn below the
play area.

### Section 5: Three Layouts, One 262-Line Frame

The frame is the same 262 lines as every lesson in this part: 3 VSYNC + 37 VBLANK + 192
visible + 30 overscan. Only the 192 visible lines change with the state.

**Title — 192 lines:**

| Visible lines | Count | What |
|---|---|---|
| 0–63 | 64 | background `$02` |
| 64–79 | 16 | gold block 1 (`PF2=$F0`, mirrored) |
| 80–87 | 8 | gap |
| 88–103 | 16 | gold block 2 |
| 104–111 | 8 | gap |
| 112–127 | 16 | gold block 3 |
| 128–159 | 32 | background |
| 160–167 | 8 | the blinking 15-chunk bar |
| 168–191 | 24 | background |

`PF2=$F0` lights chunks 16–19 in the left half; `CTRLPF=$01` reflects the right half, so the
two 16-pixel groups join into one 32-pixel centered block. The three blocks and the 8-line gaps
are the emblem. The bar is the same 15-chunk pattern as the hit bar, gated by `Frame & $20`.

**Play — 192 lines:**

| Visible lines | Count | What |
|---|---|---|
| 0–15 | 16 | the status bar: N chunks per half |
| 16 | 1 | the status bar ends; PF and sprites clear |
| 17–139 | 123 | the ball alone; P0 is off |
| 140–155 | 16 | P0 and the ball share these rows |
| 156 | 1 | P0's last row ends; the ball is drawn once |
| 157–191 | 35 | the ball alone again |

P0 is 16 rows at Y=140; the ball's 8 rows can be anywhere from 24 to 180. The kernel splits the
play area at P0's fixed rows so the middle zone can use a precomputed ball-enable byte: both
stores (`GRP0` and `ENABL`) land in HBLANK, which is why the P0 block starts at the left edge
even when P0 is at X=8. The top and bottom loops write `ENABL` before `WSYNC`. Their steady-state
store is at cycle ~24–25: after the 7-cycle `INX`/`CPX`/`BNE` loop tail and the 16-cycle compare
path, the write lands just before the earliest ball pixel at X=8, which is clock 76 (cycle
25.3). The first line of each loop is earlier (about cycle 20) because the loop tail has not run
yet.

**Over — 192 lines:**

| Visible lines | Count | What |
|---|---|---|
| 0–15 | 16 | the final hit bar |
| 16–159 | 144 | the red field (`COLUBK=$42`) |
| 160–167 | 8 | the blinking 15-chunk fire bar (white `$0E`) |
| 168–191 | 24 | the red field again |

The fire bar is precomputed in VBLANK into `FirePF0/1/2`. The visible kernel's three stores then
land before the playfield slots, so the first line of the bar is solid; the bar is 120 TIA
pixels wide (720 in the 6x capture), 15 chunks on each half.

The over screen's **first** line needs the same treatment for a different reason. BodyStart is
scanline 37 cycle 5, and the over kernel's first stores would not reach the left-half playfield
slots before they are drawn. The background (`COLUBK=$42`) and the top bar's `PF0/1/2` are
therefore preloaded in VBLANK while `GameState=2`, before `STA VBLANK`; the visible kernel only
disables the sprites and waits 16 lines. That makes line 0 as solid as lines 1–15.

The only horizontal motion is one `HMOVE` per frame. P0 is coarse-positioned with `SetCoarseP0`
at `PlayerX + 3`; the ball uses `SetCoarseBL` at `BallX + 4` (the ball's output delay is one
clock shorter than a player's, so it needs one extra pixel). Both fine values sit in `HMP0` and
`HMBL` until the single `STA HMOVE` applies them in HBLANK.

### Section 6: The Auto-Demo

A lesson ROM has to demonstrate itself. This one reaches every screen without a controller:

1. The title starts with `StateTimer=180`. Any joystick direction reloads it; if nothing
   happens, the counter reaches 0 and the title enters play. At the measured run the transition
   is at frame 180.
2. Play starts with P0 at X=80 and the ball at Y=24, X=80, so the first ball falls straight
   into P0. The hit is at frame 290; `Hits=1`; the status bar shows one chunk per half.
3. The first hit arms `StateTimer=30`. When it expires, the auto-demo sets `AutoMove` and slides
   P0 to the right, one pixel per frame, until X=144. The second ball still spawns at the old
   column (X=80), so it misses the moved P0 and reaches Y=181 at frame 446.
4. Over waits for fire. The over screen is a stable capture target: it never leaves on its own.

A manual left/right press takes control and clears `AutoMove`, so the reader can play normally.
Fire still starts play from the title and returns to the title from over. The demo is a
**fallback**, not a mode: it fills the silence, and the first real input takes over.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson41.bin lessons/part6-game-dev/41-game-states/41-game-states.asm
stella build/lesson41.bin
```

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 41: Game States — Title, Play, Game Over — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; What this program does:
;   "the state machine": one byte, GameState, selects which of three programs
;   runs this frame.  Every transition goes through SetState, so the state's
;   entry work (resetting the score, respawning the ball, starting a timer)
;   cannot be forgotten.
;
;     GameState = 0   TITLE     a gold emblem and a blinking bar
;     GameState = 1   PLAY      move P0, catch the falling ball
;     GameState = 2   OVER      a red field, the final hit bar, a blinking
;                               "fire" bar; fire returns to the title
;
;   The state is visible in the layout, not in a score: the title is a
;   playfield picture, play is a status bar plus P0 and the ball, and over
;   is a red field.  The hit bar is the only number, and it is a bar, not a
;   48-pixel score (Lesson 41 avoids the P0/P1 conflict the score kernel
;   needs).
;
; The screen (192 visible lines):
;   Title
;     visible 0-63      background
;     visible 64-79     gold block 1   (PF2=$F0, mirrored: a 32-px center)
;     visible 80-87     gap
;     visible 88-103    gold block 2
;     visible 104-111   gap
;     visible 112-127   gold block 3
;     visible 128-159   background
;     visible 160-167   the blinking 15-chunk bar (Frame & $20)
;     visible 168-191   background
;   Play
;     visible 0-15      the 16-line status bar: N gold chunks per half
;     visible 16-139    background; the ball falls through this zone
;     visible 140-155   P0 (16 rows, red $42) and the ball (8 rows, gold)
;     visible 156-191   background; the ball can still be here
;   Over
;     visible 0-15      the final hit bar
;     visible 16-159    the red field (COLUBK=$42)
;     visible 160-167   the blinking "fire" bar
;     visible 168-191   the red field
;   Every layout totals 192 lines; the next instruction is OverscanStart at
;   scanline 229.
;
; The game:
;   P0 starts at X=80, Y=140 and moves left/right with the joystick (clamp
;   8-144).  The ball starts at Y=24, X=PlayerX and falls one pixel per
;   frame.  CXP0FB bit 6 (P0-ball) is read in VBLANK and edge-detected; a new
;   contact adds one to Hits (clamp 15), beeps, and respawns the ball at
;   P0's X.  When the ball passes Y=180 the state changes to OVER.  Entering
;   play resets Hits, re-centers P0, and respawns the ball.
;
; The auto-demo (so the captures are deterministic):
;   The title's StateTimer starts at 180 frames and counts down while no
;   joystick direction is held; at zero it enters play.  Fire enters play
;   immediately.  In play, the first hit arms the timer at 30 frames; when
;   it expires the ROM slides P0 to the right, away from the ball's spawn
;   column, so the next ball misses and the OVER screen appears without any
;   input.  A manual left/right press takes control and cancels the slide.
;   Fire still starts play from the title and returns to the title from over.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), StateChange (A = the new state),
;   FireRead (A = INPT4), ReadCX (A = CXP0FB), CXClear (the strobe),
;   TimerRead (A = StateTimer's low byte), HitStep (A = the new hit count),
;   BallStep (A = the new BallY), BodyStart (37),
;   HmoveApply/HmoveDone (one per frame), OverscanStart (229).
;
;   StateTimer ($81) and BallY ($84) are the RAM values to watch: TimerRead
;   reports the title clock on its way from 180 to 1, and BallStep reports
;   the byte BallY receives each play frame.
;
; Build: acme -f plain -o build/lesson41.bin \
;        lessons/part6-game-dev/41-game-states/41-game-states.asm
; Run:   stella build/lesson41.bin     (click the screen to hear the beep)
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

TITLE_DEMO_FRAMES = 180  ; title frames before the auto-demo starts play
PLAY_DEMO_DELAY   = 30   ; frames after the first hit before P0 slides away

P0_Y           = 140     ; P0's top visible row
P0_HEIGHT      = 16
P0_MIN_X       = 8
P0_MAX_X       = 144
BALL_START_Y   = 24      ; the ball's first visible row at spawn
BALL_HEIGHT    = 8
BALL_MISS_Y    = 181     ; the first Y past the play area
BALL_START_X   = 80

TITLE_BLOCK    = $F0     ; PF2 bits 4-7: chunks 16-19, a 32-px center block

BEEP_FRAMES    = 8
BEEP_PITCH     = $0A     ; AUDF 10 on AUDC $0C: a short, bright hit

C_GOLD         = $1A
C_RED          = $42
C_WHITE        = $0E
C_BG           = $02

; --- Lesson variables (RAM $80-$9F; +clean_start zeroes them) ---
GameState   = $80   ; 0=title, 1=play, 2=over
StateTimer  = $81   ; the state's countdown: title auto-start / play slide
Hits        = $82   ; new contacts this game, clamped at 15
PlayerX     = $83   ; P0's left edge, 8..144
BallY       = $84   ; the ball's top row, 24..181
BallX       = $85   ; the ball's left edge, set when it spawns
BeepTimer   = $86   ; frames of beep remaining
BeepPitch   = $87   ; AUDF for the beep
Frame       = $88   ; free-running 8-bit frame counter (blinks use bit 5)
PrevFire    = $89   ; fire state last frame (1 = pressed)
PrevColl    = $8A   ; last frame's P0-ball latch bit ($40 or 0)
AutoMove    = $8B   ; 1 after the demo timer expires: P0 slides right
BallEn      = $8C   ; $8C-$9C: 17 ball-enable bytes for lines 140-156
HitPF0      = $9D   ; the hit bar's three playfield bytes for this frame
HitPF1      = $9E
HitPF2      = $9F
NewFire     = $A0   ; this frame's fire 0 -> 1 edge
CollTmp     = $A1   ; the P0-ball latch and then its 0 -> 1 edge
FirePF0     = $A2   ; the over screen's blinking fire bar, precomputed
FirePF1     = $A3
FirePF2     = $A4
;
; The shared score library is not used in this lesson, so the rest of
; $A5-$D7 is free.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the first scene: title, with the play positions already sensible ------
    LDA #BALL_START_X
    STA PlayerX
    STA BallX
    LDA #BALL_START_Y
    STA BallY
    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #0
    JSR SetState            ; A=0: title; SetState starts its timer

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
; 1. THE FRAME COUNTER — the blink clock
; -----------------------------------------------------------------------------
; Bit 5 toggles every 32 frames, so Frame & $20 is high for 32 frames and low
; for 32.  It drives the title's bottom bar and the over screen's fire bar.
    INC Frame

; -----------------------------------------------------------------------------
; 2. THE BEEP'S CLOCK — the last frame writes silence
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0
BeepDone:

; -----------------------------------------------------------------------------
; 3. READ FIRE — one action per 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR flips it to 1 = pressed; NewFire
; keeps only the press edge so holding the button does not repeat a
; transition.
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

; -----------------------------------------------------------------------------
; 4. READ THE COLLISION LATCH — the previous visible frame's P0-ball contact
; -----------------------------------------------------------------------------
; A latch stays set until CXCLR; reading it here describes frame N while the
; program builds frame N+1 (the one-frame latency from Lesson 38).  The mask
; keeps bit 6 ($40) and the edge is a 0 -> 1 change against last frame.
    LDA CXP0FB
ReadCX:                     ; checkpoint: A = CXP0FB
    AND #$40                ; bit 6 = P0-ball
    STA CollTmp             ; the current latch bit
    EOR PrevColl
    AND CollTmp
    TAX                     ; X = the 0 -> 1 edge ($40 or 0)
    LDA CollTmp
    STA PrevColl
    STX CollTmp             ; CollTmp = the new-contact bit
    LDA #$00
    STA CXCLR
CXClear:                    ; checkpoint: the latches are cleared

; -----------------------------------------------------------------------------
; 5. DISPATCH THE STATE — one of three per-frame programs
; -----------------------------------------------------------------------------
    LDA GameState
    CMP #1
    BEQ DoPlayState
    CMP #2
    BEQ DoOverState
    JMP TitleState
DoPlayState:
    JMP PlayState
DoOverState:
    JMP OverState
StateDone:

; -----------------------------------------------------------------------------
; 6. THE HIT BAR'S THREE BYTES — computed once, drawn by the play/over kernel
; -----------------------------------------------------------------------------
    LDA Hits
    ASL                     ; Hits * 3: three playfield bytes per entry
    CLC
    ADC Hits
    TAX
    LDA HitBarPF,X
    STA HitPF0
    LDA HitBarPF+1,X
    STA HitPF1
    LDA HitBarPF+2,X
    STA HitPF2

; -----------------------------------------------------------------------------
; 6b. THE OVER SCREEN'S FIRE BAR — precomputed, so its first line is solid
; -----------------------------------------------------------------------------
; The 15-chunk pattern is either present or dark, depending on Frame bit 5.
; Computing it here leaves the visible kernel with three short stores.
    LDA Frame
    AND #$20
    BEQ FireBarOff
    LDA HitBarPF+45
    STA FirePF0
    LDA HitBarPF+46
    STA FirePF1
    LDA HitBarPF+47
    STA FirePF2
    JMP FireBarDone
FireBarOff:
    LDA #$00
    STA FirePF0
    STA FirePF1
    STA FirePF2
FireBarDone:

; -----------------------------------------------------------------------------
; 7. THE BALL-ENABLE BYTES FOR LINES 140-156
; -----------------------------------------------------------------------------
; The play kernel's middle zone draws P0 and the ball on the same 17 lines.
; Precomputing the ball's enable byte keeps that loop to two stores, so both
; land in HBLANK (the timing note is in the walkthrough).  $02 enables the
; ball; $00 leaves it off.
    LDX #0
BallEnLoop:
    TXA
    CLC
    ADC #P0_Y               ; the line number, 140 + X
    SEC
    SBC BallY
    CMP #BALL_HEIGHT
    LDA #$00
    BCS BallEnOff
    LDA #$02
BallEnOff:
    STA BallEn,X
    INX
    CPX #(P0_HEIGHT + 1)    ; 17 entries: lines 140 through 156
    BNE BallEnLoop

; -----------------------------------------------------------------------------
; 8. POSITION P0 AND THE BALL, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; Both coarse resets happen here in VBLANK; the fine values sit in HMP0/HMBL
; until the single HMOVE applies them.  The ball's output delay is one clock
; shorter than a player's (Lesson 29), so its target needs one extra pixel.
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA BallX
    CLC
    ADC #(POS_BIAS + 1)
    JSR SetCoarseBL
    STA WSYNC
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed (next line, cycle 3)

; -----------------------------------------------------------------------------
; 9. COLORS, SIZES, AND PLAYFIELD CONTROL
; -----------------------------------------------------------------------------
    LDA #C_RED
    STA COLUP0              ; P0 is red
    LDA #C_GOLD
    STA COLUPF              ; the emblem, bars, and the ball are gold
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP1
    STA ENAM0
    STA ENAM1
    LDA #$01
    STA CTRLPF              ; reflect the playfield; ball one pixel wide

; --- the over state preloads its first visible line -------------------------
; BodyStart is scanline 37 cycle 5, but the left-half playfield slots are
; already being drawn before the over kernel's first stores could reach them.
; Loading the background and the top bar here, in VBLANK, makes line 0 as
; solid as lines 1-15.  The other states keep the $02 background and dark PF.
    LDA GameState
    CMP #2
    BNE OverPreloadDone
    LDA #C_RED
    STA COLUBK
    LDA HitPF0
    STA PF0
    LDA HitPF1
    STA PF1
    LDA HitPF2
    STA PF2
OverPreloadDone:

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDA GameState
    CMP #1
    BEQ DoPlayVisible
    CMP #2
    BEQ DoOverVisible
    JMP TitleVisible
DoPlayVisible:
    JMP PlayVisible
DoOverVisible:
    JMP OverVisible

; =============================================================================
; TITLE KERNEL — 192 lines: 64 + 16 + 8 + 16 + 8 + 16 + 32 + 8 + 24
; =============================================================================
TitleVisible:
    LDA #$00
    STA GRP0                ; the title is playfield only
    STA GRP1
    STA ENABL
    STA ENAM0
    STA ENAM1
    STA PF0
    STA PF1
    STA PF2

; --- visible 0-63: background ---
    LDY #64
TitleTop:
    STA WSYNC
    DEY
    BNE TitleTop

; --- visible 64-79: block 1 ---
    LDA #TITLE_BLOCK
    STA PF2                 ; chunks 16-19 (mirrored: a 32-px center block)
    LDY #16
TitleBlock1:
    STA WSYNC
    DEY
    BNE TitleBlock1

; --- visible 80-87: gap ---
    LDA #$00
    STA PF2
    LDY #8
TitleGap1:
    STA WSYNC
    DEY
    BNE TitleGap1

; --- visible 88-103: block 2 ---
    LDA #TITLE_BLOCK
    STA PF2
    LDY #16
TitleBlock2:
    STA WSYNC
    DEY
    BNE TitleBlock2

; --- visible 104-111: gap ---
    LDA #$00
    STA PF2
    LDY #8
TitleGap2:
    STA WSYNC
    DEY
    BNE TitleGap2

; --- visible 112-127: block 3 ---
    LDA #TITLE_BLOCK
    STA PF2
    LDY #16
TitleBlock3:
    STA WSYNC
    DEY
    BNE TitleBlock3

; --- visible 128-159: background ---
    LDA #$00
    STA PF2
    LDY #32
TitleMiddle:
    STA WSYNC
    DEY
    BNE TitleMiddle

; --- visible 160-167: the blinking 15-chunk bar ---
    LDA Frame
    AND #$20                ; high for 32 frames, low for 32
    BEQ TitleBarOff
    LDA HitBarPF+45         ; entry 15: PF0=$F0, PF1=$FF, PF2=$07
    STA PF0
    LDA HitBarPF+46
    STA PF1
    LDA HitBarPF+47
    STA PF2
    JMP TitleBarLines
TitleBarOff:
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
TitleBarLines:
    LDY #8
TitleBottomBar:
    STA WSYNC
    DEY
    BNE TitleBottomBar

; --- visible 168-191: background ---
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #24
TitleBottom:
    STA WSYNC
    DEY
    BNE TitleBottom
    JMP FrameEnd

; =============================================================================
; PLAY KERNEL — 192 lines: 16 status + 1 + 123 + 16 + 1 + 35
; =============================================================================
PlayVisible:
; --- visible 0-15: the 16-line status bar (N chunks per half) ---
    LDA HitPF0
    STA PF0
    LDA HitPF1
    STA PF1
    LDA HitPF2
    STA PF2
    LDY #16
PlayStatus:
    STA WSYNC
    DEY
    BNE PlayStatus

; --- visible 16: the status bar ends; clear the playfield and sprites ------
; All five stores happen before PF0's first visible slot (cycle 22.7), so
; line 16 shows the play area, not a partial status line.
    LDA #$00
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA WSYNC               ; end visible line 16

; --- visible 17-139: the ball alone; P0 is off ---
    LDX #(P0_Y - 123)       ; 17: one line was drawn above
PlayTop:
    TXA
    SEC
    SBC BallY
    CMP #BALL_HEIGHT
    LDA #$00
    BCS PlayTopOff
    LDA #$02
PlayTopOff:
    STA ENABL
    STA WSYNC
    INX
    CPX #P0_Y
    BNE PlayTop

; --- visible 140-155: P0 (16 rows) and the ball share these lines ---
    LDA #$FF
    STA GRP0                ; P0 is on for its 16 rows
    LDX #0
PlayBoth:
    LDA BallEn,X            ; precomputed: $02 where the ball is present
    STA ENABL
    STA WSYNC
    INX
    CPX #P0_HEIGHT
    BNE PlayBoth

; --- visible 156: P0's last row is over; clear it and draw the ball once --
    LDA #$00
    STA GRP0                ; before P0's first visible clock
    LDA BallEn+P0_HEIGHT    ; entry 16 covers line 156
    STA ENABL
    STA WSYNC               ; end visible line 156

; --- visible 157-191: the ball alone again ---
    LDX #(P0_Y + P0_HEIGHT + 1)   ; 157
PlayBottom:
    TXA
    SEC
    SBC BallY
    CMP #BALL_HEIGHT
    LDA #$00
    BCS PlayBottomOff
    LDA #$02
PlayBottomOff:
    STA ENABL
    STA WSYNC
    INX
    CPX #192
    BNE PlayBottom
    JMP FrameEnd

; =============================================================================
; OVER KERNEL — 192 lines: 16 bar + 144 red + 8 fire bar + 24 red
; =============================================================================
OverVisible:
    LDA #$00
    STA GRP0                ; the over screen is playfield only
    STA GRP1
    STA ENABL
    STA ENAM0
    STA ENAM1

; --- visible 0-15: the final hit bar (PF and COLUBK preloaded in VBLANK) ---
    LDY #16
OverBar:
    STA WSYNC
    DEY
    BNE OverBar

; --- visible 16-159: the red field; COLUPF changes to white for the fire bar
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA #C_WHITE
    STA COLUPF
    LDY #(160 - 16)
OverField:
    STA WSYNC
    DEY
    BNE OverField

; --- visible 160-167: the blinking "fire" bar (precomputed, 15 chunks) ---
    LDA FirePF0
    STA PF0
    LDA FirePF1
    STA PF1
    LDA FirePF2
    STA PF2
    LDY #8
OverFire:
    STA WSYNC
    DEY
    BNE OverFire

; --- visible 168-191: the red field again ---
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #24
OverBottom:
    STA WSYNC
    DEY
    BNE OverBottom
    JMP FrameEnd

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
FrameEnd:
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; TITLE STATE — the auto-demo clock and the fire transition
; =============================================================================
; Any joystick direction restarts the countdown, so an untouched console
; enters play after TITLE_DEMO_FRAMES; fire enters play at once.  The
; transition goes through SetState, which resets the play variables.
TitleState:
    LDA SWCHA
    AND #$F0                ; P0 up/down/left/right (0 = pressed)
    CMP #$F0
    BEQ TitleNoInput
    LDA #TITLE_DEMO_FRAMES
    STA StateTimer
TitleNoInput:
    LDA StateTimer
TimerRead:                  ; checkpoint: A = StateTimer, the state's clock
    BEQ TitleStart
    DEC StateTimer
    BNE TitleCheckFire
    ; The decrement reached zero: 180 title frames have passed.
    JMP TitleStart
TitleCheckFire:
    LDA NewFire
    BNE TitleStart
    JMP StateDone
TitleStart:
    LDA #1
    JSR SetState
    JMP StateDone

; =============================================================================
; PLAY STATE — movement, the hit, the fall, and the miss
; =============================================================================
PlayState:
; --- the auto-demo's slide timer: armed by the first hit ---
    LDA StateTimer
    BEQ PlayTimerDone
    DEC StateTimer
    BNE PlayTimerDone
    LDA #1
    STA AutoMove
PlayTimerDone:

; --- P0's motion: the joystick, or the auto-demo's slide ---
    LDA SWCHA
    AND #$C0                ; P0 left (bit 6) and right (bit 7)
    CMP #$C0
    BNE PlayManual
    LDA AutoMove
    BEQ PlayMoveDone
    JMP MoveRight
PlayManual:
    LDA #$00
    STA AutoMove            ; a manual direction takes control
    LDA SWCHA
    AND #$40                ; left
    BNE PlayNoLeft
    JMP MoveLeft
PlayNoLeft:
    LDA SWCHA
    AND #$80                ; right
    BNE PlayMoveDone
    JMP MoveRight
PlayMoveDone:

; --- a new P0-ball contact: score, beep, respawn ---
    LDA CollTmp
    BEQ NoHit
    INC Hits
    LDA Hits
    CMP #16
    BCC HitsStored
    LDA #15                 ; the bar has only 15 chunks
HitsStored:
    STA Hits
HitStep:                    ; checkpoint: A = the new hit count
    JSR BeepStart
    LDA #BALL_START_Y       ; respawn at the top...
    STA BallY
    LDA PlayerX             ; ...in P0's column
    STA BallX
    LDA Hits
    CMP #1
    BNE NoHit
    LDA #PLAY_DEMO_DELAY    ; after the first hit, arm the slide
    STA StateTimer
NoHit:

; --- the ball falls one pixel per frame; past 180 ends the game ---
    INC BallY
    LDA BallY
BallStep:                   ; checkpoint: A = the new BallY
    CMP #BALL_MISS_Y
    BCC PlayDone
    LDA #2
    JSR SetState
PlayDone:
    JMP StateDone

MoveLeft:
    DEC PlayerX
    LDA PlayerX
    CMP #P0_MIN_X
    BCS MoveDone
    LDA #P0_MIN_X
    STA PlayerX
    JMP MoveDone
MoveRight:
    INC PlayerX
    LDA PlayerX
    CMP #(P0_MAX_X + 1)
    BCC MoveDone
    LDA #P0_MAX_X
    STA PlayerX
MoveDone:
    JMP PlayMoveDone

; =============================================================================
; OVER STATE — fire returns to the title
; =============================================================================
OverState:
    LDA NewFire
    BEQ OverDone
    LDA #0
    JSR SetState
OverDone:
    JMP StateDone

; =============================================================================
; SetState — the one door into a state
; =============================================================================
; A = the new state.  Storing it first means the StateChange checkpoint
; reports exactly the value every transition used; the CMPs then run the
; state's entry work.  Entering play resets the game, not just the state
; byte: Hits, the timers, the ball, and P0's column all start fresh.
SetState:
    STA GameState
StateChange:                ; checkpoint: A = the new state
    CMP #1
    BEQ EnterPlay
    CMP #2
    BEQ EnterOver
    ; --- state 0: title ---
    LDA #TITLE_DEMO_FRAMES
    STA StateTimer
    RTS
EnterPlay:
    LDA #$00
    STA Hits
    STA StateTimer
    STA AutoMove
    STA PrevColl
    LDA #BALL_START_X
    STA PlayerX
    STA BallX
    LDA #BALL_START_Y
    STA BallY
    RTS
EnterOver:
    LDA #$00
    STA StateTimer
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
; COARSE POSITIONING — P0 and the ball, one HMOVE at the end
; =============================================================================
; A = the target TIA X plus POS_BIAS.  Each routine strobes its RESxx and
; leaves the fine value in its HMxx; the caller's single HMOVE applies both
; fine offsets in one HBLANK (the one-HMOVE rule from Lesson 28).
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
; same chunks from the right edge, so every count is "per half".
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
> `lessons/part6-game-dev/41-game-states/41-game-states.asm`.

### Code Walkthrough

#### Step 1 — Reset: positions, beep pitch, and the first `SetState`

`+clean_start` zeroes TIA and RAM and sets the stack. Reset writes the initial play positions
(`PlayerX=80`, `BallX=80`, `BallY=24`) and the beep pitch, then calls `SetState` with `A=0`.
That single call runs `StateChange` and the title's entry work: `StateTimer=180`. The first frame
therefore starts on a valid title screen, with the play variables already sensible for the
first transition.

#### Step 2 — VBLANK: the frame's fixed order

1. **The frame counter.** `INC Frame`. Bit 5 is the blink clock for the title bar and the fire
   bar; it toggles every 32 frames.
2. **The beep clock.** `BeepTimer` counts down; at zero `AUDV0=0`.
3. **Fire.** `INPT4` bit 7 is flipped to 1 = pressed and edge-detected into `NewFire`.
4. **The collision latch.** `CXP0FB` bit 6 is saved, edge-detected against `PrevColl`, and the
   latches are cleared with `CXCLR`. The edge is in `CollTmp` ($40 or 0).
5. **The state dispatch.** `GameState` selects `TitleState`, `PlayState`, or `OverState`. A
   transition calls `SetState`, which may change the state for this same frame's visible
   kernel.
6. **The hit bar's bytes.** `Hits × 3` indexes `HitBarPF`; the three playfield bytes go to
   `HitPF0/1/2`.
7. **The fire bar's bytes.** `Frame & $20` selects the 15-chunk pattern or zero; the result is
   `FirePF0/1/2`.
8. **The ball-enable buffer.** For each of lines 140–156, the buffer gets `$02` if the ball's 8
   rows cover that line, else `$00`. This is the middle zone's fast path.
9. **Positioning.** `SetCoarseP0` and `SetCoarseBL` set the coarse resets and fine values; one
   `STA HMOVE` applies both.
10. **Colors and control.** `COLUP0` red, `COLUPF` gold, `COLUBK=$02`, `CTRLPF=$01`. If
    `GameState=2`, the over background (`COLUBK=$42`) and the top bar's `PF0/1/2` are preloaded
    here, before `STA VBLANK`, so line 0 of the over screen is not clipped. `+wait_timer` then
    anchors the visible section at scanline 37.

`BodyStart` is scanline 37, visible line 0.

#### Step 3 — The title state

The title state reads the joystick's four direction bits. If any is pressed, it reloads
`StateTimer=180`; a quiet console lets the counter fall. The counter is decremented first, then
checked: when it reaches 0 the state enters play in the same frame. Fire is checked after the
decrement, so a press enters play before the timer expires. At the measured run the transition
is frame 180, and `TimerRead` logs `A=$B4` (180) at frame 1 down to `A=$01` at frame 180.

#### Step 4 — The play state

The play update runs in this order:

1. **The auto-demo slide timer.** `StateTimer` is 0 until the first hit arms it at 30. It counts
   down only in play; when it reaches 0 it sets `AutoMove`.
2. **Movement.** If a manual left/right bit is pressed, it clears `AutoMove` and moves one
   pixel. Otherwise, if `AutoMove` is set, it moves right. Both paths clamp to 8–144.
3. **The hit.** `CollTmp` is the edge from the previous frame's latch. A nonzero edge increments
   `Hits` (clamped at 15), starts the beep, respawns the ball at Y=24 and `PlayerX`, and arms the
   slide timer if this was the first hit.
4. **The fall.** `INC BallY`; `BallStep` reports the new value. If it is 181 or more, `SetState`
   enters over.

The measured sequence is `BallY=25` on the first play frame, `A=$85` (133) on the last frame
before the hit, `A=$19` (25) on the hit frame, and `A=$B5` (181) on the over frame.

#### Step 5 — The over state

Over is the simplest state: if `NewFire` is set, `SetState(0)` returns to the title and restarts
the 180-frame clock. The final hit count is not reset on entry, so the over screen can draw the
game's final bar; it is reset by the next `EnterPlay`.

#### Step 6 — `SetState` and the entry work

`SetState` is the only writer of `GameState`. `StateChange` sits immediately after the store, so
the checkpoint's A is the new state. The entry branches do the state's setup: the title reloads
180, play resets `Hits`, the timers, the ball, and P0, and over zeroes the play timer. Exercise 1
extends the door with an X argument so a pause exit can **resume** instead of resetting.

#### Step 7 — The three kernels

The title kernel writes the playfield pattern for each zone and waits. The 32-line background,
the 16-line blocks, the 8-line gaps, and the 24-line tail are all `LDY`/`DEY`/`BNE` loops of
`STA WSYNC`; the registers are written once per zone, in the previous line's HBLANK.

The play kernel has four parts. The status bar writes `HitPF0/1/2` at BodyStart and waits 16
lines. Line 16 clears PF and sprites and waits. The top loop (17–139) enables the ball per line
with a compare; the middle loop (140–155) reads `BallEn` and writes `GRP0=$FF` once at 140; line
156 clears `GRP0` and uses `BallEn+16`; the bottom loop (157–191) enables the ball per line
again. The status bar's PF writes land before PF0's first visible slot (cycle 22.7). The
top/bottom loops' steady-state `ENABL` store is at cycle ~24–25 — the 7-cycle loop tail plus the
16-cycle compare path — just before the earliest ball pixel at X=8 (clock 76, cycle 25.3); the
first line of each loop is earlier (about cycle 20).

The over kernel's top bar is preloaded in VBLANK: `COLUBK` and `HitPF0/1/2` are written while
`GameState=2`, before `STA VBLANK`, because the visible kernel's first stores would miss the
left-half slots. The kernel disables the sprites, holds 16 bar lines, sets `COLUPF` white for the
field, holds 144 red lines, writes the precomputed fire bytes, holds 8 lines, and holds 24 red
lines. The line counts are 16 + 144 + 8 + 24 = 192.

#### Step 8 — Reading it back

```bash
acme -f plain -l build/lesson41.sym -o build/lesson41.bin \
  lessons/part6-game-dev/41-game-states/41-game-states.asm
grep -E "StartFrame|VblankStart|StateChange|FireRead|ReadCX|CXClear|TimerRead|HitStep|BallStep|BodyStart|HmoveDone|OverscanStart" build/lesson41.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F358' \
  docs/public/roms/part6-game-dev/41-game-states/41-game-states.bin
```

Stella keeps one `-break` per run — the last one on the command line — so run one checkpoint at
a time.

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F026` | **259, cycle 3** | the first VSYNC line |
| `VblankStart` | `$F034` | 0, cycle 5 | the first VBLANK line |
| `StateChange` | `$F358` | A=0 at reset; A=1 at frame 180; A=2 at frame 446; A=0 on fire from over | the new state, straight from the store |
| `TimerRead` | `$F2AB` | A=`$B4` (180) at frame 1 → A=`$01` at frame 180 | the title's `StateTimer` low byte |
| `FireRead` | `$F04D` | A=`$8C` while fire is released | `INPT4`; bit 7 is the button |
| `ReadCX` | `$F063` | A=`$02` at rest; A=`$42` on the contact frame | `CXP0FB`; bit 6 is P0–ball |
| `CXClear` | `$F076` | A=0 | the `CXCLR` strobe |
| `HitStep` | `$F307` | A=1 at frame 290 | the new hit count |
| `BallStep` | `$F320` | A=`$19` (25) at frame 181; A=`$85` (133) at frame 289; A=`$B5` (181) at frame 446 | the new `BallY` |
| `BodyStart` | `$F12A` | **37, cycle 5** | visible line 0 |
| `HmoveApply` | `$F0E9` | 11, cycle 56 | the `WSYNC` stall before the one `HMOVE` |
| `HmoveDone` | `$F0EB` | 12, cycle 3 | the store has executed |
| `OverscanStart` | `$F289` | **229, cycle 7** | overscan's first line |

The two RAM values the dispatch calls out are `StateTimer` at `$81` and `BallY` at `$84`.
`TimerRead` reports the timer byte every title frame; `BallStep` reports the byte `BallY`
receives every play frame. The state log above is the proof that the timer counts only in its
state and that the ball freezes when the state changes.

## What You Should See

**Title.** A dark `$02` field with three gold bars stacked in the center — three 16-line blocks
with 8-line gaps, 32 pixels wide because the playfield is mirrored. At the bottom, a 15-chunk
gold bar per half (two segments with a centre gap) blinks on and off every 32 frames. There are
no sprites: the title is playfield only. The capture shows visible lines 64–79, 88–103, and
112–127 gold; the bar is on at lines 160–167. The three blocks are centered at TIA X=64–95,
which is capture x=409–601.

![Stella running the Lesson 41 ROM on the title screen: three gold bars stacked in the center of a dark field, with a gold 15-chunk bar per half (two segments with a centre gap) at the bottom](/images/lesson41/title.png)

*The title: three 32-pixel gold blocks and the blinking bottom bar. The capture is from the
committed ROM; the bar's phase is `Frame & $20`.*

**Play.** A 16-line status bar at the top shows the hit bar: zero chunks at the start, one gold
chunk per half after the first hit. P0 is the red 8×16 block at Y=140; the ball is the gold
1×8 block falling from Y=24 in P0's column. The auto-demo starts play at frame 180, the first
hit lands at frame 290, and the ball that follows is missed because P0 has slid to X=144.

**Over.** The field turns red (`$42`). The top 16 lines show the final hit bar — one gold chunk
per half after the auto-demo's single hit; all 16 lines are solid because the bar is preloaded
in VBLANK. The bottom 8 lines show the blinking 15-chunk fire bar in white — 15 chunks per half,
two segments with a centre gap; it is on for 32 frames and off for 32. Fire returns to the
title.

![Stella running the Lesson 41 ROM on the game-over screen: a red field, a one-chunk gold bar in each top corner, and a white 15-chunk fire bar per half (two segments with a centre gap) at the bottom](/images/lesson41/over.png)

*Over: the red field, the final one-chunk hit bar, and the blinking fire bar. The capture is
from the committed ROM.*

> **Capture method.** The title and over images are Stella debugger `saveSnap` TIA frames at
> frames 40 and 500 from the committed ROM, placed in the window chrome of a Stella window
> capture of the same ROM; no game pixel is synthesized.

<RomPlayer rom="/roms/part6-game-dev/41-game-states/41-game-states.bin" title="Lesson 41 — Game States" />

Click the player screen once: Javatari starts muted until a user gesture. The auto-demo reaches
the title, play, and over screens without input; press fire to start play yourself, and use the
joystick to catch the ball.

The debugger writes the same story as numbers:

- **`$F358` (`StateChange`)**: A=0 at frame 0 (reset), A=1 at frame 180 (title timer), A=2 at
  frame 446 (ball passed 180). With fire on the over screen, A=0 and the title timer restarts.
- **`$F2AB` (`TimerRead`)**: A=`$B4` (180) at frame 1, A=`$B3` (179) at frame 2, … A=`$01` at
  frame 180. The title timer counts only in the title state; the play slide timer counts only in play.
- **`$F307` (`HitStep`)**: A=1 at frame 290, the first P0–ball contact.
- **`$F320` (`BallStep`)**: A=`$19` (25) at frame 181, A=`$85` (133) at frame 289, A=`$19` (25)
  at frame 290 (the respawn), A=`$B5` (181) at frame 446 (the miss).
- **`$F04D` (`FireRead`)**: A=`$8C` while fire is released; bit 7 is 1. `$F063` (`ReadCX`)
  reports A=`$02` at rest and A=`$42` on the contact frame; bit 6 is the P0–ball latch.
- **`$F12A` (`BodyStart`)** 37/5 and **`$F289` (`OverscanStart`)** 229/7 — the 262-line frame.
- **`$F0E9` (`HmoveApply`)** 11/56 and **`$F0EB` (`HmoveDone`)** 12/3 — one `HMOVE` per frame.

With the debugger open on a visible frame, `GameState` is `$80`, `StateTimer` is `$81`, `Hits` is
`$82`, `PlayerX` is `$83`, `BallY` is `$84`, and `BallX` is `$85`. The hit bar's bytes are
`$9D–$9F`; the ball-enable buffer is `$8C–$9C`.

## Exercises

### Exercise 1: Pause

**Challenge:** add a fourth state, `PAUSE=3`, toggled by SELECT during play. The game freezes —
P0 and the ball keep their positions — and the status bar blinks. Expected: `StateChange` A=3
on the first SELECT, then A=1 on the next; `BallY` does not change while the state is 3.

**Hints:**
1. Read `SWCHB` bit 1 (0 = pressed) and build a `NewSelect` edge exactly like `NewFire`:
   `AND #$02`, `EOR #$02`, then `pressed & ~PrevSelect`.
2. At the top of `PlayState`, if `NewSelect` is set, enter state 3. In the new `PauseState`, if
   `NewSelect` is set, enter state 1. The pause state must not run the timer, the movement, the
   fall, or the collision.
3. `SetState` needs a second argument in X: `X=0` resets the game on a fresh play entry, `X=1`
   resumes. The pause exit uses `X=1`; every other call site uses `X=0`. The `StateChange`
   checkpoint still reports A = the new state.
4. The visible kernel must send state 3 to the play layout. To blink the status bar, zero
   `HitPF0/1/2` while `GameState=3` and `Frame & $20` is clear.
5. On the resume path, clear `PrevColl` (`LDA #0; STA PrevColl`). The VBLANK collision reader
   kept running during the pause, so it consumed the pause frame's latch. Clearing the tracker
   lets the frozen ball's still-overlapping contact score as a fresh hit after the resume.

**Expected Result:** `StateChange` logs A=3 on the pause press and A=1 on the resume. The
`BallStep` log has no entries between those frames: `BallY` stays at the value it had when the
pause began, and the next `BallStep` resumes from the same value. If the pause frame had a
contact, that contact scores as a fresh hit after the resume instead of being lost. The visible
pause screen is the play layout with the status bar blinking.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Attract Mode

**Challenge:** after 300 frames on the title with no fire, enter play automatically. Expected:
`StateChange` A=1 at frame 300; `StateTimer` counts down.

**Hints:**
1. 300 does not fit in one byte. Use a two-byte clock: `StateTimer` (`$81`) is the low byte and
   `StateTimerHi` (`$A5`) is the high byte. 300 is `$012C`: low `$2C`, high `$01`.
2. Reload both bytes when a joystick direction restarts the clock, and reload them in the
   title's `SetState` entry.
3. Decrement the low byte; when it wraps to `$FF`, decrement the high byte. After the
   decrement, OR the two bytes: zero means the 300th frame, so enter play right there.
4. The `TimerRead` checkpoint reports the low byte; watch `$A5` for the high byte.

**Expected Result:** `TimerRead` (the low byte) starts at `$2C` (44) at frame 1 with `$A5=1`;
the low byte counts 44 down to 1 and the high byte drops to 0 when the low byte borrows.
`StateChange` reports A=1 at frame 300. The rest of the auto-demo is unchanged: the first hit at
frame 410, the missed ball, and the over screen.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: High Score *(Stretch Goal)*

**Challenge:** keep the best `Hits` in `HighScore` across games and show it on the over screen as
a second bar. Expected: `HighScore` retains the maximum across two games.

**Hints:**
1. `HighScore` is a new byte at `$A5`. `+clean_start` zeroes it once at power-on; `EnterPlay`
   must not touch it, or the best score is lost on every restart.
2. Compare `Hits` with `HighScore` in `EnterOver`: if this game is higher, store it. Ties may
   store the same value; a lower game must keep the old byte.
3. The over kernel's second bar goes at visible 16–31. Precompute its three PF bytes in VBLANK
   from `HighScore × 3` into `HighPF0/1/2`; set `COLUPF` to green (`$C8`) before the bar and to
   white before the fire bar.
4. The line count becomes 16 (final bar) + 16 (high bar) + 128 (field) + 8 (fire) + 24 = 192.

**Expected Result:** the first game's `HighScoreStep` reports A=1 at frame 446. A game with a
lower final `Hits` leaves `HighScore` unchanged: with `HighScore` preset to 3, the over screen
shows one gold chunk at the top (this game) and three green chunks at visible 16–31 (the best).
`HighScore` survives the title and the next play entry.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **One byte selects the program**: `GameState` 0/1/2 chooses both the VBLANK update and the visible kernel; the layout is the visible proof of the state
- ✅ **Every transition uses `SetState`**: the state is stored first, then the entry work runs, so a reset cannot be forgotten
- ✅ **`StateChange` reports the new state**: A=1 on title-to-play, A=2 on play-to-over, A=0 on over-to-title
- ✅ **Fire and SELECT are edge-detected**: `INPT4` bit 7 and `SWCHB` bit 1 use `pressed & ~previous`; the joystick is a level and moves P0 while held
- ✅ **`CXP0FB` bit 6 is a latch**: read it in VBLANK, edge-detect it, and clear it with `CXCLR`; it describes the previous visible frame
- ✅ **Three layouts share 192 lines**: 64+16+8+16+8+16+32+8+24 for the title, 16+1+123+16+1+35 for play, 16+144+8+24 for over
- ✅ **The auto-demo makes the loop reachable**: 180 title frames, a hit at 290, a 30-frame slide, and a miss at 446; fire still works

## What's Next

The state machine now has a title, a play screen, and an end. It does not yet have a difficulty:
every game is the same speed, and the console's difficulty switches do nothing.
[Lesson 42: Difficulty and Progression](/part6-game-dev/42-difficulty) reads `SWCHB`'s switch
bits, adds a 15-entry speed table, and scales the enemy from level to level — and the state
machine gains a level bar, a lives display, and a restart flow.
