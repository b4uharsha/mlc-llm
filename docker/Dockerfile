# syntax=docker/dockerfile:1.6
ARG PYTHON_VERSION=3.10

#########################
# Stage 1: Development & Build
#########################
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04 AS build

LABEL maintainer="Your Name <you@example.com>"
WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

# 1. Copy package lists (so they cache well)
COPY docker/apt-packages.txt /tmp/apt-packages.txt
COPY docker/pip-build.txt     /tmp/pip-build.txt
COPY docker/pip-requirements.txt /tmp/pip-requirements.txt

# 2. Install system dependencies needed for build & dev
RUN apt-get update --allow-releaseinfo-change && \
    apt-get install -y --no-install-recommends apt-utils && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. Ensure python3/pip are available as python/pip
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip && \
    pip install --no-cache-dir -r /tmp/pip-build.txt -r /tmp/pip-requirements.txt

# 4. Copy source code
COPY . /mlc-llm

# 5. Make scripts executable
RUN chmod +x /mlc-llm/scripts/*.sh /mlc-llm/docker/entrypoint.sh

# 6. Install FlashInfer and MLC-LLM in editable mode
RUN pip install --no-cache-dir "git+https://github.com/flashinfer-ai/flashinfer@v0.2.5" && \
    pip install --no-cache-dir -e ./python

# 7. Optional: Native build (TVM) if CMakeLists.txt exists
RUN if [ -f CMakeLists.txt ]; then \
      mkdir -p build && cd build && cmake -GNinja .. && ninja; \
    else \
      echo "[INFO] No CMakeLists.txt found; skipping native build."; \
    fi

#########################
# Stage 2: Runtime Image
#########################
FROM nvidia/cuda:12.2.2-runtime-ubuntu22.04 AS runtime

LABEL maintainer="Your Name <you@example.com>"
WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

# 1. Copy package list for runtime-only deps
COPY docker/apt-packages.txt /tmp/apt-packages.txt

# 2. Install minimal system dependencies (no dev tools)
RUN apt-get update --allow-releaseinfo-change && \
    apt-get install -y --no-install-recommends apt-utils && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. Ensure python symlinks
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip

# 4. Copy built code from build stage
COPY --from=build /mlc-llm /mlc-llm

# 5. Install Python requirements and mlc-llm package
RUN pip install --no-cache-dir -r /mlc-llm/docker/pip-requirements.txt && \
    pip install --no-cache-dir -e /mlc-llm/python

# 6. Environment variables for TVM (if needed)
ENV TVM_LIBRARY_PATH=/mlc-llm/build
ENV LD_LIBRARY_PATH=/mlc-llm/build:$LD_LIBRARY_PATH
ENV PORT=8000

# 7. Healthcheck: confirm mlc_llm can import
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
    CMD python -c "import mlc_llm" || exit 1

# 8. Expose the application port
EXPOSE 8000

# 9. Entrypoint: start the FastAPI server
ENTRYPOINT ["/mlc-llm/docker/entrypoint.sh"]
VOLUME ["/workspace"]
