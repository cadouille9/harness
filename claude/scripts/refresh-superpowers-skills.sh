#!/usr/bin/env bash
# Refresh the selectively-installed superpowers skills from upstream, reapplying
# the local rewrites each time.
#
#   refresh-superpowers-skills.sh           # pull + show what would change
#   refresh-superpowers-skills.sh --apply   # pull, copy, and rewrite
#
# The skill selection lives in harness-manifest.sh, not here.
#
# Two rewrites are applied on every pull, because upstream writes for a plugin
# and these skills no longer live in one:
#   1. Cross-references are written "superpowers:<skill>". Outside a plugin that
#      namespace is wrong, so it is stripped, and the dropped skills repointed:
#        brainstorming           -> grill-with-docs
#        test-driven-development -> tdd
#        systematic-debugging    -> diagnosing-bugs
#        requesting/receiving-code-review -> code-review
#   2. subagent-driven-development dispatches a code-reviewer.md prompt that
#      lived inside the dropped requesting-code-review. It is kept as a local
#      asset of subagent-driven-development/.
set -euo pipefail

MANIFEST="${HARNESS_MANIFEST:-$HOME/.claude/scripts/harness-manifest.sh}"
[ -f "$MANIFEST" ] || { echo "missing manifest: $MANIFEST" >&2; exit 66; }
# shellcheck source=/dev/null
. "$MANIFEST"

VENDOR="$HOME/.claude/vendor/superpowers"
DEST="$HOME/.claude/skills"
MODE="${1:-report}"
KEEP="$HARNESS_SP_SKILLS"

# Apply every local rewrite to a tree laid out like $DEST, so the report
# compares like with like.
rewrite_tree() {
  ( cd "$1"
    present=""
    for s in $KEEP; do [ -d "$s" ] && present="$present $s"; done
    [ -n "$present" ] || return 0

    find $present -name '*.md' -print0 | xargs -0 sed -i \
      -e 's/superpowers:brainstorming/grill-with-docs/g' \
      -e 's/superpowers:test-driven-development/tdd/g' \
      -e 's/superpowers:systematic-debugging/diagnosing-bugs/g' \
      -e 's/superpowers:requesting-code-review/code-review/g' \
      -e 's/superpowers:receiving-code-review/code-review/g' \
      -e 's|\.\./requesting-code-review/code-reviewer\.md|code-reviewer.md|g' \
      -e 's/superpowers://g'

    # code-reviewer.md is a local asset now, not part of the code-review skill.
    [ -f subagent-driven-development/SKILL.md ] && perl -0pi -e \
      "s/code-review's\s*\n\[code-reviewer\.md\]\(code-reviewer\.md\)\./the local\n[code-reviewer.md](code-reviewer.md) template./" \
      subagent-driven-development/SKILL.md

    # Prose that names the dropped skills rather than referencing them by namespace.
    [ -f using-superpowers/SKILL.md ] && sed -i \
      -e "s/if you haven't already brainstormed, invoke the brainstorming skill first\./if you haven't already stress-tested the idea, invoke the grill-with-docs skill first./" \
      -e "s/Brainstorming and systematic-debugging are Superpowers' most common process skills/grill-with-docs and diagnosing-bugs are the most common process skills here/" \
      using-superpowers/SKILL.md
    [ -f writing-plans/SKILL.md ] && sed -i \
      's/sub-project specs during brainstorming/sub-project specs during grilling/' writing-plans/SKILL.md
    [ -f using-superpowers/references/hermes-tools.md ] && sed -i \
      -e 's/skill_view("brainstorming")/skill_view("grill-with-docs")/' \
      -e 's/skill_view("test-driven-development")/skill_view("tdd")/' \
      using-superpowers/references/hermes-tools.md
    true )
}

[ -d "$VENDOR/.git" ] || { echo "no vendor clone at $VENDOR — run install.sh" >&2; exit 66; }

echo "pulling upstream..."
git -C "$VENDOR" pull --quiet --ff-only
echo "upstream now at $(git -C "$VENDOR" rev-parse --short HEAD)"
echo

STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT
for s in $KEEP; do
  [ -d "$VENDOR/skills/$s" ] && cp -r "$VENDOR/skills/$s" "$STAGE/"
done
[ -f "$VENDOR/skills/requesting-code-review/code-reviewer.md" ] \
  && cp "$VENDOR/skills/requesting-code-review/code-reviewer.md" "$STAGE/subagent-driven-development/"
rewrite_tree "$STAGE"

changed=0
for s in $KEEP; do
  if   [ ! -d "$STAGE/$s" ]; then echo "  GONE    $s (removed upstream — left in place)"; continue
  elif [ ! -d "$DEST/$s"  ]; then echo "  NEW     $s"; changed=$((changed+1))
  elif diff -rq "$STAGE/$s" "$DEST/$s" >/dev/null 2>&1; then echo "  insync  $s"
  else echo "  CHANGED $s"; changed=$((changed+1)); fi
done

echo
if [ "$MODE" != "--apply" ]; then
  echo "$changed skill(s) would change — rerun with --apply to write."
  exit 0
fi

for s in $KEEP; do
  [ -d "$STAGE/$s" ] || continue
  rm -rf "${DEST:?}/$s"; cp -r "$STAGE/$s" "$DEST/"
done
echo "applied. remaining 'superpowers:' refs:"
( cd "$DEST" && grep -rn 'superpowers:' $KEEP || echo "  none" )

# Pi has no SessionStart hook: its copy of using-superpowers lives in
# ~/.pi/agent/AGENTS.md and has to be regenerated whenever this one changes.
SYNC="$(dirname "$0")/sync-pi-agents.sh"
if [ -x "$SYNC" ] && [ -d "$HOME/.pi/agent" ]; then "$SYNC"; fi
