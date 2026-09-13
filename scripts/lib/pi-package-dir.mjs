// Default pi-package location for the unit harnesses: the Brewfile
// installs pi from homebrew/core, which keeps the npm package in the
// keg's libexec. Go through opt/ rather than Cellar/<version>/ so the
// path survives upgrades; PI_PACKAGE_DIR overrides for non-standard
// installs.
export const PI_PACKAGE_DIR =
	process.env.PI_PACKAGE_DIR ??
	"/opt/homebrew/opt/pi-coding-agent/libexec/lib/node_modules/@earendil-works/pi-coding-agent";
