// MessagesTests.cpp — the wording RTVM-102, RTVM-103, RTVM-104, RTVM-105
// and RTVM-009 require, and RTVM-302's guarantee that it lives here alone.
//
// docs/RTVM.md 7 I-18 and this issue's own scope note both say the same
// thing: TP-009, TP-102, TP-103, TP-104 and TP-105 assert the *elements* a
// diagnostic must name (a line number, a length, a character, a cell, a
// digit, a unit, a path), not an exact pinned sentence — RTVM-401, RTVM-402
// and RTVM-404 are the only messages docs/RTVM.md 6.2 pins verbatim, and
// none of those is built here. So every assertion below checks that the
// required element's own text appears in the rendered string, not that the
// whole string equals a literal.

#include "CppUnitTest.h"

#include <string>

#include "InputFault.h"
#include "Messages.h"
#include "Parser.h"

using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace sudoku::test {

namespace {

[[nodiscard]] bool contains(const std::string& haystack, const std::string& needle)
{
    return haystack.find(needle) != std::string::npos;
}

} // namespace

TEST_CLASS(MessagesTests)
{
public:
    // RTVM-105: cells are named in one-based r<row>c<col> form.
    TEST_METHOD(rtvm105_cellNameRendersOneBasedRAndC)
    {
        Assert::AreEqual(std::string("r3c4"), cli::messages::cellName(CellRef{ 3, 4 }));
        Assert::AreEqual(std::string("r1c1"), cli::messages::cellName(CellRef{ 1, 1 }));
        Assert::AreEqual(std::string("r9c9"), cli::messages::cellName(CellRef{ 9, 9 }));
    }

    // TP-102 case 1: the missing-line diagnostic names the missing line.
    TEST_METHOD(rtvm102_missingLineDiagnosticNamesTheLine)
    {
        InputFault fault;
        fault.kind = FaultKind::MissingLine;
        fault.line = 9;

        const std::string message = cli::messages::inputFault(fault);
        Assert::IsTrue(contains(message, "9"), L"the diagnostic must name line 9");
    }

    // TP-102 cases 2 and 3: the length diagnostics name the line and the
    // exact observed length, distinguishing too-short from too-long is not
    // asserted by TP-102 (both simply "name the length"), but both must be
    // present as the exact number, not the sentinel.
    TEST_METHOD(rtvm102_lineTooLongDiagnosticNamesTheLineAndItsLength)
    {
        InputFault fault;
        fault.kind = FaultKind::LineTooLong;
        fault.line = 5;
        fault.observedLength = 11;

        const std::string message = cli::messages::inputFault(fault);
        Assert::IsTrue(contains(message, "5"), L"the diagnostic must name line 5");
        Assert::IsTrue(contains(message, "11"), L"the diagnostic must name the length 11");
    }

    TEST_METHOD(rtvm102_lineTooShortDiagnosticNamesTheLineAndItsLength)
    {
        InputFault fault;
        fault.kind = FaultKind::LineTooShort;
        fault.line = 5;
        fault.observedLength = 7;

        const std::string message = cli::messages::inputFault(fault);
        Assert::IsTrue(contains(message, "5"), L"the diagnostic must name line 5");
        Assert::IsTrue(contains(message, "7"), L"the diagnostic must name the length 7");
    }

    // docs/RTVM.md 7 I-13 / docs/SDD.md 2.5: the over-cap sentinel is
    // rendered as "more than 4096 characters", and the raw sentinel number
    // (4097) must never appear.
    TEST_METHOD(rtvm102_overCapLengthRendersAsMoreThanTheCapNotTheSentinel)
    {
        InputFault fault;
        fault.kind = FaultKind::LineTooLong;
        fault.line = 1;
        fault.observedLength = kLengthExceedsCap;

        const std::string message = cli::messages::inputFault(fault);
        Assert::IsTrue(contains(message, "more than 4096"),
            L"an over-cap line must render as \"more than 4096 characters\"");
        Assert::IsFalse(contains(message, std::to_string(kLengthExceedsCap)),
            L"the raw sentinel value must never be printed as a number");
    }

    // TP-103: names both the offending character and its cell.
    TEST_METHOD(rtvm103_illegalCharacterDiagnosticNamesTheCharacterAndCell)
    {
        InputFault fault;
        fault.kind = FaultKind::IllegalCharacter;
        fault.line = 1;
        fault.character = 'X';
        fault.first = CellRef{ 1, 1 };

        const std::string message = cli::messages::inputFault(fault);
        Assert::IsTrue(contains(message, "X"), L"the diagnostic must name the character X");
        Assert::IsTrue(contains(message, "r1c1"), L"the diagnostic must name r1c1");
    }

    // docs/RTVM.md 7 I-15's own negative case: an interior space is still
    // nameable in the diagnostic even though it prints as a blank.
    TEST_METHOD(rtvm103_illegalCharacterDiagnosticNamesASpaceAtItsCell)
    {
        InputFault fault;
        fault.kind = FaultKind::IllegalCharacter;
        fault.line = 3;
        fault.character = ' ';
        fault.first = CellRef{ 3, 4 };

        const std::string message = cli::messages::inputFault(fault);
        Assert::IsTrue(contains(message, "r3c4"), L"the diagnostic must name r3c4");
        Assert::IsTrue(contains(message, "' '"),
            L"the space itself must appear quoted so it is visible in the text");
    }

    // TP-104: a duplicate diagnostic names the digit, the unit, and both cells.
    TEST_METHOD(rtvm104_rowDuplicateDiagnosticNamesDigitUnitAndBothCells)
    {
        InputFault fault;
        fault.kind   = FaultKind::RowDuplicate;
        fault.digit  = 5;
        fault.first  = CellRef{ 1, 1 };
        fault.second = CellRef{ 1, 7 };

        const std::string message = cli::messages::inputFault(fault);
        Assert::IsTrue(contains(message, "5"), L"the diagnostic must name digit 5");
        Assert::IsTrue(contains(message, "row"), L"the diagnostic must name the unit kind");
        Assert::IsTrue(contains(message, "r1c1") && contains(message, "r1c7"),
            L"the diagnostic must name both conflicting cells");
    }

    TEST_METHOD(rtvm104_columnDuplicateDiagnosticNamesDigitUnitAndBothCells)
    {
        InputFault fault;
        fault.kind   = FaultKind::ColumnDuplicate;
        fault.digit  = 4;
        fault.first  = CellRef{ 1, 1 };
        fault.second = CellRef{ 5, 1 };

        const std::string message = cli::messages::inputFault(fault);
        Assert::IsTrue(contains(message, "4"), L"the diagnostic must name digit 4");
        Assert::IsTrue(contains(message, "column"), L"the diagnostic must name the unit kind");
        Assert::IsTrue(contains(message, "r1c1") && contains(message, "r5c1"),
            L"the diagnostic must name both conflicting cells");
    }

    TEST_METHOD(rtvm104_boxDuplicateDiagnosticNamesDigitUnitAndBothCells)
    {
        InputFault fault;
        fault.kind   = FaultKind::BoxDuplicate;
        fault.digit  = 8;
        fault.first  = CellRef{ 1, 2 };
        fault.second = CellRef{ 3, 3 };

        const std::string message = cli::messages::inputFault(fault);
        Assert::IsTrue(contains(message, "8"), L"the diagnostic must name digit 8");
        Assert::IsTrue(contains(message, "box"), L"the diagnostic must name the unit kind");
        Assert::IsTrue(contains(message, "r1c2") && contains(message, "r3c3"),
            L"the diagnostic must name both conflicting cells");
    }

    // RTVM-009 / docs/RTVM.md 7 I-18: names the path and states it could not
    // be opened, without pinning the errno-derived reason text.
    TEST_METHOD(rtvm009_sourceUnreadableDiagnosticNamesThePathAndTheReason)
    {
        InputFault fault;
        fault.kind        = FaultKind::SourceUnreadable;
        fault.path        = "does_not_exist.txt";
        fault.systemError = 2;   // ENOENT on every supported platform

        const std::string message = cli::messages::inputFault(fault);
        Assert::IsTrue(contains(message, "does_not_exist.txt"),
            L"the diagnostic must name the path");
        Assert::IsTrue(contains(message, "open"),
            L"the diagnostic must state the file could not be opened");
        Assert::IsFalse(message.empty());
    }

    // A zero systemError (never produced by the console layer today, but not
    // ruled out by the type) must not crash strerror's underlying call.
    TEST_METHOD(rtvm009_sourceUnreadableDiagnosticToleratesAnUnknownReason)
    {
        InputFault fault;
        fault.kind        = FaultKind::SourceUnreadable;
        fault.path        = "x.txt";
        fault.systemError = 0;

        const std::string message = cli::messages::inputFault(fault);
        Assert::IsTrue(contains(message, "x.txt"));
    }
};

} // namespace sudoku::test
