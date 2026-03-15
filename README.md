<div align="center">

# The Killing Antidote Puzzle Solver

### *"I'll solve every puzzle... just for you~"*

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-red.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![C](https://img.shields.io/badge/C-C23-A8B9CC.svg)](https://en.wikipedia.org/wiki/C23_(C_standard_revision))
[![Python](https://img.shields.io/badge/Python-3.12+-blue.svg)](https://python.org/)
[![Go](https://img.shields.io/badge/Go-1.21+-00ADD8.svg)](https://golang.org/)
[![Rust](https://img.shields.io/badge/Rust-1.70+-CE422B.svg)](https://www.rust-lang.org/)
[![D](https://img.shields.io/badge/D-2.100+-B7472A.svg)](https://dlang.org/)
[![Bash](https://img.shields.io/badge/Bash-5.0+-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![MSan](https://img.shields.io/badge/MSan-Clean-brightgreen.svg)](#sanitizer--fuzzer-testing)
[![ASan](https://img.shields.io/badge/ASan-Clean-brightgreen.svg)](#sanitizer--fuzzer-testing)
[![AFL++](https://img.shields.io/badge/AFL++-0%20crashes-brightgreen.svg)](#sanitizer--fuzzer-testing)

*A solver for the data recovery grid puzzles in The Killing Antidote*

---

</div>

## About

**The Killing Antidote Puzzle Solver** is a tool designed to conquer the data recovery puzzles found in the game *The Killing Antidote*. These puzzles present you with a grid where you must fill cells with values 0-3 to satisfy row and column sum constraints, while respecting forced blank positions.

This solver is available in **six versions** — pick whichever language lives on your machine~:

- **C** — Recursive backtracking with constraint propagation, UPX-compressed binaries under 10KB. Optional OpenMP parallel build for large puzzles.
- **Python** — Uses PuLP (integer linear programming) for guaranteed optimal solutions
- **Go** — Backtracking with constraint propagation, no external dependencies, single static binary
- **Rust** — Backtracking solver, compiled to a single native binary, no Cargo dependencies needed
- **D** — Backtracking solver using D's standard library POSIX bindings
- **Bash** — Pure Bash fallback, no compilation required

All versions share an **interactive arrow-key editor** for entering forced blank patterns, and prompt you to solve another puzzle when done~

---

## How It Works

The puzzles in *The Killing Antidote* are constraint satisfaction problems:

1. **Grid Structure** — An N×M grid where each cell can contain values 0, 1, 2, or 3
2. **Row Sums** — Each row must sum to a specified target value
3. **Column Sums** — Each column must sum to a specified target value
4. **Forced Blanks** — Certain cells are marked as "M" and must remain 0

The solver takes your input (column sums, row sums, and blank patterns) and finds a valid solution that satisfies all constraints.

### Visual Output

Solutions are displayed with symbols for clarity:
| Value | Symbol |
|-------|--------|
| 0 | `□` |
| 1 | `■` |
| 2 | `■■` |
| 3 | `■■■` |

---

## Features

<table>
<tr>
<td width="33%">

### C Version
- Recursive backtracking with pruning
- Zero dynamic memory allocation
- Static stack-based arrays
- **OpenMP parallel build** (16-core speedup)
- UPX-compressed (~8-10KB)
- MSan/ASan/AFL++ tested
- Cross-platform (Linux + Windows)

</td>
<td width="33%">

### Python Version
- Integer Linear Programming (ILP) via PuLP
- Guaranteed optimal solution finding
- CBC solver (bundled with PuLP)
- Cross-platform compatibility

</td>
<td width="33%">

### Go Version
- Backtracking with pruning
- No external dependencies
- Single static binary
- Fast native execution

</td>
</tr>
<tr>
<td width="33%">

### Rust Version
- Backtracking with pruning
- Single-file, no `Cargo.toml` needed
- Compiled with `rustc` directly
- Raw terminal via `stty` + `/dev/tty`

</td>
<td width="33%">

### D Version
- Backtracking with pruning
- POSIX termios via D stdlib
- Single-file, compiled with `dmd` or `ldc2`

</td>
<td width="33%">

### Bash Version
- Pure Bash, no compilation
- Works anywhere Bash 5+ is installed
- Great for quick one-offs on any Linux box

</td>
</tr>
</table>

### Interactive Editor (all versions) 💕

When running in a terminal, blank pattern entry is fully interactive~

- Each row pre-fills with all `0`s
- Use **← →** arrow keys to move the cursor
- Press **M** to toggle the cell under the cursor between `0` (normal) and `M` (forced blank)
- The cursor cell is highlighted with reverse video so you always know where you are
- Press **Enter** to confirm the row and move on

When stdin is piped (automated use / scripting), all versions automatically fall back to the original plain-text `00M0M000` input format — no flags needed~

---

## Pre-built Binaries

Pre-compiled, UPX-compressed binaries are available in [Releases](https://github.com/blubskye/thekillingantidotepuzzlesolver/releases):

| Platform | Binary | Size | Signed |
|----------|--------|------|--------|
| Linux x86_64 | `puzzle_solver-linux-amd64` | ~8 KB | N/A |
| Windows x86_64 | `puzzle_solver-windows-amd64.exe` | ~12 KB | Yes (self-signed) |

Just download and run -- no dependencies needed.

### Why is the Windows binary signed?

The Windows binary is built with aggressive size optimizations (`-Os -flto -s`) and compressed with UPX. These techniques are also used by malware packers, which causes many antivirus engines to flag the binary as suspicious even though it is clean.

The binary is signed with a self-signed Authenticode certificate using `osslsigncode` to give AV scanners and Windows SmartScreen a trust anchor. Because it is **self-signed** (not issued by a commercial CA like DigiCert), Windows will still show an "Unknown Publisher" SmartScreen prompt on first run -- this is expected and safe to dismiss.

The public certificate (`certs/signing.crt`) is included in the repository so you can verify the signature yourself:

```bash
# Verify the signature (requires osslsigncode)
osslsigncode verify -in puzzle_solver-windows-amd64.exe -CAfile certs/signing.crt
```

If you are still concerned, you can build from source in under 30 seconds -- see the [C Version build instructions](#c-version-build-from-source) below.

---

## Installation

### C Version (Build from Source)

<details>
<summary><b>Linux</b></summary>

```bash
# Clone the repository
git clone https://github.com/blubskye/thekillingantidotepuzzlesolver.git
cd thekillingantidotepuzzlesolver

# Build (requires gcc)
make all

# Or build the OpenMP parallel version (for large puzzles on multi-core CPUs)
make parallel

# Or build size-optimized with UPX
gcc -std=c23 -Os -flto -s -ffunction-sections -fdata-sections \
    -Wl,--gc-sections -fno-asynchronous-unwind-tables -fno-ident \
    -Wl,--build-id=none -o puzzle_solver puzzle_solver.c
upx --best puzzle_solver  # optional

# Run the solver
./puzzle_solver
```

</details>

<details>
<summary><b>Windows (cross-compile from Linux)</b></summary>

```bash
# Requires mingw-w64
x86_64-w64-mingw32-gcc -std=c23 -Os -flto -s -ffunction-sections -fdata-sections \
    -Wl,--gc-sections -fno-asynchronous-unwind-tables -fno-ident \
    -Wl,--build-id=none -mcrtdll=ucrt -o puzzle_solver.exe puzzle_solver.c
upx --best puzzle_solver.exe  # optional
```

> Note: `-mcrtdll=ucrt` links against the Universal C Runtime (built into Windows 10+) instead of the MinGW CRT shim, reducing binary size by ~60%.

</details>

---

### Python Version

<details>
<summary><b>Linux</b></summary>

```bash
# Clone the repository
git clone https://github.com/blubskye/thekillingantidotepuzzlesolver.git
cd thekillingantidotepuzzlesolver

# Install Python 3.12+ if not already installed
sudo apt update
sudo apt install python3 python3-pip

# Install dependencies
pip install pulp

# Verify installation
python3 -c "import pulp; print('Ready to solve puzzles~')"

# Run the solver
python3 puzzle_solver.py
```

</details>

<details>
<summary><b>Windows</b></summary>

**1. Install Python**
- Download Python 3.12+ from [python.org](https://www.python.org/downloads/)
- Run the installer and **check "Add Python to PATH"**

**2. Install dependencies**
```powershell
pip install pulp
```

**3. Verify installation**
```powershell
python -c "import pulp; print('Ready to solve puzzles~')"
```

**4. Run the solver**
```powershell
python puzzle_solver.py
```

</details>

#### pip Requirements

The Python version requires only one dependency:

```
pulp
```

Install with:
```bash
pip install pulp
```

Or use the included `requirements.txt`:
```bash
pip install -r requirements.txt
```

---

### Go Version (Build from Source)

<details>
<summary><b>Linux</b></summary>

**1. Install Go**

```bash
# Using package manager (Ubuntu/Debian)
sudo apt update
sudo apt install golang-go

# Or download from golang.org
wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Verify installation
go version
```

**2. Clone and build**

```bash
# Clone the repository
git clone https://github.com/blubskye/thekillingantidotepuzzlesolver.git
cd thekillingantidotepuzzlesolver

# Build the binary
go build -o puzzle_solver puzzle_solver.go

# Run the solver
./puzzle_solver
```

**3. (Optional) Install globally**

```bash
sudo mv puzzle_solver /usr/local/bin/
```

</details>

<details>
<summary><b>Windows</b></summary>

**1. Install Go**
- Download Go from [go.dev/dl](https://go.dev/dl/)
- Run the MSI installer
- Verify installation:
```powershell
go version
```

**2. Clone and build**

```powershell
# Clone the repository
git clone https://github.com/blubskye/thekillingantidotepuzzlesolver.git
cd thekillingantidotepuzzlesolver

# Build the executable
go build -o puzzle_solver.exe puzzle_solver.go

# Run the solver
.\puzzle_solver.exe
```

</details>

---

### Rust Version (Build from Source)

<details>
<summary><b>Linux</b></summary>

**1. Install Rust**

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
rustc --version
```

**2. Clone and build**

```bash
git clone https://github.com/blubskye/thekillingantidotepuzzlesolver.git
cd thekillingantidotepuzzlesolver

# Single-file compile — no Cargo.toml needed~
rustc -O -o puzzle_solver puzzle_solver.rs

./puzzle_solver
```

</details>

---

### D Version (Build from Source)

<details>
<summary><b>Linux</b></summary>

**1. Install DMD or LDC**

```bash
# DMD (reference compiler)
sudo apt install dmd-compiler

# Or LDC (LLVM-based, faster output)
sudo apt install ldc
```

**2. Clone and build**

```bash
git clone https://github.com/blubskye/thekillingantidotepuzzlesolver.git
cd thekillingantidotepuzzlesolver

# With DMD
dmd -O -release -of=puzzle_solver puzzle_solver.d

# Or with LDC
ldc2 -O2 -release -of=puzzle_solver puzzle_solver.d

./puzzle_solver
```

</details>

---

### Bash Version

No compilation needed — just run it~

```bash
git clone https://github.com/blubskye/thekillingantidotepuzzlesolver.git
cd thekillingantidotepuzzlesolver

chmod +x puzzle_solver.sh
./puzzle_solver.sh
```

Requires Bash 5.0+ (standard on any modern Linux distro).

---

## Usage

All versions work identically through interactive prompts~

### Step 1: Enter Column Sums

```
Enter column sums (space-separated, e.g., '8 8 3 9 3 12 8 6'):
8 8 3 9 3 12 8 6
```

### Step 2: Enter Row Sums

```
Enter row sums (space-separated, e.g., '8 7 6 9 8 4 9 6'):
8 7 6 9 8 4 9 6
```

### Step 3: Mark Forced Blanks (Interactive)

Each row opens with an interactive editor pre-filled with `0`s:

```
Navigate each row with ← →, press M to mark a forced blank~ ♡
Row 1~ (← → move, M toggle, Enter confirm~): 00[M]0M000
```

- **← →** — move the cursor left/right
- **M** — toggle the highlighted cell between `0` and `M`
- **Enter** — confirm the row
- **Ctrl+C** — exit at any time

> When piping input from a file (scripting/automation), the interactive editor is skipped and the original text format is used instead:
> ```
> Enter pattern for row 1 (e.g., '00M0M000' where M=forced 0):
> 00M0M000
> ```

### Step 4: Done! Play Again?

After the solution is printed, you'll be asked~:

```
Shall we dance in the dark together again, or is this our last goodbye~? (y/n):
```

Type `y` to solve another puzzle, anything else to exit.

### Example Output

```
Your flawless solved grid~ ♡
Column sums → 8 8 3 9 3 12 8 6
             ┌───────────────────────────┐
       8    │ ■■ │ ■■■ │ □ │ ■ │ □ │ ■■ │ □ │ □ │
             │                           │
       7    │ ■ │ □ │ ■ │ ■■ │ □ │ ■■■ │ □ │ □ │
             └───────────────────────────┘

Legend: □=0, ■=1, ■■=2, ■■■=3
All yours, forever~ 💕🩸
```

---

## Sanitizer & Fuzzer Testing

The C version has been verified with multiple sanitizers and a fuzzer to ensure memory safety and robustness.

### Makefile Targets

```bash
make all       # Default build (gcc -O2)
make msan      # Memory Sanitizer (clang -fsanitize=memory)
make asan      # Address Sanitizer (clang -fsanitize=address)
make afl       # AFL++ instrumented build (afl-gcc-fast)
make o3lto     # Optimized build (gcc -O3 -flto)
make parallel  # OpenMP parallel build (gcc -O3 -flto -fopenmp) — for large puzzles on multi-core~
make release   # UPX-compressed Linux + Windows release binaries
make clean     # Remove all build artifacts
```

### OpenMP Parallel Build

For large puzzles (big grids, high constraint density) the single-threaded backtracker can be slow. The parallel build spreads the search across all available CPU cores:

- OpenMP is detected automatically at runtime — thread count matches your logical CPU count
- Uses `schedule(dynamic, 1)` so threads that finish early steal remaining work items
- A `g_done` flag lets all threads bail out the moment any one finds a solution
- Falls back to single-threaded for very small puzzles where parallelism adds overhead

```bash
make parallel
./puzzle_solver_parallel
```

You can override the thread count manually:
```bash
OMP_NUM_THREADS=8 ./puzzle_solver_parallel
```

### Automated Test Pipeline

```bash
./run_tests.sh
```

Runs all 4 stages automatically with a test corpus of 5 puzzle inputs:

| Stage | Tool | Result |
|-------|------|--------|
| MSan | `clang -fsanitize=memory -fsanitize-memory-track-origins=2` | Clean — zero uninitialized reads |
| ASan | `clang -fsanitize=address` | Clean — zero buffer overflows |
| AFL++ | `afl-gcc-fast` + `afl-fuzz` (60s session) | 61,177 execs, 0 crashes |
| O3+LTO | `gcc -O3 -flto` | Output matches default build |

### Binary Size Comparison

| Build | Size |
|-------|------|
| `gcc -O2` (default) | 24,560 B |
| `gcc -O3 -flto` | 17,120 B |
| `gcc -Os -flto -s` + gc-sections | 11,072 B |
| + UPX `--best` (Linux) | **7,684 B** |
| + UPX `--best` (Windows, ucrt) | **9,728 B** |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Row sums and column sums don't total the same" | Verify your input — the sum of all row targets must equal the sum of all column targets |
| "Pattern length doesn't match columns" | Each pattern must have exactly as many characters as there are columns |
| "No solution found" | Double-check all inputs match the puzzle exactly |
| Arrow keys not working | Make sure you're running in a real terminal, not a dumb pipe or some IDE consoles |
| PuLP solver issues (Python) | Try installing GLPK as backup: `pip install glpk` |
| Rust compile error | Ensure `rustc` 1.70+ — the file uses `let-else` and other modern features |
| D compile error | Ensure DMD 2.100+ or LDC 1.30+ |

---

## Credits

| Contributor | Role |
|-------------|------|
| **blubskye** | Project Creator |

---

## License

This project is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**

### What This Means

| You CAN | You MUST | You CANNOT |
|---------|----------|------------|
| Use for any purpose | Keep it open source | Make it closed source |
| Modify the code | Publish modified source | Remove license notices |
| Distribute copies | State your changes | Keep modifications private |

See the [LICENSE](LICENSE) file for the full legal text.

---

<div align="center">

**Made for The Killing Antidote players**

*Because those puzzles can be brutal~*

---

**Copyright (c) 2026 BlubSkye** | [blubaustin@gmail.com](mailto:blubaustin@gmail.com)

</div>
