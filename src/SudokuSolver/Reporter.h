// Reporter.h — stream assignment and exit code, in one place.
//
// docs/SDD.md 2.7, 2.8. RTVM-400..406.
//
// Stream choice is decided here and nowhere else, because RTVM-406 is an
// aggregate assertion over everything stdout ever carries, and per-message
// rules are what drift.

#pragma once

#include <iosfwd>

#include "SolveReport.h"

namespace sudoku::cli {

// The complete set RTVM-405 permits. No other value is reachable, which is
// why main's catch-all maps an internal fault onto InvalidInput rather than
// inventing a code.
enum class ExitCode : int {
    Success      = 0,   // Solved, SolvedNotUnique
    InvalidInput = 1,
    NoSolution   = 2,
    Aborted      = 3
};

class Reporter {
public:
    Reporter(std::ostream& out, std::ostream& err);

    // Writes the report to the correct stream and returns the exit code
    // for the outcome. stdout carries the result and nothing else.
    [[nodiscard]] ExitCode report(const sudoku::SolveReport& report) const;

private:
    std::ostream& m_out;
    std::ostream& m_err;
};

} // namespace sudoku::cli
