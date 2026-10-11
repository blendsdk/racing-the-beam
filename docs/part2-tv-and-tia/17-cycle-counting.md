---
title: "Lesson 17: Cycle Counting — The Heart of Beam Racing"
description: "A scanline is 76 CPU cycles. This lesson counts them by hand: an exactly-76-cycle loop that rides the beam with no WSYNC inside, and the same loop with a deliberate +6-cycle overrun — 96 iterations of drift that turn the picture into a staircase and stretch the frame from 262 to 270 lines."
prev:
  text: "Lesson 16: Horizontal Zones"
  link: "/part2-tv-and-tia/16-horizontal-zones"
next:
  text: "Lesson 18: Mid-Scanline Changes"
  link: "/part2-tv-and-tia/18-mid-scanline-changes"
---

# Lesson 17: Cycle Counting — The Heart of Beam Racing

> **Part 2: TV & TIA** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 12 (the counted frame), Lesson 13 (the color byte `%HHHHLLL0` and the hue wheel), Lesson 14 (the WSYNC discipline and the HBLANK budget), Lesson 15 (the exact 44/36 timer windows), Lesson 16 (zones — the picture as stacked ranges of lines)
> **You will learn:** the 76-cycle scanline as a spendable budget; instruction cycle costs and the two counting traps (the exit branch's parity and the `abs,X` page-crossing penalty); how a hand-counted loop rides the beam with no `WSYNC` inside; what a six-cycle overrun per line does to a picture (a drifting staircase and an eight-line stretch); and the ledger discipline that makes every claim checkable
> **You will build:** "the cycle ruler" — a two-section frame: section 1 is a hand-counted loop of exactly 76 cycles per iteration painting the 16 hues at luminance 7, one hue per six lines, rock-steady; section 2 is the same loop with a deliberate +6-cycle overrun, drifting visibly and growing the frame from 262 to 270 lines; plus three exercises: counting a drill snippet by hand and verifying it with breakpoints, trimming the overrun back to exactly 76, and writing the full kernel ledger

## Introduction

Every lesson so far has *spent* cycles; none has counted them. `WSYNC` wrote them away, the RIOT counted them for the two blanking windows, and the HBLANK budget was measured in them — but the frame always had an escape hatch: when timing got tight, you aligned to the beam and let the hardware handle the rest.

This lesson closes the hatch. The 2600's CPU is synchronised to the beam: **76 CPU cycles per scanline**, always, and a write that lands at cycle N of a line paints from color clock 3N onward. There is no clock the CPU follows that the beam doesn't also follow — which means a loop that costs *exactly* 76 cycles per iteration can never fall behind the beam, and a loop that costs 82 falls behind a little more every single line.

"The cycle ruler" puts that on screen. Section 1 is a hand-counted 76-cycle loop — no `WSYNC` anywhere inside — painting the 16 hues at luminance 7 in descending steps of six lines. If the count is right, the loop rides the beam for 96 lines without a wobble. Section 2 is the *same loop* with a deliberate six-cycle overrun per iteration: the writes slide later and later within their lines, the hue boundaries turn into a drifting staircase, and the section stretches by roughly eight lines — the whole frame grows from 262 to 270 lines because the CPU had six extra cycles of work to do every line.

That is the heart of beam racing: not waiting for the beam, but **counting the same clock it counts**.

::: details TypeScript Equivalent
A cycle budget is arithmetic a junior developer already knows — a running total with an assertion at the end:

```typescript
const LINE = 76;                       // CPU cycles in one scanline

let spent = 0;
const spend = (what: string, cost: number) => { spent += cost; };

spend("LDA ColorRamp,X", 4);           // fetch this line's hue
spend("STA COLUBK", 3);                // paint it
spend("NOP x31", 62);                  // deliberate filler
spend("INX", 2);
spend("CPX #96", 2);
spend("BNE", 3);                       // taken: loops
console.assert(spent === LINE);        // exactly one scanline — the whole game

spend("NOP x34 instead", 6);           // section 2: six cycles over budget
console.assert(spent === LINE + 6);    // ...and the picture pays, every line
```

In a web app an overrun costs milliseconds and nobody sees it. Here the "milliseconds" *are* the screen: every cycle the loop overspends moves its next write three color clocks (three pixels) further right, and the display records the debt line after line.
:::

## Theory

### Section 1: The 76-Cycle Line

The numbers were fixed in Lesson 12 and are worth restating precisely, because everything in this lesson is measured against them:

- An NTSC scanline is **228 color clocks**. The TIA paints the visible 160 in the middle; the rest is HBLANK.
- The 6507 runs at **1/3 the color clock rate**, so a scanline is **76 CPU cycles** (228 ÷ 3).
- The visible portion starts at **color clock 68** — about **cycle 22⅔** of the line. A write that lands at or before cycle 22 is inside HBLANK: it affects the whole visible line. A write at cycle N > 22 affects only the pixels from color clock 3N onward — everything before it keeps the previous color.
- `WSYNC` exists precisely because counting 76 cycles per line is hard. **This lesson doesn't use it** — the count itself is the tool.

A loop that costs exactly 76 cycles per iteration, started aligned at a line boundary, spends exactly one scanline per iteration. Nothing drifts, nothing queues: the write that sets the color happens at the same in-line cycle on every single line, so the picture is rows of whatever you wrote and nothing else.

### Section 2: What Things Cost

Counting a kernel by hand means knowing instruction costs cold. The categories:

| Cycles | Instructions (examples) | Why |
|---|---|---|
| 2 | `NOP`, `INX`/`DEY`, immediate loads (`LDA #`, `LDY #`), branch **not** taken | nothing to fetch from memory |
| 3 | zero-page reads and writes (`STA COLUBK`, `LDA zp`), branch **taken** | fast memory, no extra fetch |
| 4 | absolute reads (`LDA abs`, `LDA abs,X` — +1 if it crosses a page) | a second address byte |
| 5 | indexed writes (`STA abs,X`) | write with an indexed address |
| 6 | `JSR`, `RTS`, `INC abs` | stack / read-modify-write work |

Two traps account for nearly every real counting error, and this lesson's loop meets both:

1. **The exit branch is cheaper.** `BNE` costs 3 cycles when taken, 2 when it falls through. A loop of 96 iterations therefore costs `96 × 76 − 1 = 7,295` cycles, not 7,296: exactly one cycle is missing at the end. The missing cycle is a branch parity, and padding cannot close it — there is no 1-cycle instruction, so a padding pass can never add exactly the one cycle it would need. This ROM leaves it where it is harmless: the spare cycle lands in HBLANK and feeds the junction (Section 3), and the ledger below measures exactly that.
2. **`abs,X` reads cross pages.** `LDA abs,X` costs 4 cycles — *plus one* if the base address plus X crosses a 256-byte page boundary. The extra fetch is invisible in the source and silently breaks the budget. The fix is structural: keep the table inside a single page (this ROM page-aligns its 96-byte ramp, so X ∈ 0..95 can never cross).

### Section 3: The Counted Loop

Here is section 1's loop — the lesson's whole subject in six lines and a NOP block:

```asm
    LDX #0                  ; ramp index = line counter (0..95)
S1Loop:
    LDA ColorRamp,X         ; 4 |  4    this line's hue (page-safe abs,X)
    STA COLUBK              ; 3 |  7    paint from HBLANK onward
S1Tick:                     ; debugger checkpoint: one hit per line, constant cycle
    <31 x NOP>              ; 62 | 69   the budget filler
    INX                     ; 2 | 71
    CPX #RAMP_LENGTH        ; 2 | 73   96 lines — one ramp entry per line
    BNE S1Loop              ; 3 | 76   (2 on the exit — the loop's last branch)
```

4 + 3 + 62 + 2 + 2 + 3 = **76 cycles**. The `ColorRamp` table holds the 16 hues at luminance 7 (`$0E`, `$1E`, … `$FE`), each repeated six times, indexed by line: hue changes every six iterations without costing the loop a single extra cycle. **No `WSYNC` inside**: the loop is aligned at the section start by the release (the same procedure Lesson 16 used), and after that the beam and the loop agree by arithmetic alone.

The alignment isn't assumed, it is *evidence*: a breakpoint on `S1Tick` fires once per line, always at the same in-line cycle. In Stella's log, all 96 hits of a frame read at cycle 14 — line 37 through line 132. The moment a hit appeared a cycle late, the count would be wrong.

#### The junction

Section 1's loop ends the way every counted loop ends: one cycle short of a perfect 96 lines — 7,295 instead of 7,296, because the exit branch is one cycle cheaper than the loop branch (the trap above). The gap is a branch parity, and padding cannot close it — no 1-cycle instruction exists to add — so this ROM doesn't chase it: the spare cycle lands in the next line's HBLANK, where it costs nothing. Section 2's prologue therefore starts **immediately** — no `WSYNC` at the junction. Its first write still lands inside HBLANK, so the boundary between the sections is exact: the last hue of section 1 ends on line 132, section 2's ramp restarts on line 133, and no line in between shows a sliver.

Counted sections chain by cycles. `WSYNC` is the escape hatch when you cannot count — this lesson is about counting.

### Section 4: Over-Budget — What Six Cycles a Line Do

Section 2 is *the same loop* with a deliberate addition: 34 `NOP`s instead of 31 — six extra cycles of filler. The ledger is `4 + 3 + 68 + 2 + 2 + 3 = 82` cycles per iteration — six over.

96 iterations at 82 cycles: the loop total is 7,871 cycles (95 × 82 + 81 — the exit trap again), 7,873 with its prologue, ≈ 103.6 scanlines for work sized for 96. The six cycles per line compound:

- After one line, the writes are 6 cycles late; after ten, 60; the write position within the line marches right in steps of six.
- Once a write's position passes cycle 22, it has left HBLANK: that line now shows a **sliver** of the previous hue on its left, then the new hue — the boundary has moved into the visible region. The measured positions of those slivers, hue change by hue change, are in the debugger section below — the staircase the capture shows.
- When the position walks past a full line (76 cycles of marching, ~12.7 lines), the next write skips a line: the following hit lands two lines later, not one. That happens seven times across the section — 96 hits spread over 103 lines — so the notches walk and wrap in a sawtooth.
- At the end, the section has consumed 7,873 cycles for 96 iterations' worth of picture: the extra 576 cycles (96 × 6) are ≈7.6 beam lines. The frame, which has no `WSYNC` beyond the counted skeleton, simply grows: **270 lines instead of 262** — measured, breakpoint `StartFrame` at scanline 267.

This is what "racing the beam" means in practice: the beam never waits for you, but it also never lies. Every cycle you spend is visible somewhere on screen — and with a ledger, you can point at exactly where.

### A Counting Drill

Before the exercises, one small piece of code to count — the classic little delay loop:

```asm
Drill:
    LDY #$0A                ; 2 cycles — the loop runs ten times
DrillLoop:
    DEY                     ; 2 cycles
    BNE DrillLoop           ; 3 taken / 2 not taken
    JMP Drill               ; 3 cycles — and around again (this ROM loops it)
```

Count it before you scroll on: prologue, the ten loop iterations (nine of them with the branch taken), the exit, and the back edge. Exercise 1 gives the answer — and the breakpoint recipe that lets the machine print the same number.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson17.bin \
  lessons/part2-tv-and-tia/17-cycle-counting/17-cycle-counting.asm
stella build/lesson17.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`, all in the same directory.

### Full Source

The frame keeps the course skeleton — 3 lines of VSYNC, the 37-line VBLANK on `TIM64T` = 44, the 30-line overscan on 36 — and puts the counted loops where Lesson 16 put its zones. No `WSYNC` inside either loop; the junction chains by cycle count.

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 17: Cycle Counting — The Heart of Beam Racing
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   "The cycle ruler": two 96-line sections that put the cycle budget on
;   screen.  Section 1 is a hand-counted loop of exactly 76 cycles per
;   iteration — one scanline's worth — with no WSYNC inside: if the count
;   is right, the loop rides the beam line for line.  Section 2 is the
;   same loop with a deliberate +6-cycle overrun per iteration: the CPU
;   falls 6 cycles behind every line, and the picture shows it.
;
;     - VSYNC: 3 lines, counted with WSYNC (the pulse must be exact).
;     - VBLANK: TIM64T = 44 (exactly 37 lines), then the INTIM poll.
;     - Visible: section 1 (96 iterations x 76 cycles = 96 lines) then
;       section 2 (95 x 82 + 81 = 7,871 loop cycles ≈ 103.6 lines).  The
;       junction chains by cycle count — no WSYNC — and the exit's
;       spare cycle lands harmlessly in the next line's HBLANK.
;     - Overscan: TIM64T = 36 (exactly 30 lines), polled the same way.
;
;   The picture: section 1 — 16 horizontal bands, the 16 hues at
;   luminance 7 ($0E, $1E, ... $FE), one hue change every 6 lines,
;   rock-steady because every iteration costs exactly 76 cycles.
;   Section 2 — the same ramp with the overrun: each line's color write
;   lands 6 cycles later than the last, so the hue changes arrive as a
;   drifting staircase (see the capture), and the section itself
;   stretches ~8 lines (7,873 cycles with its prologue ≈ 103.6 lines).
;
; What you'll learn:
;   - the 76-cycle scanline is a budget you spend, not a clock you
;     follow: cycles translate to beam position directly
;   - instruction cycle costs and their categories
;   - counting a loop by hand — including the two traps: the exit
;     branch is 1 cycle cheaper than the loop branch, and an abs,X
;     read costs +1 when it crosses a page
;   - what over-budget work does to a picture: every extra cycle moves
;     the write — and so the boundary — three color clocks later
;
; The per-iteration ledger (section 1 — exactly 76 cycles):
;   LDA ColorRamp,X        4       the line's hue (page-safe abs,X)
;   STA COLUBK             3       paint from HBLANK onward
;   31 x NOP              62       the budget filler (2 cycles each)
;   INX                    2
;   CPX #RAMP_LENGTH       2
;   BNE S1Loop             3       (taken; 2 on the exit iteration)
;   ------------------------------------------------
;   total                 76       (75 on the exit iteration)
;
;   Section 2 is identical with 34 NOPs (68 cycles of filler):
;   4 + 3 + 68 + 2 + 2 + 3 = 82 cycles per iteration.
;
; The section arithmetic (the ledger in full):
;   section 1: 2 (LDX) + 95 x 76 + 75 = 7,297 cycles = 96 lines + 1
;              cycle — the exit branch is 1 cycle cheaper than the loop
;              branch; padding cannot close a 1-cycle gap (no 1-cycle
;              instruction exists), so the ROM leaves it to land in
;              HBLANK, where it costs nothing
;   junction:  section 2's prologue starts immediately; its first write
;              still lands in HBLANK of the next line, so the boundary
;              between the sections is exact (no WSYNC needed)
;   section 2: 2 (LDX) + 95 x 82 + 81 = 7,873 cycles = 103.6 lines —
;              the ~8-line stretch, and the frame grows with it
;              (270 lines instead of 262)
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (267 — the grown frame), VblankStart (0), VblankPoll
;   (A = the INTIM value just read), VisibleStart (37), S1Tick (one hit
;   per line at a constant cycle — section 1 is aligned), Section2Start
;   (133 — the junction), S2Tick (96 hits per frame; consecutive hits
;   82 cycles apart, in-line position +6 per hit — the line advances 1,
;   or 2 where a write is skipped), OverscanStart (236), OverscanPoll
;   (A = the INTIM value just read).
;
; Build: acme -f plain -o build/lesson17.bin \
;        lessons/part2-tv-and-tia/17-cycle-counting/17-cycle-counting.asm
; Run:   stella build/lesson17.bin
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
; MAIN LOOP  —  one pass = one frame (this frame runs long: 270 lines)
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 267)
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

VblankWait:
    LDA INTIM               ; how much blanking is left?
VblankPoll:                 ; debugger checkpoint: A = the value just read
    BNE VblankWait          ; keep polling until it reads 0
    STA WSYNC               ; line up with the beam (parks the rest of the line)

    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
VisibleStart:               ; debugger checkpoint: the picture's first line (Stella: 37)
; -----------------------------------------------------------------------------
; SECTION 1 — the exactly-76-cycle loop, no WSYNC inside
;   alignment: the release + this prologue put every write in HBLANK;
;   the loop then rides the beam for 96 lines by cycle count alone.
; -----------------------------------------------------------------------------
    LDX #0                  ; ramp index = line counter (0..95)
S1Loop:
    LDA ColorRamp,X         ; 4 |  4    this line's hue (page-safe abs,X)
    STA COLUBK              ; 3 |  7    paint from HBLANK onward
S1Tick:                     ; debugger checkpoint: one hit per line, constant cycle
    ; --- budget filler: 62 cycles (31 x NOP, 2 cycles each) ---
    NOP                     ; 2 |  9
    NOP                     ; 2 | 11
    NOP                     ; 2 | 13
    NOP                     ; 2 | 15
    NOP                     ; 2 | 17
    NOP                     ; 2 | 19
    NOP                     ; 2 | 21
    NOP                     ; 2 | 23
    NOP                     ; 2 | 25
    NOP                     ; 2 | 27
    NOP                     ; 2 | 29
    NOP                     ; 2 | 31
    NOP                     ; 2 | 33
    NOP                     ; 2 | 35
    NOP                     ; 2 | 37
    NOP                     ; 2 | 39
    NOP                     ; 2 | 41
    NOP                     ; 2 | 43
    NOP                     ; 2 | 45
    NOP                     ; 2 | 47
    NOP                     ; 2 | 49
    NOP                     ; 2 | 51
    NOP                     ; 2 | 53
    NOP                     ; 2 | 55
    NOP                     ; 2 | 57
    NOP                     ; 2 | 59
    NOP                     ; 2 | 61
    NOP                     ; 2 | 63
    NOP                     ; 2 | 65
    NOP                     ; 2 | 67
    NOP                     ; 2 | 69
    INX                     ; 2 | 71
    CPX #RAMP_LENGTH        ; 2 | 73   96 lines — one ramp entry per line
    BNE S1Loop              ; 3 | 76   (2 on the exit — the loop's last branch)

; -----------------------------------------------------------------------------
; JUNCTION — no WSYNC: the exit's spare cycle chains into section 2's
; prologue, whose first write still lands in HBLANK of the next line.
; -----------------------------------------------------------------------------
Section2Start:              ; debugger checkpoint: the junction (Stella: 133)
    LDX #0                  ; same ramp index; section 2 restarts the hues
S2Loop:
    LDA ColorRamp,X         ; 4 |  4    same read, same page — no penalty
    STA COLUBK              ; 3 |  7    now 6 cycles later and drifting
S2Tick:                     ; debugger checkpoint: +6-cycle drift, one hit per iteration
    ; --- budget filler: 68 cycles (34 x NOP — 6 more than section 1) ---
    NOP                     ; 2 |  9
    NOP                     ; 2 | 11
    NOP                     ; 2 | 13
    NOP                     ; 2 | 15
    NOP                     ; 2 | 17
    NOP                     ; 2 | 19
    NOP                     ; 2 | 21
    NOP                     ; 2 | 23
    NOP                     ; 2 | 25
    NOP                     ; 2 | 27
    NOP                     ; 2 | 29
    NOP                     ; 2 | 31
    NOP                     ; 2 | 33
    NOP                     ; 2 | 35
    NOP                     ; 2 | 37
    NOP                     ; 2 | 39
    NOP                     ; 2 | 41
    NOP                     ; 2 | 43
    NOP                     ; 2 | 45
    NOP                     ; 2 | 47
    NOP                     ; 2 | 49
    NOP                     ; 2 | 51
    NOP                     ; 2 | 53
    NOP                     ; 2 | 55
    NOP                     ; 2 | 57
    NOP                     ; 2 | 59
    NOP                     ; 2 | 61
    NOP                     ; 2 | 63
    NOP                     ; 2 | 65
    NOP                     ; 2 | 67
    NOP                     ; 2 | 69
    NOP                     ; 2 | 71
    NOP                     ; 2 | 73
    NOP                     ; 2 | 75
    INX                     ; 2 | 77
    CPX #RAMP_LENGTH        ; 2 | 79
    BNE S2Loop              ; 3 | 82   (2 on the exit)

OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 236)
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
; COLOR RAMP — 96 bytes: the 16 hues at luminance 7, each repeated six times
;
; The table is page-aligned so that ColorRamp+X never crosses a page:
; an abs,X read that crosses a page boundary costs +1 cycle, which would
; silently break the 76-cycle ledger.
; =============================================================================
    !align 255, 0           ; the ramp stays inside one page (X reaches 95)
ColorRamp:
    !byte $0E,$0E,$0E,$0E,$0E,$0E    ; hue 0  — six lines
    !byte $1E,$1E,$1E,$1E,$1E,$1E    ; hue 1
    !byte $2E,$2E,$2E,$2E,$2E,$2E    ; hue 2
    !byte $3E,$3E,$3E,$3E,$3E,$3E    ; hue 3
    !byte $4E,$4E,$4E,$4E,$4E,$4E    ; hue 4
    !byte $5E,$5E,$5E,$5E,$5E,$5E    ; hue 5
    !byte $6E,$6E,$6E,$6E,$6E,$6E    ; hue 6
    !byte $7E,$7E,$7E,$7E,$7E,$7E    ; hue 7
    !byte $8E,$8E,$8E,$8E,$8E,$8E    ; hue 8
    !byte $9E,$9E,$9E,$9E,$9E,$9E    ; hue 9
    !byte $AE,$AE,$AE,$AE,$AE,$AE    ; hue 10
    !byte $BE,$BE,$BE,$BE,$BE,$BE    ; hue 11
    !byte $CE,$CE,$CE,$CE,$CE,$CE    ; hue 12
    !byte $DE,$DE,$DE,$DE,$DE,$DE    ; hue 13
    !byte $EE,$EE,$EE,$EE,$EE,$EE    ; hue 14
    !byte $FE,$FE,$FE,$FE,$FE,$FE    ; hue 15
RAMP_LENGTH = * - ColorRamp   ; 96 — one entry per visible line per section

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
> `lessons/part2-tv-and-tia/17-cycle-counting/17-cycle-counting.asm`.

### Code Walkthrough

#### Step 1 — The budget, ready to spend

Everything before `VisibleStart` is the Lesson 12–16 skeleton, unchanged: VSYNC's three counted lines, the VBLANK timer (44 ticks — exactly 37 lines, Lesson 15's correction), the `INTIM` poll, and the `WSYNC` that parks the CPU for the release. The loop that follows does not use the timer and does not use `WSYNC`; from here to the end of section 2 the CPU is spending the line itself.

#### Step 2 — The 76-cycle ledger, line by line

The loop, with the running total in every comment (this is the ledger, in the source):

```asm
S1Loop:
    LDA ColorRamp,X         ; 4 |  4    this line's hue (page-safe abs,X)
    STA COLUBK              ; 3 |  7    paint from HBLANK onward
S1Tick:                     ; checkpoint: one hit per line, constant cycle
    NOP (x31: 62 cycles)    ; 2 |  9 ... 2 | 69
    INX                     ; 2 | 71
    CPX #RAMP_LENGTH        ; 2 | 73
    BNE S1Loop              ; 3 | 76   (2 on the exit — the loop's last branch)
```

Every write completes inside HBLANK (the `S1Tick` checkpoint reads cycle 14 — the first cycle after the store) — so each line is painted wholly in its hue: `$0E` for six lines, `$1E` for six, on through `$FE`. The ramp table is page-aligned, so `LDA ColorRamp,X` is 4 cycles for every X — the page-crossing trap cannot fire.

#### Step 3 — The junction: one spare cycle, spent on purpose

Section 1's loop runs 95 iterations at 76 cycles plus the exit iteration at 75: 7,295. Add the prologue `LDX` (2) and the section occupies 7,297 cycles — one cycle *past* the 96-line mark (deliberately unpadded), so it ends one cycle *into* the 97th line-slot. No `WSYNC`: section 2's `LDX`/`LDA`/`STA` chain starts right there, and its first write still completes inside HBLANK. The section boundary is exact to the line, exactly as if the loop "knew" where the beam was. It didn't; the arithmetic did.

#### Step 4 — Section 2: the same loop, six cycles heavier

Section 2's loop is byte-for-byte the same shape with three extra `NOP`s (34 total, 68 cycles of filler): 82 cycles per iteration. The breakpoint `S2Tick` shows the drift directly — one hit per iteration (96 per frame), the in-line cycle marching `+6` each hit:

| Hit | Line | In-line cycle |
|---|---|---|
| 1 | 133 | 15 |
| 2 | 134 | 21 |
| 3 | 135 | 27 |
| … | … | +6 per hit |
| 96 | 235 | 53 |

At hue changes (every six iterations), the write's position within its line is far enough right to leave HBLANK, and the line shows a sliver of the outgoing hue before the new one. Since each hue change arrives 36 cycles further right, the sliver positions step — 535, 463, 391, 319, then a wrap to 967 — in captured-image pixels, measured in the capture and predicted exactly by the ledger (Section 4). The section ends after 96 iterations at line ~236, ~8 lines below where 96 iterations "should" end — and the frame, which has no `WSYNC` after the loops, is 270 lines total instead of 262.

#### Step 5 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **267, cycle 3** — the frame is 270 lines | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `VblankPoll` | `$F028` | **A = the INTIM just read** — 43 first, then 0 at (36, 35) | the VBLANK poll |
| `VisibleStart` | `$F030` | 37, cycle 5 | the picture's first line |
| `S1Tick` | `$F037` | 96 hits/frame: (37…132, cycle 14, pixel −26) — **constant**; A = the hue just written | section 1's tick — the count holding |
| `Section2Start` | `$F05B` | 133, cycle 6 (A = `$FE`, the last hue loaded) | the junction |
| `S2Tick` | `$F062` | 96 hits/frame: (133, 15), in-line cycle +6 per hit, last (235, 53); 96 hits span 103 lines | section 2's tick — the overrun |
| `OverscanStart` | `$F089` | 236, cycle 51 | overscan's first line |
| `OverscanPoll` | `$F095` | **A = the INTIM just read** — 35 first, then 0 at (266, 26) | the overscan poll |

## What You Should See

A tall picture in two regimes: the top half is sixteen perfectly flat bands — the 16 hues at luminance 7 in wheel order (`$0E` light gray, `$1E` gold, `$2E` orange, `$3E` peach, `$4E` red, `$5E` pink, … `$FE`), each six lines tall — and the bottom half is the same ramp with a twist: the bands are slightly taller (≈6.5 lines instead of six) and a dozen of the hue boundaries carry a visible notch, stepping left-to-right in a sawtooth, because those writes left HBLANK and repaint mid-line.

![Stella running the Lesson 17 ROM: 16 flat six-line hue bands on top; below, the same ramp drifting — taller bands with staircase notches at the boundaries](/images/lesson17/cycle-ruler.png)

*Captured from the ROM: section 1's 16 bands (each ≈19 px ≈ 6 lines, rows 107–408); section 2's stretched ramp (≈326 px ≈ 103.6 lines) with boundary notches measured at x = 535, 463, 391, 319, then wraparound steps at 967, 247, 895, 175, 823, 103, 751, 31 — each predicted by the ledger from the `S2Tick` hit cycles (51, 47, 43, 39, 75, 35, 71, 31, 67, 27, 63, 23) via x = 25 + (3·hit − 68)·6 (hit = the checkpoint's cycle — the first cycle after the store).*

<RomPlayer rom="/roms/part2-tv-and-tia/17-cycle-counting/17-cycle-counting.bin" title="Lesson 17 — Cycle Counting" />

The debugger writes the same story as numbers (values below as reported by Stella 7):

```bash
# assemble with a symbol list to get the checkpoint addresses
acme -f plain -l build/lesson17.sym -o build/lesson17.bin \
  lessons/part2-tv-and-tia/17-cycle-counting/17-cycle-counting.asm
grep -E "S1Tick|Section2Start|S2Tick|StartFrame" build/lesson17.sym

# then log one breakpoint per run
stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F037' \
  docs/public/roms/part2-tv-and-tia/17-cycle-counting/17-cycle-counting.bin
```

- **`$F037` (`S1Tick`)**: 96 hits per frame — one per line — every one at cycle 14: lines 37, 38, 39 … 132. Same in-line cycle, all 96 times: the 76-cycle ledger holding line after line. (This is also the two-line gap check: consecutive hits are 76 cycles apart.)
- **`$F05B` (`Section2Start`)**: exactly one hit per frame, at line 133, cycle 6, with A = `$FE` — the last byte the section-1 loop loaded. Section 2 begins there.
- **`$F062` (`S2Tick`)**: 96 hits, starting at (133, 15); each subsequent hit is 6 cycles later in its line, and the line advances by one — or by two where a write is skipped (seven times across the section). The last hit is (235, 53): 96 hits spread over 103 lines. Consecutive hits are **82 cycles apart** (76 + 6).
- **`$F00E` (`StartFrame`)**: fires at scanline 267 every frame — the only way a 270-line frame is visible in the debugger. Subtract the 3 VSYNC lines and you have the total: 270.

## Exercises

### Exercise 1: Count the Drill

**Challenge:** count the walkthrough drill by hand — the snippet from ["A Counting Drill"](#a-counting-drill) — then verify the count with a breakpoint.

**Hints:**
1. Break the count into three pieces: the prologue (`LDY #$0A`), the loop (ten iterations — how many have the branch taken?), and the back edge (`JMP Drill`).
2. `BNE` is 3 cycles taken, 2 not taken. Nine iterations take the branch; the tenth falls through.
3. The verification: breakpoint on `DrillLoop` (`$F010` in the solution). Every hit is a `DEY`; the gaps between consecutive hits are the loop's cost. You should see nine gaps of 5 cycles, then one of 9 (the exit, the `JMP`, and the next `LDY`), repeating — summing to the hand count.

**Expected Result:** one pass costs **54 cycles** (2 + 9×5 + 4 + 3); the breakpoint log prints the same number as gaps. The machine agrees with the hand.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Trim the Overrun

**Challenge:** make section 2 cost exactly 76 cycles per iteration like section 1 — and watch the drift disappear.

**Hints:**
1. Section 2 differs from section 1 by exactly three `NOP`s. Remove them (34 → 31) and the loop is 82 → 76 cycles.
2. On the evidence side, re-run the `S2Tick` breakpoint: the in-line cycle should now be **constant** on every line (cycle 15 in the solution, the junction's own one-cycle offset from section 1), and the last hit should be around line 228 — no stretch.
3. The frame should snap back to the textbook shape: `StartFrame` at scanline 259, 262 lines total. (Both sections still end one cycle "late" — and both spare cycles land in HBLANK where they cost nothing, so the standard frame absorbs the junction automatically.)

**Expected Result:** both sections are 96 lines of flat bands; the staircase is gone; `StartFrame` reports 259 — the frame is 262 lines again after the overrun is removed; measured: `S2Tick` hits stay at (line, cycle 15) for all 96 lines.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The Full Ledger *(Stretch Goal)*

**Challenge:** write the complete ledger for the kernel — every segment, every cycle — and verify two consecutive lines' cycle gap with state logs.

**Hints:**
1. The ledger has four parts: the frame skeleton (VSYNC 3 + VBLANK 37 + overscan 30), section 1 (prologue 2 + loop 7,295 = 7,297 = 96 lines + 1 cycle), the junction (the spare cycle, spent in HBLANK), and section 2 (prologue 2 + loop 7,871 = 7,873 ≈ 103.6 lines). The header of `exercise-03-solution.asm` is a worked example.
2. The two-line gap check: breakpoint `S1Tick` gives consecutive hits 76 cycles apart at the same in-line cycle; breakpoint `S2Tick` gives hits 82 cycles apart with the in-line cycle +6 per hit. To compare the numbers, remember the log's cycle column is *in-line*: add 76 per scanline.
3. `Section1End` and `Section2Start` share an address (`$F05B`) — the junction is exactly one point, which is the ledger's quiet punchline: section 1 has no "end padding" and section 2 no "start padding"; the count hands over mid-air and lands in HBLANK.

**Expected Result:** a complete ledger whose figures match every breakpoint (frame 270 lines; section 1 aligned for all 96 lines; junction exact; section 2 drift +6 per hit, 82-cycle gaps); two consecutive lines' gap verified at 76 (section 1) and 82 (section 2).

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A scanline is 76 CPU cycles** (228 color clocks ÷ 3). A loop costing exactly 76 cycles per iteration needs no `WSYNC` to ride the beam — the count is the alignment
- ✅ **Instruction costs, and the two traps**: the exit branch is 1 cycle cheaper than the loop branch (so a 96-iteration loop *as written* costs 96×76−1), and `abs,X` reads cost +1 when crossing a page. Both are invisible in the source and both break the budget silently
- ✅ **A write at or before cycle 22 is in HBLANK** — it repaints the whole visible line; later writes show the previous color up to color clock 3N, which is how overruns become visible slivers
- ✅ **Over-budget compounds**: +6 cycles per line × 96 iterations = 576 cycles ≈ 7.6 lines of stretch; each hue change pushes the write another +36 cycles (108 color clocks) to the right, so the notches walk and wrap across the section
- ✅ **Counted sections chain by cycles, not by `WSYNC`**: section 1's parity-bound spare cycle lands harmlessly in HBLANK, so the junction between the two loops is exact — `WSYNC` is the escape hatch, not the requirement
- ✅ **The ledger is the discipline**: every claim in this lesson (76/82-cycle loops, 96 aligned lines, junction at 133, frame at 270) is a number a breakpoint printed, and the staircase's twelve visible notches are each predicted from the `S2Tick` hit cycles
- ✅ **This is the heart of beam racing**: the beam never waits, and it never lies — every cycle you spend is visible somewhere on the screen

## What's Next

The budget is now explicit: 76 cycles a line, counted, with the two traps mapped. The next lesson spends it deliberately. [Lesson 18: Mid-Scanline Changes](/part2-tv-and-tia/18-mid-scanline-changes) stops moving the background *between* lines and starts moving it *within* one: `COLUBK` writes at chosen cycles paint vertical color columns, and a race between two timing states turns the same screen into an animation. The ruler taught you where the beam is at every cycle; Lesson 18 draws with it.
