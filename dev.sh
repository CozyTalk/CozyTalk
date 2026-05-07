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
fail() { printf "  ${RED}✗${RESET}  %b\n" "$*" >&2; exit 1; }
info() { printf "  ${GRAY}  %b${RESET}\n" "$*"; }
log()  { printf "  ${CYAN}▸${RESET}  %b\n" "$*"; }
warn() { printf "  ${YELLOW}⚠${RESET}  %b\n" "$*"; }

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

# ── Args ──────────────────────────────────────────────────────────────────────
USE_PROD=false
USE_WEB=false

for arg in "$@"; do
  case "$arg" in
    --prod)   USE_PROD=true ;;
    --web)    USE_WEB=true ;;
    --help|-h)
      printf "\n${BOLD}Usage:${RESET} ./dev.sh [--prod] [--web]\n\n"
      printf "  ${BOLD}--prod${RESET}  Connect to live Firebase instead of local emulators\n"
      printf "  ${BOLD}--web${RESET}   Run on Chrome instead of Android\n\n"
      printf "  ${GRAY}Without flags: emulator mode, Flutter will ask which device${RESET}\n\n"
      exit 0
      ;;
    *)
      fail "Unknown argument: ${arg}  (try --help)"
      ;;
  esac
done

# ── Header ────────────────────────────────────────────────────────────────────
printf "\n"
printf "  ${MAGENTA}${BOLD}CozyTalk${RESET}  ${GRAY}·  dev runner${RESET}\n"
printf "$HR\n\n"

# ── Mode summary ──────────────────────────────────────────────────────────────
if $USE_WEB; then
  PLATFORM="Chrome"
else
  PLATFORM="auto-detect"
fi

if $USE_PROD; then
  BACKEND="${YELLOW}Production Firebase${RESET}"
else
  BACKEND="${CYAN}Local emulators${RESET}"
fi

printf "  ${GRAY}Platform${RESET}  ${BOLD}${PLATFORM}${RESET}\n"
printf "  ${GRAY}Backend ${RESET}  ${BACKEND}\n"
printf "\n"

if $USE_PROD; then
  warn "You are connecting to ${YELLOW}${BOLD}live Firebase${RESET} — real data, real users."
  printf "\n"
fi

# ── Build Flutter args ────────────────────────────────────────────────────────
FLUTTER_ARGS=()
$USE_WEB  && FLUTTER_ARGS+=("-d" "chrome")
$USE_PROD && FLUTTER_ARGS+=("--dart-define=USE_EMULATOR=false")

# ── Emulator startup ──────────────────────────────────────────────────────────
EMULATOR_PID=""
EMULATOR_LOG=""

cleanup() {
  local code=$?
  if [[ -n "$EMULATOR_PID" ]]; then
    printf "\n\n  ${GRAY}Stopping emulators…${RESET}\n"
    kill "$EMULATOR_PID" 2>/dev/null || true
    wait "$EMULATOR_PID" 2>/dev/null || true
  fi
  [[ -n "$EMULATOR_LOG" && -f "$EMULATOR_LOG" ]] && rm -f "$EMULATOR_LOG"
  printf "  ${GRAY}Done.${RESET}\n\n"
  exit "$code"
}

if ! $USE_PROD; then
  trap cleanup EXIT INT TERM

  EMULATOR_LOG="$(mktemp /tmp/cozytalk-emulator-XXXXXX.log)"

  log "Starting Firebase emulators…"
  info "Logs → ${EMULATOR_LOG}  ${DIM}(tail -f to follow)${RESET}"
  printf "\n"

  # Redirect all emulator output to the log file so it can't race with
  # Flutter's interactive device-selection prompt later.
  (cd functions && npm run serve) > "$EMULATOR_LOG" 2>&1 &
  EMULATOR_PID=$!

  AUTH_PORT=9099
  MAX_WAIT=90
  elapsed=0
  printf "  ${GRAY}Waiting for auth emulator on :${AUTH_PORT}${RESET}"

  while ! (echo > /dev/tcp/localhost/$AUTH_PORT) 2>/dev/null; do
    printf "${GRAY}.${RESET}"
    sleep 1
    elapsed=$((elapsed + 1))

    if [[ $elapsed -ge $MAX_WAIT ]]; then
      printf "\n\n"
      printf "  ${RED}✗${RESET}  Auth emulator didn't respond after ${MAX_WAIT}s.\n"
      printf "  ${GRAY}  Last log lines:${RESET}\n\n"
      tail -20 "$EMULATOR_LOG" | sed 's/^/    /'
      printf "\n"
      exit 1
    fi

    if ! kill -0 "$EMULATOR_PID" 2>/dev/null; then
      printf "\n\n"
      printf "  ${RED}✗${RESET}  Emulator process exited unexpectedly.\n"
      printf "  ${GRAY}  Last log lines:${RESET}\n\n"
      tail -20 "$EMULATOR_LOG" | sed 's/^/    /'
      printf "\n"
      exit 1
    fi
  done

  printf " ${GREEN}ready${RESET}\n"
  ok "Emulator UI → http://127.0.0.1:4000"
  printf "\n$HR\n"
fi

# ── Flutter ───────────────────────────────────────────────────────────────────
printf "\n"
log "Starting Flutter${USE_WEB:+ on Chrome}…"
printf "\n$HR\n\n"

(cd apps/mobile && flutter run "${FLUTTER_ARGS[@]}")
