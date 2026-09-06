/**
 * Ask before the agent writes outside the current repo.
 *
 * Pi ships no permission layer by design ("intentionally does not include ...
 * permission popups"), so without this a `write` to ~/.bashrc just happens.
 *
 * The boundary is the git repo root of the session cwd, falling back to the cwd
 * when it is not a repo. Inside it, nothing is prompted. Outside it, `write`,
 * `edit`, and mutating `bash` commands ask first, and a refusal comes back to
 * the model as a blocked tool call with a reason.
 *
 * THIS IS A GUARDRAIL, NOT A SANDBOX. `bash` is unbounded: `sh -c`, `python -c`
 * or a heredoc reaches any path regardless of what is inspected here. It stops a
 * model that wanders. It does not stop one that is trying. For a real boundary,
 * use a container, or run pi from a worktree rather than from $HOME.
 *
 * It also covers this session only. pi-subagents runs children as separate
 * processes that never load this file, and its own child permission layer
 * (~/.pi/agent/extensions/subagent/config.json) is unconfigured here, so child
 * tool calls pass through ungated. See "Known gap" in the README.
 *
 * Failure is closed: if the check itself throws, the call is blocked and says
 * so, rather than being waved through.
 */

import { execFileSync } from "node:child_process";
import { basename, dirname, isAbsolute, join, resolve, sep } from "node:path";
import { realpathSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** Outside the boundary but never worth asking about. Trim to taste. */
export const ALWAYS_ALLOWED = ["/dev/null", "/dev/stdout", "/dev/stderr", "/tmp", process.env.TMPDIR];

/** A bash command is only inspected when it can actually mutate something. */
export const MUTATING = /(^|[;&|(\s])(rm|mv|cp|tee|install|chmod|chown|chgrp|ln|truncate|dd|mkdir|rmdir|touch|sed\s+-[a-z]*i)\b|>>?[^&]/;

const home = process.env.HOME ?? "";

/** realpath as far up the tree as exists, so a not-yet-created file still resolves. */
export function realish(p: string): string {
  let cur = resolve(p);
  const tail: string[] = [];
  for (;;) {
    try {
      return join(realpathSync(cur), ...[...tail].reverse());
    } catch {
      const parent = dirname(cur);
      if (parent === cur) return resolve(p);
      tail.push(basename(cur));
      cur = parent;
    }
  }
}

export function repoRoot(cwd: string): string {
  try {
    const out = execFileSync("git", ["rev-parse", "--show-toplevel"], {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    return out || cwd;
  } catch {
    return cwd;
  }
}

export function contains(parent: string, child: string): boolean {
  return child === parent || child.startsWith(parent + sep);
}

export function allowed(boundary: string, target: string): boolean {
  const t = realish(target);
  if (contains(boundary, t)) return true;
  return ALWAYS_ALLOWED.some((a) => a && contains(realish(a), t));
}

/** Absolute and ~-rooted path tokens a shell command mentions. */
export function pathsIn(command: string): string[] {
  const out: string[] = [];
  for (const m of command.matchAll(/(?<![\w$./])(~\/|\/)[^\s'";|&)>]*/g)) {
    const raw = m[0];
    out.push(raw.startsWith("~/") ? join(home, raw.slice(2)) : raw);
  }
  return out;
}

export default function (pi: ExtensionAPI) {
  let boundary: string | null = null;

  pi.on("tool_call", async (event, ctx) => {
    const root = (boundary ??= realish(repoRoot(ctx.cwd)));

    let reason: string | null = null;
    try {
      const input = event.input as Record<string, unknown>;

      if (event.toolName === "write" || event.toolName === "edit") {
        const p = input?.path;
        if (typeof p === "string" && p) {
          const target = isAbsolute(p) ? p : join(ctx.cwd, p);
          if (!allowed(root, target)) reason = `${event.toolName} ${realish(target)}`;
        }
      } else if (event.toolName === "bash") {
        const command = typeof input?.command === "string" ? input.command : "";
        if (/(^|[;&|(\s])sudo\b/.test(command)) {
          reason = "sudo";
        } else if (MUTATING.test(command)) {
          const escapes = pathsIn(command).filter((p) => !allowed(root, p));
          if (escapes.length > 0) reason = `writes outside the repo: ${escapes.join(", ")}`;
        }
      }
    } catch (err) {
      return {
        block: true,
        reason: `harness-boundary could not verify this call, so it was blocked: ${String(err)}`,
      };
    }

    if (!reason) return;

    // No dialog in -p / json mode: fail closed rather than hang or wave through.
    if (!ctx.hasUI) {
      return {
        block: true,
        reason: `Blocked: ${reason}. Outside ${root}, and this session cannot prompt (non-interactive).`,
      };
    }

    const ok = await ctx.ui.confirm("Outside the repo", `${reason}\n\nBoundary: ${root}\n\nAllow?`);
    if (!ok) return { block: true, reason: `Denied by the user: ${reason}` };
  });
}
