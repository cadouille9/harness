#!/usr/bin/env bash
# SessionStart hook: inject the using-superpowers skill as session context.
#
# Replaces the superpowers plugin's own hook, which went away when the plugin was
# disabled in favour of a selective copy under ~/.claude/skills/. Same payload,
# read from the local (edited) copy so it names the skills that actually exist.
set -euo pipefail

SKILL="$HOME/.claude/skills/using-superpowers/SKILL.md"
[ -f "$SKILL" ] || exit 0

exec python3 - "$SKILL" <<'PY'
import json, sys

body = open(sys.argv[1], encoding="utf-8").read()
ctx = (
    "<EXTREMELY_IMPORTANT>\n"
    "You have superpowers.\n\n"
    "**Below is the full content of your 'using-superpowers' skill - your "
    "introduction to using skills. For all other skills, use the 'Skill' tool:**\n\n"
    f"{body}\n"
    "</EXTREMELY_IMPORTANT>"
)
json.dump(
    {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ctx}},
    sys.stdout,
)
PY
