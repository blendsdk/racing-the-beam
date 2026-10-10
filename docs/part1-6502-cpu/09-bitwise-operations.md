---
title: "Lesson 09: Bitwise Operations — The Power of Bits"
description: "Treat one byte as eight independent bits: AND, ORA, and EOR to test, set, clear, and toggle flags; ASL/LSR and ROL/ROR to move bits through the carry; and the mask, packing, and carry-reload idioms every Atari 2600 program leans on."
prev:
  text: "Lesson 08: The Stack and Subroutines"
  link: "/part1-6502-cpu/08-stack-and-subroutines"
next:
  text: "Lesson 10: Addressing Modes"
  link: "/part1-6502-cpu/10-addressing-modes"
---

# Lesson 09: Bitwise Operations — The Power of Bits

> **Part 1: The 6502 CPU** · Estimated time: 45 minutes
> **Prerequisites:** Lesson 01 (binary, hexadecimal, and bitmasks), Lesson 07 (branches and loops), Lesson 08 (subroutines and register contracts)
> **You will learn:** the three logic instructions (`AND`, `ORA`, `EOR`) and what each is for; testing a single bit with `AND` + a branch; the shifts (`ASL`, `LSR`) and rotates (`ROL`, `ROR`), and the carry flag as the bit that fell off; how `AND`/`ORA`/`EOR` and the shifts set **Z** and **N** from their results; and packing two nibbles into one byte
> **You will build:** a "bit ladder" ROM — eight bands, one per bit of a pattern byte, with exactly one band bright green; the bright band climbs the ladder one step every half second, and the bit that leaves through bit 7 comes out in the carry, where `BCS` catches it and starts the walk over

## Introduction

Lesson 08 gave you a way to share code; this lesson changes what a byte *is*. Every lesson so far has treated a byte as a number: add it, subtract it, compare it, count with it. But 6502 arithmetic has no notion of individual bits — `$01 + $01` is `$02` and nothing politely says "bit 1 is now set." Games need that sentence constantly. A joystick direction, a "have I entered this room before" flag, a "which players are alive" byte, the four-bit size field in a TIA register: real 2600 code packs *many* yes/no values into single bytes, and then reads and writes them one bit at a time.

The instructions that do this are the **logic instructions** — `AND`, `ORA`, `EOR` — and the four **shift/rotate** instructions, `ASL`, `LSR`, `ROL`, `ROR`. There are only seven of them, and each one is a single, narrow promise: "combine these bits this way," or "move the bits along and hand me the one that fell off." That is enough to test bits, set them, clear them, toggle them, multiply and divide by powers of two, pack two nibbles into a byte — and to turn the carry flag into a ninth bit of storage.

The companion program `09-bitwise-operations.asm` makes all of it visible as a **bit ladder**: eight bands of 24 scanlines, one band per *bit* of a pattern byte at RAM `$80`. The top band shows bit 7, the bottom band bit 0, and exactly one bit of the pattern is set — so exactly one band is bright green and the other seven are dark gray. The pattern starts at `%00000001`, which puts the bright band at the bottom. Every half second `ASL` shifts the pattern one place to the left: bit 0 becomes bit 1, then bit 2, and the bright band climbs one rung. When the single set bit finally reaches bit 7 and is shifted out of the byte, it arrives in the **carry flag**, and a `BCS` notices: the pattern reloads `%00000001` and the climb begins again from the bottom.

::: details TypeScript Equivalent
TypeScript has the same operators — this is the rare corner where the 6502 and a modern language use the *same* symbols for the *same* ideas:

```typescript
let pattern = 0b00000001;

pattern |= 0b00000100;        // ORA — set bit 2
pattern &= 0b11011111;        // AND — clear bit 5
pattern ^= 0b10000000;        // EOR — toggle bit 7
const bit5 = (pattern & 0b00100000) !== 0;   // test a bit -> a boolean
const doubled = (pattern << 1) & 0xFF;        // ASL — shift left, keep 8 bits
const high = pattern >>> 4;                   // LSR x4 — move the top nibble down
```

The symbols line up; the differences are all about what the hardware *keeps*:

- **One byte, always.** A 6502 register is 8 bits — never 32, never `number`. `pattern << 1` in TypeScript can grow a value; `ASL` cannot: the bit that passes bit 7 has to go *somewhere*, and where it goes is the carry flag.
- **The flags are a second result.** Every logic and shift instruction also reports "was the result zero?" (**Z**) and "is bit 7 set?" (**N**) in the processor status register, so the very next branch can act on it. TypeScript computes a value and stops.
- **No booleans.** There is no `true`/`false` type to hold: a mask of `0b00000100` *is* "bit 2", and `AND #%00000100` *is* the test. The zero flag is the boolean.
- **No `>>>` vs `>>` distinction, no sign extension.** `LSR` always shifts 0 into bit 7, no matter what bit 7 was; there is no arithmetic shift.
:::

## Theory

### Section 1: The Three Logic Instructions

All three logic instructions compare two bytes bit by bit and build a result the same width — eight independent one-bit questions, answered eight times. The truth table is the whole story:

| A bit | B bit | `AND` | `ORA` | `EOR` |
|:-----:|:-----:|:-----:|:-----:|:-----:|
| 0 | 0 | 0 | 0 | 0 |
| 0 | 1 | 0 | 1 | 1 |
| 1 | 0 | 0 | 1 | 1 |
| 1 | 1 | 1 | 1 | 0 |

Read each column as one sentence about the *second* operand:

- **`AND` keeps a bit only where the operand's bit is 1.** Where the operand has a 1, the original bit passes through; where it has a 0, the result is forced to 0. That makes `AND` the **clear** and **extract** instruction: `AND #%00001111` keeps the low nibble and throws the high nibble away.
- **`ORA` sets every bit where the operand's bit is 1**, and leaves the rest alone. It is the **set** instruction: `ORA #%00000100` forces bit 2 on.
- **`EOR` (exclusive OR) flips a bit where the operand's bit is 1**, and leaves the rest alone. It is the **toggle**: `EOR #%10000000` turns bit 7 off if it was on, and on if it was off. XORing the same mask twice is the identity — the basis for toggling a flag, blinking an object, or swapping two bytes without a third.

All three can take an immediate (`#`), a zero-page byte, or an absolute address; in this lesson's kernel the tests use `AND` with a zero-page operand, which takes 3 cycles (`AND #` immediate takes 2). And all three set the **Z** and **N** flags from their result:

```
    LDA #%11110000
    AND #%00000001      ; result %00000000 -> Z = 1
    ORA #%10000000      ; result %10000000 -> Z = 0, N = 1 (bit 7 set)
```

That "flags from the result" behavior is what turns a logic instruction into a decision. It also means the disassembly is honest about the test idiom: **`AND #mask` + `BEQ`/`BNE` is "is this bit set?"** — the AND does double duty as operation and comparison.

::: tip Logic vs. arithmetic: two different carry stories
`ADC`/`SBC` set the carry from *arithmetic* — a carry out of bit 7, or "no borrow". The logic instructions **do not touch the carry at all**: `AND`, `ORA`, and `EOR` answer questions about bits, not about sums. (The shifts do set it — the bit that falls off lands there — which is Section 3.) If you ever wrote `CLC` before an `AND` expecting something, this is why nothing happened.
:::

### Section 2: Testing a Bit — `AND` + a Branch

Here is the pattern the lesson ROM uses eight times per frame, and the one you will write most often in your own code:

```asm
    LDA Mask            ; A = the mask for this band (%01000000 first)
    AND Pattern         ; 0 when this band's bit is 0
    BEQ BandDark        ; Z = 1 -> dark gray
```

`AND` produces zero exactly when the two bytes have **no set bit in common** — and since the mask has exactly one bit set, zero means *that one bit was 0*. The branch reads the **Z** flag that `AND` just left behind. No compare, no subtraction, no temporary: two instructions and a branch is a complete bit test.

The lesson's kernel needs eight tests per frame, one per band, each asking about a *different* bit. The clean way to write that is a **mask that moves**: a byte with one bit set starts at `%10000000` (band 0, bit 7), and `LSR` drops it one place for each band after that:

| Band (from the top) | Bit it shows | Mask when the band is tested |
|:---:|:---:|:---:|
| 0 | bit 7 | `%10000000` |
| 1 | bit 6 | `%01000000` |
| 2 | bit 5 | `%00100000` |
| 3 | bit 4 | `%00010000` |
| 4 | bit 3 | `%00001000` |
| 5 | bit 2 | `%00000100` |
| 6 | bit 1 | `%00000010` |
| 7 | bit 0 | `%00000001` |

One byte, eight tests — that is why the mask shifts **once per band**, not once per frame. Each `LSR Mask` leaves the mask sitting one place lower for the next band, and after band 7 a final shift pushes the last set bit out entirely, leaving `$00` (its carry is discarded — the mask is a testing tool, not arithmetic). The mask is reloaded to `%10000000` at the top of each frame.

The band-to-bit order matters and is easy to get backwards: **the top band shows bit 7, the bottom band shows bit 0** — the same order as a binary number is written down. That is why the starting pattern `%00000001` puts the bright band on the bottom rung.

### Section 3: Shifts — `ASL`, `LSR`, and the Bit That Falls Off

The shift instructions move every bit one place along and have to answer one question: what happens to the bit that leaves the end?

```
    ASL:   C <- [bit7 bit6 bit5 bit4 bit3 bit2 bit1 bit0] <- 0
    LSR:   0 -> [bit7 bit6 bit5 bit4 bit3 bit2 bit1 bit0] -> C
```

`ASL` (arithmetic shift left) shifts the byte left, fills bit 0 with 0, and pushes the old bit 7 into the **carry**. `LSR` shifts right, fills bit 7 with 0, and pushes the old bit 0 into the carry. Neither bit is lost — it is parked in the carry flag until you decide what to do with it.

Two consequences you will use constantly:

- **A left shift doubles the value; a right shift halves it** — as long as nothing important falls off the end. `ASL` on `%00000101` (`5`) gives `%00001010` (`10`); `LSR` on it gives `%00000010` (`2`, the 1 truncated). Four `LSR`s divide by 16, which is exactly how the packing exercise moves a nibble down out of the top half of a byte.
- **The carry catches the overflow.** `ASL` on `%10000001` gives `%00000010` with C = 1: the `$100` of the doubling is right there in the flag, waiting to be added into a second byte ([Lesson 05](/part1-6502-cpu/05-arithmetic)'s carry chain, now arriving from a shift).

Shifts also set **Z** and **N** from the result, which makes them the cheapest way to test the top bit of a byte: `ASL` puts bit 7 straight into the carry, and `BCS`/`BCC` can read it. The lesson's pattern walk is built on exactly that — see Section 4.

In the kernel, the mask shift is a zero-page `LSR`, five cycles (a read-modify-write: the CPU reads the byte, shifts it, and writes it back):

```asm
    LSR Mask                ; drop the mask's set bit down one place
```

::: tip Shift *in place* vs. shift *through A*
`ASL`, `LSR`, `ROL`, and `ROR` work on the accumulator (written with no operand in ACME: bare `ASL`) or on a byte in memory (`LSR Mask` shifts the RAM byte and stores the result back). The memory forms take 5–7 cycles instead of 2; the accumulator form is the only one that lets the shift and the carry handling happen in the same few instructions. In this ROM the mask lives in RAM because several instructions need to look at it, while the *pattern* is shifted through A so that the branch right after the shift can read the bit that just fell out of the top.
:::

### Section 4: The Carry Is Data — the Pattern's Walk and the Reload

Now the animation. The pattern byte starts with one bit set and steps one place every 30 frames, so the bright band visits eight positions:

```
%00000001   bit 0 -> bottom band
%00000010   bit 1 -> one band up
%00000100   bit 2
   ...       (one step per half second)
%01000000   bit 6
%10000000   bit 7 -> top band
```

The step itself is the heart of the lesson:

```asm
    LDA Pattern             ; A = the pattern: %00000001 ... %10000000
StepShift:
    ASL                     ; A = A x 2; bit 7 falls out into the carry
    BCS ReloadPattern       ; C = 1 -> the set bit left the byte: start over
StepStore:
    STA Pattern             ; C = 0 -> all the set bit did was move one up
    JMP NoStep
ReloadPattern:
    LDA #%00000001          ; bit 7 was set -> the walk restarts at bit 0
ReloadStore:
    STA Pattern
NoStep:
    JMP StartFrame          ; next frame
```

Walk the last step by hand. When the pattern is `%10000000`, `ASL` produces `%00000000` — the byte is empty — and the carry is **1**: the set bit is not gone, it is *in the flag*. `BCS` takes its branch to `ReloadPattern`, `%00000001` goes back into the pattern, and the next frame shows the bright band at the bottom again. When the pattern is anything smaller, `ASL` produces a nonzero byte, the carry is 0, `BCS` is not taken: the shifted value is stored and the `JMP` skips over the reload. (The `JMP` exists because the reload block sits between the store and the frame loop's `NoStep` label — falling into it would reload on *every* step, so the store path needs an unconditional jump around it.)

Two lessons live in that step:

1. **The carry is a ninth bit of storage.** Its official job is arithmetic carry, but it is also where "the bit that left" exists for one instruction. A shift throws a bit at the flag, and a branch decides what to do with it.
2. **Reloading is a deliberate choice.** Here the walk is a *line*, not a ring: bit 7 restarts at bit 0 with a `BCS` + `LDA #%00000001`. Exercise 3 replaces the reload with a rotate, which makes the walk a true eight-position ring.

The debugger shows the whole story without a single screenshot. Set a breakpoint in Stella on the `ASL` — the ROM labels it `StepShift` for exactly that reason (label names come from an `acme -l` symbol list; the shipped `.bin` has no names in it) — and step: **A** holds the pattern for the current step, `$01`, `$02`, `$04`, all the way to `$80`, and on the wrap step the reload's `STA Pattern` (labelled `ReloadStore`) arrives with **A = $01** and the **C** flag set. That is the bit that "fell out" the top, one instruction away from re-entering at the bottom.

::: details TypeScript Equivalent
A shift in TypeScript quietly loses the bit that leaves; the 6502 makes it a first-class value you can branch on. The lesson's step is one line in TypeScript and five on the 6502 — plus one entire hardware register's worth of meaning:

```typescript
// TypeScript: the carry is nowhere — bit 7 simply evaporates.
let pattern = 0b10000000;
pattern = (pattern << 1) & 0xFF;   // 0b00000000 — the bit is GONE

// On the 6502 the same shift hands you the lost bit in C:
//   ASL          -> A = %00000000, C = 1
//   BCS reload   -> C = 1, so the branch IS taken
//   LDA #%00000001  -> put the bit back at the bottom
```

The 6502's carry is a real register bit that survives between instructions; in TypeScript you would have to *invent* it (`const carry = (pattern >> 7) & 1`) every single time, and you would still have to write the branch by hand. On the 6502 the shift and the flag are produced by the same instruction.
:::

### Section 5: Rotates — `ROL` and `ROR` Bring the Bit Around

The shift instructions send the falling bit to the carry and fill the empty end with 0. The **rotate** instructions fill the empty end with the carry instead:

```
    ROL:   C <- [bit7 ... bit0] <- C      (bit 7 leaves, the carry re-enters at bit 0)
    ROR:   C -> [bit7 ... bit0] -> C      (bit 0 leaves, the carry re-enters at bit 7)
```

`ROL` is "shift left, but bank the carry into bit 0"; `ROR` is the mirror. The difference from `ASL`/`LSR` is exactly one bit — and that one bit is the whole idea of a **ring counter**: make the carry *be* the bit that is about to fall off, and the byte rotates forever with no reload:

```asm
    LDA Pattern
    CMP #%10000000      ; C = 1 exactly when bit 7 holds the set bit
    ROL                 ; the bit that left bit 7 re-enters at bit 0
    STA Pattern
```

The `CMP` deserves a second look. `ROL` cannot know that it should re-enter the falling bit at the bottom — it only knows whatever the carry happens to be. `CMP #%10000000` sets the carry to 1 exactly when `A >= $80`, which is exactly when bit 7 is set, which is exactly the bit that is about to leave. Just as important, `CMP` is a *comparison*: it sets flags and leaves A completely alone ([Lesson 06](/part1-6502-cpu/06-flags-and-comparisons) made a point of that), so the byte it tested is still in the accumulator when the `ROL` runs — which is why this ring needs no reload. Setting up the carry *before* the rotate is the standard way to use `ROL`/`ROR` deliberately instead of hoping the last instruction left the flag in a useful state. Exercise 3 builds this ring; its mirrored `ROR` version needs one extra instruction for exactly this reason — `LSR` is how bit 0 reaches the carry, and unlike `CMP` it *does* consume the byte it shifts.

::: tip Why a bare `ROL` is a trap
A rotate needs the carry to be the falling bit *at the moment of the rotate*. In a tight loop where rotations follow each other immediately, the carry from the previous rotate is already correct. But this ROM rotates once every 30 frames, and a lot of instructions run in between — including the kernel's own `LSR Mask`, which overwrites the carry once per band. A bare `LDA Pattern` / `ROL` would feed the *mask's* leftover bit back into the pattern and light a second band. Saving and setting the carry before each rotate (as above) makes the ring independent of whatever ran before it — the same discipline as preserving a register across a subroutine call in [Lesson 08](/part1-6502-cpu/08-stack-and-subroutines).
:::

### Section 6: Packing Two Nibbles into One Byte

A **nibble** is four bits — one hexadecimal digit. Color bytes are nibbles glued together: `$C4` means hue `C`, luminance `4`. When the two halves arrive in separate bytes, `AND`, `LSR`, and `ORA` put them back together:

```asm
    LDA NibbleHi    ; %11000000   the high nibble, parked at the top
    AND #$F0        ; keep only the top nibble
    STA Packed      ; the high half of the color is ready
    LDA NibbleLo    ; %01000000   the low nibble, also parked at the top
    LSR             ; ÷ 2 each shift moves the nibble down one bit ...
    LSR
    LSR
    LSR             ; ... four shifts = ÷ 16 -> %00000100
    ORA Packed      ; merge the halves (%11000000 OR %00000100)
    STA Packed      ; $C4: one color byte
```

Three instructions, three distinct jobs:

- **`AND #$F0` masks**: it keeps the top nibble and forces everything below it to 0, so whatever was stored under the nibble cannot leak into the result.
- **`LSR` ×4 shifts**: a nibble parked at the top of a byte is that nibble multiplied by 16; four one-bit shifts divide it by 16 again, putting it in the bottom half, where it belongs.
- **`ORA` merges**: OR is safe here because the two halves no longer overlap — the high nibble occupies bits 7–4, the low nibble bits 3–0, and neither can disturb the other. (If they *did* overlap, OR would set the union of the bits, which is the classic way to get a wrong-looking color.)

Exercise 2 uses exactly this sequence and paints the picture with the packed byte, so the debugger's RAM view shows the two source bytes, the packed byte, and the screen agreeing with each other.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson09.bin \
  lessons/part1-6502-cpu/09-bitwise-operations/09-bitwise-operations.asm
```

Then run it in Stella:

```bash
stella build/lesson09.bin
```

### Full Source

The program paints eight 24-line bands, top band showing bit 7 of the pattern at RAM `$80` and bottom band bit 0; a moving mask tests one bit per band, and every 30 frames the pattern steps one place and reloads when its set bit leaves through the carry. The picture is 192 non-blanked scanlines: the beam-release line is band 0's first line (its color is pre-loaded), `PaintBand` paints 23 more lines for band 0 and 24 for each other band, and the blank-on after band 7 waits for HBLANK first so the last band line is painted whole.

```asm
; =============================================================================
; LESSON 09: Bitwise Operations — The Power of Bits
; =============================================================================
; Part 1: The 6502 CPU
;
; What this program does:
;   The "bit ladder": EIGHT bands of 24 scanlines each.  Each band shows one
;   bit of the pattern byte at RAM $80: the TOP band shows bit 7, the BOTTOM
;   band shows bit 0.  Exactly one bit of the pattern is set, so exactly one
;   band is bright green ($C8) and the other seven are dark gray ($02).
;
;   The pattern starts at %00000001 — bit 0, the bottom band.  Every 30 frames
;   (~1/2 second) the pattern steps one place: ASL shifts it left, and when
;   the set bit finally leaves through bit 7 it arrives in the CARRY flag;
;   BCS sees that and reloads %00000001, so the bright band climbs from the
;   bottom to the top and then starts again at the bottom.
;
;   To test the bands the kernel needs a MOVING MASK: a byte with one bit set
;   that says which bit belongs to the band being painted.  It starts at
;   %10000000 (band 0, bit 7) and LSRs once per band, so band 1 tests bit 6,
;   band 2 bit 5, ... and band 7 tests bit 0.  AND combines mask and pattern:
;   nonzero means this band's bit is 1 -> bright green.
;
;   The picture is 192 non-blanked scanlines: 8 bands x 24 lines.  Band 0 is
;   painted partly by the beam-release line — its color is pre-loaded, so the
;   release line is band 0's FIRST line — and the other 23 lines come from
;   PaintBand.  The blank-on after the last band waits for HBLANK first
;   (STA WSYNC), so the last band line is painted whole.
;
; What you'll learn:
;   - AND masks a byte (keep some bits) and TESTS bits (AND + BEQ/BNE)
;   - ORA sets bits, EOR toggles bits — the three logic instructions
;   - AND / ORA / EOR set Z and N from the result, so a branch can read them
;   - ASL / LSR shift a byte left/right; the bit that falls off lands in C
;   - ROL / ROR rotate through the carry, so a bit can come back in
;   - The shifted-out bit is data, not garbage: BCS turns it into a decision
;   - Building a byte from two nibbles with AND / LSR / ORA
;   - A mask that shifts once per band: one byte, eight tests
;
; Build: acme -f plain -o build/lesson09.bin \
;        lessons/part1-6502-cpu/09-bitwise-operations/09-bitwise-operations.asm
; Run:   stella build/lesson09.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; COLOR CONSTANTS  (NTSC)
; =============================================================================
GRAY        = $02       ; a band whose bit is 0
GREEN       = $C8       ; the band whose bit is 1 — bright green

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
Pattern     = $80       ; the bit ladder: ONE bit set at all times,
                        ;   %00000001 ... %10000000
Mask        = $81       ; band-select mask: band 0 tests %10000000, band 1
                        ;   tests %01000000, ... band 7 tests %00000001.
                        ;   One LSR per band walks the set bit downwards.
StepTimer   = $82       ; frames left before the pattern takes its next step

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
BANDS       = 8         ; bands on the ladder — one per bit
LINES       = 24        ; scanlines per band (8 x 24 = 192 visible lines)
STEP_FRAMES = 30        ; frames between pattern steps (~1/2 second at 60 Hz)

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, set SP = $FF, CLD (Lesson 04)

    ; --- Starting state: bit 0 set -> the bright band sits at the BOTTOM ---
    LDA #%00000001          ; the pattern is binary: one set bit
    STA Pattern             ; Pattern = %00000001 (bit 0)
    LDA #STEP_FRAMES        ; A = 30
    STA StepTimer           ; 30 frames until the pattern steps

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK

; -----------------------------------------------------------------------------
; BAND 0'S COLOR — tested while the beam is still blanked
; -----------------------------------------------------------------------------
; Band 0 is the TOP band and tests bit 7.  Its color has to be in COLUBK
; before the beam is released: the release line is band 0's first line, and
; nothing else gets a chance to write the color register in time.
;
; The test is the lesson's core pattern in two instructions: AND keeps only
; the bits both bytes share, so "Pattern AND Mask" is zero exactly when this
; band's bit is 0.  BEQ reads that zero — AND sets Z from its result.
    LDA #%10000000          ; A = the mask for band 0 (bit 7) ...
    STA Mask                ; ... which also starts every frame's mask ladder
TopBandTest:                ; debugger checkpoint: break here and A is the mask
    AND Pattern             ; A = bit 7 of the pattern (0 or %10000000)
    BEQ TopBandDark         ; Z = 1 -> bit 7 is 0 -> this band is dark
    LDA #GREEN              ; bit 7 is 1 -> bright green
    BNE TopBandColor        ; GREEN is never 0, so this is a join, not a test
TopBandDark:
    LDA #GRAY               ; band 0's bit is 0 -> dark gray
TopBandColor:
    TAY                     ; park the color in Y: +wait_timer clobbers A

    +wait_timer             ; finish the ~37 scanlines of VBLANK

    LDA #$00
    STA VBLANK              ; un-blank: A = 0 now, and the color comes back
                            ; out of Y right after this
    TYA                     ; A = band 0's color again
    STA COLUBK              ; written in HBLANK, before the beam draws this
                            ; line: the release line already carries it

; -----------------------------------------------------------------------------
; KERNEL — eight 24-line bands; the band whose bit is set is bright green
; -----------------------------------------------------------------------------
; Band 0's release line was line 1, so PaintBand only has to paint 23 more
; lines for band 0 — every band ends up exactly 24 lines tall.
    LDX #LINES-1            ; X = 23: release line + 23 = band 0's 24
    JSR PaintBand           ; paint X lines of the color in A
    LSR Mask                ; band 0 is done — band 1 tests the next bit

    LDY #1                  ; Y = band index: band 1 (bit 6) is next
BandLoop:
    LDA Mask                ; A = the mask for this band (%01000000 first)
BandTest:                   ; debugger checkpoint: break here and A is the mask
    AND Pattern             ; 0 when this band's bit is 0
    BEQ BandDark            ; Z = 1 -> dark gray
    LDA #GREEN              ; Z = 0 -> this band's bit is 1 -> bright green
    BNE BandColor           ; join (GREEN is never 0)
BandDark:
    LDA #GRAY
BandColor:                  ; A = this band's color
    LDX #LINES              ; X = 24: a full band
    JSR PaintBand           ; paint it — A and Y survive, X is used up
    LSR Mask                ; drop the mask's set bit down one place
    INY                     ; next band
    CPY #BANDS              ; have we tested all 8 bits?
    BNE BandLoop            ; no -> another band, another mask

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
    STA WSYNC               ; wait for HBLANK before blanking: the last band
                            ; line is being drawn right now, so writing VBLANK
                            ; here would clip it partway across.  WSYNC lets the
                            ; line finish; the blank-on starts on the next line
    LDA #$02
    STA VBLANK
    +set_timer 35           ; ~30 scanlines of overscan
    +wait_timer

; -----------------------------------------------------------------------------
; GAME LOGIC — the pattern steps once every STEP_FRAMES frames
; -----------------------------------------------------------------------------
; This countdown is the animation clock.  One pass of the frame loop takes
; exactly one frame, so the pattern moves every 30 frames — about half a
; second at the TV's ~60 frames per second.
    DEC StepTimer           ; one frame closer to the next step
    BNE NoStep              ; not 0 yet (Z = 0) -> the pattern stays put
    LDA #STEP_FRAMES        ; countdown reached 0 -> reload it ...
    STA StepTimer

    ; --- Advance the pattern one bit: left shift, with the carry as news ---
    LDA Pattern             ; A = the pattern: %00000001 ... %10000000
StepShift:                  ; debugger checkpoint: A is the pattern before ASL
    ASL                     ; A = A x 2; bit 7 falls out into the carry
    BCS ReloadPattern       ; C = 1 -> the set bit left the byte: start over
StepStore:                  ; debugger checkpoint: A = the stepped pattern
    STA Pattern             ; C = 0 -> all the set bit did was move one up
    JMP NoStep
ReloadPattern:
    LDA #%00000001          ; bit 7 was set -> the walk restarts at bit 0
ReloadStore:                ; debugger checkpoint: A = %00000001, C = 1
    STA Pattern
NoStep:
    JMP StartFrame          ; next frame

; =============================================================================
; SUBROUTINE: PaintBand  —  paint X scanlines of the color in A
; =============================================================================
; How to call:   A = color byte, X = scanline count, then JSR PaintBand
; What it does:  waits for the next scanline to start, then writes the color
;                to COLUBK once per line for X lines.  Writing the color
;                right after the WSYNC — instead of once before the loop —
;                puts the change in the first few cycles of the line, before
;                the TIA starts drawing on it, so band boundaries fall
;                exactly on a scanline instead of showing a notch where the
;                new color arrives mid-line.
; Registers:     A survives (still the color) and Y is never touched; X is
;                used up — the line counter counts it down to 0.  The band
;                loop keeps its band index in Y for exactly that reason.
; Stack:         JSR pushed the return address; the RTS pops it.  Nothing
;                else is pushed inside, so the band loop can call it safely.
; =============================================================================
PaintBand:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEX                     ; one line fewer to go: 24, 23, ... 1
    BNE -                   ; loop until the line counter reaches 0
    RTS                     ; return; the return address comes off the stack

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

> The complete, fully-commented source lives in
> `lessons/part1-6502-cpu/09-bitwise-operations/09-bitwise-operations.asm`.

### Code Walkthrough

#### Step 1 — Band 0's color, tested while the beam is blanked

```asm
    LDA #%10000000          ; A = the mask for band 0 (bit 7) ...
    STA Mask                ; ... which also starts every frame's mask ladder
TopBandTest:
    AND Pattern             ; A = bit 7 of the pattern (0 or %10000000)
    BEQ TopBandDark         ; Z = 1 -> bit 7 is 0 -> this band is dark
    LDA #GREEN              ; bit 7 is 1 -> bright green
    BNE TopBandColor        ; GREEN is never 0, so this is a join, not a test
TopBandDark:
    LDA #GRAY               ; band 0's bit is 0 -> dark gray
TopBandColor:
    TAY                     ; park the color in Y: +wait_timer clobbers A
```

This is Section 2's test in its first home, plus one practical wrinkle. The top band's color must be in `COLUBK` **before the beam is released**: the release line is band 0's first line, and `PaintBand` cannot write anything until the next line boundary. So the test happens during VBLANK, the color is parked in **Y** across the timer wait (the `+wait_timer` macro leaves its own value in A), and `TYA` / `STA COLUBK` put it in place in the release line's HBLANK. The same `TAY`/`TYA` trick in reverse appears in [Lesson 08](/part1-6502-cpu/08-stack-and-subroutines)'s exercise 2: when a macro or subroutine is about to clobber a register, park the value in one it does not touch.

#### Step 2 — One mask shift per band

```asm
    LDX #LINES-1            ; X = 23: release line + 23 = band 0's 24
    JSR PaintBand           ; paint X lines of the color in A
    LSR Mask                ; band 0 is done — band 1 tests the next bit

    LDY #1                  ; Y = band index: band 1 (bit 6) is next
BandLoop:
    LDA Mask                ; A = the mask for this band (%01000000 first)
BandTest:
    AND Pattern             ; 0 when this band's bit is 0
```

`LSR Mask` is the lesson's "moving test" in one instruction: the byte starts at `%10000000`, and every band leaves it one place lower, so the *same* two-instruction test (`LDA Mask` / `AND Pattern`) asks about a different bit each time. The kernel is a loop, not eight copies of the test — the mask is the thing that changes.

#### Step 3 — The shared painter and the register contract

```asm
PaintBand:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEX                     ; one line fewer to go: 24, 23, ... 1
    BNE -                   ; loop until the line counter reaches 0
    RTS
```

`PaintBand` is [Lesson 08](/part1-6502-cpu/08-stack-and-subroutines)'s painter, unchanged in spirit: color in **A**, line count in **X**, one scanline per pass, the color written just after the `WSYNC` so the change lands in HBLANK and band boundaries are exact. Its contract is stated in the source: **A survives, Y is never touched, X is used up as the counter.** The band loop keeps its band index in **Y** for exactly that reason — Y is the one register the painter promises not to touch. Band 0's 23 remaining lines and the seven full bands are eight calls to that single copy of the painter.

#### Step 4 — The pattern's step and the carry reload

```asm
    LDA Pattern             ; A = the pattern: %00000001 ... %10000000
StepShift:
    ASL                     ; A = A x 2; bit 7 falls out into the carry
    BCS ReloadPattern       ; C = 1 -> the set bit left the byte: start over
StepStore:
    STA Pattern             ; C = 0 -> all the set bit did was move one up
    JMP NoStep
ReloadPattern:
    LDA #%00000001          ; bit 7 was set -> the walk restarts at bit 0
ReloadStore:
    STA Pattern
NoStep:
    JMP StartFrame          ; next frame
```

Section 4 in the flesh: `ASL` doubles the pattern and hands bit 7 to the carry; `BCS` takes the reload branch when the set bit just left the byte, and otherwise the shifted value is stored and the `JMP` skips the reload. The decision is on the *carry flag left by the shift* — no compare instruction appears anywhere in the step.

#### Step 5 — Blanking the beam in HBLANK

```asm
    STA WSYNC               ; wait for HBLANK before blanking
    LDA #$02
    STA VBLANK
```

Unwinding the band loop and shifting the mask takes enough cycles to push a naive blank-on write into the visible part of the last band line, where it clips the line partway across. `STA WSYNC` first makes the CPU wait for the next horizontal blank, so the blank-on lands there instead and the last band line is painted in full. This is the same fix [Lesson 08](/part1-6502-cpu/08-stack-and-subroutines) applies after its call chain unwinds, and the same habit every kernel needs: **look at what runs after the last visible line, and count its cycles.**

## What You Should See

Eight equal horizontal bands of 24 scanlines each — 192 non-blanked scanlines in all. Seven bands are **dark gray** (`$02`); exactly one is **bright green** (`$C8`). At the start the bright band is the **bottom** band, because the pattern is `%00000001` (bit 0). Every half second it climbs one rung, and about four seconds later it reaches the **top** band (bit 7), wraps, and starts again at the bottom:

![Stella running the Lesson 09 bit-ladder ROM: eight stacked bands, the bottom band bright green and the rest dark gray](/images/lesson09/bit-ladder-bottom.png)

![The same ROM later in the walk: the bright green band has climbed to the top band, bit 7 of the pattern](/images/lesson09/bit-ladder-top.png)

<RomPlayer rom="/roms/part1-6502-cpu/09-bitwise-operations/09-bitwise-operations.bin" title="Lesson 09 — Bitwise Operations" />

Watch for a few seconds and you can see the whole lesson: the bright band steps bottom-to-top one band at a time, and when the set bit leaves the top of the byte the band is back at the bottom before you can see the pattern ever become `%00000000` — the bit that left is caught by the carry and the reload puts it back before the next frame is drawn.

Open the debugger (backtick `` ` ``) and check the numbers:

- **`$80`** — the pattern. It steps `$01`, `$02`, `$04`, `$08`, `$10`, `$20`, `$40`, `$80`, and then `$01`: one bit, one place, once every 30 frames. The bright band on screen is always the band whose bit this byte has set — bit 7 is the top band, bit 0 the bottom.
- **`$81`** — the mask. Inside a *single frame* it runs `$80`, `$40`, `$20`, `$10`, `$08`, `$04`, `$02`, `$01` — once per band, one shift each — and the last shift leaves `$00` until the next frame reloads it. This is the "once per band" rate made visible: eight tests, eight different masks, one RAM byte.
- **`$82`** — the step countdown, counting `30 → 0` once per frame. When it reaches zero the pattern steps and the byte is reloaded with `30`.
- The **C flag** on the wrap. Set a breakpoint on the `ASL` (the `StepShift` symbol) and let it hit: when the accumulator holds `$80`, the shift empties the byte into the carry, `BCS` takes the reload branch, and the reload's `STA` stores `$01` with **C = 1**. That is the bit that "fell out" the top, one instruction away from re-entering at the bottom.

Single-step the `AND Pattern` in the band loop (`BandTest`) and watch **Z** in Stella's status display: on the one band whose bit is set, `AND` leaves a nonzero accumulator and Z = 0; on the other seven it leaves `$00` and Z = 1. One instruction, one flag, one bit — the whole lesson in a keystroke.

## Exercises

### Exercise 1: Set, Clear, and Toggle

**Challenge:** start from the byte `%10100000` and apply the three logic instructions in sequence, showing each result: **set** bit 2 with `ORA`, **clear** bit 5 with `AND`, **toggle** bit 7 with `EOR`. Each pattern should be painted on the ladder and readable at RAM `$80`.

**Hints:**
1. The three masks follow from Section 1: to set bit 2, OR with `%00000100`; to clear bit 5, AND with every bit *except* bit 5, i.e. `%11011111`; to toggle bit 7, EOR with `%10000000`.
2. The operations are **cumulative** — clear bit 5 of the byte that already has bit 2 set — so the order you apply them in is part of the answer.
3. The sequence cycles: after the toggle, put `%10100000` back and start over, so each of the four patterns holds for half a second. A step counter (0–3) decides which operation runs.

**Expected Result:** Four patterns appear in turn — `%10100000` (bands 0 and 2 bright), `%10100100` (bands 0, 2, and 5), `%10000100` (bands 0 and 5), `%00000100` (band 5 only) — and the sequence repeats. RAM `$80` reads the current pattern at every step.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Pack Two Nibbles into One Color

**Challenge:** a color's two nibbles arrive in separate bytes, each sitting in the top half of its byte — `$80` = `%11000000` (the hue nibble `$C`) and `$81` = `%01000000` (the luminance nibble `$4`). Pack them into one color byte with `AND`, `LSR`, and `ORA`, and paint the picture with the result.

**Hints:**
1. `AND #$F0` keeps the top nibble of `$80` and nothing else — that half of the color is already in place.
2. The nibble in `$81` is at the top, which means it counts as *sixteen times* the value you want. Four `LSR`s divide by 16.
3. `ORA` joins the two halves; the bits cannot overlap (high nibble in bits 7–4, low nibble in bits 3–0), so OR is safe. Store the packed byte where the debugger can see it.

**Expected Result:** The whole picture in the packed color `$C4`, and RAM `$82` reads `$C4`. Edit `$80` or `$81` in the debugger and the picture changes color on the next frame — the packing runs once per frame, during VBLANK.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The Ring Counter *(Stretch Goal)*

**Challenge:** make the traveling bit **re-enter** instead of reloading. Replace the `ASL` + `BCS` reload with a rotate, so the bit that leaves bit 7 comes back at bit 0 and the ladder never stops — an eight-position ring counter built from `ROL` (or `ROR` for the mirror-image direction).

**Hints:**
1. `ROL` shifts left and shifts the **carry** into bit 0. For the bit to re-enter, the carry must *be* the bit that is about to leave: `CMP #%10000000` sets C = 1 exactly when bit 7 is set, and it leaves the pattern byte alone.
2. The carry does not survive the 30 frames between steps — the kernel's `LSR Mask` overwrites it every frame — so set it up immediately before each rotate instead of leaving it from the last one.
3. The mirrored version rings the other way — and it needs its own reload, because `LSR` (how bit 0 reaches the carry) shifts the byte as it goes:

   ```asm
       LDA Pattern
       LSR                 ; bit 0 -> carry ... and A is shifted, too
       LDA Pattern         ; reload the byte (LDA does not touch C)
       ROR                 ; the bit that left bit 0 re-enters at bit 7
       STA Pattern
   ```

   Unlike the `CMP` version — which sets flags and leaves the byte alone — the `LSR` version must reload the pattern, because `LSR` consumes it. `LDA` preserves the carry, so the bit that just landed in C is still there for the `ROR`.

**Expected Result:** The bright band climbs bottom-to-top exactly like the lesson ROM, and then the *next* step puts it straight back on the bottom band — no reload branch, no empty frame, forever. In the debugger, `$80` steps `$01`, `$02`, … `$80`, `$01`, … and never reads `$00`, because the bit re-enters through the carry in the same step that it leaves.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **`AND` clears and extracts, `ORA` sets, `EOR` toggles** — mask with the bits you mean, and OR/EOR are safe because a 0 in the mask leaves the original bit alone
- ✅ **`AND` + a branch is the bit test**: `AND #mask` leaves Z = 1 exactly when the masked bits were all 0, so `BEQ`/`BNE` turns it into "is this bit set?"
- ✅ **`ASL` doubles, `LSR` halves, and the bit that falls off lands in the carry** — and like the logic instructions, the shifts set **Z** and **N** from the result, so a flag you did not ask for is often the one the branch needs next
- ✅ **The carry is a ninth bit of storage**: `ASL` on `%10000000` leaves `%00000000` with C = 1, and a branch can put that bit to work — reload it, add it to a second byte, or rotate it back in
- ✅ **`ROL`/`ROR` rotate *through* the carry**, so a bit can re-enter at the other end; set the carry from the bit about to leave (`CMP #%10000000`, which leaves the byte alone) instead of hoping it already holds the right value
- ✅ **One byte can hold eight flags, and a mask that moves tests them all**: `LSR Mask` once per band turns a loop into eight different bit tests on the same two instructions
- ✅ **Nibbles pack with `AND` / `LSR` / `ORA`**: keep the top half, divide the bottom half down out of the way, and merge — nothing overlaps, so nothing corrupts

## What's Next

Bytes are now eight independent flags, and the instructions that read and write them one bit at a time are in your toolkit — which is most of what makes 2600 code look like 2600 code: status bytes, direction bits, graphics nibbles, and masks that walk across a byte. The next lesson steps back from *what* the instructions do to *how they find their data*: in [Lesson 10: Addressing Modes](/part1-6502-cpu/10-addressing-modes) you will meet the full catalog — zero page, absolute, indexed, and indirect — and see six different ways to load the very same byte.
