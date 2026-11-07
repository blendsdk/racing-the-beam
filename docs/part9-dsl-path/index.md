# Part 9: The DSL Path

> 🧭 **The Big Idea — Virtual Video Memory.** The 2600 has no frame buffer; every pixel is "raced" in real time. But what if you defined a *virtual* screen that exists only at design time, and a compiler "lowered" it into a cycle-exact kernel plus data tables? That's the founding idea behind every high-level 2600 tool — and this part shows how it works.

Analyze how batari BASIC turns a high-level program into a beam-racing kernel, identify the patterns that can be automated, and design your own code-generation architecture.

## Lessons

| # | Lesson | Status |
|---|--------|--------|
| 66 | [Analyzing batari BASIC — How bB Works](./66-analyzing-batari-basic) | ✅ Complete |
| 67 | [Identifying Automatable Patterns](./67-automatable-patterns) | ✅ Complete |
| 68 | [Designing Your Kernel Architecture](./68-kernel-architecture) | 🔒 Coming Soon |

## What You'll Learn

Part 9 moves from reading a compiler's output to writing the generator:

- **Lesson 66** reads a real batari BASIC 1.9 compilation: the four-stage pipeline, the generated `start`/`drawscreen`/2-line kernel/`vblank` hook/overscan, the reversed `if` lowering, the BCD score, and the fixed zero-page variable map, with a hand-written three-lens viewer and the real bB reference ROM side by side
- **Lesson 67** turns a repeated wave pattern into a small wave-spec language and a Python generator that emits the assembly tables; the playable wave lab runs two generated levels
- **Lesson 68** designs a kernel architecture: `include/kernel_framework.asm` composes configurable display zones, a build-time check enforces the 192-line budget, and three layouts share the same macros

By the end of Part 9 you can read generated 2600 code, separate the data from the engine, define a description format that a machine can validate, and design a kernel framework that turns a layout into a cycle-counted frame.
