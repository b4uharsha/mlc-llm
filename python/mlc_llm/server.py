from fastapi import FastAPI, Request
import subprocess
import os
import threading
import time

app = FastAPI()

MODEL_NAME = "Llama-2-7b-chat-glm-4b-q0f16_0"

@app.on_event("startup")
def startup_event():
    def launch_model():
        try:
            subprocess.run(["mlc_llm", "download-model", "--model-name", MODEL_NAME], check=True)
            subprocess.run([
                "mlc_llm", "serve",
                "--model", MODEL_NAME,
                "--device", "cpu",
                "--host", "0.0.0.0",
                "--port", "8000",
                "--log-level", "debug"
            ])
        except subprocess.CalledProcessError as e:
            print(f"Model serving process failed: {e}")

    # Run in a background thread so FastAPI can start
    threading.Thread(target=launch_model, daemon=True).start()
    time.sleep(2)  # Allow some time to initialize (adjust as needed)

@app.get("/")
def read_root():
    return {"message": f"MLC-LLM '{MODEL_NAME}' model server running."}
