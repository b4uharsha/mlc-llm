import argparse
import uvicorn
from mlc_llm.server import app  # now valid import

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["serve", "download-model"])
    parser.add_argument("--model-name", help="Model name (for download-model)")
    parser.add_argument("--device", default="cpu", help="Device type (default: cpu)")
    parser.add_argument("--host", default="0.0.0.0", help="Host (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8000, help="Port (default: 8000)")
    args = parser.parse_args()

    if args.command == "serve":
        print("[INFO] Starting FastAPI server...")
        uvicorn.run(app, host=args.host, port=args.port, log_level="debug")

    elif args.command == "download-model":
        print(f"[INFO] Simulating model download: {args.model_name}")
        # Add real download logic here if needed
