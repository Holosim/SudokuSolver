// SolveReportTests.cpp — the outcome type (RTVM-300) and the grid a solved
// outcome carries (RTVM-301).
//
// Procedures: docs/RTVM.md TP-300 (type-level half) and TP-301.
//
// TP-300 has two halves. The whole-run half — drive the application once per
// outcome class and see five distinct outcomes — needs every outcome to exist
// and is executed under RTVM-405 (#18). What is testable against the type
// alone is the half below: that "no outcome" and "two outcomes" are states the
// type cannot be put into, and that each factory produces exactly the payload
// the docs/SDD.md 2.4 invariant table says it does.
//
// TP-301 is written against the solved results of P-EASY and P-NONUNIQUE, so
// its end-to-end form needs the solver (#8, #12). The property it asserts —
// that a Solved or SolvedNotUnique report carries kCellCount digits in
// 1..kGridSize with no empty cell — belongs to this type and is asserted here
// against the S-EASY fixture, including the negative case that makes the
// assertion falsifiable.

#include "CppUnitTest.h"

#include <type_traits>

#include "Grid.h"
#include "SolveReport.h"
#include "TestFixtures.h"

using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace sudoku::test {

TEST_CLASS(SolveReportTests)
{
public:
    // RTVM-300, "never none": a report cannot exist without an outcome. This
    // is a compile-time fact — the failure mode it rules out is unwritable,
    // not merely untaken — so the assertions are static_asserts and the
    // method body exists to make the check visible in the test report.
    TEST_METHOD(rtvm300_theTypeCannotRepresentNoOutcome)
    {
        static_assert(!std::is_default_constructible_v<SolveReport>,
            "SolveReport{} must not compile: that would be a report with no outcome");
        static_assert(!std::is_constructible_v<SolveReport, Outcome>,
            "the Outcome constructor is private; the five factories are the only route");

        // "Never two" is structural in the other direction: the outcome is a
        // single scalar member, so a report holds one value by construction.
        static_assert(std::is_same_v<std::underlying_type_t<Outcome>, std::uint8_t>,
            "Outcome is a scalar with an explicit underlying type (docs/SDD.md 2.1)");

        Assert::IsTrue(SolveReport::noSolution(0).outcome() == Outcome::NoSolution,
            L"a report produced by a factory reports that factory's outcome");
    }

    // RTVM-300, the closed set: five factories, five distinct outcomes, and
    // each factory yields its own and only its own.
    TEST_METHOD(rtvm300_theFiveFactoriesProduceFiveDistinctOutcomes)
    {
        const SolveReport reports[] = {
            SolveReport::solved(gridFromCompactForm(kSolvedEasy), 1),
            SolveReport::solvedNotUnique(gridFromCompactForm(kSolvedEasy), 2),
            SolveReport::invalidInput(InputFault{}),
            SolveReport::noSolution(3),
            SolveReport::aborted(4),
        };
        const Outcome expected[] = {
            Outcome::Solved,
            Outcome::SolvedNotUnique,
            Outcome::InvalidInput,
            Outcome::NoSolution,
            Outcome::Aborted,
        };
        constexpr int outcomeCount = static_cast<int>(std::extent_v<decltype(expected)>);

        for (int i = 0; i < outcomeCount; ++i) {
            Assert::IsTrue(reports[i].outcome() == expected[i],
                L"each factory must produce exactly its own outcome");
            for (int j = i + 1; j < outcomeCount; ++j) {
                Assert::IsTrue(reports[i].outcome() != reports[j].outcome(),
                    L"the five outcomes must be distinct from one another");
            }
        }
    }

    // RTVM-300 / docs/SDD.md 2.4: which fields an outcome carries is a
    // property of the outcome, and the report must agree with the table.
    TEST_METHOD(rtvm300_reportPayloadMatchesTheOutcomeInvariantTable)
    {
        const SolveReport reports[] = {
            SolveReport::solved(gridFromCompactForm(kSolvedEasy), 0),
            SolveReport::solvedNotUnique(gridFromCompactForm(kSolvedEasy), 0),
            SolveReport::invalidInput(InputFault{}),
            SolveReport::noSolution(0),
            SolveReport::aborted(0),
        };

        for (const SolveReport& report : reports) {
            Assert::IsTrue(report.hasGrid() == outcomeCarriesGrid(report.outcome()),
                L"a grid is present exactly when the outcome says it is");
            Assert::IsTrue(report.hasFault() == outcomeCarriesFault(report.outcome()),
                L"a fault is present exactly when the outcome says it is");
            Assert::IsFalse(report.hasGrid() && report.hasFault(),
                L"no outcome carries both a grid and a fault");
        }
    }

    // RTVM-505 supporting check: asking a report for a payload its outcome
    // does not carry is a caller error, but it must not be undefined
    // behaviour. The documented preconditions stay documented; they are not
    // enforced by a crash.
    TEST_METHOD(rtvm300_accessorsAreSafeOnAnOutcomeThatCarriesNoPayload)
    {
        const SolveReport report = SolveReport::aborted(0);

        Assert::IsFalse(report.hasGrid());
        Assert::IsFalse(report.hasFault());
        Assert::IsFalse(report.grid().isComplete(),
            L"the stand-in grid is empty rather than garbage");
        Assert::IsFalse(report.hasCompleteGrid());
        Assert::IsTrue(report.fault().kind == FaultKind::MissingLine,
            L"the stand-in fault is a default-constructed value");
    }

    // RTVM-301: the Solved outcome carries a complete grid of digits
    // 1..kGridSize.
    TEST_METHOD(rtvm301_solvedCarriesACompleteGridOfDigits)
    {
        const SolveReport report =
            SolveReport::solved(gridFromCompactForm(kSolvedEasy), 42);

        Assert::IsTrue(report.hasGrid(), L"Solved carries a grid");
        Assert::IsTrue(report.grid().isComplete(), L"no cell is empty");
        Assert::IsTrue(report.hasCompleteGrid(),
            L"every cell holds a digit in 1..kGridSize");

        int cellsInspected = 0;
        for (int row = 0; row < kGridSize; ++row) {
            for (int col = 0; col < kGridSize; ++col) {
                const int digit = static_cast<int>(report.grid().at(row, col));
                Assert::IsTrue(digit >= 1 && digit <= kGridSize,
                    L"every cell of a solved grid is a digit 1..kGridSize");
                ++cellsInspected;
            }
        }
        Assert::AreEqual(kCellCount, cellsInspected, L"all cells were inspected");
        Assert::IsTrue(report.nodesExplored() == 42ULL,
            L"the search-step count survives the factory (RTVM-204)");
    }

    // RTVM-301 applies to both grid-carrying outcomes, not just Solved.
    TEST_METHOD(rtvm301_solvedNotUniqueCarriesACompleteGridOfDigits)
    {
        const SolveReport report =
            SolveReport::solvedNotUnique(gridFromCompactForm(kSolvedEasy), 7);

        Assert::IsTrue(report.outcome() == Outcome::SolvedNotUnique);
        Assert::IsTrue(report.hasCompleteGrid(),
            L"the first solution found is still a complete grid");
    }

    // The falsifiable half of TP-301: a grid that is not a complete solution
    // must not be reported as one, or the assertion above proves nothing.
    TEST_METHOD(rtvm301_anIncompleteOrOutOfRangeGridIsNotACompleteGrid)
    {
        Grid withAnEmptyCell = gridFromCompactForm(kSolvedEasy);
        withAnEmptyCell.set(4, 4, kEmpty);
        Assert::IsFalse(SolveReport::solved(withAnEmptyCell, 0).hasCompleteGrid(),
            L"one empty cell is enough to fail RTVM-301");

        Grid withABadDigit = gridFromCompactForm(kSolvedEasy);
        withABadDigit.set(0, 0, static_cast<Digit>(kGridSize + 1));
        Assert::IsFalse(SolveReport::solved(withABadDigit, 0).hasCompleteGrid(),
            L"a digit outside 1..kGridSize is not a digit");

        Assert::IsFalse(SolveReport::solved(gridFromCompactForm(kPuzzleEasy), 0)
                .hasCompleteGrid(),
            L"an unsolved puzzle grid is not a complete grid");
    }
};

} // namespace sudoku::test
