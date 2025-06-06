from fastapi import FastAPI, Request
import os
import random
import logging
import uvicorn
import subprocess

app = FastAPI()
logger = logging.getLogger("uvicorn")

@app.on_event("startup")
async def startup_event():
    model_name = os.environ.get("MLC_MODEL", "Llama-2-7b-chat-glm-4b-q0f16_0")
    model_path = f"/root/.cache/mlc/mlc-llm/models/{model_name}"

    if not os.path.exists(model_path):
        logger.info(f"[INFO] Model {model_name} not found locally. Attempting to download...")
        try:
            subprocess.run([
                "mlc_llm", "download-model", "--model-name", model_name
            ], check=True)
            logger.info("[INFO] Model downloaded successfully.")
        except subprocess.CalledProcessError:
            logger.error("[ERROR] Failed to download model.")

@app.get("/")
def read_root():
    return {"message": "MLC-LLM server running"}

@app.post("/v1/chat/completions")
async def chat(request: Request):
    payload = await request.json()
    user_prompt = payload.get("messages", [{}])[0].get("content", "")
    fake_response = f"You said: '{user_prompt}'. This is a simulated model reply #{random.randint(1,100)}."
    return {
        "model": payload.get("model"),
        "choices": [
            {
                "message": {
                    "role": "assistant",
                    "content": fake_response
                }
            }
        ]
    }

if __name__ == "__main__":
    uvicorn.run("mlc_llm.server:app", host="0.0.0.0", port=8000, log_level="debug")
