# File: python/mlc_llm/server.py

from fastapi import FastAPI, Request
import subprocess
import os

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "MLC-LLM server running"}

@app.post("/v1/chat/completions")
async def chat(request: Request):
    payload = await request.json()
    model_name = payload.get("model", "Llama-2-7b-chat-glm-4b-q0f16_0")
    user_input = payload["messages"][0]["content"]

    # Ensure model is downloaded (mocked for now)
    model_dir = f"/root/.mlc/mlc-llm/{model_name}"
    if not os.path.exists(model_dir):
        subprocess.run([
            "mlc_llm", "download-model", "--model-name", model_name
        ], check=True)

    # Serve model (mocked response for now)
    # Here you'd call real inference code or subprocess to run inference and return it
    return {
        "model": model_name,
        "choices": [
            {
                "message": {
                    "role": "assistant",
                    "content": f"[🔁 mock] Response to: {user_input}"
                }
            }
        ]
    }
