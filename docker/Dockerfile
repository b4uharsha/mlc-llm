# syntax=docker/dockerfile:1.6
ARG PYTHON_VERSION=3.10

#########################
# Stage 1: Development & Build
#########################
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04 AS build

LABEL maintainer="Your Name <you@example.com>"
WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

# Add non-root user
RUN groupadd -g 1001 mlcgroup && \
    useradd -m -u 1001 -g mlcgroup -s /bin/bash mlcuser

# Copy and install build dependencies
COPY docker/apt-packages.txt       /tmp/apt-packages.txt
COPY docker/pip-build.txt          /tmp/pip-build.txt
COPY docker/pip-requirements.txt   /tmp/pip-requirements.txt

RUN apt-get update --allow-releaseinfo-change && \
    apt-get install -y --no-install-recommends apt-utils && \
    apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv python3-dev \
      build-essential cmake ninja-build git curl wget \
      libffi-dev libxml2-dev zlib1g-dev rustc cargo \
      ca-certificates nginx certbot python3-certbot-nginx && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Python aliases and install
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip && \
    pip install --no-cache-dir -r /tmp/pip-build.txt -r /tmp/pip-requirements.txt

# Copy project and adjust ownership
COPY . /mlc-llm
RUN chown -R mlcuser:mlcgroup /mlc-llm
RUN chmod +x /mlc-llm/scripts/*.sh /mlc-llm/docker/entrypoint.sh

# Switch to non-root
USER mlcuser

# Install FlashInfer and MLC-LLM in editable mode
RUN pip install --no-cache-dir "git+https://github.com/flashinfer-ai/flashinfer@v0.2.5" && \
    pip install --no-cache-dir -e ./python

# Optional CMake build
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

# Add non-root user
RUN groupadd -g 1001 mlcgroup && \
    useradd -m -u 1001 -g mlcgroup -s /bin/bash mlcuser

# Install runtime dependencies
COPY docker/apt-packages.txt /tmp/apt-packages.txt
RUN apt-get update --allow-releaseinfo-change && \
    apt-get install -y --no-install-recommends apt-utils && \
    apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv python3-dev \
      build-essential cmake ninja-build git curl wget \
      libffi-dev libxml2-dev zlib1g-dev rustc cargo \
      ca-certificates nginx certbot python3-certbot-nginx && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip

# Copy everything from build stage and fix ownership
COPY --from=build /mlc-llm /mlc-llm
RUN chown -R mlcuser:mlcgroup /mlc-llm

# Set environment variables
ENV TVM_LIBRARY_PATH=/mlc-llm/build
ENV LD_LIBRARY_PATH=/mlc-llm/build:$LD_LIBRARY_PATH
ENV PORT=8000

# Switch to non-root user
USER mlcuser

# Healthcheck to confirm successful import
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
    CMD python -c "import mlc_llm" || exit 1

EXPOSE 8000
ENTRYPOINT ["/mlc-llm/docker/entrypoint.sh"]
VOLUME ["/workspace"]
