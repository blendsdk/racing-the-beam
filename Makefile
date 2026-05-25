# =============================================================================
# Atari 2600 Development — Makefile
# =============================================================================
# Usage:
#   make          — Assemble the ROM
#   make run      — Assemble and launch in Stella
#   make clean    — Remove build artifacts
# =============================================================================

# --- Tools ---
ASM      = acme
EMU      = stella

# --- Directories ---
SRC_DIR  = src
BUILD_DIR = build

# --- Files ---
SOURCE   = $(SRC_DIR)/main.asm
ROM      = $(BUILD_DIR)/game.bin

# --- Assembler flags ---
# -f plain    : output raw binary (no headers)
# -o <file>   : output file path
# --cpu 6502  : target CPU (also set in source with !cpu)
ASM_FLAGS = -f plain -o $(ROM)

# =============================================================================

.PHONY: all run clean

all: $(ROM)

$(ROM): $(SOURCE) include/vcs.asm include/macro.asm | $(BUILD_DIR)
	@echo "=== Assembling $(SOURCE) ==="
	$(ASM) $(ASM_FLAGS) $(SOURCE)
	@echo "=== Built $(ROM) ($$(wc -c < $(ROM)) bytes) ==="

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

run: $(ROM)
	@echo "=== Launching Stella ==="
	$(EMU) $(ROM) &

clean:
	rm -rf $(BUILD_DIR)
	@echo "=== Cleaned ==="
