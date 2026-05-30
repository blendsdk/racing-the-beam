#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_ROOT="$ROOT/lessons"
OUT_ROOT="$ROOT/docs/public/roms"

command -v acme >/dev/null 2>&1 || { echo "ERROR: 'acme' not found on PATH. Install ACME to build ROMs."; exit 1; }

shopt -s nullglob globstar
count=0
for src in "$SRC_ROOT"/**/*.asm; do
  rel="${src#"$SRC_ROOT"/}"           # part/slug/name.asm
  out="$OUT_ROOT/${rel%.asm}.bin"     # docs/public/roms/part/slug/name.bin
  mkdir -p "$(dirname "$out")"
  echo "=== Assembling $rel ==="
  ( cd "$ROOT" && acme -f plain -o "$out" "$src" )
  echo "    -> ${out#"$ROOT"/} ($(wc -c < "$out") bytes)"
  count=$((count+1))
done
echo "=== Built $count ROM(s) into docs/public/roms/ ==="
