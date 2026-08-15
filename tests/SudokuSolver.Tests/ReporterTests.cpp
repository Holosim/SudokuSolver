// ReporterTests.cpp — TP-403, the invalid-input diagnostic stream.
//
// Procedure: docs/RTVM.md TP-403. Run P-BADCHAR, P-SHORT and P-CONTRA-ROW;
// for each, stdout must be byte-empty (RTVM-403, RTVM-406) and the
// diagnostic must appear on stderr; exit code 1 in all three cases
// (RTVM-405).
//
// Reporter takes its two streams by reference (docs/SDD.md 2.7), so the
// whole of TP-403 is testable here with std::ostringstream in place of
// std::cout/std::cerr — no process capture needed for this half of it. The
// three cases are driven through the real parser, exactly as TP-403 asks,
// so the fault each one produces is not hand-built.

#include "CppUnitTest.h"

#include <sstream>
#include <string>

#include "Messages.h"
#include "Parser.h"
#include "Reporter.h"
#include "SolveReport.h"
#include "TestFixtures.h"

using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace sudoku::test {

namespace {

// Runs one TP-403 case: parse `text` (expected to fail), report it, and
// assert stdout stays byte-empty, stderr carries the fault's diagnostic, and
// the exit code is InvalidInput.
void assertInvalidInputStaysOffStdout(std::string_view text, const wchar_t* label)
{
    const ParseResult parsed = parseGrid(text);
    Assert::IsFalse(parsed.ok(), label);

    std::ostringstream out;
    std::ostringstream err;
    const cli::Reporter reporter(out, err);

    const cli::ExitCode code = reporter.report(SolveReport::invalidInput(parsed.fault()));

    Assert::IsTrue(code == cli::ExitCode::InvalidInput, label);
    Assert::AreEqual(std::string{}, out.str(),
        L"stdout must be byte-empty for InvalidInput (RTVM-403, RTVM-406)");
    Assert::AreEqual(cli::messages::inputFault(parsed.fault()), err.str(),
        L"stderr must carry exactly the fault's diagnostic and nothing else");
    Assert::IsFalse(err.str().empty(), label);
}

} // namespace

TEST_CLASS(ReporterTests)
{
public:
    // TP-403 case 1: P-BADCHAR (illegal character).
    TEST_METHOD(rtvm403_illegalCharacterFaultStaysOffStdout)
    {
        assertInvalidInputStaysOffStdout(kInputBadChar, L"P-BADCHAR");
    }

    // TP-403 case 2: P-SHORT (missing line).
    TEST_METHOD(rtvm403_missingLineFaultStaysOffStdout)
    {
        assertInvalidInputStaysOffStdout(kInputShort, L"P-SHORT");
    }

    // TP-403 case 3: P-CONTRA-ROW (row duplicate).
    TEST_METHOD(rtvm403_rowDuplicateFaultStaysOffStdout)
    {
        assertInvalidInputStaysOffStdout(kInputContraRow, L"P-CONTRA-ROW");
    }

    // RTVM-009 / RTVM-403 together: a SourceUnreadable fault (which the
    // parser never produces itself — InputSource does, see InputSource.cpp)
    // takes the same path to the same exit code.
    TEST_METHOD(rtvm009_sourceUnreadableFaultReportsExitCodeOneOffStdout)
    {
        InputFault fault;
        fault.kind        = FaultKind::SourceUnreadable;
        fault.path        = "does_not_exist.txt";
        fault.systemError = 2;

        std::ostringstream out;
        std::ostringstream err;
        const cli::Reporter reporter(out, err);

        const cli::ExitCode code = reporter.report(SolveReport::invalidInput(fault));

        Assert::IsTrue(code == cli::ExitCode::InvalidInput);
        Assert::AreEqual(std::string{}, out.str());
        Assert::IsFalse(err.str().empty());
    }

    // TP-404: the Aborted outcome writes the abandonment message to stderr
    // and stdout stays byte-empty, exit code Aborted (RTVM-404, §7 I-5). The
    // Aborted path has no dependency on timing or stdin, so — exactly like
    // the cases above — it is testable here with std::ostringstream rather
    // than a spawned process.
    TEST_METHOD(rtvm404_abortedReportsAbandonmentMessageOffStdout)
    {
        std::ostringstream out;
        std::ostringstream err;
        const cli::Reporter reporter(out, err);

        const cli::ExitCode code = reporter.report(SolveReport::aborted(12345));

        Assert::IsTrue(code == cli::ExitCode::Aborted);
        Assert::AreEqual(std::string{}, out.str(),
            L"stdout must be byte-empty for Aborted (RTVM-404, RTVM-406)");
        Assert::AreEqual(cli::messages::aborted(), err.str(),
            L"stderr must carry exactly the abandonment message and nothing else");
        Assert::IsTrue(err.str().find("abandoned at") != std::string::npos,
            L"TP-005/TP-404 look for the substring \"abandoned at\"");
    }
};

} // namespace sudoku::test
