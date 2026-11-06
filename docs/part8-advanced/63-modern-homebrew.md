---
title: "Lesson 63: Modern Homebrew — Dev Carts and Community"
description: "Build a 4,096-byte attract mode — a two-scene title and credits screen with a playfield RTB logo, a starfield, a colour-cycling border, a pre-shifted scrolling marquee, and a 32-note TIA tune — and learn the modern homebrew pipeline: Harmony and UnoCart flash carts, the AtariAge community, contests and publishing, batari Basic, 8bitworkshop, Stella, and ACME."
prev:
  text: "Lesson 62: Reverse Engineering a Classic Game — Reading Wall Buster"
  link: "/part8-advanced/62-reverse-engineering"
next:
  text: "Lesson 64: Building Your Own Cartridge — From ROM to Physical Cart"
  link: "/part8-advanced/64-building-cartridges"
---

# Lesson 63: Modern Homebrew — Dev Carts and Community

> **Part 8: Advanced Topics** · Estimated time: 60 minutes
> **Prerequisites:** Lesson 03 (the 2600 anatomy and memory map), Lesson 04 (registers and memory), Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 19 (the playfield), Lesson 25 (players), Lesson 26 (horizontal positioning), Lesson 35 (sound), Lesson 39 (the score kernel), Lesson 41 (game states), Lesson 48 (the kernel taxonomy), Lesson 53 (kernel patterns), Lesson 54 (visual effects), Lesson 55 (scrolling text)
> **You will learn:** the modern 2600 homebrew pipeline; what Harmony and UnoCart flash carts do; how the AtariAge community, homebrew contests and awards, and publishing fit together; the modern toolchain (batari Basic, 8bitworkshop, Stella, ACME); how to tell a tech demo from a shippable game; and how an attract mode turns a ROM into a production-value showcase
> **You will build:** "the attract mode" — a 4,096-byte two-scene title and credits ROM: an RTB playfield logo, a 64-row starfield, colour-cycling border bands, a six-character scrolling marquee, a 32-note TIA tune, fire and SELECT scene edges, and a 300-frame auto-demo

## Introduction

Lesson 62 took a finished ROM apart. This lesson builds one that looks like a release. The difference is not a single trick: it is a set of production values and a pipeline. A homebrew author writes the code, assembles it, tests it in an emulator, flashes it to a cartridge, draws a label, answers a forum thread, and decides whether the ROM is free, paid, or manufactured. The 2600 scene is small enough that one person can do every stage, and that is the point of this lesson: the artifact is a `.bin` that can travel from a text editor to a television.

The artifact is **"the attract mode"**, a 4,096-byte ROM with two scenes. Scene 0 is the title: a large playfield **RTB** logo, a starfield, colour-cycling border bars, a six-character scrolling marquee reading **MODERN HOMEBREW**, and a 32-note TIA tune. Scene 1 is the credits: a blue field, gold stars, and four white lines — **RACING / THE / BEAM / THANKS**. Fire advances to the credits; SELECT returns to the title. A 300-frame auto-demo advances title → credits on its own, so both captures are reproducible without input. The credits screen stays until SELECT.

The production-value constraint is the same one every 2600 release lives with: 192 visible lines, 128 bytes of RAM, 4,096 bytes of cartridge, and one HMOVE per frame. The lesson uses the Lesson 55 score library for the six-column text window, the Lesson 54 starfield idea for the background, and a compact table-driven logo. The result is not a game — it is the screen that sells a game before the player presses fire, and the lesson is explicit about the difference.

::: details TypeScript Equivalent

An attract mode is easy to model in TypeScript. A state object holds the scene, the clocks, and the input edges; `step()` advances them once per frame; `draw()` paints the current state:

```typescript
type Scene = 'title' | 'credits';

interface Attract {
  scene: Scene;
  frame: number;
  scroll: number;        // 0..80, the marquee's first pixel
  tuneIndex: number;     // 0..31
  tuneTimer: number;     // frames left on the note
  autoTimer: number;     // frames until title -> credits
}

function step(a: Attract, fire: boolean, select: boolean): void {
  a.frame++;

  if (fire) {
    a.scene = 'credits';
    a.autoTimer = 0;
    a.tuneIndex = 0;
    a.tuneTimer = 1;
  }
  if (select) {
    a.scene = 'title';
    a.scroll = 0;
    a.autoTimer = 300;
    a.tuneIndex = 0;
    a.tuneTimer = 1;
  }

  if (a.scene === 'title' && --a.autoTimer === 0) a.scene = 'credits';
  if (a.frame % 4 === 0) a.scroll = (a.scroll + 1) % 81;
  if (--a.tuneTimer === 0) {
    a.tuneIndex = (a.tuneIndex + 1) % 32;
    a.tuneTimer = 6;
  }
}

function draw(a: Attract): Screen {
  const s = new Screen(160, 192);
  if (a.scene === 'title') {
    drawBars(s, a.frame);
    drawStars(s);
    drawLogo(s, 'RTB');
    drawMarquee(s, 'MODERN HOMEBREW ', a.scroll);
  } else {
    drawBars(s, 0, 'gold');
    drawStars(s);
    drawTextBlock(s, ['RACING', ' THE  ', ' BEAM ', 'THANKS']);
  }
  return s;
}
```

The analogy teaches the shape: a scene, a set of frame clocks, input edges, and a draw pass. It breaks in the four places that matter on a 2600. First, `draw()` can paint a whole framebuffer at once; the console has **no framebuffer**, so the draw is a kernel that produces one scanline at a time, in real time, inside a 76-cycle line budget. Second, the TypeScript `Screen` is a flat array; the 2600 has 128 bytes of RAM and a 4,096-byte cartridge, so the logo, the stars, the message, and the tune are all tables in ROM. Third, the TypeScript `drawMarquee` can measure and shift text at run time; the 2600 version cannot afford that in VBLANK, so the message is stored **pre-shifted** into eight phase blocks and the fill is a 48-store copy. Fourth, the TypeScript `draw()` can use any colour at any pixel; the 2600 has one `COLUPF` register shared by the playfield, the ball, and the stars, so the title's bars, logo, and stars all change colour together.

:::

## Theory

### Section 1: The Modern Pipeline

A homebrew release is a pipeline, not a file. The stages are simple, and one person can own all of them:

| Stage | The question it answers | A typical tool |
|---|---|---|
| Design | What is the screen, the goal, the controls? | paper, a prototype, a sketch |
| Code | What are the tables and the kernel? | ACME (this course), batari Basic, 8bitworkshop |
| Assemble | Does the source become a `.bin`? | ACME |
| Test | Is the frame stable, and what do the registers say? | Stella and its debugger |
| Flash | Does it run on a real console? | Harmony, UnoCart |
| Share | Can someone else play it? | a ROM download, a video, a forum post |
| Publish | Is there a cartridge, a label, a manual? | Lesson 64, a cartridge maker |
| Support | Do the bug reports and the PAL/NTSC questions get answered? | the community |

Not every release visits every stage. A free ROM may stop at **Share**; a physical release adds **Publish** and **Support**. The pipeline is a checklist, not a law. The important habit is that the `.bin` is the artifact that moves between the stages: the same file is assembled, tested, flashed, and (if the author chooses) manufactured. A build that only exists in an emulator's memory is not yet a release.

::: tip The ROM is the contract
Stella loads a `.bin`; a flash cart loads a `.bin`; a cartridge programmer burns a `.bin`. The mapper, the size, and the vectors are the interface. If the ROM is 4,096 bytes and the vectors point at `Reset`, every stage in the pipeline can consume it. That is why the lesson's build command and the committed file are part of the deliverable, not an afterthought.
:::

### Section 2: Flash Carts — Harmony and UnoCart

A **flash cart** is a reusable cartridge. It has its own firmware and a menu; it reads a ROM image from an SD card, presents that image to the console as a cartridge, and lets the developer pick another image without burning a chip. The two names a 2600 developer is most likely to meet are **Harmony** and **UnoCart**. Harmony is a commercial flash cart; UnoCart is an open-source design. Both exist to run the same `.bin` you test in Stella on a real 2600.

The point is not the menu. The point is the difference between a model and the machine. Stella is an excellent model — this course uses it for every timing claim — but the real console has an analog video signal, a real TIA, a real RIOT, real controllers, and a real power supply. A flash cart is how an author closes that gap before shipping. A game that looks perfect in an emulator can still show a colour phase, a controller deadzone, or a timing edge on hardware; a flash cart is the cheapest way to find out.

The exact mapper support, menu behaviour, and firmware of any flash cart change over time. Check the current documentation rather than treating a version number as a permanent fact. A flash cart is also **not** a production cartridge: it is reusable and menu-driven, while a production cart is one ROM on a PCB with a shell and a label. Lesson 64 builds that object.

### Section 3: The Community, Contests, and Publishing

**AtariAge** hosts the long-running 2600 Programming forum: register questions, kernel tricks, release announcements, and historical threads. The course's `sources.md` lists it as a canonical community reference. A forum is a community, not a specification; when a thread and `include/vcs.asm` disagree about a register, the register file wins. The forum is where a new author finds the vocabulary, the tool links, and the people who have already made the mistake.

**Homebrew contests and awards** have been part of the scene. They are community-run, and their schedules, categories, and rules change. A contest is useful for a deadline and for feedback; it is not a stable fact to cite. This lesson does not name a specific year or a specific winner, because those are history rather than guidance.

**Publishing and distribution** are a set of trade-offs:

| Path | What the author gets | What the author gives up |
|---|---|---|
| Free ROM | the widest reach; the copyright stays with the author | no revenue; support is voluntary |
| Paid ROM | a price and a license; a direct relationship with the buyer | payment handling, support, piracy |
| Physical cartridge | a collectible object; a label and a manual; a small run | PCB, shell, assembly, shipping, up-front cost |
| License to a publisher | the publisher handles manufacturing and distribution | some control and some revenue |

The market is niche. This lesson makes no claim about sales numbers, because a number that is true for one release is not a rule for the next. The right path depends on the game, the author's goals, and the time the author wants to spend on everything that is not code.

**Licensing** follows from the same facts. The ROM is the author's copyright; a cartridge maker needs a license to manufacture it. Atari's trademarks are not the homebrew author's to use; a release uses its own name and artwork. The course-written demo in this lesson is original for exactly this reason: it can be annotated, copied, and shipped as a teaching example without a licensing problem.

### Section 4: The Modern Toolchain

The 2600 toolchain is small, and each tool has a different job:

| Tool | What it is | When it is the right choice |
|---|---|---|
| **ACME** | a 6502 assembler with `!cpu 6502`, `!source`, `* =`, macros, and a plain-binary output | when the lesson is about the machine and the kernel; full control, more work |
| **Stella** | the reference emulator and debugger: breakpoints, state logs, RAM/TIA/ROM views, a symbol file | every day; it is the ground truth for this course |
| **8bitworkshop** | a browser IDE with VCS support, examples, and a built-in emulator | a quick experiment, a shared example, a first look at a mapper |
| **batari Basic** | a BASIC-like language that compiles to 6502 | a first game or a fast prototype; the kernel is hidden |
| **Harmony / UnoCart** | flash carts | running the `.bin` on real hardware |

The course uses **ACME + Stella** because the lessons are about the 2600, not about a framework. batari Basic is a legitimate way to make a first game, and 8bitworkshop is a legitimate way to try an idea in a browser; neither is a lesser choice if it gets the game finished. The tool is not the identity. The artifact is the `.bin`, and the discipline is the same: a stable frame, a readable screen, and a build that can be reproduced.

::: tip Which tool should a beginner use?
If the goal is to understand the machine, start with ACME and a 4K kernel, as this course does. If the goal is to have a playable game this month, batari Basic or 8bitworkshop will get there faster. The two paths meet at the `.bin`: a batari Basic game still runs on a flash cart, and an ACME game still needs a title screen and a manual. The lesson's pipeline does not care which compiler produced the file.
:::

::: tip References and claim discipline
The hardware numbers in this lesson are the course's documented facts: the NTSC frame is 262 lines (3 + 37 + 192 + 30), a scanline is 76 CPU cycles, the RIOT RAM is 128 bytes at `$80–$FF`, and the cartridge window is 4,096 bytes. The community and tooling claims are the course's summary of the public references listed in `sources.md`: the Stella Programmer's Guide and problemkaputt.de for the hardware, the AtariAge 2600 Programming forum for the community, the Stella debugger documentation and the ACME manual for the tools, and the batari Basic reference for the BASIC path. Community details change; the hardware numbers do not. Specific contest years, winners, and sales figures are deliberately omitted.
:::

### Section 5: A Tech Demo Is Not a Shippable Game

A **tech demo** proves a technique. It may be one screen, one effect, one clever kernel. A **shippable game** is a product: it has a goal, controls, a difficulty curve, a game-over and a restart, sound, a title and an attract mode, a manual, a license, and a distribution plan. The gap between the two is mostly production work, and it is the gap this lesson is about.

| A tech demo | A shippable game |
|---|---|
| proves one effect | proves the effect **and** the game loop |
| one screen | a title, an attract mode, the game, a game-over, a restart |
| runs until the developer stops it | has a goal, a score, a win or a loss, a difficulty curve |
| tested in Stella | tested on hardware, with real controllers, on NTSC and PAL |
| a source file | a ROM, a readme, a license, a label, a distribution plan |

The **attract mode** is the bridge. It is not gameplay, but it is the first thing a player sees, and it sets the expectation. A logo, a colour scheme, a message, a tune, a credits screen, and an auto-demo that shows the game without input are production value, and they are cheap compared with the game itself. A player who sees a polished title screen expects a polished game; a player who sees a test pattern expects a test.

The demo in this lesson is a tech demo **with production values**. It has no game loop, no score, and no win or loss. The exercises add a high-score screen and a reset, which is the first step toward a shippable attract mode. The lesson is honest about the boundary: a title screen is not a game, but a game without one feels unfinished.

### Section 6: The Attract Mode's Architecture

The demo is two scenes sharing one 262-line frame. `Scene` at `$80` is 0 (title) or 1 (credits). The VBLANK block runs the same clocks every frame — the tune, the fire and SELECT edges, the auto-demo, the scroll, the colour cycle, and the frame counter — and then a scene setup chooses the colours, fills the marquee (title only), and calls `ScoreSetup`. The visible kernel is dispatched on `Scene`.

**The title.** The top 17 lines are a colour bar: the border's playfield bytes stay latched through the marquee band because `ScoreDraw` writes only the players. The marquee occupies rows 9–16, the starfield fills rows 17–183, the RTB logo occupies rows 48–103, and an 8-line colour bar closes the bottom. The logo is a compact 7-row table of playfield chunks, expanded to 56 scanlines with `!fill` and OR'd with the star plane at run time.

**The credits.** The same border bars and starfield, a different background (`$84` blue instead of `$02`), a fixed gold `COLUPF`, and four 6-character white text blocks at rows 33–40, 73–80, 113–120, and 153–160. The text uses the same six-column P0/P1 window as the marquee, so the credit lines are readable at eight pixels per character.

**The scroll.** `Scroll` runs 0..80. `Phase = Scroll & 7` and `ByteIndex = Scroll >> 3` select a pre-shifted 128-byte block and a six-character window inside it. `FillMarquee` copies six columns into the score library's 48-byte buffer; `ScoreDraw` draws the nine-line band. The 16-byte row stride is deliberate: a six-byte window starting at byte 10 is still inside the row, so the `(ptr),Y` read never crosses a page.

**The tune.** Thirty-two notes in two 32-byte tables: `TuneFreq` and `TuneDur`. `TuneTimer` counts down in frames; at zero the engine writes `AUDF0`, `AUDC0=$0C`, and `AUDV0=$0A`, reloads the duration, and advances `TunePtr` with a wrap at 32. The tune restarts on a scene change.

**The colour cycle.** Eight bright hues in `TitleColors`, one every eight frames, written to `COLUPF`. The title's bars, logo, and stars share the register, so they change together; the credits use a fixed gold.

**The auto-demo.** A 300-frame timer on the title advances to the credits. Fire jumps to the credits and disarms the timer; SELECT returns to the title, rearms the timer, rewinds the marquee, and restarts the tune. The fire edge has an eight-frame startup window; a button held from power-on still produces exactly one edge.

**The checkpoints.** The four frame labels (`StartFrame`, `VblankStart`, `BodyStart`, `OverscanStart`), `CreditsOverscan` for the credits path, and the state clocks (`SceneRead`, `ScrollRead`, `TunePtrRead`, `FrameRead`). The state log proves the clocks; the two images prove the picture.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/demo-63.bin lessons/part8-advanced/63-modern-homebrew/demo-63.asm
stella build/demo-63.bin
```

The committed ROM is `docs/public/roms/part8-advanced/63-modern-homebrew/demo-63.bin`, 4,096 bytes. The source is `lessons/part8-advanced/63-modern-homebrew/demo-63.asm`. The ROM is silent only until you unmute Stella; the tune is real, and the in-page Javatari player starts muted.

### Full Source

The complete annotated source:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 63: Modern Homebrew — Dev Carts and Community
; =============================================================================
; Part 8: Advanced Topics
;
; What this program does:
;   "the attract mode": a 4,096-byte production-value title screen.  Two
;   scenes share one 262-line frame:
;
;     Scene 0 — the title.  A large playfield "RTB" logo (seven chunk rows,
;       eight scanlines each) over a 64-row starfield; solid colour-cycling
;       border bands across the top and bottom; a six-character scrolling
;       marquee ("MODERN HOMEBREW ") drawn by P0/P1 in the Lesson 55
;       six-column window; and a 32-note TIA tune on channel 0.
;
;     Scene 1 — the credits.  A fixed dark-blue field, gold stars and border
;       bands, and a four-line white credit block ("RACING / THE / BEAM /
;       THANKS") drawn by the same P0/P1 window.
;
;   Fire advances to the credits; SELECT returns to the title.  An auto-demo
;   advances title -> credits after 300 frames (5 s at 60 Hz) so the two
;   captures are reproducible without input; the credits screen then stays
;   until SELECT.  Fire and SELECT are edge-triggered: a held button acts
;   once.
;
;   The title's marquee scrolls one pixel every four frames.  Scroll 0..80
;   selects a phase (0..7) and a character offset (0..10).  The message is
;   stored pre-shifted in eight 128-byte phase blocks, the Lesson 55
;   technique; FillMarquee copies six columns into the score library's
;   buffer and ScoreDraw draws the nine-line band.
;
;   The tune is a 32-note table.  TuneTimer counts down in frames; at zero
;   the next note writes AUDF0, AUDC0=$0C and AUDV0=$0A.  The note tables are
;   two parallel 32-byte arrays (frequency, duration), so the engine needs
;   only an index and a timer.  The tune restarts on a scene change.
;   Javatari starts muted; click the player to hear it.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259/3, VblankStart 0/5, BodyStart 37/5, OverscanStart 229/6.
;
; The title picture (192 visible lines):
;   rows   0-7    the top border band (all 20 chunks lit)
;   rows   8-16   the marquee (line 8 setup, lines 9-16 glyphs).  ScoreDraw
;                 writes only P0/P1, so the border's PF bytes stay latched
;                 behind the text and the visible top bar is 17 lines tall.
;   rows  17-47   starfield (31 lines)
;   rows  48-103  the RTB logo (7 rows x 8 lines), stars OR'd in
;   rows 104-183  starfield (80 lines)
;   rows 184-191  the bottom border band
;
; The credits picture (192 visible lines):
;   rows   0-7    the top border band
;   rows   8-31   starfield (24 lines)
;   rows  32-40   credit line 1 (row 32 setup, rows 33-40 glyphs)
;   rows  41-71   starfield (31 lines)
;   rows  72-80   credit line 2
;   rows  81-111  starfield (31 lines)
;   rows 112-120  credit line 3
;   rows 121-151  starfield (31 lines)
;   rows 152-160  credit line 4
;   rows 161-183  starfield (23 lines)
;   rows 184-191  the bottom border band
;   The text macro ends with an aligning WSYNC: the last glyph row and the
;   first star row share a line in the register timeline, and the WSYNC
;   makes the next loop start on a fresh line.  Each block is 40 lines.
;   The macro writes only P0/P1; the playfield bytes stay latched at the
;   last star row for the eight text lines, so a few gold chunks repeat
;   behind a word.  The star loops resume on the line after the block.
;
; The starfield:
;   StarPF0/1/2 are 64-byte planes, page-aligned.  The kernel indexes them
;   with Y & $3F, so the 64-row pattern repeats three times down the screen.
;   The pattern is sparse: one or two 4-pixel chunks per row.  The logo zone
;   is an expanded table: each of the seven logo rows is repeated eight times
;   with !fill and OR'd with the star plane at run time, so the compact
;   LOGO_Rn_* constants are the only logo definition.
;
; Cycle ledger (the line is 76 cycles; every visible line fits):
;   star loop, title:   TYA+AND+TAX (6) + three plane loads/stores (21) +
;                       STA WSYNC+INY+CPY+BNE (10) = 37.
;   star loop, credits: the same 37 plus the two GRP clears (8) = 45.
;   logo loop:          6 + (LDA 4 + ORA 4 + STA 3) x 3 + 10 = 49;
;                       50 on a row whose table read crosses a page.
;   top/bottom border:  21 on the first line (the LDA), 19 on the rest.
;   ScoreDraw and the text-line macro are the Lesson 55 sequence; its stores
;   are inside the 76-cycle line by construction (Lesson 55 measured them).
;
; Checkpoints (Stella scanline/cycle, and the A register):
;   StartFrame    259/3  the first VSYNC instruction
;   VblankStart   0/5    the first VBLANK instruction
;   BodyStart     37/5   the scene dispatch
;   SceneRead     37/8   A = 0 (title) or 1 (credits), every frame
;   OverscanStart 229/6  the first overscan instruction (title path)
;   CreditsOverscan 229/6 the first overscan instruction (credits path)
;   ScrollRead    A = the marquee offset, 0..80
;   TunePtrRead   A = the note index, 0..31
;   FrameRead     A = the free-running frame count, 0..255
;
; RAM map (+clean_start zeroes every byte):
;   $80 Scene          0 = title, 1 = credits
;   $81 Frame          the free-running frame counter (a byte)
;   $82 Scroll         the marquee offset, 0..80
;   $83 TunePtr        the note index, 0..31
;   $84 TuneTimer      frames left on the current note
;   $85 PrevFire       fire state last frame
;   $86 PrevSelect     SELECT state last frame
;   $87 Startup        frames left before fire is trusted
;   $88 NewFire        this frame's fire 0 -> 1 edge
;   $89 Scratch        SELECT's pressed level
;   $8A AutoTimerLo    the 300-frame auto-demo timer, low byte
;   $8B AutoTimerHi    the timer, high byte
;   $8C ColorTimer     frames left before the next colour
;   $8D ColorIndex     0..7 into TitleColors
;   $8E ScrollTimer    the four-frame scroll divider
;   $8F Phase          Scroll & 7
;   $90 ByteIndex      Scroll >> 3, 0..10
;   $91 TextPtrLo      the pre-shifted row pointer
;   $92 TextPtrHi
;   $93-$9F free (13 bytes)
;   $A0-$A5 ScoreDigits  the score library's six digits (unused)
;   $A6 ScoreRow       the score library's/text macro's row counter
;   $A7 ScoreTmp       the score library's/text macro's scratch
;   $A8-$D7 ScoreBuf   the score library's 48-byte column-major buffer
;   $D8-$F7 free (32 bytes)
;   $F8-$FF stack
;
; Build: acme -f plain -o build/demo-63.bin \
;        lessons/part8-advanced/63-modern-homebrew/demo-63.asm
; Run:   stella build/demo-63.bin     (click the screen to unmute the tune)
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

SCREEN_LINES   = 192     ; the visible picture
TOP_BORDER     = 8       ; rows 0-7 are the top band
BOTTOM_BORDER  = 184     ; rows 184-191 are the bottom band

LOGO_TOP       = 48      ; the RTB logo's first row
LOGO_ROWS      = 7       ; seven chunk rows
LOGO_LINES     = LOGO_ROWS * 8   ; eight scanlines per chunk row = 56
LOGO_END       = LOGO_TOP + LOGO_LINES

MSG_LEN        = 16      ; "MODERN HOMEBREW "
MSG_WINDOW     = 6       ; six 8-pixel columns
SCROLL_MAX     = MSG_LEN * 8 - MSG_WINDOW * 8   ; 80
SCROLL_PERIOD  = 4       ; one pixel every four frames

TEXT_ROWS      = 8       ; eight glyph rows

CRED1_TOP      = 32      ; the four credit blocks' setup rows
CRED2_TOP      = 72
CRED3_TOP      = 112
CRED4_TOP      = 152

TUNE_LEN       = 32      ; 32 notes, then the tune wraps
TUNE_AUDC      = $0C     ; the div-6 pure tone from Lesson 35
TUNE_AUDV      = $0A     ; audible, not loud

SCENE_TITLE    = 0
SCENE_CREDITS  = 1

AUTO_FRAMES    = 300     ; title -> credits after 300 frames (5 s)
AUTO_LO        = AUTO_FRAMES & $FF
AUTO_HI        = AUTO_FRAMES >> 8

C_TITLE_BG     = $02     ; the title's deep-space background
C_CRED_BG      = $84     ; the credits' blue field
C_CRED_PF      = $1A     ; the credits' gold stars and bands
C_WHITE        = $0E     ; the text and the title's first colour


; The logo rows, top to bottom, with no border bits.  Chunks 3-16 hold
; "RTB": R at 3-6, T at 8-11, B at 13-16.  Each row is one playfield
; byte per register.  The !fill block below repeats each row eight times.
LOGO_R0_PF0 = $80
LOGO_R0_PF1 = $EF
LOGO_R0_PF2 = $0E
LOGO_R1_PF0 = $80
LOGO_R1_PF1 = $26
LOGO_R1_PF2 = $12
LOGO_R2_PF0 = $80
LOGO_R2_PF1 = $26
LOGO_R2_PF2 = $12
LOGO_R3_PF0 = $80
LOGO_R3_PF1 = $C6
LOGO_R3_PF2 = $0E
LOGO_R4_PF0 = $80
LOGO_R4_PF1 = $46
LOGO_R4_PF2 = $12
LOGO_R5_PF0 = $80
LOGO_R5_PF1 = $26
LOGO_R5_PF2 = $12
LOGO_R6_PF0 = $80
LOGO_R6_PF1 = $26
LOGO_R6_PF2 = $0E

; The frame arithmetic is a build-time assertion, not a comment.
!if LOGO_END > BOTTOM_BORDER {
    !error "the logo must end before the bottom border"
}
!if CRED4_TOP + 8 > BOTTOM_BORDER {
    !error "the last credit block must end before the bottom border"
}
!if SCROLL_MAX != 80 {
    !error "the message must scroll to offset 80"
}
!if MSG_LEN != 16 {
    !error "the pre-shifted table is generated for exactly 16 characters"
}

; =============================================================================
; RAM ALLOCATION ($80-$92; +clean_start zeroes every byte)
; =============================================================================
Scene         = $80   ; 0 = title, 1 = credits
Frame         = $81   ; the free-running frame counter (a byte)
Scroll        = $82   ; the marquee offset, 0..80
TunePtr       = $83   ; the note index, 0..31
TuneTimer     = $84   ; frames left on the current note
PrevFire      = $85   ; fire state last frame
PrevSelect    = $86   ; SELECT state last frame
Startup       = $87   ; frames left before fire is trusted
NewFire       = $88   ; this frame's fire 0 -> 1 edge
Scratch       = $89   ; SELECT's pressed level
AutoTimerLo   = $8A   ; the 300-frame auto-demo timer, low byte
AutoTimerHi   = $8B   ; the timer, high byte
ColorTimer    = $8C   ; frames left before the next colour
ColorIndex    = $8D   ; 0..7 into TitleColors
ScrollTimer   = $8E   ; the four-frame scroll divider
Phase         = $8F   ; Scroll & 7
ByteIndex     = $90   ; Scroll >> 3, 0..10
TextPtrLo     = $91   ; the pre-shifted row pointer
TextPtrHi     = $92
;
; $93-$9F are free.  The score library owns $A0-$D7 (ScoreDigits,
; ScoreRow, ScoreTmp and the 48-byte ScoreBuf).  $D8-$F7 are free.
; The stack lives at $F8-$FF; the demo nests two levels (ScoreSetup calls
; ScoreSetupP0/P1).  The exercise's score calls add two more, which fills the
; 8-byte reservation; plan the stack before adding them.

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreSetup positions P0/P1 at X=56/64, enables three-copy close mode and
; VDEL, and strobes the frame's only HMOVE.  ScoreDraw draws the six-column
; marquee.  The library owns $A0-$D7.  It is sourced after the ROM origin
; because it contains code; the reset vector still points at this Reset.
    * = $F000

    !source "include/score.asm"

; =============================================================================
; THE TEXT-LINE MACRO — the Lesson 55 six-column sequence, reused
; =============================================================================
; A = the base of a 48-byte column-major block (six columns x eight rows,
; bottom-up).  The eight iterations draw eight visible lines.  The closing
; WSYNC makes the caller's next code start on a fresh line, so the star loop
; that follows draws exactly 31 lines before the next text block.  The NOP
; and CPX are the timing the score kernel uses; do not "clean them up".
!macro text_line .base {
    LDA #TEXT_ROWS - 1
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
    STA WSYNC               ; align the next star loop to a fresh line
}

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the fire button)

    ; Scene 0, the first frame, the first note, the auto-demo armed.
    LDA #SCENE_TITLE
    STA Scene
    LDA #$00
    STA Frame
    STA Scroll
    STA ScrollTimer
    STA TunePtr
    STA PrevFire
    STA PrevSelect
    STA NewFire
    STA ColorIndex
    LDA #1
    STA TuneTimer           ; the first TuneStep loads note 0
    LDA #8
    STA Startup             ; ignore the fire line while the console settles
    STA ColorTimer
    LDA #AUTO_LO
    STA AutoTimerLo
    LDA #AUTO_HI
    STA AutoTimerHi

    ; The fixed TIA state.  The scene setup changes the colours each frame.
    LDA #C_TITLE_BG
    STA COLUBK
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    STA COLUPF
    LDA #$00
    STA CTRLPF              ; repeat playfield; the ball is unused
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    STA ENABL
    STA ENAM0
    STA ENAM1
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

; -----------------------------------------------------------------------------
; 1. THE TUNE — one note at a time on channel 0
; -----------------------------------------------------------------------------
; TuneTimer counts down every frame.  At zero the current index writes the
; note, the timer reloads from TuneDur, and the index advances (31 -> 0).
; The checkpoint reports the index of the note that starts on this frame.
    JSR TuneStep

; -----------------------------------------------------------------------------
; 2. FIRE — the 0 -> 1 edge moves to the credits
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1; the
; EOR/AND pair keeps only a new press, so holding the button acts once.
; Startup is eight frames.  While it counts down NewFire is forced clear and
; PrevFire is held at 0, so a button held from power-on still produces one
; edge when the console has settled (this is what -holdjoy0 F relies on).
    LDA INPT4
    AND #$80
    EOR #$80                ; 1 = pressed
    STA NewFire
    EOR PrevFire
    AND NewFire
    STA NewFire             ; NewFire = pressed & ~wasPressed
    LDA Startup
    BEQ FireEdgeReady
    DEC Startup
    LDA #$00
    STA NewFire
    STA PrevFire
    JMP FirePrevDone        ; do not overwrite PrevFire while settling
FireEdgeReady:
    LDA NewFire
    BEQ NoFireEdge
    LDA #SCENE_CREDITS
    STA Scene
    LDA #0
    STA AutoTimerLo         ; a manual change disarms the auto-demo
    STA AutoTimerHi
    STA TunePtr             ; and restarts the tune
    LDA #1
    STA TuneTimer
NoFireEdge:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire
FirePrevDone:

; -----------------------------------------------------------------------------
; 3. SELECT — the 0 -> 1 edge returns to the title and rearms the auto-demo
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  SELECT also rewinds the marquee so
; the title always starts at "MODERN".  There is no SELECT debounce: a held
; switch acts once because PrevSelect remembers the level.
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelectEdge
    LDA #SCENE_TITLE
    STA Scene
    LDA #AUTO_LO
    STA AutoTimerLo
    LDA #AUTO_HI
    STA AutoTimerHi
    LDA #0
    STA Scroll
    STA ScrollTimer
    STA TunePtr
    LDA #1
    STA TuneTimer
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 4. THE AUTO-DEMO — title -> credits after 300 frames
; -----------------------------------------------------------------------------
; The timer runs only on the title.  Fire clears it and SELECT reloads it, so
; a manual scene is never overruled a frame later.  The credits screen stays
; until SELECT: the captures can wait for it without racing a return trip.
    LDA Scene
    BNE NoAutoDemo
    LDA AutoTimerLo
    SEC
    SBC #1
    STA AutoTimerLo
    BCS AutoNoBorrow
    DEC AutoTimerHi
AutoNoBorrow:
    LDA AutoTimerLo
    ORA AutoTimerHi
    BNE NoAutoDemo
    LDA #SCENE_CREDITS
    STA Scene
    LDA #0
    STA TunePtr
    LDA #1
    STA TuneTimer
NoAutoDemo:

; -----------------------------------------------------------------------------
; 5. THE MARQUEE CLOCK — one pixel every four frames
; -----------------------------------------------------------------------------
; The scroll runs in both scenes; only the title draws it.  The wrap at 80
; returns to the first six-character window ("MODERN").
    INC ScrollTimer
    LDA ScrollTimer
    AND #(SCROLL_PERIOD - 1)
    BNE NoScrollStep
    INC Scroll
    LDA Scroll
    CMP #(SCROLL_MAX + 1)
    BCC ScrollStore
    LDA #$00
ScrollStore:
    STA Scroll
NoScrollStep:
    LDA Scroll
ScrollRead:                 ; checkpoint: A = the marquee offset, 0..80
    NOP

; -----------------------------------------------------------------------------
; 6. THE COLOUR CLOCK — one palette entry every eight frames
; -----------------------------------------------------------------------------
; Only the title uses ColorIndex; the credits scene writes a fixed gold.
    DEC ColorTimer
    BNE NoColorStep
    LDA #8
    STA ColorTimer
    INC ColorIndex
    LDA ColorIndex
    AND #$07
    STA ColorIndex
NoColorStep:

; -----------------------------------------------------------------------------
; 7. THE FRAME COUNTER
; -----------------------------------------------------------------------------
    INC Frame
    LDA Frame
FrameRead:                  ; checkpoint: A = the free-running frame count
    NOP

; -----------------------------------------------------------------------------
; 8. SCENE SETUP — colours, the marquee fill, the one HMOVE
; -----------------------------------------------------------------------------
; ScoreSetup runs in both scenes: the title's ScoreDraw and the credits'
; text macro both need the three-copy window and VDEL.  It strobes the
; frame's only HMOVE, which applies HMP0 and HMP1 in one HBLANK.
    LDA Scene
    BEQ SetupTitle
SetupCredits:
    LDA #C_CRED_BG
    STA COLUBK
    LDA #C_CRED_PF
    STA COLUPF
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    JMP DisplayCommon

SetupTitle:
    LDA #C_TITLE_BG
    STA COLUBK
    LDX ColorIndex
    LDA TitleColors,X
    STA COLUPF
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    JSR FillMarquee

DisplayCommon:
    LDA #$00
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    JSR ScoreSetup
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; THE VISIBLE PICTURE — the scene dispatch
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    LDA Scene
SceneRead:                  ; checkpoint: A = 0 (title) or 1 (credits)
    BEQ TitleKernel
    JMP CreditsKernel

; =============================================================================
; SCENE 0 — THE TITLE
; =============================================================================
TitleKernel:
    ; --- rows 0-7: the top border band ------------------------------------
    LDY #0
    LDA #$FF
TitleTopBorder:
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    INY
    CPY #TOP_BORDER
    BNE TitleTopBorder

    ; --- rows 8-16: the marquee -------------------------------------------
    ; ScoreDraw's line 0 is a setup line; the glyphs show on lines 9-16.
    JSR ScoreDraw

    ; --- rows 17-47: the starfield above the logo ------------------------
    LDY #17
TitleStarsTop:
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #LOGO_TOP
    BNE TitleStarsTop

    ; --- rows 48-103: the logo, stars OR'd into the gaps ------------------
    ; LogoZonePF* - LOGO_TOP,Y turns the global row into the expanded
    ; table's 0..55 index without a second counter in RAM.
    LDY #LOGO_TOP
TitleLogo:
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    ORA LogoZonePF0-LOGO_TOP,Y
    STA PF0
    LDA StarPF1,X
    ORA LogoZonePF1-LOGO_TOP,Y
    STA PF1
    LDA StarPF2,X
    ORA LogoZonePF2-LOGO_TOP,Y
    STA PF2
    STA WSYNC
    INY
    CPY #LOGO_END
    BNE TitleLogo

    ; --- rows 104-183: the starfield below the logo ----------------------
    LDY #LOGO_END
TitleStarsBottom:
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #BOTTOM_BORDER
    BNE TitleStarsBottom

    ; --- rows 184-191: the bottom border band ----------------------------
    LDA #$FF
    LDY #BOTTOM_BORDER
TitleBottomBorder:
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE TitleBottomBorder

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
; The two kernels each fall through to an identical block, so both paths
; reach the first overscan instruction at the same cycle.  The credits path
; has its own label for the state log; the instructions are the same.
OverscanStart:              ; checkpoint: scanline 229 on the title path
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SCENE 1 — THE CREDITS
; =============================================================================
CreditsKernel:
    ; --- rows 0-7: the top border band ------------------------------------
    LDY #0
    LDA #$FF
CreditsTopBorder:
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    INY
    CPY #TOP_BORDER
    BNE CreditsTopBorder

    ; --- rows 8-31: stars above the first credit line ---------------------
    LDY #TOP_BORDER
CreditsStars1:
    LDA #$00
    STA GRP0                ; the players are blank on every star line
    STA GRP1
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #CRED1_TOP
    BNE CreditsStars1

    +text_line CreditsLine1

    ; --- rows 40-71: stars between the first two credit lines ------------
    LDY #(CRED1_TOP + TEXT_ROWS + 1)
CreditsStars2:
    LDA #$00
    STA GRP0
    STA GRP1
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #CRED2_TOP
    BNE CreditsStars2

    +text_line CreditsLine2

    ; --- rows 80-111: stars between the second and third lines -----------
    LDY #(CRED2_TOP + TEXT_ROWS + 1)
CreditsStars3:
    LDA #$00
    STA GRP0
    STA GRP1
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #CRED3_TOP
    BNE CreditsStars3

    +text_line CreditsLine3

    ; --- rows 120-151: stars between the third and fourth lines ----------
    LDY #(CRED3_TOP + TEXT_ROWS + 1)
CreditsStars4:
    LDA #$00
    STA GRP0
    STA GRP1
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #CRED4_TOP
    BNE CreditsStars4

    +text_line CreditsLine4

    ; --- rows 160-183: stars below the last credit line ------------------
    LDY #(CRED4_TOP + TEXT_ROWS + 1)
CreditsStars5:
    LDA #$00
    STA GRP0
    STA GRP1
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    STA PF0
    LDA StarPF1,X
    STA PF1
    LDA StarPF2,X
    STA PF2
    STA WSYNC
    INY
    CPY #BOTTOM_BORDER
    BNE CreditsStars5

    ; --- rows 184-191: the bottom border band ----------------------------
    LDA #$FF
    LDY #BOTTOM_BORDER
CreditsBottomBorder:
    STA PF0
    STA PF1
    STA PF2
    STA WSYNC
    INY
    CPY #SCREEN_LINES
    BNE CreditsBottomBorder

CreditsOverscan:            ; checkpoint: scanline 229 on the credits path
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; FillMarquee — copy six columns from the pre-shifted phase block
; =============================================================================
; Phase = Scroll & 7 selects one of eight 128-byte blocks.  ByteIndex =
; Scroll >> 3 selects the first of the six 8-pixel columns.  The source row
; is 16 bytes; a six-byte read therefore never crosses a page.  The
; destination is ScoreBuf, column-major and bottom-up, as ScoreDraw expects.
FillMarquee:
    LDA Scroll
    AND #$07
    STA Phase
    LDA Scroll
    LSR
    LSR
    LSR
    STA ByteIndex

    LDX Phase
    LDA PhasePtrLo,X
    CLC
    ADC ByteIndex
    STA TextPtrLo
    LDA PhasePtrHi,X
    ADC #$00
    STA TextPtrHi

    LDX #0                  ; the glyph row, 0 (bottom) to 7 (top)
FillRow:
    LDY #0
    LDA (TextPtrLo),Y
    STA ScoreBuf+0,X
    INY
    LDA (TextPtrLo),Y
    STA ScoreBuf+8,X
    INY
    LDA (TextPtrLo),Y
    STA ScoreBuf+16,X
    INY
    LDA (TextPtrLo),Y
    STA ScoreBuf+24,X
    INY
    LDA (TextPtrLo),Y
    STA ScoreBuf+32,X
    INY
    LDA (TextPtrLo),Y
    STA ScoreBuf+40,X
    LDA TextPtrLo
    CLC
    ADC #16                 ; the next row is 16 bytes on
    STA TextPtrLo
    BCC FillNoCarry
    INC TextPtrHi
FillNoCarry:
    INX
    CPX #TEXT_ROWS
    BNE FillRow
    RTS

; =============================================================================
; TuneStep — advance the 32-note tune on channel 0
; =============================================================================
; A note's duration is in frames.  The timer is preloaded with 1 at reset and
; on every scene change, so the first frame plays note 0.  The checkpoint
; reports the index of the note that starts on this frame, not the next one.
TuneStep:
    DEC TuneTimer
    BNE TuneDone
    LDX TunePtr
    TXA
TunePtrRead:                ; checkpoint: A = the note index, 0..31
    NOP
    LDX TunePtr
    LDA TuneFreq,X
    STA AUDF0
    LDA #TUNE_AUDC
    STA AUDC0
    LDA #TUNE_AUDV
    STA AUDV0
    LDA TuneDur,X
    STA TuneTimer
    INX
    CPX #TUNE_LEN
    BCC TuneStore
    LDX #0
TuneStore:
    STX TunePtr
TuneDone:
    RTS

; =============================================================================
; THE TABLES
; =============================================================================

; --- the colour cycle: eight bright NTSC hues -------------------------------
; The title's border bands, logo and stars all share COLUPF, so they change
; together.  The credits scene uses a fixed gold instead.
TitleColors:
    !byte $0E, $1A, $2A, $3A, $4A, $5A, $8A, $AA

; --- the tune: 32 notes, 8 groups of 4 --------------------------------------
; AUDF is the TIA divider (higher = lower pitch).  The note names in the
; lesson are the nearest equal-tempered pitch, not a claim about exact tuning.
; Group 1 is C4-E4-G4-C5; group 2 D4-F4-A4-D5; group 3 E4-G4-B♭4-E5; group 4
; is the cadence C5-G4-E4-C4.
TuneFreq:
    !byte 19,15,12,9,   12,15,19,19
    !byte 17,14,11,8,   11,14,17,17
    !byte 15,12,10,7,   10,12,15,15
    !byte 9,12,15,19,   15,12,19,19
TuneDur:
    !byte 6,6,6,12,     6,6,6,12
    !byte 6,6,6,12,     6,6,6,12
    !byte 6,6,6,12,     6,6,6,12
    !byte 6,6,6,12,     6,6,6,12

; --- the eight phase-block pointers ----------------------------------------
; Each phase block is 8 rows x 16 bytes = 128 bytes.  The table is 16-aligned
; and the rows are 16 bytes, so the fill's six-byte read stays in one page.
PhasePtrLo:
    !byte <(ShiftedTable + 0*128), <(ShiftedTable + 1*128)
    !byte <(ShiftedTable + 2*128), <(ShiftedTable + 3*128)
    !byte <(ShiftedTable + 4*128), <(ShiftedTable + 5*128)
    !byte <(ShiftedTable + 6*128), <(ShiftedTable + 7*128)
PhasePtrHi:
    !byte >(ShiftedTable + 0*128), >(ShiftedTable + 1*128)
    !byte >(ShiftedTable + 2*128), >(ShiftedTable + 3*128)
    !byte >(ShiftedTable + 4*128), >(ShiftedTable + 5*128)
    !byte >(ShiftedTable + 6*128), >(ShiftedTable + 7*128)

; =============================================================================
; THE LOGO ZONE — each compact row repeated eight times
; =============================================================================
; The compact LOGO_Rn_* constants above are the single source of truth.
; !fill repeats each row across its eight scanlines, so the title kernel can
; index the expanded plane with the global row (0..55) and OR it with stars.
!align 15, 0
LogoZonePF0:
    !fill 8, LOGO_R0_PF0
    !fill 8, LOGO_R1_PF0
    !fill 8, LOGO_R2_PF0
    !fill 8, LOGO_R3_PF0
    !fill 8, LOGO_R4_PF0
    !fill 8, LOGO_R5_PF0
    !fill 8, LOGO_R6_PF0
LogoZonePF1:
    !fill 8, LOGO_R0_PF1
    !fill 8, LOGO_R1_PF1
    !fill 8, LOGO_R2_PF1
    !fill 8, LOGO_R3_PF1
    !fill 8, LOGO_R4_PF1
    !fill 8, LOGO_R5_PF1
    !fill 8, LOGO_R6_PF1
LogoZonePF2:
    !fill 8, LOGO_R0_PF2
    !fill 8, LOGO_R1_PF2
    !fill 8, LOGO_R2_PF2
    !fill 8, LOGO_R3_PF2
    !fill 8, LOGO_R4_PF2
    !fill 8, LOGO_R5_PF2
    !fill 8, LOGO_R6_PF2

; =============================================================================
; THE STARFIELD — three page-aligned 64-byte planes
; =============================================================================
; Row r is StarPF0+r, StarPF1+r, StarPF2+r.  The kernel uses Y & $3F, so the
; 64-row pattern repeats three times down the 192-line picture.  The bits
; follow the TIA layout: PF0 bits 4-7 are chunks 0-3, PF1 bits 7-0 are
; chunks 4-11, PF2 bits 0-7 are chunks 12-19.  The border handles the far
; edges; the stars keep to chunks 1-18.
    !align 255, 0
StarPF0:
    !byte $00,$20,$00,$00,$00,$00,$80,$00   ; rows 0-7
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 8-15
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 16-23
    !byte $20,$00,$00,$00,$00,$00,$00,$00   ; rows 24-31
    !byte $00,$00,$20,$00,$00,$00,$00,$00   ; rows 32-39
    !byte $80,$00,$40,$00,$00,$00,$00,$00   ; rows 40-47
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 48-55
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 56-63

    !align 255, 0
StarPF1:
    !byte $02,$00,$40,$02,$00,$10,$00,$04   ; rows 0-7
    !byte $00,$00,$00,$00,$00,$00,$01,$01   ; rows 8-15
    !byte $00,$00,$00,$01,$00,$08,$00,$00   ; rows 16-23
    !byte $00,$00,$01,$00,$00,$00,$00,$00   ; rows 24-31
    !byte $00,$80,$00,$40,$00,$80,$00,$00   ; rows 32-39
    !byte $00,$00,$00,$80,$00,$10,$00,$00   ; rows 40-47
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 48-55
    !byte $00,$00,$00,$00,$00,$04,$02,$00   ; rows 56-63

    !align 255, 0
StarPF2:
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 0-7
    !byte $00,$00,$00,$00,$00,$00,$00,$00   ; rows 8-15
    !byte $01,$10,$40,$00,$00,$00,$00,$00   ; rows 16-23
    !byte $00,$04,$00,$08,$08,$24,$20,$40   ; rows 24-31
    !byte $10,$00,$02,$00,$00,$00,$00,$00   ; rows 32-39
    !byte $00,$20,$40,$01,$10,$00,$00,$00   ; rows 40-47
    !byte $10,$20,$00,$00,$01,$00,$10,$10   ; rows 48-55
    !byte $04,$20,$02,$02,$08,$00,$00,$00   ; rows 56-63

; =============================================================================
; THE CREDIT BLOCKS — four 48-byte column-major, bottom-up blocks
; =============================================================================
; Each block is six columns x eight rows.  The text_line macro reads column
; c's eight bytes at base+c*8, with Y = 7 (top) down to 0 (bottom).
CreditsLine1:
    ; column 0: 'R'
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0
    ; column 1: 'A'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70
    ; column 2: 'C'
    !byte $00,$70,$88,$80,$80,$80,$88,$70
    ; column 3: 'I'
    !byte $00,$F8,$20,$20,$20,$20,$20,$F8
    ; column 4: 'N'
    !byte $00,$88,$88,$88,$98,$A8,$C8,$88
    ; column 5: 'G'
    !byte $00,$70,$88,$88,$B8,$80,$88,$70

CreditsLine2:
    ; column 0: 'space'
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    ; column 1: 'T'
    !byte $00,$20,$20,$20,$20,$20,$20,$F8
    ; column 2: 'H'
    !byte $00,$88,$88,$88,$F8,$88,$88,$88
    ; column 3: 'E'
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8
    ; column 4: 'space'
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    ; column 5: 'space'
    !byte $00,$00,$00,$00,$00,$00,$00,$00

CreditsLine3:
    ; column 0: 'space'
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    ; column 1: 'B'
    !byte $00,$F0,$88,$88,$F0,$88,$88,$F0
    ; column 2: 'E'
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8
    ; column 3: 'A'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70
    ; column 4: 'M'
    !byte $00,$88,$88,$88,$A8,$A8,$D8,$88
    ; column 5: 'space'
    !byte $00,$00,$00,$00,$00,$00,$00,$00

CreditsLine4:
    ; column 0: 'T'
    !byte $00,$20,$20,$20,$20,$20,$20,$F8
    ; column 1: 'H'
    !byte $00,$88,$88,$88,$F8,$88,$88,$88
    ; column 2: 'A'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70
    ; column 3: 'N'
    !byte $00,$88,$88,$88,$98,$A8,$C8,$88
    ; column 4: 'K'
    !byte $00,$88,$90,$A0,$C0,$A0,$90,$88
    ; column 5: 'S'
    !byte $00,$F0,$08,$08,$70,$80,$80,$78

; =============================================================================
; THE FONT ATLAS — the 5x7 glyphs the tables were generated from
; =============================================================================
; These bytes are the glyph source, not a runtime table: the pre-shifted
; marquee and the four credit blocks above are generated from them.  Byte 0
; is the bottom row; bit 7 is the leftmost pixel.  Every glyph's byte 0 is
; $00, so the lit part is seven scanlines tall.
FontAtlas:
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    ; 'space'
    !byte $00,$88,$88,$88,$F8,$88,$88,$70
    ; 'A'
    !byte $00,$F0,$88,$88,$F0,$88,$88,$F0
    ; 'B'
    !byte $00,$70,$88,$80,$80,$80,$88,$70
    ; 'C'
    !byte $00,$F0,$88,$88,$88,$88,$88,$F0
    ; 'D'
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8
    ; 'E'
    !byte $00,$70,$88,$88,$B8,$80,$88,$70
    ; 'G'
    !byte $00,$88,$88,$88,$F8,$88,$88,$88
    ; 'H'
    !byte $00,$F8,$20,$20,$20,$20,$20,$F8
    ; 'I'
    !byte $00,$88,$90,$A0,$C0,$A0,$90,$88
    ; 'K'
    !byte $00,$88,$88,$88,$A8,$A8,$D8,$88
    ; 'M'
    !byte $00,$88,$88,$88,$98,$A8,$C8,$88
    ; 'N'
    !byte $00,$70,$88,$88,$88,$88,$88,$70
    ; 'O'
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0
    ; 'R'
    !byte $00,$F0,$08,$08,$70,$80,$80,$78
    ; 'S'
    !byte $00,$20,$20,$20,$20,$20,$20,$F8
    ; 'T'
    !byte $00,$88,$D8,$A8,$A8,$88,$88,$88
    ; 'W'

; =============================================================================
; THE PRE-SHIFTED MARQUEE — 8 phases x 8 rows x 16 bytes = 1,024 bytes
; =============================================================================
; For phase p, row r and character i, the output byte is
;     (glyph[i][r] << p) | (glyph[i+1][r] >> (8-p))     for p > 0
;     glyph[i][r]                                       for p = 0
; where glyph[16] is a zero pad.  A row is 16 bytes (the 16-character
; message), so a six-byte window starting at byteIndex (0..10) never crosses
; a page.  Phase p starts at ShiftedTable + 128*p; row r starts at +16*r.
    !align 15, 0
ShiftedTable:
    ; ---- phase 0: the window shifted left 0 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 0, font row 1 (0 = bottom, 7 = top)
    !byte $88,$70,$F0,$F8,$88,$88,$00,$88,$70,$88,$F8,$F0,$88,$F8,$88,$00
    ; phase 0, font row 2 (0 = bottom, 7 = top)
    !byte $88,$88,$88,$80,$90,$88,$00,$88,$88,$88,$80,$88,$90,$80,$D8,$00
    ; phase 0, font row 3 (0 = bottom, 7 = top)
    !byte $88,$88,$88,$80,$A0,$88,$00,$88,$88,$88,$80,$88,$A0,$80,$A8,$00
    ; phase 0, font row 4 (0 = bottom, 7 = top)
    !byte $A8,$88,$88,$F0,$F0,$98,$00,$F8,$88,$A8,$F0,$F0,$F0,$F0,$A8,$00
    ; phase 0, font row 5 (0 = bottom, 7 = top)
    !byte $A8,$88,$88,$80,$88,$A8,$00,$88,$88,$A8,$80,$88,$88,$80,$88,$00
    ; phase 0, font row 6 (0 = bottom, 7 = top)
    !byte $D8,$88,$88,$80,$88,$C8,$00,$88,$88,$D8,$80,$88,$88,$80,$88,$00
    ; phase 0, font row 7 (0 = bottom, 7 = top)
    !byte $88,$70,$F0,$F8,$F0,$88,$00,$88,$70,$88,$F8,$F0,$F0,$F8,$88,$00
    ; ---- phase 1: the window shifted left 1 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 1, font row 1 (0 = bottom, 7 = top)
    !byte $10,$E1,$E1,$F1,$11,$10,$01,$10,$E1,$11,$F1,$E1,$11,$F1,$10,$00
    ; phase 1, font row 2 (0 = bottom, 7 = top)
    !byte $11,$11,$11,$01,$21,$10,$01,$11,$11,$11,$01,$11,$21,$01,$B0,$00
    ; phase 1, font row 3 (0 = bottom, 7 = top)
    !byte $11,$11,$11,$01,$41,$10,$01,$11,$11,$11,$01,$11,$41,$01,$50,$00
    ; phase 1, font row 4 (0 = bottom, 7 = top)
    !byte $51,$11,$11,$E1,$E1,$30,$01,$F1,$11,$51,$E1,$E1,$E1,$E1,$50,$00
    ; phase 1, font row 5 (0 = bottom, 7 = top)
    !byte $51,$11,$11,$01,$11,$50,$01,$11,$11,$51,$01,$11,$11,$01,$10,$00
    ; phase 1, font row 6 (0 = bottom, 7 = top)
    !byte $B1,$11,$11,$01,$11,$90,$01,$11,$11,$B1,$01,$11,$11,$01,$10,$00
    ; phase 1, font row 7 (0 = bottom, 7 = top)
    !byte $10,$E1,$E1,$F1,$E1,$10,$01,$10,$E1,$11,$F1,$E1,$E1,$F1,$10,$00
    ; ---- phase 2: the window shifted left 2 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 2, font row 1 (0 = bottom, 7 = top)
    !byte $21,$C3,$C3,$E2,$22,$20,$02,$21,$C2,$23,$E3,$C2,$23,$E2,$20,$00
    ; phase 2, font row 2 (0 = bottom, 7 = top)
    !byte $22,$22,$22,$02,$42,$20,$02,$22,$22,$22,$02,$22,$42,$03,$60,$00
    ; phase 2, font row 3 (0 = bottom, 7 = top)
    !byte $22,$22,$22,$02,$82,$20,$02,$22,$22,$22,$02,$22,$82,$02,$A0,$00
    ; phase 2, font row 4 (0 = bottom, 7 = top)
    !byte $A2,$22,$23,$C3,$C2,$60,$03,$E2,$22,$A3,$C3,$C3,$C3,$C2,$A0,$00
    ; phase 2, font row 5 (0 = bottom, 7 = top)
    !byte $A2,$22,$22,$02,$22,$A0,$02,$22,$22,$A2,$02,$22,$22,$02,$20,$00
    ; phase 2, font row 6 (0 = bottom, 7 = top)
    !byte $62,$22,$22,$02,$23,$20,$02,$22,$23,$62,$02,$22,$22,$02,$20,$00
    ; phase 2, font row 7 (0 = bottom, 7 = top)
    !byte $21,$C3,$C3,$E3,$C2,$20,$02,$21,$C2,$23,$E3,$C3,$C3,$E2,$20,$00
    ; ---- phase 3: the window shifted left 3 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 3, font row 1 (0 = bottom, 7 = top)
    !byte $43,$87,$87,$C4,$44,$40,$04,$43,$84,$47,$C7,$84,$47,$C4,$40,$00
    ; phase 3, font row 2 (0 = bottom, 7 = top)
    !byte $44,$44,$44,$04,$84,$40,$04,$44,$44,$44,$04,$44,$84,$06,$C0,$00
    ; phase 3, font row 3 (0 = bottom, 7 = top)
    !byte $44,$44,$44,$05,$04,$40,$04,$44,$44,$44,$04,$45,$04,$05,$40,$00
    ; phase 3, font row 4 (0 = bottom, 7 = top)
    !byte $44,$44,$47,$87,$84,$C0,$07,$C4,$45,$47,$87,$87,$87,$85,$40,$00
    ; phase 3, font row 5 (0 = bottom, 7 = top)
    !byte $44,$44,$44,$04,$45,$40,$04,$44,$45,$44,$04,$44,$44,$04,$40,$00
    ; phase 3, font row 6 (0 = bottom, 7 = top)
    !byte $C4,$44,$44,$04,$46,$40,$04,$44,$46,$C4,$04,$44,$44,$04,$40,$00
    ; phase 3, font row 7 (0 = bottom, 7 = top)
    !byte $43,$87,$87,$C7,$84,$40,$04,$43,$84,$47,$C7,$87,$87,$C4,$40,$00
    ; ---- phase 4: the window shifted left 4 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 4, font row 1 (0 = bottom, 7 = top)
    !byte $87,$0F,$0F,$88,$88,$80,$08,$87,$08,$8F,$8F,$08,$8F,$88,$80,$00
    ; phase 4, font row 2 (0 = bottom, 7 = top)
    !byte $88,$88,$88,$09,$08,$80,$08,$88,$88,$88,$08,$89,$08,$0D,$80,$00
    ; phase 4, font row 3 (0 = bottom, 7 = top)
    !byte $88,$88,$88,$0A,$08,$80,$08,$88,$88,$88,$08,$8A,$08,$0A,$80,$00
    ; phase 4, font row 4 (0 = bottom, 7 = top)
    !byte $88,$88,$8F,$0F,$09,$80,$0F,$88,$8A,$8F,$0F,$0F,$0F,$0A,$80,$00
    ; phase 4, font row 5 (0 = bottom, 7 = top)
    !byte $88,$88,$88,$08,$8A,$80,$08,$88,$8A,$88,$08,$88,$88,$08,$80,$00
    ; phase 4, font row 6 (0 = bottom, 7 = top)
    !byte $88,$88,$88,$08,$8C,$80,$08,$88,$8D,$88,$08,$88,$88,$08,$80,$00
    ; phase 4, font row 7 (0 = bottom, 7 = top)
    !byte $87,$0F,$0F,$8F,$08,$80,$08,$87,$08,$8F,$8F,$0F,$0F,$88,$80,$00
    ; ---- phase 5: the window shifted left 5 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 5, font row 1 (0 = bottom, 7 = top)
    !byte $0E,$1E,$1F,$11,$11,$00,$11,$0E,$11,$1F,$1E,$11,$1F,$11,$00,$00
    ; phase 5, font row 2 (0 = bottom, 7 = top)
    !byte $11,$11,$10,$12,$11,$00,$11,$11,$11,$10,$11,$12,$10,$1B,$00,$00
    ; phase 5, font row 3 (0 = bottom, 7 = top)
    !byte $11,$11,$10,$14,$11,$00,$11,$11,$11,$10,$11,$14,$10,$15,$00,$00
    ; phase 5, font row 4 (0 = bottom, 7 = top)
    !byte $11,$11,$1E,$1E,$13,$00,$1F,$11,$15,$1E,$1E,$1E,$1E,$15,$00,$00
    ; phase 5, font row 5 (0 = bottom, 7 = top)
    !byte $11,$11,$10,$11,$15,$00,$11,$11,$15,$10,$11,$11,$10,$11,$00,$00
    ; phase 5, font row 6 (0 = bottom, 7 = top)
    !byte $11,$11,$10,$11,$19,$00,$11,$11,$1B,$10,$11,$11,$10,$11,$00,$00
    ; phase 5, font row 7 (0 = bottom, 7 = top)
    !byte $0E,$1E,$1F,$1E,$11,$00,$11,$0E,$11,$1F,$1E,$1E,$1F,$11,$00,$00
    ; ---- phase 6: the window shifted left 6 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 6, font row 1 (0 = bottom, 7 = top)
    !byte $1C,$3C,$3E,$22,$22,$00,$22,$1C,$22,$3E,$3C,$22,$3E,$22,$00,$00
    ; phase 6, font row 2 (0 = bottom, 7 = top)
    !byte $22,$22,$20,$24,$22,$00,$22,$22,$22,$20,$22,$24,$20,$36,$00,$00
    ; phase 6, font row 3 (0 = bottom, 7 = top)
    !byte $22,$22,$20,$28,$22,$00,$22,$22,$22,$20,$22,$28,$20,$2A,$00,$00
    ; phase 6, font row 4 (0 = bottom, 7 = top)
    !byte $22,$22,$3C,$3C,$26,$00,$3E,$22,$2A,$3C,$3C,$3C,$3C,$2A,$00,$00
    ; phase 6, font row 5 (0 = bottom, 7 = top)
    !byte $22,$22,$20,$22,$2A,$00,$22,$22,$2A,$20,$22,$22,$20,$22,$00,$00
    ; phase 6, font row 6 (0 = bottom, 7 = top)
    !byte $22,$22,$20,$22,$32,$00,$22,$22,$36,$20,$22,$22,$20,$22,$00,$00
    ; phase 6, font row 7 (0 = bottom, 7 = top)
    !byte $1C,$3C,$3E,$3C,$22,$00,$22,$1C,$22,$3E,$3C,$3C,$3E,$22,$00,$00
    ; ---- phase 7: the window shifted left 7 pixel(s) ----
    ; font row 0 (blank for every glyph)
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; phase 7, font row 1 (0 = bottom, 7 = top)
    !byte $38,$78,$7C,$44,$44,$00,$44,$38,$44,$7C,$78,$44,$7C,$44,$00,$00
    ; phase 7, font row 2 (0 = bottom, 7 = top)
    !byte $44,$44,$40,$48,$44,$00,$44,$44,$44,$40,$44,$48,$40,$6C,$00,$00
    ; phase 7, font row 3 (0 = bottom, 7 = top)
    !byte $44,$44,$40,$50,$44,$00,$44,$44,$44,$40,$44,$50,$40,$54,$00,$00
    ; phase 7, font row 4 (0 = bottom, 7 = top)
    !byte $44,$44,$78,$78,$4C,$00,$7C,$44,$54,$78,$78,$78,$78,$54,$00,$00
    ; phase 7, font row 5 (0 = bottom, 7 = top)
    !byte $44,$44,$40,$44,$54,$00,$44,$44,$54,$40,$44,$44,$40,$44,$00,$00
    ; phase 7, font row 6 (0 = bottom, 7 = top)
    !byte $44,$44,$40,$44,$64,$00,$44,$44,$6C,$40,$44,$44,$40,$44,$00,$00
    ; phase 7, font row 7 (0 = bottom, 7 = top)
    !byte $38,$78,$7C,$78,$44,$00,$44,$38,$44,$7C,$78,$78,$7C,$44,$00,$00

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
> `lessons/part8-advanced/63-modern-homebrew/demo-63.asm`.

### Code Walkthrough

#### Step 1 — Reset and the initial state

`Reset` at `$F145` runs `+clean_start`, sets `SWACNT` to zero, and writes the scene state: `Scene=0`, `Frame=0`, `Scroll=0`, `ScrollTimer=0`, `TunePtr=0`, the edge latches clear, `ColorIndex=0`, `TuneTimer=1` (so the first `TuneStep` loads note 0), `Startup=8`, `ColorTimer=8`, and the 300-frame auto timer (`$012C` = low `$2C`, high `$01`). It then sets the fixed TIA state: the title background, white player and playfield colours, repeat playfield, and blank graphics. `ScoreSetup` is not called here; the first frame's VBLANK calls it after the scene setup.

#### Step 2 — The frame skeleton

The four labels are the timing anchors:

```asm
StartFrame:                 ; scanline 259, the first VSYNC line
    +vsync

VblankStart:                ; scanline 0, the first VBLANK line
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
```

`VBLANK_TIMER` is 44 ticks (37 lines); `OVERSCAN_TIMER` is 36 ticks (30 lines). The picture is 192 lines. The measured state log gives `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, and `OverscanStart` 229/6 on both the title and the credits paths. The `OverscanStart` label is the first overscan instruction; the credits path has an identical block at `CreditsOverscan`.

#### Step 3 — TuneStep and the note table

`TuneStep` is a frame-driven state machine. `TuneTimer` is preloaded with 1 at reset and on every scene change, so the first frame plays note 0. At zero the engine loads the current index, writes the note, reloads the duration, and advances the index with a wrap at 32:

```asm
TuneStep:
    DEC TuneTimer
    BNE TuneDone
    LDX TunePtr
    TXA
TunePtrRead:                ; checkpoint: A = the note index, 0..31
    NOP
    LDX TunePtr
    LDA TuneFreq,X
    STA AUDF0
    LDA #TUNE_AUDC
    STA AUDC0
    LDA #TUNE_AUDV
    STA AUDV0
    LDA TuneDur,X
    STA TuneTimer
    INX
    CPX #TUNE_LEN
    BCC TuneStore
    LDX #0
TuneStore:
    STX TunePtr
TuneDone:
    RTS
```

The two tables are 32 bytes each. The first group is the C-major arpeggio C4–E4–G4–C5 (`19, 15, 12, 9`), the second D-minor (`17, 14, 11, 8`), the third E diminished (`15, 12, 10, 7`), and the fourth a cadence back to C (`9, 12, 15, 19, 15, 12, 19, 19`). The durations are 6 frames per note with a 12-frame last note in each group, so the phrase is 240 frames — four seconds — and then loops. The note names are the nearest equal-tempered pitch; the TIA's divider is not a piano, and the lesson does not pretend it is.

#### Step 4 — Fire, SELECT, and the auto-demo

Fire is an edge, not a level. `INPT4` bit 7 is 0 while the button is held; `EOR #$80` turns that into 1, and the `EOR PrevFire` / `AND NewFire` pair keeps only a new press. The eight-frame `Startup` window forces `NewFire` clear and **holds `PrevFire` at 0**, so a button held from power-on still produces one edge when the console has settled. That is what makes `-holdjoy0 F` work in Stella: a fire button held at power-on still produces exactly one scene change. The committed `credits.png` uses the auto-demo; the fire path is the alternative.

SELECT is the mirror image: `SWCHB` bit 1 is 0 while SELECT is held, the edge returns `Scene=0`, rearms the 300-frame timer, rewinds `Scroll` to 0, and restarts the tune. The auto-demo runs only on the title. When its 16-bit timer reaches zero, it sets `Scene=1`; the credits screen then stays until SELECT, so a capture can wait for it without racing a return trip.

#### Step 5 — The scroll clock and FillMarquee

`Scroll` advances one pixel every four frames. `ScrollTimer` is the divider; the wrap at 80 returns to the first six-character window:

```asm
    INC ScrollTimer
    LDA ScrollTimer
    AND #(SCROLL_PERIOD - 1)
    BNE NoScrollStep
    INC Scroll
    LDA Scroll
    CMP #(SCROLL_MAX + 1)
    BCC ScrollStore
    LDA #$00
ScrollStore:
    STA Scroll
NoScrollStep:
    LDA Scroll
ScrollRead:                 ; checkpoint: A = the marquee offset, 0..80
    NOP
```

`FillMarquee` turns the offset into a phase and a byte index, then copies six columns from the pre-shifted table into the score library's buffer. The source row is 16 bytes; the six-byte read starts at byte 0..10, so it stays inside the row and never crosses a page. The destination is column-major and bottom-up, exactly what `ScoreDraw` expects.

#### Step 6 — The colour cycle and the scene setup

`ColorTimer` counts eight frames; at zero, `ColorIndex` advances through eight entries of `TitleColors`, and the title setup writes the new `COLUPF`. The title's bars, logo, and stars all use that register, so they change colour together. The credits setup writes the fixed blue background and gold playfield. Both scenes then clear the player graphics, call `ScoreSetup`, and wait out the VBLANK timer:

```asm
DisplayCommon:
    LDA #$00
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    JSR ScoreSetup
    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on
```

`ScoreSetup` is the score library's routine: three-copy close mode, VDEL on, P0 at X=56, P1 at X=64, and **one** `HMOVE` in a HBLANK. The title's `ScoreDraw` and the credits' text macro both rely on it. The HMOVE is the frame's only one.

#### Step 7 — The title kernel

The title kernel is a sequence of line loops. The top border is eight lines of `$FF`; `ScoreDraw` then draws the marquee, and because it does not touch the playfield, the border colour stays behind the text for a 17-line bar. The star loops read `StarPF0/1/2` at `Y & $3F`; the logo loop ORs the expanded `LogoZonePF*` rows into the star bytes; the bottom border is eight more lines of `$FF`.

```asm
TitleLogo:
    TYA
    AND #$3F
    TAX
    LDA StarPF0,X
    ORA LogoZonePF0-LOGO_TOP,Y
    STA PF0
    LDA StarPF1,X
    ORA LogoZonePF1-LOGO_TOP,Y
    STA PF1
    LDA StarPF2,X
    ORA LogoZonePF2-LOGO_TOP,Y
    STA PF2
    STA WSYNC
    INY
    CPY #LOGO_END
    BNE TitleLogo
```

The measured cycle ledger is in the source header: a star line is 37 cycles, the logo line is 49 (50 on a page-cross row), and a border line is 21 on the first line and 19 on the rest. Every one is inside the 76-cycle line, and the frame stays 262.

#### Step 8 — The credits kernel and the text-line macro

The credits kernel alternates star loops with four `+text_line` blocks. The macro is the Lesson 55 six-column VDEL sequence, reused with a 48-byte block as its base. It ends with an aligning `STA WSYNC`, so the star loop that follows starts on a fresh line and draws exactly 31 lines before the next text block. Each block is 40 lines: 9 for the text (one setup line plus eight glyph rows) and 31 for the stars.

```asm
    +text_line CreditsLine1

    ; --- rows 41-71: stars between the first two credit lines ------------
    LDY #(CRED1_TOP + TEXT_ROWS + 1)
CreditsStars2:
    LDA #$00
    STA GRP0
    STA GRP1
    ...
```

The star loops clear `GRP0`/`GRP1` on every line, so the last glyph row does not streak down the screen. The playfield and the players are independent: the boundary lines carry both the last text row and the first star row, which is why the layout counts them once but draws them twice.

#### Step 9 — The tables

The logo is seven rows of three bytes, stored as named constants (`LOGO_R0_PF0` … `LOGO_R6_PF2`). The `!fill 8` block expands each row to eight scanlines, so the kernel can index the expanded plane with the global row. `StarPF0/1/2` are 64-byte page-aligned planes; the `Y & $3F` index repeats the pattern three times down the screen. The four `CreditsLine` blocks are 48 bytes each, column-major and bottom-up. The `FontAtlas` is the 5×7 source; the `ShiftedTable` is the eight-phase pre-shifted marquee, generated from the font with the formula in its header comment. The table is 1,024 bytes and 16-aligned; each row is 16 bytes, which is what keeps the six-byte read page-safe.

#### Step 10 — The vectors and the 4,096-byte budget

The last six bytes are the three vectors, all pointing at `Reset`. The ROM is exactly 4,096 bytes. The tables end well before the vectors: the shifted table starts at `$FA90` and is 1,024 bytes, so the last byte is `$FE8F`; the vectors begin at `$FFFA`. The free space is the lesson's headroom for the exercises. The build command and `npm run roms` both produce the same image, and `bash scripts/verify.sh` checks it against the committed `.bin`.

## What You Should See

The title is a dark field with a wide colour bar across the top and a narrower bar across the bottom. The bar, the large **RTB** logo, and the stars all share one colour, and the colour advances through eight bright hues every eight frames. The top bar is 17 lines tall: the eight-line border plus the marquee band, because the playfield bytes stay latched behind the text. The marquee is white and six characters wide; it scrolls one pixel every four frames, so the visible window changes from **MODERN** through **HOMEBR** and back. The logo appears twice, once in each 80-pixel playfield half, separated by a six-chunk gap. The starfield is sparse and repeats every 64 lines. The tune plays on channel 0; Stella is unmuted, and the in-page Javatari player starts muted, so click it to hear the melody.

![Stella running the Lesson 63 ROM: a dark title screen with an orange 17-line top bar, the white marquee reading HOMEBR, two large orange RTB logos over an orange starfield, and an orange 8-line bottom bar; the title bar reads Stella 7.0: "demo-63"](/images/lesson63/title.png)

*`title.png`: the title at the burst-selected capture. The colour cycle is on an orange phase, the marquee window is **HOMEBR**, and the two RTB copies are 14 chunks wide each. The 17-line top bar is the border colour persisting through the score band.*

The credits are a blue field with gold stars, a gold 8-line bar at the top and the bottom, and four white text lines: **RACING**, **THE**, **BEAM**, **THANKS**. The first star line after a text or border band can carry a one-line fragment of the previous playfield value; the playfield bytes are latched through the text, so a few gold chunks repeat behind a word. The letters remain readable, and the effect is a documented artifact of the same latching that makes the 17-line top bar. The text is centred in the same 48-pixel six-column window as the marquee, at logical rows 33–40, 73–80, 113–120, and 153–160. The text macro writes only the players, so the playfield's last star row stays latched behind each eight-line block. The credits screen does not scroll and does not change colour; it is the quiet counterpoint to the title.

![Stella running the Lesson 63 ROM at the credits screen: a blue field with a gold 8-line bar at the top and bottom, gold stars, and four white lines reading RACING, THE, BEAM, THANKS; the title bar reads Stella 7.0: "demo-63"](/images/lesson63/credits.png)

*`credits.png`: the credits after the 300-frame auto-demo. The background is blue, the stars and bars are gold, and the four credit lines are white. The screen stays until SELECT.*

<RomPlayer rom="/roms/part8-advanced/63-modern-homebrew/demo-63.bin" title="Lesson 63 — Modern Homebrew" />

The demo is interactive. Fire moves to the credits; SELECT returns to the title, rewinds the marquee, and restarts the tune. The auto-demo moves title → credits after 300 frames (5 seconds at 60 Hz) and leaves the credits up, so the credits capture is input-free. The title capture is a burst-selected frame from the SELECT-return path: SELECT rewinds the marquee but not the colour clock, so the orange/HOMEBR pair is reachable. The state log covers the fire edge (A=1 at frame 9) and the auto-demo (A=0 until frame 299, A=1 from frame 300); the SELECT return is code-reviewed, not state-logged in this capture run. The in-page player starts muted; click the player once to unmute the tune. The ROM is 4,096 bytes and uses the 4K mapper; Stella reports `4K* (4K)`.

The debugger tells the same story as numbers. Break at the labels the source defines:

| Checkpoint | Address | Measured | Meaning |
|---|---|---|---|
| `StartFrame` | `$F1A3` | 259/3 | the first VSYNC line (the first hit at frame 0 is the power-on partial frame) |
| `VblankStart` | `$F1B1` | 0/5 | the first VBLANK line |
| `BodyStart` | `$F2B1` | 37/5 | the scene dispatch |
| `OverscanStart` | `$F33A` | 229/6 | the title path's first overscan instruction |
| `CreditsOverscan` | `$F4F1` | 229/6 | the credits path's first overscan instruction |
| `SceneRead` | `$F2B3` | 37/8, A=0/1 | the current scene |
| `ScrollRead` | `$F258` | A=0..80 | the marquee offset |
| `TunePtrRead` | `$F55B` | A=0..31 | the note index |
| `FrameRead` | `$F26D` | A=0..255 | the free-running frame counter |

The state log commands used for the evidence. The `ScrollRead`/`FrameRead` cycle columns vary because those labels are reached at different points in the VBLANK path; the A value is the checkpoint, and the scanline/cycle pair is not meant to be constant:

```bash
ROM=docs/public/roms/part8-advanced/63-modern-homebrew/demo-63.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1A3' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F1B1' $ROM   # VblankStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F2B1' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F33A' $ROM   # OverscanStart
stella -holdjoy0 F -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F4F1' $ROM   # CreditsOverscan
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F2B3' $ROM   # SceneRead
stella -holdjoy0 F -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F2B3' $ROM   # SceneRead, credits
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F258' $ROM   # ScrollRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F55B' $ROM   # TunePtrRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F26D' $ROM   # FrameRead
```

The frame checkpoints, first hits:

```text
# StartFrame
BP:           0  34 49  79 | nV-BdIZc 00 ff 00 ff |    (power-on)
BP:           1 259 03 -59 | nv-BdIZC 00 37 c0 ff |
BP:           2 259 03 -59 | nv-BdIZC 00 37 c0 ff |
BP:           3 259 03 -59 | nv-BdIZC 00 37 c0 ff |

# VblankStart
BP:           1   0 05 -53 | nv-BdIZc 00 ff 00 ff |
BP:           2   0 05 -53 | nv-BdIZC 00 37 c0 ff |
BP:           3   0 05 -53 | nv-BdIZC 00 37 c0 ff |

# BodyStart
BP:           1  37 05 -53 | nv-BdIZC 00 08 05 ff |
BP:           2  37 05 -53 | nv-BdIZC 00 08 05 ff |
BP:           3  37 05 -53 | nv-BdIZC 00 08 05 ff |

# OverscanStart (title)
BP:           1 229 06 -50 | nv-BdIZC ff 37 c0 ff |
BP:           2 229 06 -50 | nv-BdIZC ff 37 c0 ff |
BP:           3 229 06 -50 | nv-BdIZC ff 37 c0 ff |

# CreditsOverscan (with -holdjoy0 F)
BP:           9 229 06 -50 | nv-BdIZC ff 37 c0 ff |
BP:          10 229 06 -50 | nv-BdIZC ff 37 c0 ff |
BP:          11 229 06 -50 | nv-BdIZC ff 37 c0 ff |
```

The scene and the clocks:

```text
# SceneRead (no input, the title)
BP:           1  37 08 -44 | nv-BdIZC 00 08 05 ff |
BP:           2  37 08 -44 | nv-BdIZC 00 08 05 ff |

# SceneRead (no input, the auto-demo): A=0 until frame 299, A=1 from frame 300
BP:         299  37 08 -44 | nv-BdIZC 00 37 c0 ff |
BP:         300  37 08 -44 | nv-BdIzC 01 37 c0 ff |

# SceneRead (with -holdjoy0 F, the fire edge): A=1 at frame 9
BP:           9  37 08 -44 | nv-BdIzC 01 37 c0 ff |
BP:          10  37 08 -44 | nv-BdIzC 01 01 c0 ff |

# ScrollRead (A advances every four frames)
BP:           1   2 36  40 | nv-BdIZC 00 01 00 ff |
BP:           2   1 69 139 | nv-BdIZC 00 37 c0 ff |
BP:           3   1 69 139 | nv-BdIZC 00 37 c0 ff |
BP:           4   2 08 -44 | nv-BdIzc 01 37 c0 ff |
BP:           5   1 69 139 | nv-BdIZC 01 37 c0 ff |
BP:           6   1 69 139 | nv-BdIZC 01 37 c0 ff |
BP:           7   2 36  40 | nv-BdIzc 01 02 c0 ff |
BP:           8   2 08 -44 | nv-BdIzc 02 37 c0 ff |

# TunePtrRead (A = 0, 1, 2, 3, ... on the note boundaries)
BP:           1   0 34  34 | nV-BdIZc 00 00 00 fd |
BP:           7   0 34  34 | nv-BdIZC 01 01 c0 fd |
BP:          13   0 34  34 | nv-BdIZC 02 02 c0 fd |
BP:          19   0 34  34 | nv-BdIZC 03 03 c0 fd |
BP:          31   0 34  34 | nv-BdIZC 04 04 c0 fd |

# FrameRead (A increments every frame)
BP:           1   2 54  94 | nv-BdIZC 01 01 00 ff |
BP:           2   2 11 -35 | nv-BdIZC 02 37 c0 ff |
BP:           3   2 11 -35 | nv-BdIZC 03 37 c0 ff |
BP:           4   2 26  10 | nv-BdIzc 04 37 c0 ff |
```

`Scroll` advances every four frames: the A column repeats each value four times before the next. `TunePtr` advances on the note boundaries; the first three notes last six frames each, and the fourth note lasts twelve, which is why the A=4 hit is at frame 31 rather than frame 25. `Frame` is a free-running byte and wraps 255 → 0; it is the frame count, not the auto-demo timer.

The pixel check is a host-side sample of the committed images, not a second emulator. The window is 1010×807; the TIA area is 960×606 at `(25, 106)`. The measurements:

| Measurement | `title.png` | `credits.png` |
|---|---|---|
| background | `(63, 63, 62)` | `(36, 40, 176)` |
| accent / bars / stars | `(224, 141, 77)` orange | `(205, 205, 52)` gold |
| text | `(234, 234, 233)` white | `(234, 234, 233)` white |
| top bar | rows 0–16 (y = 107–158), 17 lines | rows 0–7 (y = 107–130), 8 lines |
| bottom bar | rows 184–191 (y = 688–711), 8 lines | rows 184–191 (y = 688–711), 8 lines |
| logo | x = 97–432 and 577–912, y = 258–433 → chunks 3–16, rows 48–103 | — |
| marquee | x = 367–636, y = 135–155 → rows 9–15, six cells | — |
| credit text | — | x = 361–630; y = 211–231, 337–357, 464–484, 590–610 → rows 33–39, 73–79, 113–119, 153–159 |

The title's top bar is nine lines taller (17 in total) than the source's 8-line border because the playfield bytes are not rewritten during `ScoreDraw`; the border colour therefore fills the marquee band too. The bottom bar is the plain 8-line border. The credits bars are the plain 8-line borders on both ends. The logo's two copies are 14 chunks wide each, separated by six chunks (the left half's chunks 17–19 plus the right half's chunks 0–2), which is the 24-pixel gap visible in the capture.

> **Capture method.** The two images are window captures of
> `docs/public/roms/part8-advanced/63-modern-homebrew/demo-63.bin` in Stella 7.0,
> using `scripts/capture-screenshot.sh`. `title.png` is one frame from a burst
> of the committed ROM: the title scrolls and cycles colour, so the frame was
> selected for the HOMEBR/orange state after a SELECT return (SELECT rewinds
> the marquee but not the colour clock). A burst of the committed ROM
> reproduces that state, so the image is a real frame of this ROM. `credits.png` waited
> 7 seconds, after the 300-frame auto-demo had advanced to the credits; the
> credits screen stays up until SELECT, so the wait is deterministic. The pointer was parked at `(0, 0)` before each capture (no
> cursor appears in either image), and the title bar reads `Stella 7.0: "demo-63"`
> in both. The TIA area is 960×606 at `(25, 106)`; the pixel samples above are
> taken from that area. The two images differ in background, bar colour, and
> content, as the table shows.

The tune is real. `TuneStep` writes the note at every boundary:

```asm
    LDA TuneFreq,X
    STA AUDF0
    LDA #TUNE_AUDC          ; $0C, the div-6 pure tone
    STA AUDC0
    LDA #TUNE_AUDV          ; $0A, audible but not loud
    STA AUDV0
```

The note table is two 32-byte arrays. The first group is C4–E4–G4–C5, the second D4–F4–A4–D5, the third E4–G4–B♭4–E5, and the fourth the cadence C5–G4–E4–C4; the durations are six frames per note, with a twelve-frame last note in each group. The `TunePtrRead` log shows the index; the table below is the static ledger, and the source's `TuneFreq`/`TuneDur` are the bytes the engine reads.

| Group | `TuneFreq` (AUDF) | `TuneDur` (frames) | Nearest notes |
|---|---|---|---|
| 1 | `19, 15, 12, 9, 12, 15, 19, 19` | `6, 6, 6, 12, 6, 6, 6, 12` | C4 E4 G4 C5 G4 E4 C4 C4 |
| 2 | `17, 14, 11, 8, 11, 14, 17, 17` | `6, 6, 6, 12, 6, 6, 6, 12` | D4 F4 A4 D5 A4 F4 D4 D4 |
| 3 | `15, 12, 10, 7, 10, 12, 15, 15` | `6, 6, 6, 12, 6, 6, 6, 12` | E4 G4 B♭4 E5 B♭4 G4 E4 E4 |
| 4 | `9, 12, 15, 19, 15, 12, 19, 19` | `6, 6, 6, 12, 6, 6, 6, 12` | C5 G4 E4 C4 E4 G4 C4 C4 |

The note names are the nearest equal-tempered pitch; the TIA divides a fixed clock, so the intervals are not a piano's. Stella must be unmuted to hear the tune, and the in-page player starts muted.

## Exercises

This is a production lesson: the demo ROM is the artifact, and the three exercises are answered here. Each answer names the hooks in the source and the changes needed. The exercises are deliberately about production decisions, not new kernel tricks.

### Exercise 1: Change the logo and the message

**Challenge:** Replace the **RTB** logo with a different word (for example **ATARI** or **2600**) and change the marquee from **MODERN HOMEBREW** to a message of your choice. Keep the frame at 262 lines and the ROM at 4,096 bytes.

**Hints:**
1. The logo is seven rows of three playfield bytes. The bytes are named `LOGO_R0_PF0` … `LOGO_R6_PF2`; the `!fill 8` block expands each row to eight scanlines. The letters live in chunks 3–16: R at 3–6, T at 8–11, B at 13–16.
2. A playfield chunk is 4 pixels wide. A 4-chunk letter is 16 pixels wide; a 7-row letter is 56 scanlines tall. Use the TIA bit order: `PF0` bits 4–7 are chunks 0–3, `PF1` bits 7–0 are chunks 4–11, and `PF2` bits 0–7 are chunks 12–19.
3. The marquee is the 16-character string `MODERN HOMEBREW ` in `ShiftedTable`. The table is eight phases × eight rows × 16 bytes, generated from `FontAtlas` by the formula in the source header. If the new message is still 16 characters, regenerate the table and leave `MSG_LEN` and `SCROLL_MAX` alone. If it is longer or shorter, update `MSG_LEN`, `SCROLL_MAX`, and the 16-byte row stride in `FillMarquee` together.

**Expected Result:** The new logo reads clearly in the title capture, the new marquee scrolls through the six-character window, and the frame remains 262 lines. The ROM still assembles to 4,096 bytes.

**Answer:** Edit the seven `LOGO_Rn_*` triples. The `!fill 8` block needs no change. For the message, write the eight-phase `ShiftedTable` from the formula in the source header (the lesson ships no generator), regenerate the 1,024-byte table, and keep it 16-aligned. `SCROLL_MAX` is `MSG_LEN * 8 - 48`; `FillMarquee`'s `ADC #16` is the row stride and must match the generator's row length. The `PhasePtrLo/Hi` tables assume eight 128-byte blocks; a 16-character message keeps that layout. The frame and the RAM map do not change.

### Exercise 2: Add a second attract screen

**Challenge:** Add a third scene — an instructions screen or a high-score screen — and make the attract mode cycle through title → credits → the new scene → title. Keep the frame at 262 lines and the ROM at 4,096 bytes.

**Hints:**
1. `Scene` is a byte at `$80`. The VBLANK setup branches on it with `BEQ SetupTitle`; the visible dispatch branches with `BEQ TitleKernel` / `JMP CreditsKernel`. Add a third value and a third branch.
2. The credits kernel is the template: a top border, star loops, and four `+text_line` blocks. The text blocks are 48-byte column-major tables; the `text_line` macro consumes nine lines including the aligning `WSYNC`.
3. The auto-demo timer is a 16-bit count at `$8A/$8B`; fire sets it to zero, SELECT reloads 300. For a three-scene loop, give each scene its own timer or advance `Scene` in the auto-demo handler with a wrap at 3.

**Expected Result:** A third screen appears in the auto-demo and via the scene edges; its background and text are distinct; the frame is still 262 lines; the ROM is still 4,096 bytes.

**Answer:** Add `SCENE_SCORES = 2` and a `ScoresKernel` that reuses the credits structure with a new `ScoresLine1..4` table and a different background/`COLUPF`. In the VBLANK setup, replace the two-way branch with a compare chain: `CMP #SCENE_CREDITS; BEQ SetupCredits; CMP #SCENE_SCORES; BEQ SetupScores; JMP SetupTitle`. In the visible dispatch, do the same. Change the auto-demo to advance `Scene` with a wrap at 3, and make fire/SELECT choose the scene explicitly. The `SceneRead` checkpoint reports the new value. The tables can reuse the `FontAtlas` glyphs and the `text_line` macro; the kernel's line budget is the same 192 lines. If the new text is not exactly 6 characters per line, pad it with spaces or add a sixth column.

### Exercise 3: Add a high-score table and a reset

**Challenge:** Add a persistent high-score display and a reset. The high score should survive the attract loop and reset only on the explicit input (or on power-off). Show at least three scores or one six-digit score; keep the frame at 262 lines and the ROM at 4,096 bytes.

**Hints:**
1. The score library already owns `$A0–$D7`: `ScoreDigits`, `ScoreRow`, `ScoreTmp`, and the 48-byte `ScoreBuf`. `ScoreSetup`, `ScoreDraw`, `ScoreInit`, `ScoreClear`, `ScoreSetDigit`, and `ScoreAddOne` are in `include/score.asm`; the demo calls `ScoreSetup` and `ScoreDraw` but never the digit routines (`ScoreInit`, `ScoreClear`, `ScoreSetDigit`, `ScoreAddOne`).
2. `ScoreDraw` consumes nine visible lines (one setup plus eight glyph rows) and expects `ScoreBuf` to be filled. The credits kernel's `text_line` macro uses the same VDEL sequence; a high-score screen can call `ScoreDraw` at the top and use the rest of the screen for a label or stars.
3. The score digits are binary, not BCD. `ScoreAddOne` increments the six-digit decimal number and rebuilds the affected column. To reset, call `ScoreInit` (zero digits and buffer) or `ScoreClear` (six zeros).

**Expected Result:** The high score is visible on the new screen, survives the title/credits loop, and resets on the chosen input; the frame is still 262 lines; the ROM is still 4,096 bytes.

**Answer:** Add a `SCENE_SCORES = 2` branch as in Exercise 2 and a `HighScore` table in RAM (for example `$93–$98`, six digits) or reuse `ScoreDigits`. On entry to the scores scene, call `ScoreInit` once, then `ScoreSetDigit` for each digit or `ScoreAddOne` to advance a demo score. At the top of the scores kernel, call `ScoreDraw`; `ScoreSetup` is already called once per frame in the common VBLANK — do not call it again, because a second call would strobe a second HMOVE and insert two WSYNC lines inside the visible area. The rest of the 192 lines can draw the starfield and the label. For the reset, add a SELECT edge on the scores scene that calls `ScoreInit`/`ScoreClear` and returns to `Scene=0`; the existing SELECT edge already returns to the title, so branch on `Scene` to choose reset vs. return. The score buffer survives the other scenes because it is ordinary RIOT RAM; only `+clean_start` at power-on clears it. The nine-line `ScoreDraw` band and the remaining starfield keep the frame at 262.

## Key Takeaways

- ✅ A homebrew release is a pipeline: design, code, assemble, test, flash, share, publish, and support; the `.bin` is the artifact that moves between the stages.
- ✅ A flash cart (Harmony, UnoCart) is a reusable cartridge that runs a ROM on real hardware; it is a development and play tool, not a production cart.
- ✅ The community is small and general: AtariAge is the long-running forum, contests and awards are community-run, and publishing is a trade-off among free ROMs, paid ROMs, physical carts, and licensing. Do not invent years, winners, or sales numbers.
- ✅ The modern toolchain is a set of trade-offs: ACME and Stella give full control; batari Basic and 8bitworkshop get to a prototype faster; the ROM is the same kind of file in every case.
- ✅ A tech demo proves a technique; a shippable game adds a goal, controls, a difficulty curve, a title and attract mode, sound, testing on hardware, and a distribution plan.
- ✅ An attract mode is production value: a logo, a colour cycle, a scrolling message, a tune, a credits screen, and an auto-demo that shows the game before the first input.
- ✅ The 4K budget is a design constraint: the logo is seven compact rows expanded with `!fill`, the starfield is a 64-row repeat, the marquee is pre-shifted into eight phase blocks, and the tune is two 32-byte tables.

## What's Next

The next lesson turns the `.bin` into a physical object: [Lesson 64: Building Your Own Cartridge — From ROM to Physical Cart](/part8-advanced/64-building-cartridges) covers the PCB, the ROM chip, the programmer, the shell, the label, and a burn-in test ROM that checks the console's RAM, controller, and checksum.
