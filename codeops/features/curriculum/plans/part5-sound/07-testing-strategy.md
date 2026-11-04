# Testing Strategy: Part 5 — Sound (Lessons 35–37)

> **Document**: 07-testing-strategy.md
> **Parent**: [Index](00-index.md)

## Testing Overview

This repository ships static lesson content and ROMs; there is no test framework, and none is
added (AR-7). The specification tests are **observational acceptance cases**: every ST row names
a concrete action (assemble, run, inspect, capture, break) and a concrete expected outcome that a
human or recorded command output can confirm. Session A freezes the rows for its lesson before
implementation and records the red baseline; Session C confirms every row and records the evidence
(AR-2, AR-4).

Expected outcomes here derive only from [03-lesson-specs.md](03-lesson-specs.md) and the register
ground truth — never from the implementation (immutable-oracle rule). If an implementation
disagrees with an ST row, the implementation is wrong.

**Evidence methods:** `bash scripts/verify.sh` output (assembly + drift + docs build); screenshots
captured from the committed ROM path and pixel-checked against the monitor geometry
(`x = 25 + 6·X`; `y = 107 + 3.15·visible_line`; picture rows 107–711); timed waits/bursts for
moving or switching states; and Stella state logs
(`stella -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'`, format
`BP: <frame> <scanline> <cycles> <pixels> | <flags> <A> <X> <Y> <SP> |`) with static cycle ledgers.
Audio rows use a breakpoint placed immediately after the store to `AUDC`/`AUDF`/`AUDV`; the A
column is the value written and the X column is the channel (AR-6, AR-22).

> A screenshot proves the visual state only. The audible artifact is the committed ROM and the
> `<RomPlayer>`; the tests below never claim otherwise. The lesson docs tell the reader to click
> the player screen once to unmute Javatari.

## 🚨 Specification Test Cases (frozen per lesson in Session A)

### Lesson 35

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-35.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output + file size | RD-05 AC 1–2 / AR-4 |
| ST-35.2 | Run the ROM; inspect the monitor during the BEEP and the first BOOM step | BEEP: band 0 green `$C8`, bands 1–2 `$02`; VU bar 15 green cells at capture x=169–216, y≈195–478; pitch marker green at capture x=625–672, y≈491–517; BOOM first step: band 2 red `$42`, VU bar 15 red cells, pitch marker red at capture x=457–504; background `$02`. The capture used in the doc records the exact step and height | Screenshots `beep.png`, `boom.png` + pixel check | 03 §Lesson 35 |
| ST-35.3 | Inspect the BEEP, BOOP, and BOOM recipes in the state log | `CtlWrite` A=`$0C`/`$04`/`$08` (one per frame); BEEP: `FreqWrite` A=`$13`, `VolWrite` A walks 15 (10 frames) → 12 (5) → 8 (5) → 0 (12); BOOP: `FreqWrite` A=6,6,7,7,…,20, `VolWrite` 12→8→0; BOOM: `FreqWrite` A follows `12,19,7,25,3,30,14,9,22,5,28,16,1,24,11,19`, `VolWrite` 15→0 three frames per level | State log + static ledger | RD-05 AC 3 / 03 §Lesson 35 |
| ST-35.4 | Debugger: frame checkpoints and effect steps | `StartFrame` 259, `VblankStart` 0, `VisibleStart` 37, `OverscanStart` 229 (262 lines); `BodyStart` line 37; `EffectStep` A=1 at frame 32, A=2 at 64, A=0 at 112, A=1 at 144; `HmoveApply`/`HmoveDone` once per frame | State log + static ledger (AR-6) | RD-05 AC 3 / 03 §Lesson 35 |
| ST-35.5 | Assemble and run each solution | Ex 1: pitch marker at capture x=385, `FreqWrite` A=`$09`; ex 2: marker jumps between x=313 and 649, `FreqWrite` alternates `$06`/`$14`; ex 3: `SWCHA` bits 6/7 select, fire triggers, auto-cycle resumes after 120 idle frames | `verify.sh` + manual runs + captures | RD-05 AC 1 / AR-21 |
| ST-35.6 | Build the site and inspect the page | Part index row 35 ✅ Complete linking `./35-sound-effects`; page prev 34, next 36; both images and `<RomPlayer>` on the committed ROM render; sidebar entry `config.ts:100`; README unchanged | `npm run docs:build` + page check | RD-05 AC 1 / AR-10 |

### Lesson 36

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-36.1 | Assemble the lesson source and its three solutions; run `verify.sh` | Each assembles to exactly 4,096 bytes; no ROM drift; docs build passes | `verify.sh` output + file size | RD-05 AC 1–2 / AR-4 |
| ST-36.2 | Run the ROM; inspect the ladder | Eight 1-line rungs at capture y≈157, 220, 283, 346, 409, 472, 535, 598, color `$0A`; two 8-row markers (red lead at x=313, blue harmony at x=697) on the rungs of the current notes; in the first capture the lead is on E (rung 2, y≈271–296) and the harmony on C (rung 0, y≈145–170); in the second the lead is on G (rung 4, y≈397–422) and the harmony on G (same rows); background `$02` | Screenshots `notes-a.png`, `notes-b.png` + pixel check | 03 §Lesson 36 |
| ST-36.3 | Inspect the note tables and tuning | All `AUDF` values are 0–31; `NoteFreq` is `19,17,15,14,12,11,10,9` for C4–C5; `LeadFreqWrite` A follows `15,15,14,12,12,14,15,17,19,19,17,15,15,17,17,19` (the rest re-uses 19 with volume 0); `HarmonyFreqWrite` A follows `19,12,19,12`; the published frequencies and cents errors match `31399.5/((AUDF+1)×6)`; the doc states that a C3 bass would need the out-of-range `AUDF` 39 and that the harmony stays on div 6 by design | State log + static ledger | RD-05 AC 3 / 03 §Lesson 36 |
| ST-36.4 | Debugger: frame and note timing | `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `OverscanStart` 229 (262 lines); `LeadStep` one hit every 12 frames with A = the new index; `HarmonyStep` one hit every 48 frames; `HmoveApply`/`HmoveDone` once per frame | State log + static ledger (AR-6) | RD-05 AC 3 / 03 §Lesson 36 |
| ST-36.5 | Assemble and run each solution | Ex 1: `LeadStep` every 6 (or 24) frames and `HarmonyStep` every 24 (or 96); ex 2: `HarmonyFreqWrite` A=19,15 and the blue marker on rung 2; ex 3: both markers hidden for 60 frames, `LeadVolWrite`/`HarmonyVolWrite` = 0, then the sequence restarts | `verify.sh` + manual runs + captures | RD-05 AC 1 / AR-21 |
| ST-36.6 | Build the site and inspect the page | Part index row 36 ✅ Complete linking `./36-music`; page prev 35, next 37; both images and `<RomPlayer>` render; sidebar `config.ts:101`; README unchanged | `npm run docs:build` + page check | RD-05 AC 1 / AR-10 |

### Lesson 37

| # | Input / Scenario | Expected Outcome | Evidence Method | Source |
| --- | --- | --- | --- | --- |
| ST-37.1 | Assemble the main source (which sources `include/sound.asm`) and its three solutions; run `verify.sh` | Each ROM is exactly 4,096 bytes; the library assembles through the main source; no drift; docs build passes | `verify.sh` output + file size | RD-05 AC 1–2 / AR-7 |
| ST-37.2 | Run the ROM; inspect the mixer at the LASER and EXPLOSION first steps | LASER: band 1 gold `$1A`, channel-0 bar gold 11 cells at x=313, channel-1 bar blue `$84` 4 cells at x=697, priority bar 5 chunks per half; EXPLOSION: band 2 red `$42`, channel-0 bar red 11 cells, channel-1 bar blue 4 cells, priority 9 chunks per half; background `$02`; the capture used in the doc records the exact step and height | Screenshots `laser.png`, `explosion.png` + pixel check | 03 §Lesson 37 |
| ST-37.3 | Inspect the trigger/priority log | Counters start at their periods: `Trigger` A=1 (BLIP, X=0) at frame 24 → `Accept`; frame 120: LASER (A=2) handled before BLIP → `Accept` A=2 and `Reject` A=1; frame 240: EXPLOSION (A=3) handled before BLIP → `Accept` A=3 and `Reject` A=1; frame 264: `Reject` A=1 (inside the explosion's 240–275 window); frame 360: POWERUP (A=4, X=1) → `Accept`; `MusicStart` at frame 384 when channel 1 frees; `VolWrite` fires with X=0/1 | State log + static ledger | RD-05 AC 3 / 03 §Lesson 37 |
| ST-37.4 | Debugger: engine steps and frame | `StartFrame` 259, `VblankStart` 0, `BodyStart` 37, `OverscanStart` 229 (262 lines); `StepWrite` A increments per rate, X = channel; `CtlWrite` A = `AUDC`, X = channel; `FreqWrite`/`VolWrite` A = the per-step table values, X = channel; `HmoveApply`/`HmoveDone` once per frame | State log + static ledger (AR-6) | RD-05 AC 3 / 03 §Lesson 37 |
| ST-37.5 | Assemble and run each solution | Ex 1: `Accept` A=5, the ZAP has 5 steps, the channel-0 bar follows 10→9→8→7→6 cells, priority 6 chunks per half; ex 2: `Accept` A=1 during the explosion, priority bar 10 chunks per half; ex 3: channel-1 bar 2 cells during the explosion and 4 after | `verify.sh` + manual runs + captures | RD-05 AC 1 / AR-21 |
| ST-37.6 | Build the site and inspect the page | Part index row 37 ✅ Complete linking `./37-advanced-audio`; page prev 36, next `/part6-game-dev/38-collision-detection` (the Part 6 stub; its own frontmatter is Part 6's responsibility); both images and `<RomPlayer>` render; sidebar `config.ts:102`; README unchanged | `npm run docs:build` + page check | RD-05 AC 1 / AR-10 |

## Verification Commands

| Purpose | Command |
| --- | --- |
| Full gate | `bash scripts/verify.sh` |
| Rebuild committed ROMs | `npm run roms` |
| Capture a screenshot | `bash scripts/capture-screenshot.sh <committed-rom> <out.png> [wait]` |
| Audio state log | `stella -sound 0 -dbg.logbreaks 1 -logtoconsole 1 -break '$ADDR' <rom>` |
| Docs build | `npm run docs:build` |

## Coverage Notes

- Every RD-05 acceptance criterion maps to at least one ST row: AC 1 → ST-35.1/35.5/35.6,
  ST-36.1/36.5/36.6, ST-37.1/37.5/37.6; AC 2 → the `.1` rows; AC 3 → the `.3`/`.4` rows;
  AC 4 → the site rows and the frozen curriculum check in each Session A record.
- The audio rows test the register values and frame timing, not the listener's perception. The
  lesson documents disclose that boundary (AR-6, AR-22).
- The Part 5 index starts with row 35 `🔒 Coming Soon` and rows 36–37 `🔒 Coming Soon`; each row
  flips in its own phase. The sidebar entries already exist (`config.ts:100–102`), so the
  VitePress rework is the index/page integration, not a new nav entry.
- No unit-test framework is added; the observation cases are the repository's test form (AR-7).
