# Lesson Curriculum: Atari 2600 Masterclass

> **Document**: 04-lesson-curriculum.md
> **Parent**: [Index](00-index.md)

## Overview

60+ lessons organized in 10 parts, strictly linear progression (per AR-10). Each lesson has:
- Theory document (`.md` in VitePress) with TypeScript analogies (per AR-7)
- Buildable `.asm` source file with heavy comments (per AR-4)
- Exercises with hints and expected results (per AR-8)
- Solution `.asm` files in same directory (per AR-3)

NTSC primary, PAL notes inline (per AR-6, Q1).

---

## Part 0: Foundations (3 lessons)

*Before touching the 2600, establish the mental tools you'll need.*

### Lesson 01: Number Systems — Binary, Hexadecimal, and You
**Directory:** `lessons/part0-foundations/01-number-systems/`
**Concepts:** Binary (base 2), hexadecimal (base 16), decimal conversion, why programmers use hex, bit/nibble/byte terminology, powers of 2, two's complement for signed numbers.
**TS Analogy:** `0xFF` in TypeScript vs `$FF` in 6502, `parseInt('FF', 16)`, bitwise operators `&`, `|`, `^`, `<<`, `>>`.
**ASM File:** Minimal ROM that stores hex values in RAM and uses AND/OR masks — the student modifies values and observes in Stella debugger.
**Exercises:** Convert between bases, predict bitmask results, write hex values for given binary patterns.

### Lesson 02: Meet Stella — Your Debugger and Best Friend
**Directory:** `lessons/part0-foundations/02-stella-debugger/`
**Concepts:** Loading ROMs, the debugger (backtick key), stepping through code, watching registers (A/X/Y/SP/PC), viewing memory ($80-$FF for RAM), TIA tab, breakpoints, scanline counting, frame advance.
**ASM File:** A simple ROM with intentional "landmarks" — specific values stored in specific RAM addresses so the student can find them in the debugger.
**Exercises:** Set breakpoints, step through the frame loop, find a hidden value in RAM, count scanlines for one frame.

### Lesson 03: Anatomy of the Atari 2600
**Directory:** `lessons/part0-foundations/03-anatomy-of-2600/`
**Concepts:** The three chips (6507 CPU, TIA, RIOT), memory map ($00-$3F = TIA, $80-$FF = RAM, $0280-$0297 = RIOT, $F000-$FFFF = ROM), address bus mirroring (13 lines), cartridge slot, controllers, TV signal basics.
**TS Analogy:** Hardware registers as "global singletons" — writing to `COLUBK` is like setting `document.body.style.backgroundColor`.
**ASM File:** Annotated version of the starter ROM (rainbow) with arrows pointing to which chip each instruction talks to.
**Exercises:** Draw the memory map from memory, identify which chip handles each register, predict what happens if you write to a mirrored address.

---

## Part 1: The 6502 CPU (8 lessons)

*Re-learn the processor that powered the golden age of gaming.*

### Lesson 04: Registers and Memory — The CPU's Workspace
**Directory:** `lessons/part1-6502-cpu/01-registers-and-memory/`
**Concepts:** Accumulator (A), index registers (X, Y), stack pointer (SP), program counter (PC), processor status (P/flags). LDA, LDX, LDY, STA, STX, STY. Immediate addressing (`#$xx`), zero-page addressing (`$xx`), absolute addressing (`$xxxx`).
**TS Analogy:** A/X/Y are like `let a, x, y` — only 3 variables available to work with directly. Memory is like a giant `Uint8Array(256)`.
**ASM File:** Load values into registers, store them in RAM, read them back. Observe in debugger.
**Exercises:** Store your birth year (hex) in RAM, swap two RAM values using A as temp.

### Lesson 05: Arithmetic — Adding and Subtracting
**Directory:** `lessons/part1-6502-cpu/02-arithmetic/`
**Concepts:** ADC (add with carry), SBC (subtract with borrow), CLC/SEC, the carry flag, 8-bit overflow/wraparound, INC/DEC/INX/INY/DEX/DEY.
**TS Analogy:** `(a + b) & 0xFF` — 8-bit arithmetic always wraps. Carry is like a "digit carried" in long addition.
**ASM File:** Calculator ROM — adds two values, stores result, handles carry for 16-bit addition.
**Exercises:** Add two 16-bit numbers, implement countdown timer variable, detect overflow.

### Lesson 06: Flags and Comparisons — How the CPU Decides
**Directory:** `lessons/part1-6502-cpu/03-flags-and-comparisons/`
**Concepts:** Zero flag (Z), negative flag (N), carry flag (C), overflow flag (V). CMP/CPX/CPY instructions. How flags are set by arithmetic and comparison operations. The processor status register (P).
**TS Analogy:** `if (a === 0)` → Zero flag. `if (a < b)` → Carry flag after CMP. `if (a & 0x80)` → Negative flag.
**ASM File:** ROM that compares values and stores results — student traces flag state in debugger.
**Exercises:** Predict flags after each instruction, write a "max of two values" routine.

### Lesson 07: Branches and Loops — Conditional Execution
**Directory:** `lessons/part1-6502-cpu/04-branches-and-loops/`
**Concepts:** BEQ, BNE, BCS, BCC, BMI, BPL, BVS, BVC. Relative addressing. Building loops (DEX/BNE pattern). Counted loops vs. conditional loops. Branch range limits (-128 to +127 bytes).
**TS Analogy:** `if/else` → CMP + BEQ/BNE. `for (let i=N; i>0; i--)` → LDX #N / DEX / BNE. `while (condition)` → CMP / BNE.
**ASM File:** ROM with several loop patterns: countdown, count-up, nested loops, conditional skip.
**Exercises:** Write a loop that counts to 100, write a "find first non-zero byte" search, implement a delay of exactly 1000 cycles.

### Lesson 08: The Stack and Subroutines — Functions in Assembly
**Directory:** `lessons/part1-6502-cpu/05-stack-and-subroutines/`
**Concepts:** The stack (page $01, grows downward), PHA/PLA (push/pull accumulator), PHP/PLP (push/pull flags), JSR/RTS (jump to subroutine / return). Stack on the 2600 (wraps within 128-byte RAM). Saving/restoring registers in subroutines.
**TS Analogy:** JSR/RTS = function call/return. PHA/PLA = saving local variables. Stack = the call stack in JS.
**ASM File:** ROM with multiple subroutines: one that sets colors, one that waits N scanlines, called from the main loop.
**Exercises:** Write a subroutine that multiplies A by 2, refactor existing code into subroutines, trace the stack in debugger.

### Lesson 09: Bitwise Operations — The Power of Bits
**Directory:** `lessons/part1-6502-cpu/06-bitwise-ops/`
**Concepts:** AND, ORA, EOR (XOR), BIT test. ASL/LSR (shift left/right), ROL/ROR (rotate through carry). Using AND as a mask, ORA to set bits, EOR to toggle bits. BIT instruction for testing without destroying A.
**TS Analogy:** Direct mapping: AND→`&`, ORA→`|`, EOR→`^`, ASL→`<<`, LSR→`>>`. Masking: `value & 0x0F` → lower nibble.
**ASM File:** ROM demonstrating bit manipulation — extracting joystick directions from SWCHA using AND masks.
**Exercises:** Extract individual bits from a byte, implement a simple 8-bit flag register, toggle a flag on/off.

### Lesson 10: Addressing Modes — How the CPU Finds Data
**Directory:** `lessons/part1-6502-cpu/07-addressing-modes/`
**Concepts:** All 6502 addressing modes: immediate, zero page, zero page X/Y, absolute, absolute X/Y, (indirect,X), (indirect),Y, relative (branches), implied. When to use each. Performance (zero page = fast, absolute = slow).
**TS Analogy:** Immediate = literal value. Zero page = local variable. Absolute = global. Indexed = `array[i]`. Indirect = pointer/reference.
**ASM File:** ROM using each addressing mode with comments explaining the memory access pattern.
**Exercises:** Rewrite code using different addressing modes, predict byte counts and cycle counts.

### Lesson 11: Lookup Tables — Data-Driven Programming
**Directory:** `lessons/part1-6502-cpu/08-lookup-tables/`
**Concepts:** Storing data in ROM with `!byte`. Reading tables with indexed addressing (LDA table,X). Tables for: color palettes, sprite graphics, sine waves, level data. Table alignment and page crossing penalties.
**TS Analogy:** `const colors: number[] = [0x1A, 0x2B, ...]` → `colors !byte $1A, $2B, ...`. `colors[i]` → `LDA colors,X`.
**ASM File:** ROM that uses a color table to paint each scanline a specific color (sunset gradient from table data).
**Exercises:** Create a custom color table, implement a simple animation using table data, build a "font" table for digit bitmaps.

---

## Part 2: The TV and TIA (7 lessons)

*Understand the display system that makes the 2600 unique.*

### Lesson 12: The NTSC Frame — 262 Scanlines of Precision
**Directory:** `lessons/part2-tv-and-tia/01-the-ntsc-frame/`
**Concepts:** How a CRT TV works (electron beam, phosphors). The NTSC standard: 262 scanlines, 60 fields/sec. The frame structure: 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan. Why these exact numbers. Color clocks (228 per line, 160 visible). CPU cycles per line (76).
**PAL Note:** 312 scanlines, 50 fields/sec. Different timing values.
**ASM File:** Minimal frame loop with scanline counter — student verifies 262 lines in Stella debugger.
**Exercises:** Count scanlines in debugger, calculate how many CPU cycles per frame (262 × 76 = 19,912), modify for PAL timing.

### Lesson 13: Colors — Painting the Screen
**Directory:** `lessons/part2-tv-and-tia/02-colors/`
**Concepts:** COLUBK (background), COLUP0/P1 (player colors), COLUPF (playfield color). NTSC color encoding: CCCCLLL0 (4 bits hue, 3 bits luminance, bit 0 unused). All 128 NTSC colors. Using the color picker reference component.
**ASM File:** ROM that displays all 128 colors as horizontal stripes (8 colors per hue group).
**Exercises:** Find the hex value for specific colors, create a "sky to ground" gradient, make a PAL-compatible color scheme.

### Lesson 14: WSYNC and Timing — Synchronizing with the Beam
**Directory:** `lessons/part2-tv-and-tia/03-wsync-and-timing/`
**Concepts:** WSYNC register (halts CPU until HBLANK), why it matters (without WSYNC, you'd need to count exactly 76 cycles per line). CPU cycle counting basics. The relationship: 1 CPU cycle = 3 color clocks. HBLANK (68 color clocks of non-visible left margin).
**ASM File:** ROM comparing WSYNC-aligned vs. unaligned color changes — shows what happens without WSYNC.
**Exercises:** Remove WSYNC and observe the mess, calculate exact cycles for a code sequence, add WSYNC at the right place.

### Lesson 15: The Timer — RIOT Counts for You
**Directory:** `lessons/part2-tv-and-tia/04-the-timer/`
**Concepts:** RIOT timer registers (TIM64T, TIM8T, TIM1T, T1024T, INTIM, INSTAT). Timer-based VBLANK and overscan (vs. scanline counting). Choosing the right prescaler. Timer accuracy and drift.
**ASM File:** ROM using timer for VBLANK (43 ticks) and overscan (35 ticks), with game logic in the timed gaps.
**Exercises:** Change prescaler values and observe effects, implement scanline-counted VBLANK (without timer), measure timer accuracy in debugger.

### Lesson 16: Horizontal Zones — Splitting the Screen
**Directory:** `lessons/part2-tv-and-tia/05-horizontal-zones/`
**Concepts:** Changing TIA registers at different vertical positions to create "zones" — sky zone (blue), ground zone (green), scoreboard zone (black). Tracking scanline position. Multiple-zone kernel structure.
**ASM File:** ROM with 3 color zones: blue sky (64 lines), green field (96 lines), brown ground (32 lines).
**Exercises:** Add a 4th zone, create a "sunset" effect with color transitions, implement a split-screen with different colors per zone.

### Lesson 17: Cycle Counting — The Heart of Beam Racing
**Directory:** `lessons/part2-tv-and-tia/06-cycle-counting/`
**Concepts:** Every 6502 instruction takes a specific number of cycles. Cycle table for common instructions. Counting cycles in a kernel loop. Why 76 cycles matters. What happens if you exceed 76 cycles. NOP for padding (2 cycles). BIT $00 for 3-cycle waste.
**ASM File:** ROM with carefully counted kernel loop, annotated with cycle counts per instruction.
**Exercises:** Count cycles for given code sequences, pad code to exactly 76 cycles, optimize a loop to be 2 cycles shorter.

### Lesson 18: Mid-Scanline Changes — Racing the Beam
**Directory:** `lessons/part2-tv-and-tia/07-midline-changes/`
**Concepts:** Changing COLUBK mid-scanline to create a "split" — left half one color, right half another. Precise cycle counting determines WHERE on the line the change happens. The HBLANK region (first 22 CPU cycles). This IS "racing the beam."
**DSL Note:** This is where manual cycle counting becomes painful — and where a DSL could help enormously.
**ASM File:** ROM with mid-scanline color split — vertical color boundary on screen.
**Exercises:** Move the split point left/right by adjusting cycle count, create a 3-color horizontal stripe, make the split point change each frame (animation).

---

## Part 3: Playfield Graphics (6 lessons)

*Draw backgrounds, walls, and mazes.*

### Lesson 19: Playfield Basics — PF0, PF1, PF2
**Directory:** `lessons/part3-playfield/01-playfield-basics/`
**Concepts:** The 20-bit playfield (PF0: 4 bits, PF1: 8 bits, PF2: 8 bits). Each PF pixel = 4 color clocks wide. Bit ordering (PF0: bits 4-7 left-to-right, PF1: bit 7 first, PF2: bit 0 first). Mirror vs. repeat (CTRLPF bit 0).
**ASM File:** ROM drawing simple symmetric walls using mirrored playfield.
**Exercises:** Draw specific patterns (border, cross, diamond), experiment with mirror vs. repeat.

### Lesson 20: Playfield Colors and Priority
**Directory:** `lessons/part3-playfield/02-playfield-colors/`
**Concepts:** COLUPF register. SCORE mode (CTRLPF bit 1) — left half uses COLUP0, right half uses COLUP1. Playfield priority (CTRLPF bit 2) — PF in front of or behind sprites. Ball size (CTRLPF bits 4-5).
**ASM File:** ROM with SCORE mode showing different-colored playfield halves.
**Exercises:** Create a "two-team" scoreboard effect, experiment with priority settings.

### Lesson 21: Asymmetric Playfield — Different Left and Right
**Directory:** `lessons/part3-playfield/03-asymmetric-playfield/`
**Concepts:** The mid-scanline PF register change trick. Writing PF0/PF1/PF2 once for left half, then rewriting them mid-scanline for different right half. Cycle-critical timing. Why this is hard (and why games like Adventure use it).
**DSL Note:** Asymmetric playfield is a perfect candidate for code generation — specify left/right patterns, generate the timed code.
**ASM File:** ROM with different left and right playfield halves.
**Exercises:** Create an asymmetric maze, implement an asymmetric scoreboard.

### Lesson 22: Playfield Animation — Moving Walls
**Directory:** `lessons/part3-playfield/04-playfield-animation/`
**Concepts:** Changing PF data each frame for animation. Scrolling playfield (shifting bits). Using RAM to store current playfield state. Frame-based animation timing.
**ASM File:** ROM with animated playfield — walls that pulse or scroll.
**Exercises:** Implement horizontal scrolling, create a "growing wall" animation, build a simple loading animation.

### Lesson 23: Data-Driven Playfield — Levels from Tables
**Directory:** `lessons/part3-playfield/05-data-driven-playfield/`
**Concepts:** Storing playfield graphics as ROM tables (one entry per scanline). Reading PF data per line from tables. Level data format. Compressing playfield data (2-line kernel technique preview).
**ASM File:** ROM that draws a maze from table data — different patterns at different screen heights.
**Exercises:** Design a custom level layout, implement multiple levels that switch on button press.

### Lesson 24: The Multicolor Playfield
**Directory:** `lessons/part3-playfield/06-multicolor-playfield/`
**Concepts:** Changing COLUPF per scanline for multicolor playfield graphics. Combined with data tables for fully colored backgrounds. The cost: more CPU time per scanline means less time for sprites.
**ASM File:** ROM with a colorful background — trees, mountains, etc. using per-line PF colors.
**Exercises:** Create a sunset scene with colored playfield, combine with horizontal zones.

---

## Part 4: Sprites — Players, Missiles, Ball (8 lessons)

*Moving objects on screen.*

### Lesson 25: Player Sprite Basics — GRP0, Your First Character
**Directory:** `lessons/part4-sprites/01-player-basics/`
**Concepts:** GRP0 register (8 bits = 8 pixels wide). Loading sprite graphics per scanline from a table. Sprite height (draw only on the right scanlines). Comparing current scanline to sprite Y position. REFP0 for horizontal flip.
**ASM File:** ROM drawing a simple 8-pixel character (stick figure or arrow) at a fixed position.
**Exercises:** Design your own 8×16 sprite bitmap, change the sprite position vertically, add REFP0 flipping.

### Lesson 26: Horizontal Positioning — The Divide-by-15 Trick
**Directory:** `lessons/part4-sprites/02-horizontal-positioning/`
**Concepts:** RESP0 strobe (sets position to current beam location). The problem: beam position depends on WHEN you hit RESP0. The solution: a timed delay loop. The divide-by-15 algorithm. Fine positioning with HMP0 + HMOVE. HMCLR. The HMOVE "comb" artifact (8-pixel black bar).
**ASM File:** ROM that positions a sprite at an arbitrary X coordinate using the standard positioning routine.
**Exercises:** Position sprite at specific X coordinates, understand the delay loop math, handle the HMOVE comb.

### Lesson 27: Sprite Movement — Reading the Joystick
**Directory:** `lessons/part4-sprites/03-sprite-movement/`
**Concepts:** SWCHA register (joystick directions). Bit masking to extract P0 directions (AND #$F0). Moving sprite: updating X/Y position in RAM. Applying horizontal position each frame. Boundary checking (screen edges).
**ASM File:** ROM with a moveable sprite — joystick controls position. First truly interactive program!
**Exercises:** Add boundary clamping, implement acceleration/deceleration, add diagonal movement smoothing.

### Lesson 28: Two Players — GRP0 and GRP1
**Directory:** `lessons/part4-sprites/04-two-players/`
**Concepts:** GRP1 register and COLUP1. Positioning both players independently. Reading P1 joystick (SWCHA bits 0-3). The challenge: positioning two sprites on the same scanline requires careful timing. When sprites overlap.
**ASM File:** ROM with two independently moveable sprites.
**Exercises:** Have P2 controlled by AI (simple chase algorithm), position sprites on the same scanline.

### Lesson 29: Missiles and Ball — Simple Projectiles
**Directory:** `lessons/part4-sprites/05-missiles-and-ball/`
**Concepts:** ENAM0/ENAM1 (enable missiles), ENABL (enable ball). Missile inherits player color. Ball uses playfield color. Missile/ball size (NUSIZ/CTRLPF). Positioning missiles and ball (RESM0/RESM1/RESBL + HM registers). RESMP0/RESMP1 (lock missile to player center).
**ASM File:** ROM with a player that fires missiles on button press.
**Exercises:** Implement bullet firing with fire button, add ball as a bouncing object, create missile trails.

### Lesson 30: Multi-Color Sprites — Changing Colors Per Line
**Directory:** `lessons/part4-sprites/06-multicolor-sprites/`
**Concepts:** Changing COLUP0 each scanline within the sprite to get multiple colors. Color table per sprite line. This is how real games get "detailed" sprites (e.g., Pitfall Harry has different colored hat, shirt, pants).
**ASM File:** ROM with a multi-colored player sprite (3+ colors).
**Exercises:** Design a multi-color character, animate colors for a "flashing" effect.

### Lesson 31: Copies and Sizes — NUSIZ Register
**Directory:** `lessons/part4-sprites/07-copies-and-sizes/`
**Concepts:** NUSIZ0/NUSIZ1 lower 3 bits: number and spacing of player copies (1, 2 close, 2 medium, 3 close, 2 wide, double-size, 3 medium, quad-size). Upper 2 bits: missile size (1, 2, 4, 8 pixels). Using copies for multi-sprite effects without extra sprites.
**ASM File:** ROM demonstrating each NUSIZ setting visually.
**Exercises:** Use 3-copy mode for enemy formations, create a "wall of missiles" effect.

### Lesson 32: Vertical Delay — VDELP0, VDELP1
**Directory:** `lessons/part4-sprites/08-vertical-delay/`
**Concepts:** VDELP0/VDELP1: delay GRP0/GRP1 updates by one scanline. Why this exists: enables the 48-pixel sprite trick. How delayed writes work (write to GRP0 → takes effect immediately, write to GRP1 → GRP0 gets its delayed value). The "cosmic swap" technique.
**ASM File:** ROM demonstrating VDEL behavior — comparison with and without delay.
**Exercises:** Experiment with VDEL timing, prepare for the 48-pixel trick in the next part.

---

## Part 5: Sound (3 lessons)

*The TIA's distinctive audio.*

### Lesson 33: Sound Effects — Beeps, Boops, and Explosions
**Directory:** `lessons/part5-sound/01-sound-effects/`
**Concepts:** AUDC0/AUDC1 (tone type: 0-15, including pure tone, noise, buzzy, etc.). AUDF0/AUDF1 (frequency divider: 0-31). AUDV0/AUDV1 (volume: 0-15). The 16 tone types and what they sound like. Envelope patterns (volume fade for explosions, pitch slides for effects).
**ASM File:** ROM with sound effects triggered by button/joystick — jump sound, explosion, pickup.
**Exercises:** Create 5 different sound effects, implement a volume decay envelope.

### Lesson 34: Music — Melodies on the TIA
**Directory:** `lessons/part5-sound/02-music/`
**Concepts:** Musical note frequency table for TIA. Limitations: TIA frequencies don't match standard musical notes perfectly (everything is slightly out of tune). Sequencing: frame-based timing for note duration. Two-channel harmony. Song data format in ROM tables.
**ASM File:** ROM that plays a simple melody (e.g., "Ode to Joy" or a game jingle).
**Exercises:** Compose a 16-note melody, add a bass line on channel 2, implement tempo control.

### Lesson 35: Advanced Audio — Sound Engine Design
**Directory:** `lessons/part5-sound/03-advanced-audio/`
**Concepts:** Sound engine architecture: priority system (SFX overrides music), channel allocation, sound queuing. Frame counter-based timing. Sound data format. Building a reusable sound engine as an include file.
**DSL Note:** The sound engine is a perfect candidate for the reusable library — define sounds in data, engine plays them.
**Library Addition:** `include/sound.asm` — reusable sound engine.
**ASM File:** ROM with background music that pauses for sound effects, then resumes.
**Exercises:** Add new sounds to the engine, implement sound priority, create a "music player" mode.

---

## Part 6: Game Development (8 lessons)

*From tech demos to real games.*

### Lesson 36: Collision Detection — When Things Touch
**Directory:** `lessons/part6-game-dev/01-collision-detection/`
**Concepts:** TIA hardware collision registers (CXM0P, CXM1P, CXP0FB, CXP1FB, etc.). Reading collision bits (bit 7 and bit 6). CXCLR (clear collision latches). When to read collisions (after kernel, before CXCLR). Combining hardware collisions with position-based checks.
**ASM File:** ROM where two sprites collide and change color on contact.
**Exercises:** Detect player-playfield collision, implement "bounce" behavior on collision, add visual feedback (flash, sound).

### Lesson 37: The Scoreboard — 48-Pixel Sprite Trick
**Directory:** `lessons/part6-game-dev/02-scoreboard/`
**Concepts:** The famous 48-pixel sprite: using VDELP0 + VDELP1 + NUSIZ (3 copies) to display 6 digits across the screen. Cycle-exact timing. Digit font table (8×5 or 8×8 bitmaps for 0-9). BCD (Binary Coded Decimal) arithmetic for score keeping. The SED/CLD instructions.
**Library Addition:** `include/score.asm` — scoreboard display routines + BCD helpers.
**ASM File:** ROM with a 6-digit score at the top that increments each frame.
**Exercises:** Add score increment on button press, implement a countdown timer, display 2-player scores.

### Lesson 38: BCD Arithmetic — Scores That Make Sense
**Directory:** `lessons/part6-game-dev/03-bcd-arithmetic/`
**Concepts:** Binary Coded Decimal: each nibble stores one decimal digit (0-9). SED (set decimal mode), CLD (clear decimal mode). BCD addition and subtraction. Multi-byte BCD for scores > 99. Converting BCD to digit indices for the scoreboard.
**ASM File:** ROM with BCD score that increments by different amounts.
**Exercises:** Implement score addition with carry, create a "lives" counter, implement a high score comparison.

### Lesson 39: Game States — Title, Play, Game Over
**Directory:** `lessons/part6-game-dev/04-game-states/`
**Concepts:** State machine architecture: title screen → gameplay → game over → back to title. State variable in RAM. Different kernel for each state. Reading RESET and SELECT switches (SWCHB). Debouncing button inputs.
**TS Analogy:** `enum GameState { Title, Playing, GameOver }` + `switch(state)` pattern.
**ASM File:** ROM with 3 game states: title (press fire to start), gameplay (simple), game over (press fire to restart).
**Exercises:** Add a "select" mode between title and play, implement a pause function, add a "high score" state.

### Lesson 40: Difficulty and Progression
**Directory:** `lessons/part6-game-dev/05-difficulty/`
**Concepts:** Difficulty switches (SWCHB bits 6-7). Progressive difficulty (speed increases, more enemies). Level system. Frame-based timers for difficulty ramping. Reading difficulty switch positions.
**ASM File:** ROM with gameplay that gets progressively harder each level.
**Exercises:** Implement 3 difficulty curves (linear, exponential, stepped), use difficulty switches to set starting level.

### Lesson 41: Random Numbers — Unpredictable Fun
**Directory:** `lessons/part6-game-dev/06-random-numbers/`
**Concepts:** LFSR (Linear Feedback Shift Register) — pseudo-random number generation in 1-2 bytes of RAM. The Galois LFSR implementation. Seeding from INTIM (timer value = semi-random on startup). Random number ranges (AND mask, repeated generation).
**Library Addition:** `include/random.asm` — LFSR random number generator.
**ASM File:** ROM with randomly placed objects that change each frame.
**Exercises:** Implement a random color background, create a "random maze" generator, build a slot machine effect.

### Lesson 42: Memory Management — 128 Bytes of Creativity
**Directory:** `lessons/part6-game-dev/07-memory-management/`
**Concepts:** Organizing 128 bytes for a real game. Bit packing (multiple booleans in one byte). Overlapping variables for different game states. The stack vs. variables tradeoff. Memory map documentation. Clever techniques: timer variables, shared temp space.
**TS Analogy:** Like building an app where total state must fit in 128 bytes — extreme compression of game state.
**ASM File:** ROM demonstrating a complete game memory layout with packed variables.
**Exercises:** Design a memory map for a Pong game, pack 8 boolean flags into one byte, implement a "scratch pad" region.

### Lesson 43: Debugging — Finding and Fixing Bugs
**Directory:** `lessons/part6-game-dev/08-debugging/`
**Concepts:** Common 2600 bugs and their symptoms: rolling screen (wrong scanline count), HMOVE comb in wrong place, sprite at wrong position, flickering, wrong colors. Using Stella debugger: breakpoints, memory watches, scanline analysis, TIA state inspection. Systematic debugging approach.
**ASM File:** ROM with several intentional bugs — student must find and fix each one.
**Exercises:** Fix 5 different bugs, explain the root cause of each, add diagnostic code that shows frame count on screen.

---

## Part 7: Kernel Mastery (6 lessons)

*The art of drawing complex screens.*

### Lesson 44: The 2-Line Kernel — Standard Game Pattern
**Directory:** `lessons/part7-kernel-mastery/01-two-line-kernel/`
**Concepts:** Why 1-line kernels are limiting (not enough CPU time). The 2-line kernel: process 2 scanlines per loop iteration = double the CPU time per "row." Even/odd scanline handling. Most commercial games use this approach.
**ASM File:** ROM with a 2-line kernel drawing a player sprite with more complex logic per line.
**Exercises:** Convert the 1-line rainbow kernel to 2-line, add player positioning to 2-line kernel, measure cycle savings.

### Lesson 45: Multi-Zone Kernel — Scoreboard + Playfield + Sprites
**Directory:** `lessons/part7-kernel-mastery/02-multi-zone-kernel/`
**Concepts:** Different drawing code for different screen regions. Scoreboard zone (48-pixel digits, 16 lines), game zone (playfield + sprites, 160 lines), status zone (lives/indicators, 16 lines). Zone switching with scanline counters.
**ASM File:** ROM with full multi-zone display: score at top, game area in middle, lives at bottom.
**Exercises:** Add a 4th zone, adjust zone heights, implement smooth zone transitions.

### Lesson 46: Flicker Sprites — More Than 2 Objects
**Directory:** `lessons/part7-kernel-mastery/03-flicker-sprites/`
**Concepts:** The 2600 only has 2 player sprites. But games like Space Invaders show many objects. Solution: alternate which objects are drawn each frame (30fps flicker). Object lists. Priority rotation (so flickering is evenly distributed). VDEL for smoother flicker.
**ASM File:** ROM displaying 4+ objects using frame-alternating flicker.
**Exercises:** Display 6 objects with minimal perceived flicker, implement priority-based flicker rotation.

### Lesson 47: Fine Scrolling — Smooth Movement
**Directory:** `lessons/part7-kernel-mastery/04-fine-scrolling/`
**Concepts:** Coarse scrolling (shifting playfield data) vs. fine scrolling (using HMxx for sub-pixel movement). Horizontal scrolling: combine PF shift with fine position. Vertical scrolling: shift data table pointer. Wrap-around and seamless scrolling.
**ASM File:** ROM with horizontally scrolling playfield background.
**Exercises:** Implement vertical scrolling, combine horizontal and vertical for diagonal scroll, add a stationary player over scrolling background.

### Lesson 48: Kernel Design Patterns — Building Your Toolkit
**Directory:** `lessons/part7-kernel-mastery/05-kernel-patterns/`
**Concepts:** Review and codify kernel patterns: simple (background only), single-sprite, dual-sprite, 2-line, multi-zone, scrolling. When to use each pattern. Performance characteristics. Template kernels for common game types (platformer, shooter, sports, puzzle).
**DSL Note:** These kernel patterns become the core of the DSL — each pattern is a "template" that game logic plugs into.
**Library Addition:** `include/kernel_patterns.asm` — reusable kernel templates.
**ASM File:** ROM demonstrating switching between kernel patterns.
**Exercises:** Modify a kernel template for a specific game concept, benchmark different kernel patterns.

### Lesson 49: Scrolling Text Marquee — The Activision Logo Effect
**Directory:** `lessons/part7-kernel-mastery/06-scrolling-text-marquee/`
**Concepts:** The iconic Activision scrolling copyright text seen in Pitfall!, River Raid, Kaboom!, Enduro, and every other Activision 2600 title. Combines three master techniques into one effect:
1. **48-pixel sprite rendering** — GRP0/GRP1 with VDEL + NUSIZ 3-copy mode for 6 characters across the screen
2. **Character/font system** — 5×7 or 8×8 character bitmaps stored in ROM, indexed by ASCII-like character codes
3. **Horizontal bitmap scrolling** — Bit-shifting across 6 bytes of display buffer each frame for smooth pixel-level scrolling
4. **String rendering** — Reading a null-terminated string from ROM ("© 2026 YOUR_NAME"), compositing characters into the 6-byte buffer, feeding new characters as old ones scroll off the left edge
5. **Wrapping** — Seamless looping when the string ends (restart from beginning or add padding)
**Prerequisites:** Lesson 37 (48-pixel trick), Lesson 47 (fine scrolling), Lesson 32 (VDEL)
**TS Analogy:** Like a `<marquee>` HTML element — but you're rendering it pixel by pixel, 60 times per second, in real-time on hardware with no frame buffer.
**DSL Note:** This is a perfect candidate for a high-level DSL command: `scroll_text "© 2026 MY_GAME"` → generates all the rendering code automatically.
**ASM File:** ROM with a scrolling "© 2026 ATARI MASTERCLASS" text at the bottom of the screen, over a colored background.
**Exercises:** Change the scrolling text to your own message, adjust scroll speed (pixels per frame vs. pixels per N frames), add a second scrolling line (bonus: bidirectional scrolling), implement variable-width characters.

---

## Part 8: Advanced Techniques (5 lessons)

*Push the hardware to its limits.*

### Lesson 50: Bankswitching — Beyond 4KB
**Directory:** `lessons/part8-advanced/01-bankswitching/`
**Concepts:** Why 4KB isn't enough for complex games. How bankswitching works (ROM bank selection via address line triggers). F8 (8KB, 2 banks), F6 (16KB, 4 banks), F4 (32KB, 8 banks). Bank switching code (JMP to "hotspot" address). Organizing code across banks. The trampoline technique.
**ASM File:** 8KB ROM using F8 bankswitching — each bank has different graphics/levels.
**Exercises:** Build a 16KB ROM with 4 banks, implement a bank-switch trampoline, organize game data across banks.

### Lesson 51: Superchip — Extra RAM
**Directory:** `lessons/part8-advanced/02-superchip/`
**Concepts:** Superchip adds 128 bytes of extra RAM on the cartridge ($1000-$107F write, $1080-$10FF read). Total RAM: 256 bytes. How to use it. Games that use it (Pitfall II type features). When you need more RAM.
**ASM File:** ROM using Superchip RAM for expanded game state.
**Exercises:** Move game data to Superchip RAM, implement a larger game state.

### Lesson 52: Illegal Opcodes — Undocumented Power
**Directory:** `lessons/part8-advanced/03-illegal-opcodes/`
**Concepts:** Undocumented 6502 instructions: LAX, SAX, DCP, ISC, SLO, RLA, SRE, RRA, ANC, ALR, ARR, AXS, NOP variants. Why they work (instruction decoder quirks). When to use them (cycle saving in tight kernels). Reliability considerations. Which ones are safe on all 6507s.
**ASM File:** ROM using LAX and SAX to save cycles in a kernel loop — comparison with legal equivalent.
**Exercises:** Replace legal instructions with illegal equivalents where beneficial, measure cycle savings.

### Lesson 53: DPC and DPC+ — Enhanced Audio and Graphics
**Directory:** `lessons/part8-advanced/04-dpc-plus/`
**Concepts:** DPC (Pitfall II's co-processor). DPC+ (modern Harmony/Melody cartridge feature). ARM-assisted graphics. What modern homebrew can do vs. stock hardware. CDFJ bankswitching. Overview of the Harmony cartridge.
**ASM File:** Conceptual overview with diagrams — DPC+ requires Harmony hardware knowledge. Focus on understanding the architecture.
**Exercises:** Research a modern homebrew game using DPC+, analyze its capabilities vs. stock TIA.

### Lesson 54: Modern Homebrew — Running on Real Hardware
**Directory:** `lessons/part8-advanced/05-modern-homebrew/`
**Concepts:** Harmony cartridge (flashable dev cart), PlusCart (WiFi-enabled), UnoCart. ROM file formats (.bin, .a26). Testing on real hardware vs. emulator differences. AtariAge homebrew community. Publishing your game. PCB manufacturing overview.
**ASM File:** No new ROM — this is a resource/guide lesson.
**Exercises:** Research the AtariAge homebrew forum, find 3 modern homebrew games to study, plan your own game concept.

---

## Part 9: Toward the DSL (3 lessons)

*Analyzing patterns for automation — the foundation of your future DSL.*

### Lesson 55: Analyzing batari BASIC — How bB Works
**Directory:** `lessons/part9-dsl-path/01-analyzing-batari-basic/`
**Concepts:** What batari BASIC is. Its kernel architecture (standard kernel, multisprite kernel, DPC+ kernel). How bB translates BASIC-like syntax to 6502 assembly. What it does well (accessibility). What it can't do (limited kernel customization). Source code analysis.
**ASM File:** Equivalent programs in bB syntax and hand-written assembly — side-by-side comparison.
**Exercises:** Identify 5 patterns bB automates, list 5 things bB can't do that raw assembly can.

### Lesson 56: Identifying Automatable Patterns
**Directory:** `lessons/part9-dsl-path/02-automatable-patterns/`
**Concepts:** Review all lessons and identify repeating patterns: frame loop boilerplate, sprite positioning routine, kernel template selection, score display, sound effect triggering, playfield data encoding, memory map generation. Each pattern = a potential DSL feature.
**DSL Design:** Document each pattern with: input description, output assembly, constraints, variations.
**ASM File:** No new ROM — this is an analysis/design lesson. Output is a design document.
**Exercises:** Design the "API" for 3 DSL features, sketch a DSL syntax for sprite definition, prototype a playfield data encoder (in TypeScript).

### Lesson 57: Designing Your Kernel Architecture
**Directory:** `lessons/part9-dsl-path/03-kernel-architecture/`
**Concepts:** Designing a flexible kernel framework: pluggable zones (score, game, status), configurable sprite slots, event system (collision callbacks, input handlers), data-driven level loading. This becomes the runtime that the DSL compiles against.
**DSL Design:** Architecture document for the kernel framework.
**Library Addition:** `include/kernel_framework.asm` — the master kernel template.
**ASM File:** ROM using the kernel framework — demonstrating plugin-style zone configuration.
**Exercises:** Implement a new zone type in the framework, add a new sprite slot, design the DSL compilation pipeline.

---

## Part 10: Capstone Projects (4 lessons)

*Put it all together — build real games.*

### Lesson 58: Capstone 1 — Pong
**Directory:** `lessons/part10-capstones/01-pong/`
**Concepts:** Complete game: two paddles, ball, scoring (6-digit BCD), sound effects, title screen, game over, difficulty ramping, difficulty switches. Demonstrates: playfield (court lines), 2 player sprites (paddles), ball object, collision detection, scoreboard, sound engine, game states.
**Guided Build:** Step-by-step construction over the lesson, building each system incrementally.
**ASM File:** Complete Pong game ROM.
**Exercises:** Add AI opponent, implement serve direction variation, add "english" (ball angle based on paddle hit position).

### Lesson 59: Capstone 2 — Breakout
**Directory:** `lessons/part10-capstones/02-breakout/`
**Concepts:** Paddle controller support (INPT0-3), brick field using playfield, brick destruction via playfield updates, ball physics (angle changes), multiple levels, power-ups (wider paddle, multi-ball concept via flickering).
**Guided Build:** Incremental construction with emphasis on playfield manipulation.
**ASM File:** Complete Breakout game ROM.
**Exercises:** Add multiple ball speeds, implement a "power brick" that drops a bonus, add level transition effects.

### Lesson 60: Capstone 3 — Maze Explorer
**Directory:** `lessons/part10-capstones/03-maze-game/`
**Concepts:** Room-based world (multiple screens), playfield walls, player sprite navigation, item collection, room transitions, data-driven level design from tables, key/door mechanics, inventory in status bar.
**Guided Build:** Focus on data-driven design — levels defined as data, not code.
**ASM File:** Complete maze exploration game ROM (4+ rooms).
**Exercises:** Add more rooms, implement an enemy that patrols, add a collectible item count.

### Lesson 61: Capstone 4 — Your Own Game
**Directory:** `lessons/part10-capstones/04-your-game/`
**Concepts:** Game design process: concept → requirements → technical plan → implementation → polish. Using the kernel framework from Part 9. Planning within hardware constraints. Balancing ambition with 128 bytes of RAM and 4KB of ROM.
**Guided Design:** Template for game design document, technical checklist, milestone plan.
**ASM File:** Skeleton ROM using kernel framework — student fills in game-specific logic.
**Exercises:** Complete your game! Share it on AtariAge.

---

## Summary

| Part | Lessons | New Library Files |
|------|---------|-------------------|
| Part 0: Foundations | 3 (01-03) | — |
| Part 1: 6502 CPU | 8 (04-11) | — |
| Part 2: TV & TIA | 7 (12-18) | — |
| Part 3: Playfield | 6 (19-24) | — |
| Part 4: Sprites | 8 (25-32) | `include/position.asm` |
| Part 5: Sound | 3 (33-35) | `include/sound.asm` |
| Part 6: Game Dev | 8 (36-43) | `include/score.asm`, `include/random.asm` |
| Part 7: Kernel Mastery | 6 (44-49) | `include/kernel_patterns.asm` |
| Part 8: Advanced | 5 (50-54) | — |
| Part 9: DSL Path | 3 (55-57) | `include/kernel_framework.asm` |
| Part 10: Capstones | 4 (58-61) | — |
| **TOTAL** | **61** | **5 library files** |
