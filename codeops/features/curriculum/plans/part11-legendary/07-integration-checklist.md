# Lesson 79 — Integration Checklist

> **Rule**: the curriculum listing change and the README sync belong to the amendment
> commit; the lesson artifacts and site status belong to the atomic lesson commit.
>
> **Phase 0**: executed 2026-11-08 in `d7a952a` (curriculum amendment and plan
> adoption). The lesson commit section below remains pending.

## 1. Curriculum amendment commit

Suggested message:

```text
chore(curriculum): add Lesson 79 and amend the lesson count
```

| File | Change |
|---|---|
| `AGENTS.md:3` | “78-lesson” → “79-lesson” |
| `AGENTS.md:29` | “78-lesson structure” → “79-lesson structure”; note the 2026-11-08 authorized addition |
| `.opencode/agents/lesson-author.md:73` | “78-lesson” → “79-lesson” |
| `codeops/specialists/lesson-author.md:39` | “78-lesson” → “79-lesson” |
| `codeops/features/curriculum/requirements/00-ambiguity-register.md` | Amend AR-1: record the user’s 2026-11-08 authorization; freeze the amended structure at 79 |
| `codeops/features/curriculum/requirements/README.md:3,13,44` | 78 → 79; RD-11 “Lessons 73–79” |
| `codeops/features/curriculum/requirements/RD-11-part11-legendary.md` | Title, lesson list, outcomes, AC, scope decision: 73–79; add Lesson 79 |
| `codeops/features/curriculum/00-roadmap.md` | RD-11 row: Plan Created/Executing; note “Lesson 79 first; 73–78 pending”; last updated 2026-11-08 |
| `README.md:3` | “78 hands-on lessons” → “79 hands-on lessons” |
| `README.md:26` | Part 11 `73–78` → `73–79` |
| `docs/index.md:6` | Tagline 78 → 79 |
| `docs/index.md:48` | Part 11 `73–78` → `73–79`; add the publisher mark; update the coming-soon note |
| `docs/.vitepress/config.ts:5,12` | Description/OG 78 → 79 |
| `docs/.vitepress/config.ts:180` | Add the Part 11 Lesson 79 entry; link to the Part 11 index until the doc exists |
| `package.json:6` | Description 78 → 79 |
| `docs/part11-legendary/index.md` | Rebuild the part index: 79 planned/coming soon, 73–78 coming soon; “seven lessons / 79 total”; keep the banner until Lesson 79 ships |
| `docs/part10-capstones/71-maze-explorer.md`, `72-your-game.md` | Footer 78 → 79, if present after the other session’s edits |
| `codeops/features/curriculum/plans/part11-legendary/` | Adopt this plan: index, requirements, ambiguity register, lesson spec, preflight, testing strategy, findings, integration checklist, execution plan |

## 2. Lesson commit

Suggested message:

```text
feat(lesson79): The Publisher Mark — An Activision-Style In-Game Logo
```

| Path | Content |
|---|---|
| `lessons/part11-legendary/79-publisher-mark/79-publisher-mark.asm` | Main 4,096-byte ROM |
| `lessons/part11-legendary/79-publisher-mark/exercise-01-solution.asm` | Ten-letter mark |
| `lessons/part11-legendary/79-publisher-mark/exercise-02-solution.asm` | Moved mark |
| `lessons/part11-legendary/79-publisher-mark/exercise-03-solution.asm` | Playfield mark |
| `docs/part11-legendary/79-publisher-mark.md` | Lesson document |
| `docs/public/images/lesson79/game.png` | Mark visible |
| `docs/public/images/lesson79/no-mark.png` | Mark hidden |
| `docs/public/roms/part11-legendary/79-publisher-mark/79-publisher-mark.bin` | Main ROM |
| `docs/public/roms/part11-legendary/79-publisher-mark/exercise-0{1,2,3}-solution.bin` | Exercise ROMs |
| `docs/.vitepress/config.ts` | Point the 79 entry at `/part11-legendary/79-publisher-mark` |
| `docs/part11-legendary/index.md` | 79 ✅; 73–78 🔮 |
| `codeops/.../plans/part11-legendary/06-findings.md` | Review findings and fixes |
| `codeops/.../plans/part11-legendary/99-execution-plan.md` | Session A/B/C records |

## 3. Cross-references

| File | Change | Priority |
|---|---|---|
| `docs/part7-kernel-mastery/55-scrolling-text-marquee.md:228` | Add one sentence: the persistent in-game mark is Lesson 79’s subject; the sidebar describes the scrolling logo screen | Recommended |
| `docs/part6-game-dev/39-scoreboard.md` | Add a one-line “Lesson 79 reuses this kernel for a publisher mark” in What’s Next or a tip | Optional |
| `docs/part7-kernel-mastery/50-multi-zone-kernel.md` | Add a one-line “Lesson 79 uses the handover for a bottom mark” | Optional |

## 4. Count audit

Run after both commits:

```bash
grep -rn "78 hands-on\|78 lessons\|78-lesson\|73–78\|73-78\|six lessons\|lessons 73–78" \
  README.md AGENTS.md docs package.json codeops .opencode/agents
```

Expected remaining matches:

- historical records and old execution-plan session notes (do not rewrite history);
- `$78` addresses, 1978 dates, unrelated numbers.

Every curriculum/count reference must say 79 or 73–79. Update the current docs and
briefs; leave historical session records untouched.

## 5. VitePress checklist

- [ ] Sidebar entry for 79 links to the doc.
- [ ] Part 11 index lists 79 ✅ and 73–78 🔮.
- [ ] Lesson 79 `prev` points to `/part11-legendary/`; no `next`.
- [ ] RomPlayer under the screenshot.
- [ ] Captures at `/images/lesson79/…`.
- [ ] `npm run docs:build` passes.
- [ ] No broken links to 73–78.

## 6. README checklist

- [ ] Line 3 says 79 lessons.
- [ ] Part 11 row says 73–79.
- [ ] The README change is in the curriculum-amendment commit.
- [ ] No stale “78” or “73–78” remains in the current README.

## 7. Commit order

1. `chore(curriculum): add Lesson 79 and amend the lesson count`
   - policy, requirements, AR-1, RD-11, roadmap, README, site counts, Part 11 index,
     CodeOps plan.
2. `feat(lesson79): The Publisher Mark — An Activision-Style In-Game Logo`
   - 4 sources, doc, 2 captures, 4 ROMs, sidebar link, Part 11 index status, findings.

If the user prefers one commit, squash them, but keep the README/site count change and
the lesson artifacts together. The default is two commits.

## 8. Final gate

```bash
git status --short          # clean
bash scripts/verify.sh      # passes
git log --oneline -2        # amendment, then feat(lesson79)
```
