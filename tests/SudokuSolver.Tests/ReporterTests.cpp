// ReporterTests.cpp — TP-403/TP-404, and the unit-reachable half of
// TP-300/TP-405/TP-406.
//
// Procedure: docs/RTVM.md TP-403. Run P-BADCHAR, P-SHORT and P-CONTRA-ROW;
// for each, stdout must be byte-empty (RTVM-403, RTVM-406) and the
// diagnostic must appear on stderr; exit code 1 in all three cases
// (RTVM-405). TP-404 (abort message stream) and the RTVM-405/RTVM-406
// aggregate over all five outcome classes plus TP-300's outcome-distinctness
// clause are below it.
//
// Reporter takes its two streams by reference (docs/SDD.md 2.7), so all of
// this is testable here with std::ostringstream in place of std::cout/
// std::cerr — no process capture needed. Every case is driven through the
// real parser/solver, exactly as the RTVM procedures ask, so no fault or
// report is hand-built except where the procedure itself has no unit-level
// equivalent (SourceUnreadable never comes from the parser; Aborted needs no
// session — see the two methods that build one directly, below).

#include "CppUnitTest.h"

#include <sstream>
#include <string>
#include <vector>

#include "Messages.h"
#include "Parser.h"
#include "Reporter.h"
#include "SolveControl.h"
#include "SolveReport.h"
#include "Solver.h"
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

    // RTVM-405 / RTVM-406, the aggregate half of both, plus TP-300's
    // whole-run half (docs/RTVM.md TP-300, TP-405, TP-406): drive the
    // parse/solve/report pipeline once per TP-300 fixture class -- P-EASY,
    // P-NONUNIQUE, P-BADCHAR, P-UNSOLVABLE, and the Aborted factory in place
    // of the long-solve hook + stop response, exactly as
    // rtvm404_abortedReportsAbandonmentMessageOffStdout above already does
    // for Aborted alone -- and check, as one aggregate over all five (not
    // five separate assertions the way TP-403/TP-404 check one outcome
    // each), exactly what RTVM-405/RTVM-406 require: exit codes 0, 0, 1, 2,
    // 3 in that order, and never a forbidden substring on stdout for any of
    // them. The five outcomes are also asserted pairwise distinct, which is
    // TP-300's own closing clause.
    //
    // This is the unit-level reach of TP-300/TP-405/TP-406. The
    // process-level half -- a real argv, InputSource/StdinChannel, and an
    // actual OS exit code -- is tests/windows/run-procedures.ps1's TP-405/
    // TP-406 sections, which already drive four of the five fixture classes
    // end to end; the fifth (Aborted) is NOT-RUN there pending the
    // interactive stop-response protocol, the same standing limitation
    // TP-004..008 already carry (docs/RTVM.md 9.13) -- not a gap this test
    // introduces or can close from the unit side.
    TEST_METHOD(rtvm405and406_exitCodeAndStdoutPurityAcrossAllFiveOutcomeClasses)
    {
        NullSolveControl control;

        struct Case {
            const wchar_t* label;
            SolveReport    report;
            cli::ExitCode  expectedCode;
        };

        std::vector<Case> cases;
        cases.push_back(Case{ L"P-EASY (Solved)",
            solve(gridFromCompactForm(kPuzzleEasy), SolveOptions{}, control),
            cli::ExitCode::Success });
        cases.push_back(Case{ L"P-NONUNIQUE (SolvedNotUnique)",
            solve(gridFromCompactForm(kPuzzleNonUnique), SolveOptions{}, control),
            cli::ExitCode::Success });
        cases.push_back(Case{ L"P-BADCHAR (InvalidInput)",
            SolveReport::invalidInput(parseGrid(kInputBadChar).fault()),
            cli::ExitCode::InvalidInput });
        cases.push_back(Case{ L"P-UNSOLVABLE (NoSolution)",
            solve(gridFromCompactForm(kPuzzleUnsolvable), SolveOptions{}, control),
            cli::ExitCode::NoSolution });
        cases.push_back(Case{ L"long-solve hook + stop response (Aborted)",
            SolveReport::aborted(12345),
            cli::ExitCode::Aborted });

        static const std::string kForbidden[] = {
            "Still working", "abandoned", "r1c1", "Error", "could not"
        };

        std::vector<Outcome> outcomesSeen;
        for (const Case& c : cases) {
            outcomesSeen.push_back(c.report.outcome());

            std::ostringstream out;
            std::ostringstream err;
            const cli::Reporter reporter(out, err);
            const cli::ExitCode code = reporter.report(c.report);

            Assert::IsTrue(code == c.expectedCode, c.label); // RTVM-405

            const std::string stdoutText = out.str();
            for (const std::string& banned : kForbidden) {   // RTVM-406
                Assert::IsTrue(stdoutText.find(banned) == std::string::npos, c.label);
            }
        }

        // TP-300: each run reports exactly one outcome, and the five fixture
        // classes' outcomes are pairwise distinct.
        for (std::size_t i = 0; i < outcomesSeen.size(); ++i) {
            for (std::size_t j = i + 1; j < outcomesSeen.size(); ++j) {
                Assert::IsFalse(outcomesSeen[i] == outcomesSeen[j],
                    L"TP-300: the five fixture classes must report five distinct outcomes");
            }
        }
    }
};

} // namespace sudoku::test
