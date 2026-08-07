// Grid.cpp — see Grid.h. docs/SDD.md 2.3, RTVM-100.

#include "Grid.h"

#include <cstddef>

namespace sudoku {

namespace {

[[nodiscard]] constexpr int cellIndex(int row, int col) noexcept
{
    return row * kGridSize + col;
}

[[nodiscard]] constexpr bool inRange(int row, int col) noexcept
{
    return row >= 0 && row < kGridSize && col >= 0 && col < kGridSize;
}

} // namespace

Digit Grid::at(int row, int col) const
{
    // Out-of-range reads report empty rather than trapping: RTVM-505 requires
    // that no input path can produce an access violation.
    if (!inRange(row, col)) {
        return kEmpty;
    }
    return m_cells[static_cast<std::size_t>(cellIndex(row, col))];
}

void Grid::set(int row, int col, Digit d)
{
    if (!inRange(row, col)) {
        return;
    }
    m_cells[static_cast<std::size_t>(cellIndex(row, col))] = d;
}

bool Grid::isComplete() const
{
    for (const Digit d : m_cells) {
        if (d == kEmpty) {
            return false;
        }
    }
    return true;
}

} // namespace sudoku
