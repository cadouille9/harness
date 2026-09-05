# harness

My Claude Code + Codex setup, as an installer. `./install.sh` on a new machine
reproduces it; re-running is safe.

```bash
git clone https://github.com/cadouille9/harness ~/dev/harness
~/dev/harness/install.sh
```

Then restart Claude Code, and run `/setup-matt-pocock-skills` once per repo.

## What it sets up

Two skill libraries, **copied out of their plugins** into `~/.claude/skills/`,
with the overlaps between them resolved:

- **[mattpocock/skills](https://github.com/mattpocock/skills)** — 19 skills. The
  requirements chain: `grill-with-docs` → `to-spec` → `to-tickets`, which
  publishes tracer-bullet tickets to GitHub Issues with real blocking edges.
- **[obra/superpowers](https://github.com/obra/superpowers)** — 9 skills, kept
  only for what it uniquely does: subagent-driven execution, parallel dispatch,
  verification-before-completion, worktrees.
- **`codex-plan-review`** — written here. Sends a plan to Codex for an
  adversarial review *before* any code exists.

Plus 15 plugins, a SessionStart hook, and a Codex mirror at `~/.agents/skills/`.

## Why skills are copied, not installed as plugins

`enabledPlugins` in `settings.json` toggles at **plugin granularity only** —
there is no way to disable one skill inside a plugin. Keeping both plugins meant
two contradictory TDD, debugging, review and ideation doctrines auto-triggering
at once, with the model picking a side at random. Copying also keeps the files
editable, which the tracker swap below needs.

### Resolved overlaps

mattpocock won every slot, because its skills share a **seams** vocabulary that
threads `to-spec` → `to-tickets` → `tdd` → `code-review` into one system.
Superpowers' versions are more forceful in isolation but do not connect to the
ticket chain.

| slot      | kept                     | dropped                                  |
|-----------|--------------------------|------------------------------------------|
| ideation  | `grill-with-docs`        | `brainstorming`                          |
| TDD       | `tdd`                    | `test-driven-development`                |
| debugging | `diagnosing-bugs`        | `systematic-debugging`                   |
| review    | `code-review`            | `requesting-` + `receiving-code-review`  |

`skill-creator` and `writing-skills` also overlap, but are kept together on
purpose: they are not contradictory, they are layers. `writing-skills` is the
method (TDD for documentation); `skill-creator` is the tooling that runs the
evals.

### Two rewrites the copies depend on

Reproduced by `refresh-superpowers-skills.sh` on every pull, so never hand-edit
without updating it:

1. Upstream writes cross-references as `superpowers:<skill>`. Outside a plugin
   that namespace is wrong: it is stripped, and dropped names repointed per the
   table above.
2. `subagent-driven-development` dispatches a 181-line `code-reviewer.md` prompt
   that lived inside the dropped `requesting-code-review`. It is preserved as a
   local asset of `subagent-driven-development/`.

### The SessionStart hook

Disabling the superpowers plugin kills its hook, which injected
`using-superpowers` into every session — the thing that makes skills fire at
all. `claude/scripts/skills-session-start.sh` replaces it, reading the local
(rewritten) copy so it names skills that actually exist.

## Codex

`~/.agents/skills/` gets **symlinks into `~/.claude/skills/`**, so one source of
truth and the refresh scripts update both harnesses at once.

Compatibility holds because both libraries ship Codex adaptations: every
mattpocock skill has `agents/openai.yaml` (with `policy.allow_implicit_invocation`,
the Codex equivalent of `disable-model-invocation`), and superpowers ships
`using-superpowers/references/codex-tools.md`.

Two skills are excluded as incompatible:

- `codex-plan-review` — drives the codex CLI *from* Claude Code; circular inside Codex.
- `requirement-engineering` — declares `AskUserQuestion` in `allowed-tools`,
  which Codex has no equivalent for.

`install.sh` sets `[features] multi_agent = true` in `~/.codex/config.toml`;
without it `dispatching-parallel-agents` and `subagent-driven-development` have
no spawn tools. See `codex/config.fragment.toml` for a recommended
`[agents] default_subagent_model` backstop that is deliberately **not** applied,
because the right value depends on your spawn allowlist.

## Layout

```
manifest.sh                  every skill/plugin list — the single source of truth
install.sh                   idempotent bootstrap
claude/
  settings.base.json         merged into ~/.claude/settings.json (never overwritten)
  scripts/
    skills-session-start.sh  SessionStart hook
    refresh-*-skills.sh      pull upstream, reapply the rewrites
    context-bar.sh           statusline
codex/config.fragment.toml   what install.sh merges into ~/.codex/config.toml
skills/codex-plan-review/    the one skill authored here
```

Upstream skills are **not vendored into this repo** — `install.sh` clones them
and applies the selection, so they are always current and there is no
third copy to drift.

## Staying current

```bash
~/.claude/scripts/refresh-mattpocock-skills.sh          # report
~/.claude/scripts/refresh-mattpocock-skills.sh --apply  # take upstream where you have no edits
~/.claude/scripts/refresh-superpowers-skills.sh --apply # re-pull + reapply rewrites
```

Both read `~/.claude/scripts/harness-manifest.sh`, installed from `manifest.sh`.
Edit the manifest, re-run `install.sh`, and both harnesses follow.

## Not in here

Credentials, `~/.claude.json` (session state), MCP server config, and the
per-project trust list in `~/.codex/config.toml`. Those are machine-local.
