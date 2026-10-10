# Canonical Sources

Primary references for grounding claims in this course. Cite them by name when a lesson
states a non-obvious hardware fact, and prefer the ones marked **[primary]** for numbers.

| Source | What it covers | Link |
| --- | --- | --- |
| Stella Programmer's Guide (1979) **[primary]** | Register semantics, priority, playfield bit order, timing constraints | https://www.atariage.com/2600/programming/2600_101/docs/stella.html |
| problemkaputt.de VCS specification **[primary]** | Frame tables, horizontal timing, HMOVE/RESP details, AUDC table, memory map | http://problemkaputt.de/2k6specs.htm |
| 8bitworkshop — Atari 2600/VCS docs | Modern practical overview, register summary, mappers, IDE with VCS support | https://8bitworkshop.com/docs/platforms/vcs |
| Andrew Davie — "Atari 2600 Programming for Newbies" | Gentle tutorial series, memory architecture, playfield basics | https://www.randomterrain.com/atari-2600-memories-tutorial-andrew-davie-01.html |
| Nick Bensema — "How to Draw a Playfield" | The classic kernel tutorial (playfield writer) | Hosted on AtariAge; search the title |
| *Racing the Beam* — Bogost & Montfort (MIT Press, 2009) | History and techniques (Cosmic Ark starfield, Adventure engine, Pitfall) | ISBN 978-0-262-01257-7 |
| *Making Games for the Atari 2600* — Steven Hugg | Practical game development with 8bitworkshop | 8bitworkshop books page |
| AtariAge 2600 Programming forums | TIA edge cases, SetHorizPos discussions, historical techniques | https://forums.atariage.com/forum/15-atari-2600-programming/ |
| Stella emulator + debugger docs | Debugger usage, TIA/RAM views, timing measurement | https://stella-emu.github.io/ |
| ACME assembler + manual | Syntax, macros, anonymous labels, directives | https://sourceforge.net/projects/acme-crossass/ |
| Kevin Horton — bankswitch schemes | The authoritative mapper documentation | AtariAge thread ("Atari 2600 Bankswitch Schemes") |
| batari BASIC reference | The DSL analyzed in Part 9 | https://bataribasic.com/ |
| Javatari.js | The in-browser emulator bundled with this site (AGPL-3.0) | https://github.com/ppeccin/javatari.js |
| Paul Slocum — 2600 music notes | Practical audio/music engineering | AtariAge music threads |

## How to use these in lessons

1. **Numbers** (line counts, clock divisions, register bits): cite **[primary]** sources.
2. **Techniques and history** (Cosmic Ark, skipdraw, Adventure): cite the book/forum thread and
   clearly separate "documented history" from "what we implemented here".
3. **Anything you verify yourself in Stella**: say so explicitly ("verified in Stella; debugger
   shows ...").
