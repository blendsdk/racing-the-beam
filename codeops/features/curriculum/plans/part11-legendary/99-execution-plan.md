# Execution Plan: Lesson 79 — The Publisher Mark

> **Document**: `99-execution-plan.md`
> **Status**: Complete — Lesson 79 committed at `9da653b`; 73–78 pending.
> **Base**: `255b534` (Part 10 complete)
> **Plan adoption**: `d7a952a` (curriculum amendment and plan)
> **Progress**: 6/6 tasks
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

4. Phase 0 commit: `d7a952a chore(curriculum): add Lesson 79 and amend the lesson count`.

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
3. Record the red baseline at the current HEAD (after the plan-adoption commit):
   - no `lessons/part11-legendary/79-publisher-mark`;
   - no `docs/public/images/lesson79`;
   - no `docs/public/roms/part11-legendary/79-publisher-mark`;
   - the Part 11 index lists 79 as `🔮 Coming Soon`;
   - the sidebar has a 79 entry pointing to `/part11-legendary/`;
   - the README says 79 / 73–79;
   - `bash scripts/verify.sh --no-docs` green.
4. Confirm no implementation logic has been read (AR-2).

**Gate**: ST-79.1–ST-79.10 frozen; red baseline recorded; verify green.

**Session A record** (2026-11-08 09:07): ST-79.1–ST-79.10 re-affirmed against `05-testing-strategy.md`. Design pins from `03-lesson-spec.md`: the frame is **9 score + 5 top positioner + 164 play + 5 handover + 9 mark = 192** (absolute 37–45 score, 46–50 top positioner, 51–214 play, 215–219 handover, 220–228 mark, 229 overscan); the score uses the Lesson 39 48-pixel kernel at P0=56/P1=64, the mark a `MarkDraw` clone at P0=16/P1=24; `MarkBuf` is 48 bytes, page-aligned, column-major, bottom-up; RAM `$80–$8F` game, `$90–$9F` free, score `$A0–$D7`, stack `$F8–$FF`; three HMOVEs (score in VBLANK, top positioner, handover) with the 24-cycle rule; SELECT toggles `MarkVisible`; the auto-demo scripts the toggle for `game.png` (mark visible) and `no-mark.png` (hidden). Red baseline confirmed at `cf5aab1`: no `lessons/part11-legendary/79-publisher-mark`, no `docs/public/images/lesson79`, no `docs/public/roms/part11-legendary/79-publisher-mark`; the Part 11 index lists 79 as Coming Soon; the sidebar 79 entry points to `/part11-legendary/`; README says 79 / 73–79; `bash scripts/verify.sh --no-docs` green. No implementation logic read (AR-2).

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

**Session B record** (2026-11-08 10:05): `79-publisher-mark.asm` (4,096) with the 9+5+164+5+9 frame, the Lesson 39 score band at 56/64, the 48-pixel `RACING` mark at 16/24 from a page-aligned 48-byte `MarkBuf`, the unrolled `MarkDraw` clone (C commit at CLK 93, 0/384), the top positioner and the handover (three HMOVEs), the play field (82 rows x 2), the SELECT toggle, and the auto-demo; three 4,096-byte solutions (ten-letter mark, bottom-centre mark, playfield mark); the doc (1,634 lines); the two captures. The review fixes were the ex3 PF0 order, the C-column bleed, the WSYNC tip, the single overscan timer, the auto-demo narrative, and the doc/comment residuals.

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

**Session C record** (2026-11-08 10:20): `bash scripts/verify.sh` PASSED (269 sources, no drift, docs build); four ROMs 4,096 and byte-identical; Full Source exact (990 source / 1,634 doc lines); `npm run roms` 269. Frame: `StartFrame` `$F04D` 259/3, `VblankStart` `$F05B` 0/5, `BodyStart` `$F169` 37/5, `ScoreDone` `$F16C` 46/5, `PlayStart` `$F1A2` 51, `HandoverStart` `$F216` 215, `MarkStart` `$F248` 220, `MarkDone`/`OverscanStart` `$F24F` 229/6. The mark host-vs-capture check is 0/384; the score block is X=56-103; the mark block X=16-63, visible 184-190; `no-mark.png` has 0 gold pixels in the band; the auto-demo timeline is 63/188/250/312...; the toggle is at frame 240 (Stella 241). Reviews (AR-5): atari2600-reviewer — 4 major (ex3 PF0, C bleed, WSYNC tip, double timer) + 8 minor, then 4 minor, fixed; curriculum-auditor — 1 major (auto-demo) + 9 minor, then 6 minor, fixed. Final 0 critical, 0 major open; 1 accepted limitation (the 0/384 check is against the 960x606 window capture, not a native TIA dump). The Part 11 index row 79 is now Complete and the sidebar 79 links to the doc; 73-78 remain Coming Soon.

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

**Phase 5 record** (2026-11-08): RD-11 is **Executing** with Lesson 79 complete and
73–78 pending; the feature roadmap stays at 10/11 RDs, and the portfolio remains 10/11
RDs. The plan directory stays as the historical record for Lesson 79. The next work
is the 73–78 research and plans. Lesson 79 was committed at `9da653b`.

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
