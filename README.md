# 🕹️ Racing the Beam

**Learn Atari 2600 assembly programming from scratch — 72 hands-on lessons from zero to homebrew mastery.**

🌐 **Live Site**: [blendsdk.github.io/racing-the-beam](https://blendsdk.github.io/racing-the-beam/)

## What is this?

A step-by-step masterclass in Atari 2600 game development using 6502 assembly language. Every lesson includes buildable source code that runs in the Stella emulator.

## The Curriculum

| Part | Topic | Lessons |
|------|-------|---------|
| 0 | Foundations | 01–03 |
| 1 | The 6502 CPU | 04–11 |
| 2 | TV & TIA | 12–18 |
| 3 | Playfield | 19–24 |
| 4 | Sprites | 25–34 |
| 5 | Sound | 35–37 |
| 6 | Game Development | 38–47 |
| 7 | Kernel Mastery | 48–55 |
| 8 | Advanced Topics | 56–65 |
| 9 | The DSL Path | 66–68 |
| 10 | Capstone Projects | 69–72 |

## Prerequisites

- **DASM assembler** — [github.com/dasm-assembler/dasm](https://github.com/dasm-assembler/dasm)
- **Stella emulator** — [stella-emu.github.io](https://stella-emu.github.io/)
- A text editor with 6502 assembly syntax highlighting

## Quick Start

```bash
git clone https://github.com/blendsdk/racing-the-beam.git
cd racing-the-beam
npm install
make            # Build the starter project
stella build/main.bin  # Run in Stella
```

## Development

```bash
npm run docs:dev      # Start VitePress dev server
npm run docs:build    # Build for production
npm run docs:preview  # Preview production build
```

## License

MIT
