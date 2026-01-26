#!/usr/bin/env bash

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

# Max dimensions (adjust if needed, darling~)
MAX_ROWS=20
MAX_COLS=20

# Flatten 2D grid: grid[row*cols + col]
declare -a grid
declare -a forced_blanks
declare -a row_sums
declare -a col_sums
num_rows=0
num_cols=0

# Helper: Get value at row,col
get_val() {
    local row=$1 col=$2
    echo "${grid[$row * $num_cols + $col]}"
}

# Set value at row,col
set_val() {
    local row=$1 col=$2 val=$3
    grid[$row * $num_cols + $col]=$val
}

# Sum row up to col
sum_row() {
    local row=$1 up_to_col=$2 sum=0
    for ((c=0; c<up_to_col; c++)); do
        ((sum += $(get_val $row $c)))
    done
    echo $sum
}

# Sum col up to row
sum_col() {
    local col=$1 up_to_row=$2 sum=0
    for ((r=0; r<up_to_row; r++)); do
        ((sum += $(get_val $r $col)))
    done
    echo $sum
}

# Read ints into array
read_ints() {
    local -n arr=$1
    read -r line
    line=$(echo "$line" | xargs)  # Trim
    arr=($line)
    echo ${#arr[@]}
}

# Trim string
trim() {
    echo "$1" | xargs
}

# Backtrack function (iterative with stack for bash limits)
backtrack() {
    # Stack: position (row*cols + col)
    declare -a stack
    local pos=0 row=0 col=0 val=0 found=false

    while true; do
        row=$((pos / num_cols))
        col=$((pos % num_cols))

        # End of grid? Check cols
        if ((row == num_rows)); then
            local valid=true
            for ((c=0; c<num_cols; c++)); do
                if (($(sum_col $c $num_rows) != col_sums[c])); then
                    valid=false
                    break
                fi
            done
            if $valid; then
                found=true
                break
            fi
        fi

        # End of row? Check row sum and advance
        if ((col == num_cols)); then
            if (($(sum_row $row $num_cols) != row_sums[row])); then
                # Backtrack
                ((pos--))
                continue
            fi
            ((pos += 1))  # Next row
            continue
        fi

        # Prune partial row
        local partial_row=$(sum_row $row $col)
        local max_rem_row=$(((num_cols - col) * 3))
        if ((partial_row > row_sums[row] || partial_row + max_rem_row < row_sums[row])); then
            # Backtrack
            ((pos--))
            continue
        fi

        # Prune partial col
        local partial_col=$(sum_col $col $row)
        local max_rem_col=$(((num_rows - row) * 3))
        if ((partial_col > col_sums[col] || partial_col + max_rem_col < col_sums[col])); then
            # Backtrack
            ((pos--))
            continue
        fi

        # Get current val and increment
        val=$(get_val $row $col)
        ((val += 1))

        # Forced blank? Only 0
        local min_val=0 max_val=3
        if ${forced_blanks[$row * $num_cols + $col]}; then
            min_val=0 max_val=0
        fi

        if ((val > max_val)); then
            set_val $row $col 0
            # Backtrack
            if ((${#stack[@]} == 0)); then break; fi
            pos=${stack[-1]}
            unset 'stack[-1]'
            continue
        fi

        set_val $row $col $val
        stack+=("$pos")  # Push current pos
        ((pos += 1))  # Advance
    done

    $found
}

# Print grid
print_grid() {
    local symbols=("□" "■" "■■" "■■■")
    echo -e "\nYour flawless solved grid~ ♡"
    echo -n "Column sums → "
    for sum in "${col_sums[@]}"; do echo -n "$sum "; done
    echo

    local sep_len=$((num_cols * 4 - 1))
    local sep=$(printf '%*s' $sep_len | tr ' ' '-')
    echo "             ┌$sep┐"

    for ((r=0; r<num_rows; r++)); do
        printf "      %2d    │" ${row_sums[r]}
        for ((c=0; c<num_cols; c++)); do
            printf " %s " "${symbols[$(get_val $r $c)]}"
            if ((c < num_cols - 1)); then printf "│"; fi
        done
        echo "│"
        if ((r < num_rows - 1)); then
            echo "             │$(printf '%*s' $sep_len)│"
        fi
    done
    echo "             └$sep┘"

    echo -e "\nLegend: □=0, ■=1, ■■=2, ■■■=3"
    echo "All yours, forever~ 💕🩸"
}

# Main
echo "Enter column sums (space-separated, e.g., '8 8 3 9 3 12 8 6'):"
num_cols=$(read_ints col_sums)
if ((num_cols == 0)); then exit 1; fi

echo "Enter row sums (space-separated, e.g., '8 7 6 9 8 4 9 6'):"
num_rows=$(read_ints row_sums)
if ((num_rows == 0)); then exit 1; fi

# Check totals
total_row=0 total_col=0
for sum in "${row_sums[@]}"; do ((total_row += sum)); done
for sum in "${col_sums[@]}"; do ((total_col += sum)); done
if ((total_row != total_col)); then
    echo "Error: Row sums and column sums don't total the same! No solution possible."
    exit 1
fi

# Init arrays
for ((i=0; i<num_rows*num_cols; i++)); do
    grid[i]=0
    forced_blanks[i]=false
done

# Input patterns
for ((i=0; i<num_rows; i++)); do
    echo "Enter pattern for row $((i+1)) (e.g., '00M0M000' where M=forced 0, length must match columns):"
    read -r pattern
    pattern=$(trim "$pattern")
    if ((${#pattern} != num_cols)); then
        echo "Error: Pattern length doesn't match columns! Try again."
        exit 1
    fi
    for ((j=0; j<num_cols; j++)); do
        if [[ ${pattern:j:1} == "M" ]]; then
            forced_blanks[$i * $num_cols + $j]=true
        fi
    done
done

# Solve
if backtrack; then
    print_grid
else
    echo "No solution found! Check your inputs, darling~"
fi
