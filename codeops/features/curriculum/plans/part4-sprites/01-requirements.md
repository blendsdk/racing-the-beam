# Requirements: Part 4 — Sprites (Lessons 25–34)

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)
> **Source**: [curriculum/RD-04](../../requirements/RD-04-part4-sprites.md) — the OWNING requirements doc

## Scope of this plan (delta view)

### In this plan

- **RD-04 AC 1** — for each of lessons 25–34: assembly source, three
  `exercise-NN-solution.asm` files, a lesson document from the fixed template, Stella screenshots,
  a committed 4,096-byte ROM with `<RomPlayer>`, and the VitePress/part-index/prev-next updates.
- **RD-04 AC 2** — `bash scripts/verify.sh` passes with all ten lessons included.
- **RD-04 AC 3** — claims follow the `atari-2600-expert` discipline; both specialists report no
  critical/major findings before a lesson is done.
- **RD-04 AC 4** — no lesson or part is added, removed, renamed, or reordered; Parts 0–3 stay as
  shipped.

### Deferred / out of this plan

- Lessons 35–78 — owned by RD-05 … RD-11; this plan ends at Part 4's last lesson.
- PAL video support — noted as an aside only, never exercised (AR-11).
- Flicker multiplexing, the 48-pixel trick, and a full game — named as later techniques only
  (AR-9, AR-18).
- Any new tooling, test framework, or generator — excluded by AR-7.

## Plan-local decisions

| Decision | Chosen | AR Ref |
| --- | --- | --- |
| Plan scope | RD-04 only; lessons 25–34 strictly sequential | AR-1 |
| Phase/session model | 10 phases, one per lesson; Sessions A/B/C; one task per lesson | AR-2 |
| Demo ROMs | None; each main ROM is directly visual | AR-3 |
| Verify command | `bash scripts/verify.sh` (detected from `AGENTS.md`; user-confirmed) | AR-4 |
| Specialist assignment | Both reviewers gate each lesson | AR-5 |
| Sprite timing evidence | State-log checkpoints + static cycle ledgers | AR-6 |
| New machinery | None — reuse the existing pipeline | AR-7 |
| Identifiers | Existing slugs and endpoints verbatim | AR-8 |
| Forward mentions | Name-only context notes; never used in code | AR-9 |
| Part index | Rebuilt to the Part 1 format in the Lesson 25 phase; rows flip per lesson | AR-10 |
| Video standard | NTSC only | AR-11 |
| Commits and records | One atomic commit per lesson (`git-commit` push mode); ledger, progress header, roadmap per lesson | AR-12 |
| Positioning | Classic divide-by-15 `SetHorizPos`; measured X is authoritative; Lesson 25 uses a fixed coarse delay before the routine is taught | AR-13 |
| Vertical rendering | Counted top/body/bottom loops; graphic write then `WSYNC` | AR-14 |
| Movement demo | Auto-bounce patrol, joystick override | AR-15 |
| Multi-color | Per-line `COLUP0` table over a 16-row shape | AR-16 |
| Copies/sizes | Eight static `NUSIZ` bands | AR-17 |
| Vertical delay | Two players, P1 one line lower via `VDELP1` | AR-18 |
| Multiple objects | One `HMOVE` per frame after all HM registers are set | AR-21 |
| Controllers | Monitor with real reads and a paddle timeout | AR-19 |
| Animation | Four 16-row frames, stepped every 8 frames | AR-20 |

## Acceptance Criteria

Plan-local criteria only (RD-04 owns the lesson acceptance criteria):

1. Each lesson's ST cases are frozen in its Session A record before implementation starts, with a
   recorded red baseline (AR-2, AR-4).
2. Frozen ST expectations are never edited to match an implementation; a mismatch is fixed in the
   lesson artifacts (AR-4).
3. Each lesson phase completes only after both specialist reviews report no critical/major
   findings (AR-5).
4. Every sprite positioning, timing, or color claim is backed by a recorded state-log observation
   plus a static cycle ledger, and the task record states both (AR-6, AR-13).
5. Roadmap rows reflect Plan Created on plan creation and Done when all ten lessons ship (AR-12).
