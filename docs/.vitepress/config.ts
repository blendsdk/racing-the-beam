import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Racing the Beam',
  description: 'Learn Atari 2600 assembly programming from scratch — 78 hands-on lessons from zero to homebrew mastery',
  base: '/racing-the-beam/',

  head: [
    ['meta', { name: 'theme-color', content: '#e85d04' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'Racing the Beam — Atari 2600 Programming' }],
    ['meta', { property: 'og:description', content: '78 hands-on lessons from zero to homebrew mastery' }],
  ],

  themeConfig: {
    logo: '/logo.png',

    nav: [
      { text: 'Lessons', link: '/part0-foundations/' },
      { text: 'Reference', link: '/reference/' },
      { text: 'Getting Started', link: '/getting-started' },
    ],

    sidebar: {
      '/': [
        {
          text: '🚀 Getting Started',
          items: [
            { text: 'Welcome', link: '/getting-started' },
          ],
        },
        {
          text: 'Part 0: Foundations',
          collapsed: false,
          items: [
            { text: '01 — Number Systems', link: '/part0-foundations/01-number-systems' },
            { text: '02 — Meet Stella Debugger', link: '/part0-foundations/02-stella-debugger' },
            { text: '03 — Anatomy of the Atari 2600', link: '/part0-foundations/03-anatomy-of-2600' },
          ],
        },
        {
          text: 'Part 1: The 6502 CPU',
          collapsed: true,
          items: [
            { text: '04 — Registers and Memory', link: '/part1-6502-cpu/04-registers-and-memory' },
            { text: '05 — Arithmetic', link: '/part1-6502-cpu/05-arithmetic' },
            { text: '06 — Flags and Comparisons', link: '/part1-6502-cpu/06-flags-and-comparisons' },
            { text: '07 — Branches and Loops', link: '/part1-6502-cpu/07-branches-and-loops' },
            { text: '08 — Stack and Subroutines', link: '/part1-6502-cpu/08-stack-and-subroutines' },
            { text: '09 — Bitwise Operations', link: '/part1-6502-cpu/09-bitwise-operations' },
            { text: '10 — Addressing Modes', link: '/part1-6502-cpu/10-addressing-modes' },
            { text: '11 — Lookup Tables', link: '/part1-6502-cpu/11-lookup-tables' },
          ],
        },
        {
          text: 'Part 2: TV & TIA',
          collapsed: true,
          items: [
            { text: '12 — The NTSC Frame', link: '/part2-tv-and-tia/12-the-ntsc-frame' },
            { text: '13 — Colors', link: '/part2-tv-and-tia/13-colors' },
            { text: '14 — WSYNC and Timing', link: '/part2-tv-and-tia/14-wsync-and-timing' },
            { text: '15 — The Timer', link: '/part2-tv-and-tia/15-the-timer' },
            { text: '16 — Horizontal Zones', link: '/part2-tv-and-tia/16-horizontal-zones' },
            { text: '17 — Cycle Counting', link: '/part2-tv-and-tia/17-cycle-counting' },
            { text: '18 — Mid-Scanline Changes', link: '/part2-tv-and-tia/18-mid-scanline-changes' },
          ],
        },
        {
          text: 'Part 3: Playfield',
          collapsed: true,
          items: [
            { text: '19 — Playfield Basics', link: '/part3-playfield/19-playfield-basics' },
            { text: '20 — Playfield Colors & Priority', link: '/part3-playfield/20-playfield-colors' },
            { text: '21 — Asymmetric Playfield', link: '/part3-playfield/21-asymmetric-playfield' },
            { text: '22 — Playfield Animation', link: '/part3-playfield/22-playfield-animation' },
            { text: '23 — Data-Driven Playfield', link: '/part3-playfield/23-data-driven-playfield' },
            { text: '24 — Multicolor Playfield', link: '/part3-playfield/24-multicolor-playfield' },
          ],
        },
        {
          text: 'Part 4: Sprites',
          collapsed: true,
          items: [
            { text: '25 — Player Sprite Basics', link: '/part4-sprites/25-player-basics' },
            { text: '26 — Horizontal Positioning', link: '/part4-sprites/26-horizontal-positioning' },
            { text: '27 — Sprite Movement', link: '/part4-sprites/27-sprite-movement' },
            { text: '28 — Two Players', link: '/part4-sprites/28-two-players' },
            { text: '29 — Missiles and Ball', link: '/part4-sprites/29-missiles-and-ball' },
            { text: '30 — Multi-Color Sprites', link: '/part4-sprites/30-multicolor-sprites' },
            { text: '31 — Copies and Sizes', link: '/part4-sprites/31-copies-and-sizes' },
            { text: '32 — Vertical Delay', link: '/part4-sprites/32-vertical-delay' },
            { text: '33 — Paddle & Keyboard Controllers', link: '/part4-sprites/33-paddle-keyboard-controllers' },
            { text: '34 — Sprite Animation', link: '/part4-sprites/34-sprite-animation' },
          ],
        },
        {
          text: 'Part 5: Sound',
          collapsed: true,
          items: [
            { text: '35 — Sound Effects', link: '/part5-sound/35-sound-effects' },
            { text: '36 — Music', link: '/part5-sound/36-music' },
            { text: '37 — Advanced Audio', link: '/part5-sound/37-advanced-audio' },
          ],
        },
        {
          text: 'Part 6: Game Development',
          collapsed: true,
          items: [
            { text: '38 — Collision Detection', link: '/part6-game-dev/38-collision-detection' },
            { text: '39 — The Scoreboard', link: '/part6-game-dev/39-scoreboard' },
            { text: '40 — BCD Arithmetic', link: '/part6-game-dev/40-bcd-arithmetic' },
            { text: '41 — Game States', link: '/part6-game-dev/41-game-states' },
            { text: '42 — Difficulty and Progression', link: '/part6-game-dev/42-difficulty' },
            { text: '43 — Random Numbers', link: '/part6-game-dev/43-random-numbers' },
            { text: '44 — AI & Enemy Behavior', link: '/part6-game-dev/44-ai-enemy-behavior' },
            { text: '45 — Memory Management', link: '/part6-game-dev/45-memory-management' },
            { text: '46 — Debugging', link: '/part6-game-dev/46-debugging' },
            { text: '47 — Development Tools & Workflow', link: '/part6-game-dev/47-dev-tools-workflow' },
          ],
        },
        {
          text: 'Part 7: Kernel Mastery',
          collapsed: true,
          items: [
            { text: '48 — Introduction to Kernels', link: '/part7-kernel-mastery/48-introduction-to-kernels' },
            { text: '49 — The 2-Line Kernel', link: '/part7-kernel-mastery/49-two-line-kernel' },
            { text: '50 — Multi-Zone Kernel', link: '/part7-kernel-mastery/50-multi-zone-kernel' },
            { text: '51 — Flicker Sprites', link: '/part7-kernel-mastery/51-flicker-sprites' },
            { text: '52 — Fine Scrolling', link: '/part7-kernel-mastery/52-fine-scrolling' },
            { text: '53 — Kernel Design Patterns', link: '/part7-kernel-mastery/53-kernel-patterns' },
            { text: '54 — Visual Effects Cookbook', link: '/part7-kernel-mastery/54-visual-effects-cookbook' },
            { text: '55 — Scrolling Text Marquee', link: '/part7-kernel-mastery/55-scrolling-text-marquee' },
          ],
        },
        {
          text: 'Part 8: Advanced Topics',
          collapsed: true,
          items: [
            { text: '56 — Bankswitching', link: '/part8-advanced/56-bankswitching' },
            { text: '57 — Superchip', link: '/part8-advanced/57-superchip' },
            { text: '58 — Illegal Opcodes', link: '/part8-advanced/58-illegal-opcodes' },
            { text: '59 — Self-Modifying Code', link: '/part8-advanced/59-self-modifying-code' },
            { text: '60 — DPC and DPC+', link: '/part8-advanced/60-dpc-plus' },
            { text: '61 — Compression & Data Encoding', link: '/part8-advanced/61-compression' },
            { text: '62 — Reverse Engineering a Classic', link: '/part8-advanced/62-reverse-engineering' },
            { text: '63 — Modern Homebrew', link: '/part8-advanced/63-modern-homebrew' },
            { text: '64 — Building Your Own Cartridge', link: '/part8-advanced/64-building-cartridges' },
            { text: '65 — PAL/NTSC Universal ROM', link: '/part8-advanced/65-pal-ntsc-universal' },
          ],
        },
        {
          text: 'Part 9: The DSL Path',
          collapsed: true,
          items: [
            { text: '66 — Analyzing batari BASIC', link: '/part9-dsl-path/66-analyzing-batari-basic' },
            { text: '67 — Automatable Patterns', link: '/part9-dsl-path/67-automatable-patterns' },
            { text: '68 — Kernel Architecture', link: '/part9-dsl-path/68-kernel-architecture' },
          ],
        },
        {
          text: 'Part 10: Capstone Projects',
          collapsed: true,
          items: [
            { text: '69 — Capstone: Pong', link: '/part10-capstones/69-pong' },
            { text: '70 — Capstone: Breakout', link: '/part10-capstones/70-breakout' },
            { text: '71 — Capstone: Maze Explorer', link: '/part10-capstones/71-maze-explorer' },
            { text: '72 — Capstone: Your Own Game', link: '/part10-capstones/72-your-game' },
          ],
        },
        {
          text: 'Part 11: Legendary Techniques 🔮',
          collapsed: true,
          items: [
            { text: 'Overview (Coming Soon)', link: '/part11-legendary/' },
            { text: '73 — Cosmic Ark Starfield', link: '/part11-legendary/' },
            { text: '74 — Skipdraw Sprite Kernel', link: '/part11-legendary/' },
            { text: '75 — Pseudo-3D Road', link: '/part11-legendary/' },
            { text: '76 — Procedural Worlds (LFSR)', link: '/part11-legendary/' },
            { text: '77 — Interlaced Flicker', link: '/part11-legendary/' },
            { text: '78 — Room & Object Engine', link: '/part11-legendary/' },
          ],
        },
        {
          text: '📖 Reference',
          collapsed: true,
          items: [
            { text: 'Color Chart', link: '/reference/color-chart' },
            { text: '6502 Instructions', link: '/reference/6502-instructions' },
            { text: 'TIA Registers', link: '/reference/tia-registers' },
            { text: 'Cheat Sheet', link: '/reference/cheat-sheet' },
            { text: 'Glossary', link: '/reference/glossary' },
          ],
        },
      ],
    },

    search: { provider: 'local' },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/blendsdk/racing-the-beam' },
    ],

    editLink: {
      pattern: 'https://github.com/blendsdk/racing-the-beam/edit/master/docs/:path',
      text: 'Edit this page on GitHub',
    },

    footer: {
      message: 'Released under the MIT License.',
      copyright: '© 2026 Racing the Beam',
    },
  },

  markdown: {
    lineNumbers: true,
  },
})
