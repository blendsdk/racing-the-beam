---
name: Atari 2600 Expert
description: Expert Atari 2600 (VCS) hardware and game-development knowledge — 6502/6507 assembly, TIA and RIOT programming, NTSC/PAL timing, kernel design, sprite/playfield tricks, sound, bankswitching, legendary techniques, and the pitfalls that break real ROMs. Use when writing, reviewing, debugging, or teaching Atari 2600 assembly or hardware behavior.
---

# Atari 2600 Expert

This skill is the project's reference-grade knowledge of the Atari 2600 and its 6507 CPU.
It exists so that lesson content, assembly code, and technical claims in this course are
grounded in how the hardware actually behaves — not in plausible-sounding approximations.

## How to use this skill

1. **Read the project ground truth first.** Hardware register names and their bit layouts are
   authoritative in `include/vcs.asm`. When writing TIA/RIOT access code, that file wins over
   anything in this skill — if they disagree, fix the code to match `include/vcs.asm` and flag
   the discrepancy for review.
2. **Load the reference you need** (see the map below) — don't guess numbers.
3. **Verify behavior, don't assume it.** Assemble every snippet and run it in Stella (the
   debugger shows RAM, TIA registers, and cycle counts live). A claim about timing or graphics
   that has not been observed in Stella is an *unverified claim* — mark it as such or drop it.
4. **Prefer the small, well-understood idiom.** The 2600 rewards simple, cycle-counted code.
   Clever code that nobody can re-count is a defect in this course.

## Reference map

| Read this | When you need |
| --- | --- |
| `references/6502-cpu.md` | Registers, flags, addressing modes, instruction/cycle tables, stack, ACME syntax |
| `references/tia-hardware.md` | TIA registers, write-vs-read semantics, NUSIZ/CTRLPF bit tables, RIOT, memory map |
| `references/timing.md` | Color clocks vs CPU cycles, scanline and frame structure, WSYNC/HMOVE/RESP rules |
| `references/kernels.md` | Kernel archetypes (1-line, 2-line, multi-zone), beam-racing patterns |
| `references/sprite-tricks.md` | Positioning, fine motion, copies, flicker, multicolor, VDEL tricks |
| `references/sound.md` | AUDC/AUDF/AUDV behavior, sound-effect recipes |
| `references/bankswitching.md` | 4K limits, F8/F6/F4, DPC/DPC+, superchip facts |
| `references/legendary.md` | Cosmic Ark starfield, skipdraw, pseudo-3D, LFSR worlds, interlacing, Adventure engine |
| `references/pitfalls.md` | The classic mistakes and how they show up on screen |
| `references/sources.md` | Canonical external references to cite and verify against |

## The ten rules that keep programs honest

These are the mistakes that break nearly every beginner 2600 program. Repeat them to
yourself before writing any kernel:

1. **`#` means literal, its absence means memory.** `LDA #$80` loads the number; `LDA $80` loads
   the byte stored at address `$80`. This is the single most common bug.
2. **TIA registers are write-only at their write addresses; read registers live at the same
   addresses.** `WBLANK` is `$01` *when written*; the CPU never reads it back. Reading a TIA
   address may return a collision or input bit instead — see `tia-hardware.md`.
3. **There is no frame buffer.** You draw every scanline, every frame, in real time. Being one
   cycle late changes the picture.
4. **One scanline is exactly 76 CPU cycles** (228 color clocks). Exceed it and the frame grows
   extra lines — the picture rolls or tears. Count your cycles in the kernel.
5. **`WSYNC` halts the CPU until the next horizontal blank.** It is 3 cycles to write, and the
   CPU resumes at the *start* of the next scanline. It is both a sync tool and a (rarely wanted)
   cycle cost.
6. **`HMOVE` belongs immediately after `WSYNC`.** Strobing it outside horizontal blank causes
   the famous "HMOVE comb" artifacts and unexpected shifts. Don't rewrite motion registers for
   ~24 cycles after an `HMOVE`.
7. **`RESP0`/`RESM0`/`RESBL` position an object where the beam is — quantized to 3 color
   clocks — plus a fixed output delay** (players ≈ 5 clocks, missiles/ball ≈ 4). Combine with
   `HMP0` fine motion for exact placement.
8. **RAM is 128 bytes at `$80–$FF`.** The stack lives in page `$01`, which mirrors the same
   physical RAM — a deep stack collides with your variables.
9. **The cartridge window is 4K at `$F000–$FFFF`** with the vectors at `$FFFA`. Programs that
   "don't start" usually forgot the vectors or didn't fill the ROM to 4K.
10. **NTSC is 262 lines at ~60 Hz; PAL is 312 lines at ~50 Hz.** A fixed-line-count ROM made
    for NTSC shows a rolling picture on PAL hardware (and vice versa) — this is a real
    compatibility topic, not a detail.

## Project conventions (Racing the Beam)

- Assembler: **ACME 0.97** (`!cpu 6502`, `!source "include/vcs.asm"`, macros in
  `include/macro.asm`). The course was migrated from DASM — never emit DASM syntax.
- Lesson assembly sources live in `lessons/partN-.../NN-slug/NN-slug.asm`; exercise solutions
  sit beside them as `exercise-NN-solution.asm`.
- The shared startup macro `+clean_start` zeroes TIA registers and RAM and sets the stack; the
  frame macros `+vsync`, `+set_timer`, `+wait_timer` cover the standard frame skeleton.
- Variable naming and comment style follow the existing lessons — read the two nearest
  completed lessons before writing a new one.
- The per-lesson production workflow (screenshots, ROMs, VitePress updates, README sync) lives
  in the `vcs-lesson-production` skill — load it when the task is authoring or updating a
  lesson.

## Claim discipline

When this skill or a lesson asserts something non-obvious, aim for one of:

- **Observed** — verified in Stella (say how, e.g. "Stella debugger shows 76 cycles/line").
- **Documented** — cited from `references/sources.md` (name the source).
- **Derived** — follows from arithmetic on observed/documented facts (show the math).

If none apply, don't state it as fact. "I believe, but could not verify" is an acceptable,
honest sentence in review notes.
