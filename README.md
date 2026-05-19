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
- `--prompt-file <path>` load custom review instructions from a file

Examples:

```bash
scripts/ollama-review.sh --unstaged
scripts/ollama-review.sh --staged --model llama2:latest
scripts/ollama-review.sh --base main --model llama3.2:3b
scripts/ollama-review.sh --unstaged --prompt-file prompts/cpp-raii-analysis-prompt.txt
```

## C++ RAII Prompt

A dedicated C++ prompt is available at:

- `prompts/cpp-raii-analysis-prompt.txt`

Use it like this:

```bash
scripts/ollama-review.sh --unstaged --prompt-file prompts/cpp-raii-analysis-prompt.txt --model llama3.2:3b
```

## Custom Ollama Model (Prompt Baked In)

Instead of passing `--prompt-file` every time, you can build a custom Ollama model
that has the RAII review instructions embedded as a system prompt.

**Build the custom model once:**

```bash
scripts/ollama-review.sh --build-model
```

This reads `prompts/Modelfile` and creates a model named `cpp-raii-reviewer`.

**Use the custom model for reviews:**

```bash
scripts/ollama-review.sh --unstaged --custom-model
scripts/ollama-review.sh --staged --custom-model
scripts/ollama-review.sh --base main --custom-model
```

The `Modelfile` (`prompts/Modelfile`) sets:
- Base model: `llama3.2:3b` (change the `FROM` line to switch)
- Temperature: `0.2` for consistent, deterministic output
- Context window: `8192` tokens

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
