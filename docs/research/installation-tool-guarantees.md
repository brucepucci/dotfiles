# Installation-tool lifecycle guarantees

**Checked: 2026-11-03.** Research for [Establish the lifecycle guarantees available from the existing installation tools](https://github.com/brucepucci/dotfiles/issues/67), supporting [Find a reliable, transferable Mac environment installation architecture](https://github.com/brucepucci/dotfiles/issues/64). This establishes mechanism constraints, not an architecture or new policy. Scope: personal Macs, preservation of unmanaged files/credentials, optional capabilities independent of unrelated work, one guided entry point, and a compatible tested environment rather than indefinitely frozen dependencies.

## Evidence and comparison

Read this checkout's `AGENTS.md`, `README.md`, `Brewfile`, `docs/developing.md`, `docs/pi.md`, lazy bootstrap/lockfile, Treesitter configuration, and skills reconciler. Read the installed Pi **1.4.0** README completely at `/opt/homebrew/Cellar/pi-coding-agent/1.4.0/libexec/lib/node_modules/@earendil-works/pi-coding-agent/README.md`, plus complete lifecycle-relevant linked docs: index, quickstart, CLI, configuration, settings, packages, skills, extensions, prompt templates, themes, security, environment variables, models, and providers. Pi citations use canonical upstream **v1.4.0**, not an assumed latest release. External investigation also read official Homebrew, chezmoi, lazy.nvim, Neovim, Treesitter, and Git docs/source.

**Proven** below means documented or established by the cited implementation, not fault-injection-tested here. **Inference** identifies consequences of those mechanisms. Guarantees not established remain explicit gaps.

| Layer | Established capability | Not established by success alone |
|---|---|---|
| Homebrew / Bundle | Reconcile declarations; skip satisfied entries; install/upgrade; check dependency state | Whole-Brewfile rollback, arbitrary historical restoration, working applications |
| chezmoi | Render/reconcile targets; conflict controls; content-based script history | Cross-file transaction, arbitrary script idempotence, application readiness |
| lazy.nvim / Neovim | Restore plugin revisions; wait for manager tasks; invoke/reinvoke builds | Compiler/parser/ABI compatibility, nested asynchronous completion, reliable aggregate task-failure exit |
| Pi executable | Package-manager-owned runtime; separate managed-installer lifecycle | Installed extensions, usable authentication, compatible extension APIs |
| Pi packages | Install/remove/reconcile sources separately from executable | General package transaction, dependency freeze from a top-level version, safe preservation of edits in managed Git payloads |
| Ordinary skills Git checkout | Clone/fetch/integrate versioned content independently | Idempotent adoption of an occupied directory, installed supporting tools, compliant model behavior |

## Homebrew and Brew Bundle

**Proven:** Bundle describes a desired state. Re-running installs missing formulae and normally upgrades outdated ones; satisfied entries are reused. `--no-upgrade` suppresses upgrade operations, but the manpage warns installation can still upgrade dependencies when needed. It neither pins versions nor creates a lockfile. Homebrew is rolling-release and does not promise arbitrary older versions. Consequently, repeat execution and newer-version selection are separate controls, and an older Brewfile is not a machine rollback snapshot. [Bundle guide][brew-bundle] [Manpage][brew-man]

`brew bundle check` succeeds when its dependency checks are satisfied; default checks include outdated dependencies, while `--no-upgrade` omits that comparison. Current source exits **1** when work remains. Install source counts failures, continues processing other entries/batches, and exits **1** when the aggregate fails. Completed installations remain: this is convergence, not a transaction. No application-level smoke test follows from that aggregate success. [Checker][brew-check] [Installer][brew-install] [Install command][brew-install-command]

**Adoption/destruction:** normal reconciliation need not remove unrelated packages, but `bundle cleanup` explicitly removes packages absent from the selected Brewfile; current documentation also says it reconciles the global trust store, including manually granted trust. Install-time cleanup can be requested through flags/environment. `--force` forwards force/overwrite behavior; `brew link --overwrite` deletes conflicting prefix files. Current Bundle source attempts cask adoption without force. The cask implementation compares bundle versions or contents, except that auto-updating apps can bypass equality comparison. Adoption is therefore not a universal byte-identical/non-destructive import guarantee. [Guide][brew-bundle] [Manpage][brew-man] [Installer][brew-install] [Cask move implementation][brew-cask]

**Prerequisites/concurrency:** current installation docs distinguish supported macOS/hardware, writable prefix ownership, shell/PATH setup, developer tools for source builds, and casks requiring elevation. Do not equate “Mac” with supported bottles or a compiler-ready machine. Homebrew has nonblocking per-path locks and raises an operation-in-progress error on contention; these are not an environment-wide lifecycle lock. [Installation][brew-prereq] [Locks][brew-lock]

## chezmoi

**Proven:** `apply` ensures selected targets match rendered state and prompts when a target changed since its last write. `--less-interactive` additionally prompts for pre-existing/changed targets; `--error-on-conflict` errors instead of prompting; `--force` suppresses prompts. These controls are not a backup service or proof that adopting existing files preserves their contents. `managed`, `unmanaged`, `diff`, and merge operations expose review/adoption mechanisms. [Apply][cm-apply] [Flags][cm-flags] [Usage FAQ][cm-usage]

Unmanaged entries are normally ignored, but `exact_` directories remove unmanaged contents; `remove_`, `.chezmoiremove`, and arbitrary scripts introduce explicit deletion. Preservation depends on declarations and scripts as well as invocation flags. Dry-run does not modify the destination and does not execute scripts; it does not prove script side effects or prerequisite readiness. [Attributes][cm-attributes] [Removal file][cm-remove] [Scripts][cm-scripts] [Flags][cm-flags]

`run_` executes each apply; `run_onchange_` runs when rendered contents differ from the last successful execution; `run_once_` records successful content hashes, even across renames. These are execution-history mechanisms, not probes of installed software. A removed dependency can remain missing when an unchanged successful hook is skipped; an always-run hook still needs its own safe/idempotent operations. Source propagates a script execution error **before** recording success. Earlier effects are not undone; `--keep-going` explicitly permits continuing after errors. [Scripts][cm-scripts] [Script implementation][cm-script-source] [Flags][cm-flags]

Application ordering is deterministic, with before-scripts, target updates, then after-scripts. The documentation explicitly assumes source/destination states do not change during execution and declares violations undefined. Thus concurrently applying, updating the source checkout, or having another application rewrite a managed target cannot be assumed safe merely because individual writes work. No cross-target transaction is promised. [Application order][cm-order]

`verify` returns **0** for target equality and **1** otherwise—not readiness of applications consuming those files. `update` defaults to pulling with `--autostash --rebase` before apply, which differs materially from a conflict-refusing fast-forward-only update; Git warns autostash reapplication can conflict. A Git revert plus apply restores declarations, not historical packages, credentials, or script effects. [Verify][cm-verify] [Update][cm-update] [Git merge options][git-merge]

## Neovim, lazy.nvim, and builds

**Proven:** lazy's lockfile records plugin revisions; `restore` targets them, `update` selects updates and rewrites the lockfile, and `sync` includes clean/install/update. `clean` removes unneeded plugin directories. `!`/`wait=true` waits for the manager operation. These meanings are not interchangeable. Sources checked against this repo's lazy pin `85c7ff…` match the current manager/task implementations. Tracked local plugin edits normally block updating (generated `doc/tags` is an exception), but an origin change can trigger removal/reclone; plugin directories are not a preservation boundary. [lazy usage/lockfile][lazy-doc] [Manager][lazy-manage] [Git tasks][lazy-git]

Build hooks run on installation/update, but task source skips a build unless marked dirty/needing build; explicit `build` forces it. Re-running restore at an unchanged revision is therefore not a general “repair every generated artifact” guarantee. Shell builders, Lua functions, and editor commands have different completion semantics. Builds run concurrently; official guidance forbids changing process cwd inside a build function because it affects siblings. No reviewed contract establishes safe simultaneous independent Neovim installers sharing one plugin tree. [Build task][lazy-build] [Developer/build documentation][lazy-doc]

Failure reporting requires care. Task source records errors as task log levels and prints headless output; it does not generally turn those records into a thrown editor error or process exit. The bang promises waiting, not aggregate success. Neovim documents exit **1** for editor errors or `:cquit`, and `-l` exits **1** on Lua error; caught/logged failures need not reach those paths. `:checkhealth` invokes implemented health checks and produces a report; it is not documented as a universal exit-code readiness API. **Constraint:** a trustworthy readiness result needs explicit task/build postconditions and feature checks, not merely `nvim … +qa` returning zero. [Task implementation][lazy-task] [Neovim startup/exit][nvim-start] [Health][nvim-health]

The pinned Treesitter README requires Neovim **0.12+**, tree-sitter CLI **0.26.1+**, `tar`, `curl`, and a C compiler. It guarantees only specific parser versions, requires parser updates with plugin updates, and documents asynchronous installation requiring `:wait()` in bootstrap scripts. Waiting for lazy's `:TSUpdate` invocation does not independently establish completion of asynchronously spawned work. Locally, the missing-parser path waits but catches wait errors with `pcall`; installed parser/query functionality remains a separate postcondition. A locked plugin revision is not a locked compiler, parser artifact, or compatible editor environment. [Pinned Treesitter README][ts-readme] [Local configuration](../../private_dot_config/nvim/lua/bruce/plugins/treesitter.lua)

## Pi executable versus Pi packages

**Proven:** the current Homebrew formula wraps the **1.4.0 npm payload** in its keg, depends on Node, and checks version output plus one expected provider failure. “Binary” here describes the executable lifecycle, not necessarily a standalone native executable. Pi's README requires Node **22.19+**, distinguishes its dependency-pinned managed installer from ordinary global npm installation without pinned transitives, and says normal host npm installation needs no lifecycle scripts. That last statement does **not** promise arbitrary extension installers are script-free. [Formula][pi-formula] [Pi README][pi-readme]

The managed installer has stronger, narrowly scoped update mechanics: source locks updates, stages `npm ci --ignore-scripts`, verifies version output, renames the staged release, then switches a current-version file by rename. It retains the active/running releases for rollback. These mechanisms do not apply to the Homebrew keg or make packages/settings/authentication transactional. Package-manager-owned installs must update through their owner; this repository's shell wrapper separately enforces that boundary. [Self-update source][pi-cli-source] [CLI docs][pi-cli] [Local lifecycle docs](../pi.md)

Packages have their own declarations, payloads, scopes, and updates. Exact npm versions are skipped by package updates; source treats ranges differently and can select newer matching releases. Git updates reconcile the configured ref; a named ref is not an immutable content hash. Unpinned package updates select newer inputs, unlike re-running a configuration renderer. Local package paths load without copying or installing dependencies. [Packages][pi-packages] [Package manager][pi-pm]

**Important local documentation mismatch:** `docs/pi.md` says missing user-scope packages never auto-install. In **1.4.0**, the default resource loader calls `packageManager.resolve()` without a missing-source callback; the resolver installs missing/mismatched packages in either user or trusted project scope unless offline. This was checked in both tagged upstream source and installed JS. Rendering settings alone still installs nothing, but subsequent Pi startup/reload can cause networked installation. This is source-established, not a fresh-machine execution test. [Resource loader][pi-resources] [Resolver][pi-pm]

Package command exceptions set exit status **1**. Offline package updates can return without work, so success need not mean remote versions were checked. Updates can mutate multiple sources concurrently; no cross-package rollback or cross-process extension-install lock was established. Git-managed payload reconciliation can `reset --hard` and `clean -fdx`; incomplete-update markers support retrying dependency installation, not preservation of local edits. Ordinary editable skills checkouts must not be confused with these disposable package payloads. [Package CLI][pi-cli-source] [Package manager][pi-pm]

Readiness separates executable version, declared/installed packages, successful extension loading, skill discovery, and provider access. `pi list` lists configured packages, not a functional extension test. Extensions run with process permissions, errors may be reported while Pi continues, and project resources require trust. Malformed/descriptionless skills are skipped; collisions keep the first with warnings. `auth check` documents **0/1/2** for ready/not-ready/invalid, but refreshes OAuth by default; `--no-refresh` avoids that refresh and credential-printing flags expose secrets. Credential readiness is not proof a selected model accepts a real request. [CLI][pi-cli] [Extensions][pi-extensions] [Skills][pi-skills] [Security][pi-security]

## Ordinary Git skills checkouts

**Proven:** clone accepts an existing destination only when empty; “directory exists” neither establishes repository identity nor safely adopts it. Fetch updates remote-tracking information; pull additionally integrates it. Explicit `--ff-only` refuses divergence rather than merging/rebasing. This supports repeatable advancement of an appropriate checkout, not unconditional success on arbitrary dirty/forked state. [Clone][git-clone] [Pull][git-pull]

`reset --hard` discards tracked changes and can overwrite obstructing untracked files; `clean -fdx` removes untracked/ignored content. They are not preservation-oriented recovery defaults. Clone documentation also warns local clones can race with source modifications. No whole-worktree concurrency/readiness guarantee follows from Git's per-operation behavior. [Reset][git-reset] [Clean][git-clean] [Clone][git-clone]

Here, selection/link validation belongs to `scripts/pi-skills.py`, not Git. It validates before mutation and preserves unrelated names, but sequential unlink/symlink calls are not transactional or locked. A valid checkout/manifest proves neither Pi-compatible instructions nor supporting executable availability. Pi itself warns the model may fail to invoke a relevant skill. [Local reconciler](../../scripts/pi-skills.py) [Skills][pi-skills]

## Decision constraints and remaining gaps

**Implications, not selected policy:** one guided entry point cannot truthfully promise one atomic operation across these owners. It must distinguish current state, attempted changes, partial failure, deferred/optional work, and verified capability. Retry logic cannot substitute for version-selection policy. Readiness must name its scope and observable postconditions. Preservation requires reviewable ownership boundaries and explicit handling of conflicts/deletion. Compatible tested environments require runtime/toolchain/feature evidence alongside pinned inputs; credentials remain outside transferable configuration.

**Unverified:** interruption/power-loss recovery across owners; full fresh/existing-Mac adoption; exact plugin/build failure-to-exit behavior across all hooks; simultaneous installers; extension compatibility with future Pi/Node; GUI/cask permission paths; provider/model availability. Source-level repair markers and staging do not prove durability under every crash. No reviewed primary contract supplies an all-tools transaction, automatic restoration of unmanaged data, or a compatibility guarantee for the combined environment. These need bounded experiments/acceptance criteria, not stronger wording in an installer.

[brew-bundle]: https://docs.brew.sh/Brew-Bundle-and-Brewfile
[brew-man]: https://docs.brew.sh/Manpage#bundle-subcommand
[brew-prereq]: https://docs.brew.sh/Installation
[brew-check]: https://github.com/Homebrew/brew/blob/053b4507ed270e66b3c92126b3253eb6bb322c5f/Library/Homebrew/bundle/subcommand/check.rb
[brew-install]: https://github.com/Homebrew/brew/blob/053b4507ed270e66b3c92126b3253eb6bb322c5f/Library/Homebrew/bundle/installer.rb
[brew-install-command]: https://github.com/Homebrew/brew/blob/053b4507ed270e66b3c92126b3253eb6bb322c5f/Library/Homebrew/bundle/subcommand/install.rb
[brew-cask]: https://github.com/Homebrew/brew/blob/053b4507ed270e66b3c92126b3253eb6bb322c5f/Library/Homebrew/cask/artifact/moved.rb
[brew-lock]: https://github.com/Homebrew/brew/blob/053b4507ed270e66b3c92126b3253eb6bb322c5f/Library/Homebrew/lock_file.rb
[cm-apply]: https://www.chezmoi.io/reference/commands/apply/
[cm-flags]: https://www.chezmoi.io/reference/command-line-flags/global/
[cm-usage]: https://www.chezmoi.io/user-guide/frequently-asked-questions/usage/
[cm-attributes]: https://www.chezmoi.io/reference/source-state-attributes/
[cm-remove]: https://www.chezmoi.io/reference/special-files/chezmoiremove/
[cm-scripts]: https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/
[cm-script-source]: https://github.com/twpayne/chezmoi/blob/a7bf9bafe9b63d3e6196060b79177a6c7bdab333/internal/chezmoi/targetstateentry.go#L340-L390
[cm-order]: https://www.chezmoi.io/reference/application-order/
[cm-verify]: https://www.chezmoi.io/reference/commands/verify/
[cm-update]: https://www.chezmoi.io/reference/commands/update/
[lazy-doc]: https://github.com/folke/lazy.nvim/blob/85c7ff3711b730b4030d03144f6db6375044ae82/doc/lazy.nvim.txt
[lazy-manage]: https://github.com/folke/lazy.nvim/blob/85c7ff3711b730b4030d03144f6db6375044ae82/lua/lazy/manage/init.lua
[lazy-build]: https://github.com/folke/lazy.nvim/blob/85c7ff3711b730b4030d03144f6db6375044ae82/lua/lazy/manage/task/plugin.lua
[lazy-git]: https://github.com/folke/lazy.nvim/blob/85c7ff3711b730b4030d03144f6db6375044ae82/lua/lazy/manage/task/git.lua
[lazy-task]: https://github.com/folke/lazy.nvim/blob/85c7ff3711b730b4030d03144f6db6375044ae82/lua/lazy/manage/task/init.lua
[nvim-start]: https://neovim.io/doc/user/starting.html
[nvim-health]: https://neovim.io/doc/user/health.html
[ts-readme]: https://github.com/nvim-treesitter/nvim-treesitter/blob/8b98b4470eb326f1c7b50dae79f8c963568e5720/README.md
[pi-formula]: https://github.com/Homebrew/homebrew-core/blob/932900249314fc4d2613aa030431b347ca5efc48/Formula/p/pi-coding-agent.rb
[pi-readme]: https://github.com/earendil-works/pi/blob/v1.4.0/packages/coding-agent/README.md
[pi-cli-source]: https://github.com/earendil-works/pi/blob/v1.4.0/packages/coding-agent/src/package-manager-cli.ts
[pi-cli]: https://github.com/earendil-works/pi/blob/v1.4.0/packages/coding-agent/docs/cli.md
[pi-packages]: https://github.com/earendil-works/pi/blob/v1.4.0/packages/coding-agent/docs/packages.md
[pi-pm]: https://github.com/earendil-works/pi/blob/v1.4.0/packages/coding-agent/src/core/package-manager.ts
[pi-resources]: https://github.com/earendil-works/pi/blob/v1.4.0/packages/coding-agent/src/core/resource-loader.ts
[pi-extensions]: https://github.com/earendil-works/pi/blob/v1.4.0/packages/coding-agent/docs/extensions.md
[pi-skills]: https://github.com/earendil-works/pi/blob/v1.4.0/packages/coding-agent/docs/skills.md
[pi-security]: https://github.com/earendil-works/pi/blob/v1.4.0/packages/coding-agent/docs/security.md
[git-clone]: https://github.com/git/git/blob/HEAD/Documentation/git-clone.adoc
[git-pull]: https://github.com/git/git/blob/HEAD/Documentation/git-pull.adoc
[git-reset]: https://github.com/git/git/blob/HEAD/Documentation/git-reset.adoc
[git-clean]: https://github.com/git/git/blob/HEAD/Documentation/git-clean.adoc
[git-merge]: https://github.com/git/git/blob/HEAD/Documentation/merge-options.adoc
