# syntax=docker/dockerfile:1.6
ARG PYTHON_VERSION=3.10

### ======================
### Build Stage
### ======================
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04 AS build

WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

# Install system packages
COPY docker/apt-packages.txt /tmp/apt-packages.txt
RUN apt-get update && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY docker/pip-build.txt /tmp/pip-build.txt
COPY docker/pip-requirements.txt /tmp/pip-requirements.txt
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip && \
    pip install --no-cache-dir -r /tmp/pip-build.txt && \
    pip install --no-cache-dir -r /tmp/pip-requirements.txt

# Copy source and install
COPY . /mlc-llm
RUN chmod +x /mlc-llm/scripts/*.sh /mlc-llm/docker/entrypoint.sh

# Install flashinfer
RUN pip install --no-cache-dir "git+https://github.com/flashinfer-ai/flashinfer@v0.2.5"

# Editable install of mlc-llm
RUN pip install --no-cache-dir -e ./python

# Build native libs if CMakeLists.txt exists
RUN if [ -f CMakeLists.txt ]; then \
      mkdir -p build && cd build && \
      cmake -GNinja .. && ninja; \
    else \
      echo "No CMakeLists.txt found. Skipping native build."; \
    fi

### ===========================
### Runtime Stage
### ===========================
FROM nvidia/cuda:12.2.2-runtime-ubuntu22.04 AS runtime

WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
COPY docker/apt-packages.txt /tmp/apt-packages.txt
RUN apt-get update && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set up Python
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip

# Copy only needed parts from build stage
COPY --from=build /mlc-llm /mlc-llm
COPY --from=build /usr/local/lib/python3.10/dist-packages/mlc_llm /usr/local/lib/python3.10/dist-packages/mlc_llm
COPY --from=build /usr/local/lib/python3.10/dist-packages/flashinfer* /usr/local/lib/python3.10/dist-packages/

# Set library path for runtime
ENV TVM_LIBRARY_PATH=/mlc-llm/build
ENV LD_LIBRARY_PATH=/mlc-llm/build:$LD_LIBRARY_PATH

# FastAPI port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s CMD python -c "import mlc_llm" || exit 1

ENTRYPOINT ["/mlc-llm/docker/entrypoint.sh"]
VOLUME ["/workspace"]
