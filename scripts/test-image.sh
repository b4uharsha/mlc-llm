#!/bin/bash
set -euo pipefail

echo "[INFO] Starting FastAPI server in background..."
mlc_llm serve --host 0.0.0.0 --port 8000 &

SERVER_PID=$!

# Wait for server to be ready, retry curl multiple times
echo "[INFO] Waiting for server startup (max 30 seconds)..."
for i in {1..6}; do
  if curl --max-time 5 --fail http://localhost:8000/; then
    echo "[INFO] Server is up!"
    break
  else
    echo "[INFO] Server not ready yet, retrying in 5 seconds..."
    sleep 5
  fi
done

echo "[INFO] Running API test..."
curl --max-time 10 -X POST http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"Llama-2-7b-chat-glm-4b-q0f16_0","messages":[{"role":"user","content":"Hello!"}]}'

echo "[INFO] Tests completed. Stopping server..."
kill $SERVER_PID

# Wait max 10 seconds for server to exit cleanly
timeout 10s wait $SERVER_PID || {
  echo "[WARN] Server did not exit in time, forcing kill..."
  kill -9 $SERVER_PID
}

echo "[INFO] Server stopped."
