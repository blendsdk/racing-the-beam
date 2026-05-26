# Getting Started

Welcome to **Racing the Beam** — a step-by-step masterclass in Atari 2600 assembly programming.

## What You'll Need

### 1. DASM Assembler

DASM is the standard assembler for Atari 2600 development.

**macOS** (Homebrew):
```bash
brew install dasm
```

**Linux** (build from source):
```bash
git clone https://github.com/dasm-assembler/dasm.git
cd dasm
make
sudo cp bin/dasm /usr/local/bin/
```

**Windows**: Download from [dasm-assembler releases](https://github.com/dasm-assembler/dasm/releases)

### 2. Stella Emulator

Stella is the most accurate Atari 2600 emulator and includes a powerful debugger.

- **Download**: [stella-emu.github.io](https://stella-emu.github.io/)
- Available for macOS, Linux, and Windows
- Version 6.x or later recommended

### 3. Text Editor

Any text editor works. We recommend one with 6502 assembly syntax highlighting:

- **VS Code** with the "6502 Assembly" extension
- **Sublime Text** with 6502 package
- **vim/neovim** with asm syntax

### 4. This Repository

```bash
git clone https://github.com/blendsdk/racing-the-beam.git
cd racing-the-beam
```

## Your First Build

Once you have DASM and Stella installed, you can build and run the starter project:

```bash
make
```

This will assemble `src/main.asm` into `build/main.bin`. Open it in Stella:

```bash
stella build/main.bin
```

## How This Course Works

1. **Read the lesson** on this site
2. **Type the code** — don't copy-paste! Muscle memory matters for assembly
3. **Build and run** in Stella
4. **Experiment** with the exercises at the end of each lesson
5. **Move on** when you're comfortable with the concepts

Each lesson builds on the previous one. Don't skip ahead — the 2600 is unforgiving, and every concept matters.

## Ready?

Start with [Lesson 01: Number Systems →](/part0-foundations/01-number-systems)
