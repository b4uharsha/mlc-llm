# syntax=docker/dockerfile:1.6
ARG PYTHON_VERSION=3.10

#########################
# Stage 1: Build
#########################
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04 AS build

WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

# Copy package lists for caching
COPY docker/apt-packages.txt /tmp/apt-packages.txt
COPY docker/pip-build.txt /tmp/pip-build.txt
COPY docker/pip-requirements.txt /tmp/pip-requirements.txt

# Install system packages needed to build
RUN apt-get update --allow-releaseinfo-change && \
    apt-get install -y --no-install-recommends apt-utils && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure python3/pip point to expected executables
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip && \
    pip install --no-cache-dir -r /tmp/pip-build.txt -r /tmp/pip-requirements.txt

# Copy entire repo into /mlc-llm
COPY . /mlc-llm

# Make sure scripts are executable
RUN chmod +x /mlc-llm/scripts/*.sh /mlc-llm/docker/entrypoint.sh

# Install FlashInfer and your mlc_llm package
RUN pip install --no-cache-dir "git+https://github.com/flashinfer-ai/flashinfer@v0.2.5" && \
    pip install --no-cache-dir -e ./python

# (Optional) Native build via CMake/TVM if present
RUN if [ -f CMakeLists.txt ]; then \
      mkdir -p build && cd build && cmake -GNinja .. && ninja; \
    else \
      echo "[INFO] No CMakeLists.txt found; skipping native build."; \
    fi

#########################
# Stage 2: Runtime
#########################
FROM nvidia/cuda:12.2.2-runtime-ubuntu22.04 AS runtime

WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

# Copy package list to install runtime dependencies
COPY docker/apt-packages.txt /tmp/apt-packages.txt

# Install minimal system dependencies (no nginx/certbot here—Fly.io provides TLS)
RUN apt-get update --allow-releaseinfo-change && \
    apt-get install -y --no-install-recommends apt-utils && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure python3/pip symlinks and upgrade pip
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip

# Copy over everything from build stage
COPY --from=build /mlc-llm /mlc-llm

# Install Python requirements and the mlc_llm package in editable mode
RUN pip install --no-cache-dir -r /mlc-llm/docker/pip-requirements.txt && \
    pip install --no-cache-dir -e /mlc-llm/python

# Environment for TVM libs (if any)
ENV TVM_LIBRARY_PATH=/mlc-llm/build
ENV LD_LIBRARY_PATH=/mlc-llm/build:$LD_LIBRARY_PATH
ENV PORT=8000

# Healthcheck: verify python import works
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
    CMD python -c "import mlc_llm" || exit 1

EXPOSE 8000

# Entrypoint: simply start the mlc_llm server on port 8000
ENTRYPOINT ["/mlc-llm/docker/entrypoint.sh"]
VOLUME ["/workspace"]
