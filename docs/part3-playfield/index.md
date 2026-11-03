# Part 3: Playfield

Learn to draw backgrounds using the TIA's playfield registers — from basics to multicolor techniques.

## Lessons

| # | Lesson | Status |
|---|--------|--------|
| 19 | [Playfield Basics — PF0, PF1, PF2](./19-playfield-basics) | ✅ Complete |
| 20 | [Playfield Colors and Priority](./20-playfield-colors) | ✅ Complete |
| 21 | [Asymmetric Playfield — Different Left and Right](./21-asymmetric-playfield) | ✅ Complete |
| 22 | [Playfield Animation — Moving Walls](./22-playfield-animation) | ✅ Complete |
| 23 | [Data-Driven Playfield — Levels from Tables](./23-data-driven-playfield) | ✅ Complete |
| 24 | [The Multicolor Playfield](./24-multicolor-playfield) | 🔒 Coming Soon |

## What You'll Learn

Part 3 turns the TIA's background into a drawing surface:

- **Lesson 19** writes the three playfield registers in the right bit order and switches between mirror and repeat symmetry
- **Lesson 20** colors the playfield with `COLUPF` and splits its halves with score mode
- **Lesson 21** gives the left and right halves different data with mid-line register writes
- **Lesson 22** animates the pattern frame by frame with a small state machine
- **Lesson 23** drives the playfield from level tables, one row per scanline
- **Lesson 24** changes `COLUPF` every line for rainbow and region effects

By the end of Part 3 you can draw walls, mazes, gates, and colored backgrounds from three bytes and a table — the canvas every later part builds on.
