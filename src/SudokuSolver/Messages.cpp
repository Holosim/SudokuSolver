// Messages.cpp — see Messages.h.
//
// This file fills in one message-producing function per issue as the output
// requirements land; this header tracks what's real and what's still a
// scaffold.
//
// #10 ([RTVM-102]) filled in `cellName` and `inputFault` — the wording
// RTVM-102, RTVM-103, RTVM-104, RTVM-105, RTVM-009 and RTVM-403 need.
// #11 ([RTVM-402]) filled in `noSolution` — the reference wording of
// docs/SDD.md 2.8 / docs/RTVM.md 6.2, terminated the same way every other
// message in this file is — GridFormat.cpp's convention of every line
// (including the last) carrying its own '\n', so a caller downstream never
// has to add or guess about a separator (docs/RTVM.md TP-402: "no separator
// line").
// #12 ([RTVM-401]) filled in `notUniqueNote` — the reference wording of
// docs/RTVM.md 6.2, newline-terminated the same way for the same reason.
// #17 ([RTVM-004]) filled in `aborted` and `progressPrompt` — the reference
// wording of docs/RTVM.md 6.2 / docs/SDD.md 2.8, newline-terminated the same
// way for the same reason. (RTVM-400 is `GridFormat.cpp::formatGrid`, not a
// function in this file.) `internalError` (docs/SDD.md 2.9, RTVM-505) is
// still a scaffold.
//
// docs/RTVM.md 6.2 pins exact wording for RTVM-401, RTVM-402, RTVM-404 and
// the progress prompt; RTVM-102..105, RTVM-009 and RTVM-403 are unpinned —
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
    // Reference wording, docs/RTVM.md TP-401 and 6.2. Newline-terminated
    // because Reporter concatenates it directly after formatGrid()'s output,
    // which is itself a sequence of newline-terminated lines (RTVM-401).
    return "Note: this puzzle has more than one solution; "
           "the solution shown is the first one found.\n";
}

std::string noSolution()
{
    return "This puzzle has no solution.\n";
}

std::string aborted()
{
    // Reference wording, docs/RTVM.md 6.2 / 7 I-5. stderr only; TP-005/
    // TP-404 look for "abandoned at" and stdout stays byte-empty (RTVM-404).
    return "Solve abandoned at user request.\n";
}

std::string progressPrompt(int elapsedSeconds, std::uint64_t nodesExplored)
{
    // Pinned verbatim by docs/SDD.md 2.8 / docs/RTVM.md 6.2. The leading
    // "Still working (Ns elapsed)." sentence must stay unbroken so TP-004's
    // regex `Still working \(\d+s elapsed\)\.` matches as written; the step
    // count is the live RTVM-204 counter, which is what makes RTVM-503 ("the
    // solve did not pause") observable from stderr alone.
    return "Still working (" + std::to_string(elapsedSeconds) + "s elapsed). "
        + std::to_string(nodesExplored) + " steps taken. "
          "Type s then Enter to stop; no response needed - the solve continues.\n";
}

std::string internalError()
{
    return std::string{};
}

} // namespace sudoku::cli::messages
