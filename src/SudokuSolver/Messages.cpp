// Messages.cpp — see Messages.h.
//
// SCAFFOLD, partially filled. The wordings are pinned by docs/RTVM.md 6.2 and
// docs/SDD.md 2.8 and are filled in under the output issues.
//
// noSolution() is real as of RTVM-402 (#11): the reference wording of
// docs/SDD.md 2.8 / docs/RTVM.md 6.2, terminated the same way every other
// message in this file is — GridFormat.cpp's convention of every line
// (including the last) carrying its own '\n', so a caller downstream never
// has to add or guess about a separator (docs/RTVM.md TP-402: "no separator
// line").
//
// TODO(RTVM-400, RTVM-401, RTVM-403, RTVM-404, RTVM-004): real wording.

#include "Messages.h"

namespace sudoku::cli::messages {

std::string cellName(const CellRef& cell)
{
    static_cast<void>(cell);
    return std::string{};
}

std::string inputFault(const InputFault& fault)
{
    static_cast<void>(fault);
    return std::string{};
}

std::string notUniqueNote()
{
    return std::string{};
}

std::string noSolution()
{
    return "This puzzle has no solution.\n";
}

std::string aborted()
{
    return std::string{};
}

std::string progressPrompt(int elapsedSeconds, std::uint64_t nodesExplored)
{
    static_cast<void>(elapsedSeconds);
    static_cast<void>(nodesExplored);
    return std::string{};
}

std::string internalError()
{
    return std::string{};
}

} // namespace sudoku::cli::messages
