#!/bin/bash
set -e
echo "Starting MLC-LLM FastAPI server..."
exec uvicorn scripts.serve:app --host 0.0.0.0 --port 8000
