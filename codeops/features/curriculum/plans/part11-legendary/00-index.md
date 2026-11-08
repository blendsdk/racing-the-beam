# Lesson 79 — The Publisher Mark

> **Status**: Adopted 2026-11-08 — Lesson 79 planned; implementation starts at Session A.
> **Created**: 2026-11-08
> **Repository**: `/home/gevik/workdir/2600/racing-the-beam`
> **Base commit**: `255b534` (Part 10 complete); plan adopted in `d7a952a`
> **Curriculum change**: added Lesson 79 to Part 11 (73–79); total 79 lessons.

## 1. What this is

A complete, implementation-ready plan for a new full lesson:

**Lesson 79 — The Publisher Mark — An Activision-Style In-Game Logo**

The lesson builds **"the calling card"**: a 4,096-byte Atari 2600 ROM with a six-digit
score at the top, a small play field, and a 48-pixel publisher mark in the bottom-left
corner. The score and the mark both use the Lesson 39 48-pixel two-player kernel:
the score reads a RAM buffer at X=56/64, the mark reads a ROM table at X=16/24.
The lesson teaches the second window, the second handover, the page-alignment rule,
and the production context of in-game branding.

## 2. Why this plan exists

The user asked for a separate full lesson on presenting a logo in the bottom-left,
like Activision did. The course had the pieces — Lesson 39 (the 48-pixel trick),
Lesson 50 (zones and handovers), and Lesson 55 (the scrolling logo effect) — but
never combined them into a static in-game publisher mark.

The user's decisions on 2026-11-08:

| Decision | Choice |
|---|---|
| Placement | Lesson 79 at the end of Part 11; Lessons 73–78 keep their numbers |
| Build order | After Part 10 (Lessons 71–72 and the completion gate) |
| Artifact | Small game + score + mark |
| Curriculum | Amended the frozen 78-lesson structure to 79; authorization recorded |
| Mark | Original wordmark; Activision history as context only |

## 3. Current repository state

Part 10 is complete at `255b534`. The working tree is clean except for unrelated
`.opencode` skill/config edits; do not stage them. Lesson 79 is not started.

The pending work is Session A (freeze + red baseline), Session B (implement), and
Session C (verify + review), followed by the atomic lesson commit.

## 4. File map

| File | Purpose |
|---|---|
| `00-index.md` | This overview, decisions, and handoff |
| `01-requirements.md` | Lesson and curriculum requirements, acceptance criteria |
| `02-ambiguity-register.md` | Closed decisions; zero open material items |
| `03-lesson-spec.md` | Frame, RAM, ROM, kernels, checkpoints, captures, exercises |
| `04-preflight-report.md` | Prerequisites, claims, budgets, screenshot plan, risks |
| `05-testing-strategy.md` | ST-79.1–ST-79.10 and the evidence method |
| `06-findings.md` | Review findings template (pending execution) |
| `07-integration-checklist.md` | Exact site, README, CodeOps, and count updates |
| `99-execution-plan.md` | Session A/B/C, commands, reviews, commits, handoff |

## 5. How to use this plan

1. The curriculum amendment and this plan are adopted (2026-11-08).
2. Read `03-lesson-spec.md`, `04-preflight-report.md`, and `99-execution-plan.md`.
3. Run Session A (freeze + red baseline).
4. Run Session B (implement) and Session C (verify + review).
5. Commit the lesson atomically.
6. Leave Lessons 73–78 as `🔮 Coming Soon`; update the roadmap to 1/7 Part 11 lessons.

## 6. Curriculum amendment

The user's 2026-11-08 instruction authorized adding Lesson 79. The amendment updates
`AGENTS.md`, both lesson-author briefs, the CodeOps requirements and AR-1, and every
`78` / `73–78` reference. The structure is frozen again at 79 after the amendment.

## 7. Hard constraints

- **Original mark**: use `RACING`, not the Activision wordmark. The history note is
  factual context, not a reproduction.
- **Five hard rules**: VitePress rework, Stella captures, preflight, README sync,
  committed ROM + player.
- **Four sources, four ROMs**: the main ROM and three complete exercise solutions.
- **No sound**: Lesson 79 stays focused on the mark; Lesson 50 is the precedent.
- **Stage only lesson paths**: unrelated `.opencode` edits are present; do not stage them.
