---
title: "Lesson 37: Advanced Audio — Sound Engine Design"
description: "A sound becomes an eight-byte definition plus two per-step tables. Lesson 37 builds a small two-channel sound engine with priority, plays a scheduled mix of effects and music, and draws the channels, the volumes, and the winning priority in a mixer monitor."
prev:
  text: "Lesson 36: Music"
  link: "/part5-sound/36-music"
next:
  text: "Lesson 38: Collision Detection"
  link: "/part6-game-dev/38-collision-detection"
---

# Lesson 37: Advanced Audio — Sound Engine Design

> **Part 5: Sound** · Estimated time: 90 minutes
> **Prerequisites:** Lesson 11 (lookup tables), Lesson 23 (zero-page pointers and `(zp),Y`), Lesson 34 (frame counters and state), Lesson 35 (the audio registers and effects), Lesson 36 (note tables and two-channel timing)
> **You will learn:** how to make a sound a data structure instead of a routine; the eight-byte definition and its per-step frequency/volume tables; how a two-channel engine accepts, rejects, and ends sounds; how priority decides which sound owns a channel; how to draw a mixer that shows all of it
> **You will build:** "the mixer" — a two-channel engine playing scheduled BLIP, LASER, EXPLOSION, and POWERUP sounds against a looping MUSIC track, with three effect bands, two volume meters, and a priority bar; plus three exercises: add a ZAP, invert the priority, and duck the music

## Introduction

Lessons 35 and 36 wrote the audio registers directly. That is fine for a fixed effect or a tune:
the code knows exactly which `AUDC`, `AUDF`, and `AUDV` values come next. A game needs something
more flexible. It has a pool of sounds — a shot, a hit, an explosion, a power-up, a music loop —
and only two channels. Something has to decide which sound gets a channel and which request is
turned away.

This lesson builds that decision into a small **sound engine**. A sound is no longer a routine;
it is a record:

| Byte | Field | Meaning |
|---|---|---|
| +0 | `AUDC` | generator / tone divisor |
| +1 | `Rate` | frames per step |
| +2 | `Steps` | low 7 bits = length; bit 7 = loop |
| +3 | `Priority` | 0–15; the higher number wins |
| +4/+5 | `FreqTable` | pointer to the per-step `AUDF` values |
| +6/+7 | `VolTable` | pointer to the per-step `AUDV` values |

The engine owns both channels. `SoundTrigger` accepts a request only when the channel is free or
the new priority is strictly higher than the current one. `SoundUpdate` advances both channels once
per frame, writes the registers, and mutes a non-looping sound when its last step has played. The
demo plays five sounds on a schedule, proves a rejection in the debugger, and shows the whole state
in **the mixer**: three effect bands at the top, two 15-cell volume meters, and a priority bar at
the bottom.

::: details TypeScript Equivalent
A sound definition and a priority queue make the idea portable:

```typescript
interface SoundDef {
  audc: number;
  rate: number;          // frames per step
  steps: number;
  loop: boolean;
  priority: number;
  freq: number[];        // AUDF per step
  vol: number[];         // AUDV per step
}

interface Voice {
  def: SoundDef;
  step: number;
  timer: number;
  active: boolean;
}

const channels: Voice[] = [emptyVoice(), emptyVoice()];

function trigger(id: number, channel: number): boolean {
  const def = sounds[id];
  const voice = channels[channel];
  if (voice.active && def.priority <= voice.def.priority) return false;
  channels[channel] = { def, step: 0, timer: def.rate, active: true };
  write(AUDC0 + channel, def.audc);
  write(AUDF0 + channel, def.freq[0]);
  write(AUDV0 + channel, def.vol[0]);
  return true;
}

function update() {
  for (let ch = 0; ch < 2; ch++) {
    const v = channels[ch];
    if (!v.active || --v.timer > 0) continue;
    v.timer = v.def.rate;
    v.step++;
    if (v.step >= v.def.steps) {
      if (!v.def.loop) { write(AUDV0 + ch, 0); v.active = false; continue; }
      v.step = 0;
    }
    write(AUDF0 + ch, v.def.freq[v.step]);
    write(AUDV0 + ch, v.def.vol[v.step]);
  }
}
```

The analogy breaks at the resources: a modern mixer can give every sound its own voice. The TIA
has two channels, so the priority test is not a nicety — it is the whole scheduling policy.
:::

## Theory

### Section 1: A Sound Is a Record

The engine's definition is eight bytes. The first four are scalars; the last four are two
little-endian pointers to per-step tables. A sound with `Rate=2` and four steps lasts eight frames;
a sound with `Rate=12` and sixteen steps lasts 192 frames. The loop bit turns a one-shot into a
track: the music definition is sixteen steps with bit 7 set, so it repeats forever.

The per-step tables are what make the engine expressive. A laser can sweep its `AUDF` from 6 to 16;
an explosion can walk a noise table; a melody can change note every step. The engine does not know
what the numbers mean — it just reads `freq[step]` and `vol[step]` and writes them. That is the same
data-driven move as Lesson 23's level tables, applied to sound.

The definitions in this lesson:

| ID | Sound | `AUDC` | Rate | Steps | Priority | Character |
|---|---|---|---|---|---|---|
| 0 | MUSIC | `$0C` | 12 | 16, loop | 1 | the Lesson 36 tune, quiet |
| 1 | BLIP | `$0C` | 2 | 4 | 2 | a short low pulse |
| 2 | LASER | `$04` | 2 | 6 | 5 | a bright downward sweep |
| 3 | EXPLOSION | `$08` | 3 | 12 | 9 | white noise with a long decay |
| 4 | POWERUP | `$04` | 3 | 8 | 8 | a rising arpeggio |

### Section 2: The Engine

The engine has four entry points (the complete library is `include/sound.asm`):

- **`SoundInit`** — silence both channels and clear the state.
- **`SoundTrigger`** — A = sound ID, X = channel; returns carry set if accepted. If the channel is
  busy, the new sound's priority is compared with the current one. **Strictly higher wins; equal or
  lower is rejected.** That one rule prevents a stream of small blips from cutting off an explosion.
  X is preserved on return, so the caller can route the accepted ID to the right monitor shadow.
- **`SoundUpdate`** — call once per frame. It decrements each active channel's timer; when the timer
  reaches zero it advances the step, reloads the timer, and writes the new `AUDF`/`AUDV`. If a
  non-looping sound has played its last step, it writes `AUDV=0` and frees the channel.
- **`SoundStop`** — silence a channel and free it.

The engine keeps eight bytes per channel: the definition pointer, the timer, the step, the priority,
the active flag, and shadows of the last frequency and volume. That is exactly the `$90–$9F` block;
the scratch bytes `$88–$8D` hold the current definition and table pointers; `$8E–$8F` are free for
the caller. The per-step table pointers are re-read from the definition on every step, so the
state does not grow.

### Section 3: The Scheduled Mix

The demo makes five requests on a schedule:

| Request | Period | Channel | Priority |
|---|---|---|---|
| BLIP | 24 frames | 0 | 2 |
| LASER | 120 | 0 | 5 |
| EXPLOSION | 240 | 0 | 9 |
| POWERUP | 360 | 1 | 8 |
| MUSIC | loop | 1 | 1 |

The VBLANK order is **LASER, EXPLOSION, POWERUP, BLIP**. The order matters on the frames where
requests coincide: at frame 120 the LASER is accepted first, and the BLIP that also comes due is
rejected (2 < 5). At frame 240 the LASER is accepted, then the EXPLOSION replaces it (9 > 5), and
the BLIP is rejected (2 < 9). The guaranteed standalone rejection is the BLIP at frame 264, inside
the explosion's 240–275 window. The debugger's `Accept`/`Reject` checkpoints record each one with
A = the sound ID and X = the channel.

The music is the loop that fills the gaps. Its sixteenth step is a rest, so channel 1's meter drops
to 0 for 12 frames at the end of each 192-frame loop; that is the tune, not a bug. It starts at
reset on channel 1 and is retriggered whenever channel 1 is free. The POWERUP (priority 8) interrupts it at frame 360; when the power-up
ends, the engine frees channel 1 and the main code brings the music back at frame 384.

### Section 4: The Mixer

The monitor has three parts:

| Part | Object | Position | What it shows |
|---|---|---|---|
| Effect bands | Playfield, 3 × 8 lines | visible 0–23 | which channel-0 sound is active: BLIP, LASER, or EXPLOSION |
| Volume meters | Players 0 and 1, 15 cells × 6 lines | X=48 and X=112 | channel 0 and channel 1 `AUDV` |
| Priority bar | Playfield, 8 lines | visible 122–129 | channel 0's priority, N chunks per half |

The two meters use the same cell logic as Lesson 35: cell 14 is the top, cell 0 the bottom, and a
cell lights when its index is below the channel's volume. The bars are 90 visible lines (15 × 6);
the priority bar is eight lines. The total is 24 + 4 + 90 + 4 + 8 + 62 = 192.

The priority bar is a playfield pattern, not a sprite. Its table has one 20-bit row per priority;
priority N lights the first N chunks of the left half, and `CTRLPF=$01` mirrors them, so the bar is
N chunks per half. At priority 5 (LASER) the bar is 5 chunks (120 capture px); at priority 9
(EXPLOSION) it is 9 chunks (216 capture px).

The colors follow the sound: BLIP green `$C8`, LASER gold `$1A`, EXPLOSION red `$42`; channel 1 is
blue `$84` for the music and green `$C8` during a power-up. The top bands use `$02` when a slot is
not active, so an empty mixer is dark.

### Section 5: The Frame

The frame is 3 + 37 + 192 + 30 = 262 lines. The picture is work-first; the first work line is
scanline 37, the last is 228, and overscan starts at 229. The engine work — `SoundUpdate`, the four
scheduled requests, the music retrigger, the monitor shadows, the two positions, and one
`HMOVE` — runs in VBLANK and fits inside the 37-line budget. The two players are positioned with the
same two-routine divide-by-15 code as Lessons 35 and 36; one `HMOVE` applies both fine offsets in
HBLANK.

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
```

Or assemble just this lesson's ROM directly with ACME:

```bash
acme -f plain -o build/lesson37.bin \
  lessons/part5-sound/37-advanced-audio/37-advanced-audio.asm
stella build/lesson37.bin
```

The exercise solutions assemble the same way — replace the file name with
`exercise-01-solution.asm`, `exercise-02-solution.asm`, or `exercise-03-solution.asm`.

### The Engine

The complete library is `include/sound.asm`. Its API and data format are the ones in Section 2;
the main source sources it with `!source "include/sound.asm"` and defines the `SoundTable` the
engine reads. The records are the data the caller supplies; the API and the `Snd*` shadows are the
rest of the contract.

### Full Source

<!-- BEGIN-FULL-SOURCE -->

```asm
; =============================================================================
; LESSON 37: Advanced Audio — Sound Engine Design — Racing the Beam
; =============================================================================
; Part 5: Sound
;
; What this program does:
;   "The mixer": a small data-driven sound engine owns both TIA channels.
;   Channel 0 plays BLIP, LASER, and EXPLOSION on a schedule; channel 1 loops
;   MUSIC and is interrupted by a POWERUP.  Three top bands show the active
;   channel-0 sound; two 15-cell bars show the two channel volumes; a bottom
;   bar shows the channel-0 priority.  A request that loses the priority test
;   is rejected, and the debugger's Accept/Reject checkpoints prove it.
;
; The engine (include/sound.asm):
;   Each sound is 8 bytes: AUDC, Rate (frames per step), Steps (bit 7 = loop),
;   Priority, and pointers to the per-step frequency and volume tables.
;   A channel owns one sound.  A new sound is accepted only if the channel is
;   free or the new priority is strictly higher; equal or lower is rejected.
;   SoundUpdate advances both channels once per frame and mutes a non-looping
;   sound at its end.
;
; The demo schedule (counters start at their periods):
;   BLIP       every 24 frames, channel 0, priority 2
;   LASER      every 120, channel 0, priority 5
;   EXPLOSION  every 240, channel 0, priority 9
;   POWERUP    every 360, channel 1, priority 8
;   MUSIC      channel 1, priority 1, 16-step loop, retriggered when free
;   The VBLANK order is LASER, EXPLOSION, POWERUP, BLIP, so a BLIP that lands
;   on a LASER/EXPLOSION frame is rejected deterministically.  The guaranteed
;   standalone rejection is the BLIP at frame 264 inside the explosion's
;   240-275 window.
;
; The picture:
;   Visible line 0 = scanline 37.  The top 24 lines are three 8-line bands for
;   BLIP/LASER/EXPLOSION.  The next 90 lines are two 15-cell meters (6 lines
;   per cell) at X=48 and X=112.  A 4-line gap, an 8-line priority bar (N
;   playfield chunks per half), and 62 background lines complete the 192.
;
; Checkpoints (Stella scanline numbers in parentheses):
;   StartFrame (259), VblankStart (0), Trigger/Accept/Reject (A=ID, X=channel),
;   CtlWrite/FreqWrite/VolWrite/StepWrite (A=value, X=channel), MusicStart (384),
;   BodyStart (37), MeterStart (65), PrioStart (159), HmoveApply/HmoveDone,
;   OverscanStart (229).
;
; Build: acme -f plain -o build/lesson37.bin \
;        lessons/part5-sound/37-advanced-audio/37-advanced-audio.asm
; Run:   stella build/lesson37.bin
; =============================================================================

    !cpu 6502

    !source "include/vcs.asm"
    !source "include/macro.asm"
; =============================================================================
; PROGRAM CONSTANTS
; =============================================================================
VBLANK_TIMER   = 44
OVERSCAN_TIMER = 36
SFX_X          = 48
CH1_X          = 112
POS_BIAS       = 3

; --- Lesson variables (the engine owns $88-$9F) ---
BlipTimer  = $80   ; 24 -> 0, then reload
LaserTimer = $81   ; 120 -> 0
BoomTimer  = $82   ; 240 -> 0
PowerTimer = $83   ; 120 -> 0, three ticks make 360
PowerCount = $8F   ; 3 -> 0; the third tick triggers POWERUP
SfxID      = $84   ; the last accepted channel-0 sound
Ch1ID      = $85   ; the last accepted channel-1 sound
SfxColor   = $86   ; the active channel-0 color
ActiveBand = $87   ; the active top band (0-2) or $FF

; The priority bar's three bytes live in the free $A0-$F7 block.
PrioPF0    = $A0
PrioPF1    = $A1
PrioPF2    = $A2
BandColor0 = $A3
BandColor1 = $A4
BandColor2 = $A5

; =============================================================================
; ROM START — cartridge space ($F000-$FFFF)
; =============================================================================
    * = $F000

    !source "include/sound.asm"

Reset:
    +clean_start
    LDA #24
    STA BlipTimer
    LDA #120
    STA LaserTimer
    LDA #240
    STA BoomTimer
    LDA #120
    STA PowerTimer
    LDA #3
    STA PowerCount
    LDA #0
    STA SfxID
    STA Ch1ID
    JSR SoundInit
    LDA #0
    LDX #1
    JSR TriggerSound       ; start MUSIC on channel 1

StartFrame:
    +vsync

VblankStart:
    LDA #$02
    STA VBLANK
    +set_timer VBLANK_TIMER

; --- advance the engine, then make the scheduled requests ---
    JSR SoundUpdate

    DEC LaserTimer
    BNE NoLaser
    LDA #120
    STA LaserTimer
    LDA #2
    LDX #0
    JSR TriggerSound
NoLaser:

    DEC BoomTimer
    BNE NoBoom
    LDA #240
    STA BoomTimer
    LDA #3
    LDX #0
    JSR TriggerSound
NoBoom:

    DEC PowerTimer
    BNE NoPower
    LDA #120
    STA PowerTimer
    DEC PowerCount
    BNE NoPower
    LDA #3
    STA PowerCount
    LDA #4
    LDX #1
    JSR TriggerSound
NoPower:

    DEC BlipTimer
    BNE NoBlip
    LDA #24
    STA BlipTimer
    LDA #1
    LDX #0
    JSR TriggerSound
NoBlip:

    LDA SndActive+1        ; if channel 1 is free, bring the music back
    BNE NoMusic
    LDA #0
    LDX #1
    JSR TriggerSound
MusicStart:                ; checkpoint: the music restarted (frame 384)
    NOP
NoMusic:

; --- derive the monitor's colors and the priority pattern ---
    LDA #$02
    STA SfxColor
    LDA #$FF
    STA ActiveBand
    LDA SndActive
    BEQ NoSfxShadow
    LDX SfxID
    LDA SfxColorTbl,X
    STA SfxColor
    LDA BandMap,X
    STA ActiveBand
NoSfxShadow:

    LDA #$02
    STA BandColor0
    STA BandColor1
    STA BandColor2
    LDX ActiveBand
    CPX #3
    BCS NoBandColor
    LDA SfxColor
    STA BandColor0,X
NoBandColor:

    LDA #0
    STA PrioPF0
    STA PrioPF1
    STA PrioPF2
    LDA SndActive
    BEQ NoPriority
    LDA SndPrio
    ASL
    CLC
    ADC SndPrio
    TAX
    LDA PriorityPF,X
    STA PrioPF0
    LDA PriorityPF+1,X
    STA PrioPF1
    LDA PriorityPF+2,X
    STA PrioPF2
NoPriority:

; --- position both players, one HMOVE ---
    LDA #(SFX_X + POS_BIAS)
    JSR SetPos0
    LDA #(CH1_X + POS_BIAS)
    JSR SetPos1

; --- colors ---
    LDA SfxColor
    STA COLUP0
    LDA #$02
    LDX SndActive+1
    BEQ Ch1ColorDone
    LDA #$84                ; blue for the music
    LDX Ch1ID
    CPX #4
    BNE Ch1ColorDone
    LDA #$C8                ; green for the power-up
Ch1ColorDone:
    STA COLUP1
    LDA #$02
    STA COLUBK
    LDA #0
    STA NUSIZ0
    STA NUSIZ1
    LDA #$01
    STA CTRLPF

    +wait_timer

; -----------------------------------------------------------------------------
; VISIBLE — 192 lines, work-first
; -----------------------------------------------------------------------------
    LDA BandColor0          ; band 0's colour before the first visible line
    STA COLUPF
    LDA #$00
    STA VBLANK
    LDA #$F0
    STA PF0
    LDA #$FF
    STA PF1
    STA PF2

    LDX #0
BodyStart:                 ; checkpoint: the first visible line (scanline 37)
BandLoop:
    LDA BandColor0,X
    STA COLUPF
    LDY #8
BandLines:
    STA WSYNC
    DEY
    BNE BandLines
    INX
    CPX #3
    BNE BandLoop

; --- the 4-line gap; the bars are players, the playfield is off ---
    LDA #0
    STA PF0
    STA PF1
    STA PF2
    LDY #4
GapLoop:
    STA WSYNC
    DEY
    BNE GapLoop

; --- two 15-cell meters, 6 lines per cell, top cell (14) down to 0 ---
MeterStart:                ; checkpoint: the first meter line (scanline 65)
    LDX #15
MeterLoop:
    DEX
    CPX SndVol
    LDA #0
    BCS SfxDark
    LDA #$FF
SfxDark:
    STA GRP0
    CPX SndVol+1
    LDA #0
    BCS Ch1Dark
    LDA #$FF
Ch1Dark:
    STA GRP1
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    STA WSYNC
    CPX #0
    BNE MeterLoop

; --- the 4-line gap before the priority bar ---
    LDA #0
    STA GRP0
    STA GRP1
    LDA SfxColor            ; the four gap lines give the colour time to settle
    STA COLUPF
    LDY #4
PrioGap:
    STA WSYNC
    DEY
    BNE PrioGap

; --- the 8-line priority bar ---
    LDA PrioPF0
    STA PF0
    LDA PrioPF1
    STA PF1
    LDA PrioPF2
    STA PF2
PrioStart:                 ; checkpoint: the priority bar (scanline 159)
    LDY #8
PrioLines:
    STA WSYNC
    DEY
    BNE PrioLines
    LDA #0
    STA PF0
    STA PF1
    STA PF2

; --- the bottom background: 62 lines ---
    LDY #62
BottomLoop:
    STA WSYNC
    DEY
    BNE BottomLoop

OverscanStart:
    LDA #$02
    STA VBLANK
    +set_timer OVERSCAN_TIMER
    +wait_timer
    JMP StartFrame

; =============================================================================
; TRIGGER SOUND — A = ID, X = channel; remembers accepted IDs for the monitor
; =============================================================================
TriggerSound:
    PHA
    JSR SoundTrigger
    BCC TriggerReject
    PLA
    CPX #0
    BNE TriggerCh1
    STA SfxID
    RTS
TriggerCh1:
    STA Ch1ID
    RTS
TriggerReject:
    PLA
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
HmoveApply:                ; checkpoint: the WSYNC stall
    STA HMOVE
HmoveDone:                 ; checkpoint: the store has executed
    RTS

; =============================================================================
; SOUND DEFINITIONS — see include/sound.asm for the 8-byte format
; =============================================================================
SoundTable:
    !byte $0C, 12, $90, 1   ; 0 MUSIC, 16 steps, loop, priority 1
    !word MusicFreq, MusicVol
    !byte $0C, 2, 4, 2      ; 1 BLIP, 4 steps, priority 2
    !word BlipFreq, BlipVol
    !byte $04, 2, 6, 5      ; 2 LASER, 6 steps, priority 5
    !word LaserFreq, LaserVol
    !byte $08, 3, 12, 9     ; 3 EXPLOSION, 12 steps, priority 9
    !word BoomFreq, BoomVol
    !byte $04, 3, 8, 8      ; 4 POWERUP, 8 steps, priority 8
    !word PowerFreq, PowerVol

MusicFreq:
    !byte 15,15,14,12,12,14,15,17,19,19,17,15,15,17,17,19
MusicVol:
    !fill 15, 4
    !byte 0

BlipFreq:
    !fill 4, 20
BlipVol:
    !byte 10, 8, 4, 0

LaserFreq:
    !byte 6,8,10,12,14,16
LaserVol:
    !byte 11,11,9,7,5,0

BoomFreq:
    !byte 12,19,7,25,3,30,14,9,22,5,28,16
BoomVol:
    !byte 11,10,9,8,7,6,5,4,3,2,1,0

PowerFreq:
    !byte 20,18,16,14,12,10,8,6
PowerVol:
    !byte 10,10,10,8,8,6,6,4

; =============================================================================
; MONITOR TABLES
; =============================================================================
SfxColorTbl:
    !byte $84, $C8, $1A, $42, $C8        ; MUSIC, BLIP, LASER, BOOM, POWER
BandMap:
    !byte 0, 0, 1, 2, 1                  ; which top band each ID uses

; One 20-bit playfield pattern per priority: N chunks in the left half,
; mirrored by CTRLPF.  PF0 = chunks 0-3, PF1 = 4-11, PF2 = 12-19.
PriorityPF:
    !byte $00, $00, $00    ; priority 0
    !byte $10, $00, $00    ; priority 1
    !byte $30, $00, $00    ; priority 2
    !byte $70, $00, $00    ; priority 3
    !byte $F0, $00, $00    ; priority 4
    !byte $F0, $80, $00    ; priority 5
    !byte $F0, $C0, $00    ; priority 6
    !byte $F0, $E0, $00    ; priority 7
    !byte $F0, $F0, $00    ; priority 8
    !byte $F0, $F8, $00    ; priority 9
    !byte $F0, $FC, $00    ; priority 10
    !byte $F0, $FE, $00    ; priority 11
    !byte $F0, $FF, $00    ; priority 12
    !byte $F0, $FF, $01    ; priority 13
    !byte $F0, $FF, $03    ; priority 14
    !byte $F0, $FF, $07    ; priority 15

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
> `lessons/part5-sound/37-advanced-audio/37-advanced-audio.asm`; the engine lives in
> `include/sound.asm`.

### Code Walkthrough

#### Step 1 — Reset and the music

`+clean_start` zeros the TIA and RAM. `SoundInit` silences both channels, and the first
`TriggerSound` call starts MUSIC on channel 1. The four schedule counters are loaded with their
periods (24, 120, 240, 360 represented as 120 × 3), so the first *scheduled effect* request is at
frame 24; the MUSIC request is the frame-0 exception.

#### Step 2 — The schedule

Each VBLANK decrements one counter. When a counter reaches zero it reloads and calls
`TriggerSound` with the sound ID and channel. The order is LASER, EXPLOSION, POWERUP, BLIP, so the
coincident frames are deterministic. After the requests, the code checks channel 1: if it is
inactive, MUSIC is retriggered. `TriggerSound` saves the ID, calls the engine, and — only when the
engine returns carry set — remembers the ID in `SfxID` or `Ch1ID` for the monitor.

#### Step 3 — The monitor shadows

The active channel-0 color and top band come from `SfxColorTbl` and `BandMap`, indexed by `SfxID`,
but only when `SndActive` is set. The channel-1 color is blue for MUSIC and green for POWERUP. The
priority table index is `SndPrio × 3`; the three bytes are copied into `PrioPF0`/`PrioPF1`/`PrioPF2`
(`$A0–$A2`) for the visible kernel. The three band colours are precomputed into `$A3–$A5`; `LDA BandColor0 / STA COLUPF`
runs before `STA VBLANK`, so the first visible line already has band 0's colour. Without that
preload the first playfield chunks would keep the previous colour for one line.

#### Step 4 — The mixer kernel

The top loop writes `COLUPF` for the active band and holds each band for 8 lines. The meter loop
compares the cell index with `SndVol` and `SndVol+1`, writes `GRP0`/`GRP1`, and holds each cell for
six lines. The priority bar writes the three playfield bytes and holds them for 8 lines. The
bottom 62 lines are background. The last visible line is 228; `OverscanStart` is 229.

#### Step 5 — Reading it back

| Checkpoint | Address | Reports | What it is |
|---|---|---|---|
| `StartFrame` | `$F124` | **259, cycle 3** — a 262-line frame | VSYNC's first line |
| `VblankStart` | `$F132` | 0, cycle 5 | VBLANK's first line |
| `Trigger` | `$F01E` | A = ID, X = channel, one hit per request | the request |
| `Accept` | `$F040` | A = ID, X = channel | the request won the channel |
| `Reject` | `$F06B` | A = ID, X = channel | the request lost the priority test |
| `CtlWrite` | `$F064` | A = `AUDC`, X = channel | the generator write |
| `FreqWrite` | `$F08A` | A = `AUDF`, X = channel | the per-step frequency |
| `VolWrite` | `$F09D` | A = `AUDV`, X = channel | the per-step volume |
| `StepWrite` | `$F0BA` | A = step, X = channel | the engine's step |
| `MusicStart` | `$F18D` | frame 384 | the music retrigger after the power-up |
| `BodyStart` | `$F223` | 37, cycle 26 | the first visible line |
| `MeterStart` | `$F242` | 65, cycle 4 | the first meter line (visible 28) |
| `PrioStart` | `$F286` | 159, cycle 22 | the priority bar (visible 122) |
| `HmoveApply` | `$F2E7` | line 4, cycle 60 | the WSYNC stall; the store executes at line 5, cycle 0 |
| `HmoveDone` | `$F2E9` | line 5, cycle 3 | the store has executed in HBLANK |
| `OverscanStart` | `$F29C` | 229, cycle 4 | overscan's first line |

## What You Should See

The mixer is three colored bands, two vertical meters, and a priority bar on a dark field.

**LASER.** The second band is gold. The channel-0 meter is a gold bar at capture x = 313–360,
y ≈ 308–478 — **9 cells** in this capture, which is two steps into the sweep; the first step is 11
cells (y ≈ 270–478). The channel-1 meter is a blue bar of **4 cells** at x = 697–744, y ≈ 403–478.
The priority bar is gold and **5 chunks per half** (x ≈ 25–144 on the left, mirrored on the right).

![Stella running the Lesson 37 ROM during the laser: a gold second band, a 9-cell gold channel-0 meter, a 4-cell blue channel-1 meter, and a 5-chunk priority bar](/images/lesson37/laser.png)

*The LASER at priority 5: band 1 gold, channel 0 at 9 cells (two steps into the sweep; the first step
is 11), channel 1 at 4 cells (music), and a 5-chunk priority bar.*

**EXPLOSION.** The third band is red, and the channel-0 meter is a red bar at capture y ≈ 346–478 —
**7 cells** in this capture, which is a few steps into the 36-frame decay; the first step is 11
cells (y ≈ 270–478). The channel-1 meter is still the blue 4-cell music bar, and the priority bar
is red at **9 chunks per half** (x ≈ 25–240).

![Stella running the Lesson 37 ROM during the explosion: a red third band, a 7-cell red channel-0 meter, a 4-cell blue channel-1 meter, and a 9-chunk priority bar](/images/lesson37/explosion.png)

*The EXPLOSION at priority 9 a few steps into its decay: band 2 red, channel 0 at 7 cells, channel 1
at 4 cells, and a 9-chunk priority bar.*

<RomPlayer rom="/roms/part5-sound/37-advanced-audio/37-advanced-audio.bin" title="Lesson 37 — Advanced Audio" />

Click the player screen once: Javatari starts muted until a user gesture. The picture and the
sound are produced by the same engine state.

The debugger writes the same story as numbers:

```bash
acme -f plain -l build/lesson37.sym -o build/lesson37.bin \
  lessons/part5-sound/37-advanced-audio/37-advanced-audio.asm
grep -E "Trigger|Accept|Reject|StepWrite" build/lesson37.sym

stella -audio.enabled 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$F06B' \
  docs/public/roms/part5-sound/37-advanced-audio/37-advanced-audio.bin
```

- **`$F01E` (`Trigger`)**: one hit per request; A = ID, X = channel.
- **`$F040` (`Accept`)**: A=0 X=1 at frame 0 (MUSIC); A=1 X=0 at 24, 48, … (BLIP); A=2 X=0 at 120
  (LASER); A=3 X=0 at 240 (EXPLOSION); A=4 X=1 at 360 (POWERUP); A=0 X=1 at 384 (MUSIC restart).
- **`$F06B` (`Reject`)**: A=1 X=0 at 120, 240, 264, and 360 — the BLIP losing to the LASER, the
  EXPLOSION, and the LASER again.
- **`$F0BA` (`StepWrite`)**: A advances per sound's rate and X identifies the channel.
- **`$F18D` (`MusicStart`)**: one hit at frame 384, when the power-up frees channel 1.
- **`$F242` (`MeterStart`)**: line 65; the meters are 90 lines tall.

## Exercises

### Exercise 1: Add a Zap

**Challenge:** add a sixth sound, ZAP, with `AUDC=$0C`, Rate 2, 5 steps, priority 6, frequency
`18,16,14,12,10`, volume `10,9,8,7,6`; trigger it every 60 frames on channel 0.

**Hints:**
1. Add the sixth 8-byte record to `SoundTable` and the `ZapFreq`/`ZapVol` tables.
2. Use `$8E` for a 60-frame `ZapTimer`; the library leaves `$8E–$8F` free for the caller, and the
   priority bytes live at `$A0–$A2`.
3. ZAP priority 6 is higher than LASER's 5, so a ZAP can preempt a laser; it is still lower than
   EXPLOSION's 9.

**Expected Result:** `Accept` reports A=5 on the 60-frame ticks while channel 0 is free; the
channel-0 meter follows 10→9→8→7→6 cells; the top band is LASER's band (the ZAP maps to band 1);
the priority bar is 6 chunks per half. A ZAP that comes due during an explosion (frames 240, 480)
is rejected; at 120 and 360 the ZAP replaces the LASER in the same VBLANK, so the LASER is not heard.

**Solution:** See `exercise-01-solution.asm`

### Exercise 2: Priority Inversion

**Challenge:** change BLIP's priority from 2 to 10. Predict what happens at frame 240, when the
BLIP and the explosion both request channel 0.

**Hints:**
1. The priority is byte +3 of the BLIP definition.
2. The comparison is strict: 10 > 9, so the BLIP now wins.
3. The explosion is replaced, not mixed: the channel has one active sound.

**Expected Result:** `Accept` reports A=1 at frame 240: the BLIP replaces the explosion (10 > 9)
instead of losing to it. The channel-0 meter turns green and the priority bar shows 10 chunks per
half. At frame 264 the BLIP is accepted because the channel is free (the 240 BLIP has ended), not
because it won a priority test. The BLIP also beats the ZAP (10 > 6); the inversion changes who
owns channel 0, so no rejection remains in the schedule.

**Solution:** See `exercise-02-solution.asm`

### Exercise 3: Music Ducking *(Stretch Goal)*

**Challenge:** while an explosion is active (channel 0 priority ≥ 9), lower the music volume to 2;
restore it when the explosion ends. Do not duck a power-up.

**Hints:**
1. After the triggers, test `SndActive`, `SndPrio ≥ 9`, and `Ch1ID=0` (music, not power-up).
2. Write `AUDV1=2` and `SndVol+1=2` so the meter shows the duck; otherwise let the engine's
   volume stand.
3. The music's next step writes 4 again; the duck is re-applied every frame while the explosion is
   active.

**Expected Result:** during the explosion the channel-1 meter drops to 2 cells; after the
explosion, the next music step restores it to 4. The power-up at frame 360 keeps its own 10-cell
meter. The channel-0 bars and the priority bar are unchanged.

**Solution:** See `exercise-03-solution.asm`

## Key Takeaways

- ✅ **A sound is data**: eight bytes — timbre, rate, length/loop, priority, and two table pointers
- ✅ **Per-step tables are the expression**: the engine reads `freq[step]` and `vol[step]`; a sweep, a noise decay, and a melody are all just tables
- ✅ **Priority is the scheduling policy**: a channel has one sound; a strictly higher priority may replace it, and an equal or lower request is rejected
- ✅ **The engine mutes its own endings**: `SoundUpdate` writes `AUDV=0` and frees a non-looping channel at the last step
- ✅ **Two channels need a plan**: the music loops on channel 1; the effects share channel 0 and the schedule orders coincident requests
- ✅ **The debugger proves the policy**: `Accept` and `Reject` carry the sound ID and the channel; the frame-264 rejection is the witness
- ✅ **The mixer is the engine's state**: bands, two meters, and a priority bar are all driven by `SndActive`, `SndVol`, and `SndPrio`

## What's Next

Part 5 ends here: the TIA's two audio channels now have a data-driven engine, a priority policy,
and a monitor that shows the state. [Lesson 38: Collision Detection](/part6-game-dev/38-collision-detection)
opens Part 6 with the TIA's collision latches — the hardware that tells a game when two objects
touch, and the input to the score, the hit sound, and the game-over state.
