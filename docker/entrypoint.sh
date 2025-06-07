#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  # If arguments are provided, run them instead of starting the server.
  exec "$@"
else
  echo "[INFO] Starting FastAPI server on 0.0.0.0:${PORT:-8000} ..."
  exec mlc_llm serve --host 0.0.0.0 --port "${PORT:-8000}"
fi
