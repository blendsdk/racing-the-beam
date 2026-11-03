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
| SR-119 | 3 | 🟡 MINOR | Both reviewers: the margin claim "roughly 30–40 clocks" was wrong; the effects at 105/138/171 are 43/26/25 clocks before the right slots | fixed — the doc states 43/26/25 (and 21–23 after the left slots) in the theory and the takeaway |
| SR-120 | 3 | 🟡 MINOR | Reviewer: the slot table was introduced as valid for "repeat or reflect mode", but the right-half order is reversed in reflect mode | fixed — the table is labeled repeat mode; the reflect order (PF2 148–180, PF1 180–212, PF0 212–228) is noted |
| SR-121 | 3 | 🟡 MINOR | Reviewer: "sampled at the start of its slot (four-clock granularity inside the slot)" mixed two models | fixed — "the value that matters for each four-clock chunk is the one present when that chunk begins; the windows use the conservative slot boundaries" |
| SR-122 | 3 | 🟡 MINOR | Both: the pattern table showed `PF2 $55` as `01010101` (byte order) while the same table used on-screen order for `$3F` | fixed — `10101010`, with the table labeled "on-screen chunk order (bit 0 first)" |
| SR-123 | 3 | 🟡 MINOR | Both: exercise 1's header said "the stripes start at x = 601"; `RIGHT1`'s bit 7 lights chunk 24, so the solid run reaches 625 | fixed — the solid right half runs to 625 and the stripes start there; hint 2 names chunk 24 |
| SR-124 | 3 | 🟡 MINOR | Both: exercise 3 said the first line of each band starts at cycle 7; the bottom band's exit `BNE` is not taken, so it starts at 6 | fixed — top 7, bottom 6, later lines 5; the inline comment says cycle 6 |
| SR-125 | 3 | 🟡 MINOR | Both: exercise 3 described the bottom right half as "solid", but `$F0/$CC/$3C` leaves four two-chunk gaps | fixed — "starts solid (505–649) then breaks into a different stripe pair" |
| SR-126 | 3 | 🟡 MINOR | Curriculum auditor: the prerequisite line credited Lesson 20 with repeat mode; repeat/reflect is Lesson 19 | fixed — Lesson 19 (registers, bit order, repeat/reflect), Lesson 20 (score mode and CTRLPF) |
| SR-127 | 3 | 🟡 MINOR | Both: the 144-px gap was written "x = 457–601", which reads as 145 px under the inclusive convention | fixed — "x = 457–600 (144 px); transitions at 457 and 601" in the doc, source, spec, ST, and Session A |
| SR-128 | 3 | 🟡 MINOR | Both: the plan's Session A pin described a "3-cycle pad" that the shipped exercise 3 does not contain | fixed — the pin now records the real first-line offsets (top 7, bottom 6, later 5) |
| SR-129 | 3 | ℹ️ INFO | The playfield read timing (slot map) is not stated in `tia-hardware.md`; the lesson derives it from the measured pixels and community documentation | accepted — the measurement is the lesson's evidence; a reference-set addition is outside this plan's modification set (strict scope) |
| SR-130 | 4 | 🟠 MAJOR | Both reviewers: the full gate cycle was documented as 9 s; the 16-step ping-pong at 30 frames is 8 s (exercise 1: 4 s, not 4.5) | fixed — 8 s / 4 s in the main header, doc, exercise 1 header, and Session A record |
| SR-131 | 4 | 🟠 MAJOR | Both reviewers: the exercise-3 scroll used reflect mode, so the halves moved in opposite screen directions, and an 8-entry table that jumped at the wrap (20-chunk period) | fixed — repeat mode, all 20 rotations, wrap at 20, 10-frame step; re-captured: every transition shifts exactly 24 px |
| SR-132 | 4 | 🟡 MINOR | Both: `FrameCounter` documented as 0–29 (stored 1–30) and the branch as `BEQ` (it is `BNE`) | fixed — 1–30 (0 at the reset), `BNE` |
| SR-133 | 4 | 🟡 MINOR | Both: the intro said the previous three lessons changed the playfield once per frame, contradicting Lesson 21's per-line rewrites | fixed — Lesson 21 rewrote per line but repeated the same two patterns frame after frame |
| SR-134 | 4 | 🟡 MINOR | Both: state 8's gap was written 313–697 (inclusive reads as 385 px); the measured range is 313–696 (384 px) | fixed in the main header, doc, spec, ST-22.3, and Session A |
| SR-135 | 4 | 🟡 MINOR | Both: the spec/ST said exercise 3 rotates one chunk per frame with `ASL`/`ROL`; the shipped solution steps a table every 10 frames | fixed — spec/ST now describe the 20-entry table, 10-frame step, repeat mode |
| SR-136 | 4 | 🟡 MINOR | Both: the 8-entry scroll table could not close the 20-chunk cycle; entry 7→0 jumped four chunks | fixed — 20 entries cover every rotation; the wrap is seamless |
| SR-137 | 4 | 🟡 MINOR | Both: the scroll base was attributed to the lesson ROM's castle, which is solid and would look static | fixed — a crenellated pattern ($F0/$CC/$3F = 11111100110011111100) with the notches named as the visible feature |
| SR-138 | 4 | 🟡 MINOR | Both: the Session A record said exercise 2 animates right-half PF2 and that state 8 runs frames 241–270 | fixed — right-half PF0 (chunks 20–23); state 8 frames 240–269 |
| SR-139 | 4 | 🟡 MINOR | Reviewer: the TypeScript reducer stepped at frame 0, one frame ahead of the asm | fixed — `frame === 0 || frame % 30 !== 0` returns |
| SR-140 | 4 | 🟡 MINOR | Re-review: the doc's `FrameCounter` bullet still read 0–29, the spec formula lacked the `− 1`, exercise 2's doorway read 505–601, and the base pattern string lacked the on-screen-order note | fixed — 1–30, `505 + 24k − 1`, 505–600 (96 px; transitions at 505 and 601), the bit-order note added |
