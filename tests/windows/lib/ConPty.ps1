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

Set-StrictMode -Off

$script:ConPtySource = @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32.SafeHandles;
using System.IO;

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
        private FileStream _inputStream;
        private FileStream _outputStream;
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

                _inputStream = new FileStream(new SafeFileHandle(inputWrite, true), FileAccess.Write, 4096, false);
                _outputStream = new FileStream(new SafeFileHandle(outputRead, true), FileAccess.Read, 4096, false);
                inputWrite = IntPtr.Zero;  // ownership moved into the FileStream/SafeFileHandle
                outputRead = IntPtr.Zero;

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

        private void ReaderLoop()
        {
            var buf = new byte[4096];
            try
            {
                while (!_stopReader)
                {
                    int n = _outputStream.Read(buf, 0, buf.Length);
                    Interlocked.Increment(ref ReaderReadCallCount);
                    if (n <= 0) break;
                    string text = Encoding.UTF8.GetString(buf, 0, n);
                    lock (_bufferLock) { _outputBuffer.Append(text); }
                }
            }
            catch (Exception ex)
            {
                // Recorded rather than swallowed (issue #25 diagnostics) -
                // the stream being closed under us at Dispose time is the
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
        // wants) as UTF-8 bytes and flushes immediately, exactly like a
        // real keypress stream — nothing is queued before the process
        // starts, since this can only be called on an already-running one.
        public bool WriteInput(string text)
        {
            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(text);
                _inputStream.Write(bytes, 0, bytes.Length);
                _inputStream.Flush();
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
            try { if (_inputStream != null) _inputStream.Dispose(); } catch { }
            try { if (_outputStream != null) _outputStream.Dispose(); } catch { }
            if (_readerThread != null)
            {
                try { _readerThread.Join(500); } catch { }
            }
            if (_hPC != IntPtr.Zero) { ClosePseudoConsole(_hPC); _hPC = IntPtr.Zero; }
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

# Diagnostic only - never asserted against any TP, written straight to
# <EvidenceDir>/conpty-diag.txt rather than through Add-Check (C4/C5: the
# evidence ledger is for TP evidence, not harness self-diagnosis). Two
# independent probes, cheap (<= ~16s total), meant to bisect a "the real
# TP-004/005/006 probes saw nothing at all" result:
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
            $lines.Add("readerThreadAlive=$($p1.ReaderThreadAlive) readerReadCallCount=$($p1.ReaderReadCallCount) readerException=$($p1.ReaderException)")
            $lines.Add('raw: [' + (Remove-AnsiCodes $p1.PeekOutput()) + ']')
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
            $lines.Add("readerThreadAlive=$($p2.ReaderThreadAlive) readerReadCallCount=$($p2.ReaderReadCallCount) readerException=$($p2.ReaderException)")
            $lines.Add('raw: [' + (Remove-AnsiCodes $p2.PeekOutput()) + ']')
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
    $rawDir = Join-Path $EvidenceDir 'runs/TP-004-006-conpty'
    New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
    $rawPath = Join-Path $rawDir 'transcript.txt'
    Write-Utf8NoBom -Path $rawPath -Content (Remove-AnsiCodes $proc.PeekOutput())
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

    $rawDir = Join-Path $EvidenceDir 'runs/TP-005-conpty'
    New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
    $rawPath = Join-Path $rawDir 'transcript.txt'
    Write-Utf8NoBom -Path $rawPath -Content (Remove-AnsiCodes $proc.PeekOutput())
    $result.RawOutputPath = $rawPath

    try { $proc.Dispose() } catch { }
    return $result
}
