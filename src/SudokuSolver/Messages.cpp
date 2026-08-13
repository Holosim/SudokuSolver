// Messages.cpp — see Messages.h.
//
// This issue ([RTVM-102], #10) fills in `cellName` and `inputFault` — the
// wording RTVM-102, RTVM-103, RTVM-104, RTVM-105, RTVM-009 and RTVM-403
// need. The remaining functions stay scaffolds; their wording belongs to the
// output issues that own RTVM-400..404.
//
// TODO(RTVM-400, RTVM-401, RTVM-402, RTVM-404, RTVM-004): real wording.
//
// docs/RTVM.md 6.2 pins exact wording only for RTVM-401/402/404 and the
// progress prompt; RTVM-102..105, RTVM-009 and RTVM-403 are unpinned —
// TP-102..105, TP-009 and TP-403 assert the *elements* a diagnostic must
// name, not an exact sentence, and docs/RTVM.md 7 I-18 additionally forbids
// pinning the CRT/errno reason text for RTVM-009. Every sentence below is
// still built from exactly one template per fault kind so the wording stays
// centralised here rather than reappearing ad hoc at a call site.

#include "Messages.h"

#include <cstring>

#include "Grid.h"
#include "Parser.h"

namespace sudoku::cli::messages {

namespace {

// "line N has been reported": the exact-length/over-cap distinction of
// docs/RTVM.md 7 I-13. `Messages` is the one place that sentinel is allowed
// to become "more than 4096 characters" instead of the number itself.
[[nodiscard]] std::string lengthPhrase(int observedLength)
{
    if (observedLength == sudoku::kLengthExceedsCap) {
        return "more than " + std::to_string(sudoku::kMaxLineBytes) + " characters";
    }
    return std::to_string(observedLength) + " characters";
}

// The row-major 1-based box number (1..kGridSize) a 1-based cell sits in —
// display-only arithmetic, not a fault-detection judgement, so it belongs
// here rather than in the core (RTVM-903).
[[nodiscard]] int boxNumber(const sudoku::CellRef& cell)
{
    const int row0 = cell.row - 1;
    const int col0 = cell.col - 1;
    return (row0 / sudoku::kBoxSize) * sudoku::kBoxSize + col0 / sudoku::kBoxSize + 1;
}

// "digit D appears twice in <unit>, at <cellA> and <cellB>." — the one
// sentence shape RTVM-104's three duplicate kinds share; only the unit
// clause differs between them.
[[nodiscard]] std::string duplicatePhrase(const std::string& unit, const InputFault& fault)
{
    return "Malformed input: digit " + std::to_string(fault.digit) + " appears twice in "
        + unit + ", at " + cellName(fault.first) + " and " + cellName(fault.second) + ".";
}

// std::strerror is the one place a CRT/errno string is allowed to enter a
// message (docs/RTVM.md 7 I-18): it is rendered text, not a literal baked
// into InputFault, so RTVM-302's "no prose in the fault" is untouched.
[[nodiscard]] std::string errnoReason(std::uint32_t systemError)
{
    if (systemError == 0) {
        return "reason unknown";
    }
    return std::strerror(static_cast<int>(systemError));
}

} // namespace

std::string cellName(const CellRef& cell)
{
    return "r" + std::to_string(cell.row) + "c" + std::to_string(cell.col);
}

std::string inputFault(const InputFault& fault)
{
    switch (fault.kind) {
    case FaultKind::MissingLine:
        return "Malformed input: line " + std::to_string(fault.line)
            + " is missing (the input ended after line "
            + std::to_string(fault.line - 1) + ").";

    case FaultKind::LineTooShort:
        return "Malformed input: line " + std::to_string(fault.line)
            + " is too short (" + lengthPhrase(fault.observedLength) + "; expected "
            + std::to_string(sudoku::kGridSize) + ").";

    case FaultKind::LineTooLong:
        return "Malformed input: line " + std::to_string(fault.line)
            + " is too long (" + lengthPhrase(fault.observedLength) + "; expected "
            + std::to_string(sudoku::kGridSize) + ").";

    case FaultKind::IllegalCharacter:
        return std::string("Malformed input: illegal character '") + fault.character
            + "' at " + cellName(fault.first) + ".";

    case FaultKind::RowDuplicate:
        return duplicatePhrase("row " + std::to_string(fault.first.row), fault);

    case FaultKind::ColumnDuplicate:
        return duplicatePhrase("column " + std::to_string(fault.first.col), fault);

    case FaultKind::BoxDuplicate:
        return duplicatePhrase("box " + std::to_string(boxNumber(fault.first)), fault);

    case FaultKind::SourceUnreadable:
        return "Cannot open '" + fault.path + "': " + errnoReason(fault.systemError) + ".";
    }

    // Unreachable: FaultKind is a closed set and every member is handled
    // above (no default label, so an appended member fails the build under
    // -Wswitch / MSVC C4062 rather than silently falling through here).
    return "Malformed input.";
}

std::string notUniqueNote()
{
    return std::string{};
}

std::string noSolution()
{
    return std::string{};
}

std::string aborted()
{
    return std::string{};
}

std::string progressPrompt(int elapsedSeconds, std::uint64_t nodesExplored)
{
    static_cast<void>(elapsedSeconds);
    static_cast<void>(nodesExplored);
    return std::string{};
}

std::string internalError()
{
    return std::string{};
}

} // namespace sudoku::cli::messages
