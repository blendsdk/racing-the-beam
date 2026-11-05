---
title: "Lesson 36: Music — Melodies on the TIA"
description: "A melody is a table of AUDF values and a duration counter. Lesson 36 plays the first phrase of Ode to Joy with a C/G harmony on the second channel and draws both scale degrees on an eight-rung ladder."
prev:
  text: "Lesson 35: Sound Effects"
  link: "/part5-sound/35-sound-effects"
next:
  text: "Lesson 37: Advanced Audio"
  link: "/part5-sound/37-advanced-audio"
---

# Lesson 36: Music — Melodies on the TIA

> **Part 5: Sound** · Estimated time: 75 minutes
> **Prerequisites:** Lesson 11 (lookup tables), Lesson 17 (cycle counting), Lesson 26 (`SetHorizPos` and fine positioning), Lesson 30 (per-line register writes), Lesson 34 (frame counters and state), Lesson 35 (the audio registers and effects)
> **You will learn:** how a note becomes an `AUDF` value; why the TIA's 5-bit divider makes equal temperament approximate; how a divider table is built and where it is out of tune; how a duration counter advances a melody; how two channels play a lead and a harmony; how to draw the current scale degrees on a ladder
> **You will build:** "the music box" — the first phrase of "Ode to Joy" on channel 0, a C/G harmony on channel 1, and two 8-row markers that climb an eight-rung ladder; plus three exercises: double speed, change the harmony, and add a rest-and-repeat pause

## Introduction

A modern computer stores a note as a number and a duration, and a synthesizer turns that number
into a frequency. The TIA has no note numbers. It has a **divider**: `AUDF` is a 5-bit value
(0–31), and the audio clock is divided by `AUDF+1` and then by a divisor selected by `AUDC`. A
melody is therefore a table of divider values, and a "note" is whatever frequency those dividers
produce.

That is the whole idea of this lesson. The music box plays the first phrase of **"Ode to Joy"**
(public domain) on channel 0, while channel 1 holds a **C/G harmony**. Each voice has a small
sequence table and a frame counter; when the counter expires, the next note is loaded. Two 8-row
markers climb an eight-rung ladder, so the current scale degrees are visible while the tune plays.

The tuning is honest. The TIA's integer dividers cannot hit every equal-tempered note exactly:
G4 comes out about 46 cents sharp and B4 about 65 cents flat. The lesson publishes the divider
table and the errors instead of pretending the chip is a piano. It also explains why the lower
voice is a harmony rather than a deep bass: a C3 would need `AUDF` 39, outside the 5-bit field.

::: details TypeScript Equivalent
A melody is a table plus a cursor, and a duration counter decides when the cursor moves:

```typescript
const noteFreq = [19, 17, 15, 14, 12, 11, 10, 9];   // C4..C5, AUDF
const lead = [2, 2, 3, 4, 4, 3, 2, 1, 0, 0, 1, 2, 2, 1, 1, -1];
const harmony = [0, 4, 0, 4];
const NOTE_FRAMES = 12;

let leadIndex = 0, leadTimer = NOTE_FRAMES;
let harmonyIndex = 0, harmonyTimer = 4 * NOTE_FRAMES;

write(AUDC0, 0x0C);   // div 6 pure tone
write(AUDC1, 0x0D);   // div 6, different phase

function vblank() {
  if (--leadTimer === 0) {
    leadTimer = NOTE_FRAMES;
    leadIndex = (leadIndex + 1) % lead.length;
    const degree = lead[leadIndex];
    write(AUDF0, degree < 0 ? 19 : noteFreq[degree]);
    write(AUDV0, degree < 0 ? 0 : 8);
  }
  if (--harmonyTimer === 0) {
    harmonyTimer = 4 * NOTE_FRAMES;
    harmonyIndex = (harmonyIndex + 1) % harmony.length;
    const degree = harmony[harmonyIndex];
    write(AUDF1, noteFreq[degree]);
    write(AUDV1, 6);
  }
}
```

The analogy breaks at the tuning step. A synthesizer maps a note number to a precise frequency;
the 2600 maps it to an integer divider, and the nearest divider can be tens of cents away from the
equal-tempered pitch. The table is a set of closest dividers, not a formula.
:::

## Theory

### Section 1: From Divider to Note

The audio clock is **31,399.5 Hz** on NTSC (3.579545 MHz / 114). A pure tone is:

```text
f = 31399.5 / ((AUDF + 1) × D)
```

For `AUDC=$0C` or `$0D`, `D=6`, so the tone is `5233.25 / (AUDF+1)`. The useful musical range for
this lesson is C4–C5, and the nearest dividers are:

| Degree | `AUDF` | Hz (nominal clock) | Equal-tempered Hz | Error |
|---|---|---|---|---|
| C4 | 19 | 261.66 | 261.63 | +0.2 ¢ |
| D4 | 17 | 290.74 | 293.66 | −17.4 ¢ |
| E4 | 15 | 327.08 | 329.63 | −13.4 ¢ |
| F4 | 14 | 348.88 | 349.23 | −1.7 ¢ |
| G4 | 12 | 402.56 | 392.00 | +46.0 ¢ |
| A4 | 11 | 436.10 | 440.00 | −15.4 ¢ |
| B4 | 10 | 475.75 | 493.88 | −64.8 ¢ |
| C5 | 9 | 523.33 | 523.25 | +0.2 ¢ |

Every value is in the 5-bit field. The table is not a formula: it is the closest divider for each
degree, computed against the equal-tempered target. G4 and B4 are the audible compromises; the
tune is recognizable, but the chip's tuning is not a piano's.

The 5-bit limit has a second consequence. A true C3 bass is `AUDF` 39 with div 6 — outside the
field. The TIA would silently keep only the low five bits and play a different note. Div 31 can
reach C3 at `AUDF` 7 (126.61 Hz), but that is 56.5 cents flat, and the timbre changes. This lesson
keeps both voices on div 6 and calls the lower one a **harmony**, not a bass. The trade-off is
named, not hidden.

### Section 2: Two Voices

The lead is a 16-step sequence of scale indices:

```text
2, 2, 3, 4, 4, 3, 2, 1, 0, 0, 1, 2, 2, 1, 1, $FF
E  E  F  G  G  F  E  D  C  C  D  E  E  D  D  rest
```

Each step lasts 12 frames, so the phrase is 192 frames — about 3.2 seconds at 60 Hz. The harmony
is a 4-step sequence, `0, 4, 0, 4` (C, G, C, G), and each harmony note lasts `4 × 12 = 48`
frames. The two sequences both loop at 192 frames, so they stay aligned.

The lead volume is 8; the harmony is 6. The rest is special: it re-uses C4's divider (`AUDF` 19)
with volume 0, so the frequency log still ends on 19 and the marker disappears. There is no
special "silence" register; a rest is simply a note with `AUDV=0`.

### Section 3: The Ladder

The music box draws eight rungs at visible lines 16, 36, 56, 76, 96, 116, 136, and 156. Each rung
is a one-line playfield bar: `PF1` and `PF2` are `$FF` on the rung line and cleared on the next
line. `PF0` stays 0, so the rung fills the middle 128 TIA pixels (768 capture px), with a 16-px
margin at the left and right edges; `CTRLPF=$01` mirrors the left half onto the right.

The lead marker is player 0 at X=48 (red `$42`); the harmony marker is player 1 at X=112 (blue
`$84`). Each marker is 8 rows tall and straddles its rung: the top is `RungTop[degree]` (the rung
line minus 4), so a marker on rung 0 starts at visible line 12 and covers 12–19. A rest sets the top to `$F0`, which
never matches a visible line, hiding the marker.

The loop also draws a ninth baseline rung at visible 176, below the scale. It is a visual floor,
not a scale degree; the markers never use it.

### Section 4: The Frame

The frame is 3 + 37 + 192 + 30 = 262 lines. The picture is work-first: each line's rung and markers
are written, then `STA WSYNC`. The first work line is scanline 37; the last is 228; overscan starts
at 229.

The two markers are positioned once per frame in VBLANK. Both `RESPx` strobes and both `HMPx`
values are set first, then one `HMOVE` applies both fine offsets — the one-`HMOVE` rule from
Part 4. The note timers and the two `JSR Play…` calls also run in VBLANK; the visible kernel does
no audio work.

::: tip The grid's one-line budget
The rung line writes `PF1`/`PF2` and the next line clears them. The rung and clear paths are 23 cycles;
the normal path is 16; with the two marker comparisons (about 38 cycles) and the
10-cycle loop tail, the worst line (the rung path) is about 71 cycles of the 76-cycle budget. The work-first order
keeps every line inside the beam.
:::

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson36.bin \
  lessons/part5-sound/36-music/36-music.asm
stella build/lesson36.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 36: Music — Melodies on the TIA — Racing the Beam
; =============================================================================
; Part 5: Sound
;
; What this program does:
;   "The music box": plays the first phrase of "Ode to Joy" on channel 0
;   while channel 1 holds a C/G harmony.  Two 8-row markers climb an eight-rung
;   ladder; their vertical position is the current scale degree.  The markers
;   make the two voices visible while the ROM plays.
;
; The note table:
;   A note is an AUDF value.  AUDF is a 5-bit divider (0-31); higher AUDF is a
;   lower pitch.  Both channels use AUDC=$0C/$0D (div 6), so one derived
;   C4-C5 table serves both voices:
;
;       degree  C  D  E  F  G  A  B  C'
;       AUDF   19 17 15 14 12 11 10  9
;       Hz    262 291 327 349 403 436 476 523
;
;   The integer dividers are not perfectly equal-tempered: G4 is about +46
;   cents and B4 about -65 cents.  The lesson publishes the errors rather than
;   pretending the table is exact.  A true C3 bass would need AUDF 39, outside
;   the 5-bit field, so the lower voice is a harmony in the same octave.
;
; The tune:
;   Lead (16 steps, scale indices; $FF = rest):
;       2,2,3,4,4,3,2,1,0,0,1,2,2,1,1,$FF
;   Harmony (4 steps): 0,4,0,4 (C, G, C, G), held 4 x NOTE_FRAMES.
;   NOTE_FRAMES = 12 (192 frames per phrase), so the lead advances at 5 Hz
;   and the harmony every 48 frames.  Both sequences loop.
;
; The picture:
;   Eight rungs at visible lines 16 + 20k (16, 36, ... 156), drawn by the
;   playfield for one line each.  Player 0 is the red lead marker at X=48;
;   player 1 is the blue harmony marker at X=112.  A marker is 8 rows tall and
;   straddles its rung (top = rung line - 4).  A rest sets the top to $F0,
;   which never matches a visible line, so the marker disappears.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), AUDC0Write/AUDC1Write (A = the timbre),
;   LeadStep (A = the new lead index),
;   HarmonyStep (A = the new harmony index), LeadFreqWrite/LeadVolWrite,
;   HarmonyFreqWrite/HarmonyVolWrite, BodyStart (37), HmoveApply/HmoveDone,
;   OverscanStart (229).
;
; Build: acme -f plain -o build/lesson36.bin \
;        lessons/part5-sound/36-music/36-music.asm
; Run:   stella build/lesson36.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"

; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
NOTE_FRAMES    = 12
HARMONY_FRAMES = 4 * NOTE_FRAMES
LEAD_X         = 48
HARMONY_X      = 112
POS_BIAS       = 3

; --- Zero-page variables (RAM $80-$FF; +clean_start zeroes them) ---
LeadIndex   = $80   ; 0-15, the current lead step
LeadTimer   = $81   ; frames until the next lead step
HarmonyIndex= $82   ; 0-3, the current harmony step
HarmonyTimer= $83   ; frames until the next harmony step
LeadTop     = $84   ; the lead marker's first visible line ($F0 hides it)
HarmonyTop  = $85   ; the harmony marker's first visible line ($F0 hides it)
GridPhase   = $86   ; 0-19: when it wraps, the next line is a rung

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

Reset:
    +clean_start
    LDA #$0C
    STA AUDC0               ; div 6 pure tone: the lead
AUDC0Write:                 ; checkpoint: A = the lead timbre
    LDA #$0D
    STA AUDC1               ; div 6 pure tone: the harmony
AUDC1Write:                 ; checkpoint: A = the harmony timbre
    LDA #0
    STA LeadIndex
    STA HarmonyIndex
    LDA #NOTE_FRAMES
    STA LeadTimer
    LDA #HARMONY_FRAMES
    STA HarmonyTimer
    JSR PlayLead
    JSR PlayHarmony

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- advance the lead every NOTE_FRAMES ---
    DEC LeadTimer
    BNE NoLeadStep
    LDA #NOTE_FRAMES
    STA LeadTimer
    INC LeadIndex
    LDA LeadIndex
    CMP #16
    BCC LeadStore
    LDA #0
LeadStore:
LeadStep:                   ; checkpoint: A = the new lead index
    STA LeadIndex
    JSR PlayLead
NoLeadStep:

; --- advance the harmony every HARMONY_FRAMES ---
    DEC HarmonyTimer
    BNE NoHarmonyStep
    LDA #HARMONY_FRAMES
    STA HarmonyTimer
    INC HarmonyIndex
    LDA HarmonyIndex
    CMP #4
    BCC HarmonyStore
    LDA #0
HarmonyStore:
HarmonyStep:                ; checkpoint: A = the new harmony index
    STA HarmonyIndex
    JSR PlayHarmony
NoHarmonyStep:

; --- position the two markers; one HMOVE applies both fine offsets ---
    LDA #(LEAD_X + POS_BIAS)
    JSR SetPos0
    LDA #(HARMONY_X + POS_BIAS)
    JSR SetPos1

    LDA #$42
    STA COLUP0              ; red lead
    LDA #$84
    STA COLUP1              ; blue harmony
    LDA #$0A
    STA COLUPF              ; dim grid
    LDA #$02
    STA COLUBK
    LDA #0
    STA NUSIZ0
    STA NUSIZ1
    LDA #$01
    STA CTRLPF
    LDA #17
    STA GridPhase

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — 192 lines, work-first: draw the line, then WSYNC
; -----------------------------------------------------------------------------
    LDA #$00
    STA VBLANK
    LDX #0
BodyStart:                  ; checkpoint: the first visible line (scanline 37)
BodyLoop:
    ; --- a 1-line rung every 20 lines: set PF1/PF2 on the rung,
    ;     clear them on the following line (PF0 stays 0, so the rung
    ;     has a 16-px margin on each side) ---
    DEC GridPhase
    BNE NoGrid
    LDA #20
    STA GridPhase
    LDA #$FF
    STA PF1
    STA PF2
    JMP GridDone
NoGrid:
    LDA GridPhase           ; the line after a rung clears the playfield
    CMP #19
    BNE GridDone
    LDA #0
    STA PF1
    STA PF2
GridDone:

    ; --- the lead marker, 8 rows from LeadTop ---
    TXA
    SEC
    SBC LeadTop
    CMP #8
    BCS NoLead
    LDA #$FF
    STA GRP0
    JMP LeadDone
NoLead:
    LDA #0
    STA GRP0
LeadDone:

    ; --- the harmony marker, 8 rows from HarmonyTop ---
    TXA
    SEC
    SBC HarmonyTop
    CMP #8
    BCS NoHarmony
    LDA #$FF
    STA GRP1
    JMP HarmonyDone
NoHarmony:
    LDA #0
    STA GRP1
HarmonyDone:
    STA WSYNC
    INX
    CPX #192
    BNE BodyLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; PLAY THE LEAD — one note per call; $FF is a silent C4
; =============================================================================
PlayLead:
    LDY LeadIndex
    LDA LeadNotes,Y
    CMP #$FF
    BEQ LeadRest
    TAX
    LDA NoteFreq,X
    STA AUDF0
LeadFreqWrite:              ; checkpoint: A = the lead AUDF
    LDA #8
    STA AUDV0
LeadVolWrite:               ; checkpoint: A = the lead volume
    LDA RungTop,X
    STA LeadTop
    RTS
LeadRest:
    LDA #19                 ; C4's divider, with volume 0
    STA AUDF0
LeadRestFreq:               ; checkpoint: A = 19 on the rest
    LDA #0
    STA AUDV0
LeadRestVol:                ; checkpoint: A = 0 on the rest
    LDA #$F0
    STA LeadTop
    RTS

; =============================================================================
; PLAY THE HARMONY — C and G, in the same octave as the lead table
; =============================================================================
PlayHarmony:
    LDY HarmonyIndex
    LDA HarmonyNotes,Y
    TAX
    LDA NoteFreq,X
    STA AUDF1
HarmonyFreqWrite:           ; checkpoint: A = the harmony AUDF
    LDA #6
    STA AUDV1
HarmonyVolWrite:            ; checkpoint: A = the harmony volume
    LDA RungTop,X
    STA HarmonyTop
    RTS

; =============================================================================
; TWO-OBJECT POSITIONING — one HMOVE at the end
; =============================================================================
SetPos0:
    STA WSYNC
    SEC
Div0:
    SBC #15
    BCS Div0
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP0
    STA RESP0
    RTS
SetPos1:
    STA WSYNC
    SEC
Div1:
    SBC #15
    BCS Div1
    EOR #7
    ASL
    ASL
    ASL
    ASL
    STA HMP1
    STA RESP1
    STA WSYNC
HmoveApply:                 ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                  ; checkpoint: the store has executed
    RTS

; =============================================================================
; NOTE AND PICTURE TABLES
; =============================================================================
LeadNotes:
    !byte 2,2,3,4,4,3,2,1,0,0,1,2,2,1,1,$FF
HarmonyNotes:
    !byte 0,4,0,4
NoteFreq:
    !byte 19,17,15,14,12,11,10,9
RungTop:
    !byte 12,32,52,72,92,112,132,152

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
> `lessons/part5-sound/36-music/36-music.asm`.

### Code Walkthrough

#### Step 0 — Set the timbre

`Reset` writes `AUDC0=$0C` and `AUDC1=$0D` before the first note. Both are div-6 pure tones;
the two values differ only in phase. This write is easy to forget: `+clean_start` zeroes the TIA,
and `AUDC=0` disables the channel, so the note and volume writes would produce silence. The
`AUDC0Write`/`AUDC1Write` checkpoints report A=`$0C`/`$0D` on the first frame.

#### Step 1 — The lead clock

`DEC LeadTimer` counts down from `NOTE_FRAMES` (12). When it reaches 0, the timer reloads,
`LeadIndex` advances, wraps at 16, and `PlayLead` loads the next note. `LeadStep` marks the store,
so the log reports A = the new index, one hit every 12 frames.

#### Step 2 — The harmony clock

`DEC HarmonyTimer` counts down from `HARMONY_FRAMES` (48). When it reaches 0, `HarmonyIndex`
advances, wraps at 4, and `PlayHarmony` loads the next note. `HarmonyStep` reports A = the new
index, one hit every 48 frames. The two clocks are independent but both loop at 192 frames.

#### Step 3 — Playing a note

`PlayLead` reads `LeadNotes[LeadIndex]`. A normal index selects a `NoteFreq` entry, writes
`AUDF0` (`LeadFreqWrite`), writes volume 8 (`LeadVolWrite`), and sets `LeadTop` from `RungTop`. A
`$FF` index takes the `LeadRest` path: `AUDF0=19`, `AUDV0=0`, `LeadTop=$F0`. The rest's separate
labels (`LeadRestFreq`, `LeadRestVol`) make the log unambiguous. `PlayHarmony` is the same shape
without a rest: `AUDF1=NoteFreq[degree]`, `AUDV1=6`, `HarmonyTop=RungTop[degree]`.

#### Step 4 — Position and color

The lead marker is player 0 at X=48; the harmony marker is player 1 at X=112. `SetPos0` and
`SetPos1` are the standard divide-by-15 routines; the second ends with `STA WSYNC` / `STA HMOVE`,
so both fine offsets are applied in one HBLANK. The colors are red `$42`, blue `$84`, grid `$0A`,
background `$02`.

#### Step 5 — The visible kernel

The kernel is work-first. Each line decrements `GridPhase`; when it hits 0, the line is a rung:
`PF1`/`PF2` are set to `$FF` and the phase resets to 20. The next line clears the playfield. Then
the two markers compare their line against `LeadTop`/`HarmonyTop` and write `GRP0`/`GRP1` for
eight rows. `STA WSYNC` ends the line; `INX`/`CPX #192` repeat. The last line is 228;
`OverscanStart` is 229.

#### Step 6 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F02A` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F038` | 0, cycle 5 | VBLANK's first line |
| `AUDC0Write` | `$F012` | `$0C` on the first frame | the lead timbre |
| `AUDC1Write` | `$F016` | `$0D` on the first frame | the harmony timbre |
| `LeadStep` | `$F053` | A=1 at frame 12, A=2 at 24, …, A=15 at 180 | the lead advance |
| `HarmonyStep` | `$F06A` | A=1 at frame 48, A=2 at 96, A=3 at 144, A=0 at 192 | the harmony advance |
| `LeadFreqWrite` | `$F110` | E=15 at 0/12, F=14 at 24, G=12 at 36/48, … | the lead `AUDF` |
| `LeadVolWrite` | `$F114` | 8 on every lead note; the rest writes 0 at `LeadRestVol` | the lead volume |
| `LeadRestFreq` | `$F11E` | 19 at frame 180 | the rest's silent C4 |
| `LeadRestVol` | `$F122` | 0 at frame 180 | the rest's volume |
| `HarmonyFreqWrite` | `$F132` | 19 at 0, 12 at 48, 19 at 96, 12 at 144 | the harmony `AUDF` |
| `HarmonyVolWrite` | `$F136` | 6 at every harmony note | the harmony volume |
| `BodyStart` | `$F0A4` | 37, cycle 7 | the first visible line |
| `HmoveApply` | `$F161` | line 2, cycle 60 | the WSYNC stall; the `STA HMOVE` executes at line 3, cycle 0 |
| `HmoveDone` | `$F163` | line 3, cycle 3 | the store has executed in HBLANK |
| `OverscanStart` | `$F0EE` | 229, cycle 6 | overscan's first line |

## What You Should See

The music box is a dark field with eight faint gray rungs and two colored markers.

**First phrase, first bar.** The red lead marker sits on rung 2 (E) at capture x = 313–360,
y ≈ 271–297. The blue harmony marker sits on rung 0 (C) at capture x = 697–744, y ≈ 145–168. The
rungs are visible at y ≈ 157, 220, 284, 347, 410, 473, 536, and 599, with the baseline at 663.

![Stella running the Lesson 36 ROM: a red lead marker on the E rung and a blue harmony marker on the C rung](/images/lesson36/notes-a.png)

*The music box at the start of the phrase: lead E (rung 2) and harmony C (rung 0), captured from
the committed ROM.*

**The two voices meet on G.** The red lead marker is on rung 4 (G) at capture y ≈ 397–424, and
the blue harmony marker is also on G at y ≈ 397–420. The lead has climbed from E and the harmony
has moved up a fifth; for this note both voices are in unison.

![Stella running the Lesson 36 ROM: the red lead marker and the blue harmony marker both on the G rung](/images/lesson36/notes-b.png)

*The lead and harmony meet on G: both markers sit on rung 4.*

<RomPlayer rom="/roms/part5-sound/36-music/36-music.bin" title="Lesson 36 — Music" />

Click the player screen once: Javatari starts muted until a user gesture. The ladder and the
tune are driven by the same note table.

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson36.sym -o build/lesson36.bin \
  lessons/part5-sound/36-music/36-music.asm
grep -E "LeadStep|HarmonyStep|LeadFreqWrite|HarmonyFreqWrite" build/lesson36.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F110' \
  docs/public/roms/part5-sound/36-music/36-music.bin
```

- **`$F053` (`LeadStep`)**: one hit every 12 frames with A = 1, 2, …, 15, then 0.
- **`$F06A` (`HarmonyStep`)**: one hit every 48 frames with A = 1, 2, 3, 0.
- **`$F110` (`LeadFreqWrite`)**: the `NoteFreq` sequence 15, 15, 14, 12, 12, 14, 15, 17, 19, 19,
  17, 15, 15, 17, 17; the rest at frame 180 uses `LeadRestFreq` A=19 with volume 0.
- **`$F132` (`HarmonyFreqWrite`)**: 19, 12, 19, 12 — C, G, C, G.
- **`$F0A4` (`BodyStart`)**: line 37; the ladder covers all 192 visible lines.

## Exercises

### Exercise 1: Double-Speed Music

**Challenge:** change `NOTE_FRAMES` from 12 to 6 so the melody plays twice as fast. Keep
`HARMONY_FRAMES = 4 × NOTE_FRAMES` so the voices stay aligned.

**Hints:**
1. `NOTE_FRAMES` is the only lead constant; `HARMONY_FRAMES` is an ACME expression.
2. The note tables, the ladder, and the colors do not change.
3. The phrase becomes 96 frames (1.6 s) instead of 192.

**Expected Result:** the same melody at double speed. `LeadStep` fires every 6 frames (6, 12, 18,
…); `HarmonyStep` every 24 frames (24, 48, 72, …). The markers move twice as fast but stay on the
same rungs.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Change the Harmony

**Challenge:** change the harmony from C/G (`0,4,0,4`) to C/E (`0,2,0,2`).

**Hints:**
1. The harmony sequence is one `!byte` line.
2. Degree 2 is E4, `AUDF` 15; degree 4 is G4, `AUDF` 12.
3. The lead, the tempos, and the ladder do not change.

**Expected Result:** `HarmonyFreqWrite` reports A=19, 15, 19, 15; the blue marker sits on rung 2
(E) at capture y ≈ 271–297 instead of rung 4. The harmony is a third above C rather than a fifth.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Rest and Repeat *(Stretch Goal)*

**Challenge:** after the lead's rest (step 15), hold silence for 60 frames, then restart both
voices from step 0.

**Hints:**
1. Add a `PauseTimer`. When the rest is played (`LeadIndex=15`), load it with 60 and clear both
   channel volumes and both marker tops (`$F0` hides a marker).
2. While `PauseTimer` is nonzero, skip the normal note timers and decrement it; the rest frame is
   the first of the 60 silent frames.
3. When it reaches 0, reset both indices and timers and call `PlayLead`/`PlayHarmony`; the harmony
   reappears on rung 0 (C) and the lead on rung 2 (E).

**Expected Result:** the markers disappear on the rest, stay hidden for 60 frames (frames
180–239), and return when the phrase restarts at frame 240. The next `LeadStep` is at frame 252
(A=1), 12 frames after the restart. `LeadRestFreq`/`LeadRestVol` report 19/0 at the rest;
`PauseVolWrite` reports A=0 and `PauseTopWrite` A=`$F0` during the pause.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A note is a divider**: `AUDF` 0–31 selects `f = 31399.5/((AUDF+1)×D)`, not a named pitch
- ✅ **The 5-bit field is a hard limit**: an out-of-range value silently loses its upper bits; a true C3 bass needs a coarser divisor
- ✅ **The table is derived, not guessed**: the closest divider for G4 is +46 cents and for B4 is −65 cents; the lesson publishes both
- ✅ **A melody is a table plus a cursor**: a duration counter advances the index; there is no audio buffer
- ✅ **Two voices need two clocks**: the lead advances every 12 frames, the harmony every 48, and both loop at 192
- ✅ **A rest is `AUDV=0`**: the divider can stay at C4; silence is a volume, not a special note
- ✅ **The ladder is the score**: the marker's vertical position is the scale degree, and the rung is the same table the audio uses

## What's Next

The music box plays a fixed tune with a fixed two-voice arrangement. [Lesson 37: Advanced Audio](/part5-sound/37-advanced-audio)
turns the per-frame writes into a small data-driven sound engine: eight-byte sound definitions,
per-step frequency and volume tables, two channels, and priority, with a mixer that shows which
sound owns which channel.
