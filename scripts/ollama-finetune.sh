#!/usr/bin/env bash
set -euo pipefail

BASE_MODEL="${OLLAMA_BASE_MODEL:-llama3.2:3b}"
MODEL_NAME="${OLLAMA_CUSTOM_MODEL_NAME:-cpp-raii-reviewer-ft}"
PROMPT_FILE="prompts/cpp-raii-analysis-prompt.txt"
ADAPTER_PATH=""
TEMPERATURE="0.2"
NUM_CTX="8192"
NUM_PREDICT="2048"

print_usage() {
	cat <<'EOF'
Usage: scripts/ollama-finetune.sh [options]

Build a specialized code-review model in Ollama.

Options:
	--base-model <name>    Base model to build from (default: llama3.2:3b)
	--model-name <name>    Output custom model name (default: cpp-raii-reviewer-ft)
	--prompt-file <path>   System prompt file to bake into model
	--adapter <path>       Optional LoRA/QLoRA adapter path for deeper tuning
	--temperature <value>  Temperature parameter (default: 0.2)
	--num-ctx <value>      Context window size (default: 8192)
	--num-predict <value>  Max generated tokens (default: 2048)
	-h, --help             Show this help

Examples:
	scripts/ollama-finetune.sh
	scripts/ollama-finetune.sh --model-name cpp-raii-reviewer --base-model llama3.2:3b
	scripts/ollama-finetune.sh --prompt-file prompts/cpp-raii-analysis-prompt.txt --adapter ./adapters/raii-lora
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--base-model)
			BASE_MODEL="${2:-}"
			[[ -n "$BASE_MODEL" ]] || { echo "Error: --base-model requires a value" >&2; exit 1; }
			shift 2
			;;
		--model-name)
			MODEL_NAME="${2:-}"
			[[ -n "$MODEL_NAME" ]] || { echo "Error: --model-name requires a value" >&2; exit 1; }
			shift 2
			;;
		--prompt-file)
			PROMPT_FILE="${2:-}"
			[[ -n "$PROMPT_FILE" ]] || { echo "Error: --prompt-file requires a value" >&2; exit 1; }
			shift 2
			;;
		--adapter)
			ADAPTER_PATH="${2:-}"
			[[ -n "$ADAPTER_PATH" ]] || { echo "Error: --adapter requires a value" >&2; exit 1; }
			shift 2
			;;
		--temperature)
			TEMPERATURE="${2:-}"
			[[ -n "$TEMPERATURE" ]] || { echo "Error: --temperature requires a value" >&2; exit 1; }
			shift 2
			;;
		--num-ctx)
			NUM_CTX="${2:-}"
			[[ -n "$NUM_CTX" ]] || { echo "Error: --num-ctx requires a value" >&2; exit 1; }
			shift 2
			;;
		--num-predict)
			NUM_PREDICT="${2:-}"
			[[ -n "$NUM_PREDICT" ]] || { echo "Error: --num-predict requires a value" >&2; exit 1; }
			shift 2
			;;
		-h|--help)
			print_usage
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			print_usage
			exit 1
			;;
	esac
done

if [[ ! -f "$PROMPT_FILE" ]]; then
	echo "Error: prompt file not found: $PROMPT_FILE" >&2
	exit 1
fi

if [[ -n "$ADAPTER_PATH" && ! -e "$ADAPTER_PATH" ]]; then
	echo "Error: adapter path not found: $ADAPTER_PATH" >&2
	exit 1
fi

if ! command -v ollama >/dev/null 2>&1; then
	echo "Error: ollama CLI is not installed." >&2
	exit 1
fi

if ! ollama list >/dev/null 2>&1; then
	echo "Error: Ollama daemon is not reachable. Start it with: ollama serve" >&2
	exit 1
fi

echo "Ensuring base model exists: $BASE_MODEL"
ollama pull "$BASE_MODEL" >/dev/null

SYSTEM_PROMPT_CONTENT="$(cat "$PROMPT_FILE")"
TMP_MODELFILE="$(mktemp)"
trap 'rm -f "$TMP_MODELFILE"' EXIT

cat >"$TMP_MODELFILE" <<EOF
FROM $BASE_MODEL
SYSTEM """$SYSTEM_PROMPT_CONTENT"""
PARAMETER temperature $TEMPERATURE
PARAMETER num_ctx $NUM_CTX
PARAMETER num_predict $NUM_PREDICT
EOF

if [[ -n "$ADAPTER_PATH" ]]; then
	echo "ADAPTER $ADAPTER_PATH" >>"$TMP_MODELFILE"
fi

echo "Building model '$MODEL_NAME' ..."
ollama create "$MODEL_NAME" -f "$TMP_MODELFILE"

echo
echo "Custom model ready: $MODEL_NAME"
echo "Run review with:"
echo "  scripts/ollama-review.sh --unstaged --model $MODEL_NAME"
echo "Or with custom-model alias:"
echo "  OLLAMA_CUSTOM_MODEL_NAME=$MODEL_NAME scripts/ollama-review.sh --unstaged --custom-model"
