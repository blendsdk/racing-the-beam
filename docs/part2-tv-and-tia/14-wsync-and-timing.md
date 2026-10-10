---
title: "Lesson 14: WSYNC and Timing — Synchronizing with the Beam"
description: "The scanline is 76 CPU cycles: ~23 invisible ones (HBLANK) and the 160 visible pixels. WSYNC anchors your code to the line, but only HBLANK hides a write — miss it and the line tears. Build the anchored split: a red/blue picture drawn two ways, clean and torn, alternating every two seconds, with the full cycle ledger for both."
prev:
  text: "Lesson 13: Colors"
  link: "/part2-tv-and-tia/13-colors"
next:
  text: "Lesson 15: The Timer"
  link: "/part2-tv-and-tia/15-the-timer"
---

# Lesson 14: WSYNC and Timing — Synchronizing with the Beam

> **Part 2: TV & TIA** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 12 (the counted frame — VSYNC, VBLANK, the visible 192, and HBLANK), Lesson 13 (the color writes this lesson places)
> **You will learn:** the 76-cycle scanline in CPU terms — 68 color clocks of HBLANK (~23 cycles) and 160 clocks of picture (~53 cycles); what `STA WSYNC` actually waits for; why a write that lands after HBLANK tears the line it lands on, and why a fixed late write tears the same spot every frame; the discipline "finish your line's work in the line" — with the cycle arithmetic to back it
> **You will build:** the "anchored split" ROM — a 96/96 red/blue picture drawn in two modes that alternate every two seconds: an *aligned* mode whose boundary write lands in HBLANK (a clean edge), and a *late* mode whose boundary write lands ~24 CPU cycles into the visible portion (a static tear through 76 of the line's 160 pixels) — plus three exercises: moving the split with one constant, repairing the late mode's budget, and checking the repaired budget with two state-log breakpoints

## Introduction

Every write you have made in this part has landed *somewhere*, and the picture has been kind about it. Since Lesson 04 the course has followed a quiet contract: write to the TIA right after a `WSYNC`, keep the writes short, and the screen behaves. This lesson opens the contract and reads the fine print — because that contract is where the 2600's most famous constraint comes from: the machine has no frame buffer.

The TIA has no memory of a picture. There is only the beam, sweeping 262 lines, sixty times a second — and whatever value a register holds at the exact instant the beam passes a pixel is what that pixel shows. A write is not stored and composited later; it takes effect at the color clock where it happens. That is why `WSYNC` exists at all, and why its exact behavior — not its reputation — is worth knowing before any later part's kernel gets more ambitious.

`14-wsync-and-timing.asm` makes the fine print visible. It draws the simplest possible picture — red on top, blue below, split down the middle — *twice*: once with the boundary write anchored so it lands in the invisible part of the line (a clean edge), and once with the same write deliberately late (the boundary line tears: its first 76 of 160 pixels stay red). Every two seconds the ROM flips between the two modes. By the end you can predict both pictures cycle by cycle — and read the same story back in the debugger.

::: details TypeScript Equivalent
On the web, the compositor guarantees you never see a half-updated frame: draw to an offscreen buffer, swap it atomically, and no one sees the seams. The 2600 has no compositor and no buffer — the beam *is* the compositor, and it is always mid-frame:

```typescript
// What the beam does, 228 times per line:
for (let clock = 0; clock < 228; clock++) {
  screen[scanline][clock] = currentColor;   // the register, at this exact instant
}
// A write that lands at clock 144 changes pixel 76 of that line —
// and nothing can undo the 76 pixels already painted with the old value.
```

That is the whole timing problem in one loop. Every technique in this part — bands, zones, mid-line changes — is a way of choosing *when* the beam sees each value.
:::

## Theory

### Section 1: The 76-Cycle Line

A scanline lasts **228 color clocks**, and one CPU cycle is exactly **3 color clocks** — so the line is **76 CPU cycles** long, and it has two regions:

| Region | Color clocks | CPU cycles | What it is |
|---|---|---|---|
| HBLANK | 0–67 (68 clocks) | ~0–22.7 (≈23 cycles) | blanked — the beam is off the visible area; writes here are invisible |
| Visible | 68–227 (160 clocks) | ~22.7–76 (≈53 cycles) | the 160 pixels of picture |

Every cycle of your program after a `WSYNC` is spent somewhere on this ruler, and the picture only cares about *writes*. A write at clock 30 is never seen. A write at clock 144 changes the picture at pixel 76 of that line — permanently, because the beam has already moved on by the time you could change anything. There is no undo, no compositing pass, no next-frame correction: the beam is the frame buffer.

### Section 2: What WSYNC Really Waits For

`STA WSYNC` — three cycles, one write to the TIA's WSYNC register — does something specific: the write pulls the CPU's **RDY** line low, and the 6507 parks. It stays parked until the TIA's horizontal counter wraps — the moment the next scanline begins — and then the CPU continues with the next instruction at that line's first cycle.

So `WSYNC` is not "wait a while." It is "wait for the next line, *exactly*." A write immediately after it lands in HBLANK — the ~23-cycle window — every single line, at the same spot, forever. That is the anchor every kernel loop since Lesson 12 has been using, and it is why the loop bodies in this course look the way they do: `STA WSYNC` first, then the work.

And the anchor comes with a deadline: **~23 cycles**. Whatever must be true of the picture in a line has to be written inside HBLANK. Anything later than that does not wait politely for the next opportunity — it lands wherever the beam happens to be.

### Section 3: The Torn Line

A write that lands in the visible portion changes the picture *mid-line*. Pixels before the write keep the old value; pixels after it use the new one. The result is a tear on exactly one line — and its character depends on your code:

- **Fixed late work → a static tear.** If the work between the anchor and the write takes the same number of cycles every frame, the tear sits at the same pixel, identically, forever. It looks like a scar on the picture. This lesson's late mode is exactly that.
- **Varying late work → a moving tear.** If the work's length depends on the frame (game state, sprite counts, an `if` that sometimes does more), the tear slides up and down the line, frame to frame — the shimmer and wobble real games show when their kernels overflow a line. That movement is the visible face of a budget problem; Lesson 17 (name-only, for now) walks through counting those cycles.

Either way the cause is the same: work that needed to happen before the deadline, happening after it.

### Section 4: The Anchored Split — and the Discipline

The companion ROM stretches this to the breaking point with the simplest picture it can: **red above, blue below, split at the middle** — the boundary on visible line 97 (the course numbers the picture's 192 lines from 1, so visible line 97 is frame scanline 133). It draws the split in two modes and alternates them every ~120 frames (~2 seconds):

- **Aligned mode:** after the top half is painted, the CPU takes a fresh `WSYNC` anchor, then writes the boundary color immediately. The store goes out in HBLANK; visible line 97 is *entirely* blue. A clean edge.
- **Late mode:** after the same anchor, the kernel does **38 cycles of extra work first** — a short routine representing any real kernel work (state updates, sprite math) — and only then writes the boundary color. The store lands ~24 CPU cycles into the visible portion. Visible line 97 paints red for its first 76 pixels, then blue: a static tear, identical every frame.

The late mode is not an accident; it is a demonstration. And the fix — the discipline this lesson is really teaching — is **ordering**, not speed:

> Finish your line's work *before* the line you need the result on.

The previous line has almost its whole 76-cycle budget free (its picture is already drawn), so expensive work costs nothing visible there. After the anchor, only ~23 cycles exist — and the write you actually need on screen should be first in line. Exercise 2 makes this concrete by repairing the late mode without deleting the work.

::: details TypeScript Equivalent
The same deadline arithmetic drives animation code on any raw device: work done before the frame's draw deadline is free; work done after it shows up in the frame.

```typescript
function line() {
  const hblank = 23;            // cycles before the picture starts
  doExpensiveWork();            // safe ONLY if done in the previous line
  colubk = newColor;            // must land within hblank
}
// Overrun by 24 cycles and the write lands 76 pixels into the picture:
// a half-red, half-blue scanline, once per frame.
```

Browsers hide this with buffering; the TIA cannot. Knowing the deadline — and moving work across it on purpose — is the whole job.
:::

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson14.bin \
  lessons/part2-tv-and-tia/14-wsync-and-timing/14-wsync-and-timing.asm
stella build/lesson14.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`, all in the same directory.

### Full Source

The frame is Lesson 12's, unchanged — VSYNC 3, VBLANK 37, visible 192, overscan 30. What is new is a 120-frame mode clock (Lesson 13's countdown pattern), two anchored per-line loops, and a boundary whose two paths differ by 38 cycles — enough to move a write from HBLANK into the picture.

```asm
; =============================================================================
; LESSON 14: WSYNC and Timing — Synchronizing with the Beam
; =============================================================================
; Part 2: TV & TIA
;
; What this program does:
;   The "anchored split": the picture is two equal halves — red ($42) on
;   top, blue ($84) below — with the color boundary sitting on the middle
;   line (visible line 97).  The ROM draws it TWO ways, alternating the
;   mode every 120 frames (~2 seconds):
;
;     - aligned mode:  the boundary color is written right after a WSYNC
;       anchor, so the write lands in HBLANK (the line's first ~23 CPU
;       cycles) and the boundary line is entirely blue: a clean edge.
;
;     - late mode:     the boundary color write is deliberately late — a
;       short delay routine runs AFTER the anchor, so the write lands
;       about 24 CPU cycles into the visible portion.  The boundary
;       line paints red for its first 76 of 160 pixels, then blue:
;       a static tear, identical every frame.
;
;   Every per-line write in both modes is anchored by WSYNC and lands in
;   HBLANK; the only difference is what happens after the boundary's
;   anchor.  That is the lesson: WSYNC pins your code to the line, and
;   HBLANK is the ~23-cycle window where a write is invisible.
;
; What you'll learn:
;   - the 76-cycle scanline: 68 color clocks of HBLANK + 160 visible
;     (3 color clocks per CPU cycle)
;   - what WSYNC actually waits for: the END of the current line
;   - why a write that misses HBLANK tears the line it lands on
;   - why fixed late work gives a STATIC tear, and varying work moves it
;     (the movement real games show — Lesson 17 counts those cycles)
;   - the discipline: finish your line's work in the line
;
; The boundary ledgers (cycles counted from the anchor that starts visible line 97):
;   aligned: LDA Mode 3 + BEQ 3 (taken) + LDA #$84 2 + STA COLUBK 3
;            -> store at cycle 10, still in HBLANK (pixel -38)
;   late:    LDA Mode 3 + BEQ 2 + JSR 6 + delay loop 26 + RTS 6 +
;            LDA #$84 2 + STA COLUBK 3
;            -> store at cycle 47: ~24 CPU cycles into the visible
;               portion — the boundary line paints red for its first
;               76 of 160 pixels, then blue
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VisibleStart (37),
;   TopWrite, BoundaryWrite, BottomWrite, OverscanStart (229).
;
; Build: acme -f plain -o build/lesson14.bin \
;        lessons/part2-tv-and-tia/14-wsync-and-timing/14-wsync-and-timing.asm
; Run:   stella build/lesson14.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS — the frame, the split, and the clock
; =============================================================================
VBLANK_LINES   = 37     ; blanked lines between VSYNC and the picture
VISIBLE_LINES  = 192    ; visible scanlines: two halves of 96
TOP_LINES      = 96     ; red lines at the top (Exercise 1 moves this split)
BOTTOM_LINES   = VISIBLE_LINES-TOP_LINES   ; blue lines below (96 here)
OVERSCAN_LINES = 30     ; blanked lines after the picture
MODE_FRAMES    = 120    ; frames per mode (~2 seconds at ~60 Hz)

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
ModeCounter = $80       ; frames left in this mode: 120 -> 0
Mode        = $81       ; $00 = aligned, $01 = late (flips every 120 frames)

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD (Lesson 04)

    LDA #MODE_FRAMES
    STA ModeCounter         ; 120 frames until the first mode flip
    LDA #$00
    STA Mode                ; start aligned — the first frames are the clean ones

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
; -----------------------------------------------------------------------------
; THE MODE CLOCK — one tick per frame, a flip every 120 ticks
; -----------------------------------------------------------------------------
    DEC ModeCounter
    BNE NoFlip              ; still counting: the mode holds
    LDA #MODE_FRAMES
    STA ModeCounter
    LDA Mode
    EOR #$01                ; $00 <-> $01: swap the boundary discipline
    STA Mode
NoFlip:
; -----------------------------------------------------------------------------
; VSYNC — exactly 3 lines (Lesson 12)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = start VSYNC
    STA VSYNC
    STA WSYNC               ; VSYNC line 1 ends
    STA WSYNC               ; VSYNC line 2 ends
    STA WSYNC               ; VSYNC line 3 ends
    LDA #$00
    STA VSYNC               ; pulse off — exactly 3 lines

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
; -----------------------------------------------------------------------------
; VBLANK — 37 blanked lines (Lesson 12)
; -----------------------------------------------------------------------------
    LDA #$02                ; bit 1 = blank the screen
    STA VBLANK
    LDX #VBLANK_LINES
VblankLines:
    STA WSYNC
    DEX
    BNE VblankLines

VisibleStart:               ; debugger checkpoint: visible's first line (Stella: 37)
; -----------------------------------------------------------------------------
; VISIBLE — 96 red lines, one boundary line (clean or torn), 95 blue lines
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam — visible line 1
    LDA #$42                ; the top half's red
    STA COLUBK              ; lands in HBLANK: the release line shows it
    LDY #TOP_LINES-1        ; 95 more lines complete the top half's 96
TopLoop:
    STA WSYNC               ; wait for the next line to start
TopWrite:                   ; debugger checkpoint: every line, always in HBLANK
    STA COLUBK              ; paint it red (store lands at line-cycle 2)
    DEY
    BNE TopLoop
    ; --- the last red line (visible line 96) is painted; the CPU is still early in it ---
    STA WSYNC               ; THIS is the anchor: wait out visible line 96 -> line 97

    LDA Mode
    BEQ BoundaryWrite       ; aligned: write the boundary color immediately
; -----------------------------------------------------------------------------
; LATE MODE — do extra work first, and pay for it with a torn line
; -----------------------------------------------------------------------------
    JSR DelayBottom         ; 38 cycles of "work" that HBLANK cannot hide
BoundaryWrite:              ; debugger checkpoint: where the two modes differ
    LDA #$84                ; the bottom half's blue
    STA COLUBK              ; aligned: HBLANK; late: mid-picture — a static tear

    LDY #BOTTOM_LINES-1     ; 95 more lines complete the bottom half's 96
BottomLoop:
    STA WSYNC
BottomWrite:                ; debugger checkpoint: every line, in HBLANK
    STA COLUBK              ; paint it blue
    DEY
    BNE BottomLoop

    STA WSYNC               ; let the last line finish before blanking
    LDA #$02
OverscanStart:              ; debugger checkpoint: overscan's first line (Stella: 229)
    STA VBLANK
    LDX #OVERSCAN_LINES
OverscanLines:
    STA WSYNC
    DEX
    BNE OverscanLines
    JMP StartFrame          ; 262 lines done: next frame

; =============================================================================
; SUBROUTINE: DelayBottom — the late mode's deliberate overrun (26 cycles)
; =============================================================================
; What it does:  burns a fixed 26 cycles: LDX (2) + five loop passes
;                (4 x (DEX+BNE) + the final DEX+BNE = 24).  With the JSR
;                and RTS around it (12 more), the late path spends 38
;                cycles of work between the anchor and the color load —
;                far more than HBLANK's ~23-cycle window, so the write
;                that follows lands in the visible portion.  Any real
;                kernel does work like this (state updates, sprite math);
;                the lesson is to do it BEFORE the anchor, not after it.
; Registers:     X is used up; A and Y are untouched.
; =============================================================================
DelayBottom:
    LDX #$05                ; 2 cycles
DelayLoop:
    DEX                     ; 2 cycles
    BNE DelayLoop           ; 3 cycles taken / 2 on the last pass
    RTS                     ; 6 cycles

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

> The complete, fully-commented source lives in
> `lessons/part2-tv-and-tia/14-wsync-and-timing/14-wsync-and-timing.asm`.

### Code Walkthrough

#### Step 1 — The frame, and the mode clock

The frame ledger is Lesson 12's: 3 lines of VSYNC, 37 of VBLANK, 192 visible, 30 of overscan — 262 counted lines per pass. One thing is new at the top of the loop: a 120-frame countdown that flips `Mode` between `$00` (aligned) and `$01` (late) — the same RAM-countdown pattern as Lesson 13's luminance clock, reused for a different job. The mode schedule falls out of it: frames 1–119 aligned, 120–239 late, 240–359 aligned, and so on — the first window runs one frame short (the counter flips on its 120th pass); from then on the picture changes regimen every two seconds.

#### Step 2 — The anchored loops

Both halves are painted by the now-familiar loop:

```asm
TopLoop:
    STA WSYNC               ; wait for the next line to start
TopWrite:                   ; debugger checkpoint: every line, always in HBLANK
    STA COLUBK              ; paint it red (store lands at line-cycle 2)
    DEY
    BNE TopLoop
```

The budget arithmetic: `STA WSYNC` parks the CPU until the next line begins; on release, `STA COLUBK` runs at cycle 0 and its store goes out on cycle 2, deep inside HBLANK, `DEY` costs 2, `BNE` costs 3 — **11 cycles of the 76-cycle line**, and the anchor spends the other 65 parked. That is the invisible rhythm every background in every later part will reuse. The bottom half is the same loop with blue.

After painting the top half's 96 lines (the release line plus 95 loop passes), the loop exits, and one more `WSYNC` — the *boundary anchor* — waits out the last red line, so the next instruction runs at the first cycle of visible line 97 (Stella scanline 133).

#### Step 3 — One boundary, two paths, two ledgers

What happens after that anchor is the entire lesson:

```asm
    LDA Mode
    BEQ BoundaryWrite       ; aligned: write the boundary color immediately
    JSR DelayBottom         ; late: 38 cycles of "work" that HBLANK cannot hide
BoundaryWrite:
    LDA #$84                ; the bottom half's blue
    STA COLUBK              ; aligned: HBLANK; late: mid-picture — a static tear
```

Count both paths from the anchor (cycle 0 = the line's first cycle):

| What happens (from the anchor) | Aligned | Late |
|---|---|---|
| mode check (`LDA Mode` + `BEQ`) | cycles 0–5 (branch taken) | cycles 0–4 (not taken) |
| the extra work (`JSR` + 26-cycle loop + `RTS`) | — | cycles 5–42 |
| color load (`LDA #$84`) | cycles 6–7 | cycles 43–44 |
| the store (`STA COLUBK`) | cycles 8–10 | cycles 45–47 |
| **where the write lands** | **cycle 10** — HBLANK (clocks 30–32, ~36 clocks before the picture) | **cycle 47** — ~24 CPU cycles into the visible portion |
| **on screen** | visible line 97 entirely blue — a clean edge | visible line 97: red for pixels 0–75, blue from 76 — a tear |

The late store goes out at color clocks 141–143; the register's new value is first seen at clock 144 — pixel 76 of 160. That half-painted line is the scar you will see in the screenshot, identical in every frame, because the 38-cycle routine takes exactly 38 cycles every time.

#### Step 4 — Reading the picture back

There are four frame checkpoints (Lesson 12's, unchanged) and three timing checkpoints:

| Checkpoint | Address in the shipped ROM | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F016` | scanline 259, every frame | the frame top |
| `VblankStart` | `$F032` | scanline 0 | VBLANK's first line |
| `VisibleStart` | `$F03D` | scanline 37 | the picture's first line |
| `TopWrite` | `$F049` | cycle 11 / pixel −35, every line | the per-line write, pinned in HBLANK |
| `BoundaryWrite` | `$F057` | aligned: cycle 6 / pixel −50; late: cycle 43 / pixel +61 | the checkpoint the two modes disagree on |
| `BottomWrite` | `$F05F` | same rhythm as `TopWrite` | the bottom half's per-line write |
| `OverscanStart` | `$F068` | scanline 229 | overscan's first line |

(Stella numbers the frame's lines absolutely — the picture's first line is scanline 37 — so the four frame values read 259/0/37/229, the same as Lesson 12. That is the reassurance that all this timing work did not disturb the frame.)

## What You Should See

The ROM opens in aligned mode: two equal halves — red above, blue below — with the boundary exactly at the middle line. Nothing moves; the edge is as clean as the frame around it. About two seconds in, the picture gets its scar: **the boundary line's first 76 of 160 pixels stay red**, and the rest of that line (and everything below) is blue. Two seconds later the scar is gone; two seconds later it is back. Captures taken seconds apart are pixel-identical in either mode — the only difference between the two modes is that one line.

![Stella running the Lesson 14 ROM in aligned mode: two equal halves, red over blue, with a clean boundary at the middle of the picture](/images/lesson14/wsync-aligned.png)

*The aligned mode: red above, blue below — 96 lines each — and the boundary write landed in HBLANK, so the boundary line is entirely blue. (The two colors are Lesson 12's `$42` and `$84`.)*

<RomPlayer rom="/roms/part2-tv-and-tia/14-wsync-and-timing/14-wsync-and-timing.bin" title="Lesson 14 — WSYNC and Timing" />

![Stella running the Lesson 14 ROM in late mode: the same red/blue halves, but the boundary line is torn — its left portion red, the rest blue](/images/lesson14/wsync-torn.png)

*The late mode: the same two halves, but the boundary line's first 76 of 160 pixels are still red — the boundary write landed ~24 CPU cycles into the visible portion. Fixed late work, so the tear sits at exactly the same spot in every frame.*

Open the debugger (`stella -debug`) and watch the numbers tell the same story. The course's state-log method makes it text you can diff (values as reported by Stella 7):

```bash
# assemble with a symbol list to get the checkpoint addresses
acme -f plain -l build/lesson14.sym -o build/lesson14.bin \
  lessons/part2-tv-and-tia/14-wsync-and-timing/14-wsync-and-timing.asm
grep -E "TopWrite|BoundaryWrite" build/lesson14.sym

# then log one breakpoint per run
stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F049' \
  docs/public/roms/part2-tv-and-tia/14-wsync-and-timing/14-wsync-and-timing.bin
```

- **`$F049` (`TopWrite`)**: one hit per line — scanline 37 first (cycle 19, the release line joins the loop late), then 38, 39, 40, … every line at cycle 11 / pixel −35: the same position on consecutive lines, in HBLANK, exactly the anchored rhythm. (The checkpoint sits right after `STA WSYNC`, so the log reports it at the moment the anchor takes hold; break at `$F04B`, the `DEY` right after the store, and the log reads cycle 3 — pinning the store itself at cycle 2, well inside HBLANK.)
- **`$F057` (`BoundaryWrite`)**: the two modes, live. Aligned frames log cycle 6 / pixel −50 (the store follows at cycle 10, still in HBLANK). Late frames log cycle 43 / pixel +61 (the store at cycle 47 — in the picture). Let the log run for five seconds and it alternates between the two every 120 frames, tracking the mode clock exactly.
- **`$F068` (`OverscanStart`)**, `$F016`, `$F032`, `$F03D`: 229/259/0/37 — Lesson 12's frame values, unchanged, while the boundary below them swings between clean and torn.

## Exercises

### Exercise 1: Move the Split (One Constant)

**Challenge:** move the boundary to another line. The whole answer is one constant: change `TOP_LINES` from 96 to 64 and watch the split — and everything that follows it — move.

**Hints:**
1. `TOP_LINES` drives both loops: the top loop paints `TOP_LINES-1 = 63` more lines after the release line (64 red lines, 0–63), and `BOTTOM_LINES = VISIBLE_LINES-TOP_LINES` makes the bottom 128.
2. Nothing else changes — the anchor, the mode clock, and the late mode's 38-cycle routine all still apply; only the line the boundary sits on moves.
3. The tear does not care where the boundary is: in late mode, visible line 65 still paints red for its first 76 pixels.

**Expected Result:** the top third red, the bottom two thirds blue. Aligned mode: a clean edge just above visible line 65. Late mode: the static tear on visible line 65, identical every frame.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Repair the Late Mode (Budget Fix)

**Challenge:** make the late mode's write land in HBLANK again — *without deleting the work*. The fix is ordering, not speed: run the mode check and the 38-cycle routine **before** the anchor, not after it.

**Hints:**
1. The work belongs in the last red line (visible line 96) — already painted red, with almost its whole 76-cycle budget free. Burning cycles there changes nothing on screen.
2. After the anchor, leave only the write itself: `LDA #$84` + `STA COLUBK` (5 cycles), so the store goes out at cycle 4 — deep inside HBLANK.
3. Both modes now produce the identical clean split; the ROM still alternates, and on screen you cannot tell. To verify, break at `StoreDone` — the instruction right after the store: the log reads scanline 133, cycle 5 identically in both windows.

**Expected Result:** two equal halves, red over blue, a clean boundary in **both** modes — the tear never appears. (Exercise 3 proves the budget with two breakpoints.)

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The Two-Breakpoint Budget Check *(Stretch Goal)*

**Challenge:** verify the repaired kernel's budget with two state-log breakpoints and record the cycle ledger. The two labels bracket the critical section: `BudgetStart` right after the anchor, `BudgetEnd` right after the store.

**Hints:**
1. The ledger: the anchor releases the CPU at scanline 133, cycle 0; `LDA #$84` takes 2 cycles; `STA COLUBK` takes 3, with the store latching on its last cycle — so `BudgetEnd` follows 5 cycles after the release.
2. `BudgetStart` sits immediately after `STA WSYNC`, so the debugger reports it at the moment the anchor takes hold — scanline 132 — and its position differs between modes (the work runs first in late mode). `BudgetEnd` is where the proof is: it must read **scanline 133, cycle 5** in *both* modes.
3. Five cycles used of HBLANK's ~23 leaves ~18 for real work — a budget report you can now produce for any kernel.

**Expected Result:** `BudgetStart`: scanline 132 (cycle 16 while aligned; later in late mode, after the work). `BudgetEnd`: **scanline 133, cycle 5, pixel −53 — identically in both modes** — 5 of ~23 HBLANK cycles used. The repaired write never leaves HBLANK, in either mode.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A scanline is 76 CPU cycles:** ~23 of HBLANK (the invisible window, color clocks 0–67) and ~53 of picture (the visible 160, clocks 68–227)
- ✅ **`STA WSYNC` parks the CPU until the next line begins** — it anchors code to the line, not to a duration
- ✅ **Writes take effect where the beam is:** in HBLANK they are invisible; in the visible portion they tear the line they land on
- ✅ **Fixed late work gives a static tear; varying late work gives a moving one** — the movement is a budget symptom
- ✅ **The discipline: finish your line's work before the line you need the result on.** The previous line has spare budget; HBLANK has ~23 cycles
- ✅ **The ledger is the tool:** count the cycles between an anchor and a write, compare against HBLANK's ~23, and move work across the boundary when it does not fit
- ✅ **The debugger shows both regimes:** per-line checkpoints at one fixed HBLANK position; the boundary checkpoint at HBLANK (aligned) or ~24 cycles into the picture (late)

## What's Next

You have now written every blanked wait in this part the hard way — counted `WSYNC` loops, with the ledger to prove each line. [Lesson 15: The Timer](/part2-tv-and-tia/15-the-timer) hands the invisible waits to the RIOT: a chip that counts cycles for you while the CPU gets on with the frame, and the values (`TIM64T`, `INTIM`) that will replace most of these loops in every kernel from here on.
