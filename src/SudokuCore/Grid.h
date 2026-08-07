// Grid.h — grid dimensions and the 9x9 puzzle representation.
//
// docs/SDD.md 2.3. RTVM-100, RTVM-903.
//
// The grid dimension exists here as a single named constant derived from
// kBoxSize; no other file may spell it as a literal (TP-903).

#pragma once

#include <array>
#include <cstdint>

namespace sudoku {

using Digit         = std::uint8_t;    // 0 == empty, 1..kGridSize == a given
using CandidateMask = std::uint16_t;   // one bit per digit, bit 0 == digit 1

inline constexpr int   kBoxSize   = 3;
inline constexpr int   kGridSize  = kBoxSize * kBoxSize;    // the only "9"
inline constexpr int   kCellCount = kGridSize * kGridSize;
inline constexpr Digit kEmpty     = 0;

static_assert(kGridSize <= 16,
    "CandidateMask must be widened before kBoxSize > 4");

// A fixed-size board of digits. Rows and columns are 0-based here; the
// 1-based r<row>c<col> form required by RTVM-105 is produced only in the
// output layer.
class Grid {
public:
    [[nodiscard]] Digit at(int row, int col) const;
    void set(int row, int col, Digit d);

    // True when no cell holds kEmpty. Says nothing about validity.
    [[nodiscard]] bool isComplete() const;

private:
    std::array<Digit, kCellCount> m_cells{};
};

} // namespace sudoku
