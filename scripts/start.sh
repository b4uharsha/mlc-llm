#!/bin/bash
set -euo pipefail

CMD=${1:-}

if [[ "$CMD" == "build" ]]; then
  if [[ -f "CMakeLists.txt" ]]; then
    echo "[INFO] 🔨 Building project via CMake..."
    mkdir -p build && cd build
    cmake -GNinja ..
    ninja
  else
    echo "[INFO] No CMakeLists.txt found. Skipping build step."
  fi
elif [[ "$CMD" == "" || "$CMD" == "serve" ]]; then
  echo "[INFO] Starting FastAPI server..."
  exec mlc_llm serve --host 0.0.0.0 --port 8000
else
  echo "[INFO] Executing: $@"
  exec "$@"
fi
