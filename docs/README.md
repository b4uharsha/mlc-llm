# 🤖 MLC-LLM CI/CD + Demo Deployment

This project demonstrates how to build, test, package, and deploy [MLC-LLM](https://llm.mlc.ai) using GitHub Actions in a fully automated CI/CD pipeline. It includes:

* Multi-platform Python packaging (Linux, Windows, macOS)
* Docker-based model compilation and testing
* Automatic GitHub Releases
* GPU-enabled demo model serving with FastAPI

---

## 🚀 What is MLC-LLM?

**MLC-LLM** enables efficient LLM inference on any device, including CPUs, NVIDIA/AMD GPUs, and mobile. It compiles and optimizes models to run across platforms without relying on heavyweight frameworks like PyTorch or TensorFlow.

Use-cases:

* Portable AI inference
* Quantized LLM deployment (e.g., Llama-2, Mistral)
* Edge or containerized model serving

---

## 📦 Key Technologies Used

| Tool                          | Purpose                                      |
| ----------------------------- | -------------------------------------------- |
| `mlc-llm`                     | LLM compiler, model loader, server interface |
| `CMake`, `Ninja`              | Native compilation for `mlc-llm` runtime     |
| `Docker`, `GHCR`              | Containerized build and serving environment  |
| `GitHub Actions`              | CI/CD automation                             |
| `softprops/action-gh-release` | GitHub Release automation                    |
| `curl`, `jq`                  | Test API endpoints from deployed container   |

---

## 🔀 CI/CD Flow Overview

```
[Commit or Tag Push]
        │
        ▼
📈 GitHub Actions Triggered
        │
        ▼
[Stage 1: Docker Image Build & Push]
        │
        ▼
[Stage 2: Run Tests in Container]
        │
        ▼
[Stage 3: Build Python Wheels (.whl)]
        │
        ▼
[Stage 4: GitHub Release with Wheels]
        │
        ▼
[Stage 5: Deploy Model with FastAPI]
        │
        ▼
[POST Request to Validate Model Response]
```

---

## 📊 Stage Summary

| Stage               | Purpose                                | Output                                    |
| ------------------- | -------------------------------------- | ----------------------------------------- |
| `docker-build`      | Compile + push image to GHCR           | `ghcr.io/<repo>:latest`                   |
| `test`              | Run model diagnostics inside container | Unit test validation                      |
| `build-wheels`      | Cross-platform wheel packaging         | `.whl` files (Linux, Windows, macOS)      |
| `release`           | GitHub release + artifact upload       | Tag-based release with binaries           |
| `deploy-demo-model` | Launch FastAPI + model serving demo    | Accessible API on `http://localhost:8000` |
| *(optional)* UI     | Future Gradio/Streamlit demo           | Public interface to interact with model   |

---

## 🧪 Example Model Used

The deployed demo uses the quantized test model:

```bash
mlc_llm download-model --model-name Llama-2-7b-chat-hf-q4f16_1
mlc_llm serve --model Llama-2-7b-chat-hf-q4f16_1
```

---

## 🌐 Optional: UI Demo Preview (Future)

In future enhancements, the deployment stage can be extended to include a UI demo using:

* **Gradio**
* **Streamlit**
* **Hugging Face Spaces** or **Vercel**

```python
import gradio as gr
from requests import post

def chat(input):
    payload = {
        "model": "Llama-2-7b-chat-hf-q4f16_1",
        "messages": [{"role": "user", "content": input}]
    }
    response = post("http://localhost:8000/v1/chat/completions", json=payload)
    return response.json()["choices"][0]["message"]["content"]

gr.Interface(fn=chat, inputs="text", outputs="text").launch()
```

---

## 🧰 Final Notes

* All CI/CD steps are defined in [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
* The pipeline is triggered on **every commit to `main`** and **version tag push**
* The deployment phase **pulls from GHCR** and serves a model immediately

---

## 🧠 Want to Contribute?

Fork, improve the build process, or try deploying other quantized models using MLC’s build tools.

---

## 📌 Links

* 🔗 [MLC-LLM Docs](https://llm.mlc.ai/)
* 🐙 [GitHub Repo](https://github.com/b4uharsha/mlc-llm)
* 📆 [GitHub Release](https://github.com/b4uharsha/mlc-llm/releases)

---
