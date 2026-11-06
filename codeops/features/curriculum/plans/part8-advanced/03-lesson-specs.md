# Lesson Specifications: Part 8 — Advanced Topics (Lessons 56–65)

> **Document**: 03-lesson-specs.md
> **Parent**: [Index](00-index.md)
> **Status**: Frozen for execution
> **Source of truth**: this file + [07-testing-strategy.md](07-testing-strategy.md) + the shipped
> `include/vcs.asm`, `include/macro.asm`, and `include/score.asm`. A claim that disagrees with
> `include/vcs.asm` is wrong.

## Shared Conventions

- **Source shape:** `!cpu 6502`; `!source "include/vcs.asm"`; `!source "include/macro.asm"`;
  the reset entry; `+clean_start` or the documented equivalent; the frame skeleton; the visible
  kernel; the overscan. The main source's header comment carries the RAM map, the build command,
  the run command, the checkpoints, and the measured cycle/line ledgers.
- **ROM names and paths:** `lessons/part8-advanced/NN-slug/NN-slug.asm`,
  `exercise-NN-solution.asm` (buildable) or `demo-NN.asm` (theory); committed under
  `docs/public/roms/part8-advanced/NN-slug/`.
- **ROM sizes:** 4,096 (most), 8,192 (56, 57), 10,240 (60), 16,384 (56 exercise 2). The build
  command and the doc state the actual size. No lesson assumes 4,096.
- **Start banks:** F8/F8SC/DPC start in **bank 1**; F6 starts in **bank 0**. The reset vector in
  the start bank is the one the CPU uses at power-on. A bank that is not the start bank must have a
  valid vector and a switch stub if it can be selected.
- **Cross-bank jumps:** the switch-and-jump stub is duplicated at the same fixed address in every
  bank. The hotspot read, the following JMP fetch, and the target all live in the new bank.
- **Frame:** NTSC 262 lines = 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan. PAL (65 only) 312 =
  3 + 45 + 192 + 72. `StartFrame` 259/3 (NTSC) or 309/3 (PAL); `VblankStart` 0/5;
  `BodyStart` 37/5 (NTSC) or 45/5 (PAL); `OverscanStart` 229 (NTSC) or 301 (PAL). A 4K lesson's
  visible kernel may be shorter than 192 lines only if the spec says so; Part 8 keeps 192.
- **Row loops:** top-down `LDY #0; ...; INY; CPY #N; BNE`; no sentinels.
- **HMOVE:** one per repositioning event; `HMBL`/`HMP0`/`HMP1` writes are followed by a single
  `STA HMOVE`; do not write `HMBL` within 24 cycles of an HMOVE.
- **RAM map:** `$80–$9F` lesson variables; `$A0–$D7` free; `$D8–$F7` free; `$F8–$FF` stack.
  Lesson 59's RAM routine uses `$80–$88`; its variables use `$89–$9F`. Lesson 61's row buffer is
  `$80–$82`, pointers `$83–$86`, counters `$87–$8F`. The Superchip RAM is not RIOT RAM; it lives
  at `$1000–$10FF` (write/read windows).
- **Checkpoints:** `Label:` immediately before the instruction that follows the labelled event;
  a breakpoint reports the first cycle of that instruction. The source header lists every
  checkpoint and its expected value. The doc's checkpoint table quotes the address from the symbol
  file.
- **Screenshots:** two per lesson, captured from the committed ROM via
  `scripts/capture-screenshot.sh`, pointer parked, no cursor, title bar visible. A still proves
  the visual state; the state log proves the transition/clock. Pixel checks use PIL and record
  the geometry.
- **Exercises:** buildable lessons ship three `exercise-NN-solution.asm`, each assembling to the
  declared size and running in Stella. Theory lessons 62–64 have three analysis/production
  exercises answered in the doc; their artifact is `demo-NN.asm`.
- **Docs:** the fixed six-section template with frontmatter, meta block, TypeScript equivalent,
  theory, Full Source verbatim between the markers, Code Walkthrough, What You Should See with
  the two images and `<RomPlayer>`, Exercises, Key Takeaways (≤7), What's Next. The capture method
  and any deviation are disclosed.
- **Integration:** Part 8 index row flips to ✅ in the lesson commit; sidebar entry verified;
  prev/next frontmatter; README row 8 unchanged.

---

## Lesson 56: Bankswitching — Beyond 4KB

- **Goal:** see the 4K window switch between two banks, and learn the rules that keep
  bank-switched code alive.
- **Prerequisites:** Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and
  memory), Lesson 12 (the frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19
  (the playfield), Lesson 25 (players), Lesson 26 (positioning), Lesson 33 (`INPT4` and the fire
  button), Lesson 48 (the kernel taxonomy).
- **Concepts:** the 4K cartridge window; F8 hotspots `$1FF8`/`$1FF9`; the start bank (F8 = bank
  1); the vector table in every bank; the duplicate switch-and-jump stub; code vs data banks; the
  cost of a switch (a read, then a fetch from the new bank); no interrupts on the 2600.
- **ROM:** `56-bankswitching.asm` — **"the two worlds"**, 8,192 bytes, F8.
  - Layout: bank 0 at real `$E000` with `!pseudopc $F000`; bank 1 at real `$F000`. The flat file
    is bank 0 then bank 1. Start bank 1; bank 1's reset vector is used at power-on.
  - Fixed trampoline in both banks: `$F060` = `Switch1` (`LDA $1FF9; JMP $F080`), `$F070` =
    `Switch0` (`LDA $1FF8; JMP $F080`). Both banks' main is `$F080`. The trampoline bytes are
    identical in both banks, so the JMP fetch after the hotspot read is safe.
  - Each bank draws a full 192-line scene with a 1-line kernel and a bank-local 192-byte `PF2`
    table (PF0/PF1 zero, reflected playfield). Bank 1 = a green/blue "forest" with vertical
    pillars; bank 0 = a red/orange "cave" with a different pattern. A small player (P0) sits at a
    fixed X in each scene; one HMOVE per frame.
  - The switch: an auto-demo switches every 120 frames; fire switches immediately; `Bank` (`$80`)
    tracks the current bank. A two-cell indicator in the status row shows the active bank.
  - Frame: 262 lines; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5,
    `OverscanStart` 229/6.
  - RAM: `$80` `Bank` (0/1), `$81` `BankTimer`, `$82` `FrameCount`, `$83` `SwitchFlag`,
    `$84` `PrevFire`, `$85` `NewFire`, `$86` `Startup`, `$87–$9F` free, `$A0–$D7` free,
    `$D8–$F7` free, `$F8–$FF` stack.
  - Checkpoints: `StartFrame`, `VblankStart`, `BodyStart`, `OverscanStart`, `BankEntry` (A = 1 at
    power-on, 0 after a switch), `SwitchRead` (the hotspot read; log the PC/bank), `BankWrite`
    (A = 0/1), `Frame`.
- **Evidence pins:** Stella reports `F8* (8K)`; a breakpoint at the bank's main (`$F080`; the
  labels are `ForestMain`/`CaveMain`) hits first in bank 1; the other bank's main hits after the
  switch; the two captures show the forest and the cave;
  the trampoline bytes at `$F060`/`$F070` are identical in both banks (compare the two 4K halves);
  `Bank`/`BankWrite` A=1 then 0; the frame is 262 lines.
- **Screenshots:** `bank-1.png` (the forest, the indicator on bank 1) and `bank-0.png` (the cave,
  the indicator on bank 0). Capture from the committed ROM; use fire or a short auto-demo wait to
  reach each state. The doc discloses the capture method.
- **Exercises:** (1) swap the scenes (bank 1 = cave, bank 0 = forest; start bank still 1);
  (2) **16K F6**: four 4K banks at real `$C000/$D000/$E000/$F000`, start bank 0, four scenes, the
  hotspots `$1FF6–$1FF9` selected with `LDA $1FF6,X`; (3) a **data bank**: bank 0 holds a
  192-byte `PF2` table and the kernel that draws it; bank 1 holds the frame skeleton and switches
  to bank 0 to draw the data scene, then switches back. The table is read directly in bank 0;
  there is no 192-byte RAM copy. All assemble and run.
- **Integration:** prev 55; next 57; index row 56 ✅; sidebar `config.ts:139`.
- **Risks:** a bank 0 entry never runs (PF-03); the trampoline must be duplicated (PF-14); the
  16K exercise's start bank is 0 (PF-15).

## Lesson 57: Superchip — Extra RAM

- **Goal:** use the 128 bytes of cartridge RAM that the Superchip mapper adds, and understand why
  the first 256 bytes of each bank are special.
- **Prerequisites:** Lesson 03 (memory map), Lesson 04 (registers), Lesson 12 (the frame),
  Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players),
  Lesson 26 (positioning), Lesson 48 (the taxonomy), Lesson 56 (banking).
- **Concepts:** the F8SC mapper; write window `$1000–$107F`, read window `$1080–$10FF`; the first
  256 bytes of each 4K bank hold the duplicated 128-byte signature, so code starts at `$F100`;
  the Stella/Javatari auto-detect signature (the first 128 bytes duplicated at +128); the RAM is
  not zeroed by the 2600; the RAM persists across bank switches; the difference from RIOT RAM.
- **ROM:** `57-superchip.asm` — **"the 128-byte notebook"**, 8,192 bytes, F8SC.
  - Layout: bank 0 at real `$E000` with `!pseudopc $F000`; bank 1 at real `$F000`. Each bank
    starts with `!fill 128, $EA` twice (the signature); code starts at `$F100`. Start bank 1;
    bank 1's reset vector at `$FFFC` points to `$F100`.
  - The demo: a 32-byte message table in ROM is copied one byte at a time into the 128-byte
    Superchip RAM at `$1000 + RamPtr`. Every 8 frames the code writes the next character, reads
    it back from `$1080 + RamPtr`, and updates a
    six-character window shown as two lines of three (4-chunk glyphs; a single 6×4-chunk line is
    24 chunks wide). A 16-cell gauge shows which 8-byte groups of the 128 bytes have been written
    (a cell is lit when any byte in its group has been written). A `Writes`/`Reads` counter
    and a "SC" label.
  - Picture: 8 status lines + 184 play lines. The status shows the gauge; the play shows the
    message and a moving P0 marker. One HMOVE.
  - Frame: 262 lines; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5,
    `OverscanStart` 229/6.
  - RAM: RIOT `$80` `WritePtr`/`RamPtr`, `$81` `MessagePtr`/`MsgPtr`, `$82` `FrameCount`,
    `$83` `WriteCount`/`Writes`, `$84` `ReadCount`/`Reads`, `$85` `GaugeLo`, `$86` `GaugeHi`,
    `$87–$8C` the six-glyph window, `$8D–$9A` `MsgPF0`, `$9B–$A8` `MsgPF1`, `$A9–$AC` scratch and
    the font pointer, `$AD–$D7` free; Superchip `$1000–$107F` write / `$1080–$10FF` read.
  - Checkpoints: the frame labels; `RamWrite` (A = the byte, the address is `$1000+RamPtr`),
    `RamRead` (A = the byte read from `$1080+RamPtr`), `RamPtr`, `MsgPtr`, `Frame`.
- **Evidence pins:** Stella reports `F8SC* (8K)`; a breakpoint at `RamWrite` shows the write, and
  `RamRead` returns the same byte; the first 128 bytes of each 4K bank equal the next 128 (the
  signature); the capture shows the message and the gauge; the frame is 262 lines; Javatari's F8
  (+RAM) path uses the same window (AR-29).
- **Screenshots:** `notebook-a.png` (the first message window, a few gauge cells lit) and
  `notebook-b.png` (after the message scrolls, more cells lit). The doc states that the RAM is
  initialized by the program, not by the console.
- **Exercises:** (1) fill all 128 bytes with a pattern and light all 16 gauge cells; (2) use the
  128 bytes as a sprite/playfield strip and draw it; (3) write a value in bank 1, switch to bank 0,
  read it back, and show that the RAM persists.
- **Integration:** prev 56; next 58; index row 57 ✅; sidebar `config.ts:140`.
- **Risks:** the signature and `$F100` start are mandatory (PF-04); the first 256 bytes hold the
  signature and cannot hold code; the RAM window is `$1000–$10FF` (PF-24).

## Lesson 58: Illegal Opcodes — Undocumented Power

- **Goal:** use the stable undocumented NMOS 6502 instructions where they save cycles, and know
  exactly when not to.
- **Prerequisites:** Lesson 04 (registers and memory), Lesson 06 (flags), Lesson 07 (branches),
  Lesson 09 (bitwise operations), Lesson 10 (addressing modes), Lesson 17 (cycle counting),
  Lesson 25 (players).
- **Concepts:** undocumented opcodes are real NMOS 6502 instructions; the stable set; LAX, SAX,
  DCP, ISB, SLO, RLA, SRE, RRA; the combined operation and the flags; the cycle saving; the
  opcode bytes; ACME's `!cpu 6502` mode rejects the mnemonics while `!cpu 6510` accepts them, so
  the lesson keeps `!cpu 6502` and uses `!byte` macros for byte visibility; the 65C02 difference;
  the risk of unstable opcodes and the "don't use them in portable code" rule.
- **ROM:** `58-illegal-opcodes.asm` — **"the opcode laboratory"**, 4,096 bytes.
  - The screen is a 192-line static lab. Four horizontal rows (32 lines each) show the result of
    four operations as colored bars; the top 48 lines show a title/status and the byte/cycle
    labels. The bars are drawn with the playfield; a small P0 marker selects a row.
  - The operations run once per frame in VBLANK on known inputs; the result bytes and the flags are
    stored and displayed. The source uses named macros:
    `!macro LAX_ZP .addr { !byte $A7, .addr }`, `SAX_ZP` `$87`, `DCP_ZP` `$C7`, `ISB_ZP` `$E7`.
    The doc's table gives the byte, the operation, the flags, and the documented/illegal cycles.
  - The second screen (SELECT) shows the cycle table as bars: documented vs illegal. A checksum
    byte proves the result values.
  - Frame: 262 lines; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5,
    `OverscanStart` 229/6.
  - RAM: `$80` `ResultA`, `$81` `ResultX`, `$82` `ResultM`, `$83` `Flags`, `$84` `Checksum`,
    `$85` `Screen`, `$86–$89` the four display result bytes, `$8A–$8D` the four flag bytes,
    `$8E` the marker row, `$8F` the frame count, `$90–$9A` `LaxMem`–`Tmp`, `$9B–$9C` free,
    `$9D–$9E` the checksum PF bytes, `$9F` free; stack `$F8–$FF`.
  - Checkpoints: `LaxRead`/`SaxRead`/`DcpRead`/`IsbRead` (A = each result), `SaxM`/`DcpM`/`IsbM`
    (A = the memory result), `FlagsRead` (P), `Checksum`, `Screen`, `Frame`.
- **Evidence pins:** the ROM assembles with ACME 0.97; Stella executes LAX/SAX/DCP/ISB without an
  invalid-instruction trap; the captured result colors match the documented values; the checksum
  is stable; the cycle table matches the reference; the doc states the `6502`/`6510` distinction
  and why the macros are used, and shows the bytes.
- **Screenshots:** `lab-a.png` (the four result bars) and `lab-b.png` (the cycle table / second
  screen).
- **Exercises:** (1) replace a `LDA`/`TAX` pair with `LAX` and show A=X and the saved cycle;
  (2) use `DCP` for a countdown and show the memory/flags; (3) use `SAX` to store a mask and
  `LAX` to load it, then display the result. All 4,096.
- **Integration:** prev 57; next 59; index row 58 ✅; sidebar `config.ts:141`.
- **Risks:** the source keeps `!cpu 6502` and uses the `!byte` macros (PF-06); the doc must explain
  the `!cpu 6510` alternative and warn about the 65C02 and unstable opcodes.

## Lesson 59: Self-Modifying Code — The Ultimate 6502 Trick

- **Goal:** copy a routine to RAM, patch its operand at run time, and execute it — the only way to
  self-modify on a cartridge-based 2600.
- **Prerequisites:** Lesson 03 (memory map), Lesson 04 (registers and memory), Lesson 08 (stack
  and subroutines), Lesson 10 (addressing modes), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting),
  Lesson 18 (mid-scanline changes), Lesson 25 (players), Lesson 26 (positioning), Lesson 48
  (the taxonomy).
- **Concepts:** cartridge ROM is read-only; the 128-byte RIOT RAM is executable; copying a routine
  from ROM to RAM; patching an immediate operand or an address operand; `JSR`/`RTS` and the stack;
  the stack overlaps the same 128 bytes; the cycle cost; the difference between self-modifying
  code and a data-driven table; the safety rules (fixed length, known entry, no stack use inside
  the routine).
- **ROM:** `59-self-modifying-code.asm` — **"the code painter"**, 4,096 bytes.
  - A 9-byte routine is copied to `$80`:
    `LDA #$00` (`$80`), `STA COLUBK` (`$82`), `STA WSYNC` (`$85`), `RTS` (`$88`). The main loop
    patches the immediate operand at `$81` from a 192-byte color table, calls `JSR $80`, and
    repeats. The screen is a 192-line color gradient/plasma; the status row shows the current
    patch byte and a generation counter.
  - A second RAM routine at `$90` can be added by exercise 3; the main demo uses the one routine.
  - Frame: 262 lines; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5,
    `OverscanStart` 229/6.
  - RAM: `$80–$88` the routine, `$89` `PatchByte`, `$8A` `CallCount`, `$8B` `Frame`, `$8C–$9F`
    free; stack `$F8–$FF`. The color table is in ROM.
  - Checkpoints: `PatchByte` (A = the new color), `CallCount` (A = the frame's call count),
    `RamRoutine` (the `$80` label; the debugger disassembly shows the copied bytes), `Frame`.
- **Evidence pins:** the copied bytes at `$80` match the source; a breakpoint at `PatchByte`
  reports the changing color; the capture shows the per-line gradient; the state log shows the
  `JSR $80`; the ROM is 4,096; the stack is not corrupted (SP returns to `$FD`/`$FF`).
- **Screenshots:** `painter-a.png` and `painter-b.png` (two gradient phases).
- **Exercises:** (1) patch a delay count in the RAM routine (an `LDX #n` operand); (2) patch a
  pointer operand (`LDA table,X` or `LDA (ptr),Y`) to select another table; (3) copy a second
  routine to `$90`, patch its `STA COLUPF`/`STA GRP0` address, and draw a second object. All
  4,096.
- **Integration:** prev 58; next 60; index row 59 ✅; sidebar `config.ts:142`.
- **Risks:** the routine must not use the stack (PF-07); `+clean_start` zeroes `$80–$FF`, so the
  copy happens after it; the routine must be < 128 bytes and must not overlap the stack.

## Lesson 60: DPC and DPC+ — Enhanced Audio and Graphics

- **Goal:** use the DPC display processor's data fetchers to draw a playfield from a 2K display
  image, understand the 10K image layout, and learn what DPC+ adds.
- **Prerequisites:** Lesson 03 (memory map), Lesson 04 (registers), Lesson 12 (the frame),
  Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players),
  Lesson 28 (one HMOVE), Lesson 48 (the taxonomy), Lesson 56 (banking).
- **Concepts:** the DPC chip in Pitfall II; 8K program + 2K display; the register window
  `$1000–$103F` read / `$1040–$107F` write; the 8 data fetchers; the graphics fetchers DF0–DF2
  and the display image; the counters/top/bottom/flags; the random number generator; the music
  fetchers DF5–DF7; the 10K file layout; the DPC+ ARM coprocessor and why a plain cart cannot
  run it.
- **ROM:** `60-dpc-plus.asm` — **"the display processor"**, 10,240 bytes, DPC.
  - Layout: bank 0 at real `$C000` with `!pseudopc $F000`; bank 1 at real `$D000` with
    `!pseudopc $F000`; display data at real `$E000–$E7FF`. Start bank 1. The first 128 bytes of
    each bank's address space are the DPC register window, so the entry is `$F080`; bank 0's
    `$F080` is a stub that switches to bank 1 (`LDA $1FF9; JMP $F080`).
  - The 2K display image: three 192-byte planes at offsets 0, 683, 1366. DF0/1/2 counters start
    at 2047, 1364, 681. Each line: `LDA $1008` (DF0), `STA PF0`; `LDA $1009` (DF1), `STA PF1`;
    `LDA $100A` (DF2), `STA PF2`; `STA WSYNC`. The picture is a tunnel/starfield with a "DPC"
    logo. The RNG (`LDA $1000`) twinkles stars.
  - Register table (write): the function is `(address >> 3) & 7` and the index is `address & 7`.
    DF0 top `$1040`, bottom `$1048`, counter low `$1050`, high `$1058`; DF1 top `$1041`, bottom
    `$1049`, counter low `$1051`, high `$1059`; DF2 top `$1042`, bottom `$104A`, counter low
    `$1052`, high `$105A`. RNG reset `$1070`. Music: DF5 top `$1045`, bottom `$104D`, counter low
    `$1055`, high `$105D` (bit 4 = music mode); amplitude read `$1005`; DF6/7 shift by one address.
  - Frame: 262 lines; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5,
    `OverscanStart` 229/6. The kernel is a 1-line loop; the DPC reads are 4 cycles.
  - RAM: RIOT `$80` `Frame`, `$81` `StarPtr`, `$82` `Twinkle`, `$83` `Rng`, `$84–$9F` free;
    stack `$F8–$FF`. The DPC registers and display are not RAM.
  - Checkpoints: `Reset` `$F080`, `Main`, `Line`, `Fetch0/1/2` (A = the fetched byte), `RngRead`
    (A = the random byte), `Frame`.
- **Evidence pins:** Stella reports `DPC* (10K)`; the program counter starts at `$F080`; the three
  fetchers return the three plane bytes; the captured picture shows the playfield/starfield; the
  DPC debugger tab (Stella) shows the counters; the frame is 262 lines; the doc's DPC+ section
  cites the ARM/Harmony model and does not claim a build.
- **Screenshots:** `dpc-a.png` and `dpc-b.png` (two RNG/twinkle phases; the playfield is the same).
- **Exercises:** (1) change the display image to a different tunnel; (2) use the RNG to draw a
  starfield; (3) use a music fetcher: set top/bottom, enable music mode, read the amplitude, and
  write `AUDV0`; or add a fourth graphics fetcher. All 10,240.
- **Integration:** prev 59; next 61; index row 60 ✅; sidebar `config.ts:143`.
- **Risks:** the DPC image must be exactly 10,240 (PF-05, PF-23); the register table is easy to
  misread (PF-10); the music fetcher is optional but the main demo uses the graphics fetchers.

## Lesson 61: Compression & Data Encoding — Fitting More in 4KB

- **Goal:** store a detailed picture in a fraction of its raw size and decompress it on the fly.
- **Prerequisites:** Lesson 03 (memory map), Lesson 04 (registers), Lesson 09 (bitwise), Lesson 10
  (addressing), Lesson 11 (lookup tables), Lesson 12 (the frame), Lesson 14 (`WSYNC`), Lesson 17
  (cycle counting), Lesson 19 (the playfield), Lesson 48 (the taxonomy).
- **Concepts:** RLE; the token format; a 3-byte row buffer; on-the-fly decompression; the
  cycle/space trade-off; a checksum; bit packing; the difference between a run and a literal.
- **ROM:** `61-compression.asm` — **"the compressed logo"**, 4,096 bytes.
  - A 192-row playfield image (3 bytes/row = 576 bytes) is stored RLE-compressed. The decoder
    emits 3 bytes per row into `$80–$82` and writes PF0/PF1/PF2 each line. The picture is a large
    "RTB" logo / a detailed pattern; the status row shows the packed size, the raw size, and a
    checksum. SELECT shows the byte-count screen.
  - RLE format: a control byte; bit 7 = 1 means a run (low 7 bits = count-1, next byte = value);
    bit 7 = 0 means literals (low 7 bits = count-1, next `count` bytes). The decoder is a small
    state machine with a row buffer.
  - Frame: 262 lines; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5,
    `OverscanStart` 229/6.
  - RAM: `$80–$82` `RowBuf`; `$83–$84` `DecodePtr`; `$85` `RowsLeft`; `$86` `PackedLen`;
    `$87` `RawLen`; `$88` `Checksum`; `$89` `Screen`; `$8A–$9F` free; stack `$F8–$FF`.
  - Checkpoints: `DecodePtr`, `RowsLeft`, `RowByte0/1/2`, `DecodeCount`, `Checksum`, `Screen`.
- **Evidence pins:** the compressed stream is smaller than 576 bytes; the decoded 576 bytes match
  the raw image (a checksum); the capture shows the logo; the frame is 262 lines; the decoder
  never reads past the stream or writes past the row buffer.
- **Screenshots:** `logo.png` and `stats.png` (the logo and the byte-count screen).
- **Exercises:** (1) compress a 16×8 sprite table with RLE and draw it; (2) implement a different
  RLE token scheme and compare the packed size; (3) a 2-bit-per-pixel dictionary/bit-packing
  scheme for a 96-byte buffer. All 4,096.
- **Integration:** prev 60; next 62; index row 61 ✅; sidebar `config.ts:144`.
- **Risks:** the decoder must be exactly bounded; the row buffer is only 3 bytes; the checksum
  must cover the decoded bytes, not the packed stream.

## Lesson 62: Reverse Engineering a Classic Game

- **Goal:** take a small classic-style ROM apart with the Stella debugger and produce an annotated
  map of its vectors, frame, kernel, data, and game logic.
- **Prerequisites:** Lesson 02 (the Stella debugger), Lesson 03 (the anatomy), Lesson 04
  (registers and memory), Lesson 12 (the frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting),
  Lesson 19 (the playfield), Lesson 25 (players), Lesson 26 (positioning), Lesson 39 (the score
  kernel), Lesson 48 (the taxonomy).
- **Concepts:** the reset/NMI/IRQ vectors; the init; VSYNC/VBLANK/kernel/overscan; the row loop;
  the data tables; the RAM variables; the collision; the score; the disassembler; the debugger's
  breakpoints, watches, and RAM/ROM views; a repeatable reverse-engineering method.
- **ROM:** `demo-62.asm` — **"Wall Buster"**, 4,096 bytes. A small Breakout-style game: a paddle,
  a ball, a 6×4 brick wall, a score, a life counter, and a game-over/restart. The game is
  intentionally simple but complete; the source is fully commented so the doc can annotate it.
  SELECT toggles a **debug overlay**: the background changes per zone (VBLANK/kernel/overscan) and
  the current kernel row is drawn as a bar. The overlay is the visual evidence of the frame.
  - Frame: 262 lines; 3 + 37 + 192 + 30; `StartFrame` 259/3, `VblankStart` 0/5,
    `BodyStart` 37/5, `OverscanStart` 229/6.
  - RAM: `$80` `PaddleX`, `$81` `BallX`, `$82` `BallY`, `$83` `BallDX`, `$84` `BallDY`, `$85`
    `Score`, `$86` `Lives`, `$87` `State`, `$88` `Overlay`, `$89–$9F` free; stack `$F8–$FF`.
  - Checkpoints: the frame labels; `KernelRow` (Y = 0..191); `BallMove` (A = the new X/Y);
    `HitBrick` (A = the brick index); `ScoreWrite` (A = the score); `Overlay`.
- **Evidence pins:** the ROM runs; the debug overlay shows the four zones; the symbol file gives
  the addresses the doc quotes; the disassembly excerpt matches the source; the state log shows
  the ball and score changing; the capture shows the game and the overlay.
- **Screenshots:** `game.png` (the game) and `overlay.png` (the debug overlay).
- **Exercises (analysis, answered in the doc):** (1) find the reset vector, the frame entry, and
  the kernel row loop; (2) locate the ball X/Y variables and the collision test; change the ball
  speed and explain the effect; (3) annotate the score routine and the brick table.
- **Integration:** prev 61; next 63; index row 62 ✅; sidebar `config.ts:145`.
- **Risks:** no copyrighted ROM; the demo must be genuinely complete enough to reverse; the doc
  must not pretend the game is a historical classic.

## Lesson 63: Modern Homebrew — Dev Carts and Community

- **Goal:** understand the modern 2600 homebrew pipeline and build a polished attract mode that
  demonstrates the production values the community expects.
- **Prerequisites:** Lesson 03 (the anatomy), Lesson 04 (registers), Lesson 12 (the frame),
  Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players),
  Lesson 26 (positioning), Lesson 39 (the score kernel), Lesson 41 (game states), Lesson 48
  (the taxonomy), Lesson 53 (kernel patterns), Lesson 55 (text).
- **Concepts:** Harmony and UnoCart flash carts; the AtariAge community; homebrew contests and
  awards; publishing/distribution (ROM sales, physical carts, licensing); the modern toolchain
  (batari Basic, 8bitworkshop, Stella, ACME); an attract mode as a production-value showcase;
  the difference between a tech demo and a shippable game.
- **ROM:** `demo-63.asm` — **"the attract mode"**, 4,096 bytes. A title screen with a large
  playfield logo, a starfield, a color-cycling border, a scrolling message, and a short TIA tune;
  fire shows a credits screen; SELECT returns to the title. The demo reuses the Part 7 starfield
  and text ideas in a compact form.
  - Frame: 262 lines; 3 + 37 + 192 + 30; `StartFrame` 259/3, `VblankStart` 0/5,
    `BodyStart` 37/5, `OverscanStart` 229/6.
  - RAM: `$80` `Scene`, `$81` `Frame`, `$82` `Scroll`, `$83` `TunePtr`, `$84` `TuneTimer`,
    `$85–$9F` free; stack `$F8–$FF`.
  - Checkpoints: `Scene` (A = 0/1), `Scroll` (A = the offset), `TunePtr`, `Frame`.
- **Evidence pins:** the title and credits captures; the state log shows the scene change and the
  scroll; the tune writes `AUDV0`/`AUDF0`; the frame is 262 lines; the ROM is 4,096.
- **Screenshots:** `title.png` and `credits.png`.
- **Exercises (production, answered in the doc):** (1) change the logo and message; (2) add a
  second attract screen (a high-score or instructions screen); (3) add a high-score table and a
  reset. The demo is the artifact; the exercises describe the changes and the ROM has the hooks.
- **Integration:** prev 62; next 64; index row 63 ✅; sidebar `config.ts:146`.
- **Risks:** the 4K budget; the starfield/text tables must fit; the tune is short; the doc must
  avoid unsourced claims about specific community events.

## Lesson 64: Building Your Own Cartridge — From ROM to Physical Cart

- **Goal:** turn a `.bin` into a physical cartridge and verify it with a burn-in test ROM.
- **Prerequisites:** Lesson 03 (the anatomy), Lesson 04 (registers), Lesson 12 (the frame),
  Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players),
  Lesson 48 (the taxonomy), Lesson 56 (banking).
- **Concepts:** the cartridge PCB; the ROM chip (SST39SF010A); the TL866II Plus programmer and
  adapter; the socket/shell; soldering; the label; the burn-in test; the difference between a
  flash cart (Harmony/UnoCart) and a production cart; the ROM size/mapper; the power-on test.
- **ROM:** `demo-64.asm` — **"the burn-in test"**, 4,096 bytes. A test screen with:
  a color-bar pattern; a ROM checksum (computed at runtime over the 4K image, shown as four hex
  digits); a RIOT RAM test (write/read `$A5`/`$5A`, pass/fail); a joystick/switch test (raw
  `SWCHA`, `SWCHB`, `INPT4` bits); a frame counter; and a "CARTRIDGE TEST" label. SELECT cycles
  the test pages.
  - Frame: 262 lines; 3 + 37 + 192 + 30; `StartFrame` 259/3, `VblankStart` 0/5,
    `BodyStart` 37/5, `OverscanStart` 229/6.
  - RAM: `$80` `Checksum` (2 bytes), `$82` `RamResult`, `$83` `Page`, `$84` `Frame`, `$85`
    `Swcha`, `$86` `Swchb`, `$87` `Inpt4`, `$88–$9F` free; stack `$F8–$FF`.
  - Checkpoints: `ChecksumRead` (A = the low/high byte), `RamResult`, `Page`, `Frame`.
- **Evidence pins:** the checksum matches an independent calculation over the committed ROM; the
  RAM test passes in Stella; the controller bits change with `-holdjoy0`; the capture shows the
  test screen and the controller page; the frame is 262 lines.
- **Screenshots:** `burn-in.png` and `controller.png`.
- **Exercises (production, answered in the doc):** (1) add the checksum; (2) add the RAM test;
  (3) add the controller test. The demo includes the reference implementations.
- **Integration:** prev 63; next 65; index row 64 ✅; sidebar `config.ts:147`.
- **Risks:** the checksum must include the vectors; the test must be honest about emulator vs real
  hardware; the doc must not claim a physical build was performed in this repository.

## Lesson 65: PAL/NTSC Universal ROM — One Cart, Every TV

- **Goal:** ship one ROM that runs correctly on NTSC and PAL consoles by selecting the frame timing
  at the title screen, and understand why software cannot auto-detect the TV system on a stock
  2600.
- **Prerequisites:** Lesson 03 (the anatomy), Lesson 04 (registers), Lesson 12 (the frame),
  Lesson 14 (`WSYNC`), Lesson 15 (the RIOT timer), Lesson 17 (cycle counting), Lesson 19
  (the playfield), Lesson 25 (players), Lesson 26 (positioning), Lesson 48 (the taxonomy).
- **Concepts:** NTSC 262 lines/60 Hz vs PAL 312 lines/50 Hz; the 192-line picture with different
  VBLANK/overscan padding; the color palettes (128 vs 104); why software-only auto-detection is
  impossible (same clock, ~1% crystal difference); the Harmony/Melody ARM timer exception; the
  Color/BW-switch practice; a title-screen selector; PAL-60.
- **ROM:** `65-pal-ntsc-universal.asm` — **"the world traveler"**, 4,096 bytes.
  - The title screen asks NTSC or PAL; up/down selects, fire starts. `TVMode` 0 = NTSC, 1 = PAL.
    The frame uses `FrameLines` = 262 or 312; `BodyStart` 37 or 45; `OverscanStart` 229 or 301;
    the visible kernel is 192 lines in both modes.
  - The picture: a color-bar test, a moving bar, a "NTSC"/"PAL" label, and a frame counter.
    SELECT shows the timing page (line count, frame count, color count).
  - Frame: NTSC 3 + 37 + 192 + 30 = 262; PAL 3 + 45 + 192 + 72 = 312.
  - RAM: `$80` `TVMode`, `$81` `FrameLines`, `$82` `Frame`, `$83` `BarX`, `$84` `Screen`,
    `$85–$9F` free; stack `$F8–$FF`.
  - Checkpoints: `TVMode` (A=0/1), `FrameLines` (A=262/312), `Frame`, `BodyStart` 37/45,
    `OverscanStart` 229/301, `StartFrame` 259/309.
- **Evidence pins:** the NTSC capture and the PAL capture (or the selector + one mode); the state
  log shows 262/312 and 37/45 and 229/301; Stella runs the ROM with `-pal` and the PAL mode; the
  doc states that a stock 2600 cannot auto-detect and that Harmony/Melody can.
- **Screenshots:** `selector.png` and `pal.png` (or `ntsc.png`); the doc shows both modes.
- **Exercises:** (1) default to PAL with a compile-time flag; (2) add PAL-60 (262 lines, PAL
  colors); (3) a color-bar test for both palettes. All 4,096.
- **Integration:** prev 64; next (Part 9's Lesson 66); index row 65 ✅; sidebar `config.ts:148`.
- **Risks:** the PAL/NTSC claim (PF-01); the frame padding (PF-18); the color mapping (PF-17).

---

## Cross-Lesson Evidence Summary

| Lesson | Mapper/Size | Core evidence | Captures |
| --- | --- | --- | --- |
| 56 | F8 / 8,192 | bank 1 at power-on, switch to bank 0, identical trampolines | forest, cave |
| 57 | F8SC / 8,192 | `$1000` write, `$1080` read, signature, code `$F100` | notebook A/B |
| 58 | 4K | LAX/SAX/DCP/ISB results, checksum, cycle table | lab A/B |
| 59 | 4K | routine at `$80`, patched operand, gradient | painter A/B |
| 60 | DPC / 10,240 | bank 1/`$F080`, DF0/1/2 fetch, RNG, 2K display | dpc A/B |
| 61 | 4K | RLE decode, row bytes, checksum, packed/raw size | logo, stats |
| 62 | 4K | game, overlay, symbol map, disassembly | game, overlay |
| 63 | 4K | attract mode, scroll, tune, scene change | title, credits |
| 64 | 4K | checksum, RAM test, controller bits | burn-in, controller |
| 65 | 4K / 262-312 | TVMode, FrameLines, BodyStart, OverscanStart | selector, PAL |
