# Part 10: Capstone Projects

> 🧭 **The Big Idea — The Whole Machine.** Every earlier part built one piece: the CPU, the TIA, the frame, the sprites, the collisions, the score, the sound, the kernel, the bankswitch, the generator. A game is what happens when all of them run at once, every frame, forever. Part 10 is the graduation: four complete games, built end to end with the course's production pipeline, then a design lesson that turns the pipeline on your own idea.

Pong, Breakout, and Maze Explorer apply the accumulated technique; the final lesson scopes and delivers an original game.

## Lessons

| # | Lesson | Status |
|---|--------|--------|
| 69 | [Capstone 1 — Pong](./69-pong) | ✅ Complete |
| 70 | [Capstone 2 — Breakout](./70-breakout) | ✅ Complete |
| 71 | [Capstone 3 — Maze Explorer](./71-maze-explorer) | ✅ Complete |
| 72 | [Capstone 4 — Your Own Game](./72-your-game) | ✅ Complete |

## What You'll Learn

Part 10 turns the toolbox into complete games:

- **Lesson 69** builds two-player Pong: two paddles, a ball, wall and paddle collisions, a serve, a one-digit-per-player score, and a precomputed row table driving a two-line kernel. The lesson shows why a one-line multi-object kernel cannot write GRP0 before P0's pixel time at X=16, and how the row table fixes it.
- **Lesson 70** builds Breakout: a 48-line brick field, a 128-line play area, a brick map with per-brick removal, three levels, three lives, the score library, and a zone kernel that keeps the ball visible in both the brick field and the play area.
- **Lesson 71** builds Maze Explorer: a generated mirror maze (10 unique columns, 20 visible in reflect mode), cell-by-cell movement, two enemies with a chase AI, three keys, a win and a lose state, and a first-party Python generator with a committed include and a `--check` gate.
- **Lesson 72** is the production lesson: a complete skeleton mini-game, the game design document, the RAM/screen/4K budget worksheets, the milestone plan, and the production checklist for your own game.

By the end of Part 10 you can take a game from an idea to a committed ROM: a state machine, a kernel budget, an input map, a collision policy, a score, a sound, a win/lose condition, deterministic captures, and a lesson document. That is the whole machine.
