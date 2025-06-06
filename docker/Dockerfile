# syntax=docker/dockerfile:1.6
ARG PYTHON_VERSION=3.10

#########################
# Stage 1: Development & Build
#########################
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04 AS build

LABEL maintainer="Your Name <you@example.com>"

WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

# Create a non-root user 'mlcuser'
RUN groupadd -g 1001 mlcgroup && \
    useradd -m -u 1001 -g mlcgroup -s /bin/bash mlcuser

# Copy apt and pip lists for caching
COPY docker/apt-packages.txt       /tmp/apt-packages.txt
COPY docker/pip-build.txt          /tmp/pip-build.txt
COPY docker/pip-requirements.txt   /tmp/pip-requirements.txt

# Install all build dependencies (including nginx, certbot if you ever need them)
RUN apt-get update --allow-releaseinfo-change && \
    apt-get install -y --no-install-recommends apt-utils && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Symlink python3 → python, pip3 → pip, then upgrade pip and install Python build deps
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip && \
    pip install --no-cache-dir -r /tmp/pip-build.txt -r /tmp/pip-requirements.txt

# Copy entire repo into the build stage
COPY . /mlc-llm

# Make sure scripts and entrypoint are executable
RUN chmod +x /mlc-llm/scripts/*.sh /mlc-llm/docker/entrypoint.sh

# Change ownership to mlcuser
RUN chown -R mlcuser:mlcgroup /mlc-llm

# Switch to non-root user for the remainder of the build
USER mlcuser

# Ensure console‐scripts go into ~/.local/bin
ENV PATH="/home/mlcuser/.local/bin:$PATH"

# Install FlashInfer and MLC-LLM in editable mode
RUN pip install --no-cache-dir "git+https://github.com/flashinfer-ai/flashinfer@v0.2.5" && \
    pip install --no-cache-dir -e ./python

# Optional native build (CMake + Ninja) if CMakeLists.txt exists
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

# Create the same non-root user
RUN groupadd -g 1001 mlcgroup && \
    useradd -m -u 1001 -g mlcgroup -s /bin/bash mlcuser

# Copy apt-packages list
COPY docker/apt-packages.txt /tmp/apt-packages.txt

# Install minimal runtime dependencies
RUN apt-get update --allow-releaseinfo-change && \
    apt-get install -y --no-install-recommends apt-utils && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Symlink python3 → python, pip3 → pip, then upgrade pip
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip

# Copy everything from the build stage into the runtime image
COPY --from=build /mlc-llm /mlc-llm

# Change ownership of the copied files to mlcuser
RUN chown -R mlcuser:mlcgroup /mlc-llm

# Switch to non-root user
USER mlcuser

# Ensure console‐scripts go into ~/.local/bin
ENV PATH="/home/mlcuser/.local/bin:$PATH"

# Install runtime Python requirements + editable install
RUN pip install --no-cache-dir -r /mlc-llm/docker/pip-requirements.txt && \
    pip install --no-cache-dir -e /mlc-llm/python

# Environment variables
ENV TVM_LIBRARY_PATH=/mlc-llm/build
ENV LD_LIBRARY_PATH=/mlc-llm/build:$LD_LIBRARY_PATH
ENV PORT=8000

# Healthcheck: ensure FastAPI can bind to $PORT
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
  CMD python - << 'EOF'
import socket, os, sys
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
try:
    s.connect(("localhost", int(os.environ.get("PORT", "8000"))))
    s.close()
    sys.exit(0)
except:
    sys.exit(1)
EOF

# Expose the chosen port
EXPOSE 8000

# Final entrypoint: launch the FastAPI server as mlcuser
ENTRYPOINT ["/mlc-llm/docker/entrypoint.sh"]

# Allow `docker run -v /workspace` if desired
VOLUME ["/workspace"]
