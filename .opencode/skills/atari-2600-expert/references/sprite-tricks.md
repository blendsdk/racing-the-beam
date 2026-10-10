# Sprite & Playfield Tricks — Reference

## Positioning objects horizontally: the dance

The TIA gives you two tools for horizontal placement:

1. **`RESxx` (coarse)** — a strobe that sets the object's position to where the beam is. You
   control *when* you strobe by counting cycles after `WSYNC`.
2. **`HMPx`/`HMMx`/`HMBL` + `HMOVE` (fine)** — a signed −8..+7 color-clock adjustment applied
   during HBLANK.

The two are used together, because `RESxx` alone lands on 3-color-clock boundaries with a few
clocks of output delay, while fine motion resolves the remainder.

### The classic SetHorizPos routine

```asm
; Move player 0 to horizontal position A (0-159).
; Side effects: uses A, burns about two scanlines. X and Y are preserved.
SetHorizPos:
    STA WSYNC           ; start this on a fresh scanline
    SEC
.div15
    SBC #15             ; each loop ≈ 5 CPU cycles ≈ 15 color clocks of beam travel
    BCS .div15          ; loop until the remaining distance underflows
    EOR #7              ; convert the overshoot into a signed fine-motion value
    ASL                 ; shift it into the high nibble HM expects
    ASL
    ASL
    ASL
    STA HMP0            ; fine motion
    STA RESP0           ; coarse position at the current beam position
    STA WSYNC           ; wait to the next line
    STA HMOVE           ; apply the fine motion inside HBLANK
    RTS
```

Call it in VBLANK or between objects, not in the middle of a tight kernel line — it costs
about two lines. The routine's constants assume the standard output delays; if your object
lands a pixel or two off, adjust the `EOR`/shift constants and confirm in Stella.

### Fine motion values

| Needs | HMP value (high nibble) |
| --- | --- |
| Move right 1..8 clocks | `$F0`(−1) … `$80`(−8) — two's complement of the amount |
| No move | `$00` |
| Move left 1..7 clocks | `$10`(+1) … `$70`(+7) |

Remember: negative moves **right**, positive moves **left** — the sign catches everyone once.

### The HMOVE line's left-edge mask

An `HMOVE` strobed in HBLANK blanks the leftmost 8 pixels of the next scanline. If that
matters (e.g. a sprite touching the left edge), either avoid HMOVE that line (`HMCLR` and
skip) or accept/embrace the mask as Hero did (HMOVE every line for uniformity).

## Getting more from two players

| Trick | Mechanism |
| --- | --- |
| **Copies** | `NUSIZ` bits 0–2 give 2–3 copies at close/medium/wide spacing — instant "rows" of identical objects |
| **Double/quad width** | `NUSIZ` values 5/7 widen the player to 16/32 pixels for chunky objects |
| **Repositioning** | reuse one player several times per frame at different Y (see `kernels.md`) |
| **Flicker** | alternate two 30 Hz frames to fake 2× objects |
| **Reflect** | `REFP0/1` value 8 mirrors a sprite — free extra pose |

## Multicolor sprites

The TIA gives **one color per player per line**. To show two colors in one sprite:

- **Per-scanline color switching** — change `COLUP0` between the sprite's scanlines; classic
  for hair/feet bands.
- **Overlap two players** — two copies of the shape at the same position, different colors,
  shown on alternating frames (flicker) or with priority toggled per line.
- **Hybrid shapes** — player pixels + missile/ball pixels of another color as accents.

Every "multicolor sprite" on the 2600 is one of these three illusions.

## Playfield tricks

| Trick | Mechanism |
| --- | --- |
| **Mirror vs repeat** | `CTRLPF` bit 0: reflect (right half mirrors) or repeat (same 20 bits) |
| **Asymmetric playfield** | rewrite `PF0/1/2` mid-line after the left half is drawn |
| **Score mode** | `CTRLPF` bit 1: left half uses P0's color, right half P1's — a 6-digit score in one line |
| **Playfield priority** | `CTRLPF` bit 2: playfield+ball in front of sprites (mazes, tunnels) |
| **Vertical bars/colors** | change `COLUPF` per scanline; 4-clock chunks are the playfield's real texture |
| **Ball as a thin line** | `ENABL` + `CTRLPF` ball size; perfect for lasers, goal posts, paddles |

## VDEL: deferred graphics writes

`VDELP0`/`VDELP1`/`VDELBL` delay an object's graphic by one scanline. Two uses:

1. **Flicker without tearing** — write the next frame's shape to the register while the old one
   is still being displayed.
2. **Mid-line asymmetry** — coordinate two players so their writes do not collide (the classic
   "VDEL trick" for drawing different left/right sprite data on one line).

## Missiles and ball

- Both are **1–8 pixel-wide** objects (size in NUSIZ/CTRLPF bits 4–5).
- Missiles share their player's color; the ball shares the playfield's color.
- `RESMP0` value 2 hides a missile and locks it to its player's center — great for "bullet at
  the gun's muzzle".
- The ball at 1 pixel is the classic **bullet/line**; at 8 pixels, a **block**.
- Missile + player same color = "widened sprite" tricks (e.g. make a 10-pixel-wide object).

## Composition checklists

When a lesson needs a specific visual, check every possibility before writing clever code:

1. Can it be done with **playfield only**? (4-clock granularity is often fine for backgrounds.)
2. Can one **player + copies** do it?
3. Do **missile/ball** give the last pixels (bullets, eyes, gaps)?
4. Only then: repositioning, flicker, or VDEL tricks.

The simplest technique that draws the intended picture is the correct one.

## Sources

See `sources.md` (Stella Programmer's Guide; "How to Draw a Playfield"; the newbies
tutorial's SetHorizPos session; 8bitworkshop VCS section).
