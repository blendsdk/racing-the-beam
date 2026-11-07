#!/usr/bin/env python3
"""Generate the ACME level tables for the Lesson 67 wave lab.

This is the course's first code generator.  It reads one or more human-edited
wave specs (a tiny line-oriented description language) and lowers them into an
ACME include: named byte arrays plus a per-level descriptor made of pointers.
The 2600 never parses the spec at run time; the engine interprets these fixed
tables.

The spec grammar
================

    # a comment
    level A                  one level; A or B in the lesson
    name WAVE-A              exactly six characters, space-padded
    bg $02                   the background colour byte
    pf $1A                   the playfield colour byte
    backdrop ....XXXX....    exactly eight rows of 20 '.'/'X' characters
    wave 0 0 84 100 1 0      index frame x y speed type

`wave` fields:

    index   0..N-1, in order
    frame   0..255; strictly increasing
    x       0..152
    y       64..160
    speed   1..3
    type    0 = straight, 1 = drift; --type-max 2 adds type 2 (zigzag)

The last wave's frame plus 120 must fit in a byte, because the engine's frame
counter is a byte and the level loops at that point.

Usage
=====

    python3 lesson67-generate.py --spec waves-a.txt --spec waves-b.txt \
        --out generated-levels.inc

    python3 lesson67-generate.py --spec waves-a.txt --spec waves-b.txt --check

    python3 lesson67-generate.py --spec waves-a.txt --spec waves-b.txt --report

The dialect flags extend the default language (A/B levels, types 0/1, no
colour directive):

    --type-max N        allow wave types 0..N (default 1)
    --allow-level L     add a level label (default A, B; repeatable)
    --allow-color       enable the `color <frame> <value>` directive

The exercise includes use those flags:

    python3 lesson67-generate.py --spec waves-zigzag.txt \
        --out generated-zigzag.inc --type-max 2
    python3 lesson67-generate.py --spec waves-a.txt --spec waves-b.txt \
        --spec waves-c.txt --out generated-three.inc --allow-level C
    python3 lesson67-generate.py --spec waves-color.txt \
        --out generated-color.inc --allow-color

`--check` regenerates the include in memory and compares it byte for byte with
the committed file; it exits nonzero on drift.  CI never runs Python: the
committed include is the build input, and `--check` is the author's drift gate.
"""

from __future__ import annotations

import argparse
import difflib
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

# ---------------------------------------------------------------------------
# The language's limits.  The default dialect is A/B levels, wave types 0/1,
# and no colour directive.  The CLI flags extend it for the exercises:
#   --type-max 2      exercise 1 (zigzag)
#   --allow-level C   exercise 2 (third level)
#   --allow-color     exercise 3 (colour schedule)
# ---------------------------------------------------------------------------
DEFAULT_LEVELS = ("A", "B")
TYPE_MIN = 0
TYPE_MAX_DEFAULT = 1
TYPE_MAX_LIMIT = 3  # the type is packed into bits 6-7 of the type/speed byte
FRAME_MIN = 0
FRAME_MAX = 255
X_MIN = 0
X_MAX = 152
Y_MIN = 64
Y_MAX = 160
SPEED_MIN = 1
SPEED_MAX = 3
WAVE_INDEX_MAX = 255
BACKDROP_ROWS = 8
BACKDROP_WIDTH = 20
LOOP_TAIL = 120

DEFAULT_INCLUDE_NAME = "generated-levels.inc"

# The name font.  The generator owns it because the engine draws the level name
# directly from the generated table: five top-down rows per glyph.  The table
# is lowered column-major, six columns of five rows per level.  This is the
# single source of truth for the name glyphs; the engine has no copy.
NAME_FONT: dict[str, tuple[int, int, int, int, int]] = {
    " ": (0x00, 0x00, 0x00, 0x00, 0x00),
    "-": (0x00, 0x00, 0x7E, 0x00, 0x00),
    "A": (0x7C, 0x66, 0x7E, 0x66, 0x66),
    "B": (0x7C, 0x66, 0x7C, 0x66, 0x7C),
    "C": (0x3C, 0x66, 0x60, 0x66, 0x3C),
    "E": (0x7E, 0x60, 0x7C, 0x60, 0x7E),
    "V": (0xC6, 0xC6, 0xC6, 0x6C, 0x38),
    "W": (0xC6, 0xC6, 0xD6, 0xFE, 0x6C),
}


class SpecError(Exception):
    """A validation failure tied to one source line."""

    def __init__(self, path: str, line: int, message: str) -> None:
        super().__init__(f"{path}:{line}: {message}")
        self.path = path
        self.line = line
        self.message = message


@dataclass
class Wave:
    """One generated enemy spawn."""

    index: int
    frame: int
    x: int
    y: int
    speed: int
    type: int


@dataclass
class Level:
    """One fully validated level."""

    label: str
    name: str
    bg: int | None = None
    pf: int | None = None
    backdrop: list[str] = field(default_factory=list)
    waves: list[Wave] = field(default_factory=list)
    colors: list[tuple[int, int]] = field(default_factory=list)
    line: int = 0
    seen: set[str] = field(default_factory=set)

    @property
    def loop_frame(self) -> int:
        """The frame on which the level restarts."""
        return self.waves[-1].frame + LOOP_TAIL


@dataclass(frozen=True)
class Dialect:
    """The language variant selected by the CLI flags."""

    type_max: int = TYPE_MAX_DEFAULT
    allowed_levels: tuple[str, ...] = DEFAULT_LEVELS
    extra_levels: tuple[str, ...] = ()
    allow_color: bool = False


def _hex_byte(text: str, path: str, line: int, what: str) -> int:
    """Parse one hex byte, accepting `$1A` or `1A`."""
    token = text.strip()
    if token.startswith("$"):
        token = token[1:]
    if not token:
        raise SpecError(path, line, f"{what} needs a hex byte")
    try:
        value = int(token, 16)
    except ValueError:
        raise SpecError(path, line, f"{what} is not hexadecimal: {text!r}") from None
    if not 0 <= value <= 0xFF:
        raise SpecError(path, line, f"{what} {value} is out of range 0..255")
    return value


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


def parse_specs(
    paths: Iterable[str], dialect: Dialect | None = None
) -> list[Level]:
    """Parse and validate every spec, returning the levels in file order.

    The first problem in a file is reported with its `spec:line` location.  A
    level is only appended after it has every required directive, so the
    generated tables never contain a half-written level.  The dialect supplies
    the allowed level labels, the maximum wave type, and whether the colour
    directive is part of the language.
    """
    dialect = dialect or Dialect()
    levels: list[Level] = []
    seen_labels: set[str] = set()

    for path in paths:
        try:
            text = Path(path).read_text(encoding="utf-8")
        except OSError as exc:
            raise SpecError(path, 0, f"cannot read spec: {exc.strerror}") from None

        current: Level | None = None
        level_line = 0

        def finish(level: Level | None, end_line: int) -> None:
            """Check the required fields, then append a complete level."""
            if level is None:
                return
            missing = [
                field_name
                for field_name in ("name", "bg", "pf")
                if field_name not in level.seen
            ]
            if "backdrop" not in level.seen:
                missing.append("backdrop")
            if not level.waves:
                missing.append("wave")
            if missing:
                names = ", ".join(missing)
                raise SpecError(path, end_line, f"level {level.label} is missing: {names}")
            if len(level.backdrop) != BACKDROP_ROWS:
                raise SpecError(
                    path,
                    level.line,
                    f"level {level.label} has {len(level.backdrop)} backdrop rows; "
                    f"exactly {BACKDROP_ROWS} are required",
                )
            loop = level.loop_frame
            if loop > FRAME_MAX:
                raise SpecError(
                    path,
                    level.line,
                    f"level {level.label}: last wave frame {level.waves[-1].frame} + "
                    f"{LOOP_TAIL} = {loop} exceeds {FRAME_MAX}; the level loop must fit a byte",
                )
            levels.append(level)

        for line_no, raw in enumerate(text.splitlines(), start=1):
            # `#` comments and blank lines are ignored anywhere on a line.
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue

            parts = line.split(None, 1)
            directive = parts[0].lower()
            rest = parts[1].strip() if len(parts) > 1 else ""

            if directive == "level":
                finish(current, level_line if level_line else line_no)
                if not rest:
                    raise SpecError(path, line_no, "level needs a label")
                label = rest.split()[0]
                if label not in dialect.allowed_levels:
                    allowed = ", ".join(dialect.allowed_levels)
                    raise SpecError(path, line_no, f"level {label!r} is not one of: {allowed}")
                if label in seen_labels:
                    raise SpecError(path, line_no, f"level {label} appears more than once")
                seen_labels.add(label)
                current = Level(label=label, name="", line=line_no)
                level_line = line_no
                continue

            if current is None:
                raise SpecError(path, line_no, f"{directive} appears before a level directive")

            if directive == "name":
                if "name" in current.seen:
                    raise SpecError(path, line_no, f"level {current.label} has two names")
                if not rest:
                    raise SpecError(path, line_no, "name needs at least one character")
                if len(rest) > 6:
                    raise SpecError(
                        path,
                        line_no,
                        f"name {rest!r} is {len(rest)} characters; the label is six",
                    )
                current.name = rest.ljust(6)
                current.seen.add("name")

            elif directive == "bg":
                if "bg" in current.seen:
                    raise SpecError(path, line_no, f"level {current.label} has two bg lines")
                current.bg = _hex_byte(rest, path, line_no, "bg")
                current.seen.add("bg")

            elif directive == "pf":
                if "pf" in current.seen:
                    raise SpecError(path, line_no, f"level {current.label} has two pf lines")
                current.pf = _hex_byte(rest, path, line_no, "pf")
                current.seen.add("pf")

            elif directive == "backdrop":
                if "backdrop" in current.seen and len(current.backdrop) >= BACKDROP_ROWS:
                    raise SpecError(
                        path,
                        line_no,
                        f"level {current.label} has more than {BACKDROP_ROWS} backdrop rows",
                    )
                if len(rest) != BACKDROP_WIDTH:
                    raise SpecError(
                        path,
                        line_no,
                        f"backdrop row {rest!r} is {len(rest)} characters; {BACKDROP_WIDTH} are required",
                    )
                bad = [char for char in rest if char not in ".X"]
                if bad:
                    raise SpecError(
                        path,
                        line_no,
                        f"backdrop row uses {bad[0]!r}; only '.' and 'X' are allowed",
                    )
                current.backdrop.append(rest)
                current.seen.add("backdrop")

            elif directive == "color":
                if not dialect.allow_color:
                    raise SpecError(
                        path,
                        line_no,
                        "unknown directive: color (pass --allow-color)",
                    )
                if len(current.backdrop) != BACKDROP_ROWS:
                    raise SpecError(
                        path,
                        line_no,
                        "all eight backdrop rows must appear before the first color",
                    )
                fields = rest.split()
                if len(fields) != 2:
                    raise SpecError(path, line_no, "color needs two fields: frame value")
                color_frame = _parse_int(
                    fields[0], path, line_no, "color frame", FRAME_MIN, FRAME_MAX
                )
                color_value = _hex_byte(fields[1], path, line_no, "color value")
                if current.colors and color_frame <= current.colors[-1][0]:
                    raise SpecError(
                        path,
                        line_no,
                        f"color frame {color_frame} must be greater than the previous "
                        f"color frame {current.colors[-1][0]}",
                    )
                current.colors.append((color_frame, color_value))
                current.seen.add("color")

            elif directive == "wave":
                if len(current.backdrop) != BACKDROP_ROWS:
                    raise SpecError(
                        path,
                        line_no,
                        "all eight backdrop rows must appear before the first wave",
                    )
                fields = rest.split()
                if len(fields) != 6:
                    raise SpecError(
                        path,
                        line_no,
                        "wave needs six fields: index frame x y speed type",
                    )
                index = _parse_int(fields[0], path, line_no, "wave index", 0, WAVE_INDEX_MAX)
                if index != len(current.waves):
                    raise SpecError(
                        path,
                        line_no,
                        f"wave index {index} is out of order; expected {len(current.waves)}",
                    )
                frame = _parse_int(fields[1], path, line_no, "frame", FRAME_MIN, FRAME_MAX)
                x = _parse_int(fields[2], path, line_no, "x", X_MIN, X_MAX)
                y = _parse_int(fields[3], path, line_no, "y", Y_MIN, Y_MAX)
                speed = _parse_int(fields[4], path, line_no, "speed", SPEED_MIN, SPEED_MAX)
                wave_type = _parse_int(
                    fields[5], path, line_no, "type", TYPE_MIN, dialect.type_max
                )
                if current.waves and frame <= current.waves[-1].frame:
                    raise SpecError(
                        path,
                        line_no,
                        f"frame {frame} must be greater than the previous wave's frame "
                        f"{current.waves[-1].frame}; one spawn per frame",
                    )
                current.waves.append(Wave(index, frame, x, y, speed, wave_type))

            else:
                raise SpecError(path, line_no, f"unknown directive: {directive}")

        finish(current, len(text.splitlines()) or 1)

    if not levels:
        raise SpecError(paths[0] if paths else "<spec>", 1, "no levels found")
    if len(levels) > 255:
        raise SpecError(paths[0], 1, "more than 255 levels; the level index is a byte")

    return levels


def _byte_row(values: Iterable[int], comment: str | None = None) -> str:
    """Format one `!byte` line with an optional trailing comment."""
    body = ", ".join(f"${value:02X}" for value in values)
    suffix = f"    ; {comment}" if comment else ""
    return f"    !byte {body}{suffix}"


def _expand_backdrop(row: str) -> tuple[int, int, int]:
    """Lower one 20-character backdrop row into PF0, PF1, PF2.

    The playfield's chunk order is PF0 bits 4-7 (leftmost first), PF1 bits 7-0
    (leftmost first), and PF2 bits 0-7 (leftmost first).  A row is 20 chunks:
    four in PF0, eight in PF1, eight in PF2.
    """
    pf0 = 0
    for i in range(4):
        if row[i] == "X":
            pf0 |= 1 << (4 + i)
    pf1 = 0
    for i in range(8):
        if row[4 + i] == "X":
            pf1 |= 1 << (7 - i)
    pf2 = 0
    for i in range(8):
        if row[12 + i] == "X":
            pf2 |= 1 << i
    return pf0, pf1, pf2


def _lower_name(name: str) -> list[int]:
    """Lower a six-character name into 30 column-major glyph bytes.

    Column 0 rows 0-4 come first, then column 1, and so on.  The engine's name
    kernel reads ``LevelNName+0,Y`` .. ``+25,Y`` with Y = row, exactly like the
    old RAM name buffer but from ROM.  Unknown characters become spaces.
    """
    padded = name.ljust(6)
    table: list[int] = []
    for char in padded:
        table.extend(NAME_FONT.get(char, NAME_FONT[" "]))
    return table


def _regenerate_command(
    spec_paths: Iterable[str], out_name: str, dialect: Dialect
) -> list[str]:
    """Build the header's regenerate command.

    The command is relative to the lesson folder and uses the spec basenames,
    the actual output basename, and the dialect flags actually used.  The
    directory prefix is omitted: generation and ``--check`` agree when the
    check target keeps the committed include's basename.
    """
    command = ["python3 lesson67-generate.py \\"]
    for path in spec_paths:
        command.append(f"    --spec {Path(path).name} \\")

    flags: list[str] = []
    if dialect.type_max != TYPE_MAX_DEFAULT:
        flags.append(f"--type-max {dialect.type_max}")
    for label in dialect.extra_levels:
        flags.append(f"--allow-level {label}")
    if dialect.allow_color:
        flags.append("--allow-color")

    if flags:
        command.append(f"    --out  {Path(out_name).name} \\")
        for index, flag in enumerate(flags):
            suffix = " \\" if index < len(flags) - 1 else ""
            command.append(f"    {flag}{suffix}")
    else:
        command.append(f"    --out  {Path(out_name).name}")
    return command


def generate(
    levels: list[Level],
    spec_paths: Iterable[str],
    out_name: str,
    dialect: Dialect | None = None,
) -> str:
    """Render the complete ACME include for the validated levels."""
    dialect = dialect or Dialect()
    spec_names = ", ".join(Path(path).name for path in spec_paths)
    lines: list[str] = []
    add = lines.append

    add("; =============================================================================")
    add("; GENERATED-LEVELS.INC — the Lesson 67 wave tables")
    add("; =============================================================================")
    add("; Generated by lesson67-generate.py from:")
    add(f";   {spec_names}")
    add(";")
    add("; DO NOT EDIT BY HAND.  Regenerate with:")
    for line in _regenerate_command(spec_paths, out_name, dialect):
        add(f";   {line}")
    add(";   (run from lessons/part9-dsl-path/67-automatable-patterns)")
    add(";")
    add("; The engine reads these tables; it never parses the spec at run time.")
    add("; The descriptor's first six pointers are wave frame, x, y, speed, type")
    add("; and backdrop; the colour exercise adds two more at offsets 12 and 14.")
    add("; =============================================================================")
    add("")
    add(f"LevelCount = {len(levels)}")
    add("")

    # Names: six ASCII bytes per level, plus the 30-byte glyph table the engine
    # draws.  The ASCII table documents the name; the glyph table is the data.
    add("; --- the six-character level names ------------------------------------------")
    add("LevelName:")
    for level in levels:
        values = ", ".join(f"${ord(char):02X}" for char in level.name)
        add(f"    !byte {values}    ; {level.name!r}")
    add("")
    add("; --- the 30-byte name glyph tables (six columns x five rows) ----------------")
    for index, level in enumerate(levels):
        add(f"Level{index}Name:")
        glyph_bytes = _lower_name(level.name)
        for column in range(6):
            rows = glyph_bytes[column * 5 : (column + 1) * 5]
            add(_byte_row(rows, f"column {column}"))
        add("")

    add("; --- background and playfield colours ---------------------------------------")
    add("LevelBG:")
    add(_byte_row(level.bg for level in levels))
    add("LevelPF:")
    add(_byte_row(level.pf for level in levels))
    add("")

    add("; --- wave counts and loop frames --------------------------------------------")
    add("LevelWaveCount:")
    add(_byte_row(len(level.waves) for level in levels))
    add("LevelLoop:")
    add(_byte_row(level.loop_frame for level in levels))
    add("")

    if dialect.allow_color:
        add("; --- colour schedule sizes ---------------------------------------------------")
        add("LevelColorCount:")
        add(_byte_row(len(level.colors) for level in levels))
        add("")

    add("; --- descriptor pointers ----------------------------------------------------")
    add("LevelDescLo:")
    add("    !byte " + ", ".join(f"<Level{i}Desc" for i in range(len(levels))))
    add("LevelDescHi:")
    add("    !byte " + ", ".join(f">Level{i}Desc" for i in range(len(levels))))
    add("")

    for index, level in enumerate(levels):
        add(f"; --- level {index}: {level.name!r} -------------------------------------------")
        add(f"Level{index}Desc:")
        add(f"    !word Level{index}WaveFrame")
        add(f"    !word Level{index}WaveX")
        add(f"    !word Level{index}WaveY")
        add(f"    !word Level{index}WaveSpeed")
        add(f"    !word Level{index}WaveType")
        add(f"    !word Level{index}Backdrop")
        if dialect.allow_color:
            add(f"    !word Level{index}ColorFrame")
            add(f"    !word Level{index}ColorValue")
        add("")

        add(f"Level{index}WaveFrame:")
        add(_byte_row(wave.frame for wave in level.waves))
        add(f"Level{index}WaveX:")
        add(_byte_row(wave.x for wave in level.waves))
        add(f"Level{index}WaveY:")
        add(_byte_row(wave.y for wave in level.waves))
        add(f"Level{index}WaveSpeed:")
        add(_byte_row(wave.speed for wave in level.waves))
        add(f"Level{index}WaveType:")
        add(_byte_row(wave.type for wave in level.waves))
        add("")
        if dialect.allow_color:
            add(f"Level{index}ColorFrame:")
            if level.colors:
                add(_byte_row(frame for frame, _ in level.colors))
            else:
                add("    !byte $00    ; no colour schedule")
            add(f"Level{index}ColorValue:")
            if level.colors:
                add(_byte_row(value for _, value in level.colors))
            else:
                add("    !byte $00    ; no colour schedule")
            add("")

        add(f"Level{index}Backdrop:")
        for row in level.backdrop:
            pf0, pf1, pf2 = _expand_backdrop(row)
            add(_byte_row((pf0, pf1, pf2), row))
        add("")

    return "\n".join(lines).rstrip() + "\n"


def report(levels: list[Level]) -> str:
    """Return the one-line-per-level report printed by `--report`."""
    rows = []
    for index, level in enumerate(levels):
        first = level.waves[0].frame
        last = level.waves[-1].frame
        rows.append(
            f'level {index} "{level.name}": {len(level.waves)} waves, '
            f"frames {first}-{last}, loop frame {level.loop_frame}"
        )
    return "\n".join(rows)


def _default_include_path() -> Path:
    """The committed include beside this script."""
    return Path(__file__).resolve().parent / DEFAULT_INCLUDE_NAME


def main(argv: list[str] | None = None) -> int:
    """Parse the arguments, validate the specs, and read/write the include."""
    parser = argparse.ArgumentParser(
        description="Generate the Lesson 67 ACME wave tables from wave specs."
    )
    parser.add_argument(
        "--spec",
        action="append",
        required=True,
        metavar="PATH",
        help="a wave spec file; repeat for each level file",
    )
    parser.add_argument(
        "--out",
        metavar="PATH",
        help=(
            "write the include here; with --check, PATH is only the comparison "
            f"target and is never written (default: {DEFAULT_INCLUDE_NAME})"
        ),
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help=(
            "compare the generated include with the committed file; never writes; "
            "nonzero on drift"
        ),
    )
    parser.add_argument(
        "--report",
        action="store_true",
        help="print a one-line report per level",
    )
    parser.add_argument(
        "--type-max",
        type=int,
        default=TYPE_MAX_DEFAULT,
        metavar="N",
        help=(
            f"allow wave types {TYPE_MIN}..N (default {TYPE_MAX_DEFAULT}; "
            "the zigzag exercise uses 2)"
        ),
    )
    parser.add_argument(
        "--allow-level",
        action="append",
        default=[],
        metavar="LABEL",
        help=(
            "add a level label (default: A, B; repeatable; the third-level "
            "exercise adds C)"
        ),
    )
    parser.add_argument(
        "--allow-color",
        action="store_true",
        help="enable the color <frame> <value> directive (default off)",
    )
    args = parser.parse_args(argv)

    if not TYPE_MIN <= args.type_max <= TYPE_MAX_LIMIT:
        parser.error(f"--type-max must be {TYPE_MIN}..{TYPE_MAX_LIMIT}")

    extra_levels: list[str] = []
    for label in args.allow_level:
        if len(label) != 1 or not ("A" <= label <= "Z"):
            parser.error(f"--allow-level {label!r} must be one uppercase letter")
        if label not in extra_levels:
            extra_levels.append(label)
    allowed_levels = list(DEFAULT_LEVELS)
    for label in extra_levels:
        if label not in allowed_levels:
            allowed_levels.append(label)
    dialect = Dialect(
        type_max=args.type_max,
        allowed_levels=tuple(allowed_levels),
        extra_levels=tuple(extra_levels),
        allow_color=args.allow_color,
    )

    try:
        levels = parse_specs(args.spec, dialect)
    except SpecError as exc:
        print(f"{exc.path}:{exc.line}: {exc.message}", file=sys.stderr)
        return 1

    out_name = Path(args.out).name if args.out else DEFAULT_INCLUDE_NAME
    text = generate(levels, args.spec, out_name, dialect)

    if args.report:
        print(report(levels))

    if args.check:
        # The drift gate must never modify the target.  --out selects the file
        # to compare against when it is present; otherwise the committed
        # include beside this script is the target.
        check_path = Path(args.out) if args.out else _default_include_path()
        try:
            committed = check_path.read_text(encoding="utf-8")
        except OSError as exc:
            print(
                f"{check_path}: cannot read committed include: {exc.strerror}",
                file=sys.stderr,
            )
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
                f"drift: {check_path} does not match the specs; "
                "regenerate it with --out",
                file=sys.stderr,
            )
            return 1
        print(f"check: {check_path} is up to date", file=sys.stderr)
    elif args.out:
        out_path = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(text, encoding="utf-8")
        print(f"wrote {out_path} ({len(levels)} level(s))", file=sys.stderr)

    if not args.out and not args.check and not args.report:
        sys.stdout.write(text)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
