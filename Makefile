# Makefile for puzzle_solver.c -- sanitizer, fuzzer, and optimized builds
#
# Targets:
#   all        - Default build (gcc, -O2, warnings)
#   msan       - Memory Sanitizer build (clang only)
#   asan       - Address Sanitizer build (clang)
#   afl        - AFL++ instrumented build (afl-gcc-fast)
#   o3lto      - Optimized build (-O3 -flto, gcc)
#   release    - Build + UPX compress both Linux and Windows binaries
#   sign       - Sign the Windows release binary (requires certs/signing.pfx)
#   gen-cert   - Generate a self-signed code signing certificate
#   clean      - Remove all build artifacts

SRC       = puzzle_solver.c
CFLAGS_COMMON = -std=c23 -Wall -Wextra -Wpedantic

CC_GCC    = gcc
CC_CLANG  = clang
CC_AFL    = /tmp/AFLplusplus/afl-gcc-fast
CC_WIN    = x86_64-w64-mingw32-gcc

BIN_DEFAULT  = puzzle_solver
BIN_MSAN     = puzzle_solver_msan
BIN_ASAN     = puzzle_solver_asan
BIN_AFL      = puzzle_solver_afl
BIN_O3LTO    = puzzle_solver_o3lto
BIN_PARALLEL = puzzle_solver_parallel
BIN_LINUX    = puzzle_solver-linux-amd64
BIN_WINDOWS  = puzzle_solver-windows-amd64.exe
BIN_WIN_SIGN = puzzle_solver-windows-amd64-signed.exe

CERT_PFX     = certs/signing.pfx
CERT_KEY     = certs/signing.key
CERT_CRT     = certs/signing.crt

SIGN_NAME    = "The Killing Antidote Puzzle Solver"
SIGN_URL     = "https://github.com/blubskye/thekillingantidotepuzzlesolver"

CFLAGS_RELEASE = $(CFLAGS_COMMON) -Os -flto -s -ffunction-sections -fdata-sections \
	-fno-asynchronous-unwind-tables -fno-ident -fmerge-all-constants
LDFLAGS_RELEASE = -Wl,--gc-sections -Wl,--build-id=none

.PHONY: all msan asan afl o3lto parallel release sign gen-cert clean

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

parallel: $(BIN_PARALLEL)

$(BIN_PARALLEL): $(SRC)
	$(CC_GCC) $(CFLAGS_COMMON) -O3 -flto -DNDEBUG -fopenmp -o $@ $<

release: $(BIN_LINUX) $(BIN_WINDOWS)

$(BIN_LINUX): $(SRC)
	$(CC_GCC) $(CFLAGS_RELEASE) $(LDFLAGS_RELEASE) -o $@ $<
	upx --best $@

$(BIN_WINDOWS): $(SRC)
	$(CC_WIN) $(CFLAGS_RELEASE) $(LDFLAGS_RELEASE) -mcrtdll=ucrt -o $@ $<
	upx --best $@

sign: $(BIN_WIN_SIGN)

$(BIN_WIN_SIGN): $(BIN_WINDOWS) $(CERT_PFX)
	osslsigncode sign \
		-pkcs12 $(CERT_PFX) \
		-pass "" \
		-n $(SIGN_NAME) \
		-i $(SIGN_URL) \
		-in $(BIN_WINDOWS) \
		-out $(BIN_WIN_SIGN)
	@echo "Signed: $(BIN_WIN_SIGN)"

gen-cert: $(CERT_PFX)

$(CERT_PFX):
	@mkdir -p certs
	openssl req -x509 -newkey rsa:4096 \
		-keyout $(CERT_KEY) -out $(CERT_CRT) \
		-days 3650 -nodes \
		-subj "/CN=The Killing Antidote Puzzle Solver/O=blubskye/C=US" \
		-addext "extendedKeyUsage=codeSigning"
	openssl pkcs12 -export \
		-out $(CERT_PFX) \
		-inkey $(CERT_KEY) -in $(CERT_CRT) \
		-passout pass:
	@echo "Certificate generated: $(CERT_PFX)"

clean:
	rm -f $(BIN_DEFAULT) $(BIN_MSAN) $(BIN_ASAN) $(BIN_AFL) $(BIN_O3LTO)
	rm -f $(BIN_LINUX) $(BIN_WINDOWS) $(BIN_WIN_SIGN)
	rm -rf afl_output afl_input
