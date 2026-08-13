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
//
// Every line is terminated, the last one included, so the returned string is
// a complete unit of output: a caller writes it and adds nothing. An empty
// cell renders as `.`, which RTVM-400 never asks for (it describes a solved
// grid) but which keeps a partial grid legible rather than malformed.
[[nodiscard]] std::string formatGrid(const Grid& grid);

// Returns the kCellCount-character form: every cell in row-major order,
// `0` for an empty cell, no separators and no newline. This is the
// round-trip form TP-100 asserts parseGrid against, and the identity a
// grid-to-grid comparison can be made on (TP-101).
//
// Added 2026-08-07 under issue #6: docs/SDD.md 2.6 names the round trip in
// TP-100 but does not name a function for it. Flagged to the Systems
// Engineer for adoption into 2.6, the same route ParseResult took.
//
// Not an input format — parseGrid accepts kGridSize lines only, so an
// 81-character single line is malformed (RTVM-106).
[[nodiscard]] std::string toCompactString(const Grid& grid);

} // namespace sudoku
