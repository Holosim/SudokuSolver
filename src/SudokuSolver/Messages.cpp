// Messages.cpp — see Messages.h.
//
// SCAFFOLD, PARTIALLY FILLED. The wordings are pinned by docs/RTVM.md 6.2 and
// docs/SDD.md 2.8. notUniqueNote() carries its real text as of RTVM-401
// (#12); the rest are filled in under their own output issues.
//
// TODO(RTVM-400, RTVM-402, RTVM-403, RTVM-404, RTVM-004): real wording.

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
    // Reference wording, docs/RTVM.md TP-401 and 6.2. Newline-terminated
    // because Reporter concatenates it directly after formatGrid()'s output,
    // which is itself a sequence of newline-terminated lines (RTVM-401).
    return "Note: this puzzle has more than one solution; "
           "the solution shown is the first one found.\n";
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
