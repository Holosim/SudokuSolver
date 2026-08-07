// Messages.h — every user-visible English string, in one place.
//
// docs/SDD.md 2.7, 2.8. RTVM-302, RTVM-400..404.
//
// Nothing outside this pair of files contains a sentence. That is what
// makes RTVM-302 ("wording lives in the output layer") structural, and what
// keeps the 1-based r<row>c<col> conversion of RTVM-105 in exactly one
// place.

#pragma once

#include <cstdint>
#include <string>

#include "InputFault.h"

namespace sudoku::cli::messages {

// "r<row>c<col>", converting the core's 0-based cells to 1-based (RTVM-105).
[[nodiscard]] std::string cellName(const CellRef& cell);

// Diagnostic for a rejected input. stderr (RTVM-403).
[[nodiscard]] std::string inputFault(const InputFault& fault);

// stdout (RTVM-401).
[[nodiscard]] std::string notUniqueNote();

// stdout (RTVM-402).
[[nodiscard]] std::string noSolution();

// stderr (RTVM-404).
[[nodiscard]] std::string aborted();

// stderr (RTVM-004, RTVM-501, RTVM-502). The leading sentence is pinned by
// docs/SDD.md 2.8 so TP-004's regex matches as written; the step count is
// the live RTVM-204 counter, which is what makes RTVM-503 observable from
// stderr alone.
[[nodiscard]] std::string progressPrompt(int elapsedSeconds,
                                         std::uint64_t nodesExplored);

// stderr, for an internal fault caught by main's catch-all (docs/SDD.md 2.9).
[[nodiscard]] std::string internalError();

} // namespace sudoku::cli::messages
