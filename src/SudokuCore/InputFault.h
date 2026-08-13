// InputFault.h — structured (wording-free) description of a rejected input.
//
// docs/SDD.md 2.5. RTVM-302: the fault is data, never a pre-formatted
// sentence, so that every English string lives in the output layer
// (Messages) and TP-302 can assert this object contains no prose.

#pragma once

#include <cstdint>
#include <string>

#include "Grid.h"

namespace sudoku {

enum class FaultKind : std::uint8_t {
    MissingLine,       // fewer than kGridSize lines
    LineTooShort,
    LineTooLong,
    IllegalCharacter,
    RowDuplicate,
    ColumnDuplicate,
    BoxDuplicate,
    SourceUnreadable   // populated by the CLI, not the parser
};

// 1-based, as rendered; 0 means "not applicable".
struct CellRef {
    int row = 0;
    int col = 0;

    // False for a default-constructed reference, i.e. this fault kind names
    // no cell. The output layer decides on this, not on a magic 0 test.
    [[nodiscard]] constexpr bool isApplicable() const noexcept
    {
        return row != 0 && col != 0;
    }
};

[[nodiscard]] constexpr bool operator==(const CellRef& lhs, const CellRef& rhs) noexcept
{
    return lhs.row == rhs.row && lhs.col == rhs.col;
}

[[nodiscard]] constexpr bool operator!=(const CellRef& lhs, const CellRef& rhs) noexcept
{
    return !(lhs == rhs);
}

// The single place the 0-based internal coordinates of docs/SDD.md 2.3 become
// the 1-based form a fault carries. Grid positions are 0-based everywhere in
// the core and 1-based the moment they become diagnostic data, and an
// off-by-one here fails TP-103, TP-104 and TP-302 at once — so the +1 is
// spelled exactly once, here, and every fault-producing path calls it rather
// than adding one itself.
//
// A coordinate outside the grid yields a "not applicable" reference rather
// than a nonsense cell name: RTVM-505 requires that no input path can produce
// a crash or a garbage diagnostic.
[[nodiscard]] constexpr CellRef cellRefFromZeroBased(int row, int col) noexcept
{
    const bool inRange = row >= 0 && row < kGridSize && col >= 0 && col < kGridSize;
    return inRange ? CellRef{ row + 1, col + 1 } : CellRef{};
}

// RTVM-302: every member below is a coordinate, a code, a count or a single
// character. There is deliberately no message, description or detail string —
// `path` is a filesystem path echoed back to the user, not a sentence, and it
// is populated only for SourceUnreadable. A fault therefore cannot carry
// wording even by accident, which is what makes Messages the one place any
// English exists (docs/SDD.md 2.5, 2.7).
struct InputFault {
    FaultKind     kind{};
    int           line = 0;              // 1-based; 0 == n/a
    int           observedLength = 0;    // LineTooShort / LineTooLong
    char          character = '\0';      // IllegalCharacter
    int           digit = 0;             // *Duplicate
    CellRef       first;                 // IllegalCharacter, *Duplicate
    CellRef       second;                // *Duplicate only
    std::string   path;                  // SourceUnreadable only
    std::uint32_t systemError = 0;       // SourceUnreadable only (GetLastError)
};

} // namespace sudoku
