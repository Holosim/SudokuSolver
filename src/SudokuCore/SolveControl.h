// SolveControl.h — the callback the search loop drives.
//
// docs/SDD.md 1.2, 2.6, 3.5. RTVM-203, RTVM-204.
//
// This interface is the whole of the answer to PROJECT_DEFINITION 4.4.1:
// the prompt timer and the stop-response check are polled from inside the
// search rather than awaited on another thread, so nothing ever blocks.
// Implemented by the console layer (SolveSession) and, in tests, directly.

#pragma once

#include <cstdint>

namespace sudoku {

struct SolveProgress {
    std::uint64_t nodesExplored = 0;
    int           currentDepth  = 0;
};

class SolveControl {
public:
    virtual ~SolveControl() = default;

    SolveControl(const SolveControl&) = delete;
    SolveControl& operator=(const SolveControl&) = delete;

    // Return false to request abort. Must not block. Called every
    // SolveOptions::pollNodeInterval nodes.
    virtual bool onPoll(const SolveProgress& progress) = 0;

protected:
    SolveControl() = default;
    SolveControl(SolveControl&&) = default;
    SolveControl& operator=(SolveControl&&) = default;
};

// A control that never aborts. Used where no interaction exists at all.
class NullSolveControl final : public SolveControl {
public:
    bool onPoll(const SolveProgress& progress) override;
};

} // namespace sudoku
