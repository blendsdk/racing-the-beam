# Bankswitching — Reference

## Why it exists

The 6507 sees a **4K cartridge window at `$F000–$FFFF`**. A game bigger than 4K hides extra
ROM behind the window and switches which chunk ("bank") is visible. Each scheme defines
**hotspot addresses**: touching them (usually a read) switches the bank.

The course's advanced lessons (56, 57, 60) cover this; this file is the quick map.

## The common schemes

| Scheme | ROM size | Bank select | Notes |
| --- | --- | --- | --- |
| (none) | 2K/4K | — | Everything in this course before the bankswitching lesson |
| **F8** | 8K | read `$1FF8` → bank 0, `$1FF9` → bank 1 | The classic first step |
| **F6** | 16K | read `$1FF6`–`$1FF9` → banks 0–3 | |
| **F4** | 32K | read `$1FF4`–`$1FFB` → banks 0–7 | The largest "plain" scheme |
| **F8SC / F6SC** | +128 B RAM | as F8/F6 | "Superchip" RAM: write `$1000–$107F`, read `$1080–$10FF` |
| **3E** | 8K–32K + DPC chip | write `$3E`/`$3F` | Parker Bros DPC (Pitfall II): adds 3 music channels and graphics fetchers |
| **DPC+** | large + ARM coprocessor | Harmony/Melody cart | Modern batari BASIC flagship; not buildable on a plain cartridge |
| Others | E0, E7, 3F, UA, … | various | Emulator- and cart-specific; avoid unless needed |

## Rules that keep bankswitched code working

1. **Know which bank is active at power-on** (F8: bank 0 is selected) and make sure that bank
   contains a valid reset vector at `$FFFA–$FFFD`. A common pattern is to place identical
   vector tables and bank-switch stubs in every bank.
2. **Never execute across a bank boundary.** When code jumps, the target bank must already be
   selected, or the switch and the jump must be arranged so the switch takes effect before the
   fetch — the usual trick is duplicated switch-and-jump stubs at the same address in both
   banks.
3. **Data and code live in different banks for a reason**: put graphics/level tables in data
   banks and only their readers in the code bank.
4. **Interrupts are irrelevant on the 2600**, so the only vectors that matter are RESET (and
   the emulator's tolerance for whatever is at NMI/IRQ).

## What each scheme looks like in bankswitched source

```asm
; F8 example: read the hotspot to select the bank, then jump to a
; known routine in that bank (stub duplicated in both banks).
    LDA $1FF9       ; select bank 1
    JMP BankEntry   ; BankEntry must exist (and return) appropriately in bank 1
```

Because the 6507 treats a read as a read, a plain `LDA $1FF8` is enough — no special
instruction. The subtlety is everything the CPU does *before and after* the fetch.

## Scope notes for this course

- Lessons before bankswitching stay in a **single 4K bank**. Do not introduce hotspots early.
- `docs/public/roms` includes only plain `.bin` images. Emulators (Stella, Javatari) auto-
  detect the scheme from size and content, but a `.bin` with no scheme header needs the
  emulator's auto-detection to guess right — keep one scheme per file and keep sizes exact
  (4K, 8K, 16K, 32K).

## Sources

Kevin Horton's bankswitch documentation (AtariAge), 8bitworkshop's VCS mapper notes, Stella
emulator docs; see `sources.md`.
