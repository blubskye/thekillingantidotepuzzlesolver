# Makefile for puzzle_solver.c -- sanitizer, fuzzer, and optimized builds
#
# Targets:
#   all        - Default build (gcc, -O2, warnings)
#   msan       - Memory Sanitizer build (clang only)
#   asan       - Address Sanitizer build (clang)
#   afl        - AFL++ instrumented build (afl-gcc-fast)
#   o3lto      - Optimized build (-O3 -flto, gcc)
#   clean      - Remove all build artifacts

SRC       = puzzle_solver.c
CFLAGS_COMMON = -std=c11 -Wall -Wextra -Wpedantic

CC_GCC    = gcc
CC_CLANG  = clang
CC_AFL    = /tmp/AFLplusplus/afl-gcc-fast

BIN_DEFAULT = puzzle_solver
BIN_MSAN    = puzzle_solver_msan
BIN_ASAN    = puzzle_solver_asan
BIN_AFL     = puzzle_solver_afl
BIN_O3LTO   = puzzle_solver_o3lto

.PHONY: all msan asan afl o3lto clean

all: $(BIN_DEFAULT)

$(BIN_DEFAULT): $(SRC)
	$(CC_GCC) $(CFLAGS_COMMON) -O2 -g -o $@ $<

msan: $(BIN_MSAN)

$(BIN_MSAN): $(SRC)
	$(CC_CLANG) $(CFLAGS_COMMON) -O1 -g -fno-omit-frame-pointer \
		-fsanitize=memory -fsanitize-memory-track-origins=2 \
		-o $@ $<

asan: $(BIN_ASAN)

$(BIN_ASAN): $(SRC)
	$(CC_CLANG) $(CFLAGS_COMMON) -O1 -g -fno-omit-frame-pointer \
		-fsanitize=address -fno-optimize-sibling-calls \
		-o $@ $<

afl: $(BIN_AFL)

$(BIN_AFL): $(SRC)
	AFL_HARDEN=1 $(CC_AFL) $(CFLAGS_COMMON) -O2 -g -o $@ $<

o3lto: $(BIN_O3LTO)

$(BIN_O3LTO): $(SRC)
	$(CC_GCC) $(CFLAGS_COMMON) -O3 -flto -DNDEBUG -o $@ $<

clean:
	rm -f $(BIN_DEFAULT) $(BIN_MSAN) $(BIN_ASAN) $(BIN_AFL) $(BIN_O3LTO)
	rm -rf afl_output afl_input
