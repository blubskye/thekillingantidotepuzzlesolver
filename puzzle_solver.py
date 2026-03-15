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
import sys
import os
import termios
import tty


def is_terminal():
    try:
        return os.isatty(sys.stdin.fileno())
    except Exception:
        return False


def read_key():
    """Read a single keypress, handling arrow key escape sequences."""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch = os.read(fd, 1)
        if ch == b'\x1b':
            ch2 = os.read(fd, 1)
            ch3 = os.read(fd, 1)
            if ch2 == b'[':
                if ch3 == b'D':
                    return 'LEFT'
                if ch3 == b'C':
                    return 'RIGHT'
            return 'ESC'
        elif ch in (b'\r', b'\n'):
            return 'ENTER'
        elif ch in (b'm', b'M'):
            return 'M'
        elif ch == b'\x03':
            raise KeyboardInterrupt
        return ch.decode('utf-8', errors='replace')
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)


def input_row_pattern(row_num, num_cols):
    """Interactively edit a row pattern. Starts pre-filled with 0s; use ← → to
    move the cursor and M to toggle a forced blank~"""
    pattern = ['0'] * num_cols
    cursor = 0

    def render():
        sys.stdout.write('\r')
        sys.stdout.write(f"Row {row_num}~ (\u2190 \u2192 move, M toggle, Enter confirm~): ")
        for i, ch in enumerate(pattern):
            if i == cursor:
                sys.stdout.write(f'\x1b[7m{ch}\x1b[0m')
            else:
                sys.stdout.write(ch)
        sys.stdout.write('  ')
        sys.stdout.flush()

    render()
    while True:
        key = read_key()
        if key == 'ENTER':
            sys.stdout.write('\n')
            sys.stdout.flush()
            return ''.join(pattern)
        elif key == 'LEFT':
            if cursor > 0:
                cursor -= 1
        elif key == 'RIGHT':
            if cursor < num_cols - 1:
                cursor += 1
        elif key == 'M':
            pattern[cursor] = 'M' if pattern[cursor] == '0' else '0'
        render()


def solve_puzzle(interactive):
    # Step 1: Input column sums (top vertical row)
    print("Enter column sums (space-separated, e.g., '8 8 3 9 3 12 8 6'):")
    col_sums = list(map(int, input().strip().split()))
    num_cols = len(col_sums)

    # Step 2: Input row sums (horizontal)
    print("Enter row sums (space-separated, e.g., '8 7 6 9 8 4 9 6'):")
    row_sums = list(map(int, input().strip().split()))
    num_rows = len(row_sums)

    # Verify total sums match before asking for patterns
    if sum(row_sums) != sum(col_sums):
        print("Error: Row sums and column sums don't total the same! No solution possible.")
        return

    # Step 3: Input forced blank patterns for each row
    if interactive:
        print("Navigate each row with \u2190 \u2192, press M to mark a forced blank~ \u2661")
    forced_blanks = []
    for i in range(num_rows):
        if interactive:
            pattern = input_row_pattern(i + 1, num_cols)
        else:
            print(f"Enter pattern for row {i+1} (e.g., '00M0M000' where M=forced 0, length must match columns):")
            pattern = input().strip()
            if len(pattern) != num_cols:
                print("Error: Pattern length doesn't match columns! Try again.")
                return
        forced_blanks.append([1 if char == 'M' else 0 for char in pattern])

    # Set up the ILP model
    model = pulp.LpProblem("DataRecoveryPuzzle", pulp.LpMinimize)
    cells = [[pulp.LpVariable(f"cell_{r}_{c}", lowBound=0, upBound=3, cat='Integer')
              for c in range(num_cols)] for r in range(num_rows)]

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
    status = model.solve(pulp.PULP_CBC_CMD(msg=0))
    if status != pulp.LpStatusOptimal:
        print("No solution found! Check your inputs, darling~")
        return

    # Extract solution
    grid = [[int(pulp.value(cells[r][c])) for c in range(num_cols)] for r in range(num_rows)]

    # Pretty print the grid
    symbols = {0: '\u25a1', 1: '\u25a0', 2: '\u25a0\u25a0', 3: '\u25a0\u25a0\u25a0'}
    print("\nYour flawless solved grid~ \u2661")
    print(f"Column sums \u2192 {' '.join(map(str, col_sums))}")
    print("             \u250c" + "\u2500" * (num_cols * 3 + num_cols - 1) + "\u2510")
    for r in range(num_rows):
        row_str = ' \u2502 '.join(symbols[val] for val in grid[r])
        print(f"      {row_sums[r]:2}    \u2502 {row_str} \u2502")
        if r < num_rows - 1:
            print("             \u2502" + " " * (num_cols * 3 + num_cols - 2) + "\u2502")
    print("             \u2514" + "\u2500" * (num_cols * 3 + num_cols - 1) + "\u2518")

    print("\nLegend: \u25a1=0, \u25a0=1, \u25a0\u25a0=2, \u25a0\u25a0\u25a0=3")
    print("All yours, forever~ \U0001f495\U0001fa78")


if __name__ == "__main__":
    interactive = is_terminal()
    if not interactive:
        solve_puzzle(False)
    else:
        while True:
            solve_puzzle(True)
            print("\nShall we dance in the dark together again, or is this our last goodbye~? (y/n): ",
                  end='', flush=True)
            try:
                answer = input().strip().lower()
            except EOFError:
                break
            if answer != 'y':
                print("Fine... but you'll always come back to me~ \U0001f495\U0001fa78")
                break
