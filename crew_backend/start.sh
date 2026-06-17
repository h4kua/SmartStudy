#!/usr/bin/env bash
# start.sh — Set up venv (once) and launch the CrewAI backend server.
#
# Usage:
#   cd crew_backend
#   chmod +x start.sh   # only needed once
#   ./start.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ── 1. Check .env ────────────────────────────────────────────
if [ ! -f ".env" ]; then
    echo "⚠️  No .env found. Creating from .env.example..."
    cp .env.example .env
    echo "👉  Edit crew_backend/.env and add your GROQ_API_KEY, then run ./start.sh again."
    exit 1
fi

if grep -q "gsk_YOUR_GROQ_KEY_HERE" .env; then
    echo "⚠️  GROQ_API_KEY is still the placeholder value in .env"
    echo "👉  Get your free key at https://console.groq.com/keys and update crew_backend/.env"
    exit 1
fi

# ── 2. Create venv if needed ─────────────────────────────────
if [ ! -d ".venv" ]; then
    echo "📦  Creating Python virtual environment..."
    # Prefer python3.11 for CrewAI compatibility, fall back to python3
    if command -v python3.11 &>/dev/null; then
        python3.11 -m venv .venv
    else
        python3 -m venv .venv
    fi
fi

# ── 3. Activate venv ─────────────────────────────────────────
source .venv/bin/activate

# ── 4. Install / upgrade dependencies ────────────────────────
echo "📦  Installing dependencies..."
pip install -q --upgrade pip
pip install -q -r requirements.txt

# ── 5. Launch server ─────────────────────────────────────────
echo ""
echo "🚀  Starting CrewAI backend on http://localhost:8000"
echo "    Docs: http://localhost:8000/docs"
echo "    Press Ctrl+C to stop."
echo ""

uvicorn main:app --reload --host 0.0.0.0 --port 8000
