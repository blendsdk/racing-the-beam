---
name: VCS Lesson Production
description: The Racing the Beam per-lesson production workflow — preflight checklist, assembly, Stella screenshots, committed ROMs with embedded player, VitePress/sidebar/index updates, and README sync, with the exact commands for this repository. Use when authoring, updating, or reviewing any lesson in this course.
---

# VCS Lesson Production

Every lesson in this course ships **seven artifacts**, built in one pass. This skill is the
procedure; `atari-2600-expert` is the domain knowledge. Load both when building a lesson.

## The five hard rules (from the course's governing rules)

A lesson is **not complete** until all five pass. They are hard stops, not guidelines.

1. **VitePress rework** — sidebar entry, cross-references, `npm run docs:build`, assets, and
   previous/next navigation all work; the part index page no longer says "Coming Soon" for it.
2. **Stella screenshots** — every lesson with visual output shows real Stella captures; theory
   lessons ship a small standalone `demo-NN.asm` ROM that visualizes the concept.
3. **Preflight** — the lesson's concepts are fully covered by earlier lessons, the technical
   claims are correct for 6502/TIA/RIOT, and the plan for screenshots/demo ROMs is explicit.
   Gaps are a hard stop: stop and discuss before writing content.
4. **README sync** — if the curriculum listing changes at all (lesson added/renamed, count
   changed), `README.md` is updated **in the same commit**.
5. **ROM + player** — every buildable lesson assembles via `npm run roms`, the `.bin` is
   committed under `docs/public/roms/…`, and `<RomPlayer>` is embedded under the screenshot.

## The per-lesson cycle

```
0. PREFLIGHT        run the preflight checklist (references/checklists.md);
                    on any gap: STOP and raise it — do not patch around it
1. IMPLEMENT        lessons/…/NN-slug/NN-slug.asm  +  docs/…/NN-slug.md
                    (exercise solutions as exercise-NN-solution.asm when the
                     lesson has exercises — this is the established pattern)
2. VERIFY CODE      assemble the lesson ROM; run it in Stella; check the screen
3. SCREENSHOTS      capture with scripts/capture-screenshot.sh → docs/public/images/lessonNN/
4. ROMS             npm run roms  → commit the .bin files
5. VITEPRESS        sidebar (only if a nav entry changed), part index, prev/next links,
                    RomPlayer embed, npm run docs:build
6. README           sync the curriculum table / lesson count when they changed
7. VERIFY + COMMIT  bash scripts/verify.sh  → single atomic commit
                   feat(lessonNN): <title>
```

Steps 1–6 belong to one commit. Do not commit a lesson without its ROM, screenshot, and site
integration.

## File layout (established convention)

| Artifact | Path |
| --- | --- |
| Lesson source | `lessons/partN-topic/NN-slug/NN-slug.asm` |
| Exercise solutions | `lessons/partN-topic/NN-slug/exercise-NN-solution.asm` |
| Theory demo ROM | `lessons/partN-topic/NN-slug/demo-NN.asm` |
| Lesson document | `docs/partN-topic/NN-slug.md` |
| Screenshots | `docs/public/images/lessonNN/description.png` |
| Built ROMs | `docs/public/roms/partN-topic/NN-slug/*.bin` (committed) |
| VitePress sidebar | `docs/.vitepress/config.ts` |
| Part index | `docs/partN-topic/index.md` |

## Commands (this repository)

```bash
# assemble everything and verify committed ROMs match sources + docs build
bash scripts/verify.sh

# assemble all lesson ROMs into docs/public/roms/ (then commit the .bin files)
npm run roms

# one lesson directly (example)
acme -f plain -o build/lessonNN.bin lessons/partN-topic/NN-slug/NN-slug.asm
stella build/lessonNN.bin

# screenshot (works on a desktop display or headless via xvfb-run)
# capture from the COMMITTED ROM path so the window title shows the real ROM name
bash scripts/capture-screenshot.sh docs/public/roms/partN-topic/NN-slug/NN-slug.bin docs/public/images/lessonNN/description.png
```

`scripts/verify.sh` is the gate: it must pass before the lesson commit.

Screenshot pitfalls (committed-ROM provenance, pointer parking, moving-state burst captures)
live in [references/checklists.md](references/checklists.md) under **Screenshots**.

## Lesson document template

The document structure is fixed by the six finished lessons. Read
[references/lesson-template.md](references/lesson-template.md) before writing prose — it
defines every section (frontmatter, meta block, TypeScript equivalents, theory, code
walkthrough, screenshots + RomPlayer, exercises with solutions, takeaways, what's next).

## Checklist

[references/checklists.md](references/checklists.md) holds the actionable per-rule checklists
(preflight, screenshots, ROM/player, VitePress, README). Walk it top to bottom before asking
for review, and paste the result into the plan/task record when executing under CodeOps.

## Review expectations

- A reviewer will re-run `scripts/verify.sh`, re-assemble the lesson, and check the technical
  claims against `atari-2600-expert` references.
- Every screenshot is checked against the lesson's stated output.
- Exercise solutions must assemble, run, and actually solve the exercise as written.
- Common failure modes live in `atari-2600-expert` → `references/pitfalls.md`.
