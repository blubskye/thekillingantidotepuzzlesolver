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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#define MAX_ROWS 20
#define MAX_COLS 20

typedef struct {
    int grid[MAX_ROWS][MAX_COLS];
    bool forced_blanks[MAX_ROWS][MAX_COLS];
    int row_sums[MAX_ROWS];
    int col_sums[MAX_COLS];
    int num_rows;
    int num_cols;
} Puzzle;

bool backtrack(Puzzle *p, int row, int col);
void print_grid(const Puzzle *p);
int sum_row(const Puzzle *p, int row, int up_to_col);
int sum_col(const Puzzle *p, int col, int up_to_row);
int read_ints(int *arr);
char* trim_whitespace(char *str);

int main(void) {
    Puzzle p = {0};  // Zero-init everything (C23 makes this nicer, but works in older too)

    // Step 1: Input column sums
    printf("Enter column sums (space-separated, e.g., '8 8 3 9 3 12 8 6'):\n");
    p.num_cols = read_ints(p.col_sums);
    if (p.num_cols == 0) return 1;

    // Step 2: Input row sums
    printf("Enter row sums (space-separated, e.g., '8 7 6 9 8 4 9 6'):\n");
    p.num_rows = read_ints(p.row_sums);
    if (p.num_rows == 0) return 1;

    // Verify total sums match
    int total_row = 0, total_col = 0;
    for (int i = 0; i < p.num_rows; i++) total_row += p.row_sums[i];
    for (int i = 0; i < p.num_cols; i++) total_col += p.col_sums[i];
    if (total_row != total_col) {
        printf("Error: Row sums and column sums don't total the same! No solution possible.\n");
        return 1;
    }

    // Step 3: Input forced blank patterns
    for (int i = 0; i < p.num_rows; i++) {
        printf("Enter pattern for row %d (e.g., '00M0M000' where M=forced 0, length must match columns):\n", i+1);
        char pattern[256];
        if (fgets(pattern, sizeof(pattern), stdin) == NULL) return 1;
        trim_whitespace(pattern);
        if ((int)strlen(pattern) != p.num_cols) {
            printf("Error: Pattern length doesn't match columns! Try again.\n");
            return 1;
        }
        for (int j = 0; j < p.num_cols; j++) {
            p.forced_blanks[i][j] = (pattern[j] == 'M');
        }
    }

    // Solve with backtracking
    bool found = backtrack(&p, 0, 0);
    if (!found) {
        printf("No solution found! Check your inputs, darling~\n");
        return 1;
    }

    // Pretty print
    print_grid(&p);
    return 0;
}

bool backtrack(Puzzle *p, int row, int col) {
    if (row == p->num_rows) {
        // Check all column sums
        for (int c = 0; c < p->num_cols; c++) {
            if (sum_col(p, c, p->num_rows) != p->col_sums[c]) return false;
        }
        return true;
    }

    if (col == p->num_cols) {
        // Check row sum
        if (sum_row(p, row, p->num_cols) != p->row_sums[row]) return false;
        return backtrack(p, row + 1, 0);
    }

    // Prune: partial row sum
    int partial_row = sum_row(p, row, col);
    int max_rem_row = (p->num_cols - col) * 3;
    if (partial_row > p->row_sums[row] || partial_row + max_rem_row < p->row_sums[row]) return false;

    // Prune: partial col sum
    int partial_col = sum_col(p, col, row);
    int max_rem_col = (p->num_rows - row) * 3;
    if (partial_col > p->col_sums[col] || partial_col + max_rem_col < p->col_sums[col]) return false;

    // Try values (0-3 or just 0 if forced)
    int min_val = 0, max_val = 3;
    if (p->forced_blanks[row][col]) {
        min_val = max_val = 0;
    }
    for (int val = min_val; val <= max_val; val++) {
        p->grid[row][col] = val;
        if (backtrack(p, row, col + 1)) return true;
        p->grid[row][col] = 0;  // Backtrack
    }
    return false;
}

void print_grid(const Puzzle *p) {
    const char *symbols[4] = {"□", "■", "■■", "■■■"};
    printf("\nYour flawless solved grid~ ♡\n");
    printf("Column sums →");
    for (int i = 0; i < p->num_cols; i++) printf(" %d", p->col_sums[i]);
    printf("\n");

    // Build separator string
    int sep_len = p->num_cols * 4 - 1;  // Adjusted for " │ " (3 chars + space)
    char sep[512] = {0};  // Bigger buffer for safety
    memset(sep, '-', sep_len);  // Use '-' for ASCII safe, or '─' if UTF-8 env supports
    sep[sep_len] = '\0';

    printf("             ┌%s┐\n", sep);

    for (int r = 0; r < p->num_rows; r++) {
        printf("      %2d    │", p->row_sums[r]);
        for (int c = 0; c < p->num_cols; c++) {
            printf(" %s ", symbols[p->grid[r][c]]);
            if (c < p->num_cols - 1) printf("│");
        }
        printf("│\n");
        if (r < p->num_rows - 1) {
            printf("             │");
            for (int i = 0; i < sep_len; i++) printf(" ");
            printf("│\n");
        }
    }
    printf("             └%s┘\n", sep);

    printf("\nLegend: □=0, ■=1, ■■=2, ■■■=3\n");
    printf("All yours, forever~ 💕🩸\n");
}

int sum_row(const Puzzle *p, int row, int up_to_col) {
    int sum = 0;
    for (int c = 0; c < up_to_col; c++) sum += p->grid[row][c];
    return sum;
}

int sum_col(const Puzzle *p, int col, int up_to_row) {
    int sum = 0;
    for (int r = 0; r < up_to_row; r++) sum += p->grid[r][col];
    return sum;
}

int read_ints(int *arr) {
    char line[256];
    if (fgets(line, sizeof(line), stdin) == NULL) return 0;
    trim_whitespace(line);
    char *token = strtok(line, " ");
    int count = 0;
    while (token != NULL && count < MAX_COLS) {
        arr[count++] = atoi(token);
        token = strtok(NULL, " ");
    }
    return count;
}

char* trim_whitespace(char *str) {
    // Trim leading
    while (*str == ' ' || *str == '\t' || *str == '\n' || *str == '\r') str++;
    // Trim trailing
    char *end = str + strlen(str) - 1;
    while (end > str && (*end == ' ' || *end == '\t' || *end == '\n' || *end == '\r')) end--;
    *(end + 1) = '\0';
    return str;
}
