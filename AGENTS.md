# AGENTS.md

Guidance for coding agents (Codex, Claude Code, and others) working in this repository.
This file is the single source of truth. `CLAUDE.md` only imports it, so edit here.

## Overview

Personal dotfiles for macOS, managed with [chezmoi](https://github.com/twpayne/chezmoi).
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
- Shell scripts: `#!/usr/bin/env bash` on line 1 (also after template rendering), `set -euo pipefail`, quote variables. Target BSD userland (macOS), not GNU.
- Formatting follows `.editorconfig`: UTF-8, LF, 2-space indent, final newline.
- Commit messages use a `[scope] description` prefix, e.g. `[zsh] improve start up time with caching`.
- Open findings and planned work live in `TODO.md`. Tick items off there when fixed.

## Repository Structure

- `.chezmoiroot` points to `home/` as the source directory. Files in the repo root (`AGENTS.md`, `CLAUDE.md`, `TODO.md`, `README.md`) are not deployed.
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

## Templating

Template data is defined in `home/.chezmoi.toml.tmpl`:
- `.name`: user's full name
- `.email`: user's email
- `.installmas`: `"yes"` to install Mac App Store apps
- `.lostcontact`: contact on the macOS login window. Local config only, never commit it: this repo is public. Empty leaves the current text alone.

Static data lives in `home/.chezmoidata.toml` (read on every apply, no `chezmoi init` needed):
- `.yubikeys`: serial + SSH public key per YubiKey, used for git commit signing (`allowed_signers`)

Helpers in `home/.chezmoitemplates/`:
- `script_darwin_only`: exits if not on macOS
- `script_eval_brew`: sets up Homebrew for the current architecture (arm64/x86)
- `script_sudo`: sudo keep-alive during script execution
- `script_fda`: aborts unless Full Disk Access is granted
- `script_skip_if_no_mas`: exits unless `.installmas == "yes"`

## External Dependencies

Defined in `home/.chezmoiexternal.toml`: MesloLGS Nerd Font files (for powerlevel10k), downloaded into `~/Library/Fonts`.

## Tool Versions

Managed by asdf in `home/dot_tool-versions`: nodejs, java, python, golang, bun.
Each tool needs a matching plugin in `run_once_after_20-install-asdf-plugins.sh.tmpl`.
