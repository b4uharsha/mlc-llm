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

# Install build dependencies
RUN apt-get update --allow-releaseinfo-change && \
    apt-get install -y --no-install-recommends apt-utils && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure python3 and pip are linked
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip && \
    pip install --no-cache-dir -r /tmp/pip-build.txt -r /tmp/pip-requirements.txt

# Copy all source files
COPY . /mlc-llm

# Make scripts executable
RUN chmod +x /mlc-llm/scripts/*.sh /mlc-llm/docker/entrypoint.sh

# Install FlashInfer and your mlc_llm package in editable mode
RUN pip install --no-cache-dir "git+https://github.com/flashinfer-ai/flashinfer@v0.2.5" && \
    pip install --no-cache-dir -e ./python

# (Optional) native build if CMakeLists.txt exists
RUN if [ -f CMakeLists.txt ]; then \
      mkdir -p build && cd build && cmake -GNinja .. && ninja; \
    else \
      echo "[INFO] No CMakeLists.txt found, skipping native build."; \
    fi

#########################
# Stage 2: Runtime
#########################
FROM nvidia/cuda:12.2.2-runtime-ubuntu22.04 AS runtime

WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

# Copy package list for runtime deps
COPY docker/apt-packages.txt /tmp/apt-packages.txt

# Install minimal runtime dependencies
RUN apt-get update --allow-releaseinfo-change && \
    apt-get install -y --no-install-recommends apt-utils && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure python symlinks
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip

# Copy built files from build stage
COPY --from=build /mlc-llm /mlc-llm

# Install Python dependencies again and your package
RUN pip install --no-cache-dir -r /mlc-llm/docker/pip-requirements.txt && \
    pip install --no-cache-dir -e /mlc-llm/python

ENV TVM_LIBRARY_PATH=/mlc-llm/build
ENV LD_LIBRARY_PATH=/mlc-llm/build:$LD_LIBRARY_PATH
ENV PORT=8000

# Healthcheck: verify python import
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
    CMD python -c "import mlc_llm" || exit 1

EXPOSE 8000

# Entrypoint that launches the FastAPI server
ENTRYPOINT ["/mlc-llm/docker/entrypoint.sh"]
VOLUME ["/workspace"]
