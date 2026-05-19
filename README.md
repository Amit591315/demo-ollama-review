# Local Ollama Code Review

This repo is configured to run local AI code review using Ollama against your git diff.

## Prerequisites

- `ollama` installed locally
- Ollama daemon running (`ollama serve`)
- At least one local model (for example `llama3.2:3b`)

## Review Script

Use:

```bash
scripts/ollama-review.sh [options]
```

Options:

- `--unstaged` review local unstaged changes (default)
- `--staged` review staged changes
- `--base <ref>` review `git diff <ref>...HEAD`
- `--model <name>` choose a model (default `llama3.2:3b`, or set `OLLAMA_REVIEW_MODEL`)

Examples:

```bash
scripts/ollama-review.sh --unstaged
scripts/ollama-review.sh --staged --model llama2:latest
scripts/ollama-review.sh --base main --model llama3.2:3b
```

## Local Setup Commands

```bash
git init
chmod +x scripts/ollama-review.sh
ollama serve
ollama list
```

## Notes

- The script truncates very large diffs to keep local model inference stable.
- If there are no changes in selected scope, the script exits cleanly.
