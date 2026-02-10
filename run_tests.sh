#!/usr/bin/env bash
#
# run_tests.sh -- Automated test pipeline for puzzle_solver.c
#
# Stages:
#   1. MSan build + run test corpus
#   2. ASan build + run test corpus
#   3. AFL build + short fuzzing session (60s)
#   4. O3+LTO build + correctness verification

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CORPUS_DIR="test/corpus"
PASS=0
FAIL=0
TOTAL=0

# Color codes
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BOLD='' NC=''
fi

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }
log_info() { echo -e "${BOLD}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

separator() {
    echo ""
    echo "================================================================"
    echo "  $1"
    echo "================================================================"
    echo ""
}

check_corpus() {
    local missing=0
    for f in puzzle_8x8.txt puzzle_3x3.txt puzzle_4x4.txt puzzle_nosol.txt puzzle_1x1.txt; do
        if [ ! -f "$CORPUS_DIR/$f" ]; then
            log_warn "Missing corpus file: $CORPUS_DIR/$f"
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        echo "Create corpus files first. Aborting."
        exit 1
    fi
}

check_tools() {
    local ok=1
    for tool in clang gcc; do
        if ! command -v "$tool" &>/dev/null; then
            log_warn "Required tool not found: $tool"
            ok=0
        fi
    done
    if [ "$ok" -eq 0 ]; then
        echo "Missing required compilers. Aborting."
        exit 1
    fi
}

# Run a single test input against a binary
# Usage: run_single_test <binary> <input_file> <expect_exit> <label>
run_single_test() {
    local binary="$1"
    local input_file="$2"
    local expect_exit="$3"
    local label="$4"

    local exit_code=0
    RUN_OUTPUT=$("$binary" < "$input_file" 2>&1) || exit_code=$?

    if [ "$exit_code" -eq "$expect_exit" ]; then
        log_pass "$label (exit=$exit_code)"
    else
        log_fail "$label (exit=$exit_code, expected=$expect_exit)"
        echo "  Output (first 10 lines):"
        echo "$RUN_OUTPUT" | head -10 | sed 's/^/    /'
    fi
}

# Run test suite against a binary
run_test_suite() {
    local binary="$1"
    local suite_label="$2"

    log_info "Running test suite: $suite_label"

    run_single_test "$binary" "$CORPUS_DIR/puzzle_1x1.txt" 0 \
        "$suite_label: 1x1 edge case"
    run_single_test "$binary" "$CORPUS_DIR/puzzle_3x3.txt" 0 \
        "$suite_label: 3x3 all-ones puzzle"
    run_single_test "$binary" "$CORPUS_DIR/puzzle_4x4.txt" 0 \
        "$suite_label: 4x4 with forced blanks"
    run_single_test "$binary" "$CORPUS_DIR/puzzle_8x8.txt" 0 \
        "$suite_label: 8x8 canonical puzzle"
    run_single_test "$binary" "$CORPUS_DIR/puzzle_nosol.txt" 1 \
        "$suite_label: no-solution (sum mismatch)"
}

# Check for sanitizer warnings in stderr
check_sanitizer_output() {
    local binary="$1"
    local sanitizer_name="$2"
    local pattern="$3"

    local issues=0
    for f in "$CORPUS_DIR"/puzzle_*.txt; do
        local output
        output=$("$binary" < "$f" 2>&1) || true
        if echo "$output" | grep -qi "$pattern"; then
            log_fail "$sanitizer_name issue detected with $(basename "$f")"
            echo "$output" | grep -i "Sanitizer" | head -5 | sed 's/^/    /'
            issues=1
        fi
    done
    if [ "$issues" -eq 0 ]; then
        log_pass "No $sanitizer_name issues detected across all inputs"
    fi
}

# ============================================================
# STAGE 1: Memory Sanitizer
# ============================================================
stage_msan() {
    separator "STAGE 1: Memory Sanitizer (MSan) -- clang -fsanitize=memory"

    log_info "Building with MSan..."
    if ! make msan 2>&1; then
        log_fail "MSan build failed"
        return
    fi
    log_pass "MSan build succeeded"

    run_test_suite "./puzzle_solver_msan" "MSan"
    check_sanitizer_output "./puzzle_solver_msan" "MSan" \
        "MemorySanitizer\|WARNING.*uninit\|SUMMARY.*Sanitizer"
}

# ============================================================
# STAGE 2: Address Sanitizer
# ============================================================
stage_asan() {
    separator "STAGE 2: Address Sanitizer (ASan) -- clang -fsanitize=address"

    log_info "Building with ASan..."
    if ! make asan 2>&1; then
        log_fail "ASan build failed"
        return
    fi
    log_pass "ASan build succeeded"

    run_test_suite "./puzzle_solver_asan" "ASan"
    check_sanitizer_output "./puzzle_solver_asan" "ASan" \
        "AddressSanitizer\|ERROR.*Sanitizer\|SUMMARY.*Sanitizer"
}

# ============================================================
# STAGE 3: AFL++ Fuzzing
# ============================================================
stage_afl() {
    separator "STAGE 3: AFL++ Fuzzing -- afl-gcc-fast + afl-fuzz"

    # Prefer locally-built AFL++ (handles GCC version mismatches)
    local AFL_DIR="/tmp/AFLplusplus"
    local AFL_FUZZ="afl-fuzz"
    if [ -x "$AFL_DIR/afl-fuzz" ]; then
        AFL_FUZZ="$AFL_DIR/afl-fuzz"
        log_info "Using locally-built AFL++ from $AFL_DIR"
    elif ! command -v afl-fuzz &>/dev/null; then
        log_warn "afl-fuzz not found. Skipping AFL stage."
        return
    fi

    log_info "Building with AFL++ instrumentation..."
    if ! make afl 2>&1; then
        log_fail "AFL build failed"
        return
    fi
    log_pass "AFL build succeeded"

    # Smoke test
    run_single_test "./puzzle_solver_afl" "$CORPUS_DIR/puzzle_3x3.txt" 0 \
        "AFL binary: smoke test (3x3)"

    # Set up AFL directories
    local afl_input="afl_input"
    local afl_output="afl_output"
    rm -rf "$afl_input" "$afl_output"
    mkdir -p "$afl_input"
    cp "$CORPUS_DIR"/puzzle_*.txt "$afl_input/"

    log_info "Starting AFL++ fuzzing session (60 seconds)..."

    local afl_exit=0
    AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 \
    AFL_SKIP_CPUFREQ=1 \
    AFL_NO_UI=1 \
    AFL_PATH="${AFL_DIR:-}" \
        timeout 75 "$AFL_FUZZ" \
        -i "$afl_input" \
        -o "$afl_output" \
        -t 5000 \
        -V 60 \
        -m none \
        -- ./puzzle_solver_afl 2>&1 | tail -30 || afl_exit=$?

    # Check results
    if [ -d "$afl_output/default/crashes" ]; then
        local crash_count
        crash_count=$(find "$afl_output/default/crashes" -name "id:*" 2>/dev/null | wc -l)
        if [ "$crash_count" -gt 0 ]; then
            log_fail "AFL found $crash_count crash(es)!"
            echo "  Crash inputs in: $afl_output/default/crashes/"
            ls "$afl_output/default/crashes/" | head -5 | sed 's/^/    /'
        else
            log_pass "AFL fuzzing completed: no crashes found"
        fi
    else
        if [ "$afl_exit" -eq 0 ] || [ "$afl_exit" -eq 124 ]; then
            log_pass "AFL fuzzing session completed (no crashes)"
        else
            log_warn "AFL exited with code $afl_exit"
        fi
    fi

    # Report stats
    if [ -f "$afl_output/default/fuzzer_stats" ]; then
        log_info "AFL stats:"
        grep -E "^(execs_done|execs_per_sec|unique_crashes|unique_hangs|paths_total)" \
            "$afl_output/default/fuzzer_stats" | sed 's/^/    /'
    fi

    rm -rf "$afl_input"
}

# ============================================================
# STAGE 4: O3+LTO Build + Correctness
# ============================================================
stage_o3lto() {
    separator "STAGE 4: O3+LTO Build -- gcc -O3 -flto"

    log_info "Building with O3+LTO..."
    if ! make o3lto 2>&1; then
        log_fail "O3+LTO build failed"
        return
    fi
    log_pass "O3+LTO build succeeded"

    run_test_suite "./puzzle_solver_o3lto" "O3+LTO"

    # Cross-check against default build
    log_info "Cross-checking O3+LTO vs default build..."
    make all 2>&1 >/dev/null

    local out_default out_o3lto
    out_default=$(./puzzle_solver < "$CORPUS_DIR/puzzle_8x8.txt" 2>&1) || true
    out_o3lto=$(./puzzle_solver_o3lto < "$CORPUS_DIR/puzzle_8x8.txt" 2>&1) || true

    if [ "$out_default" = "$out_o3lto" ]; then
        log_pass "O3+LTO output matches default build (8x8 puzzle)"
    else
        log_fail "O3+LTO output DIFFERS from default build!"
        diff <(echo "$out_default") <(echo "$out_o3lto") | head -20 | sed 's/^/    /'
    fi

    if [ -f puzzle_solver ] && [ -f puzzle_solver_o3lto ]; then
        local size_default size_o3lto
        size_default=$(stat -c%s puzzle_solver)
        size_o3lto=$(stat -c%s puzzle_solver_o3lto)
        log_info "Binary sizes: default=${size_default}B, O3+LTO=${size_o3lto}B"
    fi
}

# ============================================================
# MAIN
# ============================================================
main() {
    separator "Puzzle Solver -- Sanitizer, Fuzzer & Optimization Test Suite"
    log_info "Working directory: $SCRIPT_DIR"
    log_info "Date: $(date)"

    check_corpus
    check_tools

    make clean 2>/dev/null || true

    stage_msan
    stage_asan
    stage_afl
    stage_o3lto

    separator "SUMMARY"
    echo -e "  ${GREEN}Passed:${NC} $PASS"
    echo -e "  ${RED}Failed:${NC} $FAIL"
    echo -e "  Total:  $TOTAL"
    echo ""

    if [ "$FAIL" -gt 0 ]; then
        echo -e "${RED}${BOLD}Some tests FAILED.${NC} Review output above."
        exit 1
    else
        echo -e "${GREEN}${BOLD}All tests PASSED.${NC}"
        exit 0
    fi
}

main "$@"
