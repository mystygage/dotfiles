# github.com/mystygage/dotfiles

personal dotfiles, managed with [`chezmoi`](https://github.com/twpayne/chezmoi).

## Setup

```bash
curl -fsSL https://raw.githubusercontent.com/mystygage/dotfiles/main/bootstrap.sh | sh
```

## Details

The bootstrap script installs brew and chezmoi.

- all config files are stored in `XDG_CONFIG_HOME` which defaults to `~/.config`
- install tools and apps with Homebrew
- basic setup for
  - zsh with prezto
  - neovim
  - alacritty 
  - vscode
