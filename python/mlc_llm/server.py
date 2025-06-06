from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "MLC-LLM server running"}

# To run: uvicorn scripts.serve:app --reload
