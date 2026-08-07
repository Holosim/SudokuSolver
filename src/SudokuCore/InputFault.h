// InputFault.h — structured (wording-free) description of a rejected input.
//
// docs/SDD.md 2.5. RTVM-302: the fault is data, never a pre-formatted
// sentence, so that every English string lives in the output layer
// (Messages) and TP-302 can assert this object contains no prose.

#pragma once

#include <cstdint>
#include <string>

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
};

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
