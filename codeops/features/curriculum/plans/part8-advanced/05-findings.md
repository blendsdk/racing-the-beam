# Findings Ledger: Part 8 — Advanced Topics (Lessons 56–65)

> **Document**: 05-findings.md
> **Parent**: [Index](00-index.md)
> **Status**: Part 8 complete — 0 critical, 0 major open. Lessons 56–65 are committed.
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
| SR-60-001 | 60 | 🟠 MAJOR | The doc/sources claimed the DPC register window aliases at `$3000-$307F`, `$5000-$507F`, …; the 6507 has only A0–A12. | fixed — only `$F000-$F07F` in the selected 4K bank is the window; there is no `$3000`/`$5000` alias. |
| SR-60-002 | 60 | 🟠 MAJOR | The doc called the DPC+ register window "compatible with the original DPC"; DPC+ reads `$1000-$1027`, writes `$1028-$107F`, and uses different function codes. | fixed — only the range/eight-fetcher idea carry over; the DPC+ map is distinct. |
| SR-60-003 | 60 | 🟠 MAJOR | The doc said the chip is clocked by every cartridge access; Stella's `CartDPC::peek` clocks only DPC-window/hotspot accesses, so the measured RNG sequence is Stella's. | fixed — the real-chip vs Stella models are separated in the RNG section and takeaway. |
| SR-60-004 | 60 | 🟠 MAJOR | The doc said the obvious 3-fetch/3-store order does not fit with the probe; it fits in 38 cycles, and the interleaving is for PF0/PF1 margin. | fixed — the tip now gives the actual 38-cycle arithmetic and the 2.0-cycle probe margin. |
| SR-60-005 | 60 | 🟡 MINOR | The side-wall bit claim was challenged as bits 2–3; the ROM's PF0 `$30` is bits 0–1 and the capture shows the wall at x=0–7. | verified — the review was a false positive; the doc now states the `$30`/bits 0–1 mapping. |
| SR-60-006 | 60 | 🟡 MINOR | The probe first-pixel was 36.0, not 36.7; the margin 2.0, not 2.7. | fixed in the doc and all three source headers. |
| SR-60-007 | 60 | 🟡 MINOR | The display-image partition omitted the 8-byte gap at 392–399. | fixed — the table now sums to 2,048. |
| SR-60-008 | 60 | 🟡 MINOR | The HMOVE blanking reason conflated the strobe with the artifact; the next line is still in VBLANK. | fixed. |
| SR-60-009 | 60 | 🟡 MINOR | The prose used 13/20/27/34 while the table used 14/21/28/35. | fixed — one 0-based basis and matching margins. |
| SR-60-010 | 60 | 🟡 MINOR | `PhaseLo/Hi` are at `$F2F0/$F2F4`, not page-aligned; only `Probe` is `$F400`. | fixed. |
| SR-60-011 | 60 | 🟡 MINOR | The description said the main reads the music registers; only Exercise 3 does. | fixed. |
| SR-60-012 | 60 | 🟡 MINOR | Exercise 1/3 build headers pointed at the main source. | fixed. |
| SR-60-013 | 60 | 🟡 MINOR | The 03 RAM map said `$80 Frame`; the implementation uses `FrameCount`. | fixed. |
| SR-60-014 | 60 | 🟡 MINOR | "The PF2 stars change every frame" is not guaranteed; the phase is `Rng & 3`. | fixed — "when the RNG selects a different phase"; the 255-frame period is noted. |
| SR-60-015 | 60 | 🟡 MINOR | The TypeScript random read did not decrement DF0. | fixed. |
| SR-60-016 | 60 | 🟡 MINOR | The doc implied the real chip's behaviour; all evidence is Stella 7.0, and a stock cart cannot run the 10K DPC image. | fixed — a hardware-scope warning and the donor/flash/emulator disclosure. |
| SR-60-017 | 60 | 🟡 MINOR | The logo range was 84–97, not 80–97; the font is five bits wide, seven rows, each duplicated. | fixed. |
| SR-60-018 | 60 | 🟡 MINOR | The Javatari DPC detection was inferred from a filename hint; the 10K size selects DPC by priority 101. | fixed. |
| SR-61-001 | 61 | 🔴 CRITICAL | Exercise 1's RLE decoder state (`Y`, `TokLeft`, `Mode`, `CurBuf`) was initialized only once; after the first frame the stream was consumed and the strip read the `$EA` fill. | fixed — the state is reset in VBLANK and the first 8 bytes are pre-decoded; the 8-line status loop uses a zero-page counter so it no longer clobbers Y; a duplicated `+SPRITE_LINE` was removed. `StreamReady` Y=4 every frame; the two-frame strip matches 0/1,024. |
| SR-61-002 | 61 | 🟠 MAJOR | Exercise 3's first image row wrote PF0/PF1/PF2 after the status bar (clocks 75/105/135), showing the status bar's `$F0/$FF/$FF`. | fixed — the image pointer is hoisted into VBLANK; the first row is column 9, 0/760 mismatches. |
| SR-61-003 | 61 | 🟠 MAJOR | The worked example encoded six zeros as `84 00` (5 zeros); six need `$85`. | fixed — `85 00 / 81 3C`. |
| SR-61-004 | 61 | 🟠 MAJOR | "What You Should See" said five bands above and two band groups below; the image has four above, five below, then nine. | fixed. |
| SR-61-005 | 61 | 🟠 MAJOR | The TypeScript block was a top-level `##` heading, not the template's `::: details`. | fixed. |
| SR-61-006 | 61 | 🟡 MINOR | The run paths were said to be under 60; the token-start path is 71–74. | fixed — continuation/token-start cycles stated. |
| SR-61-007 | 61 | 🟡 MINOR | The one-row path was described as three cycles over; it is 80/78, and a one-row first token would desync. | fixed. |
| SR-61-008 | 61 | 🟡 MINOR | `PackedLen`, `RawLen`, `ChecksumVal`, `FrameCount` were written but never read; `SCREEN_LINES`/ex1 `Tmp` were unused. | fixed — `FrameCount`/`SCREEN_LINES`/`Tmp` removed; the three lengths/checksums are live debugger reads (`PackedLenRead`/`RawLenRead`/`ChecksumRead`). |
| SR-61-009 | 61 | 🟡 MINOR | Ex1's `NEXT_BYTE` comment said X was the line index; the run path clobbers X. | fixed. |
| SR-61-010 | 61 | 🟡 MINOR | Ex3's `OverscanStart` is 229/4, not 229/6. | fixed. |
| SR-61-011 | 61 | 🟡 MINOR | The "96-byte buffer collides with the stack" claim was wrong; `$80+96=$E0`. | fixed — the true constraint (576 cannot fit; 96 leaves no room for picture + variables + stack). |
| SR-61-012 | 61 | 🟡 MINOR | The state table said the run value is carried in X in this kernel; it uses `$8A`. | fixed. |
| SR-61-013 | 61 | 🟡 MINOR | The token end was described as `BMI` on the token-start path; it is the `BPL` fall-through. | fixed. |
| SR-61-014 | 61 | 🟡 MINOR | The overscan comment said 35 ticks = 30 lines; 36 does. | fixed. |
| SR-61-015 | 61 | 🟡 MINOR | The startup verification ran with VBLANK=0. | fixed — VBLANK=$02 before the passes. |
| SR-61-016 | 61 | 🟡 MINOR | The `!if` guards pin the packed length only, not the checksum. | fixed — the startup pass/host decode is named as the checksum guard. |
| SR-61-017 | 61 | 🟡 MINOR | The 03 said Lesson 58 covers `LAX (zp),Y`; it covers `LAX zp`. | fixed — softened; the (zp),Y timing is introduced here. |
| SR-61-018 | 61 | 🟡 MINOR | The Python RLE skeleton indexed `raw[j+1]`/`raw[j+2]` without a guard. | fixed — `j + 2 < len(raw)`. |
| SR-61-019 | 61 | 🟡 MINOR | "Every line appears twice" / "96 bytes at 2 bits" were imprecise. | fixed — mirrored right half; 95 bytes + 1 pad. |
| SR-61-020 | 61 | 🟡 MINOR | The walkthrough used `Checksum`/`Screen` for variables and said `PreDecode` leaves `remaining−1`; it leaves `count−4 = remaining−1`. | fixed — `ChecksumVal`/`ScreenNum`; the X note. |
| SR-61-021 | 61 | 🟡 MINOR | The both-screens frame claim was not backed by a second run. | fixed — both states logged; the four frame checkpoints are identical, `Screen` 00/01. |
| SR-61-022 | 61 | 🟡 MINOR | The 03/99 RAM map and checkpoint names were stale (`$8A–$9F`, `DecodePtr`, `RowsLeft`). | fixed — `$8A–$93`, `$94–$9F` free, `DecodePtrRead`/`RowsLeftRead`/`PackedLenRead`/`RawLenRead`/`ChecksumRead`. |
| SR-61-023 | 61 | 🟡 MINOR | The 03 prerequisite still said Lesson 58 covers `LAX (zp),Y`; it covers `LAX zp`. | fixed — "the stable illegal set; this lesson introduces the (zp),Y form". |
| SR-61-024 | 61 | 🟡 MINOR | The doc said SELECT toggles `Screen`; the variable is `ScreenNum` (`Screen` is the checkpoint). | fixed. |
| SR-61-025 | 61 | 🟡 MINOR | The doc said the decoder's only RAM is the 3-byte row buffer; its state also uses `$8A-$8B`. | fixed — "only picture buffer ... state at `$8A-$8B`". |
| SR-61-026 | 61 | 🟡 MINOR | Exercise 1's header compared the 66-byte stream to 128 raw bytes (51.6%); the table is 136 bytes/17 frames (48.5%). | fixed — 136 bytes, 48.5%. |
| SR-61-027 | 61 | — | The reviewer's "run token start is 70/73" claim was checked against the source: the `BMI RunStart` at `$F1DA` targets `$F20A`, a taken page-crossing branch, so 71/74 is correct. | verified — no change. |
| SR-62-001 | 62 | 🟠 MAJOR | The doc claimed the ball enable was written "long before the first visible pixel"; the store lands mid-line, so the ball is one scanline higher on the right half and the collision `BallY` is one line below the visible ball there. | fixed — the doc/source now describe the mid-line pipeline and the controlled freeze (`BallX=100`, `BallY=100` -> row 99); a `VDELBL` experiment was rejected because the ball's delay latch is clocked by `GRP1`, which the play kernel does not write every line. |
| SR-62-002 | 62 | 🟠 MAJOR | The kernel ledger said the worst line was the brick gap at 64/66, "twelve cycles inside"; the measured worst is life-bar row 22 with the ball on at 69 (the write completes at 72, four cycles before the line ends). | fixed — the source header and doc now carry the measured ledger and the 69/4 worst case. |
| SR-62-003 | 62 | 🟠 MAJOR | The round-1 `ColTable` mapped brick 2 to ten `$02` (pixels 28-37), so the gap was 2 px instead of 4; a ball at X36-37 scored a hit inside the drawn gap. | fixed in round 1 — the table is six `$02` + four `$FF` (X28-35, gap X36-39); the comment was corrected to pixels 4+12n..11+12n (chunks 1+3n..2+3n) in round 3. |
| SR-62-004 | 62 | 🟠 MAJOR | Exercise 2's answer said `BallDX=2`/`BallDY=3` gave a clean 2x/3x speed; the `EOR #$FE`/`EOR #$FC` flips make them `$FC`/`$FF` after the first bounce, and the ceiling/paddle/Respawn hard-code ±2. | fixed — the answer lists all five hard-coded sites, the actual 2/4 and +3/-1 behaviour, and the true-negate patch. |
| SR-62-005 | 62 | 🟡 MINOR | The doc called the `$02` background "dark blue"; the capture is dark grey. | fixed — "dark grey (`$02`)". |
| SR-62-006 | 62 | 🟡 MINOR | The RAM prose said 24 bytes + a 16-byte area; the map is 32 bytes. | fixed — nine state bytes, 18 pointer/cache bytes, five scratch bytes. |
| SR-62-007 | 62 | 🟡 MINOR | The `HitBrick` `TAY` looked dead, `TmpCol`'s "last-row flag" comment was wrong, and the `RespawnBall` clamp looked unreachable. | fixed — the `TAY` is documented as the debugger mirror, the `TmpCol` comment is the scratch clear, and the `RespawnBall` clamp is documented as defensive. |
| SR-62-008 | 62 | 🟡 MINOR | A fast `BallDX` could leave `BallX=159`, whose centre 160 mirrors to `$FF` and reads past the 80-byte `ColTable`. | fixed — the wall clamp stores 158 (the last legal left edge) before the flip; the default game needed the same clamp. |
| SR-62-009 | 62 | 🟡 MINOR | `StartGame` did not clear `Overlay`, so a restart after the map was on kept the map. | fixed — `STA Overlay` in `StartGame`. |
| SR-62-010 | 62 | 🟡 MINOR | `OverscanStart` was documented only as 229/6; the over path is 229/7 and the map 229/9. | fixed — all three measured; the scanline is the invariant. |
| SR-62-011 | 62 | 🟡 MINOR | The win/game-over screen was described but not captured or logged. | fixed — `game-over.png` from the committed ROM at 120 s; `ScoreWrite` A=24 at frame 4004. |
| SR-62-012 | 62 | 🟡 MINOR | The TypeScript used `paddleX + 8 > ballX` (the ROM uses `>=`) and `ballY` for the brick row (the ROM uses the leading edge). | fixed — `>=` and `edgeY = ballDY > 0 ? ballY + 3 : ballY`; the wall clamp is mirrored. |
| SR-62-013 | 62 | 🟡 MINOR | The 03 spec still called `$89-$9F` free and `overlay.png` the "debug overlay". | fixed — the real RAM map and "frame map" wording. |
| SR-62-014 | 62 | 🟡 MINOR | The sidebar label truncated "Reverse Engineering a Classic Game" to "…a Classic". | fixed — the full title. |
| SR-62-015 | 62 | 🟡 MINOR | The checkpoint addresses, state-log commands, and disassembly excerpt were stale after the wall clamp and `StartGame` changes. | fixed — re-logged at `$F22F/$F2D9/$F2EC/$F306/$F186/$F19E/$F374`; the excerpt and exercise addresses are current. |
| SR-62-016 | 62 | 🟡 MINOR | The frame-map overlay's row bar and band colours are written mid-line, so the first pixels of a row can carry the previous row's value. | fixed — the doc states the projection caveat. |
| SR-62-017 | 62 | 🟠 MAJOR | The new win capture exposed a full-height white P1 column: the over kernel cleared PF0/1/2 for the red field but not `GRP1`, so the life bar's last `$FF` stayed on from row 23. | fixed — `STA GRP1` added to the over kernel's zero block; `game-over.png` re-captured; the P1 column is gone. |
| SR-62-018 | 62 | 🟠 MAJOR | The wall clamp and the `StartGame`/over-kernel changes left stale addresses in the symbol table and exercise answers (`BricksDone`, `RespawnBall`, `RebuildBricks`, `LDA $85`, the brick path ranges). | fixed — every address was re-read from the final `.sym` and the exercise ranges now use labels; the checkpoint table, commands, and excerpt are current. |
| SR-62-019 | 62 | 🟡 MINOR | The true-negate patch was said to preserve any DX/DY "through every bounce"; the ceiling, paddle, and `RespawnBall` still force ±2. The clamp's unsigned side test also teleports a wrapped negative X to the right wall. | fixed — the answer scopes the negate to the wall/brick bounces, names the three fixed sites, and documents the fast-DX wrap caveat. |
| SR-63-001 | 63 | 🟠 MAJOR | The title capture's orange/HOMEBR state looked impossible on the no-input title path; the review asked for a capture from the committed ROM and a mechanism. | fixed — `title.png` is a burst-selected committed-ROM frame; the state is the SELECT-return path (SELECT rewinds Scroll/ScrollTimer but not ColorIndex, so orange/HOMEBR is reachable). The capture note and pixel table (x=367–636) are updated; the credits capture remains input-free. |
| SR-63-002 | 63 | 🟡 MINOR | The logo cycle ledger was changed to 52; `ORA abs,Y` is 4 cycles (+1 on a page cross), so the base is 49. | fixed — the source header and doc say 49, 50 on a page-cross row; the border is 21 on the first line and 19 on the rest. |
| SR-63-003 | 63 | 🟡 MINOR | "The top bar is one line taller" contradicted the 17-line table; it is nine lines taller. | fixed. |
| SR-63-004 | 63 | 🟡 MINOR | The shifted table's labels were off by one: the zero row is font row 0, the seven data rows are rows 1-7, and an orphan row-7 label had no data; the credit column comments sat below their data. | fixed — the zero row is labelled font row 0, the data rows 1-7, the orphan labels are removed, and the credit comments sit above their data. |
| SR-63-005 | 63 | 🟡 MINOR | `TEXT_COLS`, `BORDER_MASK0`, `BORDER_MASK2` were dead constants. | removed; the ROM bytes are unchanged. |
| SR-63-006 | 63 | 🟠 MAJOR | Exercise 3's answer called `ScoreSetup` at the top of the scores kernel, but it is already called in the common VBLANK; a second call adds a second HMOVE and two visible WSYNCs. | fixed — the answer calls `ScoreDraw` only, with an explicit warning not to repeat `ScoreSetup`. |
| SR-63-007 | 63 | 🟡 MINOR | Group 3 was labelled E-minor/B4; AUDF 10 is nearest B♭4, so the chord is E diminished. | fixed — "E diminished" and "B♭4" in the source header and doc. |
| SR-63-008 | 63 | 🟡 MINOR | The source header built `build/lesson63.bin` while the doc used `build/demo-63.bin`. | fixed — both use `build/demo-63.bin`. |
| SR-63-009 | 63 | 🟡 MINOR | The prerequisites omitted Lesson 35 (sound) and Lesson 54 (visual effects). | fixed in the doc and 03. |
| SR-63-010 | 63 | 🟡 MINOR | Exercise 3's hint said the demo "does not call the score routines"; it calls `ScoreSetup`/`ScoreDraw`. | fixed — it names the digit routines it does not call. |
| SR-63-011 | 63 | 🟡 MINOR | Exercise 1 pointed at a `MESSAGE` generator that does not ship. | fixed — the answer points at the source-header formula and says no generator is shipped. |
| SR-63-012 | 63 | 🟡 MINOR | The 24-pixel gap's mirror halves were swapped in the pixel-check paragraph. | fixed — the left half's 17–19 plus the right half's 0–2. |
| SR-63-013 | 63 | 🟡 MINOR | "The call depth is one level" was false; `ScoreSetup` nests `ScoreSetupP0/P1`. | fixed — the source states the two-level demo and the exercise's stack headroom. |
| SR-63-014 | 63 | 🟡 MINOR | The title pixel table said x=373–642; the committed burst frame measures x=367–636. | fixed; the log-cycle and first-star-line caveats are also documented. |
| SR-64-001 | 64 | 🟠 MAJOR | The first colour-bar body was entered after the page dispatch, so its first store landed at cycle 38 and the top line had a partial/black strip; the band ledger summed to 191. | fixed — `ColourBars` now starts with `WSYNC`/`BIT`/`NOP` at cycle 5, with a black alignment line; the field is 55/27 and the page is 192 lines; the top strip is gone; `OverscanStart` 229/8. |
| SR-64-002 | 64 | 🟠 MAJOR | The controller capture read FRAME 0035 (later 0037), but the doc said 0023/0103. | fixed — the captures are re-taken and the alt/caption/pixel table say 0092 (burn-in) and 0037 (controller). |
| SR-64-003 | 64 | 🟠 MAJOR | The doc claimed a held SELECT/RESET would show the SWCHB blocks on the controller page; SELECT switches the page and RESET holds the CPU. | fixed — SELECT is consumed by the page switch and its block is observable only with the switch held across power-on (`-holdselect`); RESET restarts the console and cannot be observed while the program runs; the still is idle. |
| SR-64-004 | 64 | 🟠 MAJOR | The P0 direction legend said UDLR, but the blocks left-to-right are R, L, D, U; the SWCHB bits are not contiguous. | fixed — the screen legend is RLDU; the doc gives the SWCHA/SWCHB bit maps; the exercise hint matches. |
| SR-64-005 | 64 | 🟠 MAJOR | The doc said the SUM row shows `----` before the checksum completes; it is blank. | fixed — the four SUM cells stay blank; the wording is corrected everywhere. |
| SR-64-006 | 64 | 🟡 MINOR | "Luminance-6 hues" was wrong: the bars have different luminances. | fixed. |
| SR-64-007 | 64 | 🟡 MINOR | The checksum chunk cost was estimated at ~1,344 cycles; the actual is ~1,620 average/1,750 worst, margin ~490. | fixed. |
| SR-64-008 | 64 | 🟡 MINOR | "Wrapped at whole words" was false: CARTRIDGE/CONTROLLER do not fit six columns. | fixed — the screen uses CART/TEST and CTRL/TEST; the doc says the full words are not split. |
| SR-64-009 | 64 | 🟡 MINOR | The TypeScript toggled the page every frame while SELECT was held; the hardware uses an edge. | fixed — `prevSelect` and an edge test. |
| SR-64-010 | 64 | 🟡 MINOR | `CTRLPF=0` repeats the bit blocks; the doc said eight, but 16 are visible. | fixed — the repeat is documented and the table samples the left group. |
| SR-64-011 | 64 | 🟡 MINOR | The burn-in capture showed FRAME 0060 with the checksum, which needs a post-wrap counter; the doc said 4 s. | fixed — the re-captured burn-in is 0092 (pre-wrap) and the doc states the 2.5 s/startup timing. |
| SR-64-012 | 64 | 🟡 MINOR | The Javatari muted-player note was missing. | fixed. |
| SR-64-013 | 64 | 🟡 MINOR | "the read signals" / "the console asserts chip select" were not 2600 facts. | fixed — the console's address decode uses A12; the board maps A0-A11; the ROM drives the data bus. |
| SR-64-014 | 64 | 🟡 MINOR | The Part 8 index said Lesson 64 "turns a ROM into a physical cartridge", promising a build the lesson disclaims. | fixed — the index says the lesson covers the ROM-to-cartridge pipeline and verifies the image with the burn-in test. |
| SR-64-015 | 64 | 🟡 MINOR | The prerequisites omitted Lessons 18, 39, 55, and 63. | fixed in the doc and 03. |
| SR-64-016 | 64 | 🟡 MINOR | The capture note said both stills waited 2.5 s, but the burn-in is FRAME 0092 and the controller 0037. | fixed — the burn-in waited 2.5 s; the controller was captured earlier at 0037 once the page was stable. |
| SR-64-017 | 64 | 🟡 MINOR | "The board decodes A12" conflicted with the console's address decode. | fixed — the console's decode uses A12; the board maps A0-A11; the ROM drives the data bus. |
| SR-64-018 | 64 | 🟡 MINOR | "The VBLANK sets COLUBK to zero" was wrong; the stores are in `BodyStart`/`ColourBars`. | fixed. |
| SR-64-019 | 64 | 🟡 MINOR | The meta said "a CART TEST label"; the screen has CART and TEST. | fixed — "CART and TEST labels". |
| SR-64-020 | 64 | 🟠 MAJOR | The doc still claimed the RESET block was observable with the switch held across power-on; RESET holds the CPU in reset. | fixed — SELECT is observable with `-holdselect`; RESET restarts the console and its block cannot be observed while the program runs (released = 1). |
| SR-65-001 | 65 | 🔴 CRITICAL | Exercise 3's `SwatchTable` was 64 bytes but the 16×8 grid read 128, so rows 8-15 read the timers/strings/glyphs. | fixed — the table is 128 bytes (`$00…$FE`), the grid reads 0..127, and the ROM is 4,096; the 16×8 table is verified in the source/ROM. |
| SR-65-002 | 65 | 🟠 MAJOR | The PAL `BodyEnd` cleared `ENABL` and the next frame's top bands ran with the ball off until the label clear line, so the PAL moving bar was missing from the top 34 picture/66 title lines. | fixed — `OverscanStart` restores `ENABL=2` after `STA VBLANK`; the PAL capture shows the ball in the top band and the bars. |
| SR-65-003 | 65 | 🟠 MAJOR | The band ledgers summed to 188/193, and the source comments used 100/132/66 and a 10-line text band; the actual text band is 11 lines and the final bands are 92/126/55. | fixed — title 8+48+11+16+11+92+1+5, picture 8+16+11+126+11+14+1+5, timing 8+40+11+24+11+24+11+55+1+7, all 192. |
| SR-65-004 | 65 | 🟠 MAJOR | The doc claimed the shipped Harmony/Melody menus and DPC+ games auto-detect the region; the manual supplies NTSC/PAL50/PAL60 variants and DPC+ is compile-time. | fixed — a custom Harmony/Melody firmware could measure with the ARM clock; the shipped menu is region-specific and user-selected; DPC+ is compile-time. The 03 and headers align. |
| SR-65-005 | 65 | 🟠 MAJOR | The 53/9 timer explanation said 54 would let the poll miss the zero; Lesson 15 teaches the zero holds a full tick. | fixed — the reason is the late `STA TIM64T` (cycle 15-20) and the line boundary; 53/9/76 retained. |
| SR-65-006 | 65 | 🟡 MINOR | The source/exercise headers used `stella -pal`, not Stella 7's `-format PAL`. | fixed in all four. |
| SR-65-007 | 65 | 🟡 MINOR | Exercise 3's first swatch was 4 px and the first scanline 15 px early; the hit-number comments were wrong. | fixed — the first line gets the same overhead; the hits are 18,25,32,…; the narrow first swatch is documented. |
| SR-65-008 | 65 | 🟡 MINOR | The 03/99 RAM map said `$86-$9F free`; the source uses `$86-$AB`, leaving only `$AC-$AF`. | fixed in the plan. |
| SR-65-009 | 65 | 🟡 MINOR | The TypeScript gated up/down on the title and its SELECT went picture→timing→title; the ROM is ungated and returns to the picture. | fixed — ungated edges; SELECT returns to the picture (or title if entered from it). |
| SR-65-010 | 65 | 🟡 MINOR | `Row` and `Scratch2` were dead. | removed from all four sources/RAM maps. |
| SR-65-011 | 65 | 🟡 MINOR | The Step 5 snippet showed a nonexistent `JMP PalBorder`/`PalBorder` and omitted `BuildFrame`. | fixed — the real fall-through with `BuildFrame`. |
| SR-65-012 | 65 | 🟡 MINOR | "The timer starts at the top of line 237" ignored the store cycle. | fixed — the `STA TIM64T` completes at ~cycle 27. |
| SR-65-013 | 65 | 🟡 MINOR | The PAL still cannot show the 8-line blanked overscan; the state log proves 312. | fixed — the still shows the 64-line black lower border; the log proves the split. |
| SR-65-014 | 65 | 🟡 MINOR | The playfield repeat shows each label twice; the alt/What-You-See described one. | fixed — the repeat is documented. |
| SR-65-015 | 65 | 🟡 MINOR | Code comments referenced "the plan's 72-line interval". | fixed — the durable PAL 64+8 wording. |
| SR-65-016 | 65 | 🟡 MINOR | Exercise 3's hit-number comments were wrong. | fixed — 18,25,32,… |
| SR-65-017 | 65 | 🟡 MINOR | Exercise 1's doc said "every other line is unchanged"; the file adds a header and sets `DEFAULT_TV`. | fixed — "the program body is unchanged". |
| SR-65-018 | 65 | 🟡 MINOR | The doc claimed the TVMode hand-off was in the log, but only steady A=0/1 was shown. | fixed — the frame-0/1 lines are added. |
| SR-65-019 | 65 | 🟡 MINOR | "RIOT 64-cycle ticks (1-255)" was TIM64T only, and "the TIA's line counter is the frame" was loose. | fixed — TIM64T and the program's WSYNC count. |
