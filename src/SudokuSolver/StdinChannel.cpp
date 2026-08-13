// StdinChannel.cpp — see StdinChannel.h.
//
// docs/SDD.md 1.3, 2.7. RTVM-003, RTVM-006, RTVM-008.
//
// What is implemented here: handle acquisition, the GetFileType dispatch of
// docs/SDD.md 1.3, the shared byte buffer, EOF latching, and the *waiting*
// read that acquires the puzzle before the solve starts (RTVM-003).
//
// What is deliberately still a stub: tryReadLine only ever hands back a line
// that is already in the buffer. The four non-blocking availability tests
// (GetNumberOfConsoleInputEvents + PeekConsoleInput, PeekNamedPipe, the disk
// case) belong to [RTVM-004] (#17) together with the prompt and the abort.
// Until they land, the poll path reports "nothing available", which cannot
// violate RTVM-006 or RTVM-008 by accident.
//
// TODO(RTVM-006, RTVM-008, issue #17): the availability tests, so that
//      tryReadLine can pull bytes that arrived after the puzzle was read.
//
// Whatever lands there, it must never call anything that can block from
// inside the solve: std::getline(std::cin, ...), a bare ReadFile on a
// console handle, and std::cin >> are all out, permanently. readLineBlocking
// below is not an exception to that rule — it runs before the solve exists.
//
// PLATFORM. The delivered build is the _WIN32 branch; that is the only one
// SudokuSolver.vcxproj ever compiles (RTVM-906). The POSIX branch exists so
// the console layer can be built and exercised end to end on the pipeline's
// Linux agents, which have no MSVC (docs/RTVM.md 9.1). It ships no behaviour
// to the client and is confined to this file's seam functions.

#include "StdinChannel.h"

#include <cstdint>

#if defined(_WIN32)
    // WIN32_LEAN_AND_MEAN is a <windows.h> control switch, not a macro this
    // code branches on: it drops the socket, RPC and OLE headers nothing here
    // uses (docs/SDD.md 2.1 forbids macros in the code itself, not this).
#   define WIN32_LEAN_AND_MEAN
#   include <windows.h>
#else
#   include <cerrno>
#   include <sys/stat.h>
#   include <unistd.h>
#endif

namespace sudoku::cli {

namespace {

// Bytes pulled from the OS per read. One console line or one pipe burst fits
// comfortably; the buffer grows only when a line is longer than this.
inline constexpr std::size_t kReadChunkBytes = 512;

// The seam. Three functions, each the only platform-dependent thing in the
// console layer: acquire the standard input handle, classify it, read bytes
// from it. Everything below them is portable line handling.

[[nodiscard]] void* acquireStdinHandle() noexcept
{
#if defined(_WIN32)
    void* const handle = GetStdHandle(STD_INPUT_HANDLE);
    return handle == INVALID_HANDLE_VALUE ? nullptr : handle;
#else
    // A descriptor is not a pointer; it is carried as fd + 1 so that fd 0 is
    // distinguishable from "no handle". Decoded in readSome below.
    return reinterpret_cast<void*>(static_cast<std::intptr_t>(STDIN_FILENO) + 1);
#endif
}

[[nodiscard]] StdinKind classify(void* handle) noexcept
{
    if (handle == nullptr) {
        return StdinKind::Null;
    }

#if defined(_WIN32)
    switch (GetFileType(handle)) {
    case FILE_TYPE_CHAR: {
        // NUL: is also FILE_TYPE_CHAR and is not a console. GetConsoleMode is
        // what tells the two apart (docs/SDD.md 1.3).
        DWORD mode = 0;
        return GetConsoleMode(handle, &mode) != 0 ? StdinKind::Console
                                                  : StdinKind::Null;
    }
    case FILE_TYPE_PIPE:
        return StdinKind::Pipe;
    case FILE_TYPE_DISK:
        return StdinKind::File;
    default:
        return StdinKind::Null;
    }
#else
    struct stat info {};
    if (::fstat(STDIN_FILENO, &info) != 0) {
        return StdinKind::Null;
    }
    if (S_ISFIFO(info.st_mode) || S_ISSOCK(info.st_mode)) {
        return StdinKind::Pipe;
    }
    if (S_ISREG(info.st_mode)) {
        return StdinKind::File;
    }
    if (S_ISCHR(info.st_mode)) {
        // /dev/null is a character device and is not a terminal, which is the
        // POSIX shape of the NUL: case above.
        return ::isatty(STDIN_FILENO) != 0 ? StdinKind::Console : StdinKind::Null;
    }
    return StdinKind::Null;
#endif
}

// Reads up to 'capacity' bytes. Returns the count read; 0 means end of input
// or an unrecoverable error, and either way the caller latches the channel
// closed. Bytes are bytes: a NUL in the stream is data, never a terminator.
[[nodiscard]] std::size_t readSome(void* handle, char* buffer, std::size_t capacity) noexcept
{
#if defined(_WIN32)
    DWORD read = 0;
    if (ReadFile(handle, buffer, static_cast<DWORD>(capacity), &read, nullptr) == 0) {
        // A closed pipe is end of input, not a failure worth distinguishing.
        return 0;
    }
    return static_cast<std::size_t>(read);
#else
    const int fd = static_cast<int>(reinterpret_cast<std::intptr_t>(handle)) - 1;
    for (;;) {
        const auto got = ::read(fd, buffer, capacity);
        if (got < 0) {
            if (errno == EINTR) {
                continue;
            }
            return 0;
        }
        return static_cast<std::size_t>(got);
    }
#endif
}

// Removes the first line from 'buffer' if a terminator is present, stripping
// one trailing CR with the LF (docs/RTVM.md 7 I-1). Returns false when the
// buffer holds no complete line.
[[nodiscard]] bool takeCompleteLine(std::string& buffer, std::string& line)
{
    const std::size_t newline = buffer.find('\n');
    if (newline == std::string::npos) {
        return false;
    }

    std::size_t end = newline;
    if (end > 0 && buffer[end - 1] == '\r') {
        --end;
    }

    line.assign(buffer, 0, end);
    buffer.erase(0, newline + 1);
    return true;
}

} // namespace

StdinChannel::StdinChannel()
    : m_handle(acquireStdinHandle())
    , m_kind(classify(m_handle))
    , m_closed(m_kind == StdinKind::Null)
{
}

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
    // Buffer only. See the TODO at the top of this file: issuing a read here
    // before the availability tests of docs/SDD.md 1.3 exist would be exactly
    // the blocking call RTVM-006 and RTVM-008 forbid.
    return takeCompleteLine(m_buffer, line);
}

bool StdinChannel::readLineBlocking(std::string& line, std::size_t maxBytes)
{
    for (;;) {
        if (takeCompleteLine(m_buffer, line)) {
            return true;
        }

        if (m_buffer.size() >= maxBytes) {
            // No terminator within the cap. The line is malformed whatever
            // follows it, so it is handed over truncated and the rest is left
            // unread rather than buffered (docs/RTVM.md 7 I-13).
            line.assign(m_buffer, 0, maxBytes);
            m_buffer.erase(0, maxBytes);
            return true;
        }

        if (m_closed) {
            // End of input. Any trailing bytes are the final line, which
            // RTVM-106 accepts without a terminator.
            if (m_buffer.empty()) {
                return false;
            }
            line.swap(m_buffer);
            m_buffer.clear();
            return true;
        }

        char chunk[kReadChunkBytes];
        const std::size_t got = readSome(m_handle, chunk, sizeof chunk);
        if (got == 0) {
            m_closed = true;   // latched: no further read is ever issued
            continue;
        }
        m_buffer.append(chunk, got);
    }
}

} // namespace sudoku::cli
