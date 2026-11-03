---
title: "Lesson 23: Data-Driven Playfield — Levels from Tables"
description: "A maze needs a different 20-bit row on every scanline. Lesson 23 stores two levels as three parallel 192-byte tables each and draws them with a one-line kernel that prefetches the next row during the line."
prev:
  text: "Lesson 22: Playfield Animation"
  link: "/part3-playfield/22-playfield-animation"
next:
  text: "Lesson 24: The Multicolor Playfield"
  link: "/part3-playfield/24-multicolor-playfield"
---

# Lesson 23: Data-Driven Playfield — Levels from Tables

> **Part 3: Playfield** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 11 (lookup tables and indexed reads), Lesson 17 (cycle counting), Lesson 19 (the playfield registers and bit order), Lesson 21 (per-line register writes), Lesson 22 (frame-level state changes)
> **You will learn:** how to store a 192-row playfield as three parallel byte tables; how a one-line kernel stores one row and prefetches the next during the same line; how three zero-page pointers switch levels in VBLANK; the 2-line-kernel trade-off
> **You will build:** "the keep" — two full mazes, each 192 rows at full vertical resolution, switching every four seconds; plus three exercises: a third level, a moved divider, and a 2-line half-height kernel

## Introduction

Every playfield so far has been the same 20 bits on every line. Lesson 21 rewrote the registers *within* a line, but the pattern still repeated down the screen. A maze is different: row 0 needs one pattern, row 1 another, and row 191 something else. That is 192 different 20-bit values — a data problem.

This lesson solves it the way the 2600 always does: store the data in ROM and read one row per line. Each level is three **parallel tables**, one byte per row for `PF0`, `PF1`, and `PF2`. The kernel keeps three zero-page pointers at the table bases, uses the same row index `Y` for all three reads, and writes the result to the playfield. A level is 3 × 192 = **576 bytes**, and switching levels is just changing the three pointers.

The kernel has one line to do all of it: store the current row, advance the index, fetch the next row, and park before the line ends. That is 52–55 of the 76 cycles (a page-crossing `(zp),Y` read adds one), leaving at least 21 for slack. The stores happen at cycles 5–22, each before its own playfield slot; the prefetch happens while the beam draws the row it just stored. This is the shape of every level-driven 2600 game: a row buffer, a pointer, and a counted prefetch.

The two levels are the same format but different geometry. Level 1 puts its divider at rows 93–95; Level 2 at rows 61–63. The ROM switches every 240 frames (~4 s), so both mazes are easy to capture and compare.

::: details TypeScript Equivalent
A level is an array of rows; the kernel is a loop with a one-row lookahead:

```typescript
type Row = { pf0: number; pf1: number; pf2: number };
const level1: Row[] = [/* 192 rows */];

let row = 0;
function drawLine(pf: { pf0: number; pf1: number; pf2: number }) {
  pf.pf0 = level1[row].pf0;   // the current row
  pf.pf1 = level1[row].pf1;
  pf.pf2 = level1[row].pf2;
  row = (row + 1) % level1.length;
}
```

The 2600 version prefetches row `row + 1` into three zero-page bytes during the current line, so the next line's stores are ready before the beam reaches the playfield.
:::

## Theory

### Section 1: A Row Is Three Bytes

The playfield registers hold 20 bits between them, split 4 / 8 / 8. A full row is therefore three bytes:

| Byte | Register | Bits used | Screen chunks |
|---|---|---|---|
| 0 | `PF0` | 4–7 | 0–3 |
| 1 | `PF1` | 7–0 | 4–11 |
| 2 | `PF2` | 0–7 | 12–19 |

The lesson stores the rows as three **parallel** tables — all the `PF0` rows, then all the `PF1` rows, then all the `PF2` rows — rather than interleaving the three bytes. Parallel tables let the kernel use one `Y` for three reads: `LDA (Ptr0),Y`, `LDA (Ptr1),Y`, `LDA (Ptr2),Y`, where `Ptr0/1/2` point at the three table bases. The cost is the same 576 bytes; the code is simpler.

The rows themselves are built from a small vocabulary:

| Name | `PF0` | `PF1` | `PF2` | What it draws |
|---|---|---|---|---|
| border | `$F0` | `$FF` | `$FF` | a solid row |
| wall/open | `$10` | `$81` | `$81` | the outer edge plus two vertical walls |
| open | `$10` | `$00` | `$00` | just the outer edge |
| chamber | `$10` | `$C3` | `$C3` | wider vertical walls |
| pillar | `$10` | `$18` | `$18` | two inner pillars per half (chunks 7–8 and 15–16), centre dark |
| divider | `$F0` | `$FF` | `$3F` | a full wall with a four-chunk doorway |

`PF2 = $3F` displays as `11111100` (bit 0 first): chunks 18–19 are off, and reflect mirrors them into 20–21, so the doorway is four chunks wide at the center.

### Section 2: The One-Line Kernel

The kernel keeps the current row in three zero-page bytes, `Tmp0/Tmp1/Tmp2`. Each line:

1. stores the three bytes to `PF0`/`PF1`/`PF2`;
2. increments `Y` and prefetches the next row into the temps;
3. parks with `WSYNC`.

The per-line ledger:

| Cycles | Instruction | Note |
|---|---|---|
| 5–10 | `LDA Tmp0` / `STA PF0` | effect 11 (clock 33), before `PF0` at 68 |
| 11–16 | `LDA Tmp1` / `STA PF1` | effect 17 (clock 51), before `PF1` at 84 |
| 17–22 | `LDA Tmp2` / `STA PF2` | effect 23 (clock 69), before `PF2` at 116 |
| 23–24 | `INY` | the next row |
| 25–32 | `LDA (Ptr0),Y` / `STA Tmp0` | prefetch `PF0` |
| 33–40 | `LDA (Ptr1),Y` / `STA Tmp1` | prefetch `PF1` |
| 41–48 | `LDA (Ptr2),Y` / `STA Tmp2` | prefetch `PF2` |
| 49–51 | `STA WSYNC` | write 51, park 52–75 |
| next 0–4 | `DEX` / `BNE` taken | body re-entered at 5 |

The 52-55-cycle body fits the 76-cycle line with at least 21 cycles to spare. The extra cycle appears when an `LDA (Ptr),Y` read crosses a page; `WSYNC` absorbs it in every case. The body's last prefetch reads index 192, one byte past each table; those bytes never reach `PF0`/`PF1`/`PF2` (the next frame's VBLANK preload overwrites the temps), so the read is harmless. The release is the same 5 cycles as the wake, and `X` is loaded before the VBLANK wait, so line 37 and line 228 share the phase.

### Section 3: Switching Levels

`FrameCounter` counts to 240 (~4 s); `Level` toggles; the VBLANK code reloads `Ptr0/Ptr1/Ptr2` from the new level's table bases and preloads row 0. The visible kernel never notices the change: the next frame simply starts reading the other table.

The pointer setup is the only level-specific code. Everything else — the kernel, the row format, the colors — is shared. A third level is a third set of tables and a third branch; the exercise adds one.

### Section 4: The Two Levels

Both levels are built from the same row vocabulary:

- **Level 1 "the keep"**: a top border (rows 0–2), wall/open blocks, a divider at rows **93–95** with a central doorway, chamber/pillar blocks below, and a bottom border (rows 186–191). Measured, the divider sits on scanlines **130–132**.
- **Level 2 "the labyrinth"**: the divider is higher, at rows **61–63** (scanlines **98–100**), followed by inner pillar rows and a side chamber; the lower half uses open/wall blocks in the opposite order, and the bottom border is three rows.

The two captures differ over 112,464 pixels — the divider position, the pillar rows, and the lower-half rhythm.

### Section 5: The 2-Line Trade-Off

A one-line kernel needs 192 rows. A two-line kernel displays each row twice and needs only **96 rows**: half the data for half the vertical detail. Classic 2600 games choose between the two constantly — 2-line kernels for tall playfields with lots of objects, 1-line kernels for detail.

The third exercise converts the kernel: after the stores and prefetch, park two scanlines instead of one. The tables can then be halved (the exercise uses the first 96 rows of the existing tables). The picture is the top half of the level at double height.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson23.bin \
  lessons/part3-playfield/23-data-driven-playfield/23-data-driven-playfield.asm
stella build/lesson23.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 23: Data-Driven Playfield — Levels from Tables — Racing the Beam
; =============================================================================
; Part 3: Playfield
;
; What this program does:
;   Draws a full maze, one playfield row per scanline, from ROM tables.
;   Two levels live in the cartridge; every ~4 seconds the program switches
;   to the other one by changing three table pointers.  The picture is 192
;   rows of 20 playfield bits, at full vertical resolution.
;
; Why tables:
;   Lessons 19-22 drew the same pattern on every line.  A maze needs a
;   different 20-bit row on each of the 192 lines.  Storing the rows in ROM
;   and reading one row per line turns the playfield into a level format:
;   three bytes per row, and a pointer decides which level is showing.
;
;   Each level is three PARALLEL tables of 192 bytes:
;
;     Level1PF0:  one PF0 byte per row  (only bits 4-7 are used)
;     Level1PF1:  one PF1 byte per row
;     Level1PF2:  one PF2 byte per row
;
;   3 x 192 = 576 bytes per level.  The kernel keeps three zero-page
;   pointers (Ptr0/Ptr1/Ptr2) at the three table bases and uses the same Y
;   (the row number) for all three reads.
;
; The one-line kernel:
;   The current row is held in Tmp0/Tmp1/Tmp2.  At the top of the line the
;   three bytes are stored to PF0/PF1/PF2; then Y advances and the NEXT
;   row is prefetched into the temps while the beam draws the current one.
;   The next line stores the prefetched row.  The stores end at cycle 22,
;   before every playfield slot; the prefetch finishes at cycle 48; WSYNC
;   parks the rest; DEX/BNE run at cycles 0-4 of the next line.
;
; The per-line ledger (body entered at cycle 5 every line):
;   LDA Tmp0 / STA PF0        6   5-10
;   LDA Tmp1 / STA PF1        6   11-16
;   LDA Tmp2 / STA PF2        6   17-22   (PF2 effect at clock 69 < 116)
;   INY                       2   23-24
;   LDA (Ptr0),Y / STA Tmp0   8   25-32
;   LDA (Ptr1),Y / STA Tmp1   8   33-40
;   LDA (Ptr2),Y / STA Tmp2   8   41-48
;   STA WSYNC                 3   49-51   (write 51, park 52-75)
;   DEX / BNE taken           5   next line 0-4; body re-entered at 5
;   ----------------------------------------------------------------
;   total                    52-55 of 76 cycles
;                            (a page-crossing (zp),Y read adds 1; WSYNC absorbs it)
;
; Level switching:
;   FrameCounter counts to 240 (~4 s); Level toggles and the VBLANK code
;   reloads Ptr0/Ptr1/Ptr2 from the new level's table bases.  Y resets to 0
;   and row 0 of the new level is preloaded before the release.  The
;   switch is invisible until the next frame; no mid-frame edits.
;
; The levels:
;   Level 1 "the keep": a full border, horizontal wall/open rows, a divider
;   at rows 93-95 with a central doorway, then chamber/pillar rows.
;   Level 2 "the labyrinth": the divider at rows 61-63, a central pillar,
;   and the open/wall blocks in the lower half.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), LevelSwitch (A = the new level, at
;   frames 240, 480, ...), VisibleStart (37), RowStore (one hit per line,
;   A = the PF2 byte just written), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson23.bin \
;        lessons/part3-playfield/23-data-driven-playfield/23-data-driven-playfield.asm
; Run:   stella build/lesson23.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines
VISIBLE_LINES  = 192
LEVEL_FRAMES   = 240    ; ~4 seconds per level

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameCounter   = $80
Level          = $81    ; 0 = Level1 tables, 1 = Level2 tables
Ptr0           = $82    ; 2 bytes each: the PF0/PF1/PF2 table bases
Ptr1           = $84
Ptr2           = $86
Tmp0           = $88    ; the current row's three bytes
Tmp1           = $89
Tmp2           = $8A

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM; Level = 0 (Level 1)

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- the level tick: switch every LEVEL_FRAMES frames ---
    INC FrameCounter
    LDA FrameCounter
    CMP #LEVEL_FRAMES
    BNE VblankSetLevel
    LDA #$00
    STA FrameCounter
    LDA Level
    EOR #$01
LevelSwitch:                ; debugger checkpoint: A = the new level (flip only)
    STA Level

; --- point the three tables at the current level ---
VblankSetLevel:
    LDA Level
    BEQ VblankLevel1
    LDA #<Level2PF0
    STA Ptr0
    LDA #>Level2PF0
    STA Ptr0+1
    LDA #<Level2PF1
    STA Ptr1
    LDA #>Level2PF1
    STA Ptr1+1
    LDA #<Level2PF2
    STA Ptr2
    LDA #>Level2PF2
    STA Ptr2+1
    JMP VblankPreload

VblankLevel1:
    LDA #<Level1PF0
    STA Ptr0
    LDA #>Level1PF0
    STA Ptr0+1
    LDA #<Level1PF1
    STA Ptr1
    LDA #>Level1PF1
    STA Ptr1+1
    LDA #<Level1PF2
    STA Ptr2
    LDA #>Level1PF2
    STA Ptr2+1

; --- preload row 0 into the row temps ---
VblankPreload:
    LDY #0
    LDA (Ptr0),Y
    STA Tmp0
    LDA (Ptr1),Y
    STA Tmp1
    LDA (Ptr2),Y
    STA Tmp2

    LDA #$C8
    STA COLUPF              ; green
    LDA #$02
    STA COLUBK              ; dark neutral
    LDA #$01
    STA CTRLPF              ; reflect: the maze is symmetric

    LDX #VISIBLE_LINES
    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — one table row per line
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
VisibleStart:               ; debugger checkpoint: the picture's first line (37)
    LDA Tmp0
    STA PF0
    LDA Tmp1
    STA PF1
    LDA Tmp2
    STA PF2
RowStore:                   ; debugger checkpoint: A = the PF2 byte
    INY                     ; the next row
    LDA (Ptr0),Y
    STA Tmp0
    LDA (Ptr1),Y
    STA Tmp1
    LDA (Ptr2),Y
    STA Tmp2
    STA WSYNC               ; park the rest of this line
    DEX
    BNE VisibleStart

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines; blank-on lands in line 229's HBLANK
; -----------------------------------------------------------------------------
OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; LEVEL 1 — "the keep": 192 rows, three parallel tables
; =============================================================================
Level1PF0:
    !byte $F0,$F0,$F0,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$F0,$F0,$F0
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$F0,$F0,$F0,$F0,$F0,$F0

Level1PF1:
    !byte $FF,$FF,$FF,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$FF,$FF,$FF
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$FF,$FF,$FF,$FF,$FF,$FF

Level1PF2:
    !byte $FF,$FF,$FF,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$3F,$3F,$3F
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$FF,$FF,$FF,$FF,$FF,$FF

; =============================================================================
; LEVEL 2 — "the labyrinth": 192 rows, three parallel tables
; =============================================================================
Level2PF0:
    !byte $F0,$F0,$F0,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$F0,$F0,$F0
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
    !byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$F0,$F0,$F0

Level2PF1:
    !byte $FF,$FF,$FF,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$FF,$FF,$FF
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$00,$00,$00,$00,$00,$00,$00,$00,$81,$81,$81,$81,$81
    !byte $81,$81,$81,$00,$00,$00,$00,$00,$00,$00,$00,$81,$81,$81,$81,$81
    !byte $81,$81,$81,$00,$00,$00,$00,$00,$00,$00,$00,$81,$81,$81,$81,$81
    !byte $81,$81,$81,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF

Level2PF2:
    !byte $FF,$FF,$FF,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$00,$00,$00,$00,$00
    !byte $00,$00,$00,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$3F,$3F,$3F
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$C3,$C3,$C3,$C3,$C3,$18,$18,$18,$18,$18,$18,$18,$18
    !byte $C3,$C3,$C3,$00,$00,$00,$00,$00,$00,$00,$00,$81,$81,$81,$81,$81
    !byte $81,$81,$81,$00,$00,$00,$00,$00,$00,$00,$00,$81,$81,$81,$81,$81
    !byte $81,$81,$81,$00,$00,$00,$00,$00,$00,$00,$00,$81,$81,$81,$81,$81
    !byte $81,$81,$81,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF

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
> `lessons/part3-playfield/23-data-driven-playfield/23-data-driven-playfield.asm`.

### Code Walkthrough

#### Step 1 — The level tick and the pointers

`FrameCounter` counts to 240; on that frame `Level` flips and the pointer setup runs. The setup is a two-way branch: Level 1 loads the three `Level1PF*` bases, Level 2 the `Level2PF*` bases. The `LevelSwitch` checkpoint sits on the `STA Level` that only executes on a flip, so the debugger reports one hit every 240 frames.

#### Step 2 — Preloading row 0

`Y` is zero; the three `LDA (Ptr),Y` reads put row 0 into `Tmp0/1/2`. This happens before `+wait_timer`, so the row is ready when the visible area starts.

#### Step 3 — The line

The body stores the row, increments `Y`, and prefetches the next row. The `RowStore` checkpoint sits just after `STA PF2`, so the debugger reports the PF2 byte of every line and its cycle (23) — 192 hits per frame.

#### Step 4 — The level switch

At frame 240 the pointers change to Level 2; the preload reads its row 0; the visible frame shows Level 2. The switch is a VBLANK event, never a mid-frame edit.

#### Step 5 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `LevelSwitch` | `$F035` | A = the new level; hits at frames **240** (A=1) and **480** (A=0) | the level flip |
| `VisibleStart` | `$F095` | 37, cycle 5 | the picture's first line |
| `RowStore` | `$F0A1` | 192 hits/frame at **cycle 23**, A = the PF2 byte | one row per line |
| `OverscanStart` | `$F0B3` | 229, cycle 4 | overscan's first line |

The divider rows are visible in the log: Level 1 has `PF2 = $3F` on scanlines **130–132**; Level 2 on scanlines **98–100**. That is the table data read back as geometry.

## What You Should See

A green maze on a dark field, filling all 192 lines. The keep has a solid border, two vertical walls, a horizontal divider with a doorway, and rows of chambers and pillars below. After four seconds the picture changes to the labyrinth: the divider jumps upward, inner pillars appear, and the lower half changes rhythm. Both levels are stable for their full four seconds.

![Stella running the Lesson 23 ROM showing level 1: a green maze with the divider low in the picture](/images/lesson23/level1.png)

*Level 1 "the keep", captured from the committed ROM: the divider with its central doorway sits at scanlines 130–132 (rows 93–95); the border and chamber rows fill the rest.*

![Stella running the Lesson 23 ROM showing level 2: the divider higher, with inner pillars below](/images/lesson23/level2.png)

*Level 2 "the labyrinth", same ROM ~4 seconds later: the divider moves to scanlines 98–100 (rows 61–63), the inner pillars appear, and the lower half changes. The two captures differ in 112,464 picture pixels; repeats of each level differ in zero.*

<RomPlayer rom="/roms/part3-playfield/23-data-driven-playfield/23-data-driven-playfield.bin" title="Lesson 23 — Data-Driven Playfield" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson23.sym -o build/lesson23.bin \
  lessons/part3-playfield/23-data-driven-playfield/23-data-driven-playfield.asm
grep -E "LevelSwitch|RowStore|VisibleStart" build/lesson23.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F0A1' \
  docs/public/roms/part3-playfield/23-data-driven-playfield/23-data-driven-playfield.bin
```

- **`$F0A1` (`RowStore`)**: 192 hits per frame, every one at cycle 23, A = the row's `PF2`. The divider rows read A = `$3F` at scanlines 130–132 (Level 1) and 98–100 (Level 2).
- **`$F035` (`LevelSwitch`)**: hits at frames 240 and 480 only, A = 1 and 0. The level changes exactly twice in the logged run.
- **`$F095` (`VisibleStart`)**: line 37 every frame; the row buffer is ready before the first visible line.

## Exercises

### Exercise 1: A Third Level

**Challenge:** add a third level table and a three-way selector.

**Hints:**
1. `Level` counts 0, 1, 2 and wraps; the level tick becomes `INC` / `CMP #3` / reset.
2. The pointer setup gains a third branch. The kernel and the row format are unchanged.
3. The third level in the solution puts the divider at rows 30–32 and opens an eight-chunk door (`PF2 = $0F`), then uses the pillar/open blocks below.

**Expected Result:** the three levels cycle every 240 frames; `LevelSwitch` fires at frames 240 (A=1), 480 (A=2), and 720 (A=0). The third level's divider is at scanlines 67–69 and its doorway is eight chunks wide. Measured: a capture at ~9 s shows the divider near the top of the picture.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Move the Divider and Widen the Door

**Challenge:** change the level geometry without touching the kernel.

**Hints:**
1. The divider is data: three rows of `$F0, $FF, $3F`. Move them to rows 45–47.
2. The doorway's width is the `PF2` value. `$3F` clears bits 6–7 (four chunks); `$0F` clears bits 4–7 (eight chunks).
3. The row-type blocks above and below the divider fill the remaining rows.

**Expected Result:** Level 1's divider moves from scanlines 130–132 to **82–84**, and the doorway doubles to eight chunks. Measured: `RowStore` reads `PF2 = $0F` at scanlines 82–84; Level 2 is unchanged and Level 1's rows around the moved divider reflow.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: A 2-Line Kernel *(Stretch Goal)*

**Challenge:** halve the vertical resolution — 96 rows, each displayed twice.

**Hints:**
1. After the stores and prefetch, park two scanlines instead of one (`STA WSYNC` twice).
2. The loop counts 96 rows instead of 192; the tables can be halved.
3. The picture is the top half of the level at double height — the classic 2-line trade-off.

**Expected Result:** 96 `RowStore` hits per frame, one every two scanlines (37, 39, 41, …); the top half of Level 1 fills the screen with each row two lines tall.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A level is a table**: 192 rows × 3 bytes = 576 bytes per level; three parallel tables keep the kernel's row index shared
- ✅ **One row per line**: the kernel stores the current row, prefetches the next, and parks — 52-55 of 76 cycles, with at least 21 to spare
- ✅ **Pointers switch levels**: three zero-page pointers and a VBLANK reload change the whole picture; the kernel never changes
- ✅ **The divider is data**: moving a wall or widening a door is a table edit, not a code edit
- ✅ **The row index is the geometry**: `RowStore`'s scanlines (130–132 vs 98–100) are the level's divider read back from the ROM
- ✅ **Resolution is a trade-off**: a 2-line kernel halves the data and the vertical detail; the choice is a design decision, not a bug
- ✅ **The phase holds**: the release's 5 cycles equal the wake, so line 37 reads row 0 exactly like line 228 reads row 191

## What's Next

The maze is one color. [Lesson 24: The Multicolor Playfield](/part3-playfield/24-multicolor-playfield) changes `COLUPF` on every scanline: a 192-byte color table turns the same kind of row data into 16 hue bands, then into a cool/warm region scheme. The playfield's shape and its color become two independent layers — the last piece of Part 3's canvas.
