from fastapi import FastAPI, Request

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "MLC-LLM server running"}

@app.post("/v1/chat/completions")
async def chat(request: Request):
    payload = await request.json()
    return {
        "model": payload.get("model"),
        "choices": [
            {
                "message": {
                    "role": "assistant",
                    "content": "Hello! I am a test model response."
                }
            }
        ]
    }
