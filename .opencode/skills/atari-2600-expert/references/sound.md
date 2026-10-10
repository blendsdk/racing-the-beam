# Sound — Reference

The TIA has **two independent audio channels**, each with three registers:

| Register pair | Purpose |
| --- | --- |
| `AUDC0` / `AUDC1` | Timbre — selects a tone divisor or a noise generator |
| `AUDF0` / `AUDF1` | Pitch — frequency divider, 0–31 |
| `AUDV0` / `AUDV1` | Volume — 0 (silent) to 15 (loudest) |

## The audio divider chain

```
~30 kHz base clock  →  divide by (AUDF + 1)  →  divide by AUDC's divisor (2 / 6 / 31 / 93 for tones)
```

- **Higher `AUDF` = lower pitch.** The full tone range is roughly 10 Hz – 15 kHz.
- **`AUDV = 0` is silence** on both channels — the standard way to end a sound effect.
- Writing `AUDV` every frame is normal and recommended for envelopes.

## AUDC values (authoritative table)

| Value | Generator | Character |
| --- | --- | --- |
| 0 | constant "1" | disables the channel (no sound) |
| 1 | 4-bit poly | harsh noise |
| 2 | div 15 → 4-bit poly | slower, coarser noise |
| 3 | 5-bit poly → 4-bit poly | complex, "metallic" noise |
| 4 | div 2 pure tone | bright tone, highest pitch range |
| 5 | div 2 pure tone | bright tone (slightly different phase) |
| 6 | div 31 pure tone | mid, soft tone |
| 7 | 5-bit poly → div 2 | noisy tone (buzz) |
| 8 | 9-bit poly | white noise (the classic explosion) |
| 9 | 5-bit poly | noise (different texture) |
| A (10) | div 31 pure tone | like 6, different phase |
| B (11) | "set last 4 bits to 1" | special/undocumented-ish; rarely useful |
| C (12) | div 6 pure tone | the workhorse "middle" tone |
| D (13) | div 6 pure tone | like 12, different phase |
| E (14) | div 93 pure tone | low, buzzy tone |
| F (15) | 5-bit poly div 6 | noisy tone/rumble |

Practical picks:

- **Pure tones** (music, beeps): `4`/`5`, `C`/`D`, `6`/`A`, `E` — from high to low character.
- **Noise** (explosions, hits): `8` (white), `1`/`2` (gritty), `F` (rumble), `9`/`3` (textures).

## Sound-effect recipes

All recipes are per-frame updates driven from the game loop (60 Hz NTSC).

| Effect | Recipe |
| --- | --- |
| Laser / shoot | `AUDC=4`, `AUDF` swept from high to low (or low to high) a few frames, `AUDV` from 15 down to 0 |
| Explosion | `AUDC=8`, `AUDF` random-ish sweep, `AUDV` decays a bit each frame |
| Bounce / blip | `AUDC=C`, one `AUDF` change and a 2–6 frame volume envelope |
| Engine / rumble | `AUDC=E` or `F`, `AUDF` modulated by speed, constant low `AUDV` |
| Alarm / siren | alternate `AUDF` between two values every N frames (vibrato) |
| Point scored | two-tone arpeggio: `AUDF` X for 4 frames, Y for 4 frames, then silence |

## Music engines (the small version)

A workable 2600 music engine is just a frame-driven state machine:

1. A **note table** maps note indices to `AUDF` values (the div-by-31/6/93 relations make the
   table non-linear to the ear but constant on the chip).
2. A **duration counter** counts frames per note; when it expires, advance the note index.
3. **Two channels** play lead and bass (or melody and percussion with a noise `AUDC`).
4. **Vibrato** = alternating `AUDF` ± 1 every few frames; **envelope** = decreasing `AUDV`.

Keep the engine's per-frame work small — it runs inside the overscan/VBLANK budget like any
other game logic.

## Common pitfalls

- Leaving `AUDV` above 0 after a sound ends → a drone you did not intend.
- Assuming `AUDF+1` divides by 64: the divisor is `AUDF + 1` (0 → ÷1, 31 → ÷32).
- Forgetting that **AUDC 0 is silence**, not "volume 0 timbre" — use `AUDV=0` to mute and
  `AUDC=0` to disable the channel entirely.
- Expecting the two channels to mix cleanly: they sum, so two loud channels can clip.

## Sources

AUDC table and divider chain verified against problemkaputt.de's VCS specification; see
`sources.md`. For deeper music work, Paul Slocum's 2600 music notes (AtariAge) are the
classic reference.
