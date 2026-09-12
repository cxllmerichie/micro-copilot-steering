.PHONY: install
install: path ?= $(HOME)/.config/micro/plug/copilot-steering
install: file ?= prompt.md
install:
	@mkdir -p $(path)
	@cat "$(CURDIR)/prompts/$(version).md" > "$(path)/$(file)"
	@echo "Default steering prompt was copied to \"$(path)/$(file)\"."


version ?= 1.0.0

backend ?= cuda
# backend ?= vulkan

gpu ?= nvidia
# gpu ?= intel

ifeq ($(backend), cuda)
	DOCKER_HW_OPTS := --gpus all
	flash_attn ?= auto
else ifeq ($(gpu), nvidia)
	DOCKER_HW_OPTS := --gpus all
	flash_attn ?= off
else
	DOCKER_HW_OPTS := --device /dev/dri:/dev/dri
	flash_attn ?= off
endif


.PHONY: steering
steering: name ?= steering
steering: models_dir ?= /data/models/
steering: grammar_dir ?= ./grammar
steering: model ?= default/llama-3.2-1b-instruct-q8_0.gguf
steering: port := 65433
# The total context window size (in tokens) to allocate for the model.
# - Lower = uses less VRAM, but limits the amount of code it can read at once.
# - Higher = allows it to read more surrounding code, but eats VRAM quickly.
# - Optimal: 2048 (balanced for FIM tasks).
steering: ctx_size := 2048
# Inter-Process Communication (IPC) namespace mode for the container.
# - private = isolated IPC with default 64 MiB /dev/shm (causes bus errors/crashes with GPU drivers).
# - host = shares host IPC namespace and full /dev/shm (enables zero-copy DMA and fast shared memory).
# - Optimal: host (prevents out-of-shared-memory errors).
ipc ?= host
# Maximum memory (in bytes, or -1 for unlimited) allowed to be locked into physical RAM.
# - default (64 KiB) = causes mlock and GPU pinned memory allocations to fail with ENOMEM.
# - -1 = allows pinning model weights in RAM and direct DMA transfers without disk swapping.
# - Optimal: -1 (unlimited).
ulimit_memlock ?= -1
# Maximum process call stack size in bytes.
# - default (8388608 / 8 MiB) = risks stack overflow (SIGSEGV) during deep graph evaluation or large contexts.
# - higher (67108864 / 64 MiB) = provides ample headroom for deep recursive parsing and worker threads.
# - Optimal: 67108864 (64 MiB).
ulimit_stack ?= 67108864
# The number of CPU threads to use.
# - Lower = saves CPU power.
# - Higher = faster CPU ops (until it exceeds physical cores and thrashes cache).
# - Optimal: Physical core count (e.g. 6).
steering: threads ?= 6
# The number of tokens processed in a single batch.
# - Lower = uses less VRAM.
# - Higher = better overall throughput but increases time-to-first-token.
# - Optimal: 512 (for balanced latency and throughput).
steering: batch_size ?= 512
# The micro-batch size used to split large batches for processing.
# - Lower = saves memory footprint.
# - Higher = faster processing if VRAM allows it.
# - Optimal: Matches batch_size (e.g. 512).
steering: ubatch_size ?= 256
# The memory margin (in MiB) to leave free on the GPU when fitting layers automatically.
# - Lower = fits more layers into VRAM.
# - Higher = safer from Out-Of-Memory crashes.
# - Optimal: 256 (safe margin).
steering: fit_target ?= 256
# The minimum context size to reserve memory for when fitting layers automatically.
# - Lower = allows fitting more layers on low VRAM GPUs.
# - Higher = prevents OOMs on massive prompts.
# - Optimal: Matches max(n_prompt + n_gen) (e.g. 2048).
steering: fit_ctx ?= 2048
# How the model file is loaded into memory.
# - mmap = fast startup, lazy OS loading.
# - mlock = forces model to stay pinned in RAM (avoids page faults).
# - Optimal: mmap (saves system RAM).
steering: load_mode ?= mmap
# The quantization format for the Key (K) cache.
# - f16 = perfect quality but high VRAM usage.
# - q8_0 / q4_0 = saves massive VRAM and boosts speed, but lower quality.
# - Optimal: q8_0 (best speed-to-quality ratio).
steering: cache_type ?= q8_0
# Whether to lazy-load specific tensors (like embeddings) on demand.
# - auto = saves memory for large tensors.
# - off = forces everything into memory immediately.
# - Optimal: auto (smart memory management).
steering: lazy_mode ?= auto
# The percentage of CPU polling (busy-waiting) to use when syncing with the GPU.
# - 100 = lowest latency/highest speed but 100% CPU usage.
# - 0 = CPU sleeps (saves power, adds micro-delays).
# - Optimal: 50 (balanced responsiveness and power draw).
steering: poll ?= 50
# The number of concurrent requests the server can process.
# - Lower = dedicates all resources to a single completion, fastest latency.
# - Higher = splits context across multiple requests (for multiple users).
# - Optimal: 1 (perfect for single-user editor autocomplete).
steering: parallel ?= 1
steering: is_verbose := true
steering: args :=
# https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
# https://github.com/ggml-org/llama.cpp/blob/master/docs/docker.md
steering:
	@docker run --rm -it \
		--name $(name) \
		$(DOCKER_HW_OPTS) \
		--ipc=$(ipc) \
		--ulimit memlock=$(ulimit_memlock) \
		--ulimit stack=$(ulimit_stack) \
		--publish $(port):$(port) \
		--volume $(models_dir):/models:ro \
		--volume $(grammar_dir):/grammar:ro \
		--entrypoint /app/llama-server \
		ghcr.io/ggml-org/llama.cpp:server-$(backend) \
		--model /models/$(model) \
		--grammar-file /grammar/$(version).gbnf \
		--cache-prompt \
		--no-webui \
		--host 0.0.0.0 \
		--port $(port) \
		--threads $(threads) \
		--batch-size $(batch_size) \
		--ubatch-size $(ubatch_size) \
		--ctx-size $(ctx_size) \
		--fit on \
		--fit-target $(fit_target) \
		--fit-ctx $(fit_ctx) \
		--flash-attn $(flash_attn) \
		--cache-type-k $(cache_type) \
		--cache-type-v $(cache_type) \
		--load-mode $(load_mode) \
		--lazy-mode $(lazy_mode) \
		--poll $(poll) \
		--parallel $(parallel) \
		--alias $(name),$(model) \
		$(if $(filter true,$(is_verbose)),--verbose) \
		$(args)
