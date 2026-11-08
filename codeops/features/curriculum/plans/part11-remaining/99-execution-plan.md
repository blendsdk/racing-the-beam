# Lessons 73–78 — Execution Plan

> **Status**: Adopted 2026-11-08. Six lessons, one atomic commit each, then one integration
> commit, then push and watch CI.

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

| Lesson | Commit | Gate | Reviews |
|---|---|---|---|
| 73 | `14706c2` | PASSED (272 sources, docs build) | 3 critical, 10 major, 22 minor fixed |
| 74 | `pending-commit` | PASSED (275 sources, docs build) | 1 critical, 3 major, 11 minor fixed |
| 75 | `pending-commit` | PASSED (278 sources, docs build) | 12 major, 12 minor fixed |
| 76 | pending | — | — |
| 77 | pending | — | — |
| 78 | pending | — | — |
| Integration | pending | — | — |
