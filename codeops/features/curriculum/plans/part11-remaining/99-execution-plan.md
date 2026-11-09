# Lessons 73–78 — Execution Plan

> **Status**: Complete 2026-11-09. Six lessons and the Part 11 integration committed; RD-11
> closes at 11/11.

## Order

| Task | Lesson | Depends on |
|---|---|---|
| 1 | 73 Cosmic Ark Starfield | plan |
| 2 | 74 Skipdraw | 73's integration pattern |
| 3 | 75 Pseudo-3D Road | 74 |
| 4 | 76 Procedural Worlds | 75 |
| 5 | 77 Interlaced Flicker | 76 |
| 6 | 78 Room & Object Engine | 77 |
| 7 | Part 11 integration + RD-11 close | 1–6 |

## Per-lesson loop

1. Dispatch the lesson author with the spec and the artifact list.
2. Parent checks sizes, ROM matches, Full Source, frame/state logs, and captures; runs
   `bash scripts/verify.sh`.
3. Dispatch `atari2600-reviewer` and `curriculum-auditor` with the parent-run evidence.
4. Fix all critical/major findings; round-2 confirmation.
5. Flip the part index row and the sidebar entry; run the gate.
6. Atomic commit `feat(lessonNN): <title>`.

## Evidence to keep

Per lesson: the three ROM sizes and byte matches, the frame log, the mechanism state log, the
two pixel checks, the two captures, the Full Source match, and the two review reports. Record
the summary in `04-findings.md` and the final state in this file.

## Completion record

**Final** (2026-11-09): all seven Part 11 lessons (73–79) are complete; RD-11 is Done at 11/11; the repository builds 287 ACME ROMs (288 total `.bin` including the Part 9 bB reference); `bash scripts/verify.sh` passes and the site deploys.

| Lesson | Commit | Gate | Reviews |
|---|---|---|---|
| 73 | `14706c2` | PASSED (272 sources, docs build) | 3 critical, 10 major, 22 minor fixed |
| 74 | `0521de9` | PASSED (275 sources, docs build) | 1 critical, 3 major, 11 minor fixed |
| 75 | `86723e6` | PASSED (278 sources, docs build) | 12 major, 12 minor fixed |
| 76 | `11c43cf` | PASSED (281 sources, docs build) | 0 critical/major, 12 minor fixed |
| 77 | `a492af4` | PASSED (284 sources, docs build) | 0 critical, 11 minor fixed |
| 78 | `868cc37` | PASSED (287 sources, docs build) | 3 major, 11 minor fixed |
| Integration | `a2f56f9` | PASSED (287 sources, docs build) | prev/next chain wired; Part 11 7/7 |
