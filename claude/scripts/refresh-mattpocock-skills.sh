#!/usr/bin/env bash
# Refresh the selectively-installed mattpocock skills from upstream.
#
#   refresh-mattpocock-skills.sh            # pull + report what changed
#   refresh-mattpocock-skills.sh --apply    # copy in skills you have NOT edited
#   refresh-mattpocock-skills.sh --force    # overwrite everything, incl. your edits
#
# The skill selection lives in harness-manifest.sh, not here.
set -euo pipefail

MANIFEST="${HARNESS_MANIFEST:-$HOME/.claude/scripts/harness-manifest.sh}"
[ -f "$MANIFEST" ] || { echo "missing manifest: $MANIFEST" >&2; exit 66; }
# shellcheck source=/dev/null
. "$MANIFEST"

VENDOR="$HOME/.claude/vendor/mattpocock-skills"
DEST="$HOME/.claude/skills"
MODE="${1:-report}"

[ -d "$VENDOR/.git" ] || { echo "no vendor clone at $VENDOR — run install.sh" >&2; exit 66; }

echo "pulling upstream..."
git -C "$VENDOR" pull --quiet --ff-only
echo "upstream now at $(git -C "$VENDOR" rev-parse --short HEAD)"
echo

group_for() {
  case " $HARNESS_MATT_ENGINEERING " in *" $1 "*) echo engineering; return;; esac
  case " $HARNESS_MATT_PRODUCTIVITY " in *" $1 "*) echo productivity; return;; esac
  case " $HARNESS_MATT_INPROGRESS "  in *" $1 "*) echo in-progress; return;; esac
}

clean=0; changed=0; updated=0; skipped=0
for s in $HARNESS_MATT_ENGINEERING $HARNESS_MATT_PRODUCTIVITY $HARNESS_MATT_INPROGRESS; do
  src="$VENDOR/skills/$(group_for "$s")/$s"; dst="$DEST/$s"
  [ -d "$src" ] || { echo "  GONE    $s (removed upstream)"; continue; }
  if [ ! -d "$dst" ]; then
    echo "  NEW     $s"
    case "$MODE" in --apply|--force) cp -r "$src" "$DEST/"; updated=$((updated+1));; esac
    continue
  fi
  if diff -rq "$src" "$dst" >/dev/null 2>&1; then
    clean=$((clean+1))
  else
    echo "  CHANGED $s"; changed=$((changed+1))
    case "$MODE" in
      --force) cp -r "$src" "$DEST/"; updated=$((updated+1)) ;;
      --apply) echo "          -> differs from upstream; --force to overwrite"; skipped=$((skipped+1)) ;;
      *)       skipped=$((skipped+1)) ;;
    esac
  fi
done

echo
echo "in sync: $clean   changed: $changed   updated: $updated   skipped: $skipped"
[ "$MODE" = "report" ] && echo "(report only — rerun with --apply or --force to write)"
exit 0
