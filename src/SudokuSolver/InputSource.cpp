// InputSource.cpp — see InputSource.h.
//
// SCAFFOLD ONLY.
//
// TODO(RTVM-002, RTVM-003, RTVM-009): open the file (or pull the first
//      kGridSize logical lines from the stdin channel), bound the read per
//      docs/RTVM.md 7 I-13, and populate a SourceUnreadable fault with the
//      path and GetLastError on failure.

#include "InputSource.h"

namespace sudoku::cli {

InputSource::InputSource(StdinChannel& stdinChannel)
    : m_stdin(stdinChannel)
{
}

ReadResult InputSource::readPuzzleText(std::string_view path)
{
    static_cast<void>(path);
    return ReadResult{};
}

} // namespace sudoku::cli
