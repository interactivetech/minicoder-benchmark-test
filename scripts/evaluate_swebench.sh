#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${OUTPUT_DIR:-${repo_root}/results/minicoder-1.7b}"
predictions_path="${PREDICTIONS_PATH:-${output_dir}/preds.json}"
dataset_name="${DATASET_NAME:-SWE-bench/SWE-bench_Verified}"
split="${SPLIT:-test}"
workers="${EVAL_WORKERS:-1}"
run_id="${RUN_ID:-minicoder-1.7b-$(date -u +%Y%m%d-%H%M%S)}"
report_dir="${REPORT_DIR:-${repo_root}/results/evaluation/${run_id}}"

if [[ ! -f "$predictions_path" ]]; then
  printf 'Prediction file not found: %s\nRun scripts/run_swebench.sh first.\n' "$predictions_path" >&2
  exit 1
fi
if ! python -c 'import swebench' >/dev/null 2>&1; then
  printf 'SWE-bench evaluator is not installed. Run: python -m pip install -e ".[evaluation]"\n' >&2
  exit 1
fi

mkdir -p "$report_dir"
args=(
  -m swebench.harness.run_evaluation
  --dataset_name "$dataset_name"
  --split "$split"
  --predictions_path "$predictions_path"
  --max_workers "$workers"
  --run_id "$run_id"
  --report_dir "$report_dir"
)

if [[ -n "${INSTANCE_IDS:-}" ]]; then
  read -r -a instance_ids <<< "$INSTANCE_IDS"
  args+=(--instance_ids "${instance_ids[@]}")
fi

python "${args[@]}"

python - "$report_dir" <<'PY'
import json
import sys
from pathlib import Path

report_dir = Path(sys.argv[1])
reports = sorted(report_dir.glob("*.json"))
if not reports:
    raise SystemExit(f"No evaluator report found in {report_dir}")

report = json.loads(reports[-1].read_text())
total = report["completed_instances"]
resolved = report["resolved_instances"]
score = 100.0 * resolved / total if total else 0.0
print(f"SWE-bench score: {resolved}/{total} = {score:.2f}%")
print(f"Report: {reports[-1]}")
PY

