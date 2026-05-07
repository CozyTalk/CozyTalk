#!/usr/bin/env bash
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[38;5;82m'
CYAN='\033[38;5;39m'
YELLOW='\033[38;5;220m'
RED='\033[38;5;196m'
MAGENTA='\033[38;5;171m'
GRAY='\033[38;5;245m'
WHITE='\033[38;5;255m'

HR="${GRAY}$(printf '─%.0s' $(seq 1 60))${RESET}"

ok()   { printf "  ${GREEN}✓${RESET}  %b\n" "$*"; }
fail() { printf "  ${RED}✗${RESET}  %b\n" "$*"; exit 1; }
step() { printf "\n${BOLD}${CYAN}  ▸ %b${RESET}\n" "$*"; }
info() { printf "  ${GRAY}  %b${RESET}\n" "$*"; }
warn() { printf "  ${YELLOW}⚠${RESET}  %b\n" "$*"; }

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# ── Header ────────────────────────────────────────────────────────────────────
printf "\n"
printf "  ${MAGENTA}${BOLD}CozyTalk${RESET}  ${GRAY}·  project setup${RESET}\n"
printf "$HR\n"
printf "\n"

# ── Prerequisites ─────────────────────────────────────────────────────────────
step "Checking prerequisites"

require() {
  local cmd="$1" label="${2:-$1}" hint="${3:-}"
  if command -v "$cmd" &>/dev/null; then
    local ver
    ver="$("$cmd" --version 2>&1 | head -1)"
    ok "${label}  ${DIM}${ver}${RESET}"
  else
    fail "${label} not found${hint:+ — ${hint}}"
  fi
}

require flutter  "flutter"  "https://docs.flutter.dev/get-started/install"
require node     "node"     "Install Node.js 20+ from https://nodejs.org"
require npm      "npm"

if command -v firebase &>/dev/null; then
  ok "firebase  ${DIM}$(firebase --version 2>&1 | head -1)${RESET}"
else
  warn "firebase-tools not installed globally"
  info "Run:  npm install -g firebase-tools"
  info "(or the emulator will fall back to npx, which is slower)"
fi

# ── Flutter dependencies ──────────────────────────────────────────────────────
step "Flutter dependencies"
info "flutter pub get  →  apps/mobile"
(cd apps/mobile && flutter pub get)
ok "Flutter packages ready"

# ── Code generation ───────────────────────────────────────────────────────────
step "Code generation  ${DIM}(Freezed + Riverpod)${RESET}"
info "build_runner build  →  apps/mobile"
(cd apps/mobile && dart run build_runner build --delete-conflicting-outputs 2>&1 \
  | grep -E '^\[|^Done|^Succeeded|error:' || true)
ok "Generated code up to date"

# ── Cloud Functions ───────────────────────────────────────────────────────────
step "Cloud Functions dependencies"
info "npm install  →  functions/"
(cd functions && npm install --silent)
ok "Node packages ready"

# ── Done ──────────────────────────────────────────────────────────────────────
printf "\n$HR\n\n"
printf "  ${GREEN}${BOLD}Setup complete.${RESET}\n\n"
printf "  ${WHITE}${BOLD}What to do next${RESET}\n\n"
printf "  ${CYAN}▸${RESET}  ${BOLD}./dev.sh${RESET}              Emulators + Flutter on Android\n"
printf "  ${CYAN}▸${RESET}  ${BOLD}./dev.sh --web${RESET}        Emulators + Flutter on Chrome\n"
printf "  ${CYAN}▸${RESET}  ${BOLD}./dev.sh --prod${RESET}       Flutter → ${YELLOW}live${RESET} Firebase (Android)\n"
printf "  ${CYAN}▸${RESET}  ${BOLD}./dev.sh --prod --web${RESET} Flutter → ${YELLOW}live${RESET} Firebase (Chrome)\n"
printf "\n"
printf "  ${GRAY}Emulator UI  →  http://127.0.0.1:4000${RESET}\n"
printf "  ${GRAY}Auth :9099   Functions :5001${RESET}\n"
printf "\n"
