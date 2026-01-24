<div align="center">

# The Killing Antidote Puzzle Solver

### *"I'll solve every puzzle... just for you~"*

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-red.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Python](https://img.shields.io/badge/Python-3.12+-blue.svg)](https://python.org/)
[![Go](https://img.shields.io/badge/Go-1.21+-00ADD8.svg)](https://golang.org/)

*A solver for the data recovery grid puzzles in The Killing Antidote*

---

</div>

## About

**The Killing Antidote Puzzle Solver** is a tool designed to conquer the data recovery puzzles found in the game *The Killing Antidote*. These puzzles present you with a grid where you must fill cells with values 0-3 to satisfy row and column sum constraints, while respecting forced blank positions.

This solver is available in two versions:
- **Python** - Uses PuLP (integer linear programming) for guaranteed optimal solutions
- **Go** - Uses backtracking with constraint propagation for fast native execution

---

## How It Works

The puzzles in *The Killing Antidote* are constraint satisfaction problems:

1. **Grid Structure** - An N×M grid where each cell can contain values 0, 1, 2, or 3
2. **Row Sums** - Each row must sum to a specified target value
3. **Column Sums** - Each column must sum to a specified target value
4. **Forced Blanks** - Certain cells are marked as "M" and must remain 0

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
<td width="50%">

### Python Version
- Integer Linear Programming (ILP) via PuLP
- Guaranteed optimal solution finding
- CBC solver (bundled with PuLP)
- Cross-platform compatibility

</td>
<td width="50%">

### Go Version
- Backtracking with pruning
- No external dependencies
- Single static binary
- Fast native execution

</td>
</tr>
</table>

---

## Installation

### Python Version

<details>
<summary><b>Linux</b></summary>

```bash
# Clone the repository
git clone https://github.com/japaneseenrichmentorganization/thekillingantidotepuzzlesolver.git
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

Or create a `requirements.txt` file:
```bash
echo "pulp" > requirements.txt
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
git clone https://github.com/japaneseenrichmentorganization/thekillingantidotepuzzlesolver.git
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
git clone https://github.com/japaneseenrichmentorganization/thekillingantidotepuzzlesolver.git
cd thekillingantidotepuzzlesolver

# Build the executable
go build -o puzzle_solver.exe puzzle_solver.go

# Run the solver
.\puzzle_solver.exe
```

**3. (Optional) Add to PATH**

Move `puzzle_solver.exe` to a directory in your PATH, or add the current directory to your PATH.

</details>

---

## Usage

Both versions work identically through interactive prompts:

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

### Step 3: Enter Blank Patterns

For each row, enter a pattern where:
- `0` = cell can be any value (0-3)
- `M` = cell is forced to be 0 (blank)

```
Enter pattern for row 1 (e.g., '00M0M000' where M=forced 0):
00M0M000
Enter pattern for row 2:
0M000M00
...
```

### Example Output

```
Your flawless solved grid~
Column sums → 8 8 3 9 3 12 8 6
             ┌───────────────────────────┐
       8    │ ■■ │ ■■■ │ □ │ ■ │ □ │ ■■ │ □ │ □ │
             │                           │
       7    │ ■ │ □ │ ■ │ ■■ │ □ │ ■■■ │ □ │ □ │
             └───────────────────────────┘

Legend: □=0, ■=1, ■■=2, ■■■=3
All yours, forever~
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Row sums and column sums don't total the same" | Verify your input - the sum of all row targets must equal the sum of all column targets |
| "Pattern length doesn't match columns" | Each pattern must have exactly as many characters as there are columns |
| "No solution found" | Double-check all inputs match the puzzle exactly |
| PuLP solver issues (Python) | Try installing GLPK as backup: `pip install glpk` |

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
