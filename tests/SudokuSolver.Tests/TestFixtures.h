// TestFixtures.h — reference data from docs/RTVM.md, and the helpers that
// turn it into core types.
//
// Fixtures are transcribed from docs/RTVM.md 6.1 / 6.2 and nowhere else, so a
// change to a fixture is a change to one document and one file. Puzzle text is
// held in the compact kCellCount-character form because that is what fits on a
// line; a test that needs the nine-line form should build it from here rather
// than retyping the puzzle.

#pragma once

#include <string>
#include <string_view>

#include "Grid.h"

namespace sudoku::test {

// S-EASY (docs/RTVM.md 6.1) — the unique solution of P-EASY, row-major.
// Every cell is a digit 1..kGridSize, which is what makes it the fixture
// TP-301 is written against.
inline constexpr std::string_view kSolvedEasy =
    "534678912"
    "672195348"
    "198342567"
    "859761423"
    "426853791"
    "713924856"
    "961537284"
    "287419635"
    "345286179";

// P-EASY (docs/RTVM.md 6.1) — 30 givens, the rest empty.
inline constexpr std::string_view kPuzzleEasy =
    "530070000"
    "600195000"
    "098000060"
    "800060003"
    "400803001"
    "700020006"
    "060000280"
    "000419005"
    "000080079";

// Builds a Grid from the compact row-major form above: '0' and '.' are empty,
// and any character from '1' up to the kGridSize'th digit is a given. Anything
// else is treated as empty, and a short string leaves the remaining cells
// empty — this is a fixture loader, not a parser, and validation is
// parseGrid's job (RTVM-100).
[[nodiscard]] inline Grid gridFromCompactForm(std::string_view compact)
{
    Grid grid;
    const int count = static_cast<int>(compact.size()) < kCellCount
        ? static_cast<int>(compact.size())
        : kCellCount;
    for (int index = 0; index < count; ++index) {
        const char c = compact[static_cast<std::size_t>(index)];
        const Digit digit = (c >= '1' && c <= static_cast<char>('0' + kGridSize))
            ? static_cast<Digit>(c - '0')
            : kEmpty;
        grid.set(index / kGridSize, index % kGridSize, digit);
    }
    return grid;
}

} // namespace sudoku::test
