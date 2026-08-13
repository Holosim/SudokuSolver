// InputFaultTests.cpp — the structured input fault (RTVM-302).
//
// Procedure: docs/RTVM.md TP-302.
//
// TP-302 is written as "parse P-CONTRA-ROW and inspect the returned fault
// object". Contradiction detection is RTVM-104 (#10) and is not implemented
// yet, so the parse-driven half is not runnable here; when it lands, the
// expected fault is exactly the one built in rtvm302_rowDuplicateFault... below
// and that test grows a parseGrid call rather than new expectations.
//
// The half that is testable now is the one the requirement is actually about:
// the fault is *data* — kind, line, cells, digit, character — and carries no
// pre-formatted English sentence, so that every user-visible word lives in
// Messages (docs/SDD.md 2.5, 2.7). That is a property of the type.

#include "CppUnitTest.h"

#include <string>
#include <type_traits>

#include "Grid.h"
#include "InputFault.h"

using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace sudoku::test {

TEST_CLASS(InputFaultTests)
{
public:
    // RTVM-302: the expected fault for P-CONTRA-ROW (docs/RTVM.md 6.1) —
    // digit 5 twice in row 1, at r1c1 and r1c7 — expressed entirely as data.
    // Every field TP-302 names is present and separately inspectable.
    TEST_METHOD(rtvm302_rowDuplicateFaultCarriesKindDigitAndBothCells)
    {
        InputFault fault;
        fault.kind   = FaultKind::RowDuplicate;
        fault.line   = 1;
        fault.digit  = 5;
        fault.first  = cellRefFromZeroBased(0, 0);
        fault.second = cellRefFromZeroBased(0, 6);

        Assert::IsTrue(fault.kind == FaultKind::RowDuplicate,
            L"the kind distinguishes a row duplicate from a column or box one");
        Assert::AreEqual(5, fault.digit, L"the duplicated digit is data, not text");
        Assert::AreEqual(1, fault.line);
        Assert::IsTrue(fault.first == CellRef{ 1, 1 }, L"first cell is r1c1");
        Assert::IsTrue(fault.second == CellRef{ 1, 7 }, L"second cell is r1c7");
        Assert::IsTrue(fault.first.isApplicable() && fault.second.isApplicable(),
            L"a duplicate names both of its cells");
    }

    // RTVM-302: no pre-formatted message anywhere in the object. The
    // decomposition below is the assertion — it names every member the type
    // has, so adding a `message` or `description` field breaks this test at
    // compile time rather than letting wording leak out of Messages.
    TEST_METHOD(rtvm302_faultCarriesNoPreFormattedMessage)
    {
        static_assert(std::is_aggregate_v<InputFault>,
            "InputFault is a plain data record (docs/SDD.md 2.5)");

        InputFault fault;
        fault.kind      = FaultKind::IllegalCharacter;
        fault.line      = 3;
        fault.character = 'X';
        fault.first     = cellRefFromZeroBased(2, 3);

        const auto& [kind, line, observedLength, character, digit,
                     first, second, path, systemError] = fault;

        // Every member is a code, a count, a coordinate or a single character.
        static_assert(std::is_enum_v<std::decay_t<decltype(kind)>>);
        static_assert(std::is_integral_v<std::decay_t<decltype(line)>>);
        static_assert(std::is_integral_v<std::decay_t<decltype(observedLength)>>);
        static_assert(std::is_same_v<std::decay_t<decltype(character)>, char>);
        static_assert(std::is_integral_v<std::decay_t<decltype(digit)>>);
        static_assert(std::is_same_v<std::decay_t<decltype(first)>, CellRef>);
        static_assert(std::is_same_v<std::decay_t<decltype(second)>, CellRef>);
        static_assert(std::is_integral_v<std::decay_t<decltype(systemError)>>);

        // The one string is a filesystem path, populated only for the
        // SourceUnreadable case the console layer constructs (RTVM-009).
        static_assert(std::is_same_v<std::decay_t<decltype(path)>, std::string>);
        Assert::IsTrue(path.empty(),
            L"a parser-produced fault carries no string at all");

        Assert::IsTrue(kind == FaultKind::IllegalCharacter);
        Assert::AreEqual(3, line);
        Assert::AreEqual(0, observedLength, L"a field this kind does not use stays 0");
        Assert::IsTrue(character == 'X', L"the offending byte is carried as a byte");
        Assert::AreEqual(0, digit, L"a field this kind does not use stays 0");
        Assert::IsTrue(first == CellRef{ 3, 4 });
        Assert::IsFalse(second.isApplicable(),
            L"an illegal character names one cell, not two");
        Assert::IsTrue(systemError == 0u);
    }

    // RTVM-302 / docs/SDD.md 2.3: cell references in a fault are 1-based, and
    // the 0-based-to-1-based step happens in exactly one function. An
    // off-by-one here fails TP-103, TP-104 and TP-302 together.
    TEST_METHOD(rtvm302_cellReferencesAreOneBasedThroughASingleConversion)
    {
        Assert::IsTrue(cellRefFromZeroBased(0, 0) == CellRef{ 1, 1 },
            L"the top-left cell is r1c1");
        Assert::IsTrue(cellRefFromZeroBased(0, 6) == CellRef{ 1, 7 },
            L"column 6 zero-based is c7");
        Assert::IsTrue(cellRefFromZeroBased(kGridSize - 1, kGridSize - 1)
                == CellRef{ kGridSize, kGridSize },
            L"the last cell is r<kGridSize>c<kGridSize>, not one past it");
    }

    // RTVM-505: a coordinate outside the grid must not become a nonsense cell
    // name in a diagnostic. It becomes "not applicable" instead.
    TEST_METHOD(rtvm302_anOutOfRangeCoordinateIsNotApplicableRatherThanWrong)
    {
        Assert::IsFalse(cellRefFromZeroBased(-1, 0).isApplicable());
        Assert::IsFalse(cellRefFromZeroBased(0, kGridSize).isApplicable());
        Assert::IsTrue(cellRefFromZeroBased(kGridSize, 0) == CellRef{},
            L"out of range yields the default, not a wrapped coordinate");
    }

    // RTVM-302: fault kinds that name no cell say so, rather than leaving the
    // output layer to guess from a zero. Shape faults carry a line and a
    // length; SourceUnreadable carries a path and a system code.
    TEST_METHOD(rtvm302_faultKindsCarryOnlyTheFieldsTheyApplyTo)
    {
        InputFault shape;
        shape.kind           = FaultKind::LineTooLong;
        shape.line           = 5;
        shape.observedLength = 11;

        Assert::IsFalse(shape.first.isApplicable(),
            L"a shape fault names a line, not a cell");
        Assert::AreEqual(11, shape.observedLength);

        InputFault unreadable;
        unreadable.kind        = FaultKind::SourceUnreadable;
        unreadable.path        = "missing.txt";
        unreadable.systemError = 2u;

        Assert::IsFalse(unreadable.first.isApplicable());
        Assert::AreEqual(0, unreadable.line, L"an unopened file has no line number");
        Assert::AreEqual(std::string("missing.txt"), unreadable.path,
            L"the path is echoed as data; the sentence around it is Messages' job");
        Assert::IsTrue(unreadable.systemError == 2u);
    }
};

} // namespace sudoku::test
