---
title: "Lesson 60: DPC and DPC+ — Enhanced Audio and Graphics"
description: "Build a real 10,240-byte DPC cartridge for the Atari 2600: lay out two 4K banks plus a 2K display image, enter at $F080 because the first 128 bytes of every bank are the Display Processor Chip's register window, drive the playfield from three data fetchers on every scanline, twinkle a starfield with the DPC's random generator, and, in Exercise 3, read the music-fetcher registers — then separate what the DPC really is from what DPC+ needs on a Harmony or Melody ARM cartridge."
prev:
  text: "Lesson 59: Self-Modifying Code — The Ultimate 6502 Trick"
  link: "/part8-advanced/59-self-modifying-code"
next:
  text: "Lesson 61: Compression & Data Encoding — Fitting More in 4KB"
  link: "/part8-advanced/61-compression"
---

# Lesson 60: DPC and DPC+ — Enhanced Audio and Graphics

> **Part 8: Advanced Topics** · Estimated time: 120 minutes
> **Prerequisites:** Lesson 03 (the memory map), Lesson 04 (registers and memory), Lesson 12 (the frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players), Lesson 28 (one HMOVE), Lesson 48 (the kernel taxonomy), Lesson 56 (banking)
> **You will learn:** how the Display Processor Chip in Pitfall II turns a 4K cartridge into a 10K cartridge with a 2K display image; why every DPC bank starts its code at `$F080`; the exact register window at `$1000-$107F` and the decode that makes DF1's bottom `$1049`; how eight data fetchers work; how three fetchers drive PF0/PF1/PF2 from three 192-byte planes; how the DPC random generator is clocked and read; how the music fetchers turn a counter into a 4-bit amplitude; and what DPC+ adds on a Harmony or Melody cartridge — and why a plain cartridge cannot run it
> **You will build:** "the display processor" — a 10,240-byte DPC ROM with a bold "DPC" tunnel, a starfield twinkled by the DPC's random generator, and a white player-0 probe; plus three 10,240-byte exercise solutions: a blue diamond tunnel, a full-screen RNG starfield, and a DPC music fetcher

## Introduction

Lesson 56 showed you the first rule of bank switching: the 6507 sees one 4K window at `$F000-$FFFF`, and the cartridge hides more ROM behind it. The F8 mapper put two 4K banks behind that window. This lesson goes one step further. The cartridge contains a second chip — the **Display Processor Chip**, or DPC — that sits beside the ROM and does work the 6507 cannot do fast enough: it holds a 2K display image, walks eight independent counters through it, generates random numbers, and plays three extra music channels. The DPC is the chip David Crane designed for *Pitfall II: Lost Caverns* in 1984, and it is the reason that game has a detailed underground world and continuous music on a console with 128 bytes of RAM.

The DPC is not a bank-switching trick in the ordinary sense. It is a **mapper with a coprocessor**. The 10,240-byte image is two 4K program banks followed by a 2K display image. Three of the chip's eight data fetchers read one byte each from that display image on every scanline; the 6507 copies those bytes straight into `PF0`, `PF1` and `PF2`. The result is a full-screen playfield that costs the CPU only three loads and three stores per line — no 192-byte tables in RAM, no decompression, no per-line address arithmetic. A separate path is a random generator that the lesson uses to twinkle the stars. The music fetchers turn the same counter idea into three square-wave channels.

The companion program `60-dpc-plus.asm` is a real DPC ROM, not a DPC+ one. That distinction matters, and this lesson is careful about it. DPC is the original 1984 cartridge chip, and this lesson runs it in Stella 7.0's DPC emulation. DPC+ is a modern **Harmony/Melody** scheme that puts an ARM microcontroller on the cartridge; it uses a larger 32K image, more RAM and extra registers. Section 9 explains what DPC+ adds, and the lesson does not pretend to build it. What you build here is a 10,240-byte image in the format the DPC used, which Stella identifies as `DPC* (10K)`.

::: details TypeScript Equivalent

A DPC is easiest to understand as a small object with eight counters and a 2K array. In TypeScript it might look like this:

```typescript
type Fetcher = {
  counter: number;   // 11 bits, 0..2047
  top: number;       // 8 bits
  bottom: number;    // 8 bits
  flag: number;      // 0x00 or 0xFF
};

class Dpc {
  private display = new Uint8Array(2048);
  private fetchers: Fetcher[] = Array.from({ length: 8 }, () => ({
    counter: 0, top: 0, bottom: 0, flag: 0,
  }));
  private rng = 1;

  // The 128-byte register window: low 3 bits pick a fetcher,
  // bits 3-5 pick the function.
  read(address: number): number {
    const index = address & 0x07;
    const fn = (address >> 3) & 0x07;
    const f = this.fetchers[index];

    if (fn === 0 && index < 4) {
      const value = this.random();
      f.counter = (f.counter - 1) & 0x07ff; // Stella's model also clocks this fetcher
      return value;
    }
    if (fn === 1) {
      const byte = this.display[2047 - f.counter]; // note: backwards
      f.counter = (f.counter - 1) & 0x07ff;         // a read moves it
      return byte;
    }
    return 0;
  }

  write(address: number, value: number): void {
    const index = address & 0x07;
    const fn = (address >> 3) & 0x07;
    const f = this.fetchers[index];
    if (fn === 0) f.top = value;
    if (fn === 1) f.bottom = value;
    if (fn === 2) f.counter = (f.counter & 0x0700) | value;
    if (fn === 3) f.counter = ((value & 0x07) << 8) | (f.counter & 0x00ff);
  }

  private random(): number {
    // The real chip's 8-bit LFSR is clocked by every cartridge access;
    // Stella's model clocks it only on DPC-window and hotspot accesses.
    // It feeds back the inverse of the XOR of bits 7, 5, 4 and 3.
    const bit = 1 ^ (((this.rng >> 7) ^ (this.rng >> 5) ^
      (this.rng >> 4) ^ (this.rng >> 3)) & 1);
    this.rng = ((this.rng << 1) | bit) & 0xff;
    return this.rng;
  }
}
```

The analogy teaches the shape: a register window, eight fetchers, a display array, and a read with a side effect. It breaks in three important places. First, the real DPC is **memory-mapped**: writing `$1040` is not a method call, it is a bus cycle with a function and an index hidden in the address. Second, the display image is **2K of ROM inside the cartridge**, not a heap array; the fetchers read it and cannot write it. Third, on the real chip every cartridge access clocks the random generator, so even instruction fetches change its state; Stella's model clocks it only on DPC-window and hotspot accesses, and the TypeScript object only advances when you call `random()`. The tiny, shared, side-effecting address space is the real lesson.

:::

## Theory

### Section 1: The Chip in Pitfall II

David Crane designed the DPC for *Pitfall II: Lost Caverns* (Activision, 1984). The cartridge contains an 8K program ROM, a 2K display ROM and the DPC chip itself. The chip is described in US Patent 4,644,495, and Stella's `CartDPC` class models it. Its features are:

| Feature | What it gives the 2600 |
|---|---|
| 8K program ROM | Two F8-style 4K banks, selected with `$1FF8`/`$1FF9` |
| 2K display ROM | A picture store the CPU does not have to hold in RAM |
| Eight data fetchers | Counters that read the display ROM and hand the CPU one byte per access |
| Random generator | An 8-bit LFSR the program can read to vary colors or patterns |
| Three music channels | Square-wave generators mixed into a 4-bit amplitude the CPU writes to `AUDV0` |

The DPC was used in Pitfall II and, as far as the historical record goes, in no other cartridge. That is not because it was a bad idea; it was an expensive custom chip in a market where cartridges were already being built down to a price. The lesson follows the documented DPC model implemented by Stella, not a modern approximation.

::: warning Hardware scope
Every measurement in this lesson is from Stella 7.0's DPC model. The ROM was not run on an original DPC cartridge. A stock 2600 cartridge cannot run a 10K DPC image; real hardware needs a DPC donor cartridge (for example Pitfall II) or a compatible flash cart or emulator. The original chip's exact behaviour — the random clocking, the music pitch, the read side effects — may differ from the model.
:::

::: tip Why a coprocessor helps a machine with no frame buffer
On a normal 2600 cartridge the CPU must produce every playfield byte on the scanline where it is needed. A 192-line picture with three playfield bytes per line is 576 bytes of data per frame, and the CPU has to address it, fetch it and store it inside 76 cycles per line. The DPC moves the address arithmetic and the storage into the cartridge. The CPU still does the stores, but the data is already waiting at a fixed address. That is the whole trick: the DPC is a **memory that walks itself**.
:::

### Section 2: The 10K Image and the 4K Window

The 6507 has 13 address lines, so it sees 8K of address space and the cartridge occupies the top 4K window at `$F000-$FFFF`. A DPC cartridge puts three things behind that window:

| File offset | Real address | Virtual address | Contents |
|---|---|---|---|
| `$0000-$0FFF` | `$C000-$CFFF` | `$F000-$FFFF` | bank 0 (the switch stub) |
| `$1000-$1FFF` | `$D000-$DFFF` | `$F000-$FFFF` | bank 1 (the program) |
| `$2000-$27FF` | `$E000-$E7FF` | — | the 2K display image |

8,192 + 2,048 = **10,240 bytes**. The source lays the two banks out with `!pseudopc $F000`, so a label in either bank has the same virtual address as its twin. The flat file is bank 0, then bank 1, then the display image. Stella identifies the result as `DPC* (10K)`.

The DPC is an F8-style mapper: it starts in **bank 1**, and the reset vector at `$FFFC` in bank 1 is the one the CPU uses at power-on. Every bank still needs a valid vector, and bank 0 needs a switch stub, because a cartridge reset or a stray jump must not execute garbage.

#### Why code starts at `$F080`

The DPC's register window occupies `$1000-$107F`. The chip decodes only the low address bits, so `$F000-$F07F` in whichever 4K bank is selected is the same window. The 6507 has no A13-A15, so there is no `$3000` or `$5000` alias. The first 128 bytes of every 4K bank are therefore **reserved**: the low half is the read port (an instruction fetch there would read the DPC registers and clock a data fetcher), and the high half is the write port. Every DPC bank begins with 128 filler bytes, and its code begins at `$F080`.

That leads to a layout detail that catches almost everyone. Bank 0's `$F080` is a six-byte stub:

```asm
Bank0Entry:
    LDA $1FF9       ; select bank 1 (the F8 hotspot)
    JMP $F080       ; the JMP is fetched from bank 1 at $F083
```

The hotspot read changes the bank. The **next instruction fetch** — the `JMP` — comes from bank 1 at `$F083`, not from bank 0. So bank 1 must also have a valid instruction at `$F083`. The lesson puts a second `JMP Init` there:

```asm
Reset:              ; $F080, the reset vector's target
    JMP Init
    JMP Init        ; $F083: the landing pad for bank 0's stub
```

At power-on, bank 1's vector jumps to `$F080` and the first `JMP Init` runs. If bank 0's stub ever runs, its `LDA` selects bank 1 and the `JMP` it fetches at `$F083` lands on the second `JMP Init`. This is Lesson 56's duplicated-stub rule applied to a two-bank DPC image: **never execute across a bank boundary without the target bank selected**.

::: warning The register window is not RAM
`$1000-$107F` looks like ordinary memory, but it is the DPC's control panel. The low 64 bytes are the read port and the high 64 bytes are the write port. A read has side effects: it can decrement a fetcher's counter, update a flag, or clock the random generator. A write can change a counter, a top/bottom limit or a music mode. The first 128 bytes of each bank are skipped for exactly this reason. If you put code or a data table there, you are talking to the chip instead of reading your own bytes.
:::

### Section 3: The Eight Data Fetchers

A **data fetcher** is a counter with a small control block. There are eight of them, DF0-DF7. Each has:

- an **11-bit counter** (0-2047), because the display image is 2K;
- a **top** byte and a **bottom** byte;
- a **flag** byte (0 or `$FF`);
- a **data read** that returns `display[2047 - counter]` and then decrements the counter.

The counter runs **backwards** through the display image. Offset 0 is at counter 2047, offset 683 is at counter 1364, and offset 1366 is at counter 681. The chip addresses the display ROM with `2047 - counter`, so the largest counter value returns the first byte. Once you know the rule, the arithmetic is simple:

| Plane | Display offset | Counter |
|---|---|---|
| plane 0 (PF0) | 0 | 2047 |
| plane 1 (PF1) | 683 | 1364 |
| plane 2 (PF2) | 1366 | 681 |

Each line reads one byte from each plane. All three counters decrement by one, so the three planes stay in lockstep. The lesson resets all three at the top of every frame, which is why the same 192 bytes are shown every time.

The five graphics/data fetchers are DF0-DF4; the three music fetchers are DF5-DF7. The lesson uses DF0, DF1 and DF2 for the playfield. Exercise 2 uses the same three fetchers as a starfield pattern bank, and exercise 3 uses DF5 for music.

::: tip The masked read
Each fetcher also has a **masked read** at `$1010 + index`. It returns `display[2047 - counter] AND flag`. The flag is set to `$FF` when the counter's low byte equals `top` and cleared to `$00` when it equals `bottom`. That is the DPC's built-in vertical window: a program can hide a sprite above and below its allowed rows without testing the row in the kernel. The lesson's main demo uses the plain data read; the masked read is the reason `top` and `bottom` exist.
:::

#### The read/write decode

The register window is not a flat array. An address in `$1000-$107F` decodes into a **function** and a **fetcher index**:

```text
index    = address & 7
function = (address >> 3) & 7
```

The function numbers are:

| Function | Write register (`$1040`+) | Read register (`$1000`+) |
|---|---|---|
| 0 | top | random (index 0-3) / music amplitude (index 4-7) |
| 1 | bottom | display data, decrements the counter |
| 2 | counter low | display data AND flag |
| 3 | counter high (bits 0-2; bit 4 = music mode) | — |
| 6 | reset the random generator | — |
| 7 | — | the fetcher flag |

The formula is why the measured table in the source is not a straight run of eight. DF0's bottom is `$1048`, but DF1's bottom is `$1049` (function 1, index 1), not `$1041` (function 0, index 1). DF2's counter high is `$105A` (function 3, index 2), not `$1053` (function 2, index 3). The first prototype for this lesson wrote the bottom and counter-high registers in the wrong places and lost two of the three planes; the corrected table is the one in the source. Read the address as two fields, never as "the next byte".

::: warning Every read clocks a fetcher
In Stella's model the decode applies to every access in the window, including the random generator. Reading `$1000` is function 0, index 0, so it also decrements **DF0's counter**. If the main loop read the random byte in the middle of a frame, plane 0 would be one line ahead of planes 1 and 2 for the rest of the frame. The lesson reads the random byte at the top of VBLANK and resets the counters immediately afterwards, so the extra decrement is harmless. This is the DPC's version of the "TIA read has a side effect" rule from Lesson 04.
:::

### Section 4: The Register Table

The source defines the measured table as named constants. The full map is:

| Fetcher | Top | Bottom | Counter low | Counter high | Data read |
|---|---|---|---|---|---|
| DF0 | `$1040` | `$1048` | `$1050` | `$1058` | `$1008` |
| DF1 | `$1041` | `$1049` | `$1051` | `$1059` | `$1009` |
| DF2 | `$1042` | `$104A` | `$1052` | `$105A` | `$100A` |
| DF3 | `$1043` | `$104B` | `$1053` | `$105B` | `$100B` |
| DF4 | `$1044` | `$104C` | `$1054` | `$105C` | `$100C` |
| DF5 | `$1045` | `$104D` | `$1055` | `$105D` | `$100D` |
| DF6 | `$1046` | `$104E` | `$1056` | `$105E` | `$100E` |
| DF7 | `$1047` | `$104F` | `$1057` | `$105F` | `$100F` |

The random generator is read at `$1000-$1003` and reset by a write to `$1070-$1077`. The music amplitude is read at `$1004-$1007`; the lesson uses `$1005`. The `$100D-$100F` reads are the plain data reads for DF5-DF7, which are the same fetchers but not the music mixer output.

### Section 5: The 2K Display Image

The 2K image is split into three 192-byte planes plus padding:

| Offset | Bytes | Contents |
|---|---|---|
| 0 | 192 | plane 0: the PF0 byte for each visible line |
| 192 | 8 | padding |
| 200 | 192 | PF2 twinkle phase 1 |
| 392 | 8 | padding |
| 400 | 192 | PF2 twinkle phase 2 |
| 592 | 91 | padding |
| 683 | 192 | plane 1: the PF1 byte for each visible line |
| 875 | 5 | padding |
| 880 | 192 | PF2 twinkle phase 3 |
| 1072 | 294 | padding |
| 1366 | 192 | plane 2: the PF2 byte for each visible line |
| 1558 | 490 | padding to 2,048 |

The three main planes are at offsets 0, 683 and 1366. The 683 is not arbitrary: three 192-byte planes would be 576 bytes, but the DPC's fetchers use independent counters, so the planes can sit at any offsets. The lesson picks 683 because it leaves a clean 491-byte gap after the first plane (192 + 491 = 683) and another 491-byte gap after the second (683 + 192 + 491 = 1366). The gaps are large enough to hold the three extra PF2 planes used by the twinkle.

The source's `!fill` arithmetic checks the offsets at build time:

```asm
    !fill 200 - (* - DisplayImage), $00
    ; phase 1
    !fill 400 - (* - DisplayImage), $00
    ; phase 2
    !fill 683 - (* - DisplayImage), $00
    ; plane 1
```

If a plane overruns its slot, the fill count goes negative and ACME fails. That is deliberate: a misplaced display image produces a garbled picture with no error message, and the lesson would rather fail the build.

#### The picture

The 20-bit playfield is drawn with `CTRLPF = $01`, so the left half is mirrored on the right. The picture is:

- a solid top band (rows 0-3) and bottom band (rows 188-191);
- two 2-bit side walls at the left and right screen edges (PF0 `$30`, bits 4-5 — the two leftmost playfield pixels, x=0-7 — and its mirror);
- stepped perspective braces in the top and bottom thirds, meeting near the centre;
- a bold "DPC" logo at bits 2-18, rows 84-97: a five-bit-wide, seven-row font with each font row duplicated to 14 scanlines;
- static stars in PF0 and PF1, plus a twinkling star set in PF2;
- a white 8×8 diamond drawn by player 0 at x=40, rows 70-77.

`PF0` bit 4 is the leftmost pixel (`include/vcs.asm`), so the `$30` wall bytes put the wall at x=0-7 and its mirror; `$C0` would put it at x=8-15.

Because the playfield is reflected, the logo appears twice: "DPC" on the left and its mirror on the right. That is not a bug. It is what a reflected playfield does, and it is a useful reminder that the 20 bits are the **left half** of the screen, not the whole screen.

### Section 6: The Kernel

The visible kernel is three DPC reads and three playfield writes per line:

```asm
Line:
    LDA DPC_DF0
Fetch0:
    STA PF0
    LDA DPC_DF1
Fetch1:
    STA PF1
    LDA DPC_DF2
Fetch2:
    STA PF2
    LDA Probe,Y
    STA GRP0
    STA WSYNC
    INY
    CPY #192
    BNE Line
```

The cycle budget, including the seven-cycle loop tail (`INY`, `CPY`, `BNE`) that runs at the top of the next line. All cycles are 0-based Stella cycles; a store writes on its last cycle:

| Instruction | Cycles | Starts at | Write completes |
|---|---|---|---|
| loop tail | 7 | 0 | — |
| `LDA DPC_DF0` | 4 | 7 | — |
| `STA PF0` | 3 | 11 | 13 |
| `LDA DPC_DF1` | 4 | 14 | — |
| `STA PF1` | 3 | 18 | 20 |
| `LDA DPC_DF2` | 4 | 21 | — |
| `STA PF2` | 3 | 25 | 27 |
| `LDA Probe,Y` | 4 | 28 | — |
| `STA GRP0` | 3 | 32 | 34 |
| `STA WSYNC` | 3 | 35 | — |

The total is 38 cycles including the tail; the `WSYNC` absorbs the remaining 38 of the 76-cycle line. The important numbers are the write cycles:

| Register | Write completes | Its first pixel | Margin |
|---|---|---|---|
| PF0 | cycle 13 | cycle 22.7 | 9.7 |
| PF1 | cycle 20 | cycle 28.0 | 8.0 |
| PF2 | cycle 27 | cycle 38.7 | 11.7 |
| GRP0 (probe at x=40) | cycle 34 | cycle 36.0 | 2.0 |

Each playfield byte covers four colour clocks per bit: PF0 owns screen x=0-15, PF1 owns x=16-47, PF2 owns x=48-79. The kernel writes each register before the beam reaches its region. The probe is the tightest: its `GRP0` write lands on cycle 34, and x=40 starts at cycle 36.0. If you add more work before `STA GRP0`, move the probe to the right or accept a clipped left edge.

::: tip Why the order is not arbitrary
The obvious order — fetch all three bytes, then store all three — also fits the 38-cycle budget: tail 7 + 3×`LDA` 12 + 3×`STA` 9 + probe `LDA` 4 + `STA GRP0` 3 + `STA WSYNC` 3 = 38. Its weakness is PF0: the `STA PF0` completes on cycle 21, only 1.7 cycles before PF0's first pixel at 22.7. The lesson interleaves the fetches and stores — fetch DF0, store PF0, fetch DF1, store PF1, fetch DF2, store PF2 — which moves PF0's store to cycle 13 and PF1's to 20, for 9.7 and 8.0 cycles of margin. PF2's store completes on cycle 27, 11.7 cycles before its first pixel at 38.7 (10.7 if measured from the start of the next instruction), the same in both orders; the probe's 7 cycles come after the stores and leave a 2.0-cycle margin. When you add a per-line effect, count the cycles **from the previous line's loop tail**, not from the `Line` label.
:::

The frame around the kernel is the standard Part 8 skeleton:

```text
3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229/6
```

One HMOVE, inside VBLANK, positions player 0 with the Lesson 26 divide-by-15 dance. The HMOVE artifact blanks the first eight visible pixels of the following line; that line is still inside VBLANK here, so the blanking is unseen.

### Section 7: The Random Generator

The DPC's random generator is an **8-bit linear-feedback shift register**. Stella's model taps bits 7, 5, 4 and 3, shifts the byte left, and feeds the inverse of their XOR back into bit 0. The state is never zero, so the sequence has period 255. On the **real chip** the generator is clocked by every cartridge access — instruction fetches, data reads, register reads and writes — not just by a read of `$1000`. Stella's `CartDPC::peek` clocks it only on DPC-window and hotspot accesses as a speed optimisation, so the measured sequence (`$03`, `$A4`, `$5B`, ...) is Stella's, not the original hardware's. The taps and the 255-state cycle are the same in the model. A read of `$1000` returns the current byte; a write to `$1070` resets the register to 1.

The lesson reads the generator once per frame:

```asm
    LDA DPC_RNG
RngRead:
    STA Rng
```

and uses the low two bits to pick one of four star phases:

```asm
    LDA Rng
    AND #$03
    STA Twinkle
    TAX
    LDA PhaseLo,X
    STA StarPtr
    STA DPC_DF2_LO
    LDA PhaseHi,X
    STA DPC_DF2_HI
```

The four phases live in the display image's padding. Phase 0 is the main PF2 plane at offset 1366 (counter 681); phases 1-3 are at 200, 400 and 880 (counters 1847, 1647 and 1167). Each plane carries the same tunnel and logo bits plus a different set of stars. The result is a starfield that jumps whenever the phase changes, while the tunnel and the logo stay put. The two screenshots in "What You Should See" are two of those phases.

In Stella's model the read has the side effect described in Section 3: it decrements DF0's counter. The code reads the random byte **before** it writes the three counters, so the decrement is erased. If you move the read after the reset, plane 0 will be one line out of step for the rest of the frame and the logo's left stroke will visibly shift.

### Section 8: The Music Fetchers

DF5, DF6 and DF7 are the music channels. Their counters are not decremented by CPU reads when music mode is on; instead, the DPC's **own oscillator** decrements them. In Stella's model the oscillator's default rate is 20,000 Hz (`audio.dpc_pitch`), and the real chip's exact pitch is a hardware detail this lesson does not claim.

Each music fetcher has the same top, bottom and counter registers as a graphics fetcher. The difference is in the counter-high write: **bit 4 enables music mode**. In music mode a write to the counter-low register loads the low byte from `top`, and the oscillator walks it down. When the low byte reaches `bottom`, the channel's flag goes low; when it is above `bottom`, the flag is high. A top of 63 and a bottom of 31 therefore produce a 50% square wave with a period of 64 oscillator clocks:

```text
20,000 / (63 + 1) = 312.5 Hz
```

Reading the amplitude at `$1004-$1007` updates the three music counters from the elapsed CPU cycles and returns a 4-bit value. In Stella's model the value is the three channel flags interpreted as a 3-bit index into:

```text
{ 0, 4, 5, 9, 6, 10, 11, 15 }
```

One channel gives 0 or 4 in Stella. (Javatari's mixer uses its own amplitude table, so the in-page player may sound slightly different; the register behaviour is the same.) The program writes that value to `AUDV0`; with `AUDC0 = 0` the TIA output is a constant high, so `AUDV0` becomes the waveform. `AUDF0` is irrelevant in that mode, but the lesson sets it to 0 for a known state.

Exercise 3 adds this to the lesson program. The measured amplitude in Stella alternates 04/00 every **25 scanlines** — 25 high, 25 low, 50 lines per cycle, about 314 Hz at 262 lines and 60 Hz. That is the evidence that the music fetcher is running, not just that the registers were written.

::: warning Music mode changes the counter's clock
A graphics fetcher decrements once per read. A music fetcher in music mode is clocked by the oscillator and **does not** decrement when you read its amplitude. That is why the same counter registers can serve two very different jobs. If you write a music fetcher's counter low while music mode is on, the value is replaced by `top`; use the counter-high write to change the mode, and change the period through `top`/`bottom`.
:::

### Section 9: DPC+ — The Harmony and Melody ARM

DPC+ is not a bigger DPC. It is a different cartridge architecture built around the **Harmony** and **Melody** flash carts, which carry an ARM microcontroller next to the 6502. Stella's `CartDPCPlus` class describes the image:

| DPC+ | Detail |
|---|---|
| Image size | 32K |
| First 3K | the ARM driver, executed in place through a Thumb emulator |
| Program banks | six 4K banks for 6502 code |
| Bank switching | accesses to `$1FF6-$1FFB` |
| Cartridge RAM | 8K: 3K ARM driver, 4K display data (loaded from ROM at startup), 1K frequency table |
| Fetchers | eight data fetchers; the range and the idea carry over, the register map does not |
| Random generator | 32-bit LFSR (the DPC's is 8-bit) |
| Extra | three music channels, an optional Fast Fetch mode |

The 32K image decomposes as 3K of ARM driver plus 29K of 6502 program, display data and frequency tables: six 4K banks (24K) + 4K display + 1K frequency = 29K. That is where the "29K/32K" description comes from.

A plain cartridge cannot run a DPC+ image. There is no ARM, no 8K of cartridge RAM, no Thumb emulator and no `$1FF6-$1FFB` bank latch. The .bin also has a different size and layout from the 10,240-byte DPC image this lesson builds. DPC+ needs a Harmony or Melody cartridge (or an emulator that models one). The lesson builds a **real DPC image** and documents DPC+ so you can recognise the difference; it does not claim a DPC+ build.

::: tip What DPC+ changes for a programmer
The biggest practical difference is that the DPC+ display data is **RAM**, not ROM. A DPC program ships a fixed 2K picture. A DPC+ program can rewrite its 4K display data at run time, which is why DPC+ games can stream graphics and use the ARM for heavier work. The `$1000-$107F` range and the eight-fetcher idea carry over, but the DPC+ register map is different: reads are `$1000-$1027`, writes are `$1028-$107F`, and the function codes differ (function 0 random/amplitude: random next/prior/bytes at indices 0-4, amplitude at index 5; function 1 `DFxDATA`, 2 `DFxDATAW`, 3 `DFxFRACDATA`, 4 flags). Do not reuse the DPC register table.
:::

### Section 10: What Stella Shows

Stella identifies the committed ROM as `DPC* (10K)`. Its debugger has a DPC tab that shows the eight counters, tops, bottoms and flags; the TIA tab shows the playfield registers. The state logs in this lesson's evidence were produced with:

```bash
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F080' docs/public/roms/part8-advanced/60-dpc-plus/60-dpc-plus.bin
```

The `BP:` line reports the frame, scanline, cycle and the CPU registers. `Fetch0`, `Fetch1` and `Fetch2` are placed on the `STA PFx` instructions, so the reported A is the byte the DPC just returned. `RngRead` is placed on the `STA Rng` after the `LDA $1000`, so its A is the random byte. `Frame` is placed after `LDA FrameCount`, so its A is the frame number.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson60.bin lessons/part8-advanced/60-dpc-plus/60-dpc-plus.asm
stella build/lesson60.bin
```

The main ROM is 10,240 bytes. The three exercise solutions are also 10,240 bytes; `npm run roms` builds all four into `docs/public/roms/part8-advanced/60-dpc-plus/`.

### Full Source

The complete annotated source:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 60: DPC and DPC+ — Enhanced Audio and Graphics — Racing the Beam
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the display processor": a 10,240-byte DPC cartridge.  The DPC is the
;   custom chip David Crane designed for Pitfall II (1984).  It gives the
;   2600 a 2K display image and eight data fetchers; three of them feed the
;   playfield registers on every scanline, and its random number generator
;   twinkles the stars.  The picture is a stepped cyan tunnel with a bold
;   "DPC" logo, a starfield, and a small white probe drawn by player 0.
;
; The 10K layout (the flat file is 10,240 bytes):
;   file offset $0000-$0FFF   bank 0, real $C000, assembled with !pseudopc $F000
;   file offset $1000-$1FFF   bank 1, real $D000, assembled with !pseudopc $F000
;   file offset $2000-$27FF   the 2K DPC display image, real $E000-$E7FF
;
; DPC starts in BANK 1, exactly like F8.  The reset vector at $FFFC in
; bank 1 points to $F080.  Why $F080 and not $F000?
;   The DPC's register window is at $1000-$107F.  The chip decodes only
;   the low address bits, so $F000-$F07F in whichever 4K bank is selected
;   is the same window.  The 6507 has no A13-A15, so there is no $3000 or
;   $5000 alias.  The first 128 bytes of every DPC bank are therefore
;   reserved: the low half is the read port (an instruction fetch there
;   would read the DPC registers and clock a data fetcher) and the high
;   half is the write port.  Every DPC bank starts with 128 filler bytes,
;   and its code at $F080.
;
; Bank 0 is only a stub.  It is never selected by this program, but every
; bank needs a valid vector, and the stub must switch safely if it runs:
;   $F080  Bank0Entry: LDA $1FF9   ; select bank 1 (the F8 hotspot)
;          JMP $F080              ; fetched from bank 1 at $F083
; Bank 1 carries a landing pad at $F083 as well:
;   $F080  Reset:      JMP Init    ; the reset vector's target
;   $F083             JMP Init    ; the JMP above is fetched here
; The LDA's switch takes effect before the following instruction fetch, so
; the target bank (not the bank that issued the JMP) supplies the next
; instruction.  That is the Lesson 56 rule, unchanged.
;
; The DPC register window (the chip's own memory map):
;   $1000-$1003  read  random number generator (4 mirrors)
;   $1004-$1007  read  music amplitude (4 mirrors)
;   $1008-$100F  read  DF0-DF7 display data; the read decrements the counter
;   $1010-$1017  read  DF0-DF7 display data AND the fetcher flag
;   $1038-$103F  read  DF0-DF7 flag
;   $1040-$1047  write DF0-DF7 top
;   $1048-$104F  write DF0-DF7 bottom
;   $1050-$1057  write DF0-DF7 counter low
;   $1058-$105F  write DF0-DF7 counter high (bits 0-2); bit 4 = music mode
;   $1070-$1077  write reset the random generator
; The write decode is: function = (address >> 3) & 7, index = address & 7.
; That is why DF1's bottom is $1049 (not $1041) and DF2's counter high is
; $105A (not $1053).  The addresses below are the measured table.
;
; The display image (2,048 bytes):
;   offset 0    192 bytes: plane 0, the PF0 byte for each visible line
;   offset 200  192 bytes: PF2 twinkle phase 1
;   offset 400  192 bytes: PF2 twinkle phase 2
;   offset 683  192 bytes: plane 1, the PF1 byte for each visible line
;   offset 880  192 bytes: PF2 twinkle phase 3
;   offset 1366 192 bytes: plane 2, the PF2 byte for each visible line
; The three main planes sit at 0, 683 and 1366; the padding between them
; holds three extra PF2 planes.  A fetcher returns display[2047 - counter],
; so the main counters start at 2047, 1364 and 681:
;   2047 - 0 = 2047, 2047 - 683 = 1364, 2047 - 1366 = 681.
; Each line reads one byte from each plane; the three counters decrement
; together, so the three planes stay aligned.
;
; The twinkle:
;   Plane 0 and plane 1 never change: they carry the frame, the logo and
;   the static stars.  Plane 2 has four variants.  Phase 0 is the main
;   plane at 1366; phases 1-3 are the copies at 200, 400 and 880.  Each
;   variant carries the same tunnel/logo bits and a different set of stars.
;   Every frame the random generator picks a phase, and DF2's counter is
;   set to 2047 - the phase's display offset.  The stars jump, the tunnel
;   and the logo do not.  The phase counters are:
;     phase 0: 2047 - 1366 = 681  = $02A9
;     phase 1: 2047 -  200 = 1847 = $0737
;     phase 2: 2047 -  400 = 1647 = $066F
;     phase 3: 2047 -  880 = 1167 = $048F
;
; One DPC trap in Stella's model: a read of $1000 (the random generator)
; also decrements DF0's counter, because the decode uses index 0.  The main
; loop therefore reads the random byte BEFORE it resets the counters.  A
; read in the middle of the frame would shift plane 0 by one line.
;
; The picture (192 visible lines):
;   rows 0-3      solid top band
;   rows 4-67     stepped perspective braces, meeting at bits 9-10
;   rows 68-123   the open middle: stars, the probe, the DPC logo
;   rows 84-97    the bold "DPC" logo: a five-bit-wide, seven-row font,
;                 bits 2-18, each font row duplicated to 14 scanlines
;   rows 124-187  stepped braces, opening downward
;   rows 188-191  solid bottom band
;   The playfield is reflected (CTRLPF = $01), so the left half is drawn
;   again as its mirror on the right: the logo appears twice, mirrored.
;   Player 0 draws a small white diamond at x=40, visible rows 70-77.
;
; Frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;   One HMOVE, inside VBLANK, positions player 0.
;
; The 1-line kernel (38 cycles of 76, including the 7-cycle loop tail that
; runs at the top of each line; the phase tables sit inside one page and
; the probe strip is page-aligned):
; Cycles below are 0-based Stella cycles; a store writes on its last cycle.
;   loop tail       7   INY + CPY + BNE from the previous line
;   LDA $1008       4   fetch plane 0
;   STA PF0         3   write PF0 (cycle 13; PF0's first pixel at 22.7)
;   LDA $1009       4   fetch plane 1
;   STA PF1         3   write PF1 (cycle 20; PF1's first pixel at 28.0)
;   LDA $100A       4   fetch plane 2
;   STA PF2         3   write PF2 (cycle 27; PF2's first pixel at 38.7)
;   LDA Probe,Y     4
;   STA GRP0        3   the white probe (cycle 34; x=40's first pixel at 36.0)
;   STA WSYNC       3
; The writes are ordered so each playfield register is written before the
; beam reaches the pixels that register controls, and the probe's GRP0
; write still lands before x=40 (a 2.0-cycle margin).
;
; Checkpoints (Stella's scanline/cycle in parentheses):
;   Reset ($F080), Main, StartFrame (259/3), VblankStart (0/5),
;   BodyStart (37/5), OverscanStart (229/6), Line,
;   Fetch0/Fetch1/Fetch2 (A = the fetched plane byte),
;   RngRead (A = the random byte), Frame (A = FrameCount).
;
; RAM map (+clean_start zeroes every byte):
;   $80  FrameCount  frames since reset, wraps at 256 (the Frame checkpoint)
;   $81  StarPtr     the selected phase's DF2 counter low byte
;   $82  Twinkle     the phase index (Rng & 3)
;   $83  Rng         the raw read of $1000
;   $84-$9F free
;   $F8-$FF stack
; The DPC registers and the 2K display image are in the cartridge, not RAM.
;
; Build: acme -f plain -o build/lesson60.bin \
;        lessons/part8-advanced/60-dpc-plus/60-dpc-plus.asm
; Run:   stella build/lesson60.bin
; The ROM is 10,240 bytes and Stella reports DPC* (10K).
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK
OVERSCAN_TIMER = 36      ; 30-line overscan
POS_BIAS       = 3       ; the SetHorizPos output-delay bias from Lesson 26

SCREEN_LINES   = 192     ; the DPC kernel draws every visible line
PLAYER_X       = 40      ; the probe's left edge, TIA X 40..47

; =============================================================================
; DPC REGISTERS — the cartridge's 128-byte window at $1000-$107F
; =============================================================================
; Reads and writes use the same 128 bytes.  The low three address bits
; select the fetcher; bits 3-5 select the function.  The constants below
; spell the measured table out so the source never relies on the formula
; at the call site.
DPC_RNG        = $1000   ; read: the random byte (index 0, function 0)
DPC_MUSIC      = $1005   ; read: the 4-bit music amplitude (exercise 3)
DPC_DF0        = $1008   ; read: display plane 0, decrements DF0's counter
DPC_DF1        = $1009   ; read: display plane 1, decrements DF1's counter
DPC_DF2        = $100A   ; read: display plane 2, decrements DF2's counter

DPC_DF0_TOP    = $1040   ; write: DF0 top
DPC_DF1_TOP    = $1041   ; write: DF1 top
DPC_DF2_TOP    = $1042   ; write: DF2 top
DPC_DF0_BOTTOM = $1048   ; write: DF0 bottom
DPC_DF1_BOTTOM = $1049   ; write: DF1 bottom
DPC_DF2_BOTTOM = $104A   ; write: DF2 bottom
DPC_DF0_LO     = $1050   ; write: DF0 counter low
DPC_DF1_LO     = $1051   ; write: DF1 counter low
DPC_DF2_LO     = $1052   ; write: DF2 counter low
DPC_DF0_HI     = $1058   ; write: DF0 counter high (bits 0-2)
DPC_DF1_HI     = $1059   ; write: DF1 counter high (bits 0-2)
DPC_DF2_HI     = $105A   ; write: DF2 counter high (bits 0-2)
DPC_RNG_RESET  = $1070   ; write: any value resets the random generator to 1

; =============================================================================
; FIXED DATA ADDRESSES in bank 1
; =============================================================================
; The phase tables sit at $F2F0/$F2F4 inside one page, so the indexed
; loads do not cross a page; the probe strip is page-aligned at $F400.
PhaseLo        = $F2F0   ; 4 bytes: DF2 counter low per twinkle phase
PhaseHi        = $F2F4   ; 4 bytes: DF2 counter high per twinkle phase
Probe          = $F400   ; 192 bytes: one GRP0 byte per visible line

; =============================================================================
; RAM ALLOCATION ($80-$83; +clean_start zeroes every byte)
; =============================================================================
FrameCount     = $80     ; frames since reset, wraps at 256 (Frame checkpoint)
StarPtr        = $81     ; the selected phase's DF2 counter low byte
Twinkle        = $82     ; the phase index (Rng & 3)
Rng            = $83     ; the raw read of $1000

; =============================================================================
; BANK 0 — real $C000, virtual $F000.  THE SWITCH STUB.
; =============================================================================
; The flat ROM starts here.  The first 128 bytes are the shadow of the DPC
; register window and must not contain code.  $F080 is the six-byte stub:
; the hotspot read selects bank 1, and the JMP that follows is fetched from
; bank 1 at $F083, where bank 1 carries a matching JMP Init landing pad.
    * = $C000
    !pseudopc $F000 {

    !fill 128, $EA           ; $F000-$F07F: not code (the register window)

Bank0Entry:
    LDA $1FF9                ; select bank 1 (F8 hotspot)
    JMP $F080                ; fetched from bank 1 at $F083

    !fill $FFFA - *, $EA
    * = $FFFA
    !word Bank0Entry, Bank0Entry, Bank0Entry
}

; =============================================================================
; BANK 1 — real $D000, virtual $F000.  THE PROGRAM (the start bank).
; =============================================================================
; The DPC selects bank 1 at power-on, so the vector at $FFFC below is the
; one the CPU uses.  The first 128 bytes are the register-window shadow;
; the entry is $F080.
    * = $D000
    !pseudopc $F000 {

    !fill 128, $EA           ; $F000-$F07F: not code (the register window)

; -----------------------------------------------------------------------------
; Reset — $F080, the reset vector's target (checkpoint)
; -----------------------------------------------------------------------------
; The first JMP is the real entry.  The second JMP is the landing pad for
; bank 0's stub: when that stub's LDA switches to bank 1, the CPU fetches
; the following JMP from $F083 here, and this second JMP sends it to Init.
Reset:
    JMP Init
    JMP Init

; -----------------------------------------------------------------------------
; Init — one-time hardware setup
; -----------------------------------------------------------------------------
Init:
    +clean_start             ; zero TIA and RAM, set the stack to $FF
    LDA #$00
    STA SWACNT               ; port A is an input port (the joystick)

    LDA #$02
    STA VBLANK               ; blank the picture until the first frame
    LDA #$AE
    STA COLUPF               ; the tunnel is bright cyan
    LDA #$00
    STA COLUBK               ; black space behind it
    LDA #$0E
    STA COLUP0               ; the probe is white
    LDA #$01
    STA CTRLPF               ; reflect the playfield: the right half mirrors

    LDA #$00
    STA DPC_RNG_RESET        ; the DPC's random generator starts at 1
    JMP Main

; -----------------------------------------------------------------------------
; Main — the frame loop
; -----------------------------------------------------------------------------
Main:
    NOP                      ; the Main checkpoint (one pass at startup)
StartFrame:                  ; checkpoint: scanline 259, the first VSYNC line
    +vsync                   ; 3 VSYNC lines: 259, 260, 261

VblankStart:                 ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- read the DPC random generator -------------------------------------------
; In Stella's DPC model this read clocks DF0's counter as a side effect,
; so it happens before the three counters are reset.  Rng is the raw byte;
; Twinkle keeps its low two bits as the star phase.
    LDA DPC_RNG
RngRead:                     ; checkpoint: A = the random byte
    STA Rng

; --- reset the three graphics fetchers ---------------------------------------
; Top = $FF and bottom = $00 for all three.  The plain data read ignores
; top/bottom; they matter only for the masked read and the flag.  Writing
; the top also clears the fetcher's flag.
    LDA #$FF
    STA DPC_DF0_TOP
    STA DPC_DF1_TOP
    STA DPC_DF2_TOP
    LDA #$00
    STA DPC_DF0_BOTTOM
    STA DPC_DF1_BOTTOM
    STA DPC_DF2_BOTTOM

; --- the three counters ------------------------------------------------------
; Plane 0 and plane 1 are fixed:
;   DF0 = 2047 -> plane 0 offset 0
;   DF1 = 1364 -> plane 1 offset 683
; Plane 2 is the twinkle phase: 681 for the main plane at 1366, or the
; counter of one of the three alternate planes in the padding.
    LDA #$FF
    STA DPC_DF0_LO
    LDA #$54
    STA DPC_DF1_LO
    LDA #$07
    STA DPC_DF0_HI
    LDA #$05
    STA DPC_DF1_HI

    LDA Rng
    AND #$03
    STA Twinkle              ; the phase index, 0-3
    TAX
    LDA PhaseLo,X
    STA StarPtr              ; the selected phase's counter low
    STA DPC_DF2_LO
    LDA PhaseHi,X
    STA DPC_DF2_HI

; --- the frame counter -------------------------------------------------------
    INC FrameCount
    LDA FrameCount
Frame:                       ; checkpoint: A = the new frame count

; --- position player 0: one divide-by-15 dance and one HMOVE -------------------
; SetCoarseP0 sets HMP0 and strobes RESP0.  The WSYNC starts a fresh line
; and the HMOVE applies the fine offset in its HBLANK.  This is the frame's
; only HMOVE, and it falls inside VBLANK: the artifact blanks the first
; eight visible pixels of the following line, which is still a VBLANK line.
    LDA #(PLAYER_X + POS_BIAS)
    JSR SetCoarseP0
    STA WSYNC
    STA HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK               ; picture on

; -----------------------------------------------------------------------------
; The visible kernel — 192 lines, three DPC fetches per line
; -----------------------------------------------------------------------------
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    LDY #0
Line:
    LDA DPC_DF0              ; plane 0 byte for this line
Fetch0:                      ; checkpoint: A = the fetched PF0 byte
    STA PF0
    LDA DPC_DF1              ; plane 1 byte for this line
Fetch1:                      ; checkpoint: A = the fetched PF1 byte
    STA PF1
    LDA DPC_DF2              ; plane 2 byte for this line (the star phase)
Fetch2:                      ; checkpoint: A = the fetched PF2 byte
    STA PF2
    LDA Probe,Y              ; the white probe strip
    STA GRP0
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE Line

; -----------------------------------------------------------------------------
; Overscan — 30 lines, then the next frame
; -----------------------------------------------------------------------------
OverscanStart:               ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; -----------------------------------------------------------------------------
; SetCoarseP0 — the Lesson 26 divide-by-15 positioning dance
; -----------------------------------------------------------------------------
; A = the desired left edge + POS_BIAS.  Each loop pass is 5 cycles = 15
; colour clocks, which is why dividing by 15 works.  The remainder becomes
; HMP0's fine value and RESP0 strobes the coarse position.
SetCoarseP0:
    STA WSYNC
    SEC
DivP0:
    SBC #15
    BCS DivP0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS

; -----------------------------------------------------------------------------
; The twinkle phase tables — four DF2 counter values
; -----------------------------------------------------------------------------
; display[2047 - counter], so the counter is 2047 minus the plane's display
; offset.  Phase 0 is the main plane at 1366; phases 1-3 are the copies in
; the padding at 200, 400 and 880.
    !if * > PhaseLo {
        !error "bank 1's code must end before PhaseLo"
    }
    !fill PhaseLo - *, $EA
PhaseLo:
    !byte $A9, $37, $6F, $8F   ; 681, 1847, 1647, 1167
    !fill PhaseHi - *, $EA
PhaseHi:
    !byte $02, $07, $06, $04

    !fill Probe - *, $EA

; -----------------------------------------------------------------------------
; The probe strip — one GRP0 byte per visible line
; -----------------------------------------------------------------------------
; An 8x8 diamond at visible rows 70-77.  Player 0 is positioned once per
; frame by SetCoarseP0.  The probe is a normal TIA object; the playfield
; behind it comes from the DPC.
Probe:
    !fill 70, $00
    !byte $18   ; row 70
    !byte $3C   ; row 71
    !byte $7E   ; row 72
    !byte $FF   ; row 73
    !byte $FF   ; row 74
    !byte $7E   ; row 75
    !byte $3C   ; row 76
    !byte $18   ; row 77
    !fill 114, $00
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
}

; =============================================================================
; THE 2K DPC DISPLAY IMAGE — real $E000-$E7FF, file offset $2000
; =============================================================================
; The flat file ends with 2,048 bytes of display data.  The DPC's fetchers
; read it backwards through their counters: display[2047 - counter].
; The three main planes sit at offsets 0, 683 and 1366; the padding holds
; the three alternate PF2 twinkle planes at 200, 400 and 880.  The !fill
; arithmetic checks every offset at build time and fails if a plane
; overruns its slot.
    * = $E000
DisplayImage:

; Each !byte line's comment names the range of its eight rows.  The logo
; strokes begin at row 84: the first four bytes of the "rows 80-87" line
; are rows 80-83 and are zero.

; --- plane 0: the PF0 byte (the 4 leftmost playfield bits) for each line ----
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0   ; rows 0-7
    !byte $F0, $F0, $F0, $F0, $B0, $B0, $B0, $B0   ; rows 8-15
    !byte $B0, $B0, $B0, $B0, $30, $30, $30, $30   ; rows 16-23
    !byte $30, $30, $30, $30, $30, $30, $B0, $30   ; rows 24-31
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 32-39
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 40-47
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 48-55
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 56-63
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 64-71
    !byte $30, $30, $B0, $30, $30, $30, $30, $30   ; rows 72-79
    !byte $30, $30, $30, $30, $F0, $F0, $F0, $F0   ; rows 80-87
    !byte $70, $70, $70, $70, $70, $70, $F0, $F0   ; rows 88-95
    !byte $F0, $F0, $30, $30, $30, $30, $30, $30   ; rows 96-103
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 104-111
    !byte $70, $30, $30, $30, $30, $30, $30, $30   ; rows 112-119
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 120-127
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 128-135
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 136-143
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 144-151
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 152-159
    !byte $30, $30, $30, $30, $30, $30, $30, $30   ; rows 160-167
    !byte $30, $30, $30, $30, $B0, $B0, $B0, $B0   ; rows 168-175
    !byte $B0, $B0, $B0, $B0, $F0, $F0, $F0, $F0   ; rows 176-183
    !byte $F0, $F0, $F0, $F0, $F0, $F0, $F0, $F0   ; rows 184-191
    !fill 200 - (* - DisplayImage), $00

; --- PF2 twinkle phase 1 (display offset 200) -------------------------------
    !byte $FF, $FF, $FF, $FF, $30, $30, $30, $30   ; rows 0-7
    !byte $30, $30, $30, $30, $18, $18, $18, $18   ; rows 8-15
    !byte $18, $18, $18, $18, $0C, $0C, $0C, $0C   ; rows 16-23
    !byte $2C, $0C, $0C, $0C, $06, $06, $06, $06   ; rows 24-31
    !byte $06, $06, $06, $06, $03, $03, $03, $03   ; rows 32-39
    !byte $03, $03, $03, $03, $01, $01, $01, $01   ; rows 40-47
    !byte $01, $01, $81, $01, $00, $00, $00, $00   ; rows 48-55
    !byte $00, $00, $00, $00, $00, $00, $08, $00   ; rows 56-63
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 64-71
    !byte $01, $00, $00, $00, $00, $00, $00, $00   ; rows 72-79
    !byte $40, $00, $00, $00, $78, $78, $7D, $7D   ; rows 80-87
    !byte $0D, $0D, $0D, $0D, $0D, $0D, $7C, $7C   ; rows 88-95
    !byte $78, $78, $00, $00, $00, $00, $10, $00   ; rows 96-103
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $04, $00, $00, $00   ; rows 112-119
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 120-127
    !byte $00, $00, $00, $00, $80, $00, $00, $00   ; rows 128-135
    !byte $00, $00, $00, $00, $01, $01, $01, $01   ; rows 136-143
    !byte $01, $01, $01, $01, $23, $03, $03, $03   ; rows 144-151
    !byte $03, $03, $03, $03, $06, $06, $06, $06   ; rows 152-159
    !byte $06, $06, $06, $06, $0C, $0C, $0C, $0C   ; rows 160-167
    !byte $0E, $0C, $0C, $0C, $18, $18, $18, $18   ; rows 168-175
    !byte $18, $18, $18, $18, $30, $30, $30, $30   ; rows 176-183
    !byte $30, $30, $30, $30, $FF, $FF, $FF, $FF   ; rows 184-191
    !fill 400 - (* - DisplayImage), $00

; --- PF2 twinkle phase 2 (display offset 400) -------------------------------
    !byte $FF, $FF, $FF, $FF, $30, $30, $30, $30   ; rows 0-7
    !byte $30, $30, $30, $30, $18, $18, $18, $18   ; rows 8-15
    !byte $18, $18, $18, $18, $0C, $0C, $0C, $0C   ; rows 16-23
    !byte $0C, $0C, $0C, $0C, $06, $06, $06, $06   ; rows 24-31
    !byte $06, $06, $06, $06, $03, $03, $03, $03   ; rows 32-39
    !byte $13, $03, $03, $03, $01, $01, $01, $01   ; rows 40-47
    !byte $01, $01, $01, $01, $00, $00, $01, $00   ; rows 48-55
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 56-63
    !byte $00, $00, $40, $00, $00, $00, $20, $00   ; rows 64-71
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 72-79
    !byte $00, $00, $02, $00, $78, $78, $7D, $7D   ; rows 80-87
    !byte $0D, $0D, $0D, $0D, $0D, $0D, $7C, $7C   ; rows 88-95
    !byte $78, $78, $00, $00, $80, $00, $00, $00   ; rows 96-103
    !byte $00, $00, $00, $00, $00, $00, $08, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 112-119
    !byte $00, $00, $00, $00, $00, $00, $40, $00   ; rows 120-127
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 128-135
    !byte $00, $00, $00, $00, $01, $01, $01, $01   ; rows 136-143
    !byte $01, $01, $01, $01, $03, $03, $03, $03   ; rows 144-151
    !byte $03, $03, $03, $03, $16, $06, $06, $06   ; rows 152-159
    !byte $06, $06, $06, $06, $0C, $0C, $0C, $0C   ; rows 160-167
    !byte $0C, $0C, $0C, $0C, $18, $18, $18, $18   ; rows 168-175
    !byte $18, $18, $18, $18, $30, $30, $30, $30   ; rows 176-183
    !byte $30, $30, $30, $30, $FF, $FF, $FF, $FF   ; rows 184-191
    !fill 683 - (* - DisplayImage), $00

; --- plane 1: the PF1 byte (playfield bits 4-11) for each line --------------
    !byte $FF, $FF, $FF, $FF, $00, $00, $00, $00   ; rows 0-7
    !byte $00, $00, $00, $00, $80, $80, $80, $80   ; rows 8-15
    !byte $80, $80, $80, $80, $C0, $C0, $C0, $C0   ; rows 16-23
    !byte $C0, $C0, $C0, $C0, $60, $60, $60, $60   ; rows 24-31
    !byte $60, $60, $60, $60, $30, $30, $30, $30   ; rows 32-39
    !byte $30, $30, $38, $30, $19, $19, $19, $19   ; rows 40-47
    !byte $19, $19, $19, $19, $0F, $0F, $0F, $0F   ; rows 48-55
    !byte $0F, $0F, $0F, $0F, $06, $06, $06, $06   ; rows 56-63
    !byte $06, $06, $46, $06, $00, $00, $00, $00   ; rows 64-71
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 72-79
    !byte $00, $00, $00, $00, $CF, $CF, $EF, $EF   ; rows 80-87
    !byte $69, $69, $69, $69, $6F, $6F, $EF, $EF   ; rows 88-95
    !byte $C8, $C8, $02, $00, $00, $00, $00, $00   ; rows 96-103
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 112-119
    !byte $00, $00, $00, $00, $86, $06, $06, $06   ; rows 120-127
    !byte $06, $06, $06, $06, $0F, $0F, $0F, $0F   ; rows 128-135
    !byte $1F, $0F, $0F, $0F, $19, $19, $19, $19   ; rows 136-143
    !byte $19, $19, $19, $19, $30, $30, $31, $30   ; rows 144-151
    !byte $30, $30, $30, $30, $60, $60, $60, $60   ; rows 152-159
    !byte $60, $60, $60, $60, $C0, $C0, $C0, $C0   ; rows 160-167
    !byte $C0, $C0, $C0, $C0, $80, $80, $80, $80   ; rows 168-175
    !byte $80, $80, $80, $80, $00, $00, $00, $00   ; rows 176-183
    !byte $00, $00, $00, $00, $FF, $FF, $FF, $FF   ; rows 184-191
    !fill 880 - (* - DisplayImage), $00

; --- PF2 twinkle phase 3 (display offset 880) -------------------------------
    !byte $FF, $FF, $FF, $FF, $30, $30, $30, $30   ; rows 0-7
    !byte $30, $30, $30, $30, $18, $18, $18, $18   ; rows 8-15
    !byte $18, $18, $18, $18, $0C, $0C, $0C, $0C   ; rows 16-23
    !byte $0C, $0C, $0C, $0C, $06, $06, $06, $06   ; rows 24-31
    !byte $86, $06, $06, $06, $03, $03, $03, $03   ; rows 32-39
    !byte $03, $03, $03, $03, $01, $01, $09, $01   ; rows 40-47
    !byte $01, $01, $01, $01, $00, $00, $00, $00   ; rows 48-55
    !byte $00, $00, $02, $00, $00, $00, $00, $00   ; rows 56-63
    !byte $20, $00, $00, $00, $00, $00, $00, $00   ; rows 64-71
    !byte $00, $00, $00, $00, $04, $00, $00, $00   ; rows 72-79
    !byte $01, $00, $00, $00, $78, $78, $7D, $7D   ; rows 80-87
    !byte $0D, $0D, $0D, $0D, $0D, $0D, $7C, $7C   ; rows 88-95
    !byte $78, $78, $00, $00, $00, $00, $00, $00   ; rows 96-103
    !byte $00, $00, $00, $00, $40, $00, $00, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 112-119
    !byte $00, $00, $10, $00, $00, $00, $00, $00   ; rows 120-127
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 128-135
    !byte $00, $00, $02, $00, $01, $01, $01, $01   ; rows 136-143
    !byte $01, $01, $01, $01, $03, $03, $03, $03   ; rows 144-151
    !byte $83, $03, $03, $03, $06, $06, $06, $06   ; rows 152-159
    !byte $06, $06, $06, $06, $0C, $0C, $0C, $0C   ; rows 160-167
    !byte $0C, $0C, $0C, $0C, $18, $18, $18, $18   ; rows 168-175
    !byte $18, $18, $18, $18, $30, $30, $30, $30   ; rows 176-183
    !byte $30, $30, $30, $30, $FF, $FF, $FF, $FF   ; rows 184-191
    !fill 1366 - (* - DisplayImage), $00

; --- plane 2: the PF2 byte, twinkle phase 0, at display offset 1366 ---------
    !byte $FF, $FF, $FF, $FF, $30, $30, $30, $30   ; rows 0-7
    !byte $30, $30, $30, $30, $18, $18, $18, $18   ; rows 8-15
    !byte $18, $18, $18, $18, $1C, $0C, $0C, $0C   ; rows 16-23
    !byte $0C, $0C, $0C, $0C, $06, $06, $46, $06   ; rows 24-31
    !byte $06, $06, $06, $06, $03, $03, $03, $03   ; rows 32-39
    !byte $03, $03, $03, $03, $05, $01, $01, $01   ; rows 40-47
    !byte $01, $01, $01, $01, $00, $00, $00, $00   ; rows 48-55
    !byte $20, $00, $00, $00, $00, $00, $00, $00   ; rows 56-63
    !byte $00, $00, $00, $00, $00, $00, $02, $00   ; rows 64-71
    !byte $00, $00, $00, $00, $00, $00, $80, $00   ; rows 72-79
    !byte $00, $00, $00, $00, $78, $78, $7D, $7D   ; rows 80-87
    !byte $0D, $0D, $0D, $0D, $0D, $0D, $7C, $7C   ; rows 88-95
    !byte $78, $78, $00, $00, $00, $00, $00, $00   ; rows 96-103
    !byte $08, $00, $00, $00, $00, $00, $00, $00   ; rows 104-111
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 112-119
    !byte $01, $00, $00, $00, $00, $00, $00, $00   ; rows 120-127
    !byte $00, $00, $00, $00, $00, $00, $00, $00   ; rows 128-135
    !byte $00, $00, $00, $00, $41, $01, $01, $01   ; rows 136-143
    !byte $01, $01, $01, $01, $03, $03, $03, $03   ; rows 144-151
    !byte $03, $03, $03, $03, $06, $06, $06, $06   ; rows 152-159
    !byte $16, $06, $06, $06, $0C, $0C, $0C, $0C   ; rows 160-167
    !byte $0C, $0C, $0C, $0C, $18, $18, $18, $18   ; rows 168-175
    !byte $1C, $18, $18, $18, $30, $30, $30, $30   ; rows 176-183
    !byte $30, $30, $30, $30, $FF, $FF, $FF, $FF   ; rows 184-191
    !fill 2048 - (* - DisplayImage), $00
```

<!-- END-FULL-SOURCE -->

> The complete, fully-commented source lives in
> `lessons/part8-advanced/60-dpc-plus/60-dpc-plus.asm`.

### Code Walkthrough

#### Step 1 — The two banks and the 2K display image

The file is three segments. Bank 0 is at real `$C000` with `!pseudopc $F000`; bank 1 is at real `$D000` with the same pseudo program counter; the display image is at real `$E000`. The `!fill 128, $EA` at the start of each bank is the register-window shadow. The vectors at `$FFFA-$FFFF` point to `$F080` in both banks.

#### Step 2 — The bank 0 stub and the landing pad

Bank 0's `$F080` is `LDA $1FF9; JMP $F080`. Bank 1's `$F080` is `JMP Init`, and `$F083` is a second `JMP Init` for the fetch that bank 0's stub performs after the switch. The two `JMP Init` bytes are the only reason the stub is safe.

#### Step 3 — Init and the first frame

`+clean_start` zeroes the TIA and RAM and sets the stack. The init sets the colors (`$AE` cyan playfield, `$00` black background, `$0E` white probe), reflects the playfield, and resets the DPC random generator with a write to `$1070`. Then `Main` falls into `StartFrame`.

#### Step 4 — VBLANK: random byte, counters, phase

The frame setup reads `$1000`, stores the byte in `Rng`, writes `$FF`/`$00` to the three tops and bottoms, and writes the three counters. DF0 and DF1 are fixed at 2047 and 1364. DF2 is the twinkle phase, selected from `Rng & 3` through the `PhaseLo`/`PhaseHi` tables. The frame counter increments, player 0 is positioned, and the timer wait ends VBLANK.

#### Step 5 — The visible kernel

The kernel reads `$1008`, `$1009` and `$100A` and stores them in `PF0`, `PF1` and `PF2`. It also draws the probe strip from `Probe,Y` into `GRP0`. The `Fetch0/1/2` labels sit on the stores so the debugger reports the fetched bytes, not the previous ones. The `STA WSYNC` ends each line; `INY`/`CPY #192`/`BNE` run at the top of the next line.

#### Step 6 — The display image and the phase planes

The display image is 2,048 bytes: plane 0 at 0, phase 1 at 200, phase 2 at 400, plane 1 at 683, phase 3 at 880, plane 2 at 1366, and padding to the end. The `!fill` expressions assert each offset. The planes are the left half of the playfield, four colour clocks per bit, reflected by `CTRLPF`.

#### Step 7 — The phase tables and the probe

`PhaseLo`/`PhaseHi` hold the four DF2 counter values. They sit at `$F2F0`/`$F2F4` inside one page, so the indexed loads do not cross a page. `Probe` is a 192-byte strip with an 8×8 diamond at rows 70-77 and is page-aligned at `$F400`.

## What You Should See

At power-on the screen is black with a bright cyan tunnel. The top and bottom edges are four-line solid bands; two 2-bit side walls run down the left and right edges; stepped perspective braces run from the corners toward the middle. In the centre is a bold "DPC" logo (and its mirror on the right, because the playfield is reflected). Cyan dashes of various lengths are scattered through the dark areas: the static stars are always on, and the PF2 stars change as the DPC's random generator advances and selects a different phase. A small white diamond sits at x=40, rows 70-77 — that is player 0, positioned once per frame by the one HMOVE.

![Stella running the Lesson 60 ROM at twinkle phase 0: a black screen with a bright cyan tunnel frame, stepped perspective braces, a bold DPC logo and its mirror, scattered cyan star dashes, and a small white diamond probe at the left of the logo band; the title bar reads Stella 7.0: "60-dpc-plus"](/images/lesson60/dpc-a.png)

*`dpc-a`: twinkle phase 0. The DPC's random generator selected the PF2 plane at display offset 1366 (counter 681). The tunnel and the logo are identical in both captures; only the PF2 star set changes.*

![Stella running the Lesson 60 ROM at twinkle phase 1: the same cyan tunnel, DPC logo and white probe, but the scattered star dashes are in different positions; the title bar reads Stella 7.0: "60-dpc-plus"](/images/lesson60/dpc-b.png)

*`dpc-b`: twinkle phase 1, from the same committed ROM a fraction of a second later. The PF2 plane at offset 200 (counter 1847) is selected, so the star pattern has moved. The tunnel, the logo and the probe are unchanged.*

<RomPlayer rom="/roms/part8-advanced/60-dpc-plus/60-dpc-plus.bin" title="Lesson 60 — DPC and DPC+" />

Javatari includes a DPC cartridge path; its `DPC` format accepts the 10,240-byte image by size (priority 101; its `tryFormat` range is 10,240-10,496 bytes), so the player does not need a filename hint, and the player can run the ROM in the page. Javatari starts muted; this ROM is silent, so there is nothing to unmute. Exercise 3 is the one that adds a music fetcher.

The debugger tells the same story as numbers. The frame is 262 lines; the three fetchers read the three planes in lockstep. The checkpoint table quotes the addresses this source produced:

| Checkpoint | Address | Measured | Meaning |
|---|---|---|---|
| `Reset` | `$F080` | PC = `$F080` | the DPC entry in bank 1 |
| `StartFrame` | `$F0B6` | 259/3 | the first VSYNC instruction |
| `VblankStart` | `$F0C4` | 0/5 | the first VBLANK instruction |
| `BodyStart` | `$F129` | 37/5 | visible line 0 |
| `Fetch0` | `$F12E` | A = the DF0 byte (`$F0` on line 0) | the PF0 fetch |
| `Fetch1` | `$F133` | A = the DF1 byte (`$FF` on line 0) | the PF1 fetch |
| `Fetch2` | `$F138` | A = the DF2 byte (`$FF`/`$0C`/`$1C`) | the PF2 fetch |
| `RngRead` | `$F0D0` | A = `$03`, `$A4`, `$5B`, `$0D`, `$64`… | the random byte |
| `Frame` | `$F115` | A = 1, 2, 3, … | the new frame count |
| `OverscanStart` | `$F146` | 229/6 | the first overscan instruction |

A few useful breakpoints:

```bash
ROM=docs/public/roms/part8-advanced/60-dpc-plus/60-dpc-plus.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0B6' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0C4' $ROM   # VblankStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F129' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F146' $ROM   # OverscanStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F12E' $ROM   # Fetch0
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F133' $ROM   # Fetch1
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F138' $ROM   # Fetch2
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0D0' $ROM   # RngRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F115' $ROM   # Frame
```

At `StartFrame` the log reads frame 1, scanline 259, cycle 3. `VblankStart` is 0/5, `BodyStart` 37/5, `OverscanStart` 229/6. At `Fetch0`, `Fetch1` and `Fetch2` the A register holds `$F0`, `$FF` and `$FF` on the first visible line — the first byte of each plane. At `RngRead` the A register changes from frame to frame in the measured run (`$03`, `$A4`, `$5B`, `$0D`, `$64` in the first five frames). At `Fetch2` on visible row 20 (scanline 57) the byte is `$0C` or `$1C`: the `$10` bit is the phase's star, and it appears only in the phases that place a star there.

In RAM, `$80` is `FrameCount`, `$81` is the selected phase's DF2 counter low (`$A9`, `$37`, `$6F` or `$8F`), `$82` is the phase (`0-3`) and `$83` is the random byte. The DPC's own counters and display image are inside the cartridge; they are not at `$0080`.

> **Capture method.** The two images are window captures of
> `docs/public/roms/part8-advanced/60-dpc-plus/60-dpc-plus.bin`
> in Stella 7.0, launched with a fresh Stella base directory, `-audio.enabled 0`,
> `-uimessages 0` (so the startup OSD is absent), a fixed 3× zoom, and a fixed
> window position. The window is 1010×807 including the title bar. The pointer
> was parked at `(0, 0)` before the captures, so the images contain no cursor.
> A burst of 30 window captures was taken while the ROM ran; the two frames were
> selected by matching the star plane against the four expected phase images.
> `dpc-a` is phase 0 and `dpc-b` is phase 1; both match their expected pictures
> with zero mismatching pixels outside the probe. The title bars read
> `Stella 7.0: "60-dpc-plus"`.

The pixel check measures the picture, not just the colours. The TIA area of the
window is 960×606 pixels at `(25, 106)`. It is downsampled to the logical
160×192 screen and thresholded on the cyan playfield. The result matches the
phase-0 picture exactly (0 mismatches out of 30,656 sampled pixels outside the
probe) and the phase-1 picture exactly in `dpc-b`. That proves the three
planes are vertically aligned: a one-line offset in any plane would move the
left stroke of the logo and show up as a mismatch.

## Exercises

### Exercise 1: A Different Tunnel

**Challenge:** Replace the stepped V braces with a different tunnel. Keep the
10K layout, the three 192-byte planes, the four twinkle phases and the frame.
The solution uses two concentric diamond rings and a blue playfield (`$8E`).

**Hints:**
1. The three main planes must stay at display offsets 0, 683 and 1366; the
   `!fill` checks in the source will tell you if a plane overruns.
2. A diamond ring is a pair of lit bits that move inward as the row approaches
   the centre: `b = 2 + abs(y - 96) / 8`, with a second ring at `b + 5`.
3. Cut the rings open for the logo band (rows 82-99) so the letters stay clear.

**Expected Result:** A blue diamond tunnel with the same bold "DPC" logo, the
same white probe, and a starfield that still twinkles through the four PF2
phases. Stella still reports `DPC* (10K)`.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: An RNG Starfield

**Challenge:** Turn the whole 2K display image into a bank of eight 192-byte
star planes. Every frame, point DF0 at plane `Rng & 7`, DF1 at plane
`(Rng >> 3) & 7`, and DF2 at plane `4 + ((Rng >> 6) & 3)`. The screen becomes a
full-screen starfield that changes as the RNG advances.

**Hints:**
1. The plane counters are `2047 - offset`; with offsets 0, 192, 384, 576, 768,
   960, 1152 and 1344 the counters are `$07FF`, `$073F`, `$067F`, `$05BF`,
   `$04FF`, `$043F`, `$037F` and `$02BF`.
2. Store the eight low bytes and eight high bytes in two tables and index them
   with X.
3. Keep the three fetchers' counters in lockstep: reset all three tops and
   bottoms, then write the three counter pairs.

**Expected Result:** A full-screen cyan starfield with a small white ship. The
star pattern changes when the RNG selects a different combination, and the three fetchers still read
their planes in lockstep.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: DPC Music

**Challenge:** Add one DPC music fetcher to the lesson program. Use DF5 with
top 63, bottom 31, counter low 63 and counter high `$10` (bit 4 enables music
mode). Read the amplitude at `$1005` once per scanline and write it to
`AUDV0`; set `AUDC0 = 0` and `AUDF0 = 0`.

**Hints:**
1. The music registers are `$1045` (top), `$104D` (bottom), `$1055` (counter
   low) and `$105D` (counter high + music mode). They are *not* the same
   addresses as DF0's.
2. The amplitude read is `$1005`; in Stella one channel returns 0 or 4.
3. Put the amplitude read after the probe's `STA GRP0`; if you put it before,
   the extra seven cycles push the probe write past x=40.

**Expected Result:** A steady tone of about 312 Hz at volume 4. In Stella the
`MusicRead` breakpoint shows 04 for 25 scanlines, then 00 for 25, then 04
again. (Javatari's mixer may show 05 instead of 04; the pitch and the 25-line
high/25-line low pattern are the same.) The picture is unchanged.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ The DPC is a mapper **plus a coprocessor**: 8K of program, 2K of display ROM, eight data fetchers, an 8-bit random generator and three music channels.
- ✅ A DPC image is **10,240 bytes**: bank 0 + bank 1 + the 2K display image. It starts in bank 1, and every bank's code starts at `$F080` because `$F000-$F07F` mirrors the register window.
- ✅ The register decode is `index = address & 7`, `function = (address >> 3) & 7`. DF1's bottom is `$1049`, DF2's counter high is `$105A`; never read the table as a straight run of eight.
- ✅ A fetcher returns `display[2047 - counter]` and then decrements the counter. The three playfield counters must be reset together, and the random read must happen **before** the reset because it clocks DF0.
- ✅ The 38-cycle line is three fetches, three PF stores and one probe store; each store must land before the beam reaches its register's region. The probe is the tightest write.
- ✅ On the real chip the DPC random generator is an 8-bit LFSR clocked by every cartridge access; Stella's model clocks it only on DPC-window and hotspot accesses. The lesson uses its low two bits to choose one of four PF2 star phases.
- ✅ DPC+ is the Harmony/Melody ARM scheme: a 32K image (3K ARM driver + 29K of program/display/frequency data), 8K of cartridge RAM and a 32-bit LFSR. A plain cartridge cannot run it; this lesson builds a real DPC image.

## What's Next

Lesson 61 takes the opposite approach to graphics data. Instead of a mapper
that stores a picture for you, you will compress a detailed playfield into a
fraction of its raw size and decompress it on the fly into a three-byte row
buffer. The DPC's 2K display image is a luxury; Lesson 61 shows how far you can
get when you have only 4K and a decoder.
[Lesson 61: Compression & Data Encoding — Fitting More in 4KB](/part8-advanced/61-compression)
