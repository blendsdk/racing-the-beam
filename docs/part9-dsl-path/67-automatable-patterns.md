---
title: "Lesson 67: Identifying Automatable Patterns — A Wave Compiler"
description: "Recognize a repeated wave pattern, define a line-oriented level DSL, write a Python generator that validates it and lowers it into ACME tables, run two generated levels in a 4,096-byte wave lab, and extend the generator for zigzag waves, a third level, and a colour schedule."
prev:
  text: "Lesson 66: Analyzing batari BASIC — How bB Works"
  link: "/part9-dsl-path/66-analyzing-batari-basic"
next:
  text: "Lesson 68: Designing Your Kernel Architecture — A Zone Framework"
  link: "/part9-dsl-path/68-kernel-architecture"
---

# Lesson 67: Identifying Automatable Patterns — A Wave Compiler

> **Part 9: The DSL Path** · Estimated time: 100 minutes
> **Prerequisites:** Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and memory), Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players), Lesson 26 (positioning), Lesson 33 (`INPT4` and fire), Lesson 39 (the score kernel), Lesson 41 (game states), Lesson 48 (the kernel taxonomy), Lesson 53 (kernel patterns), Lesson 55 (text), Lesson 66 (the bB analysis)
> **You will learn:** how to tell a repeated pattern from one-off code; where the boundary between data and code belongs; how to define a small line-oriented description language; how to validate every field and report `spec:line` errors; how a deterministic generator lowers a spec into ACME tables; how a `--check` drift gate protects a committed include; how a hand-written engine interprets fixed tables with a runtime "interpreter"; the cost of table indirection; and how to design a level format a human can edit and a machine can validate.
> **You will build:** **the wave lab**, a 4,096-byte playable shooter whose two levels are not written in the assembly. `waves-a.txt` and `waves-b.txt` describe names, colours, backdrops, wave timings, positions, speeds and types; `lesson67-generate.py` validates them and lowers them into `generated-levels.inc`; `67-automatable-patterns.asm` is the engine that interprets the tables. SELECT switches A/B, fire launches the ball, hits score, and the level loops after the last wave plus 120 frames. Three exercise solutions extend the generator and the engine with zigzag waves, a third level, and a colour schedule.

## Introduction

Lesson 66 read a real compiler's output. This lesson writes the generator. The pattern is small and familiar: enemies appear at chosen frames, at chosen positions, with a speed and a movement style. Hand-coding that in assembly means a table, a spawn loop, and a copy of both for every level. The numbers are not code — they are a description of a level — and once you see that, the description can leave the assembly entirely.

The wave lab makes the boundary concrete. `waves-a.txt` and `waves-b.txt` are ordinary text files a designer can edit:

```text
level A
name WAVE-A
bg $02
pf $1A
backdrop ....XXXX............
...
wave 0 0 84 100 1 0
wave 1 12 40 120 2 1
```

`lesson67-generate.py` reads those files, checks every field against its range, expands the eight 20-character backdrop rows into playfield bytes, and writes `generated-levels.inc`: names, colours, wave counts, loop frames, a descriptor of six pointers per level, the wave arrays, and the backdrop. The 4,096-byte ROM is the other half: a hand-written engine that reads the fixed tables, spawns the waves, moves four enemy slots, checks a shot against them, draws a 16-line label/score band, a one-line transition, a 64-line generated backdrop, and a 111-line play area. The 2600 never parses the spec. The generator runs on the host; the engine interprets the generated data.

The lesson is also about the limits of automation. The generator can lower a level description; it cannot invent a cycle-counted kernel, a score window, a positioning routine, or a collision rule. Those stay hand-written, and the exercise solutions show the two sides growing together: `--type-max 2` changes the validator's limit and the engine's display routine; `--allow-level C` adds a label and changes the engine's SELECT cycle; `--allow-color` enables the grammar and the engine's VBLANK code. The generator source stays the same; the dialect is a command-line choice.

::: details TypeScript Equivalent

Think of the generator as a small compiler whose target is an assembler include, and the engine as a tiny virtual machine that reads the compiled tables:

```typescript
type WaveType = 0 | 1; // 2 with --type-max 2
type Speed = 1 | 2 | 3;

interface Wave {
  index: number;
  frame: number;  // 0..255
  x: number;      // 0..152
  y: number;      // 64..160
  speed: Speed;
  type: WaveType;
}

interface Level {
  label: 'A' | 'B';     // 'C' with --allow-level C
  name: string;        // exactly six characters
  bg: number;          // TIA colour byte
  pf: number;          // TIA colour byte
  backdrop: string[];  // exactly eight rows of 20 '.'/'X'
  waves: Wave[];       // frames strictly increasing
}

// The CLI flags select the dialect; the exercises pass flags, not edits.
interface Dialect {
  typeMax: 1 | 2 | 3;   // --type-max
  allowedLevels: string[]; // A, B plus --allow-level labels
  allowColor: boolean;  // --allow-color
}

// The validator is part of the language, not an afterthought.
function validate(level: Level): string[] {
  const errors: string[] = [];
  if (level.name.length !== 6) errors.push('name is six characters');
  if (level.backdrop.length !== 8) errors.push('eight backdrop rows');
  for (const [i, wave] of level.waves.entries()) {
    if (wave.index !== i) errors.push(`wave ${i} out of order`);
    if (wave.frame > 255) errors.push(`wave ${i} frame out of range`);
    if (wave.x > 152) errors.push(`wave ${i} x out of range`);
    if (wave.y < 64 || wave.y > 160) errors.push(`wave ${i} y out of range`);
    if (i > 0 && wave.frame <= level.waves[i - 1].frame) errors.push('frames must increase');
  }
  const last = level.waves[level.waves.length - 1];
  if (last.frame + 120 > 255) errors.push('the level loop must fit a byte');
  return errors;
}

// The lowering is mechanical: data in, assembler text out.
function lower(levels: Level[]): string {
  // LevelCount, LevelName, LevelBG/PF, LevelWaveCount, LevelLoop,
  // six pointers per level, then the wave arrays and the 8x3 backdrop.
  return '; generated — do not edit\n';
}

// The engine's runtime interpreter: fixed tables, no parser.
function spawn(level: Level, frame: number, waveIndex: number): Wave | null {
  const wave = level.waves[waveIndex];
  return wave && wave.frame === frame ? wave : null;
}
```

The model captures the shape — a typed tree, a validation pass, a lowering pass, and a runtime read of fixed data — and it breaks exactly where the 2600 differs. There is no `JSON.parse` or `Level` object in the ROM: `LevelName` is six bytes and the engine reads a separate 30-byte `LevelNName` glyph table; the wave fields are separate byte arrays; the "descriptor" is six 16-bit pointers to ROM addresses. The engine is not a generic interpreter with an opcode dispatch; it is a hand-written loop that knows the table layout, reads `(LevelPtr),Y`, and packs the type and speed into one byte. The generator's output is not an object graph but an assembler include; the build is ACME, not a TypeScript bundler. And `--check` replaces a type checker at the repository boundary: it proves the committed include is still the deterministic image of the specs. The CLI's dialect flags select the same limits: `--type-max N`, `--allow-level LABEL`, and `--allow-color`. The TypeScript model shows the default dialect; the exercises pass the flags to the stock generator instead of editing this code. The Python validator is authoritative; the TypeScript model is abridged (it omits, for example, the name-font, colour-schedule, and backdrop-character checks).

:::

## Theory

### Section 1: From a Repeated Pattern to a Description Language

The first job is recognition. A pattern is worth automating when a second instance would be the same code with different numbers. In the wave lab that test is easy: a wave is a spawn time, a position, a speed, and a movement type. If level B repeated level A's spawn loop with a different list of numbers, the loop is engine and the list is data. The same test rejects the kernel: a second level does **not** want a second copy of the play kernel, it wants the same kernel reading different data.

The description language is deliberately small and line-oriented:

| Directive | Fields | Rule |
|---|---|---|
| `level` | `A` or `B` (exercise 2 adds `C`) | one per level; starts a level block |
| `name` | one to six characters | space-padded to six |
| `bg` | one hex byte | the background colour |
| `pf` | one hex byte | the playfield colour |
| `backdrop` | exactly 20 characters of `.` and `X` | exactly eight rows per level |
| `wave` | `index frame x y speed type` | index `0..N-1` in order; frame `0..255`; x `0..152`; y `64..160`; speed `1..3`; type `0` straight or `1` drift |
| `color` | `frame value` (exercise 3) | frames strictly increasing |

`#` starts a comment, and blank lines are ignored. The eight backdrop rows are still the familiar 20 playfield chunks: four in PF0 (bits 4-7, leftmost first), eight in PF1 (bits 7-0, leftmost first), and eight in PF2 (bits 0-7, leftmost first). The spec's author never writes a PF byte; the generator owns that lowering.

Two rules are not obvious until the engine exists. First, the wave frames must strictly increase: the engine keeps one `WaveIndex` and compares the current frame with `WaveFrame[WaveIndex]`, so a later wave with an earlier frame would never spawn. Second, the last wave's frame plus 120 (the loop tail) must fit a byte. The engine's frame counter is one byte at `$81`; `LevelLoop` is the frame on which the level restarts. A spec that asks for a wave at frame 200 and a 120-frame tail (320) is a frame-counter overflow, not a gameplay choice, and the generator rejects it before assembly.

::: tip The spec is a contract, not a suggestion
The spec is the only file a level designer edits. The generator's range checks are the contract: x `0..152` keeps an enemy's 8-pixel sprite on screen; y `64..160` keeps the spawn inside the backdrop-plus-play window; speed `1..3` keeps the per-frame movement readable; the strict frame order keeps the one-index spawn loop correct. A spec that fails a check exits nonzero with `spec:line: message` — the same shape as a compiler diagnostic.
:::

### Section 2: The Generator — Validation, Expansion, Lowering

`lesson67-generate.py` is Python 3 with no third-party dependencies. It has four jobs:

1. **Parse** each `--spec` file into levels, tracking the source line for every field.
2. **Validate** every field against its range, the wave order, the backdrop count and width, the level label, and the loop byte.
3. **Lower** each level into a small set of byte arrays and a six-word descriptor.
4. **Emit** a deterministic ACME include, with `--check` to compare against the committed copy.

The default dialect is levels A/B, wave types 0/1, and no `color` directive. The CLI extends the same generator without editing it: `--type-max N` (default 1; exercise 1 uses 2), `--allow-level LABEL` (repeatable; the default is A/B, so exercise 2 adds `--allow-level C`), and `--allow-color` (exercise 3). The generated header records the flags actually used, so each include is reproducible from the committed generator.

The parse is a small state machine: a `level` line starts a `Level`, the other directives fill it, and a level is appended only after every required field has appeared. A missing `name`, `bg`, `pf`, backdrop row, or wave is reported at the level's first line. The validator's messages use the source path and the exact line, so an editor can jump to the problem:

```text
waves-a.txt:14: frame 300 is out of range 0..255
waves-a.txt:22: wave index 3 is out of order; expected 2
waves-a.txt:7: backdrop row is 19 characters; 20 are required
```

The lowering is where the 2600's shape shows. A 20-character row expands to three bytes:

```python
def _expand_backdrop(row: str) -> tuple[int, int, int]:
    pf0 = 0
    for i in range(4):
        if row[i] == 'X':
            pf0 |= 1 << (4 + i)
    pf1 = 0
    for i in range(8):
        if row[4 + i] == 'X':
            pf1 |= 1 << (7 - i)
    pf2 = 0
    for i in range(8):
        if row[12 + i] == 'X':
            pf2 |= 1 << i
    return pf0, pf1, pf2
```

The wave fields become **separate arrays**, not a record per wave:

```asm
Level0WaveFrame:
    !byte $00, $0C, $18, $24, $30, $3C, $48, $54, $60, $6C, $78
Level0WaveX:
    !byte $54, $28, $80, $40, $70, $18, $90, $58, $38, $78, $20
Level0WaveY:
    !byte $64, $78, $60, $8C, $50, $68, $78, $64, $88, $58, $70
Level0WaveSpeed:
    !byte $01, $02, $01, $02, $03, $01, $02, $03, $01, $02, $03
Level0WaveType:
    !byte $00, $01, $00, $01, $00, $01, $01, $00, $01, $00, $01
```

Why separate arrays? The engine's spawn loop needs one field at a time — the frame to decide whether to spawn, then the x/y/speed/type to fill the slot — and a field-per-array layout lets each read be `LDA (LevelPtr),Y` with the same index. It is the 2600 version of a structure-of-arrays layout: no padding, no 16-bit offsets, one byte per field. The backdrop is the only 2-D data: eight rows of three playfield bytes.

The descriptor ties the arrays together:

```asm
Level0Desc:
    !word Level0WaveFrame
    !word Level0WaveX
    !word Level0WaveY
    !word Level0WaveSpeed
    !word Level0WaveType
    !word Level0Backdrop
```

Its offsets are fixed by the engine: 0, 2, 4, 6, 8, 10. `LevelDescLo` and `LevelDescHi` are the per-level pointer tables the engine indexes with `Level`. The descriptor is data about data; the engine never hard-codes `Level0WaveX` — it reads the pointer for the active level.

`--check` is the drift gate. It regenerates the include in memory and compares it byte for byte with the committed file, printing a unified diff on drift and exiting nonzero. It never writes the target: a bare `--check` compares the committed include beside the script, and `--out path --check` compares `path`. The generated header is canonical — the script basename, the spec basenames and the **output basename** — so generation and `--check` agree when the check target keeps the committed include's basename; the directory prefix does not matter. A bare `--check` uses `generated-levels.inc`; an exercise include is checked with its own name and its dialect flag, e.g. `--out generated-zigzag.inc --type-max 2 --check`. A deliberately edited copy with the same basename fails with the body diff, as it should:

```bash
python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-a.txt \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-b.txt \
  --out  lessons/part9-dsl-path/67-automatable-patterns/generated-levels.inc \
  --check
```

Both main forms pass: `--check` alone and `--out path --check`; the exercise includes pass their own names and dialect flags with `--out`. The whole include, header included, is compared, so a tampered header is caught too. CI never runs Python. The committed `generated-levels.inc` is the build input; `--check` is the author's promise that the include is still the deterministic image of the specs. `--report` prints one line per level (`level 0 "WAVE-A": 11 waves, frames 0-120, loop frame 240`), which is easier to read than the byte arrays.

::: tip Determinism is a feature
The generator emits the same bytes for the same specs: no timestamps, no dictionary-order surprises. The header is canonical (script, spec basenames, output basename and the dialect flags actually used), so generation and `--check` agree when the command uses the same flags and the check target keeps the committed include's basename; the directory prefix does not matter. That is what makes `--check` meaningful; if the generator were nondeterministic, the drift gate would be noise.
:::

### Section 3: The Generated Include

`generated-levels.inc` is data only. The main source sources `generated-levels.inc`; each exercise solution sources its own generated include, so the same engine can be paired with a different set of levels:

```asm
; --- the six-character level names ------------------------------------------
LevelName:
    !byte $57, $41, $56, $45, $2D, $41    ; 'WAVE-A'
    !byte $57, $41, $56, $45, $2D, $42    ; 'WAVE-B'

; --- the 30-byte name glyph tables (six columns x five rows) ----------------
Level0Name:
    !byte $C6, $C6, $D6, $FE, $6C    ; column 0
    !byte $7C, $66, $7E, $66, $66    ; column 1
    !byte $C6, $C6, $C6, $6C, $38    ; column 2
    !byte $7E, $60, $7C, $60, $7E    ; column 3
    !byte $00, $00, $7E, $00, $00    ; column 4
    !byte $7C, $66, $7E, $66, $66    ; column 5

; --- background and playfield colours ---------------------------------------
LevelBG:
    !byte $02, $08
LevelPF:
    !byte $1A, $46

; --- wave counts and loop frames --------------------------------------------
LevelWaveCount:
    !byte $0B, $0D
LevelLoop:
    !byte $F0, $F0

; --- descriptor pointers ----------------------------------------------------
LevelDescLo:
    !byte <Level0Desc, <Level1Desc
LevelDescHi:
    !byte >Level0Desc, >Level1Desc
```

The include's shape is deliberately flat:

| Symbol | Size | Meaning |
|---|---|---|
| `LevelCount` | a constant | the number of levels |
| `LevelName` | 6 bytes/level | the ASCII name, six characters |
| `LevelNName` | 30 bytes/level | the name glyphs, six columns x five rows, read directly by the engine |
| `LevelBG`, `LevelPF` | 1 byte/level | TIA colour bytes |
| `LevelWaveCount` | 1 byte/level | the waves in the level |
| `LevelLoop` | 1 byte/level | the frame on which the level restarts |
| `LevelDescLo`, `LevelDescHi` | 1 byte/level | pointers to the descriptors |
| `LevelN` descriptor | 12 bytes | six pointers; the colour exercise's descriptor is 16 bytes (eight pointers, offsets 0..14) |
| `LevelNWaveFrame/X/Y/Speed/Type` | 1 byte/wave | the separate wave arrays |
| `LevelNBackdrop` | 24 bytes | eight rows of PF0/PF1/PF2 |

The colour include is the `--allow-color` dialect: it adds `LevelColorCount`, two descriptor words (offsets 12/14) and the `LevelNColorFrame`/`LevelNColorValue` arrays; the default and zigzag/three includes do not have them. `LevelLoop` is the one addition beyond the plan's minimal include. The engine's frame counter is a byte; the level restarts at `last wave frame + 120`, so the generator computes and validates that value once. It is a good example of the generator and the engine agreeing on a constraint: the generator knows the loop tail, and the engine simply compares `Frame` with `LevelLoop`.

### Section 4: The Engine — Reading Fixed Tables

The engine's data path has three layers:

1. **The level state** at `$80`: `Level`, `Frame`, `WaveIndex`, `WaveCount`, and the two-byte `LevelPtr`.
2. **The descriptor**: `LoadLevelArray` reads one of the six pointers into `LevelPtr`.
3. **The arrays**: `(LevelPtr),Y` reads the field at the wave index.

`SetLevelData` loads the active level's descriptor base and wave count:

```asm
SetLevelData:
    LDX Level
    LDA LevelDescLo,X
    STA LevelPtr
    LDA LevelDescHi,X
    STA LevelPtr+1
    LDA LevelWaveCount,X
    STA WaveCount
    RTS
```

`LoadLevelArray` takes a descriptor offset in Y:

```asm
LoadLevelArray:
    LDX Level
    LDA LevelDescLo,X
    STA ArrayPtr
    LDA LevelDescHi,X
    STA ArrayPtr+1
    LDA (ArrayPtr),Y
    STA LevelPtr
    INY
    LDA (ArrayPtr),Y
    STA LevelPtr+1
    RTS
```

The first read is `LevelDescLo[Level]` — a pointer to the descriptor; the second is the pointer at `descriptor + Y` — a pointer to the array. Two levels of indirection, both one-byte indexed. The cost is a few loads per spawn, paid only on the spawn frame.

The spawn itself is the table interpretation in miniature:

```asm
    LDA WaveIndex
    CMP WaveCount
    BCS SpawnDone
    LDY #0                   ; descriptor offset 0: WaveFrame
    JSR LoadLevelArray
    LDY WaveIndex
    LDA (LevelPtr),Y
    CMP Frame
    BNE SpawnDone
    ; find the first inactive slot; if all four are active, drop the wave
    LDA WaveIndex
    AND #3
    ASL
    ASL
    TAX
    LDA #1
    STA SLOT0_ACTIVE,X
    ; x = WaveX, y = WaveY, type/speed = (type << 6) | speed | dir
```

The first inactive slot wins: 0 is P1, 1 is M0, 2 is M1, 3 is the ball. The spec does not name a slot; the scan chooses one deterministically, and the `WaveSpawn` checkpoint reports both the wave index (A) and the chosen slot offset (X). If all four slots are active, the wave is dropped and its index consumed, so a busy lab loses a spawn rather than overwriting an enemy. The four slots are four 4-byte records at `$8F-$9E` (active, x, y, type/speed). The type/speed byte packs the type in bits 6-7, the drift direction in bit 2, and the speed in bits 0-1 — one byte for three fields, because the 2600 has no struct padding to spare.

The enemy update reads the same records with an X offset of 0, 4, 8, 12. Type 0 falls straight; type 1 adds a one-pixel drift and bounces at x=8/152. A type-2 byte would fall straight in the lesson engine; exercise 1 adds the third branch.

The shot is the ball. `INPT4` bit 7 is the fire button (0 = pressed); the engine uses the same `new & ~previous` edge as the SELECT switch. A shot starts at `PlayerX + 4` and `PlayerY - 1`, moves up four pixels per frame, and deactivates at the top of the play area (`ShotY < 84`). A hit tests `|dx| <= 6` and `|dy| <= 8` against the three non-ball slots; the ball slot is skipped while the shot owns the ball. The hit deactivates the enemy, increments the score (capped at 99), rebuilds the six-digit window, and resets the shot. An enemy whose top reaches 184 is removed; a wave can also be dropped when all four slots are full. A missed shot is not punished, but the four objects always represent four live slots.

After the last wave plus 120 frames, the level loops: `Frame` and `WaveIndex` reset to 0, the slots and the shot clear, and the same frame spawns the wave at frame 0. The score and the level itself continue.

`SELECT` is one edge, one switch. The main source toggles A/B with `EOR #$01`; exercise 2 replaces that with `INC Level; CMP #LevelCount` to cycle A→B→C→A. A switch resets `Frame` to `$FF` so the next increment makes frame 0 and the first wave (if it is at frame 0) spawns in the same VBLANK.

### Section 5: The Picture — Band, Backdrop, Play Area

The 192 visible lines are four bands:

| Band | Lines | Picture rows (scanlines) | What it draws |
|---|---:|---|---|
| Label/score | 16 | 0-15 (37-52) | the six-character name (five rows) and the six-digit score (the score library's nine-row window) |
| Transition | 1 | 16 (53) | a blank line while the backdrop preloads its first row |
| Backdrop | 64 | 17-80 (54-117) | the level's eight generated playfield rows, eight lines each |
| Play area | 111 | 81-191 (118-228) | seven setup lines, 51 logical rows drawn twice (102 game lines), and two blank lines |

The band uses the shared score library's six-column hardware: `ScoreSetup` puts P0 at TIA X=56 and P1 at X=64, sets three-copy close mode and VDEL, and strobes one HMOVE. The name is a five-row font drawn by a small VDEL kernel that mirrors `ScoreDraw`; the glyphs come from the generated `LevelNName` table in ROM (the generator owns the five-row font), so there is no name RAM buffer for the score hit's stack chain to overwrite. The score then uses `ScoreDraw`'s nine-line window. The name kernel's column stores are timed like the score's: `STA GRP0` for column 0, `STA GRP1` for 1, `STA GRP0` for 2, column 3 held in `ScoreTmp`, column 4 in X, column 5 in A, then `STY GRP1 / STX GRP0 / STA GRP1 / STA GRP0`; the cross-latch commits each column to its copy. The `NOP` and `CPX NameRow` are the timing pad that keeps the later columns inside their copy windows. The band is exactly 16 lines: line 0 is the name's setup line, lines 1-5 the name, line 6 blank, line 7 the score's setup line, and the score's last nine lines (setup + eight rows) end on line 15.

The backdrop is the level's 24 generated bytes. Each row is preloaded during the previous line, stored at the start of the row's first line, and held for seven more `WSYNC`s. The playfield is in repeat mode (`CTRLPF` bit 0 = 0), so the 20 chunks of the left half appear again on the right; the two-peak staircase in level A is the same 20-character row repeated. The backdrop's PF colour is `LevelPF`; the background is `LevelBG`.

The play area is a 2-line kernel. The prepare work varies with how many objects are active, but it stays inside the two-line budget on every row; an overrun would change the frame length. The kernel gives each logical row two scanlines: the first stores the row's prepared bytes, the second holds them and runs the next row's preparation. The two visible-line counters are the row (`PlayRow`, 0-50) and the three one-row objects' precomputed logical rows (`M1Row`, `M0Row`, `BallRow`). The player's eight rows are fixed at rows 43-50 (object Y 170; the sprite is displayed at picture rows 174-189), so its shape index is `PlayRow - 43`; P1 uses a start row plus an eight-row state byte. The missiles and ball are one logical row each, computed in VBLANK as `(Y - 84) / 2`, so the play loop is a set of compares and stores, not a division.

The setup is seven lines: clear PF and HMCLR and P0's WSYNC on 118, the P0 divide on 119, P1's WSYNC on 120, the P1 divide on 121, the HMOVE and play-state init on 122, the HMOVE notch and prepare row 0 on 123, and row 0's store on 124. The first `PlayLoop` store is on 125; the game rows reach `PlayDone` with four `WSYNC`s and `BIT Frame / JMP OverscanStart` lands the overscan at 229/6. The positioners are the Lesson 26 divide-by-15 routines; the caller sets the carry and the routine's `STA WSYNC` starts the line, so each positioner costs two visible lines.

### Section 6: Two Levels, One Engine

The two committed specs exercise the whole language:

| | Level A | Level B |
|---|---|---|
| Name | `WAVE-A` | `WAVE-B` |
| Background | `$02` dark grey | `$08` light grey |
| Playfield | `$1A` gold | `$46` red |
| Backdrop | a stepped two-peak skyline | a diagonal checker |
| Waves | 11 | 13 |
| Frames | 0-120 | 0-120 |
| Types | a mix of 0 and 1 | a mix of 0 and 1 |
| Loop | 240 | 240 |

The engine is identical for both; the difference is the data. SELECT toggles `Level`, resets the frame/wave/shot/score state, reloads the descriptor, and clears the score; the name is not rebuilt because it is read directly from the selected level's generated 30-byte ROM table. The 4,096-byte ROM contains the engine, the name/score band, the 2-line play kernel, the score library, the generated tables, and the vectors.

What does the indirection cost? On a spawn frame, the engine does five `LoadLevelArray` calls (frame, x, y, speed, type) and five `(LevelPtr),Y` reads; the rest of the frame does one compare against `WaveFrame[WaveIndex]` and a `WaveIndex < WaveCount` check. A hand-coded spawn would save the pointer loads but would need a new spawn block per wave; the generated version is one block for 24 waves. The trade is the same one Lesson 66 found in bB: a small runtime cost buys a data-driven level, and a data-driven level is what a generator can edit.

The level format also has a natural limit. A level is a list of independent spawns; it cannot describe a formation that moves as a unit, a boss with a phase table, or a wave that depends on the player's position. Those need more fields or a different language. The lesson's DSL is deliberately a floor, not a ceiling: the next exercise adds one field (`type 2`), one label (`C`), or one directive (`color`), and the same generator/engine pair absorbs it.

## The Code

### Building This Lesson

```bash
# regenerate the committed include (the author's step; CI never runs Python)
python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-a.txt \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-b.txt \
  --out  lessons/part9-dsl-path/67-automatable-patterns/generated-levels.inc

# prove the committed include is still the deterministic image of the specs
# (both main forms pass; the header names the output basename)
python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-a.txt \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-b.txt \
  --check

python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-a.txt \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-b.txt \
  --out  lessons/part9-dsl-path/67-automatable-patterns/generated-levels.inc \
  --check

# assemble every lesson ROM into docs/public/roms/
npm run roms

# or just this one, from the repository root
acme -f plain -o build/lesson67.bin \
  lessons/part9-dsl-path/67-automatable-patterns/67-automatable-patterns.asm
stella build/lesson67.bin
```

The committed ROM is `docs/public/roms/part9-dsl-path/67-automatable-patterns/67-automatable-patterns.bin`, 4,096 bytes. The three exercise ROMs are beside it: `exercise-01-solution.bin`, `exercise-02-solution.bin`, `exercise-03-solution.bin`, each 4,096 bytes. The generated include is `generated-levels.inc`; the exercise includes are `generated-zigzag.inc`, `generated-three.inc`, and `generated-color.inc`. The specs are `waves-a.txt`, `waves-b.txt`, and the three exercise specs. Each exercise include is generated from its own spec with the **stock generator's flags**; the header's `Regenerate with` command names the actual paths and flags:

```bash
# exercise 1 — the zigzag dialect
python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-zigzag.txt \
  --out  lessons/part9-dsl-path/67-automatable-patterns/generated-zigzag.inc \
  --type-max 2

# exercise 2 — the third level
python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-a.txt \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-b.txt \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-c.txt \
  --out  lessons/part9-dsl-path/67-automatable-patterns/generated-three.inc \
  --allow-level C

# exercise 3 — the colour schedule
python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-color.txt \
  --out  lessons/part9-dsl-path/67-automatable-patterns/generated-color.inc \
  --allow-color

# each include checks with the same flag and its own name
python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-zigzag.txt \
  --out  lessons/part9-dsl-path/67-automatable-patterns/generated-zigzag.inc \
  --type-max 2 --check

python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-a.txt \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-b.txt \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-c.txt \
  --out  lessons/part9-dsl-path/67-automatable-patterns/generated-three.inc \
  --allow-level C --check

python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-color.txt \
  --out  lessons/part9-dsl-path/67-automatable-patterns/generated-color.inc \
  --allow-color --check
```

The zigzag header's `Regenerate with` block is the same command in canonical form:

```text
;   python3 lesson67-generate.py \
;       --spec waves-zigzag.txt \
;       --out  generated-zigzag.inc \
;       --type-max 2
```

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 67: The Wave Lab — generated levels for a hand-written engine
; =============================================================================
; Part 9: The DSL Path
;
; What this program does:
;   A playable shooter whose levels are not written here.  Two level specs
;   (waves-a.txt, waves-b.txt) are validated and lowered by
;   lesson67-generate.py into generated-levels.inc: names, colours, eight
;   20-character backdrop rows, wave timings, positions, speeds and types.
;   This source is the engine: it reads those fixed tables and interprets
;   them.  The 2600 never parses the spec at run time.
;
;   Picture: 16-line label/score band + 1-line transition +
;            64-line generated backdrop + 111-line play area = 192 visible lines.
;     - the band draws the six-character level name (five rows) and the
;       six-digit score (the shared score library's nine-row window).
;     - the backdrop is the level's eight playfield rows, eight lines each.
;     - the play area is a 2-line kernel: 51 logical rows, each drawn twice.
;       Seven setup lines position P0/P1 and prepare row 0; the 102 game
;       lines and the two blank lines at the bottom complete the 111.
;       The play area is picture lines 81-191 (scanlines 118-228).
;       P0 is the player, P1/M0/M1/BALL are the four enemy slots.  Waves
;       spawn at the generated frames; type 0 falls straight, type 1 drifts
;       left/right.  Fire launches the ball upward.  A hit scores; an enemy
;       that reaches the bottom is removed; a wave that arrives with all four
;       slots full is dropped.
;       After the last wave's frame plus 120, the level loops.
;   SELECT switches levels and resets the frame, waves, shot and score.
;
; The DSL (see lesson67-generate.py for the validator):
;   level A | name WAVE-A | bg $02 | pf $1A
;   backdrop <20 chars>   (exactly eight, '.' empty, 'X' solid)
;   wave <index> <frame> <x> <y> <speed> <type>
;   index 0..N-1 in order; frame 0..255; x 0..152; y 64..160; speed 1..3;
;   type 0 straight, 1 drift.  Frames strictly increase, and the last frame
;   plus 120 must fit a byte.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229/6.
;
; Checkpoints (source label, expected Stella state):
;   StartFrame    259/3   the first VSYNC instruction
;   VblankStart     0/5   the first VBLANK instruction
;   BodyStart      37/5   the first visible line
;   OverscanStart 229/6   the first overscan instruction
;   LevelRead     A = 0/1, the active level
;   LevelWrite    A = the new level after a SELECT edge
;   WaveSpawn     A = the wave index; X = the chosen slot offset (0,4,8,12)
;   ScoreWrite    A = the score after a hit
;   FrameRead     A = the frame counter after the increment
;
; RAM map (+clean_start zeroes every byte):
;   $80 Level         0 = A, 1 = B
;   $81 Frame         the level's frame counter, 0..LevelLoop
;   $82 WaveIndex     the next wave to spawn
;   $83 WaveCount     LevelWaveCount[Level]
;   $84 LevelPtrLo    the descriptor or array pointer; P1Start during the play
;   $85 LevelPtrHi    the pointer's high byte
;   $86 PlayerX       P0's left edge, 8..152
;   $87 ShotX         the ball shot's X
;   $88 ShotY         the ball shot's Y (moves up 4 per frame)
;   $89 ShotActive    0 = no shot, 1 = the ball is the shot
;   $8A Score         the score, 0..99
;   $8B PrevSelect    SELECT state last frame
;   $8C NewSelect     SELECT state this frame
;   $8D PrevFire      fire state last frame
;   $8E free
;   $8F-$9E           the four enemy slots, four bytes each:
;                       +0 active, +1 x, +2 y, +3 type/speed
;                       bits 0-1 speed, bit 2 drift direction,
;                       bits 6-7 type (0 straight, 1 drift)
;   $9F Tmp           scratch (NameRow, TmpPF2, PlayRow)
;   $A0-$D7           the shared score library (ScoreDigits, ScoreRow,
;                     ScoreTmp, ScoreBuf).  The play kernel borrows
;                     ScoreDigits[0..2] for M1Row/M0Row/BallRow; the score's
;                     master is the Score byte and RebuildScore rewrites the
;                     digits from it.
;   $D8 ArrayPtrLo    the level-array pointer
;   $D9 ArrayPtrHi    the pointer's high byte (scratch P1Row in the play)
;   $DA SlotOfs       scratch: the chosen enemy-slot byte offset during a spawn
;   $DB-$F1 free
;   $F2-$FF effective stack (the score chain's deepest use is 14 bytes: five
;           return addresses + four PHAs).  No name buffer sits here: the name
;           is drawn from the generated LevelNName ROM table.
;
; The visible kernel reuses library scratch between phases.  The aliases are
; safe because the phases never overlap:
;   $A6 ScoreRow  / NextGRP0 / TmpPF0
;   $A7 ScoreTmp  / NextGRP1 / TmpPF1
;   $9F Tmp       / NameRow / TmpPF2 / PlayRow
;   $84 LevelPtrLo/ P1Start
;   $D8/$D9 ArrayPtr / P1Row
;   $A0-$A2 ScoreDigits / M1Row / M0Row / BallRow
;   $DA SlotOfs / free after the spawn
;
; Build: acme -f plain -o build/lesson67.bin \
;        lessons/part9-dsl-path/67-automatable-patterns/67-automatable-patterns.asm
; Run:   stella build/lesson67.bin
; The ROM is exactly 4,096 bytes; no mapper, no bankswitching.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; CONSTANTS
; =============================================================================
VBLANK_TIMER    = 44          ; 37-line VBLANK (44 ticks)
OVERSCAN_TIMER  = 36          ; 30-line overscan (36 ticks)
POS_BIAS        = 3           ; the Lesson 26 player output delay
BALL_BIAS       = 4           ; the missile/ball output delay

PLAYER_MIN      = 8
PLAYER_MAX      = 152
PLAYER_MOVE     = 4
PLAYER_Y        = 170         ; the player's sprite top
SHOT_SPEED      = 4
SHOT_TOP        = 84          ; the play area's top; a shot above this is gone
ENEMY_BOTTOM    = 184         ; an enemy whose top reaches here is gone

PLAY_START      = 84          ; the object-row origin (the first game line is 88)
PLAY_ROWS       = 51          ; 102 game lines / 2 lines per logical row
PLAYER_ROW      = 43          ; (PLAYER_Y - PLAY_START) / 2

SLOT_COUNT      = 4
SLOT_SIZE       = 4
SLOT0_ACTIVE    = $8F
SLOT0_X         = $90
SLOT0_Y         = $91
SLOT0_TYPE      = $92
SLOT1_ACTIVE    = $93
SLOT1_X         = $94
SLOT1_Y         = $95
SLOT2_ACTIVE    = $97
SLOT2_X         = $98
SLOT2_Y         = $99
SLOT3_ACTIVE    = $9B
SLOT3_X         = $9C
SLOT3_Y         = $9D

DIR_BIT         = $04         ; bit 2: 1 = drift right, 0 = drift left

C_WHITE         = $0E
C_PLAYER        = $C8         ; green
C_ENEMY         = $1A         ; gold

; =============================================================================
; RAM
; =============================================================================
Level       = $80
Frame       = $81
WaveIndex   = $82
WaveCount   = $83
LevelPtr    = $84             ; two bytes: $84/$85
PlayerX     = $86
ShotX       = $87
ShotY       = $88
ShotActive  = $89
Score       = $8A
PrevSelect  = $8B
NewSelect   = $8C
PrevFire    = $8D
Tmp         = $9F

ArrayPtr    = $D8             ; two bytes: $D8/$D9
SlotOfs     = $DA             ; scratch: the chosen slot offset during a spawn

; The play kernel aliases.  The header explains why the phases cannot overlap.
P1Start     = LevelPtr        ; $84
NextGRP0    = $A6             ; ScoreRow
NextGRP1    = $A7             ; ScoreTmp
TmpPF0      = $A6
TmpPF1      = $A7
TmpPF2      = $9F
NameRow     = $9F
PlayRow     = $9F
P1Row       = $D9

; The three one-row objects' logical rows are computed in VBLANK and kept
; in the score library's ScoreDigits bytes.  ScoreDigits is not the score's
; master (the Score byte is); RebuildScore starts with ScoreClear, which
; rewrites all six digits, so the play kernel may borrow three of them.
M1Row       = $A0
M0Row       = $A1
BallRow     = $A2

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreSetup positions P0/P1 at 56/64, sets three-copy close mode and VDEL,
; and strobes the HMOVE.  ScoreDraw paints the six 8-pixel columns.
; ScoreClear/ScoreSetDigit rebuild the six-digit window.  The library owns
; $A0-$D7.  It is sourced after the ROM origin because it contains code.
    * = $F000

    !source "include/score.asm"

; =============================================================================
; RESET
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port
    STA SWBCNT              ; port B is an input port
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA VDELP0
    STA VDELP1
    LDA #$10                ; repeat playfield, 2-pixel ball
    STA CTRLPF
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1

    ; --- the initial level state -------------------------------------------
    LDA #0
    STA Level
    STA PrevSelect
    STA NewSelect
    STA PrevFire
    STA WaveIndex
    STA ShotActive
    STA Score
    LDA #$FF
    STA Frame               ; the first VBLANK increment makes frame 0
    LDA #80
    STA PlayerX
    LDA #0
    STA ShotX
    STA ShotY
    ; clear the four enemy slots
    LDX #0
ResetSlots:
    LDA #0
    STA SLOT0_ACTIVE,X
    INX
    INX
    INX
    INX
    CPX #16
    BNE ResetSlots

    JSR SetLevelData
    JSR ScoreInit
    JSR ScoreClear
    JSR ScoreSetup           ; P0/P1 at 56/64, NUSIZ=3, VDEL=1, HMOVE

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262
; =============================================================================
StartFrame:                  ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                 ; checkpoint: scanline 0, cycle 5
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; SELECT — one level switch per fresh press
; -----------------------------------------------------------------------------
    LDA SWCHB
    AND #$02
    EOR #$02                 ; 1 = SELECT pressed
    STA NewSelect
    AND PrevSelect
    EOR NewSelect            ; new & ~previous: a fresh press
    BEQ NoLevelSwitch

    ; Switch levels and reset the level state.  Frame is set to $FF so the
    ; increment below makes frame 0 and the first wave (if frame 0) spawns.
    LDA Level
    EOR #$01                 ; A -> B, B -> A
    STA Level
LevelWrite:                  ; checkpoint: A = the new level
    NOP
    LDA #$FF
    STA Frame
    LDA #0
    STA WaveIndex
    STA ShotActive
    STA Score
    LDX #0
SwitchSlots:
    LDA #0
    STA SLOT0_ACTIVE,X
    INX
    INX
    INX
    INX
    CPX #16
    BNE SwitchSlots
    JSR SetLevelData
    JSR ScoreClear

NoLevelSwitch:
    LDA NewSelect
    STA PrevSelect

; -----------------------------------------------------------------------------
; FRAME COUNTER AND LEVEL LOOP
; -----------------------------------------------------------------------------
    INC Frame
    LDA Frame
FrameRead:                   ; checkpoint: A = the frame counter
    NOP

    LDA Level
LevelRead:                   ; checkpoint: A = the active level
    NOP

    ; After the last wave plus 120 frames, restart the wave clock.  The score
    ; and the level itself continue; only the waves reset.
    LDX Level
    LDA LevelLoop,X
    CMP Frame
    BNE NoLoop
    LDA #0
    STA Frame
    STA WaveIndex
    STA ShotActive
    LDX #0
LoopSlots:
    LDA #0
    STA SLOT0_ACTIVE,X
    INX
    INX
    INX
    INX
    CPX #16
    BNE LoopSlots
NoLoop:

; -----------------------------------------------------------------------------
; GAME LOGIC
; -----------------------------------------------------------------------------
    JSR MovePlayer
    JSR HandleFire
    JSR UpdateEnemies
    JSR SpawnWaves
    JSR UpdateShot
    JSR SetP1Start           ; the play kernel's P1 start row
    JSR SetObjectRows        ; the three one-row objects' logical rows

; -----------------------------------------------------------------------------
; COLOURS AND CLEARED OBJECTS FOR THE BAND / BACKDROP
; -----------------------------------------------------------------------------
    LDX Level
    LDA LevelBG,X
    STA COLUBK
    LDA LevelPF,X
    STA COLUPF
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1

    LDA #0
    STA GRP0
    STA GRP1
    STA ENAM0
    STA ENAM1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2

; -----------------------------------------------------------------------------
; POSITION THE BALL, M0 AND M1 FOR THE SCORE LIBRARY'S HMOVE
; -----------------------------------------------------------------------------
    ; ball: the shot when active, otherwise the slot-3 enemy
    LDA ShotActive
    BEQ BallSlotPos
    LDA ShotX
    JMP BallPosition
BallSlotPos:
    LDA SLOT3_ACTIVE
    BEQ BallDefault
    LDA SLOT3_X
    JMP BallPosition
BallDefault:
    LDA #80
BallPosition:
    CLC
    ADC #(BALL_BIAS)
    SEC
    JSR SetCoarseBL

    ; missile 0: slot 1
    LDA SLOT1_ACTIVE
    BEQ M0Default
    LDA SLOT1_X
    JMP M0Position
M0Default:
    LDA #80
M0Position:
    CLC
    ADC #(BALL_BIAS)
    SEC
    JSR SetCoarseM0

    ; missile 1: slot 2
    LDA SLOT2_ACTIVE
    BEQ M1Default
    LDA SLOT2_X
    JMP M1Position
M1Default:
    LDA #80
M1Position:
    CLC
    ADC #(BALL_BIAS)
    SEC
    JSR SetCoarseM1

    ; The score library positions P0 and P1 at 56/64 and applies one HMOVE
    ; to all five fine-motion registers.
    JSR ScoreSetup

VblankWait:
    +wait_timer
    LDA #$00
    STA VBLANK               ; picture on

; =============================================================================
; PLAY KERNEL — prepare one logical row (2 scanlines)
; =============================================================================
; The 2-line kernel does the work during the second (hold) line of the
; previous row.  The caller stores the prepared bytes at the start of the
; next line, so the whole 76-cycle hold line is available for this routine.
;
; P0 is the player: its eight sprite rows are fixed at the last eight play
; rows, so its table index is simply PlayRow - PLAYER_ROW.  P1 is slot 0 and
; uses a start row plus an eight-row state byte; the missiles and ball are
; one logical row each, and their rows are precomputed in VBLANK.  On return
; A = the ball enable, X = the M1 enable, Y = the M0 enable.  Slot Y values
; are picture rows: logical row = (Y - PLAY_START) / 2.
!macro PrepareRow {
    ; --- P0: the player at the fixed PLAYER_ROW ---------------------------
    LDA #0
    STA NextGRP0
    LDA PlayRow
    CMP #PLAYER_ROW
    BCC .P0Done
    SEC
    SBC #PLAYER_ROW
    TAY
    LDA PlayerShape,Y
    STA NextGRP0
.P0Done:

    ; --- P1: slot 0, state-driven ----------------------------------------
    LDA PlayRow
    CMP P1Start
    BNE .P1NoStart
    LDA #0
    STA P1Row
.P1NoStart:
    LDA P1Row
    CMP #8
    BCS .P1Off
    TAY
    LDA EnemyShape,Y
    STA NextGRP1
    INC P1Row
    JMP .P1Done
.P1Off:
    LDA #0
    STA NextGRP1
.P1Done:

    ; --- M1, M0 and the ball: one precomputed row each --------------------
    LDX #0
    LDA M1Row
    CMP PlayRow
    BNE .M1Done
    LDX #2
.M1Done:

    LDY #0
    LDA M0Row
    CMP PlayRow
    BNE .M0Done
    LDY #2
.M0Done:

    LDA BallRow
    CMP PlayRow
    BNE .BallOff
    LDA #2
    JMP .Done
.BallOff:
    LDA #0
.Done:
}

; =============================================================================
; THE BACKDROP ROW MACRO
; =============================================================================
; Each call displays one generated playfield row for eight scanlines.  The
; three bytes are preloaded during the previous line, then stored at the
; start of the row's first line; seven WSYNCs hold them for the rest of the
; row.  Row 0's preload runs on line 53 (the one-line transition after the
; band), its first store is 54 (the first backdrop line), and the last row
; ends on 117.  The caller must have set ArrayPtr to the 24-byte backdrop.
!macro BackdropRow .offset {
    LDY #.offset
    LDA (ArrayPtr),Y
    STA TmpPF0
    INY
    LDA (ArrayPtr),Y
    STA TmpPF1
    INY
    LDA (ArrayPtr),Y
    STA TmpPF2
    STA WSYNC
    LDA TmpPF0
    STA PF0
    LDA TmpPF1
    STA PF1
    LDA TmpPF2
    STA PF2
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
}

; =============================================================================
; NAME ROWS — five rows of the six-column name, read straight from the ROM
; =============================================================================
; The generator lowers the level name into a 30-byte column-major table
; (six columns x five rows) in the generated include.  This macro draws one
; level's table; the dispatch below selects Level0Name or Level1Name.  The
; name never lives in RAM, so the score hit's deepest call chain cannot touch
; it.  The six columns are P0/P1 in three-copy close mode; ScoreSetup (in
; VBLANK) has positioned them at 56/64 and turned VDEL on, and this routine
; leaves NUSIZ/VDEL on for ScoreDraw.
!macro NameRows .base {
    LDA #0
    STA NameRow
.line:
    LDY NameRow
    LDA .base+0,Y
    STA WSYNC               ; line 0 is the setup/blank line
    STA GRP0                ; column 0
    LDA .base+5,Y
    STA GRP1                ; column 1
    LDA .base+10,Y
    STA GRP0                ; column 2
    LDA .base+15,Y
    STA ScoreTmp            ; hold column 3 while Y is needed
    LDX .base+20,Y          ; column 4 (a direct load saves the LDA/TAX pair)
    LDA .base+25,Y
    LDY ScoreTmp
    NOP                     ; the ScoreDraw timing pad
    CPX NameRow             ; timing only; flags discarded
    STY GRP1                ; column 3
    STX GRP0                ; column 4
    STA GRP1                ; column 5
    STA GRP0                ; commit column 5 through the cross-latch
    LDX NameRow
    INX
    STX NameRow
    CPX #5
    BNE .line
    LDA #0
    STA GRP0
    STA GRP1
}

; =============================================================================
; VISIBLE PICTURE — band, backdrop, play area
; =============================================================================
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    JSR NameDraw             ; rows 1-5; row 0 is the setup line
    LDA #0
    STA GRP0
    STA GRP1
    STA WSYNC                ; row 6
    JSR ScoreDraw            ; rows 7-15 (setup + eight score rows)

    ; The band is over; the game objects get their own colours.  The score
    ; and name pixels are already drawn, so changing the player colours here
    ; affects only the backdrop and play area.
    LDA #$10                ; one player copy, 2-pixel missiles
    STA NUSIZ0              ; ScoreDraw leaves the three-copy mode set
    STA NUSIZ1
    LDA #C_PLAYER
    STA COLUP0
    LDA #C_ENEMY
    STA COLUP1

; -----------------------------------------------------------------------------
; THE GENERATED BACKDROP — eight playfield rows, eight lines each
; -----------------------------------------------------------------------------
    ; Load the level's backdrop pointer (descriptor offset 10).
    LDY #10
    JSR LoadLevelArray
    LDA LevelPtr
    STA ArrayPtr
    LDA LevelPtr+1
    STA ArrayPtr+1

    +BackdropRow 0
    +BackdropRow 3
    +BackdropRow 6
    +BackdropRow 9
    +BackdropRow 12
    +BackdropRow 15
    +BackdropRow 18
    +BackdropRow 21

; -----------------------------------------------------------------------------
; THE PLAY AREA — seven setup lines, then 51 logical rows (102 lines)
; -----------------------------------------------------------------------------
; The play area is picture lines 81-191 (scanlines 118-228), 111 lines:
;   118  clear PF, HMCLR, P0's WSYNC (the P0 divide runs on 119)
;   119  P0 divide
;   120  P1's WSYNC (the P1 divide runs on 121)
;   121  P1 divide
;   122  HMOVE + play-state init
;   123  the HMOVE notch; prepare row 0
;   125  store row 0 (the PlayLoop checkpoint)
;   127  the first loop-body store (row 1); 51 logical rows (102 game lines)
;   227-228  two blank lines; PlayDone has four WSYNCs; overscan 229/6
PlayStart:
    STA WSYNC
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA HMCLR                ; the VBLANK fine offsets are already applied
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    SEC                      ; the positioner's divide starts with carry set
    JSR SetCoarseP0          ; its WSYNC ends 118; divide on 119
    STA WSYNC                ; ends 119
    LDA SLOT0_ACTIVE
    BEQ P1Default
    LDA SLOT0_X
    JMP P1Position
P1Default:
    LDA #80
P1Position:
    CLC
    ADC #POS_BIAS
    SEC
    JSR SetCoarseP1          ; its WSYNC ends 120; divide on 121
    STA WSYNC                ; ends 121
PlayHmove:
    STA HMOVE                ; line 122 HBLANK: blanks the next line (123)
    LDA #0
    STA PlayRow
    LDA #$FF
    STA P1Row
    STA WSYNC                ; ends 122
    +PrepareRow              ; row 0 on 123
    STA WSYNC                ; ends the prepare line

    STX ENAM1
    STY ENAM0
    STA ENABL
    LDA NextGRP0
    STA GRP0
    LDA NextGRP1
    STA GRP1
    INC PlayRow
    LDA PlayRow
    CMP #PLAY_ROWS
    BEQ PlayDone

PlayLoop:
    ; Row PlayRow is prepared during the remainder of the store line and
    ; the following hold line; its stores land at the next line's start.
    +PrepareRow
    STA WSYNC                ; ends the hold line
    STX ENAM1
    STY ENAM0
    STA ENABL
    LDA NextGRP0
    STA GRP0
    LDA NextGRP1
    STA GRP1
    INC PlayRow
    LDA PlayRow
    CMP #PLAY_ROWS
    BEQ PlayDone
    JMP PlayLoop

PlayDone:
    ; Four WSYNCs end the last row's store line, its hold line, and the two
    ; blank lines after the play area; the picture reaches 228 and the JMP
    ; lands at 229/6.
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    BIT Frame
    JMP OverscanStart

; =============================================================================
; OVERSCAN — 30 lines, then the next frame
; =============================================================================
OverscanStart:               ; checkpoint: scanline 229, cycle 6
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; NAME DRAW — select the level's 30-byte ROM name table
; =============================================================================
; The name is read from the generated table, not from a RAM buffer.  The band
; lines 0-6 draw the name; ScoreDraw then paints lines 7-15 from ScoreBuf.
NameDraw:
    LDA Level
    BEQ NameDraw0
    +NameRows Level1Name
    RTS
NameDraw0:
    +NameRows Level0Name
    RTS

; =============================================================================
; PLAYER AND FIRE
; =============================================================================
MovePlayer:
    ; left
    LDA SWCHA
    AND #$40                ; bit 6 = left, 0 = pressed
    BNE MoveNotLeft
    LDA PlayerX
    SEC
    SBC #PLAYER_MOVE
    CMP #PLAYER_MIN
    BCS MoveStoreLeft
    LDA #PLAYER_MIN
MoveStoreLeft:
    STA PlayerX
MoveNotLeft:
    ; right
    LDA SWCHA
    AND #$80                ; bit 7 = right, 0 = pressed
    BNE MoveNotRight
    LDA PlayerX
    CLC
    ADC #PLAYER_MOVE
    CMP #(PLAYER_MAX + 1)
    BCC MoveStoreRight
    LDA #PLAYER_MAX
MoveStoreRight:
    STA PlayerX
MoveNotRight:
    RTS

; -----------------------------------------------------------------------------
; HandleFire — one shot at a time; a press launches the ball from the player
; -----------------------------------------------------------------------------
HandleFire:
    LDA INPT4
    AND #$80
    EOR #$80                ; 1 = fire pressed
    STA Tmp
    AND PrevFire
    EOR Tmp                 ; new & ~previous
    BEQ NoFirePress
    LDA ShotActive
    BNE NoFirePress
    LDA #1
    STA ShotActive
    LDA PlayerX
    CLC
    ADC #4
    STA ShotX
    LDA #(PLAYER_Y - 1)
    STA ShotY
    LDA #0
    STA SLOT3_ACTIVE        ; the ball becomes the shot
NoFirePress:
    LDA Tmp
    STA PrevFire
    RTS

; =============================================================================
; ENEMIES — the four-slot table update
; =============================================================================
; X counts the slot byte offset: 0, 4, 8, 12.  Type 0 falls straight; type 1
; adds a one-pixel drift, bouncing at PLAYER_MIN/PLAYER_MAX.  The main lesson
; rejects type 2, so a type-2 byte would behave as straight here; the zigzag
; exercise adds the third branch.
UpdateEnemies:
    LDX #0
EnemyLoop:
    LDA SLOT0_ACTIVE,X
    BEQ EnemyNext
    ; y += speed
    LDA SLOT0_TYPE,X
    AND #$03
    STA Tmp
    LDA SLOT0_Y,X
    CLC
    ADC Tmp
    STA SLOT0_Y,X
    CMP #ENEMY_BOTTOM
    BCS EnemyKill
    ; type 1 drifts; type 0 (and the unhandled type) falls straight
    LDA SLOT0_TYPE,X
    AND #$C0
    CMP #$40
    BEQ EnemyDrift
    JMP EnemyNext
EnemyDrift:
    LDA SLOT0_TYPE,X
    AND #DIR_BIT
    BEQ DriftLeft
    ; right
    LDA SLOT0_X,X
    CLC
    ADC #1
    CMP #(PLAYER_MAX + 1)
    BCS DriftRightClamp
    STA SLOT0_X,X
    JMP EnemyNext
DriftRightClamp:
    LDA #PLAYER_MAX
    STA SLOT0_X,X
    LDA SLOT0_TYPE,X
    EOR #DIR_BIT
    STA SLOT0_TYPE,X
    JMP EnemyNext
DriftLeft:
    LDA SLOT0_X,X
    SEC
    SBC #1
    CMP #PLAYER_MIN
    BCC DriftLeftClamp
    STA SLOT0_X,X
    JMP EnemyNext
DriftLeftClamp:
    LDA #PLAYER_MIN
    STA SLOT0_X,X
    LDA SLOT0_TYPE,X
    EOR #DIR_BIT
    STA SLOT0_TYPE,X
    JMP EnemyNext
EnemyKill:
    LDA #0
    STA SLOT0_ACTIVE,X
EnemyNext:
    INX
    INX
    INX
    INX
    CPX #(SLOT_COUNT * SLOT_SIZE)
    BNE EnemyLoop
    RTS

; =============================================================================
; WAVE SPAWN — read the generated arrays through the level descriptor
; =============================================================================
; The first inactive slot wins: 0 = P1, 1 = M0, 2 = M1, 3 = the ball.  If all
; four slots are active the wave is dropped and its index consumed, so the
; four objects always represent four lives.  A wave that lands in slot 3
; while a shot is in flight is stored but not shown: the ball displays the
; shot until the shot ends.
SpawnWaves:
    LDA WaveIndex
    CMP WaveCount
    BCS SpawnDone
    LDY #0                   ; descriptor offset 0: WaveFrame
    JSR LoadLevelArray
    LDY WaveIndex
    LDA (LevelPtr),Y
    CMP Frame
    BNE SpawnDone

    ; Find the first inactive slot.  If all four are active, drop this wave
    ; and consume its index: a busy lab loses the spawn rather than
    ; overwriting an enemy, so the four objects always represent four lives.
    LDX #0
FindSlot:
    LDA SLOT0_ACTIVE,X
    BEQ SlotFound
    INX
    INX
    INX
    INX
    CPX #(SLOT_COUNT * SLOT_SIZE)
    BNE FindSlot
    ; all four occupied: consume the wave
    INC WaveIndex
    RTS

SlotFound:
    STX SlotOfs              ; the chosen slot byte offset, 0/4/8/12
    LDA #1
    STA SLOT0_ACTIVE,X

    ; x = WaveX
    LDY #2
    JSR LoadLevelArray
    LDY WaveIndex
    LDA (LevelPtr),Y
    LDX SlotOfs
    STA SLOT0_X,X

    ; y = WaveY
    LDY #4
    JSR LoadLevelArray
    LDY WaveIndex
    LDA (LevelPtr),Y
    LDX SlotOfs
    STA SLOT0_Y,X

    ; type/speed = (type << 6) | speed | direction-right
    LDY #6
    JSR LoadLevelArray
    LDY WaveIndex
    LDA (LevelPtr),Y
    STA Tmp                  ; speed
    LDY #8
    JSR LoadLevelArray
    LDY WaveIndex
    LDA (LevelPtr),Y
    ASL
    ASL
    ASL
    ASL
    ASL
    ASL                      ; type into bits 6-7
    ORA Tmp
    ORA #DIR_BIT
    LDX SlotOfs
    STA SLOT0_TYPE,X

    LDA WaveIndex
WaveSpawn:                   ; checkpoint: A = the wave index
    NOP
    INC WaveIndex
SpawnDone:
    RTS

; =============================================================================
; SHOT AND COLLISIONS
; =============================================================================
UpdateShot:
    LDA ShotActive
    BEQ ShotDone
    LDA ShotY
    SEC
    SBC #SHOT_SPEED
    CMP #SHOT_TOP
    BCC ShotGone
    STA ShotY

    ; Test slots 0-2.  Slot 3 is the ball's other role; while the shot owns
    ; the ball, a queued slot-3 enemy is not on screen and cannot be hit.
    LDX #0
ShotCheckLoop:
    LDA SLOT0_ACTIVE,X
    BEQ ShotNextSlot
    ; |ShotX - slot X| <= 6
    LDA ShotX
    SEC
    SBC SLOT0_X,X
    BCS ShotDxPos
    EOR #$FF
    ADC #1
ShotDxPos:
    CMP #7
    BCS ShotNextSlot
    ; |ShotY - slot Y| <= 8
    LDA ShotY
    SEC
    SBC SLOT0_Y,X
    BCS ShotDyPos
    EOR #$FF
    ADC #1
ShotDyPos:
    CMP #9
    BCS ShotNextSlot
    ; hit
    LDA #0
    STA SLOT0_ACTIVE,X
    STA ShotActive
    JSR AddScore
    RTS
ShotNextSlot:
    INX
    INX
    INX
    INX
    CPX #(3 * SLOT_SIZE)    ; slots 0, 1, 2 only
    BNE ShotCheckLoop
ShotDone:
    RTS
ShotGone:
    LDA #0
    STA ShotActive
    RTS

; -----------------------------------------------------------------------------
; AddScore — cap at 99, rebuild the six-digit window, then checkpoint
; -----------------------------------------------------------------------------
AddScore:
    LDA Score
    CMP #99
    BCS AddScoreStore
    INC Score
AddScoreStore:
    LDA Score
ScoreWrite:                  ; checkpoint: A = the score
    NOP
    JSR RebuildScore
    RTS

; RebuildScore — ScoreClear then the tens and ones digits in the last two
; columns.  The window reads 000042 for a score of 42; the value is 0-99.
RebuildScore:
    JSR ScoreClear
    LDA Score
    LDX #0
ScoreTens:
    CMP #10
    BCC ScoreTensDone
    SBC #10
    INX
    JMP ScoreTens
ScoreTensDone:
    STA Tmp                  ; ones
    LDA #4                   ; position 4 = tens, X = tens digit
    JSR ScoreSetDigit
    LDA #5                   ; position 5 = ones
    LDX Tmp
    JSR ScoreSetDigit
    RTS

; =============================================================================
; LEVEL DATA
; =============================================================================
; SetLevelData: LevelPtr = LevelDescLo/Hi[Level]; WaveCount = the level's
; wave count.  LoadLevelArray reads one of the descriptor's six pointers.
SetLevelData:
    LDX Level
    LDA LevelDescLo,X
    STA LevelPtr
    LDA LevelDescHi,X
    STA LevelPtr+1
    LDA LevelWaveCount,X
    STA WaveCount
    RTS

; SetP1Start — P1Start = (Slot0Y - PLAY_START) / 2, or $FF when the slot is
; inactive or still above the play area.  This runs in VBLANK, after the
; wave loads have finished with the $84 scratch byte.
SetP1Start:
    LDA #$FF
    STA P1Start
    LDA SLOT0_ACTIVE
    BEQ SetP1Done
    LDA SLOT0_Y
    SEC
    SBC #PLAY_START
    BCC SetP1Done
    LSR
    STA P1Start
SetP1Done:
    RTS

; -----------------------------------------------------------------------------
; SetObjectRows — precompute the three one-row objects' logical rows.
; $FF means "not on any play row".  The ball uses the shot's Y when the shot
; is active, otherwise the slot-3 enemy's Y.
; -----------------------------------------------------------------------------
SetObjectRows:
    LDA #$FF
    STA M1Row
    LDA SLOT2_ACTIVE
    BEQ ObjM1Done
    LDA SLOT2_Y
    SEC
    SBC #PLAY_START
    BCC ObjM1Done
    LSR
    STA M1Row
ObjM1Done:
    LDA #$FF
    STA M0Row
    LDA SLOT1_ACTIVE
    BEQ ObjM0Done
    LDA SLOT1_Y
    SEC
    SBC #PLAY_START
    BCC ObjM0Done
    LSR
    STA M0Row
ObjM0Done:
    LDA #$FF
    STA BallRow
    LDA ShotActive
    BEQ ObjBallSlot
    LDA ShotY
    JMP ObjBallRow
ObjBallSlot:
    LDA SLOT3_ACTIVE
    BEQ ObjBallDone
    LDA SLOT3_Y
ObjBallRow:
    SEC
    SBC #PLAY_START
    BCC ObjBallDone
    LSR
    STA BallRow
ObjBallDone:
    RTS

; LoadLevelArray: Y = descriptor offset (0,2,4,6,8,10).  On return LevelPtr
; points at the requested array and Y is one past the pointer's high byte.
LoadLevelArray:
    LDX Level
    LDA LevelDescLo,X
    STA ArrayPtr
    LDA LevelDescHi,X
    STA ArrayPtr+1
    LDA (ArrayPtr),Y
    STA LevelPtr
    INY
    LDA (ArrayPtr),Y
    STA LevelPtr+1
    RTS

; =============================================================================
; POSITIONING — the Lesson 26 divide-by-15 routines
; =============================================================================
; The caller sets the carry before the JSR; the routine's WSYNC starts the
; line and the divide begins on the following line.  That is why each
; positioner costs two visible lines.  The carry is preserved across WSYNC.
SetCoarseP0:
    STA WSYNC
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

SetCoarseM1:
    STA WSYNC
DivM1:
    SBC #15
    BCS DivM1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMM1
    STA RESM1
    RTS

SetCoarseBL:
    STA WSYNC
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
; DATA — the sprite shapes
; =============================================================================
; PlayerShape: eight rows, top-down; P0 is 8 pixels wide.
PlayerShape:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %11111111
    !byte %11111111
    !byte %01111110
    !byte %00111100
    !byte %00011000

; EnemyShape: eight rows, top-down.
EnemyShape:
    !byte %00111100
    !byte %01111110
    !byte %11011011
    !byte %11111111
    !byte %11111111
    !byte %11011011
    !byte %01111110
    !byte %00111100

; =============================================================================
; THE GENERATED LEVEL TABLES
; =============================================================================
; generated-levels.inc is produced by lesson67-generate.py from waves-a.txt
; and waves-b.txt.  It is data only; the engine above interprets it.
    !source "lessons/part9-dsl-path/67-automatable-patterns/generated-levels.inc"

; =============================================================================
; VECTORS — the 6507 reads RESET at $FFFC and jumps to Reset
; =============================================================================
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

<!-- END-FULL-SOURCE -->

### Code Walkthrough

#### Step 1 — Reset, the shared score library, and the initial level

`Reset` runs `+clean_start`, sets `SWACNT`/`SWBCNT` to input, blanks the objects and playfield, sets `CTRLPF` to `$10` (repeat playfield, 2-pixel ball) and the score colours to white. It sets `Level=0`, clears the switches and the score, sets `Frame=$FF` so the first VBLANK increment makes frame 0, puts the player at X=80, clears the four slots, and calls `SetLevelData`. There is no name-build step: the name is a ROM table selected by `Level`. Then `ScoreInit`/`ScoreClear`/`ScoreSetup` prepare the six-column window, and the first frame starts.

The score library is sourced after `* = $F000`; it owns `$A0-$D7`. The lab's own variables start at `$80`; `$D8/$D9` hold `ArrayPtr`, `$DA` is the spawn's `SlotOfs`, `$DB-$F1` are free, and `$F2-$FF` is the effective stack (the score chain's deepest use is 14 bytes: five return addresses + four PHAs). The name is drawn from the generated `Level0Name`/`Level1Name` ROM tables, so no name buffer sits under the stack.

#### Step 2 — The frame skeleton and the SELECT edge

`StartFrame` is the three-line VSYNC; `VblankStart` sets VBLANK and arms the 44-tick timer. The SELECT edge is `new & ~previous`: `SWCHB` bit 1, inverted, stored in `NewSelect`; `AND PrevSelect; EOR NewSelect` is true only on a fresh press. On a switch the engine stores the new `Level` (`LevelWrite`), sets `Frame=$FF`, clears the wave index, the shot, the score and the slots, reloads the descriptor, and clears the score window; the name is read from the new level's ROM table. The `LevelRead` checkpoint reports the active level every frame.

The frame counter increments next (`FrameRead`), and the level loop compares it with `LevelLoop`. At the loop frame it resets `Frame` and `WaveIndex`, clears the shot and the slots, and lets the same frame spawn the wave at frame 0. The score and the level continue.

#### Step 3 — Game logic in VBLANK

The VBLANK does the work the play kernel cannot: `MovePlayer` reads `SWCHA` bits 6/7 and clamps `PlayerX` to 8..152 in 4-pixel steps; `HandleFire` reads `INPT4` bit 7, detects a fresh press, starts the ball at the player's centre and top, and deactivates the ball slot; `UpdateEnemies` walks the four 4-byte slots, adds the speed to Y, kills an enemy at Y>=184, and drifts a type-1 X with a bounce at 8/152; `SpawnWaves` compares `WaveFrame[WaveIndex]` with `Frame`, scans for the first inactive slot, fills it, and drops the wave (consuming its index) if all four slots are busy; `UpdateShot` moves the ball up four pixels, deactivates it at the play top, and tests the three non-ball slots with a rectangular hitbox; a hit deactivates the enemy, increments the score (cap 99), rebuilds the six-digit window (`ScoreWrite`), and resets the shot. `SetP1Start` and `SetObjectRows` precompute the play kernel's start/row bytes.

The VBLANK then sets the level colours and clears the objects and playfield, positions the ball, M0 and M1 (each with the divide-by-15 routine), and calls `ScoreSetup`, which positions P0/P1 at 56/64 and applies one HMOVE to all five fine-motion registers. `+wait_timer` waits for the 37-line VBLANK and releases the picture.

#### Step 4 — The band and the generated backdrop

`BodyStart` is the first visible line. `NameDraw` draws five rows of the six-column name from the selected level's ROM table; its `STA WSYNC` before the stores makes line 0 the setup line, and its five rows land on lines 1-5. One blank line follows, then `ScoreDraw`'s nine-line window (setup line 7, eight rows 8-15). The band ends on picture line 15 (scanline 52); picture line 16 (53) is the one-line transition, and the backdrop's first store is on 54. After `ScoreDraw` the engine resets `NUSIZ0/NUSIZ1` to `$10` (one player copy, 2-pixel missiles) and changes `COLUP0/COLUP1` to the game colours; the band's pixels are already drawn, so the colour change affects only the backdrop and play area.

The backdrop is loaded through descriptor offset 10, copied into `ArrayPtr`, and drawn by the `BackdropRow` macro: row 0's three bytes are preloaded on the transition line 53, `STA WSYNC`, the stores begin on 54, then seven hold `WSYNC`s; the next row preloads on the last hold line. Eight calls with offsets 0..21 cover the 64 lines (54-117). The repeat playfield draws the same 20 chunks in both halves.

#### Step 5 — The play area and the 2-line kernel

The play area is picture lines 81-191 (scanlines 118-228), 111 lines. The seven setup lines are 118 (clear PF/HMCLR and P0's WSYNC), 119 (P0 divide), 120 (P1's WSYNC), 121 (P1 divide), 122 (HMOVE + play-state init), 123 (the HMOVE notch and prepare row 0), and 124 (row 0's store); the first `PlayLoop` store is 125. The 51 logical rows (102 game lines) run to `PlayDone` at 225, four `WSYNC`s follow, and the overscan grounds at 229/6. Each row's stores are `STX ENAM1 / STY ENAM0 / STA ENABL / LDA NextGRP0 / STA GRP0 / LDA NextGRP1 / STA GRP1`; the next row's `PrepareRow` macro runs during the store line and the hold line, so the worst-case prepare (P0 + P1 + three one-row objects) fits before the next `WSYNC`. `PrepareRow` uses the fixed player row, the P1 start/state, and the three precomputed rows; the macro is inlined so the JSR/RTS overhead does not eat the margin.

The `PlayDone` path uses four `WSYNC`s for the last row's store line, its hold line, and the two blank lines, then `BIT Frame / JMP OverscanStart`. The measured frame is 259/3, 0/5, 37/5, 229/6.

#### Step 6 — The generated tables and the vectors

The generator owns the name font: eight five-row glyphs (space, `-`, A, B, C, E, V, W), lowered into `LevelNName` (six columns x five rows) in the include. The engine has no name font or name buffer; it reads the selected level's ROM table. The player and enemy shapes are eight top-down bytes. `ZigOffset` appears only in exercise 1. The generated include is sourced at the end: ASCII names, the 30-byte name glyph tables, colours, wave counts, loop frames, descriptor pointers, descriptors, wave arrays, and 8x3 backdrop bytes. The vectors point at `Reset`, and `!fill $FFFA - *, $EA` pads the image to exactly 4,096 bytes.

## What You Should See

The lab opens on **level A**. The 16-line band shows `WAVE-A` in white on the level's dark-grey background, with the six-digit score `000000` underneath. The 64-line backdrop is the gold stepped skyline: two peaks with a square hole in each half, repeated by the playfield's repeat mode. The play area is dark grey with the green player diamond near the bottom, a gold P1 enemy, a green M0 dot, a gold M1, and the gold ball. The frame-0 wave spawns at x=84, y=100, speed 1; the player starts at x=80, y=170, so that wave falls almost directly onto the player's column. The gold 8x8 enemy in the two-second capture is a **later P1 wave**, not the frame-0 wave: the frame-0 wave has already left the play area by then. The HMOVE blank line (123) has a black 8-pixel notch at the left edge (TIA x=0-7; image x=25-72, around image y=378-380): the play area starts at 118, and the `STA HMOVE` on line 122 blanks line 123. That is the hardware's HMOVE left-edge artifact, not a missing playfield byte.

![Stella running level A of the Lesson 67 wave lab: WAVE-A and 000000 in the top band, a gold stepped skyline backdrop, a green player near the bottom, a gold enemy and green/gold missile dots in the dark play area; the title bar reads Stella 7.0: "67-automatable-patterns"](/images/lesson67/level-a.png)

*`level-a.png`: level A after two seconds. The band shows `WAVE-A` and `000000`; the backdrop is the two-peak gold staircase; the player is the green diamond (object y=170, displayed at picture 174); the gold 8x8 enemy is a later P1 wave; the small green and gold dots are M0/M1/ball. The frame-0 wave has already left by the two-second capture.*

The post-hit capture proves the critical name-buffer fix:

![Stella running level A after a score hit: WAVE-A and 000001 in the top band, the gold stepped skyline, the green player, and gold/green dots; the title bar reads Stella 7.0: "67-automatable-patterns"](/images/lesson67/level-a-hit.png)

*`level-a-hit.png`: the same committed ROM with `-holdjoy0 F` at power-on, captured after two seconds. The frame-0 wave is hit at about frame 14, so the score reads `000001`. `WAVE-A` is intact, and the name-band pixels are identical to `level-a.png`; only the score band differs. The score hit's deepest call chain (`UpdateShot -> AddScore -> RebuildScore -> ScoreClear -> ScoreSetDigit`) no longer has a name buffer to overwrite, because the name is read from the generated ROM table.*

<RomPlayer rom="/roms/part9-dsl-path/67-automatable-patterns/67-automatable-patterns.bin" title="Lesson 67 — Automatable Patterns (the wave lab)" />

Javatari starts muted; this ROM is silent, so there is nothing to unmute.

Press SELECT once, or hold it at power-on, for **level B**. The band shows `WAVE-B`; the background is light grey, the playfield red, and the backdrop a diagonal checker with a broad red block at the centre. The wave list is different: 13 waves, a different mix of straight and drifting enemies, and a different first spawn (x=40, y=140, speed 2, drift). The player, the score window and the engine are unchanged.

![Stella running level B of the Lesson 67 wave lab: WAVE-B and 000000 in the top band, a red diagonal checker backdrop on a light grey background, a green player near the bottom, and green/red/gold dots in the play area; the title bar reads Stella 7.0: "67-automatable-patterns"](/images/lesson67/level-b.png)

*`level-b.png`: level B after a SELECT edge at power-on, captured two seconds later. The name, palette and backdrop differ from level A; the engine is the same. The red dot is the ball with the level's playfield colour; the green and gold dots are the missiles.*

The debugger tells the same story as numbers. The lab's checkpoints:

| Checkpoint | Address (committed ROM) | Measured | Meaning |
|---|---|---|---|
| `StartFrame` | `$F1B4` | 259/3 (the first hit is the power-on partial frame at 15/18) | the first VSYNC instruction |
| `VblankStart` | `$F1C2` | 0/5 | the first VBLANK instruction |
| `BodyStart` | `$F2B2` | 37/5 | the first visible line |
| `OverscanStart` | `$F558` | 229/6 | the first overscan instruction |
| `LevelRead` | `$F20C` | A = 0 (A = 1 with SELECT) | the active level |
| `LevelWrite` | `$F1E0` | A = 1 with a SELECT edge | the new level |
| `WaveSpawn` | `$F713` | A = the wave index; X = the slot offset (0/4/8/12) | the wave index and the chosen slot |
| `ScoreWrite` | `$F76C` | A = 1 on the first hit | the score after the hit |
| `FrameRead` | `$F209` | A = 0, 1, 2, 3 | the frame counter after the increment |

The frame checkpoints, first hits:

```text
# StartFrame
BP:           1  15 18 -14 | Nv-BdIzC f0 06 30 ff |    (power-on)
BP:           2 259 03 -59 | nv-BdIZC 00 00 00 ff |
BP:           3 259 03 -59 | nv-BdIZC 00 00 00 ff |

# VblankStart
BP:           2   0 05 -53 | nv-BdIZC 00 06 30 ff |
BP:           3   0 05 -53 | nv-BdIZC 00 00 00 ff |

# BodyStart
BP:           2  37 05 -53 | nv-BdIZC 00 00 00 ff |
BP:           3  37 05 -53 | nv-BdIZC 00 00 01 ff |

# OverscanStart
BP:           2 229 06 -50 | nv-BdIZC 33 00 00 ff |
BP:           3 229 06 -50 | nv-BdIZC 33 00 00 ff |
```

The state checkpoints:

```text
# LevelRead (normal run)
BP:           2   0 56 100 | nv-BdIZC 00 06 30 ff |
BP:           3   0 56 100 | nv-BdIZC 00 00 00 ff |

# LevelWrite (-holdselect, the power-on SELECT edge)
BP:           2   0 43  61 | nv-BdIZC 01 06 30 ff |

# LevelRead (-holdselect)
BP:           2  22 73 151 | nv-BdIZC 01 06 30 ff |
BP:           4   0 56 100 | nv-BdIZC 01 00 00 ff |

# WaveSpawn (A = the wave index, X = the chosen slot offset)
BP:           2   7 66 130 | nv-BdIZc 00 00 00 fd |
BP:          14   8 47  73 | nv-BdIzc 01 04 01 fd |
BP:          26   9 53  91 | nv-BdIzc 02 08 02 fd |
BP:          38  10 35  37 | nv-BdIzc 03 0c 03 fd |
BP:          50   9 73 151 | nv-BdIzc 04 04 04 fd |    (wave 4, frame 48, slot 1)

# ScoreWrite (-holdjoy0 F, the first shot hits the frame-0 wave)
BP:          14  10 03 -59 | nv-BdIzc 01 00 01 fb |

# FrameRead
BP:           2   0 51  85 | nv-BdIZC 00 06 30 ff |
BP:           3   0 51  85 | nv-BdIzC 01 00 00 ff |
BP:           4   0 51  85 | nv-BdIZC 02 00 00 ff |
```

The frame checkpoints measure 259/3, 0/5, 37/5, 229/6 on every frame; a 10-second run logged no other scanline for `BodyStart`, `OverscanStart` or `StartFrame` beyond the power-on partial. The `LevelWrite` and `LevelRead` logs above come from a `-holdselect` run, so the power-on edge switches to level B. `-holdjoy0 F` holds the fire button at power-on; the one edge launches the shot that hits the frame-0 wave, and `ScoreWrite` reports A=1. The `WaveSpawn` log shows the slot rule in action: wave 0 takes slot 0, wave 1 slot 1, wave 2 slot 2, wave 3 slot 3, and wave 4 (frame 48) takes slot 1 (X=04) because slot 0 is still occupied by wave 0. Waves 6 and 9 are absent from the log: they arrived when all four slots were busy and were dropped.

The pixel check of the committed images:

| Image | Size | Title bar | What the pixels show |
|---|---|---|---|
| `level-a.png` | 1010×807 | `Stella 7.0: "67-automatable-patterns"` | TIA area 960×606 at (25,106); background `(63,63,62)`, playfield gold `(205,205,52)`, player green `(81,179,80)`, band text white `(234,234,233)`; the name `WAVE-A` and the score `000000`; the gold two-peak backdrop; the green/gold enemy dots |
| `level-a-hit.png` | 1010×807 | `Stella 7.0: "67-automatable-patterns"` | the same palette and backdrop as `level-a.png`; the name `WAVE-A` and the score `000001`; the name-band pixels are identical to `level-a.png`, and the score band differs (the `1` replaces the last `0`) |
| `level-b.png` | 1010×807 | `Stella 7.0: "67-automatable-patterns"` | TIA area 960×606 at (25,106); background `(162,162,161)`, playfield red `(194,61,60)`, player green `(81,179,80)`, band text white `(234,234,233)`; the name `WAVE-B` and `000000`; the red diagonal checker backdrop; green/red/gold dots |

All three captures show the black 8-pixel notch on the HMOVE blank line 123 (image x 25-72, y 378-380; the play area starts at 118). The `STA HMOVE` on line 122 blanks line 123; the notch is the hardware's documented HMOVE left-edge artifact, not a missing playfield byte.

> **Capture method.** `level-a.png` is `scripts/capture-screenshot.sh` on the committed
> `docs/public/roms/part9-dsl-path/67-automatable-patterns/67-automatable-patterns.bin`
> after two seconds, with the pointer parked at `(0,0)`. `level-a-hit.png` is the same
> ROM launched with `-holdjoy0 F` at power-on (one fire edge; the frame-0 wave is hit at
> about frame 14) and captured after two seconds with `import` on the same window.
> `level-b.png` is the same ROM launched with `-holdselect` at power-on (one SELECT edge,
> so the lab opens on level B) and captured after two seconds with `import`. The pointer
> was parked at `(0,0)` before every capture. All three images are 1010×807 and carry the
> window frame/title bar `Stella 7.0: "67-automatable-patterns"`; no cursor appears.
> The TIA area is 960×606 at (25,106) in all three. The `-holdselect` and `-holdjoy0`
> paths are the manual capture paths; the state logs above are the proof of the SELECT
> edge and the score hit.

## Exercises

Each exercise ships a 4,096-byte `exercise-NN-solution.asm`, a spec, and a committed generated include. The exercise solutions are part of the lesson deliverable: they assemble through `npm run roms`, run in Stella, and actually solve the exercise as written.

### Exercise 1: Add a zigzag wave (type 2)

**Challenge:** Run the stock generator with `--type-max 2` and extend the engine to display a zigzag enemy. The spec's `x` is the base position; the displayed X is the base plus a triangle-wave offset computed from the enemy's Y. Add a spec with zigzag waves, generate `generated-zigzag.inc`, and ship `exercise-01-solution.asm`.

**Hints:**
1. The generator's type limit is a CLI flag: `--type-max 2` (the default is 1). The validator then accepts `type 2`; no generator source edit is needed.
2. The engine already treats a type-2 byte as "falls straight" (the `AND #$C0; CMP #$40` branch only catches type 1). The base X is correct; only the display and the collision need the offset.
3. Use a 16-byte triangle indexed by `Y & $0F`, and add it to the base X before the positioners and before the shot's `dx` test. Clamp to 8..152.

**Expected Result:** The two levels in `waves-zigzag.txt` accept type-2 waves; `generated-zigzag.inc` has `$02` entries in `LevelWaveType`; the ROM is 4,096 bytes; the type-2 enemies move left and right as they fall, and a shot still hits them at their displayed X. A Stella break at `M0Position` shows the display X sweeping through the triangle (for the frame-12 wave, base 40: `$20`..`$30`).

**Solution:** See `exercise-01-solution.asm`.

The generator change is one flag:

```bash
python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-zigzag.txt \
  --out  lessons/part9-dsl-path/67-automatable-patterns/generated-zigzag.inc \
  --type-max 2
```

The committed include's header records `--type-max 2`, so `--check --type-max 2` reproduces it with the stock generator.

The engine diff adds the table and the helper, and routes the four display calls plus the collision through it:

```asm
; ZigOffset — a 16-step triangle in pixels, indexed by Y & $0F.
ZigOffset:
    !byte $00, $02, $04, $06, $08, $06, $04, $02
    !byte $00, $FE, $FC, $FA, $F8, $FA, $FC, $FE

DisplayX:
    LDA SLOT0_TYPE,X
    AND #$C0
    CMP #$80
    BNE DisplayXRaw
    LDA SLOT0_Y,X
    AND #$0F
    TAY
    LDA SLOT0_X,X
    CLC
    ADC ZigOffset,Y
    CMP #PLAYER_MIN
    BCS DisplayXHigh
    LDA #PLAYER_MIN
    RTS
DisplayXHigh:
    CMP #(PLAYER_MAX + 1)
    BCC DisplayXDone
    LDA #PLAYER_MAX
DisplayXDone:
    RTS
DisplayXRaw:
    LDA SLOT0_X,X
    RTS
```

`DisplayX` takes the slot's byte offset in X (0, 4, 8, or 12) and returns the displayed X in A. The P1 positioner calls it with X=0, M0 with 4, M1 with 8, and the ball with 12; the shot's `dx` test calls it before subtracting. The enemy's stored X never moves for type 2; the triangle is a display-time decision, which keeps the base in one byte.

### Exercise 2: Add a third level and a selector

**Challenge:** Run the stock generator with `--allow-level C`, write `waves-c.txt`, generate `generated-three.inc` with A/B/C, and make SELECT cycle 0→1→2→0. The new level needs its own name, colours, backdrop and wave list.

**Hints:**
1. The generator's level labels are a CLI list: the default is A/B; `--allow-level C` adds C to the dialect.
2. The engine's SELECT currently toggles A/B with `EOR #$01`; replace the toggle with `INC Level; CMP #LevelCount; BCC store; LDA #0`.
3. The include's `LevelCount` is a constant, so the compare is an immediate (`CMP #LevelCount`). The name font already has `C`.

**Expected Result:** `generated-three.inc` has `LevelCount = 3`, three descriptors, and a `Level2` set of arrays; `exercise-02-solution.asm` is 4,096 bytes; SELECT cycles A→B→C→A; level C's band reads `WAVE-C`, its backdrop is the vertical-bar pattern, and its colours are `bg $08`/`pf $C8`.

**Solution:** See `exercise-02-solution.asm`.

The generator change is one flag:

```bash
python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-a.txt \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-b.txt \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-c.txt \
  --out  lessons/part9-dsl-path/67-automatable-patterns/generated-three.inc \
  --allow-level C
```

The committed include's header records `--allow-level C`, so `--check --allow-level C` reproduces it with the stock generator.

The generated descriptor table grows by one entry; this is the include's descriptor-pointer block and the third descriptor:

```asm
LevelDescLo:
    !byte <Level0Desc, <Level1Desc, <Level2Desc
LevelDescHi:
    !byte >Level0Desc, >Level1Desc, >Level2Desc

Level2Desc:
    !word Level2WaveFrame
    !word Level2WaveX
    !word Level2WaveY
    !word Level2WaveSpeed
    !word Level2WaveType
    !word Level2Backdrop
```

The engine diff is the selector; the solution's `NameDraw` dispatch also selects `Level0Name`, `Level1Name` and `Level2Name`:

```asm
    LDA Level
    CLC
    ADC #1                   ; A -> B -> C -> A
    CMP #LevelCount
    BCC LevelStore
    LDA #0
LevelStore:
    STA Level
```

The committed solution's SELECT cycle is verified by source inspection: `LDA Level / CLC / ADC #1 / CMP #LevelCount / BCC LevelStore / LDA #0 / STA Level`. A continuous keyed A→B→C capture is not available because synthetic X key events do not reach Stella; instead, an evidence-only scratch build that starts on level 2 reports `LevelRead` A=2 and renders `WAVE-C`, proving the third descriptor and its arrays are complete. The committed `exercise-02-solution.asm` itself is 4,096 bytes, and its `LevelWrite` checkpoint reports A=1 for the first SELECT edge.

### Exercise 3: Generate a colour schedule

**Challenge:** Run the stock generator with `--allow-color` and add the schedule apply to the engine. Each level's background colour steps through the list at the level's frame clock. Generate `generated-color.inc` and ship `exercise-03-solution.asm`.

**Hints:**
1. The stock generator's `--allow-color` flag enables the `color <frame> <value>` directive. It emits `LevelColorCount`, two more descriptor pointers at offsets 12 and 14, and the `LevelNColorFrame`/`LevelNColorValue` arrays; no generator source edit is needed.
2. The engine needs **no** current-colour byte: recompute the schedule entry from `Frame` every frame and write `COLUBK` directly. `$8E` stays free; `$DB` is the scan index (outside the score library). Do **not** use `ScoreDigits[5]` (`$A5`), because a hit's `ScoreClear`/`ScoreSetDigit` overwrites it.
3. Recompute the schedule entry from `Frame` every frame, **after** the game logic in VBLANK, and write `COLUBK` from the recomputed colour. A hit's score rebuild can then never leave a stale colour.
4. No cursor reset is needed on a level switch or loop: the next frame's scan derives the entry from `Frame` and the new level's schedule; the frame-0 entry is the level's opening colour.

**Expected Result:** `generated-color.inc` has `LevelColorCount` and the two arrays; `exercise-03-solution.asm` is 4,096 bytes; the background steps through the six/seven colours at frames 0/24/48/72/96/120 (A) and 0/20/40/60/80/100/120 (B); a Stella break at `ColorWrite` reports A = `$02,$06,$0A,$0C,$08,$04` for level A. A hit at about frame 14, between the frame-0 and frame-24 entries, must leave the colour at `$02`; with `-holdjoy0 F` the `ColorWrite` log shows `$02` for frames 0-23 and `$06` from frame 24, with no `$01` (the score's ones digit) ever appearing.

**Solution:** See `exercise-03-solution.asm`.

The generator command enables the colour dialect:

```bash
python3 lessons/part9-dsl-path/67-automatable-patterns/lesson67-generate.py \
  --spec lessons/part9-dsl-path/67-automatable-patterns/waves-color.txt \
  --out  lessons/part9-dsl-path/67-automatable-patterns/generated-color.inc \
  --allow-color
```

The committed include's header records `--allow-color`, so `--check --allow-color` reproduces it with the stock generator. The colour support is gated: the default generator still rejects a `color` line, and only the flag adds `LevelColorCount`, the two descriptor pointers at 12/14, and the per-level colour arrays.

The generated schedule for level A:

```asm
LevelColorCount:
    !byte $06, $07
...
Level0ColorFrame:
    !byte $00, $18, $30, $48, $60, $78
Level0ColorValue:
    !byte $02, $06, $0A, $0C, $08, $04
```

The engine's apply walks the same descriptor:

```asm
ApplyColors:
    LDX Level
    LDA LevelColorCount,X
    STA Tmp                   ; the schedule length
    LDA #0
    STA ColorIdx
    LDY #12
    JSR LoadLevelArray        ; LevelPtr = ColorFrame
    LDY #0
ColorScan:
    CPY Tmp
    BCS ColorValue
    LDA (LevelPtr),Y
    CMP Frame
    BCC ColorTake
    BEQ ColorTake
    JMP ColorValue
ColorTake:
    STY ColorIdx
    INY
    JMP ColorScan
ColorValue:
    LDY #14
    JSR LoadLevelArray        ; LevelPtr = ColorValue
    LDY ColorIdx
    LDA (LevelPtr),Y
    STA COLUBK
ColorWrite:                   ; checkpoint: A = the colour written
    RTS
```

The colour schedule changes the band/backdrop/play-area background because `COLUBK` is the whole frame's background. It does not change the playfield colour, the sprites, or the score.

## Key Takeaways

- ✅ **A repeated pattern is data when a second instance would be the same code with different numbers.** The wave list is data; the play kernel, score window, positioners, and collision are engine.
- ✅ **The DSL is small, line-oriented, and validated.** Every field has a range, the wave index is ordered, the frames strictly increase, and the last frame plus the loop tail fits the byte frame counter. Errors are `spec:line: message`.
- ✅ **The generator lowers data, not a kernel.** A 20-character row becomes PF0/PF1/PF2; the wave fields become separate byte arrays; a six-word descriptor ties them together; `LevelLoop` is the computed restart frame. The dialect is selected by `--type-max`, `--allow-level` and `--allow-color`, so the stock generator reproduces every committed include.
- ✅ **`--check` is the drift gate.** The committed include is the deterministic image of the specs; CI never runs Python, and a stale include fails the author's check before the ROM does.
- ✅ **The engine interprets fixed tables.** `LoadLevelArray` reads a descriptor pointer, `(LevelPtr),Y` reads a field, the first inactive slot wins (a full lab drops the wave), and the type/speed byte packs three fields.
- ✅ **The 2-line play kernel and the precomputed rows keep the frame deterministic.** The measured frame is 259/3, 0/5, 37/5, 229/6 across hundreds of frames; the prepare work varies with the active objects but stays inside the two-line budget.
- ✅ **The boundary is the lesson.** A generator can lower a level description; it cannot invent a cycle-counted kernel. The exercises grow the grammar and the engine together, one field, one label, one directive at a time.

## What's Next

You have a generator and an engine that agree on a level format. [Lesson 68: Designing Your Kernel Architecture — A Zone Framework](/part9-dsl-path/68-kernel-architecture) moves the same idea up a level: instead of generating data for a fixed kernel, it composes the kernel itself from configurable display zones, enforces the 192-line budget at assembly time, and chooses among three layouts at runtime. The wave compiler lowered a level; the zone framework lowers a frame.
