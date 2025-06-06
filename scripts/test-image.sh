#!/bin/bash
set -euo pipefail

echo "[INFO] Starting FastAPI server in background..."
mlc_llm serve --host 0.0.0.0 --port 8000 &

SERVER_PID=$!

MAX_RETRIES=15
SLEEP_INTERVAL=4
SUCCESS=0

echo "[INFO] Waiting for server to be ready..."

for ((i=1; i<=MAX_RETRIES; i++)); do
  if curl --silent --fail --max-time 3 http://localhost:8000/; then
    echo "[INFO] Server is up!"
    SUCCESS=1
    break
  else
    echo "[INFO] Server not ready yet (attempt $i/$MAX_RETRIES), retrying in $SLEEP_INTERVAL seconds..."
    sleep $SLEEP_INTERVAL
  fi
done

if [[ $SUCCESS -ne 1 ]]; then
  echo "[ERROR] Server did not become ready in time."
  kill $SERVER_PID || true
  exit 1
fi

echo "[INFO] Running API test..."

set +e
curl -X POST http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"Llama-2-7b-chat-glm-4b-q0f16_0","messages":[{"role":"user","content":"Hello!"}]}' -v
TEST_EXIT_CODE=$?
set -e

if [[ $TEST_EXIT_CODE -ne 0 ]]; then
  echo "[ERROR] API test failed."
  kill $SERVER_PID || true
  exit $TEST_EXIT_CODE
fi

echo "[INFO] API test succeeded."

echo "[INFO] Stopping server..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null || true
echo "[INFO] Server stopped."
