// Parser.cpp — see Parser.h.
//
// docs/SDD.md 2.5, 2.6, 2.9. RTVM-100, RTVM-101, RTVM-102..106, RTVM 7
// I-1..I-3, I-13, I-15.
//
// The parse is three passes over the same nine logical lines, and the split
// is deliberate: RTVM-105 fixes the precedence shape -> illegal character ->
// contradiction across the *whole* input, not line by line. A single pass
// that validated each line completely before moving on would report the `X`
// in P-MULTIFAULT's line 1 ahead of its missing line 9 and fail TP-105. Each
// pass only runs once the previous one has cleared the whole grid, so a
// contradiction is never even looked for until every character is known
// legal (RTVM-105).

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
// illegal character at r3c4 rather than as a ten-character line — ruled
// 2026-08-13 as docs/RTVM.md 7 I-15, narrowly: only against the length
// check of the line the whitespace is on.
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

// Which of the 3x3 boxes (row-major, 0-based) a cell belongs to.
[[nodiscard]] constexpr int boxIndex(int row, int col) noexcept
{
    return (row / kBoxSize) * kBoxSize + col / kBoxSize;
}

// Pass 3: contradiction. Every cell is known to hold a legal digit by now
// (kEmpty or 1..kGridSize), so this only has to notice a repeat among the
// givens. RTVM-104 names three unit kinds; RTVM-105 says nothing about an
// order among them, so a single deterministic scan is used throughout:
// cells are visited in row-major reading order, and for each given the row
// is checked before the column before the box against every earlier given
// already seen. That is what makes P-CONTRA-ROW report `r1c1`/`r1c7` (the
// row match on r1c7 is found before its column or box are even consulted)
// and P-CONTRA-BOX report `r1c2`/`r3c3` (the earlier box member, not the
// scanning cell itself, is always `first`).
//
// Each *Seen table is addressed [unit index][digit - 1]; kEmpty is 0 and is
// therefore never entered, since an empty cell is never a "given" to
// contradict.
[[nodiscard]] bool findContradictionFault(const Grid& grid, InputFault& fault)
{
    using SeenTable = std::array<std::array<CellRef, kGridSize>, kGridSize>;

    SeenTable rowSeen{};
    SeenTable colSeen{};
    SeenTable boxSeen{};

    for (int row = 0; row < kGridSize; ++row) {
        for (int col = 0; col < kGridSize; ++col) {
            const Digit digit = grid.at(row, col);
            if (digit == kEmpty) {
                continue;
            }
            const std::size_t d = static_cast<std::size_t>(digit) - 1;
            const int box = boxIndex(row, col);
            const CellRef here = cellRefFromZeroBased(row, col);

            const CellRef earlierInRow = rowSeen[static_cast<std::size_t>(row)][d];
            const CellRef earlierInCol = colSeen[static_cast<std::size_t>(col)][d];
            const CellRef earlierInBox = boxSeen[static_cast<std::size_t>(box)][d];

            if (earlierInRow.isApplicable()) {
                fault = InputFault{};
                fault.kind  = FaultKind::RowDuplicate;
                fault.digit = static_cast<int>(digit);
                fault.line  = row + 1;
                fault.first  = earlierInRow;
                fault.second = here;
                return true;
            }
            if (earlierInCol.isApplicable()) {
                // Unlike a row duplicate, no single line names a column
                // conflict (its two cells sit on different lines), so
                // `line` stays 0 -- "not applicable" -- and the location
                // is carried entirely by `first`/`second` (docs/SDD.md 2.5).
                fault = InputFault{};
                fault.kind  = FaultKind::ColumnDuplicate;
                fault.digit = static_cast<int>(digit);
                fault.first  = earlierInCol;
                fault.second = here;
                return true;
            }
            if (earlierInBox.isApplicable()) {
                // Same reasoning as the column case above.
                fault = InputFault{};
                fault.kind  = FaultKind::BoxDuplicate;
                fault.digit = static_cast<int>(digit);
                fault.first  = earlierInBox;
                fault.second = here;
                return true;
            }

            rowSeen[static_cast<std::size_t>(row)][d] = here;
            colSeen[static_cast<std::size_t>(col)][d] = here;
            boxSeen[static_cast<std::size_t>(box)][d] = here;
        }
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

    // Pass 3: contradiction (RTVM-104). Only reached once every cell is
    // known to hold a legal digit, so a rejected puzzle is never handed to
    // the solver either for a bad shape, a bad character, or a repeat
    // (RTVM-105).
    if (findContradictionFault(grid, fault)) {
        return ParseResult::failure(fault);
    }

    return ParseResult::success(std::move(grid));
}

} // namespace sudoku
