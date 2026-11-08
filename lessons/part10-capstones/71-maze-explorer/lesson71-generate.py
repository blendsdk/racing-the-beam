#!/usr/bin/env python3
"""Generate the Lesson 71 mirror-maze tables from a small maze spec.

The generator is the host-side half of the lesson.  It builds a perfect maze
on the 10 x 11 cell grid, opens the mirror seam, places three keys in dead
ends and two enemy starts, and lowers the result into an ACME include: the
playfield bytes, the wall map, the key and enemy cells, the scripted
auto-demo route, and the constants the engine needs.

The 2600 never parses the spec.  The committed ``maze-data.inc`` is the build
input; this script only has to be re-run when the spec or the generator
changes.  ``--check`` is the drift gate: it regenerates the include in memory
and compares it with the committed file, without writing anything.

The spec grammar
================

    # a comment
    seed 20261010        the random seed; the same seed gives the same maze
    width 10             the unique columns (the lesson kernel fixes 10)
    height 11            the rows (the lesson kernel fixes 11)
    keys 3               three keys, collected in the emitted order
    enemies 2            two enemy starts

Optional overrides let a test (or a curious reader) place a key or an enemy
explicitly:

    key 9 10             a key at visible column 9, row 10
    enemy 5 2            an enemy at visible column 5, row 2

Every override is validated with the same rules as the generated placement:
a key must be on an open cell, reachable from the start, and in a dead end.

The maze
========

Cells are either solid wall cells or open floor cells.  A cell is 8 x 16
pixels: two playfield chunks.  The right half of the screen is the TIA's
reflect-mode copy of the left half, so ten unique columns become twenty
visible columns.  The unique cell ``(col, row)`` is drawn at visible columns
``col`` and ``19 - col``.

The maze is a perfect maze: every open cell is connected and there are no
loops.  The recursive backtracker starts at the bottom-left room, the rooms
sit on the even grid coordinates, and a carve removes the wall cell between
two neighbouring rooms.  Two even rows also open the mirror seam (unique
column 9) so the player can walk from the left copy to the right copy.

Usage
=====

    python3 lesson71-generate.py --spec maze-spec.txt --out maze-data.inc
    python3 lesson71-generate.py --spec maze-spec.txt --out maze-data.inc --check
    python3 lesson71-generate.py --spec maze-spec.txt --report

The first form writes the include.  ``--check`` only compares; it exits
nonzero on drift.  ``--report`` prints the maze, the placements, and the
predicted demo timeline.  CI never runs Python: the committed include is the
build input.
"""

from __future__ import annotations

import argparse
import difflib
import itertools
import sys
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

# ---------------------------------------------------------------------------
# The lesson kernel's fixed geometry.  The screen is 20 visible columns and
# 11 rows; the unique maze is the left half plus the seam.  A different grid
# would need a different kernel, so the generator rejects it.
# ---------------------------------------------------------------------------
LESSON_WIDTH = 10
LESSON_HEIGHT = 11
LESSON_KEYS = 3
LESSON_ENEMIES = 2

WIDTH_MIN, WIDTH_MAX = 1, LESSON_WIDTH
HEIGHT_MIN, HEIGHT_MAX = 1, LESSON_HEIGHT
KEY_MIN, KEY_MAX = 1, LESSON_KEYS
ENEMY_MIN, ENEMY_MAX = 1, LESSON_ENEMIES

WALL = 1
OPEN = 0

# Direction codes match the engine's TryMove: 0 up, 1 down, 2 left, 3 right.
DIRS = ((0, -1), (0, 1), (-1, 0), (1, 0))
DIR_NAMES = "UDLR"

# The demo timing is part of the contract between the generator's prediction
# and the engine.  Both read these two constants from the include.
DEMO_START = 120        # frames before the scripted demo begins
DEMO_PERIOD = 5         # frames per cell step
DEMO_LIMIT = 900        # the simulation's horizon

DEFAULT_INCLUDE = "maze-data.inc"
SPEC_NAME = "maze-spec.txt"
SCRIPT_NAME = "lesson71-generate.py"


class SpecError(Exception):
    """A validation failure tied to one source line."""

    def __init__(self, path: str, line: int, message: str) -> None:
        super().__init__(f"{path}:{line}: {message}")
        self.path = path
        self.line = line
        self.message = message


@dataclass(frozen=True)
class Cell:
    """One visible cell on the 20 x 11 screen."""

    col: int
    row: int


@dataclass
class Spec:
    """The validated maze spec."""

    path: str
    seed: int = 0
    width: int = 0
    height: int = 0
    keys: int = 0
    enemies: int = 0
    key_overrides: list[tuple[int, int, int]] = field(default_factory=list)
    enemy_overrides: list[tuple[int, int, int]] = field(default_factory=list)
    lines: dict[str, int] = field(default_factory=dict)


@dataclass
class Maze:
    """The generated maze and everything the include needs."""

    spec: Spec
    grid: list[list[int]]
    seam_rows: list[int]
    key_cells: list[Cell]
    enemy_cells: list[Cell]
    demo_path: list[int]
    key_steps: list[int]
    dead_ends: list[Cell]

    @property
    def width(self) -> int:
        return self.spec.width

    @property
    def height(self) -> int:
        return self.spec.height

    def unique(self, col: int) -> int:
        """Map a visible column to its unique column."""
        return col if col < self.width else 2 * self.width - 1 - col

    def is_open(self, col: int, row: int) -> bool:
        """True when the visible cell is open floor."""
        if not (0 <= col < 2 * self.width and 0 <= row < self.height):
            return False
        return self.grid[row][self.unique(col)] == OPEN

    def degree(self, cell: Cell) -> int:
        """The number of open orthogonal neighbours."""
        return sum(
            1
            for dc, dr in DIRS
            if self.is_open(cell.col + dc, cell.row + dr)
        )

    def neighbours(self, cell: Cell) -> list[tuple[int, Cell]]:
        """The open neighbours, with the direction code that reaches them."""
        result = []
        for code, (dc, dr) in enumerate(DIRS):
            target = Cell(cell.col + dc, cell.row + dr)
            if self.is_open(target.col, target.row):
                result.append((code, target))
        return result


def _parse_int(
    text: str, path: str, line: int, what: str, low: int, high: int
) -> int:
    """Parse one decimal field and range-check it."""
    try:
        value = int(text, 10)
    except ValueError:
        raise SpecError(path, line, f"{what} is not a decimal number: {text!r}") from None
    if not low <= value <= high:
        raise SpecError(path, line, f"{what} {value} is out of range {low}..{high}")
    return value


def parse_spec(path: str) -> Spec:
    """Parse and validate one maze spec, with its `spec:line` errors."""
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as exc:
        raise SpecError(path, 0, f"cannot read spec: {exc.strerror}") from None

    spec = Spec(path=path)
    seen: set[str] = set()
    key_lines: list[int] = []
    enemy_lines: list[int] = []
    key_cells: set[tuple[int, int]] = set()
    enemy_cells: set[tuple[int, int]] = set()

    for line_no, raw in enumerate(text.splitlines(), start=1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split()
        directive = parts[0].lower()
        rest = parts[1:]

        if directive in ("seed", "width", "height", "keys", "enemies"):
            if directive in seen:
                raise SpecError(path, line_no, f"duplicate {directive} directive")
            if len(rest) != 1:
                raise SpecError(path, line_no, f"{directive} needs one number")
            if directive == "seed":
                try:
                    value = int(rest[0], 10)
                except ValueError:
                    raise SpecError(
                        path, line_no, f"seed is not a decimal number: {rest[0]!r}"
                    ) from None
                if not 0 <= value <= 0x7FFFFFFF:
                    raise SpecError(path, line_no, f"seed {value} is out of range 0..2147483647")
                spec.seed = value
            elif directive == "width":
                spec.width = _parse_int(rest[0], path, line_no, "width", WIDTH_MIN, WIDTH_MAX)
            elif directive == "height":
                spec.height = _parse_int(
                    rest[0], path, line_no, "height", HEIGHT_MIN, HEIGHT_MAX
                )
            elif directive == "keys":
                spec.keys = _parse_int(rest[0], path, line_no, "keys", KEY_MIN, KEY_MAX)
            else:
                spec.enemies = _parse_int(
                    rest[0], path, line_no, "enemies", ENEMY_MIN, ENEMY_MAX
                )
            seen.add(directive)
            spec.lines[directive] = line_no

        elif directive in ("key", "enemy"):
            if len(rest) != 2:
                raise SpecError(path, line_no, f"{directive} needs two numbers: col row")
            col = _parse_int(rest[0], path, line_no, f"{directive} column", 0, 2 * LESSON_WIDTH - 1)
            row = _parse_int(rest[1], path, line_no, f"{directive} row", 0, LESSON_HEIGHT - 1)
            if directive == "key":
                if (col, row) in key_cells:
                    raise SpecError(path, line_no, f"duplicate key ({col},{row})")
                key_cells.add((col, row))
                spec.key_overrides.append((line_no, col, row))
                key_lines.append(line_no)
            else:
                if (col, row) in enemy_cells:
                    raise SpecError(path, line_no, f"duplicate enemy ({col},{row})")
                enemy_cells.add((col, row))
                spec.enemy_overrides.append((line_no, col, row))
                enemy_lines.append(line_no)

        else:
            raise SpecError(path, line_no, f"unknown directive: {directive}")

    missing = [name for name in ("seed", "width", "height", "keys", "enemies") if name not in seen]
    if missing:
        raise SpecError(path, 1, "missing directive(s): " + ", ".join(missing))

    # The lesson's engine is built for this screen.  A different grid would
    # need a different kernel, so the values are pinned rather than guessed.
    if spec.width != LESSON_WIDTH:
        raise SpecError(
            path,
            spec.lines["width"],
            f"width {spec.width} is not supported by the lesson kernel; "
            f"the mirror maze is {LESSON_WIDTH} unique columns",
        )
    if spec.height != LESSON_HEIGHT:
        raise SpecError(
            path,
            spec.lines["height"],
            f"height {spec.height} is not supported by the lesson kernel; "
            f"the screen is {LESSON_HEIGHT} rows",
        )
    if spec.keys != LESSON_KEYS:
        raise SpecError(
            path,
            spec.lines["keys"],
            f"keys {spec.keys} is not supported; the status band has {LESSON_KEYS} icons",
        )
    if spec.enemies != LESSON_ENEMIES:
        raise SpecError(
            path,
            spec.lines["enemies"],
            f"enemies {spec.enemies} is not supported; the engine has {LESSON_ENEMIES} enemies",
        )

    if spec.key_overrides and len(spec.key_overrides) != spec.keys:
        raise SpecError(
            path,
            key_lines[0],
            f"{len(spec.key_overrides)} key overrides for {spec.keys} keys",
        )
    if spec.enemy_overrides and len(spec.enemy_overrides) != spec.enemies:
        raise SpecError(
            path,
            enemy_lines[0],
            f"{len(spec.enemy_overrides)} enemy overrides for {spec.enemies} enemies",
        )

    return spec


def build_grid(spec: Spec) -> tuple[list[list[int]], list[int], Cell]:
    """Run the recursive backtracker and open the mirror seam.

    Every open cell is reachable and the open cells form a tree: the
    backtracker visits the room lattice (the even coordinates), and each carve
    opens the wall cell between two rooms.  The seam cells are leaves added on
    two even rows, so they keep the tree property.
    """
    width, height = spec.width, spec.height
    grid = [[WALL for _ in range(width)] for _ in range(height)]
    start = Cell(0, height - 1)
    if start.col % 2 or start.row % 2:
        raise SpecError(spec.path, 1, "the start room must be on the even lattice")

    # The room lattice: even columns and even rows.  The bottom-left room is
    # the start; the recursive backtracker reaches every room from it.
    rooms = [(c, r) for r in range(0, height, 2) for c in range(0, width, 2)]
    if (start.col, start.row) not in rooms:
        raise SpecError(spec.path, 1, "the start room is outside the room lattice")

    rng = _rng(spec.seed)
    grid[start.row][start.col] = OPEN
    visited = {(start.col, start.row)}
    stack = [(start.col, start.row)]
    while stack:
        col, row = stack[-1]
        choices = []
        for dc, dr in ((0, -2), (0, 2), (-2, 0), (2, 0)):
            nc, nr = col + dc, row + dr
            if 0 <= nc < width and 0 <= nr < height and (nc, nr) not in visited:
                choices.append((nc, nr))
        if not choices:
            stack.pop()
            continue
        nc, nr = rng.choice(choices)
        mc, mr = (col + nc) // 2, (row + nr) // 2
        grid[mr][mc] = OPEN
        grid[nr][nc] = OPEN
        visited.add((nc, nr))
        stack.append((nc, nr))

    if len(visited) != len(rooms):
        raise SpecError(spec.path, 1, "the backtracker did not reach every room")

    # The mirror seam: the right edge of the unique grid.  Only an even row
    # has a room at column 8 to attach the seam leaf to, so the seam rows are
    # even.  Two openings make the two visible copies a loop rather than a
    # single bridge, which gives the player a choice.
    even_rows = list(range(0, height, 2))
    seam_rows = sorted(rng.sample(even_rows, 2))
    for row in seam_rows:
        grid[row][width - 1] = OPEN

    return grid, seam_rows, start


def _rng(seed: int):
    """A private, seeded PRNG (the standard library's Mersenne Twister)."""
    import random

    return random.Random(seed)


def _bfs(maze: Maze, source: Cell) -> tuple[dict[Cell, int], dict[Cell, tuple[Cell, int]]]:
    """Breadth-first search over the visible open cells."""
    dist = {source: 0}
    prev: dict[Cell, tuple[Cell, int]] = {}
    queue = deque([source])
    while queue:
        cell = queue.popleft()
        for code, target in maze.neighbours(cell):
            if target not in dist:
                dist[target] = dist[cell] + 1
                prev[target] = (cell, code)
                queue.append(target)
    return dist, prev


def _path(maze: Maze, source: Cell, target: Cell) -> list[int]:
    """The shortest path's direction codes, or an empty list if unreachable."""
    _, prev = _bfs(maze, source)
    if target not in prev and target != source:
        return []
    codes: list[int] = []
    cell = target
    while cell != source:
        if cell not in prev:
            return []
        parent, code = prev[cell]
        codes.append(code)
        cell = parent
    codes.reverse()
    return codes


def _dead_ends(maze: Maze) -> list[Cell]:
    """Every open visible cell with exactly one open neighbour."""
    result = []
    for row in range(maze.height):
        for col in range(2 * maze.width):
            cell = Cell(col, row)
            if maze.is_open(col, row) and maze.degree(cell) == 1:
                result.append(cell)
    return result


def _choose_keys(maze: Maze, start: Cell) -> tuple[list[Cell], list[int]]:
    """Pick three dead ends and the shortest tour that visits them in order.

    The keys are sequential in the engine, so the tour order is the emitted
    order.  A tour is admissible when the first key is close enough for the
    six-second capture and the whole route fits the ten-second capture; the
    keys must use three different unique cells (a key and its mirror are the
    same cell), span the top and bottom halves (at least one key in each),
    and include at least one key in the mirror half so the demo crosses the
    seam.
    """
    dead_ends = _dead_ends(maze)
    if len(dead_ends) < LESSON_KEYS:
        raise SpecError(maze.spec.path, 1, f"only {len(dead_ends)} dead ends; three keys are required")

    def band(row: int) -> int:
        """Two vertical regions: the top half (rows 0-4) and the bottom (6-10)."""
        return 0 if row <= 4 else 1

    def spread(combo: tuple[Cell, ...]) -> bool:
        """Three different unique cells, with a key in each half."""
        if len({maze.unique(cell.col) for cell in combo}) != 3:
            return False
        if len({band(cell.row) for cell in combo}) != 2:
            return False
        return len({cell.row for cell in combo}) >= 2

    best: tuple[int, list[Cell], list[int]] | None = None
    candidates = [cell for cell in dead_ends if cell != start]
    if len(candidates) < LESSON_KEYS:
        raise SpecError(maze.spec.path, 1, f"only {len(candidates)} dead ends away from the start; three keys are required")
    for combo in itertools.combinations(candidates, LESSON_KEYS):
        if not spread(combo):
            continue
        for order in itertools.permutations(combo):
            route = 0
            steps = []
            ok = True
            source = start
            for key in order:
                leg = _path(maze, source, key)
                if not leg and source != key:
                    ok = False
                    break
                route += len(leg)
                steps.append(route)
                source = key
            if not ok:
                continue
            # The demo timeline: the first key at DEMO_START + step * PERIOD.
            # The captures are at about 2 s, 6 s and 10 s; the first key must
            # be behind us by about frame 330 and the last key by frame 580.
            if steps[0] * DEMO_PERIOD + DEMO_START > 320:
                continue
            if route * DEMO_PERIOD + DEMO_START > 580:
                continue
            if not any(key.col >= maze.width for key in order):
                continue
            candidate = (route, list(order), steps)
            if best is None or candidate[0] < best[0]:
                best = candidate

    if best is None:
        # Relax the mirror-half preference but keep the timing window and the
        # spread; the lesson's captures must still work.
        for combo in itertools.combinations(candidates, LESSON_KEYS):
            if not spread(combo):
                continue
            for order in itertools.permutations(combo):
                route = 0
                steps = []
                ok = True
                source = start
                for key in order:
                    leg = _path(maze, source, key)
                    if not leg and source != key:
                        ok = False
                        break
                    route += len(leg)
                    steps.append(route)
                    source = key
                if not ok:
                    continue
                if steps[0] * DEMO_PERIOD + DEMO_START > 320:
                    continue
                if route * DEMO_PERIOD + DEMO_START > 580:
                    continue
                candidate = (route, list(order), steps)
                if best is None or candidate[0] < best[0]:
                    best = candidate

    if best is None:
        raise SpecError(
            maze.spec.path,
            1,
            "no three dead ends give a tour short enough for the demo captures",
        )

    _, order, steps = best
    return order, steps


def _choose_enemies(
    maze: Maze, start: Cell, keys: list[Cell], demo_path: list[int]
) -> list[Cell]:
    """Place the two enemies far from the start, one in each visible half.

    The engine's enemy AI is greedy, so a start far from the demo route gives
    the scripted run room to pass without being caught.  The candidates are
    ranked deterministically and the first pair that survives the simulation
    is used.
    """
    dist, _ = _bfs(maze, start)
    # A cell on the demo route is not an enemy start: the scripted player must
    # not walk into a stationary enemy before the chase begins.
    route_cells = {start}
    cell = start
    for code in demo_path:
        cell = _move(cell, code)
        route_cells.add(cell)

    candidates = []
    for row in range(maze.height):
        for col in range(2 * maze.width):
            cell = Cell(col, row)
            if cell == start or cell in keys:
                continue
            if cell in route_cells:
                continue
            if not maze.is_open(col, row):
                continue
            if dist.get(cell, 0) < 6:
                continue
            candidates.append(cell)

    # One candidate in each half; the pair maximises the smaller distance.
    left = [c for c in candidates if c.col < maze.width]
    right = [c for c in candidates if c.col >= maze.width]
    left.sort(key=lambda c: (-dist[c], c.row, c.col))
    right.sort(key=lambda c: (-dist[c], c.row, c.col))

    pairs = []
    for a in left[:8]:
        for b in right[:8]:
            pairs.append((a, b))
    pairs.sort(key=lambda pair: (-min(dist[pair[0]], dist[pair[1]]), pair[0].row, pair[0].col, pair[1].row, pair[1].col))

    for a, b in pairs:
        _, _, deaths = _simulate(maze, start, keys, demo_path, [a, b])
        if deaths:
            continue
        return [a, b]

    # No pair survived: fall back to the two farthest candidates and let the
    # reader see the prediction in --report.
    if len(candidates) >= 2:
        candidates.sort(key=lambda c: (-dist[c], c.row, c.col))
        return [candidates[0], candidates[1]]
    raise SpecError(maze.spec.path, 1, "not enough open cells for two enemy starts")


def _move(cell: Cell, code: int) -> Cell:
    dc, dr = DIRS[code]
    return Cell(cell.col + dc, cell.row + dr)


def _enemy_step(maze: Maze, enemy: Cell, player: Cell) -> Cell:
    """One greedy enemy step: the larger axis first, then the other."""
    dc = player.col - enemy.col
    dr = player.row - enemy.row
    if dc == 0 and dr == 0:
        return enemy
    axes = ("h", "v") if abs(dc) > abs(dr) else ("v", "h")
    for axis in axes:
        if axis == "h":
            code = 3 if dc > 0 else 2
        else:
            code = 1 if dr > 0 else 0
        target = _move(enemy, code)
        if maze.is_open(target.col, target.row):
            return target
    return enemy


def _simulate(
    maze: Maze,
    start: Cell,
    keys: list[Cell],
    demo_path: list[int],
    enemies: list[Cell],
    horizon: int = DEMO_LIMIT,
) -> tuple[int | None, list[int], list[int]]:
    """Simulate the scripted demo and the greedy enemies.

    Returns ``(win_frame or None, key_frames, death_frames)``.  A death is a
    frame on which an enemy and the player share a cell; the chosen enemy
    starts must produce none.
    """
    player = start
    enemies = list(enemies)
    enemy_timer = 9               # the ROM's first step is frame 8
    key_index = 0
    keys_left = 0
    step = 0
    key_frames: list[int] = []
    deaths: list[int] = []
    win_frame: int | None = None
    first_demo = DEMO_START + DEMO_PERIOD

    for frame in range(horizon):
        # The ROM counts DemoPeriod down on the first idle frame and steps
        # when it reaches zero: the first cell move is frame 125, not 120.
        if frame >= first_demo and (frame - first_demo) % DEMO_PERIOD == 0:
            if step < len(demo_path):
                player = _move(player, demo_path[step])
                step += 1
                # The player's own move is checked before the key: walking
                # into an enemy loses, even on a key cell.
                if any(enemy == player for enemy in enemies):
                    deaths.append(frame)
                    break
                if key_index < len(keys) and player == keys[key_index]:
                    key_index += 1
                    keys_left += 1
                    key_frames.append(frame)
                    if keys_left >= len(keys):
                        win_frame = frame
                        break

        # The enemies move every eight frames, in order, then the cells are
        # compared (the ROM's overscan order).
        enemy_timer -= 1
        if enemy_timer <= 0:
            enemy_timer = 8
            enemies = [_enemy_step(maze, enemy, player) for enemy in enemies]
        if any(enemy == player for enemy in enemies):
            deaths.append(frame)
            break

    return win_frame, key_frames, deaths


def build_maze(spec: Spec) -> Maze:
    """Generate the maze, place the contents, and validate the demo route."""
    grid, seam_rows, start = build_grid(spec)
    maze = Maze(
        spec=spec,
        grid=grid,
        seam_rows=seam_rows,
        key_cells=[],
        enemy_cells=[],
        demo_path=[],
        key_steps=[],
        dead_ends=[],
    )
    maze.dead_ends = _dead_ends(maze)
    for row in range(maze.height):
        if _pf_from_wall(maze, row) != _pf_bytes(maze, row):
            raise SpecError(
                spec.path,
                1,
                f"row {row}: the PF bytes and the wall map disagree",
            )

    if spec.key_overrides:
        keys = [Cell(col, row) for _, col, row in spec.key_overrides]
        _validate_keys(maze, start, keys, spec.key_overrides)
        # The override order is the collection order.
        steps = []
        route = 0
        source = start
        for key in keys:
            leg = _path(maze, source, key)
            if not leg and source != key:
                raise SpecError(spec.path, 1, f"key ({key.col},{key.row}) is unreachable")
            route += len(leg)
            steps.append(route)
            source = key
    else:
        keys, steps = _choose_keys(maze, start)
        _validate_keys(maze, start, keys, [(0, c.col, c.row) for c in keys])

    maze.key_cells = keys
    maze.key_steps = steps

    demo: list[int] = []
    source = start
    for key in keys:
        demo.extend(_path(maze, source, key))
        source = key
    maze.demo_path = demo

    if spec.enemy_overrides:
        enemies = [Cell(col, row) for _, col, row in spec.enemy_overrides]
        for line, enemy in zip((line for line, _, _ in spec.enemy_overrides), enemies):
            if not maze.is_open(enemy.col, enemy.row):
                raise SpecError(spec.path, line, f"enemy ({enemy.col},{enemy.row}) is a wall cell")
            if enemy in keys:
                raise SpecError(spec.path, line, f"enemy ({enemy.col},{enemy.row}) is a key cell")
            if enemy == start:
                raise SpecError(spec.path, line, f"enemy ({enemy.col},{enemy.row}) is the start cell")
    else:
        enemies = _choose_enemies(maze, start, keys, demo)
    maze.enemy_cells = enemies

    win, key_frames, deaths = _simulate(maze, start, keys, demo, enemies)
    if deaths:
        raise SpecError(
            spec.path,
            spec.lines["enemies"],
            "the scripted demo is caught by an enemy at frame(s) "
            + ", ".join(str(frame) for frame in deaths[:4]),
        )
    if win is None:
        raise SpecError(
            spec.path,
            spec.lines["keys"],
            "the scripted demo does not reach the third key inside the simulation",
        )
    return maze


def _validate_keys(
    maze: Maze, start: Cell, keys: list[Cell], overrides: Iterable[tuple[int, int, int]]
) -> None:
    """A key must be open, reachable, in a dead end, and not on the start."""
    for key in keys:
        if key == start:
            line = next((line for line, col, row in overrides if (col, row) == (key.col, key.row)), 1)
            raise SpecError(maze.spec.path, line, f"key ({key.col},{key.row}) is the start cell")
        if not maze.is_open(key.col, key.row):
            line = next((line for line, col, row in overrides if (col, row) == (key.col, key.row)), 1)
            raise SpecError(maze.spec.path, line, f"key ({key.col},{key.row}) is a wall cell")
    dist, _ = _bfs(maze, start)
    for key in keys:
        if key not in dist:
            line = next((line for line, col, row in overrides if (col, row) == (key.col, key.row)), 1)
            raise SpecError(maze.spec.path, line, f"key ({key.col},{key.row}) is unreachable from the start")
        if maze.degree(key) != 1:
            line = next((line for line, col, row in overrides if (col, row) == (key.col, key.row)), 1)
            raise SpecError(maze.spec.path, line, f"key ({key.col},{key.row}) is not in a dead end")


def _wall_bytes(maze: Maze, row: int) -> tuple[int, int]:
    """The row's 10 wall bits as two bytes: bits 9..2 then bits 1..0.

    Bit 9 is the leftmost unique column (column 0); bit 0 is column 9.  The
    first byte holds columns 0-7 (column 0 in bit 7), the second holds
    columns 8-9 (column 8 in bit 1).
    """
    high = 0
    low = 0
    for col in range(maze.width):
        if maze.grid[row][col] == WALL:
            if col < 8:
                high |= 1 << (7 - col)
            else:
                low |= 1 << (9 - col)
    return high, low


def _pf_bytes(maze: Maze, row: int) -> tuple[int, int, int]:
    """The row's playfield bytes: PF0 (cells 0-1), PF1 (2-5), PF2 (6-9)."""
    pf0 = 0
    pf1 = 0
    pf2 = 0
    for col in range(maze.width):
        if maze.grid[row][col] != WALL:
            continue
        if col < 2:
            # Cell c owns chunks 2c, 2c+1; PF0 bit = 4 + chunk.
            pf0 |= 0x30 if col == 0 else 0xC0
        elif col < 6:
            # Chunks 4-11 are PF1 bits 7..0, left to right.
            pf1 |= 0xC0 >> (2 * (col - 2))
        else:
            # Chunks 12-19 are PF2 bits 0..7, left to right.
            pf2 |= 0x03 << (2 * (col - 6))
    return pf0, pf1, pf2


def _pf_from_wall(maze: Maze, row: int) -> tuple[int, int, int]:
    """Re-derive the row's PF bytes from the wall-map bytes.

    ``_pf_bytes`` reads ``grid`` directly; this function reads the packed
    ``MazeWalls`` bit layout instead.  The generator compares the two for
    every row, so the include's two views of the maze cannot silently drift.
    """
    high, low = _wall_bytes(maze, row)
    pf0 = 0
    pf1 = 0
    pf2 = 0
    for col in range(maze.width):
        bit = 9 - col
        wall = (high & (1 << (bit - 2))) if bit >= 2 else (low & (1 << bit))
        if not wall:
            continue
        if col == 0:
            pf0 |= 0x30
        elif col == 1:
            pf0 |= 0xC0
        elif col < 6:
            pf1 |= 0xC0 >> (2 * (col - 2))
        else:
            pf2 |= 0x03 << (2 * (col - 6))
    return pf0, pf1, pf2


def _row_pattern(maze: Maze, row: int) -> str:
    """A compact ASCII map of the unique row (the left half)."""
    return "".join("#" if maze.grid[row][col] == WALL else "." for col in range(maze.width))


def _visible_pattern(maze: Maze, row: int) -> str:
    """A 20-character ASCII map of the visible row."""
    return "".join(
        "#" if not maze.is_open(col, row) else "." for col in range(2 * maze.width)
    )


def generate_include(maze: Maze) -> str:
    """Render the complete ACME include for the maze."""
    spec = maze.spec
    lines: list[str] = []
    add = lines.append
    add("; =============================================================================")
    add("; MAZE-DATA.INC — the Lesson 71 mirror-maze tables")
    add("; =============================================================================")
    add("; Generated by lesson71-generate.py from %s." % Path(spec.path).name)
    add(";")
    add("; DO NOT EDIT BY HAND.  Regenerate from the lesson folder with:")
    add(";   python3 lesson71-generate.py --spec maze-spec.txt --out maze-data.inc")
    add(";")
    add("; The seed is %d.  The engine never parses a spec at run time." % spec.seed)
    add("; The maze is 10 unique columns x 11 rows; the TIA's reflect mode draws")
    add("; the mirror half, so the screen shows 20 columns.  Each cell is two")
    add("; playfield chunks: PF0 chunks 0-3, PF1 chunks 4-11, PF2 chunks 12-19.")
    add("; =============================================================================")
    add("")
    add("MazeRows = %d" % maze.height)
    add("MazeCols = %d" % maze.width)
    add("MazeStartCol = %d" % 0)
    add("MazeStartRow = %d" % (maze.height - 1))
    add("KeyCount = %d" % len(maze.key_cells))
    add("EnemyCount = %d" % len(maze.enemy_cells))
    add("DemoStart = %d" % DEMO_START)
    add("DemoPeriod = %d" % DEMO_PERIOD)
    add("")
    add("; --- the playfield rows: 11 rows x 3 bytes --------------------------------")
    add("; Row r's PF0/PF1/PF2 draw the unique row: a wall cell sets both of its")
    add("; chunks; an open cell is empty.  Reflect mode mirrors the 10 columns.")
    add("MazePF:")
    for row in range(maze.height):
        pf0, pf1, pf2 = _pf_bytes(maze, row)
        add(
            "    !byte $%02X, $%02X, $%02X    ; row %2d  %s"
            % (pf0, pf1, pf2, row, _row_pattern(maze, row))
        )
    add("")
    add("; --- the wall map: 11 rows x 2 bytes --------------------------------------")
    add("; Bit 9 is the leftmost unique column (column 0); bit 0 is column 9.")
    add("; The first byte holds columns 0-7 (column 0 in bit 7); the second holds")
    add("; columns 8-9 (column 8 in bit 1, column 9 in bit 0).  1 = wall.")
    add("MazeWalls:")
    for row in range(maze.height):
        high, low = _wall_bytes(maze, row)
        add(
            "    !byte $%02X, $%02X    ; row %2d  %s"
            % (high, low, row, _row_pattern(maze, row))
        )
    add("")
    add("; --- the keys: visible column, row, in collection order -------------------")
    add("KeyCells:")
    for key in maze.key_cells:
        add("    !byte %2d, %2d" % (key.col, key.row))
    add("")
    add("; --- the enemy starts: visible column, row --------------------------------")
    add("EnemyCells:")
    for enemy in maze.enemy_cells:
        add("    !byte %2d, %2d" % (enemy.col, enemy.row))
    add("")
    add("; --- the scripted demo: direction codes 0=up, 1=down, 2=left, 3=right ----")
    add("; The route visits the three keys in order, then the win follows.")
    add("DemoPath:")
    for index in range(0, len(maze.demo_path), 16):
        chunk = maze.demo_path[index : index + 16]
        add("    !byte " + ", ".join(str(code) for code in chunk))
    add("DemoSteps = %d" % len(maze.demo_path))
    add("")
    add("; --- the generator's validation summary -----------------------------------")
    add("; seam rows: %s" % ", ".join(str(row) for row in maze.seam_rows))
    add("; keys:      %s" % ", ".join("(%d,%d)" % (key.col, key.row) for key in maze.key_cells))
    add("; enemies:   %s" % ", ".join("(%d,%d)" % (e.col, e.row) for e in maze.enemy_cells))
    add("; demo:      %d steps; key steps %s"
        % (len(maze.demo_path), ", ".join(str(step) for step in maze.key_steps)))
    return "\n".join(lines) + "\n"


def report(maze: Maze) -> str:
    """The human-readable summary printed by --report."""
    spec = maze.spec
    out: list[str] = []
    out.append("spec %s: seed %d, %dx%d, %d keys, %d enemies"
               % (Path(spec.path).name, spec.seed, spec.width, spec.height,
                  len(maze.key_cells), len(maze.enemy_cells)))
    out.append("")
    out.append("visible maze (20 columns; P = start, 1-3 = keys, A/B = enemies):")
    for row in range(maze.height):
        cells = []
        for col in range(2 * maze.width):
            cell = Cell(col, row)
            if cell == Cell(0, maze.height - 1):
                ch = "P"
            elif cell in maze.key_cells:
                ch = str(maze.key_cells.index(cell) + 1)
            elif cell in maze.enemy_cells:
                ch = "A" if maze.enemy_cells.index(cell) == 0 else "B"
            elif maze.is_open(col, row):
                ch = "."
            else:
                ch = "#"
            cells.append(ch)
        out.append("  %2d  %s" % (row, "".join(cells)))
    out.append("")
    out.append("unique rows (10 columns; the reflect source):")
    for row in range(maze.height):
        out.append("  %2d  %s" % (row, _row_pattern(maze, row)))
    out.append("")
    agree = sum(
        1 for row in range(maze.height) if _pf_from_wall(maze, row) == _pf_bytes(maze, row)
    )
    out.append("PF/wall rows: %d/%d agree" % (agree, maze.height))
    out.append("seam rows: %s" % ", ".join(str(row) for row in maze.seam_rows))
    out.append("dead ends: %d" % len(maze.dead_ends))
    out.append("keys (collection order):")
    for index, key in enumerate(maze.key_cells):
        out.append("  %d: visible (%d,%d), unique (%d,%d), step %d"
                   % (index, key.col, key.row, maze.unique(key.col), key.row,
                      maze.key_steps[index]))
    out.append("enemy starts:")
    for index, enemy in enumerate(maze.enemy_cells):
        unique = maze.unique(enemy.col)
        out.append("  %d: visible (%d,%d), unique (%d,%d)"
                   % (index, enemy.col, enemy.row, unique, enemy.row))
    out.append("demo path: %d steps" % len(maze.demo_path))
    out.append("demo codes: %s" % "".join(DIR_NAMES[code] for code in maze.demo_path))
    win, key_frames, deaths = _simulate(
        maze, Cell(0, maze.height - 1), maze.key_cells, maze.demo_path, maze.enemy_cells
    )
    out.append("predicted key frames: %s" % ", ".join(str(frame) for frame in key_frames))
    out.append("predicted win frame: %s" % win)
    out.append("predicted enemy collisions: %s" % (", ".join(str(f) for f in deaths) or "none"))
    out.append("")
    out.append("PF rows:")
    for row in range(maze.height):
        pf0, pf1, pf2 = _pf_bytes(maze, row)
        high, low = _wall_bytes(maze, row)
        out.append("  %2d  PF $%02X $%02X $%02X   walls $%02X $%02X   %s"
                   % (row, pf0, pf1, pf2, high, low, _visible_pattern(maze, row)))
    return "\n".join(out)


def _default_include_path() -> Path:
    """The committed include beside this script."""
    return Path(__file__).resolve().parent / DEFAULT_INCLUDE


def main(argv: list[str] | None = None) -> int:
    """Parse the arguments, generate, then write, check, or report."""
    parser = argparse.ArgumentParser(
        description="Generate the Lesson 71 mirror-maze ACME tables."
    )
    parser.add_argument(
        "--spec",
        required=True,
        metavar="PATH",
        help="the maze spec file",
    )
    parser.add_argument(
        "--out",
        metavar="PATH",
        help=(
            "write the include here; with --check, PATH is only the comparison "
            f"target and is never written (default: {DEFAULT_INCLUDE})"
        ),
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="compare the generated include with the committed file; never writes; nonzero on drift",
    )
    parser.add_argument(
        "--report",
        action="store_true",
        help="print the maze, the placements, and the demo timeline",
    )
    args = parser.parse_args(argv)

    try:
        spec = parse_spec(args.spec)
        maze = build_maze(spec)
    except SpecError as exc:
        print(f"{exc.path}:{exc.line}: {exc.message}", file=sys.stderr)
        return 1

    text = generate_include(maze)

    if args.report:
        print(report(maze))

    if args.check:
        check_path = Path(args.out) if args.out else _default_include_path()
        try:
            committed = check_path.read_text(encoding="utf-8")
        except OSError as exc:
            print(f"{check_path}: cannot read committed include: {exc.strerror}", file=sys.stderr)
            return 1
        if committed != text:
            diff = difflib.unified_diff(
                committed.splitlines(),
                text.splitlines(),
                fromfile=str(check_path),
                tofile="regenerated",
                lineterm="",
            )
            for line in list(diff)[:40]:
                print(line, file=sys.stderr)
            print(
                f"drift: {check_path} does not match {args.spec}; regenerate it with --out",
                file=sys.stderr,
            )
            return 1
        print(f"check: {check_path} is up to date", file=sys.stderr)
    elif args.out:
        out_path = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(text, encoding="utf-8")
        print(f"wrote {out_path} ({len(maze.demo_path)} demo steps)", file=sys.stderr)

    if not args.out and not args.check and not args.report:
        sys.stdout.write(text)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
