---
title: "Lesson 18: Mid-Scanline Changes — Racing the Beam"
description: "The beam is a position encoder: a COLUBK write at cycle N paints its boundary at color clock 3N. Part 2 closes with four hand-placed vertical columns, a two-state width animation that shifts every boundary +4 cycles, and the odd-cycle tuner that makes hit 63 reachable."
prev:
  text: "Lesson 17: Cycle Counting"
  link: "/part2-tv-and-tia/17-cycle-counting"
next:
  text: "Lesson 19: Playfield Basics"
  link: "/part3-playfield/19-playfield-basics"
---

# Lesson 18: Mid-Scanline Changes — Racing the Beam

> **Part 2: TV & TIA** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 12 (the counted frame), Lesson 13 (the color byte), Lesson 14 (WSYNC and the HBLANK budget), Lesson 15 (the exact 44/36 timer windows), Lesson 17 (cycle counting — the write-position rule this lesson uses as a drawing tool)
> **You will learn:** the beam as a position encoder (a write at hit cycle N paints from color clock 3N); `WSYNC` as a per-line anchor and why a counted ring needs it; the odd-cycle tuner (`BIT`) for boundaries that NOPs cannot reach; a two-state animation built from one gap; and the last link in Part 2's timing chain
> **You will build:** "color columns" — four vertical color columns (`$42`, `$84`, `$C8`, `$1A`) placed by write cycle at the visible quarter points, with a +4-cycle shift of all three boundaries every ~2 seconds (the widths animate); plus three exercises: move one boundary, add a fifth column, and march the boundaries one cycle per frame

## Introduction

Part 2 has built the whole machine around whole lines: the frame (Lesson 12), the colors (13), the sync discipline (14), the timer windows (15), stacked zones (16), and the cycle budget (17). Every tool so far moved the picture *between* lines. This lesson steps inside one.

Lesson 17 established the rule: **a store to the TIA takes effect from color clock 3 × N, where N is the cycle number of the instruction after the store** — the number the debugger prints at a checkpoint. Twelve measured hue boundaries confirmed it, and it explained why an over-budget loop drifts. Now turn the rule around. If a `COLUBK` write at cycle 36 paints from color clock 108, then a write cycle *is* a horizontal position — 108 clocks into the line, 40 clocks from the visible left edge, 240 capture pixels. Write at 36, 49 and 63, and the line carries four columns.

No sprites, no playfield, no collision registers. Four store-and-wait sequences and one anchor per line. This is deterministic timing as a graphics tool — the technique every later sprite lesson will lean on.

::: details TypeScript Equivalent
A write cycle is an x-coordinate. The whole kernel is a list of positions with an assertion that they are reachable:

```typescript
const VISIBLE_START = 68;                   // color clocks before the picture begins
const clockOf = (hitCycle: number) => hitCycle * 3;   // where a store takes effect

const columns = [
  { color: "$42", hit: 13 },   // HBLANK: the line starts in this color
  { color: "$84", hit: 36 },   // clock 108 — the first quarter point
  { color: "$C8", hit: 49 },   // clock 147
  { color: "$1A", hit: 63 },   // clock 189
];
console.assert(clockOf(36) === 108 && clockOf(63) === 189);

// The animation: the three boundaries +4 cycles each = +12 clocks.
// The base stays in HBLANK — unshifted, as in the ROM.
const shifted = columns.map((c, i) => (i === 0 ? c : { ...c, hit: c.hit + 4 }));
console.assert(clockOf(shifted[1].hit) === 120);   // was 108
```

In a web app, a layout is measured in pixels and applied to every element at once. Here the "layout pass" runs once per scanline: 76 cycles, four stores, and the beam does the drawing.
:::

## Theory

### Section 1: The Beam as a Position Encoder

The numbers are the same ones Part 2 has used since Lesson 12, now read as a coordinate system:

- A scanline is **228 color clocks**; the CPU sees **76 cycles**; HBLANK covers the first **68 clocks** (≈ 22⅔ cycles); the visible picture is the remaining **160 clocks**.
- A store's write appears **from color clock 3 × N**, N = the cycle of the instruction *after* the store. (Lesson 17's measurement — the same rule puts the ruler's notches where the capture shows them.)
- A write at **N ≤ 22** lands inside HBLANK: the whole visible line — left edge included — takes the new color. Later writes split the line.
- Every reachable boundary clock is a **multiple of 3** — write cycles are integers and each maps to three clocks.

The visible quarter points sit at clocks 108 / 148 / 188. The multiples of three next to them are 108, 147 and 189 — so the boundary writes land at hit cycles 36, 49 and 63, and the ledger below owns every cycle in between:

| write | color | hit cycle | boundary clock | capture x |
|---|---|---|---|---|
| base | `$42` | **13** | 39 (< 68 — HBLANK: whole line from the left edge) | — |
| boundary 1 | `$84` | **36** | 108 | **265** |
| boundary 2 | `$C8` | **49** | 147 | **499** |
| boundary 3 | `$1A` | **63** | 189 | **751** |

(The capture x follows from the mapping used since Lesson 12: `x = 25 + (clock − 68) × 6`, six screen pixels per color clock.)

### Section 2: The Anchor and the Ring

Lesson 17's loops deliberately let go of `WSYNC` — the count *was* the alignment, and a drifting ruler was the point. Here drift would be a defect: three clocks of slip per line would make every boundary edge wander diagonally down the screen. The columns need the anchor back:

```asm
VarDefaultBody:             ; entered at cycle 5 — after the wake's DEX (0-1) + taken BNE (2-4)
    LDA #COL1               ; 5-6     base color
    BIT FrameCounter        ; 7-9     the odd-cycle tuner (Section 3)
    STA COLUBK              ; 10-12
    NOP x 9                 ; 13-30
    LDA #COL2 / STA COLUBK  ; 31-35   boundary 1: hit 36
    NOP x 4 / LDA #COL3 / STA COLUBK          ; boundary 2: hit 49
    NOP x 3 + BIT / LDA #COL4 / STA COLUBK    ; boundary 3: hit 63
    STA WSYNC               ; 63-65   the anchor: write 65, park 66-75
VarDefaultNext:
    DEX / BNE VarDefaultBody ; 5 cycles at the next line's wake
```

Each line is a **ring**: the anchor parks the CPU through the end of the line; the wake's `DEX`/`BNE` (5 cycles) replay the body at the same offsets. From the wake to the anchor's write: **66 cycles** (default state); `WSYNC` owns the remaining 10. The shifted state works one gap harder (Section 4) and its work ends at the write on cycle 69, leaving 6.

The entry — line 37 — is worth one paragraph, because a first line that lands a cycle off would show as a one-line notch at the top of every column. The release (`LDA #$00` + `STA VBLANK`) costs exactly 5 cycles, the same as the steady-state `DEX` + taken `BNE`. The kernel is entered by *falling through* the release, so line 37's writes land on the same cycle grid as lines 38–228. The evidence is the first checkpoint, `DefaultBase`, at **(37, cycle 13)** — the steady-state number, on the very first line.

### Section 3: The Odd-Cycle Tuner

NOPs cost 2 cycles each, so a NOP-filled gap can only shift a boundary by an even amount. The quarter-point hits 36 / 49 / **63** need odd steps somewhere: 36 → 49 is a hit difference of 13 (an 8-cycle NOP gap plus the 5-cycle load/store), and 49 → 63 is 14 (a 9-cycle gap plus 5). Nine is odd — it cannot be built from NOPs. An odd number of cycles needs an odd instruction: the cheapest official one that does nothing is **`BIT`** — 3 cycles, one read, no writes, A untouched.

So the kernel uses `BIT FrameCounter` twice: once in the base sequence and once as the last 3 cycles before boundary 3's load. The odd cycle has to be paid somewhere before boundary 1 — this ROM pays it in the base sequence (hit 13 rather than 10), which sets the parity for everything downstream; move it into the first gap instead and the geometry is identical. The 49 → 63 gap, though, is odd by construction and always needs a tuner. With NOP-only pads the quarter-point hits are simply unreachable — without a `BIT` anywhere, boundary 1 would be permanently odd. The tuner reads a live byte (`FrameCounter`, the animation counter) and changes nothing — a ledger device, not logic.

| segment | cycles | running | hit |
|---|---|---|---|
| `DEX`, `BNE` (taken) | 2 + 3 = 5 | 0-4 | |
| `LDA #COL1`, `BIT`, `STA COLUBK` | 2 + 3 + 3 = 8 | 5-12 | **13** (base) |
| `NOP` × 9 | 18 | 13-30 | |
| `LDA #COL2`, `STA COLUBK` | 5 | 31-35 | **36** |
| `NOP` × 4 | 8 | 36-43 | |
| `LDA #COL3`, `STA COLUBK` | 5 | 44-48 | **49** |
| `NOP` × 3, `BIT` | 9 | 49-57 | |
| `LDA #COL4`, `STA COLUBK` | 5 | 58-62 | **63** |
| `STA WSYNC` | 3 | 63-65 | write 65 (park 66-75) |

### Section 4: The Shift — One Gap, All Boundaries

The animation shifts the three boundary writes by **+4 cycles each**. Since the writes execute in sequence, moving *all* of them four cycles later takes only one change: grow the first gap by 4 (nine NOPs become eleven). Boundaries 2 and 3 inherit the shift; nothing else moves. The base stays in HBLANK; the anchor slides from writing on cycle 65 to cycle 69; the line still parks for its remaining cycles. One gap, three moving boundaries, one frame that never changes length:

| | hit cycles | boundary clocks | widths (clocks) | widths (capture px) |
|---|---|---|---|---|
| default | 36 / 49 / 63 | 108 / 147 / 189 | 40 / 39 / 42 / 39 | 240 / 234 / 252 / 234 |
| shifted | 40 / 53 / 67 | 120 / 159 / 201 | 52 / 39 / 42 / 27 | 312 / 234 / 252 / 162 |

The first column grows by 12 clocks (72 pixels), the middle two hold exactly, the last shrinks by 12. The flip runs on a **120-frame counter** (≈ 2 seconds at 59.94 Hz): `INC FrameCounter` / `CMP #120`, then `LDA AnimState` / `EOR #$01` / `STA AnimState`, all inside VBLANK, where the frame's 37 blanked lines leave thousands of cycles free. Measured: default frames 1-119, shifted 120-239, default again 240-359 — the two screenshots in this lesson are those two states.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson18.bin \
  lessons/part2-tv-and-tia/18-mid-scanline-changes/18-mid-scanline-changes.asm
stella build/lesson18.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 18: Mid-Scanline Changes — Racing the Beam
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   "Color columns": every one of the 192 visible lines paints four vertical
;   color columns — $42 (red), $84 (blue), $C8 (green), $1A (gold) — by
;   writing COLUBK four times per line at hand-placed cycles.  The beam
;   crosses one line in 228 color clocks (76 CPU cycles): a store whose next
;   instruction runs at cycle N paints from color clock 3N onward.  The
;   ledger below places the three boundaries at the visible quarter points.
;
;   Every ~2 seconds the three boundary writes shift +4 cycles each, so the
;   widths animate: the first column grows, the last shrinks, the middle two
;   hold.  Nothing else on screen moves.
;
;     - VSYNC: 3 lines, counted with WSYNC.
;     - VBLANK: TIM64T = 44 (exactly 37 lines), the INTIM poll, and the
;       animation tick (a 120-frame counter flips the state).
;     - Visible: one exact 76-cycle line, repeated 192 times.  Each line is
;       an anchor WSYNC plus four writes; no drifting, no waiting between
;       the writes — the count is the geometry.
;     - Overscan: TIM64T = 36 (exactly 30 lines).
;
; The per-line ledger (default state — exactly 76 cycles):
;   DEX                      2    0-1   line counter (192 lines)
;   BNE VarDefaultBody       3    2-4   taken
;   LDA #COL1                2    5-6
;   BIT FrameCounter         3    7-9   the 3-cycle odd-gap tuner
;   STA COLUBK               3   10-12  base color: hit 13 -> clock 39 (HBLANK)
;   NOP x 9                 18   13-30
;   LDA #COL2                2   31-32
;   STA COLUBK               3   33-35  boundary 1: hit 36 -> clock 108
;   NOP x 4                  8   36-43
;   LDA #COL3                2   44-45
;   STA COLUBK               3   46-48  boundary 2: hit 49 -> clock 147
;   NOP x 3 + BIT            9   49-57  (6 + 3: the odd tuner again)
;   LDA #COL4                2   58-59
;   STA COLUBK               3   60-62  boundary 3: hit 63 -> clock 189
;   STA WSYNC                3   63-65  the anchor: write 65, park 66-75
;   ----------------------------------------------------------------
;   total                   76
;
;   The shifted state is the same ring with NOP x 11 in the first gap
;   instead of NOP x 9: every write after the base lands 4 cycles later —
;   hits 40 / 53 / 67, boundaries at clocks 120 / 159 / 201 — and the
;   anchor is written at cycle 69.  The line is still exactly 76 cycles.
;
;   Why "hit cycles"?  A store takes effect from the color clock three times
;   the cycle number of the NEXT instruction — the number the debugger
;   prints and the ledger counts.  Lesson 17 verified this rule against
;   twelve measured boundaries; the same math places these columns:
;   boundary x (in the capture) = 25 + (3 x hit - 68) x 6.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259 — a standard 262-line frame), VblankStart (0),
;   VblankPoll (A = the INTIM value just read; zero at line 36),
;   VisibleStart (the release; logged (36, 46) at the anchor's first parked
;   cycle, executing from (37, 0) — its phase equals the loop's steady
;   state, so line 37 carries the columns too), the per-write ticks
;   DefaultBase/DefaultB1/DefaultB2/DefaultB3 at cycles 13/36/49/63 (192
;   hits per frame each while the default state is showing) and
;   ShiftBase/ShiftB1/ShiftB2/ShiftB3 at 13/40/53/67 (the shifted state;
;   A = the color just written), OverscanStart (229), OverscanPoll (A =
;   the INTIM value just read).
;
; Build: acme -f plain -o build/lesson18.bin \
;        lessons/part2-tv-and-tia/18-mid-scanline-changes/18-mid-scanline-changes.asm
; Run:   stella build/lesson18.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame, the columns, the animation
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (Lesson 15)
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (Lesson 15)

COL1           = $42    ; the lesson-12 palette, left to right
COL2           = $84
COL3           = $C8
COL4           = $1A

VISIBLE_LINES  = 192    ; the standard NTSC picture height
ANIM_FRAMES    = 120    ; ~2 seconds per animation state at ~60 Hz

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
FrameCounter   = $80    ; counts up to ANIM_FRAMES, then resets
AnimState      = $81    ; 0 = default widths, 1 = shifted widths

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

; =============================================================================
; MAIN LOOP  —  one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines (Lesson 12)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = start VSYNC
    STA VSYNC
    STA WSYNC               ; VSYNC line 1
    STA WSYNC               ; VSYNC line 2
    STA WSYNC               ; VSYNC line 3
    LDA #$00
    STA VSYNC               ; pulse off — exactly 3 lines

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 lines, counted by the RIOT timer (TIM64T = 44)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDA #VBLANK_TIMER
    STA TIM64T              ; start the countdown: 44 ticks for 37 lines

; --- the animation tick: flip the state every ANIM_FRAMES frames ---
    INC FrameCounter        ; 5 cycles — one frame's worth of time
    LDA FrameCounter
    CMP #ANIM_FRAMES        ; 120 frames elapsed?
    BNE VblankTickDone
    LDA #$00
    STA FrameCounter        ; wrap the counter
    LDA AnimState
    EOR #$01
    STA AnimState           ; 0 <-> 1: the widths will shift this frame
VblankTickDone:

VblankWait:
    LDA INTIM               ; how much blanking is left?
VblankPoll:                 ; debugger checkpoint: A = the value just read
    BNE VblankWait          ; keep polling until it reads 0 (line 36)

; -----------------------------------------------------------------------------
; STATE SELECT — pick the kernel for this frame's 192 lines
; -----------------------------------------------------------------------------
    LDA AnimState
    BNE VbShifted           ; 1 = the shifted widths

; -----------------------------------------------------------------------------
; VISIBLE — DEFAULT STATE: boundaries at clocks 108 / 147 / 189
; -----------------------------------------------------------------------------
    LDX #VISIBLE_LINES      ; 192 lines to paint
    STA WSYNC               ; park the rest of line 36
VisibleStart:               ; debugger checkpoint: the picture's first line (Stella: 37, 0)
    LDA #$00
    STA VBLANK              ; release the beam (cycles 0-4)
VarDefaultBody:             ; the release + these 5 cycles = the steady-state top, so
                            ; line 37 lands on the same cycle grid as every other line
    LDA #COL1               ; 5-6    base color
    BIT FrameCounter        ; 7-9    the 3-cycle odd-gap tuner (reads, changes nothing)
    STA COLUBK              ; 10-12
DefaultBase:                ; checkpoint: hit cycle 13  -> paints from clock 39
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2      (18 cycles to the next write)
    LDA #COL2               ; 31-32
    STA COLUBK              ; 33-35
DefaultB1:                  ; checkpoint: hit cycle 36  -> boundary 1 at clock 108
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2      (8 cycles)
    LDA #COL3               ; 44-45
    STA COLUBK              ; 46-48
DefaultB2:                  ; checkpoint: hit cycle 49  -> boundary 2 at clock 147
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2      (6 cycles)
    BIT FrameCounter        ; 3      (the odd tuner: 6 + 3 = 9)
    LDA #COL4               ; 58-59
    STA COLUBK              ; 60-62
DefaultB3:                  ; checkpoint: hit cycle 63  -> boundary 3 at clock 189
    STA WSYNC               ; 63-65  anchor: write 65, park 66-75
VarDefaultNext:
    DEX                     ; 2      next line
    BNE VarDefaultBody      ; 3 taken
    JMP OverscanStart       ; 192 lines done

; -----------------------------------------------------------------------------
; VISIBLE — SHIFTED STATE: boundaries at clocks 120 / 159 / 201
; -----------------------------------------------------------------------------
VbShifted:
    LDX #VISIBLE_LINES      ; 192 lines to paint
    STA WSYNC               ; park the rest of line 36
    LDA #$00
    STA VBLANK              ; release the beam — same 5-cycle phase
VarShiftBody:
    LDA #COL1               ; 5-6    base color (unchanged)
    BIT FrameCounter        ; 7-9
    STA COLUBK              ; 10-12
ShiftBase:                  ; checkpoint: hit cycle 13  -> paints from clock 39
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2      (22 cycles now — two more than the default: the shift)
    LDA #COL2               ; 35-36
    STA COLUBK              ; 37-39
ShiftB1:                    ; checkpoint: hit cycle 40  -> boundary 1 at clock 120
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2      (8 cycles)
    LDA #COL3               ; 48-49
    STA COLUBK              ; 50-52
ShiftB2:                    ; checkpoint: hit cycle 53  -> boundary 2 at clock 159
    NOP                     ; 2
    NOP                     ; 2
    NOP                     ; 2      (6 cycles)
    BIT FrameCounter        ; 3
    LDA #COL4               ; 62-63
    STA COLUBK              ; 64-66
ShiftB3:                    ; checkpoint: hit cycle 67  -> boundary 3 at clock 201
    STA WSYNC               ; 67-69  anchor: write 69, park 70-75
VarShiftNext:
    DEX                     ; 2
    BNE VarShiftBody        ; 3 taken
                            ; fall through when the 192 lines are done

OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines, counted by the RIOT timer (TIM64T = 36)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDA #OVERSCAN_TIMER
    STA TIM64T              ; start the countdown: 36 ticks for 30 lines

OverscanWait:
    LDA INTIM               ; how much blanking is left?
OverscanPoll:               ; debugger checkpoint: A = the value just read
    BNE OverscanWait        ; keep polling until it reads 0
    STA WSYNC               ; line up with the beam for VSYNC's first line
    JMP StartFrame          ; the frame is done: next one

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
> `lessons/part2-tv-and-tia/18-mid-scanline-changes/18-mid-scanline-changes.asm`.

### Code Walkthrough

#### Step 1 — The frame, the tick, the state

Everything before the visible section is the course skeleton: three `WSYNC`-counted VSYNC lines, VBLANK on with `TIM64T` = 44 (exactly 37 lines), then the `INTIM` poll. Between the timer start and the poll sits the animation tick — five instructions that flip `AnimState` every 120th frame. Nothing about the frame moves: measured, `StartFrame` fires at scanline **259** every frame — a standard 262-line picture; Lesson 17's stretch is gone, because this ROM's extra work lives inside VBLANK, where there is room for it.

#### Step 2 — The state select and the release

After the poll reads zero (measured at line 36, cycle 34), a small branch picks the kernel:

```asm
    LDA AnimState
    BNE VbShifted           ; 1 = the shifted widths
    LDX #VISIBLE_LINES      ; 192 lines to paint
    STA WSYNC               ; park the rest of line 36
VisibleStart:
    LDA #$00
    STA VBLANK              ; release the beam — falling into the ring below
```

Two kernels exist rather than one with a conditional — a per-line branch would cost 2 or 3 cycles depending on which way it went, and that one-cycle difference would drag every write after it. The frame picks its kernel once; each line inside the kernel runs branch-free (except the ring's own counted `BNE`).

#### Step 3 — The default ring, line by line

`VarDefaultBody` through `VarDefaultNext` is Section 2's ring with Section 3's ledger. The four writes land at hit cycles 13 / 36 / 49 / 63 — the base in HBLANK, the three boundaries at clocks 108 / 147 / 189. The running cycle totals are in the source comments, column-aligned, so the whole ledger is readable top to bottom.

#### Step 4 — The shifted ring

`VarShiftBody` is the same ring with `NOP` × 11 in the first gap: hits 13 / 40 / 53 / 67, boundaries at 120 / 159 / 201, anchor write on cycle 69. Everything else — the base, the two `BIT` tuners, the second and third gaps — is byte-for-byte the default ring.

#### Step 5 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **259, cycle 3** — the frame is 262 lines | VSYNC's first line |
| `VblankPoll` | `$F03A` | A = the INTIM just read — 43 first, then 0 at (36, 34) | the VBLANK poll |
| `VisibleStart` | `$F044` | logged at (36, 46) — the anchor's first parked cycle: the debugger matches the release's address while the CPU is already halted; it executes from (37, 0) | the release |
| `DefaultBase` | `$F04E` | (37, **cycle 13**), pixel −29, A = `$42`; 192 hits/frame while default | base tick |
| `DefaultB1` | `$F05B` | (37, **36**), pixel 40, A = `$84` | boundary 1 |
| `DefaultB2` | `$F063` | (37, **49**), pixel 79, A = `$C8` | boundary 2 |
| `DefaultB3` | `$F06C` | (37, **63**), pixel 121, A = `$1A` | boundary 3 |
| `ShiftBase` / `ShiftB1` / `ShiftB2` / `ShiftB3` | `$F082` / `$F091` / `$F099` / `$F0A2` | first hit at **frame 120**; (37, 13 / **40 / 53 / 67**), pixels −29 / 52 / 91 / 133 | the shifted ticks — the flip |
| `OverscanStart` | `$F0A7` | (229, cycle 7), A = `$1A`, X = 0 | overscan's first line |
| `OverscanPoll` | `$F0B3` | A = the INTIM just read — 35 first, then 0 at (258, 58) | the overscan poll |

The log's pixel column is `3 × hit − 68`: the boundary's offset in color clocks after the visible start. Boundary 1 reads 40 → capture x = 25 + 40 × 6 = **265**. Every value in the table above was produced by one breakpoint run per line.

## What You Should See

Four rock-steady vertical columns spanning all 192 visible lines: dark red `$42` from the left edge to about a quarter of the way in, then blue `$84`, green `$C8`, and gold `$1A` to the right edge. Then, every two seconds, the columns shift: the red column widens by about a thirteenth of the screen (+12 color clocks), the gold narrows by the same, the blue and green centers hold.

![Stella running the Lesson 18 ROM in the default state: four vertical columns — red, blue, green, gold — with boundaries at the quarter points](/images/lesson18/columns.png)

*Default state, captured from the ROM: boundaries at x = 265 / 499 / 751 (clocks 108 / 147 / 189) — column widths 240 / 234 / 252 / 234 pixels = 40 / 39 / 42 / 39 clocks, spanning rows 107-711 (all 192 lines).*

![Stella running the Lesson 18 ROM in the shifted state: the red column is wider, the gold narrower, the boundaries +72 pixels right](/images/lesson18/columns-shifted.png)

*Shifted state, same ROM ~2 seconds later: boundaries at x = 337 / 571 / 823 (clocks 120 / 159 / 201) — widths 312 / 234 / 252 / 162. Every visible boundary moved exactly +72 pixels; the two screenshots differ in 130,680 pixels and repeat captures of either state differ in zero.*

<RomPlayer rom="/roms/part2-tv-and-tia/18-mid-scanline-changes/18-mid-scanline-changes.bin" title="Lesson 18 — Mid-Scanline Changes" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson18.sym -o build/lesson18.bin \
  lessons/part2-tv-and-tia/18-mid-scanline-changes/18-mid-scanline-changes.asm
grep -E "DefaultB|ShiftB|StartFrame" build/lesson18.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F05B' \
  docs/public/roms/part2-tv-and-tia/18-mid-scanline-changes/18-mid-scanline-changes.bin
```

- **`$F04E` (`DefaultBase`)**: 192 hits per frame, first at (37, cycle 13) — the same cycle on every line, first line included. A single unique hit cycle per frame is what "the ring holds" looks like as data.
- **`$F05B` / `$F063` / `$F06C` (`DefaultB1/B2/B3`)**: one hit per line at cycles 36 / 49 / 63. Leave the run going: the hits stop at frame 119 and resume at frame 240 — the shifted state is showing.
- **`$F091` (`ShiftB1`)**: nothing until **frame 120** (≈ 2 s in), then 192 hits per frame at cycle 40. Toggling the state in VBLANK is visible in the log as clean switches, never mid-frame.
- **`$F0A7` (`OverscanStart`)**: line 229, cycle 7 — the 192nd line's ring ends and the overscan blank starts before any visible pixel of line 229.

## Exercises

### Exercise 1: Move One Boundary

**Challenge:** move boundary 2 later by four cycles — without moving boundaries 1 and 3.

**Hints:**
1. Boundary 2's position is set by the NOP gap between boundary 1's write and its own load. Two more NOPs (8 → 12 cycles) move it from hit 49 to hit 53.
2. Everything *after* the changed gap inherits the shift — including boundary 3 unless you take the same four cycles back out. The next gap is 9 cycles (NOP × 3 + `BIT`); make it 5 (`NOP` + `BIT`) and boundary 3 stays at hit 63.
3. The anchor and the line budget are untouched: 66 cycles of work, same park.

**Expected Result:** boundary 2 at hit 53 → clock 159 → capture x = 571; widths 40 / 51 / 30 / 39 clocks. Measured: `B2Tick` at (37, 53), boundary 1 and 3 unmoved at 265 and 751, boundary 2 at exactly 571.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: A Fifth Column

**Challenge:** add a fifth column — a new boundary write with a new color.

**Hints:**
1. A fifth column needs one more write: five colors, four internal boundaries. The budget is tight but kind: the last write can sit at hit 62 and the anchor still fits (`STA WSYNC` on cycles 62-64).
2. This solution inserts a bright white stripe (`$0E`, lesson 13's top-luminance grey) between the blue and the green: the boundary-2 write becomes the stripe's `$0E` at hit 41 (no gap — it follows the blue's write immediately), and a new write paints `$C8` at hit 48.
3. Gaps: 18 / 0 / 2 / 9 cycles before the four boundary writes; parity stays odd-friendly with one `BIT` in the last gap.

**Expected Result:** five columns — `$42` / `$84` / `$0E` / `$C8` / `$1A` — at boundaries 108 / 123 / 144 / 186, widths 40 / 15 / 21 / 42 / 42 clocks. Measured: ticks at (37, 13 / 36 / 41 / 48 / 62); capture transitions at x = 265 / 355 / 481 / 733 with the white stripe reading rgb(234, 234, 233).

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The Smooth March *(Stretch Goal)*

**Challenge:** animate the boundaries smoothly — one cycle step per frame.

**Hints:**
1. The lesson ROM flips between two frozen geometries. A march needs *twelve*: a ping-pong phase (0..11) where each phase delays the boundary block by one more cycle — pads of 4..15 cycles, which NOPs and `BIT`s can build (even → NOPs, odd → NOPs + `BIT`).
2. Rather than twelve branches in the ring (branch cycles again!), park the pad blocks outside the line ring and let an **indirect jump** select one: `JMP (PhasePtr)`, with the pointer written in VBLANK from a 12-word table. The jump costs 5 cycles in every phase; the pad eats the phase's difference; each block rejoins the shared boundary code with an absolute `JMP`.
3. The phase machine is a five-instruction ping-pong: add `PhaseDir` (+1 / −1, stored as `$01` / `$FF`), reverse at 11 and 0.

**Expected Result:** the three boundaries sweep from six cycles below home to five above (boundary 1: clocks 90..123) one cycle (three clocks / 18 capture pixels) per frame, a 22-frame round trip; phase 6 reproduces the lesson ROM's default geometry exactly. Measured: `B1Tick`'s first hit per frame steps 31, 32, 33 … 41, then 40, 39 … — one cycle per frame, 192 hits per frame; two captures ~0.3 s apart show different phases (boundary 1 at x = 283 and x = 229 — hit cycles 37 and 34, each with boundaries 2 and 3 following at +13 and +27).

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A write cycle is a position**: a TIA store takes effect from color clock **3 × N** (N = the cycle of the next instruction). The visible line is a 160-clock canvas and HBLANK covers the first 68 — a base write at N ≤ 22 paints the whole line
- ✅ **Only multiples of three are reachable**: write cycles are integers; boundaries land on clocks 3N. The quarter points 108 / 148 / 188 are reached at 108 / 147 / 189 — the nearest multiples of 3 on each side
- ✅ **`WSYNC` is the anchor, not an escape hatch**: a counted ring plus one anchor per line holds a position for 192 lines. The ring's wake (`DEX` + `BNE`, 5 cycles) must equal the entry's release (5 cycles), or line 37's notch will tell on you
- ✅ **Odd cycles need an odd instruction**: NOPs move in steps of two, so `BIT` (3 cycles, A untouched) tunes the gaps that must reach hit 63 — the odd-cycle tuner appears twice in this kernel
- ✅ **An animation is a geometry change, not a redraw**: shifting every boundary +4 cycles takes one gap (+2 NOPs) and a 120-frame counter that flips a state byte in VBLANK. Two states, two screenshots, one ROM: measured, the states alternate at frames 120 and 240, and the columns never wobble within a state
- ✅ **Part 2's timing chain is complete**: frame → colors → sync → timers → zones → cycle counting → sub-line positions. Everything from here — playfield, sprites, motion — is built on the same 76 cycles and the same ledger discipline

## What's Next

Part 2 is complete: you can count a line, fill it, and place a TIA write anywhere in it. What's missing is a vocabulary for *shapes* — and the TIA has a big one waiting. [Lesson 19: Playfield Basics](/part3-playfield/19-playfield-basics) opens Part 3 by putting the playfield register on screen: 20 bits that draw as blocks across the line, mirrored or repeated, the canvas every classic 2600 game is painted on. The columns taught you where the beam is; the playfield is what you draw once you know.
