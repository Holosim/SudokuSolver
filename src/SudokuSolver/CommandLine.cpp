// CommandLine.cpp — see CommandLine.h. RTVM-002, RTVM-003.

#include "CommandLine.h"

namespace sudoku::cli {

CommandLine CommandLine::parse(int argc, char** argv)
{
    CommandLine result{};
    if (argc > 1 && argv != nullptr && argv[1] != nullptr) {
        result.puzzlePath = argv[1];
    }
    return result;
}

} // namespace sudoku::cli
