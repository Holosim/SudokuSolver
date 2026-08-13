// ParserTests.cpp — malformed-input detection and fault precedence.
//
// Procedures: docs/RTVM.md TP-102, TP-103, TP-104, TP-105 (TP-106's own
// cases, positive and negative, are RTVM-106's and are verified elsewhere;
// this file only reuses P-EASY-with-one-line-replaced shapes for the three
// validation stages RTVM-105 orders).
//
// RTVM-105 fixes one precedence — shape -> illegal character -> contradiction
// — and says a rejected puzzle never reaches the solver. At this unit level
// "never reaches the solver" is not asserted by instrumentation; it is true
// by construction, because no test method below calls solve() at all. A
// fault is inspected directly off the ParseResult returned by parseGrid.

#include "CppUnitTest.h"

#include "InputFault.h"
#include "Parser.h"
#include "TestFixtures.h"

using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace sudoku::test {

TEST_CLASS(ParserTests)
{
public:
    // TP-102 case 1: fewer than kGridSize lines names the first line that
    // never arrived.
    TEST_METHOD(rtvm102_missingLineNamesTheFirstLineThatNeverArrived)
    {
        const ParseResult result = parseGrid(kInputShort);

        Assert::IsFalse(result.ok());
        Assert::IsTrue(result.fault().kind == FaultKind::MissingLine);
        Assert::AreEqual(9, result.fault().line,
            L"P-SHORT has 8 lines, so line 9 is the one reported missing");
    }

    // TP-102 case 2: a line longer than kGridSize characters names the line
    // and its exact observed length.
    TEST_METHOD(rtvm102_lineTooLongNamesTheLineAndItsLength)
    {
        const ParseResult result = parseGrid(kInputLongLine);

        Assert::IsFalse(result.ok());
        Assert::IsTrue(result.fault().kind == FaultKind::LineTooLong);
        Assert::AreEqual(5, result.fault().line);
        Assert::AreEqual(11, result.fault().observedLength);
    }

    // TP-102 case 3: a line shorter than kGridSize characters, symmetric
    // with the case above.
    TEST_METHOD(rtvm102_lineTooShortNamesTheLineAndItsLength)
    {
        const ParseResult result = parseGrid(kInputShortLine);

        Assert::IsFalse(result.ok());
        Assert::IsTrue(result.fault().kind == FaultKind::LineTooShort);
        Assert::AreEqual(5, result.fault().line);
        Assert::AreEqual(7, result.fault().observedLength);
    }

    // docs/RTVM.md 7 I-13: a line that runs past kMaxLineBytes with no
    // terminator in sight is reported as LineTooLong with the sentinel
    // length, not the (unknown) exact byte count.
    TEST_METHOD(rtvm102_lineOverTheCapReportsTheSentinelNotAGuess)
    {
        const std::string oversizedLine(static_cast<std::size_t>(kMaxLineBytes) + 1, '1');
        const std::string text = oversizedLine + "\n"
            "600195000\n098000060\n800060003\n400803001\n"
            "700020006\n060000280\n000419005\n000080079\n";

        const ParseResult result = parseGrid(text);

        Assert::IsFalse(result.ok());
        Assert::IsTrue(result.fault().kind == FaultKind::LineTooLong);
        Assert::AreEqual(1, result.fault().line);
        Assert::AreEqual(kLengthExceedsCap, result.fault().observedLength);
    }

    // TP-103: a character outside {0-9, .} names itself and its cell.
    TEST_METHOD(rtvm103_illegalCharacterNamesTheCharacterAndItsCell)
    {
        const ParseResult result = parseGrid(kInputBadChar);

        Assert::IsFalse(result.ok());
        Assert::IsTrue(result.fault().kind == FaultKind::IllegalCharacter);
        Assert::IsTrue(result.fault().character == 'X');
        Assert::IsTrue(result.fault().first == CellRef{ 1, 1 });
    }

    // TP-104 case 1 / TP-302's parse-driven half: a row duplicate names the
    // digit and both cells, first the earlier one, then the later one in
    // reading order.
    TEST_METHOD(rtvm104_rowDuplicateNamesTheDigitAndBothCells)
    {
        const ParseResult result = parseGrid(kInputContraRow);

        Assert::IsFalse(result.ok());
        const InputFault& fault = result.fault();
        Assert::IsTrue(fault.kind == FaultKind::RowDuplicate);
        Assert::AreEqual(5, fault.digit);
        Assert::IsTrue(fault.first == CellRef{ 1, 1 });
        Assert::IsTrue(fault.second == CellRef{ 1, 7 });
    }

    // TP-104 case 2: a column duplicate, symmetric with the row case.
    TEST_METHOD(rtvm104_columnDuplicateNamesTheDigitAndBothCells)
    {
        const ParseResult result = parseGrid(kInputContraCol);

        Assert::IsFalse(result.ok());
        const InputFault& fault = result.fault();
        Assert::IsTrue(fault.kind == FaultKind::ColumnDuplicate);
        Assert::AreEqual(4, fault.digit);
        Assert::IsTrue(fault.first == CellRef{ 1, 1 });
        Assert::IsTrue(fault.second == CellRef{ 5, 1 });
    }

    // TP-104 case 3: a box duplicate. r1c2 and r3c3 are both in the
    // top-left box, and neither shares a row or a column with the other, so
    // this is the case that proves the box check runs at all.
    TEST_METHOD(rtvm104_boxDuplicateNamesTheDigitAndBothCells)
    {
        const ParseResult result = parseGrid(kInputContraBox);

        Assert::IsFalse(result.ok());
        const InputFault& fault = result.fault();
        Assert::IsTrue(fault.kind == FaultKind::BoxDuplicate);
        Assert::AreEqual(8, fault.digit);
        Assert::IsTrue(fault.first == CellRef{ 1, 2 });
        Assert::IsTrue(fault.second == CellRef{ 3, 3 });
    }

    // RTVM-201's control case, restated here: P-UNSOLVABLE-shaped givens
    // (mutually consistent, no repeat) must not be rejected by RTVM-104 —
    // only P-EASY itself is needed to prove "well-formed givens parse", so
    // this reuses it rather than adding a fixture RTVM-201 (#11) already
    // owns.
    TEST_METHOD(rtvm104_mutuallyConsistentGivensAreNotRejected)
    {
        const ParseResult result = parseGrid(
            "530070000\n600195000\n098000060\n800060003\n400803001\n"
            "700020006\n060000280\n000419005\n000080079\n");

        Assert::IsTrue(result.ok(),
            L"P-EASY's givens contain no row, column or box repeat");
    }

    // TP-105, first case: P-MULTIFAULT carries all three fault kinds at
    // once (8 lines; an X at r1c1; digit 3 twice in row 1). Only the shape
    // fault is reported.
    TEST_METHOD(rtvm105_shapeFaultOutranksCharacterAndContradictionFaults)
    {
        const ParseResult result = parseGrid(kInputMultiFault);

        Assert::IsFalse(result.ok());
        Assert::IsTrue(result.fault().kind == FaultKind::MissingLine,
            L"the missing 9th line must be reported ahead of the illegal "
            L"character or the row duplicate elsewhere in the input");
        Assert::AreEqual(9, result.fault().line);
    }

    // TP-105, second case: the same line 1 with all 9 lines present. The
    // shape is now clean, so the illegal character must win over the row
    // duplicate that would otherwise be found two cells later.
    TEST_METHOD(rtvm105_characterFaultOutranksContradictionFault)
    {
        const ParseResult result = parseGrid(kInputMultiFault9);

        Assert::IsFalse(result.ok());
        Assert::IsTrue(result.fault().kind == FaultKind::IllegalCharacter,
            L"the X at r1c1 must be reported, not the row-1 digit-3 repeat "
            L"at r1c2/r1c7");
        Assert::IsTrue(result.fault().first == CellRef{ 1, 1 });
    }

    // TP-105's narrowness confirmation: the §7 I-15 whitespace exception
    // must not have widened precedence anywhere else. A plain over-length
    // line (no whitespace involved) still reports LineTooLong on its own
    // line, and a missing-line input still reports the missing line even
    // though it also contains an illegal character.
    TEST_METHOD(rtvm105_theWhitespaceExceptionDidNotWidenOrdinaryPrecedence)
    {
        const ParseResult tooLong = parseGrid(kInputLongLine);
        Assert::IsTrue(tooLong.fault().kind == FaultKind::LineTooLong,
            L"an 11-character line with no whitespace is still LineTooLong");

        const ParseResult missing = parseGrid(kInputMultiFault);
        Assert::IsTrue(missing.fault().kind == FaultKind::MissingLine,
            L"a shape fault elsewhere in the input still outranks the "
            L"character fault on line 1");
    }
};

} // namespace sudoku::test
