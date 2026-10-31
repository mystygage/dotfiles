# Dotfiles Audit — Open Findings

Findings from review on 2026-05-13. Ordered by severity.

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

- [ ] **No git commit signing**
  `home/private_dot_config/exact_git/config.tmpl` has no `[commit] gpgsign` / `[gpg] format = ssh`. `yubikey-agent` is already installed — pair it with SSH-signed commits.

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
3. P2 (commit signing)
4. ~~P3 cleanup~~ done
