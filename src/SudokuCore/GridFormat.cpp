// GridFormat.cpp — see GridFormat.h.
//
// docs/SDD.md 2.6, 2.8. RTVM-400, docs/RTVM.md 6.2.
//
// The 13-line block is built from kBoxSize rather than from literals, so the
// same code emits the 5-line block for a 4x4 grid and the 21-line block for a
// 16x16 one. TP-903 greps the core for a bare dimension literal; the widths
// below are the derivation, not a coincidence:
//
//   line width  = 1 + kBoxSize * (2 * kBoxSize + 2)   == 25 for kBoxSize 3
//   line count  = kGridSize + kBoxSize + 1            == 13 for kBoxSize 3
//
// ASCII only, deliberately (docs/RTVM.md 6.2): under a non-UTF-8 code page
// U+2500-range box characters render as mojibake, which would break both
// legibility (SN-3) and the byte comparison TP-400 makes.

#include "GridFormat.h"

#include <cstddef>

namespace sudoku {

namespace {

// Every character the format is made of, named once. Nothing here is above
// U+007F, which is the property TP-400 asserts over the whole block.
inline constexpr char kCorner    = '+';
inline constexpr char kRule      = '-';
inline constexpr char kWall      = '|';
inline constexpr char kGap       = ' ';
inline constexpr char kNewline   = '\n';
inline constexpr char kEmptyCell = '.';

// One cell contributes a separating space and a character; a box adds its
// closing space and wall. Stated here so the reserve below and the widths in
// the file header cannot drift apart.
inline constexpr int kCharsPerCell = 2;
inline constexpr int kCharsPerBox  = kBoxSize * kCharsPerCell + 2;
inline constexpr int kLineWidth    = 1 + kBoxSize * kCharsPerBox;
inline constexpr int kLineCount    = kGridSize + kBoxSize + 1;

// The largest digit that renders as one character. Derived from the character
// set rather than written as a literal, both because TP-903 greps the core for
// bare grid-dimension literals and because this bound is genuinely a property
// of ASCII digits, not of sudoku.
inline constexpr int kMaxSingleCharacterDigit = '9' - '0';

// formatGrid renders one character per cell. A wider grid is not a code change
// here alone: docs/RTVM.md 6.2 is normative for the format and says nothing
// about two-character cells, so that decision belongs to requirements before it
// belongs to this function. This is the assertion that makes the 16x16 tier
// stop here and ask, rather than silently emit a misaligned block.
static_assert(kGridSize <= kMaxSingleCharacterDigit,
    "formatGrid renders one character per cell; a wider grid needs a "
    "docs/RTVM.md 6.2 format decision first (RTVM-400)");

// `+-------+-------+-------+`, terminated.
void appendSeparator(std::string& out)
{
    out.push_back(kCorner);
    for (int box = 0; box < kBoxSize; ++box) {
        out.append(static_cast<std::size_t>(kCharsPerBox - 1), kRule);
        out.push_back(kCorner);
    }
    out.push_back(kNewline);
}

// `| 5 3 4 | 6 7 8 | 9 1 2 |`, terminated.
//
// An empty cell renders as `.` — the same character RTVM-101 accepts on input.
// RTVM-400 only ever asks for a solved grid, so this is a robustness path
// rather than a format (RTVM-505: no input produces garbage output), and it is
// what makes a partially filled grid legible in a debugger.
void appendRow(std::string& out, const Grid& grid, int row)
{
    out.push_back(kWall);
    for (int col = 0; col < kGridSize; ++col) {
        const Digit digit = grid.at(row, col);
        out.push_back(kGap);
        out.push_back(digit >= 1 && digit <= kGridSize
            ? static_cast<char>('0' + static_cast<int>(digit))
            : kEmptyCell);

        if ((col + 1) % kBoxSize == 0) {
            out.push_back(kGap);
            out.push_back(kWall);
        }
    }
    out.push_back(kNewline);
}

} // namespace

std::string formatGrid(const Grid& grid)
{
    // Every line carries its terminator, including the last: the block is a
    // complete unit of output, so a caller never has to add a newline and
    // whatever is written next starts on its own line. TP-400 counts 13 lines
    // and normalises line endings, which this satisfies either way.
    std::string out;
    out.reserve(static_cast<std::size_t>(kLineCount) * (static_cast<std::size_t>(kLineWidth) + 1));

    for (int row = 0; row < kGridSize; ++row) {
        if (row % kBoxSize == 0) {
            appendSeparator(out);
        }
        appendRow(out, grid, row);
    }
    appendSeparator(out);

    return out;
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
