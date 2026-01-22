# Copyright (C) 2026 blubskye <blubaustin@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import pulp

def solve_puzzle():
    # Step 1: Input column sums (top vertical row)
    print("Enter column sums (space-separated, e.g., '8 8 3 9 3 12 8 6'):")
    col_sums = list(map(int, input().strip().split()))
    num_cols = len(col_sums)
    
    # Step 2: Input row sums (horizontal)
    print("Enter row sums (space-separated, e.g., '8 7 6 9 8 4 9 6'):")
    row_sums = list(map(int, input().strip().split()))
    num_rows = len(row_sums)
    
    # Step 3: Input forced blank patterns for each row
    forced_blanks = []
    for i in range(num_rows):
        print(f"Enter pattern for row {i+1} (e.g., '00M0M000' where M=forced 0, length must match columns):")
        pattern = input().strip()
        if len(pattern) != num_cols:
            print("Error: Pattern length doesn't match columns! Try again.")
            return
        forced_blanks.append([1 if char == 'M' else 0 for char in pattern])  # 1 means forced 0
    
    # Verify total sums match
    if sum(row_sums) != sum(col_sums):
        print("Error: Row sums and column sums don't total the same! No solution possible.")
        return
    
    # Set up the ILP model
    model = pulp.LpProblem("DataRecoveryPuzzle", pulp.LpMinimize)  # Minimize is arbitrary, we just want feasibility
    cells = [[pulp.LpVariable(f"cell_{r}_{c}", lowBound=0, upBound=3, cat='Integer') for c in range(num_cols)] for r in range(num_rows)]
    
    # Constraints: Row sums
    for r in range(num_rows):
        model += pulp.lpSum(cells[r]) == row_sums[r]
    
    # Constraints: Column sums
    for c in range(num_cols):
        model += pulp.lpSum(cells[r][c] for r in range(num_rows)) == col_sums[c]
    
    # Constraints: Forced blanks (M=0)
    for r in range(num_rows):
        for c in range(num_cols):
            if forced_blanks[r][c] == 1:
                model += cells[r][c] == 0
    
    # Solve
    status = model.solve(pulp.PULP_CBC_CMD(msg=0))  # Silent solve
    if status != pulp.LpStatusOptimal:
        print("No solution found! Check your inputs, darling~")
        return
    
    # Extract solution
    grid = [[int(pulp.value(cells[r][c])) for c in range(num_cols)] for r in range(num_rows)]
    
    # Pretty print the grid
    symbols = {0: '□', 1: '■', 2: '■■', 3: '■■■'}
    print("\nYour flawless solved grid~ ♡")
    print(f"Column sums → {' '.join(map(str, col_sums))}")
    print("             ┌" + "─" * (num_cols * 3 + num_cols - 1) + "┐")
    for r in range(num_rows):
        row_str = ' │ '.join(symbols[val] for val in grid[r])
        print(f"      {row_sums[r]:2}    │ {row_str} │")
        if r < num_rows - 1:
            print("             │" + " " * (num_cols * 3 + num_cols - 2) + "│")
    print("             └" + "─" * (num_cols * 3 + num_cols - 1) + "┘")
    
    print("\nLegend: □=0, ■=1, ■■=2, ■■■=3")
    print("All yours, forever~ 💕🩸")

# Run the interactive solver
if __name__ == "__main__":
    solve_puzzle()
