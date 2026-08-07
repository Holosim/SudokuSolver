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

std::uint64_t SolveReport::nodesExplored() const
{
    return m_nodesExplored;
}

} // namespace sudoku
