---
title: "Lesson 40: BCD Arithmetic — Scores That Make Sense"
description: "Three bytes hold six decimal digits: the 6502's decimal mode adds and subtracts them with a carry that walks from byte to byte. Lesson 40 builds the BCD counter — SED/CLD add and subtract paths, a command selector, a six-digit display rebuilt with ScoreSetDigit, and a monitor that shows the operation, the carry, and the low byte's bits."
prev:
  text: "Lesson 39: The Scoreboard — 48-Pixel Sprite Trick"
  link: "/part6-game-dev/39-scoreboard"
next:
  text: "Lesson 41: Game States — Title, Play, Game Over"
  link: "/part6-game-dev/41-game-states"
---

# Lesson 40: BCD Arithmetic — Scores That Make Sense

> **Part 6: Game Development** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 05 (addition and subtraction), Lesson 06 (the flags), Lesson 27 (joystick input), Lesson 35 (the audio registers), Lesson 39 (the 48-pixel score and `ScoreSetDigit`)
> **You will learn:** how BCD packs two decimal digits into one byte; how `SED`/`CLD` make `ADC` and `SBC` decimal; how one carry flag links three bytes; why `A=100` is a command selector, not a BCD addend; how to rebuild six display digits from three bytes; how the monitor shows the operation, the carry, and the low byte's bits
> **You will build:** "the BCD counter" — a three-byte BCD score, decimal ADD 1 and ADD 100 paths, a joystick/auto-demo operation bar, a red overflow cell, a low-byte bit strip, and three exercises: ADD 10, SUB 1, and the 009900 + 100 middle carry

## Introduction

Lesson 39 kept the score as six separate digits, and `ScoreAddOne` walked them from right to
left: increment a digit, wrap 9 to 0, carry left. That works for adding one, but a game soon
needs other amounts — a bonus of 100, a penalty of 1 — and a six-digit loop for every operation
is more code and more chances to get the carry wrong.

The 6502 has a better tool: **binary-coded decimal**, or BCD. A byte has two nibbles, and in
BCD each nibble holds one decimal digit — 0 through 9. A three-byte number therefore holds six
decimal digits, and the digit boundaries are already where the display wants them. The CPU's
**decimal mode** (`SED`) makes `ADC` and `SBC` work in decimal: the byte stays in `$00–$99`, and
the carry flag reports a carry or borrow from one pair of digits to the next. Three bytes and two
instructions replace the digit-by-digit loop.

This lesson builds **the BCD counter**. The score lives in three bytes. `BCDAdd` takes a command
selector: `A=1` adds one to the low byte, `A=100` adds one to the middle byte, and the carry
walks upward through the other bytes. The six display digits are rebuilt from the three bytes
with `ScoreSetDigit`, and `ScoreDraw` draws them in the same 48-pixel block Lesson 39 built. Below
the score, three 8-line monitor zones show the selected operation, the top carry, and the eight
bits of the low byte. The auto-demo runs ADD 1, then ADD 100, so the first two captures read
**000001** and **000101** with no input at all.

::: details TypeScript Equivalent
A BCD score is an array of three decimal bytes, and the carry is a loop. The important part is
that the *selector* names a byte, not an amount to add to the whole number:

```typescript
// Each byte holds a decimal value 0-99.  The 6502 stores that value as BCD:
// decimal 42 is 0x42, two nibbles, not 0x2A.
class BcdScore {
  private bytes = [0, 0, 0];          // low, middle, high

  addOne(): boolean { return this.add(0, 1); }
  addTen(): boolean { return this.add(0, 10); }
  addHundred(): boolean { return this.add(1, 1); }

  private add(index: number, amount: number): boolean {
    let carry = amount;
    for (let i = index; i < 3 && carry !== 0; i += 1) {
      const sum = this.bytes[i] + carry;
      this.bytes[i] = sum % 100;
      carry = Math.floor(sum / 100);   // the 6502's carry flag
    }
    return carry !== 0;                // 999999 -> 000000
  }

  subtractOne(): boolean {
    let borrow = 1;
    for (let i = 0; i < 3 && borrow !== 0; i += 1) {
      const difference = this.bytes[i] - borrow;
      this.bytes[i] = (difference + 100) % 100;
      borrow = difference < 0 ? 1 : 0;
    }
    return borrow !== 0;               // 000000 -> 999999
  }

  digits(): number[] {
    const [low, mid, high] = this.bytes;
    return [high, mid, low]
      .flatMap((b) => [Math.floor(b / 10), b % 10]);   // left to right
  }
}
```

The analogy breaks in three places. `addHundred` adds **1 to byte 1**, not 100 to byte 0 —
that is what the 6502 selector does, and it is the difference between 000042 + 100 = 000142 and
adding `$64` (BCD 64) to the low byte, which gives 000106. The 6502's decimal mode is a global CPU
flag: every `ADC`/`SBC` between `SED` and `CLD` is decimal, so the routine must restore binary
mode before it returns. And the display is still six columns of glyph bytes — BCD makes the
*number* easy to keep, not the picture easy to draw.
:::

## Theory

### Section 1: BCD — Two Decimal Digits in One Byte

A byte is eight bits. In binary it holds 0–255; in BCD it holds two decimal digits, one per
nibble. The high nibble is the left digit of the pair, the low nibble is the right digit:

| Hex byte | High nibble | Low nibble | Decimal value | Two digits |
|---|---|---|---|---|
| `$00` | 0 | 0 | 0 | 00 |
| `$09` | 0 | 9 | 9 | 09 |
| `$10` | 1 | 0 | 10 | 10 |
| `$42` | 4 | 2 | 42 | 42 |
| `$99` | 9 | 9 | 99 | 99 |

The pattern `$2A` would be 42 in binary, but it is not valid BCD: the low nibble `A` is not a
decimal digit. In BCD the byte **looks like** the two digits it displays. That is the whole
reason the 6502 has a decimal mode.

Three bytes hold six digits. This lesson stores them little-endian, so the least significant
pair comes first in memory:

| Symbol | Address | Digits (positions) | Example |
|---|---|---|---|
| `BCDScoreLow` | `$90` | 5 and 4 (the rightmost two) | `$42` means `…42` |
| `BCDScoreMid` | `$91` | 3 and 2 | `$01` means `…01…` |
| `BCDScoreHigh` | `$92` | 1 and 0 (the leftmost two) | `$00` means `00…` |

The score **000101** is therefore `BCDScoreHigh=$00`, `BCDScoreMid=$01`, `BCDScoreLow=$01`.
The score **009900** is `$00`, `$99`, `$00`. The score **999999** is `$99`, `$99`, `$99`.

::: tip Why not a binary number?
A six-digit score from 0 to 999999 needs 20 bits, and displaying it means dividing by 10 six
times — expensive on a 6502 and easy to get wrong. BCD spends 24 bits instead of 20 and keeps
the digits already separated. The cost is a little RAM; the gain is that the display code just
reads nibbles. Games that show a score almost always choose BCD.
:::

### Section 2: Decimal Mode — `SED`, `ADC`, `CLD`

`SED` sets the 6502's decimal flag (D). While D is set, `ADC` and `SBC` treat each byte as two
BCD digits: the result stays in `$00–$99`, and the carry flag means "this pair of digits carried
into the next pair". `CLD` clears D. On the 2600 the flag is global, so the rule is strict:

```text
SED          enter decimal mode
... ADC / SBC only ...
CLD          leave decimal mode before anything else
```

Every `BCDAdd` path that enters decimal mode restores binary mode with `CLD`; the A=10 and
`$FF` selectors return without touching D. The overflow path is reached *after* `CLD`, so even a
wrap restores binary mode before the next instruction.

The carry is the link between bytes. After the low byte's `ADC`, the carry flag holds 0 or 1.
The 6502 has no instruction that copies C into A, so the lesson uses a two-instruction idiom:

```asm
    LDA #0
    ADC #0          ; 0 + 0 + C = the carry, as a byte
```

In decimal mode this is still valid: `0 + 0 + 1 = 1`. The byte is saved, and the next byte's add
uses it explicitly:

```asm
    STA BCDCarryTmp
    LDA BCDScoreMid
    CLC
    ADC BCDCarryTmp
    STA BCDScoreMid
```

The `CLC` starts the next add with a clear carry; the carry we care about is now the byte in
`BCDCarryTmp`. The same three lines run again at the high byte. The checkpoints `BCDCarryMid`
and `BCDCarry` sit on those captures, so the debugger reports A = 0 or 1 at each byte boundary.

**Adding 1 to 000099** shows the chain:

| Step | Byte | Operation | Result | Carry |
|---|---|---|---|---|
| 1 | low `$99` | `+ $01` | `$00` | 1 |
| 2 | middle `$00` | `+ 1` | `$01` | 0 |
| 3 | high `$00` | `+ 0` | `$00` | 0 |

The score becomes **000100**. The carry did the work that `ScoreAddOne`'s digit loop did in
Lesson 39, but in three `ADC`s instead of a six-digit loop.

### Section 3: The Command Selector

`BCDAdd` takes a **command selector** in A, not a BCD addend:

| A | What changes | The addend actually added | Example |
|---|---|---|---|
| 1 | low byte | `$01` | 000042 → 000043 |
| 10 | low byte | `$10` | 000042 → 000052 |
| 100 | middle byte | `$01` | 000042 → 000142 |

The selector matters because **`$64` is BCD 64, not 100**. A single `ADC #$64` would add 64 to
the low byte. Instead, `A=100` says "the hundreds pair changes": add 1 to the middle byte and let
its carry reach the high byte. The table is the contract; the code is short:

```asm
BCDAdd:
    CMP #1
    BEQ BCDAddOne
    CMP #100
    BEQ BCDAddHundred
    RTS                     ; A=10 is the ADD 10 exercise's path
```

`BCDAddOne` adds `$01` to the low byte, captures the carry, adds it to the middle, captures the
middle's carry, and adds that to the high byte. `BCDAddHundred` adds `$01` to the middle byte and
jumps into the same high-byte code. Both paths end with `CLD` and a `BCS` to the overflow
handler.

A carry out of the high byte means the six-digit number passed 999999. The bytes hold the low
six digits of the sum: the canonical case, 999999 + 1, stores `$00,$00,$00` and the score reads
**000000**. `BCDOverflow` sets the `Overflow` flag, and the red carry cell lights on the monitor
until the next operation clears it.

### Section 4: Subtraction and the Borrow

`SBC` is the mirror image. It subtracts the **carry flag** as well as the operand, so `SEC` starts
a subtract with no borrow and each following `SBC #$00` subtracts the previous byte's borrow:

```asm
    SED
    SEC
    LDA BCDScoreLow
    SBC #$01
    STA BCDScoreLow
    LDA BCDScoreMid
    SBC #$00                ; subtract the borrow from the low byte
    STA BCDScoreMid
    LDA BCDScoreHigh
    SBC #$00                ; subtract the borrow from the middle byte
    STA BCDScoreHigh
    CLD
    BCC BCDBorrowHandler    ; C=0: the high byte borrowed
    RTS
BCDBorrowHandler:
    LDA #1
BCDBorrow:                  ; checkpoint: A = 1 on 000000 -> 999999
    STA Borrow
    RTS
```

From **000000**, the low byte does `$00 - $01 = $99` and borrows; the middle does
`$00 - $00 - 1 = $99` and borrows; the high does the same. The final carry is 0, so
`BCDBorrow` records the wrap and the score reads **999999**. The checkpoint sits after `LDA #1`,
so the debugger reports A=1. The subtract is the exercise subject; the main ROM implements only
the adds.

### Section 5: From Three Bytes to Six Digits

The display is rebuilt from the BCD bytes, not from a separate digit array. `BCDToDigits` reads
each byte twice: once for the high nibble, once for the low nibble, and calls `ScoreSetDigit`
with the position and the digit:

| BCD byte | High nibble → position | Low nibble → position |
|---|---|---|
| `BCDScoreHigh` | 0 | 1 |
| `BCDScoreMid` | 2 | 3 |
| `BCDScoreLow` | 4 | 5 |

`ScoreSetDigit` (from `include/score.asm`) stores the digit and copies all eight bytes of its
glyph into `ScoreBuf`; `ScoreDraw` draws the eight rows in the 9-line score zone. The library's
`ScoreDigits` array is only a display cache here — the **BCD bytes are the source of truth**.
Every operation ends with `BCDToDigits`, so the picture always matches the number.

The strip below the score is the same idea at a smaller scale. It sets `PF2 = BCDScoreLow`, and
PF2's eight chunks are the eight bits of the low byte. Bit 0 is the leftmost cell, bit 7 the
rightmost; four cells are the low nibble (position 5) and four are the high nibble (position 4).
As the low byte increments, its bits change; a decimal carry changes several cells at once —
`$01` to `$02` clears bit 0 and sets bit 1, `$09` to `$10` clears bits 0 and 3 and sets bit 4,
and `$99` to `$00` clears all eight. That makes the BCD structure visible without a debugger.

### Section 6: The Frame and the Monitor

The frame is the course standard: 3 VSYNC + 37 VBLANK + 192 picture + 30 overscan = **262
lines**. The picture is split into four monitor zones and a background:

```text
  9  score (visible 0-8; the 48-pixel kernel)
  8  operation bar (visible 9-16)
  8  carry cell (visible 17-24)
  8  low-byte bit strip (visible 25-32)
159  background (visible 33-191)
---
192
```

`CTRLPF=$01` reflects the playfield, so every zone appears twice — left and right — and the
counts in this lesson are always **per half**. The bar's four cells are 16 TIA pixels wide in
chunks 2–17:

| Slot | Operation | Chunks | TIA X | PF0 | PF1 | PF2 |
|---|---|---|---|---|---|---|
| 0 | ADD 1 | 2–5 | 8–23 | `$C0` | `$C0` | `$00` |
| 1 | ADD 10 | 6–9 | 24–39 | `$00` | `$3C` | `$00` |
| 2 | ADD 100 | 10–13 | 40–55 | `$00` | `$03` | `$03` |
| 3 | SUB 1 | 14–17 | 56–71 | `$00` | `$00` | `$3C` |

Only the selected slot is drawn, in gold `$1A`; the other three are background. In the main ROM
`OpMask=%00000101` enables slots 0 and 2, so the ADD 10 and SUB 1 cells never light. The carry
cell is `PF2=$FF` — chunks 12–19, which with the mirror is TIA X=48–111 — in red `$42`, but only
on the operation that carried out of the high byte. The strip is `PF2=BCDScoreLow` in green
`$C8`, the same 64-pixel center band.

The playfield bytes for a zone are written at the start of the zone's first line. The score
kernel's `RTS` starts at line 8, cycle 75, and the caller resumes at **line 9, cycle 5**. The
three bar stores take effect at color clocks ~36 (PF0), ~54 (PF1), and ~69 (PF2); PF2 is about
one color clock past the end of HBLANK, but all three stores land before their left slots start
(PF0/PF1/PF2 at clocks 68/84/116), so visible line 9 is clean. The same early-in-the-line pattern
holds at the 17, 25, and 33 boundaries. Each zone then holds its eight lines with `STA WSYNC` and
a counter.

The auto-demo runs while no button is held. Every 60 frames it executes one operation, then
steps to the next enabled slot; the **first** tick executes the slot that is already selected,
so the score and the lit cell describe the same operation between ticks:

| Tick | Operation | Score | Lit slot |
|---|---|---|---|
| 1 | ADD 1 | 000001 | ADD 1 |
| 2 | ADD 100 | 000101 | ADD 100 |
| 3 | ADD 1 | 000102 | ADD 1 |
| 4 | ADD 100 | 000202 | ADD 100 |

The joystick's up/down directions step the selection (up = previous, down = next) and fire
executes the selected operation once. Any input resets the demo timer, so the demo waits a full
second after the last press before taking over again.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson40.bin \
  lessons/part6-game-dev/40-bcd-arithmetic/40-bcd-arithmetic.asm
stella build/lesson40.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

The shared score library lives in `include/score.asm`; the lesson source sources it after
`include/vcs.asm` and `include/macro.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 40: BCD Arithmetic — Scores That Make Sense — Racing the Beam
; =============================================================================
; Part 6: Game Development
;
; What this program does:
;   "the BCD counter": a six-digit score kept in three BCD bytes instead of
;   six separate digits.  The 6502's decimal mode does the carry for us:
;   SED, CLC, ADC, then CLD restores binary mode before any other code runs.
;
;   A three-byte score is a little-endian BCD number:
;
;     BCDScoreLow   $00-$99   positions 5 and 4 (the rightmost two)
;     BCDScoreMid   $00-$99   positions 3 and 2
;     BCDScoreHigh  $00-$99   positions 1 and 0 (the leftmost two)
;
;   Each byte holds two decimal digits, one per nibble: the high nibble is
;   the left digit of the pair and the low nibble is the right digit.  The
;   number 42 is $42, not $2A.  That is the whole trick: the byte looks like
;   the two digits it displays.
;
; The operations:
;   BCDAdd takes a COMMAND SELECTOR in A, not a BCD addend:
;     A=1    add 1 to the low byte, carry through the other two
;     A=10   add $10 to the low byte  (the ADD 10 exercise)
;     A=100  add 1 to the middle byte, carry into the high byte
;   A=100 is a selector because $64 is BCD 64, not 100.  The selector says
;   WHICH byte changes; the code adds 1 (or $10) to that byte.
;
;   The main ROM implements ADD 1 and ADD 100.  ADD 10 and SUB 1 are the
;   exercise subjects, so their operation-bar cells stay dark here: OpMask
;   names the operations this build can run, and the selector walks only
;   through those bits.
;
; The top carry and the borrow:
;   A carry out of the high byte means the sum passed 999999.  The bytes
;   wrap in decimal mode.  The canonical case, 999999 + 1, stores 000000.
;   BCDOverflow sets the Overflow flag, and the carry cell (visible 17-24)
;   turns red until the next operation clears it.
;   A borrow out of the high byte means 000000 -> 999999; a subtract
;   exercise wraps the other way.
;
; The display:
;   BCDToDigits rebuilds the six columns from the three BCD bytes: low byte
;   -> digits 5/4, middle -> 3/2, high -> 1/0.  Each nibble is one digit,
;   and ScoreSetDigit copies its eight-byte glyph into ScoreBuf.  ScoreDraw
;   then draws the 9-line 48-pixel score at the top of the frame.  The
;   library's ScoreDigits array is only a display cache here; the BCD bytes
;   are the source of truth.
;
; The screen (192 visible lines):
;   visible 0-8     the score, 9 lines (ScoreDraw: 1 setup + 8 rows)
;   visible 9-16    the operation bar: four cells (ADD 1, ADD 10, ADD 100,
;                   SUB 1), chunks 2-17, the selected one bright gold
;   visible 17-24   the carry cell: a red center block when Overflow is set
;   visible 25-32   the low-byte bit strip: PF2 = BCDScoreLow, so its eight
;                   chunks are the eight bits of the low byte
;   visible 33-191  background (159 lines)
;   CTRLPF=$01 mirrors the playfield, so the bar, cell and strip appear on
;   both halves; counts are always per half.
;
; Input and the auto-demo:
;   Joystick up/down selects the operation (up = previous, down = next);
;   fire executes the selected one.  With no input the ROM runs the demo:
;   every 60 frames it executes the selected operation and steps to the next
;   enabled one, so the first two operations read 000001 and 000101.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), BCDAdd (A = the command selector),
;   BCDCarryMid (A = the carry into the middle byte), BCDCarry (A = the
;   carry into the high byte), BCDOverflow, Overflow (the flag at $86),
;   BCDScoreLow/Mid/High (the three BCD bytes), ScoreDigitWrite (A =
;   position, X = digit), BodyStart (37), ScoreDraw (the call),
;   HmoveApply/HmoveDone (once per frame), OverscanStart (229).
;
; Build: acme -f plain -o build/lesson40.bin \
;        lessons/part6-game-dev/40-bcd-arithmetic/40-bcd-arithmetic.asm
; Run:   stella build/lesson40.bin     (click the screen to hear the beep)
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36

DEMO_FRAMES    = 60      ; frames per auto-demo operation (about one second)
BEEP_FRAMES    = 8
BEEP_PITCH     = $0A     ; AUDF 10 on AUDC $0C: a short, bright beep

OP_ADD1        = 0
OP_ADD10       = 1
OP_ADD100      = 2
OP_SUB1        = 3
OPMASK_MAIN    = %00000101   ; ADD 1 and ADD 100; bits 1 and 3 are exercises

C_WHITE        = $0E
C_GOLD         = $1A
C_RED          = $42
C_GREEN        = $C8
C_BG           = $02

; --- Lesson variables (RAM $80-$9F; +clean_start zeroes them) ---
Operation    = $80   ; 0=ADD1, 1=ADD10, 2=ADD100, 3=SUB1
DemoTimer    = $81   ; frames until the next auto-demo operation
DemoStarted  = $82   ; 0 until the first demo operation has run
Buttons      = $83   ; bit 0=up, bit 1=down, bit 2=fire (1 = pressed)
PrevButtons  = $84   ; the previous frame's Buttons
NewPress     = $85   ; Buttons & ~PrevButtons: the 0 -> 1 edges
Overflow     = $86   ; 1 after the sum passes 999999 (the top carry)
OverflowPF   = $87   ; $FF when Overflow, $00 otherwise (the red cell)
BeepTimer    = $88   ; frames of beep remaining
BeepPitch    = $89   ; AUDF for the beep
BCDCarryTmp  = $8A   ; the 0/1 carry saved across one byte's add
BarPF0       = $8B   ; the operation bar's playfield bytes for this frame
BarPF1       = $8C
BarPF2       = $8D
OpMask       = $8E   ; bits of the operations this build implements

; --- The BCD score: three bytes, two decimal digits each ---
BCDScoreLow  = $90   ; positions 5/4: high nibble = position 4, low = 5
BCDScoreMid  = $91   ; positions 3/2
BCDScoreHigh = $92   ; positions 1/0
;
; The score library owns $A0-$D7:
;   ScoreDigits $A0-$A5, ScoreRow $A6, ScoreTmp $A7, ScoreBuf $A8-$D7.

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start

    LDA #$00
    STA SWACNT              ; port A is an input port (the joysticks)

; --- the score starts at 000000; BCDScore is zero from +clean_start ---
    JSR ScoreInit           ; zero the six digits and the 48-byte buffer
    JSR BCDToDigits         ; build six zero glyphs from the zero BCD bytes

; --- the demo starts on ADD 1 ---
    LDA #OP_ADD1
    STA Operation
    LDA #OPMASK_MAIN        ; only ADD 1 and ADD 100 are implemented here
    STA OpMask
    LDA #DEMO_FRAMES
    STA DemoTimer
    LDA #BEEP_PITCH
    STA BeepPitch

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
; 1. THE BEEP'S CLOCK — the last frame writes silence
; -----------------------------------------------------------------------------
    LDA BeepTimer
    BEQ BeepDone
    DEC BeepTimer
    BNE BeepDone
    LDA #$00
    STA AUDV0
BeepDone:

; -----------------------------------------------------------------------------
; 2. READ THE JOYSTICK — up, down, and fire as 0 -> 1 edges
; -----------------------------------------------------------------------------
; SWCHA bits 4/5 are P0 up/down (0 = pressed).  EOR flips them to 1 =
; pressed, and four LSRs move them to bits 0/1.  INPT4 bit 7 is 0 while fire
; is held, so it becomes bit 2.  NewPress keeps only the bits that changed
; from 0 to 1, so holding a direction makes exactly one step.
    LDA SWCHA
    AND #$30                ; P0 up (bit 4) and down (bit 5)
    EOR #$30                ; 1 = pressed
    LSR
    LSR
    LSR
    LSR                     ; bit 0 = up, bit 1 = down
    STA Buttons
    LDA INPT4
    AND #$80
    BNE ReadDone            ; bit 7 = 1: fire is released
    LDA Buttons
    ORA #$04                ; bit 2 = fire pressed
    STA Buttons
ReadDone:
    LDA Buttons
    EOR PrevButtons
    AND Buttons             ; new presses only: Buttons & ~PrevButtons
    STA NewPress
    LDA Buttons
    STA PrevButtons

; -----------------------------------------------------------------------------
; 3. FIRE EXECUTES THE SELECTED OPERATION
; -----------------------------------------------------------------------------
    LDA NewPress
    AND #$04
    BEQ NoFireEdge
    JSR ExecuteOperation    ; one operation per press
NoFireEdge:

; -----------------------------------------------------------------------------
; 4. UP/DOWN SELECT THE OPERATION (UP = PREVIOUS, DOWN = NEXT)
; -----------------------------------------------------------------------------
    LDA NewPress
    AND #$01
    BEQ NoUpEdge
    JSR PreviousOperation
NoUpEdge:
    LDA NewPress
    AND #$02
    BEQ NoDownEdge
    JSR NextOperation
NoDownEdge:

; -----------------------------------------------------------------------------
; 5. THE AUTO-DEMO — run only while no button is held
; -----------------------------------------------------------------------------
; The first tick executes the operation that is already selected; every
; later tick steps to the next enabled operation and executes that.  The
; score and the lit cell therefore describe the same operation between
; ticks: 000001 with ADD 1 lit, then 000101 with ADD 100 lit.
    LDA Buttons
    BNE ResetDemo
    DEC DemoTimer
    BNE DemoDone
    LDA DemoStarted
    BEQ DemoFirst
    JSR NextOperation
DemoFirst:
    JSR ExecuteOperation
    LDA #1
    STA DemoStarted
    LDA #DEMO_FRAMES
    STA DemoTimer
    JMP DemoDone
ResetDemo:
    LDA #DEMO_FRAMES        ; any input pauses the demo for another second
    STA DemoTimer
DemoDone:

; -----------------------------------------------------------------------------
; 6. TURN THE STATE INTO PLAYFIELD BYTES FOR THE MONITOR ZONES
; -----------------------------------------------------------------------------
; The operation bar is four 16-pixel cells in chunks 2-17 (TIA X=8-71):
;   ADD 1    chunks 2-5    PF0=$C0           PF1=$C0           PF2=$00
;   ADD 10   chunks 6-9    PF0=$00           PF1=$3C           PF2=$00
;   ADD 100  chunks 10-13  PF0=$00           PF1=$03           PF2=$03
;   SUB 1    chunks 14-17  PF0=$00           PF1=$00           PF2=$3C
    LDX Operation
    LDA BarTab0,X
    STA BarPF0
    LDA BarTab1,X
    STA BarPF1
    LDA BarTab2,X
    STA BarPF2

    LDX Overflow
    LDA OverflowTab,X
    STA OverflowPF

; -----------------------------------------------------------------------------
; 7. POSITION THE SCORE — both players and ONE HMOVE
; -----------------------------------------------------------------------------
; ScoreSetup sets NUSIZ0/NUSIZ1=3, turns VDEL on, positions P0 at 56 and
; P1 at 64, and strobes the frame's only HMOVE.
    JSR ScoreSetup

; -----------------------------------------------------------------------------
; 8. COLORS AND PLAYFIELD CONTROL
; -----------------------------------------------------------------------------
    LDA #C_WHITE
    STA COLUP0              ; the score is white
    STA COLUP1
    LDA #C_GOLD
    STA COLUPF              ; the operation bar is gold (set again per zone)
    LDA #C_BG
    STA COLUBK
    LDA #$00
    STA PF0
    STA PF1
    STA PF2
    STA ENABL               ; no ball in this lesson
    LDA #$01
    STA CTRLPF              ; reflect the playfield; per-half counts

    +wait_timer

; =============================================================================
; VISIBLE — 192 lines: score (9) + bar (8) + carry (8) + strip (8) + 159
; =============================================================================
    LDA #$00
    STA VBLANK

BodyStart:                  ; checkpoint: scanline 37, visible line 0
    JSR ScoreDraw           ; 9 lines: line 0 setup, lines 1-8 rows

; -----------------------------------------------------------------------------
; VISIBLE 9-16: THE OPERATION BAR — one bright cell per half
; -----------------------------------------------------------------------------
; The caller resumes at line 9, cycle 5; the stores take effect at clocks
; ~36 (PF0), ~54 (PF1) and ~69 (PF2).  All three land before their left
; slots (68/84/116), so line 9 shows the new bytes for its whole width.
    LDA BarPF0
    STA PF0
    LDA BarPF1
    STA PF1
    LDA BarPF2
    STA PF2
    LDY #8
BarLines:
    STA WSYNC
    DEY
    BNE BarLines

; -----------------------------------------------------------------------------
; VISIBLE 17-24: THE CARRY CELL — a red center block on overflow
; -----------------------------------------------------------------------------
; PF2=$FF is chunks 12-19 (X=48-79); with the mirrored right half the block
; fills X=48-111, a 64-pixel bar across the center.  It is dark (PF2=$00)
; except on the operation that carried out of the high byte.
    LDA #C_RED
    STA COLUPF
    LDA #$00
    STA PF0
    STA PF1
    LDA OverflowPF
    STA PF2
    LDY #8
CarryLines:
    STA WSYNC
    DEY
    BNE CarryLines

; -----------------------------------------------------------------------------
; VISIBLE 25-32: THE LOW-BYTE BIT STRIP — PF2 = BCDScoreLow
; -----------------------------------------------------------------------------
; PF2's eight chunks are the eight bits of the low byte, one 4-pixel cell
; each: bit 0 is the leftmost cell, bit 7 the rightmost.  Four cells show
; the low nibble (digit 5) and four show the high nibble (digit 4).
    LDA #C_GREEN
    STA COLUPF
    LDA BCDScoreLow
    STA PF2
    LDY #8
StripLines:
    STA WSYNC
    DEY
    BNE StripLines

; -----------------------------------------------------------------------------
; VISIBLE 33-191: BACKGROUND — 159 lines
; -----------------------------------------------------------------------------
    LDA #$00
    STA PF2
    LDY #(192 - 33)
BackgroundLines:
    STA WSYNC
    DEY
    BNE BackgroundLines

; -----------------------------------------------------------------------------
; OVERSCAN — 30 lines
; -----------------------------------------------------------------------------
OverscanStart:              ; checkpoint: scanline 229
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; EXECUTE OPERATION — run the selected op, rebuild the display, beep
; =============================================================================
; Clearing Overflow first means the red cell reports the operation that just
; ran and goes dark on the next one.
ExecuteOperation:
    LDA #$00
    STA Overflow
    LDX Operation
    LDA OpCommand,X
    JSR BCDAdd
    JSR BCDToDigits
    JSR BeepStart
    RTS

; The command selector for each operation.  A=$FF is the SUB 1 slot, which
; this build never selects (OpMask has its bit clear).
OpCommand:
    !byte 1, 10, 100, $FF

; =============================================================================
; BCDAdd — A = the command selector
; =============================================================================
; The selector names the byte to change; it is not a BCD addend:
;   A=1    low += 1
;   A=10   low += $10
;   A=100  mid += 1
; Every path that enters decimal mode restores binary mode with CLD; the
; A=10 and A=$FF selectors return without touching D.  BCDAdd returns the
; top carry as the Overflow flag.
BCDAdd:                     ; checkpoint: A = the command selector
    CMP #1
    BEQ BCDAddOne
    CMP #100
    BEQ BCDAddHundred
    RTS                     ; A=10 is the ADD 10 exercise's path

; --- ADD 1: low += 1, then carry into the middle and the high byte ----------
BCDAddOne:
    SED                     ; decimal mode: ADC keeps each byte in 00-99
    CLC
    LDA BCDScoreLow
    ADC #$01
    STA BCDScoreLow
    LDA #0
    ADC #0                  ; 0 + 0 + C = the carry into the middle byte
BCDCarryMid:                ; checkpoint: A = the carry into the middle byte
    STA BCDCarryTmp
    LDA BCDScoreMid
    CLC
    ADC BCDCarryTmp
    STA BCDScoreMid
    JMP BCDAddHigh          ; the middle's carry is in C

; --- ADD 100: mid += 1, then carry into the high byte -----------------------
BCDAddHundred:
    SED
    CLC
    LDA BCDScoreMid
    ADC #$01
    STA BCDScoreMid
    ; fall through with the middle's carry in C

; --- finish at the high byte and report the top carry -----------------------
BCDAddHigh:
    LDA #0
    ADC #0                  ; 0 + 0 + C = the carry into the high byte
BCDCarry:                   ; checkpoint: A = the carry into the high byte
    STA BCDCarryTmp
    LDA BCDScoreHigh
    CLC
    ADC BCDCarryTmp
    STA BCDScoreHigh
    CLD                     ; back to binary before any other code runs
    BCS BCDOverflow         ; C=1: the high byte carried out
    RTS
BCDOverflow:                ; checkpoint: the sum passed 999999
    LDA #1
    STA Overflow
    RTS

; =============================================================================
; BCDToDigits — rebuild the six score columns from the three BCD bytes
; =============================================================================
; ScoreSetDigit wants A = position (0 = leftmost) and X = digit 0-9, so each
; byte contributes two calls: high nibble first, then low nibble.  The low
; byte is the rightmost pair, the middle byte the middle pair, and the high
; byte the leftmost pair.
BCDToDigits:
    LDA BCDScoreHigh
    LSR                     ; move the high nibble down to bits 0-3
    LSR
    LSR
    LSR
    TAX
    LDA #0
    JSR ScoreSetDigit       ; position 0 = the high byte's high nibble
    LDA BCDScoreHigh
    AND #$0F
    TAX
    LDA #1
    JSR ScoreSetDigit       ; position 1 = the high byte's low nibble
    LDA BCDScoreMid
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA #2
    JSR ScoreSetDigit       ; position 2 = the middle byte's high nibble
    LDA BCDScoreMid
    AND #$0F
    TAX
    LDA #3
    JSR ScoreSetDigit       ; position 3 = the middle byte's low nibble
    LDA BCDScoreLow
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA #4
    JSR ScoreSetDigit       ; position 4 = the low byte's high nibble
    LDA BCDScoreLow
    AND #$0F
    TAX
    LDA #5
    JSR ScoreSetDigit       ; position 5 = the low byte's low nibble
    RTS

; =============================================================================
; OPERATION SELECTION — walk to the next/previous enabled operation
; =============================================================================
; BitTable maps an operation index to its bit in OpMask.  The walk skips
; disabled operations, which is why an exercise can enable ADD 10 or SUB 1
; by setting one mask bit: the bar table already has a cell for every slot.
BitTable:
    !byte $01, $02, $04, $08

NextOperation:
    LDX Operation
NextLoop:
    INX
    CPX #4
    BNE NextCheck
    LDX #0
NextCheck:
    LDA BitTable,X
    AND OpMask
    BEQ NextLoop
    STX Operation
    RTS

PreviousOperation:
    LDX Operation
PrevLoop:
    DEX
    BPL PrevCheck
    LDX #3
PrevCheck:
    LDA BitTable,X
    AND OpMask
    BEQ PrevLoop
    STX Operation
    RTS

; =============================================================================
; THE OPERATION BAR TABLE — three playfield bytes per slot
; =============================================================================
; Four 16-pixel cells in chunks 2-17, one 8-line row.  The mirrored right
; half repeats them, so the bar reads left to right on the left half and
; right to left on the right half.
BarTab0:
    !byte $C0, $00, $00, $00
BarTab1:
    !byte $C0, $3C, $03, $00
BarTab2:
    !byte $00, $00, $03, $3C

; The carry cell is either fully dark or the $FF center block.
OverflowTab:
    !byte $00, $FF

; =============================================================================
; BEEP — two bytes: BeepTimer and BeepPitch
; =============================================================================
BeepStart:
    LDA #BEEP_FRAMES
    STA BeepTimer
    LDA #$0C                ; AUDC 0C: the div-6 tone from Lesson 35
    STA AUDC0
    LDA BeepPitch
    STA AUDF0
    LDA #$0A
    STA AUDV0
    RTS

; =============================================================================
; THE SHARED SCORE LIBRARY (include/score.asm)
; =============================================================================
; ScoreInit, ScoreClear, ScoreSetup, ScoreSetDigit, ScoreAddOne, ScoreDraw,
; and ScoreFont live here.  The library must be sourced inside the ROM area
; (after * = $F000) and after include/vcs.asm.
    !source "include/score.asm"

; =============================================================================
; VECTORS
; =============================================================================
    * = $FFFA
    !word Reset     ; NMI
    !word Reset     ; RESET
    !word Reset     ; IRQ
```

<!-- END-FULL-SOURCE -->

> The complete, fully-commented lesson source lives in
> `lessons/part6-game-dev/40-bcd-arithmetic/40-bcd-arithmetic.asm`. The shared library lives in
> `include/score.asm`.

### Code Walkthrough

#### Step 1 — Reset: three zero bytes and six zero glyphs

`+clean_start` zeroes TIA and RAM, so the three BCD bytes at `$90–$92` start at zero. `ScoreInit`
clears the library's digit cache and 48-byte buffer; `BCDToDigits` then builds the six zero
columns from the zero bytes. The display reads **000000** before the first frame.

The reset also seeds the demo: `Operation=OP_ADD1`, `OpMask=%00000101`, `DemoTimer=60`, and
`BeepPitch=$0A`. There is no separate `ScoreClear` call: the display is always built from the
BCD score.

#### Step 2 — VBLANK: input edges, the demo clock, and the bytes for the monitor

The VBLANK work is a fixed order:

1. **The beep clock.** `BeepTimer` counts down; at zero the program writes `AUDV0=0`.
2. **The joystick read.** `SWCHA` bits 4/5 are P0 up/down (0 = pressed); `EOR #$30` flips them to
   1 = pressed and four `LSR`s move them to bits 0/1. `INPT4` bit 7 is 0 while fire is held, so
   it becomes bit 2. `NewPress = Buttons & ~PrevButtons`, which turns a held direction into one
   step.
3. **The actions.** A fire edge calls `ExecuteOperation`; an up edge calls `PreviousOperation`;
   a down edge calls `NextOperation`.
4. **The demo.** With no button held, `DemoTimer` counts down. At zero the first tick executes
   the selected operation; every later tick steps first, then executes. `DemoStarted` remembers
   whether the first tick has happened.
5. **The monitor bytes.** `Operation` indexes three 4-byte tables (`BarTab0/1/2`) to produce the
   bar's PF bytes; `Overflow` indexes a 2-byte table for the carry cell's PF2. Doing this in
   VBLANK keeps the kernel's line-9 writes short.
6. **Positioning and colors.** `ScoreSetup` sets `NUSIZ`/`VDEL`, positions P0/P1 and strokes the
   frame's only `HMOVE`; `COLUP0`/`COLUP1` are white, `COLUPF` is gold, `COLUBK` is `$02`, and
   `CTRLPF=$01`.

`+wait_timer` then anchors the visible section at scanline 37.

#### Step 3 — `BCDAdd`: the selector and the carry chain

`BCDAdd` compares A with 1 and 100. The ADD 1 path enters decimal mode, clears the carry, adds
`$01` to the low byte, and captures the carry with `LDA #0; ADC #0`. It saves that byte, adds it
to the middle byte with a fresh `CLC`, and jumps to the high-byte code. The ADD 100 path adds
`$01` to the middle byte and falls into the same high-byte code. The high step captures its own
carry, adds it to the high byte, runs `CLD`, and branches to `BCDOverflow` if the high byte
carried out.

The `BCDCarryMid` checkpoint sits on the middle capture on the ADD 1/ADD 10 path; the ADD 100
path jumps straight to `BCDAddHigh` with the middle's carry in C. `BCDCarry` sits on the high
capture, so a debugger logs A = 0 or 1 at each boundary. `BCDOverflow` is the top-carry path (the
canonical 999999 + 1 → 000000).

#### Step 4 — `BCDToDigits`: three bytes become six columns

The routine reads the high byte twice, the middle twice, and the low twice. For each nibble it
shifts or masks the byte into X, puts the position in A, and calls `ScoreSetDigit`. The order is
high byte first (positions 0 and 1), then middle (2 and 3), then low (4 and 5), so the columns
are rebuilt left to right. Six calls, each copying eight glyph bytes, and `ScoreBuf` is again the
picture of the number.

#### Step 5 — The monitor kernel

`BodyStart` is scanline 37, visible line 0. `JSR ScoreDraw` consumes the nine score lines and
returns at visible line 9. The kernel then:

- writes the bar's three PF bytes at line 9, cycle 5 (stores at clocks ~36/54/69, all before the
  left slots at 68/84/116) and holds eight `WSYNC`s (visible 9–16);
- switches `COLUPF` to red, clears PF0/PF1, writes the overflow PF2, and holds eight lines
  (visible 17–24);
- switches to green, writes `BCDScoreLow` to PF2, and holds eight lines (visible 25–32);
- clears PF2 and runs 159 `WSYNC`s (visible 33–191).

The next instruction is `OverscanStart` at scanline 229. The zone arithmetic is
9 + 8 + 8 + 8 + 159 = 192. The carry cell and strip need no sprites, so the players remain free
for the score and the frame has exactly one `HMOVE`.

#### Step 6 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F029` | **259, cycle 3** | the first VSYNC line of a 262-line frame |
| `VblankStart` | `$F037` | 0, cycle 5 | the first VBLANK line |
| `BCDAdd` | `$F15E` | frame 61 A=`$01`; 121 A=`$64`; 181 A=`$01` | the command selector |
| `BCDCarryMid` | `$F173` | A=0 for the main's small adds; a 000099 scratch build reports A=1 | the carry into the middle byte |
| `BCDCarry` | `$F18B` | A=0 in the main; exercise 3 reports A=1 | the carry into the high byte |
| `BCDOverflow` | `$F198` | the 999999 scratch build hits it at frame 61 | the top carry |
| `Overflow` | `$86` | 0 normally; 1 after the top carry | the red-cell flag |
| `BCDScoreLow` | `$90` | 0 → 1 (frame 61), 1 (121), 2 (181) | the low BCD byte |
| `BCDScoreMid` | `$91` | 0 (61), 1 (121), 1 (181) | the middle BCD byte |
| `BCDScoreHigh` | `$92` | 0 throughout the small adds | the high BCD byte |
| `ScoreDigitWrite` | `$F294` | six calls per operation; reset A=0…5, X=0; frame 61 A=0…5, X=`0,0,0,0,0,1` | position and digit |
| `BodyStart` | `$F0EF` | **37, cycle 5** | visible line 0 |
| `ScoreDraw` | `$F2DD` | 37, cycle 11 | the score kernel call |
| `ScoreDrawRow` | `$F2E8` | first break 37/26; stores at scanline 38 with A=`$3C,$66,$6E,$76…` | the top rows of the zero glyph |
| `HmoveApply` | `$F291` | hit at **4/45**: the `WSYNC` stall; the `STA HMOVE` executes at **5/0** | the one `HMOVE` store |
| `HmoveDone` | `$F293` | **5/3**, after the `STA HMOVE` | the store has completed |
| `OverscanStart` | `$F134` | **229, cycle 4** | overscan's first line |

The BCD byte values are read at the `LDA BCDScore…` sites inside `BCDToDigits`; the
`ScoreDigitWrite` log is the decoded confirmation. The carry checkpoints are 0 for the small
numbers the demo reaches quickly, so the document also cites two scratch builds: one preset to
000099 (low-byte carry) and one preset to 999999 (top carry). Those builds are probes, not
committed artifacts; the exercise 3 solution is the committed way to see a middle carry.

## What You Should See

The monitor is a dark field with four horizontal zones. At the top, the white six-digit score
sits in the same 48-pixel block Lesson 39 built: capture x=367–642, y=110–130. Below it, the
gold operation bar shows one 16-pixel cell per half, 8 lines tall at y=135–158. The red carry
cell is dark unless the high byte carries out. The green bit strip is the 64-pixel center band
at y=186–209: eight 4-pixel cells per half, the eight bits of the low byte.

**000001.** After the first auto-demo operation, the score reads **000001** and the ADD 1 cell
is lit. In this capture the left ADD 1 cell is at capture x=73–168 and its mirror at x=841–936;
the strip shows bit 0 with a green cell at x=313–336 and its mirror at x=673–696. The carry cell
is dark.

![Stella running the Lesson 40 ROM after one ADD 1: the white six-digit score reads 000001, the gold ADD 1 cell is lit at the left, and the green low-byte strip shows bit 0](/images/lesson40/add1.png)

*The first operation: 000001, ADD 1 selected. The strip's single green cell is bit 0 of the low
byte (`BCDScoreLow=$01`). Captured from the committed ROM.*

**000101.** One operation later the score reads **000101** and the ADD 100 cell is lit. The
score's fourth digit changed from 0 to 1 (position 3), and the bar's cell moved to slot 2:
capture x=265–360 on the left and x=649–744 on the right. The strip still shows bit 0, because
the low byte is still `$01`; the middle byte is the one that changed.

![Stella running the Lesson 40 ROM after ADD 100: the six-digit score reads 000101, the gold ADD 100 cell (slot 2) is lit, and the strip still shows bit 0](/images/lesson40/add100.png)

*The second operation: 000101, ADD 100 selected. The middle byte changed from `$00` to `$01`,
which is position 3; the low byte and the strip did not change. Captured from the committed ROM.*

<RomPlayer rom="/roms/part6-game-dev/40-bcd-arithmetic/40-bcd-arithmetic.bin" title="Lesson 40 — BCD Arithmetic" />

Click the player screen once: Javatari starts muted until a user gesture, and the operation beep
begins when you click. The demo runs ADD 1 and ADD 100 on its own; hold up or down to choose an
operation and press fire to run it.

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson40.sym -o build/lesson40.bin \
  lessons/part6-game-dev/40-bcd-arithmetic/40-bcd-arithmetic.asm
grep -E "StartFrame|BCDAdd|BCDCarry|BCDScore|ScoreDigitWrite|BodyStart|HmoveDone|OverscanStart" build/lesson40.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F15E' \
  docs/public/roms/part6-game-dev/40-bcd-arithmetic/40-bcd-arithmetic.bin
```

Stella keeps one `-break` per run — the last one on the command line — so run one checkpoint at
a time.

- **`$F15E` (`BCDAdd`)**: A=`$01` at frame 61, A=`$64` at 121, A=`$01` at 181 — the command
  selector, not a BCD addend.
- **`$F173` (`BCDCarryMid`) / `$F18B` (`BCDCarry`)**: A=0 for the small adds; a scratch build
  started at 000099 reports A=1 at the mid capture, and exercise 3 reports A=1 at the high
  capture.
- **`$F294` (`ScoreDigitWrite`)**: six calls per operation; at frame 61 they are A=0…5 with
  X=`0,0,0,0,0,1`, which is 000001.
- **`$F0EF` (`BodyStart`)** 37/5, **`$F2DD` (`ScoreDraw`)** 37/11, **`$F134`
  (`OverscanStart`)** 229/4 — the 262-line frame and the 9 + 183 picture split.
- **`$F291` (`HmoveApply`) / `$F293` (`HmoveDone`)**: `HmoveApply` hits at 4/45 (the `WSYNC`
  stall); the `STA HMOVE` executes at 5/0, and `HmoveDone` reports 5/3 after it — one `HMOVE` per
  frame for the two score players.

With the debugger open on a visible frame, the number is in `$90–$92` (low, middle, high), the
display cache is `$A0–$A5`, and the picture bytes are `$A8–$D7`. The `Overflow` flag is `$86`
and the red cell's PF byte is `$87`.

## Exercises

### Exercise 1: Add 10

**Challenge:** implement the ADD 10 path — command selector `A=10`, which adds `$10` to the low
byte — and light the ADD 10 cell. The main ROM leaves this path out.

**Hints:**
1. In `BCDAdd`, add `CMP #10` / `BEQ BCDAddTen` before the `CMP #100` test.
2. `BCDAddTen` is the ADD 1 path with `ADC #$10` instead of `ADC #$01`; the carry chain into the
   middle and high bytes is unchanged. Share it with `BCDAddOne` by jumping into a common
   `BCDCarryFromLow` label.
3. Enable the ADD 10 slot by setting bit 1 in `OpMask` (`%00000111`) and start the demo on
   `OP_ADD10`, so the first operation reads 000010.

**Expected Result:** the score reads **000010**; the ADD 10 cell is lit; `BCDAdd` is called with
A=10 and `BCDScoreLow=$10`. The next operation (ADD 100) makes 000110.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Subtract 1

**Challenge:** add a `BCDSub` routine with `SED; SEC; SBC #1` across the three bytes, route the
SUB 1 slot to it, and light the SUB 1 cell. From 000000 the borrow must wrap the score to
**999999**.

**Hints:**
1. `SEC` starts the subtract; `SBC #$00` on the middle and high bytes subtracts the borrow from
   the previous byte. `LDA` does not change the carry flag, so the chain survives.
2. After the high byte, `CLD` and test `BCC` (C=0) for the borrow. The bytes are already
   `$99,$99,$99` at that point.
3. Enable bit 3 in `OpMask` (`%00001101`), start on `OP_SUB1`, and branch to `BCDSub` in
   `ExecuteOperation` for that slot.

**Expected Result:** the first operation takes 000000 to **999999**; `BCDBorrow` reports A=1;
the SUB 1 cell is lit. The next operation (ADD 1) is the mirror: it carries back to 000000 and
lights the overflow cell.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Add 100 with a Middle Carry *(Stretch Goal)*

**Challenge:** set up the middle-carry scenario **009900 + 100 = 010000**. The middle byte is
`$99`, so adding 1 to it wraps to `$00` and carries into the high byte. Show the carry in the
debugger.

**Hints:**
1. Set `BCDScoreMid` to `$99` after `ScoreInit` and before `BCDToDigits`, so the display starts
   at 009900.
2. Start the demo on `OP_ADD100`; the main ROM's ADD 100 path already carries from the middle to
   the high byte.
3. Break at `BCDCarry` — it reports A=1 on the middle add. The top carry is still 0, so the red
   cell stays dark: a carry *into* the high byte is not a carry *out* of it.

**Expected Result:** the score reads **010000**; `BCDCarry` reports A=1 at the middle add; the
ADD 100 cell is lit; `Overflow` remains 0 and the red cell stays dark.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **BCD is two decimal digits per byte**: the high nibble is the left digit, the low nibble the right; three bytes hold a six-digit score
- ✅ **`SED` and `CLD` bracket every decimal operation**: every `BCDAdd`/`BCDSub` path that enters decimal mode restores binary mode with `CLD`
- ✅ **The carry flag links the bytes**: `LDA #0; ADC #0` turns C into a byte, and the next byte adds that byte with a fresh `CLC`
- ✅ **A is a command selector**: `A=1`, `A=10`, and `A=100` name the byte and the amount; `A=100` is not the BCD addend `$64`
- ✅ **`SBC` subtracts the borrow**: `SEC` starts the chain, `SBC #$00` propagates it, and a final `BCC` detects 000000 → 999999
- ✅ **The display is rebuilt from the bytes**: `BCDToDigits` makes six `ScoreSetDigit` calls, and `ScoreDraw` draws the same 48-pixel block as Lesson 39
- ✅ **The monitor is 9 + 8 + 8 + 8 + 159 lines**: the bar shows the operation, the red cell the overflow, and the strip the eight bits of the low byte

## What's Next

The BCD counter is a reliable score, but the program still runs one operation after another with
no notion of a game. [Lesson 41: Game States](/part6-game-dev/41-game-states) adds a title
screen, a play state, and a game-over state, each with its own input and drawing code — and the
play state counts its hits with a 15-chunk bar, leaving the BCD score for a later scoreboard.
