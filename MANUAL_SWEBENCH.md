# Manual SWE-bench run

This guide runs MiniCoder-1.7B through mini-SWE-agent, generates SWE-bench patches, evaluates them in the official SWE-bench Docker environments, and reports a score.

## Requirements

- Linux
- NVIDIA GPU with NVIDIA Container Toolkit
- Docker and Docker Compose
- Python 3.10 or newer
- Approximately 4 GiB for the MiniCoder weights, plus GPU memory for the KV cache

## 1. Get the repository

```bash
git clone https://github.com/interactivetech/minicoder-benchmark-test.git
cd minicoder-benchmark-test
```

## 2. Create the Python environment

```bash
python3.10 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e '.[evaluation]'
```

This installs:

- `mini-swe-agent==2.4.6` for patch generation
- `swebench==5.0.2` for patch evaluation

## 3. Start MiniCoder with vLLM

```bash
cp .env.example .env
docker compose up -d vllm
```

The first startup downloads the model into the Docker volume `huggingface-cache`. It can take several minutes while vLLM loads weights and compiles CUDA graphs.

Check startup logs:

```bash
docker compose logs -f vllm
```

In another terminal, wait for readiness:

```bash
curl -i http://localhost:8000/health
```

Continue only when the response is `HTTP/1.1 200 OK`.

## 4. Run the API smoke test

```bash
./scripts/smoke_test.sh
```

This verifies that the vLLM API responds. It does not evaluate a coding task.

## 5. Generate a patch for one task

Run one known SWE-bench Verified instance first:

```bash
REDO_EXISTING=1 \
INSTANCE_FILTER='^django__django-11099$' \
./scripts/run_swebench.sh
```

The generated prediction file is:

```text
results/minicoder-1.7b/preds.json
```

The trajectory is saved under:

```text
results/minicoder-1.7b/django__django-11099/
```

`REDO_EXISTING=1` is useful when a previous attempt produced a failed trajectory. Without it, existing instances may be skipped.

## 6. Evaluate the generated patch

Use the official SWE-bench dataset namespace for evaluation:

```bash
INSTANCE_IDS='django__django-11099' \
RUN_ID=minicoder-1.7b-django-11099 \
./scripts/evaluate_swebench.sh
```

Expected output:

```text
SWE-bench score: 1/1 = 100.00%
```

Evaluation reports are written to:

```text
results/evaluation/<run-id>/
```

The inference dataset and evaluation dataset intentionally use different names:

- Inference: `princeton-nlp/SWE-Bench_Verified`
- Evaluation: `SWE-bench/SWE-bench_Verified`

The evaluation copy contains the Docker image and test metadata required by the official harness.

## 7. Run the full Verified benchmark

Generate predictions for all 500 Verified test instances:

```bash
REDO_EXISTING=1 ./scripts/run_swebench.sh
```

After inference finishes, evaluate every generated prediction:

```bash
EVAL_WORKERS=4 \
RUN_ID=minicoder-1.7b-verified \
./scripts/evaluate_swebench.sh
```

The final metric is:

```text
resolved instances / evaluated instances * 100
```

For example, `93/500` means an 18.60% resolved rate.

## Manual official evaluator command

The evaluation helper wraps this official command:

```bash
python -m swebench.harness.run_evaluation \
  --dataset_name SWE-bench/SWE-bench_Verified \
  --split test \
  --predictions_path results/minicoder-1.7b/preds.json \
  --max_workers 4 \
  --run_id minicoder-1.7b-verified
```

Use a new `--run_id` for every changed prediction. The evaluator caches results by run ID.

## Useful monitoring commands

```bash
docker compose ps
docker compose logs --tail=100 vllm
docker stats
find results/minicoder-1.7b -maxdepth 2 -type f | sort
```

## Common problems

### `curl: (56) Recv failure: Connection reset by peer`

vLLM is still loading or compiling. Wait for `/health` to return `200`.

### `ContextWindowExceededError`

Confirm that `configs/minicoder-model.yaml` and `configs/litellm_registry.json` use `max_tokens: 8192`. The model context window is 40,960 tokens, and the prompt must fit alongside the requested output.

### `RepeatedFormatError`

Confirm that inference is using the repository’s `configs/minicoder-model.yaml` and the text-based `swebench_backticks.yaml` configuration. MiniCoder emits `bash` code fences, which the repository configuration parses.

### `KeyError: 'image'` during evaluation

Use `SWE-bench/SWE-bench_Verified` for evaluation, not `princeton-nlp/SWE-bench_Verified`. The latter is suitable for inference but does not include the evaluator’s image metadata.

### Existing predictions are skipped

Use a fresh output directory or rerun inference with:

```bash
REDO_EXISTING=1 ./scripts/run_swebench.sh
```

