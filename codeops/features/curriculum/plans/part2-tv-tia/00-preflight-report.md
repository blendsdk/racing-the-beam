# Preflight Report: Part 2 — TV & TIA Plan (Lessons 12–18)

> **Status**: ✅ PREFLIGHT PASSED — all 22 findings resolved (iteration 2 verified the five majors and 16 resolutions; seven residuals completed and directly verified)
> **Iteration**: 1 (first scan)
> **Artifact**: Implementation plan at `codeops/features/curriculum/plans/part2-tv-tia/` (7 documents), ref `feee94c`
> **Codebase Grounded**: 5 auditor clusters (13 dimensions) + 1 independent challenger; every reference claim re-checked against the repo
> **Last Updated**: 2026-10-10 22:16

```
SAME-SESSION REVIEW: This artifact was created in the current session.
Same-agent bias risk is elevated. Mitigation used: the 13-dimension scan was
fanned out to five fresh-context auditor dispatches and the MAJOR batch was
challenged by one independent challenger before recommendations were recorded.
For maximum independence, a fresh-session audit remains an option.
```

### Codebase Context Summary

**Tech Stack:** 6502/6507 assembly (ACME 0.97), Stella 7.0 + ImageMagick capture tooling, VitePress 1.6.4 site, Bash scripts.
**Architecture:** per-lesson sources under `lessons/partN-topic/NN-slug/` assembled by `scripts/build-roms.sh` (`npm run roms`) into committed ROMs under `docs/public/roms/`; `scripts/verify.sh` re-assembles everything and compares bytes, then builds the docs site; lessons follow a fixed template and the five hard rules; two specialist reviewers gate every lesson.
**Key Files Examined:** the seven plan documents; `AGENTS.md`; `RD-02`; the executed Part 1 plan and shipped lessons 04–11; `include/vcs.asm`, `include/macro.asm`; `scripts/{verify,build-roms,capture-screenshot}.sh`; `docs/.vitepress/config.ts`; Part 2/3 stubs; `docs/reference/*`; the `atari-2600-expert` timing/TIA references.

### Summary by Dimension

| # | Dimension | Findings | Highest Severity |
|---|-----------|----------|-----------------|
| 1 | Ambiguities | (counted within others) | 🟠 |
| 3 | Logical Contradictions | 2 | 🟠 |
| 4 | Completeness Gaps | 4 | 🟠 |
| 5 | Dependency Issues | 1 | 🟡 |
| 6 | Feasibility Concerns | 3 | 🟠 |
| 7 | Testability | 2 | 🔵 |
| 11 | Ordering & Sequencing | 1 | 🟡 |
| 12 | Consistency | 7 | 🟠 |
| 13 | Codebase Alignment | 1 | 🟠 |

### Summary by Severity

| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | 0 | — |
| MAJOR | 5 | 5 resolved, verified |
| MINOR | 12 | 12 resolved, verified |
| OBSERVATION | 5 | 5 resolved, verified |

### User Decisions (bulk acceptance, 2026-10-10)

The user accepted **all recommendations** in one bulk decision, covering every finding. The
per-finding record (option spelled out):

| # | Accepted resolution |
|---|----------------------|
| PF-001 | **Option A** — pin the ST-observable parameters in `03`; Session A hand-derives and freezes cumulative values; the walkthrough restates the pinned numbers |
| PF-002 | **Option A** — self-contained course-local named-color table in the exercise solution + lesson doc; drop the stub reference pages from the dependency list |
| PF-003 | **Option B** — lesson 12 derives ≈59.9 Hz (`228 × 262` clocks ÷ 3.579545 MHz) and calls `~60 Hz` the rounded alias; background text uses "~60 Hz" |
| PF-004 | **Option A** — the existing stub titles are canonical; align the six spec headings to them |
| PF-005 | **Option B** — fixed late offset; freeze the exact static tear; reword so "movement" is attributed to its true cause (lesson 17 owns drift) |
| PF-006 | Use the ground-truth symbol `T1024T` in spec and prose |
| PF-007 | **Option A** — lesson 12 writes an explicit counted (WSYNC) frame carried through 13–14; the timer arrives in lesson 15; reword the shared rule |
| PF-008 | Re-run `analyze-agents` with the current plan set; reword the index's check sentence |
| PF-009 | Document the state-log fields as `<frame> <scanline> <cycles> <pixels>`; replace `$F0XX` with an `<addr>` placeholder |
| PF-010 | **Option A** — state the section-2 overrun consequence (visible/frame extent) in the spec and ST rows |
| PF-011 | Reword exercise 2: labels live in the lesson's table/caption, not on screen |
| PF-012 | Align AC 4 and the testing-strategy checklist to AR-6 ("state log **plus** a static cycle ledger"); add "+ ledger" to the five evidence cells |
| PF-013 | Add one site-integration ST row per lesson (page renders, `<RomPlayer>` loads the committed ROM, prev/next both ways, index row links); name the embed in the Session B artifact list |
| PF-014 | Swap to `npm run roms` first, then capture from the committed ROM path (all seven Session B steps) |
| PF-015 | Restate the AR-3 row as the user's tolerance narrowly resolved to 0 |
| PF-016 | Fix "vertical zones" to "horizontal zones — strips stacked vertically"; add band/zone/column definitions to the shared design rules |
| PF-017 | Reword the lesson-12 red-baseline line ("no part-index row yet (lesson 12); 'Coming Soon' row (lessons 13–18)") |
| PF-018 | Specify in AR-10 that unshipped rows read `🔒 Coming Soon` until flipped |
| PF-019 | Re-point the AR citations on the ST-x.5 rows and Session B steps (AR-10 index, AR-8 naming, RD-02 AC 1 artifact set) |
| PF-020 | Add "+ file size" to the ST-NN.1 evidence method |
| PF-021 | Reword ST-12.2/12.3 clauses to what their evidence actually establishes |

---

## MAJOR findings

### PF-001: Session A freeze contradicts "derived in the walkthrough" numbers 🟠 MAJOR

**Dimension:** 3 (Logical Contradiction) — corroborated by dimensions 7 and 12
**Location:** `03-lesson-specs.md:13–14` and `:172`; vs `01-requirements.md` AC 1, `99-execution-plan.md` Session A steps (e.g. `:187`), `07-testing-strategy.md:15–27`, `:58`, `:87`, `:98`
**Codebase Evidence:** `07-testing-strategy.md` mandates expectations "derived only from 03/register" and self-contained; `01` AC 1 freezes ST cases in Session A — but `03` defers "the exact cycle plumbing" (a Session B artifact) and leaves observable values unpinned (lesson 13 luminance sequence; lesson 14 late-mode offset; lesson 15 hues; lesson 16 fifth-zone partition and boundary numbering; lesson 17 ramp colors and overrun amount; lesson 18 boundary cycles and both animation states).
**The Problem:** four plan documents cannot all be satisfied: either the numbers are frozen in Session A (then `03` must pin them), or they come from the Session B walkthrough (then the frozen-oracle claims in `01`/`07` are false and the ST rows become self-referential).
**Options:**

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A | Pin the ST-observable parameters in `03`; Session A hand-derives cumulative values (e.g. boundary scanlines) and freezes them; the walkthrough restates the pinned numbers while deriving instruction-level plumbing | Keeps the immutable oracle genuinely independent; smallest change; challenger-endorsed | Requires one careful spec-edit pass now |
| B | Reclassify the ledger as Session C evidence; soften `07`'s self-contained claims | No spec edits now | Weakens the plan's central verification claim; rows like "exactly the stated drift" become self-fulfilling |

**Recommendation:** Option A (challenger verdict: material; A strongest; only ST-observable parameters need pinning — instruction selection/NOP counts stay free).

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-002: Lesson 13 exercise 2 depends on an empty stub page 🟠 MAJOR

**Dimension:** 13 (Codebase Alignment) — corroborated by dimensions 1, 4, 6
**Location:** `03-lesson-specs.md:75`; `02-current-state.md:97`
**Codebase Evidence:** `docs/reference/color-chart.md` is an 8-line "Coming Soon" stub (as are `tia-registers.md`, `glossary.md`); no canonical color-name set exists in the repo — only informal, partially clashing names in shipped lesson prose.
**The Problem:** the "chart match" exercise sources named colors from a page with no content; executing as written either silently deviates from the spec or adds an unplanned deliverable outside RD-02's artifact list.
**Options:**

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A | Make the exercise self-contained: a small course-local named-color table embedded in the solution and lesson doc; drop the stub pages from the dependency list | One-line spec edit; no new scope | Names stay course-local (doc must say so) |
| B | Author `docs/reference/color-chart.md` as a deliverable | Fills a real gap | Outside RD-02 / "reuse only" — requires an explicit user scope decision |

**Recommendation:** Option A (challenger: material but narrow; A strongest; B only as a knowingly authorized scope expansion).

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-003: "~60.2 Hz" contradicts the repo's own numbers 🟠 MAJOR

**Dimension:** 12 (Consistency)
**Location:** `00-ambiguity-register.md:19` (AR-11), `00-index.md:84`, `01-requirements.md:41`, `03-lesson-specs.md:25` and `:37`
**Codebase Evidence:** `atari-2600-expert/references/timing.md` says 76 cycles = 228 color clocks and "~60 Hz"; 3.579545 MHz ÷ (228 × 262) = **59.92 Hz**. 60.2 Hz corresponds to a 227-clock line (nowhere in this repo).
**The Problem:** the wrong figure sits in lesson 12's concepts — the lesson that teaches the frame — and would propagate under AR-6 claim discipline.
**Options:**

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A | Use "~60 Hz" everywhere, matching the course convention | Minimal, safe | Does not teach the derivation |
| B | Lesson 12 shows the one-line arithmetic (`228 × 262` clocks ÷ 3.579545 MHz ≈ 59.9 Hz) and calls `~60 Hz` the rounded alias; background text uses "~60 Hz"; one line notes broadcast NTSC's 227.5-clock line vs the TIA's 228 | Turns a magic number into the lesson's own arithmetic; reviewer-checkable | Must be framed as rounding, not correction; keep out of cadence math |

**Recommendation:** Option B (challenger verdict: material; B strongest with the split convention).

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-004: Six lesson subtitles diverge from the published stub titles 🟠 MAJOR

**Dimension:** 4 (Completeness Gaps — AC 4 impact)
**Location:** `03-lesson-specs.md` headings `:33, :60, :86, :112, :138, :162` (lesson 18 matches)
**Codebase Evidence:** stubs `docs/part2-tv-and-tia/{12..17}-*.md:1` carry e.g. "— 262 Scanlines of Precision", "— Painting the Screen", "— Synchronizing with the Beam"; Part 1's shipped lessons kept their stub titles verbatim. `RD-02` AC 4 and `AGENTS.md` forbid renames; AR-8 pins slugs, never titles.
**The Problem:** the executor cannot know which title set is canonical for document H1/frontmatter and the rebuilt index; one reading silently renames six published lessons.
**Options:**

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A | Stub titles are canonical; align the six spec headings to them | Zero policy risk; matches the only executed precedent | Loses the richer new subtitles |
| B | Adopt the new subtitles | Nicer descriptions | Changes published lesson titles — requires an explicit user ruling; stubs/index must change too |

**Recommendation:** Option A (both the cluster and the challenger land here; B is viable only as a recorded user decision).

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-005: Lesson 14's "moving, torn" boundary is unsatisfiable as specified 🟠 MAJOR

**Dimension:** 6 (Feasibility) — corroborated by dimensions 7 and 9
**Location:** `03-lesson-specs.md` §Lesson 14 (`:91–97`); `07-testing-strategy.md` ST-14.3
**Codebase Evidence:** hardware references (`timing.md`, kernel notes): a fixed late write inside a per-line-WSYNC loop is deterministic — every frame is identical, so "two frames a moment apart differ" (ST-14.3) cannot hold. With a two-region picture the artifact is a boundary-line notch, not a moving edge.
**The Problem:** as specified, the implementer must invent motion (a spec change) or fail/doctor the ST.
**Options:**

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A | Spec an explicit in-mode animation: the late offset advances one cycle per frame so the tear walks; capture at a ledger-predicted position | Preserves a "moving" experience | Simulated drift; ledger becomes frame-counter-dependent |
| B | Keep the fixed offset; freeze the exact static artifact (e.g., "boundary line paints `$42` for the first N clocks, then `$84`"); capture once; fix the wording so "movement" is attributed to its true cause (varying per-frame work / unanchored code) | Deterministic, reviewer-checkable; lesson 17 already carries the drift teaching | The tear is subtle — the spec must define a visible offset |

**Recommendation:** Option B (challenger: material; B strongest; lesson 17 owns the drift artifact).

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

---

## MINOR findings

### PF-006: `TIM1024T` is not a defined symbol 🟡 MINOR

**Dimension:** 5 (Dependency Issues) · **Location:** `03-lesson-specs.md:115` · **Codebase Evidence:** `include/vcs.asm:182` defines `T1024T`; no `TIM1024T` anywhere in `include/`; the stale stub doc uses the DASM-era spelling.
**Problem:** a literal implementation fails to assemble or contradicts the ground-truth file.
**Options:** single viable path — use `T1024T` in the spec (optionally noting the DASM-era alias once in prose). Rejected: editing `include/vcs.asm` to add an alias (shared ground truth; ripples to 36 sources).
**Recommendation:** `T1024T`.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-007: Lesson 12–15 blanking-chain contradiction 🟡 MINOR

**Dimension:** 3 (Logical Contradiction) · **Location:** `03-lesson-specs.md:20–22`, `:39–42`, `:118–126` · **Codebase Evidence:** shipped frame uses `+vsync`/`+set_timer`/`+wait_timer` (`include/macro.asm`); lesson 15's exercise 1 says "convert the VBLANK wait from a WSYNC loop", but under the shared rule the macro (timer) frame was already in use.
**Problem:** three plan statements cannot all hold; one dependent statement is wrong.
**Options:**

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A | Lesson 12 writes an explicit counted (WSYNC) frame; lessons 13–14 carry it; the timer arrives in lesson 15 (exercise 1 stands as written); reword the shared rule | Makes "the frame written out line by line" literal; gives lesson 15 its stated job | One rule sentence and lesson 15's ROM description change |
| B | Lesson 12 mirrors the timer explicitly; 13–18 keep the macro frame; reword exercise 1 | Smaller doc churn | Weakens lesson 12's "you've been running this all along" teaching arc |

**Recommendation:** Option A.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-008: Specialist-check evidence predates this plan 🟡 MINOR

**Dimension:** 12 (Consistency) · **Location:** `00-index.md:94–97` · **Codebase Evidence:** `codeops/specialist-check.json` records `plans:["part1-6502"]`, committed before this plan existed; `AGENTS.md` renders "check due" on mismatch.
**Problem:** the cited check never covered `part2-tv-tia`; the conclusion almost certainly stands, but the evidence line overstates scope.
**Options:** single viable path — re-run `analyze-agents` after plan creation (records both plans; expected `None` again) and reword the index sentence to state that.
**Recommendation:** re-run the check; apply the wording.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-009: Stella state-log field names and wildcard example are wrong 🟡 MINOR

**Dimension:** 12 (Consistency) · **Location:** AR-6 (`:54–56`), `07:22–23`, `00-index.md:68` · **Codebase Evidence:** a live Stella 7.0 breakpoint logs `BP: <frame> <scanline> <cycles> <pixels> | <flags> <A> <X> <Y> <SP> |`; `-break '$F0XX'` produces no log (no wildcard support).
**Problem:** the documented format mislabels fields; the example command silently yields nothing.
**Options:** single viable path — document the fields as `<frame> <scanline> <cycles> <pixels>` (or Stella's `Cy`/`Pxl` names) and replace `$F0XX` with a concrete-address placeholder (`<addr>`).
**Recommendation:** apply the wording fix.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-010: Lesson 17 section 2's overrun consequence is undefined 🟡 MINOR

**Dimension:** 6 (Feasibility) · **Location:** `03-lesson-specs.md` §Lesson 17 (`:168–172`); ST-17.2/17.3 · **Codebase Evidence:** timing references: 96 iterations × (76+k) cycles cannot fit 96 lines; with +6 cycles, 6×96 = 576 ≈ 7.58 lines, so the visible area stretches to ≈104 lines and the frame to ≈270 — the overscan wait cannot absorb it.
**Problem:** the frozen screenshot and ledger have no defined expected extent; the doc could silently contradict Stella.
**Options:**

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A | State the consequence in the spec and ST (visible/frame growth figures) | Honest; matches the course's over-budget rule | The "ruler" also demonstrates frame growth — needs clear wording |
| B | Keep 262 lines by trimming section 2 with WSYNC/loop-count changes | Preserves the canonical frame | Breaks the "same loop" premise |

**Recommendation:** Option A.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-011: Lesson 13 exercise 2's "labeled bands" needs later-part mechanisms 🟡 MINOR

**Dimension:** 6 (Feasibility) · **Location:** `03-lesson-specs.md:75` · **Codebase Evidence:** background-only rendering allows `COLUBK` bands; on-screen text needs playfield/sprites (lessons ≥19) — forbidden by AR-9.
**Problem:** read literally, the exercise is infeasible with ≤ Part 2 mechanisms.
**Options:** single viable path — reword: bands whose colors match the named-color table; the labels live in the lesson's table and figure caption. Rejected: on-screen labels (later mechanisms; AR-9).
**Recommendation:** apply the rewording.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-012: Ledger evidence wording conflicts with AR-6 🟡 MINOR

**Dimension:** 12 (Consistency) · **Location:** `01-requirements.md` AC 4; `07-testing-strategy.md:122`; ST-12.4/14.4/15.4/17.4/18.4 evidence cells · **Codebase Evidence:** AR-6 requires the state log **plus** a static cycle ledger for every claim; the AC/checklist say "or"; five evidence cells name only the log.
**Problem:** Session C could pass or fail the same claim on different evidence.
**Options:** single viable path — align all wordings to AR-6 ("plus, for every timing/cycle/frame claim, a static cycle ledger"); add "+ ledger" to the five cells.
**Recommendation:** apply.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-013: No acceptance case or step covers `<RomPlayer>` and prev/next 🟡 MINOR

**Dimension:** 4 (Completeness Gaps) · **Location:** `07-testing-strategy.md` ST rows/checklist; `99-execution-plan.md` Session B steps · **Codebase Evidence:** Part 1's testing strategy had an integration case and an E2E case covering the player and pager; Part 2 dropped both; `verify.sh` only builds docs.
**Problem:** RD-02 AC 1 requires the player embed and prev/next; today only the auditor review would catch a broken path.
**Options:** single viable path — add one site-integration ST row per lesson (sixth case: page renders, `<RomPlayer>` loads the committed ROM, prev/next resolve both ways, index row links) and name the embed in the Session B artifact list.
**Recommendation:** add the row and the step.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-014: Session B captures screenshots before the committed ROM exists 🟡 MINOR

**Dimension:** 11 (Ordering) · **Location:** `99-execution-plan.md` Session B steps (all seven) · **Codebase Evidence:** the checklist mandates capture from the committed ROM path; `capture-screenshot.sh` fails if the ROM is absent; the step schedules `npm run roms` after capture.
**Problem:** the step is not executable as written; an executor must improvise (or violate provenance).
**Options:** single viable path — swap the clauses: `npm run roms` first, then capture from the committed path.
**Recommendation:** swap in all seven phases.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-015: AR-3 row says "0–2" where the resolution is 0 🟡 MINOR

**Dimension:** 12 (Consistency) · **Location:** `00-ambiguity-register.md:11` vs `:44–46` and `00-index.md:19–21` · **Problem:** two different expectations recorded for the same quantity; the row is stale relative to the post-spec resolution.
**Options:** single viable path — restate the row as the user's tolerance narrowly resolved to 0 by the per-lesson reasons.
**Recommendation:** update the row.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-016: "Vertical zones" vs "Horizontal Zones" terminology 🟡 MINOR

**Dimension:** 12 (Consistency) · **Location:** `03-lesson-specs.md` §Lesson 16 (`:138`, `:142`) · **Problem:** the lesson teaches horizontal strips stacked vertically; "vertical zone" reads as columns (lesson 18's geometry); the plan defines band/zone/column nowhere.
**Options:** single viable path — fix the phrase (e.g., "horizontal zones — strips stacked vertically") and add one-line definitions of band/zone/column to the shared design rules.
**Recommendation:** apply.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

---

## OBSERVATIONS

### PF-017: Lesson 12's red-baseline wording assumes index rows that do not exist yet 🔵 OBSERVATION

**Location:** `07-testing-strategy.md:105` · **Evidence:** the Part 2 index is a 5-line stub with no lesson rows; the AR-10 rebuild creates them in lesson 12's Session B. **Recommendation:** reword to "no part-index row yet (lesson 12); 'Coming Soon' row (lessons 13–18)".

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-018: AR-10 leaves the intermediate row status unspecified 🔵 OBSERVATION

**Location:** `00-ambiguity-register.md:67–69` · **Evidence:** the repo's stub convention is `🔒 Coming Soon`. **Recommendation:** state that unshipped rows read `🔒 Coming Soon` until flipped to ✅.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-019: A few AR citations do not govern the clauses they annotate 🔵 OBSERVATION

**Location:** ST-x.5 rows ("RD-02 AC 1 / AR-3") and Session B steps ("AR-3, AR-6, AR-8") · **Recommendation:** re-point to AR-10 (index), AR-8 (naming), RD-02 AC 1 (artifact set), or mark the parentheticals as reminders.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-020: ST-x.1's 4,096-byte expectation is size-blind 🔵 OBSERVATION

**Location:** all seven ST-NN.1 rows · **Evidence:** `verify.sh` compares bytes but never checks size; Part 1's ST-07.1 used "verify.sh output + file size". **Recommendation:** add "+ file size" to the evidence method.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

### PF-021: ST-12.2/12.3 assert more than their evidence shows 🔵 OBSERVATION

**Location:** ST-12.2 ("release line counted inside band 0" is not screenshot-observable), ST-12.3 ("262 lines" is shown by ST-12.4's phase map, not the loop-top constant). **Recommendation:** reword to what each method actually establishes.

**User Decision:** Resolved — user accepted recommendation (bulk decision 2026-10-10; option spelled out in §User Decisions)

---

## Iteration 2 — verification rescan

A fresh-context verifier checked all 21 resolutions against the fix commit `9d6aee1`: 16 were
fully verified; seven residuals were found — one new minor (PF-022) and six missed spots of
already-accepted resolutions (PF-003-R, PF-007-R, PF-012-R, PF-013-R, PF-017-R, PF-021-R). All
residuals were completed in the follow-up fix pass and directly verified; no critical or major
finding remained open at any point.

### PF-022: "luminance 8" is not a representable value 🟡 MINOR (new in iteration 2)

**Dimension:** 6 (Feasibility) · **Location:** `03-lesson-specs.md` §Lesson 15/§Lesson 17;
`07-testing-strategy.md` ST-15.2/ST-17.2
**Codebase Evidence:** the palette byte is `%HHHHLLL0` — luminance 0–7
(`atari-2600-expert/references/tia-hardware.md`); "luminance 8" appears nowhere in the palette.
**The Problem:** Session A could not freeze a satisfiable oracle for lessons 15/17.
**Options:** single viable path — pin luminance 7 (brightest; matches lesson 13's 7→0 start),
with the ramp listed as `$0E,$1E,…,$FE`. Rejected: luminance 0 (renders a near-black ramp —
fails the visual intent).
**Recommendation:** luminance 7 — fixed as part of PF-001's accepted resolution.

**User Decision:** Resolved — completed within PF-001's accepted recommendation (single viable option)

## Verdict

**✅ PREFLIGHT PASSED — 22 findings resolved.** All five majors were verified in iteration 2; all
minors and observations were resolved (16 verified + seven residuals completed and directly
verified). The plan is structurally sound (document set complete, register gate passed,
spec-first ordering correct, all cross-references to code verified; the frame math, band
arithmetic, timer values, and hardware claims passed independent hardware-semantics review).
Execution may proceed.
