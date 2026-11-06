---
title: "Lesson 55: Scrolling Text Marquee — The Activision Logo Effect"
description: "Turn the 48-pixel score kernel into a six-character text window: a 39-glyph 5x7 font, eight pre-shifted phases, a 48-store column-major fill, a 183-line starfield with a one-pixel shooting star, and a scroll that moves one pixel every two frames."
prev:
  text: "Lesson 54: Visual Effects Cookbook — Starfields, Rainbows, Pseudo-3D"
  link: "/part7-kernel-mastery/54-visual-effects-cookbook"
next:
  text: "Lesson 56: Bankswitching — Beyond 4KB"
  link: "/part8-advanced/56-bankswitching"
---

# Lesson 55: Scrolling Text Marquee — The Activision Logo Effect

> **Part 7: Kernel Mastery** · Estimated time: 120 minutes
> **Prerequisites:** Lesson 11 (lookup tables), Lesson 12 (the NTSC frame), Lesson 14 (`WSYNC`), Lesson 17 (cycle counting), Lesson 18 (mid-scanline changes), Lesson 25 (players), Lesson 26 (positioning), Lesson 28 (one `HMOVE`), Lesson 29 (the ball), Lesson 31 (`NUSIZ`), Lesson 32 (`VDEL`), Lesson 39 (the 48-pixel kernel and `include/score.asm`), Lesson 48 (the kernel taxonomy)
> **You will learn:** how the Lesson 39 score kernel becomes a six-character text display; how a 5x7 glyph atlas is stored bottom-up in an 8x8 cell; why a one-pixel scroll needs eight pre-shifted copies of the message; how 48 bytes are filled into the score buffer at `ScoreBuf + c*8 + r`; how the 183-line starfield and its one-pixel shooting star share the frame; and how the scroll, fire pause, and SELECT reset are wired.
> **You will build:** "the marquee" — a 4,096-byte ROM with a six-character text window at the top, a 39-glyph font, an eight-phase pre-shifted table (1,152 bytes), a 48-store column-major fill, a scroll that moves one pixel every two frames over 0-88, a 183-line starfield, and a one-pixel gold shooting star at TIA X=80; plus three exercise solutions: a new 14-character message, a one-pixel-per-frame scroll, and a second nine-line text band.

## Introduction

Lesson 39 built the 48-pixel score with two players in three-copy close mode. The same kernel can draw any six 8-pixel cells, not just digits. This lesson replaces the ten digit glyphs with a 39-glyph alphabet, fills the six cells from a message, and slides the message through the window one pixel at a time. The result is a text marquee: the first six characters of "RACING THE BEAM  " at offset 0, "G THE " at offset 40, and the same message again after offset 88.

The text is only half of the picture. The other 183 visible lines are a starfield drawn from three page-aligned 183-byte playfield planes. A one-pixel ball at TIA X=80 falls one line per frame: the shooting star. The text zone is nine lines and the starfield is 183, so the frame is still the standard 192 visible lines.

The scrolling is the lesson's central trick. The score kernel cannot shift a byte sideways; a per-byte variable shift would cost more cycles than the 37-line VBLANK has to spare. Instead, the program stores eight pre-shifted copies of the message, one for each horizontal phase, and selects one with `ScrollOffset & 7`. The byte index selects the first of the six columns inside the 18-byte row. The fill copies 8 rows x 6 columns = 48 bytes into the score buffer, and `ScoreDraw` does the rest.

::: details TypeScript Equivalent

A glyph atlas and a bitstream window are the two data structures behind the marquee. In TypeScript the idea is a font object and a function that returns the six visible cells:

```typescript
const FONT: Record<string, number[]> = {
  R: [0x00, 0x88, 0x90, 0xa0, 0xf0, 0x88, 0x88, 0xf0],
  // ... 38 more glyphs, each eight bytes, bottom-up
};

const MESSAGE = "RACING THE BEAM  ";
const ROW_BYTES = MESSAGE.length + 1;

function glyphByte(ch: string, row: number): number {
  return FONT[ch][row];
}

/** One byte of the pre-shifted table: phase p, row r, byte i. */
function shifted(phase: number, row: number, i: number): number {
  const a = glyphByte(MESSAGE[i] ?? " ", row);
  const b = glyphByte(MESSAGE[i + 1] ?? " ", row);
  return phase === 0 ? a : ((a << phase) | (b >> (8 - phase))) & 0xff;
}

/** The 48-byte score buffer for a scroll offset. */
function fillScoreBuf(offset: number): number[] {
  const phase = offset & 7;
  const first = offset >> 3;
  const buf = new Array(48).fill(0);
  for (let c = 0; c < 6; c++)
    for (let r = 0; r < 8; r++)
      buf[c * 8 + r] = shifted(phase, r, first + c);
  return buf;
}
```

The analogy breaks in four places, and each is a 2600 constraint. There is no framebuffer: `fillScoreBuf` returns 48 bytes that `ScoreDraw` reads while the beam moves, and a byte written after its cell has passed changes nothing this frame. The six cells are not an array of characters; they are the interleaved copies of two players in `NUSIZ=3` mode, positioned at TIA X=56 and 64. The table is not computed at runtime: the eight phases are 1,152 ROM bytes, because a shift in the kernel would cost more than the 76-cycle line. And the scroll is not free: `ScrollOffset` advances one pixel every two frames, and `ScoreBuf` is refilled 48 bytes at a time in every VBLANK.

:::

## Theory

### Section 1: The 48-Pixel Window Is a Text Display

The score kernel from Lesson 39 draws six 8-pixel cells with two players. `NUSIZ0=NUSIZ1=3` gives each player three close copies. P0 is at TIA X=56 and its copies are at 56, 72 and 88; P1 is at 64 and its copies are at 64, 80 and 96. The six cells interleave:

| Cell | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| Player | P0 | P1 | P0 | P1 | P0 | P1 |
| TIA X | 56 | 64 | 72 | 80 | 88 | 96 |

The cell block is 48 pixels wide, TIA X=56-103. The six cells start at capture x = 361, 409, 457, 505, 553 and 601; the block spans x=361-648, and its last pixel column is 643-648. A solid six-cell test measures exactly that block.

`ScoreDraw` consumes nine visible lines. Line 0 is the setup/blank line; the eight glyph rows are drawn on lines 1-8, and the cleanup (`GRP0=0`, `GRP1=0`, VDEL off) shares line 8. The caller's next code starts on visible line 9, which is scanline 46 in the standard frame. That is why the text zone is exactly nine lines.

The score buffer is **column-major**: `ScoreBuf + c*8 + r` is column `c`, row `r`. The kernel reads one column at a time with `LDA ScoreBuf+8*c,Y`, so the buffer layout matches the kernel's six stores. The text fill in this lesson writes that layout directly; the source table is row-major, and the fill does the transpose.

The font is 5x7 inside an 8x8 cell. Each glyph is eight bytes, bottom-up: byte 0 is the bottom row and byte 7 is the top row. Bit 7 is the leftmost pixel. Every glyph's byte 0 is `$00`, so the lit block is seven scanlines tall: visible lines 1-7, capture y=109-130. The five lit columns use bits 7-3; the right three bits of each cell are blank.

### Section 2: The Glyph Atlas

The font has 39 glyphs: A-Z, 0-9, space, dash, and period. Each is eight bytes. The bytes are the glyph's rows from bottom to top; a 5-bit row pattern is shifted left three times so bit 7 is the leftmost pixel. For example, the letter R is:

```asm
    ; R
    !byte $00, $88, $90, $A0, $F0, $88, $88, $F0
```

Read from byte 7 down to byte 1, R is `####.`, `#...#`, `#...#`, `####.`, `#.#..`, `#..#.`, `#...#`: a top bar, two stems, a crossbar, and a diagonal leg. Byte 0 is blank, so the bottom row of the cell is empty. The other glyphs follow the same convention; the full table is in the source under `Font:`.

The message for this lesson is **"RACING THE BEAM  "**, 17 characters. The two trailing spaces are deliberate: they let the last letters leave the window without a sudden blank, and they make the wrap arithmetic `17*8 - 48 = 88`. The first six characters at offset 0 are "RACING"; at offset 40 the window starts at character 5, so it reads "G THE ".

The font is the **atlas**, not the runtime data. The runtime reads the pre-shifted table in Section 3. The font is kept in the ROM so every shifted byte can be checked against a visible 5x7 shape and regenerated with the formula.

### Section 3: The Bitstream Window and the Pre-Shifted Phases

A one-pixel scroll needs a byte that is the message shifted left by 0-7 bits. The 6502 can shift a byte with `ASL`, but doing that for 48 bytes in the score kernel would not fit the line. The lesson trades ROM for cycles: it stores **eight pre-shifted copies** of the message, one for each phase.

For phase `p`, row `r`, and byte index `i`, the table byte is:

```
p = 0:  message[i]
p > 0:  (message[i] << p) | (message[i+1] >> (8-p))
```

`message[i]` is the glyph byte for character `i` at font row `r`. The table holds 18 bytes per row: the 17 message bytes plus one zero pad. The pad is never read by the six-column window, but the shift of the last real byte needs it so the low bits come from zero rather than the next row.

The full table is `8 phases x 8 rows x 18 bytes = 1,152 bytes`. The phase block is 144 bytes. A small pointer table selects the block. The captures are phase 0; phases 0/1/3/7 were re-derived from the font during review, and the pointer arithmetic selects the other phases identically.

```asm
    LDX Phase
    LDA PhasePtrLo,X
    CLC
    ADC ByteIndex
    STA TextPtrLo
    LDA PhasePtrHi,X
    ADC #$00
    STA TextPtrHi
```

`Phase = ScrollOffset & 7` and `ByteIndex = ScrollOffset >> 3`. The pointer is the phase block's base plus the byte index; the fill advances it by 18 for each row. The window at offset 0 is `ByteIndex=0`, phase 0; at offset 40 it is `ByteIndex=5`, phase 0; at offset 88 it is `ByteIndex=11`, phase 0; at offset 1 it is phase 1, byte 0.

A still image cannot prove the one-pixel step: two captures at offsets 0 and 40 show the message at two windows, not the motion between them. The state log does: `ScrollOffsetRead` reports 0, 1, 1, 2, 2, ... and the wrap 88 -> 0. The captures prove the window content and the shift; the log proves the clock.

### Section 4: The 48-Store Fill

The fill is the transpose between the table and the score buffer. The source is row-major: row `r` is 18 contiguous bytes. The destination is column-major: column `c` is eight contiguous bytes at `ScoreBuf + c*8`. For each row the fill does six stores:

```asm
    LDX #0
FillRow:
    STX TextRow
    LDY #0
    STY TextCol
    LDA (TextPtrLo),Y
    STA ScoreBuf+0,X
    INY
    STY TextCol
    LDA (TextPtrLo),Y
    STA ScoreBuf+8,X
    ; ... four more columns: +16, +24, +32, +40 ...
    LDA (TextPtrLo),Y
    STA ScoreBuf+40,X
    LDA TextPtrLo
    CLC
    ADC #18
    STA TextPtrLo
    BCC FillNoCarry
    INC TextPtrHi
FillNoCarry:
    INX
    CPX #8
    BNE FillRow
```

X is the row (0-7) and Y is the column (0-5). The six `ScoreBuf+8*c,X` stores use the fixed column bases and X as the row offset, so the destination is the column-major layout without a second pointer. The pointer advance is 18; the add is 16-bit because a 144-byte phase block can cross a page boundary. `TextRow` and `TextCol` are debug latches; they make the stride visible in the state log. `TextFill` records the first byte of each row, and `TextColLast` records the last byte with `TextCol=5`.

The fill is 48 stores in VBLANK. It takes about twelve scanlines of the 37-line VBLANK. The rest of VBLANK is the beep, the inputs, the scroll clock, the ball's coarse position, and `ScoreSetup`'s one HMOVE. The fill and setup finish well before `+wait_timer` releases the picture at scanline 37.

### Section 5: The Starfield and the Shooting Star

Visible 9-191 is a 183-line starfield. The stars are three page-aligned 183-byte planes:

| Plane | Playfield chunks | Size |
|---|---|---|
| `StarPF0` | 0-3 | 183 bytes |
| `StarPF1` | 4-11 | 183 bytes |
| `StarPF2` | 12-19 | 183 bytes |

Each row reads one byte from each plane at the same Y and writes `PF0`, `PF1`, `PF2`. The planes are page-aligned, so `LDA StarPFx,Y` with Y=0-182 never crosses a page. The playfield is reflected (`CTRLPF=$01`), so the pattern doubles across the centre. The default pattern has 57 lit chunks before the reflection.

The shooting star is the ball at TIA X=80. The ball is one pixel wide. Its enable must be latched before the beam reaches X=80, which is about cycle 49 from the line start. The kernel does the compare first, then on the ball's line writes the gold `COLUPF` and the enable:

```asm
    CPY BallY
    BNE NoBall
BallRow:
    LDA #C_GOLD
    STA COLUPF
    LDA #$02
    STA ENABL
    JMP StarWait
NoBall:
    LDA #$00
    STA ENABL
StarWait:
    STA WSYNC
```

On every other line the clear (`LDA #$00`, `STA ENABL`) completes at cycle 43, still before X=80; the previous line's ball is hidden in time. On the ball's line the gold write completes at cycle 42 and the enable at cycle 47, about two cycles before the ball's pixel at X=80 (cycle 49.3). The gold write also tints the few playfield stars to the right of the ball on that line; the ball itself is the bright gold pixel.

The measured cycle ledger is 37 cycles of work on a plain line and 44 on the ball's line, plus the `WSYNC` and the loop tail: 47 and 54 cycles per line. The `StarWait` breakpoint reports 44 on a plain line and 51 on the ball's line; both are well inside the 76-cycle budget.

`BallY` starts at `$FF` so the first frame's `INC` wraps it to 0, the top row. It advances one line per frame and wraps at 183. The VBLANK sets the ball's coarse position with the divide-by-15 dance and `HMBL`/`RESBL`; `ScoreSetup`'s single `HMOVE` applies the ball's fine offset and the two players' offsets in one HBLANK.

### Section 6: The Frame, the Scroll Clock, and the Controls

The frame is the Part 7 skeleton: 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262 lines. The text is visible 0-8 and the starfield 9-191; 9 + 183 = 192.

The scroll clock is one byte and a divider:

```asm
    LDA FirePause
    BNE NoScrollStep
    INC ScrollTimer
    LDA ScrollTimer
    AND #$01
    BNE NoScrollStep
    INC ScrollOffset
    LDA ScrollOffset
    CMP #(SCROLL_MAX + 1)
    BCC ScrollStore
    LDA #$00
ScrollStore:
    STA ScrollOffset
```

`ScrollTimer`'s low bit makes the step happen every second frame. `ScrollOffset` wraps at 88: after the last six-character window the message starts again. SELECT resets the offset, the divider and the pause, so the demo restarts at "RACING" and moves. Fire toggles `FirePause` on the 0->1 edge; a paused message keeps its offset and resumes from it. The first eight frames are not trusted: `INPT4` can read low while the console settles, so `Startup` forces the fire edge clear until it reaches zero. A held fire button at power-on is therefore ignored; press fire after the first eight frames to pause.

The auto-demo scrolls without input. The two-frame step means one full cycle of 89 windows takes 178 frames, about three seconds; the captures at offsets 0 and 40 are two windows on that cycle.

### A Historical Note: The Activision Logo

Activision was founded in 1979 by former Atari employees, and its early Atari 2600 titles opened with a logo screen. The logo was a **graphic moved across the screen**, not a general text engine: the cartridge held a small bitmap and the kernel changed what the players drew as the picture moved. The 48-pixel two-player trick in this lesson is the same family of technique — two players in three-copy close mode make a wide, detailed strip — but this marquee is a teaching program, not a bit-exact reproduction of any Activision screen. The history is context; the code is the lesson.

## The Code

### Building This Lesson

```bash
# every lesson ROM, including this one:
npm run roms

# or just this one:
acme -f plain -o build/lesson55.bin \
  lessons/part7-kernel-mastery/55-scrolling-text-marquee/55-scrolling-text-marquee.asm

stella build/lesson55.bin
```

The three exercise solutions sit beside the lesson source. Each is a complete 4,096-byte ROM:

```bash
acme -f plain -o build/exercise-01.bin \
  lessons/part7-kernel-mastery/55-scrolling-text-marquee/exercise-01-solution.asm
acme -f plain -o build/exercise-02.bin \
  lessons/part7-kernel-mastery/55-scrolling-text-marquee/exercise-02-solution.asm
acme -f plain -o build/exercise-03.bin \
  lessons/part7-kernel-mastery/55-scrolling-text-marquee/exercise-03-solution.asm
```

### Full Source

The complete annotated source is reproduced verbatim from the `.asm` file:

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 55: Scrolling Text Marquee — The Activision Logo Effect
; =============================================================================
; Part 7: Kernel Mastery
;
; What this program does:
;   "the marquee": a six-character, 48-pixel text window at the top of the
;   screen, scrolling the message "RACING THE BEAM  " one pixel at a time
;   over a starfield with a one-pixel shooting star.
;
; The text window
;   The Lesson 39 score kernel draws six 8-pixel columns with two players in
;   three-copy close mode.  P0 sits at TIA X=56 (copies at 56, 72, 88) and P1
;   at X=64 (copies at 64, 80, 96), so the six columns interleave across
;   X=56-103: a 48-pixel cell block.  ScoreSetup positions the players and
;   turns VDEL on; ScoreDraw writes the eight glyph rows and consumes nine
;   visible lines (line 0 is the setup/blank line, lines 1-8 are the rows).
;
; The font and the message
;   The font is 39 glyphs (A-Z, 0-9, space, dash, period), eight bytes each,
;   bottom-up.  A glyph is 5x7 inside an 8x8 cell, bit 7 is the leftmost
;   pixel, and every glyph's byte 0 is $00, so the lit block is seven rows
;   (visible 1-7, capture y = 107 + 3.15 * line = 109-130).
;
;   The message is "RACING THE BEAM  " (17 characters).  A runtime shift
;   would be too expensive in the score kernel, so the program keeps eight
;   pre-shifted copies of the message, one for each horizontal phase.  The
;   table is 8 phases x 8 rows x 18 bytes = 1,152 bytes; each row holds the
;   17 message bytes plus one zero pad.  For phase p, the output byte is
;
;       (message[i] << p) | (message[i+1] >> (8-p))     for p > 0
;       message[i]                                      for p = 0
;
;   The fill selects the phase block with ScrollOffset & 7 and the byte
;   index with ScrollOffset >> 3, then copies the six columns:
;
;       ScoreBuf + c*8 + r = ShiftedTable[phase][r][byteIndex + c]
;
;   The destination is column-major because ScoreDraw reads one column at a
;   time; the source is row-major because a row's 18 bytes are contiguous.
;   That is 8 rows x 6 columns = 48 stores.  The window scrolls 0-88
;   (17*8 - 48 = 88), one pixel every two frames; SELECT resets to 0 and
;   fire pauses/resumes.  The auto-demo scrolls without input.
;
;   At offset 0 the window reads "RACING"; at offset 40 it reads "G THE ".
;
; The starfield
;   Visible 9-191 is a 183-line starfield drawn by a one-line kernel from
;   three page-aligned 183-byte planes (StarPF0/1/2).  The playfield is
;   reflected (CTRLPF=$01), so the pattern doubles across the centre.  A
;   one-pixel ball at TIA X=80 is the shooting star: it moves down one line
;   per frame, BallY 0-182.  The stars are white $0E; on the ball's row the
;   kernel writes COLUPF=$1A just before the ball's pixel, so the shooting
;   star is gold (the few playfield stars to its right on that line share
;   the gold write).
;
;   The text zone is 9 lines and the starfield is 183 lines: 9 + 183 = 192.
;
; The frame (NTSC): 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = 262.
;   StartFrame 259, VblankStart 0, BodyStart 37, OverscanStart 229.
;   The score's single HMOVE applies HMP0, HMP1 and the ball's HMBL; the
;   ball's coarse RESBL and HMBL are set before ScoreSetup.  There is one
;   HMOVE per frame.
;
; Checkpoints (Stella scanline/cycle numbers are measured in the lesson):
;   StartFrame (259), VblankStart (0), BodyStart (37), OverscanStart (229);
;   ScrollOffsetRead (A = the offset, 0..88), PhaseRead/ByteIndexRead;
;   TextRow (0..7), TextCol (0..5), TextFill (A = the first byte of a row);
;   ScoreDraw (37/11), ScoreDrawRow (37/26); HmoveApply/HmoveDone (the
;   score library's one HMOVE); BallYRead (A = the ball's row), BallRow
;   (Y = the ball's row in the kernel); FirePause (A = 0/1 after a press);
;   SelectReset (A = 0).
;
; RAM map (+clean_start zeroes every byte):
;   $80 ScrollOffset   0..88
;   $81 ScrollTimer    the two-frame scroll divider
;   $82 PrevFire       fire state last frame (1 = pressed)
;   $83 PrevSelect     SELECT state last frame (1 = pressed)
;   $84 FirePause      0 = scrolling, 1 = paused
;   $85 BeepTimer      frames of beep remaining
;   $86 BeepPitch      AUDF for the beep
;   $87 Startup        frames left before the fire edge is trusted
;   $88 NewFire        this frame's fire 0 -> 1 edge
;   $89 Scratch        SELECT's pressed state
;   $8A BallY          the shooting star's row, 0..182
;   $8B Phase          ScrollOffset & 7, 0..7
;   $8C ByteIndex      ScrollOffset >> 3, 0..11
;   $8D TextPtrLo      the fill pointer (low byte)
;   $8E TextPtrHi      the fill pointer (high byte)
;   $8F TextRow        the fill's row, 0..7
;   $90 TextCol        the fill's column, 0..5
;   $91 TextFirst      the first byte of each row (a debug latch)
;   $92-$9F free (14 bytes)
;   $A0-$D7 the score library: ScoreDigits, ScoreRow, ScoreTmp, ScoreBuf
;   $D8-$F7 free (32 bytes)
;   $F8-$FF stack
;
; Build: acme -f plain -o build/lesson55.bin \
;        lessons/part7-kernel-mastery/55-scrolling-text-marquee/55-scrolling-text-marquee.asm
; Run:   stella build/lesson55.bin     (click the screen to unmute the beeps)
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

SCREEN_LINES   = 192     ; every frame draws 192 visible lines
TEXT_TOP       = 0       ; the text zone's first visible line
TEXT_LINES     = 9       ; ScoreDraw's nine lines
STAR_TOP       = 9       ; the starfield's first visible line
STAR_LINES     = 183     ; 192 - 9

MESSAGE_LEN    = 17      ; "RACING THE BEAM  "
ROW_BYTES      = MESSAGE_LEN + 1   ; 17 bytes + one zero pad
PHASE_BYTES    = 8 * ROW_BYTES     ; one phase block: 8 rows x 18 bytes
SCROLL_MAX     = MESSAGE_LEN * 8 - 48   ; 88: the last six-character window

TEXT_COLUMNS   = 6       ; six 8-pixel columns
TEXT_ROWS      = 8       ; eight glyph rows

BALL_X         = 80      ; the shooting star's TIA X
BALL_LINES     = STAR_LINES   ; the ball's row wraps at the bottom

C_WHITE        = $0E     ; the text and the stars
C_GOLD         = $1A     ; the shooting star
C_BG           = $02     ; the background

BEEP_FRAMES    = 2       ; a two-frame tick
BEEP_PITCH     = $08     ; AUDF 8 on AUDC $0C: a short, bright beep

; The frame arithmetic is a build-time assertion, not a comment.
!if TEXT_TOP != 0 {
    !error "the text zone must start at visible line 0"
}
!if STAR_TOP != TEXT_TOP + TEXT_LINES {
    !error "the starfield must start after the nine text lines"
}
!if STAR_TOP + STAR_LINES != SCREEN_LINES {
    !error "the text zone plus the starfield must total 192 lines"
}
!if SCROLL_MAX != 88 {
    !error "the message must wrap at 88"
}
!if PHASE_BYTES != 144 {
    !error "one phase block must be 8 rows x 18 bytes"
}

; =============================================================================
; RAM ALLOCATION ($80-$91; +clean_start zeroes every byte)
; =============================================================================
ScrollOffset  = $80   ; the text window's first pixel, 0..88
ScrollTimer   = $81   ; the two-frame scroll divider
PrevFire      = $82   ; fire state last frame (1 = pressed)
PrevSelect    = $83   ; SELECT state last frame (1 = pressed)
FirePause     = $84   ; 0 = scrolling, 1 = paused
BeepTimer     = $85   ; frames of beep remaining
BeepPitch     = $86   ; AUDF for the beep
Startup       = $87   ; frames left before the fire edge is trusted
NewFire       = $88   ; this frame's fire 0 -> 1 edge
Scratch       = $89   ; SELECT's pressed state
BallY         = $8A   ; the shooting star's row, 0..182
Phase         = $8B   ; ScrollOffset & 7
ByteIndex     = $8C   ; ScrollOffset >> 3
TextPtrLo     = $8D   ; the fill pointer's low byte
TextPtrHi     = $8E   ; the fill pointer's high byte
TextRow       = $8F   ; the fill's row, 0..7
TextCol       = $90   ; the fill's column, 0..5
TextFirst     = $91   ; the first byte of each row (a debug latch)
;
; $92-$9F are free.  The score library owns $A0-$D7.  $D8-$F7 are free.
; The stack lives at $F8-$FF; the call depth is one level (SetCoarseBL,
; ScoreSetup, BeepStart).

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreSetup, ScoreDraw, ScoreInit, ScoreClear, ScoreSetDigit, ScoreAddOne and
; ScoreFont live here.  The library owns $A0-$D7 and defines the lesson's
; only HMOVE.  It is sourced first so its RAM symbols (ScoreBuf and friends)
; are known when the lesson's fill is assembled; the reset vector still
; points at the lesson's Reset below.
    !source "include/score.asm"

; =============================================================================
; RESET — the program's entry point
; =============================================================================
Reset:
    +clean_start
    LDA #$00
    STA SWACNT              ; port A is an input port (the fire button)

    LDA #BEEP_PITCH
    STA BeepPitch
    LDA #$08
    STA Startup             ; ignore the fire line while the console settles
    LDA #$FF
    STA BallY               ; the first frame's INC wraps to 0, the top row

; --- the TIA's fixed state ---------------------------------------------------
    LDA #C_BG
    STA COLUBK              ; the dark field behind the text and the stars
    LDA #$01
    STA CTRLPF              ; reflect the playfield; the ball is one pixel
    LDA #C_WHITE
    STA COLUP0              ; the six text columns are white
    STA COLUP1
    STA COLUPF              ; the stars are white until the ball's row
    LDA #$00
    STA NUSIZ0              ; ScoreSetup sets the three-copy mode
    STA NUSIZ1
    STA GRP0
    STA GRP1
    STA PF0
    STA PF1
    STA PF2
    STA ENABL

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
; 1. THE BEEP'S CLOCK
; -----------------------------------------------------------------------------
; The same two-byte beep the rest of Part 6 and Part 7 uses: BeepTimer counts
; down every frame and channel 0 goes silent at zero.
    LDA BeepTimer
    BEQ BeepClockDone
    DEC BeepTimer
    BNE BeepClockDone
    LDA #$00
    STA AUDV0
BeepClockDone:

; -----------------------------------------------------------------------------
; 2. FIRE — pause or resume the scroll on the 0 -> 1 edge
; -----------------------------------------------------------------------------
; INPT4 bit 7 is 0 while fire is held.  EOR turns that into a 1, and the
; EOR/AND pair keeps only a new press, so holding the button toggles once.
; The first eight frames are not trusted: INPT4 can read low while the
; console settles, so Startup forces the edge clear until it reaches zero.
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
FireEdgeReady:
    LDA NewFire
    BEQ NoFireEdge
    LDA FirePause
    EOR #$01                ; 0 -> 1 = pause, 1 -> 0 = resume
    STA FirePause
FirePauseSet:               ; checkpoint: A = the new pause flag
    JSR BeepStart
NoFireEdge:
    LDA INPT4
    AND #$80
    EOR #$80
    STA PrevFire

; -----------------------------------------------------------------------------
; 3. SELECT — reset the message to offset 0 and resume the scroll
; -----------------------------------------------------------------------------
; SWCHB bit 1 is 0 while SELECT is held.  The edge, not the level, resets the
; window.  SELECT also clears the pause so the demo restarts moving.
    LDA SWCHB
    AND #$02
    EOR #$02                ; 1 = pressed
    STA Scratch
    EOR PrevSelect
    AND Scratch
    BEQ NoSelectEdge
    LDA #$00
    STA ScrollOffset
    STA ScrollTimer
    STA FirePause
SelectReset:                ; checkpoint: A = 0, the new offset
    JSR BeepStart
NoSelectEdge:
    LDA Scratch
    STA PrevSelect

; -----------------------------------------------------------------------------
; 4. THE SCROLL CLOCK — one pixel every two frames
; -----------------------------------------------------------------------------
; ScrollTimer's low bit is the divider.  FirePause skips the whole clock, so
; a paused message keeps its offset and resumes from it.  The offset wraps
; 88 -> 0: after the last six-character window the message starts again.
    LDA FirePause
    BNE NoScrollStep
    INC ScrollTimer
    LDA ScrollTimer
    AND #$01
    BNE NoScrollStep
    INC ScrollOffset
    LDA ScrollOffset
    CMP #(SCROLL_MAX + 1)
    BCC ScrollStore
    LDA #$00
ScrollStore:
    STA ScrollOffset
NoScrollStep:
    LDA ScrollOffset
ScrollOffsetRead:           ; checkpoint: A = the window's first pixel

; -----------------------------------------------------------------------------
; 5. THE SHOOTING STAR — one line down per frame
; -----------------------------------------------------------------------------
    INC BallY
    LDA BallY
    CMP #BALL_LINES
    BCC BallStore
    LDA #$00
BallStore:
    STA BallY
BallYRead:                  ; checkpoint: A = the ball's row
    NOP

; -----------------------------------------------------------------------------
; 6. THE PHASE POINTER — phase block + byte index
; -----------------------------------------------------------------------------
; Phase = ScrollOffset & 7 selects one of the eight pre-shifted blocks.
; ByteIndex = ScrollOffset >> 3 selects the first of the six columns inside
; the 18-byte row.  The pointer is the block's base plus the byte index;
; the fill advances it by ROW_BYTES (18) per row.
    LDA ScrollOffset
    AND #$07
    STA Phase
PhaseRead:                  ; checkpoint: A = the phase, 0..7
    LDA ScrollOffset
    LSR
    LSR
    LSR
    STA ByteIndex
ByteIndexRead:              ; checkpoint: A = the byte index, 0..11

    LDX Phase
    LDA PhasePtrLo,X
    CLC
    ADC ByteIndex
    STA TextPtrLo
    LDA PhasePtrHi,X
    ADC #$00
    STA TextPtrHi

; -----------------------------------------------------------------------------
; 7. THE TEXT FILL — 48 stores at ScoreBuf + c*8 + r
; -----------------------------------------------------------------------------
; The source is row-major (one 18-byte row at a time); the destination is
; column-major (column c's eight rows at ScoreBuf+c*8).  X is the row and
; Y is the column, so the six stores use the fixed ScoreBuf+0/8/16/24/32/40
; bases with X as the row offset.  TextRow and TextCol are debug latches;
; they make the stride visible in the state log.
    LDX #0
FillRow:
    STX TextRow
    LDY #0
    STY TextCol
    LDA (TextPtrLo),Y
    STA TextFirst
TextFill:                   ; checkpoint: A = the first byte of the row
    STA ScoreBuf+0,X
    INY
    STY TextCol
    LDA (TextPtrLo),Y
    STA ScoreBuf+8,X
    INY
    STY TextCol
    LDA (TextPtrLo),Y
    STA ScoreBuf+16,X
    INY
    STY TextCol
    LDA (TextPtrLo),Y
    STA ScoreBuf+24,X
    INY
    STY TextCol
    LDA (TextPtrLo),Y
    STA ScoreBuf+32,X
    INY
    STY TextCol
    LDA (TextPtrLo),Y
    STA ScoreBuf+40,X
TextColLast:                ; checkpoint: TextCol = 5, A = the last byte
    ; The next row starts ROW_BYTES further on.  The pointer is 16 bits
    ; because a phase block is 144 bytes and can cross a page boundary.
    LDA TextPtrLo
    CLC
    ADC #ROW_BYTES
    STA TextPtrLo
    BCC FillNoCarry
    INC TextPtrHi
FillNoCarry:
    INX
    CPX #TEXT_ROWS
    BNE FillRow

; -----------------------------------------------------------------------------
; 8. THE SCORE SETUP AND THE ONE HMOVE
; -----------------------------------------------------------------------------
; SetCoarseBL's RESBL/HMBL and ScoreSetup's RESP0/RESP1/HMP0/HMP1 are all set
; first; ScoreSetup's single HMOVE applies the three fine offsets in one
; HBLANK.  The score's three-copy window needs VDEL on, which ScoreSetup
; sets.  The caller supplies the colours (white above).
    LDA #C_WHITE
    STA COLUP0
    STA COLUP1
    LDA #C_WHITE
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA GRP0
    STA GRP1
    STA ENABL

    LDA #(BALL_X + POS_BIAS + 1)   ; the ball's reset is one clock short
    JSR SetCoarseBL                ; sets HMBL and RESBL
    JSR ScoreSetup                 ; sets NUSIZ/VDEL, P0/P1, then one HMOVE

    +wait_timer
    LDA #$00
    STA VBLANK              ; picture on

; =============================================================================
; VISIBLE — 192 lines: the text band (9) and the starfield (183)
; =============================================================================
BodyStart:                  ; checkpoint: scanline 37, visible line 0
    JSR ScoreDraw           ; 9 lines: line 0 setup, lines 1-8 rows

; The score's cleanup has cleared GRP0/GRP1 and VDEL; the starfield starts
; on visible line 9 (scanline 46) and draws 183 lines.
StarStart:                  ; checkpoint: scanline 46, visible line 9
StarField:
    LDY #0
StarRow:                    ; checkpoint: Y = 0..182
    ; The stars are white on every line.  The write is first so the ball's
    ; gold write below can change the colour on its own line.
    LDA #C_WHITE
    STA COLUPF
    LDA StarPF0,Y
    STA PF0                 ; chunks 0-3 (the page-aligned plane)
    LDA StarPF1,Y
    STA PF1                 ; chunks 4-11
    LDA StarPF2,Y
    STA PF2                 ; chunks 12-19
    ; The ball is one pixel at X=80, so its enable must be latched before
    ; the beam reaches pixel 80 (about cycle 49 from the line start).  The
    ; compare comes first; on the ball's row the gold write and the enable
    ; follow immediately, and there is no clear to waste cycles.  On every
    ; other row the clear is still early enough (cycle ~36) to hide the ball.
    CPY BallY
    BNE NoBall
BallRow:                    ; checkpoint: Y = BallY
    LDA #C_GOLD
    STA COLUPF              ; the gold write lands before the ball's pixel
    LDA #$02
    STA ENABL
    JMP StarWait
NoBall:
    LDA #$00
    STA ENABL               ; off before X=80 on every other row
StarWait:
    STA WSYNC
    INY
    CPY #STAR_LINES
    BNE StarRow
    JMP OverscanStart       ; 183 lines: visible 9-191

; =============================================================================
; FRAME END — 30 overscan lines, then the next frame
; =============================================================================
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; SetCoarseBL — the Lesson 26 divide-by-15 dance for the ball
; =============================================================================
; A = the desired left edge + POS_BIAS + 1.  The first WSYNC starts a fresh
; line; each loop iteration is 5 cycles = 15 colour clocks, which is why
; dividing by 15 works.  The remainder becomes the fine value and RESBL
; strobes the coarse position; ScoreSetup's HMOVE applies HMBL.
; The routine is 32-byte aligned so the loop's taken BCS stays inside one
; page: a page-crossing branch costs one extra cycle per iteration and would
; shift the ball by 15 colour clocks.
    !align 31, 0
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
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
; AUDC 0C is the div-6 tone from Lesson 35; AUDV 0A is audible but not loud.
; The VBLANK clock silences the channel two frames later.
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; THE PHASE POINTERS — one 16-bit pointer per pre-shifted phase
; =============================================================================
; The fill needs a runtime block base, so the eight low bytes and eight high
; bytes are kept as two small tables.  X = Phase selects the entry; the
; byte index is added to the low byte and the carry goes into the high byte.
PhasePtrLo:
    !byte <(ShiftedTable + 0*PHASE_BYTES), <(ShiftedTable + 1*PHASE_BYTES)
    !byte <(ShiftedTable + 2*PHASE_BYTES), <(ShiftedTable + 3*PHASE_BYTES)
    !byte <(ShiftedTable + 4*PHASE_BYTES), <(ShiftedTable + 5*PHASE_BYTES)
    !byte <(ShiftedTable + 6*PHASE_BYTES), <(ShiftedTable + 7*PHASE_BYTES)
PhasePtrHi:
    !byte >(ShiftedTable + 0*PHASE_BYTES), >(ShiftedTable + 1*PHASE_BYTES)
    !byte >(ShiftedTable + 2*PHASE_BYTES), >(ShiftedTable + 3*PHASE_BYTES)
    !byte >(ShiftedTable + 4*PHASE_BYTES), >(ShiftedTable + 5*PHASE_BYTES)
    !byte >(ShiftedTable + 6*PHASE_BYTES), >(ShiftedTable + 7*PHASE_BYTES)

; =============================================================================
; THE PRE-SHIFTED MESSAGE — 8 phases x 8 rows x 18 bytes = 1,152 bytes
; =============================================================================
; The message is "RACING THE BEAM  " (17 characters; the two trailing spaces
; let the last letters leave the window cleanly).  Each row's 18th byte is a
; zero pad: it is never read by the six-column window, but the shift of the
; last real byte needs it.  The bytes are generated from the font below with
; the formula in the source header.  The table is row-major inside a phase;
; the lesson's fill turns it into the score buffer's column-major order.
ShiftedTable:
    ; --- phase 0: every byte shifted left 0 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 0, font row 0
    !byte $88,$88,$70,$F8,$88,$70,$00,$20,$88,$F8,$00,$F0,$F8,$88,$88,$00,$00,$00   ; phase 0, font row 1
    !byte $90,$88,$88,$20,$88,$88,$00,$20,$88,$80,$00,$88,$80,$88,$88,$00,$00,$00   ; phase 0, font row 2
    !byte $A0,$88,$80,$20,$88,$88,$00,$20,$88,$80,$00,$88,$80,$88,$88,$00,$00,$00   ; phase 0, font row 3
    !byte $F0,$F8,$80,$20,$98,$B8,$00,$20,$F8,$F0,$00,$F0,$F0,$F8,$A8,$00,$00,$00   ; phase 0, font row 4
    !byte $88,$88,$80,$20,$A8,$80,$00,$20,$88,$80,$00,$88,$80,$88,$A8,$00,$00,$00   ; phase 0, font row 5
    !byte $88,$88,$88,$20,$C8,$88,$00,$20,$88,$80,$00,$88,$80,$88,$D8,$00,$00,$00   ; phase 0, font row 6
    !byte $F0,$70,$70,$F8,$88,$70,$00,$F8,$88,$F8,$00,$F0,$F8,$70,$88,$00,$00,$00   ; phase 0, font row 7
    ; --- phase 1: every byte shifted left 1 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 1, font row 0
    !byte $11,$10,$E1,$F1,$10,$E0,$00,$41,$11,$F0,$01,$E1,$F1,$11,$10,$00,$00,$00   ; phase 1, font row 1
    !byte $21,$11,$10,$41,$11,$10,$00,$41,$11,$00,$01,$11,$01,$11,$10,$00,$00,$00   ; phase 1, font row 2
    !byte $41,$11,$00,$41,$11,$10,$00,$41,$11,$00,$01,$11,$01,$11,$10,$00,$00,$00   ; phase 1, font row 3
    !byte $E1,$F1,$00,$41,$31,$70,$00,$41,$F1,$E0,$01,$E1,$E1,$F1,$50,$00,$00,$00   ; phase 1, font row 4
    !byte $11,$11,$00,$41,$51,$00,$00,$41,$11,$00,$01,$11,$01,$11,$50,$00,$00,$00   ; phase 1, font row 5
    !byte $11,$11,$10,$41,$91,$10,$00,$41,$11,$00,$01,$11,$01,$11,$B0,$00,$00,$00   ; phase 1, font row 6
    !byte $E0,$E0,$E1,$F1,$10,$E0,$01,$F1,$11,$F0,$01,$E1,$F0,$E1,$10,$00,$00,$00   ; phase 1, font row 7
    ; --- phase 2: every byte shifted left 2 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 2, font row 0
    !byte $22,$21,$C3,$E2,$21,$C0,$00,$82,$23,$E0,$03,$C3,$E2,$22,$20,$00,$00,$00   ; phase 2, font row 1
    !byte $42,$22,$20,$82,$22,$20,$00,$82,$22,$00,$02,$22,$02,$22,$20,$00,$00,$00   ; phase 2, font row 2
    !byte $82,$22,$00,$82,$22,$20,$00,$82,$22,$00,$02,$22,$02,$22,$20,$00,$00,$00   ; phase 2, font row 3
    !byte $C3,$E2,$00,$82,$62,$E0,$00,$83,$E3,$C0,$03,$C3,$C3,$E2,$A0,$00,$00,$00   ; phase 2, font row 4
    !byte $22,$22,$00,$82,$A2,$00,$00,$82,$22,$00,$02,$22,$02,$22,$A0,$00,$00,$00   ; phase 2, font row 5
    !byte $22,$22,$20,$83,$22,$20,$00,$82,$22,$00,$02,$22,$02,$23,$60,$00,$00,$00   ; phase 2, font row 6
    !byte $C1,$C1,$C3,$E2,$21,$C0,$03,$E2,$23,$E0,$03,$C3,$E1,$C2,$20,$00,$00,$00   ; phase 2, font row 7
    ; --- phase 3: every byte shifted left 3 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 3, font row 0
    !byte $44,$43,$87,$C4,$43,$80,$01,$04,$47,$C0,$07,$87,$C4,$44,$40,$00,$00,$00   ; phase 3, font row 1
    !byte $84,$44,$41,$04,$44,$40,$01,$04,$44,$00,$04,$44,$04,$44,$40,$00,$00,$00   ; phase 3, font row 2
    !byte $04,$44,$01,$04,$44,$40,$01,$04,$44,$00,$04,$44,$04,$44,$40,$00,$00,$00   ; phase 3, font row 3
    !byte $87,$C4,$01,$04,$C5,$C0,$01,$07,$C7,$80,$07,$87,$87,$C5,$40,$00,$00,$00   ; phase 3, font row 4
    !byte $44,$44,$01,$05,$44,$00,$01,$04,$44,$00,$04,$44,$04,$45,$40,$00,$00,$00   ; phase 3, font row 5
    !byte $44,$44,$41,$06,$44,$40,$01,$04,$44,$00,$04,$44,$04,$46,$C0,$00,$00,$00   ; phase 3, font row 6
    !byte $83,$83,$87,$C4,$43,$80,$07,$C4,$47,$C0,$07,$87,$C3,$84,$40,$00,$00,$00   ; phase 3, font row 7
    ; --- phase 4: every byte shifted left 4 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 4, font row 0
    !byte $88,$87,$0F,$88,$87,$00,$02,$08,$8F,$80,$0F,$0F,$88,$88,$80,$00,$00,$00   ; phase 4, font row 1
    !byte $08,$88,$82,$08,$88,$80,$02,$08,$88,$00,$08,$88,$08,$88,$80,$00,$00,$00   ; phase 4, font row 2
    !byte $08,$88,$02,$08,$88,$80,$02,$08,$88,$00,$08,$88,$08,$88,$80,$00,$00,$00   ; phase 4, font row 3
    !byte $0F,$88,$02,$09,$8B,$80,$02,$0F,$8F,$00,$0F,$0F,$0F,$8A,$80,$00,$00,$00   ; phase 4, font row 4
    !byte $88,$88,$02,$0A,$88,$00,$02,$08,$88,$00,$08,$88,$08,$8A,$80,$00,$00,$00   ; phase 4, font row 5
    !byte $88,$88,$82,$0C,$88,$80,$02,$08,$88,$00,$08,$88,$08,$8D,$80,$00,$00,$00   ; phase 4, font row 6
    !byte $07,$07,$0F,$88,$87,$00,$0F,$88,$8F,$80,$0F,$0F,$87,$08,$80,$00,$00,$00   ; phase 4, font row 7
    ; --- phase 5: every byte shifted left 5 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 5, font row 0
    !byte $11,$0E,$1F,$11,$0E,$00,$04,$11,$1F,$00,$1E,$1F,$11,$11,$00,$00,$00,$00   ; phase 5, font row 1
    !byte $11,$11,$04,$11,$11,$00,$04,$11,$10,$00,$11,$10,$11,$11,$00,$00,$00,$00   ; phase 5, font row 2
    !byte $11,$10,$04,$11,$11,$00,$04,$11,$10,$00,$11,$10,$11,$11,$00,$00,$00,$00   ; phase 5, font row 3
    !byte $1F,$10,$04,$13,$17,$00,$04,$1F,$1E,$00,$1E,$1E,$1F,$15,$00,$00,$00,$00   ; phase 5, font row 4
    !byte $11,$10,$04,$15,$10,$00,$04,$11,$10,$00,$11,$10,$11,$15,$00,$00,$00,$00   ; phase 5, font row 5
    !byte $11,$11,$04,$19,$11,$00,$04,$11,$10,$00,$11,$10,$11,$1B,$00,$00,$00,$00   ; phase 5, font row 6
    !byte $0E,$0E,$1F,$11,$0E,$00,$1F,$11,$1F,$00,$1E,$1F,$0E,$11,$00,$00,$00,$00   ; phase 5, font row 7
    ; --- phase 6: every byte shifted left 6 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 6, font row 0
    !byte $22,$1C,$3E,$22,$1C,$00,$08,$22,$3E,$00,$3C,$3E,$22,$22,$00,$00,$00,$00   ; phase 6, font row 1
    !byte $22,$22,$08,$22,$22,$00,$08,$22,$20,$00,$22,$20,$22,$22,$00,$00,$00,$00   ; phase 6, font row 2
    !byte $22,$20,$08,$22,$22,$00,$08,$22,$20,$00,$22,$20,$22,$22,$00,$00,$00,$00   ; phase 6, font row 3
    !byte $3E,$20,$08,$26,$2E,$00,$08,$3E,$3C,$00,$3C,$3C,$3E,$2A,$00,$00,$00,$00   ; phase 6, font row 4
    !byte $22,$20,$08,$2A,$20,$00,$08,$22,$20,$00,$22,$20,$22,$2A,$00,$00,$00,$00   ; phase 6, font row 5
    !byte $22,$22,$08,$32,$22,$00,$08,$22,$20,$00,$22,$20,$22,$36,$00,$00,$00,$00   ; phase 6, font row 6
    !byte $1C,$1C,$3E,$22,$1C,$00,$3E,$22,$3E,$00,$3C,$3E,$1C,$22,$00,$00,$00,$00   ; phase 6, font row 7
    ; --- phase 7: every byte shifted left 7 pixel(s) ---
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; phase 7, font row 0
    !byte $44,$38,$7C,$44,$38,$00,$10,$44,$7C,$00,$78,$7C,$44,$44,$00,$00,$00,$00   ; phase 7, font row 1
    !byte $44,$44,$10,$44,$44,$00,$10,$44,$40,$00,$44,$40,$44,$44,$00,$00,$00,$00   ; phase 7, font row 2
    !byte $44,$40,$10,$44,$44,$00,$10,$44,$40,$00,$44,$40,$44,$44,$00,$00,$00,$00   ; phase 7, font row 3
    !byte $7C,$40,$10,$4C,$5C,$00,$10,$7C,$78,$00,$78,$78,$7C,$54,$00,$00,$00,$00   ; phase 7, font row 4
    !byte $44,$40,$10,$54,$40,$00,$10,$44,$40,$00,$44,$40,$44,$54,$00,$00,$00,$00   ; phase 7, font row 5
    !byte $44,$44,$10,$64,$44,$00,$10,$44,$40,$00,$44,$40,$44,$6C,$00,$00,$00,$00   ; phase 7, font row 6
    !byte $38,$38,$7C,$44,$38,$00,$7C,$44,$7C,$00,$78,$7C,$38,$44,$00,$00,$00,$00   ; phase 7, font row 7

; =============================================================================
; THE FONT — 39 glyphs x 8 bytes, bottom-up, bit 7 = the leftmost pixel
; =============================================================================
; The runtime does not read the font: the pre-shifted table above is the
; runtime copy.  The font is kept here as the glyph atlas, so every byte of
; the table can be checked against a visible 5x7 shape and regenerated with
; the header's formula.  Byte 0 is the bottom row and is $00 in every glyph;
; bytes 1-7 are the lit rows, so the visible block is seven scanlines.
Font:
    ; A
    !byte $00,$88,$88,$88,$F8,$88,$88,$70
    ; B
    !byte $00,$F0,$88,$88,$F0,$88,$88,$F0
    ; C
    !byte $00,$70,$88,$80,$80,$80,$88,$70
    ; D
    !byte $00,$F0,$88,$88,$88,$88,$88,$F0
    ; E
    !byte $00,$F8,$80,$80,$F0,$80,$80,$F8
    ; F
    !byte $00,$80,$80,$80,$F0,$80,$80,$F8
    ; G
    !byte $00,$70,$88,$88,$B8,$80,$88,$70
    ; H
    !byte $00,$88,$88,$88,$F8,$88,$88,$88
    ; I
    !byte $00,$F8,$20,$20,$20,$20,$20,$F8
    ; J
    !byte $00,$60,$90,$90,$10,$10,$10,$38
    ; K
    !byte $00,$88,$90,$A0,$C0,$A0,$90,$88
    ; L
    !byte $00,$F8,$80,$80,$80,$80,$80,$80
    ; M
    !byte $00,$88,$88,$88,$A8,$A8,$D8,$88
    ; N
    !byte $00,$88,$88,$88,$98,$A8,$C8,$88
    ; O
    !byte $00,$70,$88,$88,$88,$88,$88,$70
    ; P
    !byte $00,$80,$80,$80,$F0,$88,$88,$F0
    ; Q
    !byte $00,$68,$90,$A8,$88,$88,$88,$70
    ; R
    !byte $00,$88,$90,$A0,$F0,$88,$88,$F0
    ; S
    !byte $00,$F0,$08,$08,$70,$80,$80,$78
    ; T
    !byte $00,$20,$20,$20,$20,$20,$20,$F8
    ; U
    !byte $00,$70,$88,$88,$88,$88,$88,$88
    ; V
    !byte $00,$20,$50,$88,$88,$88,$88,$88
    ; W
    !byte $00,$88,$D8,$A8,$A8,$88,$88,$88
    ; X
    !byte $00,$88,$88,$50,$20,$50,$88,$88
    ; Y
    !byte $00,$20,$20,$20,$20,$50,$88,$88
    ; Z
    !byte $00,$F8,$80,$40,$20,$10,$08,$F8
    ; 0
    !byte $00,$70,$88,$C8,$A8,$98,$88,$70
    ; 1
    !byte $00,$F8,$20,$20,$20,$20,$60,$20
    ; 2
    !byte $00,$F8,$40,$20,$10,$08,$88,$70
    ; 3
    !byte $00,$F0,$08,$08,$70,$08,$08,$F0
    ; 4
    !byte $00,$10,$10,$F8,$90,$50,$30,$10
    ; 5
    !byte $00,$70,$88,$08,$08,$F0,$80,$F8
    ; 6
    !byte $00,$70,$88,$88,$F0,$80,$88,$70
    ; 7
    !byte $00,$40,$40,$40,$20,$10,$08,$F8
    ; 8
    !byte $00,$70,$88,$88,$70,$88,$88,$70
    ; 9
    !byte $00,$70,$88,$08,$78,$88,$88,$70
    ; space
    !byte $00,$00,$00,$00,$00,$00,$00,$00
    ; dash
    !byte $00,$00,$00,$00,$F8,$00,$00,$00
    ; period
    !byte $00,$60,$60,$00,$00,$00,$00,$00

; =============================================================================
; THE STARFIELD — three page-aligned 183-byte planes
; =============================================================================
; Row r of the world is StarPF0+r, StarPF1+r and StarPF2+r.  The planes are
; page-aligned, so LDA StarPFx,Y with Y=0..182 never crosses a page.  PF0
; uses only bits 4-7 (chunks 0-3); PF1 covers chunks 4-11 and PF2 chunks
; 12-19.  The pattern is sparse (about 57 lit chunks before the reflection).
    !align 255, 0
StarPF0:
    !byte $00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 0-15
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$70   ; rows 16-31
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$00   ; rows 32-47
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 48-63
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 64-79
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 80-95
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 96-111
    !byte $70,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 112-127
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$00,$00   ; rows 128-143
    !byte $00,$00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 144-159
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$00,$00,$00,$00   ; rows 160-175
    !byte $00,$00,$00,$00,$00,$00,$00   ; rows 176-182

    !align 255, 0
StarPF1:
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$00   ; rows 0-15
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 16-31
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00,$00,$00,$01,$00,$00   ; rows 32-47
    !byte $02,$00,$00,$00,$00,$30,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 48-63
    !byte $00,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00,$03,$00,$00,$00,$0C   ; rows 64-79
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 80-95
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 96-111
    !byte $00,$00,$00,$00,$00,$00,$00,$08,$00,$00,$00,$00,$00,$00,$04,$00   ; rows 112-127
    !byte $00,$00,$00,$00,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 128-143
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40   ; rows 144-159
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 160-175
    !byte $00,$00,$00,$00,$00,$00,$00   ; rows 176-182

    !align 255, 0
StarPF2:
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 0-15
    !byte $00,$60,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$38,$00,$00,$00   ; rows 16-31
    !byte $00,$00,$00,$00,$00,$00,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 32-47
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$C0,$00,$00,$00,$00,$00   ; rows 48-63
    !byte $00,$00,$00,$00,$00,$08,$00,$00,$00,$00,$00,$00,$00,$00,$F8,$00   ; rows 64-79
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00,$00,$00,$00   ; rows 80-95
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$00,$00,$00,$00,$00   ; rows 96-111
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 112-127
    !byte $00,$00,$00,$00,$02,$00,$04,$04,$00,$E0,$00,$00,$00,$00,$00,$00   ; rows 128-143
    !byte $00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; rows 144-159
    !byte $00,$00,$00,$00,$C0,$02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$08   ; rows 160-175
    !byte $00,$00,$01,$00,$00,$00,$00   ; rows 176-182

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
> `lessons/part7-kernel-mastery/55-scrolling-text-marquee/55-scrolling-text-marquee.asm`.

### Code Walkthrough

#### Step 1 — The frame skeleton

```asm
StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER
    ; ... beep, inputs, scroll clock, ball, phase pointer, fill, setup ...
    +wait_timer
    LDA #$00
    STA VBLANK

BodyStart:
    JSR ScoreDraw           ; nine visible lines
StarStart:
StarField:
    ; ... 183 lines ...
```

The frame is 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan. `StartFrame` is scanline 259, `VblankStart` 0, `BodyStart` 37 and `OverscanStart` 229. The text and starfield share the 192 lines: nine for the text, 183 for the stars.

#### Step 2 — The scroll clock and the controls

```asm
    LDA FirePause
    BNE NoScrollStep
    INC ScrollTimer
    LDA ScrollTimer
    AND #$01
    BNE NoScrollStep
    INC ScrollOffset
    LDA ScrollOffset
    CMP #(SCROLL_MAX + 1)
    BCC ScrollStore
    LDA #$00
ScrollStore:
    STA ScrollOffset
```

`ScrollTimer`'s low bit is the two-frame divider. `ScrollOffset` wraps at 88. SELECT clears the offset, the divider and the pause; fire toggles the pause on a new press. The edge detectors are the Part 7 idiom: `INPT4`/`SWCHB` bit 7/1 is inverted, compared with the previous frame, and the `Startup` guard suppresses the first eight frames of fire.

#### Step 3 — The phase pointer and the 48-byte fill

```asm
    LDA ScrollOffset
    AND #$07
    STA Phase
    LDA ScrollOffset
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
```

The phase block is 144 bytes; the byte index selects the first of the six columns. The fill then copies 8 rows x 6 columns at `ScoreBuf+0/8/16/24/32/40,X`. `TextRow` and `TextCol` are debug latches; `TextFill` is the first byte of each row. The pointer advances by 18 per row, and the carry goes into the high byte because a block can cross a page.

#### Step 4 — `ScoreSetup` and the one `HMOVE`

```asm
    LDA #(BALL_X + POS_BIAS + 1)   ; the ball's reset is one clock short
    JSR SetCoarseBL                ; sets HMBL and RESBL
    JSR ScoreSetup                 ; sets NUSIZ/VDEL, P0/P1, then one HMOVE
```

`SetCoarseBL` is the Lesson 26 divide-by-15 dance for the ball. `ScoreSetup` sets `NUSIZ0=NUSIZ1=3`, `VDELP0=VDELP1=1`, positions P0 at 56 and P1 at 64, and strobes one `HMOVE`. The `HMOVE` applies `HMP0`, `HMP1` and the ball's `HMBL` in one HBLANK. This is the lesson's only `HMOVE`.

#### Step 5 — The text band and `ScoreDraw`

```asm
BodyStart:
    JSR ScoreDraw           ; nine lines: line 0 setup, lines 1-8 rows
StarStart:
```

`ScoreDraw` is the Lesson 39 kernel. The first row's stores land at 37/26; the subsequent rows at 38/72 ... 44/72. The cleanup shares line 8, so the starfield starts on visible 9, scanline 46. The caller sets `COLUP0` and `COLUP1` to white; the score's six columns are the text cells at TIA X=56-103.

#### Step 6 — The starfield kernel and the shooting star

```asm
StarRow:
    LDA #C_WHITE
    STA COLUPF
    LDA StarPF0,Y
    STA PF0
    LDA StarPF1,Y
    STA PF1
    LDA StarPF2,Y
    STA PF2
    CPY BallY
    BNE NoBall
BallRow:
    LDA #C_GOLD
    STA COLUPF
    LDA #$02
    STA ENABL
    JMP StarWait
NoBall:
    LDA #$00
    STA ENABL
StarWait:
    STA WSYNC
    INY
    CPY #STAR_LINES
    BNE StarRow
```

The three playfield pairs are the whole star pattern. The ball compare and the enable are the only vertical logic: on the ball's line the gold write completes at cycle 42 and the enable at 47, before the ball's pixel at X=80 (cycle 49.3); on every other line the clear completes at cycle 43, before the same pixel. The measured work is 37 cycles on a plain line and 44 on the ball's line; the `WSYNC` and the loop tail take the line to 47/54.

#### Step 7 — Reading it back in Stella

Assemble with a symbol file and ask Stella for the checkpoints:

```bash
acme -f plain -l build/lesson55.sym -o build/lesson55.bin \
  lessons/part7-kernel-mastery/55-scrolling-text-marquee/55-scrolling-text-marquee.asm

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 \
  -break '$F186' build/lesson55.bin
```

Run each checkpoint separately for a readable log. The addresses below are the ones this source produced. A breakpoint on a label reports the first cycle of the instruction that follows it.

### Checkpoints

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F186` | 259/3 | the first VSYNC line |
| `VblankStart` | `$F194` | 0/5 | the first VBLANK line |
| `BodyStart` | `$F2A5` | 37/5 | visible line 0 |
| `ScoreDraw` | `$F0B6` | 37/11 | the score kernel's entry |
| `ScoreDrawRow` | `$F0C1` | 37/26, then 38/72 ... 44/72 | the first row's stores |
| `StarStart` | `$F2A8` | 46/5 | visible line 9, the starfield's first line |
| `StarRow` | `$F2AA` | Y=0..182 | the starfield's row |
| `StarWait` | `$F2D0` | 44 plain, 51 ball row | the `WSYNC`'s cycle |
| `BallYRead` | `$F21A` | A=0..182 | the shooting star's row |
| `BallRow` | `$F2C1` | 46/38, Y=BallY | the ball's line |
| `NoBall` | `$F2CC` | 39 | the clear's path on other lines |
| `ScrollOffsetRead` | `$F20E` | A=0..88 | the window's first pixel |
| `PhaseRead` | `$F221` | A=0..7 | `ScrollOffset & 7` |
| `ByteIndexRead` | `$F228` | A=0..11 | `ScrollOffset >> 3` |
| `TextRow` | `$008F` (RAM) | 0..7 | the fill's row |
| `TextCol` | `$0090` (RAM) | 0..5 | the fill's column |
| `TextFill` | `$F245` | A=the first byte of the row | the fill's first store |
| `TextColLast` | `$F26A` | A=the last byte, `TextCol`=5 | the fill's sixth store |
| `HmoveApply` | `$F06A` | 18/45 | the one `HMOVE`'s HBLANK |
| `HmoveDone` | `$F06C` | 19/3 | the store has executed |
| `OverscanStart` | `$F2DA` | 229/9 | the first blank line after the picture |
| `FirePauseSet` | `$F1CB` | A=0/1 | the new pause flag after a press |
| `SelectReset` | `$F1ED` | A=0 | SELECT's new offset |

## What You Should See

The marquee is one picture at a time, but the text moves. At offset 0 the six-character window reads **"RACING"**; at offset 40 it reads **"G THE "**; at offset 88 it reads **"BEAM  "** and then wraps to "RACING". The text is white in a nine-line zone with seven lit glyph rows, and sits over a white 183-line starfield. A one-pixel gold shooting star falls through the starfield at TIA X=80.

![Stella running the Lesson 55 ROM at offset 0: a white six-character banner reading RACING across the top, a white starfield below, and a one-pixel gold shooting star near the bottom centre; the title bar reads Stella 7.0: "55-scrolling-text-marquee"](/images/lesson55/marquee-a.png)

*`marquee-a`: offset 0, the window "RACING". The 48-pixel cell block is TIA X=56-103, captured at x=361-648 (six cells, left edges 361/409/457/505/553/601). The lit glyphs measure x=361-630, y=109-130; the 5x7 glyphs use bits 7-3, so the right three pixels of each 8-pixel cell are blank. The shooting star is the gold pixel at x=505-510, y=694-696 (TIA X=80; the y mapping places it at visible row ~186).*

<RomPlayer rom="/roms/part7-kernel-mastery/55-scrolling-text-marquee/55-scrolling-text-marquee.bin" title="Lesson 55 — Scrolling Text Marquee" />

Javatari starts muted: click the player once to unmute the fire/SELECT beep.

![Stella running the Lesson 55 ROM at offset 40: the same white banner showing G THE, the starfield, and the gold shooting star near the top; the title bar reads Stella 7.0: "55-scrolling-text-marquee"](/images/lesson55/marquee-b.png)

*`marquee-b`: offset 40, the window "G THE ". The first cell is G, the second a space, then T, H, E and a final space. The lit range is x=361-582 because the sixth cell is blank. The shooting star is at x=505-510, y=226-228 (TIA X=80; the y mapping places it at visible row ~38). The starfield is the same static pattern in both images; only the text and the ball move.*

> **Capture method.** Both images are window captures of
> `docs/public/roms/part7-kernel-mastery/55-scrolling-text-marquee/55-scrolling-text-marquee.bin`
> in Stella 7.0, taken from the committed ROM path with the pointer parked outside the
> window. The scroll is one pixel every two frames, so a fixed wait cannot aim at a
> particular offset: the images were selected from a burst by matching the 48-byte window
> against the pre-shifted table. The match is exact (zero mismatched bits) at offset 0 and
> offset 40, which is how the displayed offsets were measured. The gold ball is in a
> different row in each image because it falls one line per frame.

The ROM needs no input: the auto-demo scrolls. SELECT resets the message to offset 0 and resumes the scroll; fire pauses or resumes it (press it after the first eight frames; a held button at power-on is ignored by the startup guard). The joystick is not read in this lesson.

The debugger tells the same story as numbers. One checkpoint per run:

```bash
ROM=docs/public/roms/part7-kernel-mastery/55-scrolling-text-marquee/55-scrolling-text-marquee.bin
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F186' $ROM   # StartFrame
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F2A5' $ROM   # BodyStart
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F0C1' $ROM   # ScoreDrawRow
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F20E' $ROM   # ScrollOffsetRead
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F245' $ROM   # TextFill
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F26A' $ROM   # TextColLast
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F06A' $ROM   # HmoveApply
stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F2DA' $ROM   # OverscanStart
```

- **`$F186` (`StartFrame`)** is **259/3**, **`$F194` (`VblankStart`)** **0/5**, **`$F2A5` (`BodyStart`)** **37/5**, **`$F0B6` (`ScoreDraw`)** **37/11**, **`$F0C1` (`ScoreDrawRow`)** **37/26** (then 38/72 ... 44/72), and **`$F2DA` (`OverscanStart`)** **229/9**: 3 + 37 + 192 + 30 = 262 lines, and 229 - 37 = 192 visible lines. The starfield starts at **`$F2A8` (`StarStart`)** **46/5**, which is visible 9; 46 + 183 = 229.
- **`$F20E` (`ScrollOffsetRead`)** reports 0, 1, 1, 2, 2, 3, 3, ...: one pixel every two frames. It reaches `$58` (88) at frames 176-177 and 0 at frame 178, so the wrap is 88 -> 0.
- **`$F221` (`PhaseRead`)** reports `ScrollOffset & 7` and **`$F228` (`ByteIndexRead`)** reports `ScrollOffset >> 3`. At offset 0 they are 0/0; at offset 1 they are 1/0; at offset 40 they are 0/5; at offset 88 they are 0/11.
- **`$F245` (`TextFill`)** reports the first byte of each row: `$00, $88, $90, $A0, $F0, $88, $88, $F0` at offset 0. **`$F26A` (`TextColLast`)** reports the sixth column's bytes with `TextCol=5`: `$00, $70, $88, $88, $B8, $80, $88, $70`. The first sequence is R's rows 0-7; the second is G's rows 0-7. That is the fill at `ScoreBuf + c*8 + r` in the state log.
- **`$F06A` (`HmoveApply`)** is 18/45 and **`$F06C` (`HmoveDone`)** 19/3: one `HMOVE` per frame, in the HBLANK after the score setup.
- **`$F2C1` (`BallRow`)** is 46/38 on the first starfield line and advances one scanline per frame; **`$F21A` (`BallYRead`)** reports 0, 1, 2, ...; **`$F2D0` (`StarWait`)** reports 44 on a plain line and 51 on the ball's line (37 and 44 cycles of work, plus the `WSYNC` and the loop tail).
- **`$F1CB` (`FirePauseSet`)** reports A=0/1 after a new fire press (measured on a debug build with the startup guard bypassed; the committed ROM ignores a held button during its first eight frames); **`$F1ED` (`SelectReset`)** reports A=0 after SELECT. Under `-holdselect`, `SelectReset` fires at frame 1.

The pixel checks decode the captures with `capture x = 25 + 6 * TIA X` and `capture y = 107 + 3.15 * visible line`:

| Check | `marquee-a.png` | `marquee-b.png` | Expected |
|---|---|---|---|
| window | "RACING" | "G THE " | offset 0 / offset 40 |
| cell block | x=361-648 (six cells, left edges 361/409/457/505/553/601) | x=361-648 | TIA X=56-103 |
| lit glyphs | x=361-630, y=109-130 | x=361-582, y=109-130 | the 5x7 glyphs inside the block |
| shooting star | x=505-510, y=694-696 | x=505-510, y=226-228 | TIA X=80, one line |
| background | `$02` (63,63,62) | `$02` (63,63,62) | the dark field |
| text and stars | `$0E` (234,234,233) | `$0E` | white |
| shooting star | `$1A` (205,205,52) | `$1A` | gold |
| starfield | 183 lines below the text | 183 lines | visible 9-191 |

The screenshots prove the visual state; the state log proves the values and the clock. The thing a still cannot prove is the one-pixel scroll: `ScrollOffsetRead` proves the 0, 1, 1, 2, 2 sequence and the 88 -> 0 wrap. The two captures prove the window at two offsets and the shift between them.

## Exercises

### Exercise 1: Change the Message

**Challenge:** replace "RACING THE BEAM  " with **"KERNEL MASTERY"** (14 characters). The table must have 15 bytes per row (14 glyph bytes plus one zero pad), the phase block 8 x 15 = 120 bytes, and the wrap `14*8 - 48 = 64`.

**Hints:**
1. `MESSAGE_LEN` is the only length constant. `ROW_BYTES = MESSAGE_LEN + 1` and `PHASE_BYTES = 8 * ROW_BYTES` follow it; `SCROLL_MAX = MESSAGE_LEN*8 - 48` follows too.
2. The shifted table has 8 phases x 8 rows x 15 bytes = 960 bytes. Regenerate it from the font with the header's formula: `phase 0` is the glyph byte, `phase p` is `(a << p) | (b >> (8-p))`.
3. The fill's pointer advance changes from 18 to 15, and the phase pointer table changes from 144-byte blocks to 120-byte blocks.
4. The 14-character message includes K, E, R, N, L, M, A, S, T and Y; all are in the 39-glyph font.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `MESSAGE_LEN` is 14, `SCROLL_MAX` 64, and `ScrollOffset` runs 0..64. The state log shows 63 at frame 127, 64 at frames 128-129, then 0 at frame 130. At offset 0 the window reads "KERNEL"; at offset 64 it reads "ASTERY" and wraps. `OverscanStart` is still 229.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Double-Speed Scroll

**Challenge:** make the text move one pixel **per frame** instead of one pixel every two frames. `ScrollOffset` must advance 1, 2, 3, ... and still wrap 88 -> 0.

**Hints:**
1. The two-frame divider is `ScrollTimer` and `AND #$01`. Remove the divider (and the `ScrollTimer` byte) and increment `ScrollOffset` every frame.
2. Keep the wrap comparison `CMP #(SCROLL_MAX+1)` and the `LDA #0` at 88.
3. The pre-shifted table, the fill and the starfield do not change.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; `ScrollOffset` reads 1, 2, 3, ... on consecutive frames, reaches 88 at frame 88 and wraps to 0 at frame 89. The message moves at twice the base speed; `OverscanStart` is still 229.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: The Second Text Band *(Stretch Goal)*

**Challenge:** add a second nine-line text band at visible 96-104 with a different message. The frame becomes 9 + 84 + 3 + 9 + 87 = 192: the first band, the 84-line copy/star gap, the second `ScoreSetup`'s 3 lines, the second band, and the 87-line lower starfield. Refill `ScoreBuf` in the first gap, re-run `ScoreSetup` before the second `ScoreDraw`, and keep the two bands independent.

**Hints:**
1. The first gap is visible 9-92 (84 starfield lines) and visible 93-95 (the second `ScoreSetup`'s three `WSYNC`s). The first `ScoreDraw`'s cleanup clears VDEL, so the second band needs a fresh `ScoreSetup`.
2. The first 48 lines of the gap can copy the second window from a 48-byte table into `ScoreBuf` one byte per line, because the table is already in the score buffer's column-major order. The copy and the starfield stores fit: 45 (+3 WSYNC +7 tail = 55) cycles on a plain line, 52 (+3 +7 = 62) on the ball's line.
3. Clear `HMBL` after the first `HMOVE`: the second `HMOVE` re-applies every motion register, and the ball must not receive its fine offset twice.
4. The second `ScoreDraw` starts at visible 96 (scanline 133); the lower starfield is visible 105-191 (87 lines) and can read `StarPFx+87,Y` for a different star pattern.
5. The second message can be static. "SECOND LINE" gives the window "SECOND" at offset 0; the first band keeps scrolling.

**Expected Result:** the ROM assembles to exactly 4,096 bytes; the picture shows two nine-line bands (the first scrolling, the second reading "SECOND") with 84 lines between them (48 copy + 36 star) and 87 below. `ScoreDraw` hits at 37/11 and 133/31; `HmoveApply` at 18/45 and 132/45; `Star2Start` at 142/5; `TextCol2`/`TextRow2` are fixed labels (5/7), not copy witnesses; `OverscanStart` is 229. The total is 9 + 84 + 3 + 9 + 87 = 192 (171 starfield lines + 3 setup lines).

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **The 48-pixel window is six player copies.** P0 at 56 and P1 at 64 in three-copy close mode interleave into six 8-pixel cells at 56, 64, 72, 80, 88 and 96. The cell block is TIA X=56-103, the same block Lesson 39 used for six digits.
- ✅ **The font is a bottom-up 5x7 atlas in an 8x8 cell.** Byte 0 is the bottom row and is blank, bytes 1-7 are the lit rows, and bit 7 is the leftmost pixel. The lit block is seven scanlines; the right three bits of each cell stay clear.
- ✅ **Pre-shift, do not shift at runtime.** Eight phases x eight rows x 18 bytes = 1,152 ROM bytes. `Phase = offset & 7` and `ByteIndex = offset >> 3` select the window; a runtime shift would not fit the 37-line VBLANK.
- ✅ **The fill is a transpose.** The source is row-major (18 bytes per row); the destination is column-major (`ScoreBuf + c*8 + r`). The six `ScoreBuf+0/8/16/24/32/40,X` stores are 48 bytes, 8 rows x 6 columns.
- ✅ **The scroll is one pixel every two frames.** `ScrollTimer`'s low bit is the divider; the wrap is `MESSAGE_LEN*8 - 48` (88 for 17 characters, 64 for 14). SELECT resets; fire pauses and resumes.
- ✅ **The shooting star has a horizontal deadline.** The ball's enable must be latched before X=80, about cycle 49. The gold write completes at cycle 42 and the enable at 47; the clear on other lines completes at 43. The measured work is 37/44 cycles, 47/54 with the `WSYNC` and tail.
- ✅ **The frame and the budget stay exact.** Nine text lines plus 183 starfield lines = 192; one `HMOVE` per frame; 1,152 table bytes + 312 font bytes + 768 bytes of page-aligned star planes + the code fit in the 4K cartridge.

## What's Next

The marquee closes Part 7. [Lesson 56: Bankswitching — Beyond 4KB](/part8-advanced/56-bankswitching) opens Part 8 by breaking the 4K limit: F8 and F6 banking, hotspot addresses, and how to place the table and code in different banks when a program outgrows the single cartridge window.
