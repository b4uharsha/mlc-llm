#!/bin/bash
set -euo pipefail

echo "[INFO] Starting FastAPI server in background..."
mlc_llm serve --host 0.0.0.0 --port 8000 &

SERVER_PID=$!

# Wait for server readiness with retries and timeout
MAX_RETRIES=12
RETRY_INTERVAL=5
SUCCESS=0

echo "[INFO] Waiting for server readiness (timeout=$((MAX_RETRIES * RETRY_INTERVAL))s)..."
for ((i=1; i<=MAX_RETRIES; i++)); do
  if curl --silent --fail --max-time 3 http://localhost:8000/; then
    echo "[INFO] Server is ready."
    SUCCESS=1
    break
  else
    echo "[INFO] Server not ready yet, retry $i/$MAX_RETRIES. Sleeping $RETRY_INTERVAL seconds..."
    sleep $RETRY_INTERVAL
  fi
done

if [[ $SUCCESS -ne 1 ]]; then
  echo "[ERROR] Server did not start within expected time."
  kill $SERVER_PID || true
  exit 1
fi

# Run API test with timeout and error handling
echo "[INFO] Running API test..."
set +e
API_RESPONSE=$(curl --max-time 10 -s -w "%{http_code}" -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Llama-2-7b-chat-glm-4b-q0f16_0","messages":[{"role":"user","content":"Hello!"}]}' -o /tmp/api_response.json)

if [[ "$API_RESPONSE" != "200" ]]; then
  echo "[ERROR] API test failed with status code $API_RESPONSE"
  cat /tmp/api_response.json
  kill $SERVER_PID || true
  exit 1
fi
set -e

echo "[INFO] API test succeeded. Response:"
cat /tmp/api_response.json

echo "[INFO] Stopping server..."
kill $SERVER_PID

# Wait for server to stop gracefully, else force kill
timeout 10s wait $SERVER_PID || {
  echo "[WARN] Server did not stop, sending SIGKILL..."
  kill -9 $SERVER_PID || true
}

echo "[INFO] Server stopped. Test complete."
