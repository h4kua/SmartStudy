#!/usr/bin/env bash
# test.sh — build verification + backend smoke test for AI Academic Mentor
# Run from the repository root: ./scripts/test.sh
# Options:
#   --ios-only       skip backend check
#   --backend-only   skip iOS build
#   --device NAME    simulator name (default: iPhone 16)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$REPO_ROOT/FinalProject.xcodeproj"
SCHEME="FinalProject"
SIMULATOR="iPhone 16"
RUN_IOS=1
RUN_BACKEND=1

for arg in "$@"; do
  case "$arg" in
    --ios-only)     RUN_BACKEND=0 ;;
    --backend-only) RUN_IOS=0 ;;
    --device)       shift; SIMULATOR="$1" ;;
  esac
done

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "==> AI Academic Mentor — test harness"
echo ""

# ── iOS Build ─────────────────────────────────────────────────────────────────
if [ "$RUN_IOS" -eq 1 ]; then
  echo "[iOS] Building scheme '$SCHEME' → simulator '$SIMULATOR'..."
  BUILD_OUTPUT=$(xcodebuild \
    -scheme "$SCHEME" \
    -project "$PROJECT" \
    -destination "platform=iOS Simulator,name=$SIMULATOR" \
    -quiet \
    build 2>&1) && BUILD_EXIT=0 || BUILD_EXIT=$?

  if [ "$BUILD_EXIT" -eq 0 ]; then
    pass "iOS build succeeded"
  else
    fail "iOS build failed"
    echo "$BUILD_OUTPUT" | grep -E "error:|warning:" | head -20
  fi
fi

# ── Backend ───────────────────────────────────────────────────────────────────
if [ "$RUN_BACKEND" -eq 1 ]; then
  echo ""
  echo "[Backend] Checking backend health at http://localhost:8000..."

  if ! command -v curl &>/dev/null; then
    fail "curl not found — cannot check backend"
  else
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 5 http://localhost:8000/health 2>/dev/null) || HTTP_CODE=0

    if [ "$HTTP_CODE" -eq 200 ]; then
      pass "Backend /health returned 200"
    elif [ "$HTTP_CODE" -eq 0 ]; then
      fail "Backend not reachable (is crew_backend/start.sh running?)"
    else
      fail "Backend /health returned HTTP $HTTP_CODE"
    fi
  fi

  # Check .env exists and has key
  echo ""
  echo "[Backend] Checking .env..."
  ENV_FILE="$REPO_ROOT/crew_backend/.env"
  if [ ! -f "$ENV_FILE" ]; then
    fail ".env missing — run ./scripts/init.sh first"
  elif grep -q "your_key_here" "$ENV_FILE"; then
    fail "GROQ_API_KEY is still the placeholder — update crew_backend/.env"
  else
    pass ".env present with GROQ_API_KEY set"
  fi
fi

# ── Security guards ───────────────────────────────────────────────────────────
echo ""
echo "[Security] Verifying secrets not staged in git..."

STAGED=$(git -C "$REPO_ROOT" diff --cached --name-only 2>/dev/null || true)

for secret_file in ".env" "GoogleService-Info.plist"; do
  if echo "$STAGED" | grep -q "$secret_file"; then
    fail "DANGER: $secret_file is staged for commit — unstage it immediately"
  fi
done

# Check xcscheme doesn't have real key
XCSCHEME=$(find "$REPO_ROOT" -name "*.xcscheme" 2>/dev/null | head -1)
if [ -n "$XCSCHEME" ]; then
  if grep -q 'GROQ_API_KEY' "$XCSCHEME" && ! grep -q 'value = ""' "$XCSCHEME"; then
    fail "xcscheme may contain a GROQ_API_KEY value — verify it is empty"
  else
    pass "xcscheme GROQ_API_KEY is empty"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "==> Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
