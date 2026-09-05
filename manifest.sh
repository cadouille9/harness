#!/usr/bin/env bash
# Single source of truth for the harness. Sourced by install.sh and by the
# refresh scripts (which get a copy at ~/.claude/scripts/harness-manifest.sh).
#
# Editing a list here changes what install and refresh both do. Nothing else
# should carry its own copy of these names.

# --- mattpocock/skills: the selection, by upstream group -------------------
# Excluded on purpose: ask-matt, improve-codebase-architecture,
# resolving-merge-conflicts, writing-for-agents, the misc/ setup skills, and
# most of in-progress/.
HARNESS_MATT_ENGINEERING="setup-matt-pocock-skills grill-with-docs to-spec to-tickets triage wayfinder implement tdd codebase-design domain-modeling diagnosing-bugs code-review research wizard prototype"
HARNESS_MATT_PRODUCTIVITY="grilling grill-me handoff"
HARNESS_MATT_INPROGRESS="retro"

# --- obra/superpowers: kept for what only it does --------------------------
# Dropped because mattpocock replaced them (see README "Resolved overlaps"):
# brainstorming, test-driven-development, systematic-debugging,
# requesting-code-review, receiving-code-review.
HARNESS_SP_SKILLS="dispatching-parallel-agents executing-plans finishing-a-development-branch subagent-driven-development using-git-worktrees using-superpowers verification-before-completion writing-plans writing-skills"

# --- skills authored here --------------------------------------------------
HARNESS_OWN_SKILLS="codex-plan-review"

# --- Codex mirror ----------------------------------------------------------
# Everything above EXCEPT these, which depend on things Codex does not have.
# codex-plan-review drives the codex CLI *from* Claude Code (circular in Codex);
# requirement-engineering declares AskUserQuestion in allowed-tools.
HARNESS_CODEX_EXCLUDE="codex-plan-review requirement-engineering"
HARNESS_CODEX_EXTRA="delegate"

# --- plugins ---------------------------------------------------------------
HARNESS_MARKETPLACES="openai-codex=openai/codex-plugin-cc visual-explainer-marketplace=nicobailon/visual-explainer karpathy-skills=forrestchang/andrej-karpathy-skills"

HARNESS_PLUGINS_ON="document-skills@anthropic-agent-skills frontend-design@claude-plugins-official context7@claude-plugins-official code-review@claude-plugins-official typescript-lsp@claude-plugins-official pyright-lsp@claude-plugins-official playwright@claude-plugins-official code-simplifier@claude-plugins-official claude-md-management@claude-plugins-official claude-code-setup@claude-plugins-official skill-creator@claude-plugins-official claude-security@claude-plugins-official codex@openai-codex visual-explainer@visual-explainer-marketplace andrej-karpathy-skills@karpathy-skills"

# Explicitly off. superpowers is off because its skills are vendored directly
# (a plugin cannot have individual skills disabled); sonatype-guide is off so
# its bundled .mcp.json cannot re-add a server we removed.
HARNESS_PLUGINS_OFF="superpowers@claude-plugins-official feature-dev@claude-plugins-official superdesign@claude-plugins-official sonatype-guide@claude-plugins-official github@claude-plugins-official security-guidance@claude-plugins-official agent-sdk-dev@claude-plugins-official example-skills@anthropic-agent-skills"

# --- upstream sources ------------------------------------------------------
HARNESS_VENDOR_MATT="https://github.com/mattpocock/skills.git"
HARNESS_VENDOR_SP="https://github.com/obra/superpowers.git"
