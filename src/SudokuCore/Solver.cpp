// Solver.cpp — see Solver.h.
//
// SCAFFOLD ONLY. The search described in docs/SDD.md 1.5 (bitmask
// propagation of naked and hidden singles to fixpoint, then depth-first
// search ordered by minimum remaining values, candidates tried in ascending
// digit order) is implemented under its own issue.
//
// TODO(RTVM-200, RTVM-201, RTVM-202, RTVM-203, RTVM-204): real search.

#include "Solver.h"

namespace sudoku {

SolveReport solve(const Grid& puzzle,
                  const SolveOptions& options,
                  SolveControl& control)
{
    static_cast<void>(puzzle);
    static_cast<void>(options);
    static_cast<void>(control);

    // Placeholder result. Chosen because it carries no grid, so nothing
    // downstream can mistake it for a solved puzzle.
    return SolveReport::noSolution(0);
}

} // namespace sudoku
