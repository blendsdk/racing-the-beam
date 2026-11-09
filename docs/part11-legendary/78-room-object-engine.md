---
title: "Lesson 78: Room & Object Engine — The Adventure Architecture"
description: "Build Warren Robinett's data-driven idea in 4 KB: an 8-byte room record, a 6-byte object record, one interpreter, P0 for the player, P1 for the key and the ball for the door, collision latches for pickup, a 24-line status gauge, a 144-line room and a 262-line frame. The lesson explains why tables save ROM and logic, verifies the engine in Stella, and ships two exercises: a fifth room with a vertical exit, and a locked-door behaviour with a third object."
prev:
  text: "Part 11: Legendary Techniques"
  link: "/part11-legendary/"
next:
  text: "Part 11: Legendary Techniques"
  link: "/part11-legendary/"
---

# Lesson 78: Room & Object Engine — The Adventure Architecture

> **Part 11: Legendary Techniques** · Estimated time: 150 minutes
> **Prerequisites:** Lesson 10 (addressing modes), Lesson 11 (lookup tables), Lesson 19 (the playfield), Lesson 20 (playfield colours), Lesson 21 (the asymmetric playfield), Lesson 25 (player sprites), Lesson 26 (horizontal positioning), Lesson 29 (missiles and the ball), Lesson 31 (copies and sizes), Lesson 38 (collision detection), Lesson 41 (game states), Lesson 45 (memory management), Lesson 53 (kernel patterns), Lesson 71 (Maze Explorer)
> **You will learn:** how a whole adventure can live in two tables and one interpreter; how an 8-byte room record and a 6-byte object record describe walls, exits, keys and doors; how the engine stages a record into RAM, scans the objects and draws the room; how the TIA's P0/P1 collision latch becomes a pickup; how a behaviour flag turns a static object into a door; why a 4-line kernel buys the cycles for three dynamic objects; and how the room gauge, the frame ledger and the Stella trace make the data visible.
> **You will build:** **the engine** — a four-room adventure in a 4,096-byte ROM. Room 0 is a red antechamber with a door; room 1 is green, with a key on the floor and a door above it; room 2 is orange with a door; room 3 is blue with a second key and door. P0 is an 8×16 adventurer, P1 is the key, the ball is the door; the playfield draws the walls, and a 32-line opening in each room is the exit. The status band shows the room gauge (4, 8, 12 or 16 scanlines of green) and a gold key block. The auto-demo leaves room 0, picks the room-1 key up, carries it through the exit and stops in room 2, so the two captures show room 1 with the key on the floor and room 2 with the key carried. SELECT restarts; the joystick takes over at any time. Two complete exercise solutions add a fifth room with a vertical exit, and a locked-door behaviour with a third object.

## Introduction

Lesson 71 built the course's first room-based game: a generated maze, a 44-byte object row table, keys and enemies. It worked because the maze was small enough to generate and the objects fitted a fixed row table. An adventure is the harder version of the same problem: many rooms, each with walls, exits and objects, and the rooms are not known at build time in the original game. If every room were a separate block of code — its own walls, its own exit tests, its own key and door logic — the cartridge would be a pile of near-copies, and adding a room would mean writing another program.

*Adventure* (Atari, 1980, designed by Warren Robinett) solved that with a design that is now a standard: **the world is data**. A room is a record: a wall pattern, a colour, the rooms its exits lead to, and the start of its object list. An object is another record: a position, a graphic, a colour, a behaviour and the room that owns it. One engine reads the records, stages the current room into RAM, draws it, and interprets the objects' behaviours. The cartridge stores a description of the world and one interpreter, not a program per room. The same design is the reason *Adventure* could fit a world in 4 KB — and why it is still the reference architecture for small-room adventures.

The companion program `78-room-object-engine.asm` is that architecture in miniature. It has four rooms, six objects (four doors and two keys), one carried-object slot, and two behaviour values that mark a door as a door and a key as a key. The picture is data-driven from top to bottom: the playfield's three bytes per room are its walls and pillars; the ball's width is the door object's graphic index; the status band's green gauge is the room index; the gold block is the carry flag. The program is 4,096 bytes and 262 scanlines, and every claim in this lesson is checked against the committed ROM in Stella.

::: details TypeScript Equivalent

A room-and-object engine in TypeScript is a pair of arrays and a function that reads them. The arrays are the point; the interpreter is small enough to read in one screen.

```typescript
/** One room: the wall pattern, the colour, the exits and the object range. */
interface Room {
  pf0: number; pf1: number; pf2: number;   // the playfield wall bytes
  colour: number;                          // the TIA colour byte
  left: number | null;                     // the room to the left, or null
  right: number | null;                    // the room to the right, or null
  firstObject: number;                     // the first index in objects
  objectCount: number;
}

/** One object: a position, a graphic, a colour and a behaviour. */
interface GameObject {
  x: number; y: number;
  graphic: number;
  colour: number;
  behaviour: 'static' | 'pickup';
  room: number;
}

const rooms: Room[] = [
  { pf0: 0x10, pf1: 0x81, pf2: 0x00, colour: 0x46, left: null, right: 1, firstObject: 0, objectCount: 1 },
  { pf0: 0x10, pf1: 0x00, pf2: 0x18, colour: 0xc6, left: 0, right: 2, firstObject: 1, objectCount: 2 },
  { pf0: 0x10, pf1: 0x24, pf2: 0x00, colour: 0x26, left: 1, right: 3, firstObject: 3, objectCount: 1 },
  { pf0: 0x10, pf1: 0xc3, pf2: 0x00, colour: 0x86, left: 2, right: null, firstObject: 4, objectCount: 2 },
];

const objects: GameObject[] = [
  { x: 128, y: 40, graphic: 1, colour: 0x36, behaviour: 'static', room: 0 },
  { x: 112, y: 52, graphic: 0, colour: 0x1a, behaviour: 'pickup', room: 1 },
  { x: 128, y: 40, graphic: 1, colour: 0x36, behaviour: 'static', room: 1 },
  { x: 112, y: 48, graphic: 1, colour: 0x36, behaviour: 'static', room: 2 },
  { x: 96,  y: 48, graphic: 0, colour: 0x1a, behaviour: 'pickup', room: 3 },
  { x: 128, y: 40, graphic: 1, colour: 0x36, behaviour: 'static', room: 3 },
];

type State = { room: number; player: { x: number; y: number }; carrying: GameObject | null };

/** One frame: read the room, find its objects, draw them. */
function frame(state: State): void {
  const room = rooms[state.room];
  setPlayfield(room.pf0, room.pf1, room.pf2, room.colour); // three TIA writes
  const owned = objects.slice(room.firstObject, room.firstObject + room.objectCount);
  for (const object of owned) {
    if (object.behaviour === 'pickup' && !state.carrying) drawPlayer1(object);
    if (object.behaviour === 'static') drawBall(object);
  }
  drawPlayer0(state.player);
  if (state.carrying) drawPlayer1({ ...state.carrying, x: state.player.x, y: state.player.y - 16 });
}
```

Two places where the analogy breaks, and both are the lesson.

**There is no frame buffer, and the arrays are not pixels.** `frame()` in TypeScript would draw to a canvas that keeps its pixels until the next call. The 2600 has no canvas: the playfield pattern, the player graphics and the ball are TIA registers, and the room band re-reads them on every scanline. The "arrays" are read once per frame in the vertical blank, staged into a handful of RAM bytes, and then the beam draws the room while the CPU counts rows. The data model is the same; the drawing model is a race against the beam.

**The collision is hardware, not geometry.** In TypeScript you would compare rectangles. The 2600 latches a collision when two objects' pixels overlap during a frame; the engine reads `CXPPMM` bit 7 for P0/P1 and `CXP0FB` bit 6 for P0/ball. That latch *is* the pickup test, and it is what makes the key respond to the visible pixels rather than to a bounding box. The exercise's locked door uses the same latch, with a behaviour flag deciding whether the collision opens the door or stops the player.

:::

## Theory

### Section 1: Adventure, 1980 — the world as data

*Adventure* is the game this lesson is named after, and the historical claim is narrow enough to state exactly. Warren Robinett designed it at Atari; it was released in 1980 for the Atari 2600. It is widely credited as the first action-adventure video game, and it is the game where a room could contain an object, an object could be carried, and the world could be larger than the screen without a separate program for every screen. The design that made that possible is the one this lesson rebuilds: **rooms and objects are records; one engine interprets them.**

Two historical details belong in a course about the platform, and both are easy to get wrong. First, the original's rooms are not stored as pictures. A room is a small record: its walls (a playfield pattern), its colour, its exits, and a pointer into an object list. The same records are used for every room, so a new room costs a record, not a routine.

Second, the game is famous for what is usually called the first video-game Easter egg: a hidden message that a player can reach by finding an undocumented room. The story matters here because it is a *data* story — the hidden room is another room record in the same engine — but the message and the original's room maps are copyrighted, and this lesson does not reproduce them. The engine in `78-room-object-engine.asm` is a new four-room world built from the same architecture, not a copy of the 1980 map.

The claim discipline for the rest of the lesson is simple:

- **Documented** (the book *Racing the Beam* and the references in `atari-2600-expert`): Adventure's release, designer and data-driven design; the first Easter egg's existence.
- **Observed** (Stella, the trace and the captures): every screen state, every collision, the frame's 262 lines and the two captures' room layouts.
- **Derived** (arithmetic on the TIA and the code): the 8-byte and 6-byte records, the 4-line row budget, the status gauge's 4-line steps, and the frame's 3 + 37 + 192 + 30 split.

::: tip Why "data-driven" is not a buzzword here
On a modern machine, a table-driven engine saves typing. On the 2600 it saves the thing that is actually scarce: **ROM and cycles**. A per-room program would repeat the kernel's row loop, the exit tests and the object drawing for every room. The table version stores 8 bytes per room and 6 bytes per object, and the interpreter is written once. Adding a room is one more record; the kernel does not change. That is the whole argument, and the exercise proves it by adding a fifth room without touching the visible loop.
:::

### Section 2: The room record — eight bytes

The engine's room table is an array of eight-byte records. The record is the room:

| Offset | Field | Meaning in this ROM |
|---|---|---|
| +0 | `PF0` | the left wall pattern's first byte; `$10` is a four-pixel side wall at the screen edge |
| +1 | `PF1` | the next eight playfield chunks; pillars and interior walls |
| +2 | `PF2` | the last eight chunks before the mirror; the centre pillars |
| +3 | colour | the playfield colour, and the base colour of the door's corridor |
| +4 | left exit | the room to the left, or `$FF` for a solid end |
| +5 | right exit | the room to the right, or `$FF` for a solid end |
| +6 | first object | the index of the room's first object in the object table |
| +7 | object count | how many consecutive objects belong to this room |

The table in the source:

```asm
RoomTable:
    ; room 0: side walls + pillars at blocks 4 and 11
    !byte $10, $81, $00, C_WALL0, $FF, $01, 0, 1
    ; room 1: side walls + a central pair at blocks 15 and 16
    !byte $10, $00, $18, C_WALL1, $00, $02, 1, 2
    ; room 2: side walls + pillars at blocks 6 and 9
    !byte $10, $24, $00, C_WALL2, $01, $03, 3, 1
    ; room 3: side walls + a four-block band at blocks 4,5,10,11
    !byte $10, $C3, $00, C_WALL3, $02, $FF, 4, 2
```

Read the bytes across one record and then down a column. Down the colour column the rooms are red (`$46`, hue 4), green (`$C6`, hue 12), orange (`$26`, hue 2) and blue (`$86`, hue 8): four rooms you can tell apart without reading a number. Down the exit columns, room 0's only exit is right, room 1 connects 0 and 2, room 2 connects 1 and 3, and room 3's only exit is left: a corridor with two ends.

The record is eight bytes because the 6502 has an easy `×2`, and `×8` is three shifts. `LoadRoom` computes `Room × 8` by shifting three times and uses the result as the index. The object count and first index are the room's slice of the object table; the engine never searches the whole table for a room.

::: tip The playfield is a wall, not a picture
`PF0 = $10` draws a four-pixel block at the left edge, and `CTRLPF`'s reflect bit mirrors it to the right edge. That is the room's side wall. `PF1` and `PF2` add four-pixel pillars inside the room. The pattern is constant vertically, so it reads as a wall with columns rather than a drawn map. The exit corridor is the exception: the kernel zeroes all three playfield bytes for rows 10-17, and the wall opens into a 32-line doorway that the player can walk through.
:::

### Section 3: The object record — six bytes

The object table is an array of six-byte records, grouped by room:

| Offset | Field | Meaning in this ROM |
|---|---|---|
| +0 | x | the object's left edge, 0-152 (the sprite is 8 pixels wide) |
| +1 | y | the object's top edge, a multiple of 4 (the room's row height) |
| +2 | graphic | for a pickup, a sprite-table index; for a static object, the ball-size index |
| +3 | colour | the object's colour; P1 uses it directly, the door uses it in the corridor |
| +4 | behaviour | `0` static, `1` pickup |
| +5 | room | the room that owns the object |

The table:

```asm
ObjectTable:
    ; room 0: the first door
    !byte 128, 40, GFX_DOOR, C_DOOR, BEH_STATIC, 0
    ; room 1: the key and its door
    !byte 112, 52, GFX_KEY,  C_KEY,  BEH_PICKUP, 1
    !byte 128, 40, GFX_DOOR, C_DOOR, BEH_STATIC, 1
    ; room 2: the door ahead of the demo
    !byte 112, 48, GFX_DOOR, C_DOOR, BEH_STATIC, 2
    ; room 3: the second key and its door
    !byte 96,  48, GFX_KEY,  C_KEY,  BEH_PICKUP, 3
    !byte 128, 40, GFX_DOOR, C_DOOR, BEH_STATIC, 3
```

The record is six bytes, and the 6502 has no multiply, so a second small table does the index arithmetic: `ObjectBase` holds `0, 6, 12, 18, 24, 30`, and `LoadRoom` uses `ObjectBase[ObjIndex]` as the record's offset. That is the same trick as the room table, one level down.

The behaviour byte is the interpreter's switch. In the main ROM it has two values:

- **`BEH_STATIC` (0)**: draw the ball at the record's position and do nothing else. The door is part of the room's scenery.
- **`BEH_PICKUP` (1)**: draw P1 at the record's position; when the TIA latches P0 over P1, the object becomes the carried object.

The drawable assignment is the TIA constraint made explicit. P0 is always the player. P1 is the one pickup the room can show. The ball is the one static object the room can show. That is why each room has at most one key and one door: the engine has two non-player drawables, and a room with two keys or two doors would need a multiplexer the lesson does not build. The exercise's third object (a gem) is still one pickup, so it fits the same slot; the exercise's locked door is still one static object, so it fits the ball.

### Section 4: The interpreter — one loop, pointed at a record

The engine is not a state machine per room. It is one loop with a pointer:

1. **VBLANK** does everything that changes between frames. It reads SELECT, decides whether the auto-demo or the joystick is in charge, reads the previous frame's collision latches, applies or reverts the player's move, checks the room's exit bytes, picks a key up if P0/P1 collided, loads the current room's record, scans its objects, sets the ball's size, and positions P0/P1/ball with the Lesson 29 coarse-plus-`HMOVE` routine.
2. **The status band** draws the room gauge and the key block from two missiles. It knows only `Room` and `KeyHeld`; it does not read the room table.
3. **The room band** draws the current room's playfield and its three dynamic objects. It knows only the staged wall bytes, the object rows and the graphics offsets; it does not know which room it is drawing.
4. **The lower band** is the floor.
5. **Overscan** finishes the frame and jumps back.

`LoadRoom` is the whole of the "data-driven" claim in about a hundred bytes:

```asm
LoadRoom:
    LDA Room
    ASL
    ASL
    ASL
    TAX                     ; X = Room * 8
    LDA RoomTable+0,X
    STA WallPF0
    ...
    LDA RoomTable+6,X
    STA FirstObj
    LDA RoomTable+7,X
    STA ObjCount
    ; ... scan the objects ...
```

The engine copies the record's fields into RAM (`WallPF0/1/2`, `WallColor`, `LeftExit`, `RightExit`, `FirstObj`, `ObjCount`), because the visible kernel needs them at a known address without paying for an indexed table read per row. The object scan then walks `FirstObj .. FirstObj + ObjCount - 1`, checks the object's room byte, and stages the one pickup and the one static object into `Key*` and `Door*` variables. The room byte in the object record is a second check; it lets the scan skip a record that does not belong, while the first/count slice keeps the scan short.

::: tip Why the record is copied at all
The kernel is a cycle budget, not a place for table arithmetic. `LoadRoom` runs in the vertical blank, where a few hundred cycles are free; the room band runs on the beam, where every cycle is visible. Staging the room's eight bytes and the object's six bytes into fixed RAM addresses is the classic split: do the indexing while the picture is blank, then read fixed addresses while the picture is being drawn. The same reason appears in Lesson 71's object row table and Lesson 76's ring arrays.
:::

### Section 5: The screen — three bands and a four-line kernel

The visible area is 192 lines in three bands:

| Band | Lines | Rows | What it draws |
|---|---|---|---|
| status | 24 | 6 rows × 4 | the green room gauge (M0) and the gold key block (M1) |
| room | 144 | 36 rows × 4 | the playfield walls, P0, P1, the ball door |
| lower | 24 | 6 rows × 4 | a floor colour and a three-line full-width edge line |

The room band is the lesson's main kernel choice. The default course kernel is two lines per row; this engine uses **four**. The reason is the compute: each row must decide three graphics values (P0, P1 and the ball enable) and apply the playfield's gap and door-colour side effects. A four-line row gives 295 cycles for that work; a two-line row gives 143, and the branchy object compares plus the side effects do not fit in one line. The price is vertical resolution: the player, the key and the door move in four-scanline steps. That is in character with the 1980 game, whose objects also move in coarse steps, and it keeps the engine's code readable.

The row's four lines are also the four compute slots:

| Line | Store | Compute after the store |
|---|---|---|
| 1 | `GRP0`, `GRP1`, `ENABL` | save the row's values; `RoomRow++`; compute P0 for the next row |
| 2 | the same three | compute P1 for the next row |
| 3 | the same three | compute the ball enable for the next row |
| 4 | the same three | apply the next row's playfield/colour side effects; load the next row's values |

The split matters because the whole compute is about 100 cycles and one scanline is 76. The four-line row is not a luxury; it is the budget that makes the three-object compute fit. The `CurP0/CurP1/CurBL` bytes hold the values being drawn while the next row is computed.

The playfield's two side effects are the exit gap and the door colour:

```asm
RowEffects:
    LDA RoomRow
    CMP #EXIT_TOP
    BEQ .reGap              ; rows 10-17: zero PF0/PF1/PF2
    CMP #(EXIT_BOTTOM + 1)
    BEQ .reRestore          ; row 18: restore the room's pattern
    RTS
```

The gap is a 32-line hole in the walls. The player can leave the room only when its four-row body is fully inside the corridor (`PlayerRow` in 10..14); the exit bytes decide which room comes next. The door's colour is set for the whole corridor rather than row by row: the corridor has no playfield, so `COLUPF` colours only the ball there. The wall colour is restored on the row after the corridor, and the boundary line itself can show a one-scanline seam while the writes land; the steady rows on either side are clean.

The **top seam** is the same trade at the status/room boundary. The room setup (the wall colours, the playfield, the player/key colours) runs on the status band's last line after its pixel 0; the next line, the room's first, is fully the room. The setup's `COLUPF` and PF writes can show on the right part of that last status line, so a capture can show a one-line transition there. `COLUP0` is deliberately written last, after the PF writes, so room 4's gauge keeps its status green for its twentieth line; the steady status rows are clean.

The status band's gauge is the room index made visible: M0 is enabled for rows 1 through `Room + 1`, four scanlines per room step, so room 0 is 4 lines, room 1 is 8, room 2 is 12 and room 3 is 16. M1 is a 4×8 gold block, enabled for rows 1-2 while the carried-object flag is set. Both are missiles, independent of the P0/P1 graphics the room band uses. The status band is 24 lines, and the largest gauge (room 4 in the first exercise) is 20 lines, still inside it. The last status line's missile pixel is drawn: the missiles are cleared at the room setup, after that line's pixel 0, not on the line itself. The status missiles are positioned once at power-on; their fine registers are zeroed in the first VBLANK before the per-frame HMOVE, so the HMOVE's five-register apply leaves HMM0/HMM1 at zero. The committed captures show the gauge at x≈21 and the key block at x≈41; those are the 20/40 targets plus the missile output delay.

::: tip The status band's first line
The status band's first line is line 37, so its enables must be in place before the beam reaches pixel 0. The band's colours and clear playfield are latched in VBLANK; line 0 stores **zero** to both missiles at cycle 13-18, before the 22.67-cycle deadline, and computes row 1's M0 on the same line. M1 is computed on line 1, and the loop enters with row 1's values after line 4. Row 0 is therefore four blank lines, not a head start for the gauge.
:::

### Section 6: Collision, behaviour, and the carried object

The TIA's collision latches are the engine's interaction layer. Two of them matter:

- **`CXPPMM` bit 7**: P0 over P1. When the player's pixels overlap the key's pixels, the latch is set. The engine reads it in the next vertical blank and sets `KeyHeld`. The key's record is then ignored; the key is drawn four rows above the player, so its `x` follows the player and its `y` is the player's `y - 16`. The collision is the pickup, and it is hardware, not a rectangle test.
- **`CXP0FB` bit 6**: P0 over the ball. In the main ROM it is unused. In the second exercise it is the locked door: without the carried object the collision reverts the player's last move (the same `PrevX/PrevRow` dance as the wall); with the carried object it sets `DoorOpen` and the ball disappears for the rest of the room visit.

The wall collision is the other side of the same mechanism. `CXP0FB` bit 7 is P0 over the playfield; if it is set, the last move walked into a wall and the engine restores `PrevX/PrevRow`. The corridor has no playfield, so the exit itself never latches. The one-frame overlap before the revert is normal: the TIA reports the picture that was just drawn, so the engine learns about the wall on the next blank.

The carried object is one object, not a list. `KeyHeld` is a flag, `KeyGfxOffset` is the carried graphic's table offset and `KeyColor` is its colour. In the main ROM the carried object is always the key (`offset 0`, gold). The second exercise changes the pickup to a gem (`offset 4`, violet) and the carried path uses the stored offset and colour, so the engine can carry a different object without changing the draw code.

### Section 7: The frame ledger

The frame is the course skeleton: 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262 lines. The visible body is 6 status rows + 36 room rows + 6 lower rows, all four scanlines each. The measured trace, with the convention that a checkpoint's line/cycle is the instruction's start line and start cycle and cycle 0 is the first instruction after the `WSYNC` release:

| Checkpoint | Line/cycle | What it is |
|---|---|---|
| `StartFrame` | 259/3 | the first VSYNC line |
| `VblankStart` | 0/5 | the first VBLANK line |
| `BodyStart` | 37/5 | visible line 0 |
| `RoomStart` | 60/63 | the status band's last line; the first room line follows at 61/0 |
| `LowerStart` | 209/13 | the lower loop's first `WSYNC`; the lower band's first line is 205/0 |
| `OverscanStart` | 229/6 | the `STA VBLANK` that blanks the first overscan line; its store completes at 229/9 |

The visible body is 229 - 37 = 192 lines, and 3 + 37 + 192 + 30 = 262. The trace is the authority for these numbers; the source's comments repeat them so a reader can set the same breakpoints. The `RoomStart` value is the status band's last line because the first room line's stores have to be ready at cycle 0 of line 61; the `LowerStart` value is the lower loop's first `WSYNC`, four lines after the band's first line.

The frame's 262 lines are also the reason the two capture states are stable: the room band's 36 rows are exactly four lines each, and the status and lower bands are exactly six rows each. A single overrun would make the picture roll; the trace shows the same line numbers on every frame, including the room changes and the key pickup.

### Section 8: The auto-demo and the two states

The demo is a deterministic walk, not a random one. It starts in room 0 at `x=145`, `row=13`, and moves right one pixel per frame. Counting frames from power-on, the state model is:

| Frame | Event | Room | `PlayerX` | Carry |
|---|---|---|---|---|
| 1 | the first auto move | 0 | 146 | no |
| 8 | room 0's right exit; enter room 1 at the left edge | 1 | 4 | no |
| 96 | the 2-second capture | 1 | 92 | no; the key is on the floor at x=112 |
| 113 | P0/P1 collision: pick the key up at x=109 | 1 | 109 | yes |
| 156 | room 1's right exit | 1 | 152 | yes |
| 157 | enter room 2 at the left edge | 2 | 4 | yes |
| 201 | the middle of the room-2 walk | 2 | 48 | yes; the key rides above P0 |
| 249 | the demo's stop at room 2, x=96; the 5-second capture | 2 | 96 | yes |

The two captures are the two ends of that walk: room 1 at 2 s with the key still on the floor (room gauge 8 lines, key block off), and room 2 at 5 s with the key carried (gauge 12 lines, key block on, the door ahead). The model's frames are game frames; the wall-clock waits include Stella's start-up, which is why the captures are described as "about 2 and 5 seconds" rather than as exact frame numbers.

The joystick's four direction bits (SWCHA bits 7/6/5/4, active low) take over the moment any of them is pressed. The vertical move is one room row per frame (four scanlines), the horizontal move one pixel per frame. SELECT restarts the game: room 0, x=145, row 13, no key, the demo running again. The wall collision, the exit corridor and the carried key all reset with it.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson78.bin \
  lessons/part11-legendary/78-room-object-engine/78-room-object-engine.asm
stella build/lesson78.bin
```

The two exercise solutions sit beside the lesson source and are complete 4,096-byte ROMs:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part11-legendary/78-room-object-engine/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part11-legendary/78-room-object-engine/exercise-02-solution.asm
```

### Full Source

The complete annotated source, reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 78: Room & Object Engine — The Adventure Architecture
; =============================================================================
; Part 11: Legendary Techniques
;
; What this program does:
;   "the engine": a four-room adventure.  The screen is 192 scanlines in
;   three bands:
;
;     visible   0- 23    the status band   24 lines   room gauge + key block
;     visible  24-167    the room         144 lines   36 rows x 4 lines
;     visible 168-191    the lower band    24 lines   the floor
;                       ----------------
;                       24 + 144 + 24 = 192
;
;   THE PICTURE IS DATA.  There is no per-room code.  Two tables in the
;   cartridge describe the whole world:
;
;     RoomTable    one 8-byte record per room:
;                    +0 PF0        the left wall pattern's first byte
;                    +1 PF1
;                    +2 PF2
;                    +3 colour     the playfield (and the door's base) colour
;                    +4 left exit  the room to the left, or $FF for none
;                    +5 right exit the room to the right, or $FF for none
;                    +6 first object index into ObjectTable
;                    +7 object count
;
;     ObjectTable  one 6-byte record per object:
;                    +0 x          the object's left edge, 0..152
;                    +1 y          the object's top edge, a multiple of 4
;                    +2 graphic    a sprite-table index or a ball size
;                    +3 colour
;                    +4 behaviour  0 = static, 1 = pickup
;                    +5 room       the room that owns the object
;
;   The engine reads a record, stages its fields into RAM during VBLANK,
;   and the same kernel draws every room.  Changing a byte in a table
;   changes the game; adding a room is one more record (Exercise 1 adds a
;   fifth room and a second, vertical exit).  This is Warren Robinett's
;   Adventure architecture in miniature: the cartridge stores a description
;   of the world and one interpreter, not a program per room.
;
;   THE PLAYER IS P0, THE KEY IS P1, THE DOOR IS THE BALL.  P0 is an 8x16
;   adventurer; P1 is an 8x16 key that sits on the floor until the player
;   touches it.  The TIA's P0/P1 collision latch (CXPPMM bit 7) is the
;   pickup: the hardware does the overlap test, the engine changes the
;   state.  Once carried, the key is drawn four 4-line rows above the
;   player, so its x follows the player and its y sits on the player's
;   head.  The ball is a rectangle, not a bitmap: its width comes from
;   CTRLPF bits 4-5 and its height from the rows the kernel enables it.
;   The door's record is a static object; its colour is applied for the
;   whole exit corridor, which has no playfield at all, so COLUPF colours
;   only the ball.  The wall colour is restored on the row after the
;   corridor, and the boundary line can show a one-scanline seam.
;
;   THE ROOM IS 36 ROWS OF FOUR SCANLINES.  The course's default is a
;   2-line kernel; this engine pays for its three dynamic objects with
;   4-line rows.  That gives 295 cycles per row for the object compare
;   and the playfield bookkeeping, and the vertical resolution is four
;   scanlines, which is the price.  Adventure's own objects move in coarse
;   steps, so the trade is in character.  The status and lower bands use
;   the same 4-line rhythm: 6 + 36 + 6 = 48 rows x 4 = 192 lines.
;
;   THE EXIT IS A HOLE IN THE WALL.  Every room's pattern has a left/right
;   side wall (PF0 = $10, mirrored by REFLECT).  Rows 10-17 of every room
;   are the exit corridor: the kernel zeroes PF0/PF1/PF2 there, so the
;   side walls, the pillars and the door's background all open into a
;   32-line gap.  The player walks out at x=152 (or x=0) only when its
;   4-row body is fully inside the corridor.  The room record's exit
;   bytes decide what happens next; $FF is a solid end.
;
;   THE STATUS BAND SHOWS THE ROOM AND THE KEY.  M0 is the room gauge:
;   a 2-pixel bar whose height is 4 x (room index + 1) scanlines, so room
;   0 is 4 lines, room 1 is 8, room 2 is 12 and room 3 is 16.  M1 is the
;   key block: a 4x8 block, lit while the key is carried.  Both are
;   positioned once at power-on; their fine registers are zeroed in the
;   first VBLANK before the per-frame HMOVE (which applies all five HM
;   registers), so the status missiles never drift.
;
;   THE AUTO-DEMO walks P0 right from room 0 at x=145, row 13.  It leaves
;   room 0 at x=152, crosses room 1, picks the room-1 key up at x=109,
;   carries it through room 1's right exit, and stops at x=96 in room 2.
;   Counting frames from power-on: room 0 for frames 1-7, room 1 for
;   8-156, room 2 from 157.  The key is on the floor from frames 8-112 and
;   carried from 113.  The two captures are room 1 at 2 s (room gauge 8
;   lines, key on the floor) and room 2 at 5 s (gauge 12 lines, key block
;   lit, key carried, the door visible ahead).  Any joystick direction
;   cancels the demo and hands P0 to the reader; SELECT restarts the whole
;   state.
;
;   THE FRAME (NTSC): 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262.
;   The visible body is six status rows, thirty-six room rows and six
;   lower rows of four scanlines each.  The checkpoints in the source are
;   the line/cycle anchors the lesson's ledger uses:
;
;     StartFrame      259/3    the first VSYNC line
;     VblankStart       0/5    the first VBLANK line
;     BodyStart        37/5    visible line 0
;     RoomStart        60/63   the status band's last line; the room's first
;                              line follows at 61/0
;     LowerStart      209/13   the lower loop's first WSYNC; the lower band's
;                              first line is 205/0
;     OverscanStart   229/6    the STA VBLANK that blanks the first overscan
;                              line (its store completes at 229/9)
;
;   RAM map (the exact map; +clean_start zeroes every byte):
;     $80 Room         0..3, the current room index
;     $81 PlayerX      P0's left edge, 0..152
;     $82 PlayerRow    P0's top row, 0..32 (four scanlines per row)
;     $83 PrevX        the position before the last move (wall collision)
;     $84 PrevRow
;     $85 KeyHeld      1 while the key is carried
;     $86 KeyX         P1's left edge (or the floor key's)
;     $87 KeyRow       P1's top row
;     $88 KeyGfxOffset the carried/floor key's graphic * 4
;     $89 KeyOn        1 if P1 has something to draw
;     $8A DoorX        the ball's left edge
;     $8B DoorRow      the ball's top row
;     $8C DoorGfx      the ball-size index
;     $8D DoorOn       1 if the ball is enabled
;     $8E DoorColor    the door's COLUPF colour
;     $8F KeyColor     P1's COLUP1 colour
;     $90 WallPF0      the room's staged playfield bytes
;     $91 WallPF1
;     $92 WallPF2
;     $93 WallColor
;     $94 LeftExit     $FF = none
;     $95 RightExit    $FF = none
;     $96 FirstObj     the room's first object index
;     $97 ObjCount
;     $98 PrevSelect   SELECT edge latch
;     $99 AutoDemo     1 until a joystick direction is pressed
;     $9A DemoDone     1 once the scripted walk has stopped
;     $9B FrameLo      frame counter, one increment per frame
;     $9C FrameHi
;     $9D RoomRow      the room kernel's row counter
;     $9E StatusRow    the status kernel's row counter
;     $9F TmpP0        the row compute's three results
;     $A0 TmpP1
;     $A1 TmpBL
;     $A2 Tmp          scratch
;     $A3 TmpCount     the object scan's counter
;     $A4 ObjIndex     the object scan's index
;     $A5 TmpM0        the status compute's two enables
;     $A6 TmpM1
;     $A7 CurP0        the room row's held graphics values
;     $A8 CurP1
;     $A9 CurBL
;     $AA CurM0        the status row's held enables
;     $AB CurM1
;     $AC-$F7          free (76 bytes)
;     $F8-$FF          the stack (the deepest call is one level)
;
; Build: acme -f plain -o build/lesson78.bin \
;        lessons/part11-legendary/78-room-object-engine/78-room-object-engine.asm
; Run:   stella build/lesson78.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK (Lesson 15)
OVERSCAN_TIMER = 36      ; 30-line overscan (Lesson 15)

STATUS_ROWS    = 6       ; 6 x 4 = 24 visible lines
ROOM_ROWS      = 36      ; 36 x 4 = 144 visible lines
LOWER_ROWS     = 6       ; 6 x 4 = 24 visible lines
ROW_LINES      = 4       ; one row is four scanlines
VISIBLE_LINES  = (STATUS_ROWS + ROOM_ROWS + LOWER_ROWS) * ROW_LINES

; The exit corridor, in room rows.  The room's PF is zero from EXIT_TOP
; through EXIT_BOTTOM, so the 32-line opening is a hole in the side walls.
EXIT_TOP       = 10
EXIT_BOTTOM    = 17
EXIT_MIN_ROW   = EXIT_TOP          ; the player's 4-row body must be inside
EXIT_MAX_ROW   = EXIT_BOTTOM - 3   ; row + 3 <= EXIT_BOTTOM

PLAYER_MIN_X   = 0
PLAYER_MAX_X   = 152                 ; 160 - 8
PLAYER_MIN_ROW = 0
PLAYER_MAX_ROW = 32                  ; 32 + 3 = 35, the last room row

POS_BIAS       = 3                   ; the Lesson 26 player output delay
DOOR_BIAS      = 3                   ; calibrated after the first Stella run

; Object record offsets (six bytes per record).
OBJ_X          = 0
OBJ_Y          = 1
OBJ_GFX        = 2
OBJ_COLOR      = 3
OBJ_BEH        = 4
OBJ_ROOM       = 5
OBJ_SIZE       = 6
OBJ_COUNT      = 6                   ; six objects in the main ROM

; Behaviours the interpreter understands.
BEH_STATIC     = 0                   ; a door: draw the ball, no state change
BEH_PICKUP     = 1                   ; a key: P0/P1 collision picks it up

; Object graphics: four bytes per graphic, drawn on four scanlines each.
GFX_KEY        = 0
GFX_DOOR       = 1                   ; the ball's 8-pixel size index

; Colours (TIA %HHHHLLL0).
C_PLAYER       = $9A     ; P0: light blue
C_KEY          = $1A     ; P1: gold
C_DOOR         = $36     ; the door: brown-red
C_STATUS_M0    = $C8     ; the room gauge: green
C_STATUS_M1    = $1A     ; the key block: gold
C_FLOOR        = $02     ; the lower band: very dark grey

; Room wall colours.
C_WALL0        = $46     ; red (hue 4)
C_WALL1        = $C6     ; green
C_WALL2        = $26     ; orange
C_WALL3        = $86     ; blue

; The band arithmetic is a build-time assertion, not a comment.
!if (STATUS_ROWS + ROOM_ROWS + LOWER_ROWS) * ROW_LINES != 192 {
    !error "the three bands must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$AB; +clean_start zeroes every byte)
; =============================================================================
Room         = $80   ; the current room index, 0..3
PlayerX      = $81   ; P0's left edge, 0..152
PlayerRow    = $82   ; P0's top row, 0..32
PrevX        = $83   ; the position before the last move
PrevRow      = $84
KeyHeld      = $85   ; 1 while the key is carried
KeyX         = $86   ; P1's left edge
KeyRow       = $87   ; P1's top row
KeyGfxOffset = $88   ; the key's graphic table offset (index * 4)
KeyOn        = $89   ; 1 if P1 has a graphic to draw
DoorX        = $8A   ; the ball's left edge
DoorRow      = $8B   ; the ball's top row
DoorGfx      = $8C   ; the ball-size index
DoorOn       = $8D   ; 1 if the ball is enabled
DoorColor    = $8E   ; the door's own colour
KeyColor     = $8F   ; P1's colour
WallPF0      = $90   ; the room's staged playfield pattern
WallPF1      = $91
WallPF2      = $92
WallColor    = $93
LeftExit     = $94   ; $FF = no left exit
RightExit    = $95   ; $FF = no right exit
FirstObj     = $96   ; the room's first object index
ObjCount     = $97
PrevSelect   = $98   ; SELECT edge latch
AutoDemo     = $99   ; 1 until the reader touches the joystick
DemoDone     = $9A   ; 1 once the scripted walk has stopped
FrameLo      = $9B   ; frame counter, one increment per frame
FrameHi      = $9C
RoomRow      = $9D   ; the room kernel's row counter, 0..35
StatusRow    = $9E   ; the status kernel's row counter, 0..5
TmpP0        = $9F   ; the row compute's three results
TmpP1        = $A0
TmpBL        = $A1
Tmp          = $A2   ; scratch
TmpCount     = $A3   ; the object scan's counter
ObjIndex     = $A4   ; the object scan's index
TmpM0        = $A5   ; the status compute's two enables
TmpM1        = $A6
CurP0        = $A7   ; the values being held on the current room row
CurP1        = $A8
CurBL        = $A9
CurM0        = $AA   ; the status band's two enables for the current row
CurM1        = $AB
;
; $AC-$F7 are free (76 bytes).  The stack lives at $F8-$FF; the deepest
; call is LoadRoom or ComputeP0, one level, two bytes.

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
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA COLUBK              ; black until the first band writes

    LDA #$10
    STA NUSIZ0              ; M0 is 2 pixels wide; P0 is one copy
    LDA #$20
    STA NUSIZ1              ; M1 is 4 pixels wide; P1 is one copy
    LDA #$01
    STA CTRLPF              ; REFLECT the playfield; a 1-pixel ball
    LDA #C_STATUS_M0
    STA COLUP0              ; the status gauge's colour
    LDA #C_STATUS_M1
    STA COLUP1              ; the status key block's colour

    LDA #$01
    STA AutoDemo
    LDA #$00
    STA DemoDone
    STA PrevSelect
    STA FrameLo
    STA FrameHi
    STA KeyHeld
    JSR ResetGame

; --- position the two status missiles once -----------------------------------
; M0 and M1 are fixed objects: their coarse positions are strobed here and
; their fine registers are zeroed in the first VBLANK, before the per-frame
; HMOVE (which applies all five HM registers), so the status missiles cannot
; drift.
    LDA #(20 + POS_BIAS)
    JSR SetCoarseM0
    LDA #(40 + POS_BIAS)
    JSR SetCoarseM1
    STA WSYNC
    STA HMOVE

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    INC FrameLo
    BNE .frameHiDone
    INC FrameHi
.frameHiDone:

; -----------------------------------------------------------------------------
; 1. SELECT — restart the adventure
; -----------------------------------------------------------------------------
; SELECT is SWCHB bit 1, active low.  The edge latch makes it one reset per
; press: the demo, the room, the key and the player all return to power-on.
    LDA SWCHB
    AND #$02
    BNE .selectReleased
    LDA PrevSelect
    BNE .selectDone
    LDA #$01
    STA PrevSelect
    JSR ResetGame
    JMP .selectDone
.selectReleased:
    LDA #$00
    STA PrevSelect
.selectDone:

; -----------------------------------------------------------------------------
; 2. INPUT — any joystick direction surrenders the auto-demo
; -----------------------------------------------------------------------------
; SWCHA bits 7,6,5,4 are P0 right, left, down, up, all active low.  If any
; is pressed the scripted walk stops for good; SELECT starts it again.
    LDA SWCHA
    AND #$F0
    CMP #$F0
    BEQ .noManual
    LDA #$00
    STA AutoDemo
.noManual:

; -----------------------------------------------------------------------------
; 3. WALL COLLISION — the previous frame's P0/PF latch, tested and undone
; -----------------------------------------------------------------------------
; The TIA latches P0-over-playfield in CXP0FB bit 7.  The latch describes the
; picture that was just drawn; if it is set, the last move walked into a wall,
; so the player returns to PrevX/PrevRow.  The corridor is zeroed playfield,
; so the exit itself never collides.
    LDA CXP0FB
    AND #$80
    BEQ .noWall
    LDA PrevX
    STA PlayerX
    LDA PrevRow
    STA PlayerRow
.noWall:

    LDA PlayerX
    STA PrevX
    LDA PlayerRow
    STA PrevRow

; -----------------------------------------------------------------------------
; 4. MOVE — the scripted walk, or the joystick
; -----------------------------------------------------------------------------
    LDA AutoDemo
    BEQ .manual
    LDA DemoDone
    BNE .moved
    LDA Room
    CMP #2
    BCC .autoRight
    LDA PlayerX
    CMP #96
    BCS .autoStop
.autoRight:
    JMP .moveRight
.autoStop:
    LDA #$01
    STA DemoDone
    JMP .moved

.manual:
    LDA SWCHA
    AND #$40                ; left?
    BNE .manualRight
    LDA PlayerX
    BNE .decX
    JSR TryLeftExit
    JMP .manualY
.decX:
    DEC PlayerX
    JMP .manualY
.manualRight:
    LDA SWCHA
    AND #$80                ; right?
    BNE .manualY
    LDA PlayerX
    CMP #PLAYER_MAX_X
    BNE .incX
    JSR TryRightExit
    JMP .manualY
.incX:
    INC PlayerX
    JMP .manualY

.manualY:
    LDA SWCHA
    AND #$20                ; down?
    BNE .manualUp
    LDA PlayerRow
    CMP #PLAYER_MAX_ROW
    BEQ .moved
    INC PlayerRow
    JMP .moved
.manualUp:
    LDA SWCHA
    AND #$10                ; up?
    BNE .moved
    LDA PlayerRow
    BEQ .moved
    DEC PlayerRow
    JMP .moved

.moveRight:
    LDA PlayerX
    CMP #PLAYER_MAX_X
    BNE .incX2
    JSR TryRightExit
    JMP .moved
.incX2:
    INC PlayerX
    JMP .moved
.moved:

; -----------------------------------------------------------------------------
; 5. PICKUP — the hardware's P0/P1 latch picks the key up
; -----------------------------------------------------------------------------
; CXPPMM bit 7 is the P0/P1 collision.  If it is set and the key is not
; already held, the key changes state: from now on it is drawn above P0 and
; its record is ignored.  CXCLR then clears every latch for the next frame.
    LDA CXPPMM
    AND #$80
    BEQ .noPickup
    LDA KeyHeld
    BNE .noPickup
    LDA #$01
    STA KeyHeld
.noPickup:
    LDA #$00
    STA CXCLR

; -----------------------------------------------------------------------------
; 6. LOAD THE ROOM — the one interpreter, pointed at the new record
; -----------------------------------------------------------------------------
    JSR LoadRoom

; --- the ball's width comes from the door object's graphic index ------------
    LDA #$01
    STA CTRLPF              ; REFLECT, 1-pixel ball by default
    LDA DoorOn
    BEQ .noDoorSize
    LDX DoorGfx
    LDA BallSizeTable,X
    ORA #$01
    STA CTRLPF
.noDoorSize:

; --- compute the room's row 0 before the picture starts ----------------------
; The room band starts with row 0, so its three values must be ready before
; the first room line.  Computing them here (rather than in the band's first
; line) keeps the band's four-line budget intact and means a player at
; PlayerRow=0 draws its top four scanlines instead of losing them.
    LDA #$00
    STA RoomRow
    JSR ComputeP0
    JSR ComputeP1
    JSR ComputeBL

; --- clear the status missiles' fine registers outside the HMOVE window ----
; The reset HMOVE positioned M0/M1 with their fine offsets; the per-frame
; HMOVE applies all five HM registers, so HMM0/HMM1 must be zero before it.
; These writes are in VBLANK, far outside the 24-cycle HMOVE window.
    LDA #$00
    STA HMM0
    STA HMM1

; -----------------------------------------------------------------------------
; 7. POSITION P0/P1/BL — three coarse strobes, one HMOVE
; -----------------------------------------------------------------------------
; The Lesson 29 rule: every object's coarse position is set first, then one
; HMOVE applies all five fine registers.  A second HMOVE would re-apply them
; and walk the objects left; there is exactly one per frame.
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA KeyX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
    LDA DoorX
    CLC
    ADC #DOOR_BIAS
    JSR SetCoarseBL
    STA WSYNC
    STA HMOVE

; --- the status band's colours and clear playfield are latched now -----------
; The room band writes its own colours and walls after the status band; the
; status band must start from a clean PF and its own two indicator colours.
; Setting them in VBLANK (rather than after the picture starts) is what lets
; the status band's first line be line 0 instead of a wasted setup line.
    LDA #$00
    STA COLUBK
    STA PF0
    STA PF1
    STA PF2
    LDA #C_STATUS_M0
    STA COLUP0
    LDA #C_STATUS_M1
    STA COLUP1

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:                  ; checkpoint: scanline 37/5, visible line 0

; =============================================================================
; VISIBLE LINES 0-23: THE STATUS BAND (the room gauge and the key block)
; =============================================================================
; Six rows of four lines.  M0 is enabled for rows 1 .. Room+1 (4 lines per
; room step); M1 for rows 1-2 while the key is held.  Both are missiles, so
; they are independent of the P0/P1 graphics the room band uses.  The band's
; colours and clear playfield were latched in VBLANK, so the first line can
; store its enables here; the first line's stores complete at cycle 18, well
; before the beam reaches pixel 0 at 22.67.  Row 0 then needs only three
; more lines, and rows 1-5 use the four-line compute split.
    LDA #$00
    STA StatusRow
    STA ENAM0
    TAY                     ; Y = 0 for all of row 0's prelude stores
    STY ENAM1
; --- row 0 is blank: every prelude store is zero, never the next enable ------
; The two computes fill TmpM0/TmpM1 for row 1, but they must not reach the
; missile registers until row 1 starts.  STY stores Y = 0 on lines 2-4, so
; row 0 is four blank lines; M0 is computed on line 0, M1 on line 1, and the
; loop enters with row 1's values after line 4.
    LDA #$01
    STA StatusRow
    JSR ComputeM0
    STA WSYNC               ; row 0, line 2
    STY ENAM0
    STY ENAM1
    JSR ComputeM1
    STA WSYNC               ; row 0, line 3
    STY ENAM0
    STY ENAM1
    STA WSYNC               ; row 0, line 4
    STY ENAM0
    STY ENAM1
; --- rows 1-5: four lines each, M0 on line 1 and M1 on line 2 --------------
    LDA TmpM0
    LDY TmpM1
    LDX #$05                ; rows 1-5
StatusLoop:
    STA WSYNC
    STA ENAM0
    STY ENAM1
    STA CurM0
    STY CurM1
    INC StatusRow
    JSR ComputeM0
    LDA CurM0
    LDY CurM1
    STA WSYNC
    STA ENAM0
    STY ENAM1
    JSR ComputeM1
    LDA CurM0
    LDY CurM1
    STA WSYNC
    STA ENAM0
    STY ENAM1
    LDA CurM0
    LDY CurM1
    STA WSYNC
    STA ENAM0
    STY ENAM1
    DEX
    BEQ StatusDone
    LDA TmpM0
    LDY TmpM1
    JMP StatusLoop
StatusDone:
; Do NOT clear the missiles here: the write would land before pixel 0 of the
; last status line and blank its missile pixel.  Room 4's gauge would lose
; its twentieth line.  The clear belongs in the room setup, after this
; line's pixel 0 (see the room band's setup).

; =============================================================================
; VISIBLE LINES 24-167: THE ROOM (36 rows x 4 lines)
; =============================================================================
; The room's colour and playfield are staged by LoadRoom.  The setup below
; runs on the status band's last line after pixel 0; its COLUPF/PF writes can
; show on the right part of that line (a one-line top seam), and COLUP0 is
; written last so room 4's gauge keeps its status green.  Each row is drawn
; on four lines, and the four lines are also the engine's four compute slots:
;
;   line 1   store row N, save the values, compute row N+1's P0
;   line 2   store row N, compute row N+1's P1
;   line 3   store row N, compute row N+1's BL
;   line 4   store row N, apply row N+1's playfield/colour effects,
;            load row N+1 into A/X/Y
;
; The split is what keeps every row exactly four lines: the whole compute is
; about 100 cycles, which does not fit in one 76-cycle line, but each quarter
; does.  Row 0 is computed in VBLANK (after LoadRoom) and loaded here; the
; loop's first line stores row 0, then increments to 1 and computes row 1.
    LDA WallColor
    STA COLUPF
    LDA KeyColor
    STA COLUP1
    LDA WallPF0
    STA PF0
    LDA WallPF1
    STA PF1
    LDA WallPF2
    STA PF2
; COLUP0 is written last on purpose: the M0 gauge uses COLUP0, and room 4's
; gauge runs through this line.  Writing COLUP0 after the PF writes leaves
; the gauge's last-line pixels their status green; the room's first line
; still gets the player colour (the write lands after this line's pixel 0).
    LDA #C_PLAYER
    STA COLUP0
; The status band's last line has now passed pixel 0, so this clear lands on
; the room's first line: the last gauge line keeps its missile pixel, and the
; room never inherits M0/M1.  (A room-line clear after STA WSYNC would either
; clobber A or push the graphics stores past pixel 0.)
    LDA #$00
    STA ENAM0
    STA ENAM1
    LDA TmpP0
    LDX TmpP1
    LDY TmpBL               ; row 0's values, computed in VBLANK
RoomStart:                  ; checkpoint: the status band ends here; the first
                            ; room line follows (visible line 24)
RoomLoop:
    STA WSYNC
    STA GRP0
    STX GRP1
    STY ENABL
    STA CurP0
    STX CurP1
    STY CurBL
    INC RoomRow
    JSR ComputeP0
    LDA CurP0
    LDX CurP1
    LDY CurBL
    STA WSYNC
    STA GRP0
    STX GRP1
    STY ENABL
    JSR ComputeP1
    LDA CurP0
    LDX CurP1
    LDY CurBL
    STA WSYNC
    STA GRP0
    STX GRP1
    STY ENABL
    JSR ComputeBL
    LDA CurP0
    LDX CurP1
    LDY CurBL
    STA WSYNC
    STA GRP0
    STX GRP1
    STY ENABL
    JSR RowEffects
    LDA RoomRow
    CMP #ROOM_ROWS
    BEQ RoomDone
    LDA TmpP0
    LDX TmpP1
    LDY TmpBL
    JMP RoomLoop
RoomDone:

; =============================================================================
; VISIBLE LINES 168-191: THE LOWER BAND (the floor and its edge line)
; =============================================================================
; The last room row may still be holding the player's row-35 graphics, so
; the first lower line clears GRP0/GRP1/ENABL before its visible pixels.
; The edge line is a true 160-pixel line for three of the first lower row's
; four lines: PF0/PF1/PF2 = $FF for all 20 playfield blocks, mirrored by
; REFLECT.  The PF clear runs at the start of the fourth line, so that line
; is already floor; the rest of the band is the floor colour.
    LDA #$FF
    STA PF0
    STA PF1
    STA PF2
    LDA #C_FLOOR
    STA COLUBK
    STA WSYNC               ; first lower line
    LDA #$00
    STA GRP0
    STA GRP1
    STA ENABL
    STA WSYNC
    STA WSYNC
    STA WSYNC
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDX #(LOWER_ROWS - 1)
LowerStart:                 ; checkpoint: the lower loop's first WSYNC (visible line 172)
LowerLoop:
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    DEX
    BNE LowerLoop

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
    LDA #$02
OverscanStart:              ; checkpoint: scanline 229/6, the first blanked line
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; RESETGAME — the power-on state, also the SELECT reset
; =============================================================================
ResetGame:
    LDA #$00
    STA Room
    STA KeyHeld
    STA KeyOn
    STA DoorOn
    STA DemoDone
    STA FrameLo
    STA FrameHi
    LDA #$01
    STA AutoDemo
    LDA #145
    STA PlayerX
    LDA #13
    STA PlayerRow
    LDA PlayerX
    STA PrevX
    LDA PlayerRow
    STA PrevRow
    LDA #$00
    STA CXCLR
    RTS

; =============================================================================
; TRYLEFTEXIT / TRYRIGHTEXIT — the room record's exit bytes, applied
; =============================================================================
; The exit works only when the player's four-row body is fully inside the
; corridor: rows 10..14 (row + 3 <= 17).  $FF means the room is the end of
; the corridor in that direction.
TryLeftExit:
    LDA LeftExit
    CMP #$FF
    BEQ .lno
    LDA PlayerRow
    CMP #EXIT_MIN_ROW
    BCC .lno
    CMP #(EXIT_MAX_ROW + 1)
    BCS .lno
    LDA LeftExit
    STA Room
    LDA #148                ; enter from the right edge
    STA PlayerX
    STA PrevX
    LDA PlayerRow
    STA PrevRow
.lno:
    RTS

TryRightExit:
    LDA RightExit
    CMP #$FF
    BEQ .rno
    LDA PlayerRow
    CMP #EXIT_MIN_ROW
    BCC .rno
    CMP #(EXIT_MAX_ROW + 1)
    BCS .rno
    LDA RightExit
    STA Room
    LDA #4                  ; enter from the left edge
    STA PlayerX
    STA PrevX
    LDA PlayerRow
    STA PrevRow
.rno:
    RTS

; =============================================================================
; LOADROOM — read one room record and point the engine at its objects
; =============================================================================
; RoomTable is eight bytes per record, so the base is Room * 8.  The
; object scan uses the room record's first index and count; the room byte in
; each object record is a second check, so a record with the wrong room is
; skipped while the first/count slice keeps the scan short.
; The carried key is not a room object: it is placed above the player here,
; and the scan skips pickups while KeyHeld is set.
LoadRoom:
    LDA Room
    ASL
    ASL
    ASL
    TAX                     ; X = Room * 8
    LDA RoomTable+0,X
    STA WallPF0
    LDA RoomTable+1,X
    STA WallPF1
    LDA RoomTable+2,X
    STA WallPF2
    LDA RoomTable+3,X
    STA WallColor
    LDA RoomTable+4,X
    STA LeftExit
    LDA RoomTable+5,X
    STA RightExit
    LDA RoomTable+6,X
    STA FirstObj
    LDA RoomTable+7,X
    STA ObjCount

; --- the defaults before the scan --------------------------------------------
    LDA #$00
    STA KeyOn
    STA DoorOn
    STA KeyX
    STA DoorX
    LDA #C_KEY
    STA KeyColor
    LDA #C_DOOR
    STA DoorColor
    LDA #GFX_DOOR
    STA DoorGfx

; --- the carried key is drawn above the player, not from a record ------------
    LDA KeyHeld
    BEQ .scan
    LDA #$01
    STA KeyOn
    LDA PlayerX
    STA KeyX
    LDA PlayerRow
    SEC
    SBC #4                  ; four rows above the player
    BCS .haveRow
    LDA #$00
.haveRow:
    STA KeyRow
    LDA #$00
    STA KeyGfxOffset
    LDA #C_KEY
    STA KeyColor

; --- the room's own objects --------------------------------------------------
.scan:
    LDA FirstObj
    STA ObjIndex
    LDA ObjCount
    STA TmpCount
    BEQ .lrDone
.scanLoop:
    LDX ObjIndex
    LDA ObjectBase,X
    TAX                     ; X = object index * 6
    LDA ObjectTable+OBJ_ROOM,X
    CMP Room
    BNE .next
    LDA ObjectTable+OBJ_BEH,X
    CMP #BEH_PICKUP
    BNE .checkStatic
    LDA KeyHeld
    BNE .next               ; one carried object at a time
    LDA KeyOn
    BNE .next
    LDA #$01
    STA KeyOn
    LDA ObjectTable+OBJ_X,X
    STA KeyX
    LDA ObjectTable+OBJ_Y,X
    LSR
    LSR                     ; pixels / 4 = the 4-line row
    STA KeyRow
    LDA ObjectTable+OBJ_GFX,X
    ASL
    ASL                     ; graphic index * 4 bytes
    STA KeyGfxOffset
    LDA ObjectTable+OBJ_COLOR,X
    STA KeyColor
    JMP .next

.checkStatic:
    CMP #BEH_STATIC
    BNE .next
    LDA DoorOn
    BNE .next
    LDA #$01
    STA DoorOn
    LDA ObjectTable+OBJ_X,X
    STA DoorX
    LDA ObjectTable+OBJ_Y,X
    LSR
    LSR
    STA DoorRow
    LDA ObjectTable+OBJ_GFX,X
    STA DoorGfx
    LDA ObjectTable+OBJ_COLOR,X
    STA DoorColor
.next:
    INC ObjIndex
    DEC TmpCount
    BNE .scanLoop
.lrDone:
    RTS

; =============================================================================
; COMPUTEP0 / COMPUTEP1 / COMPUTEBL — one graphic byte each for a room row
; =============================================================================
; A = the P0 graphic byte, X = the P1 graphic byte, Y = the ball enable.
; The three routines are the skipdraw idea from Lesson 74 with a relaxed
; budget: row - top, and a carry test for "outside".  The playfield gap and
; the door colour are RowEffects' job, not these routines'.
ComputeP0:
    LDA RoomRow
    SEC
    SBC PlayerRow
    CMP #4
    BCS .cp0Blank
    TAY
    LDA PlayerGfx,Y
    STA TmpP0
    RTS
.cp0Blank:
    LDA #$00
    STA TmpP0
    RTS

ComputeP1:
    LDA KeyOn
    BEQ .cp1Blank
    LDA RoomRow
    SEC
    SBC KeyRow
    CMP #4
    BCS .cp1Blank
    CLC
    ADC KeyGfxOffset
    TAY
    LDA ObjGfxTable,Y
    STA TmpP1
    RTS
.cp1Blank:
    LDA #$00
    STA TmpP1
    RTS

ComputeBL:
    LDA DoorOn
    BEQ .cbBlank
    LDA RoomRow
    SEC
    SBC DoorRow
    CMP #4
    BCS .cbBlank
    LDA #$02
    STA TmpBL
    RTS
.cbBlank:
    LDA #$00
    STA TmpBL
    RTS

; RowEffects applies the row's playfield and colour side effects on the
; fourth line of the previous row.  The writes complete before the next
; row's first line, so the next row is fully correct; the fourth line
; itself can show the old value for its first pixels because the write
; lands after pixel 0 (a one-scanline seam at the boundary).  The door's
; colour is set for the whole exit corridor, not row by row: the corridor
; has no playfield, so only the ball shows COLUPF there, and the two
; checks replace a per-row door compare that did not fit the line.
RowEffects:
    LDA RoomRow
    CMP #EXIT_TOP
    BEQ .reGap
    CMP #(EXIT_BOTTOM + 1)
    BEQ .reRestore
    RTS
.reGap:
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA DoorOn
    BEQ .reGapDone
    LDA DoorColor
    STA COLUPF
.reGapDone:
    RTS
.reRestore:
    LDA WallPF0
    STA PF0
    LDA WallPF1
    STA PF1
    LDA WallPF2
    STA PF2
    LDA WallColor
    STA COLUPF
    RTS

; =============================================================================
; COMPUTEM0 / COMPUTEM1 — one enable each, for the next status row
; =============================================================================
; Row 0 is blank; the gauge runs for rows 1 .. Room+1, the key block for
; rows 1-2 while the key is held.  The split lets each compute live on its
; own scanline inside the 76-cycle budget.
ComputeM0:
    LDA #$00
    STA TmpM0
    LDA StatusRow
    CMP #1
    BCC .cm0Done
    LDA Room
    CLC
    ADC #2                  ; Room + 2: the first row past the gauge
    STA Tmp
    LDA StatusRow
    CMP Tmp
    BCS .cm0Done
    LDA #$02
    STA TmpM0
.cm0Done:
    RTS

ComputeM1:
    LDA #$00
    STA TmpM1
    LDA StatusRow
    CMP #1
    BCC .cm1Done
    CMP #3
    BCS .cm1Done
    LDA KeyHeld
    BEQ .cm1Done
    LDA #$02
    STA TmpM1
.cm1Done:
    RTS

; =============================================================================
; COARSE POSITIONING — five routines, no HMOVE here
; =============================================================================
; Input: A = the biased target (target + 3).  The routines are separate
; because each one writes a different RESxx/HMxx pair; the caller runs all
; of them and then strobes HMOVE once.  The divide-by-15 loop spends five
; cycles per 15 colour clocks; the remainder becomes the high nibble of the
; fine register.
SetCoarseP0:
    STA WSYNC
    SEC
.divP0:
    SBC #15
    BCS .divP0
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
.divP1:
    SBC #15
    BCS .divP1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
    RTS

SetCoarseBL:
    STA WSYNC
    SEC
.divBL:
    SBC #15
    BCS .divBL
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMBL
    STA RESBL
    RTS

SetCoarseM0:
    STA WSYNC
    SEC
.divM0:
    SBC #15
    BCS .divM0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM0
    STA RESM0
    RTS

SetCoarseM1:
    STA WSYNC
    SEC
.divM1:
    SBC #15
    BCS .divM1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM1
    STA RESM1
    RTS

; =============================================================================
; THE ROOM TABLE — four 8-byte records (index = Room * 8)
; =============================================================================
; Read down a column.  The playfield patterns are all built from PF0=$10
; (a four-pixel side wall, mirrored to the right edge) plus interior pillars;
; the exit corridor zeroes all three bytes for rows 10-17.  The colours are
; the room's identity: red, green, orange, blue.
RoomTable:
    ; room 0: side walls + pillars at blocks 4 and 11
    !byte $10, $81, $00, C_WALL0, $FF, $01, 0, 1
    ; room 1: side walls + a central pair at blocks 15 and 16
    !byte $10, $00, $18, C_WALL1, $00, $02, 1, 2
    ; room 2: side walls + pillars at blocks 6 and 9
    !byte $10, $24, $00, C_WALL2, $01, $03, 3, 1
    ; room 3: side walls + a four-block band at blocks 4,5,10,11
    !byte $10, $C3, $00, C_WALL3, $02, $FF, 4, 2

; =============================================================================
; THE OBJECT TABLE — six 6-byte records
; =============================================================================
; x, y, graphic, colour, behaviour, room.
; The room-0 record is the door in the corridor; room 1 has the key on the
; player's row and a door above it; room 2 has a door; room 3 has a second
; key and a door.  Each room has at most one pickup and one static object,
; which is what the P1/ball pair can draw without flicker.
ObjectTable:
    ; room 0: the first door
    !byte 128, 40, GFX_DOOR, C_DOOR, BEH_STATIC, 0
    ; room 1: the key and its door
    !byte 112, 52, GFX_KEY,  C_KEY,  BEH_PICKUP, 1
    !byte 128, 40, GFX_DOOR, C_DOOR, BEH_STATIC, 1
    ; room 2: the door ahead of the demo
    !byte 112, 48, GFX_DOOR, C_DOOR, BEH_STATIC, 2
    ; room 3: the second key and its door
    !byte 96,  48, GFX_KEY,  C_KEY,  BEH_PICKUP, 3
    !byte 128, 40, GFX_DOOR, C_DOOR, BEH_STATIC, 3

; ObjectBase is the record index times six: ObjectTable is an array of
; six-byte records, and the 6502 has no multiply, so the table does it.
ObjectBase:
    !byte 0, 6, 12, 18, 24, 30

; The ball is the door.  CTRLPF bits 4-5 choose 1/2/4/8 pixels; the high
; nibble of each entry is ORed with the REFLECT bit.
BallSizeTable:
    !byte $00               ; index 0 unused (the key's sprite index)
    !byte $30               ; index 1: 8 pixels
    !byte $20               ; index 2: 4 pixels

; The sprite graphics are four bytes, one byte per 4-line row.  Index 0 is
; the key; index 1 is the gem the stretch exercise adds.
ObjGfxTable:
    ; index 0: the key
    !byte %00111100
    !byte %01100110
    !byte %00011000
    !byte %00010100
    ; index 1: the gem
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %00111100

; P0's graphic: an 8x16 adventurer, four 4-line rows.
PlayerGfx:
    !byte %00111100
    !byte %01111110
    !byte %01111110
    !byte %00100100

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
> `lessons/part11-legendary/78-room-object-engine/78-room-object-engine.asm`.

### Code Walkthrough

#### Step 1 — Reset, the status colours, and the first game state

`Reset` is the course's `+clean_start` plus a fixed TIA state. The interesting part for this lesson is the order of the writes: the status band's colours and its clear playfield are latched **in the vertical blank**, not after the picture starts, so the status band's first line can be line 0 rather than a wasted setup line.

```asm
    LDA #$10
    STA NUSIZ0              ; M0 is 2 pixels wide; P0 is one copy
    LDA #$20
    STA NUSIZ1              ; M1 is 4 pixels wide; P1 is one copy
    LDA #$01
    STA CTRLPF              ; REFLECT the playfield; a 1-pixel ball
```

`NUSIZ0`/`NUSIZ1` choose the two status missiles' widths; `CTRLPF`'s reflect bit makes every room's left-half playfield a wall on both sides. `ResetGame` sets room 0, `x=145`, `row=13`, no key, and `AutoDemo=1`. The first vertical blank's `LoadRoom` turns those bytes into a room.

#### Step 2 — The vertical blank: SELECT, input, walls, movement, exits

The vertical blank is the engine's decision phase. The order is deliberate:

1. **SELECT** (SWCHB bit 1) resets the whole game on a new press. The edge latch `PrevSelect` makes it one reset per press.
2. **The joystick** (SWCHA bits 7-4) cancels the auto-demo as soon as any direction is pressed.
3. **The wall collision** reads `CXP0FB` bit 7 from the previous frame and, if the player walked into a wall, restores `PrevX/PrevRow`.
4. **The movement** applies the auto-demo's right step or the joystick's direction. The horizontal exit is checked at `x=152` and `x=0`; the row must be inside the corridor (10..14) and the room record's exit byte must not be `$FF`.

```asm
    LDA CXP0FB
    AND #$80
    BEQ .noWall
    LDA PrevX
    STA PlayerX
    LDA PrevRow
    STA PlayerRow
.noWall:
```

The wall test is a one-frame-old latch, so the player can overlap a wall for a single frame before the revert. That is the TIA's design: the collision registers describe the picture that has just been drawn, and the engine acts on it in the next blank. The corridor has no playfield, so the exit path never latches; the walls above and below it do.

#### Step 3 — Pickup and the carried key

`CXPPMM` bit 7 is the P0/P1 collision. If it is set and no object is carried, the key changes state:

```asm
    LDA CXPPMM
    AND #$80
    BEQ .noPickup
    LDA KeyHeld
    BNE .noPickup
    LDA #$01
    STA KeyHeld
.noPickup:
    LDA #$00
    STA CXCLR
```

`CXCLR` clears every latch after the two collision tests, so the next frame's latches describe the next frame's picture. The key's record is not deleted; `LoadRoom` simply ignores pickups while `KeyHeld` is set, and the carried path places the key four rows above the player. That is why the key follows: its x is the player's x, and its y is the player's y minus 16 pixels.

#### Step 4 — `LoadRoom`: the one interpreter

`LoadRoom` is the lesson's centerpiece. It reads the eight-byte room record, stages the fields in RAM, and scans the room's objects:

```asm
LoadRoom:
    LDA Room
    ASL
    ASL
    ASL
    TAX                     ; X = Room * 8
    LDA RoomTable+0,X
    STA WallPF0
    ...
    LDA RoomTable+6,X
    STA FirstObj
    LDA RoomTable+7,X
    STA ObjCount
```

The object scan uses `ObjectBase` to turn an object index into a six-byte record offset, checks the record's room byte, and fills `Key*` for the one pickup and `Door*` for the one static object. The scan is where the behaviour byte does its work: `BEH_PICKUP` sets `KeyOn`, the position, the graphic offset and the colour; `BEH_STATIC` sets `DoorOn`, the position, the ball size index and the door colour. The room's objects are grouped, so the scan stops after `ObjCount` records rather than searching the whole table.

#### Step 5 — Positioning and the one `HMOVE`

P0, P1 and the ball are positioned with the Lesson 26 divide-by-15 routine, three coarse strobes and **one** `HMOVE`:

```asm
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    LDA KeyX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP1
    LDA DoorX
    CLC
    ADC #DOOR_BIAS
    JSR SetCoarseBL
    STA WSYNC
    STA HMOVE
```

The three routines write `HMP0`/`HMP1`/`HMBL` and strobe `RESP0`/`RESP1`/`RESBL`; the single `HMOVE` applies all three fine offsets at once. A second `HMOVE` would re-apply the same registers and walk the objects left; there is exactly one per frame. The status missiles' fine registers are zeroed once at power-on, so the per-frame `HMOVE` cannot move them.

#### Step 6 — The status band

The status band is six rows of four lines. Its colours and clear playfield were latched in VBLANK; line 0 stores zero to both missiles and computes row 1's M0, and the rest of the band uses the same four-line compute split as the room:

```asm
    LDA #$00
    STA StatusRow
    STA ENAM0
    TAY                     ; Y = 0 for all of row 0's prelude stores
    STY ENAM1
    LDA #$01
    STA StatusRow
    JSR ComputeM0           ; row 1's M0, held in TmpM0
    STA WSYNC
    STY ENAM0               ; row 0 line 2: still zero
    STY ENAM1
    JSR ComputeM1           ; row 1's M1, held in TmpM1
    ...
```

`ComputeM0` enables the gauge for rows `1 .. Room+1`; `ComputeM1` enables the key block for rows 1-2 while the carried-object flag is set. Row 0 is four blank lines: the prelude's `STY` stores use Y=0 rather than the freshly computed A, which is the bug this lesson's first review caught. The gauge therefore starts at row 1 and the key block has room to sit beside it.

#### Step 7 — The room band's four-line row loop

The room band is thirty-six four-line rows. Each row stores P0, P1 and the ball enable on every line, and uses the four lines as the four compute slots:

```asm
RoomLoop:
    STA WSYNC
    STA GRP0
    STX GRP1
    STY ENABL
    STA CurP0
    STX CurP1
    STY CurBL
    INC RoomRow
    JSR ComputeP0
    LDA CurP0
    LDX CurP1
    LDY CurBL
    STA WSYNC
    ...
```

`ComputeP0`/`ComputeP1`/`ComputeBL` are the Lesson 74 skipdraw idea with a relaxed budget: `row - top`, a carry test for "outside", and a table read for the graphic byte. Row 0 is computed in VBLANK (after `LoadRoom`) and loaded here, so a player at `PlayerRow=0` draws its top four scanlines. `RowEffects` applies the exit gap and the door colour on the fourth line; the next row is fully correct, but the fourth line itself can show the old value for its first pixels while the writes land (a one-scanline seam at the boundary). The last room row may still be holding a player at `PlayerRow=32`, so the lower band clears `GRP0`, `GRP1` and `ENABL` on its first line before the visible pixels.

#### Step 8 — The lower band, the frame end, and the tables

The lower band draws three full-width edge lines at the top of the lower band in the room's colour (PF0/PF1/PF2 = $FF, all 20 blocks mirrored); the PF clear lands at the start of the first lower row's fourth line, so that line is already floor, and the rest of the band is the floor colour. The frame ends with the standard 30-line overscan, and `StartFrame` begins the next pass. The tables at the bottom of the source are the data the engine has been reading: the four room records, the six object records, the six-entry `ObjectBase`, the ball-size table, the two object graphics and the player's four-row graphic.

## What You Should See

At power-on, room 0 is a red antechamber. Two four-pixel side walls run down both edges, with pillars at blocks 4 and 11; a 32-line black corridor cuts the walls in the middle; a brown-red door sits in the corridor; the blue 8×16 adventurer starts at the right side, x=145, row 13. The status band is black except for a 2-pixel green bar at x≈21, four scanlines tall: room 0's gauge. The auto-demo walks right immediately, leaves through the corridor at x=152, and enters room 1.

Room 1 is green, with a central pair of pillars and the same side walls. The key is a gold 8×16 sprite on the floor at x=112, row 13. The player enters at the left edge and walks right; the 2-second capture catches the room before the pickup: the player is at x≈92, the green gauge is 8 scanlines tall, the gold key block is off, the key is on the floor ahead at x=112, and the brown-red door is above it.

![Stella running Lesson 78 at two seconds: the green room 1, the status band's 8-line green gauge, the gold key on the floor at x=112, the blue player at the left, and the door above the key](/images/lesson78/room-1.png)

*`room-1.png`: about 2 seconds after power-on. Room index 1; the gauge is 8 scanlines; the key block is off; the key is on the floor at x=112. The player is at x≈92, row 13.*

<RomPlayer rom="/roms/part11-legendary/78-room-object-engine/78-room-object-engine.bin" title="Lesson 78 — Room & Object Engine — The Adventure Architecture" />

*Javatari starts muted; this ROM is silent.*

The player reaches the key at x=109 and the P0/P1 latch sets the carry flag. From then on the key is drawn four rows above the player, so it rides along at the player's x. The player continues to room 1's right edge, enters room 2, and walks to x=96, where the demo stops.

Room 2 is orange, with pillars at blocks 6 and 9. The 5-second capture is the stable room-2 state: the orange gauge is 12 scanlines tall, the gold key block is on, the key rides above the player, and the room's brown-red door is visible ahead.

![Stella running Lesson 78 at five seconds: the orange room 2, the status band's 12-line gauge and lit gold key block, the gold key carried above the blue player, and the door to the right](/images/lesson78/room-2.png)

*`room-2.png`: about 5 seconds after power-on. Room index 2; the gauge is 12 scanlines; the key block is on; the key is carried above the player at x≈96; the door is at x=112.*

The two images are different states, not two copies of one frame. The **pixel check** of the two committed captures:

| Image | Size | Title bar | Room walls | Gauge | Key block | Key | Door |
|---|---|---|---|---|---|---|---|
| `room-1.png` | 1010×807 | `Stella 7.0: "78-room-object-engine"` | green `(61,151,60)`; side walls + central pair | green at x=139-150, y=119-143 (8 scanlines; 25 captured pixels) | off | gold at x=703-738, y=347-395 (on the floor) | orange-red at x=787-834, y=309-357 |
| `room-2.png` | 1010×807 | `Stella 7.0: "78-room-object-engine"` | orange `(173,111,38)`; side walls + four pillars | green at x=139-150, y=119-155 (12 scanlines; 37 captured pixels) | on: gold at x=259-282, y=119-143 | gold at x=607-642, y=317-345 (carried above P0) | orange-red at x=691-738, y=334-383 |

The **gauge check** is the room index. The gauge is enabled for `Room+1` status rows of four lines each: room 0 is 4 lines, room 1 is 8, room 2 is 12, room 3 is 16. The first image's green bar is 8 scanlines (25 captured pixels at the display's 3.26-pixel line height); the second is 12 (37 captured pixels). The two images differ by exactly one room step. The same measure gives 4 lines for room 0, 16 for room 3 and 20 for the first exercise's room 4; the captured bar is a few pixels shorter at the 2-pixel missile's edge.

The **key-state check** is the M1 block and the P1 sprite. The first image's M1 block is absent and the key is on the floor at x=112. The second image's M1 block is a 4×8 gold rectangle at x≈41, and the key is above the player at the player's x. The transition is the `CXPPMM` bit-7 pickup at frame 113 of the model.

The **room-layout check** is the wall colour and pattern. Room 1's record is `$10 $00 $18` at colour `$C6`: side walls, no PF1 pillars, a central pair from PF2 bits 3-4. Room 2's record is `$10 $24 $00` at colour `$26`: side walls and pillars at blocks 6 and 9. The captures show the central pair in green and the two inner pillars in orange, which is exactly the two records.

The **frame check** is the trace's ledger:

| Checkpoint | Line/cycle | What it proves |
|---|---|---|
| `StartFrame` | 259/3 | the VSYNC begins at line 259 |
| `VblankStart` | 0/5 | the blank begins at line 0 |
| `BodyStart` | 37/5 | the picture begins at line 37, every frame |
| `RoomStart` | 60/63 | the status band is 24 lines; the first room line is 61/0 |
| `LowerStart` | 209/13 | the room band is 144 lines; the lower band starts at 205/0 |
| `OverscanStart` | 229/6 | the picture ends at line 228; the blank begins at 229 |

The frame is 262 lines; the visible body is 229 - 37 = 192; the band split is 24 + 144 + 24 = 192. The trace shows the same checkpoints on every frame, including the room changes and the key pickup. The two captures show a stable picture with no roll.

> **Capture method.** Both images are `scripts/capture-screenshot.sh` captures of the committed
> `docs/public/roms/part11-legendary/78-room-object-engine/78-room-object-engine.bin` at
> approximately two and five wall-clock seconds, with the pointer parked at 0,0 and no cursor.
> Stella's start-up and frame rate shift the game clock: the 2-second image is around game
> frame 96 (room 1, just before the pickup), and the 5-second image is around frame 249
> (room 2, after the demo's stop). Both images are 1010×807, carry the window frame and the
> `Stella 7.0: "78-room-object-engine"` title bar, and show no cursor. The display uses the
> standard palette with phosphor, TV filters and colour-loss off.

Open Stella's debugger and check the same state by hand. At `BodyStart` the scanline is 37, at `RoomStart` it is 60/63 and the first room line is 61. In the RAM tab, `$80` is the room index, `$81`/`$82` are the player's x and row, `$85` is the carry flag, `$86`/`$87` are the key's x and row, `$8A`/`$8B` are the door's x and row, `$90-$93` are the current room's staged pattern and colour, and `$94`/`$95` are the exit bytes. Step a frame at a time through the room-1 pickup: `CXPPMM` bit 7 sets, `$85` goes to 1, and the key's `$87` rises four rows above the player's as the carried path takes over.

## Exercises

Each exercise ships a complete 4,096-byte `exercise-NN-solution.asm`. The solutions assemble through `npm run roms`, run in Stella, and solve the exercise as written.

### Exercise 1: A Fifth Room and a Second Exit

**Challenge:** add a fifth room to the adventure and a second exit. The fifth room must be reachable from an existing room through a **vertical** exit (up or down), not just another left/right link, and returning through that exit must work in both directions. Keep the ROM at 4,096 bytes and the frame at 262 lines.

**Hints:**

1. The room record is eight bytes because the main design only needs left and right exits. Grow it to ten: `PF0, PF1, PF2, colour, left, right, up, down, first object, count`. `LoadRoom` cannot use three `ASL`s for a ten-byte stride; a five-entry `RoomBase` table (`0, 10, 20, 30, 40`) is the smallest multiply.
2. Add `UpExit` and `DownExit` RAM bytes and two exit routines. The up exit fires at `PlayerRow == 0`, the down exit at `PlayerRow == 32`; entering from above places the player at row 2, entering from below places it at row 30. The vertical exits need no x corridor because the room has no top or bottom wall.
3. Room 2's record gets `up -> 4`; room 4's gets `down -> 2`. The status gauge already handles room 4: M0 is enabled for rows 1 through `Room+1`, and four rows of 4 scanlines is 20 lines, inside the 24-line status band. The last status line's missile pixel is not blanked: the missiles are cleared at the room setup, after that line's pixel 0. The object table needs a seventh record and a seventh `ObjectBase` entry (`36`).

**Expected Result:** the fifth room (violet walls, `$10 $42 $00` at colour `$66`) is reached by walking up from room 2; the status gauge is 20 scanlines tall; the down exit returns to room 2. The ROM assembles to exactly 4,096 bytes; `BodyStart` is 37/5 and the frame is 262; the auto-demo reaches the fifth room after it reaches x=96 in room 2 and climbs through the up exit. The solution's `exercise-01-solution.asm` is the main source with the ten-byte record, the `RoomBase` table, the two exit routines and the seventh object.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: A Behaviour Flag and a Third Object *(Stretch Goal)*

**Challenge:** add a second static behaviour, `BEH_LOCKED = 2`, and use it on room 2's door. Without a carried object the locked door must be solid: the player's P0/ball collision reverts the move, exactly like a wall. With a carried object the same collision must open the door — the ball disappears for the rest of the room visit, and the player can pass. Also add a third object: a gem in room 1 at x=40, row 13, with a different graphic and colour (violet). The auto-demo should walk to it, pick it up and use it as the carried object; the room-1 key record is skipped and not drawn while the gem is carried. Keep the ROM at 4,096 bytes and the frame at 262 lines.

**Hints:**

1. `BEH_LOCKED` is one more value in the object record's behaviour byte. In `LoadRoom`, test it after `BEH_STATIC`: set `DoorLocked=1` for the locked door, `0` for the ordinary one. The door drawing is unchanged; the behaviour decides what a collision means.
2. The collision is `CXP0FB` bit 6 (P0 over the ball). In VBLANK, after the wall test, read it. If `DoorLocked` is set and `KeyHeld` is clear, restore `PrevX/PrevRow` (the door is solid). If `DoorLocked` is set and `KeyHeld` is set, set `DoorOpen`; after `LoadRoom`, force `DoorOn=0` while `DoorOpen` is set. Reset `DoorOpen` on a room change.
3. The gem is a second pickup with `graphic = 1` (the gem's 8×16 bitmap) and colour `$7A`. The engine carries one object at a time, so the room-1 key is skipped while the gem is carried. Save the picked object's graphic offset and colour in `CarryGfxOffset`/`CarryColor`; the carried path must use those, not the hard-coded key values, or the gem will be drawn as a gold key.

**Expected Result:** the gem is a violet 8×16 object in room 1 at x=40; the auto-demo walks to it, picks it up and carries it. Room 2's locked door blocks a player without a carried object (the player stops at the door and the ball stays visible); with the gem the door opens (the ball disappears and the player walks through to x=140). The no-carry state is checked with a table/test variant that omits both room-1 pickups (`first=3, count=1`, the door only); the demo itself carries the gem. The ROM assembles to exactly 4,096 bytes; `BodyStart` is 37/5 and the frame is 262. The solution's `exercise-02-solution.asm` is the main source with `BEH_LOCKED`, the door block/open logic, the gem record and the carry storage.

**Solution:** See `exercise-02-solution.asm`

## Key Takeaways

- ✅ **A room is a record, not a program.** Eight bytes describe the walls, the colour, the exits and the object slice; one interpreter draws every room. Adding a room is a record, not another copy of the kernel.
- ✅ **An object is six bytes and one behaviour flag.** Position, graphic, colour, behaviour and room; the engine interprets the flag. The main ROM has two behaviours (static and pickup); the exercise adds a third (locked) without touching the draw code.
- ✅ **The TIA's collision latches are the interaction layer.** `CXPPMM` bit 7 is the pickup and `CXP0FB` bits 7/6 are the wall and the door. The engine reads the previous frame's picture in the next blank, which is why a wall collision reverts the move one frame later.
- ✅ **Data-driven means staged in the blank and fixed in the beam.** `LoadRoom` pays for the indexing while the picture is off; the room band reads fixed RAM addresses while the beam is on. The same split runs through Lesson 71's row table and Lesson 76's ring.
- ✅ **Four-line rows are a budget decision.** The room's three-object compute is about 100 cycles; a 2-line row gives 143 cycles and a 4-line row gives 295. The vertical resolution drops to four scanlines, which is in character with the 1980 game and keeps the engine readable.
- ✅ **The status band is the engine's debugger.** The green gauge is `Room+1` four-line steps; the gold block is the carry flag. The captures decode to the room and the carry state without reading a single byte.
- ✅ **262 lines is a contract.** The trace's checkpoints — 259/3, 0/5, 37/5, 60/63, 209/13, 229/6 — are the same on every frame. A single overrun in a band would roll the picture; the four-line compute split is what keeps the contract.

## What's Next

The four-room world is the end of this lesson. [Lesson 79: The Publisher Mark](/part11-legendary/79-publisher-mark) is the last entry in the Part 11 anthology: the 48-pixel trick, a page-aligned ROM table and the Activision-style wordmark in the bottom band. The [Part 11 index](/part11-legendary/) lists the whole anthology. The engine's next step is to make the room records themselves a level format — a generator that emits the eight-byte records and the object table, the way Lesson 71's generator emits the maze — and then to let the objects have more than one carried slot.
