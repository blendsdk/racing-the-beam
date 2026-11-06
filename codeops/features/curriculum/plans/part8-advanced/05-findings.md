# Findings Ledger: Part 8 — Advanced Topics (Lessons 56–65)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Phase 4 complete after round 2 — 0 critical, 0 major open. Lessons 56–59 are committed.
> **Rule**: every reviewer finding is recorded here with its severity, its location, and the
> fix that closed it. A lesson is not done while a critical/major row is open.

## Preflight Findings

The plan-level preflight findings (PF-01 … PF-24) live in
[00-preflight-report.md](00-preflight-report.md). All are resolved or folded into the lesson
specs. The two critical findings were the false PAL/NTSC auto-detection claim (PF-01) and the
non-buildable DPC+ promise (PF-02); both are corrected in the Lesson 65 and Lesson 60 specs.

## Per-Lesson Findings

| ID | Lesson | Severity | Finding | Resolution |
| --- | --- | --- | --- | --- |
| SR-56-001 | 56 | 🟠 MAJOR | The switch-cost table counted only the 12-cycle mapper chain, but the measured `StartFrame` offset is 36/37 cycles; the takeaway said "twelve cycles". | fixed — the doc now separates the 13-cycle mapper chain from the 23/24-cycle frame bookkeeping and 3-cycle dispatch, and reports 259/39 outbound and 259/40 on the return. |
| SR-56-002 | 56 | 🟠 MAJOR | The forest caption said four trunks (the ROM draws three); the cave wall was described as a one-sided staircase and the pixel table's "wall 433–576 at row 96" was the row-32 centre block. | fixed — "three green trunks"; the cave is a symmetric centre block that splits into two outward-stepping walls; the pixel table now records the row-32 centre block and the row-96 walls. |
| SR-56-003 | 56 | 🟠 MAJOR | The trampoline was called "seven bytes" and the post-switch fetch `$F067`; it is six bytes (`$F060–$F065`) and the JMP opcode is at `$F063`. | fixed in the source comments, the doc, and the byte-compare ranges (`$0060–$0065`/`$1060–$1065`, `$0070–$0075`/`$1070–$1075`). |
| SR-56-004 | 56 | 🟠 MAJOR | The 03 spec still pinned `JMP $F040`/`$F020`, mains at those addresses, and `$81 Frame`/`$82 BankTimer`, contradicting the implementation's `$F080`/`$81 BankTimer`/`$82 FrameCount`. | fixed — the spec now matches the implementation (`$F080`, `BankTimer`, `FrameCount`, `ForestMain`/`CaveMain`). |
| SR-56-005 | 56 | 🟠 MAJOR | ST-56.5 still expected the data-bank exercise to copy its table to RAM; the corrected design reads it in place. | fixed — "data bank read in place; no RAM copy". |
| SR-56-006 | 56 | 🟠 MAJOR | The findings ledger and roadmap still said "not executed"/"Plan Preflighted" during the lesson review. | fixed — this ledger, the plan progress, the part index, and RD-08 now record Phase 1. |
| SR-56-007 | 56 | 🟡 MINOR | The start-bank failure mechanism said bank 1's `$FFFC` points at bank 0's bytes; it points at bank 1's own slot. | fixed. |
| SR-56-008 | 56 | 🟡 MINOR | Step 4 said the 1-line kernel has 47 cycles of margin; the indicator rows are the worst case at 38. | fixed — 38 on indicator rows, 47 on scene rows. |
| SR-56-009 | 56 | 🟡 MINOR | The `<RomPlayer>` lacked the standard muted-player note. | fixed — "Javatari starts muted; this ROM is silent, so there is nothing to unmute." |
| SR-56-010 | 56 | 🟡 MINOR | Ex1's build header pointed at the main lesson source/ROM. | fixed — its own `build/exercise-01.bin` and source. |
| SR-56-011 | 56 | 🟡 MINOR | What's Next said the first 256 bytes of an F8SC bank are the RAM window; they are the duplicated signature. | fixed — the signature vs `$1000–$107F`/`$1080–$10FF` distinction; 03 §57 corrected too. |
| SR-56-012 | 56 | 🟡 MINOR | Step 7's snippet used an undefined `Reset` label. | fixed — `CaveReset` with a note that bank 1 uses `ForestReset`. |
| SR-56-013 | 56 | 🟡 MINOR | Prose slips: "the middle 16 chunks and its reflection" double-counted the mirror; "playfield field"; the cave caption claimed the geometry did not change. | fixed. |
| SR-56-014 | 56 | 🟡 MINOR | The execution plan carried two consecutive `Session B record` headings. | fixed — one B record and one C record, both filled. |
| SR-56-015 | 56 | 🟡 MINOR | The switch frame was reported only as 259/39; the return to bank 1 is 259/40. | fixed in the doc and the checkpoint table. |
| SR-56-016 | 56 | 🟡 MINOR | The exercise Stella evidence was not recorded. | fixed — ex1 `BankEntry` A=1; ex2 `BankEntry0` A=0 and A=1/2/3; ex3 `DataMain` 0/39 and `DataRow` 37/07. |
| SR-56-017 | 56 | 🟡 MINOR | The fire edge was stated as fact without an observation. | fixed — the doc discloses that fire is code-reviewed and the auto-demo exercises the same path. |
| SR-56-018 | 56 | 🟠 MAJOR | The Key Takeaway still said "the switch cost is twelve cycles" after Section 4 was corrected. | fixed — the takeaway now says the mapper chain is 12 cycles and the full path is 39/40 (36/37 over the ordinary loop). |
| SR-56-019 | 56 | 🟠 MAJOR | The bank-0 stub header still said "THE SAME SEVEN BYTES AS BANK 0"; the Full Source inherited it. | fixed — both source copies and the re-injected Full Source say six bytes. |
| SR-56-020 | 56 | 🟠 MAJOR | The Section 5 data table still said "four trunks" and "a jagged red cave wall". | fixed — "three trunks" and the symmetric cave description. |
| SR-56-021 | 56 | 🟡 MINOR | The bank-0 indicator row is 39 cycles, so the worst-case margin is 37, not 38. | fixed — the source/doc say 38 in bank 1, 39 in bank 0, at least 37 margin. |
| SR-56-022 | 56 | 🟡 MINOR | The cave's "192 to 144 pixels" used capture pixels in a TIA-pixel passage. | fixed — "192 to 144 capture pixels (32 to 24 TIA pixels)". |
| SR-56-023 | 56 | 🟡 MINOR | Step 6 still described a one-sided staircase. | fixed — centre block that splits into two mirrored walls. |
| SR-56-024 | 56 | 🟡 MINOR | Exercise 3's header said `$F085 StartFrame`; the symbol is `$F084`. | fixed. |
| SR-57-001 | 57 | 🟠 MAJOR | Exercise 3's bank-1 re-entry ran `+clean_start` and the 128-byte zero loop before VSYNC, so the VSYNC was ~51 lines late and the frame ~313 lines every 128 frames. | fixed — the exercise is now a one-way switch: bank 1 writes and switches to bank 0; bank 0 asserts `+vsync` immediately, reads `$A5`, shows green, and stays. The switch frame is `B0StartFrame` 259/15, steady 259/3, 262 lines. |
| SR-57-002 | 57 | 🟠 MAJOR | The Session B/C records and the SR-57 ledger rows were not written; the phase evidence was missing. | fixed — the 99 records now carry the build, mapper, frame, RAM, exercise, capture, and review evidence; this ledger has the SR-57 rows. |
| SR-57-003 | 57 | 🟡 MINOR | Exercise 1's failure path zeroed the gauge, but the 8-frame update re-lit it; a broken read looked like a pass after ~17 s. | fixed — `FillFailFlag = $AD` is set on a mismatch and the update skips the gauge OR; a forced-mismatch build showed A=$01 and an empty gauge. |
| SR-57-004 | 57 | 🟡 MINOR | The cycle ledger counted page-local taken `BNE`s as 4; the status/text/play rows are 29/32/17, PF0 is stored by 14 every row, and the text margin is 44. | fixed in the source/doc/ex1. |
| SR-57-005 | 57 | 🟡 MINOR | Exercise 1's RAM header said `$80-$A7`; the allocation reaches `$AD` after the failure flag. | fixed — `$80-$AD`. |
| SR-57-006 | 57 | 🟡 MINOR | Exercise 1's data header said the bank-1 tables start at `$F200`; they are at `$F400`. | fixed. |
| SR-57-007 | 57 | 🟡 MINOR | Exercise 2's header promised a `GaugeAll` checkpoint with no label. | fixed — `GaugeAll` is `$F126`; the bytes are unchanged. |
| SR-57-008 | 57 | 🟡 MINOR | The notebook-a caption said "the early part of the message"; the window holds the newest six characters at the tail of the first pass. | fixed — the captions now say tail/early-second-pass. |
| SR-57-009 | 57 | 🟡 MINOR | The spec said a gauge cell lights on a nonzero byte; the implementation lights it when the group has been written. | fixed — the spec says "has been written". |
| SR-57-010 | 57 | 🟡 MINOR | The reset-vector example said a fetch at `$F000` would execute readable RAM; `$F000–$F07F` is the write window. | fixed — a fetch there lands in the write window, not ROM/readable RAM. |
| SR-57-011 | 57 | 🟡 MINOR | The `<RomPlayer>` lacked the muted-player note. | fixed — "Javatari starts muted; this ROM is silent..." |
| SR-57-012 | 57 | 🟡 MINOR | `POS_BIAS` was dead and the `SetCoarseP0` comment promised a bias the call site did not use. | fixed — the bias is applied in the main and both exercise call sites; the main marker measures TIA 49–56 / 33–40 and the captures/columns are updated. |
| SR-57-013 | 57 | 🟡 MINOR | The 99 Session A record said bank 0's `$F100` jumps to `$F100`; it jumps to `$F106`, and the 32-byte message is not the 128-byte buffer. | fixed. |
| SR-57-014 | 57 | 🟡 MINOR | The doc's Section 6 snippet still omitted `POS_BIAS` while the prose below said the call adds it. | fixed — `ADC #(MARKER_X_BASE + POS_BIAS)`. |
| SR-57-015 | 57 | 🟡 MINOR | Exercises 1 and 2 defined `POS_BIAS` but did not use it, so their markers were 3 TIA pixels left. | fixed — both call sites use the bias; the ROMs changed by one immediate byte each. |
| SR-57-016 | 57 | 🟡 MINOR | Exercise 2's `GaugeAll` label sat before `LDA #$FF`, so the breakpoint reported the previous byte; `StripDone`'s comment implied A was the last strip byte. | fixed — `GaugeAll` moved after the `LDA` (`$F128`); `StripDone` documents A=$00, Y=128. |
| SR-57-017 | 57 | 🟡 MINOR | The doc's Exercise 3 used the main's `StartFrame` names for bank 0; the exercise exposes `B0StartFrame` etc. | fixed — the `B0`-prefixed labels, with the switch frame 259/15 and steady 259/3. |
| SR-58-001 | 58 | 🔴 CRITICAL | The lesson claimed ACME 0.97 cannot assemble the undocumented mnemonics and that only other assemblers can. ACME's `!cpu 6510` accepts LAX/SAX/DCP/ISC (verified `A7 80 87 80 C7 80 E7 80`); only `!cpu 6502` rejects them. | fixed — the rationale is now: `6502` rejects, `6510` accepts, the course keeps `6502` + `!byte` macros for byte visibility. The doc/source/spec/AR-14/PF-06 are corrected. |
| SR-58-002 | 58 | 🟠 MAJOR | The row setup wrote PF0/PF1 on the new row's first line after a 13-cycle tail, so rows 2–4's first line showed the previous row's flag bits. | fixed — `ResultLine` writes `RowF0/X`/`RowF1/X` before its `WSYNC`; the DCP/ISB first lines now show their own flags; lab-a is re-captured. |
| SR-58-003 | 58 | 🟠 MAJOR | The strip byte line completed PF1 after chunks 4–6, so the ISB strip drew `$C7` (bit 5 lost) instead of `$E7`. | fixed — the four strips are unrolled; the byte rows read $A7/$87/$C7/$E7; lab-b is re-captured. |
| SR-58-004 | 58 | 🟠 MAJOR | The unstable table listed SHA as `$9F`/`$93`/`$9E`; `$9E` is SHX. | fixed — SHA is `$9F`/`$93`; `$9E` remains only for SHX. |
| SR-58-005 | 58 | 🟠 MAJOR | The Session B/C records and the SR-58 ledger were not written. | fixed — the 99 records and this ledger row set are filled. |
| SR-58-006 | 58 | 🟡 MINOR | LAX/SAX do not define C, so the C column flashed when `ScreenTimer` wrapped. | fixed — `CLC` before both. |
| SR-58-007 | 58 | 🟡 MINOR | The checksum's two PF2 bits were reversed relative to the "bit 7 first" prose. | fixed — the `Rev2` table maps bit 1 to chunk 12 and bit 0 to chunk 13. |
| SR-58-008 | 58 | 🟡 MINOR | The footer's first line wrote PF0/PF1 after the chunks they affect, leaving a chunk-2/4 hole. | fixed — PF0/PF1 are written first; the rule spans x=25–985. |
| SR-58-009 | 58 | 🟡 MINOR | Exercise checkpoint names (`DcpZero`/`DcpFlags`, `Frame`) did not match the labels. | fixed — `ReachedZero`, `DcpFlags`, `CountFlags`; `Frame` dropped from the exercise headers. |
| SR-58-010 | 58 | 🟡 MINOR | The documented bars did not share a start column, so SAX's comparison was off by one chunk. | fixed — all right-aligned at chunk 19. |
| SR-58-011 | 58 | 🟡 MINOR | The TypeScript `isb` omitted the V flag. | fixed — V is computed and documented. |
| SR-58-012 | 58 | 🟡 MINOR | Lab-b's footer indicator was called "the right edge"; it is chunks 17–18. | fixed — "right of centre (chunks 17–18)". |
| SR-58-013 | 58 | 🟡 MINOR | The `nv-BdIZC` explanation said B=0 while the debugger display has B=1 and the stored byte clears bit 4. | fixed — the display vs stored-byte distinction is explained. |
| SR-58-014 | 58 | 🟡 MINOR | The SAX tip said the gap grows to 16; the 16-cycle documented sequence is a 13-cycle saving, and the 7-cycle form needs an immediate mask. | fixed. |
| SR-58-015 | 58 | 🟡 MINOR | The 6507 was described as having fewer data pins; it has 8 data pins and fewer address/interrupt pins. | fixed. |
| SR-58-016 | 58 | 🟡 MINOR | The NMOS decode was called "microcode"; it is a PLA/decode table. | fixed. |
| SR-58-017 | 58 | 🟠 MAJOR | Two stale ACME copies remained: Lesson 57's What's Next said "ACME has no mnemonics", and the AR table row said "ACME has no undocumented-opcode mnemonics". | fixed — both now say `!cpu 6502` rejects, `!cpu 6510` accepts, and the course keeps 6502 + `!byte` macros. |
| SR-58-018 | 58 | 🟡 MINOR | The cycle-table band separators started at cycle 11 after the loop tail, so `STA PF1` landed at the chunk-4 boundary; 7 of 8 separators could show a notch. | fixed — the index update moved before the blank lines; all eight separators are continuous x=73–505 / mirror, chunk 4 lit. |
| SR-58-019 | 58 | 🟡 MINOR | The result-row cycle numbers were measured from `ResultLine`, not the scanline start; the doc presented them as line cycles and overestimated the unused cycles. | fixed — the doc/source say "measured from ResultLine", give the absolute 14/21 (normal) and 18/25 (first line), and the RowEnd ~66 cycles/10 unused. |
| SR-58-020 | 58 | 🟡 MINOR | The panel is reflected, but the prose/pixel table listed only the left-half copies. | fixed — a reflection sentence and the mirrored ranges (checksum 10–11/28–29; indicators 1–2/37–38 and 17–18/21–22). |
| SR-58-021 | 58 | 🟡 MINOR | The source comment said the ISB bit-5 loss was "chunk 6"; bit 5 is chunk 4. | fixed. |
| SR-58-022 | 58 | 🟡 MINOR | The Step 2 walkthrough excerpt omitted the `CLC`s and the `DcpM`/`IsbM` labels. | fixed — the current `RunLab` head, marked abridged, with every checkpoint named. |
| SR-58-023 | 58 | 🟡 MINOR | The pasted `DcpM` log line showed C=0 while DCP sets C=1 and the stored `$27` says C=1. | fixed — re-logged `DcpM $F36C` `nv-BdIzC 1f`, C=1; the checkpoint row says C=1. |
| SR-59-001 | 59 | 🔴 CRITICAL | The phase window used an 8-bit `Y`; for `Phase > 72` the gradient tail read the table's opening entries instead of `table[Phase..183] + table[0..Phase-73]`. The painter-b phase-96 claim was false (the image was actually ~165–176). | fixed — the two-window split: `ColorTable,Y` from `Y=Phase`, then `ColorTable+256,Y` after the wrap; the table is page-aligned, the color write is cycle 34, `PatchByteTail` reads `$6E` at phase 73, and painter-b is re-captured at phase 96. |
| SR-59-002 | 59 | 🟠 MAJOR | The 60-frame phase hold repeated every 256 frames because `FrameNum` is 8-bit; the gradient froze ~1 s every ~4.3 s. | fixed — a one-shot `HoldFrames` byte; the first phase step is frame 64. |
| SR-59-003 | 59 | 🟠 MAJOR | The left-edge seam mixed 28/31/34-pixel models and called the 31 figure an average. | fixed — one measured model: 37 px steady, 46 first line, 64 last; one cycle = 3 px. |
| SR-59-004 | 59 | 🟡 MINOR | The status row's PF1 store could race chunk 4 on visible line 0. | fixed — the status setup is in VBLANK; the top field is identical on rows 0–3. |
| SR-59-005 | 59 | 🟡 MINOR | Exercise 1's delay limit said 5; the `WSYNC` write is 70 at d=5, 75 at d=6, overflow at d=7. | fixed. |
| SR-59-006 | 59 | 🟡 MINOR | Exercise 1's heading said "0..6" for the 1,2,3,4 table. | fixed. |
| SR-59-007 | 59 | 🟡 MINOR | Exercise 3's header said P0 X=40 (code 80), the last shape byte (code first), and unmeasured cycle numbers. | fixed — X=80, first byte `$18`, measured 39–41/54–56/57–59. |
| SR-59-008 | 59 | 🟡 MINOR | Exercise 3's status field was described as the last shape byte; it is the first. | fixed. |
| SR-59-009 | 59 | 🟡 MINOR | The doc named a `TableRead` checkpoint that did not exist. | fixed — the ex2 header has `TableRead $0083`. |
| SR-59-010 | 59 | 🟡 MINOR | `TableB` had 188 bytes and four unused entries; the doc said 184. | fixed — both tables are exactly 184 bytes. |
| SR-59-011 | 59 | 🟡 MINOR | The doc said "184 different colors"; the table has 28 distinct values. | fixed — "184 colour writes from a 184-entry table (28 distinct colours)". |
| SR-59-012 | 59 | 🟡 MINOR | The 99 Session A said the `JSR`/`RTS` pair uses `$F8-$F9`; it uses `$FF/$FE`. | fixed. |
| SR-59-013 | 59 | 🟡 MINOR | The 03/07 spec still said 9-byte/192/`CallCount 192`; the implementation is 7-byte/184/184. | fixed — the spec matches the artifact. |
| SR-59-014 | 59 | 🟡 MINOR | The second-window's first tail line took `CPY` not taken + `BNE` not taken + `LDY #0` (6 cycles), so its color write was cycle 35/40 px, not 34/37. | fixed — the redundant `LDY #0` is dropped; the first tail line is cycle 33 / 34 px, hidden because table[71] = table[72] = `$6E`. |
| SR-59-015 | 59 | 🟡 MINOR | The exercise siblings still wrote the status PF1 on visible line 0 (ex3 after `STA GRP0`). | fixed — the status/`STA GRP0` setup is in VBLANK in all three exercises. |
| SR-59-016 | 59 | 🟡 MINOR | Exercise 1's `DelayTable`/`ColorTable` were unaligned; the page crossings added 3-px steps. | fixed — both tables are `!align 255, 0` at `$F100`/`$F200`; the delay table is 184 entries. |
| SR-59-017 | 59 | 🟡 MINOR | Exercise 3's `STA COLUBK` write was labelled TIA X ~94–100; cycles 56–58 map to ~100–106. | fixed. |
| SR-59-018 | 59 | 🟡 MINOR | The doc listed only `$87–$8A`; the variables reach `$8C` (`HoldFrames`, `PhaseTimer`). | fixed — `$80–$8C` in the map and the safety rule. |
| SR-59-019 | 59 | 🟡 MINOR | PF-07 still said a 9-byte routine at `$80–$88` and variables `$89–$9F`. | fixed — 7-byte `$80–$86`, variables `$87–$8C`, stack `$F8–$FF`. |
| SR-59-020 | 59 | — | The auditor's "checkpoint addresses are $30 low" claim was checked against the ACME symbol table: `StartFrame $F033`, `PatchByteTail $F0BB`, `CallCount $F0CC`, `OverscanStart $F0D1`, `ColorTable $F100`; no change was made. | verified — the symbol table is the ground truth; the audit's byte count was off. |
