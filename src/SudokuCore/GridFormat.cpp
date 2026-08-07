// GridFormat.cpp — see GridFormat.h.
//
// formatGrid is SCAFFOLD ONLY. The byte-normative layout of docs/RTVM.md
// 6.2 is implemented under its own issue.
//
// TODO(RTVM-400, issue #9): real 13-line ASCII rendering.

#include "GridFormat.h"

#include <cstddef>

namespace sudoku {

std::string formatGrid(const Grid& grid)
{
    static_cast<void>(grid);
    return std::string{};
}

std::string toCompactString(const Grid& grid)
{
    std::string out;
    out.reserve(static_cast<std::size_t>(kCellCount));

    for (int row = 0; row < kGridSize; ++row) {
        for (int col = 0; col < kGridSize; ++col) {
            const Digit d = grid.at(row, col);
            out.push_back(d == kEmpty ? '0'
                                      : static_cast<char>('0' + static_cast<int>(d)));
        }
    }

    return out;
}

} // namespace sudoku
