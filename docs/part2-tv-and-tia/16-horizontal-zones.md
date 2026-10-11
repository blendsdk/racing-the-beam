---
title: "Lesson 16: Horizontal Zones — Splitting the Screen"
description: "The picture becomes data: the beam travels top to bottom, so a program can change TIA state between strips — horizontal zones. Build 'three-zone sky', a table-driven four-zone frame (scoreboard strip, sky, horizon, ground), and learn how each zone's boundary lands on an exact line by construction."
prev:
  text: "Lesson 15: The Timer"
  link: "/part2-tv-and-tia/15-the-timer"
next:
  text: "Lesson 17: Cycle Counting"
  link: "/part2-tv-and-tia/17-cycle-counting"
---

# Lesson 16: Horizontal Zones — Splitting the Screen

> **Part 2: TV & TIA** · Estimated time: 45 minutes
> **Prerequisites:** Lesson 12 (the counted frame — VSYNC, VBLANK, the visible 192, overscan), Lesson 13 (the color byte `%HHHHLLL0` and the named-color table), Lesson 14 (the WSYNC discipline and the HBLANK budget), Lesson 15 (the two timer windows and the corrected 44/36 frame)
> **You will learn:** horizontal zones — strips stacked down the screen, each with its own TIA setup; the zone table (a `(height, color)` row per zone) and the paint loop that walks it; how zone boundaries are counted as cumulative painted lines so each one lands on an exact scanline; the register discipline that keeps the color alive between the entry line and the per-line repaints; and the standard zone vocabulary (scoreboard / playfield / sprite zones) as the shape later parts fill in
> **You will build:** "three-zone sky" — the same 262-line frame, its 192 visible lines split into four zones of 24 / 72 / 48 / 48 lines — a dark scoreboard strip, a blue sky, a dark red horizon, and a dim green ground — painted from a four-row table in the ROM; plus three exercises: adding a fifth zone by splitting a row, rebalancing the zones by editing numbers, and moving the table into RAM so the debugger can reshape the picture live

## Introduction

The last several lessons painted more than one color per frame — Lesson 12's four equal bands, Lesson 13's sixteen hue swatches, Lesson 15's computed four-band picture. But in every one of them the *layout was hard-wired in code*: the heights were fixed constants, the boundaries were counted by hand, and changing the picture meant rewriting the kernel.

This lesson turns the picture into **data**. The 2600 has no frame buffer; nothing remembers what a previous line looked like. But the beam travels top to bottom and the CPU moves with it: a write between one line and the next repaints everything below it. A horizontal **zone** is a strip of lines painted with one TIA setup — and this ROM describes its four zones (a dark scoreboard strip, the sky, the horizon, the ground) as a four-row table of `(height, color)` pairs. The paint loop walks the table; the boundaries follow from the arithmetic; changing the picture means editing a row.

This is not a trick or an optimization: it is *the* way every real 2600 game is built. A scoreboard strip that gets cheap updates, a large field for the action, a status bar — all of them are zones, all painted top to bottom, all driven by the same discipline you already have: count your lines, write between them, anchor the boundaries.

`16-horizontal-zones.asm` is "three-zone sky": a dark strip along the top (the scoreboard area, waiting for later parts), then the sky, the horizon, and the ground. Four zones, four colors, and — the lesson's real subject — a **table** that describes the whole picture. The paint loop reads the table; the kernel does not know or care whether there are three zones or seven. Change the picture by editing data, not code.

::: details TypeScript Equivalent
Zones are a render list — the same shape as drawing stacked rectangles, or React rendering a list of rows:

```typescript
const zones = [
  { height: 24, color: 0x02 },   // scoreboard strip (dark neutral)
  { height: 72, color: 0x84 },   // sky
  { height: 48, color: 0x46 },   // horizon
  { height: 48, color: 0xC4 },   // ground
];

for (const zone of zones) {
  setBackground(zone.color);     // the zone's first line is painted now
  for (let line = 1; line < zone.height; line++) {
    await nextScanline();        // wait for the beam to reach the next row
    repaint(zone.color);         // no frame buffer: repaint every line
  }
  await nextScanline();          // park the last line; the next zone starts clean
}
```

The twist that makes this hardware work interesting: `repaint` is not a no-op — the TIA has no memory of the line above, so the color byte is re-written for *every* line, and the boundary lands wherever the counting says it does.
:::

## Theory

### Section 1: The Screen as Strips

A scanline is painted left to right in 76 CPU cycles; the frame is painted top to bottom in 262 lines. The CPU is synchronous with that beam — Lesson 14's `WSYNC` is exactly the tool that keeps it so — which means the CPU can change TIA state *at any line boundary it can count to*. Between line 60 and line 61, a write to `COLUBK` changes the background for everything the beam has not drawn yet. Line 61 onward is a new color; line 60 and everything above it keeps what it had.

That is the entire mechanism of a horizontal zone:

- **A zone is a range of scanlines painted with one TIA setup.**
- **A zone boundary is a line where the CPU writes new state before the beam paints it.**
- **The state it writes can be anything**: background color (`COLUBK`), playfield color, sprite positions, object visibility — later parts will change far more than colors in a zone boundary. This lesson only moves `COLUBK`, which keeps the picture — and the arithmetic — legible.

One constraint shapes everything: a write takes effect for every pixel *not yet drawn* on the current line. That makes HBLANK the natural boundary window — the ~23 cycles before the visible part of a line — and gives a simple rule:

> **A zone's first line is correct if its color store completes inside that line's HBLANK.**

Lessons 12 and 14 established the HBLANK budget (68 color clocks ≈ 22.7 CPU cycles); this lesson spends a measured fraction of it — about 14–16 cycles at each zone entry — and the debugger section below shows the stores landing inside the window line after line.

### Section 2: The Zone Table

Four zones could be four blocks of code. This lesson writes one loop and one table instead:

```
ZoneTable:
    !byte 24, $02           ; zone 0: scoreboard strip (dark neutral)
    !byte 72, $84           ; zone 1: sky (blue, low luminance)
    !byte 48, $46           ; zone 2: horizon (dark red)
    !byte 48, $C4           ; zone 3: ground (dim green)
ZoneTableEnd:
ZONE_TABLE_LEN = ZoneTableEnd - ZoneTable    ; bytes to walk (8 = 4 zones x 2)
```

One `(height, color)` pair per zone, in paint order. The loop walks the table as byte offsets 0, 2, 4, 6 — the height at the even byte, the color at the next — and its end test is derived from the table's own end label:

```asm
    CPX #ZONE_TABLE_LEN
    BNE ZoneBegin
```

That line is the lesson's quiet star. Because the bound comes from the table, **the loop never needs editing when the picture does**: adding a fifth zone (Exercise 1) is one `!byte` row, and the end test moves with it. Data-driven kernels are not a style preference here; they are how a four-zone lesson can ship a five-zone exercise without touching the kernel.

The heights must sum to 192 — the visible lines. Their cumulative sums are the boundaries:

| Zone | Height | Cumulative painted lines |
|---|---|---|
| 0 (strip) | 24 | 24 |
| 1 (sky) | 72 | 96 |
| 2 (horizon) | 48 | 144 |
| 3 (ground) | 48 | 192 |

And one counting convention, carried since Lesson 12: **the release line counts inside zone 0.** The first visible line (Stella's scanline 37) is painted as zone 0's first line; zone 0's 24 lines are scanlines 37–60; zone 1 starts at 61; zone 2 at 133; zone 3 at 181. The cumulative numbers 24 / 96 / 144 / 192 are painted-line counts; add 36 blanked lines and you have the scanlines 60 / 132 / 180 / 228 where each zone *ends*.

### Section 3: The Zone Vocabulary

The 2600 community long ago named the zones that show up in real games. This lesson's four strips are a miniature version of that taxonomy; the names are worth knowing now because later parts fill them in (the playfield in Part 3, sprites from Part 4 on):

| Zone (typical) | What lives there | This lesson's stand-in |
|---|---|---|
| **Status / scoreboard zone** | Score digits, lives, level — a few lines at the top, cheap to update | Zone 0: the dark 24-line strip |
| **Playfield zone** | The game world — the large middle area | Zones 1–2: sky and horizon |
| **Sprite / action zone** | The players, missiles, and ball — positioned per zone | Zone 3's ground; sprites arrive in Part 4 |
| **Status / color strip** (bottom) | Lives, timer bars — some games reserve the last lines | — |

Two notes about the vocabulary. First, the names describe *roles*, not hardware: there is no "scoreboard register"; a scoreboard is simply a zone whose contents change rarely and whose update code can be cheap, painted first while the CPU still has budget. Second, the taxonomy only becomes literal in later parts — this lesson stays with background colors only, and names the roles as context for where the course is going.

### Section 4: The Register That Must Survive

There is one trap in this kernel, and it is worth meeting here because it is a whole class of 2600 bugs: **between the entry line and the per-line repaints, the color must stay in the accumulator.**

The entry sequence loads a zone's color, stores it to `COLUBK` for the first line — and then the loop repaints every following line with `STA COLUBK`. That store writes **whatever is in A**. Load the height into A at the entry (a natural thing to try), and every repaint writes *the height byte as a color*: zone 0 (24 lines, `$18`) paints a muted gold, zone 1 (72 lines, `$48`) paints a pale red, and the debugger shows a picture that looks nothing like the table.

The fix is two keystrokes of discipline: the height loads into **Y**, not A.

```asm
    LDA ZoneTable+1,X       ; this zone's color (stays in A for the repaints)
    STA COLUBK              ; the zone's FIRST line — store lands in HBLANK
    LDY ZoneTable,X         ; this zone's height — into Y, so A keeps the color
```

`LDY`/`STY` exist exactly for this: the X register already walks the table cursor, so the counter goes to Y and the payload stays in A. The visible loop then is Lesson 14–15's paint loop, untouched:

```asm
ZoneLines:
    STA WSYNC               ; wait out this line
    STA COLUBK              ; repaint this line (store at line-cycle 2)
    DEY
    BNE ZoneLines
```

Four instructions, 11 cycles per line — 3 for the `WSYNC` write, 3 for the repaint, 2 for the decrement, 3 for the taken branch — out of 76. The line is quiet; the boundary is where the attention goes.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson16.bin \
  lessons/part2-tv-and-tia/16-horizontal-zones/16-horizontal-zones.asm
stella build/lesson16.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`, all in the same directory.

### Full Source

The frame skeleton is Lesson 12's — VSYNC 3, visible 192, the Lesson 15 timers for the two blanked windows — and the visible part is new: a table, a walking cursor, and a per-zone anchor.

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 16: Horizontal Zones — Splitting the Screen
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   "Three-zone sky": the visible 192 lines are painted as four stacked
;   horizontal zones, each with its own background color, and the whole
;   picture is driven by a small table in the ROM — one (height, color)
;   pair per zone.  This is the multi-zone architecture every later part
;   fills in: different TIA setups for different strips of the screen.
;
;     - VSYNC: 3 lines, counted with WSYNC (the pulse must be exact).
;     - VBLANK: TIM64T = 44 (exactly 37 lines), then the INTIM poll.
;     - Visible: 192 lines = 24 + 72 + 48 + 48, painted top to bottom
;       from the table: a dark scoreboard strip, the sky, a dark red
;       horizon, and the ground.  A per-zone anchor WSYNC parks each
;       zone's last line, so every boundary sits on an exact line.
;     - Overscan: TIM64T = 36 (exactly 30 lines), polled the same way.
;
;   The picture: four zones, top to bottom —
;     zone 0:  24 lines, $02  (hue 0, level 1 — a dark neutral strip;
;                              later parts put the scoreboard here)
;     zone 1:  72 lines, $84  (hue 8, level 2 — the blue sky)
;     zone 2:  48 lines, $46  (hue 4, level 3 — the dark red horizon)
;     zone 3:  48 lines, $C4  (hue 12, level 2 — the dim green ground)
;
; What you'll learn:
;   - horizontal zones: strips stacked down the screen, each with its
;     own TIA setup — the screen changes as the beam travels, simply
;     because the CPU writes registers between the strips
;   - the zone table: one (height, color) row per zone in the ROM, and
;     a paint loop that walks it — change the table, not the kernel
;   - boundaries by construction: each zone counts its own painted
;     lines and anchors its last line, so zone 0 ends at painted line
;     24, zone 1 at 96, zone 2 at 144, zone 3 at 192
;   - the standard zone vocabulary (scoreboard / playfield / sprite
;     zones) as the shape later parts fill in
;
; The zone-entry ledger (why each zone's first line gets its own color):
;   a TIA color write takes effect for every pixel that has not been
;   drawn yet, so the first line of a zone is safe as long as its color
;   store completes inside HBLANK (68 color clocks ≈ 22.7 CPU cycles).
;   - zone 0 (the release line, Stella 37): the release path plus
;     LDX / LDA put the STA COLUBK store at about cycle 14 — inside.
;   - zones 1-3 (Stella 61 / 133 / 181): the anchor wakes the CPU at
;     the line start, and INX / INX / CPX / BNE / LDA put the store at
;     about cycle 16 — still inside.
;   - every later line repaints at line-cycle 2 (deep in HBLANK):
;     WSYNC parks the line, the store lands right after the beat.
;
; The paint-loop ledger (steady state, one line):
;   STA WSYNC          3    wake at the line start
;   STA COLUBK         3    the repaint — write at line-cycle 2
;   DEY                2
;   BNE ZoneLines      3    taken; 11 cycles of the 76 spent
;   The last line of each zone is parked by the anchor WSYNC instead,
;   and the next zone's entry code (13 cycles) runs in the new line's
;   HBLANK.  No line in the visible picture ever runs over budget.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VblankPoll (A = the INTIM value
;   just read), VisibleStart (37), ZoneColor (A = the color just
;   loaded for this zone), ZoneHeight (Y = the height just loaded),
;   ZoneWrite (one hit per line — the anchor-hold position of Lessons
;   14-15), OverscanStart (229), OverscanPoll (A = the INTIM value
;   just read).
;
; Build: acme -f plain -o build/lesson16.bin \
;        lessons/part2-tv-and-tia/16-horizontal-zones/16-horizontal-zones.asm
; Run:   stella build/lesson16.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame and its two timer windows
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (Lesson 15)
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (Lesson 15)

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
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines (Lesson 12): the pulse itself still wants WSYNC,
; because it must start and end on exact lines.
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

VblankWait:
    LDA INTIM               ; how much blanking is left?
VblankPoll:                 ; debugger checkpoint: A = the value just read
    BNE VblankWait          ; keep polling until it reads 0
    STA WSYNC               ; line up with the beam (parks the rest of the line)

    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
VisibleStart:               ; debugger checkpoint: the picture's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — four zones, painted from the (height, color) table below
; -----------------------------------------------------------------------------
    LDX #0                  ; table cursor: X = this entry's byte offset
ZoneBegin:
    LDA ZoneTable+1,X       ; this zone's color (stays in A for the repaints)
ZoneColor:                  ; debugger checkpoint: A = the color just loaded
    STA COLUBK              ; the zone's FIRST line — store lands in HBLANK
    LDY ZoneTable,X         ; this zone's height — into Y, so A keeps the color
ZoneHeight:                 ; debugger checkpoint: Y = the height just loaded
    DEY                     ; the first line is painted; H-1 remain
ZoneLines:
    STA WSYNC               ; wait out this line
ZoneWrite:                  ; debugger checkpoint: one hit per line, in HBLANK
    STA COLUBK              ; repaint this line (store at line-cycle 2)
    DEY
    BNE ZoneLines
    STA WSYNC               ; anchor: park out the zone's last line
    INX
    INX                     ; step to the next (height, color) entry
    CPX #ZONE_TABLE_LEN
    BNE ZoneBegin

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
    JMP StartFrame          ; 262 lines done: next frame

; =============================================================================
; ZONE TABLE — one (height, color) pair per zone, painted top to bottom
;
; The paint loop walks this table as byte offsets 0, 2, 4, 6: the height
; at the even offset, the color at the next byte.  The heights must sum
; to 192 — the visible lines — and the cumulative sums are the zone
; boundaries (24 / 96 / 144 / 192 painted lines).  The release line
; counts as zone 0's first line, so zone 0's 24 lines are Stella
; scanlines 37-60; the anchors keep every later boundary line-exact.
; Each height must be at least 2 — the countdown loop decrements before
; it tests, so a height of 1 (or 0) wraps and the zone runs away.
; =============================================================================
ZoneTable:
    !byte 24, $02           ; zone 0: scoreboard strip (dark neutral)
    !byte 72, $84           ; zone 1: sky (blue, low luminance)
    !byte 48, $46           ; zone 2: horizon (dark red)
    !byte 48, $C4           ; zone 3: ground (dim green)
ZoneTableEnd:
ZONE_TABLE_LEN = ZoneTableEnd - ZoneTable    ; bytes to walk (8 = 4 zones x 2)

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
> `lessons/part2-tv-and-tia/16-horizontal-zones/16-horizontal-zones.asm`.

### Code Walkthrough

#### Step 1 — The frame, and what stays the same

The frame keeps its exact shape: 3 lines of VSYNC (WSYNC-counted — the pulse must start and end on exact lines), the 37-line VBLANK on `TIM64T` = 44, the visible 192, the 30-line overscan on 36, back to VSYNC — 262 lines, the course standard since Lesson 12, timed since Lesson 15. Neither the blanking nor the frame is this lesson's subject; they are copied from the skeleton so the zones can be measured against a known-stable beam.

#### Step 2 — A table and a cursor

```asm
    LDX #0                  ; table cursor: X = this entry's byte offset
ZoneBegin:
    LDA ZoneTable+1,X       ; this zone's color
ZoneColor:                  ; debugger checkpoint: A = the color just loaded
    STA COLUBK              ; the zone's first line (HBLANK)
    LDY ZoneTable,X         ; this zone's height — into Y, so A keeps the color
ZoneHeight:                 ; debugger checkpoint: Y = the height just loaded
    DEY                     ; the first line is painted; H-1 remain
```

X is the table cursor, stepping by 2 (height at `ZoneTable+X`, color one byte later). Y counts the zone's remaining lines. A carries the color through the whole zone — Section 4's discipline, visible here in the register dance: the color load, the store, then the height going *around* the accumulator into Y. The two checkpoints (`ZoneColor`, `ZoneHeight`) are placed so one debugger line shows all three registers at each zone entry: A = color, X = cursor, Y = height.

#### Step 3 — The repaint loop, and how the entry line counts

```asm
ZoneLines:
    STA WSYNC               ; wait out this line
ZoneWrite:                  ; debugger checkpoint: one hit per line, in HBLANK
    STA COLUBK              ; repaint this line (store at line-cycle 2)
    DEY
    BNE ZoneLines
    STA WSYNC               ; anchor: park out the zone's last line
```

The counting convention: the entry store painted the zone's **first** line, so Y = height − 1 (`DEY` right after the load), the loop repaints the next height − 1 lines, and the final `STA WSYNC` — the **anchor** from Lesson 14 — parks out the zone's last line. A 24-line zone therefore runs 23 loop passes; the four zones ship 23 + 71 + 47 + 47 = 188 loop passes, one per repainted line, and the debugger counts exactly that.

The anchor is what makes the next zone exact: when the last line ends, the CPU wakes at the start of the next line with 13 cycles of entry code ahead of it — `INX`, `INX`, `CPX`, `BNE`, the color load — all of it landing before HBLANK ends (≈ 22.7 cycles). Each boundary therefore sits at the scanline the table says: zone 1 at 61, zone 2 at 133, zone 3 at 181.

#### Step 4 — Why the color store never misses its window

Putting the numbers together, as measured in Stella 7:

| Entry | Path to the store | Store completes | HBLANK ends |
|---|---|---|---|
| Zone 0 (release line 37) | release + `LDX` + color load ≈ 11 cycles | cycle ≈ 14 | ≈ 22.7 |
| Zones 1–3 (lines 61 / 133 / 181) | anchor wake + `INX`/`INX`/`CPX`/`BNE` + load ≈ 13 | cycle ≈ 16 | ≈ 22.7 |

Both stores complete with margin, so every zone's first line is painted with its own color from the first visible pixel — no bleed at the boundaries. And every later line repaints at line-cycle 2, deep inside HBLANK: the WSYNC beat, then the store, line after line, for all 192.

#### Step 5 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | 259, cycle 3 | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `VblankPoll` | `$F028` | **A = the INTIM value just read** — 43 first, then 0 at line 36, cycle ≈ 35 | the VBLANK poll |
| `VisibleStart` | `$F030` | 37, cycle 5 | the picture's first line |
| `ZoneColor` | `$F035` | 4 hits/frame: `(37,11) A=$02 X=0` · `(61,13) A=$84 X=2` · `(133,13) A=$46 X=4` · `(181,13) A=$C4 X=6` | each zone's color, mid-walk |
| `ZoneHeight` | `$F03A` | same lines: `Y=$18` · `Y=$48` · `Y=$30` · `Y=$30` (A = color above, X = cursor) | each zone's height |
| `ZoneWrite` | `$F03D` | one hit per line — cycle 11 / pixel −35 (the anchor-hold position of Lessons 14–15); A = the zone's color on every line | the per-line repaint |
| `OverscanStart` | `$F04A` | 229, cycle 8 | overscan's first line |
| `OverscanPoll` | `$F056` | **A = the INTIM just read** — 35 first, then 0 at line 258, cycle ≈ 59 | the overscan poll |

## What You Should See

A stable four-strip picture: a dark neutral strip 24 lines tall at the top, a large blue sky, a dark red horizon band, and a green ground — the boundaries crisp at every column, nothing moving, the frame wrapped exactly as Lessons 12–15 left it (259/0/37/229).

![Stella running the Lesson 16 ROM: four horizontal zones — a dark grey strip, a blue sky, a dark red horizon, and a green ground — stacked top to bottom](/images/lesson16/zones.png)

*Captured from the ROM: zone 0 is `$02` — the neutral column at luminance 1, a dark grey; zone 1 is `$84`, byte-identical to Lesson 12's blue band (the captured pixels are the same `(36, 40, 176)`); zone 2 is `$46`, the red hue two levels brighter than Lesson 12's `$42`; zone 3 is `$C4`, the Lesson 12 green two luminance steps down. Measured runs: 74 / 226 / 150 / 151 pixels for the 24 / 72 / 48 / 48 lines.*

<RomPlayer rom="/roms/part2-tv-and-tia/16-horizontal-zones/16-horizontal-zones.bin" title="Lesson 16 — Horizontal Zones" />

The debugger tells the same story as numbers (values below as reported by Stella 7):

```bash
# assemble with a symbol list to get the checkpoint addresses
acme -f plain -l build/lesson16.sym -o build/lesson16.bin \
  lessons/part2-tv-and-tia/16-horizontal-zones/16-horizontal-zones.asm
grep -E "ZoneColor|ZoneHeight|ZoneWrite" build/lesson16.sym

# then log one breakpoint per run
stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F03A' \
  docs/public/roms/part2-tv-and-tia/16-horizontal-zones/16-horizontal-zones.bin
```

- **`$F035` (`ZoneColor`)**: fires four times per frame — once per table row — at the zone's first line. A is the color just loaded, X is the cursor: `$02`/0, `$84`/2, `$46`/4, `$C4`/6. The walk is visible line by line: 37, 61, 133, 181.
- **`$F03A` (`ZoneHeight`)**: the same four entries, a few cycles later, with the height in Y: 24, 72, 48, 48 (`$18`, `$48`, `$30`, `$30`). Each row is used exactly once per frame.
- **`$F03D` (`ZoneWrite`)**: one hit per line — 188 per frame — always at the same HBLANK position (cycle 11 / pixel −35, the anchor-hold beat from Lessons 14–15). Sample it mid-zone and A reads the zone's color: `$84` on the sky's lines, `$46` on the horizon's, `$C4` on the ground's — the accumulator discipline of Theory 4, live.
- **`$F028` (`VblankPoll`)** and **`$F056` (`OverscanPoll`)**: the timer countdowns of Lesson 15, unchanged — first reads 43 and 35, zeros at line 36 and line 258.

## Exercises

### Exercise 1: A Fifth Zone — Split the Sky

**Challenge:** split the sky zone into two bands by adding a row to the table — five zones totalling 192 lines, with the paint loop untouched.

**Hints:**
1. The split: 72 becomes 48 + 24, so the table reads 24 / 48 / 24 / 48 / 48. Give the lower band a brighter blue (`$86` is `$84` one level up) — the sky lightens toward the horizon.
2. You do not need to touch `CPX #ZONE_TABLE_LEN`: it is computed from the table's end label, so it follows the new row automatically. That is the whole point of deriving bounds from data.
3. The boundaries move to painted lines 24 / 72 / 96 / 144 / 192; the zone entries land on scanlines 37 / 61 / 109 / 133 / 181.

**Expected Result:** five stable zones; `ZoneColor` and `ZoneHeight` fire five times per frame, with the sky split visible as two blues; the frame still 259/0/37/229.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Rebalance the Picture

**Challenge:** keep four zones and 192 lines, but change the *proportions* — e.g. 48 / 96 / 24 / 24 — by editing the table's numbers only.

**Hints:**
1. Four numbers change; the colors stay. Total check: 48 + 96 + 24 + 24 = 192.
2. The zone entries move: zone 1 now starts at scanline 85 (48 painted lines before it), zone 2 at 181, zone 3 at 205. Predict them from the cumulative sums before you run it.
3. This is a good exercise to break deliberately: change one height and leave the total wrong. The picture still draws, but the frame stretches — the ground runs into where overscan should be. That visible failure is the sum rule teaching itself.

**Expected Result:** the same colors in new proportions; `ZoneHeight` reports 48 / 96 / 24 / 24 (`$30` / `$60` / `$18` / `$18`) at lines 37 / 85 / 181 / 205.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The Table in RAM *(Stretch Goal)*

**Challenge:** move the zone table into RAM so its boundaries can be edited live — no reassembly, no restart.

**Hints:**
1. Keep the `(height, color)` bytes in the ROM as an initializer, and copy them to a fixed RAM block (this solution uses `$80–$87`) once, at boot. From then on the paint loop reads RAM — a zero-page indexed load (`LDA $80,X`) costs the same 4 cycles as the ROM version.
2. Because the kernel re-reads the table *every frame*, an edit is visible on the next frame. In Stella's debugger, open the RAM view and type new values into `$80–$87`: to keep the total honest, move lines *between* zones — e.g. cut the sky from `$48` to `$30` (72 → 48 lines) and the ground from `$30` to `$18` (48 → 24), and give the horizon `$60` (48 → 96). That reads 24 + 48 + 96 + 24 = 192: the horizon takes 24 lines from each neighbour, the frame stays 262 lines. Keep every height at 2 or more — a height of 1 (or 0) wraps the countdown and the zone runs away for 250+ lines.
3. A breakpoint on the copy loop shows it running eight times on the boot frame and never again — the migration happens once, the picture runs on RAM forever after.

**Expected Result:** the same four-zone picture, now driven by `$80–$87`; editing live bytes reshapes the picture on the next frame — e.g. the sky `$48 → $30`, the horizon `$30 → $60`, the ground `$30 → $18` moves 24 lines from each neighbour into the horizon while the frame stays 262 lines.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A zone is a range of scanlines painted with one TIA setup** — and a zone boundary is simply a line where the CPU wrote new state before the beam got there. No new hardware, just the write discipline from Lessons 13–15
- ✅ **The release line counts inside zone 0**, and zone heights are cumulative: 24 / 72 / 48 / 48 becomes boundaries at painted lines 24 / 96 / 144 / 192 (scanlines 60 / 132 / 180 / 228)
- ✅ **Data-driven kernels scale with the picture, not the code**: one `(height, color)` row per zone, a cursor in X, and a bound derived from the table's end label — the loop never changes when the table does
- ✅ **The color must survive in A between the entry store and the per-line repaints** — the height loads into Y (the X/Y register discipline is not decoration; it is the kernel's correctness)
- ✅ **Every zone's first line is HBLANK-safe**: the longest entry path is ~13 cycles of the ~23 available, measured at ~cycle 16 of the boundary lines
- ✅ **The zone vocabulary — scoreboard, playfield, sprite zones — describes roles**: cheap-to-update strips at the top, the large middle, and where objects live. Later parts fill these names in with playfield and sprite content
- ✅ **The frame is untouched by any of it**: 259/0/37/229, 262 lines — four zones instead of one cost two instructions of bookkeeping per line, and the picture proves the budget

## What's Next

The picture now has structure: four zones, each with its own color and its own line count, all driven by data. But every zone in this lesson is *quiet* — the kernel spends 11 cycles per line and the other 65 stay empty. That gap is not slack to waste; it is the room every later part will spend on real work: playfield pixels, sprite draws, game logic. [Lesson 17: Cycle Counting](/part2-tv-and-tia/17-cycle-counting) makes the budget explicit — 76 cycles per line, counted by hand — and shows exactly what happens to the picture when a single line overspends by six.
