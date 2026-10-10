# Classic Pitfalls — Symptom → Cause → Fix

Every entry here is a mistake that actually happens in 2600 development, ordered by how often
it burns beginners. When a lesson or review hits one of these symptoms, check the matching row
first.

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Black screen / nothing syncs | No `VSYNC` pulse, missing vectors, or VBLANK never released | Check `$FFFA` vectors point at `Reset`; verify `+vsync` runs and `VBLANK` bit 1 clears before the kernel |
| Picture slowly rolls / tears | Kernel exceeds 76 cycles on some line, or wrong frame length (PAL/NTSC) | Count cycles per line; check timer values; confirm 262-line NTSC structure |
| Image is stable but shifted or doubled in places | HMOVE strobing outside HBLANK, or motion registers rewritten within 24 cycles of HMOVE | Move HMOVE directly after `WSYNC`; separate register updates from the strobe |
| Combs / vertical bars on sprites | HMOVE comb: HMOVE runs outside HBLANK | Same fix; also check `HMOVE` is not inside a kernel line |
| Leftmost 8 pixels of scattered lines are black | HMOVE-in-HBLANK's left-edge mask | Expected behavior; either accept it (uniform HMOVE every line) or skip HMOVE on lines that must be clean |
| Sprite appears a few pixels right of target | RESP output delay was not accounted for | Use the SetHorizPos routine; tune the fine-motion constant and verify in Stella |
| Sprite at the wrong position after moving | Forgot that the HMP high nibble is signed — negative moves right, positive moves left | Convert desired direction to a signed nibble (`$F0 = −1` … `$70 = +7`) |
| Score/playfield mirrored wrong, bits "reversed" | `PF2` bit order is reversed (bit 0 is leftmost) and `PF0` uses bits 4–7 only | Compare against `tia-hardware.md`; in REF mode the right half draws `PF2` first |
| Wrong colors everywhere | Color format mistaken (`%HHHHLLL0`) or NTSC/PAL palette assumed | Use `hue<<4 | luminance<<1`; expect PAL 104 vs NTSC 128 |
| Colors stuck / collisions never re-trigger | Collision latches never cleared | `CXCLR` once per frame at a known point |
| Fire button reads "pressed" constantly | Active-low bit: `INPT4/5` bit 7 = 0 means pressed | Test bit 7 explicitly; do not test "nonzero = pressed" |
| Inputs used as outputs / weird game behavior | Forgot `SWACNT`/`SWBCNT` direction registers or their zero-is-input convention | Leave both at `$00` unless the game deliberately drives a pin |
| Timer wait hangs or fires early | Timer wrapped past 0 (255+ ticks) while waiting, or wrong prescaler | Re-check `INSTAT` bit 7 for long waits; keep waits inside one 255-tick window |
| RAM variables overwritten mysteriously | Stack (page `$01`, mirroring `$80–$FF`) grew into variables | Keep call depth shallow; reserve a top-of-RAM area; audit `PHA`/`JSR` balance |
| Writing to `$00–$7F` does "nothing" or breaks graphics | Those addresses are TIA, not RAM | Variables live at `$80–$FF` only |
| BNE never exits / loop runs once | Wrong flag assumed; `DEX`/`BNE` check `Z`, not `X == 0` | Use the flag the instruction actually sets; remember `INX`/`DEX` set `N`/`Z` |
| Branch out of range | Conditional branches reach ±127 bytes only | Restructure with a nearby trampoline `JMP`, or invert the condition and jump away |
| `LDA` loads garbage | Missing `#` (address vs literal) | `LDA #$42` for the value; `LDA $42` reads memory |
| ACME refuses syntax copied from DASM | DASM-era directives (`processor 6502`, `include`, `org`) | Use ACME forms: `!cpu 6502`, `!source`, `* = $F000` |
| ROM builds but is too small / emulator rejects it | File not exactly 2K/4K (or scheme size) or vectors missing | Pad to the scheme size (`!fill`); place `!word` vectors at `$FFFA–$FFFF` |
| Everything works in the debugger but the visible picture is one line off | Writing a graphic register mid-line vs at line start | Write registers right after `WSYNC`; if tearing appears, stage values in RAM and write during blank |

## Review habit

When reviewing a lesson's ROM, run this list against the code **before** looking at the screen.
Half of all 2600 bugs announce themselves as one of the rows above.
