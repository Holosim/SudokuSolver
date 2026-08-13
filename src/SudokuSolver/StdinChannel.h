// StdinChannel.h — the single owner of the standard input byte stream.
//
// docs/SDD.md 1.3, 2.7. RTVM-003, RTVM-006, RTVM-008.
//
// Two rules this type exists to enforce:
//
//  1. Nothing here ever blocks. There is no single Win32 call that
//     non-blockingly tests any standard-input handle for available data, so
//     the handle kind is established once at startup from GetFileType and
//     dispatched on thereafter.
//  2. There is exactly one reader of the stdin byte stream. The puzzle
//     reader pulls its lines from this channel and the poll loop continues
//     from the same buffer afterwards. std::cin is never used in either
//     role -- two readers with independent buffering over one handle is the
//     classic way to lose bytes to a look-ahead.

#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

namespace sudoku::cli {

enum class StdinKind : std::uint8_t {
    Console,   // FILE_TYPE_CHAR and GetConsoleMode succeeds
    Pipe,      // FILE_TYPE_PIPE
    File,      // FILE_TYPE_DISK
    Null       // anything else, an invalid handle, or NUL:
};

class StdinChannel {
public:
    // Detects the handle kind once. Does not read.
    StdinChannel();

    StdinChannel(const StdinChannel&) = delete;
    StdinChannel& operator=(const StdinChannel&) = delete;

    [[nodiscard]] StdinKind kind() const;

    // True once end of input has been seen. Latched: a closed channel
    // issues no further reads, ever.
    [[nodiscard]] bool isClosed() const;

    // Non-blocking. Assigns one complete line (without its terminator) and
    // returns true, or returns false immediately when no complete line is
    // available right now. Never waits, on any handle kind.
    [[nodiscard]] bool tryReadLine(std::string& line);

    // Waits for one line. This is the puzzle-acquisition read of RTVM-003 and
    // it is the *only* read in the program that is allowed to wait, because
    // it happens before the solve starts and therefore before any prompt
    // exists: RTVM-006 and RTVM-008 constrain the prompt mechanism, and
    // reading a puzzle a user is still typing cannot be done without waiting
    // for it. Calling this once the solve is under way would break both, so
    // the solve path uses tryReadLine and nothing else.
    //
    // Assigns one line without its terminator and returns true; returns false
    // when the channel is closed and no bytes remain. At most 'maxBytes' are
    // buffered while looking for a terminator — a longer line is delivered
    // truncated to that length, which is enough for the caller to see it is
    // malformed without buffering the rest (docs/RTVM.md 7 I-13).
    //
    // Bytes read past the line are kept, so the control channel continues
    // from the same buffer afterwards (docs/SDD.md 1.3).
    [[nodiscard]] bool readLineBlocking(std::string& line, std::size_t maxBytes);

private:
    void*      m_handle = nullptr;      // HANDLE, kept opaque to callers
    StdinKind  m_kind   = StdinKind::Null;
    bool       m_closed = false;
    std::string m_buffer;               // bytes seen but not yet consumed
};

} // namespace sudoku::cli
