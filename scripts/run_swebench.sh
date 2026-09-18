#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
subset="${SUBSET:-verified}"
split="${SPLIT:-test}"
workers="${WORKERS:-1}"
output_dir="${OUTPUT_DIR:-${repo_root}/results/minicoder-1.7b}"

if ! command -v mini-extra >/dev/null 2>&1; then
  printf 'mini-extra is not installed. Run: python -m pip install -e .\n' >&2
  exit 1
fi

builtin_config="$(python -c 'from minisweagent.config import builtin_config_dir; print(builtin_config_dir / "benchmarks" / "swebench.yaml")' | tail -n 1)"
args=(
  swebench
  --config "$builtin_config"
  --config "${repo_root}/configs/minicoder-model.yaml"
  --subset "$subset"
  --split "$split"
  --workers "$workers"
  --output "$output_dir"
)

if [[ -n "${INSTANCE_FILTER:-}" ]]; then
  args+=(--filter "$INSTANCE_FILTER")
fi
if [[ -n "${INSTANCE_SLICE:-}" ]]; then
  args+=(--slice "$INSTANCE_SLICE")
fi

mkdir -p "$output_dir"
export LITELLM_MODEL_REGISTRY_PATH="${repo_root}/configs/litellm_registry.json"
exec mini-extra "${args[@]}"
