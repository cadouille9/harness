#!/usr/bin/env bash
# Send a plan/spec/ticket-breakdown to Codex for an adversarial review.
# Read-only: no --write is passed, so codex-companion runs the sandbox as "read-only".
# Usage: plan-review.sh <prompt-file> [--effort LEVEL] [--background]
set -euo pipefail

PROMPT_FILE="${1:-}"
if [ -z "$PROMPT_FILE" ]; then
  echo "usage: plan-review.sh <prompt-file> [--effort LEVEL] [--background]" >&2
  exit 64
fi
shift

if [ ! -f "$PROMPT_FILE" ]; then
  echo "plan-review: no such prompt file: $PROMPT_FILE" >&2
  exit 66
fi

# Resolve the newest codex-companion.mjs from the installed codex plugin.
# Layout: ~/.claude/plugins/cache/openai-codex/codex/<version>/scripts/codex-companion.mjs
COMPANION="$(find "$HOME/.claude/plugins/cache/openai-codex/codex" \
    -mindepth 3 -maxdepth 3 -path '*/scripts/codex-companion.mjs' 2>/dev/null \
  | sort -V | tail -n 1)"

if [ -z "$COMPANION" ]; then
  echo "plan-review: codex plugin not found under ~/.claude/plugins/cache/openai-codex/." >&2
  echo "             install it with:  /plugin install codex@openai-codex" >&2
  exit 69
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "plan-review: the codex CLI is not on PATH. Run /codex:setup to check the install." >&2
  exit 69
fi

EFFORT=high
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --effort) EFFORT="${2:?--effort needs a value}"; shift 2 ;;
    --background) ARGS+=(--background); shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

exec node "$COMPANION" task --prompt-file "$PROMPT_FILE" --effort "$EFFORT" ${ARGS[@]+"${ARGS[@]}"}
