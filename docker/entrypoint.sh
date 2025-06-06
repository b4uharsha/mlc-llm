#!/bin/bash
set -euo pipefail
echo "[INFO] Starting FastAPI server..."
exec mlc_llm serve --host 0.0.0.0 --port "${PORT:-8000}"
