---
title: "Lesson 61: Compression & Data Encoding — Fitting More in 4KB"
description: "Store a 192-row playfield picture as a 214-byte run-length-encoded stream instead of 576 raw bytes, decode one row per scanline into a three-byte buffer, prove the decode with an 8-bit checksum, and use the same idea for a sprite table, a second token scheme, and a 2-bit-per-pixel dictionary."
prev:
  text: "Lesson 60: DPC and DPC+ — Enhanced Audio and Graphics"
  link: "/part8-advanced/60-dpc-plus"
next:
  text: "Lesson 62: Reverse Engineering a Classic Game"
  link: "/part8-advanced/62-reverse-engineering"
---

# Lesson 61: Compression & Data Encoding — Fitting More in 4KB

> **Part 8: Advanced Topics** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 03 (the memory map), Lesson 04 (registers and memory), Lesson 09 (bitwise operations), Lesson 10 (addressing modes), Lesson 11 (lookup tables), Lesson 12 (the frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 48 (the kernel taxonomy), Lesson 58 (LAX and the stable illegal set)
> **You will learn:** run-length encoding (RLE); a token format with runs and literals; why the token's type lives in the count byte's top bit; a three-byte row buffer and the display/decode interleave; the exact cycle cost of decoding one row; the checksum that proves the decode; the difference between a run and a literal; and how the same ideas compress a sprite table, a second token scheme and a 2-bit-per-pixel image
> **You will build:** "the compressed logo" — a 4,096-byte ROM that stores a 192-row picture in 214 bytes, decodes one row per scanline, and shows the packed size, the raw size and the checksum; plus three 4,096-byte exercise solutions: a 16-frame sprite table in 66 bytes, a 257-byte alternate token scheme, and a 96-byte 2-bit-per-pixel picture

## Introduction

Lesson 60 bought a bigger picture with a mapper: the DPC put 2K of display memory inside the cartridge. This lesson buys a bigger picture with arithmetic instead. A 192-line playfield picture needs 576 bytes — three playfield bytes for each of 192 lines. On a 4K cartridge that is 14% of the whole ROM for one screen. The companion program `61-compression.asm` stores the same picture in 214 bytes and rebuilds it while the beam is drawing, three bytes at a time, in a row buffer that fits in the console's 128 bytes of RAM.

The scheme is **run-length encoding**. A stream of bytes usually contains repeats: a blank band is hundreds of zero bytes, a solid bar is hundreds of `$FF` bytes. RLE replaces a repeat with one control byte and one value: "the next 42 bytes are `$00`". The price is paid by the CPU, not the ROM: every visible line must decode its three bytes inside the 76 cycles the line has, and the decode has to finish before the playfield writes for the next line.

The program is built so the decode can be checked. At startup a verification pass walks the stream, decodes exactly 576 bytes, and adds them into an 8-bit checksum. The picture's status band — which is part of the picture, and therefore part of the stream — prints that checksum (`CK41`), the packed length (`PK214`) and the raw length (`RW576`). SELECT switches to a second stream, `PK224`/`CKDB`, which is the byte-count screen. A host script that decodes the same bytes from the committed ROM prints the same counts and the same sums, so the claim "the decoder is correct" is not a matter of opinion.

::: details TypeScript Equivalent

The decoder is a state machine with three pieces of state: how many bytes are left in the current run, how many literal bytes are left, and the run's value. In TypeScript, with the whole picture in memory, it looks like this:

```typescript
function decodeRle(stream: Uint8Array, rows: number): Uint8Array {
  const out = new Uint8Array(rows * 3);   // the whole picture, 576 bytes
  let p = 0;                              // stream index
  let o = 0;                              // output index
  let runLeft = 0;                        // bytes left in the current run
  let litLeft = 0;                        // literal bytes left
  let value = 0;                          // the run's value

  while (o < out.length) {
    if (runLeft > 0) {
      out[o++] = value;
      runLeft--;
    } else if (litLeft > 0) {
      out[o++] = stream[p++];
      litLeft--;
    } else {
      const control = stream[p++];
      if (control & 0x80) {
        runLeft = (control & 0x7f) + 1;   // 1..128
        value = stream[p++];
      } else {
        litLeft = control + 1;            // 1..128
      }
    }
  }
  return out;
}
```

The analogy teaches the shape — a pointer, a run counter, a literal counter, a value — and it breaks in the three places that matter on a 2600. First, the TypeScript version allocates 576 bytes for the output; the console has 128 bytes of RAM in total, so the real decoder writes **three bytes** and the line consumes them immediately. Second, the TypeScript loop has no deadline; the 2600 version must finish three bytes, the playfield writes and the line bookkeeping inside 76 CPU cycles. Third, `stream` is ROM: it can be read and never written, which is why the token format is designed to be decoded forward-only, with no back-references.

:::

## Theory

### Section 1: The 4K Budget and What a Picture Costs

The 6507 sees one 4K window at `$F000-$FFFF`. Everything the program is — code, tables, vectors — shares those 4,096 bytes. A full-screen playfield picture is the most expensive single table a 2600 game owns:

| Item | Bytes | Why |
|---|---|---|
| One playfield row | 3 | PF0 (4 displayed bits), PF1 (8 bits), PF2 (8 bits) |
| 192-row picture | 576 | 192 × 3 |
| Share of a 4K ROM | 14.1% | 576 / 4,096 |

576 bytes is affordable once. It is not affordable for a title screen, a level, a second level and a status screen. The usual 2600 answers are a mapper with more ROM (Lesson 56) or a display processor (Lesson 60). This lesson takes the third answer: keep the ROM small and spend CPU time rebuilding the picture on the fly.

The trade is easy to state and hard to execute. Saving 362 bytes of ROM (576 − 214) costs the decoder work on every one of the 192 visible lines. The line has 76 cycles; the playfield writes and the row bookkeeping take 26 of them; the decode has 50. The rest of the lesson is about fitting three bytes into those 50 cycles.

::: tip Why not decode once into RAM?
576 bytes cannot fit in 128 bytes of RAM. A 96-byte buffer would fit, but it would leave no room for the variables, the three-byte row buffer and the stack: the picture, the code's state and the return addresses all share the same 128 bytes. The picture has to be produced at the speed the beam consumes it. That is the same constraint every 2600 kernel lives under; compression only changes where the data comes from.
:::

### Section 2: Run-Length Encoding and the Token Format

RLE replaces a repeated byte with a **token**. This lesson's stream has two kinds of token, and the top bit of the control byte says which:

| Control byte | Meaning | Followed by |
|---|---|---|
| `1ccccccc` | a **run**: repeat one value `ccccccc + 1` times | one value byte |
| `0ccccccc` | **literals**: copy `ccccccc + 1` bytes | that many data bytes |

The count is stored as count − 1, so the seven bits cover 1..128. A run token is always two bytes. A literal token is `1 + count` bytes, because every literal byte has to be carried. The format has no end marker: the decoder stops when it has produced the number of bytes the caller asked for (576 here), which is why the exact decoded length is part of the checksum pass.

A worked example. The eight bytes

```
00 00 00 00 00 00 3C 3C
```

become two tokens:

```
85 00        ; run of 6 zeros   (count-1 = 5)
81 3C        ; run of 2 $3C     (count-1 = 1)
```

The first control byte `$85` is `1000 0101`: bit 7 set (a run), low seven bits 5, so count = 6. The second `$81` is a run of 2. Eight raw bytes became four stream bytes. On the other hand

```
10 20 30
```

has no repeated byte, so it becomes a literal token:

```
02 10 20 30
```

Three raw bytes became four stream bytes. **This is the honest shape of RLE**: it wins on repetition and loses on detail. A picture that is mostly blank or solid bands compresses well; one that is all edges does not. The lesson's picture is designed with that in mind — large blank and solid bands carry the size, while the logo and status rows are literals.

::: warning A byte run is not a row run
The token repeats **one byte**, not a three-byte row. Rows whose PF0, PF1 and PF2 differ are always literals, even if the same three bytes appear on many consecutive rows. That is why the encoder canonicalises the two run-friendly rows: a full-width "all on" row can be written `FF FF FF` (a single run value) instead of `F0 FF FF`, and an all-off row is `00 00 00`. The unused low four bits of PF0 are free, and the encoder uses them.
:::

### Section 3: The Row Buffer and the Display/Decode Interleave

The decoder's only picture buffer is three bytes at `$80-$82`, the **row buffer**; its state lives at `$8A-$8B`. Its job is to hold the three playfield bytes the TIA will display on the next line. The kernel is a pipeline:

```
line n:  write RowBuf -> PF0/PF1/PF2   (the line on the beam)
         decode the NEXT row -> RowBuf (the buffer is free to overwrite)
         WSYNC
```

The order is not cosmetic. `PF0`'s first pixel is at color clock 68, about CPU cycle 22.7; `PF1`'s is at 28.0; `PF2`'s is at 38.7. All three writes are at the top of the line, before the beam reaches the playfield. Only then does the decoder overwrite the buffer. If the decode ran first and the writes second, `PF0` would be written after its pixels had already gone by, and the left edge of every line would show the previous line's data.

The decoder consumes **one row per line**: 192 rows, 192 lines. That fixes the encoder's two rules:

1. **Counts are multiples of three.** A token ends on a row boundary, so the row loop can subtract exactly three bytes per line. A token of count 5 would leave two bytes for the next row and break the one-row-per-line invariant.
2. **Every token covers at least two rows.** A one-row token needs a separate "token starts and ends here" path whose line is two to four cycles over the budget. The encoder merges one-row literals into their neighbours and never emits a one-row run, so the path exists for safety but the stream never takes it.

The generator enforces both rules and the verification pass proves the stream decodes to exactly 576 bytes; the doc's host script repeats the proof from the committed ROM.

### Section 4: The Decoder State Machine

Four values describe the decoder's state:

| Storage | Name | Meaning |
|---|---|---|
| X | count | bytes left in the current token, minus one |
| Y | stream index | the next byte of the stream |
| `$8A` | `RunValue` | the value of the current run |
| `$8B` | `Mode` | 0 = literal row, 1 = run row |

The kernel has four row paths, and each one is a different combination of "new token or continuing token" and "run or literal":

- **run, continuing**: store `RunValue` three times, `DEX` three times, loop.
- **literal, continuing**: copy three stream bytes into `RowBuf`, `DEX` three times, loop.
- **run, starting**: read the control, mask the low seven bits into X, read the value, then store it three times.
- **literal, starting**: read the control into X (the low seven bits are already count − 1), copy three bytes, then continue in the literal loop.

The control's bit 7 chooses the path. The decoder reads the **next** token's control at the end of the token that just finished, so the token-start line does not pay for the read. The prefetch is the one place where the lesson reaches for an undocumented instruction:

```
Prefetch:
    +LAX_IND_Y DecodePtr    ; $B3: A and X = (DecodePtr),Y
    INY
```

`LAX (zp),Y` loads A and X from the same stream byte in five cycles. The documented pair `LDA (DecodePtr),Y` + `TAX` takes seven, and the extra two cycles push the worst line to 78 — two cycles past the line, which grows the frame by a line. Lesson 58 introduced LAX and the stable NMOS illegal opcodes; the plain `LAX zp` form is documented there, and this lesson uses the `(zp),Y` form: the prefetch needs the control in X as well as in A, and five cycles is the budget.

::: tip Where the state lives
`DecodePtr` is the stream's 16-bit base at `$83-$84`. The two streams are page-aligned and shorter than 256 bytes, so Y walks the whole stream and no `(DecodePtr),Y` access ever crosses a page boundary. A page crossing would add a cycle to the load, and the worst line has none to spare.
:::

### Section 5: The Cycle Ledger

The worst line is the last row of a literal token: it copies the row, discovers the token ended, and prefetches the next control. Measured instruction by instruction:

| Work | Cycles |
|---|---|
| `JMP` into the row loop from the previous line | 3 |
| `LDA RowBuf` / `STA PF0` | 6 |
| `LDA RowBuf+1` / `STA PF1` | 6 |
| `LDA RowBuf+2` / `STA PF2` | 6 |
| three × (`LDA (DecodePtr),Y` / `STA RowBuf` / `INY`) | 30 |
| `DEX` × 3 | 6 |
| `BPL` (not taken: the token is done) | 2 |
| `DEC RowsLeft` / `BEQ` (not taken) | 7 |
| `LAX (DecodePtr),Y` / `INY` | 7 |
| `STA WSYNC` | 3 |
| **Total** | **76** |

The WSYNC write lands on the line's last cycle, so the line stays 76 cycles. Every other path is shorter. The measured `STA WSYNC` start cycles are:

| Path | `STA WSYNC` starts at | Line total |
|---|---|---|
| literal continuation | 67 | 70 |
| literal token start | 71 | 74 |
| run continuation | 49 | 52 |
| run token start | 71 | 74 |

The one-row token paths are at least two cycles over the line; the encoder never emits a one-row token, so they are safety code only. The frame is the proof: Stella shows `BodyStart` at 37/5 and `OverscanStart` at 229/6, and the picture is exactly 192 lines.

A 76-cycle line is thin. The design keeps it there by removing every avoidable branch and by keeping the stream in one page; the checksum pass and the frame measurement are how the claim is verified rather than assumed.

### Section 6: The Checksum

Compression adds a new failure mode: a stream that decodes to the wrong picture. The console cannot compare the picture to the original — the original is not in RAM — so the lesson uses an 8-bit **sum** as a fingerprint:

```
checksum = (sum of all 576 decoded bytes) mod 256
```

The startup pass runs with `VBLANK = $02` (picture blanked) before the first VSYNC, decodes both streams, adds every byte, and stops when the 16-bit count reaches 576 ($0240). The pass is a separate, simple byte-at-a-time decoder; it has the whole VBLANK and as many frames as it needs, so it is written for clarity, not speed. Two facts come out of it: the decoded count is exactly 576, and the sum is `$41` for the logo stream and `$DB` for the byte-count stream.

The picture prints those numbers. The status band is part of the 192-row picture, so it is part of the stream, so the numbers on screen change the very data they describe. The generator handles that with a small fixed-point search: it tries pairs `(packed, checksum)`, encodes the image that prints them, and keeps a pair whose encoded stream reports exactly that packed length and that checksum. The logo's pair is `(214, $41)`; the byte-count screen's is `(224, $DB)`. Without the search the digits oscillate; with it the screen is self-consistent.

::: details The generator
The stream in the source is produced by a small Python script. It works on the 576-byte raw image and emits only whole-row tokens:

```python
def rle(raw):
    out = bytearray()
    i = 0
    while i < len(raw):
        # 1. extend a run of one byte
        j = i
        while j < len(raw) and raw[j] == raw[i] and j - i < 128:
            j += 1
        if j - i >= 3:
            out += bytes((0x80 | (j - i - 1), raw[i]))
            i = j
            continue
        # 2. otherwise collect literal rows until a run starts
        j = i
        while j < len(raw):
            if j > i and j + 2 < len(raw) and raw[j] == raw[j + 1] == raw[j + 2]:
                break
            j += 1
            if j - i >= 126:
                break
        out += bytes((j - i - 1,)) + raw[i:j]
        i = j
    return bytes(out)
```

The real generator adds three rules on top of that skeleton:

1. **Whole rows only.** A run or literal is rounded to a multiple of three bytes, so a token always ends on a row boundary.
2. **At least two rows.** A one-row literal is merged into a neighbouring literal; a one-row run becomes part of one. This keeps the decoder's expensive one-row path out of the stream.
3. **Run-friendly rows.** A full-width "on" row is written `FF FF FF` (the unused PF0 bits are free) and an all-off row `00 00 00`, so bands become single-byte runs.

The status digits make the script a fixed-point search: it encodes the image that prints `(packed, checksum)`, reads back the packed length and the checksum, and keeps the pair that prints itself. The logo's pair is `(214, $41)`.

:::

::: warning A checksum is not a hash
An 8-bit sum catches a wrong stream with probability about 255/256, but it is not cryptographic and it cannot catch every permutation. It is a debugging and verification aid: the host decode, the startup pass and the debugger's `Checksum` checkpoint all have to agree. The lesson uses that agreement as its evidence, not as a security claim.
:::

### Section 7: The Two Pictures and the Screen Switch

The cartridge holds two streams:

| Screen | Stream | Packed | Raw | Checksum | Rows |
|---|---|---|---|---|---|
| 0 — the logo | `LogoStream` | 214 | 576 | `$41` | 192 |
| 1 — byte counts | `StatsStream` | 224 | 576 | `$DB` | 192 |

SELECT toggles the `ScreenNum` variable (the `Screen` checkpoint). The switch is debounced against `SWCHB` bit 1 so a held switch toggles once; the decoder is reset in VBLANK and pre-decodes row 0 of the new stream. Both streams are page-aligned and shorter than 256 bytes, which is what lets one 8-bit Y walk either one.

The pictures are reflected: `CTRLPF = $01` mirrors the 20-bit playfield, so every playfield row is mirrored into the right half of the screen, which is why the screenshots show "RTB" and its mirror, and "PK214" followed by the mirror of the digits. The reflection is a free doubling of the picture's width, at the cost that the two halves touch at the centre.

### Section 8: Bit Packing and the Exercises

RLE is not the only encoding in the lesson. The three exercises each take a different angle:

1. **A sprite table.** Sixteen 8×8 frames are 128 raw bytes; the same token format, decoded one byte per line, stores them in 66 bytes. The exercise's decoder writes each byte into the slot it has just displayed, so one 8-byte buffer is enough.
2. **A second token scheme.** The lesson folds the type into the count byte. The exercise uses a separate opcode byte and a separate count byte; the same picture becomes 257 bytes instead of 214, exactly one extra byte per token (43 tokens). The comparison is the lesson: the folded byte is worth 43 bytes on this picture.
3. **Two bits per pixel.** A 20×19 picture is 95 bytes at 2 bits per pixel, padded to 96. Each 2-bit codeword indexes a four-entry dictionary; the decompressor rebuilds 19 playfield rows (57 bytes) in RAM and the kernel draws them. Bit packing beats RLE on a small, detailed picture where byte runs are rare, and it is the natural format for a multi-colour object.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lesson61.bin lessons/part8-advanced/61-compression/61-compression.asm
stella build/lesson61.bin
```

The ROM is 4,096 bytes.

### Full Source

The complete annotated source:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 61: Compression & Data Encoding — Fitting More in 4KB
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the compressed logo": a 4,096-byte cartridge that stores a 192-row
;   playfield picture as a run-length-encoded stream and rebuilds one row at a
;   time while the beam is drawing the picture.  The raw picture is 576 bytes
;   (192 rows x 3 playfield bytes); the packed stream is 214 bytes, 37.2% of
;   the raw size.  A second stream (224 bytes) is the byte-count screen; SELECT
;   switches between them.
;
; The picture:
;   The playfield is reflected (CTRLPF = $01).  Each row is three bytes:
;     PF0  bits 4-7  the leftmost four playfield chunks
;     PF1  bits 7-0  the next eight chunks
;     PF2  bits 0-7  the last eight chunks (bit 0 is the leftmost)
;   A chunk is four color clocks wide, so the 20 playfield bits fill the left
;   half of the 160-pixel screen and the reflected playfield fills the right.
;   The logo screen is a bold "RTB" over a band of status text:
;     PK214   the packed stream length
;     RW576   the raw picture length
;     CK41    the checksum of the decoded 576 bytes
;   The status text is part of the picture, so it is part of the stream.  The
;   generator iterates until the numbers printed on screen are exactly the
;   numbers of the stream that carries them (a fixed point).
;
; The RLE format (one control byte per token):
;   bit 7 = 1  a run:  the low seven bits are count-1, the next byte is the
;              value, and the decoder repeats that value count times.
;   bit 7 = 0  literals: the low seven bits are count-1, and the next count
;              bytes are copied unchanged.
;   Counts are 1..128.  This encoder writes only counts that are multiples of
;   three, so every token ends exactly on a row boundary, and every token
;   covers at least two rows (count >= 6).  The generator enforces both rules;
;   the row-stepped decoder relies on them.
;
; The decoder:
;   A small state machine with a three-byte row buffer at $80-$82.  The
;   register X holds the remaining bytes of the current token minus one, Y is
;   the index into the stream, and $8A/$8B hold the run value and the mode.
;   The visible kernel displays the row in RowBuf and decodes the NEXT row
;   during the same scanline; the row buffer is overwritten only after the
;   three playfield writes, so the current line is already on the beam.
;   The worst path is the last row of a literal token, and it is exactly 76
;   cycles:
;     JMP into LoopLit                      3
;     LDA RowBuf / STA PF0                  6
;     LDA RowBuf+1 / STA PF1                6
;     LDA RowBuf+2 / STA PF2                6
;     LDA (DecodePtr),Y / STA RowBuf / INY 10
;     LDA (DecodePtr),Y / STA RowBuf+1 / INY 10
;     LDA (DecodePtr),Y / STA RowBuf+2 / INY 10
;     DEX DEX DEX                           6
;     BPL (not taken)                       2
;     DEC RowsLeft / BEQ (not taken)         7
;     LAX (DecodePtr),Y / INY               7
;     STA WSYNC                             3
;     total                                76
;   The WSYNC write lands on the last cycle of the line, so the line stays 76
;   cycles.  Every other path is shorter.  Measured STA WSYNC start cycles
;   (the line total is three cycles more):
;     literal continuation   67  (70)
;     literal token start    71  (74)
;     run continuation       49  (52)
;     run token start        71  (74)
;   The one-row token paths are at least two cycles over the line.  The
;   encoder never emits a one-row token, so they are safety code only.
;   Stella's state log confirms BodyStart 37/5 and OverscanStart 229/6.
;
;   The control prefetch at the end of a token uses the undocumented NMOS
;   instruction LAX (DecodePtr),Y ($B3): it loads A and X from the stream in
;   five cycles.  The documented LDA (DecodePtr),Y + TAX pair takes seven and
;   would push the worst line to 78 cycles, so the picture would grow a line.
;   Lesson 58 introduced LAX and the stable illegal opcodes; this lesson uses
;   the (zp),Y form, and the LAX_IND_Y macro below keeps the opcode byte
;   visible.
;
; Why the row buffer matters:
;   The 2600 has 128 bytes of RAM.  576 bytes of picture cannot be held there,
;   and the cartridge cannot spare 576 bytes for every screen.  The row buffer
;   is the whole trick: the picture exists in RAM only three bytes at a time,
;   and those three bytes are exactly what the TIA needs for one line.
;
; The checksum:
;   At startup a verification pass decodes each stream from its first byte to
;   its last, adds every decoded byte into an 8-bit sum, and stops when the
;   count reaches 576.  The kernel's own decode is the same stream; the sum is
;   the proof that the stream the screen is showing is the stream the table
;   says it is.  A host script (the doc shows the Python) produces the same
;   576 bytes and the same sum.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229.
;   No player or missile is used, so there is no HMOVE in this kernel.
;
; The visible picture: 192 lines, one decoded row per line.
;
; Checkpoints (the state log's scanline/cycle and the A register):
;   StartFrame   the first VSYNC instruction
;   VblankStart  the first VBLANK instruction
;   BodyStart    the first visible line
;   OverscanStart the first overscan instruction
;   Screen       A = 0 (logo) or 1 (byte counts)
;   DecodePtrRead A = the stream's low byte
;   RowsLeftRead A = 191 (the rows the loop still has to draw)
;   RowByte0/1/2 A = the three row bytes at the playfield writes
;   DecodeCount  A/X = $02/$40 = 576 decoded bytes
;   Checksum     A = the logo stream's checksum ($41)
;   PackedLenRead A = 214 (logo) or 224 (stats), the active stream's length
;   RawLenRead   A = $40, the low byte of the 576-byte raw length
;   ChecksumRead A = $41 (logo) or $DB (stats), the active stream's sum
;
; RAM map (+clean_start zeroes every byte):
;   $80-$82  RowBuf       the three playfield bytes for the next line
;   $83-$84  DecodePtr    the active stream's 16-bit base address
;   $85      RowsLeft     rows left in the visible loop (191)
;   $86      PackedLen    the active stream's length in bytes
;   $87      RawLen       the low byte of the 576-byte raw length ($40)
;   $88      ChecksumVal  the active stream's decoded checksum
;   $89      ScreenNum    0 = logo screen, 1 = byte-count screen
;   $8A      RunValue     the value of the current run token
;   $8B      Mode         0 = literal row, 1 = run row
;   $8C      PrevSelect   the SELECT switch's previous state (debounce)
;   $8D-$8E  DecodeCnt    the verification pass's 16-bit byte counter
;   $8F      free
;   $90      SumLogo      the logo stream's checksum
;   $91      SumStats     the byte-count stream's checksum
;   $92      SumTmp       the verification pass's running sum
;   $93      PassValue    the verification pass's current byte
;   $94-$9F  free
;   $F8-$FF  stack
;
; Build: acme -f plain -o build/lesson61.bin \
;        lessons/part8-advanced/61-compression/61-compression.asm
; Run:   stella build/lesson61.bin
; The ROM is 4,096 bytes.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; -----------------------------------------------------------------------------
; LAX_IND_Y — the undocumented NMOS "load A and X" instruction, (zp),Y form
; -----------------------------------------------------------------------------
; ACME's !cpu 6502 does not accept the mnemonic, so the two opcode bytes are
; written out.  Lesson 58 introduced the stable illegal opcodes; this lesson
; uses LAX for one job: the control prefetch must put the next token's control
; byte in X in five cycles.  The documented LDA (ptr),Y + TAX pair needs seven,
; and that extra cycle pushes the last row of a literal token over the 76-cycle
; line.  $B3 is LAX (zp),Y: it loads A and X from the byte at (zp)+Y.
!macro LAX_IND_Y .zp {
    !byte $B3, .zp
}

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44          ; 37-line VBLANK (44 ticks)
OVERSCAN_TIMER = 36          ; 30-line overscan (1 + 35 x 64 cycles)
RAW_LEN        = 576         ; 192 rows x 3 playfield bytes
ROWS_LOOP      = 191         ; 191 loop rows + the pre-decoded row 0

; =============================================================================
; RAM ALLOCATION ($80-$9F; +clean_start zeroes every byte)
; =============================================================================
RowBuf      = $80            ; $80-$82
DecodePtr   = $83            ; $83-$84
RowsLeft    = $85
PackedLen   = $86
RawLen      = $87
ChecksumVal = $88
ScreenNum   = $89
RunValue    = $8A
Mode        = $8B
PrevSelect  = $8C
DecodeCnt   = $8D            ; $8D-$8E (verification pass only)
SumLogo     = $90
SumStats    = $91
SumTmp      = $92
PassValue   = $93

; =============================================================================
; RESET — the TIA setup and the two verification passes
; =============================================================================
    * = $F000

Reset:
    +clean_start             ; zero TIA and RAM, set SP = $FF

    LDA #$00
    STA COLUBK               ; black background
    LDA #$0E
    STA COLUPF               ; the picture is white
    LDA #$01
    STA CTRLPF               ; reflect the playfield
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDA #$02
    STA VBLANK               ; blank the picture while the startup passes run

; -----------------------------------------------------------------------------
; The verification pass: decode each stream, add all 576 bytes into a sum
; -----------------------------------------------------------------------------
; This runs before the first frame.  The screen is blanked, so it may take as
; long as it needs.  It proves the stream is exactly 576 decoded bytes and it
; produces the checksum the status text carries.
    LDA #<LogoStream
    STA DecodePtr
    LDA #>LogoStream
    STA DecodePtr+1
    JSR VerifyStream
    STA SumLogo
Checksum:                    ; checkpoint: A = the logo stream's checksum $41
    LDA #<StatsStream
    STA DecodePtr
    LDA #>StatsStream
    STA DecodePtr+1
    JSR VerifyStream
    STA SumStats

; The first frame starts from the logo screen.
    LDA #$00
    STA ScreenNum
    LDA #ROWS_LOOP
    STA RowsLeft
    LDA #<RAW_LEN
    STA RawLen
    JMP StartFrame

; -----------------------------------------------------------------------------
; VerifyStream — decode 576 bytes and sum them
; -----------------------------------------------------------------------------
; In: DecodePtr = the stream's base.  Out: A = the 8-bit sum, DecodeCnt =
; $0240.  This is a separate, slow decoder: it has the whole frame to itself,
; so it can afford the simple byte-at-a-time form.  It stops at exactly 576
; bytes, which is the guarantee that the visible decoder will not read past
; the stream.
VerifyStream:
    LDY #0
    LDA #$00
    STA SumTmp
    STA DecodeCnt
    STA DecodeCnt+1
NextToken:
    LDA DecodeCnt            ; 576 = $0240: is the picture complete?
    CMP #$40
    BNE ReadToken
    LDA DecodeCnt+1
    CMP #$02
    BEQ PassDone
ReadToken:
    LDA (DecodePtr),Y        ; the control byte
    INY
    TAX                      ; TAX sets N from the control: bit 7 decides
    BMI RunToken
; --- literals: copy count bytes into the sum ---------------------------------
    INX                      ; X = count
LitAdd:
    LDA (DecodePtr),Y
    INY
    STA PassValue
    LDA SumTmp
    CLC
    ADC PassValue
    STA SumTmp
    INC DecodeCnt
    BNE +
    INC DecodeCnt+1
+   DEX
    BNE LitAdd
    JMP NextToken
; --- a run: the low seven bits are count-1, the next byte is the value --------
RunToken:
    TXA
    AND #$7F
    CLC
    ADC #1
    TAX                      ; X = count
    LDA (DecodePtr),Y        ; the run's value
    INY
    STA PassValue
RunAdd:
    LDA SumTmp
    CLC
    ADC PassValue
    STA SumTmp
    INC DecodeCnt
    BNE +
    INC DecodeCnt+1
+   DEX
    BNE RunAdd
    JMP NextToken
PassDone:
    LDX DecodeCnt            ; X = $40
    LDA DecodeCnt+1          ; A = $02
DecodeCount:                 ; checkpoint: A/X = $02/$40 = 576 bytes
    LDA SumTmp
    RTS

; -----------------------------------------------------------------------------
; PreDecode — fill RowBuf with row 0 and set X and Mode
; -----------------------------------------------------------------------------
; In: DecodePtr = the stream's base, Y = 0.  Out: RowBuf = row 0, X = the
; token's count-1 minus 3 (the row's three bytes are already consumed), and
; Mode = 0 for a literal token or 1 for a run token.  The visible loop's first
; step continues from here.
PreDecode:
    LDA (DecodePtr),Y
    INY
    TAX
    BMI PreRun
    LDA (DecodePtr),Y
    STA RowBuf
    INY
    LDA (DecodePtr),Y
    STA RowBuf+1
    INY
    LDA (DecodePtr),Y
    STA RowBuf+2
    INY
    DEX
    DEX
    DEX
    LDA #0
    STA Mode
    RTS
PreRun:
    AND #$7F
    TAX
    LDA (DecodePtr),Y
    STA RunValue
    INY
    LDA RunValue
    STA RowBuf
    STA RowBuf+1
    STA RowBuf+2
    DEX
    DEX
    DEX
    LDA #1
    STA Mode
    RTS

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                  ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                 ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK               ; blank the picture
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; SELECT — one step per press, not one per frame
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  PrevSelect remembers the previous
; frame so a held switch toggles the screen once.
    LDA SWCHB
    AND #$02
    BEQ SelectDown
    LDA #$00
    STA PrevSelect
    JMP SelectDone
SelectDown:
    LDA PrevSelect
    BNE SelectDone
    LDA #$01
    STA PrevSelect
    LDA ScreenNum
    EOR #$01
    STA ScreenNum
SelectDone:

; -----------------------------------------------------------------------------
; Choose the active stream and set the decoder's starting state
; -----------------------------------------------------------------------------
    LDA ScreenNum
Screen:                      ; checkpoint: A = 0 (logo) or 1 (byte counts)
    BNE UseStats

; --- the logo screen ---------------------------------------------------------
    LDA #<LogoStream
    STA DecodePtr
    LDA #>LogoStream
    STA DecodePtr+1
    LDA #LogoPacked
    STA PackedLen
    LDA SumLogo
    STA ChecksumVal
    JMP StreamReady

; --- the byte-count screen ---------------------------------------------------
UseStats:
    LDA #<StatsStream
    STA DecodePtr
    LDA #>StatsStream
    STA DecodePtr+1
    LDA #StatsPacked
    STA PackedLen
    LDA SumStats
    STA ChecksumVal

StreamReady:
    LDA #<RAW_LEN
    STA RawLen
    LDY #0
    LDA #ROWS_LOOP
    STA RowsLeft
    LDA DecodePtr
DecodePtrRead:                   ; checkpoint: A = the stream's low byte
    JSR PreDecode
    LDA RowsLeft
RowsLeftRead:                    ; checkpoint: A = 191 rows still to draw
    LDA PackedLen
PackedLenRead:                   ; checkpoint: A = 214 (logo) or 224 (stats)
    LDA RawLen
RawLenRead:                      ; checkpoint: A = $40 (the low byte of 576)
    LDA ChecksumVal
ChecksumRead:                    ; checkpoint: A = $41 (logo) or $DB (stats)
    NOP                          ; the label must name a non-polling instruction

    +wait_timer
    LDA #$00
    STA VBLANK               ; picture on

; =============================================================================
; THE VISIBLE KERNEL — 192 lines, one decoded row per line
; =============================================================================
; At the top of every line the row in RowBuf is written to PF0/PF1/PF2.  Then
; the decoder rebuilds the NEXT row in RowBuf.  The writes happen first, so the
; line already on the beam keeps its picture while the buffer is overwritten.
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    LDA Mode
    BNE LoopRun

; -----------------------------------------------------------------------------
; LoopLit — display one row and decode three literal bytes
; -----------------------------------------------------------------------------
LoopLit:
    LDA RowBuf
    STA PF0
    LDA RowBuf+1
RowByte1:                    ; checkpoint: A = the second row byte
    STA PF1
    LDA RowBuf+2
RowByte2:                    ; checkpoint: A = the third row byte
    STA PF2
    LDA (DecodePtr),Y
    STA RowBuf
    INY
    LDA (DecodePtr),Y
    STA RowBuf+1
    INY
    LDA (DecodePtr),Y
    STA RowBuf+2
    INY
    DEX
    DEX
    DEX
    BPL ContLit
; --- the token ended: prefetch the next control byte -------------------------
    DEC RowsLeft
    BEQ LastTramp1
Prefetch1:
    +LAX_IND_Y DecodePtr
    INY
    STA WSYNC
    JMP TokenStart
ContLit:
    DEC RowsLeft
    BEQ LastTramp1
    STA WSYNC
    JMP LoopLit
LastTramp1:
    STA WSYNC
    JMP LastRow

; -----------------------------------------------------------------------------
; LoopRun — display one row and repeat the run's value
; -----------------------------------------------------------------------------
LoopRun:
    LDA RowBuf
RowByte0:                    ; checkpoint: A = the first row byte
    STA PF0
    LDA RowBuf+1
    STA PF1
    LDA RowBuf+2
    STA PF2
    LDA RunValue
    STA RowBuf
    STA RowBuf+1
    STA RowBuf+2
    DEX
    DEX
    DEX
    BPL ContRun
    DEC RowsLeft
    BEQ LastTramp2
Prefetch2:
    +LAX_IND_Y DecodePtr
    INY
    STA WSYNC
    JMP TokenStart
ContRun:
    DEC RowsLeft
    BEQ LastTramp2
    STA WSYNC
    JMP LoopRun
LastTramp2:
    STA WSYNC
    JMP LastRow

; -----------------------------------------------------------------------------
; TokenStart — display one row and decode the first row of a new token
; -----------------------------------------------------------------------------
; X holds the prefetched control byte.  Bit 7 selects run or literal; for a
; literal the low seven bits are already count-1, so X is ready.
TokenStart:
    LDA RowBuf
    STA PF0
    LDA RowBuf+1
    STA PF1
    LDA RowBuf+2
    STA PF2
    TXA
    BMI RunStart
    LDA (DecodePtr),Y
    STA RowBuf
    INY
    LDA (DecodePtr),Y
    STA RowBuf+1
    INY
    LDA (DecodePtr),Y
    STA RowBuf+2
    INY
    DEX
    DEX
    DEX
    BPL TokCont
; --- a one-row token (not produced by this encoder) -------------------------
    DEC RowsLeft
    BEQ LastTramp3
Prefetch3:
    +LAX_IND_Y DecodePtr
    INY
    STA WSYNC
    JMP TokenStart
TokCont:
    DEC RowsLeft
    BEQ LastTramp3
    STA WSYNC
    JMP LoopLit
LastTramp3:
    STA WSYNC
    JMP LastRow

; -----------------------------------------------------------------------------
; RunStart — decode the first row of a run token
; -----------------------------------------------------------------------------
RunStart:
    TXA
    AND #$7F
    TAX
    LDA (DecodePtr),Y
    STA RunValue
    INY
    LDA RunValue
    STA RowBuf
    STA RowBuf+1
    STA RowBuf+2
    DEX
    DEX
    DEX
    BPL RunCont
    DEC RowsLeft
    BEQ LastTramp4
Prefetch4:
    +LAX_IND_Y DecodePtr
    INY
    STA WSYNC
    JMP TokenStart
RunCont:
    DEC RowsLeft
    BEQ LastTramp4
    STA WSYNC
    JMP LoopRun
LastTramp4:
    STA WSYNC
    JMP LastRow

; -----------------------------------------------------------------------------
; LastRow — the 192nd visible line: display the final row and stop decoding
; -----------------------------------------------------------------------------
LastRow:
    LDA RowBuf
    STA PF0
    LDA RowBuf+1
    STA PF1
    LDA RowBuf+2
    STA PF2
    STA WSYNC
    NOP                      ; the Part 7/8 skeleton enters the overscan six
    NOP                      ; cycles into line 229
    NOP

; =============================================================================
; OVERSCAN — 30 lines, then the next frame
; =============================================================================
OverscanStart:               ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; THE STREAMS
; =============================================================================
; Each stream is page-aligned and smaller than 256 bytes.  That keeps every
; (DecodePtr),Y accesses stay inside one page: no index ever crosses
; a page boundary, so no load costs an extra cycle.
    !align 255, 0
LogoStream:
    !byte $88, $FF        ; run  x  9 $FF  rows   0-  2
    !byte $88, $00        ; run  x  9 $00  rows   3-  5
    !byte $8B, $FF        ; run  x 12 $FF  rows   6-  9
    !byte $88, $00        ; run  x  9 $00  rows  10- 12
    !byte $85, $FF        ; run  x  6 $FF  rows  13- 14
    !byte $88, $00        ; run  x  9 $00  rows  15- 17
    !byte $91, $FF        ; run  x 18 $FF  rows  18- 23
    !byte $8B, $00        ; run  x 12 $00  rows  24- 27
    !byte $29                      ; lit  x 42       rows  28- 41
    !byte $80, $CF, $0E, $80, $CF, $0E, $80, $24
    !byte $12, $80, $24, $12, $80, $24, $12, $80
    !byte $24, $12, $80, $C4, $0E, $80, $C4, $0E
    !byte $80, $44, $12, $80, $44, $12, $80, $24
    !byte $12, $80, $24, $12, $80, $24, $0E, $80
    !byte $24, $0E
    !byte $8B, $00        ; run  x 12 $00  rows  42- 45
    !byte $85, $FF        ; run  x  6 $FF  rows  46- 47
    !byte $8B, $00        ; run  x 12 $00  rows  48- 51
    !byte $8B, $FF        ; run  x 12 $FF  rows  52- 55
    !byte $88, $00        ; run  x  9 $00  rows  56- 58
    !byte $85, $FF        ; run  x  6 $FF  rows  59- 60
    !byte $88, $00        ; run  x  9 $00  rows  61- 63
    !byte $91, $FF        ; run  x 18 $FF  rows  64- 69
    !byte $8B, $00        ; run  x 12 $00  rows  70- 73
    !byte $85, $FF        ; run  x  6 $FF  rows  74- 75
    !byte $91, $00        ; run  x 18 $00  rows  76- 81
    !byte $1D                      ; lit  x 30       rows  82- 91
    !byte $70, $AE, $52, $70, $AE, $52, $50, $A2
    !byte $52, $50, $A2, $52, $70, $CE, $72, $70
    !byte $CE, $72, $10, $A8, $42, $10, $A8, $42
    !byte $10, $AE, $42, $10, $AE, $42
    !byte $8B, $00        ; run  x 12 $00  rows  92- 95
    !byte $1D                      ; lit  x 30       rows  96-105
    !byte $70, $AE, $77, $70, $AE, $77, $50, $A8
    !byte $14, $50, $A8, $14, $70, $EE, $74, $70
    !byte $EE, $74, $30, $E2, $54, $30, $E2, $54
    !byte $50, $AE, $74, $50, $AE, $74
    !byte $8B, $00        ; run  x 12 $00  rows 106-109
    !byte $1D                      ; lit  x 30       rows 110-119
    !byte $70, $AA, $02, $70, $AA, $02, $10, $AA
    !byte $02, $10, $AA, $02, $10, $CE, $02, $10
    !byte $CE, $02, $10, $A2, $02, $10, $A2, $02
    !byte $70, $A2, $02, $70, $A2, $02
    !byte $91, $00        ; run  x 18 $00  rows 120-125
    !byte $85, $FF        ; run  x  6 $FF  rows 126-127
    !byte $8E, $00        ; run  x 15 $00  rows 128-132
    !byte $8B, $FF        ; run  x 12 $FF  rows 133-136
    !byte $88, $00        ; run  x  9 $00  rows 137-139
    !byte $85, $FF        ; run  x  6 $FF  rows 140-141
    !byte $8E, $00        ; run  x 15 $00  rows 142-146
    !byte $91, $FF        ; run  x 18 $FF  rows 147-152
    !byte $8B, $00        ; run  x 12 $00  rows 153-156
    !byte $85, $FF        ; run  x  6 $FF  rows 157-158
    !byte $8E, $00        ; run  x 15 $00  rows 159-163
    !byte $8B, $FF        ; run  x 12 $FF  rows 164-167
    !byte $88, $00        ; run  x  9 $00  rows 168-170
    !byte $85, $FF        ; run  x  6 $FF  rows 171-172
    !byte $8E, $00        ; run  x 15 $00  rows 173-177
    !byte $91, $FF        ; run  x 18 $FF  rows 178-183
    !byte $85, $00        ; run  x  6 $00  rows 184-185
    !byte $91, $FF        ; run  x 18 $FF  rows 186-191
LogoPacked = * - LogoStream

; The assembler can pin the packed length, and does.  It cannot sum the
; decoded bytes without running the decoder, so the checksum is guarded by the
; startup pass and the host decode instead: a changed decoded sum with an
; unchanged length fails those checks, not the assembler.
    !if LogoPacked != 214 {
        !error "LogoPacked changed: update the PK214 status rows and the fixed point"
    }
    !if LogoPacked > 256 {
        !error "the logo stream must stay inside one page"
    }

    !align 255, 0
StatsStream:
    !byte $88, $FF        ; run  x  9 $FF  rows   0-  2
    !byte $94, $00        ; run  x 21 $00  rows   3-  9
    !byte $2C                      ; lit  x 45       rows  10- 24
    !byte $00, $E8, $07, $00, $E8, $07, $00, $E8
    !byte $07, $00, $A8, $01, $00, $A8, $01, $00
    !byte $A8, $01, $00, $E8, $07, $00, $E8, $07
    !byte $00, $E8, $07, $00, $C8, $01, $00, $C8
    !byte $01, $00, $C8, $01, $00, $AE, $07, $00
    !byte $AE, $07, $00, $AE, $07
    !byte $88, $00        ; run  x  9 $00  rows  25- 27
    !byte $85, $FF        ; run  x  6 $FF  rows  28- 29
    !byte $91, $00        ; run  x 18 $00  rows  30- 35
    !byte $2C                      ; lit  x 45       rows  36- 50
    !byte $00, $EE, $07, $00, $EE, $07, $00, $EE
    !byte $07, $00, $82, $01, $00, $82, $01, $00
    !byte $82, $01, $00, $E2, $07, $00, $E2, $07
    !byte $00, $E2, $07, $00, $22, $05, $00, $22
    !byte $05, $00, $22, $05, $00, $E2, $07, $00
    !byte $E2, $07, $00, $E2, $07
    !byte $88, $00        ; run  x  9 $00  rows  51- 53
    !byte $85, $FF        ; run  x  6 $FF  rows  54- 55
    !byte $97, $00        ; run  x 24 $00  rows  56- 63
    !byte $1D                      ; lit  x 30       rows  64- 73
    !byte $70, $AE, $57, $70, $AE, $57, $50, $A2
    !byte $54, $50, $A2, $54, $70, $CE, $77, $70
    !byte $CE, $77, $10, $A8, $41, $10, $A8, $41
    !byte $10, $AE, $47, $10, $AE, $47
    !byte $8B, $00        ; run  x 12 $00  rows  74- 77
    !byte $1D                      ; lit  x 30       rows  78- 87
    !byte $70, $AC, $07, $70, $AC, $07, $10, $AA
    !byte $05, $10, $AA, $05, $10, $CA, $03, $10
    !byte $CA, $03, $10, $AA, $05, $10, $AA, $05
    !byte $70, $AC, $07, $70, $AC, $07
    !byte $91, $00        ; run  x 18 $00  rows  88- 93
    !byte $8B, $FF        ; run  x 12 $FF  rows  94- 97
    !byte $88, $00        ; run  x  9 $00  rows  98-100
    !byte $85, $FF        ; run  x  6 $FF  rows 101-102
    !byte $8E, $00        ; run  x 15 $00  rows 103-107
    !byte $91, $FF        ; run  x 18 $FF  rows 108-113
    !byte $8B, $00        ; run  x 12 $00  rows 114-117
    !byte $85, $FF        ; run  x  6 $FF  rows 118-119
    !byte $8E, $00        ; run  x 15 $00  rows 120-124
    !byte $8B, $FF        ; run  x 12 $FF  rows 125-128
    !byte $88, $00        ; run  x  9 $00  rows 129-131
    !byte $85, $FF        ; run  x  6 $FF  rows 132-133
    !byte $8E, $00        ; run  x 15 $00  rows 134-138
    !byte $91, $FF        ; run  x 18 $FF  rows 139-144
    !byte $8B, $00        ; run  x 12 $00  rows 145-148
    !byte $85, $FF        ; run  x  6 $FF  rows 149-150
    !byte $8E, $00        ; run  x 15 $00  rows 151-155
    !byte $8B, $FF        ; run  x 12 $FF  rows 156-159
    !byte $88, $00        ; run  x  9 $00  rows 160-162
    !byte $85, $FF        ; run  x  6 $FF  rows 163-164
    !byte $8E, $00        ; run  x 15 $00  rows 165-169
    !byte $91, $FF        ; run  x 18 $FF  rows 170-175
    !byte $8B, $00        ; run  x 12 $00  rows 176-179
    !byte $85, $FF        ; run  x  6 $FF  rows 180-181
    !byte $8B, $00        ; run  x 12 $00  rows 182-185
    !byte $91, $FF        ; run  x 18 $FF  rows 186-191
StatsPacked = * - StatsStream

    !if StatsPacked != 224 {
        !error "StatsPacked changed: update the PK224 status rows and the fixed point"
    }
    !if StatsPacked > 256 {
        !error "the byte-count stream must stay inside one page"
    }

    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset, Reset, Reset
```

<!-- END-FULL-SOURCE -->

> The complete, fully-commented source lives in
> `lessons/part8-advanced/61-compression/61-compression.asm`.

### Code Walkthrough

#### Step 1 — Reset and the two verification passes

`Reset` runs `+clean_start`, sets the TIA to a black background and a white playfield, and calls `VerifyStream` twice: once with `DecodePtr` at `LogoStream`, once at `StatsStream`. Each call decodes 576 bytes, sums them and leaves the count in `DecodeCnt`. The two sums go to `SumLogo` and `SumStats`; the logo's sum is the value the status band prints.

#### Step 2 — The verification decoder

`VerifyStream` is deliberately the slow, obvious decoder. It reads a control byte, tests bit 7 (`TAX` puts the control in X and sets N; `BMI` takes the run path), and then either repeats a value or copies literals into the sum. It stops when `DecodeCnt` reaches `$0240`. At that moment Y equals the stream's length: 214 for the logo, 224 for the byte-count screen. That is the proof that the visible decoder will not read past the stream.

#### Step 3 — VBLANK: SELECT, the stream choice and the pre-decode

The VBLANK code debounces SELECT, loads the active stream's base into `DecodePtr`, copies its length and checksum into the `PackedLen` and `ChecksumVal` variables, and calls `PreDecode`. `PreDecode` decodes **row 0** and leaves X at count − 4 (the remaining bytes minus one), `Mode` set, and Y at the first byte of row 1. The visible loop starts with the row buffer already full.

#### Step 4 — The visible kernel's four row paths

`BodyStart` branches on `Mode` to `LoopRun` or `LoopLit`. Each path writes the three playfield bytes first, then decodes the next row. At the bottom it decrements X by three; `BPL` continues the same token, and the `BPL` fall-through handles the end of a token. The token-end path reads the next control into X with `LAX (DecodePtr),Y`, advances Y and syncs.

#### Step 5 — `LastRow` and the overscan

After 191 loop rows the row counter reaches zero; the 192nd row is displayed by `LastRow`, which writes the final three bytes and syncs. Three `NOP`s put the overscan entry six cycles into line 229, matching the Part 7/8 skeleton. The overscan timer is 36 ticks (the exact 30 lines for this kernel's phase).

#### Step 6 — The stream tables

`LogoStream` and `StatsStream` are page-aligned `!byte` tables. Each token carries a comment with the row range it covers, so the table doubles as a map of the picture: `run x 9 $FF rows 0-2` is the top bar, `lit x 42 rows 28-41` is the "RTB" block, and so on. `LogoPacked = * - LogoStream` and `StatsPacked = * - StatsStream` are the lengths the status band prints, and `!if` guards fail the build if either length changes. The assembler cannot sum the decoded bytes without running the decoder, so the **checksum** guard is the startup pass and the host decode, not an `!if`: a changed sum with an unchanged length fails those checks.

#### Step 7 — The status text is part of the stream

The digits in the status band are ordinary picture rows, encoded as literals like every other detail row. The generator searches for a `(packed, checksum)` pair that the image can truthfully print about itself. The first fixed point found is `(214, $41)`; the status rows are `PK214`, `RW576` and `CK41`, and the startup pass computes `$41` from the same 576 bytes.

#### Step 8 — SELECT and the second stream

A SELECT press toggles the `ScreenNum` variable (the `Screen` checkpoint). The next VBLANK points `DecodePtr` at `StatsStream`, copies `StatsPacked` (224) and `SumStats` (`$DB`) into the `PackedLen` and `ChecksumVal` variables, and pre-decodes the new row 0. The second screen prints `RLE`, `576`, `PK224` and `CKDB`; the kernel does not change at all.

## What You Should See

The logo screen is a black field with a white, reflected playfield. Above the logo are four white bands (rows 0-2, 6-9, 13-14 and 18-23); below it are five more (rows 46-47, 52-55, 59-60, 64-69 and 74-75), then three large status lines: `PK214`, `RW576` and `CK41`. After them come nine bands (rows 126-127, 133-136, 140-141, 147-152, 157-158, 164-167, 171-172, 178-183 and 186-191). In the middle is the bold "RTB" and its mirror "BTR" on the right, because the playfield is reflected. The digits are part of the picture, so every playfield row is mirrored into the right half.

![Stella running the Lesson 61 ROM on the logo screen: a black field with white horizontal bands, a large blocky RTB and its mirror, and the status lines PK214, RW576 and CK41 each shown with its mirror; the title bar reads Stella 7.0: "61-compression"](/images/lesson61/logo.png)

*`logo.png`: the logo screen. The stream is 214 bytes; the picture it rebuilds is 576 bytes; the status band prints both numbers and the checksum `$41`.*

![Stella running the Lesson 61 ROM on the byte-count screen: the words RLE and 576, the status lines PK224 and CKDB, and a band pattern below; the title bar reads Stella 7.0: "61-compression"](/images/lesson61/stats.png)

*`stats.png`: the byte-count screen, selected by holding SELECT at power-on. This stream is 224 bytes and its checksum is `$DB`; the screen prints both.*

<RomPlayer rom="/roms/part8-advanced/61-compression/61-compression.bin" title="Lesson 61 — Compression & Data Encoding" />

Press SELECT to switch between the two screens. Javatari's 4K path runs the ROM in the page; the ROM is silent, so there is nothing to unmute.

The debugger tells the same story as numbers. Break at the labels the source defines:

| Checkpoint | Address | Measured | Meaning |
|---|---|---|---|
| `StartFrame` | `$F0DF` | 259/3 | the first VSYNC instruction |
| `VblankStart` | `$F0ED` | 0/5 | the first VBLANK instruction |
| `BodyStart` | `$F15C` | 37/5 | visible line 0 |
| `OverscanStart` | `$F24B` | 229/6 | the first overscan instruction |
| `Screen` | `$F114` | A = 0 (or 1 with SELECT held) | the active screen |
| `DecodePtrRead` | `$F145` | A = `$00` | the stream base's low byte |
| `RowsLeftRead` | `$F14A` | A = `$BF` (191) | the rows the loop still has to draw |
| `PackedLenRead` | `$F14C` | A = `$D6` (214) / `$E0` (224) | the active stream's length |
| `RawLenRead` | `$F14E` | A = `$40` | the low byte of the 576-byte raw length |
| `ChecksumRead` | `$F150` | A = `$41` / `$DB` | the active stream's decoded sum |
| `RowByte0` | `$F19C` | A = `$FF` on the first two hits (rows 0-1) | the first playfield byte (LoopRun) |
| `RowByte1` | `$F166` | A = `$CF` on row 28 | the second playfield byte (LoopLit) |
| `RowByte2` | `$F16A` | A = `$0E` on row 28 | the third playfield byte (LoopLit) |
| `DecodeCount` | `$F0A7` | A/X = `$02`/`$40`, Y = `$D6` | 576 decoded bytes; Y is the 214-byte stream's end |
| `Checksum` | `$F033` | A = `$41` | the logo stream's decoded sum |

`PackedLenRead`, `RawLenRead` and `ChecksumRead` name the live variables the status band was generated from. They have no job in the visible kernel, so they are read once per frame in VBLANK purely so the debugger can watch them; the three reads cost 9 cycles out of the 2,753-cycle blanking period.

The state log commands used for the evidence:

```bash
ROM=docs/public/roms/part8-advanced/61-compression/61-compression.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0DF' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0ED' $ROM   # VblankStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F15C' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F24B' $ROM   # OverscanStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0A7' $ROM   # DecodeCount
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F033' $ROM   # Checksum
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F114' $ROM   # Screen
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F14C' $ROM   # PackedLenRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F14E' $ROM   # RawLenRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F150' $ROM   # ChecksumRead
stella -audio.enabled 0 -holdselect -dbg.logbreaks 1 -logtoconsole 1 -break '$F114' $ROM
```

The measured runs read `259/3`, `0/5`, `37/5` and `229/6` in that order; the frame is 262 lines. **Both SELECT states were logged**: with and without `-holdselect` the four frame checkpoints read the same values, and `Screen` reads `A=00` or `A=01`. At `DecodeCount` the log shows `A=$02, X=$40, Y=$D6`: 576 bytes decoded and the 214-byte logo stream consumed exactly. The second pass (the byte-count screen) shows `Y=$E0` (224). At `Checksum` the log shows `A=$41`. `PackedLenRead`, `RawLenRead` and `ChecksumRead` read `$D6`, `$40` and `$41` on the logo screen; with `-holdselect` they read `$E0`, `$40` and `$DB`.

::: details The host decode
The same numbers come out of an independent decode from the committed ROM. The logo stream starts at `$F300` (file offset `$0300`) and is 214 bytes; the byte-count stream starts at `$F400` and is 224 bytes.

```python
import re

rom = open('docs/public/roms/part8-advanced/61-compression/61-compression.bin', 'rb').read()

def decode(stream):
    out, p = bytearray(), 0
    while len(out) < 576:
        c = stream[p]; p += 1
        if c & 0x80:
            out += bytes([stream[p]]) * ((c & 0x7f) + 1); p += 1
        else:
            n = c + 1
            out += stream[p:p + n]; p += n
    return bytes(out), p

for name, off, size in (('logo', 0x0300, 214), ('stats', 0x0400, 224)):
    raw, used = decode(rom[off:off + size])
    print(name, 'decoded', len(raw), 'checksum', f'${sum(raw) & 0xff:02X}',
          'stream bytes used', used)
```

It prints `logo decoded 576 checksum $41 stream bytes used 214` and `stats decoded 576 checksum $DB stream bytes used 224`. The debugger's `Checksum` checkpoint says `$41`; the status band prints `CK41`. Three independent paths — the host, the startup pass and the visible decoder — agree.
:::

> **Capture method.** Both images are window captures of
> `docs/public/roms/part8-advanced/61-compression/61-compression.bin` in Stella 7.0.
> `logo.png` was captured with `scripts/capture-screenshot.sh`; `stats.png` used
> the same window-capture pipeline with `-holdselect`, so the second screen is
> the one SELECT selects. The pointer was parked at `(0, 0)` before each capture
> (no cursor appears in either image), and the title bar reads
> `Stella 7.0: "61-compression"` in both. The window is 1010×807; the TIA area is
> 960×606 at `(25, 106)`. The pixel check downsamples the TIA area to the
> logical 160×192 screen and compares it with the host-decoded picture,
> reflection included: **0 mismatching pixels of 30,720** in each image.

## Exercises

### Exercise 1: A 16×8 Sprite Table

**Challenge:** Compress a 16-frame animation of 8×8 sprites with RLE and draw it. The 16 displayed frames are 128 raw bytes; with the one pad frame the table is 136 bytes, and the solution's stream is 66 bytes.

**Hints:**
1. The sprite bytes have no rows or playfield layout: the token format works unchanged, and the counts do not have to be multiples of three.
2. Decode one byte per visible line. The line that has just been drawn no longer needs its old byte, so the decoder can overwrite the same eight-byte buffer slot.
3. Add one pad frame of eight zeros to the table. The pipeline decodes frame 16 during frame 15's lines; the pad gives it valid bytes to read. The pad is never displayed.

**Expected Result:** Sixteen small white frames in a vertical strip at x=76, a ball that falls, squashes and rises; a white bar above them. The 136-byte raw table becomes a 66-byte stream (48.5%) and decodes back to 136 bytes. The frame is 262 lines.

**Runtime check:** the decoder is reset in VBLANK every frame. The `StreamReady` checkpoint reads `Y=04` on every frame (the stream index after the reset and the frame-0 pre-decode); two captures taken a few seconds apart are pixel-identical, and the 128-row strip matches the 16 decoded frames with **0 mismatching pixels of 1,024**. Without the per-frame reset the second video frame would read the `$EA` fill after the 66-byte stream.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: A Different Token Scheme

**Challenge:** Re-encode the lesson's 576-byte picture with a different RLE scheme: a separate opcode byte (`$00` = run, `$01` = literals), a separate count byte (`count-1`), then the value or the literal bytes. Decode it, prove the checksum, and compare the packed size with the lesson's 214 bytes.

**Hints:**
1. The lesson folds the type into bit 7 of the count byte; the new scheme spends a whole byte on the type. Every token grows by one byte.
2. The lesson's stream has 43 tokens, so the new stream should be 214 + 43 = 257 bytes. Check the assembled table before believing the arithmetic.
3. The alternate stream is 257 bytes — one byte longer than a page — so a single 8-bit index wraps. Use a 16-bit pointer and carry Y into the high byte.

**Expected Result:** A screen with a 54-row solid bar (the lesson's 214 bytes at four bytes per scanline) and a 64-row striped bar (the new 257 bytes). The startup checksum is `$41`, the same 576 bytes. The comparison is the lesson: one opcode byte per token costs 43 bytes, about 20%.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: A 2-Bit-Per-Pixel Buffer

**Challenge:** Store a 20×19 picture in 95 bytes at two bits per pixel (96 with the pad byte), look each codeword up in a four-entry dictionary, decompress the picture to 19 playfield rows, and draw it.

**Hints:**
1. Five bytes hold one 20-pixel row: four codewords per byte, bits 7-6, 5-4, 3-2, 1-0 from left to right.
2. The dictionary is four bytes. Codewords 1 and 2 both light a pixel; 0 and 3 leave it dark. On a two-colour object the same table would select the colour.
3. 19 rows × 3 playfield bytes = 57 bytes, which fits in RAM between `$90` and `$C8`, clear of the stack.

**Expected Result:** A white diamond with a checkerboard core, reflected on the right, below a white status bar. The 96 packed bytes decompress to 57 playfield bytes (19 rows × 3), row 0 and row 18 are `00 04 00`, and row 9 is `50 AA 55`. The frame is 262 lines; `OverscanStart` is 229/4 in this exercise (the overscan timer absorbs the two-cycle phase difference and the frame stays 262).

**Runtime check:** the image pointer is set in VBLANK, so the first image row's three stores happen early in its line. The captured first image row shows the single lit chunk at column 9 (`PF1 = $04`), and the 19 image rows match the decompressed picture with **0 mismatching pixels of 760**. Before the pointer was hoisted, the first row still carried the status bar's `$F0/$FF/$FF`.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **RLE buys ROM with CPU time.** The lesson's picture drops from 576 raw bytes to 214 packed bytes (37.2%); the decoder spends the saved bytes back as cycles on every visible line.
- ✅ **The token's top bit is the type.** `1ccccccc` is a run of `c+1` copies of the next byte; `0ccccccc` is `c+1` literal bytes. Folding the type into the count byte is worth one byte per token — 43 bytes on this picture.
- ✅ **A byte run is not a row run.** The token repeats one byte, so only rows whose PF0/PF1/PF2 are equal become runs. Canonicalising a full-width "on" row to `FF FF FF` turns it into one run value.
- ✅ **The row buffer is the whole trick.** Three bytes at `$80-$82` are the only RAM the picture needs; the line displays them and the decoder overwrites them for the next line, in that order, because the playfield writes must beat the beam.
- ✅ **The worst line is exactly 76 cycles.** The literal token's last row costs 3 + 18 + 30 + 6 + 2 + 7 + 7 + 3 = 76; Stella confirms `BodyStart` 37/5 and `OverscanStart` 229/6 with both screens.
- ✅ **The checksum makes the decode checkable.** The startup pass decodes 576 bytes and sums them; the status band prints the sum, the host decode reproduces it, and the `Checksum` checkpoint reads the same `$41`.
- ✅ **Different data wants different encodings.** A 16-frame sprite table compresses 136 → 66 bytes with RLE; a detailed 20×19 picture fits 95 bytes (+1 pad) at two bits per pixel; a separate opcode byte costs 20% more than the folded form.

## What's Next

Lesson 62 turns the tools around. Instead of packing a picture into a stream, you will take a small classic-style game apart with the Stella debugger — its vectors, its frame, its kernel, its data tables and its game logic — and produce an annotated map of how it all works. The decoder you just built is a good first exhibit: you know exactly what every byte in its stream means.
[Lesson 62: Reverse Engineering a Classic Game](/part8-advanced/62-reverse-engineering)
