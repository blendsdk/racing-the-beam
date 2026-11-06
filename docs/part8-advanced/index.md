# Part 8: Advanced Topics

Push beyond 4KB — bankswitching, illegal opcodes, DPC+, compression, and building physical cartridges.

## Lessons

| # | Lesson | Status |
|---|--------|--------|
| 56 | [Bankswitching — Beyond 4KB](./56-bankswitching) | ✅ Complete |
| 57 | [Superchip — Extra RAM](./57-superchip) | ✅ Complete |
| 58 | [Illegal Opcodes — Undocumented Power](./58-illegal-opcodes) | ✅ Complete |
| 59 | [Self-Modifying Code — The Ultimate 6502 Trick](./59-self-modifying-code) | ✅ Complete |
| 60 | [DPC and DPC+ — Enhanced Audio and Graphics](./60-dpc-plus) | ✅ Complete |
| 61 | [Compression & Data Encoding — Fitting More in 4KB](./61-compression) | 🔒 Coming Soon |
| 62 | [Reverse Engineering a Classic Game](./62-reverse-engineering) | 🔒 Coming Soon |
| 63 | [Modern Homebrew — Dev Carts and Community](./63-modern-homebrew) | 🔒 Coming Soon |
| 64 | [Building Your Own Cartridge — From ROM to Physical Cart](./64-building-cartridges) | 🔒 Coming Soon |
| 65 | [PAL/NTSC Universal ROM — One Cart, Every TV](./65-pal-ntsc-universal) | 🔒 Coming Soon |

## What You'll Learn

Part 8 leaves the 4K world and teaches how real 2600 software is shipped:

- **Lesson 56** switches an 8K F8 cartridge between two 4K banks and proves the start bank, the hotspot addresses, and the duplicate switch stub in "the two worlds"
- **Lesson 57** uses the Superchip's 128 bytes of cartridge RAM as a scrolling notebook, with the write/read windows and the auto-detect signature
- **Lesson 58** runs the stable undocumented opcodes (LAX, SAX, DCP, ISB) side by side with their documented equivalents in "the opcode laboratory"
- **Lesson 59** copies a routine into RIOT RAM, patches its operand every scanline, and paints a gradient in "the code painter"
- **Lesson 60** uses the DPC display processor's data fetchers to draw a playfield from a 2K display image, and explains what DPC+ adds
- **Lesson 61** stores a detailed logo as a run-length-encoded stream and decompresses it a row at a time in "the compressed logo"
- **Lesson 62** reverses a course-written classic-style game with the Stella debugger in "Wall Buster"
- **Lesson 63** builds a polished attract mode and surveys the Harmony/UnoCart, AtariAge, and publishing landscape
- **Lesson 64** turns a ROM into a physical cartridge and verifies it with "the burn-in test"
- **Lesson 65** ships one ROM that selects NTSC or PAL timing at the title screen in "the world traveler"

By the end of Part 8 you can choose a mapper, lay out a banked image, read the DPC register map, compress a picture, reverse a ROM, and explain why a stock 2600 cannot auto-detect the TV system.
