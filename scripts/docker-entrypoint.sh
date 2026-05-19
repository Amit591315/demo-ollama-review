#!/usr/bin/env bash
# Entrypoint for the Docker container.
# Starts the Ollama daemon, waits for it, pulls the model if needed,
# then delegates to ollama-review.sh with all passed arguments.
set -euo pipefail

MODEL="${OLLAMA_REVIEW_MODEL:-llama3.2:3b}"

# Start Ollama daemon in the background
ollama serve &
OLLAMA_PID=$!

echo "Waiting for Ollama daemon..."
for i in $(seq 1 30); do
    ollama list >/dev/null 2>&1 && break
    sleep 1
done

if ! ollama list >/dev/null 2>&1; then
    echo "Error: Ollama daemon did not start in time." >&2
    exit 1
fi

# Pull model if not already present
if ! ollama list | grep -q "^${MODEL}"; then
    echo "Pulling model: $MODEL"
    ollama pull "$MODEL"
fi

# Run the review script, forwarding all arguments
exec /app/scripts/ollama-review.sh "$@"
