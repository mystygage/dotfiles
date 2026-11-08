# AGENTS.md

Guidance for coding agents (Codex, Claude Code, and others) working in this repository.
This file is the single source of truth. `CLAUDE.md` only imports it, so edit here.

## Overview

Personal dotfiles for macOS, plus a minimal shell setup for Linux servers and containers, managed with [chezmoi](https://github.com/twpayne/chezmoi).
Config files follow the XDG Base Directory spec (`~/.config`).

## Common Commands

```bash
# Preview changes before applying (run this first)
chezmoi diff

# Apply dotfiles changes
chezmoi apply

# Add a new file to chezmoi management
chezmoi add ~/.config/some-file

# Edit a managed file (opens in editor and applies on save)
chezmoi edit ~/.config/some-file

# Render a template without applying it
chezmoi execute-template < home/path/to/file.tmpl

# Re-run scripts (useful for testing)
chezmoi state delete-bucket --bucket=scriptState && chezmoi apply
```

## Agent Rules

- `chezmoi apply` writes to the real `$HOME` and may run install scripts with `sudo`. Do not run it unless explicitly asked; use `chezmoi diff` or `chezmoi execute-template` to verify.
- Edit files in `home/` (the source state), never the deployed files under `~`.
- Never commit secrets. Credentials come from 1Password (`op`) at runtime.
- Shell scripts: `#!/usr/bin/env bash` on line 1 (also after template rendering), `set -euo pipefail`, quote variables. Target BSD userland (macOS), not GNU. Anything deployed to Linux must work with both.
- Formatting follows `.editorconfig`: UTF-8, LF, 2-space indent, final newline.
- Commit messages use a `[scope] description` prefix, e.g. `[zsh] improve start up time with caching`.
- Open findings and planned work live in `TODO.md`. Tick items off there when fixed.

## Repository Structure

- `.chezmoiroot` points to `home/` as the source directory. Files in the repo root (`AGENTS.md`, `CLAUDE.md`, `TODO.md`, `README.md`, `bootstrap.sh`, `.github/`) are not deployed.
- Source files in `home/` map to target locations:
  - `dot_` prefix: `.` (e.g. `dot_zshenv` becomes `.zshenv`)
  - `private_` prefix: file/directory with restricted permissions
  - `exact_` prefix: directory managed exactly (extra files are deleted)
  - `executable_` prefix: file gets the executable bit
  - `symlink_` prefix: target is created as a symlink
  - `.tmpl` suffix: processed as Go template

### Key Directories

- `home/.chezmoiscripts/`: install and setup scripts
- `home/.chezmoitemplates/`: reusable script fragments, included via `{{ template "name" . }}`
- `home/dot_local/bin/`: custom shell scripts added to `PATH`
- `home/private_dot_config/`: application configs (zsh/prezto, nvim/LazyVim, git, ghostty, asdf, fzf)
- `home/private_dot_config/nvim/.lazy-lock.json`: lazy.nvim's lock file. chezmoi skips dot-prefixed source files and deploys `symlink_lazy-lock.json.tmpl` pointing here, so `:Lazy update` changes this file in the repo directly.

### Script Execution Order

Scripts in `.chezmoiscripts/` run alphabetically within each phase:
- `run_once_before_*`: once, before files are applied
- `run_once_after_*`: once, after files are applied
- `run_onchange_*`: re-run whenever the rendered script content changes

Package lists are inlined in the scripts, so editing them triggers a re-run:
- Homebrew: `run_onchange_before_install-brew-bundle.sh.tmpl`
- Mac App Store: `run_onchange_before_install-mas-bundle.sh.tmpl`
- VS Code extensions: `run_onchange_after_setup-editor.sh.tmpl`
- macOS defaults: `run_onchange_after_macos-settings.sh.tmpl`

Security settings (firewall, screen lock, TouchID) live in `run_onchange_after_macos-security.sh.tmpl`. That script reads the real state and only changes what differs.

`run_once` and `run_onchange` scripts fire again whenever their rendered content changes, so they must be safe to re-run. A destructive one-time step gets its own small script, like `run_once_after_30-macos-dock.sh.tmpl`.

## CI

`.github/workflows/ci.yml` runs on every push: gitleaks over the full history, `zsh -n`, shellcheck on scripts rendered for macOS, and a Linux smoke test in a throwaway `HOME`. macOS behavior is not tested there, only syntax and lint.

`.github/workflows/upstream.yml` runs weekly and on changes:
- every package entry still exists upstream, because a vanished cask aborts the first apply on a new Mac
- the pins in `.chezmoidata.toml` and the Withings image keep up with upstream: a warning while behind, an error once upstream changes have waited more than 30 days or a pinned commit left the default branch

Actions, images and the chezmoi download are pinned by commit, digest and checksum. Update them on purpose.

## Linux

Target is servers and containers: zsh, prezto and git config only. No Linuxbrew, no commit signing, no packages installed by the dotfiles.

- `home/.chezmoiignore` lists what is skipped on Linux. New macOS-only files go there.
- Scripts that make no sense on Linux use `script_darwin_only`.
- In zsh config, guard optional tools with `(( $+commands[tool] ))`. A missing `eza` must not break `ls`.
- A `run_once` script needing a tool that may arrive later renders empty until `lookPath` finds it. chezmoi skips empty scripts and records nothing, so it runs once the tool exists.

## Templating

Template data is defined in `home/.chezmoi.toml.tmpl`:
- `.name`: user's full name
- `.email`: user's email
- `.installmas`: `"yes"` to install Mac App Store apps
- `.lostcontact`: contact on the macOS login window. Local config only, never commit it: this repo is public. Empty leaves the current text alone.

Static data lives in `home/.chezmoidata.toml` (read on every apply, no `chezmoi init` needed):
- `.yubikeys`: serial + SSH public key per YubiKey, used for git commit signing (`allowed_signers`)
- `.pins`: commit (and checksum) for prezto, powerlevel10k, the fonts and each asdf plugin. To update, read upstream's changes, then bump `ref`. An archive or file also needs its new `sha256`. The scripts and externals render the pins, so the next `chezmoi apply` moves existing machines too.

Helpers in `home/.chezmoitemplates/`:
- `script_darwin_only`: exits if not on macOS
- `script_eval_brew`: sets up Homebrew for the current architecture (arm64/x86), renders nothing on Linux
- `script_sudo`: sudo keep-alive during script execution, `sudo -k` on exit. It sets the EXIT trap, so a script using it can't set its own.
- `script_fda`: aborts unless Full Disk Access is granted
- `script_skip_if_no_mas`: exits unless `.installmas == "yes"`

## External Dependencies

Defined in `home/.chezmoiexternal.toml` (a template, pins from `.chezmoidata.toml`):
- powerlevel10k as an archive in `~/.local/share/powerlevel10k`, sourced by `.zshrc`. Prezto's `prompt` module is not loaded, its submodule lags behind.
- MesloLGS Nerd Font files (for powerlevel10k) in `~/Library/Fonts`

Prezto itself is a git clone with submodules, so `run_onchange_after_10-install-prezto.sh.tmpl` checks out the pinned commit. It stops when the clone has local edits.

## Tool Versions

Managed by asdf in `home/dot_tool-versions`: nodejs, java, python, golang, bun.
Each tool needs a matching plugin under `pins.asdf` in `.chezmoidata.toml`. `run_onchange_after_20-install-asdf-plugins.sh.tmpl` adds it and checks out the pinned ref. Don't run `asdf plugin update --all`, it moves the plugins off their pins.
That script embeds a hash of `dot_tool-versions`, so changing a version runs `asdf install` on the next `chezmoi apply`. Project-level `.tool-versions` files still need `asdf install` by hand.
