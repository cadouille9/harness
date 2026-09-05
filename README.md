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

## Using the skills

### The main loop

```
  idea ──▶ /grill-with-docs ──▶ /to-spec ──▶ /to-tickets ──▶ /implement ──▶ review ──▶ finish
           interview you        spec +       vertical         tdd at the    two axes   integrate
           into a design        seams +      slices with      agreed seams  in
           tree; writes         Testing      blocking                       parallel
           ADRs + glossary      Decisions    edges
                                    │            │
                                    └── /codex-plan-review ──┘
                                        second model attacks it
                                        before any code exists
```

Each step feeds the next. `grill-with-docs` writes the glossary and ADRs that
`to-spec` and `to-tickets` read; `to-spec` agrees the **seams** that `tdd` later
tests at; `to-tickets` puts acceptance criteria on each ticket that `code-review`
checks the implementation against. Skipping a step doesn't break the next one, it
just makes it guess.

Run `/setup-matt-pocock-skills` **once per repo** before any of this — it writes
`docs/agents/issue-tracker.md`, which tells the chain where tickets go.

### Where to jump in

| Situation | Start with |
|---|---|
| Vague idea, and it's bigger than one session | `/wayfinder` — charts decision tickets, resolves them one at a time |
| Vague idea, normal size | `/grill-with-docs` |
| Already talked it through; just capture it | `/to-spec` — no interview, pure synthesis |
| Spec or tickets already exist | `/implement` |
| Something is broken, slow, or throwing | just say so — `diagnosing-bugs` fires |
| Not sure where an interface or seam belongs | say so — `codebase-design` fires |
| Not sure the model or logic feels right | say so — `prototype` fires (throwaway code that answers one question) |
| Need facts from docs or primary sources | say so — `research` fires and runs in the background |
| Inbox of issues and external PRs | `/triage` |
| Manual steps only a human can do (dashboards, secrets) | say so — `wizard` writes you a bash walkthrough |
| Bulk mechanical work with a pass/fail check | `/delegate` |
| Running low on context | `/handoff` |
| Session went badly and you want the setup fixed | `/retro` |

### Typed vs automatic

**11 you type.** Nothing below fires on its own — they publish, restructure, or
take over the session, so they wait for you:

```
/setup-matt-pocock-skills  /grill-with-docs  /grill-me   /to-spec   /to-tickets
/triage  /wayfinder  /implement  /handoff  /retro  /codex-plan-review
```

**The rest fire on their own**, triggered by what you say. `tdd`,
`diagnosing-bugs`, `code-review`, `codebase-design`, `domain-modeling`,
`grilling`, `prototype`, `research`, `wizard`, plus the superpowers set below.
The SessionStart hook is what makes this reliable.

### Superpowers: the execution half

These all fire on their own, and cover the part of the loop mattpocock doesn't:

| Skill | Fires when |
|---|---|
| `writing-plans` | you have a spec and a multi-step task, before code |
| `subagent-driven-development` | executing a plan's independent tasks **in this session** |
| `executing-plans` | executing a plan **in a separate session**, with review checkpoints |
| `dispatching-parallel-agents` | 2+ tasks with no shared state and no ordering between them |
| `using-git-worktrees` | feature work that needs isolation from your current tree |
| `verification-before-completion` | you're about to claim something works — forces evidence first |
| `finishing-a-development-branch` | implementation done, tests green, needs integrating |
| `writing-skills` | authoring or editing a skill (pairs with the `skill-creator` plugin) |

`subagent-driven-development` and `executing-plans` are the same job at different
scopes — one session vs. across sessions. Both consume a plan from
`writing-plans`.

### Two overlaps to be deliberate about

**`/implement` vs `subagent-driven-development`.** `/implement` works from a spec
or tickets and drives `tdd` at the agreed seams — the mattpocock path.
`subagent-driven-development` works from a written plan and fans out to
subagents, then dispatches a final reviewer. Use `/implement` when the tickets
are the unit of work; use SDD when a plan is, and you want it run autonomously.

**`writing-skills` vs `skill-creator`.** Kept together on purpose: `writing-skills`
is the method (TDD applied to documentation — write pressure tests, watch them
fail, then write the skill), `skill-creator` is the tooling that runs the evals
and scaffolds the files. Method then harness, not either/or.

### Notes

- `/grill-me` is a one-line alias for `grilling`. `/grill-with-docs` is the same
  interview but emits ADRs and a glossary as it goes — prefer it, because the rest
  of the chain reads those.
- `/to-spec` deliberately does **not** interview you. Grill first, then capture.
- `/codex-plan-review` is read-only: no `--write` is passed, so Codex can read the
  repo to check the plan's claims against real code but cannot edit anything. Use
  `/codex:adversarial-review` instead once a diff exists — it's diff-scoped and
  needs file:line anchors a plan doesn't have.
- Don't reach for `/implement` on a one-or-two-file edit. Just make the edit.

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
