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

use std::io::{self, BufRead, Write};
use std::str::FromStr;

#[derive(Clone)]
struct Puzzle {
    grid: Vec<Vec<i32>>,
    forced_blanks: Vec<Vec<bool>>,
    row_sums: Vec<i32>,
    col_sums: Vec<i32>,
    num_rows: usize,
    num_cols: usize,
}

// ── Terminal helpers ──────────────────────────────────────────────────────────

extern "C" {
    fn isatty(fd: i32) -> i32;
}

fn is_terminal() -> bool {
    unsafe { isatty(0) != 0 } // fd 0 = stdin
}

fn enable_raw_mode() {
    std::process::Command::new("stty")
        .args(["-echo", "-icanon", "min", "1"])
        .stdin(std::process::Stdio::inherit())
        .output()
        .ok();
}

fn disable_raw_mode() {
    std::process::Command::new("stty")
        .args(["echo", "icanon"])
        .stdin(std::process::Stdio::inherit())
        .output()
        .ok();
}

enum Key {
    Left,
    Right,
    Enter,
    M,
    CtrlC,
    Other,
}

fn read_key(tty: &mut std::fs::File) -> Key {
    use std::io::Read;
    let mut buf = [0u8; 1];
    if tty.read_exact(&mut buf).is_err() {
        return Key::Other;
    }
    match buf[0] {
        b'\r' | b'\n' => Key::Enter,
        b'm' | b'M' => Key::M,
        3 => Key::CtrlC,
        0x1b => {
            let mut seq = [0u8; 2];
            if tty.read_exact(&mut seq).is_ok() && seq[0] == b'[' {
                match seq[1] {
                    b'D' => return Key::Left,
                    b'C' => return Key::Right,
                    _ => {}
                }
            }
            Key::Other
        }
        _ => Key::Other,
    }
}

fn render_pattern(row_num: usize, pattern: &[u8], cursor: usize) {
    print!("\rRow {}~ (\u{2190} \u{2192} move, M toggle, Enter confirm~): ", row_num);
    for (i, &ch) in pattern.iter().enumerate() {
        if i == cursor {
            print!("\x1b[7m{}\x1b[0m", ch as char);
        } else {
            print!("{}", ch as char);
        }
    }
    print!("  ");
    io::stdout().flush().ok();
}

fn input_row_pattern(row_num: usize, num_cols: usize) -> String {
    let mut pattern: Vec<u8> = vec![b'0'; num_cols];
    let mut cursor = 0usize;

    enable_raw_mode();
    let mut tty = std::fs::OpenOptions::new()
        .read(true)
        .open("/dev/tty")
        .expect("Cannot open /dev/tty");

    render_pattern(row_num, &pattern, cursor);

    loop {
        match read_key(&mut tty) {
            Key::Enter => {
                println!();
                break;
            }
            Key::Left => {
                if cursor > 0 {
                    cursor -= 1;
                }
            }
            Key::Right => {
                if cursor < num_cols - 1 {
                    cursor += 1;
                }
            }
            Key::M => {
                pattern[cursor] = if pattern[cursor] == b'0' { b'M' } else { b'0' };
            }
            Key::CtrlC => {
                disable_raw_mode();
                std::process::exit(0);
            }
            Key::Other => {}
        }
        render_pattern(row_num, &pattern, cursor);
    }

    disable_raw_mode();
    String::from_utf8(pattern).unwrap()
}

// ── Puzzle logic ──────────────────────────────────────────────────────────────

fn backtrack(p: &mut Puzzle, row: usize, col: usize) -> bool {
    if row == p.num_rows {
        for c in 0..p.num_cols {
            if sum_col(p, c, p.num_rows) != p.col_sums[c] {
                return false;
            }
        }
        return true;
    }
    if col == p.num_cols {
        if sum_row(p, row, p.num_cols) != p.row_sums[row] {
            return false;
        }
        return backtrack(p, row + 1, 0);
    }
    let partial_row = sum_row(p, row, col);
    let max_rem_row = ((p.num_cols - col) * 3) as i32;
    if partial_row > p.row_sums[row] || partial_row + max_rem_row < p.row_sums[row] {
        return false;
    }
    let partial_col = sum_col(p, col, row);
    let max_rem_col = ((p.num_rows - row) * 3) as i32;
    if partial_col > p.col_sums[col] || partial_col + max_rem_col < p.col_sums[col] {
        return false;
    }
    let (min_val, max_val) = if p.forced_blanks[row][col] { (0, 0) } else { (0, 3) };
    for val in min_val..=max_val {
        p.grid[row][col] = val;
        if backtrack(p, row, col + 1) {
            return true;
        }
        p.grid[row][col] = 0;
    }
    false
}

fn print_grid(p: &Puzzle) {
    let symbols = ["□", "■", "■■", "■■■"];
    println!("\nYour flawless solved grid~ \u{2661}");
    print!("Column sums \u{2192}");
    for &s in &p.col_sums {
        print!(" {}", s);
    }
    println!();
    let sep_len = p.num_cols * 4 - 1;
    let sep: String = "-".repeat(sep_len);
    println!(" \u{250C}{}\u{2510}", sep);
    for r in 0..p.num_rows {
        print!(" {:2} \u{2502}", p.row_sums[r]);
        for c in 0..p.num_cols {
            print!(" {} ", symbols[p.grid[r][c] as usize]);
            if c < p.num_cols - 1 {
                print!("\u{2502}");
            }
        }
        println!("\u{2502}");
        if r < p.num_rows - 1 {
            print!(" \u{2502}");
            for _ in 0..sep_len {
                print!(" ");
            }
            println!("\u{2502}");
        }
    }
    println!(" \u{2514}{}\u{2518}", sep);
    println!("\nLegend: \u{25A1}=0, \u{25A0}=1, \u{25A0}\u{25A0}=2, \u{25A0}\u{25A0}\u{25A0}=3");
    println!("All yours, forever~ \u{1F495}\u{1FA78}");
}

fn sum_row(p: &Puzzle, row: usize, up_to_col: usize) -> i32 {
    p.grid[row][0..up_to_col].iter().sum()
}

fn sum_col(p: &Puzzle, col: usize, up_to_row: usize) -> i32 {
    (0..up_to_row).map(|r| p.grid[r][col]).sum()
}

fn read_ints_from_stdin() -> Vec<i32> {
    let mut line = String::new();
    io::stdin().lock().read_line(&mut line).unwrap_or(0);
    line.trim()
        .split_whitespace()
        .filter_map(|s| i32::from_str(s).ok())
        .collect()
}

// ── Solve one puzzle ──────────────────────────────────────────────────────────

fn run_puzzle(interactive: bool) {
    let mut p = Puzzle {
        grid: vec![],
        forced_blanks: vec![],
        row_sums: vec![],
        col_sums: vec![],
        num_rows: 0,
        num_cols: 0,
    };

    println!("Enter column sums (space-separated, e.g., '8 8 3 9 3 12 8 6'):");
    p.col_sums = read_ints_from_stdin();
    p.num_cols = p.col_sums.len();
    if p.num_cols == 0 {
        return;
    }

    println!("Enter row sums (space-separated, e.g., '8 7 6 9 8 4 9 6'):");
    p.row_sums = read_ints_from_stdin();
    p.num_rows = p.row_sums.len();
    if p.num_rows == 0 {
        return;
    }

    let total_row: i32 = p.row_sums.iter().sum();
    let total_col: i32 = p.col_sums.iter().sum();
    if total_row != total_col {
        println!("Error: Row sums and column sums don't total the same! No solution possible.");
        return;
    }

    p.grid = vec![vec![0; p.num_cols]; p.num_rows];
    p.forced_blanks = vec![vec![false; p.num_cols]; p.num_rows];

    if interactive {
        println!("Navigate each row with \u{2190} \u{2192}, press M to mark a forced blank~ \u{2661}");
    }

    for i in 0..p.num_rows {
        let pattern = if interactive {
            input_row_pattern(i + 1, p.num_cols)
        } else {
            println!(
                "Enter pattern for row {} (e.g., '00M0M000' where M=forced 0, length must match columns):",
                i + 1
            );
            let mut line = String::new();
            io::stdin().lock().read_line(&mut line).unwrap_or(0);
            line.trim().to_string()
        };

        if pattern.len() != p.num_cols {
            println!("Error: Pattern length doesn't match columns! Try again.");
            return;
        }
        for (j, ch) in pattern.chars().enumerate() {
            p.forced_blanks[i][j] = ch == 'M';
        }
    }

    let found = backtrack(&mut p, 0, 0);
    if !found {
        println!("No solution found! Check your inputs, darling~");
        return;
    }

    print_grid(&p);
}

// ── Entry point ───────────────────────────────────────────────────────────────

fn main() {
    let interactive = is_terminal();

    if !interactive {
        run_puzzle(false);
        return;
    }

    loop {
        run_puzzle(true);

        print!("\nShall we dance in the dark together again, or is this our last goodbye~? (y/n): ");
        io::stdout().flush().ok();

        let mut answer = String::new();
        match io::stdin().lock().read_line(&mut answer) {
            Ok(0) | Err(_) => break, // EOF
            Ok(_) => {
                if answer.trim().to_lowercase() != "y" {
                    println!("Fine... but you'll always come back to me~ \u{1F495}\u{1FA78}");
                    break;
                }
            }
        }
    }
}
