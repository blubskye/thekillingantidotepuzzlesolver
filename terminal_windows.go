//go:build windows

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

import "fmt"

// TermState is a placeholder on Windows; raw mode is not implemented here.
// inputRowPatternInteractive falls back to plain text input when makeRaw
// returns an error, so the solver still works — just without the arrow-key
// cursor editor.
type TermState struct{}

func makeRaw() (*TermState, error) {
	return nil, fmt.Errorf("interactive terminal not supported on Windows build")
}

func restoreTerminal(_ *TermState) {}
