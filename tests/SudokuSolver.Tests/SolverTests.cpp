// SolverTests.cpp — the core solver on a uniquely-solvable puzzle (RTVM-200).
//
// Procedure: docs/RTVM.md TP-200. Solve P-EASY and P-HARD17; expect exactly
// S-EASY and S-HARD17. For each result assert programmatically that all
// kCellCount cells hold digits 1..kGridSize, that every row, column and box is
// a permutation of 1..kGridSize, and that every given appears unchanged at the
// same position. TP-200 says "unit test against SudokuCore directly — no
// process needed at this stage", so these call solve() and nothing else.
//
// The structural assertions are deliberately not "compare against the expected
// string" alone: the string comparison proves the solver found *the* solution,
// the structural pass proves it found *a* solution, and TP-200 asks for both.
// rtvm200_theSolutionCheckerRejectsAGridThatIsNotASolution is what keeps the
// structural pass falsifiable.
//
// RTVM-201 (no solution) and RTVM-202 (non-uniqueness) run on the same search
// but are verified under #11 and #12; nothing here asserts them.

#include "CppUnitTest.h"

#include <string>
#include <string_view>

#include "Grid.h"
#include "GridFormat.h"
#include "SolveControl.h"
#include "SolveReport.h"
#include "Solver.h"
#include "TestFixtures.h"

using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace sudoku::test {

namespace {

// True when every cell holds a digit 1..kGridSize and every row, column and
// box is a permutation of 1..kGridSize — that is, no digit repeats in any
// unit. This is the whole of RTVM-200's "correct grid" property, stated once.
[[nodiscard]] bool isWellFormedSolution(const Grid& grid)
{
    for (int row = 0; row < kGridSize; ++row) {
        for (int col = 0; col < kGridSize; ++col) {
            const int digit = static_cast<int>(grid.at(row, col));
            if (digit < 1 || digit > kGridSize) {
                return false;
            }
        }
    }

    // A unit is a permutation of 1..kGridSize exactly when its kGridSize cells
    // hold kGridSize distinct in-range digits; range is already established, so
    // a seen-mask per unit settles it.
    for (int unit = 0; unit < kGridSize; ++unit) {
        unsigned rowSeen = 0;
        unsigned colSeen = 0;
        unsigned boxSeen = 0;
        for (int slot = 0; slot < kGridSize; ++slot) {
            const int boxRow = (unit / kBoxSize) * kBoxSize + slot / kBoxSize;
            const int boxCol = (unit % kBoxSize) * kBoxSize + slot % kBoxSize;
            rowSeen |= 1u << grid.at(unit, slot);
            colSeen |= 1u << grid.at(slot, unit);
            boxSeen |= 1u << grid.at(boxRow, boxCol);
        }
        const unsigned complete = ((1u << (kGridSize + 1)) - 1u) & ~1u;  // bits 1..kGridSize
        if (rowSeen != complete || colSeen != complete || boxSeen != complete) {
            return false;
        }
    }
    return true;
}

// True when every given of `puzzle` appears unchanged at the same position in
// `solution`. Empty cells of the puzzle are unconstrained here.
[[nodiscard]] bool preservesGivens(const Grid& puzzle, const Grid& solution)
{
    for (int row = 0; row < kGridSize; ++row) {
        for (int col = 0; col < kGridSize; ++col) {
            const Digit given = puzzle.at(row, col);
            if (given != kEmpty && solution.at(row, col) != given) {
                return false;
            }
        }
    }
    return true;
}

// Runs one TP-200 case end to end against the core: solve, then assert the
// outcome, the exact expected grid, and the three structural properties.
void assertSolvesTo(std::string_view puzzleText, std::string_view expectedText,
                    const wchar_t* label)
{
    const Grid       puzzle = gridFromCompactForm(puzzleText);
    NullSolveControl control;
    const SolveReport report = solve(puzzle, SolveOptions{}, control);

    Assert::IsTrue(report.outcome() == Outcome::Solved, label);
    Assert::IsTrue(report.hasGrid(), label);
    Assert::IsTrue(report.hasCompleteGrid(),
        L"a solved report carries kCellCount digits in 1..kGridSize (RTVM-301)");
    Assert::AreEqual(std::string(expectedText), toCompactString(report.grid()), label);
    Assert::IsTrue(isWellFormedSolution(report.grid()),
        L"every row, column and box must be a permutation of 1..kGridSize");
    Assert::IsTrue(preservesGivens(puzzle, report.grid()),
        L"every given must appear unchanged at the same position");
}

} // namespace

TEST_CLASS(SolverTests)
{
public:
    // TP-200, first half: P-EASY solves to exactly S-EASY.
    TEST_METHOD(rtvm200_solvesPEasyToItsUniqueSolution)
    {
        assertSolvesTo(kPuzzleEasy, kSolvedEasy, L"P-EASY must solve to S-EASY");
    }

    // TP-200, second half: P-HARD17, 17 givens, solves to exactly S-HARD17.
    // This is the case that would expose a broken MRV ordering — it is the
    // RTVM-500 performance reference — but the timing requirement itself is
    // verified under its own issue, not here.
    TEST_METHOD(rtvm200_solvesPHard17ToItsUniqueSolution)
    {
        assertSolvesTo(kPuzzleHard17, kSolvedHard17, L"P-HARD17 must solve to S-HARD17");
    }

    // The given-preservation half of TP-200 stated the other way round: the
    // solution of a puzzle must agree with the puzzle everywhere the puzzle
    // has a digit, and the check must be able to notice when it does not.
    TEST_METHOD(rtvm200_theGivenPreservationCheckIsFalsifiable)
    {
        const Grid puzzle   = gridFromCompactForm(kPuzzleEasy);
        Grid       solution = gridFromCompactForm(kSolvedEasy);
        Assert::IsTrue(preservesGivens(puzzle, solution));

        // r1c1 is the given `5` in P-EASY; moving it must be detected.
        solution.set(0, 0, static_cast<Digit>(kGridSize));
        Assert::IsFalse(preservesGivens(puzzle, solution),
            L"a moved given must fail the check, or the check proves nothing");
    }

    // Falsifiability of the structural check: a grid that repeats a digit in a
    // unit, or leaves a cell empty, must not pass as a solution.
    TEST_METHOD(rtvm200_theSolutionCheckerRejectsAGridThatIsNotASolution)
    {
        Assert::IsTrue(isWellFormedSolution(gridFromCompactForm(kSolvedEasy)),
            L"the reference solution is well formed");

        Grid withAnEmptyCell = gridFromCompactForm(kSolvedEasy);
        withAnEmptyCell.set(4, 4, kEmpty);
        Assert::IsFalse(isWellFormedSolution(withAnEmptyCell));

        // S-EASY r1c1 is 5 and r1c2 is 3; copying one over the other puts two
        // 5s in row 1, in column 2 and in the top-left box at once.
        Grid withADuplicate = gridFromCompactForm(kSolvedEasy);
        withADuplicate.set(0, 1, withADuplicate.at(0, 0));
        Assert::IsFalse(isWellFormedSolution(withADuplicate));

        Assert::IsFalse(isWellFormedSolution(gridFromCompactForm(kPuzzleEasy)),
            L"an unsolved puzzle is not a solution");
    }

    // Not RTVM-204's verification (#16 owns that): this only establishes that
    // the reported grid came out of a search that actually ran, so a future
    // change that short-circuits to a hard-coded answer fails here.
    TEST_METHOD(rtvm200_theReportedSolutionComesFromASearchThatRan)
    {
        NullSolveControl control;
        const SolveReport report =
            solve(gridFromCompactForm(kPuzzleHard17), SolveOptions{}, control);

        Assert::IsTrue(report.outcome() == Outcome::Solved);
        Assert::IsTrue(report.nodesExplored() > 0ULL,
            L"solving a 17-given puzzle explores at least one search node");
    }
};

} // namespace sudoku::test
