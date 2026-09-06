// Run: node --experimental-strip-types pi/extensions/harness-boundary.test.ts
//
// Exercises the gate's path logic directly — no pi and no model needed. The
// fixture is this repo itself, so it works wherever the harness is cloned.

import { join } from "node:path";
import { allowed, MUTATING, pathsIn, realish, repoRoot } from "./harness-boundary.ts";

const root = realish(repoRoot(import.meta.dirname));
const home = process.env.HOME ?? "/home/nobody";

let fail = 0;
const t = (name: string, got: unknown, want: unknown) => {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) fail++;
  const detail = ok ? "" : `  got ${JSON.stringify(got)} want ${JSON.stringify(want)}`;
  console.log(`${ok ? "  ok  " : "FAIL  "}${name}${detail}`);
};

console.log("boundary =", root);
t("repo file allowed", allowed(root, join(root, "install.sh")), true);
t("not-yet-created repo file allowed", allowed(root, join(root, "does/not/exist.txt")), true);
t("repo root itself allowed", allowed(root, root), true);
t("dotfile outside blocked", allowed(root, join(home, ".bashrc")), false);
t("/etc blocked", allowed(root, "/etc/passwd"), false);
t("sibling dir blocked", allowed(root, join(root, "../other/x.ts")), false);
t("prefix-sibling not confused", allowed(root, `${root}-evil/x`), false);
t("/dev/null allowed", allowed(root, "/dev/null"), true);
t("/tmp allowed", allowed(root, "/tmp/scratch.txt"), true);

console.log("\n-- bash path extraction --");
t("redirect", pathsIn(`echo hi > ${home}/.bashrc`), [`${home}/.bashrc`]);
t("tilde expands", pathsIn("rm -rf ~/.config/hypr"), [join(home, ".config/hypr")]);
t("2>/dev/null", pathsIn("ls foo 2>/dev/null"), ["/dev/null"]);
t("./relative ignored", pathsIn("rm -rf ./build"), []);
t("../relative ignored", pathsIn("cp x ../sibling/y"), []);
t("bare args ignored", pathsIn("cp -r src dst"), []);
t("path after = still found", pathsIn("OUT=/etc/x tee /etc/x"), ["/etc/x", "/etc/x"]);

console.log("\n-- mutating detection --");
t("rm", MUTATING.test("rm -rf /some/path"), true);
t("redirect", MUTATING.test("echo x > /some/path"), true);
t("sed -i", MUTATING.test("sed -i s/a/b/ f"), true);
t("cat is read-only", MUTATING.test("cat /etc/hosts"), false);
t("grep is read-only", MUTATING.test("grep -rn foo /usr/share"), false);
t("2>&1 is not a write", MUTATING.test("ls -la /etc 2>&1"), false);

console.log(fail === 0 ? "\nALL PASS" : `\n${fail} FAILURE(S)`);
process.exit(fail === 0 ? 0 : 1);
