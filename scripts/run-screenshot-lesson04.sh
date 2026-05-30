#!/bin/bash
set -e

# =============================================================================
# Description: Build the Lesson 04 ROM and capture a Stella screenshot.
# The ROM draws three colored zones (red/green/blue) — one per register
# (A/X/Y) round-tripped through RAM.
# Output: docs/public/images/lesson04/registers-demo.png
# =============================================================================

SRC="lessons/part1-6502-cpu/04-registers-and-memory/04-registers-and-memory.asm"
ROM="build/lesson04.bin"
OUT_DIR="docs/public/images/lesson04"
OUT="$OUT_DIR/registers-demo.png"

mkdir -p build
mkdir -p "$OUT_DIR"

# 1. Assemble the ROM
acme -f plain -o "$ROM" "$SRC"

# 2. Launch Stella on the live X11 display
DISPLAY=:1 stella "$ROM" &
STELLA_PID=$!

# 3. Wait for render
sleep 4

# 4. Find the Stella window and capture it
WINDOW_ID=$(xwininfo -display :1 -root -tree | grep -i "stella" | head -1 | awk '{print $1}')
import -display :1 -window "$WINDOW_ID" "$OUT"

# 5. Kill Stella
kill $STELLA_PID

echo "=== Captured $OUT ==="
