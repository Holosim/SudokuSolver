// ProcessRunner.h -- spawns the built SudokuSolver.exe for the end-to-end
// test procedures docs/SDD.md 3.3 assigns to this project: TP-001...009,
// TP-401...406 and TP-500...507, everything that is about process behaviour,
// streams and exit codes rather than a pure function of core types.
//
// docs/RTVM.md 9.8.1 pins why this exists (issue #24): those procedures
// passed once on issue-9 by hand and are not regression-tested by anything
// committed to the repository. This closes that gap.
//
// Two rules this type exists to enforce, because getting either wrong
// deadlocks the test suite rather than failing one test in it:
//
//  1. stdout and stderr are pumped concurrently on their own threads, never
//     one drained to EOF before the other is touched. A child that fills the
//     pipe buffer of the stream nobody is reading yet blocks on the next
//     write, and the harness blocks with it.
//  2. Byte input handed to the child's stdin (StdinMode::Bytes) is written on
//     a dedicated thread and the write end is then closed, so the child
//     always observes EOF (TP-003, TP-008) rather than waiting on a
//     caller-supplied terminator that may never arrive.
//
// PLATFORM. docs/SDD.md 3.3 specifies CreateProcess with anonymous pipes for
// stdin/stdout/stderr; that _WIN32 branch is the only one
// SudokuSolver.Tests.vcxproj ever compiles, and it is what ships. The POSIX
// branch (fork/exec/pipe) ships nothing to the client -- it exists so these
// procedures execute for real on this pipeline's Linux agents, which have no
// MSVC (docs/RTVM.md 9.1), mirroring the seam
// src/SudokuSolver/StdinChannel.cpp uses for the same reason. Both branches
// live entirely inside ProcessRunner.cpp; this header is platform-neutral.

#pragma once

#include <chrono>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace sudoku::test {

// How the child's standard input is supplied.
enum class StdinMode : std::uint8_t {
    Closed,   // no stdin at all -- TP-002 part 1 ("stdin closed")
    Bytes,    // a supplied buffer, written then closed for EOF -- TP-003, TP-008
    File      // redirected from an existing file on disk -- TP-002 part 3
};

struct ProcessInput {
    StdinMode mode = StdinMode::Closed;
    std::string bytes;       // used when mode == StdinMode::Bytes
    std::string filePath;    // used when mode == StdinMode::File
};

struct ProcessResult {
    // False when the process could not even be started (bad executable path,
    // spawn failure). Every other field is meaningless when this is false,
    // and it is the first thing a caller should check.
    bool spawned = false;

    // True when 'run' had to force termination after its timeout elapsed.
    // exitCode is not meaningful in that case -- it is whatever the OS
    // reports for a killed process, not a result the product chose.
    bool timedOut = false;

    int exitCode = -1;

    // Binary-safe: a NUL byte in either stream is data (RTVM-505), never
    // treated as a terminator.
    std::string stdOut;
    std::string stdErr;

    // Wall clock from just before the process is spawned to the moment it is
    // observed to have exited (or been killed). TP-005 (1.0 s abort
    // latency), TP-007 (<20 s) and TP-500...504 measure this from outside.
    std::chrono::milliseconds wallClock{ 0 };
};

class ProcessRunner {
public:
    ProcessRunner() = delete;

    // Spawns 'executablePath' with argv[1..] = 'args' (0..n arguments -- an
    // empty 'args' is TP-003's no-argument form; TP-002's "ignored extra
    // args" is a 3+ element form). Applies 'input', pumps both output
    // streams concurrently, and waits up to 'timeout' before forcing
    // termination and reporting timedOut rather than hanging the caller.
    [[nodiscard]] static ProcessResult run(
        const std::string& executablePath,
        const std::vector<std::string>& args,
        const ProcessInput& input,
        std::chrono::milliseconds timeout = std::chrono::seconds(30));

    // The directory this test module was loaded from -- the DLL's own path
    // on Windows (not the vstest host process's path, which lives somewhere
    // else entirely), the running module's path on POSIX. SudokuSolver.exe
    // shares $(OutDir) with SudokuSolver.Tests (docs/SDD.md 3.1), so a caller
    // builds the product path from this rather than assuming a relative path
    // that depends on the working directory Test Explorer happens to start
    // in.
    [[nodiscard]] static std::string testModuleDirectory();
};

// Normalises CRLF -> LF in 'actual' and compares the result byte-exact
// against 'expectedLf'. The Release build writes stdout in text mode on
// Windows, so a raw pipe capture carries CRLF even though every fixture in
// this project (docs/RTVM.md 6.2) is stored LF; the terminator *count* is
// normative, not its spelling.
[[nodiscard]] bool equalsAfterCrlfNormalization(std::string_view actual, std::string_view expectedLf);

} // namespace sudoku::test
