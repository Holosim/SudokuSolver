// Reporter.cpp — see Reporter.h.
//
// The outcome-to-exit-code mapping of RTVM-405 is wired now because
// everything downstream branches on it. The wording each case writes is
// filled in with Messages under the output issues; RTVM-400 (formatGrid) and
// RTVM-401 (the non-unique note) are real as of #9 and #12 respectively.
//
// TODO(RTVM-402, RTVM-403, RTVM-404): write the no-solution line and the
//      diagnostics once Messages carries their real text.

#include "Reporter.h"

#include <ostream>

#include "GridFormat.h"
#include "Messages.h"

namespace sudoku::cli {

Reporter::Reporter(std::ostream& out, std::ostream& err)
    : m_out(out)
    , m_err(err)
{
}

ExitCode Reporter::report(const sudoku::SolveReport& report) const
{
    switch (report.outcome()) {
    case sudoku::Outcome::Solved:
        m_out << sudoku::formatGrid(report.grid());
        return ExitCode::Success;

    case sudoku::Outcome::SolvedNotUnique:
        m_out << sudoku::formatGrid(report.grid())
              << messages::notUniqueNote();
        return ExitCode::Success;

    case sudoku::Outcome::InvalidInput:
        m_err << messages::inputFault(report.fault());
        return ExitCode::InvalidInput;

    case sudoku::Outcome::NoSolution:
        m_out << messages::noSolution();
        return ExitCode::NoSolution;

    case sudoku::Outcome::Aborted:
        m_err << messages::aborted();
        return ExitCode::Aborted;
    }

    // Unreachable: Outcome is closed (RTVM-300). Mapped onto InvalidInput
    // so that no code outside RTVM-405's set can escape.
    return ExitCode::InvalidInput;
}

} // namespace sudoku::cli
