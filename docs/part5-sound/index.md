# Part 5: Sound

Create sound effects and music with the TIA's two audio channels.

## Lessons

| # | Lesson | Status |
|---|--------|--------|
| 35 | [Sound Effects — Beeps, Boops, and Explosions](./35-sound-effects) | ✅ Complete |
| 36 | [Music — Melodies on the TIA](./36-music) | ✅ Complete |
| 37 | [Advanced Audio — Sound Engine Design](./37-advanced-audio) | 🔒 Coming Soon |

## What You'll Learn

Part 5 makes the TIA's audio registers audible and visible:

- **Lesson 35** programs `AUDC`, `AUDF`, and `AUDV` directly and shapes a beep, a boop, and an explosion with per-frame volume envelopes
- **Lesson 36** plays a melody from a measured note table on two channels, with a note ladder that shows the current scale degrees
- **Lesson 37** generalizes both into a small data-driven sound engine with two channels, priority, and a mixer monitor

By the end of Part 5 you can make the 2600 beep, sweep, rumble, and play a tune — and you know
exactly which register value produces each sound.
