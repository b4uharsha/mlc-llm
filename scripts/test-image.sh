#!/usr/bin/env bash
set -euo pipefail

#
# 1) Start FastAPI in background
#
echo "[INFO] Starting FastAPI server in background..."
mlc_llm serve --host 0.0.0.0 --port 8000 &
SERVER_PID=$!

#
# 2) Poll until the server’s root (GET /) is healthy
#
MAX_RETRIES=15
SLEEP_SECONDS=3
SUCCESS=0

echo "[INFO] Waiting for server to be ready (polling up to $MAX_RETRIES times)..."
for (( i=1; i<=MAX_RETRIES; i++ )); do
  if curl --silent --fail --max-time 2 http://localhost:8000/ ; then
    echo "[INFO] → Server is up!"
    SUCCESS=1
    break
  else
    echo "[INFO] → Not ready yet (attempt $i/$MAX_RETRIES), sleeping ${SLEEP_SECONDS}s..."
    sleep "$SLEEP_SECONDS"
  fi
done

if [[ $SUCCESS -ne 1 ]]; then
  echo "[ERROR] Server did not become ready in time."
  kill "$SERVER_PID" 2>/dev/null || true
  exit 1
fi

#
# 3) POST a dummy chat request, expect HTTP 200
#
echo "[INFO] Running API test (POST /v1/chat/completions)..."
set +e
HTTP_CODE=$(curl -sS -X POST http://localhost:8000/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{"model":"Llama-2-7b-chat-glm-4b-q0f16_0","messages":[{"role":"user","content":"Hello?"}]}' \
     -o /tmp/chat_response.json \
     -w "%{http_code}")
TEST_EXIT=$?
set -e

if [[ $TEST_EXIT -ne 0 ]]; then
  echo "[ERROR] API test command failed (curl exited $TEST_EXIT)."
  kill "$SERVER_PID" 2>/dev/null || true
  exit $TEST_EXIT
fi

if [[ -z "$HTTP_CODE" ]]; then
  echo "[ERROR] Failed to capture HTTP status code from curl"
  kill "$SERVER_PID" 2>/dev/null || true
  exit 1
fi

if [[ "$HTTP_CODE" -ne 200 ]]; then
  echo "[ERROR] Chat endpoint did not return HTTP 200. Got: $HTTP_CODE"
  echo "[ERROR] Response body:"
  cat /tmp/chat_response.json
  kill "$SERVER_PID" 2>/dev/null || true
  exit 1
fi

echo "[INFO] Chat endpoint returned 200 OK. Dumping response body:"
cat /tmp/chat_response.json

#
# 4) Tear down
#
echo "[INFO] Stopping server..."
kill "$SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" 2>/dev/null || true
echo "[INFO] Server stopped. Tests passed."
