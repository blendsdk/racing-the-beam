# Ambiguity Register: Part 4 — Sprites (Lessons 25–34)

> **Status**: ✅ GATE PASSED — all 20 items resolved
> **Last Updated**: 2026-11-04
> **Authority**: `--auto-design` active for this plan chain (policy version 1, root invocation ID
> `curriculum-plan-part4-2026-11-04`). AR #1 and #4 are user decisions carried from RD-04 and the
> course policy; AR #2, #3, #5–#20 are delegated technical decisions.

| # | Category | Ambiguity / Gap | Options Presented | Decision | Status |
|---|----------|-----------------|-------------------|----------|--------|
| 1 | Scope | Which lessons does this plan cover, and in what order? | RD-04 only (25–34) sequential / include later RDs / parallel lessons | **User (RD-04):** RD-04 only — lessons 25–34 strictly sequential; each lesson is the next one's prerequisite | ✅ Resolved |
| 2 | Technical | How is the work phased and sessioned? | One phase per lesson with Sessions A/B/C / one phase per session / one phase for all ten | **AI (auto-design):** 10 phases, one per lesson; Session A freezes that lesson's ST cases, Session B implements, Session C verifies to green and hardens — the Part 1–3 ordering | ✅ Resolved |
| 3 | Scope | Which lessons need a standalone `demo-NN.asm`? | Only where needed / one demo per lesson / no demos | **AI (auto-design):** only where needed; resolved for this part: **0** — each of the ten main ROMs visualizes its own concept directly (reasons in [03-lesson-specs.md](03-lesson-specs.md)) | ✅ Resolved |
| 4 | Technical | What fills every task's Verify line? | `bash scripts/verify.sh` / an additional gate | **User-confirmed (course policy, Part 2 AR-4 / Part 3 AR-4):** `bash scripts/verify.sh`; targeted Stella state-log evidence remains per-task evidence, not the gate | ✅ Resolved |
| 5 | Technical | Who reviews, and what blocks completion? | Both specialists per lesson + no critical/major / single reviewer | **AI (auto-design):** `atari2600-reviewer` and `curriculum-auditor` gate every lesson; no critical/major findings (RD-04 AC 3) | ✅ Resolved |
| 6 | Technical | What evidence standard governs sprite positioning, timing, and collision claims? | Stella state-log breakpoints + static cycle ledgers / static reasoning only / simulator tracing | **AI (auto-design):** the Part 2/3 standard — labelled state-log checkpoints plus a static cycle ledger for every write position; screenshots pixel-checked against predicted geometry | ✅ Resolved |
| 7 | Technical | May the work add machinery beyond the existing pipeline? | Reuse pipeline only / add a test framework or new tooling | **AI (auto-design):** reuse only — `vcs-lesson-production`, `capture-screenshot.sh`, `npm run roms`, `include/macro.asm`; no new scripts or frameworks | ✅ Resolved |
| 8 | Naming & terminology | What are the lesson folder/doc/image/ROM identifiers? | Existing slugs verbatim / new naming | **AI (auto-design):** the existing endpoints verbatim (`25-player-basics` … `34-sprite-animation`); folder/doc/image/ROM naming per the Part 1–3 convention | ✅ Resolved |
| 9 | Scope | May lessons name later-part mechanisms they cannot yet use? | Name-only reference notes / avoid entirely / introduce early | **AI (auto-design):** name-only references marked as belonging to later parts; lesson code, exercises, and solutions use only mechanisms taught by that lesson or earlier (RD-04 AC 3; the auditor verifies) | ✅ Resolved |
| 10 | Integration points | The Part 4 index is a minimal stub; how is it integrated? | Rebuild to the Part 1 format and flip rows per lesson / leave as is / rebuild at the end | **AI (auto-design):** rebuild in the Lesson 25 phase to the Part 1 format (lesson rows + What You'll Learn); each lesson flips its own row to ✅ Complete | ✅ Resolved |
| 11 | Technical | Which video standard do the lessons target? | NTSC only / NTSC + PAL | **AI (auto-design):** NTSC only (262-line frame; sprite positions derived from the 160-clock visible line); PAL appears as a noted aside at most | ✅ Resolved |
| 12 | Technical | Commit and record-keeping per lesson? | One atomic `feat(lessonNN)` commit + plan/ledger/roadmap updates / batch commits | **AI (auto-design):** one atomic commit per lesson via the `git-commit` skill in push mode with `Ref:`/`Task:` trailers; findings ledger, progress header, and roadmap transitions per Part 1–3 practice | ✅ Resolved |
| 13 | Technical | Which horizontal-positioning routine do the lessons teach and use? | Classic divide-by-15 `SetHorizPos` / hand-padded `RESxx` strobes only / HMOVE-only positioning | **AI (auto-design):** the classic divide-by-15 routine (`STA WSYNC`, `SEC`, `SBC #15`/`BCS`, `EOR #7`, `ASL`×4, `STA HMPx`, `STA RESxx`, `STA WSYNC`, `STA HMOVE`); the measured sprite X is authoritative, and each lesson pins the measured offset for its object. Players, missiles, and the ball have different output delays and are measured separately. **Lesson 25 uses a fixed coarse delay** (a counted `DEX`/`BNE` pad plus one `STA RESP0`) to place its sprite, explicitly marked as a placeholder; the divide-by-15 routine arrives in Lesson 26 | ✅ Resolved |
| 14 | Technical | How are sprites given vertical extent? | Counted top/body/bottom loops writing the graphic each body line / 192-byte column tables / 2-line kernels | **AI (auto-design):** counted top/body/bottom loops; the body writes the graphic then `WSYNC`; constants pin the sprite's first visible scanline; the body's write positions are ledgers. No 192-byte column tables | ✅ Resolved |
| 15 | Technical | What does Lesson 27's movement ROM do with no joystick input? | Auto-bounce patrol that the joystick overrides / frozen sprite with no input / require input to show anything | **AI (auto-design):** auto-bounce patrol (velocity ±1, bounds 16–144), left/right override direction each frame; the ROM is self-demonstrating in captures and responds to the joystick in Stella | ✅ Resolved |
| 16 | Technical | How does Lesson 30 make one sprite multi-colored? | Per-line `COLUP0` table over a 16-row shape / overlay two players / missile accents | **AI (auto-design):** a 16-byte per-line `COLUP0` table over a 16-row shape: hat band, body band, leg band; no overlay and no forward object trick | ✅ Resolved |
| 17 | Technical | How does Lesson 31 show all NUSIZ player modes? | Eight static bands, one per NUSIZ value / animate one sprite through the values / two players side by side | **AI (auto-design):** eight 24-line bands, each setting `NUSIZ0` to one value 0–7 and drawing the same pattern; one capture shows every copy/size mode, and a state log pins the band boundaries | ✅ Resolved |
| 18 | Technical | How is vertical delay made visible in Lesson 32? | Two identical players, one with VDEL enabled, measured one line apart / animate a sprite with VDEL / 48-pixel trick implementation | **AI (auto-design):** two identical 16-row players at the same top line; P1 has `VDELP1` set; the capture and state log show P1 one scanline lower. The 48-pixel technique is explained as name-only context, not implemented | ✅ Resolved |
| 19 | Technical | What does Lesson 33's ROM display, and how does it read the controllers? | Controller monitor: paddle needle, SWCHA columns, fire indicator / Pong-style paddle game / name-only controller reading | **AI (auto-design):** a controller monitor: paddle 0's charge time positions a player needle (clamped), the eight `SWCHA` bits drive eight playfield columns, and the `INPT4` fire state colors a player block. The paddle read uses the standard discharge/charge sequence with a timeout so a missing paddle cannot hang the ROM; no synthetic input | ✅ Resolved |
| 20 | Technical | What animation model does Lesson 34 use? | Four 16-row walk frames stepped every 8 frames / a single shape moved horizontally / a state machine with idle and walk | **AI (auto-design):** four 16-row walk frames in a 64-byte table, stepped every 8 frames, with the frame base pointer computed in VBLANK; a direction flip every 120 frames shows the mirrored walk. Idle/walk state machines are explained as the next step, not implemented | ✅ Resolved |

### Resolution Notes

**Shared delegated provenance (AR #2, #3, #5–#20).** Authority: AI — delegated by `--auto-design`.
Eligibility: implementation mechanisms and within-scope interpretations inside the confirmed RD-04
scope (lessons 25–34, existing pipeline). Objective: ship Part 4 at the Part 1–3 quality bar.
Evidence: the executed Part 1–3 plans; the verified `scripts/verify.sh` / `npm run roms` /
`scripts/capture-screenshot.sh` pipeline; the `atari-2600-expert` references (`tia-hardware.md`
sprite table and NUSIZ/VDEL semantics; `sprite-tricks.md` §The classic SetHorizPos routine,
§Multicolor sprites, §VDEL; `kernels.md`); `include/vcs.asm` (`RESP0 $10`, `GRP0 $1B`,
`HMP0 $20`, `VDELP0 $25`, `HMOVE $2A`, `SWCHA $0280`). Rejected alternatives: heavier options
(flicker multiplexing, the 48-pixel trick, a full Pong game) add machinery or break the didactic
boundary without improving verifiability. Strongest counterargument: horizontal positioning is the
part's highest-risk claim because the divide-by-15 routine's landing depends on output delays;
answered by requiring a measured position per lesson before that lesson is done. Confidence: High
for pipeline and structure; Med-High for exact sprite X until measured. Hardening: not required
beyond the per-lesson measurement gate — every decision is reversible inside existing pipeline
patterns. Policy version: 1. Root invocation ID: `curriculum-plan-part4-2026-11-04`. Reopen
triggers: RD-04 changes; the pipeline or specialists change; a lesson's concept cannot be expressed
under one of these decisions; a measured sprite position contradicts AR-13's routine.

**AR-1.** Decision: RD-04 only — lessons 25–34, strictly sequential. Evidence:
`codeops/features/curriculum/requirements/RD-04-part4-sprites.md` (lesson list and dependencies);
RD-03 is Done, so the preflight dependency is satisfied.

**AR-3.** Decision: no standalone demos. Reasons: L25 — the first sprite is the visible picture;
L26 — the sprite moving among ruler marks is the visible picture; L27 — the patrolling sprite is
the visible picture; L28 — two differently colored players are the visible picture; L29 — the
missiles and ball are the visible picture; L30 — the color bands are the visible picture; L31 — the
eight NUSIZ bands are the visible picture; L32 — the one-line VDEL offset is the visible picture;
L33 — the controller monitor is the visible picture; L34 — the walk cycle is the visible picture.
Reopen trigger: a Session B implementation proves a concept is not screen-observable.

**AR-4.** Decision (user-confirmed): `bash scripts/verify.sh` is the single gate command (detected
from `AGENTS.md`; used through Parts 1–3).

**AR-6.** Decision: sprite timing and geometry claims use the Part 2/3 evidence method — a
`stella -dbg.logbreaks 1 -logtoconsole 1 -break '$addr'` state log at labelled checkpoints, plus a
static cycle ledger; screenshots are pixel-checked against predicted boundaries. Scratch witnesses
are allowed only to provoke what-if states, never to produce lesson screenshots.

**AR-9.** Decision: lessons may name later mechanisms (HMOVE comb, flicker multiplexing, the
48-pixel trick) as explicit context notes marked for later parts; lesson code, exercises, and
solutions use only mechanisms taught by that lesson or earlier. The `curriculum-auditor` verifies
this boundary per lesson.

**AR-10.** Decision: rebuild `docs/part4-sprites/index.md` to the Part 1 format during the Lesson 25
phase; each lesson flips its own row to ✅ Complete with a link; unshipped rows read
`🔒 Coming Soon`.

**AR-12.** Decision: one atomic commit per lesson — `feat(lessonNN): <Lesson title>` via the
`git-commit` skill in push mode with `Ref:`/`Task:` trailers; findings ledger, progress header,
and roadmap transitions per ruling batch and task. RD-04 moves to `Plan Created` now and `Done`
when all ten lessons ship.

**AR-13.** Decision: the classic divide-by-15 `SetHorizPos` routine is the positioning mechanism;
its landing depends on the object's output delay, so the lesson pins the measured X (state log plus
capture) rather than a formula-only claim. Evidence: `sprite-tricks.md` §The classic SetHorizPos
routine; `tia-hardware.md` (players ≈ 5 clocks, missiles/ball ≈ 4). Reopen trigger: the measured
sprite lands more than a few pixels from the requested X and no constant tuning fixes it.

**AR-14.** Decision: counted top/body/bottom loops; the body writes the graphic then `WSYNC`; the
top constant pins the sprite's first visible scanline as 37 + top. Evidence: `kernels.md` §The
2-line kernel and §Vertical position. Reopen trigger: the body's write positions cannot be kept
ahead of the sprite's horizontal position.

**AR-15.** Decision: auto-bounce patrol with joystick override. Evidence: `tia-hardware.md` RIOT
table (SWCHA bits 4–7 for player 0; 0 = pressed). Reopen trigger: the auto-bounce makes the
joystick lesson's input path untestable or the capture states ambiguous.

**AR-19.** Decision: the paddle read is the standard discharge/charge sequence with a bounded
timeout (255 loop iterations) so a missing paddle yields a defined value and never hangs. Evidence:
`tia-hardware.md` read-register table (INPT0–3 via VBLANK bits 6–7) and `pitfalls.md` (timer/input
traps). Reopen trigger: the monitor cannot distinguish "no paddle" from a real minimum reading in a
way the lesson can explain.

**AR-20.** Decision: four walk frames, 16 rows each, stepped every 8 frames, with the frame base
pointer computed in VBLANK. Evidence: `sprite-tricks.md` (per-line graphic writes) and Part 3's
table-pointer lessons. Reopen trigger: the frame pointer setup does not fit VBLANK or the walk is
not visually distinct.
