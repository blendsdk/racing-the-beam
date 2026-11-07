# Requirements: Part 9 — The DSL Path (Lessons 66–68)

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)
> **Source**: [RD-09](../../requirements/RD-09-part9-dsl-path.md) — the OWNING requirements doc

## Scope of this plan (delta view)

### In this plan
- RD-09 AC 1 for lessons 66–68: the full artifact set — source, document, screenshots, committed
  ROMs, `<RomPlayer>`, VitePress index/sidebar/prev-next, README check.
- RD-09 AC 2: `bash scripts/verify.sh` passes with all three lessons included.
- RD-09 AC 3: both specialists report no critical/major before a lesson is done.
- RD-09 AC 4: the 78-lesson curriculum stays frozen (no add/remove/rename/reorder).

### Deferred / out of this plan
- RD-10 (Part 10 — Capstone Projects) and RD-11 (Part 11 — Legendary Techniques).
- Any new mapper, bankswitching, or hardware support; all Part 9 ROMs are 4,096 bytes.
- A bB compiler in the repository or a Python step in CI; both are preflight/author tools only.
- A general-purpose compiler or a reusable DSL framework beyond the lesson-scoped generator and
  zone framework.

## Plan-local decisions

| Decision | Chosen | AR Ref |
| -------- | ------ | ------ |
| Lesson 66 artifact | Hand-written `demo-66.asm` with three lenses; real bB 1.9 listing/reference ROM as evidence | AR-3, AR-11, AR-12 |
| Lesson 66 exercises | Three analysis exercises answered in the doc; no solution files | AR-3, AR-23 |
| Lesson 67 artifact | Playable wave lab + Python generator + wave-spec DSL + two generated levels | AR-13–AR-15 |
| Lesson 67 exercises | Three, each with a 4,096-byte solution ROM | AR-23 |
| Lesson 68 artifact | `include/kernel_framework.asm` + three layouts from one macro set | AR-16–AR-19 |
| Lesson 68 exercises | Three, each with a 4,096-byte solution ROM | AR-23 |
| Zone budget | data lines + one boundary line per zone = 192 | AR-17 |
| Screenshots | 3 (66) + 2 (67) + 3 (68) lesson captures + 1 bB reference | AR-7 |
| Completion | 9 ACME + 1 bB reference ROM, 3 docs, 10 screenshots, 252/253 ROMs | AR-26 |

## Acceptance Criteria

1. [x] Lessons 66–68 each have the artifact set named in RD-09 AC 1.
2. [x] `bash scripts/verify.sh` passes with 252 ACME sources; the committed ROMs are byte-identical.
3. [x] The bB reference ROM is 4,096 bytes and runs in Stella; the generated listing is committed.
4. [x] The Lesson 67 generator's `--check` mode reports no drift; the two specs validate.
5. [x] Every Lesson 68 layout passes the build-time 192-line check and measures a 262-line frame.
6. [x] Both specialists report no critical/major open for each lesson.
7. [x] The Part 9 index rows 66–68 are ✅; sidebar, prev/next, `<RomPlayer>`, README row 9 checked.
8. [x] RD-09 is Done; feature roadmap 9/11; portfolio 9 plans done.
