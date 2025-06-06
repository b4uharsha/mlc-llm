#!/bin/bash
set -euo pipefail

MODEL="Llama-2-7b-chat-glm-4b-q0f16_0"

echo "[INFO] 📦 Downloading model: $MODEL"
mlc_llm download-model --model-name "$MODEL"

echo "[INFO] 🚀 Launching MLC-LLM model server..."
exec mlc_llm serve --model "$MODEL" --device cpu --host 0.0.0.0
