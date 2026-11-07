---
title: "Lesson 64: Building Your Own Cartridge — From ROM to Physical Cart"
description: "Build a 4,096-byte cartridge burn-in test — eight colour bars, a runtime 16-bit ROM checksum over the whole image including the vectors, a RIOT RAM PASS/FAIL test, a raw controller page for SWCHA, SWCHB and INPT4, and a frame counter — and learn the physical cartridge pipeline: the PCB, the SST39SF010A flash chip, the TL866II Plus programmer and adapter, the socket and shell, soldering, the label, the burn-in test, and the difference between a flash cart and a production cart."
prev:
  text: "Lesson 63: Modern Homebrew — Dev Carts and Community"
  link: "/part8-advanced/63-modern-homebrew"
next:
  text: "Lesson 65: PAL/NTSC Universal ROM — One Cart, Every TV"
  link: "/part8-advanced/65-pal-ntsc-universal"
---

# Lesson 64: Building Your Own Cartridge — From ROM to Physical Cart

> **Part 8: Advanced Topics** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and memory), Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 18 (mid-line changes), Lesson 19 (the playfield), Lesson 25 (players), Lesson 39 (the score kernel), Lesson 48 (the kernel taxonomy), Lesson 55 (the text window), Lesson 56 (bankswitching), Lesson 63 (the score library)
> **You will learn:** how a `.bin` becomes a physical cartridge; what the cartridge PCB and the ROM chip do; how an SST39SF010A flash chip is programmed on a TL866II Plus; why a 4K image needs no mapper; how a burn-in test proves the ROM, the RAM, the controllers, and the frame; and why a flash cart is a development tool while a production cart is one ROM on a PCB
> **You will build:** "the burn-in test" — a 4,096-byte ROM with two SELECT pages: eight colour bars, a runtime 16-bit checksum of the whole 4,096-byte image (vectors included) shown as four hex digits, a RIOT RAM PASS/FAIL test, a frame counter, CART and TEST labels, and a controller page with the raw `SWCHA`, `SWCHB` and `INPT4` bits and the named directions and switches

## Introduction

Every lesson so far ended at a `.bin`. This one starts there. A cartridge is not a file: it is a printed circuit board with a ROM chip, an edge connector, a shell, and a label, and the `.bin` is the data you burn into the chip. The gap between the two is small enough for one person to cross — a 4K image, a flash chip, a programmer, and a test ROM — and that is the pipeline this lesson teaches.

The artifact is **"the burn-in test"**, a 4,096-byte ROM you run first on a freshly built cartridge. It checks the things that actually fail: the ROM data (a 16-bit checksum of the whole image, including the three vectors), the console's 128 bytes of RIOT RAM (a write/read of `$A5` and `$5A`), the controllers (the raw `SWCHA`, `SWCHB` and `INPT4` bits and the named directions and switches), and the frame (262 lines, with a frame counter on screen). SELECT switches between the burn-in page and the controller page. The checksum is computed at run time, so it is a test of the cartridge the console is reading, not a number copied from a build log: the host-side checksum of the committed `.bin` and the four digits on screen are the same value.

The lesson is honest about the physical boundary. The repository has **not** built a cartridge; there is no burner, no shell, and no photograph of a physical board in the deliverable. What the repository can verify is the ROM, the test screen, the checksum, and the state of the console as Stella runs it. The build procedure — PCB, chip, programmer, socket, shell, label, power-on test — is the part a builder performs with the same `.bin`. The lesson states which claims are observed in Stella, which are documented hardware facts, and which are procedure.

::: details TypeScript Equivalent

A burn-in test is a small state machine plus three pure functions. In TypeScript you would model the ROM, the sum, the RAM test, and the input masks directly:

```typescript
type Page = 'burn-in' | 'controller';

interface CartTest {
  page: Page;
  frame: number;
  checksum: number;    // 16 bits, high byte displayed first
  ramResult: 0 | 1;    // 0 = pass, 1 = fail
  swcha: number;       // active low
  swchb: number;       // active low
  inpt4: number;       // bit 7 = fire
  prevSelect: boolean; // the SELECT level last frame
}

function checksum(rom: Uint8Array): number {
  let sum = 0;
  for (const byte of rom) sum = (sum + byte) & 0xFFFF;
  return sum;
}

function ramTest(ram: Uint8Array, at: number): 0 | 1 {
  const pattern = [0xA5, 0x5A, 0xA5, 0x5A];
  for (let i = 0; i < 4; i++) ram[at + i] = pattern[i];
  for (let i = 0; i < 4; i++) if (ram[at + i] !== pattern[i]) return 1;
  return 0;
}

function step(t: CartTest, selectPressed: boolean): void {
  t.frame = (t.frame + 1) & 0xFF;
  if (selectPressed && !t.prevSelect) {
    t.page = t.page === 'burn-in' ? 'controller' : 'burn-in';
  }
  t.prevSelect = selectPressed;
}

function readInputs(t: CartTest, portA: number, portB: number, portC: number): void {
  t.swcha = portA;       // 0 = pressed, both joysticks
  t.swchb = portB;       // 0 = pressed, console switches
  t.inpt4 = portC & 0x80; // only bit 7 is defined
}
```

The analogy breaks in five places that matter on a 2600. First, the checksum is not a startup function: the 6507 has 76 cycles per scanline and the VBLANK is 37 lines, so the 4,096-byte read is split into 64-byte chunks across 64 frames, and the four SUM cells stay blank until the last chunk. Second, `ramTest` cannot use a normal array: the 128 bytes at `$80–$FF` are the only RAM, the stack shares them, and the test must run before the program trusts its own variables. Third, the raw `SWCHA` and `SWCHB` values are **active low** and `INPT4` returns only bit 7 reliably; the low seven bits of `INPT4` are not a value you can display. Fourth, a TypeScript `Page` is a variable; the 2600 page is a byte in RAM, switched by a SELECT edge, and the display is a kernel that draws every scanline in real time. The fifth difference is the physical cartridge: the ROM is read-only, the mapper is fixed by the board, and the `.bin` has to survive a burn and a console before any of this code runs.

:::

## Theory

### Section 1: What a Cartridge Is

The 2600 has **no framebuffer, no operating system, and no disk**. The CPU starts at the address in the reset vector, and that address is in the cartridge. The cartridge is the whole program: a ROM chip wired to the console's address bus, data bus, and control lines. The 6507 has 13 address lines, so it can address 8 KB, but the console's address decode puts the TIA and RIOT in the low addresses and the cartridge in the **4 KB window at `$F000–$FFFF`**. The last six bytes of that window, `$FFFA–$FFFF`, are the three vectors: NMI, RESET, and IRQ. A 4K image is exactly 4,096 bytes, and its reset vector is the first thing the console uses.

A **4K cartridge** is therefore the simplest possible board: a ROM chip, an edge connector, and a decoupling capacitor. The edge connector carries the address lines (A0–A11 to the ROM, with A12 available to the board's decode), the eight data lines (D0–D7), +5 V, and ground. The console's address decode uses A12 to select the cartridge when the address is in `$F000–$FFFF`; the board maps A0–A11 to the ROM, and the ROM drives the data bus with the byte at that address. There is no mapper, no register, and no hotspot: every address in the window is a ROM byte. That simplicity is why the burn-in test is 4K. It runs on any 2600 and needs no mapper, which makes it the easiest board to build.

| Part | What it does | What the builder chooses |
|---|---|---|
| PCB | the edge connector, the ROM footprint, the decoupling capacitor | a 4K board (the simplest), or a mapper board for a bigger game |
| ROM chip | stores the 4,096 bytes and drives the data bus | a flash chip such as the SST39SF010A |
| Edge connector | the gold-plated contacts that mate with the console | bevelled fingers, the right thickness |
| Shell | protects the board and holds the label | an Atari-style shell |
| Label | names the cartridge | the title, the author, the year, the region |

The cartridge window is not the only constraint. The 6507 runs at about **1.19 MHz**, so one CPU cycle is roughly 840 ns, and the ROM must drive the data bus inside that cycle. A modern flash chip's access time is far below that, which is why a slow-looking 1980s console can use a 1990s flash part. The console does not know what kind of memory it is reading; it only sees a byte on the bus at the right time.

::: tip The ROM is the contract
Every stage of the pipeline consumes the same three facts: the image is **4,096 bytes**, the **reset vector** points at the start, and the mapper is **4K**. The programmer writes those bytes; the console reads them; the emulator loads them. If the image is 4,095 bytes, or the vector is wrong, or the programmer puts the image at the wrong offset, the cartridge fails the same way a bad build fails in Stella: no boot. The burn-in test makes that failure visible instead of mysterious.
:::

### Section 2: The ROM Chip — SST39SF010A

The **SST39SF010A** is a 5 V flash memory: **128 KB x 8 bits = 1 Mbit**. It comes in a 32-pin DIP, a 32-pin PLCC, and a 32-pin TSOP. A 4K image uses 4,096 of its 131,072 bytes — about **3 percent** of the chip. The rest is unused, which is normal for a small 2600 game: the chip is chosen because it is available, 5 V, and programmable, not because the game needs a megabit.

The board ties the chip's address lines to the console's A0–A11 and leaves the higher address lines at a fixed level, so the console's 4K window maps onto the first 4 KB of the chip. The image is loaded at offset 0. If the programmer insists on a full-chip image, pad the file to 131,072 bytes with `$FF`; the console still sees only the first 4,096 bytes, and the padding never reaches the data bus.

| Fact | Value | Kind |
|---|---|---|
| Capacity | 131,072 bytes (1 Mbit) | documented (chip datasheet) |
| Supply | 5 V | documented |
| Packages | DIP-32, PLCC-32, TSOP-32 | documented |
| Image used by this lesson | 4,096 bytes (3.1 % of the chip) | derived (4,096 / 131,072) |
| Access time | far below the 6507's ~840 ns cycle | documented / derived |

The chip is **flash**, not mask ROM. That matters to a homebrew author: you can erase it and burn a new image, and a socket lets you do that without desoldering. A production run may use a mask ROM or a one-time-programmable part to save cost, but the `.bin` is the same; only the burning step changes.

### Section 3: The Programmer — TL866II Plus and the Adapter

A **device programmer** is the bridge between a file and a chip. The **TL866II Plus** is a USB programmer with a 40-pin ZIF socket and software that erases, writes, and verifies a long list of parts, including the SST39SF010A. The DIP-32 package fits the ZIF socket directly. The PLCC-32 package needs a **PLCC-32-to-DIP-32 adapter**, and the TSOP package needs a different adapter; the adapter is part of the bill of materials, not an afterthought.

The programming cycle has three steps, and the third is the one that matters:

1. **Erase** the chip (flash needs the target area blank).
2. **Write** the image at offset 0.
3. **Verify** by reading the chip back and comparing it with the file.

A verify that passes means the programmer read the same bytes it wrote. It does **not** mean the console will read them: the board, the edge connector, the console's address decode, and the ROM's select logic are still untested. That is what the burn-in test adds. The two checks are complementary: the programmer proves the chip, the console proves the cartridge.

::: tip The adapter is part of the recipe
A PLCC chip in a DIP socket does not fit, and a TSOP chip does not fit either. The adapter's pinout is mechanical as well as electrical. Check the programmer's supported-parts list for the exact package and adapter before you buy the chip; the adapter can be the difference between a working cartridge and a drawer of unprogrammed parts.
:::

### Section 4: The Socket, the Shell, and the Label

A **socket** is optional but useful: it lets you pull the ROM and reflash it without desoldering. A **direct-soldered** chip is cheaper and mechanically stronger, and it is what many production runs do. Either way, the board must fit the shell, the edge connector must be clean and bevelled, and the label must sit on the shell without covering the connector.

The **shell** is the plastic case: two halves, a screw, and a slot for the board's edge connector. The **label** is the visible part of the product: the title, the author, the year, and the region. The region matters because a 2600 cartridge is not automatically PAL/NTSC universal, so the label should say which TV system the cartridge targets. A label is not a technical artifact, but it is part of the release, and a cartridge without one looks like a prototype.

**Soldering** is the step that turns parts into a board. The rules are ordinary 5 V CMOS care: work on a grounded mat, use a temperature-controlled iron, keep the joints short and shiny, inspect with magnification, and test for bridges between the address and data pins before powering the console. A socket is more forgiving; a direct-soldered chip is not.

### Section 5: The ROM Size and the Mapper

The cartridge window is 4 KB, and this lesson's image is exactly **4,096 bytes**. There is no mapper: the board is a ROM and an edge connector. That is a deliberate choice, not a limitation of the lesson. A bigger game needs a mapper — F8 (8K), F6 (16K), DPC, or Superchip — and Lesson 56 shows how the hotspot read switches banks. A mapper board adds a logic chip and a different PCB, and the `.bin` grows. The burn-in test stays 4K because a 4K image runs on every 4K board, every flash cart, and every console; it is the common denominator of the cartridge world.

| Image size | Mapper | What the board adds | Lesson |
|---|---|---|---|
| 4,096 | none (4K) | nothing: ROM + connector | this lesson |
| 8,192 | F8 | a bank-select latch | 56 |
| 8,192 | F8SC | F8 plus 128 bytes of RAM | 57 |
| 16,384 | F6 | four banks, hotspots `$1FF6–$1FF9` | 56 (exercise) |
| 10,240 | DPC | the DPC display processor | 60 |

The **vectors** are part of the image, not a separate file. The reset vector at `$FFFC/$FFFD` points at the program's entry point. If the programmer writes the image at the wrong offset, or the image is short, the vector is not where the CPU looks, and the console does nothing. The burn-in checksum includes `$FFFA–$FFFF` for exactly this reason: a corrupt vector is the first failure a cartridge can have.

### Section 6: The Burn-In Test

A **burn-in test** is a program you run first, before the game. It answers four questions:

1. **Did the ROM survive?** The 16-bit checksum reads all 4,096 bytes of the image — including the three vectors — and compares the sum with a value computed outside the console. A mismatch means a bad burn, a wrong file, a bad socket, or a bad board.
2. **Does the console's RAM work?** The RIOT's 128 bytes at `$80–$FF` are the only RAM. The test writes `$A5` and `$5A` to four free bytes and reads them back. A stuck bit shows as FAIL.
3. **Do the controllers reach the program?** `SWCHA` (both joysticks), `SWCHB` (the console switches), and `INPT4` (player 0 fire) are read every frame. The controller page shows the raw bits and the named directions and switches. `SWCHA` and `SWCHB` are **active low**: a pressed direction or switch reads 0, and the display shows the pressed state.
4. **Is the frame stable?** The program draws 262 lines — 3 VSYNC, 37 VBLANK, 192 picture, 30 overscan — and counts frames. A stable picture on a real TV and a counter that advances prove the timing.

The test is deliberately **not** a game. It has no title screen, no score, and no sound. It is a piece of test equipment, and its value is that it is boring: the same bars, the same digits, the same PASS, every time. If the checksum changes, something changed in the cartridge. If the frame rolls, the timing changed. If the controller page does not react, the input path is broken.

::: tip Why a checksum and not a CRC
A 16-bit sum is not a CRC: it cannot detect every possible corruption, and two different images can share a sum. It is enough for a burn-in test because the failures it catches — a blank chip, a wrong image, a byte that did not program, a vector at the wrong address — change the sum. The host-side check and the runtime check use the same algorithm, so the comparison is exact. If you want a stronger check, use a CRC-16 in both places; the pipeline is the same, and the display already has four hex digits.
:::

### Section 7: Flash Cart vs Production Cart

A **flash cart** — Harmony, UnoCart — is a reusable cartridge with its own firmware and a menu. It reads a ROM image from an SD card and presents it to the console as a cartridge. It is a development and play tool: you can try a new `.bin` without burning a chip, and you can carry a library on one cart. It is **not** a production cartridge: it is reusable, menu-driven, and it is not the object you sell.

A **production cartridge** is one ROM on one PCB in one shell with one label. It is what a customer buys. The two share the `.bin`: the same image that runs from the flash cart is the image the programmer burns. The flash cart is how you test before the burn; the production cart is how you ship after it. The burn-in test runs on both: on a flash cart it tests the console, and on a production cart it tests the cart.

| | Flash cart | Production cart |
|---|---|---|
| Reusable | yes | no: one image |
| Menu | yes | no: the console boots the ROM |
| Purpose | development, play, a library | a release |
| Includes the PCB/shell/label | the flash cart's own | the builder's |
| Tested by | the same burn-in ROM | the same burn-in ROM |

### Section 8: The Power-On Test

The power-on test is the last step and the simplest: insert the cartridge, power on the console, and watch. The four SUM cells stay blank for the first 64 frames (about one second) while the chunks are added, then the four hex digits appear. The RAM line shows PASS. The frame counter advances. Press SELECT: the controller page appears. Move the joystick: the matching `SWCHA` blocks clear (the RLDU legend names the directions in block order). Hold fire: the leftmost `INPT4` block clears. Press RESET: the console restarts the ROM, and the SUM cells start blank again.

If the checksum is wrong, stop: the cartridge is not the image you think it is. If the RAM fails, the console's RIOT is suspect (or the test's scratch bytes collide with the program). If the controller page does not react, check the controller and the port before blaming the cartridge. If the frame rolls, the ROM is drawing a different number of lines than the TV expects — a timing bug, not a burn bug.

::: tip The repository's boundary
This repository ships the ROM, the source, the screenshots, and the state logs. It does **not** ship a physical cartridge, a photograph of a burn, or a programmer log, because no cartridge was built here. The hardware claims in this lesson are the documented facts of the parts and the console; the software claims are observed in Stella and in the host-side checksum. A builder with a board, a chip, and a programmer can run the same ROM and perform the physical steps; the lesson gives the procedure and the test, not a false claim of a build.
:::

### Section 9: The Test ROM's Architecture

The ROM is two pages sharing one 262-line frame. `Page` at `$83` is 0 (burn-in) or 1 (controller), switched by a SELECT edge in VBLANK. Every frame reads `SWCHA`, `SWCHB`, and `INPT4`, counts a frame, and draws 192 visible lines.

**The burn-in page.** The top is a black alignment line, then a **54-line colour-bar field**: eight vertical bars, each line changing `COLUBK` at fixed cycles. Below it, in the six-column score window, are two words — **CART** and **TEST** — then **SUM** with the four hex digits under it, **RAM** with PASS or FAIL, and **FRAME** with the frame counter. The six columns are contiguous at TIA X = 56, 64, 72, 80, 88, 96. Each label is one 48-byte block: its letters occupy consecutive columns 0-3 (0-4 for FRAME and SWCHB), so no word is split across bands, and a four-character value fills columns 0-3. The full name CARTRIDGE is not split into CART / RIDGE; the page uses CART and TEST, two four-character words, so each is a single contiguous block. The static labels use the five-pixel letter forms; the four-character values use the seven-pixel value glyphs in PlayerFont, so each value is a contiguous four-column run.

**The bar alignment.** `ColourBars` starts with `STA WSYNC`, `BIT Checksum` (3 cycles) and a `NOP` (2), so the first body begins at cycle 5 on the line after the page dispatch. Without that entry the first body starts about 16 cycles late; its bar-defining store lands at cycle 38 (colour clock 114), the left part of the first line is black, and the first bar is 36 clocks wide instead of 19. The alignment line is black (the `BodyStart`/`ColourBars` store sets `COLUBK` to zero), and the first bar line's stores hit at cycle 22 (clock 66), the same hits as every later line. The burn-in page is 1 alignment line + 54 bar lines; the controller page is 1 + 26. The measured page totals are exactly 192 lines, which is why `OverscanStart` is 229.

**The controller page.** The top is a black alignment line, then a **26-line bar field**, then **CTRL** and **TEST**. **CTRL** is the four-character label for CONTROLLER; the full name is not split into CONT / ROLLER, and both words occupy columns 0-3. **JOY** sits above eight playfield blocks (the raw `SWCHA` bits, bit 7 leftmost), and the static **RLDU** legend under the blocks names the four player-0 direction blocks in block order: bit 7 = R, bit 6 = L, bit 5 = D, bit 4 = U. **CONS** sits above the `SWCHB` blocks, with the **SWCHB** legend naming the register; the table below is the bit map, because those bits are not contiguous. **FIRE** sits above the `INPT4` block, which masks the raw byte to bit 7. **FRAME** and the frame counter close the page. The labels are short words; CTRL is the short form of CONTROLLER, and the legends and the blocks name and show the bits.

| Block (left to right) | `SWCHA` bit | `SWCHB` bit |
|---|---|---|
| 0 | 7 — player 0 right | 7 — player 1 difficulty |
| 1 | 6 — player 0 left | 6 — player 0 difficulty |
| 2 | 5 — player 0 down | 5 — unused |
| 3 | 4 — player 0 up | 4 — unused |
| 4 | 3 — player 1 right | 3 — COLOR (1 = color, 0 = B&W) |
| 5 | 2 — player 1 left | 2 — unused |
| 6 | 1 — player 1 down | 1 — SELECT (0 = pressed) |
| 7 | 0 — player 1 up | 0 — RESET (0 = pressed) |

`CTRLPF` is 0 (repeat), so the playfield repeats the 20-chunk half: the eight blocks appear twice, 16 visible blocks. The table and the pixel samples use the left group. The `RLDU` legend is the order of the four P0 direction blocks; `SWCHB` is the register mnemonic, not a left-to-right switch map.

**The checksum.** `Checksum` is a 16-bit sum at `$80/$81`, low byte first. `CsPtr` starts at `$F000`, `CsCount` at 64, and `ChecksumChunk` adds 64 bytes per frame in **overscan** — 64 chunks x 64 bytes = 4,096 bytes, and the last chunk reads through `$FFFF`, the vectors. The display shows the high byte first: a sum of `$2769` reads **2769**. The four SUM cells stay blank until `CsCount` reaches 0.

**The RAM test.** At reset, after `+clean_start`, `$99–$9C` receive `$A5/$5A/$A5/$5A` and are read back. `RamResult` (`$82`) is 0 when all four match and 1 when any differs.

**The six-column text window.** The score library's `ScoreSetup` positions P0 at TIA X=56 (copies at 56/72/88) and P1 at X=64 (64/80/96), sets NUSIZ=3 and VDEL on, and strobes one HMOVE. The static labels are 48-byte ROM blocks (six columns x eight rows) read by the `text_line` macro, the Lesson 63 kernel. The four-character values — the checksum, PASS/FAIL and the frame counter — are composed into the library's 48-byte `ScoreBuf` in an eight-line gap before their band, composed into columns 0–3, and drawn by `ScoreDraw`. The value glyphs are seven pixels wide, so the four characters fill the four columns with one blank pixel between neighbours.

The label and value geometry:

| Text | Columns | Rows |
|---|---|---|
| `CART` | 0-3 | 7 lit rows (0-7, byte 0 blank) |
| `TEST` | 0-3 | 7 lit rows |
| `CTRL` | 0-3 | 7 lit rows |
| `SUM` | 0-2 | 7 lit rows |
| `RAM` | 0-2 | 7 lit rows |
| `FRAME` | 0-4 | 7 lit rows |
| `JOY` | 0-2 | 7 lit rows |
| `RLDU` | 0-3 | 7 lit rows |
| `CONS` | 0-3 | 7 lit rows |
| `SWCHB` | 0-4 | 7 lit rows |
| `FIRE` | 0-3 | 7 lit rows |
| `PASS` | 0-3 | 7 lit rows |
| the checksum (for example `2769`) | 0-3 | 7 lit rows |
| the frame counter | 0-3 | 7 lit rows |

Every word occupies consecutive columns on one nine-line band; the unused columns in its 48-byte block are blank. No word is split across bands.

**The bit blocks.** The raw bytes are shown with the playfield: eight blocks, one chunk lit and one chunk dark each, at chunks 2, 4, 6, 8, 10, 12, 14, 16. Bit 7 is the leftmost block. The three bytes come from four 16-byte nibble tables, looked up in the compute line of each bit band. The `RLDU` and `SWCHB` legends are static label blocks under the block rows.

**The frame.** `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229 on both pages (cycle 8). The measured frame is 262 lines.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/demo-64.bin lessons/part8-advanced/64-building-cartridges/demo-64.asm
stella build/demo-64.bin
```

The committed ROM is `docs/public/roms/part8-advanced/64-building-cartridges/demo-64.bin`, 4,096 bytes. The source is `lessons/part8-advanced/64-building-cartridges/demo-64.asm`. SELECT switches pages; the burn-in page needs about one second for the checksum.

### Full Source

The complete annotated source:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 64: Building Your Own Cartridge — From ROM to Physical Cart
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the burn-in test": a 4,096-byte cartridge test ROM.  It is the program
;   you run first on a freshly built cartridge: it proves that the ROM data
;   survived the burn, that the console's 128 bytes of RAM work, that the
;   controllers reach the program, and that the frame is stable.
;
;   Two pages, switched by the SELECT switch:
;
;     Page 0 — the burn-in page.
;       * Eight vertical colour bars across the top of the page (54 lines),
;         drawn by changing COLUBK at fixed cycles inside each line.
;       * The label CART TEST, two four-character words in the six-column
;         score window (48 pixels, 8 per glyph): CART in columns 0-3 on
;         the first band and TEST in columns 0-3 on the second.  The
;         window uses four-character labels, so no word is split across
;         bands.
;       * A 16-bit checksum of the whole 4,096-byte image ($F000-$FFFF,
;         including the three vectors), computed once after power-on at 64
;         bytes per frame, shown under SUM as four hex digits, high byte
;         first (for example $1A2B reads 1A2B).
;       * A RIOT RAM test: $A5/$5A are written to four free bytes and read
;         back; the line under RAM reads PASS (0) or FAIL (1).
;       * The frame counter, four decimal digits, under FRAME.
;
;     Page 1 — the controller page.
;       * A 26-line colour-bar field at the top.
;       * SWCHA (both joysticks, active low) as eight playfield blocks, bit
;         7 on the left, under JOY; the RLDU legend below the blocks names
;         player 0's four bits in block order: bit 7 = R, 6 = L, 5 = D,
;         4 = U.
;       * SWCHB (the console switches, active low) as eight blocks under
;         CONS; the SWCHB legend below the blocks names the register, and
;         the doc's table maps each block to its switch bit (bit 7/6 are
;         the difficulty switches, bit 3 is COLOR, bit 1 SELECT, bit 0
;         RESET; bits 2, 4 and 5 are unused).
;       * INPT4 (player 0 fire, bit 7) as a single block under FIRE; only
;         bit 7 is defined, so the low seven bits are masked off.
;       * The frame counter under FRAME, and the label CONTROLLER TEST,
;         shown as the four-character labels CTRL and TEST.  CTRL is
;         the short form of CONTROLLER; both words use columns 0-3.
;
;   The text is the Lesson 63 six-column score window: P0 at TIA X=56
;   (copies at 56/72/88) and P1 at X=64 (copies at 64/80/96), NUSIZ=3 and
;   VDEL on, positioned once by the score library's ScoreSetup.  The six
;   columns are contiguous: 56, 64, 72, 80, 88, 96 — no gap inside a word.
;   The static labels are 48-byte ROM blocks read by the text_line macro
;   (the Lesson 63 kernel).  Each block is six columns x eight rows; the
;   letters occupy consecutive columns 0-3 (0-4 for FRAME and SWCHB) and
;   the unused columns are blank, so a word is never split across bands.
;   The four-character values are composed into the library's 48-byte
;   ScoreBuf in the eight-line gap before their band and drawn by
;   ScoreDraw.  The values are the checksum, PASS/FAIL and the frame
;   counter (all four characters); a value uses columns 0-3.  The value
;   glyphs in PlayerFont are seven pixels wide, so the four characters
;   fill the window with one blank pixel between neighbours.  The
;   controller page's RLDU and SWCHB are static legends under the bit
;   blocks, not dynamic values.
;
;   The colour bars use the Lesson 18 mid-line technique: a store takes
;   effect from colour clock 3 x (the cycle of the next instruction).  The
;   visible picture starts at colour clock 68, so the first store hits at
;   cycle 22 (clock 66, still in HBLANK) and the next seven are 7 cycles
;   apart: hits 29, 36, 43, 50, 57, 64, 71.  Measured bar widths in the
;   960-pixel capture: 114, 126, 126, 126, 126, 126, 126, 90 px.
;   ColourBars starts with a black alignment line (STA WSYNC, BIT, NOP),
;   so the body begins at cycle 5 on the next line; without it the first
;   body starts about 16 cycles late and its first store lands at cycle
;   38 (clock 114), leaving a thin misaligned top line.  The burn-in page
;   uses 54 bar lines plus the alignment line (55 lines), the controller
;   page 26 plus one (27); the page totals are exactly 192 lines.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5; OverscanStart is at
;   scanline 229 on both pages (cycle 8 in this build).  One HMOVE,
;   from ScoreSetup at reset.
;
; The checksum:
;   Sum = (Sum + byte) & $FFFF for byte = $F000, $F001, ... $FFFF.
;   It is a 16-bit wrapping sum, not a CRC.  $80 holds the low byte and
;   $81 the high byte; the display shows the high byte first, so a sum of
;   $1A2B reads "1A2B".  The checksum runs in overscan, 64 bytes per frame:
;   64 chunks x 64 bytes = 4,096 bytes, and the last chunk includes
;   $FFFA-$FFFF, the vectors.  It takes 64 frames (about 1.07 s at 60 Hz);
;   the four SUM cells stay blank until the last chunk is added.
;
; The RAM test:
;   At reset, after +clean_start, $99-$9C receive $A5/$5A/$A5/$5A and are
;   read back.  RamResult ($82) is 0 when every byte matches and 1 when any
;   byte differs.  0 = PASS, 1 = FAIL.
;
; The controller page (all inputs active low):
;   SWCHA bit 7/6/5/4 = player 0 right/left/down/up; bits 3-0 = player 1.
;   SWCHB bit 0 = RESET, bit 1 = SELECT, bit 3 = COLOR (1) / B&W (0),
;          bits 6-7 = the two difficulty switches.
;   INPT4 bit 7 = player 0 fire; 0 while the button is held.  Only bit 7
;   is defined; the low seven bits of INPT4 are not reliable, so the INPT4
;   block row masks them off and shows bit 7 alone (the leftmost block).
;   The raw bytes are in $85 (SWCHA), $86 (SWCHB), $87 (INPT4).  A SELECT
;   press switches the page in VBLANK, so the SELECT block is observable
;   only with the switch held across power-on (the -holdselect state log);
;   the still is idle.  RESET restarts the console, so its block cannot be
;   observed while the program is running (released = 1).
;
; Checkpoints (label, Stella scanline/cycle, and the A register):
;   StartFrame    259/3   the first VSYNC instruction
;   VblankStart     0/5   the first VBLANK instruction
;   BodyStart      37/5   the page dispatch
;   OverscanStart 229     the first overscan instruction
;   PageRead       A = the current page, 0 or 1
;   FrameRead      A = the free-running frame counter, 0..255
;   ChecksumRead   A = the checksum's LOW byte ($80); the high byte is $81
;   RamResultRead  A = 0 (PASS) or 1 (FAIL)
;   SwchaRead      A = the raw SWCHA byte (both joysticks)
;   SwchbRead      A = the raw SWCHB byte (the console switches)
;   Inpt4Read      A = the raw INPT4 byte (bit 7 = fire)
;
; The band ledgers (all cycles counted from the row's WSYNC):
;   text_line: the Lesson 63 six-column kernel; nine visible lines (one
;     setup line plus eight glyph rows, the last sharing its line with the
;     aligning WSYNC).  Its stores are inside the 76-cycle line by
;     construction; the columns are contiguous because NUSIZ=3.
;   ScoreDraw: the score library's nine-line kernel, reading ScoreBuf.
;   Gap + value: the gap starts a 10-tick RIOT timer (577 cycles) and then
;     sets the four glyphs, clears the players and playfield, and copies
;     the four glyphs into ScoreBuf (about 450 cycles).  The wait ends on
;     line 7 and the value band follows, so the gap is exactly eight lines.
;     ScoreDraw then draws the four-character value in columns 0-3.
;   bit_band: a leading gap line, then BitsToPF (about 60 cycles) and its
;     WSYNC; six block rows of three loads and three stores follow, then
;     one clear line.  The gap line separates a label from the blocks.
;   The measured page totals are exactly 192 lines, which is why
;   OverscanStart is 229 on both pages.
;
; RAM map (+clean_start zeroes every byte):
;   $80-$81 Checksum       the 16-bit sum, low byte first
;   $82     RamResult      0 = pass, 1 = fail
;   $83     Page           0 = burn-in, 1 = controller
;   $84     Frame          the free-running frame counter
;   $85     Swcha          the raw SWCHA byte
;   $86     Swchb          the raw SWCHB byte
;   $87     Inpt4          the raw INPT4 byte
;   $88-$89 CsPtr          the checksum's read pointer
;   $8A     CsCount        checksum chunks left, 64 -> 0
;   $8B     PrevSelect     the SELECT level last frame
;   $8C     Scratch        SELECT's pressed level this frame
;   $8D-$90 Char0-3        the four glyph indices of the next value
;   $91-$98 GlyphPtr0-3    the four glyph pointers during a compose
;   $99-$9C RamTest0-3     the four RAM-test bytes
;   $9D-$9F BitPF0-2       the live bit-block bytes
;   $A0-$A5 ScoreDigits    the score library (unused here)
;   $A6     ScoreRow       the score library's/text macro's row counter
;   $A7     ScoreTmp       the score library's/text macro's scratch
;   $A8-$D7 ScoreBuf       the 48-byte six-column text buffer
;   $D8-$DB FrameChars     the frame counter's four precomputed digits
;   $DC-$F7 free (28 bytes)
;   $F8-$FF stack
;
; Build: acme -f plain -o build/demo-64.bin \
;        lessons/part8-advanced/64-building-cartridges/demo-64.asm
; Run:   stella build/demo-64.bin        (SELECT switches pages)
; The ROM is 4,096 bytes.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44      ; 37-line VBLANK (44 ticks, see include/macro.asm)
OVERSCAN_TIMER = 36      ; 30-line overscan
GAP_TIMER      = 10      ; 1 + 9 x 64 = 577 cycles: the eight-line value gap
BAND_LINES     = 8       ; BlankBand's eight lines

; The eight colour bars.  The hues are drawn from the Lesson 13 palette.
BAR0 = $0E               ; light grey
BAR1 = $1A               ; gold
BAR2 = $2E               ; orange
BAR3 = $3E               ; peach
BAR4 = $42               ; red
BAR5 = $5E               ; pink
BAR6 = $84               ; blue
BAR7 = $C8               ; green

; The glyph indices of the runtime font (the 8-byte score-font order).
GLYPH_0        = 0
GLYPH_1        = 1
GLYPH_2        = 2
GLYPH_3        = 3
GLYPH_4        = 4
GLYPH_5        = 5
GLYPH_6        = 6
GLYPH_7        = 7
GLYPH_8        = 8
GLYPH_9        = 9
GLYPH_A        = 10
GLYPH_B        = 11
GLYPH_C        = 12
GLYPH_D        = 13
GLYPH_E        = 14
GLYPH_F        = 15
GLYPH_P        = 16
GLYPH_S        = 17
GLYPH_I        = 18
GLYPH_L        = 19
GLYPH_U        = 20
GLYPH_R        = 21
GLYPH_BLANK    = 22

; The checksum runs 64 bytes per frame.  64 chunks x 64 bytes = 4,096.
CHECK_CHUNK    = 64
CHECK_CHUNKS   = 4096 / CHECK_CHUNK

; =============================================================================
; RAM ALLOCATION ($80-$9F and $D8-$F7; the score library owns $A0-$D7)
; =============================================================================
Checksum      = $80      ; 2 bytes: $80 low, $81 high
RamResult     = $82      ; 0 = pass, 1 = fail
Page          = $83      ; 0 = burn-in, 1 = controller
Frame         = $84      ; the free-running frame counter
Swcha         = $85      ; the raw SWCHA byte
Swchb         = $86      ; the raw SWCHB byte
Inpt4         = $87      ; the raw INPT4 byte
CsPtr         = $88      ; 2 bytes: the checksum read pointer
CsCount       = $8A      ; checksum chunks left
PrevSelect    = $8B      ; SELECT's level last frame
Scratch       = $8C      ; SELECT's pressed level this frame
Char0         = $8D      ; the four glyph indices of the next value
Char1         = $8E
Char2         = $8F
Char3         = $90
GlyphPtr0     = $91      ; the four glyph pointers during a compose
GlyphPtr1     = $93
GlyphPtr2     = $95
GlyphPtr3     = $97
RamTest0      = $99
RamTest1      = $9A
RamTest2      = $9B
RamTest3      = $9C
BitPF0        = $9D      ; the live bit-block bytes
BitPF1        = $9E
BitPF2        = $9F
; $A0-$D7 are the score library's (ScoreDigits, ScoreRow, ScoreTmp,
; ScoreBuf).  This lesson uses ScoreRow, ScoreTmp and the 48-byte buffer.
FrameChars    = $D8      ; 4 bytes: the frame counter's decimal digits

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreSetup sets NUSIZ=3 (three close copies), VDEL on, positions P0 at
; TIA X=56 and P1 at X=64, and strobes ONE HMOVE.  ScoreDraw draws the six
; columns of ScoreBuf.  The library owns $A0-$D7.  It is sourced at the
; ROM origin because it contains code; the reset vector still points here.
    * = $F000

    !source "include/score.asm"

; =============================================================================
; MACROS (defined before use)
; =============================================================================
; text_line — the Lesson 63 six-column, 8-row kernel, reading a ROM block.
; The base block is 48 bytes: column c at base + c*8, row 0 at the bottom.
!macro text_line .base {
    LDA #7
    STA ScoreRow
-   LDY ScoreRow
    LDA .base+0,Y
    STA WSYNC
    STA GRP0
    LDA .base+8,Y
    STA GRP1
    LDA .base+16,Y
    STA GRP0
    LDA .base+24,Y
    STA ScoreTmp
    LDA .base+32,Y
    TAX
    LDA .base+40,Y
    LDY ScoreTmp
    NOP
    CPX ScoreRow
    STY GRP1
    STX GRP0
    STA GRP1
    STA GRP0
    DEC ScoreRow
    BPL -
    STA WSYNC               ; align the next band to a fresh line
}

; text_band — a static label: set the six-copy mode, then draw the block.
!macro text_band .label {
    JSR SetScoreMode
    +text_line .label
}

; bit_band — eight playfield blocks from one raw input byte.
; The compute line is 72 cycles and parks; six block rows follow, then a
; clear line.  Bit 7 is the leftmost block.
!macro bit_band .src, .mask {
    STA WSYNC               ; the gap line: keep the label clear
    LDA .src
    AND #.mask
    JSR BitsToPF
    STA WSYNC               ; line 0: the compute line
    LDY #0
-   LDA BitPF0
    STA PF0
    LDA BitPF1
    STA PF1
    LDA BitPF2
    STA PF2
    STA WSYNC
    INY
    CPY #6
    BNE -
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
}

; =============================================================================
; RESET — power-on entry
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (joysticks)
    STA SWBCNT              ; port B is an input port (console switches)

    ; --- the RIOT RAM test ------------------------------------------------
    ; Write two complementary patterns to four free bytes and read them
    ; back.  RamResult is 0 when all four match.
    LDA #$A5
    STA RamTest0
    STA RamTest2
    LDA #$5A
    STA RamTest1
    STA RamTest3
    LDA RamTest0
    CMP #$A5
    BNE RamFail
    LDA RamTest1
    CMP #$5A
    BNE RamFail
    LDA RamTest2
    CMP #$A5
    BNE RamFail
    LDA RamTest3
    CMP #$5A
    BNE RamFail
    LDA #$00
    BEQ RamDone
RamFail:
    LDA #$01
RamDone:
    STA RamResult

    ; --- the checksum's starting state ------------------------------------
    LDA #$00
    STA Checksum
    STA Checksum+1
    STA CsPtr
    LDA #$F0
    STA CsPtr+1
    LDA #CHECK_CHUNKS
    STA CsCount

    ; --- the frame state ---------------------------------------------------
    LDA #$00
    STA Page
    STA Frame
    STA PrevSelect

    ; --- the fixed TIA state ----------------------------------------------
    LDA #$00
    STA COLUBK              ; the text background is black
    STA CTRLPF              ; repeat playfield; the ball is unused
    STA GRP0
    STA GRP1
    LDA #$0E                ; white text and bit blocks
    STA COLUP0
    STA COLUP1
    STA COLUPF

    ; --- the six-column score window --------------------------------------
    ; ScoreSetup sets NUSIZ=3, VDEL on, positions P0/P1 at 56/64, and
    ; strobes the frame's only HMOVE.  The per-band SetScoreMode writes
    ; only re-enable VDEL/NUSIZ after ScoreDraw turns VDEL off.
    JSR ScoreSetup

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines
; =============================================================================
StartFrame:                 ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; checkpoint: scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    LDA #$00
    STA COLUBK              ; the alignment line is black

; -----------------------------------------------------------------------------
; 1. THE INPUTS — read all three sources every frame
; -----------------------------------------------------------------------------
    LDA SWCHA
    STA Swcha
SwchaRead:                  ; checkpoint: A = the raw SWCHA byte
    NOP
    LDA SWCHB
    STA Swchb
SwchbRead:                  ; checkpoint: A = the raw SWCHB byte
    NOP
    LDA INPT4
    STA Inpt4
Inpt4Read:                  ; checkpoint: A = the raw INPT4 byte
    NOP

; -----------------------------------------------------------------------------
; 2. SELECT — a press cycles the test pages
; -----------------------------------------------------------------------------
    LDA Swchb
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelect
    LDA Page
    EOR #$01
    STA Page
NoSelect:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 3. THE FRAME COUNTER AND ITS FOUR DECIMAL DIGITS
; -----------------------------------------------------------------------------
    INC Frame
    LDA Frame
FrameRead:                  ; checkpoint: A = the frame count, 0..255
    NOP
    LDX #0
FrameHundreds:
    CMP #100
    BCC FrameHundredsDone
    SBC #100
    INX
    BNE FrameHundreds
FrameHundredsDone:
    STX FrameChars+1
    LDX #0
FrameTens:
    CMP #10
    BCC FrameTensDone
    SBC #10
    INX
    BNE FrameTens
FrameTensDone:
    STX FrameChars+2
    STA FrameChars+3
    LDA #$00
    STA FrameChars+0

; -----------------------------------------------------------------------------
; 4. THE PAGE STATE
; -----------------------------------------------------------------------------
    LDA Page
PageRead:                   ; checkpoint: A = 0 (burn-in) or 1 (controller)
    NOP

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; THE VISIBLE PICTURE — the page dispatch
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDA #$00
    STA COLUBK              ; the alignment line is black
    LDA Page
    BEQ BurnPage
    JMP ControllerPage

; =============================================================================
; PAGE 0 — THE BURN-IN PAGE (24 bands, 192 lines)
; =============================================================================
BurnPage:
    LDY #54                 ; the burn-in bar field
    JSR ColourBars
    JSR BlankBand

    +text_band LabelCart
    +text_band LabelTest
    +text_band LabelBlank

    JSR BlankBand

    +text_band LabelSum
    +set_timer GAP_TIMER
    JSR SetChecksumChars
    JSR ClearCompose
    +wait_timer
    JSR SetScoreMode
    JSR ScoreDraw

    JSR BlankBand

    +text_band LabelRam
    +set_timer GAP_TIMER
    JSR SetRamChars
    JSR ClearCompose
    +wait_timer
    JSR SetScoreMode
    JSR ScoreDraw

    JSR BlankBand

    +text_band LabelFrame
    +set_timer GAP_TIMER
    JSR SetFrameChars
    JSR ClearCompose
    +wait_timer
    JSR SetScoreMode
    JSR ScoreDraw

    JMP OverscanStart

; =============================================================================
; PAGE 1 — THE CONTROLLER PAGE (24 bands, 192 lines)
; =============================================================================
ControllerPage:
    LDY #26                 ; the controller bar field
    JSR ColourBars
    JSR BlankBand

    +text_band LabelCtrl
    +text_band LabelTest
    +text_band LabelBlank

    JSR BlankBand

    +text_band LabelJoy
    +bit_band Swcha, $FF    ; eight blocks, bit 7 leftmost
    +text_band LabelRldu     ; names the four player-0 direction bits

    JSR BlankBand

    +text_band LabelCons
    +bit_band Swchb, $FF
    +text_band LabelSwchb      ; names the SWCHB register

    JSR BlankBand

    +text_band LabelFire
    +bit_band Inpt4, $80    ; only bit 7 is defined for INPT4

    JSR BlankBand

    +text_band LabelFrame
    +set_timer GAP_TIMER
    JSR SetFrameChars
    JSR ClearCompose
    +wait_timer
    JSR SetScoreMode
    JSR ScoreDraw

    JMP OverscanStart

; =============================================================================
; FRAME END — 30 overscan lines, the checksum chunk, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    JSR ChecksumChunk
    +wait_timer
    JMP StartFrame

; =============================================================================
; ColourBars — Y = number of lines.  Eight bars across each line.
; =============================================================================
; The line body starts at cycle 5: DEY (0-1) and BNE (2-4) follow the
; previous line's WSYNC, and the first line is aligned by the entry
; STA WSYNC + BIT + NOP.  A store paints from colour clock 3 x the cycle
; of the next instruction (Lesson 18), so the hits below put the bar
; boundaries at clocks 66, 87, 108, 129, 150, 171, 192 and 213.  The
; visible picture begins at clock 68; the first bar is 114 pixels wide in
; the capture, the six inside bars 126, and the last 90.
ColourBars:
    LDA #$00
    STA COLUBK              ; the alignment line is black
    STA WSYNC               ; align the body to a fresh line
    BIT Checksum            ; 3 cycles
    NOP                     ; 2 cycles: the body starts at cycle 5
BarBody:
    LDA #BAR0               ; 5-6
    STA COLUBK              ; 7-9    hit 10: the base in HBLANK
    NOP                     ; 10-11
    NOP                     ; 12-13
    BIT Checksum            ; 14-16  a 3-cycle pad; no side effects
    LDA #BAR0               ; 17-18
    STA COLUBK              ; 19-21  hit 22 (clock 66)
    NOP                     ; 22-23
    LDA #BAR1               ; 24-25
    STA COLUBK              ; 26-28  hit 29
    NOP
    LDA #BAR2
    STA COLUBK              ; hit 36
    NOP
    LDA #BAR3
    STA COLUBK              ; hit 43
    NOP
    LDA #BAR4
    STA COLUBK              ; hit 50
    NOP
    LDA #BAR5
    STA COLUBK              ; hit 57
    NOP
    LDA #BAR6
    STA COLUBK              ; hit 64
    NOP                     ; 64-65
    LDA #BAR7               ; 66-67
    STA COLUBK              ; 68-70  hit 71 (clock 213)
    STA WSYNC               ; 71-73  park until the line ends
    DEY                     ; the next line: 0-1
    BNE BarBody             ; 2-4
    LDA #$00
    STA COLUBK              ; the text background is black again
    RTS

; =============================================================================
; BlankBand — eight lines with no graphics
; =============================================================================
BlankBand:
    LDA #$00
    LDY #BAND_LINES
-   STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA WSYNC
    DEY
    BNE -
    RTS

; =============================================================================
; SetScoreMode — clear the playfield, three close copies, VDEL on
; =============================================================================
; ScoreSetup leaves the players in this mode; ScoreDraw turns VDEL off at
; the end of every value, so each band re-enables it.  The playfield is
; cleared here so a bit-block row cannot persist behind a label.  No HMOVE
; here: the positions do not change.
SetScoreMode:
    LDA #$00
    STA PF0                 ; the labels and values own the playfield
    STA PF1
    STA PF2
    LDA #$03
    STA NUSIZ0
    STA NUSIZ1
    LDA #$01
    STA VDELP0
    STA VDELP1
    RTS

; =============================================================================
; ClearCompose — blank the players/playfield, then compose the value
; =============================================================================
; The gap started the GAP_TIMER; the clear and the compose must finish
; before the timer expires (577 cycles), which keeps the gap eight lines.
ClearCompose:
    LDA #$00
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    JSR ComposeValue
    RTS

; =============================================================================
; ComposeValue — Char0-3 -> ScoreBuf columns 0-3
; =============================================================================
; A value is four glyphs wide and left-aligned in the six-column window:
; columns 0-3 hold the glyphs, columns 4 and 5 stay zero from +clean_start.
ComposeValue:
    LDX Char0
    LDA FontPtrLo,X
    STA GlyphPtr0
    LDA FontPtrHi,X
    STA GlyphPtr0+1
    LDX Char1
    LDA FontPtrLo,X
    STA GlyphPtr1
    LDA FontPtrHi,X
    STA GlyphPtr1+1
    LDX Char2
    LDA FontPtrLo,X
    STA GlyphPtr2
    LDA FontPtrHi,X
    STA GlyphPtr2+1
    LDX Char3
    LDA FontPtrLo,X
    STA GlyphPtr3
    LDA FontPtrHi,X
    STA GlyphPtr3+1
    LDY #0
-   LDA (GlyphPtr0),Y
    STA ScoreBuf+0,Y
    LDA (GlyphPtr1),Y
    STA ScoreBuf+8,Y
    LDA (GlyphPtr2),Y
    STA ScoreBuf+16,Y
    LDA (GlyphPtr3),Y
    STA ScoreBuf+24,Y
    INY
    CPY #8
    BNE -
    RTS

; =============================================================================
; SetChecksumChars — the four hex digits, high byte first
; =============================================================================
SetChecksumChars:
    LDA CsCount
    BNE CsBlank
    LDA Checksum+1
    PHA
    LSR
    LSR
    LSR
    LSR
    STA Char0               ; the high byte's high nibble
    PLA
    AND #$0F
    STA Char1               ; the high byte's low nibble
    LDA Checksum
ChecksumRead:               ; checkpoint: A = the checksum's low byte
    NOP
    PHA
    LSR
    LSR
    LSR
    LSR
    STA Char2               ; the low byte's high nibble
    PLA
    AND #$0F
    STA Char3               ; the low byte's low nibble
    RTS
CsBlank:
    LDA #GLYPH_BLANK
    STA Char0
    STA Char1
    STA Char2
    STA Char3
    RTS

; =============================================================================
; SetRamChars — PASS or FAIL
; =============================================================================
SetRamChars:
    LDA RamResult
RamResultRead:              ; checkpoint: A = 0 (PASS) or 1 (FAIL)
    NOP
    BNE RamFailLine
    LDX #0
-   LDA PassGlyphs,X
    STA Char0,X
    INX
    CPX #4
    BNE -
    RTS
RamFailLine:
    LDX #0
-   LDA FailGlyphs,X
    STA Char0,X
    INX
    CPX #4
    BNE -
    RTS

; =============================================================================
; SetFrameChars — copy the four digits computed in VBLANK
; =============================================================================
SetFrameChars:
    LDA FrameChars+0
    STA Char0
    LDA FrameChars+1
    STA Char1
    LDA FrameChars+2
    STA Char2
    LDA FrameChars+3
    STA Char3
    RTS

; =============================================================================
; BitsToPF — A = the raw byte; fills BitPF0/1/2 with the eight blocks
; =============================================================================
; Block positions: bit 7 at chunk 2 (PF0 bit 6), bits 6-3 at chunks 4, 6,
; 8, 10 (PF1 bits 7, 5, 3, 1), bits 2-0 at chunks 12, 14, 16 (PF2 bits
; 0, 2, 4).  The four 16-byte tables hold the pre-shifted contribution of
; each nibble.  Char0 is free here (the value compose runs later).
BitsToPF:
    STA Char0
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA BitHighPF0,X
    STA BitPF0
    LDA BitHighPF1,X
    STA BitPF1
    LDA Char0
    AND #$0F
    TAX
    LDA BitPF1
    ORA BitLowPF1,X
    STA BitPF1
    LDA BitLowPF2,X
    STA BitPF2
    RTS

; The high nibble: bit 7 -> PF0 $40; bits 6/5/4 -> PF1 $80/$20/$08.
BitHighPF0:
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    !byte $40,$40,$40,$40,$40,$40,$40,$40
BitHighPF1:
    !byte $00,$08,$20,$28,$80,$88,$A0,$A8
    !byte $00,$08,$20,$28,$80,$88,$A0,$A8
; The low nibble: bit 3 -> PF1 $02; bits 2/1/0 -> PF2 $01/$04/$10.
BitLowPF1:
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    !byte $02,$02,$02,$02,$02,$02,$02,$02
BitLowPF2:
    !byte $00,$10,$04,$14,$01,$11,$05,$15
    !byte $00,$10,$04,$14,$01,$11,$05,$15

; =============================================================================
; ChecksumChunk — add the next 64 bytes to the 16-bit checksum
; =============================================================================
; The pointer walks $F000 -> $FFC0, so the final chunk reads through
; $FFFF, the last vector byte.  CsCount reaches 0 after 64 chunks.
ChecksumChunk:
    LDA CsCount
    BEQ CheckDone
    LDY #0
-   LDA (CsPtr),Y
    CLC
    ADC Checksum
    STA Checksum
    BCC CheckNoCarry
    INC Checksum+1
CheckNoCarry:
    INY
    CPY #CHECK_CHUNK
    BNE -
    LDA CsPtr
    CLC
    ADC #CHECK_CHUNK
    STA CsPtr
    BCC CheckNoPage
    INC CsPtr+1
CheckNoPage:
    DEC CsCount
CheckDone:
    RTS

; =============================================================================
; THE VALUE FONT AND THE LABEL DATA
; =============================================================================
; PlayerFont holds the value glyphs.  Each glyph body is stretched to seven
; pixels (bits 7-1), so a four-character value fills its four columns with
; one blank pixel between neighbours and no gap that reads as a blank
; column.  The static label blocks below use the five-pixel letter forms,
; which suit a single word in four consecutive columns.
PlayerFont:
    !byte $00,$7C,$C6,$C6,$E6,$DE,$C6,$7C   ; 0 0
    !byte $00,$FE,$38,$38,$38,$38,$78,$38   ; 1 1
    !byte $00,$FE,$60,$38,$1C,$06,$C6,$7C   ; 2 2
    !byte $00,$7C,$C6,$06,$1C,$38,$1C,$FE   ; 3 3
    !byte $00,$1C,$1C,$FE,$DC,$7C,$3C,$1C   ; 4 4
    !byte $00,$7C,$C6,$06,$06,$FC,$C0,$FE   ; 5 5
    !byte $00,$7C,$C6,$C6,$FC,$C0,$C6,$7C   ; 6 6
    !byte $00,$38,$38,$38,$38,$1C,$C6,$FE   ; 7 7
    !byte $00,$7C,$C6,$C6,$7C,$C6,$C6,$7C   ; 8 8
    !byte $00,$7C,$C6,$06,$7E,$C6,$C6,$7C   ; 9 9
    !byte $00,$C6,$C6,$C6,$FE,$C6,$C6,$38   ; 10 A
    !byte $00,$F8,$C6,$C6,$F8,$C6,$C6,$F8   ; 11 B
    !byte $00,$38,$C6,$C0,$C0,$C0,$C6,$38   ; 12 C
    !byte $00,$F8,$C6,$C6,$C6,$C6,$C6,$F8   ; 13 D
    !byte $00,$FE,$C0,$C0,$F8,$C0,$C0,$FE   ; 14 E
    !byte $00,$C0,$C0,$C0,$F8,$C0,$C0,$FE   ; 15 F
    !byte $00,$C0,$C0,$C0,$F8,$C6,$C6,$F8   ; 16 P
    !byte $00,$F8,$06,$06,$38,$C0,$C0,$3E   ; 17 S
    !byte $00,$FE,$10,$10,$10,$10,$10,$FE   ; 18 I
    !byte $00,$FE,$C0,$C0,$C0,$C0,$C0,$C0   ; 19 L
    !byte $00,$38,$C6,$C6,$C6,$C6,$C6,$C6   ; 20 U
    !byte $00,$C6,$C8,$D0,$F8,$C6,$C6,$F8   ; 21 R
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; 22  

FontPtrLo:
    !byte <(PlayerFont + 0)
    !byte <(PlayerFont + 8)
    !byte <(PlayerFont + 16)
    !byte <(PlayerFont + 24)
    !byte <(PlayerFont + 32)
    !byte <(PlayerFont + 40)
    !byte <(PlayerFont + 48)
    !byte <(PlayerFont + 56)
    !byte <(PlayerFont + 64)
    !byte <(PlayerFont + 72)
    !byte <(PlayerFont + 80)
    !byte <(PlayerFont + 88)
    !byte <(PlayerFont + 96)
    !byte <(PlayerFont + 104)
    !byte <(PlayerFont + 112)
    !byte <(PlayerFont + 120)
    !byte <(PlayerFont + 128)
    !byte <(PlayerFont + 136)
    !byte <(PlayerFont + 144)
    !byte <(PlayerFont + 152)
    !byte <(PlayerFont + 160)
    !byte <(PlayerFont + 168)
    !byte <(PlayerFont + 176)
FontPtrHi:
    !byte >(PlayerFont + 0)
    !byte >(PlayerFont + 8)
    !byte >(PlayerFont + 16)
    !byte >(PlayerFont + 24)
    !byte >(PlayerFont + 32)
    !byte >(PlayerFont + 40)
    !byte >(PlayerFont + 48)
    !byte >(PlayerFont + 56)
    !byte >(PlayerFont + 64)
    !byte >(PlayerFont + 72)
    !byte >(PlayerFont + 80)
    !byte >(PlayerFont + 88)
    !byte >(PlayerFont + 96)
    !byte >(PlayerFont + 104)
    !byte >(PlayerFont + 112)
    !byte >(PlayerFont + 120)
    !byte >(PlayerFont + 128)
    !byte >(PlayerFont + 136)
    !byte >(PlayerFont + 144)
    !byte >(PlayerFont + 152)
    !byte >(PlayerFont + 160)
    !byte >(PlayerFont + 168)
    !byte >(PlayerFont + 176)

    !align 7, 0
LabelCart:                        ; "CART"
    !byte $00,$70,$88,$80,$80,$80,$88,$70   ; column 0 'C'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70   ; column 1 'A'
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0   ; column 2 'R'
    !byte $00,$20,$20,$20,$20,$20,$20,$F8   ; column 3 'T'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelTest:                        ; "TEST"
    !byte $00,$20,$20,$20,$20,$20,$20,$F8   ; column 0 'T'
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8   ; column 1 'E'
    !byte $00,$F0,$08,$08,$70,$80,$80,$78   ; column 2 'S'
    !byte $00,$20,$20,$20,$20,$20,$20,$F8   ; column 3 'T'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelCtrl:                        ; "CTRL"
    !byte $00,$70,$88,$80,$80,$80,$88,$70   ; column 0 'C'
    !byte $00,$20,$20,$20,$20,$20,$20,$F8   ; column 1 'T'
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0   ; column 2 'R'
    !byte $00,$F8,$80,$80,$80,$80,$80,$80   ; column 3 'L'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelSum:                         ; "SUM"
    !byte $00,$F0,$08,$08,$70,$80,$80,$78   ; column 0 'S'
    !byte $00,$70,$88,$88,$88,$88,$88,$88   ; column 1 'U'
    !byte $00,$88,$88,$88,$A8,$A8,$D8,$88   ; column 2 'M'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 3 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelRam:                         ; "RAM"
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0   ; column 0 'R'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70   ; column 1 'A'
    !byte $00,$88,$88,$88,$A8,$A8,$D8,$88   ; column 2 'M'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 3 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelFrame:                       ; "FRAME"
    !byte $00,$80,$80,$80,$F0,$80,$80,$F8   ; column 0 'F'
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0   ; column 1 'R'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70   ; column 2 'A'
    !byte $00,$88,$88,$88,$A8,$A8,$D8,$88   ; column 3 'M'
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8   ; column 4 'E'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelJoy:                         ; "JOY"
    !byte $00,$70,$88,$88,$88,$08,$08,$08   ; column 0 'J'
    !byte $00,$70,$88,$88,$88,$88,$88,$70   ; column 1 'O'
    !byte $00,$20,$20,$20,$50,$88,$88,$88   ; column 2 'Y'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 3 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelRldu:                        ; "RLDU"
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0   ; column 0 'R'
    !byte $00,$F8,$80,$80,$80,$80,$80,$80   ; column 1 'L'
    !byte $00,$F0,$88,$88,$88,$88,$88,$F0   ; column 2 'D'
    !byte $00,$70,$88,$88,$88,$88,$88,$88   ; column 3 'U'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelCons:                        ; "CONS"
    !byte $00,$70,$88,$80,$80,$80,$88,$70   ; column 0 'C'
    !byte $00,$70,$88,$88,$88,$88,$88,$70   ; column 1 'O'
    !byte $00,$88,$88,$88,$98,$A8,$C8,$88   ; column 2 'N'
    !byte $00,$F0,$08,$08,$70,$80,$80,$78   ; column 3 'S'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelSwchb:                       ; "SWCHB"
    !byte $00,$F0,$08,$08,$70,$80,$80,$78   ; column 0 'S'
    !byte $00,$D8,$A8,$A8,$88,$88,$88,$88   ; column 1 'W'
    !byte $00,$70,$88,$80,$80,$80,$88,$70   ; column 2 'C'
    !byte $00,$88,$88,$88,$F8,$88,$88,$88   ; column 3 'H'
    !byte $00,$F0,$88,$88,$F0,$88,$88,$F0   ; column 4 'B'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelFire:                        ; "FIRE"
    !byte $00,$80,$80,$80,$F0,$80,$80,$F8   ; column 0 'F'
    !byte $00,$F8,$20,$20,$20,$20,$20,$F8   ; column 1 'I'
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0   ; column 2 'R'
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8   ; column 3 'E'
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

    !align 7, 0
LabelBlank:                       ; a blank band, six empty columns
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 0 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 1 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 2 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 3 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 4 ' '
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; column 5 ' '

PassGlyphs:
    !byte 16,10,17,17
FailGlyphs:
    !byte 15,10,18,19


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
> `lessons/part8-advanced/64-building-cartridges/demo-64.asm`.

### Code Walkthrough

#### Step 1 — Reset and the RAM test

`Reset` at `$F145` runs `+clean_start`, sets `SWACNT` and `SWBCNT` to zero (both ports are inputs), and runs the RAM test before it trusts any variable:

```asm
    LDA #$A5
    STA RamTest0
    STA RamTest2
    LDA #$5A
    STA RamTest1
    STA RamTest3
    LDA RamTest0
    CMP #$A5
    BNE RamFail
    ...
RamFail:
    LDA #$01
RamDone:
    STA RamResult
```

The four bytes are `$99–$9C`. A mismatch sets `RamResult` to 1 (FAIL); a match leaves it at 0 (PASS). The test runs once, after `+clean_start`, so the bytes start from a known zero and the result is stored in a byte the test itself does not use. Four bytes with two complementary patterns catch a stuck bit and a shorted line, which are the failures a RIOT actually produces.

#### Step 2 — The checksum's state and the chunk routine

The checksum is a 16-bit sum, not a CRC:

```asm
ChecksumChunk:
    LDA CsCount
    BEQ CheckDone
    LDY #0
-   LDA (CsPtr),Y
    CLC
    ADC Checksum
    STA Checksum
    BCC CheckNoCarry
    INC Checksum+1
CheckNoCarry:
    INY
    CPY #CHECK_CHUNK
    BNE -
    ...
    DEC CsCount
CheckDone:
    RTS
```

`CsPtr` starts at `$F000` and `CsCount` at 64. Each frame the routine adds 64 bytes and advances the pointer by 64; after 64 frames the pointer has read `$F000–$FFFF`, including the vectors at `$FFFA–$FFFF`. The routine runs in **overscan**. One chunk costs about **1,620 cycles on average and about 1,750 in the worst case** (the loads and stores are fixed-cost; the branch and carry paths vary). The overscan's 30 lines are about 2,240 cycles, so the margin is about **490 cycles**. The VBLANK does the display work instead, which is why the picture never waits for the sum.

The display reads the sum in `SetChecksumChars`:

```asm
    LDA Checksum+1
    PHA
    LSR
    LSR
    LSR
    LSR
    STA Char0               ; the high byte's high nibble
    PLA
    AND #$0F
    STA Char1               ; the high byte's low nibble
    LDA Checksum
ChecksumRead:               ; checkpoint: A = the checksum's low byte
    NOP
    PHA
    LSR
    LSR
    LSR
    LSR
    STA Char2               ; the low byte's high nibble
    PLA
    AND #$0F
    STA Char3               ; the low byte's low nibble
```

The high byte is displayed first. The host-side sum of the committed `.bin` is `$2769`; the screen reads **2769**. The `ChecksumRead` checkpoint reports A = `$69`, the low byte; `$81` holds `$27`.

#### Step 3 — The frame skeleton and the page

The frame is the Part 8 skeleton: three VSYNC lines, 37 VBLANK lines with the timer at 44, 192 picture lines, and 30 overscan lines with the timer at 36. The state log gives `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, and `OverscanStart` 229/8 on both pages. The page dispatch is a branch on `Page`:

```asm
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDA #$00
    STA COLUBK              ; the alignment line is black
    LDA Page
    BEQ BurnPage
    JMP ControllerPage
```

The SELECT edge is in VBLANK:

```asm
    LDA Swchb
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelect
    LDA Page
    EOR #$01
    STA Page
NoSelect:
    LDA Scratch
    STA PrevSelect
```

`SWCHB` bit 1 is 0 while SELECT is held. `EOR #$02` turns that into 1, and the `EOR PrevSelect` / `AND Scratch` pair keeps only a new press, so a held switch acts once. The page byte flips between 0 and 1. Because the press is consumed here, the SELECT block on the controller page is not observable by pressing SELECT during play; it is observable only with the switch held across power-on (the `-holdselect` state log below), and RESET restarts the console instead of producing a block change.

#### Step 4 — The colour-bar kernel

Each bar line writes `COLUBK` eight times at fixed cycles. The store takes effect from colour clock 3 x the cycle of the next instruction (Lesson 18), and the visible picture starts at colour clock 68:

```asm
ColourBars:
    LDA #$00
    STA COLUBK              ; the alignment line is black
    STA WSYNC               ; align the body to a fresh line
    BIT Checksum            ; 3 cycles
    NOP                     ; 2 cycles: the body starts at cycle 5
BarBody:
    LDA #BAR0               ; 5-6
    STA COLUBK              ; 7-9    hit 10: the base in HBLANK
    NOP
    NOP
    BIT Checksum            ; a 3-cycle pad; no side effects
    LDA #BAR0               ; 17-18
    STA COLUBK              ; 19-21  hit 22 (clock 66)
    ...
    LDA #BAR7
    STA COLUBK              ; hit 71 (clock 213)
    STA WSYNC
    DEY
    BNE BarBody
```

The hits are 22, 29, 36, 43, 50, 57, 64, and 71; the boundaries are colour clocks 66, 87, 108, 129, 150, 171, 192, and 213. The measured widths in the capture are **114, 126, 126, 126, 126, 126, 126, 90** pixels: eight bars, the first and last slightly wider or narrower than the six inside ones. The entry alignment is the point of the `STA WSYNC`/`BIT`/`NOP`: without it the first body begins about 16 cycles after the page dispatch, its first bar-defining store lands at cycle 38 (clock 114), the left part of the first line is black, and the first bar is 36 clocks wide. The routine takes Y = the number of lines and returns with `COLUBK` black. The burn-in page uses 54 bar lines after the black alignment line; the controller page 26.

#### Step 5 — The six-column text window

The text is the Lesson 63 score window. P0 is at TIA X=56 with three close copies (56, 72, 88); P1 is at 64 (64, 80, 96); NUSIZ=3 and VDEL are on; the six columns are **contiguous**, so a word never has a gap inside it. `ScoreSetup` (the score library) positions the players and strobes the frame's only HMOVE:

```asm
    LDA #$03
    STA NUSIZ0
    STA NUSIZ1
    LDA #$01
    STA VDELP0
    STA VDELP1
    ...
    STA WSYNC
    STA HMOVE
```

`ScoreDraw` turns VDEL off at the end of every value, so `SetScoreMode` re-enables VDEL and NUSIZ before each band (and clears the playfield, so a bit-block row cannot persist behind a label). The static labels are 48-byte blocks read by the `text_line` macro, the Lesson 63 kernel:

```asm
!macro text_line .base {
    LDA #7
    STA ScoreRow
-   LDY ScoreRow
    LDA .base+0,Y
    STA WSYNC
    STA GRP0
    LDA .base+8,Y
    STA GRP1
    ...
}
```

The labels are `CART`, `TEST`, `SUM`, `RAM`, `FRAME`, `CTRL`, `JOY`, `CONS`, `FIRE`, `RLDU`, `SWCHB`. Each is one 48-byte block, and its letters occupy consecutive columns 0-3 (0-4 for FRAME and SWCHB); no word is split across bands. `CTRL` is the four-character label for CONTROLLER. Four-character words fit the visible part of the window without the ambiguous right extension a longer word would create.

#### Step 6 — The dynamic values

The four-character values are composed into the library's 48-byte `ScoreBuf` in the eight-line gap before their band. `ComposeValue` copies four glyphs into **columns 0–3**, so a value is flush left:

```asm
-   LDA (GlyphPtr0),Y
    STA ScoreBuf+0,Y
    LDA (GlyphPtr1),Y
    STA ScoreBuf+8,Y
    LDA (GlyphPtr2),Y
    STA ScoreBuf+16,Y
    LDA (GlyphPtr3),Y
    STA ScoreBuf+24,Y
    INY
    CPY #8
    BNE -
```

The gap starts a 10-tick RIOT timer (577 cycles), sets the four glyph indices, clears the players and playfield, and composes. The wait ends on line 7, so the gap is exactly eight lines; `ScoreDraw` then draws the four-column value; the value glyphs are the seven-pixel forms in PlayerFont, so the value is contiguous. The frame counter's four decimal digits are computed in VBLANK (`FrameChars`) so the gap only copies them; the checksum and PASS/FAIL setters are short. Before the checksum completes, `SetChecksumChars` fills the four indices with the blank glyph, so the four SUM cells are blank — four empty cells; the ROM has no dash glyph.

#### Step 7 — The bit-block rows and the controller legends

The controller page shows the raw bytes as playfield blocks. `BitsToPF` turns one byte into three playfield bytes with four 16-byte nibble tables:

```asm
BitsToPF:
    STA Char0
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA BitHighPF0,X
    STA BitPF0
    LDA BitHighPF1,X
    STA BitPF1
    LDA Char0
    AND #$0F
    TAX
    LDA BitPF1
    ORA BitLowPF1,X
    STA BitPF1
    LDA BitLowPF2,X
    STA BitPF2
    RTS
```

The high nibble covers bits 7–4 (bit 7 is the leftmost block, in `PF0` bit 6; bits 6–4 are in `PF1` bits 7, 5, 3); the low nibble covers bits 3–0 (bit 3 is `PF1` bit 1; bits 2–0 are `PF2` bits 0, 2, 4). `+bit_band Swcha, $FF` shows all eight `SWCHA` bits, `+bit_band Swchb, $FF` all eight `SWCHB` bits, and `+bit_band Inpt4, $80` masks `INPT4` to bit 7, because the low seven bits of `INPT4` are not defined. The **RLDU** legend under the `SWCHA` blocks is the block order (bit 7 = R, 6 = L, 5 = D, 4 = U); the **SWCHB** legend names the register, and the bit-map table in the theory section is the switch map. `CTRLPF=0` repeats the 20-chunk half, so the eight blocks appear twice (16 visible); the table and the pixel samples use the left group.

#### Step 8 — The vectors and the 4,096-byte budget

The last six bytes are the three vectors, all pointing at `Reset`:

```asm
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

The image is exactly 4,096 bytes. The font, the label blocks, the nibble tables, and the code end well before `$FFFA`; the free space is the headroom for the exercises. The build command, `npm run roms`, and `bash scripts/verify.sh` all consume the same source, and the committed `.bin` is byte-identical to the assembled image.

## What You Should See

The burn-in page starts with one black alignment line, then eight vertical colour bars across the next 54 lines: light grey, gold, orange, peach, red, pink, blue, and green, in that order. Below the bars, in white: **CART** and **TEST** — two words in the six-column window. Then **SUM** with **2769** under it, **RAM** with **PASS**, and **FRAME** with four decimal digits. The four SUM cells stay blank for the first 64 frames while the chunks are added; then the four digits appear. The frame counter advances every frame and wraps 255 -> 0.

![Stella running the Lesson 64 ROM on the burn-in page: one black line, then eight vertical colour bars (light grey, gold, orange, peach, red, pink, blue, green), then the white words CART, TEST, SUM 2769, RAM PASS, and FRAME 0092; the title bar reads Stella 7.0: "demo-64"](/images/lesson64/burn-in.png)

*`burn-in.png`: the burn-in page after the checksum finished. The host-side sum of the committed `.bin` is `$2769`, and the screen reads **2769** — high byte first. The RAM line reads PASS and the frame counter reads 0092 at the capture.*

The controller page starts with one black alignment line and a shorter bar field (26 lines), then **CTRL** and **TEST**. **CTRL** is the four-character label for CONTROLLER. **JOY** is above eight blocks (the raw `SWCHA` bits, bit 7 leftmost), and the **RLDU** legend under the blocks gives the four player-0 direction bits in block order. **CONS** is above the `SWCHB` blocks, with the **SWCHB** legend naming the register; the theory table maps each block to its switch bit. **FIRE** is above the `INPT4` block, which shows bit 7 only; with fire released the block is on. **FRAME** and the frame counter close the page.

![Stella running the Lesson 64 ROM on the controller page: CTRL, TEST, JOY with eight blocks and the RLDU legend, CONS with the console-switch blocks and the SWCHB legend, FIRE with the single bit-7 block, and FRAME 0037; the title bar reads Stella 7.0: "demo-64"](/images/lesson64/controller.png)

*`controller.png`: the controller page in the idle state (no direction, no fire, SELECT released after the startup hold). `SWCHA` is `$FF`, `SWCHB` is `$3F`, and `INPT4` bit 7 is 1. The state log below shows the same fields changing with `-holdjoy0`.*

<RomPlayer rom="/roms/part8-advanced/64-building-cartridges/demo-64.bin" title="Lesson 64 — Building Your Own Cartridge" />

The in-page Javatari player starts muted; the ROM is silent, so there is nothing to unmute. The demo is interactive in Stella. SELECT switches pages. Move the joystick on the controller page: the matching `SWCHA` block clears (the RLDU legend names the four direction blocks in order). Hold fire: the leftmost `INPT4` block clears. Pressing SELECT during play switches to the burn-in page, and RESET restarts the console; the SELECT block is observable only with the switch held across power-on — the `-holdselect` state log below records that state; the still is the idle state. RESET cannot be observed while the program runs (released = 1). The burn-in page ignores the controller; it is the ROM-and-RAM test.

The debugger tells the same story as numbers. Break at the labels the source defines:

| Checkpoint | Address | Measured | Meaning |
|---|---|---|---|
| `StartFrame` | `$F1B7` | 259/3 | the first VSYNC line (the first hit at frame 0 is the power-on partial frame) |
| `VblankStart` | `$F1C5` | 0/5 | the first VBLANK line |
| `BodyStart` | `$F22E` | 37/5 | the page dispatch |
| `OverscanStart` | `$F699` | 229/8 | the first overscan instruction (both pages) |
| `PageRead` | `$F222` | A=0 (burn-in), A=1 (controller) | the current page |
| `FrameRead` | `$F1FF` | A=1, 2, 3, ... 255 | the frame counter |
| `ChecksumRead` | `$F78A` | A=`$69` | the checksum's LOW byte; `$81` holds `$27` |
| `RamResultRead` | `$F7A5` | A=0 | PASS |
| `SwchaRead` | `$F1D7` | A=`$FF` (idle), `$EF` (up), `$AF` (up+left) | the raw `SWCHA` byte |
| `SwchbRead` | `$F1DD` | A=`$3D` (SELECT held), `$3F` (released) | the raw `SWCHB` byte |
| `Inpt4Read` | `$F1E2` | A=`$8C` (released), `$0C` (fire) | the raw `INPT4` byte; bit 7 = fire |

The state log commands used for the evidence:

```bash
ROM=docs/public/roms/part8-advanced/64-building-cartridges/demo-64.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1B7' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1C5' $ROM   # VblankStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F22E' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F699' $ROM   # OverscanStart, burn-in
stella -holdselect -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F699' $ROM   # OverscanStart, controller
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F222' $ROM   # PageRead
stella -holdselect -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F222' $ROM   # PageRead, controller
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1FF' $ROM   # FrameRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F78A' $ROM   # ChecksumRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F7A5' $ROM   # RamResultRead
stella -holdselect -holdjoy0 U -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1D7' $ROM   # SwchaRead
stella -holdselect -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1DD' $ROM   # SwchbRead
stella -holdjoy0 F -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1E2' $ROM   # Inpt4Read
```

The frame checkpoints, first hits:

```text
# StartFrame
BP:           0  38 18 -14 | Nv-BdIzC f0 ff 00 ff |    (power-on)
BP:           1 259 03 -59 | nv-BdIZc 00 00 40 ff |
BP:           2 259 03 -59 | nV-BdIZc 00 00 40 ff |
BP:           3 259 03 -59 | nv-BdIZc 00 00 40 ff |

# VblankStart
BP:           1   0 05 -53 | nv-BdIZC 00 ff 00 ff |
BP:           2   0 05 -53 | nv-BdIZc 00 00 40 ff |
BP:           3   0 05 -53 | nV-BdIZc 00 00 40 ff |

# BodyStart
BP:           1  37 05 -53 | nv-BdIZc 00 00 00 ff |
BP:           2  37 05 -53 | nv-BdIZc 00 00 40 ff |
BP:           3  37 05 -53 | nV-BdIZc 00 00 40 ff |

# OverscanStart (both pages)
BP:           1 229 08 -44 | nv-BdIZC 00 00 00 ff |
BP:           2 229 08 -44 | nV-BdIZC 00 00 00 ff |
BP:           3 229 08 -44 | nv-BdIZC 00 00 00 ff |
```

The page and the clocks:

```text
# PageRead (burn-in)
BP:           1   1 37  43 | nv-BdIZc 00 00 00 ff |
BP:           2   1 37  43 | nv-BdIZc 00 00 40 ff |

# PageRead (controller, with -holdselect)
BP:           1   1 44  64 | nv-BdIzc 01 00 00 ff |
BP:           2   1 37  43 | nv-BdIzc 01 00 40 ff |

# FrameRead (A increments every frame)
BP:           1   1 04 -56 | nv-BdIZC 01 ff 00 ff |
BP:           2   1 04 -56 | nv-BdIzc 02 00 40 ff |
BP:           3   1 04 -56 | nV-BdIzc 03 00 40 ff |

# ChecksumRead (A = the low byte, from frame 65 on)
BP:          65 144 46  70 | nV-BdIzC 69 00 00 fd |
BP:          66 144 46  70 | nV-BdIzC 69 00 00 fd |
BP:          67 144 46  70 | nV-BdIzC 69 00 00 fd |

# RamResultRead
BP:           1 178 15 -23 | nv-BdIZC 00 00 00 fd |
BP:           2 178 15 -23 | nV-BdIZC 00 00 00 fd |
BP:           3 178 15 -23 | nv-BdIZC 00 00 00 fd |
```

The input checkpoints with `-holdjoy0`:

```text
# SwchaRead, -holdjoy0 U: bit 4 (up) clears
BP:           1   0 28  16 | Nv-BdIzC ef ff 00 ff |

# SwchaRead, -holdjoy0 UL: bits 4 and 6 (up and left) clear
BP:           1   0 28  16 | Nv-BdIzC af ff 00 ff |

# SwchbRead, with -holdselect: bit 1 (SELECT) clears
BP:           1   0 37  43 | nv-BdIzC 3d ff 00 ff |

# Inpt4Read, -holdjoy0 F: bit 7 (fire) clears
BP:           1   0 45  67 | Nv-BdIzC 0c ff 00 ff |

# Inpt4Read, released
BP:           1   0 45  67 | Nv-BdIZC 8c ff 00 ff |
```

`SWCHA` is `$FF` with nothing held, `$EF` with up held, and `$AF` with up and left held. `SWCHB` is `$3D` while SELECT is held and `$3F` after it is released. `INPT4` is `$8C` released and `$0C` with fire held; only bit 7 is meaningful, and the low nibble is not a value. The hold from `-holdjoy0`/`-holdselect` lasts only the first ~25 frames — enough to produce a state-log value, not enough to survive a multi-second screenshot. That is why the controller image is the idle state and the log, not the still, is the input evidence.

The **checksum** is the one number that ties the file to the screen. The host-side calculation is ordinary Python:

```bash
python3 - <<'PY'
data = open("docs/public/roms/part8-advanced/64-building-cartridges/demo-64.bin", "rb").read()
print(len(data), hex(sum(data) & 0xFFFF))
PY
# 4096 0x2769
```

The sum is `$2769`, the display is **2769**, and the byte order is high byte first: `$81` = `$27`, `$80` = `$69`. The `ChecksumRead` checkpoint reports A = `$69`. The last chunk reads `$FFC0–$FFFF`, so the three vectors are included; the image would fail the sum if a vector byte changed.

The pixel check is a host-side sample of the committed images, not a second emulator. The window is 1010x807; the TIA area is 960x606 at `(25, 106)`. The measurements:

| Measurement | `burn-in.png` | `controller.png` |
|---|---|---|
| first visible line | black | black |
| bar runs at a mid-bar line (px) | 114, 126, 126, 126, 126, 126, 126, 90 | 114, 126, 126, 126, 126, 126, 126, 90 |
| first bar line's runs | the same eight runs | the same eight runs |
| `CART` / `TEST` | both match, distance 0 | — |
| `SUM` / `RAM` / `FRAME` | match, distance 0 | — |
| checksum cells (56/64/72/80) | 2, 7, 6, 9 (distance 0) | — |
| RAM cells | P, A, S, S (distance 0) | — |
| frame cells (56/64/72/80) | 0, 0, 9, 2 | 0, 0, 3, 7 |
| `CTRL` / `TEST` | — | match, distance 0 |
| `JOY` / `RLDU` / `CONS` / `SWCHB` / `FIRE` / `FRAME` | — | match, distance 0 |
| SWCHA blocks (bit 7 left) | — | 1,1,1,1,1,1,1,1 |
| SWCHB blocks | — | 0,0,1,1,1,1,1,1 |
| INPT4 block | — | 1,0,0,0,0,0,0,0 |
| title bar | `Stella 7.0: "demo-64"` | `Stella 7.0: "demo-64"` |

The bar runs are the eight vertical bars in the capture: the first is 19 colour clocks wide (114 px at 6 px per clock), the six inside bars 21 clocks (126 px), and the last 15 clocks (90 px). The first bar line's runs are identical to a mid-field line, which is the alignment evidence: the entry `STA WSYNC`/`BIT`/`NOP` puts the body at cycle 5 and the first bar-defining store at hit 22. The static labels are read with the five-pixel letter forms and the four-character values with the seven-pixel value glyphs, top row = byte 7; every label and both values match at distance 0. The frame cells read 0092 (burn-in) and 0037 (controller). The title bar is checked from the window name, not from the pixels, because the emulator's title font is not the ROM's font; the name read from the live window was `Stella 7.0: "demo-64"` for both captures.

> **Capture method.** The two images are window captures of
> `docs/public/roms/part8-advanced/64-building-cartridges/demo-64.bin` in Stella 7.0,
> using the same `import -window` pipeline as `scripts/capture-screenshot.sh`
> after parking the pointer at `(0, 0)` (no cursor appears in either image).
> The burn-in waited **2.5 seconds** of wall clock (including Stella's window
> startup); the controller was captured earlier, at FRAME 0037, once the page
> was stable. Both used `-uimessages 0` so Stella's on-screen message overlay is
> absent.
> The checksum finishes at frame 65 (about 1.1 s); the burn-in image's counter
> reads 0092 — 92 emulated frames, a completed checksum, and still before the
> 8-bit counter wraps at 256. `controller.png` was launched with `-holdselect`; the SELECT edge switches
> to page 1 on the first frame and the page stays. The `-holdselect` hold lasts
> only the first ~25 frames, so the capture is the idle state: `SWCHA` `$FF`,
> `SWCHB` `$3F`, `INPT4` bit 7 = 1, at frame 0037. The held-input states are
> recorded in the state log above, not in the still. The window title was read
> from the live window (`xdotool getwindowname`) and reads
> `Stella 7.0: "demo-64"` for both. The TIA area is 960x606 at `(25, 106)`; the
> pixel samples are taken from that area. The two images differ in page content
> and in the length of the bar field.

## Exercises

This is a production lesson: the demo ROM is the artifact, and the three exercises are answered here. Each answer names the hooks in the source and what a builder changes when the same test is added to their own cartridge. The exercises are about the production decisions, not new kernel tricks.

### Exercise 1: Add the checksum

**Challenge:** Add a runtime 16-bit checksum to your own 4K cartridge ROM. It must read the **whole** image, including the three vectors, display the result as four hex digits, and match a host-side calculation of the committed `.bin`. Keep the frame at 262 lines and the ROM at 4,096 bytes.

**Hints:**
1. The checksum is a 16-bit sum: `Sum = (Sum + byte) & $FFFF` for `$F000` through `$FFFF`. It is not a CRC; it is enough to catch a blank chip, a wrong image, or a changed vector.
2. The read is 4,096 bytes, which is 64 chunks of 64 bytes. A chunk costs about **1,620 cycles on average and 1,750 worst**; the overscan's 30 lines are about 2,240 cycles, so the margin is about 490 cycles. `CsPtr` starts at `$F000` and `CsCount` at 64.
3. The display order is high byte first: high nibble, low nibble, low byte's high nibble, low byte's low nibble. The host-side Python must use the same `& $FFFF` sum and must read the **committed** `.bin`, not a scratch build.

**Expected Result:** The four digits on screen equal the host-side sum, e.g. `$2769` -> **2769**; the four SUM cells stay blank until the last chunk; the frame remains 262 lines; the ROM is 4,096 bytes.

**Answer:** The reference implementation is `Checksum` (`$80/$81`), `CsPtr` (`$88/$89`), `CsCount` (`$8A`), `ChecksumChunk` (called from `OverscanStart`), `SetChecksumChars` (called in the value gap), and the score window's `ComposeValue`/`ScoreDraw`. A builder integrating it into their own ROM reserves two zero-page bytes, initialises the pointer to `$F000` and the count to 64 in the reset code, calls the chunk routine from overscan (or from VBLANK if the overscan is full), and displays the two bytes in the high-first order. The important choices are: read the whole image, including `$FFFA–$FFFF`; use the same algorithm on the host; and do not run the sum in the visible kernel, where the 76-cycle line has no room for a 64-byte loop. If the ROM is not 4K, the pointer range and the count change, but the idea is the same: cover the image the console actually reads.

### Exercise 2: Add the RAM test

**Challenge:** Add a RIOT RAM test to your own ROM. Write `$A5` and `$5A` to a few free bytes, read them back, and show PASS or FAIL. Run it before the program trusts its variables, and do not collide with the stack or the variables that store the result.

**Hints:**
1. The RIOT's 128 bytes are `$80–$FF`. The stack lives in the same page (`$F8–$FF` in this course's convention). Pick four free bytes — this lesson uses `$99–$9C` — and keep them out of the variables and the stack.
2. The test is a write, a read, and a compare. Two complementary patterns (`$A5`/`$5A`) catch a stuck bit in both directions; a single pattern can miss a bit stuck at the pattern's value.
3. `RamResult` is 0 for PASS and 1 for FAIL, and the score window composes the word PASS or FAIL from four glyph indices. The test runs once, after `+clean_start`, so the bytes start at zero.

**Expected Result:** The RAM line reads PASS in Stella; a deliberately corrupted read (for example, comparing against the wrong value) shows FAIL; the test does not corrupt the program's variables; the frame remains 262 lines.

**Answer:** The reference implementation is the reset block from `LDA #$A5` to `STA RamResult`, the `RamResult` byte at `$82`, and `SetRamChars` with the `PassGlyphs`/`FailGlyphs` tables, composed into the score window. A builder copies the pattern into four free bytes, compares each byte, stores 0 or 1, and shows the word. The pitfalls are the ones the course has already met: the stack shares the RAM, so a deep call chain can overwrite the test bytes; the test must run before the variables are trusted; and a failing test should not be hidden behind a later `+clean_start`. If the test fails on a real console, the RIOT is the suspect, but check the collision first.

### Exercise 3: Add the controller test

**Challenge:** Add a controller test to your own ROM: read the raw `SWCHA`, `SWCHB`, and `INPT4` bytes every frame, show them as hex or bit patterns, and name a few bits (P0 up/down/left/right, fire, SELECT, RESET, COLOR/B&W). Keep the frame at 262 lines and the ROM at 4,096 bytes.

**Hints:**
1. `SWCHA` and `SWCHB` are **active low**: a pressed direction or switch reads 0. `SWCHA` bits 7/6/5/4 are player 0 right/left/down/up; bits 3–0 are player 1. `SWCHB` bit 0 is RESET, bit 1 is SELECT, bit 3 is COLOR (1) / B&W (0), bits 6–7 are the difficulty switches, and bits 2, 4, 5 are unused.
2. `INPT4` bit 7 is player 0 fire; 0 while the button is held. **Only bit 7 is defined**; the low seven bits are not reliable, so mask them off (`AND #$80`) before displaying the byte.
3. The demo shows the bytes as eight playfield blocks, bit 7 leftmost, with the static `RLDU` and `SWCHB` legends under the blocks. `BitsToPF` and the four nibble tables turn a byte into the three playfield bytes; the `text_line` macro draws the legends. `CTRLPF=0` repeats the half, so the eight blocks appear twice; the left group is the one the table maps.

**Expected Result:** With a joystick, the matching `SWCHA` blocks clear; with fire, the leftmost `INPT4` block clears; with SELECT held across power-on (`-holdselect`), the SELECT `SWCHB` block clears. RESET restarts the console, so its block cannot be observed while the program runs (released = 1); the state log is the evidence. The frame remains 262 lines.

**Answer:** The reference implementation is `SwchaRead`/`SwchbRead`/`Inpt4Read` in VBLANK, the `+bit_band` calls on the controller page, `BitsToPF`, and the static `LabelRldu`/`LabelSwchb` blocks. The `RLDU` legend is the block order of the four P0 direction bits; the `SWCHB` legend names the register, and the bit-map table in the theory section maps each block to its switch bit. A builder can choose hex instead of blocks: compose two hex digits from the byte with the same nibble split the checksum uses, and keep the labels. The active-low convention is the most common bug: a beginner writes `AND #$10` and treats a nonzero result as "up pressed", which is the opposite of the hardware. The second common bug is displaying all eight `INPT4` bits; the low seven are not a value. The third is forgetting that a held switch is a level, not an edge: if you want one action per press, keep a `Prev*` byte as the demo does for SELECT.

## Key Takeaways

- ✅ A 4K cartridge is a 4,096-byte image in the `$F000–$FFFF` window, with the three vectors at `$FFFA–$FFFF`; a 4K board has no mapper.
- ✅ The physical pipeline is PCB, ROM chip, programmer, socket/shell, soldering, label, and the power-on test; the `.bin` is the data that moves between every stage.
- ✅ The SST39SF010A is a 5 V, 1 Mbit (128 KB) flash chip; a 4K image uses about 3 percent of it, and the programmer's verify proves the chip, not the cartridge.
- ✅ A burn-in test checks the ROM (a 16-bit sum including the vectors), the RIOT RAM (write/read `$A5`/`$5A`), the controllers, and the frame; it is deliberately boring so a change is meaningful.
- ✅ `SWCHA` and `SWCHB` are active low, and `INPT4` has only bit 7 defined; the display must mask `INPT4` and treat a pressed direction as 0.
- ✅ A flash cart (Harmony, UnoCart) is a reusable development tool; a production cart is one ROM on one PCB with a shell and a label. The same `.bin` runs on both.
- ✅ This repository has not built a physical cartridge; the ROM, the screenshots, the state logs, and the host-side checksum are the verification, and the physical steps are the procedure a builder performs.

## What's Next

The next lesson makes the cartridge work on every TV: [Lesson 65: PAL/NTSC Universal ROM — One Cart, Every TV](/part8-advanced/65-pal-ntsc-universal) covers the 262/312-line frame, the PAL palette, why a stock 2600 cannot auto-detect the TV system, and a title-screen selector that ships one cart for both regions.
