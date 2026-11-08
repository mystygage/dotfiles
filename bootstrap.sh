#!/usr/bin/env bash
# First step on a new Mac: installs the Xcode Command Line Tools, Homebrew and
# chezmoi, then deploys these dotfiles. For Linux see the README.
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mystygage/dotfiles/main/bootstrap.sh)"

set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This script is for macOS, for Linux see the README." >&2
  exit 1
fi

# Homebrew and chezmoi both ask questions, and `curl | sh` leaves them without input
if [ ! -t 0 ]; then
  echo "stdin is not a terminal. Run it with: /bin/bash -c \"\$(curl -fsSL <url>)\"" >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install
  echo "Finish the Xcode Command Line Tools dialog, then run this script again."
  exit 0
fi

case "$(uname -m)" in
  arm64) brew_bin=/opt/homebrew/bin/brew ;;
  *) brew_bin=/usr/local/bin/brew ;;
esac

# Check the path: a fresh shell doesn't have brew on PATH even when it is installed
if [ ! -x "$brew_bin" ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$("$brew_bin" shellenv)"
# The brew bundle script turns analytics off for good, until then skip them per call
export HOMEBREW_NO_ANALYTICS=1

if ! brew list --formula chezmoi >/dev/null 2>&1; then
  brew install chezmoi
fi

if ! chezmoi init --apply mystygage; then
  echo "The first apply stopped. Fix what it reports, open a new terminal and run: chezmoi apply" >&2
  exit 1
fi

echo "Done. Open a new terminal to get the new shell."
