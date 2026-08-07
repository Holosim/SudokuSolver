// Parser.h — puzzle text to Grid, or to a structured fault.
//
// docs/SDD.md 2.5, 2.9. RTVM-100..106, RTVM 7 I-13.

#pragma once

#include <string_view>

#include "Grid.h"
#include "InputFault.h"

namespace sudoku {

// A single logical line is capped before being declared malformed, so that a
// 1 MB one-line input is a prompt shape fault rather than a megabyte
// buffered to reach the same answer (RTVM 7 I-13).
inline constexpr int kMaxLineBytes = 4096;

// Either a grid or the first fault found — never both, never neither.
// Mirrors SolveReport's shape: no default constructor, so "neither" is
// unrepresentable.
class ParseResult {
public:
    [[nodiscard]] static ParseResult success(Grid g);
    [[nodiscard]] static ParseResult failure(InputFault f);

    [[nodiscard]] bool ok() const;
    [[nodiscard]] const Grid& grid() const;         // precondition: ok()
    [[nodiscard]] const InputFault& fault() const;  // precondition: !ok()

private:
    ParseResult() = default;

    bool       m_ok = false;
    Grid       m_grid{};
    InputFault m_fault{};
};

// Parses puzzle text held in memory. Takes no stream and opens no file:
// sourcing the text is the console layer's job (RTVM-903).
//
// Validation precedence is fixed: shape -> illegal character ->
// contradiction, returning on the first fault found (RTVM-105).
[[nodiscard]] ParseResult parseGrid(std::string_view text);

} // namespace sudoku
