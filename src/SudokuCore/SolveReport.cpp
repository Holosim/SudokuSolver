// SolveReport.cpp — see SolveReport.h. docs/SDD.md 2.4, RTVM-300.

#include "SolveReport.h"

#include <utility>

namespace sudoku {

namespace {

// Returned when a caller asks for a field this outcome does not carry.
// Preconditions are documented, but RTVM-505 means a violation must not be
// undefined behaviour.
const Grid& emptyGrid()
{
    static const Grid g{};
    return g;
}

const InputFault& emptyFault()
{
    static const InputFault f{};
    return f;
}

} // namespace

// Both switches are exhaustive and carry no default label on purpose: a sixth
// outcome appended to the enum makes the compiler point at these two functions
// (MSVC C4062 at /W4, gcc/clang -Wswitch) instead of silently defaulting to
// "carries nothing". Together they are the docs/SDD.md 2.4 invariant table.
bool outcomeCarriesGrid(Outcome outcome)
{
    switch (outcome) {
    case Outcome::Solved:
    case Outcome::SolvedNotUnique:
        return true;
    case Outcome::InvalidInput:
    case Outcome::NoSolution:
    case Outcome::Aborted:
        return false;
    }
    return false;   // unreachable for a valid Outcome; RTVM-505 leaves nothing open
}

bool outcomeCarriesFault(Outcome outcome)
{
    switch (outcome) {
    case Outcome::InvalidInput:
        return true;
    case Outcome::Solved:
    case Outcome::SolvedNotUnique:
    case Outcome::NoSolution:
    case Outcome::Aborted:
        return false;
    }
    return false;   // unreachable for a valid Outcome; RTVM-505 leaves nothing open
}

SolveReport::SolveReport(Outcome o)
    : m_outcome(o)
{
}

SolveReport SolveReport::solved(Grid g, std::uint64_t nodes)
{
    SolveReport r(Outcome::Solved);
    r.m_grid = std::move(g);
    r.m_nodesExplored = nodes;
    return r;
}

SolveReport SolveReport::solvedNotUnique(Grid g, std::uint64_t nodes)
{
    SolveReport r(Outcome::SolvedNotUnique);
    r.m_grid = std::move(g);
    r.m_nodesExplored = nodes;
    return r;
}

SolveReport SolveReport::invalidInput(InputFault f)
{
    SolveReport r(Outcome::InvalidInput);
    r.m_fault = std::move(f);
    return r;
}

SolveReport SolveReport::noSolution(std::uint64_t nodes)
{
    SolveReport r(Outcome::NoSolution);
    r.m_nodesExplored = nodes;
    return r;
}

SolveReport SolveReport::aborted(std::uint64_t nodes)
{
    SolveReport r(Outcome::Aborted);
    r.m_nodesExplored = nodes;
    return r;
}

Outcome SolveReport::outcome() const
{
    return m_outcome;
}

bool SolveReport::hasGrid() const
{
    return m_grid.has_value();
}

const Grid& SolveReport::grid() const
{
    return m_grid.has_value() ? *m_grid : emptyGrid();
}

bool SolveReport::hasFault() const
{
    return m_fault.has_value();
}

const InputFault& SolveReport::fault() const
{
    return m_fault.has_value() ? *m_fault : emptyFault();
}

bool SolveReport::hasCompleteGrid() const
{
    if (!m_grid.has_value()) {
        return false;
    }
    for (int row = 0; row < kGridSize; ++row) {
        for (int col = 0; col < kGridSize; ++col) {
            const int digit = static_cast<int>(m_grid->at(row, col));
            if (digit < 1 || digit > kGridSize) {
                return false;
            }
        }
    }
    return true;
}

std::uint64_t SolveReport::nodesExplored() const
{
    return m_nodesExplored;
}

} // namespace sudoku
