# Fixtures.ps1 — §6.1 puzzle fixtures and the §6.2 reference output block,
# reproduced exactly from docs/RTVM.md so the Windows evidence scripts don't
# have to keep a second, driftable copy of each mutation by hand.
#
# Every mutated fixture (P-LONGLINE, P-BADCHAR, ...) is derived
# programmatically from $script:PEasyLines rather than retyped, because a
# hand-retyped 9-character row is exactly the kind of thing that goes
# unnoticed when wrong. Get-SelfCheckFailures() below re-derives the one
# fixture whose *output* is quoted verbatim in the RTVM (S-EASY) and
# compares byte for byte, so a bug in ConvertTo-GridBlock (Common.ps1) is
# caught before it's trusted as an oracle for TP-400/401.
#
# docs/RTVM.md §6.1, §6.2. Not part of any .vcxproj (C7 / D-7 / V-7).

. (Join-Path $PSScriptRoot 'Common.ps1')

$script:PEasyLines = @(
    '530070000', '600195000', '098000060', '800060003', '400803001',
    '700020006', '060000280', '000419005', '000080079'
)

$script:SEasyLines = @(
    '534678912', '672195348', '198342567', '859761423', '426853791',
    '713924856', '961537284', '287419635', '345286179'
)

$script:SHard17Lines = @(
    '693784512', '487512936', '125963874', '932651487', '568247391',
    '741398625', '319475268', '856129743', '274836159'
)

# §6.2, quoted verbatim. This is the oracle; ConvertTo-GridBlock is checked
# against it in Get-SelfCheckFailures, not the other way round.
$script:SEasyBlockLiteral = (@(
    '+-------+-------+-------+',
    '| 5 3 4 | 6 7 8 | 9 1 2 |',
    '| 6 7 2 | 1 9 5 | 3 4 8 |',
    '| 1 9 8 | 3 4 2 | 5 6 7 |',
    '+-------+-------+-------+',
    '| 8 5 9 | 7 6 1 | 4 2 3 |',
    '| 4 2 6 | 8 5 3 | 7 9 1 |',
    '| 7 1 3 | 9 2 4 | 8 5 6 |',
    '+-------+-------+-------+',
    '| 9 6 1 | 5 3 7 | 2 8 4 |',
    '| 2 8 7 | 4 1 9 | 6 3 5 |',
    '| 3 4 5 | 2 8 6 | 1 7 9 |',
    '+-------+-------+-------+'
) -join "`n") + "`n"

function Get-SEasyBlock { return $script:SEasyBlockLiteral }
function Get-SHard17Block { return (ConvertTo-GridBlock -Rows $script:SHard17Lines) }

# Returns any mismatches between the literal §6.2 block and the block
# ConvertTo-GridBlock derives from $SEasyLines — an empty array means the
# renderer can be trusted for fixtures (like S-HARD17) that aren't quoted
# verbatim anywhere in the RTVM.
function Get-SelfCheckFailures {
    $failures = New-Object System.Collections.Generic.List[string]
    $derived = ConvertTo-GridBlock -Rows $script:SEasyLines
    if ($derived -ne $script:SEasyBlockLiteral) {
        $failures.Add('ConvertTo-GridBlock(S-EASY) does not reproduce the literal §6.2 block byte for byte')
    }
    # See the comment in Common.ps1's New-CheckList: a List<T> returned
    # without the leading comma gets unrolled by the pipeline, so an empty
    # (i.e. all-clear) result would come back as $null instead of an empty
    # list - which would then fail a truthiness check meant to mean "no
    # failures" and would look exactly like "no failures", the one outcome
    # this self-check exists to distinguish from a genuine pass.
    return , $failures
}

# Ordered map of §6.1 puzzle fixture name -> 9 lines of 9 characters each.
# Includes only inputs (P-*); the solution fixtures (S-*) are exposed
# separately above since only P-EASY's and P-NONUNIQUE's solutions are
# needed as text, not run as input.
function Get-Fixtures {
    $lines = $script:PEasyLines
    $f = [ordered]@{}

    $f['P-EASY'] = $lines
    $f['P-EASY-DOTS'] = @($lines | ForEach-Object { $_ -replace '0', '.' })
    $f['P-EASY-MIXED'] = @($lines[0..3]) + @($lines[4..8] | ForEach-Object { $_ -replace '0', '.' })

    $f['P-HARD17'] = @(
        '000000010', '400000000', '020000000', '000050407', '008000300',
        '001090000', '300400200', '050100000', '000806000'
    )

    $f['P-SEARCH'] = @(
        '504000910', '002000040', '090000000', '050700400', '000003000',
        '700020806', '960037000', '080400600', '000200170'
    )

    # P-UNSOLVABLE = P-EASY with r1c3 set to 1 - row 1 (line index 0),
    # column 3 (character index 2).
    $unsolvableLine1 = $lines[0].ToCharArray()
    $unsolvableLine1[2] = '1'
    $unsolvable = [string[]]$lines.Clone()
    $unsolvable[0] = -join $unsolvableLine1
    $f['P-UNSOLVABLE'] = $unsolvable

    $f['P-NONUNIQUE'] = @(
        '534678912', '672195348', '198342567', '85976.42.', '42685.79.',
        '713924856', '961537284', '287419635', '345286179'
    )

    $f['P-BLANK'] = @('.........') * 9

    $f['P-SHORT'] = $lines[0..7]

    $longLine = [string[]]$lines.Clone(); $longLine[4] = '40080300111'
    $f['P-LONGLINE'] = $longLine

    $shortLine = [string[]]$lines.Clone(); $shortLine[4] = '4008030'
    $f['P-SHORTLINE'] = $shortLine

    $badChar = [string[]]$lines.Clone(); $badChar[0] = 'X30070000'
    $f['P-BADCHAR'] = $badChar

    $contraRow = [string[]]$lines.Clone(); $contraRow[0] = '530070500'
    $f['P-CONTRA-ROW'] = $contraRow

    $contraCol = [string[]]$lines.Clone(); $contraCol[0] = '430070000'
    $f['P-CONTRA-COL'] = $contraCol

    $contraBox = [string[]]$lines.Clone(); $contraBox[0] = '580070000'
    $f['P-CONTRA-BOX'] = $contraBox

    $multi9 = [string[]]$lines.Clone(); $multi9[0] = 'X30070300'
    $f['P-MULTIFAULT-9'] = $multi9
    $f['P-MULTIFAULT'] = $multi9[0..7]

    return $f
}

# Fixtures already shipped under samples/ (RTVM-907) — prefer these paths
# over a freshly-generated temp file so the corpus also exercises the
# actually-delivered files, not just their text.
function Get-ShippedSampleMap {
    return @{
        'P-EASY'       = 'easy.txt'
        'P-HARD17'     = 'hard17.txt'
        'P-UNSOLVABLE' = 'unsolvable.txt'
        'P-BADCHAR'    = 'malformed.txt'
        'P-NONUNIQUE'  = 'nonunique.txt'
    }
}

# Writes every fixture in $Fixtures (or a name subset) into $Dir as
# "<name>.txt", LF, trailing newline on the 9th line, UTF-8 no BOM — same
# shape as the shipped samples/*.txt. Returns a name -> path map covering
# every fixture, preferring a shipped sample under $SamplesDir when one
# exists and $SamplesDir is given.
function Publish-Fixtures {
    param(
        [Parameter(Mandatory)][System.Collections.Specialized.OrderedDictionary]$Fixtures,
        [Parameter(Mandatory)][string]$Dir,
        [string]$SamplesDir = $null
    )

    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    $shipped = Get-ShippedSampleMap
    $paths = @{}

    foreach ($name in $Fixtures.Keys) {
        $useShipped = $false
        if ($SamplesDir -and $shipped.ContainsKey($name)) {
            $candidate = Join-Path $SamplesDir $shipped[$name]
            if (Test-Path -LiteralPath $candidate) {
                $paths[$name] = $candidate
                $useShipped = $true
            }
        }
        if (-not $useShipped) {
            $path = Join-Path $Dir ("$name.txt")
            $content = (($Fixtures[$name] -join "`n") + "`n")
            Write-Utf8NoBom -Path $path -Content $content
            $paths[$name] = $path
        }
    }

    return $paths
}
