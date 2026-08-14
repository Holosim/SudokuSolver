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

// P-HARD17 (docs/RTVM.md 6.1) — 17 givens, the minimum for a unique 9x9
// puzzle, and the RTVM-500 performance reference.
inline constexpr std::string_view kPuzzleHard17 =
    "000000010"
    "400000000"
    "020000000"
    "000050407"
    "008000300"
    "001090000"
    "300400200"
    "050100000"
    "000806000";

// S-HARD17 (docs/RTVM.md 6.1) — the unique solution of P-HARD17.
inline constexpr std::string_view kSolvedHard17 =
    "693784512"
    "487512936"
    "125963874"
    "932651487"
    "568247391"
    "741398625"
    "319475268"
    "856129743"
    "274836159";

// P-UNSOLVABLE (docs/RTVM.md 6.1) — P-EASY with r1c3 set to 1. Its givens are
// mutually consistent (no row, column or box duplicate), so RTVM-104 must not
// reject it at the parser; the solver itself has to discover it has no
// completion (RTVM-201, TP-201).
inline constexpr std::string_view kPuzzleUnsolvable =
    "531070000"
    "600195000"
    "098000060"
    "800060003"
    "400803001"
    "700020006"
    "060000280"
    "000419005"
    "000080079";

// The normative rendering of S-EASY (docs/RTVM.md 6.2) — 13 lines of 25 ASCII
// characters, every line terminated, the last one included. Transcribed from
// the document and nowhere else: this literal *is* the requirement, so TP-400
// comparing formatGrid against it is a comparison against RTVM-400 rather than
// against the implementation's own idea of the format.
inline constexpr std::string_view kSolvedEasyFormatted =
    "+-------+-------+-------+\n"
    "| 5 3 4 | 6 7 8 | 9 1 2 |\n"
    "| 6 7 2 | 1 9 5 | 3 4 8 |\n"
    "| 1 9 8 | 3 4 2 | 5 6 7 |\n"
    "+-------+-------+-------+\n"
    "| 8 5 9 | 7 6 1 | 4 2 3 |\n"
    "| 4 2 6 | 8 5 3 | 7 9 1 |\n"
    "| 7 1 3 | 9 2 4 | 8 5 6 |\n"
    "+-------+-------+-------+\n"
    "| 9 6 1 | 5 3 7 | 2 8 4 |\n"
    "| 2 8 7 | 4 1 9 | 6 3 5 |\n"
    "| 3 4 5 | 2 8 6 | 1 7 9 |\n"
    "+-------+-------+-------+\n";

// The separator of docs/RTVM.md 6.2, named once so a test asserting lines 1,
// 5, 9 and 13 does not retype it four times.
inline constexpr std::string_view kFormatSeparatorLine = "+-------+-------+-------+";

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
