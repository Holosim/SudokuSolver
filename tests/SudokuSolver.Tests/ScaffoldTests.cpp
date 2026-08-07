// ScaffoldTests.cpp — the placeholder test that proves the suite runs.
//
// docs/SDD.md 3.3. RTVM-905.
//
// Test methods are named for the RTVM item they verify, so a test report,
// a commit message and an issue title can all be searched on the same
// RTVM-<nnn> string (docs/SDD.md 2.2).
//
// Slow tests (TP-501, TP-502, TP-504, TP-507 run to 60 s by design) carry
//     TEST_METHOD_ATTRIBUTE(L"TestCategory", L"Slow")
// so the default developer run stays fast. Nothing here needs it yet.

#include "CppUnitTest.h"

#include "Grid.h"
#include "SolveReport.h"

using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace sudoku::test {

TEST_CLASS(ScaffoldTests)
{
public:
    // RTVM-905: the test project builds, links the core, and reports a
    // result. Replaced by real coverage as each feature lands.
    TEST_METHOD(rtvm905_testProjectRunsAndLinksTheCore)
    {
        Assert::AreEqual(kBoxSize * kBoxSize, kGridSize,
            L"kGridSize must stay derived from kBoxSize");
        Assert::AreEqual(kGridSize * kGridSize, kCellCount);

        const Grid empty{};
        Assert::IsFalse(empty.isComplete(),
            L"a default-constructed grid holds no digits");
    }

    // RTVM-903: the core links without the console layer. If this file ever
    // needs the CLI to build, the separation has been lost.
    TEST_METHOD(rtvm903_coreIsUsableWithoutTheConsoleLayer)
    {
        const SolveReport report = SolveReport::aborted(0);
        Assert::IsTrue(report.outcome() == Outcome::Aborted);
        Assert::IsFalse(report.hasGrid());
        Assert::IsFalse(report.hasFault());
    }
};

} // namespace sudoku::test
