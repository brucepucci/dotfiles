// Invoked by the chezmoi apply script, not a skill downloader or updater.
// The upstream CLI owns skill content and ~/.agents/.skill-lock.json.
import { readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

function readLock(home) {
	try {
		const lock = JSON.parse(readFileSync(join(home, ".agents/.skill-lock.json"), "utf8"));
		if (!lock || lock.version !== 3 || !lock.skills
			|| typeof lock.skills !== "object" || Array.isArray(lock.skills)) {
			throw new Error("unsupported skills lock format; review the installer integration");
		}
		// Check every registration before installing anything. Only validate the
		// identity fields we consume; other providers and CLI metadata stay opaque.
		for (const [name, entry] of Object.entries(lock.skills)) {
			if (!entry || typeof entry !== "object" || Array.isArray(entry)
				|| typeof entry.source !== "string" || !entry.source
				|| typeof entry.sourceType !== "string" || !entry.sourceType
				|| (entry.ref !== undefined && typeof entry.ref !== "string")) {
				throw new Error(`invalid skills lock entry: ${name}`);
			}
		}
		return lock.skills;
	} catch (error) {
		if (error.code === "ENOENT") return {};
		throw error;
	}
}

function isInstalled(home, lock, source, name) {
	const entry = lock[name];
	if (entry?.source !== source || entry.sourceType !== "github" || entry.ref) return false;
	try {
		return statSync(join(home, ".agents/skills", name, "SKILL.md")).isFile();
	} catch (error) {
		if (error.code === "ENOENT") return false;
		throw error;
	}
}

export function installSkills(selection, home) {
	// Validate the whole selection before any installer can change the destination.
	if (!selection || Array.isArray(selection) || typeof selection !== "object") {
		throw new Error("pi-skills.json must map GitHub repositories to skill-name arrays");
	}
	const seen = new Set();
	for (const [source, names] of Object.entries(selection)) {
		if (!/^[a-zA-Z0-9][a-zA-Z0-9_.-]*\/[a-zA-Z0-9][a-zA-Z0-9_.-]*$/.test(source)
			|| !Array.isArray(names)) throw new Error(`invalid skill source: ${source}`);
		for (const name of names) {
			if (typeof name !== "string" || name.length > 64
				|| !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(name) || seen.has(name)) {
				throw new Error(`invalid or duplicate skill name: ${name}`);
			}
			seen.add(name);
		}
	}

	let lock = readLock(home);
	for (const [source, names] of Object.entries(selection)) {
		const missing = names.filter((name) => !isInstalled(home, lock, source, name));
		if (!missing.length) continue;
		console.log(`Installing selected Pi skills from ${source}: ${missing.join(", ")}`);
		const result = spawnSync("npx", [
			"--yes", "skills@latest", "add", source,
			"--agent", "pi", "--global", "--skill", ...missing, "--yes",
		], { cwd: home, env: { ...process.env, HOME: home }, stdio: "inherit" });
		if (result.error) throw result.error;
		if (result.status !== 0) throw new Error(`skills installer failed for ${source} (${result.status ?? result.signal})`);
		lock = readLock(home);
		for (const name of missing) {
			if (!isInstalled(home, lock, source, name)) {
				throw new Error(`skills installer did not register ${source}: ${name}`);
			}
		}
	}
}
