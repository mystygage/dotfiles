#!/bin/sh

set -euo pipefail

PREZTODIR="${ZDOTDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh}/.zprezto"
REPO=https://github.com/sorin-ionescu/prezto.git

if [ ! -d $PREZTODIR ]; then
  git clone --recursive $REPO $PREZTODIR
fi
