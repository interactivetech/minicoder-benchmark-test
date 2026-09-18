# MiniCoder benchmark test

Reproducible deployment of [`ricdomolm/mini-coder-1.7b`](https://huggingface.co/ricdomolm/mini-coder-1.7b) with [`mini-swe-agent`](https://github.com/SWE-agent/mini-swe-agent) for SWE-bench experiments.

The model card reports 18.6% pass@1 and 50.4% pass@100 on SWE-bench Verified Bash-only. Those numbers are a reference point, not a guarantee: results depend on the mini-SWE-agent version, SWE-bench revision, serving engine, decoding settings, environment, and retry policy.

## Layout

- `configs/minicoder-model.yaml` — model override layered on mini-SWE-agent's built-in SWE-bench prompt/config.
- `configs/litellm_registry.json` — LiteLLM model metadata required by the local vLLM setup.
- `docker-compose.yml` — GPU-backed vLLM deployment.
- `scripts/run_swebench.sh` — benchmark entry point.
- `scripts/smoke_test.sh` — checks the OpenAI-compatible server before a run.

## Prerequisites

- Linux with an NVIDIA GPU and a working Docker + NVIDIA Container Toolkit installation.
- Python 3.10+.
- Enough GPU memory for the BF16 checkpoint and the selected context length.
- Docker access to run the SWE-bench environments. The benchmark runner may also be run directly on the host if Docker is available there.

## Install the agent

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e '.[evaluation]'
```

This installs and pins `mini-swe-agent==2.4.6`. The vLLM server is intentionally deployed separately because its installation is GPU/platform-specific.

## Start MiniCoder

```bash
cp .env.example .env
docker compose up -d vllm
./scripts/smoke_test.sh
```

The first start downloads the model into the named `huggingface-cache` volume. `HF_TOKEN` is optional for this public model, but can be set in `.env` if Hugging Face rate limits or access rules require it.

## Run the benchmark

Start with one instance to validate the complete path:

```bash
INSTANCE_FILTER='^django__django-11099$' ./scripts/run_swebench.sh
```

Run the full Verified test split after the smoke run succeeds:

```bash
./scripts/run_swebench.sh
```

The inference command writes `preds.json`. Evaluate those generated patches with
the official SWE-bench harness:

```bash
./scripts/evaluate_swebench.sh
```

For the one-instance inference and score:

```bash
OUTPUT_DIR=results/minicoder-1.7b \
INSTANCE_IDS='django__django-11099' \
./scripts/evaluate_swebench.sh
```

The evaluator prints a score such as `SWE-bench score: 1/1 = 100.00%`. Use a
fresh `RUN_ID` for every changed prediction because evaluator results are
cached by run ID.

Useful environment variables:

- `SUBSET` (default: `verified`)
- `SPLIT` (default: `test`)
- `WORKERS` (default: `1`)
- `INSTANCE_FILTER` (optional regular expression)
- `INSTANCE_SLICE` (optional slice such as `0:10`)
- `REDO_EXISTING=1` (rerun instances with an existing trajectory)
- `OUTPUT_DIR` (default: `results/minicoder-1.7b`)

Results and trajectories are written below `results/`, which is ignored by Git because they can be large and may contain model outputs.

## Reproducibility notes

The default configuration uses deterministic temperature `0.0`, one worker, the model card's `hosted_vllm` provider name, and mini-SWE-agent's text-based backtick SWE-bench prompt. Record the following alongside every result:

```bash
python --version
python -c 'import minisweagent; print(minisweagent.__version__)'
docker compose images
docker compose logs --no-color vllm > results/vllm.log
```

The Docker image is configurable in `docker-compose.yml`; pin it to a tested vLLM tag or digest before publishing a final benchmark number.

## Sources

- Model card and serving example: <https://huggingface.co/ricdomolm/mini-coder-1.7b>
- mini-SWE-agent: <https://github.com/SWE-agent/mini-swe-agent>
- SWE-bench: <https://www.swebench.com/>
