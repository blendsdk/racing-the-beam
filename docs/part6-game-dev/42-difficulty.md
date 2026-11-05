---
title: "Lesson 42: Difficulty and Progression — The Difficulty Ladder"
description: "Two console switches, one 15-entry speed table, and a 300-frame survival clock: Lesson 42 builds the difficulty ladder — a switch-selected starting level, a level bar, three life cells per half, a two-cell switch indicator per half, a bouncing enemy that gets faster, 60 frames of invulnerability, and a red game-over field that fire restarts."
prev:
  text: "Lesson 41: Game States — Title, Play, Game Over"
  link: "/part6-game-dev/41-game-states"
next:
  text: "Lesson 43: Random Numbers — Unpredictable Fun"
  link: "/part6-game-dev/43-random-numbers"
---

# Lesson 42: Difficulty and Progression — The Difficulty Ladder

> **Part 6: Game Development** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 06 (flags and comparisons), Lesson 11 (lookup tables), Lesson 27 (joystick input), Lesson 34 (frame counters), Lesson 38 (collision latches), Lesson 41 (game states and the restart flow)
> **You will learn:** how `SWCHB` reports the two difficulty switches; how a switch chooses the starting level; how a 15-entry table turns a level number into pixels per frame; how a 16-bit 300-frame timer climbs the ladder; how `CXPPMM` bit 7 costs a life; how respawn, invulnerability, and the red game-over field fit together; how four status zones and a play area share 192 lines
> **You will build:** "the difficulty ladder" — a switch-selected starting level, a gold level bar, three red life cells per half, a two-cell switch indicator per half, a bouncing green enemy whose speed follows the level, a 300-frame timer that raises the level to 15, a P0–P1 collision with 60 frames of invulnerability, a red frozen game-over field, and fire restart; plus three exercises: invert the left switch, three copies, and an expert level cap

## Introduction

Lesson 41 gave the game a structure: a title, a play screen, and an over screen, all selected by
one state byte. It still had no **pace**. Every game ran at the same speed, the enemy never
changed, and the console's two difficulty switches did nothing. A player who mastered the first
few seconds had mastered the whole game.

Difficulty is not one switch. It is a **ladder**: a starting rung chosen before the first frame, a
speed that rises as the player survives, a cap that stops the climb, and a life system that gives
the player three chances to climb it. On the Atari 2600 the ladder is built from small parts —
two bits of `SWCHB`, a 15-byte table, a 16-bit frame counter, and the `CXPPMM` collision latch.
There is no difficulty curve object and no timer interrupt; every part is a byte you can watch in
the debugger.

This lesson builds **the difficulty ladder**. The left difficulty switch picks the starting level:
level 1 on novice, level 5 on expert. The right switch picks the enemy's width: one 8-pixel copy
on novice, a 16-pixel double-width copy on expert. The level bar at the top shows the current
level; three red cells per half show the remaining lives; two white cells per half show the switch positions. Every
300 survived frames the level rises by one, the bar flashes, and a beep plays. The enemy bounces
faster as the level rises, and a collision costs a life and buys 60 frames of invulnerability. At
zero lives the field turns red, the play update freezes, and fire starts again. The companion
program `42-difficulty.asm` is the complete ROM; the exercises invert the left switch, build a
three-copy enemy, and cap the expert ladder at level 10.

::: details TypeScript Equivalent
The ladder is a class with two switch-derived settings, a table lookup, and a countdown. The shape
transfers; the constraints do not:

```typescript
type Switches = { leftExpert: boolean; rightExpert: boolean };

const SPEED_TABLE = [1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 4];

class DifficultyLadder {
  level = 1;
  levelTimer = 300;      // frames, not seconds
  lives = 3;
  invulnerable = 0;
  gameOver = false;
  enemyX = 24;
  enemyDir = 1;
  nusiz1 = 0;

  start(switches: Switches): void {
    this.level = switches.leftExpert ? 5 : 1;
    this.levelTimer = 300;
    this.lives = 3;
    this.invulnerable = 0;
    this.gameOver = false;
    this.enemyX = 24;
    this.enemyDir = 1;
  }

  applySwitches(switches: Switches): void {
    this.nusiz1 = switches.rightExpert ? 5 : 0;   // 5 = double width
  }

  update(switches: Switches, contact: boolean): void {
    this.applySwitches(switches);                  // the width follows the right switch
    if (this.gameOver) return;
    if (this.invulnerable > 0) this.invulnerable -= 1;

    if (contact && this.invulnerable === 0) {
      this.lives -= 1;
      this.respawnEnemy();
      this.invulnerable = 60;
      if (this.lives === 0) this.gameOver = true;
    }

    this.enemyX += SPEED_TABLE[this.level - 1] * (this.enemyDir ? 1 : -1);
    if (this.enemyX < 24)  { this.enemyX = 24;  this.enemyDir = 1; }
    if (this.enemyX > 136) { this.enemyX = 136; this.enemyDir = 0; }

    if (this.levelTimer === 0) {
      // the asm checks before decrementing: this is play frame 301
      const next = Math.min(15, this.level + 1);
      if (next !== this.level) { this.level = next; beep(); }
      this.levelTimer = 300;
    } else {
      this.levelTimer -= 1;
    }
  }

  private respawnEnemy(): void {
    if (this.enemyX < 80) { this.enemyX = 136; this.enemyDir = 0; }
    else                  { this.enemyX = 24;  this.enemyDir = 1; }
  }
}
```

The analogy breaks in four places. The `levelTimer` is a 16-bit counter split across two RAM
bytes; 300 does not fit in one byte, and the 6502 has no `int` type. The switch is not an object
property: it is two bits of a hardware port read in VBLANK, and the A position reports 1 while B
reports 0. The contact is not a boolean from a physics engine; it is the TIA's `CXPPMM` latch,
read one frame late and cleared with `CXCLR`. And there is no `render`: the level bar, life cells,
switch indicator, walls, and both players are a scanline plan, 192 lines long, rebuilt every frame.
:::

## Theory

### Section 1: Two Switches, One Byte

The Atari 2600 has two difficulty switches on the console, labelled **A** and **B**. Most games
use A as the harder setting and B as the easier one. The switches are not joystick buttons and
they are not read through `INPT4`; they are two bits of the RIOT's port B, at `SWCHB` (`$0282`):

| Bit | Switch | 0 | 1 |
|---|---|---|---|
| 6 | left difficulty (player 0) | B / novice | A / expert |
| 7 | right difficulty (player 1) | B / novice | A / expert |

Two details matter more than the table. First, the switch is a **level**, not an edge: the program
reads the current position every frame, so flipping it mid-game is visible immediately (the enemy
width changes on the next frame; the starting level is sampled only when a game starts). Second,
the A position reports **1**. The console, Stella's `Switches` implementation, the
[Nocash hardware reference](https://problemkaputt.de/2k6specs.htm), and `include/vcs.asm` all
agree: 0 is B/novice, 1 is A/expert. Older register tables — including this course's pre-fix
comment — had the polarity inverted; the switch label and the observed byte are the ground truth.
In this ROM, `-ld A` gives `SWCHB` bit 6 = 1, and `-ld B` gives bit 6 = 0.

The program stores the byte in `Switches` and derives three displays/behaviours from it:

- **Start level:** left switch bit 6. 0 (B) → level 1; 1 (A) → level 5. Sampled in `StartGame`.
- **Enemy width:** right switch bit 7. 0 (B) → `NUSIZ1=$00` (one 8-pixel copy); 1 (A) →
  `NUSIZ1=$05` (double width, 16 pixels). Sampled every VBLANK.
- **Indicator:** two white 1-chunk cells per half at the top. The left cell is lit when bit 6 =
  1; the right cell is lit when bit 7 = 1.

The read comes before every later decision in the frame, so the switch byte the display uses and
the switch byte the gameplay uses are the same byte. The checkpoint `ReadSWCHB` sits immediately
after `LDA SWCHB`, and `A` is the raw byte: `$3F` with both switches on B, `$FF` with both on A,
`$7F` with only the left on A, and `$BF` with only the right on A. In `$3F` (`0011 1111`) bit 0
(RESET) and bit 1 (SELECT) are 1 because both buttons are released, bit 3 is 1 in colour mode,
bits 2, 4, and 5 are unused and read 1, and bits 6–7 are the two difficulty switches (both 0 =
B/novice).

::: warning Switch polarity
Older register tables — including this course's pre-fix comment — had the polarity inverted. The
console, Stella, and `include/vcs.asm` now agree: 0 = B/novice, 1 = A/expert, and `-ld A`
produces `SWCHB` bit 6 = 1. If a register table and a switch disagree, trust the switch and the
byte the debugger shows.
:::

::: tip Why the indicator is two cells, not four
A line can have only one playfield colour. The two switches can be in different positions, so a
four-cell "both states" display would need two colours on the same line. The ROM sidesteps that
by making each cell **lit only for expert**: one white cell per switch, dark for novice. The
left/right position names the switch; lit/dark names its state. A single `COLUPF` value draws
both cells.
:::

### Section 2: A Starting Level from a Switch

The starting level is not read every frame. It is sampled once, in `StartGame`, so the ladder
cannot jump under the player when the switch is nudged mid-game:

```asm
StartGame:
    LDA Switches
    AND #$40                ; the left switch
    BEQ StartNovice
    LDA #START_EXPERT       ; A (bit 6 = 1): level 5
    BNE StartLevelStore
StartNovice:
    LDA #START_NOVICE       ; B (bit 6 = 0): level 1
StartLevelStore:
    STA StartLevel
StartLevelSet:              ; checkpoint: A = the switch-selected start level
    STA Level
```

`StartLevel` is kept for the debugger and for the lesson's explanation; the game reads `Level`.
The same routine resets the lives, the 300-frame timer, P0's column, the enemy's position and
direction, the invulnerability window, and the game-over flag. It runs from two places: the first
VBLANK (`NeedStart`) and the fire edge on the game-over screen. That means a restart uses the
switch too: on the default novice switches, fire restarts at level 1; with the left switch on A,
it restarts at level 5. The default novice switches exercise one side of the branch, and the
expert path is the same code with a different bit.

The exercise 1 solution swaps the two branches. Expert (bit 6 = 1) starts at level 1 and novice
(bit 6 = 0) starts at level 5. The indicator does not change: it still lights when the switch is
on A. That is the point of the exercise — the switch's **meaning** is a design choice, and the
program can invert it without touching the hardware read.

### Section 3: A Speed Table Indexed by Level

The enemy's speed is a lookup, not a formula. Fifteen bytes cover levels 1–15:

```asm
SpeedTable:
    !byte 1,1,1,2,2,2,3,3,3,3,4,4,4,4,4
```

| Levels | Pixels per frame |
|---|---|
| 1–3 | 1 |
| 4–6 | 2 |
| 7–10 | 3 |
| 11–15 | 4 |

The index is `Level - 1`, because the table is zero-based and the level starts at 1:

```asm
    LDX Level
    DEX                     ; level 1 -> table entry 0
    LDA SpeedTable,X
    STA Speed
SpeedWrite:                 ; checkpoint: A = SpeedTable[Level]
```

`SpeedWrite` reports the byte the movement routine will use. At level 1 it is 1; at level 5 it is
2; at level 10 it is 3; at level 15 it is 4. The two captures compare level 1 and level 5, so the
visible difference is one pixel per frame versus two. The table is deliberately gentle at the
bottom: the first three levels feel identical, then the speed steps up. A game that changed speed
every level would be exhausting to tune and would make the bar's meaning harder to read.

The enemy width is separate from the speed and comes from the right switch:

```asm
    LDA Switches
    AND #$80
    BEQ EnemyWidthNovice
    LDA #$05                ; expert: double width
    BNE EnemyWidthStore
EnemyWidthNovice:
    LDA #$00                ; novice: one 8-px enemy
EnemyWidthStore:
    STA NUSIZ1
NUSIZWrite:                 ; checkpoint: A = NUSIZ1
```

`NUSIZ1=0` draws one 8-pixel copy. `NUSIZ1=5` draws one 16-pixel copy (the TIA doubles the
player's width). The write happens every VBLANK, so flipping the right switch changes the enemy
on the next frame. The checkpoint reports `A=0` on novice and `A=5` on expert.

Exercise 2 replaces the expert value with `NUSIZ1=3`, which draws three 8-pixel copies at X, X+16,
and X+32. That is a wider enemy in a different sense: three targets instead of one. The exercise
also lowers the movement cap from 136 to 104 so the last copy ends at X=143, just inside the
right wall at X=144.

### Section 4: The Survival Clock

Three hundred frames is five seconds at 60 Hz, and it does not fit in one byte. The timer is two
bytes, `LevelTimerLo` and `LevelTimerHi`, holding `$012C` (300) at the start of a game:

```asm
    LDA #LEVEL_FRAMES_LO    ; $2C
    STA LevelTimerLo
    LDA #LEVEL_FRAMES_HI    ; $01
    STA LevelTimerHi
```

Every play frame decrements the pair. The low byte is decremented first; when it is already zero,
the high byte is decremented and the low byte is reloaded with `$FF`. When both bytes are zero,
the level-up path runs: the level rises unless it is already capped, and the pair is reloaded with
300 either way:

```asm
    LDA LevelTimerLo
    BNE LevelDecLo
    LDA LevelTimerHi
    BEQ LevelUpNow
    DEC LevelTimerHi
    LDA #$FF
    STA LevelTimerLo
    JMP LevelTickDone
LevelDecLo:
    DEC LevelTimerLo
    JMP LevelTickDone
LevelUpNow:
    LDA Level
    CMP #LEVEL_MAX
    BCS LevelCapNow
    CLC
    ADC #1
    CMP #LEVEL_MAX
    BCC LevelUpStore
LevelCapNow:
    LDA #LEVEL_MAX
LevelUpStore:
LevelUp:                    ; checkpoint: A = the new level (capped at 15)
    CMP Level
    BEQ LevelAtCap          ; no change: reload the clock, skip the reward
    STA Level
    LDA #FLASH_FRAMES
    STA FlashTimer
    LDA #LEVEL_PITCH
    STA BeepPitch
    JSR BeepStart
LevelAtCap:
    LDA #LEVEL_FRAMES_LO
    STA LevelTimerLo
    LDA #LEVEL_FRAMES_HI
    STA LevelTimerHi
```

The cap is checked twice. The first `CMP` catches a level already at 15; the second catches the
increment that would reach 16. Both paths land on `A=15`, so `Level` can never exceed the bar's
15 chunks. The measured passive run reaches `LevelUp` at frame 301 (the timer starts at frame 1),
with `A=2`. The next level-up would be at frame 601; the passive run loses its last life at frame
374, so it never gets there.

The cap still reloads the timer when it is reached, but the reward is skipped: no flash and no
beep when the new level equals the old one. That keeps the clock from re-triggering every frame
without pretending the ladder moved.

A level-up that actually changes the level starts the beep and a 30-frame flash. `FlashTimer` is
decremented every play frame; while it is nonzero, the level bar is blanked for four frames and
drawn for four, using `Frame` bit 2. The display build does the gating:

```asm
    LDA FlashTimer
    BEQ LoadLevelBar
    LDA Frame
    AND #$04                ; 4 frames off, 4 frames on while flashing
    BNE LoadLevelBar
    LDA #$00
    STA LevelPF0
    STA LevelPF1
    STA LevelPF2
    JMP LevelBarDone
LoadLevelBar:
    LDA Level
    ASL                     ; Level * 3: three playfield bytes per entry
    CLC
    ADC Level
    TAX
    LDA LevelBarPF,X
    STA LevelPF0
    LDA LevelBarPF+1,X
    STA LevelPF1
    LDA LevelBarPF+2,X
    STA LevelPF2
LevelBarDone:
```

The three bytes are a table indexed by `Level × 3`; the table is the same 16-entry pattern used
for the hit bar in Lesson 41. Entry 1 is `$10,$00,$00` (one chunk, X=0–3); entry 5 is
`$F0,$80,$00` (five chunks, X=0–19); entry 15 is `$F0,$FF,$07` (all 15 chunks). `CTRLPF=$01`
mirrors the same pattern from the right edge, so every count is "per half."

### Section 5: Lives, Respawn, and Invulnerability

P0 and P1 are both drawn on visible lines 140–155. That is not a cosmetic choice: the TIA's
collision latch only sets when two objects' drawn pixels share a scanline, so a collision between
players at different heights is impossible. Both are 16 rows tall and share the same 16 scanlines.

The collision read is the Lesson 38 pattern, with one difference: the lesson only needs P0–P1, so
it masks `CXPPMM` bit 7:

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
CXClear:                    ; checkpoint: the latches are cleared
```

The read is in VBLANK, so it describes the **previous** visible frame. The latch is sticky until
`CXCLR`; the edge test (`current AND NOT previous`) turns a contact that lasts several frames into
one event. At the measured run the drawn contact is on frame 49, the VBLANK read on frame 50
reports `A=$87` (bit 7 set; the low bits are not defined), and the life is charged on that frame.

A contact with no invulnerability left charges one life:

```asm
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
    BNE NoCollision
    LDA #1
    STA GameOver            ; the next frame draws the red field
    LDA #0
    STA Invuln              ; stop the enemy blink on the frozen field
    STA FlashTimer          ; stop the level-bar flash on the frozen field
NoCollision:
```

`LifeStep` reports `A=2`, then `A=1`, then `A=0` in the passive run, at frames 50, 212, and 374.
The frames are 162 apart: the respawn at the far wall, the pass through P0 under invulnerability,
the turn at the opposite wall, and the trip back to P0's edge.

`RespawnEnemy` puts P1 on the side away from P0 and points it back toward the player:

```asm
RespawnEnemy:
    LDA EnemyX
    CMP PlayerX
    BCC RespawnRight
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir
    RTS
RespawnRight:
    LDA #ENEMY_MAX_X
    STA EnemyX
    LDA #0
    STA EnemyDir
    RTS
```

If the contact happened to P0's left, P1 respawns at the right wall and moves left; if it happened
to P0's right, P1 respawns at the left wall and moves right. The trip back is the player's breathing
room. During the 60 frames of invulnerability P1 blinks: the display build sets `EnemyDraw` to
`$FF` normally and to `$00` for the four-frame phase in which `Frame` bit 2 is 0 while `Invuln` is
nonzero. A hidden P1 draws no pixels, so it cannot set the collision latch during the blink's off
phase either.

At zero lives `GameOver` is set, and the hit handler also clears `Invuln` and `FlashTimer`, so the
frozen field has no enemy blink and no level-bar flash. The play update is skipped from the next
frame onward: the enemy stops, the timer stops, the player stops, and the collision latch is still
read and cleared but its bits are ignored. The VBLANK colour setup sets `COLUBK` to red (`$42`)
when `GameOver=1`, so the whole field turns red while the level bar and switch indicator stay
visible; the frozen sprites keep their last positions, though the red player blends into the red
field. Fire then calls `StartGame`, which clears `GameOver`, resets the lives and timer, and starts
at the switch-selected level.

### Section 6: The Layout and the 262-Line Frame

The frame is the same 262 lines as every lesson in this part: 3 VSYNC + 37 VBLANK + 192 visible +
30 overscan. The 192 visible lines are four status zones and the play area:

| Visible lines | Count | What |
|---|---|---|
| 0–7 | 8 | the level bar: `Level` gold chunks per half |
| 8–15 | 8 | the life cells: three 2-chunk red cells per half at X=8, 16, 24 |
| 16–23 | 8 | the switch indicator: two white 1-chunk cells per half at X=8 and X=24 |
| 24–139 | 116 | the play area's top section: gold walls, no sprites |
| 140–155 | 16 | P0 and P1, both 16 rows, red and green |
| 156–191 | 36 | the play area's bottom section: gold walls, no sprites |

The total is 8 + 8 + 8 + 116 + 16 + 36 = 192. `BodyStart` is scanline 37; `OverscanStart` is
scanline 229.

The playfield is mirrored (`CTRLPF=$01`). `PF0=$F0` lights chunks 0–3 in the left half (X=0–15)
and the mirror puts the same 16-pixel wall at X=144–159. The play area is therefore X=16–143, and
P0/P1 are clamped to X=24–136 so a normal 8-pixel sprite stays inside the walls. The expert
double-width enemy at X=136 spans 136–151 and overlaps the right wall; sprites are drawn over the
playfield because `CTRLPF`'s priority bit is clear, so it remains visible. The three-copy exercise
caps X at 104 so all three 8-pixel copies end at 143, exactly inside the wall.

The level bar, life cells, and switch indicator use three different `COLUPF` colours, so the
kernel changes the colour at the start of each zone. The first line of each zone is the critical
one: the loop returns at the start of the new zone's first line, and the `LDA`/`STA` pairs run at
cycles 2–22; PF0 and PF1 are written by cycle 17, and PF2 by cycle 22, well before PF2's first
slot later in the line. The level bar's very first line is different: the level zone has no write
stage at all — it only waits eight lines. If the three PF bytes were not preloaded, visible line
0 would still show the previous frame's play-area wall bytes (`PF0=$F0`) until line 1. The colour
could be written at `BodyStart` and still land in HBLANK, but the PF bytes have no write slot in
the zone, so the ROM preloads all three bytes and the gold colour in VBLANK, before `STA VBLANK`.
The visible kernel then starts with the bar already in place.

The two players are positioned in VBLANK with the Lesson 26 divide-by-15 routine and a single
`HMOVE`:

```asm
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
HmoveDone:                  ; checkpoint: the store has executed (next line, cycle 3)
```

`SetCoarseP0` and `SetCoarseP1` leave their fine values in `HMP0`/`HMP1`; the single `STA HMOVE`
applies both in one HBLANK. The measured checkpoint is `HmoveApply` at scanline 6–7, cycle 36–41,
and `HmoveDone` on the next line at cycle 3. One `HMOVE` per frame is the rule from Lesson 28.

### Section 7: The Auto-Demo

A lesson ROM has to demonstrate itself. This one does not move P0 on its own; the enemy's bounce
is deterministic, and with no joystick input P0 stands still at X=80. P1 starts at X=24 moving
right and reaches P0 on its own:

1. At level 1, speed 1. The first drawn contact is on frame 49 (P1's right edge reaches P0's
   left edge); the VBLANK read charges the life on frame 50, and `LifeStep` reports `A=2`.
2. P1 respawns at X=136 moving left. The 60-frame invulnerability lets it pass through P0 before
   the latch can charge again, so the next contact waits for the far wall: frame 212, `A=1`.
3. The 300-frame timer expires at frame 301. `LevelUp` reports `A=2`, the bar flashes, and the
   ladder moves to level 2; the speed table still returns 1 for levels 1–3, so the enemy's pace
   changes at level 4.
4. The third contact is at frame 374: `A=0`, `GameOver=1`, and the field turns red. The play
   update freezes; the red field stays until fire is pressed.

On expert the same passive run is shorter: the level starts at 5, speed 2, and the wider enemy
meets P0 at frame 21. The three lives are gone by frame 175, before the first level-up. That is
why the level-5 capture starts the ROM with both switches on A rather than waiting for the ladder
to climb: the left switch already selects level 5, and the right switch selects the 16-pixel
enemy.

The captures use Stella's `-speed 0.05` option. That slows the emulator to about three frames per
second, so a capture six seconds after launch shows roughly the first ten frames: level 1 or 5,
three life cells per half, and P1 before its first contact. The speed option changes only the emulator's wall-clock
pace; the ROM and the frame it produces are the same as at 60 Hz. The method is disclosed again in
"What You Should See."

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson42.bin lessons/part6-game-dev/42-difficulty/42-difficulty.asm
stella build/lesson42.bin
```

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 42: Difficulty and Progression — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; What this program does:
;   "the difficulty ladder": the console's two difficulty switches choose how
;   the game starts, and a 15-entry speed table keeps raising the pressure as
;   the player survives.  The left switch picks the starting level (1 on
;   novice, 5 on expert); the right switch picks the enemy's width (8 pixels
;   on novice, 16 pixels on expert, NUSIZ1=5).  A level bar, three life
;   cells per half, and a two-cell switch indicator per half are the visible
;   state.
;
; The screen (192 visible lines, CTRLPF=$01 so the playfield is mirrored):
;   visible 0-7     the level bar: Level chunks per half, gold ($1A)
;   visible 8-15    the life cells: three red ($42) cells per half, each
;                   2 chunks, at X=8, 16, and 24; one cell per remaining life
;   visible 16-23   the switch indicator: two white ($0E) 1-chunk cells per
;                   half; the left cell is lit when the left switch is on
;                   expert (SWCHB bit 6=1), the right cell when the right
;                   switch is on expert (bit 7=1)
;   visible 24-139  the play area: the gold edge walls (PF0=$F0 mirrored)
;   visible 140-155 P0 (16 rows, red $42) and P1 (16 rows, green $C8);
;                   both share these scanlines so CXPPMM bit 7 can set
;   visible 156-191 the play area's bottom wall section
;   The zones total 8+8+8+116+16+36 = 192 lines; OverscanStart is scanline
;   229.
;
; The game:
;   P0 starts at X=80 and moves left/right with the joystick, clamped to
;   X=24..136.  P1 starts at X=24, direction right, and bounces between
;   X=24 and X=136 at Speed = SpeedTable[Level] (1..4 pixels per frame).
;   A P0-P1 contact (CXPPMM bit 7, read in VBLANK and edge-detected) costs a
;   life, beeps, respawns P1 on the opposite side of P0, and arms 60 frames
;   of invulnerability (P1 blinks during it).  At 0 lives the play area turns
;   red, Invuln and FlashTimer are cleared, the play update freezes, and fire
;   starts a new game.
;
;   Every 300 survived play frames the level-up path runs.  A level that
;   actually changes flashes the bar for 30 frames and plays a beep; at the
;   cap the clock reloads but the flash and beep are skipped.  The level
;   timer is 16 bits: LevelTimerLo/LevelTimerHi hold 300 = $012C.
;
; The switches (SWCHB, $0282):
;   bit 6  P0 difficulty (the left switch): 0=novice/B, 1=expert/A
;   bit 7  P1 difficulty (the right switch): 0=novice/B, 1=expert/A
;   Older register tables -- including this course's pre-fix comment -- had
;   the polarity inverted; include/vcs.asm now states 0=B/novice/1=A/expert,
;   and Stella's -ld/-rd command line options agree: -ld A gives bit 6=1.
;   The starting level is sampled when a game starts: novice -> 1,
;   expert -> 5.  The width is sampled every frame, so flipping the right
;   switch changes NUSIZ1 immediately: novice -> 0 (8 px), expert -> 5
;   (double width, 16 px).
;
; The auto-demo (so the captures are deterministic):
;   With no joystick input P0 stands still at X=80, so the bouncing P1
;   reaches it on its own.  The first drawn contact is at frame 49 and the
;   VBLANK read charges it at frame 50; the 60-frame invulnerability lets
;   P1 pass through P0 before the latch can count again, so the next contact
;   waits for the far-wall round trip.  The passive run therefore survives
;   long enough to reach level 2 at frame 301 and loses its last life at
;   frame 374.  The red game-over field then stays until fire is pressed;
;   fire starts a new game at the switch-selected starting level (level 1 on
;   novice, level 5 on expert).
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), ReadSWCHB (A = SWCHB),
;   NUSIZWrite (A = NUSIZ1), ReadCX (A = CXPPMM), CXClear (the strobe),
;   SpeedWrite (A = speed), LevelUp (A = level), LifeStep (A = lives),
;   LifeInit (A = 3 at a fresh game),
;   BodyStart (37), HmoveApply/HmoveDone (one per frame), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson42.bin \
;        lessons/part6-game-dev/42-difficulty/42-difficulty.asm
; Run:   stella build/lesson42.bin     (click the screen to hear the beep)
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

LEVEL_MAX      = 15
LEVEL_FRAMES_LO = $2C    ; 300 frames = $012C
LEVEL_FRAMES_HI = $01
INVULN_FRAMES  = 60
FLASH_FRAMES   = 30

START_NOVICE   = 1       ; left switch = novice/B (bit 6 = 0)
START_EXPERT   = 5       ; left switch = expert/A (bit 6 = 1)
ENEMY_MIN_X    = 24
ENEMY_MAX_X    = 136
PLAYER_MIN_X   = 24
PLAYER_MAX_X   = 136

BEEP_FRAMES    = 8
HIT_PITCH      = $08     ; AUDF 8 on AUDC $0C: a short, bright hit
LEVEL_PITCH    = $0C     ; a slightly lower note for a level-up
BEEP_PITCH_DEFAULT = HIT_PITCH

C_RED          = $42
C_GOLD         = $1A
C_GREEN        = $C8
C_WHITE        = $0E
C_BG           = $02

; --- Lesson variables (RAM $80-$9C; +clean_start zeroes them) ---
Level        = $80   ; 1..15, the current level
LevelTimerLo = $81   ; the 16-bit survival clock, low byte (300 = $012C)
LevelTimerHi = $82   ; the survival clock, high byte
Lives        = $83   ; 3 at the start, 0 = game over
EnemyX       = $84   ; P1's left edge, 24..136
EnemyDir     = $85   ; 1 = moving right, 0 = moving left
PlayerX      = $86   ; P0's left edge, 24..136
Switches     = $87   ; the last SWCHB read
Invuln       = $88   ; frames of invulnerability remaining
FlashTimer   = $89   ; frames of level-bar flashing remaining
GameOver     = $8A   ; 1 = the red frozen field; fire restarts
Frame        = $8B   ; free-running 8-bit frame counter (blink uses bit 2)
PrevFire     = $8C   ; fire state last frame (1 = pressed)
NewFire      = $8D   ; this frame's fire 0 -> 1 edge
Speed        = $8E   ; SpeedTable[Level], 1..4
NeedStart    = $8F   ; 1 = the next VBLANK must start a game
StartLevel   = $90   ; the switch-selected starting level
CollBit      = $91   ; this frame's CXPPMM bit 7 and then its 0 -> 1 edge
PrevColl     = $92   ; last frame's CXPPMM bit 7
LevelPF0     = $93   ; the level bar's three playfield bytes
LevelPF1     = $94
LevelPF2     = $95
LifePF0      = $96   ; the life cells' two playfield bytes
LifePF1      = $97
SwitchPF0    = $98   ; the switch indicator's two playfield bytes
SwitchPF1    = $99
EnemyDraw    = $9A   ; $FF, or 0 during the invulnerability blink's off phase
BeepTimer    = $9B   ; frames of beep remaining
BeepPitch    = $9C   ; AUDF for the beep
;
; The shared score/random libraries are not used, so $9D-$D7 is free.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the first game starts in the first VBLANK, after SWCHB is read --------
; Reset only marks the game as pending; StartGame samples the left switch,
; so the switch's state at power-on is the state that starts the game.
    LDA #1
    STA NeedStart
    LDA #BEEP_PITCH_DEFAULT
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
    INC Frame
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0
BeepDone:

; -----------------------------------------------------------------------------
; 2. READ THE CONSOLE SWITCHES
; -----------------------------------------------------------------------------
; SWCHB reports the difficulty switches as 0 = B/novice and 1 = A/expert:
; bit 6 is the left (P0) switch and bit 7 the right (P1) switch.  The byte
; is stored so the visible kernel can draw the indicator, and it is re-read
; every frame so a mid-game flip is visible immediately.
    LDA SWCHB
ReadSWCHB:                  ; checkpoint: A = SWCHB
    STA Switches

; --- the two-cell switch indicator ------------------------------------------
; The left cell is PF0 bit 6 (chunk 2, X=8); the right cell is PF1 bit 5
; (chunk 6, X=24).  A cell is lit when its switch is on expert (bit = 1).
    LDA #$00
    STA SwitchPF0
    STA SwitchPF1
    LDA Switches
    AND #$40                ; the left switch (P0 difficulty)
    BEQ SwitchLeftDone
    LDA #$40                ; expert: light the left cell
    STA SwitchPF0
SwitchLeftDone:
    LDA Switches
    AND #$80                ; the right switch (P1 difficulty)
    BEQ SwitchRightDone
    LDA #$20                ; expert: light the right cell
    STA SwitchPF1
SwitchRightDone:

; -----------------------------------------------------------------------------
; 3. THE ENEMY'S WIDTH FROM THE RIGHT SWITCH
; -----------------------------------------------------------------------------
; NUSIZ1=0 is one 8-pixel copy; NUSIZ1=5 is double width (16 pixels).  The
; store writes the whole register, so bits 4-5 become 0: the missile size is
; 1 pixel.  This lesson does not use the missiles.
    LDA Switches
    AND #$80
    BEQ EnemyWidthNovice
    LDA #$05                ; expert: double width
    BNE EnemyWidthStore
EnemyWidthNovice:
    LDA #$00                ; novice: one 8-px enemy
EnemyWidthStore:
    STA NUSIZ1
NUSIZWrite:                 ; checkpoint: A = NUSIZ1

; -----------------------------------------------------------------------------
; 4. FIRE — one action per 0 -> 1 edge
; -----------------------------------------------------------------------------
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
; 5. THE P0-P1 COLLISION LATCH
; -----------------------------------------------------------------------------
; Both players are drawn on visible lines 140-155, so CXPPMM bit 7 can set.
; The read is in VBLANK and therefore describes the previous visible frame.
; The latch is sticky until CXCLR, so the code keeps the previous bit and
; keeps only the 0 -> 1 edge: a contact that lasts several frames is one hit.
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
; 6. START A GAME WHEN REQUESTED
; -----------------------------------------------------------------------------
; StartGame samples the left switch, so the starting level is fixed for the
; life of the game; flipping the switch mid-game does not move the ladder.
    LDA NeedStart
    BEQ NoStartGame
    JSR StartGame
NoStartGame:

; -----------------------------------------------------------------------------
; 7. THE PLAY UPDATE, OR THE GAME-OVER FREEZE
; -----------------------------------------------------------------------------
    LDA GameOver
    BEQ PlayUpdate
    ; --- game over: play freezes; fire starts a new game ------------------
    LDA NewFire
    BNE GameOverRestart
    JMP DisplayBuild
GameOverRestart:
    JSR StartGame
    JMP DisplayBuild

PlayUpdate:
; --- invulnerability counts down one frame at a time -----------------------
    LDA Invuln
    BEQ InvulnDone
    DEC Invuln
InvulnDone:

; --- a new P0-P1 contact costs a life --------------------------------------
; The edge test and the invulnerability window together mean one contact is
; one life, even though the latch stays set while the sprites overlap.
    LDA CollBit
    BEQ NoCollision
    LDA Invuln
    BNE NoCollision
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
    BNE NoCollision
    LDA #1
    STA GameOver            ; the next frame draws the red field
    LDA #0
    STA Invuln              ; stop the enemy blink on the frozen field
    STA FlashTimer          ; stop the level-bar flash on the frozen field
NoCollision:

; --- P0's motion: the joystick, clamped to the walled play area ------------
    LDA SWCHA
    AND #$C0                ; P0 left (bit 6) and right (bit 7)
    CMP #$C0
    BEQ PlayerMoveDone
    LDA SWCHA
    AND #$40                ; left
    BNE PlayerNoLeft
    JMP MoveLeft
PlayerNoLeft:
    LDA SWCHA
    AND #$80                ; right
    BNE PlayerMoveDone
    JMP MoveRight
PlayerMoveDone:

; --- the speed table, indexed by level -------------------------------------
    LDX Level
    DEX                     ; level 1 -> table entry 0
    LDA SpeedTable,X
    STA Speed
SpeedWrite:                 ; checkpoint: A = SpeedTable[Level]

; --- P1's deterministic bounce ---------------------------------------------
    JSR MoveEnemy

; --- the 300-frame survival clock ------------------------------------------
    LDA LevelTimerLo
    BNE LevelDecLo
    LDA LevelTimerHi
    BEQ LevelUpNow
    DEC LevelTimerHi
    LDA #$FF
    STA LevelTimerLo
    JMP LevelTickDone
LevelDecLo:
    DEC LevelTimerLo
    JMP LevelTickDone
LevelUpNow:
    LDA Level
    CMP #LEVEL_MAX
    BCS LevelCapNow
    CLC
    ADC #1
    CMP #LEVEL_MAX
    BCC LevelUpStore
LevelCapNow:
    LDA #LEVEL_MAX
LevelUpStore:
LevelUp:                    ; checkpoint: A = the new level (capped at 15)
    CMP Level
    BEQ LevelAtCap          ; no change: reload the clock, skip the reward
    STA Level
    LDA #FLASH_FRAMES
    STA FlashTimer
    LDA #LEVEL_PITCH
    STA BeepPitch
    JSR BeepStart
LevelAtCap:
    LDA #LEVEL_FRAMES_LO
    STA LevelTimerLo
    LDA #LEVEL_FRAMES_HI
    STA LevelTimerHi
LevelTickDone:

; --- the level-bar flash clock ---------------------------------------------
    LDA FlashTimer
    BEQ FlashDone
    DEC FlashTimer
FlashDone:

; -----------------------------------------------------------------------------
; 8. BUILD THE DISPLAY BYTES FOR THIS FRAME
; -----------------------------------------------------------------------------
DisplayBuild:
; --- the level bar: Level chunks per half, or a 4-on/4-off flash -----------
    LDA FlashTimer
    BEQ LoadLevelBar
    LDA Frame
    AND #$04                ; 4 frames off, 4 frames on while flashing
    BNE LoadLevelBar
    LDA #$00
    STA LevelPF0
    STA LevelPF1
    STA LevelPF2
    JMP LevelBarDone
LoadLevelBar:
    LDA Level
    ASL                     ; Level * 3: three playfield bytes per entry
    CLC
    ADC Level
    TAX
    LDA LevelBarPF,X
    STA LevelPF0
    LDA LevelBarPF+1,X
    STA LevelPF1
    LDA LevelBarPF+2,X
    STA LevelPF2
LevelBarDone:

; --- the life cells: 3, 2, 1, or 0 lit cells -------------------------------
    LDA Lives
    ASL                     ; two playfield bytes per entry
    TAX
    LDA LifePF,X
    STA LifePF0
    LDA LifePF+1,X
    STA LifePF1

; --- P1 blinks while it is invulnerable ------------------------------------
    LDA #$FF
    STA EnemyDraw
    LDA Invuln
    BEQ EnemyDrawDone
    LDA Frame
    AND #$04
    BNE EnemyDrawDone
    LDA #$00
    STA EnemyDraw
EnemyDrawDone:

; -----------------------------------------------------------------------------
; 9. POSITION BOTH PLAYERS, THEN STROBE ONE HMOVE
; -----------------------------------------------------------------------------
; Both use the same +POS_BIAS target as Lesson 26/41.  Their fine values sit
; in HMP0/HMP1 until the single HMOVE applies both in one HBLANK.
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
HmoveDone:                  ; checkpoint: the store has executed (next line, cycle 3)

; -----------------------------------------------------------------------------
; 10. COLORS, SIZES, AND THE FIRST VISIBLE LINE'S PLAYFIELD
; -----------------------------------------------------------------------------
    LDA #C_RED
    STA COLUP0              ; P0 is red
    LDA #C_GREEN
    STA COLUP1              ; P1 is green
    LDA #C_BG
    STA COLUBK              ; the dark play-field background
    LDA #$01
    STA CTRLPF              ; reflect the playfield; ball one pixel wide
    LDA #$00
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL

; --- the level bar's first line is preloaded in VBLANK ---------------------
; The level zone has no write stage of its own: it only waits eight lines.
; Without the preload, visible line 0 would still show the previous frame's
; play-area wall bytes (PF0=$F0) until line 1.  Loading the three PF bytes
; and the gold colour here makes line 0 as solid as the other seven.
    LDA LevelPF0
    STA PF0
    LDA LevelPF1
    STA PF1
    LDA LevelPF2
    STA PF2
    LDA #C_GOLD
    STA COLUPF

; --- the game-over field is red --------------------------------------------
    LDA GameOver
    BEQ GameOverColorDone
    LDA #C_RED
    STA COLUBK
GameOverColorDone:

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- visible 0-7: the level bar (PF and COLUPF preloaded in VBLANK) --------
    LDY #8
LevelZone:
    STA WSYNC
    DEY
    BNE LevelZone

; --- visible 8-15: the life cells (red) ------------------------------------
    LDA #C_RED
    STA COLUPF
    LDA LifePF0
    STA PF0
    LDA LifePF1
    STA PF1
    LDA #$00
    STA PF2
    LDY #8
LifeZone:
    STA WSYNC
    DEY
    BNE LifeZone

; --- visible 16-23: the switch indicator (white) --------------------------
    LDA #C_WHITE
    STA COLUPF
    LDA SwitchPF0
    STA PF0
    LDA SwitchPF1
    STA PF1
    LDA #$00
    STA PF2
    LDY #8
SwitchZone:
    STA WSYNC
    DEY
    BNE SwitchZone

; --- visible 24-139: the edge walls, no sprites ---------------------------
    LDA #C_GOLD
    STA COLUPF
    LDA #$F0                ; PF0 bits 4-7: the 16-px wall at each edge
    STA PF0
    LDA #$00
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    LDY #116
PlayTop:
    STA WSYNC
    DEY
    BNE PlayTop

; --- visible 140-155: both 16-row players ---------------------------------
; The two stores land at cycles 5-10 of the first sprite line, well before
; the earliest P0/P1 pixel (X=24 is absolute clock 92, CPU cycle ~31).
    LDA EnemyDraw
    STA GRP1
    LDA #$FF
    STA GRP0
    LDY #16
PlaySprites:
    STA WSYNC
    DEY
    BNE PlaySprites

; --- visible 156-191: the players are over; walls only --------------------
    LDA #$00
    STA GRP0
    STA GRP1
    LDY #36
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
; StartGame — the switch-selected starting level and a fresh game
; =============================================================================
; Called from the first VBLANK (NeedStart) and from the game-over fire edge.
; The left switch (SWCHB bit 6) picks novice=1 or expert=5; the value is
; stored in StartLevel so the debugger can show what the switch chose.
StartGame:
    LDA Switches
    AND #$40                ; the left switch
    BEQ StartNovice
    LDA #START_EXPERT
    BNE StartLevelStore
StartNovice:
    LDA #START_NOVICE
StartLevelStore:
    STA StartLevel
StartLevelSet:              ; checkpoint: A = the switch-selected start level
    STA Level
    LDA #3
    STA Lives
LifeInit:                   ; checkpoint: A = 3 at the start of a game
    LDA #LEVEL_FRAMES_LO
    STA LevelTimerLo
    LDA #LEVEL_FRAMES_HI
    STA LevelTimerHi
    LDA #80
    STA PlayerX
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir
    LDA #$00
    STA Invuln
    STA FlashTimer
    STA GameOver
    STA NeedStart
    STA PrevColl
    LDA #BEEP_PITCH_DEFAULT
    STA BeepPitch
    RTS

; =============================================================================
; RespawnEnemy — put P1 on the side away from P0, moving back toward P0
; =============================================================================
; A = the hit was already charged to Lives.  If P0 was to the right of P1,
; P1 respawns at the right wall and moves left; otherwise it respawns at the
; left wall and moves right.  The trip back is the player's breathing room.
RespawnEnemy:
    LDA EnemyX
    CMP PlayerX
    BCC RespawnRight
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir
    RTS
RespawnRight:
    LDA #ENEMY_MAX_X
    STA EnemyX
    LDA #0
    STA EnemyDir
    RTS

; =============================================================================
; MoveEnemy — P1's bounce, at Speed pixels per frame
; =============================================================================
; The clamp is also the bounce: a step past a wall snaps to the wall and
; flips EnemyDir.  At the 1..4 px speeds the difference is invisible.
MoveEnemy:
    LDA EnemyDir
    BNE EnemyRight
; --- moving left -----------------------------------------------------------
    LDA EnemyX
    SEC
    SBC Speed
    BCS EnemyLeftInRange
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir
    RTS
EnemyLeftInRange:
    CMP #ENEMY_MIN_X
    BCS EnemyLeftStore
    LDA #ENEMY_MIN_X
    STA EnemyX
    LDA #1
    STA EnemyDir
    RTS
EnemyLeftStore:
    STA EnemyX
    RTS
; --- moving right ----------------------------------------------------------
EnemyRight:
    LDA EnemyX
    CLC
    ADC Speed
    BCC EnemyRightInRange
    LDA #ENEMY_MAX_X
    STA EnemyX
    LDA #0
    STA EnemyDir
    RTS
EnemyRightInRange:
    CMP #(ENEMY_MAX_X + 1)
    BCC EnemyRightStore
    LDA #ENEMY_MAX_X
    STA EnemyX
    LDA #0
    STA EnemyDir
    RTS
EnemyRightStore:
    STA EnemyX
    RTS

; =============================================================================
; P0's movement, clamped to the walled play area
; =============================================================================
MoveLeft:
    DEC PlayerX
    LDA PlayerX
    CMP #PLAYER_MIN_X
    BCS MoveDone
    LDA #PLAYER_MIN_X
    STA PlayerX
    JMP MoveDone
MoveRight:
    INC PlayerX
    LDA PlayerX
    CMP #(PLAYER_MAX_X + 1)
    BCC MoveDone
    LDA #PLAYER_MAX_X
    STA PlayerX
MoveDone:
    JMP PlayerMoveDone

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
; SPEED TABLE — 15 entries, indexed by Level-1
; =============================================================================
; The ladder is deliberately gentle at the bottom: levels 1-3 are 1 px,
; 4-6 are 2 px, 7-10 are 3 px, and 11-15 are 4 px per frame.  Level 5 is
; therefore twice level 1, which is what the two captures compare.
SpeedTable:
    !byte 1,1,1,2,2,2,3,3,3,3,4,4,4,4,4

; =============================================================================
; LEVEL-BAR TABLE — N chunks from the left, three playfield bytes per entry
; =============================================================================
; PF0 bits 4-7 are the first four chunks (bit 4 leftmost); PF1 bits 7-0 are
; the next eight (bit 7 leftmost); PF2 bits 0-2 are the last three (bit 0 is
; leftmost, because PF2's bit order is reversed).  CTRLPF=$01 mirrors the
; same chunks from the right edge, so every count is "per half".
LevelBarPF:
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
; LIFE-CELL TABLE — three cells at X=8, 16, and 24
; =============================================================================
; Cell 1 is PF0 bits 6-7 (chunks 2-3, X=8); cell 2 is PF1 bits 6-7 (chunks
; 4-5, X=16); cell 3 is PF1 bits 4-5 (chunks 6-7, X=24).
LifePF:
    !byte $00,$00           ; 0 lives
    !byte $C0,$00           ; 1 life: cell 1
    !byte $C0,$C0           ; 2 lives: cells 1 and 2
    !byte $C0,$F0           ; 3 lives: all three cells

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
> `lessons/part6-game-dev/42-difficulty/42-difficulty.asm`.

### Code Walkthrough

#### Step 1 — Reset: a pending game, not a running one

`+clean_start` zeroes TIA and RAM and sets the stack. Reset writes `SWACNT=0` (port A is the
joystick input), sets `NeedStart=1`, and stores the default beep pitch. It does not touch `Level`
or `Lives` directly: the first VBLANK reads `SWCHB` and calls `StartGame`, so the switch position
at power-on is the position that starts the game. This is the same "one door" discipline as
Lesson 41's `SetState`, applied to the game's setup.

#### Step 2 — VBLANK: the frame's fixed order

1. **Frame and beep.** `INC Frame`; `BeepTimer` counts down and `AUDV0=0` at zero.
2. **Switches.** `LDA SWCHB` → `Switches`; `ReadSWCHB` reports the raw byte. The two-cell
   indicator bytes are derived from bits 6 and 7.
3. **Width.** `NUSIZ1` is written from bit 7: 0 on novice, 5 on expert. `NUSIZWrite` reports it.
4. **Fire.** `INPT4` bit 7 is flipped to 1 = pressed and edge-detected into `NewFire`.
5. **Collision.** `CXPPMM` bit 7 is saved, edge-detected against `PrevColl`, and the latches are
   cleared with `CXCLR`. `ReadCX` reports the raw byte; `CXClear` marks the strobe.
6. **Start.** If `NeedStart` is set, `StartGame` samples the left switch and resets the game.
7. **Play or freeze.** If `GameOver=1`, only the fire edge is checked; fire calls `StartGame`
   and the frame continues to the display build. Otherwise the play update runs.
8. **Invulnerability.** `Invuln` counts down one per frame.
9. **Contact.** A new `CollBit` with `Invuln=0` charges a life, starts the hit beep, respawns P1,
   arms 60 frames, and sets `GameOver` if the life count reached 0; that path also clears
   `Invuln` and `FlashTimer`.
10. **Movement.** P0 follows the joystick (clamped 24–136); the speed table is indexed by
    `Level-1`; `MoveEnemy` bounces P1 (clamped 24–136); the 16-bit timer decrements; a level-up
    raises `Level` (cap 15), reloads the timer, starts the level beep, and sets `FlashTimer=30`;
    `FlashTimer` decrements.
11. **Display bytes.** `LevelPF0/1/2` from `Level` (or zero during the flash's off phase),
    `LifePF0/1` from `Lives`, `EnemyDraw` from the invulnerability blink.
12. **Positioning.** `SetCoarseP0`/`SetCoarseP1` set the coarse resets and fine values; one
    `STA HMOVE` applies both.
13. **Colours and preload.** P0 red, P1 green, background `$02` (or `$42` at game over),
    `CTRLPF=$01`; the level bar's three PF bytes and gold colour are preloaded for visible line 0.
    `+wait_timer` then anchors the visible section at scanline 37.

#### Step 3 — StartGame and the starting level

`StartGame` reads `Switches` bit 6. `BEQ StartNovice` means bit 6 = 0 (B/novice) → level 1;
the fall-through is bit 6 = 1 (A/expert) → level 5. `StartLevel` stores the choice and
`StartLevelSet` reports it. The rest of the routine is the fresh-game setup: three lives, the
`$012C` timer, P0 at X=80, P1 at X=24 moving right, no invulnerability, no flash, not game over,
`NeedStart` cleared, `PrevColl` cleared, and the default beep pitch. `LifeInit` reports A=3 right
after the life byte is stored. The exact same routine runs on the first VBLANK and on the
game-over fire edge, so a restart cannot forget any of it.

#### Step 4 — The speed table and the bounce

The play update indexes `SpeedTable` with `Level-1` and stores the result in `Speed`. `MoveEnemy`
uses that byte in both directions:

- Moving left: subtract `Speed`; if it borrows, clamp to 24 and set `EnemyDir=1`. If the result
  is below 24, clamp and flip. Otherwise store it.
- Moving right: add `Speed`; if it carries past 255, clamp to 136 and set `EnemyDir=0`. If the
  result is above 136, clamp and flip. Otherwise store it.

The clamp is also the bounce. At 1–4 pixels per frame the snap is invisible; what the player sees
is the enemy reaching the wall and turning around. The same `ENEMY_MAX_X` constant is used by the
respawn routine and the movement routine, so the exercise's 104 cap applies everywhere.

#### Step 5 — The 16-bit survival clock

The timer is stored little-endian: `LevelTimerLo` holds the low byte, `LevelTimerHi` the high
byte. The decrement checks the low byte first; only when it is zero does the high byte get a turn.
When both are zero, the level-up path runs. `Level` is compared with 15 before the increment and
the incremented value is compared again, so the result is always `min(Level+1, 15)`. The reload
happens in the same VBLANK, so the next 300-frame window starts immediately. A level-up that
changes the level sets `FlashTimer=30` and starts the level beep (pitch `$0C`, distinct from the
hit's `$08`); at the cap the clock reloads but the flash and beep are skipped.

#### Step 6 — The collision, the life, and the freeze

The collision read and edge test are identical to Lesson 38's, with the mask narrowed to bit 7.
The hit handler is guarded by `Invuln`: a contact while invulnerable is ignored, even if the
latch is set. On a hit, `Lives` is decremented with `SEC`/`SBC #1` so `LifeStep` can report the
new byte; the beep starts; `RespawnEnemy` puts P1 on the far side; `Invuln=60`; and if the new
life count is zero, `GameOver=1`. That same path clears `Invuln` and `FlashTimer`, so the frozen
field does not keep blinking the enemy or flashing the bar. The VBLANK colour setup turns
`COLUBK` red for `GameOver`, and the next VBLANK skips the entire play update. The red field is
therefore both a colour and a freeze: the last frame's sprite positions stay on screen, and fire
is the only input that matters.

#### Step 7 — The four status zones and the play area

The kernel is work-first: write the line's registers, then `STA WSYNC`. The level zone uses the
preloaded PF bytes and gold colour. The life zone writes red `COLUPF`, `LifePF0/1`, and `PF2=0`,
then waits eight lines. The switch zone writes white `COLUPF` and the two indicator bytes. The
play area writes gold `COLUPF`, `PF0=$F0`, clears PF1/PF2 and both sprites, and waits 116 lines.
At line 140 it writes `GRP1=EnemyDraw` and `GRP0=$FF`, holds 16 lines, clears both, and holds 36
more. The line counts are 8 + 8 + 8 + 116 + 16 + 36 = 192.

The two sprite stores at line 140 happen at cycles 5–10, well before the earliest P0/P1 pixel at
X=24 (absolute colour clock 92, CPU cycle ≈31). The clear at line 156 happens at cycles 2–8,
before that line's sprite slot, so the sprites end exactly after 16 rows. The level bar's first
line is the only one that needs the VBLANK preload because its zone has no write stage; without
it, line 0 would keep the previous frame's wall bytes. Every other zone change happens at the
start of its first line, before the playfield slots.

#### Step 8 — Reading it back

```bash
acme -f plain -l build/lesson42.sym -o build/lesson42.bin \
  lessons/part6-game-dev/42-difficulty/42-difficulty.asm
grep -E "StartFrame|VblankStart|ReadSWCHB|NUSIZWrite|FireRead|ReadCX|CXClear|SpeedWrite|LevelUp|LifeInit|LifeStep|BodyStart|HmoveApply|HmoveDone|OverscanStart|StartLevelSet" build/lesson42.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F12E' \
  docs/public/roms/part6-game-dev/42-difficulty/42-difficulty.bin
```

Stella keeps one `-break` per run — the last one on the command line — so run one checkpoint at a
time. The passive run is deterministic: with no joystick input and both difficulty switches on B,
the frame numbers below repeat on every run.

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F01B` | **259, cycle 3** | the first VSYNC line |
| `VblankStart` | `$F029` | 0, cycle 5 | the first VBLANK line |
| `ReadSWCHB` | `$F043` | A=`$3F` (B,B), `$FF` (A,A), `$7F` (A,B), `$BF` (B,A) | the raw switch byte |
| `NUSIZWrite` | `$F06D` | A=0 on novice, A=5 on expert | `NUSIZ1` |
| `FireRead` | `$F06F` | A=`$8C` released; A=`$0C` pressed | `INPT4`; bit 7 is the button |
| `ReadCX` | `$F085` | A=`$07` at rest; A=`$87` at frame 50 | `CXPPMM`; bit 7 is P0–P1 |
| `CXClear` | `$F098` | A=0 | the `CXCLR` strobe |
| `SpeedWrite` | `$F106` | A=1 at level 1; A=2 at level 5; A=3 at level 10; A=4 at level 15 | `SpeedTable[Level]` |
| `LevelUp` | `$F12E` | A=2 at frame 301; A=15 at the cap | the new level, capped at 15; at the cap the clock reloads without a flash or beep |
| `LifeInit` | `$F27F` | A=3 at frame 1 | the fresh-game life count |
| `LifeStep` | `$F0C3` | A=2 at frame 50; A=1 at 212; A=0 at 374 | the new life count |
| `StartLevelSet` | `$F279` | A=1 on B/B; A=5 on A/A | the switch-selected start level |
| `BodyStart` | `$F1EB` | **37, cycle 5** | visible line 0 |
| `HmoveApply` | `$F1AA` | 6, cycle 36–41 | the `WSYNC` stall before the one `HMOVE` |
| `HmoveDone` | `$F1AC` | 7, cycle 3 | the store has executed |
| `OverscanStart` | `$F258` | **229, cycle 7** | overscan's first line |

The two RAM values to watch are `Level` at `$80` and `Lives` at `$83`. `Level` is the byte the
bar and the table use; `Lives` is the byte the cells use. `LevelTimerLo/Hi` are `$81/$82`; the
timer counts down in play and freezes at game over. `Switches` is `$87`; `GameOver` is `$8A`.

## What You Should See

**Level 1 (novice).** Both switches on B. The level bar has one gold chunk per half at the very
top, so the bar is 4 pixels wide on each side. Three red life cells **per half** form a 24-pixel
bar on each side at visible lines 8–15; the cells touch, so each bar shortens by 8 pixels for
each lost life. The two switch-indicator cells **per half** are dark (novice), so the mirrored
display shows four dark cells. The play area is a dark `$02` field with 16-pixel gold
walls at each edge. P0 is the red 8×16 block at visible lines 140–155, X=80. P1 is the green 8×16
block on the same rows, moving right from X=24 at 1 pixel per frame. At the captured frame the
enemy is still well left of P0, so the two players have not met yet.

![Stella running the Lesson 42 ROM with both difficulty switches on novice: a one-chunk gold level bar, three red life cells per half, dark switch cells, gold side walls, and a green 8-pixel enemy left of the red player](/images/lesson42/level1.png)

*Level 1: one gold chunk per half, three red life cells per half, both switch cells dark, and an
8-pixel enemy.*

**Level 5 (expert).** Both switches on A. The left switch samples the starting level as 5, so the
level bar has five gold chunks per half (20 pixels, X=0–19). The right switch selects `NUSIZ1=5`,
so the green enemy is 16 pixels wide; at the captured frame it is still well left of P0.
The two switch-indicator cells **per half** are white (four cells on screen): the left cell is the
left switch's A position, the right cell is the right switch's A position. The life cells are
still three per half (six on screen). The speed table maps level 5 to 2 pixels per frame, twice
level 1.

![Stella running the Lesson 42 ROM with both difficulty switches on expert: a five-chunk gold level bar, three red life cells per half, two white switch cells per half, gold side walls, and a 16-pixel green enemy left of the red player](/images/lesson42/level5.png)

*Level 5: five gold chunks per half, two white switch cells per half, and a 16-pixel expert
enemy.*

> **Capture method.** Both images are window captures of the committed ROM in Stella 7.0 with
> `-tia.zoom 3`. The emulator was run with `-speed 0.05`, which advances about three frames per
> second, so the capture six seconds after launch shows roughly the first ten frames — before the
> first contact and before any level-up. `level1.png` used `-ld B -rd B`; `level5.png` used
> `-ld A -rd A`. The pointer was parked outside the window; no game pixel was altered.

<RomPlayer rom="/roms/part6-game-dev/42-difficulty/42-difficulty.bin" title="Lesson 42 — Difficulty and Progression" />

Click the player screen once: Javatari starts muted until a user gesture. The ROM starts at level
1 with the default switches; set the left switch to A before a reset to start at level 5, or use
the player's console-switch panel if it exposes the difficulties. With no joystick input the enemy
will find P0 on its own, so the life cells, the red game-over field, and the fire restart are all
reachable without a controller. At game over the red field is steady: the enemy stays visible (no
invulnerability blink) and the level bar stops flashing, because the hit handler clears `Invuln`
and `FlashTimer` when it sets `GameOver`.

The debugger writes the same story as numbers:

- **`$F043` (`ReadSWCHB`)**: A=`$3F` with both switches on B, `$FF` with both on A. Bits 6/7 are
  the two difficulty switches; 0 is B/novice, 1 is A/expert.
- **`$F06D` (`NUSIZWrite`)**: A=0 on novice, A=5 on expert. `$F279` (`StartLevelSet`) reports A=1
  on B/B and A=5 on A/A.
- **`$F06F` (`FireRead`)**: A=`$8C` while fire is released; A=`$0C` while it is held (bit 7 = 0).
  The game-over branch uses the `NewFire` edge, so a held button must be released before the next
  press restarts the game.
- **`$F085` (`ReadCX`)**: A=`$07` at rest; A=`$87` at frame 50, the VBLANK read of the frame-49
  contact. `$F27F` (`LifeInit`) reports A=3 at frame 1; `$F0C3` (`LifeStep`) reports A=2 at frame
  50, A=1 at 212, A=0 at 374.
- **`$F12E` (`LevelUp`)**: A=2 at frame 301, after 300 play frames. The passive run loses its last
  life at 374, so this is the only level-up it sees.
- **`$F106` (`SpeedWrite`)**: A=1 at level 1, A=2 at level 5. The table's level-10 entry is 3 and
  its level-15 entry is 4.
- **`$F1EB` (`BodyStart`)** 37/5, **`$F258` (`OverscanStart`)** 229/7 — the 262-line frame.
- **`$F1AA` (`HmoveApply`)** 6/36–41 and **`$F1AC` (`HmoveDone`)** 7/3 — one `HMOVE` per frame.

With the debugger open on a visible frame, `Level` is `$80`, `LevelTimerLo/Hi` are `$81/$82`,
`Lives` is `$83`, `EnemyX` is `$84`, `PlayerX` is `$86`, `Switches` is `$87`, `Invuln` is `$88`,
`FlashTimer` is `$89`, and `GameOver` is `$8A`. The three level-bar bytes are `$93–$95`; the two
life bytes are `$96–$97`; the two indicator bytes are `$98–$99`.

## Exercises

### Exercise 1: Invert the Left Switch

**Challenge:** make expert start at level 1 and novice start at level 5 — the opposite of the main
ROM. The switch read, the indicator, the speed table, and the rest of the game stay as they are.

**Hints:**
1. The decision is in `StartGame`: `LDA Switches`, `AND #$40`, then a branch. In the main ROM the
   `BEQ` goes to the level-1 path (bit 6 = 0 = B/novice); the fall-through is level 5 (A/expert).
2. Swap the two loads: the `BEQ` target should load `START_EXPERT` (5), and the fall-through
   should load `START_NOVICE` (1).
3. `StartLevelSet` reports the level that was chosen. Run with `-ld A` (expert) and expect A=1;
   run with `-ld B` (novice) and expect A=5. The level bar follows.

**Expected Result:** `ReadSWCHB` still reports the raw byte (`$FF` for A/A, `$3F` for B/B), but
`StartLevelSet` is inverted: A=1 on expert and A=5 on novice. The level bar starts at one chunk on
expert and five chunks on novice. The switch indicator still lights on A, because it shows the
switch position, not the starting level.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Three Copies

**Challenge:** make the right switch select `NUSIZ1=3` (three 8-pixel copies) on expert instead
of double width, and cap P1 at X=24–104 so all three copies stay inside the right wall.

**Hints:**
1. `NUSIZ1` bits 0–2 select the copy mode. 0 is one copy; 3 is three copies at X, X+16, and
   X+32. The main ROM's expert value is 5 (double width); change it to 3.
2. The three copies are each 8 pixels wide. At X=104 they span 104–111, 120–127, and 136–143.
   The right wall starts at X=144, so 104 is the largest safe X.
3. `ENEMY_MAX_X` is used by both `MoveEnemy` and `RespawnEnemy`. Changing the constant to 104
   caps the bounce and the respawn in one place. The left floor (`ENEMY_MIN_X=24`) stays.

**Expected Result:** `NUSIZWrite` reports A=3 on expert (`-rd A`) and A=0 on novice (`-rd B`).
The play area shows three green 8-pixel enemies at X, X+16, and X+32; at the right end the last
copy ends at X=143, just inside the wall. The life/level logic is unchanged.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Expert Level Cap *(Stretch Goal)*

**Challenge:** make the right switch cap the level at 10 on expert and 15 on novice. On expert the
ladder must stop at level 10; on novice it must still reach 15.

**Hints:**
1. Add a `LevelCap` byte. The main ROM has `$9D` free (`$9E–$D7` is also free), so put it there.
2. Recompute the cap every VBLANK from `Switches` bit 7: A (bit 7 = 1) → 10; B (bit 7 = 0) →
   15. Recomputing means a mid-game flip is picked up at the next level-up boundary.
3. In the level-up path, replace the constant 15 with `LevelCap`. Compare, increment, and compare
   again so a level at the cap stays there and a level above it (after a switch flip) is clamped
   down. The right switch keeps its main-ROM width job: expert is still `NUSIZ1=5`.
4. To see the cap without playing for 5 × 300 frames, temporarily set `LEVEL_FRAMES_LO/HI` to a
   small value in a scratch build, or use the debugger's RAM view to set `Level=9` and
   `LevelTimerLo=$02`, `LevelTimerHi=$00`. The next level-up reports A=10 on both switch
   positions. Set `Level=10` and repeat: expert stays at A=10, novice rises to A=11.

**Expected Result:** `LevelUp` reports A=10 on expert and stays at 10 on the next boundary;
`SpeedWrite` stays at 3 (the level-10 table entry). On novice, `LevelUp` still reaches 15 and
`SpeedWrite` reaches 4. A level above the cap is clamped to the cap at the next level-up. At the
cap the timer reloads but the level bar does not flash and the level beep does not play.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **The difficulty switches are two `SWCHB` bits**: bit 6 is the left/P0 switch, bit 7 the
  right/P1 switch; 0 is B/novice and 1 is A/expert. The A position reports 1 on the console and in
  Stella.
- ✅ **Sample the start level once**: `StartGame` reads the left bit and stores 1 or 5 in `Level`;
  the switch can change later without moving the ladder. Restart uses the same door.
- ✅ **Use a table for speed**: `SpeedTable[Level-1]` is 1–4 pixels per frame; level 5 is twice
  level 1, and the top levels stay at 4.
- ✅ **300 frames needs two bytes**: `$012C` is decremented low-then-high; at zero, `Level` rises
  (cap 15), the bar flashes for 30 frames, and the level beep plays.
- ✅ **`CXPPMM` bit 7 is a latch, not a distance**: both players share Y=140; read it in VBLANK,
  edge-detect it, and charge one life. Respawn on the opposite side and arm 60 frames of blinking
  invulnerability.
- ✅ **Zero lives is both a colour and a freeze**: `GameOver=1` turns `COLUBK` red and skips the
  play update; fire calls `StartGame` and starts at the switch-selected level.
- ✅ **The 192-line layout is 8 + 8 + 8 + 116 + 16 + 36**: four status zones, one 16-row sprite
  band, and one `HMOVE` for both players.

## What's Next

The game now has a pace: a starting rung, a speed that climbs, a cap, and three lives. It still
has no **surprise**. The enemy bounces on the same line every time, and every run of the same
level is identical. [Lesson 43: Random Numbers — Unpredictable Fun](/part6-game-dev/43-random-numbers)
adds a Galois LFSR, a seed that must never be zero, and an 8×8 history grid — the next ingredient
for a game that feels alive.
