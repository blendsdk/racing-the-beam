#!/bin/bash
set -e

# =============================================================================
# Description: Capture a Stella screenshot of the Lesson 02 landmark ROM.
# Produces the three colored bands (red/green/blue) that the ROM draws.
# Output: docs/public/images/lesson02/landmark-rom.png
# =============================================================================

ROM="build/lesson02.bin"
OUT_DIR="docs/public/images/lesson02"
OUT="$OUT_DIR/landmark-rom.png"

mkdir -p "$OUT_DIR"

# 1. Launch Stella on the live X11 display
DISPLAY=:1 stella "$ROM" &
STELLA_PID=$!

# 2. Wait for render
sleep 4

# 3. Find the Stella window and capture it
WINDOW_ID=$(xwininfo -display :1 -root -tree | grep -i "stella" | head -1 | awk '{print $1}')
import -display :1 -window "$WINDOW_ID" "$OUT"

# 4. Kill Stella
kill $STELLA_PID

echo "=== Captured $OUT ==="
