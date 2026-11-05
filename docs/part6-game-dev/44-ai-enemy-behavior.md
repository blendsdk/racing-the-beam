---
title: "Lesson 44: AI & Enemy Behavior — Chase, Patrol, Flee"
description: "One state byte and a distance: Lesson 44 gives the enemy a patrol route, a chase trigger at 24 pixels, a 60-frame flee with 32-pixel hysteresis, a colour-coded state row and a white distance bar — plus three exercises: waypoint pauses, a 16-pixel dead zone, and a switch-selected flee speed."
prev:
  text: "Lesson 43: Random Numbers — Unpredictable Fun"
  link: "/part6-game-dev/43-random-numbers"
next:
  text: "Lesson 45: Memory Management — 128 Bytes of Creativity"
  link: "/part6-game-dev/45-memory-management"
---

# Lesson 44: AI & Enemy Behavior — Chase, Patrol, Flee

> **Part 6: Game Development** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 06 (flags and comparisons), Lesson 27 (joystick input), Lesson 34 (frame counters), Lesson 38 (collision latches), Lesson 41 (the state-machine shape)
> **You will learn:** how one state byte selects between three movement programs; how `Distance = |PlayerX - EnemyX|` turns two positions into one number; how a signed delta moves an enemy toward or away from the player; how a 60-frame timer and a 32-pixel exit threshold stop chase/flee oscillation; how colour and a three-cell row make the state visible; how `CXPPMM` bit 7, a safe respawn, and 60 frames of invulnerability turn contact into a life
> **You will build:** "the hunter" — a patrolling enemy that chases when the player is far, flees when the chase gets too close or fire is pressed, shows its state in green/gold/red, and draws the gap as a white bar; plus three exercises: a 30-frame waypoint pause, a 16-pixel dead zone, and a switch-selected flee speed

## Introduction

Lesson 43 gave the game a source of surprise. A byte changed on its own, the seed row and the
history grid moved, and every four frames the speaker ticked. But the enemy was still a
mechanical thing: in Lesson 42 it bounced between two walls at a speed from a table. It had no
idea where the player was, so the player could learn it once and then ignore it.

This lesson gives the enemy a small brain. **The hunter** keeps one byte, `EnemyState`, and a
handful of positions. Every frame it measures `|PlayerX - EnemyX|` and chooses one of three
programs: **patrol** the line in green, **chase** the player in gold, or **flee** in red. The
chase starts when the player is farther than 24 pixels; a chase that closes to 24 pixels panics
and starts a 60-frame run; the run only ends when the timer has expired **and** the gap is past
32 pixels. A three-cell state row and the enemy's colour show the state; a white bar shows the
gap in 16-pixel chunks. A `CXPPMM` contact costs one of three lives.

The companion program `44-ai-enemy-behavior.asm` is the complete ROM: a 262-line frame, two
8×16 players on the same scanlines, one `HMOVE` for both, and a deterministic auto-demo that
needs no controller. The three exercises change the patrol into waypoints, add a 16-pixel dead
zone that stops the enemy from chattering at the chase boundary, and scale the flee speed with
the right difficulty switch.

::: details TypeScript Equivalent

The brain is a class with one mode field, one position, and one timer. The shape transfers; the
constraints do not:

```typescript
type Mode = "patrol" | "chase" | "flee";

class Hunter {
  mode: Mode = "patrol";
  x = 80;
  dir = 1;                     // the patrol direction
  timer = 0;                   // flee frames left

  static readonly MIN = 24;
  static readonly MAX = 136;

  // Returns the new x.  The ROM measures the distance at the end of the
  // previous frame, so the brain reads the gap the viewer already saw.
  step(playerX: number, fire: boolean): number {
    const distance = Math.abs(playerX - this.x);

    if (fire) {
      this.mode = "flee";
      this.timer = 60;
    }

    if (this.mode === "flee") {
      this.x += playerX >= this.x ? -2 : 2;          // away from the player
      if (this.timer > 0) this.timer--;
      if (this.timer === 0 && distance > 32) this.mode = "patrol";
    } else if (this.mode === "chase") {
      if (distance <= 24) {
        this.mode = "flee";
        this.timer = 60;
      } else {
        this.x += playerX >= this.x ? 2 : -2;        // toward the player
      }
    } else {
      if (distance > 24) {
        this.mode = "chase";
      } else {
        this.x += this.dir === 1 ? 1 : -1;           // the calm patrol
        if (this.x >= Hunter.MAX) this.dir = -1;
        if (this.x <= Hunter.MIN) this.dir = 1;
      }
    }

    this.x = Math.max(Hunter.MIN, Math.min(Hunter.MAX, this.x));
    return this.x;
  }
}
```

The analogy breaks in five places. There are no objects: the class's fields are fixed bytes at
`$80–$9C`, and `mode` is a number, not a string. The method is a chain of compares and branches;
the 6502 has no dispatcher and no `Math.abs`, only `CMP`, `BCC`, `SBC`, and a sign test. A
negative delta is a byte (`$FE` for −2), and adding it with `ADC` would carry, so the ROM turns
it into a magnitude and subtracts. The clamp is four explicit comparisons. And `step` is not
called for the picture: the state row, the colours, and the distance bar are a scanline plan
rebuilt every frame from the same bytes.

:::

## Theory

### Section 1: A Brain in One Byte

`EnemyState` holds 0, 1, or 2. Those are the only three values the program ever stores:

| Value | State | Movement | Leaves the state when |
|---|---|---|---|
| 0 | **patrol** | ±1 pixel per frame between X=24 and X=136; reverse at a wall | `Distance > 24` → chase; fire → flee |
| 1 | **chase** | ±2 pixels per frame toward the player | `Distance <= 24` → flee; fire → flee |
| 2 | **flee** | ±2 pixels per frame away from the player | `EnemyTimer` is 0 **and** `Distance > 32` → patrol |

The shape is Lesson 41's state machine applied to one object instead of the whole game. Every
transition goes through `SetEnemyState`, so the store and its checkpoint cannot be skipped:

```asm
SetEnemyState:
    STA EnemyState
EnemyStateWrite:            ; checkpoint: A = the new state
    RTS
```

**Why a patrolling enemy is calm.** The flee-on-proximity rule belongs to the chase, not to
patrol. If a patrol also ran away from a player within 24 pixels, the state would leave patrol on
the first frame and never return for more than one frame — the green state would exist only as a
theoretical value. The lesson's screen would lose one of its three states, and the auto-demo's
`patrol.png` would be impossible. So state 0 keeps walking when the player is close; state 1
panics when the chase has closed the gap. Fire panics any state. That is a deliberate rule, and
the source header repeats it.

### Section 2: Distance Is the Sensor

The enemy has no eyes, no line of sight, and no memory of the player. It has two x positions and
one subtraction. `Distance` is the absolute horizontal gap:

```asm
ComputeDistance:
    LDA PlayerX
    CMP EnemyX
    BCC PlayerIsLeft
    SBC EnemyX              ; C=1: A = PlayerX - EnemyX
    STA Distance
    LDA #1
    STA PlayerRight
    JMP DistanceDone
PlayerIsLeft:
    LDA EnemyX
    SEC
    SBC PlayerX
    STA Distance
    LDA #0
    STA PlayerRight
DistanceDone:
    LDA Distance
DistanceCalc:               ; checkpoint: A = the distance, 0..112
    RTS
```

`CMP` sets the carry when `PlayerX >= EnemyX`, and that same carry feeds the `SBC`, so the two
instructions are one unsigned subtraction. The other branch swaps the operands. The largest
possible gap is 136 − 24 = **112**, which fits in one byte with room to spare. `PlayerRight` costs
one more byte and saves the chase and flee routines from comparing the positions again.

The ROM measures the distance **after** both sprites have moved and **after** the life path, so
a respawn is included. That ordering is the same one-frame pipeline as Lesson 38's collision
read: the brain decides from the picture already on screen, then the new positions are measured
for the bar and for the next frame. The bar therefore matches the picture that is about to be
drawn, and the hit frame's bar (and the frozen red field's bar) show the post-respawn gap. In the
capture below, `Distance` is 23 and the bar has one chunk (`23 / 16 = 1`); the chase capture has
49 and three chunks.

::: tip The bar is a gauge, not a ruler
`Distance / 16` throws away the low four bits. A gap of 31 pixels and a gap of 16 pixels both
show one chunk. That is deliberate: a seven-step bar is readable at a glance, a 112-step bar is
not, and the brain uses the exact byte anyway. The bar tells you *which side of a threshold* the
enemy is on, not the exact pixel.
:::

### Section 3: Movement Is a Signed Delta

Each state ends by putting a signed delta in A: +1/−1 in patrol, +2/−2 in chase and flee. The
delta is the value the `EnemyMove` checkpoint reports:

| State | Toward the player | Away from the player |
|---|---|---|
| patrol | — (the direction comes from `EnemyDir`) | — |
| chase | `+2` when the player is to the right, `-2` when left | — |
| flee | — | `+2` when the player is to the left, `-2` when right |

The apply routine clamps the result to X=24…136. A naive `CLC / ADC EnemyX` cannot be used for a
negative delta: `$FF` is 255, so adding it produces a carry for every `EnemyX` of 1 or more and
the high clamp fires every time. The ROM converts the negative delta to a magnitude and subtracts:

```asm
ApplyDelta:
EnemyMove:                  ; checkpoint: A = the signed delta (+1, -1, +2, -2)
    STA EnemyDelta
    BPL DeltaPositive

; --- negative: A = |delta|, then EnemyX - |delta| -------------------------
    EOR #$FF
    CLC
    ADC #1                  ; two's complement: $FF -> 1, $FE -> 2
    STA EnemyStep
    LDA EnemyX
    SEC
    SBC EnemyStep
    CMP #ENEMY_MIN_X
    BCC DeltaLow
    STA EnemyX
    JMP DeltaDone
```

The positive path adds and checks the carry and the upper bound. Both paths end at `DeltaDone`,
which loads the new `EnemyX` so `EnemyXWrite` reports exactly the byte the sprite will use.

Patrol also turns at a wall. The turn is a direction flip plus a step the other way on the same
frame, so the enemy touches X=136 (or 24) and leaves immediately:

```asm
PatrolRight:
    LDA EnemyX
    CMP #ENEMY_MAX_X
    BEQ PatrolTurnLeft
    LDA #PATROL_STEP
    JMP ApplyDelta
PatrolTurnLeft:
    LDA #0
    STA EnemyDir
    LDA #$FF                ; -1
    JMP ApplyDelta
```

### Section 4: The Flee Clock and the Hysteresis

A single distance threshold cannot separate chase from flee. The chase moves toward the player
at 2 pixels per frame; the moment the gap reaches 24 the flee moves away at 2; the next frame the
gap is back above 24 and the chase starts again. The enemy would vibrate on the 24-pixel line
forever. Two mechanisms stop it:

1. **The 60-frame clock.** Entering flee loads `EnemyTimer=60`. The timer is decremented once per
   frame. The enemy cannot return to patrol until the timer is zero.
2. **The 32-pixel exit.** When the timer reaches zero, the enemy returns to patrol only if
   `Distance > 32`. If the player is still inside 32 pixels, the enemy stays in flee and keeps
   pushing away — a cornered enemy stays red at the wall until the player backs off.

The gap between 24 and 32 is the **hysteresis**. It is the same idea as a thermostat: turn on at
one temperature, turn off at another, so the system does not switch on every tiny change. The
state log below shows the result: state 2 at frame 137, state 0 at frame 197 — exactly 60 frames
later — and the distance at frame 196 is 112, well past 32.

Fire enters flee from any state and reloads the timer, so a second press extends the run. The
timer is also the only thing the `EnemyTimer` byte holds in the main ROM; exercise 1 reuses it
for the waypoint pause, which is safe because a patrol and a flee never run at the same time.

### Section 5: Three Cells, a White Bar, and 192 Lines

The 192 visible lines are five zones:

| Visible lines | Count | What |
|---|---|---|
| 0–7 | 8 | the state row: three 8-pixel cells per half, one lit |
| 8–15 | 8 | the distance bar: `Distance / 16` white chunks per half |
| 16–99 | 84 | the play area's top section, gold edge walls only |
| 100–115 | 16 | P0 (red) and P1 (state colour), both 16 rows tall |
| 116–191 | 76 | the play area's bottom section, gold edge walls only |

The total is 8 + 8 + 84 + 16 + 76 = 192. `BodyStart` is scanline 37 and `OverscanStart` is 229,
the same 262-line frame as every lesson in this part.

**The state row.** `PF0` bits 6–7 light chunks 2–3 (X=8–15), `PF1` bits 6–7 light chunks 4–5
(X=16–23), and `PF1` bits 4–5 light chunks 6–7 (X=24–31). Each state lights one 8-pixel cell:
patrol `PF0=$C0`, chase `PF1=$C0`, flee `PF1=$30`. `CTRLPF=$01` mirrors the half, so the right
edge gets the same three cells in reverse order: patrol at X=144–151, chase at 136–143, flee at
128–135. The lit cell uses the state colour, so the row and P1 are always the same colour.

**The distance bar.** The table has eight entries, 0–7 chunks, and each chunk is four pixels:

```asm
DistBarPF0:
    !byte $00,$10,$30,$70,$F0,$F0,$F0,$F0
DistBarPF1:
    !byte $00,$00,$00,$00,$00,$80,$C0,$E0
```

The bar grows from the left edge inward; the mirror copy grows from the right edge inward. It is
**white** (`$0E`), not gold. One playfield chunk (4 px) sits inside the 16-px left wall directly
below the bar; if the bar were gold, a one-chunk reading would be invisible — the bar's column
would merge into the gold wall. The colour is a reading aid, not decoration.

### Section 6: Contact, Lives, and the Red Field

Both players are drawn on visible lines 100–115. That shared band is what makes the TIA's
`CXPPMM` bit 7 (player 0–player 1) possible: the collision latch compares drawn pixels, and two
sprites on different scanlines can never touch. The read happens in VBLANK, so it describes the
previous visible frame, and the latch is cleared after the read:

```asm
    LDA CXPPMM
ReadCX:                     ; checkpoint: A = CXPPMM
    AND #$80                ; bit 7 = P0-P1
    STA CollBit
    EOR PrevColl
    AND CollBit
    TAX                     ; X = the 0 -> 1 edge ($80 or 0)
    LDA CollBit
    STA PrevColl
    STX CollBit             ; CollBit = the new-contact bit
    LDA #$00
    STA CXCLR
```

The edge test is the Lesson 38 pattern: an overlap that lasts several frames is one hit, not one
hit per frame. A new contact when `Invuln` is zero takes a life, beeps, and calls `RespawnEnemy`:

- If the player is in the right half (`PlayerX >= 80`), P1 respawns at X=24; otherwise at X=136.
  The respawn is never on top of the player.
- `Invuln=60` stops the next contact for 60 frames. P1 blinks during the window: `EnemyDraw` is
  `$FF` for four frames and `$00` for four (`Frame & $04`).
- At `Lives=0` the field freezes: `GameOver=1` turns `COLUBK` red, the play update is skipped,
  and P0 turns white so the frozen picture stays readable on the red field. Fire calls
  `StartGame`; the new game is drawn before the brain runs.
- `ComputeDistance` runs after the life block, so a respawn is already in the hit frame's bar and
  in the frozen red field's bar.

The life count is not a display in this lesson. The layout spends its 16 status lines on the
state row and the distance bar; `Lives` is a RAM byte at `$85` for the debugger and the beep is
the audible feedback. Lesson 42 makes the count visible with three life cells; this lesson
spends its 16 status lines on the state row and the distance bar instead.

### Section 7: The Auto-Demo and the Controls

A lesson ROM has to demonstrate itself. With no joystick input, the ROM moves P0 through a
two-phase demo:

| Phase | Frames | What P0 does |
|---|---|---|
| track | 120 | holds 18–22 and approaches from 23; the rightward phase rests at 23 because both sprites step together |
| provoke | 90 | runs away at 2 pixels per frame, which pushes the gap past 24 |

When the enemy is chasing, the demo runs away at 2 pixels per frame; when it is fleeing, the demo
holds still so the 60-frame clock and the 32-pixel exit are visible. The demo never collides —
a life is lost when the player deliberately walks into the enemy, which is possible in patrol
because the enemy is calm there. The first contact in the measured run is at frame 62 with a
continuous right hold (`-holdjoy0 R -turbo 1`); P0 is at X=126 and P1 at X=130.

The full input map is small:

| Input | Effect |
|---|---|
| Joystick left/right | moves P0 one pixel per frame, clamped to 24–136; overrides the demo and restarts its clock |
| Fire (0→1 edge) | enters flee from any state and reloads the 60-frame timer |
| No input | the track/provoke auto-demo above |

The joystick is a **level** (held), the fire button is an **edge** (`NewFire` is `pressed AND NOT
wasPressed`). The difference matters: a held fire must not re-arm the flee timer every frame.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson44.bin \
  lessons/part6-game-dev/44-ai-enemy-behavior/44-ai-enemy-behavior.asm
stella build/lesson44.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`. Each of the
four sources produces a 4,096-byte ROM.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 44: AI & Enemy Behavior — The Hunter — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; What this program does:
;   "the hunter": one byte, EnemyState, gives the enemy a small brain with
;   three modes.  It patrols a line, chases the player when the player is far
;   away, and flees when the chase gets too close or the fire button is
;   pressed.  A three-cell state row and the enemy's colour show the mode; a
;   distance bar shows |PlayerX - EnemyX| in 16-pixel chunks.
;
;     EnemyState = 0   PATROL   move +-1 between X=24 and X=136, reverse at
;                               the walls; green $C8
;     EnemyState = 1   CHASE    move toward the player at +-2; gold $1A
;     EnemyState = 2   FLEE     move away from the player at +-2 for at
;                               least 60 frames; red $42
;
;   Why a patrolling enemy is calm: the flee-on-proximity rule belongs to
;   the chase.  A patrol that ran away from a nearby player could never be
;   seen as a patrol, and the lesson's screen would lose one of its three
;   states.  So state 0 keeps walking when the player is close; state 1
;   panics when the chase has closed to 24 pixels.  Fire panics any state.
;
; The screen (192 visible lines, CTRLPF=$01 so the playfield is mirrored):
;   visible 0-7      the state row: three 8-pixel cells per half, one lit.
;                    Patrol lights the first cell (PF0=$C0), chase the
;                    second (PF1=$C0), flee the third (PF1=$30).  The lit
;                    cell uses the state colour, so the row and P1 match.
;   visible 8-15     the distance bar: N chunks per half, N = Distance/16
;                    (0-7).  The bar grows from the left edge inward; the
;                    mirror copy grows from the right edge inward.  White.
;   visible 16-99    the play area's top section: gold edge walls only
;                    (PF0=$F0, mirrored: X=0-15 and X=144-159).
;   visible 100-115  P0 (16 rows, red $42) and P1 (16 rows, state colour).
;                    Both sprites share these scanlines, which is what makes
;                    CXPPMM bit 7 (the P0-P1 collision) possible.
;   visible 116-191  the play area's bottom section: gold edge walls only.
;   The zones total 8+8+84+16+76 = 192 lines; OverscanStart is scanline 229.
;
; The game:
;   P0 starts at X=64 and moves left/right with the joystick (1 pixel per
;   frame, clamped to X=24..136).  P1 starts at X=80, direction right.  The
;   horizontal distance is recomputed every frame after both sprites move
;   and after the life path (so a respawn is included); the distance bar
;   matches the picture and the next frame's brain reads the gap the viewer
;   saw:
;
;     Distance = |PlayerX - EnemyX|
;
;   A state's movement is a signed delta in A: +1/-1 in patrol, +2/-2 in
;   chase and flee.  The delta is clamped to X=24..136 and written to
;   EnemyX; EnemyMove is the checkpoint at the top of that apply routine.
;
;   A P0-P1 contact (CXPPMM bit 7, read in VBLANK and edge-detected) costs a
;   life, beeps, respawns P1 on the side away from the player, and grants 60
;   frames of invulnerability (P1 blinks during it).  At 0 lives the
;   background turns red, the play update freezes, and fire starts a new
;   game.
;
; The flee clock and the hysteresis:
;   A fleeing enemy may only return to patrol when BOTH the 60-frame timer
;   has expired AND the distance is greater than 32.  The gap between the
;   chase trigger (distance > 24) and the patrol re-entry (distance > 32)
;   stops the enemy from flipping chase/flee/chase at the 24-pixel line.
;   While the timer has expired but the distance is still <= 32, the enemy
;   keeps running: a cornered enemy stays red until the player backs off.
;
; The auto-demo (so the captures are deterministic):
;   With no joystick input the ROM moves P0 for the player.  The demo has
;   two clocks: 120 frames of "track" and 90 frames of "provoke".
;     Patrol  track:   hold the distance at 18-22; the rightward phase rests at
;                      23 because both sprites step together, so the enemy
;                      keeps sweeping and the state row stays green.
;     Patrol  provoke: run away at 2 pixels per frame, which pushes the
;                      distance past 24 and starts a chase.
;     Chase:           run away at 2 pixels per frame; the enemy follows at
;                      2, so the chase lasts until P0 reaches a wall.
;     Flee:            hold still.  The enemy outruns P0 at 2 pixels per
;                      frame, so the 60-frame clock expires with the gap
;                      already past 32 and the enemy returns to patrol.
;   The joystick overrides the demo on any frame a direction is held.  Fire
;   always enters flee, in any state, and restarts the 60-frame clock.  A
;   life is lost only when P0 runs into P1; the joystick can do that in
;   patrol, where the enemy is calm.  The auto-demo itself never collides.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), ReadCX (A = CXPPMM),
;   CXClear (the strobe), EnemyStateWrite (A = the new state),
;   DistanceCalc (A = Distance), EnemyMove (A = the signed delta),
;   EnemyXWrite (A = the new EnemyX), LifeStep (A = the new life count),
;   BodyStart (37), HmoveApply (the WSYNC stall), HmoveDone (the HMOVE
;   store has executed), OverscanStart (229).
;   EnemyState is $80, EnemyX $81, EnemyTimer $83, PlayerX $84, Lives $85,
;   Distance $86, Invuln $87, GameOver $88.
;
; Build: acme -f plain -o build/lesson44.bin \
;        lessons/part6-game-dev/44-ai-enemy-behavior/44-ai-enemy-behavior.asm
; Run:   stella build/lesson44.bin     (click the screen to hear the beep)
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

ENEMY_MIN_X    = 24      ; P1's left edge at the left wall
ENEMY_MAX_X    = 136     ; P1's left edge at the right wall
PLAYER_MIN_X   = 24
PLAYER_MAX_X   = 136
PLAYER_START_X = 64
ENEMY_START_X  = 80

PATROL_STEP    = 1
CHASE_STEP     = 2
FLEE_STEP      = 2

CHASE_RANGE    = 24      ; patrol -> chase when Distance > 24
FLEE_RANGE     = 24      ; chase -> flee when Distance <= 24
FLEE_EXIT_RANGE = 32     ; flee -> patrol only when Distance > 32
FLEE_FRAMES    = 60
INVULN_FRAMES  = 60
HIT_PITCH      = $08     ; AUDF 8 on AUDC $0C: a short, bright hit

TRACK_FRAMES   = 120     ; the auto-demo's track phase
PROVOKE_FRAMES = 90      ; the auto-demo's run-away phase
TRACK_NEAR     = 18      ; track: back away below this distance
TRACK_FAR      = 22      ; track: approach above this distance

C_RED          = $42
C_GOLD         = $1A
C_GREEN        = $C8
C_WHITE        = $0E
C_BG           = $02

STATE_PATROL_PF0 = $C0   ; PF0 bits 6-7: chunks 2-3, X=8-15
STATE_CHASE_PF1  = $C0   ; PF1 bits 6-7: chunks 4-5, X=16-23
STATE_FLEE_PF1   = $30   ; PF1 bits 4-5: chunks 6-7, X=24-31

; --- Lesson variables (RAM $80-$9C; +clean_start zeroes them) --------------
EnemyState   = $80   ; 0=patrol, 1=chase, 2=flee
EnemyX       = $81   ; P1's left edge, 24..136
EnemyDir     = $82   ; patrol direction: 1 = right, 0 = left
EnemyTimer   = $83   ; flee frames remaining (the 60-frame clock)
PlayerX      = $84   ; P0's left edge, 24..136
Lives        = $85   ; 3 at the start, 0 = game over
Distance     = $86   ; |PlayerX - EnemyX|, 0..112, after the life path
Invuln       = $87   ; frames of invulnerability remaining
GameOver     = $88   ; 1 = the red frozen field; fire restarts
Frame        = $89   ; free-running 8-bit frame counter (blink uses bit 2)
PrevFire     = $8A   ; fire state last frame (1 = pressed)
NewFire      = $8B   ; this frame's fire 0 -> 1 edge
NeedStart    = $8C   ; 1 = the next VBLANK must start a game
PrevColl     = $8D   ; last frame's CXPPMM bit 7
CollBit      = $8E   ; this frame's CXPPMM bit 7, then its 0 -> 1 edge
PlayerRight  = $8F   ; 1 = PlayerX >= EnemyX, 0 = PlayerX < EnemyX
EnemyDelta   = $90   ; the signed movement delta chosen this frame
EnemyStep    = $91   ; |EnemyDelta| while it is applied to EnemyX
StatePF0     = $92   ; the state row's playfield bytes for this frame
StatePF1     = $93
DistPF0      = $94   ; the distance bar's playfield bytes for this frame
DistPF1      = $95
StateColor   = $96   ; the active state's colour ($C8, $1A, or $42)
EnemyDraw    = $97   ; $FF, or 0 during the invulnerability blink's off phase
BeepTimer    = $98   ; frames of beep remaining
BeepPitch    = $99   ; AUDF for the beep
AutoTimer    = $9A   ; the auto-demo's phase clock
AutoMode     = $9B   ; 0 = track, 1 = provoke
PlayerStep   = $9C   ; 1 or 2 while a player movement routine runs
;
; $9D-$D7 are free.  The shared score/random libraries are not used.
; The stack lives at $F8-$FF.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the first game starts in the first VBLANK -----------------------------
; Reset only marks the game as pending.  StartGame sets the positions, the
; three lives, and the patrol state, so a power-on and a fire restart use
; exactly the same door.
    LDA #1
    STA NeedStart
    LDA #HIT_PITCH
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
; 1. THE FRAME COUNTER AND THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
; Frame drives the invulnerability blink (bit 2: four frames on, four off).
; BeepTimer counts down every frame and silences channel 0 at zero.
    INC Frame

    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0               ; silence at the end of the tick
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — one action per 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while the fire button is pressed.  The EOR turns that into
; a 1, and the EOR/AND pair keeps only the new press, so holding the button
; does not re-arm the flee timer on every frame.
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
; 3. THE P0-P1 COLLISION LATCH
; -----------------------------------------------------------------------------
; Both players are drawn on visible lines 100-115, so CXPPMM bit 7 can set.
; The read is in VBLANK and therefore describes the previous visible frame.
; The latch is sticky until CXCLR, so the code keeps the previous bit and
; keeps only the 0 -> 1 edge: an overlap that lasts several frames is one hit.
    LDA CXPPMM
ReadCX:                     ; checkpoint: A = CXPPMM
    AND #$80                ; bit 7 = P0-P1
    STA CollBit
    EOR PrevColl
    AND CollBit
    TAX                     ; X = the 0 -> 1 edge ($80 or 0)
    LDA CollBit
    STA PrevColl
    STX CollBit             ; CollBit = the new-contact bit
    LDA #$00
    STA CXCLR
CXClear:                    ; checkpoint: the latches are cleared

; -----------------------------------------------------------------------------
; 4. START A GAME WHEN REQUESTED
; -----------------------------------------------------------------------------
    LDA NeedStart
    BEQ NoStartGame
    JSR StartGame
NoStartGame:

; -----------------------------------------------------------------------------
; 5. THE GAME-OVER FREEZE, OR THE PLAY UPDATE
; -----------------------------------------------------------------------------
; Game over keeps drawing the last frame; the background is red, set in the
; colour block below.  Fire calls StartGame and the new game runs this frame.
    LDA GameOver
    BEQ PlayUpdate
    LDA NewFire
    BEQ FrozenFrame
    JSR StartGame
    JSR ComputeDistance      ; the new game's bar, before the first picture
    JMP BuildDisplay
FrozenFrame:
    JMP BuildDisplay

PlayUpdate:

; -----------------------------------------------------------------------------
; 6. THE ENEMY'S BRAIN — state transitions, then movement
; -----------------------------------------------------------------------------
; UpdateEnemy reads Distance and PlayerRight, which ComputeDistance computed
; at the end of the previous frame (section 9).  The one-frame pipeline is the
; same shape as Lesson 38's collision read: the brain decides from the picture
; that is already on screen, and the new positions are measured afterwards.
    JSR UpdateEnemy

; -----------------------------------------------------------------------------
; 7. THE PLAYER — the joystick, or the auto-demo when no direction is held
; -----------------------------------------------------------------------------
; SWCHA is active low: bits 6 (left) and 7 (right) are 0 while pressed.  A
; manual direction cancels the demo's current phase and restarts its clock.
    LDA SWCHA
    AND #$C0                ; P0 left (bit 6) and right (bit 7)
    CMP #$C0
    BEQ AutoPlayer
    LDA #0
    STA AutoMode
    LDA #TRACK_FRAMES
    STA AutoTimer
    LDA SWCHA
    AND #$40                ; left
    BNE ManualNoLeft
    JSR MovePlayerLeft1
    JMP PlayerDone
ManualNoLeft:
    LDA SWCHA
    AND #$80                ; right
    BNE PlayerDone
    JSR MovePlayerRight1
    JMP PlayerDone
AutoPlayer:
    JSR AutoDemo
PlayerDone:

; -----------------------------------------------------------------------------
; 8. INVULNERABILITY AND THE LIFE COUNT
; -----------------------------------------------------------------------------
; Invuln counts down one frame at a time.  A new contact while Invuln is zero
; costs a life, beeps, respawns P1 away from the player, and re-arms 60
; frames.  At zero lives the field freezes and turns red.
    LDA Invuln
    BEQ InvulnDone
    DEC Invuln
InvulnDone:

    LDA CollBit
    BEQ NoLifeLost
    LDA Invuln
    BNE NoLifeLost
    LDA Lives
    SEC
    SBC #1
LifeStep:                   ; checkpoint: A = the new life count
    STA Lives
    LDA #HIT_PITCH
    STA BeepPitch
    JSR BeepStart
    JSR RespawnEnemy
    LDA #INVULN_FRAMES
    STA Invuln
    LDA Lives
    BNE NoLifeLost
    LDA #1
    STA GameOver            ; the next frame draws the red field
    LDA #0
    STA Invuln              ; stop the blink on the frozen field
NoLifeLost:

; -----------------------------------------------------------------------------
; 9. THE DISTANCE AND THE SIDE, MEASURED AFTER THE LIFE PATH
; -----------------------------------------------------------------------------
; Distance is |PlayerX - EnemyX|; PlayerRight records which side of the enemy
; the player is on.  Measuring after the moves AND after the life block means
; a respawn is included: the hit frame's bar shows the new gap, and the frozen
; red field keeps that gap.  The next frame's brain reads the same positions
; the viewer saw.
    JSR ComputeDistance

; -----------------------------------------------------------------------------
; 10. BUILD THE STATE ROW, THE DISTANCE BAR, AND THE BLINK
; -----------------------------------------------------------------------------
BuildDisplay:
; --- the state row: one 8-pixel cell per state, in the state's colour ------
    LDA EnemyState
    CMP #1
    BEQ BuildChase
    CMP #2
    BEQ BuildFlee
    LDA #STATE_PATROL_PF0
    STA StatePF0
    LDA #$00
    STA StatePF1
    LDA #C_GREEN
    STA StateColor
    JMP StateBuilt
BuildChase:
    LDA #$00
    STA StatePF0
    LDA #STATE_CHASE_PF1
    STA StatePF1
    LDA #C_GOLD
    STA StateColor
    JMP StateBuilt
BuildFlee:
    LDA #$00
    STA StatePF0
    LDA #STATE_FLEE_PF1
    STA StatePF1
    LDA #C_RED
    STA StateColor
StateBuilt:

; --- the distance bar: Distance / 16 chunks, 0..7 -------------------------
; Four LSRs divide by 16.  The table entry holds the PF0/PF1 bytes that light
; that many chunks from the left edge; CTRLPF's mirror repeats it on the
; right.  A zero distance leaves the bar dark.
    LDA Distance
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA DistBarPF0,X
    STA DistPF0
    LDA DistBarPF1,X
    STA DistPF1

; --- P1 blinks while it is invulnerable ------------------------------------
    LDA #$FF
    STA EnemyDraw
    LDA Invuln
    BEQ EnemyDrawDone
    LDA Frame
    AND #$04                ; four frames on, four off
    BNE EnemyDrawDone
    LDA #$00
    STA EnemyDraw
EnemyDrawDone:

; -----------------------------------------------------------------------------
; 11. POSITION BOTH PLAYERS, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; Both use the same +POS_BIAS target as Lesson 26/41/42.  Their fine values
; sit in HMP0/HMP1 until the single HMOVE applies both in one HBLANK (the
; one-HMOVE rule from Lesson 28).
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA EnemyX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
    STA WSYNC
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed (next line)

; -----------------------------------------------------------------------------
; 12. COLOURS, SIZES, CONTROL, AND THE FIRST VISIBLE LINE'S PLAYFIELD
; -----------------------------------------------------------------------------
; P0 is red; P1 takes the state colour, so the enemy and the state row agree.
; The state row's PF bytes and colour are preloaded here: BodyStart's first
; write would land in HBLANK anyway, but the preload makes line 0 as solid as
; the rest of the row.
    LDA #C_RED
    STA COLUP0
    LDA GameOver
    BEQ PlayerColorDone
    LDA #C_WHITE            ; keep P0 visible on the red game-over field
    STA COLUP0
PlayerColorDone:
    LDA StateColor
    STA COLUP1
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA NUSIZ0              ; both players are one 8-pixel copy
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    LDA #$01
    STA CTRLPF              ; reflect the playfield; ball one pixel wide

; --- the game-over field is red --------------------------------------------
    LDA GameOver
    BEQ PreloadStateRow
    LDA #C_RED
    STA COLUBK
PreloadStateRow:
    LDA StateColor
    STA COLUPF
    LDA StatePF0
    STA PF0
    LDA StatePF1
    STA PF1
    LDA #$00
    STA PF2

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- visible 0-7: the state row (PF and COLUPF preloaded in VBLANK) -------
    LDY #8
StateRow:
    STA WSYNC
    DEY
    BNE StateRow

; --- visible 8-15: the distance bar (white) -------------------------------
; White separates the bar from the gold wall directly below it: a one-chunk
; bar inside X=0-15 would otherwise be invisible against the wall.  The first
; column's writes land at cycles 5-22 of visible line 8, before PF0's first
; visible slot at cycle 22.7.
    LDA #C_WHITE
    STA COLUPF
    LDA DistPF0
    STA PF0
    LDA DistPF1
    STA PF1
    LDA #$00
    STA PF2
    LDY #8
DistRow:
    STA WSYNC
    DEY
    BNE DistRow

; --- visible 16-99: the play area's top section, walls only ---------------
    LDA #C_GOLD
    STA COLUPF
    LDA #$F0                ; PF0 bits 4-7: the 16-px wall at each edge
    STA PF0
    LDA #$00
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    LDY #84
PlayTop:
    STA WSYNC
    DEY
    BNE PlayTop

; --- visible 100-115: both 16-row players ---------------------------------
; P0 is always solid; P1 is EnemyDraw ($FF, or 0 during the blink's off
; phase).  The stores land by cycle 11, well before the earliest sprite pixel
; (X=24 is absolute clock 92, CPU cycle ~31).
    LDA #$FF
    STA GRP0
    LDA EnemyDraw
    STA GRP1
    LDY #16
PlaySprites:
    STA WSYNC
    DEY
    BNE PlaySprites

; --- visible 116-191: the players are over; walls only --------------------
    LDA #$00
    STA GRP0
    STA GRP1
    LDY #76
PlayBottom:
    STA WSYNC
    DEY
    BNE PlayBottom
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
; StartGame — the one door into a fresh game
; =============================================================================
; Called from the first VBLANK (NeedStart) and from the game-over fire edge.
; P0 starts left of P1 at a 16-pixel distance, so the first frame is a patrol;
; the auto-demo then keeps the pair together or provokes a chase.
StartGame:
    LDA #3
    STA Lives
LifeInit:                   ; checkpoint: A = 3 at the start of a game
    LDA #PLAYER_START_X
    STA PlayerX
    LDA #ENEMY_START_X
    STA EnemyX
    LDA #1
    STA EnemyDir
    LDA #0
    STA EnemyTimer
    STA Invuln
    STA GameOver
    STA NeedStart
    STA PrevColl
    STA CollBit
    STA AutoMode
    LDA #TRACK_FRAMES
    STA AutoTimer
    LDA #HIT_PITCH
    STA BeepPitch
    LDA #0
    JSR SetEnemyState       ; a fresh game starts in patrol
    RTS

; =============================================================================
; RespawnEnemy — put P1 on the side away from P0
; =============================================================================
; If the player is in the right half, P1 respawns at the left wall; otherwise
; at the right wall.  The 60-frame invulnerability in the caller is the
; breathing room; this placement keeps the respawn itself safe.
RespawnEnemy:
    LDA PlayerX
    CMP #80
    BCS RespawnAtLeft
    LDA #ENEMY_MAX_X
    STA EnemyX
    LDA #0
    STA EnemyDir
    JMP RespawnState
RespawnAtLeft:
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir
RespawnState:
    LDA #0
    JSR SetEnemyState
    LDA #0
    STA EnemyTimer
    RTS

; =============================================================================
; ComputeDistance — Distance = |PlayerX - EnemyX|, plus PlayerRight
; =============================================================================
; The subtraction is unsigned because the two bytes are compared first.  A
; carry of 1 from CMP means PlayerX >= EnemyX, so the same carry feeds SBC.
ComputeDistance:
    LDA PlayerX
    CMP EnemyX
    BCC PlayerIsLeft
    SBC EnemyX              ; C=1: A = PlayerX - EnemyX
    STA Distance
    LDA #1
    STA PlayerRight
    JMP DistanceDone
PlayerIsLeft:
    LDA EnemyX
    SEC
    SBC PlayerX
    STA Distance
    LDA #0
    STA PlayerRight
DistanceDone:
    LDA Distance
DistanceCalc:               ; checkpoint: A = the distance, 0..112
    RTS

; =============================================================================
; UpdateEnemy — the state transitions, then the movement
; =============================================================================
; Order matters: fire is checked first and wins from every state; then the
; current state's rule.  Patrol is calm at close range, chase panics at
; <= 24, and flee waits for the 60-frame clock AND a distance > 32.
UpdateEnemy:
    LDA NewFire
    BEQ EnemyNoFire
    JMP EnterFlee
EnemyNoFire:
    LDA EnemyState
    CMP #2
    BEQ UpdateFlee
    CMP #1
    BEQ UpdateChase

; --- state 0: patrol -------------------------------------------------------
    LDA Distance
    CMP #(CHASE_RANGE + 1)  ; Distance >= 25?
    BCC EnemyPatrol         ; no: stay calm and keep patrolling
    LDA #1
    JSR SetEnemyState
    JMP MoveEnemy
EnemyPatrol:
    JMP MoveEnemy

; --- state 1: chase --------------------------------------------------------
UpdateChase:
    LDA Distance
    CMP #(FLEE_RANGE + 1)   ; Distance <= 24?
    BCS EnemyChase          ; A >= 25: still far, keep chasing
    JMP EnterFlee
EnemyChase:
    JMP MoveEnemy

; --- state 2: flee ---------------------------------------------------------
UpdateFlee:
    LDA EnemyTimer
    BEQ FleeExitCheck
    DEC EnemyTimer
    BNE EnemyFleeMove       ; still counting: no exit yet
FleeExitCheck:
    LDA Distance
    CMP #(FLEE_EXIT_RANGE + 1) ; Distance > 32?
    BCC EnemyFleeMove       ; no: the cornered enemy stays red
    LDA #0
    JSR SetEnemyState
EnemyFleeMove:
    JMP MoveEnemy

EnterFlee:
    LDA #2
    JSR SetEnemyState
    LDA #FLEE_FRAMES
    STA EnemyTimer
    JMP MoveEnemy

; =============================================================================
; MoveEnemy — choose a signed delta, then apply it
; =============================================================================
; A patrol turns at a wall and moves one pixel the other way on the same
; frame.  Chase and flee use PlayerRight, so they move toward or away from
; the player without another subtraction.
MoveEnemy:
    LDA EnemyState
    CMP #2
    BEQ FleeMove
    CMP #1
    BEQ ChaseMove

; --- patrol: +1 while EnemyDir=1, -1 while EnemyDir=0 ---------------------
PatrolMove:
    LDA EnemyDir
    BNE PatrolRight
PatrolLeft:
    LDA EnemyX
    CMP #ENEMY_MIN_X
    BEQ PatrolTurnRight
    LDA #$FF                ; -1
    JMP ApplyDelta
PatrolTurnRight:
    LDA #1
    STA EnemyDir
    LDA #PATROL_STEP
    JMP ApplyDelta
PatrolRight:
    LDA EnemyX
    CMP #ENEMY_MAX_X
    BEQ PatrolTurnLeft
    LDA #PATROL_STEP
    JMP ApplyDelta
PatrolTurnLeft:
    LDA #0
    STA EnemyDir
    LDA #$FF                ; -1
    JMP ApplyDelta

; --- chase: +2 toward the player, -2 away --------------------------------
ChaseMove:
    LDA PlayerRight
    BEQ ChaseLeft
    LDA #CHASE_STEP
    JMP ApplyDelta
ChaseLeft:
    LDA #$FE                ; -2
    JMP ApplyDelta

; --- flee: +2 away from the player, -2 toward ----------------------------
FleeMove:
    LDA PlayerRight
    BEQ FleeRight
    LDA #$FE                ; -2
    JMP ApplyDelta
FleeRight:
    LDA #FLEE_STEP
    JMP ApplyDelta

; =============================================================================
; ApplyDelta — EnemyX = clamp(EnemyX + delta, 24, 136)
; =============================================================================
; The delta is signed.  A positive delta is added with CLC/ADC; a negative
; delta is converted to its magnitude and subtracted, because a raw ADC of
; $FF would carry for every EnemyX >= 1 and trip the high clamp.
ApplyDelta:
EnemyMove:                  ; checkpoint: A = the signed delta (+1, -1, +2, -2)
    STA EnemyDelta
    BPL DeltaPositive

; --- negative: A = |delta|, then EnemyX - |delta| -------------------------
    EOR #$FF
    CLC
    ADC #1                  ; two's complement: $FF -> 1, $FE -> 2
    STA EnemyStep
    LDA EnemyX
    SEC
    SBC EnemyStep
    CMP #ENEMY_MIN_X
    BCC DeltaLow
    STA EnemyX
    JMP DeltaDone

; --- positive: EnemyX + delta --------------------------------------------
DeltaPositive:
    CLC
    ADC EnemyX
    BCS DeltaHigh           ; a wrap: clamp to the right wall
    CMP #(ENEMY_MAX_X + 1)
    BCS DeltaHigh
    STA EnemyX
    JMP DeltaDone

DeltaLow:
    LDA #ENEMY_MIN_X
    STA EnemyX
    JMP DeltaDone
DeltaHigh:
    LDA #ENEMY_MAX_X
    STA EnemyX
DeltaDone:
    LDA EnemyX
EnemyXWrite:                ; checkpoint: A = the new EnemyX, 24..136
    RTS

; =============================================================================
; SetEnemyState — the one door into a state
; =============================================================================
; A = the new state.  Every transition goes through here, so EnemyStateWrite
; reports exactly the value every transition stored.
SetEnemyState:
    STA EnemyState
EnemyStateWrite:            ; checkpoint: A = the new state
    RTS

; =============================================================================
; AutoDemo — P0's movement when the joystick is untouched
; =============================================================================
; AutoTimer toggles the patrol phase between track (120 frames) and provoke
; (90 frames).  The state overrides the phase for chase and flee: a chase is
; always run away from, and a flee is always followed at the same speed.
AutoDemo:
    DEC AutoTimer
    BNE AutoTimerDone
    LDA AutoMode
    EOR #1
    STA AutoMode
    BNE AutoProvokeReload
    LDA #TRACK_FRAMES
    STA AutoTimer
    JMP AutoTimerDone
AutoProvokeReload:
    LDA #PROVOKE_FRAMES
    STA AutoTimer
AutoTimerDone:
    LDA EnemyState
    CMP #1
    BEQ AutoChase
    CMP #2
    BEQ AutoFlee

; --- patrol: track the enemy, or run away during a provoke ----------------
    LDA AutoMode
    BNE AutoProvoke
    LDA Distance
    CMP #(TRACK_FAR + 1)    ; more than 22: walk toward the enemy
    BCS AutoApproach
    CMP #TRACK_NEAR         ; less than 18: back away
    BCC AutoRetreat
    RTS                     ; 18..22: hold the gap
AutoApproach:
    LDA PlayerRight
    BNE AutoApproachLeft
    JMP MovePlayerRight1
AutoApproachLeft:
    JMP MovePlayerLeft1
AutoRetreat:
    LDA PlayerRight
    BNE AutoRetreatRight
    JMP MovePlayerLeft1
AutoRetreatRight:
    JMP MovePlayerRight1
AutoProvoke:
    LDA PlayerRight
    BNE AutoProvokeRight
    JMP MovePlayerLeft2
AutoProvokeRight:
    JMP MovePlayerRight2

; --- chase: run away at 2 -------------------------------------------------
AutoChase:
    LDA PlayerRight
    BNE AutoChaseRight
    JMP MovePlayerLeft2
AutoChaseRight:
    JMP MovePlayerRight2

; --- flee: hold still, so the enemy's 60-frame escape is visible ----------
AutoFlee:
    RTS

; =============================================================================
; PLAYER MOVEMENT — clamps at 24 and 136
; =============================================================================
MovePlayerLeft1:
    LDX #1
    JMP PlayerLeftStep
MovePlayerLeft2:
    LDX #2
    JMP PlayerLeftStep
PlayerLeftStep:
    STX PlayerStep
    LDA PlayerX
    SEC
    SBC PlayerStep
    CMP #PLAYER_MIN_X
    BCC PlayerLeftClamp
    STA PlayerX
    RTS
PlayerLeftClamp:
    LDA #PLAYER_MIN_X
    STA PlayerX
    RTS

MovePlayerRight1:
    LDX #1
    JMP PlayerRightStep
MovePlayerRight2:
    LDX #2
    JMP PlayerRightStep
PlayerRightStep:
    STX PlayerStep
    LDA PlayerX
    CLC
    ADC PlayerStep
    CMP #(PLAYER_MAX_X + 1)
    BCS PlayerRightClamp
    STA PlayerX
    RTS
PlayerRightClamp:
    LDA #PLAYER_MAX_X
    STA PlayerX
    RTS

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
; AUDC 0C is the div-6 tone from Lesson 35; AUDV 0A is audible but not loud.
; The VBLANK clock silences the channel eight frames later.
BeepStart:
    LDA #8
    STA BeepTimer
    LDA #$0C
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; COARSE POSITIONING — P0 and P1, one HMOVE at the end
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
; DISTANCE-BAR TABLE — N chunks from the left, two playfield bytes per entry
; =============================================================================
; PF0 bits 4-7 are the first four chunks (bit 4 leftmost); PF1 bits 7-5 are
; the next three (bit 7 leftmost).  CTRLPF=$01 mirrors the same chunks from
; the right edge, so every count is "per half".  N = Distance/16 (0-7).
DistBarPF0:
    !byte $00,$10,$30,$70,$F0,$F0,$F0,$F0
DistBarPF1:
    !byte $00,$00,$00,$00,$00,$80,$C0,$E0

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
> `lessons/part6-game-dev/44-ai-enemy-behavior/44-ai-enemy-behavior.asm`.

### Code Walkthrough

#### Step 1 — The RAM map and the three states

The lesson uses `$80–$9C`; the shared score and random libraries are not loaded, so `$9D–$D7`
stays free and the stack keeps `$F8–$FF`. The important bytes are `EnemyState` (`$80`), `EnemyX`
(`$81`), `EnemyDir` (`$82`), `EnemyTimer` (`$83`), `PlayerX` (`$84`), `Lives` (`$85`), and
`Distance` (`$86`). `EnemyDir` is only the **patrol** direction: chase and flee do not use it,
because they take their direction from `PlayerRight` every frame.

#### Step 2 — Reset and the one door into a game

`+clean_start` zeroes TIA and RAM and sets the stack. `Reset` does not position the game; it only
marks `NeedStart=1`. The first VBLANK calls `StartGame`, which sets `Lives=3`, `PlayerX=64`,
`EnemyX=80`, the patrol direction, and `EnemyState=0` through `SetEnemyState`. Both a power-on
and a fire restart use that one routine, so a new game cannot start half-initialised.

#### Step 3 — VBLANK in order

The VBLANK block runs in the same order every frame:

1. **Frame and beep.** `Frame` advances for the blink; `BeepTimer` counts down and silences
   channel 0 at zero.
2. **Fire.** `INPT4` bit 7 is 0 while pressed; the EOR/AND pair keeps the 0→1 edge.
3. **Collision.** Read `CXPPMM` bit 7, edge-detect against `PrevColl`, then `STA CXCLR`.
4. **Start.** If `NeedStart`, call `StartGame`.
5. **Game over or play.** `GameOver=1` freezes the play update; fire calls `StartGame` and the
   new game is rebuilt without running the brain on the restart frame.
6. **The brain.** `UpdateEnemy` reads the distance measured at the end of the previous frame.
7. **The player.** The joystick moves P0, or `AutoDemo` moves it.
8. **Lives.** Count `Invuln` down; charge a new contact; respawn and blink.
9. **Measure.** `ComputeDistance` recomputes `Distance` and `PlayerRight` after the life path, so
   a respawn is included.
10. **Display.** Build the state row bytes, the bar bytes, and `EnemyDraw`.
11. **Positioning.** Both players, then one `HMOVE`.
12. **Colours and preload.** Set `COLUP0`, `COLUP1`, `COLUBK`, `CTRLPF`, and the state row's
    `PF0/PF1/COLUPF`, then `+wait_timer`.

The VBLANK work is well inside the 37-line timer; the `+wait_timer` absorbs the rest and anchors
`BodyStart` at scanline 37.

#### Step 4 — The brain's transitions

`UpdateEnemy` checks fire first, so it wins from every state. Then it dispatches on the current
state:

```asm
    LDA NewFire
    BEQ EnemyNoFire
    JMP EnterFlee
EnemyNoFire:
    LDA EnemyState
    CMP #2
    BEQ UpdateFlee
    CMP #1
    BEQ UpdateChase

; --- state 0: patrol -------------------------------------------------------
    LDA Distance
    CMP #(CHASE_RANGE + 1)  ; Distance >= 25?
    BCC EnemyPatrol         ; no: stay calm and keep patrolling
    LDA #1
    JSR SetEnemyState
    JMP MoveEnemy
EnemyPatrol:
    JMP MoveEnemy
```

The chase's low branch goes to `EnterFlee`, and `EnterFlee` sets state 2 and `EnemyTimer=60`. The
flee branch decrements the timer, and only when the decrement reaches zero does it test the
32-pixel exit. `EnemyStateWrite` reports every state the machine stores.

#### Step 5 — The movement and the clamp

`MoveEnemy` turns the state into a delta, and `ApplyDelta` clamps it. The negative path is the
one to read twice: `EOR #$FF / CLC / ADC #1` is the two's complement of `$FF` and `$FE`, so the
result is a magnitude of 1 or 2, and the `CMP #24` clamps the low end. `EnemyMove` reports the
signed delta; `EnemyXWrite` reports the clamped position. The signed values in the log are the
proof: −1 in patrol, −2 in chase, +2 in flee.

#### Step 6 — The auto-demo

`AutoDemo` runs only when `SWCHA` bits 6 and 7 are both 1 (no direction held). Its clock toggles
`AutoMode` every 120 or 90 frames:

```asm
AutoDemo:
    DEC AutoTimer
    BNE AutoTimerDone
    LDA AutoMode
    EOR #1
    STA AutoMode
    BNE AutoProvokeReload
    LDA #TRACK_FRAMES
    STA AutoTimer
    JMP AutoTimerDone
AutoProvokeReload:
    LDA #PROVOKE_FRAMES
    STA AutoTimer
AutoTimerDone:
    LDA EnemyState
    CMP #1
    BEQ AutoChase
    CMP #2
    BEQ AutoFlee
```

The track phase holds the gap in the 18–22 band: `Distance >= 23` walks toward the enemy, `< 18`
walks away, and the middle holds. In the measured rightward phase the pair rests at 23 because
both sprites step together, so the bar shows one chunk. The provoke phase runs away at 2, which
is enough to cross the 24-pixel chase line. The chase branch runs away at 2; the flee branch
holds. A manual direction cancels the mode and resets the clock, so the player is never fighting
the demo for control.

#### Step 7 — The life path

The contact is charged once, in the VBLANK block, from the edge-detected `CollBit`. The sequence
is `Lives--`, beep, `RespawnEnemy`, `Invuln=60`. `RespawnEnemy` picks the side away from the
player: `PlayerX >= 80` sends P1 to X=24, otherwise to X=136, and sets the patrol direction
toward the middle. The check for zero lives comes after the respawn, so the last frame still
places P1 correctly; the next frame sees `GameOver=1` and draws the red field. `ComputeDistance`
runs after this block, so the hit frame's bar shows the post-respawn gap and the frozen field
keeps it.

#### Step 8 — The visible kernel

The kernel is work-first: write the line's registers, then `STA WSYNC`. The state row needs no
writes — its `PF0/PF1/COLUPF` are preloaded in VBLANK — so it is eight `STA WSYNC`s. The distance
row changes `COLUPF` to white and writes the two bar bytes; the colour store lands at cycle 5,
PF0 at cycle 8, and `STA PF2` at cycle 22, before PF0's first visible slot at 22.7. The play top then writes
`PF0=$F0`, clears `PF1/PF2/GRP0/GRP1`, and waits 84 lines. The sprite band sets `GRP0=$FF` and
`GRP1=EnemyDraw` before the earliest sprite pixel (X=24 is CPU cycle ~31). The bottom clears both
`GRP` registers and waits 76 lines.

The two sprites are positioned by `SetCoarseP0` and `SetCoarseP1` with the Lesson 26 `+3` bias,
then one `HMOVE` in the next HBLANK. `HmoveApply` is the `WSYNC` stall; `HmoveDone` is the store,
which executes at the next line's cycle 3.

### Checkpoints

Stella keeps one `-break` per run (the last one on the command line), so run one checkpoint at a
time. `-turbo 1` makes the per-frame logs fast; `-dbg.logtrace 0` keeps the output readable.

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F01B` | **259, cycle 3** | the first VSYNC line |
| `VblankStart` | `$F029` | 0, cycle 5 | the first VBLANK line |
| `FireRead` | `$F042` | A=`$8C` released; A=`$0C` pressed | `INPT4`; bit 7 is the button |
| `ReadCX` | `$F058` | A=`$07` at rest; A=`$87` at frame 62 | `CXPPMM`; bit 7 is P0–P1 |
| `CXClear` | `$F06B` | A=0 | the `CXCLR` strobe |
| `LifeStep` | `$F0CA` | A=2 at frame 62 (right hold + `-turbo 1`) | the new life count |
| `LifeInit` | `$F20C` | A=3 at frame 1 | the fresh-game life count |
| `EnemyStateWrite` | `$F351` | A=0, 1, or 2 | the new state, from every transition |
| `DistanceCalc` | `$F277` | A = 0–112 | the measured gap |
| `EnemyMove` | `$F31A` | A = `$01`/`$FF` patrol, `$02`/`$FE` chase and flee | the signed delta |
| `EnemyXWrite` | `$F34E` | A = 24–136 | the clamped position |
| `BodyStart` | `$F19F` | **37, cycle 5** | visible line 0 |
| `HmoveApply` | `$F152` | line 7–8, cycle 56 | the `WSYNC` stall before the one `HMOVE` |
| `HmoveDone` | `$F154` | line 8–9, cycle 3 | the store has executed |
| `OverscanStart` | `$F1F5` | **229, cycle 7** | overscan's first line |

The RAM bytes to watch are `EnemyState` at `$80`, `EnemyX` at `$81`, `EnemyTimer` at `$83`,
`PlayerX` at `$84`, `Lives` at `$85`, `Distance` at `$86`, `Invuln` at `$87`, and `GameOver` at
`$88`.

## What You Should See

The screen is a dark `$02` field with a 16-line status area at the top. Two 16-pixel gold walls
run down the left and right edges of the play area, from visible line 16 to 191. P0 is the red
8×16 block and P1 the state-coloured 8×16 block; both sit on visible lines 100–115, far enough
apart that the gap shows as background between them.

**Patrol.** The state row's first cell is green, at X=8–15 with its mirror at X=144–151. The
distance bar has one white chunk at each edge (X=0–3 and 156–159). P1 is green and matches the
row. In this capture P0's left edge is X=88 and P1's is X=111, a 23-pixel gap: `23 / 16 = 1`, so
one chunk is the right reading. The enemy is moving along the patrol line; the player has not
provoked anything yet.

![Stella running the Lesson 44 ROM in patrol: a green state cell per half, a one-chunk white distance bar, gold side walls, a red player at X=88 and a green 8-pixel enemy at X=111 on the same scanlines](/images/lesson44/patrol.png)

*Patrol: green state cell, one white chunk per half, and an 8-pixel green enemy 23 pixels from
the red player. The bar reads 23 / 16 = 1 chunk.*

**Chase.** The state row's second cell is gold, at X=16–23 with its mirror at X=136–143. The bar
has three white chunks at each edge (X=0–11 and 148–159), and P1 is gold. In this capture P0 is
at the left wall (X=24) and P1 is at X=73: a 49-pixel gap, and `49 / 16 = 3`. The player has
escaped past 24 pixels, so the enemy turned gold and is closing the gap; a chase that reaches 24
pixels (or a fire press) turns it red. The gold colour is the state feedback.

![Stella running the Lesson 44 ROM in chase: a gold state cell per half, a three-chunk white distance bar, a red player at the left wall and a gold 8-pixel enemy 49 pixels away on the same scanlines](/images/lesson44/chase.png)

*Chase: gold state cell, three white chunks per half, and an 8-pixel gold enemy 49 pixels from
the player. The bar reads 49 / 16 = 3 chunks.*

> **Capture method.** Both images are window captures of the committed ROM in Stella 7.0, from
> `docs/public/roms/part6-game-dev/44-ai-enemy-behavior/44-ai-enemy-behavior.bin`, with the
> pointer parked at (0,0) and no game pixel altered. The title bar reads
> `Stella 7.0: "44-ai-enemy-behavior"`. The capture script waited 1.0 s and 4.2 s; both waits
> include Stella's startup, so they are wall-clock waits, not emulated frame numbers. The
> auto-demo chose the state; the selected images are the green patrol and gold chase frames,
> identified by their state rows and P1 colours (the 4.2 s wait is not 4.2 s of emulated time).
> The colours and positions in the captions are decoded from the captured pixels: the state cells
> and the bar runs are measured in TIA pixels (capture x = 25 + 6 × TIA X), and the 23- and
> 49-pixel gaps come from the two sprite left edges.

<RomPlayer rom="/roms/part6-game-dev/44-ai-enemy-behavior/44-ai-enemy-behavior.bin" title="Lesson 44 — AI & Enemy Behavior" />

Click the player screen once: Javatari starts muted until a user gesture. The ROM runs its
auto-demo without input, so the state row, the enemy's colour, and the bar move on their own.
The state cycles: about two seconds of green patrol, then a gold chase, then a red flee for 60
frames, then a single patrol frame before the next chase. Press fire to enter flee immediately.
Push the joystick left or right to take P0 away from the demo; walking into the enemy in patrol
costs a life and starts the blink. Press fire after the third loss to restart.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
acme -f plain -l build/lesson44.sym -o build/lesson44.bin \
  lessons/part6-game-dev/44-ai-enemy-behavior/44-ai-enemy-behavior.asm
stella -audio.enabled 0 -turbo 1 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F351' docs/public/roms/part6-game-dev/44-ai-enemy-behavior/44-ai-enemy-behavior.bin
```

| Frame | `EnemyStateWrite` | `DistanceCalc` that the brain read | `EnemyMove` | `EnemyXWrite` |
|---|---|---|---|---|
| 1 | 0 | — (fresh game) | +1 | 81 |
| 128 | 1 | 25 at frame 127 | −2 | 63 |
| 137 | 2 | 23 at frame 136 | +2 | 49 |
| 197 | 0 | 112 at frame 196 | −1 | 135 |
| 198 | 1 | 111 at frame 197 | −2 | 133 |
| 242 | 2 | 23 at frame 241 | +2 | 49 |
| 302 | 0 | 112 at frame 301 | −1 | 135 |

The first transition is the auto-demo's provoke: the gap grows past 24 and the enemy changes from
patrol to chase at frame 128. The chase closes to 23 pixels and the enemy flees at frame 137.
Sixty frames later — frame 197 — the timer has expired and the gap is 112, so the enemy returns to
patrol; the next frame it sees the gap is still above 24 and chases again. The sequence repeats.
The `EnemyMove` column is the signed delta: −1 in patrol, −2 in chase, +2 in flee.

The life path:

```bash
stella -audio.enabled 0 -turbo 1 -dbg.logbreaks 1 -logtoconsole 1 -holdjoy0 R \
  -break '$F0CA' docs/public/roms/part6-game-dev/44-ai-enemy-behavior/44-ai-enemy-behavior.bin
```

`-turbo 1` is part of the command: `-holdjoy0` holds the joystick from power-on against a wall
clock, so without turbo the debugger's slow emulation can outlast the hold. The turbo lets the
first 62 emulated frames pass while the hold is active.

`LifeStep` reports A=2 at frame 62, and `ReadCX` at the same frame reports A=`$87` (bit 7 set).
At that contact P0's left edge is X=126 and P1's is X=130, a 4-pixel left-edge offset (the two
8-pixel sprites overlap by 4 pixels); because P0 is in the right half, `RespawnEnemy` puts P1 at
X=24, and `Invuln` becomes 60. `DistanceCalc` on the hit frame then reports 102 (`|126 − 24|`), so
the bar shows six chunks on the hit frame and on the frozen field. In a one-life build the same
path reaches A=0 and the field turns red; the play update stops and fire restarts. That last
branch is a code path, not a screenshot claim: the committed ROM reaches it only after three
contacts, and the screenshots above prove the visual state, not the logic.

## Exercises

### Exercise 1: Waypoint Patrol

**Challenge:** patrol between X=40 and X=120 with a **30-frame pause** at each endpoint. During
the pause `EnemyX` holds and `EnemyTimer` counts down; `EnemyMove` reports 0. The chase, flee,
and life behaviour must stay as in the main ROM; the auto-demo's track phase may be lengthened so
the narrower patrol can visit both waypoints (hint 5).

**Hints:**
1. `EnemyTimer` is unused during patrol in the main ROM, so it can hold the pause. Check it first
   in `MoveEnemy`'s patrol branch; a nonzero value means "pause".
2. At a waypoint, flip `EnemyDir`, load the timer with 30, and return a delta of 0. The arrival
   frame must not move; the timer's countdown is the pause.
3. On the frame the decrement reaches 0, walk again. The order `DEC / BNE / JMP PatrolFree` makes
   the last counted frame the first moving frame, so the position holds for exactly the 30 timer
   frames after the arrival frame.
4. `PatrolPause` reports the loaded value (30). `EnemyXWrite` reports 40 or 120 for the whole
   pause, and `EnemyMove` reports 0 on those frames.
5. The narrower patrol needs a longer track phase: change `TRACK_FRAMES` from 120 to 200, or the
   auto-demo's first provoke starts a chase before the enemy can walk from 120 to 40.

**Expected Result:** With no input and `TRACK_FRAMES=200`, the enemy reaches X=120 at frame 40
and holds it through frame 70; it reaches X=40 at frame 150 and holds it through frame 180. The
measured log shows `EnemyXWrite` = 120 for frames 40–70 and 40 for frames 150–180, `EnemyMove` =
0 for the 30 timer frames after each arrival, and `PatrolPause` A=`$1E` (30) at frames 41 and 151.
The two endpoints are the same branch, mirrored.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: The Dead Zone

**Challenge:** chase only when `Distance > 16`; otherwise patrol and **hold position**. The enemy
must not move inside the 16-pixel dead zone, and `EnemyMove` must report 0 there. Fire still
enters flee, so the red state remains reachable.

**Hints:**
1. Change `CHASE_RANGE` from 24 to 16 and use a separate `DEAD_ZONE=16` for the chase's low
   branch.
2. The chase's low branch sets state 0, not flee: the dead zone replaces the chase/flee chatter
   at the threshold.
3. Make `MoveEnemy`'s patrol branch return delta 0. That is the "no jitter" part: the enemy either
   closes the gap or holds, never reverses at the boundary.
4. Keep the flee entry on `NewFire` and the 60-frame/32-pixel exit exactly as they are.
5. Because the auto-demo's track band is 18–22, the provoke now produces a short chase and then a
   hold; press fire to see the flee state.

**Expected Result:** `EnemyStateWrite` reports state 1 at frame 2, then state 0 from frame 22.
`EnemyMove` reports +2/−2 during the chase and 0 from frame 22 on; `EnemyX` stops at X=40 (the
player is at the left wall) and stays there. There is no alternating chase/patrol movement at the
16-pixel line.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The Flee Speed Switch *(Stretch Goal)*

**Challenge:** scale the flee speed with the right difficulty switch: 2 pixels per frame on
novice/B, 3 on expert/A. The chase stays at 2 and patrol at 1. `EnemySpeed` must report 2 or 3.

**Hints:**
1. `SWCHB` bit 7 is the right/P1 difficulty switch: 0 = B/novice, 1 = A/expert
   (`include/vcs.asm`; Stella's `-rd A` sets it to 1).
2. Read the switch every VBLANK and store 2 or 3 in a new `EnemySpeed` byte at `$9D`. Sampling
   every frame means a mid-game flip takes effect immediately.
3. `FleeMove` uses `EnemySpeed` in both directions. For the negative direction use
   `LDA #0 / SEC / SBC EnemySpeed`; the `ApplyDelta` routine already turns `$FE` or `$FD` into a
   magnitude of 2 or 3.
4. Seed `EnemySpeed=FLEE_STEP` (2) in `StartGame` so the first frame is safe. Add `FleeSpeedWrite` after the
   store so the debugger shows the chosen value.

**Expected Result:** On novice/B, `FleeSpeedWrite` reports A=2 and `EnemyMove` reports `$02` or
`$FE` during the 60 flee frames. On expert/A (`stella -rd A ...`), `FleeSpeedWrite` reports A=3
and `EnemyMove` reports `$03` or `$FD`. The measured runs show 60 flee frames at delta 3 on
expert and 60 at delta 2 on novice; the enemy leaves the player behind faster on expert.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A state byte is the whole brain**: `EnemyState` 0/1/2 selects patrol, chase, or flee; every
  transition goes through `SetEnemyState`, so the store and its checkpoint cannot diverge.
- ✅ **Distance is the sensor**: `|PlayerX - EnemyX|` is one `CMP`/`SBC` pair, at most 112, and
  `PlayerRight` saves the side for the movement routines. The bar reads `Distance / 16` in white
  chunks, 0–7 per half.
- ✅ **Movement is a signed delta**: +1/−1 in patrol, +2/−2 in chase and flee. A negative delta is
  converted to a magnitude and subtracted, because adding `$FF` with `ADC` would carry and trip
  the high clamp.
- ✅ **The flee needs a clock and a hysteresis**: 60 frames at `EnemyTimer`, and a return to patrol
  only when the gap is past 32. The 24-to-32 band stops the chase/flee oscillation at the trigger.
- ✅ **Colour is the state feedback**: green `$C8`, gold `$1A`, red `$42` on P1 and the lit state
  cell. A patrolling enemy is calm at close range; proximity only startles a chase — otherwise the
  green state could never be seen.
- ✅ **Contact is a latch with a one-frame memory**: both players share visible lines 100–115;
  `CXPPMM` bit 7 is read in VBLANK, edge-detected, and cleared. A hit costs one of three lives,
  respawns P1 away from the player, and grants 60 frames of blinking invulnerability.
- ✅ **The layout is 8 + 8 + 84 + 16 + 76 = 192 lines**: the state row, the distance bar, the two
  wall sections, and the sprite band, with the 262-line frame and one `HMOVE` for both players.

## What's Next

The enemy now has a plan, and the plan costs bytes: 29 bytes of lesson RAM, plus the two sprite
positions and the state row's tables. That is a large share of the 128 bytes the console owns.
[Lesson 45: Memory Management — 128 Bytes of Creativity](/part6-game-dev/45-memory-management)
draws the whole `$80–$FF` map as a 16×8 playfield grid, packs four flags into one byte, and adds
an ACME budget assert that fails the build when a variable walks into the stack.
