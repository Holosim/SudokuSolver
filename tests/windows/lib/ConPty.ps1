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
        // Never throws — every failure path sets LastError and returns
        // false, so a caller can always report a specific reason rather
        // than an unhandled exception (mirrors Common.ps1's C1).
        public bool Start(string exePath, string arguments, short columns, short rows)
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

                string fullCommand = "\"" + exePath + "\"" + (string.IsNullOrEmpty(arguments) ? "" : " " + arguments);
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
        [int]$Rows = 40
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
        [void]$proc.Start($Exe, $Arguments, [int16]$Columns, [int16]$Rows)
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

    Write-Utf8NoBom -Path (Join-Path $EvidenceDir 'conpty-diag.txt') -Content ($lines -join "`n")
}

# ---------------------------------------------------------------------------
# TP-004 / TP-006 — one long-lived session: the first prompt (TP-004's
# content/timing/nothing-on-stdout-yet clause) plus all four scheduled
# prompts through 45s and the final stop-and-exit (TP-006).
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
        MaxGapAfterFirstPromptSec = $null
        StillRunningAfterFourth   = $false
        StopExitCode              = $null
        StopLatencyMs             = $null
        RawOutputPath             = $null
        TotalBytesRead            = $null
        ReaderReadCallCount       = $null
    }

    $proc = New-ConPtyProcess -Exe $Exe -Arguments ('"' + $FixtureFile + '"') `
        -EnvVars @{ SUDOKU_DIAG_MIN_SOLVE_MS = $HookMs } -Columns 200 -Rows 40
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
        $clean = Remove-AnsiCodes $proc.PeekOutput()
        $matches = [regex]::Matches($clean, 'Still working \(\d+s elapsed\)\.')
        for ($i = $seenTimestamps.Count; $i -lt $matches.Count; $i++) {
            $seenTimestamps.Add([math]::Round($sw.Elapsed.TotalSeconds, 2))
        }
    }
    $result.PromptTimestampsSec = @($seenTimestamps)

    $full = Remove-AnsiCodes $proc.PeekOutput()
    if ($seenTimestamps.Count -ge 1) {
        $firstIdx = $full.IndexOf('Still working')
        if ($firstIdx -ge 0) {
            $endIdx = $full.IndexOf("`n", $firstIdx)
            $result.FirstPromptText = if ($endIdx -gt $firstIdx) { $full.Substring($firstIdx, $endIdx - $firstIdx).TrimEnd("`r") } else { $full.Substring($firstIdx).TrimEnd("`r", "`n") }
            $beforeFirst = $full.Substring(0, $firstIdx)
            $result.GridSeenBeforeFirstPrompt = [bool]($beforeFirst -match '\+-------\+')
        }
    }

    if ($seenTimestamps.Count -ge 2) {
        $gaps = for ($i = 1; $i -lt $seenTimestamps.Count; $i++) { $seenTimestamps[$i] - $seenTimestamps[$i - 1] }
        $result.MaxGapAfterFirstPromptSec = ($gaps | Measure-Object -Maximum).Maximum
    }

    $result.StillRunningAfterFourth = ($seenTimestamps.Count -ge 4) -and (-not $proc.HasExited)

    # TP-006's closing step: send the stop response and confirm exit 3.
    $stopSw = [System.Diagnostics.Stopwatch]::StartNew()
    [void]$proc.WriteInput("s`r")
    $exited = $proc.WaitForExit(5000)
    $stopSw.Stop()
    if ($exited) {
        $result.StopExitCode = $proc.ExitCode
        $result.StopLatencyMs = [math]::Round($stopSw.Elapsed.TotalMilliseconds, 1)
    }
    if (-not $exited) { $proc.Kill() }

    Start-Sleep -Milliseconds 200
    $result.TotalBytesRead = $proc.TotalBytesRead
    $result.ReaderReadCallCount = $proc.ReaderReadCallCount
    $rawDir = Join-Path $EvidenceDir 'runs/TP-004-006-conpty'
    New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
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
# ---------------------------------------------------------------------------
function Invoke-ConPty005Probe {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][string]$FixtureFile,
        [Parameter(Mandatory)][string]$EvidenceDir,
        [int]$HookMs = 60000
    )

    $result = [ordered]@{
        Started           = $false
        StartError        = $null
        FirstPromptSeconds = $null
        StopExitCode      = $null
        StopLatencyMs     = $null
        AbandonedTextSeen = $false
        StdoutStayedEmpty = $null
        RawOutputPath     = $null
        TotalBytesRead    = $null
        ReaderReadCallCount = $null
    }

    $proc = New-ConPtyProcess -Exe $Exe -Arguments ('"' + $FixtureFile + '"') `
        -EnvVars @{ SUDOKU_DIAG_MIN_SOLVE_MS = $HookMs } -Columns 200 -Rows 40
    if (-not $proc -or -not $proc.Started) {
        $result.StartError = if ($proc) { $proc.LastError } else { 'New-ConPtyProcess returned nothing' }
        return $result
    }
    $result.Started = $true

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $seen = $false
    while ($sw.Elapsed.TotalSeconds -lt 25 -and -not $seen) {
        Start-Sleep -Milliseconds 150
        $clean = Remove-AnsiCodes $proc.PeekOutput()
        if ($clean -match 'Still working \(\d+s elapsed\)\.') { $seen = $true }
    }

    if ($seen) {
        $result.FirstPromptSeconds = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        $stopSw = [System.Diagnostics.Stopwatch]::StartNew()
        [void]$proc.WriteInput("s`r")
        $exited = $proc.WaitForExit(5000)
        $stopSw.Stop()
        if ($exited) {
            $result.StopExitCode = $proc.ExitCode
            $result.StopLatencyMs = [math]::Round($stopSw.Elapsed.TotalMilliseconds, 1)
        }
        if (-not $exited) { $proc.Kill() }
        Start-Sleep -Milliseconds 200
        $final = Remove-AnsiCodes $proc.PeekOutput()
        $result.AbandonedTextSeen = [bool]($final -match '(?i)abandoned at')
        $result.StdoutStayedEmpty = -not [bool]($final -match '\+-------\+')
    }

    $result.TotalBytesRead = $proc.TotalBytesRead
    $result.ReaderReadCallCount = $proc.ReaderReadCallCount
    $rawDir = Join-Path $EvidenceDir 'runs/TP-005-conpty'
    New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
    $rawPath = Join-Path $rawDir 'transcript.txt'
    Write-Utf8NoBom -Path $rawPath -Content (Remove-AnsiCodes $proc.PeekOutput())
    Write-Utf8NoBom -Path (Join-Path $rawDir 'transcript-raw-escaped.txt') -Content (ConvertTo-VisibleEscapes $proc.PeekOutput())
    $result.RawOutputPath = $rawPath

    try { $proc.Dispose() } catch { }
    return $result
}
