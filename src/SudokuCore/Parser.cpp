// Parser.cpp — see Parser.h.
//
// docs/SDD.md 2.5, 2.6, 2.9. RTVM-100, RTVM-101, RTVM-106, RTVM 7 I-1..I-3,
// I-13.
//
// The parse is two passes over the same nine logical lines, and the split is
// deliberate: RTVM-105 fixes the precedence shape -> illegal character ->
// contradiction across the *whole* input, not line by line. A single pass
// that validated each line completely before moving on would report the `X`
// in P-MULTIFAULT's line 1 ahead of its missing line 9 and fail TP-105.
//
// TODO(RTVM-104, issue #10): the contradiction pass (row / column / box
// duplicate among the givens) is the third stage of that precedence and is
// not implemented here. Issue #6 covers the accepting path only; until #10
// lands, a self-contradictory but well-shaped puzzle parses successfully and
// is left for the solver to discover has no completion.

#include "Parser.h"

#include <array>
#include <cstddef>
#include <utility>

namespace sudoku {

ParseResult ParseResult::success(Grid g)
{
    ParseResult r;
    r.m_ok = true;
    r.m_grid = std::move(g);
    return r;
}

ParseResult ParseResult::failure(InputFault f)
{
    ParseResult r;
    r.m_ok = false;
    r.m_fault = std::move(f);
    return r;
}

bool ParseResult::ok() const
{
    return m_ok;
}

const Grid& ParseResult::grid() const
{
    return m_grid;
}

const InputFault& ParseResult::fault() const
{
    return m_fault;
}

namespace {

// One logical line of the input, already stripped of its ends.
struct LogicalLine {
    std::string_view text;             // stripped content
    bool             overCap = false;  // raw bytes ran past kMaxLineBytes
};

// Horizontal whitespace only. Vertical tab and form feed are content, and
// therefore illegal characters in the grid — RTVM-106 says "horizontal".
[[nodiscard]] constexpr bool isHorizontalSpace(char c) noexcept
{
    return c == ' ' || c == '\t';
}

[[nodiscard]] std::string_view trimHorizontal(std::string_view s) noexcept
{
    std::size_t begin = 0;
    std::size_t end = s.size();
    while (begin < end && isHorizontalSpace(s[begin])) {
        ++begin;
    }
    while (end > begin && isHorizontalSpace(s[end - 1])) {
        --end;
    }
    return s.substr(begin, end - begin);
}

// The digit a grid character denotes: kEmpty for `0` and `.` (RTVM-101),
// 1..kGridSize for a given. Returns -1 for anything else, which includes
// interior whitespace, NUL, and every byte of a binary file (RTVM-103).
[[nodiscard]] constexpr int digitValue(char c) noexcept
{
    if (c == '0' || c == '.') {
        return static_cast<int>(kEmpty);
    }
    if (c >= '1' && c <= static_cast<char>('0' + kGridSize)) {
        return c - '0';
    }
    return -1;
}

// Splits text into at most kGridSize logical lines, stopping the moment the
// ninth is complete: content after line 9 is ignored and never even scanned
// (RTVM 7 I-2). No line is scanned past kMaxLineBytes raw bytes, so a 1 MB
// single-line input costs one 4 KB scan rather than a megabyte (I-13).
//
// Returns the number of lines found.
[[nodiscard]] int splitLines(std::string_view text,
                             std::array<LogicalLine, kGridSize>& lines) noexcept
{
    constexpr std::size_t kScanWindow = static_cast<std::size_t>(kMaxLineBytes) + 1;

    int count = 0;
    std::size_t pos = 0;

    while (count < kGridSize && pos < text.size()) {
        // Look for the terminator within the cap window only.
        const std::size_t remaining = text.size() - pos;
        const std::size_t window = remaining < kScanWindow ? remaining : kScanWindow;

        const std::string_view scanned = text.substr(pos, window);
        const std::size_t newline = scanned.find('\n');

        LogicalLine line;
        if (newline == std::string_view::npos) {
            if (window < remaining) {
                // The cap was reached with no terminator in sight. The line
                // is malformed whatever follows it, so stop reading here.
                line.overCap = true;
                line.text = scanned;
                lines[static_cast<std::size_t>(count)] = line;
                return count + 1;
            }
            // Final line, no trailing newline — accepted (RTVM 7 I-1).
            line.text = trimHorizontal(scanned);
            pos = text.size();
        } else {
            std::string_view raw = scanned.substr(0, newline);
            if (!raw.empty() && raw.back() == '\r') {
                raw.remove_suffix(1);   // CRLF; the CR belongs to the ending
            }
            line.text = trimHorizontal(raw);
            pos += newline + 1;
        }

        lines[static_cast<std::size_t>(count)] = line;
        ++count;
    }

    return count;
}

// Pass 1: shape. Returns true and fills fault if any line cannot serve as a
// row of kGridSize cells.
//
// Interior whitespace is classified here rather than in the character pass,
// because RTVM-102 measures a line "after the rules of RTVM-106 are
// applied" and RTVM-106 makes interior whitespace an illegal character. So
// the space in TP-106's negative case `098 000060` is reported as an
// illegal character at r3c4 rather than as a ten-character line. See the
// note on issue #6 — that reading is flagged to the Systems Engineer for
// confirmation alongside RTVM-102 (#10).
[[nodiscard]] bool findShapeFault(const std::array<LogicalLine, kGridSize>& lines,
                                  int lineCount,
                                  InputFault& fault)
{
    for (int i = 0; i < lineCount; ++i) {
        const LogicalLine& line = lines[static_cast<std::size_t>(i)];
        const int lineNumber = i + 1;

        if (line.overCap) {
            fault = InputFault{};
            fault.kind = FaultKind::LineTooLong;
            fault.line = lineNumber;
            fault.observedLength = kLengthExceedsCap;
            return true;
        }

        for (std::size_t col = 0; col < line.text.size(); ++col) {
            if (isHorizontalSpace(line.text[col])) {
                fault = InputFault{};
                fault.kind = FaultKind::IllegalCharacter;
                fault.line = lineNumber;
                fault.character = line.text[col];
                fault.first = CellRef{ lineNumber, static_cast<int>(col) + 1 };
                return true;
            }
        }

        const int length = static_cast<int>(line.text.size());
        if (length != kGridSize) {
            fault = InputFault{};
            fault.kind = length < kGridSize ? FaultKind::LineTooShort
                                            : FaultKind::LineTooLong;
            fault.line = lineNumber;
            fault.observedLength = length;
            return true;
        }
    }

    if (lineCount < kGridSize) {
        // Names the first line that never arrived, which is what TP-102's
        // "input ended early" case expects to read.
        fault = InputFault{};
        fault.kind = FaultKind::MissingLine;
        fault.line = lineCount + 1;
        return true;
    }

    return false;
}

} // namespace

ParseResult parseGrid(std::string_view text)
{
    std::array<LogicalLine, kGridSize> lines{};
    const int lineCount = splitLines(text, lines);

    InputFault fault{};
    if (findShapeFault(lines, lineCount, fault)) {
        return ParseResult::failure(fault);
    }

    // Pass 2: characters. Every line is known to hold exactly kGridSize
    // bytes by now, so this only has to classify them.
    Grid grid;
    for (int row = 0; row < kGridSize; ++row) {
        const std::string_view line = lines[static_cast<std::size_t>(row)].text;
        for (int col = 0; col < kGridSize; ++col) {
            const char c = line[static_cast<std::size_t>(col)];
            const int value = digitValue(c);
            if (value < 0) {
                fault = InputFault{};
                fault.kind = FaultKind::IllegalCharacter;
                fault.line = row + 1;
                fault.character = c;
                fault.first = CellRef{ row + 1, col + 1 };
                return ParseResult::failure(fault);
            }
            grid.set(row, col, static_cast<Digit>(value));
        }
    }

    return ParseResult::success(std::move(grid));
}

} // namespace sudoku
