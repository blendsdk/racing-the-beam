# Lesson 79 — Testing Strategy

> **Status**: Draft; freeze at Session A.
> **Evidence rule**: every frame, pixel, and cycle claim has a state log, a static
> ledger, or a pixel check. Screenshots are not evidence by themselves.

## 1. Specification test cases

| ID | Case | Method | Expected |
|---|---|---|---|
| ST-79.1 | Assemble the artifact set | `acme` for 4 sources; compare with committed ROMs | 4 × 4,096 bytes; byte-identical |
| ST-79.2 | Frame and bands | Stella state log at the checkpoints | 262 lines; `StartFrame` 259/3, `VblankStart` 0/5, `BodyStart` 37/5, `OverscanStart` 229/6; score 37–45, play 51–214, handover 215–219, mark 220–228 |
| ST-79.3 | Score block | State log + pixel check | White 48-pixel block, TIA X=56–103, visible 1–7; six digits |
| ST-79.4 | Mark block | State log + host-rendered table + pixel check | Gold 48-pixel block, TIA X=16–63, visible 184–190; 0 mismatches against `MarkBuf` |
| ST-79.5 | Mark toggle | State log + captures | `MarkVisible` toggles 0/1; the band blanks; the frame stays 262; score/play unchanged |
| ST-79.6 | Play and score | State log + input | Player moves; ball falls; `CXP0FB` hit increments the score; the auto-demo catches |
| ST-79.7 | Exercise 1 | Assemble + run + inspect | Ten-letter 4-px mark fits; table 48 bytes; frame 262 |
| ST-79.8 | Exercise 2 | Assemble + run + inspect | Mark at bottom-right/centre; frame 262 |
| ST-79.9 | Exercise 3 | Assemble + run + inspect | Playfield mark; players free; frame 262 |
| ST-79.10 | Document and site | Page check + `docs:build` | Template complete; Full Source verbatim; sidebar/part index/prev/RomPlayer; README 79/73–79 |

## 2. Evidence method

### 2.1 Frame

Use the Stella debugger:

- break at `StartFrame`, `VblankStart`, `BodyStart`, `ScoreDone`, `PlayStart`,
  `HandoverStart`, `MarkStart`, `MarkDone`, `OverscanStart`;
- record the scanline and cycle at each;
- confirm 262 lines and the band boundaries.

### 2.2 Mark pixels

- Render the 48-byte `MarkBuf` host-side into a 48×8 bitmap.
- Capture `game.png` from the committed ROM.
- Crop the mark block at the recorded rectangle and compare with the host bitmap.
- Count mismatches; expect 0. If the font’s byte 0 is blank, the lit rows are 7.
- Repeat with `no-mark.png`: the block is blank.

### 2.3 Score

- `ScoreWrite` logs the new score after a hit.
- The score block is the Lesson 39 kernel; the pixel check confirms the digits.
- The score’s first hit is 000001; the auto-demo produces a deterministic sequence.

### 2.4 Toggle

- `SelectEdge` logs 1 on the toggle.
- `MarkVisible` logs 0/1.
- The auto-demo calls `ToggleMark` at the scripted frames; `game.png` and
  `no-mark.png` show the two states.
- The frame log stays 262 lines in both states.

### 2.5 Exercises

- Each solution assembles to 4,096 bytes.
- Run in Stella; inspect the mark position/width.
- Exercise 1: the new wordmark is readable; the table remains 48 bytes.
- Exercise 2: the mark is at the new X; the score/play/frame unchanged.
- Exercise 3: the mark uses the playfield; P0/P1 are free; the frame 262.

## 3. Static checks

| Check | Method |
|---|---|
| `MarkBuf` within one page | Inspect the assembled listing; `MarkBuf & $FF <= 208` (48 bytes) |
| `MarkDraw` cycle ledger | Instruction-by-instruction count; compare with `ScoreDraw` |
| Positioner/handover budgets | Count lines per routine; 2 lines per object; 5 per band |
| RAM map | Assembly-time asserts or a static table |
| No motion writes after HMOVE | Code inspection of the 24-cycle windows |
| 4,096 bytes | `wc -c` on all four ROMs |

## 4. Verification commands

```bash
# all ROMs
npm run roms

# full verification
bash scripts/verify.sh

# ROMs only (faster while iterating)
bash scripts/verify.sh --no-docs

# one lesson
acme -f plain -o build/lesson79.bin \
  lessons/part11-legendary/79-publisher-mark/79-publisher-mark.asm
stella build/lesson79.bin

# screenshots from the committed ROM
bash scripts/capture-screenshot.sh \
  docs/public/roms/part11-legendary/79-publisher-mark/79-publisher-mark.bin \
  docs/public/images/lesson79/game.png
```

## 5. Review gates

| Gate | Requirement |
|---|---|
| `atari2600-reviewer` | No critical or major findings; all minors fixed or explicitly accepted |
| `curriculum-auditor` | Five hard rules pass; no critical or major findings |
| `bash scripts/verify.sh` | Passes after fixes |
| Findings ledger | Every finding recorded with status |

## 6. Exit criteria

- ST-79.1–ST-79.10 pass.
- The two captures are pixel-checked.
- The four ROMs are committed and byte-identical to fresh assemblies.
- The doc and site build.
- Reviews are clear of critical/major findings.
