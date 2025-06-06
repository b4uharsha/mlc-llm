import sys
from mlc_llm.server import app
import uvicorn

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "serve":
        uvicorn.run(app, host="0.0.0.0", port=8000)
    else:
        print("MLC LLM CLI works!")

if __name__ == "__main__":
    main()
