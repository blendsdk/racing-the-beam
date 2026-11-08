# Part 11: Legendary Techniques

> 🧭 **The Big Idea — The Masters' Greatest Hits.** Every earlier part taught a mechanism; this part studies the tricks that made the commercial 2600 games famous. Some are happy accidents (the HMOVE comb), some are branchless idioms (skipdraw), some are data compression (procedural worlds), and some are production craft (the in-game publisher mark). Each one is a documented technique, rebuilt from the mechanism rather than copied from a screen.

An anthology of famous, historically documented Atari 2600 tricks — the masters' greatest hits. By this point in the course you know enough to *appreciate* and *reimplement* the techniques that defined the platform.

**Lesson 79 is complete; lessons 73–78 are in production.**

## Lessons

| # | Lesson | Status |
|---|--------|--------|
| 73 | **The HMOVE Comb & the Cosmic Ark Starfield** — abusing repeated HMOVE strobes to scatter a single missile into a whole star field | 🔮 Coming Soon |
| 74 | **Skipdraw — The Classic Sprite Kernel Idiom** — the branchless per-scanline sprite idiom, driven by carry math instead of a compare-and-branch | 🔮 Coming Soon |
| 75 | **Pseudo-3D Road — The Enduro / Pole Position Effect** — a perspective road that rushes toward the player using per-scanline width, colour bands, and a curve-offset table | 🔮 Coming Soon |
| 76 | **Procedural Worlds from a Seed — Pitfall! & River Raid** — an entire world generated from a tiny LFSR seed, deterministic forward and backward | 🔮 Coming Soon |
| 77 | **Interlaced Flicker — Faking More Colours & Resolution** — time-multiplexing the display across alternating frames to exceed the hardware's limits | 🔮 Coming Soon |
| 78 | **Room & Object Engine — The Adventure Architecture** — Warren Robinett's data-driven room/object engine, all in 4KB | 🔮 Coming Soon |
| 79 | [**The Publisher Mark — An Activision-Style In-Game Logo**](./79-publisher-mark) — how Activision put its wordmark in the bottom band; the 48-pixel trick as a static mark; a ROM table instead of a RAM buffer; the second handover | ✅ Complete |

## What You'll Learn

Part 11 is the anthology of the techniques that defined the platform:

- **Lesson 73** rebuilds the Cosmic Ark starfield from the HMOVE comb: one missile, repeated strobes, and a star field that costs almost nothing.
- **Lesson 74** builds the skipdraw sprite kernel: the branchless per-scanline idiom that every commercial game used.
- **Lesson 75** renders a pseudo-3D road with per-scanline width, colour bands, and a curve table.
- **Lesson 76** generates a procedural world from a tiny LFSR seed, deterministic in both directions.
- **Lesson 77** uses interlaced flicker to fake more colours and resolution than the TIA has.
- **Lesson 78** builds the room-and-object engine that invented the action-adventure genre.
- **Lesson 79** puts the 48-pixel trick in the bottom band: a static `RACING` publisher mark drawn from a page-aligned ROM table, with a second handover and a SELECT toggle, beside the score and a small play field.

*The anthology completes the masterclass at 79 lessons. Lesson 79 is live; lessons 73–78 are coming soon.*
