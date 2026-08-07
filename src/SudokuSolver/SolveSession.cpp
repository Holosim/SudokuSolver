// SolveSession.cpp — see SolveSession.h.
//
// SCAFFOLD ONLY. The prompt schedule and the stop-response check are
// implemented under their own issues; the poll already returns without
// waiting, which is the property everything else depends on.
//
// TODO(RTVM-004, RTVM-005, RTVM-501, RTVM-502): emit the prompt when
//      elapsed reaches the deadline and advance the deadline by
//      kPromptInterval.
// TODO(RTVM-005, RTVM-006): consume available lines from the control
//      channel and set m_stopRequested on the stop response.

#include "SolveSession.h"

#include <ostream>

namespace sudoku::cli {

SolveSession::SolveSession(StdinChannel& control, std::ostream& promptStream)
    : m_control(control)
    , m_promptStream(promptStream)
    , m_start(Clock::now())
{
}

bool SolveSession::onPoll(const sudoku::SolveProgress& progress)
{
    static_cast<void>(progress);
    return !m_stopRequested;
}

bool SolveSession::stopRequested() const
{
    return m_stopRequested;
}

bool SolveSession::isStopResponse(std::string_view line)
{
    static_cast<void>(line);
    return false;
}

} // namespace sudoku::cli
