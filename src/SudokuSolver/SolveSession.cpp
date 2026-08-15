// SolveSession.cpp — see SolveSession.h.
//
// Landed at [RTVM-004] (issue #17): the prompt schedule (RTVM-004, RTVM-501,
// RTVM-502), the stop-response check (RTVM-005, RTVM-006) and their
// interaction with a completed or aborted solve (RTVM-007, RTVM-503). Every
// piece of this is a single non-blocking poll -- see docs/SDD.md 1.2's
// state-diagram properties: there is no state in which the program waits,
// and nothing here can put it in one.

#include "SolveSession.h"

#include <ostream>

#include "Messages.h"

namespace sudoku::cli {

namespace {

[[nodiscard]] bool isHorizontalWhitespace(char c)
{
    return c == ' ' || c == '\t';
}

} // namespace

SolveSession::SolveSession(StdinChannel& control, std::ostream& promptStream)
    : m_control(control)
    , m_promptStream(promptStream)
    , m_start(Clock::now())
{
}

bool SolveSession::onPoll(const sudoku::SolveProgress& progress)
{
    if (m_stopRequested) {
        return false;
    }

    const Clock::duration elapsed = Clock::now() - m_start;
    if (elapsed >= m_nextPromptAt) {
        const auto elapsedSeconds =
            std::chrono::duration_cast<std::chrono::seconds>(elapsed).count();
        m_promptStream << messages::progressPrompt(static_cast<int>(elapsedSeconds),
                                                     progress.nodesExplored);
        // Anchored to the nominal 15s/25s/35s.. schedule rather than to when
        // this poll happened to notice, so poll granularity cannot drift
        // RTVM-502's tolerance (docs/RTVM.md 7 I-6).
        m_nextPromptAt += kPromptInterval;
    }

    // Drain every line currently available. Each is either the stop
    // response or is ignored silently -- no reply is ever required
    // (RTVM-006) -- and none of this can block: tryReadLine never waits.
    std::string line;
    while (m_control.tryReadLine(line)) {
        if (isStopResponse(line)) {
            m_stopRequested = true;
            break;
        }
    }

    return !m_stopRequested;
}

bool SolveSession::stopRequested() const
{
    return m_stopRequested;
}

bool SolveSession::isStopResponse(std::string_view line)
{
    std::size_t start = 0;
    while (start < line.size() && isHorizontalWhitespace(line[start])) {
        ++start;
    }
    if (start == line.size()) {
        return false;   // blank line: not a stop response, not an error
    }

    // "First non-whitespace character is 's'/'S'" already subsumes "trimmed
    // content case-insensitively equals 'stop'" (docs/SDD.md 1.3): every
    // spelling of "stop" starts with one of those two characters, so a
    // single check satisfies both clauses of the spec.
    const char first = line[start];
    return first == 's' || first == 'S';
}

} // namespace sudoku::cli
