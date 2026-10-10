#!/usr/bin/env bash
# =============================================================================
# capture-screenshot.sh — Capture a Stella screenshot of a built ROM
# =============================================================================
#
# Lesson screenshots in this course are captured from the real Stella emulator.
# This script automates the pipeline that was previously done by hand:
#
#   1. Launch Stella with the given ROM.
#   2. Wait for it to render.
#   3. Find the Stella window and capture it to a PNG with ImageMagick.
#   4. Close Stella.
#
# Usage:
#   bash scripts/capture-screenshot.sh <rom.bin> <output.png> [wait-seconds]
#
# Environment:
#   CAPTURE_DISPLAY   X11 display to use (default: $DISPLAY, else auto-detect :0).
#                     When no working X display is found and `xvfb-run` is
#                     installed, a virtual display is used instead.
#
# Examples:
#   bash scripts/capture-screenshot.sh build/lesson01.bin docs/public/images/lesson01/number-systems.png
#
# Requirements: stella, ImageMagick `import`, `xwininfo`, and an X display
# (or `xvfb-run` for a virtual one).
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Inner mode: runs on the selected display (re-invoked under xvfb-run) ----
if [[ "${1:-}" == "--inner" ]]; then
  ROM="$2"
  OUT="$3"
  WAIT="$4"

  stella "$ROM" &
  STELLA_PID=$!
  # Make sure Stella is killed even when the capture fails below.
  trap 'kill "$STELLA_PID" 2>/dev/null || true' EXIT

  sleep "$WAIT"

  WINDOW_ID="$(xwininfo -root -tree | grep -i 'stella' | head -1 | awk '{print $1}')"
  if [[ -z "$WINDOW_ID" ]]; then
    echo "ERROR: could not find the Stella window on display $DISPLAY." >&2
    exit 1
  fi

  import -window "$WINDOW_ID" "$OUT"
  echo "=== Captured $OUT ==="
  exit 0
fi

# --- Argument handling -------------------------------------------------------
if [[ $# -lt 2 ]]; then
  echo "Usage: bash scripts/capture-screenshot.sh <rom.bin> <output.png> [wait-seconds]" >&2
  exit 2
fi

ROM="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"    # absolutize before cd
OUT="$2"
WAIT="${3:-4}"

if [[ ! -f "$ROM" ]]; then
  echo "ERROR: ROM not found: $ROM" >&2
  exit 1
fi

command -v stella >/dev/null 2>&1 || { echo "ERROR: 'stella' not found on PATH." >&2; exit 1; }
command -v import >/dev/null 2>&1 || { echo "ERROR: ImageMagick 'import' not found on PATH." >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# --- Display selection -------------------------------------------------------
# Prefer an explicitly configured display, then the session display, then a
# known-working fallback (:0). If none responds and xvfb-run exists, use a
# virtual display so the script also works on headless machines and CI.
if [[ -n "${CAPTURE_DISPLAY:-}" ]]; then
  DISPLAY="$CAPTURE_DISPLAY"
elif [[ -n "${DISPLAY:-}" ]] && xwininfo -root >/dev/null 2>&1; then
  :  # the current display works as-is
elif timeout 3 xwininfo -display :0 -root >/dev/null 2>&1; then
  DISPLAY=":0"
elif command -v xvfb-run >/dev/null 2>&1; then
  echo "=== No X display found — using xvfb-run ==="
  exec xvfb-run -a -s "-screen 0 1024x768x24" \
    bash "$SELF" --inner "$ROM" "$OUT" "$WAIT"
else
  echo "ERROR: no working X display and xvfb-run is not installed." >&2
  exit 1
fi

export DISPLAY
bash "$SELF" --inner "$ROM" "$OUT" "$WAIT"
