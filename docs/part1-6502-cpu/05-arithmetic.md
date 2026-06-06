---
title: "Lesson 05: Arithmetic — Adding and Subtracting"
description: "Put the accumulator to work: ADC and SBC, the all-important carry flag, the CLC-before-add / SEC-before-subtract rules, 8-bit wraparound, and how carry chains single bytes into 16-bit math."
prev:
  text: "Lesson 04: Registers and Memory"
  link: "/part1-6502-cpu/04-registers-and-memory"
next:
  text: "Lesson 06: Flags and Comparisons"
  link: "/part1-6502-cpu/06-flags-and-comparisons"
---

# Lesson 05: Arithmetic — Adding and Subtracting

> **Part 1: The 6502 CPU** · Estimated time: 45 minutes
> **Prerequisites:** Lesson 04 (registers, load/store, immediate & zero-page addressing)
> **You will learn:** `ADC` and `SBC`; the carry flag; the `CLC`-before-add and `SEC`-before-subtract rules; `INC`/`DEC`/`INX`/`DEX`; 8-bit wraparound; and how carry chains bytes into 16-bit math
> **You will build:** A "calculator" ROM that adds and subtracts two numbers and paints each result as a colored zone — plus a 16-bit addition you can inspect in the debugger

## Introduction

In Lesson 04 your registers only *carried* bytes around — load here, store there. Now they start to **compute**. This is the first lesson where the accumulator earns its name: the **A**ccumulator is the one register that can do arithmetic, and almost every number a game tracks — a score, a position, a countdown, a velocity — is maintained with the two instructions you'll meet here: `ADC` (add with carry) and `SBC` (subtract with borrow).

The 6502 only does **8-bit** math, so every result is implicitly taken *mod 256*: `$FF + 1` wraps back to `$00`, exactly like `(a + b) & 0xFF` in TypeScript. That "lost" overflow isn't really lost, though — it's captured in the **carry flag**, a single bit the CPU sets when an addition spills past 255 (or a subtraction needs to borrow). Carry is the hinge this whole lesson turns on: it's both the thing you must *initialize correctly* before every add or subtract, and the thing that lets you *stitch* 8-bit operations together into 16-bit (and bigger) numbers.

The companion program `05-arithmetic.asm` is a tiny calculator. It loads two numbers, computes their sum with `ADC` and their difference with `SBC`, and paints four colored bands so you can literally *see* each value. It then performs a 16-bit addition and tucks the two-byte result into RAM for you to find in the debugger.

::: details TypeScript Equivalent
On the 6502 every byte is a `Uint8`, so arithmetic always wraps at 256 — and the bit that "fell off the top" is the carry flag:

```typescript
// 8-bit math always wraps — just like masking to a byte:
const sum  = (0x30 + 0x12) & 0xFF;   // 0x42  — fits, no carry
const wrap = (0xFF + 0x01) & 0xFF;   // 0x00  — overflowed! carry = 1

// The carry flag is literally "did it exceed 255?":
const carry = (0xFF + 0x01) > 0xFF ? 1 : 0;  // 1

// 16-bit addition out of two 8-bit adds — carry chains the halves,
// exactly like ADC the low byte, then ADC the high byte:
function add16(a: number, b: number): number {
  const lo = (a & 0xFF) + (b & 0xFF);
  const loByte = lo & 0xFF;
  const carry  = lo > 0xFF ? 1 : 0;        // <- the 6502's carry flag
  const hi = ((a >> 8) & 0xFF) + ((b >> 8) & 0xFF) + carry;
  return ((hi & 0xFF) << 8) | loByte;
}
```

The catch the 6502 adds: there's no bare "add." Every add is *add-with-carry*, so **you** are responsible for setting carry to a known state first (`CLC` for a fresh add, `SEC` for a fresh subtract).
:::

## Theory

### Section 1: `ADC` — Add With Carry

The 6502 has exactly one addition instruction, and it always adds **three** things:

```
A  =  A  +  operand  +  carry
```

That `+ carry` is not optional — there is no plain "add." So before a *standalone* addition you must clear the carry with **`CLC`** (CLear Carry), guaranteeing the stray third term is 0:

```asm
    LDA NumA        ; A = $30
    CLC             ; carry = 0   <-- ALWAYS do this before a fresh ADC
    ADC NumB        ; A = $30 + $12 + 0 = $42
    STA Sum         ; Sum = $42
```

Forget the `CLC` and a leftover carry from some earlier operation silently adds an extra 1 — one of the most common 6502 bugs there is. The mnemonic to burn in: **"Clear before you add."**

If the true result exceeds `$FF`, `A` keeps only the low 8 bits and the **carry flag is set to 1** to record the overflow. That's not an error — it's the raw material for 16-bit math (Section 4).

### Section 2: `SBC` — Subtract With Borrow

Subtraction mirrors addition, but the carry flag plays the role of an **inverted borrow**:

```
A  =  A  -  operand  -  (1 - carry)
```

So **carry set (1) means "no borrow."** To start a clean subtraction you set the carry first with **`SEC`** (SEt Carry):

```asm
    LDA NumA        ; A = $30
    SEC             ; carry = 1  (= "no borrow")   <-- ALWAYS before a fresh SBC
    SBC NumB        ; A = $30 - $12 - 0 = $1E
    STA Diff        ; Diff = $1E
```

The pairing to memorize: **`CLC` before `ADC`, `SEC` before `SBC`.** They feel backwards at first (clear to add, *set* to subtract), but the logic is consistent: in both cases you're zeroing out the extra term so the very first operation is "clean."

After `SBC`, the carry tells you whether a borrow happened: **carry still set ⇒ no borrow** (the minuend was ≥ the subtrahend); **carry clear ⇒ it borrowed** (the result went negative and wrapped). You'll use that to compare numbers in Lesson 06.

::: tip PAL Note
Arithmetic is pure CPU — the 6507 behaves identically on NTSC and PAL machines. The `ADC`/`SBC`/carry rules in this lesson are timing- and region-independent. (The only place the 2600 changes math behavior is *decimal mode*, `SED`, which we deliberately avoid until Lesson 40 — `+clean_start` runs `CLD` to keep us in plain binary.)
:::

### Section 3: Wraparound, and the Quick Counters

Because results are 8-bit, they **wrap** silently:

| Operation | True value | Stored in A | Carry after |
|-----------|-----------|-------------|-------------|
| `$30 + $12` | 66 (`$42`) | `$42` | 0 (fit) |
| `$F0 + $25` | 277 (`$115`) | `$15` | 1 (overflow) |
| `$30 - $12` | 30 (`$1E`) | `$1E` | 1 (no borrow) |
| `$10 - $20` | −16 | `$F0` | 0 (borrowed) |

For the extremely common "just add or subtract one" case, the 6502 gives you single-instruction shortcuts that **don't touch carry** and don't go through A at all:

| Instruction | Effect | Works on |
|-------------|--------|----------|
| `INC addr` / `DEC addr` | memory byte ± 1 | a RAM/zero-page location |
| `INX` / `DEX` | X ± 1 | the X register |
| `INY` / `DEY` | Y ± 1 | the Y register |

You've already used `DEX` as a loop counter in every kernel so far. `INC`/`DEC` are perfect for things like a frame counter or a countdown timer (Exercise 2), since they update a variable in place without disturbing the accumulator.

::: details TypeScript Equivalent
```typescript
let frame: number = ram[0x84];
frame = (frame + 1) & 0xFF;   // INC $84  — wraps at 256
ram[0x84] = frame;

let x: number = 5;
x = (x - 1) & 0xFF;           // DEX
// INC/DEC/INX/DEX leave the carry flag untouched — unlike ADC/SBC.
```
:::

### Section 4: Carry Is the Glue — 16-Bit Addition

A single byte can't count past 255, but scores and positions routinely need more. The fix is to spread a number across **two bytes** (a low byte and a high byte) and let the carry flag carry the overflow from the low add into the high add — exactly like carrying a digit in long addition:

```asm
    ; 16-bit:  $00F0 + $0025  =  $0115
    LDA #$F0        ; low byte
    CLC             ; clear carry before the FIRST add only
    ADC #$25        ; $F0 + $25 = $115 -> A = $15, carry = 1
    STA SumLo       ; SumLo = $15
    LDA #$00        ; high byte
    ADC #$00        ; $00 + $00 + carry(1) = $01   <-- NO clc here!
    STA SumHi       ; SumHi = $01   ->  result $0115
```

The pattern is the whole point: **`CLC` once at the very start, then let each subsequent `ADC` inherit the carry from the one before it.** The low-byte add produced a carry of 1; the high-byte add folds it in automatically. Subtraction chains the same way with `SEC` once, then `SBC`, `SBC`, … This generalizes to 24-bit, 32-bit, or any width — it's how the 8-bit 6502 handled "big" numbers throughout the 8-bit era.

## The Code

### Building This Lesson

```bash
acme -f plain -o build/lesson05.bin \
  lessons/part1-6502-cpu/05-arithmetic/05-arithmetic.asm
stella build/lesson05.bin
```

### Full Source

The program computes a sum and a difference, performs a 16-bit add, then paints four 48-line zones — one per single-byte value — so each arithmetic result is visible on screen.

```asm
; =============================================================================
; LESSON 05: Arithmetic — Adding and Subtracting
; =============================================================================
    !cpu 6502
    !source "include/vcs.asm"
    !source "include/macro.asm"

; --- RAM VARIABLES (RIOT RAM, $80-$FF) ---
NumA        = $80    ; first operand
NumB        = $81    ; second operand
Sum         = $82    ; NumA + NumB  (8-bit, wraps mod 256)
Diff        = $83    ; NumA - NumB  (8-bit, borrows mod 256)
SumLo       = $84    ; low  byte of the 16-bit sum
SumHi       = $85    ; high byte of the 16-bit sum

    * = $F000

Reset:
    +clean_start            ; zero RAM/TIA, set stack — and CLD (binary math)

    ; --- Set up the two operands ---
    LDA #$30            ; A = $30 (48)
    STA NumA
    LDA #$12            ; A = $12 (18)
    STA NumB

    ; --- ADD: Sum = NumA + NumB ---
    LDA NumA            ; A = $30
    CLC                 ; carry = 0   (essential before ADC!)
    ADC NumB            ; A = $30 + $12 + 0 = $42
    STA Sum             ; Sum = $42

    ; --- SUBTRACT: Diff = NumA - NumB ---
    LDA NumA            ; A = $30
    SEC                 ; carry = 1 (= "no borrow"; essential before SBC!)
    SBC NumB            ; A = $30 - $12 - 0 = $1E
    STA Diff            ; Diff = $1E

    ; --- 16-BIT ADD: SumHi:SumLo = $00F0 + $0025 = $0115 ---
    LDA #$F0
    CLC                 ; clear carry before the low-byte add
    ADC #$25            ; $F0 + $25 = $115 -> A = $15, carry = 1
    STA SumLo           ; SumLo = $15
    LDA #$00
    ADC #$00            ; $00 + $00 + carry(1) = $01   (no CLC here!)
    STA SumHi           ; SumHi = $01  ->  full result $0115

StartFrame:
    +vsync                  ; new frame

    LDA #$02
    STA VBLANK
    +set_timer 43
    +wait_timer
    LDA #$00
    STA VBLANK

    ; --- KERNEL: four 48-line zones, one per computed value ---
    LDA NumA            ; Zone 1: NumA ($30)
    STA COLUBK
    LDX #48
-   STA WSYNC
    DEX
    BNE -

    LDA NumB            ; Zone 2: NumB ($12)
    STA COLUBK
    LDX #48
-   STA WSYNC
    DEX
    BNE -

    LDA Sum             ; Zone 3: Sum ($42)
    STA COLUBK
    LDX #48
-   STA WSYNC
    DEX
    BNE -

    LDA Diff            ; Zone 4: Diff ($1E)
    STA COLUBK
    LDX #48
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

> The complete, fully-commented source — including the extended teaching comments — lives in
> `lessons/part1-6502-cpu/05-arithmetic/05-arithmetic.asm`.

### Code Walkthrough

#### The two operands

```asm
    LDA #$30
    STA NumA            ; NumA = $30 (48)
    LDA #$12
    STA NumB            ; NumB = $12 (18)
```

Nothing new here — straight from Lesson 04. These are the inputs our calculator will add and subtract.

#### Add (CLC + ADC) and subtract (SEC + SBC)

```asm
    LDA NumA
    CLC                 ; clear before add
    ADC NumB            ; $30 + $12 = $42
    STA Sum

    LDA NumA
    SEC                 ; set before subtract
    SBC NumB            ; $30 - $12 = $1E
    STA Diff
```

This is the heart of the lesson. Notice each operation **reloads `A` first** (the accumulator is the only place math happens), **prepares the carry** (`CLC`/`SEC`), runs the operation, then **stores the result** to RAM. Load → compute → store, just like Lesson 04, but now with a real computation in the middle.

#### Chaining carry for 16-bit

```asm
    LDA #$F0
    CLC
    ADC #$25            ; low half overflows: A=$15, carry=1
    STA SumLo
    LDA #$00
    ADC #$00            ; carry folds into the high half: A=$01
    STA SumHi
```

`SumLo`/`SumHi` end up holding `$15`/`$01` — the little-endian halves of `$0115` (277). The only `CLC` is before the *first* add; the second `ADC` deliberately keeps the carry.

#### The kernel — four zones

Each 48-line zone reads one computed byte back from RAM and writes it to `COLUBK`, so the screen becomes a bar chart of your arithmetic. `4 × 48 = 192` visible scanlines, the same total as Lesson 04's three 64-line zones.

## What You Should See

When you run this ROM in Stella, the screen splits into **four horizontal bands**, top to bottom: `NumA` (`$30`), `NumB` (`$12`), their **sum** `$42`, and their **difference** `$1E`. Because each value is fed straight into the background-color register, the colors *are* the numbers — change the operands and the bands shift accordingly.

![Stella running the Lesson 05 calculator ROM — four horizontal color bands, one each for NumA, NumB, their sum, and their difference, stacked top to bottom](/images/lesson05/calculator-demo.png)

<RomPlayer rom="/roms/part1-6502-cpu/05-arithmetic/05-arithmetic.bin" title="Lesson 05 — Arithmetic Calculator" />

Now open the debugger (backtick `` ` ``) and read the RAM view:

- **`$80`** = `$30` (NumA), **`$81`** = `$12` (NumB)
- **`$82`** = `$42` (Sum = `$30 + $12`)
- **`$83`** = `$1E` (Diff = `$30 - $12`)
- **`$84`/`$85`** = `$15`/`$01` — the low/high bytes of the 16-bit sum `$0115`

Try stepping through the `CLC`/`ADC` and `SEC`/`SBC` instructions and watch the **C** flag in the status display flip — that single bit is the star of this lesson.

## Exercises

### Exercise 1: Add Two 16-Bit Numbers

**Challenge:** Add `$01F0` and `$0220` (result `$0410`) using two-byte arithmetic, then display both result bytes as colored zones to prove the carry chained correctly.

**Hints:**
1. Store each number as two bytes: a low byte and a high byte.
2. `CLC` once, `ADC` the low bytes, store the low result — the carry is now set if the low add overflowed.
3. **Do not** `CLC` again. `ADC` the high bytes; the carry from step 2 folds in automatically.

**Expected Result:** Two colored bands for the high (`$04`) and low (`$10`) result bytes. In the debugger, `$84`/`$85` hold `$10`/`$04` — i.e. `$0410`.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: A Countdown Timer Variable

**Challenge:** Keep a one-byte timer in RAM that counts **down** by one every frame, and reloads to its starting value when it reaches zero — looping forever. Show the timer as the background color so you can watch it ramp and reset.

**Hints:**
1. Use `DEC` on the timer's RAM address once per frame — it's a single instruction and leaves carry alone.
2. `DEC` sets the zero flag when the result is `0`; use `BNE` to skip the reload until then.
3. Put the tick in the VBLANK "game logic" gap, before the kernel.

**Expected Result:** The whole screen smoothly cycles through colors as the timer counts down, then jumps back to the start color when it hits zero — a repeating ramp.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Detect Overflow *(Stretch Goal)*

**Challenge:** Add two bytes and detect whether the sum **overflowed** past `$FF`. Paint the screen green when it fits and red when it overflows — decided purely by the carry flag.

**Hints:**
1. After `CLC`/`ADC`, the **carry** is your unsigned-overflow signal: `1` means the true sum was > 255.
2. `BCC` (Branch if Carry Clear) branches when the result fit; otherwise it overflowed.
3. Try operands like `$D0 + $50` (overflows) versus `$30 + $50` (fits) to see both colors.

**Expected Result:** With overflowing operands the screen is red; with fitting operands it's green. The debugger shows the wrapped sum at `$80` and a `0`/`1` overflow flag at `$81`.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ The accumulator (`A`) is the **only** register that does arithmetic — load into A, compute, store back out
- ✅ There's no plain add/subtract: it's always `ADC`/`SBC`, so you must prepare the carry first — **`CLC` before `ADC`, `SEC` before `SBC`**
- ✅ On the 6502 a **set carry means "no borrow"** for subtraction (the carry is an inverted borrow)
- ✅ 8-bit math **wraps mod 256**; the bit that overflows is captured in the **carry flag**, not lost
- ✅ Carry is the **glue for multi-byte math**: `CLC`/`SEC` once, then let each `ADC`/`SBC` inherit the carry to build 16-bit (or larger) values
- ✅ `INC`/`DEC`/`INX`/`DEX`/`INY`/`DEY` add or subtract one **without touching carry** — ideal for counters and timers

## What's Next

You've seen the carry flag set and cleared as a side effect of arithmetic — but it's only one of several **status flags** the CPU keeps. In [Lesson 06: Flags and Comparisons](/part1-6502-cpu/06-flags-and-comparisons), you'll meet the zero, negative, and overflow flags too, learn the `CMP`/`CPX`/`CPY` instructions, and turn those flags into real decisions — the groundwork for branches and loops in Lesson 07.
