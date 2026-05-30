# Part 9: The DSL Path

> 🧭 **The Big Idea — Virtual Video Memory.** The 2600 has no frame buffer; every pixel is "raced" in real time. But what if you defined a *virtual* screen that exists only at design time, and a compiler "lowered" it into a cycle-exact kernel plus data tables? That's the founding idea behind every high-level 2600 tool — and this part shows how it works.

Analyze how batari BASIC turns a high-level program into a beam-racing kernel, identify the patterns that can be automated, and design your own code-generation architecture.

Browse the lessons in the sidebar to get started.
