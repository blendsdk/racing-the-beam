# Execution Plan: Lesson 79 — The Publisher Mark

> **Document**: `99-execution-plan.md`
> **Status**: Adopted 2026-11-08 — Phase 0 done; Session A next
> **Base**: `255b534` (Part 10 complete)
> **Progress**: 1/6 tasks (Phase 0)
> **Plan directory**: `codeops/features/curriculum/plans/part11-legendary/`

## 1. Overview

One lesson, six tasks. Part 10 is complete at `255b534`; Phase 0 (adoption and the
curriculum amendment) is done. Session A is next.

The sequence is:

1. adopt the plan and amend the curriculum;
2. Session A — freeze the spec and record the red baseline;
3. Session B — implement the sources, doc, captures, ROMs, and site;
4. Session C — verify, review, and fix;
5. commit the lesson atomically;
6. update the roadmap and hand off.

The curriculum-amendment commit and the lesson commit are separate. The amendment
commit carries the README/count sync; the lesson commit carries the artifacts.

## 2. Implementation phases

| Phase | Title | Tasks |
|---|---|---:|
| 0 | Adopt the plan and amend the curriculum | 1 |
| 1 | Session A — freeze + red baseline | 1 |
| 2 | Session B — implement | 1 |
| 3 | Session C — verify + review | 1 |
| 4 | Commit | 1 |
| 5 | Roadmap + handoff | 1 |

## 3. Phase 0 — Adopt the plan and amend the curriculum (done)

**Status**: Done 2026-11-08. The plan is in this directory; the curriculum amendment
is in the Phase 0 commit.

**Preconditions (met)**

- Part 10 is complete at `255b534`.
- `bash scripts/verify.sh` passes at that commit.
- The only uncommitted files are unrelated `.opencode` edits; stage only the
  curriculum/plan paths.

**Steps**

1. Copy this plan into `codeops/features/curriculum/plans/part11-legendary/`: done.
2. Apply the curriculum amendment from `07-integration-checklist.md`: done.
3. Commit:

```text
chore(curriculum): add Lesson 79 and amend the lesson count
```

4. Phase 0 commit: `chore(curriculum): add Lesson 79 and amend the lesson count`
   (see `git log --oneline`).

**Gate**: `git status` clean for the lesson paths; `bash scripts/verify.sh --no-docs`
green; the README and site say 79 / 73–79.

## 4. Phase 1 — Session A: freeze + red baseline

**Steps**

1. Re-affirm ST-79.1–ST-79.10 from `05-testing-strategy.md`.
2. Record the design pins from `03-lesson-spec.md`:
   - frame 9 + 5 + 164 + 5 + 9 = 192;
   - RAM map `$80–$8F` game, `$90–$9F` free, score `$A0–$D7`, stack `$F8–$FF`;
   - `MARK_P0_X=16`, `MARK_P1_X=24`, `MARK_BUF` page-aligned;
   - 3 HMOVEs; 24-cycle rule;
   - captures `game.png`, `no-mark.png`.
3. Record the red baseline:
   - no `lessons/part11-legendary/79-publisher-mark`;
   - no `docs/public/images/lesson79`;
   - no `docs/public/roms/part11-legendary/79-publisher-mark`;
   - Part 11 index has no 79 row/status; sidebar points 79 to the index;
   - `bash scripts/verify.sh --no-docs` green.
4. Confirm no implementation logic has been read (AR-2).

**Gate**: ST-79.1–ST-79.10 frozen; red baseline recorded; verify green.

**Session A record**: pending.

## 5. Phase 2 — Session B: implement

**Steps**

1. Write `lessons/part11-legendary/79-publisher-mark/79-publisher-mark.asm`.
2. Write the three exercise solutions.
3. Write `docs/part11-legendary/79-publisher-mark.md` from the template.
4. Build and run in Stella; inspect the frame, the mark, the score, and the toggle.
5. Capture `game.png` and `no-mark.png` from the committed ROM path.
6. Run `npm run roms`.
7. Update the sidebar link, Part 11 index status, prev/next, and RomPlayer.
8. Record the checkpoint addresses/cycles and the capture frame numbers.

**Commands**

```bash
acme -f plain -o build/lesson79.bin \
  lessons/part11-legendary/79-publisher-mark/79-publisher-mark.asm
stella build/lesson79.bin
npm run roms
bash scripts/verify.sh --no-docs
```

**Gate**: the four ROMs assemble; Stella shows the specified screen; the captures
exist; the site page builds.

**Session B record**: pending.

## 6. Phase 3 — Session C: verify + review

**Steps**

1. `bash scripts/verify.sh` (full).
2. Run the ST-79 tests:
   - frame/state log;
   - score and mark pixel checks;
   - toggle and captures;
   - exercise runs;
   - doc/site checks.
3. Run `atari2600-reviewer` and `curriculum-auditor`.
4. Fix critical/major findings; fix or accept minors.
5. Re-run `bash scripts/verify.sh`.
6. Update `06-findings.md` and the session record.

**Gate**: ST-79.1–ST-79.10 pass; 0 critical/major open; verify green.

**Session C record**: pending.

## 7. Phase 4 — Commit

1. `git status --short`; stage only the lesson paths:
   - `lessons/part11-legendary/79-publisher-mark/`
   - `docs/part11-legendary/79-publisher-mark.md`
   - `docs/public/images/lesson79/`
   - `docs/public/roms/part11-legendary/79-publisher-mark/`
   - `docs/.vitepress/config.ts`
   - `docs/part11-legendary/index.md`
   - the CodeOps plan/findings/execution records
2. Do **not** use `git add -A` if any unrelated files are present.
3. Commit:

```text
feat(lesson79): The Publisher Mark — An Activision-Style In-Game Logo
```

4. Push only if the user authorizes; if the remote moved, rebase first.
5. Confirm `git status` clean and `git log -2` shows the amendment then the lesson.

**Gate**: atomic lesson commit; verify green; README/site consistent.

## 8. Phase 5 — Roadmap + handoff

1. Update RD-11:
   - stage `Executing` or keep `Plan Created` until all seven lessons are in progress;
   - note “Lesson 79 complete; 73–78 pending”;
   - last updated.
2. Portfolio roadmap: curriculum remains 9/11 RDs until Part 11 is done.
3. The next natural progression is Lessons 73–78; their research/plans are separate.
4. Leave this plan directory in place as the historical draft; the repo plan is the
   source of truth after adoption.

## 9. Handoff notes

Part 10 is complete at `255b534`. The only uncommitted files are unrelated `.opencode`
skill/config edits; stage explicit paths and never `git add -A`.

Start at Session A: re-affirm ST-79.1–ST-79.10, record the red baseline, then implement.

## 10. Risks and rollback

| Risk | Mitigation |
|---|---|
| Unrelated `.opencode` edits get staged | Stage explicit paths; never `git add -A` |
| The 5-line bands are too tight | Measure in Session B; reduce the play zone; keep 192 |
| Three HMOVEs disturb a zone | Blank HBLANKs; clear stale motion; state-log each boundary |
| `MarkBuf` page cross | `!align 255,0`; static check |
| Count drift | Run the final grep in `07-integration-checklist.md` |
| Review finds a major issue | Fix before commit; re-run verify; do not ship with an open major |

Rollback: the amendment and lesson commits are separate. If the lesson fails review,
revert the lesson commit only; the curriculum amendment remains valid.
