# Dotfiles Audit — Open Findings

## Review 2026-11-04 (open)

Reproduced in scratch repos, Ubuntu 24.04 arm64 containers and a scratch `HOME` on macOS, unless marked otherwise. No fresh Mac was available.

### P0 — Data loss

- [x] **`gcleanlocal` deletes `main` and `develop`**
  `home/private_dot_config/zsh/dot_zshrc:97` only filters `* main`. On any other branch `main` passes the filter.
  Done: function based on `for-each-ref`, keeps `main`, `master` and `develop`.

- [x] **`gcleanremote` passes commit subjects to `git branch -d`**
  `home/private_dot_config/zsh/dot_zshrc:96` — `$1` in double quotes expands when the alias is defined, so awk prints the whole line. A branch name in a commit subject deletes that branch.
  Done: function based on `for-each-ref`, matches `[gone]` only.

### P1 — Setup breaks

- [x] **Deprecated taps abort `brew bundle` on a fresh install**
  `tap "homebrew/bundle"` and `tap "homebrew/services"`: `brew tap` and `brew bundle` exit 1 on Homebrew 7. Machines that already have the taps don't notice. `tap "1password/tap"` is unused, both casks come from `homebrew/cask`.
  Done: all three removed.

- [x] **LazyVim fails on a fresh install: `No specs found for module "plugins"`**
  Regression from `056f06a`: `lua/plugins/` is gone, `{ import = "plugins" }` in `lua/config/lazy.lua` is not. Deployed machines keep the old file because `nvim/` is not `exact_`.
  Done: import removed. Add it back together with the first plugin file.

- [x] **asdf script installs into `~/.asdf` on a fresh machine**
  A fresh apply has no `ASDF_DATA_DIR` in its environment, `zshenv` expects `~/.local/share/asdf`.
  Done: the script exports both variables.

- [x] **Not usable on Linux**
  `chezmoi apply` exits 127 (asdf, VS Code scripts assume brew). Fonts land in `~/Library/Fonts`. Every new shell prints errors from `fzf.zsh`. `ls` and `vim` point to missing binaries. `git commit` fails on mandatory signing. `load-k8s-configs.sh` caches 6 lines of `stat -f` output. 
  Done: minimal profile for servers and containers, no Linuxbrew, no commit signing. Skips the `nvim` config (LazyVim needs Neovim 0.11.2, apt ships 0.9.5) and the Withings script, defers prezto until git and zsh exist. asdf is opt-in: once the binary exists, apply adds the plugins, `~/.tool-versions` is not deployed, so runtimes stay a per-host choice. Prerequisites are in the README.

### P2 — Controls that don't do what they claim

- [x] **Firewall block is dead on macOS 15+**
  `macos-settings` wrote `com.apple.alf`. Reports since macOS 15 say this no longer takes effect, and the plist doesn't exist on 27.2 while the firewall reports its state fine.
  Done: `run_onchange_after_macos-security.sh.tmpl` uses `socketfilterfw`, stealth mode included.

- [x] **Screen lock keys are unreliable since macOS 10.13**
  `macos-settings` wrote `askForPassword` and `askForPasswordDelay`. Sources are old and mixed, so the write can't be trusted.
  Done: the security script reads `sysadminctl -screenLock status` and only sets it when needed, which prompts for the login password. That write path has not run on a real change, this Mac is already immediate.

- [x] **TouchID patches `/etc/pam.d/sudo`, which OS updates reset**
  `run_once` didn't restore it after an update.
  Done: the security script writes `/etc/pam.d/sudo_local` and removes the old line from `sudo`.

- [x] **Login window text points to an undeliverable address**
  `run_onchange_after_macos-settings.sh.tmpl:28` rendered the GitHub noreply address and overwrote any working text on re-run.
  Done: `.lostcontact` lives in the local config only, prefilled from the address the Mac already shows. Empty leaves the text alone.

- [x] **Withings: credentials persist in a kept container**
  `executable_sync-withings-garmin.sh:50-60`. No `--rm`, and `docker start` reuses containers created before the env var change, with the password in their args. Also: `:master` is a mutable tag on a third-party image that receives credentials, and `DATA_DIR` is created with default permissions.
  Done: `--rm`, old containers are removed on the next run, image pinned by digest, `DATA_DIR` is 0700. Fetches credentials from 1Password on every run.

- [x] **Version guard is inert**
  `.chezmoiversion` at the repo root is not read once the config sets `sourceDir` to `home/`. Moved to `home/`.

### P3 — Input handling

- [x] **Init prompts accept anything**
  `home/.chezmoi.toml.tmpl`: `ja` for `installmas` silently means no. `$(...)` in `.name` executes in the rendered macOS script, `#` truncates `user.name` in git config.
  Done: `promptChoice` for `installmas`, `name` and `email` are validated, git config values are quoted.

- [x] **`--fromdate` is silently ignored once state exists**
  `executable_sync-withings-garmin.sh`.
  Done: every run starts a new container, so it always applies. The format is validated.

- [x] **`kfn` clears the namespace when fzf is cancelled**
  `dot_zshrc`.
  Done: `kfc` and `kfn` are functions that do nothing on an empty selection. Tested with stubs, `kubectl` is not installed here.

- [x] **`mvn` alias requires a `settings.xml` this repo doesn't ship**
  Done: alias only exists when the file does.

- [x] **`chezmoi add` of a secret only warns by default**
  Default adds the file and prints a warning.
  Done: `[add] secrets = "error"` in `home/.chezmoi.toml.tmpl`, tested to block a GitHub token. Best effort only: a fake AWS key and a low-entropy token passed. Override a false positive with `chezmoi add --secrets=ignore`.

### P4 — Hardening and drift

- [x] **Re-runs have side effects**
  Any edit to `macos-settings` wiped the Dock. Any edit to `00-macos-init` ran `softwareupdate --install --all` in the `before` phase, where a failure blocks deployment.
  Done: the Dock wipe is in `run_once_after_30-macos-dock.sh.tmpl`. `00-macos-init` only has checked steps left and lists updates instead of installing them.

- [x] **`PATH` order differs between login and non-login shells**
  Login shells: `path_helper` and prezto's `zprofile` move system and brew paths in front of the `zshenv` entries, so `python3` is brew's, not `.tool-versions`. Non-login children such as zellij panes skip both, so `~/.local/bin` and the shims come first. The same command can resolve differently per pane. Set one order for both at the end of `.zshrc`, with the shims in front of brew and `~/.local/bin` behind system paths.
  Done: `zshenv` and `.zshrc` set shims, brew, system, user dirs. `zsh -lc` reads no `.zshrc`, so the shims stay behind brew there.

- [ ] **Unpinned code from third parties**
  Prezto clone (unpinned on install, then never updated), font externals (`raw/master`, no `checksum.sha256`), asdf plugins. The Withings image is pinned to the 2025-08 build: update it on purpose, newer builds change the Garmin session format.

- [x] **No checks on a public repo**
  Done: `.github/workflows/ci.yml` with gitleaks, shellcheck on rendered scripts, `zsh -n` and the Linux smoke test.

- [ ] **CI only finds a secret after it is public**
  It runs after the push. Enable GitHub secret scanning with push protection in the repo settings, or add a local pre-commit hook with gitleaks.

- [ ] **`lazy-lock.json` is managed but rewritten by lazy.nvim**
  After a plugin restore `chezmoi apply` prompts, and fails without a TTY. Symlink it to the source file or ignore it.

- [x] **README one-liner applies without preview, and a new Mac has no brew**
  `init --apply` ran sudo, PAM and update steps unseen. Without Homebrew the first apply stopped at `brew: command not found`.
  Done: `bootstrap.sh` sets up a new Mac, where nothing can be overwritten. The README documents `init`, `diff`, `apply` for other machines. Idea from the unmerged `cleanup-mac-setup` branch, which also dropped the Rosetta step.

- [ ] **The setup never ran on a fresh Mac**
  `bootstrap.sh` is tested with stubs only. Expected stops: Full Disk Access in `macos-settings`, and an App Store without sign-in, which may abort the `before` phase. Run it once on the Mac mini, then delete the `cleanup-mac-setup` branch.

- [x] **asdf plugin hooks slow down every prompt**
  `set-env.zsh` and `set-java-home.zsh` spawn `asdf` and `dirname` in `precmd`, about 200 ms per prompt.
  Done: `.zshrc` sets the same variables at startup and on `cd`. Other startup tweaks (`zcompile`, skipping `/etc/zprofile`, `.hushlogin`, fewer prompt segments) brought nothing measurable.

- [ ] **Ghostty over SSH to Linux**
  `TERM=xterm-ghostty` is usually unknown on servers. Set `shell-integration-features = ssh-env` in the Ghostty config. Default is off in 1.4.0, not tested against a server.

- [ ] **Smaller items**
  `HOMEBREW_NO_ANALYTICS=1`. `transfer.fsckObjects = true` (old repos may fail). `script_sudo` keeps sudo open for every cask post-install and lingers up to 60s. `defaultKeyCommand` takes the first ECDSA key without checking `allowed_signers`. `_cached_eval` never invalidates. `brew bundle` list has drifted from installed casks (e.g. `zed`). `~/.config/homebrew/trust.json` is not managed, so `brew cu` should need `brew trust --command buo/cask-upgrade/cu` on a new Mac (from Homebrew's source, not tested on one).
## Review 2026-05-13

Ordered by severity.

## P1 — Runtime bugs (blocking or silently breaking)

- [x] **asdf plugins don't match `.tool-versions`**
  `home/.chezmoiscripts/run_once_after_20-install-asdf-plugins.sh.tmpl` only adds `nodejs` and `java`, but `home/dot_tool-versions` also lists `python` and `golang`. Fresh `asdf install` aborts on first missing plugin.
  Done in `4e3d1f5`: python, golang and bun plugins added.

- [x] **`gcleanremote` / `gcleanlocal` use `xargs -r` (GNU-only)**
  `home/private_dot_config/zsh/dot_zshrc:72-73` — BSD `xargs` on macOS doesn't support `-r`. Either install + PATH `coreutils` (`gxargs`) or rewrite without `-r` (guard with `[ -n "$input" ]`).
  No change needed: macOS `xargs` accepts `-r` and already skips empty input (verified 2026-10-31).

- [x] **`load-k8s-configs.sh`: broken `find` + unsafe parsing**
  `home/dot_local/bin/executable_load-k8s-configs.sh:16` — `-type f -name "*.yml" -o -name "*.yaml"` lacks `\( ... \)`, so `-type f` only binds to `*.yml`. Replace `for f in \`find ...\`` with `find ... -print0 | while IFS= read -r -d ''`.
  Done: `find` grouping fixed in `bd47e31`; loop now uses `find -print0 | read -d ''` (works in zsh and bash).

- [x] **Secrets passed via cmdline (visible to `ps`)**
  `home/dot_local/bin/executable_sync-withings-garmin.sh:45-50` — Garmin user/password as `--garmin-username=…`/`--garmin-password=…`. Use `--env-file`, `-e` env vars, or stdin.
  Done: credentials passed as `-e GARMIN_USERNAME -e GARMIN_PASSWORD` (name only). Still visible via `docker inspect`, as before.

- [x] **Shebang not on line 1 after template renders**
  `home/.chezmoiscripts/run_onchange_after_setup-editor.sh.tmpl:1-14` — `{{ $extensions := list ... }}` block precedes `#!/usr/bin/env bash`. Move template var below the shebang.
  Done: shebang moved to line 1.

- [x] **Cache-folder migration can clobber data**
  `home/.chezmoiscripts/run_once_before_00-macos-init.sh:17-21` — if `~/Library/Caches/XDG-cache` already exists, `mv ~/.cache` nests inside it. Guard with `-e` on target.
  Done: if target exists, contents are merged via `rsync` before symlinking.

- [x] **Unguarded `op` / yubikey / k8s sourcing in `.zshrc`**
  `home/private_dot_config/zsh/dot_zshrc:51,54,82` — `op completion`, yubikey-agent socket, and `source load-k8s-configs.sh` are unconditional. Errors on every new shell where any of these is missing. Wrap each in `command -v … &>/dev/null && …`.
  Done: `op` guarded with `command -v`, yubikey socket with `-S`, k8s loader with `-f`.

- [x] **Unquoted variable in `if`**
  `home/.chezmoiscripts/run_once_after_10-install-prezto.sh:8` — `if [ ! -d $PREZTODIR ]`. Quote it.
  Done: all variables quoted.

- [x] **asdf plugin script missing `set -euo pipefail`**
  `home/.chezmoiscripts/run_once_after_20-install-asdf-plugins.sh.tmpl` — add it. Check first that `asdf plugin add` on an already-installed plugin exits 0, otherwise re-runs will abort.
  Done: added; `asdf plugin add` on an existing plugin exits 0 (asdf 0.20.2).

## P2 — Security posture (CTO context)

- [x] **No git commit signing**
  `home/private_dot_config/exact_git/config.tmpl` has no `[commit] gpgsign` / `[gpg] format = ssh`. `yubikey-agent` is already installed — pair it with SSH-signed commits.
  Done in `dc9f1c1`: SSH signing via yubikey-agent (PIV slot 9a), commits and tags signed by default. Key registered on GitHub as signing key.

## P3 — Inconsistencies / cleanup

- [x] **`0-macos-init` doesn't use `script_darwin_only` template**
  Wraps 60+ lines in `if [ "${CHEZMOI_OS}" == "darwin" ]; then … fi`. Inconsistent with other scripts, silently no-ops on Linux instead of `exit 0`.
  Done: converted to `.tmpl`, uses `script_darwin_only` and `script_sudo`.

- [x] **`script_install_mas` is misnamed**
  Doesn't install `mas`, only gates on `.installmas == yes`. Rename to e.g. `script_skip_if_no_mas`.
  Done: renamed to `script_skip_if_no_mas`.

- [x] **`[github] user = mystygage` hardcoded**
  `home/private_dot_config/exact_git/config.tmpl:13-14` — `[user]` is templated, github user isn't. Template it or drop the section.
  Done: section removed (no tool here reads `github.user`).

- [x] **Dead SourceTree blocks in gitconfig**
  Lines 23-30 reference SourceTree, which isn't in the brew bundle. Remove.
  Done: removed.

- [x] **`python 3.14.0t` (free-threaded build)**
  `home/dot_tool-versions:3` — verify if intentional. Many wheels (numpy/pandas/etc.) still don't support the no-GIL build.
  Done in `4e3d1f5`: switched to standard `3.14.8`.

- [x] **`.chezmoiignore` has orphan entries**
  `home/.chezmoiignore` — `script` and `install.sh` don't exist in `home/`. `README.md` masks `private_dot_config/nvim/{README.md,LICENSE}` (LazyVim starter leftovers). Decide what to keep.
  Done: `.chezmoiignore` removed (all entries were orphans), LazyVim `README.md` deleted. `LICENSE` kept (Apache-2.0 notice of the starter).

- [x] **`coreutils` installed but not on PATH**
  Brew bundle includes it, but nothing adds `$(brew --prefix coreutils)/libexec/gnubin` to `PATH`. Either remove the package or actually use it (would also resolve P1 #2).
  Done: removed from brew bundle (not needed after the `xargs` finding).

- [x] **Dead LazyVim example file**
  `home/private_dot_config/nvim/lua/plugins/example.lua` starts with `if true then return {} end`. Never loaded. Delete.
  Done: deleted.

- [x] **`chezmoiexternal.toml` refreshes static fonts weekly**
  `refreshPeriod = "168h"` on MesloLGS fonts. Set to `0` (never re-download).
  Done: `refreshPeriod` removed (default `0` = never).

## Keyboard / Terminal — Umlaute + Zellij-Alt gleichzeitig

Ziel: macOS-Option+u-Compose für Umlaute **und** funktionierende `Alt+`-Bindings in Zellij — auf dem Planck (QMK, single Option/Alt). Lösung 2 (Mod-Tap), umzusetzen wenn das Keyboard wieder sauber flashbar ist.

Rahmenbedingungen:
- **Ghostty** (`home/private_dot_config/exact_ghostty/config`): `macos-option-as-alt = right` setzen.
  - Linke Option (`KC_LALT`) → nicht als Alt abgefangen → macOS-Compose (Option+u → ü) bleibt unverändert.
  - Rechte Option (`KC_RALT`) → als Alt/Meta durchgereicht → Zellij-Bindings.
- **QMK** (Keymap liegt außerhalb dieses Repos):
  - Bestehende `KC_LALT`-Taste **unverändert** lassen → Umlaut-Workflow bleibt.
  - Eine vorhandene Base-Layer-Taste als Mod-Tap belegen: `MT(MOD_RALT, KC_X)` — tippen = Taste, halten = Right-Alt.
  - **Wichtig:** Modifier muss auf dem **Base-Layer** liegen, nicht auf Lower/Raise. Ein RALT auf einem Momentary-Layer bricht Chords wie `Alt+n`, weil das Halten des Layer-Keys die Zieltaste umschaltet.
  - Danach: `qmk compile -kb planck/... -km <keymap>` + flashen.
- Verifizieren: in Zellij `Alt+n` (new pane) und `Alt+h/j/k/l` (pane nav) testen; Umlaute via Option+u im Terminal gegenchecken.
- Fallback, falls kein Base-Layer-Slot frei und Mod-Tap stört: Lösung B (dedizierte ä/ö/ü/ß-Keys per QMK-Unicode, dann Ghostty `macos-option-as-alt = true`).

## Suggested order
1. ~~P1 #1 (asdf plugins) — blocks fresh setup~~ done
2. ~~P1 #2-#9~~ done
3. ~~P2 (commit signing)~~ done
4. ~~P3 cleanup~~ done
