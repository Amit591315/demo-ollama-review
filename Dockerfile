FROM ubuntu:22.04

LABEL description="Local Ollama C++ RAII code reviewer"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.ai/install.sh | sh

COPY scripts/ /app/scripts/
COPY prompts/ /app/prompts/

RUN chmod +x /app/scripts/ollama-review.sh \
    && chmod +x /app/scripts/docker-entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/app/scripts/docker-entrypoint.sh"]
