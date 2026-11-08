---
title: "Lesson 71: Capstone 3 — Maze Explorer"
description: "Build a complete maze adventure from a generated mirror maze: a Python generator with a spec and a --check gate, ten unique columns mirrored to twenty by reflect mode, a 44-byte object row table inside 16-line maze rows, two chase enemies, three sequential keys, a win and a lose state, and a scripted auto-demo. The lesson proves the generator with a host-side check, the frame with Stella state logs, and the screen with pixel measurements."
prev:
  text: "Lesson 70: Capstone 2 — Breakout"
  link: "/part10-capstones/70-breakout"
next:
  text: "Lesson 72: Capstone 4 — Your Own Game"
  link: "/part10-capstones/72-your-game"
---

# Lesson 71: Capstone 3 — Maze Explorer

> **Part 10: Capstone Projects** · Estimated time: 180 minutes
> **Prerequisites:** Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and memory), Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players), Lesson 26 (horizontal positioning), Lesson 31 (`NUSIZ`), Lesson 33 (controllers), Lesson 39 (the scoreboard and the score library — this lesson uses a playfield icon table instead, the contrast), Lesson 41 (game states), Lesson 44 (enemy AI), Lesson 49 (the two-line kernel), Lesson 50 (the multi-zone kernel), Lesson 53 (kernel patterns), Lesson 67 (the generator), Lesson 69 (the row table), Lesson 70 (the zones)
> **You will learn:** how to draw a 20-column maze with ten unique columns and the TIA's reflect mode; how a small Python generator turns a five-line spec into the playfield rows, the wall map, the key and enemy cells, and a scripted route; how a wall map whose bit 9 is the leftmost column answers a movement query through the mirror transform `col < 10 ? col : 19 - col`; how a 44-byte object row table draws a player, two enemies and a key inside 11 maze rows of 16 lines; how the four lines of an object row split the PF/missile stores, the next-row decode, and the graphics stores; how P1 is written immediately while P0 and the ball use VDEL; how a greedy largest-axis enemy stays on the player's cell and is caught by the cell compare; how sequential keys, status slots and a win/lose state fit one machine; and how a deterministic scripted demo makes the captures reproducible.
> **You will build:** **Maze Explorer**, a complete 4,096-byte ROM: a generated 10 × 11 mirror maze (20 visible columns), an 8×16 cell drawn as a 4-pixel gold player bar, a red 8×16 enemy block and a gold 8×16 missile enemy block, a blue 8×8 key, three sequential keys that fill the status band, a win flash and a lose flash, fire restart, and a scripted auto-demo. The three exercise solutions add a fog-of-war radius, a direction-persisting pathfinding enemy that moves in the overscan, and a 60-second clock with a bonus key and a solid win screen. The generator (`lesson71-generate.py`) reads `maze-spec.txt` (seed, width, height, keys, enemies), validates it, and lowers it into the committed `maze-data.inc`; `--check` is the read-only drift gate.

## Introduction

Pong taught the capstone's first lesson: a moving object's vertical position is a per-frame decision, so precompute the whole screen's object layout in VBLANK and let the visible kernel read a table. Breakout added the field: a playfield zone above a row-table play area, with the ball crossing the border. Maze Explorer adds the piece both games avoided: **a world with structure that is too big to hand-author**. A 20-column maze at 8 pixels per column is 160 pixels wide; a hand-drawn map is 220 cells and a wall list nobody wants to type. The maze is generated, and the generator is part of the lesson.

The trick that makes a full-width maze possible is older than the course: the TIA draws the left half of the playfield and then either repeats or mirrors it. In reflect mode the right half is the mirror image, so **ten unique columns become twenty visible ones**. A wall at unique column 4 is drawn at visible column 4 and visible column 15. The movement code maps a visible column back with `col < 10 ? col : 19 - col` and asks the ten-bit wall map one question: is the target cell a wall? The same ten columns cost half the ROM and half the generator, and the mirror becomes a play mechanic: the two visible halves are connected only at the seam, the right edge of unique column 9.

The companion program, `71-maze-explorer.asm`, is a complete Maze Explorer in 4,096 bytes. Its screen is 8 status lines + 8 setup lines + 176 maze lines = 192. Its frame is the course standard 3 + 37 + 192 + 30 = 262, measured as `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `MazeRowStart` 53, `OverscanStart` 229. Its RAM map is exact: `$80-$AB` the 44-byte object row table, `$AC-$C7` twenty-eight game variables, `$C8-$DD` scratch, `$DE-$F7` free, `$F8-$FF` the stack. Its data is the committed `maze-data.inc`, generated from `maze-spec.txt` by `lesson71-generate.py`.

The lesson is also about the boundary between generated data and hand-written code. The generator can build the maze, place the keys and enemies, and even compute the scripted demo route; it cannot write the 262-line frame, the four-line object row, the four positioners, the wall check, or the collision rule. Those stay hand-written, and the include is the contract between the two: `MazePF` (11 × 3 bytes), `MazeWalls` (11 × 2 bytes), `KeyCells` (3 × 2), `EnemyCells` (2 × 2, now `(0,0)` and `(18,10)`), `DemoPath` (65 direction bytes), and the constants. `--check` proves the committed include is still the deterministic image of the spec; CI never runs Python.

::: details TypeScript Equivalent

A maze game in TypeScript keeps a two-dimensional grid and draws it with rectangles. The 2600 has a ten-bit wall map, a mirror transform, and a playfield whose cells are four-pixel chunks, so the model has three layers: a **wall grid**, a **mirror lookup**, and a **cell query** shared by the player and the enemies.

```typescript
const COLS = 10, ROWS = 11;          // the unique maze
const VIS_COLS = 20;                 // the visible screen
const CELL_W = 8, CELL_H = 16;       // pixels

// 1 = wall, 0 = open.  The generator's MazeWalls is this grid packed into
// ten bits per row, bit 9 = the leftmost unique column.
const walls: number[][] = [
  [0,0,0,0,0,0,0,0,0,1],
  // ... eleven rows
];

// The TIA's reflect mode is a display rule; the game uses it as a lookup.
const mirror = (col: number): number => (col < COLS ? col : 2 * COLS - 1 - col);
const isOpen = (col: number, row: number): boolean =>
  col >= 0 && col < VIS_COLS && row >= 0 && row < ROWS && walls[row][mirror(col)] === 0;

type Dir = 0 | 1 | 2 | 3;            // up, down, left, right
const DELTA: ReadonlyArray<readonly [number, number]> = [
  [0, -1], [0, 1], [-1, 0], [1, 0],
];

// The player's move: the screen cell becomes a sprite position.
function tryMove(col: number, row: number, dir: Dir): [number, number] | null {
  const [dc, dr] = DELTA[dir];
  const nc = col + dc, nr = row + dr;
  if (!isOpen(nc, nr)) return null;
  return [nc, nr];
}

const pixelX = (col: number) => col * CELL_W;
const pixelY = (row: number) => 16 + row * CELL_H;

// The main's enemy: choose the axis with the larger distance, then the other.
// A zero delta means the enemy is already on the player's cell: it stays.
function enemyStep(enemy: [number, number], player: [number, number]): [number, number] {
  const [ec, er] = enemy, [pc, pr] = player;
  const dc = pc - ec, dr = pr - er;
  if (dc === 0 && dr === 0) return enemy;
  const h: Dir = dc > 0 ? 3 : 2;   // right when the player is to the right
  const v: Dir = dr > 0 ? 1 : 0;   // down when the player is below
  const axes: Dir[] = Math.abs(dc) > Math.abs(dr) ? [h, v] : [v, h];
  for (const dir of axes) {
    const next = tryMove(ec, er, dir);
    if (next) return next;
  }
  return enemy;
}

// Exercise 2's actual enemy is cheaper than a search: it scores the four open
// neighbours by the Manhattan distance to the player, gives the current
// direction a one-point bonus so a corridor is followed, and refuses a cell
// whose degree is 1 (a dead end) unless the player is there.
function smarterStep(enemy: [number, number], player: [number, number],
                     dir: Dir): { cell: [number, number]; dir: Dir } {
  let best = { score: Infinity, cell: enemy, dir };
  for (let d = 0 as Dir; d < 4; d = (d + 1) as Dir) {
    const next = tryMove(enemy[0], enemy[1], d);
    if (!next) continue;
    let score = Math.abs(next[0] - player[0]) + Math.abs(next[1] - player[1]);
    if (d === dir) score -= 1;                      // persistence bonus
    if (degree(next) === 1 && next.join() !== player.join()) continue;
    if (score < best.score) best = { score, cell: next, dir: d };
  }
  return { cell: best.cell, dir: best.dir };
}

// An optional BFS alternative: the shortest corridor path, if a reader wants
// to spend the RAM and cycles on a search instead of the heuristic above.
function bfsNextStep(from: [number, number], to: [number, number]): Dir | null {
  const queue: Array<[number, number]> = [from];
  const prev = new Map<string, [number, number, Dir]>();
  const seen = new Set<string>([from.join(',')]);
  while (queue.length) {
    const [c, r] = queue.shift()!;
    if (c === to[0] && r === to[1]) break;
    for (let dir = 0 as Dir; dir < 4; dir = (dir + 1) as Dir) {
      const [dc, dr] = DELTA[dir];
      const nc = c + dc, nr = r + dr;
      if (!isOpen(nc, nr) || seen.has(`${nc},${nr}`)) continue;
      seen.add(`${nc},${nr}`);
      prev.set(`${nc},${nr}`, [c, r, dir]);
      queue.push([nc, nr]);
    }
  }
  let cell = to;
  let step: Dir | null = null;
  while (prev.has(cell.join(','))) {
    const [pc, pr, dir] = prev.get(cell.join(','))!;
    if (pc === from[0] && pr === from[1]) { step = dir; break; }
    cell = [pc, pr];
  }
  return step;
}

// One frame's world update; the real code runs this in VBLANK and in the
// overscan.  The collision is checked after the player's move and again after
// the enemies move.
function step(world: World): void {
  if (world.gameState !== 0) return;
  const moved = tryMove(world.player[0], world.player[1], world.input);
  if (moved) {
    world.player = moved;
    if (world.enemies.some((e) => e.join() === world.player.join())) {
      world.gameState = 2;
      return;
    }
    if (world.player.join() === world.key.join()) collectKey(world);
  }
  world.enemies = world.enemies.map((e) => enemyStep(e, world.player));
  if (world.enemies.some((e) => e.join() === world.player.join())) world.gameState = 2;
}
```

The model gets the shape right — a grid, a mirror, a query, a state machine — and it breaks at the points where the 2600 is different:

- **The wall map is ten bits per row, not a 20 × 11 array.** The visible right half does not exist in RAM; it is the TIA's reflect-mode copy. The TypeScript `walls[row][col]` for `col >= 10` is derived by `mirror`, exactly as the ROM does. The generator writes the ten bits, not twenty.
- **There is no framebuffer.** The maze kernel writes `PF0`/`PF1`/`PF2` once per 16-line row; the beam holds them for sixteen scanlines. The walls are 4-pixel chunks, not 1-pixel rectangles: a cell is two chunks, and the generator's `MazePF` is already the chunk pattern.
- **The objects are a table, not a scene graph.** The 44-byte `ObjRowTable` has one 4-bit byte per 4-line row; the kernel decodes the next row on the second line of each four-line row. `drawSprite` has no counterpart. The sprite boxes are 8×16 because a maze cell is 8×16 (the player's glyph is a 4-pixel bar); the ball is 8×8 and blinks because it shares `COLUPF` with the walls.
- **The collision is a cell comparison, not a physics step.** An enemy in the player's cell sets `GameState=2`; the key is collected when the player's cell equals the current key's cell. There are no bounding boxes and no `CX` latch in this game — the grid is the collision system.
- **The frame is fixed at 262 lines and every line is 76 cycles.** The later maze rows' first line stores `PF0`, `P1`, `ENAM0`, `PF1` and `PF2`, which complete at 6, 12, 18, 25 and 32; the first maze row, after `MazeRowStart`'s `LDX`, completes at 8, 14, 20, 27 and 34; the deadlines are 22.7, 22.7, 22.7, 28.0 and 38.7. The TypeScript loop has no deadline.
- **The generator runs on the host, never in the ROM.** The spec is not parsed at run time; `maze-data.inc` is fixed tables. `--check` is the repository-boundary type checker: it proves the committed include is still the deterministic image of the spec.
- **The positions are quantized.** The player's cell is 8 × 16 pixels, so `X = col * 8` and `Y = 16 + row * 16`; the sprite jumps a whole cell. The TypeScript `x += speed` is a lie the hardware does not tell.

:::

## Theory

### Section 1: The Mirror Maze

The screen is 160 TIA pixels wide and 192 visible lines. The maze uses **ten unique columns × eleven rows**, each cell 8 × 16 pixels. A cell is exactly two playfield chunks: chunks 0-3 are `PF0` bits 4-7, chunks 4-11 are `PF1` bits 7-0, and chunks 12-19 are `PF2` bits 0-7. A wall cell sets both of its chunks; an open cell is empty.

`CTRLPF` bit 0 = 1 selects reflect mode. The TIA draws the left half (chunks 0-19, visible columns 0-9) and then mirrors it: visible column 10 is the mirror of unique column 9, visible column 15 the mirror of unique column 4, and visible column 19 the mirror of unique column 0. The game's transform is:

```text
unique = col < 10 ? col : 19 - col
```

The ten unique columns therefore produce twenty visible columns with no split-playfield kernel. A wall at unique column 4 is drawn at visible columns 4 and 15; the movement code asks the same wall-map bit for both.

The mirror has a consequence the design leans into: the two visible halves are **separate copies connected only at the seam**. The seam is the right edge of unique column 9, drawn at visible columns 9 and 10. A unique cell at column 9 is open only on the generator's two seam rows (4 and 6 in this maze), so the player crosses from the left copy to the right copy at those rows. Every other cell's mirror is a second, visually distinct cell that shares the same wall bit. A key placed at visible column 15 is the mirror of unique column 4; the player must cross the seam and walk back to it.

| Unique cell | Visible positions | Wall bit |
|---|---|---|
| column 0 | 0 and 19 | bit 9 |
| column 4 | 4 and 15 | bit 5 |
| column 9 | 9 and 10 | bit 0 |

The status band uses the same mirror. Three key slots start at unique cells 2, 5 and 8 (visible X=16, 40 and 64). An empty slot is the cell's **left** 4-pixel chunk, so its mirror is the mirrored cell's **right** chunk at X=140, 116 and 92. A collected key adds the right chunk, making a full 8-pixel slot; the full-slot mirrors start at X=136, 112 and 88. The first key fills the outer pair, the second the middle pair, the third the inner pair.

::: tip Why the icons are not exactly three blocks
The playfield has no "left half only" mode: every set chunk is drawn in both halves, mirrored or repeated. The three slots are therefore three pairs, and the band shows six blocks. That is a property of the hardware, not a bug; the lesson names it and uses it.
:::

### Section 2: The Generator and the Spec

`maze-spec.txt` is five lines:

```text
seed 20261010
width 10
height 11
keys 3
enemies 2
```

`lesson71-generate.py` is Python 3 with no third-party dependencies. It has five jobs:

1. **Parse** the spec, with `spec:line` errors for every invalid field.
2. **Build** a perfect maze on the 10 × 11 cell grid with a recursive backtracker.
3. **Open the seam** at the right edge of unique column 9 on two even rows.
4. **Place** three keys in dead ends and two enemy starts away from the player.
5. **Emit** a deterministic ACME include, with `--check` to compare against the committed copy.

The backtracker starts at the bottom-left room `(0, 10)`. The rooms are the even coordinates: columns 0, 2, 4, 6, 8 and rows 0, 2, 4, 6, 8, 10, thirty rooms. Every cell starts as a wall. The backtracker visits a room, picks an unvisited neighbour two cells away, opens the wall cell between them, and pushes the neighbour. Thirty rooms and twenty-nine carves make fifty-nine open cells in a tree: every open cell is reachable and there are no loops. The two seam cells are leaves added to rooms at column 8, so the tree property survives.

The keys are placed by searching the dead ends. A dead end is an open cell with exactly one open neighbour. The generator enumerates every triple of dead ends and every collection order, measures the route with breadth-first search on the **visible** 20 × 11 grid (the mirror halves are connected only at the seam), and keeps the shortest tour that satisfies the capture window:

- the first key must be reached by about frame 320;
- the whole route must finish by about frame 580;
- at least one key must be in the mirror half, so the demo crosses the seam;
- the three keys must use three different unique cells (a key and its mirror are the same cell), include at least one key in the top half and one in the bottom half, and include at least one in the mirror half.

The result for the committed spec: keys at visible `(4,10)`, `(19,8)` and `(11,0)` in collection order, with route steps 20, 49 and 65. The enemy starts are `(0,0)` and `(18,10)`, both open cells away from the player. The generator simulates the main's greedy enemies against the route and only commits a pair that is not caught; the route and the placements are deterministic for the seed.

`--check` regenerates the include in memory and compares it with the committed file; it never writes. A deliberate edit fails with a unified diff. CI never runs Python: the committed include is the build input, and `--check` is the author's promise that it is still the deterministic image of the spec.

```bash
# from lessons/part10-capstones/71-maze-explorer
python3 lesson71-generate.py --spec maze-spec.txt --out maze-data.inc
python3 lesson71-generate.py --spec maze-spec.txt --out maze-data.inc --check
python3 lesson71-generate.py --spec maze-spec.txt --report
```

The parser also accepts optional `key <col> <row>` and `enemy <col> <row>` overrides for tests. A key on a wall reports `spec:6: key (1,1) is a wall cell`; a key that is open but not a dead end reports `spec:6: key (2,10) is not in a dead end`; a width that the kernel cannot draw reports the width line.

### Section 3: The Storage

The include has four data groups and the constants:

| Label | Size | What it holds |
|---|---:|---|
| `MazePF` | 11 × 3 bytes | The playfield rows: `PF0` chunks 0-3, `PF1` chunks 4-11, `PF2` chunks 12-19 |
| `MazeWalls` | 11 × 2 bytes | Ten wall bits per row; bit 9 is the leftmost unique column |
| `KeyCells` | 3 × 2 bytes | Visible column and row of each key, in collection order |
| `EnemyCells` | 2 × 2 bytes | Visible column and row of each enemy start |
| `DemoPath` | 65 bytes | Direction codes: 0 up, 1 down, 2 left, 3 right |
| Constants | — | `MazeRows = 11`, `MazeCols = 10`, `MazeStartCol = 0`, `MazeStartRow = 10`, `KeyCount = 3`, `EnemyCount = 2`, `DemoStart = 120`, `DemoPeriod = 5`, `DemoSteps = 65` |

The wall map's bit order is the part to get right. The first byte holds bits 9..2 (unique column 0 in bit 7, column 7 in bit 0); the second byte holds bits 1..0 (column 8 in bit 1, column 9 in bit 0). A wall cell sets its bit; an open cell clears it. The movement's `WallCheck` mirrors the visible column, loads the row's two bytes, and masks the bit with a 10-entry `WallMask` table.

The `MazePF` bytes and the wall map are two views of the same grid. Both are derived from `grid` by the same generator, and the generator re-derives each PF row from the packed wall map and compares it: `--report` prints `PF/wall rows: 11/11 agree` (0 mismatches). Each wall cell sets its two chunks:

| Unique cell | Chunks | `PF0` | `PF1` | `PF2` |
|---|---|---|---|---|
| 0 | 0-1 | bits 4-5 (`$30`) | — | — |
| 1 | 2-3 | bits 6-7 (`$C0`) | — | — |
| 2 | 4-5 | — | bits 7-6 (`$C0`) | — |
| 3 | 6-7 | — | bits 5-4 (`$30`) | — |
| 4 | 8-9 | — | bits 3-2 (`$0C`) | — |
| 5 | 10-11 | — | bits 1-0 (`$03`) | — |
| 6 | 12-13 | — | — | bits 0-1 (`$03`) |
| 7 | 14-15 | — | — | bits 2-3 (`$0C`) |
| 8 | 16-17 | — | — | bits 4-5 (`$30`) |
| 9 | 18-19 | — | — | bits 6-7 (`$C0`) |

For the committed maze, row 0 (unique `.........#`) is `PF0 $00`, `PF1 $00`, `PF2 $C0`: only the rightmost cell is a wall, and its mirror draws the leftmost cell of the right half. Row 1 (`####.#####`) is `$F0, $F3, $FF`; the open cell at unique column 4 is an 8-pixel gap at X=32-39, mirrored at X=120-127.

### Section 4: The Cell/Pixel Transform and the Movement

A cell is 8 pixels wide and 16 lines tall. The sprite position is:

```text
X = col * 8
Y = 16 + row * 16
```

The `16` is the status-and-setup band: picture lines 0-15 are above the maze, so row 0 starts on picture line 16. Visible column 19 spans X=152-159; visible row 10 spans lines 176-191. The screen is exactly filled.

The player starts at `(0,10)`. A joystick direction tries the next cell; a held direction repeats every 8 frames (the reload is `MOVE_DELAY - 1`, so the next move lands on the 8th frame, not the 9th). The target is computed in the visible grid, then mirrored to the unique wall map:

```asm
CheckTarget:
    LDA TempCol
    CMP #(MAZE_COLS_VIS / 2)     ; 10
    BCC HaveUnique
    LDA #(MAZE_COLS_VIS - 1)     ; 19
    SEC
    SBC TempCol
HaveUnique:
    LDX TempRow
    JSR WallCheck
    BNE MoveBlocked
    LDA TempCol
    STA PlayerCol
    LDA TempRow
    STA PlayerRow
```

The move is committed only when the target is open, and the cell compare runs immediately: a player who walks into an enemy's cell loses. `WallCheck` turns the unique column and row into the wall-map byte and its bit:

```asm
WallCheck:
    STA TempU
    TXA
    ASL                     ; row * 2
    TAX
    LDA TempU
    CMP #8
    BCS WallLow
    TAY
    LDA MazeWalls,X         ; columns 0-7: the first byte
    JMP WallHave
WallLow:
    SEC
    SBC #8
    TAY
    LDA MazeWalls+1,X       ; columns 8-9: the second byte
WallHave:
WallRead:                   ; checkpoint: A = the wall-map byte
    STA TempByte
    LDA TempU
    TAY
    LDA WallMask,Y
    AND TempByte
    RTS
```

A zero result means open (the target cell's bit is clear). The bounds are checked first: `col 0` left, `col 19` right, `row 0` up, `row 10` down. The wall map includes the border cells; the bounds are the safety net for the edges.

Two worked examples:

| Player | Direction | Target | Unique | Result |
|---|---|---|---|---|
| `(9,10)` | right | col 10 | `19-10 = 9` | the seam: open when unique column 9 is open |
| `(15,8)` | left | col 14 | `19-14 = 5` | the wall bit for unique column 5 |

The mirror is symmetric: a wall at unique column 4 blocks visible column 4 and visible column 15, because both map to column 4. The generated maze has such walls in rows 3, 5 and 9.

### Section 5: The Row-Table Kernel

The visible screen is three pieces:

| Picture lines | Lines | What happens |
|---|---:|---|
| 0-7 | 8 | The status band: three key slots and their mirrors; `PF0/PF1/PF2` from `IconTable[KeysLeft]` |
| 8-15 | 8 | The first maze row's setup: line 8 clears the icons, line 9 loads maze row 0's PF bytes and decodes object row 0, line 14 clears the graphics latches, line 15 writes the ball and P0 (`VDEL`); P1 is written immediately on line 16 |
| 16-191 | 176 | The maze: 11 rows × 16 lines; the 44-byte `ObjRowTable` drives a player, two enemies and a key |

`8 + 8 + 176 = 192`. The four positioners run **in VBLANK**, before the visible block: one divide-by-15 routine for P0, P1, M0 and the ball, then one `HMOVE`. This is the change the frame demanded. In the visible block the four divides plus the next target computation can exceed a line; the right-edge target (156 = 10 × 15 + 6) is the worst case, and a spill pushes the next positioner into a second line. In VBLANK each divide has the whole line, and the measured frame is 259/37/53/229.

The maze kernel is 44 object rows of four lines, unrolled as eleven maze rows of four object rows. The first line of an object row writes P1 immediately and the missile; the first object row of a maze row also stores the three PF bytes:

```asm
MazeRowLoop:
    LDA PF0Val
    STA PF0                 ; completes at cycle 6
    LDA CurP1
    STA GRP1                ; 12, immediate (VDELP1 is off)
    LDA CurM0
    STA ENAM0               ; 18
    LDA PF1Val
    STA PF1                 ; 25
    LDA PF2Val
    STA PF2                 ; 32
    STA WSYNC               ; line 1
```

The deadlines are `(0 + 68) / 3 = 22.7` cycles for `PF0`, P1 and `ENAM0` (the missile's enable is latched like the playfield; the output delay affects the `RESP` timing, not the enable), `(16 + 68) / 3 = 28.0` for `PF1` (chunk 4 starts at X=16), and `(48 + 68) / 3 = 38.7` for `PF2` (chunk 12 starts at X=48). The ten later maze rows enter the loop at cycle 0, so their five stores complete at 6/12/18/25/32. The first maze row runs `MazeRowStart`'s `LDX` first (Stella reports 53/2), so its completions are 8/14/20/27/34. The deadlines are 22.7/22.7/22.7/28.0/38.7; the first row's `PF1` keeps one cycle, the later rows three.

The other object rows have only two early stores: P1 at 6 and `ENAM0` at 12. The playfield and the missile hold their values for the rest of the 16-line maze row; only `ENAM0` is re-stored on every object row's first line.

The player and the enemies are 8 × 16: four object rows, sixteen lines (the player's glyph is a 4-pixel bar inside the 8-pixel box). The key is 8 × 8: two object rows, starting at `KeyRow * 4 + 1` (the cell is 16 lines; the key is centred with four blank lines above and four below). The object byte's bits are:

| Bit | Object | What the decode writes |
|---|---|---|
| 0 | player | `GRP0 = $3C` (a four-pixel bar) or 0 |
| 1 | enemy 1 | `GRP1 = $FF` (a full block) or 0 |
| 2 | enemy 2 | `ENAM0 = $02` (the 8-pixel missile) or 0 |
| 3 | key | `ENABL = $02` (the 8-pixel ball) or 0 |

P1 is written **immediately** on the object row's first line; P0 and the ball are written **one line early**. `VDELP0` and `VDELBL` delay P0 and the ball by one line, so line 4 of each object row writes the next row's `GRP0`/`ENABL`; they appear on the next row's first line. P1 has no vertical delay: the old VDELP1 setup lost the second graphics store on the setup line and shifted enemy 1 one object row (4 lines) down. Writing P1 at the top of the first line is both earlier and simpler, and it lines P1 up with P0. The missile is not delayed by VDEL, so `ENAM0` is written on the object row's first line.

The kernel ledger, per object row (four lines, 304 cycles):

| Line | Work | Cycles |
|---|---|---:|
| 1 (first of a maze row) | five stores (`PF0`, P1, `ENAM0`, `PF1`, `PF2`), `WSYNC` | 36 |
| 1 (other) | P1 and `ENAM0`, `WSYNC` | 16 |
| 2 | decode the next object row (four table loads and stores), `WSYNC` | 41 (45 on the last row) |
| 3 | on the last object row of a maze row: `PFIdx` load, three `MazePF` loads and stores, `WSYNC` | 40 (else 3) |
| 4 | P0 and the ball for the next row, `WSYNC` | 21 |

The 4th line's 21 cycles leave 55 cycles in the 76-cycle line; the decode's 45 on the last row leaves 31. The next row's PF bytes are prefetched on line 3 of the last object row, one maze row early; the first line of the next row stores them. This is Pong's two-line lookahead widened to four lines: the object row has three spare lines, and the decode moved to the second one so the graphics stores on line 4 start at cycle 0.

The decode tables are 16 bytes each and are page-aligned with `!align 255,0`, so an indexed load never crosses a page boundary and always takes the same four cycles.

The frame's VBLANK is 37 lines: the 44-tick timer is 2,753 cycles (36.2 lines), and `+wait_timer`'s final `WSYNC` makes the measured 37. The game logic — input, movement, the enemies, the 44-byte table, the icons, the four positioners — fits inside it. The measured checkpoints are `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `MazeRowStart` 53, `OverscanStart` 229.

### Section 6: The Enemy AI

Two enemies move every 8 frames. Each chooses the axis with the larger distance to the player; if that cell is blocked, it tries the other axis; if both are blocked, it stays. An enemy already on the player's cell has a zero delta and **stays**: the catch has already happened, and stepping off would let a player who walks into it survive.

```asm
    LDA AbsX                ; |PlayerCol - EnemyCol|
    ORA AbsY                ; |PlayerRow - EnemyRow|
    BNE EnemyMoveOn
    RTS                     ; same cell: stay, the cell compare catches it
EnemyMoveOn:
    LDA AbsX
    CMP AbsY
    BCC EnemyVerticalFirst
    BEQ EnemyVerticalFirst
    ; horizontal first: left when DeltaX is negative, else right
```

The target is checked through the same mirror transform and the same `WallCheck` as the player. The enemy's own position is a visible cell; the target's unique column is `19 - col` on the right half. The cell compare runs **twice**: after the player's move (so a player who walks into an enemy's cell loses) and after the enemies move (so an enemy that walks into the player loses). A match sets `GameState=2` and the lose flash starts.

The greedy rule is intentionally simple, and the lesson is honest about its limit: it can oscillate at a wall corner (left, right, left) or get stuck in a local minimum. That is the exercise: a direction-persisting or BFS enemy. The main's AI is the baseline the reader improves.

### Section 7: The Keys and the Win/Lose States

The ball is the current key: 8 × 8 pixels, `CTRLPF` bits 4-5 = `11`. It shares `COLUPF` with the walls, so the key is the same blue as the maze. Two presentation choices make it read:

1. **The key blinks** on `Frame` bit 4. In a dead end the 8 × 8 block touches a wall; blinking makes the item's outline move even when the colours match.
2. **The key is centred** in the cell (`Y = 16 + row * 16 + 4`), so the cell shows an 8 × 8 block with four blank lines above and below. A wall cell is a full 16-line block; the key's cell is visibly a half-height block.

The keys are **sequential**. `KeyCells` is in collection order; the ball is at `KeyCells[KeyIndex]`. Entering its cell:

```asm
    INC KeysLeft
    LDA KeysLeft
KeyGet:                     ; checkpoint: A = the new KeysLeft
    CMP #KeyCount
    BCS WinGame
    INC KeyIndex
    LDA KeyIndex
    ASL
    TAX
    LDA KeyCells,X
    STA KeyCol
    LDA KeyCells+1,X
    STA KeyRow
```

After the third key, `GameState=1`. The status band fills as `KeysLeft` grows: 0 keys shows three half-width slots, 1 key fills the outer pair, 2 the middle pair, 3 the inner pair. The win state flashes the playfield green on `Frame` bit 4; the off phase restores the wall blue (`SetWallColour` returns `C_WALL`), so the flash is green↔blue. The lose flash is red↔blue. Fire restarts: Fire restarts: the player returns to `(0,10)`, the enemies to their generated starts, and the key sequence to `KeyCells[0]`.

The icons are a playfield calculation, not the score library: `KeysLeft * 3` indexes a four-entry table of three PF bytes. That avoids the score library's fixed `$A0-$D7` map: the object row table and the game variables own that space instead, and the status band is one line shorter than Breakout's nine-line score.

### Section 8: The Auto-Demo

The captures have to be deterministic. With no joystick direction for 120 frames, the scripted demo takes over and walks one cell every 5 frames along `DemoPath`. The first cell move is **frame 125**, not 120: the idle counter reaches 120, then `DemoCount` counts five frames down. The path is the generator's shortest tour through the three keys in collection order, and the generator's simulator uses the same 125/5 phase and the ROM's frame-8 enemy step, so its predicted key frames match the state log. Any joystick direction returns control to the player and resets the demo.

The demo is the same `TryMove` the player uses: the path's direction codes go through the same wall check and the same key check. The generator simulates the main's greedy enemies against the route and only commits an enemy pair that is not caught; the route is a valid walk, not a series of teleports. The measured timeline:

| Frame | Event |
|---:|---|
| 120 | the demo starts |
| 220 | key 1 collected (`KeyGet` A=1) |
| 365 | key 2 collected (`KeyGet` A=2) |
| 445 | key 3 collected (`KeyGet` A=3) |
| 446 | `GameState=1`, the win flash starts |

The 2 s capture is before frame 120 (the start); the 6 s capture is about frame 285 (the first key collected); the 10 s capture is about frame 565 (the win flash). The generator's `--report` prints the route, the key steps, and the predicted frames; the doc's state logs are the observed values.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson71.bin lessons/part10-capstones/71-maze-explorer/71-maze-explorer.asm
stella build/lesson71.bin
```

The generator is a separate, host-side step. The committed `maze-data.inc` is already the correct include; regenerate it only when the spec or the generator changes:

```bash
cd lessons/part10-capstones/71-maze-explorer
python3 lesson71-generate.py --spec maze-spec.txt --out maze-data.inc
python3 lesson71-generate.py --spec maze-spec.txt --out maze-data.inc --check
```

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 71: Capstone 3 — Maze Explorer — Racing the Beam
; =============================================================================
; Part 10: Capstone Projects
;
; What this program does:
;   A complete maze adventure in 4,096 bytes.  A generated 10 x 11 mirror
;   maze fills the screen: ten unique columns are drawn with reflect mode,
;   so the TIA shows twenty visible columns.  The player walks cell by cell
;   through the corridors, two enemies chase the player with a greedy
;   largest-axis AI, and three sequential keys open the win.  Reaching an
;   enemy's cell loses; collecting the third key wins and flashes the maze
;   green (red for the lose).  Fire restarts.  With no joystick input a
;   deterministic scripted demo walks the generated route so the captures
;   show the start, a collected key, and the win.
;
; The screen (192 visible lines):
;   picture lines 0-7     the status band: three key slots and their
;                         reflect-mode mirrors.  A slot is an 8-pixel-wide
;                         playfield cell; an empty slot is its left 4-pixel
;                         chunk, and a collected key adds the right chunk.
;                         The first key fills the outer pair, the second the
;                         middle pair, the third the inner pair.
;   picture lines 8-15    the first maze row's setup: line 8 clears the icon
;                         playfield; line 9 loads maze row 0's PF bytes and
;                         decodes object row 0; lines 10-13 are blank; line
;                         14 clears the graphics latches; line 15 writes the
;                         ball and P0 (VDEL delivers them on line 16).  P1
;                         is written immediately on line 16's first line.
;                         The four positioners run earlier, in VBLANK: a
;                         divide-by-15 routine for P0, P1, M0 and the ball,
;                         then one HMOVE.  Positioning in VBLANK gives each
;                         divide the whole line; in the visible block the
;                         right-edge divide (the 156-cycle target) would
;                         spill into the next line and grow the frame.
;   picture lines 16-191  the maze: 11 maze rows x 16 lines = 176 lines.
;                         Each maze row holds four 4-line object rows; the
;                         44-byte ObjRowTable has one 4-bit byte per object
;                         row (bit 0 player, bit 1 enemy 1, bit 2 enemy 2,
;                         bit 3 key).  The object row is decoded on its
;                         second line; P1 and the missile are written on its
;                         first line; P0 and the ball on its fourth (VDEL).
;                         The PF bytes load once per 16-line maze row.
;   8 + 8 + 176 = 192.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame is scanline 259, VblankStart 0, BodyStart 37, MazeRowStart 53,
;   OverscanStart 229.
;
; The mirror maze:
;   Ten unique columns x eleven rows; each cell is 8x16 pixels, two playfield
;   chunks.  CTRLPF bit 0 = 1 selects reflect mode, so visible columns 0-9
;   are the unique maze and visible columns 10-19 are its mirror.  The
;   transform is col < 10 ? col : 19 - col; a wall at unique column 4 blocks
;   visible columns 4 and 15.  The generator opens the seam at the right edge
;   of unique column 9 on two even rows so the player can cross between the
;   two visible copies.
;
; The storage:
;   maze-data.inc is generated by lesson71-generate.py from maze-spec.txt.
;   MazePF is 11 rows x 3 bytes (PF0 chunks 0-3, PF1 chunks 4-11, PF2 chunks
;   12-19); a wall cell sets both of its chunks, an open cell is empty.
;   MazeWalls is 11 rows x 2 bytes; bit 9 is the leftmost unique column and
;   the first byte holds bits 9..2 (column 0 in bit 7), the second bits 1..0
;   (column 8 in bit 1, column 9 in bit 0).  1 = wall.
;   KeyCells is 3 x 2 (visible column, row) in collection order; EnemyCells
;   is 2 x 2; DemoPath is the scripted route, one direction per step
;   (0=up, 1=down, 2=left, 3=right).
;
; The movement:
;   The player starts at (0,10).  A joystick direction tries the next cell;
;   a held direction repeats every 8 frames.  The target's visible column is
;   mirrored to the unique wall map, and the row indexes MazeWalls.  A wall
;   blocks; an open cell commits the move.  The player is clamped to the
;   20 x 11 visible grid.  The sprite position is X = col * 8 and
;   Y = 16 + row * 16, set by the positioners and the object row table.
;
; The enemies:
;   Two enemies move every 8 frames.  Each chooses the axis with the larger
;   distance to the player; if that cell is blocked, it tries the other axis;
;   if both are blocked it stays.  An enemy already on the player's cell
;   stays (a zero delta is the catch).  The mirror transform selects the wall
;   map byte.  The cell compare runs after the player's move and after the
;   enemies move; an enemy in the player's cell sets the lose state.
;
; The keys:
;   The ball is the current key (8x8, CTRLPF bits 4-5 = 11).  Entering its
;   cell increments KeysLeft, moves the ball to the next KeyCells entry, and
;   fills the next status slot.  The third key sets the win state.  The keys
;   are sequential: the ball always shows the next key to collect.  The key
;   blinks on Frame bit 4: it shares COLUPF with the walls, and the blink
;   makes the 8x8 block read even when it touches a dead end's wall.
;
; The colours:
;   COLUP0 (P0 and M0) is gold; the player is the 4-pixel bar and M0 the
;   8-pixel block of enemy 2.  COLUP1 (enemy 1) is red.  COLUPF (the walls,
;   the key slots and the ball) is blue; the win wave is green and the lose
;   wave is red.  P0 and M0 share one colour register, so they share gold.
;
; The win and the lose:
;   GameState 0 = play, 1 = win, 2 = lose.  The win flashes the playfield
;   green on Frame bit 4; the lose flashes it red.  Fire restarts: the
;   player returns to (0,10), the enemies to their generated starts, and the
;   key sequence to the first key.
;
; The auto-demo:
;   After 120 frames with no joystick direction the scripted demo takes
;   over and walks one cell every 5 frames along the generated DemoPath.
;   The route visits the three keys in collection order; the generator
;   simulates the greedy enemies against the route and only commits a start
;   pair that is not caught.  Any joystick direction returns control to the
;   player.  The demo is disclosed: the 2 s capture shows the start, the 6 s
;   capture shows the first key collected, and the 10 s capture shows the
;   win.
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80-$AB  ObjRowTable   44 bytes, one 4-bit byte per 4-line object row:
;                          bit 0 player, bit 1 enemy 1, bit 2 enemy 2,
;                          bit 3 key
;   $AC      PlayerCol     visible column, 0..19
;   $AD      PlayerRow     row, 0..10
;   $AE      PrevJoy       the last frame's SWCHA high nibble
;   $AF      MoveTimer     the held-direction repeat counter
;   $B0      Enemy1Col     visible column, 0..19
;   $B1      Enemy1Row     0..10
;   $B2      Enemy2Col
;   $B3      Enemy2Row
;   $B4      EnemyTimer    8..1; at zero both enemies step
;   $B5      KeyCol        the current key's visible column
;   $B6      KeyRow        the current key's row
;   $B7      KeysLeft      collected keys, 0..3
;   $B8      KeyIndex      the next KeyCells entry, 0..2
;   $B9      Frame         the free-running frame counter
;   $BA      GameState     0 = play, 1 = win, 2 = lose
;   $BC      CurP0         the current P0 graphics byte ($3C or 0)
;   $BD      CurP1         the current P1 graphics byte ($FF or 0)
;   $BE      CurM0         the current ENAM0 byte ($02 or 0)
;   $BF      CurBall       the current ENABL byte ($02 or 0)
;   $C0      P0Row         the player's first object row (PlayerRow * 4)
;   $C1      P1Row
;   $C2      M0Row
;   $C3      BallRow
;   $C4      P0RowEnd      P0Row + 4
;   $C5      P1RowEnd
;   $C6      M0RowEnd
;   $C7      BallRowEnd    BallRow + 2
;   $C8      PFIdx         the next MazePF index (row * 3)
;   $C9      PF0Val        the current maze row's PF bytes
;   $CA      PF1Val
;   $CB      PF2Val
;   $CC      TempCol       the target / enemy cell column
;   $CD      TempRow       the target / enemy cell row
;   $CE      TempDir       the direction
;   $CF      TempU         the unique column during a wall check
;   $D0      TempByte      the wall-map byte during a wall check
;   $D1      TargetCol     the enemy's target column
;   $D2      TargetRow     the enemy's target row
;   $D3      DeltaX        PlayerCol - enemy column, signed
;   $D4      DeltaY        PlayerRow - enemy row, signed
;   $D5      AbsX          |DeltaX|
;   $D6      AbsY          |DeltaY|
;   $D7      WhichEnemy    0 or 1
;   $D8      IdleTimer     frames with no joystick direction
;   $D9      DemoCount     the demo's per-step countdown
;   $DA      DemoStep      the next DemoPath index
;   $DB      IconPF0       the status band's PF bytes
;   $DC      IconPF1
;   $DD      IconPF2
;   $DE-$F7  free
;   $F8-$FF  stack
;
; Controls:
;   Left joystick: up/down/left/right moves the player one cell.
;   Fire restarts after the win or the lose.
;
; Checkpoints (the A/X/Y/SP values are the state at the label):
;   StartFrame (259/3), VblankStart (0/5), BodyStart (37/5),
;   MazeRowStart (53, picture line 16), OverscanStart (229),
;   PlayerCell (A=PlayerCol, X=PlayerRow), MoveTry (A=the direction),
;   WallRead (A=the wall-map byte), KeyGet (A=the new KeysLeft),
;   EnemyStep (A=the enemy, 0 or 1), GameStateRead (A=GameState),
;   ObjRowWrite (A=the byte at ObjRowTable+0).
;
; Build: acme -f plain -o build/lesson71.bin \
;        lessons/part10-capstones/71-maze-explorer/71-maze-explorer.asm
; Run:   stella build/lesson71.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44       ; 1 + 43 x 64 = 2753 cycles = 36.2 lines; the
                          ; timer + wait_timer's WSYNC make the measured 37-line VBLANK
OVERSCAN_TIMER = 36       ; 1 + 35 x 64 = 2241 cycles = 29.5 lines; the
                          ; timer + WSYNC make the measured 30-line overscan

STATUS_LINES   = 8        ; the key-icon band: eight 8-line blocks
MAZE_ROWS      = 11       ; picture lines 16-191: 11 x 16
OBJ_ROWS       = 44       ; 11 maze rows x 4 four-line object rows
MAZE_COLS_VIS  = 20       ; 10 unique columns, mirrored by reflect mode

MOVE_DELAY     = 8        ; a held joystick direction repeats every 8 frames
ENEMY_DELAY    = 8        ; both enemies step every 8 frames

P0_BIAS        = 3        ; the Lesson 26 player positioning bias
P1_BIAS        = 3
M0_BIAS        = 4        ; missiles and the ball output one clock earlier
BL_BIAS        = 4

C_WALL         = $96      ; the maze walls, the key icons, the ball/key: blue
C_PLAYER       = $1E      ; P0 and M0: gold (the player's bar, enemy 2)
C_ENEMY        = $46      ; P1 and M1: red
C_WIN          = $C8      ; the win flash: green
C_LOSE         = $46      ; the lose flash: red
C_BG           = $00      ; black

PLAYER_GLYPH   = $3C      ; P0's 16-line solid bar: a 4-pixel-wide player
ENEMY_GLYPH    = $FF      ; P1's 16-line solid block
MISSILE_ON     = $02      ; ENAM0's enable bit
BALL_ON        = $02      ; ENABL's enable bit

; =============================================================================
; RAM ALLOCATION ($80-$DD; $DE-$F7 is free, the stack is $F8-$FF)
; =============================================================================
ObjRowTable = $80         ; 44 bytes ($80-$AB)

PlayerCol   = $AC
PlayerRow   = $AD
PrevJoy     = $AE
MoveTimer   = $AF
Enemy1Col   = $B0
Enemy1Row   = $B1
Enemy2Col   = $B2
Enemy2Row   = $B3
EnemyTimer  = $B4
KeyCol      = $B5
KeyRow      = $B6
KeysLeft    = $B7
KeyIndex    = $B8
Frame       = $B9
GameState   = $BA
CurP0       = $BC
CurP1       = $BD
CurM0       = $BE
CurBall     = $BF
P0Row       = $C0
P1Row       = $C1
M0Row       = $C2
BallRow     = $C3
P0RowEnd    = $C4
P1RowEnd    = $C5
M0RowEnd    = $C6
BallRowEnd  = $C7

PFIdx       = $C8
PF0Val      = $C9
PF1Val      = $CA
PF2Val      = $CB
TempCol     = $CC
TempRow     = $CD
TempDir     = $CE
TempU       = $CF
TempByte    = $D0
TargetCol   = $D1
TargetRow   = $D2
DeltaX      = $D3
DeltaY      = $D4
AbsX        = $D5
AbsY        = $D6
WhichEnemy  = $D7
IdleTimer   = $D8
DemoCount   = $D9
DemoStep    = $DA
IconPF0     = $DB
IconPF1     = $DC
IconPF2     = $DD

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
    STA SWACNT              ; port A is an input port (the joystick)

    LDA #C_PLAYER
    STA COLUP0              ; P0 and M0: gold (the player's bar, enemy 2)
    LDA #C_ENEMY
    STA COLUP1              ; P1: red (enemy 1)
    LDA #C_WALL
    STA COLUPF              ; the walls, the key icons, and the ball/key
    LDA #C_BG
    STA COLUBK
    LDA #$31
    STA CTRLPF              ; reflect mode (bit 0) + an 8-pixel ball (bits 4-5)
    LDA #$30
    STA NUSIZ0              ; missile 0 is 8 pixels wide (enemy 2)
    LDA #$00
    STA NUSIZ1
    STA REFP0
    STA REFP1
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    STA ENAM0
    LDA #$01
    STA VDELP0              ; VDEL: P0's and the ball's graphics written on
    STA VDELBL              ; line n display on line n+1.  P1 is written
                            ; immediately on its object row's first line.
    LDA #$00
    STA VDELP1              ; P1 has no vertical delay

    JSR ResetGame

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

; The status band uses only PF blocks; the sprite latches must be empty.
; VDEL delays the three writes below by one line, so the first visible line
; shows the cleared graphics.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    STA ENAM0

; -----------------------------------------------------------------------------
; 1. THE STATUS BAND'S ICON BYTES (from KeysLeft, 0..3)
; -----------------------------------------------------------------------------
    LDA KeysLeft
    ASL
    CLC
    ADC KeysLeft            ; KeysLeft * 3
    TAY
    LDA IconTable,Y
    STA IconPF0
    LDA IconTable+1,Y
    STA IconPF1
    LDA IconTable+2,Y
    STA IconPF2

; -----------------------------------------------------------------------------
; 2. INPUT: THE JOYSTICK, THE SCRIPTED DEMO, OR THE FIRE RESTART
; -----------------------------------------------------------------------------
    JSR ReadInput

; -----------------------------------------------------------------------------
; 3. THE ENEMIES: BOTH STEP EVERY EIGHT FRAMES AND THE CELLS ARE COMPARED
; -----------------------------------------------------------------------------
    JSR EnemyMove

; -----------------------------------------------------------------------------
; 4. THE 44-BYTE OBJECT ROW TABLE
; -----------------------------------------------------------------------------
    JSR BuildObjRows

; -----------------------------------------------------------------------------
; 5. THE WALL COLOUR (AND THE WIN/LOSE FLASH)
; -----------------------------------------------------------------------------
    JSR SetWallColour

; -----------------------------------------------------------------------------
; 6. THE FOUR POSITIONERS (in VBLANK, so the visible block stays eight lines)
; -----------------------------------------------------------------------------
; Each SetCoarse routine starts on a fresh line, so the four divides and the
; one HMOVE take five VBLANK lines.  Positioning here instead of in the
; visible area gives the four divides the whole line; in the visible block a
; divide that reaches the right edge (the 156-cycle target) would spill into
; the next line and grow the frame by one.
    LDA PlayerCol
    ASL
    ASL
    ASL                     ; X = PlayerCol * 8
    CLC
    ADC #P0_BIAS
    JSR SetCoarseP0
    LDA Enemy1Col
    ASL
    ASL
    ASL
    CLC
    ADC #P1_BIAS
    JSR SetCoarseP1
    LDA Enemy2Col
    ASL
    ASL
    ASL
    CLC
    ADC #M0_BIAS
    JSR SetCoarseM0
    LDA KeyCol
    ASL
    ASL
    ASL
    CLC
    ADC #BL_BIAS
    JSR SetCoarseBL
    STA WSYNC
    STA HMOVE               ; one HMOVE applies all four fine offsets

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE 0-7 — THE STATUS BAND: THREE KEY ICONS (AND THEIR MIRRORS)
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, picture line 0
    LDA IconPF0
    STA PF0
    LDA IconPF1
    STA PF1
    LDA IconPF2
    STA PF2
    LDX #STATUS_LINES
StatusLoop:
    STA WSYNC
    DEX
    BNE StatusLoop

; =============================================================================
; VISIBLE 8-15 — THE FIRST MAZE ROW'S SETUP (EIGHT BLANK/SETUP LINES)
; =============================================================================
; The positioners already ran in VBLANK.  Line 8 clears the icon playfield;
; line 9 loads maze row 0's PF bytes and decodes object row 0; line 14 clears
; the graphics latches; line 15 writes the ball and P0 (VDEL puts them on
; line 16).  P1 is written immediately on line 16's first line.  The maze
; starts on picture line 16, scanline 53.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC               ; line 8 -> 9

    LDA MazePF
    STA PF0Val
    LDA MazePF+1
    STA PF1Val
    LDA MazePF+2
    STA PF2Val
    LDA #3
    STA PFIdx
    ; also decode object row 0 here, so line 15 only has to write the
    ; latched graphics early in the line
    LDA ObjRowTable
    TAY
    LDA ObjP0Tab,Y
    STA CurP0
    LDA ObjP1Tab,Y
    STA CurP1
    LDA ObjM0Tab,Y
    STA CurM0
    LDA ObjBLTab,Y
    STA CurBall
    STA WSYNC               ; line 9 -> 10

    STA WSYNC               ; line 10 -> 11
    STA WSYNC               ; line 11 -> 12
    STA WSYNC               ; line 12 -> 13
    STA WSYNC               ; line 13 -> 14

    ; line 14: clear the graphics latch (VDEL puts the zero on line 15)
    LDA #$00
    STA GRP0
    STA GRP1
    STA ENABL
    STA WSYNC               ; line 14 -> 15

    ; line 15: write object row 0's ball and P0 at the top of the line.  VDEL
    ; displays them on line 16; P1 is written immediately on line 16's first
    ; line, so it needs no setup store.  The ball is stored first because the
    ; third key can sit on row 0.
    LDA CurBall
    STA ENABL
    LDA CurP0
    STA GRP0
    STA WSYNC               ; line 15 -> line 16
    NOP                     ; the label must not sit inside the WSYNC halt

; =============================================================================
; VISIBLE 16-191 — THE MAZE: 11 ROWS x 16 LINES, 44 OBJECT ROWS x 4 LINES
; =============================================================================
; Each object row is four lines.  Line 1 writes P1 (immediate) and the
; missile; on the first object row of a maze row it also stores the three PF
; bytes.  The ten later maze rows enter the loop at cycle 0, so the five
; stores complete at 6 (PF0), 12 (P1), 18 (ENAM0), 25 (PF1) and 32 (PF2).
; The first maze row runs MazeRowStart's LDX first (Stella reports 53/2), so
; its completions are 8/14/20/27/34; the deadlines are 22.7, 22.7, 22.7,
; 28.0 and 38.7 (PF1 keeps one cycle on the first row).  The other object
; rows store only P1 and ENAM0, at 6 and 12.  Line 2 decodes the next object row;
; line 3 prefetches the next maze row's PF; line 4 writes P0 and the ball
; for the next row (VDEL displays them on its first line).
MazeRowStart:               ; checkpoint: scanline 53, picture line 16
    LDX #0                  ; the object-row index, 0..43
MazeRowLoop:
    ; --- object row 0, line 1: the PF bytes + P1 + ENAM0 --------------------
    ; The first line of a maze row starts at cycle 0 (the LDX is on line 15),
    ; so the five stores complete at 6/12/18/25/32: PF0 6, P1 12, ENAM0 18,
    ; PF1 25, PF2 32.  The deadlines are 22.7/22.7/22.7/28.0/38.7.
    LDA PF0Val
    STA PF0
    LDA CurP1
    STA GRP1                ; P1 is immediate (VDELP1 is off)
    LDA CurM0
    STA ENAM0
    LDA PF1Val
    STA PF1
    LDA PF2Val
    STA PF2
    STA WSYNC               ; line 1
    ; line 2: decode the next object row
    LDA ObjRowTable+1,X
    TAY
    LDA ObjP0Tab,Y
    STA CurP0
    LDA ObjP1Tab,Y
    STA CurP1
    LDA ObjM0Tab,Y
    STA CurM0
    LDA ObjBLTab,Y
    STA CurBall
    STA WSYNC               ; line 2
    STA WSYNC               ; line 3
    ; line 4: P0 and the ball for the next row (VDEL)
    LDA CurP0
    STA GRP0
    LDA CurBall
    STA ENABL
    STA WSYNC               ; line 4
    INX

    ; --- object row 1 -------------------------------------------------------
    LDA CurP1
    STA GRP1
    LDA CurM0
    STA ENAM0
    STA WSYNC               ; line 1
    LDA ObjRowTable+1,X
    TAY
    LDA ObjP0Tab,Y
    STA CurP0
    LDA ObjP1Tab,Y
    STA CurP1
    LDA ObjM0Tab,Y
    STA CurM0
    LDA ObjBLTab,Y
    STA CurBall
    STA WSYNC               ; line 2
    STA WSYNC               ; line 3
    LDA CurP0
    STA GRP0
    LDA CurBall
    STA ENABL
    STA WSYNC               ; line 4
    INX

    ; --- object row 2 -------------------------------------------------------
    LDA CurP1
    STA GRP1
    LDA CurM0
    STA ENAM0
    STA WSYNC               ; line 1
    LDA ObjRowTable+1,X
    TAY
    LDA ObjP0Tab,Y
    STA CurP0
    LDA ObjP1Tab,Y
    STA CurP1
    LDA ObjM0Tab,Y
    STA CurM0
    LDA ObjBLTab,Y
    STA CurBall
    STA WSYNC               ; line 2
    STA WSYNC               ; line 3
    LDA CurP0
    STA GRP0
    LDA CurBall
    STA ENABL
    STA WSYNC               ; line 4
    INX

    ; --- object row 3: the last row of the maze row --------------------------
    LDA CurP1
    STA GRP1
    LDA CurM0
    STA ENAM0
    STA WSYNC               ; line 1
    CPX #(OBJ_ROWS - 1)
    BEQ MazeLastDecode
    LDA ObjRowTable+1,X
    TAY
    LDA ObjP0Tab,Y
    STA CurP0
    LDA ObjP1Tab,Y
    STA CurP1
    LDA ObjM0Tab,Y
    STA CurM0
    LDA ObjBLTab,Y
    STA CurBall
MazeLastDecode:
    STA WSYNC               ; line 2
    ; line 3: prefetch the next maze row's PF bytes
    CPX #(OBJ_ROWS - 1)
    BEQ MazeNoPrefetch
    LDY PFIdx
    LDA MazePF,Y
    STA PF0Val
    LDA MazePF+1,Y
    STA PF1Val
    LDA MazePF+2,Y
    STA PF2Val
    TYA
    CLC
    ADC #3
    STA PFIdx
MazeNoPrefetch:
    STA WSYNC               ; line 3
    LDA CurP0
    STA GRP0
    LDA CurBall
    STA ENABL
    STA WSYNC               ; line 4
    INX
    CPX #OBJ_ROWS
    BEQ MazeKernelDone
    JMP MazeRowLoop
MazeKernelDone:
    ; 11 maze rows x 16 lines = 176; the last WSYNC releases at scanline 229.

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
; READ INPUT — the joystick, the scripted demo, or the fire restart
; =============================================================================
; SWCHA's P0 high nibble is active low: bit 4 up, 5 down, 6 left, 7 right.
; A held direction repeats every MOVE_DELAY frames.  With no direction for
; DEMO_START frames the DemoPath takes over, one cell every DemoPeriod
; frames.  Any direction resets the idle timer and the demo.
ReadInput:
    LDA GameState
GameStateRead:              ; checkpoint: A = GameState
    BNE GameOverInput

    LDA SWCHA
    AND #$F0
    CMP #$F0
    BNE ManualInput

    ; --- no direction: count the idle frames, then follow the demo path ---
    LDA #$FF
    STA PrevJoy
    LDA IdleTimer
    CMP #DemoStart
    BCS DemoTick
    INC IdleTimer
    RTS
DemoTick:
    DEC DemoCount
    BNE ReadDone
    LDA #DemoPeriod
    STA DemoCount
    LDX DemoStep
    CPX #DemoSteps
    BCS ReadDone
    LDA DemoPath,X
    INC DemoStep
    JSR TryMove
    RTS

    ; --- a direction is held: manual control ---
ManualInput:
    LDA #$00
    STA IdleTimer
    STA DemoStep
    LDA #DemoPeriod
    STA DemoCount
    LDA SWCHA
    AND #$F0
    CMP PrevJoy
    BEQ ManualSame
    LDA #$00
    STA MoveTimer           ; a new direction moves immediately
ManualSame:
    LDA SWCHA
    AND #$F0
    STA PrevJoy
    LDA MoveTimer
    BNE ManualCount
    LDA #(MOVE_DELAY - 1)   ; the reload plus this frame makes 8
    STA MoveTimer
    JSR DirFromJoy
    JSR TryMove
    RTS
ManualCount:
    DEC MoveTimer
ReadDone:
    RTS

; --- the win or the lose: fire restarts ---
GameOverInput:
    LDA INPT4
    AND #$80                ; bit 7 is 0 while fire is pressed
    BNE ReadDone
    JSR ResetGame
    RTS

; =============================================================================
; DIR FROM JOY — A = 0 up, 1 down, 2 left, 3 right
; =============================================================================
DirFromJoy:
    LDA SWCHA
    AND #$10
    BEQ DirUp
    LDA SWCHA
    AND #$20
    BEQ DirDown
    LDA SWCHA
    AND #$40
    BEQ DirLeft
    LDA SWCHA
    AND #$80
    BEQ DirRight
    LDA #$FF                ; no direction (the caller checked already)
    RTS
DirUp:
    LDA #$00
    RTS
DirDown:
    LDA #$01
    RTS
DirLeft:
    LDA #$02
    RTS
DirRight:
    LDA #$03
    RTS

; =============================================================================
; TRY MOVE — A = the direction; the player moves one cell if it is open
; =============================================================================
TryMove:
MoveTry:                    ; checkpoint: A = the direction
    STA TempDir
    LDA PlayerCol
    LDX PlayerRow
PlayerCell:                 ; checkpoint: A = PlayerCol, X = PlayerRow
    STA TempCol
    STX TempRow
    LDX TempDir
    CPX #$00
    BEQ TryUp
    CPX #$01
    BEQ TryDown
    CPX #$02
    BEQ TryLeft
    ; right
    LDA TempCol
    CMP #(MAZE_COLS_VIS - 1)
    BCS MoveBlocked
    CLC
    ADC #1
    STA TempCol
    JMP CheckTarget
TryUp:
    LDA TempRow
    BEQ MoveBlocked
    DEC TempRow
    JMP CheckTarget
TryDown:
    LDA TempRow
    CMP #(MAZE_ROWS - 1)
    BCS MoveBlocked
    INC TempRow
    JMP CheckTarget
TryLeft:
    LDA TempCol
    BEQ MoveBlocked
    DEC TempCol
CheckTarget:
    ; the target's visible column maps to the unique wall-map column
    LDA TempCol
    CMP #(MAZE_COLS_VIS / 2)
    BCC HaveUnique
    LDA #(MAZE_COLS_VIS - 1)
    SEC
    SBC TempCol
HaveUnique:
    LDX TempRow
    JSR WallCheck           ; A = the wall byte, Z = 1 when open
    BNE MoveBlocked
    LDA TempCol
    STA PlayerCol
    LDA TempRow
    STA PlayerRow
    ; the player can walk into an enemy's cell; the cell compare must run
    ; after this move, not only after the enemies move
    JSR CheckCollision
    LDA GameState
    BNE MoveDone
    JMP CheckKeys
MoveDone:
    RTS
MoveBlocked:
    RTS

; =============================================================================
; CHECK KEYS — the player entered the current key's cell?
; =============================================================================
CheckKeys:
    LDA PlayerCol
    CMP KeyCol
    BNE KeysDone
    LDA PlayerRow
    CMP KeyRow
    BNE KeysDone
    INC KeysLeft
    LDA KeysLeft
KeyGet:                     ; checkpoint: A = the new KeysLeft
    CMP #KeyCount
    BCS WinGame
    INC KeyIndex
    LDA KeyIndex
    ASL                     ; KeyIndex * 2
    TAX
    LDA KeyCells,X
    STA KeyCol
    LDA KeyCells+1,X
    STA KeyRow
KeysDone:
    RTS
WinGame:
    LDA #1
    STA GameState
    RTS

; =============================================================================
; WALL CHECK — A = the unique column, X = the row; Z = 1 when open
; =============================================================================
; The wall map's 10 bits are split over two bytes per row.  The first byte
; holds bits 9..2 (unique column 0 in bit 7); the second holds bits 1..0
; (column 8 in bit 1, column 9 in bit 0).  The 10-entry WallMask table turns
; the unique column into its bit.  1 = wall, so Z = 1 (the AND result 0)
; means the cell is open.
WallCheck:
    STA TempU
    TXA
    ASL                     ; row * 2
    TAX
    LDA TempU
    CMP #8
    BCS WallLow
    TAY
    LDA MazeWalls,X
    JMP WallHave
WallLow:
    SEC
    SBC #8
    TAY
    LDA MazeWalls+1,X
WallHave:
WallRead:                   ; checkpoint: A = the wall-map byte
    STA TempByte
    LDA TempU
    TAY
    LDA WallMask,Y
    AND TempByte
    RTS

; =============================================================================
; ENEMY MOVE — both enemies step every eight frames, then the cells compare
; =============================================================================
EnemyMove:
    LDA GameState
    BNE EnemyDone           ; the win and the lose freeze the enemies
    DEC EnemyTimer
    BNE EnemyDone
    LDA #ENEMY_DELAY
    STA EnemyTimer
    LDA #0
    JSR EnemyOne
    LDA #1
    JSR EnemyOne
    JSR CheckCollision
EnemyDone:
    RTS

; -----------------------------------------------------------------------------
; ENEMY ONE — A = the enemy (0 or 1); greedy step toward the player
; -----------------------------------------------------------------------------
EnemyOne:
EnemyStep:                  ; checkpoint: A = the enemy (0 or 1)
    STA WhichEnemy
    LDA WhichEnemy
    BNE EnemyTwoCell
    LDA Enemy1Col
    STA TempCol
    LDA Enemy1Row
    STA TempRow
    JMP EnemyHaveCell
EnemyTwoCell:
    LDA Enemy2Col
    STA TempCol
    LDA Enemy2Row
    STA TempRow
EnemyHaveCell:
    ; DeltaX = PlayerCol - enemy column; DeltaY = PlayerRow - enemy row
    LDA PlayerCol
    SEC
    SBC TempCol
    STA DeltaX
    LDA PlayerRow
    SEC
    SBC TempRow
    STA DeltaY

    ; |DeltaX| and |DeltaY|
    LDA DeltaX
    BPL EnemyDxAbs
    EOR #$FF
    CLC
    ADC #1
EnemyDxAbs:
    STA AbsX
    LDA DeltaY
    BPL EnemyDyAbs
    EOR #$FF
    CLC
    ADC #1
EnemyDyAbs:
    STA AbsY

    ; An enemy on the player's cell must not step off it: the collision is a
    ; cell compare, so a zero delta means the catch has already happened.
    LDA AbsX
    ORA AbsY
    BNE EnemyMoveOn
    RTS
EnemyMoveOn:

    ; The axis with the larger distance goes first; a tie tries vertical.
    LDA AbsX
    CMP AbsY
    BCC EnemyVerticalFirst
    BEQ EnemyVerticalFirst

    ; --- horizontal first ---
    LDA DeltaX
    BMI EnemyHorizLeft
    LDA #3
    JMP EnemyTryHoriz
EnemyHorizLeft:
    LDA #2
EnemyTryHoriz:
    JSR EnemyTry
    BCS EnemyMoved
    ; blocked: try vertical
    LDA DeltaY
    BMI EnemyVertUp
    LDA #1
    JMP EnemyTryVert
EnemyVertUp:
    LDA #0
EnemyTryVert:
    JSR EnemyTry
    BCS EnemyMoved
    RTS                     ; both blocked: stay

    ; --- vertical first ---
EnemyVerticalFirst:
    LDA DeltaY
    BMI EnemyVertUp2
    LDA #1
    JMP EnemyTryVert2
EnemyVertUp2:
    LDA #0
EnemyTryVert2:
    JSR EnemyTry
    BCS EnemyMoved
    LDA DeltaX
    BMI EnemyHorizLeft2
    LDA #3
    JMP EnemyTryHoriz2
EnemyHorizLeft2:
    LDA #2
EnemyTryHoriz2:
    JSR EnemyTry
    BCS EnemyMoved
    RTS                     ; both blocked: stay

EnemyMoved:
    ; commit the target cell to the enemy
    LDA WhichEnemy
    BNE EnemyMovedTwo
    LDA TempCol
    STA Enemy1Col
    LDA TempRow
    STA Enemy1Row
    RTS
EnemyMovedTwo:
    LDA TempCol
    STA Enemy2Col
    LDA TempRow
    STA Enemy2Row
    RTS

; =============================================================================
; ENEMY TRY — A = the direction; TempCol/TempRow = the enemy's cell
; =============================================================================
; Returns C = 1 and updates TempCol/TempRow when the target cell is open;
; C = 0 when the target is outside the grid or a wall.
EnemyTry:
    STA TempDir
    LDA TempCol
    STA TargetCol
    LDA TempRow
    STA TargetRow
    LDX TempDir
    CPX #$00
    BEQ ETryUp
    CPX #$01
    BEQ ETryDown
    CPX #$02
    BEQ ETryLeft
    ; right
    LDA TargetCol
    CMP #(MAZE_COLS_VIS - 1)
    BCS ETryBlocked
    INC TargetCol
    JMP ETryCheck
ETryUp:
    LDA TargetRow
    BEQ ETryBlocked
    DEC TargetRow
    JMP ETryCheck
ETryDown:
    LDA TargetRow
    CMP #(MAZE_ROWS - 1)
    BCS ETryBlocked
    INC TargetRow
    JMP ETryCheck
ETryLeft:
    LDA TargetCol
    BEQ ETryBlocked
    DEC TargetCol
ETryCheck:
    LDA TargetCol
    CMP #(MAZE_COLS_VIS / 2)
    BCC ETryUnique
    LDA #(MAZE_COLS_VIS - 1)
    SEC
    SBC TargetCol
ETryUnique:
    LDX TargetRow
    JSR WallCheck
    BNE ETryBlocked
    LDA TargetCol
    STA TempCol
    LDA TargetRow
    STA TempRow
    SEC
    RTS
ETryBlocked:
    CLC
    RTS

; =============================================================================
; CHECK COLLISION — an enemy in the player's cell loses
; =============================================================================
CheckCollision:
    LDA Enemy1Col
    CMP PlayerCol
    BNE CheckEnemy2
    LDA Enemy1Row
    CMP PlayerRow
    BEQ LoseGame
CheckEnemy2:
    LDA Enemy2Col
    CMP PlayerCol
    BNE CollisionDone
    LDA Enemy2Row
    CMP PlayerRow
    BNE CollisionDone
LoseGame:
    LDA #2
    STA GameState
CollisionDone:
    RTS

; =============================================================================
; BUILD OBJECT ROWS — clear 44 bytes, then OR the four object ranges
; =============================================================================
; A 16-line character fills one maze row: four 4-line object rows.  The key
; is 8 lines tall, so it sets two object rows starting at KeyRow * 4 + 1.
BuildObjRows:
    LDX #0
    LDA #$00
ObjClear:
    STA ObjRowTable,X
    INX
    CPX #OBJ_ROWS
    BNE ObjClear

    ; the player: bit 0
    LDA PlayerRow
    ASL
    ASL
    STA P0Row
    CLC
    ADC #4
    STA P0RowEnd
    LDX P0Row
ObjP0:
    LDA ObjRowTable,X
    ORA #$01
    STA ObjRowTable,X
    INX
    CPX P0RowEnd
    BNE ObjP0

    ; enemy 1: bit 1
    LDA Enemy1Row
    ASL
    ASL
    STA P1Row
    CLC
    ADC #4
    STA P1RowEnd
    LDX P1Row
ObjP1:
    LDA ObjRowTable,X
    ORA #$02
    STA ObjRowTable,X
    INX
    CPX P1RowEnd
    BNE ObjP1

    ; enemy 2: bit 2
    LDA Enemy2Row
    ASL
    ASL
    STA M0Row
    CLC
    ADC #4
    STA M0RowEnd
    LDX M0Row
ObjM0:
    LDA ObjRowTable,X
    ORA #$04
    STA ObjRowTable,X
    INX
    CPX M0RowEnd
    BNE ObjM0

    ; the key: bit 3, two 4-line rows (8 pixels tall), centred in the cell.
    ; The key blinks on Frame bit 4: the 8x8 block shares COLUPF with the
    ; walls, and a blink makes the item read even when it touches a wall.
    LDA Frame
    AND #$10
    BNE ObjKeyDone
    LDA KeyRow
    ASL
    ASL
    CLC
    ADC #1
    STA BallRow
    CLC
    ADC #2
    STA BallRowEnd
    LDX BallRow
ObjBall:
    LDA ObjRowTable,X
    ORA #$08
    STA ObjRowTable,X
    INX
    CPX BallRowEnd
    BNE ObjBall
ObjKeyDone:

    LDA ObjRowTable
ObjRowWrite:                ; checkpoint: A = the byte at ObjRowTable+0
    RTS

; =============================================================================
; SET WALL COLOUR — the normal wall colour, or the win/lose flash
; =============================================================================
SetWallColour:
    LDA #C_WALL
    LDX GameState
    BEQ WallColourDone      ; play: the wall colour
    LDA Frame
    AND #$10
    BEQ WallColourNormal    ; the flash's off phase is the wall colour
    LDA #C_WIN
    CPX #1
    BEQ WallColourDone
    LDA #C_LOSE
    JMP WallColourDone
WallColourNormal:
    LDA #C_WALL
WallColourDone:
    STA COLUPF
    RTS

; =============================================================================
; RESET GAME — the shared power-on and fire-restart state
; =============================================================================
ResetGame:
    LDA #MazeStartCol
    STA PlayerCol
    LDA #MazeStartRow
    STA PlayerRow
    LDA #$00
    STA GameState
    STA Frame
    STA KeysLeft
    STA KeyIndex
    STA IdleTimer
    STA DemoStep
    STA MoveTimer
    LDA #$FF
    STA PrevJoy
    LDA #ENEMY_DELAY
    STA EnemyTimer
    LDA #DemoPeriod
    STA DemoCount
    LDA KeyCells
    STA KeyCol
    LDA KeyCells+1
    STA KeyRow
    LDA EnemyCells
    STA Enemy1Col
    LDA EnemyCells+1
    STA Enemy1Row
    LDA EnemyCells+2
    STA Enemy2Col
    LDA EnemyCells+3
    STA Enemy2Row
    RTS

; =============================================================================
; COARSE POSITIONING — the Lesson 26 divide-by-15 routines; no HMOVE here
; =============================================================================
; Input: A = the target X + the object's output bias.  Each routine starts
; on a fresh line, subtracts 15 until the carry clears, turns the negative
; remainder into the signed fine value, stores it in HMxx, and strobes RESxx.
; The caller applies all four fine offsets with one HMOVE.
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

SetCoarseM0:
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
; THE DECODE TABLES — index a 4-bit object-row byte to the four TIA bytes
; =============================================================================
; Index = bit 3 key, bit 2 enemy 2, bit 1 enemy 1, bit 0 player.  Each table
; is page-aligned (!align 255,0), so an indexed load never crosses a page.
    !align 255, 0
ObjP0Tab:
    !byte $00, PLAYER_GLYPH, $00, PLAYER_GLYPH
    !byte $00, PLAYER_GLYPH, $00, PLAYER_GLYPH
    !byte $00, PLAYER_GLYPH, $00, PLAYER_GLYPH
    !byte $00, PLAYER_GLYPH, $00, PLAYER_GLYPH
    !align 255, 0
ObjP1Tab:
    !byte $00, $00, ENEMY_GLYPH, ENEMY_GLYPH
    !byte $00, $00, ENEMY_GLYPH, ENEMY_GLYPH
    !byte $00, $00, ENEMY_GLYPH, ENEMY_GLYPH
    !byte $00, $00, ENEMY_GLYPH, ENEMY_GLYPH
    !align 255, 0
ObjM0Tab:
    !byte $00, $00, $00, $00, MISSILE_ON, MISSILE_ON, MISSILE_ON, MISSILE_ON
    !byte $00, $00, $00, $00, MISSILE_ON, MISSILE_ON, MISSILE_ON, MISSILE_ON
    !align 255, 0
ObjBLTab:
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte BALL_ON, BALL_ON, BALL_ON, BALL_ON, BALL_ON, BALL_ON, BALL_ON, BALL_ON

; =============================================================================
; THE WALL MASK TABLE — the 10 unique columns' bits
; =============================================================================
; Columns 0-7 live in the first wall-map byte as bits 7..0; columns 8-9 live
; in the second byte as bits 1..0.  The same mask table serves both bytes.
WallMask:
    !byte $80, $40, $20, $10, $08, $04, $02, $01, $02, $01

; =============================================================================
; THE STATUS ICON TABLE — KeysLeft (0..3) -> three PF bytes
; =============================================================================
; The three slots start at unique cells 2, 5 and 8, visible X=16, 40 and 64.
; An empty slot is the cell's left 4-pixel chunk (X=16-19, 40-43, 64-67), so
; its reflect-mode mirror is the mirrored cell's RIGHT chunk at X=140-143,
; 116-119 and 92-95.  A collected key adds the right chunk, making a full
; 8-pixel slot; the full-slot mirrors start at X=136, 112 and 88.  Cell 2 is
; PF1 bits 7-6; cell 5 is PF1 bits 1-0; cell 8 is PF2 bits 5-4.  The first
; key fills the outer pair, the second the middle pair, the third the inner.
IconTable:
    !byte $00, $82, $10     ; 0 keys: three half-width slots
    !byte $00, $C2, $10     ; 1 key: X=16 and X=136 filled
    !byte $00, $C3, $10     ; 2 keys: X=40 and X=112 filled
    !byte $00, $C3, $30     ; 3 keys: X=64 and X=88 filled

; =============================================================================
; THE GENERATED MAZE DATA (maze-data.inc, built from maze-spec.txt)
; =============================================================================
    !source "lessons/part10-capstones/71-maze-explorer/maze-data.inc"

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
> `lessons/part10-capstones/71-maze-explorer/71-maze-explorer.asm`. The generated
> data lives in `maze-data.inc`; it is built from `maze-spec.txt` by
> `lesson71-generate.py`, and the source is never edited by hand.

### Code Walkthrough

#### Step 1 — The frame and the VBLANK budget

`StartFrame` is the first VSYNC line (scanline 259). `+vsync` produces 3 lines; `VblankStart` sets `VBLANK`, starts the 44-tick timer, clears the staged graphics, and computes the status band's PF bytes. The VBLANK work is:

1. `ReadInput`: the joystick, the move timer, the demo, or the fire restart.
2. `EnemyMove`: both enemies step every 8 frames and the cells compare.
3. `BuildObjRows`: clear 44 bytes, then OR the player, enemy and key ranges.
4. `SetWallColour`: blue, or the win/lose flash.
5. The four positioners and one `HMOVE`.

The timer is 2,753 cycles. The four positioners take about five lines; the game logic and the table build fit in the rest. `+wait_timer`'s final `WSYNC` absorbs the remainder into the measured 37-line VBLANK.

#### Step 2 — The input, the move timer, and the demo

`ReadInput` reads `SWCHA`'s P0 high nibble (bits 4-7, active low). A held direction repeats every `MOVE_DELAY` (8) frames: the first frame with a new direction sets `MoveTimer=0` so it moves immediately; the reload is `MOVE_DELAY - 1` (7), so the next move lands on the 8th frame, not the 9th. The demo path is followed when the idle timer reaches `DemoStart` (120): `DemoCount` counts down from `DemoPeriod` (5), takes the next `DemoPath` byte, and calls `TryMove`; the first demo step is frame 125.

`TryMove` is the shared movement routine. It reads the player's cell, applies the direction, mirrors the target column, calls `WallCheck`, and commits the move only when the target is open. After committing it calls `CheckCollision`: walking into an enemy's cell loses immediately, before the enemy gets a chance to step away. The `PlayerCell`, `MoveTry` and `WallRead` checkpoints are in this path; the demo uses the same code, so the same checkpoints fire for the demo's moves.

#### Step 3 — The status band and the first maze row

`BodyStart` is picture line 0. The icon PF bytes are already computed in VBLANK from `KeysLeft`; the eight `WSYNC`s hold them for lines 0-7. Line 8 clears the playfield. Line 9 loads `MazePF` row 0 into `PF0Val`/`PF1Val`/`PF2Val`, sets `PFIdx=3`, and decodes object row 0. Lines 10-13 are blank. Line 14 clears the graphics latches. Line 15 writes the ball and P0; `VDEL` puts them on line 16. P1 is not VDEL-delayed: line 16's first line writes it immediately. The kernel's object-row index is set to 0 by `MazeRowStart` on line 16; the first maze line's stores start after that two-cycle `LDX`, while the ten later maze rows enter the loop directly at cycle 0.

#### Step 4 — The maze kernel

The kernel is a 44-iteration loop, written as eleven unrolled maze rows of four object rows. Each object row is four lines:

- **Line 1:** writes P1 immediately and `ENAM0`; on the first object row of a maze row it also stores the three PF bytes. The five stores complete at 6/12/18/25/32, before their deadlines.
- **Line 2:** decodes the next object row with the four decode tables. Moving the decode off line 4 is what lets line 4 start at cycle 0.
- **Line 3:** waits; on the last object row of a maze row, the next row's PF bytes are prefetched from `MazePF`.
- **Line 4:** writes P0 and the ball for the next row (`VDEL` displays them on its first line).

The last object row (index 43) has no next row, so its decode and prefetch are skipped. The last `WSYNC` releases the CPU at scanline 229.

#### Step 5 — The object row table

`BuildObjRows` clears 44 bytes and ORs four ranges:

| Object | Object rows | Bit |
|---|---|---|
| player | `PlayerRow * 4` .. +3 | 0 |
| enemy 1 | `Enemy1Row * 4` .. +3 | 1 |
| enemy 2 | `Enemy2Row * 4` .. +3 | 2 |
| key | `KeyRow * 4 + 1` .. +2 | 3 |

The player and enemies are 16 lines tall (one maze row, four object rows); the key is 8 lines tall (two object rows, centred). The table is rebuilt every frame, so the kernel is a pure reader: it never tests a Y range.

#### Step 6 — The keys, the icons, and the states

The key is the ball. `CheckKeys` compares the player's cell with `KeyCol`/`KeyRow` after every successful move; on a match it increments `KeysLeft`, reports `KeyGet`, and either moves the ball to the next `KeyCells` pair or sets `GameState=1`. `KeysLeft` also indexes `IconTable`, whose four entries are the status band's three PF bytes. The win and lose flash `COLUPF` on `Frame` bit 4; fire restarts through `ResetGame`.

#### Step 7 — The enemies

`EnemyMove` decrements the 8-frame timer. At zero, `EnemyOne` is called with A=0 and A=1. Each call loads the enemy's cell and returns immediately if it is already the player's cell; otherwise it computes the two axis distances and tries the larger axis first. `EnemyTry` computes the target, mirrors the column, calls `WallCheck`, and commits the target to the enemy's cell on success. `CheckCollision` compares both enemies' cells with the player's and sets `GameState=2` on a match; it runs after the player's move and after the enemies move.

## What You Should See

The screen is black above and below the maze. The top band has three key slots and their mirrors: six half-width blue blocks — the slots start at X=16, 40 and 64, and the empty-slot mirrors are the mirrored right chunks at X=140, 116 and 92. Below the band, the maze is a blue wall pattern on black: ten unique columns mirrored to twenty, each cell 8 × 16 pixels, with two openings at the seam. The player is a gold four-pixel bar at the bottom-left; enemy 1 is a red block; enemy 2 is a gold block (the eight-pixel missile); the current key is a blue 8 × 8 block in a dead end and blinks.

At about 2 seconds the player is still at `(0,10)`. The demo starts at frame 120 but its first cell move is frame 125; by 6 seconds it has collected the first key and the outer slot pair is full, and the player is in the mirror half. At about 7.4 seconds the third key sets the win state and the maze flashes green. The three captures are from the committed ROM:

![Maze Explorer's opening screen: the six half-width key slots, the blue mirror maze, the gold player bar at the bottom-left, the red enemy at the top-left, the gold enemy block at the bottom-right, and the blue key at the bottom-left](/images/lesson71/maze-start.png)

*The opening screen, about 2 s after power-on. No keys are collected: all six slots are half width. The player is at `(0,10)`; enemy 1 is at `(1,0)` and enemy 2 at `(17,10)`; the key at `(4,10)` is the blue block at the bottom-left.*

![Maze Explorer after the first key: the outer slot pair is full, the player is in the mirror half, and the red enemy is at the left edge on row 2](/images/lesson71/maze-key.png)

*About 6 s after power-on: the first key is collected (`KeyGet` A=1 at frame 220), so the outer slot pair at X=16 and X=136 is full. The player is at `(11,4)`; enemy 1 is at `(4,2)` (the left edge, second row); enemy 2 is at `(13,6)`.*

![Maze Explorer's win: the maze flashing green, all six key slots full, the gold player bar near the top middle, and the red enemy at the top left](/images/lesson71/maze-win.png)

*About 10 s after power-on: the third key completed the sequence (`KeyGet` A=3 at frame 445, `GameState` 1 at frame 446) and the maze is in its green flash phase. All six slots are full. The player is at `(11,0)`, enemy 1 at `(5,0)` and enemy 2 at `(15,6)`.*

<RomPlayer rom="/roms/part10-capstones/71-maze-explorer/71-maze-explorer.bin" title="Lesson 71 — Capstone 3: Maze Explorer" />

*Javatari starts muted; this ROM is silent, so there is nothing to unmute.*

The debugger tells the same story. Assemble with a symbol list and break at the labelled checkpoints:

```bash
acme -f plain -l build/71-maze-explorer.sym -o build/71-maze-explorer.bin \
  lessons/part10-capstones/71-maze-explorer/71-maze-explorer.asm
grep -E "StartFrame|VblankStart|BodyStart|MazeRowStart|OverscanStart" build/71-maze-explorer.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F04E' docs/public/roms/part10-capstones/71-maze-explorer/71-maze-explorer.bin
```

The measured checkpoints:

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F04E` | 259, cycle 3 | The first VSYNC line |
| `VblankStart` | `$F05C` | 0, cycle 5 | The first VBLANK line |
| `BodyStart` | `$F0D4` | 37, cycle 5 | The first picture line (the status band) |
| `MazeRowStart` | `$F13A` | 53, cycle 2 | The first maze line (picture 16) |
| `OverscanStart` | `$F22E` | 229, cycle 7 | The first overscan line |
| `PlayerCell` | `$F2DD` | A=col, X=row | The player's cell at the move |
| `MoveTry` | `$F2D7` | A=the direction | The direction being tried |
| `WallRead` | `$F380` | A=the wall byte | The wall-map byte before the mask |
| `KeyGet` | `$F34D` | A=the new `KeysLeft` | A key was collected |
| `EnemyStep` | `$F3A5` | A=the enemy (0/1) | One enemy's step |
| `GameStateRead` | `$F243` | A=`GameState` | 0 play, 1 win, 2 lose |
| `ObjRowWrite` | `$F537` | A=`ObjRowTable[0]` | The row table's first byte |

The state log's key lines:

```text
# the frame (one hit per frame)
BP:           1 259 03 -59 | nv-BdIZC 00 2c 05 ff |   StartFrame
BP:           1   0 05 -53 | nv-BdIZc 00 ff 00 fd |   VblankStart
BP:           1  37 05 -53 | nv-BdIZC 00 00 00 ff |   BodyStart
BP:           1  53 02 -62 | nv-BdIZC 00 00 02 ff |   MazeRowStart
BP:           1 229 07 -47 | nv-BdIZC 00 2c 05 ff |   OverscanStart

# the demo's first moves: direction 3 (right) then 0 (up), first step frame 125
BP:         125   2 02 -62 | nv-BdIzc 00 0a 00 fb |   PlayerCell (col 0, row 10)
BP:         130   2 02 -62 | nv-BdIzc 01 0a 00 fb |   PlayerCell (col 1, row 10)
BP:         135   2 02 -62 | nv-BdIzc 02 0a 00 fb |   PlayerCell (col 2, row 10)
BP:         140   2 02 -62 | nv-BdIzc 02 09 00 fb |   PlayerCell (col 2, row 9)
BP:         125   1 69 139 | nv-BdIzc 03 00 00 fb |   MoveTry (right)
BP:         130   1 69 139 | nv-BdIzc 03 01 00 fb |   MoveTry (right)
BP:         135   1 69 139 | nv-BdIzc 00 02 00 fb |   MoveTry (up)
BP:         140   1 69 139 | nv-BdIzc 00 03 00 fb |   MoveTry (up)

# the wall-map byte (the first hit is an enemy check at frame 8)
BP:           8   4 30  22 | Nv-BdIzc f7 02 00 f7 |   WallRead ($F7: row 1, high byte)
BP:           8   6 15 -23 | nv-BdIZc 00 00 01 f7 |   WallRead
BP:           8   9 52  88 | nv-BdIzc 10 14 02 f7 |   WallRead

# the three keys
BP:         220   4 29  19 | nv-BdIzC 01 14 04 fb |   KeyGet (KeysLeft = 1)
BP:         365   4 29  19 | nv-BdIzC 02 10 00 fb |   KeyGet (KeysLeft = 2)
BP:         445   4 30  22 | nv-BdIzC 03 00 08 fb |   KeyGet (KeysLeft = 3)

# the enemies step every 8 frames, enemy 0 then enemy 1
BP:           8   2 00 -68 | nv-BdIZc 00 2c 00 fb |   EnemyStep (enemy 0)
BP:           8   7 16 -20 | nv-BdIZC 01 00 01 fb |   EnemyStep (enemy 1)
BP:          16   2 00 -68 | nv-BdIZc 00 2c 00 fb |   EnemyStep (enemy 0)
BP:          16   7 15 -23 | nv-BdIZC 01 00 00 fb |   EnemyStep (enemy 1)

# the win
BP:         446   1 10 -38 | nv-BdIzc 01 2c 09 fd |   GameStateRead (1)

# the row table's first byte
BP:           1  12 69 139 | nv-BdIZC 02 2b 00 fd |   ObjRowWrite ($02: enemy 1 in row 0)
```

The **lose rule** has two observed cases on scratch data-patched ROMs (the enemy start moved, the code unchanged): with enemy 1 started on the player's cell, `GameStateRead` is A=2 from frame 9 (the enemy stays there and the cell compare catches the player); with enemy 1 at `(1,10)` and the right joystick held, the player's own move into `(1,10)` gives A=2 at frame 2.

The **P1/P0 row alignment** is checked on the committed ROM: at the 2 s capture the red enemy's box is picture lines 16-31 (`(1,0)`) and the player's box is 176-191 (`(0,10)`); a scratch ROM with the player and enemy both on row 0 gives both boxes 16-31, and the enemy's cell is `Enemy1Row * 4 = 0`. The object table at that frame is `$02, $02, $02, $02, $00...` (rows 0-3 set).

The **pixel check** of the three images:

| Image | Size | Title bar | What the pixels show |
|---|---|---|---|
| `maze-start.png` | 1010×807 | `Stella 7.0: "71-maze-explorer"` | TIA area 960×606 at (25,106); 238,320 blue pixels; 3,528 gold; 2,400 red; all six slots 24 px wide (half); the red enemy 73-120×157-206 (col 1, row 0); the gold player bar 37-61×662-711 (col 0, row 10); the gold enemy 2 block 841-888×662-711 (col 17, row 10); the key on (924 blue px in the key cell); no cursor |
| `maze-key.png` | 1010×807 | `Stella 7.0: "71-maze-explorer"` | 238,320 blue; 3,600 gold; 2,400 red; the outer slots 48 px (full) and the other four 24 px (half); the gold player 565-588×359-408 (col 11, row 4); the red enemy 217-264×258-307 (col 4, row 2); the gold enemy 2 649-696×460-509 (col 13, row 6) |
| `maze-win.png` | 1010×807 | `Stella 7.0: "71-maze-explorer"` | 240,624 green pixels (`$C8` `(81,179,80)`); the six slots are green and full; 3,600 gold; 2,400 red; the player 565-588×157-206 (col 11, row 0); the red enemy 265-312×157-206 (col 5, row 0); the gold enemy 2 745-792×460-509 (col 15, row 6); no blue maze (the flash replaces the walls) |

The three TIA-area MD5 hashes differ (`9f17282cb765a23fd449e75d6464358e`, `b6aa89df121c197752ae1d15fdf9af78`, `eabc10bfffdd1a68df038262cb9da8fd`), so the captures are genuinely different states, not three copies of one frame. All three are 1010×807, carry the window frame and the `Stella 7.0: "71-maze-explorer"` title bar, and show no cursor: the pointer was parked at (0,0) before each capture.

> **Capture method.** The three images are `import -window` captures of the committed
> `docs/public/roms/part10-capstones/71-maze-explorer/71-maze-explorer.bin` on display `:0`
> (the mutter window manager supplies the title bar). The start image is one of a burst at
> about 2 s, selected because the player is at `(0,10)` and the blinking key is in its on
> phase; the key image is one of a burst at about 6 s with exactly one slot pair filled; the
> win image is one of a burst at about 10 s in the green flash phase. The emulator's
> start-up takes the first fraction of a second, so the 2 s image is about ROM frame 80, the
> 6 s image about frame 285, and the 10 s image about frame 560. The auto-demo makes the
> states deterministic; the key's blink and the win/lose flash are the only phase choices,
> and the burst selection is disclosed. Three deliberate choices are disclosed: (1) the four
> positioners run in VBLANK, not in the visible block, because the right-edge divide is the
> worst case and a visible-block spill grows the frame by one line; (2) the key icons are
> three **pairs** because reflect mode has no left-half-only mode; (3) the player is gold,
> not green, so the win flash's green does not swallow it. The lose state is verified on a
> scratch data-patched ROM (enemy 1 moved to the player's cell), not by the scripted demo;
> the patch changes only `EnemyCells`, and the committed code path is unchanged.

## Exercises

Each exercise ships a source (`exercise-NN-solution.asm`) that assembles to a 4,096-byte ROM (`exercise-NN-solution.bin`). The solutions build through `npm run roms`, run in Stella, and actually solve the exercise as written. The exercise sources keep the main's frame and checkpoints; the state logs below are from the committed solutions.

### Exercise 1: Fog of war

**Challenge:** Only the cells within two Manhattan steps of the player's cell are drawn; every other wall cell is black. Rebuild the playfield rows every frame from the distance. The sprites stay visible, so an enemy can appear out of the dark.

**Hints:**
1. The `MazePF` rows stay the static truth; the fog is a mask. A visible cell is a wall only if it is within two of the player: for a row at vertical distance `d` (0..2), the horizontal allowance is `2 - d`; the visible columns are `PlayerCol - (2-d)` through `PlayerCol + (2-d)`, clamped to 0..19.
2. The unique cell's two visible positions are `c` and `19 - c`, so a cell is visible if either position is in the horizontal range. Map each visible column with the mirror transform and OR the cell's two chunks from `CellPF0/1/2`.
3. Build a five-row window (`FogPF`, 15 bytes) and an 11-byte `FogIndex` table: rows within two of `PlayerRow` get `(row - PlayerRow + 2) * 3`; the others get `$FF` ("dark").
4. The fog build is too slow for VBLANK. Move it to the **overscan** (30 lines) and build the next frame's window there; the first frame's window is built at reset. The kernel's `LoadFogPF` reads the next row from `FogPF` or loads three zeros.
5. The frozen zoned/row-table geometry is unchanged: the window only changes the three PF bytes per maze row.
6. `Reset` builds the first frame's window before the first visible frame; the overscan rebuilds it for the next frame, so the window is one frame behind the player's latest move.

**Expected Result:** The source assembles to a 4,096-byte ROM (`exercise-01-solution.bin`), and the frame is still 259/37/53/229. At 2 s the screen is black except for the walls within two cells of the player at `(0,10)` (the row-9 wall pair at the left and its mirror), the player, the two enemies and the blinking key. At 6 s the window has followed the player into the mirror half; the visible wall patch is centred on the player's new cell. The demo still collects the keys at frames 221/366/446.

**Solution:** See `exercise-01-solution.asm`.

The window is 15 bytes and the row index is 11; both fit in the main's `$DE-$F7` free space:

```asm
FogPF       = $DE         ; 15 bytes: the five visible rows x 3 PF bytes
FogIndex    = $ED         ; 11 bytes: row -> window index (0,3,6,9,12,$FF)
```

The kernel's prefetch becomes one call in the last object row's line 3:

```asm
    CPX #(OBJ_ROWS - 1)
    BEQ MazeNoPrefetch
    JSR LoadFogPF
MazeNoPrefetch:
```

`LoadFogPF` is the whole reader:

```asm
LoadFogPF:
    LDY PFIdx
    LDA FogIndex,Y
    CMP #$FF
    BEQ LoadFogDark
    TAY
    LDA FogPF,Y
    STA PF0Val
    LDA FogPF+1,Y
    STA PF1Val
    LDA FogPF+2,Y
    STA PF2Val
    INC PFIdx
    RTS
LoadFogDark:
    LDA #$00
    STA PF0Val
    STA PF1Val
    STA PF2Val
    INC PFIdx
    RTS
```

The state log on the committed solution:

```text
# the frame
BP:           2 259 03 -59 | nv-BdIZC 00 2c 05 ff |   StartFrame
BP:           3  37 05 -53 | nv-BdIZC 00 00 00 ff |   BodyStart
BP:           3  53 02 -62 | nv-BdIZC 00 00 02 ff |   MazeRowStart
BP:           3 229 07 -47 | nv-BdIZC 03 2c 05 ff |   OverscanStart

# the demo still collects the three keys (one frame later than the main)
BP:         221   4 28  16 | nv-BdIzC 01 14 04 fb |   KeyGet (1)
BP:         366   4 28  16 | nv-BdIzC 02 10 00 fb |   KeyGet (2)
BP:         446   4 29  19 | nv-BdIzC 03 00 08 fb |   KeyGet (3)
```

A Stella run of the committed solution at 2 s shows the fog: the player at the bottom-left, the two-row wall patch above it and its mirror at the right, and black everywhere else. At 6 s the window has followed the player into the mirror half. (The exercise images are not committed; the committed state log above is the evidence.)

### Exercise 2: Smarter enemies

**Challenge:** The main's enemy chooses the larger axis and tries the other if blocked; it can oscillate at a wall corner and never leave a dead-end corridor. Give each enemy a direction, score all four open neighbours by their Manhattan distance to the player, give the current direction a one-point bonus, and refuse a move into a dead end (degree 1) unless the player is there. The enemy still steps every 8 frames.

**Hints:**
1. Store each enemy's direction in a byte (`Enemy1Dir`, `Enemy2Dir`). The current direction is considered first, so it wins ties.
2. `EnemyScore` returns the target's Manhattan distance, or `$FF` if the target is outside the grid or a wall. It uses the same mirror transform and `WallCheck` as the player.
3. `EnemyConsider` keeps the best score and direction; a candidate equal to the current direction gets a one-point bonus.
4. `EnemyDegree` counts the chosen target's open neighbours with four more wall checks. A degree of 1 is a dead end: refuse it unless the target is the player's cell. If the enemy is already on the player's cell, return immediately (the cell compare catches the player; the score would move the enemy away).
5. The AI is too expensive for the 37-line VBLANK (two enemies with four scores and a degree each). Move `EnemyMove` to the **overscan** and alternate the two enemies one frame apart: enemy 0 at the timer's zero frame, enemy 1 on the next frame. Each still moves every 8 frames.
6. The 30-line overscan (2,241 cycles) holds one enemy's ~900-cycle AI plus the timer's wait; the measured frame stays 259/37/53/229.

**Expected Result:** The source assembles to a 4,096-byte ROM (`exercise-02-solution.bin`), and the frame is still 259/37/53/229. `EnemyStep` fires at scanline 229, alternating A=0 at frames 9, 17, 25... and A=1 at 10, 18, 26... The enemies follow corridors instead of oscillating: a Stella run of the committed solution at 6 s shows them in different cells from the main's frame-300 positions. An enemy already on the player's cell stays (the same-cell check), so the catch is never stepped away. The demo still collects the three keys at frames 220/365/445.

**Solution:** See `exercise-02-solution.asm`.

The direction-persisting loop:

```asm
    LDA #$FE
    STA AbsY                ; the best score ("no move yet")
    LDA #$FF
    STA DeltaX              ; the best direction
    LDA Temp                ; the enemy's current direction
    STA DeltaY
    JSR EnemyConsider
    LDA Temp
    CLC
    ADC #1
    AND #$03
    STA DeltaY
    JSR EnemyConsider
    ; ... three more candidates
```

The dead-end refusal:

```asm
    JSR EnemyScore
    JSR EnemyDegree
    LDA AbsX
    CMP #1
    BNE EnemyCommit
    LDA TargetCol
    CMP PlayerCol
    BNE EnemyStay
    LDA TargetRow
    CMP PlayerRow
    BNE EnemyStay
```

The state log on the committed solution:

```text
# every enemy moves once per 8 frames, one frame apart, in the overscan
BP:           9 229 41  55 | nv-BdIZC 00 2c 05 fb |   EnemyStep (enemy 0)
BP:          10 229 52  88 | nv-BdIzC 01 2c 05 fb |   EnemyStep (enemy 1)
BP:          17 229 41  55 | nv-BdIZC 00 2c 05 fb |   EnemyStep (enemy 0)
BP:          18 229 52  88 | nv-BdIzC 01 2c 05 fb |   EnemyStep (enemy 1)
BP:          25 229 41  55 | nv-BdIZC 00 2c 05 fb |   EnemyStep (enemy 0)
BP:          26 229 52  88 | nv-BdIzC 01 2c 05 fb |   EnemyStep (enemy 1)

# the demo still wins
BP:         220   3 62 118 | nv-BdIzC 01 14 04 fb |   KeyGet (1)
BP:         365   3 69 139 | nv-BdIzC 02 10 00 fb |   KeyGet (2)
BP:         445   3 70 142 | nv-BdIzC 03 00 08 fb |   KeyGet (3)
```

A Stella run of the committed solution at 6 s shows the player at the middle of the maze, the red enemy at the left middle and the gold enemy at the right middle, in different cells from the main's frame-300 positions. (The exercise images are not committed; the state log above is the evidence.)

### Exercise 3: Treasure and timer

**Challenge:** Add a 60-second clock, a bonus key worth two, and a win screen. The clock decrements once per 60 frames and is drawn as a bar between the key slots and the maze; at zero the game loses. The second key in the collection order is the bonus: it adds two to `KeysLeft`, so the first key plus the bonus fills all three slots. The win is a solid green screen with the status band, not the main's flash.

**Hints:**
1. `TimeLeft` (60..0) and `TimeTick` (60..1) are two bytes. Decrement `TimeTick` every frame; at zero reset it to 60 and decrement `TimeLeft`; at zero set `GameState=2`.
2. The bar's width is `TimeLeft / 6` unique cells (0..10), lit from the seam outward: `n=1` is cell 9, `n=10` is every cell. The `TimeBar` table holds the 11 × 3 PF bytes.
3. Draw the bar on picture lines 8-15: store the three bytes at line 8 and hold them for eight `WSYNC`s. The maze's first PF store on line 16 replaces them.
4. The bonus is `KeyIndex == 1`: after `INC KeysLeft`, test the index and `INC KeysLeft` again. `KeyGet` reports 1 then 3; the win comes after the second pickup.
5. The win screen: `BuildObjRows` clears the table when `GameState=1`. Decide the playfield **off the scanline**: in the visible setup's line 10 and in the last object row's line-3 PF prefetch, load `PF0Val`/`PF1Val`/`PF2Val = $FF` when `GameState=1`; the kernel's first line then just stores them. Do not test `GameState` on the PF line: the extra loads move `ENAM0`/`PF1` past their deadlines and leave a 6-px tab under the bar. `SetWallColour` returns the solid green for `GameState=1`.
6. The clock only runs while `GameState=0`; the win/lose freeze it.

**Expected Result:** The source assembles to a 4,096-byte ROM (`exercise-03-solution.bin`), and the frame is still 259/37/53/229 in both the play and the win states. A Stella run of the committed solution at 2 s shows the time bar spanning almost the full width and the three slots half width; the first line of each maze row shows that row's own playfield (no 6-px stub under the bar). `KeyGet` reports A=1 at frame 220 and A=3 at frame 365 (the bonus jumps two); `GameStateRead` is 1 from frame 366. At about 7.5 s the whole maze area is solid green with the six slots full. (The exercise images are not committed; the state log and the run are the evidence.)

**Solution:** See `exercise-03-solution.asm`.

The bonus is a few lines after the increment:

```asm
    INC KeysLeft
    LDA KeyIndex
    CMP #1
    BNE KeyNotBonus
    INC KeysLeft            ; the second key is the bonus key: worth two
KeyNotBonus:
    LDA KeysLeft
KeyGet:                     ; checkpoint: A = the new KeysLeft
```

The win playfield is chosen off the scanline, in the visible setup's line 10 and in the line-3 prefetch (the same block appears in both):

```asm
    LDA GameState
    CMP #1
    BNE SetupPFNotWin
    LDA #$FF
    STA PF0Val
    STA PF1Val
    STA PF2Val
SetupPFNotWin:
```

The kernel's first line then stores `PF0Val`/`PF1Val`/`PF2Val` as usual; `BuildObjRows` has already emptied the object table, so only the solid playfield is drawn.

The state log on the committed solution:

```text
# the bonus key: A jumps from 1 to 3
BP:         220   6 01 -65 | nv-BdIzc 01 14 04 fb |   KeyGet (1)
BP:         365   6 12 -32 | nv-BdIzC 03 10 00 fb |   KeyGet (3, the bonus)
BP:         366   3 10 -38 | nv-BdIzc 01 09 1b fd |   GameStateRead (1)

# the frame
BP:           1 259 03 -59 | nv-BdIZC 00 2c 05 ff |   StartFrame
BP:           2  37 05 -53 | nv-BdIZC 00 00 1e ff |   BodyStart
BP:           2  53 02 -62 | nv-BdIZc 00 00 02 ff |   MazeRowStart
BP:           2 229 07 -47 | nv-BdIZC 03 2c 05 ff |   OverscanStart
```

The win state does not grow the frame: `StartFrame` is 366 259/3, `MazeRowStart` 367 53/2 and `OverscanStart` 367 229/7, the same 259/37/53/229 as the play state.

A Stella run of the committed solution at 2 s shows the near-full time bar; at 7.5 s it shows the solid green win screen with the six slots full. (The exercise images are not committed; the state log above is the evidence.)

## Key Takeaways

- ✅ **A mirror maze is a full-width maze for half the data.** Ten unique columns × 11 rows, each cell two chunks, drawn with `CTRLPF` bit 0 = 1. The transform `col < 10 ? col : 19 - col` is the movement's, the generator's and the reader's shared rule.
- ✅ **The generator is a contract, not a convenience.** `maze-spec.txt` → `lesson71-generate.py` → `maze-data.inc`; the include is committed, `--check` is read-only and exits nonzero on drift, and CI never runs Python.
- ✅ **A wall map is ten bits per row.** Bit 9 is the leftmost unique column; the first byte holds bits 9..2, the second bits 1..0. A 10-entry mask table and a two-byte load answer every move.
- ✅ **The four-line object row is the slack the kernel needs.** The 44-byte table drives a player, two enemies and a key; the first line stores the PF, P1 and missile bytes, the second decodes the next row, and the fourth writes P0 and the ball one line early (`VDEL`). P1 is immediate, which keeps it aligned with P0, and the cell compare runs after the player's move and after the enemies move, so both catches lose.
- ✅ **The positioners belong in VBLANK.** Four divide-by-15 routines and one `HMOVE`; the right-edge divide is the worst case, and the visible block would grow the frame by a line.
- ✅ **The keys are sequential and the icons are playfield.** `KeyCells` is in collection order, `KeysLeft` indexes the status table, and the key is a blinking 8 × 8 ball that shares the walls' colour. The empty slot is the cell's left chunk; its mirror is the mirrored right chunk at X=140/116/92.
- ✅ **A deterministic demo is part of the lesson.** The generated route collects the keys at frames 220/365/445, the win at 446, and the generator uses the same 125/5 demo phase and frame-8 enemy step before it commits the route. The blink and flash phases are the only capture choices, and they are disclosed.

## What's Next

Maze Explorer proves that generated data, a mirror playfield, a four-line object row table and a cell-based state machine can share one 262-line frame. [Lesson 72: Capstone 4 — Your Own Game](/part10-capstones/72-your-game) turns the pipeline on your own idea: a one-page game design document, the RAM, screen and 4K budget worksheets, a milestone plan, and a complete skeleton mini-game with the three `YOUR GAME` sections marked for you to replace. The wall map you just built is a design worksheet with a generator behind it; the next lesson asks you to write the spec.
