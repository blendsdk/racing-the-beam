---
title: "Lesson 15: The Timer — RIOT Counts for You"
description: "The RIOT's interval timer counts CPU cycles in the background: write TIM64T, do real work, poll INTIM — the whole blanking window belongs to your code. Build 'time to think', a four-band picture whose colors are computed during VBLANK while the timer counts down, and learn why the classic 43/35 values run one line short — and why 44/36 hit the nominal 37/30 exactly."
prev:
  text: "Lesson 14: WSYNC and Timing"
  link: "/part2-tv-and-tia/14-wsync-and-timing"
next:
  text: "Lesson 16: Horizontal Zones"
  link: "/part2-tv-and-tia/16-horizontal-zones"
---

# Lesson 15: The Timer — RIOT Counts for You

> **Part 2: TV & TIA** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 12 (the counted frame — VSYNC, VBLANK, the visible 192, overscan), Lesson 14 (the WSYNC discipline and the line budget the timer replaces)
> **You will learn:** the 6532's interval timer — `TIM1T`/`TIM8T`/`TIM64T`/`T1024T` set both the count and the tick rate, and `INTIM` reads the countdown; how timer ticks map onto scanlines (one `TIM64T` tick = 64 cycles ≈ 0.84 lines); why this ROM's VBLANK value is 44 and its overscan value 36, and why the classic 43/35 in `include/macro.asm` run one line short; the freed time — one budget block instead of 37 individually-counted lines — and its single rule: finish before the timer reads zero
> **You will build:** "time to think" — the same 262-line frame, with both blanking periods counted by the RIOT and the freed CPU time spent computing the picture: four equal 48-line bands at hues (n, n+4, n+8, n+12) mod 16, luminance 7, where n advances by 1 every 30 frames (~0.5 s) — plus three exercises: converting the VBLANK from a WSYNC loop, computing the overscan value and moving a computation into it, and splitting the frame's work across both blanking windows with the ledger to prove each fits

## Introduction

For two lessons the invisible parts of the frame have been counted by hand. Every blanked line got its own `STA WSYNC`; the loop around it decremented and branched; the picture started when the count ran out. That discipline works — but it costs. The CPU spends the blanking parked in loops, and any real work has to be sliced to fit inside a single line's free cycles, line after line after line.

The 2600 carries a second clock that fixes this: the RIOT's **6532 interval timer**. It is an 8-bit counter that decrements itself — at 1, 8, 64, or 1024 CPU cycles per tick, your choice — completely in the background, while the CPU does whatever you want. You write a number to start it, you go do real work, and some time later you check whether it has reached zero. The blanking periods stop being line-by-line counts and become **budgets**: one block of thousands of cycles with a single deadline.

`15-the-timer.asm` is "time to think". Both blanking periods — the 37-line VBLANK and the 30-line overscan — are counted by `TIM64T` waits, and the cycles that frees up run a real computation: while the beam is blanked, the CPU builds the next frame's picture, four color bands whose hues step around the wheel twice a second. The animation is the visible proof that the work fits: if the computation overran its timer, the picture would start late and slip a line — so by watching the colors step in time, you are watching a budget being kept.

::: details TypeScript Equivalent
Waiting by counting and waiting by deadline are both familiar shapes in modern code; the 2600 has exactly these two:

```typescript
// WSYNC-loop waiting: the CPU is the clock, and it cannot leave the loop.
for (let line = 0; line < 37; line++) {
  await nextScanline();          // 37 separate waits, 37 separate budgets
}

// RIOT-timer waiting: start a countdown, then go do real work.
rioTimer.start(44);              // 44 ticks x 64 = 2816 cycles (2753 covered)
computeNextFrame();              // the freed time: ~150 cycles of real work
while (rioTimer.read() !== 0) {} // poll INTIM: is the deadline reached?
```

The second shape is the rest of this part's frame skeleton. The timer owns the blanking; the CPU owns the work in between.
:::

## Theory

### Section 1: The 6532's Interval Timer

The 6532 RAM-I/O-Timer sits beside the TIA and carries the machine's 128 bytes of RAM, the controller ports — and a timer. It is a single 8-bit counter, and it can decrement at four rates, one per register you write:

| Register | Address | Tick = | A full 255-tick count covers |
|---|---|---|---|
| `TIM1T` | `$0294` | 1 CPU cycle | 255 cycles ≈ 3.4 lines |
| `TIM8T` | `$0295` | 8 cycles | 2,040 cycles ≈ 26.8 lines |
| `TIM64T` | `$0296` | 64 cycles | 16,320 cycles ≈ 214.7 lines |
| `T1024T` | `$0297` | 1024 cycles | 261,120 cycles ≈ 3,435 lines |

For a 37-line VBLANK, only `TIM64T` fits: `TIM8T`'s 255-tick ceiling reaches barely 26 lines, and `TIM1T` just 3. (The course spells the last one `T1024T`; DASM-era sources often write `TIM1024T` — same register.)

Writing to one of those registers **loads the count and starts the countdown**: `LDA #44 / STA TIM64T` puts 44 in the counter and selects the 64-cycle tick. `LDA INTIM` reads the current value. When the counter reaches 0 it does not stop — it wraps to `$FF` and keeps counting down — so your code must catch the zero while it is there. That is easy: zero holds for a full tick (64 cycles), and a two-instruction poll checks every ~7 cycles, so it can never miss it.

One more behavior is the quiet star of this lesson: **the first tick arrives almost immediately.** The 6532 restarts its tick counter preloaded full on a write, so the first decrement lands one cycle after the write — not 64. You can watch it in the log: this ROM writes 44 to the VBLANK timer, and the first poll, a couple of hundred cycles later, already reads **41** — three ticks spent. That single fact is why the classic blanking values run a line short, as the next section shows.

### Section 2: Counting Lines in Ticks

One scanline is 76 CPU cycles; one `TIM64T` tick is 64 cycles — so a tick is about **0.84 lines**. A whole blanking period is therefore a small arithmetic problem: choose the largest tick count whose countdown still expires before the line where the beam must be released, then let a final `WSYNC` — the **anchor** from Lesson 14 — park the CPU until that line starts.

The VBLANK, counted from the first cycle of frame line 0:

| Step | Cycles |
|---|---|
| `STA TIM64T` writes 44 — the write cycle | 15 |
| first tick (+1), then 43 more every 64: last tick reaches 0 | 2,768 (line 36, cycle 32) |
| poll detects the zero (≤ 7 cycles) and exits | ≈ 2,775 |
| `STA WSYNC` parks the rest of line 36 | — |
| release runs at the start of line 37 | 2,812 |

Line 36 ends at 2,812; 44 ticks expire at 2,768 — comfortably inside. **45 ticks** would land their last tick at 2,832, in line 37 — the release slips a line late. So 44 is the largest safe count, and 37 lines is exactly what the timer covers. One counting note: `STA TIM64T` is an *absolute* store — 4 cycles, not zero-page 3 — so its write cycle is the fourth; every number in these tables counts from there.

The overscan, from the first cycle of its 30-line region:

| Step | Cycles |
|---|---|
| `STA TIM64T` writes 36 — the write cycle | 16 |
| first tick (+1), then 35 more: last tick reaches 0 | 2,257 (line 258, cycle 53) |
| poll exits, `STA WSYNC` parks the rest of line 258 | — |
| VSYNC runs at the start of line 259 | 2,280 |

2,264 cycles are left after the write; 36 ticks cover 2,241 of them. **37 ticks** would need 2,305 — a line late. So 36.

And the classic values? **43 and 35** — the ones `include/macro.asm` ships with, the ones in a thousand old kernels — cover one tick less: 2,689 and 2,177 cycles. Their releases land one line early: a 36-line VBLANK and a 29-line overscan, a 260-line frame. For most games that is invisible (one line of border), and the macro's own note already records the outcome — *"43 ticks x 64 = 2752 cycles ~ 36 scanlines"* — though its "use for 37-line VBLANK" is the classic convention this measurement refines: the parenthetical's 2,752 is the nominal product; the real coverage is one tick short, because the first tick lands one cycle after the write, not 64. This lesson wants the exact nominal frame — the course's 262 lines — so it writes **44** and **36**, and the walkthrough derives why. That one-tick correction, and the reason for it, is the pitfall this lesson exists to teach.

### Section 3: The Freed Time

What does the timer actually buy? Compare the two ways to blank 37 lines:

- **The WSYNC loop** spends 8 cycles per line on overhead (WSYNC 3 + DEX 2 + BNE 3) = 296 cycles, and the CPU's free time arrives in 37 separate slices of at most ~65 cycles each. Any computation must be chopped into per-line pieces, and every piece must be counted.
- **The timer** spends one ~7-cycle poll per check. The CPU's free time is one straight block of up to ~2,750 cycles (VBLANK) or ~2,240 (overscan), with one rule: **finish before the timer reads zero.**

That rule has a visible failure mode. If the work overran the window, the poll would read zero immediately — no waiting — and the anchor would park whatever line the CPU happened to be in, releasing the beam a line or more late. The picture would start low and the frame would drift against VSYNC. So the animation stepping in time *is* the budget being kept — and the debugger makes it explicit: the first poll read (41 of 44) tells you how much of the window is still left when the work finishes.

::: details TypeScript Equivalent
The deadline pattern, one-to-one:

```typescript
rioTimer.start(44);            // the window opens
computeTheFrame();             // must fit: ~150 cycles of ~2,750 available
if (rioTimer.read() === 0) {
  // overrun: the picture starts late — a scanline of visible drift
}
```

Nothing here is 2600-specific except the units. A frame budget, a deadline, a poll — the pattern powers animation loops everywhere; the TIA just makes an overrun visible on a CRT.
:::

### Section 4: The Picture, and the Clock That Proves It

The computation the timer pays for is small and legible: four equal 48-line bands, each a solid color, at hues

```
(n, n+4, n+8, n+12) mod 16     all at luminance 7
```

with **n advancing by 1 every 30 frames** (~0.5 s). At n = 0 the bands are the named-color table's landmarks — light gray, red, blue, green; each half-second the whole picture steps one hue around the wheel, and after eight seconds it has cycled all the way around.

The visible kernel itself adds nothing new: it is Lesson 12–14's paint loop — `STA WSYNC`, write `COLUBK`, count — with one anchor between bands to park each band's last line, exactly like Lesson 14's boundary anchor. The timer freed the blanking; the visible part still obeys the beam.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson15.bin \
  lessons/part2-tv-and-tia/15-the-timer/15-the-timer.asm
stella build/lesson15.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`, all in the same directory.

### Full Source

The frame skeleton is Lesson 12's — VSYNC 3, visible 192 — with the two blanked periods handed to the RIOT. `include/macro.asm` ships `+set_timer` / `+wait_timer` helpers with the classic values; this lesson writes the timer explicitly so every cycle stays visible, and uses the corrected 44/36.

```asm
; =============================================================================
; LESSON 15: The Timer — RIOT Counts for You
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   "Time to think": the frame's two blanking periods are counted by the
;   RIOT's interval timer instead of by WSYNC loops, and the cycles that
;   frees up are spent computing the picture while the beam is blanked.
;
;     - VSYNC: 3 lines, counted with WSYNC (the pulse must be exact).
;     - VBLANK: TIM64T = 44 (exactly 37 lines).  During the countdown
;       the CPU advances the hue clock and precomputes the four band
;       colors for this frame; then it polls INTIM until it reads 0.
;     - Visible: 192 lines = four equal 48-line bands, painted from the
;       precomputed colors (per-line writes, anchored by WSYNC).
;     - Overscan: TIM64T = 36 (exactly 30 lines), polled the same way.
;
;   The picture: four bands at hues (n, n+4, n+8, n+12) mod 16, all at
;   luminance 7 (byte low nibble $E).  n starts at 0 and advances by 1
;   every 30 frames (~0.5 s) — the whole picture shifts one hue step at
;   a time, all four bands in step.
;
; What you'll learn:
;   - the 6532's interval timer: TIM1T / TIM8T / TIM64T / T1024T set the
;     count; INTIM reads it; one tick = 1, 8, 64, or 1024 CPU cycles
;   - counting whole TV lines in timer ticks (64 cycles ~ 0.84 lines)
;   - why VBLANK's value is 44 and overscan's is 36 — and why the
;     timer's first tick comes one cycle early (the classic 43/35 in
;     include/macro.asm run a line short)
;   - the freed time: thousands of consecutive cycles for real work,
;     with a single rule — finish before the timer reaches zero
;   - the visible proof: the picture animates correctly only because the
;     compute fits inside the blanking budget
;
; The VBLANK ledger (cycles counted from the start of frame line 0):
;   STA TIM64T writes at cycle 15     (timer = 44)
;   the first decrement lands one cycle after the write — the prescaler
;   restarts full, so a fresh timer ticks almost immediately — and then
;   every 64 cycles
;   compute (hue clock + 4 colors)    ~150 cycles, done before cycle 180
;   first poll reads INTIM = 41       (still counting: the work fits)
;   the last tick (0) lands at cycle 2768   (line 36, cycle 32)
;   poll exits, WSYNC parks the rest of line 36
;   release runs at line 37           -> exactly 37 lines
;   why 44: 1 + 43 x 64 = 2753 cycles after the write — inside line 36,
;   which ends at cycle 2812; 45 ticks would tick 64 cycles later, into
;   line 37 — one line late.
;   (43, the classic value, covers one tick less: the release would land
;   at line 36 — 36 lines.  include/macro.asm's note records the outcome
;   — "43 ticks x 64 = 2752 cycles ~ 36 scanlines" — while its "use for
;   37-line VBLANK" is the classic convention this ledger refines: 44 is
;   what makes the period actually 37 lines.)
;
; The overscan ledger (cycles from the start of frame line 229):
;   STA TIM64T writes at cycle 16     (timer = 36)
;   first decrement one cycle later, then every 64:
;   the last tick (0) lands at cycle 2257   (line 258, cycle 53)
;   poll exits, WSYNC parks the rest of line 258
;   VSYNC starts at line 259          -> exactly 30 lines
;   why 36: 1 + 35 x 64 = 2241 cycles after the write — inside line 258
;   (2264 cycles remain after the write); 37 would overshoot into
;   line 259 — one line late.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VblankCompute (A = the value
;   just written to TIM64T), HueStep, VblankPoll (A = the INTIM value
;   just read), VisibleStart (37), BandWrite, OverscanStart (229),
;   OverscanPoll (A = the INTIM value just read).
;
; Build: acme -f plain -o build/lesson15.bin \
;        lessons/part2-tv-and-tia/15-the-timer/15-the-timer.asm
; Run:   stella build/lesson15.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame, the timer budgets, and the hue clock
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (see the ledger)
BAND_LINES     = 48     ; each of the four bands' height
BANDS          = 4      ; bands across the visible 192 lines
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (see the ledger)
STEP_FRAMES    = 30     ; the hue advances every 30 frames (~0.5 s)
LUMINANCE_7    = $0E    ; luminance nibble: level 7 = %1110 (bit 0 unused)

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
HueBase     = $80       ; n: the top band's hue (0-15), stepped every 30 frames
StepCounter = $81       ; frames until the next hue step: 30 -> 0
Temp        = $82       ; scratch: keeps the running hue in the color builder
BandColors  = $83       ; 4 bytes: precomputed colors for the four bands

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    LDA #$00
    STA HueBase             ; n = 0: the first picture's hues are 0, 4, 8, 12
    LDA #STEP_FRAMES
    STA StepCounter

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

VblankCompute:              ; debugger checkpoint: A = the timer value just written
; --- the freed time: advance the hue clock, then precompute the picture ---
    DEC StepCounter
    BNE NoStep
    LDA #STEP_FRAMES
    STA StepCounter
    LDA HueBase
    CLC
    ADC #1
    AND #$0F                ; hues wrap 15 -> 0
HueStep:                    ; debugger checkpoint: fires every 30 frames, A = new n
    STA HueBase
NoStep:
    ; --- precompute the four band colors for this frame ---
    LDA HueBase
    LDX #0
ComputeLoop:
    STA Temp                ; keep the running hue
    AND #$0F                ; mod 16 (n + 4k can pass 15)
    ASL                     ; build the byte: %HHHHLLL0
    ASL
    ASL
    ASL                     ; hue << 4
    ORA #LUMINANCE_7        ; luminance 7 = %1110
    STA BandColors,X        ; the band's color, ready for the kernel
    LDA Temp
    CLC
    ADC #4                  ; the next band is four hues around the wheel
    INX
    CPX #BANDS
    BNE ComputeLoop

    ; --- wait out the rest of the countdown ---
VblankWait:
    LDA INTIM               ; how much blanking is left?
VblankPoll:                 ; debugger checkpoint: A = the value just read
    BNE VblankWait          ; keep polling until it reads 0
    STA WSYNC               ; line up with the beam (parks the rest of the line)

    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
VisibleStart:               ; debugger checkpoint: the picture's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — four equal 48-line bands, painted from the precomputed colors
; -----------------------------------------------------------------------------
    LDX #0                  ; band 0
BandBegin:
    LDA BandColors,X        ; this band's precomputed color
    STA COLUBK              ; its first line, in HBLANK
    LDY #BAND_LINES-1       ; 47 more lines complete the band's 48
BandLines:
    STA WSYNC               ; wait for the next line to start
BandWrite:                  ; debugger checkpoint: one hit per line, in HBLANK
    STA COLUBK              ; repaint (the store lands at line-cycle 2)
    DEY
    BNE BandLines
    STA WSYNC               ; anchor: park out the band's last line
    INX
    CPX #BANDS
    BNE BandBegin

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
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

> The complete, fully-commented source lives in
> `lessons/part2-tv-and-tia/15-the-timer/15-the-timer.asm`.

### Code Walkthrough

#### Step 1 — The frame, and where the timers sit

The frame keeps its shape: 3 lines of VSYNC (still counted with `WSYNC` — the pulse must start and end on exact lines), then the VBLANK timer, 192 visible lines, the overscan timer, and back to VSYNC: 262 lines, the course standard. The VSYNC block and the visible kernel are unchanged from Lessons 12–14; the two `LDX #37`-style loops are what disappear.

#### Step 2 — VBLANK: write the timer, compute, then poll

```asm
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDA #VBLANK_TIMER       ; 44
    STA TIM64T              ; start the countdown: 44 ticks
```

That is the whole wait — except that the CPU now owns the next ~2,750 cycles. This ROM spends about 150 of them computing the upcoming picture. First the hue clock: a 30-frame countdown that steps `HueBase` by 1 (wrapping 15 → 0). Then the color builder — one small loop that walks the four bands, four hues apart, constructing each byte as `hue << 4 | luminance`:

```asm
ComputeLoop:
    STA Temp                ; keep the running hue
    AND #$0F                ; mod 16 (n + 4k can pass 15)
    ASL                     ; build the byte: %HHHHLLL0
    ASL
    ASL
    ASL                     ; hue << 4
    ORA #LUMINANCE_7        ; luminance 7 = %1110
    STA BandColors,X        ; the band's color, ready for the kernel
```

The loop costs 33 cycles per band (plus the clock's ~25 on step frames), which is why the compute costs almost nothing against the window. Then the check:

```asm
VblankWait:
    LDA INTIM               ; how much blanking is left?
VblankPoll:
    BNE VblankWait          ; keep polling until it reads 0
    STA WSYNC               ; line up with the beam
```

The poll runs ~7 cycles per check; the timer's zero holds for 64 cycles, so it can never be missed. When the zero is read, the anchor `WSYNC` parks the rest of line 36 and the release code runs at the start of line 37 — exactly 37 blanked lines, with the compute already done.

#### Step 3 — The visible bands

The kernel is the familiar one, with a band index and an anchor between bands:

```asm
BandBegin:
    LDA BandColors,X        ; this band's precomputed color
    STA COLUBK              ; its first line, in HBLANK
    LDY #BAND_LINES-1       ; 47 more lines complete the band's 48
BandLines:
    STA WSYNC
BandWrite:
    STA COLUBK              ; repaint (the store lands at line-cycle 2)
    DEY
    BNE BandLines
    STA WSYNC               ; anchor: park out the band's last line
    INX
    CPX #BANDS
    BNE BandBegin
```

The release line counts as band 0's first line, so band 0 runs 47 loop passes and the other three add an anchored first line each — 48 × 4 = 192. The per-line writes use the zero-page `STA COLUBK`, land at line-cycle 2 (deep in HBLANK, as Lesson 14's `DEY` checkpoint verified), and the anchors keep every band boundary on an exact line.

#### Step 4 — Overscan: the other window

```asm
    LDA #$02
    STA VBLANK
    LDA #OVERSCAN_TIMER     ; 36
    STA TIM64T
OverscanWait:
    LDA INTIM
OverscanPoll:
    BNE OverscanWait
    STA WSYNC               ; line up for VSYNC's first line
    JMP StartFrame
```

Same shape, smaller window. This ROM leaves the overscan purely as a wait — the freed time is there for the taking, and Exercise 2 does exactly that.

#### Step 5 — The two ledgers, and why 44 and 36

The full arithmetic, as derived in Theory 2:

| Window | Lines | Cycles | Write at | Largest safe ticks | Last tick | Release |
|---|---|---|---|---|---|---|
| VBLANK | 37 | 2,812 | cycle 15 | **44** (2,753 covered) | cycle 2,768 — line 36 | line 37 |
| Overscan | 30 | 2,280 | cycle 16 | **36** (2,241 covered) | cycle 2,257 — line 258 | line 259 |

| Ticks | Result |
|---|---|
| 43 | last tick at 2,704 — line 35; release one line early (36-line VBLANK) |
| 44 | last tick at 2,768 — line 36; release at line 37 ✔ |
| 45 | last tick at 2,832 — line 37; release one line late |

The same table shifted by the window covers the overscan (35 → 29 lines, 36 → 30 ✔, 37 → 31, late). The classic values are the "one tick less" row of each table; this ROM takes the exact row.

#### Step 6 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F016` | 259, cycle 3 | VSYNC's first line |
| `VblankStart` | `$F024` | 0, cycle 5 | VBLANK's first line |
| `VblankCompute` | `$F02D` | line 0, cycle 16 — **A = 44** | the freed-time block begins; A still holds the timer value just written |
| `HueStep` | `$F03C` | frames 30, 60, 90, … — **A = the new n** | the hue clock ticks (Δ30 frames ≈ 0.5 s) |
| `VblankPoll` | `$F05B` | **A = the INTIM value just read** — 41 first, then 40, 39, … to 0 at line 36, cycle ≈ 39 | the VBLANK poll |
| `VisibleStart` | `$F063` | 37, cycle 5 | the picture's first line |
| `BandWrite` | `$F06D` | one hit per line — cycle 11 / pixel −35 (the anchor-hold position, exactly as in Lesson 14); a band's entry line logs a few cycles later | the per-line band write |
| `OverscanStart` | `$F079` | 229, cycle 6 | overscan's first line |
| `OverscanWait` | `$F082` | first hit each frame — **A = 36** | the written timer value, still in A |
| `OverscanPoll` | `$F085` | **A = the INTIM just read** — 35 first, … to 0 at line 258 | the overscan poll |

## What You Should See

A stable four-band picture — equal halves of color stacked four high, 48 lines each — and, about twice a second, the whole picture steps: every band shifts one hue around the wheel while keeping its neighbors four hues away. Since the step applies to all four bands at once, it reads as one calm color rotation, cycling the full wheel every eight seconds. Nothing tears, nothing moves, and the frame around the picture keeps the exact shape of Lesson 12: 259/0/37/229.

![Stella running the Lesson 15 ROM: four equal color bands — light blue, bright yellow-green, gold, pink — stacked down the screen](/images/lesson15/timer-frame.png)

*Captured mid-rotation at n = 9: the bands are hues 9, 13, 1 and 5 at luminance 7 — `$9E`, `$DE`, `$1E`, `$5E`, the named-color table's light blue, bright yellow-green, gold and pink. A capture taken one second later shows n = 11: teal-green, yellow, peach, violet — the picture has stepped twice, exactly on the half-second cadence.*

<RomPlayer rom="/roms/part2-tv-and-tia/15-the-timer/15-the-timer.bin" title="Lesson 15 — The Timer" />

The debugger tells the same story as numbers (values below as reported by Stella 7):

```bash
# assemble with a symbol list to get the checkpoint addresses
acme -f plain -l build/lesson15.sym -o build/lesson15.bin \
  lessons/part2-tv-and-tia/15-the-timer/15-the-timer.asm
grep -E "VblankCompute|HueStep|VblankPoll" build/lesson15.sym

# then log one breakpoint per run
stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F05B' \
  docs/public/roms/part2-tv-and-tia/15-the-timer/15-the-timer.bin
```

- **`$F02D` (`VblankCompute`)**: A = 44 — the register still holds the value the `STA TIM64T` wrote a few cycles earlier. The same breakpoint shows the compute's position: line 0, cycle 16.
- **`$F05B` (`VblankPoll`)**: every hit logs the value just read from `INTIM` in A: 41 on the first read — three ticks spent by the compute, forty-one still counting — then 40, 39, 38, … and a final 0 at line 36, cycle ≈ 39. The first read being well above zero *is* the proof that the work fits; a zero there would mean the computation had overrun.
- **`$F03C` (`HueStep`)**: fires on frames 30, 60, 90, 120 — Δ30 frames, half a second — with A = the band's new base hue: 1, 2, 3, 4.
- **`$F082` (`OverscanWait`)**: the first hit of each frame reads A = 36 — the overscan timer value, just written.
- **`$F06D` (`BandWrite`)**: one hit per line, the same HBLANK position on every line, with the band-entering lines a few cycles later — the visible kernel's steady rhythm, undisturbed by any of the timing work.

## Exercises

### Exercise 1: Convert the VBLANK (WSYNC Loop → Timer)

**Challenge:** take Lesson 12's 37-iteration WSYNC loop out of the VBLANK and replace it with a `TIM64T` wait — then show the freed time.

**Hints:**
1. The loop version costs 8 cycles of overhead per line and hands you the CPU's free time in 37 separate slices of at most ~65 cycles. The timer version hands you one block of ~2,750.
2. The value that expires inside line 36 is **44** (43 — the classic — lands the release a line early, at 36 lines; 45 slips a line late).
3. Keep the anchor `WSYNC` after the poll: the timer only needs to expire *before* line 36 ends — the anchor does the line-exact part.

**Expected Result:** the identical picture and frame (259/0/37/229); the compute now runs in one block; the first poll reads 41; `VblankCompute` reads A = 44.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: The Overscan Value, and a Moved Computation

**Challenge:** compute the overscan timer value yourself, and move one computation out of the VBLANK into the newly-freed overscan window.

**Hints:**
1. The overscan is 30 lines = 2,280 cycles; the write lands at cycle 15, so 2,265 cycles remain. Ticks: 1 + 64 × (t − 1) cycles; solve for the largest t that fits: **36** (35 — the classic — covers 2,177, a line short; 37 needs 2,305, a line late).
2. The hue clock is a natural candidate to move: it is small (~24 cycles on step frames) and it belongs *after* the frame it applied to — the overscan is the natural "end of frame" moment.
3. Moving it shifts the animation by one frame (frame 31 shows n = 1 instead of frame 30) — a phase change no eye can catch, and a good example of the freedom the timer windows give you.

**Expected Result:** the same picture and cadence, now with the step in the overscan: `OverscanCompute` reads A = 36, `HueStep` fires in the overscan (frames 30, 60, …), the first overscan poll reads 35, and the VBLANK's first poll still reads 41.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Split the Work, Prove Both Windows *(Stretch Goal)*

**Challenge:** split the per-frame work across both blanking windows and prove with the ledger that each fits.

**Hints:**
1. The natural split is two bands per window: the VBLANK keeps the hue clock plus bands 0–1 (about 110 cycles); the overscan takes bands 2–3 (about 89).
2. Factor the color builder into a subroutine — `ComputeBand` takes the hue in A and the index in X, stores the byte, and returns with both advanced. Four calls per frame, two per window.
3. The proof is the first poll of each window: VBLANK should read ≈ 42 (it spends ~110 cycles), overscan ≈ 34 (two ticks pass during its compute). A zero on either first read would mean that window's work overran.

**Expected Result:** the same four-band picture; `VblankCompute` A = 44, `OverscanCompute` A = 36; first polls 42 and 34 — both thousands of cycles from zero.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **The 6532 timer counts cycles in the background:** `TIM1T`/`TIM8T`/`TIM64T`/`T1024T` write the count and pick the tick rate (1/8/64/1024 cycles); `INTIM` reads it; the zero holds for a full tick, so a tight poll can never miss it
- ✅ **One `TIM64T` tick ≈ 0.84 lines** — and the first tick lands one cycle after the write (the prescaler restarts full), which is why the classic blanking values run one line short
- ✅ **The exact values for the nominal periods are 44 (37 lines) and 36 (30 lines)** — the largest counts that still expire before their anchor line; the release is line-exact because the anchor parks whatever is left of the last blank line
- ✅ **The freed time is a budget block, not a count:** ~2,750 cycles (VBLANK) and ~2,240 (overscan) with one rule — finish before zero
- ✅ **The first poll read is the overrun check:** > 0 means the work fit; 0 means the picture will start late
- ✅ **The timer owns the blanking; the beam still owns the picture.** The visible kernel is unchanged — per-line WSYNC writes and anchors — because the timer cannot draw, only wait
- ✅ **The frame never changes shape:** 259/0/37/229, 262 lines — swapping 37 counted lines for a timer disturbed nothing

## What's Next

The timer now handles the frame's vertical blanks — but the visible 192 lines are still four bands whose layout is hard-wired, and every real 2600 game needs the screen to change as the beam travels down it. [Lesson 16: Horizontal Zones](/part2-tv-and-tia/16-horizontal-zones) keeps this frame skeleton and starts cutting the picture into zones — different colors, different objects, each zone with its own line budget, all of it timed by the counts and timers you now have in your toolbox.
