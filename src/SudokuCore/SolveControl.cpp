// SolveControl.cpp — see SolveControl.h. docs/SDD.md 2.6.

#include "SolveControl.h"

namespace sudoku {

bool NullSolveControl::onPoll(const SolveProgress& progress)
{
    static_cast<void>(progress);
    return true;   // never aborts
}

} // namespace sudoku
