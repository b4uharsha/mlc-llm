# syntax=docker/dockerfile:1.6
ARG PYTHON_VERSION=3.10

#########################
# Stage 1: Development & Build
#########################
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04 AS build

LABEL maintainer="Your Name <you@example.com>"

WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

# 1) Create a non-root user 'mlcuser'
RUN groupadd -g 1001 mlcgroup && \
    useradd -m -u 1001 -g mlcgroup -s /bin/bash mlcuser

# 2) Copy apt/pip lists (must contain only real package names, no comments)
COPY docker/apt-packages.txt       /tmp/apt-packages.txt
COPY docker/pip-build.txt          /tmp/pip-build.txt
COPY docker/pip-requirements.txt   /tmp/pip-requirements.txt

# 3) Install all build dependencies
RUN apt-get update --allow-releaseinfo-change && \
    apt-get install -y --no-install-recommends apt-utils && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 4) Symlink python3→python, pip3→pip, upgrade pip, install Python build-only deps
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip && \
    pip install --no-cache-dir -r /tmp/pip-build.txt -r /tmp/pip-requirements.txt

# 5) Copy entire repository into build stage
COPY . /mlc-llm

# 6) Ensure scripts and entrypoint are executable
RUN chmod +x /mlc-llm/scripts/*.sh /mlc-llm/docker/entrypoint.sh

# 7) chown everything to mlcuser and switch to non-root
RUN chown -R mlcuser:mlcgroup /mlc-llm
USER mlcuser

# 8) Ensure ~/.local/bin is on PATH (console-scripts install here)
ENV PATH="/home/mlcuser/.local/bin:$PATH"

# 9) Install FlashInfer + MLC-LLM in editable mode
RUN pip install --no-cache-dir "git+https://github.com/flashinfer-ai/flashinfer@v0.2.5" && \
    pip install --no-cache-dir -e ./python

# 10) Optional native build (CMake + Ninja)
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

# 1) Create same non-root user
RUN groupadd -g 1001 mlcgroup && \
    useradd -m -u 1001 -g mlcgroup -s /bin/bash mlcuser

# 2) Copy the cleaned apt-packages list
COPY docker/apt-packages.txt /tmp/apt-packages.txt

# 3) Install minimal runtime dependencies
RUN apt-get update --allow-releaseinfo-change && \
    apt-get install -y --no-install-recommends apt-utils && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 4) Symlink python3→python, pip3→pip, upgrade pip
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip

# 5) Copy everything from the build stage
COPY --from=build /mlc-llm /mlc-llm

# 6) chown to mlcuser and switch to non-root
RUN chown -R mlcuser:mlcgroup /mlc-llm
USER mlcuser

# 7) Ensure ~/.local/bin is on PATH
ENV PATH="/home/mlcuser/.local/bin:$PATH"

# 8) Install runtime pip requirements + editable install
RUN pip install --no-cache-dir -r /mlc-llm/docker/pip-requirements.txt && \
    pip install --no-cache-dir -e /mlc-llm/python

# 9) Set environment variables
ENV TVM_LIBRARY_PATH=/mlc-llm/build
ENV LD_LIBRARY_PATH=/mlc-llm/build:$LD_LIBRARY_PATH
ENV PORT=8000

# 10) Healthcheck (Python one-liner)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s CMD \
    python -c "import socket, os, sys; s=socket.socket(); \
try: s.connect(( 'localhost', int(os.environ.get('PORT','8000')) )); s.close(); sys.exit(0) \
except: sys.exit(1)"

# 11) Expose port and entrypoint
EXPOSE 8000
ENTRYPOINT ["/mlc-llm/docker/entrypoint.sh"]

# 12) Allow mounting a workspace
VOLUME ["/workspace"]
