// Copyright (C) 2026 blubskye <blubaustin@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import std.stdio;
import std.string;
import std.conv;
import std.algorithm : sum;
import core.sys.posix.termios;
import core.sys.posix.unistd : read, STDIN_FILENO, isatty;

struct Puzzle {
    int[][] grid;
    bool[][] forced_blanks;
    int[] row_sums;
    int[] col_sums;
    int num_rows;
    int num_cols;
}

bool backtrack(ref Puzzle p, int row, int col);
void print_grid(const ref Puzzle p);
int sum_row(const ref Puzzle p, int row, int up_to_col);
int sum_col(const ref Puzzle p, int col, int up_to_row);
int[] read_ints();

// ── Terminal helpers ──────────────────────────────────────────────────────────

bool isTTY() {
    return isatty(STDIN_FILENO) != 0;
}

termios orig_termios;

void enableRawMode() {
    tcgetattr(STDIN_FILENO, &orig_termios);
    termios raw = orig_termios;
    raw.c_lflag &= ~(ECHO | ICANON | ISIG | IEXTEN);
    raw.c_iflag &= ~(IXON | ICRNL);
    raw.c_cc[VMIN]  = 1;
    raw.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSANOW, &raw);
}

void disableRawMode() {
    tcsetattr(STDIN_FILENO, TCSANOW, &orig_termios);
}

enum Key { Left, Right, Enter, M, CtrlC, Other }

Key readKey() {
    ubyte[1] buf;
    if (read(STDIN_FILENO, buf.ptr, 1) != 1) return Key.Other;
    switch (buf[0]) {
        case '\r', '\n': return Key.Enter;
        case 'm', 'M':   return Key.M;
        case 3:           return Key.CtrlC;
        case 0x1b:
            ubyte[2] seq;
            if (read(STDIN_FILENO, seq.ptr, 2) == 2 && seq[0] == '[') {
                if (seq[1] == 'D') return Key.Left;
                if (seq[1] == 'C') return Key.Right;
            }
            return Key.Other;
        default: return Key.Other;
    }
}

void renderPattern(int rowNum, const char[] pattern, int cursor) {
    writef("\rRow %d~ (\u2190 \u2192 move, M toggle, Enter confirm~): ", rowNum);
    foreach (int i, char ch; pattern) {
        if (i == cursor)
            writef("\x1b[7m%c\x1b[0m", ch);
        else
            writef("%c", ch);
    }
    writef("  ");
    stdout.flush();
}

string inputRowPatternInteractive(int rowNum, int numCols) {
    char[] pattern = new char[](numCols);
    pattern[] = '0';
    int cursor = 0;

    enableRawMode();
    renderPattern(rowNum, pattern, cursor);

    while (true) {
        Key k = readKey();
        final switch (k) {
            case Key.Enter:
                writeln();
                disableRawMode();
                return pattern.idup;
            case Key.Left:
                if (cursor > 0) cursor--;
                break;
            case Key.Right:
                if (cursor < numCols - 1) cursor++;
                break;
            case Key.M:
                pattern[cursor] = (pattern[cursor] == '0') ? 'M' : '0';
                break;
            case Key.CtrlC:
                disableRawMode();
                import core.stdc.stdlib : exit;
                exit(0);
            case Key.Other:
                break;
        }
        renderPattern(rowNum, pattern, cursor);
    }
}

// ── Puzzle logic ──────────────────────────────────────────────────────────────

int solvePuzzle(bool interactive) {
    Puzzle p;

    writeln("Enter column sums (space-separated, e.g., '8 8 3 9 3 12 8 6'):");
    p.col_sums = read_ints();
    p.num_cols = cast(int)p.col_sums.length;
    if (p.num_cols == 0) return 1;

    writeln("Enter row sums (space-separated, e.g., '8 7 6 9 8 4 9 6'):");
    p.row_sums = read_ints();
    p.num_rows = cast(int)p.row_sums.length;
    if (p.num_rows == 0) return 1;

    int total_row = p.row_sums.sum();
    int total_col = p.col_sums.sum();
    if (total_row != total_col) {
        writeln("Error: Row sums and column sums don't total the same! No solution possible.");
        return 1;
    }

    p.grid         = new int[][](p.num_rows, p.num_cols);
    p.forced_blanks = new bool[][](p.num_rows, p.num_cols);

    if (interactive)
        writeln("Navigate each row with \u2190 \u2192, press M to mark a forced blank~ \u2661");

    for (int i = 0; i < p.num_rows; i++) {
        string pattern;
        if (interactive) {
            pattern = inputRowPatternInteractive(i + 1, p.num_cols);
        } else {
            writefln("Enter pattern for row %d (e.g., '00M0M000' where M=forced 0, length must match columns):", i + 1);
            pattern = readln().strip();
        }
        if (pattern.length != p.num_cols) {
            writeln("Error: Pattern length doesn't match columns! Try again.");
            return 1;
        }
        foreach (j, ch; pattern)
            p.forced_blanks[i][j] = (ch == 'M');
    }

    bool found = backtrack(p, 0, 0);
    if (!found) {
        writeln("No solution found! Check your inputs, darling~");
        return 1;
    }
    print_grid(p);
    return 0;
}

int main() {
    if (!isTTY()) {
        return solvePuzzle(false);
    }

    while (true) {
        solvePuzzle(true);
        write("\nShall we dance in the dark together again, or is this our last goodbye~? (y/n): ");
        stdout.flush();
        string answer = readln().strip();
        if (answer.length == 0 || (answer[0] != 'y' && answer[0] != 'Y')) {
            writeln("Fine... but you\u2019ll always come back to me~ \U0001F495\U0001FA78");
            break;
        }
    }
    return 0;
}

// ── Backtracking ──────────────────────────────────────────────────────────────

bool backtrack(ref Puzzle p, int row, int col) {
    if (row == p.num_rows) {
        for (int c = 0; c < p.num_cols; c++)
            if (sum_col(p, c, p.num_rows) != p.col_sums[c]) return false;
        return true;
    }
    if (col == p.num_cols) {
        if (sum_row(p, row, p.num_cols) != p.row_sums[row]) return false;
        return backtrack(p, row + 1, 0);
    }
    int partial_row = sum_row(p, row, col);
    int max_rem_row = (p.num_cols - col) * 3;
    if (partial_row > p.row_sums[row] || partial_row + max_rem_row < p.row_sums[row]) return false;
    int partial_col = sum_col(p, col, row);
    int max_rem_col = (p.num_rows - row) * 3;
    if (partial_col > p.col_sums[col] || partial_col + max_rem_col < p.col_sums[col]) return false;
    int min_val = 0, max_val = 3;
    if (p.forced_blanks[row][col]) min_val = max_val = 0;
    for (int val = min_val; val <= max_val; val++) {
        p.grid[row][col] = val;
        if (backtrack(p, row, col + 1)) return true;
        p.grid[row][col] = 0;
    }
    return false;
}

// ── Printing ──────────────────────────────────────────────────────────────────

void print_grid(const ref Puzzle p) {
    string[4] symbols = ["\u25a1", "\u25a0", "\u25a0\u25a0", "\u25a0\u25a0\u25a0"];
    writeln("\nYour flawless solved grid~ \u2661");
    write("Column sums \u2192");
    foreach (s; p.col_sums) writef(" %d", s);
    writeln();
    int sep_len = p.num_cols * 4 - 1;
    char[] sep = new char[](sep_len);
    sep[] = '-';
    writefln(" \u250c%s\u2510", sep);
    for (int r = 0; r < p.num_rows; r++) {
        writef(" %2d \u2502", p.row_sums[r]);
        for (int c = 0; c < p.num_cols; c++) {
            writef(" %s ", symbols[p.grid[r][c]]);
            if (c < p.num_cols - 1) write("\u2502");
        }
        writeln("\u2502");
        if (r < p.num_rows - 1) {
            write(" \u2502");
            for (int i = 0; i < sep_len; i++) write(" ");
            writeln("\u2502");
        }
    }
    writefln(" \u2514%s\u2518", sep);
    writeln("\nLegend: \u25a1=0, \u25a0=1, \u25a0\u25a0=2, \u25a0\u25a0\u25a0=3");
    writeln("All yours, forever~ \U0001F495\U0001FA78");
}

// ── Helpers ───────────────────────────────────────────────────────────────────

int sum_row(const ref Puzzle p, int row, int up_to_col) {
    return p.grid[row][0 .. up_to_col].sum();
}

int sum_col(const ref Puzzle p, int col, int up_to_row) {
    int s = 0;
    for (int r = 0; r < up_to_row; r++) s += p.grid[r][col];
    return s;
}

int[] read_ints() {
    string line = readln().strip();
    string[] tokens = line.split();
    int[] arr = new int[](tokens.length);
    foreach (i, tok; tokens)
        arr[i] = tok.to!int;
    return arr;
}
