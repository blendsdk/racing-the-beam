# Timing & the NTSC/PAL Frame — Reference

Numbers in this file are verified against problemkaputt.de's VCS specification (see
`sources.md`). Where they matter to a lesson, re-verify in the Stella debugger.

## Clocks

| Clock | NTSC | PAL |
| --- | --- | --- |
| Color clock (one pixel) | 3.579545 MHz | 3.546894 MHz |
| CPU "machine clock" | 1.193182 MHz | 1.182298 MHz |

**One CPU cycle = 3 color clocks. One scanline = 228 color clocks = 76 CPU cycles.**

## Horizontal timing

| Phase | Color clocks | CPU cycles |
| --- | --- | --- |
| Horizontal blank (HBLANK) | 68 | 22.7 |
| Visible picture | 160 | 53.3 |
| **Total scanline** | **228** | **76.0** |

- Horizontal sync/blanking is automatic in hardware. **`WSYNC` re-synchronizes you**: the CPU
  pauses inside the write until HBLANK, then resumes at the start of the next scanline.
  `STA WSYNC` costs 3 cycles and gives you a fresh line with a full 76-cycle budget.
- Every write to a TIA register lands at a specific color clock. In the visible area you have
  only **53.3 CPU cycles** to do your per-line work; the rest is blanking.

## Vertical frame structure (the canonical split)

| Phase | NTSC lines | PAL lines |
| --- | --- | --- |
| VSYNC | 3 | 3 |
| VBLANK (upper border) | 37 | 45 |
| Visible picture | 192 | 228 |
| Overscan (lower border) | 30 | 36 |
| **Frame total** | **262** | **312** |
| Frame rate | ~60 Hz | ~50 Hz |

- **VSYNC must be exactly 3 lines.** Two or four lines can make real TVs lose color.
- Many PAL games draw only 192 picture lines and pad the borders (45+18 / 36+18) instead of
  using all 228 — less work, same compatibility. This is why NTSC-targeted ROMs "roll" on PAL
  hardware: different totals.
- VBLANK and overscan are where game logic runs: read controllers, move objects, compute.
  The RIOT timer (`TIM64T`, values ~43 and ~35) measures these periods while you work.

## The CPU's view of a frame

```
+vsync          ; 3 lines: VSYNC on, 3x STA WSYNC, VSYNC off
VBLANK period   ; 37 lines: set VBLANK, timer, do logic, wait for timer
kernel          ; 192 lines: draw the picture, one WSYNC per line (or per 2 lines)
overscan        ; 30 lines: set VBLANK, timer, more logic, wait
loop
```

The timer values in `include/macro.asm` (`43` / `35`) produce roughly the right periods; the
exact line counts absorb the cost of starting the timer and waiting on it.

## Cycle budgeting

To fit a kernel into 76 cycles per line:

1. List the writes that must happen on each line and their costs (`STA WSYNC` 3, `STA zp` 3,
   `LDA #` 2, `STA abs` 4 …).
2. Sum them; if the sum exceeds 76, the line stretches and the picture tears or rolls.
3. Count **ancillary costs** too: a taken branch (+1), a page-crossing indexed load (+1),
   `JSR`/`RTS` (6 each).
4. When a full-frame main loop seems to "slowly drift" (picture rolls), you are over budget
   in the kernel or the timer periods are wrong — check both.

Kernel code is usually **unrolled** (straight-line `STA GRP0` / `STA WSYNC` pairs) precisely
so the cycles are knowable. Loops are used only where the extra branch cycles are cheap.

## HMOVE rules (the ones that bite)

- `HMOVE` applies all five motion registers: `NewPos = (OldPos ± Motion) mod 160`. In the HM
  register, the **high nibble** is signed: `-8..-1` moves right, `0` no move, `+1..+7` moves
  left (remember the sign direction when tuning).
- **Strobe it immediately after `WSYNC`** so it runs inside HBLANK. Outside HBLANK you get the
  "HMOVE comb": objects shifted by extra clocks producing combs and bars.
- **Do not rewrite motion registers for ≥24 CPU cycles after `HMOVE`.**
- Repeated `HMOVE` strokes re-apply the same motion — a mechanism behind several famous tricks.
- Executing `HMOVE` inside HBLANK also **blanks the leftmost 8 pixels of the following
  scanline** (border color). Games that need a clean left edge clear the motion registers and
  skip HMOVE on that line; games that prefer uniform masking (e.g. Hero) HMOVE every line.

## RESP positioning

- Writing `RESP0/1`, `RESM0/1`, or `RESBL` sets the object's horizontal position to "where the
  beam is" — quantized to color-clock resolution and then adjusted by a small fixed output
  delay.
- During HBLANK, a reset lands the object at the **left edge plus ~2–3 pixels** (players ≈ 3,
  missiles/ball ≈ 2 per problemkaputt; other references quote the output delay as ≈5 clocks
  for players and ≈4 for missiles when strobing mid-line).
- Because timing estimates differ by a pixel or two between references, **the working method
  is the standard SetHorizPos dance** (coarse `RESP` + fine `HMP` + `HMOVE`) with the fine
  value absorbing the error. See `sprite-tricks.md` and verify placement in Stella.

## PAL/NTSC compatibility

- The 192-line NTSC frame shown above is the course's baseline.
- A PAL release needs the 312-line split (or at least a 50 Hz-compatible frame); a
  dual-region ROM detects the TV type (commonly via frame-counting or the `SWCHB` color bit)
  and branches between two timing tables.
- Color values differ: NTSC 128 colors, PAL 104. Cross-region hue shifts are expected. This
  is covered by the course's PAL/NTSC lesson.

## Sources

problemkaputt.de VCS specification (frame table, horizontal timing, HMOVE and RESP notes);
Stella Programmer's Guide; see `sources.md` for links.
