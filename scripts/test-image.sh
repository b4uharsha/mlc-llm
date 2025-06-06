#!/bin/bash
set -euo pipefail

echo "[INFO] Starting FastAPI server in background..."
mlc_llm serve --host 0.0.0.0 --port 8000 &

SERVER_PID=$!

# Wait for server to be ready (up to 30 seconds)
echo "[INFO] Waiting for server to start (up to 30s)..."
for i in {1..30}; do
  if curl -fs http://localhost:8000/; then
    echo "[INFO] Server is up!"
    break
  else
    echo "[INFO] Server not ready yet, waiting 1 second..."
    sleep 1
  fi
done

echo "[INFO] Running API test..."
curl -fs -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Llama-2-7b-chat-glm-4b-q0f16_0","messages":[{"role":"user","content":"Hello!"}]}' | jq .

echo "[INFO] Tests completed. Stopping server..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null || true

echo "[INFO] Server stopped."
