# Part 6: Game Development

Put it all together — collision detection, scoring, game states, AI, and debugging.

## Lessons

| # | Lesson | Status |
|---|--------|--------|
| 38 | [Collision Detection — When Things Touch](./38-collision-detection) | ✅ Complete |
| 39 | [The Scoreboard — 48-Pixel Sprite Trick](./39-scoreboard) | 🔒 Coming Soon |
| 40 | [BCD Arithmetic — Scores That Make Sense](./40-bcd-arithmetic) | 🔒 Coming Soon |
| 41 | [Game States — Title, Play, Game Over](./41-game-states) | 🔒 Coming Soon |
| 42 | [Difficulty and Progression](./42-difficulty) | 🔒 Coming Soon |
| 43 | [Random Numbers — Unpredictable Fun](./43-random-numbers) | 🔒 Coming Soon |
| 44 | [AI & Enemy Behavior — Chase, Patrol, Flee](./44-ai-enemy-behavior) | 🔒 Coming Soon |
| 45 | [Memory Management — 128 Bytes of Creativity](./45-memory-management) | 🔒 Coming Soon |
| 46 | [Debugging — Finding and Fixing Bugs](./46-debugging) | 🔒 Coming Soon |
| 47 | [Development Tools & Workflow](./47-dev-tools-workflow) | 🔒 Coming Soon |

## What You'll Learn

Part 6 turns the rendering and audio skills of Parts 1–5 into complete games:

- **Lesson 38** reads the TIA's collision latches, classifies four object pairs, and turns a latch into a one-shot hit
- **Lesson 39** draws a six-digit score in 48 pixels with the Staugas kernel and packages it in `include/score.asm`
- **Lesson 40** keeps a six-digit score in three BCD bytes and adds/subtracts with decimal mode
- **Lesson 41** structures a game as a title/play/game-over state machine with per-state input and drawing
- **Lesson 42** reads the console switches and scales the level, enemy speed, and enemy width
- **Lesson 43** generates pseudo-random bytes with a Galois LFSR and packages it in `include/random.asm`
- **Lesson 44** builds patrol, chase, and flee enemy behavior with a distance threshold and hysteresis
- **Lesson 45** plans the 128-byte RAM map, packs flags and timers, and proves the budget at assembly time
- **Lesson 46** finds and fixes the classic sticky-collision, frame-overrun, and off-by-one bugs with Stella
- **Lesson 47** automates the ACME/git/verify workflow and shows the build pipeline on screen

By the end of Part 6 you can build a complete small game: it detects contacts, keeps score, moves
through states, gets harder, generates unpredictable positions, chases or flees, fits in 128
bytes, and is verified by the same pipeline every lesson uses.
