// Offline stand-in for npx, shared by the apply and installer tests.
import assert from "node:assert/strict";
import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const args = process.argv.slice(2);
assert.ok(process.env.DOTFILES_SKILLS_TEST_LOG, "fake installer requires a test log");
assert.equal(args[0], "--yes");
assert.equal(args[1], "skills@latest");
assert.equal(args[2], "add");
assert.deepEqual(args.slice(4, 8), ["--agent", "pi", "--global", "--skill"]);
assert.equal(args.at(-1), "--yes");
const source = args[3];
const names = args.slice(8, -1);
appendFileSync(process.env.DOTFILES_SKILLS_TEST_LOG,
	`${JSON.stringify({ source, names, home: process.env.HOME, cwd: process.cwd() })}\n`);
if (process.env.FAKE_SKILLS_FAIL) process.exit(42);
if (process.env.FAKE_SKILLS_INCOMPLETE) process.exit(0);
const root = join(process.env.HOME, ".agents");
let lock = { version: 3, skills: {} };
try {
	lock = JSON.parse(readFileSync(join(root, ".skill-lock.json"), "utf8"));
} catch (error) {
	if (error.code !== "ENOENT") throw error;
}
for (const name of names) {
	const dir = join(root, "skills", name);
	mkdirSync(dir, { recursive: true });
	writeFileSync(join(dir, "SKILL.md"),
		`---\nname: ${name}\ndescription: Offline test fixture for ${name}.\n${name === "grill-me" ? "disable-model-invocation: true\n" : ""}---\n\nUnmodified fixture.\n`);
	lock.skills[name] = { source, sourceType: "github", skillFolderHash: "test-hash" };
}
writeFileSync(join(root, ".skill-lock.json"), JSON.stringify(lock));
