---
title: "Lesson 06: Flags and Comparisons — How the CPU Decides"
description: "Meet the processor status register: the Zero, Negative, Carry, and oVerflow flags, the CMP/CPX/CPY instructions, and how a comparison is really a throwaway subtraction that leaves behind the flags every branch depends on."
prev:
  text: "Lesson 05: Arithmetic — Adding and Subtracting"
  link: "/part1-6502-cpu/05-arithmetic"
next:
  text: "Lesson 07: Branches and Loops"
  link: "/part1-6502-cpu/07-branches-and-loops"
---

# Lesson 06: Flags and Comparisons — How the CPU Decides

> **Part 1: The 6502 CPU** · Estimated time: 45 minutes
> **Prerequisites:** Lesson 05 (`ADC`/`SBC`, the carry flag, `SEC`/`CLC`)
> **You will learn:** the processor status register (P); the **Z**, **N**, **C**, and **V** flags; the `CMP`/`CPX`/`CPY` instructions; how comparison maps to `<`, `==`, and `>=`; and how flags become decisions
> **You will build:** a "comparison" ROM that runs three `CMP`s, captures the resulting flags into RAM for the debugger, and paints a green/red truth-table on screen

## Introduction

Every program that does anything interesting has to **decide**: is the score high enough? did the player hit the wall? has the timer run out? In Lesson 05 you saw the carry flag appear as a *side effect* of arithmetic. This lesson zooms out to the full set of one-bit answers the CPU keeps on hand — the **status flags** — and introduces the instructions whose entire job is to *set those flags so you can branch on them*.

The 6502 stores these flags together in a single 8-bit register called the **processor status register**, usually written **P**. You never load or store P directly in day-to-day code; instead, almost every instruction **updates** some of its bits as a by-product, and the branch instructions you'll meet in Lesson 07 **read** them. Flags are the invisible wire connecting "do some math" to "now act on the result."

The star instruction here is **`CMP`** (CoMPare). It answers "how does A relate to this value?" — less than, equal, or greater — and it does so by performing a subtraction it immediately **throws away**, keeping only the flags. The companion program `06-flags-and-comparisons.asm` runs three comparisons, records the Z/C/N flags of the first one into RAM so you can inspect them in the debugger, and turns each comparison's outcome into an on-screen color: **green** when `A >= B`, **red** when `A < B`.

::: details TypeScript Equivalent
In TypeScript the comparison operators *return* a boolean. On the 6502 a comparison instead *sets flags*, and you read those flags afterward:

```typescript
// TypeScript hands you a boolean directly:
const equal    = (a === b);
const aIsLess  = (a < b);     // unsigned
const aGeOrEq  = (a >= b);

// The 6502 way: CMP performs (a - b), discards the result, and leaves:
//   Z = (a === b)            -> "were they equal?"
//   C = (a >= b)  unsigned   -> "no borrow happened"
//   N = bit 7 of (a - b)     -> sign of the difference
function cmp(a: number, b: number) {
  const diff = (a - b) & 0xFF;     // the subtraction CMP throws away
  return {
    Z: a === b ? 1 : 0,
    C: a >= b  ? 1 : 0,            // unsigned >=
    N: (diff & 0x80) ? 1 : 0,
  };
}
```

The key mental shift: a 6502 comparison doesn't *give* you a yes/no — it *leaves flags behind* that the next branch instruction reads.
:::

## Theory

### Section 1: The Processor Status Register (P)

The 6502 keeps its flags packed into one 8-bit register. Seven of the eight bits are used:

| Bit | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|-----|---|---|---|---|---|---|---|---|
| Flag | **N** | **V** | – | **B** | **D** | **I** | **Z** | **C** |
| Name | Negative | oVerflow | (unused) | Break | Decimal | Interrupt | Zero | Carry |

For Part 1 you care about four of them:

| Flag | Set when… | The question it answers |
|------|-----------|-------------------------|
| **Z** (Zero) | the last result was `$00` | "was it zero / were they equal?" |
| **N** (Negative) | bit 7 of the last result is 1 | "is it negative (as a signed byte)?" |
| **C** (Carry) | an add overflowed, **or** a compare/subtract didn't borrow | "unsigned: was it ≥?" |
| **V** (oVerflow) | a *signed* add/subtract crossed the ±128 boundary | "did signed math overflow?" |

You already met **D** (decimal) — `+clean_start` runs `CLD` to keep it off — and **I**/**B** relate to interrupts, which the 6507 in the 2600 never uses. The two you'll lean on most this lesson are **Z** and **C**.

::: tip PAL Note
Flags and comparisons are pure CPU behavior — the 6507 sets N, V, Z, and C identically on NTSC and PAL machines. Nothing in this lesson is timing- or region-dependent. (The only flag with region-flavored history is **D**, decimal mode, which we still avoid until Lesson 40.)
:::

### Section 2: Flags Are a Side Effect of (Almost) Everything

Most instructions silently update Z and N based on the value they produce. An `LDA` that loads `$00` sets Z; an `LDA` that loads `$80`–`$FF` sets N (because bit 7 is on). This is why you can often *skip* an explicit compare:

```asm
    LDA Lives       ; loading also updates Z and N…
    BEQ GameOver    ; …so you can branch on "Lives == 0" immediately
```

Knowing *which* instructions touch *which* flags is part of learning the 6502, but the rule of thumb is simple: **anything that produces a value in a register usually updates Z and N**; only `ADC`, `SBC`, and the compares touch **C**; only `ADC`/`SBC` touch **V**.

### Section 3: `CMP` — Compare by Subtracting and Throwing It Away

`CMP` is the workhorse. Mechanically it computes `A - operand` **exactly like `SBC` with carry pre-set**, but it does **not** store the result anywhere — `A` is left untouched. All it leaves behind are the flags:

```
CMP operand   ≈   (A - operand), keep only Z, C, N — A is unchanged
```

That gives you three comparisons for the price of one instruction:

| You want | Flag to test | Branch (Lesson 07) |
|----------|--------------|--------------------|
| `A == operand` | **Z = 1** | `BEQ` |
| `A != operand` | **Z = 0** | `BNE` |
| `A >= operand` (unsigned) | **C = 1** | `BCS` |
| `A <  operand` (unsigned) | **C = 0** | `BCC` |

The carry rule is the same "set carry means no borrow" idea from Lesson 05: if `A` is big enough that the subtraction *doesn't borrow*, carry stays set — which is exactly `A >= operand`. Memorize this pair:

- **`BEQ`/`BNE`** read **Z** → equality
- **`BCS`/`BCC`** read **C** → unsigned ordering (`>=` / `<`)

::: details TypeScript Equivalent
```typescript
// CMP sets the flags; the branch reads them. Written out longhand:
function compareAndAct(a: number, b: number) {
  // --- CMP #b ---
  const diff = (a - b) & 0xFF;
  const Z = (a === b);
  const C = (a >= b);          // unsigned >=
  // --- the branches you'd use next lesson ---
  if (Z)  { /* BEQ: equal      */ }
  if (!Z) { /* BNE: not equal  */ }
  if (C)  { /* BCS: a >= b      */ }
  if (!C) { /* BCC: a <  b      */ }
}
```
:::

### Section 4: `CPX` and `CPY` — Comparing the Index Registers

`CMP` only compares against the accumulator. The X and Y registers get their own compare instructions, **`CPX`** and **`CPY`**, which work identically but against X or Y:

```asm
    LDX #10
    CPX #10         ; X - 10 -> Z=1 (equal), C=1 (X >= 10)
```

These are how you test loop counters. You've been ending loops with `DEX` / `BNE` — that works because `DEX` updates Z. But when you need to compare a counter to a *specific* non-zero limit, `CPX #limit` / `CPY #limit` is the tool. A very common pattern counts **up** to a limit:

```asm
    LDX #0
Loop:
    ; … do something with X …
    INX
    CPX #8          ; reached 8 yet?
    BNE Loop        ; no -> keep going  (loops for X = 0..7)
```

### Section 5: Signed vs Unsigned — Why Both C and N Exist

`CMP` gives you an honest **unsigned** comparison through the carry flag. But bytes are sometimes meant as **signed** values (`$FF` = −1, `$80` = −128). For signed comparisons the carry alone isn't enough — you'd combine **N** and **V**. We won't write signed comparisons until later, but it's worth knowing *why* there are two "sign-ish" flags:

- **C** answers the **unsigned** question ("is the bit pattern larger?")
- **N** and **V** together answer the **signed** question ("is the number larger?")

For now, every comparison in this lesson is unsigned, so **carry is the ordering flag** and N is just along for the ride as "bit 7 of the difference."

## The Code

### Building This Lesson

```bash
acme -f plain -o build/lesson06.bin \
  lessons/part1-6502-cpu/06-flags-and-comparisons/06-flags-and-comparisons.asm
stella build/lesson06.bin
```

### Full Source

The program runs three comparisons. For the first (`$40` vs `$40`) it snapshots the Z, C, and N flags into RAM so you can read them in the debugger. For all three it converts the carry into a color — **green** for `A >= B`, **red** for `A < B` — and paints one 64-line zone per comparison.

```asm
; =============================================================================
; LESSON 06: Flags and Comparisons — How the CPU Decides
; =============================================================================
    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- Color constants (NTSC) ---
GREEN       = $C8       ; "A >= B" — comparison passed
RED         = $44       ; "A <  B" — comparison failed

; --- RAM VARIABLES (RIOT RAM, $80-$FF) ---
FlagZ       = $80       ; 1 if the first compare was EQUAL      (Z flag)
FlagC       = $81       ; 1 if the first compare had A >= B     (C flag)
FlagN       = $82       ; 1 if (A - B) had bit 7 set            (N flag)
Color1      = $83       ; result color for pair 1 (equal)
Color2      = $84       ; result color for pair 2 (less)
Color3      = $85       ; result color for pair 3 (greater)

    * = $F000

Reset:
    +clean_start            ; zero RAM/TIA, set stack, CLD (binary math)

    ; --- PAIR 1: $40 vs $40 (EQUAL) — capture all three flags into RAM ---
    LDA #$40            ; A = $40
    CMP #$40            ; compare A with $40 (internally A - $40, flags only)

    LDX #$00            ; capture Z (1 = equal)
    BNE +
    LDX #$01
+   STX FlagZ           ; FlagZ = 1

    LDX #$00            ; capture C (1 = A >= operand)
    BCC +
    LDX #$01
+   STX FlagC           ; FlagC = 1

    LDX #$00            ; capture N (1 = bit 7 of A-operand set)
    BPL +
    LDX #$01
+   STX FlagN           ; FlagN = 0

    LDA #$40            ; pick pair 1's color from the carry
    CMP #$40
    LDX #RED
    BCC +
    LDX #GREEN
+   STX Color1          ; equal counts as ">=" -> GREEN

    ; --- PAIR 2: $20 vs $60 (A < B) -> RED ---
    LDA #$20
    CMP #$60            ; borrows -> carry CLEAR
    LDX #RED
    BCC +
    LDX #GREEN
+   STX Color2

    ; --- PAIR 3: $90 vs $30 (A > B) -> GREEN ---
    LDA #$90
    CMP #$30            ; no borrow -> carry SET
    LDX #RED
    BCC +
    LDX #GREEN
+   STX Color3

StartFrame:
    +vsync                  ; new frame

    LDA #$02
    STA VBLANK
    +set_timer 43
    +wait_timer
    LDA #$00
    STA VBLANK

    ; --- KERNEL: three 64-line zones, one per comparison result ---
    LDA Color1          ; Zone 1: equal   -> GREEN
    STA COLUBK
    LDX #64
-   STA WSYNC
    DEX
    BNE -

    LDA Color2          ; Zone 2: less    -> RED
    STA COLUBK
    LDX #64
-   STA WSYNC
    DEX
    BNE -

    LDA Color3          ; Zone 3: greater -> GREEN
    STA COLUBK
    LDX #64
-   STA WSYNC
    DEX
    BNE -

    LDA #$02
    STA VBLANK
    +set_timer 35
    +wait_timer

    JMP StartFrame

; --- VECTORS ---
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

> The complete, fully-commented source lives in
> `lessons/part1-6502-cpu/06-flags-and-comparisons/06-flags-and-comparisons.asm`.

### Code Walkthrough

#### Comparing, then reading the flags

```asm
    LDA #$40
    CMP #$40            ; A - $40 internally; A stays $40, only flags change
    LDX #$00
    BNE +               ; Z clear? skip (values differed)
    LDX #$01            ; Z set -> they were equal
+   STX FlagZ
```

`CMP` does the subtraction `$40 - $40 = $00`, which sets **Z**. The result `$00` is *not* stored — `A` is still `$40`. We then test the flag with a branch and record a clean `0`/`1` into RAM. The same pattern repeats for **C** (using `BCC`) and **N** (using `BPL`).

::: tip Anonymous labels
The `+` after each `BNE`/`BCC`/`BPL` is ACME's **forward anonymous label** — it means "the next `+` line." It's perfect for these tiny two-way skips where inventing a unique name would just add noise. You first saw `-` (backward) labels as loop tops; `+` is its forward-jumping sibling.
:::

#### Turning a comparison into a color

```asm
    LDA #$20
    CMP #$60            ; $20 < $60 -> borrow -> carry CLEAR
    LDX #RED
    BCC +               ; carry clear (A < B)? keep RED
    LDX #GREEN          ; else A >= B -> GREEN
+   STX Color2
```

This is the comparison idiom you'll use constantly: **load, compare, branch on carry, store the chosen value.** Pair 2 has `A < B`, so carry is clear, `BCC` is taken, and the color stays `RED`. Pairs 1 and 3 leave carry *set*, so the branch falls through to `GREEN`.

#### The kernel — three zones

Each 64-line zone reads one result color from RAM into `COLUBK`. `3 × 64 = 192` visible scanlines — the same total you used in Lesson 04. The screen becomes a literal truth-table of the three comparisons.

## What You Should See

When you run this ROM in Stella, the screen splits into **three horizontal bands**: **green** (pair 1, `$40 == $40`, so `>=` holds), **red** (pair 2, `$20 < $60`), and **green** again (pair 3, `$90 > $30`). The colors *are* the comparison results — green means the carry was set (`A >= B`), red means it was clear (`A < B`).

![Stella running the Lesson 06 comparison ROM — three horizontal bands, green then red then green, one per CMP result](/images/lesson06/comparison-demo.png)

<RomPlayer rom="/roms/part1-6502-cpu/06-flags-and-comparisons/06-flags-and-comparisons.bin" title="Lesson 06 — Flags and Comparisons" />

Now open the debugger (backtick `` ` ``) and read the RAM view for the first comparison's captured flags:

- **`$80`** = `$01` — **Z** was set (`$40 == $40`, equal)
- **`$81`** = `$01` — **C** was set (`$40 >= $40`)
- **`$82`** = `$00` — **N** was clear (`$40 - $40 = $00`, bit 7 off)
- **`$83`/`$84`/`$85`** = `$C8`/`$44`/`$C8` — the three zone colors (green/red/green)

Single-step the three `CMP` instructions and watch the **N**, **Z**, and **C** indicators in Stella's status display flip. Seeing the flags change as the operands change is the whole point — those bits are what every branch in Lesson 07 will read.

## Exercises

### Exercise 1: Predict the Flags

**Challenge:** Before running anything, predict the **Z**, **C**, and **N** flags for `A = $50` compared against `$50`, `$80`, and `$10`. Then capture all three flags for each comparison into RAM and check your predictions in the debugger.

**Hints:**
1. `CMP` computes `A - operand` and keeps only the flags — work each subtraction on paper.
2. **Z** = "result was `$00`"; **C** = "`A >= operand`, no borrow"; **N** = "bit 7 of the difference."
3. Capture each flag the same way the lesson does: zero a register, branch on the flag, set it to `1`.

**Expected Result:** In the debugger: `$50` vs `$50` → Z=1 C=1 N=0; `$50` vs `$80` → Z=0 C=0 N=1; `$50` vs `$10` → Z=0 C=1 N=0.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Max of Two Values

**Challenge:** Given two bytes `ValA` and `ValB`, compute the **larger** of the two with a single `CMP` and a single branch, store it in `Max`, and paint the whole screen with the winning value.

**Hints:**
1. Load `ValA`, then `CMP ValB`. Carry **set** means `ValA >= ValB` — `ValA` is already the max.
2. Use `BCS` to *keep* `A` when `ValA` wins; otherwise fall through and `LDA ValB`.
3. This is `if (a < b) a = b;` expressed as one compare plus one branch.

**Expected Result:** With `ValA = $30`, `ValB = $90`, the screen takes color `$90` and `Max` (`$82`) holds `$90`.

**Solution:** See `exercise-02-solution.asm`

## Key Takeaways

- ✅ The 6502 keeps its decision bits in the **processor status register (P)** — you rarely touch it directly; instructions update it and branches read it
- ✅ The four flags that matter in Part 1 are **Z** (zero/equal), **N** (negative/bit 7), **C** (carry/unsigned `>=`), and **V** (signed overflow)
- ✅ Most instructions update **Z** and **N** as a side effect — you can often branch right after an `LDA` without a separate compare
- ✅ **`CMP` is a throwaway subtraction**: it computes `A - operand`, discards the result, and leaves **Z**, **C**, **N** — leaving `A` unchanged
- ✅ For unsigned comparisons: **`BEQ`/`BNE`** test equality via **Z**; **`BCS`/`BCC`** test ordering (`>=` / `<`) via **C**
- ✅ **`CPX`/`CPY`** do the same against the X and Y registers — ideal for counting loops up to a limit

## What's Next

You now have flags *and* the comparisons that set them — but so far you've only *captured* them into RAM. In [Lesson 07: Branches and Loops](/part1-6502-cpu/07-branches-and-loops) you'll put them to work for real: the full family of branch instructions (`BEQ`, `BNE`, `BCS`, `BCC`, `BMI`, `BPL`), structured loops, and the conditional control flow that turns a list of instructions into an actual program.
