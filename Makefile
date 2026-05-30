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

.PHONY: all run clean roms lesson01 demo01 lesson02 lesson03


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

# Build all lesson ROMs into docs/public/roms/ (published, committed assets)
roms:
	@echo "=== Building all lesson ROMs ==="
	bash scripts/build-roms.sh

# =============================================================================
# Lesson Targets
# =============================================================================


# --- Lesson 01: Number Systems ---
lesson01: | $(BUILD_DIR)
	@echo "=== Building Lesson 01: Number Systems ==="
	$(ASM) -f plain -o $(BUILD_DIR)/lesson01.bin lessons/part0-foundations/01-number-systems/01-number-systems.asm
	@echo "=== Built $(BUILD_DIR)/lesson01.bin ($$(wc -c < $(BUILD_DIR)/lesson01.bin) bytes) ==="

demo01: | $(BUILD_DIR)
	@echo "=== Building Demo 01: Hex Color Chart ==="
	$(ASM) -f plain -o $(BUILD_DIR)/demo01.bin lessons/part0-foundations/01-number-systems/demo-01.asm
	@echo "=== Built $(BUILD_DIR)/demo01.bin ($$(wc -c < $(BUILD_DIR)/demo01.bin) bytes) ==="

# --- Lesson 02: Meet Stella — Your Debugger and Best Friend ---
lesson02: | $(BUILD_DIR)
	@echo "=== Building Lesson 02: Meet Stella ==="
	$(ASM) -f plain -o $(BUILD_DIR)/lesson02.bin lessons/part0-foundations/02-stella-debugger/02-stella-debugger.asm
	@echo "=== Built $(BUILD_DIR)/lesson02.bin ($$(wc -c < $(BUILD_DIR)/lesson02.bin) bytes) ==="

# --- Lesson 03: Anatomy of the Atari 2600 ---
lesson03: | $(BUILD_DIR)
	@echo "=== Building Lesson 03: Anatomy of the Atari 2600 ==="
	$(ASM) -f plain -o $(BUILD_DIR)/lesson03.bin lessons/part0-foundations/03-anatomy-of-2600/03-anatomy-of-2600.asm
	@echo "=== Built $(BUILD_DIR)/lesson03.bin ($$(wc -c < $(BUILD_DIR)/lesson03.bin) bytes) ==="
