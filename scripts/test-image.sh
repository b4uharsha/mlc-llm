#!/bin/bash
set -euo pipefail

echo "[1/3]  Testing MLC-LLM Python import..."
python -c "import mlc_llm; print('MLC-LLM imported successfully')"

echo "[2/3] Running pytest unit tests..."
cd /mlc-llm
pytest python/tests

echo "[3/3] Starting FastAPI server..."
exec ./scripts/start.sh
