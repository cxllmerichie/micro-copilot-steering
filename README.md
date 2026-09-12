# Micro Copilot Steering

This repository contains the steering harness and grammar for **Micro Copilot**, an AI-powered Fill-In-the-Middle (FIM) suggestion engine for the [micro](https://github.com/micro-editor/micro) editor.

The steering model acts as an intelligent intermediary. Before passing your code to the FIM model, the steering model analyzes the context (the prefix and suffix) and decides whether to insert a highly targeted semantic comment. This comment acts as a "hint" to guide the FIM model's generation, greatly improving the accuracy of autocomplete suggestions.

## Architecture

* **`prompts/`**: Contains the system prompts used to instruct the steering model. The current stable prompt is `prompts/1.0.0.md`.
* **`grammar/`**: Contains GBNF (GGML BNF) grammar files. These enforce the output schema of the steering model, ensuring it only outputs `[SKIP]`, `[PASS]`, or a valid comment, completely eliminating hallucinations and reasoning leakage.

## Requirements
- `make`
- `docker` (to run the local steering server container)

## Installation

Run the following command to install the steering prompt to your local micro config directory:
```bash
make install
```
This will automatically place `1.0.0.md` into `~/.config/micro/plug/copilot-steering/prompt.md` and print the exact `set` command you need to run inside `micro`.

## Configuration

In `micro`, press `Ctrl-E` and configure the plugin using the options below:

| Setting | Default | Description |
|---|---|---|
| `copilot.steering.prompt_filepath` | `""` | Path to the steering system prompt (e.g. `~/.config/micro/plug/copilot-steering/prompt.md`). If empty, steering is completely disabled. |
| `copilot.steering.url` | `http://127.0.0.1:65433/v1/chat/completions` | The API URL of your local steering LLM server. |
| `copilot.steering.model` | `llama-3.2-1b-instruct-q8_0.gguf` | The model name passed to the API. |
| `copilot.steering.log_filepath` | `~/.config/micro/plug/copilot-steering/events.log` | Optional. Path to a file where steering decisions will be logged as pretty JSON for debugging. |

## Usage

You must run a local LLM server to serve as the steering model, and you **must** attach the grammar file to restrict its output. This repository provides a `Makefile` to handle this via Docker.

Run the steering model server (defaults to port 65433 with the provided grammar):
```bash
make steering
```
*You can customize the model and port using `make steering model=... port=...` if needed.*
