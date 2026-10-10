# Legendary Techniques — Reference

These are the historically documented tricks behind the course's Part 11 (and a few famous
effects elsewhere). Each entry explains the *idea* and where its precise mechanism is
documented or must be verified. **Do not present an exact register sequence for these until
it has been validated in Stella** — the point of these lessons is the experiment, not a
copy-paste recipe.

## The HMOVE comb / repeated HMOVE strokes

- Repeated `HMOVE` strokes **re-apply the same motion** without rewriting the HM registers
  (verified: problemkaputt.de). This is a raw mechanism behind several strobing tricks.
- HMOVE executed in HBLANK blanks the **leftmost 8 pixels** of the next line; HMOVE outside
  HBLANK produces extra shifts ("the comb") — artifacts that some games deliberately used as
  visual effects.

## Cosmic Ark starfield (Imagic, Rob Fulop)

- Purpose: a full-screen starfield from almost no ROM while the CPU is busy running the game.
- Historically documented as **a bug exploitation in the TIA's sprite positioning**: the stars
  are sprite images scattered by an undocumented side effect, not stored data.
- Where the real mechanism lives: the book *Racing the Beam* (chapter on Cosmic Ark), AtariAge
  analyses, and the emulator community's TIA notes. The lesson should reproduce a convincing
  starfield (e.g. repeated HMOVE strobes and/or one-dot-per-line repositioning) and verify it
  in Stella, documenting the effect achieved rather than claiming bit-exactness with the
  original.

## Skipdraw (the classic sprite-kernel idiom)

- Purpose: draw a sprite in a **single-line kernel without branches**, by *skipping* the
  graphic stores on lines above the sprite.
- Idea: compare the scanline counter against the sprite's Y position so that the **carry**
  reflects "not yet on screen", then use carry arithmetic (`SBC`/`AND` mask patterns) to
  neutralize the `STA GRP0` on skipped lines. No compare-and-branch, so the cycle count stays
  constant for every line.
- Documented in 8bitworkshop's VCS material and AtariAge kernel discussions; the lesson should
  build it from a working 1-line kernel and count cycles in Stella.

## Pseudo-3D road (Enduro, Pole Position)

- Purpose: a road rushing toward the horizon with a believable curve.
- Idea: **per-scanline control** — each line's playfield width/colors draw the road strip
  (wider near the bottom = closer), and a small **curve table** shifts the road's center left
  or right per line, scrolling over time. The "3D" is 192 hand-tuned bands, not geometry.
- Verify by building a static road first (fixed table), then scrolling/curving it.

## Procedural worlds from a seed (Pitfall!, River Raid)

- Purpose: a huge-feeling world from a handful of bytes.
- Idea: a **linear-feedback shift register (LFSR)** generates the world deterministically from
  a seed; the same generator run forward builds the world ahead, and the reverse map/scan
  rebuilds it behind. River Raid's river sections and Pitfall!'s jungle layout are famously
  regenerated rather than stored.
- The lesson should implement an LFSR, prove determinism, then feed its bits into obstacle
  placement.

## Interlaced flicker (faking more colors/resolution)

- Purpose: more apparent colors or detail than 60 Hz drawing allows.
- Idea: display **two different 30 Hz frames** whose differences the eye merges — e.g.
  alternating colors at the same position to mix them, or alternate scanline halves to fake
  doubled vertical resolution. Requires exact frame alternation and care with VBLANK timing.
- Distinguish it from plain object flicker: interlacing alternates *whole pictures*.

## Adventure room & object engine (Warren Robinett)

- Purpose: a playable action-adventure in 4K.
- Idea: **data-driven rooms** — each room is an entry (boundaries, exits, objects) pointing at
  object records (position, graphic, behavior flag); the engine interprets the tables instead
  of storing per-room code. The first "video game easter egg" lives in this engine's data.
- The lesson reconstructs a minimal room/object interpreter and shows why data-driven design
  saves both ROM and logic.

## Related famous work worth mentioning in lessons

- **DPC music (Pitfall II)** — the DPC chip's three extra oscillators gave music while the CPU
  drew the game. Modern homebrew uses DPC+ (ARM coprocessor) for the same reason.
- **Venetian blinds / score tricks** — see `sprite-tricks.md` for the mechanics behind the
  six-digit score.
- **Batari BASIC's kernel generation** — the course's `part9-dsl-path` analyzes how a BASIC
  compiler emits these same kernel patterns automatically.

## Sources

`Racing the Beam` (Bogost & Montfort); AtariAge 2600 programming threads; 8bitworkshop VCS
docs; see `sources.md`. Each Part 11 lesson must cite its own primary source and record what
was verified in Stella versus what is historical description.
