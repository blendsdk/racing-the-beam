# Findings Ledger: Part 3 — Playfield (Lessons 19–24)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Phase 1 complete — 0 critical, 0 major open

One row per finding. Severity follows the quality profile: 🔴 CRITICAL / 🟠 MAJOR / 🟡 MINOR /
ℹ️ INFO. Duplicate observations raised by both specialists share one row (both IDs noted).

| ID | Phase | Severity | Finding | Resolution |
|----|-------|----------|---------|------------|
| SR-101 | 1 | 🟠 MAJOR | Both reviewers: the `CtrlWrite` documentation said "one hit per state flip", but the label sits after the every-frame `STA CTRLPF`, so it hits once per **frame** (696 hits in 696 frames; A = `$01` frames 1–119, `$00` 120–239) | fixed — doc, spec, ST-19.4, and Session A record now state one hit per frame with the frame spans |
| SR-102 | 1 | 🟠 MAJOR | Both reviewers: the source header still described the pre-correction picture ("dark gap in the middle", "gap disappears") while the ROM draws a green centre block (chunks 16–23 reflect, 16–25 repeat) | fixed — header rewritten to the measured geometry; doc Full Source re-injected verbatim |
| SR-103 | 1 | 🟠 MAJOR | Curriculum auditor: exercise 1's `STA PF2` comment said `$0F` displays as `00001111`; bit 0 is leftmost, so `$0F` displays as `11110000` | fixed — comment corrected to `11110000 (bit 0 first)` |
| SR-104 | 1 | 🟡 MINOR | Curriculum auditor: page title "Playfield Basics — Racing the Beam" did not match the index/stub title "Playfield Basics — PF0, PF1, PF2" | fixed — frontmatter and H1 aligned to the indexed title |
| SR-105 | 1 | 🟡 MINOR | Both: the spec and execution plan still said exercise 1's "central gap becomes a solid block" after the geometry correction | fixed — "green centre block becomes dark and the dark bands become green" |
| SR-106 | 1 | 🟡 MINOR | Curriculum auditor: exercise 3's header listed patterns (checker, gates) that are not in `PatternTable` | fixed — header now describes the eight shipped triples |
| SR-107 | 1 | 🟡 MINOR | Re-review: the source header said a chunk is "six screen pixels"; a chunk is 24 px (six per color clock) | fixed — "24 screen pixels — six per color clock"; doc re-injected |
| SR-108 | 1 | 🟡 MINOR | Both (re-review): "the dark bands move outward" implied both sides move; in repeat mode only the right-hand band moves and the left half is unchanged | fixed in the source header, spec, and doc |
| SR-109 | 1 | 🟡 MINOR | Re-review: three exercise-3 labels did not match their bytes ("heavy left edge", "heavy center", "wide bars") | fixed — "inset edges", "split centre (gate)", "sparse bars", matching the table comments |
| SR-110 | 1 | 🟡 MINOR | Both (re-review): the release was described as "line 37 cycle 0" and the hold loop as "in phase"; the `STA VBLANK` write lands at cycle 4 and the first store at cycle 7 | fixed — both numbers stated; the hold-kernel note explains why the 2-cycle difference is invisible |
| SR-111 | 1 | 🟡 MINOR | Curriculum auditor (re-review): the plan header still read 0/6 (0%) and 12:00 while task 1.1.1 was `[~]` | fixed — header now 1/6 (17%) and 22:54 |
| SR-112 | 1 | ℹ️ INFO | Session B caught the PF2 bit-order error before review (the spec's first draft read `$F0` as `11110000` on screen) | recorded — spec/ST/Session A/source/doc corrected to the measured `00001111`; disclosed to both reviewers |
| SR-113 | 2 | 🟡 MINOR | Both reviewers: exercise 3's header advertised a `VisibleStart (37)` checkpoint but the file defined no such label | fixed — `VisibleStart:` added before the 96-line split; the checkpoint set matches the other sources |
| SR-114 | 2 | 🟡 MINOR | Curriculum auditor: the gap range "x = 457–553" reads as 97 px under the course's inclusive convention; the gap is 96 px (four chunks) | fixed — "x = 457–552 (96 px)", with the color transitions at 457 and 553; source/doc strings aligned |
| SR-115 | 2 | 🟡 MINOR | Curriculum auditor: the TypeScript lead-in said the snippet makes "the priority order explicit", but it models only the score-mode color decision | fixed — "makes the score-mode decision explicit" |
| SR-116 | 2 | 🟡 MINOR | Curriculum auditor: the spec said exercise 3 switches "at line 96 by a per-line branch"; the shipped solution splits after 96 visible lines (scanline 133) with two counted loops | fixed — spec now states scanline 133, the HBLANK `CTRLPF` write, and the two loops |
| SR-117 | 2 | 🟡 MINOR | Curriculum auditor: the plan header still read 22:54 while task 2.1.1 was implemented at 23:02 | fixed — header advanced with each task; now 2/6 (33%) at 23:08 |
| SR-118 | 2 | ℹ️ INFO | `single-color.png` shows Stella's launch toast in the black band below the picture (the picture itself is clean) | accepted — does not cover the picture; the same artifact appears in Lesson 19's capture |
