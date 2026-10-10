#!/usr/bin/env bash
# =============================================================================
# verify.sh — Full project verification for Racing the Beam
# =============================================================================
#
# This is the single verify command for the repository. It checks three things:
#
#   1. The starter ROM (src/main.asm) assembles cleanly with ACME.
#   2. Every lesson source (lessons/**/*.asm) assembles and produces output
#      byte-identical to the committed ROM under docs/public/roms/.
#      Lesson ROMs are committed assets, so this catches "source changed but
#      the committed .bin was never regenerated" drift.
#   3. The VitePress site builds without errors (npm run docs:build).
#
# Usage:
#   bash scripts/verify.sh              # full verification
#   bash scripts/verify.sh --no-docs    # skip the docs build (faster, ROMs only)
#
# Exit codes:
#   0  everything passed
#   1  a tool is missing, an assembly failed, a ROM drifted, or docs failed
#
# When a ROM has drifted, regenerate and commit it:
#   npm run roms && git add docs/public/roms && git commit
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RUN_DOCS=1
if [[ "${1:-}" == "--no-docs" ]]; then
  RUN_DOCS=0
fi

# All temporary build output goes into one scratch directory that is removed
# on exit — verification must never dirty the repository.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

failures=0

note()  { printf '%s\n' "$*"; }
fail()  { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }

# --- Tool check -------------------------------------------------------------
command -v acme >/dev/null 2>&1 || {
  echo "ERROR: 'acme' not found on PATH. Install ACME (apt: sudo apt install acme)." >&2
  exit 1
}

# --- 1. Starter ROM ---------------------------------------------------------
note "=== [1/3] Assembling starter ROM (src/main.asm) ==="
if acme -f plain -o "$WORK/main.bin" src/main.asm; then
  note "    OK ($(wc -c < "$WORK/main.bin") bytes)"
else
  fail "src/main.asm did not assemble"
fi

# --- 2. Lesson ROM drift check ---------------------------------------------
# Assemble every lesson source into the scratch directory and compare each
# output with the committed ROM. Missing or different files are reported.
note "=== [2/3] Checking lesson ROMs against committed artifacts ==="
shopt -s nullglob globstar
checked=0
for src in lessons/**/*.asm; do
  rel="${src#lessons/}"                                  # part/slug/name.asm
  expected="docs/public/roms/${rel%.asm}.bin"
  actual="$WORK/${rel%.asm}.bin"

  mkdir -p "$(dirname "$actual")"
  if ! acme -f plain -o "$actual" "$src" >/dev/null; then
    fail "assembly failed: $src"
    continue
  fi
  checked=$((checked + 1))

  if [[ ! -f "$expected" ]]; then
    fail "missing committed ROM (run: npm run roms): $expected"
  elif ! cmp -s "$actual" "$expected"; then
    fail "ROM drift (source newer than committed ROM): $expected"
  fi
done
note "    Checked $checked lesson source file(s)"

# --- 3. VitePress build -----------------------------------------------------
if [[ "$RUN_DOCS" -eq 1 ]]; then
  note "=== [3/3] Building VitePress site ==="
  if npm run docs:build; then
    note "    OK"
  else
    fail "npm run docs:build failed"
  fi
else
  note "=== [3/3] Skipped docs build (--no-docs) ==="
fi

# --- Result -----------------------------------------------------------------
if [[ "$failures" -gt 0 ]]; then
  echo ""
  echo "=== VERIFY FAILED: $failures problem(s) ==="
  exit 1
fi
echo ""
echo "=== VERIFY PASSED ==="
