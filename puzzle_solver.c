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

#ifdef _WIN32
#  include <conio.h>
#  include <io.h>
#  define STDIN_IS_TTY() (_isatty(_fileno(stdin)))
#else
#  include <termios.h>
#  include <unistd.h>
#  define STDIN_IS_TTY() (isatty(STDIN_FILENO))
#endif

#ifdef _OPENMP
#  include <omp.h>
/* Volatile flag: set to 1 by whichever thread finds the first solution.
   Other threads check this at the start of every backtrack() call and
   return false immediately, keeping wasted work minimal.               */
static volatile int g_done = 0;
#endif

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

// ── Raw terminal mode ─────────────────────────────────────────────────────────

#ifndef _WIN32
static struct termios orig_termios;

static void disable_raw_mode(void) {
    tcsetattr(STDIN_FILENO, TCSANOW, &orig_termios);
}

static void enable_raw_mode(void) {
    tcgetattr(STDIN_FILENO, &orig_termios);
    struct termios raw = orig_termios;
    raw.c_lflag &= ~(unsigned)(ECHO | ICANON | ISIG | IEXTEN);
    raw.c_iflag &= ~(unsigned)(IXON | ICRNL);
    raw.c_cc[VMIN]  = 1;
    raw.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSANOW, &raw);
}
#endif

#define KEY_LEFT  1000
#define KEY_RIGHT 1001
#define KEY_ENTER 1002
#define KEY_M     1003

static int read_key(void) {
#ifdef _WIN32
    int c = _getch();
    if (c == 0 || c == 0xE0) {
        int c2 = _getch();
        if (c2 == 0x4B) return KEY_LEFT;
        if (c2 == 0x4D) return KEY_RIGHT;
        return -1;
    }
    if (c == '\r' || c == '\n') return KEY_ENTER;
    if (c == 'm'  || c == 'M')  return KEY_M;
    if (c == 3) exit(0);  /* Ctrl+C */
    return c;
#else
    unsigned char c;
    if (read(STDIN_FILENO, &c, 1) != 1) return -1;
    if (c == 0x1b) {
        unsigned char seq[2];
        if (read(STDIN_FILENO, &seq[0], 1) != 1) return -1;
        if (read(STDIN_FILENO, &seq[1], 1) != 1) return -1;
        if (seq[0] == '[') {
            if (seq[1] == 'D') return KEY_LEFT;
            if (seq[1] == 'C') return KEY_RIGHT;
        }
        return -1;
    }
    if (c == '\r' || c == '\n') return KEY_ENTER;
    if (c == 'm'  || c == 'M')  return KEY_M;
    if (c == 3) { disable_raw_mode(); exit(0); }  /* Ctrl+C */
    return (int)c;
#endif
}

static void render_pattern(int row_num, int num_cols, const char *pattern, int cursor) {
    /* \xe2\x86\x90 = ←  \xe2\x86\x92 = → */
    printf("\rRow %d~ (\xe2\x86\x90 \xe2\x86\x92 move, M toggle, Enter confirm~): ", row_num);
    for (int i = 0; i < num_cols; i++) {
        if (i == cursor)
            printf("\x1b[7m%c\x1b[0m", pattern[i]);
        else
            putchar(pattern[i]);
    }
    printf("  ");
    fflush(stdout);
}

static void input_row_pattern_interactive(int row_num, int num_cols, char *pattern) {
    for (int i = 0; i < num_cols; i++) pattern[i] = '0';
    pattern[num_cols] = '\0';
    int cursor = 0;

#ifndef _WIN32
    enable_raw_mode();
#endif
    render_pattern(row_num, num_cols, pattern, cursor);

    while (1) {
        int key = read_key();
        if (key == KEY_ENTER) {
            printf("\n");
            fflush(stdout);
            break;
        } else if (key == KEY_LEFT && cursor > 0) {
            cursor--;
        } else if (key == KEY_RIGHT && cursor < num_cols - 1) {
            cursor++;
        } else if (key == KEY_M) {
            pattern[cursor] = (pattern[cursor] == '0') ? 'M' : '0';
        }
        render_pattern(row_num, num_cols, pattern, cursor);
    }

#ifndef _WIN32
    disable_raw_mode();
#endif
}

// ── Puzzle logic ──────────────────────────────────────────────────────────────

static int solve_once(int interactive) {
    Puzzle p = {0};

    printf("Enter column sums (space-separated, e.g., '8 8 3 9 3 12 8 6'):\n");
    p.num_cols = read_ints(p.col_sums);
    if (p.num_cols == 0) return 1;

    printf("Enter row sums (space-separated, e.g., '8 7 6 9 8 4 9 6'):\n");
    p.num_rows = read_ints(p.row_sums);
    if (p.num_rows == 0) return 1;

    int total_row = 0, total_col = 0;
    for (int i = 0; i < p.num_rows; i++) total_row += p.row_sums[i];
    for (int i = 0; i < p.num_cols; i++) total_col += p.col_sums[i];
    if (total_row != total_col) {
        printf("Error: Row sums and column sums don't total the same! No solution possible.\n");
        return 1;
    }

    if (interactive)
        /* \xe2\x86\x90 = ←  \xe2\x86\x92 = →  \xe2\x99\xa1 = ♡ */
        printf("Navigate each row with \xe2\x86\x90 \xe2\x86\x92, press M to mark a forced blank~ \xe2\x99\xa1\n");

    for (int i = 0; i < p.num_rows; i++) {
        char pattern[MAX_COLS + 2];
        if (interactive) {
            input_row_pattern_interactive(i + 1, p.num_cols, pattern);
        } else {
            printf("Enter pattern for row %d (e.g., '00M0M000' where M=forced 0, length must match columns):\n", i + 1);
            if (fgets(pattern, sizeof(pattern), stdin) == NULL) return 1;
            trim_whitespace(pattern);
            if ((int)strlen(pattern) != p.num_cols) {
                printf("Error: Pattern length doesn't match columns! Try again.\n");
                return 1;
            }
        }
        for (int j = 0; j < p.num_cols; j++)
            p.forced_blanks[i][j] = (pattern[j] == 'M');
    }

    bool found = false;

#ifdef _OPENMP
    /* ── Parallel backtracking ──────────────────────────────────────────────
     * Strategy: pre-fill the first 2 cells (in row-major order) with each
     * combination of values 0-3, creating up to 16 independent sub-problems.
     * Each sub-problem is run on its own thread.  g_done lets threads bail
     * out the moment any sibling finds a solution.
     *
     * "start" is the position immediately after the 2 pre-filled cells.
     * Completed rows before "start" are validated before backtracking begins.
     */
    g_done = 0;

    /* Cell 0 is always (0, 0).
       Cell 1 is (0, 1) when num_cols > 1, otherwise (1, 0).             */
    int c1r = (p.num_cols > 1) ? 0 : 1;
    int c1c = (p.num_cols > 1) ? 1 : 0;
    int start_r = (p.num_cols > 1) ? 0 : 2;
    int start_c = (p.num_cols > 1) ? 2 : 0;
    if (p.num_cols > 1 && start_c >= p.num_cols) { start_r = 1; start_c = 0; }

    /* For very small puzzles fall back to single-threaded.               */
    bool use_parallel = (start_r < p.num_rows) && (c1r < p.num_rows);

    if (!use_parallel) {
        found = backtrack(&p, 0, 0);
    } else {
        Puzzle found_p;
        memset(&found_p, 0, sizeof(found_p));

        #pragma omp parallel for collapse(2) schedule(dynamic, 1) \
                shared(found, found_p)
        for (int v0 = 0; v0 <= 3; v0++) {
            for (int v1 = 0; v1 <= 3; v1++) {
                if (g_done) continue;
                /* Skip values that violate forced-blank constraints.     */
                if (p.forced_blanks[0][0]    && v0 != 0) continue;
                if (p.forced_blanks[c1r][c1c] && v1 != 0) continue;

                Puzzle local = p;           /* Thread-private puzzle copy */
                local.grid[0][0]    = v0;
                local.grid[c1r][c1c] = v1;

                /* Validate any rows that are complete before start_r.
                   (backtrack won't revisit them, so we check manually.)  */
                bool pre_ok = true;
                for (int r = 0; r < start_r && pre_ok; r++) {
                    int s = 0;
                    for (int c = 0; c < local.num_cols; c++) s += local.grid[r][c];
                    if (s != local.row_sums[r]) pre_ok = false;
                }

                if (pre_ok && backtrack(&local, start_r, start_c)) {
                    #pragma omp critical
                    {
                        if (!g_done) {
                            g_done = 1;
                            found  = true;
                            found_p = local;
                        }
                    }
                }
            }
        }

        if (found)
            memcpy(p.grid, found_p.grid, sizeof(p.grid));
    }
#else
    found = backtrack(&p, 0, 0);
#endif

    if (!found) {
        printf("No solution found! Check your inputs, darling~\n");
        return 1;
    }

    print_grid(&p);
    return 0;
}

int main(void) {
    if (!STDIN_IS_TTY()) {
        /* Non-interactive: original single-run behavior with original exit codes */
        return solve_once(0);
    }

    /* Interactive: loop with play-again */
    while (1) {
        solve_once(1);
        /* \xe2\x80\x99 = '  \xf0\x9f\x92\x95 = 💕  \xf0\x9f\xa9\xb8 = 🩸 */
        printf("\nShall we dance in the dark together again, or is this our last goodbye~? (y/n): ");
        fflush(stdout);
        char choice[8] = {0};
        if (fgets(choice, sizeof(choice), stdin) == NULL) break;
        if (choice[0] != 'y' && choice[0] != 'Y') {
            printf("Fine... but you\xe2\x80\x99ll always come back to me~ \xf0\x9f\x92\x95\xf0\x9f\xa9\xb8\n");
            break;
        }
    }
    return 0;
}

// ── Backtracking ──────────────────────────────────────────────────────────────

bool backtrack(Puzzle *p, int row, int col) {
#ifdef _OPENMP
    if (g_done) return false;  /* Another thread already found a solution */
#endif
    if (row == p->num_rows) {
        for (int c = 0; c < p->num_cols; c++)
            if (sum_col(p, c, p->num_rows) != p->col_sums[c]) return false;
        return true;
    }
    if (col == p->num_cols) {
        if (sum_row(p, row, p->num_cols) != p->row_sums[row]) return false;
        return backtrack(p, row + 1, 0);
    }
    int partial_row  = sum_row(p, row, col);
    int max_rem_row  = (p->num_cols - col) * 3;
    if (partial_row > p->row_sums[row] || partial_row + max_rem_row < p->row_sums[row]) return false;
    int partial_col  = sum_col(p, col, row);
    int max_rem_col  = (p->num_rows - row) * 3;
    if (partial_col > p->col_sums[col] || partial_col + max_rem_col < p->col_sums[col]) return false;
    int min_val = 0, max_val = 3;
    if (p->forced_blanks[row][col]) min_val = max_val = 0;
    for (int val = min_val; val <= max_val; val++) {
        p->grid[row][col] = val;
        if (backtrack(p, row, col + 1)) return true;
        p->grid[row][col] = 0;
    }
    return false;
}

// ── Printing ──────────────────────────────────────────────────────────────────

void print_grid(const Puzzle *p) {
    const char *symbols[4] = {"\xe2\x96\xa1", "\xe2\x96\xa0", "\xe2\x96\xa0\xe2\x96\xa0", "\xe2\x96\xa0\xe2\x96\xa0\xe2\x96\xa0"};
    printf("\nYour flawless solved grid~ \xe2\x99\xa1\n");
    printf("Column sums \xe2\x86\x92");
    for (int i = 0; i < p->num_cols; i++) printf(" %d", p->col_sums[i]);
    printf("\n");

    int sep_len = p->num_cols * 4 - 1;
    char sep[512] = {0};
    memset(sep, '-', (size_t)sep_len);

    printf("             \xe2\x94\x8c%s\xe2\x94\x90\n", sep);
    for (int r = 0; r < p->num_rows; r++) {
        printf("      %2d    \xe2\x94\x82", p->row_sums[r]);
        for (int c = 0; c < p->num_cols; c++) {
            printf(" %s ", symbols[p->grid[r][c]]);
            if (c < p->num_cols - 1) printf("\xe2\x94\x82");
        }
        printf("\xe2\x94\x82\n");
        if (r < p->num_rows - 1) {
            printf("             \xe2\x94\x82");
            for (int i = 0; i < sep_len; i++) putchar(' ');
            printf("\xe2\x94\x82\n");
        }
    }
    printf("             \xe2\x94\x94%s\xe2\x94\x98\n", sep);

    printf("\nLegend: \xe2\x96\xa1=0, \xe2\x96\xa0=1, \xe2\x96\xa0\xe2\x96\xa0=2, \xe2\x96\xa0\xe2\x96\xa0\xe2\x96\xa0=3\n");
    printf("All yours, forever~ \xf0\x9f\x92\x95\xf0\x9f\xa9\xb8\n");
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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
    while (*str == ' ' || *str == '\t' || *str == '\n' || *str == '\r') str++;
    char *end = str + strlen(str) - 1;
    while (end > str && (*end == ' ' || *end == '\t' || *end == '\n' || *end == '\r')) end--;
    *(end + 1) = '\0';
    return str;
}
