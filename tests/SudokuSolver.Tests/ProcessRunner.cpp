// ProcessRunner.cpp -- see ProcessRunner.h.
//
// docs/SDD.md 3.3. docs/RTVM.md 9.8.1 (issue #24).
//
// PLATFORM. The delivered test project only ever compiles the _WIN32 branch
// (RTVM-906 constrains the product; the test project inherits the same
// policy so nothing platform-specific ships that isn't Win32). The POSIX
// branch exists purely so this pipeline's Linux agents -- which have no MSVC
// (docs/RTVM.md 9.1) -- can build and run this harness for real against a
// g++-built copy of the console layer, exactly as
// src/SudokuSolver/StdinChannel.cpp does for the product itself. Nothing in
// this file is shared logic reused across the two branches beyond the
// portable comparison helper at the bottom: process spawning, stream pumping
// and timeout enforcement differ enough between the two OS APIs that trying
// to factor out a common core would obscure both.

#include "ProcessRunner.h"

#include <condition_variable>
#include <functional>
#include <mutex>
#include <thread>
#include <vector>

#if defined(_WIN32)
#   define WIN32_LEAN_AND_MEAN
#   include <windows.h>
#else
#   include <fcntl.h>
#   include <signal.h>
#   include <sys/wait.h>
#   include <unistd.h>
#   include <climits>
#   include <cerrno>
#endif

namespace sudoku::test {

namespace {

// Bytes read per ReadFile/read call. Generous enough that the §6.2 block
// (338 bytes) and every TP-001...003 fixture arrive in one call; larger
// captures (TP-505's 1 MB corpus entry) simply loop.
inline constexpr std::size_t kReadChunkBytes = 65536;

} // namespace

#if defined(_WIN32)

namespace {

// Builds one Windows command-line argument, quoted per the algorithm
// CommandLineToArgvW (and therefore the C runtime's argv parser every child
// built by this toolchain uses) expects: backslashes are only special
// immediately before a quote, and a run of them doubles when it precedes one.
[[nodiscard]] std::string quoteArgument(const std::string& arg)
{
    const bool needsQuoting = arg.empty() || arg.find_first_of(" \t\"") != std::string::npos;
    if (!needsQuoting) {
        return arg;
    }

    std::string quoted = "\"";
    std::size_t backslashes = 0;
    for (const char c : arg) {
        if (c == '\\') {
            ++backslashes;
            continue;
        }
        if (c == '"') {
            quoted.append(backslashes * 2 + 1, '\\');
            backslashes = 0;
            quoted.push_back('"');
            continue;
        }
        quoted.append(backslashes, '\\');
        backslashes = 0;
        quoted.push_back(c);
    }
    quoted.append(backslashes * 2, '\\');
    quoted.push_back('"');
    return quoted;
}

[[nodiscard]] std::string buildCommandLine(const std::string& executablePath, const std::vector<std::string>& args)
{
    std::string commandLine = quoteArgument(executablePath);
    for (const auto& arg : args) {
        commandLine.push_back(' ');
        commandLine += quoteArgument(arg);
    }
    return commandLine;
}

// Reads a pipe to EOF into 'out'. Runs on its own thread so stdout and
// stderr are drained at the same time -- see the deadlock note in
// ProcessRunner.h.
void pumpToEof(HANDLE handle, std::string& out)
{
    char chunk[kReadChunkBytes];
    DWORD bytesRead = 0;
    while (ReadFile(handle, chunk, static_cast<DWORD>(sizeof chunk), &bytesRead, nullptr) && bytesRead > 0) {
        out.append(chunk, bytesRead);
    }
}

// Writes 'bytes' to the child's stdin pipe, then closes the write end so the
// child observes EOF (TP-003, TP-008). Runs on its own thread: a large
// buffer could fill the pipe before the child has read any of it, and this
// keeps that from blocking the caller.
void feedStdinThenClose(HANDLE handle, const std::string& bytes)
{
    const char* data = bytes.data();
    std::size_t remaining = bytes.size();
    while (remaining > 0) {
        const DWORD toWrite = static_cast<DWORD>(
            remaining < 65536 ? remaining : std::size_t{ 65536 });
        DWORD written = 0;
        if (!WriteFile(handle, data, toWrite, &written, nullptr) || written == 0) {
            break;
        }
        data += written;
        remaining -= written;
    }
    CloseHandle(handle);
}

} // namespace

ProcessResult ProcessRunner::run(
    const std::string& executablePath,
    const std::vector<std::string>& args,
    const ProcessInput& input,
    std::chrono::milliseconds timeout)
{
    ProcessResult result;

    SECURITY_ATTRIBUTES inheritable{};
    inheritable.nLength = sizeof(inheritable);
    inheritable.bInheritHandle = TRUE;
    inheritable.lpSecurityDescriptor = nullptr;

    HANDLE stdoutRead = nullptr, stdoutWrite = nullptr;
    HANDLE stderrRead = nullptr, stderrWrite = nullptr;
    HANDLE stdinChildSide = nullptr;   // what the child inherits as hStdInput
    HANDLE stdinWriteEnd = nullptr;    // ours to write to, StdinMode::Bytes only

    if (!CreatePipe(&stdoutRead, &stdoutWrite, &inheritable, 0)
        || !SetHandleInformation(stdoutRead, HANDLE_FLAG_INHERIT, 0)) {
        return result;
    }
    if (!CreatePipe(&stderrRead, &stderrWrite, &inheritable, 0)
        || !SetHandleInformation(stderrRead, HANDLE_FLAG_INHERIT, 0)) {
        CloseHandle(stdoutRead);
        CloseHandle(stdoutWrite);
        return result;
    }

    switch (input.mode) {
    case StdinMode::Closed:
        // hStdInput stays null with STARTF_USESTDHANDLES set below, which
        // gives the child no standard input handle at all -- the Windows
        // shape of `0<&-`, and what StdinChannel's classify() reports as
        // StdinKind::Null.
        break;
    case StdinMode::Bytes: {
        HANDLE stdinReadEnd = nullptr;
        if (!CreatePipe(&stdinReadEnd, &stdinWriteEnd, &inheritable, 0)
            || !SetHandleInformation(stdinWriteEnd, HANDLE_FLAG_INHERIT, 0)) {
            CloseHandle(stdoutRead); CloseHandle(stdoutWrite);
            CloseHandle(stderrRead); CloseHandle(stderrWrite);
            return result;
        }
        stdinChildSide = stdinReadEnd;
        break;
    }
    case StdinMode::File:
        stdinChildSide = CreateFileA(input.filePath.c_str(), GENERIC_READ, FILE_SHARE_READ,
            &inheritable, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (stdinChildSide == INVALID_HANDLE_VALUE) {
            CloseHandle(stdoutRead); CloseHandle(stdoutWrite);
            CloseHandle(stderrRead); CloseHandle(stderrWrite);
            return result;
        }
        break;
    }

    STARTUPINFOA startupInfo{};
    startupInfo.cb = sizeof(startupInfo);
    startupInfo.dwFlags = STARTF_USESTDHANDLES;
    startupInfo.hStdInput = stdinChildSide;
    startupInfo.hStdOutput = stdoutWrite;
    startupInfo.hStdError = stderrWrite;

    PROCESS_INFORMATION processInfo{};
    const std::string commandLine = buildCommandLine(executablePath, args);
    std::vector<char> commandLineBuffer(commandLine.begin(), commandLine.end());
    commandLineBuffer.push_back('\0');

    const auto startTime = std::chrono::steady_clock::now();
    const BOOL spawned = CreateProcessA(
        executablePath.c_str(), commandLineBuffer.data(), nullptr, nullptr,
        /*bInheritHandles=*/TRUE, CREATE_NO_WINDOW, nullptr, nullptr, &startupInfo, &processInfo);

    // These are the child's copies once CreateProcess has duplicated them
    // (or would have, had it succeeded); the parent never reads/writes them
    // again either way.
    CloseHandle(stdoutWrite);
    CloseHandle(stderrWrite);
    if (stdinChildSide != nullptr) {
        CloseHandle(stdinChildSide);
    }

    if (!spawned) {
        CloseHandle(stdoutRead);
        CloseHandle(stderrRead);
        if (stdinWriteEnd != nullptr) {
            CloseHandle(stdinWriteEnd);
        }
        return result;
    }
    result.spawned = true;
    CloseHandle(processInfo.hThread);

    std::thread stdoutThread(pumpToEof, stdoutRead, std::ref(result.stdOut));
    std::thread stderrThread(pumpToEof, stderrRead, std::ref(result.stdErr));
    std::thread stdinThread;
    if (input.mode == StdinMode::Bytes) {
        stdinThread = std::thread(feedStdinThenClose, stdinWriteEnd, std::cref(input.bytes));
    }

    const DWORD waitResult = WaitForSingleObject(processInfo.hProcess, static_cast<DWORD>(timeout.count()));
    if (waitResult == WAIT_TIMEOUT) {
        TerminateProcess(processInfo.hProcess, 1);
        WaitForSingleObject(processInfo.hProcess, INFINITE);
        result.timedOut = true;
    }
    result.wallClock = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - startTime);

    DWORD exitCode = 0;
    GetExitCodeProcess(processInfo.hProcess, &exitCode);
    result.exitCode = static_cast<int>(exitCode);

    // Safe to join now: the process is dead, so the OS has closed every
    // handle it held, which is what lets ReadFile/WriteFile on the other
    // ends of these pipes return.
    stdoutThread.join();
    stderrThread.join();
    if (stdinThread.joinable()) {
        stdinThread.join();
    }

    CloseHandle(stdoutRead);
    CloseHandle(stderrRead);
    CloseHandle(processInfo.hProcess);

    return result;
}

std::string ProcessRunner::testModuleDirectory()
{
    HMODULE module = nullptr;
    // GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS resolves the module that
    // *contains this function* -- SudokuSolver.Tests.dll -- which is not the
    // same thing as the running process's module (the vstest test host,
    // wherever Visual Studio installed it).
    if (!GetModuleHandleExA(
            GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
            reinterpret_cast<LPCSTR>(&ProcessRunner::testModuleDirectory), &module)) {
        return {};
    }

    char pathBuffer[MAX_PATH];
    const DWORD length = GetModuleFileNameA(module, pathBuffer, MAX_PATH);
    if (length == 0 || length == MAX_PATH) {
        return {};
    }

    std::string path(pathBuffer, length);
    const std::size_t lastSeparator = path.find_last_of("\\/");
    return lastSeparator == std::string::npos ? std::string{} : path.substr(0, lastSeparator);
}

#else // POSIX -- see the file header. Not shipped; keeps this harness
      // runnable on the pipeline's Linux agents.

namespace {

// Read/write ends of a pipe, named instead of a raw int[2] so a reader knows
// which side it holds without re-deriving it from index arithmetic.
struct Pipe {
    int readEnd = -1;
    int writeEnd = -1;
};

[[nodiscard]] bool makePipe(Pipe& pipe)
{
    int fds[2] = { -1, -1 };
    if (::pipe(fds) != 0) {
        return false;
    }
    pipe.readEnd = fds[0];
    pipe.writeEnd = fds[1];
    return true;
}

void closeIfOpen(int& fd)
{
    if (fd >= 0) {
        ::close(fd);
        fd = -1;
    }
}

void pumpToEof(int fd, std::string& out)
{
    char chunk[kReadChunkBytes];
    for (;;) {
        const ssize_t got = ::read(fd, chunk, sizeof chunk);
        if (got > 0) {
            out.append(chunk, static_cast<std::size_t>(got));
            continue;
        }
        if (got < 0 && errno == EINTR) {
            continue;
        }
        break; // 0 == EOF; any other error is treated the same way
    }
}

void feedStdinThenClose(int fd, const std::string& bytes)
{
    const char* data = bytes.data();
    std::size_t remaining = bytes.size();
    while (remaining > 0) {
        const ssize_t written = ::write(fd, data, remaining);
        if (written < 0) {
            if (errno == EINTR) {
                continue;
            }
            break; // EPIPE (child gone) or another unrecoverable error
        }
        data += written;
        remaining -= static_cast<std::size_t>(written);
    }
    ::close(fd);
}

} // namespace

ProcessResult ProcessRunner::run(
    const std::string& executablePath,
    const std::vector<std::string>& args,
    const ProcessInput& input,
    std::chrono::milliseconds timeout)
{
    ProcessResult result;

    // A child that exits (or is killed) before consuming stdin would
    // otherwise deliver SIGPIPE to *this* process and terminate the whole
    // test binary on the next write -- fatal to the suite, not just to one
    // test. Once set this is process-global and idempotent to repeat.
    static const bool sigpipeIgnored = [] {
        ::signal(SIGPIPE, SIG_IGN);
        return true;
    }();
    (void)sigpipeIgnored;

    Pipe stdoutPipe, stderrPipe, stdinPipe;
    if (!makePipe(stdoutPipe)) {
        return result;
    }
    if (!makePipe(stderrPipe)) {
        closeIfOpen(stdoutPipe.readEnd);
        closeIfOpen(stdoutPipe.writeEnd);
        return result;
    }

    int stdinFileFd = -1;
    if (input.mode == StdinMode::Bytes) {
        if (!makePipe(stdinPipe)) {
            closeIfOpen(stdoutPipe.readEnd); closeIfOpen(stdoutPipe.writeEnd);
            closeIfOpen(stderrPipe.readEnd); closeIfOpen(stderrPipe.writeEnd);
            return result;
        }
    } else if (input.mode == StdinMode::File) {
        stdinFileFd = ::open(input.filePath.c_str(), O_RDONLY);
        if (stdinFileFd < 0) {
            closeIfOpen(stdoutPipe.readEnd); closeIfOpen(stdoutPipe.writeEnd);
            closeIfOpen(stderrPipe.readEnd); closeIfOpen(stderrPipe.writeEnd);
            return result;
        }
    }

    // Self-pipe, close-on-exec: silent unless execvp fails, in which case the
    // child writes its errno here before exiting. Lets the parent tell
    // "the target never ran" apart from "the target ran and exited early".
    Pipe execStatusPipe;
    if (!makePipe(execStatusPipe)) {
        closeIfOpen(stdoutPipe.readEnd); closeIfOpen(stdoutPipe.writeEnd);
        closeIfOpen(stderrPipe.readEnd); closeIfOpen(stderrPipe.writeEnd);
        closeIfOpen(stdinPipe.readEnd); closeIfOpen(stdinPipe.writeEnd);
        closeIfOpen(stdinFileFd);
        return result;
    }
    ::fcntl(execStatusPipe.writeEnd, F_SETFD, FD_CLOEXEC);

    std::vector<char*> argv;
    argv.push_back(const_cast<char*>(executablePath.c_str()));
    for (const auto& arg : args) {
        argv.push_back(const_cast<char*>(arg.c_str()));
    }
    argv.push_back(nullptr);

    const auto startTime = std::chrono::steady_clock::now();
    const pid_t pid = ::fork();

    if (pid < 0) {
        closeIfOpen(stdoutPipe.readEnd); closeIfOpen(stdoutPipe.writeEnd);
        closeIfOpen(stderrPipe.readEnd); closeIfOpen(stderrPipe.writeEnd);
        closeIfOpen(stdinPipe.readEnd); closeIfOpen(stdinPipe.writeEnd);
        closeIfOpen(stdinFileFd);
        closeIfOpen(execStatusPipe.readEnd); closeIfOpen(execStatusPipe.writeEnd);
        return result;
    }

    if (pid == 0) {
        // Child. SIG_IGN survives execve (only a function handler is reset to
        // default) -- undo the parent's SIGPIPE mitigation here so the
        // spawned program, and anything it goes on to spawn itself, sees the
        // ordinary default disposition rather than silently inheriting this
        // harness's own concern. Found by exercising this harness against a
        // shell pipeline during issue #24 validation, where GNU `yes`
        // noticed the ignored signal and printed a broken-pipe diagnostic to
        // stderr that had no business being there.
        ::signal(SIGPIPE, SIG_DFL);

        // Wire up the standard streams, close everything else, exec.
        ::dup2(stdoutPipe.writeEnd, STDOUT_FILENO);
        ::dup2(stderrPipe.writeEnd, STDERR_FILENO);

        switch (input.mode) {
        case StdinMode::Closed:
            ::close(STDIN_FILENO);
            break;
        case StdinMode::Bytes:
            ::dup2(stdinPipe.readEnd, STDIN_FILENO);
            break;
        case StdinMode::File:
            ::dup2(stdinFileFd, STDIN_FILENO);
            break;
        }

        closeIfOpen(stdoutPipe.readEnd); closeIfOpen(stdoutPipe.writeEnd);
        closeIfOpen(stderrPipe.readEnd); closeIfOpen(stderrPipe.writeEnd);
        closeIfOpen(stdinPipe.readEnd); closeIfOpen(stdinPipe.writeEnd);
        closeIfOpen(stdinFileFd);
        closeIfOpen(execStatusPipe.readEnd);

        ::execv(executablePath.c_str(), argv.data());

        const int execErrno = errno;
        // Best-effort: if this write fails there is nothing left to report
        // to, so the parent falls back to reading exit code 127 below.
        [[maybe_unused]] const ssize_t written = ::write(execStatusPipe.writeEnd, &execErrno, sizeof execErrno);
        (void)written;
        ::_exit(127);
    }

    // Parent.
    closeIfOpen(stdoutPipe.writeEnd);
    closeIfOpen(stderrPipe.writeEnd);
    if (input.mode == StdinMode::Bytes) {
        closeIfOpen(stdinPipe.readEnd);
    }
    closeIfOpen(stdinFileFd);
    closeIfOpen(execStatusPipe.writeEnd);

    int execErrno = 0;
    const ssize_t execStatusBytes = ::read(execStatusPipe.readEnd, &execErrno, sizeof execErrno);
    closeIfOpen(execStatusPipe.readEnd);
    const bool execFailed = execStatusBytes == sizeof execErrno;

    std::thread stdoutThread(pumpToEof, stdoutPipe.readEnd, std::ref(result.stdOut));
    std::thread stderrThread(pumpToEof, stderrPipe.readEnd, std::ref(result.stdErr));
    std::thread stdinThread;
    if (input.mode == StdinMode::Bytes) {
        stdinThread = std::thread(feedStdinThenClose, stdinPipe.writeEnd, std::cref(input.bytes));
    }

    // Reaped on its own thread so the timeout below can be enforced with a
    // bounded wait instead of a blocking waitpid.
    std::mutex reapMutex;
    std::condition_variable reapCv;
    bool reaped = false;
    int status = 0;
    std::thread waiter([&] {
        int localStatus = 0;
        ::waitpid(pid, &localStatus, 0);
        std::lock_guard<std::mutex> lock(reapMutex);
        status = localStatus;
        reaped = true;
        reapCv.notify_all();
    });

    {
        std::unique_lock<std::mutex> lock(reapMutex);
        const bool finishedInTime = reapCv.wait_for(lock, timeout, [&] { return reaped; });
        if (!finishedInTime) {
            ::kill(pid, SIGKILL);
            result.timedOut = true;
        }
    }
    waiter.join();

    result.wallClock = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - startTime);

    stdoutThread.join();
    stderrThread.join();
    if (stdinThread.joinable()) {
        stdinThread.join();
    }

    closeIfOpen(stdoutPipe.readEnd);
    closeIfOpen(stderrPipe.readEnd);

    if (execFailed) {
        // The target never actually ran; a status/output from a process that
        // only ever executed "fork, fail to exec, exit 127" is not evidence
        // about the product.
        result.spawned = false;
        result.stdOut.clear();
        result.stdErr.clear();
        return result;
    }

    result.spawned = true;
    if (WIFEXITED(status)) {
        result.exitCode = WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        // Negative and distinguishable from any exit(2) code the product
        // itself could choose (RTVM-405's set is {0,1,2,3}).
        result.exitCode = -WTERMSIG(status);
    }

    return result;
}

std::string ProcessRunner::testModuleDirectory()
{
    char pathBuffer[PATH_MAX];
    const ssize_t length = ::readlink("/proc/self/exe", pathBuffer, sizeof(pathBuffer) - 1);
    if (length <= 0) {
        return ".";
    }
    pathBuffer[length] = '\0';

    const std::string path(pathBuffer);
    const std::size_t lastSeparator = path.find_last_of('/');
    return lastSeparator == std::string::npos ? std::string{ "." } : path.substr(0, lastSeparator);
}

#endif // _WIN32 / POSIX

bool equalsAfterCrlfNormalization(std::string_view actual, std::string_view expectedLf)
{
    std::string normalized;
    normalized.reserve(actual.size());
    for (std::size_t index = 0; index < actual.size(); ++index) {
        if (actual[index] == '\r' && index + 1 < actual.size() && actual[index + 1] == '\n') {
            continue; // drop the CR, keep the LF that follows it
        }
        normalized.push_back(actual[index]);
    }
    return normalized == expectedLf;
}

} // namespace sudoku::test
