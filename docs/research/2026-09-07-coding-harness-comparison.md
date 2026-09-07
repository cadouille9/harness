# OpenCode, Codex, Qwen Code, and DeepSeek: lessons for this harness

Research date: 2026-09-07. Local baseline: `5bbc0a31bb65a527e40c1dcd24d884a3a0fc5e3e`.

Source snapshots inspected: OpenCode `v1.18.29` (`16747470f976aca3d362ad730bcd3fe82ecc2c9a`), Qwen Code `f1ed3bc31a2b618072dbd3c8d9ee3e04f48416d1`, DeepSeek Harness `c389f96bf3a9b6807cb71ed6bdad5849be0df6d8`. Codex findings use current official documentation rather than a pinned runtime source audit. Source snapshots establish what was inspected, not that unreleased code is available in an installed package.

This is an architecture and workflow comparison based on first-party documentation, targeted source inspection, and this repository. It is not a measured coding benchmark. “Better” below means a better fit for a stated requirement; recommendations are engineering judgments. Documentation and repository main branches move independently of installed releases. Verify the installed version before adopting a configuration example.

## What is being compared

Three layers matter:

1. **Model and provider:** reasoning, tool-call generation, context capacity, inference latency, price, and API behavior.
2. **Agent runtime:** executes the loop, manages tools and context, persists sessions, enforces permissions, and manages delegated work.
3. **Your workflow layer:** selects skills, installs plugins, supplies project conventions, and adapts these across runtimes.

Your repository principally implements the third layer. Its requirements-to-tickets workflow, shared vocabulary, selected skill libraries, and installer are assets worth preserving. They do not replace runtime services such as process isolation or reliable session recovery. [Local README](../../README.md), [manifest](../../manifest.sh), [installer](../../install.sh).

DeepSeek here means the official **DeepSeek Harness (`dsh`)**, not a community CLI or simply using a DeepSeek model inside another client. It is explicitly a developer preview. Qwen means **Qwen Code**, the coding runtime, rather than the Qwen model family. [DeepSeek repository](https://github.com/deepseek-ai/deepseek-harness), [Qwen Code repository](https://github.com/QwenLM/qwen-code).

## Practical comparison

My recommendation is to keep your existing shared workflow layer, use Codex as the initial reference for bounded execution, trial OpenCode for provider flexibility, study Qwen for recovery and configurable workflows, and borrow DeepSeek's capability interfaces and event model before considering a runtime migration. The product-specific evidence and limitations follow the matrix.

| Dimension | OpenCode | Codex | Qwen Code | DeepSeek Harness |
|---|---|---|---|---|
| Most useful design emphasis | Provider choice and extensible coding client | Execution policy and programmable agent threads | Broad workflow features and recovery controls | Replaceable runtime subsystems |
| Extension approach | JS/TS plugins, custom tools, skills, MCP | Skills, plugins, lifecycle hooks, MCP, SDK/app-server | Skills/extensions, several hook executors, MCP, SDK/ACP | Cordis plugins can replace the loop, tools, log, and providers |
| Provider fit | Broad cloud/local integrations | Custom/local routes; verify Responses compatibility | Multiple native API protocols and specialized adapters | Native DeepSeek plus additional provider adapters |
| Execution boundary | Application permissions; add independent isolation | OS sandbox and separate approval policy | Opt-in Seatbelt or Docker/Podman, separate approval modes | Filesystem sandbox and approval policy; profile-dependent |
| Context/recovery | Compaction, child sessions, Git-based undo/redo | Compaction, persistent threads, resume/fork | Compaction, session resume, optional file+chat checkpoints | Event-log-derived history and replaceable compaction |
| Automation surface | HTTP/OpenAPI, event stream, SDK, CLI run | Exec JSONL/schema, SDKs, bidirectional app-server | Headless JSON, ACP, HTTP/SSE daemon, SDKs | Headless, JSON-RPC SDK, ACP profile |
| Main evaluation concern | Host-shell authority and provider-specific behavior | Config/protocol compatibility and feature maturity | Optional features/defaults and experimental integration surfaces | Developer-preview stability and composition complexity |

These are comparative fit assessments, not numerical scores. Several capabilities overlap substantially. “Supports subagents” or “supports MCP” alone is too coarse to predict whether your workflow will work.

## OpenCode: provider choice and practical runtime customization

OpenCode's terminal interface is a client of a local HTTP server. The server exposes an OpenAPI interface and event stream for session, message, tool, and other operations. This is an attractive architecture when you want a custom UI or controller while preserving a shared execution engine. Its provider integration covers cloud and local models through the AI SDK and Models.dev ecosystem. [Server](https://opencode.ai/docs/server/), [Providers](https://opencode.ai/docs/providers/).

Its plugins are executable JavaScript/TypeScript extensions, with access to the SDK client and lifecycle hooks. Custom tools, changes to model request parameters, tool interception, and compaction customization can be implemented without forking the whole application. This is a broader customization surface than portable skill instructions alone; it also means plugin code is part of the trusted application. [Plugins](https://opencode.ai/docs/plugins/).

OpenCode supports primary agents and subagents, with configurable models, instructions, tool permissions, and step limits. It is useful for creating different working roles within one client. A child session is a separate context, not automatically a separate working tree. [Agents](https://opencode.ai/docs/agents/).

One practical feature is language-server diagnostic feedback. It can put actionable errors into the edit/repair loop, reducing the need for the model to remember a separate diagnostic command after each change. **LSP is currently disabled by default.** The official docs explicitly acknowledge memory use, synchronization problems, and latency, and recommend ordinary lint/typecheck commands when those are a better fit. Your existing Pi lens integration should be measured on the same basis. [LSP](https://opencode.ai/docs/lsp/).

Permissions offer allow/ask/deny decisions, per-agent overrides, external-directory checks, and a repeated-identical-call guard. Most permissions are permissive by default. These are application-level decisions, not OS-level confinement of arbitrary shell programs. The inspected shell tool launches the host shell with the inherited process environment. A rule checking visible command arguments cannot establish what an interpreter or script will subsequently do. For genuinely bounded execution, pair the runtime with an independently enforced environment. [Permissions](https://opencode.ai/docs/permissions/), [Pinned shell implementation](https://github.com/anomalyco/opencode/blob/16747470f976aca3d362ad730bcd3fe82ecc2c9a/packages/opencode/src/tool/shell.ts).

Provider portability is adapted rather than uniform: the inspected tool registry selects patch editing for some GPT families and edit/write tools for others. This is evidence that model/tool fit matters even when the high-level workflow is unchanged. [Pinned tool registry](https://github.com/anomalyco/opencode/blob/16747470f976aca3d362ad730bcd3fe82ecc2c9a/packages/opencode/src/tool/registry.ts).

OpenCode's undo/redo uses Git to restore file changes as well as moving the conversation backward or forward. That is a distinct capability from summarizing history or forking a chat; it still cannot reverse arbitrary external side effects. [Terminal commands](https://opencode.ai/docs/tui/).

Its compaction implementation combines a summary with a retained recent tail and prunes older tool results. The inspected version protects skill outputs from that pruning pass. This is an example of treating different context types differently rather than blindly summarizing everything. Skills load on demand, and local or remote MCP servers can extend the toolset; exposing more tool schemas also consumes context. [Pinned compaction implementation](https://github.com/anomalyco/opencode/blob/16747470f976aca3d362ad730bcd3fe82ecc2c9a/packages/opencode/src/session/compaction.ts), [Skills](https://opencode.ai/docs/skills/), [MCP](https://opencode.ai/docs/mcp-servers/).

**Where I would choose it:** a daily coding environment where switching providers and adding JavaScript tooling are central requirements. **Where I would scrutinize it:** unattended host execution, permissions assumed to imply a sandbox, and whether extra diagnostics improve task success enough to justify their overhead. Provider breadth is a usability advantage; it does not establish equal coding quality across every supported model.

## Codex: execution boundaries and a programmable agent runtime

Codex exposes an app-server protocol for clients that need authentication, history, approvals, and streaming events. Its thread/turn/item model supplies a useful vocabulary for orchestration: a persistent conversation contains units of work, which emit individual messages and tool actions. The protocol includes resume, fork, steering, and interruption. This makes it a strong reference when designing a controller that must handle ongoing work and user input. The docs mark app-server/WebSocket functionality experimental and unsupported for production workloads; assess maturity per endpoint and transport rather than treating the whole surface as uniformly stable. [App Server](https://learn.chatgpt.com/docs/app-server).

For simple jobs, `codex exec` offers JSONL events and a JSON Schema for the final output. These are different contracts: the event stream records execution; the schema describes the result. Sessions can be resumed explicitly. The default documented exec sandbox is read-only; callers can choose workspace-write. This is a useful foundation for your plan-review and future evaluation runner. [Non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode).

The TypeScript SDK starts and resumes local threads. The Python SDK controls local app-server over JSON-RPC and published builds include a pinned runtime dependency. An SDK can therefore avoid some coupling to a third-party plugin's internal script paths. This does not eliminate the need to pin and test SDK versions. [Codex SDK](https://learn.chatgpt.com/docs/codex-sdk).

**The strongest execution-boundary lesson is the separation of sandboxing from approvals.** Codex's sandbox constrains spawned processes, including commands invoked by package managers or tests. Approval policy decides when an exception requires review. Supported implementations include macOS Seatbelt, Linux/WSL bubblewrap, and a native Windows sandbox. This permits routine work within a defined scope with fewer prompts, while enforcing a boundary independently of the model's intentions. Full-access mode deliberately removes that protection. External MCP services require their own access controls; a local shell sandbox is not a universal boundary around all integrations. [Sandbox](https://learn.chatgpt.com/docs/sandboxing), [Agent approvals and security](https://learn.chatgpt.com/docs/agent-approvals-security).

Subagents have their own threads, model settings, and instructions. Current docs describe inheritance of the parent's sandbox policy and reapplication of live parent runtime overrides. Noninteractive actions needing fresh approval fail back to the workflow. Treat effective permissions as a computed runtime property: an agent definition alone is insufficient evidence that the child is read-only. Parallel writers also still need explicit workspace ownership. [Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents).

Codex now documents lifecycle hooks including tool, compaction, session, and subagent events. `Stop` can request continuation when completion criteria are unmet; `PostToolUse` cannot undo a side effect that already happened. Matching hooks can run concurrently, and trust review applies to non-managed hooks. This is enough machinery to move selected checks from prose into code, but hooks need their own failure and loop controls. [Hooks](https://learn.chatgpt.com/docs/hooks).

Skills load progressively: initial metadata first, full instructions when selected. The discovery list itself has a budget and can omit skills when large. Codex supports explicit-only invocation metadata and disabling individual local skills. Project instructions are separately discovered through a documented `AGENTS.md` chain. These distinctions matter for your shared library: installed, discoverable, selected, and executed are four separate states. [Build skills](https://learn.chatgpt.com/docs/build-skills), [AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

**Portability is supported, but protocol compatibility needs checking.** Codex documents custom providers and local Ollama/LM Studio modes. Its current configuration reference restricts custom `wire_api` to `responses`; an arbitrary Chat Completions-compatible endpoint is consequently not enough to establish compatibility. The advanced guide also contains legacy-sounding Chat Completions wording, so the deployed runtime/schema should resolve ambiguity. [Advanced configuration](https://learn.chatgpt.com/docs/config-file/config-advanced), [Configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).

Context controls include an automatic compaction threshold, a configurable compaction prompt, and a per-tool history output budget. Their existence does not prove that constraints survive every compaction. Evaluate that behavior with a task that spans compaction and then checks decisions and remaining work. [Configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).

**Where I would choose it:** bounded autonomous code execution, resumable engineering jobs, and workflows that benefit from explicit thread controls. **Where I would scrutinize it:** arbitrary provider compatibility, experimental integration surfaces, and version-sensitive configuration. These are fit judgments, not evidence that Codex produces better patches than the other runtimes.

## Qwen Code: broad workflow controls, recovery, and protocol adapters

Qwen Code separates its UI-independent core from terminal and other presentation surfaces. It supports headless execution, ACP, and an HTTP/SSE daemon that fronts ACP child processes. Its architecture is useful when one engine needs several entry points. Headless runs provide text, JSON, or streamed JSON output and resumable sessions. SDK and newer daemon surfaces should be evaluated individually for maturity rather than assuming that terminal availability makes every integration stable. [Architecture](https://qwenlm.github.io/qwen-code-docs/en/developers/architecture/), [Headless mode](https://qwenlm.github.io/qwen-code-docs/en/users/features/headless/), [TypeScript SDK](https://qwenlm.github.io/qwen-code-docs/en/developers/sdk-typescript/).

**Recovery is a concrete strength.** Optional checkpointing captures a shadow Git commit, conversation state, and the pending edit before a supported AI file mutation. Restoring can bring back both files and conversation and re-propose the action. Checkpointing is disabled by default. This is particularly useful for interactive exploration, but it is not a rollback of remote operations, database mutations, or every arbitrary shell side effect. [Checkpointing](https://qwenlm.github.io/qwen-code-docs/en/users/features/checkpointing/).

Approval modes span planning, asking, automatic edits, classifier-based auto approval, and full tool approval. Sandbox enforcement is a separate opt-in: macOS Seatbelt or Docker/Podman. The documented Seatbelt default allows outbound network, and the container mounts both the workspace and Qwen's configuration directory. Thus “auto” or “yolo” says little about actual process containment. Evaluate the chosen mounts, network, and approval behavior together. [Approval modes](https://qwenlm.github.io/qwen-code-docs/en/users/features/approval-mode/), [Sandbox guide](https://github.com/QwenLM/qwen-code/blob/f1ed3bc31a2b618072dbd3c8d9ee3e04f48416d1/docs/users/features/sandbox.md).

Named subagents have separate context and configurable model, tools, MCP servers, hooks, permissions, and turn limits. Forked agents can inherit conversation context and preserve the system/tool prefix for cache reuse. Those forks share the parent directory and cannot recursively fork; a narrowed tool list is not an administrative sandbox. This distinction is useful for your workflow: a fresh specialist and an inherited-context collaborator are different execution modes, with different cost and coordination implications. [Subagents](https://qwenlm.github.io/qwen-code-docs/en/users/features/sub-agents/).

Hooks support command, HTTP, in-process function, and model-prompt executors across tools, sessions, compaction, subagents, and other events. This gives Qwen a rich declarative workflow layer. An interactive permission request becomes a denial when no interactive prompt can be shown. Model-based hooks add inference cost and uncertainty; deterministic checks should use deterministic executors. [Hooks](https://qwenlm.github.io/qwen-code-docs/en/users/features/hooks/).

Qwen's MCP integration exposes tools, prompts, and resources. DeepSeek's current MCP bridge documents tools only, with the other primitives deferred. This is a meaningful difference if your workflow depends on reusable MCP prompts or resource browsing, rather than only remote tool calls. [Qwen MCP](https://github.com/QwenLM/qwen-code/blob/f1ed3bc31a2b618072dbd3c8d9ee3e04f48416d1/docs/users/features/mcp.md), [DeepSeek MCP bridge](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/mcp/mcp-client/README.md).

Qwen Code also supports multiple API protocols, including OpenAI-compatible, Anthropic, and Gemini routes, with specialized adapters for provider quirks. Its DeepSeek adapter handles reasoning fields and wire-shape differences. This is stronger portability evidence than a generic “custom base URL” option, although it still needs a multi-turn tool-use test against your actual endpoint. [Model providers](https://github.com/QwenLM/qwen-code/blob/f1ed3bc31a2b618072dbd3c8d9ee3e04f48416d1/docs/users/configuration/model-providers.md), [DeepSeek adapter source](https://github.com/QwenLM/qwen-code/blob/f1ed3bc31a2b618072dbd3c8d9ee3e04f48416d1/packages/core/src/core/openaiContentGenerator/provider/deepseek.ts).

**Where I would choose it:** workflows that benefit from explicit recovery, multiple provider protocols, and configurable subagent/hook behavior. **Where I would scrutinize it:** the exact enabled defaults, shared-directory fork behavior, and SDK/daemon maturity. It is a substantive alternative to OpenCode, not merely a client for Qwen models.

## DeepSeek Harness: replaceable internals and explicit execution history

DeepSeek's distinctive architecture is that even the agent loop, model adapter, tool registry, and session log are plugins. Cordis provides services, typed events, and registrations that unwind when a plugin unloads. Profiles compose bundles and ordered configuration overlays; web, headless, SDK, minimal SDK, and ACP are different compositions. This is a stronger internal replacement model than merely adding tools around a fixed loop. The cost is understanding dependency lifecycles and composition rules. [Architecture](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/architecture.md).

**Its session model is especially worth borrowing.** An append-only event log is the authoritative record; model history is derived from it. Request headers record prompt and tool-schema state, while failed attempts can be retained without entering model-visible history. This supports explaining what an agent actually saw, rather than trying to reconstruct it from the final chat transcript. Replay here means reconstructing state, not guaranteeing identical future model output or safely re-executing side effects. [Session subsystem](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/session.md).

Compaction is a replaceable capability, separate from the loop. Its interface distinguishes automatic pressure, overflow recovery, and manual compaction. The documented implementation preserves tool-call/result pairing and distinguishes failures before mutation from failures committing or persisting a reduction. The architectural lesson is to treat compaction as a state transition with explicit outcomes, not an invisible summarization trick. [Compaction subsystem](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/compaction.md).

Delegation is another capability with multiple providers: in-process children, ACP, Codex, Claude Code, and dsh SDK backends. Provider capability checks reject unsupported requests rather than silently ignoring requested behavior. That maps unusually well to your goal of sharing workflows across runtimes. It does not mean their permissions, context, or cancellation semantics become identical; the adapter must account for those differences. [Subagent subsystem](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/subagent.md).

The standard base-backed profiles document `workspace-write` as the new-session permission default and restrict mutations to the workspace and temporary roots. Reads and network access are not confined by that preset. Backends differ in process visibility. The minimal SDK profile is materially different: it uses full access and omits the approval/settings service. An integration must consequently pin the composition as well as the version; “runs in dsh” does not describe one uniform policy. [CLI reference](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/reference/README.md).

A native DeepSeek adapter translates its API into the harness stream interface; a separate pi-ai adapter can serve other routes alongside it. This makes dsh more than a single-provider wrapper. Provider-specific serialization still matters: reasoning, tool history, images, and errors are part of the adapter contract, not just URL and API-key configuration. [DeepSeek adapter](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/llm/llm-deepseek/README.md).

**Where I would choose it:** studying or experimenting with replaceable loops, durable event records, and delegation across products. **Where I would scrutinize it:** adopting it as your primary runtime today. Its maintainers explicitly call it experimental developer-preview software, state that it has not had a security audit, and warn of compatibility-breaking changes. Its design is compelling evidence for what to prototype; it is not evidence of production reliability or superior task completion. [Project status](https://github.com/deepseek-ai/deepseek-harness), [Safety notice](https://github.com/deepseek-ai/deepseek-harness/blob/master/SAFETY.md).

## Improvements suggested by your actual repository

### 1. Make installations reproducible before adding another runtime

`install.sh` clones or fast-forwards upstream skill repositories and then reapplies local transformations. `manifest.sh` pins `pi-lens`, but not every package or the upstream skill revisions. The result is repeatable installation procedure, not identical behavior over time. [Installer](../../install.sh), [manifest](../../manifest.sh).

Add a lock manifest recording upstream commits, package/plugin versions, runtime versions, and transformation revision. Separate installing the lock from proposing an update. Record the final installed skill hashes. This makes a behavioral regression attributable to an actual change and makes comparisons between runtimes meaningful.

### 2. Express portable intent and adapt capabilities per runtime

Your shared skills are physically rooted in `~/.claude/skills`, with symlinks for Codex and Pi. Exclusions already encode differences such as unavailable question tools and circular delegation. Pi also receives a global textual translation for “call the Skill tool.” These are existing adapters, expressed across lists and prose. [README](../../README.md), [manifest](../../manifest.sh), [Pi instruction fragment](../../pi/AGENTS.fragment.md).

Make that adaptation explicit. Describe required capabilities such as user questions, delegated work, durable resume, structured results, and write isolation. Each adapter should report whether the capability is native, supplied by an extension, emulated, or unavailable. Keep workflow instructions independent of concrete tool names where possible. Use a neutral canonical skill directory when it simplifies ownership, but do not migrate paths solely for aesthetic symmetry.

A proposed `harness doctor` should check effective versions, skill discovery, required tools, plugin availability, and child permissions. It should report unsupported workflows before the agent is halfway through a task.

### 3. Give parent and child execution the same explicit boundary

The Pi extension checks direct file writes and selected shell patterns. Its own comments correctly state that arbitrary shell execution can bypass those checks and that subagent children do not load the extension. This is a specific limitation of the installed setup, not a claim that all Pi configurations behave this way. [Boundary implementation](../../pi/extensions/harness-boundary.ts), [README boundary discussion](../../README.md).

For unattended jobs, define filesystem/network scope at the execution environment and propagate it to children. Continue to use worktrees for independent diffs, but a Git worktree does not sandbox a process. A useful acceptance test checks the same out-of-scope operation in the parent and a child and records whether it executed, was denied, or requested approval. The expected policy can differ for interactive and unattended profiles, but it should not differ accidentally because the child uses another process.

### 4. Replace stale compatibility assertions with versioned checks

Your Codex fragment and README describe `[features] multi_agent = true` as a prerequisite. Current first-party subagent documentation says delegation is enabled by default and describes `agents.enabled`; the config reference also still documents the older feature key. This is evidence of documentation/configuration evolution, not proof that your existing key is broken. Check against supported runtime versions before updating the fragment. [Local fragment](../../codex/config.fragment.toml), [Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents), [Configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).

The plan-review wrapper discovers the newest `codex-companion.mjs` under a plugin cache and invokes an internal command. That makes its operation depend on an unpinned implementation interface. A direct exec/SDK adapter with an explicit output contract is worth evaluating. [Plan-review wrapper](../../skills/codex-plan-review/scripts/plan-review.sh), [Codex SDK](https://learn.chatgpt.com/docs/codex-sdk).

### 5. Keep durable task state small and separate from the transcript

Record objective, accepted decisions, remaining work, changed files, verification evidence, and blockers in a task artifact. Rehydrate the relevant portion after resume or compaction. Associate verification with the code state it checked so later edits invalidate stale evidence. Store durable results from delegated tasks rather than depending on the parent remembering a transient summary.

This complements your existing specs, ADRs, tickets, and handoffs. The proposed addition is an execution record that connects those artifacts to the current work. Start with a small JSON or Markdown file rather than a new orchestration service.

### 6. Make a few workflow rules executable and measure the rest

Your setup already invests heavily in skill activation through a startup injection and mirrored instructions. Adding stronger wording alone can create competing instructions and more unnecessary process. [Startup hook](../../claude/scripts/skills-session-start.sh), [Pi instruction fragment](../../pi/AGENTS.fragment.md).

Use hooks or a wrapper for deterministic facts: check whether a required artifact exists, whether relevant verification succeeded for the current state, and whether the delegated task returned a result. Leave judgment—what tests matter, whether a small edit needs a plan, whether to ask the user—to the agent within clear instructions. Completion checks need bounded retries and legitimate “not applicable” outcomes, otherwise they can trap a successful task in a loop.

### 7. Route work by task economics, with explicit limits

Define roles such as explorer, implementer, and reviewer, each with an available model, reasoning setting, tool scope, and budget. Measure the total cost of the parent and children, not just the child's token rate. Use independent readers first; parallel implementation needs file ownership or separate worktrees plus integration verification.

Your Codex fragment already recommends a model/effort default without enforcing machine-specific values. Preserve that distinction: a policy can express “economical explorer,” while the machine adapter resolves a model that actually exists. [Codex fragment](../../codex/config.fragment.toml).

## How to find out which one is better for your work

Run two separate experiments. First, hold the model/provider constant where compatibility permits and change the harness; this approximates the runtime effect. Second, compare the best practical model/runtime combination for each product; this answers what you should use day to day. Label configurations that cannot share a model rather than treating them as controlled comparisons.

Start with roughly 12–20 representative tasks from your own repositories, using clean disposable worktrees and known acceptance criteria. Include a small bug, a multi-file feature, an ambiguous requirement, a failing test diagnosis, a large-log task, a compaction/resume task, and independent delegated work. Include a case where an already-authorized action should proceed without asking again. These are proposed tests, not tests performed for this report.

| Measure | What it tells you |
|---|---|
| Acceptance checks and human patch review | Whether the task actually succeeded |
| Time to accepted result | Includes recovery, verification, and user intervention |
| Total billed cost and token usage | Includes failed attempts, summaries, retries, and every child |
| Human interventions and avoidable questions | Whether autonomy reduces your workload |
| Invalid calls and edit-repair attempts | Whether the model and tool interface fit |
| Decisions preserved after compaction/resume | Whether long work survives context management |
| Parent and child boundary behavior | Whether the configured policy actually holds |
| Diff conflicts and integration rework | Whether parallel execution was worth its coordination cost |

Pin runtime version, model ID, reasoning setting, skills, provider endpoint, context settings, and task budget. Repeat stochastic tasks and report distributions, not the best run. Use identical dependency/setup conditions and distinguish cold starts from warm caches. Vendor model benchmarks do not isolate harness quality. The useful target is cost and time per accepted task, with intervention burden reported alongside them.
