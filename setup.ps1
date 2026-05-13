#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

function ok($msg)   { Write-Host "  [+]  $msg" -ForegroundColor Green }
function fail($msg) { Write-Host "  [x]  $msg" -ForegroundColor Red; exit 1 }
function step($msg) { Write-Host ""; Write-Host "  >>  $msg" -ForegroundColor Cyan }
function info($msg) { Write-Host "       $msg" -ForegroundColor DarkGray }
function warn($msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function hr()       { Write-Host "  $('─' * 57)" -ForegroundColor DarkGray }

$ROOT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ROOT_DIR

Write-Host ""
Write-Host "  CozyTalk  ·  project setup" -ForegroundColor Magenta
hr
Write-Host ""

# ── Prerequisites ──────────────────────────────────────────────────────────────
step "Checking prerequisites"

function Require-Cmd($cmd, $label, $hint = "") {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        $ver = & $cmd --version 2>&1 | Select-Object -First 1
        ok "$label  $ver"
    } elseif ($hint) {
        fail "$label not found — $hint"
    } else {
        fail "$label not found"
    }
}

Require-Cmd flutter "flutter" "https://docs.flutter.dev/get-started/install"
Require-Cmd node    "node"    "Install Node.js 20+ from https://nodejs.org"
Require-Cmd npm     "npm"

if (Get-Command firebase -ErrorAction SilentlyContinue) {
    $fbVer = & firebase --version 2>&1 | Select-Object -First 1
    ok "firebase  $fbVer"
} else {
    warn "firebase-tools not installed globally"
    info "Run:  npm install -g firebase-tools"
    info "(or the emulator will fall back to npx, which is slower)"
}

# ── Flutter dependencies ───────────────────────────────────────────────────────
step "Flutter dependencies"
info "flutter pub get  ->  apps/mobile"
$mobileDir = Join-Path (Join-Path $ROOT_DIR 'apps') 'mobile'
Push-Location $mobileDir
& flutter pub get
$code = $LASTEXITCODE
Pop-Location
if ($code -ne 0) { fail "flutter pub get failed" }
ok "Flutter packages ready"

# ── Code generation ────────────────────────────────────────────────────────────
step "Code generation (Freezed + Riverpod)"
info "build_runner build  ->  apps/mobile"
Push-Location $mobileDir
& dart run build_runner build --delete-conflicting-outputs
$code = $LASTEXITCODE
Pop-Location
if ($code -ne 0) { fail "build_runner failed" }
ok "Generated code up to date"

# ── Cloud Functions ────────────────────────────────────────────────────────────
step "Cloud Functions dependencies"
info "npm install  ->  functions/"
$functionsDir = Join-Path $ROOT_DIR 'functions'
Push-Location $functionsDir
& npm install --silent
$code = $LASTEXITCODE
Pop-Location
if ($code -ne 0) { fail "npm install failed" }
ok "Node packages ready"

# ── Git hooks ─────────────────────────────────────────────────────────────────
step "Git hooks"
& git config core.hooksPath .githooks
ok "pre-push hook active (runs flutter test before every push)"

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
hr
Write-Host ""
Write-Host "  Setup complete." -ForegroundColor Green
Write-Host ""
Write-Host "  What to do next" -ForegroundColor White
Write-Host ""
Write-Host "  >>  .\dev.ps1              Emulators + Flutter on Android"
Write-Host "  >>  .\dev.ps1 --web        Emulators + Flutter on Chrome"
Write-Host "  >>  .\dev.ps1 --prod       Flutter -> live Firebase (Android)"
Write-Host "  >>  .\dev.ps1 --prod --web Flutter -> live Firebase (Chrome)"
Write-Host ""
Write-Host "  Emulator UI  ->  http://127.0.0.1:4000" -ForegroundColor DarkGray
Write-Host "  Auth :9099   Firestore :8080   Database :9000   Functions :5001" -ForegroundColor DarkGray
Write-Host ""
