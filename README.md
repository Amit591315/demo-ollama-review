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
- `--custom-model` use pre-built custom model name (`cpp-raii-reviewer` by default)
- `--custom-model-name <name>` override custom model alias for this run
- `--modelfile <path>` use another Modelfile with `--build-model`

Examples:

```bash
scripts/ollama-review.sh --unstaged
scripts/ollama-review.sh --staged --model llama2:latest
scripts/ollama-review.sh --base main --model llama3.2:3b
scripts/ollama-review.sh --unstaged --prompt-file prompts/cpp-raii-analysis-prompt.txt
scripts/ollama-review.sh --build-model --custom-model-name cpp-raii-reviewer
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

You can override the model name and Modelfile path:

```bash
scripts/ollama-review.sh --build-model --custom-model-name my-reviewer --modelfile prompts/Modelfile
```

**Use the custom model for reviews:**

```bash
scripts/ollama-review.sh --unstaged --custom-model
scripts/ollama-review.sh --staged --custom-model
scripts/ollama-review.sh --base main --custom-model

# use a custom alias
OLLAMA_CUSTOM_MODEL_NAME=my-reviewer scripts/ollama-review.sh --unstaged --custom-model
```

The `Modelfile` (`prompts/Modelfile`) sets:
- Base model: `llama3.2:3b` (change the `FROM` line to switch)
- Temperature: `0.2` for consistent, deterministic output
- Context window: `8192` tokens

## Local Setup Commands

```bash
git init
chmod +x scripts/ollama-review.sh
chmod +x scripts/ollama-finetune.sh
ollama serve
ollama list
```

## Docker Setup

Build and run the entire review stack in a Docker container:

```bash
# Build the Docker image
docker build -t cpp-raii-reviewer .

# Run code review on unstaged changes
docker run --rm -v $(pwd):/workspace cpp-raii-reviewer --unstaged

# Run code review on a specific base ref
docker run --rm -v $(pwd):/workspace cpp-raii-reviewer --base main
```

The Docker container:
- Starts Ollama daemon automatically
- Builds the custom `cpp-raii-reviewer` model from `prompts/Modelfile`
- Uses the RAII review model by default
- Falls back gracefully if model build fails

## GitHub Actions CI

The repository includes an automated GitHub Actions workflow (`.github/workflows/cpp-review.yml`) that:

1. **Triggers on**: PRs and pushes that modify `.cpp` or `.h` files
2. **Builds** the Docker image with layer caching
3. **Creates** the custom Llama model with embedded RAII review prompt
4. **Runs** code review on changed files
5. **Uploads** review output as artifact

### Trigger Manually

Go to **Actions** → **C++ RAII Code Review (Docker)** → **Run workflow**

### View Results

After the workflow completes:
1. Click the workflow run
2. Scroll to **Artifacts** → Download `code-review-*.txt`
3. Or view logs in the **"Run code review in Docker"** step

## The `cpp-raii-reviewer` Custom Llama Model

This repository includes an instruction-tuned Ollama model configuration (`prompts/Modelfile`) that:

- **Base Model**: `llama3.2:3b`
- **System Prompt**: Specialized C++ RAII code review instructions
- **Temperature**: `0.2` (consistent, focused output)
- **Context**: 8192 tokens
- **Max Output**: 2048 tokens

The model emphasizes:
- Functional correctness and memory safety
- RAII (Resource Acquisition Is Initialization) principles
- Exception safety
- Smart pointers vs raw pointers
- Proper resource acquisition/release symmetry

## Fine-Tune Workflow With Ollama

If you want a stronger specialized reviewer, use the helper script:

```bash
scripts/ollama-finetune.sh --model-name cpp-raii-reviewer-ft
```

This script:
- Pulls your base model
- Bakes your review instructions into a generated Modelfile
- Optionally adds an adapter (`--adapter <path>`) for LoRA/QLoRA style tuning
- Creates a reusable model in Ollama

Examples:

```bash
# Build from a different base model
scripts/ollama-finetune.sh --base-model llama3.1:8b --model-name cpp-raii-reviewer-8b

# Build with a custom prompt and adapter
scripts/ollama-finetune.sh \
	--prompt-file prompts/cpp-raii-analysis-prompt.txt \
	--adapter ./adapters/raii-lora \
	--model-name cpp-raii-reviewer-lora

# Run review with the tuned model
scripts/ollama-review.sh --unstaged --model cpp-raii-reviewer-ft
```

Note: Ollama itself packages and serves models. Full training is done externally (for example with LoRA/QLoRA tooling), then imported via `ADAPTER`.

### Build Locally

```bash
ollama create cpp-raii-reviewer -f prompts/Modelfile
```

### Use Locally

```bash
ollama run cpp-raii-reviewer < code.cpp
```

### In Docker (Automatic)

The `docker-entrypoint.sh` script automatically:
1. Pulls the base model (`llama3.2:3b`)
2. Builds the custom `cpp-raii-reviewer` model
3. Uses it for all reviews

## Notes

- The script truncates very large diffs to keep local model inference stable.
- If there are no changes in selected scope, the script exits cleanly.
- First Docker run takes ~10 min (pulls/builds model). Subsequent runs are much faster.
- On GitHub Actions, builds are cached to speed up subsequent runs.
