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
// RTVM-201 (no solution, TP-201) and RTVM-202 (non-uniqueness, TP-202) both
// run on the same search, and are both verified below (#11 and #12
// respectively).

#include "CppUnitTest.h"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

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

// RTVM-507 (docs/SDD.md 3.6): a control that records every
// progress.nodesExplored it is given and never requests an abort. Used to
// observe the poll cadence and the node counter across the diagnostic hook's
// extension passes without depending on wall-clock sampling.
class RecordingSolveControl final : public SolveControl
{
public:
    bool onPoll(const SolveProgress& progress) override
    {
        m_samples.push_back(progress.nodesExplored);
        return true;
    }

    [[nodiscard]] const std::vector<std::uint64_t>& samples() const { return m_samples; }

private:
    std::vector<std::uint64_t> m_samples;
};

// A control that answers "continue" for the first `pollsBeforeAbort` calls
// and "abort" on every call after that -- the RTVM-203 shape: an abort
// requested partway through a run, not on the very first poll.
class AbortAfterNPollsControl final : public SolveControl
{
public:
    explicit AbortAfterNPollsControl(int pollsBeforeAbort)
        : m_pollsBeforeAbort(pollsBeforeAbort)
    {
    }

    bool onPoll(const SolveProgress&) override
    {
        ++m_pollCount;
        return m_pollCount <= m_pollsBeforeAbort;
    }

private:
    int m_pollsBeforeAbort;
    int m_pollCount = 0;
};

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

    // TP-200, third case (docs/RTVM.md 9.7, added 2026-08-13): P-SEARCH is dug
    // from S-EASY, so its expected solution is S-EASY itself, but unlike
    // P-EASY and P-HARD17 it is not solvable by naked and hidden singles
    // alone — both of those solve at nodesExplored() == 1, leaving the
    // docs/SDD.md 1.5 MRV branch/backtrack path un-exercised by TP-200's
    // original two cases. This case forces that path to run.
    TEST_METHOD(rtvm200_solvesPSearchToSEasyViaBranchAndBacktrack)
    {
        assertSolvesTo(kPuzzleSearch, kSolvedEasy, L"P-SEARCH must solve to S-EASY");

        // Asserted as an inequality, not a pinned node count: the count is an
        // implementation property, and pinning it would fail on any
        // legitimate propagation improvement. > 1 is what distinguishes a
        // search that branched from one that finished on deduction alone.
        NullSolveControl control;
        const SolveReport report =
            solve(gridFromCompactForm(kPuzzleSearch), SolveOptions{}, control);
        Assert::IsTrue(report.nodesExplored() > 1ULL,
            L"P-SEARCH is not solvable by singles alone; a search that "
            L"branched must explore more than the one deduced node");
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

    // TP-201: P-UNSOLVABLE is P-EASY with r1c3 forced to 1 — its givens are
    // mutually consistent (no row/column/box duplicate), so nothing before the
    // solver can reject it; the search itself must discover it has no
    // completion. Expect NoSolution, no grid, and no fault (RTVM-201).
    TEST_METHOD(rtvm201_puzzleWithNoCompletionReportsNoSolution)
    {
        NullSolveControl control;
        const SolveReport report =
            solve(gridFromCompactForm(kPuzzleUnsolvable), SolveOptions{}, control);

        Assert::IsTrue(report.outcome() == Outcome::NoSolution,
            L"a puzzle with mutually consistent but unsatisfiable givens must "
            L"report NoSolution, not a fault and not a partial grid");
        Assert::IsFalse(report.hasGrid(),
            L"NoSolution must not carry a grid (RTVM-201: no partial grid)");
        Assert::IsFalse(report.hasFault(),
            L"NoSolution is not InvalidInput; RTVM-104 does not apply here");
    }

    // P-UNSOLVABLE's r1c3 = 1 given creates no row/column/box duplicate by
    // itself (docs/RTVM.md 6.1) — S-EASY's r1c3 is 4, so forcing 1 there is
    // unsatisfiable only once propagation and search chase the implications
    // out. Solving the unmodified P-EASY still succeeds, which is what keeps
    // rtvm201 falsifiable rather than trivially true for any input.
    TEST_METHOD(rtvm201_theSameSearchStillSolvesTheUnmodifiedPuzzle)
    {
        NullSolveControl control;
        const SolveReport report =
            solve(gridFromCompactForm(kPuzzleEasy), SolveOptions{}, control);

        Assert::IsTrue(report.outcome() == Outcome::Solved,
            L"P-EASY, unmodified, must still solve — proves the NoSolution "
            L"result above comes from the r1c3 mutation, not a broken search");
    }

    // TP-202, non-uniqueness: P-NONUNIQUE solves to SolvedNotUnique, and the
    // printed grid is exactly S-NONUNIQUE-A or S-NONUNIQUE-B — deliberately
    // not pinned to one, since docs/RTVM.md TP-202 says which one depends on
    // search order and must not be asserted.
    TEST_METHOD(rtvm202_solvesPNonUniqueToOneOfItsTwoKnownSolutions)
    {
        const Grid        puzzle = gridFromCompactForm(kPuzzleNonUnique);
        NullSolveControl  control;
        const SolveReport report = solve(puzzle, SolveOptions{}, control);

        Assert::IsTrue(report.outcome() == Outcome::SolvedNotUnique,
            L"P-NONUNIQUE has exactly two solutions and must report SolvedNotUnique");
        Assert::IsTrue(report.hasCompleteGrid(),
            L"the first solution found is still a complete grid (RTVM-301)");

        const std::string found = toCompactString(report.grid());
        const bool matchesA = found == std::string(kSolvedNonUniqueA);
        const bool matchesB = found == std::string(kSolvedNonUniqueB);
        Assert::IsTrue(matchesA || matchesB,
            L"the reported grid must be exactly S-NONUNIQUE-A or S-NONUNIQUE-B");
        Assert::IsTrue(isWellFormedSolution(report.grid()),
            L"every row, column and box must still be a permutation of 1..kGridSize");
        Assert::IsTrue(preservesGivens(puzzle, report.grid()),
            L"every given must appear unchanged at the same position");
    }

    // TP-202's control case: a uniquely-solvable puzzle must report Solved,
    // never SolvedNotUnique. rtvm200_solvesPEasyToItsUniqueSolution already
    // pins the Solved outcome for P-EASY; this restates it under RTVM-202's
    // own name so the control case has a home that survives even if that
    // test's assertions ever narrow.
    TEST_METHOD(rtvm202_controlCasePEasyStaysUnique)
    {
        NullSolveControl  control;
        const SolveReport report =
            solve(gridFromCompactForm(kPuzzleEasy), SolveOptions{}, control);

        Assert::IsTrue(report.outcome() == Outcome::Solved,
            L"a uniquely-solvable puzzle must report Solved, not SolvedNotUnique");
    }

    // TP-202's instrumentation clause ("assert ... the solver stopped after
    // finding the second solution and did not continue searching"), on the
    // fixture where it is actually falsifiable.
    //
    // P-NONUNIQUE cannot show this: after propagation it has exactly one
    // branch cell with exactly two viable candidates, so the whole search
    // tree is exhausted at 3 nodes (root + 2 children) whether maxSolutions
    // is 2 or 1'000'000 — verified by hand against this solver. There is
    // nothing left to explore either way, so a node-count comparison on
    // P-NONUNIQUE cannot distinguish "stopped because two were found" from
    // "kept going and found nothing more because there was nothing more".
    //
    // P-BLANK — the same fixture this issue's design notes call out — has an
    // enormous branching factor, so raising the solution budget by one
    // measurably grows the search: proof that maxSolutions genuinely bounds
    // the work rather than the tree happening to run out on its own.
    //
    // TP-202's wording ties the instrumentation clause to P-NONUNIQUE
    // specifically; using P-BLANK instead is flagged in the issue #12
    // hand-off rather than assumed silently.
    TEST_METHOD(rtvm202_stoppingAtTwoSolutionsBoundsTheSearch)
    {
        NullSolveControl control;
        const Grid        blank = gridFromCompactForm(kPuzzleBlank);

        SolveOptions stopAtTwo;
        stopAtTwo.maxSolutions = 2;
        const SolveReport twoSolutions = solve(blank, stopAtTwo, control);

        SolveOptions stopAtThree;
        stopAtThree.maxSolutions = 3;
        const SolveReport threeSolutions = solve(blank, stopAtThree, control);

        Assert::IsTrue(twoSolutions.outcome() == Outcome::SolvedNotUnique);
        Assert::IsTrue(threeSolutions.outcome() == Outcome::SolvedNotUnique,
            L"P-BLANK has far more than three solutions");
        Assert::IsTrue(twoSolutions.nodesExplored() < threeSolutions.nodesExplored(),
            L"a search capped at two solutions must explore strictly fewer nodes "
            L"than the same search capped at three, or the cap is not actually "
            L"stopping anything");
    }

    // RTVM-507 / docs/SDD.md 3.6, "inert cost" row: minSolveDuration == 0
    // (SolveOptions' default) must add no measurable delay. This alone cannot
    // tell a correct gate from a solver that never honours minSolveDuration at
    // all -- rtvm507_activatingTheHookExtendsWallClockTimeWithoutChangingTheOutcome
    // below is what actually exercises the branch that does.
    TEST_METHOD(rtvm507_hookIsInertWhenMinSolveDurationIsZero)
    {
        NullSolveControl control;
        const SolveOptions options{};
        Assert::AreEqual(0LL, static_cast<long long>(options.minSolveDuration.count()),
            L"SolveOptions::minSolveDuration defaults to zero");

        const auto before = std::chrono::steady_clock::now();
        const SolveReport report =
            solve(gridFromCompactForm(kPuzzleHard17), options, control);
        const auto elapsed = std::chrono::steady_clock::now() - before;

        Assert::IsTrue(report.outcome() == Outcome::Solved);
        Assert::IsTrue(elapsed < std::chrono::milliseconds(500),
            L"an inert hook must not add any measurable wall-clock delay");
    }

    // RTVM-507's central behaviour: with the hook active, solve() keeps
    // performing search work until at least minSolveDuration has elapsed,
    // then returns the outcome it already had, unchanged (docs/SDD.md 3.6).
    TEST_METHOD(rtvm507_activatingTheHookExtendsWallClockTimeWithoutChangingTheOutcome)
    {
        NullSolveControl control;
        SolveOptions options{};
        options.minSolveDuration = std::chrono::milliseconds(50);

        const Grid puzzle = gridFromCompactForm(kPuzzleHard17);
        const auto before = std::chrono::steady_clock::now();
        const SolveReport report = solve(puzzle, options, control);
        const auto elapsed = std::chrono::steady_clock::now() - before;

        Assert::IsTrue(elapsed >= options.minSolveDuration,
            L"the hook must keep the solve running for at least minSolveDuration");
        Assert::IsTrue(report.outcome() == Outcome::Solved);
        Assert::AreEqual(std::string(kSolvedHard17), toCompactString(report.grid()),
            L"the extension must return the same answer an unextended solve would");
    }

    // RTVM-507's "not a sleep" requirement (docs/SDD.md 3.6): the extension
    // must keep polling `control` and keep advancing the reported node count,
    // not idle. Falsifiable: a `std::this_thread::sleep_for` in place of real
    // search work would call onPoll at most once (from the original search),
    // and the samples below would not keep growing past that.
    TEST_METHOD(rtvm507_hookKeepsPollingAndAdvancingTheNodeCounterDuringExtension)
    {
        RecordingSolveControl control;
        SolveOptions options{};
        options.pollNodeInterval = 1;                          // poll every node
        options.minSolveDuration = std::chrono::milliseconds(100);

        const SolveReport report =
            solve(gridFromCompactForm(kPuzzleHard17), options, control);
        static_cast<void>(report);

        const std::vector<std::uint64_t>& samples = control.samples();
        Assert::IsTrue(samples.size() > 10,
            L"a 100 ms extension polling every node must produce many samples, "
            L"far more than the single node a real (unextended) search on "
            L"P-HARD17 explores");
        Assert::IsTrue(std::is_sorted(samples.begin(), samples.end()),
            L"RTVM-204: the node counter must never go backwards, including "
            L"across RTVM-507 extension pass boundaries");
        Assert::IsTrue(samples.front() > 0ULL,
            L"the first sample must already be positive");
        Assert::IsTrue(samples.back() > samples.front(),
            L"the counter must keep advancing over the course of the extension");
    }

    // RTVM-203 outranks RTVM-507: an abort requested while the diagnostic
    // extension is running must still be honoured promptly, not deferred
    // until minSolveDuration elapses.
    TEST_METHOD(rtvm507_anAbortDuringTheExtensionStopsTheSolveRatherThanRunningToDuration)
    {
        AbortAfterNPollsControl control(/*pollsBeforeAbort=*/5);
        SolveOptions options{};
        options.pollNodeInterval = 1;
        options.minSolveDuration = std::chrono::seconds(5);

        const auto before = std::chrono::steady_clock::now();
        const SolveReport report =
            solve(gridFromCompactForm(kPuzzleHard17), options, control);
        const auto elapsed = std::chrono::steady_clock::now() - before;

        Assert::IsTrue(report.outcome() == Outcome::Aborted,
            L"an abort requested during the extension must win over the hook");
        Assert::IsTrue(elapsed < std::chrono::seconds(1),
            L"RTVM-203: abort latency stays under 1.0 s even with "
            L"minSolveDuration set far beyond it");
    }
};

} // namespace sudoku::test
