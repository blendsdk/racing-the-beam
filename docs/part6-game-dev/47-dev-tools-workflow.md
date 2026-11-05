---
title: "Lesson 47: Development Tools & Workflow — The Build Dashboard"
description: "A build-pipeline dashboard drawn by the playfield — five stage lights, a fifteen-cell progress meter, and an eight-cell checksum row — plus the ACME macros, Makefile targets, git commits, Stella symbols, verification script, ROM builder, and screenshot pipeline that turn source into a tested cartridge."
prev:
  text: "Lesson 46: Debugging — Finding and Fixing Bugs"
  link: "/part6-game-dev/46-debugging"
next:
  text: "Lesson 48: Introduction to Kernels"
  link: "/part7-kernel-mastery/48-introduction-to-kernels"
---

# Lesson 47: Development Tools & Workflow — The Build Dashboard

> **Part 6: Game Development** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 02 (the Stella debugger), Lesson 15 (frame timing and the RIOT timer), Lesson 19 (the playfield), Lesson 34 (frame counters), Lesson 45 (the RAM map and ACME `!if`), Lesson 46 (breakpoints and state logs), and the build pipeline used by every lesson
> **You will learn:** how the five-stage pipeline (EDIT, ASSEMBLE, RUN, VERIFY, COMMIT) maps to ACME, `npm run roms`, Stella, `scripts/verify.sh`, and git; how `!macro`, `!if`, `!align`, `!fill`, `!for`, and `!source` work; how `-l` produces a symbol file and `-D` selects a build; how a checksum makes a build self-checking; how the dashboard's 192 visible lines are laid out; how to capture and verify the result
> **You will build:** "the build dashboard" — a 4,096-byte ROM with five 16-line stage blocks, a fifteen-cell progress bar, an eight-cell checksum row, a two-byte beep, a debug border, and a deterministic stage cycle; plus three exercise solutions: a sixth TEST stage, a conditional build border, and a rotated checksum

## Introduction

Lesson 46 ended with a state log: a breakpoint at `OverscanStart` reporting scanline 229, a
breakpoint at `ReadCX` reporting the collision byte, and a screenshot that showed the band the
log described. That is the second half of a working project. The first half is the part that
produces the ROM in the first place — the editor, the assembler, the emulator, the verification
script, and the commit. This lesson makes that half visible.

The companion program `demo-47.asm` is **the build dashboard**. Five 16-line stage blocks are
stacked at the top of the screen: EDIT, ASSEMBLE, RUN, VERIFY, and COMMIT. The stages light in
order, one every thirty frames. A completed stage is dim gold, the active stage is green, and a
stage that has not started is `$02`, the same dark field as the background. Below the stages, a
fifteen-cell progress bar counts the stage number, and an eight-cell checksum row shows the low
byte of an 8-bit sum over a 256-byte table. The checksum is computed once at reset and drawn as
bits, not as a decimal number. The program is not a game; it is the course's workflow turned
into a picture.

The picture is produced by the same tools the rest of the course uses. ACME's `!macro` expands
the repeated stage block, `!if` selects the debug border while the assembler is still running,
`!for` generates the checksum table, `!align` puts the table on a page boundary, and `!fill`
writes an end-of-table marker. `npm run roms` builds every lesson into `docs/public/roms/`, and
`scripts/verify.sh` re-assembles every source and compares it with the committed binary. The
dashboard is what you get when those stages succeed; a red border is what you get when the
debug build is the one that ran.

::: details TypeScript Equivalent

A build pipeline is a sequence of transformations, and a dashboard is a small state machine.
The shapes transfer; the timing and the memory do not:

```typescript
type Stage = "EDIT" | "ASSEMBLE" | "RUN" | "VERIFY" | "COMMIT";

class BuildDashboard {
  private readonly stages: Stage[] = [
    "EDIT", "ASSEMBLE", "RUN", "VERIFY", "COMMIT",
  ];
  private stage = 1;                       // 1-based, like the ROM's Stage byte

  tick(): void {
    this.stage = this.stage === this.stages.length ? 1 : this.stage + 1;
  }

  active(): Stage {
    return this.stages[this.stage - 1];
  }

  status(index: number): "done" | "active" | "future" {
    if (index + 1 < this.stage) return "done";
    if (index + 1 === this.stage) return "active";
    return "future";
  }

  checksum(table: Uint8Array): number {
    let sum = 0;
    for (const byte of table) sum = (sum + byte) & 0xff;
    return sum;
  }
}
```

The analogy breaks in four places. A TypeScript class exists at runtime; the `!macro` and `!if`
in this lesson are gone by the time the ROM exists — the macro is expanded into instructions and
the conditional is resolved into one immediate byte. The five stages are not methods called by
one program: each is a different tool (`acme`, `stella`, `scripts/verify.sh`, `git`) with a file
on disk as its hand-off. There is no garbage collector and no `Uint8Array` of convenience: the
dashboard owns thirty-two bytes at `$80–$9F`, and the stack lives in the same 128 bytes. And a
frame is not a timer callback: it is exactly 262 scanlines, drawn by a kernel that must finish
each line before the beam reaches the next one.

:::

## Theory

### Section 1: The Pipeline Is Five Stages

The course's workflow has five stages, and the dashboard's five blocks are those stages:

| Stage | Tool | Input | Output | What failure looks like |
|---|---|---|---|---|
| 1 EDIT | your editor | an idea | `demo-47.asm` | a typo ACME reports on the next build |
| 2 ASSEMBLE | `acme` | the source and its `!source` includes | `demo-47.bin` (4,096 bytes) | an error, or a ROM that is not 4,096 bytes |
| 3 RUN | `stella` | the `.bin` | a picture and a state log | a blank screen, a rolling frame, a wrong value |
| 4 VERIFY | `scripts/verify.sh` | every `lessons/**/*.asm` and the committed ROMs | `=== VERIFY PASSED ===` | a failed assembly, ROM drift, or a broken docs build |
| 5 COMMIT | `git` | the verified tree | one atomic commit | a mixed commit that cannot be reverted cleanly |

The order matters. A ROM that assembles but does not run is an ASSEMBLE-stage success and a
RUN-stage failure; a ROM that runs but whose source has drifted from the committed `.bin` is a
VERIFY-stage failure. The dashboard shows the stage that is currently active, not a score. The
green block is the stage you are in; the dim gold blocks are the stages that have already
produced their artifact.

::: tip The pipeline is not a metaphor
Every one of the five stages leaves a file you can inspect: the source, the `.bin`, the Stella
window, the verify output, and the commit. If you cannot name the artifact, you are not finished
with the stage. That rule catches the most common shortcut in hobby projects — "it works in
Stella" without a committed ROM or a repeatable build.
:::

### Section 2: ACME Is a Build Tool

ACME is not only an instruction translator. It is a small build tool with its own symbols,
macros, loops, and conditionals. The dashboard uses six of its directives.

**`!source` includes another file.** Every lesson starts with the same two lines:

```asm
    !source "include/vcs.asm"
    !source "include/macro.asm"
```

`vcs.asm` is the ground truth for the TIA and RIOT addresses; `macro.asm` supplies
`+clean_start`, `+vsync`, `+set_timer`, and `+wait_timer`. The include path is relative to the
project root, which is why `npm run roms` runs ACME from the repository root.

**`!macro` expands a block of source.** The dashboard's five stage blocks are one macro called
five times:

```asm
!macro StageBlock .index {
    LDA StageColors + .index
    STA COLUPF
    LDA #$FF
    STA PF0
    STA PF1
    STA PF2
    LDY #(STAGE_LINES - 1)
-   STA WSYNC
    DEY
    BNE -
    LDA #$00                ; the block's last line is a dark separator
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
}
```

The parameter `.index` is substituted at each call. ACME gives every macro call its own scope
for local labels, so the anonymous `-` label is resolved inside each expansion. The macro is a
textual tool: it does not save RAM or cycles; it saves the chance that five hand-written blocks
disagree. Adding a sixth stage is one more call plus a larger `STAGE_COUNT` — that is the first
exercise.

ACME has two kinds of scope for names that start with a dot: a `!zone` is a named region you
declare, and a macro call gets its own scope automatically. Local labels (and the anonymous
`-`/`+` labels) live inside that scope. This lesson keeps the whole file in the default zone and
leans on the macro scope; a larger project can use `!zone` to keep two modules' local labels from
colliding.

**`!if` selects source while assembling.** The source defines a default and lets the command
line override it:

```asm
!ifndef DEBUG {
    DEBUG = 0
}
```

Then the reset code chooses the border:

```asm
    !if DEBUG {
        LDA #C_RED
    } else {
        LDA #C_BG
    }
    STA COLUBK
```

Only one of those two `LDA` instructions reaches the ROM. The debug build and the release build
differ by two bytes: the `LDA #DEBUG` immediate and the border color immediate. `cmp` shows both.

**`!align` moves the program counter to a boundary.** `!align 255, 0` fills until the address is
a multiple of 256. The checksum table uses it so the table starts at `$F300`, a page boundary
that is easy to find in the debugger.

**`!fill` writes a repeated byte.** `!fill 16, $EA` writes sixteen bytes of `$EA` (the 6502
`NOP` opcode) after the table. It is an end-of-table marker, not executable code; the
4,096-byte image comes from the `* = $FFFA` vector block and the padding before it.

**`!for` generates data.** The 256-byte `CheckData` table is one loop:

```asm
CheckData:
    !for i, 0, (CHECK_BYTES - 1) {
        !byte ((i * 7 + 3) + ((i * i) >> 8)) & $FF
    }
```

ACME computes each expression while assembling. There is no runtime loop and no table stored in
RAM.

The command line is the other half of the build tool:

| Flag | What it does | Why this lesson uses it |
|---|---|---|
| `-f plain` | writes a raw binary with no header | the 2600 cartridge window expects the bytes at `$F000–$FFFF` |
| `-o build/demo-47.bin` | names the output file | keeps scratch builds out of the committed ROM tree |
| `-l build/demo-47.sym` | writes a symbol list | Stella can show `StageStep`, `BuildFlag`, and `CheckSum` by name |
| `-D DEBUG=1` | defines a global symbol | selects the debug build without editing the source |

A symbol file is a plain text list:

```
StageStep   = $f1e1
BuildFlag   = $f015
CheckSum    = $f1fa
```

The addresses move when the source changes. Re-assemble with `-l` after every edit and read the
file; do not copy an address from an old log.

### Section 3: The Makefile, the ROM Builder, and the Gate

The repository has two build front ends. The `Makefile` is the small, local one:

```bash
make          # assemble src/main.asm into build/game.bin
make run      # assemble, then launch Stella
make clean    # remove build/
make roms     # call scripts/build-roms.sh
```

The lesson ROMs use the `npm run roms` path because it builds every source in one pass:

```bash
npm run roms
```

`scripts/build-roms.sh` walks `lessons/**/*.asm`, assembles each file into the matching
`docs/public/roms/part…/NN-slug/name.bin`, and prints the size. It is the source of the committed
`.bin` files. Never edit a `.bin` by hand; regenerate it. The lesson files are generated assets
that are committed so the published site and the `<RomPlayer>` work without a build step.

`scripts/verify.sh` is the gate:

1. It assembles `src/main.asm` and checks that the starter ROM still builds.
2. It assembles every `lessons/**/*.asm` into a temporary directory and compares the result with
   the committed ROM. A missing file or a different byte is **ROM drift**.
3. It runs `npm run docs:build`, so a broken link or a bad frontmatter block fails the gate too.

The script uses a temporary directory and removes it on exit, so verification never dirties the
repository. On success it prints one line:

```
=== VERIFY PASSED ===
```

The gate is deliberately boring. A lesson is not "done" because the author saw it work once; it
is done when a clean checkout can reproduce every artifact.

The screenshot pipeline is another local tool. `scripts/capture-screenshot.sh` launches Stella
on a ROM, waits for the window, captures it with ImageMagick `import`, and closes Stella. For a
moving state it cannot aim by waiting longer or shorter, so the lesson launches Stella on the
committed ROM and takes a burst of captures with the same `xwininfo` window lookup, then selects
the frames by pixel analysis. That is how `stage2.png` and `stage4.png` were made: the program is
the real ROM, the window title names it, and the selected frame is proved by the bands and bar
cells, not by a chosen delay.

::: tip Drift is the failure the gate is designed to catch
You change a comment and forget to rebuild? No drift, because comments do not change bytes. You
change a `#` to a `$` and forget to rebuild? The source assembles to different bytes, the
committed `.bin` still has the old ones, and `verify.sh` fails with `ROM drift`. The fix is
`npm run roms`, then commit the regenerated `.bin` with the source change.
:::

### Section 4: Git Remembers What the Build Forgot

A build directory is disposable. Git is the project's memory: it records which source, which
ROM, which document, and which screenshot belonged together. The course uses one atomic commit
per lesson:

```bash
git status
git diff
git log --oneline
```

The message convention is `feat(lessonNN): <Lesson title>` for a new lesson and `fix(lessonNN): …`
for a repair. A lesson commit contains the source, the exercise solutions, the document, the
screenshots, the committed ROMs, and any site integration. Keeping them together means a later
reader can check out one commit and have a complete lesson.

Two habits make the history useful. First, commit only after `bash scripts/verify.sh` passes;
the gate is cheaper than a broken `master`. Second, read `git diff --stat` before committing: a
lesson that claims to touch four files but touches forty usually means a scratch directory or a
generated file slipped in. The `.gitignore` keeps `build/` out; the committed ROMs are the
exception, and they are generated on purpose.

### Section 5: The Dashboard on Screen

The visible picture is 192 scanlines. The dashboard divides them into five zones:

```
visible   0– 79   5 stage blocks × 16 lines = 80 lines
visible  80– 87   gap = 8 lines
visible  88–177   progress bar = 15 cells × 6 lines = 90 lines
visible 178–183   gap = 6 lines
visible 184–191   checksum row = 8 cells × 8 lines = 8 lines
                  total = 80 + 8 + 90 + 6 + 8 = 192
```

The full frame is 3 VSYNC lines + 37 VBLANK lines + 192 visible lines + 30 overscan lines = 262
lines. `StartFrame` is scanline 259, `VblankStart` is 0, `BodyStart` is 37, and `OverscanStart`
is 229. Those four numbers are the frame's signature; the state log in "What You Should See"
reports them.

Each stage block is sixteen lines: fifteen lines of a full-width playfield bar and one dark
separator. The separator is what makes five adjacent bands readable; without it, a completed run
of the same color would look like one tall block. The active stage is green `$C8`, a completed
stage is dim gold `$16`, and a future stage is `$02`. In the release build `$02` is also the
background, so future stages disappear into the field. In the debug build the background is red,
and the future stages become dark `$02` rectangles inside a red frame.

The progress bar is a vertical column of fifteen cells at chunk 6, TIA X=24–27. Each cell is six
lines tall and one playfield chunk (four pixels) wide. The cell's byte is `$20` (PF1 bit 5) when
lit and `$00` when dark. The bar grows from the bottom: cell 0 is the bottom cell and cell 14 is
the top cell. The number of lit cells equals the stage number, so stage 2 lights two cells and
stage 4 lights four. `CTRLPF=$01` mirrors the whole playfield, so the same column appears at
X=132–135; the left copy is the reference.

The checksum row is eight cells of eight lines at chunks 2–9, TIA X=8–39. The cells are
horizontal, each one chunk wide. The mapping is:

| Cell | TIA X | Playfield bit | Checksum bit |
|---|---|---|---|
| 0 | 8–11 | PF0 bit 6 | bit 7 |
| 1 | 12–15 | PF0 bit 7 | bit 6 |
| 2 | 16–19 | PF1 bit 7 | bit 5 |
| 3 | 20–23 | PF1 bit 6 | bit 4 |
| 4 | 24–27 | PF1 bit 5 | bit 3 |
| 5 | 28–31 | PF1 bit 4 | bit 2 |
| 6 | 32–35 | PF1 bit 3 | bit 1 |
| 7 | 36–39 | PF1 bit 2 | bit 0 |

A set bit lights its cell gold `$1A`; a clear bit shows the background. The right half is the
mirror of this row. Because the row is only eight lines tall, the two playfield bytes are
computed once and held for the whole zone.

The kernel is **work-first**: each zone writes its registers, then waits with `STA WSYNC`. The
stage macro writes the color and the three playfield bytes at the top of the block's first line.
From `BodyStart` at cycle 5, PF0 is written by cycle 17 and PF1 by cycle 20, before the first
playfield slot at about cycle 22.7; PF2 is written by cycle 23, and its first visible slot is
later in the line. The progress bar's PF1 store finishes by cycle 18 (first cell) / 16 (later
cells), before the first playfield slot at about 22.7. The checksum row has no per-line work at
all.

### Section 6: The Checksum and the Two Builds

The checksum table is generated at assembly time:

```asm
CheckData:
    !for i, 0, (CHECK_BYTES - 1) {
        !byte ((i * 7 + 3) + ((i * i) >> 8)) & $FF
    }
```

The runtime sum is an 8-bit wrap:

```asm
    LDA #$00
    LDX #$00
SumLoop:
    CLC
    ADC CheckData,X
    INX
    BNE SumLoop
```

After 256 adds, `A` holds the low byte. For this table the value is `$EC` (236). A Python
cross-check produces the same number:

```python
data = [((i * 7 + 3) + ((i * i) >> 8)) & 0xFF for i in range(256)]
print(hex(sum(data) & 0xFF))          # 0xec
```

The checksum row draws `$EC` as `1110 1100`, so cells 0, 1, 2, 4, and 5 are lit and cells 3, 6,
and 7 are dark. The row is stable because the table and the sum are both fixed.

ACME can check the same value at assembly time. This snippet is not in the lesson ROM, but it is
the pattern to add when a table must not change silently:

```asm
!set total = 0
!for i, 0, (CHECK_BYTES - 1) {
    !set total = (total + (((i * 7 + 3) + ((i * i) >> 8)) & $FF)) & $FF
}
!if total != $EC {
    !error "CheckData changed: update the Python cross-check"
}
!if DEBUG {
    !warn "DEBUG build: red border enabled"
}
```

`!error` stops the build and writes no ROM. `!warn` prints a message and keeps going, which is
the right choice for a debug build: the build is valid, but the reader should know which one
ran. (ACME parses a source file more than once, so a top-level `!warn` can appear more than once
in the console output.)

The two builds are the same source with different symbols:

```bash
acme -f plain -o build/demo-47.bin lessons/part6-game-dev/47-dev-tools-workflow/demo-47.asm
acme -f plain -D DEBUG=1 -l build/demo-47-debug.sym \
  -o build/demo-47-debug.bin \
  lessons/part6-game-dev/47-dev-tools-workflow/demo-47.asm
cmp build/demo-47.bin build/demo-47-debug.bin
```

Both outputs are exactly 4,096 bytes. `cmp` reports that they differ at byte 21 (the `LDA #DEBUG`
immediate) and byte 25 (the border color). `BuildValue` stores the same symbol at reset, so the
`BuildFlag` checkpoint reports `A=0` for the release build and `A=1` for the debug build even
though the picture is the only other difference.

## The Code

### Building This Lesson

```bash
# every lesson ROM, including this one:
npm run roms

# or just this one:
acme -f plain -o build/demo-47.bin \
  lessons/part6-game-dev/47-dev-tools-workflow/demo-47.asm

# the debug build, with a symbol file:
acme -f plain -D DEBUG=1 -l build/demo-47-debug.sym \
  -o build/demo-47-debug.bin \
  lessons/part6-game-dev/47-dev-tools-workflow/demo-47.asm

stella build/demo-47.bin
```

The three exercise solutions sit beside the lesson source. Each is a complete 4,096-byte ROM:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part6-game-dev/47-dev-tools-workflow/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part6-game-dev/47-dev-tools-workflow/exercise-02-solution.asm
acme -f plain -o build/exercise-03.bin \
  lessons/part6-game-dev/47-dev-tools-workflow/exercise-03-solution.asm
```

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 47: Development Tools & Workflow — The Build Dashboard — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; What this program does:
;   "the build dashboard": the course's build pipeline drawn as a vertical
;   status board.  Five 16-line stage blocks are stacked at the top: EDIT,
;   ASSEMBLE, RUN, VERIFY and COMMIT.  The stages light in order, one every
;   STAGE_PERIOD frames; each stage stays active for its own window and then
;   becomes a completed block.  Below the stages a fifteen-cell progress bar
;   counts the stages, and an eight-cell checksum row shows the low byte of an
;   8-bit sum over a 256-byte table.
;
;   The point of the demo is not the picture by itself: it is that the picture
;   is produced by the same build pipeline the lesson describes.  The source
;   uses an ACME !macro for the repeated stage block, !if for the debug
;   build's border, !for for the checksum table, !align for the table's page
;   alignment, and !fill for an end-of-table marker.  The Makefile target, git commit,
;   scripts/verify.sh, npm run roms and scripts/capture-screenshot.sh are the
;   other half of the lesson.
;
; The screen (192 visible lines, CTRLPF=$01 mirrors the playfield):
;   visible 0-79    the five stage blocks, sixteen lines each.  A completed
;                   stage is dim gold ($16), the active stage is green
;                   ($C8), and a future stage is $02.  Each block has
;                   fifteen full-width playfield lines (PF0/PF1/PF2 = $FF)
;                   and one dark separator line, so completed stages stay
;                   distinguishable from each other.
;   visible 80-87   a background gap (eight lines).
;   visible 88-177  the progress bar: fifteen cells of six lines at chunk 6
;                   (X=24-27, PF1=$20), drawn from the bottom up.  Cell 0 is
;                   the bottom cell (visible 172-177) and cell 14 is the top
;                   cell (visible 88-93).  The number of lit cells equals the
;                   active stage number (1-5), so stage 2 lights two cells and
;                   stage 4 lights four.  CTRLPF mirrors the column at
;                   X=132-135; the left copy is the reference.
;   visible 178-183 a background gap (six lines).
;   visible 184-191 the checksum row: eight cells of eight lines at chunks
;                   2-9 (X=8-39).  Cell 0 is the most significant bit (bit 7)
;                   and cell 7 is the least significant bit (bit 0).  A set
;                   bit lights its cell gold; a clear bit leaves the
;                   background.  CTRLPF mirrors the row at X=120-151.
;   The zones total 80 + 8 + 90 + 6 + 8 = 192 lines; OverscanStart is
;   scanline 229.
;
; The stage cycle:
;   Stage starts at 1 (EDIT).  StageTimer counts down from 30 frames; when it
;   reaches zero, AdvanceStage bumps Stage.  Stage 5 (COMMIT) is held for 60
;   frames, then AdvanceStage wraps to 1.  Fire advances the stage by hand
;   (and wraps 5 -> 1); SELECT resets to stage 1.  Both actions beep.  The
;   cycle is 4 x 30 + 60 = 180 frames, so a capture can find stage 2 between
;   frames 31-60 and stage 4 between frames 91-120.
;
; The checksum:
;   CheckData is 256 bytes generated by an ACME !for loop:
;       CheckData[i] = ((i * 7 + 3) + ((i * i) >> 8)) & $FF
;   The runtime sum is the low byte of the 8-bit total:
;       CheckSum = (sum of CheckData[0..255]) & $FF
;   The sum is computed once at reset.  The Python cross-check in the lesson
;   document produces the same value; the checksum row draws its eight bits,
;   not a decimal number.
;
; The two builds:
;   The release build is the committed ROM and uses DEBUG=0: the background
;   is $02 and there is no border.  The debug build is assembled with
;   -D DEBUG=1 and paints the background red ($42), so every gap and every
;   unlit cell becomes a red border around the dashboard.  BuildValue stores
;   the same DEBUG value at reset, and the BuildFlag checkpoint reports it.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   BuildFlag (A = DEBUG, once at reset), StageStep (A = the new stage, once
;   per transition), CheckSum (A = the 8-bit sum, once at reset), BodyStart
;   (37), OverscanStart (229).  Stage is $80, StageTimer $81, BuildValue $82,
;   SumByte $83, CheckPF0 $84, CheckPF1 $85.  The full RAM map is below.
;
; Build (release, the committed ROM):
;   acme -f plain -o build/demo-47.bin \
;        lessons/part6-game-dev/47-dev-tools-workflow/demo-47.asm
; Build (debug, with the red border and the symbol file):
;   acme -f plain -D DEBUG=1 -l build/demo-47-debug.sym \
;        -o build/demo-47-debug.bin \
;        lessons/part6-game-dev/47-dev-tools-workflow/demo-47.asm
; Run:
;   stella build/demo-47.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan

STAGE_COUNT    = 5       ; EDIT, ASSEMBLE, RUN, VERIFY, COMMIT
STAGE_PERIOD   = 30      ; frames per stage (0.5 s at 60 Hz)
STAGE_HOLD     = 60      ; frames held on the last stage before the restart
STAGE_LINES    = 16      ; visible lines per stage block

BAR_CELLS      = 15      ; the progress bar's fifteen cells
BAR_LINES      = 6       ; six visible lines per cell
BAR_CHUNK      = $20     ; PF1 bit 5 = chunk 6 = X=24-27

CHECK_CELLS    = 8       ; the checksum row's eight cells
CHECK_BYTES    = 256     ; CheckData is one page

BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright beep

C_GREEN        = $C8     ; the active stage
C_GOLD         = $1A     ; the progress and checksum cells
C_DIM_GOLD     = $16     ; a completed stage: a dimmer gold than $1A
C_RED          = $42     ; the debug build's border
C_BG           = $02     ; the release background and a future stage

; =============================================================================
; BUILD FLAGS — ACME's assembler-time symbols
; =============================================================================
; The source defines DEBUG=0 only when the command line did not.  That is the
; difference between:
;   acme -f plain -o release.bin demo-47.asm          -> DEBUG=0
;   acme -f plain -D DEBUG=1 -o debug.bin demo-47.asm -> DEBUG=1
; !if reads the symbol while ACME assembles; the branch is resolved before a
; single ROM byte is written.
!ifndef DEBUG {
    DEBUG = 0
}

; =============================================================================
; RAM ALLOCATION ($80-$9F; +clean_start zeroes every byte)
; =============================================================================
Stage        = $80   ; the active stage, 1..STAGE_COUNT
StageTimer   = $81   ; frames left in the current stage
BuildValue   = $82   ; DEBUG as a runtime byte (BuildFlag checkpoint)
SumByte      = $83   ; the 8-bit checksum (CheckSum checkpoint)
CheckPF0     = $84   ; the checksum row's PF0 byte
CheckPF1     = $85   ; the checksum row's PF1 byte
PrevFire     = $86   ; fire state last frame (1 = pressed)
PrevSelect   = $87   ; SELECT state last frame (1 = pressed)
BeepTimer    = $88   ; frames of beep remaining
BeepPitch    = $89   ; AUDF for the beep
BarLevel     = $8A   ; lit progress cells, 1..BAR_CELLS
BarBuf       = $8B   ; fifteen cell bytes, $8B-$99 ($20 lit, $00 dark)
StageColors  = $9A   ; five stage colors, $9A-$9E
Scratch      = $9F   ; reset-time bit shifter, then the input-edge byte
;
; $80-$9F is the full Lesson 45 lesson block.  The score and random libraries
; are not used.  The stack lives at $F8-$FF; the call depth stays shallow.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; StageBlock — one 16-line stage block
; =============================================================================
; ACME gives every macro call its own local-label scope, so the anonymous
; "backward" label below is resolved inside each expansion.  The parameter
; .index is substituted into the StageColors expression; the color itself is
; a runtime value because the active stage changes every 30 frames.
; The block is fifteen lit lines plus a one-line separator.  The separator
; is what turns five adjacent bands of the same color into five readable
; stages; without it a completed run looks like one tall gold block.
!macro StageBlock .index {
    LDA StageColors + .index
    STA COLUPF
    LDA #$FF
    STA PF0
    STA PF1
    STA PF2
    LDY #(STAGE_LINES - 1)
-   STA WSYNC
    DEY
    BNE -
    LDA #$00                ; the block's last line is a dark separator
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
}


; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the build flag is a runtime copy of the assembler symbol --------------
; BuildFlag is the checkpoint: a breakpoint there stops before the store, with
; A already holding DEBUG.  The value also lets the debugger answer "which
; build is this?" without reading the source or the border color.
    LDA #DEBUG
BuildFlag:                  ; checkpoint: A = DEBUG
    STA BuildValue

; --- the border: an assembly-time !if, not a runtime branch ----------------
; The release build is the committed ROM: background $02, no border.  The
; debug build paints every gap and unlit cell red.  Both builds are exactly
; 4,096 bytes; only this byte (and the immediate on the previous instruction)
; differs.
    !if DEBUG {
        LDA #C_RED
    } else {
        LDA #C_BG
    }
    STA COLUBK

    LDA #$01
    STA CTRLPF              ; mirror the playfield; the left half is the reference
    LDA #BEEP_PITCH
    STA BeepPitch

    LDA #$01
    STA Stage               ; start on EDIT
    LDA #STAGE_PERIOD
    STA StageTimer

; --- the checksum is computed once, before the first frame ----------------
; 256 adds are free at reset; doing them every frame would spend VBLANK time
; for a number that never changes.
    JSR ComputeCheckSum

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
; 1. THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
; BeepTimer counts down every frame and silences channel 0 at zero.  The
; sound itself is not the lesson's subject; it is the same two-byte beep the
; rest of Part 6 uses.
    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — advance one stage on the 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1, and the
; EOR/AND pair keeps only a new press.  Fire is a manual StageStep: the same
; AdvanceStage routine the clock calls, so the checkpoint reports both kinds
; of transition.
    LDA INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA Scratch
    EOR PrevFire
    AND Scratch
    BEQ NoFireEdge
    JSR AdvanceStage
    JSR BeepStart
NoFireEdge:
    LDA Scratch
    STA PrevFire

; -----------------------------------------------------------------------------
; 3. SELECT — reset the dashboard to stage 1
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  The edge, not the level, restarts
; the cycle.  SELECT is also the screenshot helper: a capture can start from
; a known stage without waiting for the 180-frame cycle.
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelectEdge
    LDA #$01
    STA Stage
    LDA #STAGE_PERIOD
    STA StageTimer
    JSR BeepStart
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 4. THE STAGE CLOCK — one stage every 30 frames, 60 on the last
; -----------------------------------------------------------------------------
; AdvanceStage increments Stage and reloads StageTimer.  At stage 5 the
; routine wraps to stage 1; the 60-frame hold is set when the clock reaches
; stage 5, so the COMMIT block stays green for one second before the cycle
; starts again.
    DEC StageTimer
    BNE StageTickDone
    JSR AdvanceStage
StageTickDone:

; -----------------------------------------------------------------------------
; 5. THE STATUS BYTES — five stage colours and fifteen bar cells
; -----------------------------------------------------------------------------
; Both tables are rebuilt in VBLANK from the single Stage byte.  The kernel
; then reads them without a comparison per line: the stage blocks take their
; color from StageColors, and the bar takes its lit/dark byte from BarBuf.
    LDX #$00
StageColorLoop:
    TXA
    CLC
    ADC #$01                ; the block's 1-based number
    CMP Stage
    BEQ StageColorActive
    BCS StageColorFuture
    LDA #C_DIM_GOLD         ; i + 1 < Stage: completed
    JMP StageColorStore
StageColorActive:
    LDA #C_GREEN
    JMP StageColorStore
StageColorFuture:
    LDA #C_BG               ; i + 1 > Stage: not started
StageColorStore:
    STA StageColors,X
    INX
    CPX #STAGE_COUNT
    BNE StageColorLoop

; --- the bar level is the stage number, clamped to the fifteen cells ------
    LDA Stage
    CMP #BAR_CELLS
    BCC BarLevelOk
    LDA #BAR_CELLS
BarLevelOk:
    STA BarLevel

; --- build the fifteen cell bytes bottom-up ------------------------------
; Cell 0 is the bottom cell and cell 14 is the top cell.  A cell below the
; level is lit with BAR_CHUNK; a cell at or above it is dark.  The kernel
; draws cell 14 first, so the bar grows from the bottom of the zone.
    LDX #$00
BarFill:
    CPX BarLevel
    BCS BarDark
    LDA #BAR_CHUNK
    JMP BarStore
BarDark:
    LDA #$00
BarStore:
    STA BarBuf,X
    INX
    CPX #BAR_CELLS
    BNE BarFill

; --- a clean first visible line ------------------------------------------
; The stage macro writes every playfield byte, but clearing them here removes
; the previous frame's checksum bytes before the picture turns on and keeps
; the first line's stores before the playfield slots.
    LDA #$00
    STA PF0
    STA PF1
    STA PF2

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines, work-first: write the line, then WSYNC
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0

; --- visible 0-79: the five stage blocks ---------------------------------
; StageBlock is an ACME !macro: the five calls below expand to the same
; stores with a different table index.  Each call holds its color for
; STAGE_LINES - 1 lines and then clears the playfield for the separator line.
; The first block is line 37; after five blocks the CPU is at cycle 5 of
; line 117, ready for the gap.
    +StageBlock 0
    +StageBlock 1
    +StageBlock 2
    +StageBlock 3
    +StageBlock 4

; --- visible 80-87: the first gap ----------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #8
GapRow:
    STA WSYNC
    DEY
    BNE GapRow

; --- visible 88-177: the progress bar ------------------------------------
; Fifteen cells of six lines.  The cell bytes are precomputed in VBLANK, so
; the per-cell cost is one load and three stores before the six WSYNCs.  The
; PF1 store completes by cycle 18 (first cell) / 16 (later cells), before
; the first playfield slot at about 22.7; PF0 and PF2 follow before their
; own slots.
    LDA #C_GOLD
    STA COLUPF
    LDX #(BAR_CELLS - 1)    ; cell 14, the top cell
BarCell:
    LDA BarBuf,X
    STA PF1
    LDA #$00
    STA PF0
    STA PF2
    LDY #BAR_LINES
BarLine:
    STA WSYNC
    DEY
    BNE BarLine
    DEX
    BPL BarCell

; --- visible 178-183: the second gap -------------------------------------
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #6
Gap2Row:
    STA WSYNC
    DEY
    BNE Gap2Row

; --- visible 184-191: the eight checksum cells ---------------------------
; The two bytes were built at reset from SumByte.  Bit 7 is cell 0 at chunk 2
; and bit 0 is cell 7 at chunk 9; PF0 carries cells 0-1 and PF1 carries cells
; 2-7.  A set bit is a gold cell; a clear bit shows the background.
    LDA #C_GOLD
    STA COLUPF
    LDA CheckPF0
    STA PF0
    LDA CheckPF1
    STA PF1
    LDA #$00
    STA PF2
    LDY #CHECK_CELLS
ChecksumRow:
    STA WSYNC
    DEY
    BNE ChecksumRow

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
; AdvanceStage — move to the next stage and reload the stage clock
; =============================================================================
; A is the new stage when the routine returns.  StageStep is placed after the
; store, so a breakpoint there reports the value the rest of the frame will
; use.  Stage 5 wraps to 1; when the clock reaches 5 it sets the long hold.
AdvanceStage:
    LDA Stage
    CMP #STAGE_COUNT
    BCC AdvanceIncrement
    LDA #$01                ; COMMIT -> EDIT
    JMP AdvanceStore
AdvanceIncrement:
    CLC
    ADC #$01
AdvanceStore:
    STA Stage
StageStep:                  ; checkpoint: A = the new stage
    CMP #STAGE_COUNT
    BNE AdvanceNormalTimer
    LDA #STAGE_HOLD
    JMP AdvanceTimerStore
AdvanceNormalTimer:
    LDA #STAGE_PERIOD
AdvanceTimerStore:
    STA StageTimer
    RTS

; =============================================================================
; ComputeCheckSum — the 8-bit sum of CheckData, once at reset
; =============================================================================
; A starts at 0 and takes 256 ADC steps; the carry is cleared before each
; add, so the sum wraps at 256 exactly as an 8-bit checksum should.  After
; the loop A holds the low byte.  CheckSum is the checkpoint: a breakpoint
; there reports that byte before it is stored.
; The second half maps the eight bits to the two playfield bytes:
;   bit 7 -> cell 0 -> PF0 bit 6 (chunk 2)
;   bit 6 -> cell 1 -> PF0 bit 7 (chunk 3)
;   bit 5 -> cell 2 -> PF1 bit 7 (chunk 4)
;   ...
;   bit 0 -> cell 7 -> PF1 bit 2 (chunk 9)
ComputeCheckSum:
    LDA #$00
    LDX #$00
SumLoop:
    CLC
    ADC CheckData,X
    INX
    BNE SumLoop
CheckSum:                   ; checkpoint: A = the 8-bit sum
    STA SumByte

    LDA SumByte
    STA Scratch
    LDA #$00
    STA CheckPF0
    STA CheckPF1
    LDX #$00
BitLoop:
    ASL Scratch             ; the next bit falls into carry, MSB first
    BCC NoCheckBit
    LDA CheckPF0
    ORA CheckMask0,X
    STA CheckPF0
    LDA CheckPF1
    ORA CheckMask1,X
    STA CheckPF1
NoCheckBit:
    INX
    CPX #CHECK_CELLS
    BNE BitLoop
    RTS

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
; AUDC 0C is the div-6 tone from Lesson 35; AUDV 0A is audible but not loud.
; The VBLANK clock silences the channel two frames later.
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; CHECKSUM BIT MASKS — one entry per cell, 0 where the cell is in the other
; playfield register
; =============================================================================
CheckMask0:
    !byte $40, $80, $00, $00, $00, $00, $00, $00
CheckMask1:
    !byte $00, $00, $80, $40, $20, $10, $08, $04

; =============================================================================
; CheckData — 256 bytes generated at assembly time
; =============================================================================
; !align 255, 0 puts the table on a page boundary.  The alignment is not
; needed for a sum, but it makes the table easy to find in a debugger and it
; demonstrates the directive.  !for emits the 256 bytes; the Python one-liner
; in the lesson document produces the same table and the same checksum.
    !align 255, 0
CheckData:
    !for i, 0, (CHECK_BYTES - 1) {
        !byte ((i * 7 + 3) + ((i * i) >> 8)) & $FF
    }

; --- an end-of-table marker: !fill writes a fixed byte instead of code ----
; The sixteen $EA bytes mark the end of CheckData and demonstrate !fill.
; They are never executed; the 4,096-byte image comes from the * = $FFFA
; vector block and the padding before it.
    !fill 16, $EA

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
> `lessons/part6-game-dev/47-dev-tools-workflow/demo-47.asm`.

### Code Walkthrough

#### Step 1 — The build symbol and the RAM map

The source starts by defining the tools it depends on and a default build symbol:

```asm
    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

!ifndef DEBUG {
    DEBUG = 0
}
```

`!ifndef` means "if the symbol is not defined". The command-line `-D DEBUG=1` defines it before
the source is read, so the default is skipped. Without `-D`, `DEBUG` is `0` and the release
branch is assembled.

The RAM map is thirty-two bytes, `$80–$9F`. The stage byte is `$80`, the timer `$81`, the build
value `$82`, the checksum `$83`, the two checksum playfield bytes `$84–$85`, the input edges
`$86–$87`, the beep `$88–$89`, the bar level `$8A`, the fifteen bar bytes `$8B–$99`, the five
stage colors `$9A–$9E`, and one scratch byte `$9F`. The stack lives at `$F8–$FF`; keep the call
depth shallow.

#### Step 2 — Reset, the build flag, and the checksum

`Reset` calls `+clean_start`, makes port A an input port, and stores the build symbol:

```asm
    LDA #DEBUG
BuildFlag:                  ; checkpoint: A = DEBUG
    STA BuildValue
```

A breakpoint at `BuildFlag` stops before the store, with `A` already holding the symbol. That is
the same pattern as `FireRead` and `ReadCX` in Lesson 46: put the label where the value is in the
accumulator, not where it is still a memory address.

The border is an assembly-time decision:

```asm
    !if DEBUG {
        LDA #C_RED
    } else {
        LDA #C_BG
    }
    STA COLUBK
```

Then `ComputeCheckSum` walks the 256-byte table once. The sum is stored in `SumByte`, and the
two playfield bytes are built from its bits:

```asm
ComputeCheckSum:
    LDA #$00
    LDX #$00
SumLoop:
    CLC
    ADC CheckData,X
    INX
    BNE SumLoop
CheckSum:                   ; checkpoint: A = the 8-bit sum
    STA SumByte
    ...
```

The bit-mapping loop shifts `Scratch` left one bit at a time. `CheckMask0` and `CheckMask1` are
eight-byte tables: each cell contributes to PF0, PF1, or neither. This is the same table-driven
idea as the RAM map in Lesson 45, applied to eight cells instead of sixty-four.

#### Step 3 — The VBLANK work

VBLANK does five things in order: the beep clock, the fire edge, the SELECT edge, the stage
clock, and the display tables. The input edges use the same `EOR`/`AND` pattern as Lesson 46:

```asm
    LDA INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA Scratch
    EOR PrevFire
    AND Scratch
    BEQ NoFireEdge
    JSR AdvanceStage
    JSR BeepStart
NoFireEdge:
    LDA Scratch
    STA PrevFire
```

`INPT4` bit 7 is 0 while fire is held, so the first `EOR` turns a press into a 1. The second
`EOR`/`AND` keeps only the 0→1 transition. SELECT is the same pattern on `SWCHB` bit 1; it
resets `Stage` to 1 and reloads the timer.

The stage clock is a countdown:

```asm
    DEC StageTimer
    BNE StageTickDone
    JSR AdvanceStage
StageTickDone:
```

`AdvanceStage` is shared by the clock and by fire:

```asm
AdvanceStage:
    LDA Stage
    CMP #STAGE_COUNT
    BCC AdvanceIncrement
    LDA #$01                ; COMMIT -> EDIT
    JMP AdvanceStore
AdvanceIncrement:
    CLC
    ADC #$01
AdvanceStore:
    STA Stage
StageStep:                  ; checkpoint: A = the new stage
    CMP #STAGE_COUNT
    BNE AdvanceNormalTimer
    LDA #STAGE_HOLD
    JMP AdvanceTimerStore
AdvanceNormalTimer:
    LDA #STAGE_PERIOD
AdvanceTimerStore:
    STA StageTimer
    RTS
```

The `CMP #STAGE_COUNT` in the reload path is what gives COMMIT its longer window: when the new
stage is 5, the timer is 60; otherwise it is 30. The state log shows the result: `StageStep`
reports 2 at frame 31, 3 at 61, 4 at 91, 5 at 121, and 1 at 181. Stage 2 is active for frames
31–60 and stage 4 for 91–120.

#### Step 4 — The status tables

Two tables are rebuilt every frame. `StageColors` holds one color per block:

```asm
    LDX #$00
StageColorLoop:
    TXA
    CLC
    ADC #$01                ; the block's 1-based number
    CMP Stage
    BEQ StageColorActive
    BCS StageColorFuture
    LDA #C_DIM_GOLD         ; i + 1 < Stage: completed
    JMP StageColorStore
StageColorActive:
    LDA #C_GREEN
    JMP StageColorStore
StageColorFuture:
    LDA #C_BG               ; i + 1 > Stage: not started
StageColorStore:
    STA StageColors,X
    INX
    CPX #STAGE_COUNT
    BNE StageColorLoop
```

The comparison is 1-based because `Stage` is 1-based. For block index 0 at stage 2, `i + 1 = 1`
is less than 2, so the block is dim gold. For index 1, `i + 1 = 2` is equal, so it is green.

`BarBuf` holds fifteen bytes, one per cell. The cell byte is `$20` when lit and `$00` when dark:

```asm
    LDX #$00
BarFill:
    CPX BarLevel
    BCS BarDark
    LDA #BAR_CHUNK
    JMP BarStore
BarDark:
    LDA #$00
BarStore:
    STA BarBuf,X
    INX
    CPX #BAR_CELLS
    BNE BarFill
```

`CPX BarLevel` sets carry when `X >= BarLevel`. A cell below the level is lit; a cell at or above
it is dark. The kernel draws cell 14 first, so the bar grows from the bottom of the zone.

#### Step 5 — The kernel: five blocks, two gaps, a bar, and a row

`BodyStart` is scanline 37, cycle 5. The five stage calls come first:

```asm
    +StageBlock 0
    +StageBlock 1
    +StageBlock 2
    +StageBlock 3
    +StageBlock 4
```

Each macro call writes the color and the three playfield bytes, waits fifteen lines, and clears
the playfield for the separator. Five blocks take 80 lines, so the CPU reaches the gap at cycle
5 of line 117.

The gap clears the playfield for eight lines. The progress bar then walks X from 14 down to 0:

```asm
    LDA #C_GOLD
    STA COLUPF
    LDX #(BAR_CELLS - 1)    ; cell 14, the top cell
BarCell:
    LDA BarBuf,X
    STA PF1
    LDA #$00
    STA PF0
    STA PF2
    LDY #BAR_LINES
BarLine:
    STA WSYNC
    DEY
    BNE BarLine
    DEX
    BPL BarCell
```

The PF1 store completes by cycle 18 (first cell) / 16 (later cells), before the playfield's
first visible slot at about 22.7.
PF0 and PF2 follow; their first visible slots are later in the line. The loop draws 15 × 6 = 90
lines. The second gap is six lines, and the checksum row holds its two bytes for eight lines.

#### Step 6 — The frame arithmetic

The zones add up:

```
80 stage + 8 gap + 90 bar + 6 gap + 8 checksum = 192 visible lines
3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262 lines
```

The first stage line is 37; the last checksum line is 228; `OverscanStart` is 229. The state log
in the next section reports exactly those numbers. The kernel has no `HMOVE` because the display
is playfield-only.

#### Step 7 — Reading it back

Re-assemble with a symbol file and ask Stella for the checkpoints:

```bash
acme -f plain -l build/demo-47.sym -o build/demo-47.bin \
  lessons/part6-game-dev/47-dev-tools-workflow/demo-47.asm

stella -audio.enabled 0 -dbg.logbreaks 1 -dbg.logtrace 0 -logtoconsole 1 \
  -break '$F1E1' docs/public/roms/part6-game-dev/47-dev-tools-workflow/demo-47.bin
```

The symbol file resolves `StageStep` to `$F1E1`, `BuildFlag` to `$F015`, and `CheckSum` to
`$F1FA`. The addresses change when the source changes, so always read the current symbol file.
`-dbg.logbreaks 1` keeps running after each break; that is what makes the `StageStep` sequence
readable. `-dbg.logtrace 0` keeps the instruction trace out of the output.

### Checkpoints

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `BuildFlag` | `$F015` | A=`$00` release; A=`$01` debug | the `DEBUG` symbol at reset |
| `StageStep` | `$F1E1` | frames 31, 61, 91, 121, 181: A=`$02`, `$03`, `$04`, `$05`, `$01` | the new stage after the store |
| `CheckSum` | `$F1FA` | frame 1, scanline 19, cycle 66: A=`$EC` | the 8-bit sum, once at reset |
| `BodyStart` | `$F0DE` | **37, cycle 5** | visible line 0 |
| `OverscanStart` | `$F1BE` | **229, cycle 4** | overscan's first line |

The exercise solutions add code, so their addresses move. In `exercise-01-solution.asm`:
`StageStep` `$F20D`, `CheckSum` `$F226`, `BodyStart` `$F0DE`, `OverscanStart` `$F1EA`. In
`exercise-02-solution.asm`: `StageStep` `$F1E1`, `CheckSum` `$F1FA`, `OverscanStart` `$F1BE`.
In `exercise-03-solution.asm`: `StageStep` `$F1E1`, `CheckSum` `$F205`, `OverscanStart`
`$F1BE`. Re-assemble with `-l` after any edit and read the symbol file.

## What You Should See

The screen is a `$02` field with five stage-band slots at the top, a gold vertical bar near the
bottom, and a row of gold checksum cells under it. In the release build the future stage bands
are `$02` and blend into the background; only the completed dim-gold bands and the active green
band are visible.

**Stage 2 (ASSEMBLE).** The first block, EDIT, is completed and dim gold. The second block,
ASSEMBLE, is active and green. The three future blocks are `$02`. The progress bar has two lit
cells at the bottom of each of its two mirrored columns, so four gold cells in total. The
checksum row shows `$EC`: cells 0, 1, 2, 4, and 5 are gold; cells 3, 6, and 7 are dark.

![Stella running the Lesson 47 ROM at stage 2: a dim-gold EDIT band, a green ASSEMBLE band, two gold cells in each of the two mirrored progress columns at TIA X=24-27 and X=132-135, and an eight-cell checksum row with five lit cells](/images/lesson47/stage2.png)

*Stage 2: EDIT is complete, ASSEMBLE is active. The bar has two of its fifteen cells lit; the
checksum row is the stable `$EC` pattern. The image is a window capture of the committed ROM;
the title bar reads `Stella 7.0: "demo-47"`.*

<RomPlayer rom="/roms/part6-game-dev/47-dev-tools-workflow/demo-47.bin" title="Lesson 47 — Development Tools & Workflow" />

Click the player screen once: Javatari starts muted until a user gesture. The ROM runs its
180-frame cycle without input, so the stage advances by itself. Press fire to advance one stage;
press SELECT to reset to EDIT. The beep marks a manual fire advance or a SELECT reset.

**Stage 4 (VERIFY).** EDIT, ASSEMBLE, and RUN are completed and dim gold. VERIFY is active and
green. COMMIT is `$02`. The progress bar now has four lit cells, two in each mirrored column.
The checksum row is unchanged:
`$EC` is a property of the table, not of the stage.

![Stella running the Lesson 47 ROM at stage 4: three dim-gold completed bands, a green VERIFY band, four gold cells across the two mirrored progress columns, and the same eight-cell checksum row](/images/lesson47/stage4.png)

*Stage 4: the first three stages are complete and VERIFY is active. The bar has four lit cells
(two per column); the checksum row still shows `$EC`. The image is a window capture of the
committed ROM; the title bar reads `Stella 7.0: "demo-47"`.*

> **Capture method.** Both images are window captures of
> `docs/public/roms/part6-game-dev/47-dev-tools-workflow/demo-47.bin` in Stella 7.0. The pointer
> was parked at (0,0) before each capture; the title bars read `Stella 7.0: "demo-47"`. Because
> the stage changes every 30 frames, a single fixed-wait capture cannot be aimed at stage 2 or
> stage 4. Stella was launched on the committed ROM, a burst of window captures was taken with
> the same `xwininfo` lookup the screenshot script uses, and the frames were selected by pixel
> analysis: stage 2 when the second band is green and two bar cells are lit, stage 4 when the
> fourth band is green and four bar cells are lit. The band counts, the bar heights, and the
> checksum runs are decoded from the captured pixels with `capture x = 25 + 6 × TIA X` and
> `capture y = 107 + 3.15 × visible line`, not copied from a log.

The debugger tells the same story as numbers:

- **`$F015` (`BuildFlag`)**: A=`$00` in the committed release build and A=`$01` in the
  `-D DEBUG=1` build. The two builds differ at two bytes; `cmp` reports byte 21 and byte 25.
- **`$F1E1` (`StageStep`)**: A=`$02` at frame 31, `$03` at 61, `$04` at 91, `$05` at 121, and
  `$01` at 181. The same sequence repeats every 180 frames. A breakpoint at `StageStep` also
  fires when fire advances the stage manually.
- **`$F1FA` (`CheckSum`)**: A=`$EC` at frame 1. The Python one-liner in the theory section
  produces `0xec`; the row draws its eight bits.
- **`$F0DE` (`BodyStart`)** is 37/5 and **`$F1BE` (`OverscanStart`)** is 229/4: the 262-line
  frame. There is no `HMOVE` checkpoint because the display is playfield-only.
- The RAM bytes to watch are `Stage` at `$80`, `StageTimer` at `$81`, `BuildValue` at `$82`,
  `SumByte` at `$83`, `CheckPF0`/`CheckPF1` at `$84–$85`, `BarLevel` at `$8A`, and `BarBuf` at
  `$8B–$99`. The stage colors are `StageColors` at `$9A–$9E`; the checksum table is in ROM at
  `CheckData` (`$F300`).

The screenshot proves the visual state; the state log proves the values. A screenshot cannot
prove that `CheckSum` is `$EC`, and a log cannot prove that the ASSEMBLE band is green. The lesson
uses both.

## Exercises

### Exercise 1: Add a TEST Stage

**Challenge:** insert a TEST stage between ASSEMBLE and RUN. The pipeline becomes EDIT,
ASSEMBLE, TEST, RUN, VERIFY, COMMIT. The ROM must show six stage blocks and a six-step progress
bar, and `StageStep` must report the new TEST stage at 3, then reach stage 5 (VERIFY) and stage 6
(COMMIT). Keep the frame at 192 visible lines and the checksum at `$EC`.

**Hints:**
1. `STAGE_COUNT = 6` and `STAGE_LINES = 13`. Six 13-line blocks are 78 lines; a two-line gap
   brings the stage zone to 80 lines. The rest of the layout is the main ROM's 90-line bar,
   six-line gap, and eight-line checksum row, plus an eight-line tail to reach 192.
2. Add one `+StageBlock 5` call. The macro already takes the index; no new block code is needed.
3. The status table already loops to `STAGE_COUNT`, so `StageColors` needs six bytes. That is
   the one RAM change: the main ROM's `Scratch` byte at `$9F` becomes the sixth stage color. Use
   `SumByte` (`$83`) as the input-edge byte after the checksum is built, and `BarLevel` (`$8A`)
   as the reset-time bit shifter.
4. `AdvanceStage` already wraps at `STAGE_COUNT` and holds the last stage for 60 frames. The
   `StageStep` sequence becomes 2, 3, 4, 5, 6, 1, …; stage 3 is the new TEST stage and
   stage 5 is VERIFY.
5. The checksum table is unchanged, so `CheckSum` still reports `$EC`; the checksum row is still
   eight cells.

**Expected Result:** Six stage blocks appear at visible 0–77, each with a one-line separator.
The progress bar counts 1–6. `StageStep` reports A=`$02` at frame 31, `$03` at 61 (TEST),
`$04` at 91 (RUN), `$05` at 121 (VERIFY), `$06` at 151 (COMMIT), and `$01` at 211. `CheckSum`
(`$F226`) reports
A=`$EC`; `BodyStart` is 37/5 and `OverscanStart` is 229/4. The solution assembles to 4,096
bytes, and so does its `-D DEBUG=1` build.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: A Conditional Build Border

**Challenge:** make the border color depend on `DEBUG`: red for the debug build, blue for the
release build. Add a `BuildFlag` cell that is visibly different between the two builds. Both
builds must assemble to exactly 4,096 bytes, and `BuildFlag` must report A=`1` in the debug
build and A=`0` in the release build.

**Hints:**
1. The border is `COLUBK`. The main ROM already has an `!if DEBUG` block; change the release
   branch from `C_BG` to `C_BLUE` (`$84`).
2. The `BuildFlag` cell is one more playfield cell in the checksum row. PF1 bit 0 (chunk 11,
   TIA X=44–47) is one of the two bits the eight data cells leave free; bit 1 (chunk 10) is the
   other, and chunk 11 keeps the cell one chunk clear of the row. OR `BuildValue` into `CheckPF1`
   after the checksum bits are built. The cell is gold when `BuildValue=1` and shows the field
   colour (blue in release, red in debug) when it is 0.
3. `BuildValue` is already stored at reset from `LDA #DEBUG`. The `BuildFlag` checkpoint is at
   the store; it reports A before the store, so it needs no other change.
4. `cmp` the two outputs. The only differences should be the `LDA #DEBUG` immediate and the
   border color immediate. Both files are 4,096 bytes.
5. Run the two builds in Stella. The release background is blue; the debug background is red.
   The BuildFlag cell shows the blue field in the release and is gold in the debug build.

**Expected Result:** The release build shows a blue field, a BuildFlag cell at TIA X=44–47
(and its mirror at X=112–115) that shows the blue field, and `BuildFlag` A=`0`. The debug build
shows a red field, a gold BuildFlag cell, and `BuildFlag` A=`1`. Both assemble to 4,096 bytes
and differ at exactly two bytes. `CheckSum` is still `$EC` in both.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: A Rotated Checksum *(Stretch Goal)*

**Challenge:** replace the plain 8-bit sum with a rotate-right-and-add checksum over `CheckData`.
The new `CheckSum` must match a Python cross-check, differ from the main ROM's `$EC`, and draw a
stable eight-cell row.

**Hints:**
1. The step is: load the running value, `LSR` it (the old bit 0 goes into carry), OR `#$80` when
   carry is set (the old bit 0 becomes bit 7), then `CLC`/`ADC` the next table byte and store the
   low eight bits.
2. Python models the same loop:
   ```python
   s = 0
   for b in data:
       s = ((s >> 1) | ((s & 1) << 7))
       s = (s + b) & 0xFF
   print(hex(s))          # 0xea
   ```
3. The `CheckSum` label stays after the loop. The accumulator still holds the last sum when the
   loop exits; a breakpoint there reports `$EA`.
4. `$EA` is `1110 1010`: cells 0, 1, 2, 4, and 6 are lit; cells 3, 5, and 7 are dark. The main
   ROM's `$EC` lights cell 5 and leaves cell 6 dark, so the two rows are visibly different.
5. Keep the table, the stage cycle, and the layout unchanged. The exercise changes only the
   checksum loop.

**Expected Result:** The solution assembles to 4,096 bytes. `CheckSum` (`$F205`) reports A=`$EA`
at reset; the Python loop prints `0xea`. The checksum row is stable with cells 0, 1, 2, 4, and 6
lit, and the rest of the dashboard behaves as in the main ROM.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **The pipeline is five stages with five artifacts**: source, `.bin`, Stella window, verify
  output, commit. The dashboard's five blocks are those stages; a stage is not finished until
  its artifact exists.
- ✅ **ACME is a build tool**: `!source` includes, `!macro` expands, `!if` selects, `!align` and
  `!fill` place data, and `!for` generates the checksum table. All of it happens before the ROM
  exists.
- ✅ **The command line is part of the source**: `-f plain` selects the raw cartridge format,
  `-o` names the output, `-l` writes the symbol file, and `-D DEBUG=1` selects the debug build.
  The two builds differ by two bytes.
- ✅ **The gate is `scripts/verify.sh`**: it re-assembles every source, compares every committed
  ROM, and builds the site. ROM drift is a failure; `npm run roms` regenerates the artifacts.
- ✅ **Git is the project's memory**: one lesson, one atomic commit, after the gate passes. The
  committed `.bin` files are generated assets; never edit them by hand.
- ✅ **The dashboard is 192 visible lines**: 80 stage + 8 gap + 90 bar + 6 gap + 8 checksum, in a
  262-line frame. `CTRLPF=$01` mirrors the playfield; the left half is the reference.
- ✅ **The checksum gives the build a reproducible number**: the 256-byte table sums to `$EC`,
  the row draws its eight bits, and the Python cross-check reproduces the value. The rotated
  exercise carries the same idea to `$EA`.

## What's Next

The dashboard is the workflow the rest of the course uses: edit, assemble, run, verify, commit.
The next lesson leaves the workflow behind and enters the machine's most demanding subject.
[Lesson 48: Introduction to Kernels — The Heart of Every 2600 Game](/part7-kernel-mastery/48-introduction-to-kernels)
explains what a kernel is, why every 2600 game needs one, and how the one-line, two-line,
multi-zone, and flicker designs differ.
