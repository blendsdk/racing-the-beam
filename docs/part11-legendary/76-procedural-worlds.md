---
title: "Lesson 76: Procedural Worlds from a Seed — Pitfall! & River Raid"
description: "Generate a scrolling 16-row world from one byte: an 8-bit Galois LFSR with taps $B8 steps once per terrain row, a four-entry map chooses jungle, river, wall or open, a 96-byte pattern table turns the state into three playfield bytes, and a 64-byte ring shifts one row every eight frames while the seed is displayed as bars in the status band."
prev:
  text: "Lesson 75: Pseudo-3D Road — The Enduro / Pole Position Effect"
  link: "/part11-legendary/75-pseudo-3d-road"
next:
  text: "Lesson 77: Interlaced Flicker — Faking More Colours & Resolution"
  link: "/part11-legendary/77-interlaced-flicker"
---

# Lesson 76: Procedural Worlds from a Seed — Pitfall! & River Raid

> **Part 11: Legendary Techniques** · Estimated time: 120 minutes
> **Prerequisites:** Lesson 12 (the NTSC frame), Lesson 14 (WSYNC and scanline timing), Lesson 15 (the RIOT timer), Lesson 19 (playfield basics), Lesson 20 (playfield colours), Lesson 21 (the asymmetric playfield), Lesson 23 (the data-driven playfield), Lesson 26 (positioning objects), Lesson 43 (random numbers and the 8-bit LFSR), Lesson 49 (the 2-line kernel), Lesson 52 (fine scrolling), Lesson 61 (compression and the idea of a generator)
> **You will learn:** how one byte and one shift-and-XOR step can describe 255 terrain rows — 1,020 bytes if stored as four-byte rows, a quarter of the 4K cartridge; why the Galois LFSR with taps `$B8` visits all 255 nonzero states and why zero is a trap; how to turn the low bits of the state into a terrain type and a pattern variant; how a 16-row, 64-byte ring in the 2600's 128 bytes of RAM becomes a scrolling window; how the ring shifts and a new bottom row is generated every eight frames; how to run the LFSR backwards with three instructions so the world behind the player can be rebuilt; and how the row kernel writes the playfield once per ten-line row and still meets every TIA deadline.
> **You will build:** "the world" — a 4,096-byte ROM with a 32-line status band showing the 8-bit seed as bars, sixteen terrain rows of ten scanlines each in four types (jungle, river, wall, open), a white player sprite that moves left and right, and an auto-demo that changes the seed at frames 240 and 480 so the 2-second and 5-second captures show two different worlds. Plus two complete exercise solutions: a wetter world with a new palette, and the reverse LFSR step that rebuilds the previous sixteen rows.

## Introduction

Lessons 9 and 11 gave you the two tools this lesson is built from: a byte is eight independent bits, and a table is a way to turn a small number into a large answer. Lesson 43 used those tools to make a random sequence; Lesson 23 used them to store a playfield; Lesson 52 used them to scroll a world. This lesson puts all three together and asks the question that *Pitfall!* and *River Raid* answered on the same hardware: **how large a world can you get out of a few bytes?**

The answer is not "store more data." The answer is "store a generator." An eight-bit linear-feedback shift register (LFSR) has 255 nonzero states. Step it once per terrain row and you have a 255-row world from one seed byte. The cartridge never stores the rows: it stores the step, the seed, and a small table of patterns. The same seed always rebuilds the same world, and a reverse step can rebuild the rows that have already passed — which is why the world can feel endless without ever growing in RAM.

The companion program `76-procedural-worlds.asm` makes the idea visible. The top of the screen is a status band with the seed drawn as eight bars. Below it, a 16-row window of terrain scrolls upward: green jungle checkers, blue river bands, grey walls and black open ground. A white player sprite moves along the bottom of the window. Every eight frames the whole window shifts up one row and the generator steps once to fill the new bottom row. At frame 240 the seed changes from `$FA` to `$D0`, so the 2-second capture and the 5-second capture show visibly different worlds. At frame 480 it changes back to `$FA`, and the world is byte-for-byte the power-on world again — the replay is the proof of determinism.

::: details TypeScript Equivalent

The generator and the ring are ordinary code in TypeScript. The block below is the exact algorithm; the notes after it say where the 2600's version differs.

```typescript
/** The 8-bit Galois LFSR: shift right, XOR $B8 when the bit that fell out was 1. */
class Lfsr8 {
  private state: number;
  constructor(seed: number) {
    this.state = seed & 0xff;
    if (this.state === 0) this.state = 1;       // zero is the fixed point
  }
  /** One forward step; returns the new state. */
  next(): number {
    const lsb = this.state & 1;
    this.state >>= 1;
    if (lsb) this.state ^= 0xb8;
    return this.state;
  }
  /** The exact inverse: bit 7 of the new state is the old bit 0. */
  prev(): number {
    const oldBit0 = this.state >> 7;
    this.state = (this.state << 1) & 0xff;
    if (oldBit0) this.state ^= 0x70;            // ($B8 << 1) & $FF
    this.state |= oldBit0;
    return this.state;
  }
}

/** One terrain row: a type and the three playfield bytes (20 chunks). */
type Terrain = { type: 0 | 1 | 2 | 3; pf: [number, number, number] };
const TYPE_MAP = [0, 1, 2, 3];                  // slot -> type
const TYPES = ['open', 'jungle', 'river', 'wall'] as const;
const PATTERN: number[][][] = [/* 4 types x 8 variants x 3 bytes */];

function rowFromState(state: number): Terrain {
  const type = TYPE_MAP[state & 0x03];          // low two bits
  const variant = (state >> 2) & 0x07;          // bits 2-4
  return { type: type as 0 | 1 | 2 | 3, pf: PATTERN[type][variant] as [number, number, number] };
}

/** The 2600's ring: sixteen rows in RAM, shifted up one row at a time. */
class WorldRing {
  private lfsr: Lfsr8;
  readonly rows: Terrain[];
  constructor(seed: number) {
    this.lfsr = new Lfsr8(seed);
    this.rows = Array.from({ length: 16 }, () => rowFromState(this.lfsr.next()));
  }
  /** Scroll the window up: row 1 -> row 0, ..., a new bottom row. */
  scroll(): void {
    this.rows.shift();
    this.rows.push(rowFromState(this.lfsr.next()));
  }
}

const ring = new WorldRing(0xfa);
setInterval(() => ring.scroll(), 8000 / 60);    // one row every 8 frames at 60 Hz
```

The analogy breaks in four places. There is no `Array` of `Terrain` objects: the ring is four parallel 16-byte arrays, because a row is a colour byte and three playfield bytes, not an object with a pointer. There is no modulo arithmetic in the generator: the shift and the conditional XOR are the whole step, and `$B8` is chosen so the byte never leaves the 255 nonzero states. The `setInterval` is not a timer: the scroll counter is incremented once per frame in the vertical blank, and the actual picture is redrawn from scratch on every scanline — the ring is only the data, not the screen. And the real world is drawn through three 8-bit playfield registers in twenty 4-pixel chunks, so a "row" is a pattern of chunks, not an array of pixels.

:::

## Theory

### The window and the world

The screen shows sixteen terrain rows. Each row is ten scanlines tall and 160 pixels wide, so the world window is 16 x 10 = 160 visible lines. Above it, a 32-line status band shows the seed. The frame is the course's NTSC skeleton:

| Band | Lines | What draws it |
|---|---:|---|
| VSYNC | 3 | `+vsync` |
| VBLANK | 37 | the timer, the demo and the generator |
| Status band | 32 | the seed as eight playfield bars |
| World | 160 | sixteen rows x ten lines |
| Overscan | 30 | the timer |
| **Total** | **262** | |

The world window holds sixteen rows, not one row: the picture is a window that slides through a much longer sequence. The sequence is produced by the LFSR, one step per generated row. The cartridge stores no row data at all beyond the window; the window is a ring in RAM.

The distinction matters because the 2600 has 128 bytes of RAM. Sixteen rows of playfield data are 16 x 3 = 48 bytes; the colour byte per row makes 64 bytes, which is half of RAM. A 255-row world stored as raw playfield bytes would be 255 x 4 = 1,020 bytes — a quarter of the 4K cartridge for one world, before any code or graphics. The generator replaces those thousand bytes with an eight-bit state and a 96-byte pattern table.

> **The famous games.** *Pitfall!* (Activision, David Crane) and *River Raid* (Activision, Carol Shaw) are the course's reference points for this idea: both build long, varied worlds on a cartridge far too small to store them screen by screen. This lesson reconstructs the mechanism from the descriptions in *Racing the Beam* and the AtariAge/8bitworkshop material, and verifies the sequence, the ring and the frame in this ROM. The terrain table, the palette and the seed values are original; no claim is made that either game used this exact table or these exact taps.

### The LFSR: one byte, 255 states

A shift register holds bits and moves them one place per step. A **linear-feedback shift register** adds feedback: one or more of the bits that fall off the end are XORed back into the register. In the Galois form the feedback is applied to the shifted byte itself, so a step is a shift plus one conditional XOR.

This lesson's generator is eight bits wide and shifts **right**:

```asm
    LDA LFSRState
    LSR             ; bit 0 -> carry
    BCC .noTap      ; no feedback when the bit was 0
    EOR #$B8        ; taps at bits 7, 5, 4 and 3 of the shifted byte
.noTap:
    STA LFSRState
```

`$B8` is `%10111000`. The shift moves every bit one place toward bit 0 and puts 0 into bit 7; the XOR then flips bits 7, 5, 4 and 3 when the old bit 0 was 1. Those four positions are the **taps**. The polynomial is chosen so the register visits every nonzero byte before it repeats: 255 states. Zero is the one fixed point — `0 >> 1` is 0 and the carry is clear, so a zero seed stays zero forever. Every seed path in this ROM replaces zero with one, and the reverse step never produces zero from a nonzero state.

Here are the first twenty states from the two seeds the demo uses:

| Step | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Seed `$FA` | `7D` | `86` | `43` | `99` | `F4` | `7A` | `3D` | `A6` | `53` | `91` | `F0` | `78` | `3C` | `1E` | `0F` | `BF` | `E7` | `CB` | `DD` | `D6` |
| Seed `$D0` | `68` | `34` | `1A` | `0D` | `BE` | `5F` | `97` | `F3` | `C1` | `D8` | `6C` | `36` | `1B` | `B5` | `E2` | `71` | `80` | `40` | `20` | `10` |

The sequence is a **cycle**, not an infinite stream: after 255 steps the register returns to the seed. A maximal 8-bit LFSR therefore gives the largest possible sequence for one byte of state. Different seeds do not produce different sequences; they produce different **starting points** on the same 255-state cycle. That is why seed `$D0`'s world is not a new world in the "different data" sense — it is the same cycle, read from a different phase. The captures show two different-looking worlds because the phase, not the cycle, changed.

#### The reverse step

The forward step is a bijection on the 255 nonzero states, so it has an exact inverse. Because `$B8` has bit 7 set, the old bit 0 is the only thing that can set bit 7 of the new state — the shift leaves bit 7 at 0, and only the feedback can put a 1 there. So bit 7 of the current state **is** the previous state's bit 0. Read it, undo the feedback, shift the other way:

```asm
RevStep:
    LDA LFSRState
    ASL             ; carry = old bit 0; A = state << 1
    BCC .low0       ; old bit 0 = 0: no inverse tap
    EOR #$70        ; ($B8 << 1) & $FF, the taps shifted left
    ADC #0          ; carry is still set: add the old bit 0 back
.low0:
    STA LFSRState
    RTS
```

`$70` is `$B8 << 1` with the top bit dropped. If the old bit 0 was 1, the shifted word has a 1 in bit 0, and `ADC #0` adds that 1 back because the carry from `ASL` is still set. `ASL` and `EOR` do not change the carry, so the `ADC` is a branch-free way to put the bit back. The exercise solution runs this step thirty-one times to rebuild sixteen rows, and the host model checks that the forward and reverse steps are inverses on all 255 nonzero states.

::: tip Why a different LFSR from Lesson 43

Lesson 43 used a left-shifting 8-bit LFSR with taps `$1D` (`ASL` then a conditional `EOR #$1D`). This lesson uses the mirror-image right-shifting form with taps `$B8`. Both are maximal; the right-shifting form is chosen because its inverse is the clean `ASL`/`EOR #$70`/`ADC #0` sequence above, and because the "one step per row" loop reads naturally from bit 0 upward.

:::

### From a state to a terrain row

The LFSR gives an eight-bit state. The row encoder splits it:

```
state bits 0-1   -> a slot in the four-entry TypeMap   -> the terrain type
state bits 2-4   -> one of eight pattern variants
state bits 5-7   -> not used by the row encoder (they still affect the next state)
```

The main ROM's `TypeMap` is the identity: slot 0 is open, 1 jungle, 2 river, 3 wall. A different map is a density control — Exercise 1 uses `{2,2,1,3}` to make half the rows river. The type chooses a colour and a block of eight patterns:

| Type | Colour | Pattern family |
|---|---|---|
| `open` | black (`$00`) | empty; all eight variants are zero |
| `jungle` | green (`$C6`) | checkers, stripes, solid growth, sparse pillars |
| `river` | blue (`$96`) | a water band centred in the 20-chunk field; REFLECT mirrors it into two matching bands, eight widths (20, 16, 12, 10, 8, 6, 4, 2 chunks) |
| `wall` | grey (`$0A`) | block walls, pairs, solid segments, sparse pillars |

The pattern table is 4 x 8 x 3 = 96 bytes. Each entry is three playfield bytes — `PF0`, `PF1`, `PF2` — holding the twenty chunks of the row's **left half**. The chunk-to-bit mapping is the one from Lesson 19:

| Register | Chunks | Bits |
|---|---|---|
| `PF0` | 0-3 | bits 4-7 (chunk 0 = bit 4) |
| `PF1` | 4-11 | bits 7-0 (chunk 4 = bit 7) |
| `PF2` | 12-19 | bits 0-7 (chunk 12 = bit 0) |

`CTRLPF`'s `REF` bit is set, so the right half of the screen is the mirror of the left. The world data is still twenty chunks; the mirror gives the full forty-chunk line for free. The row's colour is a separate byte, `TypeColor[type]`, stored in `RowColor` so the kernel does not have to look up the type every line.

For example, state `$53` is type 3 (wall) and variant 4: chunks 1, 2, 3, 7, 8, 9, 13, 14, 15 and 19 are lit, which is `PF0 = $E0`, `PF1 = $1C`, `PF2 = $8E`. State `$1E` is type 2 (river) and variant 7: chunks 9 and 10 are lit, `00 06 00`, a two-chunk stream. State `$7D` is type 1 (jungle) and variant 7: `70 73 39`, a diagonal weave.

### The ring: a world that scrolls

Sixteen rows live in RAM in four parallel arrays:

```
RowColor[16]   the colour byte for each row
RowPF0[16]     the left chunks 0-3 for each row
RowPF1[16]     the left chunks 4-11
RowPF2[16]     the left chunks 12-19
```

That is 16 x 4 = 64 bytes. The screen always shows rows 0 to 15, top to bottom. Every eighth frame the scroll step runs:

1. `ShiftRing` copies row 1 to row 0, row 2 to row 1, ..., row 15 to row 14. The old row 0 falls off the top of the window.
2. `StepLFSR` advances the generator one state.
3. `EncodeRow` turns the new state into row 15 — the new bottom row.

The world therefore moves **up**: a row appears at the bottom and travels toward the top over fifteen scroll steps, then disappears. The screen is a window into the sequence, and the sequence is the LFSR.

The window at N scroll steps holds states N+1 through N+16 (where state 1 is the first step from the seed). The initial 16 rows are states 1-16. After one shift the window is states 2-17; after sixteen shifts it is states 17-32. The ring never stores the whole 255-row sequence; it only stores the current window. The rest of the world exists as the generator's future (or past).

This is the determinism claim, and it is testable: load the same seed, step sixteen times, and the same sixteen states — and therefore the same 64 ring bytes — come out. The demo tests it the visible way. At frame 240 the seed changes to `$D0`; at frame 480 it changes back to `$FA` and `BuildWorld` re-runs from the beginning. The frame-480 ring is byte-for-byte the frame-1 ring. The state log in the checkpoints section is that comparison.

::: tip A ring is cheaper than a shift on real hardware — but this ROM shifts

A production game might keep a "top row" index and wrap the arrays instead of copying them; the lesson keeps the copy because it makes the "row 1 becomes row 0" motion literal and easy to inspect in RAM. Sixty byte moves (fifteen rows x four arrays) every eight frames is about 600 cycles, roughly 22% of the 2,753-cycle vertical blank.

:::

### The kernel: 32 + 160 lines

The status band is 32 lines of playfield bars. `BuildStatus` turns the seed into three playfield bytes by looking at the seed's bits from bit 7 down to bit 0. Block i sits at chunk 2 + 2i, one chunk on and one chunk off, so the eight bars span chunks 2-16 of the left half. The right half mirrors them. The 32 lines just hold the three bytes:

```asm
    LDA #C_STATUS
    STA COLUPF
    LDA StatusPF0
    STA PF0
    LDA StatusPF1
    STA PF1
    LDA StatusPF2
    STA PF2
    LDX #STATUS_LINES
StatusLoop:
    STA WSYNC
    DEX
    BNE StatusLoop
```

The `STA WSYNC` in the loop is the whole line budget: the TIA re-reads the playfield registers on every scanline, and the status bytes do not change, so the loop is just "hold this picture for 32 lines". `X` is zero when the loop ends, which is exactly the first world row's index.

The world is a row loop, not a line loop. Each row's header writes four registers, and the row's ten lines then need only `WSYNC`:

```asm
RowHeader:
    LDA RowColor,X          ; the row's terrain colour
    STA COLUPF
    LDA RowPF0,X
    STA PF0
    LDA RowPF1,X
    STA PF1
    LDA RowPF2,X
    STA PF2
    CPX #PLAYER_ROW
    BEQ PlayerRow
    LDY #(ROW_LINES - 1)
RowLines:
    STA WSYNC
    DEY
    BNE RowLines
    INX
    CPX #WORLD_ROWS
    BEQ WorldEnd
    STA WSYNC
    JMP RowHeader
```

The header's four loads and four stores are 28 cycles; the `CPX`/`BEQ` after them adds four more. It must finish before the beam reaches the left chunks. Using the Lesson 75 timing rule — the visible area starts 68 color clocks, 22.67 CPU cycles, after the `WSYNC` release — the deadlines are:

| Register | Pixels | Must be written before | Completes at (normal row) | Margin |
|---|---|---:|---:|---:|
| `COLUPF` | 0-159 | 22.67 | 10 | 12.67 |
| `PF0` | 0-15 | 22.67 | 17 | 5.67 |
| `PF1` | 16-47 | 28.00 | 24 | 4.00 |
| `PF2` | 48-79 | 38.67 | 31 | 7.67 |

The tightest is `PF1`, four cycles. That margin is why the loop is rotated: the **last line of each row does the `INX`/`CPX` bookkeeping before its `WSYNC`**, so the next row's header starts at cycle 3 (after the 3-cycle `JMP`) rather than cycle 10. If the bookkeeping ran after the `WSYNC`, `PF0` and `PF1` would be written after their deadlines and every row boundary would show a one-line seam.

The player's row is a special case. It draws eight sprite rows and leaves the first and last lines of the row blank. The first line's `GRP0` write lands at cycle 44, after the header, too late for a sprite at X=40; keeping the first line blank hides that write. On each later line the `INY`/`CPY`/`BNE` take 7 cycles, the `LDA` starts at cycle 7 and the `GRP0` write lands at cycle 13 (12 on the last real line), long before the beam reaches X=40. The player's vertical position is row 14; the sprite occupies visible lines 173-180.

The player's horizontal position is re-strobed every frame in VBLANK with the Lesson 26 divide-by-15 routine:

```asm
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetHorizPosP0
```

`RESP0` sets the coarse position where the beam is, `HMP0` carries the remainder, and the routine's final `HMOVE` applies it inside HBLANK. Re-strobing every frame is deliberate: the position cannot drift, and the ROM does not have to track whether X changed.

### The demo: seeds on a timer

Three things happen in VBLANK besides the world generation:

- **SELECT** (SWCHB bit 1, active low) increments the seed by one, skips zero, rebuilds the world and the status bars, and sets `AutoDemo` to 0. Once the player has touched SELECT, the auto-demo stops changing the seed.
- **The auto-demo's seed timer** counts frames. Every 240 frames it toggles between `$FA` and `$D0`, rebuilds the ring and resets the scroll timer. The 2-second capture (game frames 64-71) is seed `$FA`; the 5-second capture (game frames 256-263) is seed `$D0`; the frame-480 change (the second after power-on) rebuilds `$FA`.
- **The player** moves one pixel every two frames between X=40 and X=120, bouncing at each end. The joystick's left/right bits (SWCHA bits 6 and 7, active low) take over whenever either is pressed; the auto-demo resumes when both are released.

The player is a white 8x8 sprite drawn by `GRP0`. It sits in front of the playfield (`CTRLPF`'s priority bit is clear), so it is visible over every terrain colour.

### The frame ledger

The frame is the NTSC skeleton: 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262 lines. The visible 192 split into 32 status lines and 160 world lines. The measured schedule, with the convention that a checkpoint's line/cycle is the instruction's start line and start cycle and cycle 0 is the first instruction after the `WSYNC` release:

| Checkpoint | Line/cycle | What it is |
|---|---|---|
| `StartFrame` | 259/3 | the first VSYNC line |
| `VblankStart` | 0/5 | the first VBLANK line |
| `BodyStart` | 37/5 | visible line 0 |
| `RowHeader` (first) | 69/4 | the first world row's header (visible line 32) |
| `PlayerRow` | 209/36 | the player row's first line (visible line 172) |
| `OverscanStart` | 229/0 | the first blanked line; the `STA VBLANK` completes at 229/4 |

The visible body is 229 - 37 = 192 lines, and 3 + 37 + 192 + 30 = 262. The state log below was produced by a cycle-accurate model of this exact binary (6502, RIOT timer and `WSYNC` line stalls); Stella's instruction trace independently shows steady-state frames with scanlines 1-262, and the captures show a stable picture with no roll. The seed-change frames and the scroll frames all keep `BodyStart` on 37 in the model.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson76.bin \
  lessons/part11-legendary/76-procedural-worlds/76-procedural-worlds.asm
stella build/lesson76.bin
```

The two exercise solutions sit beside the lesson source and are complete 4,096-byte ROMs:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part11-legendary/76-procedural-worlds/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part11-legendary/76-procedural-worlds/exercise-02-solution.asm
```

### Full Source

The complete annotated source, reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 76: Procedural Worlds from a Seed — Pitfall! & River Raid
; =============================================================================
; Part 11: Legendary Techniques
;
; What this program does:
;   "the world": a top-down terrain map that scrolls upward through a fixed
;   16-row window.  The picture is 192 scanlines in two bands:
;
;     visible   0- 31    the status band   32 lines   the 8-bit seed, as bars
;     visible  32-191    the world        160 lines   16 terrain rows x 10 lines
;                       ----------------
;                       32 + 160 = 192
;
;   Each terrain row is 10 scanlines tall and 160 pixels wide.  A row is a
;   20-chunk playfield pattern (three bytes: PF0 = chunks 0-3, PF1 = chunks
;   4-11, PF2 = chunks 12-19) plus ONE colour.  The playfield is in REFLECT
;   mode, so the right half of the screen is the mirror of the left half;
;   the world data is still 20 chunks, and the mirror is free.
;
;   There are four terrain types:
;
;     open     black   empty: no playfield chunks at all
;     jungle   green   checkers, stripes and blocks
;     river    blue    a water band centred in the 20-chunk field;
;                       REFLECT mirrors it into two matching bands
;     wall     grey    block walls, eight arrangements
;
;   The type and the pattern both come from one byte: an 8-bit Galois LFSR.
;   The low two bits choose the TYPE through a four-entry map; bits 2-4
;   choose one of eight PATTERNS for that type.  One LFSR step generates
;   one terrain row.  The row is encoded into four parallel 16-byte arrays:
;   RowColor, RowPF0, RowPF1 and RowPF2.
;
;   THE WORLD IS A RING.  Sixteen rows live in RAM (16 x 4 bytes = 64
;   bytes).  The screen always shows rows 0..15, top to bottom.  Every
;   eighth frame the ring shifts one row toward the top of the screen:
;   row 1 -> row 0, row 2 -> row 1, ..., row 15 -> row 14, and the LFSR
;   steps once to fill the new bottom row 15.  The old row 0 falls off the
;   top of the window.  The world therefore scrolls UP: terrain appears at
;   the bottom and moves toward the player.
;
;   THE SAME SEED ALWAYS BUILDS THE SAME WORLD.  The seed is one byte.  The
;   LFSR starts at the seed and the first step produces the first row.  A
;   maximal 8-bit LFSR visits 255 nonzero bytes before it repeats, so one
;   seed describes 255 terrain rows.  Stored as raw playfield data they
;   would need 1,020 bytes — a quarter of the 4K cartridge — before any
;   code or graphics; the generator needs one byte of state and a 96-byte
;   pattern table.
;
;   The auto-demo changes the seed at frames 240, 480, 720, ... so the two
;   captures (2 s and 5 s) show two different worlds; the second change
;   (frame 480, seed A again) proves the replay: the world at 8 s is the
;   world at 0 s.
;
;   THE LFSR (Galois, right-shifting, taps $B8):
;
;       LDA LFSRState
;       LSR             ; bit 0 -> carry
;       BCC .noTap      ; no feedback when the bit was 0
;       EOR #$B8        ; taps at bits 3, 4, 5 and 7 of the shifted byte
;   .noTap:
;       STA LFSRState
;
;   $B8 = %10111000.  The XOR is the feedback polynomial; the shift is the
;   register.  Starting from any nonzero byte, this step visits all 255
;   nonzero bytes and then returns to the start.  Zero is the one fixed
;   point: 0 shifts to 0 and the carry is clear, so a zero seed freezes the
;   generator.  Every seed path in this ROM replaces zero with one.
;
;   The reverse step exists too, and the stretch exercise uses it.  Because
;   $B8 has bit 7 set, the old bit 0 is the only thing that can set bit 7
;   of the new state: bit 7 of the new state IS the old bit 0.  Read it,
;   undo the XOR, shift the other way:
;
;       LDA LFSRState
;       ASL             ; carry = old bit 0; A = state << 1
;       BCC .low0       ; old bit 0 = 0: no inverse tap
;       EOR #$70        ; the taps shifted left: ($B8 << 1) & $FF
;       ADC #0          ; carry is still set: put the old bit 0 back
;   .low0:
;       STA LFSRState
;
;   The forward and reverse steps are exact inverses on all 255 nonzero
;   states; the host model in the lesson text checks every one of them.
;
;   THE FRAME (NTSC): 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan = 262.
;   Measured schedule (cycle-accurate model + Stella instruction trace): the
;   status band runs on absolute lines 37-68, the world on 69-228, the
;   overscan on 229-258 and the VSYNC on 259-261.  StartFrame is 259/3,
;   VblankStart 0/5, BodyStart 37/5, and the STA VBLANK at OverscanStart
;   completes at 229/4.
;
;   Measurement convention: a checkpoint's line/cycle is the instruction's
;   start line and start cycle, with the line's cycle 0 being the first
;   instruction after the WSYNC release.  A breakpoint on the first
;   instruction after a STA WSYNC fires during the stall and reports the
;   WSYNC's own line/cycle; the instruction itself starts on the next line
;   at cycle 0.
;
;   THE KERNEL IS A ROW LOOP, NOT A LINE LOOP.  Each row is written once
;   and then held for 10 scanlines; the TIA re-reads PF0/PF1/PF2 on every
;   line, so the pattern stays until the next row's header rewrites it.
;   The header writes four registers and must finish before the beam
;   reaches the left chunks:
;
;     COLUPF  pixels   0-159  cycle 10 (or 7)     background colour
;     PF0     pixels   0- 15  before cycle 22.67
;     PF1     pixels  16- 47  before cycle 28.00
;     PF2     pixels  48- 79  before cycle 38.67
;
;   The header is 28 cycles, plus the loop's 3-cycle JMP: on a normal row
;   the PF0 write completes at cycle 17, PF1 at 24 and PF2 at 31.  The
;   tightest is PF1, four cycles before its deadline; the first row of the
;   frame starts one cycle later (18/25/32) because it follows the status
;   loop's DEX/BNE instead of the 3-cycle JMP.  For that to be true the
;   row's last line does its bookkeeping (INX/CPX) BEFORE the WSYNC that
;   ends the row: the next header then starts at cycle 3, not cycle 10.
;
;   The player is P0, a white 8x8 sprite on row 14 of the world (the
;   second row from the bottom).  It is drawn on eight of that row's ten
;   lines; the first and last lines of the row are blank.  Its horizontal
;   position is re-strobed once per frame in VBLANK with the Lesson 26
;   divide-by-15 routine, so the position cannot drift.  The auto-demo
;   moves it one pixel every two frames between X=40 and X=120, with a
;   bounce at each end; the joystick's left/right bits (SWCHA bits 6/7,
;   active low) take over whenever either is pressed.
;
;   SELECT cycles the seed by one (skipping zero) and rebuilds the ring.
;   Pressing SELECT also stops the auto-demo's seed changes, so the player
;   can explore the seed space; the eight bars in the status band show the
;   current seed.
;
; RAM map (the exact map; +clean_start zeroes every byte):
;   $80 LFSRState    the current generator byte (never zero)
;   $81 Seed         the seed shown in the status band and rebuilt on change
;   $82 ScrollTimer  frames to the next ring shift (0..7)
;   $83 FrameLo      frame counter, used for the auto-demo's 2-frame parity
;   $84 DemoTimer    frames since the last seed change (0..239)
;   $85 AutoDemo     1 until SELECT is pressed; then 0
;   $86 PlayerX      the player's left edge (40..120)
;   $87 PlayerDir    0 = left, 1 = right
;   $88 PrevSelect   SELECT edge latch: 0 = released, 1 = pressed
;   $89 TempBase     scratch: type * 24 in the row encoder
;   $8A TempVar      scratch: variant * 3 in the row encoder
;   $8B TempType     scratch: the mapped terrain type
;   $8C TempSeed     scratch: the shifting copy of the seed
;   $8D StatusPF0    the status band's PF0 byte (seed bars)
;   $8E StatusPF1    the status band's PF1 byte
;   $8F StatusPF2    the status band's PF2 byte
;   $90-$9F RowColor 16 bytes, one colour per ring row
;   $A0-$AF RowPF0   16 bytes, chunks 0-3 per row
;   $B0-$BF RowPF1   16 bytes, chunks 4-11 per row
;   $C0-$CF RowPF2   16 bytes, chunks 12-19 per row
;   $D0-$F7          free (40 bytes)
;   $F8-$FF          the stack
;
; Build: acme -f plain -o build/lesson76.bin \
;        lessons/part11-legendary/76-procedural-worlds/76-procedural-worlds.asm
; Run:   stella build/lesson76.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK (Lesson 15)
OVERSCAN_TIMER = 36      ; 30-line overscan (Lesson 15)

VISIBLE_LINES  = 192
STATUS_LINES   = 32      ; visible 0-31: the seed readout
WORLD_ROWS     = 16      ; 16 terrain rows in the ring
ROW_LINES      = 10      ; each row is 10 scanlines tall
WORLD_LINES    = WORLD_ROWS * ROW_LINES   ; 160
PLAYER_ROW     = 14      ; the player's row: the second from the bottom

PLAYER_MIN     = 40      ; the sprite never touches the status band's columns
PLAYER_MAX     = 120     ; 120 + 8 = 128, well inside the 160-pixel screen

POS_BIAS       = 3       ; the Lesson 26 output-delay bias

SEED_A         = $FA     ; the power-on seed
SEED_B         = $D0     ; the seed the auto-demo changes to at frame 240
DEMO_PERIOD    = 240     ; 4 s at 60 Hz: seed A for the 2 s capture, B for 5 s

; --- colours -----------------------------------------------------------------
C_STATUS       = $0E     ; the seed bars: white
C_OPEN         = $00     ; open terrain: black (the pattern is empty too)
C_JUNGLE       = $C6     ; jungle: green
C_RIVER        = $96     ; river: blue
C_WALL         = $0A     ; wall: grey
C_PLAYER       = $0E     ; the player sprite: white

; The band arithmetic is a build-time assertion, not a comment.
!if STATUS_LINES + WORLD_LINES != VISIBLE_LINES {
    !error "the status band and the world must total 192 visible lines"
}

; =============================================================================
; RAM ALLOCATION ($80-$CF; +clean_start zeroes every byte)
; =============================================================================
LFSRState    = $80   ; the current generator byte, never zero
Seed         = $81   ; the seed the status band displays
ScrollTimer  = $82   ; frames to the next ring shift
FrameLo      = $83   ; frame parity for the auto-demo's movement
DemoTimer    = $84   ; frames since the last seed change
AutoDemo     = $85   ; 1 = the seed changes at frame 240; 0 after SELECT
PlayerX      = $86   ; the player's left edge, 40..120
PlayerDir    = $87   ; 0 = left, 1 = right
PrevSelect   = $88   ; SELECT edge latch
TempBase     = $89   ; scratch: type * 24
TempVar      = $8A   ; scratch: variant * 3
TempType     = $8B   ; scratch: the mapped type
TempSeed     = $8C   ; scratch: the shifting copy of the seed
StatusPF0    = $8D   ; the status band's three playfield bytes
StatusPF1    = $8E
StatusPF2    = $8F
RowColor     = $90   ; 16 bytes: $90-$9F, one colour per row
RowPF0       = $A0   ; 16 bytes: $A0-$AF, chunks 0-3 per row
RowPF1       = $B0   ; 16 bytes: $B0-$BF, chunks 4-11 per row
RowPF2       = $C0   ; 16 bytes: $C0-$CF, chunks 12-19 per row
;
; $D0-$F7 are free (40 bytes).  The stack lives at $F8-$FF; the deepest
; call is BuildWorld -> EncodeRow (two levels, six bytes).

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port
    STA NUSIZ0
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA ENAM0
    STA ENAM1

    LDA #$01
    STA CTRLPF              ; REFLECT the playfield (bit 0); no priority;
                            ; a 1-pixel ball (unused)
    LDA #$00
    STA COLUBK              ; open ground and every gap: black
    LDA #C_STATUS
    STA COLUPF              ; the status band's bars
    LDA #C_PLAYER
    STA COLUP0              ; the player is white

; --- the first world ---------------------------------------------------------
; The seed is one byte.  BuildWorld steps the LFSR 16 times and encodes the
; 16 resulting states into the ring; BuildStatus turns the seed into the
; eight bars of the status band.
    LDA #SEED_A
    STA Seed
    LDA #$01
    STA AutoDemo
    LDA #$00
    STA DemoTimer
    STA ScrollTimer
    STA PrevSelect
    STA FrameLo
    LDA #PLAYER_MIN
    STA PlayerX
    LDA #$01
    STA PlayerDir

    JSR BuildWorld
    JSR BuildStatus

; --- position the player once before the first frame -------------------------
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetHorizPosP0

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

    INC FrameLo
    INC DemoTimer

; -----------------------------------------------------------------------------
; 1. SELECT — cycle the seed, and hand control to the player
; -----------------------------------------------------------------------------
    LDA SWCHB
    AND #$02                ; SELECT is active low
    BNE SelectReleased
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA #$00
    STA AutoDemo            ; the player's seed is no longer overridden
    LDA Seed
    CLC
    ADC #$01                ; the next seed
    BNE HaveSeed
    LDA #$01                ; skip the LFSR's fixed point
HaveSeed:
    STA Seed
    JSR BuildWorld
    JSR BuildStatus
    LDA #$00
    STA ScrollTimer         ; a new seed starts a fresh ring at once
    JMP SelectDone
SelectReleased:
    LDA #$00
    STA PrevSelect
SelectDone:

; -----------------------------------------------------------------------------
; 2. THE AUTO-DEMO'S SEED — A for 240 frames, B for 240, A again ...
; -----------------------------------------------------------------------------
; The 2-second capture (game frames 64-71) is seed A; the 5-second capture
; (game frames 256-263) is seed B; the second change at frame 480 rebuilds
; seed A's first 16 rows, which is the power-on world.  Pressing SELECT
; sets AutoDemo to 0 and the whole mechanism is skipped from then on.
    LDA DemoTimer
    CMP #DEMO_PERIOD
    BCC DemoDone
    LDA #$00
    STA DemoTimer
    LDA AutoDemo
    BEQ DemoDone
    LDA Seed
    CMP #SEED_A
    BNE SeedToA
    LDA #SEED_B
    JMP SetSeed
SeedToA:
    LDA #SEED_A
SetSeed:
    STA Seed
    JSR BuildWorld
    JSR BuildStatus
    LDA #$00
    STA ScrollTimer
DemoDone:

; -----------------------------------------------------------------------------
; 3. THE PLAYER — joystick left/right, or the auto-demo's slow oscillation
; -----------------------------------------------------------------------------
; SWCHA bit 6 is left and bit 7 is right, both active low.  If either is
; pressed the player moves one pixel per frame; otherwise the auto-demo
; moves one pixel every second frame and bounces between the limits.
    LDA SWCHA
    AND #$C0
    CMP #$C0                ; both bits high: no direction pressed
    BEQ AutoMove

    LDA SWCHA
    AND #$40                ; left?
    BNE CheckRight
    LDA PlayerX
    CMP #PLAYER_MIN
    BEQ PlayerMoved
    DEC PlayerX
    LDA #$00
    STA PlayerDir
    JMP PlayerMoved
CheckRight:
    LDA SWCHA
    AND #$80                ; right?
    BNE PlayerMoved
    LDA PlayerX
    CMP #PLAYER_MAX
    BEQ PlayerMoved
    INC PlayerX
    LDA #$01
    STA PlayerDir
    JMP PlayerMoved

AutoMove:
    LDA FrameLo
    AND #$01                ; one pixel every two frames
    BNE PlayerMoved
    LDA PlayerDir
    BNE AutoRight
    LDA PlayerX
    CMP #PLAYER_MIN
    BEQ BounceRight
    DEC PlayerX
    JMP PlayerMoved
BounceRight:
    LDA #$01
    STA PlayerDir
    JMP PlayerMoved
AutoRight:
    LDA PlayerX
    CMP #PLAYER_MAX
    BEQ BounceLeft
    INC PlayerX
    JMP PlayerMoved
BounceLeft:
    LDA #$00
    STA PlayerDir
PlayerMoved:

; --- re-establish the player's horizontal position every frame --------------
; The divide-by-15 routine is the Lesson 26 dance: RESP0 lands the coarse
; position, HMP0 carries the remainder, and HMOVE applies it in HBLANK.
; Re-strobing every frame is deliberate: there is no drift and no need to
; track whether X changed.
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetHorizPosP0

; -----------------------------------------------------------------------------
; 4. THE SCROLL — one row every 8 frames, and one LFSR step per new row
; -----------------------------------------------------------------------------
; The ring shifts up by one row (row 1 -> 0, ...), then the LFSR steps and
; the new state is encoded into the bottom row (index 15).  The step is
; exactly one LFSR step per generated row, so scrolling and generation stay
; locked together: the seed alone determines the entire future world.
    INC ScrollTimer
    LDA ScrollTimer
    CMP #$08
    BCC ScrollDone
    LDA #$00
    STA ScrollTimer
    JSR ShiftRing
    JSR StepLFSR
    LDX #(WORLD_ROWS - 1)
    JSR EncodeRow
ScrollDone:

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
BodyStart:                  ; checkpoint: scanline 37/5, visible line 0

; =============================================================================
; VISIBLE LINES 0-31: THE STATUS BAND (the seed as eight bars)
; =============================================================================
; The three status bytes are built whenever the seed changes.  The bars sit
; at chunks 2, 4, 6, ..., 16: one chunk on, one off.  REFLECT mode mirrors
; them into the right half, so the display is symmetric; the left-hand copy
; is the seed, most significant bit first.
    LDA #C_STATUS
    STA COLUPF
    LDA StatusPF0
    STA PF0
    LDA StatusPF1
    STA PF1
    LDA StatusPF2
    STA PF2
    LDX #STATUS_LINES
StatusLoop:
    STA WSYNC               ; end one status line
    DEX
    BNE StatusLoop
    ; X is now 0 and the CPU is at cycle 4 of visible line 32.

; =============================================================================
; VISIBLE LINES 32-191: THE WORLD (16 rows x 10 lines)
; =============================================================================
; X is the row index.  The header writes the row's colour and three
; playfield bytes; the row's ten lines then need only WSYNCs.  The last
; line of every row does the loop bookkeeping before its WSYNC, so the
; next header starts at cycle 3 and every register write meets its chunk
; deadline.
RowHeader:
    LDA RowColor,X          ; 4   4- 8  the row's terrain colour
    STA COLUPF              ; 3   8-11  before pixel 0 (22.67)
    LDA RowPF0,X            ; 4  11-15  chunks 0-3
    STA PF0                 ; 3  15-18  before 22.67
    LDA RowPF1,X            ; 4  18-22  chunks 4-11
    STA PF1                 ; 3  22-25  before 28.00
    LDA RowPF2,X            ; 4  25-29  chunks 12-19
    STA PF2                 ; 3  29-32  before 38.67
    CPX #PLAYER_ROW
    BEQ PlayerRow

; --- a plain terrain row: nine WSYNCs, then line 10 does the bookkeeping -----
    LDY #(ROW_LINES - 1)    ; 9
RowLines:
    STA WSYNC               ; end lines 1..9 of this row
    DEY
    BNE RowLines
    ; Visible line 10 of the row.  The PF registers still hold this row's
    ; bytes, so the last line is drawn correctly while X advances.
    INX
    CPX #WORLD_ROWS
    BEQ WorldEnd
    STA WSYNC               ; end line 10
    JMP RowHeader           ; the next header starts at cycle 3

; --- the player's row: eight sprite lines and two blank lines ----------------
PlayerRow:
    LDY #$00
PlayerLines:
    LDA PlayerGfx,Y         ; 4  blank, then the 8 sprite rows, then blank
    STA GRP0                ; 3
    STA WSYNC               ; end one line of the row
    INY
    CPY #(ROW_LINES - 1)    ; lines 1..9 carry Gfx 0..8
    BNE PlayerLines
    ; Line 10: draw the last (blank) player row, then close the row.
    LDA PlayerGfx+9
    STA GRP0
    INX
    CPX #WORLD_ROWS
    BEQ WorldEnd
    STA WSYNC               ; end line 10
    JMP RowHeader

; --- the last row has been drawn (visible line 191); begin the overscan ------
WorldEnd:
    STA WSYNC               ; end visible line 191
WorldDone:

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229, the first blanked line
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; STEPLFSR — the 8-bit Galois LFSR, taps $B8, maximal period 255
; =============================================================================
; A right shift moves bit 0 into the carry.  When that bit is 1 the feedback
; polynomial is XORed into the shifted byte.  $B8 = %10111000, so the taps
; are bits 7, 5, 4 and 3 of the shifted value.  Bit 7 becomes the old bit 0
; (shifted in as 0, then XORed); bits 5, 4 and 3 are pre-shift bits 6, 5
; and 4.  A nonzero seed visits every nonzero byte and returns to itself
; after 255 steps; zero is the fixed point and never enters the cycle.
StepLFSR:
    LDA LFSRState
    LSR                     ; bit 0 -> carry
    BCC .noTap
    EOR #$B8                ; the feedback: taps 7, 5, 4 and 3
.noTap:
    STA LFSRState
    RTS

; =============================================================================
; SHIFTRING — move every row one place toward the top of the screen
; =============================================================================
; Row 1 -> row 0, row 2 -> row 1, ..., row 15 -> row 14.  The four arrays
; are parallel, so one loop moves all four bytes of a row.  Fifteen rows
; because row 15 is about to be overwritten by the new bottom row.
ShiftRing:
    LDX #$00
.shift:
    LDA RowColor+1,X
    STA RowColor,X
    LDA RowPF0+1,X
    STA RowPF0,X
    LDA RowPF1+1,X
    STA RowPF1,X
    LDA RowPF2+1,X
    STA RowPF2,X
    INX
    CPX #(WORLD_ROWS - 1)
    BNE .shift
    RTS

; =============================================================================
; BUILDWORLD — rebuild all 16 rows from the seed
; =============================================================================
; The seed is loaded into the generator, then 16 steps produce the 16 rows.
; This is the determinism proof in code: the same seed always produces the
; same 16 states, and therefore the same 16 rows.
BuildWorld:
    LDA Seed
    STA LFSRState
    LDX #$00
.build:
    JSR StepLFSR
    JSR EncodeRow           ; X is the destination row
    INX
    CPX #WORLD_ROWS
    BNE .build
    RTS

; =============================================================================
; ENCODEROW — turn the current LFSR state into the row at index X
; =============================================================================
; state bits 0-1 -> a type through TypeMap (4 entries)
; state bits 2-4 -> one of 8 pattern variants
; The pattern is three bytes in PatternTable, indexed by type * 24 + variant * 3.
EncodeRow:
    LDA LFSRState
    AND #$03
    TAY
    LDA TypeMap,Y           ; the density control: slot -> terrain type
    STA TempType
    TAY
    LDA TypeColor,Y
    STA RowColor,X

    LDA TempType
    ASL                     ; type * 2
    CLC
    ADC TempType            ; type * 3
    ASL
    ASL
    ASL                     ; type * 24
    STA TempBase

    LDA LFSRState
    LSR
    LSR                     ; bits 2-4 now in bits 0-2
    AND #$07
    STA TempVar
    ASL                     ; variant * 2
    CLC
    ADC TempVar             ; variant * 3
    CLC
    ADC TempBase
    TAY

    LDA PatternTable,Y
    STA RowPF0,X
    LDA PatternTable+1,Y
    STA RowPF1,X
    LDA PatternTable+2,Y
    STA RowPF2,X
    RTS

; =============================================================================
; BUILDSTATUS — encode the 8-bit seed as eight playfield bars
; =============================================================================
; Block i sits at chunk 2 + 2i, so the eight bars span chunks 2..16.
; The masks are one bit each: PF0 bit 6, then four PF1 bits, then three
; PF2 bits.  The seed is shifted MSB first; a 1 lights the bar.
BuildStatus:
    LDA #$00
    STA StatusPF0
    STA StatusPF1
    STA StatusPF2
    LDA Seed
    STA TempSeed
    LDX #$00
.bar:
    ASL TempSeed            ; carry = the next seed bit, bit 7 first
    BCC .next
    LDA StatusPF0
    ORA BlockPF0,X
    STA StatusPF0
    LDA StatusPF1
    ORA BlockPF1,X
    STA StatusPF1
    LDA StatusPF2
    ORA BlockPF2,X
    STA StatusPF2
.next:
    INX
    CPX #$08
    BNE .bar
    RTS

; =============================================================================
; SETHORIZPOSP0 — the Lesson 26 divide-by-15 dance, for the player
; =============================================================================
; A = the desired left edge + the output-delay bias.  Each subtraction is
; 5 cycles = 15 color clocks; the remainder becomes the signed fine motion
; in HMP0 and the coarse strobe lands on the beam.  The final WSYNC and
; HMOVE put the fine motion inside HBLANK.
    !align 31, 0
SetHorizPosP0:
    STA WSYNC
    SEC
.divide:
    SBC #15
    BCS .divide
    EOR #7                  ; the negative remainder -> the signed fine value
    ASL                     ; bits 0-3 -> HMP0's high nibble
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0               ; the coarse strobe
    STA WSYNC
    STA HMOVE               ; apply HMP0 in HBLANK
    RTS

; =============================================================================
; THE PLAYER — 8x8, white, with a blank row above and below
; =============================================================================
; PlayerGfx[0] and PlayerGfx[9] are blank.  The row's first line is drawn
; after the header's 28 cycles; its GRP0 write lands at cycle 44, too late
; for a sprite at X=40, so keeping that line blank hides the late write.
; On each later line the INY/CPY/BNE take 7 cycles, the LDA starts at cycle
; 7 and the GRP0 write lands at cycle 13 (12 on the last real line), well
; before the beam reaches X=40.
PlayerGfx:
    !byte %00000000         ; line 1 of the row: blank
    !byte %00011000         ; line 2   ..##....
    !byte %00111100         ; line 3   .####...
    !byte %01111110         ; line 4   .######.
    !byte %11011011         ; line 5   ##.##.##
    !byte %11111111         ; line 6   ########
    !byte %01111110         ; line 7   .######.
    !byte %00111100         ; line 8   .####...
    !byte %00011000         ; line 9   ..##....
    !byte %00000000         ; line 10 of the row: blank

; =============================================================================
; THE TYPE MAP — four LFSR slots -> four terrain types
; =============================================================================
; The main ROM is the identity map: each terrain type gets one quarter of
; the rows.  Exercise 1 changes these four bytes to weight the generator
; toward water: the same LFSR sequence then produces a wetter world.
TypeMap:
    !byte 0, 1, 2, 3        ; slot 0 open, 1 jungle, 2 river, 3 wall

; =============================================================================
; THE TERRAIN PALETTE — one byte per type
; =============================================================================
TypeColor:
    !byte C_OPEN, C_JUNGLE, C_RIVER, C_WALL

; =============================================================================
; THE PATTERN TABLE — 4 types x 8 variants x 3 playfield bytes
; =============================================================================
; Index = type * 24 + variant * 3.  Each entry is PF0, PF1, PF2, i.e. chunks
; 0-3, 4-11 and 12-19 in the left half.  The right half is the REFLECT
; mirror, so these 20 chunks fill the 40-chunk line.
;
; Chunk-to-bit: chunks 0-3 are PF0 bits 4-7 (chunk 0 = bit 4); chunks 4-11
; are PF1 bits 7-0 (chunk 4 = bit 7); chunks 12-19 are PF2 bits 0-7
; (chunk 12 = bit 0).
PatternTable:
    ; --- type 0: open.  All eight variants are empty; the type's colour is
    ; --- black, so an open row is a clean gap in the world.
    !byte $00, $00, $00     ; open   0
    !byte $00, $00, $00     ; open   1
    !byte $00, $00, $00     ; open   2
    !byte $00, $00, $00     ; open   3
    !byte $00, $00, $00     ; open   4
    !byte $00, $00, $00     ; open   5
    !byte $00, $00, $00     ; open   6
    !byte $00, $00, $00     ; open   7

    ; --- type 1: jungle.  Checkers, stripes, solid and sparse growth.
    !byte $50, $AA, $55     ; jungle 0  even-chunk checker
    !byte $A0, $55, $AA     ; jungle 1  odd-chunk checker
    !byte $F0, $FF, $FF     ; jungle 2  solid
    !byte $30, $CC, $33     ; jungle 3  dense pairs
    !byte $C0, $33, $CC     ; jungle 4  offset pairs
    !byte $10, $88, $11     ; jungle 5  sparse every fourth chunk
    !byte $40, $22, $44     ; jungle 6  sparse offset
    !byte $70, $73, $39     ; jungle 7  diagonal blocks

    ; --- type 2: river.  A water band centred in the 20-chunk field;
    ; --- REFLECT mirrors it into two matching bands.  Eight widths: 20,
    ; --- 16, 12, 10, 8, 6, 4 and 2 chunks.  The banks are black.
    !byte $F0, $FF, $FF     ; river  0  full width (20 chunks)
    !byte $C0, $FF, $3F     ; river  1  chunks 2-17  (16)
    !byte $00, $FF, $0F     ; river  2  chunks 4-15  (12)
    !byte $00, $7F, $07     ; river  3  chunks 5-14  (10)
    !byte $00, $3F, $03     ; river  4  chunks 6-13  (8)
    !byte $00, $1F, $01     ; river  5  chunks 7-12  (6)
    !byte $00, $0F, $00     ; river  6  chunks 8-11  (4)
    !byte $00, $06, $00     ; river  7  chunks 9-10  (2)

    ; --- type 3: wall.  Solid segments, pairs, and sparse pillars.
    !byte $30, $CC, $33     ; wall   0  pairs at 0,4,8,12,16
    !byte $C0, $33, $CC     ; wall   1  pairs offset by 2
    !byte $F0, $FF, $FF     ; wall   2  solid
    !byte $70, $38, $C7     ; wall   3  three-chunk blocks
    !byte $E0, $1C, $8E     ; wall   4  three-chunk blocks offset
    !byte $10, $88, $11     ; wall   5  pillars every fourth chunk
    !byte $40, $22, $44     ; wall   6  pillars offset
    !byte $F0, $80, $F8     ; wall   7  two thick walls

; =============================================================================
; THE STATUS BAND'S BAR MASKS — one bit per seed bit
; =============================================================================
; Block i is chunk 2 + 2i.  These tables give the one register bit each
; block needs; BuildStatus ORs the ones whose seed bit is set.
BlockPF0:
    !byte $40, $00, $00, $00, $00, $00, $00, $00   ; chunk 2
BlockPF1:
    !byte $00, $80, $20, $08, $02, $00, $00, $00   ; chunks 4,6,8,10
BlockPF2:
    !byte $00, $00, $00, $00, $00, $01, $04, $10   ; chunks 12,14,16

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
> `lessons/part11-legendary/76-procedural-worlds/76-procedural-worlds.asm`.

### Code Walkthrough

#### Step 1 — Reset, the first world, and the first player position

`Reset` is the course's `+clean_start` plus the fixed TIA state: `CTRLPF = $01` selects the reflected playfield and no priority; `COLUBK` is black; `COLUPF` is the status colour; `COLUP0` is the player's white. Then the seed constants and the four variables are set, and `BuildWorld` / `BuildStatus` produce the first frame's data:

```asm
    LDA #SEED_A
    STA Seed
    LDA #$01
    STA AutoDemo
    ...
    JSR BuildWorld
    JSR BuildStatus
    LDA PlayerX
    CLC
    ADC #POS_BIAS
    JSR SetHorizPosP0
```

`BuildWorld` loads the seed into `LFSRState` and calls `StepLFSR` / `EncodeRow` sixteen times. `EncodeRow` uses `X` as the destination row; `StepLFSR` does not touch `X`, so the loop is just `INX` / `CPX #16` / `BNE`.

#### Step 2 — The vertical blank: SELECT, the seed timer, the player, the scroll

The vertical blank is where the world is generated. The order is:

1. `+set_timer VBLANK_TIMER` starts the 37-line blank.
2. `DemoTimer` and `FrameLo` advance.
3. SELECT is tested; a new press increments the seed and rebuilds.
4. `DemoTimer` reaches 240; the auto-demo toggles the seed (unless SELECT has taken over).
5. The player's X is updated from the joystick or the auto-demo.
6. `SetHorizPosP0` re-strobes the player.
7. The scroll timer reaches 8: `ShiftRing`, `StepLFSR`, `EncodeRow` into row 15.
8. `+wait_timer` anchors the end of the blank.

The generation and the shift are one package: one scroll step equals one LFSR step, so the world's future is determined by the seed alone. The scroll timer is reset to 0 when a seed rebuild happens, so a new seed starts its window at once instead of inheriting the old phase.

#### Step 3 — The status band

`BuildStatus` clears the three status bytes and walks the seed from bit 7 to bit 0:

```asm
    LDA Seed
    STA TempSeed
    LDX #$00
.bar:
    ASL TempSeed            ; carry = the next seed bit, bit 7 first
    BCC .next
    LDA StatusPF0
    ORA BlockPF0,X
    STA StatusPF0
    LDA StatusPF1
    ORA BlockPF1,X
    STA StatusPF1
    LDA StatusPF2
    ORA BlockPF2,X
    STA StatusPF2
.next:
    INX
    CPX #$08
    BNE .bar
    RTS
```

The three `BlockPFx` tables are eight bytes each; each entry is the single bit for that block's chunk. Block i is chunk 2 + 2i, so the first block is `PF0` bit 6 (`$40`), the next four are `PF1` bits 7, 5, 3 and 1, and the last three are `PF2` bits 0, 2 and 4. The reflections on the right half are the playfield's mirror, not eight more bits.

#### Step 4 — One world row, ten lines

The row header and the ten-line hold are the kernel's whole job. The header writes the colour and the three playfield bytes; the first of the row's ten lines is the header's own line, and the next nine are plain `WSYNC`s. The tenth line's `INX`/`CPX` runs before its `WSYNC` so the next header starts at cycle 3. The measured store completions on a normal row are 17 (`PF0`), 24 (`PF1`) and 31 (`PF2`), against the deadlines 22.67, 28.00 and 38.67.

The player row replaces the nine-`WSYNC` hold with ten `GRP0` writes. `PlayerGfx[0]` and `PlayerGfx[9]` are blank, so the first line (whose `GRP0` write lands at cycle 44, too late for X=40) and the last line are clean. On each later line the `INY`/`CPY`/`BNE` take 7 cycles, the `LDA` starts at cycle 7 and the `GRP0` write lands at cycle 13 (12 on the last real line), well before the sprite's left edge.

#### Step 5 — StepLFSR and EncodeRow

`StepLFSR` is five instructions. `EncodeRow` is longer because it must turn a state into a table index:

```asm
    LDA LFSRState
    AND #$03
    TAY
    LDA TypeMap,Y
    STA TempType
    TAY
    LDA TypeColor,Y
    STA RowColor,X
    ...
    LDA TempType
    ASL
    CLC
    ADC TempType            ; type * 3
    ASL
    ASL
    ASL                     ; type * 24
    STA TempBase
    LDA LFSRState
    LSR
    LSR                     ; bits 2-4 in bits 0-2
    AND #$07
    STA TempVar
    ASL
    CLC
    ADC TempVar             ; variant * 3
    CLC
    ADC TempBase
    TAY
    LDA PatternTable,Y
    STA RowPF0,X
    LDA PatternTable+1,Y
    STA RowPF1,X
    LDA PatternTable+2,Y
    STA RowPF2,X
```

The index is `type * 24 + variant * 3`; the table is type-major, eight variants per type, three bytes per variant. `EncodeRow` leaves `X` alone, which is what lets `BuildWorld` and `RewindWorld` use `X` as the row counter.

#### Step 6 — ShiftRing and the scroll

`ShiftRing` is fifteen iterations of four byte moves:

```asm
    LDX #$00
.shift:
    LDA RowColor+1,X
    STA RowColor,X
    LDA RowPF0+1,X
    STA RowPF0,X
    LDA RowPF1+1,X
    STA RowPF1,X
    LDA RowPF2+1,X
    STA RowPF2,X
    INX
    CPX #(WORLD_ROWS - 1)
    BNE .shift
    RTS
```

It stops at `X = 15`: row 15 is about to be overwritten by the new bottom row, so it does not need to be copied. The scroll block then calls `StepLFSR` and `EncodeRow` with `X = 15`. The cost is about 600 cycles (roughly 22% of the vertical blank); the rest of the blank has room for the seed demo and the player positioner.

#### Step 7 — Reading it back

Assemble with a symbol list and break at the checkpoints:

```bash
acme -f plain -l build/lesson76.lst -o build/lesson76.bin \
  lessons/part11-legendary/76-procedural-worlds/76-procedural-worlds.asm
grep -E "StartFrame|VblankStart|BodyStart|RowHeader|PlayerRow|OverscanStart|StepLFSR|ShiftRing|BuildWorld|SetSeed" build/lesson76.lst
```

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F05F` | 259/3 | the first VSYNC line |
| `VblankStart` | `$F06D` | 0/5 | the first VBLANK line |
| `BodyStart` | `$F15A` | 37/5 | visible line 0 |
| `RowHeader` | `$F171` | 69/4 (first row; 3 later) | the world's first header |
| `PlayerRow` | `$F196` | 209/36 | the player row's first line |
| `OverscanStart` | `$F1B5` | 229/0 | the first blanked line |
| `StepLFSR` | `$F1C8` | entry | the generator step |
| `ShiftRing` | `$F1D2` | entry | the ring shift |
| `BuildWorld` | `$F1EA` | entry | the seed rebuild |
| `SetSeed` | `$F0C4` | entry | the auto-demo's seed change |

The state that is worth watching in RAM:

| Address | Holds | What to expect |
|---|---|---|
| `$80` | `LFSRState` | the current generator byte, never zero |
| `$81` | `Seed` | `$FA` at power-on, `$D0` at frame 240, `$FA` at frame 480 |
| `$82` | `ScrollTimer` | 0-7; resets on a shift and on a seed change |
| `$84` | `DemoTimer` | 0-239; the auto-demo's seed period |
| `$86` | `PlayerX` | 40-120, one pixel every two frames |
| `$8D`-`$8F` | `StatusPF0/1/2` | the seed bars: `40 AA 04` for `$FA`, `40 88 00` for `$D0` |
| `$90`-`$9F` | `RowColor` | sixteen colour bytes |
| `$A0`-`$AF` | `RowPF0` | sixteen bytes, chunks 0-3 |
| `$B0`-`$BF` | `RowPF1` | sixteen bytes, chunks 4-11 |
| `$C0`-`$CF` | `RowPF2` | sixteen bytes, chunks 12-19 |

At frame 1 the seed is `$FA`, the generator state is `$BF` (the sixteenth step), and the ring is the seed-A table below. At frame 8 the state is `$E7` (the seventeenth step) and the ring is the same table shifted up one row with `$E7` at the bottom. At frame 240 the seed is `$D0` and the ring is the seed-B table. At frame 480 the seed is `$FA` and the ring is byte-for-byte the frame-1 ring.

### The seed-A and seed-B tables

The first sixteen rows from seed `$FA`:

| Row | State | Type | Variant | `PF0` | `PF1` | `PF2` |
|---:|---|---|---:|---:|---:|---:|
| 0 | `$7D` | jungle | 7 | `70` | `73` | `39` |
| 1 | `$86` | river | 1 | `C0` | `FF` | `3F` |
| 2 | `$43` | wall | 0 | `30` | `CC` | `33` |
| 3 | `$99` | jungle | 6 | `40` | `22` | `44` |
| 4 | `$F4` | open | 5 | `00` | `00` | `00` |
| 5 | `$7A` | river | 6 | `00` | `0F` | `00` |
| 6 | `$3D` | jungle | 7 | `70` | `73` | `39` |
| 7 | `$A6` | river | 1 | `C0` | `FF` | `3F` |
| 8 | `$53` | wall | 4 | `E0` | `1C` | `8E` |
| 9 | `$91` | jungle | 4 | `C0` | `33` | `CC` |
| 10 | `$F0` | open | 4 | `00` | `00` | `00` |
| 11 | `$78` | open | 6 | `00` | `00` | `00` |
| 12 | `$3C` | open | 7 | `00` | `00` | `00` |
| 13 | `$1E` | river | 7 | `00` | `06` | `00` |
| 14 | `$0F` | wall | 3 | `70` | `38` | `C7` |
| 15 | `$BF` | wall | 7 | `F0` | `80` | `F8` |

The first sixteen rows from seed `$D0`:

| Row | State | Type | Variant | `PF0` | `PF1` | `PF2` |
|---:|---|---|---:|---:|---:|---:|
| 0 | `$68` | open | 2 | `00` | `00` | `00` |
| 1 | `$34` | open | 5 | `00` | `00` | `00` |
| 2 | `$1A` | river | 6 | `00` | `0F` | `00` |
| 3 | `$0D` | jungle | 3 | `30` | `CC` | `33` |
| 4 | `$BE` | river | 7 | `00` | `06` | `00` |
| 5 | `$5F` | wall | 7 | `F0` | `80` | `F8` |
| 6 | `$97` | wall | 5 | `10` | `88` | `11` |
| 7 | `$F3` | wall | 4 | `E0` | `1C` | `8E` |
| 8 | `$C1` | jungle | 0 | `50` | `AA` | `55` |
| 9 | `$D8` | open | 6 | `00` | `00` | `00` |
| 10 | `$6C` | open | 3 | `00` | `00` | `00` |
| 11 | `$36` | river | 5 | `00` | `1F` | `01` |
| 12 | `$1B` | wall | 6 | `40` | `22` | `44` |
| 13 | `$B5` | jungle | 5 | `10` | `88` | `11` |
| 14 | `$E2` | river | 0 | `F0` | `FF` | `FF` |
| 15 | `$71` | jungle | 4 | `C0` | `33` | `CC` |

The two tables differ in all sixteen rows (type or variant), which is the "same cycle, different phase" effect in concrete bytes.

### The determinism replay

The state log has four moments that make the determinism visible:

| Moment | Seed | State | Ring |
|---|---|---|---|
| Frame 1 | `$FA` | `$BF` | the seed-A table above |
| Frame 8 | `$FA` | `$E7` | the frame-1 table shifted up one row; row 15 is `$E7` (wall variant 1, `C0 33 CC`) |
| Frame 240 | `$D0` | `$71` | the seed-B table above |
| Frame 480 | `$FA` | `$BF` | byte-for-byte the frame-1 table |

The frame-8 shift is the ring in motion: row 0 becomes the old row 1 (`$86`, river variant 1, `C0 FF 3F`), every row moves up by one, and the new row 15 is the seventeenth state `$E7` (wall variant 1, `C0 33 CC`). Between frame 8 and frame 15 the ring does not change: the scroll step is every eighth frame, and the window is held for eight frames at a time.

The frame-480 replay is the proof. `BuildWorld` re-runs from the seed, the first sixteen states are `7D 86 ... BF`, and the four arrays are the frame-1 arrays again. The auto-demo makes the same point with the status bars: `$FA` has six bars, `$D0` has three, and the bars return to six at frame 480.

## What You Should See

At power-on the screen is black, with a white status band at the top and a world below it. The status band shows the seed `$FA` as six white bars on the left, mirrored by six more on the right. Under it, the first world is the seed-A table: a green jungle weave, a wide blue river, a grey wall of pairs, a jungle, an open black row, a narrow river, more jungle and river, a wall at row 8, then the open rows and the two-wall tail at rows 14-15. A white 8x8 player sits at the bottom of the world window: at power-on its left edge is TIA X=40; in the 2-second capture it is X=72. Its lines are always visible 173-180. Every eight frames the whole world jumps up one ten-line row and a new bottom row appears; the player stays at its row and sweeps right one pixel every two frames.

![Stella running Lesson 76 at two seconds: the white seed bars at the top, then a world of green jungle checkers, blue river bands, grey walls and black open rows, with the white player near the bottom](/images/lesson76/world-seed-a.png)

*`world-seed-a.png`: about 2 seconds after power-on. The status band is seed `$FA` (six bars, mirrored); the window is the eight-scroll-step window, states `$53` through `$7F`. The player is at TIA X=72.*

<RomPlayer rom="/roms/part11-legendary/76-procedural-worlds/76-procedural-worlds.bin" title="Lesson 76 — Procedural Worlds from a Seed — Pitfall! & River Raid" />

*Javatari starts muted; this ROM is silent.*

At frame 240 (about four seconds of game time) the seed changes to `$D0`. The status bars drop to three on each side and the world rebuilds from the new seed: a river, a jungle checker, a wider river, a three-row wall block (rows 3-5), a jungle, two open rows, a river, a wall and the jungle/river/open tail. The 5-second capture is two scroll steps into the new world:

![Stella running Lesson 76 at five seconds: three white seed bars at the top, a new world with open rows, a blue river, green jungle and grey walls, and the white player near the bottom](/images/lesson76/world-seed-b.png)

*`world-seed-b.png`: about 5 seconds after power-on, after the frame-240 seed change. The status band is seed `$D0` (three bars, mirrored); the window is states `$1A` through `$40`, the first sixteen rows of seed `$D0` after two scroll steps. The player is at TIA X=73.*

The two images are different states, not two copies of one frame. The **pixel check** of the two committed captures:

| Image | Size | Title bar | Status bars | The world window, decoded |
|---|---|---|---|---|
| `world-seed-a.png` | 1010x807 | `Stella 7.0: "76-procedural-worlds"` | six bars left at chunks 2, 4, 6, 8, 10, 14, mirrored to six right; seed `$FA` | rows 0-15: wall 4, jungle 4, open, open, open, river 7, wall 3, wall 7, wall 1, wall 2, jungle 7, river 5, wall 2, jungle 3, river 7, wall 7 |
| `world-seed-b.png` | 1010x807 | `Stella 7.0: "76-procedural-worlds"` | three bars left at chunks 2, 4, 8, mirrored to three right; seed `$D0` | rows 0-15: river 6, jungle 3, river 7, wall 7, wall 5, wall 4, jungle 0, open, open, river 5, wall 6, jungle 5, river 0, jungle 4, open, open |

The **window check**: the seed-A image's sixteen row types are exactly states `$53` to `$7F` (states 9-24), the window after eight scroll steps; the seed-B image's sixteen rows are exactly states `$1A` to `$40` (the first sixteen rows of `$D0` after two scroll steps). Both windows were matched against the host model's 255-state cycle; every row's type and variant matched. The two images differ in all sixteen rows.

The **seed check**: the six bars in the first image are chunks 2, 4, 6, 8, 10 and 14 of the left half (and the mirror). Seed `$FA` is `%11111010`, so bits 7, 6, 5, 4, 3 and 1 are set: blocks 0, 1, 2, 3, 4 and 6, which are exactly those chunks. The three bars in the second image are chunks 2, 4 and 8; seed `$D0` is `%11010000`, bits 7, 6 and 4, blocks 0, 1 and 3. The playfield's `REF` bit makes the right half a mirror, so the left-hand bars are the seed and the right-hand bars are the same six (or three) bits again.

The **player check**: the white sprite is eight pixels wide and eight lines tall. In the first image its left edge is TIA X=72 and its lines are visible 173-180; in the second, X=73 and the same lines. The player is in the world band, on row 14 of the sixteen, not in the status band. The two positions are what the auto-demo's one-pixel-every-two-frames movement predicts at game frames 64-71 and 256-263.

The **colour check**: the sampled chunk colours are the standard Stella palette's green (61, 151, 60) for jungle, blue (55, 103, 187) for river, grey (186, 186, 185) for wall, black (0, 0, 0) for open, and white for the status bars and the player. The open rows are black, not "missing": the pattern table's open entries are zero and the type's colour is black.

> **Capture method.** Both images are `scripts/capture-screenshot.sh` captures of the committed
> `docs/public/roms/part11-legendary/76-procedural-worlds/76-procedural-worlds.bin` on display `:0`
> at approximately two and five wall-clock seconds, with `xdotool mousemove 0 0` before each.
> Stella's start-up takes under a second, so the 2-second image covers game frames 64-71 (eight
> scroll steps, seed `$FA`) and the 5-second image covers game frames 256-263 (two scroll steps
> after the frame-240 seed change, seed `$D0`). All images are 1010x807, carry the window frame
> and the `Stella 7.0: "76-procedural-worlds"` title bar, and show no cursor.

The model's frame log is the clock behind the pictures:

| Checkpoint | Line/cycle | What it proves |
|---|---|---|
| `StartFrame` | 259/3 | the VSYNC begins at line 259 |
| `VblankStart` | 0/5 | the blank begins at line 0 |
| `BodyStart` | 37/5 | the picture begins at line 37, every frame, including the seed changes |
| `RowHeader` | 69/4 | the first world row begins at visible line 32 |
| `PlayerRow` | 209/36 | the player row begins at visible line 172 |
| `OverscanStart` | 229/0 | the picture ends at line 228; the blank begins at 229 |

The frame is 262 lines; the visible body is 229 - 37 = 192; the band split is 32 + 160 = 192. Stella's instruction trace of this ROM shows steady-state frames with scanlines 1-262 (114 frames in a three-second trace; the trace logging slows the emulator, so the frame rate is not real time). The captures show the stable picture; the state log shows the ring.

## Exercises

Each exercise ships a complete 4,096-byte `exercise-NN-solution.asm`. The solutions assemble through `npm run roms`, run in Stella, and solve the exercise as written.

### Exercise 1: A Wetter World

**Challenge:** change the tile palette and the terrain density. Make **half** of the generated rows river instead of a quarter, keep jungle and wall in the mix, remove open terrain, and give the world a new palette: bright blue water, bright green jungle, brown walls, and gold status bars. Keep the ROM at 4,096 bytes and the frame at 262 lines.

**Hints:**

1. The density is the four-byte `TypeMap`. The main ROM's map is `{0,1,2,3}` (one quarter each). `{2,2,1,3}` maps both slot 0 and slot 1 to river, slot 2 to jungle and slot 3 to wall: half the rows are water and open disappears.
2. The palette is the four-byte `TypeColor` table. `$9E` is bright blue, `$D6` bright green, `$36` brown, and `$1E` gold for the status bars. Keep `$00` for open even though the map no longer selects it.
3. The pattern table, the LFSR, the ring and the kernel do not change. The build-time band assertion and the two seed constants stay as they are.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; the first sixteen rows from seed `$FA` are 8 river, 4 jungle and 4 wall (no open) instead of 4 river, 4 jungle, 4 wall and 4 open; the status bars are gold; `BodyStart` is 37/5 and the frame is 262. The host model reports 8 river rows, and a Stella capture shows the bright blue/green/brown palette.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: The World Behind the Player *(Stretch Goal)*

**Challenge:** add the reverse LFSR step so the sixteen rows behind the player's window can be rebuilt from the current state. At frame 200, reverse sixteen steps, rebuild the ring backwards (row 15 first, then row 14, ..., row 0), restore the saved state, and let forward scrolling resume. The rebuilt window must be the same sixteen rows that were on screen sixteen scroll steps earlier; the ROM must stay at 4,096 bytes and the frame at 262 lines on the rewind frame.

**Hints:**

1. The inverse of `LSR` + conditional `EOR #$B8` is `ASL` + conditional `EOR #$70` + `ADC #0`, because bit 7 of the new state is the old bit 0. The exact sequence is in the lesson's theory and in `RevStep`.
2. Reverse sixteen steps from the current state to reach the state of the row sixteen rows back. Save that state; it is row 15 of the rebuilt window. Then for row 15 down to row 0: encode the current state into the row, reverse one step, and move up one row. The loop must encode row 0 as well — the first version of this solution exited on `DEX`/`BNE` before row 0 and left a one-row seam.
3. Restore the saved state after the rebuild so the next forward scroll step produces the row that followed the rebuilt window. The rewind frame should skip the player positioner and the scroll: the rebuild is about 2,600 cycles, which fits the 37-line blank only if it starts at line 0 and nothing else runs. The frame still ends on 262 lines.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `BodyStart` is 37/5 on every frame, including frame 200; the ring at frame 200 (after the rebuild and the frame's skipped scroll) is byte-for-byte the ring at frame 71, which is sixteen scroll steps earlier. The screen jumps back one full window, the status bars stay on seed `$FA`, and the next scroll step continues from the restored state.

**Solution:** See `exercise-02-solution.asm`

## Key Takeaways

- ✅ **A world can be a sequence, not a map.** One seed byte and one shift-and-XOR step describe 255 terrain rows; the cartridge stores the generator and a 96-byte pattern table, not the rows. The same idea is the heart of *Pitfall!* and *River Raid*.
- ✅ **The Galois step is five instructions.** `LSR` moves bit 0 to the carry; a conditional `EOR #$B8` applies the feedback. `$B8` is maximal: every nonzero seed visits all 255 nonzero states, and zero is the fixed point that freezes the generator.
- ✅ **The reverse step is exact and cheap.** Because `$B8` has bit 7 set, bit 7 of the new state is the old bit 0; `ASL` + conditional `EOR #$70` + `ADC #0` inverts the step. The exercise rebuilds the previous window with it.
- ✅ **The ring is the window, not the world.** Sixteen rows, four parallel arrays, 64 bytes; one shift every eight frames, one LFSR step per new bottom row. The window is states N+1 through N+16, and the rest of the world is the generator's future or past.
- ✅ **Determinism is visible and testable.** The same seed produces the same sixteen states and the same 64 ring bytes; the auto-demo's frame-480 rebuild is byte-for-byte the frame-1 world, and the two captures decode to exactly the model's windows.
- ✅ **The kernel pays for the world in the vertical blank.** The header's four loads and four stores are 28 cycles and write four registers once per ten-line row; the tightest deadline is `PF1` at 24 against 28.00. The rotated loop's last-line bookkeeping is what keeps the next header at cycle 3.
- ✅ **Two bits of type plus three bits of pattern is enough.** Four terrain types and eight variants per type give 32 distinct rows from five bits of the LFSR state; the top three bits are still part of the future state, so the world keeps changing.

## What's Next

The world ends with the two captures and the ring; [the Part 11 index](/part11-legendary/) lists the rest of the anthology. The next lesson, **Lesson 77 — Interlaced Flicker — Faking More Colours & Resolution**, adds two alternating whole-frame pictures at 30 Hz, so the eye blends colours and detail that a single frame cannot draw. Return to the index for the part's overview; the Lesson 77 page will be linked there.
