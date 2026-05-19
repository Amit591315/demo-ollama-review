#!/usr/bin/env bash
set -euo pipefail

MODEL="${OLLAMA_REVIEW_MODEL:-llama3.2:3b}"
DIFF_MODE="unstaged"
BASE_REF=""
PROMPT_FILE=""
BUILD_MODEL=""
USE_CUSTOM_MODEL=""
CUSTOM_MODEL_NAME="${OLLAMA_CUSTOM_MODEL_NAME:-cpp-raii-reviewer}"
MODELFILE="${OLLAMA_MODELFILE:-prompts/Modelfile}"

print_usage() {
	cat <<'EOF'
Usage: scripts/ollama-review.sh [options]

Options:
	--staged            Review staged changes (git diff --cached)
	--unstaged          Review unstaged changes (default)
	--base <ref>        Review changes from <ref> to HEAD (git diff <ref>...HEAD)
	--model <name>      Ollama model name (default: $OLLAMA_REVIEW_MODEL or llama3.2:3b)
	--prompt-file <p>   Load review instructions from prompt file
	--build-model       Build the custom Ollama model from prompts/Modelfile and exit
	--custom-model      Use the pre-built custom model ($CUSTOM_MODEL_NAME)
	--custom-model-name Override custom model name used by --custom-model/--build-model
	--modelfile <path>  Use a different Modelfile when building custom model
	-h, --help          Show this help

Examples:
	scripts/ollama-review.sh --unstaged
	scripts/ollama-review.sh --staged --model llama2:latest
	scripts/ollama-review.sh --base main --model llama3.2:3b
	scripts/ollama-review.sh --unstaged --prompt-file prompts/cpp-raii-analysis-prompt.txt
	scripts/ollama-review.sh --build-model
	scripts/ollama-review.sh --unstaged --custom-model
	scripts/ollama-review.sh --build-model --custom-model-name my-reviewer --modelfile prompts/Modelfile
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--staged)
			DIFF_MODE="staged"
			shift
			;;
		--unstaged)
			DIFF_MODE="unstaged"
			shift
			;;
		--base)
			BASE_REF="${2:-}"
			if [[ -z "$BASE_REF" ]]; then
				echo "Error: --base requires a ref value" >&2
				exit 1
			fi
			shift 2
			;;
		--model)
			MODEL="${2:-}"
			if [[ -z "$MODEL" ]]; then
				echo "Error: --model requires a value" >&2
				exit 1
			fi
			shift 2
			;;
		--prompt-file)
			PROMPT_FILE="${2:-}"
			if [[ -z "$PROMPT_FILE" ]]; then
				echo "Error: --prompt-file requires a file path" >&2
				exit 1
			fi
			if [[ ! -f "$PROMPT_FILE" ]]; then
				echo "Error: prompt file not found: $PROMPT_FILE" >&2
				exit 1
			fi
			shift 2
			;;
		--build-model)
			BUILD_MODEL="yes"
			shift
			;;
		--custom-model)
			USE_CUSTOM_MODEL="yes"
			shift
			;;
		--custom-model-name)
			CUSTOM_MODEL_NAME="${2:-}"
			if [[ -z "$CUSTOM_MODEL_NAME" ]]; then
				echo "Error: --custom-model-name requires a value" >&2
				exit 1
			fi
			shift 2
			;;
		--modelfile)
			MODELFILE="${2:-}"
			if [[ -z "$MODELFILE" ]]; then
				echo "Error: --modelfile requires a file path" >&2
				exit 1
			fi
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

if [[ "$USE_CUSTOM_MODEL" == "yes" ]]; then
	MODEL="$CUSTOM_MODEL_NAME"
fi

if [[ "$BUILD_MODEL" == "yes" ]]; then
	if [[ ! -f "$MODELFILE" ]]; then
		echo "Error: Modelfile not found: $MODELFILE" >&2
		exit 1
	fi
	echo "Building custom model '$CUSTOM_MODEL_NAME' from $MODELFILE ..."
	ollama create "$CUSTOM_MODEL_NAME" -f "$MODELFILE"
	echo "Done. Run with: scripts/ollama-review.sh --unstaged --custom-model"
	exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo "Error: current directory is not a git repository." >&2
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

if [[ -n "$BASE_REF" ]]; then
	DIFF_CONTENT="$(git diff "$BASE_REF"...HEAD)"
	REVIEW_SCOPE="branch changes: $BASE_REF...HEAD"
elif [[ "$DIFF_MODE" == "staged" ]]; then
	DIFF_CONTENT="$(git diff --cached)"
	REVIEW_SCOPE="staged changes"
else
	DIFF_CONTENT="$(git diff)"
	while IFS= read -r untracked_file; do
		[[ -z "$untracked_file" ]] && continue
		DIFF_CONTENT+=$'\n'
		DIFF_CONTENT+="$(git diff --no-index -- /dev/null "$untracked_file" || true)"
	done < <(git ls-files --others --exclude-standard)
	REVIEW_SCOPE="unstaged changes"
fi

if [[ -z "$DIFF_CONTENT" ]]; then
	echo "No $REVIEW_SCOPE found. Nothing to review."
	exit 0
fi

# Keep prompt size manageable for local models.
MAX_CHARS=50000
if [[ ${#DIFF_CONTENT} -gt $MAX_CHARS ]]; then
	DIFF_CONTENT="${DIFF_CONTENT:0:$MAX_CHARS}

[TRUNCATED: diff was longer than $MAX_CHARS characters]"
fi

if [[ -n "$PROMPT_FILE" ]]; then
	BASE_PROMPT="$(cat "$PROMPT_FILE")"
else
	BASE_PROMPT="You are a strict senior reviewer. Review the git diff below.

Rules:
- Focus on real defects, regressions, security risks, and missing tests.
- Prioritize findings by severity: critical, high, medium, low.
- For each finding include: file path, why it is an issue, and a concrete fix.
- If no findings, explicitly say 'No significant findings'.
- Keep summary brief."
fi

PROMPT="$BASE_PROMPT

Review scope: $REVIEW_SCOPE

Git diff:
$DIFF_CONTENT"

echo "Running review with model: $MODEL"
printf "%s" "$PROMPT" | ollama run "$MODEL"
