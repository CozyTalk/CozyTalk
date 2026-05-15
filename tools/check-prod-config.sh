#!/bin/sh
# Run this after every Firebase deployment to verify production is wired correctly.
#
# Usage:
#   ./tools/check-prod-config.sh
#   ./tools/check-prod-config.sh --project my-project-id
#
# Auth (first one found is used):
#   1. GOOGLE_ACCESS_TOKEN env var  — paste the output of: gcloud auth print-access-token
#   2. gcloud CLI (if installed)    — gcloud auth login / gcloud auth application-default login
#   3. firebase-tools CLI           — firebase login  (this is what you use to deploy)
#
# The only thing checked here that requires Google Cloud API access is the Firestore
# TTL policy check. Everything else uses the Firebase CLI which you already have.

set -eu

PROJECT="cozytalk-5d984"
FAIL=0

for arg in "$@"; do
  case "$arg" in
    --project=*) PROJECT="${arg#--project=}" ;;
    --project)   shift; PROJECT="$1" ;;
  esac
done

# ── Colour helpers ────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  GRN='\033[0;32m'; RED='\033[0;31m'; YLW='\033[0;33m'; RST='\033[0m'; BLD='\033[1m'
else
  GRN=''; RED=''; YLW=''; RST=''; BLD=''
fi
ok()   { printf "  ${GRN}✓${RST}  %s\n" "$1"; }
fail() { printf "  ${RED}✗${RST}  %s\n" "$1"; FAIL=1; }
warn() { printf "  ${YLW}!${RST}  %s\n" "$1"; }
hr()   { printf "\n  ${BLD}%s${RST}\n" "$1"; }

printf "\n  ${BLD}CozyTalk — production config check${RST}  (project: ${PROJECT})\n"

# ── Get a GCP access token ────────────────────────────────────────────────────
# The Firestore TTL field API requires a Google OAuth access token.
# Tried in order: env var → gcloud → firebase-tools stored token → refresh exchange.

ACCESS_TOKEN="${GOOGLE_ACCESS_TOKEN:-}"

# gcloud (if installed)
if [ -z "$ACCESS_TOKEN" ] && command -v gcloud > /dev/null 2>&1; then
  ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null || true)
fi

# firebase login stores tokens in configstore. Read access_token directly first
# (firebase-tools refreshes it on every CLI command, so it's usually fresh).
# Fall back to exchanging the refresh_token if the access_token is missing.
if [ -z "$ACCESS_TOKEN" ] && command -v node > /dev/null 2>&1; then
  ACCESS_TOKEN=$(node -e "
    try {
      const fs = require('fs');
      const p = require('os').homedir() + '/.config/configstore/firebase-tools.json';
      const d = JSON.parse(fs.readFileSync(p, 'utf8'));
      const tok = d.tokens;
      if (!tok) { process.exit(0); }
      // Use the stored access_token — valid for ~1 h after any firebase command.
      if (tok.access_token) { process.stdout.write(tok.access_token); process.exit(0); }
      // Otherwise surface the refresh_token so the shell can exchange it below.
      const rt = tok.refresh_token;
      if (rt) process.stdout.write('REFRESH:' + rt);
    } catch(_) {}
  " 2>/dev/null || true)

  # If we only got a refresh token, exchange it for an access token.
  case "$ACCESS_TOKEN" in
    REFRESH:*)
      REFRESH_TOKEN="${ACCESS_TOKEN#REFRESH:}"
      ACCESS_TOKEN=""
      RESP=$(curl -sf -X POST https://oauth2.googleapis.com/token \
        -d "client_id=563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com" \
        -d "client_secret=j9iVZfS8yvTGRKQbTMCS-SnX" \
        -d "refresh_token=${REFRESH_TOKEN}" \
        -d "grant_type=refresh_token" 2>/dev/null || true)
      ACCESS_TOKEN=$(printf '%s' "$RESP" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4 || true)
      ;;
  esac
fi

if [ -z "$ACCESS_TOKEN" ]; then
  warn "Could not read a GCP access token from firebase-tools — TTL checks will be skipped."
  printf "\n     You are logged in, but the token could not be read automatically.\n"
  printf "     Run any firebase command to refresh the stored token, then retry:\n\n"
  printf "       npx firebase-tools projects:list && ./tools/check-prod-config.sh\n\n"
fi

# ── 1. Firestore TTL policies ─────────────────────────────────────────────────
hr "1. Firestore TTL policies"

check_ttl() {
  COLL="$1"; FIELD="$2"; LABEL="$3"
  if [ -z "$ACCESS_TOKEN" ]; then
    warn "${LABEL} — skipped (no auth token)"
    return
  fi
  URL="https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/collectionGroups/${COLL}/fields/${FIELD}"
  RESP=$(curl -sf -H "Authorization: Bearer ${ACCESS_TOKEN}" "$URL" 2>/dev/null || echo "CURL_ERROR")
  if echo "$RESP" | grep -q '"state": *"ACTIVE"'; then
    ok "${LABEL}  (expiresAt TTL ACTIVE)"
  elif echo "$RESP" | grep -q '"ttlConfig"'; then
    STATE=$(echo "$RESP" | grep -o '"state":"[^"]*"' | head -1 | tr -d '"' | cut -d: -f2)
    fail "${LABEL}  — TTL present but state='${STATE}' (not ACTIVE)"
    printf "         Fix in Firebase console: Firestore → Indexes tab → TTL\n"
  elif echo "$RESP" | grep -qE '"code": *(401|403)|UNAUTHENTICATED|PERMISSION_DENIED'; then
    warn "${LABEL}  — auth token expired; re-run after: npx firebase-tools projects:list"
  else
    fail "${LABEL}  — TTL policy NOT configured on field '${FIELD}'"
    printf "         Fix in Firebase console:\n"
    printf "           Firestore → Indexes → TTL → Add policy\n"
    printf "           Collection group: ${COLL}, Field: ${FIELD}, type: Timestamp\n"
    printf "         Then run seedTtlCollections once so the field is visible:\n"
    printf "           GET https://us-central1-${PROJECT}.cloudfunctions.net/seedTtlCollections\n"
  fi
}

check_ttl "messages"     "expiresAt" "chat_rooms/*/messages"
check_ttl "session_keys" "expiresAt" "session_keys"

# ── 2. Deployed functions ─────────────────────────────────────────────────────
hr "2. Deployed Cloud Functions"

FUNCTIONS_OUTPUT=$(npx --yes firebase-tools@latest functions:list --project "$PROJECT" 2>/dev/null || echo "ERROR")

check_fn() {
  NAME="$1"; EXPECT_REGION="$2"
  if echo "$FUNCTIONS_OUTPUT" | grep -q "$NAME"; then
    # Check region if expected
    ROW=$(echo "$FUNCTIONS_OUTPUT" | grep "$NAME" | head -1)
    if [ -n "$EXPECT_REGION" ] && ! echo "$ROW" | grep -q "$EXPECT_REGION"; then
      FOUND_REGION=$(echo "$ROW" | grep -o 'us-[a-z0-9-]*\|asia-[a-z0-9-]*\|europe-[a-z0-9-]*' | head -1)
      fail "${NAME}  — wrong region '${FOUND_REGION}' (expected '${EXPECT_REGION}')"
    else
      ok "${NAME}"
    fi
  else
    fail "${NAME}  — NOT deployed  →  cd functions && npm run deploy"
  fi
}

check_fn "expireRooms"       "us-central1"
check_fn "match1v1Users"     "asia-southeast1"
check_fn "cleanupMember"     "asia-southeast1"
check_fn "cleanupPoolMember" "asia-southeast1"
check_fn "sendMessage"       "us-central1"
check_fn "endSession"        "us-central1"
check_fn "reportSession"     "us-central1"
check_fn "leaveRoom"         "us-central1"
check_fn "join1v1Pool"       "us-central1"
check_fn "joinGroupRoom"     "us-central1"

# ── 3. Cloud Scheduler ────────────────────────────────────────────────────────
hr "3. Cloud Scheduler"

if echo "$FUNCTIONS_OUTPUT" | grep -q "expireRooms"; then
  ok "expireRooms is deployed"
  warn "Cannot verify job is ENABLED via CLI"
  printf "         Manually check: GCP console → Cloud Scheduler\n"
  printf "         Job name: firebase-schedule-expireRooms-us-central1\n"
  printf "         Status must be 'Enabled', not 'Paused'\n"
else
  fail "expireRooms not deployed — Cloud Scheduler job missing"
fi

# ── 4. Manual checklist ───────────────────────────────────────────────────────
hr "4. Things you must verify manually"
printf "\n"
printf "  a) onDisconnect fires on abrupt disconnect\n"
printf "     Kill a browser tab (not close gracefully) while in a 1v1 room.\n"
printf "     The room should enter 'padding' status within ~60 s.\n"
printf "     Check: Firestore → rooms/{roomId} → status\n\n"

printf "  b) seedTtlCollections was run at least once\n"
printf "     This creates placeholder docs so the TTL field is visible in\n"
printf "     the console when configuring TTL policies.\n"
printf "     Run if not done: GET https://us-central1-${PROJECT}.cloudfunctions.net/seedTtlCollections\n"
printf "     Then remove that function export from functions/src/index.ts and redeploy.\n\n"

printf "  c) Auth providers are enabled in Firebase console\n"
printf "     Anonymous, Email/Password, Google Sign-In\n\n"

# ── Summary ───────────────────────────────────────────────────────────────────
printf "\n"
if [ "$FAIL" -eq 0 ]; then
  printf "  ${GRN}${BLD}All automated checks passed.${RST}\n\n"
else
  printf "  ${RED}${BLD}Fix the failures above before going live.${RST}\n\n"
  exit 1
fi
