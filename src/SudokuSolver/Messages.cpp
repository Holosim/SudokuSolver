// Messages.cpp — see Messages.h.
//
// SCAFFOLD ONLY. The wordings are pinned by docs/RTVM.md 6.2 and
// docs/SDD.md 2.8 and are filled in under the output issues.
//
// TODO(RTVM-400, RTVM-401, RTVM-402, RTVM-403, RTVM-404, RTVM-004): real
// wording.

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
    return std::string{};
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
