# syntax=docker/dockerfile:1.6
ARG PYTHON_VERSION=3.10

#########################
# Stage 1: Development & Build
#########################
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04 AS build

WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

# Preload dependency lists for caching
COPY docker/apt-packages.txt /tmp/apt-packages.txt
COPY docker/pip-build.txt /tmp/pip-build.txt
COPY docker/pip-requirements.txt /tmp/pip-requirements.txt

# Install system packages and Python tooling
RUN apt-get update && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip && \
    pip install --no-cache-dir -r /tmp/pip-build.txt -r /tmp/pip-requirements.txt

# Copy full source and install
COPY . /mlc-llm
RUN chmod +x /mlc-llm/scripts/*.sh /mlc-llm/docker/entrypoint.sh

# Install MLC-LLM and FlashInfer (editable)
RUN pip install --no-cache-dir "git+https://github.com/flashinfer-ai/flashinfer@v0.2.5" && \
    pip install --no-cache-dir -e ./python

# Optional native build (TVM)
RUN if [ -f CMakeLists.txt ]; then \
      mkdir -p build && cd build && cmake -GNinja .. && ninja; \
    else \
      echo "No CMakeLists.txt found. Skipping native build."; \
    fi

#########################
# Stage 2: Runtime Image
#########################
FROM nvidia/cuda:12.2.2-runtime-ubuntu22.04 AS runtime

WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

# Minimal system deps + nginx, certbot for HTTPS
COPY docker/apt-packages.txt /tmp/apt-packages.txt
RUN apt-get update && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends \
    nginx certbot python3-certbot-nginx && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup Python
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip

# Copy MLC-LLM source and re-install cleanly
COPY --from=build /mlc-llm /mlc-llm
RUN pip install --no-cache-dir -r /mlc-llm/docker/pip-requirements.txt && \
    pip install --no-cache-dir -e /mlc-llm/python

# Runtime ENV setup
ENV TVM_LIBRARY_PATH=/mlc-llm/build
ENV LD_LIBRARY_PATH=/mlc-llm/build:$LD_LIBRARY_PATH
ENV PORT=8000

# Healthcheck & Runtime
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s CMD python -c "import mlc_llm" || exit 1
EXPOSE 80 443

# Entrypoint: certbot renewal + nginx + mlc_llm serve
ENTRYPOINT ["/mlc-llm/docker/entrypoint.sh"]
VOLUME ["/var/www/certbot", "/etc/letsencrypt"]
