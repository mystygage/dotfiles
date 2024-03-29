# github.com/mystygage/dotfiles

personal dotfiles, managed with [`chezmoi`](https://github.com/twpayne/chezmoi).

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply mystygage --purge-binary
```

## Details

The script assumes that [`brew`](https://brew.sh) is already installed.

- all config files are stored in `XDG_CONFIG_HOME` which defaults to `~/.config`
- install tools and apps with Homebrew
- basic setup for
  - zsh with prezto
  - neovim
  - alacritty 
  - vscode
