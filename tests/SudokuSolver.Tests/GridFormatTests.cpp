// GridFormatTests.cpp — TP-400, the normative 13-line rendering.
//
// docs/RTVM.md TP-400, 6.2. RTVM-400.
//
// TP-400 is written as a process capture ("run P-EASY, expect stdout to
// equal…"), but formatGrid is a pure function of a Grid (docs/SDD.md 2.6), so
// every assertion the procedure makes can be made here as well — byte
// equality, the line count, the separator lines, the 25-character width, the
// row shape and the ASCII-only property. Running it at this level is what
// makes a format regression a failing unit test in Test Explorer rather than
// a diff in a captured stream.
//
// The end-to-end half of TP-400 (that this text is what actually reaches
// stdout, and nothing else does) remains a process-level procedure.

#include "CppUnitTest.h"

#include <cstddef>
#include <string>
#include <string_view>
#include <vector>

#include "Grid.h"
#include "GridFormat.h"
#include "TestFixtures.h"

using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace sudoku::test {

namespace {

// Splits on '\n' and drops the empty element after the final terminator, so
// "13 lines" counts lines the way TP-400 does.
[[nodiscard]] std::vector<std::string> splitTerminatedLines(std::string_view text)
{
    std::vector<std::string> lines;
    std::size_t start = 0;

    while (start < text.size()) {
        const std::size_t newline = text.find('\n', start);
        if (newline == std::string_view::npos) {
            lines.emplace_back(text.substr(start));
            break;
        }
        lines.emplace_back(text.substr(start, newline - start));
        start = newline + 1;
    }

    return lines;
}

// `| d d d | d d d | d d d |` — the shape of TP-400's regex, spelled out so
// the test needs no <regex> and says which character disagreed.
[[nodiscard]] bool isRowLine(const std::string& line)
{
    const std::size_t width = 1 + static_cast<std::size_t>(kBoxSize)
        * (2 * static_cast<std::size_t>(kBoxSize) + 2);
    if (line.size() != width) {
        return false;
    }

    // `| 5 3 4 |` — a wall every (2 * kBoxSize + 2) characters, a digit at
    // every other even position, a space at every odd position.
    for (std::size_t index = 0; index < line.size(); ++index) {
        const char c = line[index];
        const bool isWallPosition = index % (2 * static_cast<std::size_t>(kBoxSize) + 2) == 0;
        const bool isDigitPosition = index % 2 == 0;

        if (isWallPosition) {
            if (c != '|') {
                return false;
            }
        } else if (isDigitPosition) {
            if (c < '1' || c > static_cast<char>('0' + kGridSize)) {
                return false;
            }
        } else if (c != ' ') {
            return false;
        }
    }

    return true;
}

} // namespace

TEST_CLASS(GridFormatTests)
{
public:
    // RTVM-400: the whole of the format, byte for byte against docs/RTVM.md
    // 6.2. Every other test in this class is a narrower restatement of this
    // one — kept because a single byte-equality failure says "the format
    // changed" without saying what changed.
    TEST_METHOD(rtvm400_solvedGridRendersTheNormativeBlockByteForByte)
    {
        const Grid solved = gridFromCompactForm(kSolvedEasy);
        const std::string actual = formatGrid(solved);

        Assert::AreEqual(std::string{ kSolvedEasyFormatted }, actual,
            L"formatGrid must equal docs/RTVM.md 6.2 for S-EASY, byte for byte");
    }

    // TP-400: 13 lines, and lines 1, 5, 9, 13 are exactly the separator.
    TEST_METHOD(rtvm400_blockIsThirteenLinesWithFourSeparators)
    {
        const std::vector<std::string> lines =
            splitTerminatedLines(formatGrid(gridFromCompactForm(kSolvedEasy)));

        Assert::AreEqual(static_cast<std::size_t>(kGridSize + kBoxSize + 1), lines.size(),
            L"a kBoxSize=3 grid renders as 13 lines");

        for (std::size_t index = 0; index < lines.size(); ++index) {
            const bool separatorPosition =
                index % (static_cast<std::size_t>(kBoxSize) + 1) == 0;
            if (separatorPosition) {
                Assert::AreEqual(std::string{ kFormatSeparatorLine }, lines[index],
                    L"lines 1, 5, 9 and 13 are exactly the box separator");
            } else {
                Assert::IsTrue(isRowLine(lines[index]),
                    L"every other line is 25 characters of | and digits");
            }
        }
    }

    // TP-400: pure ASCII, nothing above U+007F. Box-drawing characters would
    // render as mojibake under a non-UTF-8 console code page (6.2).
    TEST_METHOD(rtvm400_outputIsPureAscii)
    {
        const std::string actual = formatGrid(gridFromCompactForm(kSolvedEasy));

        for (const char c : actual) {
            Assert::IsTrue(static_cast<unsigned char>(c) <= 0x7Fu,
                L"no byte above U+007F may appear in the rendered grid");
        }
    }

    // The block is a complete unit of output: the last line carries its
    // terminator too, so a caller writes the string and adds nothing.
    TEST_METHOD(rtvm400_everyLineIncludingTheLastIsTerminated)
    {
        const std::string actual = formatGrid(gridFromCompactForm(kSolvedEasy));

        Assert::IsFalse(actual.empty());
        Assert::AreEqual('\n', actual.back(),
            L"the closing separator is terminated like every other line");
    }

    // RTVM-400 renders the grid it is given, not a remembered one: a second
    // solved grid must produce its own block. S-HARD17 is the independent
    // fixture, and the check is the round trip through toCompactString — the
    // digits in the rendering are the digits in the grid, in order.
    TEST_METHOD(rtvm400_renderingCarriesTheDigitsOfTheGridItIsGiven)
    {
        const Grid solved = gridFromCompactForm(kSolvedHard17);
        const std::string rendered = formatGrid(solved);

        std::string digits;
        for (const char c : rendered) {
            if (c >= '1' && c <= static_cast<char>('0' + kGridSize)) {
                digits.push_back(c);
            }
        }

        Assert::AreEqual(std::string{ kSolvedHard17 }, digits,
            L"the rendered digits are the grid's cells in row-major order");
        Assert::AreEqual(toCompactString(solved), digits,
            L"formatGrid and toCompactString must agree on the same grid");
    }

    // RTVM-505: a grid that is not solved still renders as a well-formed
    // block rather than as garbage. RTVM-400 never asks for this — an empty
    // cell shows as the `.` RTVM-101 accepts on input — but "no input
    // produces a malformed output" is a property of the whole program.
    TEST_METHOD(rtvm400_partialGridStillRendersAWellFormedBlock)
    {
        const std::vector<std::string> lines =
            splitTerminatedLines(formatGrid(gridFromCompactForm(kPuzzleEasy)));

        Assert::AreEqual(static_cast<std::size_t>(kGridSize + kBoxSize + 1), lines.size());
        for (const std::string& line : lines) {
            Assert::AreEqual(std::string{ kFormatSeparatorLine }.size(), line.size(),
                L"an unsolved grid renders at the same width as a solved one");
        }
    }
};

} // namespace sudoku::test
