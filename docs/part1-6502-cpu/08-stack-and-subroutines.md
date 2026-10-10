---
title: "Lesson 08: The Stack and Subroutines — Functions in Assembly"
description: "Meet the hardware stack: the stack pointer, the page-$01 that mirrors your RAM, PHA/PLA, JSR/RTS return addresses, saving registers across a call, and the collision hazard that makes a deep call chain dangerous on the Atari 2600."
prev:
  text: "Lesson 07: Branches and Loops"
  link: "/part1-6502-cpu/07-branches-and-loops"
next:
  text: "Lesson 09: Bitwise Operations"
  link: "/part1-6502-cpu/09-bitwise-operations"
---

# Lesson 08: The Stack and Subroutines — Functions in Assembly

> **Part 1: The 6502 CPU** · Estimated time: 45 minutes
> **Prerequisites:** Lesson 07 (branches, loops, and `JMP`), Lesson 04 (registers, RAM, the frame skeleton)
> **You will learn:** the hardware stack and the stack pointer (`SP`); `PHA`/`PLA` and `PHP`/`PLP`; `JSR` and `RTS` — what they push, what they pop, and what they cost; saving registers across a call; nested call chains; and the page-`$01` mirror that turns a deep stack into a RAM overwrite
> **You will build:** a "subroutine bands" ROM — four bands (each one 48-line `PaintBand` call; the beam-release line carries the top band's color, so the picture is 193 non-blanked scanlines) painted by **one shared subroutine**, called four times per frame, with an explicit push/pull round trip that keeps the caller's counter alive across every call

## Introduction

Every program you have written so far has stayed inside a single routine. A branch can send the CPU *backwards* or *forwards*, and a loop can repeat, but a branch never has to remember anything: it just moves the program counter. That is enough to paint a ladder of bands — and it is not enough to write a real program. Real programs are built from **subroutines**: one named piece of code, called from many places, that runs and then *comes back to where it was called from*.

Coming back is the interesting part. The CPU has one program counter, and a `JMP` overwrites it — so before jumping into a subroutine, *somebody* has to remember the return address. On the 6502 that somebody is the **stack**: 256 bytes of memory in page `$01`, addressed by the 8-bit **stack pointer** (`SP`), and wired into the `JSR`/`RTS` instructions so that the remembering is automatic. Push the return address on the way in, pop it on the way out — and while you are there, the same stack can hold anything else you need to save: a loop counter, a register a callee is about to trash, a set of flags.

The companion program `08-stack-and-subroutines.asm` makes this visible twice over. On screen it paints four bands — red, green, blue, gold — and every band is painted by the *same* subroutine, `PaintBand`, called four times per frame by another subroutine, `DrawScreen`. Each call paints 48 lines and lands the color change exactly on a scanline boundary; the beam-release line already carries the top band's color, so the top band is one scanline taller — 193 non-blanked scanlines of picture in all. Inside `DrawScreen`, the band counter is pushed on the stack before every call and pulled back afterwards, because `PaintBand` needs the register the counter lives in. And in the debugger you can watch the whole thing: `SP` sits at `$FF` when a frame begins, drops by two bytes for each call, and is back at `$FF` before the next frame starts.

There is one 2600-specific twist you have to meet early, and this lesson meets it head-on: on this machine the stack's page `$01` is **the same physical memory as your RAM at `$80–$FF`**. The stack does not get extra bytes — it grows *down from the top of your variables*.

::: details TypeScript Equivalent
A function call in TypeScript looks free: the language keeps the return address, the local variables, and the machine state, and hands them back after the call. The 6502 keeps exactly one of those for you — the return address — and it makes you pay for it in stack bytes:

```typescript
// TypeScript: the call, the locals and the machine state are all automatic.
function paintBand(color: number, lines: number): void {
  const savedX = someLiveValue;   // not a real thing you write — the compiler
  /* paint */                     // decides what to save and where
  someLiveValue = savedX;
}

// 6502: the return address is the ONLY thing the call saves for you.
//   JSR PaintBand     -> pushes the return address (2 bytes)
//   RTS               -> pops it
// Everything else is your job:
//   TXA / PHA         -> "please keep X for me while I'm away"
//   ... JSR ...       -> the callee may use X freely
//   PLA / TAX         -> "thank you"
```

Two differences matter. First, the 6502 has **no notion of a local variable**: a subroutine that wants scratch space either uses a register (and takes it from its caller) or pushes it onto the shared stack. Second — and this is the one that bites on a 2600 — the stack is not a separate area of memory. Page `$01` is a **mirror** of the 128 bytes of RAM at `$80–$FF`, so a deep call chain physically overwrites your variables. In TypeScript you would never worry that calling a function might clobber a global by *existing*; here, every byte of call depth is a byte taken from the top of your variable space.
:::

## Theory

### Section 1: The Stack — 256 Bytes of Page `$01`

The stack pointer is a single 8-bit register, and it combines with the fixed page `$01` to form a full address:

```
   SP = $FF  ->  the next free stack byte is at $0100 + $FF = $01FF
```

The convention is worth memorizing because it explains every number in this lesson: **`SP` points at the next free byte** — the byte *below* the last thing that was pushed.

| Instruction | What it does | `SP` after |
|-------------|--------------|-----------|
| `PHA` | Push A: store A at `$0100 + SP` | `SP − 1` |
| `PLA` | Pull A: `SP + 1`, then load A from `$0100 + SP` | `SP + 1` |
| `PHP` / `PLP` | The same, for the flags byte (P) | `SP ∓ 1` |
| `JSR` | Push the return address, high byte then low byte | `SP − 2` |
| `RTS` | Pull the return address, low byte then high byte | `SP + 2` |

Three facts fall straight out of that table. **The stack grows down**: every push moves `SP` towards `$00`. **It is empty when `SP` is `$FF`**: nothing has been pushed yet, and the next push lands at `$01FF`. And `PHP`/`PLP` are just `PHA`/`PLA` for the status register — useful when a subroutine has to clobber a flag you depend on, exactly like a pushed register.

`+clean_start` ends with `LDX #$FF` / `TXS`, which is where the `$FF` in every lesson's startup comes from. (`TXS` is the *only* way to load `SP`: `TSX` copies it the other way, into X, which is how you read it in the debugger or in code.)

::: tip Why "page $01" is 2600-specific
On a full 6502 the stack would be its own 256 bytes at `$0100–$01FF`. The 6507 in the 2600 has only 13 address lines (A0–A12), so addresses mirror every 8K — and the RIOT's RAM, which lives at `$0080–$00FF`, also answers at `$0180–$01FF`. Those are the addresses the stack uses. Writing the stack at `$01FF` writes the RAM byte at `$00FF`; there is no second copy.
:::

### Section 2: `JSR` and `RTS` — How a Call Remembers Where to Return

A subroutine call is a jump with a bookmark. `JSR target` pushes a 16-bit address and loads the program counter with `target`; `RTS` pops that address back into the program counter. The one detail that confuses beginners reading a disassembly is *which* address gets pushed:

```
    JSR PaintBand       ; at $F056: JSR $F061 (shipped layout)
AfterPaint:             ; at $F059  <- execution resumes here
```

The pushed value is `$F058` — the address of the **last byte of the `JSR` instruction**, not the address of the next instruction (`$F059`). (Those addresses are from the shipped assembly — an `acme -l` symbol list gives your build's own.) `RTS` adds 1 back. That is why the 6502 reference says "**`JSR` pushes address − 1 and `RTS` adds 1**", and it is why a subroutine can never be entered by a plain `JMP` — `JMP PaintBand` jumps to the code all right, but with nothing on the stack to `RTS` to.

A call costs **6 cycles and 2 stack bytes**; the matching `RTS` costs 6 cycles and hands the 2 bytes back. Twelve cycles of overhead per call is cheap for a big routine and noticeable inside a cycle-counted kernel — which is the whole subject of the final section.

::: tip When NOT to call
A per-line `JSR`/`RTS` pair costs 12 cycles out of the ~53 you get while the picture is visible, plus the push/pull traffic to protect your registers. Inside a tight kernel that is often the difference between fitting in 76 cycles and tearing the picture, which is why kernels usually *inline* the work (or paste it with a macro) instead of calling it. Use a call when the code is shared and the timing has room for it.
:::

### Section 3: Saving Registers — Whose Job Is It?

There is no automatic context save on the 6502. When control jumps to a subroutine, A, X, and Y still hold *the caller's* values, and the subroutine is free to use them. Two conventions solve this, and the lesson ROM uses one and the exercise uses the other:

**The caller saves** — push before the call, pull after:

```asm
    TXA             ; A = the caller's X (there is no PHX: TXA then PHA)
    PHA             ; save it on the stack          (SP: $FD -> $FC)
    LDA BandColors,X
    LDX #LINES      ; the callee wants X for its line count
    JSR PaintBand   ; the callee uses X up            (SP: $FC -> $FA inside)
    PLA             ; A = the value back             (SP: $FC -> $FD)
    TAX             ; X = the caller's value again
```

**The callee saves** — the same instructions inside the subroutine, announced as a contract: *"I clobber X, but I give it back."*

Both are correct; what is never correct is *assuming*. A subroutine's documentation should always say which registers survive. `PaintBand` in the lesson ROM promises A and Y and uses up X as its line counter — so `DrawScreen` protects its own counter. `PaintBandSafe` in Exercise 2 makes the opposite promise (it saves and restores X), and the caller stops worrying.

The picture on screen is where the lesson keeps its counters honest: `DrawScreen`'s counter must survive four calls. In this ROM losing it is not subtle: `TAX` then loads X with the byte `PaintBand` left in A — the color — so `INX` / `CPX #BANDS` never matches 4, the band loop never exits, and the frame never ends. Exercise 2 is written the other way round, counting down, so there a lost counter collapses the picture to a single band — which is exactly what makes that bug legible.

### Section 4: Nested Calls — Frame → DrawScreen → PaintBand

Calls nest, and each level costs 2 stack bytes. The lesson ROM's chain is two levels deep; the frame loop calls `DrawScreen`, which calls `PaintBand` once per band:

```
frame loop  --JSR-->  DrawScreen  --JSR-->  PaintBand
   SP $FF               SP $FD                SP $FA (with the saved counter
                                                     pushed at $FC in between)
```

The debugger shows the whole ledger if you step through one band. These are the values this ROM produces, and they are exactly what the arithmetic in the table above predicts:

| Moment in the frame | `SP` | Bytes the stack holds (page `$01`) |
|---------------------|:----:|------------------------------------|
| `StartFrame` — frame top | `$FF` | nothing: the stack is empty |
| just after `JSR DrawScreen` | `$FD` | `DrawScreen`'s return address at `$01FE`/`$01FF` |
| just after `TXA` + `PHA` in the band loop | `$FC` | + the saved band counter at `$01FD` |
| inside `PaintBand`, after its `JSR` | `$FA` | + `PaintBand`'s return address at `$01FB`/`$01FC` |
| back in `DrawScreen`, after `RTS` | `$FC` | the return address is gone again |
| after `PLA` + `TAX` | `$FD` | the counter has been pulled too |
| after the final `RTS` | `$FF` | nothing — ready for the next frame |

Two habits make this safe. First, **balance every push with a pull on every path** — the ledger above only returns to `$FF` because each call unwinds exactly. If a frame ended with one extra byte on the stack, the next frame would start at `$FE`, then `$FD`, and within a second the stack would be eating band counters and return addresses out of your variables. The `$FF` at the frame top is the checksum that says "balanced".

Second, note what the `$FA` row is *not*: it is not a free area. The very next subsection is about who else lives there.

### Section 5: The Page-`$01` Collision Hazard

Here is the sentence that this lesson exists for:

> **On the Atari 2600, the stack's page `$01` mirrors the 128 bytes of RAM at `$80–$FF`. Every byte you push is a byte of your variable space, taken from the top down.**

The lesson ROM's deepest stack write is at `$01FB`; because of the mirror, that is RAM `$FB` — the deepest `SP` is `$FA`, and the bytes `$01FB–$01FF` are the RAM bytes `$FB–$FF`. If this ROM kept a variable at, say, `$FE`, the first `JSR` of the frame would overwrite it with the low byte of a return address, and the variable would change every frame depending on where the code happened to sit. That is the classic "my RAM variable changes by itself" bug in 2600 programs.

So the rules are:

1. **Keep variables away from the top of RAM.** The further down the stack goes, the more you lose: the lesson ROM's two levels of calls plus a saved byte descend to `SP = $FA`, and its pushes write bytes down to `$FB`; the three-level chain of Exercise 3 descends to `SP = $F9`, and its pushes write bytes down to `$FA`; an accidental unbalanced push reaches *everything* eventually.
2. **Write down your deepest call chain** and leave the mirrored bytes alone. A variable table that starts at `$80` and grows upwards, with a comment like *"top of variables: $9F; deepest stack: $F9"*, is all the safety you get.
3. **Never put a variable at `$F9–$FF`** in a lesson like this one — that is the range the three-level chain of Exercise 3 reaches (deepest `SP = $F9`, so the next push would already land among your variables), and every extra level reaches 2 bytes further down.

For context, a full 128 bytes of stack is a *lot* of calls — 64 levels with nothing else pushed. On the 2600, the constraint is not the number of levels; it is that the space is shared with the only variables you have.

### Section 6: When a Subroutine Earns Its Keep

A `JSR`/`RTS` pair is 12 cycles and 2 stack bytes, plus whatever you push to protect your registers. That is not free, so the trade is:

**Worth a call:** the same code is needed in several places (one copy instead of three); the work is long enough that 12 cycles are noise (a band painter, a score updater, a sound routine); or the code needs a *name* — `PaintBand` says what it does, and the caller's loop reads like a sentence.

**Not worth a call:** a handful of instructions used once; anything inside a kernel line where the 12 cycles push you past 76; anything you are about to unroll for speed anyway.

The lesson ROM's `PaintBand` is the textbook case: one copy of the 48-line painter, four bands of different colors, and a caller loop that stays four lines long. The cost — 12 cycles per band, plus the push/pull round trip — lands between scanlines, where there is room.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson08.bin \
  lessons/part1-6502-cpu/08-stack-and-subroutines/08-stack-and-subroutines.asm
```

Then run it in Stella:

```bash
stella build/lesson08.bin
```

### Full Source

The program paints four bands with four calls to one shared painter: each call paints 48 lines, the beam-release line already carries the top band's color, and the picture is 193 non-blanked scanlines. The frame loop calls `DrawScreen`; `DrawScreen` calls `PaintBand`; the band counter survives each call on the stack. Nothing moves on screen — the action is in the debugger.

```asm
; =============================================================================
; LESSON 08: The Stack and Subroutines — Functions in Assembly
; =============================================================================
; Part 1: The 6502 CPU
;
; What this program does:
;   The "subroutine bands": FOUR bands, red ($42), green ($C8), blue ($96) and
;   gold ($1A), top to bottom.  Each band is one 48-line PaintBand call — the
;   beam-release line already carries the top band's color, so the top band is
;   one scanline taller; the picture is 193 non-blanked scanlines.  Every band
;   is painted by the SAME subroutine — PaintBand — called four times per
;   frame by DrawScreen.  The picture is steady on purpose: the interesting
;   activity happens on the stack, where you can watch it in the debugger.
;
;   DrawScreen keeps its own loop counter in X, and PaintBand needs X for its
;   line count, so every call is wrapped in a push/pull round trip:
;
;       TXA / PHA        save the band counter on the stack
;       JSR PaintBand    call the shared painter (it uses up X)
;       PLA / TAX        pull the band counter back
;
;   The frame top is the one moment per frame when the stack is empty again:
;   SP = $FF.  If that were not true, every frame would start one byte deeper
;   and the stack would slowly eat its way down through RAM.
;
; What you'll learn:
;   - The stack: 128 bytes of page $01, growing DOWN from $01FF
;   - PHA / PLA push and pull one byte; PHP / PLP do the same for the flags
;   - JSR pushes the return address MINUS 1; RTS adds 1 back
;   - Every JSR costs 2 stack bytes, so a call chain is 2 bytes per level
;   - TXA / PHA ... PLA / TAX: save a register a callee would clobber
;   - Nested calls: frame loop -> DrawScreen -> PaintBand
;   - Page $01 mirrors RAM $80-$FF: a deep stack overwrites your variables
;
; Build: acme -f plain -o build/lesson08.bin \
;        lessons/part1-6502-cpu/08-stack-and-subroutines/08-stack-and-subroutines.asm
; Run:   stella build/lesson08.bin
; =============================================================================

    !cpu 6502

; --- Include hardware definitions and macros ---
    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; COLOR CONSTANTS  (NTSC)
; =============================================================================
RED         = $42       ; top band
GREEN       = $C8       ; second band
BLUE        = $96       ; third band
GOLD        = $1A       ; bottom band

; =============================================================================
; RAM VARIABLES  —  RIOT RAM ($80-$FF)
; =============================================================================
; This ROM deliberately declares NO variables: every value that has to survive
; a call lives on the stack instead.  That is not a rule to follow forever —
; it is the safe choice for a lesson about the stack.  The rule that IS worth
; remembering is the other way round: whatever variables you do declare, keep
; them away from the top of RAM, because the stack grows down into the same
; 128 bytes (the document walks through the collision in detail).

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
BANDS       = 4         ; bands on the screen: 4 calls of 48 painted lines
LINES       = 48        ; scanlines per PaintBand call (top band + the release
                        ; line; 4 x 48 + 1 = 193 non-blanked scanlines)

; =============================================================================
; ROM START  —  cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; ENTRY POINT
; =============================================================================
Reset:
    +clean_start            ; zero TIA + RAM, set SP = $FF, CLD (Lesson 04)

; =============================================================================
; MAIN LOOP  —  one pass = one TV frame
; =============================================================================
; The stack is empty here on every pass: everything the previous frame pushed
; has been pulled again.  That is what "balanced" means, and SP = $FF at this
; label is the proof.  (In the debugger: set a breakpoint on StartFrame and
; watch SP never move.)
; =============================================================================
StartFrame:
    +vsync                  ; 3-line VSYNC — "a new frame starts now"

    LDA #$02
    STA VBLANK              ; blank the beam while we set up
    +set_timer 43           ; ~37 scanlines of VBLANK
    +wait_timer

    LDA BandColors          ; pre-load the top band's color BEFORE the beam
    STA COLUBK              ; is released.  A call costs cycles, so the shared
                            ; painter cannot write its first line until the
                            ; next WSYNC — without this, the first visible
                            ; line would show last frame's bottom color.
    LDA #$00
    STA VBLANK              ; un-blank — the visible picture starts now

; -----------------------------------------------------------------------------
; KERNEL — the whole picture is painted by one call
; -----------------------------------------------------------------------------
; SP is $FF here.  JSR pushes the address to come back to (two bytes), so
; inside DrawScreen SP is $FD — and every return unwinds it again.
    JSR DrawScreen          ; SP: $FF -> $FD ... and back to $FF on return

    STA WSYNC               ; wait for HBLANK before blanking.  Unwinding home
                            ; from DrawScreen costs ~28 cycles, which would put
                            ; the blank-on ~12 cycles into the VISIBLE part of
                            ; the last band line and clip it partway across;
                            ; WSYNC moves the blank-on into HBLANK instead.

; -----------------------------------------------------------------------------
; OVERSCAN
; -----------------------------------------------------------------------------
    LDA #$02
    STA VBLANK
    +set_timer 35           ; ~30 scanlines of overscan
    +wait_timer

    JMP StartFrame          ; next frame; the stack is empty again

; =============================================================================
; SUBROUTINE: DrawScreen  —  paint the whole picture, one band at a time
; =============================================================================
; How to call:   JSR DrawScreen
; What it does:  paints BANDS bands of LINES scanlines each, in the colors of
;                the BandColors table, top to bottom.  Nothing on screen
;                changes from frame to frame; the picture is a steady ladder.
; Registers:     Y is never touched — by this routine or by PaintBand.  A and
;                X do not survive: X is this routine's own counter, and on
;                return A = the last band's index and X = BANDS.  A subroutine
;                promises only what its contract says it does; here the
;                promise is Y.
; Stack:         enters with SP = $FD, returns with SP = $FD (plus the caller's
;                own return address below it); each PaintBand call adds and
;                removes its own two bytes.
;
; X is this routine's own counter: the index of the band it is about to paint.
; PaintBand needs X for its line count, so before every call we push the
; counter onto the stack and after the call we pull it back.  That is the
; whole point of the lesson: a subroutine call does not save anything for you.
; =============================================================================
DrawScreen:
    LDX #0                  ; X = band index: 0 = top band, 3 = bottom band
BandLoop:
    TXA                     ; A = the band index...
    PHA                     ; ...saved on the stack   (SP: $FD -> $FC)

    LDA BandColors,X        ; A = this band's color (PHA did not touch X)
    LDX #LINES              ; X = 48: the line count PaintBand wants
    JSR PaintBand           ; paint the band          (SP: $FC -> $FA inside)

    PLA                     ; A = the band index back (SP: $FC -> $FD)
    TAX                     ; X = our counter again
    INX                     ; next band
    CPX #BANDS              ; have we painted all four?
    BNE BandLoop            ; no -> another push / call / pull round trip
    RTS                     ; back to the frame loop  (SP: $FD -> $FF)

; =============================================================================
; SUBROUTINE: PaintBand  —  paint X scanlines of the color in A
; =============================================================================
; How to call:   A = color byte, X = scanline count, then JSR PaintBand
; What it does:  waits for the next scanline to start, then writes the color to
;                COLUBK once per line for X lines.  Writing the color right
;                after the WSYNC — instead of once before the loop — puts the
;                change in the first few cycles of the line, before the TIA
;                starts drawing on it, so band boundaries fall exactly on a
;                scanline instead of showing a notch where the new color
;                arrives mid-line.
; Registers:     A survives (still the color) and Y is never touched; X is
;                used up — the line counter counts it down to 0.  Saying which
;                registers survive is part of a subroutine's contract; here
;                the contract is "I leave A and Y alone and use up X", which
;                is why DrawScreen saves its counter before every call.
; Stack:         JSR pushed the return address; the RTS pops it.  Nothing else
;                is pushed inside, so the band loop can nest safely.
;
; One copy of this code paints all four bands.  Without a subroutine you would
; either repeat the painter four times (inlining) or write one loop that knows
; all four colors — the call lets the loop stay simple and the painter stay
; written once.  That is when a subroutine earns its keep.
; =============================================================================
PaintBand:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEX                     ; one line fewer to go: 48, 47, ... 1
    BNE -                   ; loop until the scanline counter reaches 0
    RTS                     ; return; the return address comes off the stack

; =============================================================================
; DATA — the band palette, addressed as BandColors,X (X = band index)
; =============================================================================
BandColors:
    !byte RED, GREEN, BLUE, GOLD    ; band 0 = top ... band 3 = bottom

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

> The complete, fully-commented source lives in
> `lessons/part1-6502-cpu/08-stack-and-subroutines/08-stack-and-subroutines.asm`.

### Code Walkthrough

#### Step 1 — The frame calls once, and the stack goes down by two

```asm
    JSR DrawScreen          ; SP: $FF -> $FD ... and back to $FF on return
```

At `StartFrame` the stack is empty (`SP = $FF`), because the previous frame unwound every byte it pushed. This `JSR` pushes the return address (two bytes: high, then low — actually into `$01FF` and `$01FE`) and `SP` becomes `$FD`. When `DrawScreen`'s `RTS` runs at the end of the picture, those bytes come back off and `SP` is `$FF` again. One call, one clean round trip.

#### Step 2 — The push/pull round trip around every band

```asm
    TXA                     ; A = the band index...
    PHA                     ; ...saved on the stack   (SP: $FD -> $FC)
    LDA BandColors,X        ; A = this band's color (PHA did not touch X)
    LDX #LINES              ; X = 48: the line count PaintBand wants
    JSR PaintBand           ; paint the band          (SP: $FC -> $FA inside)
    PLA                     ; A = the band index back (SP: $FC -> $FD)
    TAX                     ; X = our counter again
```

This is the heart of the lesson. `X` is `DrawScreen`'s own counter — the index of the band being painted — and `PaintBand` needs `X` for its line count. There is no `PHX` instruction, so saving X means copying it through A: `TXA` then `PHA`. After the call, `PLA` / `TAX` puts it back. Between the `PHA` and the `PLA`, the counter exists only as one byte on the stack at `$01FD` — and the callee is free to use `X` all it likes.

#### Step 3 — The shared painter

```asm
PaintBand:
-   STA WSYNC               ; wait for the next scanline to start
    STA COLUBK              ; paint it with the color in A
    DEX                     ; one line fewer to go: 48, 47, ... 1
    BNE -                   ; loop until the scanline counter reaches 0
    RTS                     ; return; the return address comes off the stack
```

The color arrives in A and the line count in X, and the loop paints one scanline per pass. `RTS` takes the return address back off the stack — the same two bytes the `JSR` pushed, at whatever addresses the stack pointer was pointing at. Note the write order: the color is written *after* the `WSYNC`, in the first few cycles of the line and before the TIA has begun drawing on it, so band boundaries are clean. Moving that `STA COLUBK` above the `WSYNC` produces a small notch on the first line of every band — the kind of one-line blemish you only see when you count cycles.

#### Step 4 — Why the frame pre-loads a color

```asm
    LDA BandColors          ; pre-load the top band's color BEFORE the beam
    STA COLUBK              ; is released...
```

The first visible line has to be red, and the only code that knows how to paint a band is behind a `JSR` — and its first act once inside is a `WSYNC`, so `PaintBand` cannot write anything until the *next* line starts. A call is not instant, so the frame gives the painter a head start: the top band's color goes into `COLUBK` *while the beam is still blanked*. Without it, the whole first visible line would show last frame's bottom color — `PaintBand` only replaces it at the next line boundary. It is a small thing, and it is exactly the sort of accounting that subroutines add to a kernel.

#### Step 5 — Balanced, or the stack leaks a byte per frame

After the fourth band, `DrawScreen`'s `RTS` returns to the frame loop with `SP = $FF`. That is the invariant to watch in the debugger: **frame top, `SP` = `$FF`, forever**. A missing `PLA` here does not stay quiet for long: `TAX` then reloads X from A, which `PaintBand` left holding the color byte — so `INX` / `CPX #BANDS` never matches 4, the band loop never exits, and the frame never ends at all (and each pass round it pushes another byte that is never pulled). Exercise 2 is built the other way round, counting down with the callee doing the restore, so there the same mistake is visible as a picture that collapses to one band.

## What You Should See

Four horizontal bands fill the visible picture: **red** (`$42`) on top, then **green** (`$C8`), **blue** (`$96`), and **gold** (`$1A`) at the bottom. Each band is one 48-line `PaintBand` call, and the top band is one scanline taller because the beam-release line already carries its color — 193 non-blanked scanlines in all. Nothing moves: the same four calls produce the same four bands, 60 times a second, and the boundaries between them are exact scanlines.

![Stella running the Lesson 08 subroutine-bands ROM: four horizontal bands, red then green then blue then gold from top to bottom, painted by one shared PaintBand subroutine](/images/lesson08/subroutine-bands.png)

<RomPlayer rom="/roms/part1-6502-cpu/08-stack-and-subroutines/08-stack-and-subroutines.bin" title="Lesson 08 — The Stack and Subroutines" />

The ROM's real output is in the debugger (backtick `` ` ``). There are two places to look.

**Registers — watch `SP` through one frame.** Step into the `JSR DrawScreen` and it becomes `$FD`; step to the `PHA` in the band loop and it is `$FC`; step into `PaintBand` and it is `$FA`. Then let it run and check any frame top: `SP` is `$FF`. The exact ledger is in Section 4 of the theory — every value in it is two bytes per call plus one byte per push.

**Memory — look at `$01FB–$01FF`.** That is where the stack is writing, and on this machine those addresses *are* the RAM bytes `$FB–$FF` (the RIOT's 128 bytes are mirrored from `$0080–$00FF` into `$0180–$01FF`). Step over a `JSR PaintBand` and watch `$01FB`/`$01FC` change to the return address; step over the `PHA` and `$01FD` gets the band counter. Then look at the RAM view at `$FB` and see the exact same bytes. This is the collision hazard in person — and the reason this ROM declares no variables at all.

## Exercises

### Exercise 1: Eight Bands from Eight Calls

**Challenge:** Keep the same four colors, but double the number of bands: **eight** bands, each built from a 24-line `PaintBand` call, instead of four of 48, so the frame makes eight calls to `PaintBand` instead of four. Change as little as possible.

**Hints:**
1. Only three things change: `BANDS` goes from 4 to 8, `LINES` from 48 to 24 (8 × 24 = 192 painted lines; the beam-release line still carries the top band's color, so the picture stays 193 non-blanked scanlines), and the color table repeats its four entries.
2. The band loop is untouched — that is the payoff of a shared subroutine. You are not copying code, you are calling it more often.
3. Watch the stack in the debugger while it runs: twice the calls means twice the push/pull traffic per frame, but the *deepest* `SP` is unchanged at `$FA`, because each band's round trip is balanced before the next one starts.

**Expected Result:** Eight bands — red, green, blue, gold, red, green, blue, gold from top to bottom (the top band one scanline taller, from the beam-release line, exactly as in the lesson ROM).

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Let the Callee Save X

**Challenge:** Move the saving into the subroutine. Write `PaintBandSafe`, a painter that **does** clobber X (it uses X for its line count) but gives the caller's X back untouched, using `TXA`/`PHA` on entry and `PLA`/`TAX` just before the `RTS`. Then keep the band counter live in X in `DrawScreen` and let the callee protect it.

**Hints:**
1. The save/restore dance costs A, so hand the color to the painter in **Y** instead of A: `TAY` in the caller, `TYA` inside, and the loop can then keep the color in A while the X save/restore uses the stack.
2. Count the band counter **down** from 3 to 0 with `DEX`/`BPL` — and index the color table accordingly (index 3 is the top band). It makes the failure mode visible.
3. The painter's line loop ends with X = 0. If you delete the `PLA`/`TAX`, the next `DEX` turns X into `$FF`, `BPL` falls through, and the loop exits after **one** band. The picture is the test: four bands mean X survived, one band means it did not.

**Expected Result:** The same four-band picture as the lesson ROM — red, green, blue, gold — with the counter surviving on the callee's honor instead of the caller's push.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Three Levels Deep *(Stretch Goal)*

**Challenge:** Build a call chain three levels deep — frame loop → `DrawScreen` → `PaintBandRow` → `PaintBand` — and show in the debugger that `SP` drops exactly 2 bytes per level: `$FF → $FD → $FB → $F9`, then returns to `$FF` every frame. The middle level just supplies the line count and delegates.

**Hints:**
1. The depth math is pure subtraction: `$FF − 2 − 2 − 2 = $F9`. Each `JSR` pushes a 2-byte return address.
2. Keep the band counter in **Y**, which no level of the chain touches — the lesson's `PaintBand` leaves Y alone by contract — then you need no extra push, and the chain really is exactly three `JSR`s deep. (With an extra `PHA` in the chain the deepest point would be `$F8`, and the stack would be one byte deeper than the exercise's target.)
3. The chain descends to `SP = $F9`, and its pushes write bytes down to `$FA` (`$01FA`/`$01FB` are RAM `$FA`/`$FB`). Keep variables below `$F9`.

**Expected Result:** The same four-band picture, painted through a three-deep chain. In the debugger: `SP` = `$F9` inside `PaintBand`, `$FF` at the frame top, and the same six bytes on the stack in between, every frame.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **The stack lives in page `$01` and grows down**: `SP` points at the next free byte, `$FF` means empty, and each push moves down one byte
- ✅ **`PHA`/`PLA` move one byte, `PHP`/`PLP` the flags, `JSR`/`RTS` a return address**: 2 stack bytes and 12 cycles per call and return
- ✅ **`JSR` pushes address − 1 and `RTS` adds 1** — which is why a subroutine must be entered with `JSR`, never with `JMP`
- ✅ **A call saves nothing but the return address**: whatever you need afterwards must be on the stack or in a register the callee promises not to touch
- ✅ **Either the caller or the callee can save a register** — but the subroutine's contract must say which registers survive, and somebody must do it
- ✅ **Balance every push with a pull**: the frame-top `SP = $FF` is the checksum; a leaked byte per frame walks the stack down through RAM
- ✅ **On the 2600, page `$01` mirrors RAM `$80–$FF`**: the stack is not extra memory, it is your variable space — keep variables clear of the deepest call chain (the lesson ROM descends to `SP = $FA`, its pushes writing down to `$FB`; the three-level chain of Exercise 3 descends to `$F9`)

## What's Next

Subroutines and the stack are now in your toolkit, and from here on every lesson uses them — but the only operations you have applied to a byte so far are addition, subtraction, comparison, and counting. In [Lesson 09: Bitwise Operations](/part1-6502-cpu/09-bitwise-operations) you meet `AND`, `ORA`, `EOR`, and the shifts: how to test, set, clear, and move individual bits — the instructions that turn one byte into eight independent flags you can use.
