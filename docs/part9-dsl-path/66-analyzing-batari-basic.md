---
title: "Lesson 66: Analyzing batari BASIC — How bB Works"
description: "Read a real batari BASIC 1.9 compilation: the four-stage pipeline, the generated start/drawscreen/2-line kernel/vblank hook/overscan, the lowered if and BCD score, the fixed zero-page variable map, and a three-lens auto-advancing demo that maps the frame, the RUN picture, and the 128 RIOT RAM bytes."
prev:
  text: "Lesson 65: PAL/NTSC Universal ROM — One Cart, Every TV"
  link: "/part8-advanced/65-pal-ntsc-universal"
next:
  text: "Lesson 67: Identifying Automatable Patterns — A Wave Compiler"
  link: "/part9-dsl-path/67-automatable-patterns"
---

# Lesson 66: Analyzing batari BASIC — How bB Works

> **Part 9: The DSL Path** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and memory), Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players), Lesson 26 (positioning), Lesson 39 (the score kernel), Lesson 48 (the kernel taxonomy), Lesson 55 (scrolling text), Lesson 62 (reverse engineering), Lesson 63 (the score library)
> **You will learn:** the bB four-stage pipeline (preprocess → compile → link → assemble); the `.bas` → `bB.asm` → linked `.asm` → `.bin` artifacts; the generated `start` (the RAM probe, the memory clear, the kernel); `drawscreen`; the 2-line kernel; the `vblank_bB_code` hook; the overscan; how assignment, `if`, arithmetic, the BCD score, `drawscreen`, and `goto` lower to 6502; the fixed zero-page variable map; bB's strengths and limits; and when to hand-write assembly
> **You will build:** no new game this time. The artifact is the analysis: a course-authored `lesson66.bas` that compiles with bB 1.9 to a 4,096-byte reference ROM and a committed generated listing, plus the hand-written `demo-66.asm` — the **bB anatomy viewer**, a 4,096-byte ACME ROM with three lenses that SELECT or a four-second auto-demo advances. The demo is not bB output, and it carries no text labels or legend: the pictures and the lesson's tables carry the meaning.

## Introduction

Every lesson so far has ended with code you wrote: 6502 instructions, a frame skeleton, a kernel you counted cycle by cycle. batari BASIC (bB) starts from the other end. You write `player0y = player0y + 1`, `if player0y > 120 then player0y = 60`, `score = score + 1`, `drawscreen`, and `goto main`; bB generates the frame, the kernel, the score window, the sprite positions, and the 6502 that makes them happen. The trade is the one every high-level tool makes: you give up direct control of the beam, and you get a working game in a few dozen lines.

The tool is real, and this lesson reads a real compilation. The course-authored `lesson66.bas` is 75 lines. bB 1.9 (the wasm build) with wasmtime 50.0.1 turns it into a 4,096-byte ROM and a 44,000-byte linked assembly listing, and the listing is committed as `lesson66.generated.txt` so every claim below can be checked line by line. The listing is DASM syntax, not ACME: it is evidence, not a course build. The reference ROM (`lesson66-bb.bin`) is committed beside it and runs in the player at the end of this page.

The lesson's companion is the **bB anatomy viewer**, a hand-written 4,096-byte ACME ROM. It is deliberately *not* generated code. Its three lenses — SELECT or a four-second auto-demo — show the three layers bB manages: the RUN picture (a starfield, a green ship, a gold enemy, and a white ball, echoing the bB sample's objects), the ZONES frame map (the 3 VSYNC / 37 VBLANK / 192 picture / 30 overscan phases projected into the visible window), and the VARS RAM map (a 16×8 grid of the 128 bytes at `$80-$FF`, with the bB variable groups encoded by the cell bar heights). The bB reference ROM and the demo are separate artifacts; the document says which is which at every step. The demo carries no text labels and no legend: the pictures and the lesson's tables carry the meaning.

::: details TypeScript Equivalent

Think of bB as a tiny compiler with a very small target. Here is a TypeScript model of two of its lowerings — the `if` and the score update — and of the fixed frame the generated code assumes:

```typescript
type Expr = number | { var: string } | { add: [Expr, Expr] };
type Stmt =
  | { kind: 'assign'; name: string; value: Expr }
  | { kind: 'ifGt'; name: string; limit: number; then: Stmt }
  | { kind: 'scoreAdd' }
  | { kind: 'drawscreen' }
  | { kind: 'goto'; label: string };

// bB's real if-lowering.  The branch is taken when the condition is FALSE:
// CMP computes limit - player0y and sets carry when limit >= player0y, so
// BCS skips the body for every value that is not strictly greater.
function lowerIfGt(name: string, limit: number, body: Stmt): string[] {
  return [
    `    LDA #${limit}`,
    `    CMP ${name}`,
    `    BCS .skip`,
    ...lower(body),
    `.skip:`,
  ];
}

// bB keeps the score as three BCD bytes at score, score+1 and score+2.
// Decimal mode makes each byte a pair of decimal digits; the carry chain
// runs from the ones byte to the hundreds byte.
function lowerScoreAdd(): string[] {
  return [
    '    SED',
    '    CLC',
    '    LDA score+2', '    ADC #$01', '    STA score+2',
    '    LDA score+1', '    ADC #$00', '    STA score+1',
    '    LDA score',   '    ADC #$00', '    STA score',
    '    CLD',
  ];
}

// The "frame" is not a function of the program's data: it is a fixed kernel.
// drawscreen is a JSR into that kernel; the kernel reads the fixed RAM map.
function frame(game: { player0y: number; player1y: number; score: number[] }): void {
  // 2-line kernel: every sprite row is drawn twice; the playfield is 4-pixel
  // chunks; the score is six 8-pixel columns.  There is no framebuffer.
}
```

The model captures the shape — a statement list, an expressions-to-instructions function, a fixed draw call — and it breaks in the places that define the 2600. There is no object or array at run time: the "variables" are fixed bytes at `$80-$FF`, and a name is only a compile-time alias. The `if` branch is reversed because 6502 `CMP` reports `>=`, not `>`. The score is not a number: it is three BCD bytes, and `SED`/`CLD` bracket the add. The frame is not a function you can rewrite: bB ships a fixed 2-line kernel, and `drawscreen` hands the beam to it. And the real tool is a **pipeline**, not a single `lower()`: a preprocessor, a compiler, a linker, and DASM each produce a different artifact.

:::

## Theory

### Section 1: The Four Stages and the Artifacts

bB is not one program. `2600basic.sh` runs four stages, and each one leaves a file you can read:

| Stage | Tool (bB 1.9) | Input | Output |
|---|---|---|---|
| 1. Preprocess | `preprocess.wasm` | `lesson66.bas` | the token stream on standard input |
| 2. Compile | `2600basic.wasm` | the token stream | `bB.asm` (the user program's 6502) |
| 3. Link | `postprocess.wasm` | `bB.asm` + the includes | `lesson66.bas.asm` (the linked listing) |
| 4. Assemble | `dasm.wasm` | `lesson66.bas.asm` | `lesson66.bas.bin` (4,096 bytes) |

The compiler writes `lesson66.bas.bin`; the course renames its committed copy to
`lesson66-bb.bin` so the compiler output is never confused with the ACME demo
`demo-66.bin`. The same compile also writes the address listing
`lesson66.bas.list.txt`, the symbol table `lesson66.bas.symbol.txt`, and the
variable-redefs header `2600basic_variable_redefs.h`.

The compile command used for the committed artifacts was:

```bash
export bB=<path-to-bB-1.9>
export PATH=<path-to-wasmtime-50.0.1>:$PATH
sh "$bB/2600basic.sh" lesson66.bas
```

The toolchain is not vendored in the repository. bB is GPL software; the bB README says the GPL does not apply to games created with bB, and the generated assembly is CC0. The course commits the **input** (`lesson66.bas`), the **linked listing** (`lesson66.generated.txt`), the compiler's **address listing** (`lesson66.bas.list.txt`, 154,577 bytes), the **symbol table** (`lesson66.bas.symbol.txt`, 20,075 bytes), the **variable-redefs header** (`2600basic_variable_redefs.h`, 105 bytes), and the **reference ROM** (`lesson66-bb.bin`); it leaves the compiler out. `npm run roms` never runs bB: it builds the 244 ACME sources, and the bB reference is a separate, manually produced artifact. That is why the reference ROM is not drift-checked by `scripts/verify.sh`; the listing, the address/symbol files, and the `.bas` are the reproducible evidence.

The compile reports:

```text
  basic version:  batari Basic v1.9 (c)2025
  dasm version:  DASM 2.20.15-SNAPSHOT
2600 Basic compilation complete.
      2697 bytes of ROM space left
```

The final listing is 44,000 bytes and 2,159 lines **with the committed header**; without the header the compiler's own file is 43,085 bytes and 2,144 lines. The `.bin` is 4,096 bytes. The header names the toolchain and the command; it is a comment block, so the listing still begins with bB's own `; Provided under the CC0 license...` line after it.

::: tip The listing is DASM, the demo is ACME
The generated listing uses DASM syntax (`.byte`, `.word`, `ORG`, `processor 6502`). It cannot be assembled by ACME, and the project does not try: committing it as a `.asm` would make `scripts/verify.sh` fail. It is committed as `lesson66.generated.txt` and quoted; the course's build path stays ACME. This is also why the reference ROM is not in the `npm run roms` drift check.
:::

### Section 2: The Generated `start` — a RAM Probe, a Clear, and a Kernel

The 6507 reads the RESET vector at `$FFFC` and jumps to `start` at `$F000`. The generated prologue is the same every bB program gets:

```asm
start
 sei
 cld
 ldy #0
 lda $D0
 cmp #$2C               ;check RAM location #1
 bne MachineIs2600
 lda $D1
 cmp #$A9               ;check RAM location #2
 bne MachineIs2600
 dey
MachineIs2600
 ldx #0
 txa
clearmem
 inx
 txs
 pha
 bne clearmem
 sty temp1
```

These are lines 51-70 of the committed listing. The prologue does four things:

1. **`sei` / `cld`** — disable interrupts and clear decimal mode. The 6507 has no interrupts, but a stray NMI or IRQ would use the same `start` vector; `cld` matters because the score later relies on decimal mode being off until it turns it on deliberately.
2. **The RAM probe** — read `$D0` and `$D1`, compare them with `$2C` and `$A9`. If both match, the code falls through to `dey`, leaving Y=`$FF`; otherwise Y stays 0. The result is stored in `temp1` at line 70 (`sty temp1`). This is a two-byte signature probe in the generated startup; the lesson records what the code does, not a guessed reason for the two constants.
3. **The clear loop** — `ldx #0 / txa / clearmem: inx / txs / pha / bne clearmem`. A=0, X counts up; `txs` moves X to the stack pointer, and `pha` writes A to the stack page. The loop walks the stack page, zeroing it, and wraps when X returns to 0. The same 128 bytes are the RIOT RAM, so the clear covers the variables and the stack.
4. **The kernel's starting state** — `playfieldpos` is initialised to 8 (the kernel's starting row position; the `pfres` branch would change it), the six score pointers are initialised from `scoretable`, `CTRLPF` is set to 1, and `rand` is seeded from the timer. Then `jmp game` (line 99) enters the user program. The `.bas` uses bB 1.9's default **eleven-row** playfield; eleven rows of thirty-two chunks fill 44 of the 48 playfield bytes at `$A4-$D3`, and this sample's playfield is empty (all dots), so the reference screen shows no playfield block.

The prologue is the first thing a bB program does, and it is the first thing a reader of the listing should find. The `start` label is at `$F000`; the `kernel` label is at `$F034`; the user's `game` label is at `$F45F`; the user's `.main` is at `$F4D0`. Those four addresses are the skeleton of the ROM.

::: warning The stack is not a separate memory
The 2600 has 128 bytes of RAM at `$80-$FF`, mirrored into the stack page. bB's `start` uses `txs`/`pha` to clear the stack page; the same bytes are the variable area. The bB header reserves the top of the map for the stack (`stack1` at `$F6`, `stack2` at `$F7`, ...), and a deep call chain can collide with the variables. The course's demo keeps its stack at `$F8-$FF` for the same reason.
:::

### Section 3: `drawscreen`, the 2-Line Kernel, the `vblk` Hook, and the Overscan

The generated kernel announces itself at line 112 of the committed listing:

```asm
     ; This is a 2-line kernel!
     ifnconst vertical_reflect
kernel
     endif
     sta WSYNC
     lda #255
     sta TIM64T
```

The `kernel` label is at `$F034`. The `sta WSYNC` starts the first visible line, `lda #255 / sta TIM64T` arms the RIOT timer for the visible area, and the 2-line loop draws every logical row twice. The kernel is fixed: it reads the player/playfield/score state from the zero-page map and paints it; the program does not supply a kernel function. That is the central trade of bB.

The user's `drawscreen` call is at line 1879:

```asm
 jsr drawscreen
```

and `drawscreen` is at `$F3BF`. The label is followed by two conditional blocks:

```asm
drawscreen
     ifconst debugscore
         ...
     endif
     ifconst debugcycles
         ...
     endif
overscan
     ifconst interlaced
         ...
     endif
overscanloop
     lda INTIM ;wait for sync
     bmi overscanloop
doneoverscan
     ;do VSYNC
```

The `debugscore` and `debugcycles` blocks are compiled out in this build, so `drawscreen` and `overscan` are the **same address** (`$F3BF`). The `overscanloop` waits for the **visible-area timer** that `kernel` armed (`lda #255 / sta TIM64T`); after that wait the routine performs the VSYNC and reaches the VBLANK hand-off:

```asm
vblk
     ; run possible vblank bB code
     ifconst vblank_bB_code
         jsr vblank_bB_code
     endif
vblk2
     LDA INTIM
     bmi vblk2
     jmp kernel
```

These are lines 1634-1642. The `vblank_bB_code` hook is present as an `ifconst` block; this program never defines `vblank_bB_code`, so the `jsr` is not assembled, but the hook is the place a bB program would put its own VBLANK code (positioning, game logic, sound). `vblk2` polls `INTIM` until the VBLANK timer expires and then jumps to the kernel. The bB frame is therefore the course's frame with different names: `vblk` is the VBLANK hand-off, `kernel` is the visible kernel, `overscan` is the wait/VSYNC hand-off, and the user's `drawscreen` is a `JSR` into that cycle.

The bB reference state log shows the anchors on the real ROM:

```text
# vblk (the VBLANK hand-off)
BP:           1   9 50  82 | Nv-BdIzc 9c 9c 9c fd |

# kernel (the 2-line kernel entry)
BP:           1  31 32  28 | nv-BdIzc 7f 9c 9c fd |

# overscan / drawscreen (the user's JSR into the hand-off)
BP:           0  47 36  40 | nv-BdIZc 00 0d 00 fd |
```

The `vblk` line is 9, the kernel entry is line 31, and the `drawscreen`/`overscan` entry is line 47: the generated VBLANK, kernel, and overscan are real, named, and visible in the debugger. The bB kernel is a 2-line kernel; the picture is 192 visible lines, and the frame is the NTSC 262-line frame.

What does the 2-line kernel buy and cost? It buys **time**: two scanlines per logical row give the kernel twice the cycles to load and store the sprite and playfield bytes, and a simple loop that repeats the same work. It costs **vertical resolution**: a player's 8-pixel-wide row is two scanlines tall, so a 6-row sprite is 12 scanlines; a playfield row is two lines; the score's 8 rows are 16 lines. It also fixes the kernel's shape: the score, the playfield, the players, the missiles and the ball all have a place in the generated loop, and a program that wants a mid-line colour change or a different number of score rows is outside what the kernel offers. That is when a hand-written kernel takes over.

::: tip `drawscreen` is not a framebuffer flip
On a modern system `drawscreen` would present a buffer. On the 2600 it is a `JSR` into a routine that waits for the visible-area timer, starts the next frame's VSYNC, and jumps into the fixed 2-line kernel. The program's state is the RAM map; the "frame" is the kernel's read of that state, line by line, as the beam moves.
:::

### Section 4: The Lowering of Assignment, `if`, Arithmetic, the BCD Score, and `goto`

The user program is the `main` loop at lines 1832-1882. It is short, and every line has a generated counterpart:

| Source (line) | Generated (lines) | What changed |
|---|---|---|
| `COLUBK = $02` (1835) | `LDA #$02 / STA COLUBK` (1837-1838) | an immediate load and a TIA store |
| `player0y = player0y + 1` (1851) | `INC player0y` (1853) | the compiler recognises `x = x + 1` |
| `if player0y > 120 then player0y = 60` (1854) | `LDA #120 / CMP player0y / BCS .skipL038 / LDA #60 / STA player0y` (1856-1862) | a reversed branch |
| `score = score + 1` (1863) | `SED / CLC / LDA score+2 / ADC #$01 / STA score+2 / LDA score+1 / ADC #$00 / STA score+1 / LDA score / ADC #$00 / STA score / CLD` (1865-1876) | a 3-byte BCD add |
| `drawscreen` (1877) | `jsr drawscreen` (1879) | a call into the fixed frame |
| `goto main` (1880) | `jmp .main` (1882) | a direct jump |

The `if` is the one that surprises readers. The source says "if `player0y` is greater than 120, set it to 60". The generated code does **not** branch when the condition is true; it branches when the condition is false:

```asm
	LDA #120
	CMP player0y
     BCS .skipL038
.condpart0
	LDA #60
	STA player0y
.skipL038
```

`CMP player0y` computes `120 - player0y` and sets the carry flag when `120 >= player0y`, i.e. when `player0y <= 120`. `BCS` takes the branch to `.skipL038` when the carry is set, i.e. when the condition is *not* strictly greater. The assignment runs only when `player0y > 120`. This is the standard 6502 way to write a strict `>`: compare the limit with the variable and branch on the **false** side. The branch target is a 4-byte forward branch (`BCS .skipL038` at `$F4E6`, operand `$04`, target `$F4EC`). The condition is strict: at `player0y = 120`, the carry is set and the assignment is skipped; only 121 and above wrap to 60.

The score is three bytes at `$93-$95`, but they are **BCD**, not binary. `SED` turns decimal mode on; `CLC` clears the carry; the `ADC` chain adds 1 to `score+2` (the ones byte), carries into `score+1` (the tens), and carries into `score` (the hundreds). `CLD` turns decimal mode off. A score of 000199 plus one becomes 000200, not the binary `$00C8`. The bB score window reads these three bytes through the `scorepointers` and the `scoretable` font; the `player0y`/`player1y` bytes are ordinary binary, which is why the `if` uses a plain `CMP`.

`goto main` is `jmp .main`; `drawscreen` is `jsr drawscreen`. There is no optimizer hiding a call graph: the `.L0xx` labels and the `;;line N;;` comments map every generated block to the source line that produced it. That mapping is the reader's best tool.

### Section 5: The Fixed Zero-Page Variable Map

bB does not allocate variables dynamically. The compiler reserves a fixed map in the RIOT RAM, and every program uses the same addresses. The bB 1.9 symbol file for this program gives the addresses. The table below is a **selected** map: it names the symbols the lesson's analysis needs, not every alias. The committed `lesson66.bas.symbol.txt` is the complete list.

| Symbol | Address | Meaning |
|---|---|---|
| `player0x` | `$80` | player 0's horizontal position |
| `player1x` | `$81` | player 1's horizontal position |
| `ballx` | `$84` | the ball's horizontal position |
| `player0y` | `$85` | player 0's vertical position |
| `player1y` | `$86` | player 1's vertical position |
| `bally` | `$89` | the ball's vertical position |
| `player0pointer` | `$8A-$8B` | the player 0 graphics pointer |
| `player1pointer` | `$8C-$8D` | the player 1 graphics pointer |
| `player0height` | `$8E` | the player 0 height |
| `player1height` | `$8F` | the player 1 height |
| `ballheight` | `$92` | the ball height |
| `score` | `$93-$95` | the three BCD score bytes |
| `scorepointers` | `$96-$9B` | six score-column pointers |
| `temp1`-`temp6` | `$9C-$A1` | kernel temporaries |
| `rand` | `$A2` | the random seed |
| `scorecolor` | `$A3` | the score colour |
| `var0`-`var47` | `$A4-$D3` | the playfield array / the first 48 user variables |
| `a`-`z` | `$D4-$ED` | the 26 single-letter variables |
| `temp7` / `playfieldpos` | `$EE-$EF` | the bankswitch temporary / playfield position |
| `aux1`-`aux6` | `$F0-$F5` | the optional lives/status/colour pointers |
| `stack1`-`stack4` | `$F6-$F9` | the kernel's stack bytes |

The omitted aliases include the missile variables (`missile0x` `$82`, `missile0y`
`$91`, `missile1x` `$83`, `missile1y` `$88`, `missile0height` `$90`,
`missile1height` `$87`), the paddle/lives/status names (`paddle` `$91`,
`currentpaddle` `$90`, `lives` `$F3`, `lifepointer` `$F2`, `lifecolor` `$F4`,
the `pfscore` names), the player-colour aliases (`player0color` `$90`,
`player1color` `$87`), and `objecty` (`$85`, the `player0y` alias). The wider bB
family also has multi-player aliases (`player2x/y`, `player3x/y`,
`player2height`/`player3height`); bB 1.9's two-player header does not emit them
for this build, and the committed symbol file is the authority.

The committed `2600basic_variable_redefs.h` for this program is only:

```text
; This file contains variable mapping and other information for the current project.

no_blank_lines = 1
```

The map itself is in `2600basic.h` in the bB includes; the committed symbol file repeats the addresses. This is why the bB program's `.bas` has no declarations for `player0y` or `score`: the names are predefined. A `dim` statement does not allocate RAM; it adds a **compile-time alias** for one of the bytes that are already reserved. `dim frame = a` makes `frame` another name for `$D4`; it costs no RAM because the 26 letters are already in the map. The demonstration's VARS lens draws exactly this map.

::: warning The map is version-specific
The addresses above are bB 1.9's. A future bB could move `temp1` or the `a`-`z` block, and a program that peeks at them would break. The lesson pins 1.9 and quotes the committed symbol file, not a generic claim. The same discipline applies to the generated listing: the line numbers in this document are the committed `lesson66.generated.txt`, header included.
:::

### Section 6: bB's Strengths, Its Limits, and When to Drop to Assembly

bB's strengths are real:

- **Fast iteration.** A playable 4K program is a few dozen lines; the kernel, the score, the frame, and the sprite positioning are already there.
- **Readable output.** Every generated block is labelled with its source line. A reader can follow `score = score + 1` into the BCD chain and back.
- **A fixed map and a fixed frame.** The 2-line kernel and the zero-page map are stable, so a program can rely on them and the community's examples transfer.
- **The 4K/8K/16K/32K sizes.** `set romsize` picks the cartridge; the compiler and the linker handle the mapper.

The limits are just as real:

- **The kernel is fixed.** The score is 8 rows, the playfield is 4-pixel chunks, the players are 8 pixels wide; a mid-line colour change or a custom status bar is outside the generated loop.
- **The 2-line resolution.** A sprite row is two scanlines, so a 6-row player is 12 lines and the vertical detail is half the 1-line kernel's.
- **Per-statement cost.** `score = score + 1` is a twelve-instruction sequence: three load/add/store triples plus `SED`, `CLC`, and `CLD`. An `if` is a reversed compare and a branch; every assignment is a load and a store. In a tight kernel those costs add up.
- **The 128-byte map.** `temp1`-`temp6` are the kernel's; the `a`-`z` block is 26 bytes; the playfield array is 48 bytes. A larger game runs out of variables before it runs out of ROM.
- **Version-specific output.** The listing and the map change with the compiler; the lesson's quotes are bB 1.9's.

When should you drop to assembly? When the kernel's shape is the problem: a mid-line colour change, a one-line sprite kernel, a precise multiplexer, a custom mapper, a status bar that is not the score, or the last few bytes of a 4K image. The demo in this lesson is hand-written ACME for exactly that reason: it wants three different pictures from one frame, with a mid-line playfield split in the VARS grid and a 2-line-free RUN picture. bB would not generate those kernels; the demo's code shows what the generated code would have to become.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just the demo:
acme -f plain -o build/demo-66.bin \
  lessons/part9-dsl-path/66-analyzing-batari-basic/demo-66.asm
stella build/demo-66.bin
```

The committed ROM is `docs/public/roms/part9-dsl-path/66-analyzing-batari-basic/demo-66.bin`, 4,096 bytes. The reference build is `lesson66-bb.bin` in the same directory, also 4,096 bytes; it is produced by bB 1.9, not by `npm run roms`, and the document gives the exact command. The compiler writes `lesson66.bas.bin`; the committed copy is renamed `lesson66-bb.bin`. The generated listing is `lessons/part9-dsl-path/66-analyzing-batari-basic/lesson66.generated.txt`; the `.bas`, the address listing `lesson66.bas.list.txt`, the symbol table `lesson66.bas.symbol.txt`, and `2600basic_variable_redefs.h` are beside it.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 66 DEMO: The bB Anatomy Viewer
; =============================================================================
; Part 9: The DSL Path
;
; What this program does:
;   A hand-written ACME demo that visualizes how batari BASIC works.  It is
;   NOT bB output and it is NOT generated code: the real bB 1.9 compilation
;   is the separate lesson66.bas / lesson66.generated.txt / lesson66-bb.bin
;   reference.  This ROM is the teaching model.
;
;   Three lenses, selected by SELECT or by the auto-demo:
;     Lens 0 RUN   - a 16-line band (a 3-line gold bar + the white six-digit
;                    frame counter) over a 176-row picture: 5 position/setup
;                    rows, the 168-row starfield loop (Y=6..173), two blank
;                    spacer rows, and the StarLast row.  The picture is a
;                    starfield playfield, a green P0 ship that auto-pans, a
;                    gold P1 enemy, and a white ball.  The objects echo the
;                    bB sample's player0/player1/ball.  There is no text.
;     Lens 1 ZONES - the frame map: 192 visible lines as a teaching
;                    projection of VSYNC (3 white), VBLANK (37 blue), the
;                    kernel (192 compressed to 122 green), and overscan
;                    (30 red).  A white row bar steps right one playfield
;                    chunk every eight rows; the repeat playfield draws the
;                    same staircase in both 80-pixel halves.  There is no text; the lesson
;                    names the phases.  The blanked phases are NOT visible
;                    on a TV; the map compresses the kernel into the lines
;                    the visible window has room for.
;     Lens 2 VARS  - a 16-line band (a 3-line gold bar + the six-digit
;                    group/address window) over a 16x8 grid of the 128 RIOT
;                    RAM bytes $80-$FF.  Every cell is one byte, drawn as a
;                    four-pixel bar whose height is the group code: SYS is
;                    eight lines, SCR seven, PTR six, TMP five, RND four,
;                    PF three, DIM two; AUX is the top dot and STK the
;                    bottom dot.  Each grid row is nine display lines (a
;                    preload line that repeats the first cell line, then the
;                    eight cell lines) plus two dark gap lines: 8 x 11 = 88.
;                    An 8-pixel ball makes the selected row a solid white
;                    block over those nine lines; it spans the 4-pixel cell
;                    and the 4-pixel gap after it.  The six-digit window
;                    shows the group code in the digit to the left of the
;                    two hex digits of $80 + MapIndex (for example 0 8 0 is
;                    group 0, SYS, at $80).  There is no legend text; the
;                    lesson's table maps the groups.
;
;   Auto-demo: a 240-frame (about four-second) timer advances the lens
;   0 -> 1 -> 2 -> 0 when no SELECT has been pressed; any SELECT edge
;   advances the lens immediately and resets the timer.  A fixed wait is
;   therefore deterministic: about 2 s is RUN, 6 s is ZONES, 10 s is VARS.
;   The auto-demo only changes Lens at a frame boundary; the frame stays
;   262 lines.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229/6.
;   Every lens's last visible line ends with STA WSYNC / BIT / JMP so the
;   overscan label lands at 229/6, exactly the course skeleton.
;
; Checkpoints (source label, expected Stella state):
;   StartFrame   259/3   the first VSYNC instruction
;   VblankStart    0/5   the first VBLANK instruction
;   BodyStart     37/5   the first visible line
;   OverscanStart 229/6  the first overscan instruction
;   LensRead     A = 0/1/2, the active lens
;   LensWrite    A = the new lens (SELECT or the auto-demo)
;   FrameRead    A = the free-running frame counter
;   MapIndexRead A = the highlighted RAM byte index, 0..127
;
; RAM map (+clean_start zeroes every byte):
;   $80 Lens         0 = RUN, 1 = ZONES, 2 = VARS
;   $81 Frame        free-running frame counter
;   $82 ShipX        the RUN ship's left edge, 8..144
;   $83 ShipDir      1 = right, $FF = left
;   $84 free
;   $85 MapIndex     the VARS highlighted byte, 0..127
;   $86 PrevSelect   SELECT level last frame
;   $87 NewSelect    SELECT level this frame
;   $88 free
;   $89 BallX        the ball's target X
;   $8A free
;   $8B TmpA         scratch
;   $8C GridRow      the VARS grid row, 0..7
;   $8D ScreenY      the ZONES screen row counter
;   $8E BarIdx       the ZONES bar table index, 0..23
;   $8F LineCount    the ZONES band line counter
;   $90 SelectedRow  MapIndex >> 4, 0..7 (the grid row)
;   $91 OwnerGroup   the VARS group code, 0..8
;   $92 MapTick      the MapIndex speed divider
;   $93-$94 free
;   $95 LensTimer    the auto-demo frame counter, 0..239
;   $96 free
;   $97 TmpB         the hex-glyph copy counter
;   $98-$9F free
;   $A0-$D7 the shared score library (ScoreDigits, ScoreRow, ScoreTmp,
;           ScoreBuf)
;   $D8-$F7 free
;   $F8-$FF stack
;
; Build: acme -f plain -o build/demo-66.bin \
;        lessons/part9-dsl-path/66-analyzing-batari-basic/demo-66.asm
; Run:   stella build/demo-66.bin
; The ROM is 4,096 bytes.
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; CONSTANTS
; =============================================================================
VBLANK_TIMER    = 44          ; 37-line VBLANK (44 ticks)
OVERSCAN_TIMER  = 36          ; 30-line overscan (36 ticks)
POS_BIAS        = 3           ; the Lesson 26 output-delay bias
AUTO_LENS_FRAMES = 240        ; the auto-demo: about four seconds per lens

; --- the three lenses -------------------------------------------------------
LENS_RUN   = 0
LENS_ZONES = 1
LENS_VARS  = 2

; --- RUN geometry -----------------------------------------------------------
RUN_FIRST   = 6               ; the first StarBody row's Y coordinate (screen row 21)
SHIP_Y      = 120             ; the ship's picture row
ENEMY_Y     = 60              ; the enemy's picture row
BALL_Y      = 40              ; the ball's picture row
SHIP_MIN    = 8
SHIP_MAX    = 144
ENEMY_X     = 100
RUN_BALL_X  = 80

; --- VARS layout (192 visible lines) ----------------------------------------
; 16 label + 2 top gap + 8 rows x (1 preload + 8 cell + 2 gap) = 88
; + 85 blank + 1 last row = 192.

; --- colours (TIA colour bytes, not RGB) -----------------------------------
C_WHITE   = $0E
C_BLUE    = $84
C_GREEN   = $C2
C_RED     = $42
C_GOLD    = $1A
C_SHIP    = $C8
C_BG      = $02

; =============================================================================
; RAM
; =============================================================================
Lens        = $80
Frame       = $81
ShipX       = $82
ShipDir     = $83
; $84 free
MapIndex    = $85
PrevSelect  = $86
NewSelect   = $87
; $88 free
BallX       = $89
; $8A free
TmpA        = $8B
GridRow     = $8C
ScreenY     = $8D
BarIdx      = $8E
LineCount   = $8F
SelectedRow = $90
OwnerGroup  = $91
MapTick     = $92
LensTimer   = $95
TmpB        = $97
; $93-$94, $96 and $98-$9F are free
; $A0-$D7 the score library
; $D8-$F7 free
; $F8-$FF stack

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreSetup positions P0/P1 at 56/64, sets three-copy close mode and VDEL,
; and strobes the HMOVE.  ScoreDraw paints the six 8-pixel columns.
; ScoreAddOne increments the six decimal digits.  The library owns $A0-$D7.
; It is sourced after the ROM origin because it contains code.
    * = $F000

    !source "include/score.asm"

; =============================================================================
; RESET
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port
    STA SWBCNT              ; port B is an input port
    STA GRP0
    STA GRP1
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA VDELP0
    STA VDELP1
    LDA #$0E
    STA COLUP0
    STA COLUP1
    LDA #$02
    STA COLUBK
    LDA #$10                ; repeat playfield, 2-pixel ball
    STA CTRLPF

    ; --- the initial lens state --------------------------------------------
    LDA #LENS_RUN
    STA Lens
    STA Frame
    STA PrevSelect
    STA NewSelect
    STA MapIndex
    STA MapTick
    STA GridRow
    STA LensTimer
    LDA #60
    STA ShipX
    LDA #1
    STA ShipDir
    LDA #RUN_BALL_X
    STA BallX
    LDA #0
    STA SelectedRow
    STA OwnerGroup

    ; --- the score ---------------------------------------------------------
    JSR ScoreInit
    JSR ScoreClear
    JSR ScoreSetup           ; P0/P1 at 56/64, NUSIZ=3, VDEL=1, HMOVE

    JMP StartFrame

; =============================================================================
; FRAME — 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262
; =============================================================================
StartFrame:                  ; checkpoint: scanline 259, the first VSYNC line
    +vsync

VblankStart:                 ; checkpoint: scanline 0, cycle 5
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; -----------------------------------------------------------------------------
; SELECT and the auto-demo — one lens advance, then reset the timer
; -----------------------------------------------------------------------------
; A SELECT edge advances the lens immediately; otherwise the 240-frame
; auto-demo timer advances it.  Both paths reset the timer and call the
; same advance routine, so the lens-entry side effects cannot diverge.
    LDA SWCHB
    AND #$02
    EOR #$02                 ; 1 = SELECT pressed
    STA NewSelect
    AND PrevSelect
    EOR NewSelect            ; new & ~previous: a fresh press
    BEQ CheckAutoDemo
    LDA #0
    STA LensTimer
    JSR AdvanceLens
    JMP SelectDone
CheckAutoDemo:
    INC LensTimer
    LDA LensTimer
    CMP #AUTO_LENS_FRAMES
    BCC SelectDone
    LDA #0
    STA LensTimer
    JSR AdvanceLens
SelectDone:
    LDA NewSelect
    STA PrevSelect


; -----------------------------------------------------------------------------
; FRAME COUNTER
; -----------------------------------------------------------------------------
    INC Frame
    LDA Frame
FrameRead:                   ; checkpoint: A = the frame counter
    NOP

; -----------------------------------------------------------------------------
; LENS-SPECIFIC STATE
; -----------------------------------------------------------------------------
    LDA Lens
LensRead:                    ; checkpoint: A = the active lens
    NOP
    BEQ VblankRun
    CMP #LENS_ZONES
    BEQ VblankZones
    JMP VblankVars

; --- RUN --------------------------------------------------------------------
VblankRun:
    ; the ship auto-pans between SHIP_MIN and SHIP_MAX
    LDA ShipX
    CLC
    ADC ShipDir
    CMP #SHIP_MIN
    BCS RunCheckRight
    LDA #SHIP_MIN
    STA ShipX
    JMP RunTurn
RunCheckRight:
    CMP #(SHIP_MAX + 1)
    BCC RunShipStore
    LDA #SHIP_MAX
    STA ShipX
RunTurn:
    LDA ShipDir
    EOR #$FE                 ; 1 <-> $FF
    STA ShipDir
    JMP RunColours
RunShipStore:
    STA ShipX
RunColours:
    ; the score counts frames in decimal, like the bB sample's score = score+1
    JSR ScoreAddOne
    LDA #RUN_BALL_X
    STA BallX
    LDA #C_BG
    STA COLUBK
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    LDA #C_GOLD
    STA COLUPF
    LDA #$10                 ; repeat playfield, 2-pixel ball
    STA CTRLPF
    LDA #$00
    STA VDELBL               ; the RUN ball's enable is immediate
    JMP VblankCommon

; --- ZONES ------------------------------------------------------------------
VblankZones:
    LDA #$00
    STA GRP0
    STA GRP1
    STA ENABL
    STA NUSIZ0
    STA NUSIZ1
    STA VDELP0
    STA VDELP1
    STA VDELBL
    ; preload the first white VSYNC row: the first BarLines store is too late
    ; for the left-half PF slots, so the VBLANK supplies row 0.
    LDA BarPF0
    STA PF0
    LDA BarPF1
    STA PF1
    LDA BarPF2
    STA PF2
    LDA #$10
    STA CTRLPF               ; repeat: the staircase appears in both halves
    LDA #0
    STA ScreenY
    STA BarIdx
    LDA #C_WHITE
    STA COLUPF
    STA COLUBK
    LDA #3
    STA LineCount
    JMP VblankWait

; --- VARS -------------------------------------------------------------------
VblankVars:
    ; advance the highlighted cell every eight frames
    INC MapTick
    LDA MapTick
    AND #$07
    BNE NoMapAdvance
    INC MapIndex
    LDA MapIndex
    CMP #128
    BCC MapStore
    LDA #0
MapStore:
    STA MapIndex
NoMapAdvance:
    LDA MapIndex
MapIndexRead:                ; checkpoint: A = the highlighted RAM byte index
    NOP

    ; the selected row and the owner group
    LDA MapIndex
    LSR
    LSR
    LSR
    LSR
    STA SelectedRow

    JSR SetOwner
    JSR BuildHexScore
    JSR SetVarBall

    LDA #C_BG
    STA COLUBK
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    STA COLUPF
    LDA #$30                 ; repeat playfield, 8-pixel ball
    STA CTRLPF
    LDA #$00
    STA VDELBL               ; the VARS ball's block is the row's nine display lines
    JMP VblankCommon

; --- the shared score / ball positioning ------------------------------------
VblankCommon:
    ; clear the visible objects before the score band
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL

    ; preload the first score-band row: the ScoreBand stores in the first
    ; visible line are too late for the left-half PF slots, so the VBLANK
    ; supplies the colour and the three bytes here.
    LDA #C_GOLD
    STA COLUPF
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2

    ; position the ball; ScoreSetup's HMOVE applies HMP0/HMP1/HMBL together
    LDA BallX
    CLC
    ADC #(POS_BIAS + 1)
    JSR SetCoarseBL
    JSR ScoreSetup

    ; the score band's score is white
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1

    JMP VblankWait

VblankWait:
    +wait_timer
    LDA #$00
    STA VBLANK               ; picture on

; =============================================================================
; VISIBLE PICTURE — the three lenses
; =============================================================================
BodyStart:                   ; checkpoint: scanline 37, visible line 0
    LDA Lens
    BEQ RunLens
    CMP #LENS_ZONES
    BNE NotZoneLens
    JMP ZoneLens
NotZoneLens:
    JMP VarLens

; -----------------------------------------------------------------------------
; LENS 0 — RUN
; -----------------------------------------------------------------------------
RunLens:
    JSR ScoreBand
    JMP RunPicture

RunPicture:
    ; the picture's objects have their own colours; the score is already drawn
    LDA #C_SHIP
    STA COLUP0
    LDA #C_GOLD
    STA COLUP1
    LDA #C_GOLD
    STA COLUPF

    ; Position P0 (ship) and P1 (enemy).  The two positioners and the final
    ; WSYNC consume five picture rows (screen 16-20); the first StarBody row
    ; is Y=6 on screen row 21.  The starfield loop is Y=6..173 (168 rows), the
    ; two blank spacers take the next two rows, and StarLast draws the last
    ; row.  16 + 5 + 168 + 2 + 1 = 192.
    LDA ShipX
    CLC
    ADC #POS_BIAS
    JSR SetCoarseP0
    STA WSYNC                ; start the enemy's positioner on a fresh line
    LDA #(ENEMY_X + POS_BIAS)
    JSR SetCoarseP1
    LDA #0
    STA HMBL                 ; the ball's fine offset was applied in VBLANK
    STA WSYNC
    STA HMOVE                ; HMOVE blanks the leftmost 8 pixels of this
                             ; first star row (the only row it affects)
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL
    LDY #RUN_FIRST
RunToBall:
    CPY #BALL_Y
    BEQ RunBallZone
    JSR StarLine
    JMP RunToBall
RunBallZone:
RunBallLoop:
    JSR StarBallLine          ; StarBody clobbers X, so test Y instead
    CPY #(BALL_Y + 4)
    BNE RunBallLoop
RunToEnemy:
    CPY #ENEMY_Y
    BEQ RunEnemyZone
    JSR StarLine
    JMP RunToEnemy
RunEnemyZone:
RunEnemyLoop:
    JSR StarEnemyLine
    CPY #(ENEMY_Y + 6)
    BNE RunEnemyLoop
RunToShip:
    CPY #SHIP_Y
    BEQ RunShipZone
    JSR StarLine
    JMP RunToShip
RunShipZone:
RunShipLoop:
    JSR StarShipLine
    CPY #(SHIP_Y + 6)
    BNE RunShipLoop
RunBottom:
    CPY #174
    BEQ RunLast
    JSR StarLine
    JMP RunBottom
RunLast:
    ; two blank spacer rows: 16 band + 5 position + 168 starfield = 189;
    ; the two spacers make 191 and StarLast draws the 192nd line.  The first
    ; WSYNC ends the last starfield row before the PF is cleared, so that
    ; row keeps its right half; the second spacer line also computes the last
    ; row's index so StarLast can store PF before the left-half latch.
    STA WSYNC                ; end the last starfield row
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC                ; blank spacer row 1
    ; compute the last row's starfield index while this spacer line runs, so
    ; StarLast can store PF before the left-half latch on the next line
    TYA
    CLC
    ADC Frame
    AND #$0F
    TAX
    STA WSYNC                ; blank spacer row 2
    JMP StarLast

; --- StarLast — the final visible row; X was computed in RunLast; the
; --- WSYNC/BIT/JMP tail lands at 229/6 -------------------------------------
StarLast:
    ; X was computed on the previous spacer line, so the first PF store lands
    ; early enough for the left-half latch; the second WSYNC/BIT/JMP keeps the
    ; overscan landing at 229/6.
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    LDA #0
    STA ENABL
    STA GRP0
    STA GRP1
    STA WSYNC
    BIT Frame                ; three cycles of alignment
    JMP OverscanStart        ; fetched at 229/6

; -----------------------------------------------------------------------------
; THE SCORE BAND — 3 gold bar rows + 4 blank + 9 score rows = 16
; -----------------------------------------------------------------------------
; The band is shared by RUN and VARS.  The gold bar identifies the bB-style
; score header; the six-digit window underneath is the score (RUN) or the
; group/address window (VARS).  There is no text in the band.
ScoreBand:
    LDA #C_GOLD
    STA COLUPF
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2
    LDY #3
BandBar:
    STA WSYNC
    DEY
    BNE BandBar
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    LDY #4
BandBlank:
    STA WSYNC
    DEY
    BNE BandBlank
    JSR ScoreDraw
    ; leave three-copy / VDEL mode before the picture
    LDA #$00
    STA NUSIZ0
    STA NUSIZ1
    STA VDELP0
    STA VDELP1
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    RTS

; -----------------------------------------------------------------------------
; LENS 1 — ZONES
; -----------------------------------------------------------------------------
ZoneLens:
    JMP ZonePicture

ZonePicture:
    ; the white VSYNC band: VblankZones already set ScreenY, BarIdx,
    ; COLUPF, COLUBK and LineCount, so the first bar line starts at 37/5.
    JSR BarLines

    ; rows 3-39: VBLANK (37 rows)
    LDA #C_BLUE
    STA COLUBK
    LDA #37
    STA LineCount
    JSR BarLines

    ; rows 40-161: the kernel, compressed to 122 rows
    LDA #C_GREEN
    STA COLUBK
    LDA #122
    STA LineCount
    JSR BarLines

    ; rows 162-190: overscan (29 rows), then the last row below
    LDA #C_RED
    STA COLUBK
    LDA #29
    STA LineCount
    JSR BarLines

    ; row 191: the last map line, then the overscan at 229/6
    LDX BarIdx
    LDA BarPF0,X
    STA PF0
    LDA BarPF1,X
    STA PF1
    LDA BarPF2,X
    STA PF2
    STA WSYNC
    BIT Frame
    JMP OverscanStart

; --- BarLines — draw LineCount bar-only rows --------------------------------
; ScreenY is the absolute map row; BarIdx is the bar table position.  The
; next row's BarIdx is prepared during the current row, so the line starts
; with the bar bytes already known.
BarLines:
BarLine:
    LDX BarIdx
    LDA BarPF0,X
    STA PF0
    LDA BarPF1,X
    STA PF1
    LDA BarPF2,X
    STA PF2
    LDA ScreenY
    CLC
    ADC #1
    AND #7
    BNE BarNoStep
    INC BarIdx
BarNoStep:
    INC ScreenY
    STA WSYNC
    DEC LineCount
    BNE BarLine
    RTS

; -----------------------------------------------------------------------------
; LENS 2 — VARS
; -----------------------------------------------------------------------------
VarLens:
    JSR ScoreBand
    JMP VarPicture

; --- WriteGridLine — the shared grid cell line, with the left/right split ---
; X is the table entry.  The macro is used for the preload line and for all
; eight cell lines so the split is identical (a JSR per line would push the
; left-half stores past the latch).  The L bytes go early; the R bytes follow
; after the left half's latch.  The caller adds the WSYNC.
!macro WriteGridLine {
    LDA GridL0,X
    STA PF0
    LDA GridL1,X
    STA PF1
    LDA GridL2,X
    STA PF2
    LDA GridR0,X
    STA PF0
    NOP
    NOP
    NOP
    LDA GridR1,X
    STA PF1
    NOP
    NOP
    NOP
    LDA GridR2,X
    STA PF2
}

VarPicture:
    LDA #C_WHITE
    STA COLUPF               ; the grid is white
    ; the two gap lines before grid row 0 (screen rows 16-17)
    LDX #0                   ; X = the grid table index, 0..63
    LDA #0
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    STA WSYNC
    ; preload row 0's first cell line (X=0) before the line starts; the
    ; macro writes the full left/right split, not just the L bytes.
    +WriteGridLine

    ; eight rows: the preload line, eight cell lines, and two gap lines each
    LDA #0
    STA GridRow
GridRowLoop:
    ; The ball is a solid white block over the selected row's nine display
    ; lines (the preload line plus the eight cell lines); the gap lines and
    ; the other rows are off.
    LDA GridRow
    CMP SelectedRow
    BNE RowCellsOff
    LDA #2
    JMP RowCellsStore
RowCellsOff:
    LDA #0
RowCellsStore:
    STA ENABL
    LDY #8
GridCellLoop:
    +WriteGridLine
    INX
    STA WSYNC
    DEY
    BNE GridCellLoop

    ; the two blank gap lines after this row
    LDA #0
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC                ; gap line 1
    ; After the last row X=64 would read past the 64-byte grid planes; skip
    ; that preload so the tail line stays dark.  The check runs on the first
    ; gap line, so the rows 0-6 preload keeps its early L stores.
    LDA GridRow
    CMP #7
    BEQ TailSkip
    STA WSYNC                ; gap line 2
    +WriteGridLine           ; the next row's preload, full split
    JMP TailDone
TailSkip:
    STA WSYNC                ; gap line 2
TailDone:
    INC GridRow
    LDA GridRow
    CMP #8
    BNE GridRowLoop

    ; the grid is done; the ball is off and the rest of the screen is dark
    LDA #0
    STA ENABL
    STA PF0
    STA PF1
    STA PF2
    ; 85 dark rows below the grid: the skipped tail line plus 84 blanks
    LDY #85
VarBlank:
    STA WSYNC
    DEY
    BNE VarBlank

    ; row 191: the last visible line
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    BIT Frame
    JMP OverscanStart

; =============================================================================
; THE RUN PICTURE LINE ROUTINES
; =============================================================================
; StarBody draws the starfield row and waits; it leaves GRP0/GRP1/ENABL alone.
; The wrappers set the object for the current row, then tail-call StarBody.
StarLine:
    LDA #C_GOLD
    STA COLUPF               ; the starfield is gold on ordinary rows
    LDA #$00
    STA ENABL
    STA GRP0
    STA GRP1
    JMP StarBody

StarBallLine:
    LDA #C_WHITE
    STA COLUPF               ; the ball's four rows are white
    LDA #$02
    STA ENABL
    JMP StarBody

StarEnemyLine:
    TYA
    SEC
    SBC #ENEMY_Y
    TAX
    LDA EnemyGfx,X
    STA GRP1
    JMP StarBody

StarShipLine:
    TYA
    SEC
    SBC #SHIP_Y
    TAX
    LDA ShipGfx,X
    STA GRP0
    JMP StarBody

StarBody:
    TYA
    CLC
    ADC Frame
    AND #$0F
    TAX
    STA WSYNC
    ; the index is known before the line starts, so the three stores land in
    ; the left-half PF slots (PF0 ~7, PF1 ~14, PF2 ~21) instead of ~52-69.
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    INY
    RTS

; =============================================================================
; POSITIONING — the Lesson 26 divide-by-15 coarse routines
; =============================================================================
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

SetCoarseP1:
    STA WSYNC
    SEC
DivP1:
    SBC #15
    BCS DivP1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
    RTS

SetCoarseBL:
    STA WSYNC
    SEC
DivBL:
    SBC #15
    BCS DivBL
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMBL
    STA RESBL
    RTS

; =============================================================================
; VARS HELPERS
; =============================================================================
; SetOwner — A = the owner group code for MapIndex.
;   0 SYS    $80-$92 and $EE-$EF   player/ball/missile state + playfieldpos
;   1 SCR    $93-$95              the three score bytes
;   2 PTR    $96-$9B              the six score pointers
;   3 TMP    $9C-$A1              temp1-temp6
;   4 RND    $A2-$A3              rand and scorecolor
;   5 PF     $A4-$D3              the playfield / var0-var47 block
;   6 DIM    $D4-$ED              the a-z pool (the dim aliases)
;   7 AUX    $F0-$F5              aux1-aux6, free in this program
;   8 STK    $F6-$FF              the bB stack
SetOwner:
    LDA MapIndex
    CMP #$13
    BCC OwnerSys
    CMP #$16
    BCC OwnerScr
    CMP #$1C
    BCC OwnerPtr
    CMP #$22
    BCC OwnerTmp
    CMP #$24
    BCC OwnerRnd
    CMP #$54
    BCC OwnerPf
    CMP #$6E
    BCC OwnerDim
    CMP #$70
    BCC OwnerSys
    CMP #$76
    BCC OwnerAux
    LDA #8
    JMP OwnerStore
OwnerSys:
    LDA #0
    JMP OwnerStore
OwnerScr:
    LDA #1
    JMP OwnerStore
OwnerPtr:
    LDA #2
    JMP OwnerStore
OwnerTmp:
    LDA #3
    JMP OwnerStore
OwnerRnd:
    LDA #4
    JMP OwnerStore
OwnerPf:
    LDA #5
    JMP OwnerStore
OwnerDim:
    LDA #6
    JMP OwnerStore
OwnerAux:
    LDA #7
OwnerStore:
    STA OwnerGroup
    RTS

; SetVarBall — BallX is the selected cell's left edge.  The 8-pixel ball
; spans the 4-pixel cell and the 4-pixel gap after it.  The ball has no Y
; register; the vertical white block is the grid's ENABL logic.
SetVarBall:
    LDA MapIndex
    AND #$0F
    CMP #8
    BCS VarBallRight
    ASL
    ASL
    ASL
    STA BallX
    RTS
VarBallRight:
    SEC
    SBC #8
    ASL
    ASL
    ASL
    CLC
    ADC #80
    STA BallX
    RTS

; BuildHexScore — the six-digit window: the three left digits are blank,
; then the group code, then the two hex digits of $80 + MapIndex.
BuildHexScore:
    ; blank the first three columns
    LDX #24
    LDA #0
ClearHex:
    DEX
    STA ScoreBuf,X
    BNE ClearHex

    LDA MapIndex
    CLC
    ADC #$80
    STA TmpA

    ; position 5 = the low nibble
    LDA TmpA
    AND #$0F
    TAX
    LDA #5
    JSR SetHexGlyph
    ; position 4 = the high nibble
    LDA TmpA
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA #4
    JSR SetHexGlyph
    ; position 3 = the owner group code
    LDX OwnerGroup
    LDA #3
    JSR SetHexGlyph
    RTS

; SetHexGlyph — A = position 0-5, X = glyph 0-15.  Copies eight bottom-up
; bytes from HexFont into that column of ScoreBuf.
SetHexGlyph:
    STA TmpB
    TXA
    ASL
    ASL
    ASL
    TAX
    LDA TmpB
    ASL
    ASL
    ASL
    TAY
    LDA #8
    STA TmpB
HexCopy:
    LDA HexFont,X
    STA ScoreBuf,Y
    INX
    INY
    DEC TmpB
    BNE HexCopy
    RTS

; =============================================================================
; OVERSCAN — 30 lines, then the next frame
; =============================================================================
OverscanStart:               ; checkpoint: scanline 229, cycle 6
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; -----------------------------------------------------------------------------
; AdvanceLens — advance 0 -> 1 -> 2 -> 0 and run the lens-entry side effects
; -----------------------------------------------------------------------------
AdvanceLens:
    LDA Lens
    CLC
    ADC #1
    CMP #3
    BCC AdvanceStore
    LDA #0
AdvanceStore:
    STA Lens
LensWrite:                   ; checkpoint: A = the new lens
    NOP
    CMP #LENS_RUN
    BNE AdvanceNotRun
    ; entering RUN: restart the little score counter
    JSR ScoreClear
    LDA #60
    STA ShipX
    LDA #1
    STA ShipDir
    RTS
AdvanceNotRun:
    CMP #LENS_VARS
    BNE AdvanceDone
    ; entering VARS: restart the highlighted byte
    LDA #0
    STA MapIndex
    STA MapTick
    JSR BuildHexScore
AdvanceDone:
    RTS

; =============================================================================
; DATA TABLES
; =============================================================================

; --- the RUN starfield: sixteen rows of three playfield bytes --------------
; (Y + Frame) & $0F selects the row, so the field scrolls one row per frame.
StarPF0:
    !byte $00, $00, $10, $00, $00, $00, $00, $00
    !byte $00, $40, $00, $00, $00, $00, $00, $00
StarPF1:
    !byte $00, $00, $00, $00, $80, $00, $00, $00
    !byte $00, $00, $00, $08, $00, $00, $00, $00
StarPF2:
    !byte $00, $00, $00, $00, $00, $00, $02, $00
    !byte $00, $00, $00, $00, $00, $20, $00, $00

; --- the RUN sprites: six rows each, same shapes as the bB sample ----------
ShipGfx:
    !byte %00111100
    !byte %01111110
    !byte %11111111
    !byte %11111111
    !byte %01111110
    !byte %00111100
EnemyGfx:
    !byte %00011000
    !byte %00111100
    !byte %01111110
    !byte %11111111
    !byte %01111110
    !byte %00111100

; --- the ZONES row bar: one four-pixel chunk, clamped to chunk 19 ----------
BarPF0:
    !byte $10, $20, $40, $80, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
BarPF1:
    !byte $00, $00, $00, $00, $80, $40, $20, $10
    !byte $08, $04, $02, $01, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $00
BarPF2:
    !byte $00, $00, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $01, $02, $04, $08
    !byte $10, $20, $40, $80, $80, $80, $80, $80

; --- the 16x8 VARS grid: six 64-entry planes, indexed row*8 + cell_line -----
; Entry i = grid row i>>3, cell line i&7 (row-major).  L = the left eight columns,
; R = the right eight columns.  The playfield writes L in HBLANK and R after
; the left half has been read, so all sixteen columns are distinct.
GridL0:
    !byte $50, $50, $50, $50, $50, $50, $50, $50
    !byte $50, $50, $50, $50, $50, $50, $50, $50
    !byte $50, $50, $50, $50, $50, $00, $00, $00
    !byte $50, $50, $50, $00, $00, $00, $00, $00
    !byte $50, $50, $50, $00, $00, $00, $00, $00
    !byte $50, $50, $50, $00, $00, $00, $00, $00
    !byte $50, $50, $00, $00, $00, $00, $00, $00
    !byte $50, $00, $00, $00, $00, $00, $00, $00
GridL1:
    !byte $AA, $AA, $AA, $AA, $AA, $AA, $AA, $AA
    !byte $AA, $AA, $AA, $AA, $AA, $AA, $AA, $80
    !byte $AA, $AA, $AA, $A0, $00, $00, $00, $00
    !byte $AA, $AA, $AA, $00, $00, $00, $00, $00
    !byte $AA, $AA, $AA, $00, $00, $00, $00, $00
    !byte $AA, $AA, $A0, $00, $00, $00, $00, $00
    !byte $AA, $AA, $00, $00, $00, $00, $00, $00
    !byte $AA, $00, $00, $00, $00, $00, $00, $00
GridL2:
    !byte $05, $05, $05, $05, $05, $05, $05, $05
    !byte $05, $05, $05, $05, $05, $05, $00, $00
    !byte $05, $05, $05, $00, $00, $00, $00, $00
    !byte $05, $05, $05, $00, $00, $00, $00, $00
    !byte $05, $05, $05, $00, $00, $00, $00, $00
    !byte $05, $05, $00, $00, $00, $00, $00, $00
    !byte $05, $05, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $05
GridR0:
    !byte $50, $50, $50, $50, $50, $50, $50, $50
    !byte $50, $50, $50, $50, $50, $50, $00, $00
    !byte $50, $50, $50, $00, $00, $00, $00, $00
    !byte $50, $50, $50, $00, $00, $00, $00, $00
    !byte $50, $50, $50, $00, $00, $00, $00, $00
    !byte $50, $50, $00, $00, $00, $00, $00, $00
    !byte $50, $50, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $50
GridR1:
    !byte $AA, $AA, $AA, $AA, $AA, $AA, $AA, $AA
    !byte $AA, $AA, $AA, $AA, $AA, $A0, $00, $00
    !byte $AA, $AA, $AA, $00, $00, $00, $00, $00
    !byte $AA, $AA, $AA, $00, $00, $00, $00, $00
    !byte $AA, $AA, $AA, $00, $00, $00, $00, $00
    !byte $AA, $AA, $00, $00, $00, $00, $00, $00
    !byte $AA, $AA, $00, $00, $00, $00, $00, $00
    !byte $00, $00, $00, $00, $00, $00, $00, $AA
GridR2:
    !byte $05, $05, $05, $05, $05, $05, $05, $05
    !byte $05, $05, $05, $05, $05, $00, $00, $00
    !byte $05, $05, $05, $00, $00, $00, $00, $00
    !byte $05, $05, $05, $00, $00, $00, $00, $00
    !byte $05, $05, $05, $00, $00, $00, $00, $00
    !byte $05, $05, $00, $00, $00, $00, $00, $00
    !byte $05, $05, $05, $05, $05, $05, $05, $05
    !byte $00, $00, $00, $00, $00, $00, $00, $05

; --- the hex score font: sixteen glyphs, eight rows, bottom-up -------------
; The 4x7 glyph is shifted into bits 7-4 of the 8-pixel score column.
HexFont:
    !byte $00, $60, $90, $90, $90, $90, $90, $60
    !byte $00, $E0, $40, $40, $40, $40, $C0, $40
    !byte $00, $F0, $80, $40, $20, $10, $90, $60
    !byte $00, $E0, $10, $10, $60, $10, $10, $E0
    !byte $00, $20, $20, $F0, $A0, $A0, $60, $20
    !byte $00, $E0, $10, $10, $E0, $80, $80, $F0
    !byte $00, $60, $90, $90, $E0, $80, $80, $60
    !byte $00, $40, $40, $40, $20, $20, $10, $F0
    !byte $00, $60, $90, $90, $60, $90, $90, $60
    !byte $00, $60, $10, $10, $70, $90, $90, $60
    !byte $00, $90, $90, $90, $F0, $90, $90, $60
    !byte $00, $E0, $90, $90, $E0, $90, $90, $E0
    !byte $00, $60, $90, $80, $80, $80, $90, $60
    !byte $00, $E0, $90, $90, $90, $90, $90, $E0
    !byte $00, $F0, $80, $80, $E0, $80, $80, $F0
    !byte $00, $80, $80, $80, $E0, $80, $80, $F0

; =============================================================================
; VECTORS — the 6507 reads RESET at $FFFC and jumps to Reset
; =============================================================================
    !fill $FFFA - *, $EA
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

<!-- END-FULL-SOURCE -->

### Code Walkthrough

#### Step 1 — Reset, the score library, and the initial lens

`Reset` runs `+clean_start`, sets `SWACNT`/`SWBCNT` to input, clears the TIA objects, sets the palette, loads the lens state (`Lens=0`, `Frame=0`, `ShipX=60`, `ShipDir=1`, `BallX=80`, `MapIndex=0`, `LensTimer=0`), and calls `ScoreInit`, `ScoreClear` and `ScoreSetup`. `ScoreSetup` puts P0/P1 in three-copy close mode at X=56/64, turns VDEL on, and strobes the first HMOVE. The score library owns `$A0-$D7`; the demo's variables live in `$80-$9F`.

#### Step 2 — The frame skeleton and the SELECT edge

`StartFrame` is the 3-line VSYNC; `VblankStart` sets VBLANK, arms the 44-tick timer, reads `SWCHB` bit 1, and uses the edge `new & ~previous` to advance the lens. The 240-frame `LensTimer` does the same when no SELECT has been pressed: it advances the lens every four seconds and resets on any SELECT edge, so the same `AdvanceLens` path runs for both. `LensWrite` is the checkpoint: A is the new lens. The shared VBLANK preloads the first score-band row (`COLUPF=C_GOLD`, `PF0=$F0`, `PF1=$FF`, `PF2=$FF`) before `STA VBLANK`, because the visible-line stores are too late for the left-half PF slots. The VBLANK then does the lens-specific state (the ship's auto-pan and the decimal `ScoreAddOne` for RUN; the `MapIndex`/`SetOwner`/`BuildHexScore`/`SetVarBall` work for VARS), positions the ball and the score with `SetCoarseBL` + `ScoreSetup`, waits for the timer, and releases the picture at scanline 37. `BodyStart` dispatches to the three kernels.

#### Step 3 — Lens 0: the RUN picture

`ScoreBand` draws the 16-line band shared by RUN and VARS: three gold bar rows (`PF0=$F0`, `PF1=$FF`, `PF2=$FF`), four blank rows, and a nine-line `ScoreDraw`. The shared VBLANK preloads the first gold row, so row 0 is full-width; the visible stores re-store the same bytes. There is no text. For RUN the score is the frame counter, incremented with `ScoreAddOne`; it is the bB sample's `score = score + 1` in a different form. After the score, the band restores NUSIZ/VDEL to off. `RunPicture` sets the ship/enemy/playfield colours, positions P0 at `ShipX` and P1 at `ENEMY_X=100`, clears HMBL (the ball's fine offset was already applied in VBLANK), and strobes the frame's second HMOVE. The two positioners and the final WSYNC consume five picture rows; the first `StarBody` row is `RUN_FIRST=6`, a **Y coordinate** that lands on screen row 21. The starfield loop is Y=6..173 (168 rows): `StarLine` for the open rows, `StarBallLine` for the four ball rows (the playfield turns white and the 2-pixel ball sits at X=80-81), `StarEnemyLine` for the six enemy rows, and `StarShipLine` for the six ship rows. `StarBody` computes the index `(Y + Frame) & $0F` before `STA WSYNC` and stores PF0/PF1/PF2 immediately after it, so the left and right halves show the same row. After the 168 rows, `RunLast` clears the PF, draws two blank spacer rows, and computes the last row's starfield index before the final spacer WSYNC; `StarLast` then stores PF0/PF1/PF2 at the start of row 191, before the left-half latch, and its `STA WSYNC / BIT / JMP OverscanStart` lands the overscan at 229/6. The `HMOVE` strobed on the first star row blanks the leftmost 8 pixels of that row only. The ledger is 16 band + 5 position + 168 starfield + 2 blank + 1 StarLast = 192 picture rows, and the frame is 262 lines at every ship X.

#### Step 4 — Lens 1: the ZONES frame map

`ZonePicture` is four band loops. `VblankZones` preloads the white VSYNC row and sets `CTRLPF=$10` (repeat), so the first white row is full-width and the 20-bit playfield draws the staircase **twice**, at x and x+80. `ZonePicture` starts with `JSR BarLines` (3 white VSYNC rows), then sets blue and draws 37 rows, then sets green and draws 122 rows, then sets red and draws 29 rows and the final row. `BarLines` writes the bar row's three playfield bytes and prepares the next row's `BarIdx`; there is no text path. The row bar is a single 4-pixel chunk at `Y >> 3`, clamped to chunk 19. The 192 visible rows are a **projection** of the 3/37/192/30 frame: the white 3 and the red 30 keep their true line counts, the 37 blue lines are the VBLANK, and the 192-line kernel is compressed into the 122 rows the visible window has room for. The blanked phases are not visible on a TV, and the lesson's text names them; the screen carries only the colours and the two staircases.

#### Step 5 — Lens 2: the VARS RAM map

`ScoreBand` draws the same gold bar and the six-digit window. For VARS the window is the group code, then the two hex digits of `$80 + MapIndex` (the capture shows `0 8 9`, group 0, SYS, at `$89`). `VarPicture` draws the two-line top gap, eight grid rows of nine display lines each (a preload line that repeats the first cell line, then eight cell lines), two dark gap lines between rows, then the skipped tail line plus 84 blank rows (85 dark rows) and the last row: 2 + 88 + 85 + 1 = 176 picture rows. Each cell is a four-pixel bar whose height is the group code; the 8-pixel ball makes the selected row a **solid white block** over its nine lines, spanning the 4-pixel cell and the 4-pixel gap after it (the capture: row 0, column 9, X=88-95, lines 18-26). The grid table is six 64-byte **row-major** planes, indexed `row*8 + cell_line` (eight 8-byte row blocks). The shared `WriteGridLine` macro (an ACME macro, not a JSR: the call overhead would push the left-half stores past the latch) writes the left half's PF0/PF1/PF2 early, then the right half's PF0/PF1/PF2 after the left half has been read, so all 16 columns are distinct. The preload line and every cell line use the same macro; the preload line and the first cell line match for rows 1-7. `SetOwner` maps `MapIndex` to one of nine groups; `BuildHexScore` fills `ScoreBuf` with the group code and the two address digits; `SelectedRow = MapIndex >> 4` is the grid row (the high nibble), and `SetVarBall` uses the low nibble for the column and computes only the cell's X (the ball has no Y register).

#### Step 6 — The tables and the vectors

The starfield is 16 rows of three bytes; the sprites are the bB sample's six-row shapes; the bar is 24 entries of three bytes; the grid is the six 64-byte row-major planes; the hex font is 16 eight-byte glyphs, bottom-up. There are no label or legend tables: the band is a solid gold bar and the score window, and the VARS groups are read from the cell bar heights with the lesson's table. The image is padded with `!fill $FFFA - *, $EA` and the three vectors point at `Reset`. The result is exactly 4,096 bytes.

## What You Should See

The demo opens on **Lens 0 — RUN**. The 16-line band is a bB-style header with no text: three rows of solid gold playfield (`PF0=$F0`, `PF1=$FF`, `PF2=$FF`), four blank rows, and the white six-digit frame counter. Below it, the picture is a dark grey field with a gold starfield, a six-row green player-0 ship that pans left and right, a six-row gold player-1 enemy at X=100, and a white ball on four rows (55-58) whose playfield rows are also white. The `HMOVE` on the first star row blanks the leftmost 8 pixels of row 21 only. The enemy and the ball are the bB sample's objects (player1 at X=100, ball at X=80); the ship is the sample's player0 with a green colour. The first band row is full-width gold: the VBLANK preloads its playfield bytes, so there is no left-edge notch. There is no `RUN` text and no label: the picture identifies the lens.

![Stella running Lens 0 of the Lesson 66 demo: a 3-row full-width gold bar and white score at the top, a gold starfield, a six-row green ship, a six-row gold enemy, and a four-row white ball zone; the title bar reads Stella 7.0: "demo-66"](/images/lesson66/run.png)

*`run.png`: Lens 0, the RUN picture, captured two seconds after launch. The 3-line gold bar and the white frame counter are the whole header; there is no text. The four white playfield rows (55-58) are the ball's zone; the 2-pixel ball column at X=80-81 is visible on rows 55-57 because the first enable is set on the wrapper line (the playfield stays white on 55-58). The first star row (row 21) has its leftmost 8 pixels blanked by the picture's `HMOVE`.*

<RomPlayer rom="/roms/part9-dsl-path/66-analyzing-batari-basic/demo-66.bin" title="Lesson 66 — Analyzing batari BASIC (demo)" />

Javatari starts muted; these ROMs are silent, so there is nothing to unmute.

The auto-demo advances to **Lens 1 — ZONES** at about four seconds, or immediately on a SELECT edge. The four bands are the frame phases as a teaching projection: 3 white VSYNC rows, 37 blue VBLANK rows, 122 green kernel rows (the 192-line kernel compressed into the visible window), and 30 red overscan rows. The white staircase is the row bar: it steps one 4-pixel chunk to the right every eight rows, so the diagonal is the kernel's row loop. `CTRLPF` is left at repeat (`$10`), so the 20-bit playfield draws the same staircase **twice**, at x and x+80; the capture shows both. There are no phase labels on the screen; the lesson's text names them. The white band at the very top is only 3 rows; the TV does not show the real blanked VSYNC, VBLANK, or overscan lines, which is why the map is a projection, not a photograph.

![Stella running Lens 1 of the Lesson 66 demo: a 3-row white band, a blue VBLANK band, a large green kernel band, and a red overscan band, with a white staircase row bar; no text labels; the title bar reads Stella 7.0: "demo-66"](/images/lesson66/zones.png)

*`zones.png`: Lens 1, the frame map, captured six seconds after launch. The bands keep the true 3/37/30 blanked counts and compress the 192-line kernel into 122 visible rows; the staircase is the row bar, repeated in both 80-pixel halves by `CTRLPF=$10`. The phase names are in the paragraph above, not on the screen.*

The auto-demo advances to **Lens 2 — VARS** at about eight seconds, or on a second SELECT edge. The 16-line band is the same gold bar and a six-digit window. The window reads the group code followed by the two hex digits of the address: the capture shows `0 8 9`, group 0 (SYS) at `$89`. The 16×8 grid is 128 cells, one per RIOT RAM byte. Each cell is a four-pixel bar whose height is the group: SYS is a full row (eight cell lines), SCR seven, PTR six, TMP five, RND four, PF three, DIM two; AUX is the top dot and STK the bottom dot. Each grid row is nine display lines: a preload line that repeats the first cell line, then the eight cell lines. Two dark gap lines separate the rows. The white block is the ball: it makes the selected row a **solid** 8-pixel white block over the row's nine lines, spanning the 4-pixel cell and the 4-pixel gap after it (the capture: row 0, column 9, X=88-95, lines 18-26). The gap lines stay dark. The preload line and the first cell line match for every row 1-7. The rest of the screen below the grid is dark. There is **no legend and no footer text**; the table below maps the group codes and bar heights to the owners.

![Stella running Lens 2 of the Lesson 66 demo: a 3-row gold bar and a six-digit hex score at the top, a 16×8 bar-chart grid of the 128 RAM bytes, a solid white block over the selected row, and a dark lower half with no legend; the title bar reads Stella 7.0: "demo-66"](/images/lesson66/variables.png)

*`variables.png`: Lens 2, the RAM map, captured ten seconds after launch. The score window shows `0 8 9` (group 0, SYS, at `$89`); the solid white block is the selected row 0, column 9 (X=88-95, lines 18-26). The grid is a bar chart of the nine bB groups; the preload line and first cell line match for rows 1-7; the dark lower half carries no legend; the table below maps the groups.*

The VARS group table:

| Code | Owner | Address range | Cell bar |
|---:|---|---|---|
| 0 | SYS | `$80-$92` and `$EE-$EF` | 8 lines (full) |
| 1 | SCR | `$93-$95` | 7 lines |
| 2 | PTR | `$96-$9B` | 6 lines |
| 3 | TMP | `$9C-$A1` | 5 lines |
| 4 | RND | `$A2-$A3` | 4 lines |
| 5 | PF | `$A4-$D3` | 3 lines |
| 6 | DIM | `$D4-$ED` | 2 lines |
| 7 | AUX | `$F0-$F5` | top dot |
| 8 | STK | `$F6-$FF` | bottom dot |

The heights are **cell lines**. The preload line repeats the first cell line,
so a full SYS row shows nine white lines (the preload line plus the eight cell
lines). The block is not a hollow outline; it is the cell's row turned solid,
plus the 4-pixel gap after it.

The bB reference is a **separate** ROM. It is not the demo and it is not generated by ACME:

![Stella running the batari BASIC reference ROM: a dark grey screen with the white six-digit score at the bottom, a blue player 1 above it, and a small gold ball; the title bar reads Stella 7.0: "lesson66-bb"](/images/lesson66/bb-run.png)

*`bb-run.png`: the bB 1.9 reference build. The six-digit score is at the bottom in this `no_blank_lines` build; the blue player and the gold ball are the sample's `player1` and `ball`. The screen is the output of the real `lesson66.bas` compilation, not the demo; the sample's playfield is an **empty** 11-row block (all dots), so no playfield block appears.*

<RomPlayer rom="/roms/part9-dsl-path/66-analyzing-batari-basic/lesson66-bb.bin" title="Lesson 66 — batari BASIC 1.9 reference (lesson66.bas)" />

Javatari starts muted; these ROMs are silent, so there is nothing to unmute.

The reference ROM is produced by bB 1.9 + wasmtime 50.0.1 from `lesson66.bas`; the exact command is in Section 1. It is not built by `npm run roms`, not drift-checked, and not an ACME source. The demo's three lenses are hand-written ACME; the reference is the real compiler output the document analyzes.

The debugger tells the same story as numbers. The demo's checkpoints:

| Checkpoint | Address (committed demo) | Measured | Meaning |
|---|---|---|---|
| `StartFrame` | `$F1A9` | 259/3 (the first hit is the power-on partial frame at 14/18) | the first VSYNC instruction |
| `VblankStart` | `$F1B7` | 0/5 | the first VBLANK instruction |
| `BodyStart` | `$F2F2` | 37/5 | the first visible line |
| `OverscanStart` | `$F66B` | 229/6 | the first overscan instruction |
| `LensRead` | `$F1F3` | A = 0, 1, 2 | the active lens |
| `LensWrite` | `$F68B` | A = 1, 2, 0 at frames 241, 481, 721 | the new lens (auto-demo) |
| `FrameRead` | `$F1F0` | A = 1, 2, 3, … | the free-running frame counter |
| `MapIndexRead` | `$F28E` | A = 00..1E (VARS) | the highlighted RAM byte |

The frame checkpoints, first hits:

```text
# StartFrame
BP:           1  14 18 -14 | Nv-BdIzC f0 06 30 ff |    (power-on)
BP:           2 259 03 -59 | nv-BdIZc 00 0f ae ff |
BP:           3 259 03 -59 | nv-BdIZc 00 00 ae ff |

# VblankStart
BP:           2   0 05 -53 | nv-BdIZC 00 06 30 ff |
BP:           3   0 05 -53 | nv-BdIZc 00 0f ae ff |

# BodyStart
BP:           2  37 05 -53 | nv-BdIZC 00 05 30 ff |
BP:           3  37 05 -53 | nv-BdIZC 00 05 30 ff |

# OverscanStart
BP:           2 229 06 -50 | nv-BdIZc 00 0f ae ff |
BP:           3 229 06 -50 | nv-BdIZc 00 00 ae ff |
```

The auto-demo and map checkpoints:

```text
# LensWrite (the auto-demo, one hit every 240 frames)
BP:         241   0 74 154 | Nv-BdIzc 01 0d ae fd |
BP:         481   0 74 154 | Nv-BdIzc 02 17 ae fd |
BP:         721   0 75 157 | nv-BdIZC 00 40 00 fd |

# LensRead (the A changes at frames 241, 481 and 721)
BP:           2   0 68 136 | nv-BdIZc 00 06 30 ff |
BP:           3   0 68 136 | nv-BdIZc 00 0f ae ff |

# FrameRead
BP:           2   0 63 121 | nv-BdIzc 01 06 30 ff |
BP:           3   0 63 121 | nv-BdIzc 02 0f ae ff |

# MapIndexRead (VARS, first hit after the 481 transition)
BP:         481  13 51  85 | nv-BdIZC 00 08 20 ff |
BP:         482   1 19 -11 | nV-BdIZC 00 40 00 ff |
```

The three lenses measure 259/3, 0/5, 37/5, 229/6 in every case: the frame is 262 lines whichever picture is selected. A full overscan run logged every hit at scanline 229. The auto-demo changes `Lens` at frames 241, 481 and 721 (about four seconds apart); `LensWrite` and `LensRead` show the same 1 → 2 → 0 transitions. A SELECT edge also calls `AdvanceLens` and resets the 240-frame timer; the state log above is the automatic path. A `-holdselect` run (SELECT held at power-on) confirms the manual path: `LensWrite` hits at frame 2 with A=1, then the auto-demo resumes at 242 (A=2) and 482 (A=0), because the manual edge reset the timer. `MapIndexRead` runs only while VARS is active; its first hit is A=00 and it counts through 00–1E in the VARS window shown by the twelve-second log.

```text
# LensWrite, -holdselect (the manual path)
BP:           2   0 61 115 | Nv-BdIZc 01 06 30 fd |
BP:         242   0 74 154 | Nv-BdIZc 02 17 30 fd |
BP:         482   0 75 157 | nv-BdIZC 00 40 00 fd |
BP:         722   0 74 154 | nv-BdIzc 01 0e ae fd |

# MapIndexRead, 12 s (the VARS window)
BP:         481  13 51  85 | nv-BdIZC 00 08 20 ff |
BP:         482   1 19 -11 | nV-BdIZc 00 40 00 ff |
BP:         720   1 34  34 | nV-BdIzc 1e 40 00 ff |
```

The bB reference checkpoints (from the symbol file and the real ROM):

| Checkpoint | Address | Measured | Meaning |
|---|---|---|---|
| `start` | `$F000` | 0/00 (the first instruction) | the reset target |
| `kernel` | `$F034` | 31/32 | the 2-line kernel entry |
| `drawscreen` / `overscan` | `$F3BF` | 47/36 | the user's `JSR` into the hand-off |
| `vblk` | `$F438` | 9/50 | the VBLANK hand-off / `vblank_bB_code` hook |
| `game` | `$F45F` | — | the user program |
| `.main` | `$F4D0` | — | the user's main loop |

```text
# vblk
BP:           1   9 50  82 | Nv-BdIzc 9c 9c 9c fd |

# kernel
BP:           1  31 32  28 | nv-BdIzc 7f 9c 9c fd |

# overscan / drawscreen
BP:           0  47 36  40 | nv-BdIZc 00 0d 00 fd |
```

The pixel check of the committed images:

| Image | Size | Title bar | What the pixels show |
|---|---|---|---|
| `run.png` | 1010×807 | `Stella 7.0: "demo-66"` (present) | TIA area 960×606 at (25,106); gold bar rows 0-2 `(205,205,52)`, **row 0 full-width** (no left notch), blank rows 3-6, white score row 10 `(234,234,233)`; gold starfield/enemy `(205,205,52)`, green six-row ship `(81,179,80)` at x=124-131, y=134-139 (the code's Y+15 range is 135-140; the capture origin accounts for the one-line offset); the four white ball rows are 55-58, and the 2-pixel ball column at x=80-81 is visible on 55-57 because the first enable is the wrapper line; the left/right starfield mismatch is only on the sprite rows (55-58, 75-80, 134-139); row 21's leftmost 8 pixels are blank from the `HMOVE`; row 191's left/right halves match (0 mismatches), so the `StarLast` PF store is not sheared |
| `zones.png` | 1010×807 | `Stella 7.0: "demo-66"` (present) | TIA area 960×606 at (25,106); rows 0-2 white `(234,234,233)`, rows 3-39 blue `(36,40,176)`, rows 40-161 green `(19,91,18)`, rows 162-190 red `(158,19,18)`, row 191 red; the bar at row 100 is white at x=48 **and** x=128 (the repeat playfield draws two staircases); no text |
| `variables.png` | 1010×807 | `Stella 7.0: "demo-66"` (present) | TIA area 960×606 at (25,106); gold bar rows 0-2 `(205,205,52)`, white score row 10 with `0 8 9` at x=80/83, 88/91, 96/99; the solid white block is x=88-95, rows 18-26 (selected row 0, column 9); grid row 0 starts at 18 and row 1 at 29; each row is nine display lines plus two dark gap lines, and the preload line equals the first cell line for rows 1-7; row 106 (the skipped tail) is dark `(63,63,62)`, and the lower row 120 is dark too; no legend/text |
| `bb-run.png` | 1010×807 | `Stella 7.0: "lesson66-bb"` (present) | TIA area 960×606 at (25,106); white score `(234,234,233)` at x=61-106, y=177-184; blue player `(36,40,176)` at x=99-106, y=145-156; gold ball `(205,205,52)` at x=78, y=69-78; dark background `(63,63,62)`; the empty 11-row playfield draws no block |

> **Capture method.** `run.png`, `zones.png` and `variables.png` are window
> captures of
> `docs/public/roms/part9-dsl-path/66-analyzing-batari-basic/demo-66.bin`
> on the session display, each after the fixed wait that the auto-demo makes
> deterministic: 2 s for RUN (Lens 0), 6 s for ZONES (Lens 1), 10 s for VARS
> (Lens 2). The auto-demo advances the lens every 240 frames (about four
> seconds) when no SELECT is pressed; the 2/6/10 s points are one to two
> seconds before each next transition, so the capture cannot land on the
> wrong side. A SELECT edge still advances the lens immediately and resets
> the timer; the state log above quotes the automatic path. All three demo
> images are 1010×807 and carry the window frame/title bar
> `Stella 7.0: "demo-66"`. `bb-run.png` is the same pipeline on
> `.../lesson66-bb.bin` after 3 s; its title is
> `Stella 7.0: "lesson66-bb"`. The pointer was parked at `(0,0)` before every
> capture, outside the window; no cursor appears in any image. The TIA area is
> 960×606 at (25,106), and the first gold row is y=106. With that origin the
> RUN ship's green bbox measures y=134-139, one line above the code's Y+15
> range (135-140); the capture origin and row rounding account for the
> one-line difference. The ball's four white rows measure 55-58, matching the
> code. The bB reference's provenance is the bB 1.9 compile command in
> Section 1; it is not ACME and not drift-checked.

## Exercises

The exercises are analysis, not new code. Each asks you to find something in the committed bB listing or the reference ROM and prove it with the debugger; the answers are below each exercise. There are no `exercise-NN-solution.asm` files because the artifact is the analysis itself.

### Exercise 1: Find the `if` lowering, explain the reversed branch, and change the threshold

**Challenge:** Locate `if player0y > 120 then player0y = 60` in `lesson66.generated.txt`. Explain why the branch is taken when the condition is **false**, prove it with a Stella breakpoint on the reference ROM, and change the threshold to 100 in a scratch copy of the `.bas`. What changes in the listing, and what stays the same?

**Hints:**
1. The source line 72 is at listing line 1854; the generated block starts at `.L038` and the branch target is `.skipL038`.
2. `CMP player0y` computes `120 - player0y`; the carry is set when `120 >= player0y` (so `player0y <= 120`). The `BCS` target is a 4-byte forward branch.
3. `player0y` is the byte at `$85`; the assignment is `STA $85` at `$F4EA`. Set a breakpoint at `$F4E2` (the `LDA #120`) and at `$F4EA` (the store), and watch A and `$85`.

**Expected Result:** The listing shows `LDA #120 / CMP player0y / BCS .skipL038 / LDA #60 / STA player0y`; the branch is taken for `player0y <= 120` and the store runs only for `player0y > 120`. A Stella breakpoint at `$F4E2` hits every frame; a breakpoint at `$F4EA` hits only on the wrap. With 100, the `LDA #120` becomes `LDA #100` and the wrap happens at 101; the rest of the pattern — the reversed branch, the store, the fall-through — is unchanged.

**Answer:** The committed block is at lines 1854-1862:

```asm
.L038 ;;line 72;;  if player0y  >  120 then player0y = 60

	LDA #120
	CMP player0y
     BCS .skipL038
.condpart0
	LDA #60
	STA player0y
.skipL038
```

In the `lesson66.bas.list.txt` address column, `.L038` is `$F4E2`, the `LDA #120` is at `$F4E2`, `CMP player0y` at `$F4E4`, `BCS .skipL038` at `$F4E6` (operand `$04`, so the target is `$F4E8 + 4 = $F4EC`), `LDA #60` at `$F4E8`, `STA player0y` at `$F4EA`, and `.skipL038`/`.L039` at `$F4EC`. The `CMP` computes `120 - player0y`; the carry is **set** when `120 >= player0y`, i.e. when `player0y <= 120`. `BCS` therefore skips the assignment for `player0y <= 120`; the assignment runs only when `player0y > 120`. This is the 6502 idiom for a strict `>`: test the false side and branch over the body. At `player0y = 120` the carry is set and the body is skipped, which is exactly the strict `>` in the source.

A Stella breakpoint at `$F4E2` hits on every frame (the `LDA` is unconditional); a breakpoint at `$F4EA` hits only when the body runs, i.e. when `player0y` was 121 or more. The `player0y` byte is `$85`; the store `STA $85` is the proof. Change line 72 to `if player0y > 100 then player0y = 60` and rebuild with bB 1.9: the listing's `LDA #120` becomes `LDA #100`, the `BCS` target and the body are the same, and the wrap happens at 101. The threshold is an immediate in the compare, not a table entry; the branch polarity and the `STA player0y` do not change. The score chain and the rest of the main loop are untouched.

### Exercise 2: Map the bB variables and explain why `dim` costs no RAM

**Challenge:** Use `2600basic_variable_redefs.h`, the bB symbol file, and the committed listing to find `player0y`, `player1y`, `score`, `temp1`, and the stack. Prove the addresses with a Stella RAM watch. Explain why a `dim` alias costs no RAM, and what the VARS lens's groups correspond to in the listing.

**Hints:**
1. The symbol file is produced by the compile (`lesson66.bas.symbol.txt`); the addresses are also in the bB `2600basic.h` map.
2. `player0y`/`player1y` are the two bytes just above `ballx`; `score` is three bytes at `$93`; `temp1` is the first of six kernel temporaries; the stack bytes are at the top of the map (`stack1` at `$F6`).
3. A `dim` statement is a compile-time alias, not an allocation: the 26 letters at `$D4-$ED` and `var0`-`var47` at `$A4-$D3` are already reserved.

**Expected Result:** `player0y` `$85`, `player1y` `$86`, `score` `$93-$95`, `temp1` `$9C`, `scorepointers` `$96-$9B`, `playfield` `$A4-$D3`, `stack1` `$F6`. A Stella watch on `$85` changes every frame; the score's **ones** byte `$95` changes every frame, while `$94`/`$93` change only on carries; `$9C` changes inside the kernel. `dim` adds no bytes: the map is fixed before the program is parsed.

**Answer:** The symbol file gives `player0y = $85`, `player1y = $86`, `score = $93` (three bytes, `$93-$95`), `temp1 = $9C` (`temp1`-`temp6` are `$9C-$A1`), `scorepointers = $96` (six bytes, `$96-$9B`), `playfield = $A4` (the 48-byte `var0`-`var47` block, `$A4-$D3`), `stack1 = $F6`, `stack2 = $F7`, `stack3 = $F8`, `stack4 = $F9`. The full block from the bB 1.9 `2600basic.h` is in Section 5. The generated listing uses these addresses directly: `INC player0y` is `INC $85` at `$F4E0`; the score's `LDA score+2` is `LDA $95`; the `if`'s `CMP player0y` is `CMP $85`; the `sty temp1` at line 70 is `STY $9C`.

The `2600basic_variable_redefs.h` for this program contains only `no_blank_lines = 1`; it does not declare `player0y` or `score` because those names are in `2600basic.h` and the compiler's fixed map. A `dim` line such as `dim frame = a` makes `frame` another name for `$D4`; `dim sc0 = score` names `$93`; `dim sc1 = score+1` names `$94`. bB 1.9 accepts the expression alias; the compiler resolves it at parse time to the byte `$94`, and the committed listing's address column shows the lowered loads and stores. The bytes already exist, so the alias costs no RAM. The playfield array and the 26 letters are the two user pools; the `var0`-`var47` block is also the playfield storage (the default 11-row playfield uses 44 of the 48 bytes), and the `a`-`z` block is the 26 aliases.

The VARS lens maps the same groups to the grid: SYS `$80-$92` plus `$EE-$EF` (the player/missile/ball state and `playfieldpos`), SCR `$93-$95`, PTR `$96-$9B`, TMP `$9C-$A1`, RND `$A2-$A3`, PF `$A4-$D3`, DIM `$D4-$ED`, AUX `$F0-$F5`, and STK `$F6-$FF`. The cell bar heights encode the groups; the table in "What You Should See" maps each code and height to the owner. There is no legend on the screen.

A Stella RAM watch proves the live bytes: `$85` changes every frame from the `INC`; `$95` (the score's ones byte) changes every frame from `score = score + 1`, while `$94` and `$93` change only when the ones and tens carry; `$9C` changes in the kernel's temp use; `$F6-$F9` are the kernel's stack bytes. The bytes at `$D4-$ED` are untouched by this program, which is why the VARS lens marks them as the free `dim` pool.

### Exercise 3: Trace `drawscreen`, measure the frame, and explain the 2-line kernel

**Challenge:** Starting from `jsr drawscreen` at listing line 1879, find the 2-line kernel, the `vblank_bB_code` hook, and the overscan. Measure the bB reference frame in Stella. Explain what the 2-line kernel buys and costs, and name one thing you would hand-write instead.

**Hints:**
1. `drawscreen` is at `$F3BF`, and so is `overscan`; the `ifconst debugscore`/`debugcycles` blocks between them are compiled out. The `vblk` label is at `$F438` and the `kernel` label at `$F034`.
2. `kernel`'s first instruction is `sta WSYNC`; the comment at line 112 says "This is a 2-line kernel!".
3. The `vblank_bB_code` hook is the `ifconst` block at lines 1636-1638; this program does not define it, so the `jsr` is absent.

**Expected Result:** `jsr drawscreen` calls `$F3BF`; the `overscanloop` waits for the visible-area timer that `kernel` armed, does the VSYNC, and reaches `vblk`/`vblk2`, which polls the VBLANK timer and jumps to `kernel` at `$F034`. `kernel` starts with `sta WSYNC` and the 2-line loop. The bB state log gives `vblk` 9/50, `kernel` 31/32, and the `drawscreen`/`overscan` entry 47/36; the bB frame is the standard NTSC 262 lines. The 2-line kernel buys cycle slack and a simple fixed loop; it costs vertical resolution (two lines per sprite row) and the fixed kernel shape.

**Answer:** The user's `drawscreen` is `jsr drawscreen` at line 1879. The `drawscreen` label at `$F3BF` is followed by the `ifconst debugscore` block (lines 1419-1458), the `ifconst debugcycles` block (1460-1467), and the `overscan` label at 1469. Both debug blocks are compiled out, so `drawscreen` and `overscan` are the same address. The code at `$F3BF` polls `INTIM` (`overscanloop: lda INTIM / bmi overscanloop`), does the VSYNC, and reaches `vblk` at `$F438`. `vblk` runs the `ifconst vblank_bB_code` hook (lines 1636-1638; not assembled here) and `vblk2` polls `INTIM` again before `jmp kernel`. The `kernel` at `$F034` starts with `sta WSYNC` and the `; This is a 2-line kernel!` comment at line 112; the kernel draws every logical row twice.

The bB reference state log from the committed `lesson66-bb.bin`:

```text
# vblk
BP:           1   9 50  82 | Nv-BdIzc 9c 9c 9c fd |
# kernel
BP:           1  31 32  28 | nv-BdIzc 7f 9c 9c fd |
# overscan / drawscreen
BP:           0  47 36  40 | nv-BdIZc 00 0d 00 fd |
```

The frame is the NTSC 262-line frame; the bB kernel is 192 visible lines, and the VBLANK/kernel/overscan hand-offs are the three labels. To measure it yourself, break at `$F438` (the VBLANK hand-off), `$F034` (the kernel entry), and `$F3BF` (the `drawscreen`/overscan entry), and read the scanline column; the same three anchors reproduce the table.

The 2-line kernel buys **time**: the kernel has two scanlines to load and store each logical row's sprite/playfield bytes, and the loop is simple and predictable. It costs **vertical resolution**: a 6-row player is 12 scanlines, an 8-row score is 16 lines, and the playfield's chunks are 4 pixels wide. It also fixes the kernel's shape: the score/playfield/players/missiles/ball all have a slot, and a mid-line colour change or a different score height is outside the generated loop. One thing to hand-write instead: a **mid-line colour/status bar** (change `COLUBK`/`COLUPF` at a fixed cycle inside a line) or a **1-line sprite kernel** for a taller, sharper player. Both are exactly the kind of kernel the demo hand-writes; bB's fixed 2-line kernel cannot express them.

## Key Takeaways

- ✅ **bB is a four-stage pipeline, not one compiler.** Preprocess → compile → link → assemble produces `bB.asm`, the linked `lesson66.generated.txt`, and the 4,096-byte `.bin`; the listing is DASM evidence, the course build stays ACME.
- ✅ **The generated `start` is a RAM probe, a clear, and a jump to the kernel.** It reads `$D0/$D1`, compares `$2C/$A9`, clears the stack page with `inx/txs/pha`, sets `playfieldpos`, and jumps to `game`.
- ✅ **`drawscreen` is a `JSR` into the fixed frame.** In this build `drawscreen` and `overscan` are the same `$F3BF`; `vblk` runs the `vblank_bB_code` hook and `vblk2` jumps to the 2-line `kernel` at `$F034`.
- ✅ **The `if` lowering is a reversed branch, and the score is BCD.** `LDA #120 / CMP player0y / BCS .skip` runs the assignment only for `player0y > 120`; `SED`/`CLC`/`ADC`×3/`CLD` add 1 to the three decimal bytes.
- ✅ **The variable map is fixed and `dim` is only an alias.** `player0y` is `$85`, `score` is `$93-$95`, `temp1` is `$9C`, the stack starts at `$F6`; `dim` names an existing byte in the `a`-`z`/`var0` pool.
- ✅ **The 2-line kernel is the trade.** It buys cycles and a simple loop, and costs vertical resolution and the fixed kernel shape; a mid-line colour change or a 1-line sprite kernel is a hand-written job.
- ✅ **The demo is not bB output, and it carries no text.** `demo-66.asm` is a hand-written ACME model of the bB architecture; the three pictures (and the lesson's group table) carry the meaning. The real compilation is `lesson66.bas` + `lesson66.generated.txt` + `lesson66-bb.bin`, with the committed address listing, symbol table, and redefs header; the document keeps the two separate.

## What's Next

You have read a real compiler's output from `start` to the BCD score. [Lesson 67: Identifying Automatable Patterns — A Wave Compiler](/part9-dsl-path/67-automatable-patterns) turns the analysis around: instead of reading a generator, you write one. A line-oriented wave spec, a Python generator that validates it and emits an ACME include, and a 4,096-byte engine that interprets the generated tables — the same boundary between data, generated code, and the hand-written kernel that this lesson found in bB.
