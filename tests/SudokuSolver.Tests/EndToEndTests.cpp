// EndToEndTests.cpp -- TP-001, TP-002, TP-003, the first procedures moved
// onto sudoku::test::ProcessRunner (issue #24, docs/RTVM.md 9.8.1).
//
// docs/RTVM.md TP-001, TP-002, TP-003. RTVM-001, RTVM-002, RTVM-003.
//
// Chosen deliberately as the harness's first tenants rather than a new
// feature: all three passed by hand on issue-9 against the known-good
// S-EASY §6.2 block, so a failure here means the harness disagrees with
// already-verified behaviour, not that a feature regressed.
//
// Fixtures: samples/easy.txt and samples/unsolvable.txt are copied beside
// SudokuSolver.exe by that project's post-build step (docs/SDD.md 3.1), and
// SudokuSolver.Tests shares the same $(OutDir), so both are read directly
// from there rather than rewritten as temporary files -- they are also the
// RTVM-907 samples, byte-identical to P-EASY / P-UNSOLVABLE (docs/RTVM.md
// 6.1), so using them ties this test to the same fixture the DELIV
// inspections check.

#include "CppUnitTest.h"

#include <chrono>
#include <cstdlib>
#include <string>
#include <vector>

#include "ProcessRunner.h"
#include "TestFixtures.h"

using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace sudoku::test {

namespace {

// The product exe under test. On the shipped _WIN32 build this is exactly
// docs/SDD.md 3.3's $(OutDir)SudokuSolver.exe, resolved at run time from the
// directory this test module itself was loaded from (docs/SDD.md 3.1's
// shared $(OutDir)). The POSIX arm is never shipped -- see ProcessRunner.cpp
// -- and exists only so these three procedures execute for real on this
// pipeline's Linux agents against a g++-built stand-in named by
// SUDOKU_TEST_EXE, or a same-directory "SudokuSolver" if that is unset.
[[nodiscard]] std::string productExecutablePath()
{
#if defined(_WIN32)
    return ProcessRunner::testModuleDirectory() + "\\SudokuSolver.exe";
#else
    if (const char* const overridePath = std::getenv("SUDOKU_TEST_EXE")) {
        return overridePath;
    }
    return ProcessRunner::testModuleDirectory() + "/SudokuSolver";
#endif
}

[[nodiscard]] std::string samplePath(const std::string& fileName)
{
#if defined(_WIN32)
    return ProcessRunner::testModuleDirectory() + "\\samples\\" + fileName;
#else
    return ProcessRunner::testModuleDirectory() + "/samples/" + fileName;
#endif
}

// TP-001...003 are all sub-second in normal operation; ten seconds is
// generous headroom that still turns a genuine hang into a fast failure
// instead of stalling the whole suite.
inline constexpr std::chrono::milliseconds kProcedureTimeout{ 10000 };

[[nodiscard]] ProcessResult runProduct(const std::vector<std::string>& args, const ProcessInput& input)
{
    return ProcessRunner::run(productExecutablePath(), args, input, kProcedureTimeout);
}

} // namespace

TEST_CLASS(EndToEndTests)
{
public:
    // TP-001: no menu, no question, immediate solve -- stdin form and the
    // file-argument form must agree byte for byte, proving the absence of a
    // menu is not input-source dependent.
    TEST_METHOD(rtvm001_noMenuImmediateSolveBothInputForms)
    {
        ProcessInput stdinInput;
        stdinInput.mode = StdinMode::Bytes;
        stdinInput.bytes = toMultilinePuzzleText(kPuzzleEasy);
        const ProcessResult viaStdin = runProduct({}, stdinInput);

        Assert::IsTrue(viaStdin.spawned, L"the product must launch");
        Assert::IsFalse(viaStdin.timedOut, L"TP-001 is a sub-second run");
        Assert::AreEqual(0, viaStdin.exitCode, L"a solved puzzle exits 0");
        Assert::IsTrue(viaStdin.stdErr.empty(),
            L"no menu, question or \"press any key\" text -- stderr must be 0 bytes");
        Assert::IsTrue(equalsAfterCrlfNormalization(viaStdin.stdOut, kSolvedEasyFormatted),
            L"stdout must be exactly the S-EASY 6.2 block");

        ProcessInput fileInput;
        fileInput.mode = StdinMode::Closed;
        const ProcessResult viaFile = runProduct({ samplePath("easy.txt") }, fileInput);

        Assert::IsTrue(viaFile.spawned, L"the product must launch");
        Assert::IsFalse(viaFile.timedOut, L"TP-001 is a sub-second run");
        Assert::AreEqual(0, viaFile.exitCode, L"a solved puzzle exits 0");
        Assert::IsTrue(viaFile.stdErr.empty(), L"no menu, question or \"press any key\" text");
        Assert::IsTrue(equalsAfterCrlfNormalization(viaFile.stdOut, kSolvedEasyFormatted),
            L"stdout must be exactly the S-EASY 6.2 block");

        // The procedure's own point: absence of a menu is not input-source
        // dependent, so the two forms must be byte-identical.
        Assert::AreEqual(viaStdin.stdOut, viaFile.stdOut,
            L"the stdin and file-argument forms must produce byte-identical stdout");
    }

    // TP-002 part 1: a bare file argument with stdin closed solves and
    // exits 0.
    TEST_METHOD(rtvm002_fileArgumentSolves)
    {
        ProcessInput input;
        input.mode = StdinMode::Closed;
        const ProcessResult result = runProduct({ samplePath("easy.txt") }, input);

        Assert::IsTrue(result.spawned);
        Assert::IsFalse(result.timedOut);
        Assert::AreEqual(0, result.exitCode);
        Assert::IsTrue(equalsAfterCrlfNormalization(result.stdOut, kSolvedEasyFormatted));
    }

    // TP-002 part 2: trailing arguments beyond the puzzle path are ignored --
    // identical output and exit code to the bare-argument case.
    TEST_METHOD(rtvm002_trailingArgumentsIgnored)
    {
        ProcessInput input;
        input.mode = StdinMode::Closed;
        const ProcessResult result =
            runProduct({ samplePath("easy.txt"), "ignored", "extra", "args" }, input);

        Assert::IsTrue(result.spawned);
        Assert::IsFalse(result.timedOut);
        Assert::AreEqual(0, result.exitCode);
        Assert::IsTrue(equalsAfterCrlfNormalization(result.stdOut, kSolvedEasyFormatted),
            L"trailing arguments must not change stdout");
    }

    // TP-002 part 3: a file argument wins over stdin -- with a path present,
    // stdin (here carrying the unsolvable puzzle) is never read at all.
    TEST_METHOD(rtvm002_fileArgumentWinsOverStdin)
    {
        ProcessInput input;
        input.mode = StdinMode::File;
        input.filePath = samplePath("unsolvable.txt");
        const ProcessResult result = runProduct({ samplePath("easy.txt") }, input);

        Assert::IsTrue(result.spawned);
        Assert::IsFalse(result.timedOut);
        Assert::AreEqual(0, result.exitCode, L"the file argument must win, not the unsolvable stdin");
        Assert::IsTrue(equalsAfterCrlfNormalization(result.stdOut, kSolvedEasyFormatted));
    }

    // TP-003: no arguments, P-EASY piped to stdin -- stdout is the S-EASY
    // block, exit 0.
    TEST_METHOD(rtvm003_stdinFallbackNoArguments)
    {
        ProcessInput input;
        input.mode = StdinMode::Bytes;
        input.bytes = toMultilinePuzzleText(kPuzzleEasy);
        const ProcessResult result = runProduct({}, input);

        Assert::IsTrue(result.spawned);
        Assert::IsFalse(result.timedOut);
        Assert::AreEqual(0, result.exitCode);
        Assert::IsTrue(result.stdErr.empty());
        Assert::IsTrue(equalsAfterCrlfNormalization(result.stdOut, kSolvedEasyFormatted));
    }
};

} // namespace sudoku::test
