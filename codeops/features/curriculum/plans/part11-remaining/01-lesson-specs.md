# Lessons 73–78 — Lesson Specifications

> **Status**: Adopted. Each section is the design contract for one lesson. The author may
> adjust an arithmetic detail only with a recorded reason and re-measured evidence.

Shared frame: NTSC 262 lines = 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan. Every main
ROM auto-demos (no input needed for the captures); SELECT toggles the second visual state.

## Lesson 73 — The HMOVE Comb & the Cosmic Ark Starfield

**Artifact**: a 192-line starfield over a planet limb, with a small ship. Sparse single-pixel
stars come from one missile in three-copy mode plus the ball; the sky cycles through four blues.

**Mechanism**: the HMOVE walk. Missile 0 and the ball are positioned **once**; every visible
line writes `HMM0`/`HMBL` from a 160-entry motion table and strobes `HMOVE`, so each object's X
is the accumulated signed motion (positive moves left). The 8-pixel HMOVE blanking bar is the
border-colour notch on every star line in both states. A second `HMOVE` in the visible line is
the comb/visible-line experiment: it stalls (plugs) the not-yet-drawn pixels rightward by a
bounded, line-dependent amount; it does not re-apply a 4-px left motion. The mask scrolls every
8 frames. SELECT or the one-shot auto-demo at frame 240 adds the second strobe. The lesson
reproduces the documented repeated-HMOVE look without claiming bit-exact Cosmic Ark.

**Frame**: 37 VBLANK; 160 star lines + 32 planet lines = 192; 30 overscan; 262. The planet limb
is 16 rows x 2 lines, continuous from a 4-px cap to the full width (rows 12-15 use PF1=$FF plus
PF0=$80/$C0/$E0/$F0; half-widths 68/72/76/80), with the ship on rows 10-13.

**Captures**: `starfield.png` (single-strobe walk; the bar is present) and `comb.png` (the
second visible-line strobe; the field shifts right, the bar is still present). The auto-demo
switches at frame 240; captures at 2 s and 5 s.

**Exercises**: (1) a 73-star mask with five 32-line colour bands; (2) a 2-frame scroll plus a
16-frame twinkle. Both keep the walk and the single strobe.

> **Amended 2026-11-08** after the mechanism probe and the first review: the original spec used
> per-line `RESM0`/`RESBL` positioning, which does not demonstrate the repeated-HMOVE scatter;
> the delivered walk does. The second strobe is a visible-line stall, not a 4-px left
> re-application. The bar is inherent to the walk and is present in both captures.

## Lesson 74 — Skipdraw — The Classic Sprite Kernel Idiom

**Artifact**: a vertical "rocket" scene: P0 is an 8x16 rocket at `RocketY`, M0 is its 2x8
exhaust; the playfield is a ground band and a star band. The rocket rises and falls on a table.

**Mechanism**: one-line kernel. P0 uses the skipdraw pattern (`LDY #0; TXA; SEC; SBC RocketY;
CMP #16; BCS skip; TAY; LDA RocketGfx,Y; TAY; skip: STY GRP0`): one branch, one unconditional
store, constant cycles on both paths (pad the taken path). M0 uses the branchless carry idiom
(`TXA; SEC; SBC ExhaustY; CMP #8; ROL; ROL; EOR #2; STA ENAM0`). The lesson counts both paths
in Stella and explains why the store stays unconditional.

**Frame**: 37 VBLANK; 192 visible (24-line status/star band, 144-line flight region, 24-line
ground); 30 overscan.

**Captures**: `rocket-low.png` and `rocket-high.png` (two auto-demo heights; the exhaust and
the ground prove the skipdraw rows are clipped correctly).

**Exercises**: (1) add P1 as a second skipdraw sprite; (2) replace P0's skip branch with the
fully branchless carry form (or add a second missile).

## Lesson 75 — Pseudo-3D Road — The Enduro / Pole Position Effect

**Artifact**: a road rushing to a horizon: 96 rows x 2 lines; sky in the top rows, road in the
bottom rows, a dashed centre line, shoulders, and a curve.

**Mechanism**: per-row road width and centre from two small tables (width 56 entries, curve
32 entries); the playfield is written twice per row (left half, then right half after the
left half has been latched) so the road can be asymmetric; colour bands separate sky, grass,
shoulder, and road. A scroll phase advances the centre-line dashes and the curve table.

**Frame**: 37 VBLANK; 192 visible (40 rows sky, 56 rows road); 30 overscan.

**Captures**: `straight.png` and `curve.png` (auto-demo straight then curve; the road edges and
the dashed centre line are visible in both).

**Exercises**: (1) recolour the road and shoulders; (2) add a second curve phase (left/right).

## Lesson 76 — Procedural Worlds from a Seed — Pitfall! & River Raid

**Artifact**: a top-down 16-row world scrolling upward: each row is 8 lines tall and 160 px
wide (20 playfield bits); tiles are jungle, water, wall, and empty. A player sprite sits near
the bottom and moves left/right.

**Mechanism**: an 8-bit Galois LFSR (taps `$B8`) steps once per generated tile; 2 bits select
the tile type, and the same seed always rebuilds the same 16-row ring. SELECT changes the seed;
the auto-demo scrolls the ring. The doc proves determinism by replaying a seed and comparing
the row bytes, and explains why the generator is smaller than the world it describes.

**Frame**: 37 VBLANK; 192 visible (16 rows x 8 lines = 128 lines, 24-line status band with the
seed bits, 24-line lower band; adjust the split to 128 + 32 + 32 if cleaner); 30 overscan.

**Captures**: `world-seed-a.png` and `world-seed-b.png` (two seeds produce visibly different
worlds).

**Exercises**: (1) change the tile palette and density; (2) add the reverse LFSR step so the
world can be rebuilt behind the player (stretch).

## Lesson 77 — Interlaced Flicker — Faking More Colours & Resolution

**Artifact**: an eight-band colour mosaic: each 24-line band alternates between two TIA
colours on successive frames, so the eye sees eight blended colours from one colour register.

**Mechanism**: a frame counter toggles `Phase`; the band table is indexed `Phase*8 + Band`;
the frame is otherwise identical, so the alternation is exact. SELECT freezes the phase; the
auto-demo freezes on phase A and then phase B for the captures. The lesson distinguishes
whole-frame interlacing from object flicker and explains why a static screenshot shows one
phase only.

**Frame**: 37 VBLANK; 192 visible (8 bands x 24 lines); 30 overscan.

**Captures**: `phase-a.png` and `phase-b.png` (the same bands in the two colour phases).

**Exercises**: (1) reverse the phase order and add a third palette pair; (2) field-interlace a
96-line bitmap to fake doubled vertical resolution (stretch).

## Lesson 78 — Room & Object Engine — The Adventure Architecture

**Artifact**: a four-room adventure: a player (P0), a key (P1), a door, and walls drawn by the
playfield. The player walks between rooms through exits; the key follows once picked up; the
door is the exit object.

**Mechanism**: a room table (walls, exits, first object index) and an object table (x, y,
graphic, colour, behaviour flag); the engine reads the tables and draws the room; object
behaviour is a flag the engine interprets, not per-room code. The doc explains why the data
tables save ROM and logic.

**Frame**: 37 VBLANK; 192 visible (24-line status/room band, 144-line room, 24-line lower
band); 30 overscan.

**Captures**: `room-1.png` (start room, key visible) and `room-2.png` (after the exit; the key
is carried or the second room's object is visible).

**Exercises**: (1) add a fifth room and a second exit; (2) add a behaviour flag (key opens the
door) and a third object (stretch).

## Common deliverables

| Artifact | Path |
|---|---|
| Main source | `lessons/part11-legendary/NN-slug/NN-slug.asm` |
| Exercise solutions | `lessons/part11-legendary/NN-slug/exercise-01-solution.asm`, `exercise-02-solution.asm` |
| Document | `docs/part11-legendary/NN-slug.md` |
| Captures | `docs/public/images/lessonNN/<name>.png` (two per lesson) |
| ROMs | `docs/public/roms/part11-legendary/NN-slug/*.bin` (three per lesson) |

Every document follows the course template: frontmatter, meta block, TypeScript equivalent,
theory, build/full source/walkthrough, what-you-see with both captures and one `<RomPlayer>`
for the main ROM, two exercises with solution references, 5–7 takeaways, and a what's-next
link. The Full Source block is the main source verbatim.
