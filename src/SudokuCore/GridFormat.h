// GridFormat.h — the normative 13-line ASCII rendering of a solved grid.
//
// docs/SDD.md 2.6, 2.8. RTVM-400, docs/RTVM.md 6.2.

#pragma once

#include <string>

#include "Grid.h"

namespace sudoku {

// Returns the 13-line block of docs/RTVM.md 6.2 and writes to nothing.
// Keeping this a pure function is what lets TP-400 assert it byte for byte
// as a unit test rather than a process capture, and keeps the core free of
// streams for TP-903.
[[nodiscard]] std::string formatGrid(const Grid& grid);

} // namespace sudoku
