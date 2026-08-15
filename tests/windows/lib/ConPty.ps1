# ConPty.ps1 — a small ConPTY driver, built for issue #25 (docs/RTVM.md
# §9.4 A-4). Its only job is to put a *real* Windows console handle in
# front of SudokuSolver.exe, so tests/windows/run-procedures.ps1 can attempt
# TP-004/TP-005/TP-006 against the `Console` `StdinKind` branch
# (`StdinChannel.cpp`'s `GetFileType`/`PeekConsoleInput`/`ReadConsoleA` path)
# instead of only the `Pipe`/`File` shapes `Invoke-Sudoku` (Common.ps1)
# already drives.
#
# Dot-sourced by run-procedures.ps1 alongside Common.ps1/Fixtures.ps1 (same
# W-10 rationale: agent-writable, no workflows-permission round trip).
#
# Why a compiled C# type instead of raw PowerShell P/Invoke: ConPTY setup
# needs InitializeProcThreadAttributeList/UpdateProcThreadAttribute against
# an unmanaged buffer sized at runtime, a STARTUPINFOEX passed by reference,
# and a background reader thread so a poll loop can inspect output without
# blocking on ReadFile — all fiddly to get byte-correct from loose PS
# P/Invoke calls and easy to get subtly wrong (wrong struct layout, wrong
# attribute value) in a way that only shows up on a real Windows run.
# Add-Type compiles it once per session (guarded below) and the C# itself
# can be syntax-checked on any platform that has pwsh, since P/Invoke
# declarations don't need the target DLL to exist until a method is
# actually called (see the software-engineer memory entry
# no-msvc-in-agent-runner) — only the *behaviour* is Windows-only.
#
# The construction sequence below (two anonymous pipes, CreatePseudoConsole,
# InitializeProcThreadAttributeList/UpdateProcThreadAttribute,
# CreateProcessW with EXTENDED_STARTUPINFO_PRESENT) is the sequence
# Microsoft's own ConPTY sample documents — nothing invented here.
#
# Third Windows round (issue #25): the reader thread's output pipe was
# originally wrapped in a .NET FileStream (Read()/Write()/Dispose()).
# Real evidence from the first two Windows runs (see the ReaderReadCallCount
# instrumentation and its call sites further down) showed the first Read()
# call returning but every one after it blocking forever, even against a
# session that was actively producing output for 55+ seconds — the
# FileStream layer's own buffering/lifetime behaviour over a raw pipe
# handle was a live suspect with no way to rule it out from this Linux
# development environment. ReadFile/WriteFile below call the pipe directly,
# the same Win32 functions StdinChannel.cpp already uses successfully on
# every other StdinKind in this codebase, removing that layer rather than
# instrumenting around it further.

Set-StrictMode -Off

$script:ConPtySource = @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace SudokuTests
{
    // A minimal ConPTY-attached child process: spawn SudokuSolver.exe with a
    // real pseudoconsole in front of its stdin/stdout/stderr, write bytes to
    // it the way a person at a keyboard would (after launch, not queued
    // before it), and drain whatever the console rendered so far without
    // blocking. Nothing here asserts anything about SudokuSolver.exe's
    // behaviour — that judgment is entirely in the calling PowerShell.
    public sealed class ConPtyProcess : IDisposable
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct COORD { public short X; public short Y; }

        [StructLayout(LayoutKind.Sequential)]
        private struct STARTUPINFO
        {
            public int cb;
            public IntPtr lpReserved;
            public IntPtr lpDesktop;
            public IntPtr lpTitle;
            public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars;
            public int dwFillAttribute, dwFlags;
            public short wShowWindow, cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput, hStdOutput, hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct STARTUPINFOEX
        {
            public STARTUPINFO StartupInfo;
            public IntPtr lpAttributeList;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct PROCESS_INFORMATION
        {
            public IntPtr hProcess, hThread;
            public int dwProcessId, dwThreadId;
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CreatePipe(out IntPtr hReadPipe, out IntPtr hWritePipe, IntPtr lpPipeAttributes, uint nSize);

        // HRESULT return (0 == S_OK), not a BOOL — this is the one ConPTY
        // entry point that differs from the rest of the Win32 surface here.
        [DllImport("kernel32.dll")]
        private static extern int CreatePseudoConsole(COORD size, IntPtr hInput, IntPtr hOutput, uint dwFlags, out IntPtr phPC);

        [DllImport("kernel32.dll")]
        private static extern void ClosePseudoConsole(IntPtr hPC);

        [DllImport("kernel32.dll")]
        private static extern int ResizePseudoConsole(IntPtr hPC, COORD size);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr hObject);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool InitializeProcThreadAttributeList(IntPtr lpAttributeList, int dwAttributeCount, int dwFlags, ref IntPtr lpSize);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool UpdateProcThreadAttribute(IntPtr lpAttributeList, uint dwFlags, IntPtr Attribute, IntPtr lpValue, IntPtr cbSize, IntPtr lpPreviousValue, IntPtr lpReturnSize);

        [DllImport("kernel32.dll")]
        private static extern void DeleteProcThreadAttributeList(IntPtr lpAttributeList);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern bool CreateProcessW(
            string lpApplicationName,
            StringBuilder lpCommandLine,
            IntPtr lpProcessAttributes,
            IntPtr lpThreadAttributes,
            bool bInheritHandles,
            uint dwCreationFlags,
            IntPtr lpEnvironment,
            string lpCurrentDirectory,
            ref STARTUPINFOEX lpStartupInfo,
            out PROCESS_INFORMATION lpProcessInformation);

        [DllImport("kernel32.dll")]
        private static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetExitCodeProcess(IntPtr hProcess, out uint lpExitCode);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool TerminateProcess(IntPtr hProcess, uint uExitCode);

        // Third Windows round (issue #25): the reader thread's very first
        // Read() call returned (ReaderReadCallCount=1) but every subsequent
        // one blocked forever, even against a SudokuSolver.exe session
        // actively writing prompts for 55+ seconds - i.e. not "no data was
        // ever produced" but "this thread stopped seeing it after the
        // first call". That symptom points at .NET's FileStream, not at
        // ConPTY itself: FileStream applies its own internal buffering/
        // read-ahead heuristics on top of a raw handle, and those
        // heuristics are documented for regular files, not for anonymous
        // pipes wrapped this way. ReadFile/WriteFile below call the same
        // Win32 functions StdinChannel.cpp already uses successfully on
        // every other StdinKind in this codebase, with nothing in between
        // to second-guess.
        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool ReadFile(IntPtr hFile, byte[] lpBuffer, uint nNumberOfBytesToRead, out uint lpNumberOfBytesRead, IntPtr lpOverlapped);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool WriteFile(IntPtr hFile, byte[] lpBuffer, uint nNumberOfBytesToWrite, out uint lpNumberOfBytesWritten, IntPtr lpOverlapped);

        private const uint EXTENDED_STARTUPINFO_PRESENT = 0x00080000;
        // ProcThreadAttributeValue(ProcThreadAttributePseudoConsole=22, Thread=FALSE, Input=TRUE, Additive=FALSE)
        // == 22 | 0x00020000. Documented constant, not derived at runtime.
        private const int PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE = unchecked((int)0x00020016);
        private const uint STILL_ACTIVE = 259;
        private const uint WAIT_OBJECT_0 = 0;

        private IntPtr _hPC = IntPtr.Zero;
        private IntPtr _hProcess = IntPtr.Zero;
        private IntPtr _hThread = IntPtr.Zero;
        private IntPtr _attrList = IntPtr.Zero;
        // Raw handles, not FileStream (see the ReadFile/WriteFile P/Invoke
        // comment above) - _hInputWrite is written to with WriteInput,
        // _hOutputRead is drained by ReaderLoop.
        private IntPtr _hInputWrite = IntPtr.Zero;
        private IntPtr _hOutputRead = IntPtr.Zero;
        private readonly object _bufferLock = new object();
        private readonly StringBuilder _outputBuffer = new StringBuilder();
        private Thread _readerThread;
        private volatile bool _stopReader;

        public bool Started { get; private set; }
        public string LastError { get; private set; }
        public int ProcessId { get; private set; }

        // Diagnostics only (issue #25, second Windows round): the first
        // real run showed Started=true, correct exit codes, correct
        // elapsed time (proving process creation/args/env all work), but
        // PeekOutput() came back empty for the whole run - these three
        // fields narrow down whether the reader thread ever ran, ever
        // called Read(), and whether Read() ever threw.
        public string ReaderException { get; private set; }
        public long ReaderReadCallCount;
        public bool ReaderThreadAlive { get { return _readerThread != null && _readerThread.IsAlive; } }

        // Spawns 'exePath arguments' attached to a fresh pseudoconsole. Any
        // extra environment the caller wants the child to see must already
        // be set in *this* process's environment before calling Start() —
        // lpEnvironment is passed as NULL, which makes CreateProcess give
        // the child a snapshot of the caller's own environment block,
        // exactly the pattern Common.ps1's Invoke-Sudoku already uses for
        // the pipe/file harness (set, launch, restore).
        //
        // Sixth Windows round (issue #25): rounds 1-5 proved CreatePseudoConsole/
        // CreateProcessW/the pipe plumbing itself works (conhost's own
        // negotiation-and-first-repaint burst arrives intact, byte for
        // byte, on both a trivial cmd.exe control case and SudokuSolver.exe
        // alike) but that no *subsequently written* character output - not
        // delayed, not truncated, simply absent - ever reaches the reader
        // thread from either process, even measured well after the child
        // has exited. That points at conhost's render pass on this image,
        // not at anything specific to SudokuSolver.exe or to this harness's
        // reading code. stdoutRedirectPath/stderrRedirectPath below stop
        // depending on that render pass for the actual TP-004/005/006
        // assertions: when given, 'exePath arguments' is wrapped in
        // "cmd.exe /c ...1>out 2>err" and *cmd.exe* is what gets attached
        // to the pseudoconsole. cmd inherits its own stdin from the
        // pseudoconsole and never touches it, but opens the redirect
        // targets as ordinary Win32 file handles for the child it spawns -
        // exactly what a person gets typing "program > out.txt 2> err.txt"
        // at an interactive prompt. StdinChannel.cpp's Console StdinKind
        // branch still sees a genuine console handle; stdout/stderr become
        // independently readable files instead of one merged VT transcript,
        // which also finally gives TP-004's "nothing on stdout" and TP-005's
        // "stdout stays empty" a real separate stream to assert against
        // instead of inferring it from transcript ordering. cmd.exe /c
        // forwards its child's exit code as its own (documented behaviour),
        // so ExitCode/HasExited below - which read this process's own
        // handle, i.e. cmd.exe's - still report exePath's real exit code
        // unchanged.
        public bool Start(string exePath, string arguments, short columns, short rows, string stdoutRedirectPath = null, string stderrRedirectPath = null)
        {
            IntPtr inputRead = IntPtr.Zero, inputWrite = IntPtr.Zero;
            IntPtr outputRead = IntPtr.Zero, outputWrite = IntPtr.Zero;
            bool ptyPipesClosed = false;

            try
            {
                if (!CreatePipe(out inputRead, out inputWrite, IntPtr.Zero, 0))
                {
                    LastError = "CreatePipe(input) failed, GetLastError=" + Marshal.GetLastWin32Error();
                    return false;
                }
                if (!CreatePipe(out outputRead, out outputWrite, IntPtr.Zero, 0))
                {
                    LastError = "CreatePipe(output) failed, GetLastError=" + Marshal.GetLastWin32Error();
                    return false;
                }

                var size = new COORD { X = columns, Y = rows };
                int hr = CreatePseudoConsole(size, inputRead, outputWrite, 0, out _hPC);
                if (hr != 0)
                {
                    LastError = "CreatePseudoConsole failed, hresult=0x" + hr.ToString("X8");
                    return false;
                }

                // Fourth Windows round (issue #25): with FileStream ruled
                // out (ReadFile/WriteFile see the exact same 16-byte
                // handshake and nothing else, against two different child
                // processes, even 55s later), the remaining suspect is
                // ConPTY session setup itself never being kicked into
                // rendering past its initial mode-negotiation burst. A
                // same-size resize immediately after creation is a
                // documented-by-experience nudge for exactly that failure
                // mode in other ConPTY host implementations. Best-effort:
                // if it fails, that is itself useful evidence (recorded),
                // not a reason to abandon the session.
                int resizeHr = ResizePseudoConsole(_hPC, size);
                if (resizeHr != 0)
                {
                    LastError = "ResizePseudoConsole (post-create kick) failed, hresult=0x" + resizeHr.ToString("X8") + " - continuing anyway";
                }

                // ConPTY duplicates these two handles internally; our copies
                // are closed here per Microsoft's own sample (they would
                // otherwise leak, and keeping them open serves no purpose —
                // it is inputWrite/outputRead below this harness actually
                // uses).
                CloseHandle(inputRead); inputRead = IntPtr.Zero;
                CloseHandle(outputWrite); outputWrite = IntPtr.Zero;
                ptyPipesClosed = true;

                IntPtr attrListSize = IntPtr.Zero;
                InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref attrListSize);
                if (attrListSize == IntPtr.Zero)
                {
                    LastError = "InitializeProcThreadAttributeList size probe returned 0, GetLastError=" + Marshal.GetLastWin32Error();
                    return false;
                }
                _attrList = Marshal.AllocHGlobal(attrListSize);
                if (!InitializeProcThreadAttributeList(_attrList, 1, 0, ref attrListSize))
                {
                    LastError = "InitializeProcThreadAttributeList failed, GetLastError=" + Marshal.GetLastWin32Error();
                    return false;
                }
                if (!UpdateProcThreadAttribute(_attrList, 0, (IntPtr)PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, _hPC, (IntPtr)IntPtr.Size, IntPtr.Zero, IntPtr.Zero))
                {
                    LastError = "UpdateProcThreadAttribute failed, GetLastError=" + Marshal.GetLastWin32Error();
                    return false;
                }

                var si = new STARTUPINFOEX();
                si.StartupInfo.cb = Marshal.SizeOf(typeof(STARTUPINFOEX));
                si.lpAttributeList = _attrList;

                string fullCommand;
                if (!string.IsNullOrEmpty(stdoutRedirectPath) || !string.IsNullOrEmpty(stderrRedirectPath))
                {
                    string comspec = Environment.GetEnvironmentVariable("ComSpec");
                    if (string.IsNullOrEmpty(comspec)) comspec = "C:\\Windows\\System32\\cmd.exe";
                    string inner = "\"" + exePath + "\"" + (string.IsNullOrEmpty(arguments) ? "" : " " + arguments);
                    if (!string.IsNullOrEmpty(stdoutRedirectPath)) inner += " 1>\"" + stdoutRedirectPath + "\"";
                    if (!string.IsNullOrEmpty(stderrRedirectPath)) inner += " 2>\"" + stderrRedirectPath + "\"";
                    // Doubled outer quote around the whole /c argument is
                    // deliberate cmd.exe quoting, not a typo - the accepted
                    // workaround for cmd's own argument parser when the
                    // command it must run already contains quoted paths.
                    fullCommand = "\"" + comspec + "\" /c \"" + inner + "\"";
                }
                else
                {
                    fullCommand = "\"" + exePath + "\"" + (string.IsNullOrEmpty(arguments) ? "" : " " + arguments);
                }
                var cmd = new StringBuilder(fullCommand, fullCommand.Length + 32);

                PROCESS_INFORMATION pi;
                bool ok = CreateProcessW(
                    null, cmd, IntPtr.Zero, IntPtr.Zero,
                    /* bInheritHandles */ false,
                    EXTENDED_STARTUPINFO_PRESENT,
                    IntPtr.Zero, null, ref si, out pi);

                if (!ok)
                {
                    LastError = "CreateProcessW failed, GetLastError=" + Marshal.GetLastWin32Error();
                    return false;
                }

                _hProcess = pi.hProcess;
                _hThread = pi.hThread;
                ProcessId = pi.dwProcessId;

                _hInputWrite = inputWrite;
                _hOutputRead = outputRead;
                inputWrite = IntPtr.Zero;  // ownership moved to the fields above -
                outputRead = IntPtr.Zero;  // the finally block below must not also close these

                _readerThread = new Thread(ReaderLoop);
                _readerThread.IsBackground = true;
                _readerThread.Start();

                Started = true;
                return true;
            }
            catch (Exception ex)
            {
                LastError = ex.ToString();
                return false;
            }
            finally
            {
                if (!ptyPipesClosed)
                {
                    if (inputRead != IntPtr.Zero) CloseHandle(inputRead);
                    if (outputWrite != IntPtr.Zero) CloseHandle(outputWrite);
                }
                // On any failure path these are still raw handles (Started
                // is still false), so close them here rather than leak them.
                if (!Started)
                {
                    if (inputWrite != IntPtr.Zero) CloseHandle(inputWrite);
                    if (outputRead != IntPtr.Zero) CloseHandle(outputRead);
                }
            }
        }

        // Total bytes ever appended to _outputBuffer - independent of
        // PeekOutput()'s string length, so a diagnostic can tell "the
        // buffer really is empty" apart from "something downstream of the
        // buffer (a UTF-8 decode, a caller's own filtering) is losing it".
        public long TotalBytesRead;

        private void ReaderLoop()
        {
            var buf = new byte[4096];
            try
            {
                while (!_stopReader)
                {
                    uint read;
                    bool ok = ReadFile(_hOutputRead, buf, (uint)buf.Length, out read, IntPtr.Zero);
                    Interlocked.Increment(ref ReaderReadCallCount);
                    if (!ok)
                    {
                        // ERROR_BROKEN_PIPE (109) once ClosePseudoConsole
                        // tears the session down is the expected end of
                        // this loop, not a fault worth recording as one.
                        int err = Marshal.GetLastWin32Error();
                        if (err != 109) ReaderException = "ReadFile failed, GetLastError=" + err;
                        break;
                    }
                    if (read == 0) break;
                    Interlocked.Add(ref TotalBytesRead, read);
                    string text = Encoding.UTF8.GetString(buf, 0, (int)read);
                    lock (_bufferLock) { _outputBuffer.Append(text); }
                }
            }
            catch (Exception ex)
            {
                // Recorded rather than swallowed (issue #25 diagnostics) -
                // the handle being closed under us at Dispose time is the
                // expected/benign case, but this also catches a genuine
                // read-side failure that would otherwise look identical to
                // "nothing was ever written".
                ReaderException = ex.ToString();
            }
        }

        // Everything captured so far, without clearing it (repeated polling
        // during a still-running process needs the cumulative transcript,
        // not a one-shot drain).
        public string PeekOutput()
        {
            lock (_bufferLock) { return _outputBuffer.ToString(); }
        }

        // Writes 'text' (already including any line terminator the caller
        // wants) as UTF-8 bytes, exactly like a real keypress stream -
        // nothing is queued before the process starts, since this can only
        // be called on an already-running one. A pipe write completes as
        // soon as the bytes are handed to the OS buffer, so there is
        // nothing to separately flush (unlike the FileStream this replaced).
        public bool WriteInput(string text)
        {
            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(text);
                uint written;
                if (!WriteFile(_hInputWrite, bytes, (uint)bytes.Length, out written, IntPtr.Zero))
                {
                    LastError = "WriteFile failed, GetLastError=" + Marshal.GetLastWin32Error();
                    return false;
                }
                return true;
            }
            catch (Exception ex)
            {
                LastError = ex.ToString();
                return false;
            }
        }

        public bool WaitForExit(int timeoutMs)
        {
            if (_hProcess == IntPtr.Zero) return true;
            return WaitForSingleObject(_hProcess, (uint)timeoutMs) == WAIT_OBJECT_0;
        }

        public bool HasExited
        {
            get
            {
                if (_hProcess == IntPtr.Zero) return true;
                uint code;
                if (!GetExitCodeProcess(_hProcess, out code)) return true;
                return code != STILL_ACTIVE;
            }
        }

        public int ExitCode
        {
            get
            {
                uint code = unchecked((uint)(-1));
                if (_hProcess != IntPtr.Zero) GetExitCodeProcess(_hProcess, out code);
                return unchecked((int)code);
            }
        }

        public void Kill()
        {
            try { if (_hProcess != IntPtr.Zero) TerminateProcess(_hProcess, 1); } catch { }
        }

        public void Dispose()
        {
            _stopReader = true;

            // ClosePseudoConsole FIRST, before touching our own pipe
            // handles: it is what tears down the conhost session backing
            // this pseudoconsole, and conhost holds its own duplicated
            // write handle onto the output pipe for as long as it is
            // alive. Until that happens, the reader thread's blocking
            // ReadFile has a live writer on the other end and will not see
            // EOF no matter how long Dispose waits - closing our own read
            // handle out from under it first (the previous ordering) does
            // not fix that, it just turns a clean EOF into an
            // undefined-behaviour close-during-a-pending-synchronous-read.
            if (_hPC != IntPtr.Zero) { ClosePseudoConsole(_hPC); _hPC = IntPtr.Zero; }

            if (_readerThread != null)
            {
                try { _readerThread.Join(1000); } catch { }
            }

            if (_hInputWrite != IntPtr.Zero) { CloseHandle(_hInputWrite); _hInputWrite = IntPtr.Zero; }
            if (_hOutputRead != IntPtr.Zero) { CloseHandle(_hOutputRead); _hOutputRead = IntPtr.Zero; }
            if (_attrList != IntPtr.Zero) { DeleteProcThreadAttributeList(_attrList); Marshal.FreeHGlobal(_attrList); _attrList = IntPtr.Zero; }
            if (_hThread != IntPtr.Zero) { CloseHandle(_hThread); _hThread = IntPtr.Zero; }
            if (_hProcess != IntPtr.Zero) { CloseHandle(_hProcess); _hProcess = IntPtr.Zero; }
        }
    }
}
'@

# Compiles $script:ConPtySource exactly once per process (Add-Type throws on
# a redefinition, which dot-sourcing this file twice in one session would
# otherwise trigger).
function Initialize-ConPtyTypes {
    if (-not ("SudokuTests.ConPtyProcess" -as [type])) {
        Add-Type -TypeDefinition $script:ConPtySource -Language CSharp
    }
}

# Polls a redirected stdout/stderr file (see the sixth-round Start() comment
# above) until its content matches $Pattern or $TimeoutMs elapses. Returns
# @{ Matched; ElapsedMs; Text }. Never throws - a file that does not exist
# yet (the child hasn't opened it) reads as empty, not an error.
function Wait-ForRedirectedTextMatch {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][int]$TimeoutMs,
        [int]$PollMs = 100
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $text = ''
    while ($sw.Elapsed.TotalMilliseconds -lt $TimeoutMs) {
        $text = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
        if (-not $text) { $text = '' }
        if ($text -match $Pattern) {
            return @{ Matched = $true; ElapsedMs = $sw.Elapsed.TotalMilliseconds; Text = $text }
        }
        Start-Sleep -Milliseconds $PollMs
    }
    return @{ Matched = $false; ElapsedMs = $sw.Elapsed.TotalMilliseconds; Text = $text }
}

# Byte length of a redirected file, 0 if it does not exist yet - used to
# assert "stayed empty" against a real, independently-captured stream
# instead of inferring it from the merged ConPTY transcript's ordering.
function Get-RedirectedFileLength {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path) { return (Get-Item -LiteralPath $Path).Length }
    return 0
}

# Strips ANSI/VT escape sequences a real console's rendering can introduce
# (cursor moves, colour resets, ...) so content checks below can match
# against the plain text SudokuSolver.exe actually wrote, the same way a
# person glancing at the terminal would read it. SudokuSolver itself never
# emits VT sequences (docs/SDD.md §2.8's pinned wording is plain ASCII) —
# any that appear come from conhost's own console-to-VT translation.
function Remove-AnsiCodes {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $noCsi = [regex]::Replace($Text, "`e\[[0-9;?]*[a-zA-Z]", '')
    return [regex]::Replace($noCsi, "`e\][^`a]*(`a|`e\\)", '')
}

# Renders control characters visibly (<ESC>, <BEL>, <CR>, <LF>, <NUL> or
# <0xNN> for anything else non-printable) instead of stripping them, so a
# diagnostic dump shows exactly what arrived rather than what a filter
# thinks mattered. Used only for conpty-diag.txt (never for a TP content
# assertion, which stays on Remove-AnsiCodes's plain-text view) - the whole
# point here is to see past that filter when a result is unexpectedly empty.
function ConvertTo-VisibleEscapes {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int]$ch
        switch ($code) {
            0x1B { [void]$sb.Append('<ESC>'); break }
            0x07 { [void]$sb.Append('<BEL>'); break }
            0x0D { [void]$sb.Append('<CR>'); break }
            0x0A { [void]$sb.Append("<LF>`n"); break }
            0x00 { [void]$sb.Append('<NUL>'); break }
            default {
                if ($code -lt 0x20 -or $code -eq 0x7F) {
                    [void]$sb.Append("<0x$($code.ToString('X2'))>")
                }
                else {
                    [void]$sb.Append($ch)
                }
            }
        }
    }
    return $sb.ToString()
}

# Spawns $Exe under a real ConPTY. Never throws (C1) — a construction
# failure comes back as an object with Started = $false and LastError set,
# so the caller always has a specific reason to report rather than an
# unhandled exception. $EnvVars is applied to *this* process's environment
# only for the duration of the call (see ConPtyProcess.Start's doc comment).
function New-ConPtyProcess {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [string]$Arguments = '',
        [hashtable]$EnvVars = @{},
        [int]$Columns = 200,
        [int]$Rows = 40,
        # When given, $Exe is run under a cmd.exe intermediary with its
        # stdout/stderr redirected to these paths instead of being attached
        # to the pseudoconsole directly - see the Start() doc comment above
        # (sixth Windows round) for why. Stdin is unaffected either way: it
        # is always the real console handle.
        [string]$StdoutRedirectPath = $null,
        [string]$StderrRedirectPath = $null
    )

    try {
        Initialize-ConPtyTypes
    }
    catch {
        # Add-Type itself failed (e.g. the C# above doesn't compile against
        # this pwsh's Roslyn) - report it the same way a runtime ConPTY
        # failure would be reported, rather than letting it escape. Must
        # happen before New-Object below, which needs the type to exist.
        return [pscustomobject]@{
            Started    = $false
            LastError  = "Add-Type failed to compile the ConPTY wrapper: $($_.Exception.Message)"
            ProcessId  = $null
            IsFallback = $true
        }
    }

    $proc = New-Object SudokuTests.ConPtyProcess

    $previous = @{}
    foreach ($k in $EnvVars.Keys) {
        $previous[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, [string]$EnvVars[$k])
    }

    try {
        [void]$proc.Start($Exe, $Arguments, [int16]$Columns, [int16]$Rows, $StdoutRedirectPath, $StderrRedirectPath)
    }
    catch {
        # Start() is documented not to throw, but a marshalling-level
        # failure (e.g. CreatePseudoConsole simply doesn't exist as an
        # export on a pre-1809 image) could still surface as a .NET
        # exception rather than a false return - caught here so the probe
        # functions only ever have to check .Started.
    }
    finally {
        foreach ($k in $EnvVars.Keys) { [Environment]::SetEnvironmentVariable($k, $previous[$k]) }
    }

    return $proc
}

# Fifth Windows round (issue #25): rounds one through four established that
# CreatePseudoConsole/CreateProcessW/the pipe plumbing all succeed (a real
# child process is created, attached, and runs to a correct exit code) and
# that conhost's own *negotiation* burst (clear screen, hide/show cursor,
# set title - see conpty-diag.txt's "rawEscaped" dumps from prior rounds)
# reaches the reader thread intact. What never arrives, from *either*
# SudokuSolver.exe or a trivial `cmd.exe /c echo` control case, is any
# subsequently-*rendered* text - not delayed, not truncated, simply absent,
# even measured well after the child has fully exited (so it is not a
# buffering-before-flush question; the CRT/console API calls that would
# produce it are proven to have already returned by the time the process
# object signals termination). Two remaining, checkable explanations: (a)
# conhost's VT render pass needs a window station/desktop context this job
# doesn't have (a documented failure mode for console hosts run under a
# non-interactive service context) - probe (0) below checks that directly
# instead of inferring it; (b) something about *this* pseudoconsole's
# render pass specifically never fires a repaint after the first frame,
# independent of (a) - if (0) comes back "interactive", (b) becomes the
# live hypothesis instead and the cmd.exe control case (probe 1) already
# rules out anything SudokuSolver.exe-specific.
#
# Not asserted against any TP (C4/C5) - this is one .NET type compiled
# purely to read two OS facts (the window station handle's name and its
# WSF_VISIBLE flag), kept separate from ConPtyProcess above so a failure to
# compile *this* diagnostic can never take down the actual TP-004/005/006
# probes.
function Get-WindowStationDiagnostic {
    try {
        if (-not ("SudokuTests.WindowStationDiag" -as [type])) {
            Add-Type -Namespace SudokuTests -Name WindowStationDiag -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true)]
public static extern IntPtr GetProcessWindowStation();

// Same native GetUserObjectInformationW entry point, exposed twice under
// different managed signatures/names - once for the fixed-size
// USEROBJECTFLAGS struct (UOI_FLAGS=1), once for the station's own name
// (UOI_NAME=2), since P/Invoke cannot overload one extern method over two
// different marshaled buffer types.
[DllImport("user32.dll", EntryPoint = "GetUserObjectInformationW", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool GetUserObjectInformationFlags(IntPtr hObj, int nIndex, byte[] pvInfo, int nLength, out int lpnLengthNeeded);

[DllImport("user32.dll", EntryPoint = "GetUserObjectInformationW", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool GetUserObjectInformationName(IntPtr hObj, int nIndex, System.Text.StringBuilder pvInfo, int nLength, out int lpnLengthNeeded);
'@
        }
    }
    catch {
        return "WindowStationDiag failed to compile: $($_.Exception.Message)"
    }

    try {
        $hwinsta = [SudokuTests.WindowStationDiag]::GetProcessWindowStation()
        if ($hwinsta -eq [IntPtr]::Zero) {
            return "GetProcessWindowStation returned NULL, GetLastError=$([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }

        # USEROBJECTFLAGS is { BOOL fInherit; BOOL fReserved; DWORD dwFlags }
        # - three 4-byte fields, dwFlags at offset 8. WSF_VISIBLE = 0x0001.
        $buf = New-Object byte[] 12
        $needed = 0
        $flagsOk = [SudokuTests.WindowStationDiag]::GetUserObjectInformationFlags($hwinsta, 1, $buf, $buf.Length, [ref]$needed)
        $flagsText = if ($flagsOk) {
            $dwFlags = [System.BitConverter]::ToUInt32($buf, 8)
            "dwFlags=0x$($dwFlags.ToString('X8')) WSF_VISIBLE=$(($dwFlags -band 0x1) -ne 0)"
        }
        else {
            "GetUserObjectInformation(UOI_FLAGS) failed, GetLastError=$([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }

        $nameSb = New-Object System.Text.StringBuilder 256
        $nameNeeded = 0
        $nameOk = [SudokuTests.WindowStationDiag]::GetUserObjectInformationName($hwinsta, 2, $nameSb, $nameSb.Capacity, [ref]$nameNeeded)
        $nameText = if ($nameOk) { $nameSb.ToString() } else { '<name unavailable>' }

        return "windowStationName='$nameText' $flagsText dotnetUserInteractive=$([Environment]::UserInteractive)"
    }
    catch {
        return "window-station diagnostic threw: $($_.Exception.Message)"
    }
}

# Diagnostic only - never asserted against any TP, written straight to
# <EvidenceDir>/conpty-diag.txt rather than through Add-Check (C4/C5: the
# evidence ledger is for TP evidence, not harness self-diagnosis). Three
# independent probes, cheap (<= ~16s total), meant to bisect a "the real
# TP-004/005/006 probes saw nothing at all" result:
#   (0) window station / interactive-desktop check - see the fifth-round
#       comment above for why this is the live hypothesis.
#   (1) cmd.exe under ConPTY - isolates whether the ConPTY mechanism itself
#       (CreatePseudoConsole/CreateProcessW/the pipe plumbing) works on this
#       image at all, independent of SudokuSolver.exe.
#   (2) SudokuSolver.exe under ConPTY with a short (3s, not 15s+) hook -
#       isolates whether spawning the real exe and passing the
#       SUDOKU_DIAG_MIN_SOLVE_MS env var through produces any observable
#       output at all, without waiting for the first scheduled prompt.
function Invoke-ConPtyDiagnostics {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][string]$FixtureFile,
        [Parameter(Mandatory)][string]$EvidenceDir
    )

    $lines = New-Object System.Collections.Generic.List[string]

    try {
        $lines.Add('--- (0) window station / interactive-desktop check ---')
        $lines.Add((Get-WindowStationDiagnostic))
    }
    catch {
        $lines.Add("EXCEPTION in probe (0): $($_.Exception.Message)")
    }

    $lines.Add('')

    try {
        $comspec = $env:ComSpec
        if (-not $comspec) { $comspec = 'C:\Windows\System32\cmd.exe' }
        $lines.Add('--- (1) cmd.exe echo smoke test ---')
        $lines.Add("comspec=$comspec")
        $p1 = New-ConPtyProcess -Exe $comspec -Arguments '/c "echo CONPTY_SMOKE_OK & exit 7"' -Columns 120 -Rows 30
        $lines.Add("Started=$($p1.Started) LastError=$($p1.LastError) ProcessId=$($p1.ProcessId)")
        if ($p1.Started) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $seen = $false
            while ($sw.Elapsed.TotalSeconds -lt 8 -and -not $seen) {
                Start-Sleep -Milliseconds 200
                if ((Remove-AnsiCodes $p1.PeekOutput()) -match 'CONPTY_SMOKE_OK') { $seen = $true }
            }
            $exited = $p1.WaitForExit(3000)
            Start-Sleep -Milliseconds 300  # let the reader thread catch up to a just-exited process
            $lines.Add("seenMarker=$seen exited=$exited exitCode=$(if ($exited) { $p1.ExitCode } else { 'n/a' }) hasExited=$($p1.HasExited)")
            $lines.Add("readerThreadAlive=$($p1.ReaderThreadAlive) readerReadCallCount=$($p1.ReaderReadCallCount) totalBytesRead=$($p1.TotalBytesRead) readerException=$($p1.ReaderException)")
            $lines.Add('stripped: [' + (Remove-AnsiCodes $p1.PeekOutput()) + ']')
            $lines.Add('rawEscaped: [' + (ConvertTo-VisibleEscapes $p1.PeekOutput()) + ']')
            if (-not $exited) { $p1.Kill() }
            try { $p1.Dispose() } catch { }
        }
    }
    catch {
        $lines.Add("EXCEPTION in probe (1): $($_.Exception.Message)")
    }

    $lines.Add('')

    try {
        $lines.Add('--- (2) SudokuSolver.exe short-hook smoke test (3s hook, no wait for a 15s prompt) ---')
        $p2 = New-ConPtyProcess -Exe $Exe -Arguments ('"' + $FixtureFile + '"') `
            -EnvVars @{ SUDOKU_DIAG_MIN_SOLVE_MS = 3000 } -Columns 120 -Rows 30
        $lines.Add("Started=$($p2.Started) LastError=$($p2.LastError) ProcessId=$($p2.ProcessId)")
        if ($p2.Started) {
            $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
            while ($sw2.Elapsed.TotalSeconds -lt 8 -and -not $p2.HasExited) { Start-Sleep -Milliseconds 200 }
            Start-Sleep -Milliseconds 300  # let the reader thread catch up to a just-exited process
            $lines.Add("elapsedSec=$([math]::Round($sw2.Elapsed.TotalSeconds,1)) hasExitedAfter8s=$($p2.HasExited) exitCode=$(if ($p2.HasExited) { $p2.ExitCode } else { 'n/a' })")
            $lines.Add("readerThreadAlive=$($p2.ReaderThreadAlive) readerReadCallCount=$($p2.ReaderReadCallCount) totalBytesRead=$($p2.TotalBytesRead) readerException=$($p2.ReaderException)")
            $lines.Add('stripped: [' + (Remove-AnsiCodes $p2.PeekOutput()) + ']')
            $lines.Add('rawEscaped: [' + (ConvertTo-VisibleEscapes $p2.PeekOutput()) + ']')
            if (-not $p2.HasExited) { $p2.Kill() }
            try { $p2.Dispose() } catch { }
        }
    }
    catch {
        $lines.Add("EXCEPTION in probe (2): $($_.Exception.Message)")
    }

    $lines.Add('')

    # (3) Sixth Windows round: the same cmd.exe smoke test as probe (1),
    # but this time cmd's stdout/stderr are redirected to real files
    # (Start()'s stdoutRedirectPath/stderrRedirectPath) instead of being
    # attached to the pseudoconsole. Run in the same job as probes (1)/(2)
    # specifically so a single evidence artifact shows both results side by
    # side: if the marker shows up here but not in probe (1), that is
    # direct, controlled confirmation that conhost's render pass (not
    # process creation, not the input side, not this harness's env/argument
    # handling) is what drops output on this image - and that routing
    # around it, rather than continuing to debug it, is the correct fix.
    try {
        $comspec3 = $env:ComSpec
        if (-not $comspec3) { $comspec3 = 'C:\Windows\System32\cmd.exe' }
        $lines.Add('--- (3) cmd.exe echo smoke test, stdout/stderr redirected to files (the fix under test) ---')
        $diagDir = Join-Path $EvidenceDir 'conpty-diag-redirect'
        New-Item -ItemType Directory -Force -Path $diagDir | Out-Null
        $out3 = Join-Path $diagDir 'stdout.txt'
        $err3 = Join-Path $diagDir 'stderr.txt'
        Write-Utf8NoBom -Path $out3 -Content ''
        Write-Utf8NoBom -Path $err3 -Content ''
        $p3 = New-ConPtyProcess -Exe $comspec3 -Arguments '/c "echo CONPTY_REDIRECT_OK & echo CONPTY_REDIRECT_ERR 1>&2 & exit 7"' `
            -Columns 120 -Rows 30 -StdoutRedirectPath $out3 -StderrRedirectPath $err3
        $lines.Add("Started=$($p3.Started) LastError=$($p3.LastError) ProcessId=$($p3.ProcessId)")
        if ($p3.Started) {
            $exited3 = $p3.WaitForExit(8000)
            Start-Sleep -Milliseconds 300
            $stdoutText3 = Get-Content -LiteralPath $out3 -Raw -ErrorAction SilentlyContinue
            $stderrText3 = Get-Content -LiteralPath $err3 -Raw -ErrorAction SilentlyContinue
            $lines.Add("exited=$exited3 exitCode=$(if ($exited3) { $p3.ExitCode } else { 'n/a' })")
            $lines.Add("stdoutFile=[$stdoutText3] stderrFile=[$stderrText3]")
            if (-not $exited3) { $p3.Kill() }
            try { $p3.Dispose() } catch { }
        }
    }
    catch {
        $lines.Add("EXCEPTION in probe (3): $($_.Exception.Message)")
    }

    $lines.Add('')

    # (4) Seventh Windows round: probe (3) proved output redirection works;
    # the sixth round's real TP-005/TP-006 result (SHA 944bf63, workflow
    # 31886735121) showed TP-004 and three of TP-006's four clauses now
    # genuinely PASS with real console evidence, but the stop-response
    # itself was never recognised (StopExitCode/StopLatencyMs both blank -
    # the process just never exited within the wait window). The merged
    # transcript for that run shows nothing past ConPTY's own initial
    # handshake, but that is *expected* given the already-diagnosed broken
    # render pass on this image and proves nothing about whether the typed
    # keystroke ever reached the console's input buffer - rendering and
    # input are separate paths in conhost, and only the former is known
    # broken here. This probe isolates that specific question: does a byte
    # written via WriteInput reach a process reading stdin, under the exact
    # same two-level "ConPTY -> cmd.exe -> reader" plumbing the real
    # TP-005/TP-006 probes use (StdoutRedirectPath given, so the answer
    # comes back on an independently-captured file, not the broken
    # transcript) - using cmd.exe's own `set /p` builtin as the reader
    # instead of SudokuSolver.exe, so a positive or negative result here
    # attributes cleanly to the input path itself, not to anything specific
    # to the product under test.
    try {
        $comspec4 = $env:ComSpec
        if (-not $comspec4) { $comspec4 = 'C:\Windows\System32\cmd.exe' }
        $lines.Add('--- (4) console input round-trip test (WriteInput -> nested cmd.exe "set /p"), same redirect-wrapper shape as the real TP-004..006 probes ---')
        $diagDir4 = Join-Path $EvidenceDir 'conpty-diag-input'
        New-Item -ItemType Directory -Force -Path $diagDir4 | Out-Null
        $out4 = Join-Path $diagDir4 'stdout.txt'
        $err4 = Join-Path $diagDir4 'stderr.txt'
        Write-Utf8NoBom -Path $out4 -Content ''
        Write-Utf8NoBom -Path $err4 -Content ''
        # !REPLY! (not %REPLY%): cmd.exe expands %-variables once, when it
        # first parses the whole line, which is before `set /p` has run -
        # the classic reason "set /p X=&echo %X%" on one line prints the
        # *old* value. !REPLY! defers the expansion to execution time,
        # after set /p has actually assigned it - BUT only once delayed
        # expansion is already active *before* this line is parsed.
        # `setlocal enabledelayedexpansion & ... & echo !REPLY!` on a
        # single line does NOT work: cmd.exe decides how to treat every `!`
        # on a line at the moment it starts parsing that line, before any
        # of the line's own commands (including the setlocal on it) have
        # run - the well-known "can't enable and use delayed expansion on
        # the same line" gotcha, and a real bug in the first version of
        # this probe (round 7): its "inputReachedAndWasRead=False" result
        # (literal text "GOT:!REPLY!" in stdoutFile) is exactly what that
        # bug produces regardless of whether WriteInput's bytes ever
        # reached cmd.exe at all, so it proved nothing. `/V:ON` enables
        # delayed expansion for the entire cmd.exe instance before it reads
        # any command, which is unaffected by this gotcha.
        # Round 8: /V:ON alone did NOT fix it (still literal "GOT:!REPLY!")
        # - a second, independent bug in this probe, not a second real
        # finding. -StdoutRedirectPath/-StderrRedirectPath make Start()
        # wrap $comspec4 in *another* cmd.exe /c layer (see Start()'s own
        # doc comment), so this was actually running
        # `cmd /c "cmd /V:ON /c "set /p REPLY=& echo GOT:!REPLY!" 1>out 2>err"`
        # - a doubly-nested command line whose quoting cmd.exe's own
        # ambiguous /C-argument stripping cannot be trusted to parse the
        # way intended (exactly the hazard the "doubled outer quote"
        # comment on Start() itself warns about, self-inflicted here by
        # nesting a second /V:ON /c inside it). Redirection is now inline
        # in this probe's own single /c string instead, so $comspec4 is
        # attached to the pseudoconsole directly - one level of cmd.exe,
        # not two. EvidenceDir is the GitHub Actions workspace root
        # (D:\a\...\..., confirmed space-free in every prior round's
        # transcript path), so the redirect targets need no quoting of
        # their own within this single-quoted /c string.
        $argString4 = '/V:ON /c "set /p REPLY=& echo GOT:!REPLY! 1>' + $out4 + ' 2>' + $err4 + '"'
        $p4 = New-ConPtyProcess -Exe $comspec4 -Arguments $argString4 -Columns 120 -Rows 30
        $lines.Add("Started=$($p4.Started) LastError=$($p4.LastError) ProcessId=$($p4.ProcessId)")
        if ($p4.Started) {
            # `set /p` needs a moment to actually be waiting on stdin before
            # a write is guaranteed to be read as its answer rather than
            # raced against cmd.exe's own startup.
            Start-Sleep -Milliseconds 1000
            [void]$p4.WriteInput("hello`r")
            $exited4 = $p4.WaitForExit(5000)
            Start-Sleep -Milliseconds 300
            $stdoutText4 = Get-Content -LiteralPath $out4 -Raw -ErrorAction SilentlyContinue
            if (-not $stdoutText4) { $stdoutText4 = '' }
            $lines.Add("exited=$exited4 exitCode=$(if ($exited4) { $p4.ExitCode } else { 'n/a' })")
            $lines.Add("stdoutFile=[$stdoutText4]")
            $lines.Add("inputReachedAndWasRead=$([bool]($stdoutText4 -match 'GOT:hello'))")
            if (-not $exited4) { $p4.Kill() }
            try { $p4.Dispose() } catch { }
        }
    }
    catch {
        $lines.Add("EXCEPTION in probe (4): $($_.Exception.Message)")
    }

    $lines.Add('')

    # (5) Eighth Windows round: probe (4)'s round-8 fix did not resolve it
    # (still literal "GOT:!REPLY!" - see conpty-diag.txt from that run) and
    # cmd.exe's /V:ON/delayed-expansion behaviour is now a second suspect in
    # its own right, on top of the original question. That makes probe (4)
    # a test of "does cmd.exe's delayed expansion behave as documented
    # here", not cleanly "does console input reach a child process" -
    # continuing to debug cmd.exe's own quoting/expansion rules is chasing
    # a different bug than #25 is actually about. This probe asks the
    # original question directly instead, with no cmd.exe involved at all:
    # powershell.exe -EncodedCommand (Base64, so no quoting/escaping
    # hazard survives being embedded in Start()'s own cmd.exe /c redirect
    # wrapper) P/Invokes GetNumberOfConsoleInputEvents/ReadConsoleA - the
    # same two Win32 entry points StdinChannel.cpp's consoleLineReady/
    # tryNonBlockingRead call for the Console StdinKind - against its own
    # STD_INPUT_HANDLE, polling non-blocking for up to 20s the same way the
    # product does, then doing one ReadConsoleA once an event is pending.
    # A clean "EVENTS=1 LINE=[hello]" here is a direct, unambiguous answer:
    # console input delivery works on this image end to end, independent
    # of cmd.exe, independent of SudokuSolver.exe, independent of the
    # render pass already known broken.
    try {
        $lines.Add('--- (5) console input round-trip test via powershell.exe -EncodedCommand (GetNumberOfConsoleInputEvents/ReadConsoleA directly, no cmd.exe) ---')
        $diagDir5 = Join-Path $EvidenceDir 'conpty-diag-input-ps'
        New-Item -ItemType Directory -Force -Path $diagDir5 | Out-Null
        $out5 = Join-Path $diagDir5 'stdout.txt'
        $err5 = Join-Path $diagDir5 'stderr.txt'
        Write-Utf8NoBom -Path $out5 -Content ''
        Write-Utf8NoBom -Path $err5 -Content ''

        $psPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $psPath)) { $psPath = 'powershell.exe' }

        # Single-quoted here-string (@'...'@): nothing inside is
        # interpolated by *this* PowerShell before being embedded in the
        # child's -EncodedCommand payload.
        $childScript = @'
Add-Type -Namespace SudokuDiag -Name Con -MemberDefinition @"
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool GetNumberOfConsoleInputEvents(IntPtr hConsoleInput, out uint lpNumberOfEvents);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool ReadConsoleA(IntPtr hConsoleInput, byte[] lpBuffer, uint nNumberOfCharsToRead, out uint lpNumberOfCharsRead, IntPtr lpInputControl);
"@
$h = [SudokuDiag.Con]::GetStdHandle(-10)
$deadline = [DateTime]::UtcNow.AddSeconds(20)
$events = 0
while ([DateTime]::UtcNow -lt $deadline) {
    [uint32]$n = 0
    [void][SudokuDiag.Con]::GetNumberOfConsoleInputEvents($h, [ref]$n)
    if ($n -gt 0) { $events = $n; break }
    Start-Sleep -Milliseconds 100
}
$line = ''
if ($events -gt 0) {
    $buf = New-Object byte[] 256
    [uint32]$read = 0
    [void][SudokuDiag.Con]::ReadConsoleA($h, $buf, 256, [ref]$read, [IntPtr]::Zero)
    $line = [System.Text.Encoding]::ASCII.GetString($buf, 0, $read)
}
$visible = $line.Replace("`r", '<CR>').Replace("`n", '<LF>')
Write-Output ("EVENTS=" + $events + " LINE=[" + $visible + "]")
'@
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($childScript))
        $psArgs = "-NoProfile -NonInteractive -EncodedCommand $encoded"

        $p5 = New-ConPtyProcess -Exe $psPath -Arguments $psArgs -Columns 120 -Rows 30 -StdoutRedirectPath $out5 -StderrRedirectPath $err5
        $lines.Add("Started=$($p5.Started) LastError=$($p5.LastError) ProcessId=$($p5.ProcessId)")
        if ($p5.Started) {
            # The child polls internally for up to 20s (its own deadline
            # above) before giving up and printing EVENTS=0 - this needs to
            # wait at least that long, not race it.
            Start-Sleep -Milliseconds 1500
            $writeOk = $p5.WriteInput("hello`r")
            $writeErr = $p5.LastError
            $exited5 = $p5.WaitForExit(25000)
            Start-Sleep -Milliseconds 300
            $stdoutText5 = Get-Content -LiteralPath $out5 -Raw -ErrorAction SilentlyContinue
            $stderrText5 = Get-Content -LiteralPath $err5 -Raw -ErrorAction SilentlyContinue
            if (-not $stdoutText5) { $stdoutText5 = '' }
            if (-not $stderrText5) { $stderrText5 = '' }
            $lines.Add("writeInputOk=$writeOk writeInputError=$writeErr")
            $lines.Add("exited=$exited5 exitCode=$(if ($exited5) { $p5.ExitCode } else { 'n/a' })")
            $lines.Add("stdoutFile=[$stdoutText5] stderrFile=[$stderrText5]")
            $lines.Add("inputReachedConsoleInputBuffer=$([bool]($stdoutText5 -match 'EVENTS=[1-9]'))")
            $lines.Add("readConsoleAGotHello=$([bool]($stdoutText5 -match '<CR>' -or $stdoutText5 -match 'hello'))")
            if (-not $exited5) { $p5.Kill() }
            try { $p5.Dispose() } catch { }
        }
    }
    catch {
        $lines.Add("EXCEPTION in probe (5): $($_.Exception.Message)")
    }

    $lines.Add('')

    # (6) Ninth Windows round, second probe: probe (5) was *framed* as
    # cmd.exe-free ("no cmd.exe" in its own header line above) but is not,
    # in fact, cmd.exe-free - it passes StdoutRedirectPath/StderrRedirectPath,
    # and New-ConPtyProcess's Start() (see its doc comment) unconditionally
    # wraps $Exe in a `cmd.exe /c "... 1>out 2>err"` layer whenever either
    # redirect path is given. So probe (5)'s EVENTS=0 result still has
    # cmd.exe in the chain, exactly like probes (3)/(4) - it never actually
    # tested "does input reach a process with *nothing* else in the chain".
    # This probe does: powershell.exe attached to the pseudoconsole with
    # NEITHER redirect path given (true direct attachment - the same shape
    # SudokuSolver.exe itself has in the real TP-004/005/006 probes *before*
    # Start() adds any cmd wrapper), and the child reports its result with
    # [System.IO.File]::WriteAllText - a plain Win32 file write, not
    # Write-Output - so the answer does not depend on the render pass
    # already proven broken on this image (probe (1): cmd.exe's own echoed
    # text through the plain pty transcript never arrives past the initial
    # handshake). A clean "EVENTS=1 LINE=[hello]" here, with nothing else
    # anywhere in the chain, is the most direct answer this harness can
    # give to "does console input delivery work on this image at all".
    try {
        $lines.Add('--- (6) console input round-trip test, true direct attachment (no cmd.exe anywhere, no redirect wrapper) - result written to a file from inside the child, not through its own rendered stdout ---')
        $diagDir6 = Join-Path $EvidenceDir 'conpty-diag-input-direct'
        New-Item -ItemType Directory -Force -Path $diagDir6 | Out-Null
        $resultPath6 = Join-Path $diagDir6 'result.txt'
        if (Test-Path -LiteralPath $resultPath6) { Remove-Item -LiteralPath $resultPath6 -Force }

        $psPath6 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $psPath6)) { $psPath6 = 'powershell.exe' }

        # Same P/Invoke/poll shape as probe (5)'s child script; the only
        # difference is where the answer goes - a file, via plain .NET file
        # I/O, substituted in below as a literal single-quoted PowerShell
        # string (backslashes are not escapes inside single quotes, so the
        # raw Windows path substitutes in unmodified).
        $childScript6 = @'
Add-Type -Namespace SudokuDiag6 -Name Con -MemberDefinition @"
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool GetNumberOfConsoleInputEvents(IntPtr hConsoleInput, out uint lpNumberOfEvents);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool ReadConsoleA(IntPtr hConsoleInput, byte[] lpBuffer, uint nNumberOfCharsToRead, out uint lpNumberOfCharsRead, IntPtr lpInputControl);
"@
$h = [SudokuDiag6.Con]::GetStdHandle(-10)
$deadline = [DateTime]::UtcNow.AddSeconds(20)
$events = 0
while ([DateTime]::UtcNow -lt $deadline) {
    [uint32]$n = 0
    [void][SudokuDiag6.Con]::GetNumberOfConsoleInputEvents($h, [ref]$n)
    if ($n -gt 0) { $events = $n; break }
    Start-Sleep -Milliseconds 100
}
$line = ''
if ($events -gt 0) {
    $buf = New-Object byte[] 256
    [uint32]$read = 0
    [void][SudokuDiag6.Con]::ReadConsoleA($h, $buf, 256, [ref]$read, [IntPtr]::Zero)
    $line = [System.Text.Encoding]::ASCII.GetString($buf, 0, $read)
}
$visible = $line.Replace("`r", '<CR>').Replace("`n", '<LF>')
[System.IO.File]::WriteAllText('__RESULT_PATH__', 'EVENTS=' + $events + ' LINE=[' + $visible + ']')
'@
        $childScript6 = $childScript6.Replace('__RESULT_PATH__', $resultPath6)
        $encoded6 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($childScript6))
        $psArgs6 = "-NoProfile -NonInteractive -EncodedCommand $encoded6"

        # No StdoutRedirectPath/StderrRedirectPath here - unlike probe (5),
        # this really is one process (powershell.exe) attached to the
        # pseudoconsole directly, nothing else in the chain.
        $p6 = New-ConPtyProcess -Exe $psPath6 -Arguments $psArgs6 -Columns 120 -Rows 30
        $lines.Add("Started=$($p6.Started) LastError=$($p6.LastError) ProcessId=$($p6.ProcessId)")
        if ($p6.Started) {
            # Same 1.5s settle as probe (5) before writing - the child polls
            # internally for up to 20s before giving up, so this needs to
            # wait at least that long too, not race it.
            Start-Sleep -Milliseconds 1500
            $writeOk6 = $p6.WriteInput("hello`r")
            $writeErr6 = $p6.LastError
            $exited6 = $p6.WaitForExit(25000)
            Start-Sleep -Milliseconds 300
            $resultText6 = Get-Content -LiteralPath $resultPath6 -Raw -ErrorAction SilentlyContinue
            if (-not $resultText6) { $resultText6 = '(result.txt not written - child never reached the WriteAllText call, or was killed first)' }
            $lines.Add("writeInputOk=$writeOk6 writeInputError=$writeErr6")
            $lines.Add("exited=$exited6 exitCode=$(if ($exited6) { $p6.ExitCode } else { 'n/a' })")
            $lines.Add("resultFile=[$resultText6]")
            $lines.Add("inputReachedConsoleInputBuffer=$([bool]($resultText6 -match 'EVENTS=[1-9]'))")
            $lines.Add("readConsoleAGotHello=$([bool]($resultText6 -match 'hello'))")
            if (-not $exited6) { $p6.Kill() }
            try { $p6.Dispose() } catch { }
        }
    }
    catch {
        $lines.Add("EXCEPTION in probe (6): $($_.Exception.Message)")
    }

    Write-Utf8NoBom -Path (Join-Path $EvidenceDir 'conpty-diag.txt') -Content ($lines -join "`n")
}

# ---------------------------------------------------------------------------
# TP-004 / TP-006 — one long-lived session: the first prompt (TP-004's
# content/timing/nothing-on-stdout-yet clause) plus all four scheduled
# prompts through 45s and the final stop-and-exit (TP-006).
#
# Sixth Windows round (issue #25): reads $Exe's stderr/stdout off the real,
# independently-redirected files (StdoutRedirectPath/StderrRedirectPath -
# see the Start() doc comment) instead of the merged ConPTY transcript the
# first five rounds depended on and which never delivered $Exe's actual
# character output on this image. Stdin is still the genuine console handle
# - only where stdout/stderr are read from changed. The transcript is still
# captured to disk (RawOutputPath) as a diagnostic, but nothing below is
# decided from it any more.
# ---------------------------------------------------------------------------
function Invoke-ConPty004006Probe {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][string]$FixtureFile,
        [Parameter(Mandatory)][string]$EvidenceDir,
        [int]$HookMs = 70000
    )

    $result = [ordered]@{
        Started                   = $false
        StartError                = $null
        PromptTimestampsSec       = @()
        FirstPromptText           = $null
        GridSeenBeforeFirstPrompt = $false
        StdoutBytesAtFirstPrompt  = $null
        MaxGapAfterFirstPromptSec = $null
        StillRunningAfterFourth   = $false
        StopExitCode              = $null
        StopLatencyMs             = $null
        StopWriteOk               = $null
        StopWriteError            = $null
        PromptsAfterStopAttempt   = $null
        RawOutputPath             = $null
        StdoutPath                = $null
        StderrPath                = $null
    }

    $rawDir = Join-Path $EvidenceDir 'runs/TP-004-006-conpty'
    New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
    $out = Join-Path $rawDir 'stdout.txt'
    $err = Join-Path $rawDir 'stderr.txt'
    Write-Utf8NoBom -Path $out -Content ''
    Write-Utf8NoBom -Path $err -Content ''
    $result.StdoutPath = $out
    $result.StderrPath = $err

    $proc = New-ConPtyProcess -Exe $Exe -Arguments ('"' + $FixtureFile + '"') `
        -EnvVars @{ SUDOKU_DIAG_MIN_SOLVE_MS = $HookMs } -Columns 200 -Rows 40 `
        -StdoutRedirectPath $out -StderrRedirectPath $err
    if (-not $proc -or -not $proc.Started) {
        $result.StartError = if ($proc) { $proc.LastError } else { 'New-ConPtyProcess returned nothing' }
        return $result
    }
    $result.Started = $true

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $seenTimestamps = New-Object System.Collections.Generic.List[double]

    # Ceiling, not a sleep-until: four prompts nominally land by 45s, so 55s
    # leaves margin without letting a stuck run hold the CI job open.
    while ($sw.Elapsed.TotalSeconds -lt 55 -and $seenTimestamps.Count -lt 4) {
        Start-Sleep -Milliseconds 200
        $errText = Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue
        if (-not $errText) { $errText = '' }
        $matches = [regex]::Matches($errText, 'Still working \(\d+s elapsed\)\.')
        for ($i = $seenTimestamps.Count; $i -lt $matches.Count; $i++) {
            $seenTimestamps.Add([math]::Round($sw.Elapsed.TotalSeconds, 2))
            if ($i -eq 0) { $result.StdoutBytesAtFirstPrompt = Get-RedirectedFileLength -Path $out }
        }
    }
    $result.PromptTimestampsSec = @($seenTimestamps)

    $errFull = Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue
    if (-not $errFull) { $errFull = '' }
    if ($seenTimestamps.Count -ge 1) {
        $firstIdx = $errFull.IndexOf('Still working')
        if ($firstIdx -ge 0) {
            $endIdx = $errFull.IndexOf("`n", $firstIdx)
            $result.FirstPromptText = if ($endIdx -gt $firstIdx) { $errFull.Substring($firstIdx, $endIdx - $firstIdx).TrimEnd("`r") } else { $errFull.Substring($firstIdx).TrimEnd("`r", "`n") }
        }
        # A real, independently-captured stream now, not an inference from
        # transcript ordering (see the "sixth Windows round" comment above).
        $result.GridSeenBeforeFirstPrompt = ($result.StdoutBytesAtFirstPrompt -gt 0)
    }

    if ($seenTimestamps.Count -ge 2) {
        $gaps = for ($i = 1; $i -lt $seenTimestamps.Count; $i++) { $seenTimestamps[$i] - $seenTimestamps[$i - 1] }
        $result.MaxGapAfterFirstPromptSec = ($gaps | Measure-Object -Maximum).Maximum
    }

    $result.StillRunningAfterFourth = ($seenTimestamps.Count -ge 4) -and (-not $proc.HasExited)

    # TP-006's closing step: send the stop response and confirm exit 3.
    $stopSw = [System.Diagnostics.Stopwatch]::StartNew()
    $countAtStop = $seenTimestamps.Count
    $result.StopWriteOk = $proc.WriteInput("s`r")
    $result.StopWriteError = $proc.LastError
    $exited = $proc.WaitForExit(5000)
    $stopSw.Stop()
    if ($exited) {
        $result.StopExitCode = $proc.ExitCode
        $result.StopLatencyMs = [math]::Round($stopSw.Elapsed.TotalMilliseconds, 1)
    }
    else {
        # Distinguishes "the stop response was never recognised" (the
        # process just keeps running and prompting on its normal schedule,
        # as if nothing had been typed) from "recognised but slow to
        # actually exit" - both look identical as a bare WaitForExit
        # timeout otherwise, and the issue's own instruction is a specific
        # negative result, not a vague one. Watches for one more scheduled
        # prompt (~10s after the fourth, per RTVM-502) rather than giving
        # up the instant the 5s exit-wait elapses.
        $keepWatching = [System.Diagnostics.Stopwatch]::StartNew()
        $result.PromptsAfterStopAttempt = 0
        while ($keepWatching.Elapsed.TotalSeconds -lt 15 -and -not $proc.HasExited) {
            Start-Sleep -Milliseconds 200
            $errText2 = Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue
            if (-not $errText2) { $errText2 = '' }
            $countNow = ([regex]::Matches($errText2, 'Still working \(\d+s elapsed\)\.')).Count
            $result.PromptsAfterStopAttempt = $countNow - $countAtStop
            if ($result.PromptsAfterStopAttempt -gt 0) { break }
        }
    }
    if (-not $exited) { $proc.Kill() }

    Start-Sleep -Milliseconds 200
    $rawPath = Join-Path $rawDir 'transcript.txt'
    Write-Utf8NoBom -Path $rawPath -Content (Remove-AnsiCodes $proc.PeekOutput())
    Write-Utf8NoBom -Path (Join-Path $rawDir 'transcript-raw-escaped.txt') -Content (ConvertTo-VisibleEscapes $proc.PeekOutput())
    $result.RawOutputPath = $rawPath

    try { $proc.Dispose() } catch { }
    return $result
}

# ---------------------------------------------------------------------------
# TP-005 — a dedicated, shorter session: respond at the *first* prompt
# specifically (TP-005's own wording), not the fourth, and measure the
# response-to-exit latency RTVM-203/TP-005 bound at 1.0s.
#
# Sixth Windows round: same StdoutRedirectPath/StderrRedirectPath change as
# Invoke-ConPty004006Probe above - "stdout stayed empty" is now a real
# byte-length check on an independently-captured file, not an inference
# from the merged transcript.
# ---------------------------------------------------------------------------
function Invoke-ConPty005Probe {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][string]$FixtureFile,
        [Parameter(Mandatory)][string]$EvidenceDir,
        [int]$HookMs = 60000
    )

    $result = [ordered]@{
        Started            = $false
        StartError         = $null
        FirstPromptSeconds = $null
        StopExitCode       = $null
        StopLatencyMs      = $null
        StopWriteOk        = $null
        StopWriteError     = $null
        AbandonedTextSeen  = $false
        StdoutStayedEmpty  = $null
        RawOutputPath      = $null
        StdoutPath         = $null
        StderrPath         = $null
    }

    $rawDir = Join-Path $EvidenceDir 'runs/TP-005-conpty'
    New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
    $out = Join-Path $rawDir 'stdout.txt'
    $err = Join-Path $rawDir 'stderr.txt'
    Write-Utf8NoBom -Path $out -Content ''
    Write-Utf8NoBom -Path $err -Content ''
    $result.StdoutPath = $out
    $result.StderrPath = $err

    $proc = New-ConPtyProcess -Exe $Exe -Arguments ('"' + $FixtureFile + '"') `
        -EnvVars @{ SUDOKU_DIAG_MIN_SOLVE_MS = $HookMs } -Columns 200 -Rows 40 `
        -StdoutRedirectPath $out -StderrRedirectPath $err
    if (-not $proc -or -not $proc.Started) {
        $result.StartError = if ($proc) { $proc.LastError } else { 'New-ConPtyProcess returned nothing' }
        return $result
    }
    $result.Started = $true

    $wait = Wait-ForRedirectedTextMatch -Path $err -Pattern 'Still working \(\d+s elapsed\)\.' -TimeoutMs 25000 -PollMs 150

    if ($wait.Matched) {
        $result.FirstPromptSeconds = [math]::Round($wait.ElapsedMs / 1000.0, 2)
        $stopSw = [System.Diagnostics.Stopwatch]::StartNew()
        $result.StopWriteOk = $proc.WriteInput("s`r")
        $result.StopWriteError = $proc.LastError
        $exited = $proc.WaitForExit(5000)
        $stopSw.Stop()
        if ($exited) {
            $result.StopExitCode = $proc.ExitCode
            $result.StopLatencyMs = [math]::Round($stopSw.Elapsed.TotalMilliseconds, 1)
        }
        if (-not $exited) { $proc.Kill() }
        Start-Sleep -Milliseconds 200
        $finalErr = Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue
        if (-not $finalErr) { $finalErr = '' }
        $result.AbandonedTextSeen = [bool]($finalErr -match '(?i)abandoned at')
        $result.StdoutStayedEmpty = ((Get-RedirectedFileLength -Path $out) -eq 0)
    }

    $rawPath = Join-Path $rawDir 'transcript.txt'
    Write-Utf8NoBom -Path $rawPath -Content (Remove-AnsiCodes $proc.PeekOutput())
    Write-Utf8NoBom -Path (Join-Path $rawDir 'transcript-raw-escaped.txt') -Content (ConvertTo-VisibleEscapes $proc.PeekOutput())
    $result.RawOutputPath = $rawPath

    try { $proc.Dispose() } catch { }
    return $result
}
