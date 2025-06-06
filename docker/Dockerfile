# syntax=docker/dockerfile:1.6
ARG PYTHON_VERSION=3.10

#########################
# Stage 1: Build
#########################
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04 AS build

WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

COPY docker/apt-packages.txt /tmp/apt-packages.txt
COPY docker/pip-build.txt /tmp/pip-build.txt
COPY docker/pip-requirements.txt /tmp/pip-requirements.txt

RUN apt-get update && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip && \
    pip install --no-cache-dir -r /tmp/pip-build.txt -r /tmp/pip-requirements.txt

COPY . /mlc-llm
RUN chmod +x /mlc-llm/scripts/*.sh /mlc-llm/docker/entrypoint.sh

RUN pip install --no-cache-dir "git+https://github.com/flashinfer-ai/flashinfer@v0.2.5" && \
    pip install --no-cache-dir -e ./python

#########################
# Stage 2: Runtime
#########################
FROM nvidia/cuda:12.2.2-runtime-ubuntu22.04 AS runtime

WORKDIR /mlc-llm
ENV DEBIAN_FRONTEND=noninteractive

COPY docker/apt-packages.txt /tmp/apt-packages.txt
RUN apt-get update && \
    xargs -a /tmp/apt-packages.txt apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install --upgrade pip

COPY --from=build /mlc-llm /mlc-llm
RUN pip install --no-cache-dir -r /mlc-llm/docker/pip-requirements.txt && \
    pip install --no-cache-dir -e /mlc-llm/python

ENV TVM_LIBRARY_PATH=/mlc-llm/build
ENV LD_LIBRARY_PATH=/mlc-llm/build:$LD_LIBRARY_PATH
ENV PORT=8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s CMD python -c "import mlc_llm" || exit 1
EXPOSE 8000

ENTRYPOINT ["/mlc-llm/docker/entrypoint.sh"]
VOLUME ["/workspace"]
