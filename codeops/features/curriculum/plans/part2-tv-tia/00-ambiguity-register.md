# Ambiguity Register: Part 2 — TV & TIA (Lessons 12–18)

> **Status**: ✅ GATE PASSED — all 12 items resolved
> **Last Updated**: 2026-10-10 21:56
> **Authority**: `--auto-design` active for this plan chain (policy version 1, root invocation ID `curriculum-plan-part2-2026-10-10`). AR #1, #3, #4 are user decisions; AR #2, #5–#12 are delegated technical decisions.

| # | Category | Ambiguity / Gap | Options Presented | User Decision | Status |
|---|----------|-----------------|-------------------|---------------|--------|
| 1 | Scope | Which lessons does this plan cover, and in what order? | RD-02 only (12–18) sequential / include later RDs / parallel lessons | **User:** RD-02 only — lessons 12–18 strictly sequential; each lesson is the next one's prerequisite | ✅ Resolved |
| 2 | Technical | How is the work phased and sessioned? | One phase per lesson with Sessions A/B/C / one phase per session / one phase for all seven | **AI (auto-design):** 7 phases, one per lesson; Session A freezes that lesson's ST cases, Session B implements, Session C verifies to green and hardens — the Part 1 ordering | ✅ Resolved |
| 3 | Scope | Which lessons need a standalone `demo-NN.asm`? | Only where needed (main ROM cannot visualize the concept) / one demo per lesson / no demos | **User:** only where needed — decided per lesson in the specification with a reason; expectation 0–2 for this part | ✅ Resolved |
| 4 | Technical | What fills every task's Verify line? | `bash scripts/verify.sh` / an additional gate | **User-confirmed:** `bash scripts/verify.sh`; targeted Stella state-log evidence remains per-task evidence, not the gate | ✅ Resolved |
| 5 | Technical | Who reviews, and what blocks completion? | Both specialists per lesson + no critical/major / single reviewer | **AI (auto-design):** `atari2600-reviewer` and `curriculum-auditor` gate every lesson; no critical/major findings (RD-02 AC 3) | ✅ Resolved |
| 6 | Technical | What evidence standard governs timing/cycle/frame claims (Part 2 is the course's timing core)? | Stella state-log breakpoints + static cycle ledgers + labeled witnesses / static reasoning only / simulator tracing | **AI (auto-design):** state-log observations at labelled checkpoints are the primary runtime evidence; every timing claim carries a static cycle ledger; scratch witnesses only for what-if experiments, clearly labeled and deleted | ✅ Resolved |
| 7 | Technical | May the work add machinery beyond the existing pipeline? | Reuse pipeline only / add test framework or new tooling | **AI (auto-design):** reuse only — `vcs-lesson-production` cycle, `capture-screenshot.sh`, `npm run roms`, `include/macro.asm`; macro expansion only if a lesson requires it (reopen trigger) | ✅ Resolved |
| 8 | Naming & terminology | What are the lesson folder/doc/image/ROM identifiers? | Existing slugs verbatim / new naming | **AI (auto-design):** the existing endpoints verbatim (`12-the-ntsc-frame` … `18-mid-scanline-changes`); folder/doc/image/ROM naming per the Part 1 convention | ✅ Resolved |
| 9 | Scope | May lessons name later-part registers and concepts (COLUP0/1/PF, scoreboard/playfield/sprite zones) they cannot yet use? | Name-only reference notes / avoid entirely / introduce early | **AI (auto-design):** name-only references are allowed as context notes marked as belonging to later parts; lesson code and exercises use only ≤ Part 2 mechanisms; the auditor verifies | ✅ Resolved |
| 10 | Integration points | The Part 2 index page is a minimal stub; how is it integrated? | Rebuild to the Part 1 format and flip rows per lesson / leave as is / rebuild at the end | **AI (auto-design):** rebuild in the lesson-12 phase to the Part 1 format (lesson rows + What You'll Learn); each lesson flips its own row to ✅ | ✅ Resolved |
| 11 | Technical | Which video standard do the lessons target? | NTSC only / NTSC + PAL | **AI (auto-design):** NTSC only (262 lines, ~60.2 Hz); PAL appears only as a noted aside | ✅ Resolved |
| 12 | Technical | Commit and record-keeping per lesson? | One atomic `feat(lessonNN)` commit + plan/ledger/roadmap updates / batch commits | **AI (auto-design):** one atomic commit per lesson via the `git-commit` skill in push mode with `Ref:`/`Task:` trailers; findings ledger, progress header, and roadmap transitions per Part 1 practice | ✅ Resolved |

### Resolution Notes

**Shared delegated provenance (AR #2, #5–#12).** Authority: AI — delegated by `--auto-design`.
Eligibility: implementation mechanisms and within-scope interpretations inside the confirmed
RD-02 scope (lessons 12–18, existing pipeline). Objective: ship Part 2 at the Part 1 quality bar.
Evidence: the verified Part 1 pipeline (`scripts/verify.sh`, `npm run roms`,
`scripts/capture-screenshot.sh`), the three installed specialists, and Part 1's executed plan.
Rejected alternatives: heavier options (test frameworks, new tooling, parallel lessons) add
machinery without improving verifiability of static lesson content. Strongest counterargument:
Part 2 is more timing-critical than Part 1, so the state-log evidence standard could demand more
than needed; answered by keeping the standard observational (AR-6) and reusing the proven method.
Confidence: High. Hardening: not required — low-risk, reversible choices inside an existing
verified pipeline. Policy version: 1. Root invocation ID: `curriculum-plan-part2-2026-10-10`.
Reopen triggers: RD-02 changes; the pipeline or specialists change; a lesson's specification
cannot express its concept under one of these decisions.

**AR-1.** Decision: RD-02 only — lessons 12–18, strictly sequential. Evidence:
`codeops/features/curriculum/requirements/RD-02-part2-tv-tia.md` (lesson list and dependencies);
RD-01 complete, so the Part 2 preflight dependency is satisfied. Reopen trigger: the user
requests a curriculum change.

**AR-3.** Decision (user): a standalone `demo-NN.asm` ships only where a lesson's concept cannot
be visualized by its main ROM; the reason is recorded per lesson. Current resolution: all seven
main ROMs are designed to be directly visual ([03-lesson-specs.md](03-lesson-specs.md)), so the
expectation is zero standalone demos for this part; Part 1 shipped demos only for its catalogue
lesson (lesson 10). Reopen trigger: a Session B implementation proves a concept is not
screen-observable, in which case the demo decision moves to the user.

**AR-4.** Decision (user-confirmed): `bash scripts/verify.sh` is the single gate command
(detected from `AGENTS.md`; used all through Part 1). Targeted Stella observations and documents
remain per-task evidence; they do not change the gate.

**AR-6.** Decision: timing, cycle, and frame claims use the Part 1 evidence method — a `stella
-dbg.logbreaks 1 -logtoconsole 1 -break '$addr'` state log at labelled checkpoints (format
`BP: <frame> <scanline> <x> <y> | <flags> <A> <X> <Y> <SP> |`), plus a static cycle ledger for
every claim. Scratch witnesses are allowed only to provoke what-if states (never to produce
lesson screenshots), are clearly labeled in the task record, and are deleted afterwards.
Evidence: Part 1 lessons 08–11 executed this method; requirements AR-6 claim discipline.

**AR-9.** Decision: lessons may name later-part registers and concepts as explicit context notes
(e.g., `COLUP0`/`COLUP1`/`COLUPF` in lesson 13; the scoreboard/playfield/sprite zone taxonomy in
lesson 16), marked as belonging to later parts. Lesson code, exercises, and solutions use only
mechanisms taught by lesson ≤ their own. The `curriculum-auditor` verifies this boundary per
lesson. Reopen trigger: a lesson needs a later-part mechanism for its stated outcome.

**AR-10.** Decision: rebuild `docs/part2-tv-and-tia/index.md` to the Part 1 format (Lessons
table with status rows + What You'll Learn) during the lesson-12 phase; each lesson flips its own
row to ✅ Complete with a link. Evidence: `docs/part1-6502-cpu/index.md` format.

**AR-12.** Decision: one atomic commit per lesson — `feat(lessonNN): <Lesson title>` via the
`git-commit` skill in push mode with `Ref:`/`Task:` trailers; the findings ledger and execution
plan's progress header update per ruling batch and task, and the roadmap moves RD-02 to
`Plan Created` now and `Done` when all seven lessons ship.
