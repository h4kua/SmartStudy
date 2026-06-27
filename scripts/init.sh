#!/usr/bin/env bash
# init.sh — one-time dev environment setup for AI Academic Mentor
# Run from the repository root: ./scripts/init.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_DIR="$REPO_ROOT/crew_backend"

echo "==> AI Academic Mentor — environment init"
echo "    Repo root: $REPO_ROOT"
echo ""

# ── 1. Check Xcode ──────────────────────────────────────────────────────────
echo "[1/5] Checking Xcode..."
if ! xcodebuild -version &>/dev/null; then
  echo "ERROR: xcodebuild not found. Install Xcode from the App Store."
  exit 1
fi
XCODE_VER=$(xcodebuild -version | head -1)
echo "      $XCODE_VER — OK"

# ── 2. Check Python ──────────────────────────────────────────────────────────
echo "[2/5] Checking Python..."
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 not found. Install via 'brew install python' or python.org."
  exit 1
fi
PYTHON_VER=$(python3 --version)
echo "      $PYTHON_VER — OK"

# ── 3. Python venv ───────────────────────────────────────────────────────────
echo "[3/5] Setting up Python virtual environment..."
cd "$BACKEND_DIR"
if [ ! -d "venv" ]; then
  python3 -m venv venv
  echo "      Created venv at crew_backend/venv"
else
  echo "      venv already exists — skipping creation"
fi
# shellcheck disable=SC1091
source venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
echo "      Python dependencies installed — OK"
deactivate

# ── 4. Validate .env ─────────────────────────────────────────────────────────
echo "[4/5] Checking crew_backend/.env..."
ENV_FILE="$BACKEND_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo ""
  echo "      .env not found. Creating template..."
  cat > "$ENV_FILE" <<'EOF'
# crew_backend/.env — never commit this file
GROQ_API_KEY=your_key_here
EOF
  echo "      Created crew_backend/.env — fill in GROQ_API_KEY before starting the server."
else
  if grep -q "GROQ_API_KEY=your_key_here" "$ENV_FILE" 2>/dev/null || \
     ! grep -q "GROQ_API_KEY=" "$ENV_FILE" 2>/dev/null; then
    echo "      WARNING: GROQ_API_KEY appears unset in .env. Edit crew_backend/.env."
  else
    echo "      .env present and GROQ_API_KEY is set — OK"
  fi
fi

# ── 5. Verify .gitignore entries ─────────────────────────────────────────────
echo "[5/5] Verifying .gitignore protections..."
GITIGNORE="$REPO_ROOT/.gitignore"
MISSING=0
for entry in ".env" "GoogleService-Info.plist"; do
  if ! grep -q "$entry" "$GITIGNORE" 2>/dev/null; then
    echo "      WARNING: $entry not found in .gitignore!"
    MISSING=1
  fi
done
if [ "$MISSING" -eq 0 ]; then
  echo "      .gitignore entries OK"
fi

echo ""
echo "==> Init complete."
echo ""
echo "    Next steps:"
echo "      1. Fill in GROQ_API_KEY in crew_backend/.env"
echo "      2. Start backend:  cd crew_backend && ./start.sh"
echo "      3. Build iOS:      ./scripts/test.sh"
echo "      4. Open in Xcode:  open FinalProject.xcodeproj"
