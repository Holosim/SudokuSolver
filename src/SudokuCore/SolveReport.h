// SolveReport.h — the closed outcome set and the value a run produces.
//
// docs/SDD.md 2.4. RTVM-300: exactly one outcome per run, never none and
// never two. That is enforced by the type itself — no default constructor,
// no "Unknown" member, and construction only through the five factories.

#pragma once

#include <cstdint>
#include <optional>

#include "Grid.h"
#include "InputFault.h"

namespace sudoku {

enum class Outcome : std::uint8_t {
    Solved, SolvedNotUnique, InvalidInput, NoSolution, Aborted
};

class SolveReport {
public:
    [[nodiscard]] static SolveReport solved(Grid g, std::uint64_t nodes);
    [[nodiscard]] static SolveReport solvedNotUnique(Grid g, std::uint64_t nodes);
    [[nodiscard]] static SolveReport invalidInput(InputFault f);
    [[nodiscard]] static SolveReport noSolution(std::uint64_t nodes);
    [[nodiscard]] static SolveReport aborted(std::uint64_t nodes);

    [[nodiscard]] Outcome outcome() const;
    [[nodiscard]] bool hasGrid() const;
    [[nodiscard]] const Grid& grid() const;            // precondition: hasGrid()
    [[nodiscard]] bool hasFault() const;
    [[nodiscard]] const InputFault& fault() const;     // precondition: InvalidInput
    [[nodiscard]] std::uint64_t nodesExplored() const;

private:
    explicit SolveReport(Outcome o);   // private; no default ctor, so no "none"

    Outcome                   m_outcome;
    std::optional<Grid>       m_grid;
    std::optional<InputFault> m_fault;
    std::uint64_t             m_nodesExplored = 0;
};

} // namespace sudoku
