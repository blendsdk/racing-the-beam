---
title: "Lesson 72: Capstone 4 — Your Own Game"
description: "Turn a concept into a shipped 4K game: write the one-page GDD, draw the RAM and 192-line screen maps, measure the 4K budget, plan four tested milestones, and start from Star Catcher, a complete 4,096-byte skeleton with title/play/over states, the score and sound libraries, three lives, a 30-second timer, and a deterministic auto-demo."
prev:
  text: "Lesson 71: Capstone 3 — Maze Explorer"
  link: "/part10-capstones/71-maze-explorer"
next:
  text: "Part 11: Legendary Techniques"
  link: "/part11-legendary/"
---

# Lesson 72: Capstone 4 — Your Own Game

> **Part 10: Capstone Projects** · Estimated time: 180 minutes
> **Prerequisites:** Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and memory), Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 25 (players), Lesson 26 (horizontal positioning), Lesson 29 (the ball), Lesson 33 (controllers), Lesson 37 (the sound engine), Lesson 38 (collision detection), Lesson 39 (the scoreboard and the score library), Lesson 41 (game states), Lesson 45 (memory maps), Lesson 46 (debugging), Lesson 47 (the development tools), Lesson 49 (the two-line kernel), Lesson 50 (the multi-zone kernel), Lesson 69 (Pong), Lesson 70 (Breakout), Lesson 71 (Maze Explorer)
> **You will learn:** the production method that turns a concept into a 4K game — the one-page game design document (GDD), the 128-byte RAM map, the 192-line screen map, the 4K ROM budget, the four-milestone plan with a test per milestone, and the discipline of captures and state logs; how a complete skeleton game is organized so the reader replaces three marked sections and keeps the frame, score, sound, states, restart, and auto-demo.
> **You will build:** **Star Catcher**, a complete 4,096-byte skeleton mini-game: a title screen with a gold emblem and a blinking bar prompt, a play state with a six-digit score, a 30-second timer bar, three life markers, a gold ship, a falling star, a catch that scores and a miss that costs a life, a red game-over screen, the shared score and sound libraries, fire restart, and a deterministic auto-demo that makes the two captures reproducible. The three design exercises are answered in this document; Lesson 72 has no exercise solution files.

## Introduction

The first three capstones each began with a known game. Pong gave you the row table and the two-line kernel. Breakout gave you zones and the shared score library. Maze Explorer gave you generated data and a mirror world. All three had a finished design before the first line of assembly: the screen was already divided into bands, the objects already had positions and speeds, and the score already had a source.

Your own game starts with a blank page. That is a different problem, and it is the one this lesson solves. The blank page is not an assembly problem; it is a **production** problem. A game that is too large for 4K, or whose RAM map collides with a library, or whose kernel cannot finish a line, will not be rescued by clever 6502. The rescue happens earlier: a one-page design, two maps, a ROM budget, and a milestone plan with a test for each step.

The production method in this lesson is:

| Step | Artifact | The question it answers |
| --- | --- | --- |
| 1 | Concept | What is the player doing, and why is it fun for one minute? |
| 2 | One-page GDD | What are the core loop, controls, objects, states, win/lose, score, and audio? |
| 3 | RAM map | Which byte holds what, and which bytes belong to a library? |
| 4 | Screen map | Which picture lines draw which zone, and does each kernel line fit 76 cycles? |
| 5 | 4K budget | How many ROM bytes does each block spend, and how much headroom is left? |
| 6 | Milestone plan | What is the smallest tested step that proves the riskiest mechanic first? |
| 7 | Implementation | Write the skeleton, replace the three marked sections, keep the frame. |
| 8 | Captures and logs | Does the real ROM show the claimed picture and the claimed frame? |

The companion program, `demo-72.asm`, is the worked example: **Star Catcher**, a complete mini-game in 4,096 bytes. It is deliberately small enough to read in one sitting, but it is not a blank template. The title, play, and over states run; the score library counts catches; the sound library plays a catch blip and a miss buzz; fire starts and restarts; the auto-demo catches and misses on a deterministic schedule. Three banners mark the parts the reader replaces:

- `YOUR GAME — INPUT`: the controls (`ReadJoystick`, `DemoFollow`).
- `YOUR GAME — UPDATE`: the rules, scoring, and collision policy (`TickTimer`, `MoveItem`, `CatchItem`, `MissItem`, `SpawnItem`).
- `YOUR GAME — DRAW`: the screen (`TitleScreen`, `PlayScreen`, `OverScreen`, and the small graphics tables).

Everything else — the 262-line frame, the VBLANK order, the score calls, the sound calls, the state/restart helpers, and the auto-demo timer — stays. The skeleton is a contract: replace the three sections and the game is yours; keep the frame and the libraries and the hardware stays happy.

::: details TypeScript Equivalent

A browser game in TypeScript usually has a game loop, a state machine, a world object, and a renderer that draws into a framebuffer. The 2600 has the first two almost exactly, and the last two in a very different form.

```typescript
type GameState = 0 | 1 | 2;          // title, play, over

interface World {
  state: GameState;
  playerX: number;                   // 8..152
  itemX: number;                     // 8..148
  itemY: number;                     // 24..181
  score: number;
  lives: number;
  timer: number;                     // seconds, 30..0
  frame: number;
  prevFire: boolean;
  autoTimer: number;                 // frames with no direction
  startup: number;                   // 60-frame settle, then 60-frame tick
  itemDir: 1 | 2;                    // 1 normal, 2 forced miss
  curItem: 0 | 1;
  itemLine: number;                  // itemY - 15
  timerIdx: number;                  // 2 * floor(timer / 3), 0..20
}

const WORLD: World = {
  state: 0, playerX: 76, itemX: 76, itemY: 24, score: 0, lives: 3,
  timer: 30, frame: 0, prevFire: true, autoTimer: 0, startup: 60,   // PrevFire starts at the pressed level
  itemDir: 1, curItem: 0, itemLine: 9, timerIdx: 20,
};

// One frame: the same order as VBLANK in the ROM.
function step(w: World, input: { fire: boolean; left: boolean; right: boolean }): void {
  w.frame++;

  // Fire is an edge: a press starts the title or restarts the over screen.
  if (input.fire && !w.prevFire) {
    if (w.state === 0) startPlay(w);
    else if (w.state === 2) startPlay(w);
  }
  w.prevFire = input.fire;

  if (w.state === 0) {
    if (w.startup > 0) w.startup--;
    else if (++w.autoTimer >= 120) { startPlay(w); w.autoTimer = 120; }
  } else if (w.state === 1) {
    tickTimer(w);
    if (w.state !== 1) return;
    readJoystick(w, input);
    moveItem(w);
  }
}

function startPlay(w: World): void {
  w.state = 1;
  w.score = 0; w.lives = 3; w.timer = 30; w.timerIdx = 20;
  w.startup = 60; w.autoTimer = 0; w.curItem = 0; w.playerX = 76;
  spawnItem(w);
}

function tickTimer(w: World): void {
  if (--w.startup === 0) {
    w.startup = 60;
    if (--w.timer === 0) { w.timerIdx = 0; w.state = 2; return; }
    w.timerIdx = 2 * Math.floor(w.timer / 3);
  }
}

function moveItem(w: World): void {
  // The collision latch describes the previous frame in the real hardware.
  if (overlaps(w)) { scoreCatch(w); return; }
  w.itemY += w.itemDir === 1 ? 2 : 1;
  w.itemLine = w.itemY - 15;
  if (w.itemY > 180) missItem(w);
}

// The 2600 renderer is not a framebuffer.  This function is a stand-in for
// the 176-line play loop: it decides one line's TIA bytes, then waits.
function renderPlayLine(w: World, line: number): void {
  const pf = timerAndLivesBytes(w, line);       // only the first five lines
  const grp0 = line >= 153 && line < 161
    ? SHIP[line - 153] : 0;                     // the 8x8 ship
  const enabl = line >= w.itemLine && line < w.itemLine + 4 ? 0x02 : 0;
  writeTia({ pf, grp0, enabl });
  waitForScanline();
}
```

The model captures the shape — a state machine, a world object, a per-frame step, a per-line draw — and it breaks exactly where the 2600 differs:

- **There is no framebuffer.** `renderPlayLine` is a metaphor for a kernel that writes `PF0/PF1/PF2`, `GRP0`, and `ENABL` and then waits with `WSYNC`. The picture exists only as the beam scans; the code is the schedule.
- **The screen is 192 visible lines, not a canvas.** The score band is nine lines, the positioner five, the play area 176. A design that forgets the score band or the positioner does not fit.
- **The TIA has a fixed object set.** Two 8-pixel players, two missiles, one ball, and a 20-bit playfield. There are no arbitrary rectangles, no alpha, and no off-screen surfaces.
- **One line is 76 CPU cycles.** The `step` function has no time budget; the real kernel must finish each line's stores before the beam reaches the object. The play line's item check and ship store are counted, not guessed.
- **RAM is 128 bytes and it is a contract.** The `World` interface is an object on a heap; the 2600 version is a list of absolute addresses. The score library owns `$A0-$D7`; the sound library owns `$88-$8D` and `$90-$9F`. A variable in the wrong byte silently corrupts a library.
- **ROM is 4,096 bytes.** The TypeScript bundle can grow; the cartridge cannot. The 4K worksheet is a design document, not an afterthought.
- **Collisions are hardware latches.** `CXP0FB` bit 6 is set when the player and ball pixels overlap during a frame and stays set until `CXCLR`. The TypeScript `overlaps` is evaluated at the moment of the step; the real code reads the previous frame's latch, so the catch is one frame late by construction.
- **The frame is fixed at 262 lines and 60 Hz.** There is no `requestAnimationFrame`; the VSYNC/VBLANK/overscan skeleton is the clock, and the auto-demo is deterministic because that clock is fixed.

:::

## Theory

### Section 1: The production pipeline

The pipeline is a sequence of **decisions that get cheaper to change**. A concept change costs a sentence. A GDD change costs a paragraph. A RAM-map change costs every routine that touches the moved byte. A kernel change costs a re-counted line. A capture change costs a re-run. The point of the pipeline is to make the expensive changes rare.

| Step | Output | Cheap test | Expensive failure it prevents |
| --- | --- | --- | --- |
| Concept | One sentence: the player does X to achieve Y | Can you say it without a list? | A game with no core loop |
| GDD | One page: loop, controls, objects, states, win/lose, score, audio | Does every object have a job? | A feature list with no game |
| RAM map | 128 bytes, every byte named or owned | Do the libraries fit? | A silent corruption |
| Screen map | 192 lines, every zone counted | Does 9 + 1 + 5 + 176 + 1 = 192? | A rolled or short frame |
| 4K budget | Bytes per block | Is the total under 4,096? | A game that cannot ship |
| Milestones | Four tested steps | Does each step have a measurement? | A big-bang integration |
| Implementation | The skeleton with three sections replaced | Does it assemble and run? | A demo that is not a game |
| Captures | Two images and a state log | Do the pixels match the claims? | A lesson that describes a different ROM |

Star Catcher is deliberately a **one-mechanic** game. The player moves a ship left and right; a star falls; the player catches it or misses it. The core loop is one sentence: *see the star, move under it, catch it for a point, or lose a life and try again before the clock runs out.* Everything else — the title, the score, the timer, the sound, the over screen — exists to frame that sentence. That is the scope that fits 4K and the scope a first original game should have.

::: tip Scope is a feature
The most common first-game failure is not a bug; it is a design that needs three screens, two enemy types, a scrolling world, and a save system. Star Catcher has one screen, one enemy (the star), one verb (move), and one number (the score). The small scope is what makes the complete version possible: title, play, over, score, sound, restart, and captures all fit because the core loop is small.
:::

### Section 2: The one-page GDD

A game design document for a 4K game should fit on one page. It is not a pitch deck; it is the contract the code is written against. The template has twelve fields:

| Field | What it must say |
| --- | --- |
| Title | The name on the title screen and the lesson. |
| Concept | One sentence: who does what, and why. |
| Core loop | The repeating action, in order, with the feedback at each step. |
| Controls | Every input, its effect, its speed, and its edge/level behavior. |
| Screen map | The line bands; the score, the play area, the prompts. |
| Object list | Every visible object, its size, color, and job. |
| States | Every state, its entry, its exit, and what persists across the transition. |
| Win/lose | How the game ends, and what the player sees. |
| Score | What scores, how much, how it is displayed, and what happens on overflow. |
| Audio | Every sound, its trigger, its channel, and its priority. |
| Milestones | The four tested steps that take the game from empty to shipped. |
| Risks | The three things most likely to break, and the smallest prototype that tests each. |

#### Star Catcher, filled in

**Title.** Star Catcher.

**Concept.** A gold ship catches falling stars for points while a 30-second clock and three lives run out.

**Core loop.**
1. A star appears at Y=24 at a pseudo-random X and falls.
2. The player moves the ship left or right at 2 pixels per frame.
3. If the ship and the star overlap, the score goes up by one, the catch blip plays, and the star respawns.
4. If the star passes Y=180, a life is lost, the miss buzz plays, and the star respawns.
5. The loop repeats until the lives reach zero or the 30-second clock reaches zero.
6. The over screen shows the final score; fire restarts at step 1.

**Controls.** Left joystick left/right moves the ship at 2 pixels per frame, clamped to X=8..152. Fire is an edge: it starts the title and restarts the over screen; a press during play does nothing. With no direction for 120 frames, the auto-demo takes over.

**Screen map.**
- 0-8: the score band (nine lines; six digits, white).
- 9: blank; the score's three-copy mode ends.
- 10-14: the positioner; P0 moves from X=56 to the ship's X.
- 15-19: the status zone; a two-line timer bar, a blank line, a one-line lives marker, a blank line.
- 20-167: open zone A; the falling star.
- 168-175: the player zone; the 8x8 ship and the star.
- 176-190: open zone B; the falling star.
- 191: blank; the overscan begins on line 229.

**Object list.**

| Object | Size | Color | Job |
| --- | --- | --- | --- |
| Ship (P0) | 8x8 | gold `$1A` | The player's catcher. |
| Star (ball) | 4x4 | gold `$1A` | The falling item; catch it. |
| Score (P0/P1, three copies each) | 6 digits, 48x8 | white `$0E` | The catch count. |
| Timer bar (playfield) | 2 lines, 0..40 chunks | gold `$1A` | The remaining 30 seconds. |
| Lives (playfield) | 1 line, 0..3 chunks | gold `$1A` | The remaining lives. |
| Title emblem (P0) | 8x12 | gold `$1A` | The title's visual. |
| Prompt (playfield) | 4 lines, dashed | gold/dark grey on the title; white/dark grey on the over screen | "PRESS FIRE" on the title, "FIRE" on the over screen. |

**States.**
- **0 TITLE.** Entry: power-on or `ScoreInit` zeroed buffer. Exit: a fire edge, or 60 settle frames plus 120 demo frames. Persists: the score buffer is blank; the ship is the emblem at X=76.
- **1 PLAY.** Entry: `StartPlay`. Exit: lives=0 or timer=0. Persists: the score, the ship's X, the item, the clock.
- **2 OVER.** Entry: the last miss or the clock. Exit: a fire edge. Persists: the final score in the band; the field is red.

**Win/lose.** There is no win state in the skeleton; the score is the measure. You lose when the three lives reach zero or the 30-second clock reaches zero. A target score (for example, 20 catches) is a good first design exercise and a clean way to add a win.

**Score.** One point per catch, shown as six digits with leading zeros (`000000`). The `Score` byte is an 8-bit catch count used by the spawn mix; it wraps at 256. The displayed number is the six-digit `ScoreDigits`/`ScoreBuf` pair, advanced by `ScoreAddOne`, which continues to 999999 and then wraps to 000000. A 30-second game reaches neither wrap.

**Audio.** A catch blip on channel 0: `AUDC=$0C`, a four-step rising tone. A miss buzz on channel 1: `AUDC=$08`, a five-step noise burst. The catch has priority 4 and the miss priority 6; they use separate channels, so they can overlap. `SoundUpdate` runs once per frame.

**Milestones.** M1 frame + input; M2 core loop + score; M3 audio + states; M4 polish + captures. Each has a test; see Section 6.

**Risks.**
- **The RAM map.** The score library owns `$A0-$D7`; the sound library owns `$88-$8D` and `$90-$9F`. A variable at `$90` breaks the sound engine. The prototype is the map itself: name every byte before writing a routine.
- **The visible positioner.** The score uses P0 at X=56 for nine lines; the play area needs P0 at `PlayerX`. The divide-by-15 routine's length varies with X, so a naive positioner changes the number of lines and the frame. The prototype is the frame with the positioner and a breakpoint at `OverscanStart`; the fix is the fixed 60-cycle pad.
- **The collision lag.** `CXP0FB` is the previous frame's overlap. The catch must be read before the item moves, and `CXCLR` must clear the latch every frame. The prototype is one falling item and a fixed ship, with the catch log.

### Section 3: The RAM map worksheet

The 2600 has 128 bytes of RAM at `$80-$FF`. The worksheet is a 128-byte grid: every byte is either **named** (a game variable), **owned** (by a library), **free**, or **stack**. The rule is absolute: **no data under the stack**. The stack starts at `$FF` and grows down; if a deep call reaches a variable, the variable changes without a warning.

#### The 128-byte grid

```text
         +0   +1   +2   +3   +4   +5   +6   +7
$80      GS   PX   IX   IY   SC   LV   TM   FR
$88      s    s    s    s    s    s    PF   AT
$90      S    S    S    S    S    S    S    S
$98      S    S    S    S    S    S    S    S
$A0      D0   D1   D2   D3   D4   D5   SR   ST
$A8      B0   B1   B2   B3   B4   B5   B6   B7
$B0      B8   B9   B10  B11  B12  B13  B14  B15
$B8      B16  B17  B18  B19  B20  B21  B22  B23
$C0      B24  B25  B26  B27  B28  B29  B30  B31
$C8      B32  B33  B34  B35  B36  B37  B38  B39
$D0      B40  B41  B42  B43  B44  B45  B46  B47
$D8      SU   ID   CI   IL   TI   --   --   --
$E0      --   --   --   --   --   --   --   --
$E8      --   --   --   --   --   --   --   --
$F0      --   --   --   --   --   --   --   --
$F8      ST   ST   ST   ST   ST   ST   ST   ST
```

Legend:

| Mark | Meaning |
| --- | --- |
| `GS` | `GameState`: 0 title, 1 play, 2 over. |
| `PX` | `PlayerX`: 8..152. |
| `IX` | `ItemX`: 8..148. |
| `IY` | `ItemY`: 24..181. |
| `SC` | `Score`: the 8-bit catch count. |
| `LV` | `Lives`: 3..0. |
| `TM` | `Timer`: 30..0 seconds. |
| `FR` | `Frame`: the free-running frame counter. |
| `s` | The sound engine's scratch: `SndID`, `SndChan`, `SndDefL/H`, `SndTabL/H` (`$88-$8D`). |
| `PF` | `PrevFire`: the previous `INPT4` bit 7. |
| `AT` | `AutoTimer`: frames with no joystick direction. |
| `S` | The sound engine's state: `SndPtrL/H`, `SndTimer`, `SndStep`, `SndPrio`, `SndActive`, `SndFreq`, `SndVol` (`$90-$9F`). |
| `D0-D5` | `ScoreDigits`: six binary digits, left to right (`$A0-$A5`). |
| `SR`, `ST` | `ScoreRow`, `ScoreTmp`: the score kernel's scratch (`$A6-$A7`). |
| `B0-B47` | `ScoreBuf`: six columns x eight rows, column-major, bottom-up (`$A8-$D7`). |
| `SU` | `Startup`: the 60-frame boot settle, then the 60-frame second tick. |
| `ID` | `ItemDir`: 1 normal (2 px/frame), 2 forced miss (1 px/frame). |
| `CI` | `CurItem`: alternates 0/1; 0 normal spawn, 1 forced miss. |
| `IL` | `ItemLine`: `ItemY - 15`. |
| `TI` | `TimerIdx`: `2 * (Timer / 3)`, 0..20. |
| `--` | Free. |
| `ST` | The stack, `$F8-$FF`; the pointer starts at `$FF`. |

The important entries are the **owned** ranges. `include/score.asm` owns `$A0-$D7` (six digits, two scratch bytes, and the 48-byte buffer). `include/sound.asm` owns `$88-$8D` (scratch) and `$90-$9F` (state). The game variables therefore live at `$80-$87`, `$8E-$8F`, and `$D8-$DC`. The sound library's two free bytes at `$8E-$8F` are exactly enough for `PrevFire` and `AutoTimer`.

> **The plan's first map and the library's map.** It is tempting to write "the game variables are `$80-$9F`" and stop. That map is wrong the moment the sound library is sourced: `$88-$8D` and `$90-$9F` already have an owner. The worksheet above corrects the map to the bytes that are actually free. This is the lesson's most practical design rule: **a library's RAM map is part of your RAM map**. If you cannot name the owner of a byte, you cannot use it.

::: warning No data under the stack
The stack starts at `$FF` and grows down. The deepest game call chain (`PlayUpdate` -> `MoveItem` -> `CatchItem` -> `ScoreAddOne` -> `ScoreSetDigit`) is five JSRs (10 bytes) plus two `PHA`s in `ScoreAddOne` and two in `ScoreSetDigit`: 14 bytes. The pointer ends at `$F1`, and the lowest byte written is `$F2`. That is safe here only because `$DD-$F7` is free. If a variable lived at `$F2`, a catch could overwrite it. The rule is not "leave a few bytes"; it is "leave the bytes the deepest call can reach empty".
:::

### Section 4: The screen map worksheet

The screen map is the 192-line answer to "what draws on each line?" It must sum to 192 and every zone must have a kernel whose per-line code fits 76 CPU cycles. Star Catcher's map:

| Picture lines | Lines | Zone | What draws |
| --- | ---: | --- | --- |
| 0-8 | 9 | Score band | `ScoreDraw`: line 0 is setup/blank, lines 1-8 are the six white digits. |
| 9 | 1 | Blank | `NUSIZ0=0`, PF and `ENABL` cleared. |
| 10-14 | 5 | Positioner | P0 from the score's X=56 to `PlayerX`; one divide, one HMOVE. |
| 15-19 | 5 | Status | Two timer-bar lines, one blank, one lives line, one blank. |
| 20-167 | 148 | Open A | The falling star; the ship is blank here. |
| 168-175 | 8 | Player | The 8x8 ship and the star. |
| 176-190 | 15 | Open B | The falling star; the ship is blank here. |
| 191 | 1 | Blank | Clear the sprites; the overscan begins on line 229. |

`9 + 1 + 5 + 5 + 148 + 8 + 15 + 1 = 192`.

#### The 192-line grid

```text
line 000-008  [score band, 9]       line 096-103  [open A, 8]
line 009      [blank, 1]            line 104-111  [open A, 8]
line 010-014  [positioner, 5]       line 112-119  [open A, 8]
line 015-019  [status, 5]           line 120-127  [open A, 8]
line 020-027  [open A, 8]           line 128-135  [open A, 8]
line 028-035  [open A, 8]           line 136-143  [open A, 8]
line 036-043  [open A, 8]           line 144-151  [open A, 8]
line 044-051  [open A, 8]           line 152-159  [open A, 8]
line 052-059  [open A, 8]           line 160-167  [open A, 8]
line 060-067  [open A, 8]           line 168-175  [player, 8]
line 068-075  [open A, 8]           line 176-183  [open B, 8]
line 076-083  [open A, 8]           line 184-190  [open B, 7]
line 084-091  [open A, 8]           line 191      [blank, 1]
line 092-095  [open A, 4]
```

The grid covers all 192 lines: 9 + 1 + 5 + 5 + 148 + 8 + 15 + 1. The open-A zone is 148 lines, so the last block is four lines (092-095) and the first block starts at 020; the player zone starts at 168.

#### The kernel choice and the cycle budget

The play area is a **one-line zone kernel**. Each line writes the registers for that line, then waits with `STA WSYNC`. The zones have different jobs, so they have different code:

| Zone line | Code | Cycles (derived) | First store deadline |
| --- | --- | ---: | --- |
| Status, timer | Two PF loads/stores (3 bytes) + clear ships | ~30 | PF0 at cycle ~10, before ~22.7 |
| Status, lives | One PF load/store + clears | ~20 | PF0 at cycle ~10 |
| Open A | Item check + `ENABL` store | ~24 | `ENABL` at cycle ~20, before ~24 |
| Player | `GRP0` store + item check | ~31 | `GRP0` at cycle ~7, before ~25.3 |
| Title/over | PF or `GRP0` store + branch | ~30 | PF0 at cycle ~16; P0 at X=76 is late |

The deadlines come from the TIA output delay: a player's leftmost pixel at X=8 appears around cycle `(8+68)/3 ≈ 25.3`; the ball's output delay is one color clock shorter, so its deadline is a little earlier; PF0's first chunk is around cycle 22.7. The player store is first in its zone, at cycle ~7; the ball store follows at ~20. Both are before their pixels. The status PF0 store is at ~10. The item's minimum X is 8, so the ~20-cycle `ENABL` store has about a four-cycle margin; the measured picture shows the 4-pixel item at X=8 (the 6-second capture), so the margin holds in Stella.

::: tip The score band is not free
The nine score lines are the score library's contract. They are not part of the play area's 176 lines; the positioner's five lines are not free either. A screen map that starts the play area at line 0 will draw the game over the score, and a map that forgets the positioner will put the ship at X=56. Count the bands before counting the kernel.
:::

### Section 5: The 4K budget worksheet

The cartridge window is 4,096 bytes at `$F000-$FFFF`, and the six vectors occupy `$FFFA-$FFFF`. The budget is measured from the symbol file, not estimated. The labels `ScoreLibStart`, `ScoreLibEnd`, `SoundLibStart`, and `SoundLibEnd` are placed around the two includes; the rest of the spans are the symbol addresses of the named routines and tables.

| Block | Bytes | Measurement |
| --- | ---: | --- |
| Score library | 325 | `ScoreLibStart` to `ScoreLibEnd` |
| Sound library | 242 | `SoundLibStart` to `SoundLibEnd` |
| Keep: reset, frame, state/restart, fire, auto-demo timer | 530 | `Reset` to `ReadJoystick` |
| `YOUR GAME — INPUT` | 112 | `ReadJoystick` to `PlayUpdate` |
| `YOUR GAME — UPDATE` | 191 | `PlayUpdate` to `TitleScreen` |
| `YOUR GAME — DRAW` | 339 | `TitleScreen` to `PlayerGfx` |
| Graphics tables | 90 | `PlayerGfx` to `SoundTable` |
| Sound table | 34 | `SoundTable` to `SetCoarseP0` |
| Positioners | 66 | `SetCoarseP0` to the end of `SetCoarseBL` |
| Vectors | 6 | `$FFFA-$FFFF` |
| Padding | 2,161 | `4,096 - 1,935` |
| **Total** | **4,096** | |

The font is inside the score library: `ScoreFont` is ten glyphs x eight bytes = **80 bytes**. The "strings" line is **0 bytes**: the title/over prompt is a playfield bar, not a text string, and the six score digits are the font. The tables are the 8-byte ship, the 12-byte emblem, the 63-byte timer tables, the 4-byte lives table, and the 3-byte fall-speed table.

The used image is **1,935 bytes** (1,929 bytes of code/data plus 6 vector bytes); the headroom is **2,161 bytes**. That is a lot of room, and it is intentional: the skeleton is a starting point, and the reader's game will spend the headroom on more objects, more states, or a bigger title screen. The worksheet's job is to make the spending visible before it happens.

::: warning The number that matters is the one after the edit
Measure the ROM after every table you add, not once at the end. A 64-entry x 3-byte playfield table is 192 bytes; three of them are 576 bytes, which is a quarter of the game. `npm run roms` reports the assembled size, and the symbol file gives the spans. If the size is 4,096 because the assembler filled the window, the used bytes are still the number in the table.
:::

### Section 6: The milestone plan

A milestone is a tested state, not a task list. Each one should be runnable and should have a measurement that can fail. Star Catcher's plan:

| Milestone | Deliverable | Test | What can fail |
| --- | --- | --- | --- |
| **M1 Frame + input** | The 262-line frame, the score band, the positioner, the title, the fire edge, the joystick read | Stella breakpoints: `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229. Fire starts the title; a held fire does not restart twice. | A positioner that adds a line; a fire level that starts twice |
| **M2 Core loop + score** | The falling star, the catch and miss, three lives, the six-digit score | `Catch` A=0 and `ScoreWrite` A=1; `Miss` A=2/1/0; `ItemSpawn` A=the X; the screen shows `000001` and the timer bar | The collision latch read after the move; a score that does not carry |
| **M3 Audio + states** | The sound table, the title/play/over states, the red field, fire restart | `StateChange` A=1 at frame 180 and A=2 at frame 645; the catch blip on channel 0 and the buzz on channel 1; fire restarts from over | A sound that never mutes; a restart that keeps the old score |
| **M4 Polish + captures** | The timer bar, the auto-demo, the 2-second and 6-second captures, the pixel checks, `verify.sh` | The ROM is 4,096; `npm run roms` reports 265; the images are 1010x807 with the title bar and no cursor; `scripts/verify.sh` passes | A demo that is not deterministic; a capture from the wrong ROM |

The riskiest mechanic is the **visible positioner plus the frame budget**. The score library consumes nine lines and uses P0 at X=56; the play area needs P0 at `PlayerX`. The divide-by-15 loop takes a variable number of cycles, so a naive positioner changes the number of lines and the frame. The smallest prototype is the frame with the score band, the positioner, and a `OverscanStart` breakpoint: if the breakpoint is not 229 for every X, the positioner is wrong before the game logic exists. Star Catcher's fixed 60-cycle pad makes the divide 88-138 cycles long; it starts on the line after its `WSYNC` and ends 12-62 cycles into the second line. The caller's 8-cycle `HMP1`/`HMBL` clear extends the body to 20-70 cycles into the second line, and the trailing `WSYNC` halts to the third line, where the `HMOVE` is strobed. The trace is 229 for every X.

The second risk is the **RAM map**, and it is tested by the map itself: `$88-$8D` and `$90-$9F` are the sound library's; `$A0-$D7` is the score library's; the variables are at `$80-$87`, `$8E-$8F`, and `$D8-$DC`. The third is the **collision lag**, tested by the first catch and the first miss in the state log.

### Section 7: The skeleton and the three sections

The skeleton is a complete game with a seam. The seam is three banners; everything above and below them is the kept machinery.

| Section | Routines | The contract |
| --- | --- | --- |
| `YOUR GAME — INPUT` | `ReadJoystick`, `DemoFollow` | Read `SWCHA`/`INPT4`, move `PlayerX`, reset `AutoTimer` on human input, and make the demo deterministic. |
| `YOUR GAME — UPDATE` | `TickTimer`, `MoveItem`, `CatchItem`, `MissItem`, `SpawnItem` | Change `ItemX/ItemY/ItemLine`, `Score`, `Lives`, `Timer`, and `GameState`; call `ScoreAddOne`, `SoundTrigger`, and `SetState`. |
| `YOUR GAME — DRAW` | `TitleScreen`, `PlayScreen`, `OverScreen`, the graphics tables | Consume exactly 176 picture lines and jump to `PictureEnd`; write only the TIA registers for the current line. |

The kept machinery is:

- **The frame.** `StartFrame` -> `VblankStart` -> `BodyStart` -> `ScoreDone` -> `PlayStart` -> `PictureEnd` -> `OverscanStart`. The measured trace is 259/3, 0/5, 37/5, 229.
- **The score calls.** `ScoreInit` at reset, `ScoreClear` at `StartPlay`, `ScoreSetup` every frame in VBLANK, `ScoreDraw` every frame at `BodyStart`, `ScoreAddOne` on a catch.
- **The sound calls.** `SoundInit` at reset, `SoundTrigger` on a catch/miss, `SoundUpdate` once per frame.
- **The state and restart helpers.** `SetState` (`StateChange`), `StartPlay`, `ReadFire`.
- **The auto-demo timer.** `TitleUpdate` (the 60-frame settle and the 120-frame auto-start), and the `AutoTimer`/`DemoFollow` contract.

The skeleton is not a framework. It is a working game whose three sections are intentionally small enough to replace. If the reader's game needs a different state machine, the `SetState` helper and the VBLANK dispatch are the two places to change; if it needs a different score, the score library's API is the same; if it needs a different screen, the 176-line contract and the score band's nine lines are the boundary.

### Section 8: The production checklist

The course's five hard rules apply to every lesson, and they apply doubly to a game the reader will ship. The checklist for Star Catcher:

| Rule | How this lesson satisfies it |
| --- | --- |
| **1. VitePress rework** | The lesson page has the sidebar entry (`config.ts:167`), prev 71 / next Part 11, the two images, and the `<RomPlayer>` embed; `npm run docs:build` passes. The Part 10 index row is flipped in the lesson commit (the parent integrates it). |
| **2. Stella screenshots** | `title.png` at 2 s and `play.png` at 6 s are captures of the committed ROM via `scripts/capture-screenshot.sh`, 1010x807, title bar `Stella 7.0: "demo-72"`, no cursor. |
| **3. Preflight** | The concepts are covered by Lessons 39, 41, 45, 46, 47, 69, 70, and 71; the register names come from `include/vcs.asm`; the frame and state logs are measured in Stella. |
| **4. README sync** | The curriculum listing does not change (Lesson 72 already exists), so README row 10 is unchanged. |
| **5. ROM + player** | `npm run roms` builds 265 ROMs; `demo-72.bin` is 4,096 bytes and committed; the `<RomPlayer>` is under the play screenshot. |

The checklist is not paperwork. Each line is a test that catches a different failure: a missing sidebar entry is a broken link; a screenshot from a scratch ROM is a false claim; a preflight gap is a forward reference; a README mismatch is a curriculum drift; an uncommitted ROM is a lesson that cannot be played.

### Section 9: Captures and determinism

A moving game is hard to screenshot because a fixed wait can catch the wrong state. Star Catcher solves this the same way the capstones do: a **deterministic auto-demo**.

- The title's auto-demo timer waits 60 frames (one second) for the boot settle, then 120 frames (two seconds) with no fire. The auto-start is at frame 180, three seconds after power-on. A fire press is accepted at any time; a button held at power-on is not an edge because `PrevFire` starts at 0.
- The 2-second capture is therefore the title: the emblem is on screen and the score band is blank because the score buffer is still zero. The prompt is in whichever blink phase the capture frame selects; the published capture is gold.
- The auto-start sets `AutoTimer=120`, so the demo is active on the first play frame. The demo tracks the star at one pixel per frame.
- Every second item is a forced miss: it spawns on the far side of the ship, falls at one pixel per frame, and the demo does not chase it. The forced miss lands about 156 frames after the spawn, close to the 180-frame design target.
- The first normal item is caught at frame 252. The 6-second capture shows the play state with `000001`, the timer bar, the lives, the ship, and a falling star.
- Three misses reach the over state at frame 645 (about 10.75 seconds). The over screen is red, the final score is white, and the prompt bars blink.

The captures are made from the committed ROM path, not a scratch copy, so the window title is the real ROM name. The pointer is parked at `(0,0)` with `xdotool mousemove 0 0` before each capture; `import -window` captures the window only, and no cursor appears in the image. The wall-clock waits are 2 and 6 seconds; Stella's startup takes the first fraction of a second, so the images show roughly ROM frames 100-120 and 350-380, which are the title and the play state. The state log below uses the same committed ROM and the labels from the symbol file. The captures and the state log are from the committed ROM; the auto-demo exercises the state and score paths and calls `StartPlay` from the title; the over-to-play fire restart, the sound, and the manual fire/joystick paths are code-verified; the over state is state-log-verified at frame 645 but is not one of the two published captures.

> **Disclosure.** The auto-demo is a capture tool, not a hidden player. It is disclosed here and in the source header. Any joystick direction resets `AutoTimer` and returns control to the reader. The forced-miss item is a deliberate design choice: it makes the over state reachable in a short run without waiting for a human to miss three times, and it keeps the captures reproducible.

## The Code

### Building This Lesson

```bash
# assemble every lesson ROM into docs/public/roms/ (the new ROM is 4,096 bytes)
npm run roms

# or just this one:
acme -f plain -o build/demo-72.bin lessons/part10-capstones/72-your-game/demo-72.asm
stella build/demo-72.bin
```

The source header carries the screen map, the frame, the RAM map, the checkpoint list, and the build/run commands. The symbol file is the address book for the state log:

```bash
acme -f plain -l build/demo-72.sym -o build/demo-72.bin \
  lessons/part10-capstones/72-your-game/demo-72.asm
grep -E "StartFrame|VblankStart|BodyStart|OverscanStart|StateChange|ScoreWrite|ItemSpawn|Catch|Miss" build/demo-72.sym
```

### Full Source

The complete annotated source is the file the reader should open beside this page. It is reproduced verbatim between the markers; the file remains the source of truth.

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 72: Capstone 4 — Your Own Game — Racing the Beam
; =============================================================================
; Part 10: Capstone Projects
;
; What this program does:
;   "Star Catcher" is a complete 4,096-byte mini-game and the skeleton for
;   the reader's own game.  The player catches falling stars with a gold ship
;   while a 30-second clock runs.  Three states drive the machine:
;
;     State 0 TITLE   a gold emblem (P0) and a blinking bar prompt that
;                     stands for "PRESS FIRE" (the course has no text engine
;                     in this skeleton).  The score is hidden because the
;                     score buffer is still zeroed.  Fire begins play; with
;                     no fire the auto-demo begins after a one-second settle
;                     plus two seconds.
;     State 1 PLAY    the score band at the top, a timer bar and three life
;                     markers in the first five play lines, the ship at
;                     Y=168, and a 4x4 ball item falling from Y=24 at a
;                     pseudo-random X (two pixels per frame; the demo's
;                     forced-miss items fall one, slowly).  A catch (CXP0FB bit 6)
;                     scores one and
;                     respawns the item; a miss (ItemY > 180) costs a life.
;                     The 30-second clock is shown as a bar that shrinks.
;     State 2 OVER    the final score stays in the score band, the field
;                     turns red, and the prompt bars blink.  Fire restarts.
;
;   The score library (include/score.asm) draws the six-digit score in nine
;   visible lines.  The sound library (include/sound.asm) plays a catch blip
;   on channel 0 and a miss buzz on channel 1.  Fire is an edge, not a level:
;   the title starts play and the over screen restarts; a fire press during
;   play does nothing.
;
; The screen (192 visible lines):
;   picture lines 0-8     the score band.  ScoreDraw consumes nine lines:
;                         line 0 is the setup/blank line and lines 1-8 are
;                         the six digits.  On the title the score buffer is
;                         zero, so the band is blank and the score is hidden.
;   picture line 9        blank; NUSIZ0 returns to one copy.
;   picture lines 10-14   the visible positioner: P0 is moved from the
;                         score's X=56 to PlayerX with one divide and one
;                         HMOVE.  The ball was positioned in VBLANK and the
;                         score's HMOVE applied it.  HMP1/HMBL are zeroed
;                         just before the second HMOVE, outside the first
;                         HMOVE's 24-cycle window, so it moves only P0.
;   picture lines 15-19   the status zone: two timer-bar lines, one blank,
;                         one lives line, one blank.
;   picture lines 20-167  open zone A: 148 lines of the falling item.
;   picture lines 168-175 the player zone: the 8x8 ship and the item.
;   picture lines 176-190 open zone B: 15 lines of the falling item.
;   picture line 191      blank.
;   9 + 1 + 5 + 5 + 148 + 8 + 15 + 1 = 192.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame is scanline 259, VblankStart 0, BodyStart 37, ScoreDone 46,
;   OverscanStart 229.
;
; The RAM map (the exact map; +clean_start zeroes every byte):
;   $80      GameState     0 = title, 1 = play, 2 = over
;   $81      PlayerX       8..152, the ship's left edge
;   $82      ItemX         8..148, the ball's left edge
;   $83      ItemY         24..181, the ball's top visible line
;   $84      Score         0..255, the catch count
;   $85      Lives         3..0
;   $86      Timer         30..0, seconds
;   $87      Frame         the free-running frame counter
;   $88-$8D  sound engine scratch (SndID, SndChan, SndDefL/H, SndTabL/H)
;   $8E      PrevFire      the previous INPT4 bit 7 (0 pressed, $80 released)
;   $8F      AutoTimer     frames with no joystick direction
;   $90-$9F  sound engine state (SndPtr, SndTimer, SndStep, ...)
;   $A0-$D7  score library (ScoreDigits, ScoreRow, ScoreTmp, ScoreBuf)
;   $D8      Startup       60-frame boot settle, then the 60-frame second tick
;   $D9      ItemDir       1 normal (2 px/frame), 2 forced miss (1 px/frame)
;   $DA      CurItem       alternates 0/1: 0 normal spawn, 1 forced miss
;   $DB      ItemLine      ItemY - 15, the item's play-area line
;   $DC      TimerIdx      2 * (Timer / 3), 0..20, the bar's half-width
;   $DD-$F7  free; the deepest call uses 14 bytes, so SP can reach $F1
;   $F8-$FF  the stack (starts at $FF)
;
;   The sound library owns $88-$8D and $90-$9F, so the game variables sit
;   at $80-$87, $8E-$8F, and $D8-$DC.  No variable lives in the score
;   library, in the free area, or under the stack.
;
; The 30-second clock:
;   Startup counts 60 frames; when it reaches zero it is reloaded and Timer
;   is decremented.  30 ticks x 60 frames = 1,800 frames = 30 seconds at the
;   nominal 60 Hz NTSC frame.  2 * (Timer / 3) is the centered bar's
;   half-width, 0..20 chunks; the bar loses two chunks on each side every
;   three seconds.  When Timer reaches zero the game is over.
;
; The auto-demo (disclosed):
;   After a 60-frame boot settle the title counts 120 more frames with no
;   fire and then starts play with AutoTimer = 120, so the demo is active on
;   the first play frame.  The demo moves P0 toward ItemX at one pixel per
;   frame.  Every second item is a forced miss: it falls at one pixel per
;   frame and spawns on the far side of the player, and the demo does not
;   chase it.  The result is deterministic: the first normal item is caught,
;   then the forced items miss (a normal item can also miss when the ship
;   cannot cross the distance in time); three misses reach the over state.
;   Any joystick direction resets AutoTimer and returns control to the
;   reader.
;
; The three replaceable sections:
;   YOUR GAME — INPUT    ReadJoystick and DemoFollow: the controls.
;   YOUR GAME — UPDATE   TickTimer, MoveItem, CatchItem, MissItem, SpawnItem:
;                        the rules, scoring, and collision policy.
;   YOUR GAME — DRAW     TitleScreen, PlayScreen, OverScreen and the small
;                        graphics tables: the screen.
;   Keep the frame, the score calls, the sound calls, the state/restart
;   helpers, and the auto-demo timer.  Replace the bodies of the three
;   sections and the skeleton becomes your game.
;
; Controls:
;   Left joystick left/right moves the ship at two pixels per frame.
;   Fire starts the title and restarts the over screen (a press edge).
;
; Checkpoints (the A/X/Y/SP values are the state at the label):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   OverscanStart (229/2), StateChange (A = the new state),
;   ScoreWrite (A = the new score), ItemSpawn (A = the item's new X),
;   Catch (A = the score before the catch), Miss (A = the new Lives).
;
; Build: acme -f plain -o build/demo-72.bin \
;        lessons/part10-capstones/72-your-game/demo-72.asm
; Run:   stella build/demo-72.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
; The 42-cycle fill keeps each zone-boundary WSYNC store before the end of
; the line; a late WSYNC still halts to the next line, which is why the fill
; is fixed-length.  It is timing, not decoration.
!macro burn_line {
    !fill 21, $EA          ; 21 NOPs = 42 cycles
}

VBLANK_TIMER    = 44       ; 1 + 43 x 64 = 2753 cycles; the timer plus the
                           ; final WSYNC make the measured 37-line VBLANK
OVERSCAN_TIMER  = 36       ; 1 + 35 x 64 = 2241 cycles; the measured 30 lines

SCREEN_LINES    = 176      ; the play-area lines: picture 15..190
PLAY_TOP        = 15       ; the first picture line after the score/positioner
PLAYER_Y        = 168      ; the ship's top visible line
PLAYER_LINE     = (PLAYER_Y - PLAY_TOP) ; 153
PLAYER_MIN      = 8        ; the ship's left-edge limits
PLAYER_MAX      = 152
PLAYER_SPEED    = 2        ; human movement, pixels per frame
PLAYER_BIAS     = 3        ; the Lesson 26 player output-delay bias
BALL_BIAS       = 4        ; the ball's output delay is one clock shorter
PLAYER_HEIGHT   = 8

ITEM_TOP        = 24       ; the item's first visible line
ITEM_LINE_TOP   = (ITEM_TOP - PLAY_TOP) ; 9
ITEM_MISS       = 180      ; ItemY > 180 is a miss
ITEM_HEIGHT     = 4        ; the 4-pixel ball is four lines tall

STARTUP_FRAMES  = 60       ; one second of boot settle, then one second tick
AUTO_START      = 120      ; title frames with no fire before the auto-demo
TIMER_TICK      = 60       ; frames per Timer second
TIMER_FULL      = 30       ; the clock starts at 30 seconds
TIMER_IDX_FULL  = 20       ; 2 * (30 / 3): the centered bar's half-width

C_SCORE         = $0E      ; the score digits and the over prompt: white
C_PLAYER        = $1A      ; the ship, the item, the timer bar: gold
C_TITLE         = $1A      ; the title emblem and prompt: gold
C_TITLE_DIM     = $06      ; the prompt's off phase: dark grey
C_OVER          = $46      ; the over field: red
C_BG            = $00      ; the play and title background: black

; =============================================================================
; RAM MAP — the exact map (see the header for the full description)
; =============================================================================
GameState       = $80      ; 0 = title, 1 = play, 2 = over
PlayerX         = $81      ; 8..152
ItemX           = $82      ; 8..148
ItemY           = $83      ; 24..181
Score           = $84      ; 0..255
Lives           = $85      ; 3..0
Timer           = $86      ; 30..0 seconds
Frame           = $87      ; the free-running frame counter
PrevFire        = $8E      ; the previous INPT4 bit 7
AutoTimer       = $8F      ; frames with no joystick direction
Startup         = $D8      ; boot settle, then the 60-frame second tick
ItemDir         = $D9      ; 1 normal (2 px/frame), 2 forced (1 px/frame)
CurItem         = $DA      ; alternates 0/1
ItemLine        = $DB      ; ItemY - 15
TimerIdx        = $DC      ; 2 * (Timer / 3), 0..20
; $88-$8D and $90-$9F belong to the sound library; $A0-$D7 to the score
; library; $DD-$F7 are free; the stack starts at $FF.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; THE SHARED LIBRARIES
; =============================================================================
; The score library owns $A0-$D7 and the sound library owns $88-$8D and
; $90-$9F.  They are sourced first so the README's 4K worksheet can measure
; each library exactly from ScoreLibStart/ScoreLibEnd and SoundLibStart/
; SoundLibEnd.  The reset vector at $FFFC points at Reset below.
ScoreLibStart:
    !source "include/score.asm"
ScoreLibEnd:
SoundLibStart:
    !source "include/sound.asm"
SoundLibEnd:

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joystick)

    LDA #C_SCORE
    STA COLUP0              ; the score's left digits
    STA COLUP1              ; the score's right digits
    LDA #C_TITLE
    STA COLUPF              ; the title emblem's prompt and the play item
    LDA #C_BG
    STA COLUBK

    LDA #$21                ; reflect mode + a 4-pixel ball
    STA CTRLPF
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA VDELP0
    STA VDELP1
    STA VDELBL
    STA REFP0
    STA REFP1

    LDA #0
    STA GameState           ; state 0 = title
    STA Score
    STA Frame
    STA AutoTimer
    STA CurItem
    STA PrevFire
    LDA #STARTUP_FRAMES
    STA Startup
    LDA #TIMER_FULL
    STA Timer
    LDA #TIMER_IDX_FULL
    STA TimerIdx
    LDA #3
    STA Lives
    LDA #76                 ; the title emblem and the play start position
    STA PlayerX
    STA ItemX
    LDA #ITEM_TOP
    STA ItemY
    LDA #ITEM_LINE_TOP
    STA ItemLine
    LDA #1
    STA ItemDir

    JSR ScoreInit           ; six digits and the 48-byte buffer are zero
    JSR SoundInit           ; both audio channels are silent

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK              ; blank the picture while the game thinks
    +set_timer VBLANK_TIMER
    INC Frame

; The previous frame left the playfield and the sprites latched.  Clear them
; before the score band: the score uses only P0/P1/PF=0, and the ball would
; otherwise appear at ItemX during the score's nine lines.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    STA GRP0
    STA GRP1

; The score is white in every state; the state-specific background and
; playfield colours are chosen next.
    LDA #C_SCORE
    STA COLUP0
    STA COLUP1

    LDA GameState
    CMP #2
    BEQ VblankOverColors
    CMP #1
    BEQ VblankPlayColors

    ; title: black field, and the prompt blinks gold/dark grey
    LDA #C_BG
    STA COLUBK
    LDA Frame
    AND #$3F
    CMP #48
    BCS VblankTitleDim
    LDA #C_TITLE
    JMP VblankStorePF
VblankTitleDim:
    LDA #C_TITLE_DIM
VblankStorePF:
    STA COLUPF
    JMP VblankColorsDone

VblankPlayColors:
    LDA #C_BG
    STA COLUBK
    LDA #C_PLAYER
    STA COLUPF              ; the timer bar, lives and item are gold
    JMP VblankColorsDone

VblankOverColors:
    LDA #C_OVER
    STA COLUBK              ; the over field is red
    LDA Frame
    AND #$3F
    CMP #48
    BCS VblankOverDim
    LDA #C_SCORE
    JMP VblankStoreOverPF
VblankOverDim:
    LDA #C_TITLE_DIM
VblankStoreOverPF:
    STA COLUPF              ; the over prompt blinks white/dark grey
VblankColorsDone:

; -----------------------------------------------------------------------------
; 1. THE FIRE EDGE AND THE STATE UPDATE
; -----------------------------------------------------------------------------
; Fire is an edge, not a level.  ReadFire starts play from the title and
; restarts from the over state; a press during play is ignored.  The title's
; boot settle and auto-demo timer live in TitleUpdate.
    JSR ReadFire

    LDA GameState
    CMP #0
    BNE VblankNotTitle
    JSR TitleUpdate
    JMP VblankStateDone
VblankNotTitle:
    CMP #1
    BNE VblankStateDone
    JSR PlayUpdate
VblankStateDone:

; -----------------------------------------------------------------------------
; 2. THE SOUND ENGINE
; -----------------------------------------------------------------------------
    JSR SoundUpdate         ; advance both channels once per frame

; The collision latches are read in MoveItem (on the previous frame's
; overlap) and cleared here, so every frame starts with a fresh latch.
    LDA #0
    STA CXCLR

; -----------------------------------------------------------------------------
; 3. THE POSITIONERS — the ball in VBLANK, then the score's one HMOVE
; -----------------------------------------------------------------------------
; The ball is positioned before ScoreSetup; ScoreSetup's single HMOVE then
; applies P0, P1 and the ball in the same horizontal blank.  Do not touch
; HMP1/HMBL here: the TIA forbids motion-register writes for 24 cycles after
; an HMOVE.  They are zeroed much later, just before the second HMOVE.
    LDA ItemX
    CLC
    ADC #BALL_BIAS
    JSR SetCoarseBL
    JSR ScoreSetup

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE 0-8 — THE SCORE BAND (nine lines from the score library)
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, picture line 0
    JSR ScoreDraw           ; nine lines; returns at scanline 46

; =============================================================================
; VISIBLE 9 — THE BLANK LINE
; =============================================================================
ScoreDone:                  ; checkpoint: scanline 46, picture line 9
    LDA #$00
    STA NUSIZ0              ; one 8-pixel copy for the ship
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    LDA #C_PLAYER
    STA COLUP0              ; the score's pixels are already latched white
    STA WSYNC               ; consume picture line 9 -> line 10

; =============================================================================
; VISIBLE 10-14 — THE PLAY POSITIONER (five lines)
; =============================================================================
; Only P0 needs a coarse position here: the ball was positioned in VBLANK
; and the score's HMOVE applied it.  The six NOPs push the first WSYNC store
; past the start of the visible area (cycle ~23) so it really ends the line;
; +burn_line does the same for the following lines.  SetCoarseP0's divide is
; padded to a fixed length, so its body always ends on the second line; the
; trailing WSYNC then halts to the third line, where the HMOVE is strobed.
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    LDA PlayerX
    CLC
    ADC #PLAYER_BIAS
    JSR SetCoarseP0
    ; Zero HMP1/HMBL here, on the second line and many lines after the
    ; score's HMOVE, before the second HMOVE.  The TIA forbids HMPx/HMBL
    ; writes for 24 cycles after an HMOVE; doing this just after
    ; ScoreSetup's HMOVE would be inside that window.
    LDA #$00
    STA HMP1
    STA HMBL
    STA WSYNC               ; the second line -> the third line (HMOVE line)
    STA HMOVE               ; the third line's HBLANK
; COLUPF was chosen in VBLANK: gold for the title/play, white/dim for the
; over prompt.  Do not overwrite it here.
    +burn_line
    STA WSYNC               ; the HMOVE's stall ends on this line
    NOP                     ; the halt has taken effect; PlayStart is line 51

; =============================================================================
; VISIBLE 14 — THE PLAY-AREA DISPATCH (the checkpoint line)
; =============================================================================
PlayStart:                  ; checkpoint: scanline 51, picture line 14
    LDA GameState
    CMP #0
    BNE PlayNotTitle
    JMP TitleScreen
PlayNotTitle:
    CMP #2
    BNE PlayIsPlay
    JMP OverScreen
PlayIsPlay:
    JMP PlayScreen

; =============================================================================
; THE BLANK LAST LINE
; =============================================================================
; Every screen routine reaches here after its 176th line.  The last sprites
; are still latched, so clear them immediately; the colour restore and the
; 42-cycle fill push the final WSYNC past HBLANK, and the overscan starts on
; scanline 229.
PictureEnd:
    LDA #$00
    STA GRP0
    STA ENABL
    LDA #C_SCORE
    STA COLUP0
    STA COLUP1
    LDA #C_PLAYER
    STA COLUPF
    +burn_line
    STA WSYNC               ; consume picture line 191 -> overscan
    NOP                     ; the halt has taken effect; overscan is line 229

; =============================================================================
; OVERSCAN — 30 lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; THE STATE AND RESTART HELPERS (keep these)
; =============================================================================
; SetState is the one place that changes GameState after reset (Reset writes
; 0 directly), so the StateChange checkpoint reports every transition with
; A = the new state.
SetState:
StateChange:                ; checkpoint: A = the new state
    STA GameState
    RTS

; StartPlay is the restart path: fire from the title or the over screen, or
; the title's auto-demo.  It zeroes the score, restores three lives and the
; 30-second clock, recentres the ship, and spawns the first item.
StartPlay:
    LDA #1
    JSR SetState
    JSR ScoreClear          ; the display reads 000000
    LDA #0
    STA Score
    STA AutoTimer
    STA CurItem
    LDA #3
    STA Lives
    LDA #TIMER_FULL
    STA Timer
    LDA #TIMER_IDX_FULL
    STA TimerIdx
    LDA #STARTUP_FRAMES
    STA Startup
    LDA #76
    STA PlayerX
    JSR SpawnItem
    RTS

; ReadFire is the fire edge and the state gate.  INPT4 bit 7 is 0 when the
; button is pressed.  PrevFire starts at 0, so a button held at power-on is
; not an edge; a new press during the first second is accepted.
ReadFire:
    LDA INPT4
    AND #$80
    TAX
    EOR PrevFire
    AND #$80
    BEQ ReadFireNoEdge
    CPX #0
    BNE ReadFireNoEdge
    STX PrevFire            ; X = 0: the pressed level
    LDA GameState
    CMP #1
    BEQ ReadFireDone        ; play ignores fire
    CMP #0
    BNE ReadFireStart       ; state 2 (over) restarts at once
ReadFireStart:
    JSR StartPlay
    JMP ReadFireDone
ReadFireNoEdge:
    STX PrevFire
ReadFireDone:
    RTS

; TitleUpdate is the auto-demo timer (keep it).  Startup is the 60-frame
; boot settle; after it the title counts 120 frames with no fire.  At 120
; the demo starts play and sets AutoTimer = 120, so the first play frame is
; already under demo control.  The 3-second total keeps the title visible
; for the 2-second capture.
TitleUpdate:
    LDA Startup
    BEQ TitleCountAuto
    DEC Startup
    RTS
TitleCountAuto:
    INC AutoTimer
    LDA AutoTimer
    CMP #AUTO_START
    BCC TitleUpdateDone
    JSR StartPlay
    LDA #AUTO_START
    STA AutoTimer
TitleUpdateDone:
    RTS

; =============================================================================
; YOUR GAME — INPUT
; =============================================================================
; Replace the bodies of ReadJoystick and DemoFollow with your game's
; controls.  ReadJoystick is called once per frame in VBLANK while the game
; is in the play state.  It owns the joystick bits and the demo takeover.
; =============================================================================

; -----------------------------------------------------------------------------
; ReadJoystick — human left/right or the deterministic auto-demo
; -----------------------------------------------------------------------------
; SWCHA is active low.  P0's directions are bits 4-7; left is bit 6 and
; right is bit 7 (include/vcs.asm is the authority).  Any direction resets
; AutoTimer, so the reader takes over immediately.  With no direction for
; 120 frames the demo tracks the item at one pixel per frame.
ReadJoystick:
    LDA SWCHA
    AND #$F0                ; P0 up/down/left/right
    CMP #$F0
    BEQ JoyNoInput
    LDA #0
    STA AutoTimer           ; any direction takes over

    LDA SWCHA
    AND #$40                ; left, active low
    BNE JoyTryRight
    LDA PlayerX
    SEC
    SBC #PLAYER_SPEED
    CMP #PLAYER_MIN
    BCS JoyStoreLeft
    LDA #PLAYER_MIN
JoyStoreLeft:
    STA PlayerX
    JMP JoyDone

JoyTryRight:
    LDA SWCHA
    AND #$80                ; right, active low
    BNE JoyDone
    LDA PlayerX
    CLC
    ADC #PLAYER_SPEED
    CMP #(PLAYER_MAX + 1)
    BCC JoyStoreRight
    LDA #PLAYER_MAX
JoyStoreRight:
    STA PlayerX
    JMP JoyDone

JoyNoInput:
    INC AutoTimer
    LDA AutoTimer
    CMP #AUTO_START
    BCC JoyDone
    JSR DemoFollow
JoyDone:
    RTS

; -----------------------------------------------------------------------------
; DemoFollow — track the item at one pixel per frame while the demo runs
; -----------------------------------------------------------------------------
; The forced-miss item (ItemDir = 2) is not chased: it spawns on the far
; side of the player, so freezing the ship guarantees the miss that makes
; the over state reachable in the capture run.
DemoFollow:
    LDA ItemDir
    CMP #2
    BEQ DemoDone            ; a forced-miss item: do not chase
    LDA PlayerX
    CMP ItemX
    BEQ DemoDone
    BCC DemoRight
    DEC PlayerX
    JMP DemoClamp
DemoRight:
    INC PlayerX
DemoClamp:
    LDA PlayerX
    CMP #PLAYER_MIN
    BCS DemoHigh
    LDA #PLAYER_MIN
    STA PlayerX
    RTS
DemoHigh:
    CMP #(PLAYER_MAX + 1)
    BCC DemoDone
    LDA #PLAYER_MAX
    STA PlayerX
DemoDone:
    RTS

; =============================================================================
; YOUR GAME — UPDATE
; =============================================================================
; Replace TickTimer, MoveItem, CatchItem, MissItem and SpawnItem with your
; game's rules.  The score and sound calls are the interface to the kept
; libraries; the state change is the interface to the kept restart path.
; =============================================================================

; -----------------------------------------------------------------------------
; PlayUpdate — one frame of the game's rules
; -----------------------------------------------------------------------------
PlayUpdate:
    JSR TickTimer
    LDA GameState
    CMP #1
    BNE PlayUpdateDone      ; the clock may have ended the game
    JSR ReadJoystick        ; YOUR GAME — INPUT
    JSR MoveItem
PlayUpdateDone:
    RTS

; -----------------------------------------------------------------------------
; TickTimer — the 30-second clock and the bar's chunk count
; -----------------------------------------------------------------------------
; Startup is the 60-frame sub-second counter.  When it expires, Timer is
; decremented and Startup reloads.  2 * (Timer / 3) is the centered bar's
; half-width, 0..20 chunks; a full bar is the whole screen width.  Timer = 0
; ends the game.
TickTimer:
    DEC Startup
    BNE TickDone
    LDA #TIMER_TICK
    STA Startup
    DEC Timer
    BNE TickBar
    LDA #0
    STA TimerIdx
    LDA #2
    JSR SetState            ; time up: over
    RTS
TickBar:
    LDA Timer
    LDX #0
TickBarDiv:
    CMP #3
    BCC TickBarDone
    SBC #3
    INX
    JMP TickBarDiv
TickBarDone:
    TXA
    ASL                     ; 2 * (Timer / 3): the bar's half-width, 0..20
    STA TimerIdx
TickDone:
    RTS

; -----------------------------------------------------------------------------
; MoveItem — the catch latch, then the fall, then the miss line
; -----------------------------------------------------------------------------
; The catch latch is read first: it describes the previous frame's pixels.
; CXP0FB bit 6 is P0/ball.  A catch respawns and skips this frame's fall.
; Otherwise the item falls by FallSpeed[ItemDir] (2 or 1) and a top line past 180 is a
; miss.  ItemLine is the item's play-area line, rebuilt on every move.
MoveItem:
    LDA CXP0FB
    AND #$40                ; P0/ball collision latch
    BEQ MoveItemFall
    JSR CatchItem
    RTS

MoveItemFall:
    LDX ItemDir
    LDA FallSpeed,X
    CLC
    ADC ItemY
    STA ItemY
    SEC
    SBC #PLAY_TOP
    STA ItemLine
    CMP #(ITEM_MISS - PLAY_TOP + 1) ; 166: ItemY > 180
    BCC MoveItemDone
    JSR MissItem
MoveItemDone:
    RTS

; -----------------------------------------------------------------------------
; CatchItem — score one, play the blip, respawn
; -----------------------------------------------------------------------------
; Catch reports the score before the add; ScoreWrite reports it after.  The
; score library's ScoreAddOne owns the six-digit carry.  The catch blip is
; sound 0 on channel 0.
CatchItem:
    LDA Score
Catch:                      ; checkpoint: A = the score before this catch
    INC Score
    LDA Score
ScoreWrite:                 ; checkpoint: A = the new score
    JSR ScoreAddOne
    LDA #0                  ; sound 0: the catch blip
    LDX #0                  ; channel 0
    JSR SoundTrigger
    JSR SpawnItem
    RTS

; -----------------------------------------------------------------------------
; MissItem — lose a life, play the buzz, respawn or end the game
; -----------------------------------------------------------------------------
; Miss reports the new Lives.  The miss buzz is sound 1 on channel 1.  At
; zero lives the state changes to over; the final score stays in the band.
MissItem:
    DEC Lives
    LDA Lives
Miss:                       ; checkpoint: A = the new Lives
    PHA
    LDA #1                  ; sound 1: the miss buzz
    LDX #1                  ; channel 1
    JSR SoundTrigger
    PLA
    BNE MissRespawn
    LDA #2
    JSR SetState            ; three misses: over
    RTS
MissRespawn:
    JSR SpawnItem
    RTS

; -----------------------------------------------------------------------------
; SpawnItem — a new item at Y=24 with a deterministic pseudo-random X
; -----------------------------------------------------------------------------
; The X mixes Frame, Score and the old ItemX, so the sequence depends on
; when catches happen but is fully deterministic.  Every second item is the
; demo's forced miss: it falls at one pixel per frame and spawns on the far
; side of the player.  CurItem toggles 0/1; ItemSpawn reports the X.
SpawnItem:
    LDA #ITEM_TOP
    STA ItemY
    LDA #ITEM_LINE_TOP
    STA ItemLine
    LDA Frame
    EOR Score
    EOR ItemX
    AND #$7F
    CLC
    ADC #8                  ; 8..135
    LDX CurItem
    BEQ SpawnNormal
    LDA #2
    STA ItemDir             ; forced miss: fall one pixel per frame
    LDA PlayerX
    CMP #80
    BCC SpawnFarRight
    LDA #PLAYER_MIN         ; the player is on the right: spawn left
    JMP SpawnStore
SpawnFarRight:
    LDA #148                ; the player is on the left: spawn right
    JMP SpawnStore
SpawnNormal:
    LDY #1
    STY ItemDir             ; normal item: fall two pixels per frame
SpawnStore:
ItemSpawn:                  ; checkpoint: A = the item's new X
    STA ItemX
    LDA CurItem
    EOR #$01
    STA CurItem
    RTS

; =============================================================================
; YOUR GAME — DRAW
; =============================================================================
; Replace TitleScreen, PlayScreen, OverScreen and the graphics tables with
; your game's screen.  Each routine consumes exactly 176 picture lines and
; jumps to PictureEnd.  The score band, the positioner and the frame are
; kept.  The play screen's zones are:
;   status 5 + open A 148 + player 8 + open B 15 = 176.
; =============================================================================

; -----------------------------------------------------------------------------
; TitleScreen — a gold emblem and a blinking bar prompt
; -----------------------------------------------------------------------------
; P0 is the 8x12 emblem at PlayerX (76); the prompt is three PF bytes at
; play lines 100-103.  COLUPF blinks between gold and dark grey, so the
; prompt is always visible but changes brightness.  The score band above is
; blank because ScoreBuf is still the zeroed buffer from ScoreInit.
TitleScreen:
    LDX #0
    LDA #0
    STA GRP0
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC               ; consume picture line 14 -> line 15

TitleLoop:
    ; The prompt path writes PF early enough for the playfield's first pixel.
    ; COLUPF was already chosen in VBLANK (gold or dark grey), so the whole
    ; bar has one colour and the blink never tears it.
    CPX #100
    BCC TitleNotPrompt
    CPX #104
    BCS TitleNotPrompt
    LDA #$AA                ; a dashed 4-pixel-chunk bar
    STA PF0
    STA PF1
    STA PF2
    LDA #0
    STA GRP0
    JMP TitleLineDone

TitleNotPrompt:
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    CPX #30
    BCC TitleNoEmblem
    CPX #42
    BCS TitleNoEmblem
    TXA
    SEC
    SBC #30
    TAY
    LDA EmblemGfx,Y
    STA GRP0
    JMP TitleLineDone
TitleNoEmblem:
    LDA #0
    STA GRP0

TitleLineDone:
    STA WSYNC
    INX
    CPX #SCREEN_LINES
    BNE TitleLoop
    JMP PictureEnd

; -----------------------------------------------------------------------------
; PlayScreen — status, open A, player, open B
; -----------------------------------------------------------------------------
PlayScreen:
    STA WSYNC               ; consume picture line 14 -> line 15
    ; --- status zone: play lines 0-4 --------------------------------
    ; The five lines are written out instead of looped so the playfield
    ; stores land early: PF0 at cycle ~10, PF1 at ~17, PF2 at ~24, each
    ; before its own deadline.  A loop with three comparisons pushed PF1
    ; past its deadline and tore the bar.
    LDY TimerIdx            ; line 0: the timer bar
    LDA TimerBarPF0,Y
    STA PF0
    LDA TimerBarPF1,Y
    STA PF1
    LDA TimerBarPF2,Y
    STA PF2
    LDA #0
    STA GRP0
    STA ENABL
    STA WSYNC

    LDY TimerIdx            ; line 1: the timer bar
    LDA TimerBarPF0,Y
    STA PF0
    LDA TimerBarPF1,Y
    STA PF1
    LDA TimerBarPF2,Y
    STA PF2
    STA WSYNC

    LDA #0                  ; line 2: blank the playfield
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA ENABL
    STA WSYNC

    LDY Lives               ; line 3: one chunk per life
    LDA LivesPF,Y
    STA PF0
    LDA #0
    STA PF1
    STA PF2
    STA GRP0
    STA ENABL
    STA WSYNC

    LDA #0                  ; line 4: blank the playfield
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA ENABL
    STA WSYNC

    ; --- open zone A: play lines 5-152 (148 lines) -------------------
    LDX #5
    LDA #0
    STA GRP0
PlayOpenALoop:
    LDA #0
    CPX ItemLine
    BCC PlayOpenANoItem
    TXA
    SEC
    SBC ItemLine
    CMP #ITEM_HEIGHT
    BCS PlayOpenAClear
    LDA #2
    JMP PlayOpenANoItem
PlayOpenAClear:
    LDA #0
PlayOpenANoItem:
    STA ENABL
    STA WSYNC
    INX
    CPX #PLAYER_LINE
    BNE PlayOpenALoop

    ; --- player zone: play lines 153-160 (8 lines) -------------------
    LDY #0
PlayPlayerLoop:
    LDA PlayerGfx,Y
    STA GRP0                ; the first store, before P0's pixel time
    LDA #0
    CPX ItemLine
    BCC PlayPlayerNoItem
    TXA
    SEC
    SBC ItemLine
    CMP #ITEM_HEIGHT
    BCS PlayPlayerClear
    LDA #2
    JMP PlayPlayerNoItem
PlayPlayerClear:
    LDA #0
PlayPlayerNoItem:
    STA ENABL
    STA WSYNC
    INX
    INY
    CPY #PLAYER_HEIGHT
    BNE PlayPlayerLoop

    ; --- open zone B: play lines 161-175 (15 lines) ------------------
    LDA #0
    STA GRP0
PlayOpenBLoop:
    LDA #0
    CPX ItemLine
    BCC PlayOpenBNoItem
    TXA
    SEC
    SBC ItemLine
    CMP #ITEM_HEIGHT
    BCS PlayOpenBClear
    LDA #2
    JMP PlayOpenBNoItem
PlayOpenBClear:
    LDA #0
PlayOpenBNoItem:
    STA ENABL
    STA WSYNC
    INX
    CPX #SCREEN_LINES
    BNE PlayOpenBLoop
    JMP PictureEnd

; -----------------------------------------------------------------------------
; OverScreen — the red field and a blinking bar prompt
; -----------------------------------------------------------------------------
OverScreen:
    LDX #0
    LDA #0
    STA GRP0
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC               ; consume picture line 14 -> line 15
OverLoop:
    CPX #100
    BCC OverNotPrompt
    CPX #104
    BCS OverNotPrompt
    LDA #$AA
    STA PF0
    STA PF1
    STA PF2
    JMP OverLineDone
OverNotPrompt:
    LDA #0
    STA PF0
    STA PF1
    STA PF2
OverLineDone:
    STA WSYNC
    INX
    CPX #SCREEN_LINES
    BNE OverLoop
    JMP PictureEnd

; =============================================================================
; GRAPHICS TABLES (replace these with your game's shapes)
; =============================================================================
; The ship is 8x8, top row first, because the play kernel indexes it with
; the picture line.  (The score font is bottom-up because its kernel counts
; rows down.)
PlayerGfx:
    !byte $18, $3C, $7E, $FF, $FF, $E7, $C3, $81
    ;     ..##....  .####...  ######..  ########
    ;     ########  ###..###  ##....##  #......#

; The title emblem is 8x12, drawn at play lines 30-41.  The dashed bar at
; play lines 100-103 is the "PRESS FIRE" prompt; it has no letters.
EmblemGfx:
    !byte $18, $18, $3C, $3C, $7E, $FF, $FF, $7E, $3C, $3C, $18, $18

; The timer bar is centered: n chunks on each side of the screen centre, for
; n = 0..20.  The lit left-half chunks run from (20-n) to 19; reflect mode
; draws their mirror on the right half.  PF0 bit 4 is the leftmost chunk,
; PF1 bit 7 follows it, and PF2 bit 0 is chunk 12.
TimerBarPF0:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $80, $C0, $E0, $F0
TimerBarPF1:
    !byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $03
    !byte $07, $0F, $1F, $3F, $7F, $FF, $FF, $FF, $FF, $FF
TimerBarPF2:
    !byte $00, $80, $C0, $E0, $F0, $F8, $FC, $FE, $FF, $FF, $FF
    !byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF

; The lives markers: 0..3 chunks lit from the left.  PF0 bit 4 is leftmost.
LivesPF:
    !byte $00, $10, $30, $70

; =============================================================================
; THE ITEM'S FALL SPEED (indexed by ItemDir)
; =============================================================================
; Normal items fall two pixels per frame; the demo's forced-miss items fall
; one, slowly, so the forced miss lands near the 180-frame design target.
; The slot at 0 is unused so ItemDir can be 1 or 2 directly.
FallSpeed:
    !byte 0, 2, 1

; =============================================================================
; THE SOUND TABLE (keep the table shape; change the two sounds)
; =============================================================================
; Each 8-byte record is AUDC, Rate, Steps|loop, Priority, FreqL/H, VolL/H.
; Sound 0 is the catch blip: a div-6 tone, four steps at four frames per step
; (16 frames).  Sound 1 is the miss buzz: white noise, five steps at eight
; frames per step (40 frames).
SoundTable:
    ; sound 0: the catch blip
    !byte $0C, 4, $04, 4
    !word CatchFreq, CatchVol
    ; sound 1: the miss buzz
    !byte $08, 8, $05, 6
    !word MissFreq, MissVol

CatchFreq:
    !byte 12, 8, 5, 3
CatchVol:
    !byte 15, 12, 8, 3
MissFreq:
    !byte 16, 22, 28, 31, 31
MissVol:
    !byte 12, 12, 10, 7, 0

; =============================================================================
; POSITIONING — the divide-by-15 routine from Lesson 26
; =============================================================================
; SetCoarseP0 is the visible-area player positioner.  The divide loop takes
; a variable number of cycles, so a fixed 60-cycle pad follows it.  The
; divide+pad is 88..138 cycles: it starts on the line after the WSYNC and
; ends 12..62 cycles into the second line.  The caller's HMP1/HMBL clear
; adds 8 cycles (20..70 into the second line) and its trailing WSYNC halts
; to the third line, where the HMOVE is strobed.  A = the target TIA X plus
; PLAYER_BIAS.
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
    ; A fixed 60-cycle pad keeps the routine's line count constant: the
    ; divide is 28..78 cycles, so 28+60 = 88 and 78+60 = 138.  The body
    ; starts on the line after the WSYNC and ends 12..62 cycles into the
    ; second line, never reaching the third.  The caller's clear adds 8
    ; cycles and its trailing WSYNC halts to the third line, where the
    ; HMOVE is strobed.
    +burn_line
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    RTS

; SetCoarseBL positions the ball in VBLANK.  It does not strobe HMOVE: the
; score's HMOVE applies the ball's fine offset together with P0 and P1.
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
; THE ROM VECTORS
; =============================================================================
    * = $FFFA
    !word Reset             ; NMI
    !word Reset             ; RESET
    !word Reset             ; IRQ
```

<!-- END-FULL-SOURCE -->

> The complete, fully-commented source lives in
> `lessons/part10-capstones/72-your-game/demo-72.asm`.

### Code Walkthrough

#### Step 1 — The frame and the two timers

The frame is the course's 262-line skeleton: 3 VSYNC lines, 37 VBLANK, 192 picture, 30 overscan. The two RIOT timers are 44 and 36 ticks:

```asm
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    INC Frame
```

`44` ticks are `1 + 43 x 64 = 2,753` cycles, a little over 36 lines; the timer plus `+wait_timer`'s final `WSYNC` produce the measured 37-line VBLANK. `36` ticks are `1 + 35 x 64 = 2,241` cycles, the measured 30-line overscan. The VBLANK work — fire, state update, sound, collision clear, ball position, score setup — fits inside those 2,753 cycles with room to spare; the timer is the floor, not a guess.

The picture side is the score library's nine lines, one blank, five positioner lines, and the 176-line play screen. `BodyStart` at 37/5 and `OverscanStart` at 229/2 are the two ends of the measured 192-line block.

#### Step 2 — The VBLANK order

The VBLANK order is a dependency graph, not a checklist. The fire edge and the state update come first because they can change `GameState` and `PlayerX`. The sound update comes after the triggers so a catch's first step is advanced in the same frame. The collision clear comes after `MoveItem` because the latch has just been read. The ball position and `ScoreSetup` come last because they need `ItemX` and they must finish before the picture turns on.

```asm
    JSR ReadFire
    LDA GameState
    CMP #0
    BNE VblankNotTitle
    JSR TitleUpdate
    JMP VblankStateDone
VblankNotTitle:
    CMP #1
    BNE VblankStateDone
    JSR PlayUpdate
VblankStateDone:
    JSR SoundUpdate
    LDA #0
    STA CXCLR
    LDA ItemX
    CLC
    ADC #BALL_BIAS
    JSR SetCoarseBL
    JSR ScoreSetup
    +wait_timer
    LDA #$00
    STA VBLANK
```

Two details matter. First, `ScoreSetup` ends with one `HMOVE` that applies P0, P1, and the ball in the same horizontal blank; the TIA forbids writes to `HMPx`/`HMBL` for at least 24 cycles after an `HMOVE`, so `HMP1`/`HMBL` are not touched here. They are zeroed much later, just before the visible positioner's second `HMOVE`. Second, `CXCLR` is written every frame, including the title and over states, so a stale latch cannot score a catch in a state that has no item.

#### Step 3 — The visible positioner

The score library draws six digits with P0 and P1 in three-copy close mode at X=56/64. After `ScoreDraw`, P0 is left at 56. The play area needs P0 at `PlayerX`, so the code divides `PlayerX + 3` by 15, sets `HMP0`, strobes `RESP0`, and applies one `HMOVE`:

```asm
    LDA PlayerX
    CLC
    ADC #PLAYER_BIAS
    JSR SetCoarseP0
    LDA #$00
    STA HMP1
    STA HMBL
    STA WSYNC               ; the second line -> the third line (HMOVE line)
    STA HMOVE               ; the third line's HBLANK
```

The divide loop is the Lesson 26 routine, but the length depends on `PlayerX`: 1 to 11 iterations of 5 cycles. A naive positioner would finish early for small X and late for large X, and the number of lines would change. The fix is a fixed 60-cycle pad after `RESP0`:

```asm
    STA HMP0
    STA RESP0
    +burn_line              ; 42 cycles
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP                     ; nine NOPs: 18 cycles
    RTS
```

The divide is 28-78 cycles, so the routine is 88-138 cycles: it starts on the line after its `WSYNC` and ends 12-62 cycles into the second line, never reaching the third. The caller's 8-cycle `HMP1`/`HMBL` clear extends the body to 20-70 cycles into the second line, and the trailing `WSYNC` halts to the third line, where the `HMOVE` is strobed. The trace is 229 for every `PlayerX`. The pad is the smallest prototype from the milestone plan, and it is the reason the frame is stable before the game logic exists.

#### Step 4 — The score band and the play zones

`BodyStart` calls `ScoreDraw`, which consumes exactly nine lines and returns at scanline 46. `ScoreDone` clears `NUSIZ0` and the playfield, sets P0's color, and consumes the blank line 9. The play area then dispatches on `GameState`:

```asm
PlayStart:
    LDA GameState
    CMP #0
    BNE PlayNotTitle
    JMP TitleScreen
PlayNotTitle:
    CMP #2
    BNE PlayIsPlay
    JMP OverScreen
PlayIsPlay:
    JMP PlayScreen
```

Each screen routine starts with a `STA WSYNC` that consumes picture line 14, then runs a 176-line loop. The play screen's five status lines are written out instead of looped: the timer bar needs its PF0 store at cycle ~10, and a loop with three comparisons pushed PF1 past its deadline and tore the bar. The open-A loop (148 lines) does one item check per line; the player loop (8 lines) stores `GRP0` first at cycle ~7 and the item's `ENABL` at ~20; the open-B loop (15 lines) clears `GRP0` and finishes the 176.

#### Step 5 — Input and the auto-demo

`ReadJoystick` reads `SWCHA` bits 4-7. Any direction resets `AutoTimer`, so the reader takes over immediately. Left is bit 6 and right is bit 7, both active low:

```asm
    LDA SWCHA
    AND #$40                ; left, active low
    BNE JoyTryRight
    LDA PlayerX
    SEC
    SBC #PLAYER_SPEED
    CMP #PLAYER_MIN
    BCS JoyStoreLeft
    LDA #PLAYER_MIN
JoyStoreLeft:
    STA PlayerX
```

The demo follows `ItemX` at one pixel per frame. It deliberately refuses to chase a forced-miss item (`ItemDir = 2`): that item spawns on the far side and falls slowly, so freezing the ship guarantees the miss. The result is deterministic without a recorded input tape.

#### Step 6 — The update: clock, item, catch, miss

`TickTimer` uses `Startup` as a 60-frame sub-second counter. When it reaches zero it reloads and decrements `Timer`; `Timer / 3` times two is the centered bar's half-width. `MoveItem` reads `CXP0FB` bit 6 first, because the latch describes the previous frame's pixels; a catch increments the score and respawns. Otherwise the item falls by `FallSpeed[ItemDir]` (2 for a normal item, 1 for the forced miss) and a top line past 180 is a miss:

```asm
    LDX ItemDir
    LDA FallSpeed,X
    CLC
    ADC ItemY
    STA ItemY
    SEC
    SBC #PLAY_TOP
    STA ItemLine
    CMP #(ITEM_MISS - PLAY_TOP + 1) ; 166: ItemY > 180
    BCC MoveItemDone
    JSR MissItem
```

`CatchItem` reports the score before the add (`Catch`) and after it (`ScoreWrite`), calls `ScoreAddOne` for the six-digit carry, triggers sound 0 on channel 0, and respawns. `MissItem` reports the new `Lives` (`Miss`), triggers sound 1 on channel 1, and either respawns or sets state 2.

#### Step 7 — The draw: title, play, over

The title screen uses P0 as an 8x12 emblem and three playfield bytes as a dashed "PRESS FIRE" bar. The prompt is always visible; `COLUPF` blinks between gold and dark grey on a 48/16-frame duty cycle. The published 2-second capture happens to be in the gold phase; the phase is frame-dependent and is not guaranteed for every run. The play screen's zones are the status lines, the open-A item lines, the player zone, and the open-B lines. The over screen paints the field red with `COLUBK`, keeps the final score in the band, and shows the same dashed prompt in white.

The timer bar is a centered playfield bar. `TimerIdx` is `2 * (Timer / 3)`, 0..20, the number of chunks on each side of the centre; the tables light the left half from chunk `20 - n` to 19, and reflect mode draws the mirror on the right half. At `Timer=30` the bar is the full width; at `Timer=0` it is empty.

#### Step 8 — The state machine, the restart, and the captures

`SetState` is the one place that changes `GameState` after reset (`Reset` writes 0 directly), so `StateChange` reports every transition with A = the new state. `StartPlay` is the only restart path: it sets state 1, clears the score, restores three lives and 30 seconds, recentres the ship, and spawns the first item. `ReadFire` is an edge detector: it stores the current `INPT4` bit 7 in `PrevFire`, starts play on the title, and restarts on the over screen; a press during play is ignored.

The auto-demo timer lives in `TitleUpdate`. It counts the 60-frame settle, then 120 frames of no fire. At 120 it calls `StartPlay` and sets `AutoTimer=120`, so the demo is active on the first play frame. The state log's `StateChange` at frame 180 and 645, the `ScoreWrite` at 252, and the three `Miss` values 2/1/0 are the evidence that the state machine, the score, and the restart path are the same machine the captures show.

## What You Should See

At power-on the screen is black. A gold diamond emblem sits in the upper middle (P0 at TIA X=76, visible lines 45-56), and a gold dashed bar blinks below it (playfield lines 115-118). The bar is the skeleton's "PRESS FIRE": the course has no text engine in this ROM, so the prompt is a pattern. The score band above the emblem is blank, not `000000`, because the title hides the score by leaving the score buffer in its zeroed state.

![The Star Catcher title screen: a gold emblem at centre, a gold dashed PRESS FIRE bar below it, and no score](/images/lesson72/title.png)

*The title at about 2 seconds. The emblem is P0 at X=76; the prompt is three playfield bytes. The score band is blank because the title has not called `ScoreClear`.*

Press fire and the title yields to the play screen. The score band now reads `000000` in white six-digit digits. Below it, a two-line gold timer bar spans the width; below that, three gold life chunks sit at each edge. The gold ship is at the bottom (P0 at Y=168), and a 4x4 gold star falls from Y=24. When the star reaches the ship, the score increments and the catch blip plays; when it passes Y=180, a life disappears and the miss buzz plays. The timer bar loses two chunks on each side every three seconds. After three misses (or 30 seconds) the field turns red and the final score stays in the band; fire restarts.

![The Star Catcher play screen: the score 000001, the timer bar, the lives, the ship, and a falling star](/images/lesson72/play.png)

*The play state at about 6 seconds. The score is 000001; the timer bar is near full; the ship is at TIA X≈128 and the star is falling at the left. The auto-demo has caught the first star and is letting a forced-miss star fall.*

<RomPlayer rom="/roms/part10-capstones/72-your-game/demo-72.bin" title="Lesson 72 — Capstone 4: Your Own Game" />

*Javatari starts muted; unmute it to hear the catch blip and the miss buzz.*

The debugger tells the same story. Assemble with a symbol list and break at the labelled checkpoints:

```bash
acme -f plain -l build/demo-72.sym -o build/demo-72.bin \
  lessons/part10-capstones/72-your-game/demo-72.asm
grep -E "StartFrame|VblankStart|BodyStart|OverscanStart|StateChange|ScoreWrite|ItemSpawn|Catch|Miss" build/demo-72.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F2AE' docs/public/roms/part10-capstones/72-your-game/demo-72.bin
```

The measured checkpoints:

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F2AE` | 259, cycle 3 | The first VSYNC line |
| `VblankStart` | `$F2BC` | 0, cycle 5 | The first VBLANK line |
| `BodyStart` | `$F350` | 37, cycle 5 | The first picture line (the score band) |
| `ScoreDone` | `$F353` | 46, cycle 5 | The blank line after the score |
| `PlayStart` | `$F395` | 51, cycle 2 | The play-area dispatch line |
| `OverscanStart` | `$F3D0` | 229, cycle 2 | The first overscan line |
| `StateChange` | `$F3E3` | A=the new state | Every `GameState` change |
| `ScoreWrite` | `$F519` | A=the new score | The score after a catch |
| `ItemSpawn` | `$F56F` | A=the new `ItemX` | Every respawn |
| `Catch` | `$F515` | A=the score before the catch | The collision catch |
| `Miss` | `$F52B` | A=the new `Lives` | A missed star |

The state log from the committed ROM:

| Event | Frame | Log line | Reading |
| --- | ---: | --- | --- |
| `StateChange` | 180 | `BP: 180 2 06 -50 \| ... 01 ...` | A=1: title -> play (the auto-demo) |
| ScoreWrite | 252 | `BP: 252 3 14 -26 \| ... 01 ...` | A=1: the first catch |
| Catch | 252 | `BP: 252 3 06 -50 \| ... 00 ...` | A=0: the score before the catch |
| ItemSpawn | 180 | `BP: 180 23 49 79 \| ... 80 ...` | X=128: the first star |
| ItemSpawn | 252 | `BP: 252 10 48 76 \| ... 08 ...` | X=8: the forced-miss star |
| ItemSpawn | 409 | `BP: 409 6 60 112 \| ... 18 ...` | X=24: the next normal star |
| ItemSpawn | 488 | `BP: 488 7 45 67 \| ... 94 ...` | X=148: the next forced-miss star |
| Miss | 409 | `BP: 409 3 11 -35 \| ... 02 ...` | A=2: one life gone |
| Miss | 488 | `BP: 488 3 60 112 \| ... 01 ...` | A=1: two lives gone |
| Miss | 645 | `BP: 645 3 11 -35 \| ... 00 ...` | A=0: the last life gone |
| `StateChange` | 645 | `BP: 645 6 25 7 \| ... 02 ...` | A=2: play -> over |

The state sequence is 0 (power-on) -> 1 at frame 180 -> 2 at frame 645. The score reaches 1 at frame 252; the three misses at 409, 488, and 645 are the three lives. The item spawns are the deterministic sequence 128, 8, 24, 148: normal, forced, normal, forced.

The **pixel check** of the two images:

| Image | Size | Title bar | What the pixels show |
|---|---|---|---|
| `title.png` | 1010×807 | `Stella 7.0: "demo-72"` | TIA area 960×606 at (25,106); black field; the gold emblem at x=481-528, y=249-285 (48×37 px, 936 gold pixels); the gold dashed prompt at x=49-960, y=470-480 (912×11 px, 5,280 gold pixels); no white pixels in the TIA area (the score is hidden); no cursor |
| `play.png` | 1010×807 | `Stella 7.0: "demo-72"` | the white score at x=367-642, y=110-130 (2,832 white pixels, reading 000001); the gold timer bar at x=73-936, y=154-158 (864×5 px, two lines); the gold lives at x=25-984, y=164-165 (two 72-px groups at the edges); the gold star at x=73-96, y=432-443 (24×12 px = 4×4 TIA px); the gold ship at x=793-840, y=637-660 (48×24 px = 8×8 TIA px); no cursor |

The two TIA-area MD5 hashes differ (`cf9d35474eeaa0fe0a14e00382c70226` for the title, `0f2d03ad848700776bd7112f220cd72a` for the play state), so the captures are genuinely different states, not two copies of one frame. Both are 1010×807, carry the window frame and the `Stella 7.0: "demo-72"` title bar, and show no cursor: the pointer was parked at (0,0) before each capture.

The **late-game timer-bar check** covers the table at low `n`. The three-life demo reaches the over state at frame 645 (about 10.75 s), so a 20-second *play* capture is not possible with the spec's three lives; the bar was checked with two diagnostic builds that start the clock at `Timer=10` (n=6) and `Timer=3` (n=2). These are diagnostic captures, not the two published lesson screenshots (their window titles read `late6` and `late2`). At n=6 the bar is one contiguous run from x=361-648 (288 gold pixels, 48 TIA px); at n=2 it is x=457-552 (96 gold pixels, 16 TIA px). A host-side simulation of all n=0..20 confirms that the lit left-half chunks are always the contiguous run `20-n..19`; the old 21-entry PF1 table produced a two-chunk hole at n=6 and a six-chunk hole at n=2, and is gone.


> **Capture method.** The two images are `scripts/capture-screenshot.sh` captures of the
> committed `docs/public/roms/part10-capstones/72-your-game/demo-72.bin` on display `:0`
> (the mutter window manager supplies the title bar) at two and six wall-clock seconds, with
> `xdotool mousemove 0 0` before each. The emulator's start-up takes the first fraction of a
> second, so the 2-second image is about ROM frame 100-120 (title) and the 6-second image is
> about frame 350-380 (play). The auto-demo makes the states deterministic: the title auto-start
> is frame 180, the first catch is frame 252, and the over state is frame 645. The prompt is a
> bar, not text; the title's gold phase is 48 of every 64 frames. The published capture is in
> the gold phase, but the phase is frame-dependent, so a different run can show the dark-grey phase.

## Exercises

The three exercises are **design tasks**, not coding tasks. They are answered here because the lesson's deliverable is the method, and the method is best shown by doing it. There are no `exercise-72-solution.asm` files: the reader's game is the solution.

### Exercise 1: Write your one-page GDD

**Challenge:** Take your game idea and fill in the twelve-field GDD template from Section 2. Keep it to one page. Name the core loop in one sentence and the win/lose state explicitly.

**Hints:**
1. If the concept needs more than one sentence, the scope is too large for a first 4K game.
2. The core loop must include the feedback at each step: what sound, what score, what screen change.
3. A game with no lose state has no tension; a game with no win state has no finish. Choose both, even if the win is a target score.

**Expected Result:** A one-page GDD that a second person could implement without asking what the game is. The core loop has a feedback step, the controls name the input bits, and the win/lose states are explicit.

**Answer.** Here is a compact second example, deliberately smaller than Star Catcher, to show the level of detail:

| Field | **Dodge** |
| --- | --- |
| Title | Dodge |
| Concept | A 4-pixel ship crosses a 160-pixel corridor while 4-pixel meteors fall; survive 30 seconds. |
| Core loop | A meteor spawns at Y=24 at a random X; the ship moves left/right; a contact costs a life and a buzz; a dodge scores one and a blip; repeat until the clock or the lives end. |
| Controls | Left joystick left/right, 2 pixels per frame, clamp 8..152; fire starts and restarts. |
| Screen map | 9 score + 1 blank + 5 positioner + 5 status + 171 play + 1 blank = 192; the play area is 5 status + 171 play = 176. |
| Objects | Ship (P0, 8×8), meteor (ball, 4×4), score (six digits), timer bar (PF, 2 lines), lives (PF, 1 line). |
| States | 0 title, 1 play, 2 over; fire starts/restarts; the score persists into the over screen. |
| Win/lose | Lose when lives=0 or the clock=0; win at 20 dodges (the target score is the win). |
| Score | +1 per dodged meteor, six digits, `000000` start. |
| Audio | Dodge blip on channel 0; hit buzz on channel 1. |
| Milestones | M1 frame + input; M2 falling meteor + collision; M3 score + sound + states; M4 captures + budget. |
| Risks | The RAM map (the score and sound libraries own `$A0-$D7` and `$88-$9F`); the collision lag; the play-area line count. |

The point of the example is the **screen-map arithmetic**: the first draft said 178 play lines, which would make 9 + 1 + 5 + 5 + 178 = 198, not 192. The worksheet catches the error before a line of code. The corrected map has 171 play lines after the five status lines, for 176 play-area lines in total.

### Exercise 2: Draw the RAM and screen maps

**Challenge:** Draw the 128-byte RAM grid and the 192-line screen grid for your game. Name every variable, mark every library-owned byte, and check the 4K budget.

**Hints:**
1. Start with the libraries: `$A0-$D7` (score) and `$88-$8D`/`$90-$9F` (sound). The remaining bytes are the only ones you can use.
2. Put the hot variables first; the 6502 has no cache, but the map is easier to read when the frame variables are together.
3. Count the screen bands before the kernel: score (9), blank (1), positioner (5), play (176), blank (1).
4. Measure the 4K budget from the symbol file, not from a guess.

**Expected Result:** A grid with no unnamed byte in the used range, a screen map that sums to 192, and a budget table that sums to 4,096 (including the padding).

**Answer.** For Star Catcher, the RAM grid is Section 3 and the screen grid is Section 4. The key answers are:

- The game variables are `$80-$87`, `$8E-$8F`, and `$D8-$DC`: eight frame/state bytes, two input/demo bytes, and five clock/spawn bytes.
- The score library owns `$A0-$D7`; the sound library owns `$88-$8D` and `$90-$9F`. The free bytes are `$DD-$F7`; the stack is `$F8-$FF`.
- The screen is 9 + 1 + 5 + 5 + 148 + 8 + 15 + 1 = 192. The play area is 5 + 148 + 8 + 15 = 176.
- The 4K budget is 325 (score) + 242 (sound) + 530 (keep) + 112 (input) + 191 (update) + 339 (draw) + 90 (graphics) + 34 (sound table) + 66 (positioners) + 6 (vectors) + 2,161 (padding) = 4,096.

For **Dodge**, the same method gives a smaller map: `$80` state, `$81` ship X, `$82` meteor X, `$83` meteor Y, `$84` score, `$85` lives, `$86` timer, `$87` frame, `$8E` prev fire, `$8F` auto timer, `$D8` startup, `$D9` meteor speed, `$DA` spawn counter, `$DB` meteor line, `$DC` timer index. The screen is 9 + 1 + 5 + 5 + 171 + 1 = 192; the play area is 176 lines, with the ship at the bottom of the same open loop. The budget is smaller because Dodge has no title emblem and no separate player zone. The exact numbers depend on the drawing; the method is the same.

### Exercise 3: Write the milestone plan

**Challenge:** Write four milestones, each with a test that can fail. Name the riskiest mechanic and the smallest prototype that proves it first.

**Hints:**
1. A milestone is a running state, not a list of files.
2. The first milestone should test the frame and the input, because every later milestone inherits them.
3. The riskiest mechanic is the one that can invalidate the screen map, the RAM map, or the frame; prototype it before the content.
4. A test is a measurement: a breakpoint, a pixel count, a state log, or an assembly size.

**Expected Result:** Four milestones with a measurement each, a named risk, and a prototype small enough to build in an hour.

**Answer.** For Star Catcher:

| Milestone | Test | Why it is this early |
| --- | --- | --- |
| M1 Frame + input | `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229; fire starts the title | The frame is the base every later state inherits; a broken positioner changes the line count for every screen. |
| M2 Core loop + score | `Catch` A=0, `ScoreWrite` A=1, `Miss` A=2/1/0, `ItemSpawn` values; the screen shows `000001` | The loop is the game; a collision lag or a score carry bug is cheaper to find with one star than with a full screen. |
| M3 Audio + states | `StateChange` A=1 at 180 and A=2 at 645; the catch blip and miss buzz; fire restarts | The state machine and the sound table are integration points; they can be tested once the loop exists. |
| M4 Polish + captures | 4,096 bytes; `npm run roms` 265; two 1010×807 images with the title bar and no cursor; `scripts/verify.sh` passes | The captures are evidence, not decoration; they are the last test because they use the final ROM. |

The riskiest mechanic is the **frame plus the visible positioner**. It is the one place where a correct-looking routine can change the number of lines and roll the picture. The smallest prototype is the frame with the score band, the positioner, and a breakpoint at `OverscanStart`: no star, no score, no sound. If the breakpoint is 229 for `PlayerX` = 8, 76, and 152, the riskiest part is proven. The second risk is the RAM map; its prototype is the worksheet itself, because the map is the design. The third risk is the collision lag; its prototype is one star and a fixed ship, with the `Catch`/`ScoreWrite` pair in the log.

## Key Takeaways

- ✅ A 4K game is a **scoped design** first: one-sentence concept, one-page GDD, one core loop, and a named win/lose state.
- ✅ The **RAM map is a contract**: the score library owns `$A0-$D7`, the sound library owns `$88-$8D` and `$90-$9F`, and no data may live under the stack's reach.
- ✅ The **screen map is a line budget**: 9 score + 1 blank + 5 positioner + 176 play + 1 blank = 192, and every kernel line fits 76 cycles.
- ✅ The **4K budget is measured, not guessed**: 1,935 bytes used (1,929 code/data + 6 vectors) and 2,161 bytes of headroom in Star Catcher.
- ✅ **Milestones are tested states**: frame and input first, core loop and score second, audio and states third, captures last.
- ✅ The skeleton's **three sections are the seam**: replace INPUT, UPDATE, and DRAW; keep the frame, the score and sound calls, the state/restart helpers, and the auto-demo.
- ✅ **Captures are part of the design**: a deterministic auto-demo makes the 2-second title, the 6-second play state, and the state log reproducible.

## What's Next

You have a complete game, a design method, and a ROM that fits. Part 11 is the anthology of the tricks that made the commercial 2600 games famous: the HMOVE comb and the Cosmic Ark starfield, skipdraw, the pseudo-3D road, procedural worlds from an LFSR seed, interlaced flicker, and the Adventure room engine. The method you practiced here is how those techniques become your game rather than a demo: [Part 11: Legendary Techniques](/part11-legendary/).
