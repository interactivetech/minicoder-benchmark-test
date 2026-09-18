# Manual pass@N SWE-bench runs

This guide runs N independent MiniCoder attempts for every SWE-bench instance,
evaluates every generated patch, and reports empirical pass@N.

An instance counts as solved when at least one of its N attempts is resolved by
the SWE-bench evaluator. This is different from `WORKERS=N`: workers run
different benchmark instances concurrently; they do not create N attempts for
one instance.

## Before starting

Complete the setup in [MANUAL_SWEBENCH.md](MANUAL_SWEBENCH.md), start vLLM,
and verify the API:

```bash
source .venv/bin/activate
docker compose up -d vllm
./scripts/smoke_test.sh
```

The normal configuration uses `temperature: 0.0` and is deterministic. Pass@N
uses the stochastic configuration:

```text
configs/minicoder-model-sampling.yaml
```

Each attempt must have a separate output directory. Otherwise later attempts
would overwrite earlier predictions.

## Recommended one-instance test

Run five attempts for one task before launching the full benchmark:

```bash
ATTEMPTS=5
INSTANCE_FILTER='^django__django-11099$'

for n in $(seq 1 "$ATTEMPTS"); do
  printf -v sample '%02d' "$n"
  OUTPUT_DIR="results/pass${ATTEMPTS}-smoke/sample-${sample}" \
  MODEL_CONFIG="configs/minicoder-model-sampling.yaml" \
  WORKERS=1 \
  INSTANCE_FILTER="$INSTANCE_FILTER" \
  ./scripts/run_swebench.sh

  OUTPUT_DIR="results/pass${ATTEMPTS}-smoke/sample-${sample}" \
  PREDICTIONS_PATH="results/pass${ATTEMPTS}-smoke/sample-${sample}/preds.json" \
  REPORT_DIR="results/evaluation/pass${ATTEMPTS}-smoke/sample-${sample}" \
  RUN_ID="minicoder-1.7b-pass${ATTEMPTS}-smoke-${sample}" \
  INSTANCE_IDS='django__django-11099' \
  ./scripts/evaluate_swebench.sh
done
```

Aggregate the smoke-test reports:

```bash
python scripts/aggregate_passk.py \
  results/evaluation/pass5-smoke/sample-01/*.json \
  results/evaluation/pass5-smoke/sample-02/*.json \
  results/evaluation/pass5-smoke/sample-03/*.json \
  results/evaluation/pass5-smoke/sample-04/*.json \
  results/evaluation/pass5-smoke/sample-05/*.json
```

## Full pass@N run

Set `ATTEMPTS=5` for pass@5 or `ATTEMPTS=10` for pass@10. The following
example runs pass@5 over all 500 SWE-bench Verified test instances:

```bash
ATTEMPTS=5
AGENT_WORKERS=4
EVAL_WORKERS=4

for n in $(seq 1 "$ATTEMPTS"); do
  printf -v sample '%02d' "$n"
  OUTPUT_DIR="results/pass${ATTEMPTS}/sample-${sample}" \
  MODEL_CONFIG="configs/minicoder-model-sampling.yaml" \
  WORKERS="$AGENT_WORKERS" \
  ./scripts/run_swebench.sh
done

for n in $(seq 1 "$ATTEMPTS"); do
  printf -v sample '%02d' "$n"
  OUTPUT_DIR="results/pass${ATTEMPTS}/sample-${sample}" \
  PREDICTIONS_PATH="results/pass${ATTEMPTS}/sample-${sample}/preds.json" \
  REPORT_DIR="results/evaluation/pass${ATTEMPTS}/sample-${sample}" \
  RUN_ID="minicoder-1.7b-pass${ATTEMPTS}-${sample}" \
  EVAL_WORKERS="$EVAL_WORKERS" \
  ./scripts/evaluate_swebench.sh
done
```

Aggregate all N reports:

```bash
report_args=()
for n in $(seq 1 "$ATTEMPTS"); do
  printf -v sample '%02d' "$n"
  report_args+=("results/evaluation/pass${ATTEMPTS}/sample-${sample}"/*.json)
done

python scripts/aggregate_passk.py "${report_args[@]}"
```

The result will look like:

```text
Empirical pass@5: 120/500 = 24.00%
```

For pass@10, set `ATTEMPTS=10`. The run requires approximately ten times the
inference and evaluation work of pass@1.

## Resuming an interrupted attempt

Rerun the same inference loop without `REDO_EXISTING=1`. Existing predictions
in that sample directory are skipped and unfinished instances continue.

To regenerate every prediction for a sample, add:

```bash
REDO_EXISTING=1
```

to that sample's `run_swebench.sh` command. Use a new `RUN_ID` whenever the
predictions change.

## Interpreting the score

`aggregate_passk.py` unions the `resolved_ids` from all N evaluator reports.
Thus each task is counted once even if multiple attempts solve it:

```text
number of unique tasks resolved by at least one attempt / total tasks
```

The reported value is empirical pass@N for exactly N attempts per task.
