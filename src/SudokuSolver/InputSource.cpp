// InputSource.cpp — see InputSource.h.
//
// docs/SDD.md 2.7, 2.9. RTVM-002, RTVM-003, docs/RTVM.md 7 I-2, I-13.
//
// Two sources, one shape of read. Whether the text comes from a file or from
// the stdin channel, the reader stops the moment it has kGridSize logical
// lines and never scans a single line past kMaxLineBytes. That bound is the
// whole of the answer to TP-505's 1 MB single line and 10 000-line cases:
// both are shape faults reported promptly rather than a megabyte buffered to
// reach the same answer.
//
// The reader deliberately does not classify the text. It hands whatever it
// found to parseGrid, which owns every judgement about line endings,
// whitespace and characters (RTVM-106). "Nine lines or fewer, capped" is a
// bound, not a validation.

#include "InputSource.h"

#include <cerrno>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <string>

#include "Grid.h"
#include "Parser.h"

namespace sudoku::cli {

namespace {

// One byte more than the cap is what lets the parser tell "exactly at the
// cap" from "ran past it" (docs/RTVM.md 7 I-13, Parser.h kLengthExceedsCap).
inline constexpr std::size_t kLineReadLimit = static_cast<std::size_t>(kMaxLineBytes) + 1;

// Bytes pulled from a file per read.
inline constexpr std::size_t kFileChunkBytes = 1024;

// Accumulates puzzle text under the two bounds above. Fed a byte at a time
// from whichever source is in play; says when there is no reason to read on.
class BoundedText {
public:
    // False once kGridSize complete lines have been seen, or once a single
    // line has run past the cap — in both cases nothing further can change
    // the parse, so the caller stops reading (RTVM 7 I-2, I-13).
    [[nodiscard]] bool wantsMore() const
    {
        return m_lines < kGridSize && m_currentLineBytes <= kLineReadLimit;
    }

    void append(char byte)
    {
        m_text.push_back(byte);
        if (byte == '\n') {
            ++m_lines;
            m_currentLineBytes = 0;
        } else {
            ++m_currentLineBytes;
        }
    }

    [[nodiscard]] std::string release() { return std::move(m_text); }

private:
    std::string m_text;
    int         m_lines = 0;
    std::size_t m_currentLineBytes = 0;
};

[[nodiscard]] InputFault unreadable(std::string_view path, std::uint32_t systemError)
{
    InputFault fault{};
    fault.kind = FaultKind::SourceUnreadable;
    fault.path = std::string{ path };
    fault.systemError = systemError;
    return fault;
}

} // namespace

InputSource::InputSource(StdinChannel& stdinChannel)
    : m_stdin(stdinChannel)
{
}

ReadResult InputSource::readPuzzleText(std::string_view path)
{
    ReadResult result{};

    if (path.empty()) {
        // RTVM-003: no argument, so the puzzle comes from standard input —
        // through the one owner of that byte stream, never std::cin
        // (docs/SDD.md 1.3).
        BoundedText text;
        std::string line;
        while (text.wantsMore() && m_stdin.readLineBlocking(line, kLineReadLimit)) {
            for (const char byte : line) {
                text.append(byte);
            }
            // The channel strips the terminator; the parser wants it back.
            // Re-adding it for a final unterminated line is harmless — a
            // trailing newline is optional (RTVM-106).
            text.append('\n');

            if (line.size() >= kLineReadLimit) {
                // The channel truncated this line at the cap, so it carried no
                // terminator of its own. Nothing further can change the parse:
                // stop rather than read the rest of a line already known to be
                // malformed (docs/RTVM.md 7 I-13).
                break;
            }
        }
        result.text = text.release();
        return result;
    }

    // RTVM-002: the first argument is a path, and the file wins over anything
    // on stdin — stdin is simply never read on this path.
    //
    // Opened in binary: the bytes the parser sees must be the bytes on disk,
    // so that a CR is data the parser decides about (RTVM-106) rather than
    // something the CRT silently removed.
    const std::string pathText{ path };
    std::ifstream file(pathText, std::ios::binary);
    if (!file.is_open()) {
        // RTVM-009 owns the wording and the exit code (issue #10); all that
        // is recorded here is the structured fact (RTVM-302).
        result.fault = unreadable(path, static_cast<std::uint32_t>(errno));
        return result;
    }

    BoundedText text;
    char chunk[kFileChunkBytes];
    while (text.wantsMore()
           && file.read(chunk, static_cast<std::streamsize>(sizeof chunk)).gcount() > 0) {
        const std::size_t got = static_cast<std::size_t>(file.gcount());
        for (std::size_t index = 0; index < got && text.wantsMore(); ++index) {
            text.append(chunk[index]);
        }
    }

    if (file.bad()) {
        // Opened but could not be read — a directory on POSIX, a device that
        // failed mid-read. Same fault as a failed open (RTVM-009, 7 I-9).
        result.fault = unreadable(path, static_cast<std::uint32_t>(errno));
        return result;
    }

    result.text = text.release();
    return result;
}

} // namespace sudoku::cli
