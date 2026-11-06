# Part 7: Kernel Mastery

Design and build display kernels — the scanline-by-scanline routines that define every 2600 game.

## Lessons

| # | Lesson | Status |
|---|--------|--------|
| 48 | [Introduction to Kernels — The Heart of Every 2600 Game](./48-introduction-to-kernels) | ✅ Complete |
| 49 | [The 2-Line Kernel — Standard Game Pattern](./49-two-line-kernel) | ✅ Complete |
| 50 | [Multi-Zone Kernel — Scoreboard + Playfield + Sprites](./50-multi-zone-kernel) | ✅ Complete |
| 51 | [Flicker Sprites — More Than 2 Objects](./51-flicker-sprites) | ✅ Complete |
| 52 | [Fine Scrolling — Smooth Movement](./52-fine-scrolling) | ✅ Complete |
| 53 | [Kernel Design Patterns — Building Your Toolkit](./53-kernel-patterns) | 🔒 Coming Soon |
| 54 | [Visual Effects Cookbook — Starfields, Rainbows, Pseudo-3D](./54-visual-effects-cookbook) | 🔒 Coming Soon |
| 55 | [Scrolling Text Marquee — The Activision Logo Effect](./55-scrolling-text-marquee) | 🔒 Coming Soon |

## What You'll Learn

Part 7 turns the frame, the playfield, and the sprites of Parts 2–4 into the routine at the centre of every 2600 game:

- **Lesson 48** names the kernel taxonomy — 1-line, 2-line, multi-zone, repositioning, and flicker — and draws the same diamond at both vertical resolutions in "the kernel zoo"
- **Lesson 49** builds the standard 2-line game kernel: 96 rows, a per-row colour ramp, a mountain playfield, and two 16-line sprites in "the mountain pass"
- **Lesson 50** divides the screen into a score zone, a status bar, a play area, and a ground line, and repositions the players between zones in "the dashboard"
- **Lesson 51** draws four objects with two players by alternating two 30 Hz frames, with a per-row skipdraw test in "the flicker gallery"
- **Lesson 52** scrolls a three-plane world one line at a time and moves a ship one pixel at a time in "the tunnel"
- **Lesson 53** packages the fill, playfield-row, sprite-strip, and colour-ramp kernels as a reusable library and combines them into "the pattern sampler"
- **Lesson 54** builds a scrolling starfield, a full-screen rainbow, and a pseudo-3D road in "the effects reel"
- **Lesson 55** turns the 48-pixel score kernel into a scrolling text marquee in "the marquee"

By the end of Part 7 you can choose a kernel for a picture, divide the 192 visible lines into zones, count every row against the 76-cycle and 152-cycle budgets, and prove the result in Stella.
