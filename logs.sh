#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[38;5;196m'
YELLOW='\033[38;5;220m'
GREEN='\033[38;5;82m'
CYAN='\033[38;5;39m'
GRAY='\033[38;5;245m'
BOLD='\033[1m'
RESET='\033[0m'

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$ROOT_DIR/logs"

USE_PROD=false
FOLLOW=false
FN_FILTER=""
LINES=100
LIST_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prod|-p)    USE_PROD=true ;;
    --follow|-f)  FOLLOW=true ;;
    --list|-l)    LIST_MODE=true ;;
    --fn=*)       FN_FILTER="${1#--fn=}" ;;
    --fn)         shift; FN_FILTER="$1" ;;
    -n)           shift; LINES="$1" ;;
    --lines=*)    LINES="${1#--lines=}" ;;
    --help|-h)
      printf "\n${BOLD}Usage:${RESET} ./logs.sh [OPTIONS]\n\n"
      printf "  ${BOLD}(no flags)${RESET}        Last %d lines of current emulator session\n" "$LINES"
      printf "  ${BOLD}--follow, -f${RESET}      Follow emulator logs live\n"
      printf "  ${BOLD}--prod,   -p${RESET}      Fetch and save production Cloud Function logs\n"
      printf "  ${BOLD}--fn=NAME${RESET}         Filter output to lines matching a function name\n"
      printf "  ${BOLD}-n N${RESET}              Show last N lines (default: 100)\n"
      printf "  ${BOLD}--list,   -l${RESET}      List all saved log sessions\n\n"
      printf "  ${GRAY}Examples:${RESET}\n"
      printf "    ./logs.sh -f                   # live follow emulator\n"
      printf "    ./logs.sh --fn=joinGroupRoom   # filter by function\n"
      printf "    ./logs.sh --prod -f            # live follow production\n"
      printf "    ./logs.sh -n 500               # show last 500 lines\n\n"
      exit 0
      ;;
    *) printf "Unknown option: %s  (try --help)\n" "$1" >&2; exit 1 ;;
  esac
  shift
done

mkdir -p "$LOG_DIR"

# ── List mode ─────────────────────────────────────────────────────────────────

if $LIST_MODE; then
  printf "\n  ${BOLD}Saved log sessions${RESET} in ${GRAY}${LOG_DIR}/${RESET}\n\n"
  if ls "$LOG_DIR"/*.log 2>/dev/null | head -1 > /dev/null 2>&1; then
    ls -lht "$LOG_DIR"/*.log | awk -v gray="$GRAY" -v rst="$RESET" -v bold="$BOLD" \
      '{printf "  %s%s %s%s  %s\n", gray, $6" "$7, rst, bold, $9}'
  else
    printf "  ${GRAY}No log files found.${RESET}\n"
  fi
  printf "\n"
  exit 0
fi

# ── Colorize function: reads stdin, applies color by log severity ─────────────

colorize() {
  while IFS= read -r line; do
    if [[ -n "$FN_FILTER" ]] && ! printf '%s' "$line" | grep -qi "$FN_FILTER"; then
      continue
    fi
    if printf '%s' "$line" | grep -qF '"severity":"ERROR"'; then
      printf "${RED}%s${RESET}\n" "$line"
    elif printf '%s' "$line" | grep -qE '"severity":"WARNING"|⚠|warning'; then
      printf "${YELLOW}%s${RESET}\n" "$line"
    elif printf '%s' "$line" | grep -qF '"severity":"INFO"'; then
      printf "${GREEN}%s${RESET}\n" "$line"
    elif printf '%s' "$line" | grep -qF '"severity":"DEBUG"'; then
      printf "${GRAY}%s${RESET}\n" "$line"
    elif printf '%s' "$line" | grep -qE '^>  '; then
      printf "${CYAN}%s${RESET}\n" "$line"
    elif printf '%s' "$line" | grep -qE '^[[:space:]]*(i|✔|✗|⚠)[[:space:]]'; then
      printf "${GRAY}%s${RESET}\n" "$line"
    else
      printf "%s\n" "$line"
    fi
  done
}

# ── Production mode ───────────────────────────────────────────────────────────

if $USE_PROD; then
  LOG_FILE="$LOG_DIR/production-$(date +%Y-%m-%d).log"
  printf "\n  ${BOLD}Production logs${RESET}\n"
  printf "  ${GRAY}Saving to ${BOLD}${LOG_FILE}${RESET}\n"
  [[ -n "$FN_FILTER" ]] && printf "  ${GRAY}Filter: ${BOLD}${FN_FILTER}${RESET}\n"
  printf "  ${GRAY}Press Ctrl+C to stop.${RESET}\n\n"
  if $FOLLOW; then
    npx firebase-tools@latest functions:log --project cozytalk-5d984 2>&1 \
      | tee -a "$LOG_FILE" | colorize
  else
    npx firebase-tools@latest functions:log --project cozytalk-5d984 2>&1 \
      | tee -a "$LOG_FILE" | tail -n "$LINES" | colorize
  fi
  exit 0
fi

# ── Emulator mode ─────────────────────────────────────────────────────────────

LATEST="$LOG_DIR/emulator-latest.log"

if [[ ! -e "$LATEST" ]]; then
  printf "\n  ${RED}No emulator log found.${RESET}\n"
  printf "  Start the emulator first:  ${BOLD}./dev.sh --web${RESET}\n\n"
  exit 1
fi

REAL_PATH="$(readlink -f "$LATEST" 2>/dev/null || realpath "$LATEST" 2>/dev/null || echo "$LATEST")"
printf "\n  ${BOLD}Emulator logs${RESET}\n"
printf "  ${GRAY}File: ${RESET}${REAL_PATH}\n"
[[ -n "$FN_FILTER" ]] && printf "  ${GRAY}Filter: ${BOLD}${FN_FILTER}${RESET}\n"
printf "\n"

if $FOLLOW; then
  tail -n "$LINES" -f "$LATEST" | colorize
else
  tail -n "$LINES" "$LATEST" | colorize
fi
