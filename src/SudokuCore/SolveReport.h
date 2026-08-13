// SolveReport.h — the closed outcome set and the value a run produces.
//
// docs/SDD.md 2.4. RTVM-300: exactly one outcome per run, never none and
// never two. That is enforced by the type itself — no default constructor,
// no "Unknown" member, and construction only through the five factories.

#pragma once

#include <cstdint>
#include <optional>
#include <type_traits>

#include "Grid.h"
#include "InputFault.h"

namespace sudoku {

enum class Outcome : std::uint8_t {
    Solved, SolvedNotUnique, InvalidInput, NoSolution, Aborted
};

// RTVM-300 calls the outcome set *closed*. These pin it: inserting a member
// shifts a value and breaks the build here rather than silently renumbering an
// outcome some other translation unit already compiled against. Appending one
// is caught by the exhaustive switches in SolveReport.cpp, which carry no
// default label (MSVC C4062 at /W4, gcc/clang -Wswitch).
static_assert(static_cast<std::uint8_t>(Outcome::Solved) == 0
    && static_cast<std::uint8_t>(Outcome::SolvedNotUnique) == 1
    && static_cast<std::uint8_t>(Outcome::InvalidInput) == 2
    && static_cast<std::uint8_t>(Outcome::NoSolution) == 3
    && static_cast<std::uint8_t>(Outcome::Aborted) == 4,
    "Outcome is a closed set of exactly these five members in this order (RTVM-300)");

// The populated-field invariant of docs/SDD.md 2.4, stated once. The two
// answers are a property of the outcome alone, so a caller never has to
// discover them by probing a report. Exit codes are deliberately absent:
// RTVM-405 maps outcomes to exit codes in the console layer, and the core
// knows nothing about process exit (RTVM-903).
[[nodiscard]] bool outcomeCarriesGrid(Outcome outcome);
[[nodiscard]] bool outcomeCarriesFault(Outcome outcome);

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

    // RTVM-301: true when this report carries a grid in which every one of the
    // kCellCount cells holds a digit 1..kGridSize — no empty cell, nothing out
    // of range. Grid::isComplete() only answers the first half, and only a
    // solved outcome is required to answer both, so the check that matches the
    // requirement lives here where the outcome is known.
    //
    // The solved() and solvedNotUnique() factories are the solver's promise
    // that this holds; this is how the promise is checked rather than assumed
    // (TP-301), and how a future caller can assert it cheaply.
    [[nodiscard]] bool hasCompleteGrid() const;

private:
    explicit SolveReport(Outcome o);   // private; no default ctor, so no "none"

    Outcome                   m_outcome;
    std::optional<Grid>       m_grid;
    std::optional<InputFault> m_fault;
    std::uint64_t             m_nodesExplored = 0;
};

// RTVM-300, the "never none" half, as a property of the type rather than a
// thing a test has to catch: a SolveReport cannot be brought into existence
// without naming one of the five outcomes, because the only constructor that
// takes an Outcome is private and there is no other constructor at all. The
// "never two" half needs no assertion — m_outcome is a single scalar.
static_assert(!std::is_default_constructible_v<SolveReport>,
    "a SolveReport with no outcome must be unrepresentable (RTVM-300)");
static_assert(!std::is_constructible_v<SolveReport, Outcome>,
    "SolveReport must be reachable only through the five named factories (RTVM-300)");
static_assert(std::is_copy_constructible_v<SolveReport>
    && std::is_move_constructible_v<SolveReport>,
    "SolveReport is a value: solve() returns it and the console layer holds it");

} // namespace sudoku
