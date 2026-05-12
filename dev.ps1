#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

function ok($msg)   { Write-Host "  [+]  $msg" -ForegroundColor Green }
function fail($msg) { Write-Host "  [x]  $msg" -ForegroundColor Red; exit 1 }
function log($msg)  { Write-Host "  >>  $msg" -ForegroundColor Cyan }
function info($msg) { Write-Host "       $msg" -ForegroundColor DarkGray }
function warn($msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function hr()       { Write-Host "  $('─' * 57)" -ForegroundColor DarkGray }

$ROOT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ROOT_DIR

# ── Args ───────────────────────────────────────────────────────────────────────
$USE_PROD = $false
$USE_WEB  = $false

foreach ($arg in $args) {
    switch ($arg) {
        '--prod' { $USE_PROD = $true }
        '--web'  { $USE_WEB  = $true }
        { $_ -in '--help', '-h' } {
            Write-Host ""
            Write-Host "  Usage: .\dev.ps1 [--prod] [--web]" -ForegroundColor White
            Write-Host ""
            Write-Host "  --prod  Connect to live Firebase instead of local emulators"
            Write-Host "  --web   Run on Chrome instead of Android"
            Write-Host ""
            Write-Host "  Without flags: emulator mode, Flutter will ask which device" -ForegroundColor DarkGray
            Write-Host ""
            exit 0
        }
        default { fail "Unknown argument: $arg  (try --help)" }
    }
}

# ── Header ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  CozyTalk  ·  dev runner" -ForegroundColor Magenta
hr
Write-Host ""

$PLATFORM = if ($USE_WEB)  { "Chrome" }            else { "auto-detect" }
$BACKEND  = if ($USE_PROD) { "Production Firebase" } else { "Local emulators" }

Write-Host "  Platform  $PLATFORM"
Write-Host "  Backend   $BACKEND"
Write-Host ""

if ($USE_PROD) {
    warn "You are connecting to live Firebase — real data, real users."
    Write-Host ""
}

# ── Helpers ────────────────────────────────────────────────────────────────────
function Stop-ProcessOnPort([int]$Port) {
    Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique |
        ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
}

function Test-Port([int]$Port) {
    $tcp = New-Object System.Net.Sockets.TcpClient
    try   { $tcp.Connect('127.0.0.1', $Port); $true  }
    catch { $false }
    finally { $tcp.Dispose() }
}

# ── Emulator state ─────────────────────────────────────────────────────────────
$EmulatorProcess = $null
$EmulatorOut     = $null
$EmulatorErr     = $null

function Stop-Emulators {
    if ($null -ne $EmulatorProcess -and -not $EmulatorProcess.HasExited) {
        Write-Host ""
        Write-Host "  Stopping emulators..." -ForegroundColor DarkGray
        & taskkill /F /T /PID $EmulatorProcess.Id 2>$null
    }
    foreach ($f in @($EmulatorOut, $EmulatorErr)) {
        if ($null -ne $f -and (Test-Path $f)) {
            Remove-Item $f -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "  Done." -ForegroundColor DarkGray
    Write-Host ""
}

function Show-EmulatorTail {
    $lines = @()
    if ($null -ne $EmulatorOut -and (Test-Path $EmulatorOut)) {
        $lines += Get-Content $EmulatorOut -ErrorAction SilentlyContinue
    }
    if ($null -ne $EmulatorErr -and (Test-Path $EmulatorErr)) {
        $lines += Get-Content $EmulatorErr -ErrorAction SilentlyContinue
    }
    $lines | Select-Object -Last 20 | ForEach-Object { Write-Host "    $_" }
}

# ── Build Flutter args ─────────────────────────────────────────────────────────
$FLUTTER_ARGS = @()
if ($USE_WEB)  { $FLUTTER_ARGS += '-d', 'chrome' }
if ($USE_PROD) { $FLUTTER_ARGS += '--dart-define=USE_EMULATOR=false' }

$mobileDir = Join-Path (Join-Path $ROOT_DIR 'apps') 'mobile'

try {
    # ── Emulator startup ───────────────────────────────────────────────────────
    if (-not $USE_PROD) {
        # Kill any stale processes left over from a previous run.
        foreach ($port in @(9099, 8080, 9000, 5001, 4000, 4400, 4500)) {
            Stop-ProcessOnPort $port
        }

        $EmulatorOut = [System.IO.Path]::GetTempFileName()
        $EmulatorErr = [System.IO.Path]::GetTempFileName()

        $functionsDir = Join-Path $ROOT_DIR 'functions'

        log "Starting Firebase emulators..."
        info "Logs -> $EmulatorOut"
        Write-Host ""

        # cmd.exe /c ensures npm.cmd resolves correctly on Windows.
        $EmulatorProcess = Start-Process -FilePath 'cmd.exe' `
            -ArgumentList '/c', 'npm run serve' `
            -WorkingDirectory $functionsDir `
            -RedirectStandardOutput $EmulatorOut `
            -RedirectStandardError  $EmulatorErr `
            -PassThru -NoNewWindow

        $MAX_WAIT = 90

        function Wait-ForPort([string]$Name, [int]$Port) {
            $elapsed = 0
            Write-Host -NoNewline "  Waiting for $Name emulator on :$Port" -ForegroundColor DarkGray
            while (-not (Test-Port $Port)) {
                Write-Host -NoNewline "." -ForegroundColor DarkGray
                Start-Sleep -Seconds 1
                $elapsed++
                if ($elapsed -ge $MAX_WAIT) {
                    Write-Host ""
                    Write-Host "  [x]  $Name emulator didn't respond after ${MAX_WAIT}s." -ForegroundColor Red
                    Write-Host "  Last log lines:" -ForegroundColor DarkGray
                    Write-Host ""
                    Show-EmulatorTail
                    Write-Host ""
                    exit 1
                }
                $EmulatorProcess.Refresh()
                if ($EmulatorProcess.HasExited) {
                    Write-Host ""
                    Write-Host "  [x]  Emulator process exited unexpectedly." -ForegroundColor Red
                    Write-Host "  Last log lines:" -ForegroundColor DarkGray
                    Write-Host ""
                    Show-EmulatorTail
                    Write-Host ""
                    exit 1
                }
            }
            Write-Host " ready" -ForegroundColor Green
        }

        Wait-ForPort "auth"     9099
        Wait-ForPort "database" 9000
        ok "Emulator UI -> http://127.0.0.1:4000"
        Write-Host ""
        hr
    }

    # ── Flutter ────────────────────────────────────────────────────────────────
    Write-Host ""
    $webSuffix = if ($USE_WEB) { " on Chrome" } else { "" }
    log "Starting Flutter$webSuffix..."
    Write-Host ""
    hr
    Write-Host ""

    Push-Location $mobileDir
    try {
        & flutter run @FLUTTER_ARGS
    } finally {
        Pop-Location
    }
} finally {
    if (-not $USE_PROD) { Stop-Emulators }
}
