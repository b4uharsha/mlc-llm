# MLC-LLM CI/CD Pipeline

> **Repository:** [https://github.com/b4uharsha/mlc-llm](https://github.com/b4uharsha/mlc-llm)

This repository implements a full CI/CD pipeline for the [MLC-LLM project](https://llm.mlc.ai/docs/index.html). It enables **building**, **testing**, and **deploying** a multipurpose Docker image and **publishing cross-platform Python wheels** as GitHub releases. It also includes a **demo deployment** that serves a quantized LLM model via a FastAPI interface.

---

## 🔧 What Is This Project?

MLC-LLM is a framework to deploy LLMs with TVM-native performance and quantization support. This repository automates its build and deployment lifecycle.

---

## 🚀 Features

### ✅ Multipurpose Docker Image

* Based on Ubuntu with build tools, Python, and dependencies.
* Supports both **development mode** (shell access) and **build mode** (used in CI).
* Automatically built and pushed to GHCR (GitHub Container Registry).

### ✅ Cross-Platform Wheel Packaging

* Builds the `mlc_llm` Python package.
* Outputs `.whl` files for:

  * Linux (x64)
  * Windows (x64)
  * macOS (x64)

### ✅ GitHub Actions CI/CD Pipeline

* Triggers on:

  * Push to `main`
  * Version tags `v*.*.*`
* CI Pipeline stages:

  1. Build Docker Image and push to GHCR
  2. Run automated tests inside the Docker container
  3. Build Python wheels on multiple platforms
  4. Create GitHub Release with built wheels
  5. Deploy and validate a demo model server

### ✅ Demo Deployment

* Pulls the Docker image from GHCR
* Downloads a small quantized LLM model (`Llama-2-7b-chat-hf-q4f16_1`)
* Serves it via `mlc_llm serve`
* Sends a test request to validate model response

> ⚠️ Note: GitHub-hosted runners **do not support GPUs**, so the demo is only for syntax/flow validation. A real deployment should run on a **GPU-enabled machine** or **cloud instance**.

---

## 📦 Packages & Tools Used

| Tool                          | Purpose                                |
| ----------------------------- | -------------------------------------- |
| `docker/build-push-action`    | Build/push image to GHCR               |
| `actions/setup-python`        | Configure Python 3.10 across platforms |
| `mlc_llm`                     | Python package being built/tested      |
| `pytest`, `curl`, `jq`        | Testing and demo validation            |
| `softprops/action-gh-release` | Publish GitHub releases                |

---

## 📂 Project Structure

```
mlc-llm/
├── .github/workflows/ci.yml   # CI/CD pipeline
├── docker/Dockerfile          # Multipurpose build image
├── python/                    # Python package source
├── scripts/test-image.sh      # Automated tests
├── docs/assets/               # Architecture and pipeline diagrams
```

---

## 🖼️ Architecture Diagrams

Below are the CI/CD and build pipeline diagrams.  
**Make sure your images are located in `docs/assets/` in your repository.**

### Build & Deployment Flow

![Build & Deployment Flow](docs/assets/CI_CD Pipeline for Docker Deployment.png)

### CI/CD Architecture

![CI/CD Architecture](docs/assets/MLC-LLM CI_CD Architecture Flowchart.png)

### Model Deployment

![CI/CD Pipeline](Model Deployment Process.png)

---

## 🧪 Local Development Instructions

```bash
# Clone repo
git clone https://github.com/b4uharsha/mlc-llm.git
cd mlc-llm

# Build docker image
docker build -t mlc-llm-dev -f docker/Dockerfile .

# Start interactive shell for dev
docker run -it --rm -v $PWD:/mlc-llm mlc-llm-dev bash

# Run model serving demo manually
mlc_llm download-model --model-name Llama-2-7b-chat-hf-q4f16_1
mlc_llm serve --model Llama-2-7b-chat-hf-q4f16_1
```

---

## 🌐 Live Demo & Sample Output

You can validate the deployment at:  
**[https://mlc-llm.fly.dev/](https://mlc-llm.fly.dev/)**

**Sample output:**

```bash
curl https://mlc-llm.fly.dev/
# {"message":"MLC-LLM server running"}

curl -X POST https://mlc-llm.fly.dev/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
        "model": "Llama-2-7b-chat-glm-4b-q0f16_0",
        "messages": [
          { "role": "user", "content": "Hello, who are you?" }
        ]
      }'
# {"model":"Llama-2-7b-chat-glm-4b-q0f16_0","choices":[{"message":{"role":"assistant","content":"Hello! I am a test model response."}}]}
```

---

## 🔁 CI/CD Flow Summary

```mermaid
graph TD
  A[Push or Tag to GitHub] --> B[Build & Push Docker Image]
  B --> C[Run Tests in Container]
  C --> D[Build Wheels on Linux/Windows/Mac]
  D --> E[Create GitHub Release with Wheels]
  E --> F[Deploy Demo Model in Docker]
  F --> G[Send Test Chat Completion Request]
```

---

## 📌 Optional Enhancements

* [ ] Add UI support with `/docs` using FastAPI’s built-in Swagger
* [ ] Deploy to AWS EC2 or GCP with GPU for live demo
* [ ] Add GitHub Pages for documentation site

---

## 📫 Maintainer

**Harsha Reddy**  
🔗 GitHub: [b4uharsha/mlc-llm](https://github.com/b4uharsha/mlc-llm)

---
