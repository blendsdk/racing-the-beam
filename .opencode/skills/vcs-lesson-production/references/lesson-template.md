# Lesson Document Template

The six finished lessons (01–06) define this structure. Match it — consistency across the
course is a stated requirement, and readers learn the rhythm of a lesson.

## Structure, top to bottom

````markdown
---
title: "Lesson NN: <Title> — <Subtitle>"
description: "<One sentence that names the concepts and what the reader builds.>"
prev:
  text: "Lesson NN-1: <previous title>"
  link: "/partX-topic/NN-1-slug"
next:
  text: "Lesson NN+1: <next title>"
  link: "/partX-topic/NN+1-slug"
---

# Lesson NN: <Title> — <Subtitle>

> **Part X: <Part name>** · Estimated time: NN minutes
> **Prerequisites:** Lesson A (topic), Lesson B (topic)
> **You will learn:** <concepts, as a list in prose>
> **You will build:** <the concrete ROM the reader will run>

## Introduction

Two or three short paragraphs. Start from what the reader already knows (reference the
previous lessons), introduce the problem this lesson solves, and promise the concrete result
("the companion program `NN-slug.asm` makes this visible: …").

::: details TypeScript Equivalent
Translate the core concept into TypeScript the reader likely knows (variables, arrays,
functions). Explain where the analogy breaks — that is where assembly's real constraint lives.
:::

## Theory

### Section 1: <First concept>

Explain with short paragraphs, a table where a table helps, and inline `code`. Introduce new
instructions exactly when needed, with a one-line meaning and an example.

::: tip <Practical note>
Side notes that answer "why is it like this?" or "what will bite me later?".
:::

### Section 2: <Second concept>
…

## The Code

### Building This Lesson

```bash
npm run roms      # assemble every lesson ROM into docs/public/roms/
# or just this one:
acme -f plain -o build/lessonNN.bin lessons/partX-topic/NN-slug/NN-slug.asm
stella build/lessonNN.bin
```

### Full Source

The complete annotated source (keep the in-page copy readable; the file remains the full one):

```asm
; ... fully commented lesson source ...
```

> The complete, fully-commented source lives in
> `lessons/partX-topic/NN-slug/NN-slug.asm`.

### Code Walkthrough

#### Step 1 — <what happens>
Short snippet + why. Every non-obvious instruction gets its meaning stated in comments and
in prose.
…

## What You Should See

Describe the exact picture (colors, positions, motion). Then:

![<Alt text describing exactly what the screenshot shows>](/images/lessonNN/description.png)

<RomPlayer rom="/roms/partX-topic/NN-slug/NN-slug.bin" title="Lesson NN — <Title>" />

Add a short "open the debugger and check …" paragraph: which RAM addresses hold what, which
TIA state to inspect.

## Exercises

### Exercise 1: <Name>
**Challenge:** <what to do, building on the lesson>
**Hints:** 1. … 2. … 3. …
**Expected Result:** <what the reader should see / verify>
**Solution:** See `exercise-01-solution.asm`

(Two or three exercises; the last may be marked *(Stretch Goal)*. Every exercise ships a
solution file that assembles and actually solves it.)

## Key Takeaways

- ✅ <one sentence per takeaway, 5–7 of them, covering the lesson's concepts>

## What's Next

One or two sentences linking to the next lesson and naming what it adds
(`[Lesson NN+1: …](/partX-topic/NN+1-slug)`).
````

## Content rules

- **Never forward-reference** a concept the reader has not met (preflight checks this).
- **Every claim about timing or hardware** follows the claim discipline in `atari-2600-expert`
  (observed / documented / derived). No invented numbers.
- **The TypeScript-equivalent blocks are the course's signature** — one per major concept area,
  honest about where the analogy fails.
- **Code in the document is the teaching copy**; the `.asm` file is the complete reference.
  They must be the same program — verify by assembling the file, not the snippet.
- **Exercise solutions are part of the lesson deliverable**, named `exercise-NN-solution.asm`.
- Keep the lesson's "You will build" promise true: the demo must produce exactly what the
  "What You Should See" section describes.

## Theory demo ROMs

Theory lessons (number systems, registers, addressing modes) still ship a visual: a standalone
`demo-NN.asm` that turns the abstract concept into colors or bands on screen, referenced from
the lesson text ("The demo program `demo-NN.asm` visualizes this concept…"). It builds through
`npm run roms` like any lesson source.
