from fastapi import FastAPI, Request
from mlc_llm.serve import ChatModule  # this must exist in your build
import asyncio

# Load the quantized model
chat_mod = ChatModule(model="Llama-2-7b-chat-glm-4b-q0f16_0", device="cpu")

app = FastAPI()

@app.get("/")
def root():
    return {"message": "MLC-LLM is serving a real model 🚀"}

@app.post("/v1/chat/completions")
async def chat(request: Request):
    data = await request.json()
    prompt = data["messages"][-1]["content"]
    result = await asyncio.to_thread(chat_mod.generate, prompt)
    return {
        "model": data["model"],
        "choices": [
            {
                "message": {
                    "role": "assistant",
                    "content": result
                }
            }
        ]
    }
