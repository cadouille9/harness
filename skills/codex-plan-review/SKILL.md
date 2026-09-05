---
name: codex-plan-review
description: Send a plan, spec, or ticket breakdown to Codex for an adversarial review before any code is written. Use when the user runs /codex-plan-review, or asks for a second opinion on a plan from Codex or GPT.
disable-model-invocation: true
argument-hint: "[path | issue number/URL | nothing for the current conversation] [--background]"
allowed-tools: Read, Glob, Grep, Bash, AskUserQuestion
---

# Codex Plan Review

A second model attacks the plan **before** it becomes tickets or code.

This exists because `/codex:review` and `/codex:adversarial-review` are diff-based:
they scope to working-tree or branch changes and require every finding to carry a
file plus `line_start`/`line_end`. When a plan is written there is no diff and no
line to point at. This skill reviews prose.

**Use this for**: a spec from `to-spec`, a ticket breakdown from `to-tickets` before
publishing, a `wayfinder` decision map, an ADR, a design doc, or a plan that only
exists in the current conversation.

**Do not use this for code.** Once there is a diff, use `/codex:adversarial-review`.

## Process

### 1. Resolve the plan

From `$ARGUMENTS`:

- **A path** (`docs/spec.md`, `.scratch/feature/issues/03-slug.md`) → read it. A
  directory or glob → read every file, in dependency order if they are numbered tickets.
- **An issue number or URL** (`42`, `https://github.com/o/r/issues/42`) → fetch the
  full body *and comments* with `gh issue view <n> --comments`. If the issue has
  sub-issues, fetch those too — the breakdown is the thing under review.
- **Nothing** → use the plan as it stands in the current conversation. Write it out
  in full first; do not make Codex infer it from fragments.

Codex runs read-only in the workspace, so it can read the repo itself. Do not paste
source files into the prompt — name the paths and let it look.

### 2. Assemble the prompt

Write the review prompt to a scratch file. Use the harness scratchpad directory if
one is set, otherwise `.scratch/`:

```bash
PROMPT=$(mktemp --suffix=.md)
```

Fill it with the template in `references/review-prompt.md`, substituting:

- `{{PLAN}}` — the full plan text, verbatim. Never a summary.
- `{{CONTEXT}}` — one paragraph: what this repo is, what stage the plan is at
  (draft spec / approved spec / published tickets), and anything already decided
  and not up for debate. If a `CONTEXT.md` or ADRs exist, name their paths so
  Codex can read them rather than pasting them.
- `{{FOCUS}}` — any focus text the user passed after the target. Omit the line if none.

### 3. Run Codex

```bash
~/.claude/skills/codex-plan-review/scripts/plan-review.sh "$PROMPT"
```

The script resolves the newest `codex-companion.mjs` from the installed codex plugin
and runs `task --prompt-file` at `--effort high`. It passes **no** `--write`, which
maps to a `read-only` sandbox — Codex can read the repo but cannot edit it.

Add `--background` for a long plan, then tell the user to check `/codex:status`.
Do not poll for the result in the same turn.

### 4. Report

Return Codex's output **verbatim** first. No summary, no reordering, no commentary
above it.

Then, and only then, add your own assessment — you wrote the plan, so say where you
think Codex is right and where it is wrong:

- For each finding, state **agree / disagree / needs a decision from the user**, in
  one line each, with the reason.
- Do not silently accept a finding to seem agreeable, and do not defend the plan out
  of authorship. If Codex is wrong about a fact in the repo, check the repo and say so.
- Findings that survive become plan edits. Ask before making them.

Never edit the plan or publish tickets inside this skill. Review only.
