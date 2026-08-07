// CommandLine.h — the whole of the command line contract.
//
// docs/SDD.md 2.7. RTVM-002, RTVM-003.

#pragma once

#include <string>

namespace sudoku::cli {

struct CommandLine {
    // Empty means "no path was given", i.e. read the puzzle from standard
    // input (RTVM-003).
    std::string puzzlePath;

    // The first argument is a puzzle path; every further argument is
    // ignored (RTVM-002). There are no switches, which is also what keeps
    // the RTVM-507 hook out of the command line and in the environment.
    [[nodiscard]] static CommandLine parse(int argc, char** argv);
};

} // namespace sudoku::cli
