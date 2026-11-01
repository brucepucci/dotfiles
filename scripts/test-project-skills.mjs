// Exercise project-local runbook discovery through Pi's real resource loader.
// HOME is the smoke test's scratch HOME, never the user's skills/settings.
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { PI_PACKAGE_DIR } from "./lib/pi-package-dir.mjs";

if (!existsSync(`${PI_PACKAGE_DIR}/package.json`)) {
	console.log("  ok  project skill discovery skipped: pi not installed here");
	process.exit(0);
}
const { DefaultResourceLoader, SettingsManager } = await import(
	pathToFileURL(`${PI_PACKAGE_DIR}/dist/index.js`).href
);
const source = resolve(process.argv[2]);
const home = resolve(process.argv[3]);
assert.ok(process.env.HOME, "HOME must be set");
assert.equal(resolve(process.env.HOME), home, "run this harness with a disposable HOME");
const skillPath = resolve(source, ".agents/skills/chezmoi-runbook/SKILL.md");
const selected = Object.values(JSON.parse(readFileSync(resolve(source, "pi-skills.json"), "utf8"))).flat();

for (const [label, cwd, trusted, expected] of [
	["repo root", source, true, true],
	["repo subdirectory", resolve(source, "scripts"), true, true],
	["unrelated project", home, true, false],
	["untrusted repo", source, false, false],
]) {
	const loader = new DefaultResourceLoader({
		cwd,
		agentDir: resolve(home, ".pi/agent"),
		settingsManager: SettingsManager.inMemory(),
		noExtensions: true,
		noPromptTemplates: true,
		noThemes: true,
		noContextFiles: true,
	});
	await loader.reload({ resolveProjectTrust: async () => trusted });
	const { skills, diagnostics } = loader.getSkills();
	const matches = skills.filter((skill) => skill.name === "chezmoi-runbook");
	assert.equal(matches.length, expected ? 1 : 0, label);
	if (expected) {
		assert.equal(matches[0].filePath, skillPath, label);
		assert.equal(matches[0].sourceInfo.scope, "project", label);
	}
	for (const name of selected) {
		const global = skills.filter((skill) => skill.name === name);
		assert.equal(global.length, 1, `${label}: global ${name}`);
		assert.equal(global[0].sourceInfo.scope, "user", name);
		assert.equal(global[0].filePath, resolve(home, ".agents/skills", name, "SKILL.md"));
	}
	if (selected.includes("grill-me")) {
		assert.equal(skills.find((skill) => skill.name === "grill-me").disableModelInvocation, true);
	}
	assert.equal(diagnostics.length, 0, `${label}: ${JSON.stringify(diagnostics)}`);
	console.log(`  ok  runbook discovery: ${label}`);
}
