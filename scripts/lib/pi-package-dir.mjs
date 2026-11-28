import { execFileSync } from "node:child_process";
import { join } from "node:path";

// The Brewfile installs Pi into Homebrew's libexec on both platforms.
// `brew --prefix` finds the stable opt path; overrides support other installs.
export const PI_PACKAGE_DIR = process.env.PI_PACKAGE_DIR ?? join(
	execFileSync("brew", ["--prefix", "pi-coding-agent"], { encoding: "utf8" }).trim(),
	"libexec/lib/node_modules/@earendil-works/pi-coding-agent",
);
