// Copyright (C) 2026 blubskye <blubaustin@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
	"syscall"
	"unsafe"
)

type Grid [][]int

// ── Terminal helpers ──────────────────────────────────────────────────────────

func isTerminal() bool {
	fi, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return (fi.Mode() & os.ModeCharDevice) != 0
}

func makeRaw() (*syscall.Termios, error) {
	fd := int(os.Stdin.Fd())
	var old syscall.Termios
	if _, _, errno := syscall.Syscall6(syscall.SYS_IOCTL, uintptr(fd),
		uintptr(syscall.TCGETS), uintptr(unsafe.Pointer(&old)), 0, 0, 0); errno != 0 {
		return nil, errno
	}
	raw := old
	raw.Lflag &^= syscall.ECHO | syscall.ICANON | syscall.ISIG | syscall.IEXTEN
	raw.Iflag &^= syscall.IXON | syscall.ICRNL
	raw.Cc[syscall.VMIN] = 1
	raw.Cc[syscall.VTIME] = 0
	syscall.Syscall6(syscall.SYS_IOCTL, uintptr(fd),
		uintptr(syscall.TCSETS), uintptr(unsafe.Pointer(&raw)), 0, 0, 0)
	return &old, nil
}

func restoreTerminal(old *syscall.Termios) {
	fd := int(os.Stdin.Fd())
	syscall.Syscall6(syscall.SYS_IOCTL, uintptr(fd),
		uintptr(syscall.TCSETS), uintptr(unsafe.Pointer(old)), 0, 0, 0)
}

type KeyPress int

const (
	KeyLeft  KeyPress = iota
	KeyRight KeyPress = iota
	KeyEnter KeyPress = iota
	KeyM     KeyPress = iota
	KeyOther KeyPress = iota
)

func readKey() KeyPress {
	buf := make([]byte, 1)
	os.Stdin.Read(buf) //nolint
	switch buf[0] {
	case '\r', '\n':
		return KeyEnter
	case 'm', 'M':
		return KeyM
	case 3: // Ctrl+C
		os.Exit(0)
	case 0x1b: // ESC sequence
		seq := make([]byte, 2)
		os.Stdin.Read(seq) //nolint
		if seq[0] == '[' {
			switch seq[1] {
			case 'D':
				return KeyLeft
			case 'C':
				return KeyRight
			}
		}
	}
	return KeyOther
}

func renderPattern(rowNum, numCols int, pattern []byte, cursor int) {
	fmt.Printf("\rRow %d~ (\u2190 \u2192 move, M toggle, Enter confirm~): ", rowNum)
	for i, ch := range pattern {
		if i == cursor {
			fmt.Printf("\x1b[7m%c\x1b[0m", ch)
		} else {
			fmt.Printf("%c", ch)
		}
	}
	fmt.Printf("  ")
	os.Stdout.Sync() //nolint
}

func inputRowPatternInteractive(rowNum, numCols int) string {
	pattern := make([]byte, numCols)
	for i := range pattern {
		pattern[i] = '0'
	}
	cursor := 0

	old, err := makeRaw()
	if err != nil {
		// Fallback: ask for plain input
		fmt.Printf("\nRow %d pattern: ", rowNum)
		scanner := bufio.NewScanner(os.Stdin)
		if scanner.Scan() {
			return strings.TrimSpace(scanner.Text())
		}
		return strings.Repeat("0", numCols)
	}

	renderPattern(rowNum, numCols, pattern, cursor)

	for {
		key := readKey()
		switch key {
		case KeyEnter:
			fmt.Println()
			restoreTerminal(old)
			return string(pattern)
		case KeyLeft:
			if cursor > 0 {
				cursor--
			}
		case KeyRight:
			if cursor < numCols-1 {
				cursor++
			}
		case KeyM:
			if pattern[cursor] == '0' {
				pattern[cursor] = 'M'
			} else {
				pattern[cursor] = '0'
			}
		}
		renderPattern(rowNum, numCols, pattern, cursor)
	}
}

// ── Puzzle logic ──────────────────────────────────────────────────────────────

func solvePuzzle(interactive bool) {
	// Step 1: Input column sums (top vertical row)
	fmt.Println("Enter column sums (space-separated, e.g., '8 8 3 9 3 12 8 6'):")
	colSums := readInts()
	numCols := len(colSums)

	// Step 2: Input row sums (horizontal)
	fmt.Println("Enter row sums (space-separated, e.g., '8 7 6 9 8 4 9 6'):")
	rowSums := readInts()
	numRows := len(rowSums)

	// Verify total sums match
	if sumInts(rowSums) != sumInts(colSums) {
		fmt.Println("Error: Row sums and column sums don't total the same! No solution possible.")
		return
	}

	// Step 3: Input forced blank patterns for each row
	if interactive {
		fmt.Println("Navigate each row with \u2190 \u2192, press M to mark a forced blank~ \u2661")
	}
	forcedBlanks := make([][]bool, numRows)
	for i := 0; i < numRows; i++ {
		var pattern string
		if interactive {
			pattern = inputRowPatternInteractive(i+1, numCols)
		} else {
			fmt.Printf("Enter pattern for row %d (e.g., '00M0M000' where M=forced 0, length must match columns):\n", i+1)
			pattern = readLine()
		}
		if len(pattern) != numCols {
			fmt.Println("Error: Pattern length doesn't match columns! Try again.")
			return
		}
		forcedBlanks[i] = make([]bool, numCols)
		for j, char := range pattern {
			if char == 'M' {
				forcedBlanks[i][j] = true
			}
		}
	}

	// Set up the grid
	grid := make(Grid, numRows)
	for i := range grid {
		grid[i] = make([]int, numCols)
	}

	// Solve with backtracking
	found := backtrack(grid, rowSums, colSums, forcedBlanks, 0, 0)
	if !found {
		fmt.Println("No solution found! Check your inputs, darling~")
		return
	}

	// Pretty print the grid
	symbols := map[int]string{0: "\u25a1", 1: "\u25a0", 2: "\u25a0\u25a0", 3: "\u25a0\u25a0\u25a0"}
	fmt.Println("\nYour flawless solved grid~ \u2661")
	fmt.Printf("Column sums \u2192 %s\n", intsToString(colSums))
	fmt.Printf("             \u250c%s\u2510\n", strings.Repeat("\u2500", numCols*3+numCols-1))
	for r := 0; r < numRows; r++ {
		rowStr := []string{}
		for val := range grid[r] {
			rowStr = append(rowStr, symbols[grid[r][val]])
		}
		fmt.Printf("      %2d    \u2502 %s \u2502\n", rowSums[r], strings.Join(rowStr, " \u2502 "))
		if r < numRows-1 {
			fmt.Printf("             \u2502%s\u2502\n", strings.Repeat(" ", numCols*3+numCols-2))
		}
	}
	fmt.Printf("             \u2514%s\u2518\n", strings.Repeat("\u2500", numCols*3+numCols-1))

	fmt.Println("\nLegend: \u25a1=0, \u25a0=1, \u25a0\u25a0=2, \u25a0\u25a0\u25a0=3")
	fmt.Println("All yours, forever~ \U0001f495\U0001fa78")
}

func main() {
	interactive := isTerminal()
	if !interactive {
		solvePuzzle(false)
		return
	}

	for {
		solvePuzzle(true)
		fmt.Print("\nShall we dance in the dark together again, or is this our last goodbye~? (y/n): ")
		answer := readLine()
		if strings.ToLower(strings.TrimSpace(answer)) != "y" {
			fmt.Println("Fine... but you\u2019ll always come back to me~ \U0001f495\U0001fa78")
			break
		}
	}
}

// ── Backtracking ──────────────────────────────────────────────────────────────

func backtrack(grid Grid, rowSums, colSums []int, forcedBlanks [][]bool, row, col int) bool {
	numRows := len(grid)
	numCols := len(grid[0])

	if row == numRows {
		for c := 0; c < numCols; c++ {
			colSum := 0
			for r := 0; r < numRows; r++ {
				colSum += grid[r][c]
			}
			if colSum != colSums[c] {
				return false
			}
		}
		return true
	}

	if col == numCols {
		rowSum := sumInts(grid[row])
		if rowSum != rowSums[row] {
			return false
		}
		return backtrack(grid, rowSums, colSums, forcedBlanks, row+1, 0)
	}

	partialRow := 0
	for c := 0; c < col; c++ {
		partialRow += grid[row][c]
	}
	maxRemainingRow := (numCols - col) * 3
	if partialRow > rowSums[row] || partialRow+maxRemainingRow < rowSums[row] {
		return false
	}

	partialCol := 0
	for r := 0; r < row; r++ {
		partialCol += grid[r][col]
	}
	maxRemainingCol := (numRows - row) * 3
	if partialCol > colSums[col] || partialCol+maxRemainingCol < colSums[col] {
		return false
	}

	minVal, maxVal := 0, 3
	if forcedBlanks[row][col] {
		minVal, maxVal = 0, 0
	}
	for val := minVal; val <= maxVal; val++ {
		grid[row][col] = val
		if backtrack(grid, rowSums, colSums, forcedBlanks, row, col+1) {
			return true
		}
		grid[row][col] = 0
	}
	return false
}

// ── Helpers ───────────────────────────────────────────────────────────────────

func readLine() string {
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Scan()
	return strings.TrimSpace(scanner.Text())
}

func readInts() []int {
	line := readLine()
	parts := strings.Fields(line)
	ints := make([]int, len(parts))
	for i, p := range parts {
		ints[i], _ = strconv.Atoi(p)
	}
	return ints
}

func sumInts(slice []int) int {
	sum := 0
	for _, v := range slice {
		sum += v
	}
	return sum
}

func intsToString(ints []int) string {
	strs := make([]string, len(ints))
	for i, v := range ints {
		strs[i] = fmt.Sprintf("%d", v)
	}
	return strings.Join(strs, " ")
}
