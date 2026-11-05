# Lesson Specifications: Part 5 — Sound (Lessons 35–37)

> **Document**: 03-lesson-specs.md
> **Parent**: [Index](00-index.md)
> **Authority**: this document owns the per-lesson design; [07-testing-strategy.md](07-testing-strategy.md)
> owns the ST cases, and [00-ambiguity-register.md](00-ambiguity-register.md) owns the decisions.

## Shared Conventions

### Frame and Video

- NTSC only: `VSYNC` 3 + `VBLANK` 37 + picture 192 + overscan 30 = **262 lines**.
- `+set_timer 44` and `+wait_timer` cover VBLANK; `+set_timer 36` and `+wait_timer` cover overscan.
  The timer is armed about 15 cycles into the line and covers 2,753 cycles, so it expires at
  2,768; the final `+wait_timer` WSYNC absorbs the remaining 44 cycles to the 37-line
  (2,812-cycle) boundary. A VBLANK ledger budgets **2,812 cycles**, not 2,753.
- The picture begins at scanline 37 (visible line 0 = capture y 107) and ends at scanline 228.
- Capture mapping used by every pixel check: `capture x = 25 + 6 × TIA_X`, `capture y = 107 +
  3.15 × visible_line`. A sprite's first visible row is the scanline where its `GRP` write is
  latched.
- **Kernel order:** every full-screen kernel is **work-first** — write the line's registers, then
  `STA WSYNC`. The first work line is scanline 37, the last is 228, and `OverscanStart` is 229. A
  WSYNC-first loop adds a line: the scratch Lesson 36 prototype measured `OverscanStart` at 230, a
  263-line frame, until the loop was reordered. Session C checks the frame before accepting a
  capture.
- Two-object positioning: set every coarse `RESxx` and every `HMxx` value first, then strobe one
  `HMOVE` (the one-HMOVE rule). The final `STA WSYNC` sits immediately after the last `STA RESPx`,
  with `STA HMOVE` next. Report `HmoveApply` (the WSYNC stall) and a `HmoveDone` checkpoint after
  the store: the scratch prototype measured `HmoveApply` at line 2 cycle 60 and `HmoveDone` at
  line 3 cycle 3, with the markers at the expected X. The measured X is authoritative; the target
  includes the `+3` bias used by `SetHorizPos`.

### Audio Arithmetic

The NTSC audio clock is **31,399.5 Hz** (3.579545 MHz / 114). A pure tone is:

```
f = 31399.5 / ((AUDF + 1) × D)
```

`AUDF` is a **5-bit field, 0–31**. `AUDC` selects the generator and the divisor `D`:
`4/5 → 2`, `6/A → 31`, `C/D → 6`, `E → 93`; the noise types (`1/2/3/7/8/9/F`) have no single
tone frequency. `AUDV` 0–15 sets the volume; `AUDV=0` mutes and `AUDC=0` disables the channel. The
two channels sum, so the lessons keep the combined volume at or below 15 (a 15 SFX plus a 4 music
is the ceiling; the ducking exercise lowers the music to 2).

### Evidence

- Audio claims are evidenced by a breakpoint placed **after** the store to `AUDC0/1`, `AUDF0/1`, or
  `AUDV0/1`; the log's A column is the value written and the X column identifies the channel. A
  static ledger checks the VBLANK cost.
- Visual claims are evidenced by a screenshot from the committed ROM and a pixel check against the
  geometry above.
- A screenshot never proves the sound; the committed ROM and the `<RomPlayer>` are the audible
  artifact (AR-6, AR-22). The lesson documents say this, and tell the reader to click the player
  screen once: Javatari starts muted until a user gesture. The ROM's audio is not disabled by
  `-sound 0` during captures; that flag only silences the emulator host.

### Lesson Document Template

Every lesson document follows the fixed six-section template (the Part 1–4 pattern):
frontmatter (`title`, `description`, `prev`, `next`), the meta block (Part, estimated time,
prerequisites, "You will learn", "You will build"), Introduction with a `::: details TypeScript
Equivalent` block, Theory, The Code (Building, Full Source **verbatim** from the `.asm`, Code
Walkthrough, checkpoint table), What You Should See (two images + `<RomPlayer>` + debugger
commands), Exercises (three, each with Challenge/Hints/Expected Result/Solution), Key Takeaways
(≤ 7), and What's Next. Each lesson's TypeScript block is:
- Lesson 35: a per-frame envelope state machine over an effect table.
- Lesson 36: a note table plus a duration counter driving two voices.
- Lesson 37: a priority queue that assigns sounds to two channels.

### Shared RAM Map

| Range | Owner | Contents |
| --- | --- | --- |
| `$80–$87` | lesson | counters, shadows, marker positions, effect state |
| `$88–$8F` | engine scratch (Lesson 37 only) | ID, channel, definition pointer, table pointer |
| `$90–$9F` | engine state (Lesson 37 only) | two channels × 8 bytes: definition pointer (2), timer, step, priority, active, freq shadow, volume shadow |

`+clean_start` zeros all of it. Lessons 35–36 use only `$80–$87`. The engine stores only the
definition pointer; the per-step frequency/volume table pointers are re-read into `$88–$8F` on
each step, so the state fits exactly 16 bytes.

## Lesson 35: Sound Effects — Beeps, Boops, and Explosions

- **Goal:** program `AUDC`, `AUDF`, and `AUDV` directly and shape three classic effects over time.
- **Concepts:** the audio divider chain; tone versus noise; volume as an envelope; a per-frame
  effect state machine; a frame counter as the effect clock; auto-cycling so the ROM demonstrates
  itself.
- **ROM:** `35-sound-effects.asm` — "the sound lab".
  - Three full-width playfield bands, 8 visible lines each (visible 0–23): BEEP, BOOP, BOOM. The
    active band uses the effect color, the others `$02`; `CTRLPF=$01`, `PF0=$F0`, `PF1=$FF`,
    `PF2=$FF`; `COLUPF` changes per band.
  - A 15-cell vertical VU meter (6 visible lines per cell, visible 28–117) drawn by player 0 at
    X=24; cell 14 is the top, cell 0 the bottom; a cell is lit when its index is below the current
    volume; `GRP0=$FF` for lit cells and `$00` for dark cells; `COLUP0` = effect color.
  - A pitch band (visible 118–133): 4 blank lines, 8 marker lines, 4 blank lines. Player 1 is an
    8-row marker at X = `24 + AUDF × 4` (AUDF 0–31 → X 24–148); `COLUP1` = effect color.
  - Bottom 58 visible lines (134–191) are the dark background.
  - Colors: BEEP `$C8` green, BOOP `$84` blue, BOOM `$42` red; `COLUBK=$02`; inactive bands `$02`.
  - The ROM auto-cycles: BEEP 32 frames, BOOP 32, BOOM 48, repeat. `EffectFrame` starts at `$FF` so
    the first increment is 0; `COLUP0` and `COLUP1` are set from `EffectColor` each frame, so the
    VU bar and pitch marker always match the active band. No input is required; the exercises add
    it.
  - Exact effect tables (the implementation authority):

    | Effect | `AUDC` | `AUDF` | Volume envelope | Length |
    |---|---|---|---|---|
    | BEEP | `$0C` (div 6) | `$13` (19 → 261.66 Hz) | 15 for 10 frames, 12 for 5, 8 for 5, 0 for 12 | 32 |
    | BOOP | `$04` (div 2) | `min(20, 6 + frame/2)` (2242.8 → 747.6 Hz) | 12 for 24 frames, 8 for 4, 0 for 4 | 32 |
    | BOOM | `$08` (9-bit poly) | `BoomFreq[frame & 15]` = `12,19,7,25,3,30,14,9,22,5,28,16,1,24,11,19` | `15 − frame/3` (15 → 0, 3 frames per level) | 48 |

  - The BOOM's `AUDF` changes the noise generator's divider, not a tone frequency; the doc says so.
  - The VU bar's height is `volume × 6` visible lines; the pitch marker's capture x is
    `169 + 24 × AUDF`.
- **Expected screen:** at the BEEP sustain, band 0 is green, bands 1–2 dark, the VU bar is 15
  green cells (90 visible lines ≈ 284 capture px, y≈195–478), and the pitch marker is green at
  capture x = 625 (AUDF 19, X=100), y≈491–517. At the BOOM's first step, band 2 is red, the VU bar
  is 15 red cells (the first step's volume is 15), and the pitch marker is red at capture x =
  169 + 24×12 = 457; the capture used in the doc records the exact step and height.
- **Demo ROM:** none — the sound lab is the visible picture (AR-3).
- **Exercises:**
  1. **Raise the beep.** Change the BEEP `AUDF` from `$13` to `$09` (523.33 Hz). Expected: the
     pitch marker sits at capture x = 169 + 24×9 = 385; `FreqWrite` reports A=`$09` during BEEP.
  2. **Siren boop.** Replace the BOOP sweep with a two-pitch alternation: `AUDF` 6 for 4 frames,
     20 for 4 frames, repeating; volume stays 12 for 24 frames, then 0. Expected: the pitch marker
     jumps between capture x = 313 (X=48) and 649 (X=104); `FreqWrite` alternates A=`$06`/`$14`.
  3. *(Stretch)* **Sound board.** Read `SWCHA` bits 6 (left) and 7 (right), active low, and
     `INPT4` bit 7 (fire): left/right selects an effect, fire restarts it, and the auto-cycle
     resumes after 120 frames with no input. Expected: the selected band brightens; fire writes
     the effect's registers; `EffectID` changes on input or when the auto-cycle resumes.
- **Screenshots:** `docs/public/images/lesson35/beep.png`, `…/boom.png`.
- **Evidence pins:** frame checkpoints; `EffectStep` — A = the new effect ID at the cycle boundary;
  `CtlWrite` — A = `AUDC` (one hit per frame); `FreqWrite` — A = `AUDF`; `VolWrite` — A = `AUDV`;
  `BodyStart` at line 37; `HmoveApply`/`HmoveDone` once per frame; the capture bars and marker.
- **Integration:** prev → Lesson 34; next → Lesson 36; part-index row 35 → ✅ Complete linking
  `./35-sound-effects`; sidebar entry exists (`config.ts:100`). Estimated time: 60 minutes.
- **ST cases:** ST-35.1 assembly & drift · ST-35.2 monitor layout · ST-35.3 effect recipes ·
  ST-35.4 debugger state and ledger · ST-35.5 solutions and screenshots · ST-35.6 site integration.

## Lesson 36: Music — Melodies on the TIA

- **Goal:** play a melody from a note table on two channels with frame-based timing, and show the
  current notes on a ladder.
- **Concepts:** a note table maps scale degrees to `AUDF`; the TIA's integer dividers make equal
  temperament approximate; a duration counter advances a note; two channels play lead and harmony;
  the visual marker's vertical position is the scale degree, not the raw frequency; the `AUDF`
  field is only 5 bits, so the deepest notes need a coarser divisor.
- **ROM:** `36-music.asm` — "the music box".
  - An 8-rung ladder at visible lines 16, 36, 56, 76, 96, 116, 136, 156 (16 + 20·k), plus a
    ninth baseline at 176; each rung is a 1-line playfield line, `COLUPF=$0A`; `CTRLPF=$01`,
    `PF1=$FF`/`PF2=$FF` on the rung line and cleared on the next, `PF0=0` (768 capture px, 16-px
    margins).
  - Lead marker: player 0, 8 rows, X=48, red `$42`; harmony marker: player 1, 8 rows, X=112, blue
    `$84`. Marker top = rung line − 4 (the 8 rows straddle the rung); a rest sets the top to
    `$F0`, which never matches a visible line, hiding the marker.
  - `COLUBK=$02`; the grid is dim gray; no other objects.
  - Audio:
    - `AUDC0=$0C` (div 6) lead; `AUDC1=$0D` (div 6) harmony. Both registers are written once in
      `Reset`, before the first note; `AUDC=0` would disable the channel and leave the `AUDF`/`AUDV`
      writes silent. Both channels use the same C4–C5 table; the harmony plays C4/G4, below the
      melody's upper notes.
    - `NoteFreq` for C4–C5: `19, 17, 15, 14, 12, 11, 10, 9`. The calculated frequency and cents
      error for every entry:

      | Degree | `AUDF` | Hz | Error |
      |---|---|---|---|
      | C4 | 19 | 261.66 | +0.2 ¢ |
      | D4 | 17 | 290.74 | −17.4 ¢ |
      | E4 | 15 | 327.08 | −13.4 ¢ |
      | F4 | 14 | 348.88 | −1.7 ¢ |
      | G4 | 12 | 402.56 | +46.0 ¢ |
      | A4 | 11 | 436.10 | −15.4 ¢ |
      | B4 | 10 | 475.75 | −64.8 ¢ |
      | C5 | 9 | 523.33 | +0.2 ¢ |

    - A true C3 bass is not reachable with div 6: `AUDF` would need 39, outside the 0–31 field.
      Div 31 reaches C3 at `AUDF` 7 (126.61 Hz, −56.5 ¢), which is noticeably flat. The lesson
      keeps both voices on div 6 and calls the lower voice a **harmony**, not a bass; it names the
      trade-off explicitly instead of hiding an out-of-range value.
    - Lead sequence (16 steps, scale indices, `$FF` = rest): `2,2,3,4,4,3,2,1,0,0,1,2,2,1,1,$FF`
      — the first phrase of "Ode to Joy" (public domain). Each step lasts 12 frames (192 frames ≈
      3.2 s). The rest re-uses C4's `AUDF` (19) with volume 0, so the frequency log still ends on
      19 and the marker is hidden.
    - Harmony sequence (4 steps, scale indices): `0,4,0,4` — C, G, C, G, each held
      `4 × NOTE_FRAMES = 48` frames. The harmony uses the same `NoteFreq` table.
    - Lead volume 8 (0 on the rest); harmony volume 6. `AUDV`/`AUDF` are written when a note
      changes, not every frame. The lead and harmony sequences both loop at 192 frames.
- **Expected screen:** two 8-row markers on the ladder. In the first capture the lead is on E
  (rung 2, capture y≈271–296) and the harmony on C (rung 0, capture y≈145–170); in the second the
  lead is on G (rung 4, capture y≈397–424) and the harmony on G (y≈397–420). The exact measured
  pair is recorded in Session C.
- **Demo ROM:** none — the note ladder is the visible picture (AR-3).
- **Exercises:**
  1. **Change the tempo.** `NOTE_FRAMES` 12 → 6 (double speed) or 24 (half speed); keep
     `HARMONY_FRAMES = 4 × NOTE_FRAMES`. Expected: `LeadStep` fires every 6 or 24 frames and
     `HarmonyStep` every 24 or 96; the markers change at the new rate.
  2. **Change the harmony.** Use `0,2,0,2` (C, E) instead of `0,4,0,4` (C, G). Expected:
     `HarmonyFreqWrite` A=19,15; the blue marker moves to rung 2.
  3. *(Stretch)* **Rest and repeat.** After the 16th lead step, hold silence for 60 frames, then
     restart both sequences. Expected: both markers disappear for 60 frames (frames 180–239;
     `LeadTop=$F0`, `PauseTopWrite` A=`$F0`, `PauseVolWrite` A=0), the phrase restarts at frame
     240, and the next `LeadStep` is at 252 (A=1).
- **Screenshots:** `docs/public/images/lesson36/notes-a.png`, `…/notes-b.png`.
- **Evidence pins:** frame checkpoints; `AUDC0Write`/`AUDC1Write` — A=`$0C`/`$0D` on the first
  frame; `LeadStep` — A = the new lead index, one hit every 12 frames; `HarmonyStep` — A = the new
  harmony index, one hit every 48 frames; `LeadFreqWrite` — A = the lead `AUDF`; `LeadVolWrite` —
  A = 8 on every lead note; `LeadRestFreq`/`LeadRestVol` — A=19/0 on the rest;
  `HarmonyFreqWrite`/`HarmonyVolWrite`; `BodyStart` at 37 (the ladder body covers all 192 lines);
  `HmoveApply`/`HmoveDone` once per frame; the capture marker rows.
- **Integration:** prev → Lesson 35; next → Lesson 37; part-index row 36 → ✅ Complete linking
  `./36-music`; sidebar entry exists (`config.ts:101`). Estimated time: 75 minutes.
- **ST cases:** ST-36.1 assembly & drift · ST-36.2 ladder layout · ST-36.3 note tables and tuning ·
  ST-36.4 debugger state and ledger · ST-36.5 solutions and screenshots · ST-36.6 site integration.

## Lesson 37: Advanced Audio — Sound Engine Design

- **Goal:** build a small data-driven sound engine with two channels and priority, and show its
  state in a mixer.
- **Concepts:** a sound is data (timbre, rate, length, priority, per-step frequency and volume);
  a definition is 8 bytes; a channel owns one active sound; a higher priority replaces, an equal or
  lower priority is rejected; a looping sound (music) runs on one channel while effects use the
  other; a mixer visual exposes volume and priority; a non-looping sound ends by writing `AUDV=0`.
- **Library:** `include/sound.asm` (AR-7, AR-18).
  - Definition (8 bytes): `+0 AUDC`, `+1 Rate` (frames per step), `+2 Steps` (bit 7 = loop; low 7
    bits = count), `+3 Priority` (0–15), `+4/+5` frequency-table pointer, `+6/+7` volume-table
    pointer.
  - API:
    - `SoundInit` — silence both channels and clear state.
    - `SoundTrigger` — A = sound ID, X = channel (0/1); returns C=1 if accepted, C=0 if rejected.
    - `SoundUpdate` — call once per frame; advances both channels' steps and writes `AUDF`/`AUDV`.
      On the final step of a non-looping sound it writes `AUDV=0`, clears the channel's active
      flag, and leaves the shadow volume at 0. The last table entry is not relied on to mute.
    - `SoundStop` — X = channel; silence and free it.
  - State at `$90–$9F` (8 bytes/channel: definition pointer, timer, step, priority, active, freq
    shadow, volume shadow); scratch at `$88–$8F` (`$8E–$8F` free for the caller). `SoundTrigger`
    preserves X (the channel) on return. One active sound per channel; a new sound with priority
    strictly greater than the active one replaces it; equal or lower is rejected. The monitor uses
    `$A0–$A5` for its priority/band bytes, outside the engine's block. Preemption-with-resume is
    named as a later refinement, not implemented (AR-18).
- **ROM:** `37-advanced-audio.asm` — "the mixer".
  - Sound table (IDs 0–4):

    | ID | Name | `AUDC` | Rate | Steps | Priority | Frequency table | Volume table |
    |---|---|---|---|---|---|---|---|
    | 0 | MUSIC | `$0C` | 12 | `$90` (16, loop) | 1 | `15,15,14,12,12,14,15,17,19,19,17,15,15,17,17,19` | fifteen 4s, 0 |
    | 1 | BLIP | `$0C` | 2 | 4 | 2 | `20,20,20,20` | `10,8,4,0` |
    | 2 | LASER | `$04` | 2 | 6 | 5 | `6,8,10,12,14,16` | `11,11,9,7,5,0` |
    | 3 | EXPLOSION | `$08` | 3 | 12 | 9 | `12,19,7,25,3,30,14,9,22,5,28,16` | `11,10,9,8,7,6,5,4,3,2,1,0` |
    | 4 | POWERUP | `$04` | 3 | 8 | 8 | `20,18,16,14,12,10,8,6` | `10,10,10,8,8,6,6,4` |

  - The combined volume stays at or below 15: MUSIC 4 and the loudest SFX 11; the ducking exercise
    lowers MUSIC to 2 during the explosion.
  - Demo schedule: the counters start at their periods, so the first requests are BLIP at frame
    24, LASER at 120, EXPLOSION at 240, POWERUP at 360 (all channel 0 except POWERUP on channel 1).
    The VBLANK order checks LASER, then EXPLOSION, then POWERUP, then BLIP, so coincident frames
    are deterministic. MUSIC starts on channel 1 at reset; when channel 1 is free again, MUSIC is
    retriggered (frame 384 after the first POWERUP). A BLIP request during the explosion is
    rejected and logged; a BLIP request at a LASER frame is rejected because the LASER is handled
    first.
  - Visual: three top bands (8 lines each) for BLIP, LASER, EXPLOSION — active band in the effect
    color, others `$02`; a 15-cell VU bar for channel 0 (player 0, X=48) and channel 1 (player 1,
    X=112), 6 lines per cell; a priority bar at visible 122–129 (8 lines) drawn from a 16-entry
    playfield table (three bytes per entry: `PF0`, `PF1`, `PF2`; the left half lights N chunks for
    priority N, and `CTRLPF=$01` mirrors it, so the visible bar is N chunks per half), in the
    effect color; `COLUBK=$02`.
  - Colors: BLIP `$C8` green, LASER `$1A` gold, EXPLOSION `$42` red; channel 1 is blue `$84` for
    MUSIC and green `$C8` for POWERUP; inactive bands `$02`. The lesson keeps an `SfxID` shadow
    (set when a channel-0 trigger is accepted) and a `Ch1ID` shadow (channel 1), because the engine
    stores priority but not the sound ID; when a channel is inactive, its bar is 0 and the top
    bands are dark.
- **Expected screen:** at the EXPLOSION's first step, band 2 is red, the channel-0 bar is red at
  11 cells, the channel-1 bar is blue at 4 cells, and the priority bar is 9 chunks per half. At
  the LASER's first step, band 1 is gold, the channel-0 bar is gold at 11 cells, the channel-1 bar
  is blue at 4 cells, and the priority bar is 5 chunks per half. The committed captures are a few
  steps in: LASER 9 cells (y≈308–478), EXPLOSION 7 cells (y≈346–478); the doc records both the
  first-step values and the captured step.
- **Demo ROM:** none — the mixer is the visible picture (AR-3).
- **Exercises:**
  1. **Add a zap.** Add ID 5 (`AUDC=$0C`, Rate 2, 5 steps, priority 6, freq `18,16,14,12,10`,
     vol `10,9,8,7,6`) and trigger it every 60 frames on channel 0. Expected: `Accept` A=5 on the
     60-frame ticks while channel 0 is free; the sound has 5 steps; the channel-0 bar follows
     10→9→8→7→6 cells; the top band maps to LASER's band; the priority bar is 6 chunks per half.
     ZAP priority 6 preempts the LASER (5) at 120/360 and is rejected by the EXPLOSION (9) at
     240/480.
  2. **Priority inversion.** Change BLIP's priority from 2 to 10. Expected: at frame 240 the BLIP
     replaces the EXPLOSION (`Accept` A=1; 10 > 9); the channel-0 bar turns green and the priority
     bar is 10 chunks per half. At frame 264 the BLIP is accepted because the channel is free, not
     from a priority win. The BLIP also beats ZAP (10 > 6); the inversion changes who owns channel
     0. Run the exercise on the lesson ROM without ZAP.
  3. *(Stretch)* **Music ducking.** After `SoundUpdate`, if channel 0 is active with priority ≥ 9,
     write `AUDV1=2`; otherwise write `SndVol+1` (channel 1's current volume). Expected: the
     channel-1 bar drops to 2 cells while the explosion is active and returns to 4 after it ends.
- **Screenshots:** `docs/public/images/lesson37/laser.png`, `…/explosion.png`.
- **Evidence pins:** frame checkpoints; `Trigger` — A = ID, X = channel, one hit per request;
  `Accept`/`Reject` — A = ID; `CtlWrite` — A = `AUDC`, X = channel; `FreqWrite` — A = `AUDF`, X =
  channel; `VolWrite` — A = `AUDV`, X = channel; `StepWrite` — A = the step index, X = channel;
  `MusicStart` — one hit at frame 384; `BodyStart` at 37; `HmoveApply`/`HmoveDone` once per frame
  (`HmoveApply` line 4 c60; `HmoveDone` line 5 c3); the capture bars, priority bar, and bands.
- **Integration:** prev → Lesson 36; next → `/part6-game-dev/38-collision-detection` (the real
  Part 6 stub); part-index row 37 → ✅ Complete linking `./37-advanced-audio`; sidebar entry exists
  (`config.ts:102`). Estimated time: 90 minutes.
- **ST cases:** ST-37.1 assembly & drift · ST-37.2 mixer layout · ST-37.3 engine steps and priority
  · ST-37.4 debugger state and ledger · ST-37.5 solutions and screenshots · ST-37.6 site
  integration.

## Cross-Lesson Consistency

- **Progression:** Lesson 35 writes the registers directly; Lesson 36 adds the note table and
  duration counters; Lesson 37 generalizes both into the engine. No lesson uses a later lesson's
  mechanism in code.
- **Naming:** the main sources are `35-sound-effects.asm`, `36-music.asm`, `37-advanced-audio.asm`;
  solutions are `exercise-01-solution.asm`, `exercise-02-solution.asm`, `exercise-03-solution.asm`.
- **Visual language:** the same 15-cell meter, 8-row marker, and effect colors recur across the
  three monitors, so the reader recognizes the state at a glance.
- **Audio honesty:** every tone claim cites the formula and the written `AUDF`; noise claims name
  the generator and do not pretend to a frequency; the screenshot is never described as proof of
  sound.
- **Part 5 index:** rows 35–37 with What You'll Learn summaries; row 35 flips in Phase 1, row 36 in
  Phase 2, row 37 in Phase 3; rows 36–37 start `🔒 Coming Soon` (AR-10).
