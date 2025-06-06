#!/bin/bash
set -euo pipefail

echo "[INFO] Starting FastAPI server in background..."
mlc_llm serve --host 0.0.0.0 --port 8000 &

SERVER_PID=$!

echo "[INFO] Waiting 10 seconds for server startup..."
sleep 10

echo "[INFO] Running API test..."
curl -X POST http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"Llama-2-7b-chat-glm-4b-q0f16_0","messages":[{"role":"user","content":"Hello!"}]}'

echo "[INFO] Tests completed. Stopping server..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null || true

echo "[INFO] Server stopped."
