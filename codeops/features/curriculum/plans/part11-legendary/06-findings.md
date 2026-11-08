# Lesson 79 — Findings

> **Status**: Complete — 0 critical, 0 major open. 4 major fixed; 1 accepted limitation.
> **Rule**: every finding gets a stable ID, a severity, a status, and a resolution.
> No lesson is complete with an open critical or major finding.

## 1. Summary

| Severity | Open | Fixed | Accepted | Total |
|---|---:|---:|---:|---:|
| Critical | 0 | 0 | 0 | 0 |
| Major | 0 | 4 | 0 | 4 |
| Minor | 0 | 13 | 1 | 14 |

## 2. Findings

| ID | Source | Severity | Finding | Evidence | Resolution | Status |
|---|---|---|---|---|---|---|
| SR-001 | atari2600-reviewer | 🟠 Major | Ex3's `MarkPF0` used bit 7 = chunk 0; the TIA's PF0 is bit 4 = chunk 0, so R/A were garbled | ex3 `MarkPF0`; TIA tables | Table corrected to `$00,$D0,$D0,$D0,$D0,$B0,$D0,$30`; 0/96 chunk check; RACE renders | Fixed |
| SR-002 | atari2600-reviewer | 🟠 Major | The 381/384 mark mismatch was the C column committing inside P0 copy 0 (CLK 84-91), not a scaler edge | `MarkDraw` commits; source | Kernel unrolled; C commit at write 31/CLK 93; 0/384; later margins 6/5/4 CLK | Fixed |
| SR-003 | atari2600-reviewer | 🟠 Major | The doc taught that a WSYNC written in HBLANK does not hold the CPU; false | doc tip; Lesson 12/14 | Tip corrected; the NOPs are store-position devices only; band lines unchanged | Fixed |
| SR-004 | atari2600-reviewer | 🟠 Major | The double `+set_timer` was a workaround; the second write 6 cycles later could not add 2 lines | source; doc | Single write; `StartFrame` 259/3; the old 257/3 was the old mark cleanup; the stale theory block removed | Fixed |
| SR-005 | curriculum-auditor | 🟠 Major | The auto-demo prose said the player "can always reach" and catches were 62 frames apart after the first; the log shows 63 then 188 | doc; state log | Narrative corrected: the first respawn is missed; the cadence starts at 188 | Fixed |
| N1-N4 | atari | 🟡 Minor | WYSYNC/WYINC typos; BallNext wording; ex2 ledger; ball-X not measured | doc/source | Fixed; the ball is at TIA X≈60 in `game.png` | Fixed |
| R-01-R-06 | auditor | 🟡 Minor | HitFlag excerpt; ex1/ex2 ledgers; ex2 229/5; 6 s window; auto-demo wording; 06 limitation | doc/source | Fixed; the accepted limitation is recorded below | Fixed |

## 3. Review record

| Review | Reviewer | Date | Critical | Major | Minor | Result |
|---|---|---|---:|---:|---:|---|
| Hardware/CPU | `atari2600-reviewer` | 2026-11-08 | 0 | 4 | 12 | clear after round 2 |
| Curriculum/site | `curriculum-auditor` | 2026-11-08 | 0 | 1 | 15 | clear after round 2 |

## 4. Accepted limitations

| ID | Limitation | Why accepted | User ruling |
|---|---|---|---|
| L-01 | The 0/384 mark check is against the 960×606 Stella window capture, not a native TIA framebuffer dump. | The window capture is the course's standard evidence; the host table and the 0/384 pixels agree, and no native-framebuffer tool is in the workflow. | Accepted by the lesson review |
|---|---|---|---|
| — | — | — | — |

## 5. Close-out

- [ ] All critical and major findings fixed or ruled accepted.
- [ ] All minor findings fixed or explicitly accepted.
- [ ] `bash scripts/verify.sh` passes after the fixes.
- [ ] The findings summary above is current.
