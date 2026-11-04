# Part 4: Sprites

Master player sprites, missiles, the ball, positioning tricks, and animation.

## Lessons

| # | Lesson | Status |
|---|--------|--------|
| 25 | [Player Sprite Basics — GRP0, Your First Character](./25-player-basics) | ✅ Complete |
| 26 | [Horizontal Positioning — The Divide-by-15 Trick](./26-horizontal-positioning) | ✅ Complete |
| 27 | [Sprite Movement — Reading the Joystick](./27-sprite-movement) | ✅ Complete |
| 28 | [Two Players — GRP0 and GRP1](./28-two-players) | ✅ Complete |
| 29 | [Missiles and Ball — Simple Projectiles](./29-missiles-and-ball) | ✅ Complete |
| 30 | [Multi-Color Sprites — Changing Colors Per Line](./30-multicolor-sprites) | ✅ Complete |
| 31 | [Copies and Sizes — NUSIZ Register](./31-copies-and-sizes) | 🔒 Coming Soon |
| 32 | [Vertical Delay — VDELP0, VDELP1](./32-vertical-delay) | 🔒 Coming Soon |
| 33 | [Paddle & Keyboard Controllers](./33-paddle-keyboard-controllers) | 🔒 Coming Soon |
| 34 | [Sprite Animation — Walking Cycles & Character States](./34-sprite-animation) | 🔒 Coming Soon |

## What You'll Learn

Part 4 turns the TIA's movable objects into characters, projectiles, and animation:

- **Lesson 25** draws the first player sprite and learns that vertical position is a write schedule
- **Lesson 26** positions a sprite exactly with `RESP0`, `HMP0`, and the divide-by-15 routine
- **Lesson 27** moves the sprite every frame and steers it with the joystick
- **Lesson 28** gives both players their own shape, color, and position
- **Lesson 29** enables the two missiles and the ball, with their widths and the player/playfield colors they share
- **Lesson 30** changes `COLUP0` per line for a multi-colored character
- **Lesson 31** uses `NUSIZ` for copies, double width, and quad width
- **Lesson 32** delays a player's graphic one line with `VDELP1`
- **Lesson 33** reads the paddles, the keyboard matrix, and the fire buttons
- **Lesson 34** animates a walk cycle from a four-frame table

By the end of Part 4 you can draw and position sprites, move them with the joystick, and animate
them frame by frame — the objects every later game is made of.
