#!/usr/bin/env bash
set -euo pipefail

if (( $# > 0 )); then
  printf 'Usage: ./scripts/smoke_test.sh\n' >&2
  printf 'Set benchmark variables before ./scripts/run_swebench.sh, for example:\n' >&2
  printf "  INSTANCE_FILTER='^django__django-11099$' ./scripts/run_swebench.sh\n" >&2
  exit 2
fi

model="${MODEL_ID:-ricdomolm/mini-coder-1.7b}"
timeout_seconds="${SMOKE_TIMEOUT_SECONDS:-300}"
deadline=$((SECONDS + timeout_seconds))

printf 'Waiting for vLLM to finish loading (up to %ss)...\n' "$timeout_seconds"
until curl --fail --silent --show-error --max-time 5 http://localhost:8000/health >/dev/null; do
  if (( SECONDS >= deadline )); then
    printf 'vLLM did not become ready within %ss. Inspect with:\n' "$timeout_seconds" >&2
    printf '  docker compose logs --tail=200 vllm\n' >&2
    exit 1
  fi
  sleep 5
done

curl --fail --silent --show-error http://localhost:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  --data "$(cat <<JSON
{
  "model": "$model",
  "messages": [{"role": "user", "content": "Reply with exactly: minicoder-ok"}],
  "temperature": 0,
  "max_tokens": 16
}
JSON
)"
printf '\nMiniCoder vLLM smoke test passed.\n'
