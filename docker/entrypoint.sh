#!/usr/bin/env bash
set -euo pipefail

CMD=${1:-}

# 🛠️ Build logic if explicitly requested
if [[ "$CMD" == "build" ]]; then
  if [[ -f "CMakeLists.txt" ]]; then
    echo "[INFO] 🔨 Building project via CMake..."
    mkdir -p build && cd build
    cmake -GNinja ..
    ninja
  else
    echo "[INFO]  No CMakeLists.txt found. Skipping build step."
  fi
  exit 0
fi

# 🧪 If no command or running bash
if [[ -z "${CMD}" || "$CMD" == "bash" ]]; then
  echo "[INFO] 🐚 Starting interactive shell..."
  exec bash
fi

# 🚀 Otherwise, execute the passed command
echo "[INFO]  Executing: $@"
exec "$@"
