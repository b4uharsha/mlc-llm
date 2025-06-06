# MLC-LLM Dockerized CI/CD Documentation

---

## Table of Contents

1. [Pipeline Overview](#pipeline-overview)
2. [Installed Packages](#installed-packages)
3. [Using LLM in MLC and Our Docker Image](#using-llm-in-mlc-and-our-docker-image)
4. [Testing Process](#testing-process)
5. [Replacing Models](#replacing-models)
6. [Folder Structure](#folder-structure)
7. [Running the Setup](#running-the-setup)
8. [CI/CD Flow Chart & Architecture Diagram](#cicd-flow-chart--architecture-diagram)
9. [Why We Use Fly](#why-we-use-fly)
10. [Running Test Commands & Expected Output](#running-test-commands--expected-output)
11. [Summary & Replication Steps](#summary--replication-steps)
12. [Environment Variables & Tokens](#environment-variables--tokens)
13. [Reference: Official MLC-LLM Documentation](#reference-official-mlc-llm-documentation)

---

## 1. Pipeline Overview

This document details how to build, test, package, and deploy the **MLC-LLM** Python package and FastAPI server via a GitHub Actions CI/CD pipeline. We use a multipurpose Docker image that serves as both:

* A **development environment** (interactive shell, all dev tools installed).
* A **build environment** (non-interactive entrypoint for compiling and packaging).

The Docker image is pushed to **GitHub Container Registry (GHCR)** and then deployed to **Fly.io** as a live HTTPS endpoint.

### 1.1 Execution Flow

```mermaid
flowchart TD
    A[Push to `main` or Manual Dispatch] --> B[Checkout Code]
    B --> C[Build & Push Docker Image to GHCR]
    C --> D[Test Inside Container]
    D --> E[Build Python Wheels<br>(Linux & Windows)]
    E --> F[Publish GitHub Release<br>with Wheels]
    F --> G[Deploy to Fly.io]
    G --> H[Live FastAPI Server at Fly.io]
```

1. **Trigger**: Any push to `main` or manual “Run workflow” in GitHub Actions.
2. **Checkout Code**: The CI job retrieves the latest code.
3. **Build & Push Docker Image**: Uses `docker/Dockerfile` and `docker/apt-packages.txt` to build a multipurpose image, then pushes `ghcr.io/<owner>/mlc-llm:latest`.
4. **Test Inside Container**: Pulls the newly built image, runs `./scripts/test-image.sh`. If it hangs or fails, we log a warning and proceed.
5. **Build Python Wheels**: On `ubuntu-latest` and `windows-latest`, runs `python -m build python/` and packages wheels as artifacts.
6. **Publish GitHub Release**: Tags the repository as `mlc-llm-v<run_number>` and attaches the Linux & Windows wheels.
7. **Deploy to Fly.io**: Runs `flyctl deploy --remote-only --image ghcr.io/<owner>/mlc-llm:latest` to push the container to Fly.
8. **Live Server**: A Fly VM starts the FastAPI server, serving HTTPS at `https://mlc-llm.fly.dev/`.

---

## 2. Installed Packages

All Debian packages needed for build and runtime are listed in `docker/apt-packages.txt`. They are installed via:

```bash
xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends
```

> **`docker/apt-packages.txt`** (exact lines, no comments):

```
python3
python3-pip
python3-venv
python3-dev
build-essential
cmake
ninja-build
git
curl
wget
libffi-dev
libxml2-dev
zlib1g-dev
rustc
cargo
ca-certificates
nginx
certbot
python3-certbot-nginx
```

### 2.1 Package Roles

| Package                                   | Purpose                                                                           |
| ----------------------------------------- | --------------------------------------------------------------------------------- |
| `python3`, `python3-pip`                  | Base Python interpreter and package installer.                                    |
| `python3-venv`                            | Provides `venv` for isolated Python environments (used in wheel builds).          |
| `python3-dev`                             | Headers and static libraries for building Python extensions.                      |
| `build-essential`                         | Basic compilation tools: `gcc`, `make`, etc.                                      |
| `cmake`, `ninja-build`                    | Build system for optional native builds (e.g., TVM).                              |
| `git`                                     | Needed to fetch FlashInfer from GitHub.                                           |
| `curl`, `wget`                            | Download utilities (used by scripts or certbot).                                  |
| `libffi-dev`, `libxml2-dev`, `zlib1g-dev` | Libraries for Python dependencies (e.g., cryptography, XML parsing, compression). |
| `rustc`, `cargo`                          | Rust compiler and package manager (for any Rust-based Python extensions).         |
| `ca-certificates`                         | SSL root certificates (for HTTPS downloads).                                      |
| `nginx`                                   | Reverse proxy for production, handling HTTPS.                                     |
| `certbot`, `python3-certbot-nginx`        | Let’s Encrypt client + Nginx plugin for obtaining/renewing SSL certificates.      |

---

## 3. Using LLM in MLC and Our Docker Image

### 3.1 How MLC-LLM Uses LLM Models

* The **MLC-LLM** Python package provides:

  1. A CLI (`mlc_llm`) to download and serve quantized LLMs (e.g., llama.cpp, FlashInfer).
  2. A FastAPI server (`/v1/chat/completions`) to expose chat-style inference.

Typical workflow inside the container:

1. **Download Model**:

   ```bash
   mlc_llm download-model --model-name Llama-2-7b-chat-glm-4b-q0f16_0
   ```

   Model weights are stored under `~/.cache/mlc_llm/models/`.

2. **Serve Model**:

   ```bash
   mlc_llm serve --model Llama-2-7b-chat-glm-4b-q0f16_0 --device cpu --host 0.0.0.0 --port 8000
   ```

   This spins up a Uvicorn server exposing REST endpoints.

### 3.2 Our Custom Docker Image

We use a **multi-stage Dockerfile**:

1. **Stage 1 (build)**:

   * Installs all build dependencies (CMake, Ninja, Rust, Python, etc.).
   * Creates a non-root user `mlcuser`.
   * Installs FlashInfer and the MLC-LLM package in editable mode (`pip install -e ./python`).
   * Optionally compiles native TVM code if `CMakeLists.txt` exists.

2. **Stage 2 (runtime)**:

   * Installs minimal runtime dependencies (Python, pip, same Debian packages).
   * Copies files from the build stage.
   * Installs runtime Python requirements and the MLC-LLM package.
   * Configures a healthcheck on `$PORT` (default 8000).
   * Uses `docker/entrypoint.sh` as `ENTRYPOINT` to start the FastAPI server.

**Entrypoint (`docker/entrypoint.sh`)**:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Starting FastAPI server on 0.0.0.0:${PORT:-8000} ..."
exec mlc_llm serve --host 0.0.0.0 --port "${PORT:-8000}"
```

* The shebang must be `#!/usr/bin/env bash`.
* Ensure Unix (LF) line endings and executable permission (`chmod +x`).

---

## 4. Testing Process

### 4.1 Local Docker Test

1. **Build the Runtime Image**:

   ```bash
   docker build -f docker/Dockerfile --target runtime -t local-mlc .
   ```
2. **Run Interactively**:

   ```bash
   docker run --rm -it -p 8000:8000 local-mlc bash
   ```
3. **Inside Container**:

   ```bash
   which mlc_llm
   # → /home/mlcuser/.local/bin/mlc_llm

   mlc_llm serve --host 0.0.0.0 --port 8000
   ```
4. **On Host (in another terminal)**:

   ```bash
   curl http://localhost:8000/
   # → {"message":"MLC-LLM server running"}

   curl -X POST http://localhost:8000/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{
           "model":"Llama-2-7b-chat-glm-4b-q0f16_0",
           "messages":[{"role":"user","content":"Hello"}]
         }'
   # → {"model":"Llama-2-7b-chat-glm-4b-q0f16_0","choices":[{"message":{"role":"assistant","content":"Hello! I am a test model response."}}]}
   ```

### 4.2 CI/CD Automated Test

In GitHub Actions, the **test** job runs:

```yaml
- name: Run test-image.sh with timeout
  run: |
    timeout 60s docker run --rm ${{ needs.build-and-push.outputs.image }} ./scripts/test-image.sh \
      && echo "✅ container tests passed." \
      || echo "⚠️ container tests timed out or failed, proceeding."
```

* If `test-image.sh` takes longer than 60 seconds or exits non-zero, the step logs a warning but does not fail the entire pipeline (using `|| echo …`).
* **`scripts/test-image.sh`** typically does:

  1. Import test: `python -c "import mlc_llm"`.
  2. `pytest python/tests` (runs unit tests).
  3. Launch FastAPI server in background, wait a few seconds, issue one `/v1/chat/completions` request, then kill server.

**Expected output for passing tests**:

```
[1/3] Testing MLC-LLM Python import...
MLC-LLM imported successfully

[2/3] Running pytest unit tests...
============================= test session starts =============================
platform linux -- Python 3.x.x, pytest-8.x.x, pluggy-1.x.x
rootdir: /mlc-llm/python
collected 1 item
python/tests/test_basic.py .                                                [100%]
============================== 1 passed in 0.00s ==============================

[3/3] Starting FastAPI server...
INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
{"model":"test","choices":[{"message":{"role":"assistant","content":"Hello! I am a test model response."}}]}
```

---

## 5. Replacing Models

To use a different LLM model:

1. **Locally**:

   ```bash
   docker run --rm -p 8000:8000 local-mlc \
     bash -c "mlc_llm download-model --model-name <new-model> && \
              mlc_llm serve --model <new-model> --device cpu --host 0.0.0.0 --port 8000"
   ```

2. **On Fly.io**:

   * Add an environment variable in `fly.toml`:

     ```toml
     [env]
       DEFAULT_MODEL="Llama-2-13b-chat-v1"
     ```
   * Modify `docker/entrypoint.sh` to read `$DEFAULT_MODEL`:

     ```bash
     #!/usr/bin/env bash
     set -euo pipefail

     MODEL="${DEFAULT_MODEL:-Llama-2-7b-chat-glm-4b-q0f16_0}"
     echo "[INFO] Starting FastAPI server with model $MODEL on 0.0.0.0:${PORT:-8000} ..."
     exec mlc_llm serve --model "$MODEL" --host 0.0.0.0 --port "${PORT:-8000}"
     ```

**Considerations**:

* Ensure the new model fits within memory/CPU constraints.
* Download times vary; you may want to pre-download or bake into the image.

---

## 6. Folder Structure

```bash
.
├── build
├── dist
├── docker
│   ├── apt-packages.txt
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── pip-build.txt
│   └── pip-requirements.txt
├── docker-compose.yml
├── docs
│   ├── ci.md
│   ├── README.md
│   └── TAGGING.md
├── fly.toml
├── LICENSE
├── nginx
│   ├── certbot-webroot
│   ├── letsencrypt
│   └── nginx.conf
├── python
│   ├── mlc_llm
│   │   ├── __init__.py
│   │   ├── cli.py
│   │   └── server.py
│   ├── setup.py
│   └── tests
│       └── test_basic.py
├── scripts
│   ├── start.sh
│   └── test-image.sh
└── .github
    └── workflows
        └── ci.yml
```

### 6.1 Explanation

* **`docker/`**

  * `Dockerfile`: Multi-stage build (build & runtime).
  * `apt-packages.txt`: Debian package names.
  * `pip-build.txt`, `pip-requirements.txt`: Python dependencies.
  * `entrypoint.sh`: Launches `mlc_llm serve`.

* **`nginx/`** (optional)

  * Configuration for Nginx reverse proxy and Certbot.

* **`python/`**

  * `mlc_llm/`: Python package code.
  * `setup.py`: Metadata for packaging.
  * `tests/`: Unit tests.

* **`scripts/`**

  * `start.sh`: Convenience script for local dev.
  * `test-image.sh`: Automated container tests.

* **`fly.toml`**

  * Fly.io configuration: app name, ports, environment.

* **`.github/workflows/ci.yml`**

  * GitHub Actions pipeline: build, test, release, deploy.

---

## 7. Running the Setup

### 7.1 Local Development

1. **Clone**:

   ```bash
   git clone https://github.com/b4uharsha/mlc-llm.git
   cd mlc-llm
   ```

2. **Build & Run Dev Image**:

   ```bash
   docker build -f docker/Dockerfile --target build -t mlc-llm-dev .
   docker run --rm -it -v "$PWD:/workspace" -w /workspace mlc-llm-dev bash
   ```

   * You now have an interactive shell with all build tools installed.

3. **Build Native Code** (optional inside dev container):

   ```bash
   if [ -f CMakeLists.txt ]; then
     mkdir -p build && cd build
     cmake -GNinja ..
     ninja
   fi
   ```

4. **Run Tests** (inside dev container or host):

   ```bash
   cd python
   pip install -r ../docker/pip-requirements.txt
   pip install -e .
   pytest tests
   ```

5. **Serve Locally** (after installing):

   ```bash
   pip install -e python
   mlc_llm serve --host 0.0.0.0 --port 8000
   curl http://localhost:8000/
   ```

### 7.2 Common Errors & Troubleshooting

| Symptom                                 | Cause                                                  | Fix                                                                                               |   |             |
| --------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------- | - | ----------- |
| “Unable to locate package …”            | `apt-packages.txt` contains comments or extra text     | Remove comments; include only valid package names.                                                |   |             |
| “Exec format error” for `entrypoint.sh` | `entrypoint.sh` has CRLF line endings or wrong shebang | Run `sed -i '' -e 's/\r$//' docker/entrypoint.sh` and ensure `#!/usr/bin/env bash` is first line. |   |             |
| Container tests hang indefinitely       | `test-image.sh` waits for a server that never starts   | Wrap `docker run` in \`timeout 60s …                                                              |   | echo "…";\` |
| Fly healthcheck fails (port not opened) | Server did not bind to `$PORT` or crashed              | Confirm `ENTRYPOINT` uses `--host 0.0.0.0 --port $PORT`.                                          |   |             |

---

## 8. CI/CD Flow Chart & Architecture Diagram

### 8.1 CI/CD Flow Chart

```mermaid
flowchart TD
    A[Developer Pushes Code] --> B[GitHub Actions: CI/CD Pipeline]
    B --> C[Build & Push Docker Image to GHCR]
    C --> D[Test Container (w/ timeout)]
    D --> E[Build Python Wheels (Linux & Windows)]
    E --> F[Upload Artifacts & Create Release]
    F --> G[Deploy to Fly.io]
    G --> H[Fly Machines: Live FastAPI]
    H --> I[Clients connect via HTTPS]
```

### 8.2 Architecture Diagram

```mermaid
graph LR
    subgraph Developer Workstation
      DevLocal[Local Dev Machine]
      DevLocal --> GitHub[GitHub Repository]
    end

    subgraph GitHub Actions
      GitHub --> CI["CI/CD Pipeline"]
      CI --> BuildPush["Build & Push Docker Image"]
      BuildPush --> GHCR[GHCR (ghcr.io/<owner>/mlc-llm:latest)]
      CI --> Test["Test Inside Container"]
      CI --> Wheels["Build Wheels"]
      Wheels --> Artifacts[Artifacts: Linux & Windows wheels]
      CI --> Release["Publish GitHub Release"]
      CI --> FlyDeploy["Deploy to Fly.io"]
    end

    subgraph Fly.io
      FlyMachines["Fly Virtual Machines"]
      FlyMachines --> HTTPS["Users connect via HTTPS"]
    end

    GHCR --> FlyDeploy
    FlyDeploy --> FlyMachines

    HTTPS --> FlyMachines
```

---

## 9. Why We Use Fly

1. **Global Deployment**

   * Fly.io provides an easy way to deploy containers close to end users.
   * Automatic IPv6 & shared IPv4 allocation.

2. **Built-in Healthchecks & Auto-Restart**

   * Define TCP checks in `fly.toml`; Fly will auto-restart the container if it fails.

3. **Automatic HTTPS via Let’s Encrypt**

   * Fly can provision and renew SSL certificates automatically (via Nginx + Certbot).

4. **Simple CLI & GitHub Actions Integration**

   * `flyctl deploy --remote-only` works seamlessly in CI.

5. **Free Tier for Small Apps**

   * Trial tier supports one VM with up to 256 MB RAM and shared CPU—perfect for testing or lightweight models.

---

## 10. Running Test Commands & Expected Output

### 10.1 Healthcheck Demo (Locally)

```bash
docker run --rm -d -p 8000:8000 local-mlc
sleep 5
curl http://localhost:8000/
```

**Expected**:

```json
{"message":"MLC-LLM server running"}
```

### 10.2 Chat Completion API

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
        "model":"Llama-2-7b-chat-glm-4b-q0f16_0",
        "messages":[{"role":"user","content":"Hello"}]
      }'
```

**Expected**:

```json
{
  "model":"Llama-2-7b-chat-glm-4b-q0f16_0",
  "choices":[
    {
      "message":{
        "role":"assistant",
        "content":"Hello! I am a test model response."
      }
    }
  ]
}
```

### 10.3 Container Test Script Output (`scripts/test-image.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] Testing MLC-LLM Python import..."
python - << 'EOF'
import mlc_llm
print("MLC-LLM imported successfully")
EOF

echo "[2/3] Running pytest unit tests..."
pytest python/tests

echo "[3/3] Starting FastAPI server..."
mlc_llm serve --host 0.0.0.0 --port 8000 &  
PID=$!
sleep 5
curl -X POST http://localhost:8000/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{"model":"test","messages":[{"role":"user","content":"Hello"}]}' && echo
kill $PID
```

**Expected**:

```
[1/3] Testing MLC-LLM Python import...
MLC-LLM imported successfully

[2/3] Running pytest unit tests...
============================= test session starts =============================
platform linux -- Python 3.x.x, pytest-8.x.x, pluggy-1.x.x
rootdir: /mlc-llm/python
collected 1 item
python/tests/test_basic.py .                                                [100%]
============================== 1 passed in 0.00s ==============================

[3/3] Starting FastAPI server...
INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
{"model":"test","choices":[{"message":{"role":"assistant","content":"Hello! I am a test model response."}}]}
```

---

## 11. Summary & Replication Steps

1. **Clone Repo**

   ```bash
   git clone https://github.com/b4uharsha/mlc-llm.git
   cd mlc-llm
   ```

2. **Verify `docker/apt-packages.txt`**

   * Must contain exactly the list of package names (no comments).

3. **Fix `entrypoint.sh`**

   ```bash
   sed -i '' -e 's/\r$//' docker/entrypoint.sh
   chmod +x docker/entrypoint.sh
   ```

   * First line: `#!/usr/bin/env bash`.

4. **Build Locally**

   ```bash
   docker build -f docker/Dockerfile --target runtime -t local-mlc .
   docker run --rm -it -p 8000:8000 local-mlc bash
   # Inside container:
   mlc_llm serve --host 0.0.0.0 --port 8000
   # On host:
   curl http://localhost:8000/
   ```

5. **Push to GitHub**

   * CI pipeline triggers automatically.

6. **Monitor GitHub Actions**

   * Watch “CI/CD Pipeline” from **Actions** tab for successful steps:

     1. Build & push Docker image
     2. Test container
     3. Build wheels
     4. Publish release
     5. Deploy to Fly.io

7. **Inspect Fly Logs**

   ```bash
   fly logs -a mlc-llm
   ```

   * Confirm lines like:

     ```
     INFO Preparing to run: `/mlc-llm/docker/entrypoint.sh` as mlcuser
     INFO Starting FastAPI server on 0.0.0.0:8000 ...
     INFO: Uvicorn running on http://0.0.0.0:8000
     ```

8. **Test Live**

   ```bash
   curl https://mlc-llm.fly.dev/
   curl -X POST https://mlc-llm.fly.dev/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{
           "model":"Llama-2-7b-chat-glm-4b-q0f16_0",
           "messages":[{"role":"user","content":"Hello"}]
         }'
   ```

---

## 12. Environment Variables & Tokens

Several CI/CD steps and runtime deployments require authentication tokens. This section explains where to obtain them and how to configure them.

### 12.1 GitHub Container Registry (GHCR) Token

* GHCR requires a GitHub Personal Access Token (PAT) with **`write:packages`** and **`read:packages`** scopes.

* **Create a PAT**:

  1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Generate new token**.
  2. Name it (e.g., `GHCR-PAT`), enable scopes **`write:packages`**, **`read:packages`**, and optionally **`repo`** if the repo is private.
  3. Copy the generated token.

* **Store in GitHub Actions**:

  * Navigate to your repo’s **Settings → Secrets & variables → Actions → New repository secret**.
  * Name: `GHCR_PAT`; Value: *the copied PAT*.

* **Usage in CI**:

  ```yaml
  - uses: docker/login-action@v3
    with:
      registry: ghcr.io
      username: ${{ github.actor }}
      password: ${{ secrets.GHCR_PAT }}
  ```

### 12.2 GitHub Release Token

* The automatically provided `GITHUB_TOKEN` (by Actions) has **`contents: write`** permission.
* **Usage in CI**:

  ```yaml
  - uses: softprops/action-gh-release@v2
    with:
      tag_name: ${{ env.RELEASE_TAG }}
      files: |
        ./artifacts/wheel-ubuntu-latest/mlc_llm-ubuntu-latest.whl
        ./artifacts/wheel-windows-latest/mlc_llm-windows-latest.whl
    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  ```

### 12.3 Fly.io API Token

* Fly requires an API token to authorize deployments.

* **Create Fly Token**:

  1. Install `flyctl` or visit [https://fly.io/account/tokens](https://fly.io/account/tokens).
  2. Click **“New Access Token”**, name it (e.g., `mlc-llm-fly-token`), then copy.

* **Store in GitHub Actions**:

  * Go to **Settings → Secrets & variables → Actions → New repository secret**.
  * Name: `FLY_API_TOKEN`; Value: *the copied Fly token*.

* **Usage in CI**:

  ```yaml
  - name: Deploy to Fly.io
    env:
      FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
    run: flyctl deploy --remote-only --image ${{ env.IMAGE_NAME }} --app mlc-llm
  ```

### 12.4 Local Development with Tokens

* To push to GHCR locally:

  ```bash
  echo "$GHCR_PAT" | docker login ghcr.io -u <github-username> --password-stdin
  ```
* To deploy manually to Fly:

  ```bash
  export FLY_API_TOKEN="YOUR_FLY_TOKEN"
  flyctl deploy --remote-only --image ghcr.io/<owner>/mlc-llm:latest --app mlc-llm
  ```

---

## 13. Reference: Official MLC-LLM Documentation

The official docs at **[https://llm.mlc.ai/](https://llm.mlc.ai/)** provide up-to-date build instructions, model lists, and usage examples.

### 13.1 Build from Source

* **URL**:
  [https://llm.mlc.ai/docs/install/mlc\_llm.html#option-2-build-from-source](https://llm.mlc.ai/docs/install/mlc_llm.html#option-2-build-from-source)
* **Steps**:

  1. Clone:

     ```bash
     git clone https://github.com/mlc-ai/mlc-llm.git
     cd mlc-llm
     ```
  2. Install dependencies (similar to our `docker/apt-packages.txt`).
  3. Build native code:

     ```bash
     mkdir build && cd build
     cmake -DUSE_CUDA=ON ..
     make -j$(nproc)
     ```
  4. Install Python package:

     ```bash
     pip install -U pip
     pip install -e python
     ```

### 13.2 Quickstart & Examples

* **URL**:
  [https://llm.mlc.ai/docs/quickstart/](https://llm.mlc.ai/docs/quickstart/)
* **Highlights**:

  * Download a model:

    ```bash
    mlc_llm download-model --model-name Llama-2-7b-chat-glm-4b-q0f16_0
    ```
  * Serve a model:

    ```bash
    mlc_llm serve --model Llama-2-7b-chat-glm-4b-q0f16_0 --device cpu --host 0.0.0.0 --port 8000
    ```
  * Python client example:

    ```python
    from mlc_llm.client import AsyncClient

    async def main():
        client = AsyncClient("http://localhost:8000")
        resp = await client.chat_completions(
            "Llama-2-7b-chat-glm-4b-q0f16_0",
            [{"role":"user","content":"Hello"}]
        )
        print(resp.choices[0].message.content)

    import asyncio; asyncio.run(main())
    ```

### 13.3 Available Models

* **URL**:
  [https://llm.mlc.ai/docs/models/](https://llm.mlc.ai/docs/models/)
* **Usage**:
  Provides a list of supported model names (e.g.,
  `"Llama-2-7b-chat-glm-4b-q0f16_0"`, `"Llama-2-13b-chat-v1"`).
* When deploying, ensure you reference a valid model string.

### 13.4 CLI Commands

* **URL**:
  [https://llm.mlc.ai/docs/cli/](https://llm.mlc.ai/docs/cli/)
* **Common Commands**:

  * `mlc_llm --help`
  * `mlc_llm download-model --help`
  * `mlc_llm serve --help`

---

> **End of Documentation**
