# Lessons 73–78 — Integration Checklist

## Per lesson

- [ ] Main source and two solutions assemble to 4,096 bytes.
- [ ] `docs/partN/NN-slug.md` follows the template; Full Source is verbatim.
- [ ] Two real Stella captures at 1010x807, title bar, pointer parked, no cursor.
- [ ] `<RomPlayer>` under the captures, pointing at the committed main ROM.
- [ ] Part 11 index row flips to Complete and links to the page.
- [ ] Sidebar entry links to the page.
- [ ] `npm run roms` builds every source; the three `.bin` files are committed.
- [ ] `bash scripts/verify.sh` passes after the lesson commit.
- [ ] Both reviews report 0 critical / 0 major open.

## Final integration (after 78)

- [ ] `prev`/`next` chain: 73 -> 74 -> ... -> 78 -> 79; 73's prev is the Part 11 index; 79's
      prev is 78 and has no next.
- [ ] Part 11 index: all seven rows Complete; the "coming soon" wording is gone.
- [ ] Sidebar: all seven entries point at their pages; the overview is live.
- [ ] Home page row 11 no longer says "coming soon".
- [ ] README: 79 lessons; Part 11 = 73–79.
- [ ] RD-11 closes at 11/11 RDs; the portfolio and feature roadmaps say Complete.
- [ ] `bash scripts/verify.sh` passes; the site deploys.
