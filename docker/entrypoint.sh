# docker/entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Starting FastAPI server on 0.0.0.0:${PORT:-8000} ..."
exec mlc_llm serve --host 0.0.0.0 --port "${PORT:-8000}"
