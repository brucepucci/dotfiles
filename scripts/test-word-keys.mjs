// Exercise Herdr's configured bytes against Pi's real keybinding resolver.
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { PI_PACKAGE_DIR } from "./lib/pi-package-dir.mjs";

const modulePath = join(PI_PACKAGE_DIR, "dist/core/keybindings.js");
if (!existsSync(modulePath)) {
  console.log("SKIP: Pi not installed; interactive word-key routing not checked");
  process.exit(0);
}
const home = process.argv[2];
assert.ok(home, "usage: node scripts/test-word-keys.mjs DESTINATION_HOME");
const { KeybindingsManager } = await import(pathToFileURL(modulePath).href);
const agentDir = join(home, ".pi/agent");
const bindings = JSON.parse(readFileSync(join(home, ".config/herdr-app/keys.json"), "utf8")).terminal;
const kb = KeybindingsManager.create(agentDir);
const cases = [
  ["alt-left", "tui.editor.cursorWordLeft"],
  ["alt-right", "tui.editor.cursorWordRight"],
  ["alt-backspace", "tui.editor.deleteWordBackward"],
  ["alt-shift-backspace", "tui.editor.deleteWordForward"],
];
for (const [key, action] of cases) {
  assert.ok(bindings[key]?.startsWith("send:"), `${key}: missing terminal send`);
  assert.ok(kb.matches(bindings[key].slice(5), action), `${key} does not invoke ${action}`);
}
assert.equal(kb.matches("\x17", "tui.editor.cursorWordRight"), false, "Ctrl+W must not move right");
console.log("PASS: all four Herdr word keys resolve to the intended Pi actions");
