# Lesson 79 — Preflight Report

> **Status**: Draft preflight — re-run at Session A at the current HEAD (after the
> plan-adoption commit `d7a952a`).
> **Rule**: Any gap is a hard stop. Do not write lesson content around a gap.

## 1. Prerequisites coverage

| Prerequisite | What Lesson 79 uses | Covered? |
|---|---|---|
| Lesson 17 — cycle counting | `LDA abs,Y` is 4 cycles, +1 on a page cross; the mark table is page-aligned | ✅ |
| Lesson 19 — playfield basics | PF0/PF1/PF2, `CTRLPF`, `COLUPF` for the play bands | ✅ |
| Lesson 21 — asymmetric playfield | Exercise 3 draws the mark with PF bytes in SCORE mode | ✅ |
| Lesson 23 — data-driven playfield | Exercise 3’s 3-byte-per-row mark table | ✅ |
| Lesson 26 — horizontal positioning | `RESPx`/`HMPx`/`HMOVE`; X=16/24; the `+3` bias | ✅ |
| Lesson 31 — copies and sizes | `NUSIZ=3` for the 48-pixel block; `NUSIZ=0` for the play (one copy) | ✅ |
| Lesson 32 — vertical delay | VDEL for the 48-pixel kernel; clearing it for the play | ✅ |
| Lesson 39 — the scoreboard | The 48-pixel trick, `ScoreSetup`/`ScoreDraw`, the 9-line kernel, the 48-byte buffer | ✅ |
| Lesson 50 — multi-zone kernel | Zones, line budget, the second HMOVE, the 24-cycle rule, the handover | ✅ |
| Lesson 55 — scrolling text marquee | The 48-pixel window as a text display; the Activision history note | ✅ |
| Lesson 38 — collision detection | `CXP0FB` latch and the one-frame hit delay | ✅ |
| Lesson 42 / 47 / 63 | Joystick, SELECT edge, auto-demo pattern | ✅ |

**No forward references.** Every mechanism used by Lesson 79 appears in an earlier
lesson. The new material is the composition: a second 48-pixel window in the same
frame, a second handover, and a ROM table instead of a RAM buffer.

## 2. Technical claims to verify

| Claim | Basis | Verification |
|---|---|---|
| P0 at X, P1 at X+8, three close copies each, make a 48-pixel block | Lesson 39 geometry | Static table + capture |
| The score block at X=56/64 spans X=56–103 | Lesson 39 | Pixel check |
| The mark block at X=16/24 spans X=16–63 | Same geometry, shifted 40 px left | Pixel check |
| `ScoreDraw` consumes nine visible lines | `include/score.asm` | State log + frame |
| A `MarkDraw` clone has the same cycle count when the table is page-aligned | Lesson 17 + `ScoreDraw` ledger | Static ledger + state log |
| Three HMOVEs can share one frame when each is in a blank HBLANK | Lesson 50 two-HMOVE pattern | State log at each boundary |
| The 24-cycle rule forbids motion writes after an HMOVE | TIA documentation / Lesson 50 | Code inspection + state log |
| `CXP0FB` reports the previous frame’s P0–ball overlap | Lessons 38/50 | Hit log |
| SELECT is `SWCHB` bit 1 and is active low | Course convention | Input log |
| 9 + 5 + 164 + 5 + 9 = 192 visible lines | Arithmetic | Frame measurement |

## 3. Screenshot plan

| Capture | Frame/time | Content | Check |
|---|---|---|---|
| `game.png` | ~2 s | Score, play field, gold `RACING` mark at bottom-left | Mark block X=16–63, rows 184–190; score X=56–103, rows 1–7 |
| `no-mark.png` | ~6 s | The same screen with the mark hidden | Mark band blank; score/play unchanged |

Both: 1010×807, title bar `Stella 7.0: "79-publisher-mark"`, no cursor, captured from
the committed ROM. The auto-demo scripts the SELECT toggle; no external input is
needed. Session C records the exact capture rectangle and the frame numbers.

## 4. Budgets

| Resource | Budget | Plan |
|---|---|---|
| Visible lines | 192 | 9 + 5 + 164 + 5 + 9 |
| ROM | 4,096 | 48-byte mark table, 80-byte score font, code, vectors |
| RAM | 128 bytes | `$80–$8F` game, `$90–$9F` free, `$A0–$D7` score library, `$D8–$F7` free, stack `$F8–$FF` |
| Cycles per line | 76 | Score/mark kernels follow Lesson 39; play is 2-line; positioner/handover are 2 lines per object |
| HMOVEs per frame | 3 | Score (VBLANK), game (top positioner), mark (handover); all in blank HBLANKs |

## 5. Trademark and licensing

- The artifact uses **RACING**, an original course mark.
- The lesson discusses Activision’s historical practice and the 48-pixel trick, but
  does not reproduce the Activision wordmark, logo, or any copyrighted screen.
- Lesson 63 already states the rule: a release uses its own name and artwork; Atari’s
  (and Activision’s) trademarks are not the homebrew author’s to use.
- The doc may use “Activision” nominatively in the history section, as Lesson 55 does.

## 6. Gaps

| Gap | Status |
|---|---|
| No dedicated lesson for a static in-game mark | **This lesson closes it.** |
| The score library hard-codes 56/64 | The lesson copies the setup for the mark; no shared-library change. |
| The Part 11 index is a “Coming Soon” page | The lesson rebuilds it to the standard part index with 79 ✅ and 73–78 🔮. |
| Lessons 73–78 have no pages | 79’s `prev` points to the Part 11 index; no `next`; the index lists 73–78 as coming soon. |
| The 78-lesson freeze | The user’s 2026-11-08 authorization amends it to 79; AR-1 and AGENTS.md must record it. |

No unresolved technical gap. If Session A finds one, stop and update this report.

## 7. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| The 5-line top positioner/handover is too tight | Medium | Reuse the Lesson 50 routines; measure; reduce the play zone if needed (keep 192 total) |
| Three HMOVEs disturb the score or mark | Medium | Each in a blank HBLANK; clear stale motion registers; state-log every boundary |
| `MarkBuf` page cross | Medium | `!align 255,0`; static check; the table is 48 bytes |
| 4K ROM overflow | Low | Mark table in ROM; no sound; simple play field |
| The mark is hard to read at 5×7 | Low | Use a bold 5×7 font; gold on a dark field; capture and inspect |
| The ball shares `COLUPF`, so it can blend into the ground band | Low | Keep the sky mostly PF-off while the ball falls; document the trade-off; the catch is at the player’s head |
| The auto-demo toggle is not deterministic | Low | Frame-scripted `ToggleMark`; record the frames; captures from the committed ROM |
| The curriculum amendment conflicts with the other session | High | Wait for the Part 10 completion commit and a clean tree; no repo writes before then |

## 8. Preflight verdict

**PASS for planning.** Session A must re-run this checklist at the Part 10 completion
commit. Any new gap is a hard stop.
