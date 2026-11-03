---
title: "Lesson 21: Asymmetric Playfield — Different Left and Right"
description: "The TIA re-reads PF0, PF1, and PF2 for the second half of every line. Rewrite them after their left-half slots and before their right-half slots, and the two halves hold different data. Lesson 21 pins the six write windows and draws a split gate."
prev:
  text: "Lesson 20: Playfield Colors and Priority"
  link: "/part3-playfield/20-playfield-colors"
next:
  text: "Lesson 22: Playfield Animation"
  link: "/part3-playfield/22-playfield-animation"
---

# Lesson 21: Asymmetric Playfield — Different Left and Right

> **Part 3: Playfield** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 14 (`WSYNC` and the 76-cycle line), Lesson 16 (horizontal zones), Lesson 17 (cycle counting), Lesson 18 (mid-scanline writes and hit cycles), Lesson 19 (the playfield registers, bit order, and the repeat/reflect modes), Lesson 20 (score mode and `CTRLPF`)
> **You will learn:** how the TIA reads the playfield twice per line; the six register slots and their color-clock windows; how to rewrite `PF0`/`PF1`/`PF2` between the left and right reads; a pinned per-line cycle ledger for a two-pattern line; why the first line can share the same phase
> **You will build:** "the split gate" — a solid left wall with a two-chunk doorway and a gapped, striped right half, both drawn from the same three registers every line; plus three exercises: move the gate, mirror the halves, and build a two-band asymmetric scene

## Introduction

Every playfield so far has been symmetric or repeated: the right half was the left half mirrored or duplicated. That covers a lot of 2600 scenery — but not mazes, not two-sided corridors, not a gate with a different wall on each side.

The symmetry is a hardware convenience, not a rule. The TIA reads the playfield **twice per line**: once for the left half and again for the right. In repeat mode the second pass reads the same three registers; in reflect mode it reads them backwards. If you rewrite a register **after the beam has consumed its left-half slot and before the right-half slot begins**, the left half keeps the old data and the right half gets the new data. One line, two patterns, no extra objects.

The catch is timing. The three registers are read at different clock ranges inside the line, and each one has its own window. This lesson maps the windows, pins the write cycles, and builds a kernel where every right-half write lands with room to spare. The measured evidence — six write ticks at constant cycles, 192 times per frame — is what makes the technique trustworthy.

::: details TypeScript Equivalent
A line is two arrays drawn from the same registers. The mid-line writes replace the second array:

```typescript
let pf0 = 0xf0, pf1 = 0xff, pf2 = 0x3f;   // the left half's data

function drawLeftHalf() { return [pf0, pf1, pf2]; }
function drawRightHalf() { return [pf0, pf1, pf2]; }

// The TIA calls drawLeftHalf, then drawRightHalf. If we overwrite the
// registers between the calls, the halves differ:
const left  = drawLeftHalf();
pf0 = 0x00; pf1 = 0xaa; pf2 = 0x55;
const right = drawRightHalf();               // new data, same line
console.assert(left[0] !== right[0] && left[2] !== right[2]);
```

The hardware equivalent is not a function call: the reads happen at fixed color clocks, so the "between the calls" window is a range of CPU cycles. That range is the lesson.
:::

## Theory

### Section 1: The Two-Pass Line

A visible line is 160 color clocks. In **repeat mode** the playfield consumes 20 bits per half and reads the three registers in the same order twice:

| Half | `PF0` | `PF1` | `PF2` |
|---|---|---|---|
| Left | clocks 68–84 | 84–116 | 116–148 |
| Right | 148–164 | 164–196 | 196–228 |

In **reflect mode** the right-half order is reversed — `PF2` 148–180, `PF1` 180–212, `PF0` 212–228 — so the write windows move. This lesson uses repeat mode.

The value that matters for each four-clock chunk is the one present when that chunk begins; the windows below use the conservative slot boundaries. The left pass paints chunks 0–19; the right pass paints chunks 20–39 from whatever the registers hold when their slots arrive.

This is the whole technique: **the registers are not latched once for the line**. The TIA re-reads them per half. Lesson 18 used the same idea for `COLUBK`; the playfield gives it three registers and six windows.

### Section 2: The Six Write Windows

For each register, the safe rewrite window runs from the end of its left-half slot to the start of its right-half slot:

| Register | Left slot ends | Right slot starts | Safe write window |
|---|---|---|---|
| `PF0` | clock 84 (cycle ≈28) | clock 148 (cycle ≈49.3) | cycles ≈29–49 |
| `PF1` | clock 116 (cycle ≈38.7) | clock 164 (cycle ≈54.7) | cycles ≈39–54 |
| `PF2` | clock 148 (cycle ≈49.3) | clock 196 (cycle ≈65.3) | cycles ≈50–65 |

The lesson's kernel places the three right-half writes at hit cycles **35, 46 and 57** (a hit cycle is the cycle of the instruction after the store — the Lesson 18 convention). Their effects begin at clocks **105, 138 and 171**: 43, 26 and 25 clocks before the right `PF0`/`PF1`/`PF2` slots (and 21–23 clocks after the left ones). The left-half writes go in at hit cycles **10, 15 and 20** (effects at clocks 30, 45 and 60), comfortably before the left slots.

The margins matter. The windows are wide enough for a small amount of per-line logic — a scroll, a moving gate, a score update — which is why the technique scales beyond this fixed pair of patterns.

### Section 3: The Per-Line Ledger

The body is entered at cycle 5 on every line. The release (`LDA #$00` + `STA VBLANK`) is 5 cycles, and the steady-state wake is `DEX` + taken `BNE` = 5 cycles; `X` is loaded before the timer wait, so line 37's body starts at cycle 5 like every later line.

| Cycles | Instruction | Effect / note |
|---|---|---|
| 5–9 | `LDA #LEFT0` / `STA PF0` | effect 10 (clock 30) — before left PF0 at 68 |
| 10–14 | `LDA #LEFT1` / `STA PF1` | effect 15 (clock 45) — before left PF1 at 84 |
| 15–19 | `LDA #LEFT2` / `STA PF2` | effect 20 (clock 60) — before left PF2 at 116 |
| 20–29 | `NOP` × 5 | left PF0 slot (68–84) is past |
| 30–34 | `LDA #RIGHT0` / `STA PF0` | effect 35 (clock 105) — before right PF0 at 148 |
| 35–40 | `NOP` × 3 | left PF1 slot (84–116) is past |
| 41–45 | `LDA #RIGHT1` / `STA PF1` | effect 46 (clock 138) — before right PF1 at 164 |
| 46–51 | `NOP` × 3 | left PF2 slot (116–148) is past |
| 52–56 | `LDA #RIGHT2` / `STA PF2` | effect 57 (clock 171) — before right PF2 at 196 |
| 57–59 | `STA WSYNC` | write 59, park 60–75 |
| next 0–4 | `DEX` / `BNE` taken | wake 5; body re-entered at 5 |

The line is 76 cycles: 55 of work, 16 parked, 5 of wake. Nothing drifts because the anchor is always written at cycle 59, long before the line ends.

### Section 4: The Split Gate

The pattern pair is chosen to make the asymmetry obvious. The bitstrings below are in on-screen chunk order (bit 0 first, as the TIA draws them):

```
left half                       right half
PF0 $F0  1111                  PF0 $00  0000
PF1 $FF  11111111              PF1 $AA  10101010
PF2 $3F  11111100              PF2 $55  10101010
```

Remember the bit orders: `PF0` bit 4 leftmost, `PF1` bit 7 leftmost, `PF2` bit 0 leftmost. `LEFT2 = $3F` displays as `11111100`: chunks 12–17 on, 18–19 off. `RIGHT2 = $55` displays as `10101010` in chunk order (bit 0 first): chunks 32/34/36/38 on, 33/35/37/39 off.

The picture is on from x = 25, then: a six-chunk central gap (the left half's 18–19 plus the right half's 20–23, x = 457–600; the transitions are at 457 and 601), then alternating 24-pixel stripes all the way to the right edge. The last chunk is off, so the picture ends dark at x = 961.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson21.bin \
  lessons/part3-playfield/21-asymmetric-playfield/21-asymmetric-playfield.asm
stella build/lesson21.bin
```

The exercise solutions assemble the same way — replace the file name with `exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 21: Asymmetric Playfield — Different Left and Right — Racing the Beam
; =============================================================================
; Part 3: Playfield
;
; What this program does:
;   Draws a wall whose left and right halves hold DIFFERENT data.  The left
;   half is a solid green wall with a two-chunk doorway beside the center;
;   the right half is a gapped field of one-chunk stripes.  The two halves
;   are not mirror images — they are separate patterns.
;
; How the TIA draws a playfield line, in repeat mode:
;   - The 20 bits are read once for the LEFT half: PF0 (chunks 0-3),
;     PF1 (4-11), PF2 (12-19), each register sampled at its own slot;
;   - then the SAME registers are read again for the RIGHT half, in the
;     same order (PF0, PF1, PF2), because CTRLPF bit 0 (REF) is clear.
;
;   The trick: the TIA re-reads a register for the second half.  If you
;   rewrite PF0/PF1/PF2 after their left-half slots have been displayed
;   and before their right-half slots begin, only the right half changes.
;   The left half is already painted; the new bytes are waiting for the
;   second pass.
;
;   The slot map (color clocks from the start of the visible line):
;
;     left  PF0  68-84     left  PF1  84-116    left  PF2 116-148
;     right PF0 148-164    right PF1 164-196    right PF2 196-228
;
;   This program's per-line ledger (body entered at cycle 5 on every line):
;
;     cycles   instruction            note
;     5-9      LDA #LEFT0 / STA PF0   effect 10 (clock 30)  - before left PF0 (68)
;     10-14    LDA #LEFT1 / STA PF1   effect 15 (clock 45)  - before left PF1 (84)
;     15-19    LDA #LEFT2 / STA PF2   effect 20 (clock 60)  - before left PF2 (116)
;     20-29    NOP x 5                burn 10 cycles; left PF0 slot (68-84) is past
;     30-34    LDA #RIGHT0 / STA PF0  effect 35 (clock 105) - before right PF0 (148)
;     35-40    NOP x 3                left PF1 slot (84-116) is past
;     41-45    LDA #RIGHT1 / STA PF1  effect 46 (clock 138) - before right PF1 (164)
;     46-51    NOP x 3                left PF2 slot (116-148) is past
;     52-56    LDA #RIGHT2 / STA PF2  effect 57 (clock 171) - before right PF2 (196)
;     57-59    STA WSYNC              write 59, park 60-75
;     next 0-4 DEX / BNE taken       wake 5; the body is entered at cycle 5
;
;   The release (LDA #$00 / STA VBLANK) is also 5 cycles, and X is loaded
;   before the timer wait, so line 37's body starts at cycle 5 exactly like
;   every later line.  The left half is painted on line 37 just as on 228.
;
; The patterns (bit order: PF0 bit 4 leftmost, PF1 bit 7, PF2 bit 0):
;   LEFT0  = $F0  chunks 0-3 on
;   LEFT1  = $FF  chunks 4-11 on
;   LEFT2  = $3F  chunks 12-17 on, 18-19 off  (bits 6-7 clear)
;   RIGHT0 = $00  chunks 20-23 off
;   RIGHT1 = $AA  chunks 24/26/28/30 on, 25/27/29/31 off
;   RIGHT2 = $55  chunks 32/34/36/38 on, 33/35/37/39 off
;
;   The central gap is six chunks: the left half's 18-19 plus the right
;   half's 20-23 (x = 457-600, 144 px; transitions at 457 and 601).  The
;   right half then alternates every
;   chunk to the edge.
;
; Debugger checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), VisibleStart (37), OverscanStart
;   (229); the six write ticks Left0/Left1/Left2 at hit cycles 10/15/20 and
;   Right0/Right1/Right2 at 35/46/57, 192 hits per frame each.
;
; Build: acme -f plain -o build/lesson21.bin \
;        lessons/part3-playfield/21-asymmetric-playfield/21-asymmetric-playfield.asm
; Run:   stella build/lesson21.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions; +clean_start boots the machine ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44     ; TIM64T ticks for exactly 37 lines (Lesson 15)
OVERSCAN_TIMER = 36     ; TIM64T ticks for exactly 30 lines (Lesson 15)
VISIBLE_LINES  = 192

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, SP = $FF, CLD

; =============================================================================
; MAIN LOOP — one pass = one frame = 262 scanlines
; =============================================================================
StartFrame:                 ; debugger checkpoint: VSYNC's first line (Stella: 259)
    +vsync

VblankStart:                ; debugger checkpoint: VBLANK's first line (Stella: 0)
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- one setup for the whole frame: repeat mode, colors ---
    LDA #$00
    STA CTRLPF              ; REF = 0: repeat the left half on the right
    LDA #$C8
    STA COLUPF              ; green
    LDA #$02
    STA COLUBK              ; dark neutral

; --- X is the line counter; load it before the wait so line 37 starts at
;     cycle 5 exactly like every later line ---
    LDX #VISIBLE_LINES
    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — every line rewrites the registers for its right half
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK              ; release the beam on line 37
VisibleStart:               ; debugger checkpoint: the picture's first line (37)
    LDA #$F0                ; 5-6    left PF0
    STA PF0                 ; 7-9
Left0:                      ; checkpoint: hit cycle 10
    LDA #$FF                ; 10-11  left PF1
    STA PF1                 ; 12-14
Left1:                      ; checkpoint: hit cycle 15
    LDA #$3F                ; 15-16  left PF2: chunks 12-17 on, 18-19 off
    STA PF2                 ; 17-19
Left2:                      ; checkpoint: hit cycle 20
    NOP                     ; 20-21  burn the rest of the left PF0 slot
    NOP
    NOP
    NOP
    NOP                     ; 28-29
    LDA #$00                ; 30-31  right PF0
    STA PF0                 ; 32-34
Right0:                     ; checkpoint: hit cycle 35
    NOP                     ; 35-36  left PF1 slot (84-116) is past
    NOP
    NOP                     ; 39-40
    LDA #$AA                ; 41-42  right PF1
    STA PF1                 ; 43-45
Right1:                     ; checkpoint: hit cycle 46
    NOP                     ; 46-51  left PF2 slot (116-148) is past
    NOP
    NOP
    LDA #$55                ; 52-53  right PF2
    STA PF2                 ; 54-56
Right2:                     ; checkpoint: hit cycle 57
    STA WSYNC               ; 57-59  write 59, park 60-75
    DEX                     ; next line, cycle 0-1
    BNE VisibleStart        ; 2-4 taken; body re-entered at cycle 5

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
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

<!-- END-FULL-SOURCE -->

> The complete, fully-commented source lives in
> `lessons/part3-playfield/21-asymmetric-playfield/21-asymmetric-playfield.asm`.

### Code Walkthrough

#### Step 1 — One setup per frame

`CTRLPF = $00` selects repeat mode; `COLUPF = $C8` and `COLUBK = $02` set the colors. The pattern bytes change every line, so unlike Lessons 19–20 there is no frame-level pattern store.

#### Step 2 — The release and the counter

`X` is loaded with 192 **before** the VBLANK wait. The release then costs exactly 5 cycles, the same as the steady-state wake, so line 37 and line 228 share the same phase. This is the Lesson 18 phase-match applied to a six-write body.

#### Step 3 — The left half

The first three stores put the left-half values in place at hit cycles 10/15/20. Their effects land in clocks 30/45/60, before the playfield begins reading at clock 68.

#### Step 4 — The right half

Five NOPs burn the rest of the left PF0 slot; then the right-half values go in at hit cycles 35/46/57. The NOP groups between the stores are not padding for its own sake: each one waits out the left-half slot of the register that is about to be rewritten.

#### Step 5 — The anchor

`STA WSYNC` at cycles 57–59 writes the anchor at cycle 59 and parks the rest of the line. `DEX`/`BNE` wake the body at cycle 5.

#### Step 6 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F00E` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F01C` | 0, cycle 5 | VBLANK's first line |
| `VisibleStart` | `$F03E` | 37, cycle 5 | the picture's first line |
| `Left0` | `$F042` | (37, **10**), A = `$F0`, 192 hits/frame | left PF0 |
| `Left1` | `$F046` | (37, **15**), A = `$FF` | left PF1 |
| `Left2` | `$F04A` | (37, **20**), A = `$3F` | left PF2 |
| `Right0` | `$F053` | (37, **35**), A = `$00` | right PF0 |
| `Right1` | `$F05A` | (37, **46**), A = `$AA` | right PF1 |
| `Right2` | `$F061` | (37, **57**), A = `$55` | right PF2 |
| `OverscanStart` | `$F066` | 229, cycle 4 | overscan's first line |

The six ticks are constant across all 192 lines of the frame — one unique cycle each. That is what "the windows are wide enough" looks like as data.

## What You Should See

A green wall where the two halves do not match. From the left edge to x = 457 the wall is solid. Then comes a six-chunk dark doorway (x = 457–600, 144 px). The right half starts with four dark chunks, then turns into alternating 24-pixel stripes — on, off, on, off — all the way to the right edge, ending dark.

![Stella running the Lesson 21 ROM: a solid left wall with a central doorway and a striped right half](/images/lesson21/asymmetric.png)

*The split gate, captured from the committed ROM: solid green to x = 457, a six-chunk doorway to 601, then alternating stripes (transitions at 601, 625, 649, 673, 697, 721, 745, 769, 793, 817, 841, 865, 889, 913, 937, 961; the last chunk is dark). The left half is unchanged by the right-half writes.*

<RomPlayer rom="/roms/part3-playfield/21-asymmetric-playfield/21-asymmetric-playfield.bin" title="Lesson 21 — Asymmetric Playfield" />

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson21.sym -o build/lesson21.bin \
  lessons/part3-playfield/21-asymmetric-playfield/21-asymmetric-playfield.asm
grep -E "Left[012]|Right[012]|VisibleStart" build/lesson21.sym

stella -dbg.logbreaks 1 -logtoconsole 1 -break '$F053' \
  docs/public/roms/part3-playfield/21-asymmetric-playfield/21-asymmetric-playfield.bin
```

- **`$F042` / `$F046` / `$F04A`**: the left-half writes at hit cycles 10/15/20, A = `$F0`/`$FF`/`$3F`.
- **`$F053` / `$F05A` / `$F061`**: the right-half writes at hit cycles 35/46/57, A = `$00`/`$AA`/`$55`. Each is one unique cycle across the frame's 192 lines.
- **`$F03E` (`VisibleStart`)**: line 37, cycle 5 — the same phase as every later line. There is no first-line seam.

## Exercises

### Exercise 1: Move the Gate

**Challenge:** move the doorway left and start the right half solid.

**Hints:**
1. The doorway's left edge is `LEFT2`. To clear four chunks instead of two, clear bits 4–7: `$0F`, which displays as `11110000` (bit 0 first) — chunks 16–19 off.
2. `RIGHT0 = $F0` turns on the right half's first four chunks (20–23); `RIGHT1 = $AA`'s leftmost bit (bit 7) also lights chunk 24, so the solid run reaches x = 625. The right side no longer starts with a gap.
3. The cycle ledger is unchanged: the same six writes, the same hit cycles.

**Expected Result:** the solid left wall ends at x = 409, a four-chunk doorway runs to 505, the right half is solid from 505 to 625, and the alternating stripes resume from 625. Measured: transitions at 409, 505, 625, 649, 673, 697, 721, 745, 769, 793, 817, 841, 865, 889, 913, 937, 961.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Mirror the Right Half

**Challenge:** make the right half a mirror of the left by using reflect mode instead of mid-line rewrites.

**Hints:**
1. Set `CTRLPF = $01` (`REF`) and write the left pattern once per frame.
2. The kernel becomes the 192-line hold from Lessons 19–20 — no mid-line writes at all.
3. `PF2 = $3F` keeps the four-chunk central gap; reflect mirrors chunks 18–19 into 20–21.

**Expected Result:** a symmetric green wall with a four-chunk central gap: on from x = 25 to 457, dark to 553, green to the right edge. The measured transitions are at 457 and 553 — exactly the Lesson 20 wall without the score split.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Two Asymmetric Bands *(Stretch Goal)*

**Challenge:** a scene with two horizontal bands, each with its own left/right pair.

**Hints:**
1. Duplicate the per-line body with different constants; two 96-line loops cover the 192 visible lines.
2. The second loop reloads `X`, which costs 2 cycles, so the top band's first line starts its body at cycle 7 and the bottom band's at cycle 6 (the exit `BNE` is not taken); every later line starts at 5. Every write still lands before its slot — the margins absorb the shift.
3. Keep the same six-write shape so the windows stay valid in both bands.

**Expected Result:** top band (lines 37–132) the lesson ROM's split gate; bottom band (lines 133–228) a slotted left wall and a right half that starts solid (505–649) then breaks into a different stripe pair — dark 649–697 and 745–841, green 841–937, dark to the edge. Measured: the top band's transitions match the main ROM; the bottom band's transitions are at 169/217/265/313/457/505/649/697/745/841/937 — clearly a different scene.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **The playfield is read twice per line**: once for the left half and once for the right. In repeat mode the second pass reads the same registers; in reflect mode it reads them backwards
- ✅ **Each register has its own window**: rewrite `PF0` after clock 84, `PF1` after 116, `PF2` after 148, and each before its right-half slot (148/164/196). The lesson's writes at hit 35/46/57 land with 43 / 26 / 25 clocks of margin
- ✅ **The left half is already painted**: a write after a register's left slot cannot change it; that is why one set of three registers can feed two different pictures
- ✅ **The phase must be set before the line**: loading `X` before the VBLANK wait makes the release's 5 cycles equal the steady-state wake, so line 37 and line 228 share the same cycle grid
- ✅ **Hit cycles are the unit**: a store's effect begins at the next instruction's cycle; the six ticks measured at 10/15/20/35/46/57 are the ledger's proof
- ✅ **`PF2` keeps its reversed order**: `$3F` clears the centre-adjacent chunks; `$FC` would clear the left edge of PF2 — the same trap, now used deliberately
- ✅ **Asymmetry scales**: the same windows can hold per-line logic (a scroll, a door, a score), which is what Lessons 22–23 build on

## What's Next

The split gate is frozen. [Lesson 22: Playfield Animation](/part3-playfield/22-playfield-animation) makes the wall move: a nine-state portcullis that opens and closes every half second, with the animation state changed once per frame in VBLANK. The asymmetric kernel from this lesson is the foundation for the one-sided-gate exercise.
