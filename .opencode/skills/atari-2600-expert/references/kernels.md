# Kernels — Reference

A **kernel** is the code that draws the picture, scanline by scanline. Everything about 2600
programming that feels strange comes from this: the CPU and the beam must stay in lockstep.

## The mental model

- The visible area is **192 scanlines** (NTSC). The kernel visits every one of them, every
  frame (~60 Hz), in real time.
- Vertical position comes from **when** you write: writing `GRP0` on line 100 makes the sprite
  appear on line 100.
- Horizontal position comes from **where** you strobed `RESxx` and the fine motion value.
- The per-line budget is **76 CPU cycles**. Blow it and the frame stretches (rolls).

Software reads the beam; the beam never waits for software (except `WSYNC`).

## Kernel archetypes

| Archetype | What it does | When to use |
| --- | --- | --- |
| **2-line kernel** | Each data byte covers 2 scanlines; loop does `LDA/STA` + 2×`WSYNC` | Default choice: 96 bytes cover the screen, easy cycle budget |
| **1-line kernel** | One scanline per byte; 192 bytes of data | Max vertical detail; tight but doable for a few objects |
| **Flicker (30 Hz)** | Two halves of the picture alternate each frame | More sprites than the TIA provides |
| **Multi-zone kernel** | Fixed screen regions (status bar, play area, score) each drawn by their own loop | Almost every real game |
| **Repositioning kernel** | `RESxx` + `HMOVE` called mid-frame to place the same object at several Y/X spots | Rows of enemies, stacked objects |
| **Playfield writer** | Sets `PF0/PF1/PF2` once per line (or mid-line for asymmetry) | Walls, terrain, text |

## The frame skeleton (as used in this course)

```asm
Reset:
    +clean_start            ; zero TIA + RAM, set stack

StartFrame:
    +vsync                  ; 3 lines
    LDA #$02 : STA VBLANK   ; blank
    +set_timer 44           ; VBLANK = 37 lines (44 ticks)
    ; --- game logic (read inputs, move objects, collisions) ---
    +wait_timer             ; wait out the timer
    LDA #$00 : STA VBLANK   ; picture on

    ; --- kernel: draw 192 lines ---
    LDX #192
.kernel
    STA WSYNC
    ; ... writes for this line ...
    DEX
    BNE .kernel

    LDA #$02 : STA VBLANK   ; blank
    +set_timer 36           ; overscan = 30 lines (36 ticks)
    +wait_timer
    JMP StartFrame
```

This is exactly `src/main.asm`, which every lesson builds on.

## The 2-line kernel pattern

Because 192 lines divide evenly by 2, the most common kernel reads one byte every two lines:

```asm
    LDY #95                 ; 96 rows: 96 x 2 lines = 192
.kernel
    LDA (sprite),Y          ; fetch this row's byte     5 cycles
    STA GRP0                ; draw it                   3
    STA WSYNC               ; rest of line 1            3
    STA WSYNC               ; line 2                    3
    DEY                     ;                           2
    BNE .kernel             ;                           3 (2 + 1 taken)
    ; total ≈ 19 cycles per 2 lines — comfortably inside budget
```

The trade-off: 2-line kernels cannot show a one-scanline difference; shapes look chunky
vertically. That is normal for the platform and part of its look.

## The 1-line kernel pattern

```asm
    LDX #191
.kernel
    LDA data,X              ; 4 (if no page cross)
    STA GRP0                ; 3
    STA WSYNC               ; 3
    DEX                     ; 2
    BNE .kernel             ; 3
    ; ≈ 15 cycles — still inside 76, but the *next* object eats the budget fast
```

Add a second object (`STA GRP1`, `STA COLUP0`, playfield writes) and the numbers climb:
a full line can hold perhaps six to eight register writes plus the loop overhead.

## Multi-zone kernels

Structure the picture as bands, each with its own loop:

```
zone 1 (status bar)  — set COLUBK/COLUPF, CLR a playfield row pattern, 20 lines
zone 2 (play area)   — the real kernel: sprites, playfield, 152 lines
zone 3 (score)       — PF multi-color score trick or sprites, 20 lines
```

Each zone sets its colors and object states at the zone boundary, usually right after a
`WSYNC` so the change lands exactly on a new line.

## Repositioning: many objects from few

The TIA has one player per side — but you can reuse it. Place one object, draw its lines,
reposition it (the `SetHorizPos` dance costs about 2 lines), then draw the next object lower
on the screen. Classic examples: rows of invaders, logs in a river, a status bar plus a
sprite below it. The cost is the ~2 reposition lines per object.

## Asymmetric playfield

The playfield is 20 bits for the left half; the right half repeats or reflects it. To draw a
*different* right half, rewrite `PF0/PF1/PF2` **during the scanline** after the left half has
been consumed and before the beam reaches the right half. Typical timing on a 76-cycle line:

```
STA WSYNC          ; fresh line
; immediately: write PF0, PF1, PF2 for the LEFT half
; then burn ~20 cycles (NOPs or the game's per-line logic)
; then write PF2, PF1, PF0 in reverse order for the RIGHT half
```

In reflect mode, the right half is drawn in reversed register order (`PF2` first, then `PF1`,
`PF0`). This is how scoreboards, mazes, and text screens work.

## Flicker

When the picture needs more objects than the TIA has, alternate two frames at 30 Hz:

```
frame A: player 0 = object 1, player 1 = object 3
frame B: player 0 = object 2, player 1 = object 4
```

The eye merges them into "four" objects. `VDELP0/1` (vertical delay) helps: with delay
enabled, a write to `GRPx` is held until the *next* write to the other player register,
letting you update graphics between draws without tearing.

## Cycle-counting discipline

- **Unroll** straight-line kernel code so costs are visible line by line; loop only where
  the branch overhead is acceptable.
- Remember the **taken-branch +1** and **page-cross +1** penalties.
- `STA WSYNC` costs 3 cycles; the CPU then waits — writes after `WSYNC` on the same line cost
  their normal cycles from the start of the line.
- If the picture rolls slowly, the kernel is over budget by exactly the cycles you are missing
  per line; measure with the Stella debugger's scanline/cycle display.

## Sources

See `sources.md`: "How to Draw a Playfield" (Nick Bensema), Andrew Davie's newbies sessions,
8bitworkshop's VCS section, and the course's own lessons.
