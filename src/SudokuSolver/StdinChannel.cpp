// StdinChannel.cpp — see StdinChannel.h.
//
// SCAFFOLD ONLY. Handle-type detection and the four non-blocking read
// paths of docs/SDD.md 1.3 are implemented under their own issue. Until
// then the channel behaves exactly as the Null kind does: never available,
// never read. That is the one placeholder that cannot violate RTVM-006 or
// RTVM-008 by accident.
//
// TODO(RTVM-003, RTVM-006, RTVM-008): GetFileType dispatch;
//      GetNumberOfConsoleInputEvents + PeekConsoleInput + ReadConsoleA for
//      the console case; PeekNamedPipe + bounded ReadFile for the pipe
//      case; ReadFile with EOF latching for the file case.
//
// Whatever lands here, it must never call anything that can block:
// std::getline(std::cin, ...), a bare ReadFile on a console handle, and
// std::cin >> are all out, permanently.

#include "StdinChannel.h"

namespace sudoku::cli {

StdinChannel::StdinChannel() = default;

StdinKind StdinChannel::kind() const
{
    return m_kind;
}

bool StdinChannel::isClosed() const
{
    return m_closed;
}

bool StdinChannel::tryReadLine(std::string& line)
{
    static_cast<void>(line);
    return false;
}

} // namespace sudoku::cli
