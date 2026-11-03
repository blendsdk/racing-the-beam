# Ambiguity Register: Part 3 — Playfield (Lessons 19–24)

> **Status**: ✅ GATE PASSED — all 18 items resolved
> **Last Updated**: 2026-11-03
> **Authority**: `--auto-design` active for this plan chain (policy version 1, root invocation ID `curriculum-plan-part3-2026-11-03`). AR #1 and #4 are user decisions carried from RD-03 and the course policy; AR #2, #3, #5–#18 are delegated technical decisions.

| # | Category | Ambiguity / Gap | Options Presented | Decision | Status |
|---|----------|-----------------|-------------------|----------|--------|
| 1 | Scope | Which lessons does this plan cover, and in what order? | RD-03 only (19–24) sequential / include later RDs / parallel lessons | **User (RD-03):** RD-03 only — lessons 19–24 strictly sequential; each lesson is the next one's prerequisite | ✅ Resolved |
| 2 | Technical | How is the work phased and sessioned? | One phase per lesson with Sessions A/B/C / one phase per session / one phase for all six | **AI (auto-design):** 6 phases, one per lesson; Session A freezes that lesson's ST cases, Session B implements, Session C verifies to green and hardens — the Part 1/2 ordering | ✅ Resolved |
| 3 | Scope | Which lessons need a standalone `demo-NN.asm`? | Only where needed (main ROM cannot visualize the concept) / one demo per lesson / no demos | **AI (auto-design):** only where needed; resolved for this part: **0** — each of the six main ROMs visualizes its own concept directly (reasons in [03-lesson-specs.md](03-lesson-specs.md)) | ✅ Resolved |
| 4 | Technical | What fills every task's Verify line? | `bash scripts/verify.sh` / an additional gate | **User-confirmed (course policy, Part 2 AR-4):** `bash scripts/verify.sh`; targeted Stella state-log evidence remains per-task evidence, not the gate | ✅ Resolved |
| 5 | Technical | Who reviews, and what blocks completion? | Both specialists per lesson + no critical/major / single reviewer | **AI (auto-design):** `atari2600-reviewer` and `curriculum-auditor` gate every lesson; no critical/major findings (RD-03 AC 3) | ✅ Resolved |
| 6 | Technical | What evidence standard governs the playfield timing and geometry claims? | Stella state-log breakpoints + static cycle ledgers / static reasoning only / simulator tracing | **AI (auto-design):** the Part 2 standard — labelled state-log checkpoints plus a static cycle ledger for every write position; screenshots pixel-checked against predicted geometry | ✅ Resolved |
| 7 | Technical | May the work add machinery beyond the existing pipeline? | Reuse pipeline only / add test framework or new tooling | **AI (auto-design):** reuse only — `vcs-lesson-production`, `capture-screenshot.sh`, `npm run roms`, `include/macro.asm`; no new scripts or frameworks | ✅ Resolved |
| 8 | Naming & terminology | What are the lesson folder/doc/image/ROM identifiers? | Existing slugs verbatim / new naming | **AI (auto-design):** the existing endpoints verbatim (`19-playfield-basics` … `24-multicolor-playfield`); folder/doc/image/ROM naming per the Part 1–2 convention | ✅ Resolved |
| 9 | Scope | May lessons name later-part registers and concepts (players, missiles, the ball, PFP's visible effect) they cannot yet use? | Name-only reference notes / avoid entirely / introduce early | **AI (auto-design):** name-only references marked as belonging to later parts; lesson code, exercises, and solutions use only mechanisms taught by that lesson or earlier (RD-03 AC 3; the auditor verifies) | ✅ Resolved |
| 10 | Integration points | The Part 3 index is a minimal stub; how is it integrated? | Rebuild to the Part 1 format and flip rows per lesson / leave as is / rebuild at the end | **AI (auto-design):** rebuild in the Lesson 19 phase to the Part 1 format (lesson rows + What You'll Learn); each lesson flips its own row to ✅ Complete | ✅ Resolved |
| 11 | Technical | Which video standard do the lessons target? | NTSC only / NTSC + PAL | **AI (auto-design):** NTSC only (262-line frame; playfield geometry derived from the 160-clock visible line); PAL appears as a noted aside at most | ✅ Resolved |
| 12 | Technical | Commit and record-keeping per lesson? | One atomic `feat(lessonNN)` commit + plan/ledger/roadmap updates / batch commits | **AI (auto-design):** one atomic commit per lesson via the `git-commit` skill in push mode with `Ref:`/`Task:` trailers; findings ledger, progress header, and roadmap transitions per Part 1/2 practice | ✅ Resolved |
| 13 | Technical | What is the authoritative model for a mid-line `PF0/PF1/PF2` write? | Registers are re-read for the second half; a write lands on the next 4-clock playfield pixel / registers are latched only at line start / model only by experiment | **AI (auto-design):** the TIA re-reads the playfield registers for the second half; a store's effect begins at the next instruction's cycle and is quantized to the 4-clock playfield pixel. Session C must confirm the pinned L21 write windows in Stella before the lesson is done ([03](03-lesson-specs.md) §Lesson 21) | ✅ Resolved |
| 14 | Scope | Lesson 20 must teach priority (RD-03 outcome), but `PFP`'s visible effect needs a player/ball, which belongs to Part 4 | Demonstrate `PFP` with a forward object / teach the bit and defer its visible effect / omit priority | **AI (auto-design):** demonstrate `COLUPF` and score mode (both observable now); teach the full priority table and the `PFP` bit with an explicit name-only note that its visible effect arrives with players/ball in Part 4. No forward-mechanism code (AR-9) | ✅ Resolved |
| 15 | Technical | What kernel and data layout realizes the data-driven playfield? | 1-line kernel, 192 rows, interleaved rows / 2-line kernel, 96 rows, parallel tables / one table per object | **AI (auto-design):** 1-line kernel, 192 rows, one interleaved row table per level (`PF0,PF1,PF2` per row), read through three zero-page pointers offset by 0/1/2 and indexed by `Y = row × 3`; full vertical resolution, 576 bytes per level, and the load/store budget fits the line with the prefetch | ✅ Resolved |
| 16 | Technical | How is the multicolor playfield driven? | 192-byte per-line color table / computed band index per line / mid-line color writes | **AI (auto-design):** a 192-byte per-line `COLUPF` table read through a zero-page pointer; two tables (rainbow and region colors) switched once per frame in VBLANK | ✅ Resolved |
| 17 | Technical | How does the animation lesson animate without per-line data? | Frame-level pattern states / per-line data animation / mid-line rewrites | **AI (auto-design):** a frame-level symmetric gate: 9 `PF2` states (closed → fully open), one step every 30 frames, direction reversal at both ends; the visible kernel holds the registers, so only VBLANK changes state | ✅ Resolved |
| 18 | Technical | How are the first line and the per-line phase kept artifact-free? | Phase-matched release (5-cycle equivalent) / accept a first-line artifact / blank the first line | **AI (auto-design):** the release (`LDA #$00` + `STA VBLANK`, 5 cycles) matches the steady-state wake so the first visible line shares the kernel's phase; each kernel's ledger states its first-line entry | ✅ Resolved |

### Resolution Notes

**Shared delegated provenance (AR #2, #3, #5–#18).** Authority: AI — delegated by `--auto-design`.
Eligibility: implementation mechanisms and within-scope interpretations inside the confirmed RD-03
scope (lessons 19–24, existing pipeline). Objective: ship Part 3 at the Part 1/2 quality bar.
Evidence: the executed Part 1 and Part 2 plans, the verified `scripts/verify.sh` /
`npm run roms` / `scripts/capture-screenshot.sh` pipeline, the `atari-2600-expert` references
(`tia-hardware.md` playfield bit order and priority table; `kernels.md` asymmetric-playfield and
2-line-kernel patterns), and `include/vcs.asm`. Rejected alternatives: heavier options (new
tooling, 1-line kernels everywhere, forward sprite code) add machinery or break the didactic
boundary without improving verifiability. Strongest counterargument: the mid-line playfield model
(AR-13) is the part's highest-risk claim; answered by pinning the windows and requiring Stella
confirmation before Lesson 21 counts as done. Confidence: High for scope and pipeline; Med-High for
the L21 timing until measured. Hardening: not required beyond the L21 measurement gate — the
decisions are reversible inside existing pipeline patterns. Policy version: 1. Root invocation ID:
`curriculum-plan-part3-2026-11-03`. Reopen triggers: RD-03 changes; the pipeline or specialists
change; a lesson's concept cannot be expressed under one of these decisions; the L21 measurement
contradicts the playfield re-read model.

**AR-1.** Decision: RD-03 only — lessons 19–24, strictly sequential. Evidence:
`codeops/features/curriculum/requirements/RD-03-part3-playfield.md` (lesson list and dependencies);
RD-02 is Done, so the preflight dependency is satisfied.

**AR-3.** Decision: no standalone demos. Reasons: L19 — the register layout and REF/REPEAT are the
visible picture; L20 — the color split is the visible picture; L21 — the asymmetric halves are the
visible picture; L22 — the gate animation is the visible picture; L23 — the maze levels are the
visible picture; L24 — the rainbow is the visible picture. Reopen trigger: a Session B
implementation proves a concept is not screen-observable.

**AR-4.** Decision (user-confirmed): `bash scripts/verify.sh` is the single gate command (detected
from `AGENTS.md`; used through Parts 1–2).

**AR-6.** Decision: playfield timing and geometry claims use the Part 2 evidence method — a
`stella -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'` state log at labelled checkpoints, plus a
static cycle ledger; screenshots are pixel-checked against predicted boundaries. Scratch witnesses
are allowed only to provoke what-if states, never to produce lesson screenshots.

**AR-9.** Decision: lessons may name later-part objects (players, missiles, ball) as explicit
context notes marked for later parts; lesson code, exercises, and solutions use only mechanisms
taught by that lesson or earlier. The `curriculum-auditor` verifies this boundary per lesson.

**AR-10.** Decision: rebuild `docs/part3-playfield/index.md` to the Part 1 format during the
Lesson 19 phase; each lesson flips its own row to ✅ Complete with a link; unshipped rows read
`🔒 Coming Soon`.

**AR-12.** Decision: one atomic commit per lesson — `feat(lessonNN): <Lesson title>` via the
`git-commit` skill in push mode with `Ref:`/`Task:` trailers; findings ledger, progress header,
and roadmap transitions per ruling batch and task. RD-03 moves to `Plan Created` now and `Done`
when all six lessons ship.

**AR-13.** Decision: the TIA re-reads `PF0/PF1/PF2` for the second half of the line; a store's
effect begins at the cycle of the next instruction and is quantized to the 4-clock playfield pixel.
Evidence: `atari-2600-expert/references/kernels.md` §Asymmetric playfield ("rewrite PF0/PF1/PF2
during the scanline after the left half has been consumed and before the beam reaches the right
half"); `tia-hardware.md` (each playfield pixel = 4 color clocks; 20 bits per half). The L21 spec
pins the write windows with margins; Session C must confirm them in Stella. Reopen trigger: a
measured right-half write lands in the wrong half or the left half changes.

**AR-14.** Decision: Lesson 20 demonstrates `COLUPF` and score mode, teaches the priority table,
and explains that `PFP`'s visible effect needs a player/ball (Part 4). No forward object code.
Reopen trigger: the user requires an observable `PFP` demo inside Part 3.

**AR-15.** Decision: Lesson 23 uses a 1-line kernel with 192 rows and one interleaved row table per
level (`PF0, PF1, PF2` per row), read through three zero-page pointers offset by 0/1/2 with
`Y = row × 3`. Evidence: `kernels.md` §The 1-line kernel pattern (192 bytes of data, maximum
vertical detail); the pinned ledger (18 store cycles + 24 prefetch + 11 loop control + 3 WSYNC =
56 of 76) leaves headroom, and 576 bytes per level fit the 4K ROM. Reopen trigger: the load/store
sequence overruns the line, or the two-level data plus code exceeds 4,096 bytes.

**AR-16.** Decision: Lesson 24 uses a 192-byte per-line `COLUPF` table read through a zero-page
pointer; two tables (rainbow and region colors) switched in VBLANK. Evidence: Part 2's per-line
color writes (Lessons 16–18) and the 192-line visible area. Reopen trigger: the table read does not
fit the line budget.

**AR-17.** Decision: Lesson 22 animates a symmetric gate at the frame level: 9 `PF2` states, one
step every 30 frames, reversal at both ends. Evidence: the playfield registers are persistent
across lines; a frame-level update needs no per-line writes. Reopen trigger: the frozen 30-frame
cadence is not observable in captures, or the gate states do not read clearly.

**AR-18.** Decision: the release's 5 cycles match the steady-state wake, so the first visible line
shares the kernel's phase. Evidence: Lesson 18's measured phase-match; each Part 3 kernel's ledger
will state its own entry arithmetic.
