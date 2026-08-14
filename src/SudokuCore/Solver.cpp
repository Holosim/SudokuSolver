// Solver.cpp — see Solver.h.
//
// Implements docs/SDD.md 1.5: bitmask constraint propagation (naked and
// hidden singles) to fixpoint, then depth-first search ordered by minimum
// remaining values, candidates tried in ascending digit order, undo by
// restoring a saved copy of the node state.
//
// RTVM-200 is the requirement this file was written for. The same search
// answers RTVM-201 (no completion exists) and RTVM-202 (a second solution
// exists) because those are the zero- and two-solution exits of one loop;
// their test procedures land under their own issues (#11, #12).
//
// Nothing here names a stream, the command line, or the environment
// (RTVM-903): the poll callback and every option value arrive as arguments.

#include "Solver.h"

#include <algorithm>
#include <array>
#include <cstddef>
#include <utility>

namespace sudoku {

namespace {

// All kGridSize digits set. Bit 0 is digit 1, per Grid.h's CandidateMask.
inline constexpr CandidateMask kAllDigits =
    static_cast<CandidateMask>((1u << kGridSize) - 1u);

[[nodiscard]] constexpr CandidateMask bitFor(Digit digit)
{
    return static_cast<CandidateMask>(1u << (digit - 1));
}

[[nodiscard]] constexpr int cellIndex(int row, int col)
{
    return row * kGridSize + col;
}

[[nodiscard]] constexpr int boxIndex(int row, int col)
{
    return (row / kBoxSize) * kBoxSize + (col / kBoxSize);
}

// Number of set bits. std::popcount is C++20 and this project is C++17
// (docs/SDD.md 2.1), and the intrinsic route (__popcnt) would be a
// compiler-specific dependency for a 9-bit value; Kernighan's loop runs at
// most kGridSize times and is the version that reads as what it is.
[[nodiscard]] constexpr int popCount(CandidateMask mask)
{
    int count = 0;
    while (mask != 0) {
        mask = static_cast<CandidateMask>(mask & (mask - 1));
        ++count;
    }
    return count;
}

// Lowest set bit's digit, 1-based. Precondition: mask != 0.
[[nodiscard]] constexpr Digit lowestDigit(CandidateMask mask)
{
    Digit digit = 1;
    while ((mask & 1u) == 0u) {
        mask = static_cast<CandidateMask>(mask >> 1);
        ++digit;
    }
    return digit;
}

// One search node's complete state, per docs/SDD.md 1.5. Copying this is the
// undo mechanism: no journal, no incremental rollback, no way for an undo to
// disagree with the forward step. It is a trivially copyable aggregate of
// roughly 300 bytes at a maximum depth of kCellCount, which is a rounding
// error against the RTVM-500 budget and buys ST-2 / D-4 readability.
//
// 1.5 lists candidates, the three used-masks and unsolvedCount; `cells` is
// added because the report has to carry the digits that were assigned, and
// deriving them from a single-bit candidate mask would conflate "assigned" with
// "one candidate left but not yet propagated".
struct SearchState {
    std::array<CandidateMask, kCellCount> candidates{};
    std::array<Digit, kCellCount>         cells{};
    std::array<CandidateMask, kGridSize>  rowUsed{};
    std::array<CandidateMask, kGridSize>  colUsed{};
    std::array<CandidateMask, kGridSize>  boxUsed{};
    int                                   unsolvedCount = kCellCount;
};

[[nodiscard]] SearchState makeEmptyState()
{
    SearchState state;
    state.candidates.fill(kAllDigits);
    state.cells.fill(kEmpty);
    return state;
}

// Places `digit` in the given cell and removes it from the candidates of every
// peer. Returns false on a contradiction — the digit is not a candidate here,
// or the placement empties some peer's candidate set. A false return leaves
// `state` unusable, which is safe because every caller abandons the copy.
[[nodiscard]] bool assign(SearchState& state, int row, int col, Digit digit)
{
    const int           index = cellIndex(row, col);
    const int           box   = boxIndex(row, col);
    const CandidateMask bit   = bitFor(digit);

    if ((state.candidates[static_cast<std::size_t>(index)] & bit) == 0u) {
        return false;
    }

    state.cells[static_cast<std::size_t>(index)]      = digit;
    state.candidates[static_cast<std::size_t>(index)] = 0u;
    state.rowUsed[static_cast<std::size_t>(row)] =
        static_cast<CandidateMask>(state.rowUsed[static_cast<std::size_t>(row)] | bit);
    state.colUsed[static_cast<std::size_t>(col)] =
        static_cast<CandidateMask>(state.colUsed[static_cast<std::size_t>(col)] | bit);
    state.boxUsed[static_cast<std::size_t>(box)] =
        static_cast<CandidateMask>(state.boxUsed[static_cast<std::size_t>(box)] | bit);
    --state.unsolvedCount;

    // Eliminate from the three units this cell belongs to. A cell left with no
    // candidate and no digit is an immediate contradiction (docs/SDD.md 1.5).
    for (int other = 0; other < kGridSize; ++other) {
        const int peers[] = {
            cellIndex(row, other),
            cellIndex(other, col),
            cellIndex((row / kBoxSize) * kBoxSize + other / kBoxSize,
                      (col / kBoxSize) * kBoxSize + other % kBoxSize),
        };
        for (const int peer : peers) {
            if (peer == index) {
                continue;
            }
            CandidateMask& peerMask = state.candidates[static_cast<std::size_t>(peer)];
            peerMask = static_cast<CandidateMask>(peerMask & ~bit);
            if (peerMask == 0u && state.cells[static_cast<std::size_t>(peer)] == kEmpty) {
                return false;
            }
        }
    }
    return true;
}

// Applies naked singles and hidden singles until neither fires. Returns false
// when the branch is contradictory. docs/SDD.md 1.5, rules 1-3.
[[nodiscard]] bool propagate(SearchState& state)
{
    bool changed = true;
    while (changed && state.unsolvedCount > 0) {
        changed = false;

        // Rule 1 — naked single: exactly one candidate left in a cell.
        for (int row = 0; row < kGridSize; ++row) {
            for (int col = 0; col < kGridSize; ++col) {
                const std::size_t index = static_cast<std::size_t>(cellIndex(row, col));
                if (state.cells[index] != kEmpty) {
                    continue;
                }
                const CandidateMask mask = state.candidates[index];
                if (mask == 0u) {
                    return false;                                   // rule 3
                }
                if (popCount(mask) == 1) {
                    if (!assign(state, row, col, lowestDigit(mask))) {
                        return false;
                    }
                    changed = true;
                }
            }
        }

        // Rule 2 — hidden single: a digit with exactly one legal placement in
        // a row, column or box. The three unit kinds share one loop body; a
        // unit is addressed by (kind, unit, slot) so the rule is written once.
        for (int kind = 0; kind < 3 && !changed; ++kind) {
            for (int unit = 0; unit < kGridSize && !changed; ++unit) {
                for (Digit digit = 1; digit <= kGridSize; ++digit) {
                    const CandidateMask bit = bitFor(digit);
                    int placements = 0;
                    int foundRow   = 0;
                    int foundCol   = 0;
                    bool alreadyPlaced = false;

                    for (int slot = 0; slot < kGridSize; ++slot) {
                        int row = 0;
                        int col = 0;
                        if (kind == 0) {            // row unit
                            row = unit;
                            col = slot;
                        } else if (kind == 1) {     // column unit
                            row = slot;
                            col = unit;
                        } else {                    // box unit
                            row = (unit / kBoxSize) * kBoxSize + slot / kBoxSize;
                            col = (unit % kBoxSize) * kBoxSize + slot % kBoxSize;
                        }
                        const std::size_t index =
                            static_cast<std::size_t>(cellIndex(row, col));
                        if (state.cells[index] == digit) {
                            alreadyPlaced = true;
                            break;
                        }
                        if (state.cells[index] == kEmpty
                            && (state.candidates[index] & bit) != 0u) {
                            ++placements;
                            foundRow = row;
                            foundCol = col;
                        }
                    }

                    if (alreadyPlaced) {
                        continue;
                    }
                    if (placements == 0) {
                        return false;               // nowhere left for this digit
                    }
                    if (placements == 1) {
                        if (!assign(state, foundRow, foundCol, digit)) {
                            return false;
                        }
                        changed = true;
                        break;   // masks moved; restart the sweep from rule 1
                    }
                }
            }
        }
    }
    return true;
}

// The unassigned cell with the fewest candidates (MRV). Ties go to the lowest
// cell index, which — with ascending digit order at the branch — is what makes
// "the first solution found" reproducible run to run (docs/SDD.md 1.5,
// RTVM-202, RTVM-401). Precondition: state.unsolvedCount > 0.
struct BranchCell {
    int row = 0;
    int col = 0;
};

[[nodiscard]] BranchCell selectBranchCell(const SearchState& state)
{
    BranchCell best;
    int bestCount = kGridSize + 1;
    for (int row = 0; row < kGridSize; ++row) {
        for (int col = 0; col < kGridSize; ++col) {
            const std::size_t index = static_cast<std::size_t>(cellIndex(row, col));
            if (state.cells[index] != kEmpty) {
                continue;
            }
            const int count = popCount(state.candidates[index]);
            if (count < bestCount) {
                bestCount = count;
                best      = BranchCell{row, col};
                if (bestCount == 2) {
                    return best;   // nothing branchier can beat two after propagation
                }
            }
        }
    }
    return best;
}

// Seeds `state` with every given of `puzzle`. Returns false on a
// contradiction -- an out-of-range given, or one that empties a peer's
// candidate set on assignment -- leaving `state` unusable, the same contract
// as assign() itself. Shared by the real search and by every pass of the
// RTVM-507 diagnostic extension below, so both seed identically.
[[nodiscard]] bool seedGivens(const Grid& puzzle, SearchState& state)
{
    for (int row = 0; row < kGridSize; ++row) {
        for (int col = 0; col < kGridSize; ++col) {
            const Digit given = puzzle.at(row, col);
            if (given == kEmpty) {
                continue;
            }
            if (given > kGridSize || !assign(state, row, col, given)) {
                return false;
            }
        }
    }
    return true;
}

[[nodiscard]] Grid toGrid(const SearchState& state)
{
    Grid grid;
    for (int row = 0; row < kGridSize; ++row) {
        for (int col = 0; col < kGridSize; ++col) {
            grid.set(row, col, state.cells[static_cast<std::size_t>(cellIndex(row, col))]);
        }
    }
    return grid;
}

// The search itself. Holds the run-scoped counters so the recursive step
// carries only the node state, and so nodesExplored is a single plain
// std::uint64_t — there is one thread (docs/SDD.md 1.2), so no atomics.
class Search {
public:
    Search(const SolveOptions& options, SolveControl& control)
        : m_maxSolutions(std::max(1, options.maxSolutions))
        , m_pollNodeInterval(options.pollNodeInterval)
        , m_control(control)
        , m_nodesUntilPoll(options.pollNodeInterval)
    {
    }

    // Explores one node. Returns false when the caller must unwind without
    // trying further candidates — either the solution budget is met or an
    // abort was requested.
    bool explore(SearchState state, int depth)
    {
        ++m_nodesExplored;
        if (!poll(depth)) {
            return false;
        }

        if (!propagate(state)) {
            return true;                    // dead branch; keep searching elsewhere
        }
        if (state.unsolvedCount == 0) {
            return recordSolution(state);
        }

        const BranchCell branch = selectBranchCell(state);
        const CandidateMask mask =
            state.candidates[static_cast<std::size_t>(cellIndex(branch.row, branch.col))];

        // Ascending digit order is normative (docs/SDD.md 1.5).
        for (Digit digit = 1; digit <= kGridSize; ++digit) {
            if ((mask & bitFor(digit)) == 0u) {
                continue;
            }
            // Undo is the copy: the child mutates its own state and this one
            // is untouched when it returns.
            SearchState child = state;
            if (!assign(child, branch.row, branch.col, digit)) {
                continue;                   // contradiction before any recursion
            }
            if (!explore(std::move(child), depth + 1)) {
                return false;
            }
        }
        return true;
    }

    [[nodiscard]] SolveReport report() const
    {
        if (m_aborted) {
            return SolveReport::aborted(m_nodesExplored);
        }
        if (m_solutionsFound == 0) {
            return SolveReport::noSolution(m_nodesExplored);       // RTVM-201
        }
        if (m_solutionsFound == 1) {
            return SolveReport::solved(m_firstSolution, m_nodesExplored);   // RTVM-200
        }
        // The first solution found is the one reported (RTVM-202, 7 I-8).
        return SolveReport::solvedNotUnique(m_firstSolution, m_nodesExplored);
    }

    [[nodiscard]] std::uint64_t nodesExplored() const { return m_nodesExplored; }

    // Resets this pass's solution bookkeeping so a fresh explore() call can
    // find its own first and (up to) second solution, while leaving the node
    // counter, poll countdown and abort flag untouched. Used only by the
    // RTVM-507 diagnostic extension in solve(): each extra pass repeats "the
    // full two-solution search" (docs/SDD.md 3.6), but RTVM-204's counter and
    // the poll cadence it drives must stay continuous across passes rather
    // than restart at every pass boundary.
    void beginNewPass()
    {
        m_solutionsFound = 0;
        m_firstSolution  = Grid{};
    }

private:
    // Calls onPoll every pollNodeInterval nodes. An interval of zero disables
    // polling rather than dividing by it; a caller that wants no callbacks says
    // so that way. Returns false once an abort has been requested (RTVM-203).
    bool poll(int depth)
    {
        if (m_aborted) {
            return false;
        }
        if (m_pollNodeInterval == 0) {
            return true;
        }
        if (--m_nodesUntilPoll > 0) {
            return true;
        }
        m_nodesUntilPoll = m_pollNodeInterval;

        SolveProgress progress;
        progress.nodesExplored = m_nodesExplored;
        progress.currentDepth  = depth;
        if (!m_control.onPoll(progress)) {
            m_aborted = true;
            return false;
        }
        return true;
    }

    // Returns false when enough solutions have been found to stop.
    bool recordSolution(const SearchState& state)
    {
        ++m_solutionsFound;
        if (m_solutionsFound == 1) {
            m_firstSolution = toGrid(state);
        }
        return m_solutionsFound < m_maxSolutions;
    }

    int                m_maxSolutions;
    std::uint32_t      m_pollNodeInterval;
    SolveControl&      m_control;
    std::uint32_t      m_nodesUntilPoll;
    std::uint64_t      m_nodesExplored = 0;
    int                m_solutionsFound = 0;
    bool               m_aborted = false;
    Grid               m_firstSolution{};
};

} // namespace

SolveReport solve(const Grid& puzzle,
                  const SolveOptions& options,
                  SolveControl& control)
{
    const auto startTime = std::chrono::steady_clock::now();

    SearchState root = makeEmptyState();

    // Seed the givens. A contradictory set of givens cannot complete, so it is
    // a NoSolution here; RTVM-104 catches the duplicate-digit case earlier and
    // more precisely, but solve() must not depend on having been called after
    // the parser. Seeding is deterministic, so there is no RTVM-507 extension
    // to run below when it fails here -- a second attempt would fail exactly
    // the same way -- hence the direct return.
    if (!seedGivens(puzzle, root)) {
        return SolveReport::noSolution(0);
    }

    Search search(options, control);
    static_cast<void>(search.explore(std::move(root), 0));
    const SolveReport result = search.report();

    if (options.minSolveDuration.count() <= 0 || result.outcome() == Outcome::Aborted) {
        return result;
    }

    // RTVM-507 diagnostic hook (docs/SDD.md 3.6): `result` is already the
    // answer this call will return. Keep performing genuine search work --
    // repeating the full two-solution search on a scratch copy of `puzzle`
    // and discarding every result -- until minSolveDuration has elapsed
    // since this call began, so that a solve normally far too fast to reach
    // the prompt thresholds (docs/RTVM.md 7 I-10) can be made to sit in them
    // on demand.
    //
    // `search` itself is reused rather than rebuilt for each pass so its node
    // count and poll countdown stay continuous across passes -- rebuilding it
    // would reset the poll countdown every pass and could leave onPoll never
    // called at all on a puzzle whose full search tree is smaller than
    // options.pollNodeInterval, which is exactly the P-HARD17 case this hook
    // exists for. That continuity is also what keeps RTVM-204's counter
    // monotonic across the whole call rather than sawtoothing back to zero at
    // every pass boundary.
    //
    // An abort requested during this extra work outranks the hook: RTVM-203
    // promises the solve stops within 1.0 s regardless of which phase it is
    // in, so that outcome replaces `result` below rather than being folded
    // into it or delayed until minSolveDuration elapses.
    while (std::chrono::steady_clock::now() - startTime < options.minSolveDuration) {
        SearchState scratch = makeEmptyState();
        if (!seedGivens(puzzle, scratch)) {
            break;   // unreachable in practice: seeding already succeeded once
        }
        search.beginNewPass();
        if (!search.explore(std::move(scratch), 0)) {
            return SolveReport::aborted(search.nodesExplored());
        }
    }
    return result;
}

} // namespace sudoku
