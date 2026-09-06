#!/usr/bin/env bash
# Install this harness on a machine. Safe to re-run: every step is idempotent,
# nothing is clobbered without a backup, and settings are merged rather than
# overwritten.
#
#   ./install.sh                 # everything
#   ./install.sh --skip-plugins  # skip the `claude plugin` steps
#   ./install.sh --skip-codex    # skip the ~/.agents + ~/.codex mirror
#   ./install.sh --skip-pi       # skip the ~/.pi/agent setup
#   ./install.sh --skip-pyright  # skip installing pyright
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
. "$REPO/manifest.sh"

CLAUDE_DIR="$HOME/.claude"
SKILLS="$CLAUDE_DIR/skills"
SCRIPTS="$CLAUDE_DIR/scripts"
VENDOR="$CLAUDE_DIR/vendor"
BACKUPS="$CLAUDE_DIR/backups"
AGENTS_SKILLS="$HOME/.agents/skills"
PI_DIR="$HOME/.pi/agent"
STAMP="$(date +%Y%m%d-%H%M%S)"

SKIP_PLUGINS=0; SKIP_CODEX=0; SKIP_PI=0; SKIP_PYRIGHT=0
for a in "$@"; do case "$a" in
  --skip-plugins) SKIP_PLUGINS=1 ;;
  --skip-codex)   SKIP_CODEX=1 ;;
  --skip-pi)      SKIP_PI=1 ;;
  --skip-pyright) SKIP_PYRIGHT=1 ;;
  -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
  *) echo "unknown flag: $a" >&2; exit 64 ;;
esac; done

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
ok()   { printf '   \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '   \033[33m!\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------- preflight
say "Preflight"
for c in git python3; do
  command -v "$c" >/dev/null || { echo "required but missing: $c" >&2; exit 69; }
done
ok "git, python3"
python3 -c 'import sys; sys.exit(sys.version_info < (3,11))' \
  || warn "python3 < 3.11 — the Codex config step needs tomllib; it will be skipped"
command -v node >/dev/null && ok "node" || warn "no node — /codex-plan-review needs it"
command -v claude >/dev/null || { warn "no claude CLI — forcing --skip-plugins"; SKIP_PLUGINS=1; }
command -v pi >/dev/null || { warn "no pi CLI — forcing --skip-pi"; SKIP_PI=1; }

mkdir -p "$SKILLS" "$SCRIPTS" "$VENDOR" "$BACKUPS"

# ------------------------------------------------------------------ scripts
say "Scripts"
install -m 0755 "$REPO/claude/scripts/"*.sh "$REPO/pi/scripts/"*.sh "$SCRIPTS/"
install -m 0644 "$REPO/manifest.sh" "$SCRIPTS/harness-manifest.sh"
install -m 0644 "$REPO/pi/AGENTS.fragment.md" "$SCRIPTS/pi-agents-header.md"
ok "installed $(ls "$REPO"/claude/scripts/*.sh "$REPO"/pi/scripts/*.sh | wc -l) scripts + harness-manifest.sh + pi-agents-header.md"

# ------------------------------------------------------------------ vendors
say "Vendored skill libraries"
clone_or_pull() {
  local url="$1" dir="$2"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" pull --quiet --ff-only && ok "$(basename "$dir") updated -> $(git -C "$dir" rev-parse --short HEAD)"
  else
    git clone --depth 1 --quiet "$url" "$dir" && ok "$(basename "$dir") cloned -> $(git -C "$dir" rev-parse --short HEAD)"
  fi
}
clone_or_pull "$HARNESS_VENDOR_MATT" "$VENDOR/mattpocock-skills"
clone_or_pull "$HARNESS_VENDOR_SP"   "$VENDOR/superpowers"

say "Skills"
# --force: on a fresh machine there is nothing to preserve, and on a re-run the
# rewrites are reproducible, so upstream always wins here. Use the refresh
# scripts directly when you want your local edits respected.
HARNESS_MANIFEST="$SCRIPTS/harness-manifest.sh" "$SCRIPTS/refresh-mattpocock-skills.sh"  --force >/dev/null
HARNESS_MANIFEST="$SCRIPTS/harness-manifest.sh" "$SCRIPTS/refresh-superpowers-skills.sh" --apply >/dev/null
ok "mattpocock: $(echo $HARNESS_MATT_ENGINEERING $HARNESS_MATT_PRODUCTIVITY $HARNESS_MATT_INPROGRESS | wc -w) skills"
ok "superpowers: $(echo $HARNESS_SP_SKILLS | wc -w) skills (rewrites applied)"

for s in $HARNESS_OWN_SKILLS; do
  rm -rf "${SKILLS:?}/$s"; cp -r "$REPO/skills/$s" "$SKILLS/"
  find "$SKILLS/$s" -name '*.sh' -exec chmod +x {} +
done
ok "own skills: $HARNESS_OWN_SKILLS"

# ----------------------------------------------------------------- settings
say "settings.json"
[ -f "$CLAUDE_DIR/settings.json" ] && cp "$CLAUDE_DIR/settings.json" "$BACKUPS/settings.json.pre-install.$STAMP"
MARKETPLACES="$HARNESS_MARKETPLACES" PLUGINS_ON="$HARNESS_PLUGINS_ON" PLUGINS_OFF="$HARNESS_PLUGINS_OFF" \
python3 - "$REPO/claude/settings.base.json" "$CLAUDE_DIR/settings.json" <<'PY'
import json, os, sys, pathlib

base_p, out_p = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
base = json.loads(base_p.read_text())
cur = json.loads(out_p.read_text()) if out_p.exists() else {}

def merge(dst, src):
    for k, v in src.items():
        if isinstance(v, dict) and isinstance(dst.get(k), dict):
            merge(dst[k], v)
        else:
            dst[k] = v
    return dst

merge(cur, base)

mk = cur.setdefault("extraKnownMarketplaces", {})
for pair in os.environ["MARKETPLACES"].split():
    name, repo = pair.split("=", 1)
    mk[name] = {"source": {"source": "github", "repo": repo}}

ep = cur.setdefault("enabledPlugins", {})
for p in os.environ["PLUGINS_ON"].split():  ep[p] = True
for p in os.environ["PLUGINS_OFF"].split(): ep[p] = False

out_p.write_text(json.dumps(cur, indent=2) + "\n")
on = sum(1 for v in ep.values() if v)
print(f"   \033[32m✓\033[0m merged — {on} plugins on, {len(ep)-on} off, {len(mk)} marketplaces")
PY

# ------------------------------------------------------------------ plugins
if [ "$SKIP_PLUGINS" -eq 0 ]; then
  say "Plugins"
  for pair in $HARNESS_MARKETPLACES; do
    name="${pair%%=*}"; repo="${pair#*=}"
    claude plugin marketplace add "$repo" >/dev/null 2>&1 && ok "marketplace $name" || ok "marketplace $name (already known)"
  done
  for p in $HARNESS_PLUGINS_ON; do
    claude plugin install "$p" >/dev/null 2>&1 && ok "installed $p" || warn "could not install $p (may already be present)"
  done
else
  say "Plugins"; warn "skipped"
fi

# -------------------------------------------------------------------- codex
if [ "$SKIP_CODEX" -eq 0 ]; then
  say "Codex mirror"
  mkdir -p "$AGENTS_SKILLS"
  # A stale superpowers/ symlink here shadows the vendored copies with an older
  # tree that still carries the dropped skills.
  [ -L "$AGENTS_SKILLS/superpowers" ] && { rm "$AGENTS_SKILLS/superpowers"; ok "removed stale superpowers symlink"; }

  n=0
  for s in $HARNESS_MATT_ENGINEERING $HARNESS_MATT_PRODUCTIVITY $HARNESS_MATT_INPROGRESS \
           $HARNESS_SP_SKILLS $HARNESS_OWN_SKILLS $HARNESS_CODEX_EXTRA; do
    case " $HARNESS_CODEX_EXCLUDE " in *" $s "*) continue ;; esac
    [ -d "$SKILLS/$s" ] || continue
    ln -sfn "$SKILLS/$s" "$AGENTS_SKILLS/$s"; n=$((n+1))
  done
  ok "linked $n skills into ~/.agents/skills (excluded: $HARNESS_CODEX_EXCLUDE)"

  CODEX_CFG="$HOME/.codex/config.toml"
  if [ -f "$CODEX_CFG" ] && python3 -c 'import tomllib' 2>/dev/null; then
    cp "$CODEX_CFG" "$BACKUPS/codex-config.toml.pre-install.$STAMP"
    python3 - "$CODEX_CFG" <<'PY'
import pathlib, sys, tomllib
p = pathlib.Path(sys.argv[1]); lines = p.read_text().splitlines()
if tomllib.loads(p.read_text()).get("features", {}).get("multi_agent") is True:
    print("   \033[32m✓\033[0m [features] multi_agent already true")
else:
    i = next((n for n, l in enumerate(lines) if l.strip().startswith("[")), len(lines))
    lines[i:i] = ["", "[features]", "multi_agent = true", ""]
    p.write_text("\n".join(lines) + "\n")
    tomllib.loads(p.read_text())  # fail loudly rather than leave broken TOML
    print("   \033[32m✓\033[0m added [features] multi_agent = true")
PY
  else
    warn "no ~/.codex/config.toml (or python3 < 3.11) — set [features] multi_agent = true yourself"
  fi
else
  say "Codex mirror"; warn "skipped"
fi

# ----------------------------------------------------------------------- pi
if [ "$SKIP_PI" -eq 0 ]; then
  say "Pi"
  mkdir -p "$PI_DIR/skills"

  # Pi reads ~/.agents/skills natively, so the Codex mirror is already Pi's
  # library. Only the extras land here, and only when the mirror does not carry
  # them: Pi reads both trees and a duplicate name warns and keeps the first.
  n=0
  for s in $HARNESS_PI_EXTRA; do
    [ -d "$SKILLS/$s" ] || continue
    if [ -e "$AGENTS_SKILLS/$s" ]; then
      warn "$s already in ~/.agents/skills — not linked (would collide)"; continue
    fi
    ln -sfn "$SKILLS/$s" "$PI_DIR/skills/$s"; n=$((n+1))
  done
  ok "linked $n extra skill(s) into ~/.pi/agent/skills: $HARNESS_PI_EXTRA"

  # Packages before settings: `pi install` writes its own entry into
  # settings.json, and the merge below is what reconciles the array.
  for pkg in $HARNESS_PI_PACKAGES; do
    # Match on the name alone: a pinned spec (npm:x@1.2.3) is listed with its
    # version, an unpinned one without, and both must count as installed.
    if pi list 2>/dev/null | grep -qF "${pkg%@[0-9]*}"; then ok "$pkg already installed"
    elif pi install "$pkg" >/dev/null 2>&1; then ok "installed $pkg"
    else warn "could not install $pkg — the subagent tool will be missing"; fi
  done

  # Only these keys are touched. Provider, model, thinking level and theme are
  # machine-local and left alone, same deal as codex/config.fragment.toml.
  [ -f "$PI_DIR/settings.json" ] && cp "$PI_DIR/settings.json" "$BACKUPS/pi-settings.json.pre-install.$STAMP"
  PI_DISABLE="$HARNESS_PI_DISABLE" \
  python3 - "$REPO/pi/settings.fragment.json" "$PI_DIR/settings.json" <<'PY'
import json, os, pathlib, sys

frag_p, out_p = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
cur = json.loads(out_p.read_text()) if out_p.exists() else {}
cur.update(json.loads(frag_p.read_text()))

# `!name` in the skills array disables an auto-discovered skill of that name.
# Entries you added yourself are kept; only ours are guaranteed present.
skills = list(cur.get("skills", []))
for s in os.environ["PI_DISABLE"].split():
    if f"!{s}" not in skills:
        skills.append(f"!{s}")
cur["skills"] = skills

out_p.parent.mkdir(parents=True, exist_ok=True)
out_p.write_text(json.dumps(cur, indent=2) + "\n")
off = [s[1:] for s in skills if s.startswith("!")]
print(f"   \033[32m✓\033[0m merged — skills disabled: {', '.join(off) or 'none'}")
PY

  HARNESS_PI_HEADER="$REPO/pi/AGENTS.fragment.md" "$SCRIPTS/sync-pi-agents.sh"
else
  say "Pi"; warn "skipped"
fi

# ------------------------------------------------------------------ pyright
if [ "$SKIP_PYRIGHT" -eq 0 ]; then
  say "pyright"
  if command -v pyright >/dev/null; then ok "already installed ($(pyright --version))"
  elif command -v uv >/dev/null; then uv tool install pyright >/dev/null 2>&1 && ok "installed via uv"
  elif command -v npm >/dev/null; then npm install -g pyright >/dev/null 2>&1 && ok "installed via npm"
  else warn "no uv or npm — pyright-lsp will be inert until you install pyright"; fi
fi

say "Done"
echo "   skills:  $(ls -d "$SKILLS"/*/ 2>/dev/null | wc -l) in ~/.claude/skills"
[ "$SKIP_CODEX" -eq 0 ] && echo "   codex:   $(ls "$AGENTS_SKILLS" 2>/dev/null | wc -l) in ~/.agents/skills"
[ "$SKIP_PI" -eq 0 ] && echo "   pi:      the same tree, plus $(ls "$PI_DIR/skills" 2>/dev/null | wc -l) in ~/.pi/agent/skills"
echo "   backups: $BACKUPS"
echo
echo "   Restart Claude Code to pick up plugins and the SessionStart hook."
echo "   Then run /setup-matt-pocock-skills once per repo."
