# Ambiguity Register: Curriculum

> **Status**: ✅ GATE PASSED — all 9 items resolved
> **Last Updated**: 2026-10-10
> **Authority**: `--auto-design` active for this requirements chain (policy version 1, root invocation ID `curriculum-reqs-2026-10-10`). AR #1 is a user decision; AR #2–#9 are delegated technical decisions.

| # | Category | Ambiguity / Gap | Options Presented | User Decision | Status |
|---|----------|-----------------|-------------------|---------------|--------|
| 1 | Scope | May lessons or parts be added, removed, renamed, or reordered? | Freeze the structure / allow restructuring | **User:** curriculum frozen — deliver the existing 78-lesson structure; structural changes are out of scope | ✅ Resolved |
| 2 | Technical | How is the remaining lesson work modeled in CodeOps? | One feature `curriculum` / task-lane backlog rows | **AI (auto-design):** one feature `curriculum` covering Parts 1–11 | ✅ Resolved |
| 3 | Technical | RD granularity for the feature. | One RD per part / one mega-RD / one RD per lesson | **AI (auto-design):** one RD per part — RD-01..RD-11 | ✅ Resolved |
| 4 | Technical | Plan and task granularity. | One plan per RD + one task per lesson / one feature-level plan / one task per RD | **AI (auto-design):** one plan per RD, one task per lesson; RD-01 plans first | ✅ Resolved |
| 5 | Technical | What is the per-lesson definition of done? | Five hard rules + `verify.sh` + independent reviews / lighter spot checks | **AI (auto-design):** full gate — five hard rules, green `scripts/verify.sh`, reviewer and auditor sign-off | ✅ Resolved |
| 6 | Technical | What accuracy standard governs technical claims? | `atari-2600-expert` claim discipline with `include/vcs.asm` ground truth / free-form prose | **AI (auto-design):** observed/documented/derived claims; `include/vcs.asm` wins on registers and bits | ✅ Resolved |
| 7 | Technical | How are Stella screenshots produced? | Local Stella 7.0 (live display, xvfb fallback) via `scripts/capture-screenshot.sh` / browser-based capture | **AI (auto-design):** local Stella via the existing script | ✅ Resolved |
| 8 | Technical | How are Part 11 legendary techniques sourced? | Source-cited mechanism research before authoring / author from memory | **AI (auto-design):** research first; recorded as a dependency, not scope expansion | ✅ Resolved |
| 9 | Technical | How is the AGPL-3.0 Javatari bundle handled? | Ship unmodified with vendored license and attribution / modify the bundle / drop the player | **AI (auto-design):** ship unmodified; license stays at `docs/public/javatari/license.txt` | ✅ Resolved |

### Resolution Notes

**Shared delegated provenance (AR #2–#9).** Authority: AI — delegated by `--auto-design`.
Eligibility: implementation mechanisms inside the confirmed frozen-curriculum scope. Objective:
deliver lessons 07–78 at the established quality bar. Policy version: 1. Root invocation ID:
`curriculum-reqs-2026-10-10`. Hardening: not required — low-risk, reversible choices inside an
existing pipeline.

**AR-1.** Decision: keep the 78-lesson structure frozen. Evidence: `README.md` curriculum table;
the project rules in `AGENTS.md`. Rejected alternative: restructuring the course (contradicts the
user's decision). Reopen trigger: the user requests a curriculum change.

**AR-2.** Decision: one feature `curriculum` over Parts 1–11. Evidence: the parts share one
production pipeline (`vcs-lesson-production`), one verification gate (`scripts/verify.sh`), and
long-running quality gates, so the work is cohesive feature work. Rejected alternative: task-lane
rows (no cohesive outcome, no gate alignment). Strongest counterargument: 72 lessons are
long-running and could be tracked as independent tasks; answered by the shared requirements and
gates. Confidence: High. Reopen trigger: lessons split into independent pipelines.

**AR-3.** Decision: one RD per part. Evidence: the curriculum already defines Parts 0–11 as the
course's structure; plans and progress then read per part. Rejected alternatives: one mega-RD
(poor progress granularity), one RD per lesson (excessive ceremony). Confidence: High. Reopen
trigger: a part stops sharing one outcome set.

**AR-4.** Decision: one plan per RD and one task per lesson, starting with RD-01. Evidence: an
RD holds at most 10 lessons, which fits one planning pass; per-lesson tasks match the one-lesson
atomic-commit rule. Rejected alternatives: one plan for all remaining lessons (unreviewable),
one task per RD (too coarse for verification). Confidence: High. Reopen trigger: a lesson grows
into multiple independent deliverables.

**AR-5.** Decision: a lesson is done only when the five hard rules and the `vcs-lesson-production`
checklists pass, `bash scripts/verify.sh` is green, and both specialist reviews report no
critical/major findings. Rejected alternative: lighter spot checks (conflict with the user's
quality mandate). Confidence: High. Reopen trigger: the user relaxes the quality bar.

**AR-6.** Decision: non-obvious claims are observed, documented, or derived; `include/vcs.asm` is
the ground truth for register addresses and bits. Rejected alternative: free-form prose without
sources. Confidence: High. Reopen trigger: the ground-truth file moves or changes.

**AR-7.** Decision: capture with local Stella 7.0 through `scripts/capture-screenshot.sh` (live
display, xvfb fallback), verified end-to-end in this repository. Rejected alternative:
browser-based capture (new machinery for no added value). Confidence: High. Reopen trigger: the
script or Stella stops working headless.

**AR-8.** Decision: Part 11 lessons start with source-cited mechanism research before authoring;
the research is a dependency of those tasks, not new scope. Evidence:
`atari-2600-expert/references/legendary.md` and `references/sources.md`. Rejected alternative:
authoring from memory (unverifiable claims). Confidence: Med — some legendary effects have thin
public documentation. Reopen trigger: sources are unavailable or contradictory.

**AR-9.** Decision: the Javatari player ships unmodified with its AGPL-3.0 license vendored at
`docs/public/javatari/license.txt` and attribution in `README.md` and `THIRD-PARTY-NOTICES.md`.
Rejected alternatives: modifying the bundle (license risk), dropping the player (loses the
in-browser experience). Confidence: High. Reopen trigger: the bundle or its license changes.
