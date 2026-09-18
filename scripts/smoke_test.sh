#!/usr/bin/env bash
set -euo pipefail

model="${MODEL_ID:-ricdomolm/mini-coder-1.7b}"
curl --fail --silent --show-error http://localhost:8000/health >/dev/null
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

