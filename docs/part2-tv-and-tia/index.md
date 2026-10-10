# Part 2: TV & TIA

Understand how the Atari 2600 generates video — scanline by scanline, cycle by cycle.

## Lessons

| # | Lesson | Status |
|---|--------|--------|
| 12 | [The NTSC Frame — 262 Scanlines of Precision](./12-the-ntsc-frame) | ✅ Complete |
| 13 | [Colors — Painting the Screen](./13-colors) | 🔒 Coming Soon |
| 14 | [WSYNC and Timing — Synchronizing with the Beam](./14-wsync-and-timing) | 🔒 Coming Soon |
| 15 | [The Timer — RIOT Counts for You](./15-the-timer) | 🔒 Coming Soon |
| 16 | [Horizontal Zones — Splitting the Screen](./16-horizontal-zones) | 🔒 Coming Soon |
| 17 | [Cycle Counting — The Heart of Beam Racing](./17-cycle-counting) | 🔒 Coming Soon |
| 18 | [Mid-Scanline Changes — Racing the Beam](./18-mid-scanline-changes) | 🔒 Coming Soon |

## What You'll Learn

Part 2 opens the black box between your code and the screen:

- **Lesson 12** builds the canonical NTSC frame by hand — VSYNC, VBLANK, the visible picture, and overscan — as a counted structure: 3 + 37 + 192 + 30 = 262 scanlines, with `STA WSYNC` as the line ruler
- **Lesson 13** opens the palette: what the color bytes encode, why 128 colors come from hue and luminance, and how to read a color chart
- **Lesson 14** is about timing to the beam: what `WSYNC` really waits for, and why a write that misses its window lands mid-picture instead of on a clean boundary
- **Lesson 15** hands the waiting to the RIOT: an interval timer paces VBLANK and overscan while the CPU gets work done
- **Lesson 16** splits the screen into horizontal zones, each with its own color and boundary discipline
- **Lesson 17** counts cycles exactly — a line has 76 of them — and shows what a single extra cycle per line does to a picture
- **Lesson 18** moves writes *inside* a scanline: mid-line color changes that build vertical columns

By the end of Part 2 you'll control where every scanline's color comes from, how long each line's code may take, and how to prove both in the debugger — ready to start drawing with the playfield in Part 3.
