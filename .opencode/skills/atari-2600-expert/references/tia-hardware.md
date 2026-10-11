# TIA & RIOT Hardware — Reference

> **Ground truth for addresses and bit positions in this project: `include/vcs.asm`.**
> This file explains *semantics* — what the registers do and how they interact. If a
> number here and `include/vcs.asm` disagree, `include/vcs.asm` wins.

## The address regions the CPU sees

| Range | Device | Notes |
| --- | --- | --- |
| `$00–$3F` | TIA (write and read) | Write addresses and read addresses overlap; mirrors fill `$40–$7F` and again within the 13-bit bus |
| `$80–$FF` | RIOT RAM | 128 bytes — all of it zero page |
| `$0280–$0297` | RIOT I/O + timer | mirrors elsewhere in `$0280–$03FF` |
| `$F000–$FFFF` | Cartridge ROM | 4K; vectors at `$FFFA–$FFFF` |

## The TIA model: five objects drawn per scanline

The TIA has no frame buffer. For each scanline, the beam moves left to right and the TIA
decides, color clock by color clock, what color to output. Five movable objects plus the
playfield:

| Object | Color register | Graphic control | Positioning |
| --- | --- | --- | --- |
| Player 0 | `COLUP0` | `GRP0` (8 bits) | `RESP0` + `HMP0`; copies/size via `NUSIZ0` |
| Player 1 | `COLUP1` | `GRP1` | `RESP1` + `HMP1`; `NUSIZ1` |
| Missile 0 | `COLUP0` | `ENAM0` | `RESM0` + `HMM0`; width in `NUSIZ0` |
| Missile 1 | `COLUP1` | `ENAM1` | `RESM1` + `HMM1`; `NUSIZ1` |
| Ball | `COLUPF` | `ENABL` | `RESBL` + `HMBL`; size in `CTRLPF` |
| Playfield | `COLUPF` | `PF0/PF1/PF2` (20 bits) | fixed; 4-color-clock-wide pixels |
| Background | `COLUBK` | — | fills everything else |

Consequences worth internalizing:

- **Vertical position = which scanlines you write the graphic register for.** There is no
  "y register". You count scanlines and write `GRP0`/`GRP1`/`ENAMx`/`ENABL` on the right ones.
- **Horizontal position = a strobe plus fine motion** (see `sprite-tricks.md`).
- **Sprites are one scanline tall per write.** A "sprite" is a loop writing the same byte
  once per line for as many lines as the shape is tall.
- **Missiles share their player's color**; the ball shares the playfield's color.

## Playfield bit order (the classic confusion)

The playfield is **20 bits** covering the left half of the screen (in **repeat** mode the
right half repeats it; in **reflect** mode it mirrors it). The bits map to screen pixels
like this:

| Register | Bits used | Pixel order on screen (left → right) |
| --- | --- | --- |
| `PF0` | 4–7 | bit **4** is the leftmost pixel (pixels 0–3) |
| `PF1` | 7–0 | bit **7** is the leftmost pixel (pixels 4–11) |
| `PF2` | 0–7 | bit **0** is the leftmost pixel (pixels 12–19, reaching screen center) |

Each playfield "pixel" is **4 color clocks** wide — 40 chunks across the visible line.
`PF2`'s reversed bit order (vs. `PF1`) and `PF0`'s untouched low nibble are the two
playfield mistakes that cost beginners evenings.

## Write registers — semantics

| Register | Semantics |
| --- | --- |
| `VSYNC` ($00) | Bit 1 (value 2) = vertical sync on/off. Standard: on for 3 lines. |
| `VBLANK` ($01) | Bit 1 (value 2) = blank screen. Bit 6 = latch paddle inputs. Bit 7 = discharge paddles. |
| `WSYNC` ($02) | **Strobe.** Any write pauses the CPU until the end of the scanline. |
| `RSYNC` ($03) | Strobe; resets the horizontal sync counter (rare; used by one famous trick). |
| `NUSIZ0/1` ($04/$05) | Player copies/size in bits 0–2, missile width in bits 4–5 (tables below). |
| `COLUP0/1` ($06/$07), `COLUPF` ($08), `COLUBK` ($09) | Colors, format `%HHHHLLL0`: hue 0–15, luminance 0–7. NTSC 128 colors, PAL 104. |
| `CTRLPF` ($0A) | Bit 0 `REF`: mirror the right playfield half. Bit 1 `SCORE`: left half uses P0 color, right half P1 color. Bit 2 `PFP`: playfield+ball priority (see priority below). Bits 4–5: ball size. |
| `REFP0/1` ($0B/$0C) | Bit 3 (value 8): mirror that player sprite horizontally. |
| `PF0/PF1/PF2` ($0D–$0F) | Playfield bits (see the table above). |
| `RESP0/1`, `RESM0/1`, `RESBL` ($10–$14) | **Strobe.** Set that object's horizontal position to "where the beam is"; quantized, plus a fixed output delay (players ≈ 5 clocks, missiles/ball ≈ 4). |
| `AUDC0/1` `AUDF0/1` `AUDV0/1` ($15–$1A) | Audio: timbre, frequency divider, volume. See `sound.md`. |
| `GRP0` `GRP1` ($1B/$1C) | Player graphics: 8 pixels, bit 7 = leftmost. A write affects both the pixel pattern for the current line and the start of the sprite's vertical extent. |
| `ENAM0/1` `ENABL` ($1D–$1F) | Bit 1 (value 2) enables the missile/ball for the current scanline. |
| `HMP0/1` `HMM0/1` `HMBL` ($20–$24) | Fine motion, **high nibble** = signed offset −8..+7 (two's complement). Applied by `HMOVE`. |
| `VDELP0/1` `VDELBL` ($25–$27) | Bit 0: delay that object's graphic output by one scanline (flicker and trick kernels). |
| `RESMP0/1` ($28/$29) | Bit 1 (value 2) = lock the missile to the center of its player, suppressing independent missile graphics until cleared. |
| `HMOVE` ($2A) | **Strobe.** Applies all five HM registers. Must occur within horizontal blank for clean behavior. |
| `HMCLR` ($2B) | **Strobe.** Zeroes all five HM registers. |
| `CXCLR` ($2C) | **Strobe.** Clears all collision latches. |

### NUSIZ bits 0–2 — player appearance

| Value | Copies | Spacing / other |
| --- | --- | --- |
| 0 | one | — |
| 1 | two | close (16 color clocks) |
| 2 | two | medium (32) |
| 3 | three | close |
| 4 | two | wide (64) |
| 5 | one | player drawn **double width** |
| 6 | three | medium |
| 7 | one | player drawn **quad width** |

### Missile width (NUSIZ bits 4–5) and ball size (CTRLPF bits 4–5)

`00` = 1 pixel · `01` = 2 px · `10` = 4 px · `11` = 8 px.

## Read registers

| Address | Read meaning |
| --- | --- |
| `$00–$07` | Collision latches (`CXM0P`…`CXPPMM`). Only bits 7 and 6 are defined; each names two object pairs (e.g. `CXP0FB` bit 7 = P0 hit playfield, bit 6 = P0 hit ball). |
| `$08–$0B` | Paddle inputs `INPT0–INPT3` (RC-timing outputs controlled via VBLANK bits 6–7) |
| `$0C` `$0D` | `INPT4/5` fire buttons — **bit 7: 0 = pressed**, 1 = not pressed (active low) |

Collision latches stay set until cleared with `CXCLR` — clear them once per frame at a
known point, or collisions "stick" for the rest of the game.

## Priority: what covers what

Objects on the same pixel do not blend — the higher-priority object's color simply wins.
There are four priority levels; each level groups objects that share a color register:

| Priority (default, `PFP=0`) | Objects |
| --- | --- |
| 1 (highest) | Player 0 & Missile 0 (`COLUP0`) |
| 2 | Player 1 & Missile 1 (`COLUP1`) |
| 3 | Playfield & Ball (`COLUPF`) |
| 4 (lowest) | Background (`COLUBK`) |

With `PFP=1` (CTRLPF bit 2), the Playfield & Ball level moves to the top:
playfield+ball > P0/M0 > P1/M1 > background. With `SCORE=1` (CTRLPF bit 1), the playfield
itself splits: its left half uses `COLUP0`, its right half uses `COLUP1` — the classic
six-digit scoreboard trick.

## RIOT (6532): RAM, ports, timer

| Item | Address | Notes |
| --- | --- | --- |
| RAM | `$80–$FF` | The only 128 bytes of writable memory |
| `SWCHA` | `$0280` | Joysticks. **0 = pressed.** P0: bit 4 right, 5 left, 6 down, 7 up; P1: bits 0–3 in the same order |
| `SWACNT` | `$0281` | Port A direction register — normally `$00` (all input) |
| `SWCHB` | `$0282` | Console switches. `0 = pressed` for RESET (bit 0) and SELECT (bit 1); bit 3 = 1 color / 0 B&W; bits 6–7 = P0/P1 difficulty (0 = expert/A, 1 = novice/B) |
| `SWBCNT` | `$0283` | Port B direction register — normally `$00` |
| `INTIM` | `$0284` | Current timer value; counts down to 0 |
| `INSTAT` | `$0285` | Bit 7 = 1 once the timer has underflowed |
| `TIM1T/8T/64T/1024T` | `$0294–$0297` | **Write = start the timer** with that prescaler (ticks of 1, 8, 64, 1024 CPU cycles) |

Standard timing recipe (as in `include/macro.asm`): write `TIM64T` and busy-wait on `INTIM`
reaching 0. Use **44** for a 37-line VBLANK or **36** for a 30-line overscan: the first tick
lands one cycle after the write, so `t` ticks cover `1 + (t−1) × 64` cycles. The classic
`43`/`35` run one tick short (36/29 lines — a 260-line frame; Lesson 15 derives the whole
arithmetic).

The timer keeps counting after reaching 0 and wraps through `$00→$FF` after 255 further
ticks, so re-check or re-arm for long waits. Short waits (< 255 ticks) can simply poll
`INTIM`.

## Sources

See `sources.md`. Register semantics follow the Stella Programmer's Guide and
problemkaputt.de's VCS specification; the playfield bit order is confirmed by both.
