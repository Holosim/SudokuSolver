// SolveSession.h — the console layer's SolveControl.
//
// docs/SDD.md 1.2, 1.6, 2.7. RTVM-004..008, RTVM-501..504.
//
// Owns the steady_clock start point, the next-prompt deadline and the
// stop-response check. Every onPoll call does two non-blocking things and
// returns: read the clock and maybe write a prompt, then ask the control
// channel whether a complete line is available right now. There is no
// waiting state -- an unanswered prompt is the absence of a transition, not
// a state the program sits in.

#pragma once

#include <chrono>
#include <iosfwd>
#include <string_view>

#include "SolveControl.h"
#include "StdinChannel.h"

namespace sudoku::cli {

// RTVM-501 / RTVM-502, both +/- 1.0 s (docs/RTVM.md 7 I-6).
inline constexpr std::chrono::seconds kFirstPromptDelay{15};
inline constexpr std::chrono::seconds kPromptInterval{10};

class SolveSession final : public sudoku::SolveControl {
public:
    // 'promptStream' is stderr in production (RTVM-004, RTVM-406); tests
    // pass their own stream.
    SolveSession(StdinChannel& control, std::ostream& promptStream);

    // Non-blocking. Returns false once the stop response has been seen.
    bool onPoll(const sudoku::SolveProgress& progress) override;

    // True when the abort came from the user's stop response (RTVM-005).
    [[nodiscard]] bool stopRequested() const;

    // A line whose first non-whitespace character is 's' or 'S', or whose
    // trimmed content case-insensitively equals "stop". Any other line is
    // ignored silently -- it is not an error and does not abort (RTVM-006).
    [[nodiscard]] static bool isStopResponse(std::string_view line);

private:
    using Clock = std::chrono::steady_clock;

    StdinChannel&    m_control;
    std::ostream&    m_promptStream;
    Clock::time_point m_start{};
    Clock::duration  m_nextPromptAt{kFirstPromptDelay};
    bool             m_stopRequested = false;
};

} // namespace sudoku::cli
