# github.com/mystygage/dotfiles

personal dotfiles, managed with [`chezmoi`](https://github.com/twpayne/chezmoi).

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply mystygage --purge-binary
```

## Details

On macOS the script assumes that [`brew`](https://brew.sh) is already installed.

- all config files are stored in `XDG_CONFIG_HOME` which defaults to `~/.config`
- install tools and apps with Homebrew
- basic setup for
  - zsh with prezto
  - neovim
  - ghostty
  - vscode
- runtime versions managed with asdf
- pending macOS updates are listed, installing them stays manual

## Linux servers and containers

Linux gets the shell setup only: zsh with prezto, git config and shell helpers. Mac apps, fonts, neovim and asdf configs are skipped, and nothing needs `sudo`. The dotfiles don't install packages on Linux, so install the prerequisites first:

```bash
sudo apt-get install -y zsh git curl
chsh -s "$(command -v zsh)"

sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply mystygage
```

- Prezto is installed by the first `chezmoi apply` that finds both `git` and `zsh`.
- Commits are unsigned, the YubiKey stays on the Mac.
- asdf is opt-in: install the [binary](https://github.com/asdf-vm/asdf/releases) on a host that needs runtimes and the next `chezmoi apply` adds the plugins. Versions come from each project's `.tool-versions`.
- Use this for dev and debug containers, not production images. It pulls unpinned code at runtime.

Guidance for coding agents (Codex, Claude Code) lives in [`AGENTS.md`](AGENTS.md).
