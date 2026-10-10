# Lesson Checklists

Walk these top to bottom. Any unchecked "hard stop" item means the lesson is not complete.

## Preflight (Rule 3) — before writing any content

- [ ] The lesson's concepts are fully covered by earlier lessons (no forward references)
- [ ] The lesson does not duplicate another lesson's content
- [ ] Learning objectives are concrete: what can the reader do/see afterwards?
- [ ] Every technical claim is correct for 6502/6507, TIA, and RIOT
      (check against `atari-2600-expert` references; verify timing claims in Stella when unsure)
- [ ] Register addresses and bit layouts match `include/vcs.asm`
- [ ] The code plan actually assembles in ACME (no DASM-era syntax)
- [ ] Screenshot plan: which screenshots, from which ROM, showing what
- [ ] Demo-ROM plan if the lesson is conceptual: `demo-NN.asm` defined
- [ ] Naming/style follows the two nearest completed lessons

**Outcome:** all clear → proceed. Any gap → **hard stop**: raise it before writing content.

## Implementation

- [ ] `lessons/partX-topic/NN-slug/NN-slug.asm` assembles cleanly
- [ ] The ROM actually shows what the lesson claims (checked in Stella, not just by reading)
- [ ] Exercise solutions exist, assemble, and verify the exercises as written
- [ ] `docs/partX-topic/NN-slug.md` follows `references/lesson-template.md`
- [ ] No forward references; TypeScript-equivalence blocks present where they help

## Screenshots (Rule 2)

- [ ] Captured from the **committed ROM path** (`docs/public/roms/…/`), never a scratch or
      renamed copy — the window title bar is part of the published image and must read the real
      ROM name (`Stella 7.0: "NN-slug"`)
- [ ] Pointer parked away from the window before capture (`xdotool mousemove 0 0`) — no cursor
      or hover artifact in the image
- [ ] Captured with `scripts/capture-screenshot.sh`
- [ ] Saved as `docs/public/images/lessonNN/description.png` (PNG, reasonable size)
- [ ] The image matches the "What You Should See" text exactly — pixel-check the state (band
      counts, positions, colours), not just a glance
- [ ] Paired screenshots (before/after, two states) verified to actually differ
- [ ] Alt text describes what the reader sees; the caption connects it to the lesson
- [ ] Stella UI chrome does not obscure the picture (crop if needed)

**Moving states (walking bands, scrolling waves, animations):** `capture-screenshot.sh` takes a
single capture after a fixed wait, so it cannot be aimed at a specific animation state by
waiting longer or shorter. For time-dependent screens, launch Stella on the committed ROM
yourself, take a burst of captures with the script's own window lookup
(`xwininfo -root -tree | grep -i stella`), and select the frames you need by pixel analysis
(which band is bright, which wave offset is shown). Never fake a state with a modified ROM.

## ROMs + player (Rule 5)

- [ ] `npm run roms` ran and the `.bin` files are committed under `docs/public/roms/…`
- [ ] `<RomPlayer rom="/roms/partX-topic/NN-slug/NN-slug.bin" title="…" />` embedded beneath
      the relevant screenshot
- [ ] Download link (provided by RomPlayer) resolves under the site base path
- [ ] `bash scripts/verify.sh` passes (no ROM drift)

## VitePress rework (Rule 1)

- [ ] Lesson renders with the right title in the sidebar (`docs/.vitepress/config.ts`)
- [ ] Prev/next frontmatter links work both ways (the next lesson's prev points back)
- [ ] Part index page updated: this lesson no longer "Coming Soon"
- [ ] Images and the RomPlayer load; no broken links to/from other lessons
- [ ] `npm run docs:build` succeeds

## README sync (Rule 4) — only when the curriculum listing changed

- [ ] "The Curriculum" table matches parts/topics/lesson ranges
- [ ] Total lesson count in the README tagline matches the site
- [ ] Part names and order match the VitePress sidebar

## Commit

- [ ] `bash scripts/verify.sh` passes
- [ ] Single atomic commit: source + doc + solutions + screenshots + ROMs + site updates
- [ ] Message: `feat(lessonNN): <Lesson title>`
      (fixes: `fix(lessonNN): …`; site/tooling: `chore(vitepress): …` / `chore(ci): …`)
