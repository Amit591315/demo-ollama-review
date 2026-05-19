#!/usr/bin/env bash
# Entrypoint for the Docker container.
# Starts the Ollama daemon, waits for it, builds/pulls models,
# then delegates to ollama-review.sh with all passed arguments.
set -euo pipefail

BASE_MODEL="${OLLAMA_REVIEW_MODEL:-llama3.2:3b}"
CUSTOM_MODEL="${OLLAMA_CUSTOM_MODEL_NAME:-cpp-raii-reviewer}"
MODELFILE="${OLLAMA_MODELFILE:-/app/prompts/Modelfile}"

# Start Ollama daemon in the background
echo "Starting Ollama daemon..."
ollama serve &
OLLAMA_PID=$!

echo "Waiting for Ollama daemon..."
for i in $(seq 1 60); do
    ollama list >/dev/null 2>&1 && echo "✓ Ollama ready." && break
    sleep 1
done

if ! ollama list >/dev/null 2>&1; then
    echo "Error: Ollama daemon did not start in time." >&2
    kill $OLLAMA_PID 2>/dev/null || true
    exit 1
fi

# Pull base model if not already present
if ! ollama list | grep -q "^${BASE_MODEL}"; then
    echo "Pulling base model: $BASE_MODEL"
    ollama pull "$BASE_MODEL"
else
    echo "✓ Base model already present: $BASE_MODEL"
fi

# Build custom model from Modelfile
if [[ -f "$MODELFILE" ]]; then
    echo "Building custom model '$CUSTOM_MODEL' from Modelfile..."
    if ollama create "$CUSTOM_MODEL" -f "$MODELFILE" 2>&1; then
        echo "✓ Custom model '$CUSTOM_MODEL' ready."
        # Run with custom model by default
        exec /app/scripts/ollama-review.sh --custom-model "$@"
    else
        echo "Warning: Failed to build custom model, falling back to base model."
        exec /app/scripts/ollama-review.sh "$@"
    fi
else
    echo "Modelfile not found at $MODELFILE, using base model."
    exec /app/scripts/ollama-review.sh "$@"
fi
