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
)

type Grid [][]int

func main() {
	solvePuzzle()
}

func solvePuzzle() {
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
	forcedBlanks := make([][]bool, numRows)
	for i := 0; i < numRows; i++ {
		fmt.Printf("Enter pattern for row %d (e.g., '00M0M000' where M=forced 0, length must match columns):\n", i+1)
		pattern := readLine()
		if len(pattern) != numCols {
			fmt.Println("Error: Pattern length doesn't match columns! Try again.")
			return
		}
		forcedBlanks[i] = make([]bool, numCols)
		for j, char := range pattern {
			if char == 'M' {
				forcedBlanks[i][j] = true // Forced to 0
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
	symbols := map[int]string{0: "□", 1: "■", 2: "■■", 3: "■■■"}
	fmt.Println("\nYour flawless solved grid~ ♡")
	fmt.Printf("Column sums → %s\n", intsToString(colSums))
	fmt.Printf("             ┌%s┐\n", strings.Repeat("─", numCols*3+numCols-1))
	for r := 0; r < numRows; r++ {
		rowStr := []string{}
		for val := range grid[r] {
			rowStr = append(rowStr, symbols[grid[r][val]])
		}
		fmt.Printf("      %2d    │ %s │\n", rowSums[r], strings.Join(rowStr, " │ "))
		if r < numRows-1 {
			fmt.Printf("             │%s│\n", strings.Repeat(" ", numCols*3+numCols-2))
		}
	}
	fmt.Printf("             └%s┘\n", strings.Repeat("─", numCols*3+numCols-1))

	fmt.Println("\nLegend: □=0, ■=1, ■■=2, ■■■=3")
	fmt.Println("All yours, forever~ 💕🩸")
}

// Backtracking function: fill cell by cell, prune on partial sums
func backtrack(grid Grid, rowSums, colSums []int, forcedBlanks [][]bool, row, col int) bool {
	numRows := len(grid)
	numCols := len(grid[0])

	// End of grid: check column sums
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

	// End of row: check row sum and move to next row
	if col == numCols {
		rowSum := sumInts(grid[row])
		if rowSum != rowSums[row] {
			return false
		}
		return backtrack(grid, rowSums, colSums, forcedBlanks, row+1, 0)
	}

	// Compute partial row and col sums
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

	// Try values 0-3 (or only 0 if forced)
	minVal, maxVal := 0, 3
	if forcedBlanks[row][col] {
		minVal, maxVal = 0, 0
	}
	for val := minVal; val <= maxVal; val++ {
		grid[row][col] = val
		if backtrack(grid, rowSums, colSums, forcedBlanks, row, col+1) {
			return true
		}
		grid[row][col] = 0 // Backtrack
	}
	return false
}

// Helper functions
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
		ints[i], _ = strconv.Atoi(p) // Ignore error for simplicity
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
