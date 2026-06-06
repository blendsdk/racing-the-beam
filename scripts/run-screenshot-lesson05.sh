#!/bin/bash
set -e

# =============================================================================
# Description: Build the Lesson 05 ROM and capture a Stella screenshot.
# The ROM is a "calculator" that paints four colored zones: NumA, NumB,
# their sum (ADC), and their difference (SBC).
# Output: docs/public/images/lesson05/calculator-demo.png
# =============================================================================

SRC="lessons/part1-6502-cpu/05-arithmetic/05-arithmetic.asm"
ROM="build/lesson05.bin"
OUT_DIR="docs/public/images/lesson05"
OUT="$OUT_DIR/calculator-demo.png"

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
