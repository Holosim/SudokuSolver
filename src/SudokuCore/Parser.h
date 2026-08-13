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

// Sentinel for InputFault::observedLength. A line at or under the cap
// reports its exact stripped length (TP-102 expects that); a line whose raw
// bytes ran past the cap reports this value instead, which the output layer
// renders as "more than kMaxLineBytes characters" (RTVM 7 I-13). The parser
// never scans further than the cap, so the exact length is genuinely not
// known in that case rather than merely withheld.
inline constexpr int kLengthExceedsCap = kMaxLineBytes + 1;

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
// Line handling (RTVM-106, RTVM 7 I-1..I-3):
//   - LF and CRLF both terminate a line; one trailing CR is consumed with
//     the LF rather than treated as content.
//   - A trailing newline after the ninth line is optional.
//   - Leading and trailing horizontal whitespace (space, tab) is stripped
//     from every line before it is measured. Whitespace anywhere else in
//     the line is an illegal character, never stripped.
//   - Everything after the ninth line is ignored and never scanned.
//   - Text is treated as bytes throughout: a NUL byte is content (and, in
//     the grid, an illegal character), not a terminator (docs/SDD.md 2.9).
//
// Validation precedence is fixed: shape -> illegal character ->
// contradiction, returning on the first fault found (RTVM-105).
[[nodiscard]] ParseResult parseGrid(std::string_view text);

} // namespace sudoku
