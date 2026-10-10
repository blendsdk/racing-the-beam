---
title: "Lesson 07: Branches and Loops — Conditional Execution"
description: "Turn the flags from Lesson 06 into real control flow: the full branch family (BEQ/BNE, BCS/BCC, BMI/BPL, BVS/BVC), count-up and count-down loops, nested loops, and the ±127-byte reach limit that decides when you must reach for JMP instead."
prev:
  text: "Lesson 06: Flags and Comparisons"
  link: "/part1-6502-cpu/06-flags-and-comparisons"
next:
  text: "Lesson 08: The Stack and Subroutines"
  link: "/part1-6502-cpu/08-stack-and-subroutines"
---

# Lesson 07: Branches and Loops — Conditional Execution

> **Part 1: The 6502 CPU** · Estimated time: 45 minutes
> **Prerequisites:** Lesson 06 (`CMP`/`CPX` and the Z, C, and N flags), Lesson 04 (registers, RAM, the frame skeleton)
> **You will learn:** the branch family (`BEQ`/`BNE`, `BCS`/`BCC`, `BMI`/`BPL`, `BVS`/`BVC`) and the flag each one reads; compare-then-branch; count-up and count-down loops; nested loops and delay loops; when to use `JMP` instead of a branch; and how far a branch can reach
> **You will build:** a "cursor ladder" ROM — eight equal bands, one of them bright — in which the bright band steps down one band about every half second and wraps from the bottom back to the top

## Introduction

Lesson 06 ended with a promise: flags are the invisible wire between "do some math" and "now act on the result." This lesson connects that wire. The instructions that *act* are the **branches** — short, conditional jumps — and once you have a branch you have **loops**, because a loop is nothing more than a branch that jumps backwards until its test finally fails.

Control flow is where a list of instructions becomes a *program*. Your ROMs so far have been a straight line with a couple of loops copied from the template; from here on, the interesting part of every program you write is the shape of its branches. The 6502 gives you exactly eight of them, and each one is "look at one flag; jump if it looks right." That is the entire decision-making hardware of the machine — and it is enough for *Adventure*.

The companion program `07-branches-and-loops.asm` makes control flow visible. It paints eight equal bands — a "ladder" — and lights exactly one of them bright red. A byte in RAM called the **cursor** says which band is bright; every half second a **countdown loop** times out, the cursor steps down one band, and a **compare-and-reset branch** wraps it from the bottom back to the top. Everything in the picture is produced by branches and loops; the only unconditional jump in the whole program is the frame loop's `JMP`.

::: details TypeScript Equivalent
In TypeScript the decision and the jump are one statement. On the 6502 they are two instructions, and the decision lives in a shared register:

```typescript
// TypeScript: the test and the jump are fused, and the answer is a boolean.
if (a === b) { /* BEQ */ }
if (a !== b) { /* BNE */ }
if (a >= b)  { /* BCS */ }

// 6502: CMP runs first and leaves flags behind; a LATER branch reads them.
//   CMP #$40      -> sets Z, C, N   ("the answer" is not stored anywhere)
//   BNE somewhere -> reads Z and jumps if it is clear

// Loops look similar, but notice what the assembly version counts:
for (let band = 0; band < 8; band++) { draw(band); }   // INX / CPX #8 / BNE
let lines = 24; while (lines--) { waitOneLine(); }     // LDY #24 / DEY / BNE
```

Two differences matter. First, a 6502 loop counter is an 8-bit register, not an `int` expression — so "loop 24 times" is written as *count down to zero*, because the decrement itself sets the flag the branch needs. Second, and this is the big one: a 6502 branch is a **`goto` with a condition** — and a `goto` can only travel about ±127 bytes. TypeScript would never let its control flow depend on how much code you wrote; on the 6502, that is a real constraint you must design around.
:::

## Theory

### Section 1: The Branch Family — Eight Instructions, One Flag Each

Every branch instruction reads exactly one flag and jumps if it is in the right state. Lesson 06's flag table mapped **Z** and **C** to their branches; here is the complete family, and the flag each one reads:

| Branch | Jumps when | Flag | Typical meaning |
|--------|-----------|:----:|-----------------|
| `BEQ` | equal | **Z = 1** | "the result was zero" / "it matched" |
| `BNE` | not equal | **Z = 0** | "the result was not zero" / "keep going" |
| `BCS` | carry set | **C = 1** | unsigned `A >= operand` (no borrow) |
| `BCC` | carry clear | **C = 0** | unsigned `A < operand` (borrowed) |
| `BMI` | minus | **N = 1** | bit 7 of the last result is on |
| `BPL` | plus | **N = 0** | bit 7 of the last result is off |
| `BVS` | overflow set | **V = 1** | signed math crossed the ±128 boundary |
| `BVC` | overflow clear | **V = 0** | signed math stayed in range |

Two mnemonics are worth decoding once: `BEQ` is "**B**ranch if **EQ**ual" and `BNE` is "**B**ranch if **N**ot **E**qual", but both really test zero — "equal" is just what a `CMP` leaves in **Z**. Likewise `BMI`/`BPL` mean "**B**ranch on **M**inus/**PL**us", which is the sign bit (**N**) of the last result, not the sign of the *number* you were thinking about.

::: tip You will use four of them constantly
In Part 1, `BEQ`/`BNE` and `BCS`/`BCC` do almost all the work. `BMI`/`BPL` show up whenever a value can roll over from `$00` to `$FF` or vice versa — Exercise 1 uses `BPL` to end a count-down loop. `BVS`/`BVC` are the odd pair out: among the instructions you have met so far, only `ADC` and `SBC` *produce* **V** (later lessons meet `BIT`, `CLV`, and `PLP`, which touch it differently), and signed overflow is a topic for much later. Know the pair exists; you will rarely branch on it.
:::

### Section 2: Compare, Then Branch

A branch does not compare anything — it only *consults* flags that some earlier instruction already set. That is why the workhorse pattern of 6502 control flow is two instructions:

```asm
    CPX Cursor          ; CPX: set C, Z, N from (X - Cursor), keep X unchanged
    BNE +               ; Z = 0 -> they differ, so skip the next line
    LDA #BRIGHT         ; Z = 1 -> this band is the cursor band
+   STA COLUBK
```

`CPX` was introduced in Lesson 06: like `CMP` it performs a subtraction, throws the result away, and leaves the flags. The branch on the next line turns those flags into a decision. The catch is that the compare must be the **last** thing to touch **Z** before the branch — any flag-setting instruction in between invalidates the test. That is why `LDA #DARK` sits *above* the `CPX` in the lesson ROM, not between the compare and the branch.

The lesson ROM uses `CPX Cursor` because the band index lives in X. `Cursor` is just the byte at RAM `$80`, so this is a zero-page compare — exactly the "register versus a variable" test you will write hundreds of times:

| You want | Write | Then branch on |
|----------|-------|----------------|
| X == a RAM byte | `CPX Cursor` | `BEQ` (taken when equal) |
| X == a constant | `CPX #8` | `BEQ` / `BNE` |
| A == a constant | `CMP #$40` | `BEQ` / `BNE` |
| X >= a RAM byte | `CPX Cursor` | `BCS` (carry set = no borrow) |
| Y == 0 after a decrement | `DEY` | `BEQ` / `BNE` (no compare needed!) |

That last row is the trick that powers the next section.

### Section 3: Loops — Counting Up and Counting Down

A loop is a branch that goes **backwards**. The two idioms differ only in where the "have I finished?" test comes from.

**Count-down loops** (`DEX`/`DEY` + `BNE`) get their test for free, because `DEX` and `DEY` update **Z** and **N** from the value they produce. Counting *down to zero* means the branch needs no compare instruction at all:

```asm
    LDY #LINES          ; 24
-   STA WSYNC           ; wait one scanline
    DEY                 ; Y = Y - 1 ... and this sets Z if Y became 0
    BNE -               ; Z = 0 -> more lines to go
```

Three instructions, one loop, one scanline per pass. The loop body runs for Y = 24, 23, … 1 and stops when `DEY` finally produces 0 — no compare instruction needed, because the decrement itself answers the question.

**Count-up loops** (`INX`/`INY` + `CPX #limit` + `BNE`) are the right choice when the counter *is* the value you want — the lesson ROM walks the bands with X = 0, 1, … 7 and compares it against the cursor:

```asm
    LDX #0              ; X = band index, starting at the top band
PaintBand:
    ; ... paint band X here ...
    INX                 ; next band
    CPX #BANDS          ; reached 8?
    BNE PaintBand       ; no -> another band
```

A count-up loop needs that extra compare because `INX` has no way of knowing where you want to stop. When you count down, your chosen stop value *is* zero, and zero is what the flags already know about.

::: tip Anonymous labels `-` and `+`
Loops need a label to jump back to, and naming every one of them (`LineLoop:`) gets noisy fast. ACME's **anonymous labels** solve this: `-` means "the most recent `-` label", `+` means "the next `+` label". So `BNE -` is "branch back to the top of this little loop" and `BNE +` is "branch forwards over the next couple of lines". You have been using them since Lesson 06; the lesson ROM uses both: `+` to skip the bright load in the compare, and `-` to close the line loop.
:::

### Section 4: Nested Loops and the Animation Countdown

Two loops, one inside the other, is how a screen gets built. The lesson ROM's paint pass is:

```
band loop      (outer):  8 iterations, one per band        — counts up with X
    line loop  (inner): 24 iterations, one per scanline    — counts down with Y
```

8 × 24 = 192 visible scanlines, which is exactly the picture height your ROMs have painted since Lesson 04. The inner loop must finish before the outer loop's counter moves on, and the inner loop's counter is reloaded from `#LINES` on every pass of the outer loop — a two-level structure that scales to any screen layout.

The animation adds a **third level**, a countdown loop spanning many frames. The frame loop runs about 60 times a second; each pass drops `StepTimer` by one, and the cursor only moves when that counter reaches zero:

```asm
    DEC StepTimer       ; one frame closer to the next step
    BNE NoStep          ; not 0 yet -> nothing moves this frame
    LDA #STEP_FRAMES    ; countdown expired -> reload it...
    STA StepTimer
    INC Cursor          ; ...and move at last
NoStep:
```

With `STEP_FRAMES = 30` the cursor moves every 30 frames — about half a second at NTSC's ~60 frames per second (observed: captures taken half a second apart advance exactly one band). This is the standard way to slow anything down: keep a counter in RAM, decrement it once per frame, and act only on zero. Note that this counter lives in RAM, not in X or Y, because the paint kernel needs both registers every frame.

Talking of slowing things down: when you want a delay *inside* a single frame, the same idea nests — an outer countdown of "how many passes", an inner countdown of "how long is a pass". Because each `DEX`/`BNE` pair costs 5 cycles (derived from the cycle table: `DEX` is 2 cycles, a taken `BNE` is 3), and one scanline is 76 cycles, a delay loop is also how you count *time* on a machine that has no clock to ask.

::: tip Cycle math for a delay loop
`LDX #0` then `DEX`/`BNE` 256 times burns 256 × 5 − 1 ≈ 1,279 cycles ≈ 16.8 scanlines (1,279 ÷ 76). Wrap that in an outer `LDY`/`DEY`/`BNE` and you can stretch a delay to almost anything — this is "a nested delay loop": two countdowns stacked, the way you would nest two `for` loops. The catch is that nothing else happens while it runs, so it belongs in VBLANK or overscan, never during visible lines.
:::

### Section 5: `JMP` vs. Branch — and the ±127-Byte Reach Limit

A branch is a `goto` with two restrictions:

1. **It is conditional.** There has to be a flag, in the right state, at the right moment.
2. **It is short.** The instruction is two bytes — an opcode plus a *signed 8-bit* offset — so the target must lie within **−128 to +127 bytes** of the instruction that follows the branch. The assembler computes the offset for you and reports an error if the target is too far away.

`JMP` has neither restriction: three bytes, three cycles, any target in the cartridge, no flag involved. So the rule of thumb is simple: **branch to make a decision, `JMP` when you just have to go somewhere.** The lesson ROM's frame loop ends with `JMP StartFrame` for exactly that reason — the frame body is 94 bytes of code (measured from the assembled addresses) so a branch *could* reach, but there is no flag worth testing: one frame simply follows another.

The reach limit becomes real the moment a loop body grows. If a loop's body is longer than 127 bytes, the closing `BNE` is rejected by the assembler — the classic error looks like:

```
Error - ... Target out of range (-206; 78 too far).
```

The fix is not to shrink the loop, but to invert the test so the *conditional* jump is a short one, and let `JMP` do the long travel:

```asm
    DEC StepTimer
    BNE Far_away        ; <- the branch you wanted; too far, rejected
    ; the restructure:
    DEC StepTimer
    BEQ StepCursor      ; short hop forward: countdown finished
    JMP Far_away        ; long jump back: another pass instead
```

Exercise 3 walks through exactly this restructure on a real over-range loop.

::: details TypeScript Equivalent
A branch is a conditional `goto`, and a `goto` with a range limit has no TypeScript equivalent at all — which is the point. In TypeScript, control flow is expressed with blocks and `break`/`continue`, and the compiler worries about how far away the end of the loop is:

```typescript
while (true) {
  drawFrame();
  if (--stepTimer === 0) { stepCursor(); stepTimer = 30; }
  // "the loop continues" costs no bytes; the jump back is always in reach
}
```

The 6502 has no such luxury. When you restructure an over-range loop as `BEQ` + `JMP`, you are doing the compiler's job by hand: putting the short jump where the condition is, and the long jump where the distance is.
:::

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson07.bin \
  lessons/part1-6502-cpu/07-branches-and-loops/07-branches-and-loops.asm
```

Then run it in Stella:

```bash
stella build/lesson07.bin
```

### Full Source

The program paints eight 24-line bands. The band whose index equals the cursor byte at RAM `$80` is bright red; the other seven are dark gray. A countdown in RAM steps the cursor every 30 frames, and a compare-and-reset branch wraps it back to the top.

```asm
; =============================================================================
; LESSON 07: Branches and Loops — Conditional Execution
; =============================================================================
; Part 1: The 6502 CPU
;
; What this program does:
;   The "cursor ladder": EIGHT equal bands of 24 scanlines fill the screen,
;   and exactly one of them — chosen by the cursor byte at RAM $80 — is bright
;   red ($42).  Every other band is dark gray ($02).  The cursor walks DOWN
;   one band about every half second and wraps from the bottom back to the top.
;
;   Almost every interesting instruction below is a control-flow instruction:
;   a compare, a branch, or a loop.  That is the whole lesson.
;
; What you'll learn:
;   - The branch family, and the flag each branch reads:
;       BEQ/BNE -> Z     BCS/BCC -> C     BMI/BPL -> N     BVS/BVC -> V
;   - CMP / CPX / CPY set the flags; the branch right after them reads them
;   - A count-up loop  (INX ... CPX #8 ... BNE)  walks the 8 bands
;   - A count-down loop (LDY #24 ... DEY ... BNE) fills one band, 24 lines
;   - A countdown loop nested inside the frame loop times the animation
;   - A compare-and-reset branch wraps 7 -> 0
;   - JMP is the unconditional jump; branches are for decisions
;   - A branch can only reach about ±127 bytes away (see Exercise 3)
;
; Build: acme -f plain -o build/lesson07.bin \
;        lessons/part1-6502-cpu/07-branches-and-loops/07-branches-and-loops.asm
; Run:   stella build/lesson07.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; COLOR CONSTANTS  (NTSC)
; =============================================================================
DARK        = $02       ; every band that is NOT the cursor band
BRIGHT      = $42       ; the cursor band — bright red

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
Cursor      = $80       ; 0..7: which band is bright (0 = top band, 7 = bottom)
StepTimer   = $81       ; frames left before the cursor moves again

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
BANDS       = 8         ; bands on the ladder (8 x 24 = 192 visible lines)
LINES       = 24        ; scanlines per band
STEP_FRAMES = 30        ; frames between cursor steps (~1/2 second at 60 Hz)

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, set the stack, CLD (Lesson 04)

    ; --- Starting state: the cursor sits on the TOP band ---
    LDA #0                  ; A = 0
    STA Cursor              ; Cursor = 0  (band 0, the top band, is bright)
    LDA #STEP_FRAMES        ; A = 30
    STA StepTimer           ; 30 frames until the first step

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK
    +wait_timer
    LDA #$00
    STA VBLANK              ; un-blank — the visible picture starts now

; -----------------------------------------------------------------------------
; KERNEL — eight 24-line bands; the cursor band is the bright one
; -----------------------------------------------------------------------------
    LDX #0                  ; X = band index.  0 = top band, 7 = bottom band.
PaintBand:
    LDA #DARK               ; assume a dark band...
    CPX Cursor              ; ...until X equals the cursor?  (CPX: X - Cursor)
    BNE +                   ; not equal (Z = 0) -> keep DARK
    LDA #BRIGHT             ; equal (Z = 1) -> this band is the cursor band
+   STA COLUBK              ; paint this band with the chosen color

    LDY #LINES              ; Y counts down the 24 scanlines of this band
-   STA WSYNC               ; wait for the end of the current scanline
    DEY                     ; one line fewer to go: 24, 23, ... 0
    BNE -                   ; loop until the line counter reaches 0

    INX                     ; count up: next band
    CPX #BANDS              ; have we painted all 8 bands?
    BNE PaintBand           ; no (Z = 0) -> loop back for the next band

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
    LDA #$02
    STA VBLANK
    +set_timer 35           ; ~30 scanlines of overscan
    +wait_timer

; -----------------------------------------------------------------------------
; GAME LOGIC — a countdown loop nested inside the frame loop
; -----------------------------------------------------------------------------
; This countdown is the animation clock.  One pass of the frame loop takes
; exactly one frame, and we drop the counter by one on every pass.  Only when
; it reaches 0 does the cursor move — so the bright band steps every 30
; frames, about half a second at the TV's ~60 frames per second.
    DEC StepTimer           ; one frame closer to the next step
    BNE NoStep              ; not 0 yet (Z = 0) -> the cursor stays put
    LDA #STEP_FRAMES        ; countdown reached 0 -> reload it...
    STA StepTimer
    INC Cursor              ; ...and walk the cursor down one band
    LDA Cursor
    CMP #BANDS              ; did it walk past the bottom band (7)?
    BNE NoStep              ; no (Z = 0) -> nothing more to do
    LDA #0                  ; yes -> wrap back to the top band.
    STA Cursor              ; (a compare-and-reset branch, not a wraparound)
NoStep:
    JMP StartFrame          ; next frame.  This jump is unconditional — the
                            ; frame loop simply repeats, so there is no flag to
                            ; test and JMP (not a branch) is the right tool.
                            ; Exercise 3 shows what happens when a loop body
                            ; grows past a branch's ~±127-byte reach.

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

> The complete, fully-commented source lives in
> `lessons/part1-6502-cpu/07-branches-and-loops/07-branches-and-loops.asm`.

### Code Walkthrough

#### Step 1 — The compare-then-branch decision

```asm
    LDA #DARK               ; assume a dark band...
    CPX Cursor              ; ...until X equals the cursor?  (CPX: X - Cursor)
    BNE +                   ; not equal (Z = 0) -> keep DARK
    LDA #BRIGHT             ; equal (Z = 1) -> this band is the cursor band
+   STA COLUBK              ; paint this band with the chosen color
```

Two registers, one compare, one branch. `CPX Cursor` subtracts the RAM byte from X and leaves **Z** set only when the two match. `BNE` skips the bright load when they differ, so the accumulator ends up holding whatever color this band should be, and `STA COLUBK` paints it. The `+` is an anonymous forward label — "branch over the next line".

This is the ROM's whole visual decision, and it happens eight times per frame, once per band.

#### Step 2 — One band, counted down

```asm
    LDY #LINES              ; Y counts down the 24 scanlines of this band
-   STA WSYNC               ; wait for the end of the current scanline
    DEY                     ; one line fewer to go: 24, 23, ... 0
    BNE -                   ; loop until the line counter reaches 0
```

`STA WSYNC` makes the CPU wait for the TV beam to finish the current scanline, so this loop paints exactly 24 lines of the chosen color. The counter counts **down**, so the `DEY` that reaches zero sets **Z** and `BNE` falls through — no compare needed. A count-up version of the same loop would have to ask `CPY #LINES` before every branch to know when it was done.

#### Step 3 — The band loop, counted up

```asm
    INX                     ; count up: next band
    CPX #BANDS              ; have we painted all 8 bands?
    BNE PaintBand           ; no (Z = 0) -> loop back for the next band
```

X is both the loop counter *and* the band index, which is why this loop counts **up**: the value X holds while painting band *n* is exactly what the next pass needs. The count-up loop pays one compare instruction for that luxury.

#### Step 4 — The animation countdown and the compare-and-reset branch

```asm
    DEC StepTimer           ; one frame closer to the next step
    BNE NoStep              ; not 0 yet (Z = 0) -> the cursor stays put
    LDA #STEP_FRAMES        ; countdown reached 0 -> reload it...
    STA StepTimer
    INC Cursor              ; ...and walk the cursor down one band
    LDA Cursor
    CMP #BANDS              ; did it walk past the bottom band (7)?
    BNE NoStep              ; no (Z = 0) -> nothing more to do
    LDA #0                  ; yes -> wrap back to the top band.
    STA Cursor
```

This block is the frame loop's "game logic": a countdown in RAM that turns a 60 Hz loop into a half-second tick. When the tick fires, the cursor steps down one band and is compared against 8. The wrap is a deliberate **compare-and-reset**: `INC Cursor` on its own would roll `$07` over to `$08`, `$09`, and eventually wrap at `$FF` — leaving screens with *no* bright band at all. Testing `CMP #BANDS` and resetting to `LDA #0` keeps the cursor inside 0…7 forever. (You can see this in the debugger: after eleven steps the cursor reads `$03`, not `$0B`.)

#### Step 5 — Why the frame loop ends with `JMP`

```asm
NoStep:
    JMP StartFrame          ; next frame
```

The frame loop has no condition to test: one frame simply follows another, forever. `JMP` is unconditional, three bytes long, and can reach anywhere — which is why it closes every main loop in this course. Branches are for *decisions*, and they come with the reach limit that Exercise 3 explores.

## What You Should See

Eight equal horizontal bands fill the screen — 24 scanlines each. One of them is **bright red** (`$42`); the other seven are **dark gray** (`$02`), and because they are all the same color they read as one dark field. The ladder's eight rungs are easiest to see *through the bright band*: it is exactly one eighth of the picture tall, and it moves.

These two captures are seven steps apart in the same cycle — first with the bright band on the **top** band:

![Stella running the Lesson 07 cursor-ladder ROM: eight equal bands fill the screen, the top band is bright red and the other seven dark gray](/images/lesson07/loop-cursor-top.png)

…and then with it on the **bottom** band, one step before the wrap:

![The same ROM captured later in the cycle: the bright red band has walked down the ladder and now sits on the bottom band](/images/lesson07/loop-cursor-bottom.png)

<RomPlayer rom="/roms/part1-6502-cpu/07-branches-and-loops/07-branches-and-loops.bin" title="Lesson 07 — Branches and Loops" />

Watch it for a few seconds: the bright band steps down one rung about every half second, reaches the bottom rung, then jumps straight back to the top in a single step — the compare-and-reset branch keeps the cursor inside 0–7, so the band never leaves the ladder. Nothing else on screen ever changes — the picture is held steady at 192 visible lines by the line loop in Step 2.

Now open the debugger (backtick `` ` ``) and check the numbers:

- **`$80`** — the cursor. It cycles `$00`, `$01`, … `$07` and back to `$00`, and the band on screen that is bright is always the one named by this byte. It resets only through the `CMP #BANDS` branch: after eleven steps it holds `$03` (not `$0B`), and a plain rolling-over increment would spend most of its time pointing at bands that do not exist.
- **`$81`** — the step countdown, counting `30 → 0` once per frame. When it reaches zero the cursor steps and the byte is reloaded with `30`. (Measured in the debugger: with the cursor on band 1 the countdown read `$0D`, i.e. 13 — seventeen frames into the current tick.)
- **`SP`** — stays `$FF`, exactly as `+clean_start` left it. Nothing in this program touches the stack pointer, so it cannot move; Lesson 08 puts it to work.
- **`X`** during the paint pass — the band index, `0…7`, and `8` at the moment the band loop exits. **`Y`** — the line counter, counting down to `0` once per band.

Single-step over the `CPX Cursor` in the band loop and watch **Z** flip in Stella's status display: one compare, one flag, one branch — the whole lesson in three instructions.

## Exercises

### Exercise 1: Twelve Bands, Counted Down

**Challenge:** Make the ladder *twelve* bands tall instead of eight, so each band is 16 scanlines (12 × 16 = 192), and paint it with a **count-down loop** instead of the lesson's count-up loop.

**Hints:**
1. A count-down band loop starts X at 11 and ends with `DEX` / `BPL`: `BPL` keeps looping while **N** is clear, and `DEX` finally rolls X from `$00` to `$FF`, setting **N** and ending the loop.
2. The band painted *first* lands at the top of the screen, so in this version band 11 is the top and band 0 is the bottom — which means the cursor has to count **down** too.
3. Wrap the cursor with `DEC Cursor` / `BPL` (still `0…11`?), resetting to 11 when **N** says it went below zero — that is the N-flag counterpart of the lesson's `CMP`-and-reset.

**Expected Result:** Twelve equal bands instead of eight, one bright red, still walking down the screen and wrapping from the bottom to the top — same motion, different loop shape and different ending flag.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: The Bouncing Cursor

**Challenge:** Replace the wrap with a **bounce**: the bright band walks down, reverses at the bottom band (7), walks back up, reverses at the top band (0), and repeats forever. A direction byte in RAM decides which way the cursor moves on each step.

**Hints:**
1. Keep two bytes: `Cursor` (`$80`) and `Direction` (`$82`) — `0` means "walking down", `1` means "walking up".
2. Test the direction with `BNE` (the Z flag) and jump to a "walk up" path: down is `INC Cursor`, up is `DEC Cursor`.
3. The two ends are caught differently: walking down, `CMP #7` notices the bottom band and flips the direction; walking up, `DEC` sets **N** as the cursor rolls from 0 to `$FF`, and `BPL` falls through exactly then, so put the cursor on band 1 and flip the direction back.

**Expected Result:** The bright band slides down all eight positions, bounces off the bottom, slides back up, bounces off the top — no wrap, no pause, no band ever skipped.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Out of Reach — When a Branch Cannot Get There *(Stretch Goal)*

**Challenge:** Make the ladder *crawl*: paint the eight bands **inline** (repeated code or a macro — no band loop), and time the cursor with a single countdown loop that wraps the **whole frame**, so the cursor steps once every 120 frames (about two seconds). Then close that loop with the natural `DEC StepTimer` / `BNE StartFrame` — the long inline body now puts `StartFrame` out of branch reach. Restructure the loop so it assembles and still crawls.

**Hints:**
1. A branch's target must be within −128…+127 bytes of the instruction that follows it. The solution's frame body is over 200 bytes, because it paints the eight bands *inline* (a macro expanded once per band) instead of with a band loop.
2. ACME rejects the long branch with `Target out of range (-206; 78 too far)`.
3. The fix is the branch-else-jump idiom: ask the *opposite* question with `BEQ` so the conditional jump is a short hop forward, then let an unconditional `JMP` cover the long way back.

**Expected Result:** The same eight-band ladder as the lesson ROM, but the bright band now steps once every ~2 seconds instead of twice a second — and the loop ends with `BEQ`/`JMP` instead of a single `BNE`.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **Eight branches, one flag each**: `BEQ`/`BNE` read **Z**, `BCS`/`BCC` read **C**, `BMI`/`BPL` read **N**, `BVS`/`BVC` read **V** — the compare sets the flags, the branch just looks at them
- ✅ **A branch is a conditional `goto`**: it has no memory of what was compared, so nothing may change the flag between the compare and the branch
- ✅ **Count down to zero** whenever the counter is just a counter: `DEY`/`DEX` set **Z** for free, so `DEY` + `BNE` is a complete loop with no compare
- ✅ **Count up** when the counter *is* your data (like a band index): `INX` + `CPX #limit` + `BNE` keeps the value and pays for one compare
- ✅ **Loops nest**: band loop inside frame loop, line loop inside band loop — and a RAM countdown inside the frame loop is how you slow 60 Hz down to half a second
- ✅ **Circular counters wrap by comparing**, not by rolling over: `INC` past the last value would leave gaps, so test with `CMP`/`CPX` and reset deliberately
- ✅ **`JMP` is unconditional and unlimited; branches reach only about ±127 bytes** — when a loop body outgrows that window, invert the test and `JMP` (Exercise 3)

## What's Next

Every loop so far has been flat code: the branch goes backwards and the CPU keeps the return address in its program counter. But real programs need to *call* things — paint a band, print a score, run a subroutine a hundred times — and that requires a place to remember where to come back to. In [Lesson 08: The Stack and Subroutines](/part1-6502-cpu/08-stack-and-subroutines) you meet the stack pointer, `JSR`/`RTS`, `PHA`/`PLA`, and the page-`$01` collision hazard that makes a deep call chain dangerous on the 2600.
