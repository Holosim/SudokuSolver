// main.cpp — the host. One process, one thread.
//
// docs/SDD.md 1.1, 1.2, 2.9. RTVM-001, RTVM-405, RTVM-505.
//
// The pipeline is wired end to end here so the shape of a run is readable
// in one place:
//
//     argv -> InputSource -> parseGrid -> solve (polled by SolveSession)
//          -> Reporter -> exit code
//
// The individual stages are scaffolds; the wiring is not.

#include <cerrno>
#include <chrono>
#include <cstdlib>
#include <exception>
#include <iostream>

#include "CommandLine.h"
#include "InputSource.h"
#include "Messages.h"
#include "Parser.h"
#include "Reporter.h"
#include "SolveReport.h"
#include "SolveSession.h"
#include "Solver.h"
#include "StdinChannel.h"

namespace {

// docs/SDD.md 3.6: the console layer reads SUDOKU_DIAG_MIN_SOLVE_MS at
// startup and passes the value in SolveOptions::minSolveDuration, so the
// core never touches the environment (RTVM-903). Absent, empty, zero or
// unparseable means completely inert -- std::strtol's own "no digits
// consumed" signal (end == value) covers empty and non-numeric text in one
// branch, *end != '\0' rejects trailing garbage such as "500ms" rather than
// silently truncating it, and the range/sign checks reject overflow and
// non-positive values. Not reachable from puzzle content in any form (RTVM-002
// fixes the meaning of argv; this reads the environment, not argv) -- TP-507
// asserts that.
[[nodiscard]] std::chrono::milliseconds diagnosticMinSolveDuration()
{
    const char* const value = std::getenv("SUDOKU_DIAG_MIN_SOLVE_MS");
    if (value == nullptr || *value == '\0') {
        return std::chrono::milliseconds{0};
    }

    errno = 0;
    char* end = nullptr;
    const long parsed = std::strtol(value, &end, 10);
    if (end == value || *end != '\0' || errno == ERANGE || parsed <= 0) {
        return std::chrono::milliseconds{0};
    }
    return std::chrono::milliseconds{parsed};
}

[[nodiscard]] sudoku::cli::ExitCode run(int argc, char** argv)
{
    using namespace sudoku;
    using namespace sudoku::cli;

    const CommandLine commandLine = CommandLine::parse(argc, argv);

    StdinChannel stdinChannel;
    InputSource  source(stdinChannel);
    Reporter     reporter(std::cout, std::cerr);

    const ReadResult read = source.readPuzzleText(commandLine.puzzlePath);
    if (read.fault.has_value()) {
        return reporter.report(SolveReport::invalidInput(*read.fault));
    }

    const ParseResult parsed = parseGrid(read.text);
    if (!parsed.ok()) {
        // A rejected puzzle is never handed to the solver (RTVM-105).
        return reporter.report(SolveReport::invalidInput(parsed.fault()));
    }

    SolveOptions options{};
    options.minSolveDuration = diagnosticMinSolveDuration();

    SolveSession session(stdinChannel, std::cerr);
    return reporter.report(solve(parsed.grid(), options, session));
}

} // namespace

int main(int argc, char** argv)
{
    // RTVM-505: no input may produce an unhandled exception or a crash
    // dialog, and RTVM-405 permits no exit code outside {0,1,2,3}. An
    // internal fault is therefore reported as InvalidInput -- the only code
    // meaning "no result was produced because something was wrong with this
    // run".
    try {
        return static_cast<int>(run(argc, argv));
    }
    catch (const std::exception&) {
        std::cerr << sudoku::cli::messages::internalError();
    }
    catch (...) {
        std::cerr << sudoku::cli::messages::internalError();
    }
    return static_cast<int>(sudoku::cli::ExitCode::InvalidInput);
}
