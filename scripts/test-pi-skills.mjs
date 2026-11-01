// Exercise the real apply adapter with a fake upstream CLI, never the network.
import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { installSkills } from "./install-pi-skills.mjs";

assert.ok(process.env.DOTFILES_SKILLS_TEST_LOG, "run through smoke-test.sh's offline npx shim");
const work = mkdtempSync(join(tmpdir(), "pi-skills-test-"));
const home = join(work, "home with spaces");
mkdirSync(home);
const log = join(work, "calls.jsonl");
const previousLog = process.env.DOTFILES_SKILLS_TEST_LOG;
process.env.DOTFILES_SKILLS_TEST_LOG = log;
const selection = { "example/first": ["one", "two"], "example/second": ["three"] };
const lockPath = join(home, ".agents/.skill-lock.json");
const skillPath = (name) => join(home, ".agents/skills", name, "SKILL.md");
const calls = () => existsSync(log) ? readFileSync(log, "utf8").trim().split("\n").map(JSON.parse) : [];
const readLock = () => JSON.parse(readFileSync(lockPath, "utf8"));
const saveLock = (lock) => writeFileSync(lockPath, JSON.stringify(lock));
try {
	installSkills(selection, home);
	assert.deepEqual(calls().map(({ source, names }) => [source, names]), Object.entries(selection));
	for (const call of calls()) {
		assert.equal(call.home, home);
		assert.equal(call.cwd, realpathSync(home));
	}

	// No npx call (nor content reset) for an unchanged selection, even after a
	// user's explicit update or edits to the installed content/hash.
	writeFileSync(skillPath("one"), "user-updated skill content\n");
	const updated = readLock();
	updated.skills.one.skillFolderHash = "new-upstream-hash";
	saveLock(updated);
	process.env.FAKE_SKILLS_FAIL = "1";
	installSkills(selection, home);
	assert.equal(calls().length, 2);
	assert.equal(readFileSync(skillPath("one"), "utf8"), "user-updated skill content\n");
	delete process.env.FAKE_SKILLS_FAIL;

	rmSync(skillPath("two"));
	installSkills(selection, home);
	assert.deepEqual(calls().at(-1).names, ["two"]);
	assert.equal(calls().length, 3);

	installSkills({ ...selection, "example/first": ["one", "two", "four"] }, home);
	assert.deepEqual(calls().at(-1).names, ["four"]);
	assert.equal(calls().length, 4);

	// Changing a selected source reinstalls just that skill.
	installSkills({ "example/replacement": ["one"], "example/first": ["two"] }, home);
	assert.deepEqual(calls().at(-1).names, ["one"]);
	assert.equal(readLock().skills.one.source, "example/replacement");
	assert.equal(calls().length, 5);
	assert.ok(existsSync(skillPath("three")), "removed selections stay installed");
	assert.ok(existsSync(skillPath("four")), "unrelated skills stay installed");

	// Missing registration is repaired even when the directory exists.
	const unregistered = readLock();
	delete unregistered.skills.two;
	saveLock(unregistered);
	installSkills({ "example/first": ["two"] }, home);
	assert.deepEqual(calls().at(-1).names, ["two"]);

	const count = calls().length;
	for (const invalid of [null, [], { "../bad": ["safe"] },
		{ "example/first": ["../escape"] }, { "example/first": "one" },
		{ "example/first": ["one"], "example/second": ["one"] }]) {
		assert.throws(() => installSkills(invalid, home));
	}
	assert.equal(calls().length, count, "validate everything before invoking npx");

	process.env.FAKE_SKILLS_FAIL = "1";
	assert.throws(() => installSkills({ "example/first": ["failure"] }, home), /installer failed/);
	delete process.env.FAKE_SKILLS_FAIL;
	process.env.FAKE_SKILLS_INCOMPLETE = "1";
	assert.throws(() => installSkills({ "example/first": ["incomplete"] }, home), /did not register/);
	delete process.env.FAKE_SKILLS_INCOMPLETE;
	installSkills({ "example/first": ["failure", "incomplete"] }, home);
	assert.ok(existsSync(skillPath("failure")), "a later apply retries failures");

	const countBeforeBadLock = calls().length;
	writeFileSync(lockPath, "not JSON");
	assert.throws(() => installSkills(selection, home), SyntaxError);
	for (const invalidLock of ['{"version":999,"skills":{}}', '{"version":3,"skills":[]}', 'null']) {
		writeFileSync(lockPath, invalidLock);
		assert.throws(() => installSkills(selection, home), /unsupported skills lock format/);
	}
	assert.equal(calls().length, countBeforeBadLock, "bad lock must not invoke npx");
	// Exercise the real selection's migration from mixed upstream/fork sources.
	// A source change must move every remaining engineering skill to the fork,
	// without reinstalling the already-forked review or Vercel's skill.
	const selected = JSON.parse(readFileSync(new URL("../pi-skills.json", import.meta.url), "utf8"));
	assert.deepEqual(Object.keys(selected).sort(), ["brucepucci/skills", "vercel-labs/skills"]);
	assert.ok(selected["brucepucci/skills"].includes("code-review"));
	assert.deepEqual(selected["vercel-labs/skills"], ["find-skills"]);
	const migrationHome = join(work, "migration home");
	mkdirSync(migrationHome);
	const migrationLog = join(work, "migration-calls.jsonl");
	process.env.DOTFILES_SKILLS_TEST_LOG = migrationLog;
	const migrating = selected["brucepucci/skills"].filter((name) => name !== "code-review");
	installSkills({
		"mattpocock/skills": migrating,
		"brucepucci/skills": ["code-review"],
		"vercel-labs/skills": selected["vercel-labs/skills"],
	}, migrationHome);
	const migrationSkillPath = (name) => join(migrationHome, ".agents/skills", name, "SKILL.md");
	for (const name of ["code-review", ...selected["vercel-labs/skills"]]) {
		writeFileSync(migrationSkillPath(name), "already installed from selected source\n");
	}
	const migrationCalls = () => readFileSync(migrationLog, "utf8").trim().split("\n").map(JSON.parse);
	const beforeMigration = migrationCalls().length;
	installSkills(selected, migrationHome);
	assert.deepEqual(migrationCalls().slice(beforeMigration).map(({ source, names }) => [source, names]),
		[["brucepucci/skills", migrating]]);
	const migratedLock = JSON.parse(readFileSync(join(migrationHome, ".agents/.skill-lock.json"), "utf8"));
	for (const [source, names] of Object.entries(selected)) {
		for (const name of names) assert.equal(migratedLock.skills[name].source, source);
	}
	for (const name of ["code-review", ...selected["vercel-labs/skills"]]) {
		assert.equal(readFileSync(migrationSkillPath(name), "utf8"), "already installed from selected source\n");
	}
	process.env.FAKE_SKILLS_FAIL = "1";
	installSkills(selected, migrationHome);
	assert.equal(migrationCalls().length, beforeMigration + 1, "repeat apply must not refresh migrated skills");
	delete process.env.FAKE_SKILLS_FAIL;
	console.log("  ok  selected skills: fresh install, no-op, repair, source changes, fork migration, preservation and failures");
} finally {
	process.env.DOTFILES_SKILLS_TEST_LOG = previousLog;
	delete process.env.FAKE_SKILLS_FAIL;
	delete process.env.FAKE_SKILLS_INCOMPLETE;
	rmSync(work, { recursive: true, force: true });
}
