// Solver.h — constraint propagation with MRV-ordered backtracking.
//
// docs/SDD.md 1.5, 2.6. RTVM-200..204, RTVM-500.

#pragma once

#include <chrono>
#include <cstdint>

#include "Grid.h"
#include "SolveControl.h"
#include "SolveReport.h"

namespace sudoku {

// Poll cadence, in search nodes. At a 9x9 node rate of 1e6-1e7/s this is a
// callback every few microseconds to a few milliseconds, which is what keeps
// RTVM-203's 1.0 s abort latency comfortable.
inline constexpr std::uint32_t kPollNodeInterval = 1024;

// Stop after this many solutions. Two is enough to answer "is it unique?"
// without enumerating (RTVM-202, RTVM 7 I-8).
inline constexpr int kMaxSolutions = 2;

struct SolveOptions {
    int                       maxSolutions     = kMaxSolutions;      // RTVM-202
    std::uint32_t             pollNodeInterval = kPollNodeInterval;  // RTVM-203/204
    std::chrono::milliseconds minSolveDuration{0};                   // RTVM-507 hook
};

// Searches for at most options.maxSolutions solutions, calling control.onPoll
// every options.pollNodeInterval nodes and unwinding when it returns false.
//
// Never touches a stream, the command line, or the environment (RTVM-903):
// the RTVM-507 minSolveDuration value is read from the environment by the
// console layer and passed in here.
[[nodiscard]] SolveReport solve(const Grid& puzzle,
                                const SolveOptions& options,
                                SolveControl& control);

} // namespace sudoku
